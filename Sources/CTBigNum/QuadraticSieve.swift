import Foundation
import CTCommon

extension Factorization {
    /// Multiple polynomial quadratic sieve (MPQS, A = q²) with single large prime variation and
    /// Gaussian elimination over GF(2). Practical up to ~60–70 decimal digits.
    static func quadraticSieve(_ n: BigUInt, deadline: Deadline, log: ((String) -> Void)?) -> BigUInt? {
        if n.bitLength < 50 {
            // too small for a sieve – Pollard rho is instantaneous here
            return pollardRhoBrent(n, deadline: deadline)
        }
        let qs = QuadraticSieve(n: n, log: log)
        return qs.run(deadline: deadline)
    }
}

/// Smoothness relation Y² ≡ (−1)^s · ∏ p_i^e_i · L² (mod N).
struct QSRelation {
    var y: BigUInt
    /// (column, exponent) pairs; column 0 = −1, column i ≥ 1 = factor base prime i−1.
    var factors: [(Int32, Int32)]
    /// Large primes whose square divides the product (from combined partial relations).
    var largePrimes: [UInt64]
}

final class QuadraticSieve: @unchecked Sendable {
    let N: BigUInt
    let k: UInt64
    let kN: BigUInt
    /// Factor base primes (fb[0] = 2).
    var fb: [UInt64] = []
    /// sqrt(kN) mod p
    var roots: [UInt64] = []
    var logs: [UInt8] = []
    /// first factor base index that is sieved
    var sieveStart = 1
    let M: Int
    let fbSize: Int
    let largePrimeBound: UInt64
    let threshold: UInt8
    let log: ((String) -> Void)?

    // shared relation store
    private let lock = NSLock()
    private var fulls: [QSRelation] = []
    private var partials: [UInt64: QSRelation] = [:]
    private var foundFactor: BigUInt?
    private var nextQ: UInt64 = 0
    private var polyCount = 0

    init(n: BigUInt, log: ((String) -> Void)?) {
        N = n
        self.log = log
        let digits = n.digitCount()
        // parameter table: (digits, factor base size, sieve half-length M)
        let table: [(Int, Int, Int)] = [
            (15, 60, 4096), (20, 90, 8192), (25, 130, 16384), (30, 200, 16384), (35, 300, 32768),
            (40, 450, 32768), (45, 700, 49152), (50, 1000, 65536), (55, 1400, 65536), (60, 2000, 98304),
            (65, 2700, 98304), (70, 3600, 131072), (75, 4800, 131072), (80, 6000, 196608),
            (90, 9000, 262144), (100, 14000, 327680),
        ]
        var fbs = table.last!.1, mm = table.last!.2
        for i in 0..<table.count {
            if digits <= table[i].0 {
                if i == 0 { fbs = table[0].1; mm = table[0].2; break }
                let (d0, f0, m0) = table[i - 1], (d1, f1, m1) = table[i]
                let t = Double(digits - d0) / Double(d1 - d0)
                fbs = Int(Double(f0) + t * Double(f1 - f0))
                mm = t < 0.5 ? m0 : m1
                break
            }
        }
        fbSize = fbs
        M = mm
        k = QuadraticSieve.chooseMultiplier(n)
        kN = n.multiplied(by: k)
        // factor base
        fb = [2]
        roots = [kN.isOdd ? 1 : 0]
        logs = [1]
        var it = PrimeSieveIterator(from: 3, to: 100_000_000)
        while fb.count < fbSize, let p = it.next() {
            let r = kN.remainder(dividingBy: p)
            if r == 0 {
                if k % p == 0 {
                    fb.append(p); roots.append(0); logs.append(UInt8(Foundation.log2(Double(p)).rounded()))
                }
                continue
            }
            if BigUInt.powMod64(r, (p - 1) / 2, p) == 1 {
                fb.append(p)
                roots.append(QuadraticSieve.sqrtMod(r, p))
                logs.append(UInt8(Foundation.log2(Double(p)).rounded()))
            }
        }
        // primes below 40 are not sieved (their contribution is accounted for in the threshold)
        sieveStart = fb.firstIndex(where: { $0 >= 40 }) ?? fb.count
        let pmax = fb.last!
        largePrimeBound = min(pmax * 60, pmax * pmax)
        let logQ = Foundation.log2(Double(M)) + kN.log2Value / 2 - 0.5
        let t = logQ - Foundation.log2(Double(largePrimeBound)) - 3.5
        threshold = UInt8(max(10, min(120, t)))
        // first q ≈ sqrt(sqrt(2kN)/M), larger than the largest factor base prime
        let targetA = (kN.log2Value + 1) / 2 - Foundation.log2(Double(M))
        let q0 = pow(2.0, targetA / 2)
        nextQ = max(UInt64(min(q0, 9e18)), pmax + 2) | 3
    }

    /// Knuth–Schroeppel multiplier selection.
    static func chooseMultiplier(_ n: BigUInt) -> UInt64 {
        let candidates: [UInt64] = [1, 3, 5, 7, 11, 13, 15, 17, 19, 21, 23, 29, 31, 33, 35, 37, 39, 41,
                                    43, 47, 51, 53, 55, 57, 59, 61, 65, 67, 69, 71, 73]
        let smallP = Primality.sieve(upTo: 2000).dropFirst().map { UInt64($0) }
        var best: UInt64 = 1
        var bestScore = -Double.infinity
        for kk in candidates {
            let kn = n.multiplied(by: kk)
            var score = -0.5 * Foundation.log(Double(kk))
            switch kn.low64 & 7 {
            case 1: score += 2 * Foundation.log(2.0)
            case 5: score += Foundation.log(2.0)
            case 3, 7: score += 0.5 * Foundation.log(2.0)
            default: break
            }
            for p in smallP {
                let lp = Foundation.log(Double(p))
                if kk % p == 0 {
                    score += lp / Double(p)
                } else {
                    let r = kn.remainder(dividingBy: p)
                    if r != 0 && BigUInt.powMod64(r, (p - 1) / 2, p) == 1 { score += 2 * lp / Double(p - 1) }
                }
            }
            if score > bestScore { bestScore = score; best = kk }
        }
        return best
    }

    /// Square root of a modulo the odd prime p (a is a QR), Tonelli–Shanks on 64-bit values.
    static func sqrtMod(_ a: UInt64, _ p: UInt64) -> UInt64 {
        let a = a % p
        if a == 0 { return 0 }
        if p % 4 == 3 { return BigUInt.powMod64(a, (p + 1) / 4, p) }
        var q = p - 1
        var s = 0
        while q & 1 == 0 { q >>= 1; s += 1 }
        var z: UInt64 = 2
        while BigUInt.powMod64(z, (p - 1) / 2, p) != p - 1 { z += 1 }
        var m = s
        var c = BigUInt.powMod64(z, q, p)
        var t = BigUInt.powMod64(a, q, p)
        var r = BigUInt.powMod64(a, (q + 1) / 2, p)
        while t != 1 {
            var i = 0
            var tt = t
            while tt != 1 { tt = BigUInt.mulMod64(tt, tt, p); i += 1 }
            var b = c
            for _ in 0..<(m - i - 1) { b = BigUInt.mulMod64(b, b, p) }
            m = i
            c = BigUInt.mulMod64(b, b, p)
            t = BigUInt.mulMod64(t, c, p)
            r = BigUInt.mulMod64(r, b, p)
        }
        return r
    }

    @inline(__always)
    static func inv32(_ a: UInt64, _ p: UInt64) -> UInt64 {
        // extended Euclid for small values (p < 2^32)
        var r0 = Int64(p), r1 = Int64(a % p)
        var t0: Int64 = 0, t1: Int64 = 1
        while r1 != 0 {
            let q = r0 / r1
            (r0, r1) = (r1, r0 - q * r1)
            (t0, t1) = (t1, t0 - q * t1)
        }
        if t0 < 0 { t0 += Int64(p) }
        return UInt64(t0)
    }

    private func takeQ() -> UInt64? {
        lock.lock(); defer { lock.unlock() }
        if foundFactor != nil { return nil }
        while true {
            let q = nextQ
            nextQ += 4
            if q % 4 != 3 { continue }
            if !Primality.isPrime64(q) { continue }
            let r = kN.remainder(dividingBy: q)
            if r == 0 { continue }
            if BigUInt.powMod64(r, (q - 1) / 2, q) != 1 { continue }
            polyCount += 1
            return q
        }
    }

    private var relationCount: Int {
        lock.lock(); defer { lock.unlock() }
        return fulls.count
    }

    private var needed: Int { fb.count + 1 + 40 }

    /// Adds relations found by a worker; returns true when enough relations are collected.
    private func submit(_ newFull: [QSRelation], _ newPartial: [(UInt64, QSRelation)]) -> Bool {
        lock.lock(); defer { lock.unlock() }
        fulls.append(contentsOf: newFull)
        for (L, rel) in newPartial {
            if let other = partials[L] {
                if other.y == rel.y { continue }
                var combined = QSRelation(y: (other.y * rel.y) % N, factors: [], largePrimes: [L])
                combined.factors = QuadraticSieve.merge(other.factors, rel.factors)
                fulls.append(combined)
            } else {
                partials[L] = rel
            }
        }
        return fulls.count >= needed || foundFactor != nil
    }

    private func offerFactor(_ f: BigUInt) {
        lock.lock(); if foundFactor == nil { foundFactor = f }; lock.unlock()
    }

    static func merge(_ a: [(Int32, Int32)], _ b: [(Int32, Int32)]) -> [(Int32, Int32)] {
        var d: [Int32: Int32] = [:]
        for (c, e) in a { d[c, default: 0] += e }
        for (c, e) in b { d[c, default: 0] += e }
        return d.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    func run(deadline: Deadline) -> BigUInt? {
        // small factors up to the largest factor base prime (the sieve cannot use them)
        var it = PrimeSieveIterator(from: 2, to: fb.last! + 1)
        while let p = it.next() {
            if N.remainder(dividingBy: p) == 0 { return BigUInt(p) }
        }
        log?("Quadratic sieve: \(N.digitCount()) digits, multiplier \(k), factor base \(fb.count) primes up to \(fb.last!), sieve interval 2·\(M)")
        let start = Date()
        let done = ParallelSearchState()
        DispatchQueue.concurrentPerform(iterations: Factorization.workerCount) { _ in
            let worker = QSWorker(qs: self)
            while !done.isDone && !deadline.expired {
                guard let q = self.takeQ() else { done.offer(1); break }
                var full: [QSRelation] = []
                var partial: [(UInt64, QSRelation)] = []
                if let f = worker.sievePolynomial(q: q, full: &full, partial: &partial) {
                    self.offerFactor(f)
                    done.offer(1)
                    break
                }
                if self.submit(full, partial) { done.offer(1) }
            }
        }
        if let f = foundFactor { return f }
        if deadline.expired && relationCount < needed { return nil }
        log?(String(format: "Quadratic sieve: %d relations from %d polynomials collected in %.2f s, linear algebra ...",
                    fulls.count, polyCount, Date().timeIntervalSince(start)))
        return linearAlgebra()
    }

    /// Gaussian elimination over GF(2) and square root step.
    private func linearAlgebra() -> BigUInt? {
        let rels = fulls
        let R = rels.count
        let C = fb.count + 1
        let wc = (C + 63) / 64
        let wr = (R + 63) / 64
        var mat = [UInt64](repeating: 0, count: R * wc)
        var hist = [UInt64](repeating: 0, count: R * wr)
        for (i, rel) in rels.enumerated() {
            for (c, e) in rel.factors where e & 1 == 1 {
                mat[i * wc + Int(c) / 64] ^= 1 << UInt64(Int(c) % 64)
            }
            hist[i * wr + i / 64] |= 1 << UInt64(i % 64)
        }
        var isPivot = [Bool](repeating: false, count: R)
        mat.withUnsafeMutableBufferPointer { mp in
        hist.withUnsafeMutableBufferPointer { hp in
            for c in 0..<C {
                let w = c / 64, bit = UInt64(1) << UInt64(c % 64)
                var piv = -1
                for r in 0..<R where !isPivot[r] && mp[r * wc + w] & bit != 0 { piv = r; break }
                if piv < 0 { continue }
                isPivot[piv] = true
                for r in 0..<R where r != piv && !isPivot[r] && mp[r * wc + w] & bit != 0 {
                    for k in w..<wc { mp[r * wc + k] ^= mp[piv * wc + k] }
                    for k in 0..<wr { hp[r * wr + k] ^= hp[piv * wr + k] }
                }
            }
        }}
        // dependencies = non-pivot rows (all zero now)
        for r in 0..<R where !isPivot[r] {
            var x = BigUInt(1)
            var z = BigUInt(1)
            var exps = [Int](repeating: 0, count: C)
            for i in 0..<R where hist[r * wr + i / 64] & (1 << UInt64(i % 64)) != 0 {
                let rel = rels[i]
                x = (x * rel.y) % N
                for (c, e) in rel.factors { exps[Int(c)] += Int(e) }
                for L in rel.largePrimes { z = z.multiplied(by: L) % N }
            }
            var ok = true
            for c in 0..<C where exps[c] & 1 == 1 { ok = false; break }
            if !ok { continue }
            for c in 1..<C where exps[c] > 0 {
                z = (z * BigUInt(fb[c - 1]).power(BigUInt(exps[c] / 2), modulus: N)) % N
            }
            let diff = x >= z ? x - z : z - x
            let g = diff.gcd(N)
            if g > 1 && g < N { return g }
        }
        return nil
    }
}

/// Per-thread sieving state.
final class QSWorker {
    let qs: QuadraticSieve
    var sieve: [UInt8]
    var soln1: [Int]
    var soln2: [Int]

    init(qs: QuadraticSieve) {
        self.qs = qs
        sieve = [UInt8](repeating: 0, count: 2 * qs.M + 8)
        soln1 = [Int](repeating: 0, count: qs.fb.count)
        soln2 = [Int](repeating: 0, count: qs.fb.count)
    }

    /// Sieves the polynomial for A = q². Returns a factor of N if one shows up by accident.
    func sievePolynomial(q: UInt64, full: inout [QSRelation], partial: inout [(UInt64, QSRelation)]) -> BigUInt? {
        let N = qs.N, kN = qs.kN, M = qs.M
        let qb = BigUInt(q)
        let A = qb * qb
        // t = sqrt(kN) mod q, lift to B with B² ≡ kN mod q²
        let t = BigUInt.powMod64(kN.remainder(dividingBy: q), (q + 1) / 4, q)
        let tb = BigUInt(t)
        let c0 = ((kN - tb * tb) / qb).remainder(dividingBy: q)
        guard let inv2t = BigUInt.inverse64((2 * t) % q, q) else { return nil }
        let u = BigUInt.mulMod64(c0, inv2t, q)
        var B = tb + qb.multiplied(by: u)
        if B >= A { B = B % A }
        // C = (B² − kN) / A  (exact division)
        let C_int = (BigInt(B * B) - BigInt(kN)) / BigInt(A)
        guard let qinv = qb.inverse(modulo: N) else {
            let g = qb.gcd(N)
            return (g > 1 && g < N) ? g : nil
        }
        // roots for each sieved prime
        let fb = qs.fb, roots = qs.roots, logs = qs.logs
        let size = 2 * M
        for i in qs.sieveStart..<fb.count {
            let p = fb[i]
            if roots[i] == 0 { soln1[i] = -1; continue }
            let am = BigUInt.mulMod64(q % p, q % p, p)
            let ainv = QuadraticSieve.inv32(am, p)
            let bm = B.remainder(dividingBy: p)
            let tp = roots[i]
            let r1 = BigUInt.mulMod64(ainv, (tp + p - bm) % p, p)
            let r2 = BigUInt.mulMod64(ainv, (2 * p - tp - bm) % p, p)
            let mp = UInt64(M) % p
            soln1[i] = Int((r1 + mp) % p)
            soln2[i] = Int((r2 + mp) % p)
        }
        // sieve
        let initVal = UInt8(128 - Int(qs.threshold))
        sieve.withUnsafeMutableBufferPointer { sp in
            let s = sp.baseAddress!
            s.update(repeating: initVal, count: size)
            for i in qs.sieveStart..<fb.count {
                let s1 = soln1[i]
                if s1 < 0 { continue }
                let p = Int(fb[i])
                let lp = logs[i]
                var j = s1
                while j < size { s[j] &+= lp; j += p }
                let s2 = soln2[i]
                if s2 != s1 {
                    j = s2
                    while j < size { s[j] &+= lp; j += p }
                }
            }
        }
        // scan for candidates (high bit set)
        var candidates: [Int] = []
        sieve.withUnsafeBufferPointer { sp in
            sp.baseAddress!.withMemoryRebound(to: UInt64.self, capacity: size / 8) { w in
                for i in 0..<(size / 8) where w[i] & 0x8080_8080_8080_8080 != 0 {
                    for b in 0..<8 where sp[i * 8 + b] & 0x80 != 0 { candidates.append(i * 8 + b) }
                }
            }
        }
        if candidates.isEmpty { return nil }
        let A_int = BigInt(A), B_int = BigInt(B)
        let twoB = B_int + B_int
        for idx in candidates {
            let x = idx - M
            let xb = BigInt(x)
            let qv = (A_int * xb + twoB) * xb + C_int
            if qv.isZero { continue }
            var mag = qv.magnitude
            var factors: [(Int32, Int32)] = []
            if qv.isNegative { factors.append((0, 1)) }
            // 2
            let tz = mag.trailingZeroBitCount
            if tz > 0 { mag >>= tz; factors.append((1, Int32(tz))) }
            for i in 1..<fb.count {
                let p = fb[i]
                if i >= qs.sieveStart && soln1[i] >= 0 {
                    let pi = Int(p)
                    let d1 = (idx - soln1[i]) % pi, d2 = (idx - soln2[i]) % pi
                    if d1 != 0 && d2 != 0 { continue }
                }
                var e: Int32 = 0
                while true {
                    let (qq, r) = mag.quotientAndRemainder(dividingBy: p)
                    if r != 0 { break }
                    mag = qq
                    e += 1
                }
                if e > 0 { factors.append((Int32(i + 1), e)) }
                if mag.isOne { break }
            }
            // Y = (A x + B) / q mod N
            let axb = (A_int * xb + B_int).modulo(N)
            let y = (axb * qinv) % N
            if mag.isOne {
                full.append(QSRelation(y: y, factors: factors, largePrimes: []))
            } else if let L = mag.uint64Value, L < qs.largePrimeBound {
                if N.remainder(dividingBy: L) == 0 { return BigUInt(L) }
                partial.append((L, QSRelation(y: y, factors: factors, largePrimes: [])))
            }
        }
        return nil
    }
}
