import CTCommon

/// The modern symmetric ciphers of CT1 ("Ver-/Entschlüsseln ▸ Symmetrisch (modern)").
public enum SymmetricAlgorithm: String, CaseIterable, Codable, Sendable {
    case idea, rc2, rc4, desECB, desCBC, tripleDESECB, tripleDESCBC, aes, mars, rc6, serpent, twofish, desx, desl, desxl

    /// Menu name as in CT1.
    public var displayName: String {
        switch self {
        case .idea: return "IDEA"
        case .rc2: return "RC2"
        case .rc4: return "RC4"
        case .desECB: return "DES (ECB)"
        case .desCBC: return "DES (CBC)"
        case .tripleDESECB: return "Triple DES (ECB)"
        case .tripleDESCBC: return "Triple DES (CBC)"
        case .aes: return "AES (CBC)"
        case .mars: return "MARS"
        case .rc6: return "RC6"
        case .serpent: return "Serpent"
        case .twofish: return "Twofish"
        case .desx: return "DESX"
        case .desl: return "DESL"
        case .desxl: return "DESXL"
        }
    }

    /// Key lengths (bits) offered by CT1's key dialog (Cryptography.cpp, SymmetricEncryption).
    ///
    /// Note: Triple DES additionally accepts 192-bit keys (three-key 3DES) in `SymmetricCipher`
    /// and the brute force, although CT1 only offered 128 bit (two-key EDE).
    public var keySizesBits: [Int] {
        switch self {
        case .aes, .mars, .rc6, .serpent, .twofish: return [128, 192, 256]
        case .desECB, .desCBC, .desl: return [64]
        case .tripleDESECB, .tripleDESCBC: return [128]
        case .desx, .desxl: return [192]
        case .idea: return [128]
        case .rc2, .rc4: return Array(stride(from: 8, through: 128, by: 8))
        }
    }

    /// Default key length in bits.
    public var defaultKeyBits: Int {
        switch self {
        case .desECB, .desCBC, .desl: return 64
        case .desx, .desxl: return 192
        default: return 128
        }
    }

    /// Block size of the cipher in bytes (0 for the stream cipher RC4).
    public var blockSize: Int {
        switch self {
        case .rc4: return 0
        case .aes, .mars, .rc6, .serpent, .twofish: return 16
        case .idea, .rc2, .desECB, .desCBC, .tripleDESECB, .tripleDESCBC, .desx, .desl, .desxl: return 8
        }
    }

    /// True if the algorithm uses CT1's own padding (append 0x01, then 0x00 up to a multiple
    /// of 16 bytes; CBC with all-zero IV). These are the algorithms CT1 implemented itself
    /// (CoreCryptography.cpp); files are compatible with CT1.
    public var usesCT1Padding: Bool {
        switch self {
        case .aes, .mars, .rc6, .serpent, .twofish, .desx, .desl, .desxl: return true
        default: return false
        }
    }

    /// True for the SECUDE ECB modes of CT1 (DES and Triple DES): zero padding.
    public var usesZeroPadding: Bool { self == .desECB || self == .tripleDESECB }

    /// Mode of operation as human readable text.
    public var modeDescription: String {
        switch self {
        case .rc4: return "Stream cipher"
        case .desECB, .tripleDESECB, .idea: return "ECB"
        default: return "CBC, IV = 0"
        }
    }

    /// Padding granularity in bytes (16 for CT1 padding, block size for PKCS#7, 1 for RC4);
    /// ciphertext lengths are multiples of it.
    public var paddingUnit: Int {
        if usesCT1Padding { return 16 }
        return max(blockSize, 1)
    }

    /// True for the DES family whose least significant key bits are parity bits.
    public var hasDESParity: Bool {
        switch self {
        case .desECB, .desCBC, .tripleDESECB, .tripleDESCBC, .desl, .desx, .desxl: return true
        default: return false
        }
    }

    /// Key lengths in bytes accepted by `SymmetricCipher` (superset of `keySizesBits`).
    public var acceptedKeyBytes: ClosedRange<Int>? {
        switch self {
        case .rc2: return 1...128
        case .rc4: return 1...256
        default: return nil
        }
    }

    /// True if a key of `byteCount` bytes is valid for this algorithm.
    public func isValidKeyLength(_ byteCount: Int) -> Bool {
        if let r = acceptedKeyBytes { return r.contains(byteCount) }
        if self == .tripleDESECB || self == .tripleDESCBC { return byteCount == 16 || byteCount == 24 }
        return keySizesBits.contains(byteCount * 8)
    }

    /// Valid key lengths as text, e.g. "128, 192, 256 bits".
    var keySizesText: String {
        switch self {
        case .rc2: return "8 to 1024 bits (multiples of 8)"
        case .rc4: return "8 to 2048 bits (multiples of 8)"
        case .tripleDESECB, .tripleDESCBC: return "128 or 192 bits"
        default: return keySizesBits.map(String.init).joined(separator: ", ") + " bits"
        }
    }
}
