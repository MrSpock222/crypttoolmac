import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Schlüsseleingabe: Homophone Substitution" (IDD_KEY_HOMOPHONE, DlgKeyHomophone.cpp,
// HomophoneEncryption.cpp, Cryptography.cpp HomophoneAsc). The ciphertext is binary: every code is
// written with ⌈log₂ Gesamtzahl⌉ bits (256 → one byte per code) and opened in the hex view.

struct HomophoneDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var countText = "256"
    @CTState private var codeCount = 256
    @CTState private var binaryInput = false
    @CTState private var formatChars = false
    @CTState private var umlauts = false
    @CTState private var hexDisplay = true
    @CTState private var key: HomophoneKey?
    @CTState private var selected: Character?

    /// Alphabet used for the key: text options alphabet, with "Formatierungen mit verschlüsseln"
    /// CR, TAB and LF are inserted in front (as CT1 does).
    private var options: TextOptions {
        var o = settings.textOptions
        if formatChars { o.alphabet = "\r\t\n" + o.alphabet.filter { $0 != "\r" && $0 != "\t" && $0 != "\n" } }
        return o
    }

    private var bitLength: Int { Homophone.bitLength(codeCount) }

    var body: some View {
        DialogScaffold(title: "Key Entry: Homophonic Substitution", minWidth: 680) {
            HStack(alignment: .top) {
                CT1Group(title: "Total count and bit length of the homophones") {
                    HStack {
                        Text("Total number:").frame(width: 80, alignment: .leading)
                        TextField("", text: $countText).frame(width: 50)
                            .ct1Filter($countText) { s in
                                let d = s.filter { $0.isASCII && $0.isNumber }
                                return (String(d.prefix(5)), d.count != s.count)
                            }
                        Button("Update") { actualize() }
                    }
                    HStack {
                        Text("Bit length:").frame(width: 80, alignment: .leading)
                        Text("\(bitLength)").frame(width: 50, alignment: .trailing).font(.system(.body, design: .monospaced))
                        Text("bits")
                    }
                }
                CT1Group(title: "Encryption options") {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("Consider input document as")
                            HStack {
                                CT1Radio(title: "Text", selected: !binaryInput) { binaryInput = false }
                                CT1Radio(title: "Binary data", selected: binaryInput) { binaryInput = true }
                            }
                        }
                        VStack(alignment: .leading) {
                            Toggle("Include formatting\nwith encryption", isOn: $formatChars)
                            Toggle("Encode umlauts", isOn: $umlauts)
                        }.disabled(binaryInput)
                    }
                }
            }
            Text("Key table for homophonic substitution")
            keyTable.frame(height: 220)
            CT1Group(title: "Display of homophones") {
                HStack {
                    CT1Radio(title: "Hexadecimal", selected: hexDisplay) { hexDisplay = true }
                    CT1Radio(title: "Decimal", selected: !hexDisplay) { hexDisplay = false }
                }
            }
            Text("Show the list of homophones for an individual character (select according line above via double click):")
                .font(.callout)
            HStack(alignment: .top) {
                VStack(alignment: .leading) { Text("Character:").font(.caption); CT1ReadOnlyLine(text: selected.map(display) ?? "") }.frame(width: 60)
                VStack(alignment: .leading) { Text("Number:").font(.caption); CT1ReadOnlyLine(text: selected.map { String(key?.table[$0]?.count ?? 0) } ?? "") }.frame(width: 60)
                VStack(alignment: .leading) { Text("List of homophones:").font(.caption); CT1ReadOnlyLine(text: selected.map { codesText($0) } ?? "") }
            }
            HStack {
                Button("Generate random key") { generate() }
                CT1PasteKeyButton(method: "homophone") { pasteKey($0) }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: key == nil,
                          textOptions: !binaryInput, help: .homophone)
        }
        .onAppear {
            binaryInput = !document.isText
            generate()
        }
        .onChange(of: binaryInput) { _, _ in generate() }
        .onChange(of: formatChars) { _, _ in generate() }
        .onChange(of: settings.textOptions) { _, _ in if !binaryInput { generate() } }
    }

    // MARK: table

    private var rows: [Character] {
        guard let key else { return [] }
        return key.table.keys.filter { !(key.table[$0] ?? []).isEmpty }.sorted { code($0) < code($1) }
    }

    private func code(_ c: Character) -> Int { Int(c.unicodeScalars.first?.value ?? 0) }

    private func display(_ c: Character) -> String {
        switch c {
        case "\n": return "LF"
        case "\r": return "CR"
        case "\t": return "TAB"
        case " ": return "' '"
        default:
            let v = code(c)
            return v < 32 || (v >= 127 && v < 160) ? String(format: "0x%02X", v) : String(c)
        }
    }

    private func codesText(_ c: Character) -> String {
        (key?.table[c] ?? []).map { hexDisplay ? String(format: "%X", $0) : String($0) }.joined(separator: " ")
    }

    private var frequencies: [Character: Double] {
        binaryInput ? HomophoneDialog.byteFrequencies(document.bytes)
                    : (HomophoneDialog.frequencies(from: settings.referenceText, options: options) ?? [:])
    }

    private var keyTable: some View {
        let freq = frequencies
        return VStack(spacing: 0) {
            HStack {
                Text("Ord").frame(width: 44, alignment: .leading)
                Text("Character").frame(width: 60, alignment: .leading)
                Text("Frequency").frame(width: 80, alignment: .leading)
                Text("Count").frame(width: 50, alignment: .leading)
                Text("List of homophones").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption.bold()).padding(4)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows, id: \.self) { c in
                        HStack {
                            Text(String(code(c))).frame(width: 44, alignment: .leading)
                            Text(display(c)).frame(width: 60, alignment: .leading)
                            Text(String(format: "%.2f", (freq[c] ?? 0) * 100)).frame(width: 80, alignment: .leading)
                            Text(String(key?.table[c]?.count ?? 0)).frame(width: 50, alignment: .leading)
                            Text(codesText(c)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(selected == c ? Color.accentColor.opacity(0.25) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { selected = c }
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }

    // MARK: key generation

    static func frequencies(from text: String, options: TextOptions) -> [Character: Double]? {
        let idx = options.indices(of: text)
        guard !idx.isEmpty else { return nil }
        let chars = options.alphabetCharacters
        var counts = [Int](repeating: 0, count: chars.count)
        for i in idx { counts[i] += 1 }
        var out: [Character: Double] = [:]
        for (i, c) in chars.enumerated() { out[c] = Double(counts[i]) / Double(idx.count) }
        return out
    }

    static func byteFrequencies(_ bytes: [UInt8]) -> [Character: Double] {
        var counts = [Int](repeating: 0, count: 256)
        for b in bytes { counts[Int(b)] += 1 }
        let total = Double(max(1, bytes.count))
        var out: [Character: Double] = [:]
        for i in 0..<256 { out[Character(Unicode.Scalar(UInt8(i)))] = Double(counts[i]) / total }
        return out
    }

    private func actualize() {
        let minimum = binaryInput ? 256 : options.alphabetSize
        var v = Int(countText) ?? 256
        if v < minimum { v = minimum }
        countText = String(v)
        if v != codeCount { codeCount = v; generate() }
    }

    private func generate() {
        selected = nil
        if binaryInput {
            if codeCount < 256 { codeCount = 256; countText = "256" }
            let freq = HomophoneDialog.byteFrequencies(document.bytes)
            let chars = (0..<256).map { Character(Unicode.Scalar(UInt8($0))) }
            let counts = Homophone.allocate(frequencies: chars.map { freq[$0] ?? 0 }, total: codeCount)
            var codes = Array(0..<codeCount).shuffled()
            var table: [Character: [Int]] = [:]
            for (i, c) in chars.enumerated() {
                table[c] = Array(codes.prefix(counts[i]))
                codes.removeFirst(min(counts[i], codes.count))
            }
            key = HomophoneKey(table: table, codeCount: codeCount)
        } else {
            let o = options
            if codeCount < o.alphabetSize { codeCount = o.alphabetSize; countText = String(codeCount) }
            key = Homophone.generateKey(options: o, letterFrequencies: HomophoneDialog.frequencies(from: settings.referenceText, options: o),
                                        codeCount: codeCount)
        }
    }

    /// CHomophoneEncryption::GetKeyStr: "<count hex> <type>###<char hex>:<codes hex,…> # …".
    private func keyString(_ key: HomophoneKey) -> String {
        var s = String(format: "%X %X###", key.codeCount, binaryInput ? 1 : 0)
        for c in rows where code(c) < 256 {
            s += String(format: "%X", code(c)) + ":" + (key.table[c] ?? []).map { String(format: "%X", $0) }.joined(separator: ",") + " # "
        }
        return s
    }

    private func pasteKey(_ s: String) {
        guard let sep = s.range(of: "###") else { return }
        let head = s[..<sep.lowerBound].split(separator: " ")
        guard let count = head.first.flatMap({ Int($0, radix: 16) }) else { return }
        var table: [Character: [Int]] = [:]
        for entry in s[sep.upperBound...].components(separatedBy: " # ") {
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let ch = Int(parts[0].trimmingCharacters(in: .whitespaces), radix: 16), ch < 256 else { continue }
            table[Character(Unicode.Scalar(UInt8(ch)))] = parts[1].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces), radix: 16) }
        }
        guard !table.isEmpty else { return }
        binaryInput = head.count > 1 && head[1] == "1"
        codeCount = count
        countText = String(count)
        key = HomophoneKey(table: table, codeCount: count)
    }

    private func run(_ encrypt: Bool) {
        guard let key else { return }
        KeyMemory.rememberObject(key, for: "homophone")
        let keyStr = keyString(key)
        let title = CT1.title("Homophone", encrypt: encrypt, of: document, key: keyStr)
        if encrypt {
            let codes: [Int]
            if binaryInput {
                var rng = SystemRandomNumberGenerator()
                let byByte = (0..<256).map { key.table[Character(Unicode.Scalar(UInt8($0)))] ?? [] }
                codes = document.bytes.compactMap { b in
                    let c = byByte[Int(b)]
                    return c.isEmpty ? nil : c[Int.random(in: 0..<c.count, using: &rng)]
                }
            } else {
                codes = Homophone.encrypt(document.text, key: key, options: options, transcribeUmlauts: umlauts)
            }
            if CipherRun.open(bytes: document, method: "homophone", title: title, key: keyStr, viewMode: .hex, {
                Homophone.pack(codes, codeCount: key.codeCount)
            }) != nil { close() }
        } else {
            let codes = Homophone.unpack(document.bytes, codeCount: key.codeCount)
            if binaryInput {
                let table = key.decryptionTable
                if CipherRun.open(bytes: document, method: "homophone", title: title, key: keyStr, {
                    codes.compactMap { table[$0].flatMap { $0.unicodeScalars.first.map { UInt8(truncatingIfNeeded: $0.value) } } }
                }) != nil { close() }
            } else {
                if CipherRun.open(text: document, method: "homophone", title: title, key: keyStr, {
                    Homophone.decrypt(codes, key: key)
                }) != nil { close() }
            }
        }
    }
}
