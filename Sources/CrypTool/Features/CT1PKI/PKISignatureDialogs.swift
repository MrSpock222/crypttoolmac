import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

// MARK: - Step-by-step dialog (CT1 IDD_ECSIGNATRURE_STEPBYSTEP / IDD_VERIFY_ECSIGNATURE_STEPBYSTEP)

struct PKIStepDialog: View {
    let title: String
    let header: String
    let steps: [String]
    let finishTitle: String
    let finish: () -> Void
    let cancel: () -> Void
    @CTState private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3.weight(.semibold))
            ResultBox(text: header, minHeight: 110)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(steps.prefix(shown).joined()).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(height: 260)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                .onChange(of: shown) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            Text("Schritt \(shown) von maximal \(steps.count) Schritten.").bold()
            Divider()
            HStack {
                Button(finishTitle, action: finish)
                Spacer()
                Button("Abbrechen", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Weiter >") { shown += 1 }.keyboardShortcut(.defaultAction).disabled(shown >= steps.count)
            }
        }
        .padding(16)
        .frame(width: 680)
        .onAppear { shown = 1 }
    }
}

enum PKIECSteps {
    static func domainText(_ c: EllipticCurve) -> String {
        "  a  = \(c.a)\n  b  = \(c.b)\n  Gx = \(c.gx)\n  Gy = \(c.gy)\n  k  = \(c.h)\n  r  = \(c.n)\n\n"
    }

    /// Signature generation steps of CDlgECSignatureStepByStep (returns steps and (c, d)).
    static func sign(message: [UInt8], method: PKISignMethod, hash: PKISignHash, key: ECKeyPair, owner: StoredKey) -> ([String], BigUInt, BigUInt) {
        let c0 = key.curve, r = c0.n
        let digest = Hashing.hash(message, algorithm: hash.algorithm)
        var steps: [String] = []
        var s1 = "Signaturerzeuger:  \(owner.firstLast)\n\n"
        s1 += "Zu benutzende Domain-Parameter '\(c0.name)':\n\n" + domainText(c0)
        s1 += "Geheimer Schlüssel s des Signaturerzeugers:\n\n  s  = \(key.d)\n\n"
        s1 += "Gewähltes Signaturverfahren: \(method.rawValue) mit Hashfunktion \(hash.rawValue)\n\n"
        s1 += "Größe der zu signierenden Nachricht M: \(message.count) Byte\n\nweiter ...\n\n"
        steps.append(s1)
        while true {
            let u = BigUInt.random(below: r - 1) + 1
            let f = ECDSA.hashToInteger(digest, curve: c0) % r
            let V = c0.multiply(u, c0.generator)
            guard case let .affine(vx, vy) = V else { continue }
            var c = BigUInt(0), d = BigUInt(0)
            if method == .ecnr {
                guard let t = ECNR.trace(hash: digest, key: key, nonce: u) else { continue }
                c = t.c; d = t.d
            } else {
                guard let sd = ECDSA.sign(hash: digest, key: key, nonce: u) else { continue }
                c = sd.r; d = sd.s
            }
            steps.append("Berechne mit der gewählten Hashfunktion \(hash.rawValue) aus der Nachricht M einen 'Hashwert' f (message representative):\n\n  f  = \(f)\n\n")
            steps.append("Erzeuge ein zufälliges one-time Schlüsselpaar (geheimer Schlüssel, öffentlicher Schlüssel) = (u,V)\nmit den Domain-Parametern von '\(c0.name)' (V=(Vx,Vy) ist ein Punkt auf der Elliptischen Kurve):\n\n  u  = \(u)\n  Vx  = \(vx)\n  Vy  = \(vy)\n\n")
            steps.append("Konvertiere das Gruppenelement Vx (x Koordinate des Punktes V auf Elliptischer Kurve) in die Zahl i:\n\n  i  = \(vx)\n\n")
            if method == .ecnr {
                steps.append("Berechne die Zahl c = i + f (mod r) (c ungleich 0):\n\n  c  = \(c)\n\n")
                steps.append("Berechne die Zahl d = u - s*c (mod r) (d ungleich 0):\n\n  d  = \(d)\n\n")
            } else {
                steps.append("Berechne die Zahl c = i mod r (c ungleich 0):\n\n  c  = \(c)\n\n")
                steps.append("Berechne die Zahl d = u^(-1)*(f + s*c) mod r (d ungleich 0):\n\n  d  = \(d)\n\n")
            }
            steps.append("Signaturerzeugung beendet.\nDie Signatur besteht aus den beiden Zahlen c und d.\n\n")
            return (steps, c, d)
        }
    }

    /// Verification steps (CDlgVerifyECSignatureStepByStep).
    static func verify(message: [UInt8], method: PKISignMethod, hash: PKISignHash, c: BigUInt, d: BigUInt,
                       curve c0: EllipticCurve, W: ECPoint, owner: StoredKey) -> (header: String, steps: [String], ok: Bool) {
        let r = c0.n
        let digest = Hashing.hash(message, algorithm: hash.algorithm)
        var header = "Schrittweise Signatur-Verifikation:\n\nSignaturerzeuger:  \(owner.firstLast)\n"
        header += "Gewähltes Signaturverfahren: \(method.rawValue) mit Hashfunktion \(hash.rawValue)\n"
        header += "Größe der signierten Nachricht M: \(message.count) Byte\n"
        header += "Bitlänge von c + Bitlänge von d = \(c.bitLength + d.bitLength) Bit\n  c = \(c)\n  d = \(d)\n"
        var steps: [String] = []
        var s1 = "Zu benutzende Domain-Parameter '\(c0.name)':\n\n" + domainText(c0)
        if case let .affine(wx, wy) = W {
            s1 += "Öffentlicher Schlüssel W=(Wx,Wy) (W ist ein Punkt auf der Elliptischen Kurve) des Signaturerzeugers:\n\n  Wx = \(wx)\n  Wy = \(wy)\n\n"
        }
        steps.append(s1)
        let inRange = c >= 1 && c < r && d >= 1 && d < r
        steps.append("Falls c oder d nicht im Intervall [1, r-1] ist die Signatur ungültig:\n\n  " +
                     (inRange ? "c und d liegen im geforderten Intervall [1, r-1]" : "c oder d liegt NICHT im geforderten Intervall [1, r-1]") + "\n\n")
        guard inRange else { return (header, steps, false) }
        let g = ECDSA.hashToInteger(digest, curve: c0) % r
        if method == .ecnr {
            let P = c0.multiplyAdd(d, c0.generator, c, W)
            guard case let .affine(px, py) = P else {
                steps.append("Der Punkt P = (inf,inf) zeigt an, dass die Signatur fehlerhaft ist\n\n")
                return (header, steps, false)
            }
            steps.append("Berechne den Elliptischen Kurven Punkt P = d G + c W\n(falls P = (Px, Py) = (inf, inf) ist die Signatur ungültig):\n\n  Px = \(px)\n  Py = \(py)\n\n")
            steps.append("Konvertiere das Gruppenelement Px (x Koordinate des Punktes P auf Elliptischer Kurve) in die Zahl i:\n\n  i  = \(px)\n\n")
            let f = (c % r + r - px % r) % r
            steps.append("Berechne die Zahl f = c - i (mod r) (f ist ein 'message-representative'):\n\n  f  = \(f)\n\n")
            steps.append("Berechne mit der gewählten Hashfunktion \(hash.rawValue) aus der Nachricht M einen 'Hashwert' g (message representative):\n\n  g  = \(g)\n\n")
            let ok = f == g
            steps.append("Falls f = g ist die Signatur korrekt; sonst ist Signatur fehlerhaft:\n\n  " + (ok ? "Signatur korrekt !" : "Signatur fehlerhaft !") + "\n")
            return (header, steps, ok)
        }
        steps.append("Berechne mit der gewählten Hashfunktion \(hash.rawValue) aus der Nachricht M einen 'Hashwert' f (message representative):\n\n  f  = \(g)\n\n")
        let h = d.inverse(modulo: r) ?? 0
        steps.append("Berechne die Zahl h = d^(-1) mod r:\n\n  h  = \(h)\n\n")
        let h1 = (g * h) % r, h2 = (c * h) % r
        steps.append("Berechne die Zahl h1 = f*h mod r:\n\n  h1 = \(h1)\n\n")
        steps.append("Berechne die Zahl h2 = c*h mod r:\n\n  h2 = \(h2)\n\n")
        guard case let .affine(px, py) = c0.multiplyAdd(h1, c0.generator, h2, W) else {
            steps.append("Der Punkt P = (inf,inf) zeigt an, dass die Signatur fehlerhaft ist\n\n")
            return (header, steps, false)
        }
        steps.append("Berechne den Elliptischen Kurven Punkt P = h1 G + h2 W \n(falls P = (Px, Py) = (inf, inf) ist die Signatur ungültig):\n\n  Px = \(px)\n  Py = \(py)\n\n")
        steps.append("Konvertiere das Gruppenelement Px (x Koordinate des Punktes P auf Elliptischer Kurve) in die Zahl i:\n\n  i  = \(px)\n\n")
        let c1 = px % r
        steps.append("Berechne die Zahl c' = i mod r:\n\n  c' = \(c1)\n\n")
        let ok = c1 == c
        steps.append("Falls c' = c ist die Signatur korrekt; sonst ist Signatur fehlerhaft:\n\n  " + (ok ? "Signatur korrekt !" : "Signatur fehlerhaft !") + "\n")
        return (header, steps, ok)
    }
}

// MARK: - Sign (CT1 IDD_SIGNATURE "Signatur eines Dokuments erstellen")

struct PKISignDialog: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var keyID: UUID?
    @CTState private var hash: PKISignHash = .sha1
    @CTState private var method: PKISignMethod = .rsa
    @CTState private var affine = false
    @CTState private var filter = PKIKeyFilter()
    @CTState private var pin = ""
    @CTState private var showTime = false
    @CTState private var showSteps = false

    private var key: StoredKey? { keyID.flatMap { KeyStore.shared.key(id: $0) } }
    private var keyKind: PKIKeyKind? { key?.type.kind }

    private func methodEnabled(_ m: PKISignMethod) -> Bool {
        switch keyKind {
        case nil: return true
        case .rsa?: return m == .rsa
        case .dsa?: return m == .dsa
        case .ec?: return m.isEC
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signatur eines Dokuments erstellen").font(.title3.weight(.semibold))
            HStack(alignment: .top, spacing: 12) {
                PKIGroup("Hashfunktion wählen:") {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
                        GridRow { Text("Verfahren:").foregroundStyle(.secondary); Text("Ausgabenlänge:").foregroundStyle(.secondary) }
                        ForEach(PKISignHash.signDialogCases) { h in
                            GridRow {
                                radio(h.rawValue, selected: hash == h, enabled: method.allowedHashes.contains(h)) { hash = h }
                                Text("\(h.bits) Bit")
                            }
                        }
                    }
                }
                .frame(width: 230)
                PKIGroup("Signaturverfahren wählen:") {
                    Text("Problemklasse \"Faktorisieren\":")
                    radio("RSA", selected: method == .rsa, enabled: methodEnabled(.rsa)) { setMethod(.rsa) }.padding(.leading, 16)
                    Text("Problemklasse \"Diskreter Logarithmus\":")
                    radio("DSA", selected: method == .dsa, enabled: methodEnabled(.dsa)) { setMethod(.dsa) }.padding(.leading, 16)
                    Text("Problemklasse \"Elliptische Kurven Diskreter Logarithmus\":")
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            radio("ECSP-DSA", selected: method == .ecdsa, enabled: methodEnabled(.ecdsa)) { setMethod(.ecdsa) }
                            radio("ECSP-NR", selected: method == .ecnr, enabled: methodEnabled(.ecnr)) { setMethod(.ecnr) }
                        }.padding(.leading, 16)
                        Spacer()
                        PKIGroup("Punkt-Repräsentation") {
                            radio("Affine Koordinaten", selected: affine, enabled: method.isEC) { affine = true }
                            radio("Projektive Koordinaten", selected: !affine, enabled: method.isEC) { affine = false }
                        }.fixedSize()
                    }
                }
            }
            Text("Wählen Sie zum Signieren Ihren privaten Schlüssel:")
            PKIKeyTable(selection: $keyID, filter: filter, minHeight: 150)
            HStack(alignment: .top, spacing: 12) {
                PKIKeyFilterBox(filter: $filter, hyphen: false)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PIN-Code für den Zugriff auf die gewählte PSE:")
                        SecureField("", text: $pin).frame(width: 120)
                    }
                    Toggle("Zum Signieren benötigte Zeit anzeigen", isOn: $showTime)
                    Toggle("Zwischenschritte anzeigen", isOn: $showSteps).disabled(!method.isEC)
                }
            }
            Divider()
            HStack {
                Button("Signieren") { sign() }.keyboardShortcut(.defaultAction)
                Spacer()
                PKIHelpButton(action: .signDocument)
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 720)
        .onChange(of: keyID) { _, _ in adaptToKey() }
    }

    private func radio(_ title: String, selected: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected && enabled ? Color.accentColor : .secondary)
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func setMethod(_ m: PKISignMethod) {
        method = m
        if !m.allowedHashes.contains(hash) { hash = .sha1 }
        if !m.isEC { showSteps = false }
    }

    /// CT1 OnClickList: the selected key determines the method (EC: ECSP-DSA default) and hash.
    private func adaptToKey() {
        guard let kind = keyKind else { return }
        switch kind {
        case .rsa: setMethod(.rsa)
        case .dsa: setMethod(.dsa)
        case .ec: if !method.isEC { setMethod(.ecdsa) } else { setMethod(method) }
        }
    }

    private func sign() {
        guard let k = key else {
            PKIModal.info("Bitte wählen Sie eine PSE.")
            return
        }
        guard let material = PKIPinAccess.open(k, pin: pin) else { pin = ""; return }
        let message = document.bytes
        let start = Date()
        var duration: TimeInterval = 0
        var doc = PKISignedDocument(method: method.rawValue, hash: hash.rawValue, keyID: k.ct1Identifier,
                                    signature: [], c: nil, d: nil, bitLength: 0, message: message)
        do {
            switch material {
            case .rsa(let pair):
                let sig = try PKIRSASignature.sign(Hashing.hash(message, algorithm: hash.algorithm), hash: hash, key: pair)
                duration = Date().timeIntervalSince(start)
                doc.signature = sig; doc.bitLength = sig.count * 8
            case .dsa(let pair):
                let (r, s) = DSA.sign(hash: Hashing.hash(message, algorithm: hash.algorithm), key: pair)
                duration = Date().timeIntervalSince(start)
                doc.signature = DSA.derEncode(r: r, s: s); doc.bitLength = doc.signature.count * 8
            case .ecc(let pair):
                var c = BigUInt(0), d = BigUInt(0)
                if showSteps {
                    let (steps, sc, sd) = PKIECSteps.sign(message: message, method: method, hash: hash, key: pair, owner: k)
                    var accepted = false
                    let header = "Zu signierende Nachricht M:\n\n" + String(PKIText.string(Array(message.prefix(2000))))
                    PKIModal.run(title: "Signaturerzeugung - Schritt für Schritt") { done in
                        PKIStepDialog(title: "Schrittweise Signatur-Erzeugung:", header: header, steps: steps,
                                      finishTitle: "Signaturdaten ausgeben", finish: { accepted = true; done() }, cancel: done)
                    }
                    duration = Date().timeIntervalSince(start)
                    guard accepted else { return }
                    c = sc; d = sd
                } else {
                    let digest = Hashing.hash(message, algorithm: hash.algorithm)
                    if method == .ecnr { (c, d) = ECNR.sign(hash: digest, key: pair) } else { (c, d) = ECDSA.sign(hash: digest, key: pair) }
                    duration = Date().timeIntervalSince(start)
                }
                doc.c = c; doc.d = d; doc.bitLength = c.bitLength + d.bitLength
            }
            DocumentFactory.openResult(doc.serialize(), title: "\(method.titleName(hash))-Signatur von <\(document.shortName)>",
                                       parent: document, viewMode: .hex)
            close()
            if showTime { PKIModal.info("Zum Erzeugen der Signatur benötigte Zeit: \(PKIText.seconds(duration)) Sekunden.") }
        } catch { Alerts.error(error.localizedDescription) }
    }
}

// MARK: - Verify (CT1 IDD_VERIFY_SIGNATURE "Verifizieren einer Signatur")

struct PKIVerifyDialog: View {
    let document: CTDocument
    let signed: PKISignedDocument
    let close: () -> Void
    @CTState private var keyID: UUID?
    @CTState private var filter = PKIKeyFilter()
    @CTState private var ecMethod: PKISignMethod = .ecdsa
    @CTState private var ecHash: PKISignHash = .sha1
    @CTState private var affine = false
    @CTState private var showTime = true
    @CTState private var showSteps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verifizieren einer Signatur").font(.title3.weight(.semibold))
            Text("Wählen Sie aus der folgenden Liste den Signaturersteller:")
            PKIKeyTable(selection: $keyID, filter: filter, minHeight: 180)
            PKIGroup("Angegebene Daten") {
                HStack {
                    Text("Signatur-Verfahren:"); Text(signed.method.isEmpty ? "unbekannt !" : signed.method).bold()
                    Spacer()
                    Text("Hashfunktion:"); Text(signed.hash.isEmpty ? "unbekannt !" : signed.hash).bold()
                    Spacer()
                }
            }
            HStack(alignment: .top, spacing: 12) {
                PKIKeyFilterBox(filter: $filter)
                VStack(alignment: .leading, spacing: 6) {
                    PKIGroup("Verifikation mit Verfahren:") {
                        Picker("", selection: $ecMethod) { Text("ECSP-DSA").tag(PKISignMethod.ecdsa); Text("ECSP-NR").tag(PKISignMethod.ecnr) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                    PKIGroup("Verifikation mit Hashfunktion:") {
                        Picker("", selection: $ecHash) { Text("SHA-1").tag(PKISignHash.sha1); Text("RIPEMD-160").tag(PKISignHash.ripemd160) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                    PKIGroup("Repräsentation der EC-Punkte in:") {
                        Picker("", selection: $affine) { Text("Affine Koord.").tag(true); Text("Projektive Koord.").tag(false) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                }
                .disabled(!isEC)
                VStack(alignment: .trailing, spacing: 8) {
                    Button("Suche Schlüssel") { search(verbose: true) }
                    Spacer()
                }
            }
            Toggle("Zum Verifizieren benötigte Zeit anzeigen", isOn: $showTime)
            Toggle("Zwischenschritte anzeigen", isOn: $showSteps)
            Divider()
            HStack {
                Button("Signatur verifizieren") { verify() }.keyboardShortcut(.defaultAction)
                Spacer()
                PKIHelpButton(action: .verifySignature)
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 700)
        .onAppear {
            if let m = PKISignMethod(rawValue: signed.method), m.isEC { ecMethod = m }
            if let h = PKISignHash.named(signed.hash), h == .ripemd160 { ecHash = .ripemd160 }
            search(verbose: false)
        }
    }

    private var isEC: Bool { signed.c != nil }

    private func search(verbose: Bool) {
        if let k = KeyStore.shared.key(ct1Identifier: signed.keyID) {
            if !filter.accepts(k) { filter = PKIKeyFilter() }
            keyID = k.id
        } else if verbose {
            PKIModal.warning("Es gibt keinen Schlüsselbezeichner der dem angeforderten Format\n'\(signed.keyID)'\nentspricht !")
        }
    }

    private func verify() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id) else {
            PKIModal.warning("Eingabe unvollständig\n\nBitte wählen Sie den Signaturersteller.")
            return
        }
        guard let hash = PKISignHash.named((isEC && !signed.legacy) ? ecHash.rawValue : signed.hash) else {
            PKIModal.warning("Eingabe unvollständig\n\nUnbekannte Hashfunktion: \(signed.hash)")
            return
        }
        let start = Date()
        let digest = Hashing.hash(signed.message, algorithm: hash.algorithm)
        var ok = false
        if let c = signed.c, let d = signed.d {
            guard let curve = k.curve, let W = k.ecPublic else { return finish(false, Date().timeIntervalSince(start)) }
            if showSteps {
                let v = PKIECSteps.verify(message: signed.message, method: ecMethod, hash: hash, c: c, d: d, curve: curve, W: W, owner: k)
                PKIModal.run(title: "Signaturverifikation - Schritt für Schritt") { done in
                    PKIStepDialog(title: "Schrittweise Signatur-Verifikation:", header: v.header, steps: v.steps,
                                  finishTitle: "Dialog beenden", finish: done, cancel: done)
                }
                ok = v.ok
            } else if ecMethod == .ecnr {
                ok = ECNR.verify(hash: digest, c: c, d: d, curve: curve, publicKey: W)
            } else {
                ok = ECDSA.verify(hash: digest, r: c, s: d, curve: curve, publicKey: W)
            }
        } else if let pub = k.rsaPublic, signed.method == "RSA" {
            ok = signed.legacy
                ? PKCS1.verify(signature: signed.signature, hash: digest, algorithm: DigestAlgorithmID(rawValue: hash.algorithm.rawValue) ?? .sha1, key: pub)
                : PKIRSASignature.verify(signed.signature, digest: digest, hash: hash, key: pub)
            if showSteps { showRSASteps(pub, hash: hash, digest: digest, ok: ok) }
        } else if let dp = k.dsaParameters, let y = k.dsaPublic, signed.method == "DSA", let (r, s) = DSA.derDecode(signed.signature) {
            ok = DSA.verify(hash: digest, r: r, s: s, parameters: dp, publicKey: y)
        }
        finish(ok, Date().timeIntervalSince(start))
    }

    private func showRSASteps(_ pub: RSAPublicKey, hash: PKISignHash, digest: [UInt8], ok: Bool) {
        let s = BigUInt(bigEndianBytes: signed.signature)
        let v = pub.verifyRaw(s % pub.n)
        let k = (pub.n.bitLength + 7) / 8
        var t = "Signatur s:\n\(s)\n\nÖffentlicher Schlüssel des Signaturerstellers:\nN = \(pub.n)\ne = \(pub.e)\n\n"
        t += "s^e mod N (hexadezimal):\n\(PKIText.hex(v.bigEndianBytes(length: k)))\n\n"
        t += "\(hash.rawValue)-Hashwert der Nachricht:\n\(PKIText.hex(digest))\n\n"
        t += "Erwartet (PKCS #1: 00 01 FF … FF 00 ‖ DigestInfo ‖ Hashwert):\n"
        t += ((try? PKIRSASignature.encode(digest, hash: hash, k: k)).map(PKIText.hex) ?? "–") + "\n\n"
        t += ok ? "Signatur korrekt !" : "Signatur fehlerhaft !"
        PKIModal.run(title: "Signaturverifikation - Schritt für Schritt") { done in
            PKIStepDialog(title: "Schrittweise Signatur-Verifikation:", header: "RSA-Signatur mit \(hash.rawValue)", steps: [t],
                          finishTitle: "Dialog beenden", finish: done, cancel: done)
        }
    }

    private func finish(_ ok: Bool, _ t: TimeInterval) {
        close()
        if showTime {
            let time = "Zum Verifizieren der Signatur benötigte Zeit: \(PKIText.seconds(t)) Sekunden."
            ok ? PKIModal.info("Signatur korrekt!\n" + time) : PKIModal.warning("Signatur fehlerhaft!\n" + time)
        } else {
            ok ? PKIModal.info("Signatur korrekt !") : PKIModal.warning("Signatur fehlerhaft !")
        }
    }
}

// MARK: - Extract (CT1 IDD_EXTRACT_SIGNATURE "Extrahierte Signatur")

struct PKIExtractDialog: View {
    let document: CTDocument
    let signed: PKISignedDocument
    let close: () -> Void
    @CTState private var mode = 3   // 0 Oktal, 1 Dezimal, 2 Hexadezimal, 3 Hex-Dump

    private var key: StoredKey? { KeyStore.shared.key(ct1Identifier: signed.keyID) }

    private var signatureText: String {
        if let c = signed.c, let d = signed.d {
            switch mode {
            case 0: return "c = \(c.toString(radix: 8))\nd = \(d.toString(radix: 8))"
            case 2: return "c = \(c.toString(radix: 16))\nd = \(d.toString(radix: 16))"
            case 3: return "c = \(PKIText.hex(c.bigEndianBytes))\nd = \(PKIText.hex(d.bigEndianBytes))"
            default: return "c = \(c)\nd = \(d)"
            }
        }
        let v = BigUInt(bigEndianBytes: signed.signature)
        switch mode {
        case 0: return v.toString(radix: 8)
        case 1: return v.toString(radix: 10)
        case 2: return v.toString(radix: 16)
        default: return HexDump.format(signed.signature)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extrahierte Signatur").font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Signaturerzeuger:"); Text(key?.firstLast ?? "Unbekannt - übermittelter Schlüsselbezeichner existiert nicht").textSelection(.enabled) }
                GridRow {
                    Text("Benutzter Schlüssel:")
                    Text(key.map { "\($0.type.displayName)\($0.label.isEmpty ? "" : " (\($0.label))"); erzeugt am \($0.createdString)" } ?? signed.keyID)
                        .textSelection(.enabled)
                }
                GridRow { Text("Signaturverfahren:"); Text("\(signed.method) mit Hashfunktion \(signed.hash)") }
            }
            Text("Signatur:")
            ResultBox(text: signatureText, minHeight: 120)
            Text("Länge der Signatur: \(signed.bitLength) Bit.").font(.callout)
            PKIGroup("Optionen der Darstellung der Signatur:") {
                HStack {
                    Text("Zahlendarstellung:")
                    Picker("", selection: $mode) {
                        Text("Oktal").tag(0); Text("Dezimal").tag(1); Text("Hexadezimal").tag(2); Text("Hex-Dump (hexadezimal und Ascii):").tag(3)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
            }
            Text("Signierte Nachricht:")
            ResultBox(text: PKIText.string(Array(signed.message.prefix(100_000))), minHeight: 120)
            Text("Länge der Nachricht: \(signed.message.count) Byte.").font(.callout)
            Divider()
            HStack {
                Button("Verifizieren") {
                    close()
                    DispatchQueue.main.async { SignatureOps.verify(document) }
                }
                Spacer()
                PKIHelpButton(action: .extractSignature)
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 680)
    }
}
