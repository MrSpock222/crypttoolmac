import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Halbautomatische Analyse von ADFGVX" (DlgAdfgvxManual, DlgAdfgvxIntro, DlgAdfgvxStringBox).

extension CT1Analysis {
    /// Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸ ADFGVX …
    static func openADFGVXAnalysis(document: CTDocument) {
        let id = "ct1-adfgvx-analysis-\(ObjectIdentifier(document).hashValue)"
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == id && $0.isVisible }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let analysis: ADFGVXAnalysis
        do {
            analysis = try ADFGVXAnalysis(ciphertext: document.text)
        } catch {
            Alerts.error(error.localizedDescription)
            return
        }
        let model = ADFGVXAnalysisModel(document: document, analysis: analysis)
        let window = WindowPresenter.tool(id: id, title: "Semiautomatic Analysis of the ADFGVX Cipher",
                                          size: CGSize(width: 620, height: 820)) {
            ADFGVXAnalysisView(model: model)
        }
        window.identifier = NSUserInterfaceItemIdentifier(id)
        model.window = window
        if !UserDefaults.standard.bool(forKey: ADFGVXAnalysisIntroView.defaultsKey) {
            WindowPresenter.sheet(on: window, title: "Introduction to Analyzing ADFGVX Messages") { close in
                ADFGVXAnalysisIntroView(close: close)
            }
        }
        if !model.applyReferenceStatistics() {
            Alerts.info(ADFGVXAnalysisTexts.referenceFileError)
        }
    }
}

/// German texts of CT1's string table (IDS_STRING_ADFGVX_…).
enum ADFGVXAnalysisTexts {
    static let error4 = "Invalid characters have been removed. Only characters from the\ncurrent CrypTool alphabet are valid.\n"
    static let error6 = "The length of the password must be >0!"
    static let error8 = "Please analyze transposition first!"
    static let error9 = "No valid permutation was found while analyzing the transposition phase.\nThis may have two reasons:\n\n1. The relative frequency of the letters is atypical for the English or German language.\nThis often occurs when analyzing short messages.\n\n2. The transposition password is not within the selected boundaries of the analysis.\nYou should change the boundaries for the evaluated password length."
    static let error9B = "The analysis has reached the upper boundary of the search area.\nNo further passwords have been found."
    static let error11 = "Invalid character! Please enter characters from 'A' to 'Z' and '0' to '9' only!"
    static let charExists1A = "The character '"
    static let charExists1B = "The character '"
    static let charExists2 = "' was already assigned. \nDo you want to retain the new entry? \n\nYes: The old entry will be deleted.\n\nNo: Undo the changes."
    static let matrixReset = "All current entries in the substitution matrix will be erased!\nContinue?"
    static let noCharacters = "You did not enter any characters, thus the substitution matrix was not changed."
    static let referenceFileError = "Error opening the reference file! Please select a valid reference file via the menu Options / Text Options."
    static let pasteKey = "Paste key from keystore"

    /// Yes/No question (CT1 AfxMessageBox MB_YESNO).
    @MainActor
    static func askYesNo(_ message: String) -> Bool {
        let a = NSAlert()
        a.messageText = "CrypTool"
        a.informativeText = message
        a.addButton(withTitle: "Yes")
        a.addButton(withTitle: "No")
        return a.runModal() == .alertFirstButtonReturn
    }
}

// MARK: - Model (state and logic of CDlgAdfgvxManual)

@MainActor
final class ADFGVXAnalysisModel: ObservableObject {
    let document: CTDocument
    private(set) var analysis: ADFGVXAnalysis
    weak var window: NSWindow?

    @Published private(set) var password = ""
    @Published var minLength = 1          // CT1 default: 1 … 8
    @Published var maxLength = 8
    @Published var matrix = ADFGVXAnalysis.emptyMatrix
    @Published private(set) var analysed = false
    @Published private(set) var forceEnabled = false
    @Published private(set) var plaintext = ""
    @Published private(set) var running = false
    @Published private(set) var progress = 0.0
    @Published private(set) var status = ""
    @Published private(set) var frequencyInfo = ""
    private var iGotOne = false
    private var lastPasswordFound = ""
    private var token = CancellationToken()

    init(document: CTDocument, analysis: ADFGVXAnalysis) {
        self.document = document
        self.analysis = analysis
    }

    var numberedPassword: String { ADFGVXAnalysis.numberedPassword(password) }
    var remainingCharacters: String { ADFGVXAnalysis.remainingCharacters(matrix) }
    var remainingPossibilities: String { String(format: "%.15g", ADFGVXAnalysis.remainingPossibilities(matrix)) }
    var outputEnabled: Bool { analysed && !plaintext.isEmpty && !running }
    var hasStoredKey: Bool {
        KeyMemory.initial(for: "adfgvx", document: document).flatMap(ADFGVXAnalysis.parseKey) != nil
    }

    private var alphabet: String { AppSettings.shared.textOptions.alphabet }

    // MARK: Reference statistics (SetFrequenciesFromReference)

    /// Sets the frequency ranking from the reference text; false if the text has no letters
    /// (CT1 then keeps its default "ENISR" / 16 %).
    @discardableResult
    func applyReferenceStatistics() -> Bool {
        let s = AppSettings.shared
        let includeDigits = s.textOptions.alphabet.contains("0123456789")
        let ok: Bool
        if let st = ADFGVXAnalysis.referenceStatistics(s.referenceText, includeDigits: includeDigits) {
            analysis.setFrequencyTable(st)
            ok = true
        } else {
            ok = false
        }
        frequencyInfo = "Reference language \(s.referenceLanguage.displayName): frequency order \(String(analysis.frequencyTable.prefix(10)))…, "
            + "a password is considered possible if the most frequent bigram reaches ≥ \(analysis.highestFrequency) %."
        return ok
    }

    /// Text options changed (CT1: "Textoptionen" button): password re-filtered, frequencies recomputed.
    func textOptionsChanged() {
        let filtered = filterToAlphabet(password)
        if filtered != password { passwordChanged(filtered) }
        applyReferenceStatistics()
    }

    // MARK: Password field (CAlphabetTextEdit + OnChangedTranspositionPassword)

    /// CAlphabetTextEdit: only characters of the CrypTool alphabet; letters are converted to the
    /// case contained in the alphabet.
    func filterToAlphabet(_ s: String) -> String {
        let a = alphabet
        var out = ""
        for ch in s {
            if a.contains(ch) { out.append(ch); continue }
            let up = ch.uppercased(), low = ch.lowercased()
            if up.count == 1, up != String(ch), a.contains(up) { out += up } else if low.count == 1, low != String(ch), a.contains(low) { out += low }
        }
        return out
    }

    func userEditedPassword(_ s: String) {
        passwordChanged(filterToAlphabet(s))
    }

    private func passwordChanged(_ p: String) {
        password = p
        analysed = false
        if !p.isEmpty {
            forceEnabled = true
            let len = min(p.count, 26)
            if maxLength < len { maxLength = len }
            minLength = len
        } else {
            forceEnabled = false
        }
    }

    // MARK: Length range (OnCbnSelchangeMinlength / Maxlength)

    func setMinLength(_ v: Int) {
        minLength = v
        iGotOne = false
        if !password.isEmpty && password.count != v {
            passwordChanged("")
            analysed = false
            matrix = ADFGVXAnalysis.emptyMatrix
        }
        if minLength > maxLength { maxLength = minLength }
    }

    func setMaxLength(_ v: Int) {
        maxLength = v
        iGotOne = false
        if password.count > v {
            passwordChanged("")
            analysed = false
            matrix = ADFGVXAnalysis.emptyMatrix
        }
        if maxLength < minLength { minLength = maxLength }
    }

    // MARK: "Analysieren" (OnBnClickedNextPermutation / Permutate)

    func analyze() {
        guard !running else { return }
        analysed = false
        switch ADFGVXAnalysis.checkPassword(password, alphabet: alphabet) {
        case .invalidCharacters:
            let old = password
            let cleaned = ADFGVXAnalysis.cleansePassword(password, alphabet: alphabet)
            passwordChanged(cleaned)
            minLength = max(1, min(26, cleaned.count))
            if maxLength == old.count { maxLength = minLength }
            Alerts.info(ADFGVXAnalysisTexts.error4 + cleaned)
            analyze()
        case .duplicateCharacters:
            // CT1 (since 2010) does nothing with repeated password characters
            finishAnalyze()
        case .empty, .valid:
            startSearch()
        }
    }

    private func startSearch() {
        let old = password
        let a = analysis, minL = minLength, maxL = maxLength, last = lastPasswordFound
        token = CancellationToken()
        let t = token
        running = true
        progress = 0
        status = "Searching for a transposition password..."
        let sink = ProgressSink(self)
        Task { @MainActor [weak self] in
            let r = await Task.detached(priority: .userInitiated) {
                a.searchNextPassword(minLength: minL, maxLength: maxL, start: old, lastPasswordFound: last, cancel: t) { tested, length, fraction in
                    Task { @MainActor in sink.update(tested: tested, length: length, fraction: fraction) }
                }
            }.value
            self?.searchFinished(r, old: old)
        }
    }

    /// Forwards progress of the background search to the model (main actor).
    @MainActor
    private final class ProgressSink {
        weak var model: ADFGVXAnalysisModel?
        init(_ model: ADFGVXAnalysisModel) { self.model = model }
        func update(tested: Int, length: Int, fraction: Double) {
            guard let m = model, m.running else { return }
            m.progress = fraction
            m.status = "Password length \(length): \(tested.formatted()) permutations checked..."
        }
    }

    func cancelSearch() { token.cancel() }

    private func searchFinished(_ r: ADFGVXAnalysis.SearchResult, old: String) {
        running = false
        progress = 0
        if r.cancelled {
            status = "Search canceled (\(r.tested.formatted()) permutations checked)."
            finishAnalyze()
            return
        }
        lastPasswordFound = r.password
        passwordChanged(r.password)
        if r.password.isEmpty && !iGotOne {
            status = "No password found (\(r.tested.formatted()) permutations checked)."
            Alerts.info(ADFGVXAnalysisTexts.error9)
        }
        if !r.password.isEmpty && (r.password != old || !iGotOne), let m = r.matrix {
            matrix = m
            iGotOne = true
            status = "Possible password found: \(r.password) (\(r.tested.formatted()) permutations checked)."
        } else if iGotOne {
            status = "No further passwords have been found."
            Alerts.info(ADFGVXAnalysisTexts.error9B)
            passwordChanged(old)
        }
        finishAnalyze()
    }

    private func finishAnalyze() {
        if !password.isEmpty {
            analysed = true
            forceEnabled = true
            resubstitute()
        } else {
            forceEnabled = false
        }
    }

    // MARK: "Übernehmen" (OnBnClickedButtonForce)

    func force() {
        guard !running else { return }
        switch ADFGVXAnalysis.checkPassword(password, alphabet: alphabet) {
        case .invalidCharacters:
            let cleaned = ADFGVXAnalysis.cleansePassword(password, alphabet: alphabet)
            passwordChanged(cleaned)
            minLength = max(1, min(26, cleaned.count))
            maxLength = minLength
            Alerts.info(ADFGVXAnalysisTexts.error4 + cleaned)
            force()
            return
        case .duplicateCharacters:
            break   // CT1: no change of the matrix
        case .empty, .valid:
            if password.isEmpty {
                Alerts.error(ADFGVXAnalysisTexts.error6)
                return
            }
            matrix = analysis.forcedMatrix(password: password)
            status = "Password \(password) applied."
        }
        analysed = true
        resubstitute()
    }

    // MARK: Stage 1 (matrix)

    /// Recomputes the current solution (CT1 `Resubstitute`).
    func resubstitute() {
        guard analysed, !password.isEmpty else { return }
        plaintext = analysis.plaintext(password: password, matrix: matrix)
    }

    enum CellInput { case clear, character(Character) }

    /// Edit of a matrix cell (CT1 OnEnChangeMxy + CheckInput). Returns true if the focus should
    /// move on to the next cell (CT1 NextDlgCtrl).
    func cellInput(row: Int, column: Int, _ input: CellInput) -> Bool {
        guard analysed else {
            Alerts.info(ADFGVXAnalysisTexts.error8)
            return false
        }
        var new: Character = ADFGVXAnalysis.unassigned
        if case .character(let ch) = input {
            let u = Character(ch.uppercased().count == 1 ? ch.uppercased() : String(ch))
            if ADFGVXAnalysis.symbols.contains(u) {
                var others: [(Int, Int)] = []
                for r in 0..<6 { for c in 0..<6 where (r, c) != (row, column) && matrix[r][c] == u { others.append((r, c)) } }
                if !others.isEmpty {
                    let prefix = u.isNumber ? ADFGVXAnalysisTexts.charExists1B : ADFGVXAnalysisTexts.charExists1A
                    if ADFGVXAnalysisTexts.askYesNo(prefix + String(u) + ADFGVXAnalysisTexts.charExists2) {
                        for (r, c) in others { matrix[r][c] = ADFGVXAnalysis.unassigned }
                    } else {
                        return false
                    }
                }
                new = u
            } else if u == " " || u == ADFGVXAnalysis.unassigned {
                new = ADFGVXAnalysis.unassigned
            } else {
                Alerts.error(ADFGVXAnalysisTexts.error11)
                new = ADFGVXAnalysis.unassigned
            }
        }
        matrix[row][column] = new
        resubstitute()
        return true
    }

    func clearMatrix() {
        guard ADFGVXAnalysisTexts.askYesNo(ADFGVXAnalysisTexts.matrixReset) else { return }
        matrix = ADFGVXAnalysis.emptyMatrix
        resubstitute()
    }

    func standardMatrix() {
        guard ADFGVXAnalysisTexts.askYesNo(ADFGVXAnalysisTexts.matrixReset) else { return }
        matrix = ADFGVXAnalysis.standardMatrix
        resubstitute()
    }

    /// CT1 "Zeichenkette eingeben".
    func applyString(_ s: String) {
        guard let m = ADFGVXAnalysis.matrix(fromString: s) else {
            Alerts.info(ADFGVXAnalysisTexts.noCharacters)
            return
        }
        matrix = m
        resubstitute()
    }

    /// CT1 paste button: password and matrix from the key store ("Übernehmen", then the matrix).
    func insertKey() {
        guard let key = KeyMemory.initial(for: "adfgvx", document: document), let k = ADFGVXAnalysis.parseKey(key) else { return }
        passwordChanged(filterToAlphabet(k.password))
        force()
        matrix = k.matrix
        analysed = !password.isEmpty
        resubstitute()
    }

    /// CT1 "Ausgabe": new document "ADFGVX-Entschlüsselung von <…>, Schlüssel <…>".
    func output() {
        guard !password.isEmpty else {
            Alerts.info(ADFGVXAnalysisTexts.error8)
            return
        }
        let text = analysis.plaintext(password: password, matrix: matrix)
        let key = ADFGVXAnalysis.keyString(password: password, matrix: matrix)
        if CipherRun.text(document, method: "adfgvx", name: "ADFGVX", encrypt: false, key: key, { text }) {
            window?.close()
        }
    }

    func cancel() {
        token.cancel()
        window?.close()
    }
}

// MARK: - Main view

struct ADFGVXAnalysisView: View {
    @ObservedObject var model: ADFGVXAnalysisModel
    @EnvironmentObject var settings: AppSettings
    @FocusState private var focusedCell: Int?
    @CTState private var showStringBox = false
    @CTState private var stringInput = ""

    private let labels = ADFGVXAnalysis.labels.map(String.init)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ciphertext: \(model.document.displayName ?? "") (\(model.analysis.count) characters)")
                .font(.callout).foregroundStyle(.secondary)
            transpositionGroup
            substitutionGroup
            VStack(alignment: .leading, spacing: 4) {
                Text("Current solution")
                ResultBox(text: model.plaintext, minHeight: 130)
            }
            if model.running || !model.status.isEmpty {
                HStack {
                    if model.running { ProgressView(value: model.progress).frame(width: 140) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    if model.running { Button("Cancel search") { model.cancelSearch() } }
                }
            }
            Divider()
            HStack {
                Button {
                    model.insertKey()
                } label: {
                    Label("Paste key", systemImage: "key")
                }
                .help(ADFGVXAnalysisTexts.pasteKey)
                .disabled(!model.hasStoredKey || model.running)
                Spacer()
                Button("Output") { model.output() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.outputEnabled)
                Button("Cancel") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 580, minHeight: 760, alignment: .topLeading)
        .onChange(of: settings.textOptions) { _, _ in model.textOptionsChanged() }
        .onChange(of: settings.referenceLanguage) { _, _ in model.applyReferenceStatistics() }
        .sheet(isPresented: $showStringBox) {
            ADFGVXAnalysisStringBox(input: $stringInput) { ok in
                showStringBox = false
                if ok { model.applyString(stringInput) }
            }
        }
    }

    // MARK: Stage 2

    private var transpositionGroup: some View {
        GroupBox("Step 2: Transposition") {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    GroupBox("Password length") {
                        HStack {
                            Picker("minimal", selection: Binding(get: { model.minLength }, set: { model.setMinLength($0) })) {
                                ForEach(1...26, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .frame(width: 110)
                            Picker("maximal", selection: Binding(get: { model.maxLength }, set: { model.setMaxLength($0) })) {
                                ForEach(1...26, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .frame(width: 115)
                        }
                        .padding(4)
                    }
                    Button("Text options") { OptionsWindows.showTextOptions() }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current password")
                    TextField("", text: Binding(get: { model.password }, set: { model.userEditedPassword($0) }))
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Text("Column sequence")
                    Text(model.numberedPassword.isEmpty ? " " : model.numberedPassword)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                    HStack {
                        Spacer()
                        Button("Apply") { model.force() }
                            .disabled(!model.forceEnabled || model.running)
                        Button("Analyze") { model.analyze() }
                            .disabled(model.running)
                    }
                }
            }
            .disabled(model.running)
            .padding(6)
            Text(model.frequencyInfo)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    // MARK: Stage 1

    private var substitutionGroup: some View {
        GroupBox("Step 1: Substitution") {
            HStack(alignment: .top, spacing: 18) {
                GroupBox("Substitution matrix") {
                    matrixGrid.padding(6)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Remaining possible solutions")
                    readOnlyField(model.remainingPossibilities)
                    Text("Not yet assigned characters")
                    readOnlyField(model.remainingCharacters.isEmpty ? " " : model.remainingCharacters)
                    HStack {
                        Button("Erase matrix entries") { model.clearMatrix() }
                        Button("Standard matrix") { model.standardMatrix() }
                    }
                    .disabled(!model.analysed)
                    Button("Enter string") {
                        stringInput = ""
                        showStringBox = true
                    }
                    .disabled(!model.analysed)
                }
            }
            .disabled(model.running)
            .padding(6)
        }
    }

    private func readOnlyField(_ s: String) -> some View {
        Text(s)
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.center)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }

    private var matrixGrid: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Text("")
                ForEach(0..<6, id: \.self) { c in
                    Text(labels[c]).font(.system(.callout, design: .monospaced).bold()).foregroundStyle(.secondary)
                }
            }
            ForEach(0..<6, id: \.self) { r in
                GridRow {
                    Text(labels[r]).font(.system(.callout, design: .monospaced).bold()).foregroundStyle(.secondary)
                    ForEach(0..<6, id: \.self) { c in cell(r, c) }
                }
            }
        }
    }

    private func cell(_ r: Int, _ c: Int) -> some View {
        let idx = r * 6 + c
        let focused = focusedCell == idx
        let value = model.matrix[r][c]
        return Text(String(value))
            .font(.system(.body, design: .monospaced).bold())
            .foregroundStyle(value == ADFGVXAnalysis.unassigned ? Color.secondary : Color.primary)
            .frame(width: 28, height: 26)
            .background(focused ? Color.accentColor.opacity(0.2) : Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(focused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: focused ? 2 : 1))
            .contentShape(Rectangle())
            .focusable()
            .focusEffectDisabled()
            .focused($focusedCell, equals: idx)
            .onTapGesture { focusedCell = idx }
            .onKeyPress(phases: .down) { press in handleKey(press, row: r, column: c) }
            .help("Bigram \(labels[r])\(labels[c]): type a character (space/delete = not assigned)")
    }

    private func handleKey(_ press: KeyPress, row: Int, column: Int) -> KeyPress.Result {
        let idx = row * 6 + column
        switch press.key {
        case .leftArrow: focusedCell = max(0, idx - 1); return .handled
        case .rightArrow: focusedCell = min(35, idx + 1); return .handled
        case .upArrow: focusedCell = idx >= 6 ? idx - 6 : idx; return .handled
        case .downArrow: focusedCell = idx < 30 ? idx + 6 : idx; return .handled
        case .delete, .deleteForward:
            DispatchQueue.main.async { _ = model.cellInput(row: row, column: column, .clear) }
            return .handled
        default: break
        }
        guard let ch = press.characters.first, press.characters.count == 1,
              !ch.isNewline, !(ch.asciiValue.map { $0 < 0x20 || $0 == 0x7F } ?? false),
              !press.modifiers.contains(.command) else { return .ignored }
        DispatchQueue.main.async {
            if model.cellInput(row: row, column: column, .character(ch)) {
                focusedCell = idx < 35 ? idx + 1 : nil
            }
        }
        return .handled
    }
}

// MARK: - Intro (DlgAdfgvxIntro)

struct ADFGVXAnalysisIntroView: View {
    static let defaultsKey = "CT1ADFGVXAnalysisNoIntro"
    let close: () -> Void
    @CTState private var noIntro = UserDefaults.standard.bool(forKey: ADFGVXAnalysisIntroView.defaultsKey)

    var body: some View {
        DialogScaffold(title: "Introduction to Analyzing ADFGVX Messages", minWidth: 520) {
            VStack(alignment: .leading, spacing: 10) {
                Text("The creation of an ADFGVX message is a two-step process: Step 1 performs a Polybius substitution, step 2 transforms the result by a column transposition (permutation). A ciphertext-only analysis of an ADFGVX message reverses those steps.")
                Text("By clicking the button \"Analyze\" in the grouping \"Step 2: Transposition\", the search for a potential transposition password is started (each click of the button continues the search for the next valid password) and the five most common letters that were used to validate the password are entered into the substitution matrix. Thus, the first step of the analysis runs automatically.")
                Text("When a transposition password is found, the analysis continues in the grouping \"Step 1: Substitution\". Now you can enter further characters into the substitution matrix manually. The result of the analysis is shown in the field \"Current solution\".")
            }
            .fixedSize(horizontal: false, vertical: true)
            Toggle("Do not show this dialog again", isOn: $noIntro)
                .onChange(of: noIntro) { _, v in UserDefaults.standard.set(v, forKey: ADFGVXAnalysisIntroView.defaultsKey) }
        } buttons: {
            Button("OK", action: close).keyboardShortcut(.defaultAction)
        }
        .frame(width: 540)
    }
}

// MARK: - String box (DlgAdfgvxStringBox)

struct ADFGVXAnalysisStringBox: View {
    @Binding var input: String
    let done: (Bool) -> Void

    var body: some View {
        DialogScaffold(title: "Substitution Password",
                       subtitle: "The characters (A–Z, 0–9) are entered into the substitution matrix row by row; duplicate characters are skipped, the remaining characters are appended.",
                       minWidth: 420) {
            TextField("", text: Binding(get: { input }, set: { input = String($0.uppercased().prefix(36)) }))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit { done(true) }
        } buttons: {
            Button("Cancel") { done(false) }.keyboardShortcut(.cancelAction)
            Button("OK") { done(true) }.keyboardShortcut(.defaultAction)
        }
    }
}
