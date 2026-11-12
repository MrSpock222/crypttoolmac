import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 IDD_CRT_ASTRONOMY: "Anwendungsbeispiel des Chinesischen Restsatze aus der Astronomie:
/// Planetenumlaufbahn" (DlgCrtAstronomy.cpp).
struct CT1CRTAstronomyDialog: View {
    static let title = "Anwendungsbeispiel des Chinesischen Restsatze aus der Astronomie: Planetenumlaufbahn"
    static let planets: [(name: String, period: String)] = [
        ("Merkur", "88"), ("Venus", "225"), ("Erde", "365"), ("Mars", "687"), ("Jupiter", "4327"),
        ("Saturn", "10751"), ("Uranus", "30661"), ("Neptun", "60149"), ("Pluto", "90491"),
    ]
    static let initialA = ["15", "", "100", "", "", "", "", "", ""]
    static let initialM = ["88", "", "365", "", "", "", "", "", ""]
    static let initialChecks = [true, false, true, false, false, false, false, false, false]

    @StateObject private var win = CT1WindowRef()
    @CTState private var a = CT1CRTAstronomyDialog.initialA
    @CTState private var m = CT1CRTAstronomyDialog.initialM
    @CTState private var checks = CT1CRTAstronomyDialog.initialChecks
    @CTState private var x = ""
    @CTState private var period = ""
    @CTState private var merkurTag = "15"
    @CTState private var erdeTag = "100"

    /// CT1 testdata(): every row complete or empty, at least one complete row.
    private var canSolve: Bool {
        var empty = 0
        for i in 0..<9 {
            if a[i].isEmpty != m[i].isEmpty { return false }
            if a[i].isEmpty { empty += 1 }
        }
        return empty < 9
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                Text("Mit dem Chinesischen Restsatz (CRT) kann man lineare modulare Gleichungssysteme lösen. Unten können Sie 9 Gleichungen der Form x = a[i] mod m[i] (i=1, ..., 9) eingeben und anschließend lösen. Solche Gleichungssysteme kann man z.B. nutzen, um herauszufinden, in wie viel Tagen bestimmte Planeten aufgereiht wie auf einer Perlenschnur hintereinander in einer Linie (Strahl) stehen.")
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CRTGroup(title: "Simultane Kongruenzen/ Modulare lineare Gleichungssysteme") {
                        ForEach(0..<9, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text("x ≡")
                                TextField("", text: Binding(get: { a[i] }, set: { setA(i, $0) }))
                                Text("mod")
                                TextField("", text: Binding(get: { m[i] }, set: { setM(i, $0) }))
                            }.font(.system(.body, design: .monospaced))
                        }
                    }
                    CRTGroup(title: "Lösung") { CRTOutputField(text: x) }
                    HStack {
                        Button("Lösen", action: solve).keyboardShortcut(.defaultAction).disabled(!canSolve)
                        Button("Beenden") { win.window?.close() }
                        Spacer()
                        CT1HelpButton(action: .crtAstronomy)
                    }
                    HStack {
                        Button("Löschen aller Parameter", action: clearAll)
                        Button("Zurücksetzen auf den Initialzustand", action: resetInitial)
                    }
                }
                .frame(width: 400)
                CRTGroup(title: "Anwendungsbeispiel aus der Astronomie / Film-Visualisierung ist fix") {
                    CRTOrbitSketch().frame(height: 150).frame(maxWidth: .infinity)
                    Text("Die Umlaufzeiten der Planeten Merkur und Erde um die Sonne betragen 88 und 365 Tage. Bis zum Erreichen eines bestimmten Bahnradiusvektors s (rot) vergehen")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        CRTOutputField(text: merkurTag).frame(width: 80)
                        Text("und")
                        CRTOutputField(text: erdeTag).frame(width: 80)
                        Text("Tage.")
                    }
                    Text("Kann es vorkommen, dass sich Merkur und Erde irgendwann einmal auf dem Strahl s befinden?")
                        .fixedSize(horizontal: false, vertical: true)
                    CRTGroup(title: "Planetenauswahl") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 2) {
                            ForEach(0..<3, id: \.self) { r in
                                GridRow {
                                    ForEach(0..<3, id: \.self) { c in
                                        let i = c * 3 + r
                                        Toggle(Self.planets[i].name, isOn: Binding(get: { checks[i] }, set: { togglePlanet(i, $0) }))
                                    }
                                }
                            }
                        }
                    }
                    Text("In welchen Zeitabständen (Tagen) wiederholt sich das Ereignis?")
                    CRTOutputField(text: period)
                }
                .frame(minWidth: 330)
            }
        }
        .padding(14)
        .frame(minWidth: 780, minHeight: 600, alignment: .topLeading)
        .ct1Window(title: Self.title, ref: win)
        .crtMinWindowSize(800, 620)
    }

    // MARK: Field logic (CT1 OnEnChange… / OnBnClickedCheck…)

    private func setA(_ i: Int, _ v: String) {
        a[i] = CRTUtil.digits(v)
        if i == 0 { merkurTag = checks[0] ? a[0] : "" }
        if i == 2 { erdeTag = checks[2] ? a[2] : "" }
        x = ""; period = ""
    }

    private func setM(_ i: Int, _ v: String) {
        let d = CRTUtil.digits(v)
        if d != m[i] { checks[i] = false }
        m[i] = d
        x = ""; period = ""
    }

    private func togglePlanet(_ i: Int, _ on: Bool) {
        checks[i] = on
        m[i] = on ? Self.planets[i].period : ""
        a[i] = on ? "0" : ""
        if i == 0 { merkurTag = on ? a[0] : "" }
        if i == 2 { erdeTag = on ? a[2] : "" }
        x = ""; period = ""
    }

    private func clearAll() {
        a = Array(repeating: "", count: 9); m = Array(repeating: "", count: 9)
        checks = Array(repeating: false, count: 9)
        x = ""; period = ""; merkurTag = ""; erdeTag = ""
    }

    private func resetInitial() {
        a = Self.initialA; m = Self.initialM; checks = Self.initialChecks
        x = ""; period = ""; merkurTag = "15"; erdeTag = "100"
    }

    // MARK: Solve (CT1 OnBnClickedCrtAstronomyButtonsolve)

    private func solve() {
        if m.contains(where: { $0 == "0" || $0 == "1" }) {
            CRTUtil.message("Das Modul m muss größer als 1 sein !")
            return
        }
        var rows: [Int] = []
        for i in 0..<9 where !m[i].isEmpty && !a[i].isEmpty { rows.append(i) }
        guard !rows.isEmpty else { return }
        let mods = rows.map { BigUInt(m[$0]) ?? 1 }
        let rems = rows.map { BigUInt(a[$0]) ?? 0 }
        // pairwise coprime? (CT1 testeteilerfremd – over all filled modulus fields)
        var text = ""
        for i in 0..<9 {
            for j in (i + 1)..<9 where !m[i].isEmpty && !m[j].isEmpty {
                let mi = BigUInt(m[i]) ?? 1, mj = BigUInt(m[j]) ?? 1
                if !mi.gcd(mj).isOne {
                    text += "Die Umlaufzeiten von \(Self.planets[i].name) (\(m[i])) und \(Self.planets[j].name) (\(m[j])) sind nicht teilerfremd.\n"
                }
            }
        }
        if !text.isEmpty {
            CRTUtil.message(text + "\nDie Moduln sind nicht teilerfremd.\n\nDeshalb ist die Anwendbarkeit des Chinesischen Restsatzes nicht garantiert. \n\nEine Lösung wird jetzt gesucht.\n")
        }
        if let (sol, M) = ChineseRemainder.solve(remainders: rems, moduli: mods) {
            x = CRTUtil.thousands(sol.description)
            period = CRTUtil.thousands(M.description)
        } else {
            CRTUtil.message("Das Brute-Force-Verfahren konnte keine Lösung finden.\n")
            x = "Es existiert keine Lösung!"
            period = ""
        }
    }
}

/// Static replacement for CT1's fixed orbit animation (IDR_CRT_ASTRONOMY): sun, the orbits of
/// Mercury and Earth and the red radius vector s.
struct CRTOrbitSketch: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r2 = min(size.width, size.height) / 2 - 8
            let r1 = r2 * 0.45
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)), with: .color(.black))
            for r in [r1, r2] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(.gray), lineWidth: 1)
            }
            var ray = Path(); ray.move(to: c); ray.addLine(to: CGPoint(x: c.x + r2 + 6, y: c.y - (r2 + 6) * 0.35))
            ctx.stroke(ray, with: .color(.red), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(.yellow))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r1 - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.orange))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5, y: c.y + r2 - 5, width: 10, height: 10)), with: .color(.blue))
            ctx.draw(Text("s").foregroundColor(.red).font(.caption.bold()), at: CGPoint(x: c.x + r2 - 6, y: c.y - r2 * 0.42))
        }
    }
}
