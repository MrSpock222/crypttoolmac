import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CTCommon
import CTAnalysis

// CT1 substitution analyses:
//   Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸ Substitution …
//     → Methodenauswahl (Verfahren 1: Jakobsen / Verfahren 2: Hart) → Optionen → Analyse
//   Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Manuelle Analyse ▸ Substitution …
//     → "Substitutionsanalyse: Manuelle Nachbearbeitung"
// Texts, steps, options and result titles follow the German CT1 resources.

extension CT1Analysis {
    /// CT1 "Manuelle Analyse ▸ Substitution" (AnalyseMonoManual): manual post-processing dialog
    /// with an empty substitution.
    static func openManualSubstitution(document: CTDocument) {
        guard SubstitutionCT1Support.checkDocument(document) else { return }
        ManualSubstitutionCT1View.open(document: document, mapping: Array(repeating: -1, count: 26), convertUmlauts: true)
    }

    /// CT1 "Ciphertext-Only ▸ Substitution" (AutoAnaSubst): method choice, options, analysis.
    static func openAutomaticSubstitution(document: CTDocument) {
        guard SubstitutionCT1Support.checkDocument(document) else { return }
        WindowPresenter.sheet(on: document.windowControllers.first?.window,
                              title: "Methodenauswahl zur automatische Substitutionsanalyse") { close in
            AutomaticSubstitutionCT1Sheet(document: document, close: close)
        }
    }
}

// MARK: - Shared helpers

@MainActor
enum SubstitutionCT1Support {
    /// Key repository entry of the analysis results (CT1 IDS_ANALYSIS_SUBSTITUTION).
    static let analysisKeyMethod = "ct1-substitution-analysis"

    /// CT1 checks of the menu handlers: at least one letter; info if the document contains
    /// characters outside the static alphabet A–Z.
    static func checkDocument(_ doc: CTDocument) -> Bool {
        let bytes = doc.bytes
        let hasLetter = bytes.contains { ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) }
        guard hasLetter else {
            Alerts.error("Die Eingabe muss mindestens 1 (nicht unbedingt verschiedene) Buchstaben des eingestellten Alphabets enthalten. Das Alphabet können Sie unter Optionen \\ Textoptionen ändern.")
            return false
        }
        if bytes.contains(where: { $0 < 65 || $0 > 90 }) {
            Alerts.info("Die in CrypTool implementierten Algorithmen für die Analyse der Substitutions-Verschlüsselung arbeiten auf einem statischen Alphabet (A-Z).\n\nDas aktuell ausgewählte Dokument enthält aber auch Zeichen, die nicht zu diesem statischen Alphabet gehören.\n\nDie Ergebnisse der Analyse können daher falsch sein.")
        }
        return true
    }

    static func wordListName(_ language: CT1SubstLanguage) -> String {
        language == .german ? "SubstitutionAnalysisMethod2-de.txt" : "SubstitutionAnalysisMethod2-en.txt"
    }
}

/// Lets a SwiftUI view close the tool window it lives in.
final class SubstitutionCT1WindowHandle {
    weak var window: NSWindow?
    func close() { window?.close() }
}

/// Radio button row (CT1 BS_AUTORADIOBUTTON) with an optional description below.
private struct SubstitutionCT1Radio: View {
    let title: String
    let selected: Bool
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(title).foregroundStyle(enabled ? Color.primary : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Method choice and options (sheet)

struct AutomaticSubstitutionCT1Sheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings

    private enum Step { case choice, options1, options2 }
    @CTState private var step: Step = .choice
    @CTState private var algorithm = 1
    // Verfahren 1
    @CTState private var spaceInAlphabet = false
    @CTState private var noGUI = false
    // Verfahren 2
    @CTState private var automatic = true
    @CTState private var german = true
    @CTState private var wordListGerman: URL?
    @CTState private var wordListEnglish: URL?
    @CTState private var option1 = false
    @CTState private var option2 = false
    @CTState private var manualWithStoredKey = false
    @StateObject private var hart = HartRunModel()

    var body: some View {
        switch step {
        case .choice: choiceView
        case .options1: options1View
        case .options2: options2View
        }
    }

    // IDD_AUTO_SUBSTITUTION_ANALYSIS_ALGORITHM_CHOICE
    private var choiceView: some View {
        DialogScaffold(title: "Methodenauswahl zur automatische Substitutionsanalyse", minWidth: 560) {
            GroupBox("Bitte wählen Sie zwischen folgenden Algorithmen aus:") {
                VStack(alignment: .leading, spacing: 8) {
                    SubstitutionCT1Radio(title: "Verfahren 1 basierend auf der Häufigkeitsanalyse der Digramme im Text", selected: algorithm == 1) { algorithm = 1 }
                    description([
                        "Der Algorithmus analysiert die Häufigkeit einzelner Digramme im verschlüsselten Text und versucht, anhand einer Standardverteilung den Schlüssel zu erraten.",
                        "Dieses Verfahren eignet sich am besten für die Analyse längerer Texte.\nEine automatische Spracherkennung ist eingebaut. Das Verfahren arbeitet auch auf verschlüsselten Texten, die keine Leerzeichen enthalten.",
                        "Quelle: Thomas Jakobsen \"A Fast Method for Cryptanalysis of Substitution Ciphers\", Cryptologia 19:3, 1995",
                    ])
                    SubstitutionCT1Radio(title: "Verfahren 2 basierend auf der Erkennung der häufigsten Wörter einer Sprache", selected: algorithm == 2) { algorithm = 2 }
                    description([
                        "Die Analyse basiert auf einer Liste mit den häufigsten Wörtern der jeweiligen Sprache. Die Wörter des Chiffrats werden (ihrem Muster nach) mit den Wörtern in der Liste verglichen.",
                        "Bei jeder möglichen Zuordnung ergibt sich daraus eine (partielle) Substitution. Durch einen Suchbaum wird diejenige Substitution ermittelt, die mit den meisten partiellen Substitutionen verträglich ist.",
                        "Dieses Verfahren arbeitet mit deutschen und englischen Standardtexten. Die Leerzeichen müssen im Chiffrat an den richtigen Stellen enthalten sein.",
                        "Quelle: George W. Hart \"To Decode Short Cryptograms\", Communications of the ACM, Sept 1994, Vol 37, No.4",
                    ])
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } buttons: {
            Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            Button("OK") { step = algorithm == 1 ? .options1 : .options2 }.keyboardShortcut(.defaultAction)
        }
    }

    private func description(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(.leading, 24)
    }

    // IDD_OPTIONS_SUBSTITUTION_AUTO_ANALYSIS
    private var options1View: some View {
        DialogScaffold(title: "Automatische Substitutionsanalyse 1 - Optionen", minWidth: 420) {
            GroupBox("Leerzeichen") {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Das Leerzeichen wurde substituiert", isOn: $spaceInAlphabet)
                    Text("(d.h. durch einen anderen Buchstaben ersetzt).").font(.callout).foregroundStyle(.secondary).padding(.leading, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("GUI") {
                Toggle("Zwischenergebnisse nicht anzeigen (schneller).", isOn: $noGUI)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } buttons: {
            Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            Button("OK", action: startMethod1).keyboardShortcut(.defaultAction)
        }
    }

    private func startMethod1() {
        let reference = settings.referenceText
        let refName = "\(settings.referenceLanguage.fileName).txt"
        guard !reference.isEmpty else {
            Alerts.error("Der Analysevorgang wird abgebrochen, da ein Fehler beim Öffnen der folgenden Datei aufgetreten ist:\n \(refName)")
            return
        }
        let jakobsen = CT1SubstJakobsen(spaceInAlphabet: spaceInAlphabet)
        let text = document.text
        let count = jakobsen.validCharacterCount(text)
        let language = jakobsen.guessLanguage(text)
        let doc = document, nogui = noGUI
        close()
        if count < 200 {
            Alerts.info("Der eingegebene Text ist zu kurz, um verlässliche Ergebnisse zu produzieren. \nWie Versuche zeigen, braucht das Jakobsen-Verfahren eine Textlänge von mindestens 300 Zeichen. \nSollte die automatische Analyse fehlschlagen, können Sie es mit der manuellen Analyse versuchen.")
        }
        JakobsenSubstitutionCT1View.open(document: doc, jakobsen: jakobsen, language: language, validCharacters: count,
                                         reference: reference, referenceName: refName, noGUI: nogui)
    }

    // IDD_OPTIONS_SUBSTITUTION_ANALYSIS
    private var storedKey: String? {
        KeyMemory.initial(for: SubstitutionCT1Support.analysisKeyMethod, document: document)
    }

    private var options2View: some View {
        let lang: CT1SubstLanguage = german ? .german : .english
        let url = german ? wordListGerman : wordListEnglish
        let listShown = url?.path ?? "Words/" + SubstitutionCT1Support.wordListName(lang)
        return DialogScaffold(title: "Automatische Substitutionsanalyse 2 - Optionen",
                              subtitle: "Die automatische Substitutionsanalyse ist nur für deutsche bzw. englische Klartexte implementiert. Für alle anderen Sprachen sollte die Analyse manuell durchgeführt werden.",
                              minWidth: 480) {
            VStack(alignment: .leading, spacing: 4) {
                SubstitutionCT1Radio(title: "Automatische Analyse", selected: automatic, enabled: !hart.running) { automatic = true }
                SubstitutionCT1Radio(title: "Manuelle Analyse", selected: !automatic, enabled: !hart.running) { automatic = false }
            }
            GroupBox("Optionen für automatische Analyse") {
                VStack(alignment: .leading, spacing: 6) {
                    SubstitutionCT1Radio(title: "Der erwartete Klartext ist Deutsch.", selected: german, enabled: automatic) { german = true }
                    SubstitutionCT1Radio(title: "Der erwartete Klartext ist Englisch.", selected: !german, enabled: automatic) { german = false }
                    HStack {
                        Text(listShown).font(.system(.callout, design: .monospaced)).lineLimit(1).truncationMode(.head)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4).background(Color(nsColor: .textBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                        Button("Suchen...", action: chooseWordList).disabled(!automatic)
                    }
                    Text("Die Annahme, dass im Klartext der Buchstabe 'e' am häufigsten ist, verbessert oft das Ergebnis der automatischen Analyse:")
                        .font(.callout).foregroundStyle(automatic ? .primary : .secondary).fixedSize(horizontal: false, vertical: true)
                    Toggle("'e' als häufigstes Zeichen annehmen", isOn: Binding(get: { option1 }, set: { v in
                        option1 = v
                        if !v { option2 = false }      // CT1: deactivating option 1 deactivates option 2
                    })).padding(.leading, 12).disabled(!automatic)
                    Text("In deutschen Klartexten sind die Digramme 'en' und 'er' sehr häufig. Die erweiterte Analyse benutzt diese Annahme:")
                        .font(.callout).foregroundStyle(automatic ? .primary : .secondary).fixedSize(horizontal: false, vertical: true)
                    Toggle("erweiterte Analyse (deutscher Klartext)", isOn: Binding(get: { option2 }, set: { v in
                        option2 = v
                        if v { option1 = true }        // CT1: activating option 2 activates option 1
                    })).padding(.leading, 12).disabled(!automatic)
                }
                .padding(4).frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(hart.running)
            GroupBox("Optionen für manuelle Analyse") {
                Toggle("Manuelle Analyse mit dem gespeicherten Schlüssel.", isOn: $manualWithStoredKey)
                    .disabled(automatic || storedKey == nil || hart.running)
                    .padding(4).frame(maxWidth: .infinity, alignment: .leading)
            }
            if hart.running {
                ProgressView(value: hart.progress) {
                    Text("Substitutionsanalyse")
                } currentValueLabel: {
                    Text("Substitutionsanalyse erledigt: \(Int(hart.progress * 100))%")
                }
            }
        } buttons: {
            if hart.running {
                Button("Abbrechen") { hart.cancel() }.keyboardShortcut(.cancelAction)
            } else {
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
                Button("Starten", action: startMethod2).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func chooseWordList() {
        let panel = NSOpenPanel()
        panel.title = "Wortliste wählen"
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if german { wordListGerman = url } else { wordListEnglish = url }
    }

    private func startMethod2() {
        let doc = document
        if !automatic {
            var mapping = Array(repeating: -1, count: 26)
            if manualWithStoredKey, let key = storedKey { mapping = CT1SubstText.mapping(fromTitleKey: key) }
            close()
            ManualSubstitutionCT1View.open(document: doc, mapping: mapping, convertUmlauts: true)
            return
        }
        let lang: CT1SubstLanguage = german ? .german : .english
        let content: String?
        if let url = german ? wordListGerman : wordListEnglish {
            content = (try? Data(contentsOf: url)).map { TextCoding.string(from: [UInt8]($0)) }
        } else {
            content = CT1Analysis.wordFile(SubstitutionCT1Support.wordListName(lang))
        }
        guard let list = content else {
            let name = "Words/" + SubstitutionCT1Support.wordListName(lang)
            Alerts.error("Die mit CrypTool ausgelieferte Wortliste für die Substitutions-Analyse in \(german ? "Deutsch" : "Englisch") (\(name)) ist nicht vorhanden.")
            return
        }
        let words = CT1SubstHart.words(fromList: list)
        hart.start(text: doc.text, words: words, assumeE: option1, extended: option2) { result in
            close()
            // CT1: cancelling while the words are collected aborts; cancelling the search shows the
            // best substitution found so far in the post-processing dialog
            if result.cancelled && result.mapping.allSatisfy({ $0 < 0 }) { return }
            if result.frequencyTie {
                Alerts.info("Mehrere Zeichen sind gleich häufig.\nHäufigstes Zeichen wird nicht berücksichtigt.\nDadurch ist auch keine erweiterte Analyse möglich.")
            }
            ManualSubstitutionCT1View.open(document: doc, mapping: result.mapping, convertUmlauts: true)
        }
    }
}

/// Runs Verfahren 2 off the main thread (CT1 progress dialog "Substitutionsanalyse").
@MainActor
final class HartRunModel: ObservableObject {
    @Published var running = false
    @Published var progress = 0.0
    private var token = CancellationToken()

    func start(text: String, words: [[Int8]], assumeE: Bool, extended: Bool,
               completion: @escaping @MainActor (CT1SubstHart.Result) -> Void) {
        token = CancellationToken()
        let t = token
        running = true
        progress = 0
        Task.detached(priority: .userInitiated) {
            let r = CT1SubstHart.analyze(text, wordList: words, assumeE: assumeE, extended: extended, cancel: t) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run {
                self.running = false
                completion(r)
            }
        }
    }

    func cancel() { token.cancel() }
}

// MARK: - Verfahren 1 dialog (IDD_AUTO_SUBSTITUTION_ANALYSIS)

@MainActor
final class JakobsenSubstitutionCT1Model: ObservableObject {
    @Published var key: [Int]?
    @Published var displayText = "Die statistische Textanalyse wird durchgeführt. Bitte warten Sie..."
    @Published var finished = false
    let jakobsen: CT1SubstJakobsen
    let ciphertext: String
    private let token = CancellationToken()
    private let box = LatestKeyBox()
    private var timer: Timer?
    private var shownKey: [Int]?

    init(jakobsen: CT1SubstJakobsen, ciphertext: String) {
        self.jakobsen = jakobsen
        self.ciphertext = ciphertext
    }

    func start(reference: String, language: CT1SubstLanguage, noGUI: Bool) {
        let j = jakobsen, text = ciphertext, t = token, b = box
        Task.detached(priority: .userInitiated) {
            let r = j.analyze(text, reference: reference, language: language, cancel: t) { k in
                if !noGUI { b.set(k) }
            }
            b.set(r.key)
            b.finish()
        }
        // CT1 refreshes the dialog with a 300 ms timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let (k, done) = box.get()
        if let k, k != shownKey {
            shownKey = k
            key = k
            displayText = String(jakobsen.decrypt(ciphertext, key: k).prefix(30_000))
        }
        if done {
            finished = true
            timer?.invalidate(); timer = nil
        }
    }

    func stop() {
        token.cancel()
        timer?.invalidate(); timer = nil
    }

    /// Thread-safe hand-over of the latest key from the worker.
    private final class LatestKeyBox: @unchecked Sendable {
        private let lock = NSLock()
        private var key: [Int]?
        private var done = false
        func set(_ k: [Int]) { lock.lock(); key = k; lock.unlock() }
        func finish() { lock.lock(); done = true; lock.unlock() }
        func get() -> ([Int]?, Bool) { lock.lock(); defer { lock.unlock() }; return (key, done) }
    }
}

struct JakobsenSubstitutionCT1View: View {
    let document: CTDocument
    let language: CT1SubstLanguage
    let validCharacters: Int
    let referenceName: String
    let handle: SubstitutionCT1WindowHandle
    @ObservedObject var model: JakobsenSubstitutionCT1Model
    @CTState private var copied: String?

    static func open(document: CTDocument, jakobsen: CT1SubstJakobsen, language: CT1SubstLanguage, validCharacters: Int,
                     reference: String, referenceName: String, noGUI: Bool) {
        let model = JakobsenSubstitutionCT1Model(jakobsen: jakobsen, ciphertext: document.text)
        let handle = SubstitutionCT1WindowHandle()
        let w = WindowPresenter.tool(title: "Automatische Substitutionsanalyse mittels Digrammhäufigkeit",
                                     size: CGSize(width: 720, height: 600)) {
            JakobsenSubstitutionCT1View(document: document, language: language, validCharacters: validCharacters,
                                        referenceName: referenceName, handle: handle, model: model)
        }
        handle.window = w
        model.start(reference: reference, language: language, noGUI: noGUI)
    }

    private var alphabetLine: String { "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + (model.jakobsen.spaceInAlphabet ? "␣" : "") }
    private var keyLine: String {
        guard let k = model.key else { return String(repeating: " ", count: alphabetLine.count) }
        return CT1SubstJakobsen.keyString(k).replacingOccurrences(of: " ", with: "␣")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    GroupBox("Aktuelle Substitution (Schlüssel)") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alphabetLine)
                            Text(keyLine).foregroundStyle(.blue)
                        }
                        .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                    GroupBox("Referenzdatei für Sprachanalyse") {
                        Text(referenceName).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    GroupBox("Anzahl der validen Zeichen im Text") {
                        Text("\(validCharacters)").frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                    GroupBox("Erkannte Sprache") {
                        Text(language.displayName).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                }
                .frame(width: 230)
            }
            GroupBox("Aktuelles Substitutionsergebnis") {
                ScrollView {
                    Text(model.displayText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .frame(minHeight: 260)
                .background(Color(nsColor: .textBackgroundColor))
            }
            HStack {
                if !model.finished { ProgressView().controlSize(.small) }
                if let copied { Text(copied).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
                Button("Substitution akzeptieren", action: accept).keyboardShortcut(.defaultAction).disabled(model.key == nil)
                Button("Schlüssel kopieren", action: copyKey).disabled(model.key == nil)
                Button("Manuelle Analyse", action: manual).disabled(model.key == nil)
                Button("Abbrechen") { model.stop(); handle.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 520)
        .onDisappear { model.stop() }
    }

    /// CT1: new document "<Titel> -Substitution- <Schlüssel>" with the current result.
    private func accept() {
        guard let k = model.key else { return }
        model.stop()
        let keyText = CT1SubstJakobsen.keyString(k)
        DocumentFactory.openResult(text: model.jakobsen.decrypt(document.text, key: k),
                                   title: "\(document.shortName) -Substitution- \(keyText)",
                                   parent: document, method: "ct1-substitution-analysis-1", key: keyText)
        handle.close()
    }

    private func copyKey() {
        guard let k = model.key else { return }
        let keyText = CT1SubstJakobsen.keyString(k)
        copyToPasteboard(keyText)
        if !model.jakobsen.spaceInAlphabet { KeyMemory.remember(keyText, for: "substitution") }
        copied = "Schlüssel kopiert: \(keyText)"
    }

    private func manual() {
        guard let k = model.key else { return }
        if model.jakobsen.spaceInAlphabet {
            Alerts.info("Manuelle Analyse ist nicht möglich, \nda das Leerzeichen substituiert wurde \n(d.h. durch einen anderen Buchstaben ersetzt).")
            return
        }
        model.stop()
        let mapping = CT1SubstJakobsen.invert(k)
        let doc = document
        handle.close()
        // CT1 (ManualAnaSubst) works on the unchanged document here
        ManualSubstitutionCT1View.open(document: doc, mapping: mapping, convertUmlauts: false)
    }
}

// MARK: - Manual post-processing (IDD_MANUAL_SUBST_ANALYSIS)

@MainActor
final class ManualSubstitutionCT1Model: ObservableObject {
    /// Plaintext letter ('A'…'Z') or '*' for every ciphertext letter a…z.
    @Published private(set) var fields: [Character]
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    let initial: [Character]
    let symbols: [Int8]
    let counts: [Int]
    private var lastValid: [Character]
    private var history: [[Character]] = []
    private var historyIndex = 0

    init(text: String, mapping: [Int], convertUmlauts: Bool) {
        var f = [Character](repeating: "*", count: 26)
        for c in 0..<26 where c < mapping.count && mapping[c] >= 0 && mapping[c] < 26 { f[c] = CT1SubstText.letters[mapping[c]] }
        initial = f
        fields = f
        lastValid = f
        symbols = CT1SubstText.symbols(text, convertUmlauts: convertUmlauts)
        var cnt = [Int](repeating: 0, count: 26)
        for s in symbols where s != CT1SubstText.space { cnt[Int(s)] += 1 }
        counts = cnt
        history = [f]
    }

    var mapping: [Int] {
        fields.map { ch in ch == "*" ? -1 : Int(ch.asciiValue! - 65) }
    }

    var preview: String { CT1SubstText.display(symbols, mapping: mapping) }

    /// CT1 OnChange: lower case → upper case, invalid input → last valid value, collisions are
    /// resolved by the user.
    func input(_ index: Int, _ raw: String) {
        let old = fields[index]
        var ch: Character = "*"
        if !raw.isEmpty {
            if raw.count > 1 {
                ch = raw.first == old ? raw.last! : raw.first!
            } else {
                ch = raw.first!
            }
        }
        if let v = ch.asciiValue, v >= 97 && v <= 122 { ch = Character(Unicode.Scalar(v - 32)) }
        let valid = ch == "*" || (ch.asciiValue.map { $0 >= 65 && $0 <= 90 } ?? false)
        guard valid else {
            fields[index] = lastValid[index]
            objectWillChange.send()
            return
        }
        if ch == old { objectWillChange.send(); return }
        var f = fields
        f[index] = ch
        if ch != "*", let other = f.indices.first(where: { $0 != index && f[$0] == ch }) {
            let cipher = CT1SubstText.letters[index], otherCipher = CT1SubstText.letters[other]
            let message = "Ihre Eingabe: \(cipher) -> \(ch)\nkollidiert mit der Eingabe: \(otherCipher) -> \(ch)\n\nWollen Sie an Ihrer Eingabe trotzdem festhalten?\n\n\nBei JA wird Ihre Eingabe übernommen und das \nkollidierende Feld auf unbestimmt gesetzt.\n\n\nBei NEIN wird ihre Eingabe ignoriert und das Feld \nauf seinen letzten gültigen Wert zurückgesetzt."
            let alert = NSAlert()
            alert.messageText = "CrypTool"
            alert.informativeText = message
            alert.addButton(withTitle: "Ja")
            alert.addButton(withTitle: "Nein")
            if alert.runModal() == .alertFirstButtonReturn {
                f[other] = "*"
                lastValid[other] = "*"
            } else {
                fields[index] = lastValid[index]
                objectWillChange.send()
                return
            }
        }
        lastValid[index] = ch
        fields = f
        pushHistory()
    }

    private func pushHistory() {
        history.removeSubrange((historyIndex + 1)...)
        history.append(fields)
        historyIndex = history.count - 1
        updateFlags()
    }

    private func updateFlags() {
        canUndo = historyIndex > 0
        canRedo = historyIndex < history.count - 1
    }

    /// "Ergebnis der automatischen Analyse wieder herstellen".
    func restore() {
        fields = initial
        lastValid = initial
        history = [initial]
        historyIndex = 0
        updateFlags()
    }

    func undo() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        fields = history[historyIndex]
        lastValid = fields
        updateFlags()
    }

    func redo() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        fields = history[historyIndex]
        lastValid = fields
        updateFlags()
    }
}

struct ManualSubstitutionCT1View: View {
    let document: CTDocument
    let convertUmlauts: Bool
    let handle: SubstitutionCT1WindowHandle
    @ObservedObject var model: ManualSubstitutionCT1Model
    @CTState private var note: String?

    static func open(document: CTDocument, mapping: [Int], convertUmlauts: Bool) {
        let model = ManualSubstitutionCT1Model(text: document.text, mapping: mapping, convertUmlauts: convertUmlauts)
        let handle = SubstitutionCT1WindowHandle()
        let w = WindowPresenter.tool(title: "Substitutionsanalyse: Manuelle Nachbearbeitung", size: CGSize(width: 660, height: 640)) {
            ManualSubstitutionCT1View(document: document, convertUmlauts: convertUmlauts, handle: handle, model: model)
        }
        handle.window = w
    }

    private func binding(_ i: Int) -> Binding<String> {
        Binding(get: { String(model.fields[i]) },
                set: { v in DispatchQueue.main.async { model.input(i, v) } })
    }

    var body: some View {
        let total = max(1, model.counts.reduce(0, +))
        VStack(alignment: .leading, spacing: 10) {
            Text("In diesem Dialog sind Zeichen des Geheimtextes klein geschrieben und Zeichen des Klartextes groß geschrieben (Beispiel: a -->C bedeutet, dass das Zeichen 'a' in den Buchstaben 'C' entschlüsselt wird).")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Jede Änderung in der Substitutionsliste wird in der unteren Anzeige der Entschlüsselung angezeigt. Der aktuelle Zwischenstand der Entschlüsselung hilft Ihnen, weitere Substitutionen zu bestimmen.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let i = row * 7 + col
                            if i < 26 {
                                HStack(spacing: 4) {
                                    Text(verbatim: String(Character(Unicode.Scalar(UInt8(97 + i)))) + ":")
                                        .font(.system(.body, design: .monospaced))
                                    TextField("", text: binding(i))
                                        .font(.system(.body, design: .monospaced))
                                        .multilineTextAlignment(.center)
                                        .frame(width: 30)
                                }
                                .help(String(format: "Häufigkeit von '%@' im Geheimtext: %d (%.1f %%)",
                                             String(Character(Unicode.Scalar(UInt8(97 + i)))), model.counts[i],
                                             Double(model.counts[i]) * 100 / Double(total)))
                            } else {
                                Color.clear.frame(width: 1, height: 1)
                            }
                        }
                    }
                }
            }
            HStack {
                Button("Ergebnis der automatischen Analyse wieder herstellen") { model.restore() }
                Spacer()
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .help("Zurück (letzte Änderung rückgängig machen)").disabled(!model.canUndo)
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .help("Vor (rückgängig gemachte Änderung wiederherstellen)").disabled(!model.canRedo)
            }
            Text("Aktueller Zwischenstand:")
            ResultBox(text: model.preview, minHeight: 200)
            HStack {
                if let note { Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }
                Spacer()
                Button("Aktuellen Zwischenstand ausgeben", action: output).keyboardShortcut(.defaultAction)
                Button("Schlüssel kopieren", action: copyKey)
                Button("Abbrechen") { handle.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 560)
    }

    /// CT1: new document "Substitutionsanalyse von <…>, Schlüssel: <…>".
    private func output() {
        let mapping = model.mapping
        let key = CT1SubstText.titleKey(mapping)
        let text = CT1SubstText.output(document.text, mapping: mapping, convertUmlauts: convertUmlauts)
        KeyMemory.remember(key, for: SubstitutionCT1Support.analysisKeyMethod)
        DocumentFactory.openResult(text: text, title: "Substitutionsanalyse von <\(document.shortName)>, Schlüssel: <\(key)>",
                                   parent: document, method: SubstitutionCT1Support.analysisKeyMethod, key: key)
        handle.close()
    }

    /// CT1 "Schlüssel kopieren": unassigned letters are filled with the unused letters; the key is
    /// stored for the substitution dialog (as encryption alphabet, so that "Entschlüsseln" of the
    /// ciphertext yields the plaintext) and copied to the clipboard.
    private func copyKey() {
        let decryptionAlphabet = CT1SubstText.copyKey(model.mapping)
        let key = CT1SubstText.invertAlphabet(decryptionAlphabet)
        KeyMemory.remember(key, for: "substitution")
        copyToPasteboard(key)
        note = "Schlüssel (Substitution) kopiert: \(key)"
    }
}
