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
            Text(decrypt ? "RSA-Entschlüsselung" : "RSA-Verschlüsselung").font(.title3.weight(.semibold))
            Text(decrypt ? "Wählen Sie Ihren geheimen Schlüssel aus der Liste der PSEs aus:" : "Wählen Sie den Empfänger:")
            PKIKeyTable(selection: $keyID, filter: .rsaOnly, minHeight: 200) { _ in run() }
            HStack {
                Text(decrypt ? "Bemerkung: Es werden nur Namen mit einem RSA Schlüssel angezeigt."
                             : "Bemerkung: Es werden nur Namen angezeigt, die einen RSA-Schlüssel haben.")
                    .font(.callout)
                Spacer()
                if decrypt {
                    Text("PIN-Code:")
                    SecureField("", text: $pin).frame(width: 110)
                }
            }
            Toggle(decrypt ? "Zum Entschlüsseln benötigte Zeit anzeigen" : "Zum Verschlüsseln benötigte Zeit anzeigen", isOn: $showTime)
            Divider()
            HStack {
                Button(decrypt ? "Entschlüsseln" : "Verschlüsseln") { run() }
                    .keyboardShortcut(.defaultAction).disabled(keyID == nil)
                Spacer()
                PKIHelpButton(action: decrypt ? .rsaDecrypt : .rsaEncrypt)
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
    }

    private func run() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id), let pub = k.rsaPublic else {
            PKIModal.info("Wählen Sie einen Schlüsselbezeichner aus der Liste.")
            return
        }
        do {
            let start = Date()
            if decrypt {
                guard case .rsa(let pair)? = PKIPinAccess.open(k, pin: pin) else { pin = ""; return }
                let r = try AsymmetricOps.rsaDecrypt(document.bytes, key: pair)
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(r, title: "RSA-Entschlüsselung von <\(document.shortName)>", parent: document,
                                           viewMode: TextCoding.looksLikeText(r) ? .text : .hex)
                close()
                if showTime { PKIModal.info("Für die RSA-Entschlüsselung benötigte Zeit: \(PKIText.seconds(t)) Sekunden.") }
            } else {
                let r = try AsymmetricOps.rsaEncrypt(document.bytes, key: pub)
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(r, title: "RSA-Verschlüsselung von <\(document.shortName)> für <\(k.firstLast)>",
                                           parent: document, viewMode: .hex)
                close()
                if showTime { PKIModal.info("Für die RSA-Verschlüsselung benötigte Zeit: \(PKIText.seconds(t)) Sekunden.") }
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
            Text(decrypt ? "Hybridentschlüsselung mit ECC-AES" : "Hybridverschlüsselung mit ECC-AES").font(.title3.weight(.semibold))
            Text(decrypt ? "Wählen Sie Ihren geheimen Schlüssel aus der Liste der PSEs aus und geben Sie die PIN ein:"
                         : "Wählen Sie den Empfänger aus:")
            PKIKeyTable(selection: $keyID, filter: .ecOnly, minHeight: 200) { _ in run() }
            HStack {
                Text(decrypt ? "Bemerkung: Es werden nur Namen mit einem ECC Schlüssel angezeigt."
                             : "Bemerkung: Es werden nur Namen angezeigt, die einen ECC-Schlüssel haben.")
                    .font(.callout)
                Spacer()
                if decrypt {
                    Text("PIN-Code:")
                    SecureField("", text: $pin).frame(width: 110)
                }
            }
            Toggle(decrypt ? "Zum Entschlüsseln benötigte Zeit anzeigen" : "Zum Verschlüsseln benötigte Zeit anzeigen", isOn: $showTime)
            Divider()
            HStack {
                Button(decrypt ? "Entschlüsseln" : "Verschlüsseln") { run() }
                    .keyboardShortcut(.defaultAction).disabled(keyID == nil)
                Spacer()
                PKIHelpButton(action: decrypt ? .hybridECCDecrypt : .hybridECCEncrypt)
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
    }

    private func keyTitle(_ k: StoredKey) -> String { "\(k.lastName), \(k.firstName), \(k.type.displayName)" }

    private func run() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id), let curve = k.curve, let q = k.ecPublic else {
            PKIModal.info("Wählen Sie einen Schlüsselbezeichner aus der Liste.")
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
                        throw CTError("Sender und Empfänger müssen die gleiche elliptische Kurve verwenden.\n\n Bitte wählen Sie einen Empfängerschlüssel mit dem Kurvenparameter \(doc.curveID)!")
                    }
                    let session = try PKIECIESDocument.decryptSessionKey(doc.encryptedSessionKey, curve: curve, privateKey: pair.d)
                    guard let p = try? SymmetricCipher.decrypt(.aes, key: session, data: doc.ciphertext) else {
                        throw CTError("Der AES-Geheimtext konnte nicht mit dem AES-Sessionkey entschlüsselt werden.\nEventuell ist einer der beiden oder beide beschädigt.")
                    }
                    plain = p
                }
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(plain, title: DocumentFactory.title("ECC-AES-Hybrid-Entschlüsselung", of: document, key: keyTitle(k)),
                                           parent: document, viewMode: TextCoding.looksLikeText(plain) ? .text : .hex)
                close()
                if showTime { PKIModal.info("Für die ECC-AES-Entschlüsselung benötigte Zeit: \(PKIText.seconds(t)) Sekunden.") }
            } else {
                var session = [UInt8](repeating: 0, count: 32)   // CT1: AES with KEYSIZE 32
                _ = SecRandomCopyBytes(kSecRandomDefault, session.count, &session)
                let cipher = try SymmetricCipher.encrypt(.aes, key: session, data: document.bytes)
                let enc = try PKIECIESDocument.encryptSessionKey(session, curve: curve, publicKey: q)
                let out = PKIECIESDocument(receiverName: k.lastName, receiverFirstName: k.firstName, curveID: curve.name,
                                           encryptedSessionKey: enc, ciphertext: cipher).serialize()
                let t = Date().timeIntervalSince(start)
                DocumentFactory.openResult(out, title: DocumentFactory.title("ECC-AES-Hybrid-Verschlüsselung", of: document, key: keyTitle(k)),
                                           parent: document, method: "hybrid", key: "Sessionkey: " + PKIText.hex(session), viewMode: .hex)
                close()
                if showTime { PKIModal.info("Für die ECC-AES-Verschlüsselung benötigte Zeit: \(PKIText.seconds(t)) Sekunden.") }
            }
        } catch { Alerts.error(error.localizedDescription) }
    }
}
