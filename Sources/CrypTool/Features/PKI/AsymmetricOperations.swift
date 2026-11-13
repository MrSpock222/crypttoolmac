import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

/// Simple self-describing text container ("Feld: Wert" lines + Base64 payload).
struct CTContainer {
    var kind: String
    var fields: [(String, String)]
    var payload: [UInt8]

    func serialize() -> String {
        var s = "-----BEGIN CRYPTOOL \(kind)-----\n"
        for (k, v) in fields { s += "\(k): \(v)\n" }
        s += "\n" + Base64Codec.encode(payload, lineLength: 64) + "\n"
        s += "-----END CRYPTOOL \(kind)-----\n"
        return s
    }

    static func parse(_ text: String, kind: String) throws -> CTContainer {
        let lines = text.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        guard let begin = lines.firstIndex(of: "-----BEGIN CRYPTOOL \(kind)-----"),
              let end = lines.firstIndex(of: "-----END CRYPTOOL \(kind)-----"), end > begin else {
            throw CTError("The document does not have the expected format (\(kind)).")
        }
        var fields: [(String, String)] = []
        var i = begin + 1
        while i < end, !lines[i].isEmpty {
            if let r = lines[i].range(of: ": ") {
                fields.append((String(lines[i][..<r.lowerBound]), String(lines[i][r.upperBound...])))
            }
            i += 1
        }
        let b64 = lines[i..<end].joined()
        return CTContainer(kind: kind, fields: fields, payload: try Base64Codec.decode(b64))
    }

    func field(_ name: String) -> String? { fields.first { $0.0 == name }?.1 }
}

@MainActor
enum AsymmetricOps {
    // MARK: RSA (PKCS #1 v1.5, blockwise)

    static func rsaEncrypt(_ data: [UInt8], key: RSAPublicKey) throws -> [UInt8] {
        let k = (key.n.bitLength + 7) / 8
        let chunk = k - 11
        guard chunk > 0 else { throw CTError("The key is too short.") }
        var out: [UInt8] = []
        var i = 0
        repeat {
            let block = Array(data[i..<min(i + chunk, data.count)])
            out += try PKCS1.encrypt(block, key: key)
            i += chunk
        } while i < data.count
        return out
    }

    static func rsaDecrypt(_ data: [UInt8], key: RSAKeyPair) throws -> [UInt8] {
        let k = (key.n.bitLength + 7) / 8
        guard data.count % k == 0 else { throw CTError("The length of the ciphertext (\(data.count) bytes) is not a multiple of the key length (\(k) bytes).") }
        var out: [UInt8] = []
        var i = 0
        while i < data.count {
            out += try PKCS1.decrypt(Array(data[i..<i + k]), key: key)
            i += k
        }
        return out
    }
}

// MARK: - Dialogs (entry points used by FeatureRouter; the CT1 dialogs live in Features/CT1PKI)

/// CT1 "RSA-Verschlüsselung" / "RSA-Entschlüsselung".
struct RSAEncryptDialog: View {
    let document: CTDocument
    let decrypt: Bool
    let close: () -> Void
    var body: some View { PKIRSACryptDialog(document: document, decrypt: decrypt, close: close) }
}

/// CT1 hybrid encryption: RSA-AES as data-flow diagram / step-by-step decryption, ECC-AES as receiver dialogs.
struct HybridDialog: View {
    let document: CTDocument
    let ecc: Bool
    let decrypt: Bool
    let close: () -> Void

    var body: some View {
        if ecc {
            PKIECCHybridDialog(document: document, decrypt: decrypt, close: close)
        } else if decrypt {
            if let legacy = try? CTContainer.parse(document.text, kind: "HYBRID") {
                PKIKeyChooser(headline: "Select your secret key from the PSE list.",
                              note: "Note: Only PSEs containing an RSA key are shown.",
                              filter: .rsaOnly, initial: legacy.field("Schlüssel-ID").flatMap(UUID.init(uuidString:)), withPIN: true) { id, pin in
                    guard let k = KeyStore.shared.key(id: id), let m = PKIPinAccess.open(k, pin: pin) else { return }
                    do {
                        let plain = try HybridDialog.legacyDecrypt(legacy, material: m)
                        DocumentFactory.openResult(plain, title: "Hybrid decryption of <\(document.shortName)>", parent: document,
                                                   viewMode: TextCoding.looksLikeText(plain) ? .text : .hex)
                        close()
                    } catch { Alerts.error(error.localizedDescription) }
                } cancel: { close() }
            } else {
                PKIHybridDecryptionDemo(document: document, close: close)
            }
        } else {
            PKIHybridEncryptionDemo(document: document, close: close)
        }
    }

    /// Decrypts the port's former text container "-----BEGIN CRYPTOOL HYBRID-----".
    static func legacyDecrypt(_ c: CTContainer, material: PrivateKeyMaterial) throws -> [UInt8] {
        let sessionKey: [UInt8]
        let bits = Int(c.field("Symmetrisches Verfahren")?.split(separator: "-").dropFirst().first?.prefix(3) ?? "128") ?? 128
        switch material {
        case .rsa(let pair):
            guard let hex = c.field("Verschlüsselter Sitzungsschlüssel"), let enc = Hex.decode(hex) else { throw CTError("No RSA-encrypted session key in the document.") }
            sessionKey = try PKCS1.decrypt(enc, key: pair)
        case .ecc(let pair):
            guard let xs = c.field("Ephemerer Punkt x"), let ys = c.field("Ephemerer Punkt y"),
                  let x = BigUInt(xs, radix: 16), let y = BigUInt(ys, radix: 16) else { throw CTError("No ephemeral EC point in the document.") }
            let shared = try ECDH.sharedSecret(privateKey: pair.d, publicKey: .affine(x: x, y: y), curve: pair.curve)
            sessionKey = Array(Hashing.hash(shared.bigEndianBytes(length: (pair.curve.p.bitLength + 7) / 8), algorithm: .sha256).prefix(bits / 8))
        case .dsa:
            throw CTError("A DSA key cannot be used for decryption.")
        }
        return try SymmetricCipher.decrypt(.aes, key: sessionKey, data: c.payload)
    }
}

// MARK: - Signatures

/// Hash functions of the port's former signature container (kept to read old documents).
enum SignatureHash: String, CaseIterable, Identifiable {
    case md5, sha1, sha256, sha512, ripemd160
    var id: String { rawValue }
    var hash: HashAlgorithm { HashAlgorithm(rawValue: rawValue)! }
    var digestID: DigestAlgorithmID { DigestAlgorithmID(rawValue: rawValue)! }
}

/// CT1 "Signatur eines Dokuments erstellen".
struct SignDialog: View {
    let document: CTDocument
    let close: () -> Void
    var body: some View { PKISignDialog(document: document, close: close) }
}

@MainActor
enum SignatureOps {
    /// CT1 "Signatur überprüfen": dialog "Verifizieren einer Signatur".
    static func verify(_ doc: CTDocument) {
        do {
            let signed = try PKISignedDocument.parse(doc.bytes)
            WindowPresenter.sheet(on: doc.windowControllers.first?.window, title: "Signature Verification") { close in
                PKIVerifyDialog(document: doc, signed: signed, close: close)
            }
        } catch { PKIModal.warning(error.localizedDescription) }
    }

    /// CT1 "Signatur extrahieren": dialog "Extrahierte Signatur".
    static func extract(_ doc: CTDocument) {
        do {
            let signed = try PKISignedDocument.parse(doc.bytes)
            WindowPresenter.sheet(on: doc.windowControllers.first?.window, title: "Extracted Signature") { close in
                PKIExtractDialog(document: doc, signed: signed, close: close)
            }
        } catch { PKIModal.warning(error.localizedDescription) }
    }
}
