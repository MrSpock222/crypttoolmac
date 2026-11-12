import Foundation
import CTCommon

// MARK: - Keys

/// RSA public key (n, e).
public struct RSAPublicKey: Codable, Hashable, Sendable {
    public var n: BigUInt
    public var e: BigUInt

    public init(n: BigUInt, e: BigUInt) {
        self.n = n
        self.e = e
    }

    /// Bit length of the modulus.
    public var bitLength: Int { n.bitLength }
    /// Length of the modulus in bytes (k in PKCS #1).
    public var byteLength: Int { (n.bitLength + 7) / 8 }

    /// Textbook RSA: m^e mod n (m < n).
    public func encrypt(_ m: BigUInt) -> BigUInt { m.power(e, modulus: n) }

    /// Textbook signature verification: s^e mod n.
    public func verifyRaw(_ s: BigUInt) -> BigUInt { s.power(e, modulus: n) }
}

/// RSA key pair with CRT parameters (d = e⁻¹ mod φ(n), as in CT1).
public struct RSAKeyPair: Codable, Hashable, Sendable {
    public private(set) var p: BigUInt
    public private(set) var q: BigUInt
    public private(set) var n: BigUInt
    public private(set) var e: BigUInt
    public private(set) var d: BigUInt
    /// φ(n) = (p−1)(q−1)
    public private(set) var phi: BigUInt
    /// d mod (p−1)
    public private(set) var dp: BigUInt
    /// d mod (q−1)
    public private(set) var dq: BigUInt
    /// q⁻¹ mod p
    public private(set) var qInv: BigUInt

    /// Builds a key pair from two primes and the public exponent. Throws `CTError` if p or q is
    /// not a (probable) prime, p = q, e is not in 1 < e < φ(n), or gcd(e, φ(n)) ≠ 1.
    public init(p: BigUInt, q: BigUInt, e: BigUInt) throws {
        guard Primality.isProbablePrime(p) else { throw CTError("p = \(p) ist keine Primzahl.") }
        guard Primality.isProbablePrime(q) else { throw CTError("q = \(q) ist keine Primzahl.") }
        guard p != q else { throw CTError("Die Primzahlen p und q müssen verschieden sein.") }
        let phi = (p - 1) * (q - 1)
        guard e > 1, e < phi else {
            throw CTError("Der öffentliche Exponent e muss zwischen 1 und φ(N) = \(phi) liegen.")
        }
        guard let d = e.inverse(modulo: phi) else {
            throw CTError("Der öffentliche Exponent e = \(e) ist nicht teilerfremd zu φ(N) = \(phi).")
        }
        self.init(p: p, q: q, e: e, d: d, phi: phi)
    }

    /// Builds a key pair from primes and an explicitly given private exponent d (checked:
    /// e·d ≡ 1 mod φ(n)).
    public init(p: BigUInt, q: BigUInt, e: BigUInt, d: BigUInt) throws {
        try self.init(p: p, q: q, e: e)
        guard (e * d) % phi == 1 % phi else {
            throw CTError("e·d ≢ 1 (mod φ(N)) – d passt nicht zu e.")
        }
        self.d = d
        self.dp = d % (p - 1)
        self.dq = d % (q - 1)
    }

    private init(p: BigUInt, q: BigUInt, e: BigUInt, d: BigUInt, phi: BigUInt) {
        // order p > q is not required; qInv refers to the given q
        self.p = p
        self.q = q
        self.n = p * q
        self.e = e
        self.d = d
        self.phi = phi
        self.dp = d % (p - 1)
        self.dq = d % (q - 1)
        self.qInv = q.inverse(modulo: p) ?? 0
    }

    /// Generates a random key pair whose modulus has exactly `bits` bits (bits >= 8).
    /// If e is not usable for very small key sizes (e ≥ φ(n)), the smallest suitable odd e ≥ 3
    /// is chosen instead.
    public static func generate(bits: Int, e: BigUInt = 65537) -> RSAKeyPair {
        precondition(bits >= 8, "RSA-Modul muss mindestens 8 Bit haben")
        let pBits = (bits + 1) / 2, qBits = bits / 2
        // for tiny moduli there are too few primes with the two top bits set
        let topTwo = bits >= 32
        while true {
            let p = Primality.randomPrime(bits: pBits, topTwoBits: topTwo)
            let q = Primality.randomPrime(bits: qBits, topTwoBits: topTwo)
            if p == q || (p * q).bitLength != bits { continue }
            let phi = (p - 1) * (q - 1)
            var ee = e
            if ee >= phi || ee < 3 || !ee.gcd(phi).isOne {
                if e < phi && e >= 3 && bits > 2 * e.bitLength + 4 { continue } // try other primes
                ee = 3
                while !ee.gcd(phi).isOne { ee += 2 }
                if ee >= phi { continue }
            }
            if let kp = try? RSAKeyPair(p: p, q: q, e: ee), kp.n.bitLength == bits {
                return kp
            }
        }
    }

    /// The public part (n, e).
    public var publicKey: RSAPublicKey { RSAPublicKey(n: n, e: e) }

    /// Bit length of the modulus.
    public var bitLength: Int { n.bitLength }

    /// Textbook encryption m^e mod n.
    public func encrypt(_ m: BigUInt) -> BigUInt { m.power(e, modulus: n) }

    /// Decryption c^d mod n using the Chinese remainder theorem.
    public func decrypt(_ c: BigUInt) -> BigUInt {
        if qInv.isZero { return c.power(d, modulus: n) }
        let m1 = (c % p).power(dp, modulus: p)
        let m2 = (c % q).power(dq, modulus: q)
        // h = qInv·(m1 − m2) mod p
        let diff = m1 >= m2 % p ? m1 - m2 % p : p - (m2 % p - m1)
        let h = (qInv * diff) % p
        return m2 + h * q
    }

    /// Decryption without CRT (c^d mod n), for comparison in demos.
    public func decryptWithoutCRT(_ c: BigUInt) -> BigUInt { c.power(d, modulus: n) }

    /// Textbook signature m^d mod n (CRT).
    public func signRaw(_ m: BigUInt) -> BigUInt { decrypt(m) }
}

// MARK: - PKCS #1 v1.5

/// Hash algorithms with DER encoded DigestInfo prefixes (PKCS #1 v2.2, section 9.2).
public enum DigestAlgorithmID: String, CaseIterable, Codable, Sendable {
    case md2, md5, sha1, sha256, sha512, ripemd160

    /// Display name.
    public var displayName: String {
        switch self {
        case .md2: return "MD2"
        case .md5: return "MD5"
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        case .ripemd160: return "RIPEMD-160"
        }
    }

    /// Length of the hash value in bytes.
    public var digestLength: Int {
        switch self {
        case .md2, .md5: return 16
        case .sha1, .ripemd160: return 20
        case .sha256: return 32
        case .sha512: return 64
        }
    }

    /// Object identifier (dotted notation).
    public var oid: String {
        switch self {
        case .md2: return "1.2.840.113549.2.2"
        case .md5: return "1.2.840.113549.2.5"
        case .sha1: return "1.3.14.3.2.26"
        case .sha256: return "2.16.840.1.101.3.4.2.1"
        case .sha512: return "2.16.840.1.101.3.4.2.3"
        case .ripemd160: return "1.3.36.3.2.1"
        }
    }

    /// DER prefix of the DigestInfo structure (the hash value follows directly).
    public var digestInfoPrefix: [UInt8] {
        switch self {
        case .md2: return [0x30, 0x20, 0x30, 0x0C, 0x06, 0x08, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02, 0x02, 0x05, 0x00, 0x04, 0x10]
        case .md5: return [0x30, 0x20, 0x30, 0x0C, 0x06, 0x08, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02, 0x05, 0x05, 0x00, 0x04, 0x10]
        case .sha1: return [0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2B, 0x0E, 0x03, 0x02, 0x1A, 0x05, 0x00, 0x04, 0x14]
        case .sha256: return [0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20]
        case .sha512: return [0x30, 0x51, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05, 0x00, 0x04, 0x40]
        case .ripemd160: return [0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2B, 0x24, 0x03, 0x02, 0x01, 0x05, 0x00, 0x04, 0x14]
        }
    }
}

/// PKCS #1 v1.5 encryption (EME-PKCS1-v1_5) and signatures (EMSA-PKCS1-v1_5).
public enum PKCS1 {
    /// Encrypts `message` (at most k − 11 bytes) with a random non-zero padding string.
    /// Result has exactly k = byte length of n bytes.
    public static func encrypt(_ message: [UInt8], key: RSAPublicKey) throws -> [UInt8] {
        let k = key.byteLength
        guard k >= 11, message.count <= k - 11 else {
            throw CTError("Die Nachricht ist zu lang: höchstens \(max(0, k - 11)) Byte bei einem \(key.bitLength)-Bit-Schlüssel.")
        }
        var ps: [UInt8] = []
        while ps.count < k - message.count - 3 {
            for b in BigUInt.secureRandomBytes(k - message.count - 3 - ps.count) where b != 0 { ps.append(b) }
        }
        let em: [UInt8] = [0x00, 0x02] + ps + [0x00] + message
        let m = BigUInt(bigEndianBytes: em)
        return key.encrypt(m).bigEndianBytes(length: k)
    }

    /// Decrypts a PKCS #1 v1.5 block. Throws `CTError` if the format is invalid.
    public static func decrypt(_ cipher: [UInt8], key: RSAKeyPair) throws -> [UInt8] {
        let k = (key.n.bitLength + 7) / 8
        guard cipher.count == k, k >= 11 else {
            throw CTError("Der Chiffretext muss genau \(k) Byte lang sein.")
        }
        let c = BigUInt(bigEndianBytes: cipher)
        guard c < key.n else { throw CTError("Der Chiffretext ist größer als der Modul.") }
        let em = key.decrypt(c).bigEndianBytes(length: k)
        guard em[0] == 0x00, em[1] == 0x02 else {
            throw CTError("Entschlüsselungsfehler: kein gültiger PKCS#1-Block (Typ 2).")
        }
        guard let sep = em[2...].firstIndex(of: 0x00), sep >= 10 else {
            throw CTError("Entschlüsselungsfehler: ungültiger PKCS#1-Füllstring.")
        }
        return Array(em[(sep + 1)...])
    }

    /// DER encoded DigestInfo = prefix(algorithm) ‖ hash.
    public static func digestInfo(hash: [UInt8], algorithm: DigestAlgorithmID) -> [UInt8] {
        algorithm.digestInfoPrefix + hash
    }

    /// Encoded message EM = 00 01 FF…FF 00 ‖ DigestInfo for a modulus of k bytes.
    public static func signatureBlock(hash: [UInt8], algorithm: DigestAlgorithmID, k: Int) throws -> [UInt8] {
        let t = digestInfo(hash: hash, algorithm: algorithm)
        guard k >= t.count + 11 else {
            throw CTError("Der Schlüssel ist zu kurz für eine \(algorithm.displayName)-Signatur (mindestens \((t.count + 11) * 8) Bit).")
        }
        return [0x00, 0x01] + [UInt8](repeating: 0xFF, count: k - t.count - 3) + [0x00] + t
    }

    /// RSASSA-PKCS1-v1_5 signature of a precomputed hash value.
    public static func sign(hash: [UInt8], algorithm: DigestAlgorithmID, key: RSAKeyPair) throws -> [UInt8] {
        let k = (key.n.bitLength + 7) / 8
        if hash.count != algorithm.digestLength {
            throw CTError("Der Hashwert hat nicht die für \(algorithm.displayName) erwartete Länge von \(algorithm.digestLength) Byte.")
        }
        let em = try signatureBlock(hash: hash, algorithm: algorithm, k: k)
        let m = BigUInt(bigEndianBytes: em)
        return key.decrypt(m).bigEndianBytes(length: k)
    }

    /// Verifies a RSASSA-PKCS1-v1_5 signature.
    public static func verify(signature: [UInt8], hash: [UInt8], algorithm: DigestAlgorithmID, key: RSAPublicKey) -> Bool {
        let k = key.byteLength
        guard signature.count == k else { return false }
        let s = BigUInt(bigEndianBytes: signature)
        guard s < key.n else { return false }
        let em = key.encrypt(s).bigEndianBytes(length: k)
        guard let expected = try? signatureBlock(hash: hash, algorithm: algorithm, k: k) else { return false }
        return em == expected
    }
}

// MARK: - Text coding for the RSA demo (CT1 "RSA-Demo")

/// Block coding of texts into numbers as done by CT1's RSA demo.
///
/// The text is cut into blocks of `blockSize` characters; each block is read as a number in
/// base b = alphabet size ("b-adisch"): the first character is the most significant digit,
/// a character's value is its index in the alphabet. The last block is padded with spaces
/// (CT1 behaviour; if the alphabet has no space, its first character is used).
public enum RSATextCodec {
    /// CT1's default alphabet of the RSA demo (space + A–Z, 27 characters).
    public static let defaultAlphabet = " ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    /// Largest block size k with base^k ≤ modulus, i.e. every block value (at most base^k − 1)
    /// is smaller than the modulus. Returns 0 if even a single character does not fit (base > n).
    public static func maxBlockSize(modulus: BigUInt, base: Int) -> Int {
        precondition(base >= 2)
        if modulus < BigUInt(base) { return 0 }
        let b = UInt64(base)
        var k = 0
        var pw = BigUInt(1)
        while true {
            let next = pw.multiplied(by: b)
            if next > modulus { return k }
            pw = next
            k += 1
        }
    }

    static func uniqueCharacters(_ alphabet: String) -> [Character] {
        var seen = Set<Character>()
        var out: [Character] = []
        for c in alphabet where !seen.contains(c) { seen.insert(c); out.append(c) }
        return out
    }

    /// Removes all characters that are not part of the alphabet (CT1 asks before doing this).
    public static func filter(_ text: String, alphabet: String) -> String {
        let set = Set(alphabet)
        return String(text.filter { set.contains($0) })
    }

    /// Splits the (filtered) text into blocks of `blockSize` characters, padding the last block.
    public static func segment(_ text: String, alphabet: String, blockSize: Int) -> [String] {
        precondition(blockSize >= 1)
        let chars = uniqueCharacters(alphabet)
        let pad: Character = chars.contains(" ") ? " " : (chars.first ?? " ")
        let filtered = Array(filter(text, alphabet: alphabet))
        var blocks: [String] = []
        var i = 0
        while i < filtered.count {
            var block = Array(filtered[i..<min(i + blockSize, filtered.count)])
            while block.count < blockSize { block.append(pad) }
            blocks.append(String(block))
            i += blockSize
        }
        return blocks
    }

    /// Encodes a text into block numbers (characters not in the alphabet are skipped).
    public static func encodeBlocks(_ text: String, alphabet: String, blockSize: Int) -> [BigUInt] {
        let chars = uniqueCharacters(alphabet)
        var index: [Character: UInt64] = [:]
        for (i, c) in chars.enumerated() { index[c] = UInt64(i) }
        let base = UInt64(chars.count)
        return segment(text, alphabet: alphabet, blockSize: blockSize).map { block in
            var v = BigUInt()
            for c in block { v = v.multiplied(by: base, adding: index[c] ?? 0) }
            return v
        }
    }

    /// Decodes block numbers back into text. Each number yields `blockSize` characters (more if
    /// the number is ≥ base^blockSize, as in CT1). Padding characters are kept.
    public static func decodeBlocks(_ blocks: [BigUInt], alphabet: String, blockSize: Int) -> String {
        let chars = uniqueCharacters(alphabet)
        guard chars.count >= 2 else { return "" }
        let base = UInt64(chars.count)
        var out = ""
        for b in blocks {
            var digits: [Character] = []
            var t = b
            var i = 0
            while i < blockSize || !t.isZero {
                let (q, r) = t.quotientAndRemainder(dividingBy: base)
                digits.append(chars[Int(r)])
                t = q
                i += 1
            }
            out.append(contentsOf: digits.reversed())
        }
        return out
    }

    /// Encodes bytes in blocks of `blockSize` bytes as base-256 numbers (big-endian). The last
    /// block is padded with `padding` (CT1 pads text with spaces, hex dumps with 0x00).
    public static func encodeBytes(_ bytes: [UInt8], blockSize: Int, padding: UInt8 = 0x20) -> [BigUInt] {
        precondition(blockSize >= 1)
        var out: [BigUInt] = []
        var i = 0
        while i < bytes.count {
            var block = Array(bytes[i..<min(i + blockSize, bytes.count)])
            while block.count < blockSize { block.append(padding) }
            out.append(BigUInt(bigEndianBytes: block))
            i += blockSize
        }
        return out
    }

    /// Decodes base-256 block numbers into bytes (each block yields `blockSize` bytes, more if the
    /// number does not fit).
    public static func decodeBytes(_ blocks: [BigUInt], blockSize: Int) -> [UInt8] {
        var out: [UInt8] = []
        for b in blocks { out.append(contentsOf: b.bigEndianBytes(length: blockSize)) }
        return out
    }

    // MARK: "Zahlensystem" coding (CT1 option "Kodierung: Zahlensystem")

    /// Digits needed per character when each character index is written with a fixed number of
    /// digits in `radix` (CT1 coding method "Zahlensystem").
    public static func digitsPerCharacter(alphabetSize: Int, radix: Int) -> Int {
        var d = 1
        var p = radix
        while p < alphabetSize { p *= radix; d += 1 }
        return d
    }

    /// Largest block size for the number-system coding: the largest k such that the maximal block
    /// value (A−1)·(m^k − 1)/(m − 1) with m = radix^digits is smaller than the modulus.
    public static func maxBlockSizeNumberSystem(modulus: BigUInt, alphabetSize: Int, radix: Int) -> Int {
        let d = digitsPerCharacter(alphabetSize: alphabetSize, radix: radix)
        let m = BigUInt(radix).power(d)
        var k = 0
        while true {
            let next = k + 1
            let maxValue = (BigUInt(alphabetSize - 1) * (m.power(next) - 1)) / (m - 1)
            if maxValue >= modulus { return k }
            k = next
            if k > 100_000 { return k }
        }
    }

    /// Number-system coding: every character index becomes `digitsPerCharacter` digits in
    /// `radix`; the concatenated digits of a block form the number (written in `radix`).
    public static func encodeBlocksNumberSystem(_ text: String, alphabet: String, blockSize: Int, radix: Int) -> [BigUInt] {
        let chars = uniqueCharacters(alphabet)
        var index: [Character: UInt64] = [:]
        for (i, c) in chars.enumerated() { index[c] = UInt64(i) }
        let d = digitsPerCharacter(alphabetSize: chars.count, radix: radix)
        var m: UInt64 = 1
        for _ in 0..<d { m *= UInt64(radix) }
        return segment(text, alphabet: alphabet, blockSize: blockSize).map { block in
            var v = BigUInt()
            for c in block { v = v.multiplied(by: m, adding: index[c] ?? 0) }
            return v
        }
    }

    /// Inverse of `encodeBlocksNumberSystem` (digit groups ≥ alphabet size wrap around as in CT1).
    public static func decodeBlocksNumberSystem(_ blocks: [BigUInt], alphabet: String, blockSize: Int, radix: Int) -> String {
        let chars = uniqueCharacters(alphabet)
        guard chars.count >= 2 else { return "" }
        let d = digitsPerCharacter(alphabetSize: chars.count, radix: radix)
        var m: UInt64 = 1
        for _ in 0..<d { m *= UInt64(radix) }
        var out = ""
        for b in blocks {
            var digits: [Character] = []
            var t = b
            var i = 0
            while i < blockSize || !t.isZero {
                let (q, r) = t.quotientAndRemainder(dividingBy: m)
                digits.append(chars[Int(r % UInt64(chars.count))])
                t = q
                i += 1
            }
            out.append(contentsOf: digits.reversed())
        }
        return out
    }
}
