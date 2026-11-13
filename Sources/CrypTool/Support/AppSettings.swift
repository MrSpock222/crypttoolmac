import AppKit
import Combine
import CTCommon

/// Persistent application settings (CT1 "Optionen" menu).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum ReferenceLanguage: String, CaseIterable, Identifiable {
        case german = "de", english = "en"
        var id: String { rawValue }
        var displayName: String { self == .german ? "German" : "English" }
        var fileName: String { self == .german ? "deutsch" : "english" }
    }

    @Published var textOptions: TextOptions { didSet { save() } }
    @Published var referenceLanguage: ReferenceLanguage { didSet { save(); _referenceText = nil } }
    @Published var showStartExample: Bool { didSet { save() } }
    @Published var fontSize: Double { didSet { save(); NotificationCenter.default.post(name: .ctFontChanged, object: nil) } }
    @Published var monospacedFont: Bool { didSet { save(); NotificationCenter.default.post(name: .ctFontChanged, object: nil) } }
    @Published var lineWrap: Bool { didSet { save(); NotificationCenter.default.post(name: .ctFontChanged, object: nil) } }
    /// Assumed most frequent plaintext character for XOR/addition analysis (CT1 analysis option).
    @Published var expectedMostFrequentByte: Int { didSet { save() } }
    @Published var vigenereMaxKeyLength: Int { didSet { save() } }
    @Published var substitutionRestarts: Int { didSet { save() } }

    /// Font from CT1's "Ansicht ▸ Schriftart" menu ("" = system monospaced font).
    @Published var fontName: String { didSet { save(); NotificationCenter.default.post(name: .ctFontChanged, object: nil) } }
    @Published var showToolbar: Bool { didSet { save(); NotificationCenter.default.post(name: .ctViewOptionsChanged, object: nil) } }
    @Published var showStatusBar: Bool { didSet { save(); NotificationCenter.default.post(name: .ctViewOptionsChanged, object: nil) } }
    /// CT1 "Ansicht ▸ Alphabet": grey out characters not in the alphabet.
    @Published var viewAlphabet: Bool { didSet { save(); NotificationCenter.default.post(name: .ctViewOptionsChanged, object: nil) } }
    @Published var viewEndOfLine: Bool { didSet { save(); NotificationCenter.default.post(name: .ctViewOptionsChanged, object: nil) } }
    @Published var viewWhitespace: Bool { didSet { save(); NotificationCenter.default.post(name: .ctViewOptionsChanged, object: nil) } }
    /// CT1 "Grafikoptionen".
    @Published var plotBarWidth: Int { didSet { save() } }
    @Published var plotLineWidth: Int { didSet { save() } }
    @Published var plotShowZeroLine: Bool { didSet { save() } }
    @Published var plotRelativeAutocorrelation: Bool { didSet { save() } }
    /// CT1 "Ansicht ▸ Balkendiagramm" (bar vs. curve diagram).
    @Published var plotAsBars: Bool { didSet { save() } }
    /// CT1 start option: show the "Wie Sie starten" dialog.
    @Published var showStartDialog: Bool { didSet { save() } }
    /// Custom reference file chosen with "Suchen …" in the text options (overrides the language).
    @Published var customReferencePath: String { didSet { save(); _referenceText = nil } }

    private let defaults = UserDefaults.standard
    private var _referenceText: String?

    private init() {
        if let data = defaults.data(forKey: "textOptions"),
           let o = try? JSONDecoder().decode(TextOptions.self, from: data) {
            textOptions = o
        } else {
            textOptions = .default
        }
        referenceLanguage = ReferenceLanguage(rawValue: defaults.string(forKey: "referenceLanguage") ?? "en") ?? .english
        showStartExample = defaults.object(forKey: "showStartExample") as? Bool ?? true
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 13
        monospacedFont = defaults.object(forKey: "monospacedFont") as? Bool ?? true
        lineWrap = defaults.object(forKey: "lineWrap") as? Bool ?? true
        expectedMostFrequentByte = defaults.object(forKey: "expectedMostFrequentByte") as? Int ?? 0x00
        vigenereMaxKeyLength = defaults.object(forKey: "vigenereMaxKeyLength") as? Int ?? 30
        substitutionRestarts = defaults.object(forKey: "substitutionRestarts") as? Int ?? 20
        fontName = defaults.string(forKey: "fontName") ?? "Courier New"
        showToolbar = defaults.object(forKey: "showToolbar") as? Bool ?? true
        showStatusBar = defaults.object(forKey: "showStatusBar") as? Bool ?? true
        viewAlphabet = defaults.object(forKey: "viewAlphabet") as? Bool ?? false
        viewEndOfLine = defaults.object(forKey: "viewEndOfLine") as? Bool ?? false
        viewWhitespace = defaults.object(forKey: "viewWhitespace") as? Bool ?? false
        plotBarWidth = defaults.object(forKey: "plotBarWidth") as? Int ?? 5
        plotLineWidth = defaults.object(forKey: "plotLineWidth") as? Int ?? 2
        plotShowZeroLine = defaults.object(forKey: "plotShowZeroLine") as? Bool ?? true
        plotRelativeAutocorrelation = defaults.object(forKey: "plotRelativeAutocorrelation") as? Bool ?? false
        plotAsBars = defaults.object(forKey: "plotAsBars") as? Bool ?? true
        showStartDialog = defaults.object(forKey: "showStartDialog") as? Bool ?? true
        customReferencePath = defaults.string(forKey: "customReferencePath") ?? ""
    }

    private func save() {
        if let data = try? JSONEncoder().encode(textOptions) { defaults.set(data, forKey: "textOptions") }
        defaults.set(referenceLanguage.rawValue, forKey: "referenceLanguage")
        defaults.set(showStartExample, forKey: "showStartExample")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(monospacedFont, forKey: "monospacedFont")
        defaults.set(lineWrap, forKey: "lineWrap")
        defaults.set(expectedMostFrequentByte, forKey: "expectedMostFrequentByte")
        defaults.set(vigenereMaxKeyLength, forKey: "vigenereMaxKeyLength")
        defaults.set(substitutionRestarts, forKey: "substitutionRestarts")
        defaults.set(fontName, forKey: "fontName")
        defaults.set(showToolbar, forKey: "showToolbar")
        defaults.set(showStatusBar, forKey: "showStatusBar")
        defaults.set(viewAlphabet, forKey: "viewAlphabet")
        defaults.set(viewEndOfLine, forKey: "viewEndOfLine")
        defaults.set(viewWhitespace, forKey: "viewWhitespace")
        defaults.set(plotBarWidth, forKey: "plotBarWidth")
        defaults.set(plotLineWidth, forKey: "plotLineWidth")
        defaults.set(plotShowZeroLine, forKey: "plotShowZeroLine")
        defaults.set(plotRelativeAutocorrelation, forKey: "plotRelativeAutocorrelation")
        defaults.set(plotAsBars, forKey: "plotAsBars")
        defaults.set(showStartDialog, forKey: "showStartDialog")
        defaults.set(customReferencePath, forKey: "customReferencePath")
    }

    /// Reference text for language statistics (bundled CT1 reference files).
    var referenceText: String {
        if let t = _referenceText { return t }
        if !customReferencePath.isEmpty, let d = FileManager.default.contents(atPath: customReferencePath) {
            let t = TextCoding.string(from: [UInt8](d))
            _referenceText = t
            return t
        }
        let t = Resources.text("Reference/\(referenceLanguage.fileName).txt") ?? ""
        _referenceText = t
        return t
    }

    /// Name of the reference file shown in the text options.
    var referenceFileDisplayName: String {
        customReferencePath.isEmpty ? "\(referenceLanguage.fileName).txt" : (customReferencePath as NSString).lastPathComponent
    }

    /// Editor font. CT1 sizes are Windows points (96 dpi); they are scaled by 4/3 so that
    /// "Courier 10" looks the same size as on a Windows PC.
    var editorFont: NSFont {
        if !fontName.isEmpty, let f = NSFont(name: fontName, size: fontSize) { return f }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    /// Applies a CT1 font menu entry ("Arial 10", "Courier 12" …).
    func applyCT1Font(_ family: String, points: Int) {
        fontName = family == "Arial" ? "Arial" : "Courier New"
        fontSize = (Double(points) * 4 / 3).rounded()
    }

    func isCT1Font(_ family: String, points: Int) -> Bool {
        let name = family == "Arial" ? "Arial" : "Courier New"
        return fontName == name && Int(fontSize) == Int((Double(points) * 4 / 3).rounded())
    }
}

extension Notification.Name {
    static let ctFontChanged = Notification.Name("CTFontChanged")
    static let ctViewOptionsChanged = Notification.Name("CTViewOptionsChanged")
}

/// Locates bundled resources: inside the .app (Contents/Resources) or, when started via
/// `swift run`, in the repository's Resources folder.
enum Resources {
    static var baseURL: URL {
        if let r = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: r.appendingPathComponent("Reference").path) {
            return r
        }
        // Sources/CrypTool/Support/AppSettings.swift → repo root
        let here = URL(fileURLWithPath: #filePath)
        return here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources")
    }

    static func url(_ relative: String) -> URL? {
        let u = baseURL.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    static func text(_ relative: String) -> String? {
        guard let u = url(relative), let d = try? Data(contentsOf: u) else { return nil }
        return TextCoding.string(from: [UInt8](d))
    }
}
