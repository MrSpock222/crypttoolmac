import AppKit
import SwiftUI
import CTCommon

/// Developer diagnostic (see `scripts/audit-layout.sh`): started with the environment variable
/// `CT_LAYOUT_AUDIT=<first item index>`, the app shows nothing, runs every menu command once and
/// prints the size each dialog would get. It finds dialogs that become wider or taller than a
/// screen, e.g. after text changes. Inactive in normal use.
@MainActor
enum LayoutAudit {
    static let isEnabled = ProcessInfo.processInfo.environment["CT_LAYOUT_AUDIT"] != nil

    private static var current = ""
    nonisolated(unsafe) private static var itemStarted = Date()
    nonisolated(unsafe) private static var itemIndex = -1

    /// Called by `WindowPresenter` instead of showing a window.
    static func record<V: View>(kind: String, title: String, declared: CGSize?, cap: CGFloat, content: V) {
        let free = NSHostingController(rootView: AnyView(content.environmentObject(AppSettings.shared)))
        let capped = NSHostingController(rootView: AnyView(IdealWidthCap(cap: cap) { content }.environmentObject(AppSettings.shared)))
        let ideal = free.view.fittingSize
        var size = capped.view.fittingSize
        if let d = declared { size = CGSize(width: max(size.width, d.width), height: max(size.height, d.height)) }
        if let dir = ProcessInfo.processInfo.environment["CT_LAYOUT_SHOTS"] {
            let name = String(title.prefix(40)).map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "_" }
            snapshot(capped, size: size, to: "\(dir)/\(String(format: "%03d", itemIndex))-\(kind)-\(String(name)).png")
        }
        let decl = declared.map { String(format: "%.0fx%.0f", $0.width, $0.height) } ?? "-"
        print(String(format: "DIALOG\t%@\t%@\t%@\tdeclared=%@\tideal=%.0fx%.0f\tsize=%.0fx%.0f",
                     current, kind, title, decl, ideal.width, ideal.height, size.width, size.height))
        fflush(stdout)
    }

    /// Renders the dialog into a PNG file without showing it (`CT_LAYOUT_SHOTS=<directory>`).
    private static func snapshot(_ host: NSHostingController<AnyView>, size: CGSize, to path: String) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentViewController = host
        window.setContentSize(size)
        guard let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// Called by `Alerts` instead of showing a modal alert.
    static func note(_ text: String) {
        print("NOTE\t\(current)\t\(text.replacingOccurrences(of: "\n", with: " ").prefix(120))")
        fflush(stdout)
    }

    /// Commands handled directly by `ActionRouter` that open a dialog; all other direct commands
    /// (toggles, fonts, help, window arrangement) would change settings or open other programs.
    private static func isAudited(_ a: CTAction) -> Bool {
        switch a {
        case .documentProperties, .editHex, .formatTextDocument,
             .plotOptions, .textOptions, .analysisOptions, .startOptions, .about:
            return true
        case .showKey, .gotoParent, .openExample, .toggleToolbar, .toggleStatusBar, .viewAlphabet, .viewEndOfLine,
             .viewWhitespace, .toggleLineWrap, .plotAsBars, .font, .fontLarger, .fontSmaller,
             .windowCascade, .windowTile, .windowArrangeIcons, .windowCloseAll,
             .helpStart, .helpIndex, .helpScenarios, .contextHelp, .helpWebsite, .helpReadme, .helpLicense,
             .helpBook, .helpPresentation, .show3DBox:
            return false
        default:
            return true
        }
    }

    static func run() {
        var items: [(String, CTAction)] = []
        func walk(_ menu: NSMenu, _ path: String) {
            for item in menu.items {
                let p = path.isEmpty ? item.title : path + " > " + item.title
                if let a = item.ctAction { items.append((p, a)) }
                if let sub = item.submenu { walk(sub, p) }
            }
        }
        walk(MainMenu.build(), "")

        let start = Int(ProcessInfo.processInfo.environment["CT_LAYOUT_AUDIT"] ?? "") ?? 0
        let name = "Startingexample-en.txt"
        let data = Resources.url("Examples/\(name)").flatMap { try? Data(contentsOf: $0) } ?? Data("CrypTool".utf8)
        let doc = CTDocument(bytes: TextCoding.bytes(from: TextCoding.string(from: [UInt8](data))),
                             origin: DocumentOrigin(title: name, method: nil, key: nil, parent: nil), viewMode: nil)

        // A command that blocks in a modal panel cannot be measured: report it and stop, the
        // script continues with the next item.
        Thread.detachNewThread {
            while true {
                Thread.sleep(forTimeInterval: 0.5)
                if itemIndex >= 0 && Date().timeIntervalSince(itemStarted) > 6 {
                    print("HANG\t\(itemIndex)")
                    fflush(stdout)
                    exit(3)
                }
            }
        }

        for (n, (path, action)) in items.enumerated() where n >= start {
            current = "\(n)\t\(path)"
            print("ITEM\t\(current)")
            fflush(stdout)
            guard isAudited(action) else { continue }
            itemStarted = Date()
            itemIndex = n
            ActionRouter.perform(action, document: doc, window: nil)
        }
        itemIndex = -1
        print("DONE\t\(items.count)")
        fflush(stdout)
    }
}
