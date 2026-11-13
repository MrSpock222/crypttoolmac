import Foundation
import CTCommon
import CTBigNum
import CTModern

// CT1 output document formats (binary documents with Windows-1252 headers):
//  * hybrid RSA-AES   (CDlgHybridEncryptionDemo::OnButtonDatenausgabe / DecHyb)
//  * ECC-AES (ECIES)  (ECIESMain.cpp writeEncFile / readEncFile)
//  * signed document  (AsymmetricEncryption.cpp PrintSignData / GetSignData)

// MARK: - Hash functions of the signature dialogs

/// CT1 signature hash functions ("MD2", "MD5", "RIPEMD-160", "SHA", "SHA-1" in CT1 order).
enum PKISignHash: String, CaseIterable, Identifiable {
    case md2 = "MD2", md5 = "MD5", ripemd160 = "RIPEMD-160", sha = "SHA", sha1 = "SHA-1"
    case md4 = "MD4", sha256 = "SHA-256", sha512 = "SHA-512"   // only in the signature demo
    var id: String { rawValue }
    /// Radio buttons of CT1's "Dokument signieren" dialog.
    static let signDialogCases: [PKISignHash] = [.md2, .md5, .ripemd160, .sha, .sha1]
    /// CT1 "Hashfunktion wählen" (signature demo).
    static let demoCases: [PKISignHash] = [.md2, .md4, .md5, .sha, .sha1, .sha256, .sha512, .ripemd160]
    var algorithm: HashAlgorithm {
        switch self {
        case .md2: return .md2
        case .md5: return .md5
        case .ripemd160: return .ripemd160
        case .sha: return .sha0
        case .sha1: return .sha1
        case .md4: return .md4
        case .sha256: return .sha256
        case .sha512: return .sha512
        }
    }
    var bits: Int { algorithm.digestLength * 8 }
    /// Name in "Verfahren2" ("RSA (SHA1)").
    var shortName: String {
        switch self {
        case .md2: return "MD2"
        case .md5: return "MD5"
        case .ripemd160: return "RIPEMD160"
        case .sha: return "SHA"
        case .sha1: return "SHA1"
        case .md4: return "MD4"
        case .sha256: return "SHA256"
        case .sha512: return "SHA512"
        }
    }
    /// DER prefix of DigestInfo (PKCS #1 v1.5) – SHA uses OID 1.3.14.3.2.18.
    var digestInfoPrefix: [UInt8] {
        switch self {
        case .md2: return DigestAlgorithmID.md2.digestInfoPrefix
        case .md5: return DigestAlgorithmID.md5.digestInfoPrefix
        case .ripemd160: return DigestAlgorithmID.ripemd160.digestInfoPrefix
        case .sha1: return DigestAlgorithmID.sha1.digestInfoPrefix
        case .sha: return [0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2B, 0x0E, 0x03, 0x02, 0x12, 0x05, 0x00, 0x04, 0x14]
        case .md4: return [0x30, 0x20, 0x30, 0x0C, 0x06, 0x08, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02, 0x04, 0x05, 0x00, 0x04, 0x10]
        case .sha256: return DigestAlgorithmID.sha256.digestInfoPrefix
        case .sha512: return DigestAlgorithmID.sha512.digestInfoPrefix
        }
    }
    static func named(_ s: String) -> PKISignHash? {
        let t = s.trimmingCharacters(in: .whitespaces).uppercased()
        switch t {
        case "MD2": return .md2
        case "MD5": return .md5
        case "RIPEMD-160", "RIPEMD160": return .ripemd160
        case "SHA", "SHA-0": return .sha
        case "SHA-1", "SHA1": return .sha1
        case "MD4": return .md4
        case "SHA-256", "SHA256": return .sha256
        case "SHA-512", "SHA512": return .sha512
        default: return nil
        }
    }
}

/// CT1 signature methods.
enum PKISignMethod: String, CaseIterable, Identifiable {
    case rsa = "RSA", dsa = "DSA", ecdsa = "ECSP-DSA", ecnr = "ECSP-NR"
    var id: String { rawValue }
    var isEC: Bool { self == .ecdsa || self == .ecnr }
    /// Hash functions CT1 enables for the method.
    var allowedHashes: [PKISignHash] {
        switch self {
        case .rsa: return PKISignHash.signDialogCases
        case .dsa: return [.sha, .sha1]
        case .ecdsa, .ecnr: return [.ripemd160, .sha1]
        }
    }
    /// CT1 "Verfahren2" used in the document title, e.g. "RSA (SHA1)" / "ECSP-DSA (SHA-1)".
    func titleName(_ h: PKISignHash) -> String {
        isEC ? "\(rawValue) (\(h.rawValue))" : "\(rawValue) (\(h.shortName))"
    }
}

// MARK: - RSA signature (EMSA-PKCS1-v1_5 like SECUDE af_sign_all)

enum PKIRSASignature {
    static func encode(_ digest: [UInt8], hash: PKISignHash, k: Int) throws -> [UInt8] {
        let t = hash.digestInfoPrefix + digest
        guard k >= t.count + 11 else { throw CTError("The RSA modulus is too small for the signature with \(hash.rawValue).") }
        return [0x00, 0x01] + [UInt8](repeating: 0xFF, count: k - t.count - 3) + [0x00] + t
    }

    static func sign(_ digest: [UInt8], hash: PKISignHash, key: RSAKeyPair) throws -> [UInt8] {
        let k = (key.n.bitLength + 7) / 8
        let m = BigUInt(bigEndianBytes: try encode(digest, hash: hash, k: k))
        return key.signRaw(m).bigEndianBytes(length: k)
    }

    static func verify(_ sig: [UInt8], digest: [UInt8], hash: PKISignHash, key: RSAPublicKey) -> Bool {
        let k = (key.n.bitLength + 7) / 8
        let s = BigUInt(bigEndianBytes: sig)
        guard s < key.n, let expected = try? encode(digest, hash: hash, k: k) else { return false }
        return key.verifyRaw(s).bigEndianBytes(length: k) == expected
    }
}

// MARK: - Signed document

struct PKISignedDocument {
    var method: String          // "RSA", "DSA", "ECSP-DSA", "ECSP-NR"
    var hash: String            // "SHA-1" …
    var keyID: String           // CT1 key identifier
    var signature: [UInt8]      // RSA/DSA signature bytes
    var c: BigUInt?             // EC signature (c, d)
    var d: BigUInt?
    var bitLength: Int
    var message: [UInt8]
    var legacy = false          // read from the old port container

    static let lSignature = "Signature:       "
    static let lLength = "                Signature length:  "
    static let lMethod = "                Algorithm:      "
    static let lHash = "                Hash function:   "
    static let lKey = "                Key:      "
    static let lMessage = "                Message:      "

    /// CT1 PrintSignData: every value is followed by 16 − (len mod 16) spaces.
    func serialize(padded: Bool = true) -> [UInt8] {
        func pad(_ n: Int) -> [UInt8] { padded ? [UInt8](repeating: 0x20, count: 16 - n % 16) : [] }
        var out = PKIText.cp1252(Self.lSignature)
        if let c, let d {
            for (tag, v) in [("[c=]", c), ("[d=]", d)] {
                out += Array(tag.utf8) + pad(4)
                let s = Array(v.toString(radix: 10).utf8)
                out += s + pad(s.count)
            }
        } else {
            out += signature + pad(signature.count)
        }
        for (label, value) in [(Self.lLength, String(bitLength)), (Self.lMethod, method), (Self.lHash, hash), (Self.lKey, keyID)] {
            out += PKIText.cp1252(label)
            let v = PKIText.cp1252(value)
            out += v + pad(v.count)
        }
        out += PKIText.cp1252(Self.lMessage) + message
        return out
    }

    static func isSigned(_ data: [UInt8]) -> Bool {
        data.starts(with: Array(lSignature.utf8)) || PKIText.find(Array("-----BEGIN CRYPTOOL SIGNATUR-----".utf8), in: data) != nil
    }

    /// Parses a CT1 signed document (or the port's former text container).
    static func parse(_ data: [UInt8]) throws -> PKISignedDocument {
        let missing = CTError("Not all keywords were found in the information section of the signature.\nPlease consider that a signed document consists of the signature information part and the document itself.\nThe signature information part could not be analyzed, therefore the signature check was not performed!")
        if !data.starts(with: Array(lSignature.utf8)) {
            if let legacy = try? parseLegacy(data) { return legacy }
            throw missing
        }
        guard let (iLen, lLen) = PKIText.findLabel(lLength, in: data, from: lSignature.count),
              let (iMeth, lMeth) = PKIText.findLabel(lMethod, in: data, from: iLen + lLen),
              let (iHash, lHash) = PKIText.findLabel(lHash, in: data, from: iMeth + lMeth),
              let (iKey, lKey) = PKIText.findLabel(lKey, in: data, from: iHash + lHash),
              let (iMsg, lMsg) = PKIText.findLabel(lMessage, in: data, from: iKey + lKey) else { throw missing }
        func field(_ a: Int, _ b: Int) -> String {
            PKIText.string(Array(data[a..<b])).trimmingCharacters(in: .whitespaces)
        }
        let bits = Int(field(iLen + lLen, iMeth)) ?? 0
        var doc = PKISignedDocument(method: field(iMeth + lMeth, iHash), hash: field(iHash + lHash, iKey),
                                    keyID: field(iKey + lKey, iMsg), signature: [], c: nil, d: nil,
                                    bitLength: bits, message: Array(data[(iMsg + lMsg)...]))
        let sigArea = Array(data[lSignature.count..<iLen])
        if sigArea.starts(with: Array("[c=]".utf8)) {
            let s = PKIText.string(sigArea)
            let parts = s.replacingOccurrences(of: "[c=]", with: " ").replacingOccurrences(of: "[d=]", with: " ")
                .split(separator: " ").map(String.init)
            guard parts.count >= 2, let c = BigUInt(parts[0]), let d = BigUInt(parts[1]) else { throw missing }
            doc.c = c; doc.d = d
        } else {
            var n = bits > 0 ? (bits + 7) / 8 : sigArea.count
            if n > sigArea.count { n = sigArea.count }
            if bits == 0 { while n > 0, sigArea[n - 1] == 0x20 { n -= 1 } }
            doc.signature = Array(sigArea[0..<n])
        }
        return doc
    }

    /// The port's former text container "-----BEGIN CRYPTOOL SIGNATUR-----".
    private static func parseLegacy(_ data: [UInt8]) throws -> PKISignedDocument {
        let c = try CTContainer.parse(TextCoding.string(from: data), kind: "SIGNATUR")
        guard let idText = c.field("Schlüssel-ID"), let id = UUID(uuidString: idText) else { throw CTError("Signature data incomplete.") }
        let keyID = MainActor.assumeIsolated { KeyStore.shared.key(id: id)?.ct1Identifier } ?? (c.field("Unterzeichner") ?? "")
        let hash = c.field("Hashverfahren").flatMap { SignatureHash(rawValue: $0) }?.hash.displayName ?? "SHA-1"
        var doc = PKISignedDocument(method: "RSA", hash: hash, keyID: keyID, signature: [], c: nil, d: nil,
                                    bitLength: 0, message: c.payload, legacy: true)
        if let sig = c.field("Signatur").flatMap(Hex.decode) {
            doc.signature = sig; doc.bitLength = sig.count * 8
        } else if let r = c.field("Signatur r").flatMap({ BigUInt($0, radix: 16) }), let s = c.field("Signatur s").flatMap({ BigUInt($0, radix: 16) }) {
            doc.method = "ECSP-DSA"; doc.c = r; doc.d = s
            doc.bitLength = r.bitLength + s.bitLength + 2
        }
        return doc
    }
}

// MARK: - Hybrid RSA-AES document

struct PKIHybridDocument {
    var keyID: String
    var encryptedSessionKey: [UInt8]
    var symmetric = "AES"
    var asymmetric = "RSA"
    var ciphertext: [UInt8]

    static let lReceiver = "Receiver:    "
    static let lKeyLength = "     Length of encrypted session key:    "
    static let lEncKey = "    Encrypted session key:    "
    static let lSym = "    Symmetric method:    "
    static let lAsym = "    Asymmetric method:    "
    static let lCipher = "    Ciphertext:    "

    func serialize() -> [UInt8] {
        var out = PKIText.cp1252(Self.lReceiver) + PKIText.cp1252(keyID)
        out += PKIText.cp1252(Self.lKeyLength) + Array(String(encryptedSessionKey.count * 8).utf8)
        out += PKIText.cp1252(Self.lEncKey) + encryptedSessionKey
        out += PKIText.cp1252(Self.lSym) + Array(symmetric.utf8)
        out += PKIText.cp1252(Self.lAsym) + Array(asymmetric.utf8)
        out += PKIText.cp1252(Self.lCipher) + ciphertext
        return out
    }

    static let notHybrid = CTError("Your input is not a valid hybrid encrypted file!\nIt could not be decrypted.\n")

    static func parse(_ data: [UInt8]) throws -> PKIHybridDocument {
        guard let (i0, l0) = PKIText.findLabel(lReceiver, in: data), i0 == 0,
              let (i1, l1) = PKIText.findLabel(lKeyLength, in: data, from: l0),
              let (i2, l2) = PKIText.findLabel(lEncKey, in: data, from: i1 + l1),
              let bits = Int(PKIText.string(Array(data[(i1 + l1)..<i2])).trimmingCharacters(in: .whitespaces)), bits > 0 else {
            throw notHybrid
        }
        let keyStart = i2 + l2, keyLen = (bits + 7) / 8
        guard keyStart + keyLen <= data.count,
              let (i3, l3) = PKIText.findLabel(lSym, in: data, from: keyStart + keyLen),
              let (i4, l4) = PKIText.findLabel(lAsym, in: data, from: i3 + l3),
              let (i5, l5) = PKIText.findLabel(lCipher, in: data, from: i4 + l4) else { throw notHybrid }
        return PKIHybridDocument(keyID: PKIText.string(Array(data[l0..<i1])),
                                 encryptedSessionKey: Array(data[keyStart..<(keyStart + keyLen)]),
                                 symmetric: PKIText.string(Array(data[(i3 + l3)..<i4])),
                                 asymmetric: PKIText.string(Array(data[(i4 + l4)..<i5])),
                                 ciphertext: Array(data[(i5 + l5)...]))
    }

    /// CT1 RSAEncrypt: the session key is left-padded with zeros to (|N|−1)/8 bytes and
    /// encrypted with textbook RSA; the result has the byte length of N.
    static func encryptSessionKey(_ key: [UInt8], with pub: RSAPublicKey) -> [UInt8] {
        let m = BigUInt(bigEndianBytes: key)
        return pub.encrypt(m).bigEndianBytes(length: (pub.n.bitLength + 7) / 8)
    }

    /// CT1 DlgHybridDecryptionDemo: decrypt and take the rightmost 16 bytes (128 bit AES key).
    static func decryptSessionKey(_ enc: [UInt8], with pair: RSAKeyPair) -> (full: [UInt8], key: [UInt8]) {
        let k = (pair.n.bitLength - 1) / 8
        let m = pair.decrypt(BigUInt(bigEndianBytes: enc) % pair.n).bigEndianBytes(length: max(k, 16))
        return (m, Array(m.suffix(16)))
    }
}

// MARK: - ECC-AES (ECIES) document

struct PKIECIESDocument {
    var receiverName: String
    var receiverFirstName: String
    var curveID: String
    var encryptedSessionKey: [UInt8]
    var ciphertext: [UInt8]

    static let lReceiver = "Receiver:"
    static let lCurve = "|Curve ID:"
    static let lKeyLen = "|Length of the ECIES-encrypted AES session key:"
    static let lCipherLen = "Byte|Ciphertext length:"
    static let lEncKey = "Byte\n\nECIES-encrypted AES session key:\n"
    static let lCipher = "|AES ciphertext:"

    func serialize() -> [UInt8] {
        var out = PKIText.cp1252(Self.lReceiver + receiverName + ", " + receiverFirstName)
        out += PKIText.cp1252(Self.lCurve + curveID)
        out += PKIText.cp1252(Self.lKeyLen + String(encryptedSessionKey.count))
        out += PKIText.cp1252(Self.lCipherLen + String(ciphertext.count))
        out += PKIText.cp1252(Self.lEncKey) + encryptedSessionKey
        out += PKIText.cp1252(Self.lCipher) + ciphertext
        return out
    }

    static let badHeader = CTError("The decryption was not successful.\nThe file has the wrong format, the header might be damaged.")

    static func parse(_ data: [UInt8]) throws -> PKIECIESDocument {
        guard let (i0, l0) = PKIText.findLabel(lReceiver, in: data), i0 == 0,
              let (i1, l1) = PKIText.findLabel(lCurve, in: data, from: l0),
              let (i2, l2) = PKIText.findLabel(lKeyLen, in: data, from: i1 + l1),
              let (i3, l3) = PKIText.findLabel(lCipherLen, in: data, from: i2 + l2),
              let (i4, l4) = PKIText.findLabel(lEncKey, in: data, from: i3 + l3),
              let keyLen = Int(PKIText.string(Array(data[(i2 + l2)..<i3]))),
              let cLen = Int(PKIText.string(Array(data[(i3 + l3)..<i4]))) else { throw badHeader }
        let ks = i4 + l4
        guard ks + keyLen <= data.count else {
            throw CTError("The decryption was not successful, the AES session key is damaged.")
        }
        guard let (i5, l5) = PKIText.findLabel(lCipher, in: data, from: ks + keyLen), i5 == ks + keyLen,
              i5 + l5 + cLen <= data.count else {
            throw CTError("The decryption was not successful, the AES ciphertext is damaged.")
        }
        let names = PKIText.string(Array(data[l0..<i1])).components(separatedBy: ", ")
        return PKIECIESDocument(receiverName: names.first ?? "", receiverFirstName: names.dropFirst().joined(separator: ", "),
                                curveID: PKIText.string(Array(data[(i1 + l1)..<i2])),
                                encryptedSessionKey: Array(data[ks..<(ks + keyLen)]),
                                ciphertext: Array(data[(i5 + l5)..<(i5 + l5 + cLen)]))
    }

    // ECIES (SEC 1 / ANSI X9.63): ephemeral point 04‖x‖y, KDF2-SHA-1 → XOR key + HMAC-SHA-1 key.

    static func encryptSessionKey(_ key: [UInt8], curve: EllipticCurve, publicKey: ECPoint) throws -> [UInt8] {
        let eph = ECKeyPair.generate(curve: curve)
        let z = try ECDH.sharedSecret(privateKey: eph.d, publicKey: publicKey, curve: curve)
        let flen = (curve.p.bitLength + 7) / 8
        guard case let .affine(x, y) = eph.Q else { throw CTError("Internal error (ephemeral point).") }
        let R = [0x04] + x.bigEndianBytes(length: flen) + y.bigEndianBytes(length: flen)
        let k = kdf2(z.bigEndianBytes(length: flen), length: key.count + 20)
        let enc = zip(key, k.prefix(key.count)).map { $0 ^ $1 }
        let tag = MAC.compute(.hmac, hash: .sha1, key: Array(k.suffix(20)), message: enc)
        return R + enc + tag
    }

    static func decryptSessionKey(_ blob: [UInt8], curve: EllipticCurve, privateKey d: BigUInt) throws -> [UInt8] {
        let flen = (curve.p.bitLength + 7) / 8
        guard blob.count > 1 + 2 * flen + 20, blob[0] == 0x04 else {
            throw CTError("The decryption was not successful, the AES session key is damaged.")
        }
        let x = BigUInt(bigEndianBytes: Array(blob[1...flen]))
        let y = BigUInt(bigEndianBytes: Array(blob[(1 + flen)...(2 * flen)]))
        let enc = Array(blob[(1 + 2 * flen)..<(blob.count - 20)])
        let z = try ECDH.sharedSecret(privateKey: d, publicKey: .affine(x: x, y: y), curve: curve)
        let k = kdf2(z.bigEndianBytes(length: flen), length: enc.count + 20)
        guard MAC.compute(.hmac, hash: .sha1, key: Array(k.suffix(20)), message: enc) == Array(blob.suffix(20)) else {
            throw CTError("The decryption was not successful, a wrong key was used for decryption.")
        }
        return zip(enc, k.prefix(enc.count)).map { $0 ^ $1 }
    }

    /// KDF2 (ISO 18033-2) with SHA-1.
    static func kdf2(_ z: [UInt8], length: Int) -> [UInt8] {
        var out: [UInt8] = []
        var counter: UInt32 = 1
        while out.count < length {
            let c: [UInt8] = [UInt8(counter >> 24), UInt8(counter >> 16 & 0xFF), UInt8(counter >> 8 & 0xFF), UInt8(counter & 0xFF)]
            out += Hashing.hash(z + c, algorithm: .sha1)
            counter += 1
        }
        return Array(out.prefix(length))
    }
}
