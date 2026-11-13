import AppKit
import SwiftUI
import CTCommon
import CTClassic

// Classic key dialogs laid out after CT1 (German resources): Caesar / ROT-13 (IDD_ROT13_CAESAR),
// Vigenère (IDD_KEY), Substitution / Atbash (IDD_KEY_MONSUBST), ADD / XOR (IDD_KEY as CDlgKeyHex),
// Vernam (file dialog), Skytale / Gartenzaun (IDD_SIMPLE_TRANSPOSITIONS).
// Hill, Playfair, ADFGVX, Homophone, Permutation and Solitaire live in CT1Dialogs/.

// MARK: - Caesar / ROT-13

struct CaesarDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var rot13 = false
    @CTState private var alphabeticInput = true
    @CTState private var offsetOne = false
    @CTState private var letterText = ""
    @CTState private var numberText = ""

    private var alphabet: [Character] { settings.textOptions.alphabetCharacters }
    private var n: Int { alphabet.count }
    private var rot13Available: Bool { n > 0 && n % 2 == 0 }
    private var useROT13: Bool { rot13 && rot13Available }

    /// DlgRot13Caesar `calculateAlphabeticKeyFromNumericKey`.
    private func letter(forNumber k: Int) -> Character? {
        guard k >= 0, k < n else { return nil }
        var pos = k
        if offsetOne { pos = k <= 0 ? n - 1 : k - 1 }
        return alphabet[pos]
    }

    /// The typed key letter, tried in upper/lower case like CT1.
    private var resolvedLetter: Character? {
        guard let c = letterText.first else { return nil }
        if alphabet.contains(c) { return c }
        if let u = String(c).uppercased().first, alphabet.contains(u) { return u }
        if let l = String(c).lowercased().first, alphabet.contains(l) { return l }
        return nil
    }

    /// (alphabetic key, numeric key = shift) as computed by CDlgRot13Caesar::onUpdateGUI.
    private var key: (letter: Character, shift: Int)? {
        guard n > 0 else { return nil }
        if useROT13 {
            guard let l = letter(forNumber: n / 2) else { return nil }
            return (l, n / 2)
        }
        if alphabeticInput {
            guard let c = resolvedLetter, let i = alphabet.firstIndex(of: c) else { return nil }
            return (c, offsetOne ? (i + 1) % n : i)
        }
        guard let k = Int(numberText), let l = letter(forNumber: k) else { return nil }
        return (l, k)
    }

    private var keyString: String {
        guard let k = key else { return "" }
        return "\(k.letter), KEY OFFSET: \(offsetOne ? 1 : 0)"
    }

    var body: some View {
        DialogScaffold(title: "Key Entry: Caesar / ROT-13", minWidth: 600) {
            CT1Group(title: "Description") {
                Text("Here you can enter the key for the Caesar cipher. Caesar is a mono-alphabetic substitution, where the characters of the cleartext alphabet are mapped to the ciphertext alphabet by shifting. This shifting value is the key. You can enter the key as a number or as a single character of the alphabet.\nRot-13 is a special variant, where the key has the fixed value of half the length of the cleartext alphabet. This variant is only selectable if the length of the alphabet is an even number.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top) {
                CT1Group(title: "Select variant") {
                    CT1Radio(title: "Caesar", selected: !useROT13) { rot13 = false }
                    CT1Radio(title: "Rot-13", selected: useROT13) { rot13 = true }.disabled(!rot13Available)
                }.frame(width: 170)
                CT1Group(title: "Options to interpret the alphabet characters") {
                    CT1Radio(title: "Value of the first alphabet character = 0 (e.g. \"A\"=0)", selected: !offsetOne) { offsetOne = false }
                    CT1Radio(title: "Value of the first alphabet character = 1 (e.g. \"A\"=1)", selected: offsetOne) { offsetOne = true }
                }
            }
            CT1Group(title: "Key entry as") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            CT1Radio(title: "Alphabet character", selected: alphabeticInput) { alphabeticInput = true }
                                .frame(width: 140, alignment: .leading)
                            TextField("", text: $letterText).frame(width: 34).multilineTextAlignment(.center)
                                .font(.system(.body, design: .monospaced))
                                .disabled(!alphabeticInput || useROT13)
                                .ct1Filter($letterText) { s in (String(s.suffix(1)), false) }
                            CT1PasteKeyButton(method: "caesar") { pasteKey($0) }
                        }
                        HStack {
                            CT1Radio(title: "Number value", selected: !alphabeticInput) { alphabeticInput = false }
                                .frame(width: 140, alignment: .leading)
                            TextField("", text: $numberText).frame(width: 40).multilineTextAlignment(.center)
                                .disabled(alphabeticInput || useROT13)
                                .ct1Filter($numberText) { s in
                                    let d = s.filter(\.isASCII).filter(\.isNumber)
                                    return (String(d.prefix(String(n).count)), d.count != s.count)
                                }
                        }
                    }
                    .disabled(useROT13)
                    Spacer()
                    if !rot13Available {
                        Text("Rot-13 encryption is deactivated because the alphabet does not consist of an even number of letters!")
                            .font(.callout).frame(width: 220, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            CT1Group(title: "Properties of the chosen encryption") {
                Text("Shift of \(key.map { String($0.shift) } ?? (alphabeticInput || useROT13 ? "" : numberText))")
                Text("Mapping of the alphabet (\(n) characters)")
                HStack { Text("from:").frame(width: 34, alignment: .leading); CT1ReadOnlyLine(text: String(alphabet)) }
                HStack {
                    Text("to:").frame(width: 34, alignment: .leading)
                    CT1ReadOnlyLine(text: key.map { Caesar.targetAlphabet(shift: $0.shift, options: settings.textOptions) } ?? "")
                }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: key == nil,
                          textOptions: true, help: .caesar)
        }
        .onAppear {
            // CT1 default key: the second alphabet character (A = 0 → shift 1)
            let first: Character? = n > 1 ? alphabet[1] : alphabet.first
            if letterText.isEmpty, let c = first { letterText = String(c) }
            if let k = key { numberText = String(k.shift) }
        }
        .onChange(of: alphabeticInput) { _, alpha in
            // keep both representations in sync like CT1 when switching the input mode
            if !alpha, let c = resolvedLetter, let i = alphabet.firstIndex(of: c) {
                numberText = String(offsetOne ? (i + 1) % n : i)
            } else if alpha, let k = Int(numberText), let l = letter(forNumber: k) {
                letterText = String(l)
            }
        }
    }

    private func pasteKey(_ s: String) {
        guard let c = s.first, alphabet.contains(c) else {
            Alerts.error("The key stored in the clipboard is not part of the actual alphabet\nthus the key is currently not usable!")
            return
        }
        rot13 = false
        alphabeticInput = true
        letterText = String(c)
        offsetOne = s.last == "1"
    }

    private func run(_ encrypt: Bool) {
        guard let k = key else { return }
        let o = settings.textOptions
        if CipherRun.text(document, method: "caesar", name: useROT13 ? "ROT 13" : "Caesar", encrypt: encrypt, key: keyString, {
            encrypt ? Caesar.encrypt(document.text, shift: k.shift, options: o)
                    : Caesar.decrypt(document.text, shift: k.shift, options: o)
        }) { close() }
    }
}

// MARK: - Vigenère (IDD_KEY)

struct VigenereDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var key = ""

    var body: some View {
        DialogScaffold(title: "Key Entry: Vigenère", minWidth: 480) {
            Text("Enter the key.\nThe maximum key length is 1024 characters!")
            HStack {
                TextField("", text: $key).font(.system(.body, design: .monospaced))
                    .ct1Filter($key) { CT1KeyInput.filter($0, alphabet: settings.textOptions.alphabetCharacters, maxLength: 1024) }
                CT1PasteKeyButton(method: "vigenere") { key = CT1KeyInput.filter($0, alphabet: settings.textOptions.alphabetCharacters, maxLength: 1024).0 }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: key.isEmpty,
                          textOptions: true, help: .vigenere)
        }
    }

    private func run(_ encrypt: Bool) {
        let o = settings.textOptions
        if CipherRun.text(document, method: "vigenere", name: "Vigenère", encrypt: encrypt, key: key, {
            encrypt ? try Vigenere.encrypt(document.text, key: key, options: o)
                    : try Vigenere.decrypt(document.text, key: key, options: o)
        }) { close() }
    }
}

// MARK: - Substitution / Atbash (IDD_KEY_MONSUBST)

struct SubstitutionDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    /// 0 = remaining characters ascending (CT1 default), 1 = descending, 2 = Atbash.
    @CTState private var variant = 0
    @CTState private var key = ""
    @CTState private var offsetText = "0"

    private var alphabet: [Character] { settings.textOptions.alphabetCharacters }

    private var mapping: [Character] {
        if variant == 2 { return Array(alphabet.reversed()) }
        return SubstitutionCipher.keyAlphabet(fromKeyword: key, options: settings.textOptions,
                                              remainingDescending: variant == 1, offset: Int(offsetText) ?? 0)
    }

    var body: some View {
        DialogScaffold(title: "Key Entry: Monoalphabetic Substitution / Atbash", minWidth: 600) {
            CT1Group(title: "Choose variant of the monoalphabetic substitution") {
                CT1Radio(title: "Key entry: Remaining characters are filled in ascending order", selected: variant == 0) { variant = 0 }
                CT1Radio(title: "Key entry: Remaining characters are filled in descending order", selected: variant == 1) { variant = 1 }
                CT1Radio(title: "Atbash (the encryption is using a fixed key)", selected: variant == 2) { variant = 2 }
            }
            CT1Group(title: "Key Input") {
                HStack {
                    Text("Key:").frame(width: 70, alignment: .leading)
                    if variant == 2 {
                        CT1ReadOnlyLine(text: String(alphabet.reversed()))
                    } else {
                        TextField("", text: $key).font(.system(.body, design: .monospaced))
                            .ct1Filter($key) { CT1KeyInput.filter($0, alphabet: settings.textOptions.alphabetCharacters) }
                    }
                    CT1PasteKeyButton(method: "substitution") { pasteKey($0) }.disabled(variant == 2)
                }
                HStack {
                    Text("Offset:").frame(width: 70, alignment: .leading)
                    TextField("", text: $offsetText).frame(width: 44).multilineTextAlignment(.center)
                        .disabled(variant == 2)
                        .ct1Filter($offsetText) { s in
                            let d = s.filter { $0.isASCII && ($0.isNumber || $0 == "-") }
                            return (d, d.count != s.count)
                        }
                }
            }
            CT1Group(title: "Information on the substitution encryption") {
                Text("The alphabet (\(alphabet.count) characters) will be mapped")
                HStack { Text("from:").frame(width: 34, alignment: .leading); CT1ReadOnlyLine(text: String(alphabet)) }
                HStack { Text("to:").frame(width: 34, alignment: .leading); CT1ReadOnlyLine(text: String(mapping)) }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: alphabet.isEmpty,
                          textOptions: true, help: .substitution)
        }
        .onChange(of: variant) { _, v in if v == 2 { offsetText = "0" } }
    }

    private func pasteKey(_ s: String) {
        let (f, _) = CT1KeyInput.filter(s, alphabet: alphabet)
        key = f
        if f != s {
            Alerts.info("Please note that characters not part of the currently configured alphabet were removed while pasting from the clipboard.")
        }
    }

    private func run(_ encrypt: Bool) {
        let keyAlphabet = String(mapping)
        if CipherRun.text(document, method: "substitution", name: variant == 2 ? "Atbash" : "Substitution",
                          encrypt: encrypt, key: keyAlphabet, {
            let c = try SubstitutionCipher(keyAlphabet: keyAlphabet, options: settings.textOptions)
            return encrypt ? c.encrypt(document.text) : c.decrypt(document.text)
        }) { close() }
    }
}

// MARK: - Byteweise Addition / XOR (IDD_KEY as CDlgKeyHex)

struct ByteCipherDialog: View {
    enum Kind { case addition, xor }
    let kind: Kind
    let document: CTDocument
    let close: () -> Void
    @CTState private var key = ""

    private var method: String { kind == .addition ? "add" : "xor" }
    /// CT1 IDS_STRING_ADD / IDS_STRING_XOR (used in the result title).
    private var name: String { kind == .addition ? "ADD" : "XOR" }
    private var keyBytes: [UInt8]? { CT1KeyInput.hexBytes(key) }

    var body: some View {
        DialogScaffold(title: kind == .addition ? "Key Entry: byte by byte addition (ADD)" : "Key Entry: byte by byte XOR",
                       minWidth: 500) {
            Text("Enter the key using hex characters (0..9, A..F).\nKey length at maximum  2048 hex characters (= 1024 bytes).")
            HStack {
                TextField("", text: $key).font(.system(.body, design: .monospaced))
                    .ct1Filter($key) { CT1KeyInput.hex($0, maxDigits: 2048) }
                CT1PasteKeyButton(method: method) { key = CT1KeyInput.hex($0, maxDigits: 2048).0 }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: keyBytes == nil,
                          help: kind == .addition ? CTAction.byteAddition : CTAction.xor)
        }
    }

    private func run(_ encrypt: Bool) {
        guard let k = keyBytes else { return }
        if CipherRun.bytes(document, method: method, name: name, encrypt: encrypt, key: key, {
            switch kind {
            case .addition: return encrypt ? ByteCiphers.add(document.bytes, key: k) : ByteCiphers.subtract(document.bytes, key: k)
            case .xor: return ByteCiphers.xor(document.bytes, key: k)
            }
        }) { close() }
    }
}

// MARK: - Vernam (Cryptography.cpp VernamBin: file dialog only)

/// CT1 has no key dialog for Vernam: a file dialog "Auswahl der Vernam-Schlüsseldatei für <doc>"
/// opens directly, the document is XOR-ed with the key file (repeated if shorter).
struct VernamDialog: View {
    let document: CTDocument
    let close: () -> Void

    var body: some View {
        Color.clear.frame(width: 1, height: 1)
            .onAppear {
                DispatchQueue.main.async {
                    close()
                    VernamFlow.run(document)
                }
            }
    }
}

@MainActor
enum VernamFlow {
    static func run(_ doc: CTDocument) {
        var shown = doc.shortName
        if shown.count > 32 { shown = String(shown.prefix(29)) + "..." }
        let panel = NSOpenPanel()
        panel.title = "Selection of the Vernam key file for <\(shown)>"
        panel.message = panel.title
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let pad: [UInt8]
        do { pad = [UInt8](try Data(contentsOf: url)) } catch { Alerts.error(error.localizedDescription); return }
        var result = doc.bytes
        if pad.isEmpty {
            Alerts.info("The chosen Vernam key is of length 0.\nPlease check the key file.")
        } else {
            if pad.count < doc.bytes.count {
                Alerts.info("The Vernam key is shorter than the text that is to be encrypted.")
            }
            result = ByteCiphers.xor(doc.bytes, key: pad)
        }
        // CT1: title always "Vernam-Verschlüsselung von <doc> und <keyfile>", key "Datei <path>"
        let key = "Datei \(url.path)"
        KeyMemory.remember(key, for: "vernam")
        DocumentFactory.openResult(result, title: "Vernam encryption of <\(doc.shortName)> and <\(url.lastPathComponent)>",
                                   parent: doc, method: "vernam", key: key,
                                   viewMode: TextCoding.looksLikeText(result) ? .text : .hex)
    }
}

// MARK: - Skytale / Gartenzaun (IDD_SIMPLE_TRANSPOSITIONS)

struct ScytaleDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    // CT1 keeps type, key and offset in the registry ("SimpleTranspositions"); defaults 0 / 2 / 0.
    @AppStorage("ct1.simpleTranspositions.type") private var type = 0
    @AppStorage("ct1.simpleTranspositions.key") private var storedKey = 2
    @AppStorage("ct1.simpleTranspositions.offset") private var storedOffset = 0
    @CTState private var keyText = ""
    @CTState private var offsetText = ""

    private var railFence: Bool { type == 1 }

    var body: some View {
        DialogScaffold(title: "Key Entry: Scytale / Rail Fence", minWidth: 480) {
            CT1Group(title: "Description") {
                Text("Transpositions scramble the order of the letters in the cleartext. Two well-known classical variants are known as Scytale and Rail Fence.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    CT1Group(title: "Choose the transposition variant") {
                        CT1Radio(title: "Scytale", selected: !railFence) { type = 0 }
                        CT1Radio(title: "Rail Fence", selected: railFence) { type = 1 }
                    }
                    CT1Group(title: "Choose the key") {
                        HStack {
                            Text(railFence ? "Number of rows:" : "Number of edges:").frame(width: 130, alignment: .leading)
                            TextField("", text: $keyText).frame(width: 44).multilineTextAlignment(.center)
                                .ct1Filter($keyText, digitsOnly)
                            CT1PasteKeyButton(method: "simpletransposition") { pasteKey($0) }
                        }
                        HStack {
                            Text("Offset:").frame(width: 130, alignment: .leading)
                            TextField("", text: $offsetText).frame(width: 44).multilineTextAlignment(.center)
                                .ct1Filter($offsetText, digitsOnly)
                        }
                    }
                }
                Image(systemName: railFence ? "point.3.connected.trianglepath.dotted" : "cylinder.split.1x2")
                    .font(.system(size: 54)).foregroundStyle(.secondary).frame(width: 110, height: 110)
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) },
                          disabled: Int(keyText) == nil || Int(offsetText) == nil, textOptions: true, help: .scytaleRailFence)
        }
        .onAppear { keyText = String(storedKey); offsetText = String(storedOffset) }
    }

    private func digitsOnly(_ s: String) -> (String, Bool) {
        let d = s.filter { $0.isASCII && $0.isNumber }
        return (String(d.prefix(6)), d.count != s.count)
    }

    private func pasteKey(_ s: String) {
        // "TYPE: 0, KEY: 3, KEY OFFSET: 0"
        func value(_ name: String) -> Int? {
            guard let r = s.range(of: name + ": ") else { return nil }
            return Int(s[r.upperBound...].prefix { $0.isNumber })
        }
        if let t = value("TYPE") { type = t == 1 ? 1 : 0 }
        if let k = value(", KEY") ?? value("KEY") { keyText = String(k) }
        if let o = value("KEY OFFSET") { offsetText = String(o) }
    }

    private func run(_ encrypt: Bool) {
        guard let key = Int(keyText), let offset = Int(offsetText) else { return }
        let o = settings.textOptions
        let length = o.indices(of: document.text).count
        guard key > 1, key < length else {
            Alerts.error("The key is invalid. It must be greater than 1 and smaller than the length of the input text.\n\nCharacters that are not part of the CrypTool alphabet are deleted before encryption/decryption. If you don't want to change the input text, please use the button \"Text options\" to alter the CrypTool alphabet in order to proceed.")
            return
        }
        storedKey = key
        storedOffset = offset
        // CT1 writes the normalised offset into the key string
        let shownOffset = railFence ? offset % (2 * key - 2) : min(offset, length)
        let keyString = "TYPE: \(type), KEY: \(key), KEY OFFSET: \(shownOffset)"
        let name = railFence ? "Rail Fence" : "Scytale"
        let title = "\(name) \(encrypt ? "encryption" : "decryption") (Simple Transposition) of <\(document.shortName)>, key <\(keyString)>"
        let result = CipherRun.open(text: document, method: "simpletransposition", title: title, key: keyString) {
            if railFence {
                return encrypt ? RailFence.encrypt(document.text, rails: key, offset: offset, options: o)
                               : RailFence.decrypt(document.text, rails: key, offset: offset, options: o)
            }
            return encrypt ? Scytale.encrypt(document.text, circumference: key, offset: offset, options: o)
                           : Scytale.decrypt(document.text, circumference: key, offset: offset, options: o)
        }
        if result != nil { close() }
    }
}
