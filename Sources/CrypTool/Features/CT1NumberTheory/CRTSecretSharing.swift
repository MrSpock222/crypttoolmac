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

    var title: String { "Secret Sharing by CRT: Reconstructing a secret with \(k) of \(n) keys" }

    func clearValues() {
        minK = ""; maxK1 = ""; w = ""; s = ""; a = ""; sPrime = ""
        ids = Array(repeating: "", count: 7); pw = Array(repeating: "", count: 7); rek = Array(repeating: "", count: 7)
    }

    /// "Zurücksetzen" (OnBnClickedSecretsharingReset).
    func reset() {
        clearValues(); log = ""; computed = false; safeState = nil
    }

    private static let inputFalse = "Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2."
    static let generatePrimeMsg = "This demonstration supports prime numbers with a bit length up to 109.\nThese numbers have up to 33 decimal places.\nPlease go to the 'Options'-dialog and decrease the Co-domain."

    /// "Berechnen" (OnBnClickedSecretsharingShare).
    func share() {
        rek = Array(repeating: "", count: 7)
        if manual { prepareManual() } else if let primes = generatePrimes() { calculate(primes) }
    }

    /// CT1 GeneratePrime(): n distinct random primes from [lower, upper], ascending.
    private func generatePrimes() -> [BigUInt]? {
        if lower.trimmingCharacters(in: .whitespaces).isEmpty || upper.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Enter an upper limit and a lower limit."); return nil
        }
        guard let lo = CRTUtil.formula(lower), let hi = CRTUtil.formula(upper) else { Alerts.error(Self.inputFalse); return nil }
        if lo > hi { Alerts.error("The lower limit must not be greater than the upper limit!"); return nil }
        var primes: [BigUInt] = []
        for _ in 0..<n {
            var found: BigUInt?
            for _ in 0..<10 {
                if let p = CRTUtil.randomPrime(lo, hi), !primes.contains(p) { found = p; break }
            }
            guard let p = found else {
                reset()
                CRTUtil.message("While generating prime numbers for \(n) identifiers, some of these numbers arose doubly.\nTo apply the Chinese remainder theorem, all these identifiers have to be different.\nPlease click 'Calculate' once again or go to the dialog 'options' and increase the Co-domain. .\n")
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
            CRTUtil.message("Please enter enough identifiers."); return
        }
        let primes = ids.prefix(n).map { BigUInt($0) ?? 0 }
        for i in 0..<n {
            for j in (i + 1)..<n where primes[i] == primes[j] {
                CRTUtil.message("Each identifier has to be a prime number and all of entered numbers have to be different.\n The identifier \(primes[i]) was entered twice.")
                return
            }
        }
        var nonPrimes = 0
        for p in primes where !Primality.millerRabin(p, rounds: 100) {
            nonPrimes += 1
            CRTUtil.message("Please enter only prime numbers. Identifier \(p) is a non prime.")
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

        var l = "----- starting calculation ----- \n\n"
        l += "number of keys given:  \(n)\n"
        l += "number of keys needed: \(k)\n\n"
        l += "SMALLEST possible identifier: \(lower)\n"
        l += "BIGGEST possible identifier:   \(upper)\n\n"
        for i in 0..<t { l += "Identifier_\(i + 1): \n\(ids[i])\n" }
        l += "\nmin(k):\n\(minK)\n"
        l += "max(k-1):\n\(maxK1)\n"
        l += "Quotient w:\n\(w)\n"
        l += "Secret s:\n\(s)\n"
        l += "Multiplier a:\n\(a)\n"
        l += "basis for shares (s'):\n\(sPrime)\n"
        l += "\n"
        for i in 0..<t { l += "Password_\(i + 1):\n\(pw[i])\n" }
        if t == 7 { l += "\n\n" }
        l += "\n----- calculation of identifiers and passwords is finished -----\n\n"
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
        log += "\n\n\n----- Reconstruction started -----\n\n"
        guard !ids[0].isEmpty else { return }
        let primesAll = (0..<n).map { BigUInt(ids[$0]) ?? 1 }
        var minKv = BigUInt(1)
        for i in 0..<k { minKv *= primesAll[i] }
        var used: [Int] = []
        for i in 0..<n where !rek[i].isEmpty { used.append(i) }
        if used.isEmpty {
            CRTUtil.message("Please enter at least \(k) correct keys into the 'Rebuilding the secret' - groupbox")
            log += "No keys entered.\n\n----- Reconstruction failed -----\n\n"
            return
        }
        safeState = used.count
        CRTUtil.message("The keys are joined together.\n\nAfter clicking OK, the resulting secret will be shown.")
        log += "Using the \(used.count) passwords to identifiers    " + used.map { " \($0 + 1)" }.joined(separator: ",") + "\n\n"
        let mods = used.map { primesAll[$0] }
        let shares = used.map { BigUInt(rek[$0]) ?? 0 }
        var M = BigUInt(1)
        for m in mods { M *= m }
        log += "M is now rebuilt from the given identifiers:\n\(M)\n\n"
        let wv = BigUInt(w) ?? 1, sv = BigUInt(s) ?? 0
        if M >= minKv {
            let sp = ChineseRemainder.solve(remainders: shares, moduli: mods)?.solution ?? 0
            log += "Enough passwords have been entered. s' can be calculated now using the Chinese remainder theorem:\n\(sp)\n\n"
            if sp % wv == sv {
                log += "Checking (s' mod w = s) .......................Successful!\n\n"
                safeState = 100
                CRTUtil.message("The following secret was rebuilt:\n\(sv)")
                log += "The following secret was rebuilt:\n\(sv)\n\n----- Reconstruction successfully finished -----"
            } else {
                log += "Checking (s' mod w = s) .......................NOT Successful!\n\n\n"
                safeState = -1
                CRTUtil.message("You've entered \(used.count) keys.\nThis is conform to the minimum number, but at least one key is wrong.\n")
                log += "At least one wrong key has been entered.\n\n----- Reconstruction failed -----\n\n"
            }
        } else {
            safeState = -1
            var missing = k - used.count
            var remaining = BigUInt(1)
            for i in 0..<n where missing > 0 && rek[i].isEmpty { remaining *= primesAll[i]; missing -= 1 }
            CRTUtil.message("You've entered \(used.count) keys.\nAt least \(k) correct keys are needed for a definite calculation.\nWith the given keys, there are \(remaining) possibilities remaining.")
            log += "Number of keys used is too small. With these keys, there are \(remaining) possibilities remaining.\n\n----- Reconstruction failed -----\n\n"
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
                    Text("Secret sharing with the Chinese Remainder Theorem (CRT) allows a secret to be divided among n keys, such that the secret can be reconstructed if a given subset k<=n share their keys with each other.")
                    Text("Click the \"Calculate\" button to generate and distribute the secret. Click on \"Options\" to change the number of involved parties and the range of values for the identifiers.")
                    Text("Once the secret has been distributed, use the \"+/-\" buttons to add or remove participating parties. You can try to rebuild the secret if enough parties are present by clicking \"Rebuild secret\".")
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            CRTGroup(title: "Constructing and sharing the secret with n = \(model.n) parties") {
                HStack(alignment: .top, spacing: 10) {
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                        GridRow { Text("Identifier (= Prime number)"); Text("Password (= Key)") }
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
                        Text("Distribute keys:")
                        Picker("", selection: Binding(get: { model.manual }, set: { model.manual = $0; model.reset() })) {
                            Text("automatically").tag(false); Text("manually").tag(true)
                        }.pickerStyle(.radioGroup).labelsHidden()
                        Button("Calculate") { model.share() }.keyboardShortcut(.defaultAction).frame(maxWidth: .infinity)
                        Button("Options", action: showOptions).frame(maxWidth: .infinity)
                        Button("Calc. steps", action: showFacts).disabled(!model.computed).frame(maxWidth: .infinity)
                        Button("Reset") { model.reset() }.disabled(!model.computed).frame(maxWidth: .infinity)
                    }.frame(width: 120)
                }
            }
            CRTGroup(title: "Rebuilding the secret with a minimum of k = \(model.k) keys") {
                Text("Choose which of the n = \(model.n) identifiers will participate in rebuilding the secret.")
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
                        Button("Rebuild secret") { model.reconstruct() }.disabled(!model.computed)
                    }.frame(width: 250)
                }
            }
            Toggle("Show intro on next startup", isOn: Binding(get: { model.showIntro }, set: {
                model.showIntro = $0; CT1Prefs.set(CRTSSModel.prefIntro, $0)
            }))
            HStack {
                CT1HelpButton(action: .crtSecretSharing)
                Spacer()
                Button("Log file", action: showLog).disabled(!model.computed)
                Spacer()
                Button("Exit") {
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
        win.sheet("Sharing a Secret Using the CRT") { close in
            CRTSSIntroSheet(close: { show in
                CT1Prefs.set(CRTSSModel.prefIntro, show)
                model.showIntro = show
                close()
            })
        }
    }

    private func showOptions() {
        let m = model
        win.sheet("Secret Sharing by CRT: Controlling the Basic Conditions") { close in
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
        win.sheet("Secret Sharing by CRT: Calculation Method: How to Get a Password") { close in
            CRTSSFactsSheet(model: m, close: close)
        }
    }

    private func showLog() {
        let m = model
        win.sheet("Secret Sharing by CRT: Show log file") { close in
            CRTLogSheet(title: "Secret Sharing by CRT: Show log file", text: m.log, saveTitle: "SecretSharing-Log",
                        savedMessage: "Log file successfully written to the main window.", close: close)
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
                Text("Secret distributed").font(.caption)
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
            Text("Using this application a secret can be distributed to a maximum of 7 people, so that it may be solved with a smaller number, that was specified before. Certainly it`s not fixed, which of these people are involved in this subset.")
            Text("You can compare this proceeding to a bank, where 5 people from the executive committee own keys for the safe deposit. To  ensure, that one single person is not able to open it up, one demands that e.g. three of these persons have to use their keys at the same time.")
            Text("In this scheme, we are using number-keys: each person is 'marked' with an identifier an has got a personal key, that can only be validated, when it is used with the correct identifier.")
            Text("In case of uncertainties while using this application, simply hit the F1-key to get a context-specific help.")
            HStack { Spacer(); Button("OK") { close(showAgain) }.keyboardShortcut(.defaultAction); Spacer() }
            Toggle("Display this dialog on next startup", isOn: $showAgain)
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
            CRTGroup(title: "Required values") {
                HStack {
                    Text("Number of parties (n):")
                    TextField("", text: Binding(get: { n }, set: { n = CRTUtil.digits($0) })).frame(width: 40)
                    Text("Parties needed (k):")
                    TextField("", text: Binding(get: { k }, set: { k = CRTUtil.digits($0) })).frame(width: 40)
                }
                HStack {
                    Text("Closed interval in which the prime identifiers will be generated:")
                        .fixedSize(horizontal: false, vertical: true).frame(width: 220, alignment: .leading)
                    TextField("", text: $lower).frame(width: 70)
                    Text("-")
                    TextField("", text: $upper).frame(width: 70)
                }.disabled(manual)
            }
            VStack {
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 560, height: 130)
    }

    private func ok() {
        let nn = Int(n) ?? 0, kk = Int(k) ?? 0
        if nn == kk {
            CRTUtil.message("Please choose k<n (here: k<\(nn)).\n\nIf k and n are identical in this secret sharing procedure, the secret equals the password of the first participant.")
            return
        }
        guard nn >= 2, kk <= nn, kk >= 2, nn <= 7 else {
            var msg = ""
            if nn < 2 { msg += "You have entered \(nn) as number of parties.\nPlease enter 2 as minimum for this parameter.\n" }
            if nn > 7 { msg += "You have entered \(nn) as number of parties.\nPlease choose 7 as maximum.\n" }
            if kk > nn { msg += "You have entered \(kk) as the number of parties needed.\nThis number mustn't be bigger than the over all number of parties.\n" }
            if kk < 2 && kk > nn { msg += "Please enter a minimum of 2 for the number of parties needed.\n" }
            if kk < 2 && kk <= nn { msg += "You have entered \(kk) for the number of parties needed.\nPlease enter a minimum of 2 for the number of parties needed.\n" }
            CRTUtil.message(msg)
            return
        }
        var lo = lower, hi = upper
        if manual { lo = "2^108"; hi = "2^109" }
        if lo.trimmingCharacters(in: .whitespaces).isEmpty || hi.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Enter an upper limit and a lower limit."); return
        }
        let inputFalse = "Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2."
        guard let x = CRTUtil.formula(lo), let y = CRTUtil.formula(hi) else { CRTUtil.message(inputFalse); return }
        if y.isZero || y.description.count > 33 || (lo != "0" && (x.isZero || x.description.count > 33)) {
            CRTUtil.message(CRTSSModel.generatePrimeMsg); return
        }
        if x > y { Alerts.error("The lower limit must not be greater than the upper limit!"); return }
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
            Text("1. Product of the k = \(model.k) smallest prime numbers (min[k]):")
            CRTOutputField(text: model.minK, multiline: true, minHeight: 44)
            Text("2. Product of the (k-1) = \(model.k - 1) biggest prime numbers (max[k-1]):")
            CRTOutputField(text: model.maxK1, multiline: true, minHeight: 44)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("3. Quotient of these upper numbers (w):")
                    CRTOutputField(text: model.w)
                }
                VStack(alignment: .leading) {
                    Text("4. Secret (s) is a random number between 0 and w:")
                    TextField("", text: Binding(get: { s }, set: { s = CRTUtil.digits($0) })).font(.system(.body, design: .monospaced))
                }
            }
            Text("5. Multiplicator (a) with 0 <= a <= (min[k] / w):")
            TextField("", text: Binding(get: { a }, set: { a = CRTUtil.digits($0) })).font(.system(.body, design: .monospaced))
            Text("6. The number (s' = a*w+s) now serves as a base for calculating the passwords:")
            CRTOutputField(text: model.sPrime, multiline: true, minHeight: 44)
            HStack {
                Text("7. Password_i is now calculated through (s' mod Identifier_i).")
                Spacer()
                Button("Log-File") {
                    let text = model.log
                    WindowPresenter.sheet(on: NSApp.keyWindow, title: "Secret Sharing by CRT: Show log file") { c in
                        CRTLogSheet(title: "Secret Sharing by CRT: Show log file", text: text, saveTitle: "SecretSharing-Log",
                                    savedMessage: "Log file successfully written to the main window.", close: c)
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
            CRTUtil.message("Please notice the formal restrictions."); return
        }
        model.applyFacts(s: s, a: a)
        close()
    }
}
