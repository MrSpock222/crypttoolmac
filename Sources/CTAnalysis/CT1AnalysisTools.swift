import Foundation
import CTCommon

// CT1 parity helpers for "Analyse ▸ Werkzeuge" (Entropie, N-Gramm, Periode) and
// "Analyse ▸ Zufallsanalyse" (Frequency/Poker/Serial/Runs-Test, FIPS-PUB-140-1, 3D-Visualisierung).
// Everything here reproduces CT1's own computations (RandomTest.cpp, DlgStatRandTests.cpp,
// DlgNGramAnalysis.cpp, DlgPeriodicityAnalysis.cpp, StreamToVolume.cpp) including their quirks,
// so that the numbers shown match the Windows version.

// MARK: - Number formatting

/// CT1 number formatting. The separators are language resources in CT1; the English program
/// uses "," as thousands separator (IDS_STRING_PT) and a decimal point (IDS_STRING_COMMA).
public enum CT1Format {
    /// `itoa_fmt`: integer with "," as thousands separator ("12,345").
    public static func integer(_ v: Int) -> String {
        let digits = String(abs(v))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (v < 0 ? "-" : "") + out
    }

    /// `double_fmt`: integer part with thousands separators, decimal point and `decimals`
    /// *truncated* (not rounded) decimals, e.g. "4.69" for 4.6999.
    public static func double(_ x: Double, decimals: Int) -> String {
        guard x.isFinite else { return String(x) }
        let prec = min(max(decimals, 0), 9)
        var s = integer(Int(floor(x)))
        guard prec > 0 else { return s }
        let a = abs(x)
        let frac = a - floor(a) + 1.0
        let i = Int(frac * pow(10.0, Double(prec)))
        var f = String(i)
        f.removeFirst()
        s += "." + f
        return s
    }

    /// C `%lf` / `%f` (6 decimals, decimal point) as used in CT1's test dialogs.
    public static func cDouble(_ x: Double) -> String { String(format: "%f", x) }
}

// MARK: - Random tests

/// CT1's statistical random tests (RandomTest.cpp) with the dialog logic of DlgStatRandTests.cpp.
public enum CT1RandomTests {
    /// Significance levels offered by CT1 (TEST-Param.ini, ALPHA_LIST); default "0.05".
    public static let alphaLevels = ["0.01", "0.05", "0.10"]
    public static let defaultAlpha = "0.05"

    /// χ² table of TEST-Param.ini: entries 1…10 are the quantiles for 1…10 degrees of freedom,
    /// entries 11…14 those for 15, 20, 30 and 255 degrees of freedom.
    static let table: [String: [Double]] = [
        "0.01": [6.635, 9.210, 11.340, 13.280, 15.090, 16.810, 18.480, 20.090, 21.670, 23.210, 30.580, 37.570, 50.890, 310.400],
        "0.05": [3.841, 5.991, 7.815, 9.488, 11.070, 12.590, 14.070, 15.510, 16.920, 18.310, 25.000, 31.410, 43.770, 293.200],
        "0.10": [2.705, 4.605, 6.251, 7.779, 9.236, 10.640, 12.010, 13.360, 14.680, 15.980, 22.300, 28.410, 40.250, 284.300],
    ]

    /// `CParseIniFile2::GetAlphaParam(alpha, index)`: the `index`-th table entry (1-based); 0 if
    /// the index lies outside the table (CT1 then reads the "\end" line and returns 0).
    public static func quantile(alpha: String, index: Int) -> Double {
        guard let t = table[alpha], index >= 1, index <= t.count else { return 0 }
        return t[index - 1]
    }

    /// The tests of the "Frequency/Poker/Serial" dialog (IDD_FRQ_TEST) and the Runs dialog.
    public enum Kind: Sendable, Equatable {
        case frequency
        case serial
        /// Poker test with tuple size 1…4 (CT1 default 3).
        case poker(tupel: Int)
        /// Runs test with maximal run length (CT1 "Run-Länge", default 3).
        case runs(runLength: Int)

        /// Index into the quantile table used by CT1: Frequency 1, Serial 2, Poker 2^m − 1 (15 → 11,
        /// i.e. the χ²(15) entry), Runs: the run length itself (CT1's Runs dialog passes
        /// `m_Runlang` instead of 2k − 2).
        public var quantileIndex: Int {
            switch self {
            case .frequency: return 1
            case .serial: return 2
            case .poker(let m):
                let d = (1 << max(1, min(m, 4))) - 1
                return d == 15 ? 11 : d
            case .runs(let k): return k
            }
        }

        /// CT1 test names (IDS_STRING_TEST_FREQ …).
        public var name: String {
            switch self {
            case .frequency: return "Frequency test"
            case .serial: return "Serial test"
            case .poker: return "Poker test"
            case .runs: return "Runs test"
            }
        }
    }

    /// Outcome of one test run as shown in CT1's "Teststatus" box.
    public struct Outcome: Sendable, Equatable {
        public let passed: Bool
        /// "Maximaler Testwert" (χ² quantile from TEST-Param.ini).
        public let threshold: Double
        /// "Testergebnis" (statistic of the last evaluated block).
        public let statistic: Double
        /// Number of evaluated blocks (1, or up to 10 with random blocks).
        public let blocks: Int

        /// "%s bestanden!" / "%s nicht bestanden!".
        public func verdict(_ name: String) -> String { passed ? "\(name) passed!" : "\(name) failed!" }
        /// IDS_STRING_TESTS_ERGEBNIS_INFO: "Maximaler Testwert: %lf\nTestergebnis: %lf".
        public var info: String { "Maximal test value: \(CT1Format.cDouble(threshold))\nTest result: \(CT1Format.cDouble(statistic))" }
    }

    // MARK: Statistics (exact ports)

    /// `bitt(x, bit)` of RandomTest.h on a *signed* char: `((x >> (7 - bit)) & 1)`. For bit = 8 the
    /// x86 shift count wraps to 31, i.e. the result is the sign bit (= MSB) of the byte.
    @inline(__always)
    static func bitt(_ b: UInt8, _ bit: Int) -> Int {
        if bit >= 8 { return Int(b >> 7) }
        return Int((b >> UInt8(7 - bit)) & 1)
    }

    /// Frequency test statistic X₁ = (n₀ − n₁)² / n over `length` bytes from `offset`.
    public static func frequencyStatistic(_ d: [UInt8], offset: Int, length: Int) -> (statistic: Double, ones: Int, zeros: Int) {
        var ones = 0
        let end = min(d.count, offset + length)
        if offset < end { for i in offset..<end { ones += d[i].nonzeroBitCount } }
        let n = max(0, end - offset) * 8
        let zeros = n - ones
        let diff = Double(zeros - ones)
        return (n > 0 ? diff * diff / Double(n) : 0, ones, zeros)
    }

    /// Serial test exactly as CT1's `Serial_Test::test` counts the bits: least significant bit
    /// first; in the first byte bit 1 is counted twice and bit 7 is skipped.
    public static func serialStatistic(_ d: [UInt8], offset: Int, length: Int) -> Double {
        var n0 = 0.0, n1 = 0.0, n00 = 0.0, n01 = 0.0, n10 = 0.0, n11 = 0.0
        var temp = 2, flag = 0
        var n = 0
        var pos = offset
        while n < length {
            var ch = pos < d.count ? Int(d[pos]) : 0
            pos += 1
            n += 1
            flag = 1
            var i = 1
            while i <= 8 {
                if temp == 2 {
                    if i > 2 { ch /= 2 }
                    if ch % 2 == 1 {
                        n1 += 1; ch /= 2; i += 1
                        if ch % 2 == 1 { n1 += 1; n11 += 1; temp = 1 } else { n0 += 1; n10 += 1; temp = 0 }
                    } else {
                        n0 += 1; ch /= 2; i += 1
                        if ch % 2 == 1 { n1 += 1; n01 += 1; temp = 1 } else { n0 += 1; n00 += 1; temp = 0 }
                    }
                } else if temp == 1 {
                    if flag == 0 { ch /= 2 }
                    flag = 0
                    if ch % 2 == 1 { n1 += 1; n11 += 1 } else { n0 += 1; n10 += 1; temp = 0 }
                } else {
                    if flag == 0 { ch /= 2 }
                    flag = 0
                    if ch % 2 == 1 { n1 += 1; n01 += 1; temp = 1 } else { n0 += 1; n00 += 1 }
                }
                i += 1
            }
        }
        let nb = Double(n * 8)
        return 4 * (n00 * n00 + n01 * n01 + n10 * n10 + n11 * n11) / (nb - 1) - 2 * (n0 * n0 + n1 * n1) / nb + 1
    }

    /// Poker test statistic X₃ = 2^m / k · Σ nᵢ² − k over non-overlapping m-bit tuples
    /// (k = ⌊8·length / m⌋).
    public static func pokerStatistic(_ d: [UInt8], offset: Int, length: Int, tupel: Int) -> Double {
        let m = max(1, min(tupel, 8))
        var z = [Double](repeating: 0, count: 1 << m)
        let total = length * 8
        let k = (total - total % m) / m
        guard k > 0 else { return 0 }
        var bitIndex = 0
        for _ in 0..<k {
            var v = 0
            for i in 0..<m {
                let p = offset + (bitIndex >> 3)
                let b = p < d.count ? d[p] : 0
                v += bitt(b, bitIndex & 7) << i
                bitIndex += 1
            }
            z[v] += 1
        }
        let sum = z.reduce(0) { $0 + $1 * $1 }
        return Double(1 << m) / Double(k) * sum - Double(k)
    }

    /// Number of maximal runs of exactly `length` ones (`ones` = true, "Blöcke") or zeros
    /// ("Lücken") in `count` bytes from `offset`, most significant bit first
    /// (`Runs_Test::zaehle_luck_block`).
    public static func runCount(_ d: [UInt8], offset: Int, count: Int, length: Int, ones: Bool) -> Int {
        var result = 0
        var run = 0
        let end = min(d.count, offset + count)
        guard offset < end else { return 0 }
        for p in offset..<end {
            let b = d[p]
            for bit in 0..<8 {
                let v = (b >> UInt8(7 - bit)) & 1 == 1
                if v == ones { run += 1 } else {
                    if run == length { result += 1 }
                    run = 0
                }
            }
        }
        if run == length { result += 1 }
        return result
    }

    /// Runs test statistic Σ (Bᵢ − eᵢ)²/eᵢ + (Gᵢ − eᵢ)²/eᵢ, i = 1…k, eᵢ = (n − i + 3)/2^(i+2).
    public static func runsStatistic(_ d: [UInt8], offset: Int, length: Int, runLength k: Int) -> Double {
        var s1 = 0.0, s2 = 0.0
        guard k >= 1 else { return 0 }
        for i in 1...k {
            let b = Double(runCount(d, offset: offset, count: length, length: i, ones: true))
            let l = Double(runCount(d, offset: offset, count: length, length: i, ones: false))
            let e = Double(length * 8 - i + 3) / pow(2, Double(i + 2))
            s1 += (b - e) * (b - e) / e
            s2 += (l - e) * (l - e) / e
        }
        return s1 + s2
    }

    /// Longest run as CT1's `Long_Run_Test::longrun` determines it (always over the *whole* data,
    /// also inside the FIPS battery). Faithful to CT1: the last byte and the final run are not
    /// evaluated, and a run crossing a byte boundary only continues if the previous byte's most
    /// significant bit equals the run's bit value (CT1 evaluates `bitt(ch, 8)` as the sign bit).
    public static func longestRun(_ d: [UInt8]) -> Int {
        let total = d.count
        var pos = 0
        var ch: UInt8 = 0
        func get() { if pos < total { ch = d[pos] }; pos += 1 }
        var run = 0, bit = 0, longest = 0, i = 0
        var flag = 2
        while i < total {
            if flag == 2 { get(); i += 1 }
            if !(i < total) { break }
            if bit >= 8 {
                get(); i += 1
                if !(i < total) { break }
                bit = 0
            }
            while bitt(ch, bit) == 1 {
                if flag == 0 { if longest < run { longest = run }; run = 0 }
                flag = 1
                if bit >= 8 {
                    get(); i += 1
                    if !(i < total) { break }   // C: leaves only the inner loop
                    bit = 0
                    continue
                }
                run += 1; bit += 1
            }
            while bitt(ch, bit) == 0 {
                if flag == 1 { if longest < run { longest = run }; run = 0 }
                flag = 0
                if bit >= 8 {
                    get(); i += 1
                    if !(i < total) { break }   // C: leaves only the inner loop
                    bit = 0
                    continue
                }
                run += 1; bit += 1
            }
        }
        return longest
    }

    // MARK: Dialog logic

    /// CT1 RAND_RANGE.
    static let randRange = 10240

    /// Runs a test like CT1's `OnButtonFreqtest` / `OnTestbutton`:
    /// - `useDefaults` ("Default-Offset und -Testlänge"): whole data, otherwise `offset`/`length`;
    /// - `randomBlocks` ("Zufällige Blöcke aus der Datei verwenden"): ten runs on random sections
    ///   (offset + rand()%10240, length ± rand()%10240, as CT1), stopping at the first failure.
    /// Returns nil if offset/length are invalid (CT1: "Falsche Offset/Testlänge!").
    public static func run<R: RandomNumberGenerator>(_ kind: Kind, data d: [UInt8], alpha: String,
                                                     useDefaults: Bool, offset: Int, length: Int,
                                                     randomBlocks: Bool, using rng: inout R) -> Outcome? {
        let total = d.count
        if !useDefaults && (offset < 0 || length <= 0 || offset + length > total) { return nil }
        if length <= 0 && !useDefaults { return nil }
        if case .runs(let k) = kind, !useDefaults, k <= 0 { return nil }
        let offs = useDefaults ? 0 : offset
        let testlen = useDefaults ? total : length
        let threshold = quantile(alpha: alpha, index: kind.quantileIndex)
        let passes = randomBlocks ? 10 : 1
        var passed = true
        var statistic = 0.0
        var blocks = 0
        for _ in 0..<passes {
            var anf = offs, bis = testlen
            if randomBlocks && total > 0 {
                func r() -> Int { Int.random(in: 0..<randRange, using: &rng) }
                // Frequency/Poker: retry while anf+bis ≥ L or bis ≤ 12; Serial/Runs: while anf+bis > L
                // (with def: length − rand, unsigned in CT1).
                let strictKind: Bool
                switch kind { case .frequency, .poker: strictKind = true; default: strictKind = false }
                var tries = 0
                repeat {
                    anf = (offs + r()) % total
                    if strictKind || !useDefaults {
                        bis = (testlen + r()) % total
                    } else {
                        let v = UInt32(truncatingIfNeeded: testlen &- r())
                        bis = Int(v % UInt32(total))
                    }
                    tries += 1
                    let bad = strictKind ? (anf + bis >= total || bis <= 12) : (anf + bis > total || bis == 0)
                    if !bad { break }
                    if tries > 100_000 { anf = offs; bis = testlen; break }
                } while true
            }
            switch kind {
            case .frequency: statistic = frequencyStatistic(d, offset: anf, length: bis).statistic
            case .serial: statistic = serialStatistic(d, offset: anf, length: bis)
            case .poker(let m): statistic = pokerStatistic(d, offset: anf, length: bis, tupel: m)
            case .runs(let k): statistic = runsStatistic(d, offset: anf, length: bis, runLength: k)
            }
            blocks += 1
            if !(statistic <= threshold) { passed = false; break }
        }
        return Outcome(passed: passed, threshold: threshold, statistic: statistic, blocks: blocks)
    }

    /// Convenience with the system random generator.
    public static func run(_ kind: Kind, data: [UInt8], alpha: String, useDefaults: Bool = true,
                           offset: Int = 0, length: Int = 0, randomBlocks: Bool = false) -> Outcome? {
        var g = SystemRandomNumberGenerator()
        return run(kind, data: data, alpha: alpha, useDefaults: useDefaults, offset: offset,
                   length: length > 0 ? length : data.count, randomBlocks: randomBlocks, using: &g)
    }

    /// True longest run of equal bits (zeros or ones) in `count` bytes from `offset`.
    public static func longestRunCorrect(_ d: [UInt8], offset: Int = 0, count: Int? = nil) -> Int {
        let end = min(d.count, offset + (count ?? d.count))
        guard offset < end else { return 0 }
        var longest = 0, run = 0
        var last: UInt8 = 2
        for p in offset..<end {
            let b = d[p]
            for bit in 0..<8 {
                let v = (b >> UInt8(7 - bit)) & 1
                if v == last { run += 1 } else { run = 1; last = v }
                if run > longest { longest = run }
            }
        }
        return longest
    }

    /// Long-Runs test of the Runs dialog: passed if the longest run is shorter than `maxRun`
    /// (CT1 default 34). Info: "Maximaler Testwert: %d\nLängster Run: %d".
    /// Deviation: uses the true longest run (`longestRunCorrect`). CT1's `longestRun` ignores the
    /// last byte and the final run, so e.g. a file of zero bytes passed in CT1.
    public static func longRunTest(_ d: [UInt8], maxRun: Int = 34) -> (passed: Bool, longest: Int, info: String) {
        let l = longestRunCorrect(d)
        return (l < maxRun, l, "Maximal test value: \(maxRun)\nLongest Run: \(l)")
    }

    // MARK: FIPS PUB 140-1

    /// Result of CT1's FIPS-PUB-140-1 battery (CDlgFIPSTest140_1::OnBatterietest).
    public struct FIPSResult: Sendable, Equatable {
        /// Entropy of the whole data in bit per byte (CT1 shows it with 3 truncated decimals).
        public let entropy: Double
        public let monobitOnes: Int
        public let monobitPassed: Bool
        public let longestRun: Int
        public let longRunPassed: Bool
        public let pokerStatistic: Double
        public let pokerPassed: Bool
        /// Blocks/gaps for run lengths 1…5 and ≥ 6 (6…33).
        public let runBlocks: [Int]
        public let runGaps: [Int]
        public let runsPassed: Bool
        public var batteryPassed: Bool { monobitPassed && longRunPassed && pokerPassed && runsPassed }

        /// CT1 lines.
        public var entropyLine: String { "Entropy: \(CT1Format.double(entropy, decimals: 3)) bit/character" }
        public var longRunLine: String { longRunPassed ? "Longrun Test passed!" : "Longrun Test failed!" }
        public var monobitLine: String { monobitPassed ? "Mono-Bit Test passed!" : "Mono-Bit Test failed!" }
        public var pokerLine: String { pokerPassed ? "Poker-Test passed!" : "Poker Test failed!" }
        public var runsLine: String { runsPassed ? "Runs Test passed!" : "Runs Test failed!" }
        public var batteryLine: String { batteryPassed ? "Test battery passed!" : "Test battery failed!" }
    }

    /// FIPS-PUB-140-1 battery on the first 2500 bytes.
    /// Requires at least 2500 bytes.
    public static func fips140_1(_ d: [UInt8]) -> FIPSResult? {
        guard d.count >= 2500 else { return nil }
        let ones = frequencyStatistic(d, offset: 0, length: 2500).ones
        // CT1 evaluated the long run over the whole file with its faulty `longestRun`; FIPS (and
        // CT1's own message) specify the first 2500 bytes.
        let longest = longestRunCorrect(d, offset: 0, count: 2500)
        let poker = pokerStatistic(d, offset: 0, length: 2500, tupel: 4)
        let limits: [(Int, Int)] = [(2267, 2733), (1079, 1421), (502, 748), (223, 402), (90, 223), (90, 223)]
        var blocks: [Int] = [], gaps: [Int] = []
        for i in 1...5 {
            blocks.append(runCount(d, offset: 0, count: 2500, length: i, ones: true))
            gaps.append(runCount(d, offset: 0, count: 2500, length: i, ones: false))
        }
        var b6 = 0, g6 = 0
        for i in 6...33 {
            b6 += runCount(d, offset: 0, count: 2500, length: i, ones: true)
            g6 += runCount(d, offset: 0, count: 2500, length: i, ones: false)
        }
        blocks.append(b6); gaps.append(g6)
        var ok = 0
        for i in 0..<6 where blocks[i] >= limits[i].0 && blocks[i] <= limits[i].1 && gaps[i] >= limits[i].0 && gaps[i] <= limits[i].1 { ok += 1 }
        return FIPSResult(entropy: Statistics.entropy(bytes: d),
                          monobitOnes: ones, monobitPassed: ones > 9654 && ones < 10346,
                          longestRun: longest, longRunPassed: longest < 34,
                          pokerStatistic: poker, pokerPassed: poker > 1.03 && poker < 57.4,
                          runBlocks: blocks, runGaps: gaps, runsPassed: ok == 6)
    }
}

// MARK: - N-gram list (DlgNGramAnalysis.cpp)

/// CT1's N-Gramm-Liste.
public enum CT1NGram {
    /// CT1 analyses at most 2^20 bytes.
    public static let maxBytes = 1_048_576

    public struct Entry: Sendable, Equatable {
        /// The n-gram as symbols (characters for text, byte values for binary data).
        public let symbols: [UInt32]
        public let count: Int
        /// Relative frequency (count / number of registered n-grams).
        public let relative: Double
    }

    public struct Result: Sendable {
        public let n: Int
        public let binary: Bool
        /// Sorted by count (descending), ties by symbol values (CT1 `memcmp`).
        public let entries: [Entry]
        /// Number of registered n-grams (CT1 `hashed`).
        public let total: Int
        /// Number of different n-grams (CT1 `getIndividuals`).
        public var individuals: Int { entries.count }

        /// Display string of an entry: text n-gram, or "AB, CD" for binary data.
        public func label(_ e: Entry) -> String {
            if binary { return e.symbols.map { String(format: "%02X", $0) }.joined(separator: ", ") }
            return String(String.UnicodeScalarView(e.symbols.compactMap { Unicode.Scalar($0) }))
        }
    }

    /// Text n-grams as CT1 registers them: a–z are converted to A–Z unless case is distinguished,
    /// every other character must be part of the alphabet literally; a character outside the
    /// alphabet interrupts the sequence (n-grams never span it).
    public static func text(_ text: String, n: Int, options: TextOptions) -> Result {
        let alphabet = Set(options.alphabet.unicodeScalars.map(\.value))
        var seq: [UInt32] = []
        var grams: [[UInt32]: Int] = [:]
        var total = 0
        var processed = 0
        for s in text.unicodeScalars {
            processed += 1
            if processed > maxBytes { break }
            var v = s.value
            if !options.distinguishCase && v >= 97 && v <= 122 { v -= 32 }
            if alphabet.contains(v) {
                if seq.count < n { seq.append(v) } else { seq.removeFirst(); seq.append(v) }
                if seq.count >= n { grams[seq, default: 0] += 1; total += 1 }
            } else {
                seq.removeAll(keepingCapacity: true)
            }
        }
        return make(grams, total: total, n: n, binary: false)
    }

    /// Overlapping byte n-grams (CT1 "N-Gramm" of a hex window).
    public static func binary(_ bytes: [UInt8], n: Int) -> Result {
        var grams: [[UInt32]: Int] = [:]
        let data = bytes.count > maxBytes ? Array(bytes.prefix(maxBytes)) : bytes
        var total = 0
        if data.count >= n && n > 0 {
            for i in 0...(data.count - n) {
                grams[data[i..<(i + n)].map { UInt32($0) }, default: 0] += 1
                total += 1
            }
        }
        return make(grams, total: total, n: n, binary: true)
    }

    private static func make(_ grams: [[UInt32]: Int], total: Int, n: Int, binary: Bool) -> Result {
        let entries = grams.map { Entry(symbols: $0.key, count: $0.value, relative: total > 0 ? Double($0.value) / Double(total) : 0) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.symbols.lexicographicallyPrecedes(b.symbols)
            }
        return Result(n: n, binary: binary, entries: entries, total: total)
    }

    /// Method prefix used in titles: "Histogramm-", "Digramm-", "Trigramm-", "%i-Gramm-".
    public static func method(n: Int, freeN: Bool) -> String {
        if !freeN {
            switch n { case 1: return "Histogram"; case 2: return "Digram"; case 3: return "Trigram"; default: break }
        }
        return "\(n) Gram"
    }

    /// Content of the document written by "Liste speichern" (CT1 format).
    public static func listDocument(_ r: Result, rows: Int, method: String, title: String, fileSize: Int) -> String {
        func pad(_ s: String, _ w: Int) -> String { s.count >= w ? s : String(repeating: " ", count: w - s.count) + s }
        var out = "\(method) Analysis of <\(title)>. File size \(fileSize) bytes.\n"
        out += "Descending sorted on frequency.\n\n"
        let substr = "Substring"
        var wd = substr.count
        if r.binary { wd = wd > r.n * 3 - 1 ? wd + 2 : r.n * 3 + 1 } else { wd = wd > r.n ? wd + 2 : r.n + 2 }
        out += pad("No.", 5) + "\t" + pad(substr, wd) + "\t" + pad("Frequency (in %)", 12) + "\t" + "Frequency\n"
        for (i, e) in r.entries.prefix(max(0, rows)).enumerated() {
            out += pad(String(i + 1), 5) + "\t"
            out += pad(r.label(e), wd) + "\t"
            out += pad(String(format: "%.4f", e.relative * 100), 15) + "\t"
            out += pad("\t", 7)
            out += "\(e.count)\n"
        }
        return out
    }
}

// MARK: - Periodicity list (DlgPeriodicityAnalysis.cpp)

public enum CT1Periodicity {
    /// CT1 PA_MAXPRINTLENGTH.
    public static let maxPrint = 20

    /// CT1 `IsText`: printable characters are shown, others as ".".
    static func printable(_ b: UInt8) -> Character {
        (b >= 0x20 && b < 0x7F) ? Character(Unicode.Scalar(b)) : "."
    }

    /// "Periodeninhalt" (at most 20 bytes).
    public static func text(_ r: Statistics.PeriodResult) -> String {
        String(r.pattern.prefix(maxPrint).map(printable))
    }

    /// "Periodeninhalt (Hex)": " 41 42 43" (every byte preceded by a space, as CT1's sprintf).
    public static func hex(_ r: Statistics.PeriodResult) -> String {
        r.pattern.prefix(maxPrint).map { String(format: " %02X", $0) }.joined()
    }

    /// Document of "Liste im Hauptfenster anzeigen"; `results` in display order (outermost first).
    public static func listDocument(_ results: [Statistics.PeriodResult], title: String) -> String {
        var out = "Periodicity analysis of \(title):\n"
        out += "No.\tOffset\tLength\tNumber of cycles\tCycle content\n"
        guard let first = results.first else { return out }
        let maxtxt = min(first.length, maxPrint)
        for (i, r) in results.enumerated() {
            out += "\(i + 1)\t\(r.offset + 1)\t\(r.length)\t\(r.repetitions)\t\t"
            out += text(r) + "\t"
            let tabs = (maxtxt - r.length + 7) / 8
            if tabs > 0 { out += String(repeating: "\t", count: tabs) }
            out += hex(r) + "\n"
        }
        return out
    }
}

// MARK: - 3D visualisation (StreamToVolume.cpp)

/// CT1's volume data for "3D-Visualisierung": the differences of consecutive words (1, 2 or 4
/// bytes, little endian) shifted by `shift` % of the cube and scaled to `resolution`; three
/// consecutive differences give a voxel whose brightness grows by `density` (modulo 256, as CT1).
public enum CT1Volume {
    public static let defaultResolution = 128
    public static let defaultDensity = 127
    public static let defaultShift = 50
    public static let defaultWordLength = 4

    /// Returns the voxel buffer (resolution³ bytes, index x + y·res + z·res²).
    /// Deviation from CT1: a trailing incomplete word is ignored (CT1 discarded the whole last
    /// read buffer if the file length was not a multiple of the word length).
    public static func volume(_ data: [UInt8], resolution: Int = defaultResolution, density: Int = defaultDensity,
                              shiftPercent: Int = defaultShift, wordLength: Int = defaultWordLength) -> [UInt8] {
        let res = max(1, min(resolution, 255))
        let w = [1, 2, 4].contains(wordLength) ? wordLength : 4
        var buffer = [UInt8](repeating: 0, count: res * res * res)
        var shiftPx = res * shiftPercent / 100
        shiftPx = max(0, min(shiftPx, res))
        // StreamToVolume::setShift rejects values > dim/2 (then keeps dim/2)
        if shiftPx > res / 2 { shiftPx = res / 2 }
        let modulus: UInt64 = w == 4 ? 1 << 32 : (w == 2 ? 1 << 16 : 1 << 8)
        let scale = max(UInt64(1), modulus / UInt64(res))
        let words = data.count / w
        func word(_ i: Int) -> UInt64 {
            var v: UInt64 = 0
            for k in 0..<w { v |= UInt64(data[i * w + k]) << (8 * UInt64(k)) }
            return v
        }
        let chunk = 32768
        var voxel = [UInt64](repeating: 0, count: 3)
        var idx = 0
        let dens = UInt8(truncatingIfNeeded: density)
        var start = 0
        while start < words {
            let end = min(words, start + chunk)
            var ii = start + 1
            while ii < end {
                let diff = (word(ii) &+ (modulus - word(ii - 1)) &+ UInt64(shiftPx) * scale) % modulus
                voxel[idx] = diff
                idx = (idx + 1) % 3
                if idx == 0 {
                    var addr = 0, off = 1
                    for j in 0..<3 {
                        var v = Int(voxel[j] / scale)
                        if v >= res { v = res - 1 }
                        addr += v * off
                        off *= res
                    }
                    if density > 0 { buffer[addr] = buffer[addr] &+ dens }
                }
                ii += 1
            }
            start = end
        }
        return buffer
    }
}
