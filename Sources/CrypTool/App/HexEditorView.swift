import AppKit
import CTCommon

/// Editable hex view like CT1's HexEdit control: offset | 16 hex bytes | ASCII.
/// Typing hex digits (hex column) or characters (ASCII column) overwrites bytes; typing at the
/// end appends. Backspace/Delete remove bytes, Tab switches between the columns.
final class HexEditorView: NSView, NSMenuItemValidation {
    var bytes: [UInt8] = [] {
        didSet {
            cursor = min(cursor, bytes.count)
            updateFrameSize()
            needsDisplay = true
        }
    }
    /// Called after every user edit with the new contents.
    var onChange: (([UInt8]) -> Void)?
    /// Called when cursor or selection change (for the status bar).
    var onSelectionChange: (() -> Void)?

    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet { updateMetrics(); updateFrameSize(); needsDisplay = true }
    }

    private(set) var cursor = 0
    private var lowNibble = false
    private var asciiFocus = false
    private var anchor: Int?
    private var charWidth: CGFloat = 8
    private var lineHeight: CGFloat = 16
    private let bytesPerLine = 16
    private let inset: CGFloat = 6

    /// Selected byte range (empty if nothing selected).
    var selection: Range<Int> {
        guard let a = anchor, a != cursor else { return cursor..<cursor }
        return min(a, cursor)..<max(a, cursor)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        updateMetrics()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }

    // MARK: Geometry

    private func updateMetrics() {
        charWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        lineHeight = ceil(font.ascender - font.descender + font.leading) + 2
    }

    private var lineCount: Int { max(1, (bytes.count + bytesPerLine) / bytesPerLine) }

    private func updateFrameSize() {
        let width = inset * 2 + CGFloat(10 + bytesPerLine * 3 + 1 + 2 + bytesPerLine) * charWidth
        let height = inset * 2 + CGFloat(lineCount) * lineHeight
        let visibleHeight = enclosingScrollView?.contentSize.height ?? 0
        setFrameSize(NSSize(width: max(width, enclosingScrollView?.contentSize.width ?? 0), height: max(height, visibleHeight)))
    }

    private func hexX(_ column: Int) -> CGFloat {
        inset + CGFloat(10 + column * 3 + (column >= 8 ? 1 : 0)) * charWidth
    }

    private func asciiX(_ column: Int) -> CGFloat {
        inset + CGFloat(10 + bytesPerLine * 3 + 1 + 2 + column) * charWidth
    }

    private func lineY(_ line: Int) -> CGFloat { inset + CGFloat(line) * lineHeight }

    /// Byte index and column type for a point.
    private func hit(_ p: NSPoint) -> (index: Int, ascii: Bool, low: Bool) {
        let line = max(0, Int((p.y - inset) / lineHeight))
        let asciiStart = asciiX(0)
        if p.x >= asciiStart - charWidth {
            let col = min(bytesPerLine - 1, max(0, Int((p.x - asciiStart) / charWidth)))
            return (min(bytes.count, line * bytesPerLine + col), true, false)
        }
        var best = 0
        for c in 0..<bytesPerLine where p.x >= hexX(c) - charWidth / 2 { best = c }
        let low = p.x >= hexX(best) + charWidth
        return (min(bytes.count, line * bytesPerLine + best), false, low)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        let first = max(0, Int((dirtyRect.minY - inset) / lineHeight))
        let last = min(lineCount - 1, Int((dirtyRect.maxY - inset) / lineHeight) + 1)
        guard first <= last else { return }

        let offsetAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor]
        let dimAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
        let sel = selection
        let focused = window?.firstResponder === self && window?.isKeyWindow == true
        let selColor = focused ? NSColor.selectedTextBackgroundColor : NSColor.unemphasizedSelectedTextBackgroundColor

        // column separators
        NSColor.separatorColor.setFill()
        NSRect(x: hexX(0) - charWidth, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
        NSRect(x: asciiX(0) - charWidth * 1.5, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()

        for line in first...last {
            let y = lineY(line)
            let start = line * bytesPerLine
            (String(format: "%08X", start) as NSString).draw(at: NSPoint(x: inset, y: y), withAttributes: offsetAttrs)
            for col in 0..<bytesPerLine {
                let i = start + col
                guard i < bytes.count else { break }
                let b = bytes[i]
                if sel.contains(i) {
                    selColor.setFill()
                    NSRect(x: hexX(col) - 1, y: y, width: charWidth * 2 + 2, height: lineHeight).fill()
                    NSRect(x: asciiX(col), y: y, width: charWidth, height: lineHeight).fill()
                }
                (String(format: "%02X", b) as NSString).draw(at: NSPoint(x: hexX(col), y: y), withAttributes: textAttrs)
                let printable = b >= 0x20 && b < 0x7F
                (String(printable ? Character(UnicodeScalar(b)) : ".") as NSString)
                    .draw(at: NSPoint(x: asciiX(col), y: y), withAttributes: printable ? textAttrs : dimAttrs)
            }
        }

        // caret
        let cl = cursor / bytesPerLine, cc = cursor % bytesPerLine
        if (first...last).contains(cl) {
            let y = lineY(cl)
            let caretColor = focused ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
            caretColor.setFill()
            let hx = hexX(cc) + (lowNibble ? charWidth : 0)
            let ax = asciiX(cc)
            if asciiFocus {
                NSRect(x: ax, y: y, width: 2, height: lineHeight).fill()
                caretColor.withAlphaComponent(0.35).setStroke()
                NSBezierPath(rect: NSRect(x: hexX(cc) - 1, y: y + 0.5, width: charWidth * 2 + 2, height: lineHeight - 1)).stroke()
            } else {
                NSRect(x: hx, y: y + lineHeight - 2, width: charWidth, height: 2).fill()
                NSRect(x: hx, y: y, width: 1.5, height: lineHeight).fill()
                caretColor.withAlphaComponent(0.35).setStroke()
                NSBezierPath(rect: NSRect(x: ax + 0.5, y: y + 0.5, width: charWidth - 1, height: lineHeight - 1)).stroke()
            }
        }
    }

    // MARK: Cursor movement

    private func move(to index: Int, extend: Bool) {
        if extend { if anchor == nil { anchor = cursor } } else { anchor = nil }
        cursor = max(0, min(bytes.count, index))
        lowNibble = false
        scrollToCursor()
        needsDisplay = true
        onSelectionChange?()
    }

    private func scrollToCursor() {
        let y = lineY(cursor / bytesPerLine)
        scrollToVisible(NSRect(x: 0, y: y - lineHeight, width: 1, height: lineHeight * 3))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let h = hit(convert(event.locationInWindow, from: nil))
        asciiFocus = h.ascii
        if event.modifierFlags.contains(.shift) {
            move(to: h.index, extend: true)
        } else {
            move(to: h.index, extend: false)
            lowNibble = h.low && !h.ascii && h.index < bytes.count
            anchor = cursor
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let h = hit(convert(event.locationInWindow, from: nil))
        let a = anchor ?? cursor
        cursor = min(bytes.count, h.index >= a ? h.index + 1 : h.index)
        anchor = a
        autoscroll(with: event)
        needsDisplay = true
        onSelectionChange?()
    }

    // MARK: Editing

    private func replace(_ range: Range<Int>, with new: [UInt8], cursorAfter: Int, actionName: String) {
        let old = bytes
        var b = bytes
        b.replaceSubrange(range, with: new)
        apply(b, cursor: cursorAfter)
        registerUndo(old: old, actionName: actionName)
    }

    private func apply(_ b: [UInt8], cursor c: Int) {
        bytes = b
        cursor = max(0, min(b.count, c))
        anchor = nil
        onChange?(b)
        scrollToCursor()
        needsDisplay = true
        onSelectionChange?()
    }

    private func registerUndo(old: [UInt8], actionName: String) {
        guard let um = undoManager else { return }
        let current = bytes, cur = cursor
        um.registerUndo(withTarget: self) { view in
            view.apply(old, cursor: min(cur, old.count))
            view.registerUndoRestore(current)
        }
        um.setActionName(actionName)
    }

    private func registerUndoRestore(_ newer: [UInt8]) {
        guard let um = undoManager else { return }
        let old = bytes
        um.registerUndo(withTarget: self) { view in
            view.apply(newer, cursor: view.cursor)
            view.registerUndo(old: old, actionName: "Bearbeiten")
        }
    }

    private func typeHexDigit(_ v: UInt8) {
        let sel = selection
        if !sel.isEmpty {
            replace(sel, with: [v << 4], cursorAfter: sel.lowerBound, actionName: "Eingabe")
            lowNibble = true
            return
        }
        let old = bytes
        var b = bytes
        if cursor >= b.count {
            b.append(v << 4)
            apply(b, cursor: b.count - 1)
            lowNibble = true
        } else if !lowNibble {
            b[cursor] = (v << 4) | (b[cursor] & 0x0F)
            apply(b, cursor: cursor)
            lowNibble = true
        } else {
            b[cursor] = (b[cursor] & 0xF0) | v
            apply(b, cursor: cursor + 1)
            lowNibble = false
        }
        registerUndo(old: old, actionName: "Eingabe")
        needsDisplay = true
    }

    private func typeASCII(_ ch: UInt8) {
        let sel = selection
        if !sel.isEmpty {
            replace(sel, with: [ch], cursorAfter: sel.lowerBound + 1, actionName: "Eingabe")
            return
        }
        if cursor >= bytes.count {
            replace(bytes.count..<bytes.count, with: [ch], cursorAfter: bytes.count + 1, actionName: "Eingabe")
        } else {
            replace(cursor..<cursor + 1, with: [ch], cursorAfter: cursor + 1, actionName: "Eingabe")
        }
    }

    override func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let cmd = event.modifierFlags.contains(.command)
        guard let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first else {
            super.keyDown(with: event); return
        }
        switch Int(scalar.value) {
        case NSLeftArrowFunctionKey:
            if !asciiFocus && lowNibble && !shift { lowNibble = false; needsDisplay = true } else { move(to: cursor - 1, extend: shift) }
        case NSRightArrowFunctionKey:
            if !asciiFocus && !lowNibble && !shift && cursor < bytes.count { lowNibble = true; needsDisplay = true } else { move(to: cursor + 1, extend: shift) }
        case NSUpArrowFunctionKey:
            move(to: cmd ? 0 : (cursor >= bytesPerLine ? cursor - bytesPerLine : cursor), extend: shift)
        case NSDownArrowFunctionKey:
            move(to: cmd ? bytes.count : min(bytes.count, cursor + bytesPerLine), extend: shift)
        case NSHomeFunctionKey: move(to: cmd ? 0 : cursor - cursor % bytesPerLine, extend: shift)
        case NSEndFunctionKey: move(to: cmd ? bytes.count : min(bytes.count, cursor - cursor % bytesPerLine + bytesPerLine - 1), extend: shift)
        case NSPageUpFunctionKey: move(to: cursor - pageBytes, extend: shift)
        case NSPageDownFunctionKey: move(to: cursor + pageBytes, extend: shift)
        case 0x09, 0x19: // tab / backtab
            asciiFocus.toggle(); lowNibble = false; needsDisplay = true
        case 0x7F: // backspace
            let sel = selection
            if !sel.isEmpty { replace(sel, with: [], cursorAfter: sel.lowerBound, actionName: "Löschen") }
            else if cursor > 0 { replace(cursor - 1..<cursor, with: [], cursorAfter: cursor - 1, actionName: "Löschen") }
        case NSDeleteFunctionKey:
            let sel = selection
            if !sel.isEmpty { replace(sel, with: [], cursorAfter: sel.lowerBound, actionName: "Löschen") }
            else if cursor < bytes.count { replace(cursor..<cursor + 1, with: [], cursorAfter: cursor, actionName: "Löschen") }
        default:
            guard !cmd, let typed = event.characters?.unicodeScalars.first else { super.keyDown(with: event); return }
            if asciiFocus {
                if typed.value >= 0x20 && typed.value < 0x7F { typeASCII(UInt8(typed.value)) } else { NSSound.beep() }
            } else if let v = Hex.decode("0" + String(typed)), v.count == 1 {
                typeHexDigit(v[0])
            } else {
                NSSound.beep()
            }
        }
    }

    private var pageBytes: Int {
        let lines = max(1, Int((enclosingScrollView?.contentSize.height ?? 300) / lineHeight) - 1)
        return lines * bytesPerLine
    }

    // MARK: Edit menu

    @objc func copy(_ sender: Any?) {
        let sel = selection
        guard !sel.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        let part = Array(bytes[sel])
        pb.setString(asciiFocus ? TextCoding.string(from: part) : Hex.encode(part), forType: .string)
    }

    @objc func cut(_ sender: Any?) {
        copy(sender)
        let sel = selection
        if !sel.isEmpty { replace(sel, with: [], cursorAfter: sel.lowerBound, actionName: "Ausschneiden") }
    }

    @objc func paste(_ sender: Any?) {
        guard let s = NSPasteboard.general.string(forType: .string) else { return }
        let new = (!asciiFocus ? Hex.decode(s) : nil) ?? TextCoding.bytes(from: s)
        let sel = selection
        replace(sel, with: new, cursorAfter: sel.lowerBound + new.count, actionName: "Einfügen")
    }

    @objc func delete(_ sender: Any?) {
        let sel = selection
        if !sel.isEmpty { replace(sel, with: [], cursorAfter: sel.lowerBound, actionName: "Löschen") }
    }

    /// CT1 context menu (IDR_CONTEXT_MENU).
    override func menu(for event: NSEvent) -> NSMenu? {
        CT1ContextMenu.make(hexView: true)
    }

    override func selectAll(_ sender: Any?) {
        anchor = 0
        cursor = bytes.count
        needsDisplay = true
        onSelectionChange?()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(copy(_:)), #selector(cut(_:)), #selector(delete(_:)): return !selection.isEmpty
        case #selector(paste(_:)): return NSPasteboard.general.string(forType: .string) != nil
        default: return true
        }
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateFrameSize()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateFrameSize()
    }

    /// Selects a byte range (used by "Suchen und Ersetzen").
    func select(_ range: Range<Int>) {
        anchor = range.lowerBound
        cursor = min(bytes.count, range.upperBound)
        lowNibble = false
        scrollToCursor()
        needsDisplay = true
        onSelectionChange?()
    }

    var selectedBytes: [UInt8] { Array(bytes[selection]) }

    func replaceSelection(with new: [UInt8]) {
        let sel = selection
        replace(sel, with: new, cursorAfter: sel.lowerBound + new.count, actionName: "Ersetzen")
    }

    var statusDescription: String {
        let sel = selection
        var s = String(format: "Offset %08X (%d)", cursor, cursor)
        if !sel.isEmpty { s += "  ·  Auswahl: \(sel.count) Bytes" }
        s += asciiFocus ? "  ·  ASCII-Spalte" : "  ·  Hex-Spalte (Tab wechselt)"
        return s
    }
}
