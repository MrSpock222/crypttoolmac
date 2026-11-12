import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// State of CT1's IDD_CRT_SECRETSHARING (DlgCrtSecretSharing.cpp).
@MainActor
final class CRTSSModel: ObservableObject {
    static let prefIntro = "crtss.showIntro"

    @Published var n = 5
    @Published var k = 3
    @Published var lower = "2^108"
    @Published var upper = "2^109"
    @Published var manual = false
    @Published var ids = Array(repeating: "", count: 7)
    @Published var pw = Array(repeating: "", count: 7)
    @Published var rek = Array(repeating: "", count: 7)
    @Published var minK = ""
    @Published var maxK1 = ""
    @Published var w = ""
    @Published var s = ""
    @Published var a = ""
    @Published var sPrime = ""
    @Published var log = ""
    @Published var computed = false
    /// Replacement for CT1's safe animations: nil = idle, 0 = shares distributed,
    /// 1…7 = number of keys inserted, 100 = opened, -1 = failed.
    @Published var safeState: Int? = nil
    @Published var showIntro = CT1Prefs.bool(CRTSSModel.prefIntro, true)

    var title: String { "Secret-Sharing mittels CRT: Ein Geheimnis mit \(k) von \(n) Schlüsseln rekonstruieren" }

    func clearValues() {
        minK = ""; maxK1 = ""; w = ""; s = ""; a = ""; sPrime = ""
        ids = Array(repeating: "", count: 7); pw = Array(repeating: "", count: 7); rek = Array(repeating: "", count: 7)
    }

    /// "Zurücksetzen" (OnBnClickedSecretsharingReset).
    func reset() {
        clearValues(); log = ""; computed = false; safeState = nil
    }

    private static let inputFalse = "In diesem Feld wird eine Zahl oder ein Ausdruck erwartet,\naus dem sich ein Zahlenwert berechnen lässt.\nBitte geben Sie einen gültigen Ausdruck ein!\n\nBeispiele: 123, 2^15+1, (2^17-5)^2."
    static let generatePrimeMsg = "Die Demonstration unterstützt nur Primzahlen der Bitlänge kleiner 109.\nDas sind Zahlen mit höchstens 33 Dezimalstellen.\nBitte verringern Sie den Wertebereich im Optionen-Dialog."

    /// "Berechnen" (OnBnClickedSecretsharingShare).
    func share() {
        rek = Array(repeating: "", count: 7)
        if manual { prepareManual() } else if let primes = generatePrimes() { calculate(primes) }
    }

    /// CT1 GeneratePrime(): n distinct random primes from [lower, upper], ascending.
    private func generatePrimes() -> [BigUInt]? {
        if lower.trimmingCharacters(in: .whitespaces).isEmpty || upper.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Geben Sie Ober- und Untergrenze ein!"); return nil
        }
        guard let lo = CRTUtil.formula(lower), let hi = CRTUtil.formula(upper) else { Alerts.error(Self.inputFalse); return nil }
        if lo > hi { Alerts.error("Die Untergrenze darf nicht größer als die Obergrenze sein!"); return nil }
        var primes: [BigUInt] = []
        for _ in 0..<n {
            var found: BigUInt?
            for _ in 0..<10 {
                if let p = CRTUtil.randomPrime(lo, hi), !primes.contains(p) { found = p; break }
            }
            guard let p = found else {
                reset()
                CRTUtil.message("Bei der zufälligen Erzeugung der Primzahlen für die \(n) Kennungen sind Primzahlen doppelt aufgetreten.\nFür die Anwendung des Chinesischen Restsatzes müssen die Kennungen jedoch alle verschieden sein.\nBitte drücken Sie (evtl. mehrfach) erneut den Button 'Berechnen' oder erhöhen Sie den Wertebereich im Optionen-Dialog.\n")
                return nil
            }
            primes.append(p)
        }
        primes.sort()
        if primes.contains(where: { $0.description.count > 33 }) {
            reset()
            CRTUtil.message(Self.generatePrimeMsg)
            return nil
        }
        for i in 0..<7 { ids[i] = i < n ? primes[i].description : "" }
        return primes
    }

    /// CT1 PrepareManual(): identifiers typed by the student.
    private func prepareManual() {
        if ids.prefix(n).contains(where: { $0.isEmpty }) {
            CRTUtil.message("Bitte ausreichend Kennungen angeben."); return
        }
        let primes = ids.prefix(n).map { BigUInt($0) ?? 0 }
        for i in 0..<n {
            for j in (i + 1)..<n where primes[i] == primes[j] {
                CRTUtil.message("Jede Kennung muss eine Primzahl sein und alle Eingaben müssen verschieden sein. \nDie Kennung wurde \(primes[i]) doppelt angegeben.")
                return
            }
        }
        var nonPrimes = 0
        for p in primes where !Primality.millerRabin(p, rounds: 100) {
            nonPrimes += 1
            CRTUtil.message("Bitte nur Primzahlen eingeben. Die Kennung \(p) ist nicht prim.")
        }
        guard nonPrimes == 0 else { return }
        let sorted = primes.sorted()
        for i in 0..<n { ids[i] = sorted[i].description }
        calculate(sorted)
    }

    /// CT1 Calculate(): min(k), max(k-1), w, random s and a, s' and the passwords.
    private func calculate(_ primes: [BigUInt]) {
        let t = n
        var minKv = BigUInt(1), maxK1v = BigUInt(1)
        for i in 0..<k { minKv *= primes[i] }
        if k > 1 { for i in stride(from: t - 1, through: t - (k - 1), by: -1) { maxK1v *= primes[i] } }
        var wv = minKv / maxK1v
        if wv.isZero { wv = 1 }
        var sv = BigUInt.random(below: wv + 1)          // MIRACL rand(w+1): 0 … w
        if wv.isOne { sv = 0 }
        let aRange = minKv / wv
        let av = aRange.isZero ? BigUInt() : BigUInt.random(below: aRange)
        let sp = av * wv + sv
        minK = minKv.description; maxK1 = maxK1v.description; w = wv.description
        s = sv.description; a = av.description; sPrime = sp.description
        for i in 0..<7 { pw[i] = i < t ? (sp % primes[i]).description : "" }

        var l = "----- Berechnung beginnt ----- \n\n"
        l += "Anzahl gegebene Schlüssel:  \(n)\n"
        l += "Anzahl benötigte Schlüssel: \(k)\n\n"
        l += "KLEINSTE mögliche Kennung: \(lower)\n"
        l += "GRÖßTE mögliche Kennung:   \(upper)\n\n"
        for i in 0..<t { l += "Kennung_\(i + 1): \n\(ids[i])\n" }
        l += "\nmin(k):\n\(minK)\n"
        l += "max(k-1):\n\(maxK1)\n"
        l += "Quotient w:\n\(w)\n"
        l += "Geheimnis s:\n\(s)\n"
        l += "Faktor a:\n\(a)\n"
        l += "Basis für Shares (s'):\n\(sPrime)\n"
        l += "\n"
        for i in 0..<t { l += "Passwort_\(i + 1):\n\(pw[i])\n" }
        if t == 7 { l += "\n\n" }
        l += "\n----- Berechnung der Kennungen und Passwörter abgeschlossen -----\n\n"
        log = l
        computed = true
        safeState = 0
    }

    /// Applies s and a changed in the "Rechenweg" dialog.
    func applyFacts(s newS: String, a newA: String) {
        guard newS != s || newA != a else { return }
        s = newS; a = newA
        let wv = BigUInt(w) ?? 1, sv = BigUInt(s) ?? 0, av = BigUInt(a) ?? 0
        let sp = av * wv + sv
        sPrime = sp.description
        for i in 0..<n { pw[i] = (sp % (BigUInt(ids[i]) ?? 1)).description }
    }

    /// "+ / -" (OnBnClickedSecretsharingAddN).
    func toggleKey(_ i: Int) { rek[i] = rek[i].isEmpty ? pw[i] : "" }

    /// "Geheimnis rekonstruieren" (OnBnClickedSecretsharingSolve).
    func reconstruct() {
        log += "----- Rekonstruktion beginnt -----\n\n"
        guard !ids[0].isEmpty else { return }
        let primesAll = (0..<n).map { BigUInt(ids[$0]) ?? 1 }
        var minKv = BigUInt(1)
        for i in 0..<k { minKv *= primesAll[i] }
        var used: [Int] = []
        for i in 0..<n where !rek[i].isEmpty { used.append(i) }
        if used.isEmpty {
            CRTUtil.message("Bitte geben Sie in der Gruppierung 'Rekonstruktion des Geheimnisses' mindestens \(k) richtige Schlüssel ein!")
            log += "Kein Schlüssel angegeben.\n\n----- Rekonstruktion gescheitert -----\n\n"
            return
        }
        safeState = used.count
        CRTUtil.message("Die Schlüssel werden zusammengefügt.\n\nNachdem Sie OK klicken, bekommen Sie das Ergebnis (Geheimnis) angezeigt.")
        log += "Benutze Passwörter zu den \(used.count) Kennungen  " + used.map { " \($0 + 1)" }.joined(separator: ",") + "\n\n"
        let mods = used.map { primesAll[$0] }
        let shares = used.map { BigUInt(rek[$0]) ?? 0 }
        var M = BigUInt(1)
        for m in mods { M *= m }
        log += "M wird nun aus den gegebenen Kennungen rekonstruiert:\n\(M)\n\n"
        let wv = BigUInt(w) ?? 1, sv = BigUInt(s) ?? 0
        if M >= minKv {
            let sp = ChineseRemainder.solve(remainders: shares, moduli: mods)?.solution ?? 0
            log += "Es wurden ausreichend viele Passwörter eingegeben. s' wird errechnet:\n\(sp)\n\n"
            if sp % wv == sv {
                log += "Überprüfung (s' mod w = s) wird ausgeführt-.......................Erfolgreich!\n\n"
                safeState = 100
                CRTUtil.message("Folgendes Geheimnis wurde rekonstruiert:\n\(sv)")
                log += "Das folgende Geheimnis konnte rekonstruiert werden:\n\(sv)\n\n----- Rekonstruktion erfolgreich abgeschlossen -----"
            } else {
                log += "Überprüfung (s' mod w = s) wird ausgeführt-.......................NICHT Erfolgreich!\n\n\n"
                safeState = -1
                CRTUtil.message("Sie haben \(used.count) Schlüssel eingegeben.\nDas entspricht der Mindestanzahl, aber es sind nicht alle Schlüssel korrekt.\n")
                log += "Mindestens ein Passwort war falsch.\n\n----- Rekonstruktion gescheitert -----\n\n"
            }
        } else {
            safeState = -1
            var missing = k - used.count
            var remaining = BigUInt(1)
            for i in 0..<n where missing > 0 && rek[i].isEmpty { remaining *= primesAll[i]; missing -= 1 }
            CRTUtil.message("Sie haben \(used.count) Schlüssel eingegeben. Es werden aber mindestens \(k) richtige Schlüssel für eine eindeutige \nBerechnung benötigt. Mit diesen Schlüsseln bleiben \(remaining) Möglichkeiten offen.")
            log += "Es wurden zu wenige Schlüssel benutzt.\n Mit diesen Schlüsseln bleiben \(remaining) Möglichkeiten offen.\n\n----- Rekonstruktion gescheitert -----\n\n"
        }
    }
}

/// CT1 "Secret-Sharing mittels CRT" main dialog.
struct CT1CRTSecretSharingDialog: View {
    @StateObject private var model = CRTSSModel()
    @StateObject private var win = CT1WindowRef()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secret-Sharing erlaubt es, ein Geheimnis so auf n Schlüssel zu verteilen, dass das ursprüngliche Geheimnis wieder rekonstruiert werden kann, wenn später eine beliebige Teilmenge von k<n Schlüsselinhabern zusammenkommt.")
                    Text("Um das Geheimnis erzeugen und verteilen zu lassen, klicken Sie auf 'Berechnen'. Über einen Klick auf 'Optionen' können Sie den Wertebereich, aus dem die Schlüssel erzeugt werden, und die Anzahl der Parteien verändern.")
                    Text("Wenn Sie danach in der unteren Gruppierung \"Rekonstruktion...\" über die linken Buttons die Mindestanzahl an Schlüsseln zur Verfügung stellen, können Sie daraus durch einen Klick auf 'Geheimnis rekonstruieren' das Geheimnis rekonstruieren.")
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            CRTGroup(title: "Konstruktion und Verteilung des Geheimnisses auf n = \(model.n) Schlüssel") {
                HStack(alignment: .top, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                        GridRow { Text("Kennung (= Primzahl)"); Text("Passwort (= Schlüssel)") }
                        ForEach(0..<7, id: \.self) { i in
                            GridRow {
                                if model.manual && i < model.n {
                                    TextField("", text: Binding(get: { model.ids[i] }, set: { model.ids[i] = CRTUtil.digits($0) }))
                                        .multilineTextAlignment(.trailing).font(.system(.body, design: .monospaced))
                                } else {
                                    CRTOutputField(text: model.ids[i], alignment: .trailing).opacity(i < model.n ? 1 : 0.4)
                                }
                                CRTOutputField(text: model.pw[i], alignment: .trailing).opacity(i < model.n ? 1 : 0.4)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(" Verteilung erfolgt:")
                        Picker("", selection: Binding(get: { model.manual }, set: { model.manual = $0; model.reset() })) {
                            Text("Automatisch").tag(false); Text("Manuell").tag(true)
                        }.pickerStyle(.radioGroup).labelsHidden()
                        Button("Berechnen") { model.share() }.keyboardShortcut(.defaultAction).frame(maxWidth: .infinity)
                        Button("Optionen", action: showOptions).frame(maxWidth: .infinity)
                        Button("Rechenweg", action: showFacts).disabled(!model.computed).frame(maxWidth: .infinity)
                        Button("Zurücksetzen") { model.reset() }.disabled(!model.computed).frame(maxWidth: .infinity)
                    }.frame(width: 120)
                }
            }
            CRTGroup(title: "Rekonstruktion des Geheimnisses aus mindestens k = \(model.k) Schlüsseln") {
                Text("Wählen Sie unter den n = \(model.n) Kennungen die aus, deren Schlüssel für die Rekonstruktion genutzt werden sollen:")
                HStack(alignment: .top, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            let on = model.computed && i < model.n
                            GridRow {
                                Text("\(i + 1):").foregroundStyle(on ? .primary : .secondary)
                                Button("+ / -") { model.toggleKey(i) }.disabled(!on)
                                TextField("", text: Binding(get: { model.rek[i] }, set: { model.rek[i] = CRTUtil.digits($0) }))
                                    .multilineTextAlignment(.trailing).font(.system(.body, design: .monospaced)).disabled(!on)
                            }
                        }
                    }
                    VStack(spacing: 8) {
                        CRTSafeView(state: model.safeState).frame(maxWidth: .infinity, minHeight: 140)
                        Button("Geheimnis rekonstruieren") { model.reconstruct() }.disabled(!model.computed)
                    }.frame(width: 250)
                }
            }
            Toggle("Einführungsdialog beim nächsten Start anzeigen", isOn: Binding(get: { model.showIntro }, set: {
                model.showIntro = $0; CT1Prefs.set(CRTSSModel.prefIntro, $0)
            }))
            HStack {
                CT1HelpButton(action: .crtSecretSharing)
                Spacer()
                Button("Log-Datei", action: showLog).disabled(!model.computed)
                Spacer()
                Button("Beenden") {
                    CT1Prefs.set(CRTSSModel.prefIntro, model.showIntro)
                    win.window?.close()
                }
            }
        }
        .padding(14)
        .frame(minWidth: 700, minHeight: 760, alignment: .topLeading)
        .ct1Window(title: model.title, ref: win)
        .crtMinWindowSize(720, 790)
        .onAppear {
            guard CT1Prefs.bool(CRTSSModel.prefIntro, true) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showIntro() }
        }
    }

    private func showIntro() {
        win.sheet("Verteilte Geheimnisse: Secret-Sharing mittels CRT") { close in
            CRTSSIntroSheet(close: { show in
                CT1Prefs.set(CRTSSModel.prefIntro, show)
                model.showIntro = show
                close()
            })
        }
    }

    private func showOptions() {
        let m = model
        win.sheet("Secret-Sharing mittels CRT: Optionen festlegen") { close in
            CRTSSOptionsSheet(n: String(m.n), k: String(m.k), lower: m.manual ? "" : m.lower, upper: m.manual ? "" : m.upper,
                              manual: m.manual, close: close) { n, k, lo, hi in
                if n != m.n || k != m.k || lo != m.lower || hi != m.upper {
                    m.minK = ""; m.maxK1 = ""; m.w = ""; m.s = ""; m.a = ""; m.sPrime = ""
                    m.pw = Array(repeating: "", count: 7); m.rek = Array(repeating: "", count: 7)
                    for i in n..<7 { m.ids[i] = "" }
                    m.n = n; m.k = k; m.lower = lo; m.upper = hi
                    m.computed = false
                }
                m.log = ""
                m.safeState = nil
            }
        }
    }

    private func showFacts() {
        let m = model
        win.sheet("Secret-Sharing mittels CRT: Zwischenrechnung - Von der Kennung zum Passwort") { close in
            CRTSSFactsSheet(model: m, close: close)
        }
    }

    private func showLog() {
        let m = model
        win.sheet("Secret-Sharing mittels CRT: Log-Datei anzeigen") { close in
            CRTLogSheet(title: "Secret-Sharing mittels CRT: Log-Datei anzeigen", text: m.log, saveTitle: "SecretSharing-Log",
                        savedMessage: "Die Log-Datei wurde erfolgreich in das CrypTool-Hauptfenster geschrieben.", close: close)
        }
    }
}

/// Symbolic replacement for CT1's safe/key GIF animations.
struct CRTSafeView: View {
    var state: Int?
    var body: some View {
        VStack(spacing: 6) {
            switch state {
            case nil:
                Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(.secondary)
            case 0:
                Image(systemName: "lock.fill").font(.system(size: 48))
                Text("Geheimnis verteilt").font(.caption)
            case 100:
                Image(systemName: "lock.open.fill").font(.system(size: 48)).foregroundStyle(.green)
            case -1:
                Image(systemName: "lock.trianglebadge.exclamationmark.fill").font(.system(size: 48)).foregroundStyle(.red)
            case let c?:
                Image(systemName: "lock.fill").font(.system(size: 48))
                HStack(spacing: 2) { ForEach(0..<c, id: \.self) { _ in Image(systemName: "key.fill") } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }
}

/// IDD_CRT_SECRETSHARING_INFO
struct CRTSSIntroSheet: View {
    var close: (Bool) -> Void
    @CTState private var showAgain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mit dieser Beispiel-Implementierung kann ein Geheimnis auf maximal 7 Personen so verteilt werden, dass eine vorher festgelegte kleinere Anzahl ausreicht, das Geheimnis wieder herzustellen. Dabei ist vorher nicht festgelegt, wer später in der kleineren Teilmenge zusammenkommt.")
            Text("Vergleichen kann man dies mit einer Bank, in der 5 Personen aus dem Vorstand jeweils einen Schlüssel für den Tresor bekommen. Um sicher zu stellen, dass nicht eine Person allein Zugang zum Vermögen der Bank hat, fordert man, dass zum Beispiel immer drei der Personen ihren persönlichen Schlüsseln gleichzeitig benutzen.")
            Text("Hier ist dieses System mit Zahlen umgesetzt: Jede Person ist durch eine Kennung identifiziert und hat ein persönliches Passwort, welches nur in Verbindung mit ihrer Kennung gültig ist.")
            Text("Sie können sich jederzeit mit F1 Hilfe zur Bedienung des Dialogs und zur Erläuterung des Verfahrens anzeigen lassen.")
            HStack { Spacer(); Button("OK") { close(showAgain) }.keyboardShortcut(.defaultAction); Spacer() }
            Toggle("Diesen Dialog beim nächsten Start wieder anzeigen", isOn: $showAgain)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 400)
    }
}

/// IDD_CRT_SECRETSHARING_OPTIONS
struct CRTSSOptionsSheet: View {
    @CTState var n: String
    @CTState var k: String
    @CTState var lower: String
    @CTState var upper: String
    var manual: Bool
    var close: () -> Void
    var apply: (Int, Int, String, String) -> Void

    init(n: String, k: String, lower: String, upper: String, manual: Bool, close: @escaping () -> Void,
         apply: @escaping (Int, Int, String, String) -> Void) {
        _n = CTState(initialValue: n); _k = CTState(initialValue: k)
        _lower = CTState(initialValue: lower); _upper = CTState(initialValue: upper)
        self.manual = manual; self.close = close; self.apply = apply
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CRTGroup(title: "Notwendige Angaben zum Generieren der n Schlüssel") {
                HStack {
                    Text("Anzahl Parteien (n):")
                    TextField("", text: Binding(get: { n }, set: { n = CRTUtil.digits($0) })).frame(width: 40)
                    Text("Benötigte Parteien (k):")
                    TextField("", text: Binding(get: { k }, set: { k = CRTUtil.digits($0) })).frame(width: 40)
                }
                HStack {
                    Text("Geben Sie ein geschlossenes Intervall für die zu erzeugenden Primzahl-Kennungen vor:")
                        .fixedSize(horizontal: false, vertical: true).frame(width: 220, alignment: .leading)
                    TextField("", text: $lower).frame(width: 70)
                    Text("-")
                    TextField("", text: $upper).frame(width: 70)
                }.disabled(manual)
            }
            VStack {
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 560, height: 130)
    }

    private func ok() {
        let nn = Int(n) ?? 0, kk = Int(k) ?? 0
        if nn == kk {
            CRTUtil.message("Bitte wählen Sie k<n (hier: k<\(nn)).\n\nSind k und n bei diesem speziellen Secret-Sharing-Verfahren identisch, dann gleicht das Geheimnis dem Passwort des ersten Teilnehmers.")
            return
        }
        guard nn >= 2, kk <= nn, kk >= 2, nn <= 7 else {
            var msg = ""
            if nn < 2 { msg += "Sie haben für die Anzahl der Parteien \(nn) eingegeben.\nBitte geben Sie für die Anzahl der Parteien mindestens 2 Parteien ein.\n" }
            if nn > 7 { msg += "Sie haben für die Anzahl der Parteien \(nn) eingegeben.\nBitte geben Sie für die Anzahl der Parteien maximal 7 Parteien ein.\n" }
            if kk > nn { msg += "Sie haben für die benötigten Parteien \(kk) eingegeben.\nDie benötigten Parteien dürfen aber nicht größer als die Anzahl der Parteien sein.\n" }
            if kk < 2 && kk > nn { msg += "Bitte geben Sie für die benötigten Parteien mindestens 2 Parteien ein.\n" }
            if kk < 2 && kk <= nn { msg += "Sie haben für die benötigten Parteien \(kk) eingegeben.\nBitte geben Sie für die benötigten Parteien mindestens 2 Parteien ein.\n" }
            CRTUtil.message(msg)
            return
        }
        var lo = lower, hi = upper
        if manual { lo = "2^108"; hi = "2^109" }
        if lo.trimmingCharacters(in: .whitespaces).isEmpty || hi.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Geben Sie Ober- und Untergrenze ein!"); return
        }
        let inputFalse = "In diesem Feld wird eine Zahl oder ein Ausdruck erwartet,\naus dem sich ein Zahlenwert berechnen lässt.\nBitte geben Sie einen gültigen Ausdruck ein!\n\nBeispiele: 123, 2^15+1, (2^17-5)^2."
        guard let x = CRTUtil.formula(lo), let y = CRTUtil.formula(hi) else { CRTUtil.message(inputFalse); return }
        if y.isZero || y.description.count > 33 || (lo != "0" && (x.isZero || x.description.count > 33)) {
            CRTUtil.message(CRTSSModel.generatePrimeMsg); return
        }
        if x > y { Alerts.error("Die Untergrenze darf nicht größer als die Obergrenze sein!"); return }
        apply(nn, kk, lo, hi)
        close()
    }
}

/// IDD_CRT_SECRETSHARING_FACTS ("Rechenweg").
struct CRTSSFactsSheet: View {
    @ObservedObject var model: CRTSSModel
    var close: () -> Void
    @CTState private var s = ""
    @CTState private var a = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1. Produkt der k = \(model.k) kleinsten Primzahlen (min[k]):")
            CRTOutputField(text: model.minK, multiline: true, minHeight: 44)
            Text("2. Produkt der (k-1) = \(model.k - 1) größten Primzahlen (max[k-1]):")
            CRTOutputField(text: model.maxK1, multiline: true, minHeight: 44)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("3. Quotient der beiden obigen Zahlen (w):")
                    CRTOutputField(text: model.w)
                }
                VStack(alignment: .leading) {
                    Text("4. Geheimnis (s) ist eine Zufallszahl zwischen 0 und w:")
                    TextField("", text: Binding(get: { s }, set: { s = CRTUtil.digits($0) })).font(.system(.body, design: .monospaced))
                }
            }
            Text("5. Multiplikator (a) mit 0 <= a <= (min[k] / w):")
            TextField("", text: Binding(get: { a }, set: { a = CRTUtil.digits($0) })).font(.system(.body, design: .monospaced))
            Text("6. Die Zahl (s' = a*w+s) ist Basis für die Ermittlung der Passwörter: ")
            CRTOutputField(text: model.sPrime, multiline: true, minHeight: 44)
            HStack {
                Text("7. Passwort_i wird nun durch (s' mod Kennung_i) ermittelt.")
                Spacer()
                Button("Log-Datei") {
                    let text = model.log
                    WindowPresenter.sheet(on: NSApp.keyWindow, title: "Secret-Sharing mittels CRT: Log-Datei anzeigen") { c in
                        CRTLogSheet(title: "Secret-Sharing mittels CRT: Log-Datei anzeigen", text: text, saveTitle: "SecretSharing-Log",
                                    savedMessage: "Die Log-Datei wurde erfolgreich in das CrypTool-Hauptfenster geschrieben.", close: c)
                    }
                }
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 640)
        .onAppear { s = model.s; a = model.a }
    }

    private func ok() {
        let wv = BigUInt(model.w) ?? 1, mk = BigUInt(model.minK) ?? 0
        guard !s.isEmpty, !a.isEmpty, let sv = BigUInt(s), let av = BigUInt(a), sv <= wv, !wv.isZero, av <= mk / wv else {
            CRTUtil.message("Bitte beachten Sie die Nebenbedingungen."); return
        }
        model.applyFacts(s: s, a: a)
        close()
    }
}
