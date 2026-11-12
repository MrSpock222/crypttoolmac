import Foundation
import CTCommon

// Vigenère-Analyse nach Schrödel (CT1 "Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸
// Ciphertext-Only ▸ Vigenère (Analyse nach Schrödel)", DlgVigenereAnalysisSchroedel.cpp).
//
// Tobias Schrödel's attack on *short* Vigenère ciphertexts whose key is a dictionary word
// ("Breaking Short Vigenère Ciphers", Cryptologia 32/4, 2008), ported step by step from CT1:
//
// 1. 1st ciphertext letter c: all 26 pairs (plaintext letter, key letter) with p + k = c; pairs that
//    are mirror images of an earlier pair are removed (plaintext and key are interchangeable).
// 2. 2nd letter: every pair is extended by the 26 possible letters, both halves are rated with the
//    digram statistics of the ciphertext language (missing digrams count 100 if they form a
//    two-letter word of the language); mirror images are removed, pairs with a rating < 10 are
//    discarded. 3rd letter: the same with trigram statistics (no mirror removal).
// 3. For every remaining pair the 4th letters of all dictionary words that begin with one of the two
//    halves are collected; combinations that encrypt to the 4th ciphertext letter select the
//    dictionary words (≤ ciphertext length) that are tried as key. Every decryption is a possible
//    result; it is rated by the longest dictionary word that begins with the decrypted text.
//
// The analysis works on the letters A–Z of the text only (independent of the text options), like
// CT1. All texts of the result log are the German CT1 strings.

/// Digram/trigram statistics of one language (one section of CT1's
/// `VigenereAnalysisSchroedelDigrams.txt` / `…Trigrams.txt`).
public struct SchroedelNGramSet: Sendable {
    /// The two-letter words of the language (line after the section header), e.g. "AM AN AS …".
    public let digramFactorString: String
    let factorBytes: [UInt8]
    /// Digram counts, index `a * 26 + b` (A = 0), in the line order of the file.
    public let digrams: [UInt32]
    /// Trigram counts, index `(a * 26 + b) * 26 + c`.
    public let trigrams: [UInt32]

    init(factor: [UInt8], digrams: [UInt32], trigrams: [UInt32]) {
        factorBytes = factor
        digramFactorString = String(decoding: factor, as: UTF8.self)
        self.digrams = digrams
        self.trigrams = trigrams
    }

    public func digram(_ a: Int, _ b: Int) -> Int { Int(digrams[a * 26 + b]) }
    public func trigram(_ a: Int, _ b: Int, _ c: Int) -> Int { Int(trigrams[(a * 26 + b) * 26 + c]) }
}

/// Dictionary words of one language (uppercased CP1252 bytes in file order) with lookup indices.
struct SchroedelWordList: Sendable {
    let words: [[UInt8]]
    /// First three bytes → indices (ascending) of the words with at least three bytes.
    let prefix3: [UInt32: [Int32]]
    /// Word indices sorted lexicographically by bytes (for prefix range queries).
    let sorted: [Int32]

    init(words: [[UInt8]]) {
        self.words = words
        var p: [UInt32: [Int32]] = [:]
        for (i, w) in words.enumerated() where w.count >= 3 {
            p[SchroedelWordList.code(w[0], w[1], w[2]), default: []].append(Int32(i))
        }
        prefix3 = p
        sorted = words.indices.map(Int32.init).sorted { a, b in
            let x = words[Int(a)], y = words[Int(b)]
            return x.lexicographicallyPrecedes(y) || (x == y && a < b)
        }
    }

    @inline(__always)
    static func code(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> UInt32 { UInt32(a) << 16 | UInt32(b) << 8 | UInt32(c) }

    /// Longest word beginning with `prefix` (ties: first in file order) → (length, index), nil if none.
    func longestWord(withPrefix prefix: [UInt8]) -> (length: Int, index: Int)? {
        var lo = 0, hi = sorted.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if words[Int(sorted[mid])].lexicographicallyPrecedes(prefix) { lo = mid + 1 } else { hi = mid }
        }
        var best: (length: Int, index: Int)? = nil
        var i = lo
        while i < sorted.count {
            let idx = Int(sorted[i])
            let w = words[idx]
            guard w.count >= prefix.count, w.starts(with: prefix) else { break }
            if best == nil || w.count > best!.length || (w.count == best!.length && idx < best!.index) {
                best = (w.count, idx)
            }
            i += 1
        }
        return best
    }
}

/// Parsed CT1 data files: dictionary, digrams and trigrams, each with `[LANGUAGE X]` sections.
public struct SchroedelLanguageData: Sendable {
    let dictionaries: [String: SchroedelWordList]
    /// Statistics per language (CT1: languages of the digram/trigram files).
    public let ngrams: [String: SchroedelNGramSet]

    /// Languages offered for the keywords (dictionary sections), sorted like CT1's list box.
    public var keywordLanguages: [String] { SchroedelLanguageData.sortedNames(dictionaries.keys) }
    /// Languages offered for the ciphertext (digram/trigram sections), sorted like CT1's list box.
    public var ciphertextLanguages: [String] { SchroedelLanguageData.sortedNames(ngrams.keys) }

    /// Number of dictionary words of a language (0 if unknown).
    public func wordCount(language: String) -> Int { dictionaries[language]?.words.count ?? 0 }

    static func sortedNames<S: Sequence>(_ s: S) -> [String] where S.Element == String {
        s.sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Parses the three files (contents as strings, e.g. the bundled UTF-8 copies or CT1's
    /// original CP1252 files decoded with `TextCoding`). Parsing follows CT1 exactly: after a
    /// `[LANGUAGE X]` line the digram file contains the factor-string line and 26 × 26 lines
    /// "XY;count", the trigram file 26³ lines "XYZ;count" (counts in line order). Dictionary words are
    /// trimmed and uppercased; empty lines are skipped.
    public static func parse(dictionary: String, digrams: String, trigrams: String) -> SchroedelLanguageData {
        // dictionary
        var words: [String: [[UInt8]]] = [:]
        var language: String? = nil
        for line in lines(of: dictionary) {
            if let l = languageName(line) { language = l; continue }
            guard let lang = language else { continue }
            let w = upperASCII(trim(line))
            guard !w.isEmpty else { continue }
            words[lang, default: []].append(w)
        }
        var dicts: [String: SchroedelWordList] = [:]
        for (lang, list) in words { dicts[lang] = SchroedelWordList(words: list) }

        // digrams / trigrams
        var factor: [String: [UInt8]] = [:]
        var di: [String: [UInt32]] = [:]
        var tri: [String: [UInt32]] = [:]
        let dl = lines(of: digrams)
        var i = 0
        while i < dl.count {
            if let lang = languageName(dl[i]) {
                i += 1
                factor[lang] = i < dl.count ? Array(dl[i]) : []
                i += 1
                var table = [UInt32](repeating: 0, count: 26 * 26)
                for k in 0..<(26 * 26) {
                    table[k] = i < dl.count ? count(dl[i]) : 0
                    i += 1
                }
                di[lang] = table
            } else {
                i += 1
            }
        }
        let tl = lines(of: trigrams)
        i = 0
        while i < tl.count {
            if let lang = languageName(tl[i]) {
                i += 1
                var table = [UInt32](repeating: 0, count: 26 * 26 * 26)
                for k in 0..<(26 * 26 * 26) {
                    table[k] = i < tl.count ? count(tl[i]) : 0
                    i += 1
                }
                tri[lang] = table
            } else {
                i += 1
            }
        }
        var sets: [String: SchroedelNGramSet] = [:]
        for lang in Set(di.keys).union(tri.keys) {
            sets[lang] = SchroedelNGramSet(factor: factor[lang] ?? [],
                                           digrams: di[lang] ?? [UInt32](repeating: 0, count: 26 * 26),
                                           trigrams: tri[lang] ?? [UInt32](repeating: 0, count: 26 * 26 * 26))
        }
        return SchroedelLanguageData(dictionaries: dicts, ngrams: sets)
    }

    // MARK: Parsing helpers (byte based like CT1's std::getline / CString)

    /// Lines as CP1252 bytes (CT1 read the files byte-wise), trailing CR removed.
    static func lines(of text: String) -> [ArraySlice<UInt8>] {
        let bytes = cp1252(text)
        var out: [ArraySlice<UInt8>] = []
        out.reserveCapacity(bytes.count / 8)
        var start = 0
        for (k, b) in bytes.enumerated() where b == 0x0A {
            var end = k
            if end > start && bytes[end - 1] == 0x0D { end -= 1 }
            out.append(bytes[start..<end])
            start = k + 1
        }
        if start < bytes.count {
            var end = bytes.count
            if bytes[end - 1] == 0x0D { end -= 1 }
            out.append(bytes[start..<end])
        }
        return out
    }

    static func cp1252(_ s: String) -> [UInt8] {
        if let d = s.data(using: .windowsCP1252, allowLossyConversion: true) { return [UInt8](d) }
        return Array(s.utf8)
    }

    /// "[LANGUAGE X]" anywhere in the line → "X" (CT1: substring from offset 10 up to "]").
    static func languageName(_ line: ArraySlice<UInt8>) -> String? {
        let tag = Array("[LANGUAGE ".utf8)
        let l = Array(line)
        guard l.count >= tag.count else { return nil }
        var found = false
        for s in 0...(l.count - tag.count) where Array(l[s..<(s + tag.count)]) == tag { found = true; break }
        guard found, l.count > 10 else { return found ? "" : nil }
        let end = l.firstIndex(of: UInt8(ascii: "]")) ?? l.count
        guard end > 10 else { return "" }
        return String(decoding: l[10..<end], as: UTF8.self)
    }

    static func trim(_ s: ArraySlice<UInt8>) -> ArraySlice<UInt8> {
        func ws(_ b: UInt8) -> Bool { b == 0x20 || (b >= 0x09 && b <= 0x0D) }
        var lo = s.startIndex, hi = s.endIndex
        while lo < hi && ws(s[lo]) { lo += 1 }
        while hi > lo && ws(s[hi - 1]) { hi -= 1 }
        return s[lo..<hi]
    }

    static func upperASCII(_ s: ArraySlice<UInt8>) -> [UInt8] {
        s.map { $0 >= 0x61 && $0 <= 0x7A ? $0 - 32 : $0 }
    }

    /// CT1: `s.Delete(0, s.Find(';') + 1); atoi(s)`.
    static func count(_ line: ArraySlice<UInt8>) -> UInt32 {
        var s = line
        if let semi = s.firstIndex(of: UInt8(ascii: ";")) { s = s[(semi + 1)...] }
        var i = s.startIndex
        while i < s.endIndex && (s[i] == 0x20 || (s[i] >= 0x09 && s[i] <= 0x0D)) { i += 1 }
        var negative = false
        if i < s.endIndex && (s[i] == UInt8(ascii: "-") || s[i] == UInt8(ascii: "+")) { negative = s[i] == UInt8(ascii: "-"); i += 1 }
        var v: Int64 = 0
        while i < s.endIndex && s[i] >= 0x30 && s[i] <= 0x39 {
            v = min(v * 10 + Int64(s[i] - 0x30), Int64(Int32.max))
            i += 1
        }
        let r = Int32(negative ? -v : v)
        return UInt32(bitPattern: r)
    }
}

/// A possible solution of the Schrödel analysis.
public struct VigenereSchroedelResult: Sendable, Identifiable, Equatable {
    /// The dictionary word used as key (uppercase).
    public let key: String
    /// The decrypted ciphertext (uppercase A–Z).
    public let cleartext: String
    /// Longest dictionary word (lowercase) that begins with the cleartext; empty if none.
    public let longestDictionaryMatch: String
    public var id: String { key }
}

/// Outcome of a run (also after cancellation, then with the log written so far).
public struct VigenereSchroedelReport: Sendable {
    /// false if the analysis was cancelled.
    public let completed: Bool
    /// The ciphertext as analysed (letters A–Z).
    public let ciphertext: String
    /// All possible results in CT1 order (longest dictionary match first, then longest key).
    public let results: [VigenereSchroedelResult]
    /// Results with a dictionary match in the order they were found (CT1 dialog list).
    public let listedResults: [VigenereSchroedelResult]
    /// The result log (CT1 `result`; with extensive logging it contains every step).
    public let log: String
    /// The complete log incl. all analysis steps (CT1 `resultDebug`).
    public let debugLog: String
    /// Seconds needed (CT1: whole seconds of the clock).
    public let seconds: Int

    /// CT1 `isSuccessful`: done and at least one possible result.
    public var isSuccessful: Bool { completed && !results.isEmpty }
    /// Text of the result document (CT1 shows the debug log if the regular log is empty, i.e.
    /// after a cancelled run).
    public var documentText: String { log.isEmpty ? debugLog : log }
}

public enum VigenereSchroedel {
    // German CT1 strings (string table of CrypTool 1.4.x)
    static let tagLoadingCiphertext = "Lade Geheimtext..."
    static let tagLoadingDictionary = "Lade Wörterbuch..."
    static let tagLoadingDigrams = "Lade Digramme..."
    static let tagLoadingTrigrams = "Lade Trigramme..."
    static let tagCharacter = ["1. Zeichen des Geheimtexts: ", "2. Zeichen des Geheimtexts: ", "3. Zeichen des Geheimtexts: "]
    static let tagPossiblePairs = "%d mögliche Paare:"
    static let tagRemoveDuplicates = "%d entfernte Duplikate:"
    static let tagRemaining = "Verbleibende Paare: "
    static let tagSortedAll = "Sortierte Liste aller Paare:"
    static let tagSortedAfterDiscarding = "Sortierte Liste aller verbliebenen Paare:"
    static let tagSortedLeaders = "Sortierte Liste der besten Paare:"
    static let tagCheckingRatings = "Mögliche Lösungen mit dem Wörterbuch abgleichen:"
    public static let headerTag = "CrypTool: Ciphertext-Only-Analyse nach Schrödel gegen die Vigenère-Verschlüsselung"
    static let timeNeededTag = "Benötigte Zeit für die Durchführung der Analyse: "
    static let unitSeconds = " Sekunden"
    static let ciphertextLengthTag = "Länge des analysierten Geheimtexts:"
    static let unitCharacters = "Zeichen"
    static let keywordLanguagesTag = "Sprache(n) für Schlüsselworte: "
    static let ciphertextLanguageTag = "Sprache für Geheimtext: "
    public static let ciphertextTag = "Geheimtext:"
    public static let possibleKeyTag = "Möglicher Schlüssel:"
    public static let foundCleartextTag = "Gefundener Klartext:"
    public static let noResultsMessage = "Die Analyse war nicht erfolgreich. Es wurden keine möglichen Lösungen gefunden."

    /// CT1 preprocessing: letters A–Z (lowercase converted), everything else removed.
    public static func preprocess(_ text: String) -> String {
        String(decoding: letters(text), as: UTF8.self)
    }

    static func letters(_ text: String) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(text.utf8.count)
        for b in text.utf8 {
            if b >= 0x41 && b <= 0x5A { out.append(b) } else if b >= 0x61 && b <= 0x7A { out.append(b - 32) }
        }
        return out
    }

    /// CT1 `decryptText`: Vigenère decryption with the key repeated to the text length; positions
    /// whose key character is not a letter A–Z are skipped.
    public static func decrypt(_ ciphertext: String, key: String) -> String {
        String(decoding: decryptBytes(letters(ciphertext), key: SchroedelLanguageData.cp1252(key.uppercased())), as: UTF8.self)
    }

    static func decryptBytes(_ text: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return [] }
        var out: [UInt8] = []
        out.reserveCapacity(text.count)
        for (i, c) in text.enumerated() {
            let k = key[i % key.count]
            guard k >= 0x41 && k <= 0x5A, c >= 0x41 && c <= 0x5A else { continue }
            out.append(UInt8((Int(c) - Int(k) + 26) % 26) + 0x41)
        }
        return out
    }

    /// CT1 `encryptChar` (0 if a character is not A–Z).
    @inline(__always)
    static func encryptChar(_ ch: UInt8, _ key: UInt8) -> UInt8 {
        guard ch >= 0x41 && ch <= 0x5A, key >= 0x41 && key <= 0x5A else { return 0 }
        return UInt8((Int(ch) - 0x41 + Int(key) - 0x41) % 26) + 0x41
    }

    private struct Pair {
        var text: [UInt8]
        var key: [UInt8]
        var s0: UInt32
        var s1: UInt32
        var product: UInt32 { s0 &* s1 }   // CT1: unsigned int product (wraps)
        var label: String { str(text) + "-" + str(key) }
    }

    private static let removed = UInt32.max   // CT1 stores -1 in an unsigned score

    @inline(__always)
    private static func str(_ b: [UInt8]) -> String { String(decoding: b, as: UTF8.self) }

    private static func cp1252String(_ b: [UInt8]) -> String {
        String(data: Data(b), encoding: .windowsCP1252) ?? String(decoding: b, as: UTF8.self)
    }

    /// Stable sort, descending by score product (CT1 bubble sort).
    private static func sortPairs(_ p: inout [Pair]) {
        p = p.enumerated().sorted { a, b in
            a.element.product != b.element.product ? a.element.product > b.element.product : a.offset < b.offset
        }.map(\.element)
    }

    /// Runs the analysis.
    /// - Parameters:
    ///   - keywordLanguages: dictionary languages used for the keywords (CT1: at least one).
    ///   - ciphertextLanguage: language of the plaintext (digram/trigram statistics).
    ///   - extensiveLogging: CT1 "Ausführliche Protokollierung" (Analyseoptionen): the result log
    ///     then contains all analysis steps.
    ///   - germanLocale: CT1 checks `GetThreadLocale() == 1031` (German Windows) and then rates
    ///     unseen digrams beginning with A or I with 20. German CT1 installations do this.
    ///   - found: called (on the analysis thread) for every new result with a dictionary match.
    /// - Throws: if the text contains fewer than three letters A–Z or a language is unknown.
    public static func analyze(ciphertext text: String, data: SchroedelLanguageData,
                               keywordLanguages: [String], ciphertextLanguage: String,
                               extensiveLogging: Bool = false, germanLocale: Bool = true,
                               cancel: CancellationToken? = nil, progress: ProgressHandler? = nil,
                               found: (@Sendable (VigenereSchroedelResult) -> Void)? = nil) throws -> VigenereSchroedelReport {
        let selected = SchroedelLanguageData.sortedNames(keywordLanguages.filter { data.dictionaries[$0] != nil })
        guard !selected.isEmpty, let ngram = data.ngrams[ciphertextLanguage] else {
            throw CTError("Bitte wählen Sie MINDESTENS EINE Schlüsselwort-Sprache und GENAU EINE Geheimtext-Sprache aus.")
        }
        let ct = letters(text)
        guard ct.count >= 3 else {
            throw CTError("Der Geheimtext muss mindestens drei Buchstaben (A–Z) enthalten.")
        }
        let lists = selected.map { data.dictionaries[$0]! }
        var offsets: [Int] = []
        var dictCount = 0
        for l in lists { offsets.append(dictCount); dictCount += l.words.count }

        var result = ""
        var debug = ""
        func output(_ s: String, _ force: Bool = false) {
            if force || extensiveLogging { result += s + "\n" }
            debug += s + "\n"
        }
        func cancelled() -> Bool { cancel?.isCancelled == true }
        let listed = ListedBox()
        func aborted() -> VigenereSchroedelReport {
            VigenereSchroedelReport(completed: false, ciphertext: str(ct), results: [], listedResults: listed.value,
                                    log: result, debugLog: debug, seconds: 0)
        }

        output(tagLoadingCiphertext)
        output(tagLoadingDictionary)
        output(tagLoadingDigrams)
        output(tagLoadingTrigrams)
        progress?(0.10)
        let start = Date()

        // MARK: 1st character
        let c0 = Int(ct[0]) - 0x41
        var pairs: [Pair] = []
        var line = ""
        for i in 0..<26 {
            let p = Pair(text: [UInt8(0x41 + i)], key: [UInt8(0x41 + (c0 - i + 26) % 26)], s0: 0, s1: 0)
            line += p.label + " "
            pairs.append(p)
        }
        output("")
        output(tagCharacter[0] + str([ct[0]]))
        output(String(format: tagPossiblePairs, pairs.count))
        output(line)
        var remain = pairs.count
        for l in 0..<max(0, pairs.count - 1) {
            for o in (l + 1)..<pairs.count where pairs[l].text == pairs[o].key {
                pairs[o].s0 = removed; pairs[o].s1 = removed
                remain -= 1
            }
        }
        line = ""
        var removedCount = 0
        for p in pairs where p.s0 == removed { removedCount += 1; line += p.label + " " }
        output(String(format: tagRemoveDuplicates, removedCount))
        output(line)
        output(tagRemaining + "\(remain)")
        pairs = Array(pairs.filter { $0.s1 != removed }.prefix(max(0, remain)))
        progress?(0.12)

        // MARK: 2nd and 3rd character
        for n in 1...2 {
            if cancelled() { return aborted() }
            let c = Int(ct[n]) - 0x41
            output("")
            output(tagCharacter[n] + str([ct[n]]))
            var next: [Pair] = []
            next.reserveCapacity(pairs.count * 26)
            var temp = ""
            for p in pairs {
                for o in 0..<26 {
                    let fText = UInt8(0x41 + o), fKey = UInt8(0x41 + (c - o + 26) % 26)
                    var t: UInt32, k: UInt32
                    if n == 1 {
                        let st = p.text[0], sk = p.key[0]
                        t = ngram.digrams[Int(st - 0x41) * 26 + o]
                        k = ngram.digrams[Int(sk - 0x41) * 26 + Int(fKey - 0x41)]
                        if t == 0 {
                            if germanLocale && (st == 0x41 || st == 0x49) { t = 20 }
                            if contains(ngram.factorBytes, [st, fText]) { t = 100 }
                        }
                        if k == 0 {
                            if germanLocale && (sk == 0x41 || sk == 0x49) { k = 20 }
                            if contains(ngram.factorBytes, [sk, fKey]) { k = 100 }
                        }
                    } else {
                        let st = p.text, sk = p.key
                        t = ngram.trigrams[(Int(st[0] - 0x41) * 26 + Int(st[1] - 0x41)) * 26 + o]
                        k = ngram.trigrams[(Int(sk[0] - 0x41) * 26 + Int(sk[1] - 0x41)) * 26 + Int(fKey - 0x41)]
                        // CT1 adds two chars here (char + char = int), so these look-ups search
                        // a single (non-ASCII) byte in the factor string – reproduced as is.
                        if t == 0 {
                            if germanLocale && (st[0] == 0x41 || st[0] == 0x49) &&
                                ngram.factorBytes.contains(UInt8(truncatingIfNeeded: Int(st[1]) + Int(fText))) { t = 100 }
                            if ngram.factorBytes.contains(UInt8(truncatingIfNeeded: Int(sk[1]) + Int(fKey))) { k = 100 }
                        }
                        if k == 0 {
                            if germanLocale && (sk[0] == 0x41 || sk[0] == 0x49) &&
                                ngram.factorBytes.contains(UInt8(truncatingIfNeeded: Int(sk[1]) + Int(fKey))) { k = 100 }
                        }
                    }
                    let q = Pair(text: p.text + [fText], key: p.key + [fKey], s0: t, s1: k)
                    temp += q.label + " "
                    next.append(q)
                }
            }
            pairs = next
            output(String(format: tagPossiblePairs, pairs.count))
            output(temp)

            if n == 1 {
                // remove mirror images
                var marked = [Bool](repeating: false, count: pairs.count)
                if pairs.count > 1 {
                    // pairs[l].text == pairs[o].key for some l < o
                    var firstByText: [[UInt8]: Int] = [:]
                    for (i, p) in pairs.enumerated() where firstByText[p.text] == nil { firstByText[p.text] = i }
                    for o in 0..<pairs.count {
                        if let l = firstByText[pairs[o].key], l < o { marked[o] = true }
                    }
                }
                line = ""
                removedCount = 0
                for (i, p) in pairs.enumerated() where marked[i] { removedCount += 1; line += p.label + " " }
                output(String(format: tagRemoveDuplicates, removedCount))
                output(line)
                output(tagRemaining + "\(pairs.count - removedCount)")
                pairs = pairs.enumerated().filter { !marked[$0.offset] }.map(\.element)
            }

            sortPairs(&pairs)
            output("")
            output(tagSortedAll)
            for p in pairs { output(p.label + "/\(Int32(bitPattern: p.s0))-\(Int32(bitPattern: p.s1)) ") }

            // discard underperformers
            pairs = pairs.filter { $0.s0 >= 10 && $0.s1 >= 10 }
            sortPairs(&pairs)
            output("")
            output(tagSortedAfterDiscarding)
            for p in pairs { output(p.label + "/\(Int32(bitPattern: p.s0))-\(Int32(bitPattern: p.s1)) ") }
            output("")
            output(tagSortedLeaders)
            line = ""
            for (i, p) in pairs.enumerated() { line += "\(i + 1). " + p.label + " " }
            output(line)
            output(tagRemaining + "\(pairs.count)")
        }
        output("")
        progress?(0.15)

        // MARK: solve trigrams with the dictionary
        func word(_ global: Int) -> [UInt8] {
            var li = lists.count - 1
            while offsets[li] > global { li -= 1 }
            return lists[li].words[global - offsets[li]]
        }
        /// Global indices (ascending) of the words beginning with the 3-byte prefix.
        func withPrefix(_ p: [UInt8]) -> [Int] {
            let code = SchroedelWordList.code(p[0], p[1], p[2])
            var out: [Int] = []
            for (li, l) in lists.enumerated() {
                if let idx = l.prefix3[code] { out.append(contentsOf: idx.map { Int($0) + offsets[li] }) }
            }
            return out
        }
        var matchCache: [[UInt8]: String] = [:]
        func longestMatch(_ plain: [UInt8]) -> String {
            if let m = matchCache[plain] { return m }
            var best: (length: Int, index: Int)? = nil
            for (li, l) in lists.enumerated() {
                if let b = l.longestWord(withPrefix: plain) {
                    let g = b.index + offsets[li]
                    if best == nil || b.length > best!.length { best = (b.length, g) }
                }
            }
            let m = best.map { cp1252String(word($0.index).map { $0 >= 0x41 && $0 <= 0x5A ? $0 + 32 : $0 }) } ?? ""
            matchCache[plain] = m
            return m
        }

        var possible: [[UInt8]: VigenereSchroedelResult] = [:]
        let c3: UInt8 = ct.count > 3 ? ct[3] : 0
        for (pi, p) in pairs.enumerated() {
            if cancelled() { return aborted() }
            let keyPrefix = p.text, textPrefix = p.key   // CT1 naming: key = pairs[i][0], text = pairs[i][1]
            let keyWords = withPrefix(keyPrefix), textWords = withPrefix(textPrefix)
            var cKey: [UInt8] = [], cText: [UInt8] = []
            for g in keyWords { let w = word(g); if w.count > 3 && !cKey.contains(w[3]) { cKey.append(w[3]) } }
            for g in textWords { let w = word(g); if w.count > 3 && !cText.contains(w[3]) { cText.append(w[3]) } }
            if !cKey.isEmpty && !cText.isEmpty {
                for ko in cKey {
                    for tl in cText where encryptChar(tl, ko) == c3 {
                        if cancelled() { return aborted() }
                        // words (≤ ciphertext length) beginning with key+ko or text+tl, dictionary order
                        var a = 0, b = 0
                        while a < keyWords.count || b < textWords.count {
                            let g: Int
                            if b >= textWords.count || (a < keyWords.count && keyWords[a] <= textWords[b]) {
                                g = keyWords[a]
                                if b < textWords.count && textWords[b] == g { b += 1 }
                                a += 1
                            } else {
                                g = textWords[b]; b += 1
                            }
                            let w = word(g)
                            guard w.count <= ct.count, w.count >= 4 else { continue }
                            let viaKey = w[0] == keyPrefix[0] && w[1] == keyPrefix[1] && w[2] == keyPrefix[2] && w[3] == ko
                            let viaText = w[0] == textPrefix[0] && w[1] == textPrefix[1] && w[2] == textPrefix[2] && w[3] == tl
                            guard viaKey || viaText, possible[w] == nil else { continue }
                            let plain = decryptBytes(ct, key: w)
                            let r = VigenereSchroedelResult(key: cp1252String(w), cleartext: str(plain),
                                                            longestDictionaryMatch: longestMatch(plain))
                            possible[w] = r
                            if !r.longestDictionaryMatch.isEmpty {
                                listed.append(r)
                                found?(r)
                            }
                        }
                    }
                }
            }
            progress?(0.15 + 0.75 * Double(pi + 1) / Double(max(pairs.count, 1)))
        }

        let byKey = possible.sorted { $0.key.lexicographicallyPrecedes($1.key) }.map(\.value)
        output("")
        output(tagCheckingRatings)
        for r in byKey {
            output(r.longestDictionaryMatch.isEmpty ? "\(r.key)/\(r.cleartext)" : "\(r.key)/\(r.cleartext) [\(r.longestDictionaryMatch)]")
        }
        output("")

        let seconds = Int(floor(Date().timeIntervalSince1970) - floor(start.timeIntervalSince1970))
        output(headerTag, true)
        output(timeNeededTag + "\(seconds)" + unitSeconds, true)
        output("\(ciphertextLengthTag) \(ct.count) \(unitCharacters)", true)
        // CT1 prints the ciphertext language here (bug); the keyword languages are shown instead.
        output(keywordLanguagesTag + selected.joined(separator: ", "), true)
        output(ciphertextLanguageTag + ciphertextLanguage, true)
        output("", true)
        output(ciphertextTag, true)
        output(str(ct), true)
        output("", true)

        // CT1 list::sort (stable): longest dictionary match first, then longest key
        let sorted = byKey.enumerated().sorted { a, b in
            let x = a.element, y = b.element
            if x.longestDictionaryMatch.count != y.longestDictionaryMatch.count {
                return x.longestDictionaryMatch.count > y.longestDictionaryMatch.count
            }
            if x.key.utf8.count != y.key.utf8.count { return x.key.utf8.count > y.key.utf8.count }
            return a.offset < b.offset
        }.map(\.element)

        if sorted.isEmpty {
            output(noResultsMessage, true)
        } else if sorted.count == 1 {
            output(possibleKeyTag, true)
            output(sorted[0].key, true)
            output("", true)
            output(foundCleartextTag, true)
            output(sorted[0].cleartext, true)
            output("", true)
        } else {
            for (i, r) in sorted.enumerated() {
                output("\(i + 1). " + possibleKeyTag, true)
                output(r.key, true)
                output(foundCleartextTag, true)
                output(r.cleartext, true)
                output("", true)
            }
        }
        progress?(1)
        return VigenereSchroedelReport(completed: true, ciphertext: str(ct), results: sorted, listedResults: listed.value,
                                       log: result, debugLog: debug, seconds: seconds)
    }

    private static func contains(_ hay: [UInt8], _ needle: [UInt8]) -> Bool {
        guard needle.count <= hay.count else { return false }
        if needle.isEmpty { return true }
        for s in 0...(hay.count - needle.count) {
            var ok = true
            for j in 0..<needle.count where hay[s + j] != needle[j] { ok = false; break }
            if ok { return true }
        }
        return false
    }

    private final class ListedBox: @unchecked Sendable {
        var value: [VigenereSchroedelResult] = []
        func append(_ r: VigenereSchroedelResult) { value.append(r) }
    }
}
