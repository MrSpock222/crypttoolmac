import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Hill-Analyse (Known Plaintext)" (IDD_HILL_ANALYSIS, DlgHillAnalysis.cpp, HillAnalysis.cpp) and the
// key display "Anzeige Hill-Schlüsselmatrix" (IDD_SHOW_KEY_HILL5x5 / 10x10, DlgShowKeyHill*.cpp).

extension CT1Analysis {
    /// Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Known-Plaintext ▸ Hill.
    static func openHillAnalysis(document: CTDocument) {
        let holder = CT1KPWindowHolder()
        let model = CT1KPTextPair(active: document)
        holder.window = WindowPresenter.tool(id: "ct1-kp-hill-\(ObjectIdentifier(document).hashValue)",
                                             title: "Hill-Analyse (Known Plaintext)",
                                             size: CGSize(width: 640, height: 700)) {
            CT1KPHillAnalysisView(model: model, holder: holder)
        }
    }
}

struct CT1KPHillAnalysisView: View {
    @ObservedObject var model: CT1KPTextPair
    let holder: CT1KPWindowHolder
    @EnvironmentObject var settings: AppSettings
    // CT1 registry "HillAnalysis": try_mult_dir_vec_matr / try_mult_dir_matr_vec (the dimensions are
    // always reset to 1…10 when the dialog opens).
    @AppStorage("ct1.hillAnalysis.vm") private var checkVM = true
    @AppStorage("ct1.hillAnalysis.mv") private var checkMV = true
    @CTState private var dimFrom = 1
    @CTState private var dimTo = 10
    @CTState private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dies ist eine Known-Plaintext-Analyse einer Hill-Chiffre. Mit dieser Analyse können Sie aus dem Klartext und dem Geheimtext den Hill-Schlüssel berechnen.")
                .fixedSize(horizontal: false, vertical: true)
            CT1KPTextInputView(model: model)
            GroupBox("Welche Varianten der Hill-Verschlüsselung sollen analysiert werden") {
                GroupBox("Multiplikationsart") {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("(Vektorreihe) x (Matrix)", isOn: $checkVM)
                            .onChange(of: checkVM) { _, v in if !v && !checkMV { checkMV = true } }
                        Toggle("(Matrix) x (Vektorspalte)", isOn: $checkMV)
                            .onChange(of: checkMV) { _, v in if !v && !checkVM { checkVM = true } }
                    }
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                .padding(4)
            }
            GroupBox("Optionen") {
                HStack(spacing: 8) {
                    Text("Durchsuchen der Dimensionen von")
                    Picker("", selection: $dimFrom) { ForEach(1...10, id: \.self) { Text("\($0)").tag($0) } }
                        .labelsHidden().fixedSize()
                        .onChange(of: dimFrom) { _, v in if v > dimTo { dimTo = v } }
                    Text("bis")
                    Picker("", selection: $dimTo) { ForEach(1...10, id: \.self) { Text("\($0)").tag($0) } }
                        .labelsHidden().fixedSize()
                        .onChange(of: dimTo) { _, v in if v < dimFrom { dimFrom = v } }
                    Spacer()
                }
                .padding(4)
            }
            HStack {
                Button("Schlüssel suchen", action: search).keyboardShortcut(.defaultAction).disabled(busy)
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Textoptionen...") { OptionsWindows.showTextOptions() }
                Spacer()
                Button("Schließen") { holder.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 560)
    }

    /// CDlgHillAnaylsis::OnBnClickedSearchKey.
    private func search() {
        let p = model.plain, c = model.cipher
        guard !p.isEmpty else { Alerts.error("Klartext: Datei ist leer!\nBitte wählen Sie eine nicht leere Datei aus."); return }
        guard !c.isEmpty else { Alerts.error("Geheimtext: Datei ist leer!\nBitte wählen Sie eine nicht leere Datei aus."); return }
        let o = settings.textOptions
        let d = UserDefaults.standard
        // CT1 registry "Hill" (Weitere Hill-Optionen): OrdChrOffset, PaddingDefaultChr / PaddingOwnChr.
        let offsetOne = d.bool(forKey: "ct1.hill.offset")
        let ownPad = (d.object(forKey: "ct1.hill.paddingDefault") as? Bool ?? true) ? nil
            : d.string(forKey: "ct1.hill.paddingChar")?.first.flatMap { o.alphabetCharacters.contains($0) ? $0 : nil }
        // Both variants describe the same key (transposed). With both boxes checked the
        // "(Matrix) x (Vektorspalte)" form is shown – the matrix CT1 displays in this case.
        let mult: HillMultiplication = checkMV ? .matrixTimesVector : .vectorTimesMatrix
        let dims = dimFrom...max(dimFrom, dimTo)
        busy = true
        Task.detached {
            let outcome = CT1HillKnownPlaintext.search(plaintext: p, ciphertext: c, dimensions: dims, multiplication: mult,
                                                       options: o, firstLetterIsOne: offsetOne, paddingCharacter: ownPad)
            await MainActor.run {
                busy = false
                switch outcome {
                case .notFound(let failures):
                    Alerts.error(CT1HillKnownPlaintext.notFoundMessage(failures))
                case .found(let r):
                    if r.lengthMismatch { Alerts.info("Die Dokumente haben nicht die gleiche Länge !") }
                    let alphabet = o.alphabetCharacters
                    WindowPresenter.sheet(on: holder.window, title: "Anzeige Hill-Schlüsselmatrix") { close in
                        CT1KPHillKeyView(matrix: r.matrix, multiplication: r.multiplication, alphabet: alphabet,
                                         offsetOne: offsetOne, close: close)
                    }
                }
            }
        }
    }
}

/// "Anzeige Hill-Schlüsselmatrix" (IDD_SHOW_KEY_HILL5x5 / IDD_SHOW_KEY_HILL10x10).
struct CT1KPHillKeyView: View {
    /// Key in Hill numbers for the analysis offset.
    let matrix: [[Int]]
    let multiplication: HillMultiplication
    let alphabet: [Character]
    let close: () -> Void
    @CTState private var offsetOne: Bool
    @CTState private var inverse = false
    /// The letters stay fixed when the offset radio is switched (CKeyHillBase::syncNumAlph).
    private let letters: [[Character]]

    init(matrix: [[Int]], multiplication: HillMultiplication, alphabet: [Character], offsetOne: Bool, close: @escaping () -> Void) {
        self.matrix = matrix
        self.multiplication = multiplication
        self.alphabet = alphabet
        self.close = close
        _offsetOne = CTState(initialValue: offsetOne)
        letters = matrix.map { $0.map { CT1HillKnownPlaintext.letter($0, alphabet: alphabet, firstLetterIsOne: offsetOne) } }
    }

    private var n: Int { alphabet.count }

    /// Numbers of the (fixed) letters for the selected offset.
    private var numbers: [[Int]] {
        letters.map { $0.map { ch in ((alphabet.firstIndex(of: ch) ?? 0) + (offsetOne ? 1 : 0)) % n } }
    }

    private var shown: [[Int]]? { inverse ? HillCipher.inverse(of: numbers, modulus: n) : numbers }

    private func cell(_ s: String, width: CGFloat) -> some View {
        Text(s)
            .font(.system(.body, design: .monospaced))
            .frame(width: width, height: 20)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(nsColor: .separatorColor)))
    }

    private func grid(_ m: [[Int]], letters: Bool) -> some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(m.indices, id: \.self) { r in
                GridRow {
                    ForEach(m[r].indices, id: \.self) { c in
                        let v = m[r][c]
                        if letters {
                            cell(String(CT1HillKnownPlaintext.letter(v, alphabet: alphabet, firstLetterIsOne: offsetOne)), width: 22)
                        } else {
                            cell(String(format: "%02d", offsetOne && v == 0 ? n : v), width: n > 99 ? 36 : 28)
                        }
                    }
                }
            }
        }
        .padding(4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CT1Group(title: "Benutztes Alphabet (\(n) Zeichen)") {
                CT1ReadOnlyLine(text: String(alphabet))
            }
            CT1Group(title: "Hill-Schlüsselmatrix") {
                if let m = shown {
                    HStack(alignment: .top, spacing: 12) {
                        GroupBox("Alphabetzeichen") { grid(m, letters: true).frame(maxWidth: .infinity) }
                        GroupBox("Zahlenwerte") { grid(m, letters: false).frame(maxWidth: .infinity) }
                    }
                } else {
                    Text("Die Matrix ist nicht invertierbar.").foregroundStyle(.red)
                }
                CT1Radio(title: "Hill-Schlüsselmatrix (Verschlüsseln)", selected: !inverse) { inverse = false }
                CT1Radio(title: "Inverse Hill-Schlüsselmatrix (Entschlüsseln)", selected: inverse) { inverse = true }
            }
            HStack(alignment: .top, spacing: 12) {
                CT1Group(title: "Multiplikationsart") {
                    CT1Radio(title: "(Vektorreihe) * (Matrix)", selected: multiplication == .vectorTimesMatrix) {}
                    CT1Radio(title: "(Matrix) * (Vektorspalte)", selected: multiplication == .matrixTimesVector) {}
                }
                .disabled(true)
                CT1Group(title: "Wert des ersten Alphabetzeichens") {
                    CT1Radio(title: "0 (z.B. \"A\"=0)", selected: !offsetOne) { offsetOne = false }
                    CT1Radio(title: "1 (z.B. \"A\"=1)", selected: offsetOne) { offsetOne = true }
                }
            }
            HStack {
                // CKeyHillBase::copyKey: the matrix currently shown, with the selected offset.
                Button("Schlüssel kopieren") {
                    guard let m = shown else { return }
                    CT1KeyStore.shared.copy(CT1HillKnownPlaintext.keyString(matrix: m, alphabet: alphabet, firstLetterIsOne: offsetOne,
                                                                            multiplication: multiplication), method: "hill")
                }
                .disabled(shown == nil)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 460)
    }
}
