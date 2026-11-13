import AppKit
import SwiftUI
import WebKit
import CTCommon

/// CT1's stand-alone learning programs, ported natively:
/// "The Number Shark" (MFC NumberShark), "Point Addition on Elliptic Curves" (Java eccdemo)
/// and the Enigma visualisation (Flash, Frank Spieß).
@MainActor
enum CT1Games {
    private static weak var sharkWindow: NSWindow?
    private static weak var eccWindow: NSWindow?
    private static weak var enigmaWindow: NSWindow?
    private static weak var enigmaModel: EnigmaVisModel?

    /// Indiv. Procedures ▸ Educational Games ▸ Number Shark
    static func openNumberShark() {
        if let w = sharkWindow, w.isVisible { w.makeKeyAndOrderFront(nil); return }
        let model = SharkGameModel()
        let w = WindowPresenter.tool(id: "ct1games.numbershark", title: SharkText.numberShark + SharkText.titleVersion,
                                     size: CGSize(width: 730, height: 640), resizable: false) {
            CT1SharkView(model: model)
        }
        sharkWindow = w
        model.attach(window: w)
    }

    /// Indiv. Procedures ▸ Number Theory - Interactive ▸ Point Addition on Elliptic Curves
    static func openECCDemo() {
        if let w = eccWindow, w.isVisible { w.makeKeyAndOrderFront(nil); return }
        let model = ECCDemoModel()
        let w = WindowPresenter.tool(id: "ct1games.eccdemo", title: ECCText.frameTitleFr,
                                     size: CGSize(width: 900, height: 650), resizable: false) {
            CT1ECCDemoView(model: model)
        }
        eccWindow = w
        model.attach(window: w)
    }

    /// Indiv. Procedures ▸ Visualization of Algorithms ▸ Enigma
    static func openEnigma(document: CTDocument?) {
        if let w = enigmaWindow, w.isVisible {
            if let document { enigmaModel?.document = document }
            w.makeKeyAndOrderFront(nil)
            return
        }
        let model = EnigmaVisModel(document: document)
        enigmaModel = model
        let w = WindowPresenter.tool(id: "ct1games.enigma", title: "Enigma",
                                     size: CGSize(width: 1000, height: 780), resizable: false) {
            CT1EnigmaView(model: model)
        }
        enigmaWindow = w
    }

    // MARK: - Embedded help (NumberShark-en.chm, Enigma-Help_en.html)

    static func showSharkHelp(page: String = "NumberShark.html") {
        let toc: [(String, String)] = [
            ("Manual of the game", "NumberShark.html"),
            ("Tutorial for the game", "NumberSharkTutorial.html"),
            ("Development of the game", "NumberSharkDevelopment.html"),
            ("Real factors", "NumberSharkRealFactors.html"),
            ("Challenge", "NumberSharkChallenge.html"),
            ("Terms of License", "NumberSharkLicense.html"),
        ]
        let model = CT1HelpModel(start: page)
        let w = WindowPresenter.tool(id: "ct1games.sharkhelp", title: "Number Shark Help", size: CGSize(width: 900, height: 680)) {
            CT1HelpView(model: model, toc: toc)
        }
        // Window reused: navigate the existing web view.
        _ = w
        NotificationCenter.default.post(name: CT1HelpModel.navigate, object: nil, userInfo: ["page": page])
    }

    static func showEnigmaHelp() {
        let model = CT1HelpModel(start: "Enigma-Help_en.html")
        WindowPresenter.tool(id: "ct1games.enigmahelp", title: "Enigma Simulation Help", size: CGSize(width: 820, height: 680)) {
            CT1HelpView(model: model, toc: [])
        }
    }

    // MARK: - Embedded images

    private static var imageCache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage? {
        if let i = imageCache[name] { return i }
        guard let b64 = CT1GamesData.images[name], let d = Data(base64Encoded: b64), let i = NSImage(data: d) else { return nil }
        imageCache[name] = i
        return i
    }

    /// English number formatting with "," as thousands separator (CT1 `setSeperator`, IDS_STRING_PT).
    nonisolated static func sep<T: BinaryInteger>(_ v: T) -> String {
        let s = String(v)
        let neg = s.hasPrefix("-")
        var digits = Array(neg ? s.dropFirst() : Substring(s))
        var i = digits.count - 3
        while i > 0 { digits.insert(",", at: i); i -= 3 }
        return (neg ? "-" : "") + String(digits)
    }

    /// Simple message box as a sheet on `window` (or app-modal without window).
    static func messageBox(_ text: String, title: String, style: NSAlert.Style = .informational,
                           on window: NSWindow?, completion: (() -> Void)? = nil) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.alertStyle = style
        a.addButton(withTitle: "OK")
        if let window {
            a.beginSheetModal(for: window) { _ in completion?() }
        } else {
            a.runModal()
            completion?()
        }
    }
}

// MARK: - Help viewer (WKWebView serving the embedded pages via a custom URL scheme)

@MainActor
final class CT1HelpModel: ObservableObject {
    static let navigate = Notification.Name("CT1GamesHelpNavigate")
    let start: String
    @Published var current: String
    init(start: String) { self.start = start; current = start }
}

private final class CT1GamesSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "ct1games"

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        let name = url.lastPathComponent
        var data: Data?
        var mime = "text/html"
        if let html = CT1GamesData.sharkHelpPages[name] {
            data = Data(html.utf8)
        } else if name == "Enigma-Help_en.html" {
            data = Data(CT1GamesData.enigmaHelp.utf8)
        } else if name.lowercased().hasSuffix(".css") {
            data = Data(CT1GamesData.sharkHelpCSS.utf8); mime = "text/css"
        } else if let b64 = CT1GamesData.images[name] {
            data = Data(base64Encoded: b64)
            mime = name.hasSuffix(".gif") ? "image/gif" : (name.hasSuffix(".png") ? "image/png" : "image/jpeg")
        } else if let u = Resources.url("Help/en/images/" + name) {
            data = try? Data(contentsOf: u)
            mime = name.lowercased().hasSuffix(".png") ? "image/png" : "image/jpeg"
        }
        guard let data else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist))
            return
        }
        let response = URLResponse(url: url, mimeType: mime, expectedContentLength: data.count,
                                   textEncodingName: mime.hasPrefix("text") ? "utf-8" : nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

private struct CT1HelpWebView: NSViewRepresentable {
    @ObservedObject var model: CT1HelpModel

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        let handler = CT1GamesSchemeHandler()
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let u = navigationAction.request.url, let s = u.scheme?.lowercased(), s == "http" || s == "https" || s == "mailto" {
                NSWorkspace.shared.open(u)
                return .cancel
            }
            return .allow
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: CT1GamesSchemeHandler.scheme)
        let v = WKWebView(frame: .zero, configuration: config)
        v.navigationDelegate = context.coordinator
        v.allowsMagnification = true
        return v
    }

    func updateNSView(_ v: WKWebView, context: Context) {
        guard context.coordinator.loaded != model.current else { return }
        context.coordinator.loaded = model.current
        if let u = URL(string: "\(CT1GamesSchemeHandler.scheme)://help/\(model.current)") {
            v.load(URLRequest(url: u))
        }
    }
}

struct CT1HelpView: View {
    @ObservedObject var model: CT1HelpModel
    let toc: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            if !toc.isEmpty {
                List {
                    ForEach(toc, id: \.1) { item in
                        Button { model.current = item.1 } label: {
                            Text(item.0).frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(model.current == item.1 ? .semibold : .regular)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 230)
                Divider()
            }
            CT1HelpWebView(model: model)
        }
        .frame(minWidth: 640, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: CT1HelpModel.navigate)) { n in
            if !toc.isEmpty, let p = n.userInfo?["page"] as? String { model.current = p }
        }
    }
}

/// Owner-drawn 7-segment display (CDigiStatic: light green on black, dark green "off" segments).
struct CT1SevenSegmentDisplay: View {
    let text: String
    var on = Color(red: 0, green: 1, blue: 0)
    var off = Color(red: 0, green: 0.25, blue: 0)

    private static let segments: [Character: [Int]] = [
        "0": [0, 1, 2, 4, 5, 6], "1": [2, 5], "2": [0, 2, 3, 4, 6], "3": [0, 2, 3, 5, 6], "4": [1, 2, 3, 5],
        "5": [0, 1, 3, 5, 6], "6": [0, 1, 3, 4, 5, 6], "7": [0, 2, 5], "8": [0, 1, 2, 3, 4, 5, 6], "9": [0, 1, 2, 3, 5, 6],
        "-": [3],
    ]

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let chars = Array(text)
            let h = size.height * 0.78
            let w = h * 0.52
            let gap = w * 0.38
            let colonW = w * 0.45
            let total = chars.reduce(CGFloat(0)) { $0 + ($1 == ":" ? colonW : w) + gap } - gap
            var x = (size.width - total) / 2
            let y = (size.height - h) / 2
            let t = max(3, h * 0.11)
            for c in chars {
                if c == ":" {
                    for fy in [0.3, 0.7] {
                        let r = CGRect(x: x + colonW / 2 - t / 2, y: y + h * fy - t / 2, width: t, height: t)
                        ctx.fill(Path(r), with: .color(on))
                    }
                    x += colonW + gap
                    continue
                }
                let lit = Set(Self.segments[c] ?? [])
                // 0 top, 1 upper-left, 2 upper-right, 3 middle, 4 lower-left, 5 lower-right, 6 bottom
                let rects: [CGRect] = [
                    CGRect(x: x + t, y: y, width: w - 2 * t, height: t),
                    CGRect(x: x, y: y + t, width: t, height: h / 2 - 1.5 * t),
                    CGRect(x: x + w - t, y: y + t, width: t, height: h / 2 - 1.5 * t),
                    CGRect(x: x + t, y: y + h / 2 - t / 2, width: w - 2 * t, height: t),
                    CGRect(x: x, y: y + h / 2 + t / 2, width: t, height: h / 2 - 1.5 * t),
                    CGRect(x: x + w - t, y: y + h / 2 + t / 2, width: t, height: h / 2 - 1.5 * t),
                    CGRect(x: x + t, y: y + h - t, width: w - 2 * t, height: t),
                ]
                for (i, r) in rects.enumerated() {
                    ctx.fill(Path(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), cornerRadius: t / 3), with: .color(lit.contains(i) ? on : off))
                }
                x += w + gap
            }
        }
    }
}
