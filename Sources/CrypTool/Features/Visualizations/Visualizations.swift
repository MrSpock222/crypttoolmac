import AppKit
import SwiftUI
import CTCommon
import CTClassic
import CTModern

// MARK: - Enigma

struct EnigmaView: View {
    let sourceDocument: CTDocument?
    @CTState private var rotors: [EnigmaRotor] = [.I, .II, .III]
    @CTState private var reflector: EnigmaReflector = .B
    @CTState private var rings = [0, 0, 0]
    @CTState private var positions = [0, 0, 0]
    @CTState private var plugboard = ""
    @CTState private var input = "HALLOWELT"
    @CTState private var error: String?

    private static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    private func machine() throws -> Enigma {
        let pairs = plugboard.uppercased().split(separator: " ").compactMap { p -> (Character, Character)? in
            let c = Array(p)
            return c.count == 2 ? (c[0], c[1]) : nil
        }
        return try Enigma(rotors: rotors, reflector: reflector, ringSettings: rings, positions: positions, plugboard: pairs)
    }

    private var output: String {
        do {
            var m = try machine()
            return m.encrypt(input)
        } catch { return "" }
    }

    var body: some View {
        Form {
            Section("Walzenlage (links → rechts)") {
                HStack {
                    Picker("Umkehrwalze", selection: $reflector) {
                        ForEach(EnigmaReflector.allCases, id: \.self) { Text("UKW \($0.rawValue)").tag($0) }
                    }.frame(width: 160)
                    ForEach(0..<3, id: \.self) { i in
                        VStack {
                            Picker("", selection: $rotors[i]) {
                                ForEach(EnigmaRotor.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().frame(width: 70)
                            Picker("Ring", selection: $rings[i]) {
                                ForEach(0..<26, id: \.self) { Text(String(EnigmaView.letters[$0])).tag($0) }
                            }.frame(width: 90)
                            Picker("Start", selection: $positions[i]) {
                                ForEach(0..<26, id: \.self) { Text(String(EnigmaView.letters[$0])).tag($0) }
                            }.frame(width: 90)
                        }
                    }
                }
            }
            Section("Steckerbrett") {
                TextField("Steckerpaare", text: $plugboard, prompt: Text("z. B. AB CD EF")).font(.system(.body, design: .monospaced))
            }
            Section("Eingabe") {
                CodeEditor(text: $input, minHeight: 80)
            }
            Section("Ausgabe") {
                if let e = (try? machine()) == nil ? "Ungültige Einstellung (Steckerpaare doppelt? Walzen doppelt?)" : nil {
                    Text(e).foregroundStyle(.red)
                }
                ResultBox(text: EnigmaView.group(output), minHeight: 60)
                HStack {
                    Text("Die Enigma ist involutorisch: Mit gleicher Einstellung verschlüsselt sie den Geheimtext wieder zum Klartext.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if let d = sourceDocument {
                        Button("Dokument <\(d.shortName)> verschlüsseln") { encryptDocument(d) }
                    }
                    Button("Ausgabe als Dokument") { DocumentFactory.openResult(text: output, title: "Enigma-Ausgabe", key: settingsDescription) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { if let d = sourceDocument { input = String(d.text.prefix(2000)) } }
    }

    private var settingsDescription: String {
        "UKW \(reflector.rawValue), Walzen \(rotors.map(\.rawValue).joined(separator: "-")), Ringe \(String(rings.map { EnigmaView.letters[$0] })), Start \(String(positions.map { EnigmaView.letters[$0] }))"
            + (plugboard.isEmpty ? "" : ", Stecker \(plugboard.uppercased())")
    }

    static func group(_ s: String) -> String {
        var out = ""
        for (i, c) in s.enumerated() {
            if i > 0 && i % 5 == 0 { out += i % 50 == 0 ? "\n" : " " }
            out.append(c)
        }
        return out
    }

    private func encryptDocument(_ d: CTDocument) {
        do {
            var m = try machine()
            let r = m.encrypt(d.text)
            DocumentFactory.openResult(text: r, title: DocumentFactory.title("Enigma-Verschlüsselung", of: d, key: settingsDescription), parent: d, method: "enigma", key: settingsDescription)
        } catch { Alerts.error(error.localizedDescription) }
    }
}

// MARK: - AES / Rijndael inspector

struct AESInspectorView: View {
    @CTState private var keyHex = "2B 7E 15 16 28 AE D2 A6 AB F7 15 88 09 CF 4F 3C"
    @CTState private var blockHex = "32 43 F6 A8 88 5A 30 8D 31 31 98 A2 E0 37 07 34"
    @CTState private var steps: [AESTraceStep] = []
    @CTState private var roundKeys: [[UInt8]] = []
    @CTState private var cipher: [UInt8] = []
    @CTState private var error: String?
    @CTState private var selectedStep = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verfolgen Sie die Zustandsmatrix (spaltenweise, FIPS-197) durch alle Runden von AES. Vorbelegt ist das Beispiel aus FIPS-197, Anhang B.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Text("Schlüssel").frame(width: 80, alignment: .leading)
                TextField("16/24/32 Bytes hex", text: $keyHex).font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Klartext").frame(width: 80, alignment: .leading)
                TextField("16 Bytes hex", text: $blockHex).font(.system(.body, design: .monospaced))
                Button("Berechnen", action: compute).keyboardShortcut(.defaultAction)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if !steps.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    List(selection: $selectedStep) {
                        ForEach(steps.indices, id: \.self) { i in
                            Text("Runde \(steps[i].round): \(steps[i].operation)").tag(i)
                        }
                    }.frame(width: 240)
                    VStack(alignment: .leading, spacing: 12) {
                        let s = steps[min(selectedStep, steps.count - 1)]
                        Text("Runde \(s.round) – \(s.operation)").font(.headline)
                        StateMatrixView(state: s.state, previous: selectedStep > 0 ? steps[selectedStep - 1].state : nil)
                        if s.round < roundKeys.count {
                            Text("Rundenschlüssel \(s.round)").font(.headline)
                            StateMatrixView(state: roundKeys[s.round], previous: nil)
                        }
                        Text("Chiffrat: " + Hex.encode(cipher)).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .onAppear(perform: compute)
    }

    private func compute() {
        guard let k = Hex.decode(keyHex), let b = Hex.decode(blockHex) else { error = "Ungültige Hex-Eingabe."; return }
        do {
            let r = try AESInspector.trace(key: k, block: b)
            steps = r.steps; roundKeys = r.roundKeys; cipher = r.ciphertext; error = nil
            selectedStep = 0
        } catch { self.error = error.localizedDescription }
    }
}

struct StateMatrixView: View {
    let state: [UInt8]
    let previous: [UInt8]?
    var body: some View {
        let cols = max(1, state.count / 4)
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<4, id: \.self) { r in
                GridRow {
                    ForEach(0..<cols, id: \.self) { c in
                        let i = c * 4 + r
                        let changed = previous.map { i < $0.count && $0[i] != state[i] } ?? false
                        Text(String(format: "%02X", state[i]))
                            .font(.system(.title3, design: .monospaced))
                            .frame(width: 44, height: 34)
                            .background(changed ? Color.orange.opacity(0.35) : Color(nsColor: .controlBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
                    }
                }
            }
        }
    }
}

// MARK: - Caesar disk

struct CaesarDiskView: View {
    @CTState private var shift = 3
    @CTState private var text = "CRYPTOOL"
    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r1 = min(size.width, size.height) / 2 - 10
                let r2 = r1 - 38
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r1, y: c.y - r1, width: 2 * r1, height: 2 * r1)), with: .color(.secondary))
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r2, y: c.y - r2, width: 2 * r2, height: 2 * r2)), with: .color(.secondary))
                for i in 0..<26 {
                    let a = Double(i) / 26 * 2 * .pi - .pi / 2
                    let p1 = CGPoint(x: c.x + (r1 - 18) * cos(a), y: c.y + (r1 - 18) * sin(a))
                    let p2 = CGPoint(x: c.x + (r2 - 18) * cos(a), y: c.y + (r2 - 18) * sin(a))
                    ctx.draw(Text(String(letters[i])).font(.system(size: 15, weight: .semibold, design: .monospaced)), at: p1)
                    ctx.draw(Text(String(letters[(i + shift) % 26])).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundColor(.blue), at: p2)
                }
                ctx.draw(Text("+\(shift)").font(.largeTitle.bold()), at: c)
            }
            .frame(width: 360, height: 360)
            VStack(alignment: .leading, spacing: 10) {
                Text("Caesar-Scheibe").font(.title2.bold())
                Text("Außen: Klartextalphabet, innen (blau): Geheimtextalphabet. Drehen Sie die innere Scheibe, um die Verschiebung zu ändern.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Stepper("Verschiebung: \(shift) (Schlüssel \(String(letters[shift])))", value: $shift, in: 0...25)
                Slider(value: Binding(get: { Double(shift) }, set: { shift = Int($0.rounded()) }), in: 0...25, step: 1)
                TextField("Klartext", text: $text).font(.system(.body, design: .monospaced))
                Text(Caesar.encrypt(text, shift: shift, options: .default)).font(.system(.title3, design: .monospaced)).foregroundStyle(.blue).textSelection(.enabled)
                Spacer()
            }
            .frame(width: 280)
        }
        .padding()
    }
}
