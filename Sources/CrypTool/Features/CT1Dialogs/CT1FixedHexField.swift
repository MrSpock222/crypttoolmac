import AppKit
import SwiftUI

/// CT1's `CHexEdit` with a fixed byte length (HexEdit.cpp, used by CDlgKeyHexFixedLen and the
/// brute-force dialog): the field always shows exactly `byteLength` bytes ("12 34 00 00 …").
/// Typed digits overwrite the digit under the cursor (the Insert key toggles insert mode),
/// pasted text is inserted, missing trailing digits are filled with `fill` ('0' for keys, '*' for
/// brute-force patterns) and surplus digits are cut off – so entering "12 34 AB CD" in a
/// 128-bit key field yields the key 12 34 AB CD 00 … 00 like in CT1.
struct CT1FixedHexField: NSViewRepresentable {
    @Binding var text: String
    let byteLength: Int
    var fill: Character = "0"
    /// Accept '*' (and '?' as '*') – brute-force patterns.
    var allowStar = false

    static func digits(_ s: String, allowStar: Bool) -> [Character] {
        s.uppercased().compactMap { c -> Character? in
            if c.isASCII && c.isHexDigit { return c }
            if allowStar && (c == "*" || c == "?") { return "*" }
            return nil
        }
    }

    static func format(_ d: [Character]) -> String {
        var out = ""
        for (i, c) in d.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(c)
        }
        return out
    }

    /// Normalized representation (exactly `byteLength` bytes).
    static func normalize(_ s: String, byteLength: Int, fill: Character, allowStar: Bool) -> String {
        var d = digits(s, allowStar: allowStar)
        let n = 2 * byteLength
        if d.count > n { d = Array(d.prefix(n)) }
        while d.count < n { d.append(fill) }
        return format(d)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let tv = HexTextView(frame: .zero)
        tv.coordinator = context.coordinator
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tv.textContainerInset = NSSize(width: 2, height: 4)
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        let sv = NSScrollView()
        sv.documentView = tv
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .bezelBorder
        sv.drawsBackground = true
        tv.string = Self.normalize(text, byteLength: byteLength, fill: fill, allowStar: allowStar)
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = sv.documentView as? NSTextView else { return }
        let normalized = Self.normalize(text, byteLength: byteLength, fill: fill, allowStar: allowStar)
        if tv.string != normalized {
            let sel = tv.selectedRange()
            tv.string = normalized
            tv.setSelectedRange(NSRange(location: min(sel.location, (normalized as NSString).length), length: 0))
        }
        if text != normalized {
            let binding = $text
            DispatchQueue.main.async { binding.wrappedValue = normalized }
        }
    }

    final class HexTextView: NSTextView {
        weak var coordinator: Coordinator?

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 114 { coordinator?.insertMode.toggle(); return }   // Insert / Help key
            super.keyDown(with: event)
        }
        override func insertTab(_ sender: Any?) { window?.selectNextKeyView(sender) }
        override func insertBacktab(_ sender: Any?) { window?.selectPreviousKeyView(sender) }
        override func insertNewline(_ sender: Any?) {
            // Return triggers the dialog's default button, as in CT1's single-line edit control.
            if let event = NSApp.currentEvent, let content = window?.contentView,
               content.performKeyEquivalent(with: event) { return }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CT1FixedHexField
        var insertMode = false

        init(_ parent: CT1FixedHexField) { self.parent = parent }

        /// Digit index at a display position (CHexEdit::shrink).
        private func digitIndex(_ p: Int) -> Int { p - p / 3 }
        /// Display position of a digit index (CHexEdit::extend).
        private func displayPos(_ d: Int, length: Int) -> Int {
            min(d + d / 2, max(0, length + (length - 1) / 2))
        }

        func textView(_ tv: NSTextView, shouldChangeTextIn range: NSRange, replacementString s: String?) -> Bool {
            guard let s else { return false }
            let n = 2 * parent.byteLength
            var d = CT1FixedHexField.digits(tv.string, allowStar: parent.allowStar)
            while d.count < n { d.append(parent.fill) }
            let typed = CT1FixedHexField.digits(s, allowStar: parent.allowStar)
            let invalid = s.contains { !$0.isWhitespace } && typed.count != s.filter { !$0.isWhitespace }.count
            if invalid { NSSound.beep() }
            if !s.isEmpty && typed.isEmpty { return false }

            var a = min(digitIndex(range.location), n)
            var b = min(digitIndex(range.location + range.length), n)
            if s.isEmpty && a == b {
                // only a separator was to be deleted: delete the neighbouring digit instead
                let cursor = tv.selectedRange().location
                if cursor >= range.location + range.length { a = max(0, a - 1) } else { b = min(n, b + 1) }
            }
            var cursor: Int
            if range.length == 0 && !insertMode && typed.count == 1 && a < n {
                d[a] = typed[0]                      // overwrite mode (CT1 default)
                cursor = a + 1
            } else {
                d.replaceSubrange(a..<b, with: typed)
                cursor = a + typed.count
            }
            if d.count > n { d = Array(d.prefix(n)) }
            while d.count < n { d.append(parent.fill) }
            cursor = min(cursor, n)
            let formatted = CT1FixedHexField.format(d)
            tv.string = formatted
            tv.setSelectedRange(NSRange(location: displayPos(cursor, length: n), length: 0))
            parent.text = formatted
            return false
        }
    }
}
