import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// MARK: - Shared helpers of the CT1 tool dialogs

/// Weak reference to the hosting window (for "Schließen"/"Abbrechen").
final class CT1ToolsWindowRef {
    weak var window: NSWindow?
    func close() { window?.performClose(nil) }
}

/// Gives access to the hosting NSWindow; optionally sets its title and enlarges it to a minimum
/// content size (the router opens the tool windows with a fixed, smaller size).
struct CT1ToolsWindowAccessor: NSViewRepresentable {
    var title: String? = nil
    var minContentSize: CGSize? = nil
    var onWindow: (NSWindow) -> Void = { _ in }

    func makeNSView(context: Context) -> NSView {
        let v = Probe()
        v.onAttach = { w in
            if let title { w.title = title }
            if let min = minContentSize { CT1ToolsWindowAccessor.enlarge(w, to: min) }
            onWindow(w)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        var onAttach: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let w = window else { return }
            let attach = onAttach
            DispatchQueue.main.async { attach?(w) }
        }
    }

    @MainActor
    static func enlarge(_ w: NSWindow, to min: CGSize) {
        let content = w.contentRect(forFrameRect: w.frame).size
        guard content.width < min.width || content.height < min.height else { return }
        let size = CGSize(width: max(content.width, min.width), height: max(content.height, min.height))
        var f = w.frame
        let top = f.maxY
        f.size = w.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
        f.origin.y = top - f.height
        if let vis = (w.screen ?? NSScreen.main)?.visibleFrame {
            if f.maxY > vis.maxY { f.origin.y = vis.maxY - f.height }
            if f.minY < vis.minY { f.origin.y = max(vis.minY, vis.maxY - f.height) }
            if f.maxX > vis.maxX { f.origin.x = max(vis.minX, vis.maxX - f.width) }
        }
        w.setFrame(f, display: true)
    }
}

/// CT1 message texts shared by the parameter dialogs.
enum CT1ToolsMessages {
    static let inputFalse = "Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2."
    static let bigNumber = "CrypTool only supports positive integers of bit length smaller than 8192. These are decimal numbers with at most 2467 digits."
    static let greaterEqual2 = "Please enter a whole number >= 2!"
    static let modulNotPrime = "Your input for the modulus P is not a prime number."

    /// Parses a CT1 number field (expressions allowed); shows CT1's error message and returns nil.
    @MainActor
    static func number(_ s: String) -> BigUInt? {
        guard let v = parseBigNumber(s) else { Alerts.error(inputFalse); return nil }
        guard v.bitLength < 8192 else { Alerts.info(bigNumber); return nil }
        return v
    }
}

// MARK: - Random data generator (CT1 IDD_RANDOM_GENERATOR)

/// Generator-specific parameters as entered (strings, expressions allowed), persisted like CT1's
/// registry values ParamX2MODN_N, ParamLCG_P1/P2/N, ParamICG_P1/P2/N.
struct CT1ToolsRandomParameters: Equatable {
    var x2N = RandomGenerators.defaultX2ModNModulus.description
    var lcgA = RandomGenerators.defaultLCGA.description
    var lcgB = RandomGenerators.defaultLCGB.description
    var lcgN = RandomGenerators.defaultLCGModulus.description
    var icgA = RandomGenerators.defaultICGA.description
    var icgC = RandomGenerators.defaultICGB.description
    var icgP = RandomGenerators.defaultICGModulus.description

    private static let keys = ["x2modn.n", "lcg.a", "lcg.b", "lcg.n", "icg.a", "icg.c", "icg.p"]
    private var values: [String] { [x2N, lcgA, lcgB, lcgN, icgA, icgC, icgP] }

    static func load() -> CT1ToolsRandomParameters {
        var p = CT1ToolsRandomParameters()
        let d = UserDefaults.standard
        let v = zip(keys, p.values).map { d.string(forKey: "ct1tools.random." + $0.0) ?? $0.1 }
        (p.x2N, p.lcgA, p.lcgB, p.lcgN, p.icgA, p.icgC, p.icgP) = (v[0], v[1], v[2], v[3], v[4], v[5], v[6])
        return p
    }

    func save() {
        for (k, v) in zip(Self.keys, values) { UserDefaults.standard.set(v, forKey: "ct1tools.random." + k) }
    }

    func summary(_ g: RandomGenerators.CT1Generator) -> String {
        switch g {
        case .secude: return "No additional parameters."
        case .x2modN: return "Modulus N = \(x2N)"
        case .lcg: return "a = \(lcgA), b = \(lcgB), Modulus N = \(lcgN)"
        case .icg: return "a = \(icgA), c = \(icgC), prime P = \(icgP)"
        }
    }
}

struct RandomGeneratorView: View {
    private typealias Gen = RandomGenerators.CT1Generator

    @CTState private var generator: Gen
    @CTState private var seed: String
    @CTState private var length: String
    @CTState private var showStates: Bool
    @CTState private var params: CT1ToolsRandomParameters
    @CTState private var showParameters = false
    @CTState private var running = false
    @CTState private var percent = 0
    @CTState private var token = CancellationToken()
    @CTState private var windowRef = CT1ToolsWindowRef()

    init() {
        let d = UserDefaults.standard
        let g = Gen(rawValue: d.object(forKey: "ct1tools.random.generator") as? Int ?? 0) ?? .secude
        _generator = CTState(initialValue: g)
        _seed = CTState(initialValue: d.string(forKey: "ct1tools.random.seed") ?? RandomGenerators.defaultSeed.description)
        _length = CTState(initialValue: String(d.object(forKey: "ct1tools.random.length") as? Int ?? RandomGenerators.defaultByteCount))
        // CT1 default ShowInternalRandState = 1; the Secude generator clears it (OnBnClickedRadio1)
        _showStates = CTState(initialValue: g.hasInternalStates && (d.object(forKey: "ct1tools.random.showStates") as? Bool ?? true))
        _params = CTState(initialValue: CT1ToolsRandomParameters.load())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Description") {
                Text("Random data is generated with the aid of so-called \"pseudorandom number generators\". This is a selection of both \"cryptographically strong\" and also insecure pseudorandom number generators.")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Algorithm selection") {
                Picker("", selection: $generator) {
                    ForEach(Gen.allCases, id: \.self) { Text($0.radioLabel).tag($0) }
                }
                .pickerStyle(.radioGroup).labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
                .onChange(of: generator) { _, g in if !g.hasInternalStates { showStates = false } }
            }
            GroupBox("Parameters") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Seed:")
                        TextField("", text: $seed).font(.system(.body, design: .monospaced))
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Button("Choose generator-specific parameters ...") { showParameters = true }
                        Text(params.summary(generator)).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).truncationMode(.middle)
                    }
                }
                .padding(4)
            }
            GroupBox("Output options") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Length of output in bytes:")
                        TextField("", text: $length).frame(width: 90).multilineTextAlignment(.trailing)
                    }
                    Toggle("Print out internal random number states (only for X^2 mod N, ICG and LCG).", isOn: $showStates)
                        .toggleStyle(.checkbox)
                        .disabled(!generator.hasInternalStates)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            if running {
                VStack(alignment: .leading, spacing: 4) {
                    Text(RandomGenerators.ct1ProgressTitle(generator)).font(.callout.weight(.semibold))
                    ProgressView(value: Double(percent), total: 100)
                    Text(RandomGenerators.ct1ProgressText(percent: percent)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Generate output", action: generate).keyboardShortcut(.defaultAction).disabled(running)
                Spacer()
                Button("Cancel") {
                    if running { token.cancel() } else { windowRef.close() }
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 520)
        .background(CT1ToolsWindowAccessor(minContentSize: CGSize(width: 600, height: 560)) { windowRef.window = $0 })
        .sheet(isPresented: $showParameters) {
            CT1ToolsRandomParameterSheet(generator: generator, parameters: params) { params = $0 }
        }
    }

    private func generate() {
        let trimmed = length.trimmingCharacters(in: .whitespaces)
        guard let n = Int(trimmed), RandomGenerators.ct1ByteRange.contains(n) else {
            Alerts.error("Please enter an integer between \(RandomGenerators.ct1ByteRange.lowerBound) and \(RandomGenerators.ct1ByteRange.upperBound).")
            return
        }
        let g = generator
        var p = RandomGenerators.CT1Parameters()
        if g != .secude {
            guard let s = CT1ToolsMessages.number(seed) else { return }
            p.seed = s
            switch g {
            case .x2modN:
                guard let m = CT1ToolsMessages.number(params.x2N) else { return }
                guard m >= 2 else { Alerts.info(CT1ToolsMessages.greaterEqual2); return }
                p.x2Modulus = m
            case .lcg:
                guard let a = CT1ToolsMessages.number(params.lcgA), let b = CT1ToolsMessages.number(params.lcgB),
                      let m = CT1ToolsMessages.number(params.lcgN) else { return }
                guard m >= 2 else { Alerts.info(CT1ToolsMessages.greaterEqual2); return }
                (p.lcgA, p.lcgB, p.lcgModulus) = (a, b, m)
            case .icg:
                guard let a = CT1ToolsMessages.number(params.icgA), let c = CT1ToolsMessages.number(params.icgC),
                      let m = CT1ToolsMessages.number(params.icgP) else { return }
                guard RandomGenerators.ct1IsValidICGPrime(m) else { Alerts.error(CT1ToolsMessages.modulNotPrime); return }
                (p.icgA, p.icgC, p.icgPrime) = (a, c, m)
            case .secude: break
            }
        }
        // CT1 stores the settings in the registry when generating
        let d = UserDefaults.standard
        d.set(seed, forKey: "ct1tools.random.seed")
        d.set(n, forKey: "ct1tools.random.length")
        d.set(showStates, forKey: "ct1tools.random.showStates")
        d.set(g.rawValue, forKey: "ct1tools.random.generator")
        params.save()

        let states = showStates && g.hasInternalStates
        let t = CancellationToken()
        token = t
        percent = 0
        running = true
        Task.detached(priority: .userInitiated) {
            let out = RandomGenerators.ct1Generate(g, parameters: p, count: n, internalStates: states, progress: { pc in
                Task { @MainActor in percent = pc }
            }, cancel: t)
            await MainActor.run {
                running = false
                guard let out, !t.isCancelled else { return }
                let title = RandomGenerators.ct1ResultTitle(g, length: n)
                // CT1 opens the state window first, then the data window (same title)
                if let s = out.states { DocumentFactory.openResult(text: s, title: title) }
                DocumentFactory.openResult(out.bytes, title: title, viewMode: .hex)
                windowRef.close()   // CT1 closes the dialog ("Ausgabe erzeugen" = OK)
            }
        }
    }
}

/// The generator-specific parameter dialogs of CT1 (IDD_RANDOMPARAMETER_SECUDE,
/// IDD_X2MODN_RANDOMPARAMETER, IDD_LCG_RANDOMPARAMETER, IDD_ICG_RANDOMPARAMETER).
struct CT1ToolsRandomParameterSheet: View {
    let generator: RandomGenerators.CT1Generator
    let onOK: (CT1ToolsRandomParameters) -> Void
    @CTState private var draft: CT1ToolsRandomParameters
    @CTState private var primeBits = String(RandomGenerators.ct1DefaultICGPrimeBits)
    @Environment(\.dismiss) private var dismiss

    init(generator: RandomGenerators.CT1Generator, parameters: CT1ToolsRandomParameters,
         onOK: @escaping (CT1ToolsRandomParameters) -> Void) {
        self.generator = generator
        self.onOK = onOK
        _draft = CTState(initialValue: parameters)
    }

    private var title: String {
        switch generator {
        case .secude: return "Secude Random Number Generator"
        case .x2modN: return "x^2 (mod N) Random Number Generator"
        case .lcg: return "Linear Congruence Generator (LCG)"
        case .icg: return "Inverse Congruence Generator (ICG)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            switch generator {
            case .secude:
                Text("For the Secude pseudorandom number generator you do not need any additional parameters. Further information can be obtained from the online help (\"F1\" key).\n\nNote: CrypTool for macOS uses the cryptographic random number generator of the system (SecRandomCopyBytes) instead of the Secude library.")
                    .fixedSize(horizontal: false, vertical: true)
            case .x2modN:
                Text("A X^2 (mod N) random number generator requires modulus N as input parameter.\nAdditional information can be obtained from the online help (\"F1\" key).")
                    .fixedSize(horizontal: false, vertical: true)
                field("Modulus N =", $draft.x2N)
            case .lcg:
                Text("The linear congruence generator uses a and b from line ax + b and modulus N as parameters.\nAdditional information can be obtained from the online help (\"F1\" key).")
                    .fixedSize(horizontal: false, vertical: true)
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        Text("Straight line parameters:")
                        Text("a =").gridColumnAlignment(.trailing)
                        numberField($draft.lcgA)
                    }
                    GridRow { Color.clear.frame(width: 1, height: 1); Text("b ="); numberField($draft.lcgB) }
                    GridRow { Color.clear.frame(width: 1, height: 1); Text("Modulus  N ="); numberField($draft.lcgN) }
                }
            case .icg:
                Text("The inverse congruence generator uses a and b from the line ax + c and the prime number P as parameters. The generator produces the sequence of random numbers (X_n) from the formula :    X_n = inverse ( a * ( X_0 + n ) + c ) mod P.\nAdditional information can be obtained from the online help (\"F1\" key).")
                    .fixedSize(horizontal: false, vertical: true)
                GroupBox("Parameter options") {
                    HStack(alignment: .top, spacing: 14) {
                        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow { Text("a =").gridColumnAlignment(.trailing); numberField($draft.icgA) }
                            GridRow { Text("c ="); numberField($draft.icgC) }
                            GridRow { Text("prime P ="); numberField($draft.icgP) }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bit length of the prime P:")
                            TextField("", text: $primeBits).frame(width: 60).multilineTextAlignment(.trailing)
                            Button("generate prime", action: generatePrime)
                        }
                    }
                    .padding(4)
                }
            }
            HStack {
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
                Spacer()
                if generator != .secude { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            }
        }
        .padding(18)
        .frame(width: generator == .icg ? 560 : 460)
    }

    private func numberField(_ b: Binding<String>) -> some View {
        TextField("", text: b).font(.system(.body, design: .monospaced)).frame(minWidth: 240)
    }

    private func field(_ label: String, _ b: Binding<String>) -> some View {
        HStack { Text(label); numberField(b) }
    }

    private func generatePrime() {
        guard let bits = Int(primeBits.trimmingCharacters(in: .whitespaces)),
              RandomGenerators.ct1ICGPrimeBitRange.contains(bits) else {
            Alerts.error("Please enter an integer between 0 and 256.")
            return
        }
        let l = RandomGenerators.ct1EffectiveICGPrimeBits(bits)
        primeBits = String(l)
        draft.icgP = RandomGenerators.ct1ICGPrime(bits: l).description
    }

    private func ok() {
        switch generator {
        case .secude: break
        case .x2modN:
            guard let n = CT1ToolsMessages.number(draft.x2N) else { return }
            guard n >= 2 else { Alerts.info(CT1ToolsMessages.greaterEqual2); return }
        case .lcg:
            guard CT1ToolsMessages.number(draft.lcgA) != nil, CT1ToolsMessages.number(draft.lcgB) != nil,
                  let n = CT1ToolsMessages.number(draft.lcgN) else { return }
            guard n >= 2 else { Alerts.info(CT1ToolsMessages.greaterEqual2); return }
        case .icg:
            guard let p = CT1ToolsMessages.number(draft.icgP), CT1ToolsMessages.number(draft.icgA) != nil,
                  CT1ToolsMessages.number(draft.icgC) != nil else { return }
            guard RandomGenerators.ct1IsValidICGPrime(p) else { Alerts.error(CT1ToolsMessages.modulNotPrime); return }
        }
        onOK(draft)
        dismiss()
    }
}
