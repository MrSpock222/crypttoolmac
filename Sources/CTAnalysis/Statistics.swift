import Foundation
import CTCommon

/// Basic statistics of texts and binary data (CT1 menu "Analyse ▸ Werkzeuge zur Analyse").
public enum Statistics {

    // MARK: Entropy

    /// Shannon entropy of the byte values in bits per byte (0 … 8). CT1 "Entropie" for binary documents.
    public static func entropy(bytes: [UInt8]) -> Double {
        guard !bytes.isEmpty else { return 0 }
        return entropy(counts: byteHistogram(bytes))
    }

    /// Shannon entropy over the alphabet symbols of `text` in bits per symbol (CT1 "Entropie" for
    /// text documents: only characters of the alphabet are counted). Maximum: `log2(alphabetSize)`.
    public static func entropy(text: String, options: TextOptions) -> Double {
        let table = LetterTable(options: options)
        var counts = [Int](repeating: 0, count: table.size)
        for i in table.indices(text) { counts[i] += 1 }
        return entropy(counts: counts)
    }

    /// Shannon entropy (bits) of a frequency distribution given as absolute counts.
    public static func entropy(counts: [Int]) -> Double {
        let total = counts.reduce(0, +)
        guard total > 0 else { return 0 }
        let t = Double(total)
        var h = 0.0
        for c in counts where c > 0 {
            let p = Double(c) / t
            h -= p * log2(p)
        }
        return h
    }

    /// Maximum possible entropy `log2(symbolCount)` (equal distribution).
    public static func maximumEntropy(symbolCount: Int) -> Double {
        symbolCount > 0 ? log2(Double(symbolCount)) : 0
    }

    // MARK: Histograms

    /// Absolute frequencies of all 256 byte values.
    public static func byteHistogram(_ bytes: [UInt8]) -> [Int] {
        var h = [Int](repeating: 0, count: 256)
        bytes.withUnsafeBufferPointer { buf in
            for b in buf { h[Int(b)] += 1 }
        }
        return h
    }

    /// Absolute frequencies of the alphabet letters in `text`, in alphabet order
    /// (CT1 "Histogramm" of a text document). Case folding follows `options`.
    public static func letterCounts(_ text: String, options: TextOptions) -> [(symbol: Character, count: Int)] {
        let table = LetterTable(options: options)
        var counts = [Int](repeating: 0, count: table.size)
        for i in table.indices(text) { counts[i] += 1 }
        return zip(table.characters, counts).map { (symbol: $0.0, count: $0.1) }
    }

    // MARK: N-grams

    /// One row of an n-gram list.
    public struct NGramEntry: Sendable, Equatable {
        /// The n-gram (alphabet characters, or hex bytes like "1F A0" for binary data).
        public let gram: String
        /// Absolute frequency.
        public let count: Int
        /// Relative frequency in percent of all counted n-grams.
        public let percent: Double
        public init(gram: String, count: Int, percent: Double) {
            self.gram = gram
            self.count = count
            self.percent = percent
        }
    }

    /// N-gram analysis of a text (CT1 "N-Gramm-Analyse", text mode): overlapping n-grams over the
    /// alphabet letters, sorted by descending count (ties alphabetically).
    ///
    /// As in CT1, an n-gram does not span characters outside the alphabet (spaces, punctuation …)
    /// unless `acrossNonAlphabet` is `true`. `limit` restricts the number of returned rows
    /// (CT1 default display: 26, maximum 5000).
    public static func ngrams(_ text: String, n: Int, options: TextOptions, limit: Int = 100,
                              acrossNonAlphabet: Bool = false) -> [NGramEntry] {
        guard n >= 1 else { return [] }
        let table = LetterTable(options: options)
        let size = table.size
        guard size > 0 else { return [] }
        let seq = acrossNonAlphabet ? table.indices(text) : table.indicesWithGaps(text)
        var counts: [Int: Int] = [:]
        var useArray = false
        var arrayCounts: [Int] = []
        // Encode n-grams as integers in base `size` (dense array if small enough).
        var space = 1.0
        for _ in 0..<n { space *= Double(size) }
        if space <= 1_048_576 { useArray = true; arrayCounts = [Int](repeating: 0, count: Int(space)) }
        guard space < 9.0e18 else { return ngramsByString(seq, n: n, table: table, limit: limit) }
        let modulus = Int(space) / size   // size^(n-1)
        var code = 0
        var run = 0
        var total = 0
        for v in seq {
            if v < 0 { run = 0; code = 0; continue }
            code = (code % modulus) * size + v
            run += 1
            if run >= n {
                total += 1
                if useArray { arrayCounts[code] += 1 } else { counts[code, default: 0] += 1 }
            }
        }
        guard total > 0 else { return [] }
        var pairs: [(code: Int, count: Int)] = []
        if useArray {
            for (c, k) in arrayCounts.enumerated() where k > 0 { pairs.append((c, k)) }
        } else {
            pairs = counts.map { ($0.key, $0.value) }
        }
        // Order: count descending, then lexicographic by alphabet index (= code ascending).
        pairs.sort { $0.count != $1.count ? $0.count > $1.count : $0.code < $1.code }
        let t = Double(total)
        return pairs.prefix(max(0, limit)).map { p in
            var digits = [Int](repeating: 0, count: n)
            var c = p.code
            for k in stride(from: n - 1, through: 0, by: -1) { digits[k] = c % size; c /= size }
            return NGramEntry(gram: table.string(from: digits), count: p.count, percent: Double(p.count) * 100 / t)
        }
    }

    private static func ngramsByString(_ seq: [Int], n: Int, table: LetterTable, limit: Int) -> [NGramEntry] {
        var counts: [[Int]: Int] = [:]
        var window: [Int] = []
        var total = 0
        for v in seq {
            if v < 0 { window.removeAll(); continue }
            window.append(v)
            if window.count > n { window.removeFirst() }
            if window.count == n { counts[window, default: 0] += 1; total += 1 }
        }
        let t = Double(max(total, 1))
        let sorted = counts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key.lexicographicallyPrecedes(b.key)
        }
        return sorted.prefix(max(0, limit)).map {
            NGramEntry(gram: table.string(from: $0.key), count: $0.value, percent: Double($0.value) * 100 / t)
        }
    }

    /// N-gram analysis of binary data (CT1 "N-Gramm-Analyse", binary mode): overlapping n-grams of
    /// bytes; `gram` is the hex representation ("41 42"). Sorted by descending count.
    public static func byteNGrams(_ bytes: [UInt8], n: Int, limit: Int = 100) -> [NGramEntry] {
        guard n >= 1, bytes.count >= n else { return [] }
        let total = bytes.count - n + 1
        var pairs: [(key: [UInt8], count: Int)]
        if n <= 2 {
            var arr = [Int](repeating: 0, count: n == 1 ? 256 : 65536)
            for i in 0..<total {
                let code = n == 1 ? Int(bytes[i]) : (Int(bytes[i]) << 8 | Int(bytes[i + 1]))
                arr[code] += 1
            }
            pairs = []
            for (c, k) in arr.enumerated() where k > 0 {
                pairs.append((n == 1 ? [UInt8(c)] : [UInt8(c >> 8), UInt8(c & 0xFF)], k))
            }
        } else if n <= 8 {
            var dict: [UInt64: Int] = [:]
            for i in 0..<total {
                var code: UInt64 = 0
                for k in 0..<n { code = code << 8 | UInt64(bytes[i + k]) }
                dict[code, default: 0] += 1
            }
            pairs = dict.map { entry in
                var key = [UInt8](repeating: 0, count: n)
                var c = entry.key
                for k in stride(from: n - 1, through: 0, by: -1) { key[k] = UInt8(c & 0xFF); c >>= 8 }
                return (key, entry.value)
            }
        } else {
            var dict: [[UInt8]: Int] = [:]
            for i in 0..<total { dict[Array(bytes[i..<(i + n)]), default: 0] += 1 }
            pairs = dict.map { ($0.key, $0.value) }
        }
        pairs.sort { a, b in a.count != b.count ? a.count > b.count : a.key.lexicographicallyPrecedes(b.key) }
        let t = Double(total)
        return pairs.prefix(max(0, limit)).map {
            NGramEntry(gram: Hex.encode($0.key), count: $0.count, percent: Double($0.count) * 100 / t)
        }
    }

    // MARK: Autocorrelation

    /// CT1 "Autokorrelation": number of coincidences `x[i] == x[i+s]` (non-cyclic) for every shift
    /// `s = 1 … maxShift`. Element `k` of the result belongs to shift `k + 1`.
    ///
    /// CT1 plots the shifts `1 ..< min(count / 2, 200)`, see `defaultAutocorrelationMaxShift`.
    public static func autocorrelation(_ bytes: [UInt8], maxShift: Int) -> [Int] {
        autocorrelation(bytes.map { Int($0) }, maxShift: maxShift)
    }

    /// Autocorrelation of a text over its alphabet letters (CT1 does this for text documents:
    /// only characters of the alphabet are considered, case folded according to `options`).
    public static func autocorrelation(text: String, options: TextOptions, maxShift: Int) -> [Int] {
        autocorrelation(LetterTable(options: options).indices(text), maxShift: maxShift)
    }

    /// The largest shift CT1 displays for a document with `count` symbols: `min(count/2, 200) - 1`.
    public static func defaultAutocorrelationMaxShift(count: Int) -> Int {
        max(0, min(count / 2, 200) - 1)
    }

    static func autocorrelation(_ seq: [Int], maxShift: Int) -> [Int] {
        let n = seq.count
        guard maxShift >= 1 else { return [] }
        var out = [Int](repeating: 0, count: maxShift)
        seq.withUnsafeBufferPointer { p in
            for s in 1...maxShift where s < n {
                var c = 0
                for i in 0..<(n - s) where p[i] == p[i + s] { c += 1 }
                out[s - 1] = c
            }
        }
        return out
    }

    // MARK: Floating frequency

    /// CT1 "Gleitende Häufigkeit" (floating frequency): for every window of `window` consecutive
    /// bytes (default 64) the number of *different* byte values in that window
    /// (CT1 axis label: "Verschiedene Zeichen pro 64 Byte Block"). Element `i` belongs to the
    /// window starting at offset `i`; the result has `count - window + 1` elements
    /// (CT1 omitted the very last window). Empty if the data is shorter than the window.
    /// CT1 always works on the raw document bytes, also for text documents.
    public static func floatingFrequency(_ bytes: [UInt8], window: Int = 64) -> [Double] {
        guard window >= 1, bytes.count >= window else { return [] }
        var num = [Int](repeating: 0, count: 256)
        var distinct = 0
        for i in 0..<window {
            if num[Int(bytes[i])] == 0 { distinct += 1 }
            num[Int(bytes[i])] += 1
        }
        var out: [Double] = []
        out.reserveCapacity(bytes.count - window + 1)
        out.append(Double(distinct))
        if bytes.count > window {
            for i in window..<bytes.count {
                let old = Int(bytes[i - window])
                num[old] -= 1
                if num[old] == 0 { distinct -= 1 }
                let new = Int(bytes[i])
                if num[new] == 0 { distinct += 1 }
                num[new] += 1
                out.append(Double(distinct))
            }
        }
        return out
    }

    /// Entropy (bits/byte) in a sliding window – a variant of the floating frequency that CT1 had
    /// prepared in code (commented out). Element `i` belongs to the window starting at `i`.
    public static func floatingEntropy(_ bytes: [UInt8], window: Int = 64) -> [Double] {
        guard window >= 1, bytes.count >= window else { return [] }
        var num = [Int](repeating: 0, count: 256)
        let w = Double(window)
        // term[k] = -(k/w) log2(k/w)
        let term: [Double] = (0...window).map { k in k == 0 ? 0 : -(Double(k) / w) * log2(Double(k) / w) }
        var e = 0.0
        for i in 0..<window { num[Int(bytes[i])] += 1 }
        for c in num { e += term[c] }
        var out: [Double] = [e]
        if bytes.count > window {
            for i in window..<bytes.count {
                let old = Int(bytes[i - window])
                e -= term[num[old]]; num[old] -= 1; e += term[num[old]]
                let new = Int(bytes[i])
                e -= term[num[new]]; num[new] += 1; e += term[num[new]]
                out.append(max(0, e))
            }
        }
        return out
    }

    // MARK: Index of coincidence

    /// Index of coincidence κ = Σ nᵢ(nᵢ−1) / (N(N−1)) over the alphabet letters of `text`
    /// (≈ 0.0762 for German, ≈ 0.0667 for English, 1/26 ≈ 0.0385 for random A–Z text).
    public static func indexOfCoincidence(_ text: String, options: TextOptions) -> Double {
        let table = LetterTable(options: options)
        return indexOfCoincidence(indices: table.indices(text), alphabetSize: table.size)
    }

    /// Index of coincidence of a sequence of alphabet indices.
    public static func indexOfCoincidence(indices: [Int], alphabetSize: Int) -> Double {
        guard indices.count > 1, alphabetSize > 0 else { return 0 }
        var counts = [Int](repeating: 0, count: alphabetSize)
        for i in indices { counts[i] += 1 }
        return indexOfCoincidence(counts: counts)
    }

    /// Index of coincidence from absolute counts.
    public static func indexOfCoincidence(counts: [Int]) -> Double {
        let n = counts.reduce(0, +)
        guard n > 1 else { return 0 }
        var s = 0.0
        for c in counts { s += Double(c) * Double(c - 1) }
        return s / (Double(n) * Double(n - 1))
    }

    // MARK: Periodicity

    /// One period found by `periodicity`.
    public struct PeriodResult: Sendable, Equatable {
        /// 0-based offset where the periodic part starts (CT1 displays `offset + 1`).
        public let offset: Int
        /// Length of the period in bytes.
        public let length: Int
        /// Number of occurrences of the period from `offset` to the end of the data
        /// (CT1 column "Periodenzahl").
        public let repetitions: Int
        /// Content of one period (the last occurrence, `length` bytes; CT1 shows at most 20).
        public let pattern: [UInt8]
        public init(offset: Int, length: Int, repetitions: Int, pattern: [UInt8]) {
            self.offset = offset
            self.length = length
            self.repetitions = repetitions
            self.pattern = pattern
        }
    }

    /// CT1 "Periode" (Periodenanalyse, algorithm by H. Koy 2002): searches periodic repetitions
    /// at the *end* of the data. For gap = 1, 2, … ≤ count/2 the data is compared with itself
    /// shifted by `gap`, starting from the last byte. If at least one full period matches, a result
    /// is recorded and the search continues with the next larger (superordinate) period
    /// `gap = length · repetitions + 1`.
    ///
    /// Results are returned in CT1's display order: the outermost (longest) period first.
    /// At most `maxResults` (CT1: 100) periods are reported. Empty: "Keine Periodizität gefunden."
    public static func periodicity(_ bytes: [UInt8], maxResults: Int = 100,
                                   cancel: CancellationToken? = nil) -> [PeriodResult] {
        let n = bytes.count
        guard n >= 2 else { return [] }
        var results: [PeriodResult] = []
        var gap = 1
        var steps = 0
        bytes.withUnsafeBufferPointer { data in
            while gap <= n / 2 {
                steps += 1
                if steps & 0xFFF == 0, cancel?.isCancelled == true { break }
                var follow = n - 1
                var search = follow - gap
                while search >= 0 && data[follow] == data[search] {
                    follow -= 1
                    search -= 1
                }
                if n - follow > gap {
                    let length = follow - search
                    let repeated = (n - 1 - follow) / length
                    let offset = n - length * (repeated + 1)
                    let pattern = Array(data[(n - length)..<n])
                    results.append(PeriodResult(offset: offset, length: length, repetitions: repeated + 1, pattern: pattern))
                    if results.count >= maxResults { break }
                    gap = length * (repeated + 1) + 1
                } else {
                    gap += 1
                }
            }
        }
        return results.reversed()
    }
}
