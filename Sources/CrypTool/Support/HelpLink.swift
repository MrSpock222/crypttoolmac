import AppKit

/// Entry points for CT1's online help (bundled HTML help, see HelpCenter).
@MainActor
enum HelpLink {
    static func startPage() { HelpBridge.startPage() }
    static func index() { HelpBridge.index() }
    static func scenarios() { HelpBridge.scenarios() }

    /// Help page of a menu command (context help / F1).
    static func show(for action: CTAction) { HelpBridge.show(action) }

    /// F1: help for the most recently used dialog/tool, otherwise the start page.
    static func contextHelp() {
        if let a = ActionRouter.lastAction, NSApp.keyWindow?.windowController is DocumentWindowController == false {
            show(for: a)
        } else {
            startPage()
        }
    }
}
