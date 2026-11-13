import CTCommon

/// One intermediate state of an AES encryption.
public struct AESTraceStep: Sendable {
    /// Round number (0 = initial AddRoundKey, Nr = final round).
    public let round: Int
    /// "Eingabe", "AddRoundKey", "SubBytes", "ShiftRows", "MixColumns" or "Ausgabe".
    public let operation: String
    /// The 16 state bytes in FIPS-197 column-major order (s[r,c] = state[r + 4c]).
    public let state: [UInt8]
}

/// Step-by-step AES encryption (replacement for CT1's Rijndael inspector). Pure Swift, not
/// optimised – for visualisation only.
public enum AESInspector {

    /// Encrypts one 16-byte block and records every transformation.
    /// - Returns: the steps, the Nr+1 round keys (16 bytes each, column-major) and the ciphertext.
    public static func trace(key: [UInt8], block: [UInt8]) throws -> (steps: [AESTraceStep], roundKeys: [[UInt8]], ciphertext: [UInt8]) {
        guard [16, 24, 32].contains(key.count) else {
            throw CTError("AES: The key must be 128, 192 or 256 bits long (is \(key.count * 8) bits).")
        }
        guard block.count == 16 else {
            throw CTError("AES: A block must be exactly 16 bytes long (is \(block.count) bytes).")
        }
        let roundKeys = expandKey(key)
        let nr = roundKeys.count - 1
        var steps: [AESTraceStep] = []
        var s = block
        steps.append(AESTraceStep(round: 0, operation: "Input", state: s))
        addRoundKey(&s, roundKeys[0])
        steps.append(AESTraceStep(round: 0, operation: "AddRoundKey", state: s))
        for round in 1...nr {
            subBytes(&s)
            steps.append(AESTraceStep(round: round, operation: "SubBytes", state: s))
            shiftRows(&s)
            steps.append(AESTraceStep(round: round, operation: "ShiftRows", state: s))
            if round < nr {
                mixColumns(&s)
                steps.append(AESTraceStep(round: round, operation: "MixColumns", state: s))
            }
            addRoundKey(&s, roundKeys[round])
            steps.append(AESTraceStep(round: round, operation: "AddRoundKey", state: s))
        }
        steps.append(AESTraceStep(round: nr, operation: "Output", state: s))
        return (steps, roundKeys, s)
    }

    /// AES S-box (computed from the multiplicative inverse in GF(2⁸) and the affine map).
    public static let sbox: [UInt8] = {
        var box = [UInt8](repeating: 0, count: 256)
        for x in 0..<256 {
            var inv: UInt8 = 0
            if x != 0 {
                // x^254 = x^-1
                var result: UInt8 = 1, base = UInt8(x), e = 254
                while e > 0 {
                    if e & 1 == 1 { result = gmul(result, base) }
                    base = gmul(base, base)
                    e >>= 1
                }
                inv = result
            }
            var s = inv
            for i in 1...4 { s ^= (inv << UInt8(i)) | (inv >> UInt8(8 - i)) }
            box[x] = s ^ 0x63
        }
        return box
    }()

    /// Multiplication in GF(2⁸) modulo x⁸ + x⁴ + x³ + x + 1.
    public static func gmul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var a = a, b = b, p: UInt8 = 0
        while b != 0 {
            if b & 1 != 0 { p ^= a }
            let hi = a & 0x80
            a <<= 1
            if hi != 0 { a ^= 0x1B }
            b >>= 1
        }
        return p
    }

    /// Key expansion (FIPS-197 section 5.2); returns Nr+1 round keys of 16 bytes.
    public static func expandKey(_ key: [UInt8]) -> [[UInt8]] {
        let nk = key.count / 4
        let nr = nk + 6
        var w: [[UInt8]] = (0..<nk).map { Array(key[(4 * $0)..<(4 * $0 + 4)]) }
        var rcon: UInt8 = 1
        for i in nk..<(4 * (nr + 1)) {
            var t = w[i - 1]
            if i % nk == 0 {
                t = [t[1], t[2], t[3], t[0]].map { sbox[Int($0)] }
                t[0] ^= rcon
                rcon = gmul(rcon, 2)
            } else if nk > 6 && i % nk == 4 {
                t = t.map { sbox[Int($0)] }
            }
            w.append(zip(w[i - nk], t).map { $0 ^ $1 })
        }
        return (0...nr).map { r in w[(4 * r)..<(4 * r + 4)].flatMap { $0 } }
    }

    static func addRoundKey(_ s: inout [UInt8], _ k: [UInt8]) { for i in 0..<16 { s[i] ^= k[i] } }

    static func subBytes(_ s: inout [UInt8]) { for i in 0..<16 { s[i] = sbox[Int(s[i])] } }

    static func shiftRows(_ s: inout [UInt8]) {
        let t = s
        for r in 1..<4 { for c in 0..<4 { s[r + 4 * c] = t[r + 4 * ((c + r) % 4)] } }
    }

    static func mixColumns(_ s: inout [UInt8]) {
        for c in 0..<4 {
            let a0 = s[4 * c], a1 = s[4 * c + 1], a2 = s[4 * c + 2], a3 = s[4 * c + 3]
            s[4 * c] = gmul(a0, 2) ^ gmul(a1, 3) ^ a2 ^ a3
            s[4 * c + 1] = a0 ^ gmul(a1, 2) ^ gmul(a2, 3) ^ a3
            s[4 * c + 2] = a0 ^ a1 ^ gmul(a2, 2) ^ gmul(a3, 3)
            s[4 * c + 3] = gmul(a0, 3) ^ a1 ^ a2 ^ gmul(a3, 2)
        }
    }
}

/// Helpers for CT1's hash demo ("Hash-Demo": avalanche effect).
public enum HashDemo {
    /// Number of differing bits between `a` and `b`. Bytes beyond the shorter input count as
    /// completely different; `totalBits` = 8 × length of the longer input.
    public static func bitDifference(_ a: [UInt8], _ b: [UInt8]) -> (differentBits: Int, totalBits: Int) {
        let common = min(a.count, b.count)
        var diff = 0
        for i in 0..<common { diff += (a[i] ^ b[i]).nonzeroBitCount }
        let longer = max(a.count, b.count)
        diff += 8 * (longer - common)
        return (diff, 8 * longer)
    }

    /// Indices (0 = most significant bit of byte 0) of the bits that differ in the common prefix.
    public static func differingBitPositions(_ a: [UInt8], _ b: [UInt8]) -> [Int] {
        var out: [Int] = []
        for i in 0..<min(a.count, b.count) {
            let x = a[i] ^ b[i]
            if x == 0 { continue }
            for bit in 0..<8 where x & (0x80 >> UInt8(bit)) != 0 { out.append(8 * i + bit) }
        }
        return out
    }
}
