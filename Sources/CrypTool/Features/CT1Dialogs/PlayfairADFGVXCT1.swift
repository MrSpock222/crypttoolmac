import AppKit
import SwiftUI
import CTCommon
import CTClassic

// MARK: - Playfair (IDD_KEY_PLAYFAIR, DlgKeyPlayfair.cpp, Cryptography.cpp PlayfairBin)

struct PlayfairDialog: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var keyword = ""
    @CTState private var size: PlayfairCipher.Size = .fiveByFive
    @CTState private var separate = true
    @CTState private var separator1 = "X"
    @CTState private var separator2 = "Y"
    @CTState private var onlyWithinPairs = true
    @CTState private var ignoreDuplicates = true

    private var cipher: PlayfairCipher {
        PlayfairCipher(keyword: keyword, size: size, separator: separator1.first ?? "X", doubleLetterRule: separate,
                       separator2: separator2.first ?? "Y", separateOnlyWithinPairs: onlyWithinPairs,
                       ignoreDuplicateKeyLetters: ignoreDuplicates)
    }

    /// CT1 key string "KEY: …, SEPARATOR1: X, SEPARATOR2: Y, MATRIXSIZE: 5[, OPT_…]".
    private var keyString: String {
        var s = "KEY: \(keyword), SEPARATOR1: \(separator1), SEPARATOR2: \(separator2), MATRIXSIZE: \(size.dimension)"
        if ignoreDuplicates { s += ", OPT_IGNORE_DUPLICATE_LETTERS_IN_KEY" }
        if onlyWithinPairs { s += ", OPT_SEPERATE_DUPLICATE_ONLY_WITHIN_PAIRS" }
        return s
    }

    private func letterFilter(_ s: String) -> (String, Bool) {
        let f = String(s.compactMap { PlayfairCipher.normalize($0, size: size) })
        return (f, f.count != s.count)
    }

    private func separatorFilter(_ s: String) -> (String, Bool) {
        guard let c = s.last else { return ("", false) }
        guard let p = PlayfairCipher.normalize(c, size: size) else { return ("", true) }
        return (String(p), false)
    }

    var body: some View {
        DialogScaffold(title: "Key Entry: Playfair", minWidth: 480) {
            CT1Group(title: "Options") {
                Toggle("Separate duplicate letters", isOn: $separate)
                Group {
                    HStack {
                        Text("First separator:").frame(width: 150, alignment: .leading)
                        TextField("", text: $separator1).frame(width: 30).multilineTextAlignment(.center)
                            .ct1Filter($separator1, separatorFilter)
                    }
                    HStack {
                        Text("Second separator:").frame(width: 150, alignment: .leading)
                        TextField("", text: $separator2).frame(width: 30).multilineTextAlignment(.center)
                            .ct1Filter($separator2, separatorFilter)
                    }
                    Toggle("Separate duplicate letters only within pairs", isOn: $onlyWithinPairs)
                }
                .padding(.leading, 20)
                .disabled(!separate)
                Toggle("Ignore duplicate letters in the key phrase", isOn: $ignoreDuplicates)
            }
            CT1Group(title: "Playfair key") {
                Text("Short version of the Playfair key:")
                HStack {
                    TextField("", text: $keyword).font(.system(.body, design: .monospaced))
                        .ct1Filter($keyword, letterFilter)
                    CT1PasteKeyButton(method: "playfair") { pasteKey($0) }
                }
                HStack(alignment: .top) {
                    GroupBox("Key matrix") { CharMatrixView(matrix: cipher.matrix).padding(4) }
                    VStack(alignment: .leading) {
                        CT1Radio(title: "5x5 matrix", selected: size == .fiveByFive) { size = .fiveByFive }
                        CT1Radio(title: "6x6 matrix", selected: size == .sixBySix) { size = .sixBySix }
                    }.padding(.top, 20)
                }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, help: .playfair)
        }
        .onChange(of: size) { _, _ in
            keyword = letterFilter(keyword).0
            separator1 = separatorFilter(separator1).0.isEmpty ? "X" : separatorFilter(separator1).0
            separator2 = separatorFilter(separator2).0.isEmpty ? "Y" : separatorFilter(separator2).0
        }
    }

    private func pasteKey(_ s: String) {
        func value(_ name: String) -> String? {
            guard let r = s.range(of: name + ": ") else { return nil }
            return String(s[r.upperBound...].prefix { $0 != "," })
        }
        if let m = value("MATRIXSIZE") { size = m.hasPrefix("6") ? .sixBySix : .fiveByFive }
        keyword = letterFilter(value("KEY") ?? s).0
        if let a = value("SEPARATOR1"), !a.isEmpty { separator1 = a }
        if let b = value("SEPARATOR2"), !b.isEmpty { separator2 = b }
        if s.contains("KEY: ") {
            ignoreDuplicates = s.contains("OPT_IGNORE_DUPLICATE_LETTERS_IN_KEY")
            onlyWithinPairs = s.contains("OPT_SEPERATE_DUPLICATE_ONLY_WITHIN_PAIRS")
        }
    }

    private func run(_ encrypt: Bool) {
        let c = cipher
        let key = keyString
        let text = document.text
        guard c.letters(text).count >= 2 else {
            Alerts.error("The input must contain at least 2 (not necessarily different) character(s) from the current alphabet. The alphabet can be configured in Options \\ Text Options.")
            return
        }
        // CT1 opens the preformatted plaintext (encryption only) and the result, both in the
        // Playfair (digraph) view.
        if encrypt {
            DocumentFactory.openResult(text: PlayfairCipher.grouped(c.preformat(text).joined()),
                                       title: "Playfair pre-formatting of <\(document.shortName)>", parent: document)
        }
        if CipherRun.text(document, method: "playfair", name: "Playfair", encrypt: encrypt, key: key, {
            PlayfairCipher.grouped(encrypt ? c.encrypt(text) : c.decrypt(text))
        }) { close() }
    }
}

// MARK: - ADFGVX (IDD_ADFGVX, DlgADFGVX.cpp, adfgvx.cpp)

struct ADFGVXDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var cells: [[String]] = ADFGVXCipher.standardMatrix.map { $0.map(String.init) }
    @CTState private var password = ""
    // Ausgabeoptionen (CT1 defaults: no blocks; stage-2 block length 5, stage-1 block length 2)
    @CTState private var block2 = false
    @CTState private var blockLen2 = "5"
    @CTState private var newLine2 = false
    @CTState private var outputStage1 = false
    @CTState private var block1 = false
    @CTState private var blockLen1 = "2"
    @CTState private var newLine1 = false
    @CTState private var showStringBox = false
    @CTState private var stringBoxText = ""

    private var matrix: [[Character]] { cells.map { $0.map { $0.first ?? "*" } } }
    private var cipher: ADFGVXCipher? { try? ADFGVXCipher(matrix: matrix, transpositionKey: password) }

    /// adfgvx::readCiphertext – only A, D, F, G, V, X (blanks and line feeds ignored), even count.
    private var validCiphertext: Bool {
        var count = 0
        for ch in document.text {
            if ch == " " || ch == "\n" { continue }
            guard "ADFGVX".contains(Character(String(ch).uppercased())) else { return false }
            count += 1
        }
        return count > 0 && count % 2 == 0
    }

    private var columnOrder: String {
        guard let c = cipher else { return "" }
        return "-" + c.numberedKey.map(String.init).joined(separator: "-") + "-"
    }

    private func cellBinding(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: { cells[r][c] }, set: { new in
            let u = String(new.uppercased().suffix(1))
            cells[r][c] = u
        })
    }

    var body: some View {
        DialogScaffold(title: "Key Entry: ADFGVX", minWidth: 560) {
            CT1Group(title: "Step 1: Substitution") {
                HStack(alignment: .top, spacing: 16) {
                    GroupBox("Substitution matrix") {
                        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                            GridRow {
                                Text("")
                                ForEach(ADFGVXCipher.labels, id: \.self) { Text(String($0)).font(.caption.monospaced().bold()) }
                            }
                            ForEach(0..<6, id: \.self) { r in
                                GridRow {
                                    Text(String(ADFGVXCipher.labels[r])).font(.caption.monospaced().bold())
                                    ForEach(0..<6, id: \.self) { c in
                                        TextField("", text: cellBinding(r, c)).frame(width: 26)
                                            .multilineTextAlignment(.center).font(.system(.body, design: .monospaced))
                                    }
                                }
                            }
                        }.padding(4)
                    }
                    Text("The substitution matrix replaces each plaintext letter by a pair of the letters A,D,F,G,V,X.\n\nThe matrix must contain each letter A-Z and each cipher 0-9 exactly once. ")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Standard matrix") { cells = ADFGVXCipher.standardMatrix.map { $0.map(String.init) } }
                    Button("Random matrix") { cells = ADFGVXCipher.randomMatrix().map { $0.map(String.init) } }
                    Button("Erase matrix") {
                        if Alerts.confirm("All current entries in the substitution matrix will be erased!\nContinue?", title: "ADFGVX", ok: "Yes") {
                            cells = Array(repeating: Array(repeating: "*", count: 6), count: 6)
                        }
                    }
                    Button("Enter string") { stringBoxText = ""; showStringBox = true }
                }
            }
            CT1Group(title: "Step 2: Transposition") {
                Text("The encryption only uses the characters of the transposition password that are part of the current alphabet (see text options).")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Text("Transposition password")
                HStack {
                    TextField("", text: $password).font(.system(.body, design: .monospaced))
                        .ct1Filter($password) { CT1KeyInput.filter($0, alphabet: settings.textOptions.alphabetCharacters) }
                    CT1PasteKeyButton(method: "adfgvx") { pasteKey($0) }
                }
                Text("Column sequence")
                CT1ReadOnlyLine(text: columnOrder)
                Button("Text options") { OptionsWindows.showTextOptions() }.frame(maxWidth: .infinity)
            }
            CT1Group(title: "Output options") {
                GroupBox("Result: Ciphertext after step 2") {
                    blockOptions(block: $block2, length: $blockLen2, newLine: $newLine2).padding(4)
                }
                Toggle("Print out intermediate result", isOn: $outputStage1)
                GroupBox("Intermediate result: Ciphertext after step 1") {
                    blockOptions(block: $block1, length: $blockLen1, newLine: $newLine1).padding(4)
                }.disabled(!outputStage1)
            }
        } buttons: {
            Button("Help") { HelpCenter.show(action: .adfgvx) }
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Decrypt") { run(false) }.disabled(cipher == nil || !validCiphertext)
            Button("Encrypt") { run(true) }.keyboardShortcut(.defaultAction).disabled(cipher == nil)
        }
        .onChange(of: block1) { _, on in if on { blockLen1 = String(max(1, password.count)) } else { blockLen1 = "2"; newLine1 = false } }
        .onChange(of: block2) { _, on in if !on { blockLen2 = "5"; newLine2 = false } }
        .onChange(of: outputStage1) { _, on in if !on { block1 = false } }
        .sheet(isPresented: $showStringBox) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Substitution Password").font(.title3.weight(.semibold))
                TextField("", text: $stringBoxText).frame(width: 300)
                HStack {
                    Spacer()
                    Button("Cancel") { showStringBox = false }.keyboardShortcut(.cancelAction)
                    Button("OK") {
                        cells = ADFGVXCipher.matrix(fromKeyword: stringBoxText).map { $0.map(String.init) }
                        showStringBox = false
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(18)
        }
    }

    private func blockOptions(block: Binding<Bool>, length: Binding<String>, newLine: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("Separate output blocks by blanks", isOn: block)
                Spacer()
                Text("Block length (1-26):")
                TextField("", text: length).frame(width: 36).multilineTextAlignment(.center).disabled(!block.wrappedValue)
            }
            Toggle("New line after each block", isOn: newLine).disabled(!block.wrappedValue)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pasteKey(_ s: String) {
        guard let k = ADFGVXAnalysis.parseKey(s) else { return }
        password = CT1KeyInput.filter(k.password, alphabet: settings.textOptions.alphabetCharacters).0
        cells = k.matrix.map { $0.map(String.init) }
    }

    private func run(_ encrypt: Bool) {
        guard let c = cipher else { return }
        let l2 = Int(blockLen2) ?? 0, l1 = Int(blockLen1) ?? 0
        if block2 && !(1...26).contains(l2) {
            blockLen2 = "5"
            Alerts.error("Blocklength stage1:\nFor block length please enter values between 1 and 26 only!")
            return
        }
        if outputStage1 && block1 && !(1...26).contains(l1) {
            blockLen1 = String(password.count)
            Alerts.error("Blocklength stage1:\nFor block length please enter values between 1 and 26 only!")
            return
        }
        let key = password + ", " + String(matrix.flatMap { $0 })
        let text = document.text
        let stage1Title = CT1.title("ADFGVX stage 1", encrypt: true, of: document, key: key)
        do {
            if encrypt {
                let stage1 = c.substitute(text)
                let final = c.encrypt(text, blockSize: 0)
                if outputStage1 {
                    DocumentFactory.openResult(text: CT1.blocks(stage1, size: block1 ? l1 : 0, newLine: newLine1),
                                               title: stage1Title, parent: document, method: "adfgvx", key: key)
                }
                _ = CipherRun.open(text: document, method: "adfgvx", title: CT1.title("ADFGVX", encrypt: true, of: document, key: key), key: key) {
                    CT1.blocks(final, size: block2 ? l2 : 0, newLine: newLine2)
                }
            } else {
                let stage1 = try c.detranspose(text)
                let plain = try c.decrypt(text)
                _ = CipherRun.open(text: document, method: "adfgvx", title: CT1.title("ADFGVX", encrypt: false, of: document, key: key), key: key) { plain }
                if outputStage1 {
                    DocumentFactory.openResult(text: CT1.blocks(stage1, size: block1 ? l1 : 0, newLine: newLine1),
                                               title: stage1Title, parent: document, method: "adfgvx", key: key)
                }
            }
            close()
        } catch {
            Alerts.error(error.localizedDescription)
        }
    }
}
