import CTCommon

/// Bruce Schneier's Solitaire ("Pontifex") stream cipher as in CT1.
///
/// The deck is an array of card values 1…n (n = 54 for the full deck: 52 cards and the jokers
/// A = n−1 and B = n). CT1 also allows smaller decks (3…54 cards). Both jokers count as n−1.
/// Keystream values > 26 are reduced by 26; letters are combined as A = 1 … Z = 26.
///
/// Text handling as in CT1: letters A–Z (case-insensitive), Ä/Ö/Ü → AE/OE/UE, ß → SS, everything
/// else is dropped; the output is written in groups of five letters, 14 groups per line. CT1 does
/// not pad the plaintext – `padWithX` enables Schneier's padding with X to a multiple of five.
public struct Solitaire: Sendable {
    /// Current deck (top card first).
    public private(set) var deck: [Int]
    /// Number of cards (including the two jokers).
    public var cardCount: Int { deck.count }
    public var jokerA: Int { deck.count - 1 }
    public var jokerB: Int { deck.count }

    /// Ordered deck 1…54.
    public static var orderedDeck: [Int] { Array(1...54) }

    /// Ordered deck with `cards` cards (3…54).
    public static func orderedDeck(cards: Int) -> [Int] { Array(1...max(3, min(cards, 54))) }

    /// Uses `deck` if it is a valid deck (permutation of 1…n, 3 ≤ n ≤ 54), otherwise the ordered
    /// 54-card deck. Use `init(validating:)` to get an error instead.
    public init(deck: [Int]) {
        self.deck = (try? Solitaire.validated(deck)) ?? Solitaire.orderedDeck
    }

    /// Throws a German error message if `deck` is not a permutation of 1…n (3 ≤ n ≤ 54).
    public init(validating deck: [Int]) throws {
        self.deck = try Solitaire.validated(deck)
    }

    /// Ordered deck keyed with a passphrase (Schneier/CT1: for every letter perform steps 1–4 and
    /// then a count cut with the letter value A = 1 … Z = 26). Non-letters are ignored.
    public init(passphrase: String, cards: Int = 54) {
        self.deck = Solitaire.orderedDeck(cards: cards)
        if deck.count >= 26 {
            for ch in passphrase {
                guard let v = latinLetterValue(ch) else { continue }
                step1(); step2(); step3(); step4()
                countCut(v + 1)
            }
        }
    }

    /// Validates a deck.
    public static func validated(_ deck: [Int]) throws -> [Int] {
        let n = deck.count
        guard n >= 3 && n <= 54 else {
            throw CTError("Ein Solitaire-Kartenspiel muss aus 3 bis 54 Karten bestehen (hier: \(n)).")
        }
        guard Set(deck) == Set(1...n) else {
            throw CTError("Das Kartenspiel muss jede Karte 1…\(n) genau einmal enthalten (die Joker sind \(n - 1) und \(n)).")
        }
        return deck
    }

    /// Parses a deck in CT1 notation ("1,2,3,…"; separators: commas, spaces, semicolons).
    public static func parseDeck(_ s: String) throws -> [Int] {
        var out: [Int] = []
        for t in s.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }) {
            guard let v = Int(t) else { throw CTError("„\(t)“ ist keine gültige Kartennummer.") }
            out.append(v)
        }
        return try validated(out)
    }

    /// Deck in CT1 notation.
    public var deckString: String { deck.map(String.init).joined(separator: ",") }

    /// Display name of a card (Schneier's bridge order: clubs, diamonds, hearts, spades).
    public static func cardName(_ value: Int, cards: Int = 54) -> String {
        if value == cards - 1 { return "Joker A" }
        if value == cards { return "Joker B" }
        let suits = ["♣", "♦", "♥", "♠"]
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "B", "D", "K"]
        let v = value - 1
        return suits[(v / 13) % 4] + ranks[v % 13]
    }

    // MARK: Algorithm steps (public for step-by-step visualisation)

    /// Step 1: move joker A one card down (from the bottom it wraps to below the top card).
    public mutating func step1() { moveDown(jokerA, by: 1) }

    /// Step 2: move joker B two cards down (wrapping like step 1).
    public mutating func step2() { moveDown(jokerB, by: 2) }

    private mutating func moveDown(_ card: Int, by steps: Int) {
        let n = deck.count
        var pos = deck.firstIndex(of: card)!
        for _ in 0..<steps {
            if pos == n - 1 {
                deck.remove(at: pos)
                deck.insert(card, at: 1)
                pos = 1
            } else {
                deck.swapAt(pos, pos + 1)
                pos += 1
            }
        }
    }

    /// Step 3: triple cut around the jokers.
    public mutating func step3() {
        let a = deck.firstIndex(of: jokerA)!, b = deck.firstIndex(of: jokerB)!
        let lo = min(a, b), hi = max(a, b)
        // [X][J…J][Y] → [Y][J…J][X] in place: reverse all, then each part
        let n = deck.count
        reverseCards(0, n)
        let ySize = n - 1 - hi, mid = hi - lo + 1
        reverseCards(0, ySize)
        reverseCards(ySize, ySize + mid)
        reverseCards(ySize + mid, n)
    }

    /// Reverses deck[lo..<hi] in place.
    @inline(__always)
    private mutating func reverseCards(_ lo: Int, _ hi: Int) {
        var i = lo, j = hi - 1
        while i < j { deck.swapAt(i, j); i += 1; j -= 1 }
    }

    /// Step 4: count cut using the value of the bottom card.
    public mutating func step4() {
        countCut(min(deck.last!, deck.count - 1))
    }

    /// Count cut: move the top `count` cards just above the bottom card.
    public mutating func countCut(_ count: Int) {
        let n = deck.count
        let c = max(0, min(count, n - 1))
        guard c > 0 else { return }
        // rotate the first n−1 cards left by c (in place), the bottom card stays
        reverseCards(0, c)
        reverseCards(c, n - 1)
        reverseCards(0, n - 1)
    }

    /// Step 5: output card (value of the card below the top-card count), nil if it is a joker.
    public func step5() -> Int? {
        let count = min(deck[0], deck.count - 1)
        let card = deck[count]
        return card >= deck.count - 1 ? nil : card
    }

    /// Next keystream value 1…26 (performs steps 1–5, repeating if a joker is hit).
    public mutating func nextKeystreamValue() -> Int {
        while true {
            step1(); step2(); step3(); step4()
            if let c = step5() {
                var v = c
                while v > 26 { v -= 26 }
                return v
            }
        }
    }

    /// Keystream values (1…26) starting from the current deck (the deck itself is not changed).
    public func keystream(count: Int) -> [Int] {
        var s = self
        return (0..<max(0, count)).map { _ in s.nextKeystreamValue() }
    }

    /// Deck after generating `count` keystream values.
    public func finalDeck(after count: Int) -> [Int] {
        var s = self
        for _ in 0..<max(0, count) { _ = s.nextKeystreamValue() }
        return s.deck
    }

    // MARK: Text

    /// Letter values (1…26) of the text in CT1 preprocessing.
    public static func letters(_ text: String) -> [Int] {
        var out: [Int] = []
        for ch in text {
            if let t = umlautTranscription(ch) {
                for c in t { out.append(latinLetterValue(c)! + 1) }
            } else if let v = latinLetterValue(ch) {
                out.append(v + 1)
            }
        }
        return out
    }

    /// Result of a Solitaire run (for display of keystream and final deck).
    public struct Result: Sendable {
        public var output: String
        public var keystream: [Int]
        public var finalDeck: [Int]
    }

    /// Encrypts or decrypts and returns output, keystream and final deck.
    public func run(_ text: String, decrypt: Bool, padWithX: Bool = false, grouped: Bool = true) -> Result {
        var vals = Solitaire.letters(text)
        if padWithX && !decrypt { while vals.count % 5 != 0 { vals.append(24) } }
        var s = self
        var ks: [Int] = []
        ks.reserveCapacity(vals.count)
        var out = String()
        for v in vals {
            let k = s.nextKeystreamValue()
            ks.append(k)
            var r = decrypt ? v - k : v + k
            if r > 26 { r -= 26 }
            if r < 1 { r += 26 }
            out.append(Character(Unicode.Scalar(UInt8(64 + r))))
        }
        let formatted = grouped ? groupText(out, size: 5, blocksPerLine: 14) : out
        return Result(output: formatted, keystream: ks, finalDeck: s.deck)
    }

    /// Encrypts (grouped output); `padWithX` pads to a multiple of five (Schneier, not CT1).
    public func encrypt(_ text: String, padWithX: Bool = false) -> String {
        run(text, decrypt: false, padWithX: padWithX).output
    }

    /// Decrypts (grouped output).
    public func decrypt(_ text: String) -> String {
        run(text, decrypt: true).output
    }

    /// Randomly shuffled deck.
    public static func shuffledDeck(cards: Int = 54) -> [Int] { orderedDeck(cards: cards).shuffled() }
}
