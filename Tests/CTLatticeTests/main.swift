import Foundation
import CTCommon
import CTBigNum

// Kleiner Testrahmen (wie die übrigen CT*-Tests).
nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var passes = 0

func check(_ cond: Bool, _ msg: @autoclosure () -> String = "", line: Int = #line) {
    if cond { passes += 1 } else { failures += 1; print("  FEHLER Zeile \(line): \(msg())") }
}

func section(_ name: String, _ body: () -> Void) {
    let start = Date()
    body()
    print(name.padding(toLength: 44, withPad: " ", startingAt: 0) + String(format: "%8.3f s", Date().timeIntervalSince(start)))
}

// MARK: - LLL

section("LLL: kürzester Vektor (2D)") {
    // Gitter enthält (1,0) = b1 − 1000000·b2; LLL muss einen Vektor der Länge 1 finden.
    let reduced = Lattice.reduce([[BigInt(1), BigInt(1_000_000)], [BigInt(0), BigInt(1)]])
    var minNorm2 = BigInt(0)
    for (i, v) in reduced.enumerated() {
        let n2 = v[0] * v[0] + v[1] * v[1]
        if i == 0 || n2 < minNorm2 { minNorm2 = n2 }
    }
    check(minNorm2 == BigInt(1), "kürzeste Norm² = \(minNorm2.toString())")
}

section("LLL: Determinante erhalten (3D)") {
    let basis = [[BigInt(2), BigInt(7), BigInt(3)], [BigInt(1), BigInt(5), BigInt(0)], [BigInt(4), BigInt(1), BigInt(6)]]
    func det3(_ m: [[BigInt]]) -> BigInt {
        m[0][0]*(m[1][1]*m[2][2]-m[1][2]*m[2][1])
      - m[0][1]*(m[1][0]*m[2][2]-m[1][2]*m[2][0])
      + m[0][2]*(m[1][0]*m[2][1]-m[1][1]*m[2][0])
    }
    let before = det3(basis).absoluteValue
    let after = det3(Lattice.reduce(basis)).absoluteValue
    check(before == after, "det vorher \(before.toString()) ≠ nachher \(after.toString())")
}

// MARK: - LLL: optimierte Fassung = schlichte Referenz

/// Cohen, Algorithmus 2.6.7, ohne jede Beschleunigung (Stand vor der Optimierung von `Lattice.reduce`).
func referenceLLL(_ basis: [[BigInt]], deltaNum: Int, deltaDen: Int) -> [[BigInt]] {
    let n = basis.count
    let dim = basis[0].count
    var b = [[BigInt]](repeating: [], count: n + 1)
    for i in 1...n { b[i] = basis[i - 1] }
    var d = [BigInt](repeating: BigInt(0), count: n + 1)
    d[0] = BigInt(1)
    var lambda = [[BigInt]](repeating: [BigInt](repeating: BigInt(0), count: n + 1), count: n + 1)
    func dot(_ x: [BigInt], _ y: [BigInt]) -> BigInt {
        var s = BigInt(0)
        for k in 0..<dim { s += x[k] * y[k] }
        return s
    }
    func reduceStep(_ k: Int, _ l: Int) {
        if (BigInt(2) * lambda[k][l].absoluteValue) <= d[l] { return }
        let q = (BigInt(2) * lambda[k][l] + d[l]).floorDivided(by: BigInt(2) * d[l])
        for t in 0..<dim { b[k][t] = b[k][t] - q * b[l][t] }
        lambda[k][l] = lambda[k][l] - q * d[l]
        if l >= 2 { for i in 1...(l - 1) { lambda[k][i] = lambda[k][i] - q * lambda[l][i] } }
    }
    var kMax = 1
    d[1] = dot(b[1], b[1])
    var k = 2
    while k <= n {
        if k > kMax {
            kMax = k
            for j in 1...k {
                var u = dot(b[k], b[j])
                if j >= 2 { for i in 1...(j - 1) { u = (d[i] * u - lambda[k][i] * lambda[j][i]) / d[i - 1] } }
                if j < k { lambda[k][j] = u } else { d[k] = u }
            }
        }
        reduceStep(k, k - 1)
        let dn = BigInt(deltaNum), dd = BigInt(deltaDen)
        if dd * d[k] * d[k - 2] < dn * d[k - 1] * d[k - 1] - dd * lambda[k][k - 1] * lambda[k][k - 1] {
            let lam = lambda[k][k - 1]
            let B = (d[k - 2] * d[k] + lam * lam) / d[k - 1]
            b.swapAt(k, k - 1)
            if k > 2 { for j in 1...(k - 2) { let t = lambda[k][j]; lambda[k][j] = lambda[k - 1][j]; lambda[k - 1][j] = t } }
            if k < kMax {
                for i in (k + 1)...kMax {
                    let t = lambda[i][k]
                    lambda[i][k] = (d[k] * lambda[i][k - 1] - lam * t) / d[k - 1]
                    lambda[i][k - 1] = (B * t + lam * lambda[i][k]) / d[k]
                }
            }
            d[k - 1] = B
            k = max(2, k - 1)
        } else {
            var l = k - 2
            while l >= 1 { reduceStep(k, l); l -= 1 }
            k += 1
        }
    }
    return Array(b[1...n])
}

/// Fester Zufallsgenerator, damit die Testgitter bei jedem Lauf dieselben sind.
nonisolated(unsafe) var latticeSeed: UInt64 = 0x1234_5678_9ABC_DEF0
func fixedRandom(bits: Int) -> BigUInt {
    var v = BigUInt(0)
    var left = bits
    while left > 0 {
        latticeSeed ^= latticeSeed << 13; latticeSeed ^= latticeSeed >> 7; latticeSeed ^= latticeSeed << 17
        let take = min(left, 32)
        v = (v << take) + BigUInt(latticeSeed & ((1 << UInt64(take)) - 1))
        left -= take
    }
    return v | (BigUInt(1) << (bits - 1)) | BigUInt(1)
}

section("LLL: optimiert = Referenz (bitgenau)") {
    // kleine Zahlen (serieller Zweig) und große Zahlen (paralleler Zweig mit gemeinsamem Kehrwert)
    for (n, bits, dn, dd) in [(8, 120, 3, 4), (12, 300, 99, 100), (7, 1400, 3, 4), (8, 1100, 99, 100)] {
        var basis = [[BigInt]]()
        for i in 0..<n {
            var row = [BigInt](repeating: BigInt(0), count: n)
            row[i] = BigInt(1)
            row[n - 1] = BigInt(fixedRandom(bits: bits))
            // dichtere Zeilen, damit auch Einträge außerhalb der letzten Spalte groß werden
            if i % 3 == 1 { row[0] = BigInt(fixedRandom(bits: bits / 2)) }
            basis.append(row)
        }
        let fast = Lattice.reduce(basis, deltaNum: dn, deltaDen: dd)
        let ref = referenceLLL(basis, deltaNum: dn, deltaDen: dd)
        check(fast == ref, "LLL n=\(n) bits=\(bits) δ=\(dn)/\(dd): Basis weicht von der Referenz ab")
    }
}

section("Exakte Division mit gemeinsamem Kehrwert") {
    var wrong = 0, cases = 0
    for trial in 0..<1500 {
        let dl = 1 + Int(fixedRandom(bits: 16).low64 % 40), ql = Int(fixedRandom(bits: 16).low64 % 60)
        var dv = fixedRandom(bits: 64 * dl - Int(fixedRandom(bits: 16).low64 % 63))
        if trial % 7 == 0 { dv = dv << (64 * Int(fixedRandom(bits: 16).low64 % 3)) }   // niederwertiges Wort 0
        if trial % 11 == 0 { dv = (dv >> 1) << 1 }                                     // gerader Divisor
        if trial % 13 == 0 { dv = BigUInt(1) << (64 * dl - 1) }                        // Zweierpotenz
        var qs = [BigUInt]()
        for _ in 0..<3 {
            qs.append(ql == 0 ? BigUInt(fixedRandom(bits: 16).low64 % 3)
                              : fixedRandom(bits: max(1, 64 * ql - Int(fixedRandom(bits: 16).low64 % 64))) - BigUInt(fixedRandom(bits: 16).low64 % 2))
        }
        let got = Lattice.exactQuotients(of: qs.map { $0 * dv }, by: dv)
        for (q, g) in zip(qs, got) { cases += 1; if q != g { wrong += 1 } }
    }
    check(wrong == 0, "\(wrong) von \(cases) Quotienten falsch")
}

// MARK: - Angriff auf stereotype Nachrichten (Coppersmith, e = 3)

section("Stereotype Nachrichten (e=3)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let e = 3
    // Zufällige Nachricht, die unteren 30 Bit sind dem Angreifer unbekannt.
    let m = Primality.randomPrime(bits: 250)
    let u = 30
    let twoU = BigUInt(1) << u
    let x0 = m % twoU
    let known = m - x0
    let c = m.power(e, modulus: N)
    let start = Date()
    let rec = Coppersmith.stereotypedMessage(n: N, e: e, cipher: c, known: known, bound: twoU)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(rec == m, "Nachricht nicht wiederhergestellt (rec=\(rec?.toString() ?? "nil"))")
}

// MARK: - Faktorisieren mit teilweise bekanntem p (höchstwertige Bits)

section("Teilweise bekanntes p (MSB)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let u = 40                       // unbekannte niederwertige Bits von p
    let twoU = BigUInt(1) << u
    let P = p - (p % twoU)           // bekannte höchstwertige Bits
    let start = Date()
    let r = Coppersmith.factorWithKnownBits(n: N, known: P, pBits: 128, unknownBits: u, highBits: true, latticeParameter: 5)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(r != nil && (r!.p == p || r!.p == q), "p nicht gefunden")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

section("Teilweise bekanntes p (LSB)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let u = 38                       // unbekannte höchstwertige Bits von p; untere 90 bekannt
    let s = 128 - u
    let P = p % (BigUInt(1) << s)    // bekannte niederstwertige Bits
    let r = Coppersmith.factorWithKnownBits(n: N, known: P, pBits: 128, unknownBits: u, highBits: false, latticeParameter: 5)
    check(r != nil && (r!.p == p || r!.p == q), "p (LSB) nicht gefunden")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

// MARK: - Angriff auf kleine geheime Schlüssel (Wiener)

section("Kleine geheime Schlüssel (Wiener)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let phi = (p - BigUInt(1)) * (q - BigUInt(1))
    // Kleiner geheimer Exponent d < N^{1/4}.
    var d = Primality.randomPrime(bits: 50)
    while d.gcd(phi) != BigUInt(1) { d = Primality.randomPrime(bits: 50) }
    guard let e = d.inverse(modulo: phi) else { check(false, "kein e"); return }
    let start = Date()
    let r = Coppersmith.wienerSmallSecretKey(n: N, e: e)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(r != nil && r!.d == d, "d nicht gefunden (\(r?.d.toString() ?? "nil"))")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

// MARK: - Kleine geheime Schlüssel (Boneh-Durfee / Blömer-May), δ > 0,25

section("Blömer/May (δ ≈ 0,25, über Wiener)") {
    let nb = 100
    var p = Primality.randomPrime(bits: nb / 2)
    var q = Primality.randomPrime(bits: nb / 2)
    while p == q { q = Primality.randomPrime(bits: nb / 2) }
    let N = p * q
    let phi = (p - BigUInt(1)) * (q - BigUInt(1))
    // d mit genau ⌊N-Bitlänge/4⌋ Bit ⇒ δ ≈ 0,25 – jenseits der sicheren Wiener-Grenze (N^0,25/3).
    let dbits = N.bitLength / 4
    var d = BigUInt.random(in: (BigUInt(1) << (dbits - 1))...(BigUInt(1) << dbits))
    while d.gcd(phi) != BigUInt(1) { d = BigUInt.random(in: (BigUInt(1) << (dbits - 1))...(BigUInt(1) << dbits)) }
    guard let e = d.inverse(modulo: phi) else { check(false, "kein e"); return }
    let start = Date()
    let r = BloemerMay.attack(n: N, e: e, delta: 0.25, m: 5, t: 2)
    print(String(format: "      Laufzeit %.3f s, dim=%d, realdelta=%.3f", Date().timeIntervalSince(start), r?.latticeDimension ?? 0, Double(d.bitLength)/Double(N.bitLength)))
    check(r != nil && r!.p == max(p, q) && r!.q == min(p, q), "p/q nicht gefunden")
    if let r { check(r.p * r.q == N && r.d == d, "p·q ≠ N oder d falsch") }
}

// MARK: - Seitenkanalangriff auf Textbook-RSA (Kühn)

section("Seitenkanalangriff (Textbook-RSA)") {
    // RSA-512 wie in CT1 (Bob), significantBits = 128 ⇒ L(N)=512 > 3·128+3 = 387.
    let p = Primality.randomPrime(bits: 256)
    let q = Primality.randomPrime(bits: 256)
    let N = p * q
    let phi = (p - BigUInt(1)) * (q - BigUInt(1))
    var e = BigUInt(65537)
    while e.gcd(phi) != BigUInt(1) { e = e + BigUInt(2) }
    guard let d = e.inverse(modulo: phi) else { check(false, "kein d"); return }
    let bits = 128
    // Sessionkey K ist ein b-Bit-Schlüssel (Textbook-RSA ohne Polsterung), c = K^e mod N
    let K = BigUInt.random(below: BigUInt(1) << bits)
    let c = K.power(e, modulus: N)
    let trueSecret = K % (BigUInt(1) << bits)
    let start = Date()
    do {
        let r = try SideChannel.run(n: N, e: e, d: d, cipher: c, significantBits: bits)
        print(String(format: "      Laufzeit %.3f s, %d Anfragen", Date().timeIntervalSince(start), r.queries))
        check(r.secret == trueSecret, "Geheimnis falsch\n  erhalten:  \(r.secret.toString())\n  erwartet:  \(trueSecret.toString())")
    } catch {
        check(false, "Angriff warf Ausnahme: \(error)")
    }
}

print("\nCTLatticeTests: \(passes) bestanden, \(failures) fehlgeschlagen")
exit(failures == 0 ? 0 : 1)
