import Foundation
import CTCommon
import CTClassic

/// Forward simulation that records, for every round (incl. null rounds), the deck before the
/// round and after step 1 – used as an oracle for the joker decisions of the backward calculation.
private func forwardHistory(_ initial: [Int], letters: Int) -> (start: [[Int]], afterStep1: [[Int]], end: [Int]) {
    var s = Solitaire(deck: initial)
    var starts: [[Int]] = [], afterStep1: [[Int]] = []
    var produced = 0
    while produced < letters {
        starts.append(s.deck)
        s.step1()
        afterStep1.append(s.deck)
        s.step2(); s.step3(); s.step4()
        if s.step5() != nil { produced += 1 }
    }
    return (starts, afterStep1, s.deck)
}

/// Runs the manual backward calculation, answering every question like the true history.
private func reverseWithOracle(endDeck: [Int], letters: Int, history: (start: [[Int]], afterStep1: [[Int]], end: [Int])) throws -> SolitaireAnalysis.Reverser {
    var r = try SolitaireAnalysis.Reverser(endDeck: endDeck, letterCount: letters)
    let total = history.start.count
    let n = endDeck.count
    while true {
        r.run()
        guard let p = r.pending else { break }
        let forwardRound = total - 1 - r.roundsReversed      // round currently being reversed
        guard forwardRound >= 0 else { r.decide(front: true); continue }
        switch p {
        case .b: r.decide(front: history.afterStep1[forwardRound].firstIndex(of: n) == 0)
        case .a: r.decide(front: history.start[forwardRound].firstIndex(of: n - 1) == 0)
        }
    }
    return r
}

/// CT1 Solitaire-Analyse (DlgSolitaireAnalyse / Deck) – called from main.swift.
func runCT1SolitaireAnalysisTests() {
    group("CT1 Solitaire-Analyse: Schneier-Testvektor") {
        // Unkeyed deck, plaintext AAAAAAAAAA → EXKYI ZSGEH (raw keystream 4 49 10 24 8 51 44 6 4 33)
        let ordered = Solitaire.orderedDeck
        let raw = try SolitaireAnalysis.keystream(initialDeck: ordered, count: 10)
        expectEqual(raw, [4, 49, 10, 24, 8, 51, 44, 6, 4, 33])
        expectEqual(SolitaireAnalysis.reduced(raw), [4, 23, 10, 24, 8, 25, 18, 6, 4, 7])
        expectEqual(SolitaireAnalysis.decrypt("EXKYI ZSGEH", keystream: raw), "AAAAA AAAAA")
        let end = Solitaire(deck: ordered).finalDeck(after: 10)
        let hist = forwardHistory(ordered, letters: 10)
        expectEqual(hist.end, end)
        let r = try reverseWithOracle(endDeck: end, letters: 10, history: hist)
        expect(r.isFinished)
        expectEqual(r.initialDeck ?? [], ordered, "Initial-Deck rekonstruiert")
        expectEqual(r.roundsReversed, hist.start.count, "Anzahl Runden inkl. Nullrunden")
    }

    group("CT1 Solitaire-Analyse: deutscher Text, 54 Karten, manuelle Entscheidungen") {
        let plain = "Kryptographie ist die Wissenschaft von der Verschluesselung von Informationen. Die Solitaire-Chiffre wurde von Bruce Schneier fuer den Roman Cryptonomicon entworfen und kommt mit einem Kartenspiel aus."
        let cipher = Solitaire(passphrase: "CRYPTOOL").encrypt(plain)
        let n = SolitaireAnalysis.letters(cipher).count
        let initial = Solitaire(passphrase: "CRYPTOOL").deck
        let end = SolitaireAnalysis.endDeck(passphrase: "CRYPTOOL", letterCount: n)
        let hist = forwardHistory(initial, letters: n)
        expectEqual(hist.end, end)
        let r = try reverseWithOracle(endDeck: end, letters: n, history: hist)
        expectEqual(r.initialDeck ?? [], hist.start[hist.start.count - r.roundsReversed], "Initial-Deck")
        let ks = try SolitaireAnalysis.keystream(initialDeck: r.deck, count: n)
        let expectedPlain = Solitaire.letters(plain).map { Character(Unicode.Scalar(UInt8(64 + $0))) }
        let dec = SolitaireAnalysis.decrypt(cipher, keystream: ks)
        expectEqual(dec.replacingOccurrences(of: " ", with: ""), String(expectedPlain))
        expect(!dec.contains("\n") && dec.split(separator: " ").allSatisfy { $0.count <= 5 }, "CT1-Ausgabeformat (Fünfergruppen, eine Zeile)")
        expectEqual(SolitaireAnalysis.reduced(ks), Solitaire(passphrase: "CRYPTOOL").keystream(count: n))
    }

    group("CT1 Solitaire-Analyse: Strategien und kleine Decks") {
        // Over many random decks: a backward run without any question is unique and must hit the
        // true initial deck; with questions, "immer vorne"/"immer hinten" equal the oracle result
        // whenever all true answers were "vorne" resp. "hinten".
        var rng = SystemRandomNumberGenerator()
        var unique = 0, checkedFront = 0, checkedBack = 0
        for trial in 0..<300 {
            let cards = trial % 3 == 0 ? 54 : Int.random(in: 6...54, using: &rng)
            let initial = Solitaire.orderedDeck(cards: cards).shuffled(using: &rng)
            let letters = Int.random(in: 1...40, using: &rng)
            let hist = forwardHistory(initial, letters: letters)
            let trueKs = try SolitaireAnalysis.keystream(initialDeck: initial, count: letters)
            let r = try reverseWithOracle(endDeck: hist.end, letters: letters, history: hist)
            // CT1 stops before leading null rounds (loop condition i > 1) – such a deck yields the
            // same keystream, so it is an equally valid initial deck.
            let total = hist.start.count
            expect(r.roundsReversed <= total && r.isFinished, "Runden \(r.roundsReversed)/\(total)")
            expectEqual(r.deck, hist.start[total - r.roundsReversed], "Orakel, \(cards) Karten, \(letters) Zeichen")
            expectEqual(try SolitaireAnalysis.keystream(initialDeck: r.deck, count: letters), trueKs)
            var probe = try SolitaireAnalysis.Reverser(endDeck: hist.end, letterCount: letters)
            probe.run()
            if probe.pending == nil { unique += 1; expectEqual(probe.deck, hist.start[total - probe.roundsReversed]) }
            if !r.decisions.isEmpty && r.decisions.allSatisfy({ $0.front }) {
                checkedFront += 1
                expectEqual(try SolitaireAnalysis.keystream(initialDeck: SolitaireAnalysis.initialDeck(endDeck: hist.end, letterCount: letters, strategy: .alwaysFront), count: letters), trueKs)
            }
            if !r.decisions.isEmpty && r.decisions.allSatisfy({ !$0.front }) {
                checkedBack += 1
                expectEqual(try SolitaireAnalysis.keystream(initialDeck: SolitaireAnalysis.initialDeck(endDeck: hist.end, letterCount: letters, strategy: .alwaysBack), count: letters), trueKs)
            }
        }
        expect(unique > 0 && checkedFront > 0 && checkedBack > 0, "Fälle abgedeckt: \(unique)/\(checkedFront)/\(checkedBack)")
        // 3-card deck (smallest CT1 deck) must not crash
        var tiny = try SolitaireAnalysis.Reverser(endDeck: [3, 1, 2], letterCount: 5)
        tiny.run(strategy: .alwaysBack)
        expect(tiny.isFinished)
    }

    group("CT1 Solitaire-Analyse: Deck-Notation") {
        let d = Array(1...54)
        expectEqual(SolitaireAnalysis.deckFileString(d).hasSuffix("52,A,B"), true)
        expectEqual(try SolitaireAnalysis.parseDeck(SolitaireAnalysis.deckFileString(d)), d)
        expectEqual(try SolitaireAnalysis.parseDeck("B, 1;2 A 3"), [5, 1, 2, 4, 3])
        expectEqual(try SolitaireAnalysis.parseDeck(SolitaireAnalysis.deckString(d.reversed())), Array(d.reversed()))
        expectThrows { _ = try SolitaireAnalysis.parseDeck("1,2,3,A") }
        expectThrows { _ = try SolitaireAnalysis.parseDeck("1,2,53,A,B") }
        expectThrows { _ = try SolitaireAnalysis.parseDeck("1,1,2") }
        expectThrows { _ = try SolitaireAnalysis.Reverser(endDeck: [1, 2], letterCount: 1) }
        expectEqual(SolitaireAnalysis.letters("Äb c-d"), [1, 5, 2, 3, 4])
    }
}
