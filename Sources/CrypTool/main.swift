import AppKit

// Entry point: classic AppKit lifecycle (NSDocument based, like CT1's MDI model:
// every operation result opens in a new document window).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { app.run() }
}
