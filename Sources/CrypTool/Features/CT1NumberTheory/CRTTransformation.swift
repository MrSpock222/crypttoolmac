import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 IDD_CRT_TRANSFORMATION: "Visualisierung Hin- und Rücktransformation von Zahlen in
/// Berechnungen mit Hilfe des CRT" (DlgCrtTransformation.cpp).
struct CT1CRTTransformationDialog: View {
    static let title = "Visualization of the Transformation from Number Notation into the Modular Representation with the CRT"

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
                Text("This dialog is supposed to show the transformation of the integer number notation into the set of the according modular number representation - based on the Chinese Remainder Theorem (CRT).  After selecting the mathematical operation, entering the numbers A and B and entering the modules, you can click on 'Solve' to start the visualization.")
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CRTGroup(title: "Number notation") {
                        CRTGroup(title: "1. Choose a mathematic operation:") {
                            Picker("", selection: Binding(get: { op }, set: { op = $0; clearResults() })) {
                                Text("Multiplication").tag(0); Text("Addition").tag(1); Text("Subtraction").tag(2)
                            }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                        }
                        CRTGroup(title: "2. Please enter two numbers:") {
                            numberRow("A:", Binding(get: { aText }, set: { aText = CRTUtil.digits($0); clearResults() }))
                            numberRow("B:", Binding(get: { bText }, set: { bText = CRTUtil.digits($0); clearResults() }))
                        }
                        CRTGroup(title: "3. Please enter modules, that are relatively prime to each other:") {
                            Picker("", selection: Binding(get: { genMode }, set: { genMode = $0; m = Array(repeating: "", count: 5); clearResults() })) {
                                Text("enter modules manually").tag(0); Text("generate prime modules automatically").tag(1)
                            }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                            if genMode == 1 {
                                HStack {
                                    Text("Range of values for prime numbers within this closed interval:")
                                    Spacer()
                                    Text("Number:")
                                    TextField("", text: Binding(get: { count }, set: { count = CRTUtil.digits($0); clearResults() })).frame(width: 36)
                                }
                                HStack {
                                    Text("Lower limit:")
                                    TextField("", text: Binding(get: { lower }, set: { lower = $0; clearResults() })).frame(width: 80)
                                    Text("Upper limit:")
                                    TextField("", text: Binding(get: { upper }, set: { upper = $0; clearResults() })).frame(width: 80)
                                    Spacer()
                                    Button("Generate", action: generate)
                                }
                            }
                            ForEach(0..<5, id: \.self) { i in
                                numberRow("Module \(i + 1)", Binding(get: { m[i] }, set: { m[i] = CRTUtil.digits($0); clearResults() }))
                            }
                        }
                    }
                    CRTGroup(title: "Representable range (depends on the size of the modules)") { CRTOutputField(text: range) }
                    CRTGroup(title: "Solution") { CRTOutputField(text: x) }
                    HStack {
                        Button("Solve", action: solve).keyboardShortcut(.defaultAction).disabled(!canSolve)
                        Button("Reset", action: reset)
                        Button("Exit") { win.window?.close() }
                        Spacer()
                        CT1HelpButton(action: .crtTransformation)
                    }
                }
                .frame(width: 470)
                VStack(alignment: .leading, spacing: 10) {
                    CRTGroup(title: "Modular representation") {
                        HStack { Text("A:").frame(width: 50, alignment: .leading); CRTOutputField(text: ma) }
                        HStack { Text("B:").frame(width: 50, alignment: .leading); CRTOutputField(text: mb) }
                    }
                    Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                    CRTGroup(title: "Result of operation") { CRTOutputField(text: mab) }
                    Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                    CRTGroup(title: "Base calculation") { CRTOutputField(text: basis) }
                    CRTGroup(title: "Transformation back") { CRTOutputField(text: back, multiline: true, minHeight: 170) }
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
            CRTUtil.message("Only 1 to 5 prime numbers can be generated!"); return
        }
        if lower.trimmingCharacters(in: .whitespaces).isEmpty || upper.trimmingCharacters(in: .whitespaces).isEmpty {
            CRTUtil.message("Enter an upper limit and a lower limit."); return
        }
        let inputFalse = "Please enter into this field an integer or an expression, that\nevaluates to an integer!\nExamples: 123, 2^15+1, (2^17-5)^2."
        guard let lo = CRTUtil.formula(lower) else { Alerts.error(inputFalse); return }
        guard let hi = CRTUtil.formula(upper) else { Alerts.error(inputFalse); return }
        let tooBig = "The demonstration supports only positive integers of bit length smaller than 186.\nThese are decimal numbers with at most 56 digits.\nPlease decrease the Co-domain."
        if hi.isZero || hi.description.count > 56 || lo.description.count > 56 { CRTUtil.message(tooBig); return }
        if lo > hi { Alerts.error("The lower limit must not be greater than the upper limit!"); return }
        var primes: [BigUInt] = []
        for _ in 0..<n {
            var found: BigUInt?
            for _ in 0..<10 {
                if let p = CRTUtil.randomPrime(lo, hi), !primes.contains(p) { found = p; break }
            }
            guard let p = found else {
                CRTUtil.message("While generating prime numbers for \(n) moduli, some of these numbers arose doubly.\nTo apply the Chinese remainder theorem, all these modules have to be different.\nPlease click 'Generate' again or increase the range of values for the prime numbers.\n")
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
                    text += "Module \(i + 1) (\(m[i])) and module \(j + 1) (\(m[j])) are not coprime.\n"
                    ok = false
                }
            }
            if m[i] == "1" || m[i] == "0" { ok = false; one = true }
        }
        if one { CRTUtil.message("The module m has to be larger than 1!") }
        if !text.isEmpty {
            CRTUtil.message(text + "\nCoprime modules are a pre-condition to apply the Chinese remainder theorem. \n")
        }
        guard ok, !mods.isEmpty else { return }
        let rangeText = "0 to " + (M - BigInt(1)).description
        let res: BigInt = op == 0 ? a * b : (op == 1 ? a + b : a - b)
        if (op == 0 && a * b > M) || (op == 1 && a + b > M) || (op == 2 && (a - b > M || a - b < BigInt(0))) {
            range = rangeText
            if op == 2 && a - b < BigInt(0) {
                CRTUtil.message("The result must be non-negative. \(res.description) was calculated.\n")
            } else {
                CRTUtil.message("The range [\(rangeText)] was exceeded. \(res.description) was calculated.\nUnder this circumstance, no solution with the chosen modules is possible.")
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
