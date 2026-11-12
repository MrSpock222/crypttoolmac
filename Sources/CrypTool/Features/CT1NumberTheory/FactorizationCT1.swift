import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// CT1 "Faktorisieren einer Zahl" (IDD_FACTORISATION_DEMO), "Details zur Faktorisierung"
// (IDD_FACTORISATION_LIST) and the per-algorithm progress dialog (IDD_PROGRESS_FACTORISATION).

/// ceil(log2(n)) as CT1's `BitLength()` (0 for n <= 1).
func ntCeilLog2(_ n: BigUInt) -> Int {
    if n <= 1 { return 0 }
    let b = n.bitLength
    return (n - 1).bitLength < b ? b - 1 : b
}

@MainActor
final class FactorizationCT1Model: ObservableObject {
    struct Factor: Equatable { var value: BigUInt; var exponent: Int; var isPrime: Bool }
    struct Detail: Identifiable {
        let id = UUID()
        var number: String, factor1: String, factor2: String, method: String, time: String
        var primeMask: Int, bits1: Int, bits2: Int
    }
    /// CT1 checkbox order: Brute-Force, Brent, Pollard, Williams, Lenstra, Quadratisches Sieb.
    static let names = ["Brute-Force", "Brent", "Pollard", "Williams", "Lenstra", "Quadratisches Sieb"]
    static let methods: [FactorizationMethod?] = [nil, .pollardRhoBrent, .pollardPMinus1, .williamsPPlus1, .lenstraECM, .quadraticSieve]

    @Published var input = ""
    @Published var enabled = [true, true, true, true, true, true]
    @Published var factors: [Factor] = []
    @Published var lastMethod = ""
    @Published var timeText = ""
    @Published var details: [Detail] = []
    @Published var running = false
    @Published var finished = false
    private var totalDuration: Double = 0
    private var abortFullRun = false

    // progress dialog state
    struct MethodState: Identifiable { let id: Int; var name: String; var status: String; var token: CancellationToken; var done: Bool }
    @Published var methodStates: [MethodState] = []
    @Published var progressNumber = ""
    let globalToken = CancellationToken()

    /// Called when the user edits the input (CT1 `InitialiseFactorList`).
    func reset() {
        factors = []; lastMethod = ""; timeText = ""; details = []; totalDuration = 0; finished = false
    }

    var hasComposite: Bool { factors.isEmpty || factors.contains { !$0.isPrime } }

    /// First composite factor (CT1 `Search_First_Composite_Factor`), nil if fully factorised.
    private func nextComposite() -> BigUInt?? {
        if factors.isEmpty { return .some(nil) }
        if let f = factors.first(where: { !$0.isPrime }) { return .some(f.value) }
        return .none
    }

    /// Product representation "z1^a1 * z2^a2 * …" (composite factors red).
    var factorisationText: String {
        factors.map { $0.value.description + ($0.exponent > 1 ? "^\($0.exponent)" : "") }.joined(separator: " * ")
    }

    var factorisationAttributed: Text {
        var t = Text("")
        for (i, f) in factors.enumerated() {
            var part = Text(f.value.description + (f.exponent > 1 ? "^\(f.exponent)" : ""))
            if !f.isPrime { part = part.foregroundColor(.red) }
            t = t + part
            if i < factors.count - 1 { t = t + Text(" * ") }
        }
        return t
    }

    // MARK: Steps

    enum StepResult { case factorized, stop, complete }

    /// One click on "Weiter" (CT1 `OnButtonFactorisation`).
    func step(window: NSWindow?) async -> StepResult {
        let n: BigUInt
        switch nextComposite() {
        case .none:
            finished = true
            Alerts.info("Die Eingabe ist jetzt vollständig in ihre Primfaktoren zerlegt.")
            return .complete
        case .some(let v?):
            n = v
        case .some(nil):
            let t = input.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, let v = try? BigExpression.evaluate(t) else { Alerts.error(NTMessages.inputFalse); return .stop }
            if v.isNegative { Alerts.error("Die Eingabe ist keine positive ganze Zahl."); return .stop }
            if v.magnitude <= 1 { Alerts.error("Bitte geben Sie eine positive ganze Zahl größer 1 ein."); return .stop }
            if !CT1BigNumber.isAllowed(v.magnitude) { Alerts.info(NTMessages.bigNumber); return .stop }
            n = v.magnitude
        }
        if !enabled.contains(true) {
            Alerts.error("Sie müssen mindestens einen Faktorisierungsalgorithmus wählen.")
            return .stop
        }
        if Primality.isProbablePrime(n) {
            Alerts.error("Die Eingabe ist eine Primzahl.")
            return .stop
        }
        let start = Date()
        var f1: BigUInt?, f2: BigUInt?, name = ""
        var aborted = false
        if enabled[0], let p = Self.bruteForce(n) {
            f1 = p; f2 = n / p; name = "Brute Force"
        }
        if f1 == nil {
            // quadratic sieve limits (CT1: > 132 digits overflow, > 93 digits memory request)
            let digits = Double(n.bitLength) * log10(2.0)
            if enabled[5] {
                if digits > 132 {
                    Alerts.error("Das Quadratische Sieb kann nicht ausgeführt werden und wird deaktiviert (Speicherüberlauf).")
                    enabled[5] = false
                } else if digits > 93 {
                    let a = NSAlert()
                    a.messageText = "CrypTool"
                    a.informativeText = "Das Quadratische Sieb benötigt mehr als 128 MB Speicher.\nWir empfehlen diese Methode zu deaktivieren.\n\nMöchten Sie das Quadratische Sieb deaktivieren?"
                    a.addButton(withTitle: "Ja"); a.addButton(withTitle: "Nein")
                    if a.runModal() == .alertFirstButtonReturn { enabled[5] = false }
                }
            }
            let started = (1..<6).filter { enabled[$0] }
            if !started.isEmpty {
                let r = await runParallel(n, indices: started, window: window)
                if let (idx, f) = r.found { f1 = f; f2 = n / f; name = Self.names[idx] }
                aborted = r.aborted
            }
            if f1 == nil {
                if aborted {
                    Alerts.error("Die Faktorisierung wurde vorzeitig beendet.\nDie jetzige Zerlegung enthält noch mindestens einen zusammengesetzten Faktor.")
                } else if enabled[0] && !enabled[1...].contains(true) {
                    Alerts.error("Diese Zahl konnte mit dem Brute-Force-Verfahren nicht zerlegt werden. Das Brute-Force-Verfahren ist hier so implementiert, dass es nur Faktoren kleiner 10000 findet.")
                } else {
                    Alerts.error("Die jetzige Zerlegung enthält noch mindestens einen zusammengesetzten Faktor.\nDieser Faktor konnte mit den von Ihnen ausgewählten Algorithmen nicht zerlegt werden.\nVersuchen Sie bitte ein anderes Verfahren.")
                }
            }
        }
        let duration = Date().timeIntervalSince(start)
        totalDuration += duration
        let stepTime = ntCT1Time(duration)
        if let f1, let f2 {
            expand(n, f1, f2)
            lastMethod = name
            let p1 = Primality.isProbablePrime(f1), p2 = Primality.isProbablePrime(f2)
            details.append(Detail(number: n.description, factor1: f1.description, factor2: f2.description, method: name, time: stepTime,
                                  primeMask: (p1 ? 1 : 0) + (p2 ? 2 : 0), bits1: ntCeilLog2(f1), bits2: ntCeilLog2(f2)))
        } else {
            details.append(Detail(number: n.description, factor1: "", factor2: "", method: aborted ? "abgebrochen" : "ohne Erfolg",
                                  time: stepTime, primeMask: 0, bits1: 0, bits2: 0))
        }
        let count = factors.reduce(0) { $0 + $1.exponent }
        timeText = "\(count) Faktoren gefunden in \(ntCT1Time(totalDuration))"
        return f1 != nil ? .factorized : .stop
    }

    /// "Vollständig faktorisieren": repeats "Weiter" until done or aborted.
    func factorizeCompletely(window: NSWindow?) async {
        running = true
        defer { running = false }
        while true {
            let r = await step(window: window)
            if r != .factorized { return }
        }
    }

    func singleStep(window: NSWindow?) async {
        running = true
        defer { running = false }
        _ = await step(window: window)
    }

    /// CT1 Brute-Force: smallest prime factor < 10000 (LIMIT1).
    static func bruteForce(_ n: BigUInt) -> BigUInt? {
        if n.isEven { return 2 }
        for p in Primality.sieve(upTo: 9999) where p > 2 {
            if n.remainder(dividingBy: UInt64(p)) == 0 { return BigUInt(p) == n ? nil : BigUInt(p) }
            if BigUInt(p * p) > n { return nil }
        }
        return nil
    }

    /// Runs the selected algorithms in parallel; the first one finding a factor wins.
    private func runParallel(_ n: BigUInt, indices: [Int], window: NSWindow?) async -> (found: (Int, BigUInt)?, aborted: Bool) {
        let global = CancellationToken()
        methodStates = indices.map { MethodState(id: $0, name: Self.names[$0], status: "läuft …", token: CancellationToken(), done: false) }
        let s = n.description
        progressNumber = s.count > 21 ? String(s.prefix(9)) + "..." + String(s.suffix(9)) : s
        var globalCancelled = false
        var sheetClose: (() -> Void)?
        WindowPresenter.sheet(on: window, title: "Faktorisierungstimer") { close in
            sheetClose = close
            return FactorizationProgressSheet(model: self) {
                globalCancelled = true
                global.cancel()
                for m in self.methodStates { m.token.cancel() }
            }
        }
        let start = Date()
        let timer = Task { @MainActor in
            while !Task.isCancelled {
                let el = Int(Date().timeIntervalSince(start))
                for i in methodStates.indices where !methodStates[i].done {
                    methodStates[i].status = "läuft … \(el) s"
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        let jobs = methodStates.map { ($0.id, Self.methods[$0.id]!, $0.token) }
        let race = FactorizationRace(remaining: jobs.count)
        // first factor wins; the remaining searches are cancelled and finish in the background
        let result: (Int, BigUInt)? = await withCheckedContinuation { cont in
            for (idx, method, token) in jobs {
                Task.detached(priority: .userInitiated) {
                    let combined = CancellationToken()
                    let watcher = Task.detached {
                        while !combined.isCancelled {
                            if token.isCancelled || global.isCancelled { combined.cancel(); break }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                    }
                    let f = Factorization.findFactor(of: n, method: method, timeLimit: .infinity, cancel: combined)
                    combined.cancel()
                    _ = await watcher.value
                    await MainActor.run {
                        if let i = self.methodStates.firstIndex(where: { $0.id == idx }) {
                            self.methodStates[i].done = true
                            self.methodStates[i].status = f != nil ? "Faktor gefunden"
                                : (self.methodStates[i].token.isCancelled || global.isCancelled ? "abgebrochen" : "ohne Erfolg")
                        }
                        race.remaining -= 1
                        if race.resumed { return }
                        if let f {
                            race.resumed = true
                            global.cancel()
                            cont.resume(returning: (idx, f))
                        } else if race.remaining == 0 {
                            race.resumed = true
                            cont.resume(returning: nil)
                        }
                    }
                }
            }
        }
        timer.cancel()
        sheetClose?()
        return (result, result == nil && globalCancelled)
    }

    /// CT1 `expandFactorisation`: replaces the composite by its two factors (sorted, merged).
    private func expand(_ composite: BigUInt, _ f1: BigUInt, _ f2: BigUInt) {
        var exp = 1
        if let i = factors.firstIndex(where: { $0.value == composite }) {
            exp = factors[i].exponent
            factors.remove(at: i)
        }
        for f in [f1, f2] {
            if let i = factors.firstIndex(where: { $0.value == f }) {
                factors[i].exponent += exp
            } else {
                factors.append(Factor(value: f, exponent: exp, isPrime: Primality.isProbablePrime(f)))
            }
        }
        factors.sort { $0.value < $1.value }
    }

    /// Text of "Liste im Hauptfenster anzeigen".
    func detailsDocument() -> String {
        var s = "Details zur Faktorisierung der Eingabezahl\n\(input)\n\n"
        s += "Der jeweils nächste zusammengesetzte Faktor wird in zwei Faktoren zerlegt:\n\n"
        for (i, d) in details.enumerated() {
            s += "\(i + 1). "
            if !d.factor1.isEmpty {
                s += "Faktorisierte Zahl = \(d.number)\n"
                s += "Bitlänge = \(BigUInt(d.number).map(ntCeilLog2) ?? 0)\n"
                s += "Methode: \(d.method).  Zeit: \(d.time)\n"
                s += "      - Erster Faktor = \(d.factor1)\n"
                s += "        " + Self.factorInfo(prime: d.primeMask & 1 != 0, bits: d.bits1) + "\n"
                s += "      - Zweiter Faktor = \(d.factor2)\n"
                s += "        " + Self.factorInfo(prime: d.primeMask & 2 != 0, bits: d.bits2) + "\n\n"
            } else {
                s += "Faktorisierung \(d.method)\nZeit: \(d.time)\n\n\n"
            }
        }
        s += "\(timeText)\n\n"
        s += "Die Eingabezahl wurde in die folgenden Faktoren zerlegt:\n"
        s += factorisationText + "\n"
        return s
    }

    static func factorInfo(prime: Bool, bits: Int) -> String {
        prime ? "Bitlänge = \(bits), Primzahl." : "Bitlänge = \(bits), zusammengesetzte Zahl."
    }

    var documentTitle: String {
        let t = input
        let shown = t.count < 20 ? t : String(t.prefix(9)) + "..." + String(t.suffix(8))
        return "Faktorisierung der Zahl \(shown)."
    }
}

@MainActor
final class FactorizationRace {
    var remaining: Int
    var resumed = false
    init(remaining: Int) { self.remaining = remaining }
}

struct FactorizationProgressSheet: View {
    @ObservedObject var model: FactorizationCT1Model
    var cancelAll: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zu faktorisierende Zahl")
            Text(model.progressNumber).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Algorithmus").bold()
                    Text("Laufzeit").bold()
                    Text("")
                }
                ForEach(model.methodStates) { m in
                    GridRow {
                        Text(m.name)
                        Text(m.status).monospacedDigit().frame(width: 130, alignment: .trailing)
                        Button("Abbrechen") { m.token.cancel() }.disabled(m.done)
                    }
                }
            }
            HStack { Spacer(); Button("Abbrechen", action: cancelAll).keyboardShortcut(.cancelAction); Spacer() }
        }
        .padding(16)
        .frame(width: 400)
    }
}

/// CT1 "Faktorisieren einer Zahl".
struct FactorizationView: View {
    var initialNumber: String = ""
    /// RSA demo: the input is read-only (`m_inputReadOnly`).
    var readOnly = false
    /// Closes the dialog when shown as a sheet; receives the current factor list.
    var onClose: (([FactorizationCT1Model.Factor]) -> Void)? = nil

    @StateObject private var model = FactorizationCT1Model()
    @StateObject private var ref = CT1WindowRef()
    @CTState private var didInit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                GroupBox("Algorithmen zur Faktorisierung") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in
                            Toggle(FactorizationCT1Model.names[i], isOn: $model.enabled[i])
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }.frame(width: 190)
                GroupBox("Eingabe") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Geben Sie die zu faktorisierende Zahl ein:")
                        TextField("", text: $model.input).font(.system(.body, design: .monospaced))
                            .disabled(readOnly || model.running)
                        Button("Zahl aus Datei laden") {
                            if let s = CT1BigNumber.loadFromFile() { model.input = s }
                        }.disabled(readOnly || model.running)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            GroupBox("Faktorisierung (schrittweise)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Durch das Anklicken des Buttons \"Weiter\" wird initial die Zahl im Eingabefeld und dann jeweils die nächste zusammengesetzte Zahl im Feld \"Produktdarstellung\" in zwei Faktoren zerlegt.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Weiter") { Task { await model.singleStep(window: ref.window) } }
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.input.isEmpty || model.running || model.finished)
                        Spacer()
                        Button("Vollständig faktorisieren") { Task { await model.factorizeCompletely(window: ref.window) } }
                            .disabled(model.input.isEmpty || model.running || model.finished)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Faktorisierungsergebnis") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Die Faktorisierung wird in dem Format   <z1^a1 * z2^a2 * .... * zn^an>  dargestellt.\nZusammengesetzte Zahlen sind rot markiert.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Letzte Faktorisierung durch:")
                        NTReadOnlyText(text: model.lastMethod).frame(width: 150)
                        Text(model.timeText).lineLimit(1)
                        Spacer()
                    }
                    Text("Produktdarstellung der Faktorisierung:")
                    ScrollView {
                        model.factorisationAttributed
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    }
                    .frame(minHeight: 44, maxHeight: 90)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                    Button("Details", action: showDetails).disabled(model.details.isEmpty || model.running)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Spacer()
                CT1HelpButton(action: .factorization)
                Button("Schließen") { closeDialog() }.keyboardShortcut(.cancelAction).disabled(model.running)
            }
        }
        .padding(14)
        .frame(width: 640)
        .ct1Window(title: "Faktorisieren einer Zahl", ref: ref)
        .onAppear {
            if !didInit { didInit = true; if !initialNumber.isEmpty { model.input = initialNumber } }
        }
        .onChange(of: model.input) { _, v in
            let f = ntFilterFormula(v)
            if f != v { model.input = f }
            model.reset()
        }
    }

    private func closeDialog() {
        if let onClose { onClose(model.factors) } else { ref.window?.close() }
    }

    private func showDetails() {
        ref.sheet("Details zur Faktorisierung") { close in
            FactorizationDetailsView(model: model, close: close) {
                close()
                DocumentFactory.openResult(text: model.detailsDocument(), title: model.documentTitle)
                // CT1 closes the factorisation dialog as well
                closeDialog()
            }
        }
    }
}

struct FactorizationDetailsView: View {
    @ObservedObject var model: FactorizationCT1Model
    var close: () -> Void
    var showList: () -> Void
    @CTState private var selection: FactorizationCT1Model.Detail.ID?

    var body: some View {
        let sel = model.details.first { $0.id == selection }
        VStack(alignment: .leading, spacing: 8) {
            Text("Eingabe-Zahl:")
            NTReadOnlyText(text: model.input)
            Table(model.details, selection: $selection) {
                TableColumn("Faktorisierte Zahl") { Text($0.number).font(.system(.body, design: .monospaced)) }
                TableColumn("Faktor 1") { Text($0.factor1).font(.system(.body, design: .monospaced)) }
                TableColumn("Faktor 2") { Text($0.factor2).font(.system(.body, design: .monospaced)) }
                TableColumn("Methode") { Text($0.method) }
                TableColumn("Zeit") { Text($0.time) }
            }
            .frame(minHeight: 180)
            GroupBox("Informationen zur gewählten Faktorisierung (Selektieren einer Zahl durch Doppelklick auf die Zeile) ") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Faktorisierte Zahl:")
                    NTReadOnlyText(text: sel?.number ?? "")
                    HStack {
                        Text("Erster Faktor:")
                        Text(sel.map { $0.factor1.isEmpty ? "" : FactorizationCT1Model.factorInfo(prime: $0.primeMask & 1 != 0, bits: $0.bits1) } ?? "")
                    }
                    NTReadOnlyText(text: sel?.factor1 ?? "")
                    HStack {
                        Text("Zweiter Faktor:")
                        Text(sel.map { $0.factor2.isEmpty ? "" : FactorizationCT1Model.factorInfo(prime: $0.primeMask & 2 != 0, bits: $0.bits2) } ?? "")
                    }
                    NTReadOnlyText(text: sel?.factor2 ?? "")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Spacer()
                Button("Liste im Hauptfenster anzeigen", action: showList)
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 720, height: 560)
    }
}
