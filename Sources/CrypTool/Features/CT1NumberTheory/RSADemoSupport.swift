import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// Options of the CT1 RSA demo (IDD_OPTIONS_RSA_DEMO, CDlgOptionsRSADemo).
struct RSADemoOptions: Equatable {
    /// 0 "Alle 256 Zeichen", 1 "Alphabet vorgeben".
    var textOptions = 0
    var alphabet = RSATextCodec.defaultAlphabet
    /// 0 "Normal", 1 "Dialog der Schwestern".
    var variant = 0
    /// 0 "b-adisch", 1 "Basissystem".
    var coding = 0
    /// 0 Dezimal, 1 Binär, 2 Oktal, 3 Hexadezimal (CT1 radio order).
    var numberBasis = 0
    var blockLength = -1

    var alphabetSize: Int { textOptions == 0 ? 256 : alphabet.count }
    var base: Int { [10, 2, 8, 16][numberBasis] }

    /// CT1 `GetBlockLength()` (maximal block length).
    func maxBlockLength(modulus n: BigUInt?) -> Int {
        guard let n, n > 2 else { return 0 }
        if variant == 1 { return 1 }
        let a = Double(max(2, alphabetSize))
        let log2N = ntLog2(n)
        if coding == 0 {
            return Int(floor(log2N / (log(a) / log(2.0))))
        }
        let bl1 = log(a) / log(2.0)
        let b1 = Double(base)
        let b2 = ceil(log(a) / log(b1))
        let b3 = b2 * log(b1) / log(2.0)
        var bl = Int(floor(Double(n.bitLength - 1) / b3))
        if Double(bl) * b3 + bl1 <= log2N { bl += 1 }
        return bl
    }

    /// CT1 `CompareModulAlphabetSize`: alphabet size < N (N with more than 3 digits counts as 1000).
    func alphabetFits(_ n: BigUInt?) -> Bool {
        guard let n else { return false }
        let m = n.description.count > 3 ? 1000 : Int(n.description) ?? 0
        return alphabetSize < m
    }
}

/// log2(n) for display/limits.
func ntLog2(_ n: BigUInt) -> Double {
    let bits = n.bitLength
    if bits <= 53 { return log2(Double(n.uint64Value ?? 1)) }
    let top = (n >> (bits - 53)).uint64Value ?? 1
    return log2(Double(top)) + Double(bits - 53)
}

/// CT1 codec functions of IntegerArithmetic.cpp (encode/decode/BigToCString).
enum RSADemoCodec {
    static func digits(alphabetSize a: Int, base: Int) -> Int {
        Int(ceil(log(Double(a)) / log(Double(base))))
    }

    static func modul(alphabetSize a: Int, base: Int, basisSystem: Bool) -> Int {
        if !basisSystem { return a }
        var m = base
        for _ in 1..<max(1, digits(alphabetSize: a, base: base)) { m *= base }
        return m
    }

    static func pad(_ s: String, _ length: Int) -> String {
        s.count >= length ? s : String(repeating: "0", count: length - s.count) + s
    }

    /// CT1 `encode`: block digit values → number string in `base` (zero-padded).
    static func encode(_ values: [Int], alphabetSize a: Int, base: Int, basisSystem: Bool) -> String {
        let m = modul(alphabetSize: a, base: base, basisSystem: basisSystem)
        let outLength = basisSystem ? digits(alphabetSize: a, base: base) * values.count
                                    : Int(ceil(log(Double(a)) / log(Double(base)) * Double(values.count)))
        var t = BigUInt()
        for v in values { t = t * BigUInt(m) + BigUInt(v) }
        return pad(t.toString(radix: base), outLength)
    }

    /// CT1 `decode`: number → digit values; nil if it does not yield exactly `blockLength` characters.
    static func decode(_ t0: BigUInt, alphabetSize a: Int, base: Int, basisSystem: Bool, blockLength: Int) -> [Int]? {
        let m = UInt64(modul(alphabetSize: a, base: base, basisSystem: basisSystem))
        var t = t0
        var out: [Int] = []
        var i = 0
        while i < blockLength || !t.isZero {
            let (q, r) = t.quotientAndRemainder(dividingBy: m)
            out.append(Int(r % UInt64(a)))
            t = q
            i += 1
        }
        return i == blockLength ? Array(out.reversed()) : nil
    }

    /// Output length of RSA results: ceil((bits(N) − 1) / log2(base)).
    static func outLength(_ n: BigUInt, base: Int) -> Int {
        Int(ceil(Double(n.bitLength - 1) / (log(Double(base)) / log(2.0))))
    }

    /// Tokens of a number stream (CT1 NUMBER_SEPARATOR " \r\n#,;:"); nil if a token is not a number in `base`.
    static func numberTokens(_ s: String, base: Int) -> [BigUInt]? {
        let seps = Set(" \r\n#,;:\t")
        var out: [BigUInt] = []
        for tok in s.split(whereSeparator: { seps.contains($0) }) {
            guard let v = BigUInt(String(tok).uppercased(), radix: base) else { return nil }
            out.append(v)
        }
        return out
    }

    static func cp1252Bytes(_ s: String) -> [UInt8] {
        [UInt8](s.data(using: .windowsCP1252, allowLossyConversion: true) ?? Data())
    }

    static func cp1252String(_ b: [UInt8]) -> String {
        b.map { byte in
            String(bytes: [byte], encoding: .windowsCP1252) ?? String(bytes: [byte], encoding: .isoLatin1) ?? "?"
        }.joined()
    }

    static func isPrintable(_ b: UInt8) -> Bool { b >= 32 && b != 127 }
}

// MARK: - Options dialog

struct RSADemoOptionsView: View {
    @CTState var options: RSADemoOptions
    let modulus: BigUInt?
    var onOK: (RSADemoOptions) -> Void
    var close: () -> Void
    @CTState private var blockText = ""

    var body: some View {
        let maxBL = options.maxBlockLength(modulus: modulus)
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Alphabetoptionen") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        NTRadio(title: "Alle 256 Zeichen", selected: options.textOptions == 0) { options.textOptions = 0; options.coding = 0 }
                            .disabled(options.variant == 1)
                        Spacer()
                        Text("Anzahl Zeichen: \(options.alphabetSize)")
                    }
                    NTRadio(title: "Alphabet vorgeben:", selected: options.textOptions == 1) { options.textOptions = 1 }
                    TextField("", text: $options.alphabet).font(.system(.body, design: .monospaced))
                        .disabled(options.textOptions == 0).padding(.leading, 18)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("RSA-Variante ") {
                HStack(spacing: 20) {
                    NTRadio(title: "Normal", selected: options.variant == 0) { options.variant = 0 }
                    NTRadio(title: "Dialog der Schwestern", selected: options.variant == 1) {
                        options.variant = 1; options.textOptions = 1; options.coding = 0
                    }
                    Spacer()
                }.padding(4)
            }
            GroupBox("Methode, wie ein Block als Zahl codiert wird") {
                HStack(spacing: 20) {
                    NTRadio(title: "b-adisch", selected: options.coding == 0) { options.coding = 0 }
                    NTRadio(title: "Basissystem", selected: options.coding == 1) { options.coding = 1 }.disabled(options.variant == 1)
                    Spacer()
                }.padding(4)
            }
            GroupBox("Blocklänge") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Die Anzahl der Zeichen, die pro RSA-Operation verschlüsselt werden.\nDie maximale Anzahl ist abhängig von der Bitlänge des RSA-Moduls N, der Anzahl der Zeichen im Alphabet und der Codierungsmethode der Nachricht.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Blocklänge in Zeichen:")
                        TextField("", text: $blockText).frame(width: 50).disabled(options.variant == 1)
                        Text("(Maximale Blocklänge \(maxBL) Zeichen)")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Zahlensystem ") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Die Zahlen der RSA-Ver-/Entschlüsselung werden in dem folgenden Zahlensystem dargestellt.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 20) {
                        NTRadio(title: "Dezimal", selected: options.numberBasis == 0) { options.numberBasis = 0 }
                        NTRadio(title: "Binär", selected: options.numberBasis == 1) { options.numberBasis = 1 }
                        NTRadio(title: "Oktal", selected: options.numberBasis == 2) { options.numberBasis = 2 }
                        NTRadio(title: "Hexadezimal", selected: options.numberBasis == 3) { options.numberBasis = 3 }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 470)
        .onAppear {
            let m = options.maxBlockLength(modulus: modulus)
            if options.blockLength <= 0 || options.blockLength > m { options.blockLength = m }
            if options.blockLength == 0 { options.blockLength = 1 }
            blockText = "\(options.blockLength)"
        }
        .onChange(of: options.alphabet) { _, v in
            // CT1 removes duplicate characters while typing
            var seen = Set<Character>(); var out = ""
            for c in v where !seen.contains(c) { seen.insert(c); out.append(c) }
            if out != v { options.alphabet = out }
        }
        .onChange(of: options) { _, o in
            // CT1 MsgBlockLength: clamp to the new maximum
            let m = max(1, o.maxBlockLength(modulus: modulus))
            if (Int(blockText) ?? 0) > m || o.variant == 1 { blockText = "\(o.variant == 1 ? 1 : m)" }
        }
    }

    private func ok() {
        var o = options
        o.blockLength = Int(blockText) ?? 0
        let maxBL = o.maxBlockLength(modulus: modulus)
        let nText = modulus?.description ?? ""
        if o.variant == 1 {
            let m = nText.count > 3 ? 1000 : Int(nText) ?? 0
            if o.alphabetSize > m {
                Alerts.error("Bitte ändern Sie das Alphabet, so dass die Anzahl der Zeichen im Alphabet (hier \(o.alphabetSize)) kleiner oder gleich der Größe des RSA-Moduls (hier N = \(nText)) ist.")
                return
            }
            o.blockLength = 1
        } else if maxBL == 0 {
            Alerts.error("Bitte ändern Sie das Alphabet, so dass die Anzahl der Zeichen im Alphabet (hier \(o.alphabetSize)) kleiner oder gleich der Größe des RSA-Moduls (hier N = \(nText)) ist.")
            return
        } else if maxBL == 1 && o.blockLength != 1 {
            Alerts.error("Bitte setzen Sie die Blocklänge auf 1.")
            return
        } else if o.blockLength < 1 || o.blockLength > maxBL {
            Alerts.error("Die Blocklänge muss aus dem Zahlenbereich 1, ..., \(maxBL) sein!")
            return
        }
        onOK(o)
        close()
    }
}

/// Radio button with a (possibly multi-line) label.
struct NTRadio: View {
    let title: String
    let selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(title).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Read-only multi-line step field of the RSA demo.
struct NTStepBox: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text.isEmpty ? " " : text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}
