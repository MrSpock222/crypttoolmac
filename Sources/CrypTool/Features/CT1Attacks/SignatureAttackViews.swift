import AppKit
import SwiftUI
import CTCommon
import CTModern

/// Persistent options of the signature attack (CT1 registry values).
@MainActor
final class SignatureAttackSettings: ObservableObject {
    static let shared = SignatureAttackSettings()
    @Published var options: SignatureAttack.Options = .standard
    @Published var harmlessPath = ""
    @Published var dangerousPath = ""
}

@MainActor
enum SignatureAttackWindows {
    static func openAttack() {
        WindowPresenter.tool(id: "sigattack", title: "Angriff auf den Hashwert der digitalen Signatur",
                             size: CGSize(width: 620, height: 640), resizable: false) {
            SignatureAttackView()
        }
    }

    static func openModificationDemo(document: CTDocument?) {
        WindowPresenter.tool(id: "sigattmodific", title: "Nachrichtenmodifikation durch einen Hashwert",
                             size: CGSize(width: 560, height: 420), resizable: false) {
            ModificationDemoView(document: document)
        }
    }

    static func hashTitle(_ hash: [UInt8], bits: Int) -> String {
        let full = Array(hash.prefix(bits / 8))
        return Hex.encode(full) + (bits % 8 != 0 ? " ..." : "")
    }
}

@MainActor
final class SignatureAttackModel: ObservableObject {
    @Published var running = false
    @Published var progress = 0.0
    @Published var result: SignatureAttack.Result?
    private var token = CancellationToken()

    func start(harmless: [UInt8], dangerous: [UInt8], options: SignatureAttack.Options,
               names: (String, String), onDone: @escaping (SignatureAttack.Result) -> Void, onError: @escaping (String) -> Void) {
        token = CancellationToken()
        let t = token
        running = true
        progress = 0
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let r = try SignatureAttack.run(harmless: harmless, dangerous: dangerous, options: options, cancel: t) { p in
                    Task { @MainActor in self.progress = p }
                }
                await MainActor.run { self.running = false; self.result = r; onDone(r) }
            } catch {
                await MainActor.run { self.running = false; onError(error.localizedDescription) }
            }
        }
    }

    func cancel() { token.cancel() }
}

struct SignatureAttackView: View {
    @ObservedObject private var settings = SignatureAttackSettings.shared
    @StateObject private var model = SignatureAttackModel()
    @CTState private var showOptions = false
    @CTState private var showStatistics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Der hier implementierte Angriff auf die digitale Signatur beruht auf dem Versuch, zwei verschiedene Nachrichten mit gleichem Hashwert zu finden.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Default-Nachrichten benutzen", action: useDefaults).frame(maxWidth: .infinity)
            GroupBox("\"Harmlose\" Datei auswählen") {
                fileRow(path: $settings.harmlessPath,
                        text: "Die \"harmlose\" Datei ist eine Nachricht, von der der Angreifer vermutet, dass der Unterzeichner sie digital signieren wird.")
            }
            GroupBox("\"Gefährliche\" Datei auswählen") {
                fileRow(path: $settings.dangerousPath,
                        text: "Die \"gefährliche\" Datei ist eine Nachricht, von der der Angreifer nach erfolgreichem Angriff behaupten wird: \"Diese Nachricht wurde vom Unterzeichner digital signiert.\"")
            }
            GroupBox("Suche starten / Optionen festlegen") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mit \"Nachrichtenpaar suchen\" starten Sie den Versuch, zu den oben eingestellten Nachrichten zwei Modifikationen zu finden, die denselben Hashwert haben.")
                    Text("Der Sinn (Semantik) der Nachrichten ändert sich während der Suche nicht, da zum Modifizieren nicht darstellbare bzw. Formatierungszeichen verwendet werden.")
                    Text("Unter \"Optionen\" können Sie das Hashverfahren, die Anzahl der für den Vergleich der Hashwerte herangezogenen Bits sowie verschiedene Modifikationsverfahren auswählen.")
                    Text("Aktuell: \(settings.options.hash.displayName), \(settings.options.significantBits) signifikante Bits, \(methodDescription(settings.options.method))")
                        .font(.callout).foregroundStyle(.secondary)
                    if model.running {
                        ProgressView(value: model.progress) { Text("Suche läuft …") }
                    }
                }
                .font(.callout).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                if model.running {
                    Button("Abbrechen") { model.cancel() }
                } else {
                    Button("Nachrichtenpaar suchen", action: start).keyboardShortcut(.defaultAction)
                }
                Button("Optionen …") { showOptions = true }.disabled(model.running)
                Button("Modifikations-Demo …") {
                    SignatureAttackWindows.openModificationDemo(document: NSDocumentController.shared.currentDocument as? CTDocument)
                }
                Spacer()
                Button("Dialog beenden") { model.cancel(); closeKeyWindow() }
            }
        }
        .padding(16)
        .sheet(isPresented: $showOptions) { SignatureAttackOptionsView(close: { showOptions = false }) }
        .sheet(isPresented: $showStatistics) {
            if let r = model.result { SignatureAttackStatisticsView(result: r, options: settings.options, close: { showStatistics = false }) }
        }
        .onAppear { if settings.harmlessPath.isEmpty { useDefaults() } }
    }

    private func fileRow(path: Binding<String>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("", text: path).font(.system(.body, design: .monospaced))
                Button("Suchen …") {
                    let p = NSOpenPanel()
                    if p.runModal() == .OK, let u = p.url { path.wrappedValue = u.path }
                }
            }
        }.padding(4)
    }

    private func useDefaults() {
        settings.harmlessPath = Resources.url("Examples/Original.txt")?.path ?? ""
        settings.dangerousPath = Resources.url("Examples/Faelschung.txt")?.path ?? ""
    }

    private func methodDescription(_ m: SignatureAttack.Method) -> String {
        switch m {
        case let .blanks(le, db):
            return "Leerzeichen einfügen (" + [le ? "vor Zeilenende" : nil, db ? "Leerzeichenverdoppelung" : nil].compactMap { $0 }.joined(separator: ", ") + ")"
        case let .attachments(printable):
            return "Zeichen anhängen (" + (printable ? "druckbare Zeichen" : "nicht druckbare Zeichen") + ")"
        }
    }

    private func start() {
        guard let h = FileManager.default.contents(atPath: settings.harmlessPath),
              let d = FileManager.default.contents(atPath: settings.dangerousPath) else {
            Alerts.error("Bitte eine harmlose und eine gefährliche Datei auswählen.")
            return
        }
        let opts = settings.options
        let names = ((settings.harmlessPath as NSString).lastPathComponent, (settings.dangerousPath as NSString).lastPathComponent)
        model.start(harmless: [UInt8](h), dangerous: [UInt8](d), options: opts, names: names, onDone: { r in
            if r.cancelled { return }
            if r.success {
                let hv = SignatureAttackWindows.hashTitle(r.harmlessHash, bits: opts.significantBits)
                DocumentFactory.openResult(r.harmless, title: "Harmlose Nachricht: \(opts.hash.displayName), <\(hv)>", key: Hex.encode(r.harmlessHash))
                DocumentFactory.openResult(r.dangerous, title: "Gefährliche Nachricht: \(opts.hash.displayName), <\(hv)>", key: Hex.encode(r.dangerousHash))
                Alerts.info("Der Angriff war erfolgreich: Es wurden zwei Nachrichten gefunden, deren Hashwert innerhalb der ersten \(opts.significantBits) Bits identisch ist.")
            } else {
                Alerts.info("Der Angriff schlug fehl: Es konnte kein Nachrichtenpaar gefunden werden.")
            }
            showStatistics = true
        }, onError: { Alerts.error($0) })
    }
}

/// CT1 "Optionen für den Angriff auf den Hashwert der digitalen Signatur".
struct SignatureAttackOptionsView: View {
    let close: () -> Void
    @ObservedObject private var settings = SignatureAttackSettings.shared
    @CTState private var hash: HashAlgorithm = .md2
    @CTState private var bits = 16
    @CTState private var blanks = true
    @CTState private var beforeLineEnd = true
    @CTState private var doubleBlanks = true
    @CTState private var printable = true

    var body: some View {
        DialogScaffold(title: "Optionen für den Angriff auf den Hashwert der digitalen Signatur", minWidth: 520) {
            GroupBox("Hashfunktion") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wählen Sie eines der sechs Hashverfahren sowie die Anzahl der Bits, die für den Vergleich der Hashwerte herangezogen werden sollen.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Picker("", selection: $hash) {
                        ForEach(SignatureAttack.Options.hashes, id: \.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    HStack {
                        Text("Signifikante Bitlänge")
                        TextField("", value: $bits, format: .number).frame(width: 50)
                        Text("(1 … \(hash.digestLength * 8))").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Optionen für die Nachrichtenmodifikation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entscheiden Sie, nach welchem Verfahren die Nachrichten modifiziert werden sollen.").font(.callout)
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                        GridRow {
                            Toggle("Leerzeichen einfügen", isOn: Binding(get: { blanks }, set: { if $0 { blanks = true } })).toggleStyle(.radioLike)
                            VStack(alignment: .leading) {
                                Toggle("Vor Zeilenende", isOn: $beforeLineEnd)
                                Toggle("Leerzeichenverdoppelung", isOn: $doubleBlanks)
                            }.disabled(!blanks)
                        }
                        GridRow {
                            Toggle("Zeichen anhängen", isOn: Binding(get: { !blanks }, set: { if $0 { blanks = false } })).toggleStyle(.radioLike)
                            Picker("", selection: $printable) {
                                Text("Druckbare Zeichen (zur Demonstration)").tag(true)
                                Text("Nicht druckbare Zeichen").tag(false)
                            }.pickerStyle(.radioGroup).labelsHidden().disabled(blanks)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } buttons: {
            Button("Standard wiederherstellen") { load(.standard) }
            Spacer()
            Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            Button("Übernehmen") {
                let maxBits = hash.digestLength * 8
                settings.options = SignatureAttack.Options(
                    hash: hash, significantBits: min(max(1, bits), maxBits),
                    method: blanks ? .blanks(beforeLineEnd: beforeLineEnd, doubleBlanks: doubleBlanks) : .attachments(printable: printable))
                close()
            }.keyboardShortcut(.defaultAction)
        }
        .onAppear { load(settings.options) }
    }

    private func load(_ o: SignatureAttack.Options) {
        hash = o.hash
        bits = o.significantBits
        switch o.method {
        case let .blanks(le, db): blanks = true; beforeLineEnd = le; doubleBlanks = db
        case let .attachments(p): blanks = false; printable = p
        }
    }
}

/// Radio-button look for a Toggle (used for the two exclusive modification methods).
struct RadioLikeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                configuration.label
            }
        }.buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == RadioLikeToggleStyle {
    static var radioLike: RadioLikeToggleStyle { RadioLikeToggleStyle() }
}

/// CT1 "Statistische Auswertung des Angriffs".
struct SignatureAttackStatisticsView: View {
    let result: SignatureAttack.Result
    let options: SignatureAttack.Options
    let close: () -> Void

    struct Row: Identifiable { let id: Int; let r: SignatureAttack.RunStatistics }

    var body: some View {
        DialogScaffold(title: "Statistische Auswertung des Angriffs", minWidth: 560) {
            GroupBox("Abschätzung des Aufwands zum Finden eines Nachrichtenpaares") {
                VStack(alignment: .leading) {
                    LabeledContent("Rechenzeit", value: SignatureAttackStatisticsView.time(result.expectedSeconds))
                    LabeledContent("Benötigte Schritte", value: "\(result.expectedSteps)")
                }.padding(4)
            }
            GroupBox("Tatsächlich geleisteter Aufwand") {
                VStack(alignment: .leading) {
                    LabeledContent("Rechenzeit", value: SignatureAttackStatisticsView.time(result.elapsed))
                    LabeledContent("Benötigte Schritte", value: "\(result.totalSteps)")
                    LabeledContent("Ausgeführte Hash-Operationen", value: "\(result.hashOperations)")
                    Text("Aufschlüsselung der Einzelschritte").font(.callout).padding(.top, 4)
                    Table(result.runs.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                        TableColumn("Durchlauf") { Text("\($0.r.run)") }.width(70)
                        TableColumn("Kollisionssuche") { Text("\($0.r.collisionSteps)") }.width(110)
                        TableColumn("Bestätigung") { Text("\($0.r.confirmationSteps)") }.width(90)
                        TableColumn("Ergebnis") { Text($0.r.outcome) }
                    }.frame(height: 130)
                }.padding(4)
            }
            GroupBox("Hinzugefügte Bytes") {
                VStack(alignment: .leading) {
                    Text("Harmlose Nachricht: \(result.addedBytesHarmless) Bytes")
                    Text("Gefährliche Nachricht: \(result.addedBytesDangerous) Bytes")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } buttons: {
            Button("Statistik ausgeben") {
                DocumentFactory.openResult(text: report, title: "Statistik des Angriffs")
            }
            Spacer()
            Button("Dialog beenden", action: close).keyboardShortcut(.defaultAction)
        }
    }

    static func time(_ s: Double) -> String {
        if s < 1 { return String(format: "%.0f ms", s * 1000) }
        if s < 120 { return String(format: "%.1f s", s) }
        if s < 7200 { return String(format: "%.1f min", s / 60) }
        if s < 172_800 { return String(format: "%.1f h", s / 3600) }
        return String(format: "%.1f Tage", s / 86_400)
    }

    private var report: String {
        let s = SignatureAttackSettings.shared
        var t = "Partielle \(options.hash.displayName)-Kollisionssuche\n\n"
        t += "Dateiname Original: \(s.harmlessPath)\n"
        t += "Dateiname Fälschung: \(s.dangerousPath)\n"
        t += "Signifikante Bitlänge: \(options.significantBits)\n\n"
        t += "Erwartete Schritte: \(result.expectedSteps)\nErwartete Rechenzeit: \(SignatureAttackStatisticsView.time(result.expectedSeconds))\n\n"
        t += "Benötigte Schritte: \(result.totalSteps)\nRechenzeit: \(SignatureAttackStatisticsView.time(result.elapsed))\n"
        t += "Ausgeführte Hash-Operationen: \(result.hashOperations)\n\n"
        for r in result.runs {
            t += "Durchlauf \(r.run): Kollisionssuche \(r.collisionSteps) Schritte, Bestätigung \(r.confirmationSteps) Schritte – \(r.outcome)\n"
        }
        if result.success {
            t += "\nHashwert harmlose Nachricht:   \(Hex.encode(result.harmlessHash))\n"
            t += "Hashwert gefährliche Nachricht: \(Hex.encode(result.dangerousHash))\n"
        }
        return t
    }
}

/// CT1 "Nachrichtenmodifikation durch einen Hashwert" (DlgSigAttModificDemo).
struct ModificationDemoView: View {
    let document: CTDocument?
    @CTState private var hashHex = "A3 5F"
    @CTState private var bits = 16
    @CTState private var blanks = true
    @CTState private var beforeLineEnd = true
    @CTState private var doubleBlanks = true
    @CTState private var printable = true
    @CTState private var run = 1

    private var value: [UInt8]? { Hex.decode(hashHex) }
    private var parityText: String {
        guard let v = value, v.count * 8 >= bits, bits > 0 else { return "–" }
        return "\(SignatureAttack.parity(v, bits: bits))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Hashwert") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Hashwert").frame(width: 110, alignment: .leading); TextField("", text: $hashHex).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text("Signifikante Bitlänge").frame(width: 110, alignment: .leading)
                        TextField("", value: $bits, format: .number).frame(width: 50)
                        Spacer()
                        Text("Parität des Hashwerts"); Text(parityText).font(.system(.body, design: .monospaced)).frame(width: 30)
                    }
                }.padding(4)
            }
            GroupBox("Optionen für die Nachrichtenmodifikation") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Toggle("Leerzeichen einfügen", isOn: Binding(get: { blanks }, set: { if $0 { blanks = true } })).toggleStyle(.radioLike)
                        VStack(alignment: .leading) {
                            Toggle("Vor Zeilenende", isOn: $beforeLineEnd)
                            Toggle("Leerzeichenverdoppelung", isOn: $doubleBlanks)
                        }.disabled(!blanks)
                    }
                    GridRow {
                        Toggle("Zeichen anhängen", isOn: Binding(get: { !blanks }, set: { if $0 { blanks = false } })).toggleStyle(.radioLike)
                        VStack(alignment: .leading) {
                            Picker("", selection: $printable) {
                                Text("Druckbare Zeichen (zur Demonstration)").tag(true)
                                Text("Nicht druckbare Zeichen").tag(false)
                            }.pickerStyle(.radioGroup).labelsHidden()
                            Picker("Run", selection: $run) {
                                ForEach(1...16, id: \.self) { Text(String(format: "%02d.", $0)).tag($0) }
                            }.frame(width: 120)
                        }.disabled(blanks)
                    }
                }.padding(4)
            }
            Text(document.map { "Dokument: <\($0.shortName)>" } ?? "Kein Dokument geöffnet – bitte zuerst ein Dokument öffnen.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Button("Modifikation berechnen", action: compute).keyboardShortcut(.defaultAction).disabled(document == nil)
                Spacer()
                Button("Abbrechen", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
    }

    private func compute() {
        guard let doc = document, let v = value, bits >= 1, v.count * 8 >= bits else {
            Alerts.error("Der Hashwert muss mindestens so viele Bits enthalten wie die signifikante Bitlänge.")
            return
        }
        do {
            let m = try SignatureAttack.modify(doc.bytes, value: v, bits: bits,
                                               method: blanks ? .blanks(beforeLineEnd: beforeLineEnd, doubleBlanks: doubleBlanks) : .attachments(printable: printable),
                                               run: run - 1)
            DocumentFactory.openResult(m, title: "Modifikation von <\(doc.shortName)>", parent: doc, key: Hex.encode(v))
        } catch { Alerts.error(error.localizedDescription) }
    }
}
