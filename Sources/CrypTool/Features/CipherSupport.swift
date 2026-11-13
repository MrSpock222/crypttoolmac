import AppKit
import SwiftUI
import CTCommon

/// Remembers the last key per method (CT1 key repository) so decryption dialogs can be pre-filled.
@MainActor
enum KeyMemory {
    private static var last: [String: String] = [:]
    private static var objects: [String: Any] = [:]

    static func initial(for method: String, document: CTDocument?) -> String? {
        if let o = document?.origin, o.method == method, let k = o.key { return k }
        return last[method]
    }

    static func remember(_ key: String, for method: String) { last[method] = key }

    static func object<T>(for method: String, document: CTDocument?, as type: T.Type) -> T? {
        objects[method] as? T
    }

    static func rememberObject(_ value: Any, for method: String) { objects[method] = value }
}

/// Helpers for producing result documents of cipher operations.
@MainActor
enum CipherRun {
    /// Runs a text transformation and opens the result window (CT1 title pattern).
    static func text(_ doc: CTDocument, method: String, name: String, encrypt: Bool, key: String,
                     _ transform: () throws -> String) -> Bool {
        do {
            let result = try transform()
            KeyMemory.remember(key, for: method)
            let op = "\(name) \(encrypt ? "encryption" : "decryption")"
            DocumentFactory.openResult(text: result, title: DocumentFactory.title(op, of: doc, key: key),
                                       parent: doc, method: method, key: key)
            return true
        } catch {
            Alerts.error(error.localizedDescription)
            return false
        }
    }

    /// Like `text(…)` with a complete CT1 window title; returns the opened document (nil on error).
    @discardableResult
    static func open(text doc: CTDocument, method: String, title: String, key: String,
                     _ transform: () throws -> String) -> CTDocument? {
        do {
            let result = try transform()
            KeyMemory.remember(key, for: method)
            return DocumentFactory.openResult(text: result, title: title, parent: doc, method: method, key: key)
        } catch {
            Alerts.error(error.localizedDescription)
            return nil
        }
    }

    /// Byte variant of `open(text:…)`.
    @discardableResult
    static func open(bytes doc: CTDocument, method: String, title: String, key: String,
                     viewMode: DocumentViewMode? = nil, _ transform: () throws -> [UInt8]) -> CTDocument? {
        do {
            let result = try transform()
            KeyMemory.remember(key, for: method)
            return DocumentFactory.openResult(result, title: title, parent: doc, method: method, key: key,
                                              viewMode: viewMode ?? (TextCoding.looksLikeText(result) ? .text : .hex))
        } catch {
            Alerts.error(error.localizedDescription)
            return nil
        }
    }

    /// Runs a byte transformation and opens the result window.
    static func bytes(_ doc: CTDocument, method: String, name: String, encrypt: Bool, key: String,
                      viewMode: DocumentViewMode? = nil, _ transform: () throws -> [UInt8]) -> Bool {
        do {
            let result = try transform()
            KeyMemory.remember(key, for: method)
            let op = "\(name) \(encrypt ? "encryption" : "decryption")"
            DocumentFactory.openResult(result, title: DocumentFactory.title(op, of: doc, key: key),
                                       parent: doc, method: method, key: key,
                                       viewMode: viewMode ?? (TextCoding.looksLikeText(result) ? .text : .hex))
            return true
        } catch {
            Alerts.error(error.localizedDescription)
            return false
        }
    }
}

/// "Hilfe / Textoptionen / Abbrechen / Entschlüsseln / Verschlüsseln" button row (CT1 order is
/// Verschlüsseln · Entschlüsseln · Textoptionen · Abbrechen; macOS order is used here).
struct CipherButtons: View {
    var cancel: () -> Void
    var decrypt: (() -> Void)?
    var encrypt: (() -> Void)?
    var encryptTitle = "Encrypt"
    var decryptTitle = "Decrypt"
    var disabled = false
    /// CT1 "Textoptionen" button (opens Optionen ▸ Textoptionen).
    var textOptions = false
    /// Menu command whose help page the "Hilfe" button opens (CT1: F1 in the dialog).
    var help: CTAction? = nil

    var body: some View {
        if let help {
            Button("Help") { HelpCenter.show(action: help) }
        }
        if textOptions {
            Button("Text Options...") { OptionsWindows.showTextOptions() }
        }
        Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
        if let decrypt {
            Button(decryptTitle, action: decrypt).disabled(disabled)
        }
        if let encrypt {
            Button(encryptTitle, action: encrypt).keyboardShortcut(.defaultAction).disabled(disabled)
        }
    }
}

/// Small note showing the active text options (alphabet) – CT1 shows this in key dialogs.
struct AlphabetNote: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        let o = settings.textOptions
        Text("Alphabet (\(o.alphabetSize) characters): \(o.alphabet)" + (o.keepNonAlphabet ? "" : " – other characters are removed"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .truncationMode(.middle)
    }
}

/// Key input that can be entered as text or hex digits.
struct ByteKeyField: View {
    @Binding var key: String
    @Binding var isHex: Bool
    var body: some View {
        HStack {
            Picker("", selection: $isHex) {
                Text("Text").tag(false)
                Text("Hex").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .labelsHidden()
            TextField(isHex ? "e.g. 4B 45 59" : "Key", text: $key)
                .font(.system(.body, design: .monospaced))
        }
    }

    static func bytes(key: String, isHex: Bool) throws -> [UInt8] {
        if isHex {
            guard let b = Hex.decode(key), !b.isEmpty else { throw CTError("Invalid hex key.") }
            return b
        }
        let b = TextCoding.bytes(from: key)
        if b.isEmpty { throw CTError("Please enter a key.") }
        return b
    }
}

/// Grid display of a character matrix (Playfair, ADFGVX …).
struct CharMatrixView: View {
    let matrix: [[Character]]
    var rowLabels: [String]? = nil
    var columnLabels: [String]? = nil

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            if let columnLabels {
                GridRow {
                    if rowLabels != nil { Text("") }
                    ForEach(columnLabels.indices, id: \.self) { i in
                        Text(columnLabels[i]).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(matrix.indices, id: \.self) { r in
                GridRow {
                    if let rowLabels { Text(rowLabels[r]).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(.secondary) }
                    ForEach(matrix[r].indices, id: \.self) { c in
                        Text(String(matrix[r][c]))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 24, height: 22)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                    }
                }
            }
        }
    }
}

/// Picker listing all open documents (for Vernam key, known plaintext …).
struct DocumentPicker: View {
    let title: String
    @Binding var selection: ObjectIdentifier?
    var exclude: CTDocument? = nil

    var documents: [CTDocument] {
        NSDocumentController.shared.documents.compactMap { $0 as? CTDocument }.filter { $0 !== exclude }
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text("– please select –").tag(ObjectIdentifier?.none)
            ForEach(documents, id: \.self) { d in
                Text(d.displayName ?? "?").tag(Optional(ObjectIdentifier(d)))
            }
        }
    }

    static func document(for id: ObjectIdentifier?) -> CTDocument? {
        guard let id else { return nil }
        return NSDocumentController.shared.documents.compactMap { $0 as? CTDocument }.first { ObjectIdentifier($0) == id }
    }
}

extension CTDocument: Identifiable {}
