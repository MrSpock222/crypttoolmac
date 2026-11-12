import Foundation
import CTCommon

/// Factorisation methods offered by CT1 ("Faktorisieren einer Zahl").
public enum FactorizationMethod: String, CaseIterable, Codable, Sendable {
    case trialDivision, pollardRhoBrent, pollardPMinus1, williamsPPlus1, lenstraECM, fermat, quadraticSieve

    /// Short German name as used by CT1.
    public var displayName: String {
        switch self {
        case .trialDivision: return "Brute-Force"
        case .pollardRhoBrent: return "Brent"
        case .pollardPMinus1: return "Pollard"
        case .williamsPPlus1: return "Williams"
        case .lenstraECM: return "Lenstra"
        case .fermat: return "Fermat"
        case .quadraticSieve: return "Quadratisches Sieb"
        }
    }

    /// Longer German description of the algorithm.
    public var longName: String {
        switch self {
        case .trialDivision: return "Probedivision (Brute-Force)"
        case .pollardRhoBrent: return "Pollard-Rho-Verfahren (Variante von Brent)"
        case .pollardPMinus1: return "Pollards (p−1)-Verfahren"
        case .williamsPPlus1: return "Williams' (p+1)-Verfahren"
        case .lenstraECM: return "Lenstras Elliptische-Kurven-Methode (ECM)"
        case .fermat: return "Fermat-Faktorisierung"
        case .quadraticSieve: return "Quadratisches Sieb (MPQS)"
        }
    }
}

/// Integer factorisation.
public enum Factorization {

    // MARK: - Public API

    /// Tries to find a non-trivial factor (1 < f < n) of `n` with the given method within
    /// `timeLimit` seconds. Returns nil if no factor was found (n prime, time limit reached,
    /// cancelled, or method failed). Blocking – call from a background task. ECM and the
    /// quadratic sieve use all CPU cores. Even numbers always yield 2, perfect powers their base.
    public static func findFactor(of n: BigUInt, method: FactorizationMethod, timeLimit: TimeInterval = 60,
                                  cancel: CancellationToken? = nil) -> BigUInt? {
        let deadline = Deadline(seconds: timeLimit, cancel: cancel)
        return findFactor(n, method: method, deadline: deadline, level: 100, log: nil)
    }

    /// Complete factorisation into primes, sorted ascending: [(prime, exponent)].
    ///
    /// The methods are tried in the given order with growing time budgets until every cofactor
    /// is prime (if `.trialDivision` is selected, primes < 2^16 are removed first). Throws
    /// `CTError` on cancellation, for n = 0, or if the selected methods cannot split a
    /// composite cofactor. `log` receives German progress messages (called on the calling
    /// thread). Blocking – call from a background task.
    public static func factorize(_ n: BigUInt,
                                 methods: [FactorizationMethod] = [.trialDivision, .pollardRhoBrent, .lenstraECM, .quadraticSieve],
                                 cancel: CancellationToken? = nil,
                                 log: ((String) -> Void)? = nil) throws -> [(prime: BigUInt, exponent: Int)] {
        if n.isZero { throw CTError("Die Zahl 0 kann nicht faktorisiert werden.") }
        if n.isOne { return [] }
        let methods = methods.isEmpty ? [.trialDivision, .pollardRhoBrent, .lenstraECM, .quadraticSieve] : methods
        var primes: [BigUInt: Int] = [:]
        var work: [(BigUInt, Int)] = [(n, 1)]

        func addPrime(_ p: BigUInt, _ e: Int) {
            primes[p, default: 0] += e
        }

        // cheap trial division by small primes first
        if methods.contains(.trialDivision) {
            var m = n
            var found: [BigUInt] = []
            for p in Primality.smallPrimes {
                if m.isOne { break }
                if m.remainder(dividingBy: p) == 0 {
                    var e = 0
                    while m.remainder(dividingBy: p) == 0 {
                        m = m.quotientAndRemainder(dividingBy: p).quotient
                        e += 1
                    }
                    addPrime(BigUInt(p), e)
                    found.append(BigUInt(p))
                }
                if BigUInt(p * p) > m { break }
            }
            if !found.isEmpty {
                log?("Brute-Force: kleine Primfaktoren \(found.map { $0.description }.joined(separator: ", "))")
            }
            work = m.isOne ? [] : [(m, 1)]
        }

        while let (m, mult) = work.popLast() {
            if cancel?.isCancelled == true { throw CTError("Faktorisierung abgebrochen.") }
            if m.isOne { continue }
            if Primality.isProbablePrime(m) {
                addPrime(m, mult)
                continue
            }
            if let (b, k) = m.perfectPower() {
                log?("\(m) ist die \(k)-te Potenz von \(b)")
                work.append((b, mult * k))
                continue
            }
            log?("Suche Faktor von \(m) (\(m.digitCount()) Stellen)")
            var factor: BigUInt? = nil
            var level = 0
            while factor == nil {
                if cancel?.isCancelled == true { throw CTError("Faktorisierung abgebrochen.") }
                var anyUnlimited = false
                for method in methods {
                    let (budget, unlimited) = budgetFor(method, level: level, digits: m.digitCount())
                    if budget <= 0 { continue }
                    anyUnlimited = anyUnlimited || unlimited
                    let start = Date()
                    let deadline = Deadline(seconds: budget, cancel: cancel)
                    if let f = findFactor(m, method: method, deadline: deadline, level: level, log: log) {
                        log?(String(format: "%@: Faktor %@ gefunden (%.2f s)", method.displayName, f.description,
                                    Date().timeIntervalSince(start)))
                        factor = f
                        break
                    }
                    if cancel?.isCancelled == true { throw CTError("Faktorisierung abgebrochen.") }
                }
                if factor == nil {
                    level += 1
                    if level > 12 && !anyUnlimited {
                        throw CTError("Die Zahl \(m) konnte mit den gewählten Verfahren nicht faktorisiert werden.")
                    }
                }
            }
            let f = factor!
            let g = m / f
            work.append((f, mult))
            work.append((g, mult))
        }
        return primes.map { (prime: $0.key, exponent: $0.value) }.sorted { $0.prime < $1.prime }
    }

    /// Formats a factorisation like "2^3 · 3 · 5^2".
    public static func format(_ factors: [(prime: BigUInt, exponent: Int)], multiplicationSign: String = " · ") -> String {
        if factors.isEmpty { return "1" }
        return factors.map { $0.exponent == 1 ? $0.prime.description : "\($0.prime)^\($0.exponent)" }
            .joined(separator: multiplicationSign)
    }

    /// Time budget (seconds) of a method at a given escalation level; second value tells whether
    /// the method keeps running at high levels (so the orchestration can go on forever).
    static func budgetFor(_ m: FactorizationMethod, level: Int, digits: Int) -> (TimeInterval, Bool) {
        let scale = pow(2.0, Double(level))
        switch m {
        case .trialDivision:
            // small primes were already removed; extended trial division rarely pays off
            return (0.02 * scale, true)
        case .pollardRhoBrent:
            return (0.1 * scale, true)
        case .pollardPMinus1, .williamsPPlus1:
            return (level < 10 ? 0.2 * scale : 0, false)
        case .fermat:
            return (level < 10 ? 0.1 * scale : 0, false)
        case .lenstraECM:
            return (0.5 * scale, true)
        case .quadraticSieve:
            // the sieve runs to completion once it is started for small enough numbers
            if digits <= 45 { return (.infinity, true) }
            if digits <= 70 { return (level >= 1 ? .infinity : 0, true) }
            return (level >= 2 ? 30 * scale : 0, true)
        }
    }

    // MARK: - Dispatcher

    static func findFactor(_ n: BigUInt, method: FactorizationMethod, deadline: Deadline, level: Int,
                           log: ((String) -> Void)?) -> BigUInt? {
        if n < 4 { return nil }
        if n.isEven { return 2 }
        if Primality.isProbablePrime(n) { return nil }
        // perfect powers break most of the algorithms – handle them directly
        if let (b, _) = n.perfectPower() { return b }
        let f: BigUInt?
        switch method {
        case .trialDivision: f = trialDivision(n, deadline: deadline)
        case .pollardRhoBrent: f = pollardRhoBrent(n, deadline: deadline)
        case .pollardPMinus1: f = pollardPMinus1(n, deadline: deadline, level: level)
        case .williamsPPlus1: f = williamsPPlus1(n, deadline: deadline, level: level)
        case .lenstraECM: f = ecm(n, deadline: deadline, startLevel: level >= 100 ? 0 : level / 2, log: log)
        case .fermat: f = fermat(n, deadline: deadline)
        case .quadraticSieve: f = quadraticSieve(n, deadline: deadline, log: log)
        }
        if let f = f, f > 1, f < n, (n % f).isZero { return f }
        return nil
    }

    // MARK: - Trial division

    static func trialDivision(_ n: BigUInt, deadline: Deadline) -> BigUInt? {
        if let f = Primality.smallFactor(n) { return BigUInt(f) == n ? nil : BigUInt(f) }
        let root = n.squareRoot()
        let bound64 = root.uint64Value ?? UInt64.max
        let offsets: [UInt64] = [1, 7, 11, 13, 17, 19, 23, 29]
        var base: UInt64 = 65520
        var counter = 0
        let n64 = n.uint64Value
        while base <= bound64 {
            for o in offsets {
                let p = base + o
                if p < 65536 { continue }
                if p > bound64 { break }
                let r = n64.map { $0 % p } ?? n.remainder(dividingBy: p)
                if r == 0 { return BigUInt(p) }
            }
            base += 30
            counter += 1
            if counter & 0x3FFF == 0 && deadline.expired { return nil }
            if base > UInt64.max - 64 { break }
        }
        return nil
    }

    // MARK: - Pollard rho (Brent)

    static func pollardRhoBrent(_ n: BigUInt, deadline: Deadline) -> BigUInt? {
        if let n64 = n.uint64Value { return rho64(n64, deadline: deadline).map { BigUInt($0) } }
        // registers: 0 y, 1 x, 2 ys, 3 q, 4 c, 5 tmp
        let ctx = MontgomeryContext(modulus: n, registers: 8)
        let m = 256
        while !deadline.expired {
            ctx.set(0, BigUInt.random(below: n))
            ctx.set(4, BigUInt.random(below: n - 3) + 1)
            ctx.setOne(3)
            var g = BigUInt(1)
            var r = 1
            var iterations = 0
            repeat {
                ctx.copy(1, 0)
                for _ in 0..<r { ctx.sqr(0, 0); ctx.add(0, 0, 4) }
                var k = 0
                while k < r && g.isOne {
                    ctx.copy(2, 0)
                    let lim = min(m, r - k)
                    for _ in 0..<lim {
                        ctx.sqr(0, 0); ctx.add(0, 0, 4)
                        ctx.sub(5, 1, 0)
                        ctx.mul(3, 3, 5)
                    }
                    g = ctx.raw(3).gcd(n)
                    k += m
                    iterations += lim
                    if iterations & 0x3FFF < m, deadline.expired { return nil }
                }
                r *= 2
            } while g.isOne
            if g == n {
                // backtrack from ys
                repeat {
                    ctx.sqr(2, 2); ctx.add(2, 2, 4)
                    ctx.sub(5, 1, 2)
                    g = ctx.raw(5).gcd(n)
                } while g.isOne
            }
            if g != n && !g.isOne { return g }
        }
        return nil
    }

    static func rho64(_ n: UInt64, deadline: Deadline) -> UInt64? {
        if n % 2 == 0 { return 2 }
        let m = 128
        while !deadline.expired {
            var y = UInt64.random(in: 0..<n)
            let c = UInt64.random(in: 1..<(n - 1))
            var q: UInt64 = 1
            var g: UInt64 = 1
            var r = 1
            var x: UInt64 = 0
            var ys: UInt64 = 0
            @inline(__always) func f(_ v: UInt64) -> UInt64 {
                let s = BigUInt.mulMod64(v, v, n)
                let (t, o) = s.addingReportingOverflow(c)
                return (o || t >= n) ? t &- n : t
            }
            var iterations = 0
            repeat {
                x = y
                for _ in 0..<r { y = f(y) }
                var k = 0
                while k < r && g == 1 {
                    ys = y
                    for _ in 0..<min(m, r - k) {
                        y = f(y)
                        q = BigUInt.mulMod64(q, x > y ? x - y : y - x, n)
                    }
                    g = BigUInt.gcd64(q, n)
                    k += m
                    iterations += m
                    if iterations & 0xFFFF == 0, deadline.expired { return nil }
                }
                r *= 2
            } while g == 1
            if g == n {
                repeat {
                    ys = f(ys)
                    g = BigUInt.gcd64(x > ys ? x - ys : ys - x, n)
                } while g == 1
            }
            if g != n && g != 1 { return g }
        }
        return nil
    }

    // MARK: - Fermat

    static func fermat(_ n: BigUInt, deadline: Deadline) -> BigUInt? {
        if n.isEven { return 2 }
        var a = n.squareRoot()
        if a * a < n { a += 1 }
        let r0 = a * a - n
        if r0.isPerfectSquare {
            let b = r0.squareRoot()
            let f = a - b
            return f > 1 ? f : nil
        }
        // residue filters: track a mod M and r mod M with M = 64·63·65·11
        let mods: [Int] = [64, 63, 65, 11]
        var qr: [[Bool]] = []
        for m in mods {
            var t = [Bool](repeating: false, count: m)
            for i in 0..<m { t[(i * i) % m] = true }
            qr.append(t)
        }
        let M = 64 * 63 * 65 * 11
        var am = Int(a.remainder(dividingBy: UInt64(M)))
        var rm = Int(r0.remainder(dividingBy: UInt64(M)))
        var i: UInt64 = 0
        let q0 = qr[0], q1 = qr[1], q2 = qr[2], q3 = qr[3]
        while true {
            // r_{i+1} = r_i + 2 a_i + 1, a_{i+1} = a_i + 1
            rm += 2 * am + 1
            if rm >= M { rm %= M }
            am += 1
            if am == M { am = 0 }
            i += 1
            if q0[rm & 63] && q1[rm % 63] && q2[rm % 65] && q3[rm % 11] {
                let ai = a + BigUInt(i)
                let ri = ai * ai - n
                if ri.isPerfectSquare {
                    let b = ri.squareRoot()
                    let f = ai - b
                    return f > 1 ? f : nil
                }
            }
            if i & 0xFFFFF == 0 {
                if deadline.expired { return nil }
                // past (n+9)/6 only the trivial factorisation n = n·1 remains
                if (a + BigUInt(i)) > (n + 9) / 6 { return nil }
            }
        }
    }

    // MARK: - Pollard p-1

    /// B1 bounds used per escalation level for p−1 / p+1.
    static func pm1Bounds(level: Int) -> [UInt64] {
        let all: [UInt64] = [10_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000]
        return Array(all.prefix(min(all.count, 2 + level)))
    }

    /// Largest exponent k with p^k <= bound, where small primes (p < 1000) use bound² so that
    /// high powers of 2, 3, … are covered as well.
    @inline(__always)
    static func pm1Exponent(_ p: UInt64, _ bound: UInt64) -> Int {
        let b = p < 1000 ? bound.multipliedReportingOverflow(by: bound).partialValue : bound
        var k = 0
        var q: UInt64 = 1
        while q <= b / p { q *= p; k += 1 }
        return k
    }

    static func pollardPMinus1(_ n: BigUInt, deadline: Deadline, level: Int) -> BigUInt? {
        // registers: 0 a, 1 tmp, 2.. pow table (16)
        let ctx = MontgomeryContext(modulus: n, registers: 24)
        ctx.set(0, 3)
        var prevB1: UInt64 = 1
        for B1 in pm1Bounds(level: level) {
            // stage 1 extension from prevB1 to B1
            var e = BigUInt(1)
            var it = PrimeSieveIterator(from: 2, to: B1)
            var count = 0
            while let p = it.next() {
                // exponent increase for p: p^(k_new - k_old)
                let kNew = pm1Exponent(p, B1)
                let kOld = p <= prevB1 ? pm1Exponent(p, prevB1) : 0
                for _ in 0..<(kNew - kOld) { e = e.multiplied(by: p) }
                if e.bitLength > 1024 {
                    ctx.pow(1, 0, e, tableBase: 2)
                    ctx.copy(0, 1)
                    e = 1
                }
                count += 1
                if count & 0xFFF == 0 && deadline.expired { return nil }
            }
            if !e.isOne { ctx.pow(1, 0, e, tableBase: 2); ctx.copy(0, 1) }
            prevB1 = B1
            // gcd(a - 1, n)
            ctx.setOne(1)
            ctx.sub(1, 0, 1)
            let g = ctx.raw(1).gcd(n)
            if g > 1 && g < n { return g }
            if g == n { return nil }
            // stage 2 with V-sequence of P = a + 1/a
            let a = ctx.get(0)
            guard let ainv = a.inverse(modulo: n) else {
                let g2 = a.gcd(n)
                return (g2 > 1 && g2 < n) ? g2 : nil
            }
            let P = (a + ainv) % n
            if let f = lucasStage2(n: n, P: P, B1: B1, B2: B1 * 50, deadline: deadline) { return f }
            if deadline.expired { return nil }
        }
        return nil
    }

    // MARK: - Williams p+1

    static func williamsPPlus1(_ n: BigUInt, deadline: Deadline, level: Int) -> BigUInt? {
        // seeds 2/7 and 6/5 (Montgomery) and a random one
        var seeds: [BigUInt] = []
        if let i7 = BigUInt(7).inverse(modulo: n) { seeds.append((2 * i7) % n) }
        if let i5 = BigUInt(5).inverse(modulo: n) { seeds.append((6 * i5) % n) }
        seeds.append(BigUInt.random(below: n - 3) + 3)
        for B1 in pm1Bounds(level: level) {
            for seed in seeds {
                // registers: 0 V, 1 A, 2 B, 3 two, 4 tmp, 5 base
                let ctx = MontgomeryContext(modulus: n, registers: 8)
                ctx.set(0, seed)
                ctx.set(3, 2)
                var it = PrimeSieveIterator(from: 2, to: B1)
                var count = 0
                while let p = it.next() {
                    // V = V_{p^k}(V)
                    for _ in 0..<pm1Exponent(p, B1) {
                        ctx.copy(5, 0)
                        lucasLadder(ctx, out: 0, outNext: nil, base: 5, m: p, two: 3, a: 1, b: 2)
                    }
                    count += 1
                    if count & 0x3FF == 0 && deadline.expired { return nil }
                }
                ctx.sub(4, 0, 3)
                let g = ctx.raw(4).gcd(n)
                if g > 1 && g < n { return g }
                if g == n { continue }
                let P = ctx.get(0)
                if let f = lucasStage2(n: n, P: P, B1: B1, B2: B1 * 50, deadline: deadline) { return f }
                if deadline.expired { return nil }
            }
        }
        return nil
    }

    /// Lucas ladder: out = V_m(base), outNext = V_{m+1}(base). Uses registers a, b as scratch;
    /// `two` must hold 2. base must differ from out/outNext/a/b.
    static func lucasLadder(_ ctx: MontgomeryContext, out: Int, outNext: Int?, base: Int, m: UInt64,
                            two: Int, a: Int, b: Int) {
        if m == 0 {
            ctx.copy(out, two)
            if let on = outNext { ctx.copy(on, base) }
            return
        }
        ctx.copy(a, base)
        ctx.sqr(b, base)
        ctx.sub(b, b, two)
        var bit = 62 - m.leadingZeroBitCount
        while bit >= 0 {
            if (m >> UInt64(bit)) & 1 == 1 {
                ctx.mul(a, a, b); ctx.sub(a, a, base)
                ctx.sqr(b, b); ctx.sub(b, b, two)
            } else {
                ctx.mul(b, a, b); ctx.sub(b, b, base)
                ctx.sqr(a, a); ctx.sub(a, a, two)
            }
            bit -= 1
        }
        ctx.copy(out, a)
        if let on = outNext { ctx.copy(on, b) }
    }

    /// Baby-step/giant-step stage 2 for p±1 with V-sequences: accumulates ∏ (V_{kd} − V_j) over
    /// all primes q = kd ± j in (B1, B2] and returns gcd with n if non-trivial.
    static func lucasStage2(n: BigUInt, P: BigUInt, B1: UInt64, B2: UInt64, deadline: Deadline) -> BigUInt? {
        let d: UInt64 = B2 >= 10_000_000 ? 2310 : 210
        let half = Int(d / 2)
        var js: [Int] = []
        for j in stride(from: 1, to: half, by: 2) where BigUInt.gcd64(UInt64(j), d) == 1 { js.append(j) }
        // register layout
        let rTwo = 0, rP = 1, rV2 = 2, rA = 3, rB = 4, rAcc = 5, rT = 6
        let rGprev = 7, rG = 8, rGd = 9, rGnext = 10
        let babyBase = 11
        var babyReg = [Int](repeating: -1, count: half + 1)
        for (i, j) in js.enumerated() { babyReg[j] = babyBase + i }
        let rPrev = babyBase + js.count, rCur = rPrev + 1, rNext = rPrev + 2
        let ctx = MontgomeryContext(modulus: n, registers: rNext + 1)
        ctx.set(rTwo, 2)
        ctx.set(rP, P)
        ctx.sqr(rV2, rP); ctx.sub(rV2, rV2, rTwo)
        // odd V_j: V_1 = P, V_3 = P*V_2 - P, V_{j+2} = V_j V_2 - V_{j-2}
        ctx.copy(rPrev, rP)                    // V_{-1} = V_1 (symmetric), used for V_1 → V_3 step
        ctx.copy(rCur, rP)                     // V_1
        if babyReg[1] >= 0 { ctx.copy(babyReg[1], rCur) }
        var j = 1
        while j + 2 < half {
            ctx.mul(rNext, rCur, rV2)
            ctx.sub(rNext, rNext, rPrev)
            ctx.copy(rPrev, rCur)
            ctx.copy(rCur, rNext)
            j += 2
            if babyReg[j] >= 0 { ctx.copy(babyReg[j], rCur) }
        }
        // giant steps: V_d, and (V_{(k-1)d}, V_{kd}) for the first k
        lucasLadder(ctx, out: rGd, outNext: nil, base: rP, m: d, two: rTwo, a: rA, b: rB)
        var it = PrimeSieveIterator(from: B1 + 1, to: B2)
        guard let firstQ = it.next() else { return nil }
        var k = (firstQ + d / 2) / d
        lucasLadder(ctx, out: rGprev, outNext: rG, base: rGd, m: k - 1, two: rTwo, a: rA, b: rB)
        ctx.setOne(rAcc)
        var q: UInt64? = firstQ
        var count = 0
        while let qq = q {
            let kk = (qq + d / 2) / d
            while k < kk {
                ctx.mul(rGnext, rG, rGd)
                ctx.sub(rGnext, rGnext, rGprev)
                ctx.copy(rGprev, rG)
                ctx.copy(rG, rGnext)
                k += 1
            }
            let jj = Int(qq > k * d ? qq - k * d : k * d - qq)
            let br = babyReg[jj]
            if br >= 0 {
                ctx.sub(rT, rG, br)
                ctx.mul(rAcc, rAcc, rT)
            }
            count += 1
            if count & 0x3FFF == 0 && deadline.expired { break }
            q = it.next()
        }
        let g = ctx.raw(rAcc).gcd(n)
        if g > 1 && g < n { return g }
        return nil
    }
}
