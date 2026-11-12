import Foundation
import CTCommon

extension Primality {
    /// Outcome of `aksCT1` (CT1 "AKS-Test (deterministisches Verfahren)").
    public enum AKSOutcome: Sendable, Equatable {
        case prime
        case composite
        case cancelled
        /// The polynomial ring Z_n[X]/(X^r − 1) would not fit into memory (estimated bytes).
        case tooLarge(bytes: Double)
    }

    /// Memory budget (64-bit words) for one Kronecker product in the multi-word AKS.
    public static let aksWordBudget = 32 << 20

    /// AKS for every n (CT1 runs it for all n < 2^8192, see `PrimeTestAKS.cpp`).
    ///
    /// n < 2^62 uses the fast single-word kernel `aks(_:)`; larger n use polynomial arithmetic
    /// with multi-word coefficients (Kronecker substitution + Karatsuba). Like in CT1 this
    /// finishes in practical time only for small n – progress (0…1, fraction of the polynomial
    /// congruences checked, as CT1's progress dialog) and cancellation are supported for all n.
    /// `forceGeneric` runs the multi-word code also for small n (tests).
    public static func aksCT1(_ n: BigUInt, cancel: CancellationToken? = nil, forceGeneric: Bool = false,
                              progress: ((Double) -> Void)? = nil,
                              info: ((AKSInfo) -> Void)? = nil) -> AKSOutcome {
        if !forceGeneric, n < aksLimit {
            switch aks(n, cancel: cancel, progress: progress, info: info) {
            case .some(true): return .prime
            case .some(false): return .composite
            case .none: return .cancelled
            }
        }
        return aksGeneric(n, cancel: cancel, progress: progress, info: info)
    }

    /// log2(n) as Double (accurate to ~1e-15 relative).
    static func approxLog2(_ n: BigUInt) -> Double {
        let bits = n.bitLength
        if bits <= 53 { return Foundation.log2(Double(n.uint64Value ?? 1)) }
        let top = (n >> (bits - 53)).uint64Value ?? 1
        return Foundation.log2(Double(top)) + Double(bits - 53)
    }

    static func aksGeneric(_ n: BigUInt, cancel: CancellationToken?,
                           progress: ((Double) -> Void)?, info: ((AKSInfo) -> Void)?) -> AKSOutcome {
        if n < 2 { return .composite }
        if n < 4 { return .prime }
        if n.perfectPower() != nil { return .composite }
        let log2n = approxLog2(n)
        let maxk = UInt64((log2n * log2n).rounded(.down))
        // r > log2(n)^2, so the polynomial ring needs at least 2·maxk·k words: refuse hopeless
        // cases early (after removing small factors, which CT1's gcd loop would find)
        let minSlot = (2 * n.bitLength + (64 - maxk.leadingZeroBitCount) + 2 + 63) / 64
        if 2.0 * Double(maxk + 2) * Double(minSlot) > Double(aksWordBudget) {
            if let f = smallFactor(n), BigUInt(f) != n { return .composite }
            return .tooLarge(bytes: 2.0 * Double(maxk + 2) * Double(minSlot) * 8 * 3)
        }
        // smallest r with ord_r(n) > log2(n)^2; on the way check 1 < gcd(a, n) < n for a <= r
        var r: UInt64 = 1
        while true {
            r += 1
            if r & 0xFFF == 0, cancel?.isCancelled == true { return .cancelled }
            if BigUInt(r) >= n { return .prime }
            let nr = n.remainder(dividingBy: r)
            let g = BigUInt.gcd64(r, nr)
            if g > 1 { return .composite }
            // ord_r(n) <= r − 1, so the order condition can only hold for r > maxk + 1
            if r <= maxk + 1 { continue }
            var x: UInt64 = 1
            var small = false
            var k: UInt64 = 0
            while k < maxk {
                x = x &* nr % r
                k += 1
                if x == 1 { small = true; break }
                if k & 0xFFFFF == 0, cancel?.isCancelled == true { return .cancelled }
            }
            if !small { break }
        }
        let phi = eulerPhi64(r)
        let limit = Int((Double(phi).squareRoot() * log2n).rounded(.down))
        info?(AKSInfo(r: Int(r), checks: limit))
        let ri = Int(r)
        // Kronecker slot width: product coefficients < 2·r·n^2
        let slotBits = 2 * n.bitLength + (64 - r.leadingZeroBitCount) + 2
        let k = (slotBits + 63) / 64
        let productWords = 2 * ri * k
        if productWords > aksWordBudget {
            return .tooLarge(bytes: Double(productWords) * 8 * 3)
        }
        let nModR = Int(n.remainder(dividingBy: r))
        let bits = n.bitLength
        let totalSteps = Double(max(1, limit)) * Double(bits)
        if limit >= 1 {
            for a in 1...limit {
                if cancel?.isCancelled == true { return .cancelled }
                let done = Double(a - 1) * Double(bits)
                guard let lhs = polyPowXPlusABig(UInt64(a), n: n, r: ri, slotWords: k, cancel: cancel,
                                                 step: { s in progress?((done + Double(s)) / totalSteps) }) else {
                    return .cancelled
                }
                let aBig = BigUInt(UInt64(a)) % n
                for i in 0..<ri {
                    var expected = BigUInt()
                    if i == nModR { expected = BigUInt(1) }
                    if i == 0 { expected = (expected + aBig) % n }
                    if lhs[i] != expected { return .composite }
                }
                progress?(Double(a) / Double(limit))
            }
        }
        progress?(1)
        return .prime
    }

    /// (X + a)^n in Z_n[X]/(X^r − 1) with BigUInt coefficients; nil if cancelled.
    /// `step` receives the number of processed exponent bits.
    static func polyPowXPlusABig(_ a: UInt64, n: BigUInt, r: Int, slotWords k: Int,
                                 cancel: CancellationToken?, step: (Int) -> Void) -> [BigUInt]? {
        var p = [BigUInt](repeating: BigUInt(), count: r)
        p[0] = BigUInt(a) % n
        if r > 1 { p[1] = BigUInt(1) } else { p[0] = (p[0] + 1) % n }
        let bits = n.bitLength
        var b = bits - 2
        var processed = 1
        while b >= 0 {
            if cancel?.isCancelled == true { return nil }
            // square via Kronecker substitution
            var packed = [UInt64](repeating: 0, count: r * k)
            for i in 0..<r {
                let l = p[i].limbs
                for j in 0..<l.count { packed[i * k + j] = l[j] }
            }
            let sq = Limbs.square(packed)
            if cancel?.isCancelled == true { return nil }
            func slot(_ j: Int) -> BigUInt {
                let s = j * k
                if s >= sq.count { return BigUInt() }
                return BigUInt(limbs: Array(sq[s..<min(s + k, sq.count)]))
            }
            for i in 0..<r {
                var v = slot(i)
                if i + r < 2 * r - 1 { v = v + slot(i + r) }
                p[i] = v % n
            }
            if n.bit(at: b) {
                // multiply by (X + a): new[i] = a·p[i] + p[i−1]
                let last = p[r - 1]
                var i = r - 1
                while i >= 0 {
                    let prev = i > 0 ? p[i - 1] : last
                    p[i] = (p[i].multiplied(by: a) + prev) % n
                    i -= 1
                }
            }
            b -= 1
            processed += 1
            step(processed)
        }
        return p
    }
}
