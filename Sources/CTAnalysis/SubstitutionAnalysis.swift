import Foundation
import CTCommon

/// Ciphertext-only analysis of the monoalphabetic substitution (CT1 "… ▸ Ciphertext-Only ▸
/// Substitution").
///
/// CT1 used Jakobsen's fast algorithm (swapping key letters guided by digram statistics). This port
/// uses the closely related, stronger hill climbing on quadgram log-probabilities: starting from a
/// key (frequency ranking for the first restart, random keys otherwise), two key letters are swapped;
/// the swap is kept if the score of the decrypted text improves. A climb ends after `iterations`
/// consecutive non-improving swaps; every restart additionally performs a few rounds of iterated
/// local search (perturb its best key, climb again). Restarts run in parallel on all cores.
/// Quadgrams are used if the model was built from a reference text (≥ 1000 letters), otherwise
/// only letter frequencies (which is usually not sufficient to solve a substitution).
/// Long texts: the key search uses the first 2500 letters.
public enum SubstitutionAnalysis {

    /// Breaks a monoalphabetic substitution.
    /// - Returns: `key[c]` = plaintext index for ciphertext index `c`, the decrypted text (case and
    ///   non-alphabet characters kept as by `TextOptions.mapLetters`) and the score
    ///   (`LanguageModel.score` of the decrypted letters, higher = better).
    public static func automatic(_ ciphertext: String, options: TextOptions, model: LanguageModel,
                                 restarts: Int = 20, iterations: Int = 2000,
                                 cancel: CancellationToken? = nil, progress: ProgressHandler? = nil)
        -> (key: [Int], plaintext: String, score: Double) {
        automatic(ciphertext, options: options, model: model, restarts: restarts, iterations: iterations,
                  seed: UInt64.random(in: 0...UInt64.max), cancel: cancel, progress: progress)
    }

    /// Variant with a fixed random seed (reproducible results, used by the tests).
    public static func automatic(_ ciphertext: String, options: TextOptions, model: LanguageModel,
                                 restarts: Int, iterations: Int, seed: UInt64,
                                 cancel: CancellationToken? = nil, progress: ProgressHandler? = nil)
        -> (key: [Int], plaintext: String, score: Double) {
        let table = LetterTable(options: options)
        let n = table.size
        guard n > 1 else { return (Array(0..<max(n, 0)), ciphertext, 0) }
        let model = compatibleModel(model, table, options)
        let seq = table.indices(ciphertext)
        let identity = Array(0..<n)
        guard !seq.isEmpty else { return (identity, ciphertext, 0) }

        // the key search uses at most 2500 letters (bounded run time); the key is applied to all
        let scorer = Scorer(seq: seq.count > 2500 ? Array(seq.prefix(2500)) : seq, model: model, n: n)

        // initial key from the frequency ranking
        var counts = [Int](repeating: 0, count: n)
        for c in seq { counts[c] += 1 }
        let cipherRank = (0..<n).sorted { counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 < $1 }
        let plainRank = (0..<n).sorted { model.letterFrequencies[$0] != model.letterFrequencies[$1] ? model.letterFrequencies[$0] > model.letterFrequencies[$1] : $0 < $1 }
        var freqKey = identity
        for (r, c) in cipherRank.enumerated() { freqKey[c] = plainRank[r] }

        // Every restart: hill climbing from a start key (restart 0: frequency key, others random),
        // followed by `ilsRounds` rounds of iterated local search (perturb the restart's best key by
        // a few random swaps and climb again). Restarts run in parallel; each has its own
        // deterministic random stream, the best result (ties: lowest restart) wins.
        let totalRestarts = max(1, restarts)
        let ilsRounds = 8
        let maxFails = max(1, iterations)
        let results = ResultBox(count: totalRestarts)
        let done = ResultBox(count: 1)
        let freqStart = freqKey
        DispatchQueue.concurrentPerform(iterations: totalRestarts) { r in
            if cancel?.isCancelled == true { return }
            var rng = SplitMix64(seed: seed &+ UInt64(r) &* 0x9E37_79B9_7F4A_7C15)
            var plain = [Int](repeating: 0, count: scorer.seq.count)
            var key = identity
            if r == 0 { key = freqStart } else { key.shuffle(using: &rng) }
            var current = scorer.score(key, into: &plain)
            var localKey = key
            var localScore = -Double.infinity
            for round in 0...ilsRounds {
                if round > 0 {
                    key = localKey
                    for _ in 0..<(2 + round % 3) {
                        let a = Int.random(in: 0..<n, using: &rng), b = Int.random(in: 0..<n, using: &rng)
                        key.swapAt(a, b)
                    }
                    current = scorer.score(key, into: &plain)
                }
                var fails = 0
                var evals = 0
                while fails < maxFails {
                    let a = Int.random(in: 0..<n, using: &rng)
                    var b = Int.random(in: 0..<(n - 1), using: &rng)
                    if b >= a { b += 1 }
                    key.swapAt(a, b)
                    let s = scorer.score(key, into: &plain)
                    if s > current {
                        current = s
                        fails = 0
                    } else {
                        key.swapAt(a, b)
                        fails += 1
                    }
                    evals += 1
                    if evals & 1023 == 0, cancel?.isCancelled == true { break }
                }
                if current > localScore { localScore = current; localKey = key }
                if cancel?.isCancelled == true { break }
            }
            results.set(r, key: localKey, score: localScore)
            let finished = done.increment()
            progress?(Double(finished) / Double(totalRestarts))
        }
        var bestKey = freqKey
        var bestScore = scorer.score(freqKey)
        for r in 0..<totalRestarts {
            if let (k, sc) = results.get(r), sc > bestScore + 1e-7 { bestKey = k; bestScore = sc }
        }
        progress?(1)
        let text = apply(key: bestKey, to: ciphertext, options: options)
        return (bestKey, text, model.score(indices: seq.map { bestKey[$0] }))
    }

    /// Applies a decryption key (`key[c]` = plaintext index of ciphertext index `c`). Case and
    /// non-alphabet characters are handled like `TextOptions.mapLetters`.
    public static func apply(key: [Int], to ciphertext: String, options: TextOptions) -> String {
        let table = LetterTable(options: options)
        return table.mapLetters(ciphertext) { i, _ in i < key.count ? key[i] : i }
    }

    /// The decryption key as string: plaintext letter for every ciphertext letter in alphabet order.
    public static func keyString(_ key: [Int], options: TextOptions) -> String {
        LetterTable(options: options).string(from: key)
    }

    /// Inverts a permutation key (decryption key ↔ encryption key).
    public static func invert(_ key: [Int]) -> [Int] {
        var inv = [Int](repeating: 0, count: key.count)
        for (c, p) in key.enumerated() where p >= 0 && p < key.count { inv[p] = c }
        return inv
    }

    /// Thread-safe storage for the parallel restarts.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: [[Int]?]
        private var scores: [Double]
        private var counter = 0
        init(count: Int) {
            keys = [[Int]?](repeating: nil, count: count)
            scores = [Double](repeating: -.infinity, count: count)
        }
        func set(_ i: Int, key: [Int], score: Double) {
            lock.lock(); keys[i] = key; scores[i] = score; lock.unlock()
        }
        func get(_ i: Int) -> ([Int], Double)? {
            lock.lock(); defer { lock.unlock() }
            return keys[i].map { ($0, scores[i]) }
        }
        func increment() -> Int {
            lock.lock(); defer { lock.unlock() }
            counter += 1
            return counter
        }
    }

    /// Fast scorer for the hill climber.
    private struct Scorer: @unchecked Sendable {
        let seq: [Int]
        let model: LanguageModel
        let n: Int
        let order: Int
        let table: [Float]?

        init(seq: [Int], model: LanguageModel, n: Int) {
            self.seq = seq
            self.model = model
            self.n = n
            if let (o, t) = model.bestTable(), seq.count >= o {
                order = o
                table = t
            } else {
                order = 1
                table = nil
            }
        }

        func score(_ key: [Int]) -> Double {
            var plain = [Int](repeating: 0, count: seq.count)
            return score(key, into: &plain)
        }

        func score(_ key: [Int], into plain: inout [Int]) -> Double {
            let count = seq.count
            return seq.withUnsafeBufferPointer { s in
                key.withUnsafeBufferPointer { k in
                    plain.withUnsafeMutableBufferPointer { p in
                        for i in 0..<count { p[i] = k[s[i]] }
                        guard let table = table else {
                            var sum = 0.0
                            for i in 0..<count { sum += model.letterLogProbabilities[p[i]] }
                            return sum
                        }
                        return table.withUnsafeBufferPointer { t in
                            var sum: Float = 0
                            let n = self.n
                            switch order {
                            case 4:
                                var code = p[0] * n * n + p[1] * n + p[2]
                                let m = n * n * n
                                for i in 3..<count {
                                    code = (code % m) * n + p[i]
                                    sum += t[code]
                                }
                            case 3:
                                var code = p[0] * n + p[1]
                                let m = n * n
                                for i in 2..<count {
                                    code = (code % m) * n + p[i]
                                    sum += t[code]
                                }
                            default:
                                for i in 1..<count { sum += t[p[i - 1] * n + p[i]] }
                            }
                            return Double(sum)
                        }
                    }
                }
            }
        }
    }
}
