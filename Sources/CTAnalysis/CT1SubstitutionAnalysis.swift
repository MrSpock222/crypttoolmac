import Foundation
import CTCommon

// Ports of CT1's analyses of the monoalphabetic substitution ("Analyse ▸ Symmetrische Verschlüsselung
// (klassisch) ▸ Ciphertext-Only ▸ Substitution" and "… ▸ Manuelle Analyse ▸ Substitution"):
//
// * `CT1SubstJakobsen` – "Verfahren 1" (MonoSubstCracker.cpp): Thomas Jakobsen's fast method with
//   CT1's digram distribution matrix, initial key from the single letter ranking and CT1's language
//   detection (index of coincidence).
// * `CT1SubstHart` – "Verfahren 2" (Cryptography.cpp, AnaSubst): George W. Hart's word pattern search
//   with the CT1 word lists (SubstitutionAnalysisMethod2-de/en.txt) incl. the options "'e' als
//   häufigstes Zeichen annehmen" and "erweiterte Analyse (deutscher Klartext)".
// * `CT1SubstText` – the text handling of CT1's manual analysis dialog (DlgManualSubstAnalysis.cpp):
//   preview text, result text, key strings.
//
// Like CT1 all three work on the fixed alphabet A–Z (Verfahren 1 optionally with the space as 27th
// symbol), independent of the text options.

/// Language assumed/recognised by the CT1 substitution analyses.
public enum CT1SubstLanguage: String, Sendable, CaseIterable {
    case german, english
    /// CT1 strings IDS_MONO_SUBST_AUTO_LANG_DE / _EN.
    public var displayName: String { self == .german ? "German" : "English" }
}

// MARK: - Text handling of the manual analysis dialog

public enum CT1SubstText {
    /// Symbol value of the space in `symbols(_:convertUmlauts:)`.
    public static let space: Int8 = 26
    public static let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    @inline(__always) static func code(_ v: UInt32) -> Int8? {
        if v >= 65 && v <= 90 { return Int8(v - 65) }
        if v >= 97 && v <= 122 { return Int8(v - 97) }
        return nil
    }

    static func transcription(_ s: Unicode.Scalar) -> String? {
        switch s {
        case "ü": return "ue"
        case "Ü": return "Ue"
        case "ö": return "oe"
        case "Ö": return "Oe"
        case "ä": return "ae"
        case "Ä": return "Ae"
        case "ß": return "ss"
        default: return nil
        }
    }

    /// CT1 replaces umlauts and ß before the analysis (ä → ae, Ü → Ue, ß → ss).
    public static func transcribed(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            if let t = transcription(s) { out.append(contentsOf: t.unicodeScalars) } else { out.append(s) }
        }
        return String(out)
    }

    /// CT1 `SymbolArray(AlphaSpaceConv)`: letters A–Z (case-insensitive) → 0…25, space → 26, all
    /// other characters are dropped. With `convertUmlauts` (CT1 analysis entry points) umlauts are
    /// transcribed first and every line break counts as a space; without it (manual post-processing
    /// after "Verfahren 1") the document is read as it is.
    public static func symbols(_ text: String, convertUmlauts: Bool) -> [Int8] {
        let source = convertUmlauts ? transcribed(text) : text
        var out: [Int8] = []
        out.reserveCapacity(source.utf8.count)
        for s in source.unicodeScalars {
            if s.value == 32 || (convertUmlauts && s.value == 10) { out.append(space) } else if let c = code(s.value) { out.append(c) }
        }
        return out
    }

    /// Preview of the manual analysis dialog ("Aktueller Zwischenstand"): plaintext letters (known
    /// assignment) upper case, still unknown ciphertext letters lower case, spaces kept; at most
    /// `limit` symbols (CT1: 5000). `mapping[c]` = plaintext index for ciphertext index `c` or −1.
    public static func display(_ symbols: [Int8], mapping: [Int], limit: Int = 5000) -> String {
        var out = String()
        out.reserveCapacity(min(symbols.count, limit))
        for s in symbols.prefix(limit) {
            if s == space { out.append(" "); continue }
            let p = Int(s) < mapping.count ? mapping[Int(s)] : -1
            out.append(p >= 0 && p < 26 ? letters[p] : Character(Unicode.Scalar(UInt8(97 + Int(s)))))
        }
        return out
    }

    /// Result document of the manual analysis ("Aktuellen Zwischenstand ausgeben"): every letter is
    /// replaced by its plaintext letter (upper case) or, if unknown, by the ciphertext letter in lower
    /// case; afterwards CT1 (`ForceReformat`) restores the layout of the (transcribed) document and
    /// lower-cases letters that were lower case in the document. All other characters are kept.
    public static func output(_ text: String, mapping: [Int], convertUmlauts: Bool) -> String {
        let reference = convertUmlauts ? transcribed(text) : text
        var result: [Unicode.Scalar] = []
        for s in symbols(text, convertUmlauts: convertUmlauts) where s != space {
            let p = Int(s) < mapping.count ? mapping[Int(s)] : -1
            result.append(Unicode.Scalar(UInt8(p >= 0 && p < 26 ? 65 + p : 97 + Int(s))))
        }
        var out = String.UnicodeScalarView()
        var p = 0
        for s in reference.unicodeScalars {
            if p < result.count, code(s.value) != nil {
                let r = result[p]
                if s.value >= 97 && s.value <= 122, r.value >= 65 && r.value <= 90 {
                    out.append(Unicode.Scalar(r.value + 32)!)
                } else {
                    out.append(r)
                }
                p += 1
            } else {
                out.append(s)
            }
        }
        if p < result.count { out.append(contentsOf: result[p...]) }
        return String(out)
    }

    /// Key shown in the title of the result ("Substitutionsanalyse von <…>, Schlüssel: <…>"):
    /// for every plaintext letter A…Z the ciphertext letter, `*` if unknown.
    public static func titleKey(_ mapping: [Int]) -> String {
        var key = [Character](repeating: "*", count: 26)
        for (c, p) in mapping.enumerated() where c < 26 && p >= 0 && p < 26 { key[p] = letters[c] }
        return String(key)
    }

    /// Inverse of `titleKey`: decryption mapping from a title key (`*` = unknown).
    public static func mapping(fromTitleKey key: String) -> [Int] {
        var m = [Int](repeating: -1, count: 26)
        for (p, ch) in key.uppercased().prefix(26).enumerated() {
            if let v = ch.asciiValue, v >= 65 && v <= 90 { m[Int(v) - 65] = p }
        }
        return m
    }

    /// CT1 "Schlüssel kopieren" (manual dialog): for every ciphertext letter A…Z the assigned
    /// plaintext letter; unassigned positions are filled with the unused letters in alphabetical
    /// order (decryption alphabet).
    public static func copyKey(_ mapping: [Int]) -> String {
        var key = [Character?](repeating: nil, count: 26)
        var unused = letters
        for c in 0..<26 {
            let p = c < mapping.count ? mapping[c] : -1
            if p >= 0 && p < 26 {
                key[c] = letters[p]
                unused.removeAll { $0 == letters[p] }
            }
        }
        for c in 0..<26 where key[c] == nil && !unused.isEmpty { key[c] = unused.removeFirst() }
        return String(key.map { $0 ?? "*" })
    }

    /// Converts a decryption alphabet (plaintext letter per ciphertext letter A…Z) into the
    /// encryption alphabet (ciphertext letter per plaintext letter), as used by the substitution
    /// dialog.
    public static func invertAlphabet(_ key: String) -> String {
        var out = [Character](repeating: "*", count: 26)
        for (c, ch) in key.uppercased().prefix(26).enumerated() {
            if let v = ch.asciiValue, v >= 65 && v <= 90 { out[Int(v) - 65] = letters[c] }
        }
        return String(out)
    }
}

// MARK: - Verfahren 1: Jakobsen (digram frequencies)

/// CT1 "Verfahren 1 basierend auf der Häufigkeitsanalyse der Digramme im Text"
/// (MonoSubstCracker.cpp, after T. Jakobsen, Cryptologia 19:3, 1995).
///
/// * Letters A–Z, with `spaceInAlphabet` also the space ("Das Leerzeichen wurde substituiert") as
///   27th symbol. Case is ignored for the statistics but kept in the output, all other characters
///   are copied.
/// * Reference: digram distribution of the reference text (Optionen ▸ Textoptionen); umlauts count as
///   in CT1 ("Ü" adds the digrams UE and EU, "ß" adds SS twice).
/// * Initial key: ciphertext letters ranked by frequency are assigned to the language's frequency
///   ranking (EN "etasionrlchudmpfgybwvkxqjz", DE "enisratdhulcgmowbfkzpvjyxq"); the language is
///   guessed from the index of coincidence (≤ 0,07 → Englisch).
/// * Search: CT1 swaps the key letters of plaintext positions (i, i+d), d = 1, 2, …; a swap is kept
///   if the summed absolute deviation between the digram matrices decreases, and the search restarts
///   with d = 1. The digram matrix is updated incrementally exactly like CT1 (including CT1's
///   handling of the 2×2 block of the exchanged rows/columns), so the results match CT1.
public struct CT1SubstJakobsen: Sendable {
    public let spaceInAlphabet: Bool
    public var size: Int { spaceInAlphabet ? 27 : 26 }

    public init(spaceInAlphabet: Bool) { self.spaceInAlphabet = spaceInAlphabet }

    /// Result: `key[p]` = ciphertext symbol for plaintext symbol `p` (0…25, 26 = space) – CT1's
    /// "Aktuelle Substitution (Schlüssel)".
    public struct Result: Sendable {
        public var key: [Int]
        public var error: Float
        public var improvements: Int
        public var cancelled: Bool
    }

    // MARK: Text preparation

    /// CT1: number of valid characters ("Anzahl der validen Zeichen im Text").
    public func validCharacterCount(_ text: String) -> Int {
        var n = 0
        for s in text.unicodeScalars where CT1SubstText.code(s.value) != nil || (spaceInAlphabet && s.value == 32) { n += 1 }
        return n
    }

    /// CT1 replaces the space by '[' (symbol 26) and an original '[' by BEL before the analysis.
    func prepared(_ text: String) -> [UInt32] {
        var out: [UInt32] = []
        out.reserveCapacity(text.utf8.count)
        for s in text.unicodeScalars {
            var v = s.value
            if spaceInAlphabet {
                if v == 91 { v = 7 } else if v == 32 { v = 91 }
            }
            out.append(v)
        }
        return out
    }

    @inline(__always) func symbol(_ v: UInt32) -> Int? {
        if v >= 65 && v <= 90 { return Int(v - 65) }
        if v >= 97 && v <= 122 { return Int(v - 97) }
        if spaceInAlphabet && v == 91 { return 26 }
        return nil
    }

    /// CT1 language detection (index of coincidence, Friedman): ≤ 0,07 → English, otherwise German.
    public func guessLanguage(_ text: String) -> CT1SubstLanguage {
        let n = size
        var stat = [Float](repeating: 0, count: n)
        var count = 0
        for s in text.unicodeScalars {
            let v = s.value
            if let c = CT1SubstText.code(v) {
                stat[Int(c)] += 1; count += 1
            } else if spaceInAlphabet && (v == 32 || (v >= 9 && v <= 12)) {
                stat[26] += 1; count += 1
            }
        }
        guard count > 1 else { return .english }
        if !spaceInAlphabet {
            for i in 0..<n { stat[i] /= Float(count) }
        } else {
            // the most frequent symbol is assumed to be the space and removed
            var maxV: Float = 0, index = 0
            for i in 0..<n {
                if stat[i] > maxV { maxV = stat[i]; index = i }
                stat[i] /= Float(count - 1)
            }
            var i = index
            while i < n - 1 { stat[i] = stat[i + 1]; i += 1 }
        }
        var ic: Float = 0
        for i in 0..<26 { ic += stat[i] * (Float(count) * stat[i] - 1) / Float(count - 1) }
        return ic <= 0.07 ? .english : .german
    }

    /// Letters sorted by frequency (CT1 `getSortedLetters`); '[' stands for the space.
    public func sortedLetters(_ language: CT1SubstLanguage) -> [Int] {
        let s = language == .english ? "etasionrlchudmpfgybwvkxqjz" : "enisratdhulcgmowbfkzpvjyxq"
        let letters = s.unicodeScalars.map { Int($0.value) - 97 }
        return spaceInAlphabet ? [26] + letters : letters
    }

    // MARK: Statistics

    /// Digram distribution of the reference text (CT1 `initializeStandardDMatrix`).
    public func referenceMatrix(_ reference: String) -> [Float] {
        let n = size
        var stat = [Int](repeating: 0, count: n * n)
        var count = 0
        var last: Int = -1   // symbol of the last character (−1 = no letter)
        func add(_ a: Int, _ b: Int) { stat[a * n + b] += 1; count += 1 }
        for s in reference.precomposedStringWithCanonicalMapping.unicodeScalars {
            switch s {
            case "Ü", "ü": add(20, 4); last = 4; add(last, 20)
            case "Ö", "ö": add(14, 4); last = 4; add(last, 14)
            case "Ä", "ä": add(0, 4); last = 4; add(last, 0)
            case "ß": add(18, 18); last = 18; add(last, 18)
            case " ":
                if spaceInAlphabet {
                    if last >= 0 && last < 26 { add(last, 26) }
                    last = 26
                }
            case "[":
                last = -1
            default:
                let cur = CT1SubstText.code(s.value).map { Int($0) }
                if let c = cur, last >= 0 { add(last, c) }
                last = cur ?? -1
            }
        }
        let total = Float(count)
        return stat.map { Float($0) / total }
    }

    /// Single letter and digram distribution of a prepared text (CT1 `createStatistics`).
    func statistics(_ text: [UInt32]) -> (single: [Float], digram: [Float]) {
        let n = size
        var single = [Float](repeating: 0, count: n)
        var digram = [Float](repeating: 0, count: n * n)
        var singleTotal = 0, digramTotal = 0
        var c = text.first.flatMap(symbol)
        if let c0 = c { single[c0] += 1; singleTotal += 1 }
        var i = 1
        while i < text.count {
            let di = c
            c = symbol(text[i])
            i += 1
            guard let cc = c else { continue }
            single[cc] += 1; singleTotal += 1
            guard let d = di else { continue }
            digram[d * n + cc] += 1; digramTotal += 1
        }
        for k in 0..<(n * n) { digram[k] /= Float(digramTotal) }
        for k in 0..<n { single[k] /= Float(singleTotal) }
        return (single, digram)
    }

    /// Initial key from the letter frequencies (CT1 `createInitialKey`).
    func initialKey(single: [Float], language: CT1SubstLanguage) -> [Int] {
        let n = size
        var stats = single
        var temp = Array(0..<n)
        var notDone = true
        while notDone {
            notDone = false
            for i in 0..<(n - 1) where stats[i] < stats[i + 1] {
                stats.swapAt(i, i + 1); temp.swapAt(i, i + 1)
                notDone = true
            }
        }
        var key = Array(0..<n)
        for (i, p) in sortedLetters(language).enumerated() { key[p] = temp[i] }
        return key
    }

    @inline(__always) static func error(_ m: [Float], _ s: [Float]) -> Float {
        var e: Float = 0
        for k in 0..<m.count { e += abs(m[k] - s[k]) }
        return e
    }

    /// CT1 `transformDMatrix` (rows and columns i1/i2 exchanged; the 2×2 block as in CT1).
    static func transform(_ src: [Float], _ i1: Int, _ i2: Int, _ n: Int, into t: inout [Float]) {
        t = src
        for i in 0..<n {
            t[n * i1 + i] = src[n * i2 + i]
            t[n * i2 + i] = src[n * i1 + i]
        }
        let s1 = t[n * i1 + i1], s2 = t[n * i1 + i2], s3 = t[n * i2 + i1], s4 = t[n * i2 + i2]
        for i in 0..<n {
            t[n * i + i1] = src[n * i + i2]
            t[n * i + i2] = src[n * i + i1]
        }
        t[n * i1 + i1] = s1; t[n * i1 + i2] = s2; t[n * i2 + i1] = s3; t[n * i2 + i2] = s4
    }

    /// Inverts a key (encryption ↔ decryption).
    public static func invert(_ key: [Int]) -> [Int] {
        var inv = Array(0..<key.count)
        for (i, k) in key.enumerated() where k >= 0 && k < key.count { inv[k] = i }
        return inv
    }

    // MARK: Analysis

    /// Runs the analysis. `onImprovement` receives every improved key (CT1 shows them live).
    public func analyze(_ ciphertext: String, reference: String, language: CT1SubstLanguage,
                        cancel: CancellationToken? = nil,
                        onImprovement: (@Sendable ([Int]) -> Void)? = nil) -> Result {
        analyze(ciphertext, referenceMatrix: referenceMatrix(reference), language: language,
                cancel: cancel, onImprovement: onImprovement)
    }

    public func analyze(_ ciphertext: String, referenceMatrix std: [Float], language: CT1SubstLanguage,
                        cancel: CancellationToken? = nil,
                        onImprovement: (@Sendable ([Int]) -> Void)? = nil) -> Result {
        let n = size
        let (single, cipherDigrams) = statistics(prepared(ciphertext))
        var bestKey = initialKey(single: single, language: language)
        // digram matrix of the decrypted text = cipher matrix permuted by the decryption key
        func decryptedMatrix(_ key: [Int]) -> [Float] {
            let dec = CT1SubstJakobsen.invert(key)
            var m = [Float](repeating: 0, count: n * n)
            for a in 0..<n { for b in 0..<n { m[dec[a] * n + dec[b]] = cipherDigrams[a * n + b] } }
            return m
        }
        var best = decryptedMatrix(bestKey)
        var bestError = CT1SubstJakobsen.error(best, std)
        onImprovement?(bestKey)
        var current = best
        var improvements = 0
        var d = 1, s1 = 0
        var cancelled = false
        while d < n {
            if s1 + d > n - 1 { s1 = 0; d += 1; continue }
            let s2 = s1 + d
            CT1SubstJakobsen.transform(best, s1, s2, n, into: &current)
            let e = CT1SubstJakobsen.error(current, std)
            if e < bestError {
                bestError = e
                bestKey.swapAt(s1, s2)
                swap(&best, &current)
                improvements += 1
                onImprovement?(bestKey)
                if cancel?.isCancelled == true { cancelled = true; break }
                d = 1; s1 = 0
            } else {
                s1 += 1
            }
        }
        return Result(key: bestKey, error: bestError, improvements: improvements, cancelled: cancelled)
    }

    /// Decrypts with an encryption key (`key[p]` = ciphertext symbol): case and all characters that
    /// are not part of the alphabet are kept (CT1 `encryptText` with the inverted key).
    public func decrypt(_ text: String, key: [Int]) -> String {
        let n = size
        guard key.count == n else { return text }
        let dec = CT1SubstJakobsen.invert(key)
        var out = String.UnicodeScalarView()
        for v in prepared(text) {
            var r = v
            if v >= 65 && v <= 90 {
                r = dec[Int(v - 65)] == 26 ? 32 : UInt32(65 + dec[Int(v - 65)])
            } else if v >= 97 && v <= 122 {
                r = dec[Int(v - 97)] == 26 ? 32 : UInt32(97 + dec[Int(v - 97)])
            } else if spaceInAlphabet && v == 91 {
                r = dec[26] == 26 ? 32 : UInt32(97 + dec[26])
            } else if spaceInAlphabet && v == 7 {
                r = 91
            }
            out.append(Unicode.Scalar(r)!)
        }
        return String(out)
    }

    /// Key as displayed by CT1 (ciphertext letter for A…Z; the space as ' ').
    public static func keyString(_ key: [Int]) -> String {
        String(key.map { $0 == 26 ? " " : CT1SubstText.letters[max(0, min(25, $0))] })
    }
}

// MARK: - Verfahren 2: Hart (frequent words)

/// CT1 "Verfahren 2 basierend auf der Erkennung der häufigsten Wörter einer Sprache" (AnaSubst,
/// after G. W. Hart, "To Decode Short Cryptograms", CACM 37(9), 1994).
///
/// The words of the ciphertext (separated by spaces; at most 100 different words of ≤ 20 letters)
/// are grouped by their letter pattern; only patterns that occur in the word list are used. A depth
/// first search over the pattern classes (root: most distinct letters per candidate, then by number
/// of distinct letters) assigns at most one word per class to a list word with the same pattern; the
/// substitution consistent with the most classes wins (first one found on ties, as in CT1). The search
/// additionally prunes branches that cannot beat the best score – this does not change the result.
public enum CT1SubstHart {
    public struct Result: Sendable {
        /// `mapping[c]` = plaintext index for ciphertext letter `c`, −1 = unknown.
        public var mapping: [Int]
        /// Option "'e' als häufigstes Zeichen annehmen": several letters were equally frequent, the
        /// option was ignored (CT1 IDS_STRING_MSG_FREQ_ANALYSE_NOTE).
        public var frequencyTie: Bool
        public var wordsInAnalysis: Int
        public var patternClasses: Int
        public var score: Int
        public var cancelled: Bool
    }

    /// Word list as CT1 reads it: one word per line, converted to upper case. Lines that are empty
    /// or contain other characters than A–Z are ignored.
    public static func words(fromList content: String) -> [[Int8]] {
        var out: [[Int8]] = []
        for line in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let w = line.trimmingCharacters(in: .whitespaces).uppercased()
            guard !w.isEmpty else { continue }
            var codes: [Int8] = []
            var ok = true
            for s in w.unicodeScalars {
                if s.value >= 65 && s.value <= 90 { codes.append(Int8(s.value - 65)) } else { ok = false; break }
            }
            if ok { out.append(codes) }
        }
        return out
    }

    /// CT1 `match`: same length and the same pattern of repeated letters.
    static func match(_ a: [Int8], _ b: [Int8]) -> Bool {
        guard a.count == b.count else { return false }
        for l in 1..<max(a.count, 1) {
            for j in 0..<l where (a[l] == a[j]) != (b[l] == b[j]) { return false }
        }
        return true
    }

    /// Runs the analysis on `ciphertext` (spaces must be preserved).
    public static func analyze(_ ciphertext: String, wordList: [[Int8]], assumeE: Bool, extended: Bool,
                               cancel: CancellationToken? = nil, progress: ProgressHandler? = nil) -> Result {
        let text = CT1SubstText.symbols(ciphertext, convertUmlauts: true)
        let length = text.count
        var permu = [Int8](repeating: -1, count: 26)
        var vore = [Int](repeating: 0, count: 26), nache = [Int](repeating: 0, count: 26)
        var ende = [Int](repeating: 0, count: 26)

        // Option 1: the most frequent ciphertext letter is the encryption of 'e'
        var oft = -1
        var tie = false
        if assumeE {
            var counts = [Int](repeating: 0, count: 26)
            for s in text where s != CT1SubstText.space { counts[Int(s)] += 1 }
            var maxim = 0
            for i in 0..<26 where counts[i] >= maxim {
                tie = counts[i] == maxim
                oft = i
                maxim = counts[i]
            }
            if !tie { permu[oft] = 4 }
        }

        // ciphertext words grouped by pattern (Cipher) and the matching list words (PatSet)
        var classes: [[[Int8]]] = []
        var patSets: [[[Int8]]] = []
        var wordsInAnalysis = 0
        var start = 0
        while start < length && wordsInAnalysis < 100 {
            if cancel?.isCancelled == true {
                return Result(mapping: Array(repeating: -1, count: 26), frequencyTie: tie, wordsInAnalysis: wordsInAnalysis,
                              patternClasses: classes.count, score: 0, cancelled: true)
            }
            var leer = start
            while leer < length && text[leer] != CT1SubstText.space { leer += 1 }
            if leer - start > 20 { start = leer + 1; continue }
            let word = Array(text[start..<leer])
            for i in 0..<word.count where Int(word[i]) == oft {
                if i < word.count - 1 { nache[Int(word[i + 1])] += 1 }
                if i != 0 { vore[Int(word[i - 1])] += 1 }
            }
            if let last = word.last { ende[Int(last)] += 1 }
            if !word.isEmpty {
                var ci = 0
                while ci < 100 {
                    if ci == classes.count {
                        let candidates = wordList.filter { match(word, $0) }
                        if candidates.isEmpty { break }
                        wordsInAnalysis += 1
                        classes.append([word])
                        patSets.append(Array(candidates.prefix(50)))
                        break
                    }
                    if match(classes[ci][0], word) {
                        if !classes[ci].contains(word) && classes[ci].count < 100 {
                            wordsInAnalysis += 1
                            classes[ci].append(word)
                        }
                        break
                    }
                    ci += 1
                }
            }
            start = leer + 1
        }
        let dMax = classes.count

        // order of the classes: root = max (distinct letters / candidates), then by distinct letters
        var perm: [Int] = []
        if dMax > 0 {
            let nBuch = classes.map { Set($0[0]).count }
            var maxRatio: Float = 0
            var nMax = 0
            for i in 0..<dMax {
                let r = Float(nBuch[i]) / Float(patSets[i].count)
                if r > maxRatio { maxRatio = r; nMax = i }
            }
            var taken = [Bool](repeating: false, count: dMax)
            taken[nMax] = true
            perm = [nMax]
            for _ in 1..<dMax {
                var best = -1, maximum = -1
                for j in 0..<dMax where !taken[j] && nBuch[j] > maximum { maximum = nBuch[j]; best = j }
                taken[best] = true
                perm.append(best)
            }
        }

        // Option 2: extended analysis for German plaintexts (n, r, i) – faithful to CT1
        if extended && assumeE && !tie && oft >= 0 {
            func sorted(_ cond: [Int], _ update: [Int]) -> [Int] {
                var used = [Bool](repeating: false, count: 26)
                var out = [Int](repeating: 0, count: 26)
                var maximum = -1
                for i in 0..<26 {
                    var maxValue = -1
                    for j in 0..<26 where cond[j] > maxValue && !used[j] {
                        maxValue = update[j]
                        maximum = j
                    }
                    out[i] = maximum
                    if maximum >= 0 { used[maximum] = true }
                }
                return out
            }
            let nacheSort = sorted(nache, nache)
            let voreSort = sorted(vore, nache)       // CT1 compares with the "nache" values here
            let endeSort = sorted(ende, ende)
            var minimum = 5000, minimum2 = 5000, punkte = 100, punkte2 = 100
            for i in 0..<26 {
                for j in 0..<26 where endeSort[i] == nacheSort[j] && permu[endeSort[i]] == -1 && i + j < punkte2 {
                    if i + j < punkte {
                        punkte2 = punkte; minimum2 = minimum
                        punkte = i + j; minimum = i
                    } else {
                        punkte2 = i + j; minimum2 = i
                    }
                }
            }
            if minimum < 26 && minimum2 < 26 {
                if minimum < minimum2 {
                    permu[endeSort[minimum]] = 13; permu[endeSort[minimum2]] = 17
                } else {
                    permu[endeSort[minimum2]] = 13; permu[endeSort[minimum]] = 17
                }
            }
            // letters before/after the ciphertext letter 'N' (CT1 uses the symbol value 13 here)
            var vorn = [Int](repeating: 0, count: 26), nachn = [Int](repeating: 0, count: 26)
            for i in 0..<length where text[i] == 13 {
                if i != 0 && text[i - 1] != CT1SubstText.space { vorn[Int(text[i - 1])] += 1 }
                if i < length - 1 && text[i + 1] != CT1SubstText.space { nachn[Int(text[i + 1])] += 1 }
            }
            let vornSort = sorted(vorn, ende)
            _ = sorted(nachn, ende)   // computed but not used by CT1
            punkte = 100
            for i in 0..<26 {
                for j in 0..<26 where voreSort[i] == nacheSort[j] && permu[voreSort[i]] == -1 {
                    for k in 0..<26 where voreSort[i] == vornSort[k] && i + j + k <= punkte {
                        punkte = i + j + k; minimum = i
                    }
                }
            }
            if minimum < 26, permu[voreSort[minimum]] == -1 { permu[voreSort[minimum]] = 8 }
        }

        // depth first search (CT1 `solve`)
        var maxScore = -1
        var bestPermu = permu
        var cancelled = false
        var nodes = 0
        func consistent(_ p: [Int8], _ w: [Int8], _ x: [Int8]) -> [Int8]? {
            var nu = p
            for i in 0..<w.count {
                let wi = Int(w[i]), xi = x[i]
                if p[wi] != -1 && p[wi] != xi { return nil }
                for j in 0..<26 where p[j] == xi && wi != j { return nil }
                nu[wi] = xi
            }
            return nu
        }
        func solve(_ depth: Int, _ p: [Int8], _ score: Int) {
            if cancelled { return }
            nodes += 1
            if nodes & 0x3FFF == 0, cancel?.isCancelled == true { cancelled = true; return }
            if depth == dMax {
                if score > maxScore { maxScore = score; bestPermu = p }
                return
            }
            if score + (dMax - depth) <= maxScore { return }
            let c = perm[depth]
            for w in classes[c] {
                for x in patSets[c] {
                    if let nu = consistent(p, w, x) { solve(depth + 1, nu, score + 1) }
                }
            }
            solve(depth + 1, p, score)
        }
        if dMax == 0 {
            maxScore = 0
        } else {
            // root level by hand for the progress display
            let c = perm[0]
            var branches: [[Int8]] = []
            for w in classes[c] { for x in patSets[c] { if let nu = consistent(permu, w, x) { branches.append(nu) } } }
            let total = Double(branches.count + 1)
            for (k, nu) in branches.enumerated() {
                solve(1, nu, 1)
                progress?(Double(k + 1) / total)
                if cancelled { break }
            }
            if !cancelled { solve(1, permu, 0) }
            progress?(1)
        }
        return Result(mapping: bestPermu.map { Int($0) }, frequencyTie: tie, wordsInAnalysis: wordsInAnalysis,
                      patternClasses: dMax, score: max(maxScore, 0), cancelled: cancelled)
    }
}
