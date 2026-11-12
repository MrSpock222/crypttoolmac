import Foundation
import CTCommon

/// Returns `model` if it fits the alphabet of `table`, otherwise a default model for it.
func compatibleModel(_ model: LanguageModel, _ table: LetterTable, _ options: TextOptions) -> LanguageModel {
    if model.alphabetSize == table.size { return model }
    return LanguageModel.defaultGerman(options: options)
}

// MARK: - Caesar

/// Ciphertext-only analysis of the Caesar cipher (CT1 "Analyse ▸ Symmetrische Verschlüsselung
/// (klassisch) ▸ Ciphertext-Only ▸ Caesar").
///
/// Shift convention: ciphertext index = plaintext index + `shift` (mod alphabet size); the key
/// letter (with "A = 0") is `alphabet[shift]`.
///
/// CT1's method: compute the cyclic correlation between the letter distribution of the reference
/// text and that of the ciphertext and take the peak (`correlation`). The classical manual method is
/// "most frequent ciphertext letter ↦ E" (`mostFrequentLetterShift`). `analyze` uses the maximum
/// log-likelihood under the language model (n-gram score if the model has a reference text), which
/// is the most reliable variant for short texts.
public enum CaesarAnalysis {

    /// Finds the most probable shift. `scores[s]` is the average log-likelihood per scored n-gram of
    /// the text decrypted with shift `s` (higher = better); `shift` is the arg max.
    public static func analyze(_ text: String, options: TextOptions, model: LanguageModel) -> (shift: Int, scores: [Double]) {
        let table = LetterTable(options: options)
        let n = table.size
        guard n > 0 else { return (0, []) }
        let model = compatibleModel(model, table, options)
        let seq = table.indices(text)
        guard !seq.isEmpty else { return (0, [Double](repeating: 0, count: n)) }
        var scores = [Double](repeating: 0, count: n)
        var dec = seq
        for s in 0..<n {
            for k in 0..<seq.count { dec[k] = mod(seq[k] - s, n) }
            scores[s] = model.hasNGrams && seq.count >= 2
                ? model.normalizedScore(indices: dec)
                : model.unigramScore(indices: dec) / Double(seq.count)
        }
        var best = 0
        for s in 1..<n where scores[s] > scores[best] { best = s }
        return (best, scores)
    }

    /// CT1 correlation plot: `result[s] = Σᵢ p(i) · q((i + s) mod n)` with p = reference letter
    /// frequencies and q = relative ciphertext letter frequencies. The peak is the shift.
    public static func correlation(_ text: String, options: TextOptions, model: LanguageModel) -> [Double] {
        let table = LetterTable(options: options)
        let n = table.size
        guard n > 0 else { return [] }
        let model = compatibleModel(model, table, options)
        var counts = [Double](repeating: 0, count: n)
        let seq = table.indices(text)
        for i in seq { counts[i] += 1 }
        let total = Double(max(seq.count, 1))
        return (0..<n).map { s in
            var c = 0.0
            for i in 0..<n { c += model.letterFrequencies[i] * counts[(i + s) % n] / total }
            return c
        }
    }

    /// Classical manual method: assumes that the most frequent ciphertext letter is the encryption
    /// of `assumedPlain` (default "E"). Returns the resulting shift (0 if not applicable).
    public static func mostFrequentLetterShift(_ text: String, options: TextOptions, assumedPlain: Character = "E") -> Int {
        let table = LetterTable(options: options)
        guard table.size > 0, let (p, _) = table.lookup(assumedPlain) else { return 0 }
        var counts = [Int](repeating: 0, count: table.size)
        for i in table.indices(text) { counts[i] += 1 }
        var best = 0
        for i in 1..<table.size where counts[i] > counts[best] { best = i }
        return mod(best - p, table.size)
    }

    /// Decrypts a Caesar ciphertext (keeps case and non-alphabet characters per `options`).
    public static func decrypt(_ text: String, shift: Int, options: TextOptions) -> String {
        LetterTable(options: options).mapLetters(text) { i, _ in i - shift }
    }
}

// MARK: - Vigenère

/// Ciphertext-only analysis of the Vigenère cipher (CT1 "… ▸ Ciphertext-Only ▸ Vigenère").
///
/// Key convention: ciphertext = plaintext + key letter (mod n), key letter "A" = shift 0.
/// CT1 determines the period with the autocorrelation (first shift whose coincidence count exceeds
/// (average + maximum)/2, see `autocorrelationKeyLength`) and breaks every column as a Caesar cipher by
/// correlating with the reference distribution. `analyze` uses a more robust approach (column
/// log-likelihood for every candidate length, verification of the decrypted text with the n-gram
/// model, preference of the smallest divisor and an n-gram refinement of every key letter).
public enum VigenereAnalysis {

    /// Friedman test: estimated key length
    /// L ≈ N(κp − κr) / ((N − 1)κo − Nκr + κp) with κo = observed index of coincidence,
    /// κp = model index of coincidence, κr = 1/n. Returns 0 if not computable.
    public static func friedmanKeyLength(_ text: String, options: TextOptions, model: LanguageModel) -> Double {
        let table = LetterTable(options: options)
        let seq = table.indices(text)
        let n = table.size
        guard seq.count > 1, n > 0 else { return 0 }
        let model = compatibleModel(model, table, options)
        let N = Double(seq.count)
        let ko = Statistics.indexOfCoincidence(indices: seq, alphabetSize: n)
        let kp = model.kappa
        let kr = 1.0 / Double(n)
        let denom = (N - 1) * ko - N * kr + kp
        guard denom > 0 else { return 0 }
        return max(0, N * (kp - kr) / denom)
    }

    /// Kasiski test: distances between consecutive occurrences of repeated letter sequences of length
    /// `minLength` (non-alphabet characters removed). Result: distinct distances with their
    /// frequency, sorted by descending count (then ascending distance).
    public static func kasiski(_ text: String, options: TextOptions, minLength: Int = 3) -> [(distance: Int, count: Int)] {
        let table = LetterTable(options: options)
        let seq = table.indices(text)
        let m = max(1, minLength)
        guard seq.count > m, table.size > 0 else { return [] }
        var last: [[Int]: Int] = [:]
        var dist: [Int: Int] = [:]
        for i in 0...(seq.count - m) {
            let gram = Array(seq[i..<(i + m)])
            if let p = last[gram] { dist[i - p, default: 0] += 1 }
            last[gram] = i
        }
        return dist.map { (distance: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.distance < $1.distance }
    }

    /// For every key length 1 … `maxLength`: the average index of coincidence of the columns
    /// (text split into `length` columns). Values near κp of the language indicate the period.
    public static func keyLengthScores(_ text: String, options: TextOptions, maxLength: Int = 30) -> [(length: Int, score: Double)] {
        let table = LetterTable(options: options)
        let seq = table.indices(text)
        let n = table.size
        guard n > 0, maxLength >= 1 else { return [] }
        return (1...maxLength).map { L in
            var sum = 0.0
            var cols = 0
            for c in 0..<L {
                var counts = [Int](repeating: 0, count: n)
                var k = c
                var len = 0
                while k < seq.count { counts[seq[k]] += 1; k += L; len += 1 }
                if len > 1 { sum += Statistics.indexOfCoincidence(counts: counts); cols += 1 }
            }
            return (length: L, score: cols > 0 ? sum / Double(cols) : 0)
        }
    }

    /// CT1's period estimate from the autocorrelation of the letters (shifts 1 … min(N, 200) − 1):
    /// the first shift whose coincidence count exceeds (average + maximum) / 2.
    public static func autocorrelationKeyLength(_ text: String, options: TextOptions) -> Int {
        let seq = LetterTable(options: options).indices(text)
        return ct1Period(seq, maxShift: min(seq.count, 200) - 1)
    }

    /// Breaks a Vigenère ciphertext. If `keyLength` is nil the length is determined automatically
    /// (1 … min(`maxKeyLength`, N/2)). Returns the key length, the shifts (key letter indices) and
    /// the key as alphabet letters (an iterated key like "ABAB" is reduced to "AB").
    public static func analyze(_ text: String, options: TextOptions, model: LanguageModel, keyLength: Int? = nil,
                               maxKeyLength: Int = 30) -> (keyLength: Int, shifts: [Int], key: String) {
        let table = LetterTable(options: options)
        let n = table.size
        let seq = table.indices(text)
        guard n > 0, !seq.isEmpty else { return (0, [], "") }
        let model = compatibleModel(model, table, options)

        var L: Int
        var shifts: [Int]
        if let k = keyLength, k >= 1 {
            L = min(k, seq.count)
            shifts = columnShifts(seq, L, n, model)
        } else {
            let maxL = max(1, min(maxKeyLength, seq.count / 2))
            var scores: [Double] = []
            var allShifts: [[Int]] = []
            for l in 1...maxL {
                let s = columnShifts(seq, l, n, model)
                allShifts.append(s)
                scores.append(normalizedScore(decrypt(seq, s, n), model))
            }
            var best = 0
            for i in 1..<scores.count where scores[i] > scores[best] { best = i }
            let bestL = best + 1
            let sorted = scores.sorted()
            let median = sorted[sorted.count / 2]
            let tol = max(0, (scores[best] - median) * 0.1)
            L = bestL
            for d in 1...bestL where bestL % d == 0 {
                if scores[d - 1] >= scores[best] - tol { L = d; break }
            }
            shifts = allShifts[L - 1]
        }
        if model.hasNGrams {
            // refinement on at most 3000 letters (enough statistics, bounded run time)
            let sample = seq.count > 3000 ? Array(seq.prefix(3000)) : seq
            if sample.count >= shifts.count { shifts = refine(sample, shifts, n, model) }
        }
        // reduce an iterated key ("ABCABC" → "ABC") as CT1 does
        var period = shifts.count
        for p in 1..<max(shifts.count, 1) where shifts.count % p == 0 {
            if (0..<shifts.count).allSatisfy({ shifts[$0] == shifts[$0 % p] }) { period = p; break }
        }
        shifts = Array(shifts.prefix(period))
        return (shifts.count, shifts, table.string(from: shifts))
    }

    /// Decrypts a Vigenère ciphertext with the given shifts (keeps case/non-alphabet characters).
    public static func decrypt(_ text: String, shifts: [Int], options: TextOptions) -> String {
        guard !shifts.isEmpty else { return text }
        return LetterTable(options: options).mapLetters(text) { i, pos in i - shifts[pos % shifts.count] }
    }

    // MARK: internals

    static func ct1Period(_ seq: [Int], maxShift: Int) -> Int {
        guard maxShift >= 1 else { return 1 }
        let c = Statistics.autocorrelation(seq, maxShift: maxShift)
        // CT1: GetAverage(1) divides the sum of c[1..] by the full size (incl. shift 0)
        let av = Double(c.reduce(0, +)) / Double(maxShift + 1)
        let mx = Double(c.max() ?? 0)
        let s = Int((Int(av) + Int(mx)) / 2)
        for (k, v) in c.enumerated() where v > s { return k + 1 }
        return maxShift + 1
    }

    static func columnShifts(_ seq: [Int], _ L: Int, _ n: Int, _ model: LanguageModel) -> [Int] {
        (0..<L).map { c in
            var counts = [Double](repeating: 0, count: n)
            var k = c
            while k < seq.count { counts[seq[k]] += 1; k += L }
            var best = 0
            var bestLL = -Double.infinity
            for s in 0..<n {
                var ll = 0.0
                for j in 0..<n where counts[j] > 0 { ll += counts[j] * model.letterLogProbabilities[mod(j - s, n)] }
                if ll > bestLL { bestLL = ll; best = s }
            }
            return best
        }
    }

    static func decrypt(_ seq: [Int], _ shifts: [Int], _ n: Int) -> [Int] {
        let L = shifts.count
        var out = seq
        for k in 0..<seq.count { out[k] = mod(seq[k] - shifts[k % L], n) }
        return out
    }

    static func normalizedScore(_ dec: [Int], _ model: LanguageModel) -> Double {
        model.hasNGrams ? model.normalizedScore(indices: dec) : model.unigramScore(indices: dec) / Double(max(dec.count, 1))
    }

    /// Coordinate ascent: re-optimises every key letter with the full n-gram score.
    static func refine(_ seq: [Int], _ initial: [Int], _ n: Int, _ model: LanguageModel) -> [Int] {
        var shifts = initial
        let L = shifts.count
        var dec = decrypt(seq, shifts, n)
        var current = model.score(indices: dec)
        for _ in 0..<6 {
            var changed = false
            for c in 0..<L {
                var bestS = shifts[c]
                var bestScore = current
                for s in 0..<n where s != shifts[c] {
                    var k = c
                    while k < seq.count { dec[k] = mod(seq[k] - s, n); k += L }
                    let sc = model.score(indices: dec)
                    if sc > bestScore + 1e-9 { bestScore = sc; bestS = s }
                }
                var k = c
                while k < seq.count { dec[k] = mod(seq[k] - bestS, n); k += L }
                if bestS != shifts[c] { shifts[c] = bestS; current = bestScore; changed = true }
            }
            if !changed { break }
        }
        return shifts
    }
}
