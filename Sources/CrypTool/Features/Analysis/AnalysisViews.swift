import AppKit
import SwiftUI
import Charts
import CTCommon
import CTAnalysis

// MARK: - Histogram

struct HistogramView: View {
    let document: CTDocument
    @EnvironmentObject var settings: AppSettings
    @CTState private var byBytes = false

    struct Bar: Identifiable { let id: Int; let label: String; let percent: Double; let count: Int }

    var bars: [Bar] {
        if byBytes {
            let h = Statistics.byteHistogram(document.bytes)
            let total = Double(max(document.bytes.count, 1))
            return h.indices.map { Bar(id: $0, label: String(format: "%02X", $0), percent: Double(h[$0]) * 100 / total, count: h[$0]) }
        }
        let counts = Statistics.letterCounts(document.text, options: settings.textOptions)
        let total = Double(max(counts.map(\.count).reduce(0, +), 1))
        return counts.enumerated().map { Bar(id: $0.offset, label: String($0.element.symbol), percent: Double($0.element.count) * 100 / total, count: $0.element.count) }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("", selection: $byBytes) {
                    Text("Zeichen des Alphabets").tag(false)
                    Text("Alle Bytes (0–255)").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 320)
                Spacer()
                Button("Werte als Dokument") {
                    let t = bars.filter { $0.count > 0 }.map { "\($0.label)\t\($0.count)\t\(String(format: "%.2f", $0.percent)) %" }.joined(separator: "\n")
                    DocumentFactory.openResult(text: "Zeichen\tAnzahl\tAnteil\n" + t, title: DocumentFactory.title("Histogramm-Werte", of: document), parent: document)
                }
            }
            Chart(bars) { b in
                if settings.plotAsBars {
                    BarMark(x: .value("Zeichen", b.label), y: .value("Häufigkeit (%)", b.percent),
                            width: .ratio(min(1, 0.15 + Double(settings.plotBarWidth) * 0.08)))
                        .foregroundStyle(.blue.gradient)
                } else {
                    LineMark(x: .value("Zeichen", b.label), y: .value("Häufigkeit (%)", b.percent))
                        .lineStyle(StrokeStyle(lineWidth: CGFloat(settings.plotLineWidth)))
                }
            }
            .chartYScale(domain: .automatic(includesZero: settings.plotShowZeroLine))
            .chartYAxisLabel("Häufigkeit in %")
            .chartXAxis {
                AxisMarks(values: byBytes ? stride(from: 0, to: 256, by: 16).map { String(format: "%02X", $0) } : bars.map(\.label)) { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .onAppear { byBytes = !document.isText }
        .contextMenu {
            Button("Übergeordnetes Fenster") { document.windowControllers.first?.window?.makeKeyAndOrderFront(nil) }
        }
    }
}

// MARK: - Line chart (floating frequency, autocorrelation)

struct SeriesChartView: View {
    let title: String
    let xLabel: String
    let yLabel: String
    let values: [Double]
    var xOffset = 0
    var bars = false
    var note: String? = nil
    /// Document the plot was computed from (CT1 plot context menu "Übergeordnetes Fenster").
    var parent: CTDocument? = nil
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let asBars = bars && settings.plotAsBars
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if let note { Text(note).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Chart {
                ForEach(values.indices, id: \.self) { i in
                    if asBars {
                        BarMark(x: .value(xLabel, i + xOffset), y: .value(yLabel, values[i]),
                                width: .fixed(CGFloat(max(1, settings.plotBarWidth))))
                    } else {
                        LineMark(x: .value(xLabel, i + xOffset), y: .value(yLabel, values[i]))
                            .lineStyle(StrokeStyle(lineWidth: CGFloat(settings.plotLineWidth)))
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: settings.plotShowZeroLine))
            .chartXAxisLabel(xLabel)
            .chartYAxisLabel(yLabel)
        }
        .padding()
        .contextMenu {
            Button("Übergeordnetes Fenster") { parent?.windowControllers.first?.window?.makeKeyAndOrderFront(nil) }
                .disabled(parent == nil)
        }
    }
}

// MARK: - N-grams

struct NGramView: View {
    let document: CTDocument
    @EnvironmentObject var settings: AppSettings
    @CTState private var n = 2
    @CTState private var limit = 100
    @CTState private var onlyAlphabet = true
    @CTState private var entries: [Statistics.NGramEntry] = []

    struct Row: Identifiable { let id: Int; let e: Statistics.NGramEntry }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("", selection: $n) {
                    Text("Histogramm (1)").tag(1); Text("Digramm (2)").tag(2); Text("Trigramm (3)").tag(3); Text("4-Gramm").tag(4)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 420)
                Toggle("nur Alphabet-Zeichen", isOn: $onlyAlphabet)
                Stepper("Anzeigen: \(limit)", value: $limit, in: 10...5000, step: 10)
            }
            Table(entries.enumerated().map { Row(id: $0.offset, e: $0.element) }) {
                TableColumn("Nr.") { Text("\($0.id + 1)") }.width(40)
                TableColumn("\(n)-Gramm") { Text($0.e.gram).font(.system(.body, design: .monospaced)) }
                TableColumn("Häufigkeit") { Text("\($0.e.count)") }.width(90)
                TableColumn("Anteil (%)") { Text(String(format: "%.3f", $0.e.percent)) }.width(90)
            }
            HStack {
                Spacer()
                Button("Liste als Dokument") {
                    let t = entries.enumerated().map { "\($0.offset + 1)\t\($0.element.gram)\t\($0.element.count)\t\(String(format: "%.4f", $0.element.percent))" }.joined(separator: "\n")
                    DocumentFactory.openResult(text: "Nr.\t\(n)-Gramm\tHäufigkeit\tAnteil (%)\n" + t, title: DocumentFactory.title("\(n)-Gramm-Analyse", of: document), parent: document)
                }
            }
        }
        .padding()
        .onAppear(perform: compute)
        .onChange(of: n) { _, _ in compute() }
        .onChange(of: limit) { _, _ in compute() }
        .onChange(of: onlyAlphabet) { _, _ in compute() }
    }

    private func compute() {
        entries = onlyAlphabet && document.isText
            ? Statistics.ngrams(document.text, n: n, options: settings.textOptions, limit: limit)
            : Statistics.byteNGrams(document.bytes, n: n, limit: limit)
    }
}

// MARK: - Periodicity

struct PeriodicityView: View {
    let document: CTDocument
    @CTState private var results: [Statistics.PeriodResult] = []
    struct Row: Identifiable { let id: Int; let r: Statistics.PeriodResult }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Gefundene Perioden in <\(document.shortName)>").font(.headline)
            if results.isEmpty {
                Text("Es wurde keine Periode gefunden.").foregroundStyle(.secondary)
            } else {
                Table(results.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                    TableColumn("Offset") { Text("\($0.r.offset + 1)") }.width(70)
                    TableColumn("Periodenlänge") { Text("\($0.r.length)") }.width(110)
                    TableColumn("Wiederholungen") { Text("\($0.r.repetitions)") }.width(120)
                    TableColumn("Muster") { Text(PeriodicityView.describe($0.r.pattern)).font(.system(.body, design: .monospaced)) }
                }
            }
        }
        .padding()
        .onAppear { results = Statistics.periodicity(document.bytes) }
    }

    static func describe(_ b: [UInt8]) -> String {
        let text = String(b.prefix(48).map { $0 >= 0x20 && $0 < 0x7F ? Character(UnicodeScalar($0)) : "·" })
        return text + "   [" + Hex.encode(b.prefix(16)) + (b.count > 16 ? " …" : "") + "]"
    }
}

// MARK: - Random tests

struct RandomTestView: View {
    enum Kind: String { case frequency, poker, runs, serial, fips, vitanyi }
    let kind: Kind
    let document: CTDocument
    @CTState private var alpha = 0.05
    @CTState private var pokerM = 3
    @CTState private var runLength = 3
    @CTState private var results: [RandomnessTests.TestResult] = []
    @CTState private var vitanyi: RandomnessTests.VitanyiResult?

    var title: String {
        switch kind {
        case .frequency: return "Frequency-Test"
        case .poker: return "Poker-Test"
        case .runs: return "Runs-Test"
        case .serial: return "Serial-Test"
        case .fips: return "FIPS PUB 140-1 Testbatterie"
        case .vitanyi: return "Vitányi"
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Daten: <\(document.shortName)>, \(document.bytes.count) Bytes = \(document.bytes.count * 8) Bit").foregroundStyle(.secondary)
                if kind != .fips && kind != .vitanyi {
                    Picker("Signifikanzniveau α", selection: $alpha) {
                        Text("0,10").tag(0.10); Text("0,05").tag(0.05); Text("0,01").tag(0.01); Text("0,001").tag(0.001)
                    }
                }
                if kind == .poker { Stepper("Tupellänge m: \(pokerM)", value: $pokerM, in: 2...8) }
                if kind == .runs { Stepper("Maximale Lauflänge: \(runLength)", value: $runLength, in: 1...10) }
                if kind == .vitanyi {
                    Text("Dreieckeverfahren: Die ersten 8 KB werden als Punkte (Paare von 32-Bit-Wörtern) aufgefasst; aufgetragen wird die normierte kleinste Dreiecksfläche, die je drei der bisherigen Punkte bilden (Heilbronn-Problem). Bei Zufallsdaten schwankt die Kurve um 1; strukturierte Daten weichen deutlich ab.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack { Spacer(); Button("Test durchführen", action: run).keyboardShortcut(.defaultAction) }
            } header: { Text(title) }
            if let v = vitanyi {
                Section("Vitányi-Diagramm") {
                    Chart {
                        ForEach(v.series.indices, id: \.self) { i in
                            LineMark(x: .value("Eckpunkte", i + v.firstPoint), y: .value("Wert", v.series[i]))
                        }
                        RuleMark(y: .value("Durchschnitt", 1)).foregroundStyle(.secondary)
                    }
                    .chartXAxisLabel("Eckpunkte")
                    .frame(height: 220)
                    LabeledContent("Ausgewertete Punkte", value: "\(v.pointCount)")
                    LabeledContent("Durchschnitt", value: String(format: "%.4f", v.mean))
                    LabeledContent("Variation", value: String(format: "%.4f", v.variation))
                    if v.degenerate {
                        Label("Drei (nahezu) kollineare Punkte gefunden – deutliches Zeichen für nicht zufällige Daten.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            if !results.isEmpty {
                Section("Ergebnis") {
                    ForEach(results.indices, id: \.self) { i in
                        let r = results[i]
                        VStack(alignment: .leading, spacing: 4) {
                            Label(r.name + (r.passed ? " – bestanden" : " – nicht bestanden"),
                                  systemImage: r.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(r.passed ? .green : .red).font(.headline)
                            Text(String(format: "Teststatistik: %.4f    Schwellwert: %.4f", r.statistic, r.threshold)).font(.system(.body, design: .monospaced))
                            if !r.details.isEmpty { Text(r.details).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: run)
    }

    private func run() {
        let b = document.bytes
        switch kind {
        case .frequency: results = [RandomnessTests.frequencyTest(b, alpha: alpha)]
        case .poker: results = [RandomnessTests.pokerTest(b, m: pokerM, alpha: alpha)]
        case .runs: results = [RandomnessTests.runsTest(b, alpha: alpha, maxRunLength: runLength)]
        case .serial: results = [RandomnessTests.serialTest(b, alpha: alpha)]
        case .fips: results = RandomnessTests.fips140_1(b)
        case .vitanyi: vitanyi = RandomnessTests.vitanyi(b)
        }
    }
}
