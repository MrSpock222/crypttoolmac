import AppKit
import SwiftUI
import CTCommon
import CTClassic

// Native replacement for CT1's Flash visualisation "Enigma" by Frank Spieß (enigma v6.0, see
// Enigma-Help_en.html): Enigma I with reflector B and three of the rotors I–V. For every typed
// letter the current path is drawn – red from the keyboard through plugboard, rotors (right → left)
// to the reflector, green back to the lamp. Ring settings are an addition (default A = Flash).

/// Signal path of one key press in contact numbers (0 = 12 o'clock position of the rotors).
struct EnigmaTrace {
    var key = 0, plugIn = 0                 // keyboard letter, letter after the plugboard (entry wheel)
    var fIn = [0, 0, 0], fOut = [0, 0, 0]   // forward (right face → left face), slots left…right
    var reflIn = 0, reflOut = 0
    var bIn = [0, 0, 0], bOut = [0, 0, 0]   // backward (left face → right face)
    var lamp = 0
}

@MainActor
final class EnigmaVisModel: ObservableObject {
    static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    @Published var rotors: [EnigmaRotor] = [.I, .II, .III] { didSet { recompute() } }
    @Published var rings = [0, 0, 0] { didSet { recompute() } }
    @Published var start = [0, 0, 0] { didSet { recompute() } }
    @Published var plugText = "" { didSet { recompute() } }
    @Published var input = "" { didSet { sanitize() } }
    @Published var showKey = true
    @Published var pendingPlug: Int?

    @Published private(set) var output = ""
    @Published private(set) var positions = [0, 0, 0]
    @Published private(set) var trace: EnigmaTrace?
    @Published private(set) var plugError: String?
    @Published private(set) var plug = Array(0..<26)

    @Published var document: CTDocument?

    init(document: CTDocument?) {
        self.document = document
        recompute()
    }

    private func sanitize() {
        let clean = String(input.uppercased().filter { $0.isASCII && $0.isLetter })
        if clean != input { input = clean; return }
        recompute()
    }

    var validPairs: [(Character, Character)] { (try? Enigma.parsePlugboard(plugText)) ?? [] }

    private func machine() -> Enigma? {
        guard let pairs = try? Enigma.parsePlugboard(plugText) else { plugError = "The plugboard must consist of pairs of letters."; return nil }
        do {
            let m = try Enigma(rotors: rotors, reflector: .B, ringSettings: rings, positions: start, plugboard: pairs)
            plugError = nil
            return m
        } catch {
            plugError = error.localizedDescription
            return nil
        }
    }

    private static func tables(_ wiring: String) -> ([Int], [Int]) {
        let f = wiring.unicodeScalars.map { Int($0.value) - 65 }
        var b = [Int](repeating: 0, count: 26)
        for (i, v) in f.enumerated() { b[v] = i }
        return (f, b)
    }

    private static func mod(_ v: Int) -> Int { ((v % 26) + 26) % 26 }

    /// Contact-level pass through a rotor (same formula as CTClassic.Enigma).
    static func through(_ table: [Int], _ c: Int, position: Int, ring: Int) -> Int {
        let shift = position - ring
        return mod(table[mod(c + shift)] - shift)
    }

    func forwardTable(_ slot: Int) -> [Int] { Self.tables(rotors[slot].wiring).0 }
    static let reflector = EnigmaReflector.B.wiring.unicodeScalars.map { Int($0.value) - 65 }

    /// Traces one key press at the given (already stepped) rotor positions.
    func traceKey(_ k: Int, positions pos: [Int]) -> EnigmaTrace {
        var t = EnigmaTrace()
        t.key = k
        t.plugIn = plug[k]
        var c = t.plugIn
        for slot in stride(from: 2, through: 0, by: -1) {
            t.fIn[slot] = c
            c = Self.through(Self.tables(rotors[slot].wiring).0, c, position: pos[slot], ring: rings[slot])
            t.fOut[slot] = c
        }
        t.reflIn = c
        c = Self.reflector[c]
        t.reflOut = c
        for slot in 0...2 {
            t.bIn[slot] = c
            c = Self.through(Self.tables(rotors[slot].wiring).1, c, position: pos[slot], ring: rings[slot])
            t.bOut[slot] = c
        }
        t.lamp = plug[c]
        return t
    }

    func recompute() {
        var p = Array(0..<26)
        for (a, b) in validPairs {
            let x = Int(a.asciiValue! - 65), y = Int(b.asciiValue! - 65)
            p[x] = y; p[y] = x
        }
        plug = p
        guard var m = machine() else {
            output = ""; trace = nil; positions = start
            return
        }
        var out = ""
        var last: EnigmaTrace?
        for ch in input {
            guard let v = ch.asciiValue.map({ Int($0) - 65 }), (0..<26).contains(v) else { continue }
            m.step()
            let t = traceKey(v, positions: m.positions)
            out.append(Self.letters[t.lamp])
            last = t
        }
        output = out
        trace = last
        positions = m.positions
    }

    // MARK: Actions

    func rotate(_ slot: Int, by d: Int) { start[slot] = Self.mod(start[slot] + d) }

    func setRotor(_ slot: Int, _ r: EnigmaRotor) {
        var list = rotors
        if let other = list.firstIndex(of: r), other != slot { list[other] = list[slot] }
        list[slot] = r
        rotors = list
    }

    func press(_ letter: Character) { input.append(letter) }
    func backspace() { if !input.isEmpty { input.removeLast() } }

    /// "Reset": the whole machine back to its initial state.
    func reset() {
        rotors = [.I, .II, .III]
        rings = [0, 0, 0]
        start = [0, 0, 0]
        plugText = ""
        pendingPlug = nil
        input = ""
    }

    /// Click on a plugboard letter: connect two letters, or remove an existing connection.
    func plugClick(_ k: Int) {
        var pairs = validPairs.map { (Int($0.0.asciiValue! - 65), Int($0.1.asciiValue! - 65)) }
        if let i = pairs.firstIndex(where: { $0.0 == k || $0.1 == k }) {
            pairs.remove(at: i)
            pendingPlug = nil
        } else if let first = pendingPlug {
            if first != k && pairs.count < 13 { pairs.append((first, k)) }
            pendingPlug = nil
        } else {
            pendingPlug = k
            return
        }
        plugText = pairs.map { String([Self.letters[$0.0], Self.letters[$0.1]]) }.joined(separator: " ")
    }

    var keyLine1: String {
        let r = rotors.map(\.rawValue).joined(separator: ",")
        let s = start.map { String(Self.letters[$0]) }.joined(separator: ",")
        var t = "Rotors: \(r), Indicators: \(s)"
        if rings != [0, 0, 0] { t += ", Rings: " + rings.map { String(Self.letters[$0]) }.joined(separator: ",") }
        return t
    }

    var keyLine2: String {
        let pairs = validPairs.map { String([$0.0, $0.1]) }
        return "Steckers: " + (pairs.isEmpty ? "-" : pairs.joined(separator: " "))
    }

    var keyDescription: String {
        "Reflector B, rotors \(rotors.map(\.rawValue).joined(separator: "-")), rings \(String(rings.map { Self.letters[$0] })), start \(String(start.map { Self.letters[$0] }))"
            + (validPairs.isEmpty ? "" : ", plugs \(validPairs.map { String([$0.0, $0.1]) }.joined(separator: " "))")
    }

    func encryptDocument() {
        guard let d = document, let pairs = try? Enigma.parsePlugboard(plugText),
              var m = try? Enigma(rotors: rotors, reflector: .B, ringSettings: rings, positions: start, plugboard: pairs) else { return }
        let r = m.encrypt(d.text)
        DocumentFactory.openResult(text: r, title: DocumentFactory.title("Enigma encryption", of: d, key: keyDescription),
                                   parent: d, method: "enigma", key: keyDescription)
    }
}

// MARK: - View

struct CT1EnigmaView: View {
    @ObservedObject var model: EnigmaVisModel
    @CTState private var showRotors = false
    @CTState private var showPlugs = false

    static let canvasSize = CGSize(width: 960, height: 540)
    static let rotorCenters = [CGPoint(x: 180, y: 205), CGPoint(x: 470, y: 205), CGPoint(x: 760, y: 205)]
    static let reflCenter = CGPoint(x: 180, y: 440)
    static let rOuterLetter: CGFloat = 118, rOuterContact: CGFloat = 103, rInnerLetter: CGFloat = 88, rInnerContact: CGFloat = 76
    static let rReflLetter: CGFloat = 80, rReflContact: CGFloat = 66
    static let plugX0: CGFloat = 588, plugDX: CGFloat = 13.8, plugTopY: CGFloat = 392, plugBottomY: CGFloat = 492

    static let red = Color(red: 0.85, green: 0, blue: 0)
    static let green = Color(red: 0.4, green: 0.6, blue: 0)
    static let cyan = Color(red: 0, green: 1, blue: 1)
    static let wire = Color(white: 0.68)
    static let background = Color(white: 0.8)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in draw(&ctx) }
                    .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { e in tap(e.location) })
                rotorControls
                Button { CT1Games.showEnigmaHelp() } label: {
                    Text("? Help").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(UInt16(NSF1FunctionKey))!)), modifiers: [])
                .position(x: 440, y: 440)
            }
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .background(Self.background)
            keyBand
            bottomPanel
        }
        .background(Self.background)
        .foregroundColor(.black)
    }

    // MARK: Rotor buttons (< > and current position)

    private var rotorControls: some View {
        ForEach(0..<3, id: \.self) { slot in
            let c = Self.rotorCenters[slot]
            HStack(spacing: 4) {
                Button { model.rotate(slot, by: -1) } label: { Text("<").font(.system(size: 15, weight: .medium)).frame(width: 22, height: 24) }
                Button { model.rotate(slot, by: 1) } label: { Text(">").font(.system(size: 15, weight: .medium)).frame(width: 22, height: 24) }
            }
            .buttonStyle(.bordered)
            .position(x: c.x - 105, y: c.y - 128)
        }
    }

    // MARK: Key band (Chosen key)

    private var keyBand: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { model.showKey.toggle() } label: {
                Image(systemName: "key.fill").font(.system(size: 18)).foregroundColor(.black)
                    .frame(width: 38, height: 30).background(Color.yellow)
            }
            .buttonStyle(.plain)
            .help("Show/hide the currently chosen key")
            VStack(alignment: .leading, spacing: 2) {
                if model.showKey {
                    HStack(alignment: .top, spacing: 0) {
                        Text("Chosen key: ").underline()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.keyLine1)
                            Text(model.keyLine2)
                        }
                    }
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.yellow)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color(white: 0.45))
            Button { showRotors = true } label: {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                    .frame(width: 38, height: 30).background(Color.yellow)
            }
            .buttonStyle(.plain)
            .help("Exchange rotors and ring setting")
            .popover(isPresented: $showRotors, arrowEdge: .bottom) { rotorSettings.foregroundColor(.primary) }
            Button { showPlugs = true } label: {
                Image(systemName: "wrench.fill").font(.system(size: 16)).foregroundColor(.black)
                    .frame(width: 38, height: 30).background(Color.yellow)
            }
            .buttonStyle(.plain)
            .help("Set the plugboard")
            .popover(isPresented: $showPlugs, arrowEdge: .bottom) { plugSettings.foregroundColor(.primary) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var rotorSettings: some View {
        let names = ["Left rotor", "Middle rotor", "Right rotor"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Exchange rotors").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Rotor")
                    Text("Ring setting")
                }
                ForEach(0..<3, id: \.self) { slot in
                    GridRow {
                        Text(names[slot])
                        Picker("", selection: Binding(get: { model.rotors[slot] }, set: { model.setRotor(slot, $0) })) {
                            ForEach([EnigmaRotor.I, .II, .III, .IV, .V], id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 70)
                        Picker("", selection: $model.rings[slot]) {
                            ForEach(0..<26, id: \.self) { Text(String(EnigmaVisModel.letters[$0])).tag($0) }
                        }
                        .labelsHidden().frame(width: 60)
                    }
                }
            }
            Text("Reflector: B. The Flash version had no rings – ring setting A corresponds to it.")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 330)
    }

    private var plugSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plugboard").font(.headline)
            TextField("e.g. AB FX", text: $model.plugText)
                .font(.system(.body, design: .monospaced))
                .frame(width: 300)
            if let e = model.plugError { Text(e).font(.caption).foregroundColor(.red) }
            Text("Pairs of letters (at most 13). You can also click two letters one after the other in the plugboard of the graphic; a click on a connected letter removes the connection.")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Remove all plugs") { model.plugText = ""; model.pendingPlug = nil }
        }
        .padding(14)
        .frame(width: 330)
    }

    // MARK: Lampboard, keyboard, input/output

    private static let rows = ["QWERTZUIO", "ASDFGHJK", "PYXCVBNML"]

    private func keyRows(lamps: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(Array(row), id: \.self) { ch in
                        let v = Int(ch.asciiValue! - 65)
                        if lamps {
                            let lit = model.trace?.lamp == v
                            Text(String(ch))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(lit ? Color.yellow : Color(white: 0.25)))
                                .foregroundColor(lit ? .black : Color(white: 0.75))
                                .shadow(color: lit ? .yellow : .clear, radius: 6)
                        } else {
                            let pressed = model.trace?.key == v
                            Button { model.press(ch) } label: {
                                Text(String(ch))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(pressed ? Color(white: 0.45) : Color(white: 0.12)))
                                    .overlay(Circle().stroke(pressed ? Self.red : Color(white: 0.6), lineWidth: pressed ? 2 : 1))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var bottomPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Text("Lampboard").font(.caption)
                keyRows(lamps: true)
            }
            VStack(spacing: 6) {
                Text("Keyboard").font(.caption)
                keyRows(lamps: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Input:")
                HStack {
                    TextField("", text: $model.input)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Self.red)
                        .textFieldStyle(.roundedBorder)
                    Button { model.backspace() } label: { Image(systemName: "delete.left") }
                        .help("Delete the last letter (the rotors turn backwards)")
                    Button("Reset") { model.reset() }
                        .help("Puts the whole machine to the \"initial state\".")
                }
                HStack {
                    Text("Output:")
                    Spacer()
                    if let d = model.document {
                        Button("Encrypt document <\(d.shortName)>") { model.encryptDocument() }
                            .controlSize(.small)
                            .help("Encrypts the document with the chosen key (indicators).")
                    }
                }
                Text(model.output.isEmpty ? " " : model.output)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Self.green)
                    .lineLimit(1).truncationMode(.head)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .background(Color(white: 0.92))
                    .overlay(Rectangle().stroke(Color.black.opacity(0.6)))
                HStack {
                    Text("Status:")
                    Text(model.trace == nil ? "" : "Highlighted wires show encryption steps.")
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    // MARK: Geometry

    static func angle(_ k: Int) -> CGFloat { -.pi / 2 + CGFloat(k) * 2 * .pi / 26 }
    static func point(_ c: CGPoint, _ r: CGFloat, _ k: Int) -> CGPoint {
        CGPoint(x: c.x + r * cos(angle(k)), y: c.y + r * sin(angle(k)))
    }
    static func plugX(_ k: Int) -> CGFloat { plugX0 + CGFloat(k) * plugDX }

    private func tap(_ p: CGPoint) {
        for k in 0..<26 {
            let x = Self.plugX(k)
            if abs(p.x - x) < Self.plugDX / 2 && (abs(p.y - Self.plugTopY) < 14 || abs(p.y - Self.plugBottomY) < 12) {
                model.plugClick(k)
                return
            }
        }
    }

    // MARK: Drawing

    private func stroke(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: CGFloat = 1) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(p, with: .color(c), lineWidth: w)
    }

    private func letter(_ ctx: inout GraphicsContext, _ s: String, _ at: CGPoint, size: CGFloat, rotate k: Int, color: Color = .black) {
        var c = ctx
        c.translateBy(x: at.x, y: at.y)
        c.rotate(by: .radians(Double(Self.angle(k) + .pi / 2)))
        c.draw(Text(s).font(.system(size: size, weight: .regular, design: .default)).foregroundColor(color), at: .zero)
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let m = model
        let pos = m.positions
        let t = m.trace

        // Rotors
        for slot in 0..<3 {
            let c = Self.rotorCenters[slot]
            let fw = m.forwardTable(slot)
            for k in 0..<26 {
                let out = EnigmaVisModel.through(fw, k, position: pos[slot], ring: m.rings[slot])
                stroke(&ctx, Self.point(c, Self.rOuterContact, k), Self.point(c, Self.rInnerContact, out), Self.wire, 0.6)
            }
            let roman = m.rotors[slot].rawValue
            ctx.draw(Text(roman).font(.custom("Times New Roman", size: 64).bold()).foregroundColor(Self.cyan.opacity(0.75)), at: c)
            for k in 0..<26 {
                let l = String(EnigmaVisModel.letters[(k + pos[slot]) % 26])
                if k == 0 {
                    let p = Self.point(c, Self.rOuterLetter, 0)
                    ctx.fill(Path(CGRect(x: p.x - 10, y: p.y - 13, width: 20, height: 26)), with: .color(Self.cyan))
                    ctx.stroke(Path(CGRect(x: p.x - 10, y: p.y - 13, width: 20, height: 26)), with: .color(.black), lineWidth: 0.6)
                }
                letter(&ctx, l, Self.point(c, Self.rOuterLetter, k), size: 19, rotate: k)
                letter(&ctx, l, Self.point(c, Self.rInnerLetter, k), size: 11, rotate: k)
            }
        }

        // Reflector B
        let rc = Self.reflCenter
        for k in 0..<26 where EnigmaVisModel.reflector[k] > k {
            stroke(&ctx, Self.point(rc, Self.rReflContact, k), Self.point(rc, Self.rReflContact, EnigmaVisModel.reflector[k]), Self.wire, 0.6)
        }
        for k in 0..<26 {
            letter(&ctx, String(EnigmaVisModel.letters[k]), Self.point(rc, Self.rReflLetter, k), size: 17, rotate: k)
        }
        ctx.draw(Text("Reflector B").font(.system(size: 13, weight: .bold)).foregroundColor(Color(white: 0.35)), at: rc)

        // Plugboard
        for k in 0..<26 {
            let x = Self.plugX(k)
            ctx.draw(Text(String(EnigmaVisModel.letters[k])).font(.system(size: 15, design: .monospaced)), at: CGPoint(x: x, y: Self.plugTopY))
            let box = CGRect(x: x - 4.5, y: Self.plugTopY + 11, width: 9, height: 9)
            let active = t.map { $0.plugIn == k || $0.bOut[2] == k } ?? false
            ctx.fill(Path(box), with: .color(active ? Self.cyan : Self.cyan.opacity(0.45)))
            ctx.stroke(Path(box), with: .color(active ? .black : Color(white: 0.5)), lineWidth: active ? 1.2 : 0.5)
            ctx.draw(Text(String(EnigmaVisModel.letters[k])).font(.system(size: 15, design: .monospaced))
                        .foregroundColor(m.pendingPlug == k ? Self.red : .black),
                     at: CGPoint(x: x, y: Self.plugBottomY))
            stroke(&ctx, CGPoint(x: Self.plugX(m.plug[k]), y: Self.plugTopY + 20), CGPoint(x: x, y: Self.plugBottomY - 10),
                   m.plug[k] == k ? Self.wire : Color(white: 0.3), m.plug[k] == k ? 0.6 : 1.1)
        }
        ctx.draw(Text("Plugboard").font(.system(size: 11)).foregroundColor(Color(white: 0.3)),
                 at: CGPoint(x: Self.plugX(25) - 30, y: Self.plugTopY - 22))
        // Faint connections entry wheel → right rotor
        for k in 0..<26 {
            stroke(&ctx, CGPoint(x: Self.plugX(k), y: Self.plugTopY - 10), Self.point(Self.rotorCenters[2], Self.rOuterContact, k),
                   Self.wire.opacity(0.35), 0.4)
        }

        guard let t else { return }
        let r0 = Self.rotorCenters[0], r2 = Self.rotorCenters[2]
        // forward (red)
        var f = Path()
        f.move(to: CGPoint(x: Self.plugX(t.key), y: Self.plugBottomY - 10))
        f.addLine(to: CGPoint(x: Self.plugX(t.plugIn), y: Self.plugTopY + 20))
        f.move(to: CGPoint(x: Self.plugX(t.plugIn), y: Self.plugTopY - 10))
        f.addLine(to: Self.point(r2, Self.rOuterContact, t.fIn[2]))
        for slot in stride(from: 2, through: 0, by: -1) {
            let c = Self.rotorCenters[slot]
            f.move(to: Self.point(c, Self.rOuterContact, t.fIn[slot]))
            f.addLine(to: Self.point(c, Self.rInnerContact, t.fOut[slot]))
            if slot > 0 {
                f.addLine(to: Self.point(Self.rotorCenters[slot - 1], Self.rOuterContact, t.fOut[slot]))
            }
        }
        f.move(to: Self.point(r0, Self.rInnerContact, t.fOut[0]))
        f.addLine(to: Self.point(rc, Self.rReflContact, t.reflIn))
        f.addLine(to: Self.point(rc, Self.rReflContact, t.reflOut))
        // backward (green)
        var g = Path()
        g.move(to: Self.point(rc, Self.rReflContact, t.reflOut))
        g.addLine(to: Self.point(r0, Self.rInnerContact, t.bIn[0]))
        for slot in 0...2 {
            let c = Self.rotorCenters[slot]
            g.move(to: Self.point(c, Self.rInnerContact, t.bIn[slot]))
            g.addLine(to: Self.point(c, Self.rOuterContact, t.bOut[slot]))
            if slot < 2 {
                g.addLine(to: Self.point(Self.rotorCenters[slot + 1], Self.rInnerContact, t.bOut[slot]))
            }
        }
        g.move(to: Self.point(r2, Self.rOuterContact, t.bOut[2]))
        g.addLine(to: CGPoint(x: Self.plugX(t.bOut[2]), y: Self.plugTopY - 10))
        g.move(to: CGPoint(x: Self.plugX(t.bOut[2]), y: Self.plugTopY + 20))
        g.addLine(to: CGPoint(x: Self.plugX(t.lamp), y: Self.plugBottomY - 10))
        ctx.stroke(g, with: .color(Self.green), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ctx.stroke(f, with: .color(Self.red), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        // contact markers
        for (slot, c) in Self.rotorCenters.enumerated() {
            for (k, col) in [(t.fIn[slot], Self.red), (t.bOut[slot], Self.green)] {
                ctx.fill(Path(ellipseIn: CGRect(origin: Self.point(c, Self.rOuterContact, k), size: .zero).insetBy(dx: -3, dy: -3)), with: .color(col))
            }
            for (k, col) in [(t.fOut[slot], Self.red), (t.bIn[slot], Self.green)] {
                ctx.fill(Path(ellipseIn: CGRect(origin: Self.point(c, Self.rInnerContact, k), size: .zero).insetBy(dx: -3, dy: -3)), with: .color(col))
            }
        }
        // arrows below the plugboard: red = key pressed, green = lamp
        for (k, up, col) in [(t.key, true, Self.red), (t.lamp, false, Self.green)] {
            let x = Self.plugX(k), y0 = Self.plugBottomY + 14, y1 = Self.plugBottomY + 40
            var a = Path()
            if up {
                a.move(to: CGPoint(x: x, y: y0)); a.addLine(to: CGPoint(x: x - 7, y: y0 + 10)); a.addLine(to: CGPoint(x: x - 3, y: y0 + 10))
                a.addLine(to: CGPoint(x: x - 3, y: y1)); a.addLine(to: CGPoint(x: x + 3, y: y1)); a.addLine(to: CGPoint(x: x + 3, y: y0 + 10))
                a.addLine(to: CGPoint(x: x + 7, y: y0 + 10)); a.closeSubpath()
            } else {
                a.move(to: CGPoint(x: x, y: y1)); a.addLine(to: CGPoint(x: x - 7, y: y1 - 10)); a.addLine(to: CGPoint(x: x - 3, y: y1 - 10))
                a.addLine(to: CGPoint(x: x - 3, y: y0)); a.addLine(to: CGPoint(x: x + 3, y: y0)); a.addLine(to: CGPoint(x: x + 3, y: y1 - 10))
                a.addLine(to: CGPoint(x: x + 7, y: y1 - 10)); a.closeSubpath()
            }
            ctx.stroke(a, with: .color(col), lineWidth: 1.5)
        }
    }
}
