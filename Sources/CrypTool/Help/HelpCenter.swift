import AppKit

/// Entry point to CT1's original online help (German), shown in one reusable help window.
///
/// Menu wiring (done by the app): Hilfe ▸ Startseite → `showStartPage()`, Index → `showIndex()`,
/// Szenarien (Tutorials) → `showScenarios()`, F1 / Help buttons → `show(topic: topic(for: action) ?? …)`.
@MainActor
enum HelpCenter {
    /// Start page ("Startseite: Der Einstieg in CrypTool", ID_HILFE_STARTSEITE).
    static func showStartPage() {
        HelpWindowController.shared.present(file: HelpBook.startPage)
    }

    /// Alphabetical help index (ID_HILFE_INDEX).
    static func showIndex() {
        HelpWindowController.shared.present(file: HelpBook.indexPage)
    }

    /// Scenarios / tutorials overview (ID_HILFE_SZENARIEN).
    static func showScenarios() {
        HelpWindowController.shared.present(file: HelpBook.scenariosPage)
    }

    /// Shows a help page by file name, e.g. "hid_rot13caesar_asc.html" (an optional "#anchor"
    /// is honoured). Falls back to the start page if the page does not exist.
    static func show(topic: String) {
        HelpWindowController.shared.present(file: resolve(topic) ?? HelpBook.startPage)
    }

    /// Convenience: shows the page of a menu command (start page if it has none).
    static func show(action: CTAction) {
        show(topic: topic(for: action) ?? HelpBook.startPage)
    }

    /// Whether a page exists for `topic` (same lookup rules as `show(topic:)`).
    static func hasTopic(_ topic: String) -> Bool { resolve(topic) != nil }

    /// Normalises a topic: exact name, lower-cased name (CT1 aliases use upper case),
    /// and a missing ".html" suffix are accepted.
    private static func resolve(_ topic: String) -> String? {
        var name = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        var fragment = ""
        if let i = name.firstIndex(of: "#") {
            fragment = String(name[i...])
            name = String(name[..<i])
        }
        guard !name.isEmpty else { return nil }
        var candidates = [name, name.lowercased()]
        if !name.lowercased().hasSuffix(".html") && !name.lowercased().hasSuffix(".htm") {
            candidates += [name + ".html", name.lowercased() + ".html"]
        }
        for c in candidates where HelpBook.url(for: c) != nil {
            return c + fragment
        }
        return nil
    }
}
