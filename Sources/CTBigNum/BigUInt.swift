import Foundation
import CTCommon

/// Arbitrary precision unsigned integer (little-endian `UInt64` limbs).
///
/// Value semantics, copy-on-write storage. `description` is the decimal representation,
/// `Codable` uses an uppercase hexadecimal string.
public struct BigUInt: Sendable {
    /// Little-endian limbs, normalised (no leading zero limbs; zero is `[]`).
    @usableFromInline internal var limbs: [UInt64]

    /// Internal: wraps limbs and normalises them.
    @inlinable
    init(limbs: [UInt64]) {
        var l = limbs
        while let last = l.last, last == 0 { l.removeLast() }
        self.limbs = l
    }

    /// Internal: wraps already normalised limbs.
    @inlinable
    init(normalizedLimbs: [UInt64]) {
        self.limbs = normalizedLimbs
    }

    /// Zero.
    public init() { limbs = [] }

    /// The value 0.
    public static let zero = BigUInt()
    /// The value 1.
    public static let one = BigUInt(1)

    /// Creates a value from a non-negative `Int` (precondition: `v >= 0`).
    public init(_ v: Int) {
        precondition(v >= 0, "BigUInt kann keine negativen Werte darstellen")
        limbs = v == 0 ? [] : [UInt64(v)]
    }

    /// Creates a value from an `UInt64`.
    public init(_ v: UInt64) {
        limbs = v == 0 ? [] : [v]
    }

    /// Creates a value from an `UInt`.
    public init(_ v: UInt) { self.init(UInt64(v)) }

    /// Creates a value from an `UInt32`.
    public init(_ v: UInt32) { self.init(UInt64(v)) }

    /// Creates a value from any non-negative binary integer (precondition: `v >= 0`).
    public init<T: BinaryInteger>(_ v: T) {
        precondition(v >= 0, "BigUInt kann keine negativen Werte darstellen")
        self.init(limbs: v.words.map { UInt64($0) })
    }

    /// Creates a value if `v` is a non-negative integer that fits, otherwise nil.
    public init?<T: BinaryInteger>(exactly v: T) {
        guard v >= 0 else { return nil }
        self.init(v)
    }

    /// Converts a non-negative `BigInt` (nil for negative values).
    public init?(_ v: BigInt) {
        guard !v.isNegative else { return nil }
        self = v.magnitude
    }

    /// Creates a value from a big-endian byte sequence (leading zero bytes are ignored).
    public init(bigEndianBytes bytes: [UInt8]) {
        var l = [UInt64](repeating: 0, count: (bytes.count + 7) / 8)
        var shift: UInt64 = 0
        var idx = 0
        for b in bytes.reversed() {
            l[idx] |= UInt64(b) << shift
            shift += 8
            if shift == 64 { shift = 0; idx += 1 }
        }
        self.init(limbs: l)
    }

    /// Creates a value from a little-endian byte sequence.
    public init(littleEndianBytes bytes: [UInt8]) {
        self.init(bigEndianBytes: bytes.reversed())
    }

    /// Parses a string in the given radix (2…36). Leading/trailing whitespace is ignored, as are
    /// `_` separators. For radix 16 an optional `0x` prefix is accepted. Returns nil for empty or
    /// invalid input.
    public init?(_ string: String, radix: Int = 10) {
        guard (2...36).contains(radix) else { return nil }
        var s = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if s.hasPrefix("+") { s = s.dropFirst() }
        if radix == 16, s.hasPrefix("0x") || s.hasPrefix("0X") { s = s.dropFirst(2) }
        if s.isEmpty { return nil }
        // digits per chunk such that radix^k fits into UInt64
        let (chunkDigits, chunkBase) = BigUInt.chunkInfo(radix: radix)
        var result: [UInt64] = []
        result.reserveCapacity(s.utf8.count / max(1, chunkDigits) + 1)
        var acc: UInt64 = 0
        var accDigits = 0
        var sawDigit = false
        let r64 = UInt64(radix)
        for u in s.utf8 {
            let d: UInt64
            switch u {
            case 0x30...0x39: d = UInt64(u - 0x30)
            case 0x41...0x5A: d = UInt64(u - 0x41 + 10)
            case 0x61...0x7A: d = UInt64(u - 0x61 + 10)
            case 0x5F: continue // '_'
            default: return nil
            }
            if d >= r64 { return nil }
            sawDigit = true
            acc = acc * r64 + d
            accDigits += 1
            if accDigits == chunkDigits {
                Limbs.mulAddSmallInPlace(&result, chunkBase, acc)
                acc = 0
                accDigits = 0
            }
        }
        if !sawDigit { return nil }
        if accDigits > 0 {
            var m: UInt64 = 1
            for _ in 0..<accDigits { m *= r64 }
            Limbs.mulAddSmallInPlace(&result, m, acc)
        }
        // mulAddSmallInPlace starts from an empty array: handle the case "no limbs yet"
        Limbs.normalize(&result)
        self.limbs = result
    }

    /// (k, radix^k) with radix^k the largest power fitting into an UInt64.
    static func chunkInfo(radix: Int) -> (Int, UInt64) {
        var k = 0
        var p: UInt64 = 1
        let r = UInt64(radix)
        while true {
            let (np, o) = p.multipliedReportingOverflow(by: r)
            if o { break }
            p = np
            k += 1
        }
        return (k, p)
    }

    // MARK: - Basic properties

    /// True if the value is zero.
    @inlinable public var isZero: Bool { limbs.isEmpty }
    /// True if the value is even (zero is even).
    @inlinable public var isEven: Bool { limbs.isEmpty || limbs[0] & 1 == 0 }
    /// True if the value is odd.
    @inlinable public var isOdd: Bool { !isEven }
    /// True if the value is one.
    public var isOne: Bool { limbs.count == 1 && limbs[0] == 1 }

    /// Number of significant bits (0 for zero).
    public var bitLength: Int { Limbs.bitLength(limbs) }

    /// Number of trailing zero bits (0 for zero).
    public var trailingZeroBitCount: Int { Limbs.trailingZeroBits(limbs) }

    /// Number of limbs (64 bit words).
    public var wordCount: Int { limbs.count }

    /// The value as `UInt64`, or nil if it does not fit.
    public var uint64Value: UInt64? {
        switch limbs.count {
        case 0: return 0
        case 1: return limbs[0]
        default: return nil
        }
    }

    /// The value as `Int`, or nil if it does not fit.
    public var intValue: Int? {
        guard let v = uint64Value, v <= UInt64(Int.max) else { return nil }
        return Int(v)
    }

    /// Lowest 64 bits.
    public var low64: UInt64 { limbs.first ?? 0 }

    /// Approximation as `Double` (may be `.infinity` for huge values).
    public var doubleValue: Double {
        if limbs.isEmpty { return 0 }
        let bl = bitLength
        if bl <= 64 { return Double(limbs[0]) }
        let top = (self >> (bl - 64)).limbs[0]
        return Double(top) * pow(2.0, Double(bl - 64))
    }

    /// log2 of the value (−∞ for zero).
    public var log2Value: Double {
        if limbs.isEmpty { return -.infinity }
        let bl = bitLength
        if bl <= 64 { return Foundation.log2(Double(limbs[0])) }
        let top = (self >> (bl - 64)).limbs[0]
        return Foundation.log2(Double(top)) + Double(bl - 64)
    }

    /// Bit `i` (0 = least significant).
    public func bit(at i: Int) -> Bool {
        precondition(i >= 0)
        let w = i / 64
        guard w < limbs.count else { return false }
        return (limbs[w] >> UInt64(i % 64)) & 1 == 1
    }

    /// Returns a copy with bit `i` set or cleared.
    public func settingBit(_ i: Int, to value: Bool = true) -> BigUInt {
        var l = limbs
        let w = i / 64
        if w >= l.count {
            if !value { return self }
            l.append(contentsOf: [UInt64](repeating: 0, count: w - l.count + 1))
        }
        if value { l[w] |= 1 << UInt64(i % 64) } else { l[w] &= ~(1 << UInt64(i % 64)) }
        return BigUInt(limbs: l)
    }

    /// Number of set bits.
    public var nonzeroBitCount: Int { limbs.reduce(0) { $0 + $1.nonzeroBitCount } }

    // MARK: - Bytes

    /// Minimal big-endian byte representation (zero → `[]`).
    public var bigEndianBytes: [UInt8] {
        if limbs.isEmpty { return [] }
        let byteCount = (bitLength + 7) / 8
        var out = [UInt8](repeating: 0, count: byteCount)
        for i in 0..<byteCount {
            let limb = limbs[i / 8]
            out[byteCount - 1 - i] = UInt8(truncatingIfNeeded: limb >> UInt64((i % 8) * 8))
        }
        return out
    }

    /// Big-endian bytes left-padded with zeros to `length` bytes. If the value needs more bytes
    /// than `length`, the minimal representation is returned (never truncated).
    public func bigEndianBytes(length: Int) -> [UInt8] {
        let b = bigEndianBytes
        if b.count >= length { return b }
        return [UInt8](repeating: 0, count: length - b.count) + b
    }

    /// Little-endian bytes (minimal).
    public var littleEndianBytes: [UInt8] { bigEndianBytes.reversed() }

    // MARK: - String conversion

    /// String representation in radix 2…36 (no prefix). Power-of-two radices are linear time;
    /// other radices use divide & conquer (≈0.3 s for 1 Mbit, roughly quadratic beyond that).
    public func toString(radix: Int = 10, uppercase: Bool = true) -> String {
        precondition((2...36).contains(radix), "Ungültige Basis")
        if limbs.isEmpty { return "0" }
        let digitChars: [UInt8] = Array((uppercase ? "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                                   : "0123456789abcdefghijklmnopqrstuvwxyz").utf8)
        var out: [UInt8]
        if radix & (radix - 1) == 0 {
            // power of two radix: direct bit extraction
            let bitsPerDigit = radix.trailingZeroBitCount
            let bl = bitLength
            let nDigits = (bl + bitsPerDigit - 1) / bitsPerDigit
            out = [UInt8](repeating: 0, count: nDigits)
            let mask = UInt64(radix - 1)
            for d in 0..<nDigits {
                let bitPos = d * bitsPerDigit
                let w = bitPos / 64, o = bitPos % 64
                var v = limbs[w] >> UInt64(o)
                if o + bitsPerDigit > 64 && w + 1 < limbs.count {
                    v |= limbs[w + 1] << UInt64(64 - o)
                }
                out[nDigits - 1 - d] = digitChars[Int(v & mask)]
            }
        } else {
            out = []
            BigUInt.convertGeneric(self, radix: radix, digits: digitChars, minDigits: 0, into: &out)
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Divide & conquer conversion for non power-of-two radices. Appends the digits of `x`
    /// (left-padded with zeros to `minDigits`) to `out`.
    private static func convertGeneric(_ x: BigUInt, radix: Int, digits: [UInt8], minDigits: Int, into out: inout [UInt8]) {
        let (chunkDigits, chunkBase) = chunkInfo(radix: radix)
        if x.limbs.count <= 60 {
            // simple repeated division by radix^k
            var chunks: [UInt64] = []
            var t = x.limbs
            while !t.isEmpty {
                chunks.append(Limbs.divSmallInPlace(&t, chunkBase))
            }
            var tmp: [UInt8] = []
            tmp.reserveCapacity(chunks.count * chunkDigits)
            let r = UInt64(radix)
            for (i, c) in chunks.enumerated().reversed() {
                var buf = [UInt8](repeating: digits[0], count: chunkDigits)
                var v = c
                var k = chunkDigits - 1
                while v > 0 {
                    buf[k] = digits[Int(v % r)]
                    v /= r
                    k -= 1
                }
                if i == chunks.count - 1 {
                    // most significant chunk: strip leading zeros
                    let firstNonZero = buf.firstIndex(where: { $0 != digits[0] }) ?? (chunkDigits - 1)
                    tmp.append(contentsOf: buf[firstNonZero...])
                } else {
                    tmp.append(contentsOf: buf)
                }
            }
            if tmp.isEmpty { tmp = [digits[0]] }
            if x.isZero { tmp = [] }
            if tmp.count < minDigits {
                out.append(contentsOf: [UInt8](repeating: digits[0], count: minDigits - tmp.count))
            }
            out.append(contentsOf: tmp)
            return
        }
        // powers: P[i] = chunkBase^(2^i), digits(P[i]) = chunkDigits * 2^i
        var powers: [BigUInt] = [BigUInt(chunkBase)]
        while powers.last!.limbs.count * 2 <= x.limbs.count + 1 {
            powers.append(powers.last!.squared())
        }
        func rec(_ v: BigUInt, _ level: Int, _ pad: Int, _ out: inout [UInt8]) {
            if level < 0 || v.limbs.count <= 60 {
                convertGeneric(v, radix: radix, digits: digits, minDigits: pad, into: &out)
                return
            }
            let p = powers[level]
            if v < p {
                rec(v, level - 1, pad, &out)
                return
            }
            let (q, r) = v.quotientAndRemainder(dividingBy: p)
            let lowDigits = chunkDigits << level
            rec(q, level - 1, max(0, pad - lowDigits), &out)
            rec(r, level - 1, lowDigits, &out)
        }
        rec(x, powers.count - 1, minDigits, &out)
    }

    /// Exact number of digits in the given radix (1 for zero).
    public func digitCount(radix: Int = 10) -> Int {
        precondition((2...36).contains(radix))
        if limbs.isEmpty { return 1 }
        if radix & (radix - 1) == 0 {
            let b = radix.trailingZeroBitCount
            return (bitLength + b - 1) / b
        }
        // estimate from bit length, then correct by comparing with radix^k
        let est = Int(Double(bitLength - 1) / Foundation.log2(Double(radix))) // floor(log_r(2^(bl-1)))
        var k = max(1, est)
        // value has k+1 digits iff value >= radix^k
        var p = BigUInt(UInt64(radix)).power(k)
        while self >= p {
            k += 1
            p = p * BigUInt(UInt64(radix))
        }
        while k > 1 {
            let q = BigUInt(UInt64(radix)).power(k - 1)
            if self < q { k -= 1 } else { break }
        }
        return k
    }
}

// MARK: - Protocol conformances

extension BigUInt: Equatable, Hashable {
    public static func == (lhs: BigUInt, rhs: BigUInt) -> Bool { lhs.limbs == rhs.limbs }
    public func hash(into hasher: inout Hasher) { hasher.combine(limbs) }
}

extension BigUInt: Comparable {
    public static func < (lhs: BigUInt, rhs: BigUInt) -> Bool { Limbs.compare(lhs.limbs, rhs.limbs) < 0 }
}

extension BigUInt: ExpressibleByIntegerLiteral {
    /// Arbitrarily large integer literals are supported (`let n: BigUInt = 2305843009213693951…`).
    public init(integerLiteral value: StaticBigInt) {
        precondition(value.signum() >= 0, "BigUInt kann keine negativen Werte darstellen")
        let words = (value.bitWidth + UInt.bitWidth - 1) / UInt.bitWidth
        var l = [UInt64]()
        l.reserveCapacity(words)
        for i in 0..<words { l.append(UInt64(value[i])) }
        self.init(limbs: l)
    }
}

extension BigUInt: CustomStringConvertible, CustomDebugStringConvertible {
    /// Decimal representation.
    public var description: String { toString(radix: 10) }
    public var debugDescription: String { "BigUInt(0x\(toString(radix: 16)))" }
}

extension BigUInt: Codable {
    /// Encoded as uppercase hexadecimal string.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(toString(radix: 16))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let v = BigUInt(s, radix: 16) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Ungültige Hex-Zahl: \(s)")
        }
        self = v
    }
}
