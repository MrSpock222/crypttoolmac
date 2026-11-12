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

    private let f1 = "\n\nMit F1 erhalten Sie Informationen darüber, in welcher Reihenfolge\nSie die Aktivitäten im Datenflussplan steuern können."

    var body: some View {
        VStack(spacing: 6) {
            Grid(horizontalSpacing: 14, verticalSpacing: 4) {
                GridRow {
                    PKIFlowButton(title: "Dokument öffnen", shape: .hexagon, state: docBytes.isEmpty ? .todo : .done, width: 150, action: openDocument)
                    PKIFlowButton(title: "Hashverfahren wählen", shape: .hexagon, state: hash == nil ? .todo : .done, width: 150, action: chooseHash)
                    PKIFlowButton(title: "Schlüssel generieren", shape: .hexagon, state: rsa == nil ? .todo : .done, width: 150, action: generateKey)
                    PKIFlowButton(title: "Zertifikat bereitstellen", shape: .hexagon,
                                  state: rsa == nil ? .inactive : (cert == nil ? .todo : .done), width: 150, action: provideCertificate)
                }
                GridRow { PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Dokument", shape: .diamond, state: docBytes.isEmpty ? .inactive : .info, width: 150, action: infoDocument)
                    PKIFlowButton(title: "Hashverfahren", shape: .diamond, state: hash == nil ? .inactive : .info, width: 150, action: infoHashAlg)
                    PKIFlowButton(title: "Schlüssel", shape: .diamond, state: rsa == nil ? .inactive : .info, width: 150, action: infoKey)
                    PKIFlowButton(title: "Zertifikat", shape: .diamond, state: cert == nil ? .inactive : .info, width: 150, action: infoCert)
                }
                GridRow { PKIFlowArrow(); Color.clear.frame(width: 1, height: 1); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Hashwert berechnen", shape: .rectangle,
                                  state: (docBytes.isEmpty || hash == nil) ? .inactive : (hashValue == nil ? .todo : .done), width: 150, action: computeHash)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Hashwert verschlüsseln", shape: .rectangle,
                                  state: (hashValue == nil || rsa == nil) ? .inactive : (encHash == nil ? .todo : .done), width: 150, action: encryptHash)
                    PKIFlowButton(title: "Signatur mit Zertifikat verknüpfen", shape: .rectangle,
                                  state: (encHash == nil || cert == nil) ? .inactive : (signed == nil ? .todo : .done), width: 150, action: combine)
                }
                GridRow { PKIFlowArrow(); Color.clear.frame(width: 1, height: 1); PKIFlowArrow(); PKIFlowArrow() }
                GridRow {
                    PKIFlowButton(title: "Hashwert", shape: .diamond, state: hashValue == nil ? .inactive : .info, width: 150, action: infoHash)
                    Color.clear.frame(width: 1, height: 1)
                    PKIFlowButton(title: "Verschlüsselter Hashwert", shape: .diamond, state: encHash == nil ? .inactive : .info, width: 150, action: infoEncHash)
                    PKIFlowButton(title: "Signatur", shape: .diamond, state: signed == nil ? .inactive : .info, width: 150, action: infoSign)
                }
                GridRow {
                    PKIFlowButton(title: "Abbrechen", shape: .oval, state: .done, width: 130, height: 38) { windowBox.window?.close() }
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
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Schrittweise Signaturerzeugung" })
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

    private func inactive(_ m: String = "") { PKIModal.warning("Dieser Button ist im Moment inaktiv!" + (m.isEmpty ? "" : "\n" + m) + f1) }

    // MARK: Actions

    private func openDocument() {
        let p = NSOpenPanel()
        p.title = "Dokument öffnen"
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let u = p.url else { return }
        let d = (try? Data(contentsOf: u)).map { [UInt8]($0) } ?? []
        guard !d.isEmpty else { return PKIModal.warning("Datei ist leer!\nBitte wählen Sie eine nicht leere Datei aus.") }
        docBytes = d
        docName = u.lastPathComponent
        hashValue = nil; encHash = nil; signed = nil
        infoDocument()
    }

    private func chooseHash() {
        var chosen = hash ?? .sha1
        var ok = false
        PKIModal.run(title: "Hashfunktion wählen") { close in
            PKIHashChooser(selection: chosen) { h in chosen = h; ok = true; close() } cancel: { close() }
        }
        guard ok else { return }
        if chosen != hash { hashValue = nil; encHash = nil; signed = nil }
        hash = chosen
        infoHashAlg()
    }

    private func generateKey() {
        var result: RSAKeyPair?
        PKIModal.run(title: "RSA-Schlüssel generieren") { close in
            PKIDemoRSAKeyView(initial: rsa) { k in result = k; close() } cancel: { close() }
        }
        guard let k = result else { return }
        if k != rsa { encHash = nil; signed = nil; cert = nil; certImported = false }
        rsa = k
        infoKey()
    }

    private func provideCertificate() {
        guard let k = rsa else { return inactive("Sie müssen vorher einen Schlüssel generieren.") }
        var result: (StoredKey, RSAKeyPair, Bool)?
        PKIModal.run(title: "Zertifikat und PSE erzeugen") { close in
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
        DocumentFactory.openResult(s, title: "RSA-Signatur mit \(h.rawValue) von <\(docName)>", parent: document, viewMode: .hex)
        var msg = "Herzlichen Glückwunsch!\n\nSie haben erfolgreich eine RSA-Signatur des Dokumentes <\(docName)> erzeugt.\n\n"
        msg += certImported
            ? "Den dazu verwendeten RSA-Schlüssel haben Sie aus der PSE-Datei <\(c.ct1Identifier).pse> zusammen mit einem Zertifikat importiert.\n\n"
            : "Den dazu von Ihnen erzeugten RSA-Schlüssel haben Sie in der PSE-Datei <\(c.ct1Identifier).pse> zusammen mit einem Zertifikat gespeichert.\n\n"
        msg += "Als Hashverfahren wählten Sie <\(h.rawValue)>."
        windowBox.window?.close()
        PKIModal.info(msg)
    }

    // MARK: Info symbols

    private func infoDocument() {
        guard !docBytes.isEmpty else { return inactive("Sie müssen vorher eine Datei auswählen.") }
        infoTitle = "Dokument: \(docName)"
        infoText = HexDump.format(Array(docBytes.prefix(64 * 1024)))
    }

    private func infoHashAlg() {
        guard let h = hash else { return inactive() }
        infoTitle = "Hashverfahren"
        infoText = "Name:                   \(h.rawValue) \nLänge in Bit:           \(h.bits)\nAlgorithmus-ID:         \(PKIText.hex(h.digestInfoPrefix))\n"
    }

    private func infoKey() {
        guard let k = rsa else { return inactive() }
        infoTitle = "RSA-Schlüssel des Signierers"
        infoText = "Modullänge in Bit:      \(k.n.bitLength)\nRSA-Modul N:            \(k.n)\nphi(N) = (p-1)(q-1):    \(k.phi)\nÖffentlicher Schlüssel: \(k.e)\nPrivater Schlüssel:     \(k.d)\n"
    }

    private func infoCert() {
        guard let c = cert else { return inactive() }
        infoTitle = "Zertifikat des Signierers (wird der Signatur zur Prüfung beigefügt)"
        infoText = PKICertificate.text(c)
    }

    private func infoHash() {
        guard let hv = hashValue, let h = hash else { return inactive("Sie müssen vorher die Datei mit dem symmetrischen Schlüssel verschlüsseln.") }
        infoTitle = "\(h.rawValue)-Hashwert von <\(docName)>"
        infoText = PKIText.hex(hv)
    }

    private func infoEncHash() {
        guard let e = encHash, let hv = hashValue, let h = hash, let k = rsa else { return inactive() }
        let kLen = (k.n.bitLength + 7) / 8
        let block = (try? PKIRSASignature.encode(hv, hash: h, k: kLen)) ?? []
        let padLen = max(0, kLen - h.digestInfoPrefix.count - hv.count)
        infoTitle = "Mit dem privaten Schlüssel des Signierers verschlüsselter Hashwert"
        var t = "Padding-String:         \(PKIText.hex(Array(block.prefix(padLen))))\n"
        t += "Algorithmus-ID:         \(PKIText.hex(h.digestInfoPrefix))\n"
        t += "Hashwert:               \(PKIText.hex(hv))\n"
        t += "ASN-1 Hashwert:         \(PKIText.hex(block))\n"
        t += "Länge in Bit:           \(block.count * 8)\n"
        t += "Verschl. Hashwert:      \(PKIText.hex(e))\n"
        t += "Länge in Bit:           \(e.count * 8)\n"
        infoText = t
    }

    private func infoSign() {
        guard let s = signed, let h = hash else { return inactive() }
        infoTitle = "RSA (\(h.shortName))-Signatur von <\(docName)>"
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
            PKIGroup("Hashfunktion") {
                Picker("", selection: $selection) {
                    ForEach(PKISignHash.demoCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.radioGroup).labelsHidden()
            }
            HStack {
                Button("OK") { ok(selection) }.keyboardShortcut(.defaultAction)
                Button("Abbrechen", action: cancel).keyboardShortcut(.cancelAction)
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
            Text("Wählen Sie zwei Primzahlen p und q. Die Zahl N=pq ist der öffentliche RSA-Modul, und phi(N)=(p-1)(q-1) ist die Eulersche Phi-Funktion. Der öffentliche Schlüssel e muss teilerfremd zu phi(N) sein; der geheime Schlüssel d wird daraus berechnet.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            PKIGroup("Primzahleneingabe") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text("Primzahl p"); TextField("", text: $p).font(.system(.body, design: .monospaced))
                        Button("Primzahlen generieren...") { generatePrimes() }
                    }
                    GridRow {
                        Text("Primzahl q"); TextField("", text: $q).font(.system(.body, design: .monospaced))
                        Text(p.isEmpty && q.isEmpty ? "" : (primesOK ? "p und q sind prim" : "p oder q ist keine Primzahl"))
                            .font(.caption).foregroundStyle(primesOK ? Color.secondary : Color.red)
                    }
                }
            }
            PKIGroup("RSA-Schlüssel-Parameter für Empfänger") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Bitlänge"); Text(primesOK ? "\(n.bitLength)" : "").textSelection(.enabled); Text("") }
                    GridRow { Text("RSA-Modul N"); Text(verbatim: primesOK ? n.description : "").textSelection(.enabled).lineLimit(3); Text("(öffentlich)") }
                    GridRow { Text("phi(N) = (p-1)(q-1)"); Text(verbatim: primesOK ? phi.description : "").textSelection(.enabled).lineLimit(3); Text("(geheim)") }
                    GridRow {
                        Text("Öffentlicher Schlüssel e"); TextField("", text: $e).font(.system(.body, design: .monospaced))
                        Text(primesOK && key == nil ? "e ist nicht teilerfremd zu phi(N)" : "").font(.caption).foregroundStyle(.red)
                    }
                    GridRow { Text("Geheimer Schlüssel d"); Text(verbatim: key.map { $0.d.description } ?? "").textSelection(.enabled).lineLimit(3); Text("") }
                }
            }
            HStack {
                Button("Schlüssel übernehmen") { if let k = key { ok(k) } }.keyboardShortcut(.defaultAction).disabled(key == nil)
                Spacer()
                Button("Abbrechen", action: cancel).keyboardShortcut(.cancelAction)
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
        a.messageText = "Primzahlen generieren"
        a.informativeText = "Bitlänge der Primzahlen p und q:"
        let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        f.stringValue = "512"
        a.accessoryView = f
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Abbrechen")
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
            PKIGroup("Öffentliche RSA-Parameter") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow { Text("Bitlänge:"); Text("\(key.n.bitLength)") }
                    GridRow { Text("RSA-Modul N:"); Text(verbatim: key.n.description).lineLimit(2).textSelection(.enabled) }
                    GridRow { Text("Öffentlicher Schlüssel e:"); Text(verbatim: key.e.description) }
                }
            }
            PKIGroup("Persönliche Daten für das Zertifikat") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Name:"); TextField("", text: $name) }
                    GridRow { Text("Vorname:"); TextField("", text: $firstName) }
                    GridRow { Text("Schlüsselbezeichner:\n(optional)"); TextField("", text: $label) }
                    GridRow { Text("PIN-Code:"); SecureField("", text: $pin) }
                    GridRow { Text("PIN-Verifikation:"); SecureField("", text: $pin2) }
                }
            }
            PKIGroup("Generierte Namen für PSE und Zertifikat") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow { Text("User Key ID:"); Text(preview).textSelection(.enabled) }
                    GridRow { Text("Distinguished Name:"); Text("CN=\(firstName) \(name) [\(Int(created.timeIntervalSince1970))], DC=cryptool, DC=org").textSelection(.enabled) }
                }
            }
            HStack {
                Button("Zertifkat und PSE erzeugen") { create() }.keyboardShortcut(.defaultAction)
                Button("Zertifikat / Schlüssel importieren") { importKey() }
                Spacer()
                Button("Abbrechen", action: cancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 620)
    }

    private func create() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return PKIModal.warning("Bitte geben Sie einen Nachnamen ein.") }
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { return PKIModal.warning("Bitte geben Sie einen Vornamen ein.") }
        if pin.isEmpty { return PKIModal.warning("Bitte geben Sie einen PIN-Code ein.") }
        if pin != pin2 { pin = ""; pin2 = ""; return PKIModal.warning("PIN und PIN-Verifikation stimmen nicht überein.\nBitte nochmal eingeben.") }
        do {
            let k = try KeyStore.shared.add(lastName: name.trimmingCharacters(in: .whitespaces), firstName: firstName.trimmingCharacters(in: .whitespaces),
                                            label: label.trimmingCharacters(in: .whitespaces), material: .rsa(key), pin: pin, created: created)
            done(k, key, false)
        } catch { Alerts.error(error.localizedDescription) }
    }

    /// Uses an RSA key pair of the key store instead (its key replaces the demo key).
    private func importKey() {
        var chosen: (UUID, String)?
        PKIModal.run(title: "Zertifikat / Schlüssel importieren") { close in
            PKIKeyChooser(headline: "Wählen Sie Ihren geheimen Schlüssel aus der Liste der PSEs aus:",
                          note: "Bemerkung: Es werden nur Namen mit einem RSA Schlüssel angezeigt.",
                          filter: .rsaOnly, initial: nil, withPIN: true) { id, pin in chosen = (id, pin); close() } cancel: { close() }
        }
        guard let (id, pin) = chosen, let k = KeyStore.shared.key(id: id),
              case .rsa(let pair)? = PKIPinAccess.open(k, pin: pin) else { return }
        done(k, pair, true)
    }
}
