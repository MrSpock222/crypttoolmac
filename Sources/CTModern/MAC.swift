import CommonCrypto
import CTCommon

/// The MAC constructions of CT1's dialog "Generieren von HMACs" (DlgHMAC.cpp), in CT1 order.
public enum MACConstruction: String, CaseIterable, Codable, Sendable {
    /// H(k ‖ m)
    case secretPrefix
    /// H(m ‖ k)
    case secretSuffix
    /// H(k ‖ m ‖ k)
    case envelope
    /// H(k ‖ m ‖ k')
    case doubleKey
    /// HMAC nach RFC 2104: H((k ⊕ opad) ‖ H((k ⊕ ipad) ‖ m))
    case hmac

    /// German display name (CT1 resource strings).
    public var displayName: String {
        switch self {
        case .secretPrefix: return "H(k, m): Schlüssel vor der Nachricht"
        case .secretSuffix: return "H(m, k): Schlüssel nach der Nachricht"
        case .envelope: return "H(k, m, k): Schlüssel vor und hinter der Nachricht"
        case .doubleKey: return "H(k, m, k'): Zwei verschiedene Schlüssel"
        case .hmac: return "H(k, H(k, m)): doppeltes Hashing (RFC 2104)"
        }
    }

    /// Short formula, e.g. "H(k, m, k')".
    public var formula: String {
        switch self {
        case .secretPrefix: return "H(k, m)"
        case .secretSuffix: return "H(m, k)"
        case .envelope: return "H(k, m, k)"
        case .doubleKey: return "H(k, m, k')"
        case .hmac: return "H(k, H(k, m))"
        }
    }

    /// True if the construction uses a second key k'.
    public var requiresSecondKey: Bool { self == .doubleKey }
}

/// Message authentication codes built from the hash functions of `HashAlgorithm`.
public enum MAC {
    /// Computes the MAC. `secondKey` is only used by `.doubleKey` (nil = empty).
    public static func compute(_ c: MACConstruction, hash: HashAlgorithm, key: [UInt8], message: [UInt8],
                               secondKey: [UInt8]? = nil) -> [UInt8] {
        details(c, hash: hash, key: key, message: message, secondKey: secondKey).mac
    }

    /// Intermediate values as shown by CT1: `outerInput` is the input of the (final) hash call,
    /// `innerHash` is H((k ⊕ ipad) ‖ m) for HMAC (nil otherwise).
    public struct Details: Sendable {
        public let outerInput: [UInt8]
        public let innerHash: [UInt8]?
        public let mac: [UInt8]
    }

    /// Computes the MAC together with its intermediate values.
    public static func details(_ c: MACConstruction, hash: HashAlgorithm, key: [UInt8], message: [UInt8],
                               secondKey: [UInt8]? = nil) -> Details {
        switch c {
        case .secretPrefix:
            let input = key + message
            return Details(outerInput: input, innerHash: nil, mac: Hashing.hash(input, algorithm: hash))
        case .secretSuffix:
            let input = message + key
            return Details(outerInput: input, innerHash: nil, mac: Hashing.hash(input, algorithm: hash))
        case .envelope:
            let input = key + message + key
            return Details(outerInput: input, innerHash: nil, mac: Hashing.hash(input, algorithm: hash))
        case .doubleKey:
            let input = key + message + (secondKey ?? [])
            return Details(outerInput: input, innerHash: nil, mac: Hashing.hash(input, algorithm: hash))
        case .hmac:
            let (ipad, opad) = hmacPads(hash: hash, key: key)
            let inner = Hashing.hash(ipad + message, algorithm: hash)
            let outerInput = opad + inner
            return Details(outerInput: outerInput, innerHash: inner, mac: Hashing.hash(outerInput, algorithm: hash))
        }
    }

    /// HMAC (RFC 2104) with the block length `hash.hmacBlockLength` (as CT1).
    public static func hmac(hash: HashAlgorithm, key: [UInt8], message: [UInt8]) -> [UInt8] {
        compute(.hmac, hash: hash, key: key, message: message)
    }

    /// Key ⊕ ipad and key ⊕ opad (keys longer than the block are hashed first).
    static func hmacPads(hash: HashAlgorithm, key: [UInt8]) -> (ipad: [UInt8], opad: [UInt8]) {
        let b = hash.hmacBlockLength
        var k = key.count > b ? Hashing.hash(key, algorithm: hash) : key
        k += [UInt8](repeating: 0, count: b - k.count)
        return (k.map { $0 ^ 0x36 }, k.map { $0 ^ 0x5C })
    }
}

/// Key derivation from passwords (CT1: "Einzelverfahren ▸ Hashverfahren ▸ Schlüssel aus Passwort
/// generieren (PKCS #5)").
public enum PasswordKeyDerivation {
    /// Hash functions offered for PBKDF2 (CT1's MD2, MD5, SHA-1 plus SHA-256/SHA-512).
    public static var supportedHashes: [HashAlgorithm] { [.md2, .md5, .sha1, .sha256, .sha512] }

    /// Hash functions offered by CT1's PKCS #5 dialog (used with `pbkdf1`).
    public static var pbkdf1Hashes: [HashAlgorithm] { [.md2, .md5, .sha1] }

    /// PBKDF2 (PKCS #5 v2.0, RFC 8018) with HMAC-`hash` as PRF. Any `HashAlgorithm` works;
    /// SHA-1/256/512 use CommonCrypto.
    public static func pbkdf2(password: [UInt8], salt: [UInt8], iterations: Int, keyLength: Int,
                              hash: HashAlgorithm) throws -> [UInt8] {
        guard iterations >= 1 else { throw CTError("Die Anzahl der Iterationen muss mindestens 1 sein.") }
        guard keyLength >= 1, keyLength <= 4096 else {
            throw CTError("Die Schlüssellänge muss zwischen 1 und 4096 Byte liegen.")
        }
        let prf: CCPseudoRandomAlgorithm?
        switch hash {
        case .sha1: prf = CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1)
        case .sha256: prf = CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
        case .sha512: prf = CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
        default: prf = nil
        }
        if let prf, iterations <= Int(UInt32.max) {
            var out = [UInt8](repeating: 0, count: keyLength)
            let status = password.withUnsafeBufferPointer { pw in
                salt.withUnsafeBufferPointer { s in
                    pw.withMemoryRebound(to: Int8.self) { pwc in
                        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pwc.baseAddress, pw.count,
                                             s.baseAddress, s.count, prf, UInt32(iterations), &out, keyLength)
                    }
                }
            }
            if status == Int32(kCCSuccess) { return out }
        }
        // Generic implementation
        let (ipad, opad) = MAC.hmacPads(hash: hash, key: password)
        func prfHMAC(_ m: [UInt8]) -> [UInt8] {
            Hashing.hash(opad + Hashing.hash(ipad + m, algorithm: hash), algorithm: hash)
        }
        var out: [UInt8] = []
        var block: UInt32 = 1
        while out.count < keyLength {
            var u = prfHMAC(salt + [UInt8(block >> 24), UInt8((block >> 16) & 255), UInt8((block >> 8) & 255), UInt8(block & 255)])
            var t = u
            if iterations > 1 {
                for _ in 2...iterations {
                    u = prfHMAC(u)
                    for i in 0..<t.count { t[i] ^= u[i] }
                }
            }
            out += t
            block += 1
        }
        return Array(out.prefix(keyLength))
    }

    /// PBKDF1 (PKCS #5 v1.5) exactly as CT1's dialog computes it (KeyFromPasswordPKCS5.cpp):
    /// T₁ = H(P ‖ S), Tᵢ = H(Tᵢ₋₁); the key is the first `keyLength` bytes of T_c.
    /// `iterations` ≤ 1 means a single hash (CT1 behaviour); `keyLength` ≤ digest length.
    public static func pbkdf1(password: [UInt8], salt: [UInt8], iterations: Int, keyLength: Int,
                              hash: HashAlgorithm) throws -> [UInt8] {
        guard iterations >= 0 else { throw CTError("Die Anzahl der Iterationen darf nicht negativ sein.") }
        guard keyLength >= 1, keyLength <= hash.digestLength else {
            throw CTError("Die Schlüssellänge muss für \(hash.displayName) zwischen 1 und \(hash.digestLength) Byte liegen.")
        }
        var t = Hashing.hash(password + salt, algorithm: hash)
        if iterations > 1 {
            for _ in 1..<iterations { t = Hashing.hash(t, algorithm: hash) }
        }
        return Array(t.prefix(keyLength))
    }
}
