import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

/// CT1 "Signaturdemo (Signaturerzeugung)" – IDD_SIGNATURE_DEMO "Schrittweise Signaturerzeugung":
/// data-flow diagram with the sub-dialogs "Hashfunktion wählen", "RSA-Schlüssel generieren" and
/// "Zertifikat und PSE erzeugen". The output is a signed document in CT1's format.
struct SignatureDemoView: View {
    let document: CTDocument?

    @CTState private var docBytes: [UInt8] = []
    @CTState private var docName = ""
    @CTState private var hash: PKISignHash?
    @CTState private var rsa: RSAKeyPair?
    @CTState private var cert: StoredKey?
    @CTState private var certImported = false
    @CTState private var hashValue: [UInt8]?
    @CTState private var encHash: [UInt8]?
    @CTState private var signed: [UInt8]?
    @CTState private var infoTitle = ""
    @CTState private var infoText = ""
    @CTState private var started = false
    @StateObject private var windowBox = PKIWindowBox()

    private let f1 = "\n\nUse F1 to get information about the sequence you\nshould follow to activate this button."

    var body: some View {
        VStack(spacing: 6) {
            Grid(horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    PKIFlowButton(title: "Open document", shape: .hexagon, state: docBytes.isEmpty ? .todo : .done, width: 150, action: openDocument)
                    PKIFlowButton(title: "Select hash function", shape: .hexagon, state: hash == nil ? .todo : .done, width: 150, action: chooseHash)
                    PKIFlowButton(title: "Generate key", shape: .hexagon, state: rsa == nil ? .todo : .done, width: 150, action: generateKey)
                    PKIFlowButton(title: "Provide certificate", shape: .hexagon,
                                  state: rsa == nil ? .inactive : (cert == nil ? .todo : .done), width: 150, action: provideCertificate)
                }
                GridRow { PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Document", shape: .diamond, state: docBytes.isEmpty ? .inactive : .info, width: 150, action: infoDocument)
                    PKIFlowButton(title: "Hash function", shape: .diamond, state: hash == nil ? .inactive : .info, width: 150, action: infoHashAlg)
                    PKIFlowButton(title: "RSA key", shape: .diamond, state: rsa == nil ? .inactive : .info, width: 150, action: infoKey)
                    PKIFlowButton(title: "Certificate", shape: .diamond, state: cert == nil ? .inactive : .info, width: 150, action: infoCert)
                }
                GridRow { PKIFlowArrow(); Color.clear.frame(width: 1, height: 1); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Compute hash value", shape: .rectangle,
                                  state: (docBytes.isEmpty || hash == nil) ? .inactive : (hashValue == nil ? .todo : .done), width: 150, action: computeHash)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Encrypt hash value", shape: .rectangle,
                                  state: (hashValue == nil || rsa == nil) ? .inactive : (encHash == nil ? .todo : .done), width: 150, action: encryptHash)
                    PKIFlowButton(title: "Generate signature", shape: .rectangle,
                                  state: (encHash == nil || cert == nil) ? .inactive : (signed == nil ? .todo : .done), width: 150, action: combine)
                }
                GridRow { PKIFlowArrow(); Color.clear.frame(width: 1, height: 1); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Hash value", shape: .diamond, state: hashValue == nil ? .inactive : .info, width: 150, action: infoHash)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Encrypted hash value", shape: .diamond, state: encHash == nil ? .inactive : .info, width: 150, action: infoEncHash)
                    PKIFlowButton(title: "Signature", shape: .diamond, state: signed == nil ? .inactive : .info, width: 150, action: infoSign)
                }
                GridRow {
                    PKIFlowButton(title: "Cancel", shape: .oval, state: .done, width: 130, height: 38) { windowBox.window?.close() }
                    PKIHelpButton(action: .signatureDemo)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "OK", shape: .oval, state: signed == nil ? .inactive : .done, width: 130, height: 38, action: output)
                }
                .padding(.top, 4)
            }
            PKIInfoPane(title: infoTitle, text: infoText)
        }
        .padding(14)
        .frame(minWidth: 720)
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Step by Step Signature Generation" })
        .onAppear {
            guard !started else { return }
            started = true
            if let d = document, !d.bytes.isEmpty {
                docBytes = d.bytes
                docName = d.shortName
                infoDocument()
            }
        }
    }

    private func inactive(_ m: String = "") { PKIModal.warning("This button is currently inactive!" + (m.isEmpty ? "" : "\n" + m) + f1) }

    // MARK: Actions

    private func openDocument() {
        let p = NSOpenPanel()
        p.title = "Open document"
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let u = p.url else { return }
        let d = (try? Data(contentsOf: u)).map { [UInt8]($0) } ?? []
        guard !d.isEmpty else { return PKIModal.warning("File is empty!\nPlease select a non empty file.") }
        docBytes = d
        docName = u.lastPathComponent
        hashValue = nil; encHash = nil; signed = nil
        infoDocument()
    }

    private func chooseHash() {
        var chosen = hash ?? .sha1
        var ok = false
        PKIModal.run(title: "Select a Hash Function") { close in
            PKIHashChooser(selection: chosen) { h in chosen = h; ok = true; close() } cancel: { close() }
        }
        guard ok else { return }
        if chosen != hash { hashValue = nil; encHash = nil; signed = nil }
        hash = chosen
        infoHashAlg()
    }

    private func generateKey() {
        var result: RSAKeyPair?
        PKIModal.run(title: "Generate RSA Key") { close in
            PKIDemoRSAKeyView(initial: rsa) { k in result = k; close() } cancel: { close() }
        }
        guard let k = result else { return }
        if k != rsa { encHash = nil; signed = nil; cert = nil; certImported = false }
        rsa = k
        infoKey()
    }

    private func provideCertificate() {
        guard let k = rsa else { return inactive("Please generate a key first.") }
        var result: (StoredKey, RSAKeyPair, Bool)?
        PKIModal.run(title: "Create Certificate and PSE") { close in
            PKICertificateGenerationView(key: k) { stored, pair, imported in result = (stored, pair, imported); close() } cancel: { close() }
        }
        guard let (stored, pair, imported) = result else { return }
        if pair != rsa { encHash = nil }
        rsa = pair
        cert = stored
        certImported = imported
        signed = nil
        infoCert()
    }

    private func computeHash() {
        guard let h = hash, !docBytes.isEmpty else { return inactive() }
        hashValue = Hashing.hash(docBytes, algorithm: h.algorithm)
        encHash = nil; signed = nil
        infoHash()
    }

    private func encryptHash() {
        guard let hv = hashValue, let h = hash, let k = rsa else { return inactive() }
        do {
            encHash = try PKIRSASignature.sign(hv, hash: h, key: k)
            signed = nil
            infoEncHash()
        } catch { PKIModal.warning(error.localizedDescription) }
    }

    private func combine() {
        guard let e = encHash, let c = cert, let h = hash else { return inactive() }
        let doc = PKISignedDocument(method: "RSA", hash: h.rawValue, keyID: c.ct1Identifier, signature: e, c: nil, d: nil,
                                    bitLength: e.count * 8, message: docBytes)
        signed = doc.serialize(padded: false)
        infoSign()
    }

    private func output() {
        guard let s = signed, let h = hash, let c = cert else { return inactive() }
        DocumentFactory.openResult(s, title: "RSA (\(h.rawValue)) signature of <\(docName)>", parent: document, viewMode: .hex)
        var msg = "Congratulations! \n\nYou have successfully created an RSA signature of the document \(docName). \n\n"
        msg += certImported
            ? "For this purpose you have imported the RSA key together with a certificate from the PSE file: \(c.ct1Identifier). \n\n"
            : "For this purpose you have generated a new RSA key and stored it together with a certificate in the PSE file \(c.ct1Identifier). \n\n"
        msg += "As the hash function you have selected \(h.rawValue). "
        windowBox.window?.close()
        PKIModal.info(msg)
    }

    // MARK: Info symbols

    private func infoDocument() {
        guard !docBytes.isEmpty else { return inactive("Please select a file.") }
        infoTitle = "Document: \(docName)"
        infoText = HexDump.format(Array(docBytes.prefix(64 * 1024)))
    }

    private func infoHashAlg() {
        guard let h = hash else { return inactive() }
        infoTitle = "Hash function"
        infoText = "Name:                   \(h.rawValue) \nLength in bits:         \(h.bits)\nAlgorithm ID:           \(PKIText.hex(h.digestInfoPrefix))\n"
    }

    private func infoKey() {
        guard let k = rsa else { return inactive() }
        infoTitle = "RSA key of signer"
        infoText = "Bit length of N:         \(k.n.bitLength)\nRSA modulus N:          \(k.n)\nphi(N) = (p-1)(q-1):    \(k.phi)\nPublic key:             \(k.e)\nPrivate key:            \(k.d)\n"
    }

    private func infoCert() {
        guard let c = cert else { return inactive() }
        infoTitle = "Certificate of signer (added to signature for examination)"
        infoText = PKICertificate.text(c)
    }

    private func infoHash() {
        guard let hv = hashValue, let h = hash else { return inactive("Please encrypt the document with your session key.") }
        infoTitle = "\(h.rawValue) hash of <\(docName)>"
        infoText = PKIText.hex(hv)
    }

    private func infoEncHash() {
        guard let e = encHash, let hv = hashValue, let h = hash, let k = rsa else { return inactive() }
        let kLen = (k.n.bitLength + 7) / 8
        let block = (try? PKIRSASignature.encode(hv, hash: h, k: kLen)) ?? []
        let padLen = max(0, kLen - h.digestInfoPrefix.count - hv.count)
        infoTitle = "Hash value encrypted with the private key of the signer"
        var t = "Padding string:         \(PKIText.hex(Array(block.prefix(padLen))))\n"
        t += "Algorithm ID:           \(PKIText.hex(h.digestInfoPrefix))\n"
        t += "Hash value:             \(PKIText.hex(hv))\n"
        t += "ASN-1 hash value:       \(PKIText.hex(block))\n"
        t += "Length in bits:         \(block.count * 8)\n"
        t += "Encrypted hash value:   \(PKIText.hex(e))\n"
        t += "Length in bits:         \(e.count * 8)\n"
        infoText = t
    }

    private func infoSign() {
        guard let s = signed, let h = hash else { return inactive() }
        infoTitle = "RSA (\(h.shortName)) signature of <\(docName)>"
        infoText = HexDump.format(s)
    }
}

/// CT1 IDD_SELECT_HASHFUNCTION "Hashfunktion wählen" (signature demo variant).
struct PKIHashChooser: View {
    @CTState var selection: PKISignHash
    let ok: (PKISignHash) -> Void
    let cancel: () -> Void

    init(selection: PKISignHash, ok: @escaping (PKISignHash) -> Void, cancel: @escaping () -> Void) {
        self._selection = CTState(initialValue: selection)
        self.ok = ok
        self.cancel = cancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PKIGroup("Hash function") {
                Picker("", selection: $selection) {
                    ForEach(PKISignHash.demoCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.radioGroup).labelsHidden()
            }
            HStack {
                Button("OK") { ok(selection) }.keyboardShortcut(.defaultAction)
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

/// CT1 IDD_DEMO_RSAKEY_GENERATION "RSA-Schlüssel generieren": own primes p, q and exponent e.
struct PKIDemoRSAKeyView: View {
    let initial: RSAKeyPair?
    let ok: (RSAKeyPair) -> Void
    let cancel: () -> Void
    @CTState private var p = ""
    @CTState private var q = ""
    @CTState private var e = "65537"
    @CTState private var started = false

    private var pv: BigUInt? { BigUInt(p.filter { !$0.isWhitespace }) }
    private var qv: BigUInt? { BigUInt(q.filter { !$0.isWhitespace }) }
    private var ev: BigUInt? { BigUInt(e.filter { !$0.isWhitespace }) }
    private var primesOK: Bool {
        guard let a = pv, let b = qv, a > 1, b > 1 else { return false }
        return a != b && Primality.isProbablePrime(a) && Primality.isProbablePrime(b)
    }
    private var key: RSAKeyPair? {
        guard primesOK, let a = pv, let b = qv, let x = ev else { return nil }
        return try? RSAKeyPair(p: a, q: b, e: x)
    }

    var body: some View {
        let n = (pv ?? 0) * (qv ?? 0)
        let phi = primesOK ? (pv! - 1) * (qv! - 1) : BigUInt(0)
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose two prime numbers p and q. The number N = pq is the public RSA modulus and phi(N) = (p-1)(q-1) is the Euler phi function. Public key e is coprime to phi(N). The private key  d = e^(-1)  (mod phi(N))  is calculated from this.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            PKIGroup("Prime number entry") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text("Prime number p"); TextField("", text: $p).font(.system(.body, design: .monospaced))
                        Button("Generate prime numbers...") { generatePrimes() }
                    }
                    GridRow {
                        Text("Prime number q"); TextField("", text: $q).font(.system(.body, design: .monospaced))
                        Text(p.isEmpty && q.isEmpty ? "" : (primesOK ? "p and q are prime numbers." : "p or q is NOT a prime number !"))
                            .font(.caption).foregroundStyle(primesOK ? Color.secondary : Color.red)
                    }
                }
            }
            PKIGroup("RSA  parameter") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Length"); Text(primesOK ? "\(n.bitLength)" : "").textSelection(.enabled); Text("") }
                    GridRow { Text("RSA modulus N"); Text(verbatim: primesOK ? n.description : "").textSelection(.enabled).lineLimit(3); Text("(public)") }
                    GridRow { Text("phi(N) = (p-1)(q-1)"); Text(verbatim: primesOK ? phi.description : "").textSelection(.enabled).lineLimit(3); Text("(secret)") }
                    GridRow {
                        Text("Public key e"); TextField("", text: $e).font(.system(.body, design: .monospaced))
                        Text(primesOK && key == nil ? "e is not coprime to phi(N)" : "").font(.caption).foregroundStyle(.red)
                    }
                    GridRow { Text("Private key d"); Text(verbatim: key.map { $0.d.description } ?? "").textSelection(.enabled).lineLimit(3); Text("") }
                }
            }
            HStack {
                Button("Store key") { if let k = key { ok(k) } }.keyboardShortcut(.defaultAction).disabled(key == nil)
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 620)
        .onAppear {
            guard !started else { return }
            started = true
            if let k = initial { p = "\(k.p)"; q = "\(k.q)"; e = "\(k.e)" }
        }
    }

    private func generatePrimes() {
        let a = NSAlert()
        a.messageText = "Prime Number Generation"
        a.informativeText = "Bit length of the prime numbers p and q:"
        let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        f.stringValue = "512"
        a.accessoryView = f
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn, let bits = Int(f.stringValue), bits >= 8, bits <= 2048 else { return }
        let x = Primality.randomPrime(bits: bits)
        var y = Primality.randomPrime(bits: bits)
        while y == x { y = Primality.randomPrime(bits: bits) }
        p = "\(x)"; q = "\(y)"
    }
}

/// CT1 IDD_CERTIFICATE_GENERATION "Zertifikat und PSE erzeugen".
struct PKICertificateGenerationView: View {
    let key: RSAKeyPair
    let done: (StoredKey, RSAKeyPair, Bool) -> Void
    let cancel: () -> Void
    @CTState private var name = ""
    @CTState private var firstName = ""
    @CTState private var label = ""
    @CTState private var pin = ""
    @CTState private var pin2 = ""
    @CTState private var created = Date()

    private var preview: String {
        "[\(name)][\(firstName)][RSA-\(key.n.bitLength)][\(Int(created.timeIntervalSince1970))]" + (label.isEmpty ? "" : "[\(label)]")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PKIGroup("Public RSA parameter") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow { Text("Bit length:"); Text("\(key.n.bitLength)") }
                    GridRow { Text("RSA modulus N:"); Text(verbatim: key.n.description).lineLimit(2).textSelection(.enabled) }
                    GridRow { Text("Public key e:"); Text(verbatim: key.e.description) }
                }
            }
            PKIGroup("Personal data for the certificate") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Name:"); TextField("", text: $name) }
                    GridRow { Text("First name:"); TextField("", text: $firstName) }
                    GridRow { Text("Key identifier:\n(optional)"); TextField("", text: $label) }
                    GridRow { Text("PIN:"); SecureField("", text: $pin) }
                    GridRow { Text("PIN verification:"); SecureField("", text: $pin2) }
                }
            }
            PKIGroup("Generated names for PSE and certificate") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow { Text("User Key ID:"); Text(preview).textSelection(.enabled) }
                    GridRow { Text("Distinguished Name:"); Text("CN=\(firstName) \(name) [\(Int(created.timeIntervalSince1970))], DC=cryptool, DC=org").textSelection(.enabled) }
                }
            }
            HStack {
                Button("Create Certificate and PSE") { create() }.keyboardShortcut(.defaultAction)
                Button("Import certificate and key") { importKey() }
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 620)
    }

    private func create() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return PKIModal.warning("Please enter a last name.") }
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { return PKIModal.warning("Please enter a first name.") }
        if pin.isEmpty { return PKIModal.warning("Please enter a PIN code.") }
        if pin != pin2 { pin = ""; pin2 = ""; return PKIModal.warning("PIN and PIN confirmation do not agree.\\Please enter again.") }
        do {
            let k = try KeyStore.shared.add(lastName: name.trimmingCharacters(in: .whitespaces), firstName: firstName.trimmingCharacters(in: .whitespaces),
                                            label: label.trimmingCharacters(in: .whitespaces), material: .rsa(key), pin: pin, created: created)
            done(k, key, false)
        } catch { Alerts.error(error.localizedDescription) }
    }

    /// Uses an RSA key pair of the key store instead (its key replaces the demo key).
    private func importKey() {
        var chosen: (UUID, String)?
        PKIModal.run(title: "Import certificate and key") { close in
            PKIKeyChooser(headline: "Select your secret key from the PSE list.",
                          note: "Note: Only PSEs containing an RSA key are shown.",
                          filter: .rsaOnly, initial: nil, withPIN: true) { id, pin in chosen = (id, pin); close() } cancel: { close() }
        }
        guard let (id, pin) = chosen, let k = KeyStore.shared.key(id: id),
              case .rsa(let pair)? = PKIPinAccess.open(k, pin: pin) else { return }
        done(k, pair, true)
    }
}
