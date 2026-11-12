import AppKit
import SwiftUI
import CTCommon
import CTModern

// Native port of CT1's Java applet "Rijndael-Flussvisualisierung" (AES_flow_visualisation:
// MainView/RijndaelView/DrawScheme/State). Every byte of the 16-byte block is a colour stream
// whose colour is derived from the byte value (DrawScheme.valueToColor); one AES-128 round is
// drawn at a time: (initial key addition), S-boxes, ShiftRows, MixColumns, round key addition.
// "Berechnung" colours the round from top to bottom, "Neue Runde" scrolls to the next round;
// without "Pausen" it runs endlessly from round to round, as in CT1.

extension CT1Visualizations {
    static func openRijndaelFlow() {
        WindowPresenter.tool(id: "ct1-aes-flow", title: "Rijndael-Flussvisualisierung", size: CGSize(width: 1000, height: 820)) {
            AESFlowView()
        }
    }
}

/// All values of one displayed round (DrawScheme's `State`).
struct AESFlowRound {
    static let mix: [[UInt8]] = [[2, 3, 1, 1], [1, 2, 3, 1], [1, 1, 2, 3], [3, 1, 1, 2]]

    let round: Int              // 1 … 10
    var first: Bool { round == 1 }
    var last: Bool { round == 10 }
    let start: [UInt8]
    let firstKey: [UInt8]       // round key 0 (used in round 1 only)
    let afterKey: [UInt8]
    let afterSub: [UInt8]
    let afterShift: [UInt8]
    /// products[c][j][m] = mix[m][j] · afterShift[4c + j] in GF(2⁸)
    let products: [[[UInt8]]]
    let afterMix: [UInt8]
    let roundKey: [UInt8]
    let result: [UInt8]

    init(round: Int, start: [UInt8], roundKeys: [[UInt8]]) {
        self.round = round
        self.start = start
        firstKey = roundKeys[0]
        afterKey = round == 1 ? zip(start, roundKeys[0]).map { $0 ^ $1 } : start
        afterSub = afterKey.map { AESInspector.sbox[Int($0)] }
        var sh = [UInt8](repeating: 0, count: 16)
        for c in 0..<4 { for r in 0..<4 { sh[4 * c + r] = afterSub[4 * ((c + r) % 4) + r] } }
        afterShift = sh
        var prod = [[[UInt8]]](repeating: [[UInt8]](repeating: [UInt8](repeating: 0, count: 4), count: 4), count: 4)
        var mixed = [UInt8](repeating: 0, count: 16)
        for c in 0..<4 {
            for j in 0..<4 {
                for m in 0..<4 {
                    prod[c][j][m] = AESInspector.gmul(sh[4 * c + j], Self.mix[m][j])
                    mixed[4 * c + m] ^= prod[c][j][m]
                }
            }
        }
        products = prod
        afterMix = mixed
        roundKey = roundKeys[round]
        result = zip(round == 10 ? sh : mixed, roundKeys[round]).map { $0 ^ $1 }
    }

    /// DrawScheme.valueToColor
    static func color(_ x: UInt8) -> Color {
        let v = Int(x)
        return Color(red: Double((v % 8) * 32 + 1) / 255, green: Double(((v / 8) % 8) * 32) / 255,
                     blue: Double(((v / 64) % 3) * 64) / 255)
    }
}

// MARK: - Drawing

enum AESFlowDrawing {
    static let width: CGFloat = 520
    static let height: CGFloat = 240

    static func x(_ c: Int, _ r: Int) -> CGFloat { 22 + 120 * CGFloat(c) + 15 * CGFloat(r) }

    /// Draws one round. `colored == false` draws the empty structure (white streams).
    static func draw(_ ctx: GraphicsContext, round f: AESFlowRound, colored: Bool, origin: CGPoint, scale s: CGFloat) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * s, y: origin.y + y * s) }
        func fill(_ v: UInt8) -> Color { colored ? AESFlowRound.color(v) : .white }
        func stream(_ pts: [CGPoint], _ v: UInt8, width w: CGFloat = 3) {
            var p = Path()
            p.move(to: pts[0]); for q in pts.dropFirst() { p.addLine(to: q) }
            ctx.stroke(p, with: .color(.black), style: StrokeStyle(lineWidth: (w + 0.9) * s, lineCap: .butt, lineJoin: .round))
            ctx.stroke(p, with: .color(fill(v)), style: StrokeStyle(lineWidth: max(1, (w - 0.3) * s), lineCap: .butt, lineJoin: .round))
        }
        func box(_ x0: CGFloat, _ y0: CGFloat, _ top: UInt8, _ bottom: UInt8, h: CGFloat = 10) {
            let r1 = CGRect(origin: P(x0 - 5, y0), size: CGSize(width: 10 * s, height: h / 2 * s))
            let r2 = CGRect(origin: P(x0 - 5, y0 + h / 2), size: CGSize(width: 10 * s, height: h / 2 * s))
            ctx.fill(Path(r1), with: .color(fill(top)))
            ctx.fill(Path(r2), with: .color(fill(bottom)))
            ctx.stroke(Path(CGRect(origin: P(x0 - 5, y0), size: CGSize(width: 10 * s, height: h * s))), with: .color(.black), lineWidth: 1)
        }
        func xorCircle(_ x0: CGFloat, _ y0: CGFloat, r: CGFloat = 3) {
            let rect = CGRect(x: origin.x + (x0 - r) * s, y: origin.y + (y0 - r) * s, width: 2 * r * s, height: 2 * r * s)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: 1)
            var plus = Path()
            plus.move(to: P(x0 - r, y0)); plus.addLine(to: P(x0 + r, y0))
            plus.move(to: P(x0, y0 - r)); plus.addLine(to: P(x0, y0 + r))
            ctx.stroke(plus, with: .color(.black), lineWidth: 0.8)
        }
        func label(_ t: String, _ x0: CGFloat, _ y0: CGFloat, size: CGFloat = 5.5, color: Color = .primary) {
            guard colored else { return }
            ctx.draw(Text(t).font(.system(size: size * s, design: .monospaced)).foregroundColor(color), at: P(x0, y0))
        }
        func hx(_ v: UInt8) -> String { String(format: "%02X", v) }

        // 1. input / initial key addition
        for c in 0..<4 {
            for r in 0..<4 {
                let i = 4 * c + r, x0 = x(c, r)
                if f.first {
                    label(hx(f.start[i]), x0, 4)
                    stream([P(x0, 18), P(x0, 46)], f.afterKey[i])
                    stream([P(x0, 18), P(x0, 32)], f.start[i])
                    box(x0, 8, f.start[i], f.start[i])
                    xorCircle(x0, 32)
                    label(hx(f.firstKey[i]), x0 - 9.5, 27, size: 4.6, color: .secondary)
                } else {
                    stream([P(x0, 0), P(x0, 46)], f.start[i])
                }
            }
        }
        // 2. S-boxes
        for c in 0..<4 {
            for r in 0..<4 {
                let i = 4 * c + r, x0 = x(c, r)
                stream([P(x0, 56), P(x0, 66)], f.afterSub[i])
                box(x0, 46, f.afterKey[i], f.afterSub[i], h: 10)
            }
        }
        if !colored {
            ctx.draw(Text("S-Box").font(.system(size: 5 * s)).foregroundColor(.secondary), at: P(458, 51), anchor: .leading)
        }
        // 3. ShiftRows: input column c, row r → output column (c − r) mod 4
        for c in 0..<4 {
            for r in 0..<4 {
                let i = 4 * c + r
                let x0 = x(c, r), x1 = x((c - r + 4) % 4, r)
                let ya = 66 + CGFloat(3 - r) * 7, yb = ya + 18
                stream([P(x0, 66), P(x0, ya), P(x1, yb), P(x1, 112)], f.afterSub[i])
            }
        }
        if !colored {
            ctx.draw(Text("ShiftRows").font(.system(size: 5 * s)).foregroundColor(.secondary), at: P(458, 90), anchor: .leading)
        }
        var yKey: CGFloat = 124
        // 4. MixColumns
        if !f.last {
            for c in 0..<4 {
                for j in 0..<4 {
                    for m in 0..<4 {
                        let a = P(x(c, j), 114), b = P(x(c, m), 168)
                        stream([a, b], f.products[c][j][m], width: 1.6)
                    }
                }
                for j in 0..<4 { box(x(c, j), 110, f.afterShift[4 * c + j], f.afterShift[4 * c + j], h: 4) }
                for j in 0..<4 {
                    for m in 0..<4 {
                        let t: CGFloat = 0.2
                        let px = x(c, j) + (x(c, m) - x(c, j)) * t
                        label("\(AESFlowRound.mix[m][j])", px + 1.8, 114 + 54 * t, size: 3.6, color: .secondary)
                    }
                }
                for m in 0..<4 {
                    stream([P(x(c, m), 170), P(x(c, m), 196)], f.afterMix[4 * c + m])
                    xorCircle(x(c, m), 170, r: 2.4)
                }
            }
            if !colored {
                ctx.draw(Text("MixColumns").font(.system(size: 5 * s)).foregroundColor(.secondary), at: P(458, 140), anchor: .leading)
            }
            yKey = 202
        }
        // 5. round key addition and output
        for c in 0..<4 {
            for r in 0..<4 {
                let i = 4 * c + r, x0 = x(c, r)
                let pre = f.last ? f.afterShift[i] : f.afterMix[i]
                stream([P(x0, yKey - 10), P(x0, yKey)], pre)
                stream([P(x0, yKey), P(x0, yKey + 14)], f.result[i])
                xorCircle(x0, yKey)
                label(hx(f.roundKey[i]), x0 - 9.5, yKey - 5, size: 4.6, color: .secondary)
                box(x0, yKey + 14, f.result[i], f.result[i])
                label(hx(f.result[i]), x0, yKey + 30)
            }
        }
        if !colored {
            ctx.draw(Text("Rundenschlüssel").font(.system(size: 5 * s)).foregroundColor(.secondary), at: P(458, yKey), anchor: .leading)
        }
    }
}

// MARK: - Animation driver

@MainActor
final class FlowAnimator: ObservableObject {
    enum Phase { case idle, wiping, scrolling }
    @Published var progress: Double = 0   // wipe 0 … 1
    @Published var scroll: Double = 0     // 0 … 1
    @Published private(set) var phase: Phase = .idle
    @Published var speed: Double = 1
    private var timer: Timer?
    private var start = Date()
    private var duration = 1.0
    private var completion: (() -> Void)?

    func wipe(_ done: @escaping () -> Void) { run(.wiping, 5.0, done) }
    func scrollUp(_ done: @escaping () -> Void) { run(.scrolling, 1.6, done) }

    private func run(_ p: Phase, _ d: Double, _ done: @escaping () -> Void) {
        stop()
        phase = p; start = Date(); duration = d / max(0.25, speed); completion = done
        if p == .wiping { progress = 0 } else { scroll = 0 }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let v = min(1, Date().timeIntervalSince(start) / duration)
        if phase == .wiping { progress = v } else { scroll = v }
        if v >= 1 {
            timer?.invalidate(); timer = nil
            phase = .idle
            let c = completion; completion = nil
            c?()
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        phase = .idle; completion = nil
    }
}

// MARK: - View

struct AESFlowView: View {
    @StateObject private var anim = FlowAnimator()
    @CTState private var data: [String] = AESFlowView.randomHex()
    @CTState private var key: [String] = AESFlowView.randomHex()
    @CTState private var roundIndex = 0                 // 0 … 9 (displayed: roundIndex + 1)
    @CTState private var roundKeys: [[UInt8]] = AESInspector.expandKey([UInt8](repeating: 0, count: 16))
    @CTState private var current: AESFlowRound?
    @CTState private var next: AESFlowRound?
    @CTState private var computed = false               // colours of `current` shown
    @CTState private var pauses = true
    @CTState private var running = false
    @CTState private var keyLocked = false
    @CTState private var runPlaintext: [UInt8]?
    @CTState private var message = ""

    static func randomHex() -> [String] { (0..<16).map { _ in String(format: "%02X", UInt8.random(in: 0...255)) } }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            Canvas { ctx, size in
                let s = min(size.width / AESFlowDrawing.width, size.height / AESFlowDrawing.height)
                let ox = (size.width - AESFlowDrawing.width * s) / 2
                let h = AESFlowDrawing.height * s
                let cur = current ?? placeholderRound()
                if anim.phase == .scrolling || (anim.scroll > 0 && anim.scroll < 1) {
                    let off = anim.scroll * h
                    AESFlowDrawing.draw(ctx, round: cur, colored: true, origin: CGPoint(x: ox, y: -off), scale: s)
                    if let n = next {
                        AESFlowDrawing.draw(ctx, round: n, colored: false, origin: CGPoint(x: ox, y: h - off), scale: s)
                    }
                    return
                }
                AESFlowDrawing.draw(ctx, round: cur, colored: false, origin: CGPoint(x: ox, y: 0), scale: s)
                let p = computed ? 1 : (anim.phase == .wiping ? anim.progress : 0)
                if p > 0 {
                    var layer = ctx
                    layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: p * h)))
                    AESFlowDrawing.draw(layer, round: cur, colored: true, origin: CGPoint(x: ox, y: 0), scale: s)
                }
            }
            .background(Color.white)
            Divider()
            HStack {
                Text(message).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                Spacer()
                Text("Farbe eines Bytes x: R = (x mod 8)·32, G = (⌊x/8⌋ mod 8)·32, B = (⌊x/64⌋ mod 3)·64")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .onAppear { if current == nil { prepareCurrent() } }
        .onDisappear { anim.stop() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Daten:").frame(width: 72, alignment: .trailing)
                ForEach(0..<16, id: \.self) { i in
                    TextField("", text: $data[i]).frame(width: 30).font(.system(.body, design: .monospaced))
                        .disabled(running)
                }
            }
            HStack(spacing: 4) {
                Text("Schlüssel:").frame(width: 72, alignment: .trailing)
                ForEach(0..<16, id: \.self) { i in
                    TextField("", text: $key[i]).frame(width: 30).font(.system(.body, design: .monospaced))
                        .disabled(running || keyLocked)
                }
            }
            HStack(spacing: 8) {
                Text("\(roundIndex + 1). Runde").font(.headline).frame(width: 80, alignment: .leading)
                Button(computed ? "Neue Runde" : "Berechnung") { computed ? newRound() : calculate() }
                    .disabled(running).keyboardShortcut(.defaultAction)
                Button("Reset") { reset() }.disabled(running && !pauses)
                Button("0-Eingabe") { data = Array(repeating: "00", count: 16) }.disabled(running)
                Button("Zufällige Eingabe") { data = Self.randomHex() }.disabled(running)
                Button("0-Schlüssel") { reset(); key = Array(repeating: "00", count: 16) }.disabled(running)
                Button("Zufälliger Schlüssel") { key = Self.randomHex() }
                    .disabled(running || keyLocked)
                Toggle("Pausen", isOn: $pauses).onChange(of: pauses) { _, v in if !v { continueAutomatically() } }
                Spacer()
                Image(systemName: "tortoise").foregroundStyle(.secondary)
                Slider(value: Binding(get: { log2(anim.speed) }, set: { anim.speed = pow(2, $0) }), in: -2...2).frame(width: 90)
                Image(systemName: "hare").foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    // MARK: logic (MainView.java)

    private func parse(_ f: [String]) -> [UInt8]? {
        var out: [UInt8] = []
        for s in f {
            guard let v = UInt8(s.trimmingCharacters(in: .whitespaces), radix: 16) else { return nil }
            out.append(v)
        }
        return out
    }

    private func placeholderRound() -> AESFlowRound {
        AESFlowRound(round: roundIndex + 1, start: [UInt8](repeating: 0, count: 16), roundKeys: roundKeys)
    }

    private func prepareCurrent() {
        if roundIndex == 0, let k = parse(key) { roundKeys = AESInspector.expandKey(k) }
        current = AESFlowRound(round: roundIndex + 1, start: parse(data) ?? [UInt8](repeating: 0, count: 16), roundKeys: roundKeys)
    }

    private func calculate() {
        guard let d = parse(data) else { message = "Ungültige Daten: bitte 16 Hex-Bytes eingeben."; return }
        if roundIndex == 0 {
            guard let k = parse(key) else { message = "Ungültiger Schlüssel: bitte 16 Hex-Bytes eingeben."; return }
            roundKeys = AESInspector.expandKey(k)
            keyLocked = true
            runPlaintext = d
        }
        message = ""
        current = AESFlowRound(round: roundIndex + 1, start: d, roundKeys: roundKeys)
        running = true
        anim.wipe {
            computed = true
            running = false
            showResult()
            if !pauses { newRound() }
        }
    }

    private func showResult() {
        guard let c = current else { return }
        var m = "Runde \(c.round): " + c.start.ct1Hex + "  →  " + c.result.ct1Hex
        if c.last, let p = runPlaintext, let k = parse(key),
           let tr = try? AESInspector.trace(key: k, block: p), tr.ciphertext == c.result {
            m = "Geheimtext (AES-128): " + c.result.ct1Hex + "  ✓"
        }
        message = m
    }

    private func newRound() {
        guard let c = current else { return }
        let nextIndex = (roundIndex + 1) % 10
        let start: [UInt8]
        if nextIndex == 0 {
            start = (0..<16).map { _ in UInt8.random(in: 0...255) }   // CT1 starts again with new data
        } else {
            start = c.result
        }
        let keys = nextIndex == 0 ? AESInspector.expandKey(parse(key) ?? [UInt8](repeating: 0, count: 16)) : roundKeys
        next = AESFlowRound(round: nextIndex + 1, start: start, roundKeys: keys)
        running = true
        anim.scrollUp {
            roundIndex = nextIndex
            data = start.map { String(format: "%02X", $0) }
            if nextIndex == 0 { keyLocked = false; runPlaintext = nil }
            current = next
            next = nil
            computed = false
            anim.scroll = 0
            running = false
            if !pauses { calculate() }
        }
    }

    private func continueAutomatically() {
        guard !running else { return }
        if computed { newRound() } else { calculate() }
    }

    private func reset() {
        anim.stop()
        anim.progress = 0; anim.scroll = 0
        roundIndex = 0
        computed = false
        running = false
        keyLocked = false
        pauses = true
        next = nil
        message = ""
        prepareCurrent()
    }
}
