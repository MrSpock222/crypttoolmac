import Foundation
import CTCommon

/// Statistical model of a natural language over the alphabet of a `TextOptions` value.
///
/// Built either from a reference text (CT1: "Optionen ▸ Textoptionen ▸ Referenzdatei", e.g.
/// `deutsch.txt` / `english.txt`) or from the embedded default letter frequencies. With a reference
/// text, log-probability tables for bigrams, trigrams and (for alphabets with ≤ 32 symbols)
/// quadgrams are available; they are used by the substitution and Vigenère solvers.
/// All n-grams are counted over the letter sequence with non-alphabet characters removed
/// (as ciphertexts usually do not contain spaces).
public struct LanguageModel: Sendable {
    /// Number of alphabet symbols the model was built for.
    public let alphabetSize: Int
    /// The alphabet the model was built for.
    public let alphabet: [Character]
    /// Relative letter frequencies in alphabet order (sum = 1).
    public let letterFrequencies: [Double]
    /// Natural logarithms of the (smoothed, strictly positive) letter probabilities.
    public let letterLogProbabilities: [Double]
    /// Number of alphabet letters in the reference text (0 for the embedded defaults).
    public let referenceLetterCount: Int
    /// Description, e.g. "Deutsch (Standard)" or "Referenztext".
    public let name: String

    // n-gram log probabilities (natural log), index = base-`alphabetSize` code. nil if unavailable.
    let bigramLog: [Float]?
    let trigramLog: [Float]?
    let quadgramLog: [Float]?

    /// True if n-gram tables (from a reference text) are available.
    public var hasNGrams: Bool { bigramLog != nil }
    /// Largest n for which a log-probability table exists (1 = letters only).
    public var maxNGramOrder: Int { quadgramLog != nil ? 4 : trigramLog != nil ? 3 : bigramLog != nil ? 2 : 1 }

    /// Expected index of coincidence κ_p = Σ pᵢ² of the language.
    public var kappa: Double { letterFrequencies.reduce(0) { $0 + $1 * $1 } }

    // MARK: Construction

    /// Builds a model from a reference text. N-gram tables are only built if the text contains at
    /// least 1000 alphabet letters (otherwise letters only).
    public static func from(referenceText: String, options: TextOptions) -> LanguageModel {
        let table = LetterTable(options: options)
        let seq = table.indices(referenceText)
        return from(indices: seq, alphabet: table.characters, name: "Reference text")
    }

    /// Builds a model from a sequence of alphabet indices.
    static func from(indices seq: [Int], alphabet: [Character], name: String) -> LanguageModel {
        let n = alphabet.count
        var counts = [Int](repeating: 0, count: n)
        for i in seq { counts[i] += 1 }
        let total = seq.count
        var freqs: [Double]
        if total > 0 {
            freqs = counts.map { Double($0) / Double(total) }
        } else {
            freqs = [Double](repeating: n > 0 ? 1 / Double(n) : 0, count: n)
        }
        var bi: [Float]? = nil, tri: [Float]? = nil, quad: [Float]? = nil
        if total >= 1000 && n >= 2 {
            if n <= 1000 { bi = ngramTable(seq, order: 2, size: n) }
            if n <= 100 { tri = ngramTable(seq, order: 3, size: n) }
            if n <= 32 { quad = ngramTable(seq, order: 4, size: n) }
        }
        return LanguageModel(alphabet: alphabet, frequencies: freqs, letterCount: total, name: name,
                             bigram: bi, trigram: tri, quadgram: quad)
    }

    init(alphabet: [Character], frequencies: [Double], letterCount: Int, name: String,
         bigram: [Float]?, trigram: [Float]?, quadgram: [Float]?) {
        self.alphabet = alphabet
        self.alphabetSize = alphabet.count
        let s = frequencies.reduce(0, +)
        self.letterFrequencies = s > 0 ? frequencies.map { $0 / s } : frequencies
        // smoothing: never zero (unseen letters get a small probability)
        let floor = 0.5 / Double(max(letterCount, 10_000))
        let smoothed = letterFrequencies.map { max($0, floor) }
        let ss = smoothed.reduce(0, +)
        self.letterLogProbabilities = smoothed.map { log($0 / max(ss, .leastNonzeroMagnitude)) }
        self.referenceLetterCount = letterCount
        self.name = name
        self.bigramLog = bigram
        self.trigramLog = trigram
        self.quadgramLog = quadgram
    }

    private static func ngramTable(_ seq: [Int], order: Int, size: Int) -> [Float] {
        var space = 1
        for _ in 0..<order { space *= size }
        var counts = [Int32](repeating: 0, count: space)
        let modulus = space / size
        var code = 0
        var total = 0
        for (k, v) in seq.enumerated() {
            code = (code % modulus) * size + v
            if k >= order - 1 { counts[code] += 1; total += 1 }
        }
        let t = Double(max(total, 1))
        let floorLog = Float(log(0.01 / t))
        var table = [Float](repeating: floorLog, count: space)
        for i in 0..<space where counts[i] > 0 { table[i] = Float(log(Double(counts[i]) / t)) }
        return table
    }

    /// Model with the embedded German letter frequencies (A–Z, Ä, Ö, Ü, ß; space if part of the
    /// alphabet). Letters of the alphabet without a table entry get a tiny probability.
    public static func defaultGerman(options: TextOptions) -> LanguageModel {
        fromTable(germanFrequencies, spaceShare: 0.15, options: options, name: "German (default)")
    }

    /// Model with the embedded English letter frequencies (A–Z; space if part of the alphabet).
    public static func defaultEnglish(options: TextOptions) -> LanguageModel {
        fromTable(englishFrequencies, spaceShare: 0.18, options: options, name: "English (default)")
    }

    private static func fromTable(_ tab: [Character: Double], spaceShare: Double, options: TextOptions, name: String) -> LanguageModel {
        let chars = options.alphabetCharacters
        // count how many alphabet characters map to the same table letter (e.g. 'A' and 'a' when
        // case is distinguished) to split the probability mass
        func key(_ c: Character) -> Character? {
            if tab[c] != nil { return c }
            let up = String(c).uppercased()
            if up.count == 1, let u = up.first, tab[u] != nil { return u }
            if c == "ß" { return "ß" }
            return nil
        }
        var multiplicity: [Character: Int] = [:]
        for c in chars { if let k = key(c) { multiplicity[k, default: 0] += 1 } }
        var freqs: [Double] = []
        let letterMass = 1.0 - (chars.contains(" ") ? spaceShare : 0)
        for c in chars {
            if c == " " {
                freqs.append(spaceShare)
            } else if let k = key(c), let p = tab[k] {
                let m = Double(multiplicity[k] ?? 1)
                // upper case letters are rarer in running text if both cases are in the alphabet
                var share = 1.0 / m
                if m > 1 { share = (c == k) ? 0.04 : 0.96 }
                freqs.append(p * letterMass * share)
            } else {
                freqs.append(0.0005)
            }
        }
        return LanguageModel(alphabet: chars, frequencies: freqs, letterCount: 0, name: name,
                             bigram: nil, trigram: nil, quadgram: nil)
    }

    // MARK: Scoring

    /// Log-likelihood score of a text given as alphabet indices (higher = more language-like).
    /// Uses the highest available n-gram order (quadgrams → trigrams → bigrams → letters);
    /// the value is the sum of natural log-probabilities of all overlapping n-grams.
    public func score(indices: [Int]) -> Double {
        let n = alphabetSize
        guard n > 0, !indices.isEmpty else { return 0 }
        if let q = quadgramLog, indices.count >= 4 { return Self.sumTable(q, indices, order: 4, size: n) }
        if let t = trigramLog, indices.count >= 3 { return Self.sumTable(t, indices, order: 3, size: n) }
        if let b = bigramLog, indices.count >= 2 { return Self.sumTable(b, indices, order: 2, size: n) }
        return unigramScore(indices: indices)
    }

    /// Score per scored n-gram (comparable between texts of different length).
    public func normalizedScore(indices: [Int]) -> Double {
        let order = min(maxNGramOrder, max(1, indices.count))
        let count = indices.count - order + 1
        return count > 0 ? score(indices: indices) / Double(count) : 0
    }

    /// Sum of the letter log-probabilities.
    public func unigramScore(indices: [Int]) -> Double {
        var s = 0.0
        for i in indices { s += letterLogProbabilities[i] }
        return s
    }

    static func sumTable(_ table: [Float], _ seq: [Int], order: Int, size: Int) -> Double {
        var s: Float = 0
        var modulus = 1
        for _ in 0..<(order - 1) { modulus *= size }
        var code = 0
        seq.withUnsafeBufferPointer { p in
            table.withUnsafeBufferPointer { t in
                for k in 0..<p.count {
                    code = (code % modulus) * size + p[k]
                    if k >= order - 1 { s += t[code] }
                }
            }
        }
        return Double(s)
    }

    /// The table used by `score` (order, table) – internal for fast incremental solvers.
    func bestTable() -> (order: Int, table: [Float])? {
        if let q = quadgramLog { return (4, q) }
        if let t = trigramLog { return (3, t) }
        if let b = bigramLog { return (2, b) }
        return nil
    }

    /// χ² statistic of observed letter counts (alphabet order) against the model frequencies
    /// (smaller = better fit).
    public func chiSquared(counts: [Int]) -> Double {
        let total = Double(counts.reduce(0, +))
        guard total > 0 else { return 0 }
        var chi = 0.0
        for (i, c) in counts.enumerated() where i < alphabetSize {
            let e = total * exp(letterLogProbabilities[i])
            let d = Double(c) - e
            chi += d * d / e
        }
        return chi
    }

    // MARK: Embedded tables

    /// German letter frequencies (percent), typical values for running text.
    static let germanFrequencies: [Character: Double] = [
        "A": 6.51, "B": 1.89, "C": 3.06, "D": 5.08, "E": 17.40, "F": 1.66, "G": 3.01, "H": 4.76,
        "I": 7.55, "J": 0.27, "K": 1.21, "L": 3.44, "M": 2.53, "N": 9.78, "O": 2.51, "P": 0.79,
        "Q": 0.02, "R": 7.00, "S": 7.27, "T": 6.15, "U": 4.35, "V": 0.67, "W": 1.89, "X": 0.03,
        "Y": 0.04, "Z": 1.13, "Ä": 0.54, "Ö": 0.30, "Ü": 0.65, "ß": 0.31,
    ]

    /// English letter frequencies (percent), typical values for running text.
    static let englishFrequencies: [Character: Double] = [
        "A": 8.17, "B": 1.49, "C": 2.78, "D": 4.25, "E": 12.70, "F": 2.23, "G": 2.02, "H": 6.09,
        "I": 6.97, "J": 0.15, "K": 0.77, "L": 4.03, "M": 2.41, "N": 6.75, "O": 7.51, "P": 1.93,
        "Q": 0.10, "R": 5.99, "S": 6.33, "T": 9.06, "U": 2.76, "V": 0.98, "W": 2.36, "X": 0.15,
        "Y": 1.97, "Z": 0.07,
    ]
}
