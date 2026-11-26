import AppKit

/// Checks the GitHub releases of this port for a newer version (macOS-only addition, CT1 has no
/// update check). "Download" opens the release page; installing stays manual (DMG).
@MainActor
enum UpdateChecker {
    static let repository = "MrSpock222/crypttoolmac"

    private static let autoKey = "updateAutoCheck"
    private static let lastCheckKey = "updateLastCheck"
    private static let skippedKey = "updateSkippedVersion"

    /// Automatic check at launch (on by default).
    static var automaticChecks: Bool {
        get { UserDefaults.standard.object(forKey: autoKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoKey) }
    }

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        enum CodingKeys: String, CodingKey { case tagName = "tag_name", htmlURL = "html_url" }
    }

    /// At launch: at most once a day, silent unless a newer (not skipped) release exists.
    static func checkAtLaunch() {
        guard automaticChecks, !LayoutAudit.isEnabled else { return }
        if let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < 24 * 60 * 60 { return }
        Task { await check(manual: false) }
    }

    /// CrypTool ▸ Check for Updates...
    static func checkNow() {
        guard !LayoutAudit.isEnabled else { return }
        Task { await check(manual: true) }
    }

    private static func check(manual: Bool) async {
        let release: Release
        do {
            release = try await fetchLatest()
        } catch {
            if manual { showError(error) }
            return
        }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        let latest = normalized(release.tagName)
        if isNewer(latest, than: installedVersion) {
            if !manual && UserDefaults.standard.string(forKey: skippedKey) == latest { return }
            showUpdate(latest: latest, page: release.htmlURL)
        } else if manual {
            showUpToDate()
        }
    }

    private static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    // MARK: Versions

    /// "v2.0.3" → "2.0.3"
    static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespaces).drop { $0 == "v" || $0 == "V" }.description
    }

    /// Numeric comparison of dotted versions ("2.0.10" > "2.0.9", "2.1" > "2.0.3").
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    // MARK: Alerts

    private static func alert(_ message: String, _ info: String, style: NSAlert.Style = .informational) -> NSAlert {
        let a = NSAlert()
        a.alertStyle = style
        a.messageText = message
        a.informativeText = info
        return a
    }

    /// Checkbox for the automatic check, shown in the update and "up to date" alerts.
    private static func addAutoCheckbox(_ a: NSAlert) {
        a.showsSuppressionButton = true
        a.suppressionButton?.title = "Check for updates automatically"
        a.suppressionButton?.state = automaticChecks ? .on : .off
    }

    private static func readAutoCheckbox(_ a: NSAlert) {
        automaticChecks = a.suppressionButton?.state == .on
    }

    private static func showUpdate(latest: String, page: String) {
        let a = alert("A new version of CrypTool for macOS is available.",
                      "Version \(latest) is available – you have version \(installedVersion).\n\n"
                      + "Download the new CrypTool.dmg from the release page and replace the app in the Applications folder.")
        a.addButton(withTitle: "Download")
        a.addButton(withTitle: "Later")
        a.addButton(withTitle: "Skip This Version")
        addAutoCheckbox(a)
        let r = a.runModal()
        readAutoCheckbox(a)
        switch r {
        case .alertFirstButtonReturn:
            if let url = URL(string: page) { NSWorkspace.shared.open(url) }
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(latest, forKey: skippedKey)
        default:
            break
        }
    }

    private static func showUpToDate() {
        let a = alert("CrypTool for macOS is up to date.", "Version \(installedVersion) is the latest version.")
        addAutoCheckbox(a)
        a.runModal()
        readAutoCheckbox(a)
    }

    private static func showError(_ error: Error) {
        alert("Could not check for updates.",
              "Please check the internet connection and try again.\n\n\(error.localizedDescription)",
              style: .warning).runModal()
    }
}
