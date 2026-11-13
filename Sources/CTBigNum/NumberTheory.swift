import Foundation
import Security

// MARK: - GCD, inverse, roots

extension BigUInt {
    /// Greatest common divisor (gcd(0, 0) = 0).
    public func gcd(_ other: BigUInt) -> BigUInt {
        var a = self, b = other
        if a.isZero { return b }
        if b.isZero { return a }
        while !b.isZero {
            if let x = a.uint64Value, let y = b.uint64Value {
                return BigUInt(BigUInt.gcd64(x, y))
            }
            (a, b) = (b, a % b)
        }
        return a
    }

    static func gcd64(_ a: UInt64, _ b: UInt64) -> UInt64 {
        var x = a, y = b
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    /// Least common multiple.
    public func lcm(_ other: BigUInt) -> BigUInt {
        if isZero || other.isZero { return BigUInt() }
        return (self / gcd(other)) * other
    }

    /// Multiplicative inverse modulo `m`, or nil if gcd(self, m) != 1 (or m <= 1).
    public func inverse(modulo m: BigUInt) -> BigUInt? {
        if m.isZero { return nil }
        if m.isOne { return nil }
        let a = self % m
        if a.isZero { return nil }
        if let mm = m.uint64Value {
            guard let r = BigUInt.inverse64(a.limbs[0], mm) else { return nil }
            return BigUInt(r)
        }
        // extended Euclid keeping only the coefficient of `a`; signs are tracked separately
        var r0 = m, r1 = a
        var t0 = BigUInt(), t1 = BigUInt(1)
        var t0neg = false, t1neg = false
        while !r1.isZero {
            let (q, r) = r0.quotientAndRemainder(dividingBy: r1)
            // t2 = t0 - q*t1
            let qt1 = q * t1
            var t2: BigUInt
            var t2neg: Bool
            if t0neg == t1neg {
                // t0 - q*t1 with equal signs
                if t0 >= qt1 { t2 = t0 - qt1; t2neg = t0neg } else { t2 = qt1 - t0; t2neg = !t0neg }
            } else {
                t2 = t0 + qt1; t2neg = t0neg
            }
            if t2.isZero { t2neg = false }
            (r0, r1) = (r1, r)
            (t0, t0neg, t1, t1neg) = (t1, t1neg, t2, t2neg)
        }
        guard r0.isOne else { return nil }
        let res = t0 % m
        return (t0neg && !res.isZero) ? m - res : res
    }

    /// Inverse of a modulo m for 64-bit values (nil if not invertible).
    static func inverse64(_ a: UInt64, _ m: UInt64) -> UInt64? {
        if m <= 1 { return nil }
        var r0 = m, r1 = a % m
        var t0: UInt64 = 0, t1: UInt64 = 1
        var n0 = false, n1 = false
        while r1 != 0 {
            let q = r0 / r1
            (r0, r1) = (r1, r0 - q * r1)
            let qt1 = q &* t1
            var t2: UInt64
            var n2: Bool
            if n0 == n1 {
                if t0 >= qt1 { t2 = t0 - qt1; n2 = n0 } else { t2 = qt1 - t0; n2 = !n0 }
            } else {
                t2 = t0 &+ qt1; n2 = n0
            }
            if t2 == 0 { n2 = false }
            (t0, n0, t1, n1) = (t1, n1, t2, n2)
        }
        if r0 != 1 { return nil }
        let r = t0 % m
        return (n0 && r != 0) ? m - r : r
    }

    /// Integer square root ⌊√self⌋.
    public func squareRoot() -> BigUInt {
        if isZero { return self }
        if let v = uint64Value {
            return BigUInt(BigUInt.isqrt64(v))
        }
        // Newton iteration from an upper bound
        var x = BigUInt(1) << ((bitLength + 1) / 2 + 1)
        while true {
            let y = (x + self / x) >> 1
            if y >= x { return x }
            x = y
        }
    }

    /// ⌊√v⌋ for 64-bit values.
    static func isqrt64(_ v: UInt64) -> UInt64 {
        var r = UInt64(Double(v).squareRoot())
        if r > 0xFFFF_FFFF { r = 0xFFFF_FFFF }
        while r * r > v { r -= 1 }
        while r < 0xFFFF_FFFF && (r + 1) * (r + 1) <= v { r += 1 }
        return r
    }

    /// ⌊self^(1/k)⌋ for k >= 1.
    public func nthRoot(_ k: Int) -> BigUInt {
        precondition(k >= 1)
        if k == 1 || isZero || isOne { return self }
        if k == 2 { return squareRoot() }
        let bl = bitLength
        if k >= bl { return 1 }
        // Newton: x_{n+1} = ((k-1)x + self / x^(k-1)) / k, from an upper bound
        var x = BigUInt(1) << ((bl + k - 1) / k + 1)
        let kb = BigUInt(k), km1 = BigUInt(k - 1)
        while true {
            let y = (km1 * x + self / x.power(k - 1)) / kb
            if y >= x { break }
            x = y
        }
        // final correction
        while x.power(k) > self { x -= 1 }
        while (x + 1).power(k) <= self { x += 1 }
        return x
    }

    /// True if self is a perfect square.
    public var isPerfectSquare: Bool {
        // quick residue filter mod 64
        let low = low64 & 63
        let squaresMod64: UInt64 = 0x0202021202030213
        if (squaresMod64 >> low) & 1 == 0 { return false }
        let r = squareRoot()
        return r * r == self
    }

    /// If self = b^k for some k >= 2, returns (b, k) with maximal k; otherwise nil.
    public func perfectPower() -> (base: BigUInt, exponent: Int)? {
        if self < 4 { return nil }
        let bl = bitLength
        var best: (BigUInt, Int)? = nil
        var k = 2
        while k <= bl {
            let r = nthRoot(k)
            if r < 2 { break }
            if r.power(k) == self { best = (r, k) }
            k += 1
        }
        if let (b, e) = best { return (b, e) }
        return nil
    }

    /// Jacobi symbol (self / n) for odd n > 0. Returns -1, 0 or 1.
    public func jacobi(_ n: BigUInt) -> Int {
        precondition(n.isOdd, "Jacobi symbol: n must be odd")
        var a = self % n
        var m = n
        var result = 1
        while !a.isZero {
            let tz = a.trailingZeroBitCount
            if tz > 0 {
                a >>= tz
                let m8 = m.low64 & 7
                if tz & 1 == 1 && (m8 == 3 || m8 == 5) { result = -result }
            }
            // reciprocity
            if a.low64 & 3 == 3 && m.low64 & 3 == 3 { result = -result }
            (a, m) = (m % a, a)
        }
        return m.isOne ? result : 0
    }

    /// Square root modulo an odd prime p (Tonelli–Shanks), nil if self is a non-residue.
    public func modularSquareRoot(prime p: BigUInt) -> BigUInt? {
        let a = self % p
        if a.isZero { return BigUInt() }
        if p == 2 { return a }
        if a.jacobi(p) != 1 { return nil }
        if p.low64 & 3 == 3 {
            return a.power((p + 1) >> 2, modulus: p)
        }
        // p - 1 = q * 2^s
        let pm1 = p - 1
        let s = pm1.trailingZeroBitCount
        let q = pm1 >> s
        var z = BigUInt(2)
        while z.jacobi(p) != -1 { z += 1 }
        var m = s
        var c = z.power(q, modulus: p)
        var t = a.power(q, modulus: p)
        var r = a.power((q + 1) >> 1, modulus: p)
        while !t.isOne {
            var i = 0
            var tt = t
            while !tt.isOne {
                tt = (tt * tt) % p
                i += 1
                if i == m { return nil }
            }
            var b = c
            for _ in 0..<(m - i - 1) { b = (b * b) % p }
            m = i
            c = (b * b) % p
            t = (t * c) % p
            r = (r * b) % p
        }
        return r
    }

    /// (self * other) mod m
    public func multipliedModulo(_ other: BigUInt, _ m: BigUInt) -> BigUInt { (self * other) % m }

    /// (self + other) mod m (operands < m)
    public func addedModulo(_ other: BigUInt, _ m: BigUInt) -> BigUInt {
        let s = self + other
        return s >= m ? s - m : s
    }

    /// (self - other) mod m (operands < m)
    public func subtractedModulo(_ other: BigUInt, _ m: BigUInt) -> BigUInt {
        self >= other ? self - other : m - (other - self)
    }

    /// n! (precondition n >= 0). Uses product tree splitting.
    public static func factorial(_ n: Int) -> BigUInt {
        precondition(n >= 0)
        func prod(_ lo: Int, _ hi: Int) -> BigUInt {
            if lo > hi { return 1 }
            if hi - lo < 16 {
                var r = BigUInt(1)
                for i in lo...hi { r = r.multiplied(by: UInt64(i)) }
                return r
            }
            let mid = (lo + hi) / 2
            return prod(lo, mid) * prod(mid + 1, hi)
        }
        return prod(2, n)
    }

    /// Binomial coefficient C(n, k).
    public static func binomial(_ n: Int, _ k: Int) -> BigUInt {
        if k < 0 || k > n { return BigUInt() }
        let kk = min(k, n - k)
        var r = BigUInt(1)
        if kk == 0 { return r }
        for i in 1...kk {
            r = r.multiplied(by: UInt64(n - kk + i)).quotientAndRemainder(dividingBy: UInt64(i)).quotient
        }
        return r
    }
}

// MARK: - Random numbers

extension BigUInt {
    /// Cryptographically secure random bytes (SecRandomCopyBytes).
    static func secureRandomBytes(_ count: Int) -> [UInt8] {
        if count <= 0 { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            // extremely unlikely; fall back to the system generator
            var g = SystemRandomNumberGenerator()
            for i in 0..<count { bytes[i] = UInt8.random(in: 0...255, using: &g) }
        }
        return bytes
    }

    /// Uniform random number with at most `bits` bits; with `exact: true` the top bit is set
    /// (so the result has exactly `bits` bits).
    public static func random(bits: Int, exact: Bool = false) -> BigUInt {
        if bits <= 0 { return BigUInt() }
        let bytes = secureRandomBytes((bits + 7) / 8)
        var x = BigUInt(bigEndianBytes: bytes).truncated(toBits: bits)
        if exact { x = x.settingBit(bits - 1) }
        return x
    }

    /// Uniform random number in 0..<upper (precondition: upper > 0).
    public static func random(below upper: BigUInt) -> BigUInt {
        precondition(!upper.isZero, "Upper bound must be > 0")
        if upper.isOne { return BigUInt() }
        let bits = (upper - 1).bitLength
        while true {
            let x = random(bits: bits)
            if x < upper { return x }
        }
    }

    /// Uniform random number in the closed range.
    public static func random(in range: ClosedRange<BigUInt>) -> BigUInt {
        let width = range.upperBound - range.lowerBound + 1
        return range.lowerBound + random(below: width)
    }
}
