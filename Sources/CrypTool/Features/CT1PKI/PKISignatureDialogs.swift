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
            Text("Step \(shown) out of a maximum of \(steps.count) steps.").bold()
            Divider()
            HStack {
                Button(finishTitle, action: finish)
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue >") { shown += 1 }.keyboardShortcut(.defaultAction).disabled(shown >= steps.count)
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
        var s1 = "Signature originator:  \(owner.firstLast)\n\n"
        s1 += "Domain parameters to be used '\(c0.name)':\n\n" + domainText(c0)
        s1 += "Secret key s of the signature originator:\n\n  s  = \(key.d)\n\n"
        s1 += "Chosen signature algorithm: \(method.rawValue) with hash function \(hash.rawValue)\n\n"
        s1 += "Size of message M to be signed: \(message.count) bytes\n\nContinue ...\n\n"
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
            steps.append("Calculate a 'hash value' f (message representative) from message M, using the chosen hash function \(hash.rawValue).\n\n  f  = \(f)\n\n")
            steps.append("Create a random one-time key pair (secret key, public key) = (u,V)\nwith the domain parameters of '\(c0.name)' (V=(Vx,Vy) is a point on the elliptic curve):\n\n  u  = \(u)\n  Vx  = \(vx)\n  Vy  = \(vy)\n\n")
            steps.append("Convert the group element Vx (x co-ordinates of point V on elliptic curve) to the number i:\n\n  i  = \(vx)\n\n")
            if method == .ecnr {
                steps.append("Calculate the number c = i + f (mod r) (c not equal to 0):\n\n  c  = \(c)\n\n")
                steps.append("Calculate the number d = u - s*c (mod r) (d not equal to 0):\n\n  d  = \(d)\n\n")
            } else {
                steps.append("Calculate the number c = i mod r (c not equal to 0):\n\n  c  = \(c)\n\n")
                steps.append("Calculate the number d = u^(-1)*(f + s*c) mod r (d not equal to 0):\n\n  d  = \(d)\n\n")
            }
            steps.append("Signature generation finished.\nThe signature consists of the two numbers c and d.\n\n")
            return (steps, c, d)
        }
    }

    /// Verification steps (CDlgVerifyECSignatureStepByStep).
    static func verify(message: [UInt8], method: PKISignMethod, hash: PKISignHash, c: BigUInt, d: BigUInt,
                       curve c0: EllipticCurve, W: ECPoint, owner: StoredKey) -> (header: String, steps: [String], ok: Bool) {
        let r = c0.n
        let digest = Hashing.hash(message, algorithm: hash.algorithm)
        var header = "Step-by-step signature verification:\n\nSignature originator:  \(owner.firstLast)\n"
        header += "Chosen signature algorithm: \(method.rawValue) with hash function \(hash.rawValue)\n"
        header += "Size of message M to be signed: \(message.count) bytes\n"
        header += "Bit length of c + bit length of d = \(c.bitLength + d.bitLength) bits\n  c = \(c)\n  d = \(d)\n"
        var steps: [String] = []
        var s1 = "Domain parameters to be used '\(c0.name)':\n\n" + domainText(c0)
        if case let .affine(wx, wy) = W {
            s1 += "Public key W=(Wx,Wy) (W is a point on the elliptic curve) of the signature originator:\n\n  Wx = \(wx)\n  Wy = \(wy)\n\n"
        }
        steps.append(s1)
        let inRange = c >= 1 && c < r && d >= 1 && d < r
        steps.append("If c or d does not fall within the interval [1, r-1] then the signature is invalid:\n\n  " +
                     (inRange ? "c and d fall within the required interval [1, r-1]." : "Either c or d does NOT fall within the required interval [1, r-1].") + "\n\n")
        guard inRange else { return (header, steps, false) }
        let g = ECDSA.hashToInteger(digest, curve: c0) % r
        if method == .ecnr {
            let P = c0.multiplyAdd(d, c0.generator, c, W)
            guard case let .affine(px, py) = P else {
                steps.append("Point P = (inf,inf) shows that the signature is invalid.\n\n")
                return (header, steps, false)
            }
            steps.append("Calculate the elliptic curve point P = d G + c W\n(If P = (Px, Py) = (inf, inf) then the signature is invalid):\n\n  Px = \(px)\n  Py = \(py)\n\n")
            steps.append("Convert the group element Px (x co-ordinates of point P on elliptic curve) to the number i:\n\n  i  = \(px)\n\n")
            let f = (c % r + r - px % r) % r
            steps.append("Calculate the number f = c - i (mod r) (f is a 'message representative'):\n\n  f  = \(f)\n\n")
            steps.append("Calculate a hash value g (message representative) from message M, using the chosen hash function \(hash.rawValue).\n\n  g  = \(g)\n\n")
            let ok = f == g
            steps.append("If f = g, then the signature is correct; otherwise the signature is invalid:\n\n  " + (ok ? "Correct signature!" : "Signature is not correct!") + "\n")
            return (header, steps, ok)
        }
        steps.append("Calculate a 'hash value' f (message representative) from message M, using the chosen hash function \(hash.rawValue).\n\n  f  = \(g)\n\n")
        let h = d.inverse(modulo: r) ?? 0
        steps.append("Calculate the number h = d^(-1) mod r:\n\n  h  = \(h)\n\n")
        let h1 = (g * h) % r, h2 = (c * h) % r
        steps.append("Calculate the number h1 = f*h mod r:\n\n  h1 = \(h1)\n\n")
        steps.append("Calculate the number h2 = c*h mod r:\n\n  h2 = \(h2)\n\n")
        guard case let .affine(px, py) = c0.multiplyAdd(h1, c0.generator, h2, W) else {
            steps.append("Point P = (inf,inf) shows that the signature is invalid.\n\n")
            return (header, steps, false)
        }
        steps.append("Calculate the elliptic curve point P = h1 G + h2 W \n(If P = (Px, Py) = (inf, inf) then the signature is invalid):\n\n  Px = \(px)\n  Py = \(py)\n\n")
        steps.append("Convert the group element Px (x co-ordinates of point P on elliptic curve) to the number i:\n\n  i  = \(px)\n\n")
        let c1 = px % r
        steps.append("Calculate the number c' = i mod r:\n\n  c' = \(c1)\n\n")
        let ok = c1 == c
        steps.append("If c' = c then the signature is correct; otherwise the signature is invalid:\n\n  " + (ok ? "Correct signature!" : "Signature is not correct!") + "\n")
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
            Text("Sign a Document").font(.title3.weight(.semibold))
            HStack(alignment: .top, spacing: 12) {
                PKIGroup("Choose hash function") {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
                        GridRow { Text("Algorithm:").foregroundStyle(.secondary); Text("Output length").foregroundStyle(.secondary) }
                        ForEach(PKISignHash.signDialogCases) { h in
                            GridRow {
                                radio(h.rawValue, selected: hash == h, enabled: method.allowedHashes.contains(h)) { hash = h }
                                Text("\(h.bits) bits")
                            }
                        }
                    }
                }
                .frame(width: 230)
                PKIGroup("Choose signature algorithm") {
                    Text("Factorization based algorithms")
                    radio("RSA", selected: method == .rsa, enabled: methodEnabled(.rsa)) { setMethod(.rsa) }.padding(.leading, 16)
                    Text("Discrete logarithm based algorithms")
                    radio("DSA", selected: method == .dsa, enabled: methodEnabled(.dsa)) { setMethod(.dsa) }.padding(.leading, 16)
                    Text("Elliptic curve based algorithms")
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            radio("ECSP-DSA", selected: method == .ecdsa, enabled: methodEnabled(.ecdsa)) { setMethod(.ecdsa) }
                            radio("ECSP-NR", selected: method == .ecnr, enabled: methodEnabled(.ecnr)) { setMethod(.ecnr) }
                        }.padding(.leading, 16)
                        Spacer()
                        PKIGroup("Presentation format") {
                            radio("Affine coordinates", selected: affine, enabled: method.isEC) { affine = true }
                            radio("Projective coordinates", selected: !affine, enabled: method.isEC) { affine = false }
                        }.fixedSize()
                    }
                }
            }
            Text("Choose a key/PSE to be used when signing")
            PKIKeyTable(selection: $keyID, filter: filter, minHeight: 150)
            HStack(alignment: .top, spacing: 12) {
                PKIKeyFilterBox(filter: $filter, hyphen: false)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PIN code for chosen PSE:")
                        SecureField("", text: $pin).frame(width: 120)
                    }
                    Toggle("Display signature time", isOn: $showTime)
                    Toggle("Display intermediate results", isOn: $showSteps).disabled(!method.isEC)
                }
            }
            Divider()
            HStack {
                Button("Sign") { sign() }.keyboardShortcut(.defaultAction)
                Spacer()
                PKIHelpButton(action: .signDocument)
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
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
            PKIModal.info("Please select a PSE.")
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
                    let header = "Message M to be signed:\n\n" + String(PKIText.string(Array(message.prefix(2000))))
                    PKIModal.run(title: "Signature Generation - Step By Step") { done in
                        PKIStepDialog(title: "Step-by-step signature generation:", header: header, steps: steps,
                                      finishTitle: "Output signature data", finish: { accepted = true; done() }, cancel: done)
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
            DocumentFactory.openResult(doc.serialize(), title: "\(method.titleName(hash)) signature of <\(document.shortName)>",
                                       parent: document, viewMode: .hex)
            close()
            if showTime { PKIModal.info("Signature generation time: \(PKIText.seconds(duration)) seconds.") }
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
            Text("Signature Verification").font(.title3.weight(.semibold))
            Text("Choose the signature originator from the following list:")
            PKIKeyTable(selection: $keyID, filter: filter, minHeight: 180)
            PKIGroup("Specified data") {
                HStack {
                    Text("Signature algorithm"); Text(signed.method.isEmpty ? "Unknown !" : signed.method).bold()
                    Spacer()
                    Text("Hash function:"); Text(signed.hash.isEmpty ? "Unknown !" : signed.hash).bold()
                    Spacer()
                }
            }
            HStack(alignment: .top, spacing: 12) {
                PKIKeyFilterBox(filter: $filter)
                VStack(alignment: .leading, spacing: 6) {
                    PKIGroup("Verification algorithm:") {
                        Picker("", selection: $ecMethod) { Text("ECSP-DSA").tag(PKISignMethod.ecdsa); Text("ECSP-NR").tag(PKISignMethod.ecnr) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                    PKIGroup("Verification hash function:") {
                        Picker("", selection: $ecHash) { Text("SHA-1").tag(PKISignHash.sha1); Text("RIPEMD-160").tag(PKISignHash.ripemd160) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                    PKIGroup("Presentation format:") {
                        Picker("", selection: $affine) { Text("Affine coord.").tag(true); Text("Projective coord.").tag(false) }
                            .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    }
                }
                .disabled(!isEC)
                VStack(alignment: .trailing, spacing: 8) {
                    Button("Look up key") { search(verbose: true) }
                    Spacer()
                }
            }
            Toggle("Display verification time", isOn: $showTime)
            Toggle("Display intermediate results", isOn: $showSteps)
            Divider()
            HStack {
                Button("Verify signature") { verify() }.keyboardShortcut(.defaultAction)
                Spacer()
                PKIHelpButton(action: .verifySignature)
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
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
            PKIModal.warning("There is no key identifier which matches the required format!\n‘\(signed.keyID)‘")
        }
    }

    private func verify() {
        guard let id = keyID, let k = KeyStore.shared.key(id: id) else {
            PKIModal.warning("Entry incomplete\n\nPlease choose the signature originator.")
            return
        }
        guard let hash = PKISignHash.named((isEC && !signed.legacy) ? ecHash.rawValue : signed.hash) else {
            PKIModal.warning("Entry incomplete\n\nUnknown hash function: \(signed.hash)")
            return
        }
        let start = Date()
        let digest = Hashing.hash(signed.message, algorithm: hash.algorithm)
        var ok = false
        if let c = signed.c, let d = signed.d {
            guard let curve = k.curve, let W = k.ecPublic else { return finish(false, Date().timeIntervalSince(start)) }
            if showSteps {
                let v = PKIECSteps.verify(message: signed.message, method: ecMethod, hash: hash, c: c, d: d, curve: curve, W: W, owner: k)
                PKIModal.run(title: "Signature Verification - Step By Step") { done in
                    PKIStepDialog(title: "Step-by-step signature verification:", header: v.header, steps: v.steps,
                                  finishTitle: "End dialog", finish: done, cancel: done)
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
        var t = "Signature s:\n\(s)\n\nPublic key of the signature originator:\nN = \(pub.n)\ne = \(pub.e)\n\n"
        t += "s^e mod N (hexadecimal):\n\(PKIText.hex(v.bigEndianBytes(length: k)))\n\n"
        t += "\(hash.rawValue) hash value of the message:\n\(PKIText.hex(digest))\n\n"
        t += "Expected (PKCS #1: 00 01 FF … FF 00 ‖ DigestInfo ‖ hash value):\n"
        t += ((try? PKIRSASignature.encode(digest, hash: hash, k: k)).map(PKIText.hex) ?? "–") + "\n\n"
        t += ok ? "Correct signature!" : "Signature is not correct!"
        PKIModal.run(title: "Signature Verification - Step By Step") { done in
            PKIStepDialog(title: "Step-by-step signature verification:", header: "RSA signature with \(hash.rawValue)", steps: [t],
                          finishTitle: "End dialog", finish: done, cancel: done)
        }
    }

    private func finish(_ ok: Bool, _ t: TimeInterval) {
        close()
        if showTime {
            let time = "Duration of signature verification: \(PKIText.seconds(t)) seconds."
            ok ? PKIModal.info("Correct signature!\n" + time) : PKIModal.warning("Invalid signature!\n" + time)
        } else {
            ok ? PKIModal.info("Correct signature!") : PKIModal.warning("Signature is not correct!")
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
            Text("Extracted Signature").font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Signer:"); Text(key?.firstLast ?? "Unknown - transmitted key identifier does not exist").textSelection(.enabled) }
                GridRow {
                    Text("Used key:")
                    Text(key.map { "\($0.type.displayName)\($0.label.isEmpty ? "" : " (\($0.label))"); created \($0.createdString)" } ?? signed.keyID)
                        .textSelection(.enabled)
                }
                GridRow { Text("Signature algorithm:"); Text("\(signed.method) with hash function \(signed.hash)") }
            }
            Text("Signature:")
            ResultBox(text: signatureText, minHeight: 120)
            Text("Length of signature: \(signed.bitLength) bits").font(.callout)
            PKIGroup("Options for presentation of signature") {
                HStack {
                    Text("Numbers:")
                    Picker("", selection: $mode) {
                        Text("Octal").tag(0); Text("Decimal").tag(1); Text("Hexadecimal").tag(2); Text("Hex dump (hexadecimal and ASCII):").tag(3)
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
            }
            Text("Signed message:")
            ResultBox(text: PKIText.string(Array(signed.message.prefix(100_000))), minHeight: 120)
            Text("Length of message: \(signed.message.count) bytes").font(.callout)
            Divider()
            HStack {
                Button("Verify") {
                    close()
                    DispatchQueue.main.async { SignatureOps.verify(document) }
                }
                Spacer()
                PKIHelpButton(action: .extractSignature)
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 680)
    }
}
