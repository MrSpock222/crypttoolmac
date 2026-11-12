import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 number fields with digit grouping ("1.234.567", IDS_INTEGRAL_NUMBER_SEPARATOR ".").
func ntGrouped(_ digits: String) -> String {
    var out: [Character] = []
    for (i, c) in digits.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { out.append(".") }
        out.append(c)
    }
    return String(out.reversed())
}

// MARK: - Mersenne numbers (CT1 IDD_COMPUTE_MERSENNE_NUMBERS)

struct MersenneView: View {
    @StateObject private var ref = CT1WindowRef()
    @CTState private var baseText = "2"
    @CTState private var exponentText = "10"
    @CTState private var resultText = ""
    @CTState private var lengthText = ""
    @CTState private var result: String?
    @CTState private var running = false
    @CTState private var token = CancellationToken()
    /// Values of the last computation (CT1 `mersenneComputationParameters`).
    @CTState private var lastBase = ""
    @CTState private var lastExponent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Beschreibung") {
                Text("Dieser Dialog berechnet Mersenne-artige Zahlen b^e-1 auch dann sehr schnell, wenn sie sehr groß sind. Sowohl die Basis b als auch der Exponent e bestehen aus natürlichen Zahlen.")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Basis b:").gridColumnAlignment(.trailing)
                    TextField("", text: $baseText).frame(width: 120).disabled(running)
                }
                GridRow {
                    Text("Exponent e:")
                    TextField("", text: $exponentText).disabled(running)
                }
                GridRow {
                    Text("Ergebnis b^e - 1:")
                    NTReadOnlyText(text: resultText)
                }
                GridRow {
                    Text("Ergebnislänge:")
                    HStack {
                        NTReadOnlyText(text: lengthText).frame(width: 120)
                        Text("(Anzahl der Dezimalstellen)")
                    }
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Button("Berechnung starten", action: start).keyboardShortcut(.defaultAction).disabled(running)
                    Button("Berechnung abbrechen", action: cancel).disabled(!running)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Button("Primzahltest", action: primeTest).disabled(result == nil || running)
                    Button("Ergebnis in Datei schreiben", action: writeToFile).disabled(result == nil || running)
                    HStack {
                        CT1HelpButton(action: .mersenne)
                        Button("Schließen") { ref.window?.close() }.disabled(running)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 520)
        .ct1Window(title: "Mersenne-Zahlen berechnen", ref: ref)
        .onChange(of: baseText) { _, v in fieldChanged($baseText, v) }
        .onChange(of: exponentText) { _, v in fieldChanged($exponentText, v) }
    }

    private func fieldChanged(_ binding: Binding<String>, _ v: String) {
        let grouped = ntGrouped(v.filter(\.isNumber))
        if grouped != v { binding.wrappedValue = grouped }
        if !running { resultText = ""; lengthText = ""; result = nil }
    }

    private func start() {
        let bDigits = baseText.filter(\.isNumber), eDigits = exponentText.filter(\.isNumber)
        let b = BigUInt(bDigits) ?? BigUInt()
        // CT1 reads the exponent with strtoul (32 bit)
        let e = Int(UInt32(clamping: UInt64(eDigits.prefix(19)) ?? 0))
        lastBase = b.description; lastExponent = "\(e)"
        if b > 1 && Double(e) * ntLog2(b) > 4_294_967_296 {
            // guard against results of more than 512 MB (CT1 would run out of memory)
            Alerts.error("Das Ergebnis ist zu groß (mehr als 2^32 Bit). Bitte wählen Sie eine kleinere Basis oder einen kleineren Exponenten.")
            return
        }
        let t = CancellationToken(); token = t
        running = true
        result = nil
        resultText = "Die Berechnung läuft..."; lengthText = ""
        Task.detached(priority: .userInitiated) {
            let startTime = Date()
            var r: BigUInt? = nil
            if e == 0 || b.isZero {
                r = e == 0 ? BigUInt() : nil
            } else if b == 2 {
                r = (BigUInt(1) << e) - 1
            } else {
                // square and multiply with cancellation (CT1 computeMersenneNumber)
                var acc = BigUInt(1), x = b, k = e
                while k > 0 && !t.isCancelled {
                    if k & 1 == 1 { acc = acc * x }
                    k >>= 1
                    if k > 0 { x = x * x }
                }
                if !t.isCancelled { r = acc - 1 }
            }
            let seconds = Date().timeIntervalSince(startTime)
            let decimal = t.isCancelled ? nil : (r ?? BigUInt()).description
            await MainActor.run {
                guard !t.isCancelled, let decimal else { return }
                running = false
                if b.isZero && e > 0 {
                    // 0^e − 1 is negative: CT1 (apint) prints "-1"
                    result = "-1"
                } else {
                    result = decimal
                }
                if seconds > 1 {
                    Alerts.info(String(format: "Benötigte Zeit für die Berechnung der Mersenne-Zahl: %.0f Sekunden", seconds))
                }
                show(result!)
            }
        }
    }

    private func show(_ r: String) {
        if r.count > 100_000 {
            Alerts.info("Das Ergebnis ist sehr groß. Deshalb wird es nur in Teilen im Dialog angezeigt.\r\nBitte schreiben Sie das Ergebnis in eine Datei, um es vollständig zu betrachten.")
            resultText = String(r.prefix(10)) + "..." + String(r.suffix(10))
        } else {
            resultText = r.hasPrefix("-") ? r : ntGrouped(r)
        }
        lengthText = ntGrouped("\(r.filter(\.isNumber).count)")
    }

    private func cancel() {
        token.cancel()
        running = false
        result = nil
        resultText = "Die Berechnung wurde abgebrochen."; lengthText = ""
    }

    private func primeTest() {
        guard let r = result else { return }
        if r.count > CT1BigNumber.maxDigits { Alerts.info(NTMessages.bigNumber); return }
        WindowPresenter.tool(title: "Primzahltest", size: CGSize(width: 600, height: 520)) {
            PrimeTestView(initialNumber: r)
        }
    }

    private func writeToFile() {
        guard let r = result else { return }
        if r.count > 100_000 {
            Alerts.info("Das Ergebnis ist sehr groß. Es in eine Datei zu schreiben und anzuzeigen, wird eine gewisse Zeit dauern.")
        }
        let text = "b: \(lastBase)\r\ne: \(lastExponent)\r\nr: \(r)\r\n"
        DocumentFactory.openResult(text: text, title: "Mersenne-Zahl \(lastBase)^\(lastExponent) - 1")
    }
}

// MARK: - Length of a number (CT1 IDD_LENGTHOFANUMBER)

struct NumberLengthView: View {
    @StateObject private var ref = CT1WindowRef()
    /// 0 binary, 1 octal, 2 decimal (default), 3 hexadecimal.
    @CTState private var representation = 2
    @CTState private var number = "0"
    /// Evaluated value of the current input (nil = invalid).
    @CTState private var value: BigUInt? = BigUInt()

    private static let bases = [2, 8, 10, 16]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Beschreibung") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dieser Dialog berechnet die Länge einer Zahl (in Zeichen).")
                    Text("Sie können die Zahl in vier verschiedenen Darstellungsformen eingeben (binär, oktal, dezimal, hexadezimal). Sobald die Zahl verändert wird, wird die Länge für jede Darstellungsform sofort aktualisiert.")
                    Text("Falls die dezimale Darstellung ausgewählt ist, können Sie auch Formeln eingeben (das Ändern der Darstellung zeigt den jeweiligen Zahlenwert an).")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Eingabe-Darstellung") {
                Picker("", selection: Binding(get: { representation }, set: { switchRepresentation($0) })) {
                    Text("Binär").tag(0); Text("Oktal").tag(1); Text("Dezimal").tag(2); Text("Hexadezimal").tag(3)
                }
                .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                .disabled(value == nil)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Zahl") {
                TextField("", text: $number).font(.system(.body, design: .monospaced)).padding(4)
            }
            GroupBox("Ergebnis (Länge der Zahl in Zeichen)") {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                    row("Binär:", 2); row("Oktal:", 8); row("Dezimal:", 10); row("Hexadezimal:", 16)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Spacer()
                CT1HelpButton(action: .numberLength)
                Button("Schließen") { ref.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 520)
        .ct1Window(title: "Länge einer Zahl", ref: ref)
        .onChange(of: number) { _, _ in updateNumber() }
    }

    private func row(_ label: String, _ radix: Int) -> some View {
        GridRow {
            Text(label)
            Text(value.map { "\($0.toString(radix: radix).count)" } ?? "-").monospacedDigit()
        }
    }

    private func updateNumber() {
        let base = Self.bases[representation]
        var s = number.uppercased()
        let allowed: Set<Character>
        switch base {
        case 2: allowed = Set("01")
        case 8: allowed = Set("01234567")
        case 10: allowed = Set("0123456789+-*^()")
        default: allowed = Set("0123456789ABCDEF")
        }
        s = String(s.filter { allowed.contains($0) })
        if s != number { number = s; return }
        if s.isEmpty { value = nil; return }
        if base == 10 {
            if let v = try? BigExpression.evaluate(s), !v.isNegative { value = v.magnitude } else { value = nil }
        } else {
            value = BigUInt(s, radix: base)
        }
    }

    private func switchRepresentation(_ new: Int) {
        guard new != representation else { return }
        let v = value
        representation = new
        if let v { number = v.toString(radix: Self.bases[new]) }
        updateNumber()
    }
}
