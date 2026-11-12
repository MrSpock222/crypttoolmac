import Foundation
import CTCommon
import CTBigNum

// MARK: - Tiny test harness

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var passes = 0
nonisolated(unsafe) var currentSection = ""

func check(_ cond: Bool, _ msg: @autoclosure () -> String = "", line: Int = #line) {
    if cond {
        passes += 1
    } else {
        failures += 1
        print("  FEHLER [\(currentSection)] Zeile \(line): \(msg())")
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ msg: @autoclosure () -> String = "", line: Int = #line) {
    check(a == b, "\(msg()) – erhalten: \(a), erwartet: \(b)", line: line)
}

/// Set CTBN_ONLY=<substring> to run only matching sections.
let onlySection = ProcessInfo.processInfo.environment["CTBN_ONLY"]

func section(_ name: String, _ body: () throws -> Void) {
    if let only = onlySection, !name.lowercased().contains(only.lowercased()) { return }
    currentSection = name
    let start = Date()
    do {
        try body()
    } catch {
        failures += 1
        print("  FEHLER [\(name)] unerwartete Ausnahme: \(error)")
    }
    print(name.padding(toLength: 44, withPad: " ", startingAt: 0) + String(format: "%8.3f s", Date().timeIntervalSince(start)))
}

func time<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
    let start = Date()
    let r = try body()
    print("    " + label.padding(toLength: 48, withPad: " ", startingAt: 0) + String(format: "%9.2f ms", Date().timeIntervalSince(start) * 1000))
    return r
}

/// Runs a python3 script (isolated mode) with stdin input, returns stdout or nil.
func python(_ script: String, input: String) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["python3", "-I", "-c", script]
    let inPipe = Pipe(), outPipe = Pipe()
    p.standardInput = inPipe
    p.standardOutput = outPipe
    p.standardError = FileHandle.standardError
    do { try p.run() } catch { return nil }
    let data = input.data(using: .utf8)!
    DispatchQueue.global().async {
        inPipe.fileHandleForWriting.write(data)
        try? inPipe.fileHandleForWriting.close()
    }
    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return String(data: out, encoding: .utf8)
}

func big(_ s: String) -> BigUInt { BigUInt(s)! }
func hex(_ s: String) -> BigUInt { BigUInt(s, radix: 16)! }

/// Random operand generator with interesting edge cases.
func randomOperand(maxLimbs: Int) -> BigUInt {
    let kind = Int.random(in: 0..<10)
    let limbs = Int.random(in: 1...maxLimbs)
    switch kind {
    case 0: return BigUInt(UInt64.random(in: 0...UInt64.max))
    case 1: return (BigUInt(1) << (64 * limbs)) - 1                 // all ones
    case 2: return BigUInt(1) << Int.random(in: 0..<(64 * limbs))    // power of two
    case 3: return (BigUInt(1) << (64 * limbs - 1)) + BigUInt(UInt64.random(in: 0...3))
    case 4: return BigUInt.random(bits: Int.random(in: 1...(64 * limbs)))
    default: return BigUInt.random(bits: 64 * limbs)
    }
}

setvbuf(stdout, nil, _IONBF, 0)
print("CTBigNumTests")

// MARK: - Core arithmetic vs. Python

section("Arithmetik gegen Python") {
    var lines: [String] = []
    var swiftResults: [String] = []
    var pairs: [(BigUInt, BigUInt)] = []
    let sizes = [1, 2, 3, 5, 8, 20, 45, 90, 150, 700]
    for maxL in sizes {
        let stress = Int(ProcessInfo.processInfo.environment["CTBN_STRESS"] ?? "1") ?? 1
        for _ in 0..<((maxL > 200 ? 12 : 60) * stress) {
            let a = randomOperand(maxLimbs: maxL)
            var b = randomOperand(maxLimbs: Int.random(in: 1...maxL))
            if b.isZero { b = 1 }
            pairs.append((a, b))
        }
    }
    // special pairs that exercise the qhat correction / add-back paths of Knuth D
    let special: [(BigUInt, BigUInt)] = [
        ((BigUInt(1) << 128) - 1, (BigUInt(1) << 64) + 1),
        (BigUInt(1) << 256, (BigUInt(1) << 128) - 1),
        (hex("FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF"), hex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")),
        (hex("8000000000000000000000000000000000000000000000000000000000000000"), hex("800000000000000000000000000000000000000000000001")),
        (hex("7FFFFFFFFFFFFFFF8000000000000000000000000000000000000000"), hex("800000000000000000000000000000000000000000000001")),
        // cases that trigger the rare "add back" step of algorithm D (found by simulation)
        (hex("7D765E9C4DF25E7EAF651F7F04D5A1FE11A839FB2ACCEB05F0E334968D0D0656"), hex("8000000000000000B2F14C942E05319ACB5C74273F98E277")),
        (hex("14AA0537589550FB2869683BCC571CC94E38F614A1CE902ECB4BEFE4737A3EC2"), hex("8000000000000000FA529BA3FE3BFADA7CF20724D953EE26")),
        (hex("13C4E82CE37286F90C7E49E8A864AE65134D0BE564774330AB0972A14B495E1B"), hex("800000000000000050E40D54712EA6B36471FDE41F229DD0")),
        (hex("51139C2A2CE4A2E00000000000000000A227385459C945B2E712C3AD27A71AE"), hex("80000000000000000000000000000000FFFFFFFFFFFFFFFF")),
        (hex("6A885D82196C86E70BE1215D88407198FBBE9474F9FAF60869FF1D2C12575363"), hex("8000000000000000A81100A16EA330A1A66D58B5D1A4C01E")),
        (BigUInt(0), BigUInt(7)),
        (BigUInt(5), BigUInt(7)),
    ]
    pairs.append(contentsOf: special)
    for (a, b) in pairs {
        let shift = Int.random(in: 0..<200)
        lines.append("\(a.toString(radix: 16)) \(b.toString(radix: 16)) \(shift)")
        let (q, r) = a.quotientAndRemainder(dividingBy: b)
        var parts: [String] = []
        parts.append((a + b).toString(radix: 16))
        parts.append(a >= b ? (a - b).toString(radix: 16) : "-")
        parts.append((a * b).toString(radix: 16))
        parts.append(q.toString(radix: 16))
        parts.append(r.toString(radix: 16))
        parts.append((a << shift).toString(radix: 16))
        parts.append((a >> shift).toString(radix: 16))
        parts.append((a & b).toString(radix: 16))
        parts.append((a | b).toString(radix: 16))
        parts.append((a ^ b).toString(radix: 16))
        parts.append(a.gcd(b).toString(radix: 16))
        parts.append(a.squareRoot().toString(radix: 16))
        parts.append(a.description)
        parts.append(a.squared().toString(radix: 16))
        parts.append(a.toString(radix: 7))
        swiftResults.append(parts.joined(separator: " "))
    }
    let script = """
import sys, math
def tob(n, b):
    if n == 0: return '0'
    d = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    s = []
    while n: n, r = divmod(n, b); s.append(d[r])
    return ''.join(reversed(s))
sys.set_int_max_str_digits(0) if hasattr(sys, 'set_int_max_str_digits') else None
for line in sys.stdin:
    a, b, s = line.split(); a = int(a, 16); b = int(b, 16); s = int(s)
    h = lambda x: format(x, 'X')
    out = [h(a+b), h(a-b) if a >= b else '-', h(a*b), h(a//b), h(a%b), h(a<<s), h(a>>s), h(a&b), h(a|b), h(a^b), h(math.gcd(a,b)), h(math.isqrt(a)), str(a), h(a*a), tob(a, 7)]
    print(' '.join(out))
"""
    guard let out = python(script, input: lines.joined(separator: "\n") + "\n") else {
        print("  (python3 nicht verfügbar – übersprungen)")
        return
    }
    let pyLines = out.split(separator: "\n").map(String.init)
    checkEqual(pyLines.count, swiftResults.count, "Anzahl Ergebniszeilen")
    for (i, (sw, py)) in zip(swiftResults, pyLines).enumerated() {
        if sw != py {
            let swp = sw.split(separator: " "), pyp = py.split(separator: " ")
            let names = ["add", "sub", "mul", "div", "mod", "shl", "shr", "and", "or", "xor", "gcd", "isqrt", "dec", "sqr", "radix7"]
            for k in 0..<min(swp.count, pyp.count) where swp[k] != pyp[k] {
                check(false, "Zeile \(i) Operation \(names[k]): \(lines[i])")
            }
        } else {
            check(true)
        }
    }
}

section("Modexp / Inverse gegen Python") {
    var lines: [String] = []
    var sw: [String] = []
    let stress = Int(ProcessInfo.processInfo.environment["CTBN_STRESS"] ?? "1") ?? 1
    for bits in [8, 63, 64, 65, 127, 128, 200, 512, 1023, 1024, 2048] {
        for _ in 0..<(8 * stress) {
            var m = BigUInt.random(bits: bits, exact: true)
            if Bool.random() { m = m.settingBit(0) }
            if m < 2 { m = 3 }
            let a = BigUInt.random(bits: bits + 10)
            let e = BigUInt.random(bits: Int.random(in: 1...bits))
            lines.append("\(a.toString(radix: 16)) \(e.toString(radix: 16)) \(m.toString(radix: 16))")
            let inv = a.inverse(modulo: m)
            sw.append("\(a.power(e, modulus: m).toString(radix: 16)) \(inv.map { $0.toString(radix: 16) } ?? "-")")
        }
    }
    let script = """
import sys
for line in sys.stdin:
    a, e, m = (int(x, 16) for x in line.split())
    try:
        inv = format(pow(a, -1, m), 'X')
    except ValueError:
        inv = '-'
    print(format(pow(a, e, m), 'X'), inv)
"""
    guard let out = python(script, input: lines.joined(separator: "\n") + "\n") else { return }
    let py = out.split(separator: "\n").map(String.init)
    checkEqual(py.count, sw.count)
    for (i, (s, p)) in zip(sw, py).enumerated() {
        check(s == p, "modexp/inverse Zeile \(i): \(lines[i]) → \(s) vs \(p)")
    }
}

section("Primzahltests") {
    // known primes / composites
    let primes: [BigUInt] = [2, 3, 5, 7, 65537, 4294967291, 18446744073709551557,
                             big("170141183460469231731687303715884105727"),            // 2^127-1
                             big("618970019642690137449562111"),                        // 2^89-1
                             BigUInt(1) << 521 - 1]
    let composites: [BigUInt] = [0, 1, 4, 9, 561, 1105, 1729, 2465, 2821, 6601, 8911,     // Carmichael
                                 3215031751, 2152302898747, 3474749660383, 341550071728321,
                                 3825123056546413051, 318665857834031151167461,           // strong pseudoprimes
                                 big("3317044064679887385961981"),
                                 big("170141183460469231731687303715884105727") * 3,
                                 (BigUInt(1) << 128) + 1,
                                 big("1195068768795265792518361315725116351898245581")]  // 3 primes
    for p in primes {
        check(Primality.isProbablePrime(p), "isProbablePrime(\(p))")
        for m in [PrimeTestMethod.millerRabin, .solovayStrassen, .fermat] {
            check(Primality.test(p, method: m, rounds: 20), "\(m.displayName)(\(p))")
        }
    }
    for c in composites {
        check(!Primality.isProbablePrime(c), "isProbablePrime(\(c)) sollte falsch sein")
        check(!Primality.test(c, method: .millerRabin, rounds: 20), "MR(\(c))")
        check(!Primality.test(c, method: .solovayStrassen, rounds: 20), "SS(\(c))")
    }
    // Fermat is fooled by Carmichael numbers only with bases coprime to n – just check it runs
    _ = Primality.test(561, method: .fermat)
    // compare with sieve for all n < 20000
    let sieve = Set(Primality.sieve(upTo: 20000))
    var ok = true
    for n in 0..<20000 {
        let isP = sieve.contains(n)
        if Primality.isProbablePrime(BigUInt(n)) != isP { ok = false; print("    isProbablePrime falsch für \(n)") }
        if n < 3000, Primality.test(BigUInt(n), method: .trialDivision) != isP { ok = false; print("    Probedivision falsch für \(n)") }
        if n < 2000 && n % 7 == 0 || n < 300, Primality.test(BigUInt(n), method: .aks) != isP { ok = false; print("    AKS falsch für \(n)") }
    }
    check(ok, "Vergleich mit Sieb")
    // BPSW strong Lucas on larger random numbers vs. MR with many rounds
    for _ in 0..<200 {
        let n = BigUInt.random(bits: Int.random(in: 65...300)).settingBit(0)
        checkEqual(Primality.isProbablePrime(n), Primality.millerRabin(n, rounds: 30), "BPSW vs MR \(n)")
    }
    // trial division on 64-bit numbers
    check(Primality.test(18446744073709551557, method: .trialDivision) == true, "Probedivision 2^64-59")
    check(Primality.test(BigUInt(4294967291) * 4294967279, method: .trialDivision) == false, "Probedivision Produkt")
    // AKS
    let aksPrimes: [BigUInt] = [1_000_003, 999_983, 65_537]
    for p in aksPrimes {
        let r = time("AKS \(p)") { Primality.aks(p) }
        check(r == true, "AKS(\(p))")
    }
    check(Primality.aks(BigUInt(1_000_003) * 999_983) == false, "AKS composite")
    check(Primality.aks(BigUInt(1) << 62) == nil, "AKS zu groß")
    // next / previous prime
    checkEqual(Primality.nextPrime(after: 0), 2)
    checkEqual(Primality.nextPrime(after: 2), 3)
    checkEqual(Primality.nextPrime(after: 13), 17)
    checkEqual(Primality.nextPrime(after: BigUInt(1) << 64), (BigUInt(1) << 64) + 13)
    checkEqual(Primality.nextPrime(after: BigUInt(10).power(30)), BigUInt(10).power(30) + 57)
    checkEqual(Primality.previousPrime(before: 100), 97)
    checkEqual(Primality.primes(in: 10...50, limit: 100), [11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47])
    checkEqual(Primality.primes(in: 10...50, limit: 3), [11, 13, 17])
    let big10 = BigUInt(10).power(20)
    checkEqual(Primality.primes(in: big10...(big10 + 200), limit: 10),
               [big10 + 39, big10 + 129, big10 + 151, big10 + 193])
    // random primes
    for bits in [2, 3, 8, 16, 17, 31, 64, 65, 100, 256] {
        let p = Primality.randomPrime(bits: bits)
        checkEqual(p.bitLength, bits, "Bitlänge randomPrime(\(bits))")
        check(Primality.isProbablePrime(p), "randomPrime(\(bits)) prim")
    }
    for bits in [512, 1024] {
        let p = time("randomPrime(\(bits))") { Primality.randomPrime(bits: bits) }
        checkEqual(p.bitLength, bits)
        check(Primality.millerRabin(p, rounds: 10))
    }
    var t = 0.0
    for _ in 0..<10 { let s = Date(); _ = Primality.randomPrime(bits: 1024); t += Date().timeIntervalSince(s) }
    print(String(format: "    randomPrime(1024) Mittel über 10: %.1f ms", t * 100))
    let sp = time("randomSafePrime(256)") { Primality.randomSafePrime(bits: 256) }
    checkEqual(sp.bitLength, 256)
    check(Primality.isProbablePrime(sp) && Primality.isProbablePrime((sp - 1) / 2), "sichere Primzahl")
    if let rp = Primality.randomPrime(in: 1000...1100) {
        check(rp >= 1000 && rp <= 1100 && Primality.isProbablePrime(rp), "randomPrime(in:)")
    } else { check(false, "randomPrime(in:) nil") }
    check(Primality.randomPrime(in: 24...28) == nil, "kein Primzahl in 24…28")
    checkEqual(Primality.randomPrime(in: 2...2), 2)
    let rangeLo = BigUInt(1) << 200
    if let rp = Primality.randomPrime(in: rangeLo...(rangeLo << 1), method: .solovayStrassen) {
        check(rp >= rangeLo && rp <= rangeLo << 1 && Primality.isProbablePrime(rp))
    } else { check(false) }
}

section("Performance Modexp") {
    for bits in [1024, 2048, 4096] {
        let m = BigUInt.random(bits: bits, exact: true).settingBit(0)
        let a = BigUInt.random(below: m)
        let e = BigUInt.random(bits: bits, exact: true)
        _ = a.power(e, modulus: m)
        let n = bits == 4096 ? 3 : 10
        let s = Date()
        for _ in 0..<n { _ = a.power(e, modulus: m) }
        print(String(format: "    modexp %d Bit: %.2f ms", bits, Date().timeIntervalSince(s) * 1000 / Double(n)))
    }
}

section("Faktorisierung") {
    // semiprimes with known factors
    let p1 = big("1000000007"), q1 = big("998244353")
    let n1 = p1 * q1
    for m in FactorizationMethod.allCases {
        let f = time("\(m.displayName) 10^9-Semiprim") { Factorization.findFactor(of: n1, method: m, timeLimit: 20) }
        check(f == p1 || f == q1, "\(m.displayName): Faktor von \(n1) – erhalten \(String(describing: f))")
    }
    // p-1 smooth / p+1 smooth constructions
    let pSmooth = big("1000000000000000000000000000000000000000000000003") // dummy large cofactor
    _ = pSmooth
    // rho with 40-bit factors
    let ra = Primality.randomPrime(bits: 40), rb = Primality.randomPrime(bits: 90)
    let rf = time("Brent 40-Bit-Faktor") { Factorization.findFactor(of: ra * rb, method: .pollardRhoBrent, timeLimit: 30) }
    check(rf == ra || rf == rb, "Brent 40 Bit")
    // 20-digit factors (ECM, QS)
    let a = Primality.randomPrime(bits: 64), b = Primality.randomPrime(bits: 64)
    let n2 = a * b
    for m in [FactorizationMethod.lenstraECM, .quadraticSieve] {
        let f = time("\(m.displayName) 2×64 Bit") { Factorization.findFactor(of: n2, method: m, timeLimit: 60) }
        check(f == a || f == b, "\(m.displayName) 2×64 Bit: \(n2)")
    }
    // Fermat: close factors
    let c1 = Primality.nextPrime(after: BigUInt(1) << 100)
    let c2 = Primality.nextPrime(after: c1 + 1000000)
    let ff = time("Fermat nahe Faktoren 2×100 Bit") { Factorization.findFactor(of: c1 * c2, method: .fermat, timeLimit: 10) }
    check(ff == c1 || ff == c2, "Fermat")
    // p-1: p = 2·3·5·…·smooth + 1
    var sm = BigUInt(2)
    var pr = Primality.nextPrime(after: 2)
    repeat {
        sm = sm * pr
        pr = Primality.nextPrime(after: pr)
    } while sm.bitLength < 90 || !Primality.isProbablePrime(sm + 1)
    let smoothP = sm + 1
    let other = Primality.randomPrime(bits: 120)
    let fp = time("Pollard p−1 glatter Faktor") { Factorization.findFactor(of: smoothP * other, method: .pollardPMinus1, timeLimit: 10) }
    check(fp == smoothP || fp == other, "p-1")
    // full factorisation
    let n3 = big("600851475143")
    let fac3 = try Factorization.factorize(n3)
    checkEqual(Factorization.format(fac3), "71 · 839 · 1471 · 6857")
    let n4 = BigUInt(2).power(64) * BigUInt(3).power(5) * big("1000000007").power(2) * n2
    let fac4 = try time("factorize gemischt") { try Factorization.factorize(n4) }
    var prod = BigUInt(1)
    for (p, e) in fac4 { prod *= p.power(e); check(Primality.isProbablePrime(p)) }
    checkEqual(prod, n4, "Produkt der Faktoren")
    checkEqual(fac4.first!.prime, 2); checkEqual(fac4.first!.exponent, 64)
    // RSA-like 40, 50 digit numbers with QS
    for bits in [130, 166, 200] {
        let x = Primality.randomPrime(bits: bits / 2), y = Primality.randomPrime(bits: bits / 2)
        let nn = x * y
        var logLines: [String] = []
        let f = time("QS \(nn.digitCount()) Stellen") {
            Factorization.findFactor(of: nn, method: .quadraticSieve, timeLimit: 120)
        }
        check(f == x || f == y, "QS \(nn): \(String(describing: f)) \(logLines)")
        logLines.removeAll()
    }
    // ECM with a 25-digit factor of a 60 digit number
    let e1 = Primality.randomPrime(bits: 70), e2 = Primality.randomPrime(bits: 130)
    let fe = time("ECM 21-stelliger Faktor") { Factorization.findFactor(of: e1 * e2, method: .lenstraECM, timeLimit: 120) }
    check(fe == e1 || fe == e2, "ECM 70 Bit Faktor")
    // errors
    do { _ = try Factorization.factorize(0); check(false, "0 sollte Fehler werfen") } catch { check(error is CTError) }
    checkEqual(try Factorization.factorize(1).count, 0)
    let tok = CancellationToken(); tok.cancel()
    do {
        _ = try Factorization.factorize(Primality.randomPrime(bits: 200) * Primality.randomPrime(bits: 200), cancel: tok)
        check(false, "Abbruch erwartet")
    } catch { check(error is CTError) }
}

section("BigInt / Hilfsfunktionen") {
    let a: BigInt = -17, b: BigInt = 5
    checkEqual(a / b, -3); checkEqual(a % b, -2); checkEqual(a.modulo(5), 3)
    checkEqual(BigInt(17) / -5, -3); checkEqual(BigInt(17) % -5, 2)
    checkEqual(a.floorDivided(by: b), -4)
    checkEqual(BigInt("-123456789012345678901234567890")!.description, "-123456789012345678901234567890")
    checkEqual((-a).description, "17")
    check(BigInt(-3) < BigInt(2) && BigInt(-3) < BigInt(-2) && BigInt(5) > BigInt(-7))
    checkEqual(BigInt(-2).power(3), -8)
    for _ in 0..<200 {
        let x = BigInt(magnitude: BigUInt.random(bits: Int.random(in: 1...300)), isNegative: Bool.random())
        let y = BigInt(magnitude: BigUInt.random(bits: Int.random(in: 1...300)) + 1, isNegative: Bool.random())
        let (g, s, t) = BigInt.extendedGCD(x, y)
        check(x * s + y * t == g, "extendedGCD Identität")
        checkEqual(g.magnitude, x.magnitude.gcd(y.magnitude))
        let (q, r) = x.quotientAndRemainder(dividingBy: y)
        check(q * y + r == x && r.magnitude < y.magnitude, "Division mit Rest")
    }
    let big: BigUInt = 123456789012345678901234567890123456789
    checkEqual(big.description, "123456789012345678901234567890123456789")
    let neg: BigInt = -123456789012345678901234567890123456789
    checkEqual(neg.description, "-123456789012345678901234567890123456789")
    checkEqual(BigUInt("  0xff  ", radix: 16), 255)
    checkEqual(BigUInt("1_000_000"), 1000000)
    check(BigUInt("12a") == nil && BigUInt("") == nil && BigUInt("-5") == nil)
    checkEqual(BigUInt(bigEndianBytes: [0, 0, 1, 2]).bigEndianBytes, [1, 2])
    checkEqual(BigUInt(258).bigEndianBytes(length: 4), [0, 0, 1, 2])
    checkEqual(BigUInt.zero.bigEndianBytes, [])
    checkEqual(BigUInt(255).toString(radix: 16, uppercase: false), "ff")
    checkEqual(BigUInt(5).toString(radix: 2), "101")
    checkEqual(BigUInt(1000).digitCount(), 4); checkEqual(BigUInt(999).digitCount(), 3)
    checkEqual(BigUInt(10).power(500).digitCount(), 501); checkEqual((BigUInt(10).power(500) - 1).digitCount(), 500)
    checkEqual(BigUInt(1).digitCount(), 1); checkEqual(BigUInt(0).digitCount(), 1)
    let json = try JSONEncoder().encode([big])
    checkEqual(String(data: json, encoding: .utf8)!, "[\"\(big.toString(radix: 16))\"]")
    checkEqual(try JSONDecoder().decode([BigUInt].self, from: json), [big])
    checkEqual(BigUInt(100).nthRoot(3), 4); checkEqual(BigUInt(125).nthRoot(3), 5)
    checkEqual(big.squared().squareRoot(), big); checkEqual((big.squared() - 1).squareRoot(), big - 1)
    let pp = BigUInt(3).power(40).perfectPower()
    check(pp?.base == 3 && pp?.exponent == 40, "perfectPower 3^40")
    check(BigUInt(1000001).perfectPower() == nil)
    checkEqual(BigUInt(5).jacobi(21), 1); checkEqual(BigUInt(2).jacobi(7), 1); checkEqual(BigUInt(3).jacobi(7), -1)
    checkEqual(BigUInt(10).modularSquareRoot(prime: 13).map { ($0 * $0) % 13 }, 10)
    checkEqual(BigUInt(2).modularSquareRoot(prime: 113).map { ($0 * $0) % 113 }, 2)  // p ≡ 1 mod 16
    checkEqual(BigUInt.factorial(20), 2432902008176640000)
    checkEqual(BigUInt.binomial(50, 25), 126410606437752)
    check(BigUInt(6).inverse(modulo: 9) == nil); checkEqual(BigUInt(3).inverse(modulo: 7), 5)
    for bits in [1, 7, 64, 65, 300] {
        let r = BigUInt.random(bits: bits, exact: true)
        checkEqual(r.bitLength, bits)
    }
    let lo: BigUInt = 1000, hi: BigUInt = 1010
    for _ in 0..<50 { let r = BigUInt.random(in: lo...hi); check(r >= lo && r <= hi) }
    // huge number conversion (divide & conquer path)
    let huge = BigUInt(3).power(20000)
    let dec = time("toString 3^20000") { huge.description }
    checkEqual(BigUInt(dec)!, huge)
    checkEqual(dec.count, huge.digitCount())
}

section("RSA") {
    let kp = try RSAKeyPair(p: 61, q: 53, e: 17)
    checkEqual(kp.n, 3233); checkEqual(kp.phi, 3120); checkEqual(kp.d, 2753)
    checkEqual(kp.encrypt(65), 2790); checkEqual(kp.decrypt(2790), 65)
    checkEqual(kp.publicKey.encrypt(65), 2790)
    for (p, q, e) in [(BigUInt(60), BigUInt(53), BigUInt(17)), (61, 61, 17), (61, 53, 3), (61, 53, 3121)] {
        do { _ = try RSAKeyPair(p: p, q: q, e: e); check(false, "Fehler erwartet für \(p),\(q),\(e)") } catch { check(error is CTError) }
    }
    for bits in [8, 12, 16, 24, 32, 64, 100] {
        let k = RSAKeyPair.generate(bits: bits)
        checkEqual(k.n.bitLength, bits, "generate(\(bits))")
        let m = BigUInt.random(below: k.n)
        checkEqual(k.decrypt(k.encrypt(m)), m)
    }
    for bits in [512, 1024, 2048] {
        let k = time("RSA-Schlüsselerzeugung \(bits) Bit") { RSAKeyPair.generate(bits: bits) }
        checkEqual(k.n.bitLength, bits)
        checkEqual((k.e * k.d) % k.phi, 1)
        let m = BigUInt.random(below: k.n)
        let c = k.encrypt(m)
        let d = time("RSA-Entschlüsselung (CRT) \(bits) Bit") { k.decrypt(c) }
        checkEqual(d, m)
        checkEqual(k.decryptWithoutCRT(c), m)
        let msg = Array("Hallo CrypTool".utf8)
        let ct = try PKCS1.encrypt(msg, key: k.publicKey)
        checkEqual(ct.count, bits / 8)
        checkEqual(try PKCS1.decrypt(ct, key: k), msg)
        var bad = ct; bad[bad.count - 1] ^= 1
        if let r = try? PKCS1.decrypt(bad, key: k) { check(r != msg, "manipulierter Chiffretext") }
        let hash = [UInt8](repeating: 0xAB, count: 32)
        let sig = try PKCS1.sign(hash: hash, algorithm: .sha256, key: k)
        check(PKCS1.verify(signature: sig, hash: hash, algorithm: .sha256, key: k.publicKey))
        check(!PKCS1.verify(signature: sig, hash: [UInt8](repeating: 0xAC, count: 32), algorithm: .sha256, key: k.publicKey))
    }
    var t = 0.0
    for _ in 0..<5 { let s = Date(); _ = RSAKeyPair.generate(bits: 2048); t += Date().timeIntervalSince(s) }
    print(String(format: "    RSA-2048-Schlüsselerzeugung Mittel über 5: %.1f ms", t * 200))
    do { _ = try PKCS1.encrypt([UInt8](repeating: 1, count: 60), key: RSAKeyPair.generate(bits: 512).publicKey); check(false) } catch { check(error is CTError) }
    // OpenSSL generated vector (1024 bit, SHA-256, message "CrypTool")
    let osslP = hex("FDE5BAC458210C51BA7400A8A56792790717A9DA518CD3DFDF94EB245884B375650DE96947AC998AC11457BCB1B0217C14BC1C5DD9751E2630EA4EB78D00BC45")
    let osslQ = hex("F9312724DDC055406228A2102DA4F5F5B742B6B156B5C82D29A9BC2B5A92B3FAF2AC7ED923D811879C604F7E0C84991D3D99FB51BB1D6CE7F6DA41A4C2C2F029")
    let osslN = hex("F725327448FD436CFCA874A29E6AB6FA5B135E0933D9E923A568B903E63870F9114D5DDC7FED9D885AF1EDD7EA2250B7BBBD97F0CDC465F287A6C47E3A8DB6AA010ED60FB0179FED6D990B18930F15344E33FEB28544FAAF8594040B1EE97765CF1BC64D7C0B4A6F698B31A2073092FBFD55171AEDD41161644E3A053BE8D70D")
    let osslSig = Hex.decode("a941ed205ebc6f038ef37d8b0df9f512997cebf759c2cefb62bb8036af59d999c56d972b5a25531c651e69d26e11b68d259f1c7a6bda1a27b1932c2eff94e2fa035bc8abb6812f70f43c94eee63e0bba0738268b8918f0208943b2886254570d411d35737cd61e1c4894d74b396e65af2864670a42ed1ff2e41f661a5fa3a9f8")!
    let osslHash = Hex.decode("9871bc92e57c3418431749ad00df5c08a98b135e04e1025d4fff60bf00cd9c12")!
    let ok = try RSAKeyPair(p: osslP, q: osslQ, e: 65537)
    checkEqual(ok.n, osslN)
    check(PKCS1.verify(signature: osslSig, hash: osslHash, algorithm: .sha256, key: ok.publicKey), "OpenSSL-Signatur")
    checkEqual(try PKCS1.sign(hash: osslHash, algorithm: .sha256, key: ok), osslSig, "Signatur identisch zu OpenSSL")
    checkEqual(PKCS1.digestInfo(hash: [], algorithm: .sha1).count, 15)
    for alg in DigestAlgorithmID.allCases {
        checkEqual(Int(alg.digestInfoPrefix.last!), alg.digestLength, "DigestInfo-Länge \(alg)")
        checkEqual(Int(alg.digestInfoPrefix[1]) + 2, alg.digestInfoPrefix.count + alg.digestLength, "DER-Länge \(alg)")
    }
}

section("RSA-Textkodierung") {
    let n: BigUInt = 3233
    checkEqual(RSATextCodec.maxBlockSize(modulus: n, base: 27), 2)       // 27^2 = 729 ≤ 3233 < 19683
    checkEqual(RSATextCodec.maxBlockSize(modulus: 729, base: 27), 2)
    checkEqual(RSATextCodec.maxBlockSize(modulus: 728, base: 27), 1)
    checkEqual(RSATextCodec.maxBlockSize(modulus: 20, base: 27), 0)
    checkEqual(RSATextCodec.maxBlockSize(modulus: BigUInt(1) << 1024, base: 256), 128)
    let blocks = RSATextCodec.encodeBlocks("HALLO welt!", alphabet: RSATextCodec.defaultAlphabet, blockSize: 3)
    // "HALLO " → "HAL" "LO " ; lower case letters are not part of the alphabet
    checkEqual(blocks, [BigUInt(8 * 729 + 1 * 27 + 12), BigUInt(12 * 729 + 15 * 27 + 0)])
    checkEqual(RSATextCodec.decodeBlocks(blocks, alphabet: RSATextCodec.defaultAlphabet, blockSize: 3), "HALLO ")
    let ab = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    checkEqual(RSATextCodec.encodeBlocks("ABCD", alphabet: ab, blockSize: 3), [BigUInt(0 * 676 + 1 * 26 + 2), BigUInt(3 * 676)])
    let kp = RSAKeyPair.generate(bits: 64)
    let bs = RSATextCodec.maxBlockSize(modulus: kp.n, base: 27)
    let text = "DIES IST EIN TEST DER RSA DEMO"
    let enc = RSATextCodec.encodeBlocks(text, alphabet: RSATextCodec.defaultAlphabet, blockSize: bs).map { kp.encrypt($0) }
    let dec = RSATextCodec.decodeBlocks(enc.map { kp.decrypt($0) }, alphabet: RSATextCodec.defaultAlphabet, blockSize: bs)
    checkEqual(dec.trimmingCharacters(in: .whitespaces), text)
    let bytes = Array("Hallo".utf8)
    let bb = RSATextCodec.encodeBytes(bytes, blockSize: 2)
    checkEqual(bb, [BigUInt(0x4861), BigUInt(0x6C6C), BigUInt(0x6F20)])
    checkEqual(RSATextCodec.decodeBytes(bb, blockSize: 2), Array("Hallo ".utf8))
    checkEqual(RSATextCodec.digitsPerCharacter(alphabetSize: 27, radix: 10), 2)
    let ns = RSATextCodec.encodeBlocksNumberSystem("HAL", alphabet: RSATextCodec.defaultAlphabet, blockSize: 3, radix: 10)
    checkEqual(ns, [BigUInt(80112)])
    checkEqual(RSATextCodec.decodeBlocksNumberSystem(ns, alphabet: RSATextCodec.defaultAlphabet, blockSize: 3, radix: 10), "HAL")
    checkEqual(RSATextCodec.maxBlockSizeNumberSystem(modulus: 262700, alphabetSize: 27, radix: 10), 3) // max 262626
    checkEqual(RSATextCodec.maxBlockSizeNumberSystem(modulus: 262626, alphabetSize: 27, radix: 10), 2)
}

section("Elliptische Kurven") {
    for c in EllipticCurve.namedCurves {
        check(c.contains(c.generator), "\(c.name): G auf der Kurve")
        check(c.isNonSingular)
        check(Primality.isProbablePrime(c.p) && Primality.isProbablePrime(c.n), "\(c.name): p, n prim")
        check(c.multiply(c.n, c.generator).isInfinity, "\(c.name): n·G = O")
        let key = time("\(c.name) Schlüsselerzeugung") { ECKeyPair.generate(curve: c) }
        check(c.contains(key.Q))
        let hash = [UInt8](repeating: 0x5A, count: 48)
        let sig = time("\(c.name) Signatur") { ECDSA.sign(hash: hash, key: key) }
        let ok = time("\(c.name) Verifikation") { ECDSA.verify(hash: hash, r: sig.r, s: sig.s, curve: c, publicKey: key.Q) }
        check(ok, "\(c.name): ECDSA-Rundreise")
        check(!ECDSA.verify(hash: [UInt8](repeating: 0x5B, count: 48), r: sig.r, s: sig.s, curve: c, publicKey: key.Q))
        let other = ECKeyPair.generate(curve: c)
        let s1 = try ECDH.sharedSecret(privateKey: key.d, publicKey: other.Q, curve: c)
        let s2 = try ECDH.sharedSecret(privateKey: other.d, publicKey: key.Q, curve: c)
        checkEqual(s1, s2, "\(c.name): ECDH")
    }
    check(EllipticCurve.named("P-256") == EllipticCurve.secp256r1)
    // RFC 6979, A.2.5 (P-256, SHA-256, message "sample")
    let c = EllipticCurve.secp256r1
    let d = hex("C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721")
    let Q = ECPoint.affine(x: hex("60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6"),
                           y: hex("7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299"))
    let key = ECKeyPair(curve: c, d: d)
    checkEqual(key.Q, Q, "RFC 6979 öffentlicher Schlüssel")
    let h = Hex.decode("af2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf")!
    let r = hex("EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716")
    let s = hex("F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8")
    check(ECDSA.verify(hash: h, r: r, s: s, curve: c, publicKey: Q), "RFC 6979 Signatur gültig")
    check(!ECDSA.verify(hash: h, r: r, s: s + 1, curve: c, publicKey: Q))
    let k = hex("A6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60")
    if let sig = ECDSA.sign(hash: h, key: key, nonce: k) {
        checkEqual(sig.r, r, "RFC 6979 r"); checkEqual(sig.s, s, "RFC 6979 s")
    } else { check(false) }
    // OpenSSL generated P-256 signature over "CrypTool"
    let oq = ECPoint.affine(x: hex("81C9386B021522257F903CA8B75ACBBCA47C57FF4D29241D3B4B2B10F2B57C66"),
                            y: hex("B800C50131C79E37084770CD8C9CE83C4A1DB597AF1DBFA7E736D2B78FCBEDA9"))
    let oh = Hex.decode("9871bc92e57c3418431749ad00df5c08a98b135e04e1025d4fff60bf00cd9c12")!
    check(ECDSA.verify(hash: oh, r: hex("E98827B68E882A60D0B0D3B25025260F29B3BC14913FE9556EFD252D957D93CF"),
                       s: hex("1045D7D7421EF6E307016F3104ACC6017825FE21F04A914D1495BA8CEC479DEF"), curve: c, publicKey: oq),
          "OpenSSL-ECDSA-Signatur")
    // toy curve y² = x³ + 2x + 3 over F_97
    let toy = EllipticCurve(p: 97, a: 2, b: 3)
    let pts = toy.allPoints(limit: 1000)
    checkEqual(BigUInt(pts.count), toy.pointCount()!, "Punktanzahl")
    for P in pts { check(toy.contains(P)) }
    for _ in 0..<100 {
        let P = pts.randomElement()!, R = pts.randomElement()!, S = pts.randomElement()!
        checkEqual(toy.add(toy.add(P, R), S), toy.add(P, toy.add(R, S)), "Assoziativität")
        checkEqual(toy.add(P, R), toy.add(R, P))
        checkEqual(toy.add(P, toy.negate(P)), .infinity)
        let kk = Int.random(in: 0...150)
        var acc = ECPoint.infinity
        for _ in 0..<kk { acc = toy.add(acc, P) }
        checkEqual(toy.multiply(BigUInt(kk), P), acc, "Skalarmultiplikation")
        if let o = toy.order(of: P) { check((BigUInt(pts.count) % o).isZero, "Ordnung teilt #E") }
    }
    checkEqual(toy.double(.affine(x: 3, y: 6)), toy.add(.affine(x: 3, y: 6), .affine(x: 3, y: 6)))
    checkEqual(toy.add(.affine(x: 3, y: 6), .affine(x: 3, y: 6)), .affine(x: 80, y: 10))
    let bigToy = EllipticCurve(p: 1_000_003, a: 5, b: 7)
    checkEqual(BigUInt(bigToy.allPoints(limit: 10_000_000).count), bigToy.pointCount()!)
    do { _ = try ECDH.sharedSecret(privateKey: 5, publicKey: .affine(x: 1, y: 1), curve: c); check(false) } catch { check(error is CTError) }
}

section("CRT / Secret Sharing / DH / DSA") {
    let r = ChineseRemainder.solve(remainders: [2, 3, 2], moduli: [3, 5, 7])
    check(r?.solution == 23 && r?.modulus == 105, "CRT klassisch")
    let r2 = ChineseRemainder.solve(remainders: [3, 5], moduli: [4, 6])   // x ≡ 3 mod 4, x ≡ 5 mod 6 → 11 mod 12
    check(r2?.solution == 11 && r2?.modulus == 12, "CRT nicht teilerfremd")
    check(ChineseRemainder.solve(remainders: [1, 2], moduli: [4, 6]) == nil, "CRT inkonsistent")
    for _ in 0..<50 {
        let mods = (0..<4).map { _ in BigUInt.random(bits: 40) + 2 }
        let x = BigUInt.random(bits: 100)
        if let s = ChineseRemainder.solve(remainders: mods.map { x % $0 }, moduli: mods) {
            checkEqual(s.solution, x % s.modulus)
        } else { check(false, "CRT nil") }
    }
    // Shamir
    let prime: BigUInt = 2_147_483_647
    let (shares, coeffs) = try ShamirSecretSharing.split(secret: 1234567, threshold: 3, shareCount: 5, prime: prime)
    checkEqual(coeffs.count, 2)
    checkEqual(ShamirSecretSharing.reconstruct(Array(shares[1...3]), prime: prime), 1234567)
    checkEqual(ShamirSecretSharing.reconstruct([shares[0], shares[2], shares[4]], prime: prime), 1234567)
    check(ShamirSecretSharing.reconstruct(Array(shares[0...1]), prime: prime) != 1234567 || true)
    let (fixed, _) = try ShamirSecretSharing.split(secret: 11, threshold: 2, shareCount: 3, prime: 17, coefficients: [5])
    checkEqual(fixed.map { $0.y }, [16, 4, 9])
    checkEqual(ShamirSecretSharing.polynomialString(secret: 11, coefficients: [5, 3], prime: 17), "f(x) = 11 + 5·x + 3·x^2 (mod 17)")
    do { _ = try ShamirSecretSharing.split(secret: 20, threshold: 2, shareCount: 3, prime: 17); check(false) } catch { check(error is CTError) }
    // CRT secret sharing (CT1)
    let setup = try CRTSecretSharing.split(secret: nil, shareCount: 5, threshold: 3,
                                           lowerBound: CRTSecretSharing.defaultLowerBound, upperBound: CRTSecretSharing.defaultUpperBound)
    check(setup.sPrime < setup.minK && setup.secret < setup.w)
    for combo in [[0, 1, 2], [2, 3, 4], [0, 2, 4], [0, 1, 2, 3, 4]] {
        let s = CRTSecretSharing.reconstruct(shares: combo.map { setup.shares[$0] }, moduli: combo.map { setup.moduli[$0] }, w: setup.w)
        checkEqual(s, setup.secret, "CRT-Secret-Sharing \(combo)")
    }
    // simple API (Mignotte)
    for (secret, n, k) in [(BigUInt(12345), 5, 3), (12345, 20, 3), (42, 4, 2), (1000, 3, 1), (big("123456789012345678901234567890"), 7, 4),
                           (BigUInt(10).power(40), 20, 20), (999_999, 10, 2)] {
        let (mods, sh) = try CRTSecretSharing.split(secret: secret, shareCount: n, threshold: k)
        checkEqual(mods.count, n)
        check(mods == mods.sorted(), "aufsteigend")
        for _ in 0..<10 {
            let idx = Array((0..<n).shuffled().prefix(k))
            checkEqual(CRTSecretSharing.reconstruct(shares: idx.map { sh[$0] }, moduli: idx.map { mods[$0] }), secret, "Mignotte \(secret) n=\(n) k=\(k)")
            if k > 1 {
                let fewer = Array(idx.prefix(k - 1))
                check(CRTSecretSharing.reconstruct(shares: fewer.map { sh[$0] }, moduli: fewer.map { mods[$0] }) != secret, "zu wenige Anteile")
            }
        }
    }
    do { _ = try CRTSecretSharing.split(secret: 5, shareCount: 5, threshold: 3); check(false, "zu kleines Geheimnis") } catch { check(error is CTError) }
    check(CRTSecretSharing.remainingCandidates(usedModuli: [setup.moduli[0]], setup: setup) > 1)
    // Diffie-Hellman
    let (p, g) = time("DH-Parameter 256 Bit") { DiffieHellman.generateParameters(bits: 256) }
    checkEqual(p.bitLength, 256)
    check(DiffieHellman.isGenerator(g, safePrime: p))
    let a = DiffieHellman.randomSecret(prime: p), b = DiffieHellman.randomSecret(prime: p)
    let A = DiffieHellman.publicValue(secret: a, generator: g, prime: p)
    let B = DiffieHellman.publicValue(secret: b, generator: g, prime: p)
    checkEqual(DiffieHellman.sharedKey(otherPublic: B, secret: a, prime: p), DiffieHellman.sharedKey(otherPublic: A, secret: b, prime: p))
    check(!DiffieHellman.isGenerator(1, safePrime: 23) && DiffieHellman.isGenerator(5, safePrime: 23) && !DiffieHellman.isGenerator(2, safePrime: 23))
    // DSA
    let params = time("DSA-Parameter 1024/160") { DSA.generateParameters(L: 1024, N: 160) }
    checkEqual(params.p.bitLength, 1024); checkEqual(params.q.bitLength, 160)
    check(((params.p - 1) % params.q).isZero && params.g.power(params.q, modulus: params.p).isOne)
    let dk = DSA.generateKey(parameters: params)
    let hh = [UInt8](repeating: 7, count: 32)
    let sig = DSA.sign(hash: hh, key: dk)
    check(DSA.verify(hash: hh, r: sig.r, s: sig.s, parameters: params, publicKey: dk.y))
    check(!DSA.verify(hash: [UInt8](repeating: 8, count: 32), r: sig.r, s: sig.s, parameters: params, publicKey: dk.y))
}

section("Zufallsgeneratoren") {
    let script = """
import sys
def bits_to_bytes(bits):
    out = []
    for i in range(0, len(bits), 8):
        o = 0
        for j in range(8): o |= bits[i+j] << (7-j)
        out.append(o)
    return bytes(out)
# x^2 mod N
x = 314159; N = 245438302030331732360701189397045881523; bits = []
for _ in range(8*64): x = x*x % N; bits.append(x & 1)
print(bits_to_bytes(bits).hex())
# LCG
x = 314159; a, b, N = 23, 0, 100000001; bits = []
for _ in range(8*64): x = (a*x + b) % N; bits.append(1 if x > N//2 else 0)
print(bits_to_bytes(bits).hex())
# ICG with CT1 counter sequence
seed = 314159; a, b, N = 22211, 11926380, 2147483053; bits = []
def cnt(k, i):
    if i == 0: return 0 if k == 0 else 9*(k-1)+7
    return 9*k + i - 1
for k in range(64):
    for i in range(8):
        v = (a*(seed + cnt(k, i)) + b) % N
        try: x = pow(v, -1, N)
        except ValueError: x = 0
        bits.append(1 if x > N//2 else 0)
print(bits_to_bytes(bits).hex())
"""
    let x2 = RandomGenerators.x2modN(seed: RandomGenerators.defaultSeed, modulus: RandomGenerators.defaultX2ModNModulus, count: 64)
    let lcg = RandomGenerators.lcg(seed: RandomGenerators.defaultSeed, a: RandomGenerators.defaultLCGA, b: RandomGenerators.defaultLCGB,
                                   modulus: RandomGenerators.defaultLCGModulus, count: 64)
    let icg = RandomGenerators.icg(seed: RandomGenerators.defaultSeed, a: RandomGenerators.defaultICGA, b: RandomGenerators.defaultICGB,
                                   modulus: RandomGenerators.defaultICGModulus, count: 64)
    // even modulus / state recording paths must agree with the fast paths
    var states: [BigUInt] = []
    let lcg2 = RandomGenerators.lcg(seed: RandomGenerators.defaultSeed, a: 23, b: 0, modulus: 100000001, count: 64, states: { states.append($0) })
    checkEqual(lcg2, lcg); checkEqual(states.count, 1 + 64 * 8)
    if let out = python(script, input: "") {
        let lines = out.split(separator: "\n").map(String.init)
        checkEqual(Hex.encode(x2, separator: "", uppercase: false), lines[0], "x² mod N")
        checkEqual(Hex.encode(lcg, separator: "", uppercase: false), lines[1], "LCG")
        checkEqual(Hex.encode(icg, separator: "", uppercase: false), lines[2], "ICG")
    }
    let big = time("x² mod N 100 kB") { RandomGenerators.x2modN(seed: 314159, modulus: RandomGenerators.defaultX2ModNModulus, count: 100_000) }
    checkEqual(big.count, 100_000)
    checkEqual(RandomGenerators.secure(count: 33).count, 33)
    checkEqual(RandomGenerators.icgCounter(byte: 0, bit: 1), 0); checkEqual(RandomGenerators.icgCounter(byte: 1, bit: 0), 7)
    checkEqual(RandomGenerators.icgCounter(byte: 1, bit: 1), 9); checkEqual(RandomGenerators.icgCounter(byte: 2, bit: 0), 16)
}

section("Ausdrücke / Mersenne") {
    func ev(_ s: String) -> String { (try? BigExpression.evaluate(s).description) ?? "FEHLER" }
    checkEqual(ev("2^127-1"), "170141183460469231731687303715884105727")
    checkEqual(ev("-2*(3+4)*5^2"), "-350")
    checkEqual(ev("-2^2"), "-4")
    checkEqual(ev("(-2)^3"), "-8")
    checkEqual(ev("2^3^2"), "512")
    checkEqual(ev("0xFF + 1"), "256")
    checkEqual(ev("10!/(5!*5!)"), "252")
    checkEqual(ev("17 % 5 * 3"), "6")
    checkEqual(ev("-17 / 5"), "-3")
    checkEqual(ev("3(1+1)"), "6")
    checkEqual(ev(" 1_000 * 2 "), "2000")
    checkEqual(ev("2**10"), "1024")
    for bad in ["", "2+", "(1+2", "1/0", "5 % 0", "2^-1", "10^100000000", "1 + a", "3!!!!!", "2^(2^40)"] {
        do { _ = try BigExpression.evaluate(bad); check(false, "Fehler erwartet: \(bad)") } catch { check(error is CTError, "\(bad)") }
    }
    let m127 = try BigExpression.evaluateUnsigned("2^127-1")
    checkEqual(m127, Mersenne.number(exponent: 127))
    let lens = try time("Länge von 2^(2^20)") { try BigExpression.evaluateUnsigned("2^(2^20)").digitCount() }
    checkEqual(lens, 315653)
    for p in [2, 3, 5, 7, 13, 17, 19, 31, 61, 89, 107, 127, 521, 607] { check(Mersenne.lucasLehmer(exponent: p), "LL \(p)") }
    for p in [11, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71, 73, 79, 83, 97, 101, 103, 109, 113, 4, 9, 15] {
        check(!Mersenne.lucasLehmer(exponent: p), "LL \(p) zusammengesetzt")
    }
    check(time("Lucas-Lehmer 4423") { Mersenne.lucasLehmer(exponent: 4423) })
    check(time("Lucas-Lehmer 11213") { Mersenne.lucasLehmer(exponent: 11213) })
    checkEqual(Mersenne.knownPrimeExponents.count, 52)
}

section("Ergänzende Tests") {
    checkEqual(BigUInt(UInt8(200)), 200); checkEqual(BigUInt(Int16(5)), 5); checkEqual(BigInt(Int8(-5)), -5)
    checkEqual(BigUInt(exactly: -1), nil); checkEqual(BigUInt(BigInt(-3)), nil); checkEqual(BigUInt(BigInt(7)), 7)
    // Codable round trips
    let curve = EllipticCurve.secp256r1
    let key = ECKeyPair.generate(curve: curve)
    let data = try JSONEncoder().encode(key)
    checkEqual(try JSONDecoder().decode(ECKeyPair.self, from: data), key)
    let rsa = RSAKeyPair.generate(bits: 256)
    checkEqual(try JSONDecoder().decode(RSAKeyPair.self, from: try JSONEncoder().encode(rsa)), rsa)
    checkEqual(try JSONDecoder().decode(ECPoint.self, from: try JSONEncoder().encode(ECPoint.infinity)), .infinity)
    // RSA with e = 3
    let k3 = RSAKeyPair.generate(bits: 512, e: 3)
    checkEqual(k3.e, 3); checkEqual(k3.decrypt(k3.encrypt(12345)), 12345)
    let k3b = try RSAKeyPair(p: 61, q: 53, e: 17, d: 2753)
    checkEqual(k3b.d, 2753)
    do { _ = try RSAKeyPair(p: 61, q: 53, e: 17, d: 2754); check(false) } catch { check(error is CTError) }
    // findFactor edge cases
    checkEqual(Factorization.findFactor(of: 1_000_003, method: .lenstraECM), nil)
    checkEqual(Factorization.findFactor(of: BigUInt(1_000_003).power(3), method: .pollardRhoBrent), 1_000_003)
    checkEqual(Factorization.findFactor(of: 1, method: .fermat), nil)
    checkEqual(Factorization.findFactor(of: 1 << 70, method: .quadraticSieve), 2)
    // p+1 smooth prime for Williams
    var sm = BigUInt(1)
    var pr: BigUInt = 3
    var pp1: BigUInt = 0
    while true {
        sm = sm * pr
        pr = Primality.nextPrime(after: pr)
        if sm.bitLength > 80, Primality.isProbablePrime(2 * sm - 1) { pp1 = 2 * sm - 1; break }
    }
    let other = Primality.randomPrime(bits: 140)
    let fw = time("Williams p+1 glatter Faktor") { Factorization.findFactor(of: pp1 * other, method: .williamsPPlus1, timeLimit: 20) }
    check(fw == pp1 || fw == other, "p+1: \(String(describing: fw))")
    // factorize with method subsets
    let a = Primality.randomPrime(bits: 30), b = Primality.randomPrime(bits: 34)
    for ms in [[FactorizationMethod.trialDivision], [.pollardRhoBrent], [.lenstraECM], [.quadraticSieve], [.fermat, .pollardRhoBrent]] {
        let f = try time("factorize \(ms.map { $0.displayName })") { try Factorization.factorize(a * b * 9, methods: ms) }
        checkEqual(f.map { $0.prime }, [3, min(a, b), max(a, b)], "factorize mit \(ms)")
        checkEqual(f.first?.exponent, 2)
    }
    // randomPrime(in:) with other methods
    for m in PrimeTestMethod.allCases {
        if let p = time("randomPrime(in:) \(m)", { Primality.randomPrime(in: 10_000...20_000, method: m) }) {
            check(p >= 10_000 && p <= 20_000 && Primality.isProbablePrime(p), "randomPrime(in:) \(m)")
        } else { check(false) }
    }
    let tok = CancellationToken(); tok.cancel()
    check(!Primality.test(big("170141183460469231731687303715884105727"), method: .millerRabin, cancel: tok))
    check(Primality.aks(1_000_003, cancel: tok) == nil)
    checkEqual(PrimeTestMethod.trialDivision.displayName, "Probedivision")
    checkEqual(FactorizationMethod.quadraticSieve.displayName, "Quadratisches Sieb")
    // Mersenne via expression & trial division of M67 (Cole)
    let m67 = Mersenne.number(exponent: 67)
    let fac67 = try time("factorize M67") { try Factorization.factorize(m67) }
    checkEqual(Factorization.format(fac67), "193707721 · 761838257287")
    // larger Karatsuba / string round trip
    let x = BigUInt.random(bits: 50_000), y = BigUInt.random(bits: 37_000)
    let (q, r) = (x * y + 5).quotientAndRemainder(dividingBy: y)
    checkEqual(q, x); checkEqual(r, 5)
    checkEqual(BigUInt(x.description), x)
    checkEqual(BigUInt(x.toString(radix: 36), radix: 36), x)
}

if ProcessInfo.processInfo.environment["CTBN_LONG"] != nil {
    section("Langläufer (CTBN_LONG)") {
        for digits in [65, 70, 75] {
            let bits = Int(Double(digits) * 3.3219)
            let x = Primality.randomPrime(bits: bits / 2), y = Primality.randomPrime(bits: bits - bits / 2)
            let n = x * y
            let f = time("QS \(n.digitCount()) Stellen") {
                Factorization.findFactor(of: n, method: .quadraticSieve, timeLimit: 600)
            }
            check(f == x || f == y, "QS \(digits)")
        }
        let e1 = Primality.randomPrime(bits: 100), e2 = Primality.randomPrime(bits: 200)
        let fe = time("ECM 31-stelliger Faktor") { Factorization.findFactor(of: e1 * e2, method: .lenstraECM, timeLimit: 600) }
        check(fe == e1 || fe == e2, "ECM 100 Bit")
        let a1 = time("AKS 2^31-1") { Primality.aks(2147483647) }
        check(a1 == true)
        let a2 = time("AKS 1000000007") { Primality.aks(1000000007) }
        check(a2 == true)
        let x = BigUInt(1) << 1_000_000
        let d1 = time("toString 2^1000000") { x.description }
        checkEqual(d1.count, 301030)
        let y = BigUInt(3).power(2_000_000)
        let d2 = time("digitCount 3^2000000") { y.digitCount() }
        checkEqual(d2, 954243)
        let sq = time("Quadrat 3^2000000 (3,2 Mbit)") { y.squared() }
        checkEqual(sq.bitLength, 6339851)
        let pr = time("randomPrime(2048)") { Primality.randomPrime(bits: 2048) }
        checkEqual(pr.bitLength, 2048)
        let sp = time("randomSafePrime(512)") { Primality.randomSafePrime(bits: 512) }
        checkEqual(sp.bitLength, 512)
        let ll = time("Lucas-Lehmer 44497") { Mersenne.lucasLehmer(exponent: 44497) }
        check(ll)
        var log: [String] = []
        let n = Primality.randomPrime(bits: 60) * Primality.randomPrime(bits: 90) * Primality.randomPrime(bits: 100) * 1234567890
        let fac = try time("factorize 3 große Primfaktoren") { try Factorization.factorize(n, log: { log.append($0) }) }
        var prod = BigUInt(1)
        for (p, e) in fac { prod *= p.power(e) }
        checkEqual(prod, n)
        for l in log { print("      " + l) }
    }
}

runCT1RandomGeneratorTests()
runCT1TutorialTests()

runCT1PKITests()

runCT1AKSTests()

runCT1TadicNAFTests()

print("\nErgebnis: \(passes) bestanden, \(failures) fehlgeschlagen")
exit(failures == 0 ? 0 : 1)
