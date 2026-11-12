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
        WindowPresenter.tool(id: "factorhint", title: "Faktorisieren mit teilweise bekanntem p",
                             size: CGSize(width: 640, height: 560)) { FactorHintView() }
    }
    static func openStereotyped() {
        WindowPresenter.tool(id: "stereotyped", title: "Angriff auf stereotype Nachrichten",
                             size: CGSize(width: 680, height: 620)) { StereotypedView() }
    }
    static func openSmallSecretKey() {
        WindowPresenter.tool(id: "bloemermay", title: "Angriff auf kleine geheime Schlüssel",
                             size: CGSize(width: 660, height: 560)) { SmallSecretKeyView() }
    }
    static func openSideChannel() {
        WindowPresenter.tool(id: "sidechannel", title: "Seitenkanalangriff auf \"Textbook-RSA\"",
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
        DialogScaffold(title: "Faktorisieren mit teilweise bekanntem p",
                       subtitle: "Mit diesem Angriff lässt sich der RSA-Modul N faktorisieren, wenn ein Teil P eines der beiden Faktoren p oder q bekannt ist. Benötigt werden mindestens ⌈n/4⌉+1 Bit von p.",
                       minWidth: 600) {
            GroupBox("Schritt 1: Öffentlichen Schlüssel eingeben") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow {
                        Text("Bitlänge von p:"); TextField("", text: $pBitsText).frame(width: 90)
                    }
                }.padding(6)
            }
            GroupBox("Schritt 2: Bekannter Teil P der Primzahl p") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $highBits) {
                        Text("höchstwertige Bits").tag(true)
                        Text("niederstwertige Bits").tag(false)
                    }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    HStack { Text("Bitlänge von P (bekannte Bits):"); TextField("", text: $pBitsOfPText).frame(width: 90) }
                    HStack { Text("P:"); TextField("", text: $pText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Gitter wird reduziert …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Beispiel erzeugen") { makeExample() }.disabled(running)
            Spacer()
            Button("Starten") { start() }.keyboardShortcut(.defaultAction).disabled(running)
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
        info = "Beispiel erzeugt: p, q mit je 128 Bit, \(unknown) unbekannte Bits."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let pBits = Int(pBitsText.trimmingCharacters(in: .whitespaces)),
              let knownBits = Int(pBitsOfPText.trimmingCharacters(in: .whitespaces)),
              let P = parseBigNumber(pText), pBits > 0, knownBits > 0, knownBits < pBits else {
            Alerts.info(NTMessages.inputFalse, title: "Eingabe"); return
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
                    result = "Faktorisierung gefunden (\(String(format: "%.2f", dt)) s):\n\np = \(r.p)\n\nq = \(r.q)"
                } else {
                    result = "Es wurde keine Faktorisierung gefunden. Möglicherweise ist zu wenig von p bekannt (nötig: ⌈n/4⌉+1 Bit)."
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
        DialogScaffold(title: "Angriff auf stereotype Nachrichten",
                       subtitle: "Fängt ein Angreifer eine mit RSA verschlüsselte Nachricht ab und kennt den größten Teil des Klartextes, kann er den unbekannten Teil finden – sofern der öffentliche Exponent e klein ist (z. B. 3).",
                       minWidth: 640) {
            GroupBox("Schritt 1: Öffentlicher Schlüssel") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).frame(width: 80) }
                }.padding(6)
            }
            GroupBox("Schritt 2: Geheimtext") {
                HStack { Text("c:"); TextField("", text: $cipherText).font(.system(.body, design: .monospaced)) }.padding(6)
            }
            GroupBox("Schritt 3: Bekannter Klartext und unbekannter Bereich") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Klartext:"); TextField("", text: $knownText).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text("Position:"); TextField("", text: $posText).frame(width: 60)
                        Text("Länge (Byte):"); TextField("", text: $lenText).frame(width: 60)
                    }
                    Text("Die unbekannten Bytes im Klartext stehen ab „Position“ über „Länge“ Bytes; die übrigen Zeichen sind bekannt.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Gitter wird reduziert …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Beispiel erzeugen") { makeExample() }.disabled(running)
            Spacer()
            Button("Starten") { start() }.keyboardShortcut(.defaultAction).disabled(running)
        }
    }

    private func makeExample() {
        let p = Primality.randomPrime(bits: 128)
        let q = Primality.randomPrime(bits: 128)
        let N = p * q
        let e = 3
        let full = "Das Passwort lautet 2718"       // die letzten 4 Zeichen sind unbekannt
        let bytes = TextCoding.bytes(from: full)
        let m = BigUInt(bigEndianBytes: bytes)
        let c = m.power(e, modulus: N)
        nText = N.description
        eText = "3"
        cipherText = c.description
        knownText = full
        posText = String(bytes.count - 4)
        lenText = "4"
        info = "Beispiel erzeugt: N mit 256 Bit, e = 3; die 4 Zeichen ab Position \(bytes.count - 4) gelten als unbekannt."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = Int(eText.trimmingCharacters(in: .whitespaces)),
              let c = parseBigNumber(cipherText), let pos = Int(posText.trimmingCharacters(in: .whitespaces)),
              let len = Int(lenText.trimmingCharacters(in: .whitespaces)), e >= 2, len >= 1, pos >= 0 else {
            Alerts.info(NTMessages.inputFalse, title: "Eingabe"); return
        }
        var bytes = TextCoding.bytes(from: knownText)
        guard pos + len <= bytes.count else {
            Alerts.info("Position und Länge des unbekannten Teils liegen außerhalb des Klartextes.", title: "Eingabe"); return
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
                    result = "Nachricht wiederhergestellt (\(String(format: "%.2f", dt)) s):\n\n\(txt)\n\nm = \(m)"
                } else {
                    result = "Der unbekannte Teil konnte nicht gefunden werden. Er ist evtl. zu groß (nötig: kleiner als N^(1/e))."
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
        DialogScaffold(title: "Angriff auf kleine geheime Schlüssel",
                       subtitle: "Mit diesem Angriff lässt sich N faktorisieren, wenn der geheime Schlüssel d zu klein ist. Verwendet wird das Gitterverfahren nach Blömer/May (Boneh/Durfee), δ = log(d)/log(N) < 0,292 – wie in CT1. Für sehr kleines d (δ < 0,25) wird zuerst das schnelle Kettenbruchverfahren (Wiener) versucht; es liefert denselben Schlüssel.",
                       minWidth: 640) {
            GroupBox("Öffentlicher Schlüssel (N, e)") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            GroupBox("Gitterparameter") {
                HStack {
                    Text("δ (geschätzte Größe von d):"); TextField("", text: $deltaText).frame(width: 70)
                    Text("m:"); TextField("", text: $mText).frame(width: 50)
                    Text("(t wird optimal gewählt)").font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            Text("Hinweis: Das Gitterverfahren ist rechenintensiv; größere N oder δ nahe 0,29 können einige Minuten dauern. CT1 nutzt eine schnellere Fließkomma-LLL.")
                .font(.caption).foregroundStyle(.secondary)
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Gitter wird reduziert …") } }
            if !result.isEmpty { ResultBox(text: result, minHeight: 80) }
        } buttons: {
            Button("Beispiel erzeugen") { makeExample() }.disabled(running)
            Spacer()
            Button("Starten") { start() }.keyboardShortcut(.defaultAction).disabled(running)
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
        info = "Beispiel erzeugt: N mit \(N.bitLength) Bit, d mit \(dbits) Bit (δ ≈ 0,25)."
        result = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = parseBigNumber(eText) else {
            Alerts.info(NTMessages.inputFalse, title: "Eingabe"); return
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
                    result = "Angriff erfolgreich (Wiener, \(String(format: "%.2f", dt)) s):\n\nd = \(w.d)\n\np = \(w.p)\n\nq = \(w.q)"
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
                    result = "Angriff erfolgreich (Blömer/May, Gitterdimension \(r.latticeDimension), \(String(format: "%.1f", dt)) s):\n\nd = \(r.d)\n\np = \(r.p)\n\nq = \(r.q)"
                } else {
                    result = "Es wurde kein kleiner geheimer Schlüssel gefunden. Für δ nahe 0,29 ggf. m erhöhen (deutlich längere Laufzeit)."
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
        DialogScaffold(title: "Seitenkanalangriff auf \"Textbook-RSA\"",
                       subtitle: "Seitenkanalangriff von Ulrich Kühn auf das RSA-Hybridprotokoll. Trudy fängt das mit ungepolstertem RSA verschlüsselte Chiffrat c des Sessionkeys ab und verändert es multiplikativ. Über die Ja/Nein-Antworten von Bobs Server (Seitenkanal) rekonstruiert eine Binärsuche den geheimen Sessionkey – nicht Bobs privaten Schlüssel.",
                       minWidth: 660) {
            GroupBox("Öffentlicher Schlüssel von Bob") {
                Grid(alignment: .leading) {
                    GridRow { Text("N:"); TextField("", text: $nText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("e:"); TextField("", text: $eText).font(.system(.body, design: .monospaced)) }
                }.padding(6)
            }
            GroupBox("Server-Orakel") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("d:"); TextField("", text: $dText).font(.system(.body, design: .monospaced)) }
                    Text("Bobs privater Schlüssel liegt in CT1 in der PSE des Servers; hier wird er eingegeben, damit das Orakel (Ampel grün/rot) rechnen kann. Trudy kennt d nicht.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(6)
            }
            GroupBox("Abgefangenes Chiffrat / Parameter") {
                Grid(alignment: .leading) {
                    GridRow { Text("c:"); TextField("", text: $cipherText).font(.system(.body, design: .monospaced)) }
                    GridRow { Text("Signifikante Bits:"); TextField("", text: $bitsText).frame(width: 80) }
                }.padding(6)
            }
            if !info.isEmpty { Text(info).font(.caption).foregroundStyle(.secondary) }
            if running { HStack { ProgressView().controlSize(.small); Text("Angriffszyklus läuft …") } }
            if !result.isEmpty { Text(result).font(.callout).fixedSize(horizontal: false, vertical: true) }
            if !log.isEmpty { ResultBox(text: log, minHeight: 140) }
        } buttons: {
            Button("Beispiel erzeugen") { makeExample() }.disabled(running)
            Spacer()
            Button("Angriff starten") { start() }.keyboardShortcut(.defaultAction).disabled(running)
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
        info = "Beispiel erzeugt: Bob-Schlüssel RSA-512, geheimer 128-Bit-Sessionkey K = \(K)."
        result = ""; log = ""
    }

    private func start() {
        guard let N = parseBigNumber(nText), let e = parseBigNumber(eText), let d = parseBigNumber(dText),
              let c = parseBigNumber(cipherText), let bits = Int(bitsText.trimmingCharacters(in: .whitespaces)),
              bits > 0, bits % 8 == 0 else {
            Alerts.info("Bitte N, e, d, c (Zahlen) und signifikante Bits (Vielfaches von 8) angeben.", title: "Eingabe"); return
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
                    "Schritt \(s.index) (Phase \(s.phase)): Antwort \(s.response ? "JA (grün)" : "NEIN (rot)")"
                }
                let steps = r.steps
                if steps.count <= 16 {
                    lines = steps.map(fmt)
                } else {
                    lines = steps.prefix(8).map(fmt) + ["   … \(steps.count - 16) weitere Anfragen …"] + steps.suffix(8).map(fmt)
                }
                await MainActor.run {
                    running = false
                    result = "Angriff erfolgreich (\(String(format: "%.2f", dt)) s, \(r.queries) Anfragen an den Server).\n\nRekonstruierter Sessionkey K = \(r.secret)"
                    log = lines.joined(separator: "\n")
                }
            } catch {
                await MainActor.run {
                    running = false
                    result = "Der Angriff ist nicht durchführbar: Die Bedingung L(N) > 3·(signifikante Bits)+3 ist verletzt. Wählen Sie einen größeren Modul N oder weniger signifikante Bits."
                }
            }
        }
    }
}
