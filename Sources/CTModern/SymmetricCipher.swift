import CommonCrypto
import CTCipherC
import CTCommon

/// Encryption / decryption with the modern symmetric ciphers, compatible with CT1.
///
/// Conventions:
/// * CBC modes use an all-zero IV (as CT1).
/// * AES, MARS, RC6, Serpent, Twofish, DESX, DESL, DESXL use CT1's padding (append 0x01, then
///   0x00 up to a multiple of 16 bytes) – files are interchangeable with CT1.
/// * IDEA, RC2, DES and Triple DES: CT1 used the proprietary SECUDE library there
///   (SecudeCryptography.cpp `select_algorithm`); modes and paddings as documented in CT1's help:
///   DES (ECB) `desECB` and Triple DES (ECB) `desEDE`: zero padding up to the block size
///   (nothing is appended to block aligned data, decryption cannot remove it);
///   DES (CBC) `desCBC_pad`: zero bytes, the last byte holds the number of message bytes in the
///   last block – block aligned data get a whole zero block (help page "DES (CBC)");
///   Triple DES (CBC), RC2 (CBC) and IDEA (ECB): PKCS#7. Triple DES with a 128-bit key is
///   two-key EDE.
/// * RC4 is a stream cipher without padding.
/// * RC2 uses an effective key length of 8 × key length in bits (RFC 2268, at most 1024).
/// * MARS, RC6, Serpent and Twofish run the original AES submission code exactly as CT1 calls
///   it. Note for Serpent: that API reads the hex key as one big-endian number, so the key bytes
///   are the reverse of the NESSIE/Crypto++ byte order (data bytes are not affected).
public enum SymmetricCipher {

    /// Encrypts `data` (padding is added).
    public static func encrypt(_ alg: SymmetricAlgorithm, key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        try checkKey(alg, key)
        let padded = pad(alg, data)
        return try crypt(alg, decrypt: false, key: key, data: padded)
    }

    /// Decrypts `data` and removes the padding. Throws if the ciphertext length or the padding
    /// is invalid (usually a wrong key); `decryptRaw` returns the result without padding check.
    public static func decrypt(_ alg: SymmetricAlgorithm, key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        let raw = try decryptRaw(alg, key: key, data: data)
        return try unpad(alg, raw)
    }

    /// Decrypts without removing/checking the padding. The ciphertext length must be a multiple
    /// of the padding unit (16 bytes for CT1-padded algorithms, block size otherwise).
    public static func decryptRaw(_ alg: SymmetricAlgorithm, key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        try checkKey(alg, key)
        try checkCiphertextLength(alg, data.count)
        return try crypt(alg, decrypt: true, key: key, data: data)
    }

    /// Encrypts block aligned data without adding padding (length must be a multiple of the
    /// block size; any length for RC4).
    public static func encryptRaw(_ alg: SymmetricAlgorithm, key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        try checkKey(alg, key)
        if alg.blockSize > 0 && data.count % alg.blockSize != 0 {
            throw CTError("Die Datenlänge (\(data.count) Byte) ist kein Vielfaches der Blocklänge (\(alg.blockSize) Byte).")
        }
        return try crypt(alg, decrypt: false, key: key, data: data)
    }

    // MARK: - Padding

    /// Applies the padding used for `alg` (see type documentation).
    public static func pad(_ alg: SymmetricAlgorithm, _ data: [UInt8]) -> [UInt8] {
        if alg == .rc4 { return data }
        var out = data
        if alg.usesCT1Padding {
            out.append(0x01)
            while out.count % 16 != 0 { out.append(0) }
        } else if alg.usesZeroPadding {
            while out.count % alg.blockSize != 0 { out.append(0) }
        } else if alg == .desCBC {
            let r = data.count % 8
            out.append(contentsOf: [UInt8](repeating: 0, count: 7 - r))
            out.append(UInt8(r))
        } else {
            let bs = alg.blockSize
            let n = bs - data.count % bs
            out.append(contentsOf: [UInt8](repeating: UInt8(n), count: n))
        }
        return out
    }

    /// Removes the padding used for `alg`; throws on invalid padding.
    public static func unpad(_ alg: SymmetricAlgorithm, _ data: [UInt8]) throws -> [UInt8] {
        if alg == .rc4 { return data }
        let bad = CTError("Ungültiges Padding nach der Entschlüsselung – falscher Schlüssel oder beschädigter Geheimtext?")
        if alg.usesCT1Padding {
            // CT1: strip trailing zeros, then the 0x01 marker (at most 15 zeros).
            var i = data.count - 1
            while i >= 0 && data[i] == 0 { i -= 1 }
            guard i >= 0, data[i] == 0x01, data.count - 1 - i <= 15 else { throw bad }
            return Array(data[0..<i])
        } else if alg.usesZeroPadding {
            return data
        } else if alg == .desCBC {
            // SECUDE desCBC_pad: last byte = number of message bytes in the last block
            guard data.count >= 8, let last = data.last, last < 8 else { throw bad }
            return Array(data[0..<(data.count - 8 + Int(last))])
        } else {
            guard let last = data.last, last >= 1, Int(last) <= alg.blockSize, Int(last) <= data.count else { throw bad }
            let n = Int(last)
            for b in data[(data.count - n)...] where b != last { throw bad }
            return Array(data[0..<(data.count - n)])
        }
    }

    // MARK: - Internals

    static func checkKey(_ alg: SymmetricAlgorithm, _ key: [UInt8]) throws {
        guard alg.isValidKeyLength(key.count) else {
            throw CTError("Ungültige Schlüssellänge für \(alg.displayName): \(key.count * 8) Bit (erlaubt: \(alg.keySizesText)).")
        }
    }

    static func checkCiphertextLength(_ alg: SymmetricAlgorithm, _ count: Int) throws {
        if alg == .rc4 { return }
        let unit = alg.paddingUnit
        if count == 0 || count % unit != 0 {
            throw CTError("Die Länge des Geheimtexts (\(count) Byte) ist kein Vielfaches von \(unit) Byte – keine gültige \(alg.displayName)-Verschlüsselung.")
        }
    }

    static func crypt(_ alg: SymmetricAlgorithm, decrypt: Bool, key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        if data.isEmpty { return [] }
        var out = [UInt8](repeating: 0, count: data.count)
        let status = key.withUnsafeBufferPointer { k in
            data.withUnsafeBufferPointer { i in
                out.withUnsafeMutableBufferPointer { o in
                    rawCrypt(alg, decrypt: decrypt, key: k, input: i, output: o)
                }
            }
        }
        if !status {
            throw CTError("\(alg.displayName): Fehler bei der \(decrypt ? "Ent" : "Ver")schlüsselung.")
        }
        return out
    }

    /// Low level block operation without padding (CBC with zero IV / ECB / RC4 as defined for
    /// `alg`). `output.count` must be ≥ `input.count`; input must be block aligned. Thread safe.
    static func rawCrypt(_ alg: SymmetricAlgorithm, decrypt: Bool,
                         key: UnsafeBufferPointer<UInt8>,
                         input: UnsafeBufferPointer<UInt8>,
                         output: UnsafeMutableBufferPointer<UInt8>) -> Bool {
        guard let kp = key.baseAddress, let ip = input.baseAddress, let op = output.baseAddress else {
            return input.isEmpty
        }
        let n = input.count
        let kl = key.count
        let d: Int32 = decrypt ? 1 : 0
        switch alg {
        case .aes:
            return commonCrypto(decrypt, CCAlgorithm(kCCAlgorithmAES), ecb: false, kp, kl, ip, op, n)
        case .desECB:
            return commonCrypto(decrypt, CCAlgorithm(kCCAlgorithmDES), ecb: true, kp, kl, ip, op, n)
        case .desCBC:
            return commonCrypto(decrypt, CCAlgorithm(kCCAlgorithmDES), ecb: false, kp, kl, ip, op, n)
        case .tripleDESECB, .tripleDESCBC:
            let ecb = alg == .tripleDESECB
            if kl == 24 {
                return commonCrypto(decrypt, CCAlgorithm(kCCAlgorithm3DES), ecb: ecb, kp, 24, ip, op, n)
            }
            // two-key 3DES: K1 K2 K1
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 24) { k3 in
                let b = k3.baseAddress!
                b.update(from: kp, count: 16)
                (b + 16).update(from: kp, count: 8)
                return commonCrypto(decrypt, CCAlgorithm(kCCAlgorithm3DES), ecb: ecb, b, 24, ip, op, n)
            }
        case .mars: return ctc_mars_cbc(d, kp, kl, nil, ip, op, n) == CTC_OK
        case .rc6: return ctc_rc6_cbc(d, kp, kl, nil, ip, op, n) == CTC_OK
        case .serpent: return ctc_serpent_cbc(d, kp, kl, nil, ip, op, n) == CTC_OK
        case .twofish: return ctc_twofish_cbc(d, kp, kl, nil, ip, op, n) == CTC_OK
        case .desx: return ctc_desxl_cbc(CTC_VARIANT_DESX, d, kp, kl, nil, ip, op, n) == CTC_OK
        case .desl: return ctc_desxl_cbc(CTC_VARIANT_DESL, d, kp, kl, nil, ip, op, n) == CTC_OK
        case .desxl: return ctc_desxl_cbc(CTC_VARIANT_DESXL, d, kp, kl, nil, ip, op, n) == CTC_OK
        case .idea:
            guard kl == 16 else { return false }
            return ctc_idea_crypt(d, 0, kp, nil, ip, op, n) == CTC_OK   // SECUDE idea: ECB
        case .rc2:
            return ctc_rc2_crypt(d, 1, kp, kl, Int32(min(kl * 8, 1024)), nil, ip, op, n) == CTC_OK
        case .rc4:
            RC4.process(key: key, input: input, output: output)
            return true
        }
    }

    /// Like `rawCrypt`, but DES/Triple DES use the C DES (no CommonCrypto context setup per key),
    /// which is about 2–3× faster for the brute-force analysis. Results are identical.
    static func rawCryptFast(_ alg: SymmetricAlgorithm, decrypt: Bool,
                             key: UnsafeBufferPointer<UInt8>,
                             input: UnsafeBufferPointer<UInt8>,
                             output: UnsafeMutableBufferPointer<UInt8>) -> Bool {
        switch alg {
        case .desECB, .desCBC, .tripleDESECB, .tripleDESCBC:
            guard let kp = key.baseAddress, let ip = input.baseAddress, let op = output.baseAddress else { return false }
            let cbc: Int32 = (alg == .desCBC || alg == .tripleDESCBC) ? 1 : 0
            return ctc_des_crypt(decrypt ? 1 : 0, cbc, kp, key.count, nil, ip, op, input.count) == CTC_OK
        default:
            return rawCrypt(alg, decrypt: decrypt, key: key, input: input, output: output)
        }
    }

    /// AES-CBC decryption (zero IV, no padding) with a caller-provided CommonCrypto context
    /// buffer – avoids the allocation of `CCCrypt` per key (brute force).
    static func aesDecryptNoAlloc(key: UnsafeBufferPointer<UInt8>, input: UnsafeBufferPointer<UInt8>,
                                  output: UnsafeMutableBufferPointer<UInt8>,
                                  scratch: UnsafeMutableRawPointer, scratchSize: Int) -> Bool {
        var ref: CCCryptorRef?
        var used = 0
        guard CCCryptorCreateFromData(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), 0,
                                      key.baseAddress, key.count, nil, scratch, scratchSize, &ref, &used) == CCCryptorStatus(kCCSuccess),
              let ref else {
            return rawCrypt(.aes, decrypt: true, key: key, input: input, output: output)
        }
        defer { CCCryptorRelease(ref) }
        var moved = 0
        let st = CCCryptorUpdate(ref, input.baseAddress, input.count, output.baseAddress, output.count, &moved)
        return st == CCCryptorStatus(kCCSuccess) && moved == input.count
    }

    @inline(__always)
    private static func commonCrypto(_ decrypt: Bool, _ alg: CCAlgorithm, ecb: Bool,
                                     _ key: UnsafeRawPointer, _ keyLen: Int,
                                     _ input: UnsafeRawPointer, _ output: UnsafeMutableRawPointer,
                                     _ count: Int) -> Bool {
        var moved = 0
        let status = CCCrypt(CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), alg,
                             CCOptions(ecb ? kCCOptionECBMode : 0),
                             key, keyLen, nil, input, count, output, count, &moved)
        return status == CCCryptorStatus(kCCSuccess) && moved == count
    }
}

/// RC4 stream cipher (ARCFOUR).
enum RC4 {
    static func process(key: UnsafeBufferPointer<UInt8>, input: UnsafeBufferPointer<UInt8>,
                        output: UnsafeMutableBufferPointer<UInt8>) {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 256) { sb in
            let s = sb.baseAddress!
            for i in 0..<256 { s[i] = UInt8(i) }
            let kl = key.count
            var j = 0
            for i in 0..<256 {
                j = (j + Int(s[i]) + Int(key[i % kl])) & 255
                let t = s[i]; s[i] = s[j]; s[j] = t
            }
            var i = 0
            j = 0
            for n in 0..<input.count {
                i = (i + 1) & 255
                j = (j + Int(s[i])) & 255
                let t = s[i]; s[i] = s[j]; s[j] = t
                output[n] = input[n] ^ s[(Int(s[i]) + Int(s[j])) & 255]
            }
        }
    }
}
