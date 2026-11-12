import Foundation
import CTCommon
import CTAnalysis

/// Vigenère-Analyse nach Schrödel (CT1 DlgVigenereAnalysisSchroedel) – called from main.swift.
func runCT1SchroedelTests() {
    section("CT1 Vigenère-Analyse nach Schrödel")

    func word(_ name: String) -> String {
        let url = repoRoot.appendingPathComponent("Resources/Words/\(name)")
        guard let s = try? String(contentsOf: url, encoding: .utf8) else {
            check(false, "cannot read \(url.path)")
            return ""
        }
        return s
    }
    func vigenere(_ plain: String, _ key: String) -> String {
        let p = Array(plain.utf8), k = Array(key.utf8)
        return String(decoding: p.enumerated().map { i, c in UInt8((Int(c) - 65 + Int(k[i % k.count]) - 65) % 26 + 65) }, as: UTF8.self)
    }

    let (data, parseTime) = timed {
        SchroedelLanguageData.parse(dictionary: word("VigenereAnalysisSchroedelDictionary.txt"),
                                    digrams: word("VigenereAnalysisSchroedelDigrams.txt"),
                                    trigrams: word("VigenereAnalysisSchroedelTrigrams.txt"))
    }
    print(String(format: "  parse: %.2f s", parseTime))
    check(data.keywordLanguages == ["English", "German"], "dictionary languages \(data.keywordLanguages)")
    check(data.ciphertextLanguages == ["English", "German"], "n-gram languages \(data.ciphertextLanguages)")
    check(data.wordCount(language: "English") == 81537, "English words \(data.wordCount(language: "English"))")
    check(data.wordCount(language: "German") == 160086, "German words \(data.wordCount(language: "German"))")
    if let en = data.ngrams["English"], let de = data.ngrams["German"] {
        check(en.digramFactorString.hasPrefix("AM AN AS AT BE BY DO"), "English factor string '\(en.digramFactorString)'")
        check(de.digramFactorString == "AB AM AN DA DU EI ER ES HA IM IN JA NA NE OB OK SO UM WO ZU", "German factor string '\(de.digramFactorString)'")
        check(en.digram(0, 0) == 3 && en.digram(0, 1) == 2063 && en.digram(0, 2) == 2698, "English digrams AA/AB/AC")
        check(de.digram(0, 0) == 175, "German digram AA")
        check(en.trigram(0, 0, 0) == 0 && en.trigrams.count == 17576 && de.trigrams.count == 17576, "trigram tables")
        check(de.trigrams.reduce(0, +) > 0 && de.trigrams.max()! == 8794, "German trigram maximum \(de.trigrams.max()!)")
        check(en.digrams.max()! <= 89259 && de.digrams.max()! <= 89259, "digram maximum")
    } else {
        check(false, "n-gram sets missing")
    }
    check(VigenereSchroedel.preprocess("Ab c-ä D1e") == "ABCDE", "preprocessing to A–Z")
    check(VigenereSchroedel.decrypt(vigenere("CRYPTOGRAPHY", "SECRET"), key: "secret") == "CRYPTOGRAPHY", "decrypt helper")
    check(VigenereSchroedel.decrypt("ABCD", key: "B-") == "ZB", "key positions with non-letters are skipped (CT1)")

    // Short ciphertexts (Schrödel's use case): plaintext and key are dictionary words.
    let cases: [(plain: String, key: String, lang: String)] = [
        ("CRYPTOGRAPHY", "SECRET", "English"),
        ("MATHEMATICS", "COMPUTER", "English"),
        ("HAUPTBAHNHOF", "SCHLUESSEL", "German"),
        ("BUNDESREGIERUNG", "HAUPTBAHNHOF", "German"),
    ]
    for c in cases {
        let ct = vigenere(c.plain, c.key)
        let found = FoundBox()
        let (r, t) = timed {
            try? VigenereSchroedel.analyze(ciphertext: ct.lowercased(), data: data, keywordLanguages: data.keywordLanguages,
                                          ciphertextLanguage: c.lang, found: { found.add($0) })
        }
        guard let r else { check(false, "\(c.plain): analysis threw"); continue }
        print(String(format: "  %@ / %@: %d results, %d listed, %.2f s", c.plain, c.key, r.results.count, r.listedResults.count, t))
        check(r.completed && r.isSuccessful, "\(c.plain): completed")
        let hit = r.results.first { $0.key == c.key }
        check(hit?.cleartext == c.plain, "\(c.plain): key \(c.key) found (\(hit?.cleartext ?? "–"))")
        check(hit.map { !$0.longestDictionaryMatch.isEmpty && $0.longestDictionaryMatch.hasPrefix(c.plain.lowercased()) } == true,
              "\(c.plain): dictionary match \(hit?.longestDictionaryMatch ?? "–")")
        check(r.listedResults.contains { $0.key == c.key } && found.items.map(\.key) == r.listedResults.map(\.key),
              "\(c.plain): listed in dialog order")
        // CT1 ordering: dictionary match length desc, key length desc
        let ordered = zip(r.results, r.results.dropFirst()).allSatisfy { a, b in
            a.longestDictionaryMatch.count > b.longestDictionaryMatch.count ||
            (a.longestDictionaryMatch.count == b.longestDictionaryMatch.count && a.key.count >= b.key.count)
        }
        check(ordered, "\(c.plain): result order")
        check(r.results.first.map { !$0.longestDictionaryMatch.isEmpty } == true, "\(c.plain): best result has a match")
        check(r.log.hasPrefix(VigenereSchroedel.headerTag + "\nBenötigte Zeit für die Durchführung der Analyse: "), "\(c.plain): log header")
        check(r.log.contains("Länge des analysierten Geheimtexts: \(c.plain.count) Zeichen\n"), "\(c.plain): log length")
        check(r.log.contains("Sprache für Geheimtext: \(c.lang)\n\nGeheimtext:\n\(ct)\n\n"), "\(c.plain): log ciphertext")
        check(r.log.contains("Möglicher Schlüssel:\n\(c.key)\nGefundener Klartext:\n\(c.plain)\n"), "\(c.plain): log result entry")
        check(r.debugLog.hasPrefix("Lade Geheimtext...\nLade Wörterbuch...\nLade Digramme...\nLade Trigramme...\n\n1. Zeichen des Geheimtexts: \(ct.first!)\n26 mögliche Paare:\n"),
              "\(c.plain): debug log start")
        check(r.debugLog.contains("Mögliche Lösungen mit dem Wörterbuch abgleichen:") && !r.log.contains("Sortierte Liste"), "\(c.plain): debug vs. standard log")
    }

    // first step: pairs for "A": A-A B-Z … ; mirror images removed → 14 pairs (2·p ≡ 0 has two solutions)
    if let r = try? VigenereSchroedel.analyze(ciphertext: "AAAA", data: data, keywordLanguages: ["English"], ciphertextLanguage: "English") {
        check(r.debugLog.contains("26 mögliche Paare:\nA-A B-Z C-Y D-X E-W F-V G-U H-T I-S J-R K-Q L-P M-O N-N O-M P-L "), "pairs of the first letter")
        check(r.debugLog.contains("12 entfernte Duplikate:\nO-M P-L Q-K R-J S-I T-H U-G V-F W-E X-D Y-C Z-B \nVerbleibende Paare: 14\n"), "mirror pairs removed")
        check(r.completed, "short text completes")
    } else {
        check(false, "AAAA analysis threw")
    }
    // extensive logging puts every step into the result log; cancellation keeps the partial log
    if let r = try? VigenereSchroedel.analyze(ciphertext: vigenere("SECRET", "KEY"), data: data, keywordLanguages: ["English"],
                                              ciphertextLanguage: "English", extensiveLogging: true) {
        check(r.log == r.debugLog && r.log.contains("Sortierte Liste der besten Paare:"), "extensive logging")
    }
    let token = CancellationToken()
    token.cancel()
    if let r = try? VigenereSchroedel.analyze(ciphertext: "QWERTZUIOP", data: data, keywordLanguages: ["German"], ciphertextLanguage: "German", cancel: token) {
        check(!r.completed && !r.isSuccessful && r.log.isEmpty && r.documentText == r.debugLog, "cancelled run")
    }
    var threw = false
    do { _ = try VigenereSchroedel.analyze(ciphertext: "ab", data: data, keywordLanguages: ["English"], ciphertextLanguage: "English") } catch { threw = true }
    check(threw, "fewer than three letters")
    threw = false
    do { _ = try VigenereSchroedel.analyze(ciphertext: "abcdef", data: data, keywordLanguages: [], ciphertextLanguage: "English") } catch { threw = true }
    check(threw, "no keyword language")
}

private final class FoundBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var items: [VigenereSchroedelResult] = []
    func add(_ r: VigenereSchroedelResult) { lock.lock(); items.append(r); lock.unlock() }
}
