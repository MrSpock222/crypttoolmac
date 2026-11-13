import AppKit
import SwiftUI
import CTCommon
import CTClassic

// MARK: - Permutation / Transposition (IDD_KEY_PERMUTATION, IDD_KEY_PERMUTATION_INFO)

struct PermutationDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var key1 = ""
    @CTState private var key2 = ""
    @CTState private var options = PermutationOptions()
    @CTState private var showInverseDialog = false
    /// CT1 default: "Binäre Daten".
    @CTState private var textMode = false
    /// Pending operation while the intermediate dialog with the inverse permutation is shown.
    @CTState private var pendingEncrypt: Bool?

    private func perm(_ s: String) -> [Int]? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : PermutationCipher.parsePermutation(t)
    }

    private func letterPermutation(_ s: String) -> String {
        guard let c = s.trimmingCharacters(in: .whitespaces).first, !c.isNumber, let p = perm(s) else { return "" }
        return PermutationCipher.display(p)
    }

    private var valid: Bool { perm(key1) != nil && (key2.trimmingCharacters(in: .whitespaces).isEmpty || perm(key2) != nil) }

    var body: some View {
        if let encrypt = pendingEncrypt {
            inverseInfo(encrypt)
        } else {
            keyDialog
        }
    }

    private var keyDialog: some View {
        DialogScaffold(title: "Key Entry: Permutation / Transposition", minWidth: 560) {
            stageGroup("1st Permutation (simple column transposition)", key: $key1, stage: $options.first)
            stageGroup("2nd Permutation (double column transposition)", key: $key2, stage: $options.second)
            CT1Group(title: "Options") {
                Toggle("Apply the respective inverse permutation", isOn: $options.applyInverse)
                Toggle("Show intermediate dialog with the inverse permutation", isOn: $showInverseDialog)
                HStack {
                    Text("Consider input document as")
                    CT1Radio(title: "Binary data", selected: !textMode) { textMode = false }
                    CT1Radio(title: "Text", selected: textMode) { textMode = true }
                    Spacer()
                    CT1PasteKeyButton(method: "permutation") { pasteKey($0) }
                }
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { start(false) }, encrypt: { start(true) }, disabled: !valid,
                          textOptions: true, help: .permutation)
        }
    }

    private func stageGroup(_ title: String, key: Binding<String>, stage: Binding<PermutationOptions.Stage>) -> some View {
        CT1Group(title: title) {
            Text("Key (via letters or via comma separated numbers)")
            TextField("", text: key).font(.system(.body, design: .monospaced))
            Text("Presentation as permutation if key is given in letters")
            CT1ReadOnlyLine(text: letterPermutation(key.wrappedValue))
            PermutationStageGrid(stage: stage).padding(.top, 4)
        }
    }

    /// IDD_KEY_PERMUTATION_INFO: entered and inverse permutation of both stages.
    private func inverseInfo(_ encrypt: Bool) -> some View {
        let p1 = perm(key1) ?? [], p2 = perm(key2)
        return DialogScaffold(title: "Permutation / Transposition", minWidth: 520) {
            CT1Group(title: "1st Permutation") {
                infoRow("Entered", PermutationCipher.display(p1))
                infoRow("Inverse", PermutationCipher.display(PermutationCipher.inverse(of: p1)))
            }
            CT1Group(title: "2nd Permutation") {
                infoRow("Entered", p2.map(PermutationCipher.display) ?? "")
                infoRow("Inverse", p2.map { PermutationCipher.display(PermutationCipher.inverse(of: $0)) } ?? "")
            }
        } buttons: {
            Button("Back") { pendingEncrypt = nil }
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button("Display text") { run(encrypt) }.keyboardShortcut(.defaultAction)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).frame(width: 80, alignment: .trailing); CT1ReadOnlyLine(text: value) }
    }

    private func start(_ encrypt: Bool) {
        if showInverseDialog { pendingEncrypt = encrypt } else { run(encrypt) }
    }

    private func flags(_ s: PermutationOptions.Stage) -> String {
        [s.readIn, s.permute, s.readOut].map { $0 == .rowWise ? "0" : "1" }.joined(separator: ",")
    }

    /// CT1 key "<key1>[;<key2>] PARAMETER: BINARY, [INV, ]a,b,c,d,e,f".
    private var keyString: String {
        let k2 = key2.trimmingCharacters(in: .whitespaces)
        var s = key1.trimmingCharacters(in: .whitespaces) + (k2.isEmpty ? "" : ";" + k2)
        s += " PARAMETER: " + (textMode ? "TEXT, " : "BINARY, ") + (options.applyInverse ? "INV, " : "")
        s += flags(options.first) + "," + flags(options.second)
        return s
    }

    private func pasteKey(_ s: String) {
        let parts = s.components(separatedBy: " PARAMETER: ")
        let keys = parts[0].split(separator: ";", maxSplits: 1).map(String.init)
        key1 = keys.first ?? ""
        key2 = keys.count > 1 ? keys[1] : ""
        guard parts.count > 1 else { return }
        let p = parts[1]
        textMode = p.contains("TEXT, ")
        options.applyInverse = p.contains("INV, ")
        let nums = p.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Int($0) }
        guard nums.count == 6 else { return }
        func dir(_ v: Int) -> PermutationOptions.Direction { v == 0 ? .rowWise : .columnWise }
        options.first = .init(readIn: dir(nums[0]), permute: dir(nums[1]), readOut: dir(nums[2]))
        options.second = .init(readIn: dir(nums[3]), permute: dir(nums[4]), readOut: dir(nums[5]))
    }

    private func run(_ encrypt: Bool) {
        guard let p1 = perm(key1) else { return }
        let p2 = perm(key2)
        var o = options
        o.lettersOnly = textMode
        let key = keyString
        let title = CT1.title("Permutation/Transposition", encrypt: encrypt, of: document, key: key)
        let opened: CTDocument?
        if textMode {
            opened = CipherRun.open(text: document, method: "permutation", title: title, key: key) {
                let c = try PermutationCipher(firstKey: p1, secondKey: p2, options: o)
                return encrypt ? c.encrypt(document.text, textOptions: settings.textOptions)
                               : c.decrypt(document.text, textOptions: settings.textOptions)
            }
        } else {
            opened = CipherRun.open(bytes: document, method: "permutation", title: title, key: key) {
                let c = try PermutationCipher(firstKey: p1, secondKey: p2, options: o)
                return encrypt ? c.encrypt(bytes: document.bytes) : c.decrypt(bytes: document.bytes)
            }
        }
        if opened != nil { close() }
    }
}

// MARK: - Solitaire (IDD_SOLITAIRE, DlgSolitaire.cpp, Solitaire.cpp)

struct SolitaireDialog: View {
    let document: CTDocument
    let close: () -> Void
    @CTState private var cards = 54
    /// 0 Aufsteigend, 1 Absteigend, 2 Gemischt, 3 Passwort, 4 Nach Vorgabe, 5 Kartendeck laden...
    @CTState private var order = 0
    @CTState private var password = ""
    @CTState private var vorgabe: [Int] = []
    @CTState private var initialDeck: [Int] = Solitaire.orderedDeck
    @CTState private var deck = Solitaire(deck: Solitaire.orderedDeck)
    @CTState private var endDeck: [Int]?
    @CTState private var keystream: [Int] = []
    /// nil = no generation started, 0 = automatic finished, 1…5 = next manual step.
    @CTState private var manualStep: Int?
    @CTState private var generationStarted = false

    private static let orders = ["ascending", "descending", "randomly shuffled", "passphrase", "as entered", "load saved card deck..."]

    /// Number of keystream characters (letters A–Z after CT1 preprocessing: Ä → AE, ß → SS …).
    private var needed: Int { Solitaire.letters(document.text).count }
    private var complete: Bool { generationStarted && keystream.count >= needed }
    private var deckReady: Bool { order < 3 || (order == 4 ? vorgabe.count == cards : true) }

    private func label(_ v: Int, of n: Int) -> String { v == n - 1 ? "A" : v == n ? "B" : String(v) }

    var body: some View {
        DialogScaffold(title: "Key Entry / Key Stream Generation: Solitaire", minWidth: 860) {
            CT1Group(title: "Description") {
                Text("With this dialog you can make use of the Solitaire cipher. Usually 54 cards are used. The different cards are represented as numbers from 1 to 52 and as letters A and B.\nStep 1: Either you create the key (the shuffled card deck) by yourself or you load a key. The result of generating the key is the shuffled card deck (\"Initial deck\").\nStep 2: You generate the keystream (This is the actual Solitaire algorithm). This process modifies the card deck; its actual card order can be found at \"Final deck\".\nStep 3: You encrypt the chosen text. In the case the chosen text is already encrypted with the Solitaire, you can also decrypt it.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            CT1Group(title: "1. Generating the initial deck (= shuffling) == Generating the key") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        CT1Group(title: "1 a: Number of cards (classic: 52+2)") {
                            Picker("Total number of cards\n(incl. joker):", selection: $cards) {
                                ForEach(3...54, id: \.self) { Text("\($0)").tag($0) }
                            }.frame(width: 240)
                        }
                        CT1Group(title: "1 b: Defining the card order") {
                            HStack {
                                Picker("", selection: $order) {
                                    ForEach(0..<6, id: \.self) { Text(SolitaireDialog.orders[$0]).tag($0) }
                                }.labelsHidden().frame(width: 160)
                                Button("Different shuffle") { initDeck() }.disabled(order != 2 || generationStarted)
                            }
                        }
                    }.frame(width: 280)
                    CT1Group(title: "Optional") {
                        GroupBox("Enter password") {
                            HStack {
                                TextField("", text: $password).frame(width: 180)
                                    .ct1Filter($password) { s in
                                        let f = String(s.uppercased().filter { ("A"..."Z").contains($0) })
                                        return (f, false)
                                    }
                                Button("Modify the initial deck") { modifyByPassword() }.disabled(password.isEmpty)
                            }.disabled(order != 3 || generationStarted).padding(4)
                        }
                        GroupBox("Own choice") {
                            VStack(alignment: .leading, spacing: 2) {
                                let values = Array(1...cards)
                                ForEach(Array(stride(from: 0, to: values.count, by: 18)), id: \.self) { start in
                                    HStack(spacing: 2) {
                                        ForEach(values[start..<min(start + 18, values.count)], id: \.self) { v in
                                            Button(label(v, of: cards)) { pickCard(v) }
                                                .controlSize(.mini)
                                                .disabled(vorgabe.contains(v))
                                        }
                                    }
                                }
                                Button("Reset") { vorgabe = [] }
                            }.disabled(order != 4 || generationStarted).padding(4)
                        }
                    }
                }
            }
            CT1Group(title: "2. Generating the keystream (automatically or manually)") {
                HStack {
                    Button("Automatic") { finish() }.disabled(generationStarted || !deckReady)
                    Button("Manual") { generationStarted = true; manualStep = 1 }.disabled(generationStarted || !deckReady)
                    GroupBox("Manual steps of the Solitaire algorithm") {
                        HStack {
                            ForEach(1...5, id: \.self) { s in
                                Button("Step \(s)") { step(s) }.disabled(manualStep != s || complete)
                            }
                            if manualStep != nil && manualStep != 0 {
                                Text("You still need \(needed - keystream.count) of \(needed) keystream letters.").font(.callout)
                            }
                            Button("Generate rest") { finish() }.disabled(manualStep != 1 || complete)
                        }.padding(2)
                    }
                }
            }
            CT1Group(title: "Output of the different states of the card deck and of the generated keystream") {
                Text("Initial deck (already shuffled card deck; represents the state of the card deck before the algorithm to generate the keystream is used the first time)").font(.caption)
                HStack {
                    CT1ReadOnlyLine(text: deckReady ? SolitaireAnalysis.deckFileString(initialDeck) : "")
                    Button("Save") { CT1.save(SolitaireAnalysis.deckFileString(initialDeck), defaultName: "initial-deck.txt") }.disabled(!deckReady)
                }
                Text("Final deck (represents the state of the card deck directly after generating the last keystream letter)").font(.caption)
                HStack {
                    CT1ReadOnlyLine(text: endDeck.map(SolitaireAnalysis.deckFileString) ?? "")
                    Button("Save") { if let e = endDeck { CT1.save(SolitaireAnalysis.deckFileString(e), defaultName: "end-deck.txt") } }
                        .disabled(endDeck == nil)
                }
                Text("Keystream").font(.caption)
                HStack(alignment: .top) {
                    ResultBox(text: keystream.map(String.init).joined(separator: ","), minHeight: 44).frame(maxHeight: 60)
                    Button("Save") { CT1.save(keystream.map(String.init).joined(separator: ","), defaultName: "key-stream.txt") }
                        .disabled(!complete)
                }
            }
        } buttons: {
            CT1PasteKeyButton(method: "solitaire") { pasteKey($0) }
            Button("Generate initial state") { reInit() }
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: !complete, help: .solitaire)
        }
        .onChange(of: cards) { _, _ in changeConfiguration() }
        .onChange(of: order) { _, _ in changeConfiguration() }
    }

    // MARK: deck set-up (CDlgSolitaire::ChangeConfiguration / init)

    private func resetGeneration() {
        endDeck = nil
        keystream = []
        manualStep = nil
        generationStarted = false
    }

    private func initDeck() {
        switch order {
        case 0: initialDeck = Solitaire.orderedDeck(cards: cards)
        case 1: initialDeck = Array((1...cards).reversed())
        case 2: initialDeck = Solitaire.shuffledDeck(cards: cards)
        default: break
        }
        deck = Solitaire(deck: initialDeck)
        resetGeneration()
    }

    private func changeConfiguration() {
        vorgabe = []
        if order > 2 { initialDeck = Solitaire.orderedDeck(cards: cards) }
        switch order {
        case 3:
            if cards <= 25 {
                Alerts.error("Could not load the Solitaire deck.", title: "Solitaire")
                cards = 26
                return
            }
        case 5:
            loadDeck()
        default: break
        }
        initDeck()
    }

    private func loadDeck() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let s = try String(contentsOf: url, encoding: .isoLatin1)
            let d = try SolitaireAnalysis.parseDeck(s)
            if d.count != cards { cards = d.count }
            initialDeck = d
        } catch {
            Alerts.error(error.localizedDescription, title: "Solitaire")
        }
    }

    private func modifyByPassword() {
        var s = Solitaire(deck: initialDeck)
        for ch in password {
            guard let a = ch.asciiValue, (65...90).contains(a) else { continue }
            s.step1(); s.step2(); s.step3(); s.step4()
            s.countCut(Int(a) - 64)
        }
        initialDeck = s.deck
        deck = s
        resetGeneration()
    }

    private func pickCard(_ v: Int) {
        vorgabe.append(v)
        if vorgabe.count == cards {
            initialDeck = vorgabe
            deck = Solitaire(deck: initialDeck)
            resetGeneration()
        }
    }

    private func pasteKey(_ s: String) {
        guard let d = try? SolitaireAnalysis.parseDeck(s) else {
            Alerts.error("Could not load the Solitaire deck.", title: "Solitaire")
            return
        }
        order = 4
        cards = d.count
        DispatchQueue.main.async {
            vorgabe = d
            initialDeck = d
            deck = Solitaire(deck: d)
            resetGeneration()
        }
    }

    private func reInit() {
        password = ""
        if cards == 54 && order == 0 { changeConfiguration() } else { cards = 54; order = 0 }
    }

    // MARK: keystream (steps 1–5)

    private func step(_ s: Int) {
        switch s {
        case 1: deck.step1()
        case 2: deck.step2()
        case 3: deck.step3()
        case 4: deck.step4()
        default:
            if let c = deck.step5() { keystream.append(c) }
        }
        endDeck = deck.deck
        manualStep = s == 5 ? 1 : s + 1
        if s == 5 && keystream.count >= needed {
            manualStep = 0
            Alerts.info("All keystream letters produced", title: "Solitaire")
        }
    }

    /// CDlgSolitaire::OnBnFinishCrypt.
    private func finish() {
        generationStarted = true
        while keystream.count < needed {
            deck.step1(); deck.step2(); deck.step3(); deck.step4()
            if let c = deck.step5() { keystream.append(c) }
        }
        endDeck = deck.deck
        manualStep = 0
    }

    private func run(_ encrypt: Bool) {
        let key = SolitaireAnalysis.deckFileString(initialDeck)
        if CipherRun.text(document, method: "solitaire", name: "Solitaire", encrypt: encrypt, key: key, {
            let r = try Solitaire(validating: initialDeck).run(document.text, decrypt: !encrypt)
            return r.output
        }) { close() }
    }
}
