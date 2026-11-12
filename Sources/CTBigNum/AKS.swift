import Foundation
import CTCommon

extension Primality {
    /// Parameters of an AKS run (for display in the UI).
    public struct AKSInfo: Sendable, Hashable {
        /// The modulus r of the polynomial ring Z_n[X]/(X^r − 1).
        public var r: Int
        /// Number of polynomial congruences (X + a)^n ≡ X^n + a that have to be checked.
        public var checks: Int
    }

    /// AKS primality test (Agrawal–Kayal–Saxena, "PRIMES is in P", v6) with real polynomial
    /// arithmetic in Z_n[X]/(X^r − 1).
    ///
    /// Returns nil if cancelled or if n ≥ 2^62 (not supported). Practical only for small n: a few
    /// seconds for primes up to ~2^24, minutes beyond 2^32. `progress` receives values in 0…1.
    public static func aks(_ n: BigUInt, cancel: CancellationToken? = nil,
                           progress: ((Double) -> Void)? = nil,
                           info: ((AKSInfo) -> Void)? = nil) -> Bool? {
        guard let nn = n.uint64Value, nn < (1 << 62) else { return nil }
        if nn < 2 { return false }
        if nn < 4 { return true }
        // 1. perfect power?
        if n.perfectPower() != nil { return false }
        // 2. smallest r with ord_r(n) > log2(n)^2
        let log2n = Foundation.log2(Double(nn))
        let maxk = Int((log2n * log2n).rounded(.down))
        var r: UInt64 = 1
        while true {
            r += 1
            if cancel?.isCancelled == true { return nil }
            let g = BigUInt.gcd64(r, nn)
            // 3. 1 < gcd(a, n) < n for some a <= r → composite
            if g > 1 && g < nn { return false }
            // 4. n <= r → prime
            if r >= nn { return true }
            if g == 1 {
                let nr = nn % r
                var x: UInt64 = 1
                var orderTooSmall = false
                for _ in 1...maxk {
                    x = x * nr % r
                    if x == 1 { orderTooSmall = true; break }
                }
                if !orderTooSmall { break }
            }
        }
        // 5. polynomial checks for a = 1 … ⌊√φ(r)·log2 n⌋
        let phi = eulerPhi64(r)
        let limit = Int((Double(phi).squareRoot() * log2n).rounded(.down))
        info?(AKSInfo(r: Int(r), checks: limit))
        let ri = Int(r)
        let nModR = Int(nn % r)
        if limit >= 1 {
            for a in 1...limit {
                if cancel?.isCancelled == true { return nil }
                let am = UInt64(a) % nn
                let lhs = polyPowXPlusA(am, exponent: nn, r: ri, n: nn)
                // rhs = X^(n mod r) + a
                for i in 0..<ri {
                    var expected: UInt64 = 0
                    if i == nModR { expected = 1 }
                    if i == 0 { expected = (expected + am) % nn }
                    if lhs[i] != expected { return false }
                }
                if a % 4 == 0 { progress?(Double(a) / Double(limit)) }
            }
        }
        progress?(1)
        // 6. prime
        return true
    }

    static func eulerPhi64(_ n: UInt64) -> UInt64 {
        var result = n
        var m = n
        var p: UInt64 = 2
        while p * p <= m {
            if m % p == 0 {
                while m % p == 0 { m /= p }
                result -= result / p
            }
            p += 1
        }
        if m > 1 { result -= result / m }
        return result
    }

    /// (X + a)^e in Z_n[X]/(X^r − 1), coefficients reduced mod n (n < 2^62).
    static func polyPowXPlusA(_ a: UInt64, exponent e: UInt64, r: Int, n: UInt64) -> [UInt64] {
        var p = [UInt64](repeating: 0, count: r)
        // start with X + a
        p[0] = a % n
        if r > 1 { p[1] = (p[1] + 1) % n } else { p[0] = (p[0] + 1) % n }
        let bits = 64 - e.leadingZeroBitCount
        var lo = [UInt64](repeating: 0, count: 2 * r)
        var hi = [UInt64](repeating: 0, count: 2 * r)
        var top = [UInt64](repeating: 0, count: 2 * r)
        var b = bits - 2
        while b >= 0 {
            polySquare(&p, r: r, n: n, lo: &lo, hi: &hi, top: &top)
            if (e >> UInt64(b)) & 1 == 1 {
                // multiply by (X + a): new[i] = a·p[i] + p[i-1]
                let last = p[r - 1]
                var i = r - 1
                while i >= 0 {
                    let prev = i > 0 ? p[i - 1] : last
                    let (h, l) = p[i].multipliedFullWidth(by: a)
                    let t = n.dividingFullWidth((h % n, l)).remainder
                    var s = t &+ prev
                    if s >= n { s -= n }
                    p[i] = s
                    i -= 1
                }
            }
            b -= 1
        }
        return p
    }

    /// p = p^2 mod (X^r − 1, n) with three-word accumulation.
    static func polySquare(_ p: inout [UInt64], r: Int, n: UInt64,
                           lo: inout [UInt64], hi: inout [UInt64], top: inout [UInt64]) {
        lo.withUnsafeMutableBufferPointer { lp in
        hi.withUnsafeMutableBufferPointer { hp in
        top.withUnsafeMutableBufferPointer { tp in
        p.withUnsafeMutableBufferPointer { pp in
            polySquareRaw(pp.baseAddress!, r, n, lp.baseAddress!, hp.baseAddress!, tp.baseAddress!)
        }}}}
    }

    /// Pointer kernel of `polySquare` (static and not inlined so the loops optimise well).
    @inline(never)
    static func polySquareRaw(_ pp: UnsafeMutablePointer<UInt64>, _ r: Int, _ n: UInt64,
                              _ lp: UnsafeMutablePointer<UInt64>, _ hp: UnsafeMutablePointer<UInt64>,
                              _ tp: UnsafeMutablePointer<UInt64>) {
        let m = 2 * r
        for k in 0..<m { lp[k] = 0; hp[k] = 0; tp[k] = 0 }
        // off-diagonal products
        for i in 0..<r {
            let pi = pp[i]
            if pi == 0 { continue }
            var j = i + 1
            while j < r {
                let (h, l) = pi.multipliedFullWidth(by: pp[j])
                let k = i + j
                let (s1, o1) = lp[k].addingReportingOverflow(l)
                lp[k] = s1
                let (s2, o2) = hp[k].addingReportingOverflow(h &+ (o1 ? 1 : 0))
                hp[k] = s2
                tp[k] &+= (o2 ? 1 : 0)
                j += 1
            }
        }
        // double
        for k in 0..<m {
            tp[k] = (tp[k] << 1) | (hp[k] >> 63)
            hp[k] = (hp[k] << 1) | (lp[k] >> 63)
            lp[k] = lp[k] << 1
        }
        // diagonal
        for i in 0..<r {
            let (h, l) = pp[i].multipliedFullWidth(by: pp[i])
            let k = 2 * i
            let (s1, o1) = lp[k].addingReportingOverflow(l)
            lp[k] = s1
            let (s2, o2) = hp[k].addingReportingOverflow(h &+ (o1 ? 1 : 0))
            hp[k] = s2
            tp[k] &+= (o2 ? 1 : 0)
        }
        // fold X^(r+k) = X^k and reduce
        for k in 0..<r {
            var v = reduce3(tp[k], hp[k], lp[k], n)
            if k + r < m {
                v &+= reduce3(tp[k + r], hp[k + r], lp[k + r], n)
                if v >= n { v -= n }
            }
            pp[k] = v
        }
    }

    @inline(__always)
    static func reduce3(_ t: UInt64, _ h: UInt64, _ l: UInt64, _ n: UInt64) -> UInt64 {
        var x = t % n
        x = n.dividingFullWidth((x, h)).remainder
        x = n.dividingFullWidth((x, l)).remainder
        return x
    }
}
