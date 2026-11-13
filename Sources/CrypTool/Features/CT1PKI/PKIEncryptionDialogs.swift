import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

/// CT1 IDD_RSA_ENCRYPTION / IDD_RSA_DECRYPTION ("RSA-Verschlüsselung" / "RSA-Entschlüsselung").
struct PKIRSACryptDialog: View {
    let document: CTDocument
    let decrypt: Bool
    let close: () -> Void
    @CTState private var keyID: UUID?
    @CTState private var pin = ""
    @CTState private var showTime = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decrypt ? "Decryption with RSA" : "RSA Encryption").font(.title3.weight(.semibold))
            Text(decrypt ? "Select your secret key from the PSE list." : "Choose the recipient:")
            PKIKeyTable(selection: $keyID, filter: .rsaOnly, minHeight: 200) { _ in run() }
            HStack {
                Text(decrypt ? "Note: Only PSEs containing an RSA key are shown."
                             : "Note: Here only names are displayed, which have an RSA key.")
                    .font(.callout)
                Spacer()
                if decrypt {
                    Text("PIN code:")
                    SecureField("", text: $pin).frame(width: 110)
                }
            }
            Toggle(decrypt ? "Display decryption time" : "Display encryption time", isOn: $showTime)
            Divider()
            HStack {
                Button(decrypt ? "Decrypt" : "Encrypt") { run() }
                    .keyboardShortcut(.defaultAction).disabled(keyID == nil)
                Spacer()
                PKIHelpButton(action: decrypt ? .rsaDecrypt : .rsaEncrypt)
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
    }

    private func run() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id), let pub = k.rsaPublic else {
            PKIModal.info("Choose a key identifier from the list.")
            return
        }
        do {
            let start = Date()
            if decrypt {
                guard case .rsa(let pair)? = PKIPinAccess.open(k, pin: pin) else { pin = ""; return }
                let r = try AsymmetricOps.rsaDecrypt(document.bytes, key: pair)
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(r, title: "RSA decryption of <\(document.shortName)>", parent: document,
                                           viewMode: TextCoding.looksLikeText(r) ? .text : .hex)
                close()
                if showTime { PKIModal.info("RSA decryption time:  \(PKIText.seconds(t)) seconds.") }
            } else {
                let r = try AsymmetricOps.rsaEncrypt(document.bytes, key: pub)
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(r, title: "RSA encryption of <\(document.shortName)> for <\(k.firstLast)>",
                                           parent: document, viewMode: .hex)
                close()
                if showTime { PKIModal.info("RSA encryption time: \(PKIText.seconds(t)) seconds.") }
            }
        } catch { Alerts.error(error.localizedDescription) }
    }
}

/// CT1 IDD_ECCENCRECEIVER / IDD_ECCDECRECEIVER ("Hybridverschlüsselung mit ECC-AES").
struct PKIECCHybridDialog: View {
    let document: CTDocument
    let decrypt: Bool
    let close: () -> Void
    @CTState private var keyID: UUID?
    @CTState private var pin = ""
    @CTState private var showTime = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decrypt ? "Hybrid Decryption with ECC-AES" : "Hybrid Encryption with ECC-AES").font(.title3.weight(.semibold))
            Text(decrypt ? "Select your secret key from the PSE list."
                         : "Choose a destination:")
            PKIKeyTable(selection: $keyID, filter: .ecOnly, minHeight: 200) { _ in run() }
            HStack {
                Text(decrypt ? "Note: Only PSEs containing an ECC key are shown."
                             : "Note: Only PSEs containing an ECC key are shown.")
                    .font(.callout)
                Spacer()
                if decrypt {
                    Text("PIN code:")
                    SecureField("", text: $pin).frame(width: 110)
                }
            }
            Toggle(decrypt ? "Display decryption time" : "Display encryption time", isOn: $showTime)
            Divider()
            HStack {
                Button(decrypt ? "Decrypt" : "Encrypt") { run() }
                    .keyboardShortcut(.defaultAction).disabled(keyID == nil)
                Spacer()
                PKIHelpButton(action: decrypt ? .hybridECCDecrypt : .hybridECCEncrypt)
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
    }

    private func keyTitle(_ k: StoredKey) -> String { "\(k.lastName), \(k.firstName), \(k.type.displayName)" }

    private func run() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id), let curve = k.curve, let q = k.ecPublic else {
            PKIModal.info("Choose a key identifier from the list.")
            return
        }
        do {
            let start = Date()
            if decrypt {
                guard case .ecc(let pair)? = PKIPinAccess.open(k, pin: pin) else { pin = ""; return }
                let plain: [UInt8]
                if let legacy = try? CTContainer.parse(document.text, kind: "HYBRID") {
                    plain = try HybridDialog.legacyDecrypt(legacy, material: .ecc(pair))
                } else {
                    let doc = try PKIECIESDocument.parse(document.bytes)
                    guard doc.curveID == curve.name else {
                        throw CTError("Sender and receiver must use the same elliptic curve.\n\nPlease choose a receiver key with the curve parameter \(doc.curveID)!")
                    }
                    let session = try PKIECIESDocument.decryptSessionKey(doc.encryptedSessionKey, curve: curve, privateKey: pair.d)
                    guard let p = try? SymmetricCipher.decrypt(.aes, key: session, data: doc.ciphertext) else {
                        throw CTError("The AES ciphertext could not be decrypted with the AES session key.\nOne or both components might be damaged.")
                    }
                    plain = p
                }
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(plain, title: DocumentFactory.title("ECC-AES hybrid decryption", of: document, key: keyTitle(k)),
                                           parent: document, viewMode: TextCoding.looksLikeText(plain) ? .text : .hex)
                close()
                if showTime { PKIModal.info("ECC-AES decryption time: \(PKIText.seconds(t)) seconds.") }
            } else {
                var session = [UInt8](repeating: 0, count: 32)   // CT1: AES with KEYSIZE 32
                _ = SecRandomCopyBytes(kSecRandomDefault, session.count, &session)
                let cipher = try SymmetricCipher.encrypt(.aes, key: session, data: document.bytes)
                let enc = try PKIECIESDocument.encryptSessionKey(session, curve: curve, publicKey: q)
                let out = PKIECIESDocument(receiverName: k.lastName, receiverFirstName: k.firstName, curveID: curve.name,
                                           encryptedSessionKey: enc, ciphertext: cipher).serialize()
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(out, title: DocumentFactory.title("ECC-AES hybrid encryption", of: document, key: keyTitle(k)),
                                           parent: document, method: "hybrid", key: "Sessionkey: " + PKIText.hex(session), viewMode: .hex)
                close()
                if showTime { PKIModal.info("ECC-AES encryption time: \(PKIText.seconds(t)) seconds.") }
            }
        } catch { Alerts.error(error.localizedDescription) }
    }
}
