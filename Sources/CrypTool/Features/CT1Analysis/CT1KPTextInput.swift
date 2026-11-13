import AppKit
import SwiftUI
import CTCommon

// Tabbed plaintext/ciphertext input of CT1's known-plaintext dialogs (IDD_HILL_ANALYSIS,
// IDD_AUTOMATED_PERM_ANALYSIS): tab control "Klartext"/"Geheimtext" with an editor per tab and the
// combo box "[Bitte wählen Sie ein Dokument.]" / open windows / "[Aus Datei laden...]".

@MainActor
final class CT1KPWindowHolder {
    weak var window: NSWindow?
}

/// Texts of both tabs plus the combo selection per tab (CT1 m_sel_tab1/m_sel_tab2).
@MainActor
final class CT1KPTextPair: ObservableObject {
    /// 0 = Klartext, 1 = Geheimtext.
    @Published var tab = 1
    @Published var texts = ["", ""]
    @Published var selection = ["none", "none"]
    /// Raw bytes of a loaded window/file (binary mode) as long as the tab text is unchanged.
    private var loaded: [(text: String, bytes: [UInt8])?] = [nil, nil]
    /// The document the dialog was started for (CT1 "(Aktiv) ").
    weak var active: CTDocument?

    /// CT1 OnInitDialog: the ciphertext tab shows the active document; the plaintext is taken from
    /// the document this one was derived from (if any).
    init(active: CTDocument) {
        self.active = active
        load(active, tab: 1)
        if let p = active.origin?.parent { load(p, tab: 0) }
        tab = 1
    }

    var plain: String { texts[0] }
    var cipher: String { texts[1] }

    /// Bytes of a tab for the binary mode (original bytes of a loaded document/file if not edited).
    func bytes(_ i: Int) -> [UInt8] {
        if let l = loaded[i], l.text == texts[i] { return l.bytes }
        return TextCoding.bytes(from: texts[i])
    }

    static func tag(_ d: CTDocument) -> String { "doc:\(ObjectIdentifier(d).hashValue)" }

    var documents: [CTDocument] {
        NSDocumentController.shared.documents.compactMap { $0 as? CTDocument }
    }

    func load(_ d: CTDocument, tab i: Int) {
        let b = d.bytes
        texts[i] = d.text
        loaded[i] = (texts[i], b)
        selection[i] = CT1KPTextPair.tag(d)
    }

    /// CT1 OnCbnSelendokFileSelect.
    func select(_ tag: String) {
        let i = tab
        selection[i] = tag
        switch tag {
        case "none":
            texts[i] = ""; loaded[i] = nil
        case "file":
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                let b = [UInt8](try Data(contentsOf: url))
                texts[i] = TextCoding.string(from: b)
                loaded[i] = (texts[i], b)
            } catch {
                Alerts.error(error.localizedDescription)
            }
        default:
            if let d = documents.first(where: { CT1KPTextPair.tag($0) == tag }) { load(d, tab: i) }
        }
    }
}

/// Tab control with editor and document combo (CT1 IDC_TAB1 + Scintilla + IDC_FILE_SELECT).
struct CT1KPTextInputView: View {
    @ObservedObject var model: CT1KPTextPair
    var editorHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: $model.tab) {
                Text("Plaintext").tag(0)
                Text("Ciphertext").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            CodeEditor(text: Binding(get: { model.texts[model.tab] }, set: { model.texts[model.tab] = $0 }),
                       minHeight: editorHeight)
                .id(model.tab)
            Picker("", selection: Binding(get: { model.selection[model.tab] }, set: { model.select($0) })) {
                Text("[Please select a document.]").tag("none")
                ForEach(model.documents, id: \.self) { d in
                    Text((d === model.active ? "(Active) " : "") + (d.displayName ?? d.shortName)).tag(CT1KPTextPair.tag(d))
                }
                Text("[Open document ...]").tag("file")
            }
            .labelsHidden()
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor)))
    }
}

/// C atoi: leading decimal digits (after blanks), otherwise 0.
func ct1KPAtoi(_ s: String) -> Int {
    let t = s.drop { $0 == " " || $0 == "\t" }
    var sign = 1
    var rest = Substring(t)
    if let f = rest.first, f == "-" || f == "+" { sign = f == "-" ? -1 : 1; rest = rest.dropFirst() }
    let digits = rest.prefix { $0.isASCII && $0.isNumber }
    return (Int(digits.prefix(9)) ?? 0) * sign
}
