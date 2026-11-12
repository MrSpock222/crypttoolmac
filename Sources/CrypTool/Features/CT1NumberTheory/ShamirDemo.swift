import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// State of CT1's IDD_SECRETSHARING_SETUP (DlgSecretSharingSetup.cpp).
@MainActor
final class ShamirModel: ObservableObject {
    static let prefIntro = "shamir.showIntro"

    @Published var secret = ""
    @Published var participants = ""
    @Published var threshold = ""
    @Published var partyLimit = "30"
    @Published var primeLimit = "10000"
    @Published var polynom = ""
    @Published var modulus = ""
    @Published var generateEnabled = false
    @Published var paramsEnabled = false      // "Polynomparameter ändern"
    @Published var updateEnabled = false      // "Parameter übernehmen"
    @Published var revealEnabled = false      // "Rekonstruktion"
    @Published var locked = false             // S, n, t read-only after "Parameter übernehmen"
    @Published var rows: [(x: Int, share: BigUInt)] = []
    @Published var checked: Set<Int> = []
    @Published var showIntro = CT1Prefs.bool(ShamirModel.prefIntro, true)

    // generated parameters
    var t = 0, n = 0, s = 0, p = 0
    var coeff: [Int] = []
    var xValues: [Int] = []
    var primeFlag = false
    var coeffFlag = false

    /// Field edits (CT1 OnUpdateEdit…: digits only, no leading zeros, clears the polynomial).
    func edit(_ field: ReferenceWritableKeyPath<ShamirModel, String>, _ v: String) {
        guard !locked else { return }
        let d = CRTUtil.digitsNoLeadingZeros(v)
        guard d != self[keyPath: field] else { return }
        self[keyPath: field] = d
        polynom = ""; modulus = ""; rows = []; checked = []
        paramsEnabled = false; updateEnabled = false; revealEnabled = false
        if field == \ShamirModel.threshold && !d.isEmpty { generateEnabled = true }
    }

    func example() {
        guard !locked else { return }
        secret = "18"; participants = "10"; threshold = "4"
        polynom = ""; modulus = ""; rows = []; checked = []
        paramsEnabled = false; updateEnabled = false; revealEnabled = false
        generateEnabled = true
    }

    static func randomPrime(above lower: Int, upTo upper: Int) -> Int? {
        guard upper > lower else { return nil }
        return Primality.randomPrime(in: BigUInt(lower + 1)...BigUInt(upper), method: .millerRabin).flatMap { $0.uint64Value.map(Int.init) }
    }

    /// Random coefficients a(i) ∈ [1, p−1] and distinct public values x ∈ [1, p−1].
    func randomCoefficients(_ p: Int) -> [Int] { (0..<max(0, t - 1)).map { _ in Int.random(in: 1...(p - 1)) } }

    func polynomString() -> String {
        var f = secret
        for (i, c) in coeff.enumerated() {
            f += "+\(c)x"
            if i > 0 { f += "^\(i + 1)" }
        }
        return f
    }

    /// "Polynom generieren" (OnButtonGenerate). Returns false if the options dialog should open.
    func generate() -> Bool {
        if secret.isEmpty || participants.isEmpty || threshold.isEmpty || Int(threshold) == 0 || Int(participants) == 0 {
            CRTUtil.message("Sie haben nicht alle erforderlichen Parameter eingegeben."); return true
        }
        guard let tt = Int(threshold), let nn = Int(participants), let ss = Int(secret) else {
            CRTUtil.message("Sie haben nicht alle erforderlichen Parameter eingegeben."); return true
        }
        if tt > nn {
            CRTUtil.message("Der angegebene Schwellenwert liegt über der Teilnehmerzahl. Bitte korrigieren Sie Ihre Angaben.")
            threshold = ""; generateEnabled = false; return true
        }
        if nn > (Int(partyLimit) ?? 30) {
            CRTUtil.message("Die Anzahl der Teilnehmer liegt über der von Ihnen festgelegten Grenze.")
            threshold = ""; participants = ""; generateEnabled = false; return true
        }
        let maxPrime = Int(primeLimit) ?? 10000
        guard maxPrime >= nn, maxPrime >= ss, let prime = Self.randomPrime(above: max(nn, ss), upTo: maxPrime) else {
            CRTUtil.message("Die Obergrenze für die Primzahl p muss sowohl größer als das Geheimnis K\nals auch größer als die Teilnehmerzahl n sein.")
            return false
        }
        t = tt; n = nn; s = ss; p = prime
        primeFlag = false; coeffFlag = false
        coeff = randomCoefficients(prime)
        var xs: [Int] = []
        while xs.count < nn {
            let x = Int.random(in: 1...(prime - 1))
            if !xs.contains(x) { xs.append(x) }
        }
        xValues = xs
        polynom = polynomString()
        modulus = String(prime)
        paramsEnabled = true; updateEnabled = true; revealEnabled = false
        rows = []; checked = []
        return true
    }

    /// Result of "Polynomparameter ändern".
    func applyParameters(prime: Int, coefficients: [Int]?) {
        if prime != p { p = prime; modulus = String(prime); primeFlag = true }
        if let c = coefficients, c != coeff { coeff = c; coeffFlag = true }
        polynom = polynomString()
        rows = []; checked = []
        updateEnabled = true; revealEnabled = false
    }

    /// "Parameter übernehmen" (OnButtonUpdate).
    func update() {
        let pb = BigUInt(p)
        rows = xValues.map { x in
            let y = ShamirSecretSharing.evaluate(secret: BigUInt(s), coefficients: coeff.map { BigUInt($0) }, at: BigUInt(x), prime: pb)
            return (x, y)
        }
        checked = []
        revealEnabled = true; updateEnabled = false; locked = true
    }

    /// Reconstructed secret of the checked participants (Lagrange interpolation in GF(p)).
    func reveal() -> BigUInt {
        let sel = checked.sorted().map { ShamirSecretSharing.Share(x: BigUInt(rows[$0].x), y: rows[$0].share) }
        return ShamirSecretSharing.reconstruct(sel, prime: BigUInt(p))
    }

    /// CT1 SecretSharingLog.
    func logText(result: BigUInt) -> String {
        var l = "Protokolldatei für das Secret-Sharing-Verfahren nach Shamir\n\n"
        l += "Zunächst haben Sie die Parameter des Shamir-Schemas festgelegt. Dabei handelt es sich um das Geheimnis S, die Begrenzung der Teilnehmerzahl l = Max(n), die Teilnehmerzahl n, die Begrenzung für die Primzahl Max(p) und den Schwellenwert t.\n\n"
        l += "S: \(secret)\nl = Max(n): \(partyLimit)\nn: \(participants)\nMax(p): \(primeLimit)\nt: \(threshold)\n\n"
        l += (primeFlag ? "Sie haben eine Primzahl p festgelegt." : "Auf Basis der von Ihnen gemachten Angaben hat CrypTool zufällig eine Primzahl p bestimmt.") + "\n\n"
        l += "p: \(modulus)\n\n"
        l += (coeffFlag ? "Für ein Polynom f(x) vom Grad t-1 haben Sie die Koeffizienten bestimmt. Alle folgenden Berechnungen finden mod p statt."
                        : "Zusätzlich wurde ein Polynom f(x) vom Grad t-1 mit zufälligen Koeffizienten und dem absoluten Summanden S erzeugt. Alle folgenden Berechnungen finden mod p statt.") + "\n\n"
        l += "f(x): \(polynom)\n\n"
        l += "Für jeden Teilnehmer wurde eine zufällige Zahl x gewählt. Diese Zahl ist der öffentliche Wert des entsprechenden Teilnehmers:\n\n"
        for (i, r) in rows.enumerated() { l += "\(i + 1): \(r.x)\n" }
        l += "\nDurch Einsetzen der öffentlichen Werte x in das Polynom f(x) erhält jeder Teilnehmer seinen geheimen Wert y (Share):\n\n"
        for (i, r) in rows.enumerated() { l += "\(i + 1): \(r.share)\n" }
        l += "\nSie haben die folgenden Teilnehmer ausgewählt, um das Geheimnis wiederherzustellen:\n\n"
        let sel = checked.sorted()
        for i in sel { l += "\(i + 1), " }
        l += "\n\nDie zu diesen Teilnehmern gehörenden Wertepaare (x/y) sind:\n\n"
        for i in sel { l += "\(i + 1): \(rows[i].x) / \(rows[i].share)\n" }
        l += "\nMit Hilfe des Lagrange-Interpolationsverfahrens wurde aus diesen \(sel.count) Wertepaaren das Geheimnis S rekonstruiert:\n\n"
        l += result.description
        return l
    }
}

/// CT1 "Secret-Sharing-Demo: Aufsetzen eines Schwellenwertschemas".
struct CT1ShamirDialog: View {
    static let title = "Secret-Sharing-Demo: Aufsetzen eines Schwellenwertschemas"
    @StateObject private var model = ShamirModel()
    @StateObject private var win = CT1WindowRef()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mit dem (t, n)-Schwellenwertschema nach Shamir ist es möglich, ein Geheimnis S auf n Personen aufzuteilen. Danach sind t Personen (t <= n) in der Lage, mit ihren Teilgeheimnissen (Shares) das ursprüngliche Geheimnis wiederherzustellen.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Dazu werden ein Polynom f(x) vom Grad t-1 [also mit t-1 zufälligen Koeffizienten a(i)] und eine zufällige Primzahl p erzeugt. Jedem Teilnehmer werden dann ein zufällig gewählter, öffentlicher Wert x  und ein geheimer Wert y=f(x) [sein Share] zugewiesen.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Weitere Details erhalten Sie in der Online-Hilfe, indem Sie F1 drücken.")
            CRTGroup(title: "Geheimnis und Steuerparameter wählen (ganze Zahlen)") {
                HStack(alignment: .top) {
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        GridRow { Text("Geheimnis S mit S >= 0"); field(\.secret) }
                        GridRow { Text("Anzahl der Teilnehmer n mit n > 0"); field(\.participants) }
                        GridRow { Text("Schwellenwert (Mindestanzahl) t mit t > 0"); field(\.threshold) }
                    }
                    Spacer()
                    VStack {
                        Button("Beispielparameter setzen") { model.example() }.frame(width: 190).disabled(model.locked)
                        Button("Optionen", action: showOptions).frame(width: 190)
                    }
                }
            }
            HStack {
                Spacer().frame(width: 230)
                Button("Polynom generieren", action: generate).disabled(!model.generateEnabled || model.locked)
                Spacer()
                Button("Polynomparameter ändern", action: showParameters).disabled(!model.paramsEnabled || model.locked)
            }
            CRTGroup(title: "Parameter des Polynoms f(x) vom Grad t-1") {
                Text("Alle Operationen finden im diskreten Raum GF(p) statt.")
                HStack { Text("Polynom f(x)").frame(width: 90, alignment: .leading); CRTOutputField(text: model.polynom) }
                HStack {
                    Text("Primzahl p").frame(width: 90, alignment: .leading)
                    CRTOutputField(text: model.modulus)
                    Button("Parameter übernehmen") { model.update() }.disabled(!model.updateEnabled)
                }
            }
            Text("Aus den Parametern berechnete Werte der Teilnehmer:")
            sharesList
            Text("Bitte wählen Sie die Teilnehmer, die das Geheimnis wiederherstellen sollen, aus der Liste aus, indem Sie die entsprechenden Checkboxen ankreuzen.")
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Informationsdialog zu Beginn anzeigen", isOn: Binding(get: { model.showIntro }, set: {
                model.showIntro = $0; CT1Prefs.set(ShamirModel.prefIntro, $0)
            }))
            HStack {
                Button("Schließen") { win.window?.close() }
                CT1HelpButton(action: .shamirSecretSharing)
                Spacer()
                Button("Rekonstruktion", action: reconstruct).keyboardShortcut(.defaultAction).disabled(!model.revealEnabled)
            }
        }
        .padding(14)
        .frame(minWidth: 640, minHeight: 760, alignment: .topLeading)
        .ct1Window(title: Self.title, ref: win)
        .crtMinWindowSize(680, 790)
        .onAppear {
            guard CT1Prefs.bool(ShamirModel.prefIntro, true) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showIntro() }
        }
    }

    private func field(_ kp: ReferenceWritableKeyPath<ShamirModel, String>) -> some View {
        TextField("", text: Binding(get: { model[keyPath: kp] }, set: { model.edit(kp, $0) }))
            .frame(width: 140).disabled(model.locked)
    }

    private var sharesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(width: 24)
                Text("Teilnehmer").frame(width: 150, alignment: .leading)
                Text("Öffentlicher Wert x").frame(width: 150, alignment: .leading)
                Text("Share (geheimer Wert f(x))").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption.bold()).padding(4).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.rows.indices, id: \.self) { i in
                        HStack {
                            Toggle("", isOn: Binding(get: { model.checked.contains(i) }, set: {
                                if $0 { model.checked.insert(i) } else { model.checked.remove(i) }
                            })).labelsHidden().frame(width: 24)
                            Text("Teilnehmer \(i + 1)").frame(width: 150, alignment: .leading)
                            Text("\(model.rows[i].x)").frame(width: 150, alignment: .leading)
                            Text(model.rows[i].share.description).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .contentShape(Rectangle())
                        .onTapGesture { if model.checked.contains(i) { model.checked.remove(i) } else { model.checked.insert(i) } }
                    }
                }
            }
        }
        .frame(minHeight: 150)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }

    private func generate() {
        if !model.generate() { showOptions() }
    }

    private func showIntro() {
        win.sheet("Einleitung Secret-Sharing-Demo") { close in
            ShamirIntroSheet(close: { hide in
                CT1Prefs.set(ShamirModel.prefIntro, !hide)
                model.showIntro = !hide
                close()
            })
        }
    }

    private func showOptions() {
        let m = model
        win.sheet("Secret-Sharing: Optionen") { close in
            ShamirOptionsSheet(limit: m.partyLimit, prime: m.primeLimit, close: close) { l, p in
                m.partyLimit = l; m.primeLimit = p
            }
        }
    }

    private func showParameters() {
        let m = model
        win.sheet("Secret-Sharing: Polynomparameter anzeigen und ändern") { close in
            ShamirParameterSheet(model: m, close: close)
        }
    }

    private func reconstruct() {
        guard let t = Int(model.threshold), model.checked.count >= t else {
            CRTUtil.message("Die Anzahl der ausgewählten Teilnehmer liegt unter dem von Ihnen gesetzten Schwellenwert.")
            return
        }
        let m = model
        let result = m.reveal()
        let log = m.logText(result: result)
        let rows = m.checked.sorted().map { (i: $0, x: m.rows[$0].x, y: m.rows[$0].share) }
        win.sheet("Secret-Sharing: Rekonstruktion des Geheimnisses") { close in
            ShamirRevealSheet(rows: rows, secret: result.description, log: log, close: close)
        }
        m.locked = false
    }
}

/// IDD_SECRETSHARING_INTRO
struct ShamirIntroSheet: View {
    var close: (Bool) -> Void
    @CTState private var hide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Willkommen zur Visualisierung des Secret-Sharing-Verfahrens nach Shamir!")
            Text("Das Verfahren behandelt die folgende Problemstellung:")
            Text("Ein geheimer Wert soll unter n Personen so aufgeteilt werden, dass eine einzelne Person keinerlei Information über diesen Wert besitzt. Nur wenn sich mindestens t der n Personen zusammenschließen, gelingt die Wiederherstellung des Geheimnisses.")
            Text("Das Verfahren bezeichnet man daher als (t,n)-Schwellenwertschema.")
            Text("Beispiel:")
            Text("Das Geheimrezept für eine neue Sorte Eiscreme wird in einem Safe eingeschlossen. Damit kein Mitarbeiter der Versuchung erliegen kann, es aus dem Safe zu nehmen und für viel Geld an die Konkurrenz zu verkaufen, wird die Zahlenkombination unter den 10 Mitarbeitern der Firma aufgeteilt. Mindestens 7 Angestellte müssen ihre Teilschlüssel eingeben, um den Tresor zu öffnen und so an die Rezeptur zu gelangen.")
            Text("Die folgende interaktive Visualisierung des Verfahrens erfordert Benutzereingaben von Ihnen.")
            Text("Weitere Informationen zu diesem Dialog erhalten Sie in der Online-Hilfe, indem Sie F1 drücken.")
            HStack { Spacer(); Toggle("Diesen Dialog in Zukunft nicht mehr anzeigen.", isOn: $hide); Spacer() }
            HStack { Spacer(); Button("OK") { close(hide) }.keyboardShortcut(.defaultAction); Spacer() }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 470)
    }
}

/// IDD_SECRETSHARING_OPTIONS
struct ShamirOptionsSheet: View {
    @CTState var limit: String
    @CTState var prime: String
    var close: () -> Void
    var apply: (String, String) -> Void

    init(limit: String, prime: String, close: @escaping () -> Void, apply: @escaping (String, String) -> Void) {
        _limit = CTState(initialValue: limit); _prime = CTState(initialValue: prime)
        self.close = close; self.apply = apply
    }

    var body: some View {
        VStack(spacing: 12) {
            CRTGroup(title: "Einstellbare Parameter") {
                HStack { Text("Maximale Teilnehmerzahl [l = Max(n)]"); Spacer(); TextField("", text: Binding(get: { limit }, set: { limit = CRTUtil.digits($0) })).frame(width: 80) }
                HStack { Text("Obergrenze für p"); Spacer(); TextField("", text: Binding(get: { prime }, set: { prime = CRTUtil.digits($0) })).frame(width: 80) }
            }
            HStack {
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
                Button("OK") { apply(limit, prime); close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}

/// IDD_SECRETSHARING_PARAMETER ("Polynomparameter ändern").
struct ShamirParameterSheet: View {
    @ObservedObject var model: ShamirModel
    var close: () -> Void
    @CTState private var prime = ""
    @CTState private var coeffText = ""
    @CTState private var oldPrime = 0
    @CTState private var okEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CRTGroup(title: "Geheimnis und Steuerparameter anzeigen") {
                HStack {
                    Text("Geheimnis S:"); CRTOutputField(text: model.secret).frame(width: 70)
                    Text("Teilnehmerzahl n:"); CRTOutputField(text: model.participants).frame(width: 70)
                    Text("Schwellenwert t:"); CRTOutputField(text: model.threshold).frame(width: 70)
                }
            }
            CRTGroup(title: "Polynomparameter eingeben oder ändern") {
                Text("Alle Berechnungen eines Shamir-Schemas finden in einem endlichen Körper GF(p) statt.\np ist eine Primzahl, die sowohl größer als das Geheimnis S als auch größer als die Teilnehmerzahl n sein muss.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("Eingabe einer geeigneten Primzahl")
                        Text("[p > n, p > S, p > a(i),  i = 1, 2, ..., t-1 ]").font(.caption)
                    }
                    TextField("", text: Binding(get: { prime }, set: { prime = $0.filter { "0123456789^+-*()".contains($0) } }))
                }
                Text("Über GF(p) wird ein Polynom f(x) vom Grad t-1 gebildet: Damit können die Shares der Teilnehmer berechnet werden. Mit dem Polynom und den Shares kann später das Geheimnis rekonstruiert werden. Ein solches Polynom besitzt t-1 Koeffizienten a(i) aus GF(p).")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Eingabe der t-1 Koeffizienten (getrennt durch Kommata; z.B. 3, 6,19, sofern p>=19)")
                TextField("", text: Binding(get: { coeffText }, set: { coeffText = $0; okEnabled = true }))
            }
            HStack {
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Polynom generieren", action: generateNew).keyboardShortcut(.defaultAction)
                Spacer()
                Button("OK", action: ok).disabled(!okEnabled)
            }
        }
        .padding(14)
        .frame(width: 620)
        .onAppear {
            prime = model.modulus
            oldPrime = model.p
            coeffText = model.coeff.map(String.init).joined(separator: ",")
        }
    }

    private var currentPrime: Int? { CRTUtil.formula(prime).flatMap { $0.uint64Value }.flatMap { Int(exactly: $0) } }

    private func setCoefficients(_ p: Int) {
        coeffText = model.randomCoefficients(p).map(String.init).joined(separator: ",")
        okEnabled = true
        oldPrime = p
    }

    /// CT1 OnButtonGenerateNew.
    private func generateNew() {
        guard let tmpPrime = currentPrime else {
            Alerts.error("In diesem Feld wird eine Zahl oder ein Ausdruck erwartet,\naus dem sich ein Zahlenwert berechnen lässt.\nBitte geben Sie einen gültigen Ausdruck ein!\n\nBeispiele: 123, 2^15+1, (2^17-5)^2.")
            return
        }
        let limit = Int(model.primeLimit) ?? 10000
        let s = Int(model.secret) ?? 0, n = Int(model.participants) ?? 0
        if tmpPrime != oldPrime && tmpPrime != 0 {
            if !Primality.isProbablePrime(BigUInt(tmpPrime)) {
                CRTUtil.message("Bei der von Ihnen eingegebenen Zahl handelt es sich nicht um eine Primzahl.")
                return
            }
            if tmpPrime > limit {
                CRTUtil.message("Die Primzahl p liegt über der von Ihnen gesetzten Obergrenze \(limit).")
                return
            }
            if tmpPrime <= s || tmpPrime <= n {
                CRTUtil.message("Die von Ihnen gewählte Primzahl ist zu klein. Ihr Wert muss über dem des Geheimnisses und der Anzahl der Teilnehmer liegen.")
                prime = ""
                return
            }
            prime = String(tmpPrime)
            setCoefficients(tmpPrime)
        } else {
            guard let p = ShamirModel.randomPrime(above: max(n, s), upTo: limit) else {
                CRTUtil.message("Die Obergrenze für die Primzahl p muss sowohl größer als das Geheimnis K\nals auch größer als die Teilnehmerzahl n sein.")
                return
            }
            prime = String(p)
            setCoefficients(p)
        }
    }

    /// CT1 OnButtonClickedOk.
    private func ok() {
        let filtered = coeffText.filter { "0123456789,".contains($0) }
        let parts = filtered.split(separator: ",", omittingEmptySubsequences: true).map(String.init)
        let required = (Int(model.threshold) ?? 1) - 1
        if parts.count != required {
            CRTUtil.message("Sie benötigen exakt \(required) Koeffizienten!")
            coeffText = ""; okEnabled = false
            return
        }
        guard let p = currentPrime, p > 1 else { return }
        if !Primality.isProbablePrime(BigUInt(p)) || p <= (Int(model.secret) ?? 0) || p <= (Int(model.participants) ?? 0) {
            CRTUtil.message("Die von Ihnen gewählte Primzahl ist zu klein. Ihr Wert muss über dem des Geheimnisses und der Anzahl der Teilnehmer liegen.")
            return
        }
        let coeffs = parts.map { Int($0) ?? Int.max }
        if coeffs.contains(where: { $0 >= p }) {
            CRTUtil.message("Alle Koeffizienten müssen kleiner sein als die gewählte Primzahl.")
            coeffText = ""; okEnabled = false
            return
        }
        if p != model.p {
            // new prime: the public values must lie in GF(p) as well
            var xs: [Int] = []
            while xs.count < model.n {
                let x = Int.random(in: 1...(p - 1))
                if !xs.contains(x) { xs.append(x) }
            }
            model.xValues = xs
        }
        model.applyParameters(prime: p, coefficients: coeffs)
        close()
    }
}

/// IDD_SECRETSHARING_REVEAL
struct ShamirRevealSheet: View {
    var rows: [(i: Int, x: Int, y: BigUInt)]
    var secret: String
    var log: String
    var close: () -> Void
    @CTState private var logShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ausgewählte Teilnehmer")
            VStack(spacing: 0) {
                HStack {
                    Text("Teilnehmer").frame(width: 150, alignment: .leading)
                    Text("Öffentlicher Wert x").frame(width: 150, alignment: .leading)
                    Text("Share (geheimer Wert f(x))").frame(maxWidth: .infinity, alignment: .leading)
                }.font(.caption.bold()).padding(4).background(Color(nsColor: .controlBackgroundColor))
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { r in
                            HStack {
                                Text("Teilnehmer \(rows[r].i + 1)").frame(width: 150, alignment: .leading)
                                Text("\(rows[r].x)").frame(width: 150, alignment: .leading)
                                Text(rows[r].y.description).frame(maxWidth: .infinity, alignment: .leading)
                            }.font(.system(.body, design: .monospaced)).padding(.horizontal, 4).padding(.vertical, 1)
                        }
                    }
                }
            }
            .frame(height: 170)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
            CRTGroup(title: "Berechnung des Geheimnisses") {
                HStack {
                    Text("Das von den ausgewählten Teilnehmern rekonstruierte Geheimnis lautet")
                    CRTOutputField(text: secret).frame(width: 140)
                }
            }
            HStack {
                Button("Logdatei anzeigen") {
                    DocumentFactory.openResult(text: log, title: "Secret-Sharing (Shamir): Logdatei")
                    CRTUtil.message("Der Protokollverlauf mit Ihren Zahlen wurde erfolgreich in ein Fenster im CrypTool-Hauptprogramm geschrieben.")
                    logShown = true
                }.disabled(logShown)
                Spacer()
                Button("OK", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 600)
    }
}
