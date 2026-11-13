import AppKit
import SwiftUI
import WebKit
import CTCommon

/// State shared by the help window's sidebar (table of contents / search results) and web view.
@MainActor
final class HelpViewModel: ObservableObject {
    @Published private(set) var toc: [HelpTOCNode] = []
    @Published private(set) var query = ""
    @Published private(set) var results: [HelpSearchResult] = []
    @Published private(set) var searching = false
    /// Page currently shown (relative to the help root, without fragment).
    @Published var currentFile: String?

    /// Opens a page in the web view (set by the window controller).
    var open: (String) -> Void = { _ in }
    /// First search word, highlighted after a search result has been opened.
    var pendingHighlight: String?

    private let index = HelpSearchIndex()
    private var searchTask: Task<Void, Never>?
    private var tocIDs: [String: Int] = [:]

    init() {
        toc = HelpBook.loadTOC()
        func collect(_ nodes: [HelpTOCNode]) {
            for n in nodes {
                if let f = n.file, tocIDs[f] == nil { tocIDs[f] = n.id }
                if let c = n.children { collect(c) }
            }
        }
        collect(toc)
    }

    var isSearchActive: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var selectedTOCID: Int? { currentFile.flatMap { tocIDs[$0] } }

    func selectTOC(_ id: Int?) {
        guard let id, let file = find(id, in: toc)?.file else { return }
        open(file)
    }

    private func find(_ id: Int, in nodes: [HelpTOCNode]) -> HelpTOCNode? {
        for n in nodes {
            if n.id == id { return n }
            if let c = n.children, let hit = find(id, in: c) { return hit }
        }
        return nil
    }

    func openResult(_ file: String?) {
        guard let file else { return }
        pendingHighlight = query.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
        open(file)
    }

    func search(_ text: String) {
        query = text
        searchTask?.cancel()
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        let index = self.index
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)   // debounce typing
            if Task.isCancelled { return }
            let found = await Task.detached(priority: .userInitiated) { index.search(q) }.value
            if Task.isCancelled { return }
            self?.results = found
            self?.searching = false
        }
    }
}

/// Sidebar: collapsible table of contents from cryptool.hhc, or the search result list.
struct HelpSidebarView: View {
    @ObservedObject var model: HelpViewModel

    var body: some View {
        Group {
            if model.isSearchActive {
                resultList
            } else {
                List(model.toc, children: \.children,
                     selection: Binding(get: { model.selectedTOCID }, set: { model.selectTOC($0) })) { node in
                    Label(node.title, systemImage: node.children == nil ? "doc.text" : "book.closed")
                        .lineLimit(2)
                        .help(node.title)
                        .tag(node.id)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200, idealWidth: 270)
    }

    @ViewBuilder private var resultList: some View {
        if model.results.isEmpty {
            VStack(spacing: 8) {
                if model.searching {
                    ProgressView().controlSize(.small)
                    Text("Searching...").foregroundStyle(.secondary)
                } else {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                    Text("No results for \"\(model.query)\"").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: Binding(get: { model.currentFile }, set: { model.openResult($0) })) {
                Section(header: Text(model.results.count == 1 ? "1 page found" : "\(model.results.count) pages found")) {
                    ForEach(model.results) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).lineLimit(2)
                            Text(r.hits == 1 ? "1 hit" : "\(r.hits) hits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .help(r.file)
                        .tag(r.file)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

/// The single help window: sidebar + WKWebView, toolbar with navigation, print and search.
@MainActor
final class HelpWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate,
                                  NSToolbarItemValidation, WKNavigationDelegate, WKUIDelegate {
    static let shared = HelpWindowController()

    let model = HelpViewModel()
    private let webView: WKWebView
    private let splitController = NSSplitViewController()
    private var sidebarItem: NSSplitViewItem!
    private weak var searchItem: NSSearchToolbarItem?

    private enum Item {
        static let back = NSToolbarItem.Identifier("ct.help.back")
        static let forward = NSToolbarItem.Identifier("ct.help.forward")
        static let home = NSToolbarItem.Identifier("ct.help.home")
        static let index = NSToolbarItem.Identifier("ct.help.index")
        static let print = NSToolbarItem.Identifier("ct.help.print")
        static let search = NSToolbarItem.Identifier("ct.help.search")
    }

    private init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 760, height: 700), configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "CrypTool Help"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)

        let sidebarHost = NSHostingController(rootView: HelpSidebarView(model: model))
        sidebarHost.sizingOptions = []
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHost)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 460
        sidebarItem.canCollapse = true
        let webController = NSViewController()
        webController.view = webView
        let contentItem = NSSplitViewItem(viewController: webController)
        contentItem.minimumThickness = 360
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(contentItem)
        splitController.splitView.autosaveName = "CTHelpSplitView"
        window.contentViewController = splitController
        window.setContentSize(NSSize(width: 1060, height: 740))

        let toolbar = NSToolbar(identifier: "CTHelpToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.delegate = self
        if !window.setFrameUsingName("CTHelpWindow") { window.center() }
        window.setFrameAutosaveName("CTHelpWindow")

        webView.navigationDelegate = self
        webView.uiDelegate = self
        model.open = { [weak self] file in self?.load(file: file) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Presenting

    func present(file: String) {
        load(file: file)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func load(file: String) {
        guard let root = HelpBook.rootURL else {
            webView.loadHTMLString("""
                <html><body style="font-family:-apple-system;padding:2em">
                <h2>Help not found</h2><p>The help files (Resources/Help/en) are missing in this installation.</p>
                </body></html>
                """, baseURL: nil)
            return
        }
        guard let url = HelpBook.url(for: file) ?? HelpBook.url(for: HelpBook.startPage) else { return }
        if let current = webView.url, current == url, !webView.isLoading {
            highlightPendingSearchWord()
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: root)
    }

    // MARK: - Toolbar actions

    @objc func goBack(_ sender: Any?) { webView.goBack() }
    @objc func goForward(_ sender: Any?) { webView.goForward() }
    @objc func goHome(_ sender: Any?) { load(file: HelpBook.startPage) }
    @objc func goIndex(_ sender: Any?) { load(file: HelpBook.indexPage) }

    @objc func printPage(_ sender: Any?) {
        guard let window else { return }
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        let op = webView.printOperation(with: info)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.jobTitle = webView.title ?? "CrypTool Help"
        // WKWebView's print view has a zero frame unless set explicitly (prints blank pages otherwise).
        op.view?.frame = webView.bounds
        op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    @objc func searchChanged(_ sender: NSSearchField) {
        model.search(sender.stringValue)
        if model.isSearchActive && sidebarItem.isCollapsed {
            sidebarItem.animator().isCollapsed = false
        }
    }

    /// ⌘F focuses the search field.
    @objc func performFindPanelAction(_ sender: Any?) {
        if let field = searchItem?.searchField { window?.makeFirstResponder(field) }
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Item.back: return webView.canGoBack
        case Item.forward: return webView.canGoForward
        default: return true
        }
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, Item.back, Item.forward, Item.home, Item.index, .flexibleSpace, Item.print, Item.search]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case Item.back: return button(id, "Back", "chevron.left", #selector(goBack(_:)), navigational: true)
        case Item.forward: return button(id, "Forward", "chevron.right", #selector(goForward(_:)), navigational: true)
        case Item.home: return button(id, "Starting Page", "house", #selector(goHome(_:)))
        case Item.index: return button(id, "Index", "list.bullet.rectangle", #selector(goIndex(_:)))
        case Item.print: return button(id, "Print", "printer", #selector(printPage(_:)))
        case Item.search:
            let item = NSSearchToolbarItem(itemIdentifier: id)
            item.label = "Find"
            item.toolTip = "Full-text search in the help"
            item.preferredWidthForSearchField = 240
            item.searchField.placeholderString = "Search help"
            item.searchField.sendsSearchStringImmediately = false
            item.searchField.target = self
            item.searchField.action = #selector(searchChanged(_:))
            searchItem = item
            return item
        default:
            return nil
        }
    }

    private func button(_ id: NSToolbarItem.Identifier, _ label: String, _ symbol: String,
                        _ action: Selector, navigational: Bool = false) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.isBordered = true
        item.isNavigational = navigational
        item.target = self
        item.action = action
        item.autovalidates = true
        return item
    }

    // MARK: - WKNavigationDelegate / WKUIDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        case "about", "data", "blob":
            return .allow
        case "file":
            guard let file = HelpBook.file(for: url) else { return .cancel }
            let ext = url.pathExtension.lowercased()
            if ext == "html" || ext == "htm" {
                if navigationAction.targetFrame == nil {   // target="_blank": stay in the help window
                    load(file: file + (url.fragment.map { "#" + $0 } ?? ""))
                    return .cancel
                }
                return .allow
            }
            openAttachment(url)
            return .cancel
        default:
            // http(s), mailto, … → default application
            NSWorkspace.shared.open(url)
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if url.isFileURL, let file = HelpBook.file(for: url) {
                load(file: file)
            } else if url.scheme != nil {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageChanged()
        highlightPendingSearchWord()
    }

    /// Selects (and scrolls to) the first occurrence of the search word after opening a search result.
    private func highlightPendingSearchWord() {
        guard let word = model.pendingHighlight else { return }
        model.pendingHighlight = nil
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true
        webView.find(word, configuration: config) { _ in }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        pageChanged()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pageChanged()
    }

    private func pageChanged() {
        if let url = webView.url, let file = HelpBook.file(for: url) {
            if model.currentFile != file { model.currentFile = file }
        }
        if let t = webView.title, !t.isEmpty {
            window?.title = "CrypTool Help – \(t)"
        } else {
            window?.title = "CrypTool Help"
        }
        window?.toolbar?.validateVisibleItems()
    }

    /// Files linked from the help that CT1 opened from its installation folder: text files
    /// (crypto challenges) open as CrypTool documents, everything else (PDF) in the default app.
    private func openAttachment(_ url: URL) {
        if url.pathExtension.lowercased() == "txt", let data = try? Data(contentsOf: url) {
            let bytes = TextCoding.bytes(from: TextCoding.string(from: [UInt8](data)))
            DocumentFactory.openResult(bytes, title: url.lastPathComponent)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
