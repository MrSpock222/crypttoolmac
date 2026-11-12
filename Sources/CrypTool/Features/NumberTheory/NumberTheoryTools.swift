import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// Parses a number field that may contain an expression such as 2^127-1.
func parseBigNumber(_ s: String) -> BigUInt? {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return nil }
    if let v = BigUInt(t) { return v }
    if let v = try? BigExpression.evaluate(t), !v.isNegative { return v.magnitude }
    return nil
}

/// CT1 messages used by several number-theory dialogs.
enum NTMessages {
    static let inputFalse = "In diesem Feld wird eine Zahl oder ein Ausdruck erwartet,\naus dem sich ein Zahlenwert berechnen lässt.\nBitte geben Sie einen gültigen Ausdruck ein!\n\nBeispiele: 123, 2^15+1, (2^17-5)^2."
    static let bigNumber = CT1BigNumber.message
}

/// Evaluates a CT1 number field (formula allowed): nil + CT1 message on error.
func ntEvaluate(_ s: String) -> (value: BigUInt?, error: String?) {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty, let v = try? BigExpression.evaluate(t), !v.isNegative else { return (nil, NTMessages.inputFalse) }
    if !CT1BigNumber.isAllowed(v.magnitude) { return (nil, NTMessages.bigNumber) }
    return (v.magnitude, nil)
}

/// CT1 `removeInvalidCharactersFromFormula`: keeps digits and formula operators.
func ntFilterFormula(_ s: String) -> String {
    let allowed = Set("0123456789+-*/^()% ")
    return String(s.filter { allowed.contains($0) })
}

/// Probabilistic test as used by CT1's GeneratePrimes (trial division first, `rounds` rounds).
func ntProbablePrime(_ n: BigUInt, algorithm: Int, rounds: Int = 100, cancel: CancellationToken? = nil) -> Bool {
    if let v = n.uint64Value { return Primality.isPrime64(v) }
    switch algorithm {
    case 1: return Primality.solovayStrassen(n, rounds: rounds, cancel: cancel)
    case 2: return Primality.fermat(n, rounds: rounds, cancel: cancel)
    default: return Primality.millerRabin(n, rounds: rounds, cancel: cancel)
    }
}

// MARK: - Prime test (CT1 IDD_PRIME_TEST)

struct PrimeTestView: View {
    var initialNumber: String = ""
    @StateObject private var ref = CT1WindowRef()
    @CTState private var input = ""
    /// CT1 radio order: 0 Miller-Rabin, 1 Fermat, 2 Solovay-Strassen, 3 AKS.
    @CTState private var algo = 0
    @CTState private var result = ""
    @CTState private var isPrime: Bool?
    @CTState private var canFactor = false
    @CTState private var busy = false
    @CTState private var token = CancellationToken()
    @CTState private var didInit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Es gibt viele Verfahren, um zu testen, ob eine Zahl eine Primzahl ist.")
                    Text("Am häufigsten werden die probabilistischen Verfahren verwendet: Sie sind sehr schnell, geben aber nur mit einer bestimmten (einstellbar kleinen) Wahrscheinlichkeit an, ob die Zahl prim ist.")
                    Text("Daneben gibt es noch deterministische Verfahren: Wenn diese ein Ergebnis liefern, ist es mit 100% Wahrscheinlichkeit korrekt (aus mathematischer Sicht).")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Algorithmen zum Primzahltest") {
                Picker("", selection: $algo) {
                    Text("Miller-Rabin-Test").tag(0)
                    Text("Fermat-Test").tag(1)
                    Text("Solovay-Strassen-Test").tag(2)
                    Text("AKS-Test (deterministisches Verfahren)").tag(3)
                }
                .pickerStyle(.radioGroup).labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Primzahltest") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button("Zahl aus Datei laden") {
                            if let s = CT1BigNumber.loadFromFile() { input = s }
                        }.disabled(busy)
                    }
                    HStack {
                        Text("Zu testende Zahl oder Formel:").frame(width: 190, alignment: .leading)
                        TextField("", text: $input).font(.system(.body, design: .monospaced))
                            .onSubmit(test)
                    }
                    HStack {
                        Text("Ergebnis:").frame(width: 190, alignment: .leading)
                        Image(systemName: isPrime == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isPrime == true ? .green : .red)
                            .opacity(isPrime == nil ? 0 : 1)
                        NTReadOnlyText(text: result)
                    }
                }.padding(4)
            }
            HStack {
                Button("Zahl testen", action: test).keyboardShortcut(.defaultAction).disabled(busy)
                Button("Zahl faktorisieren", action: jumpToFactorization).disabled(!canFactor || busy)
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                CT1HelpButton(action: .primeTest)
                Button("Abbrechen") {
                    token.cancel()
                    ref.window?.close()
                }
            }
        }
        .padding(14)
        .frame(minWidth: 560, idealWidth: 600)
        .ct1Window(title: "Primzahltest", ref: ref)
        .onAppear {
            if !didInit { didInit = true; if !initialNumber.isEmpty { input = initialNumber } }
        }
        .onChange(of: input) { _, v in
            let f = ntFilterFormula(v)
            if f != v { input = f }
            clearResult()
        }
        .onChange(of: algo) { _, _ in clearResult() }
    }

    private func clearResult() {
        result = ""; isPrime = nil; canFactor = false
    }

    private func test() {
        clearResult()
        if input.trimmingCharacters(in: .whitespaces).isEmpty {
            Alerts.error("Geben Sie eine zu testende Zahl ein!")
            return
        }
        let (value, err) = ntEvaluate(input)
        guard let n = value else { Alerts.error(err ?? NTMessages.inputFalse); return }
        let t = CancellationToken(); token = t
        let a = algo
        let numberText = n.description
        busy = true
        if a == 3 {
            runAKS(n, numberText: numberText, token: t)
            return
        }
        Task.detached(priority: .userInitiated) {
            let p: Bool
            switch a {
            case 0: p = Primality.millerRabin(n, rounds: 100, cancel: t)
            case 1: p = Primality.fermat(n, rounds: 100, cancel: t)
            // CT1: Solovay-Strassen with accuracy "99.999999999999999" % = 57 rounds
            default: p = Primality.solovayStrassen(n, rounds: 57, cancel: t)
            }
            await MainActor.run {
                busy = false
                if t.isCancelled { return }
                show(prime: p, probable: true, numberText)
            }
        }
    }

    private func show(prime: Bool, probable: Bool, _ numberText: String) {
        isPrime = prime
        if prime {
            result = (probable ? "Die Zahl ist wahrscheinlich eine Primzahl: " : "Die Zahl ist eine Primzahl: ") + numberText
        } else {
            result = "Die Zahl ist keine Primzahl: " + numberText
            canFactor = true
        }
    }

    private func runAKS(_ n: BigUInt, numberText: String, token: CancellationToken) {
        let progress = NTProgressModel()
        let bits = n.bitLength
        progress.format = { p, rest in "\(bits) Bit AKS-Test zu \(p)% erledigt.\nRestzeit: \(rest)" }
        var shown = false
        // show the progress dialog only for runs that are not instantaneous
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if busy && !shown && !progress.token.isCancelled && !token.isCancelled {
                shown = true
                progress.show(on: ref.window, title: "AKS Test")
            }
        }
        let combined = CancellationToken()
        Task.detached(priority: .userInitiated) {
            var last = Date.distantPast
            let outcome = Primality.aksCT1(n, cancel: combined, progress: { f in
                if progress.token.isCancelled || token.isCancelled { combined.cancel() }
                let now = Date()
                if now.timeIntervalSince(last) > 0.2 {
                    last = now
                    Task { @MainActor in progress.update(f) }
                }
            })
            await MainActor.run {
                busy = false
                progress.dismiss()
                switch outcome {
                case .prime: show(prime: true, probable: false, numberText)
                case .composite: show(prime: false, probable: false, numberText)
                case .cancelled:
                    if !token.isCancelled { result = "Test abgebrochen!"; isPrime = nil }
                case .tooLarge(let bytes):
                    result = "Fehler bei der Verarbeitung!"; isPrime = nil
                    Alerts.error(String(format: "Der AKS-Test ist für diese Zahl nicht durchführbar: Die Polynomrechnung würde ca. %.0f MB Arbeitsspeicher benötigen.", bytes / 1_048_576))
                }
            }
        }
        // poll the cancel button of the progress dialog (the AKS loop only checks `combined`)
        Task { @MainActor in
            while busy {
                if progress.token.isCancelled || token.isCancelled { combined.cancel() }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func jumpToFactorization() {
        guard let n = ntEvaluate(input).value else { return }
        let s = n.description
        WindowPresenter.tool(title: "Faktorisieren einer Zahl", size: CGSize(width: 660, height: 640)) {
            FactorizationView(initialNumber: s)
        }
    }
}

// MARK: - Prime generation (CT1 IDD_PRIMES_GENERATOR_DEMO)

struct PrimeGenerationView: View {
    /// Set when opened from the RSA demo: shows "Primzahlen übernehmen".
    var onUse: ((BigUInt, BigUInt) -> Void)? = nil
    /// Closes the dialog when it is shown as a sheet.
    var close: (() -> Void)? = nil

    @StateObject private var ref = CT1WindowRef()
    @CTState private var lowerP = "2^7"
    @CTState private var upperP = "2^8"
    @CTState private var lowerQ = "2^7"
    @CTState private var upperQ = "2^8"
    @CTState private var resultP = "0"
    @CTState private var resultQ = "0"
    /// 0 Miller-Rabin, 1 Solovay-Strassen, 2 Fermat (CT1 order).
    @CTState private var algo = 0
    /// 0 "Unabhängig voneinander", 1 "Beide gleich".
    @CTState private var sameRange = 0
    /// 0 two primes, 1 all primes.
    @CTState private var countMode = 0
    @CTState private var separator = CT1Prefs.string("PrimeNumberGeneration.Separator", " ")
    @CTState private var busy = false
    @CTState private var accepted = false

    private var allowAll: Bool { onUse == nil }
    private var canAccept: Bool { !resultP.isEmpty && resultP != "0" && !resultQ.isEmpty && resultQ != "0" && accepted }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                Text("Primzahlen spielen in der modernen Kryptographie eine wichtige Rolle. Hier können Sie sich Primzahlen aus einem vorzugebenden Wertebereich [Untergrenze, Obergrenze] erzeugen.")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Anzahl der zu generierenden Primzahlen") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $countMode) {
                        Text("Zwei Primzahlen zufällig aus dem Wertebereich (den Wertebereichen) generieren").tag(0)
                        Text("Alle Primzahlen in dem (für p vorgegebenen) Wertebereich generieren").tag(1)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .disabled(!allowAll)
                    HStack {
                        Text("Trennzeichen für die Ausgabe der Primzahlen:")
                        TextField("", text: $separator).frame(width: 40).multilineTextAlignment(.center)
                            .disabled(countMode == 0)
                    }.padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack(alignment: .top, spacing: 12) {
                GroupBox("Algorithmen zur Generierung") {
                    Picker("", selection: $algo) {
                        Text("Miller-Rabin-Test").tag(0)
                        Text("Solovay-Strassen-Test").tag(1)
                        Text("Fermat-Test").tag(2)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                GroupBox("Wertebereich der Primzahlen p und q") {
                    Picker("", selection: $sameRange) {
                        Text("Unabhängig voneinander einzugeben").tag(0)
                        Text("Beide gleich (nur einen eingeben)").tag(1)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .disabled(countMode == 1)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                GroupBox("Primzahl p") {
                    rangeFields(lower: $lowerP, upper: $upperP, result: resultP, disabled: false, resultDisabled: countMode == 1)
                }
                GroupBox("Primzahl q") {
                    rangeFields(lower: $lowerQ, upper: $upperQ, result: resultQ,
                                disabled: countMode == 1 || sameRange == 1, resultDisabled: countMode == 1)
                }
            }
            HStack {
                Button("Primzahlen generieren", action: generate).keyboardShortcut(.defaultAction).disabled(busy)
                if onUse != nil {
                    Button("Primzahlen übernehmen") {
                        if let p = BigUInt(resultP), let q = BigUInt(resultQ) { onUse?(p, q); dismiss() }
                    }.disabled(!canAccept || busy)
                }
                Spacer()
                CT1HelpButton(action: .primeGeneration)
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 620)
        .ct1Window(title: "Primzahlen generieren", ref: ref)
        .onChange(of: lowerP) { _, _ in fieldsChanged() }
        .onChange(of: upperP) { _, _ in fieldsChanged() }
        .onChange(of: lowerQ) { _, _ in fieldsChanged() }
        .onChange(of: upperQ) { _, _ in fieldsChanged() }
        .onChange(of: sameRange) { _, v in if v == 1 { lowerQ = lowerP; upperQ = upperP } }
    }

    private func rangeFields(lower: Binding<String>, upper: Binding<String>, result: String, disabled: Bool, resultDisabled: Bool) -> some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Untergrenze")
                TextField("", text: lower).font(.system(.body, design: .monospaced)).disabled(disabled)
            }
            GridRow {
                Text("Obergrenze")
                TextField("", text: upper).font(.system(.body, design: .monospaced)).disabled(disabled)
            }
            GridRow {
                Text("Ergebnis")
                NTReadOnlyText(text: result).opacity(resultDisabled ? 0.4 : 1)
            }
        }.padding(4)
    }

    private func fieldsChanged() {
        for b in [$lowerP, $upperP, $lowerQ, $upperQ] {
            let f = ntFilterFormula(b.wrappedValue)
            if f != b.wrappedValue { b.wrappedValue = f }
        }
        if sameRange == 1 { if lowerQ != lowerP { lowerQ = lowerP }; if upperQ != upperP { upperQ = upperP } }
        resultP = ""; resultQ = ""
        accepted = false
    }

    private func dismiss() {
        if let close { close() } else { ref.window?.close() }
    }

    private func generate() {
        if [lowerP, upperP, lowerQ, upperQ].contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            Alerts.info("Geben Sie Ober- und Untergrenze ein!")
            return
        }
        for s in [lowerP, upperP, lowerQ, upperQ] {
            if (try? BigExpression.evaluate(s)) == nil { Alerts.error(NTMessages.inputFalse); return }
        }
        if countMode == 1 { generateAll(); return }
        let qLo = sameRange == 1 ? lowerP : lowerQ, qHi = sameRange == 1 ? upperP : upperQ
        let pl = ntEvaluate(lowerP), pu = ntEvaluate(upperP), ql = ntEvaluate(qLo), qu = ntEvaluate(qHi)
        for r in [pl, pu, ql, qu] where r.value == nil { Alerts.info(r.error ?? NTMessages.bigNumber); return }
        let (a, b, c, d) = (pl.value!, pu.value!, ql.value!, qu.value!)
        if a > b || c > d { Alerts.error("Die Untergrenze darf nicht größer als die Obergrenze sein!"); return }
        let algorithm = algo
        let progress = NTProgressModel()
        let rangeText = sameRange == 1 ? "Generiere Primzahlen im folgenden Bereich:\n[\(lowerP), \(upperP)]"
                                       : "Generiere Primzahlen in folgenden Bereichen:\n[\(lowerP), \(upperP)], [\(lowerQ), \(upperQ)]"
        progress.format = { p, _ in rangeText + "\n\(p)%" }
        busy = true
        scheduleProgress(progress, title: "Generierung von Primzahlen")
        let token = progress.token
        Task.detached(priority: .userInitiated) {
            let iterations = 20000
            var p: BigUInt?, q: BigUInt?
            var lastReport = Date.distantPast
            for i in 1...iterations {
                if token.isCancelled { break }
                if p == nil { let x = BigUInt.random(in: a...b); if ntProbablePrime(x, algorithm: algorithm, cancel: token) { p = x } }
                if q == nil { let x = BigUInt.random(in: c...d); if ntProbablePrime(x, algorithm: algorithm, cancel: token) { q = x } }
                if p != nil && q != nil { break }
                if Date().timeIntervalSince(lastReport) > 0.2 {
                    lastReport = Date()
                    let f = Double(i) / Double(iterations)
                    Task { @MainActor in progress.update(f) }
                }
            }
            let (fp, fq) = (p, q)
            let cancelled = token.isCancelled
            await MainActor.run {
                busy = false
                progress.dismiss()
                if cancelled { return }
                if let fp, let fq {
                    resultP = fp.description; resultQ = fq.description
                    accepted = true
                } else {
                    resultP = "0"; resultQ = "0"
                    if fp == nil { Alerts.error("Schlechte Wahl der Grenzen im linken Fenster, es wurde keine Primzahl gefunden !") }
                    if fq == nil { Alerts.error("Schlechte Wahl der Grenzen im rechten Fenster, es wurde keine Primzahl gefunden !") }
                }
            }
        }
    }

    private func scheduleProgress(_ progress: NTProgressModel, title: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if busy && !progress.token.isCancelled { progress.show(on: ref.window, title: title) }
        }
    }

    /// "Alle Primzahlen in dem (für p vorgegebenen) Wertebereich generieren".
    private func generateAll() {
        let pl = ntEvaluate(lowerP), pu = ntEvaluate(upperP)
        for r in [pl, pu] where r.value == nil { Alerts.info(r.error ?? NTMessages.bigNumber); return }
        let (a, b) = (pl.value!, pu.value!)
        if a > b { Alerts.error("Die Untergrenze darf nicht größer als die Obergrenze sein!"); return }
        let sep = separator.isEmpty ? " " : separator
        CT1Prefs.set("PrimeNumberGeneration.Separator", sep)
        let (loText, hiText) = (lowerP, upperP)
        let algorithm = algo
        let progress = NTProgressModel()
        progress.format = { p, _ in "Generiere Primzahlen im folgenden Bereich:\n[\(loText), \(hiText)]\n\(p)%" }
        busy = true
        scheduleProgress(progress, title: "Generation einer Menge von Primzahlen")
        let token = progress.token
        Task.detached(priority: .userInitiated) {
            var primes: [BigUInt] = []
            var value = a
            let width = b - a
            var lastReport = Date.distantPast
            // CT1 iterates "value < upper bound" (the upper bound itself is not tested)
            while value < b && !token.isCancelled {
                if ntProbablePrime(value, algorithm: algorithm, cancel: token) { primes.append(value) }
                value += 1
                if Date().timeIntervalSince(lastReport) > 0.2 {
                    lastReport = Date()
                    let f = width.isZero ? 1 : ntRatio(value - a, width)
                    Task { @MainActor in progress.update(f) }
                }
            }
            let cancelled = value < b
            let list = primes
            await MainActor.run {
                busy = false
                progress.dismiss()
                let text = list.map { $0.description + sep }.joined()
                DocumentFactory.openResult(text: text, title: "Primzahlen im Bereich [\(loText), \(hiText)]")
                if cancelled {
                    Alerts.info("Der Vorgang wurde abgebrochen. Im ausgewählten Wertebereich [\(loText), \(hiText)] wurden bisher \(list.count) Primzahlen gefunden.")
                } else {
                    Alerts.info("Im ausgewählten Wertebereich [\(loText), \(hiText)] wurden \(list.count) Primzahlen gefunden.")
                }
            }
        }
    }
}

/// a / b as Double for big numbers (0…1).
func ntRatio(_ a: BigUInt, _ b: BigUInt) -> Double {
    if b.isZero { return 0 }
    let shift = max(0, b.bitLength - 52)
    let x = Double((a >> shift).uint64Value ?? 0), y = Double((b >> shift).uint64Value ?? 1)
    return y == 0 ? 0 : min(1, x / y)
}
