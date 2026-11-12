import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 IDD_CRT_TRANSFORMATION: "Visualisierung Hin- und Rücktransformation von Zahlen in
/// Berechnungen mit Hilfe des CRT" (DlgCrtTransformation.cpp).
struct CT1CRTTransformationDialog: View {
    static let title = "Visualisierung Hin- und Rücktransformation von Zahlen in Berechnungen mit Hilfe des CRT"

    @StateObject private var win = CT1WindowRef()
    /// 0 Multiplikation (default), 1 Addition, 2 Subtraktion
    @CTState private var op = 0
    @CTState private var aText = ""
    @CTState private var bText = ""
    /// 0 = "Moduln selbst eingeben", 1 = "Prime Moduln generieren lassen" (default)
    @CTState private var genMode = 1
    @CTState private var lower = "2^185"
    @CTState private var upper = "2^186"
    @CTState private var count = "5"
    @CTState private var m = Array(repeating: "", count: 5)
    // results
    @CTState private var range = ""
    @CTState private var ma = ""
    @CTState private var mb = ""
    @CTState private var mab = ""
    @CTState private var basis = ""
    @CTState private var back = ""
    @CTState private var x = ""

    private var canSolve: Bool { m.contains { !$0.isEmpty } && !aText.isEmpty && !bText.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox {
                Text("Dieser Dialog visualisiert die Hin- und Rücktransformation der Zifferndarstellung in die modulare Darstellung mit Hilfe des Chinesischen Restsatzes (CRT).\nNach Auswahl der mathematischen Operation, der Eingabe der Zahlen A und B sowie der höchstens 5 Moduln kann die Berechnung über den Button \"Lösen\" gestartet werden.")
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CRTGroup(title: "Zifferndarstellung") {
                        CRTGroup(title: "1. Mathematische Operation auswählen:") {
                            Picker("", selection: Binding(get: { op }, set: { op = $0; clearResults() })) {
                                Text("Multiplikation").tag(0); Text("Addition").tag(1); Text("Subtraktion").tag(2)
                            }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                        }
                        CRTGroup(title: "2. Bitte zwei Zahlen eingeben:") {
                            numberRow("Zahl A", Binding(get: { aText }, set: { aText = CRTUtil.digits($0); clearResults() }))
                            numberRow("Zahl B", Binding(get: { bText }, set: { bText = CRTUtil.digits($0); clearResults() }))
                        }
                        CRTGroup(title: "3. Bitte die Felder der Moduln mit paarweise primen Zahlen füllen:") {
                            Picker("", selection: Binding(get: { genMode }, set: { genMode = $0; m = Array(repeating: "", count: 5); clearResults() })) {
                                Text("Moduln selbst eingeben").tag(0); Text("Prime Moduln generieren lassen ").tag(1)
                            }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                            if genMode == 1 {
                                HStack {
                                    Text("Wertebereich der Primzahlen innerhalb des Intervalls:")
                                    Spacer()
                                    Text("Anzahl:")
                                    TextField("", text: Binding(get: { count }, set: { count = CRTUtil.digits($0); clearResults() })).frame(width: 36)
                                }
                                HStack {
                                    Text("Untergrenze:")
                                    TextField("", text: Binding(get: { lower }, set: { lower = $0; clearResults() })).frame(width: 80)
                                    Text("Obergrenze:")
                                    TextField("", text: Binding(get: { upper }, set: { upper = $0; clearResults() })).frame(width: 80)
                                    Spacer()
                                    Button("Generieren", action: generate)
                                }
                            }
                            ForEach(0..<5, id: \.self) { i in
                                numberRow("Modul \(i + 1)", Binding(get: { m[i] }, set: { m[i] = CRTUtil.digits($0); clearResults() }))
                            }
                        }
                    }
                    CRTGroup(title: "Darstellbarer Zahlenbereich (abhängig von der Größe der Moduln)") { CRTOutputField(text: range) }
                    CRTGroup(title: "Lösung") { CRTOutputField(text: x) }
                    HStack {
                        Button("Lösen", action: solve).keyboardShortcut(.defaultAction).disabled(!canSolve)
                        Button("Zurücksetzen", action: reset)
                        Button("Beenden") { win.window?.close() }
                        Spacer()
                        CT1HelpButton(action: .crtTransformation)
                    }
                }
                .frame(width: 470)
                VStack(alignment: .leading, spacing: 10) {
                    CRTGroup(title: "Modulare Darstellung") {
                        HStack { Text("Zahl A").frame(width: 50, alignment: .leading); CRTOutputField(text: ma) }
                        HStack { Text("Zahl B").frame(width: 50, alignment: .leading); CRTOutputField(text: mb) }
                    }
                    Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                    CRTGroup(title: "Ergebnis der Operation") { CRTOutputField(text: mab) }
                    Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                    CRTGroup(title: "Basisberechnung") { CRTOutputField(text: basis) }
                    CRTGroup(title: "Rücktransformation") { CRTOutputField(text: back, multiline: true, minHeight: 170) }
                }
                .frame(minWidth: 320)
            }
        }
        .padding(14)
        .frame(minWidth: 820, minHeight: 690, alignment: .topLeading)
        .ct1Window(title: Self.title, ref: win)
        .crtMinWindowSize(840, 720)
    }

    private func numberRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            TextField("", text: text).font(.system(.body, design: .monospaced))
        }
    }

    private func clearResults() { x = ""; ma = ""; mb = ""; mab = ""; basis = ""; range = ""; back = "" }

    private func reset() {
        m = Array(repeating: "", count: 5); aText = ""; bText = ""; clearResults()
        op = 0; genMode = 1; lower = "2^185"; upper = "2^186"; count = "5"
    }

    // MARK: Generieren (CT1 OnBnClickedGenerate1 / GeneratePrime)

    private func generate() {
        m = Array(repeating: "", count: 5)
        clearResults()
        guard let n = Int(count), n >= 1, n <= 5 else {
            CRTUtil.message("Es können nur 1 bis 5 Primzahlen erzeugt werden!"); return
        }
        if lower.trimmingCharacters(in: .whitespaces).isEmpty || upper.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Geben Sie Ober- und Untergrenze ein!"); return
        }
        let inputFalse = "In diesem Feld wird eine Zahl oder ein Ausdruck erwartet,\naus dem sich ein Zahlenwert berechnen lässt.\nBitte geben Sie einen gültigen Ausdruck ein!\n\nBeispiele: 123, 2^15+1, (2^17-5)^2."
        guard let lo = CRTUtil.formula(lower) else { Alerts.error(inputFalse); return }
        guard let hi = CRTUtil.formula(upper) else { Alerts.error(inputFalse); return }
        let tooBig = "Die Demonstration unterstützt nur positive ganze Zahlen der Bitlänge kleiner 186.\nDas sind Zahlen mit höchstens 56 Dezimalstellen.\nBitte senken Sie den Wertebereich. "
        if hi.isZero || hi.description.count > 56 || lo.description.count > 56 { CRTUtil.message(tooBig); return }
        if lo > hi { Alerts.error("Die Untergrenze darf nicht größer als die Obergrenze sein!"); return }
        var primes: [BigUInt] = []
        for _ in 0..<n {
            var found: BigUInt?
            for _ in 0..<10 {
                if let p = CRTUtil.randomPrime(lo, hi), !primes.contains(p) { found = p; break }
            }
            guard let p = found else {
                CRTUtil.message("Beim zufälligen Generieren der Primzahlen für die benötigten \(n) Moduln sind Primzahlen doppelt aufgetreten.\nFür die Anwendung des Chinesischen Restsatzes müssen die Module jedoch alle verschieden sein.\nBitte drücken Sie (evtl. mehrfach) erneut den Button 'Generieren' oder vergrößern Sie das Intervall für den Wertebereich der Primzahlen.\n")
                return
            }
            primes.append(p)
        }
        primes.sort()
        for (i, p) in primes.enumerated() { m[i] = p.description }
    }

    // MARK: Lösen (CT1 OnBnClickedCrtTransformationButtonsolve)

    private func vector(_ v: [BigInt]) -> String { "(" + v.map(\.description).joined(separator: ", ") + ")" }

    private func solve() {
        let a = BigInt(BigUInt(aText) ?? 0), b = BigInt(BigUInt(bText) ?? 0)
        let filled = m.filter { !$0.isEmpty }
        let mods = filled.map { BigInt(BigUInt($0) ?? 0) }
        var M = BigInt(1)
        for mi in mods { M *= mi }
        // testeteilerfremd
        var ok = true, one = false, text = ""
        for i in 0..<5 {
            for j in (i + 1)..<5 where !m[i].isEmpty && !m[j].isEmpty {
                let mi = BigUInt(m[i]) ?? 0, mj = BigUInt(m[j]) ?? 0
                if !mi.gcd(mj).isOne {
                    text += "Modul \(i + 1) (\(m[i])) und Modul \(j + 1) (\(m[j])) sind nicht teilerfremd.\n"
                    ok = false
                }
            }
            if m[i] == "1" || m[i] == "0" { ok = false; one = true }
        }
        if one { CRTUtil.message("Das Modul m muss größer als 1 sein !") }
        if !text.isEmpty {
            CRTUtil.message(text + "\nTeilerfremde Moduln sind eine Voraussetzung für die Anwendung des Chinesischen Restsatzes. \n")
        }
        guard ok, !mods.isEmpty else { return }
        let rangeText = "0 bis " + (M - BigInt(1)).description
        let res: BigInt = op == 0 ? a * b : (op == 1 ? a + b : a - b)
        if (op == 0 && a * b > M) || (op == 1 && a + b > M) || (op == 2 && (a - b > M || a - b < BigInt(0))) {
            range = rangeText
            if op == 2 && a - b < BigInt(0) {
                CRTUtil.message("Das Ergebnis darf nicht negativ sein. Berechnet wurde \(res.description).\n")
            } else {
                CRTUtil.message("Der Zahlenbereich [\(rangeText)] wurde überschritten. Berechnet wurde \(res.description).\nDeshalb ist keine Lösung mit den gewählten Moduln möglich.")
            }
            return
        }
        let va = mods.map { a % $0 }, vb = mods.map { b % $0 }
        var vo: [BigInt] = []
        for i in mods.indices {
            switch op {
            case 0: vo.append((va[i] * vb[i]) % mods[i])
            case 1: vo.append((va[i] + vb[i]) % mods[i])
            default: vo.append((va[i] - vb[i]) % mods[i])   // CT1: may be negative
            }
        }
        var e: [BigInt] = []
        for mi in mods {
            let Mi = M / mi
            let inv = Mi.magnitude.inverse(modulo: mi.magnitude) ?? 0
            e.append(BigInt(inv) * Mi)
        }
        var sum = BigInt(0)
        for i in mods.indices { sum += e[i] * vo[i] }
        let result = sum.modulo(M.magnitude)
        ma = vector(va); mb = vector(vb); mab = vector(vo); basis = vector(e)
        var r = ""
        for i in mods.indices {
            r += "(\(vo[i].description)*\(e[i].description))\n"
            r += i < mods.count - 1 ? "+" : " mod \(M.description)"
        }
        back = r
        x = CRTUtil.thousands(result.description)
        range = rangeText
    }
}
