import AppKit
import SwiftUI
import Charts
import CTCommon
import CTAnalysis
import CTClassic

/// CT1's step-by-step ciphertext-only analyses (AutomaticAnalysis.cpp `CaesarAuto`, `VigenereAuto`,
/// `XorAuto`, `AddAuto`). Which intermediate steps are shown is controlled by the Analyseoptionen
/// (Caesar: "Ermittelter Schlüssel", "Korrelation", "Histogramme"; Vigenère, XOR and Addition share
/// "Ermittelter Schlüssel", "Ermittelte Schlüssellänge", "Autokorrelation", "Weitere Analyse-Werte
/// ausgeben"). Dialogs are application-modal like CT1's `DoModal`, plot and histogram windows stay open.
extension CT1Analysis {
    /// Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸ Caesar.
    static func openCaesarAnalysis(document: CTDocument) {
        CT1AutoFlows.caesar(document)
    }

    /// … ▸ Ciphertext-Only ▸ Vigenère.
    static func openVigenereAnalysis(document: CTDocument) {
        Task { @MainActor in await CT1AutoFlows.vigenere(document) }
    }

    /// … ▸ Ciphertext-Only ▸ XOR.
    static func openXORAnalysis(document: CTDocument) {
        Task { @MainActor in await CT1AutoFlows.bytes(document, kind: .xor) }
    }

    /// … ▸ Ciphertext-Only ▸ Addition.
    static func openAdditionAnalysis(document: CTDocument) {
        Task { @MainActor in await CT1AutoFlows.bytes(document, kind: .addition) }
    }
}

// MARK: - Flows

@MainActor
enum CT1AutoFlows {
    private typealias A = CT1AutoAnalysis

    /// Analyseoptionen (stored by AnalysisOptionsView; unset keys use CT1's defaults).
    private static func option(_ key: String, _ defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    // MARK: Caesar

    static func caesar(_ doc: CTDocument) {
        let s = AppSettings.shared
        let o = s.textOptions
        let alphabet = o.alphabetCharacters
        let n = alphabet.count
        let title = A.Kind.caesar.analysisTitle
        guard !doc.bytes.isEmpty else { Alerts.error(A.inputTooShortMessage(1)); return }
        let text = doc.text
        let refName = s.referenceFileDisplayName
        let refText = s.referenceText
        let seq = o.indices(of: text)

        // 1. histograms of the reference file and of the ciphertext
        if option("analysis.caesarHistograms", false) {
            CT1AutoUI.letterHistogram(o.indices(of: refText), name: refName, alphabet: alphabet)
            CT1AutoUI.letterHistogram(seq, name: doc.shortName, alphabet: alphabet)
            Alerts.info("Compare ciphertext with reference file <\(refName)>.", title: title)
        }
        guard seq.count >= 2, n > 0 else { Alerts.error(A.inputTooShortMessage(2)); return }
        guard !refText.isEmpty else { Alerts.error(A.referenceFileError); return }

        // 2. correlation of the distributions (reference shifted by one)
        let refCounts = A.counts(o.indices(of: refText), symbolCount: n)
        let corr = A.caesarCorrelation(textCounts: A.counts(seq, symbolCount: n), referenceCounts: refCounts)
        if option("analysis.caesarCorrelation", true) {
            CT1AutoUI.correlationPlot(corr, title: "Correlation of the distributions <\(doc.shortName)> and <\(refName)>", alphabet: alphabet)
            Alerts.info("Analysis of the superposition", title: title)
        }

        // 3. key dialog (key offset 1: the text is decrypted by index + 1)
        var shift = A.findPeak(corr)
        if option("analysis.caesarShowKey", true) {
            let proposed = String(alphabet[shift])
            guard let entered: String = CT1AutoUI.runModal(title: "Automatic Caesar Analysis", content: { done in
                CT1AutoCaesarKeyDialog(key: proposed, alphabet: alphabet, ignoreCase: !o.distinguishCase, done: done)
            }) else { return }
            // CT1: an empty field means shift 0
            shift = entered.count == 1 ? (alphabet.firstIndex(of: entered.first!) ?? 0) : 0
        }
        let letter = String(alphabet[shift])
        CipherRun.open(text: doc, method: "caesar", title: A.resultTitle(.caesar, document: doc.shortName, key: letter),
                       key: "\(letter), KEY OFFSET: 1") {
            Caesar.decrypt(text, shift: shift + 1, options: o)
        }
    }

    // MARK: Vigenère

    static func vigenere(_ doc: CTDocument) async {
        let s = AppSettings.shared
        let o = s.textOptions
        let alphabet = o.alphabetCharacters
        let n = alphabet.count
        let title = A.Kind.vigenere.analysisTitle
        let text = doc.text
        let seq = o.indices(of: text)
        guard seq.count > 3, n > 0 else { Alerts.error(A.inputTooShortMessage(4)); return }

        // 1. autocorrelation (shifts 1 … 199)
        guard let c = await CT1AutoUI.autocorrelation(seq) else { return }
        guard c.count >= 8 else { Alerts.error(A.inputTooShortMessage(8)); return }
        if option("analysis.vigAutocorrelation", true) {
            CT1AutoUI.autocorrelationPlot(c, textLength: seq.count, document: doc.shortName)
        }

        // 2. key length
        var period = A.keyLength(autocorrelation: c)
        if option("analysis.vigKeyLength", true) {
            let proposed = period
            guard let p: Int = CT1AutoUI.runModal(title: "Automatic Vigenère Analysis", content: { done in
                CT1AutoKeyLengthDialog(length: proposed, expectedHex: nil) { r in done(r?.0) }
            }) else { return }
            period = p
        }
        let refText = s.referenceText
        guard !refText.isEmpty else { Alerts.error(A.referenceFileError); return }
        let refName = s.referenceFileDisplayName
        let refCounts = A.counts(o.indices(of: refText), symbolCount: n)

        // 3. Caesar analysis of every column
        var more = option("analysis.vigMore", false)
        if more { CT1AutoUI.letterHistogram(o.indices(of: refText), name: refName, alphabet: alphabet) }
        var key: [Int] = []
        for i in 0..<period {
            let col = A.columnCounts(seq, period: period, column: i, symbolCount: n)
            if more {
                CT1AutoUI.letterHistogram(counts: col, name: "Caesar \(i + 1) of <\(doc.shortName)>", alphabet: alphabet)
            }
            let corr = A.caesarCorrelation(textCounts: col, referenceCounts: refCounts)
            let k = (A.findPeak(corr) + 1) % n
            key.append(k)
            if more {
                CT1AutoUI.correlationPlot(corr, title: "Correlation of the distributions <Caesar \(i + 1)> and <\(refName)>", alphabet: alphabet)
                if !Alerts.confirm(A.ascertainedKeyCharacterMessage(position: i + 1, key: alphabet[k]), title: title) { more = false }
            }
        }

        // 4. key dialog, iterated key, decryption
        var keyString = o.string(from: key)
        if option("analysis.vigKey", true) {
            let proposed = keyString
            guard let k: String = CT1AutoUI.runModal(title: "Automatic Analysis", content: { done in
                CT1AutoKeyDialog(key: proposed, alphabet: alphabet, ignoreCase: !o.distinguishCase, done: done)
            }) else { return }
            keyString = k
        }
        if let r = A.reducedKey(Array(keyString)) {
            keyString = String(r)
            Alerts.info(A.repeatedKeyMessage(keyString), title: title)
        }
        let finalKey = keyString
        CipherRun.open(text: doc, method: "vigenere", title: A.resultTitle(.vigenere, document: doc.shortName, key: finalKey), key: finalKey) {
            try Vigenere.decrypt(text, key: finalKey, options: o)
        }
    }

    // MARK: XOR / byte-wise addition

    static func bytes(_ doc: CTDocument, kind: CT1AutoAnalysis.Kind) async {
        let s = AppSettings.shared
        let xor = kind == .xor
        let title = kind.analysisTitle
        let data = doc.bytes
        guard data.count > 1 else { Alerts.error(A.inputTooShortMessage(2)); return }

        // 1. autocorrelation
        guard let c = await CT1AutoUI.autocorrelation(data.map { Int($0) }) else { return }
        guard c.count >= 8 else { Alerts.error(A.inputTooShortMessage(8)); return }
        if option("analysis.vigAutocorrelation", true) {
            CT1AutoUI.autocorrelationPlot(c, textLength: data.count, document: doc.shortName)
        }

        // 2. key length and expected most frequent plaintext byte
        var period = A.keyLength(autocorrelation: c)
        var expected = UInt8(truncatingIfNeeded: s.expectedMostFrequentByte)
        if option("analysis.vigKeyLength", true) {
            let proposed = period
            let hex = String(format: "%02X", expected)
            guard let r: (Int, UInt8) = CT1AutoUI.runModal(title: title, content: { done in
                CT1AutoKeyLengthDialog(length: proposed, expectedHex: hex, done: done)
            }) else { return }
            (period, expected) = r
        }

        // 3. most frequent byte of every column
        var more = option("analysis.vigMore", false)
        var key: [UInt8] = []
        var shift = 0
        for i in 0..<period {
            let counts = A.byteColumnCounts(data, period: period, column: i)
            if more {
                CT1AutoUI.byteHistogram(counts, name: "\(kind.columnName) \(i + 1) of <\(doc.shortName)>")
                if !Alerts.confirm("Continue", title: title) { more = false }
            }
            shift = A.mostFrequentByte(counts, previous: shift)
            key.append(xor ? UInt8(shift) ^ expected : UInt8(shift) &- expected)
        }

        // 4. hex key dialog, iterated key, decryption
        if option("analysis.vigKey", true) {
            let proposed = A.hexKeyString(key)
            guard let k: [UInt8] = CT1AutoUI.runModal(title: title, content: { done in
                CT1AutoHexKeyDialog(key: proposed, done: done)
            }) else { return }
            key = k
        }
        if let r = A.reducedKey(key) {
            key = r
            Alerts.info(A.repeatedKeyMessage(A.hexKeyString(key)), title: title)
        }
        let finalKey = key
        let hex = A.hexKeyString(finalKey)
        CipherRun.open(bytes: doc, method: xor ? "xor" : "add", title: A.resultTitle(kind, document: doc.shortName, key: hex), key: hex) {
            xor ? ByteCiphers.xor(data, key: finalKey) : ByteCiphers.subtract(data, key: finalKey)
        }
    }
}

// MARK: - Windows, modal dialogs, progress

@MainActor
enum CT1AutoUI {
    /// Runs `content` in an application-modal dialog (CT1 `DoModal`) and returns the value passed
    /// to `done` (nil = Abbrechen).
    static func runModal<R, V: View>(title: String, @ViewBuilder content: (_ done: @escaping (R?) -> Void) -> V) -> R? {
        var result: R?
        let w = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        let host = NSHostingController(rootView: AnyView(content({ r in
            result = r
            NSApp.stopModal()
        }).environmentObject(AppSettings.shared)))
        host.sizingOptions = [.preferredContentSize]
        w.contentViewController = host
        w.center()
        NSApp.runModal(for: w)
        w.orderOut(nil)
        return result
    }

    /// CT1 `SCorrelation(text, min(N, 200))` off the main thread; a progress window
    /// ("Autokorrelation erledigt: …%") with Abbrechen is shown for large inputs. nil = cancelled.
    static func autocorrelation(_ seq: [Int]) async -> [Int]? {
        let token = CancellationToken()
        let model = CT1AutoProgressModel()
        var window: NSWindow?
        if seq.count > 300_000 {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
            w.title = "Autocorrelation"
            w.isReleasedWhenClosed = false
            let host = NSHostingController(rootView: CT1AutoProgressView(model: model) { token.cancel() })
            host.sizingOptions = [.preferredContentSize]
            w.contentViewController = host
            w.center()
            w.makeKeyAndOrderFront(nil)
            window = w
        }
        let result = await Task.detached(priority: .userInitiated) {
            CT1AutoAnalysis.autocorrelation(seq, cancel: token) { p in
                Task { @MainActor in model.value = p }
            }
        }.value
        window?.orderOut(nil)
        return result
    }

    private static func chartWindow<V: View>(_ title: String, _ content: () -> V) {
        WindowPresenter.tool(title: title, size: CGSize(width: 820, height: 420), content: content)
    }

    /// "Autokorrelation von <doc>" (CT1 `Autocorr`).
    static func autocorrelationPlot(_ c: [Int], textLength: Int, document: String) {
        let relative = AppSettings.shared.plotRelativeAutocorrelation
        let values = CT1AutoAnalysis.autocorrelationPlotValues(c, textLength: textLength, relative: relative)
        chartWindow("Autocorrelation of <\(document)>") {
            SeriesChartView(title: "Autocorrelation", xLabel: "Offset",
                            yLabel: relative ? "Relative agreement [%]" : "Number of characters that match",
                            values: values, xOffset: 1, bars: true)
        }
    }

    /// "Korrelation der Verteilungen <…> und <…>" – x axis: shift (labelled with the alphabet).
    static func correlationPlot(_ corr: [Double], title: String, alphabet: [Character]) {
        chartWindow(title) {
            CT1AutoBarChart(heading: title, xLabel: "Offset", yLabel: "Correlation",
                            labels: corr.indices.map { CT1AutoBarChart.label(alphabet[$0 % max(1, alphabet.count)]) }, values: corr)
        }
    }

    /// CT1 `HistogramASCII`: "ASCII-Histogramm von <name> (N Zeichen)".
    static func letterHistogram(_ seq: [Int], name: String, alphabet: [Character]) {
        letterHistogram(counts: CT1AutoAnalysis.counts(seq, symbolCount: alphabet.count), name: name, alphabet: alphabet)
    }

    static func letterHistogram(counts: [Int], name: String, alphabet: [Character]) {
        let total = counts.reduce(0, +)
        let title = "ASCII Histogram of <\(name)> (\(total) characters)"
        let values = counts.map { total == 0 ? 0 : Double($0) * 100 / Double(total) }
        chartWindow(title) {
            CT1AutoBarChart(heading: title, xLabel: "Value", yLabel: "Frequency (%)",
                            labels: alphabet.map { CT1AutoBarChart.label($0) }, values: values)
        }
    }

    /// CT1 `HistogramBin`: "Binäres Histogramm von <name> (N Zeichen)".
    static func byteHistogram(_ counts: [Int], name: String) {
        let total = counts.reduce(0, +)
        let title = "Binary Histogram of <\(name)> (\(total) characters)"
        let values = counts.map { total == 0 ? 0 : Double($0) * 100 / Double(total) }
        chartWindow(title) {
            CT1AutoBarChart(heading: title, xLabel: "Value", yLabel: "Frequency (%)",
                            labels: (0..<256).map { String(format: "%02X", $0) }, values: values)
        }
    }
}

@MainActor
final class CT1AutoProgressModel: ObservableObject {
    @Published var value = 0.0
}

struct CT1AutoProgressView: View {
    @ObservedObject var model: CT1AutoProgressModel
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Autocorrelation finished: \(Int(model.value * 100))%")
            ProgressView(value: model.value).frame(width: 300)
            HStack { Spacer(); Button("Cancel", action: cancel).keyboardShortcut(.cancelAction) }
        }
        .padding(16)
    }
}

/// Bar/line chart with categorical labels (histograms and correlation plots).
struct CT1AutoBarChart: View {
    let heading: String
    let xLabel: String
    let yLabel: String
    let labels: [String]
    let values: [Double]
    @EnvironmentObject var settings: AppSettings

    static func label(_ c: Character) -> String { c == " " ? "␣" : String(c) }

    var body: some View {
        let axis = labels.count > 64 ? stride(from: 0, to: labels.count, by: 16).map { labels[$0] } : labels
        VStack(alignment: .leading) {
            Text(heading).font(.headline)
            Chart {
                ForEach(values.indices, id: \.self) { i in
                    if settings.plotAsBars {
                        BarMark(x: .value(xLabel, labels[i]), y: .value(yLabel, values[i]),
                                width: .ratio(min(1, 0.15 + Double(settings.plotBarWidth) * 0.08)))
                    } else {
                        LineMark(x: .value(xLabel, labels[i]), y: .value(yLabel, values[i]))
                            .lineStyle(StrokeStyle(lineWidth: CGFloat(settings.plotLineWidth)))
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: settings.plotShowZeroLine))
            .chartXAxis { AxisMarks(values: axis) { _ in AxisValueLabel() } }
            .chartXAxisLabel(xLabel)
            .chartYAxisLabel(yLabel)
        }
        .padding()
    }
}

// MARK: - Dialogs

/// Key filter of CT1's analysis key dialogs (`OnUpdateEdit1`): upper case if case is ignored, only
/// alphabet characters (others are rejected with a beep).
private func ct1AutoFilterKey(_ s: String, alphabet: [Character], ignoreCase: Bool, maxLength: Int) -> (String, Bool) {
    let set = Set(alphabet)
    var out = ""
    var rejected = false
    for ch in s {
        var c = ch
        if ignoreCase { let u = String(ch).uppercased(); if u.count == 1 { c = u.first! } }
        if set.contains(c) { out.append(c) } else { rejected = true }
    }
    // single character field: the last typed character replaces the old one; longer keys are cut (DDV_MaxChars)
    if out.count > maxLength { out = maxLength == 1 ? String(out.suffix(1)) : String(out.prefix(maxLength)); rejected = maxLength > 1 }
    return (out, rejected)
}

/// IDD_CAESAR_ANALYSIS "Automatische Caesar-Analyse".
struct CT1AutoCaesarKeyDialog: View {
    let alphabet: [Character]
    let ignoreCase: Bool
    let done: (String?) -> Void
    @CTState private var key: String

    init(key: String, alphabet: [Character], ignoreCase: Bool, done: @escaping (String?) -> Void) {
        self.alphabet = alphabet
        self.ignoreCase = ignoreCase
        self.done = done
        _key = CTState(initialValue: key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Derived Caesar key:")
                TextField("", text: $key).frame(width: 34).multilineTextAlignment(.center)
                    .font(.system(.body, design: .monospaced))
                    .ct1Filter($key) { ct1AutoFilterKey($0, alphabet: alphabet, ignoreCase: ignoreCase, maxLength: 1) }
            }.frame(maxWidth: .infinity)
            GroupBox("Remark") {
                Text(CT1AutoAnalysis.caesarKeyOffsetRemark(derivedKey: key.first ?? alphabet.first ?? "A", alphabet: alphabet))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Decrypt") { done(key) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}

/// IDD_KEYLENGTH "Automatische Vigenère-Analyse" (`expectedHex == nil`) and IDD_BIN_KEYLENGTH
/// (XOR / ADD, with "Erwartetes häufigstes Zeichen (Hex)").
struct CT1AutoKeyLengthDialog: View {
    let showsExpected: Bool
    let done: ((Int, UInt8)?) -> Void
    @CTState private var lengthText: String
    @CTState private var hexText: String

    init(length: Int, expectedHex: String?, done: @escaping ((Int, UInt8)?) -> Void) {
        showsExpected = expectedHex != nil
        self.done = done
        _lengthText = CTState(initialValue: String(length))
        _hexText = CTState(initialValue: expectedHex ?? "00")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Derived key length:")
                    TextField("", text: $lengthText).frame(width: 70)
                        .ct1Filter($lengthText) { s in
                            let d = s.filter { $0.isASCII && $0.isNumber }
                            return (String(d.prefix(4)), d.count != s.count)
                        }
                }
                if showsExpected {
                    GridRow {
                        Text("Expected most common character (hex):")
                        TextField("", text: $hexText).frame(width: 44).font(.system(.body, design: .monospaced))
                            .ct1Filter($hexText) { s in
                                let d = s.uppercased().filter { $0.isASCII && $0.isHexDigit }
                                return (String(d.prefix(2)), d.count != s.count || d.count > 2)
                            }
                    }
                }
            }
            HStack {
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue", action: next).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: showsExpected ? 360 : 320)
    }

    private func next() {
        guard let l = Int(lengthText), (1...200).contains(l) else {
            Alerts.error("Please enter an integer between 1 and 200.")
            return
        }
        // CDlgBinKeyLength::OnOK: hex digits accumulated, empty field = 00
        let c = hexText.reduce(0) { $0 * 16 + ($1.hexDigitValue ?? 0) }
        done((l, UInt8(truncatingIfNeeded: c)))
    }
}

/// IDD_KEY_ANALYSIS "Automatische Analyse" – editable Vigenère key.
struct CT1AutoKeyDialog: View {
    let alphabet: [Character]
    let ignoreCase: Bool
    let done: (String?) -> Void
    @CTState private var key: String

    init(key: String, alphabet: [Character], ignoreCase: Bool, done: @escaping (String?) -> Void) {
        self.alphabet = alphabet
        self.ignoreCase = ignoreCase
        self.done = done
        _key = CTState(initialValue: key)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Derived key:")
            TextField("", text: $key, axis: .vertical).lineLimit(2...4)
                .font(.system(.body, design: .monospaced))
                .ct1Filter($key) { ct1AutoFilterKey($0, alphabet: alphabet, ignoreCase: ignoreCase, maxLength: 200) }
            HStack {
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Decrypt") { done(key) }.keyboardShortcut(.defaultAction).disabled(key.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}

/// IDD_KEY_ANALYSIS with CT1's hex edit (`CDlgKeyHexAnalysis`, max. 200 bytes) – XOR / ADD key.
struct CT1AutoHexKeyDialog: View {
    let done: ([UInt8]?) -> Void
    @CTState private var key: String

    init(key: String, done: @escaping ([UInt8]?) -> Void) {
        self.done = done
        _key = CTState(initialValue: key)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Derived key:")
            TextField("", text: $key, axis: .vertical).lineLimit(2...4)
                .font(.system(.body, design: .monospaced))
                .ct1Filter($key) { CT1KeyInput.hex($0, maxDigits: 400) }
            HStack {
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Decrypt") { if let b = CT1KeyInput.hexBytes(key) { done(b) } }
                    .keyboardShortcut(.defaultAction).disabled(CT1KeyInput.hexBytes(key) == nil)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}
