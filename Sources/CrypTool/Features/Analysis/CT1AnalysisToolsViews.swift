import AppKit
import Combine
import SwiftUI
import CTCommon
import CTAnalysis

// CT1 parity for Analyse ▸ Werkzeuge (Entropie, N-Gramm, Periode) and Analyse ▸ Zufallsanalyse
// (Frequency/Poker/Serial/Runs-Test, FIPS-PUB-140-1, Vitányi, 3D-Visualisierung).

extension CT1Analysis {
    /// True if the document is shown as hex dump – CT1 then analyses bytes (CHexDoc), otherwise the
    /// text with the alphabet of the text options (CAscDoc).
    static func isBinaryView(_ document: CTDocument) -> Bool {
        if let wc = document.windowControllers.first as? DocumentWindowController { return wc.viewMode == .hex }
        return !document.isText
    }

    /// Opens a tool window whose content can close it.
    @discardableResult
    static func toolWindow<V: View>(id: String?, title: String, size: CGSize, @ViewBuilder content: (_ close: @escaping () -> Void) -> V) -> NSWindow {
        let holder = CT1ToolsWindowHolder()
        let w = WindowPresenter.tool(id: id, title: title, size: size) {
            content({ holder.window?.close() })
        }
        holder.window = w
        return w
    }

    // MARK: Entropie

    /// Analyse ▸ Werkzeuge ▸ Entropie (CT1 IDD_ENTROPY_INFO).
    static func openEntropy(document: CTDocument) {
        let binary = isBinaryView(document)
        let alphabetSize: Int
        let present: Int
        let entropy: Double
        if binary {
            let h = Statistics.byteHistogram(document.bytes)
            alphabetSize = 256
            present = h.filter { $0 > 0 }.count
            entropy = Statistics.entropy(counts: h)
            guard !document.bytes.isEmpty else {
                Alerts.error("The input must contain at least 1 (not necessarily different) character(s) from the current alphabet. The alphabet can be configured in Options \\ Text Options.")
                return
            }
        } else {
            let o = AppSettings.shared.textOptions
            let counts = Statistics.letterCounts(document.text, options: o).map(\.count)
            alphabetSize = o.alphabetSize
            present = counts.filter { $0 > 0 }.count
            entropy = Statistics.entropy(counts: counts)
            guard counts.reduce(0, +) > 0 else {
                Alerts.error("The input must contain at least 1 (not necessarily different) character(s) from the current alphabet. The alphabet can be configured in Options \\ Text Options.")
                return
            }
        }
        var info: String
        if alphabetSize < 256 {
            info = present < alphabetSize
                ? "This document contains \(present) different characters compared to the \(alphabetSize) characters of the selected alphabet."
                : "This document contains all \(alphabetSize) different characters of the selected alphabet."
        } else {
            info = present < alphabetSize
                ? "This document contains \(present) different byte values (there are \(alphabetSize) different byte values)."
                : "This document contains all \(alphabetSize) possible byte values."
        }
        info += "\n\nThe entropy of the whole document is \(CT1Format.double(entropy, decimals: 2))\n(maximum possible entropy \(CT1Format.double(log2(Double(max(alphabetSize, 1))), decimals: 2)))."
        Alerts.info(info, title: "Entropy <\(document.shortName)>")
    }

    // MARK: N-Gramm

    /// Analyse ▸ Werkzeuge ▸ N-Gramm (CT1 IDD_NGRAM_ANALYSIS, "N-Gramm-Liste von %s").
    static func openNGram(document: CTDocument) {
        toolWindow(id: nil, title: "N-Gram List of \(document.shortName)", size: CGSize(width: 760, height: 560)) { close in
            CT1NGramListView(document: document, binary: isBinaryView(document), close: close)
        }
    }

    // MARK: Periode

    /// Analyse ▸ Werkzeuge ▸ Periode (CT1 IDD_PERIODICITY_ANALYSIS).
    static func openPeriodicity(document: CTDocument) {
        let bytes = document.bytes
        guard bytes.count >= 4 else {
            Alerts.error("The file to be analyzed must be at least 4 bytes large!")
            return
        }
        let results = Statistics.periodicity(bytes)
        guard !results.isEmpty else {
            Alerts.info("No periodicity found.")
            return
        }
        toolWindow(id: nil, title: "Results of Periodicity Analysis", size: CGSize(width: 860, height: 520)) { close in
            CT1PeriodicityView(document: document, results: results, close: close)
        }
    }

    // MARK: Zufallstests

    /// Analyse ▸ Zufallsanalyse ▸ Frequency-Test.
    static func openFrequencyTest(document: CTDocument) {
        guard checkRandomTestSize(document) else { return }
        if document.bytes.count * 8 < 10_000 {
            Alerts.info("For frequency test it is recommended to examine at least 1250 bytes.")
        }
        openRandomTest(.frequency, document)
    }

    /// Analyse ▸ Zufallsanalyse ▸ Poker-Test.
    static func openPokerTest(document: CTDocument) {
        guard checkRandomTestSize(document) else { return }
        openRandomTest(.poker, document)
    }

    /// Analyse ▸ Zufallsanalyse ▸ Serial-Test.
    static func openSerialTest(document: CTDocument) {
        guard checkRandomTestSize(document) else { return }
        openRandomTest(.serial, document)
    }

    /// Analyse ▸ Zufallsanalyse ▸ Runs-Test (Runs- und Long-Runs-Test).
    static func openRunsTest(document: CTDocument) {
        guard checkRandomTestSize(document) else { return }
        toolWindow(id: nil, title: "Runs Tests of \(document.shortName)", size: CGSize(width: 520, height: 600)) { close in
            CT1RunsTestView(document: document, close: close)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ FIPS-PUB-140-1 Testbatterie.
    static func openFIPSTest(document: CTDocument) {
        let n = document.bytes.count
        guard n >= 2500 else {
            Alerts.error("The FIPS-PUB-140-1 test battery is specified for exactly 2,500 bytes.\nThe currently selected file has a length of only \(CT1Format.integer(n)) bytes.\nTherefore the test cannot be performed.")
            return
        }
        if n > 2500 {
            Alerts.info("The FIPS-PUB-140-1 test battery is specified for exactly 2,500 bytes.\nBecause the currently selected document (\(CT1Format.integer(n)) bytes) is bigger,\nCrypTool will test only the first 2,500 bytes of the whole document.")
        }
        toolWindow(id: nil, title: "FIPS-PUB-140-1 test battery of \(document.shortName)", size: CGSize(width: 460, height: 500)) { close in
            CT1FIPSView(document: document, close: close)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ Vitányi.
    static func openVitanyi(document: CTDocument) {
        guard document.bytes.count >= 500 else {
            Alerts.error("For Vitányi analysis, the input file size must exceed 500 bytes!")
            return
        }
        WindowPresenter.tool(id: nil, title: "Vitányi Diagram of <\(document.shortName)>", size: CGSize(width: 640, height: 560)) {
            RandomTestView(kind: .vitanyi, document: document)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ 3D-Visualisierung.
    static func open3DVisualization(document: CTDocument) {
        WindowPresenter.tool(id: nil, title: "3-D Visualization: \(document.shortName)", size: CGSize(width: 760, height: 680)) {
            Random3DView(document: document)
        }
    }

    private static func checkRandomTestSize(_ document: CTDocument) -> Bool {
        if document.bytes.count < 16 {
            Alerts.error("The file size must be at least 16 bytes !")
            return false
        }
        return true
    }

    private static func openRandomTest(_ kind: CT1RandomTestView.TestKind, _ document: CTDocument) {
        let title: String
        switch kind {
        case .frequency: title = "Frequency test of \(document.shortName)"
        case .poker: title = "Poker Test of \(document.shortName)"
        case .serial: title = "Serial Test (overlapping) of \(document.shortName)"
        }
        toolWindow(id: nil, title: title, size: CGSize(width: 500, height: 430)) { close in
            CT1RandomTestView(kind: kind, document: document, close: close)
        }
    }
}

@MainActor
final class CT1ToolsWindowHolder {
    weak var window: NSWindow?
}

// MARK: - N-Gramm-Liste

struct CT1NGramListView: View {
    let document: CTDocument
    let binary: Bool
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    /// 0 Histogramm, 1 Digramm, 2 Trigramm, 3 freies N
    @CTState private var choice = 0
    @CTState private var freeN = "4"
    @CTState private var showCount = "26"
    @CTState private var result: CT1NGram.Result?
    @CTState private var counts: [Int] = [0, 0, 0, 0]
    @CTState private var shownN = 4

    struct Row: Identifiable { let id: Int; let label: String; let percent: String; let count: Int }

    private var rows: [Row] {
        guard let r = result else { return [] }
        let limit = min(Int(showCount) ?? 26, 5000)
        return r.entries.prefix(max(0, limit)).enumerated().map {
            Row(id: $0.offset, label: r.label($0.element), percent: String(format: "%.4f", $0.element.relative * 100), count: $0.element.count)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                GroupBox("Selection") {
                    VStack(alignment: .leading, spacing: 6) {
                        radio(0) { Text("Histogram (\(counts[0]))") }
                        radio(1) { Text("Digram (\(counts[1]))") }
                        radio(2) { Text("Trigram (\(counts[2]))") }
                        radio(3) {
                            HStack(spacing: 2) {
                                TextField("", text: $freeN).frame(width: 30)
                                Text("-gram (\(counts[3]))")
                            }
                        }
                        HStack(spacing: 4) {
                            Text("Display of the")
                            TextField("", text: $showCount).frame(width: 50)
                        }
                        Text("most common N-grams (allowed values: 1-5000)")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                Button("Text options") { OptionsWindows.showTextOptions() }
                    .frame(maxWidth: .infinity)
                    .disabled(binary)
                Spacer().frame(height: 8)
                Button("Compute list", action: evaluate)
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity)
                Button("Save list", action: save)
                    .disabled(result == nil)
                Button("Close", action: close).keyboardShortcut(.cancelAction)
                Spacer()
            }
            .frame(width: 200)
            Table(rows) {
                TableColumn("No.") { Text(String(format: "%3d", $0.id + 1)).font(.system(.body, design: .monospaced)) }.width(45)
                TableColumn("Character sequence") { Text($0.label).font(.system(.body, design: .monospaced)) }
                TableColumn("Frequency in %") { Text($0.percent).font(.system(.body, design: .monospaced)) }.width(110)
                TableColumn("Frequency") { Text("\($0.count)").font(.system(.body, design: .monospaced)) }.width(90)
            }
        }
        .padding(12)
        .onAppear(perform: evaluate)
        .onReceive(settings.$textOptions.dropFirst()) { _ in
            // CT1 recalculates after the text options dialog
            DispatchQueue.main.async { evaluate() }
        }
    }

    private func radio<L: View>(_ i: Int, @ViewBuilder _ label: () -> L) -> some View {
        HStack(spacing: 6) {
            Button { choice = i } label: {
                Image(systemName: choice == i ? "largecircle.fill.circle" : "circle")
            }
            .buttonStyle(.plain)
            label()
        }
    }

    private func nValue() -> Int? {
        guard let v = Int(freeN.trimmingCharacters(in: .whitespaces)), (3...16).contains(v) else { return nil }
        return v
    }

    private func compute(_ n: Int) -> CT1NGram.Result {
        binary ? CT1NGram.binary(document.bytes, n: n) : CT1NGram.text(document.text, n: n, options: settings.textOptions)
    }

    /// "Liste berechnen" (CT1 OnEvalNGram).
    private func evaluate() {
        guard let n = nValue() else {
            Alerts.error("Please enter an integer between 3 and 16.")
            return
        }
        guard let cnt = Int(showCount.trimmingCharacters(in: .whitespaces)), cnt > 0, cnt <= 5000 else {
            Alerts.error("The number of Rows is bounded by 5,000!\nPlease enter a number between 1 and 5,000.")
            return
        }
        let selected = choice == 3 ? n : choice + 1
        let r = compute(selected)
        result = r
        shownN = selected
        if cnt > r.individuals { showCount = String(r.individuals) }
        counts = [compute(1).individuals, compute(2).individuals, compute(3).individuals, compute(n).individuals]
    }

    /// "Liste speichern": opens the list as document ("Digramm-Analyse von <…>") and closes.
    private func save() {
        guard let n = nValue() else { return }
        let selected = choice == 3 ? n : choice + 1
        let r = selected == shownN && result != nil ? result! : compute(selected)
        let method = CT1NGram.method(n: selected, freeN: choice == 3)
        let rows = min(Int(showCount) ?? 26, r.individuals)
        let size = binary ? min(document.bytes.count, CT1NGram.maxBytes)
                          : min(document.text.data(using: .windowsCP1252)?.count ?? document.bytes.count, CT1NGram.maxBytes)
        let text = CT1NGram.listDocument(r, rows: rows, method: method, title: document.shortName, fileSize: size)
        DocumentFactory.openResult(text: text, title: "\(method) Analysis of <\(document.shortName)>", parent: document)
        close()
    }
}

// MARK: - Periode

struct CT1PeriodicityView: View {
    let document: CTDocument
    let results: [Statistics.PeriodResult]
    let close: () -> Void

    struct Row: Identifiable { let id: Int; let r: Statistics.PeriodResult }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Each line below contains the following characteristics of the found cycles:")
                Text("- the first position in the file, where the cycle starts (the first character within the file has the offset value 1)")
                Text("- the length of the cycle")
                Text("- the number, how often the cycle appears")
                Text("- the first maximum 20 bytes of the cycle (presented in ASCII and hex format)")
            }
            .font(.callout)
            Table(results.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                TableColumn("No.") { Text("\($0.id + 1)") }.width(40)
                TableColumn("Offset") { Text("\($0.r.offset + 1)") }.width(60)
                TableColumn("Length") { Text("\($0.r.length)") }.width(60)
                TableColumn("Number of cycles") { Text("\($0.r.repetitions)") }.width(90)
                TableColumn("Cycle content") { Text(CT1Periodicity.text($0.r)).font(.system(.body, design: .monospaced)) }.width(170)
                TableColumn("Cycle content (hex)") { Text(CT1Periodicity.hex($0.r)).font(.system(.body, design: .monospaced)) }
            }
            HStack {
                Button("Save list into main window") {
                    let header = "Periodicity analysis of \(document.shortName):"
                    DocumentFactory.openResult(text: CT1Periodicity.listDocument(results, title: document.shortName),
                                               title: header, parent: document)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(12)
    }
}

// MARK: - Frequency / Poker / Serial (IDD_FRQ_TEST)

/// Pass/fail pictogram of CT1's test dialogs (check mark / cross).
struct CT1TestPictogram: View {
    let passed: Bool?
    var body: some View {
        if let passed {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(passed ? .green : .red)
                .font(.title2)
        }
    }
}

struct CT1RandomTestView: View {
    enum TestKind { case frequency, poker, serial }
    let kind: TestKind
    let document: CTDocument
    let close: () -> Void
    @CTState private var alpha = CT1RandomTests.defaultAlpha
    @CTState private var tupel = 3
    @CTState private var useDefaults = true
    @CTState private var randomBlocks = false
    @CTState private var offset = "0"
    @CTState private var length = ""
    @CTState private var info = ""
    @CTState private var verdict = ""
    @CTState private var passed: Bool?

    private var testName: String {
        switch kind { case .frequency: return "Frequency test"; case .poker: return "Poker test"; case .serial: return "Serial test" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Parameter options") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Significance level alpha:")
                        Picker("", selection: $alpha) {
                            ForEach(CT1RandomTests.alphaLevels, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 80)
                        Spacer()
                        Text("Tuple size").foregroundStyle(kind == .poker ? .primary : .secondary)
                        Picker("", selection: $tupel) {
                            ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                        }.labelsHidden().frame(width: 55).disabled(kind != .poker)
                    }
                    Toggle("Default offset and test length", isOn: $useDefaults)
                        .onChange(of: useDefaults) { _, on in if on { resetRange() } }
                    Toggle("Use randomly chosen sections from file", isOn: $randomBlocks)
                    HStack {
                        Text("Offset:")
                        TextField("", text: $offset).frame(width: 90)
                        Spacer()
                        Text("Test length")
                        TextField("", text: $length).frame(width: 90)
                    }
                    .disabled(useDefaults)
                }
                .padding(4)
            }
            GroupBox("Test results") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(info.isEmpty ? " \n " : info).font(.system(.body, design: .monospaced))
                    HStack {
                        Text(verdict.isEmpty ? " " : verdict).font(.headline)
                        CT1TestPictogram(passed: passed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            HStack {
                Button("Execute test", action: runTest)
                Spacer()
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .onAppear(perform: resetRange)
    }

    private func resetRange() {
        offset = "0"
        length = String(document.bytes.count)
    }

    private func runTest() {
        let kindValue: CT1RandomTests.Kind
        switch kind {
        case .frequency: kindValue = .frequency
        case .serial: kindValue = .serial
        case .poker: kindValue = .poker(tupel: tupel)
        }
        let off = Int(offset.trimmingCharacters(in: .whitespaces)) ?? -1
        let len = Int(length.trimmingCharacters(in: .whitespaces)) ?? 0
        var g = SystemRandomNumberGenerator()
        guard let o = CT1RandomTests.run(kindValue, data: document.bytes, alpha: alpha, useDefaults: useDefaults,
                                         offset: off, length: useDefaults ? document.bytes.count : len,
                                         randomBlocks: randomBlocks, using: &g) else {
            info = ""
            verdict = "Wrong offset or test length !"
            passed = false
            Alerts.error("Offset + test length must be smaller than the file size !")
            return
        }
        info = o.info
        verdict = o.verdict(testName)
        passed = o.passed
    }
}

// MARK: - Runs-Test (IDD_RUNS_TEST)

struct CT1RunsTestView: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var alpha = CT1RandomTests.defaultAlpha
    @CTState private var defaultRun = true
    @CTState private var randomBlocks = false
    @CTState private var offset = "0"
    @CTState private var length = ""
    @CTState private var runLength = "3"
    @CTState private var defaultLongRun = true
    @CTState private var longRunLength = "34"
    @CTState private var runInfo = ""
    @CTState private var runVerdict = "\nPlease select \"Execute tests\""
    @CTState private var runPassed: Bool?
    @CTState private var longInfo = ""
    @CTState private var longVerdict = ""
    @CTState private var longPassed: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Runs parameter") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Significance level alpha:")
                        Picker("", selection: $alpha) {
                            ForEach(CT1RandomTests.alphaLevels, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 80)
                    }
                    Toggle("Default run test parameter", isOn: $defaultRun)
                        .onChange(of: defaultRun) { _, on in if on { resetRuns() } }
                    Toggle("Use randomly chosen sections from file", isOn: $randomBlocks)
                    Group {
                        HStack {
                            Text("Offset:")
                            TextField("", text: $offset).frame(width: 90)
                            Spacer()
                            Text("Length:")
                            TextField("", text: $length).frame(width: 90)
                        }
                        HStack {
                            Text("Run length:")
                            TextField("", text: $runLength).frame(width: 60)
                        }
                    }
                    .disabled(defaultRun)
                }
                .padding(4)
            }
            GroupBox("Long runs parameter") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Default long runs parameter", isOn: $defaultLongRun)
                        .onChange(of: defaultLongRun) { _, on in if on { longRunLength = "34" } }
                    HStack {
                        Text("Maximal run length:")
                        TextField("", text: $longRunLength).frame(width: 70).disabled(defaultLongRun)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            GroupBox("Test status") {
                VStack(alignment: .leading, spacing: 8) {
                    if !runInfo.isEmpty { Text(runInfo).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text(runVerdict).font(.headline).fixedSize(horizontal: false, vertical: true)
                        CT1TestPictogram(passed: runPassed)
                    }
                    if !longInfo.isEmpty { Text(longInfo).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text(longVerdict.isEmpty ? " " : longVerdict).font(.headline)
                        CT1TestPictogram(passed: longPassed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            HStack {
                Button("Execute tests", action: runTests)
                Spacer()
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .onAppear(perform: resetRuns)
    }

    private func resetRuns() {
        offset = "0"
        runLength = "3"
        length = String(document.bytes.count)
    }

    /// CT1 CDlgRunsTest::OnTestbutton – first the Long-Runs test, then the Runs test.
    private func runTests() {
        let data = document.bytes
        let fileLength = data.count
        let lrl = Int(longRunLength.trimmingCharacters(in: .whitespaces)) ?? 0
        if !defaultLongRun && (lrl > fileLength || lrl <= 0) {
            longPassed = false
            longInfo = ""
            longVerdict = "Wrong long runs length !"
            Alerts.error("The selected parameter for the maximal run length exceeds the  possible values !\nPlease select an integer between [1..\(fileLength)].")
        } else {
            let r = CT1RandomTests.longRunTest(data, maxRun: defaultLongRun ? 34 : lrl)
            longPassed = r.passed
            longInfo = r.info
            longVerdict = r.passed ? "Long runs test passed!" : "Long runs test failed!"
        }
        let off = Int(offset.trimmingCharacters(in: .whitespaces)) ?? -1
        let len = Int(length.trimmingCharacters(in: .whitespaces)) ?? 0
        let k = Int(runLength.trimmingCharacters(in: .whitespaces)) ?? 0
        var g = SystemRandomNumberGenerator()
        guard k >= 1 || defaultRun,
              let o = CT1RandomTests.run(.runs(runLength: max(k, 1)), data: data, alpha: alpha, useDefaults: defaultRun,
                                         offset: off, length: defaultRun ? fileLength : len, randomBlocks: randomBlocks, using: &g) else {
            runPassed = false
            runInfo = ""
            runVerdict = "Wrong offset or test length !"
            Alerts.error("Offset + test length must be smaller than the file size !")
            return
        }
        runPassed = o.passed
        runInfo = o.info
        runVerdict = o.passed ? "Runs test passed!" : "Runs test failed!"
    }
}

// MARK: - FIPS-PUB-140-1 (IDD_FIPS_PUB_140_1)

struct CT1FIPSView: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var result: CT1RandomTests.FIPSResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Entropy state") {
                Text(result?.entropyLine ?? " ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            GroupBox("Result of the individual FIPS-PUB-140-1 tests") {
                VStack(alignment: .leading, spacing: 10) {
                    line("Longrun test result:", result?.longRunLine, result?.longRunPassed)
                    line("Mono bit test result:", result?.monobitLine, result?.monobitPassed)
                    line("Poker test result:", result?.pokerLine, result?.pokerPassed)
                    line("Runs test result:", result?.runsLine, result?.runsPassed)
                }
                .padding(4)
            }
            GroupBox("Test battery state") {
                line("FIPS-PUB-140-1 Test battery result:", result?.batteryLine, result?.batteryPassed)
                    .padding(4)
            }
            if let r = result {
                Text("Ones: \(r.monobitOnes) (9654 < n < 10346) · Poker: \(String(format: "%.2f", r.pokerStatistic)) (1.03 < X < 57.4) · longest run: \(r.longestRun) (< 34)")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Start test battery", action: run)
                Spacer()
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .onAppear(perform: run)   // CT1 starts the battery when the dialog opens
    }

    private func line(_ label: String, _ value: String?, _ passed: Bool?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(value ?? " ").font(.headline)
            }
            Spacer()
            CT1TestPictogram(passed: passed)
        }
    }

    private func run() { result = CT1RandomTests.fips140_1(document.bytes) }
}
