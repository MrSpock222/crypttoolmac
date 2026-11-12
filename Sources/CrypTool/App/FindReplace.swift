import AppKit
import SwiftUI
import CTCommon

/// CT1 "Suchen und Ersetzen" (IDD_FIND_AND_REPLACE): text or hex search in the active document.
@MainActor
final class FindState: ObservableObject {
    static let shared = FindState()
    @Published var search = ""
    @Published var replace = ""
    @Published var hexMode = false
    @Published var caseSensitive = false
    @Published var backwards = false
    @Published var regex = false
}

@MainActor
enum FindReplace {
    static func show(for controller: DocumentWindowController) {
        FindState.shared.hexMode = controller.viewMode == .hex
        WindowPresenter.tool(id: "findreplace", title: "Suchen und Ersetzen", size: CGSize(width: 520, height: 300), resizable: false) {
            FindReplaceView()
        }
    }

    /// The document window the dialog works on (frontmost document window).
    static var target: DocumentWindowController? {
        NSApp.orderedWindows.compactMap { $0.windowController as? DocumentWindowController }.first
    }

    /// "Suche nächstes" (F3 in CT1, ⌘G here).
    static func findNext() {
        guard let c = target, !FindState.shared.search.isEmpty else { NSSound.beep(); return }
        if !c.find(FindState.shared) { NSSound.beep() }
    }
}

struct FindReplaceView: View {
    @ObservedObject private var state = FindState.shared
    @CTState private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Modus", selection: $state.hexMode) {
                Text("Text").tag(false)
                Text("Hex").tag(true)
            }.pickerStyle(.segmented).frame(width: 200)
            HStack {
                Text("Suchen nach:").frame(width: 100, alignment: .leading)
                TextField(state.hexMode ? "z. B. 4B 45 59" : "", text: $state.search).font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Ersetzen durch:").frame(width: 100, alignment: .leading)
                TextField("", text: $state.replace).font(.system(.body, design: .monospaced))
            }
            HStack(spacing: 18) {
                Toggle("Groß-/Kleinschreibung beachten", isOn: $state.caseSensitive).disabled(state.hexMode)
                Toggle("Rückwärtssuche", isOn: $state.backwards)
            }
            Toggle("Reguläre Ausdrücke im Suchfeld erlauben (nur in der Text-Ansicht)", isOn: $state.regex).disabled(state.hexMode)
            if !message.isEmpty { Text(message).font(.callout).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            HStack {
                Button("Weitersuchen") { run { $0.find(state) ? "" : "Nicht gefunden." } }.keyboardShortcut(.defaultAction)
                Button("Ersetzen") { run { $0.replaceCurrent(state) ? "" : "Nicht gefunden." } }
                Button("Alle ersetzen") { run { "\($0.replaceAll(state)) Stelle(n) ersetzt." } }
                Spacer()
                Button("Schließen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
    }

    private func run(_ f: (DocumentWindowController) -> String) {
        guard let c = FindReplace.target else { message = "Kein Dokument geöffnet."; return }
        if state.hexMode && Hex.decode(state.search) == nil { message = "Ungültige Hex-Eingabe."; return }
        message = f(c)
    }
}

extension DocumentWindowController {
    /// Byte pattern for hex mode, or nil.
    private func hexPattern(_ s: String) -> [UInt8]? {
        guard let b = Hex.decode(s), !b.isEmpty else { return nil }
        return b
    }

    @discardableResult
    func find(_ state: FindState) -> Bool {
        if state.hexMode {
            if viewMode != .hex { setViewMode(.hex) }
            guard let p = hexPattern(state.search), let bytes = ctDocument?.bytes else { return false }
            let start = hexEditorView.cursor
            if let r = HexSearch.find(p, in: bytes, from: start, backwards: state.backwards) {
                hexEditorView.select(r)
                window?.makeKeyAndOrderFront(nil)
                return true
            }
            return false
        }
        if viewMode != .text { setViewMode(.text) }
        let tv = textEditorView
        let ns = tv.string as NSString
        let sel = tv.selectedRange()
        var options: NSString.CompareOptions = state.caseSensitive ? [] : [.caseInsensitive]
        if state.regex { options.insert(.regularExpression) }
        let range: NSRange
        if state.backwards {
            options.insert(.backwards)
            range = NSRange(location: 0, length: sel.location)
        } else {
            let from = NSMaxRange(sel)
            range = NSRange(location: from, length: ns.length - from)
        }
        let r = ns.range(of: state.search, options: options, range: range)
        guard r.location != NSNotFound else { return false }
        tv.setSelectedRange(r)
        tv.scrollRangeToVisible(r)
        tv.showFindIndicator(for: r)
        window?.makeKeyAndOrderFront(nil)
        return true
    }

    func replaceCurrent(_ state: FindState) -> Bool {
        if state.hexMode {
            guard let p = hexPattern(state.search), hexEditorView.selectedBytes == p,
                  let repl = Hex.decode(state.replace) else { return find(state) }
            hexEditorView.replaceSelection(with: repl)
            return find(state)
        }
        let tv = textEditorView
        let sel = tv.selectedRange()
        let current = (tv.string as NSString).substring(with: sel)
        let matches = state.caseSensitive ? current == state.search : current.caseInsensitiveCompare(state.search) == .orderedSame
        if sel.length > 0 && (matches || state.regex), tv.shouldChangeText(in: sel, replacementString: state.replace) {
            tv.replaceCharacters(in: sel, with: state.replace)
            tv.didChangeText()
        }
        return find(state)
    }

    func replaceAll(_ state: FindState) -> Int {
        if state.hexMode {
            guard let p = hexPattern(state.search), let repl = Hex.decode(state.replace), let doc = ctDocument else { return 0 }
            let (out, n) = HexSearch.replaceAll(p, with: repl, in: doc.bytes)
            if n > 0 {
                doc.bytes = out
                doc.updateChangeCount(.changeDone)
            }
            return n
        }
        let tv = textEditorView
        var options: NSString.CompareOptions = state.caseSensitive ? [] : [.caseInsensitive]
        if state.regex { options.insert(.regularExpression) }
        let ns = tv.string as NSString
        var count = 0
        var searchRange = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: state.search, options: options, range: searchRange)
            if r.location == NSNotFound || r.length == 0 { break }
            count += 1
            searchRange = NSRange(location: NSMaxRange(r), length: ns.length - NSMaxRange(r))
        }
        guard count > 0 else { return 0 }
        let replaced = ns.replacingOccurrences(of: state.search, with: state.replace, options: options, range: NSRange(location: 0, length: ns.length))
        let full = NSRange(location: 0, length: ns.length)
        if tv.shouldChangeText(in: full, replacementString: replaced) {
            tv.replaceCharacters(in: full, with: replaced)
            tv.didChangeText()
        }
        return count
    }
}

enum HexSearch {
    static func find(_ p: [UInt8], in b: [UInt8], from: Int, backwards: Bool) -> Range<Int>? {
        guard !p.isEmpty, b.count >= p.count else { return nil }
        if backwards {
            var i = min(from - 1, b.count - p.count)
            while i >= 0 {
                if b[i..<i + p.count].elementsEqual(p) { return i..<i + p.count }
                i -= 1
            }
        } else {
            var i = max(0, from)
            while i + p.count <= b.count {
                if b[i..<i + p.count].elementsEqual(p) { return i..<i + p.count }
                i += 1
            }
        }
        return nil
    }

    static func replaceAll(_ p: [UInt8], with r: [UInt8], in b: [UInt8]) -> ([UInt8], Int) {
        var out: [UInt8] = []
        out.reserveCapacity(b.count)
        var i = 0, n = 0
        while i < b.count {
            if i + p.count <= b.count, b[i..<i + p.count].elementsEqual(p) {
                out += r; i += p.count; n += 1
            } else {
                out.append(b[i]); i += 1
            }
        }
        return (out, n)
    }
}
