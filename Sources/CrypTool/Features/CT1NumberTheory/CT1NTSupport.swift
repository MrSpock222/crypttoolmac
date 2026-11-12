import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CTCommon
import CTBigNum

// Shared helpers for the CT1-aligned number-theory dialogs (Einzelverfahren ▸ Zahlentheorie,
// Protokolle, CRT, Secret-Sharing).

/// Holds the NSWindow hosting a SwiftUI dialog, so sub-dialogs can be shown as sheets on it.
@MainActor
final class CT1WindowRef: ObservableObject {
    weak var window: NSWindow?

    /// Shows `content` as a modal sheet on the hosting window (CT1 modal sub-dialog).
    func sheet<V: View>(_ title: String, @ViewBuilder content: @escaping (@escaping () -> Void) -> V) {
        WindowPresenter.sheet(on: window, title: title) { close in content(close) }
    }
}

/// Reads the hosting window and (optionally) sets its title to the CT1 caption.
struct CT1WindowAccessor: NSViewRepresentable {
    var ref: CT1WindowRef?
    var title: String?

    final class Coordinator { var fitted = false }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        let c = context.coordinator
        DispatchQueue.main.async { apply(v, c) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let c = context.coordinator
        DispatchQueue.main.async { apply(nsView, c) }
    }

    @MainActor private func apply(_ v: NSView, _ c: Coordinator) {
        guard let w = v.window else { return }
        ref?.window = w
        if let title, w.title != title { w.title = title }
        // enlarge a tool window once so that the whole CT1 dialog layout is visible
        if !c.fitted, w.sheetParent == nil, let content = w.contentView {
            c.fitted = true
            let fit = content.fittingSize
            let cur = content.frame.size
            if fit.width > cur.width + 1 || fit.height > cur.height + 1 {
                w.setContentSize(CGSize(width: max(cur.width, fit.width), height: max(cur.height, fit.height)))
            }
        }
    }
}

extension View {
    /// Sets the CT1 window caption of the hosting tool window and records the window in `ref`.
    func ct1Window(title: String? = nil, ref: CT1WindowRef? = nil) -> some View {
        background(CT1WindowAccessor(ref: ref, title: title).frame(width: 0, height: 0))
    }
}

/// Persistent dialog settings (CT1 stores them in the registry).
enum CT1Prefs {
    private static let d = UserDefaults.standard
    private static func k(_ key: String) -> String { "CT1NT." + key }

    static func bool(_ key: String, _ def: Bool) -> Bool { d.object(forKey: k(key)) as? Bool ?? def }
    static func set(_ key: String, _ v: Bool) { d.set(v, forKey: k(key)) }
    static func string(_ key: String, _ def: String) -> String { d.string(forKey: k(key)) ?? def }
    static func set(_ key: String, _ v: String) { d.set(v, forKey: k(key)) }
    static func int(_ key: String, _ def: Int) -> Int { d.object(forKey: k(key)) as? Int ?? def }
    static func set(_ key: String, _ v: Int) { d.set(v, forKey: k(key)) }
}

/// CT1 limits (IDS_STRING_BIG_NUMBER): positive integers below 2^8192 (≤ 2467 decimal digits).
enum CT1BigNumber {
    static let maxBits = 8192
    static let maxDigits = 2467
    static let message = "CrypTool unterstützt hier nur positive ganze Zahlen der Bitlänge kleiner 8192. Das sind Zahlen mit höchstens 2467 Dezimalstellen."

    static func isAllowed(_ n: BigUInt) -> Bool { n.bitLength < maxBits }

    /// "Zahl aus Datei laden": reads a file, keeps only the digits, truncates to 2467 digits.
    @MainActor
    static func loadFromFile() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Zahl aus Datei laden"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url) else {
            Alerts.error("Die Datei konnte nicht geöffnet werden!")
            return nil
        }
        var digits = String(decoding: data.filter { $0 >= 0x30 && $0 <= 0x39 }, as: UTF8.self)
        if digits.count > maxDigits {
            Alerts.info(message)
            digits = String(digits.prefix(maxDigits))
        }
        return digits
    }
}

/// Generic CT1 intro/info dialog with "Diesen Dialog … nicht mehr anzeigen" checkbox.
struct CT1IntroDialog: View {
    var heading: String? = nil
    var text: String
    var checkboxLabel = "Diesen Dialog in Zukunft nicht mehr anzeigen!"
    /// Preference key storing whether the dialog is shown; nil hides the checkbox.
    var prefKey: String?
    /// Checkbox semantics: true = checked means "show again" (CT1 CRT secret sharing).
    var checkedMeansShow = false
    var okTitle = "OK"
    var close: () -> Void
    @CTState private var checked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading { Text(heading).font(.headline) }
            ScrollView {
                Text(text).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }.frame(minHeight: 120, maxHeight: 420)
            HStack {
                if prefKey != nil { Toggle(checkboxLabel, isOn: $checked) }
                Spacer()
                Button(okTitle) {
                    if let prefKey { CT1Prefs.set(prefKey, checkedMeansShow ? checked : !checked) }
                    close()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 520)
        .onAppear {
            if let prefKey { let show = CT1Prefs.bool(prefKey, true); checked = checkedMeansShow ? show : !show }
        }
    }
}

/// Labelled read-only/monospaced text field as used in the CT1 dialogs.
struct CT1Field: View {
    let label: String
    @Binding var text: String
    var readOnly = false
    var labelWidth: CGFloat? = 160
    var secure = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: labelWidth, alignment: .leading)
            Group {
                if readOnly {
                    Text(text.isEmpty ? " " : text)
                        .lineLimit(1).truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4).padding(.vertical, 3)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                } else if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(.system(.body, design: .monospaced))
        }
    }
}

/// "Hilfe" button calling the CT1 help page of a menu command.
struct CT1HelpButton: View {
    let action: CTAction
    var body: some View { Button("Hilfe") { HelpCenter.show(action: action) } }
}

/// Formats a duration like CT1's time strings ("1 Stunde 3 Minuten 5 Sekunden" – simplified).
func ct1Duration(_ seconds: Double) -> String {
    if seconds < 1 { return String(format: "%.3f Sekunden", seconds) }
    var s = Int(seconds.rounded())
    let h = s / 3600; s %= 3600
    let m = s / 60; s %= 60
    var parts: [String] = []
    if h > 0 { parts.append("\(h) Stunde\(h == 1 ? "" : "n")") }
    if m > 0 { parts.append("\(m) Minute\(m == 1 ? "" : "n")") }
    parts.append("\(s) Sekunde\(s == 1 ? "" : "n")")
    return parts.joined(separator: " ")
}
