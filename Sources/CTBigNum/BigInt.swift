import Foundation

/// Arbitrary precision signed integer (sign + magnitude). Division truncates toward zero
/// (like Swift's `Int`), `%` has the sign of the dividend.
public struct BigInt: Sendable {
    /// Absolute value.
    public private(set) var magnitude: BigUInt
    /// True for values < 0 (zero is never negative).
    public private(set) var isNegative: Bool

    /// Creates a value from magnitude and sign (negative zero is normalised to zero).
    public init(magnitude: BigUInt, isNegative: Bool) {
        self.magnitude = magnitude
        self.isNegative = isNegative && !magnitude.isZero
    }

    /// Zero.
    public init() { magnitude = BigUInt(); isNegative = false }

    /// Non-negative value from an unsigned big integer.
    public init(_ v: BigUInt) { magnitude = v; isNegative = false }

    /// Value from an `Int`.
    public init(_ v: Int) {
        magnitude = BigUInt(v.magnitude)
        isNegative = v < 0
    }

    /// Value from any binary integer type.
    public init<T: BinaryInteger>(_ v: T) {
        self.init(magnitude: BigUInt(v.magnitude), isNegative: v < 0)
    }

    /// Parses an optionally signed string ("-123", "+0x1F" for radix 16 …).
    public init?(_ string: String, radix: Int = 10) {
        var s = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        var neg = false
        if s.hasPrefix("-") { neg = true; s = s.dropFirst() } else if s.hasPrefix("+") { s = s.dropFirst() }
        guard let m = BigUInt(String(s), radix: radix) else { return nil }
        self.init(magnitude: m, isNegative: neg)
    }

    public var isZero: Bool { magnitude.isZero }
    /// -1, 0 or 1.
    public var signum: Int { isZero ? 0 : (isNegative ? -1 : 1) }
    public var isEven: Bool { magnitude.isEven }
    public var isOdd: Bool { magnitude.isOdd }

    /// The value as `Int` if it fits.
    public var intValue: Int? {
        guard let m = magnitude.uint64Value else { return nil }
        if isNegative {
            if m <= UInt64(Int.max) { return -Int(m) }
            if m == UInt64(Int.max) + 1 { return Int.min }
            return nil
        }
        return m <= UInt64(Int.max) ? Int(m) : nil
    }

    /// String in radix 2…36 with leading '-' for negative values.
    public func toString(radix: Int = 10, uppercase: Bool = true) -> String {
        (isNegative ? "-" : "") + magnitude.toString(radix: radix, uppercase: uppercase)
    }

    // MARK: Arithmetic

    public static prefix func - (x: BigInt) -> BigInt {
        BigInt(magnitude: x.magnitude, isNegative: !x.isNegative)
    }

    public static func + (lhs: BigInt, rhs: BigInt) -> BigInt {
        if lhs.isNegative == rhs.isNegative {
            return BigInt(magnitude: lhs.magnitude + rhs.magnitude, isNegative: lhs.isNegative)
        }
        if lhs.magnitude >= rhs.magnitude {
            return BigInt(magnitude: lhs.magnitude - rhs.magnitude, isNegative: lhs.isNegative)
        }
        return BigInt(magnitude: rhs.magnitude - lhs.magnitude, isNegative: rhs.isNegative)
    }

    public static func - (lhs: BigInt, rhs: BigInt) -> BigInt { lhs + (-rhs) }

    public static func * (lhs: BigInt, rhs: BigInt) -> BigInt {
        BigInt(magnitude: lhs.magnitude * rhs.magnitude, isNegative: lhs.isNegative != rhs.isNegative)
    }

    /// Truncating division (precondition: rhs != 0).
    public static func / (lhs: BigInt, rhs: BigInt) -> BigInt {
        BigInt(magnitude: lhs.magnitude / rhs.magnitude, isNegative: lhs.isNegative != rhs.isNegative)
    }

    /// Remainder of the truncating division (sign of the dividend).
    public static func % (lhs: BigInt, rhs: BigInt) -> BigInt {
        BigInt(magnitude: lhs.magnitude % rhs.magnitude, isNegative: lhs.isNegative)
    }

    public static func += (lhs: inout BigInt, rhs: BigInt) { lhs = lhs + rhs }
    public static func -= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs - rhs }
    public static func *= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs * rhs }
    public static func /= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs / rhs }
    public static func %= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs % rhs }

    /// Truncating quotient and remainder.
    public func quotientAndRemainder(dividingBy d: BigInt) -> (quotient: BigInt, remainder: BigInt) {
        let (q, r) = magnitude.quotientAndRemainder(dividingBy: d.magnitude)
        return (BigInt(magnitude: q, isNegative: isNegative != d.isNegative), BigInt(magnitude: r, isNegative: isNegative))
    }

    /// Floor division (rounds toward −∞).
    public func floorDivided(by d: BigInt) -> BigInt {
        let (q, r) = quotientAndRemainder(dividingBy: d)
        if !r.isZero && (r.isNegative != d.isNegative) { return q - 1 }
        return q
    }

    /// Non-negative residue `self mod m` in 0..<m (precondition: m > 0).
    public func modulo(_ m: BigUInt) -> BigUInt {
        let r = magnitude % m
        if isNegative && !r.isZero { return m - r }
        return r
    }

    /// self^e (precondition: e >= 0).
    public func power(_ e: Int) -> BigInt {
        BigInt(magnitude: magnitude.power(e), isNegative: isNegative && e % 2 == 1)
    }

    /// Absolute value.
    public var absoluteValue: BigInt { BigInt(magnitude) }

    /// Extended Euclidean algorithm: returns (g, x, y) with a·x + b·y = g = gcd(a, b) ≥ 0.
    public static func extendedGCD(_ a: BigInt, _ b: BigInt) -> (gcd: BigInt, x: BigInt, y: BigInt) {
        var oldR = a, r = b
        var oldS = BigInt(1), s = BigInt(0)
        var oldT = BigInt(0), t = BigInt(1)
        while !r.isZero {
            let q = oldR / r
            (oldR, r) = (r, oldR - q * r)
            (oldS, s) = (s, oldS - q * s)
            (oldT, t) = (t, oldT - q * t)
        }
        if oldR.isNegative { return (-oldR, -oldS, -oldT) }
        return (oldR, oldS, oldT)
    }
}

extension BigInt: Equatable, Hashable {}

extension BigInt: Comparable {
    public static func < (lhs: BigInt, rhs: BigInt) -> Bool {
        if lhs.isNegative != rhs.isNegative { return lhs.isNegative }
        if lhs.isNegative { return lhs.magnitude > rhs.magnitude }
        return lhs.magnitude < rhs.magnitude
    }
}

extension BigInt: ExpressibleByIntegerLiteral {
    /// Arbitrarily large (also negative) integer literals are supported.
    public init(integerLiteral value: StaticBigInt) {
        let words = (value.bitWidth + UInt.bitWidth - 1) / UInt.bitWidth
        var l = [UInt64]()
        l.reserveCapacity(words)
        for i in 0..<words { l.append(UInt64(value[i])) }
        if value.signum() < 0 {
            // two's complement → magnitude
            var carry: UInt64 = 1
            for i in 0..<l.count {
                let (s, o) = (~l[i]).addingReportingOverflow(carry)
                l[i] = s
                carry = o ? 1 : 0
            }
            self.init(magnitude: BigUInt(limbs: l), isNegative: true)
        } else {
            self.init(magnitude: BigUInt(limbs: l), isNegative: false)
        }
    }
}

extension BigInt: CustomStringConvertible {
    /// Decimal representation.
    public var description: String { toString(radix: 10) }
}

extension BigInt: Codable {
    /// Encoded as (optionally signed) hexadecimal string.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(toString(radix: 16))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let v = BigInt(s, radix: 16) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid hex number: \(s)")
        }
        self = v
    }
}
