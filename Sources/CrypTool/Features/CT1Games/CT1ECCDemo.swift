import AppKit
import SwiftUI

// Port of CT1's Java "ECC-Demo 1.1.1" (eccdemo: ECCFrame, GrafikFr/GrafikFp, BedienungsPanelFr/Fp,
// TextPanel, LogDatei) with the German texts of Texte.java. Pixel geometry (529×529 canvas,
// pixelProZelle = 264 / zoom, 25 px margin for F_p) is kept so that hovering/selection behaves alike.

enum ECCText {
    static let frameTitleFr = "ECC-Demo 1.1.1: Punktaddition auf Elliptischen Kurven über den reellen Zahlenraum R"
    static let frameTitleFp = "ECC-Demo 1.1.1: Punktaddition auf Elliptischen Kurven über diskreten Gruppen Fp"
    static let pointsText = "Punkte:"
    static let labelSpace = "Wählen Sie den Zahlenraum"
    static let buttonFr = "Reeller Zahlenraum R"
    static let buttonFp = "Diskrete Gruppe über Fp"
    static let buttonLog = "Log-Datei"
    static let buttonDelete = "Lösche Punkte"
    static let buttonExit = "Beenden"
    static let intro = ["Dieses Programm visualisiert verschiedene", "Elliptische Kurven und ermöglicht es,",
                        "Punktadditionen auf diesen durchzuführen.", "Die Kurven können entweder über dem Zahlenraum",
                        "der reellen Zahlen oder über der diskreten Gruppe", "über Primzahlen zwischen 3 und 97 erzeugt werden.",
                        "Die Kurvenparameter a und b können Sie mit", "den Reglern verändern."]
    static let start = ["Nachdem Sie eine Kurve ausgewählt haben,", "legen Sie durch Klick mit der linken Maustaste",
                        "einen Punkt auf der Kurve fest! In der Grafik", "wird Ihnen jeweils der Punkt rot angezeigt, der",
                        "Ihrem Mauszeiger am nächsten ist.", "", ""]
    static let p = ["Sie haben einen Punkt P auf der Kurve", "ausgewählt. Sie können nun den Punkt",
                    "mit dem Button '2*P' zu sich selbst addieren,", "oder einen weiteren Punkt auswählen.", "", "", ""]
    static let q = ["Sie haben jetzt einen Punkt P und einen Punkt Q", "auf der Kurve gewählt. Mit dem Button 'P+Q'",
                    "können Sie die beiden Punkte addieren.", "", "", "", ""]
    static let rp = ["Die Tangente an den Punkt P schneidet die", "Kurve im Punkt -R. Die Spiegelung von -R an der",
                     "x-Achse ist der Punkt R.", "R ist das Ergebnis der Punktaddition von P.",
                     "Durch erneutes Drücken des Buttons können Sie", "die Punktaddition mit dem Punkt P fortsetzen.", ""]
    static let rpq = ["Die Gerade durch die Punkte P und Q schneidet", "die Kurve im Punkt -R. Die Spiegelung von -R",
                      "an der x-Achse ist der Punkt R.", "R ist das Ergebnis der Addition von P und Q.", "", "", ""]
    static let rAus2PNaN = ["Die Tangente an den Punkt P hat keinen weiteren", "Schnittpunkt mit der Kurve.",
                            "Der Punkt R ist der Punkt im Unendlichen O.", "", "", "", ""]
    static let rAusPQNaN = ["Die Gerade durch die Punkte P und Q hat keine", "weiteren Schnittpunkte mit der Kurve.",
                            "Der Punkt R ist der Punkt im Unendlichen O.", "", "", "", ""]
    static let frp = ["Die Verdopplung des Punktes P ergibt den", "Punkt R.", "Durch erneutes Drücken des Buttons können Sie",
                      "die Punktaddition mit dem Punkt P fortsetzen.", "", "Eine Erläuterung des mathematischen Verfahrens",
                      "finden Sie in der Hilfe zu dieser Demo."]
    static let frpq = ["Die Addition der Punkte P und Q ergibt den", "Punkt R.", "", "Eine Erläuterung des mathematischen Verfahrens",
                       "finden Sie in der Hilfe zu dieser Demo.", "", ""]
    static let frAus2PNaN = ["Das Ergebnis der Verdopplung des Punktes P", "ist der Punkt im Unendlichen O, welcher sich",
                             "nicht im Koordinatensystem darstellen lässt.", "", "", "", ""]
    static let frAusPQNaN = ["Das Ergebnis der Addition der Punkte P und Q", "ist der Punkt im Unendlichen O, welcher sich",
                             "nicht im Koordinatensystem darstellen lässt.", "", "", "", ""]
    static let graph1 = " mit "
    static let graph2 = " über "
    static let graph3 = " Punkten."
    static let logTitle = "Log-Datei: Punktaddition auf Elliptischen Kurven"
    static let logFrNumberSpace = "----- Berechnung im reellen Zahlenraum R -----\n\n"
    static let logFpNumberSpace = "----- Berechnung in der diskreten Gruppe Fp mit p = "
    static let logCurve = "Gewählte Kurve:\n"
    static let line = "_______________________________________"
}

struct ECCPt: Equatable { var x: Double; var y: Double }

@MainActor
final class ECCDemoModel: ObservableObject {
    static let canvas = 529
    static let zoomValues = [6, 8, 11, 12, 22, 24, 33, 44, 66, 88]
    static let primes = [3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]
    static let abstand = 25

    @Published var fp = false                // ECCFrame.raum
    // reals: a = aScroll / 100 (nks = 100)
    @Published var aScroll = -1000
    @Published var bScroll = 1500
    @Published var cIndex = 3
    // F_p
    @Published var aFp = 11
    @Published var bFp = 20
    @Published var pIndex = 7

    @Published var pset = false
    @Published var qset = false
    @Published var rset = false
    @Published var rNaN = false
    @Published var np = 1
    @Published var P = ECCPt(x: 0, y: 0)
    @Published var Q = ECCPt(x: 0, y: 0)
    @Published var R = ECCPt(x: 0, y: 0)
    @Published var A: ECCPt?                 // point closest to the mouse (ax/ay)
    @Published var info: [String] = ECCText.start
    @Published var labelP = ""
    @Published var labelQ = ""
    @Published var labelR = ""
    @Published var buttonP = false
    @Published var buttonPQ = false
    @Published var buttonDelete = false
    @Published var logText = ""
    @Published private(set) var points: [(Int, Int)] = []

    weak var window: NSWindow?
    private var logWindow: NSWindow?

    init() {
        startLog()
    }

    func attach(window w: NSWindow) {
        window = w
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.logWindow?.close() }
        }
    }

    // MARK: Parameters

    var a: Double { fp ? Double(aFp) : Double(aScroll) / 100 }
    var b: Double { fp ? Double(bFp) : Double(bScroll) / 100 }
    var p: Int { Self.primes[pIndex] }
    var maxwert: Int { fp ? p : Self.zoomValues[cIndex] }
    var ppz: Int { 264 / Self.zoomValues[cIndex] }

    func setSpace(fp newValue: Bool) {
        guard newValue != fp else { return }
        fp = newValue
        if fp { aFp = 11; bFp = 20; computePoints() } else { aScroll = -1000; bScroll = 1500; cIndex = 3 }
        window?.title = fp ? ECCText.frameTitleFp : ECCText.frameTitleFr
        deletePoints()
    }

    func parametersChanged() {
        if fp { computePoints() }
        deletePoints()
    }

    func zoomChanged() { objectWillChange.send() }

    // MARK: Formatting

    static func fr(_ v: Double) -> String { String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") }
    static func fi(_ v: Double) -> String { String(Int(v.rounded())) }
    func fmt(_ v: Double) -> String { fp ? Self.fi(v) : Self.fr(v) }
    func pair(_ pt: ECCPt) -> String { "(" + fmt(pt.x) + "/" + fmt(pt.y) + ")" }

    /// Java's Double.toString for the curve in the log ("y^2 = x^3 - 10.0x + 15.0").
    private static func javaDouble(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e7 ? String(format: "%.1f", v) : "\(v)"
    }

    // MARK: Log (startLogDatei)

    func startLog() {
        var t = fp ? ECCText.logFpNumberSpace + "\(p) -----\n\n" : ECCText.logFrNumberSpace
        t += ECCText.logCurve + "y^2 = x^3"
        if a < 0 { t += " - " + Self.javaDouble(abs(a)) + "x" } else if a > 0 { t += " + " + Self.javaDouble(a) + "x" }
        if b < 0 { t += " - " + Self.javaDouble(abs(b)) } else if b > 0 { t += " + " + Self.javaDouble(b) }
        t += "\n"
        if fp {
            if !points.isEmpty {
                t += "\n" + ECCText.pointsText + " " + points.map { "(\($0.0)|\($0.1))" }.joined(separator: ", ") + "\n"
            }
        }
        logText = t
    }

    private func log(_ line: String) { logText += "\n" + line }

    func openLog() {
        let w = WindowPresenter.tool(id: "ct1games.ecclog", title: ECCText.logTitle, size: CGSize(width: 500, height: 250)) {
            ECCLogView(model: self)
        }
        logWindow = w
    }

    func closeLog() { logWindow?.close() }

    func exit() {
        logWindow?.close()
        window?.close()
    }

    // MARK: F_p points (berechnePunkte; computed mod p for negative a/b as well)

    func computePoints() {
        let p = self.p
        var r: [(Int, Int)] = []
        for x in 0..<p {
            let rhs = ((x * x * x + aFp * x + bFp) % p + p) % p
            for y in 0..<p where (y * y) % p == rhs { r.append((x, y)) }
        }
        points = r
    }

    // MARK: Delete points (ButtonDeleteClicked)

    func deletePoints() {
        pset = false; qset = false; rset = false; rNaN = false
        A = nil
        np = 1
        buttonP = false; buttonPQ = false; buttonDelete = false
        info = ECCText.start
        labelP = ""; labelQ = ""; labelR = ""
        startLog()
    }

    // MARK: Pixel transforms (GrafikFr / GrafikFp)

    private var fpScale: Double { Double(Self.canvas - 2 * Self.abstand) / Double(p - 1) }

    func xPixel(_ w: Double) -> Int {
        fp ? Int(fpScale * w + Double(Self.abstand)) : Int(w * Double(ppz) + 264)
    }

    func yPixel(_ w: Double) -> Int {
        fp ? Int(fpScale * (Double(p - 1) - w) + Double(Self.abstand)) : Int(264 - w * Double(ppz))
    }

    private func frX(_ px: Int) -> Double { Double(px - 264) / Double(ppz) }
    func f(_ x: Double) -> Double { x * x * x + a * x + b }
    private func frY(_ x: Double) -> Double {
        let y = f(x).squareRoot()
        return y.isNaN ? 0 : y
    }

    /// GrafikFr.punktAufKurve
    private func frOnCurve(_ x: Int, _ y: Int) -> Bool {
        let xw = frX(x)
        let yw = frY(xw)
        if yw == 0 && f(frX(x - 1)).squareRoot().isNaN && f(frX(x + 1)).squareRoot().isNaN { return false }
        let k = yPixel(yw)
        return abs(k - y) <= 3 || abs((Self.canvas - 1 - k) - y) <= 3
    }

    /// GrafikFp.punktAufKurve: closest x, then closest y on that x.
    private func fpNearest(_ x: Int, _ y: Int) -> (Int, Int)? {
        guard !points.isEmpty else { return nil }
        let xw = Double(x - Self.abstand) / fpScale
        let yw = Double(p - 1) - Double(y - Self.abstand) / fpScale
        var bx = points[0].0
        var dx = abs(Double(bx) - xw)
        for pt in points where abs(Double(pt.0) - xw) < dx { dx = abs(Double(pt.0) - xw); bx = pt.0 }
        var best: (Int, Int)?
        var dy = 0.0
        for pt in points where pt.0 == bx {
            let d = Double(Int(abs(Double(pt.1) - yw)))
            if best == nil || d < dy { best = pt; dy = d }
        }
        return best
    }

    // MARK: Mouse

    func hover(_ loc: CGPoint) {
        let x = Int(loc.x), y = Int(loc.y)
        guard !rset, !rNaN, !(pset && qset) else { return }
        if fp {
            if let pt = fpNearest(x, y) {
                let n = ECCPt(x: Double(pt.0), y: Double(pt.1))
                if A != n { A = n }
            }
        } else if frOnCurve(x, y) {
            let xw = frX(x)
            var yw = frY(xw)
            if y > (Self.canvas - 1) / 2 { yw = -yw }
            A = ECCPt(x: xw, y: yw)
        }
    }

    func click() {
        guard let a = A else { return }
        if !pset {
            P = a
            pset = true
            if !fp { A = nil }
            labelP = "P= " + pair(P)
            log(labelP)
            info = ECCText.p
            buttonP = true
            buttonDelete = true
        } else if !rset && !qset && !rNaN {
            Q = a
            qset = true
            labelQ = "Q= " + pair(Q)
            log(labelQ)
            info = ECCText.q
            buttonP = false
            buttonPQ = true
            buttonDelete = true
        }
    }

    // MARK: Arithmetic

    private func modp(_ v: Int) -> Int { ((v % p) + p) % p }

    private func inverse(_ m: Int) -> Int {
        var (r0, r1) = (modp(m), p)
        var (s0, s1) = (1, 0)
        while r1 != 0 {
            let q = r0 / r1
            (r0, r1) = (r1, r0 - q * r1)
            (s0, s1) = (s1, s0 - q * s1)
        }
        return modp(s0)
    }

    private func fpAdd(_ u: ECCPt, _ v: ECCPt) -> ECCPt? {
        let (x1, y1, x2, y2) = (Int(u.x), Int(u.y), Int(v.x), Int(v.y))
        if x1 == x2 && y1 == modp(-y2) { return nil }
        let lambda = (x1 == x2 && y1 == y2) ? modp((3 * x1 * x1 + aFp) * inverse(2 * y1))
                                             : modp((y1 - y2) * inverse(x1 - x2))
        let x3 = modp(lambda * lambda - x1 - x2)
        let y3 = modp(lambda * (x1 - x3) - y1)
        return ECCPt(x: Double(x3), y: Double(y3))
    }

    /// "P + Q" (ButtonAddierenPQClicked)
    func addPQ() {
        buttonPQ = false
        if fp {
            guard let r = fpAdd(P, Q) else {
                rset = false; rNaN = true
                R = ECCPt(x: 0, y: 0)
                info = ECCText.frAusPQNaN
                if np > 1 {
                    labelR = "R = \(np - 1)P + P = O"
                    log("\(np)P = O")
                } else {
                    labelR = "R = P + Q = O"
                    log(labelR)
                }
                return
            }
            R = r
            rset = true
            if np == 1 {
                labelR = "R = " + pair(R)
                info = ECCText.frpq
                log(labelR)
            } else {
                labelR = "R = \(np - 1)P + P = " + pair(R)
                log("\(np)P = " + pair(R))
                info = ECCText.frp
            }
            return
        }
        let lambda: Double
        let rx: Double
        if P == Q {
            if P.y == 0 { frInfinity(ECCText.rAusPQNaN); return }
            lambda = (3 * P.x * P.x + a) / (2 * P.y)
            rx = lambda * lambda - 2 * P.x
        } else {
            if P.x - Q.x == 0 { frInfinity(ECCText.rAusPQNaN); return }
            lambda = (P.y - Q.y) / (P.x - Q.x)
            rx = lambda * lambda - P.x - Q.x
        }
        rset = true
        R = ECCPt(x: rx, y: lambda * (P.x - rx) - P.y)
        if np == 1 {
            labelR = "R = " + pair(R)
            log(labelR)
            info = ECCText.rpq
        } else {
            labelR = "R = \(np - 1)P + P = " + pair(R)
            log(labelR)
            info = ECCText.rp
        }
    }

    private func frInfinity(_ text: [String]) {
        rset = false; rNaN = true
        info = text
        labelR = "R = O"
        log(labelR)
    }

    /// "n * P" (ButtonAddierenPPClicked, with F_p's "O + P" step).
    func multiply() {
        if rNaN && np > 1 {
            // R was the point at infinity: O + P = P
            rset = true; rNaN = false
            R = P
            qset = false
            np += 1
            labelQ = "\(np - 1)P = O"
            labelR = "R = \(np - 1)P + P = O + P = " + pair(R)
            log("\(np)P = " + pair(R))
            info = fp ? ECCText.frp : ECCText.rp
            return
        }
        if np > 1 {
            Q = R
            qset = true; rset = false
            np += 1
            labelQ = "\(np - 1)P = " + pair(Q)
            if !fp { log(labelQ) }
            addPQ()
        }
        if P.y == 0 {
            if fp {
                rset = true; rNaN = true
                R = ECCPt(x: 0, y: 0)
                info = ECCText.frAus2PNaN
                labelR = "R = " + (np - 1 == 0 ? "" : "\(np - 1)") + "P + P = O"
                log("\(np)P = O")
                if np == 1 { np += 1 }
            } else {
                rset = false; rNaN = true
                R = ECCPt(x: 0, y: 0)
                np = 1
                labelR = "R = O"
                log(labelR)
                info = ECCText.rAus2PNaN
            }
            return
        }
        if np == 1 {
            if fp {
                guard let r = fpAdd(P, P) else { return }
                R = r
                labelR = "2P = " + pair(R)
                info = ECCText.frp
            } else {
                let lambda = (3 * P.x * P.x + a) / (2 * P.y)
                let rx = lambda * lambda - 2 * P.x
                R = ECCPt(x: rx, y: lambda * (P.x - rx) - P.y)
                labelR = "R = 2P = " + pair(R)
                info = ECCText.rp
            }
            rset = true; rNaN = false
            np += 1
            log(labelR)
        }
    }
}

// MARK: - Window content (ECCFrame)

struct CT1ECCDemoView: View {
    @ObservedObject var model: ECCDemoModel

    private static let lila = Color(red: 148 / 255, green: 3 / 255, blue: 148 / 255)
    private static let magenta = Color(red: 1, green: 0, blue: 1)
    private static let grid = Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255)

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 18) {
                graph
                    .frame(width: CGFloat(ECCDemoModel.canvas), height: CGFloat(ECCDemoModel.canvas))
                textPanel.frame(width: 320, alignment: .leading)
            }
            controlPanel
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Text panel (TextPanel)

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ECCText.labelSpace).font(.custom("Times New Roman", size: 13).bold())
            Picker("", selection: Binding(get: { model.fp }, set: { model.setSpace(fp: $0) })) {
                Text(ECCText.buttonFr).tag(false)
                Text(ECCText.buttonFp).tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Text(ECCText.line).bold()
            ForEach(ECCText.intro, id: \.self) { Text($0) }
            Text(ECCText.line).bold()
            ForEach(Array(model.info.enumerated()), id: \.offset) { _, l in
                Text(l.isEmpty ? " " : l).foregroundColor(.blue)
            }
            Text(ECCText.line).bold()
            Text(model.labelP.isEmpty ? " " : model.labelP).bold().foregroundColor(.red)
            Text(model.labelQ.isEmpty ? " " : model.labelQ).bold().foregroundColor(.red)
            Text(model.labelR.isEmpty ? " " : model.labelR).bold().foregroundColor(Self.magenta)
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }

    // MARK: Control panel (BedienungsPanelFr / BedienungsPanelFp)

    private func scroller(_ value: Binding<Int>, _ range: ClosedRange<Int>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1; onChange() } } label: {
                Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.bordered).controlSize(.mini)
            Slider(value: Binding(get: { Double(value.wrappedValue) },
                                  set: { let v = Int($0.rounded()); if v != value.wrappedValue { value.wrappedValue = v; onChange() } }),
                   in: Double(range.lowerBound)...Double(range.upperBound))
                .controlSize(.mini)
                .frame(width: 62)
            Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1; onChange() } } label: {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.bordered).controlSize(.mini)
        }
    }

    private var controlPanel: some View {
        HStack(spacing: 6) {
            let boldTimes = Font.custom("Times New Roman", size: 13).bold()
            if model.fp {
                Text("a = \(model.aFp)").font(boldTimes).foregroundColor(.red).frame(width: 52, alignment: .leading)
                scroller($model.aFp, -99...99) { model.parametersChanged() }
                Text("b = \(model.bFp)").font(boldTimes).foregroundColor(Self.lila).frame(width: 52, alignment: .leading)
                scroller($model.bFp, -99...99) { model.parametersChanged() }
                Text("p = \(model.p)").font(boldTimes).frame(width: 46, alignment: .leading)
                scroller($model.pIndex, 0...23) { model.parametersChanged() }
            } else {
                Text("a = " + ECCDemoModel.fr(model.a)).font(boldTimes).foregroundColor(.red).frame(width: 72, alignment: .leading)
                scroller($model.aScroll, -5000...5099) { model.parametersChanged() }
                Text("b = " + ECCDemoModel.fr(model.b)).font(boldTimes).foregroundColor(Self.lila).frame(width: 72, alignment: .leading)
                scroller($model.bScroll, -5000...5099) { model.parametersChanged() }
                Text("Zoom:").font(boldTimes)
                scroller($model.cIndex, 0...9) { model.zoomChanged() }
            }
            Spacer(minLength: 4)
            Group {
                Button(" \(model.np + 1) * P ") { model.multiply() }.disabled(!model.buttonP)
                Button(" P + Q ") { model.addPQ() }.disabled(!model.buttonPQ)
                Button(ECCText.buttonDelete) { model.deletePoints() }.disabled(!model.buttonDelete)
                Button(ECCText.buttonLog) { model.openLog() }
                Button(ECCText.buttonExit) { model.exit() }
            }
            .fixedSize()
            .controlSize(.small)
        }
        .font(.system(size: 12))
    }

    // MARK: Graphics (GrafikFr / GrafikFp)

    private var graph: some View {
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: ECCDemoModel.canvas, height: ECCDemoModel.canvas)), with: .color(.white))
            if model.fp { drawFp(&ctx) } else { drawFr(&ctx) }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            if case .active(let loc) = phase { model.hover(loc) }
        }
        .gesture(SpatialTapGesture().onEnded { _ in model.click() })
        .overlay(Rectangle().stroke(Color.gray.opacity(0.4)))
    }

    private static let labelFont = Font.system(size: 14, weight: .bold)

    private func line(_ ctx: inout GraphicsContext, _ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ c: Color, _ w: CGFloat = 1) {
        var p = Path()
        p.move(to: CGPoint(x: CGFloat(x1) + 0.5, y: CGFloat(y1) + 0.5))
        p.addLine(to: CGPoint(x: CGFloat(x2) + 0.5, y: CGFloat(y2) + 0.5))
        ctx.stroke(p, with: .color(c), lineWidth: w)
    }

    private func dot(_ ctx: inout GraphicsContext, _ x: Int, _ y: Int, _ c: Color, big: Bool) {
        let (o, i): (CGFloat, CGFloat) = big ? (6, 4) : (5, 3)
        ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - o / 2 + 0.5, y: CGFloat(y) - o / 2 + 0.5, width: o, height: o)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - i / 2 + 0.5, y: CGFloat(y) - i / 2 + 0.5, width: i, height: i)), with: .color(c))
    }

    /// Java drawString: (x, y) is the baseline start.
    private func text(_ ctx: inout GraphicsContext, _ s: String, _ x: Int, _ y: Int, _ c: Color, _ font: Font = labelFont) {
        ctx.draw(Text(s).font(font).foregroundColor(c), at: CGPoint(x: CGFloat(x), y: CGFloat(y) + 3), anchor: .bottomLeading)
    }

    private func equation(_ ctx: inout GraphicsContext, x x0: CGFloat, baseline: CGFloat) {
        let big = Font.system(size: 14, weight: .bold), small = Font.system(size: 11, weight: .bold)
        var x = x0
        func put(_ s: String, _ c: Color, _ f: Font, dy: CGFloat = 0, pad: CGFloat = 0) {
            let r = ctx.resolve(Text(s).font(f).foregroundColor(c))
            let size = r.measure(in: CGSize(width: 1000, height: 100))
            ctx.draw(r, at: CGPoint(x: x, y: baseline + 3 + dy), anchor: .bottomLeading)
            x += size.width + pad
        }
        let fmt: (Double) -> String = model.fp ? ECCDemoModel.fi : ECCDemoModel.fr
        put("y", .blue, big, pad: 2); put("2", .blue, small, dy: -7)
        put(" = x", .blue, big, pad: 2); put("3", .blue, small, dy: -7)
        let a = model.a, b = model.b
        if a != 0 {
            put(a < 0 ? " - " : " + ", a < 0 ? .red : .blue, big, pad: 2)
            put(fmt(abs(a)), .red, big)
            put("x", .blue, big, pad: 2)
        }
        if b != 0 {
            put(b < 0 ? " - " : " + ", b < 0 ? Self.lila : .blue, big, pad: 2)
            put(fmt(abs(b)), Self.lila, big)
        }
        if model.fp {
            put(ECCText.graph1, .blue, big)
            put("F", .black, big)
            put("\(model.p)", .black, small, dy: 6)
            put(ECCText.graph2 + "\(model.points.count + 1)" + ECCText.graph3, .blue, big)
        }
    }

    // reals
    private func drawFr(_ ctx: inout GraphicsContext) {
        let size = ECCDemoModel.canvas, mid = (size - 1) / 2
        let ppz = model.ppz, maxwert = model.maxwert
        var yp = 0
        while yp <= size { line(&ctx, 0, yp, size, yp, Self.grid); yp += ppz }
        var xp = 0
        while xp <= size { line(&ctx, xp, 0, xp, size, Self.grid); xp += ppz }
        line(&ctx, mid, 0, mid, size, .black)
        line(&ctx, 0, mid, size, mid, .black)
        let axisFont = Font.system(size: 11)
        for v in (-maxwert + 1)...maxwert {
            let px = model.xPixel(Double(v)), py = model.yPixel(Double(v))
            if v % 5 == 0 && v != 0 && v != maxwert && (maxwert < 50 || v % 10 == 0) {
                let dxl = v <= -10 ? -10 : (v == -5 ? -7 : (v == 5 ? -3 : -7))
                text(&ctx, "\(v)", px + dxl, mid + 20, .black, axisFont)
                let dyl = v <= -10 ? -25 : (v == -5 ? -18 : (v == 5 ? -14 : -21))
                text(&ctx, "\(v)", mid + dyl, py + 5, .black, axisFont)
            }
            if v == maxwert {
                line(&ctx, px - ppz / 2 - 1, mid - 8, size - 1, mid, .black)
                line(&ctx, px - ppz / 2 - 1, mid + 8, size - 1, mid, .black)
                line(&ctx, mid - 8, py + ppz / 2 + 1, mid, 0, .black)
                line(&ctx, mid + 8, py + ppz / 2 + 1, mid, 0, .black)
            } else {
                let t = v % 5 == 0 ? 6 : 3
                line(&ctx, px, mid - t, px, mid + t, .black)
                line(&ctx, mid - t, py, mid + t, py, .black)
            }
        }
        // curve
        var upper = Path(), lower = Path()
        for x in 0..<(size - 1) {
            let y1 = frYValue(x), y2 = frYValue(x + 1)
            if y1 == 0 && y2 == 0 { continue }
            let p1 = model.yPixel(y1), p2 = model.yPixel(y2)
            upper.move(to: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(p1) + 0.5))
            upper.addLine(to: CGPoint(x: CGFloat(x + 1) + 0.5, y: CGFloat(p2) + 0.5))
            lower.move(to: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(size - 2 - p1) + 0.5))
            lower.addLine(to: CGPoint(x: CGFloat(x + 1) + 0.5, y: CGFloat(size - 2 - p2) + 0.5))
        }
        ctx.stroke(upper, with: .color(.blue), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        ctx.stroke(lower, with: .color(.blue), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        equation(&ctx, x: 10, baseline: CGFloat(size - 10))
        drawFrPoints(&ctx)
    }

    private func frYValue(_ xPixel: Int) -> Double {
        let x = Double(xPixel - 264) / Double(model.ppz)
        let y = model.f(x).squareRoot()
        return y.isNaN ? 0 : y
    }

    /// zeichneLinie: line through A and B, extended by 3 units on both sides.
    private func extendedLine(_ ctx: inout GraphicsContext, _ a: ECCPt, _ b: ECCPt, _ c: Color) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return }
        let ux = dx / len * 3, uy = dy / len * 3
        let p1 = ECCPt(x: a.x - ux, y: a.y - uy), p2 = ECCPt(x: b.x + ux, y: b.y + uy)
        line(&ctx, model.xPixel(p1.x), model.yPixel(p1.y), model.xPixel(p2.x), model.yPixel(p2.y), c, 1.8)
    }

    private func drawFrPoints(_ ctx: inout GraphicsContext) {
        let m = model, h = ECCDemoModel.canvas
        let px = m.xPixel(m.P.x), py = m.yPixel(m.P.y)
        let qx = m.xPixel(m.Q.x), qy = m.yPixel(m.Q.y)
        let rx = m.xPixel(m.R.x), ry = m.yPixel(m.R.y)
        let minusR = ECCPt(x: m.R.x, y: -m.R.y)
        let pq = m.pset && m.qset && px == qx && py == qy
        if m.rset && m.qset {
            if (rx < qx && qx < px) || (rx > qx && qx > px) { extendedLine(&ctx, m.P, minusR, Self.lila) }
            if (rx < px && px <= qx) || (rx > px && px >= qx) { extendedLine(&ctx, m.Q, minusR, Self.lila) }
            if (rx <= px && rx >= qx) || (rx >= px && rx <= qx) { extendedLine(&ctx, m.P, m.Q, Self.lila) }
            let lbl = m.np > 1 ? "R = \(m.np)P" : "R"
            text(&ctx, lbl, rx + 8, m.R.y < 0 ? ry - 4 : ry + 13, Self.magenta)
            extendedLine(&ctx, minusR, m.R, Self.magenta)
            dot(&ctx, rx, h - ry, Self.lila, big: true)
            text(&ctx, "-R", rx + 8, m.R.y > 0 ? h - ry - 4 : h - ry + 13, Self.lila)
            dot(&ctx, rx, ry, Self.magenta, big: true)
        }
        if m.rset && !m.qset {
            extendedLine(&ctx, m.P, minusR, Self.lila)
            extendedLine(&ctx, minusR, m.R, Self.magenta)
            dot(&ctx, rx, h - ry, Self.lila, big: true)
            text(&ctx, "-R", rx + 8, h - ry + 8, Self.lila)
            dot(&ctx, rx, ry, Self.magenta, big: true)
            text(&ctx, m.np > 2 ? "R = P = \(m.np)P" : "R = 2P", rx + 8, m.R.y < 0 ? ry - 4 : ry + 13, Self.magenta)
        }
        if m.rNaN { line(&ctx, px, h, px, 0, Self.lila, 1.8) }
        if !(m.pset && m.qset) && !m.rset && !m.rNaN, let a = m.A {
            let ax = m.xPixel(a.x), ay = m.yPixel(a.y)
            dot(&ctx, ax, ay, .red, big: true)
            text(&ctx, m.pair(a), ax + 10, a.y < 0 ? ay - 4 : ay + 13, .red)
        }
        if !pq && m.pset {
            dot(&ctx, px, py, .red, big: true)
            text(&ctx, "P", px + 8, m.P.y < 0 ? py - 4 : py + 13, .red)
        }
        if !pq && m.qset {
            dot(&ctx, qx, qy, .red, big: true)
            text(&ctx, m.np > 1 ? "\(m.np - 1)P" : "Q", qx + 8, m.Q.y < 0 ? qy - 4 : qy + 13, .red)
        }
        if pq {
            dot(&ctx, qx, qy, .red, big: true)
            text(&ctx, m.np == 1 ? "P = Q" : "P = \(m.np)P", qx + 8, m.Q.y < 0 ? qy - 4 : qy + 13, .red)
        }
    }

    // F_p
    private func drawFp(_ ctx: inout GraphicsContext) {
        let m = model, h = ECCDemoModel.canvas, ab = ECCDemoModel.abstand, maxwert = m.p
        for i in 0..<maxwert {
            line(&ctx, m.xPixel(Double(i)), m.yPixel(0), m.xPixel(Double(i)), m.yPixel(Double(maxwert - 1)), Self.grid)
            line(&ctx, m.xPixel(0), m.yPixel(Double(i)), m.xPixel(Double(maxwert - 1)), m.yPixel(Double(i)), Self.grid)
        }
        line(&ctx, m.xPixel(0), m.yPixel(0), m.xPixel(0), m.yPixel(Double(maxwert - 1)), .black)
        line(&ctx, m.xPixel(0), m.yPixel(0), m.xPixel(Double(maxwert - 1)), m.yPixel(0), .black)
        let axisFont = Font.system(size: 11)
        for v in 1..<maxwert {
            let px = m.xPixel(Double(v)), py = m.yPixel(Double(v))
            if v % 5 == 0 {
                if v == 5 { text(&ctx, "5", px - 3, h - ab + 20, .black, axisFont); text(&ctx, "5", ab - 14, py + 5, .black, axisFont) }
                if v >= 10 { text(&ctx, "\(v)", px - 7, h - ab + 20, .black, axisFont); text(&ctx, "\(v)", ab - 21, py + 5, .black, axisFont) }
                line(&ctx, px, h - ab - 6, px, h - ab + 6, .black)
                line(&ctx, ab - 6, py, ab + 6, py, .black)
            }
            if maxwert <= 11 && v <= 10 && v % 5 != 0 {
                text(&ctx, "\(v)", px - 3, h - ab + 20, .black, axisFont)
                text(&ctx, "\(v)", ab - 14, py + 5, .black, axisFont)
            }
            line(&ctx, px, h - ab - 3, px, h - ab + 3, .black)
            line(&ctx, ab - 3, py, ab + 3, py, .black)
        }
        for pt in m.points { dot(&ctx, m.xPixel(Double(pt.0)), m.yPixel(Double(pt.1)), .cyan, big: false) }
        equation(&ctx, x: 20, baseline: 15)
        drawFpPoints(&ctx)
    }

    private func fpLabel(_ ctx: inout GraphicsContext, _ s: String, _ x: Int, _ y: Int, _ c: Color) {
        let half = ECCDemoModel.canvas / 2
        let tx = x > half ? x - 8 - 7 * s.utf8.count : x + 8
        let ty = y > half ? y - 8 : y + 14
        text(&ctx, s, tx, ty, c)
    }

    private func drawFpPoints(_ ctx: inout GraphicsContext) {
        let m = model
        let px = m.xPixel(m.P.x), py = m.yPixel(m.P.y)
        let qx = m.xPixel(m.Q.x), qy = m.yPixel(m.Q.y)
        let rx = m.xPixel(m.R.x), ry = m.yPixel(m.R.y)
        let pq = m.pset && m.qset && px == qx && py == qy
        if m.rset && m.qset && !m.rNaN {
            fpLabel(&ctx, m.np > 1 ? "R = \(m.np)P" : "R", rx, ry, Self.magenta)
            dot(&ctx, rx, ry, Self.magenta, big: false)
        }
        if m.rset && !m.qset && m.np <= 2 && !m.rNaN {
            dot(&ctx, rx, ry, Self.magenta, big: false)
            fpLabel(&ctx, "R = 2P", rx, ry, Self.magenta)
        }
        if m.rset && !m.qset && m.np > 2 {
            dot(&ctx, rx, ry, .red, big: false)
            fpLabel(&ctx, "R = P = \(m.np)P", rx, ry, .red)
        }
        if !(m.pset && m.qset) && !m.rset && !m.rNaN, let a = m.A {
            let ax = m.xPixel(a.x), ay = m.yPixel(a.y)
            dot(&ctx, ax, ay, .red, big: false)
            fpLabel(&ctx, m.pair(a), ax, ay, .red)
        }
        if !pq && m.pset {
            dot(&ctx, px, py, .red, big: false)
            fpLabel(&ctx, "P", px, py, .red)
        }
        if !pq && m.qset {
            dot(&ctx, qx, qy, .red, big: false)
            fpLabel(&ctx, m.np > 1 ? "\(m.np - 1)P" : "Q", qx, qy, .red)
        }
        if pq {
            dot(&ctx, qx, qy, .red, big: false)
            fpLabel(&ctx, m.np == 1 ? "P = Q" : "P = \(m.np - 1)P", qx, qy, .red)
        }
    }
}

// MARK: - Non-modal log window (LogDatei)

struct ECCLogView: View {
    @ObservedObject var model: ECCDemoModel
    var body: some View {
        VStack(spacing: 6) {
            TextEditor(text: .constant(model.logText))
                .font(.system(size: 12, design: .monospaced))
                .frame(minWidth: 480, minHeight: 200)
            Button(" OK ") { model.closeLog() }.keyboardShortcut(.defaultAction)
        }
        .padding(6)
    }
}
