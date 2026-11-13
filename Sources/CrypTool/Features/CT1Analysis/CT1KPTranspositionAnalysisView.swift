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
                                             title: "Analysis of a Simple Column Transposition (Known Plaintext)",
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
                Toggle("Line by line", isOn: row).onChange(of: row.wrappedValue) { _, _ in if !row.wrappedValue && !col.wrappedValue { col.wrappedValue = true } }
                Toggle("Col by col", isOn: col).onChange(of: col.wrappedValue) { _, _ in if !row.wrappedValue && !col.wrappedValue { row.wrappedValue = true } }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This is a known-plaintext analysis of a permutation cipher. Given as input a pair of plaintext and ciphertext belonging together, this analysis computes a valid permutation key.")
                .fixedSize(horizontal: false, vertical: true)
            CT1KPTextInputView(model: model)
            GroupBox("Which permutation variant should be analyzed? ") {
                HStack(alignment: .top, spacing: 8) {
                    pair("Input", $inRow, $inCol)
                    pair("Permute", $permRow, $permCol)
                    pair("Output", $outRow, $outCol)
                    GroupBox("Permutation size") {
                        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                            GridRow { Text("from"); TextField("", text: $rangeFrom).frame(width: 56) }
                            GridRow { Text("to"); TextField("", text: $rangeTo).frame(width: 56) }
                        }
                        .padding(2)
                    }
                }
                .padding(4)
            }
            GroupBox("Options") {
                HStack(spacing: 14) {
                    Text("Consider input document as")
                    CT1Radio(title: "binary data", selected: !textMode) { textMode = false }
                    CT1Radio(title: "text", selected: textMode) { textMode = true }
                    Spacer()
                }
                .padding(4)
            }
            HStack {
                if let progress {
                    ProgressView(value: progress).frame(width: 120)
                    Button("Cancel") { token?.cancel() }
                } else {
                    Button("Search key", action: search).keyboardShortcut(.defaultAction)
                }
                Spacer()
                Button("Text options...") { OptionsWindows.showTextOptions() }.disabled(!textMode)
                Spacer()
                Button("Close") { token?.cancel(); holder.window?.close() }.keyboardShortcut(.cancelAction)
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
                    Alerts.info("No single transposition key was found.")
                } else if keys.count == 1 {
                    WindowPresenter.sheet(on: holder.window, title: "Key Display: Simple Column Transposition") { close in
                        CT1KPPermKeyView(key: keys[0], textMode: text, close: close)
                    }
                } else {
                    WindowPresenter.sheet(on: holder.window, title: "List of recovered permutation keys") { close in
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
            Text("Key")
            CT1KPField(text: key)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow { Text("Input:"); CT1KPField(text: dirs[0]).frame(width: 170) }
                GridRow { Text("Permute:"); CT1KPField(text: dirs[1]).frame(width: 170) }
                GridRow { Text("Output:"); CT1KPField(text: dirs[2]).frame(width: 170) }
            }
        }
        .disabled(!enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stage("1st Permutation (simple column transposition)", key: key.display,
                  [K.name(key.readIn), K.name(key.permute), K.name(key.readOut)], enabled: true)
            stage("2nd Permutation (double column transposition)", key: "", ["", "", ""], enabled: false)
            HStack {
                // CDlgPermKey::OnBnClickedCopyKey
                Button("Copy key") {
                    CT1KeyStore.shared.copy(key.keyString(textMode: textMode), method: ct1KPPermutationKeyMethod)
                }
                Spacer()
                Button("Close", action: close).keyboardShortcut(.defaultAction)
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
            Text("At least one permutation key was found. These keys are now displayed in the list below.\nYou may copy your actual selection key into the key storage.")
                .fixedSize(horizontal: false, vertical: true)
            Table(keys.enumerated().map { Row(id: $0.offset, key: $0.element) }, selection: $selection) {
                TableColumn("Key") { Text($0.key.display).textSelection(.enabled) }.width(min: 180, ideal: 260)
                TableColumn("Input") { Text(K.name($0.key.readIn)) }.width(min: 80, ideal: 100)
                TableColumn("Permutation") { Text(K.name($0.key.permute)) }.width(min: 80, ideal: 100)
                TableColumn("Output") { Text(K.name($0.key.readOut)) }.width(min: 80, ideal: 100)
            }
            .frame(minHeight: 220)
            HStack {
                Spacer()
                // CDlgKeyList::OnBnClickedButtonCopyKey
                Button("Copy key") {
                    guard let i = selection, keys.indices.contains(i) else {
                        Alerts.info("Please select a key from the list")
                        return
                    }
                    CT1KeyStore.shared.copy(keys[i].keyString(textMode: textMode), method: ct1KPPermutationKeyMethod)
                    Alerts.info("The selected key has been copied to the key storage. You may use this permutation key for document encryption or ciphertext decryption (See menu: Encrypt/Decrypt \\ Symmetric (classic) \\ Permutation / Transposition).\n\nUsing the Permutation encryption dialog you may click on the key symbol to paste the stored key.")
                    close()
                }
                Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 360)
    }
}
