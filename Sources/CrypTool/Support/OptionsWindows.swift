import AppKit
import SwiftUI
import CTCommon

/// CT1 "Optionen" dialogs, laid out like the originals (IDD_TEXT_OPTIONS, IDD_OPTIONS_ANALYSIS,
/// IDD_DIALOG_PLOT_PARAM, IDD_STARTOPTIONS).
@MainActor
enum OptionsWindows {
    static func showTextOptions() {
        WindowPresenter.tool(id: "textoptions", title: "Text Options", size: CGSize(width: 560, height: 600), resizable: false) {
            TextOptionsView()
        }
    }

    static func showAnalysisOptions() {
        WindowPresenter.tool(id: "analysisoptions", title: "Analysis Options", size: CGSize(width: 600, height: 640), resizable: false) {
            AnalysisOptionsView()
        }
    }

    static func showPlotOptions() {
        WindowPresenter.tool(id: "plotoptions", title: "Drawing Parameters", size: CGSize(width: 400, height: 260), resizable: false) {
            PlotOptionsView()
        }
    }

    static func showStartOptions() {
        WindowPresenter.tool(id: "startoptions", title: "Starting Options", size: CGSize(width: 560, height: 200), resizable: false) {
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
    @CTState private var language: AppSettings.ReferenceLanguage = .english
    @CTState private var customPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Formatting options for cleartext and ciphertext") {
                Toggle("Keep characters not present in the alphabet unchanged", isOn: $draft.keepNonAlphabet)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Upper/lower case in cleartext and ciphertext") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("If possible, retain case information for encryption/decryption", isOn: $draft.keepCase)
                        .disabled(draft.distinguishCase)
                    Toggle("Distinguish between uppercase and lowercase", isOn: Binding(get: { draft.distinguishCase }, set: { on in
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
            GroupBox("Define the alphabet used in text ciphers") {
                VStack(alignment: .leading, spacing: 6) {
                    Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 4) {
                        GridRow { Toggle("Uppercase letters", isOn: group(\.upper)); Toggle("Lowercase letters", isOn: group(\.lower)) }
                        GridRow { Toggle("Space", isOn: group(\.space)); Toggle("Special characters", isOn: group(\.special)) }
                        GridRow { Toggle("Numerals", isOn: group(\.digits)); Toggle("Umlauts", isOn: group(\.umlauts)) }
                    }
                    Text("Alphabet to use (\(draft.alphabetSize) characters):").font(.callout)
                    TextField("", text: Binding(get: { draft.alphabet }, set: { new in
                        // CT1 only allows its known character set
                        draft.alphabet = String(new.filter { TextOptions.allowedCharacters.contains($0) })
                        loadToggles()
                    })).font(.system(.body, design: .monospaced))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Reference file for statistical applications") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(customPath.isEmpty ? "\(language.fileName).txt" : (customPath as NSString).lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                        Button("Find...", action: chooseFile)
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
                Button("Apply", action: apply).keyboardShortcut(.defaultAction)
                Button("Restore default") {
                    draft = .default
                    loadToggles()
                }
                Spacer()
                Button("Cancel", action: closeKeyWindow).keyboardShortcut(.cancelAction)
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
            GroupBox("Output options for automatic analysis") {
                HStack(alignment: .top, spacing: 16) {
                    GroupBox("Caesar") {
                        VStack(alignment: .leading) {
                            Toggle("Derived key", isOn: $caesarKey)
                            Toggle("Correlation", isOn: $caesarCorrelation)
                            Toggle("Histograms", isOn: $caesarHistograms)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Vigenère, XOR, Addition") {
                        VStack(alignment: .leading) {
                            Toggle("Derived key", isOn: $vigKey)
                            Toggle("Derived key length", isOn: $vigKeyLength)
                            Toggle("Autocorrelation", isOn: $vigAuto)
                            Toggle("Show further analysis results", isOn: $vigMore)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(4)
            }
            GroupBox("Options for the Vigenère analysis according to Schroedel") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Extensive logging", isOn: $schroedelVerbose)
                    LabeledContent("Dictionary:", value: "VigenereAnalysisSchroedelDictionary.txt")
                    LabeledContent("Digram file:", value: "VigenereAnalysisSchroedelDigrams.txt")
                    LabeledContent("Trigram file:", value: "VigenereAnalysisSchroedelTrigrams.txt")
                }.font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Options for brute-force attacks against modern symmetric algorithms") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("See menu: Analysis \\ Symmetric Encryption (modern)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Number of bytes of the ciphertext document used for the entropy test:")
                        TextField("", value: $bruteBytes, format: .number).frame(width: 60)
                    }
                    Text("Alphabet for the expected cleartext:")
                    Picker("", selection: $bruteCharset) {
                        Text("All 256 characters").tag(0)
                        Text("Printable characters (ascii 32 - 256)").tag(1)
                        Text("Characters as defined in menu: Options \\ Text Options").tag(2)
                    }.pickerStyle(.radioGroup).labelsHidden()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Further options (macOS version)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Expected most common character for XOR/Addition (hex):")
                        TextField("", text: $expectedHex).frame(width: 40)
                    }
                    Stepper("Maximum Vigenère key length: \(settings.vigenereMaxKeyLength)", value: $settings.vigenereMaxKeyLength, in: 2...100)
                    Stepper("Restarts of the automatic substitution analysis: \(settings.substitutionRestarts)", value: $settings.substitutionRestarts, in: 1...200)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Apply") { applyHex(); closeKeyWindow() }.keyboardShortcut(.defaultAction)
                Button("Restore default") {
                    caesarKey = true; caesarCorrelation = true; caesarHistograms = false
                    vigKey = true; vigKeyLength = true; vigAuto = true; vigMore = false
                    schroedelVerbose = false; bruteBytes = 128; bruteCharset = 0; expectedHex = "00"
                }
                Spacer()
                Button("Cancel", action: closeKeyWindow).keyboardShortcut(.cancelAction)
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
            Stepper("Bar width (1-10): \(bar)", value: $bar, in: 1...10)
            Stepper("Curve width (1-10): \(line)", value: $line, in: 1...10)
            Toggle("Show zero", isOn: $zero)
            Toggle("Autocorrelation in relative", isOn: $relative)
            Spacer(minLength: 0)
            HStack {
                Button("Apply") {
                    settings.plotBarWidth = bar; settings.plotLineWidth = line
                    settings.plotShowZeroLine = zero; settings.plotRelativeAutocorrelation = relative
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
                Spacer()
                Button("Cancel", action: closeKeyWindow).keyboardShortcut(.cancelAction)
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
            Toggle("Show dialog \"How to start\" when starting CrypTool.", isOn: $dialog)
            Toggle("Open the sample text file automatically when starting CrypTool.", isOn: $example)
            Spacer(minLength: 0)
            HStack {
                Button("OK") {
                    settings.showStartDialog = dialog
                    settings.showStartExample = example
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
                Spacer()
                Button("Cancel", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .onAppear { dialog = settings.showStartDialog; example = settings.showStartExample }
    }
}
