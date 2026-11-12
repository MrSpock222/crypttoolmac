import AppKit
import SwiftUI
import CTCommon
import CTAnalysis

// CT1 "Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸ Vigenère (Analyse nach
// Schrödel)" – dialog IDD_VIGENERE_ANALYSIS_SCHROEDEL with the language selection
// IDD_VIGENERE_ANALYSIS_SCHROEDEL_CHOOSE_LANGUAGES. The options CT1 keeps in "Analyseoptionen"
// (extensive logging, dictionary/digram/trigram files) are offered in the dialog itself.

extension CT1Analysis {
    /// Opens the Schrödel analysis dialog for the document (sheet on its window).
    static func openVigenereSchroedel(document: CTDocument) {
        let window = document.windowControllers.first?.window
        WindowPresenter.sheet(on: window, title: "Vigenère (Analyse nach Schrödel)") { close in
            VigenereSchroedelView(document: document, close: close)
        }
    }
}

/// Persistent options (CT1 registry key "VigenereAnalysisSchroedel").
enum VigenereSchroedelSettings {
    static let extensiveLoggingKey = "VigenereAnalysisSchroedel.ExtensiveLogging"
    static let dictionaryKey = "VigenereAnalysisSchroedel.DictionaryFile"
    static let digramsKey = "VigenereAnalysisSchroedel.DigramsFile"
    static let trigramsKey = "VigenereAnalysisSchroedel.TrigramsFile"

    static let dictionaryName = "VigenereAnalysisSchroedelDictionary.txt"
    static let digramsName = "VigenereAnalysisSchroedelDigrams.txt"
    static let trigramsName = "VigenereAnalysisSchroedelTrigrams.txt"

    static var extensiveLogging: Bool { UserDefaults.standard.bool(forKey: extensiveLoggingKey) }
    static func path(_ key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }

    /// Contents of a data file: user-chosen file (UTF-8 or CP1252) or the bundled CT1 file.
    @MainActor
    static func load(customPath: String, defaultName: String) throws -> String {
        let fileError = "Die folgende Datei konnte nicht geöffnet werden:\n"
        if !customPath.isEmpty {
            guard let d = FileManager.default.contents(atPath: customPath) else { throw CTError(fileError + customPath) }
            return TextCoding.string(from: [UInt8](d))
        }
        guard let t = CT1Analysis.wordFile(defaultName) else { throw CTError(fileError + "Words/" + defaultName) }
        return t
    }

    @MainActor private static var cache: (key: String, data: SchroedelLanguageData)?
    @MainActor static func cached(_ key: String) -> SchroedelLanguageData? { cache?.key == key ? cache?.data : nil }
    @MainActor static func store(_ data: SchroedelLanguageData, key: String) { cache = (key, data) }
}

@MainActor
final class VigenereSchroedelModel: ObservableObject {
    enum Phase { case idle, loading, choosingLanguages, running, finished }

    @Published var phase: Phase = .idle
    @Published var progress = 0.0
    /// Possible results with a dictionary match, newest first (CT1 inserts at the top).
    @Published var listed: [VigenereSchroedelResult] = []
    @Published var cleartextHeader = "Klartext:"
    @Published var showLanguageChooser = false
    @Published var report: VigenereSchroedelReport?
    private(set) var data: SchroedelLanguageData?
    private var token = CancellationToken()
    private var text = ""

    var isBusy: Bool { phase == .loading || phase == .choosingLanguages || phase == .running }

    /// "Analyse starten": load the data files (cached), then ask for the languages.
    func start(text: String) {
        self.text = text
        listed = []
        report = nil
        cleartextHeader = "Klartext:"
        progress = 0.01
        phase = .loading
        token = CancellationToken()
        let paths = [VigenereSchroedelSettings.path(VigenereSchroedelSettings.dictionaryKey),
                     VigenereSchroedelSettings.path(VigenereSchroedelSettings.digramsKey),
                     VigenereSchroedelSettings.path(VigenereSchroedelSettings.trigramsKey)]
        let cacheKey = paths.joined(separator: "\u{1}")
        if let d = VigenereSchroedelSettings.cached(cacheKey) {
            loaded(d)
            return
        }
        let dict: String, di: String, tri: String
        do {
            dict = try VigenereSchroedelSettings.load(customPath: paths[0], defaultName: VigenereSchroedelSettings.dictionaryName)
            di = try VigenereSchroedelSettings.load(customPath: paths[1], defaultName: VigenereSchroedelSettings.digramsName)
            tri = try VigenereSchroedelSettings.load(customPath: paths[2], defaultName: VigenereSchroedelSettings.trigramsName)
        } catch {
            phase = .idle
            progress = 0
            Alerts.info(error.localizedDescription)
            return
        }
        progress = 0.05
        Task.detached(priority: .userInitiated) {
            let d = SchroedelLanguageData.parse(dictionary: dict, digrams: di, trigrams: tri)
            await MainActor.run {
                VigenereSchroedelSettings.store(d, key: cacheKey)
                guard self.phase == .loading else { return }   // cancelled meanwhile
                self.loaded(d)
            }
        }
    }

    private func loaded(_ d: SchroedelLanguageData) {
        data = d
        progress = 0.10
        if d.keywordLanguages.isEmpty || d.ciphertextLanguages.isEmpty {
            phase = .idle
            progress = 0
            Alerts.info("Die Wörterbuch-, Digramm- und Trigramm-Dateien enthalten keine Abschnitte „[LANGUAGE …]“.")
            return
        }
        phase = .choosingLanguages
        showLanguageChooser = true
    }

    /// Language dialog closed with OK.
    func run(keywordLanguages: [String], ciphertextLanguage: String) {
        guard let data else { return }
        showLanguageChooser = false
        cleartextHeader = "Klartext (vermutete Sprache: \"\(ciphertextLanguage)\"):"
        phase = .running
        let t = token
        let text = self.text
        let extensive = VigenereSchroedelSettings.extensiveLogging
        Task.detached(priority: .userInitiated) {
            let outcome: Result<VigenereSchroedelReport, Error> = Result {
                try VigenereSchroedel.analyze(
                    ciphertext: text, data: data, keywordLanguages: keywordLanguages, ciphertextLanguage: ciphertextLanguage,
                    extensiveLogging: extensive, germanLocale: true, cancel: t,
                    progress: { p in Task { @MainActor in if self.phase == .running { self.progress = max(self.progress, p) } } },
                    found: { r in Task { @MainActor in
                        if self.phase == .running, !self.listed.contains(r) { self.listed.insert(r, at: 0) }
                    } })
            }
            await MainActor.run { self.finished(outcome) }
        }
    }

    /// Language dialog cancelled (CT1 would hang here; we return to the start state).
    func languageChoiceCancelled() {
        showLanguageChooser = false
        phase = .idle
        progress = 0
    }

    func cancel() {
        token.cancel()
        if phase == .loading { phase = .idle; progress = 0 }
    }

    private func finished(_ outcome: Result<VigenereSchroedelReport, Error>) {
        switch outcome {
        case .failure(let error):
            phase = .idle
            progress = 0
            DispatchQueue.main.async { Alerts.info(error.localizedDescription) }
        case .success(let r):
            report = r
            listed = r.listedResults.reversed()
            if r.completed { progress = 1 }
            phase = .finished
            var message: String
            if r.completed {
                message = "Die Analyse ist beendet."
                if !r.isSuccessful {
                    message += "\n\nEs wurden leider keine möglichen Lösungen gefunden.\n\nÜberprüfen Sie, ob Sie die richtige(n) Sprache(n) für Schlüsselwort und Geheimtext ausgewählt haben."
                }
            } else {
                message = "Die Analyse wurde nicht beendet."
            }
            DispatchQueue.main.async { Alerts.info(message) }
        }
    }
}

struct VigenereSchroedelView: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @StateObject private var model = VigenereSchroedelModel()
    @CTState private var selection: VigenereSchroedelResult.ID?
    @CTState private var showOptions = false

    var body: some View {
        DialogScaffold(title: "Vigenère (Analyse nach Schrödel)",
                       subtitle: "Sobald Sie die Analyse starten, werden mögliche Lösungen in die nachstehende Liste eingetragen. Detaillierte Informationen können Sie sich anzeigen lassen, wenn die Analyse vollständig beendet wurde.",
                       minWidth: 660) {
            Table(model.listed, selection: $selection) {
                TableColumn("Schlüssel:", value: \.key)
                    .width(min: 120, ideal: 200)
                TableColumn(model.cleartextHeader, value: \.cleartext)
            }
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 230)
            ProgressView(value: model.progress)
            DisclosureGroup("Optionen für die Vigenère-Analyse nach Schrödel", isExpanded: $showOptions) {
                VigenereSchroedelOptionsView()
                    .disabled(model.isBusy)
                    .padding(.top, 4)
            }
            Text("Schrödels Verfahren knackt kurze Geheimtexte, deren Schlüssel ein Wort aus dem Wörterbuch ist (Buchstaben A–Z; die Textoptionen werden nicht verwendet).")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } buttons: {
            Button("Analyse starten") { model.start(text: document.text) }
                .disabled(model.isBusy)
            Button("Analyse abbrechen") { model.cancel() }
                .disabled(!model.isBusy)
            Spacer()
            Button("Analyse-Ergebnisse anzeigen") {
                guard let r = model.report else { return }
                DocumentFactory.openResult(text: r.documentText,
                                           title: DocumentFactory.title("Vigenère-Analyse nach Schrödel", of: document),
                                           parent: document)
                close()
            }
            .disabled(model.report == nil || model.isBusy)
            Button("Schließen") { model.cancel(); close() }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isBusy)
        }
        .frame(minHeight: 460)
        .sheet(isPresented: $model.showLanguageChooser) {
            if let data = model.data {
                VigenereSchroedelLanguageChooser(
                    keywordLanguages: data.keywordLanguages,
                    ciphertextLanguages: data.ciphertextLanguages,
                    preferredCiphertextLanguage: settings.referenceLanguage == .german ? "German" : "English",
                    done: { k, c in model.run(keywordLanguages: k, ciphertextLanguage: c) },
                    cancel: { model.languageChoiceCancelled() })
            }
        }
    }
}

/// CT1 dialog "Sprachen auswählen".
struct VigenereSchroedelLanguageChooser: View {
    let keywordLanguages: [String]
    let ciphertextLanguages: [String]
    let done: ([String], String) -> Void
    let cancel: () -> Void
    @CTState private var keyword: Set<String>
    @CTState private var ciphertext: Set<String>

    init(keywordLanguages: [String], ciphertextLanguages: [String], preferredCiphertextLanguage: String,
         done: @escaping ([String], String) -> Void, cancel: @escaping () -> Void) {
        self.keywordLanguages = keywordLanguages
        self.ciphertextLanguages = ciphertextLanguages
        self.done = done
        self.cancel = cancel
        // CT1: all keyword languages checked; the ciphertext language defaults to the first entry –
        // here to the language of the reference text if available.
        _keyword = CTState(initialValue: Set(keywordLanguages))
        let pre = ciphertextLanguages.contains(preferredCiphertextLanguage) ? preferredCiphertextLanguage : ciphertextLanguages.first
        _ciphertext = CTState(initialValue: pre.map { [$0] } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sprachen auswählen").font(.title3.weight(.semibold))
            Text("Wählen Sie mindestens eine Sprache aus, in der nach möglichen Schlüsselworten gesucht werden soll; und wählen Sie genau eine Sprache, in welcher der Geheimtext ursprünglich verfasst wurde.")
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 16) {
                checklist("Sprache(n) für Schlüsselworte:", keywordLanguages, $keyword)
                checklist("Sprache für Klartext:", ciphertextLanguages, $ciphertext)
            }
            HStack {
                Spacer()
                Button("Abbrechen", action: cancel).keyboardShortcut(.cancelAction)
                Button("OK") {
                    guard !keyword.isEmpty, ciphertext.count == 1, let c = ciphertext.first else {
                        Alerts.info("Bitte wählen Sie MINDESTENS EINE Schlüsselwort-Sprache und GENAU EINE Geheimtext-Sprache aus.")
                        return
                    }
                    done(keywordLanguages.filter { keyword.contains($0) }, c)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 440)
    }

    private func checklist(_ title: String, _ items: [String], _ selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { selection.wrappedValue.contains(item) },
                            set: { on in
                                if on { selection.wrappedValue.insert(item) } else { selection.wrappedValue.remove(item) }
                            }))
                        .toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            .frame(height: 110)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
        }
        .frame(maxWidth: .infinity)
    }
}

/// CT1 "Analyseoptionen ▸ Optionen für die Vigenère-Analyse nach Schrödel".
struct VigenereSchroedelOptionsView: View {
    @AppStorage(VigenereSchroedelSettings.extensiveLoggingKey) private var extensiveLogging = false
    @AppStorage(VigenereSchroedelSettings.dictionaryKey) private var dictionaryFile = ""
    @AppStorage(VigenereSchroedelSettings.digramsKey) private var digramsFile = ""
    @AppStorage(VigenereSchroedelSettings.trigramsKey) private var trigramsFile = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Ausführliche Protokollierung", isOn: $extensiveLogging)
            fileRow("Wörterbuch:", $dictionaryFile, VigenereSchroedelSettings.dictionaryName, "Wörterbuch-Datei auswählen")
            fileRow("Digramm-Datei:", $digramsFile, VigenereSchroedelSettings.digramsName, "Digramm-Datei auswählen")
            fileRow("Trigramm-Datei:", $trigramsFile, VigenereSchroedelSettings.trigramsName, "Trigramm-Datei auswählen")
            HStack {
                Spacer()
                Button("Standard wiederherstellen") {
                    extensiveLogging = false
                    dictionaryFile = ""; digramsFile = ""; trigramsFile = ""
                }
            }
        }
    }

    private func fileRow(_ label: String, _ path: Binding<String>, _ defaultName: String, _ panelTitle: String) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            Text(path.wrappedValue.isEmpty ? "words/\(defaultName)" : path.wrappedValue)
                .lineLimit(1).truncationMode(.middle)
                .foregroundStyle(path.wrappedValue.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(path.wrappedValue.isEmpty ? "Mitgelieferte CT1-Datei" : path.wrappedValue)
            Button("Suchen …") {
                let panel = NSOpenPanel()
                panel.title = panelTitle
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url { path.wrappedValue = url.path }
            }
        }
    }
}
