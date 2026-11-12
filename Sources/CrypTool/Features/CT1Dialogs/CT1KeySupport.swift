import AppKit
import SwiftUI
import CTCommon

/// CT1 key store ("Schlüsselspeicher", KeyRepository.cpp): "Schlüssel anzeigen ▸ Schlüssel kopieren"
/// stores the key of a document per method; the paste buttons of the key dialogs insert it again.
/// Deliberately separate from the system clipboard (as in CT1).
final class CT1KeyStore: ObservableObject {
    static let shared = CT1KeyStore()
    @Published private(set) var keys: [String: String] = [:]

    /// Stores `key` for the method identifier (e.g. "caesar", "hill", "sym.aes").
    func copy(_ key: String, method: String) { keys[method] = key }

    func key(for method: String) -> String? {
        guard let k = keys[method], !k.isEmpty else { return nil }
        return k
    }
}

/// CT1's bitmap "Paste" button (tooltip "Schlüssel aus Schlüsselspeicher einfügen"); enabled only
/// if the key store holds a key of this method.
struct CT1PasteKeyButton: View {
    let method: String
    let paste: (String) -> Void
    @ObservedObject private var store = CT1KeyStore.shared

    var body: some View {
        Button {
            if let k = store.key(for: method) { paste(k) }
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .help("Schlüssel aus Schlüsselspeicher einfügen")
        .disabled(store.key(for: method) == nil)
    }
}

/// Radio button usable inside custom layouts (CT1 dialogs place edits next to their radios).
struct CT1Radio: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(title)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Group box with a leading-aligned content stack (CT1 GROUPBOX).
struct CT1Group<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 6) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
    }
}

/// Read-only single line (CT1 ES_READONLY edit), scrollable for long alphabets.
struct CT1ReadOnlyLine: View {
    let text: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text.isEmpty ? " " : text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}

/// Input filters of CT1's key dialogs.
enum CT1KeyInput {
    /// CrypToolTools.cpp `adaptKeyToAlphabet`: lowercase letters (a–z, ä, ö, ü) are converted to
    /// uppercase if they are not part of the alphabet but their uppercase form is.
    static func adapt(_ key: String, alphabet: [Character]) -> String {
        let set = Set(alphabet)
        return String(key.map { ch -> Character in
            guard "abcdefghijklmnopqrstuvwxyzäöü".contains(ch), !set.contains(ch),
                  let up = String(ch).uppercased().first, set.contains(up) else { return ch }
            return up
        })
    }

    /// DlgKey.cpp `OnUpdateEdit1`: adapts case, removes characters that are not in the alphabet.
    /// Returns the filtered key and whether characters were rejected (CT1 beeps).
    static func filter(_ key: String, alphabet: [Character], maxLength: Int? = nil) -> (String, Bool) {
        let set = Set(alphabet)
        let adapted = adapt(key, alphabet: alphabet)
        var out = String(adapted.filter { set.contains($0) })
        var rejected = out.count != adapted.count
        if let m = maxLength, out.count > m { out = String(out.prefix(m)); rejected = true }
        return (out, rejected)
    }

    /// Hex key field of CT1 (CHexEdit): uppercase hex digits grouped in bytes ("4B 45 59").
    static func hex(_ s: String, maxDigits: Int? = nil) -> (String, Bool) {
        var digits = s.uppercased().filter { $0.isHexDigit && $0.isASCII }
        let rejected = digits.count != s.filter { !$0.isWhitespace }.count
        if let m = maxDigits, digits.count > m { digits = String(digits.prefix(m)) }
        var out = ""
        for (i, d) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(d)
        }
        return (out, rejected)
    }

    /// Bytes of a hex key (nil if the digit count is odd or zero).
    static func hexBytes(_ s: String) -> [UInt8]? {
        let d = s.filter { !$0.isWhitespace }
        guard !d.isEmpty, d.count % 2 == 0 else { return nil }
        return Hex.decode(d)
    }
}

extension View {
    /// Applies a CT1 input filter live (rejected characters → beep, like CT1's `MessageBeep`).
    func ct1Filter(_ text: Binding<String>, _ transform: @escaping (String) -> (String, Bool)) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            let (f, rejected) = transform(new)
            if rejected { NSSound.beep() }
            if f != new { text.wrappedValue = f }
        }
    }
}

/// Small helpers shared by the CT1 dialogs.
@MainActor
enum CT1 {
    /// Window of a document (for sheets opened after the key dialog has closed).
    static func window(of doc: CTDocument) -> NSWindow? {
        doc.windowControllers.first?.window ?? NSApp.keyWindow
    }

    /// CT1 title "%s-Verschlüsselung von <%s>, Schlüssel <%s>" / "…-Entschlüsselung …".
    static func title(_ name: String, encrypt: Bool, of doc: CTDocument, key: String) -> String {
        DocumentFactory.title("\(name)-\(encrypt ? "Verschlüsselung" : "Entschlüsselung")", of: doc, key: key)
    }

    /// Writes `blockSize` characters per block followed by a blank or a line break (also after the
    /// last complete block) – adfgvx.cpp `writeCiphertext`/`writeStage1`.
    static func blocks(_ s: String, size: Int, newLine: Bool) -> String {
        guard size > 0 else { return s }
        var out = String()
        var i = 0
        for ch in s {
            out.append(ch)
            i += 1
            if i % size == 0 { out.append(newLine ? "\n" : " ") }
        }
        return out
    }

    /// Asks for a file name and writes `text` (CT1 "Speichern" buttons).
    static func save(_ text: String, defaultName: String) {
        let p = NSSavePanel()
        p.nameFieldStringValue = defaultName
        guard p.runModal() == .OK, let url = p.url else { return }
        do { try Data(text.utf8).write(to: url) } catch { Alerts.error(error.localizedDescription) }
    }
}
