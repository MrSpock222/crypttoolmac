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
    static let inputFalse = "Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2."
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
                    Text("There are many methods to check if a number is prime.")
                    Text("Most of these are probabilistic, meaning that they can only determine primality to a given adjustable degree of certainty.")
                    Text("However, these methods are much faster than their counterpart, deterministic methods. Such methods return a 100% mathematically certain result.")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Algorithms for prime number test") {
                Picker("", selection: $algo) {
                    Text("Miller-Rabin test").tag(0)
                    Text("Fermat test").tag(1)
                    Text("Solovay-Strassen test").tag(2)
                    Text("AKS test (deterministic procedure)").tag(3)
                }
                .pickerStyle(.radioGroup).labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Prime number test") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button("Load number from file") {
                            if let s = CT1BigNumber.loadFromFile() { input = s }
                        }.disabled(busy)
                    }
                    HStack {
                        Text("Number or formula to test:").frame(width: 190, alignment: .leading)
                        TextField("", text: $input).font(.system(.body, design: .monospaced))
                            .onSubmit(test)
                    }
                    HStack {
                        Text("Result:").frame(width: 190, alignment: .leading)
                        Image(systemName: isPrime == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isPrime == true ? .green : .red)
                            .opacity(isPrime == nil ? 0 : 1)
                        NTReadOnlyText(text: result)
                    }
                }.padding(4)
            }
            HStack {
                Button("Test number", action: test).keyboardShortcut(.defaultAction).disabled(busy)
                Button("Factorize number", action: jumpToFactorization).disabled(!canFactor || busy)
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                CT1HelpButton(action: .primeTest)
                Button("Cancel") {
                    token.cancel()
                    ref.window?.close()
                }
            }
        }
        .padding(14)
        .frame(minWidth: 560, idealWidth: 600)
        .ct1Window(title: "Prime Number Test", ref: ref)
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
            Alerts.error("Please enter a number!")
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
            result = (probable ? "The number is probable prime: " : "The number is prime: ") + numberText
        } else {
            result = "The number is not prime: " + numberText
            canFactor = true
        }
    }

    private func runAKS(_ n: BigUInt, numberText: String, token: CancellationToken) {
        let progress = NTProgressModel()
        let bits = n.bitLength
        progress.format = { p, rest in "\(bits)-bit AKS test \(p)% completed.\nRemaining time: \(rest)" }
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
                    if !token.isCancelled { result = "Test canceled"; isPrime = nil }
                case .tooLarge(let bytes):
                    result = "Error in processing"; isPrime = nil
                    Alerts.error(String(format: "The AKS test is not feasible for this number: the polynomial arithmetic would require approx. %.0f MB of memory.", bytes / 1_048_576))
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
        WindowPresenter.tool(title: "Factorization of a Number", size: CGSize(width: 660, height: 640)) {
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
                Text("Prime numbers play an important role in modern cryptography. Here you can generate primes within a given value range [lower limit, upper limit].")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Amount of prime numbers to be generated") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("", selection: $countMode) {
                        Text("Generate two primes randomly from within the value range(s)").tag(0)
                        Text("Generate all primes within the value range set for p").tag(1)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .disabled(!allowAll)
                    HStack {
                        Text("Separator for the display of the primes:")
                        TextField("", text: $separator).frame(width: 40).multilineTextAlignment(.center)
                            .disabled(countMode == 0)
                    }.padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack(alignment: .top, spacing: 12) {
                GroupBox("Algorithms for prime number generation") {
                    Picker("", selection: $algo) {
                        Text("Miller-Rabin Test").tag(0)
                        Text("Solovay-Strassen Test").tag(1)
                        Text("Fermat Test").tag(2)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                // only as wide as its content, so the longer options on the right are not cut off
                .fixedSize(horizontal: true, vertical: false)
                GroupBox("Value range of the prime numbers p and q") {
                    Picker("", selection: $sameRange) {
                        Text("To be entered independently of each other").tag(0)
                        Text("Both are equal (just enter one)").tag(1)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .disabled(countMode == 1)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                GroupBox("Prime number p") {
                    rangeFields(lower: $lowerP, upper: $upperP, result: resultP, disabled: false, resultDisabled: countMode == 1)
                }
                GroupBox("Prime number q") {
                    rangeFields(lower: $lowerQ, upper: $upperQ, result: resultQ,
                                disabled: countMode == 1 || sameRange == 1, resultDisabled: countMode == 1)
                }
            }
            HStack {
                Button("Generate prime numbers", action: generate).keyboardShortcut(.defaultAction).disabled(busy)
                if onUse != nil {
                    Button("Apply primes") {
                        if let p = BigUInt(resultP), let q = BigUInt(resultQ) { onUse?(p, q); dismiss() }
                    }.disabled(!canAccept || busy)
                }
                Spacer()
                CT1HelpButton(action: .primeGeneration)
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 620)
        .ct1Window(title: "Prime Number Generation", ref: ref)
        .onChange(of: lowerP) { _, _ in fieldsChanged() }
        .onChange(of: upperP) { _, _ in fieldsChanged() }
        .onChange(of: lowerQ) { _, _ in fieldsChanged() }
        .onChange(of: upperQ) { _, _ in fieldsChanged() }
        .onChange(of: sameRange) { _, v in if v == 1 { lowerQ = lowerP; upperQ = upperP } }
    }

    private func rangeFields(lower: Binding<String>, upper: Binding<String>, result: String, disabled: Bool, resultDisabled: Bool) -> some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Lower limit")
                TextField("", text: lower).font(.system(.body, design: .monospaced)).disabled(disabled)
            }
            GridRow {
                Text("Upper limit")
                TextField("", text: upper).font(.system(.body, design: .monospaced)).disabled(disabled)
            }
            GridRow {
                Text("Result")
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
            Alerts.info("Enter an upper limit and a lower limit.")
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
        if a > b || c > d { Alerts.error("The lower limit must not be greater than the upper limit!"); return }
        let algorithm = algo
        let progress = NTProgressModel()
        let rangeText = sameRange == 1 ? "Generating prime numbers in the following value range:\n[\(lowerP), \(upperP)]"
                                       : "Generating prime numbers in the following value ranges:\n[\(lowerP), \(upperP)], [\(lowerQ), \(upperQ)]"
        progress.format = { p, _ in rangeText + "\n\(p)%" }
        busy = true
        scheduleProgress(progress, title: "Generating prime numbers")
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
                    if fp == nil { Alerts.error("Bad choice of limits in the left-hand window. No prime numbers were found!") }
                    if fq == nil { Alerts.error("Bad choice of limits in the right-hand window. No prime numbers were found!") }
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
        if a > b { Alerts.error("The lower limit must not be greater than the upper limit!"); return }
        let sep = separator.isEmpty ? " " : separator
        CT1Prefs.set("PrimeNumberGeneration.Separator", sep)
        let (loText, hiText) = (lowerP, upperP)
        let algorithm = algo
        let progress = NTProgressModel()
        progress.format = { p, _ in "Generating prime numbers in the following value range:\n[\(loText), \(hiText)]\n\(p)%" }
        busy = true
        scheduleProgress(progress, title: "Generating a set of prime numbers")
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
                DocumentFactory.openResult(text: text, title: "Prime numbers in the range [\(loText), \(hiText)]")
                if cancelled {
                    Alerts.info("The process was cancelled. In the given value range [\(loText), \(hiText)], \(list.count) prime numbers were found yet.")
                } else {
                    Alerts.info("In the given value range [\(loText), \(hiText)], \(list.count) prime numbers were found.")
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
