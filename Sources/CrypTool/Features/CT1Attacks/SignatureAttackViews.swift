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
        WindowPresenter.tool(id: "sigattack", title: "Attack on the Hash Value of the Digital Signature",
                             size: CGSize(width: 620, height: 640), resizable: false) {
            SignatureAttackView()
        }
    }

    static func openModificationDemo(document: CTDocument?) {
        WindowPresenter.tool(id: "sigattmodific", title: "Modification of as Message by a Hash Value",
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
            Text("This attack attempts to find two different messages that hash to the same value.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Use default messages", action: useDefaults).frame(maxWidth: .infinity)
            GroupBox("Choose \"harmless\" file") {
                fileRow(path: $settings.harmlessPath,
                        text: "The attacker assumes that his victim will digitally sign the \"harmless\" message due to its non-malicious content.")
            }
            GroupBox("Choose \"dangerous\" file") {
                fileRow(path: $settings.dangerousPath,
                        text: "If the attack is successful, the attacker can argue that the victim has digitally signed the \"dangerous\" instead of the \"harmless\" message.")
            }
            GroupBox("Start search / Set options") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Click \"Start search\" to initiate the attack. The program will search for modifications of the two messages that hash to the same value.")
                    Text("The message will not appear to change, since only unprintable characters will be used to modify them.")
                    Text("In the \"Options\" you can select the hash function, the required minimum number of matching bits, and the message modification method.")
                    Text("Current: \(settings.options.hash.displayName), \(settings.options.significantBits) significant bits, \(methodDescription(settings.options.method))")
                        .font(.callout).foregroundStyle(.secondary)
                    if model.running {
                        ProgressView(value: model.progress) { Text("Searching for a pair of messages ...") }
                    }
                }
                .font(.callout).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                if model.running {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button("Start search", action: start).keyboardShortcut(.defaultAction)
                }
                Button("Options ...") { showOptions = true }.disabled(model.running)
                Button("Modification demo ...") {
                    SignatureAttackWindows.openModificationDemo(document: NSDocumentController.shared.currentDocument as? CTDocument)
                }
                Spacer()
                Button("Cancel") { model.cancel(); closeKeyWindow() }
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
                Button("Search...") {
                    let p = NSOpenPanel()
                    if p.runModal() == .OK, let u = p.url { path.wrappedValue = u.path }
                }
            }
        }.padding(4)
    }

    private func useDefaults() {
        settings.harmlessPath = Resources.url("Examples/original.txt")?.path ?? ""
        settings.dangerousPath = Resources.url("Examples/fake.txt")?.path ?? ""
    }

    private func methodDescription(_ m: SignatureAttack.Method) -> String {
        switch m {
        case let .blanks(le, db):
            return "Insert blanks (" + [le ? "in front of end of line" : nil, db ? "double blanks" : nil].compactMap { $0 }.joined(separator: ", ") + ")"
        case let .attachments(printable):
            return "Attach characters (" + (printable ? "printable characters" : "unprintable characters") + ")"
        }
    }

    private func start() {
        guard let h = FileManager.default.contents(atPath: settings.harmlessPath),
              let d = FileManager.default.contents(atPath: settings.dangerousPath) else {
            Alerts.error("Please select a harmless and a dangerous file.")
            return
        }
        let opts = settings.options
        let names = ((settings.harmlessPath as NSString).lastPathComponent, (settings.dangerousPath as NSString).lastPathComponent)
        model.start(harmless: [UInt8](h), dangerous: [UInt8](d), options: opts, names: names, onDone: { r in
            if r.cancelled { return }
            if r.success {
                let hv = SignatureAttackWindows.hashTitle(r.harmlessHash, bits: opts.significantBits)
                DocumentFactory.openResult(r.harmless, title: "Harmless message: \(opts.hash.displayName), <\(hv)>", key: Hex.encode(r.harmlessHash))
                DocumentFactory.openResult(r.dangerous, title: "Dangerous message: \(opts.hash.displayName), <\(hv)>", key: Hex.encode(r.dangerousHash))
                Alerts.info("The attack was successful: Two different messages were found where the message hash is equal for the first \(opts.significantBits) bits.")
            } else {
                Alerts.info("The attack failed: no pair of messages could be found.")
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
        DialogScaffold(title: "Options for the Attack on the Hash Value of the Digital Signature", minWidth: 520) {
            GroupBox("Hash function") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose a hash function and the minimum required number of matching bits for the attack to be considered successful.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Picker("", selection: $hash) {
                        ForEach(SignatureAttack.Options.hashes, id: \.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                    HStack {
                        Text("Significant bit length")
                        TextField("", value: $bits, format: .number).frame(width: 50)
                        Text("(1 … \(hash.digestLength * 8))").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Options for the modification of messages") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Determine the way messages are modified throughout the attack.").font(.callout)
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                        GridRow {
                            Toggle("Insert blanks", isOn: Binding(get: { blanks }, set: { if $0 { blanks = true } })).toggleStyle(.radioLike)
                            VStack(alignment: .leading) {
                                Toggle("In front of end of line", isOn: $beforeLineEnd)
                                Toggle("Double blanks", isOn: $doubleBlanks)
                            }.disabled(!blanks)
                        }
                        GridRow {
                            Toggle("Attach characters", isOn: Binding(get: { !blanks }, set: { if $0 { blanks = false } })).toggleStyle(.radioLike)
                            Picker("", selection: $printable) {
                                Text("Printable characters (demonstration)").tag(true)
                                Text("Unprintable characters").tag(false)
                            }.pickerStyle(.radioGroup).labelsHidden().disabled(blanks)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } buttons: {
            Button("Restore defaults") { load(.standard) }
            Spacer()
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Apply") {
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
        DialogScaffold(title: "Statistics of the Attack", minWidth: 560) {
            GroupBox("Assumed efforts") {
                VStack(alignment: .leading) {
                    LabeledContent("Calculation time", value: SignatureAttackStatisticsView.time(result.expectedSeconds))
                    LabeledContent("Steps required", value: "\(result.expectedSteps)")
                }.padding(4)
            }
            GroupBox("Efforts made to find a pair of messages") {
                VStack(alignment: .leading) {
                    LabeledContent("Calculation time", value: SignatureAttackStatisticsView.time(result.elapsed))
                    LabeledContent("Steps required", value: "\(result.totalSteps)")
                    LabeledContent("Hash operations performed", value: "\(result.hashOperations)")
                    Text("Steps required sorted by run").font(.callout).padding(.top, 4)
                    Table(result.runs.enumerated().map { Row(id: $0.offset, r: $0.element) }) {
                        TableColumn("Run No.") { Text("\($0.r.run)") }.width(70)
                        TableColumn("Steps until collision") { Text("\($0.r.collisionSteps)") }.width(110)
                        TableColumn("Collision check") { Text("\($0.r.confirmationSteps)") }.width(90)
                        TableColumn("Result") { Text($0.r.outcome) }
                    }.frame(height: 130)
                }.padding(4)
            }
            GroupBox("Additional bytes") {
                VStack(alignment: .leading) {
                    Text("\(result.addedBytesHarmless) bytes were added to the harmless message.")
                    Text("\(result.addedBytesDangerous) bytes were added to the dangerous message.")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
        } buttons: {
            Button("Print statistics") {
                DocumentFactory.openResult(text: report, title: "Statistics of the attack")
            }
            Spacer()
            Button("Cancel", action: close).keyboardShortcut(.defaultAction)
        }
    }

    static func time(_ s: Double) -> String {
        if s < 1 { return String(format: "%.0f ms", s * 1000) }
        if s < 120 { return String(format: "%.1f s", s) }
        if s < 7200 { return String(format: "%.1f min", s / 60) }
        if s < 172_800 { return String(format: "%.1f h", s / 3600) }
        return String(format: "%.1f days", s / 86_400)
    }

    private var report: String {
        let s = SignatureAttackSettings.shared
        var t = "Partial \(options.hash.displayName)-Collision Search\n\n"
        t += "Filename original: \(s.harmlessPath)\n"
        t += "Filename fake: \(s.dangerousPath)\n"
        t += "Significant bit length: \(options.significantBits)\n\n"
        t += "Expected steps: \(result.expectedSteps)\nExpected calculating time: \(SignatureAttackStatisticsView.time(result.expectedSeconds))\n\n"
        t += "Steps required: \(result.totalSteps)\nCalculating time: \(SignatureAttackStatisticsView.time(result.elapsed))\n"
        t += "Hash operations performed: \(result.hashOperations)\n\n"
        for r in result.runs {
            t += "Run \(r.run): collision search \(r.collisionSteps) steps, collision check \(r.confirmationSteps) steps – \(r.outcome)\n"
        }
        if result.success {
            t += "\nHash value of harmless message:  \(Hex.encode(result.harmlessHash))\n"
            t += "Hash value of dangerous message: \(Hex.encode(result.dangerousHash))\n"
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
            GroupBox("Hash value") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Hash value").frame(width: 110, alignment: .leading); TextField("", text: $hashHex).font(.system(.body, design: .monospaced)) }
                    HStack {
                        Text("Significant bit length").frame(width: 110, alignment: .leading)
                        TextField("", value: $bits, format: .number).frame(width: 50)
                        Spacer()
                        Text("Parity of the hash value"); Text(parityText).font(.system(.body, design: .monospaced)).frame(width: 30)
                    }
                }.padding(4)
            }
            GroupBox("Options for the message modification") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Toggle("Insert blanks", isOn: Binding(get: { blanks }, set: { if $0 { blanks = true } })).toggleStyle(.radioLike)
                        VStack(alignment: .leading) {
                            Toggle("In front of end of line", isOn: $beforeLineEnd)
                            Toggle("Double blanks", isOn: $doubleBlanks)
                        }.disabled(!blanks)
                    }
                    GridRow {
                        Toggle("Attach characters", isOn: Binding(get: { !blanks }, set: { if $0 { blanks = false } })).toggleStyle(.radioLike)
                        VStack(alignment: .leading) {
                            Picker("", selection: $printable) {
                                Text("Printable characters (demonstration)").tag(true)
                                Text("Unprintable characters").tag(false)
                            }.pickerStyle(.radioGroup).labelsHidden()
                            Picker("Run", selection: $run) {
                                ForEach(1...16, id: \.self) { Text(String(format: "%02d.", $0)).tag($0) }
                            }.frame(width: 120)
                        }.disabled(blanks)
                    }
                }.padding(4)
            }
            Text(document.map { "Document: <\($0.shortName)>" } ?? "No document opened – please open a document first.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Button("Compute modification", action: compute).keyboardShortcut(.defaultAction).disabled(document == nil)
                Spacer()
                Button("Cancel", action: closeKeyWindow).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
    }

    private func compute() {
        guard let doc = document, let v = value, bits >= 1, v.count * 8 >= bits else {
            Alerts.error("The hash value must contain at least as many bits as the significant bit length.")
            return
        }
        do {
            let m = try SignatureAttack.modify(doc.bytes, value: v, bits: bits,
                                               method: blanks ? .blanks(beforeLineEnd: beforeLineEnd, doubleBlanks: doubleBlanks) : .attachments(printable: printable),
                                               run: run - 1)
            DocumentFactory.openResult(m, title: "Modification of <\(doc.shortName)>", parent: doc, key: Hex.encode(v))
        } catch { Alerts.error(error.localizedDescription) }
    }
}
