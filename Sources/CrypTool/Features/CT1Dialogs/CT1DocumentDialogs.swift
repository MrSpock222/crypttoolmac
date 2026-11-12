import AppKit
import SwiftUI
import CTCommon

/// "Bearbeiten ▸ Schlüssel anzeigen" (IDD_SHOW_KEY, IDD_SHOW_KEY_HILL5x5/10x10) and
/// "Datei ▸ Dokument-Eigenschaften" (IDD_FILE_PROPERTIES).
@MainActor
enum CT1DocumentDialogs {
    /// Shows the key of a result document. "Schlüssel kopieren" copies it into the CT1 key store
    /// (not the system clipboard); the paste buttons of the key dialogs insert it.
    static func showKey(_ doc: CTDocument) {
        guard let key = doc.origin?.key, !key.isEmpty else { NSSound.beep(); return }
        let name = methodName(fromTitle: doc.origin?.title ?? doc.displayName ?? "")
        let method = doc.origin?.method ?? name
        let window = CT1.window(of: doc)
        if method == "hill", let parsed = HillKey.parse(key) {
            WindowPresenter.sheet(on: window, title: "Anzeige Hill-Schlüsselmatrix") { close in
                HillKeyDisplay(key: key, parsed: parsed, close: close)
            }
            return
        }
        WindowPresenter.sheet(on: window, title: "\(name)-Schlüssel") { close in
            ShowKeyView(caption: "\(name)-Schlüssel", key: key, method: method, close: close)
        }
    }

    /// Document properties as in CT1 (temporary-file lines are omitted on macOS).
    static func showProperties(_ doc: CTDocument) {
        WindowPresenter.sheet(on: CT1.window(of: doc), title: "Dokument-Eigenschaften") { close in
            DocumentPropertiesView(document: doc, close: close)
        }
    }

    /// Method part of a CT1 window title ("Vigenère-Verschlüsselung von <…>" → "Vigenère").
    static func methodName(fromTitle title: String) -> String {
        var cut = title.endIndex
        for marker in ["-Verschlüsselung", "-Entschlüsselung", "-Analyse", " von <"] {
            if let r = title.range(of: marker), r.lowerBound < cut { cut = r.lowerBound }
        }
        return String(title[..<cut])
    }
}

struct ShowKeyView: View {
    let caption: String
    let key: String
    let method: String
    let close: () -> Void
    @CTState private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(caption).font(.title3.weight(.semibold))
            Text("Schlüssel:")
            ResultBox(text: key, minHeight: 50).frame(maxHeight: 140)
            HStack {
                Button("Schlüssel kopieren") {
                    CT1KeyStore.shared.copy(key, method: method)
                    copied = true
                }
                if copied { Text("In den Schlüsselspeicher kopiert.").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520)
    }
}

struct DocumentPropertiesView: View {
    let document: CTDocument
    let close: () -> Void

    private var size: String {
        let n = document.bytes.count
        return "\(n.formatted(.number.locale(Locale(identifier: "de_DE")))) Bytes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dokument-Eigenschaften").font(.title3.weight(.semibold))
            CT1Group(title: "Informationen zum aktuell ausgewählten Dokument") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    row("Fenster-Titel:", document.displayName ?? "")
                    row("Name der Datei", document.fileURL?.lastPathComponent ?? "")
                    row("Dokument-Typ:", document.isText ? "Text" : "Binärdaten (Hex)")
                    row("Dokument-Größe:", size)
                    if let p = document.origin?.parent { row("Erzeugt aus:", p.displayName ?? "") }
                }
            }
            CT1Group(title: "Pfad") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    row("für Dokumente:", document.fileURL?.deletingLastPathComponent().path ?? "")
                }
            }
            HStack {
                Button {
                    let doc = document
                    close()
                    DispatchQueue.main.async { CT1DocumentDialogs.showKey(doc) }
                } label: {
                    Label("KEY", systemImage: "key.fill")
                }
                .help("Schlüssel anzeigen")
                .disabled(document.origin?.key?.isEmpty ?? true)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).frame(width: 130, alignment: .trailing)
            Text(value).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
        }
    }
}
