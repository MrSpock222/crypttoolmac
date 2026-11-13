import AppKit
import SwiftUI
import CTCommon

/// Dispatches menu commands to the individual features.
@MainActor
enum ActionRouter {
    /// Last executed command – used for F1 (context help of the current dialog/tool).
    private(set) static var lastAction: CTAction?

    static func perform(_ action: CTAction, document doc: CTDocument?, window: NSWindow?) {
        if ContextHelp.consume(action) { return }
        let settings = AppSettings.shared
        switch action {
        // Datei / Bearbeiten
        case .documentProperties: if let doc { CT1DocumentDialogs.showProperties(doc) }
        case .showKey: if let doc { CT1DocumentDialogs.showKey(doc) }
        case .gotoParent:
            doc?.origin?.parent?.windowControllers.first?.window?.makeKeyAndOrderFront(nil)
        case .editHex: if let doc { DocumentActions.editHex(doc, window: window) }
        case .openExample(let name): DocumentFactory.openExample(name)

        // Ansicht
        case .toggleToolbar: settings.showToolbar.toggle()
        case .toggleStatusBar: settings.showStatusBar.toggle()
        case .viewAlphabet: settings.viewAlphabet.toggle()
        case .viewEndOfLine: settings.viewEndOfLine.toggle()
        case .viewWhitespace: settings.viewWhitespace.toggle()
        case .toggleLineWrap: settings.lineWrap.toggle()
        case .plotAsBars: settings.plotAsBars.toggle()
        case .font(let family, let points): settings.applyCT1Font(family, points: points)
        case .fontLarger: settings.fontSize = min(settings.fontSize + 1, 48)
        case .fontSmaller: settings.fontSize = max(settings.fontSize - 1, 8)
        case .formatTextDocument: if let doc { DocumentActions.formatText(doc, window: window) }

        // Optionen
        case .plotOptions: OptionsWindows.showPlotOptions()
        case .textOptions: OptionsWindows.showTextOptions()
        case .analysisOptions: OptionsWindows.showAnalysisOptions()
        case .startOptions: OptionsWindows.showStartOptions()

        // Fenster
        case .windowCascade: WindowArranger.cascade()
        case .windowTile: WindowArranger.tile()
        case .windowArrangeIcons: WindowArranger.arrangeMinimized()
        case .windowCloseAll: WindowArranger.closeAll()

        // Hilfe
        case .helpStart: HelpLink.startPage()
        case .helpIndex: HelpLink.index()
        case .helpScenarios: HelpLink.scenarios()
        case .contextHelp: HelpLink.contextHelp()
        case .about: AboutDialog.show()
        case .helpWebsite: NSWorkspace.shared.open(URL(string: "https://www.cryptool.org/en/ct1/")!)
        case .helpReadme: HelpCenter.show(action: action)
        case .helpLicense: HelpActions.showLicense()
        case .helpBook, .helpPresentation:
            // CT1 opens the PDF documents in the default PDF viewer
            let file = action == .helpBook ? "Docs/CT-Book-en.pdf" : "Docs/CrypTool1-Presentation-en.pdf"
            if let url = Resources.url(file) { NSWorkspace.shared.open(url) } else { HelpCenter.show(action: action) }
        case .show3DBox:
            let d = UserDefaults.standard
            d.set(!(d.object(forKey: "ct1.3d.showBox") as? Bool ?? true), forKey: "ct1.3d.showBox")

        default:
            lastAction = action
            FeatureRouter.perform(action, document: doc, window: window)
        }
    }

    /// Check marks for the toggle commands.
    static func validate(_ item: NSMenuItem, action: CTAction) -> Bool {
        let s = AppSettings.shared
        func mark(_ on: Bool) { item.state = on ? .on : .off }
        switch action {
        case .toggleToolbar: mark(s.showToolbar)
        case .toggleStatusBar: mark(s.showStatusBar)
        case .viewAlphabet: mark(s.viewAlphabet)
        case .viewEndOfLine: mark(s.viewEndOfLine)
        case .viewWhitespace: mark(s.viewWhitespace)
        case .toggleLineWrap: mark(s.lineWrap)
        case .plotAsBars: mark(s.plotAsBars)
        case .show3DBox: mark(UserDefaults.standard.object(forKey: "ct1.3d.showBox") as? Bool ?? true)
        case .font(let family, let points): mark(s.isCT1Font(family, points: points))
        default: break
        }
        return FeatureRouter.isAvailable(action)
    }
}

@MainActor
enum DocumentActions {
    static func showProperties(_ doc: CTDocument) {
        var lines: [String] = []
        lines.append("Window title: \(doc.displayName ?? "")")
        if let url = doc.fileURL { lines.append("Name of the file: \(url.path)") }
        lines.append("Document size: \(doc.bytes.count) bytes")
        lines.append("Document type: \(doc.isText ? "Text" : "Binary data")")
        if let o = doc.origin {
            if let p = o.parent { lines.append("Created from: \(p.displayName ?? "")") }
            if let k = o.key { lines.append("Key: \(k)") }
        }
        Alerts.info(lines.joined(separator: "\n"), title: "Document Properties")
    }

    static func showKey(_ doc: CTDocument) {
        guard let key = doc.origin?.key else { return }
        Alerts.infoWithCopy("Key: \(key)", title: "Show key", copyValue: key)
    }

    static func editHex(_ doc: CTDocument, window: NSWindow?) {
        WindowPresenter.sheet(on: window, title: "Edit hex values") { close in
            HexEditSheet(document: doc, close: close)
        }
    }

    static func formatText(_ doc: CTDocument, window: NSWindow?) {
        WindowPresenter.sheet(on: window, title: "Format Text Document") { close in
            FormatTextDialog(document: doc, close: close)
        }
    }
}

struct HexEditSheet: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var hex: String = ""
    @CTState private var error: String?

    var body: some View {
        DialogScaffold(title: "Edit hex values",
                       subtitle: "Bytes as hexadecimal digits (spaces and line breaks are ignored).",
                       minWidth: 560) {
            CodeEditor(text: $hex, minHeight: 300)
            if let error { Text(error).foregroundStyle(.red) }
        } buttons: {
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Apply") {
                guard let bytes = Hex.decode(hex) else { error = "Invalid hex input (only 0-9, A-F, even number of digits)."; return }
                document.bytes = bytes
                document.updateChangeCount(.changeDone)
                close()
            }.keyboardShortcut(.defaultAction)
        }
        .onAppear { hex = HexDump.editable(document.bytes) }
    }
}

/// CT1 "Textdokument formatieren" (IDD_FORMAT_TEXT_DOCUMENT).
struct FormatTextDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var removeNonAlphabet = true
    @CTState private var toUpper = false
    @CTState private var toLower = false
    @CTState private var blocks = false
    @CTState private var blockSize = 5

    var body: some View {
        DialogScaffold(title: "Format Text Document", minWidth: 420) {
            GroupBox("Formatting options") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Remove characters not in alphabet", isOn: $removeNonAlphabet)
                    Toggle("Convert to uppercase", isOn: $toUpper)
                        .onChange(of: toUpper) { _, on in if on { toLower = false } }
                    Toggle("Convert to lowercase", isOn: $toLower)
                        .onChange(of: toLower) { _, on in if on { toUpper = false } }
                    HStack {
                        Toggle("Divide in blocks of size", isOn: $blocks)
                        TextField("", value: $blockSize, format: .number).frame(width: 44).disabled(!blocks)
                    }
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            }
            AlphabetNote()
        } buttons: {
            Button("Text options") { OptionsWindows.showTextOptions() }
            Spacer()
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("OK", action: apply).keyboardShortcut(.defaultAction)
        }
    }

    private func apply() {
        let mapper = settings.textOptions.makeMapper()
        var out = ""
        for ch in document.text {
            if removeNonAlphabet && mapper.lookup(ch) == nil { continue }
            out.append(ch)
        }
        if toUpper { out = out.uppercased() }
        if toLower { out = out.lowercased() }
        if blocks, blockSize > 0 {
            var grouped = "", n = 0
            for ch in out where !ch.isWhitespace {
                if n > 0 && n % blockSize == 0 { grouped += " " }
                grouped.append(ch); n += 1
            }
            out = grouped
        }
        DocumentFactory.openResult(text: out, title: DocumentFactory.title("Formatting", of: document), parent: document)
        close()
    }
}

@MainActor
enum HelpActions {
    static func about() {
        let credits = NSAttributedString(string: """
        Native macOS port (Apple Silicon) of CrypTool 1.

        CrypTool 1 © CrypTool Team (www.cryptool.org), Apache License 2.0.
        AES candidates MARS, RC6, Serpent, Twofish: reference implementations of the respective authors.
        """, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "CrypTool for macOS",
            .credits: credits,
        ])
    }

    static func showReadme() {
        if let t = Resources.text("README.md") {
            DocumentFactory.openResult(text: t, title: "Readme")
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/cryptool-org/cryptool1")!)
        }
    }

    static func showLicense() {
        if let t = Resources.text("LICENSE") {
            DocumentFactory.openResult(text: t, title: "License")
        }
    }
}

/// CT1 "Fenster" menu: cascade / tile / close all.
@MainActor
enum WindowArranger {
    private static var documentWindows: [NSWindow] {
        NSApp.orderedWindows.filter { $0.windowController is DocumentWindowController && $0.isVisible && !$0.isMiniaturized }
    }

    static func cascade() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        var point = NSPoint(x: screen.minX + 20, y: screen.maxY - 20)
        for w in documentWindows.reversed() {
            w.setFrameTopLeftPoint(point)
            point = w.cascadeTopLeft(from: point)
            w.orderFront(nil)
        }
    }

    static func tile() {
        let wins = documentWindows
        guard !wins.isEmpty, let screen = NSScreen.main?.visibleFrame else { return }
        let cols = Int(ceil(sqrt(Double(wins.count))))
        let rows = Int(ceil(Double(wins.count) / Double(cols)))
        let w = screen.width / CGFloat(cols), h = screen.height / CGFloat(rows)
        for (i, win) in wins.enumerated() {
            let r = i / cols, c = i % cols
            win.setFrame(NSRect(x: screen.minX + CGFloat(c) * w, y: screen.maxY - CGFloat(r + 1) * h, width: w, height: h), display: true)
        }
    }

    static func arrangeMinimized() {
        NSApp.arrangeInFront(nil)
    }

    static func closeAll() {
        NSDocumentController.shared.closeAllDocuments(withDelegate: nil, didCloseAllSelector: nil, contextInfo: nil)
    }
}
