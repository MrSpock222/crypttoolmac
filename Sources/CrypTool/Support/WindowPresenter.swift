import AppKit
import SwiftUI

/// Limits the *ideal* width of dialog content.
///
/// SwiftUI reports the ideal width of a paragraph as its unwrapped single-line width. A dialog that
/// is sized to its ideal size would therefore become as wide as its longest text – wider than the
/// screen for the long description texts of CT1. With this layout the content is offered `cap` as
/// width whenever its ideal width exceeds `cap`, so texts wrap; content that really needs more
/// room (fixed-width tables, explicit frames) keeps its own minimum width, and narrower content
/// keeps its natural width. Explicit width proposals (a resized window) are passed through.
struct IdealWidthCap: Layout {
    var cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let v = subviews.first else { return .zero }
        guard proposal.width == nil else { return v.sizeThatFits(proposal) }
        let ideal = v.sizeThatFits(proposal)
        if ideal.width <= cap { return ideal }
        return v.sizeThatFits(ProposedViewSize(width: cap, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// Presents SwiftUI content as sheets on document windows or as free-standing tool windows.
@MainActor
enum WindowPresenter {
    private static var toolWindows: [String: NSWindow] = [:]
    private static var anonymousWindows: Set<NSWindow> = []

    /// Widest a sheet may become on its own (points); long texts wrap at this width.
    static let sheetWidthCap: CGFloat = 700

    private static var screenSize: NSSize { (NSScreen.main?.visibleFrame.size) ?? NSSize(width: 1400, height: 900) }

    /// Shows `content` as a sheet on `window` (or as a modal-less panel if `window` is nil).
    /// The content receives a `close` closure.
    static func sheet<V: View>(on window: NSWindow?, title: String = "", @ViewBuilder content: (@escaping () -> Void) -> V) {
        let sheet = NSWindow(contentRect: .zero, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        sheet.title = title
        var closeAction: () -> Void = {}
        let cap = min(sheetWidthCap, screenSize.width - 80)
        if LayoutAudit.isEnabled {
            LayoutAudit.record(kind: "sheet", title: title, declared: nil, cap: sheetWidthCap, content: content({}))
            return
        }
        let root = IdealWidthCap(cap: cap) { content({ closeAction() }) }.environmentObject(AppSettings.shared)
        let host = NSHostingController(rootView: AnyView(root))
        // A sheet cannot be moved or resized: if it would be taller than the screen, its content scrolls.
        let fitting = host.view.fittingSize
        let maxHeight = screenSize.height - 90
        if fitting.height > maxHeight {
            host.rootView = AnyView(ScrollView(.vertical) { root }.frame(width: fitting.width, height: maxHeight))
        }
        host.sizingOptions = [.preferredContentSize]
        sheet.contentViewController = host
        if let parent = window {
            closeAction = { [weak parent, weak sheet] in
                guard let sheet else { return }
                parent?.endSheet(sheet)
            }
            parent.beginSheet(sheet)
        } else {
            sheet.styleMask.insert(.closable)
            closeAction = { [weak sheet] in sheet?.close() }
            sheet.isReleasedWhenClosed = false
            anonymousWindows.insert(sheet)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: sheet, queue: .main) { n in
                MainActor.assumeIsolated {
                    if let w = n.object as? NSWindow { anonymousWindows.remove(w) }
                }
            }
            sheet.center()
            sheet.makeKeyAndOrderFront(nil)
        }
    }

    /// Opens (or brings to front) a tool window. Windows with the same `id` are reused.
    @discardableResult
    static func tool<V: View>(id: String? = nil, title: String, size: CGSize = CGSize(width: 640, height: 480),
                              resizable: Bool = true, @ViewBuilder content: () -> V) -> NSWindow {
        if LayoutAudit.isEnabled {
            LayoutAudit.record(kind: "tool", title: title, declared: size, cap: size.width, content: content())
            return NSWindow()
        }
        if let id, let w = toolWindows[id] {
            w.makeKeyAndOrderFront(nil)
            return w
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        w.tabbingMode = .disallowed
        w.isRestorable = false
        // Long texts wrap at the intended window width instead of widening the window.
        let cap = min(size.width, screenSize.width - 40)
        let root = IdealWidthCap(cap: cap) { content() }
        let host = NSHostingController(rootView: AnyView(root.environmentObject(AppSettings.shared)))
        // The window may never be smaller than the SwiftUI content needs (avoids clipped dialogs).
        host.sizingOptions = [.minSize]
        w.contentViewController = host
        let fitting = host.view.fittingSize
        let screen = screenSize
        w.setContentSize(NSSize(width: min(max(size.width, fitting.width), screen.width - 40),
                                height: min(max(size.height, fitting.height), screen.height - 60)))
        w.center()
        w.cascadeTopLeft(from: NSPoint(x: 40, y: 40))
        let key = id ?? UUID().uuidString
        toolWindows[key] = w
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
            MainActor.assumeIsolated { toolWindows[key] = nil }
        }
        w.makeKeyAndOrderFront(nil)
        return w
    }
}

/// Standard dialog chrome: title, content, button row.
struct DialogScaffold<Content: View, Buttons: View>: View {
    let title: String
    var subtitle: String? = nil
    var minWidth: CGFloat = 460
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            content
            Divider()
            HStack {
                Spacer()
                buttons
            }
        }
        .padding(18)
        .frame(minWidth: minWidth, alignment: .leading)
    }
}

/// Monospaced read-only text block with copy button.
struct ResultBox: View {
    let text: String
    var minHeight: CGFloat = 60
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        }
        .frame(minHeight: minHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }
}

/// Multi-line monospaced editor with border.
struct CodeEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 80
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: minHeight)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }
}

func copyToPasteboard(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}
