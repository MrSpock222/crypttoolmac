import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 "Punktaddition auf Elliptischen Kurven": over the reals and over F_p.
struct EllipticCurveView: View {
    @CTState private var overReals = true
    var body: some View {
        VStack(alignment: .leading) {
            Picker("", selection: $overReals) {
                Text("Reelle Zahlen ℝ").tag(true)
                Text("Endlicher Körper F_p").tag(false)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 320)
            if overReals { RealCurveView() } else { FiniteCurveView() }
        }
        .padding()
    }
}

private struct RPoint: Equatable { var x: Double; var y: Double }

private struct RealCurveView: View {
    @CTState private var a = -3.0
    @CTState private var b = 5.0
    @CTState private var P: RPoint?
    @CTState private var Q: RPoint?
    @CTState private var selectingP = true
    private let range = 6.0

    private func f(_ x: Double) -> Double { x * x * x + a * x + b }

    private var discriminantText: String {
        let inner: Double = 4 * a * a * a + 27 * b * b
        let d: Double = -16 * inner
        return String(format: "Diskriminante: %.1f", d) + (abs(inner) < 1e-9 ? " (singulär!)" : "")
    }

    private func add(_ p: RPoint, _ q: RPoint) -> RPoint? {
        let m: Double
        if abs(p.x - q.x) < 1e-9 {
            if abs(p.y + q.y) < 1e-9 { return nil } // P + (−P) = O
            m = (3 * p.x * p.x + a) / (2 * p.y)
        } else {
            m = (q.y - p.y) / (q.x - p.x)
        }
        let x = m * m - p.x - q.x
        let y = m * (p.x - x) - p.y
        return RPoint(x: x, y: y)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            GeometryReader { geo in
                let size = geo.size
                let scale = min(size.width, size.height) / (2 * range)
                let toScreen = { (p: RPoint) in CGPoint(x: size.width / 2 + p.x * scale, y: size.height / 2 - p.y * scale) }
                Canvas { ctx, _ in
                    // axes
                    var axes = Path()
                    axes.move(to: CGPoint(x: 0, y: size.height / 2)); axes.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    axes.move(to: CGPoint(x: size.width / 2, y: 0)); axes.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    ctx.stroke(axes, with: .color(.secondary.opacity(0.5)))
                    // curve
                    for sign in [1.0, -1.0] {
                        var path = Path(); var started = false
                        var x = -range
                        var prevX = x, prevV = f(x)
                        while x <= range {
                            let v = f(x)
                            // close the curve exactly at the roots (y = 0)
                            let root = prevV != v ? prevX + (x - prevX) * (-prevV) / (v - prevV) : x
                            if v >= 0 {
                                let pt = toScreen(RPoint(x: x, y: sign * v.squareRoot()))
                                if started { path.addLine(to: pt) } else {
                                    path.move(to: prevV < 0 ? toScreen(RPoint(x: root, y: 0)) : pt)
                                    path.addLine(to: pt)
                                    started = true
                                }
                            } else if started {
                                path.addLine(to: toScreen(RPoint(x: root, y: 0)))
                                started = false
                            }
                            prevX = x; prevV = v
                            x += range / 800
                        }
                        ctx.stroke(path, with: .color(.blue), lineWidth: 2)
                    }
                    func dot(_ p: RPoint, _ label: String, _ color: Color) {
                        let s = toScreen(p)
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x - 5, y: s.y - 5, width: 10, height: 10)), with: .color(color))
                        ctx.draw(Text(label).bold().foregroundColor(color), at: CGPoint(x: s.x + 14, y: s.y - 12))
                    }
                    if let P { dot(P, "P", .red) }
                    if let Q { dot(Q, "Q", .green) }
                    if let P, let Q, let R = add(P, Q) {
                        let minusR = RPoint(x: R.x, y: -R.y)
                        var line = Path()
                        let dir = P == Q ? RPoint(x: 1, y: (3 * P.x * P.x + a) / (2 * P.y)) : RPoint(x: Q.x - P.x, y: Q.y - P.y)
                        line.move(to: toScreen(RPoint(x: P.x - dir.x * 20, y: P.y - dir.y * 20)))
                        line.addLine(to: toScreen(RPoint(x: P.x + dir.x * 20, y: P.y + dir.y * 20)))
                        ctx.stroke(line, with: .color(.orange.opacity(0.7)), lineWidth: 1)
                        var vert = Path(); vert.move(to: toScreen(minusR)); vert.addLine(to: toScreen(R))
                        ctx.stroke(vert, with: .color(.purple.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        dot(minusR, "−R", .orange)
                        dot(R, "R = P+Q", .purple)
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { e in
                    let x = (e.location.x - size.width / 2) / scale
                    let yClick = (size.height / 2 - e.location.y) / scale
                    let v = f(x)
                    guard v >= 0 else { return }
                    let y = (yClick >= 0 ? 1 : -1) * v.squareRoot()
                    if selectingP { P = RPoint(x: x, y: y) } else { Q = RPoint(x: x, y: y) }
                    selectingP.toggle()
                })
            }
            .frame(minWidth: 420, minHeight: 420)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))

            VStack(alignment: .leading, spacing: 10) {
                Text("y² = x³ + a·x + b").font(.title3.bold())
                Text("a = \(a, specifier: "%.2f")"); Slider(value: $a, in: -6...6)
                Text("b = \(b, specifier: "%.2f")"); Slider(value: $b, in: -6...8)
                Text(discriminantText)
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Klicken Sie nacheinander auf die Kurve, um P und Q zu wählen. Klicken Sie zweimal auf denselben Punkt für die Punktverdopplung 2P.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Q = P (Verdopplung)") { Q = P }.disabled(P == nil)
                if let P { Text("P = (\(P.x, specifier: "%.3f"), \(P.y, specifier: "%.3f"))") }
                if let Q { Text("Q = (\(Q.x, specifier: "%.3f"), \(Q.y, specifier: "%.3f"))") }
                if let P, let Q {
                    if let R = add(P, Q) { Text("P + Q = (\(R.x, specifier: "%.3f"), \(R.y, specifier: "%.3f"))").bold() }
                    else { Text("P + Q = O (Punkt im Unendlichen)").bold() }
                }
                Spacer()
            }
            .frame(width: 260)
        }
    }
}

private struct FiniteCurveView: View {
    @CTState private var pText = "23"
    @CTState private var aText = "1"
    @CTState private var bText = "1"
    @CTState private var points: [ECPoint] = []
    @CTState private var P: ECPoint?
    @CTState private var Q: ECPoint?
    @CTState private var error: String?

    private var curve: EllipticCurve? {
        guard let p = BigUInt(pText), p > 3, p < 2000, Primality.isProbablePrime(p), let a = BigUInt(aText), let b = BigUInt(bText) else { return nil }
        return EllipticCurve(p: p, a: a % p, b: b % p)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            GeometryReader { geo in
                let size = geo.size
                let pv = Double(curve?.p.uint64Value ?? 23)
                let cell = min(size.width, size.height) / (pv + 1)
                let toScreen = { (x: Double, y: Double) in CGPoint(x: (x + 0.5) * cell, y: size.height - (y + 0.5) * cell) }
                Canvas { ctx, _ in
                    for pt in points {
                        guard case let .affine(x, y) = pt else { continue }
                        let s = toScreen(Double(x.uint64Value ?? 0), Double(y.uint64Value ?? 0))
                        var color: Color = .blue
                        if pt == P { color = .red } else if pt == Q { color = .green } else if let P, let Q, let c = curve, c.add(P, Q) == pt { color = .purple }
                        let r = max(2.5, min(cell / 2.5, 6))
                        ctx.fill(Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { e in
                    var best: (ECPoint, CGFloat)?
                    for pt in points {
                        guard case let .affine(x, y) = pt else { continue }
                        let s = toScreen(Double(x.uint64Value ?? 0), Double(y.uint64Value ?? 0))
                        let d = hypot(s.x - e.location.x, s.y - e.location.y)
                        if best == nil || d < best!.1 { best = (pt, d) }
                    }
                    guard let (pt, _) = best else { return }
                    if P == nil || (P != nil && Q != nil) { P = pt; Q = nil } else { Q = pt }
                })
            }
            .frame(minWidth: 420, minHeight: 420)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))

            VStack(alignment: .leading, spacing: 10) {
                Text("y² ≡ x³ + a·x + b (mod p)").font(.title3.bold())
                HStack { Text("p"); TextField("", text: $pText) }
                HStack { Text("a"); TextField("", text: $aText) }
                HStack { Text("b"); TextField("", text: $bText) }
                Button("Punkte berechnen", action: compute).keyboardShortcut(.defaultAction)
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
                Text("\(points.count + 1) Punkte (einschließlich O)").foregroundStyle(.secondary)
                Divider()
                Text("Klicken Sie auf zwei Punkte P und Q. Die Summe R = P + Q wird violett markiert.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let P { Text("P = \(FiniteCurveView.describe(P))").foregroundStyle(.red) }
                if let Q { Text("Q = \(FiniteCurveView.describe(Q))").foregroundStyle(.green) }
                if let P, let Q, let c = curve { Text("P + Q = \(FiniteCurveView.describe(c.add(P, Q)))").bold().foregroundStyle(.purple) }
                if let P, let c = curve { Text("2P = \(FiniteCurveView.describe(c.double(P)))").foregroundStyle(.secondary) }
                Spacer()
            }
            .frame(width: 260)
        }
        .onAppear(perform: compute)
    }

    static func describe(_ p: ECPoint) -> String {
        switch p {
        case .infinity: return "O"
        case let .affine(x, y): return "(\(x), \(y))"
        }
    }

    private func compute() {
        guard let c = curve else { error = "p muss eine Primzahl zwischen 5 und 2000 sein."; points = []; return }
        error = nil
        points = c.allPoints(limit: 10_000).filter { $0 != .infinity }
        P = nil; Q = nil
    }
}
