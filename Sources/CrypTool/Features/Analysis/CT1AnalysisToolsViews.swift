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
                Alerts.error("Die Eingabe muss mindestens 1 (nicht unbedingt verschiedene) Buchstaben des eingestellten Alphabets enthalten. Das Alphabet können Sie unter Optionen \\ Textoptionen ändern.")
                return
            }
        } else {
            let o = AppSettings.shared.textOptions
            let counts = Statistics.letterCounts(document.text, options: o).map(\.count)
            alphabetSize = o.alphabetSize
            present = counts.filter { $0 > 0 }.count
            entropy = Statistics.entropy(counts: counts)
            guard counts.reduce(0, +) > 0 else {
                Alerts.error("Die Eingabe muss mindestens 1 (nicht unbedingt verschiedene) Buchstaben des eingestellten Alphabets enthalten. Das Alphabet können Sie unter Optionen \\ Textoptionen ändern.")
                return
            }
        }
        var info: String
        if alphabetSize < 256 {
            info = present < alphabetSize
                ? "Das analysierte Dokument enthält \(present) der \(alphabetSize) Zeichen des eingestellten Alphabets."
                : "Das analysierte Dokument enthält alle \(alphabetSize) Zeichen des eingestellten Alphabets."
        } else {
            info = present < alphabetSize
                ? "Das analysierte Dokument enthält \(present) unterschiedliche Bytes von \(alphabetSize) möglichen."
                : "Das analysierte Dokument enthält alle \(alphabetSize) möglichen Bytes."
        }
        info += "\n\nSeine Entropie beträgt \(CT1Format.double(entropy, decimals: 2))\n(maximal mögliche Entropie \(CT1Format.double(log2(Double(max(alphabetSize, 1))), decimals: 2)))."
        Alerts.info(info, title: "Entropie <\(document.shortName)>")
    }

    // MARK: N-Gramm

    /// Analyse ▸ Werkzeuge ▸ N-Gramm (CT1 IDD_NGRAM_ANALYSIS, "N-Gramm-Liste von %s").
    static func openNGram(document: CTDocument) {
        toolWindow(id: nil, title: "N-Gramm-Liste von \(document.shortName)", size: CGSize(width: 760, height: 560)) { close in
            CT1NGramListView(document: document, binary: isBinaryView(document), close: close)
        }
    }

    // MARK: Periode

    /// Analyse ▸ Werkzeuge ▸ Periode (CT1 IDD_PERIODICITY_ANALYSIS).
    static func openPeriodicity(document: CTDocument) {
        let bytes = document.bytes
        guard bytes.count >= 4 else {
            Alerts.error("Die zu analysierende Datei muss mindestens 4 Bytes groß sein!")
            return
        }
        let results = Statistics.periodicity(bytes)
        guard !results.isEmpty else {
            Alerts.info("Keine Periodizität gefunden.")
            return
        }
        toolWindow(id: nil, title: "Ausgabe der gefundenen Perioden", size: CGSize(width: 860, height: 520)) { close in
            CT1PeriodicityView(document: document, results: results, close: close)
        }
    }

    // MARK: Zufallstests

    /// Analyse ▸ Zufallsanalyse ▸ Frequency-Test.
    static func openFrequencyTest(document: CTDocument) {
        guard checkRandomTestSize(document) else { return }
        if document.bytes.count * 8 < 10_000 {
            Alerts.info("Für den Frequency-Test wird eine Dateigröße von mindestens 1250 Bytes empfohlen.")
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
        toolWindow(id: nil, title: "Runs-Tests von \(document.shortName)", size: CGSize(width: 520, height: 600)) { close in
            CT1RunsTestView(document: document, close: close)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ FIPS-PUB-140-1 Testbatterie.
    static func openFIPSTest(document: CTDocument) {
        let n = document.bytes.count
        guard n >= 2500 else {
            Alerts.error("Die FIPS-PUB-140-1 Testbatterie analysiert nach Spezifikation genau 2.500 Bytes.\nDie zu dem ausgewählten Fenster gehörende Datei ist nur \(CT1Format.integer(n)) Bytes groß.\nDer Test kann deshalb nicht ausgeführt werden!")
            return
        }
        if n > 2500 {
            Alerts.info("Die FIPS-PUB-140-1 Testbatterie analysiert nach Spezifikation genau 2.500 Bytes.\nDa die zu dem ausgewählten Fenster gehörende Datei größer (\(CT1Format.integer(n)) Bytes) ist,\nwerden nach OK nur die ersten 2.500 Byte der gesamten Datei getestet.")
        }
        toolWindow(id: nil, title: "FIPS-PUB-140-1 Testbatterie von \(document.shortName)", size: CGSize(width: 460, height: 500)) { close in
            CT1FIPSView(document: document, close: close)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ Vitányi.
    static func openVitanyi(document: CTDocument) {
        guard document.bytes.count >= 500 else {
            Alerts.error("Für die Vitányi-Analyse muss die Eingabedatei mindestens 500 Bytes lang sein!")
            return
        }
        WindowPresenter.tool(id: nil, title: "Vitányi-Diagramm von <\(document.shortName)>", size: CGSize(width: 640, height: 560)) {
            RandomTestView(kind: .vitanyi, document: document)
        }
    }

    /// Analyse ▸ Zufallsanalyse ▸ 3D-Visualisierung.
    static func open3DVisualization(document: CTDocument) {
        WindowPresenter.tool(id: nil, title: "3-D-Visualisierung: \(document.shortName)", size: CGSize(width: 760, height: 680)) {
            Random3DView(document: document)
        }
    }

    private static func checkRandomTestSize(_ document: CTDocument) -> Bool {
        if document.bytes.count < 16 {
            Alerts.error("Die Datei muss mindestens 16 Bytes groß sein !")
            return false
        }
        return true
    }

    private static func openRandomTest(_ kind: CT1RandomTestView.TestKind, _ document: CTDocument) {
        let title: String
        switch kind {
        case .frequency: title = "Frequency-Test von \(document.shortName)"
        case .poker: title = "Poker-Test von \(document.shortName)"
        case .serial: title = "Serial-Test (überlappend) von \(document.shortName)"
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
                GroupBox("Auswahl") {
                    VStack(alignment: .leading, spacing: 6) {
                        radio(0) { Text("Histogramm (\(counts[0]))") }
                        radio(1) { Text("Digramm (\(counts[1]))") }
                        radio(2) { Text("Trigramm (\(counts[2]))") }
                        radio(3) {
                            HStack(spacing: 2) {
                                TextField("", text: $freeN).frame(width: 30)
                                Text("-Gramm (\(counts[3]))")
                            }
                        }
                        HStack(spacing: 4) {
                            Text("Anzeige der")
                            TextField("", text: $showCount).frame(width: 50)
                        }
                        Text("häufigsten N-Gramme (erlaubte Werte: 1-5000).")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }
                Button("Textoptionen") { OptionsWindows.showTextOptions() }
                    .frame(maxWidth: .infinity)
                    .disabled(binary)
                Spacer().frame(height: 8)
                Button("Liste berechnen", action: evaluate)
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity)
                Button("Liste speichern", action: save)
                    .disabled(result == nil)
                Button("Schließen", action: close).keyboardShortcut(.cancelAction)
                Spacer()
            }
            .frame(width: 200)
            Table(rows) {
                TableColumn("Nr.") { Text(String(format: "%3d", $0.id + 1)).font(.system(.body, design: .monospaced)) }.width(45)
                TableColumn("Zeichenfolge") { Text($0.label).font(.system(.body, design: .monospaced)) }
                TableColumn("Häufigkeit in %") { Text($0.percent).font(.system(.body, design: .monospaced)) }.width(110)
                TableColumn("Häufigkeit") { Text("\($0.count)").font(.system(.body, design: .monospaced)) }.width(90)
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
            Alerts.error("Bitte geben Sie eine ganze Zahl zwischen 3 und 16 ein.")
            return
        }
        guard let cnt = Int(showCount.trimmingCharacters(in: .whitespaces)), cnt > 0, cnt <= 5000 else {
            Alerts.error("Die Anzahl der Tabelleneinträge ist auf 5.000 Zeilen beschränkt!\nBitte geben Sie eine Zahl zwischen 1 und 5.000 ein.")
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
        DocumentFactory.openResult(text: text, title: "\(method)Analyse von <\(document.shortName)>", parent: document)
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
                Text("Jede Zeile der Ausgabe unten enthält pro gefundener Periode folgende Informationen:")
                Text("- die erste Position in der Datei, wo die Periode startet (das erste Zeichen in der Datei hat den Offset-Wert 0)")
                Text("- die Länge der Periode")
                Text("- die Anzahl, wie häufig die Periode vorkommt")
                Text("- die ersten maximal 20 Bytes, mit der die Periode beginnt (ausgegeben im ASCII- und Hexformat)")
            }
            .font(.callout)
            Table(results.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                TableColumn("Nr.") { Text("\($0.id + 1)") }.width(40)
                TableColumn("Offset") { Text("\($0.r.offset + 1)") }.width(60)
                TableColumn("Länge") { Text("\($0.r.length)") }.width(60)
                TableColumn("Periodenzahl") { Text("\($0.r.repetitions)") }.width(90)
                TableColumn("Periodeninhalt") { Text(CT1Periodicity.text($0.r)).font(.system(.body, design: .monospaced)) }.width(170)
                TableColumn("Periodeninhalt (Hex)") { Text(CT1Periodicity.hex($0.r)).font(.system(.body, design: .monospaced)) }
            }
            HStack {
                Button("Liste im Hauptfenster anzeigen") {
                    let header = "Periodenanalyse von \(document.shortName):"
                    DocumentFactory.openResult(text: CT1Periodicity.listDocument(results, title: document.shortName),
                                               title: header, parent: document)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.cancelAction)
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
        switch kind { case .frequency: return "Frequency-Test"; case .poker: return "Poker-Test"; case .serial: return "Serial-Test" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Parameterwahl") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Signifikanzniveau alpha:")
                        Picker("", selection: $alpha) {
                            ForEach(CT1RandomTests.alphaLevels, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 80)
                        Spacer()
                        Text("Tupelgröße:").foregroundStyle(kind == .poker ? .primary : .secondary)
                        Picker("", selection: $tupel) {
                            ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                        }.labelsHidden().frame(width: 55).disabled(kind != .poker)
                    }
                    Toggle("Default-Offset und -Testlänge", isOn: $useDefaults)
                        .onChange(of: useDefaults) { _, on in if on { resetRange() } }
                    Toggle("Zufällige Blöcke aus der Datei verwenden", isOn: $randomBlocks)
                    HStack {
                        Text("Offset:")
                        TextField("", text: $offset).frame(width: 90)
                        Spacer()
                        Text("Testlänge:")
                        TextField("", text: $length).frame(width: 90)
                    }
                    .disabled(useDefaults)
                }
                .padding(4)
            }
            GroupBox("Teststatus") {
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
                Button("Test durchführen", action: runTest)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
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
            verdict = "Falsche Offset/Testlänge!"
            passed = false
            Alerts.error("Offset + Testlänge muss <= Dateilänge oder\nTestlänge muss nicht gleich Null sein !")
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
    @CTState private var runVerdict = "\nBitte auf die \"Tests durchführen\"\ntaste drücken !!!"
    @CTState private var runPassed: Bool?
    @CTState private var longInfo = ""
    @CTState private var longVerdict = ""
    @CTState private var longPassed: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Runs-Parameter") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Signifikanzniveau alpha:")
                        Picker("", selection: $alpha) {
                            ForEach(CT1RandomTests.alphaLevels, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 80)
                    }
                    Toggle("Default-Runs-Test-Parameter", isOn: $defaultRun)
                        .onChange(of: defaultRun) { _, on in if on { resetRuns() } }
                    Toggle("Zufällige Blöcke aus der Datei verwenden", isOn: $randomBlocks)
                    Group {
                        HStack {
                            Text("Offset:")
                            TextField("", text: $offset).frame(width: 90)
                            Spacer()
                            Text("Testlänge:")
                            TextField("", text: $length).frame(width: 90)
                        }
                        HStack {
                            Text("Run-Länge:")
                            TextField("", text: $runLength).frame(width: 60)
                        }
                    }
                    .disabled(defaultRun)
                }
                .padding(4)
            }
            GroupBox("Long-Runs-Parameter") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Default-Long-Runs-Parameter", isOn: $defaultLongRun)
                        .onChange(of: defaultLongRun) { _, on in if on { longRunLength = "34" } }
                    HStack {
                        Text("Long-Runs-Länge:")
                        TextField("", text: $longRunLength).frame(width: 70).disabled(defaultLongRun)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            GroupBox("Teststatus") {
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
                Button("Tests durchführen", action: runTests)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
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
            longVerdict = "Falsche Longrun-Länge!"
            Alerts.error("Der Paramater der maximalen Run-Länge ist zu groß gewählt !\nBitte wählen Sie die maximale Run-Länge aus dem Wertebereich [1..\(fileLength)].")
        } else {
            let r = CT1RandomTests.longRunTest(data, maxRun: defaultLongRun ? 34 : lrl)
            longPassed = r.passed
            longInfo = r.info
            longVerdict = r.passed ? "Long-Runs-Test bestanden!" : "Long-Runs-Test nicht bestanden!"
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
            runVerdict = "Falsche Offset/Testlänge!"
            Alerts.error("Offset + Testlänge muss <= Dateilänge oder\nTestlänge muss nicht gleich Null sein !")
            return
        }
        runPassed = o.passed
        runInfo = o.info
        runVerdict = o.passed ? "Runs-Test bestanden!" : "Runs-Test nicht bestanden!"
    }
}

// MARK: - FIPS-PUB-140-1 (IDD_FIPS_PUB_140_1)

struct CT1FIPSView: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var result: CT1RandomTests.FIPSResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Entropiestatus") {
                Text(result?.entropyLine ?? " ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
            GroupBox("Ergebnisse der einzelnen FIPS-PUB-140-1 Tests") {
                VStack(alignment: .leading, spacing: 10) {
                    line("Longrun Testergebnis:", result?.longRunLine, result?.longRunPassed)
                    line("Mono-Bit Testergebnis:", result?.monobitLine, result?.monobitPassed)
                    line("Poker Testergebnis:", result?.pokerLine, result?.pokerPassed)
                    line("Runs Testergebnis:", result?.runsLine, result?.runsPassed)
                }
                .padding(4)
            }
            GroupBox("Testbatterie Status") {
                line("FIPS-PUB-140-1 Testbatterie Status:", result?.batteryLine, result?.batteryPassed)
                    .padding(4)
            }
            if let r = result {
                Text("Einsen: \(r.monobitOnes) (9654 < n < 10346) · Poker: \(String(format: "%.2f", r.pokerStatistic)) (1,03 < X < 57,4) · längster Run: \(r.longestRun) (< 34)")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Testbatterie starten", action: run)
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
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
