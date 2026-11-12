import Foundation
import CTCommon

/// Shared state of a parallel search (first result wins).
final class ParallelSearchState: @unchecked Sendable {
    private let lock = NSLock()
    private var _result: BigUInt?
    private var _counter = 0
    var result: BigUInt? { lock.lock(); defer { lock.unlock() }; return _result }
    var isDone: Bool { lock.lock(); defer { lock.unlock() }; return _result != nil }
    func offer(_ v: BigUInt) { lock.lock(); if _result == nil { _result = v }; lock.unlock() }
    /// Returns the next work item index.
    func nextIndex() -> Int { lock.lock(); defer { lock.unlock() }; _counter += 1; return _counter - 1 }
}

extension Factorization {
    /// ECM parameter levels (expected factor size in decimal digits, B1, number of curves),
    /// classic Silverman–Wagstaff values for B2 = 100·B1.
    static let ecmLevels: [(digits: Int, b1: UInt64, curves: Int)] = [
        (10, 300, 8), (15, 2_000, 25), (20, 11_000, 90), (25, 50_000, 300), (30, 250_000, 700),
        (35, 1_000_000, 1_800), (40, 3_000_000, 5_100), (45, 11_000_000, 10_600),
        (50, 43_000_000, 19_300), (55, 110_000_000, 49_000), (60, 260_000_000, 124_000),
    ]

    /// Number of worker threads used for ECM and the quadratic sieve.
    static var workerCount: Int { max(1, ProcessInfo.processInfo.activeProcessorCount - 1) }

    /// Lenstra's elliptic curve method with Montgomery curves (Suyama parametrisation),
    /// Montgomery ladder in stage 1 and a baby-step/giant-step standard continuation in stage 2.
    /// Curves run in parallel on all cores.
    static func ecm(_ n: BigUInt, deadline: Deadline, startLevel: Int, log: ((String) -> Void)?) -> BigUInt? {
        let state = ParallelSearchState()
        let level0 = min(startLevel, ecmLevels.count - 1)
        for li in level0..<ecmLevels.count {
            let lv = ecmLevels[li]
            log?("ECM: B1 = \(lv.b1), bis zu \(lv.curves) Kurven (Faktoren bis ca. \(lv.digits) Stellen)")
            let counter = ParallelSearchState()
            DispatchQueue.concurrentPerform(iterations: workerCount) { _ in
                while !state.isDone && !deadline.expired {
                    let c = counter.nextIndex()
                    if c >= lv.curves { break }
                    let sigma = BigUInt(UInt64.random(in: 6...(1 << 31)))
                    if let f = ecmCurve(n, sigma: sigma, B1: lv.b1, B2: lv.b1 * 100, deadline: deadline) {
                        state.offer(f)
                    }
                }
            }
            if let f = state.result { return f }
            if deadline.expired { return nil }
        }
        return nil
    }

    // Register layout for one ECM curve.
    private static let rX = 0, rZ = 1, rA24 = 2, rT1 = 3, rT2 = 4, rT3 = 5, rT4 = 6
    private static let rX0 = 7, rZ0 = 8, rX1 = 9, rZ1 = 10, rXP = 11, rZP = 12
    private static let rAcc = 13, rGX = 14, rGZ = 15, rCX = 16, rCZ = 17, rNX = 18, rNZ = 19
    private static let rPX = 20, rPZ = 21, rQX = 22, rQZ = 23, rDX = 24, rDZ = 25, rTmpX = 26, rTmpZ = 27
    private static let babyBase = 28

    /// xDBL on a Montgomery curve: (xo:zo) = 2·(x:z).
    @inline(__always)
    static func xDBL(_ c: MontgomeryContext, _ xo: Int, _ zo: Int, _ x: Int, _ z: Int) {
        c.add(rT1, x, z); c.sqr(rT1, rT1)          // s = (x+z)^2
        c.sub(rT2, x, z); c.sqr(rT2, rT2)          // d = (x-z)^2
        c.sub(rT3, rT1, rT2)                       // t = s - d = 4xz
        c.mul(xo, rT1, rT2)                        // X2 = s·d
        c.mul(rT4, rT3, rA24); c.add(rT4, rT4, rT2)
        c.mul(zo, rT3, rT4)                        // Z2 = t·(d + a24·t)
    }

    /// xADD: (xo:zo) = P + Q given the difference D = P − Q.
    @inline(__always)
    static func xADD(_ c: MontgomeryContext, _ xo: Int, _ zo: Int, _ xp: Int, _ zp: Int,
                     _ xq: Int, _ zq: Int, _ xd: Int, _ zd: Int) {
        c.sub(rT1, xp, zp); c.add(rT2, xq, zq); c.mul(rT1, rT1, rT2)   // u
        c.add(rT3, xp, zp); c.sub(rT4, xq, zq); c.mul(rT3, rT3, rT4)   // v
        c.add(rT2, rT1, rT3); c.sqr(rT2, rT2)                          // (u+v)^2
        c.sub(rT4, rT1, rT3); c.sqr(rT4, rT4)                          // (u-v)^2
        c.mul(xo, zd, rT2)
        c.mul(zo, xd, rT4)
    }

    /// Montgomery ladder: (R0, R1) = (k·P, (k+1)·P) for P = (xp:zp), k >= 1.
    /// Results in (rX0:rZ0) and (rX1:rZ1). P registers must not be rX0…rZ1.
    static func ladder(_ c: MontgomeryContext, k: UInt64, xp: Int, zp: Int) {
        c.copy(rX0, xp); c.copy(rZ0, zp)
        xDBL(c, rX1, rZ1, xp, zp)
        var bit = 62 - k.leadingZeroBitCount
        while bit >= 0 {
            if (k >> UInt64(bit)) & 1 == 1 {
                xADD(c, rX0, rZ0, rX0, rZ0, rX1, rZ1, xp, zp)
                xDBL(c, rX1, rZ1, rX1, rZ1)
            } else {
                xADD(c, rX1, rZ1, rX0, rZ0, rX1, rZ1, xp, zp)
                xDBL(c, rX0, rZ0, rX0, rZ0)
            }
            bit -= 1
        }
    }

    /// Runs one ECM curve with Suyama parameter sigma. Returns a non-trivial factor or nil.
    static func ecmCurve(_ n: BigUInt, sigma: BigUInt, B1: UInt64, B2: UInt64, deadline: Deadline) -> BigUInt? {
        // Suyama: u = σ²−5, v = 4σ, x0 = u³, z0 = v³, a24 = (v−u)³(3u+v) / (16u³v)
        let u = (sigma * sigma + n - 5) % n
        let v = (4 * sigma) % n
        let u3 = u.power(3, modulus: n)
        let v3 = v.power(3, modulus: n)
        let vmu = (v + n - u) % n
        let num = (vmu.power(3, modulus: n) * ((3 * u + v) % n)) % n
        let den = (16 * u3 * v) % n
        guard let deninv = den.inverse(modulo: n) else {
            let g = den.gcd(n)
            return (g > 1 && g < n) ? g : nil
        }
        let a24 = (num * deninv) % n
        let d: UInt64 = B1 >= 10_000 ? 2310 : 210
        let half = Int(d / 2)
        var js: [Int] = []
        for j in stride(from: 1, to: half, by: 2) where BigUInt.gcd64(UInt64(j), d) == 1 { js.append(j) }
        let c = MontgomeryContext(modulus: n, registers: babyBase + 2 * js.count + 2)
        c.set(rX, u3)
        c.set(rZ, v3)
        c.set(rA24, a24)

        // Stage 1
        var it = PrimeSieveIterator(from: 2, to: B1)
        var count = 0
        while let p = it.next() {
            var q = p
            while q <= B1 / p { q *= p }
            c.copy(rXP, rX); c.copy(rZP, rZ)
            ladder(c, k: q, xp: rXP, zp: rZP)
            c.copy(rX, rX0); c.copy(rZ, rZ0)
            count += 1
            if count & 0x1FF == 0 && deadline.expired { return nil }
        }
        let g1 = c.raw(rZ).gcd(n)
        if g1 > 1 && g1 < n { return g1 }
        if g1 == n { return nil }

        // Stage 2: baby steps j·Q (odd j < d/2, gcd(j, d) = 1)
        var babyReg = [Int](repeating: -1, count: half + 1)
        for (i, j) in js.enumerated() { babyReg[j] = babyBase + 2 * i }
        // Q1 = Q in (rPX:rPZ) as "previous", Q2 = 2Q in (rDX:rDZ)
        c.copy(rQX, rX); c.copy(rQZ, rZ)                    // current = 1·Q
        if babyReg[1] >= 0 { c.copy(babyReg[1], rX); c.copy(babyReg[1] + 1, rZ) }
        xDBL(c, rDX, rDZ, rX, rZ)                           // 2Q
        // 3Q = 2Q + Q (diff Q)
        c.copy(rPX, rX); c.copy(rPZ, rZ)                    // previous = 1·Q (for j=1: prev used as diff Q_{-1} = Q)
        var j = 1
        while j + 2 < half {
            // next = cur + 2Q, diff = cur − 2Q = Q_{j−2}; for j = 1 the diff is Q_{−1} ≅ Q
            xADD(c, rTmpX, rTmpZ, rQX, rQZ, rDX, rDZ, rPX, rPZ)
            c.copy(rPX, rQX); c.copy(rPZ, rQZ)
            c.copy(rQX, rTmpX); c.copy(rQZ, rTmpZ)
            j += 2
            if babyReg[j] >= 0 { c.copy(babyReg[j], rQX); c.copy(babyReg[j] + 1, rQZ) }
        }
        // giant step G = d·Q
        c.copy(rXP, rX); c.copy(rZP, rZ)
        ladder(c, k: d, xp: rXP, zp: rZP)
        c.copy(rGX, rX0); c.copy(rGZ, rZ0)
        var pit = PrimeSieveIterator(from: B1 + 1, to: B2)
        guard let firstQ = pit.next() else { return nil }
        var k = (firstQ + d / 2) / d
        if k == 0 { k = 1 }
        // (cur, next) = (k·G, (k+1)·G)
        c.copy(rXP, rGX); c.copy(rZP, rGZ)
        ladder(c, k: k, xp: rXP, zp: rZP)
        c.copy(rCX, rX0); c.copy(rCZ, rZ0)
        c.copy(rNX, rX1); c.copy(rNZ, rZ1)
        c.setOne(rAcc)
        var qv: UInt64? = firstQ
        count = 0
        while let q = qv {
            let kk = (q + d / 2) / d
            while k < kk {
                // new = next + G, diff = next − G = cur
                xADD(c, rTmpX, rTmpZ, rNX, rNZ, rGX, rGZ, rCX, rCZ)
                c.copy(rCX, rNX); c.copy(rCZ, rNZ)
                c.copy(rNX, rTmpX); c.copy(rNZ, rTmpZ)
                k += 1
            }
            let jj = Int(q > k * d ? q - k * d : k * d - q)
            if jj <= half {
                let br = babyReg[jj]
                if br >= 0 {
                    // X_k·Z_j − X_j·Z_k
                    c.mul(rT1, rCX, br + 1)
                    c.mul(rT2, br, rCZ)
                    c.sub(rT1, rT1, rT2)
                    c.mul(rAcc, rAcc, rT1)
                }
            }
            count += 1
            if count & 0x3FFF == 0 && deadline.expired { break }
            qv = pit.next()
        }
        let g2 = c.raw(rAcc).gcd(n)
        if g2 > 1 && g2 < n { return g2 }
        return nil
    }
}
