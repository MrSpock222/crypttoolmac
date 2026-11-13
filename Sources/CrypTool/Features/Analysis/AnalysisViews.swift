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
                    Text("Characters of the alphabet").tag(false)
                    Text("All bytes (0–255)").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 320)
                Spacer()
                Button("Values as document") {
                    let t = bars.filter { $0.count > 0 }.map { "\($0.label)\t\($0.count)\t\(String(format: "%.2f", $0.percent)) %" }.joined(separator: "\n")
                    DocumentFactory.openResult(text: "Character\tCount\tFrequency\n" + t, title: DocumentFactory.title("Histogram values", of: document), parent: document)
                }
            }
            Chart(bars) { b in
                if settings.plotAsBars {
                    BarMark(x: .value("Character", b.label), y: .value("Frequency (%)", b.percent),
                            width: .ratio(min(1, 0.15 + Double(settings.plotBarWidth) * 0.08)))
                        .foregroundStyle(.blue.gradient)
                } else {
                    LineMark(x: .value("Character", b.label), y: .value("Frequency (%)", b.percent))
                        .lineStyle(StrokeStyle(lineWidth: CGFloat(settings.plotLineWidth)))
                }
            }
            .chartYScale(domain: .automatic(includesZero: settings.plotShowZeroLine))
            .chartYAxisLabel("Frequency in %")
            .chartXAxis {
                AxisMarks(values: byBytes ? stride(from: 0, to: 256, by: 16).map { String(format: "%02X", $0) } : bars.map(\.label)) { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .onAppear { byBytes = !document.isText }
        .contextMenu {
            Button("Parent Window") { document.windowControllers.first?.window?.makeKeyAndOrderFront(nil) }
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
            Button("Parent Window") { parent?.windowControllers.first?.window?.makeKeyAndOrderFront(nil) }
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
                    Text("Histogram (1)").tag(1); Text("Digram (2)").tag(2); Text("Trigram (3)").tag(3); Text("4-gram").tag(4)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 420)
                Toggle("alphabet characters only", isOn: $onlyAlphabet)
                Stepper("Display: \(limit)", value: $limit, in: 10...5000, step: 10)
            }
            Table(entries.enumerated().map { Row(id: $0.offset, e: $0.element) }) {
                TableColumn("No.") { Text("\($0.id + 1)") }.width(40)
                TableColumn("\(n)-gram") { Text($0.e.gram).font(.system(.body, design: .monospaced)) }
                TableColumn("Frequency") { Text("\($0.e.count)") }.width(90)
                TableColumn("Frequency in %") { Text(String(format: "%.3f", $0.e.percent)) }.width(90)
            }
            HStack {
                Spacer()
                Button("List as document") {
                    let t = entries.enumerated().map { "\($0.offset + 1)\t\($0.element.gram)\t\($0.element.count)\t\(String(format: "%.4f", $0.element.percent))" }.joined(separator: "\n")
                    DocumentFactory.openResult(text: "No.\t\(n)-gram\tFrequency\tFrequency in %\n" + t, title: DocumentFactory.title("\(n) Gram Analysis", of: document), parent: document)
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
            Text("Periods found in <\(document.shortName)>").font(.headline)
            if results.isEmpty {
                Text("No periodicity found.").foregroundStyle(.secondary)
            } else {
                Table(results.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                    TableColumn("Offset") { Text("\($0.r.offset + 1)") }.width(70)
                    TableColumn("Length") { Text("\($0.r.length)") }.width(110)
                    TableColumn("Number of cycles") { Text("\($0.r.repetitions)") }.width(120)
                    TableColumn("Cycle content") { Text(PeriodicityView.describe($0.r.pattern)).font(.system(.body, design: .monospaced)) }
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
        case .frequency: return "Frequency Test"
        case .poker: return "Poker Test"
        case .runs: return "Runs Test"
        case .serial: return "Serial Test"
        case .fips: return "FIPS-PUB-140-1 Test Battery"
        case .vitanyi: return "Vitányi"
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Data: <\(document.shortName)>, \(document.bytes.count) bytes = \(document.bytes.count * 8) bits").foregroundStyle(.secondary)
                if kind != .fips && kind != .vitanyi {
                    Picker("Significance level α", selection: $alpha) {
                        Text("0.10").tag(0.10); Text("0.05").tag(0.05); Text("0.01").tag(0.01); Text("0.001").tag(0.001)
                    }
                }
                if kind == .poker { Stepper("Tuple size m: \(pokerM)", value: $pokerM, in: 2...8) }
                if kind == .runs { Stepper("Maximal run length: \(runLength)", value: $runLength, in: 1...10) }
                if kind == .vitanyi {
                    Text("Triangle method: the first 8 KB are interpreted as points (pairs of 32-bit words); the plot shows the normalized smallest area of a triangle formed by any three of the points so far (Heilbronn problem). For random data the curve fluctuates around 1; structured data deviates clearly.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack { Spacer(); Button("Execute test", action: run).keyboardShortcut(.defaultAction) }
            } header: { Text(title) }
            if let v = vitanyi {
                Section("Vitányi Diagram") {
                    Chart {
                        ForEach(v.series.indices, id: \.self) { i in
                            LineMark(x: .value("Vertices", i + v.firstPoint), y: .value("Value", v.series[i]))
                        }
                        RuleMark(y: .value("Mean", 1)).foregroundStyle(.secondary)
                    }
                    .chartXAxisLabel("Vertices")
                    .frame(height: 220)
                    LabeledContent("Evaluated points", value: "\(v.pointCount)")
                    LabeledContent("Mean", value: String(format: "%.4f", v.mean))
                    LabeledContent("Variation", value: String(format: "%.4f", v.variation))
                    if v.degenerate {
                        Label("Three (nearly) collinear points found – a clear sign of non-random data.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            if !results.isEmpty {
                Section("Result") {
                    ForEach(results.indices, id: \.self) { i in
                        let r = results[i]
                        VStack(alignment: .leading, spacing: 4) {
                            Label(r.name + (r.passed ? " – passed" : " – failed"),
                                  systemImage: r.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(r.passed ? .green : .red).font(.headline)
                            Text(String(format: "Test result: %.4f    Maximal test value: %.4f", r.statistic, r.threshold)).font(.system(.body, design: .monospaced))
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
