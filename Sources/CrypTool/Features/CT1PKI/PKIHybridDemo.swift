import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

// MARK: - Data-flow diagram symbols (CT1 bitmap buttons: R = red, G = green, B = blue, X = grey)

enum PKIFlowState { case todo, done, info, inactive }

enum PKIFlowShape { case hexagon, diamond, rectangle, oval }

struct PKIFlowSymbol: Shape {
    let kind: PKIFlowShape
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .hexagon:
            let d = r.height / 2.2
            p.move(to: CGPoint(x: r.minX + d, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - d, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX - d, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + d, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
        case .diamond:
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
        case .rectangle:
            p.addRoundedRect(in: r, cornerSize: CGSize(width: 4, height: 4))
        case .oval:
            p.addEllipse(in: r)
        }
        return p
    }
}

/// One clickable symbol of a CT1 data-flow diagram.
struct PKIFlowButton: View {
    let title: String
    let shape: PKIFlowShape
    let state: PKIFlowState
    var width: CGFloat = 170
    var height: CGFloat = 52
    let action: () -> Void

    private var color: Color {
        switch state {
        case .todo: return .red
        case .done: return .green
        case .info: return .blue
        case .inactive: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                PKIFlowSymbol(kind: shape).fill(color.opacity(state == .inactive ? 0.18 : 0.30))
                PKIFlowSymbol(kind: shape).stroke(color, lineWidth: 2)
                Text(title).font(.callout.weight(.medium)).multilineTextAlignment(.center)
                    .foregroundStyle(state == .inactive ? Color.secondary : Color.primary)
                    .padding(.horizontal, shape == .diamond ? 30 : 14)
            }
            .frame(width: width, height: height)
            .contentShape(PKIFlowSymbol(kind: shape))
        }
        .buttonStyle(.plain)
    }
}

struct PKIFlowArrow: View {
    var body: some View {
        Image(systemName: "arrow.down").font(.title3).foregroundStyle(.secondary).frame(height: 18)
    }
}

/// Text pane under a data-flow diagram (CT1: title line + Courier edit box).
struct PKIInfoPane: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.isEmpty ? " " : title).font(.headline)
            ResultBox(text: text, minHeight: 150)
        }
    }
}

// MARK: - Hybrid encryption (CT1 IDD_HYBRID_ENCRYPTION_DEMO)

struct PKIHybridEncryptionDemo: View {
    let document: CTDocument
    let close: () -> Void

    @CTState private var docBytes: [UInt8] = []
    @CTState private var docTitle = ""
    @CTState private var sessionKey: [UInt8]?
    @CTState private var keyID: UUID?
    @CTState private var cipher: [UInt8]?
    @CTState private var encKey: [UInt8]?
    @CTState private var infoTitle = ""
    @CTState private var infoText = ""
    @CTState private var loaded = false

    private var key: StoredKey? { keyID.flatMap { KeyStore.shared.key(id: $0) } }
    private let inactiveF1 = "\n\nUse F1 to get information about the sequence you\nshould follow to activate this button."

    var body: some View {
        VStack(spacing: 6) {
            Text("Hybrid Encryption with RSA-AES - Visualization with a Flow Chart").font(.title3.weight(.semibold))
            Grid(horizontalSpacing: 24, verticalSpacing: 4) {
                GridRow {
                    PKIFlowButton(title: "Open document", shape: .hexagon, state: docBytes.isEmpty ? .todo : .done, action: chooseDocument)
                    PKIFlowButton(title: "Generate session key", shape: .hexagon, state: sessionKey == nil ? .todo : .done, action: generateKey)
                    PKIFlowButton(title: "Select asymmetr. key", shape: .hexagon, state: keyID == nil ? .todo : .done, action: chooseKey)
                }
                GridRow { PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Document", shape: .diamond, state: docBytes.isEmpty ? .inactive : .info, action: showDocument)
                    PKIFlowButton(title: "Session key", shape: .diamond, state: sessionKey == nil ? .inactive : .info, action: showSessionKey)
                    PKIFlowButton(title: "Asymmetr. key", shape: .diamond, state: keyID == nil ? .inactive : .info, action: showPublicKey)
                }
                GridRow { PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Encrypt document symmetr.", shape: .rectangle,
                                  state: (docBytes.isEmpty || sessionKey == nil) ? .inactive : (cipher == nil ? .todo : .done), action: encryptDocument)
                        .gridCellColumns(1)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Encrypt session key asymmetr.", shape: .rectangle,
                                  state: (sessionKey == nil || keyID == nil) ? .inactive : (encKey == nil ? .todo : .done), action: encryptKey)
                }
                GridRow { PKIFlowArrow(); Color.clear.frame(width: 1, height: 1); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Encrypted document", shape: .diamond, state: cipher == nil ? .inactive : .info, action: showCipher)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Encrypted session key", shape: .diamond, state: encKey == nil ? .inactive : .info, action: showEncKey)
                }
                GridRow {
                    PKIFlowButton(title: "Cancel", shape: .oval, state: .done, width: 150, height: 40, action: close)
                    PKIHelpButton(action: .hybridRSAEncrypt)
                    PKIFlowButton(title: "Save", shape: .oval, state: (cipher != nil && encKey != nil) ? .done : .inactive,
                                  width: 150, height: 40, action: output)
                }
                .padding(.top, 6)
            }
            PKIInfoPane(title: infoTitle, text: infoText)
        }
        .padding(16)
        .frame(width: 700)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            docBytes = document.bytes
            docTitle = document.shortName
            showDocument()
        }
    }

    private func inactive(_ msg: String) { PKIModal.warning("This button is currently inactive!\n" + msg + inactiveF1) }

    private func chooseDocument() {
        let p = NSOpenPanel()
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let u = p.url, let d = try? Data(contentsOf: u) else { return }
        docBytes = [UInt8](d)
        docTitle = u.lastPathComponent
        cipher = nil
        showDocument()
    }

    private func generateKey() {
        var k = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, k.count, &k)
        sessionKey = k
        cipher = nil; encKey = nil
        infoTitle = ""; infoText = ""
        showSessionKey()
    }

    private func chooseKey() {
        guard KeyStore.shared.keys.contains(where: { $0.type.isRSA }) else {
            PKIModal.warning("There is no RSA key available!\nGenerate an RSA key pair first (Digital Signatures/PKI ▸ PKI ▸ Generate/Import Keys).")
            return
        }
        var chosen: UUID? = keyID
        PKIModal.run(title: "RSA key for the hybrid encryption") { done in
            PKIKeyChooser(headline: "Select the receiver key from the list.",
                          note: "Note: Here only names are displayed, which have an RSA key.",
                          filter: .rsaOnly, initial: keyID, withPIN: false) { id, _ in
                chosen = id
                done()
            } cancel: { done() }
        }
        if chosen != keyID {
            keyID = chosen
            encKey = nil
        }
        if keyID != nil { showPublicKey() }
    }

    private func showDocument() {
        guard !docBytes.isEmpty else { return inactive("Please select a file.") }
        infoTitle = docTitle
        infoText = HexDump.format(docBytes)
    }

    private func showSessionKey() {
        guard let k = sessionKey else { return inactive("Please generate a session key first.") }
        infoTitle = "Symmetric session key, selected randomly:"
        infoText = PKIText.hex(k)
    }

    private func showPublicKey() {
        guard let k = key, let p = k.rsaPublic else { return inactive("Please select the public key of the recipient.") }
        infoTitle = "Public key of: \(k.firstLast)"
        infoText = "Key identifier: \(k.ct1Identifier)\n\nRSA modulus N (\(p.n.bitLength) bits):\n\(p.n)\n\nPublic key e:\n\(p.e)"
    }

    private func encryptDocument() {
        guard let k = sessionKey, !docBytes.isEmpty else {
            return PKIModal.warning("This button is currently inactive!" + inactiveF1)
        }
        do {
            cipher = try SymmetricCipher.encrypt(.aes, key: k, data: docBytes)
            showCipher()
        } catch { Alerts.error(error.localizedDescription) }
    }

    private func encryptKey() {
        guard let s = sessionKey, let p = key?.rsaPublic else { return inactive("Please select the public key of the recipient.") }
        encKey = PKIHybridDocument.encryptSessionKey(s, with: p)
        showEncKey()
    }

    private func showCipher() {
        guard let c = cipher else { return inactive("Please encrypt the document with your session key.") }
        infoTitle = "Document encrypted symmetrically with the session key:"
        infoText = HexDump.format(c)
    }

    private func showEncKey() {
        guard let e = encKey else { return inactive("Please encrypt the session key first.") }
        infoTitle = "Session key encrypted asymmetrically with recipient's public key:"
        infoText = PKIText.hex(e)
    }

    private func output() {
        guard let c = cipher, let e = encKey, let k = key, let s = sessionKey else {
            return PKIModal.warning("This button is currently inactive!\nBefore saving, the document must be encrypted symmetric\nand the session key must be encrypted asymmetric.\n\nThe F1 key will give you further information on which sequence you can control the activities on the flowchart.")
        }
        let out = PKIHybridDocument(keyID: k.ct1Identifier, encryptedSessionKey: e, ciphertext: c).serialize()
        DocumentFactory.openResult(out, title: "Hybrid encryption of <\(docTitle)> for <\(k.firstLast)>",
                                   parent: document, method: "hybrid", key: "Sessionkey: " + PKIText.hex(s), viewMode: .hex)
        close()
    }
}

/// Key selection sub-dialog (CT1 CDlgRSAEncryption/CDlgRSADecryption with disabled extra buttons).
struct PKIKeyChooser: View {
    let headline: String
    let note: String
    let filter: PKIKeyFilter
    let initial: UUID?
    let withPIN: Bool
    let ok: (UUID, String) -> Void
    let cancel: () -> Void
    @CTState private var sel: UUID?
    @CTState private var pin = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
            PKIKeyTable(selection: $sel, filter: filter, minHeight: 200) { k in ok(k.id, pin) }
            HStack {
                Text(note).font(.callout)
                Spacer()
                if withPIN {
                    Text("PIN code:")
                    SecureField("", text: $pin).frame(width: 110)
                }
            }
            Divider()
            HStack {
                Button("OK") { if let s = sel { ok(s, pin) } }.keyboardShortcut(.defaultAction).disabled(sel == nil)
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
        .onAppear { sel = initial }
    }
}

// MARK: - Hybrid decryption (CT1 IDD_HYBRID_DECRYPTION_DEMO)

struct PKIHybridDecryptionDemo: View {
    let document: CTDocument
    let close: () -> Void

    @CTState private var parsed: PKIHybridDocument?
    @CTState private var display = ""
    @CTState private var stepLine = ""
    @CTState private var step = 0
    @CTState private var key: StoredKey?
    @CTState private var pair: RSAKeyPair?
    @CTState private var sessionKey: [UInt8]?
    @CTState private var started = false

    private let maxSteps = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hybrid Decryption with RSA-AES").font(.title3.weight(.semibold))
            Text("Step-by-step hybrid decryption:").bold()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(display).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 300)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                .onChange(of: display) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            Text(stepLine).bold()
            Divider()
            HStack {
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Decrypt") { decryptMessage() }.disabled(sessionKey == nil)
                Button("Show certificate") { if let k = key { PKICertificate.show(k) } }.disabled(key == nil)
                PKIHelpButton(action: .hybridRSADecrypt)
                Button("Continue >") { advance() }.keyboardShortcut(.defaultAction).disabled(step > maxSteps || parsed == nil)
            }
        }
        .padding(16)
        .frame(width: 640)
        .onAppear {
            guard !started else { return }
            started = true
            do {
                parsed = try PKIHybridDocument.parse(document.bytes)
                display = "As step 1 please select your certificate from the PSE and enter \nyour PIN, to be able to read your private RSA key from the PSE.\n\nClick Continue > ...\n\n"
                step = 1
            } catch {
                DispatchQueue.main.async {
                    PKIModal.warning(error.localizedDescription)
                    close()
                }
            }
        }
    }

    private func advance() {
        guard let doc = parsed else { return }
        switch step {
        case 1:
            var chosen: (UUID, String)?
            PKIModal.run(title: "RSA key for Hybrid decryption") { done in
                PKIKeyChooser(headline: "Select your secret key from the PSE list.",
                              note: "Note: Only PSEs containing an RSA key are shown.",
                              filter: .rsaOnly, initial: KeyStore.shared.key(ct1Identifier: doc.keyID)?.id, withPIN: true) { id, pin in
                    chosen = (id, pin)
                    done()
                } cancel: { done() }
            }
            guard let (id, pin) = chosen, let k = KeyStore.shared.key(id: id) else { return }
            guard case .rsa(let p)? = PKIPinAccess.open(k, pin: pin) else { return }
            guard k.ct1Identifier == doc.keyID.trimmingCharacters(in: .whitespaces) else {
                PKIModal.warning("You have selected the wrong Certificate!")
                return
            }
            key = k; pair = p
            display += "As step 2 your private RSA key is shown. It is used to decrypt\nthe session key.\n\nClick Continue > ...\n\n"
        case 2:
            guard let p = pair else { return }
            display += "Your private RSA key d is the integer number:\nd = \(p.d)\n\n\nAs step 3 your session key will be decrypted and displayed.\n\nClick Continue > ...\n"
        case 3:
            guard let p = pair else { return }
            let k = PKIHybridDocument.decryptSessionKey(doc.encryptedSessionKey, with: p).key
            sessionKey = k
            display += "\nThe session key is the following 128 bit number:\nSession key: \(PKIText.hex(k)) \n\nClicking Decrypt\n- decrypts the message with the session key and\n- displays the decrypted message within the main window and\n- closes this dialog box.\n\nClick Decrypt.\n\n"
        default:
            return
        }
        stepLine = "Step \(step) out of a maximum of \(maxSteps) steps."
        step += 1
    }

    private func decryptMessage() {
        guard let doc = parsed, let k = sessionKey else { return }
        do {
            let plain = try SymmetricCipher.decrypt(.aes, key: k, data: doc.ciphertext)
            DocumentFactory.openResult(plain, title: "Hybrid decryption of <\(document.shortName)>", parent: document,
                                       viewMode: TextCoding.looksLikeText(plain) ? .text : .hex)
            close()
        } catch { Alerts.error(error.localizedDescription) }
    }
}
