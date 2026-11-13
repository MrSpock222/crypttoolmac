import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 "Solitaire-Analyse: Manuelle Bearbeitung" (DlgSolitaireAnalyse.cpp, IDD_SOLITAIRE_ANALYSE).

extension CT1Analysis {
    /// Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸ Solitaire.
    static func openSolitaireAnalysis(document: CTDocument) {
        guard !SolitaireAnalysis.letters(document.text).isEmpty else {
            // IDS_SOLITAIRE_MESSAGE_1
            Alerts.error("Please enter between 1 and 15,000 characters.")
            return
        }
        let holder = SolitaireAnalysisCT1WindowHolder()
        let w = WindowPresenter.tool(id: "ct1-solitaire-analysis-\(ObjectIdentifier(document).hashValue)",
                                     title: "Solitaire Analysis: Manual Post-Processing",
                                     size: CGSize(width: 860, height: 820)) {
            SolitaireAnalysisCT1View(document: document, close: { holder.window?.close() })
        }
        holder.window = w
    }
}

@MainActor
final class SolitaireAnalysisCT1WindowHolder {
    weak var window: NSWindow?
}

/// State of the analysis dialog (mirrors the enable/disable logic of CT1's dialog).
@MainActor
final class SolitaireAnalysisCT1Model: ObservableObject {
    let document: CTDocument
    /// Ciphertext letters (CT1 `readPlaintext`, max. 65535).
    let letterCount: Int

    // 1. Parameter des gefundenen Decks
    @Published var entryEnabled = false          // group "Nach Vorgabe"
    @Published var cardCount = 54
    @Published var entered: [Int] = []
    @Published var endDeck: [Int]?
    @Published var pastedDeck = ""
    @Published var passphrase = ""
    // 2./3. Joker positionieren, Initial-Deck
    @Published var reverser: SolitaireAnalysis.Reverser?
    @Published var initialDeck: [Int]?
    @Published var lastNote: String?
    // 4. Schlüsselstrom
    @Published var rawKeystream: [Int]?

    init(document: CTDocument) {
        self.document = document
        self.letterCount = SolitaireAnalysis.letters(document.text).count
    }

    var manualRunning: Bool { reverser?.pending != nil }
    var jokerButtonsEnabled: Bool { endDeck != nil && reverser == nil && initialDeck == nil }
    var intermediateDeck: [Int]? { reverser?.deck ?? initialDeck }

    // MARK: Deck input

    /// CT1 "Nach Vorgabe" (IDC_BUTTON6) and the reset after "Abbrechen" in the manual decision.
    func resetForManualEntry() {
        entryEnabled = true
        entered = []
        endDeck = nil
        reverser = nil
        initialDeck = nil
        rawKeystream = nil
        lastNote = nil
    }

    /// CT1 "Reset" (IDC_BUTTON63): clears the entered cards only.
    func resetEntry() {
        entered = []
        endDeck = nil
        reverser = nil
        initialDeck = nil
        rawKeystream = nil
        lastNote = nil
    }

    /// Combo box "Kartenanzahl" changed.
    func cardCountChanged() { resetEntry() }

    /// Card button k pressed (`DoCard`).
    func pick(_ k: Int) {
        guard k <= cardCount else { Alerts.error("Please note the number of cards."); return }   // IDS_SOLITAIRE_MESSAGE_5
        guard !entered.contains(k), endDeck == nil else { return }
        entered.append(k)
        if entered.count >= cardCount {
            endDeck = entered
            Alerts.info("Found Deck entered.")                                    // IDS_SOLITAIRE_MESSAGE_6
        }
    }

    private func useLoadedDeck(_ deck: [Int]) {
        cardCount = deck.count
        entered = deck
        endDeck = deck
        entryEnabled = false
        reverser = nil
        initialDeck = nil
        rawKeystream = nil
        lastNote = nil
    }

    /// CT1 "End-Deck laden" (IDC_BUTTON5): file in CT1 notation ("1,2,…,A,B") or numeric.
    func loadEndDeck() {
        let panel = NSOpenPanel()
        panel.title = "Load final deck"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.nameFieldStringValue = "end-deck.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            Alerts.error("Could not load the Solitaire deck.")
            return
        }
        do {
            useLoadedDeck(try SolitaireAnalysis.parseDeck(TextCoding.string(from: [UInt8](data))))
        } catch {
            Alerts.error(error.localizedDescription)
        }
    }

    /// Mac addition: deck pasted as text.
    func usePastedDeck() {
        do { useLoadedDeck(try SolitaireAnalysis.parseDeck(pastedDeck)) } catch { Alerts.error(error.localizedDescription) }
    }

    /// Mac addition: end deck the sender gets with a passphrase (scenario preparation).
    func computeEndDeckFromPassphrase() {
        guard passphrase.contains(where: { $0.isLetter }) else {
            Alerts.error("Please enter a password (letters A–Z).")
            return
        }
        useLoadedDeck(SolitaireAnalysis.endDeck(passphrase: passphrase, cards: 54, letterCount: letterCount))
    }

    // MARK: Backward calculation

    /// "Immer vorne" / "Immer hinten".
    func runUniform(_ strategy: SolitaireAnalysis.Strategy) {
        guard let end = endDeck else { return }
        do {
            var r = try SolitaireAnalysis.Reverser(endDeck: end, letterCount: letterCount)
            r.run(strategy: strategy)
            finish(r)
        } catch {
            Alerts.error(error.localizedDescription)
        }
    }

    /// "Starten" (manual decisions).
    func startManual() {
        guard let end = endDeck else { return }
        do {
            var r = try SolitaireAnalysis.Reverser(endDeck: end, letterCount: letterCount)
            r.run()
            lastNote = nil
            if r.isFinished { finish(r) } else { reverser = r }
        } catch {
            Alerts.error(error.localizedDescription)
        }
    }

    /// Answer to "Möchten Sie Joker … vorne einsortieren?"; nil = Abbrechen.
    func answer(front: Bool?) {
        guard var r = reverser, let joker = r.pending else { return }
        guard let front else {
            resetForManualEntry()   // CT1 resets the whole dialog on "Abbrechen"
            return
        }
        r.decide(front: front)
        // IDS_SOLITAIRE_MESSAGE_7 / _8 (CT1 shows them as message boxes)
        lastNote = front ? "Joker \(joker.name) put in front." : "Joker \(joker.name) put in back."
        r.run()
        if r.isFinished { finish(r) } else { reverser = r }
    }

    private func finish(_ r: SolitaireAnalysis.Reverser) {
        reverser = nil
        initialDeck = r.deck
        summary = "\(r.roundsReversed) rounds calculated backwards (\(r.nullRounds) of them null rounds), \(r.decisions.count) joker decisions"
            + (r.decisions.isEmpty ? "." : ": " + r.decisions.map { "\($0.joker.name) \($0.front ? "front" : "back")" }.joined(separator: ", ") + ".")
    }

    @Published var summary: String?

    // MARK: Keystream / decryption

    /// "Schlüsselstrom automatisch erzeugen".
    func generateKeystream() {
        guard let d = initialDeck else { return }
        do { rawKeystream = try SolitaireAnalysis.keystream(initialDeck: d, count: letterCount) } catch { Alerts.error(error.localizedDescription) }
    }

    /// "Entschlüsseln": opens the plaintext document (CT1 title "Solitaire-Entschlüsselung von <…>,
    /// Schlüssel <Schlüsselstrom>").
    func decrypt() -> Bool {
        guard let raw = rawKeystream else { return false }
        let plain = SolitaireAnalysis.decrypt(document.text, keystream: raw)
        let key = SolitaireAnalysis.keyString(SolitaireAnalysis.reduced(raw))
        DocumentFactory.openResult(text: plain, title: DocumentFactory.title("Solitaire decryption", of: document, key: key),
                                   parent: document, method: "solitaire", key: key)
        return true
    }
}

struct SolitaireAnalysisCT1View: View {
    let document: CTDocument
    let close: () -> Void
    @StateObject private var model: SolitaireAnalysisCT1Model

    init(document: CTDocument, close: @escaping () -> Void) {
        self.document = document
        self.close = close
        _model = StateObject(wrappedValue: SolitaireAnalysisCT1Model(document: document))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    description
                    GroupBox("Determining the initial deck and generating the keystream") {
                        VStack(alignment: .leading, spacing: 10) {
                            step1
                            step2
                            step3
                            step4
                        }
                        .padding(4)
                    }
                }
                .padding(.trailing, 4)
            }
            Divider()
            HStack {
                Button("Decrypt") { if model.decrypt() { close() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.rawKeystream == nil)
                Text("Ciphertext: \(document.shortName), \(model.letterCount) letters")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 780, minHeight: 640)
    }

    // MARK: Sections

    private var description: some View {
        GroupBox("Description") {
            Text("The legitimate receiver needs for encryption the ciphertext and the initial deck. We suppose, the attacker got beside the ciphertext only the final deck generated by the sender (through encryption) or by the receiver (through decryption).\nThis cryptanalysis tries to reproduce the initial deck from the final deck. Because of the irreversibility of the keystream generation this reverse production succeeds not always in a unique manner. Then you will be asked for the decision, where to place the joker.\nThen the original keystream can be generated from the calculated initial deck.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
    }

    private var step1: some View {
        GroupBox("1. Parameters of the found deck") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Load final deck") { model.loadEndDeck() }
                            .disabled(model.manualRunning)
                        Button("Own choice") { model.resetForManualEntry() }
                            .disabled(model.manualRunning)
                    }
                    .frame(width: 120, alignment: .leading)
                    GroupBox("Own choice") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Number of cards:")
                                Picker("", selection: $model.cardCount) {
                                    ForEach(3...54, id: \.self) { Text("\($0)").tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: 70)
                                .onChange(of: model.cardCount) { _, _ in
                                    if model.entryEnabled { model.cardCountChanged() }
                                }
                                Spacer()
                                Button("Reset") { model.resetEntry() }
                                    .disabled(!model.entryEnabled || model.manualRunning)
                            }
                            cardGrid
                        }
                        .disabled(!model.entryEnabled)
                        .opacity(model.entryEnabled ? 1 : 0.55)
                    }
                }
                DisclosureGroup("Enter the final deck as text or compute it for an example (addition of the Mac version)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("e.g. 1,2,3,…,52,A,B (CT1 file \"end-deck.txt\") or 1,…,53,54", text: $model.pastedDeck)
                                .font(.system(.body, design: .monospaced))
                            Button("Apply") { model.usePastedDeck() }
                                .disabled(model.pastedDeck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack {
                            TextField("Password the sender used for encryption (54 cards)", text: $model.passphrase)
                            Button("Compute the final deck of the sender") { model.computeEndDeckFromPassphrase() }
                        }
                        Text("Simulates the deck of the sender after the encryption of this ciphertext (\(model.letterCount) letters).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .disabled(model.manualRunning)
            }
            .padding(4)
        }
    }

    private var cardGrid: some View {
        let rows = stride(from: 1, through: 54, by: 18).map { Array($0..<min($0 + 18, 55)) }
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 3) {
                    ForEach(row, id: \.self) { k in
                        Button { model.pick(k) } label: {
                            Text("\(k)").font(.system(.caption, design: .monospaced)).frame(width: 22)
                        }
                        .controlSize(.small)
                        .disabled(k > model.cardCount || model.entered.contains(k) || model.endDeck != nil)
                        .help(Solitaire.cardName(k, cards: model.cardCount))
                    }
                }
            }
        }
    }

    private var step2: some View {
        GroupBox("2. Positioning of the joker ") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 14) {
                    GroupBox("Always the same decision") {
                        HStack {
                            Button("Always to front") { model.runUniform(.alwaysFront) }
                            Button("Always to back") { model.runUniform(.alwaysBack) }
                        }
                        .disabled(!model.jokerButtonsEnabled)
                    }
                    GroupBox("Manual") {
                        Button("Start manual") { model.startManual() }
                            .disabled(!model.jokerButtonsEnabled)
                    }
                    Text("Because of the irreversibility of the Solitaire algorithm the user has to decide in special cases of the reverse calculation, where to position the joker.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let r = model.reverser, let joker = r.pending {
                    // CT1: message box "Joker einsortieren" with Ja / Nein / Abbrechen
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Putting Jokers").font(.headline)
                        Text("Do you want to put Joker \(joker.name) to the front?")
                        Text("Round \(r.roundsReversed + 1) of the reverse calculation, \(r.remaining) ciphertext characters left. \"No\" puts the joker in back.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Yes") { model.answer(front: true) }.keyboardShortcut("y", modifiers: [])
                            Button("No") { model.answer(front: false) }.keyboardShortcut("n", modifiers: [])
                            Button("Cancel") { model.answer(front: nil) }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12)))
                }
                if let note = model.lastNote {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
    }

    private var step3: some View {
        GroupBox("3. Generating the initial deck") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Found deck").font(.caption)
                SolitaireAnalysisCT1DeckField(text: SolitaireAnalysis.deckString(model.endDeck ?? model.entered))
                Text("Temporary deck").font(.caption)
                SolitaireAnalysisCT1DeckField(text: model.intermediateDeck.map(SolitaireAnalysis.deckString) ?? "")
                Text("Initial deck").font(.caption)
                SolitaireAnalysisCT1DeckField(text: model.initialDeck.map(SolitaireAnalysis.deckString) ?? "")
                if let s = model.summary, model.initialDeck != nil {
                    Text(s).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private var step4: some View {
        GroupBox("4. Generating the keystream") {
            VStack(alignment: .leading, spacing: 6) {
                Button("Automatically generate the keystream") { model.generateKeystream() }
                    .disabled(model.initialDeck == nil || model.rawKeystream != nil)
                ResultBox(text: model.rawKeystream.map(SolitaireAnalysis.keyString) ?? "", minHeight: 50)
                    .frame(maxHeight: 90)
            }
            .padding(4)
        }
    }
}

/// Read-only deck display (CT1 edit fields IDC_EDIT1 / IDC_EDIT132 / IDC_EDIT2).
struct SolitaireAnalysisCT1DeckField: View {
    let text: String
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}
