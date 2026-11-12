import AppKit

/// Bridge between menu commands and the bundled CT1 online help (HelpCenter).
@MainActor
enum HelpBridge {
    static func startPage() { HelpCenter.showStartPage() }
    static func index() { HelpCenter.showIndex() }
    static func scenarios() { HelpCenter.showScenarios() }
    static func show(_ action: CTAction) { HelpCenter.show(action: action) }
}
