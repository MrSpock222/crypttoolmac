import AppKit
import SwiftUI
import CTCommon
import CTModern

/// CT1 hash list of the hash demo / HMAC / file hash dialogs (CT1 order).
let ct1HashOrder: [HashAlgorithm] = [.md2, .md4, .md5, .sha0, .sha1, .sha256, .sha512, .ripemd160]

extension HashAlgorithm {
    /// CT1 combo entry, e.g. "MD2 (128 bits)".
    var ct1ComboName: String { "\(displayName) (\(digestLength * 8) bits)" }
}

// MARK: - Hash value (CT1 IDD_SHOW_HASH "%s-Hashwert von <%s>")

struct HashResultSheet: View {
    let algorithm: HashAlgorithm
    let document: CTDocument
    let close: () -> Void
    @CTState private var digest: [UInt8] = []

    var body: some View {
        PKIHashValueView(algorithm: algorithm, digest: digest, sourceName: document.shortName, parent: document, close: close)
            .onAppear { digest = Hashing.hash(document.bytes, algorithm: algorithm) }
    }
}

/// Body of CT1's "Hashwert" dialog: caption, hex value, "Hashwert als HEX-Datei" / "Schließen".
struct PKIHashValueView: View {
    let algorithm: HashAlgorithm
    let digest: [UInt8]
    let sourceName: String
    let parent: CTDocument?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(algorithm.displayName) hash of <\(sourceName)>").font(.title3.weight(.semibold))
            ResultBox(text: Hex.encode(digest), minHeight: 44)
            HStack {
                Button("Store hash value to HEX format") {
                    DocumentFactory.openResult(digest, title: "\(algorithm.displayName) hash of <\(sourceName)>",
                                               parent: parent, viewMode: .hex)
                    close()
                }
                Spacer()
                PKIHelpButton(action: .hash(algorithm.rawValue))
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 560)
    }
}

// MARK: - Hash of a file (CT1 HashOfAFile: file dialog → "Hashfunktion wählen" → hash dialog)

struct FileHashView: View {
    @CTState private var url: URL?
    @CTState private var algorithm: HashAlgorithm = .md2
    @CTState private var digest: [UInt8]?
    @CTState private var busy = false
    @CTState private var started = false
    @StateObject private var windowBox = PKIWindowBox()

    var body: some View {
        Group {
            if let d = digest, let u = url {
                PKIHashValueView(algorithm: algorithm, digest: d, sourceName: u.lastPathComponent, parent: nil) { windowBox.window?.close() }
            } else if url != nil {
                VStack(alignment: .leading, spacing: 10) {
                    PKIGroup("Hash function") {
                        Picker("", selection: $algorithm) {
                            ForEach(ct1HashOrder, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.radioGroup).labelsHidden()
                    }
                    .frame(width: 220)
                    if busy { ProgressView("Calculating \(algorithm.displayName) hash value").controlSize(.small) }
                    HStack {
                        Button("OK") { compute() }.keyboardShortcut(.defaultAction).disabled(busy)
                        Button("Cancel") { windowBox.window?.close() }.keyboardShortcut(.cancelAction)
                        PKIHelpButton(action: .hashOfFile)
                    }
                }
                .padding(18)
            } else {
                Color.clear.frame(width: 300, height: 120)
            }
        }
        .background(PKIWindowReader { windowBox.window = $0 })
        .onAppear {
            guard !started else { return }
            started = true
            DispatchQueue.main.async { choose() }
        }
    }

    private func choose() {
        let p = NSOpenPanel()
        p.title = "Hash of a file"
        p.canChooseDirectories = false
        guard p.runModal() == .OK, let u = p.url else { windowBox.window?.close(); return }
        url = u
        windowBox.window?.title = "Select a Hash Function"
    }

    private func compute() {
        guard let u = url else { return }
        busy = true
        let alg = algorithm
        Task.detached {
            let data = (try? Data(contentsOf: u)).map { [UInt8]($0) } ?? []
            let h = Hashing.hash(data, algorithm: alg)
            await MainActor.run {
                digest = h
                busy = false
                windowBox.window?.title = "\(alg.displayName) hash of <\(u.lastPathComponent)>"
            }
        }
    }
}

// MARK: - Hash demo (CT1 IDD_HASH_DEMO)

struct HashDemoView: View {
    private let originalBytes: [UInt8]
    private let originalText: String
    private let docTitle: String?
    private let truncated: Bool
    private let utf8: Bool
    @CTState private var current = ""
    @CTState private var algorithm: HashAlgorithm = .md2
    @CTState private var base = 1          // 0 dezimal, 1 hexadezimal, 2 binär
    @CTState private var started = false
    @StateObject private var windowBox = PKIWindowBox()

    static let maxBytes = 16_000

    /// Entry point used by FeatureRouter (text only; the window title then has no document name).
    init(initialText: String) {
        self.init(bytes: Array(initialText.utf8), title: nil)
    }

    /// CT1 Hashdemo(infile, OldTitle): the original document (at most 16 000 bytes) and its title.
    init(document: CTDocument?) {
        self.init(bytes: document?.bytes ?? Array("CrypTool".utf8), title: document?.shortName)
    }

    private init(bytes: [UInt8], title: String?) {
        let cut = Array(bytes.prefix(Self.maxBytes))
        truncated = bytes.count > Self.maxBytes
        // edits are encoded like CT1 (Windows-1252) unless the document is UTF-8 with non-ASCII text
        utf8 = cut.contains { $0 >= 0x80 } && String(bytes: cut, encoding: .utf8) != nil
        originalBytes = cut
        originalText = TextCoding.string(from: cut)
        docTitle = title
    }

    private func encode(_ s: String) -> [UInt8] { utf8 ? Array(s.utf8) : PKIText.cp1252(s) }

    private func format(_ h: [UInt8]) -> String {
        h.map { b -> String in
            switch base {
            case 0: return String(format: "%03d", b)
            case 2: return String(repeating: "0", count: 8 - String(b, radix: 2).count) + String(b, radix: 2)
            default: return String(format: "%02X", b)
            }
        }.joined(separator: " ")
    }

    var body: some View {
        let h1 = Hashing.hash(originalBytes, algorithm: algorithm)
        let h2 = Hashing.hash(encode(current), algorithm: algorithm)
        VStack(alignment: .leading, spacing: 8) {
            PKIGroup("Description") {
                Text("- Choose a hash function and then change the copy of the original file (see field \"Actual document\").\n- You can see below how many bits of the hash value change when you edit the document.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top) {
                PKIGroup("Selection of hash function") {
                    Picker("", selection: $algorithm) {
                        ForEach(ct1HashOrder, id: \.self) { Text($0.ct1ComboName).tag($0) }
                    }.labelsHidden().frame(width: 200)
                }.frame(width: 240)
                PKIGroup("Base of hash values") {
                    Picker("", selection: $base) {
                        Text("decimal").tag(0); Text("hexadecimal").tag(1); Text("binary").tag(2)
                    }.pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
            }
            Text("Modified document (copied from the original file)")
            CodeEditor(text: $current, minHeight: 170)
            Text("Hash value of the original file")
            ResultBox(text: format(h1), minHeight: base == 2 ? 60 : 30)
            Text("Hash value of the modified file")
            ResultBox(text: format(h2), minHeight: base == 2 ? 60 : 30)
            Text("Difference between the hash values of the original and of the modified file")
            HashDiffView(a: h1, b: h2)
            HStack {
                Spacer()
                PKIHelpButton(action: .hashDemo)
                Button("Close") { windowBox.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .background(PKIWindowReader { windowBox.window = $0; updateTitle() })
        .onChange(of: algorithm) { _, _ in updateTitle() }
        .onAppear {
            guard !started else { return }
            started = true
            current = originalText
            if truncated {
                DispatchQueue.main.async {
                    PKIModal.info("The file size in this demonstration is limited to \(Self.maxBytes) characters.\nEverything beyond that will be ignored. ")
                }
            }
        }
    }

    private func updateTitle() {
        windowBox.window?.title = "Hash Demonstration: \(algorithm.ct1ComboName) Hash of " + (docTitle ?? "")
    }
}

/// CT1 difference field: XOR bits per byte (changed bits red), ratio and longest unchanged run.
struct HashDiffView: View {
    let a: [UInt8]
    let b: [UInt8]

    var body: some View {
        let n = min(a.count, b.count)
        var text = Text("")
        var ones = 0, total = 0
        var bestOff = 0, bestLen = 0, curOff = 0, curLen = 0
        var pos = 0
        for i in 0..<n {
            let x = a[i] ^ b[i]
            for bit in (0..<8).reversed() {
                let d = (x >> UInt8(bit)) & 1 == 1
                total += 1
                if d {
                    ones += 1
                    text = text + Text("1").foregroundColor(.red).bold()
                    curLen = 0
                } else {
                    text = text + Text("0")
                    if curLen == 0 { curOff = pos }
                    curLen += 1
                    if curLen > bestLen { bestLen = curLen; bestOff = curOff }
                }
                pos += 1
            }
            if i < n - 1 { text = text + Text(" ") }
        }
        let pct = String(format: "%.2f", total == 0 ? 0 : 100.0 * Double(ones) / Double(total))
        return VStack(alignment: .leading, spacing: 2) {
            text.font(.system(.body, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
            Text("\(pct)% of the bits differ (\(ones) of \(total)).")
            Text("Longest identical bit sequence: offset \(bestOff), length \(bestLen).")
        }
        .textSelection(.enabled)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }
}

// MARK: - PKCS #5 (CT1 IDD_KEY_FROM_PASSWORD "Schlüssel aus Passwort generieren gemäß PKCS #5")

struct PKCS5View: View {
    @CTState private var password = ""
    @CTState private var salt = "\(Int.random(in: 0...32767))\(Int.random(in: 0...32767))"
    @CTState private var iterations = "1000"
    @CTState private var keyLength = "16"
    @CTState private var hash: HashAlgorithm = .md2
    @CTState private var result = ""
    @StateObject private var windowBox = PKIWindowBox()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PKIGroup("Data entry (password and parameters)") {
                HStack { Text("Password:"); TextField("", text: $password) }
                HStack(alignment: .top) {
                    Text("Length of output key (in bytes):")
                    TextField("", text: digits($keyLength)).frame(width: 44)
                    Text("(may not be longer than the output length of the selected hash function)").font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 12) {
                    PKIGroup("Choose hash function") {
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                            GridRow { Text("Algorithm").foregroundStyle(.secondary); Text("Output length").foregroundStyle(.secondary) }
                            ForEach([HashAlgorithm.md2, .md5, .sha1], id: \.self) { h in
                                GridRow {
                                    Button { hash = h; keyLength = String(h.digestLength) } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: hash == h ? "largecircle.fill.circle" : "circle")
                                                .foregroundStyle(hash == h ? Color.accentColor : .secondary)
                                            Text(h.displayName)
                                        }
                                    }.buttonStyle(.plain)
                                    Text("\(h.digestLength) bytes")
                                }
                            }
                        }
                    }.frame(width: 220)
                    VStack(alignment: .trailing, spacing: 10) {
                        PKIGroup("Optional parameters") {
                            HStack { Text("Salt:"); TextField("", text: $salt) }
                            HStack { Text("Number of iterations:"); TextField("", text: digits($iterations)).frame(width: 80) }
                        }
                        Button("Generate key") { generate() }.keyboardShortcut(.defaultAction)
                    }
                }
            }
            PKIGroup("Key generated from password and other parameters") {
                ResultBox(text: result, minHeight: 30)
                HStack {
                    Button("Copy to clipboard") { copyToPasteboard(result) }
                    Spacer()
                    PKIHelpButton(action: .pkcs5)
                    Button("Close") { windowBox.window?.close() }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 560)
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Key Generation from Password According to PKCS #5" })
    }

    /// CT1 CheckEdit: only digits, no leading zeros.
    private func digits(_ b: Binding<String>) -> Binding<String> {
        Binding(get: { b.wrappedValue }, set: { v in
            var s = v.filter(\.isNumber)
            while s.hasPrefix("0") { s.removeFirst() }
            b.wrappedValue = s
        })
    }

    private func generate() {
        let n = Int(iterations) ?? 0
        let len = Int(keyLength) ?? 0
        let maxLen = hash.digestLength
        if len <= 0 {
            return PKIModal.warning("The given byte length of the output key is smaller than 1 !\nPlease enter a number between 1 and \(maxLen).")
        }
        if len > maxLen {
            return PKIModal.warning("The chosen key length is too large! The key generated from the password must be at least 1 byte long, and it may not exceed the output length of the chosen hash function (\(maxLen) bytes).\n\nPlease choose an output length that lies within those boundaries.")
        }
        if n > 100_000 {
            return PKIModal.warning("The maximum count of hash-iterations is limited to 100,000!\nPlease select for 'Number of iterations' a smaller number.")
        }
        do {
            let key = try PasswordKeyDerivation.pbkdf1(password: PKIText.bytes(password), salt: PKIText.bytes(salt),
                                                       iterations: n, keyLength: len, hash: hash)
            result = Hex.encode(key, separator: " ")
        } catch { PKIModal.warning(error.localizedDescription) }
    }
}

// MARK: - HMAC (CT1 IDD_HMAC "Keyed-Hash Message Authentication Code (HMAC)")

struct HMACView: View {
    let initialMessage: String
    let sourceTitle: String?
    @CTState private var message = ""
    @CTState private var key = "foobar"
    @CTState private var key2 = ""
    @CTState private var construction: MACConstruction? = .secretPrefix
    @CTState private var hash: HashAlgorithm? = .sha256
    @CTState private var shownNoKey = false
    @CTState private var shownOneKey = false
    @CTState private var shownDouble = false
    @CTState private var started = false
    @StateObject private var windowBox = PKIWindowBox()

    static let maxLength = 16_000

    struct Details { var outerInput: [UInt8]; var innerHash: [UInt8]?; var mac: [UInt8] }

    private var details: Details? {
        guard let c = construction, let h = hash else { return nil }
        if c == .hmac { return Self.ct1RFC2104(hash: h, key: PKIText.bytes(key), message: PKIText.bytes(message)) }
        let d = MAC.details(c, hash: h, key: PKIText.bytes(key), message: PKIText.bytes(message), secondKey: PKIText.bytes(key2))
        return Details(outerInput: d.outerInput, innerHash: d.innerHash, mac: d.mac)
    }

    /// CT1 DlgHMAC RFC 2104 branch: block size 128 for SHA-512, 64 for all other hash functions.
    static func ct1RFC2104(hash h: HashAlgorithm, key: [UInt8], message: [UInt8]) -> Details {
        let bs = h == .sha512 ? 128 : 64
        var k = key.count > bs ? Hashing.hash(key, algorithm: h) : key
        k += [UInt8](repeating: 0, count: bs - k.count)
        let ipad = k.map { $0 ^ 0x36 }, opad = k.map { $0 ^ 0x5C }
        let inner = Hashing.hash(ipad + message, algorithm: h)
        let outer = opad + inner
        return Details(outerInput: outer, innerHash: inner, mac: Hashing.hash(outer, algorithm: h))
    }

    private var outerInputText: String {
        guard let c = construction, let d = details else { return "" }
        switch c {
        case .secretPrefix: return key + message
        case .secretSuffix: return message + key
        case .envelope: return key + message + key
        case .doubleKey: return key + message + key2
        case .hmac: return Hex.encode(d.outerInput, separator: " ")
        }
    }

    var body: some View {
        let d = details
        VStack(alignment: .leading, spacing: 8) {
            PKIGroup("Description") {
                Text("By means of a HMAC the recipient of a message is able to verify its integrity and the authenticity of its sender. Therefore both parties use a shared secret (symmetric key).")
                    .fixedSize(horizontal: false, vertical: true)
                Text("To create a HMAC, a cryptographic hash function is applied to a combination of the message m and the secret key k. According to the variation chosen below, two different keys k and k' can be used.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            PKIGroup("Message") { CodeEditor(text: $message, minHeight: 110) }
            PKIGroup("HMAC parameter and key") {
                HStack {
                    Text("Hash function")
                    Picker("", selection: $hash) {
                        Text("Please choose a hash function").tag(HashAlgorithm?.none)
                        ForEach(ct1HashOrder, id: \.self) { Text($0.ct1ComboName).tag(Optional($0)) }
                    }.labelsHidden().frame(width: 230)
                    Text("HMAC variant")
                    Picker("", selection: $construction) {
                        Text("Please choose a HMAC variant").tag(MACConstruction?.none)
                        ForEach(MACConstruction.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                    }.labelsHidden()
                }
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Enter your key (k)"); TextField("", text: $key).font(.system(.body, design: .monospaced)) }
                    GridRow {
                        Text("Enter second key (k')")
                        TextField("", text: $key2).font(.system(.body, design: .monospaced)).disabled(construction != .doubleKey)
                    }
                }
            }
            Text("Inner hash value:")
            ResultBox(text: d?.innerHash.map { Hex.encode($0, separator: " ") } ?? "", minHeight: 30)
            Text("Input for outer hash function (depends on the HMAC variant chosen above)")
            ResultBox(text: outerInputText, minHeight: 60)
            Text("HMAC generated from message and key")
            ResultBox(text: d.map { Hex.encode($0.mac, separator: " ") } ?? "", minHeight: 30)
            HStack {
                Spacer()
                PKIHelpButton(action: .hmac)
                Button("Close") { windowBox.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 760)
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Keyed-Hash Message Authentication Code (HMAC)" })
        .onAppear {
            guard !started else { return }
            started = true
            message = String(initialMessage.prefix(Self.maxLength))
            if initialMessage.count > Self.maxLength {
                DispatchQueue.main.async {
                    PKIModal.info("The size of a message is limited to 16,000 characters.\nFurther characters are ignored.")
                }
            }
        }
        .onChange(of: key) { _, _ in checkKeys() }
        .onChange(of: key2) { _, _ in checkKeys() }
        .onChange(of: construction) { _, _ in checkKeys() }
    }

    /// CT1 keyEmpty(): each hint is shown only once per dialog.
    private func checkKeys() {
        guard let c = construction else { return }
        var msg: String?
        switch c {
        case .doubleKey:
            if key.isEmpty && key2.isEmpty {
                if !shownNoKey { shownNoKey = true; msg = "You did not enter a key!\nThe HMAC of your message corresponds to its hash value." }
            } else if key.isEmpty || key2.isEmpty {
                if !shownOneKey { shownOneKey = true; msg = "You did only enter one key!\nConsequently, the HMAC will be determined by your message \nand one key only." }
            }
        case .hmac:
            if key.isEmpty && !shownDouble { shownDouble = true; msg = "You did not enter a key!\nThe inner hash value therefore corresponds to the hash value\nof the message, the HMAC to this values' hash value." }
        default:
            if key.isEmpty && !shownNoKey { shownNoKey = true; msg = "You did not enter a key!\nThe HMAC of your message corresponds to its hash value." }
        }
        if let msg { DispatchQueue.main.async { PKIModal.info(msg) } }
    }
}
