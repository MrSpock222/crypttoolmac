import CTCommon

/// CT1 "Solitaire-Analyse" (Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸ Ciphertext-Only ▸
/// Solitaire; CT1 sources `DlgSolitaireAnalyse.cpp` and class `Deck` in `Solitaire.cpp`).
///
/// Scenario: the attacker knows the ciphertext and the *end deck* (the deck after the sender's
/// encryption). The Solitaire rounds are undone one by one (steps 4, 3, 2, 1 reversed); after each
/// reversed round CT1 checks whether the previous deck would have produced a joker in step 5
/// ("Nullrunde") – then one more round is reversed. The result is the *initial deck*, from which the
/// keystream and the plaintext follow.
///
/// Steps 1 and 2 are not uniquely reversible: if joker B lies at position 3 (index 2) it came either
/// from the top or from the bottom of the deck; joker A at position 2 (index 1) likewise. CT1 offers
/// "Immer vorne", "Immer hinten" or a manual decision per occurrence ("Starten"). All operations
/// below reproduce CT1's `Deck` methods exactly (including its handling of decks that cannot occur
/// in a correct backward calculation, e.g. joker A on top after reversing steps 4 and 3).
///
/// Card values: 1 … n with joker A = n − 1 and joker B = n (n = 3 … 54 cards).
public enum SolitaireAnalysis {
    /// CT1 truncates the ciphertext to 65535 letters.
    public static let maxLetters = 65_535

    /// The two jokers.
    public enum Joker: Sendable, Equatable {
        case a, b
        /// "A" / "B".
        public var name: String { self == .a ? "A" : "B" }
    }

    /// CT1 "Einheitliche Entscheidung".
    public enum Strategy: Sendable, Equatable {
        /// "Immer vorne" (`Deck::analysevorne`).
        case alwaysFront
        /// "Immer hinten" (`Deck::analysehinten`).
        case alwaysBack
    }

    /// One decision taken during the backward calculation.
    public struct Decision: Sendable, Equatable {
        public let joker: Joker
        /// true = joker placed in front ("vorne"), false = at the end ("hinten").
        public let front: Bool
        /// Number of the reversed round (1-based) in which the question occurred.
        public let round: Int
    }

    // MARK: Text

    /// Letter values (A = 1 … Z = 26) of a ciphertext as read by CT1 (`Deck::readPlaintext`: letters
    /// A–Z/a–z, Ä/Ö/Ü/ß transcribed, everything else dropped), truncated to `maxLetters`.
    public static func letters(_ text: String) -> [Int] {
        let l = Solitaire.letters(text)
        return l.count > maxLetters ? Array(l.prefix(maxLetters)) : l
    }

    // MARK: Deck notation

    /// CT1 `Deck::getDeck`: card values separated by commas ("1,2,…,53,54").
    public static func deckString(_ deck: [Int]) -> String {
        deck.map(String.init).joined(separator: ",")
    }

    /// CT1 deck file format (`end-deck.txt` written by the Solitaire dialog): cards separated by
    /// commas, the jokers written as "A" and "B" ("1,2,…,52,A,B").
    public static func deckFileString(_ deck: [Int]) -> String {
        let n = deck.count
        return deck.map { $0 == n - 1 ? "A" : $0 == n ? "B" : String($0) }.joined(separator: ",")
    }

    /// Parses a deck in CT1's file notation ("…,A,B", as written by the CT1 Solitaire dialog) or in
    /// purely numeric notation ("1,2,…,54", jokers = n − 1 and n). Separators: commas, semicolons,
    /// whitespace. Throws an error message for invalid decks.
    public static func parseDeck(_ s: String) throws -> [Int] {
        let tokens = s.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }).map { String($0).uppercased() }
        guard !tokens.isEmpty else { throw CTError("Could not load the Solitaire deck (no cards found).") }
        guard tokens.count <= 54 else {
            throw CTError("Could not load the Solitaire deck (more than 54 cards).")
        }
        let hasLetters = tokens.contains("A") || tokens.contains("B")
        let n = tokens.count
        var deck: [Int] = []
        for t in tokens {
            if t == "A" { deck.append(n - 1); continue }
            if t == "B" { deck.append(n); continue }
            guard let v = Int(t) else {
                throw CTError("Could not load the Solitaire deck (\"\(t)\" is not a valid card).")
            }
            if hasLetters && (v < 1 || v > n - 2) {
                throw CTError("Could not load the Solitaire deck (card \(v) does not match \(n) cards; the jokers are called A and B).")
            }
            deck.append(v)
        }
        if hasLetters && !(tokens.contains("A") && tokens.contains("B")) {
            throw CTError("Could not load the Solitaire deck (both jokers A and B must be included).")
        }
        do {
            return try Solitaire.validated(deck)
        } catch {
            throw CTError("Could not load the Solitaire deck. \(error.localizedDescription)")
        }
    }

    // MARK: CT1 Deck operations (reverse direction)

    /// `Deck::schritt4revers`: undoes the count cut.
    static func reverseStep4(_ deck: inout [Int]) {
        let n = deck.count
        var a = deck[n - 1]
        if a == n { a -= 1 }
        let t = deck
        var k = 0
        for j in (n - 1 - a)..<(n - 1) { deck[k] = t[j]; k += 1 }
        k = 0
        for l in a..<(n - 1) { deck[l] = t[k]; k += 1 }
    }

    /// `Deck::schritt3revers` (= `schritt3`): the triple cut is its own inverse.
    static func tripleCut(_ deck: inout [Int]) {
        let n = deck.count
        guard let pa = deck.firstIndex(of: n - 1), let pb = deck.firstIndex(of: n) else { return }
        let lo = min(pa, pb), hi = max(pa, pb)
        deck = Array(deck[(hi + 1)...]) + Array(deck[lo...hi]) + Array(deck[..<lo])
    }

    /// `Deck::schritt2reversabfrage`: undoes step 2 if unique; returns true if joker B lies at
    /// index 2 and the user has to decide (deck unchanged then).
    static func reverseStep2NeedsDecision(_ deck: inout [Int]) -> Bool {
        let n = deck.count, jb = n
        if deck[1] == jb {
            deck.remove(at: 1); deck.insert(jb, at: n - 2)
            return false
        }
        if deck[0] == jb {
            deck.remove(at: 0); deck.insert(jb, at: n - 3)
            return false
        }
        if deck[2] == jb { return true }
        if let i = deck.firstIndex(of: jb), i >= 3 {
            deck.remove(at: i); deck.insert(jb, at: i - 2)
            return false
        }
        return true
    }

    /// `Deck::schritt1reversabfrage`: undoes step 1 if unique; returns true if joker A lies at
    /// index 1 and the user has to decide (deck unchanged then).
    static func reverseStep1NeedsDecision(_ deck: inout [Int]) -> Bool {
        let n = deck.count, ja = n - 1
        if deck[0] == ja {
            deck.remove(at: 0); deck.insert(ja, at: n - 2)
            return false
        }
        if deck[1] == ja { return true }
        if let i = deck.firstIndex(of: ja), i >= 2 {
            deck.swapAt(i, i - 1)
            return false
        }
        return true
    }

    /// `vorneeinordnenb` / `hinteneinordnenb` / `vorneeinordnena` / `hinteneinordnena`.
    static func place(_ joker: Joker, front: Bool, in deck: inout [Int]) {
        switch (joker, front) {
        case (.b, true):
            let t = deck[2]; deck[2] = deck[1]; deck[1] = deck[0]; deck[0] = t
        case (.b, false):
            let t = deck.remove(at: 2); deck.append(t)
        case (.a, true):
            deck.swapAt(0, 1)
        case (.a, false):
            let t = deck.remove(at: 1); deck.append(t)
        }
    }

    /// `Deck::pruefenullrunde`: true if step 5 would hit a joker for this deck.
    public static func isNullRound(_ deck: [Int]) -> Bool {
        let n = deck.count
        var a = deck[0]
        if a == n { a -= 1 }
        return deck[a] >= n - 1
    }

    // MARK: Backward calculation

    /// Resumable backward calculation from the end deck to the initial deck (CT1 steps 2 and 3).
    public struct Reverser: Sendable {
        private enum Phase: Sendable { case start, step1, finish }

        /// The current ("Zwischendeck") deck.
        public private(set) var deck: [Int]
        /// The end deck the calculation started with.
        public let endDeck: [Int]
        /// Number of ciphertext letters (= rounds that produced an output).
        public let letterCount: Int
        /// Remaining output rounds (CT1 loop counter).
        public private(set) var remaining: Int
        /// Number of rounds reversed so far (including null rounds).
        public private(set) var roundsReversed = 0
        /// Number of null rounds detected so far.
        public private(set) var nullRounds = 0
        /// Joker awaiting a manual decision (nil if none).
        public private(set) var pending: Joker?
        /// All decisions taken (manual or by strategy).
        public private(set) var decisions: [Decision] = []
        private var phase: Phase = .start

        /// True when the initial deck has been reached.
        public var isFinished: Bool { remaining == 0 && pending == nil && phase == .start }
        /// The initial deck (nil until finished).
        public var initialDeck: [Int]? { isFinished ? deck : nil }

        /// Starts at `endDeck` (validated) for `letterCount` ciphertext letters.
        public init(endDeck: [Int], letterCount: Int) throws {
            let d = try Solitaire.validated(endDeck)
            self.deck = d
            self.endDeck = d
            self.letterCount = max(0, letterCount)
            self.remaining = max(0, letterCount)
        }

        /// Continues the calculation. With a `strategy`, every ambiguity is decided automatically
        /// and the call returns when the initial deck is reached; without, the call stops at the
        /// next ambiguity (`pending` != nil) – answer it with `decide(front:)`.
        public mutating func run(strategy: Strategy? = nil, cancel: CancellationToken? = nil) {
            var steps = 0
            while true {
                if let p = pending {
                    guard let s = strategy else { return }
                    resolve(p, front: s == .alwaysFront)
                }
                switch phase {
                case .start:
                    if remaining == 0 { return }
                    steps += 1
                    if steps & 4095 == 0, cancel?.isCancelled == true { return }
                    SolitaireAnalysis.reverseStep4(&deck)
                    SolitaireAnalysis.tripleCut(&deck)
                    phase = .step1
                    if SolitaireAnalysis.reverseStep2NeedsDecision(&deck) { pending = .b }
                case .step1:
                    phase = .finish
                    if SolitaireAnalysis.reverseStep1NeedsDecision(&deck) { pending = .a }
                case .finish:
                    roundsReversed += 1
                    if SolitaireAnalysis.isNullRound(deck) && remaining > 1 {
                        nullRounds += 1
                    } else {
                        remaining -= 1
                    }
                    phase = .start
                }
            }
        }

        /// Answers the pending question ("Möchten Sie Joker … vorne einsortieren?").
        public mutating func decide(front: Bool) {
            guard let p = pending else { return }
            resolve(p, front: front)
        }

        private mutating func resolve(_ joker: Joker, front: Bool) {
            SolitaireAnalysis.place(joker, front: front, in: &deck)
            decisions.append(Decision(joker: joker, front: front, round: roundsReversed + 1))
            pending = nil
        }
    }

    /// Convenience: complete backward calculation with a uniform strategy.
    public static func initialDeck(endDeck: [Int], letterCount: Int, strategy: Strategy) throws -> [Int] {
        var r = try Reverser(endDeck: endDeck, letterCount: letterCount)
        r.run(strategy: strategy)
        return r.deck
    }

    // MARK: Keystream and decryption

    /// CT1 "Schlüsselstrom automatisch erzeugen": raw card values (1 … n − 2, before reduction
    /// modulo 26) for `count` letters, starting with `initialDeck` (null rounds are skipped).
    public static func keystream(initialDeck: [Int], count: Int) throws -> [Int] {
        var s = try Solitaire(validating: initialDeck)
        var out: [Int] = []
        out.reserveCapacity(max(0, count))
        for _ in 0..<max(0, count) {
            s.step1(); s.step2(); s.step3(); s.step4()
            while s.step5() == nil { s.step1(); s.step2(); s.step3(); s.step4() }
            out.append(s.step5()!)
        }
        return out
    }

    /// CT1 `Deck::keyUmrechnen`: value modulo 26, 0 → 26.
    public static func reduced(_ raw: [Int]) -> [Int] {
        raw.map { let v = $0 % 26; return v == 0 ? 26 : v }
    }

    /// Keystream notation of CT1 (`Deck::getKey`): values separated by commas.
    public static func keyString(_ values: [Int]) -> String {
        values.map(String.init).joined(separator: ",")
    }

    /// CT1 `Deck::entschluesseln` + `writeplaintext`: decrypts the letters of `ciphertext` with the
    /// keystream (raw or reduced values) and writes the plaintext in uppercase groups of five
    /// separated by single spaces (no line breaks).
    public static func decrypt(_ ciphertext: String, keystream: [Int]) -> String {
        let c = letters(ciphertext)
        let k = reduced(keystream)
        var out = String()
        out.reserveCapacity(c.count + c.count / 5)
        for (i, v) in c.enumerated() where i < k.count {
            var p = (v - k[i]) % 26
            if p <= 0 { p += 26 }
            if i > 0 && i % 5 == 0 { out.append(" ") }
            out.append(Character(Unicode.Scalar(UInt8(64 + p))))
        }
        return out
    }

    /// End deck the sender has after encrypting `letterCount` letters with a passphrase-keyed
    /// deck (scenario preparation; not part of CT1's analysis dialog).
    public static func endDeck(passphrase: String, cards: Int = 54, letterCount: Int) -> [Int] {
        Solitaire(passphrase: passphrase, cards: cards).finalDeck(after: letterCount)
    }

    /// End deck after `letterCount` letters starting from an explicit initial deck.
    public static func endDeck(initialDeck: [Int], letterCount: Int) throws -> [Int] {
        try Solitaire(validating: initialDeck).finalDeck(after: letterCount)
    }
}
