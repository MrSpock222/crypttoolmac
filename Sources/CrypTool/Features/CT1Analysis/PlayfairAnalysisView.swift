import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Manuelle Analyse ▸ Playfair"
// (dialog IDD_PLAYFAIR_ANALYSIS "Playfair-Analyse: Manuelle Nachbearbeitung").

extension CT1Analysis {
    /// Opens CT1's manual Playfair analysis for `document` (non-modal tool window).
    static func openPlayfairAnalysis(document: CTDocument) {
        let session = PlayfairAnalysisSession(ciphertext: document.text)
        // CT1 shows the warning (InitListBox) before the dialog appears
        if let w = session.warning { Alerts.info(w.message) }
        let model = PlayfairAnalysisModel(document: document, session: session)
        let window = WindowPresenter.tool(id: "ct1-playfair-analysis-\(ObjectIdentifier(document).hashValue)",
                                          title: "Playfair Analysis: Manual Post-Processing",
                                          size: CGSize(width: 960, height: 720)) {
            PlayfairAnalysisView(model: model)
        }
        if model.window == nil { model.window = window }
        window.minSize = NSSize(width: 860, height: 640)
    }
}

/// UI state of the analysis window (wraps the CT1 port `PlayfairAnalysisSession`).
@MainActor
final class PlayfairAnalysisModel: ObservableObject {
    let document: CTDocument
    let session: PlayfairAnalysisSession
    weak var window: NSWindow?

    /// Bumped after every change of the session (the session itself is not observable).
    @Published private(set) var revision = 0
    /// "Vermuteter Klartext" (aligned character by character with the ciphertext).
    @Published private(set) var plaintext = ""
    /// "Vermuteten Klartext anhand der Matrix aktualisieren" (CT1 default: on).
    @Published var updateExpectedPlaintext = true
    /// Current consistency error of the guess (CT1 shows it in a message box).
    @Published private(set) var errorText: String?
    /// "Synchronisiere Analyseergebnis / Vermuteter Klartext".
    @Published private(set) var syncRequest = 0

    private var lastAlert: String?
    private var lastInvalidLetters = false

    init(document: CTDocument, session: PlayfairAnalysisSession) {
        self.document = document
        self.session = session
    }

    private func changed() { revision &+= 1 }

    // MARK: Actions (CT1 message handlers)

    /// CT1 `OnManAnalyse` (every change of the guessed plaintext).
    func plaintextEdited(_ text: String) {
        plaintext = text
        handle(session.analyzePlaintext(text))
        changed()
    }

    private func handle(_ r: PlayfairAnalysisSession.GuessResult) {
        // CT1 repeats its message box on every keystroke; here a message is shown once until it changes
        if r.containsInvalidLetters && !lastInvalidLetters {
            Alerts.error(PlayfairAnalysisSession.invalidGuessLetterMessage)
        }
        lastInvalidLetters = r.containsInvalidLetters
        errorText = r.error?.message
        if let m = r.error?.message, m != lastAlert { Alerts.error(m) }
        lastAlert = r.error?.message
    }

    /// CT1 `OnUpdate` (input in "Passwort").
    func passwordEdited(_ text: String) {
        if !session.setPassword(text) { NSSound.beep() }
        changed()
    }

    /// CT1 `OnCheck` ("Doppelte wurden ignoriert").
    func setIgnoreDuplicates(_ flag: Bool) {
        session.setIgnoreDuplicateLetters(flag)
        changed()
    }

    /// CT1 `OnSechs` ("5x5 Matrix" / "6x6 Matrix").
    func setSize(_ size: PlayfairCipher.Size) {
        guard size != session.size else { return }
        handle(session.setSize(size, guess: plaintext))
        changed()
    }

    /// CT1 `CChEdit::OnChar` (input in a matrix cell).
    func cellTyped(row: Int, column: Int, _ ch: Character) {
        if !session.setCell(row: row, column: column, to: ch) { NSSound.beep() }
        changed()
    }

    /// CT1 "Erzeuge Matrix" (`OnAnalyse`).
    func createMatrix() {
        let ok = session.createMatrix(guess: plaintext)
        changed()
        if !ok { Alerts.info(PlayfairAnalysisSession.noMatrixMessage) }
        if ok && updateExpectedPlaintext {
            plaintextEdited(session.expectedPlaintext)
        }
    }

    func synchronize() { syncRequest &+= 1 }

    /// CT1 "Ergebnis der Analyse ausgeben": decrypts the whole document with the matrix.
    func outputResult() {
        let s = session
        if CipherRun.text(document, method: "playfair", name: "Playfair", encrypt: false, key: s.password, {
            s.decryptAll()
        }) {
            window?.close()
        }
    }

    func cancel() { window?.close() }
}

struct PlayfairAnalysisView: View {
    @ObservedObject var model: PlayfairAnalysisModel

    private var session: PlayfairAnalysisSession { model.session }

    var body: some View {
        let lines = session.analysisLines
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                leftColumn.frame(width: 250)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Letter information")
                    letterTable
                }
            }
            Text("Analysis result: The following three rows contain ciphertext, input or result of the frequency analysis, found plaintext.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            PlayfairAnalysisTextPanel(lines: lines.cipher + "\n" + lines.guess + "\n" + lines.plain,
                                      plaintext: model.plaintext,
                                      size: session.size,
                                      syncRequest: model.syncRequest,
                                      onEdit: { model.plaintextEdited($0) })
                .frame(height: 150)
            if let e = model.errorText {
                Text(e.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption).foregroundStyle(.red)
                    .lineLimit(2)
            }
            HStack {
                Button("Output results of analysis") { model.outputResult() }
                    .keyboardShortcut(.defaultAction)
                Button("Synchronize analysis result / Expected plaintext") { model.synchronize() }
                Spacer()
                Button("Cancel") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 600)
    }

    // MARK: Left column: password and key matrix

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password:")
            TextField("", text: Binding(get: { session.password }, set: { model.passwordEdited($0) }))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
            GroupBox("Key matrix") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Duplicates are ignored",
                           isOn: Binding(get: { session.ignoreDuplicateLetters }, set: { model.setIgnoreDuplicates($0) }))
                    Picker("", selection: Binding(get: { session.size }, set: { model.setSize($0) })) {
                        Text("5x5 matrix").tag(PlayfairCipher.Size.fiveByFive)
                        Text("6x6 matrix").tag(PlayfairCipher.Size.sixBySix)
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                    .labelsHidden()
                    matrixGrid
                        .frame(maxWidth: .infinity)
                    Toggle("Update expected plaintext using the key matrix", isOn: $model.updateExpectedPlaintext)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer()
                        Button("Generate matrix") { model.createMatrix() }
                        Spacer()
                    }
                }
                .padding(6)
            }
        }
    }

    private var matrixGrid: some View {
        let d = session.size.dimension
        let m = session.matrix
        return Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(0..<6, id: \.self) { r in
                GridRow {
                    ForEach(0..<6, id: \.self) { c in
                        let active = r < d && c < d
                        PlayfairAnalysisCell(value: active ? String(m[r][c]) : "",
                                             enabled: active,
                                             onType: { model.cellTyped(row: r, column: c, $0) })
                            .frame(width: 28, height: 24)
                    }
                }
            }
        }
    }

    // MARK: Letter information table

    private var letterTable: some View {
        Table(session.letterInfos) {
            TableColumn(" ") { (i: PlayfairAnalysisLetterInfo) in Text(String(i.letter)).bold() }.width(22)
            TableColumn("LROU") { (i: PlayfairAnalysisLetterInfo) in Text(i.neighbours) }.width(48)
            TableColumn("Nb?") { (i: PlayfairAnalysisLetterInfo) in Text(i.possibleNeighbours) }.width(55)
            TableColumn("Horizontal") { (i: PlayfairAnalysisLetterInfo) in Text(i.horizontal) }.width(min: 80, ideal: 110)
            TableColumn("Vertical") { (i: PlayfairAnalysisLetterInfo) in Text(i.vertical) }.width(min: 70, ideal: 90)
            TableColumn("row or col?") { (i: PlayfairAnalysisLetterInfo) in Text(i.rowOrColumn) }.width(min: 90, ideal: 130)
            TableColumn("Metrik") { (i: PlayfairAnalysisLetterInfo) in Text("\(i.weight)") }.width(50)
        }
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 330)
    }
}

// MARK: - Matrix cell (CT1 CChEdit)

/// Single-letter matrix cell: a typed letter is handed to `onType` (which swaps letters like CT1);
/// the cell always shows the model value.
struct PlayfairAnalysisCell: NSViewRepresentable {
    let value: String
    let enabled: Bool
    let onType: (Character) -> Void

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var value = ""
        var onType: (Character) -> Void = { _ in }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let new = field.stringValue.uppercased()
            let old = value
            var typed: Character?
            if new.count > old.count, new.hasPrefix(old) { typed = new.last }
            else { typed = new.first { String($0) != old } }
            field.stringValue = old
            field.currentEditor()?.selectAll(nil)
            if let t = typed { onType(t) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSTextField {
        let f = NSTextField(string: value)
        f.alignment = .center
        f.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        f.isBezeled = true
        f.bezelStyle = .squareBezel
        f.focusRingType = .exterior
        f.delegate = context.coordinator
        f.cell?.usesSingleLineMode = true
        return f
    }

    func updateNSView(_ f: NSTextField, context: Context) {
        context.coordinator.value = value
        context.coordinator.onType = onType
        if f.stringValue != value {
            f.stringValue = value
            f.currentEditor()?.selectAll(nil)
        }
        f.isEnabled = enabled
        f.isEditable = enabled
    }
}

// MARK: - Analysis result + guessed plaintext (CT1 IDC_LIST, IDC_SCROLLBAR1, IDC_MYTXT)

/// The three-line analysis display and the "Vermuteter Klartext" input below it. Both use the same
/// monospaced font and scroll horizontally in sync, so every plaintext character stands below its
/// ciphertext character. The input works in overwrite mode like CT1's CPlayfairEdit.
struct PlayfairAnalysisTextPanel: NSViewRepresentable {
    let lines: String
    let plaintext: String
    let size: PlayfairCipher.Size
    let syncRequest: Int
    let onEdit: (String) -> Void

    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var onEdit: (String) -> Void = { _ in }
        var analysisView: NSTextView!
        var plainView: PlayfairOverwriteTextView!
        var analysisScroll: NSScrollView!
        var plainScroll: NSScrollView!
        var syncing = false
        var lastSync = 0

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, tv === plainView else { return }
            onEdit(tv.string)
            adjustWidths()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, tv === plainView else { return }
            tv.scrollRangeToVisible(tv.selectedRange())
        }

        @objc func boundsChanged(_ n: Notification) {
            guard !syncing, let clip = n.object as? NSClipView else { return }
            let target: NSScrollView = clip === analysisScroll.contentView ? plainScroll : analysisScroll
            syncing = true
            var o = target.contentView.bounds.origin
            o.x = clip.bounds.origin.x
            target.contentView.scroll(to: o)
            target.reflectScrolledClipView(target.contentView)
            syncing = false
        }

        /// Both documents get the same width so they can scroll together.
        func adjustWidths() {
            for tv in [analysisView!, plainView! as NSTextView] {
                if let lm = tv.layoutManager, let tc = tv.textContainer { lm.ensureLayout(for: tc) }
            }
            func used(_ tv: NSTextView) -> CGFloat {
                guard let lm = tv.layoutManager, let tc = tv.textContainer else { return 0 }
                return lm.usedRect(for: tc).width + 2 * tv.textContainerInset.width + 20
            }
            let w = max(used(analysisView), used(plainView), analysisScroll.contentSize.width)
            for tv in [analysisView!, plainView! as NSTextView] {
                tv.minSize = NSSize(width: w, height: tv.minSize.height)
                tv.setFrameSize(NSSize(width: w, height: tv.frame.height))
            }
        }

        /// CT1 "Synchronisiere": the analysis shows the columns around the input cursor.
        func synchronize() {
            plainView.scrollRangeToVisible(plainView.selectedRange())
            var o = analysisScroll.contentView.bounds.origin
            o.x = plainScroll.contentView.bounds.origin.x
            analysisScroll.contentView.scroll(to: o)
            analysisScroll.reflectScrolledClipView(analysisScroll.contentView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private static func configure(_ tv: NSTextView, scroll: NSScrollView, lines: Int) {
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let height = ceil(lineHeight * CGFloat(lines)) + 8
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = false
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        tv.font = font
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.textContainer?.lineFragmentPadding = 0
        tv.isHorizontallyResizable = true
        tv.isVerticallyResizable = false
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: height)
        tv.minSize = NSSize(width: 100, height: height)
        tv.frame = NSRect(x: 0, y: 0, width: 100, height: height)
        scroll.documentView = tv
        scroll.heightAnchor.constraint(equalToConstant: height + NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy) + 4).isActive = true
        scroll.contentView.postsBoundsChangedNotifications = true
    }

    func makeNSView(context: Context) -> NSStackView {
        let c = context.coordinator
        let analysis = NSTextView(frame: .zero)
        analysis.isEditable = false
        analysis.isSelectable = true
        let aScroll = NSScrollView(frame: .zero)
        Self.configure(analysis, scroll: aScroll, lines: 3)
        let plain = PlayfairOverwriteTextView(frame: .zero)
        plain.isEditable = true
        let pScroll = NSScrollView(frame: .zero)
        Self.configure(plain, scroll: pScroll, lines: 1)
        plain.delegate = c
        let label = NSTextField(labelWithString: "Expected plaintext:")
        let stack = NSStackView(views: [aScroll, label, pScroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        aScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        pScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        c.analysisView = analysis
        c.plainView = plain
        c.analysisScroll = aScroll
        c.plainScroll = pScroll
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.boundsChanged(_:)),
                                               name: NSView.boundsDidChangeNotification, object: aScroll.contentView)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.boundsChanged(_:)),
                                               name: NSView.boundsDidChangeNotification, object: pScroll.contentView)
        return stack
    }

    func updateNSView(_ stack: NSStackView, context: Context) {
        let c = context.coordinator
        c.onEdit = onEdit
        let s = size
        c.plainView.isPlayfairLetter = { ch in
            guard let v = ch.asciiValue else { return false }
            let u = (97...122).contains(v) ? v - 32 : v
            if (65...90).contains(u) { return s == .sixBySix || u != 74 }
            return s == .sixBySix && (48...57).contains(u)
        }
        if c.analysisView.string != lines { c.analysisView.string = lines }
        if c.plainView.string != plaintext {
            let sel = c.plainView.selectedRange()
            c.plainView.string = plaintext
            let len = (plaintext as NSString).length
            c.plainView.setSelectedRange(NSRange(location: min(sel.location, len), length: 0))
        }
        c.adjustWidths()
        if c.lastSync != syncRequest {
            c.lastSync = syncRequest
            c.synchronize()
            c.plainView.window?.makeFirstResponder(c.plainView)
        }
    }

    static func dismantleNSView(_ nsView: NSStackView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
}

/// Single-line text view in overwrite mode (CT1 CPlayfairEdit): a typed character replaces the
/// character at the cursor; input is converted to upper case; pasted text keeps Playfair letters and
/// replaces everything else by '*' (CT1 OnEditPaste).
final class PlayfairOverwriteTextView: NSTextView {
    var isPlayfairLetter: (Character) -> Bool = { _ in true }

    private static func upper(_ s: String) -> String {
        var out = ""
        for ch in s where ch != "\n" && ch != "\r" && ch != "\t" && ch != "\r\n" {
            let u = String(ch).uppercased()
            out += u.count == 1 ? u : String(ch)
        }
        return out
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let raw = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        let s = Self.upper(raw)
        guard !s.isEmpty else { return }
        var range = replacementRange
        if range.location == NSNotFound {
            range = selectedRange()
            let length = (self.string as NSString).length
            if range.length == 0 && range.location < length {
                range.length = min((s as NSString).length, length - range.location)
            }
        }
        super.insertText(s, replacementRange: range)
    }

    override func insertNewline(_ sender: Any?) { window?.selectNextKeyView(nil) }
    override func insertTab(_ sender: Any?) { window?.selectNextKeyView(nil) }
    override func insertBacktab(_ sender: Any?) { window?.selectPreviousKeyView(nil) }

    override func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        var mapped = ""
        for ch in text.unicodeScalars.map(Character.init) {
            if let v = ch.asciiValue, v >= 32, isPlayfairLetter(ch) { mapped.append(ch) } else { mapped.append("*") }
        }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: mapped) else { return }
        replaceCharacters(in: range, with: Self.upper(mapped))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (mapped as NSString).length, length: 0))
    }
}
