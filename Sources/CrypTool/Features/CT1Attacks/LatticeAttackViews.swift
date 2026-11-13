import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// Gitterbasierte Angriffe auf RSA (CT1: Einzelverfahren ▸ RSA-Kryptosystem ▸ Gitterbasierte
// Angriffe auf RSA bzw. Analyse ▸ Asymmetrische Verfahren):
//   IDD_RSAFACTORHINT   – Faktorisieren mit teilweise bekanntem p
//   IDD_RSASTEREOTYPED  – Angriff auf stereotype Nachrichten
//   IDD_RSABLOEMERMAY   – Angriff auf kleine geheime Schlüssel
// Die Rechenkerne stehen in CTBigNum (Lattice/Coppersmith).

@MainActor
enum LatticeAttacks {
    static func openFactorHint() {
        WindowPresenter.tool(id: "factorhint", title: "Factoring Knowing a Fraction of p",
                             size: CGSize(width: 640, height: 560)) { FactorHintView() }
    }
    static func openStereotyped() {
        WindowPresenter.tool(id: "stereotyped", title: "Attack on Stereotyped Messages",
                             size: CGSize(width: 680, height: 620)) { StereotypedView() }
    }
    static func openSmallSecretKey() {
        WindowPresenter.tool(id: "bloemermay", title: "Attack on Small Secret Exponents (according to Bloemer / May)",
                             size: CGSize(width: 660, height: 560)) { SmallSecretKeyView() }
    }
    static func openSideChannel() {
        WindowPresenter.tool(id: "sidechannel", title: "Side-Channel Attack on \"Textbook RSA\"",
                             size: CGSize(width: 700, height: 640)) { SideChannelView() }
    }
}

// MARK: - Faktorisieren mit teilweise bekanntem p

private struct FactorHintView: View {
    @CTState private var nText = ""
    @CTState private var pBitsText = ""       // Bitlänge von p
    @CTState private var pBitsOfPText = ""    // Anzahl bekannter Bits (Bitlänge von P)
    @CTState private var pText = ""           // bekannter Teil P
    @CTState private var highBits = true      // höchstwertige / niederstwertige Bits
    @CTState private var running = false
    @CTState private var result = ""
    @CTState private var info = ""

    var body: some View {
        DialogScaffold(title: "Factoring Knowing a Fraction of p",
                       subtitle: "This attack allows to factor an RSA modulus N, if a part of one of its factors p and q is known (we assume here, that a part of p is known). Let P be the known fraction of p. At least ⌈n/4⌉+1 bits of p are needed.",
                       minWidth: 600) {
            GroupBox("Step 1: Enter public key") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow {
                        Text("Bit length of p:"); TextField("", text: $pBitsText).frame(width: 90)
                    }
                }.padding(6)
            }
            GroupBox("Step 2: Enter P (known part of the prime number p)") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $highBits) {
                        Text("most significant bits").tag(true)
                        Text("least significant bits").tag(false)
                    }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    HStack { Text("Bit length of P (known bits):"); TextField("", text: $pBitsOfPText).frame(width: 90) }
                    HStack { Text("P:"); TextField("", text: $pText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Reducing lattice …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Generate example") { makeExample() }.disabled(running)
            Spacer()
            Button("Start") { start() }.keyboardShortcut(.defaultAction).disabled(running)
        }
    }

    private func makeExample() {
        // 128-Bit-Primzahlen (N 256 Bit); es fehlen 50 Bit von p.
        let p = Primality.randomPrime(bits: 128)
        let q = Primality.randomPrime(bits: 128)
        let unknown = 50
        let knownBits = 128 - unknown
        nText = (p * q).description
        pBitsText = "128"
        pBitsOfPText = String(knownBits)
        if highBits {
            pText = (p >> unknown).description           // bekannte höchstwertige Bits als kurze Zahl
        } else {
            pText = (p % (BigUInt(1) << knownBits)).description   // bekannte niederstwertige Bits
        }
        info = "Example generated: p, q with 128 bits each, \(unknown) unknown bits."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let pBits = Int(pBitsText.trimmingCharacters(in: .whitespaces)),
              let knownBits = Int(pBitsOfPText.trimmingCharacters(in: .whitespaces)),
              let P = parseBigNumber(pText), pBits > 0, knownBits > 0, knownBits < pBits else {
            Alerts.info(NTMessages.inputFalse, title: "Input"); return
        }
        let unknown = pBits - knownBits
        // Höchstwertige Bits: P als kurze Zahl in den oberen Teil schieben (p = P·2^unknown + x₀).
        let known = highBits ? (P << unknown) : P
        running = true; result = ""
        let start = Date()
        Task.detached {
            let r = Coppersmith.factorWithKnownBits(n: N, known: known, pBits: pBits,
                                                    unknownBits: unknown, highBits: highBits)
            let dt = Date().timeIntervalSince(start)
            await MainActor.run {
                running = false
                if let r {
                    result = "Found solution (\(String(format: "%.2f", dt)) s):\n\np = \(r.p)\n\nq = \(r.q)"
                } else {
                    result = "Attack not successful. Possibly too little of p is known (needed: ⌈n/4⌉+1 bits)."
                }
            }
        }
    }
}

// MARK: - Angriff auf stereotype Nachrichten

private struct StereotypedView: View {
    @CTState private var nText = ""
    @CTState private var eText = "3"
    @CTState private var knownText = ""       // bekannter Klartext (Text)
    @CTState private var cipherText = ""      // Geheimtext (dezimal)
    @CTState private var posText = ""         // Position des unbekannten Teils (Byte)
    @CTState private var lenText = ""         // Länge des unbekannten Teils (Byte)
    @CTState private var running = false
    @CTState private var result = ""
    @CTState private var info = ""

    var body: some View {
        DialogScaffold(title: "Attack on Stereotyped Messages",
                       subtitle: "If a RSA-encrypted message is intercepted and the major part of the plaintext belonging to it is known, this attack allows to find the remaining part of the plaintext, provided the public exponent e is small (e.g. 3).",
                       minWidth: 640) {
            GroupBox("Step 1: Enter the public key (N,e)") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).frame(width: 80) }
                }.padding(6)
            }
            GroupBox("Step 2: Ciphertext") {
                HStack { Text("c:"); TextField("", text: $cipherText).font(.system(.body, design: .monospaced)) }.padding(6)
            }
            GroupBox("Step 3: Part of the plaintext known to the attacker") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Plaintext:"); TextField("", text: $knownText).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text("Position:"); TextField("", text: $posText).frame(width: 60)
                        Text("Length (bytes):"); TextField("", text: $lenText).frame(width: 60)
                    }
                    Text("The unknown bytes of the plaintext start at \"Position\" and span \"Length\" bytes; the remaining characters are known.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Reducing lattice …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Generate example") { makeExample() }.disabled(running)
            Spacer()
            Button("Start") { start() }.keyboardShortcut(.defaultAction).disabled(running)
        }
    }

    private func makeExample() {
        let p = Primality.randomPrime(bits: 128)
        let q = Primality.randomPrime(bits: 128)
        let N = p * q
        let e = 3
        let full = "The password is 2718"       // the last 4 characters are unknown
        let bytes = TextCoding.bytes(from: full)
        let m = BigUInt(bigEndianBytes: bytes)
        let c = m.power(e, modulus: N)
        nText = N.description
        eText = "3"
        cipherText = c.description
        knownText = full
        posText = String(bytes.count - 4)
        lenText = "4"
        info = "Example generated: N with 256 bits, e = 3; the 4 characters from position \(bytes.count - 4) are considered unknown."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = Int(eText.trimmingCharacters(in: .whitespaces)),
              let c = parseBigNumber(cipherText), let pos = Int(posText.trimmingCharacters(in: .whitespaces)),
              let len = Int(lenText.trimmingCharacters(in: .whitespaces)), e >= 2, len >= 1, pos >= 0 else {
            Alerts.info(NTMessages.inputFalse, title: "Input"); return
        }
        var bytes = TextCoding.bytes(from: knownText)
        guard pos + len <= bytes.count else {
            Alerts.info("Position and length of the unknown part are outside the plaintext.", title: "Input"); return
        }
        for i in pos..<(pos + len) { bytes[i] = 0 }                 // unbekannte Bytes auf 0 setzen
        let known = BigUInt(bigEndianBytes: bytes)
        let shift = BigUInt(1) << (8 * (bytes.count - pos - len))   // Stellenwert des Blocks
        let bound = BigUInt(1) << (8 * len)
        running = true; result = ""
        let start = Date()
        Task.detached {
            let m = Coppersmith.stereotypedMessage(n: N, e: e, cipher: c, known: known, bound: bound, shift: shift)
            let dt = Date().timeIntervalSince(start)
            await MainActor.run {
                running = false
                if let m {
                    let txt = TextCoding.string(from: m.bigEndianBytes)
                    result = "Message recovered (\(String(format: "%.2f", dt)) s):\n\n\(txt)\n\nm = \(m)"
                } else {
                    result = "The unknown part could not be found. It may be too big (needed: smaller than N^(1/e))."
                }
            }
        }
    }
}

// MARK: - Angriff auf kleine geheime Schlüssel

private struct SmallSecretKeyView: View {
    @CTState private var nText = ""
    @CTState private var eText = ""
    @CTState private var deltaText = "0.25"
    @CTState private var mText = "5"
    @CTState private var running = false
    @CTState private var result = ""
    @CTState private var info = ""

    var body: some View {
        DialogScaffold(title: "Attack on Small Secret Exponents (according to Bloemer / May)",
                       subtitle: "This attack factors an RSA modulus N if the secret key d is too small compared to N. The lattice method according to Bloemer/May (Boneh/Durfee) is used, δ = log(d)/log(N) < 0.292 – as in CT1. For very small d (δ < 0.25) the fast continued fraction method (Wiener) is tried first; it yields the same key.",
                       minWidth: 640) {
            GroupBox("Public key (N, e)") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            GroupBox("Lattice parameters") {
                HStack {
                    Text("δ (estimated size of d):"); TextField("", text: $deltaText).frame(width: 70)
                    Text("m:"); TextField("", text: $mText).frame(width: 50)
                    Text("(t is optimally calculated as a function of m)").font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            Text("Note: The lattice method is computationally intensive; larger N or δ close to 0.29 can take several minutes. CT1 uses a faster floating-point LLL.")
                .font(.caption).foregroundStyle(.secondary)
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Reducing lattice …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Generate example") { makeExample() }.disabled(running)
            Spacer()
            Button("Start") { start() }.keyboardShortcut(.defaultAction).disabled(running)
        }
    }

    private func makeExample() {
        // RSA mit kleinem geheimem Exponenten: N 128 Bit, d mit δ ≈ 0,25 (jenseits der
        // sicheren Wiener-Grenze – zeigt das Gitterverfahren; läuft in wenigen Sekunden).
        let p = Primality.randomPrime(bits: 64)
        let q = Primality.randomPrime(bits: 64)
        let N = p * q
        let phi = (p - BigUInt(1)) * (q - BigUInt(1))
        let dbits = N.bitLength / 4
        var d = BigUInt.random(in: (BigUInt(1) << (dbits - 1))...(BigUInt(1) << dbits))
        while d.gcd(phi) != BigUInt(1) { d = BigUInt.random(in: (BigUInt(1) << (dbits - 1))...(BigUInt(1) << dbits)) }
        guard let e = d.inverse(modulo: phi) else { return }
        nText = N.description
        eText = e.description
        deltaText = "0.25"
        mText = "5"
        info = "Example generated: N with \(N.bitLength) bits, d with \(dbits) bits (δ ≈ 0.25)."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = parseBigNumber(eText) else {
            Alerts.info(NTMessages.inputFalse, title: "Input"); return
        }
        let delta = Double(deltaText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0.25
        let m = max(3, Int(mText.trimmingCharacters(in: .whitespaces)) ?? 5)
        running = true; result = ""
        let start = Date()
        Task.detached {
            // Schneller Wiener-Vorlauf (identisches Ergebnis für δ < 0,25).
            if let w = Coppersmith.wienerSmallSecretKey(n: N, e: e) {
                let dt = Date().timeIntervalSince(start)
                await MainActor.run {
                    running = false
                    result = "Attack successful (Wiener, \(String(format: "%.2f", dt)) s):\n\nd = \(w.d)\n\np = \(w.p)\n\nq = \(w.q)"
                }
                return
            }
            // Gitterverfahren nach Blömer/May.
            let t = BloemerMay.optimalT(m)
            let r = BloemerMay.attack(n: N, e: e, delta: delta, m: m, t: t)
            let dt = Date().timeIntervalSince(start)
            await MainActor.run {
                running = false
                if let r {
                    result = "Attack successful (Bloemer/May, lattice dimension \(r.latticeDimension), \(String(format: "%.1f", dt)) s):\n\nd = \(r.d)\n\np = \(r.p)\n\nq = \(r.q)"
                } else {
                    result = "No small secret key was found. For δ close to 0.29 increase m if necessary (considerably longer running time)."
                }
            }
        }
    }
}

// MARK: - Seitenkanalangriff auf "Textbook-RSA" (Kühn)

private struct SideChannelView: View {
    @CTState private var nText = ""
    @CTState private var eText = ""
    @CTState private var dText = ""
    @CTState private var cipherText = ""
    @CTState private var bitsText = "128"
    @CTState private var running = false
    @CTState private var result = ""
    @CTState private var log = ""
    @CTState private var info = ""

    var body: some View {
        DialogScaffold(title: "Side-Channel Attack on \"Textbook RSA\"",
                       subtitle: "Ulrich Kuehn's side-channel attack against the RSA based hybrid encryption protocol. Trudy intercepts the ciphertext c of the session key, which was encrypted with unpadded RSA, and modifies it multiplicatively. From the yes/no responses of Bob's server (side channel), a binary search reconstructs the secret session key – not Bob's private key.",
                       minWidth: 660) {
            GroupBox("Bob's public key") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            GroupBox("Server oracle") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("d:"); TextField("", text: $dText).font(.system(.body, design: .monospaced)) }
                    Text("In CT1, Bob's private key is stored in the PSE of the server; here it is entered so that the oracle (traffic light green/red) can calculate. Trudy does not know d.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            GroupBox("Intercepted ciphertext / parameters") {
                Grid(alignment: .leading) {
                    GridRow { Text("c:"); TextField("", text: $cipherText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("Significant bits:"); TextField("", text: $bitsText).frame(width: 80) }
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Attack cycle running …") } }
            if !result.isEmpty { Text(result).font(.callout).fixedSize(horizontal: false, vertical: true) }
            if !log.isEmpty { ResultBox(text: log, minHeight: 140) }
        } buttons: {
            Button("Generate example") { makeExample() }.disabled(running)
            Spacer()
            Button("Start attack") { start() }.keyboardShortcut(.defaultAction).disabled(running)
        }
    }

    private func makeExample() {
        // RSA-512 wie in CT1 (Bob), 128-Bit-Sessionkey.
        let p = Primality.randomPrime(bits: 256)
        let q = Primality.randomPrime(bits: 256)
        let N = p * q
        let phi = (p - BigUInt(1)) * (q - BigUInt(1))
        var e = BigUInt(65537)
        while e.gcd(phi) != BigUInt(1) { e = e + BigUInt(2) }
        guard let d = e.inverse(modulo: phi) else { return }
        let K = BigUInt.random(below: BigUInt(1) << 128)   // 128-Bit-Sessionkey
        let c = K.power(e, modulus: N)
        nText = N.description; eText = e.description; dText = d.description
        cipherText = c.description; bitsText = "128"
        info = "Example generated: Bob's key RSA-512, secret 128-bit session key K = \(K)."
        result = ""; log = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = parseBigNumber(eText), let d = parseBigNumber(dText),
              let c = parseBigNumber(cipherText), let bits = Int(bitsText.trimmingCharacters(in: .whitespaces)),
              bits > 0, bits % 8 == 0 else {
            Alerts.info("Please enter N, e, d, c (numbers) and the significant bits (multiple of 8).", title: "Input"); return
        }
        running = true; result = ""; log = ""
        let start = Date()
        Task.detached {
            do {
                let r = try SideChannel.run(n: N, e: e, d: d, cipher: c, significantBits: bits)
                let dt = Date().timeIntervalSince(start)
                // kompaktes Protokoll: erste und letzte Schritte
                var lines: [String] = []
                func fmt(_ s: SideChannel.Step) -> String {
                    "Step \(s.index) (phase \(s.phase)): response \(s.response ? "YES (green)" : "NO (red)")"
                }
                let steps = r.steps
                if steps.count <= 16 {
                    lines = steps.map(fmt)
                } else {
                    lines = steps.prefix(8).map(fmt) + ["   … \(steps.count - 16) more requests …"] + steps.suffix(8).map(fmt)
                }
                await MainActor.run {
                    running = false
                    result = "Attack successful (\(String(format: "%.2f", dt)) s, \(r.queries) requests to the server).\n\nReconstructed session key K = \(r.secret)"
                    log = lines.joined(separator: "\n")
                }
            } catch {
                await MainActor.run {
                    running = false
                    result = "The attack is not feasible: the condition L(N) > 3·(significant bits)+3 is violated. Choose a larger modulus N or fewer significant bits."
                }
            }
        }
    }
}
