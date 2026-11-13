import Foundation

// MARK: - Arithmetic operators

extension BigUInt {
    public static func + (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        BigUInt(normalizedLimbs: Limbs.add(lhs.limbs, rhs.limbs))
    }

    /// Subtraction; precondition: `lhs >= rhs`.
    public static func - (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        precondition(lhs >= rhs, "BigUInt: underflow in subtraction")
        return BigUInt(normalizedLimbs: Limbs.sub(lhs.limbs, rhs.limbs))
    }

    public static func * (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        if lhs.limbs.count == 1 { return BigUInt(normalizedLimbs: Limbs.mulSmall(rhs.limbs, lhs.limbs[0])) }
        if rhs.limbs.count == 1 { return BigUInt(normalizedLimbs: Limbs.mulSmall(lhs.limbs, rhs.limbs[0])) }
        if lhs.limbs == rhs.limbs { return BigUInt(normalizedLimbs: Limbs.square(lhs.limbs)) }
        return BigUInt(normalizedLimbs: Limbs.mul(lhs.limbs, rhs.limbs))
    }

    /// Truncating division; precondition: divisor != 0.
    public static func / (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        lhs.quotientAndRemainder(dividingBy: rhs).quotient
    }

    /// Remainder; precondition: divisor != 0.
    public static func % (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        if rhs.limbs.count == 1 {
            let r = Limbs.modSmall(lhs.limbs, rhs.limbs[0])
            return BigUInt(r)
        }
        return lhs.quotientAndRemainder(dividingBy: rhs).remainder
    }

    public static func += (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs + rhs }
    public static func -= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs - rhs }
    public static func *= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs * rhs }
    public static func /= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs / rhs }
    public static func %= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs % rhs }

    /// Quotient and remainder of a truncating division (precondition: divisor != 0).
    public func quotientAndRemainder(dividingBy divisor: BigUInt) -> (quotient: BigUInt, remainder: BigUInt) {
        precondition(!divisor.isZero, "Division by zero")
        let (q, r) = Limbs.divMod(limbs, divisor.limbs)
        return (BigUInt(normalizedLimbs: q), BigUInt(normalizedLimbs: r))
    }

    /// Quotient and remainder for a single word divisor.
    public func quotientAndRemainder(dividingBy divisor: UInt64) -> (quotient: BigUInt, remainder: UInt64) {
        precondition(divisor != 0, "Division by zero")
        if limbs.isEmpty { return (BigUInt(), 0) }
        let (q, r) = Limbs.divSmall(limbs, divisor)
        return (BigUInt(normalizedLimbs: q), r)
    }

    /// `self mod m` for a single word modulus (fast path).
    public func remainder(dividingBy m: UInt64) -> UInt64 {
        precondition(m != 0, "Division by zero")
        if limbs.isEmpty { return 0 }
        return Limbs.modSmall(limbs, m)
    }

    /// self * self
    public func squared() -> BigUInt { BigUInt(normalizedLimbs: Limbs.square(limbs)) }

    /// self * m + a for single words.
    public func multiplied(by m: UInt64, adding a: UInt64 = 0) -> BigUInt {
        BigUInt(normalizedLimbs: Limbs.mulSmall(limbs, m, add: a))
    }

    /// `self - rhs` or nil if the result would be negative.
    public func subtractingIfPossible(_ rhs: BigUInt) -> BigUInt? {
        self >= rhs ? self - rhs : nil
    }

    /// |self - rhs|
    public func distance(to rhs: BigUInt) -> BigUInt {
        self >= rhs ? self - rhs : rhs - self
    }

    // MARK: Shifts

    public static func << (lhs: BigUInt, rhs: Int) -> BigUInt {
        if rhs < 0 { return lhs >> (-rhs) }
        return BigUInt(normalizedLimbs: Limbs.shiftLeft(lhs.limbs, rhs))
    }

    public static func >> (lhs: BigUInt, rhs: Int) -> BigUInt {
        if rhs < 0 { return lhs << (-rhs) }
        return BigUInt(normalizedLimbs: Limbs.shiftRight(lhs.limbs, rhs))
    }

    public static func <<= (lhs: inout BigUInt, rhs: Int) { lhs = lhs << rhs }
    public static func >>= (lhs: inout BigUInt, rhs: Int) { lhs = lhs >> rhs }

    // MARK: Bitwise

    public static func & (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = min(lhs.limbs.count, rhs.limbs.count)
        var r = [UInt64](repeating: 0, count: n)
        for i in 0..<n { r[i] = lhs.limbs[i] & rhs.limbs[i] }
        return BigUInt(limbs: r)
    }

    public static func | (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = max(lhs.limbs.count, rhs.limbs.count)
        var r = [UInt64](repeating: 0, count: n)
        for i in 0..<n {
            r[i] = (i < lhs.limbs.count ? lhs.limbs[i] : 0) | (i < rhs.limbs.count ? rhs.limbs[i] : 0)
        }
        return BigUInt(limbs: r)
    }

    public static func ^ (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = max(lhs.limbs.count, rhs.limbs.count)
        var r = [UInt64](repeating: 0, count: n)
        for i in 0..<n {
            r[i] = (i < lhs.limbs.count ? lhs.limbs[i] : 0) ^ (i < rhs.limbs.count ? rhs.limbs[i] : 0)
        }
        return BigUInt(limbs: r)
    }

    public static func &= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs & rhs }
    public static func |= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs | rhs }
    public static func ^= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs ^ rhs }

    /// The lowest `bits` bits (self mod 2^bits).
    public func truncated(toBits bits: Int) -> BigUInt {
        if bits <= 0 { return BigUInt() }
        if bits >= bitLength { return self }
        let w = bits / 64, b = bits % 64
        var r = Array(limbs[0..<(w + (b > 0 ? 1 : 0))])
        if b > 0 { r[w] &= (UInt64(1) << UInt64(b)) &- 1 }
        return BigUInt(limbs: r)
    }

    // MARK: Powers

    /// self^e for e >= 0 (binary exponentiation). Precondition: e >= 0.
    public func power(_ e: Int) -> BigUInt {
        precondition(e >= 0, "Negative exponent")
        if e == 0 { return 1 }
        if isZero { return self }
        if limbs == [1] { return self }
        if limbs == [2] { return BigUInt(1) << e }
        var result = BigUInt(1)
        var base = self
        var k = e
        while true {
            if k & 1 == 1 { result = result * base }
            k >>= 1
            if k == 0 { break }
            base = base.squared()
        }
        return result
    }

    /// 2^e
    public static func powerOfTwo(_ e: Int) -> BigUInt { BigUInt(1) << e }
}
