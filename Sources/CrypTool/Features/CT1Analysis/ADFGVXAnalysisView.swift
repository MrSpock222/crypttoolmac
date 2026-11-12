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
        let window = WindowPresenter.tool(id: id, title: "Halbautomatische Analyse von ADFGVX",
                                          size: CGSize(width: 620, height: 820)) {
            ADFGVXAnalysisView(model: model)
        }
        window.identifier = NSUserInterfaceItemIdentifier(id)
        model.window = window
        if !UserDefaults.standard.bool(forKey: ADFGVXAnalysisIntroView.defaultsKey) {
            WindowPresenter.sheet(on: window, title: "Einführung in die Analyse von ADFGVX-Nachrichten") { close in
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
    static let error4 = "Ungültige Zeichen wurden entfernt. Gültige Zeichen sind alle\nBuchstaben des aktuell eingestellten CrypTool-Alphabets.\n"
    static let error6 = "Die Passwortlänge muss >0 sein!"
    static let error8 = "Bitte zuerst Transposition analysieren!"
    static let error9 = "Bei der Analyse des Transpositionsschrittes wurde keine gültige Permutation gefunden.\nDies kann zwei Gründe haben:\n\n1. Die Häufigkeitsverteilung der Buchstaben ist untypisch für deutsche oder englische Texte.\nDies tritt oft bei kurzen Nachrichten auf.\n\n2. Das verwendete Transpositionspasswort liegt nicht im Suchbereich der Analyse.\nSie sollten den Bereich der Passwortlänge verschieben."
    static let error9B = "Die Analyse hat die obere Grenze des Suchbereichs erreicht.\nEs wurden keine weiteren Passwörter gefunden."
    static let error11 = "Ungültiges Zeichen! Bitte nur 'A' bis 'Z' und '0' bis '9' eingeben!"
    static let charExists1A = "Der Buchstabe '"
    static let charExists1B = "Die Ziffer '"
    static let charExists2 = "' wurde bereits zugewiesen. \nWollen Sie die neue Zuordnung beibehalten? \n\nJa: Die alte Zuordnung wird gelöscht.\n\nNein: Die Änderung wird rückgängig gemacht."
    static let matrixReset = "Alle bisherigen Einträge der Substitutionsmatrix werden gelöscht!\nFortfahren?"
    static let noCharacters = "Sie haben keine Zeichen eingegeben, d.h. die Substitutionsmatrix wurde nicht verändert."
    static let referenceFileError = "Fehler beim Öffnen der Referenzdatei! Bitte wählen Sie unter dem Menü Optionen / Textoptionen eine geeignete Datei."
    static let pasteKey = "Schlüssel aus Schlüsselspeicher einfügen"

    /// Yes/No question (CT1 AfxMessageBox MB_YESNO).
    @MainActor
    static func askYesNo(_ message: String) -> Bool {
        let a = NSAlert()
        a.messageText = "CrypTool"
        a.informativeText = message
        a.addButton(withTitle: "Ja")
        a.addButton(withTitle: "Nein")
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
        frequencyInfo = "Referenzsprache \(s.referenceLanguage.displayName): Häufigkeitsfolge \(String(analysis.frequencyTable.prefix(10)))…, "
            + "ein Passwort gilt als möglich, wenn das häufigste Bigramm ≥ \(analysis.highestFrequency) % erreicht."
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
        status = "Suche nach einem Transpositionspasswort …"
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
            m.status = "Passwortlänge \(length): \(tested.formatted()) Permutationen geprüft …"
        }
    }

    func cancelSearch() { token.cancel() }

    private func searchFinished(_ r: ADFGVXAnalysis.SearchResult, old: String) {
        running = false
        progress = 0
        if r.cancelled {
            status = "Suche abgebrochen (\(r.tested.formatted()) Permutationen geprüft)."
            finishAnalyze()
            return
        }
        lastPasswordFound = r.password
        passwordChanged(r.password)
        if r.password.isEmpty && !iGotOne {
            status = "Kein Passwort gefunden (\(r.tested.formatted()) Permutationen geprüft)."
            Alerts.info(ADFGVXAnalysisTexts.error9)
        }
        if !r.password.isEmpty && (r.password != old || !iGotOne), let m = r.matrix {
            matrix = m
            iGotOne = true
            status = "Mögliches Passwort gefunden: \(r.password) (\(r.tested.formatted()) Permutationen geprüft)."
        } else if iGotOne {
            status = "Keine weiteren Passwörter gefunden."
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
            status = "Passwort \(password) übernommen."
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
            Text("Geheimtext: \(model.document.displayName ?? "") (\(model.analysis.count) Zeichen)")
                .font(.callout).foregroundStyle(.secondary)
            transpositionGroup
            substitutionGroup
            VStack(alignment: .leading, spacing: 4) {
                Text("Aktuelle Lösung")
                ResultBox(text: model.plaintext, minHeight: 130)
            }
            if model.running || !model.status.isEmpty {
                HStack {
                    if model.running { ProgressView(value: model.progress).frame(width: 140) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    if model.running { Button("Suche abbrechen") { model.cancelSearch() } }
                }
            }
            Divider()
            HStack {
                Button {
                    model.insertKey()
                } label: {
                    Label("Schlüssel einfügen", systemImage: "key")
                }
                .help(ADFGVXAnalysisTexts.pasteKey)
                .disabled(!model.hasStoredKey || model.running)
                Spacer()
                Button("Ausgabe") { model.output() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.outputEnabled)
                Button("Abbrechen") { model.cancel() }
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
        GroupBox("Stufe 2: Transposition") {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    GroupBox("Passwortlänge") {
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
                    Button("Textoptionen …") { OptionsWindows.showTextOptions() }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktuelles Passwort")
                    TextField("", text: Binding(get: { model.password }, set: { model.userEditedPassword($0) }))
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Text("Reihenfolge der Spalten")
                    Text(model.numberedPassword.isEmpty ? " " : model.numberedPassword)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                    HStack {
                        Spacer()
                        Button("Übernehmen") { model.force() }
                            .disabled(!model.forceEnabled || model.running)
                        Button("Analysieren") { model.analyze() }
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
        GroupBox("Stufe 1: Substitution") {
            HStack(alignment: .top, spacing: 18) {
                GroupBox("Substitutionsmatrix") {
                    matrixGrid.padding(6)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Verbleibende Möglichkeiten")
                    readOnlyField(model.remainingPossibilities)
                    Text("Noch nicht zugewiesene Zeichen")
                    readOnlyField(model.remainingCharacters.isEmpty ? " " : model.remainingCharacters)
                    HStack {
                        Button("Matrix leeren") { model.clearMatrix() }
                        Button("Standardmatrix") { model.standardMatrix() }
                    }
                    .disabled(!model.analysed)
                    Button("Zeichenkette eingeben …") {
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
            .help("Bigramm \(labels[r])\(labels[c]): Zeichen eintippen (Leertaste/Entf = nicht zugewiesen)")
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
        DialogScaffold(title: "Einführung in die Analyse von ADFGVX-Nachrichten", minWidth: 520) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ein ADFGVX-Chiffrat wird in 2 Stufen erstellt: Stufe 1 führt eine Polybius-Substitution durch, Stufe 2 wendet auf das Ergebnis eine Spalten-Transposition (Permutation) an. Die Ciphertext-only-Analyse eines ADFGVX-Chiffrats geht diese Schritte umgekehrt an.")
                Text("Wenn Sie in der Gruppierung „Stufe 2: Transposition“ auf „Analysieren“ drücken, wird für die zweite Stufe eine mögliche Passwort-Permutation gesucht (bei jedem Drücken wird versucht, ein weiteres gültiges Passwort zu finden) und die sich daraus schon zwingend ergebenden Zuordnungen werden in der Substitutionsmatrix eingetragen. Der erste Analyseschritt (Transpositionsanalyse) funktioniert also automatisch.")
                Text("Danach können Sie in der Gruppierung „Stufe 1: Substitution“ weitere Einträge von Hand in die Substitutionsmatrix eintragen. Das entsprechende Zwischenergebnis wird in dem Feld „Aktuelle Lösung“ angezeigt.")
            }
            .fixedSize(horizontal: false, vertical: true)
            Toggle("Diesen Dialog in Zukunft nicht mehr anzeigen", isOn: $noIntro)
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
        DialogScaffold(title: "Substitutionspasswort",
                       subtitle: "Die Zeichen (A–Z, 0–9) werden zeilenweise in die Substitutionsmatrix eingetragen; doppelte Zeichen werden übersprungen, die restlichen Zeichen werden angehängt.",
                       minWidth: 420) {
            TextField("", text: Binding(get: { input }, set: { input = String($0.uppercased().prefix(36)) }))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit { done(true) }
        } buttons: {
            Button("Abbrechen") { done(false) }.keyboardShortcut(.cancelAction)
            Button("OK") { done(true) }.keyboardShortcut(.defaultAction)
        }
    }
}
