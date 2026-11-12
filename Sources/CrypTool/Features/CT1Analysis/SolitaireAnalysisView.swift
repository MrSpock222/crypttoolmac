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
            Alerts.error("Die Eingabe muss mindestens ein Zeichen und höchstens 15.000 Zeichen enthalten.")
            return
        }
        let holder = SolitaireAnalysisCT1WindowHolder()
        let w = WindowPresenter.tool(id: "ct1-solitaire-analysis-\(ObjectIdentifier(document).hashValue)",
                                     title: "Solitaire-Analyse: Manuelle Bearbeitung",
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
        guard k <= cardCount else { Alerts.error("Kartenanzahl beachten."); return }   // IDS_SOLITAIRE_MESSAGE_5
        guard !entered.contains(k), endDeck == nil else { return }
        entered.append(k)
        if entered.count >= cardCount {
            endDeck = entered
            Alerts.info("Gefundenes Deck eingegeben.")                                    // IDS_SOLITAIRE_MESSAGE_6
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
        panel.title = "End-Deck laden"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.nameFieldStringValue = "end-deck.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            Alerts.error("Das Solitaire-Deck konnte nicht geladen werden.")
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
            Alerts.error("Bitte ein Passwort (Buchstaben A–Z) eingeben.")
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
        lastNote = front ? "Joker \(joker.name) vorne einsortiert." : "Joker \(joker.name) hinten einsortiert."
        r.run()
        if r.isFinished { finish(r) } else { reverser = r }
    }

    private func finish(_ r: SolitaireAnalysis.Reverser) {
        reverser = nil
        initialDeck = r.deck
        summary = "\(r.roundsReversed) Runden zurückgerechnet (davon \(r.nullRounds) Nullrunden), \(r.decisions.count) Joker-Entscheidungen"
            + (r.decisions.isEmpty ? "." : ": " + r.decisions.map { "\($0.joker.name) \($0.front ? "vorne" : "hinten")" }.joined(separator: ", ") + ".")
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
        DocumentFactory.openResult(text: plain, title: DocumentFactory.title("Solitaire-Entschlüsselung", of: document, key: key),
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
                    GroupBox("Initial-Deck bestimmen und Schlüsselstrom erzeugen") {
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
                Button("Entschlüsseln") { if model.decrypt() { close() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.rawKeystream == nil)
                Text("Geheimtext: \(document.shortName), \(model.letterCount) Buchstaben")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 780, minHeight: 640)
    }

    // MARK: Sections

    private var description: some View {
        GroupBox("Beschreibung") {
            Text("Der legitime Empfänger braucht zur Entschlüsselung den Geheimtext und das „Initial-Deck“. Wir nehmen an, der Angreifer hat neben dem Geheimtext aber nur das (vom Sender bei der Verschlüsselung, oder vom Empfänger bei der Entschlüsselung erzeugte) End-Deck.\nBei dieser Kryptoanalyse wird versucht, aus dem End-Deck das Initial-Deck zu reproduzieren. Dies gelingt aufgrund der unvollständigen Reversibilität der Schlüsselstrom-Erzeugung nicht immer eindeutig. Deshalb müssen Sie entscheiden, wo der Joker einzusortieren ist.\nAus dem berechneten Initial-Deck kann dann wieder der nötige Schlüsselstrom berechnet werden.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
    }

    private var step1: some View {
        GroupBox("1. Parameter des gefundenen Decks") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("End-Deck laden") { model.loadEndDeck() }
                            .disabled(model.manualRunning)
                        Button("Nach Vorgabe") { model.resetForManualEntry() }
                            .disabled(model.manualRunning)
                    }
                    .frame(width: 120, alignment: .leading)
                    GroupBox("Nach Vorgabe") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Kartenanzahl:")
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
                DisclosureGroup("End-Deck als Text eingeben oder für ein Beispiel berechnen (Ergänzung der Mac-Version)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("z. B. 1,2,3,…,52,A,B (CT1-Datei „end-deck.txt“) oder 1,…,53,54", text: $model.pastedDeck)
                                .font(.system(.body, design: .monospaced))
                            Button("Übernehmen") { model.usePastedDeck() }
                                .disabled(model.pastedDeck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack {
                            TextField("Passwort, mit dem der Sender verschlüsselt hat (54 Karten)", text: $model.passphrase)
                            Button("End-Deck des Senders berechnen") { model.computeEndDeckFromPassphrase() }
                        }
                        Text("Simuliert das Kartenspiel des Senders nach der Verschlüsselung dieses Geheimtextes (\(model.letterCount) Buchstaben).")
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
        GroupBox("2. Joker positionieren") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 14) {
                    GroupBox("Einheitliche Entscheidung") {
                        HStack {
                            Button("Immer vorne") { model.runUniform(.alwaysFront) }
                            Button("Immer hinten") { model.runUniform(.alwaysBack) }
                        }
                        .disabled(!model.jokerButtonsEnabled)
                    }
                    GroupBox("Manuell") {
                        Button("Starten") { model.startManual() }
                            .disabled(!model.jokerButtonsEnabled)
                    }
                    Text("Aufgrund der Irreversibilität von Solitaire müssen an bestimmten Stellen der Rückwärtsrechnung Entscheidungen getroffen werden, wo der entsprechende Joker einzuordnen ist.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let r = model.reverser, let joker = r.pending {
                    // CT1: message box "Joker einsortieren" with Ja / Nein / Abbrechen
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Joker einsortieren").font(.headline)
                        Text("Möchten Sie Joker \(joker.name) vorne einsortieren?")
                        Text("Runde \(r.roundsReversed + 1) der Rückwärtsrechnung, noch \(r.remaining) Geheimtextzeichen. „Nein“ sortiert den Joker hinten ein.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Ja") { model.answer(front: true) }.keyboardShortcut("j", modifiers: [])
                            Button("Nein") { model.answer(front: false) }.keyboardShortcut("n", modifiers: [])
                            Button("Abbrechen") { model.answer(front: nil) }
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
        GroupBox("3. Initial-Deck erzeugen") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gefundenes Deck (= End-Deck)").font(.caption)
                SolitaireAnalysisCT1DeckField(text: SolitaireAnalysis.deckString(model.endDeck ?? model.entered))
                Text("Zwischendeck").font(.caption)
                SolitaireAnalysisCT1DeckField(text: model.intermediateDeck.map(SolitaireAnalysis.deckString) ?? "")
                Text("Initial-Deck").font(.caption)
                SolitaireAnalysisCT1DeckField(text: model.initialDeck.map(SolitaireAnalysis.deckString) ?? "")
                if let s = model.summary, model.initialDeck != nil {
                    Text(s).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private var step4: some View {
        GroupBox("4. Schlüsselstrom erzeugen") {
            VStack(alignment: .leading, spacing: 6) {
                Button("Schlüsselstrom automatisch erzeugen") { model.generateKeystream() }
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
