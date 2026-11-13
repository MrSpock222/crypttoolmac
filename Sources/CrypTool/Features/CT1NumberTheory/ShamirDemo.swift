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
            CRTUtil.message("You did not enter all values needed to set up the scheme."); return true
        }
        guard let tt = Int(threshold), let nn = Int(participants), let ss = Int(secret) else {
            CRTUtil.message("You did not enter all values needed to set up the scheme."); return true
        }
        if tt > nn {
            CRTUtil.message("The given threshold is bigger than the number of participants. Please correct your specifications.")
            threshold = ""; generateEnabled = false; return true
        }
        if nn > (Int(partyLimit) ?? 30) {
            CRTUtil.message("The number of participants exceeds the previously defined limit.")
            threshold = ""; participants = ""; generateEnabled = false; return true
        }
        let maxPrime = Int(primeLimit) ?? 10000
        guard maxPrime >= nn, maxPrime >= ss, let prime = Self.randomPrime(above: max(nn, ss), upTo: maxPrime) else {
            CRTUtil.message("The defined limit for your prime p has to be bigger than your secret K and the number of participants n.")
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
        var l = "Log file for Shamir's secret-sharing scheme\n\n"
        l += "At first, you chose the following parameters that determine the Shamir scheme: the secret S, the upper limit of participants l = Max(n), the number of participants n, the upper limit to a prime Max(p) and your threshold t.\n\n"
        l += "S: \(secret)\nl = Max(n): \(partyLimit)\nn: \(participants)\nMax(p): \(primeLimit)\nt: \(threshold)\n\n"
        l += (primeFlag ? "You did set a prime number p." : "Founded on the values you entered before, CrypTool has randomly chosen a prime number p.") + "\n\n"
        l += "p: \(modulus)\n\n"
        l += (coeffFlag ? "You determined the coefficients of a polynomial of degree t-1. All computations take place in the discrete space GF(p)."
                        : "In addition, a polynomial f(x) of degree t-1 with random coefficients and the absolute summand S has been created. All computations take place in the discrete space GF(p). ") + "\n\n"
        l += "f(x): \(polynom)\n\n"
        l += "Each participant receives its public value x. Also x has been chosen at random:\n\n"
        for (i, r) in rows.enumerated() { l += "\(i + 1): \(r.x)\n" }
        l += "\nBy applying the polynomial f(x) to every single public value x, each participant obtains his secret value y (share):\n\n"
        for (i, r) in rows.enumerated() { l += "\(i + 1): \(r.share)\n" }
        l += "\nYou selected the following participants to reconstruct the secret:\n\n"
        let sel = checked.sorted()
        for i in sel { l += "\(i + 1), " }
        l += "\n\nThese participants hold the following pairs of public values and shares (x/y):\n\n"
        for i in sel { l += "\(i + 1): \(rows[i].x) / \(rows[i].share)\n" }
        l += "\nBy means of Lagrange polynomial interpolation, the secret S has been reconstructed out of these \(sel.count) pairs of public values and shares:\n\n"
        l += result.description
        return l
    }
}

/// CT1 "Secret-Sharing-Demo: Aufsetzen eines Schwellenwertschemas".
struct CT1ShamirDialog: View {
    static let title = "Secret Sharing Demonstration: Initializing the Threshold Scheme"
    @StateObject private var model = ShamirModel()
    @StateObject private var win = CT1WindowRef()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By means of a (t, n) Shamir scheme a secret S can be distributed among n persons. Afterwards, t persons (t <= n) will be able to reconstruct the original secret by combining their individual secrets (shares).")
                .fixedSize(horizontal: false, vertical: true)
            Text("To set up such a scheme, a polynomial f(x) of degree at most t-1 [with t-1 coefficients a(i) chosen at random] and a random prime p must be generated.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Each participant receives a randomly chosen public value x and his or her share, the corresponding secret value y=f(x). For further details please check the CrypTool online help by pressing F1.")
            CRTGroup(title: "Choose your secret and the parameters (whole numbers) to set up a scheme") {
                HStack(alignment: .top) {
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        GridRow { Text("Secret S with S >= 0"); field(\.secret) }
                        GridRow { Text("Number of participants n  with n > 0"); field(\.participants) }
                        GridRow { Text("Threshold (minimum) t with t > 0"); field(\.threshold) }
                    }
                    Spacer()
                    VStack {
                        Button("Set default parameters") { model.example() }.frame(width: 190).disabled(model.locked)
                        Button("Options", action: showOptions).frame(width: 190)
                    }
                }
            }
            HStack {
                Spacer().frame(width: 230)
                Button("Generate polynomial", action: generate).disabled(!model.generateEnabled || model.locked)
                Spacer()
                Button("Edit polynomial parameters", action: showParameters).disabled(!model.paramsEnabled || model.locked)
            }
            CRTGroup(title: "Parameters concerning the polynomial f(x) of degree t-1") {
                Text("All computations take place in the discrete space GF(p) ")
                HStack { Text("Polynomial f(x)").frame(width: 90, alignment: .leading); CRTOutputField(text: model.polynom) }
                HStack {
                    Text("Prime p").frame(width: 90, alignment: .leading)
                    CRTOutputField(text: model.modulus)
                    Button("Accept parameters") { model.update() }.disabled(!model.updateEnabled)
                }
            }
            Text("Participants' values, calculated from chosen parameters:")
            sharesList
            Text("Please check the appropriate boxes to select the participants who will attempt to reconstruct the secret.")
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Show information dialog at startup", isOn: Binding(get: { model.showIntro }, set: {
                model.showIntro = $0; CT1Prefs.set(ShamirModel.prefIntro, $0)
            }))
            HStack {
                Button("Close") { win.window?.close() }
                CT1HelpButton(action: .shamirSecretSharing)
                Spacer()
                Button("Reconstruction", action: reconstruct).keyboardShortcut(.defaultAction).disabled(!model.revealEnabled)
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
                Text("Participant").frame(width: 150, alignment: .leading)
                Text("Public value x").frame(width: 150, alignment: .leading)
                Text("Share [secret value f(x)]").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption.bold()).padding(4).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.rows.indices, id: \.self) { i in
                        HStack {
                            Toggle("", isOn: Binding(get: { model.checked.contains(i) }, set: {
                                if $0 { model.checked.insert(i) } else { model.checked.remove(i) }
                            })).labelsHidden().frame(width: 24)
                            Text("participant \(i + 1)").frame(width: 150, alignment: .leading)
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
        win.sheet("Introduction Secret Sharing Demonstration") { close in
            ShamirIntroSheet(close: { hide in
                CT1Prefs.set(ShamirModel.prefIntro, !hide)
                model.showIntro = !hide
                close()
            })
        }
    }

    private func showOptions() {
        let m = model
        win.sheet("Secret Sharing: Options") { close in
            ShamirOptionsSheet(limit: m.partyLimit, prime: m.primeLimit, close: close) { l, p in
                m.partyLimit = l; m.primeLimit = p
            }
        }
    }

    private func showParameters() {
        let m = model
        win.sheet("Secret Sharing: Displaying and Editing Polynomial Parameters") { close in
            ShamirParameterSheet(model: m, close: close)
        }
    }

    private func reconstruct() {
        guard let t = Int(model.threshold), model.checked.count >= t else {
            CRTUtil.message("The number of selected participants is below your chosen threshold.")
            return
        }
        let m = model
        let result = m.reveal()
        let log = m.logText(result: result)
        let rows = m.checked.sorted().map { (i: $0, x: m.rows[$0].x, y: m.rows[$0].share) }
        win.sheet("Secret Sharing: Reconstructing the Secret") { close in
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
            Text("Welcome to the visualization of the Shamir secret-sharing scheme!")
            Text("The protocol deals with the following problem:")
            Text("A secret value is to be distributed among n persons so that a single person has no information about this value. At least t out of n persons have to cooperate to succeed in reconstructing the secret.")
            Text("Therefore, this method is called a (t,n)-threshold scheme.")
            Text("Example:")
            Text("The secret recipe for a new kind of ice cream is locked up in a safe. In order to prevent any employee from selling the recipe to a competitor for a great deal of money, the secret combination to open this safe is split up among the 10 employees. At least 7 employees have to combine their shares of the key to open the safe and to come into the possession of the recipe.")
            Text("Since this demonstration is an interactive visualization, you will be prompted for certain inputs a couple of times.")
            Text("If you need additional information, please feel free to use the CrypTool online help by pressing F1.")
            HStack { Spacer(); Toggle("Don't show this message again.", isOn: $hide); Spacer() }
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
            CRTGroup(title: "Adjustable parameters") {
                HStack { Text("Maximum number of participants [l = Max(n)]"); Spacer(); TextField("", text: Binding(get: { limit }, set: { limit = CRTUtil.digits($0) })).frame(width: 80) }
                HStack { Text("Upper Limit to p"); Spacer(); TextField("", text: Binding(get: { prime }, set: { prime = CRTUtil.digits($0) })).frame(width: 80) }
            }
            HStack {
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
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
            CRTGroup(title: "Displaying secret and control parameters") {
                HStack {
                    Text("Secret S:"); CRTOutputField(text: model.secret).frame(width: 70)
                    Text("Number of participants n:"); CRTOutputField(text: model.participants).frame(width: 70)
                    Text("Threshold t:"); CRTOutputField(text: model.threshold).frame(width: 70)
                }
            }
            CRTGroup(title: "Entering or changing polynomial parameters") {
                Text("All computations of a (t, n) Shamir scheme take place in a discrete space GF(p).\np is a prime that has to be larger than the secret S as well as the number of participants n.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("Enter a suitable prime")
                        Text("[p > n, p > S, p > a(i),  i = 1, 2, ..., t-1 ]").font(.caption)
                    }
                    TextField("", text: Binding(get: { prime }, set: { prime = $0.filter { "0123456789^+-*()".contains($0) } }))
                }
                Text("A polynomial f(x) of degree t-1 is constructed over GF(p): It is used to compute the participants' shares. By means of this polynomial and the generated shares, the secret can be reconstructed. Such a polynomial consists of t-1 coefficients a(i) from GF(p).")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Enter t-1 coefficients (separated by commas; e.g. 3, 6, 19, if p>=19)")
                TextField("", text: Binding(get: { coeffText }, set: { coeffText = $0; okEnabled = true }))
            }
            HStack {
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Generate polynomial", action: generateNew).keyboardShortcut(.defaultAction)
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
            Alerts.error("Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2.")
            return
        }
        let limit = Int(model.primeLimit) ?? 10000
        let s = Int(model.secret) ?? 0, n = Int(model.participants) ?? 0
        if tmpPrime != oldPrime && tmpPrime != 0 {
            if !Primality.isProbablePrime(BigUInt(tmpPrime)) {
                CRTUtil.message("The number you have entered is no prime number.")
                return
            }
            if tmpPrime > limit {
                CRTUtil.message("Your prime exceeds the defined limit of \(limit).")
                return
            }
            if tmpPrime <= s || tmpPrime <= n {
                CRTUtil.message("The chosen prime number is too small. Its value has to exceed the secret and the number of participants. ")
                prime = ""
                return
            }
            prime = String(tmpPrime)
            setCoefficients(tmpPrime)
        } else {
            guard let p = ShamirModel.randomPrime(above: max(n, s), upTo: limit) else {
                CRTUtil.message("The defined limit for your prime p has to be bigger than your secret K and the number of participants n.")
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
            CRTUtil.message("Exactly \(required) coefficients are required!")
            coeffText = ""; okEnabled = false
            return
        }
        guard let p = currentPrime, p > 1 else { return }
        if !Primality.isProbablePrime(BigUInt(p)) || p <= (Int(model.secret) ?? 0) || p <= (Int(model.participants) ?? 0) {
            CRTUtil.message("The chosen prime number is too small. Its value has to exceed the secret and the number of participants. ")
            return
        }
        let coeffs = parts.map { Int($0) ?? Int.max }
        if coeffs.contains(where: { $0 >= p }) {
            CRTUtil.message("All coefficients have to be less than your prime module.")
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
            Text("Selected participants")
            VStack(spacing: 0) {
                HStack {
                    Text("Participant").frame(width: 150, alignment: .leading)
                    Text("Public value x").frame(width: 150, alignment: .leading)
                    Text("Share [secret value f(x)]").frame(maxWidth: .infinity, alignment: .leading)
                }.font(.caption.bold()).padding(4).background(Color(nsColor: .controlBackgroundColor))
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { r in
                            HStack {
                                Text("participant \(rows[r].i + 1)").frame(width: 150, alignment: .leading)
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
            CRTGroup(title: "Reconstruction of your secret") {
                HStack {
                    Text("The secret reconstructed by the previous selected participants is")
                    CRTOutputField(text: secret).frame(width: 140)
                }
            }
            HStack {
                Button("Show log file") {
                    DocumentFactory.openResult(text: log, title: "Secret Sharing (Shamir): Log file")
                    CRTUtil.message("The log text of the procedure was successfully written into the main window of the CrypTool application.")
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
