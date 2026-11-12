import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Analyse einer einstufigen Spaltentransposition (Known Plaintext)" (IDD_AUTOMATED_PERM_ANALYSIS,
// DlgAutomatedPermAnalysis.cpp, automated_permanalysis.cpp), the key output
// "Schlüsselausgabe: Permutation / Transposition" (IDD_AUTOMATED_PERM_ANALYSIS_OUTPUT, DlgPermKey.cpp)
// and the key list (IDD_KEYS_LIST, DlgKeyList.cpp).

extension CT1Analysis {
    /// Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Known-Plaintext ▸ Einstufige Spaltentransposition.
    static func openTranspositionAnalysis(document: CTDocument) {
        let holder = CT1KPWindowHolder()
        let model = CT1KPTextPair(active: document)
        holder.window = WindowPresenter.tool(id: "ct1-kp-perm-\(ObjectIdentifier(document).hashValue)",
                                             title: "Analyse einer einstufigen Spaltentransposition (Known Plaintext)",
                                             size: CGSize(width: 660, height: 720)) {
            CT1KPTranspositionAnalysisView(model: model, holder: holder)
        }
    }
}

/// Method identifier of the permutation key in `CT1KeyStore` (CT1 IDS_CRYPT_PERMUTATION).
let ct1KPPermutationKeyMethod = "permutation"

struct CT1KPTranspositionAnalysisView: View {
    typealias KP = CT1PermutationKnownPlaintext
    @ObservedObject var model: CT1KPTextPair
    let holder: CT1KPWindowHolder
    @EnvironmentObject var settings: AppSettings
    // CT1 registry "PermutationAnalysis" (the data type is always reset to "Binäre Daten").
    @AppStorage("ct1.permAnalysis.inRow") private var inRow = true
    @AppStorage("ct1.permAnalysis.inCol") private var inCol = true
    @AppStorage("ct1.permAnalysis.permRow") private var permRow = true
    @AppStorage("ct1.permAnalysis.permCol") private var permCol = true
    @AppStorage("ct1.permAnalysis.outRow") private var outRow = true
    @AppStorage("ct1.permAnalysis.outCol") private var outCol = true
    @AppStorage("ct1.permAnalysis.from") private var rangeFrom = "1"
    @AppStorage("ct1.permAnalysis.to") private var rangeTo = "100"
    @CTState private var textMode = false
    @CTState private var progress: Double?
    @CTState private var token: CancellationToken?

    /// CDlgAutomatedPermAnalysis::check_dir – one checkbox of a pair always stays checked.
    private func pair(_ title: String, _ row: Binding<Bool>, _ col: Binding<Bool>) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("zeilenweise", isOn: row).onChange(of: row.wrappedValue) { _, _ in if !row.wrappedValue && !col.wrappedValue { col.wrappedValue = true } }
                Toggle("spaltenweise", isOn: col).onChange(of: col.wrappedValue) { _, _ in if !row.wrappedValue && !col.wrappedValue { row.wrappedValue = true } }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dies ist eine Known-Plaintext-Analyse einer Permutations-Chiffre. Mit dieser Analyse können Sie aus dem Klartext und dem Geheimtext den Permutationsschlüssel berechnen.")
                .fixedSize(horizontal: false, vertical: true)
            CT1KPTextInputView(model: model)
            GroupBox("Welche Varianten des Permutationsverfahrens sollen analysiert werden?") {
                HStack(alignment: .top, spacing: 8) {
                    pair("Einlesen", $inRow, $inCol)
                    pair("Permutieren", $permRow, $permCol)
                    pair("Auslesen", $outRow, $outCol)
                    GroupBox("Permutationsgröße") {
                        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                            GridRow { Text("von"); TextField("", text: $rangeFrom).frame(width: 56) }
                            GridRow { Text("bis"); TextField("", text: $rangeTo).frame(width: 56) }
                        }
                        .padding(2)
                    }
                }
                .padding(4)
            }
            GroupBox("Optionen") {
                HStack(spacing: 14) {
                    Text("Betrachte beide Eingabedokumente als:")
                    CT1Radio(title: "Binäre Daten", selected: !textMode) { textMode = false }
                    CT1Radio(title: "Text", selected: textMode) { textMode = true }
                    Spacer()
                }
                .padding(4)
            }
            HStack {
                if let progress {
                    ProgressView(value: progress).frame(width: 120)
                    Button("Abbrechen") { token?.cancel() }
                } else {
                    Button("Schlüssel suchen", action: search).keyboardShortcut(.defaultAction)
                }
                Spacer()
                Button("Textoptionen...") { OptionsWindows.showTextOptions() }.disabled(!textMode)
                Spacer()
                Button("Schließen") { token?.cancel(); holder.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 600)
    }

    /// CDlgAutomatedPermAnalysis::OnBnClickedCompute.
    private func search() {
        let o = settings.textOptions
        let plain: [Int], cipher: [Int]
        if textMode {
            plain = KP.textElements(model.plain, options: o)
            cipher = KP.textElements(model.cipher, options: o)
        } else {
            plain = model.bytes(0).map(Int.init)
            cipher = model.bytes(1).map(Int.init)
        }
        if let e = KP.check(plain: plain, cipher: cipher) { Alerts.error(e.message); return }
        let (lo, hi) = KP.effectiveRange(from: ct1KPAtoi(rangeFrom), to: ct1KPAtoi(rangeTo), size: plain.count)
        rangeFrom = String(lo)
        rangeTo = String(hi)
        guard lo <= hi, hi > 0 else { Alerts.error(KP.InputError.range.message); return }
        func dirs(_ r: Bool, _ c: Bool) -> Set<KP.Direction> {
            var s: Set<KP.Direction> = []
            if r { s.insert(.rowWise) }
            if c || !r { s.insert(.columnWise) }
            return s
        }
        let (dIn, dPerm, dOut) = (dirs(inRow, inCol), dirs(permRow, permCol), dirs(outRow, outCol))
        let t = CancellationToken()
        token = t
        progress = 0
        let text = textMode
        Task.detached {
            let keys = KP.search(plain: plain, cipher: cipher, sizes: lo...hi, readIn: dIn, permute: dPerm, readOut: dOut,
                                 cancel: t, progress: { v in Task { @MainActor in if progress != nil { progress = v } } })
            await MainActor.run {
                progress = nil
                token = nil
                guard let keys else { return }
                if keys.isEmpty {
                    Alerts.info("Es wurde kein Permutationsschlüssel gefunden.")
                } else if keys.count == 1 {
                    WindowPresenter.sheet(on: holder.window, title: "Schlüsselausgabe: Permutation / Transposition") { close in
                        CT1KPPermKeyView(key: keys[0], textMode: text, close: close)
                    }
                } else {
                    WindowPresenter.sheet(on: holder.window, title: "Liste der gefundenen Permutationsschlüssel") { close in
                        CT1KPKeyListView(keys: keys, textMode: text, close: close)
                    }
                }
            }
        }
    }
}

private typealias K = CT1PermutationKnownPlaintext.Key

/// Bordered read-only field (CT1 LTEXT with WS_BORDER).
private struct CT1KPField: View {
    let text: String
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor)))
    }
}

/// "Schlüsselausgabe: Permutation / Transposition" (IDD_AUTOMATED_PERM_ANALYSIS_OUTPUT).
struct CT1KPPermKeyView: View {
    let key: CT1PermutationKnownPlaintext.Key
    let textMode: Bool
    let close: () -> Void

    private func stage(_ title: String, key: String, _ dirs: [String], enabled: Bool) -> some View {
        CT1Group(title: title) {
            Text("Schlüssel")
            CT1KPField(text: key)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow { Text("Einlesen:"); CT1KPField(text: dirs[0]).frame(width: 170) }
                GridRow { Text("Permutieren:"); CT1KPField(text: dirs[1]).frame(width: 170) }
                GridRow { Text("Auslesen:"); CT1KPField(text: dirs[2]).frame(width: 170) }
            }
        }
        .disabled(!enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stage("1. Permutation (einfache Spaltentransposition)", key: key.display,
                  [K.name(key.readIn), K.name(key.permute), K.name(key.readOut)], enabled: true)
            stage("2. Permutation (doppelte Spaltentransposition)", key: "", ["", "", ""], enabled: false)
            HStack {
                // CDlgPermKey::OnBnClickedCopyKey
                Button("Schlüssel kopieren") {
                    CT1KeyStore.shared.copy(key.keyString(textMode: textMode), method: ct1KPPermutationKeyMethod)
                }
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 400)
    }
}

/// "Liste der gefundenen Permutationsschlüssel" (IDD_KEYS_LIST).
struct CT1KPKeyListView: View {
    let keys: [CT1PermutationKnownPlaintext.Key]
    let textMode: Bool
    let close: () -> Void
    @CTState private var selection: Int? = 0

    private struct Row: Identifiable {
        let id: Int
        let key: CT1PermutationKnownPlaintext.Key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Es wurde mindestens ein Permutationsschlüssel gefunden. Die Schlüssel werden in der Liste angezeigt. Sie können eine Zeile auswählen und den damit ausgewählten Schlüssel in den Schlüsselspeicher kopieren.")
                .fixedSize(horizontal: false, vertical: true)
            Table(keys.enumerated().map { Row(id: $0.offset, key: $0.element) }, selection: $selection) {
                TableColumn("Schlüssel") { Text($0.key.display).textSelection(.enabled) }.width(min: 180, ideal: 260)
                TableColumn("Einlesen") { Text(K.name($0.key.readIn)) }.width(min: 80, ideal: 100)
                TableColumn("Permutation") { Text(K.name($0.key.permute)) }.width(min: 80, ideal: 100)
                TableColumn("Auslesen") { Text(K.name($0.key.readOut)) }.width(min: 80, ideal: 100)
            }
            .frame(minHeight: 220)
            HStack {
                Spacer()
                // CDlgKeyList::OnBnClickedButtonCopyKey
                Button("Schlüssel kopieren") {
                    guard let i = selection, keys.indices.contains(i) else {
                        Alerts.info("Bitte wählen Sie einen Schlüssel aus der Liste.")
                        return
                    }
                    CT1KeyStore.shared.copy(keys[i].keyString(textMode: textMode), method: ct1KPPermutationKeyMethod)
                    Alerts.info("Der von Ihnen gewählte Schlüssel wurde in den Schlüsselspeicher geladen.\nSie können diesen Schlüssel bei der Permutationsverschlüsselung nutzen (siehe Menü: Ver-/Entschlüsseln \\ Symmetrisch (klassisch) \\ Permutation / Transposition).\n\nUm den gespeicherten Schlüssel für die Permutations-Verschlüsselung zu benutzen, klicken Sie dann unten im Schlüsseleingabe-Dialog auf die Ikone zum Schlüsseleinfügen.")
                    close()
                }
                Button("Schließen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 360)
    }
}
