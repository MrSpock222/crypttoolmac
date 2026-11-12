import AppKit
import CTCommon
import CTAnalysis

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, CTActionHandling {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must be the first document controller created (it becomes NSDocumentController.shared).
        _ = CTDocumentController()
        // Result windows are not file backed; restoring them would yield empty documents.
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        MainMenu.adoptSystemRecentMenu()
        DispatchQueue.main.async { MainMenu.adoptSystemRecentMenu() }
        if AppSettings.shared.showStartExample, NSDocumentController.shared.documents.isEmpty {
            DocumentFactory.openExample("Startbeispiel-de.txt")
        }
        // CT1's cracklib dictionary for the password quality meter (loaded in the background)
        DispatchQueue.global(qos: .utility).async {
            if let url = Resources.url("Words/cracklib-words.deflate"), let d = try? Data(contentsOf: url),
               let raw = try? (d as NSData).decompressed(using: .zlib) {
                PasswordTools.dictionary = PasswordDictionary(sortedWordList: [UInt8](raw as Data))
            }
        }
        if AppSettings.shared.showStartDialog {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { StartDialog.show() }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSDocumentController.shared.newDocument(nil) }
        return true
    }

    @objc func performCTAction(_ sender: Any?) {
        guard let action = (sender as? NSMenuItem)?.ctAction else { return }
        let doc = NSDocumentController.shared.currentDocument as? CTDocument
        if ContextHelp.consume(action) { return }
        if action.requiresDocument && doc == nil { NSSound.beep(); return }
        ActionRouter.perform(action, document: doc, window: doc?.windowControllers.first?.window)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.ctAction else { return true }
        return ActionRouter.validate(menuItem, action: action) && !action.requiresDocument
    }
}

/// Creation of new documents (results of operations).
@MainActor
enum DocumentFactory {
    /// Opens a new document window with the given contents, CT1 style.
    @discardableResult
    static func openResult(_ bytes: [UInt8], title: String, parent: CTDocument? = nil,
                           method: String? = nil, key: String? = nil,
                           viewMode: DocumentViewMode? = nil) -> CTDocument {
        let origin = DocumentOrigin(title: title, method: method, key: key, parent: parent)
        let doc = CTDocument(bytes: bytes, origin: origin, viewMode: viewMode)
        NSDocumentController.shared.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
        return doc
    }

    @discardableResult
    static func openResult(text: String, title: String, parent: CTDocument? = nil,
                           method: String? = nil, key: String? = nil) -> CTDocument {
        openResult(TextCoding.bytes(from: text), title: title, parent: parent, method: method, key: key, viewMode: .text)
    }

    static func openExample(_ name: String) {
        guard let url = Resources.url("Examples/\(name)") else {
            Alerts.error("Beispieldatei \(name) nicht gefunden.")
            return
        }
        // Open a copy so the bundled example is never modified. Text examples are stored as UTF-8
        // and loaded as CT1's Windows-1252 bytes; binary examples (.hex, .bmp) stay unchanged.
        let data = (try? Data(contentsOf: url)) ?? Data()
        let isText = url.pathExtension.lowercased() == "txt"
        let bytes = isText ? TextCoding.bytes(from: TextCoding.string(from: [UInt8](data))) : [UInt8](data)
        let doc = CTDocument(bytes: bytes, origin: DocumentOrigin(title: name, method: nil, key: nil, parent: nil),
                             viewMode: isText ? nil : .hex)
        NSDocumentController.shared.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
    }

    /// CT1 title pattern: "<Verfahren> von <Dokument>, Schlüssel <Key>".
    static func title(_ operation: String, of doc: CTDocument?, key: String? = nil) -> String {
        var t = operation
        if let d = doc { t += " von <\(d.shortName)>" }
        if let k = key, !k.isEmpty {
            let shown = k.count > 60 ? String(k.prefix(57)) + "…" : k
            t += ", Schlüssel <\(shown)>"
        }
        return t
    }
}

@MainActor
enum Alerts {
    static func error(_ message: String, title: String = "CrypTool") {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }

    static func info(_ message: String, title: String = "CrypTool") {
        let a = NSAlert()
        a.alertStyle = .informational
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }

    /// Info alert with an additional "Kopieren" button.
    static func infoWithCopy(_ message: String, title: String, copyValue: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "In Zwischenablage kopieren")
        if a.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyValue, forType: .string)
        }
    }

    static func confirm(_ message: String, title: String, ok: String = "OK") -> Bool {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: ok)
        a.addButton(withTitle: "Abbrechen")
        return a.runModal() == .alertFirstButtonReturn
    }
}
