import AppKit
import SwiftUI
import Charts
import CTCommon
import CTAnalysis
import CTClassic

@MainActor
func currentLanguageModel() -> LanguageModel {
    let s = AppSettings.shared
    let ref = s.referenceText
    if ref.isEmpty {
        return s.referenceLanguage == .german ? LanguageModel.defaultGerman(options: s.textOptions) : LanguageModel.defaultEnglish(options: s.textOptions)
    }
    return LanguageModel.from(referenceText: ref, options: s.textOptions)
}

// MARK: - Caesar

struct CaesarAnalysisSheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var shift = 0
    @CTState private var scores: [Double] = []

    var body: some View {
        let chars = settings.textOptions.alphabetCharacters
        DialogScaffold(title: "Caesar Analysis (Ciphertext-Only)",
                       subtitle: "For each possible shift the letter distribution of the decrypted text is compared with the reference language (\(settings.referenceLanguage.displayName)) (χ² distance, smaller = better).",
                       minWidth: 600) {
            if !scores.isEmpty {
                Chart {
                    ForEach(scores.indices, id: \.self) { i in
                        BarMark(x: .value("Key", String(chars[i % max(chars.count, 1)])), y: .value("Distance", scores[i]))
                            .foregroundStyle(i == shift ? Color.green : Color.blue.opacity(0.6))
                    }
                }.frame(height: 180)
            }
            Stepper("Key: \(chars.isEmpty ? "?" : String(chars[shift % chars.count])) (shift \(shift))", value: $shift, in: 0...max(0, chars.count - 1))
            Text("Preview: " + String(Caesar.decrypt(String(document.text.prefix(300)), shift: shift, options: settings.textOptions).prefix(200)))
                .font(.system(.callout, design: .monospaced)).lineLimit(3)
        } buttons: {
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Decrypt") {
                let key = chars.isEmpty ? "\(shift)" : String(chars[shift])
                if CipherRun.text(document, method: "caesar", name: "Caesar", encrypt: false, key: key, {
                    Caesar.decrypt(document.text, shift: shift, options: settings.textOptions)
                }) { close() }
            }.keyboardShortcut(.defaultAction)
        }
        .onAppear {
            let r = CaesarAnalysis.analyze(document.text, options: settings.textOptions, model: currentLanguageModel())
            shift = r.shift; scores = r.scores
        }
    }
}

// MARK: - Vigenère

struct VigenereAnalysisSheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var lengthScores: [(length: Int, score: Double)] = []
    @CTState private var friedman = 0.0
    @CTState private var keyLength = 1
    @CTState private var key = ""

    var body: some View {
        DialogScaffold(title: "Vigenère Analysis (Ciphertext-Only)",
                       subtitle: "1. Determination of the key length (Friedman test, index of coincidence of the columns). 2. Caesar analysis of each column against the reference language.",
                       minWidth: 620) {
            if !lengthScores.isEmpty {
                Chart {
                    ForEach(lengthScores, id: \.length) { s in
                        BarMark(x: .value("Length", s.length), y: .value("Index of coincidence", s.score))
                            .foregroundStyle(s.length == keyLength ? Color.green : Color.blue.opacity(0.6))
                    }
                }.frame(height: 170)
                Text(String(format: "Friedman estimate of the key length: %.2f", friedman)).font(.caption).foregroundStyle(.secondary)
            }
            Stepper("Key length: \(keyLength)", value: $keyLength, in: 1...max(1, settings.vigenereMaxKeyLength))
                .onChange(of: keyLength) { _, l in deriveKey(length: l) }
            TextField("Derived key (editable)", text: $key).font(.system(.body, design: .monospaced))
            Text("Preview: " + preview).font(.system(.callout, design: .monospaced)).lineLimit(3)
        } buttons: {
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Decrypt") {
                if CipherRun.text(document, method: "vigenere", name: "Vigenère", encrypt: false, key: key, {
                    try Vigenere.decrypt(document.text, key: key, options: settings.textOptions)
                }) { close() }
            }.keyboardShortcut(.defaultAction).disabled(key.isEmpty)
        }
        .onAppear(perform: analyze)
    }

    private var preview: String {
        (try? Vigenere.decrypt(String(document.text.prefix(400)), key: key, options: settings.textOptions)).map { String($0.prefix(200)) } ?? ""
    }

    private func analyze() {
        let o = settings.textOptions
        let model = currentLanguageModel()
        lengthScores = VigenereAnalysis.keyLengthScores(document.text, options: o, maxLength: settings.vigenereMaxKeyLength)
        friedman = VigenereAnalysis.friedmanKeyLength(document.text, options: o, model: model)
        let r = VigenereAnalysis.analyze(document.text, options: o, model: model)
        keyLength = r.keyLength
        key = r.key
    }

    private func deriveKey(length: Int) {
        let r = VigenereAnalysis.analyze(document.text, options: settings.textOptions, model: currentLanguageModel(), keyLength: length)
        key = r.key
    }
}

// MARK: - XOR / byte addition

struct ByteKeyAnalysisSheet: View {
    let document: CTDocument
    let xor: Bool
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var keyHex = ""
    @CTState private var keyLength = 0
    @CTState private var autocorr: [Double] = []
    @CTState private var useReference = true

    var body: some View {
        DialogScaffold(title: xor ? "XOR / Vernam Analysis" : "Byte Addition Analysis",
                       subtitle: "The key length is determined by autocorrelation. For each column it is assumed that the most frequent byte corresponds to the most frequent plaintext character (\(String(format: "%02X", settings.expectedMostFrequentByte)), can be set in the analysis options).",
                       minWidth: 620) {
            if !autocorr.isEmpty {
                Chart {
                    ForEach(autocorr.indices, id: \.self) { i in
                        BarMark(x: .value("Offset", i + 1), y: .value("Number of characters that match", autocorr[i]))
                            .foregroundStyle(keyLength > 0 && (i + 1) % keyLength == 0 ? Color.green : Color.blue.opacity(0.6))
                    }
                }.frame(height: 160)
            }
            Picker("Determination of the key bytes", selection: $useReference) {
                Text("Maximum likelihood with reference text").tag(true)
                Text("CT1: most frequent byte ↦ most frequent plaintext character").tag(false)
            }
            .onChange(of: useReference) { _, _ in analyze() }
            Text("Derived key length: \(keyLength)")
            TextField("Key (hex, editable)", text: $keyHex).font(.system(.body, design: .monospaced))
            if let k = Hex.decode(keyHex), !k.isEmpty {
                let p = xor ? ByteCiphers.xor(Array(document.bytes.prefix(200)), key: k) : ByteCiphers.subtract(Array(document.bytes.prefix(200)), key: k)
                Text("Preview: " + BruteForceDialog.preview(p)).font(.system(.callout, design: .monospaced)).lineLimit(2)
            }
        } buttons: {
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Decrypt") {
                guard let k = Hex.decode(keyHex), !k.isEmpty else { return }
                if CipherRun.bytes(document, method: xor ? "xor" : "add", name: xor ? "XOR" : "Byte Addition", encrypt: false, key: Hex.encode(k), {
                    xor ? ByteCiphers.xor(document.bytes, key: k) : ByteCiphers.subtract(document.bytes, key: k)
                }) { close() }
            }.keyboardShortcut(.defaultAction)
        }
        .onAppear {
            autocorr = Statistics.autocorrelation(document.bytes, maxShift: min(128, max(1, document.bytes.count - 1))).map(Double.init)
            analyze()
        }
    }

    private func analyze() {
        let b = document.bytes
        let ref = TextCoding.bytes(from: settings.referenceText)
        let r: (keyLength: Int, key: [UInt8])
        if useReference && !ref.isEmpty {
            r = xor ? ByteKeyAnalysis.analyzeXOR(b, referenceBytes: ref) : ByteKeyAnalysis.analyzeAddition(b, referenceBytes: ref)
        } else {
            let expected = UInt8(truncatingIfNeeded: settings.expectedMostFrequentByte)
            r = xor ? ByteKeyAnalysis.analyzeXOR(b, expectedMostFrequent: expected)
                    : ByteKeyAnalysis.analyzeAddition(b, expectedMostFrequent: expected)
        }
        keyLength = r.keyLength
        keyHex = Hex.encode(r.key)
    }
}

// MARK: - Substitution (automatic)

@MainActor
final class SubstitutionAnalysisModel: ObservableObject {
    @Published var running = false
    @Published var progress = 0.0
    @Published var key: [Int] = []
    @Published var plaintext = ""
    private var token = CancellationToken()

    func start(text: String, options: TextOptions, model: LanguageModel, restarts: Int) {
        token = CancellationToken()
        let t = token
        running = true; progress = 0
        Task.detached(priority: .userInitiated) { [self] in
            let r = SubstitutionAnalysis.automatic(text, options: options, model: model, restarts: restarts, cancel: t) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run {
                self.key = r.key
                self.plaintext = r.plaintext
                self.running = false
            }
        }
    }

    func cancel() { token.cancel() }
}

struct SubstitutionAnalysisSheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @StateObject private var model = SubstitutionAnalysisModel()

    var body: some View {
        let chars = settings.textOptions.alphabetCharacters
        DialogScaffold(title: "Substitution Analysis (Ciphertext-Only)",
                       subtitle: "Automatic analysis by hill climbing: the key is varied until the decrypted text is as typical as possible with respect to the N-gram statistics of the reference language (\(settings.referenceLanguage.displayName)).",
                       minWidth: 640) {
            if model.running { ProgressView(value: model.progress) { Text("Analysis in progress...") } }
            if !model.key.isEmpty {
                Text("Ciphertext alphabet → plaintext alphabet").font(.caption).foregroundStyle(.secondary)
                Text(String(chars)).font(.system(.body, design: .monospaced))
                Text(String(model.key.map { $0 >= 0 && $0 < chars.count ? chars[$0] : "?" })).font(.system(.body, design: .monospaced)).foregroundStyle(.blue)
                ResultBox(text: String(model.plaintext.prefix(1500)), minHeight: 160)
            }
        } buttons: {
            Button("Close", action: { model.cancel(); close() }).keyboardShortcut(.cancelAction)
            if model.running {
                Button("Abort") { model.cancel() }
            } else {
                Button("Manual post-processing...") {
                    let key = model.key
                    close()
                    FeatureRouter.openManualSubstitution(document, initialKey: key)
                }.disabled(model.key.isEmpty)
                Button("Open as document") {
                    let keyDesc = String(model.key.map { $0 >= 0 && $0 < chars.count ? chars[$0] : "?" })
                    DocumentFactory.openResult(text: model.plaintext, title: DocumentFactory.title("Automatic substitution analysis", of: document, key: keyDesc),
                                               parent: document, method: "substitution-analysis", key: keyDesc)
                    close()
                }.keyboardShortcut(.defaultAction).disabled(model.key.isEmpty)
            }
        }
        .onAppear {
            model.start(text: document.text, options: settings.textOptions, model: currentLanguageModel(), restarts: settings.substitutionRestarts)
        }
    }
}

// MARK: - Manual substitution analysis

struct ManualSubstitutionView: View {
    let document: CTDocument
    var initialKey: [Int]? = nil
    @EnvironmentObject var settings: AppSettings
    @CTState private var mapping: [String] = []

    var body: some View {
        let chars = settings.textOptions.alphabetCharacters
        let counts = Statistics.letterCounts(document.text, options: settings.textOptions)
        let total = max(counts.map(\.count).reduce(0, +), 1)
        HSplitView {
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow { Text("Cipher").bold(); Text("Frequency").bold(); Text("→ Plain").bold() }
                    ForEach(counts.indices.sorted { counts[$0].count > counts[$1].count }, id: \.self) { i in
                        GridRow {
                            Text(String(counts[i].symbol)).font(.system(.body, design: .monospaced).bold())
                            Text(String(format: "%.1f %%", Double(counts[i].count) * 100 / Double(total))).foregroundStyle(.secondary)
                            if i < mapping.count {
                                TextField("", text: $mapping[i]).frame(width: 36).font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }.padding()
            }
            .frame(minWidth: 220, maxWidth: 260)
            VStack(alignment: .leading) {
                HStack {
                    Button("Frequency suggestion") { frequencyGuess() }
                    Button("Reset") { mapping = Array(repeating: "", count: chars.count) }
                    Spacer()
                    Button("Open as document") {
                        DocumentFactory.openResult(text: decrypted(document.text, chars: chars),
                                                   title: DocumentFactory.title("Manual substitution analysis", of: document, key: keyString(chars)), parent: document)
                    }
                }
                Text("Unassigned ciphertext characters are shown as ·. Uppercase letters = ciphertext, lowercase letters = assigned plaintext.")
                    .font(.caption).foregroundStyle(.secondary)
                ResultBox(text: decrypted(String(document.text.prefix(4000)), chars: chars), minHeight: 300)
            }
            .padding()
        }
        .onAppear {
            mapping = Array(repeating: "", count: chars.count)
            if let k = initialKey {
                for (i, p) in k.enumerated() where i < chars.count && p >= 0 && p < chars.count { mapping[i] = String(chars[p]) }
            }
        }
    }

    private func keyString(_ chars: [Character]) -> String {
        String(mapping.map { $0.first ?? "·" })
    }

    private func decrypted(_ text: String, chars: [Character]) -> String {
        let m = settings.textOptions.makeMapper()
        var out = ""
        for ch in text {
            if let (i, _) = m.lookup(ch) {
                if i < mapping.count, let p = mapping[i].first { out += String(p).lowercased() } else { out += "·" }
            } else { out.append(ch) }
        }
        return out
    }

    private func frequencyGuess() {
        let o = settings.textOptions
        let chars = o.alphabetCharacters
        let counts = Statistics.letterCounts(document.text, options: o)
        let freq = currentLanguageModel().letterFrequencies
        let cipherOrder = counts.indices.sorted { counts[$0].count > counts[$1].count }
        let plainOrder = freq.indices.sorted { freq[$0] > freq[$1] }
        mapping = Array(repeating: "", count: chars.count)
        for (c, p) in zip(cipherOrder, plainOrder) where c < chars.count && p < chars.count { mapping[c] = String(chars[p]) }
    }
}

// MARK: - Hill (known plaintext)

struct HillAnalysisSheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var plainID: ObjectIdentifier?
    @CTState private var cipherID: ObjectIdentifier?
    @CTState private var size = 2
    @CTState private var automatic = true
    @CTState private var multiplication: HillMultiplication = .matrixTimesVector
    @CTState private var result: [[Int]]?
    @CTState private var message: String?

    var body: some View {
        DialogScaffold(title: "Hill Analysis (Known Plaintext)",
                       subtitle: "The key matrix is determined from a matching pair of plaintext and ciphertext by solving a system of linear equations modulo \(settings.textOptions.alphabetSize).",
                       minWidth: 560) {
            DocumentPicker(title: "Plaintext", selection: $plainID)
            DocumentPicker(title: "Ciphertext", selection: $cipherID)
            Toggle("Determine matrix size automatically (1…10)", isOn: $automatic)
            if !automatic { Stepper("Matrix size: \(size)", value: $size, in: 1...10) }
            Picker("Multiplication", selection: $multiplication) {
                Text("Matrix × column vector").tag(HillMultiplication.matrixTimesVector)
                Text("Row vector × matrix").tag(HillMultiplication.vectorTimesMatrix)
            }
            if let message { Text(message).foregroundStyle(.secondary) }
            if let m = result {
                Text("Key matrix found:").font(.headline)
                Text(m.map { $0.map { String(format: "%3d", $0) }.joined(separator: " ") }.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
            }
        } buttons: {
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Analyze", action: analyze)
            Button("Decrypt ciphertext") {
                guard let m = result, let c = DocumentPicker.document(for: cipherID) else { return }
                if CipherRun.text(c, method: "hill", name: "Hill", encrypt: false, key: HillDialog.format(m), {
                    try HillCipher(matrix: m, options: settings.textOptions, multiplication: multiplication).decrypt(c.text)
                }) { close() }
            }.keyboardShortcut(.defaultAction).disabled(result == nil)
        }
        .onAppear {
            cipherID = ObjectIdentifier(document)
            if let p = document.origin?.parent { plainID = ObjectIdentifier(p) }
        }
    }

    private func analyze() {
        guard let p = DocumentPicker.document(for: plainID), let c = DocumentPicker.document(for: cipherID) else { message = "Please select plaintext and ciphertext."; return }
        let sizes = automatic ? Array(1...10) : [size]
        for s in sizes {
            if let m = HillAnalysis.knownPlaintext(plaintext: p.text, ciphertext: c.text, size: s, options: settings.textOptions, multiplication: multiplication),
               let h = try? HillCipher(matrix: m, options: settings.textOptions, multiplication: multiplication) {
                let check = settings.textOptions.filtered(h.encrypt(String(p.text.prefix(400))))
                let cc = settings.textOptions.filtered(String(c.text.prefix(400)))
                if automatic && !cc.hasPrefix(String(check.prefix(min(40, check.count - s)))) { continue }
                result = m
                message = "Key of size \(s)×\(s) found."
                return
            }
        }
        result = nil
        message = "No matching key matrix could be determined (not enough text, or the texts do not belong together)."
    }
}

// MARK: - Single columnar transposition (known plaintext)

struct TranspositionAnalysisSheet: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var plainID: ObjectIdentifier?
    @CTState private var cipherID: ObjectIdentifier?
    @CTState private var maxLength = 8
    @CTState private var results: [[Int]] = []
    @CTState private var searched = false

    var body: some View {
        DialogScaffold(title: "Simple Column Transposition (Known Plaintext)",
                       subtitle: "All permutations up to the given length that transform the plaintext into the ciphertext are searched.",
                       minWidth: 520) {
            DocumentPicker(title: "Plaintext", selection: $plainID)
            DocumentPicker(title: "Ciphertext", selection: $cipherID)
            Stepper("Maximum key length: \(maxLength)", value: $maxLength, in: 2...10)
            if searched {
                if results.isEmpty { Text("No matching permutation found.").foregroundStyle(.secondary) }
                ForEach(results.indices, id: \.self) { i in
                    Text("Permutation: " + results[i].map(String.init).joined(separator: ",")).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                }
            }
        } buttons: {
            Button("Close", action: close).keyboardShortcut(.cancelAction)
            Button("Find") {
                guard let p = DocumentPicker.document(for: plainID), let c = DocumentPicker.document(for: cipherID) else { return }
                results = TranspositionAnalysis.knownPlaintextSingleColumn(plaintext: p.text, ciphertext: c.text, options: settings.textOptions, maxKeyLength: maxLength)
                searched = true
            }.keyboardShortcut(.defaultAction)
        }
        .onAppear {
            cipherID = ObjectIdentifier(document)
            if let p = document.origin?.parent { plainID = ObjectIdentifier(p) }
        }
    }
}
