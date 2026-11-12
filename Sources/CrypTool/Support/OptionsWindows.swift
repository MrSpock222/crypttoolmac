import AppKit
import SwiftUI
import CTCommon

/// CT1 "Optionen" dialogs, laid out like the originals (IDD_TEXT_OPTIONS, IDD_OPTIONS_ANALYSIS,
/// IDD_DIALOG_PLOT_PARAM, IDD_STARTOPTIONS).
@MainActor
enum OptionsWindows {
    static func showTextOptions() {
        WindowPresenter.tool(id: "textoptions", title: "Textoptionen", size: CGSize(width: 560, height: 600), resizable: false) {
            TextOptionsView()
        }
    }

    static func showAnalysisOptions() {
        WindowPresenter.tool(id: "analysisoptions", title: "Analyseoptionen", size: CGSize(width: 600, height: 640), resizable: false) {
            AnalysisOptionsView()
        }
    }

    static func showPlotOptions() {
        WindowPresenter.tool(id: "plotoptions", title: "Grafikoptionen", size: CGSize(width: 400, height: 260), resizable: false) {
            PlotOptionsView()
        }
    }

    static func showStartOptions() {
        WindowPresenter.tool(id: "startoptions", title: "Startoptionen", size: CGSize(width: 560, height: 200), resizable: false) {
            StartOptionsView()
        }
    }
}

/// Closes the hosting window of a SwiftUI view.
@MainActor
func closeKeyWindow() { NSApp.keyWindow?.performClose(nil) }

// MARK: - Textoptionen

struct TextOptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @CTState private var draft = TextOptions.default
    @CTState private var upper = true
    @CTState private var lower = false
    @CTState private var space = false
    @CTState private var special = false
    @CTState private var digits = false
    @CTState private var umlauts = false
    @CTState private var language: AppSettings.ReferenceLanguage = .german
    @CTState private var customPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Formatierungsoptionen für Klar- und Geheimtext") {
                Toggle("Nicht im Alphabet enthaltene Zeichen unverändert beibehalten", isOn: $draft.keepNonAlphabet)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Groß-/Kleinschreibung in Klar- und Geheimtext") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Wenn möglich bei der Ver-/Entschlüsselung Informationen zur Groß-/Kleinschreibung beibehalten", isOn: $draft.keepCase)
                        .disabled(draft.distinguishCase)
                    Toggle("Groß-/Kleinschreibung beachten", isOn: Binding(get: { draft.distinguishCase }, set: { on in
                        draft.distinguishCase = on
                        if on {
                            draft.keepCase = false
                        } else {
                            // CT1: alphabet is converted to upper case, duplicates removed
                            var seen = Set<Character>(), out = ""
                            for c in draft.alphabet.uppercased() where !seen.contains(c) { seen.insert(c); out.append(c) }
                            draft.alphabet = out
                            loadToggles()
                        }
                    }))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Alphabet für Texte definieren") {
                VStack(alignment: .leading, spacing: 6) {
                    Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 4) {
                        GridRow { Toggle("Großbuchstaben", isOn: group(\.upper)); Toggle("Kleinbuchstaben", isOn: group(\.lower)) }
                        GridRow { Toggle("Leerzeichen", isOn: group(\.space)); Toggle("Sonderzeichen", isOn: group(\.special)) }
                        GridRow { Toggle("Ziffern", isOn: group(\.digits)); Toggle("Umlaute", isOn: group(\.umlauts)) }
                    }
                    Text("Zu verwendendes Alphabet: (\(draft.alphabetSize) Zeichen)").font(.callout)
                    TextField("", text: Binding(get: { draft.alphabet }, set: { new in
                        // CT1 only allows its known character set
                        draft.alphabet = String(new.filter { TextOptions.allowedCharacters.contains($0) })
                        loadToggles()
                    })).font(.system(.body, design: .monospaced))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Referenzdatei für statistische Anwendungen") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(customPath.isEmpty ? "\(language.fileName).txt" : (customPath as NSString).lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                        Button("Suchen …", action: chooseFile)
                    }
                    Picker("", selection: $language) {
                        ForEach(AppSettings.ReferenceLanguage.allCases) { Text("\($0.displayName) (\($0.fileName).txt)").tag($0) }
                    }
                    .labelsHidden()
                    .onChange(of: language) { _, _ in customPath = "" }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Übernehmen", action: apply).keyboardShortcut(.defaultAction)
                Button("Standard wiederherstellen") {
                    draft = .default
                    loadToggles()
                }
                Spacer()
                Button("Abbrechen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear {
            draft = settings.textOptions
            language = settings.referenceLanguage
            customPath = settings.customReferencePath
            loadToggles()
        }
    }

    private func chooseFile() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.plainText, .text]
        p.allowsOtherFileTypes = true
        if p.runModal() == .OK, let u = p.url { customPath = u.path }
    }

    private func apply() {
        settings.textOptions = draft
        settings.referenceLanguage = language
        settings.customReferencePath = customPath
        closeKeyWindow()
    }

    private func loadToggles() {
        let a = draft.alphabet
        upper = a.contains { TextOptions.uppercaseLetters.contains($0) || TextOptions.umlautsUpper.contains($0) }
        lower = a.contains { TextOptions.lowercaseLetters.contains($0) || TextOptions.umlautsLower.contains($0) }
        space = a.contains(" ")
        special = a.contains { TextOptions.specialCharacters.contains($0) }
        digits = a.contains { TextOptions.digits.contains($0) }
        umlauts = a.contains { (TextOptions.umlautsUpper + TextOptions.umlautsLower).contains($0) }
    }

    private enum Group { case upper, lower, space, special, digits, umlauts }

    /// CT1 checkbox semantics: ticking appends the group's missing characters to the end of the
    /// current alphabet (order of clicks matters, as in CT1), unticking removes them.
    private func group(_ g: KeyPath<TextOptionsView, Bool>) -> Binding<Bool> {
        Binding(get: { self[keyPath: g] }, set: { on in
            switch g {
            case \TextOptionsView.upper:
                upper = on
                if on { draft.addCharacters(TextOptions.uppercaseLetters); if umlauts { draft.addCharacters(TextOptions.umlautsUpper) } }
                else { draft.removeCharacters(TextOptions.uppercaseLetters + TextOptions.umlautsUpper) }
            case \TextOptionsView.lower:
                lower = on
                if on { draft.addCharacters(TextOptions.lowercaseLetters); if umlauts { draft.addCharacters(TextOptions.umlautsLower) } }
                else { draft.removeCharacters(TextOptions.lowercaseLetters + TextOptions.umlautsLower) }
                if on && upper { draft.distinguishCase = true; draft.keepCase = false }
            case \TextOptionsView.space:
                space = on
                if on { draft.addCharacters(" ") } else { draft.removeCharacters(" ") }
            case \TextOptionsView.special:
                special = on
                if on { draft.addCharacters(TextOptions.specialCharacters) } else { draft.removeCharacters(TextOptions.specialCharacters) }
            case \TextOptionsView.digits:
                digits = on
                if on { draft.addCharacters(TextOptions.digits) } else { draft.removeCharacters(TextOptions.digits) }
            default:
                umlauts = on
                if on {
                    if upper { draft.addCharacters(TextOptions.umlautsUpper) }
                    if lower { draft.addCharacters(TextOptions.umlautsLower) }
                } else {
                    draft.removeCharacters(TextOptions.umlautsUpper + TextOptions.umlautsLower)
                }
            }
        })
    }
}

// MARK: - Analyseoptionen

struct AnalysisOptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @AppStorage("analysis.caesarShowKey") private var caesarKey = true
    @AppStorage("analysis.caesarCorrelation") private var caesarCorrelation = true
    @AppStorage("analysis.caesarHistograms") private var caesarHistograms = false
    @AppStorage("analysis.vigKey") private var vigKey = true
    @AppStorage("analysis.vigKeyLength") private var vigKeyLength = true
    @AppStorage("analysis.vigAutocorrelation") private var vigAuto = true
    @AppStorage("analysis.vigMore") private var vigMore = false
    @AppStorage("analysis.schroedelVerbose") private var schroedelVerbose = false
    @AppStorage("analysis.bruteForceBytes") private var bruteBytes = 128
    @AppStorage("analysis.bruteForceCharset") private var bruteCharset = 0
    @CTState private var expectedHex = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Umfang der Ausgabe bei der automatischen Analyse") {
                HStack(alignment: .top, spacing: 16) {
                    GroupBox("Caesar") {
                        VStack(alignment: .leading) {
                            Toggle("Ermittelter Schlüssel", isOn: $caesarKey)
                            Toggle("Korrelation", isOn: $caesarCorrelation)
                            Toggle("Histogramme", isOn: $caesarHistograms)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Vigenère, XOR, Addition") {
                        VStack(alignment: .leading) {
                            Toggle("Ermittelter Schlüssel", isOn: $vigKey)
                            Toggle("Ermittelte Schlüssellänge", isOn: $vigKeyLength)
                            Toggle("Autokorrelation", isOn: $vigAuto)
                            Toggle("Weitere Analyse-Werte ausgeben", isOn: $vigMore)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(4)
            }
            GroupBox("Optionen für die Vigenère-Analyse nach Schrödel") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Ausführliche Protokollierung", isOn: $schroedelVerbose)
                    LabeledContent("Wörterbuch:", value: "VigenereAnalysisSchroedelDictionary.txt")
                    LabeledContent("Digramm-Datei:", value: "VigenereAnalysisSchroedelDigrams.txt")
                    LabeledContent("Trigramm-Datei:", value: "VigenereAnalysisSchroedelTrigrams.txt")
                }.font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Optionen für Brute-Force-Angriffe gegen moderne symmetrische Algorithmen") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Siehe Menü: Analyse \\ Symmetrische Verschlüsselung (modern)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Anzahl der Bytes aus dem Geheimtextdokument für den Entropietest:")
                        TextField("", value: $bruteBytes, format: .number).frame(width: 60)
                    }
                    Text("Zeichensatz für den zu erwartenden Klartext")
                    Picker("", selection: $bruteCharset) {
                        Text("Alle 256 Zeichen").tag(0)
                        Text("Druckbare Zeichen (ASCII 32 - 256)").tag(1)
                        Text("Zeichensatz, wie in Menü: Optionen \\ Textoptionen definiert").tag(2)
                    }.pickerStyle(.radioGroup).labelsHidden()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Weitere Optionen (macOS-Version)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Erwartetes häufigstes Zeichen bei XOR/Addition (Hex):")
                        TextField("", text: $expectedHex).frame(width: 40)
                    }
                    Stepper("Maximale Vigenère-Schlüssellänge: \(settings.vigenereMaxKeyLength)", value: $settings.vigenereMaxKeyLength, in: 2...100)
                    Stepper("Neustarts der automatischen Substitutions-Analyse: \(settings.substitutionRestarts)", value: $settings.substitutionRestarts, in: 1...200)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Übernehmen") { applyHex(); closeKeyWindow() }.keyboardShortcut(.defaultAction)
                Button("Standard wiederherstellen") {
                    caesarKey = true; caesarCorrelation = true; caesarHistograms = false
                    vigKey = true; vigKeyLength = true; vigAuto = true; vigMore = false
                    schroedelVerbose = false; bruteBytes = 128; bruteCharset = 0; expectedHex = "00"
                }
                Spacer()
                Button("Abbrechen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear { expectedHex = String(format: "%02X", settings.expectedMostFrequentByte) }
    }

    private func applyHex() {
        if let b = Hex.decode(expectedHex), b.count == 1 { settings.expectedMostFrequentByte = Int(b[0]) }
    }
}

// MARK: - Grafikoptionen

struct PlotOptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @CTState private var bar = 5
    @CTState private var line = 2
    @CTState private var zero = true
    @CTState private var relative = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper("Balkenstärke (1, …, 10): \(bar)", value: $bar, in: 1...10)
            Stepper("Kurvenstärke (1, …, 10): \(line)", value: $line, in: 1...10)
            Toggle("Nulllinie anzeigen", isOn: $zero)
            Toggle("Relative Anzeige bei Autokorrelation", isOn: $relative)
            Spacer(minLength: 0)
            HStack {
                Button("Übernehmen") {
                    settings.plotBarWidth = bar; settings.plotLineWidth = line
                    settings.plotShowZeroLine = zero; settings.plotRelativeAutocorrelation = relative
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear {
            bar = settings.plotBarWidth; line = settings.plotLineWidth
            zero = settings.plotShowZeroLine; relative = settings.plotRelativeAutocorrelation
        }
    }
}

// MARK: - Startoptionen

struct StartOptionsView: View {
    @EnvironmentObject var settings: AppSettings
    @CTState private var dialog = true
    @CTState private var example = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Den \"Wie Sie starten\"-Dialog beim Programmstart von CrypTool anzeigen.", isOn: $dialog)
            Toggle("Die Beispieldatei wird nach dem Start von CrypTool automatisch geöffnet.", isOn: $example)
            Spacer(minLength: 0)
            HStack {
                Button("OK") {
                    settings.showStartDialog = dialog
                    settings.showStartExample = example
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear { dialog = settings.showStartDialog; example = settings.showStartExample }
    }
}
