import AppKit

// Entry point: classic AppKit lifecycle (NSDocument based, like CT1's MDI model:
// every operation result opens in a new document window).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    if LayoutAudit.isEnabled {
        // developer diagnostic: measure all dialogs without showing anything, then quit
        app.setActivationPolicy(.prohibited)
        LayoutAudit.run()
        exit(0)
    }
    app.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { app.run() }
}
