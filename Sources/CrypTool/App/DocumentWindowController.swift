import AppKit
import CTCommon

/// Layout manager that can draw CT1's "Zeilenende" (¶) and "Leerzeichen" (·) markers.
final class CTLayoutManager: NSLayoutManager {
    var showEndOfLine = false
    var showWhitespace = false

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard showEndOfLine || showWhitespace, let storage = textStorage else { return }
        let text = storage.string as NSString
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let font = storage.length > 0 ? (storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont) : nil
        let attrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.6)]
        var i = charRange.location
        while i < NSMaxRange(charRange) {
            let c = text.character(at: i)
            var marker: String?
            if showWhitespace && c == 0x20 { marker = "·" }
            else if showWhitespace && c == 0x09 { marker = "→" }
            else if showEndOfLine && (c == 0x0A || c == 0x0D) { marker = "¶" }
            if let marker {
                let g = glyphIndexForCharacter(at: i)
                if let container = textContainer(forGlyphAt: g, effectiveRange: nil) {
                    var rect = boundingRect(forGlyphRange: NSRange(location: g, length: 1), in: container)
                    if rect.width < 1 { rect.size.width = 6 }
                    (marker as NSString).draw(at: NSPoint(x: rect.minX + origin.x, y: rect.minY + origin.y), withAttributes: attrs)
                }
            }
            i += 1
        }
    }
}

/// Text view with CT1's "Codiert kopieren" / "Decodiert einfügen" (hex) behaviour.
final class CTTextView: NSTextView {
    var isBinaryDocument: () -> Bool = { false }

    override func copy(_ sender: Any?) {
        guard isBinaryDocument() else { super.copy(sender); return }
        let r = selectedRange()
        guard r.length > 0, let range = Range(r, in: string) else { return }
        let part = String(string[range])
        let a = NSAlert()
        a.messageText = "Codiert kopieren"
        a.informativeText = "Die Auswahl enthält Binärdaten. Wie sollen sie in die Zwischenablage kopiert werden?"
        a.addButton(withTitle: "Hex-Codierung")
        a.addButton(withTitle: "Keine Codierung")
        a.addButton(withTitle: "Abbrechen")
        switch a.runModal() {
        case .alertFirstButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Hex.encode(Array(part.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) })), forType: .string)
        case .alertSecondButtonReturn: super.copy(sender)
        default: break
        }
    }

    override func paste(_ sender: Any?) {
        guard isEditable, let s = NSPasteboard.general.string(forType: .string) else { super.paste(sender); return }
        let compact = s.filter { !$0.isWhitespace }
        let looksHex = compact.count >= 4 && compact.count % 2 == 0 && compact.allSatisfy(\.isHexDigit) && compact.contains(where: \.isNumber)
        guard looksHex, let decoded = Hex.decode(s) else { super.paste(sender); return }
        let a = NSAlert()
        a.messageText = "Decodiert einfügen"
        a.informativeText = "Der Inhalt der Zwischenablage besteht nur aus Hexadezimalziffern. Soll er decodiert eingefügt werden?"
        a.addButton(withTitle: "Keine Decodierung")
        a.addButton(withTitle: "Hex-Decodierung")
        if a.runModal() == .alertSecondButtonReturn {
            guard let text = String(bytes: decoded, encoding: .utf8) else {
                Alerts.info("Die decodierten Daten sind kein Text. Bitte in der Hex-Ansicht (Ansicht ▸ Als HexDump anzeigen) einfügen.")
                return
            }
            insertText(text, replacementRange: selectedRange())
        } else {
            super.paste(sender)
        }
    }
}

/// Window of a CrypTool document: CT1 toolbar, info bar (origin), text view or hex editor, status bar.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSMenuItemValidation, NSToolbarDelegate, CTActionHandling {
    private(set) var viewMode: DocumentViewMode = .text
    private let infoLabel = NSTextField(labelWithString: "")
    private let infoBar = NSVisualEffectView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let statusSeparator = NSBox()
    private let scrollView = NSScrollView()
    private let textView: NSTextView
    private let layoutManager = CTLayoutManager()
    private let hexEditor = HexEditorView(frame: .zero)
    private var isUpdatingFromDocument = false
    private var observers: [NSObjectProtocol] = []
    private var statusHeight: NSLayoutConstraint?
    private var statusBottom: NSLayoutConstraint?

    var ctDocument: CTDocument? { document as? CTDocument }
    var hexEditorView: HexEditorView { hexEditor }
    var textEditorView: NSTextView { textView }

    // The document is attached after init (NSDocument.addWindowController) – load it then.
    override var document: AnyObject? {
        didSet { reloadFromDocument() }
    }

    init(document: CTDocument) {
        // TextKit 1 stack with our layout manager (for the CT1 view options)
        let storage = NSTextStorage()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        let ctv = CTTextView(frame: .zero, textContainer: container)
        textView = ctv

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 580),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 460, height: 280)
        window.tabbingMode = .disallowed
        window.isRestorable = false   // derived documents have no file – don't restore empty windows
        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = true
        buildUI()
        buildToolbar()
        viewMode = document.preferredViewMode ?? (document.isText ? .text : .hex)
        reloadFromDocument()
        observers.append(NotificationCenter.default.addObserver(forName: CTDocument.contentChanged, object: document, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFromDocument() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .ctFontChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyFontAndWrap() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .ctViewOptionsChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyViewOptions() }
        })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    // MARK: UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        infoBar.material = .headerView
        infoBar.blendingMode = .withinWindow
        infoBar.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.lineBreakMode = .byTruncatingMiddle
        infoLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        infoLabel.textColor = .secondaryLabelColor
        infoBar.addSubview(infoLabel)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        (textView as? CTTextView)?.isBinaryDocument = { [weak self] in !(self?.ctDocument?.isText ?? true) }
        hexEditor.onChange = { [weak self] bytes in self?.hexEdited(bytes) }
        hexEditor.onSelectionChange = { [weak self] in self?.updateStatus() }

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.findBarPosition = .aboveContent

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let separatorTop = NSBox(); separatorTop.boxType = .separator
        statusSeparator.boxType = .separator
        [separatorTop, statusSeparator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        content.addSubview(infoBar)
        content.addSubview(separatorTop)
        content.addSubview(scrollView)
        content.addSubview(statusSeparator)
        content.addSubview(statusLabel)

        let bottom = statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4)
        statusBottom = bottom
        NSLayoutConstraint.activate([
            infoBar.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor),
            infoBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            infoBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: infoBar.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -10),
            infoLabel.topAnchor.constraint(equalTo: infoBar.topAnchor, constant: 4),
            infoLabel.bottomAnchor.constraint(equalTo: infoBar.bottomAnchor, constant: -4),

            separatorTop.topAnchor.constraint(equalTo: infoBar.bottomAnchor),
            separatorTop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separatorTop.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separatorTop.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            statusSeparator.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            statusSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: statusSeparator.bottomAnchor, constant: 3),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            bottom,
        ])
        applyFontAndWrap()
        applyViewOptions()
    }

    // MARK: CT1 toolbar

    private enum ToolbarID {
        static let new = NSToolbarItem.Identifier("ct.new")
        static let open = NSToolbarItem.Identifier("ct.open")
        static let close = NSToolbarItem.Identifier("ct.close")
        static let save = NSToolbarItem.Identifier("ct.save")
        static let print = NSToolbarItem.Identifier("ct.print")
        static let cut = NSToolbarItem.Identifier("ct.cut")
        static let copy = NSToolbarItem.Identifier("ct.copy")
        static let paste = NSToolbarItem.Identifier("ct.paste")
        static let key = NSToolbarItem.Identifier("ct.key")
        static let parent = NSToolbarItem.Identifier("ct.parent")
        static let about = NSToolbarItem.Identifier("ct.about")
        static let help = NSToolbarItem.Identifier("ct.help")
        static let sep1 = NSToolbarItem.Identifier("ct.sep1")
        static let sep2 = NSToolbarItem.Identifier("ct.sep2")
        static let sep3 = NSToolbarItem.Identifier("ct.sep3")
    }

    private func buildToolbar() {
        let tb = NSToolbar(identifier: "CrypToolDocumentToolbar")
        tb.delegate = self
        tb.displayMode = .iconOnly
        tb.allowsUserCustomization = true
        tb.autosavesConfiguration = true
        window?.toolbar = tb
        window?.toolbarStyle = .unifiedCompact
        window?.toolbar?.isVisible = AppSettings.shared.showToolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarID.new, ToolbarID.open, ToolbarID.close, ToolbarID.save, ToolbarID.print, ToolbarID.sep1,
         ToolbarID.cut, ToolbarID.copy, ToolbarID.paste, ToolbarID.sep2,
         ToolbarID.key, ToolbarID.parent, ToolbarID.sep3,
         ToolbarID.about, ToolbarID.help]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        func item(_ label: String, _ symbol: String, _ action: Selector, target: AnyObject? = nil) -> NSToolbarItem {
            let i = NSToolbarItem(itemIdentifier: id)
            i.label = label
            i.paletteLabel = label
            i.toolTip = label
            i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            i.action = action
            i.target = target
            i.isBordered = true
            return i
        }
        switch id {
        case ToolbarID.new: return item("Neu", "doc.badge.plus", #selector(NSDocumentController.newDocument(_:)))
        case ToolbarID.open: return item("Öffnen", "folder", #selector(NSDocumentController.openDocument(_:)))
        case ToolbarID.close: return item("Schließen", "xmark.square", #selector(NSWindow.performClose(_:)))
        case ToolbarID.save: return item("Speichern", "square.and.arrow.down", #selector(NSDocument.save(_:)))
        case ToolbarID.print: return item("Drucken", "printer", #selector(NSDocument.printDocument(_:)))
        case ToolbarID.cut: return item("Ausschneiden", "scissors", #selector(NSText.cut(_:)))
        case ToolbarID.copy: return item("Kopieren", "doc.on.doc", #selector(NSText.copy(_:)))
        case ToolbarID.paste: return item("Einfügen", "doc.on.clipboard", #selector(NSText.paste(_:)))
        case ToolbarID.key: return item("Schlüssel anzeigen", "key", #selector(toolbarShowKey(_:)), target: self)
        case ToolbarID.parent: return item("Übergeordnetes Fenster", "arrow.up.doc", #selector(toolbarGotoParent(_:)), target: self)
        case ToolbarID.about: return item("Über CrypTool", "info.circle", #selector(toolbarAbout(_:)), target: self)
        case ToolbarID.help: return item("Kontexthilfe – danach Menüpunkt wählen", "questionmark.circle", #selector(toolbarContextHelp(_:)), target: self)
        case ToolbarID.sep1, ToolbarID.sep2, ToolbarID.sep3:
            let i = NSToolbarItem(itemIdentifier: id)
            let line = NSBox(frame: NSRect(x: 0, y: 0, width: 1, height: 18))
            line.boxType = .separator
            i.view = line
            return i
        default: return nil
        }
    }

    @objc private func toolbarShowKey(_ sender: Any?) { if let d = ctDocument { CT1DocumentDialogs.showKey(d) } }
    @objc private func toolbarGotoParent(_ sender: Any?) { ctDocument?.origin?.parent?.windowControllers.first?.window?.makeKeyAndOrderFront(nil) }
    @objc private func toolbarAbout(_ sender: Any?) { HelpActions.about() }
    @objc private func toolbarContextHelp(_ sender: Any?) { ContextHelp.arm() }

    // MARK: Appearance

    private func applyFontAndWrap() {
        let settings = AppSettings.shared
        textView.font = settings.editorFont
        hexEditor.font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        let wrap = settings.lineWrap
        if wrap {
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            textView.frame.size.width = scrollView.contentSize.width
        } else {
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        }
        applyAlphabetHighlighting()
    }

    private func applyViewOptions() {
        let s = AppSettings.shared
        window?.toolbar?.isVisible = s.showToolbar
        statusLabel.isHidden = !s.showStatusBar
        statusSeparator.isHidden = !s.showStatusBar
        statusBottom?.constant = s.showStatusBar ? -4 : 0
        layoutManager.showEndOfLine = s.viewEndOfLine
        layoutManager.showWhitespace = s.viewWhitespace
        textView.needsDisplay = true
        applyAlphabetHighlighting()
    }

    /// CT1 "Ansicht ▸ Alphabet": characters not in the alphabet are greyed out.
    private func applyAlphabetHighlighting() {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        guard AppSettings.shared.viewAlphabet, viewMode == .text, storage.length < 2_000_000 else { return }
        let mapper = AppSettings.shared.textOptions.makeMapper()
        let text = storage.string
        var utf16Offset = 0
        var runStart: Int?
        for ch in text {
            let len = String(ch).utf16.count
            let inAlphabet = mapper.lookup(ch) != nil
            if !inAlphabet {
                if runStart == nil { runStart = utf16Offset }
            } else if let start = runStart {
                layoutManager.addTemporaryAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, forCharacterRange: NSRange(location: start, length: utf16Offset - start))
                runStart = nil
            }
            utf16Offset += len
        }
        if let start = runStart {
            layoutManager.addTemporaryAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, forCharacterRange: NSRange(location: start, length: utf16Offset - start))
        }
    }

    func reloadFromDocument() {
        guard let doc = ctDocument, !isUpdatingFromDocument else { return }
        isUpdatingFromDocument = true
        defer { isUpdatingFromDocument = false }
        switch viewMode {
        case .text:
            if scrollView.documentView !== textView { scrollView.documentView = textView }
            textView.isEditable = doc.isText
            textView.string = doc.text
            textView.undoManager?.removeAllActions()
        case .hex:
            if scrollView.documentView !== hexEditor { scrollView.documentView = hexEditor }
            hexEditor.bytes = doc.bytes
        }
        applyFontAndWrap()
        updateInfo()
        updateStatus()
    }

    private func hexEdited(_ bytes: [UInt8]) {
        guard let doc = ctDocument else { return }
        isUpdatingFromDocument = true
        doc.bytes = bytes
        isUpdatingFromDocument = false
        doc.updateChangeCount(.changeDone)
        updateStatus()
    }

    private func updateInfo() {
        guard let doc = ctDocument else { return }
        if let o = doc.origin {
            var s = o.title
            if let k = o.key, !o.title.contains(k) { s += " – Schlüssel: \(k)" }
            infoLabel.stringValue = s
        } else {
            infoLabel.stringValue = doc.fileURL?.path ?? "Neues Dokument"
        }
        window?.title = doc.displayName
    }

    private func updateStatus() {
        guard let doc = ctDocument else { return }
        var parts = ["\(doc.bytes.count) Bytes"]
        if viewMode == .text {
            parts.append("\(textView.string.count) Zeichen")
            let sel = textView.selectedRange()
            if sel.length > 0 { parts.append("Auswahl: \(sel.length)") }
            if !doc.isText { parts.append("Binärdaten – Textansicht schreibgeschützt (Ansicht ▸ Als HexDump anzeigen)") }
        } else {
            parts.append(hexEditor.statusDescription)
        }
        statusLabel.stringValue = parts.joined(separator: "  ·  ")
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String { displayName }

    func setViewMode(_ mode: DocumentViewMode) {
        viewMode = mode
        reloadFromDocument()
        window?.makeFirstResponder(mode == .hex ? hexEditor : textView)
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard viewMode == .text, let doc = ctDocument, !isUpdatingFromDocument else { return }
        isUpdatingFromDocument = true
        // New/CT1 documents are Windows-1252 like in CT1 (so e.g. a typed Vernam key has CT1's bytes);
        // a document that is already UTF-8 with non-ASCII characters keeps its encoding.
        let keepUTF8 = doc.bytes.contains { $0 >= 0x80 } && String(bytes: doc.bytes, encoding: .utf8) != nil
        doc.bytes = keepUTF8 ? Array(textView.string.utf8) : TextCoding.bytes(from: textView.string)
        isUpdatingFromDocument = false
        doc.updateChangeCount(.changeDone)
        if AppSettings.shared.viewAlphabet { applyAlphabetHighlighting() }
        updateStatus()
    }

    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }

    func windowDidResize(_ notification: Notification) { applyFontAndWrap() }

    /// The text currently selected (or the whole text if nothing is selected).
    var selectedOrAllText: String {
        let r = textView.selectedRange()
        if viewMode == .text, r.length > 0, let s = Range(r, in: textView.string) {
            return String(textView.string[s])
        }
        return ctDocument?.text ?? ""
    }

    // MARK: Actions

    @objc func performCTAction(_ sender: Any?) {
        guard let action = (sender as? NSMenuItem)?.ctAction, let doc = ctDocument else { return }
        if ContextHelp.consume(action) { return }
        switch action {
        case .viewAsText: setViewMode(.text)
        case .viewAsHex: setViewMode(.hex)
        case .findReplace: FindReplace.show(for: self)
        case .findNext: FindReplace.findNext()
        default:
            ActionRouter.perform(action, document: doc, window: window)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.ctAction else { return true }
        switch action {
        case .viewAsText:
            menuItem.state = viewMode == .text ? .on : .off
        case .viewAsHex:
            menuItem.state = viewMode == .hex ? .on : .off
        case .gotoParent:
            return ctDocument?.origin?.parent != nil
        case .showKey:
            return ctDocument?.origin?.key != nil
        default:
            return ActionRouter.validate(menuItem, action: action)
        }
        return true
    }
}
