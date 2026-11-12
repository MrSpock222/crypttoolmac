import Foundation
import CTCommon

/// Statistical tests for (pseudo) random data (CT1 "Analyse ▸ Zufallsanalyse").
///
/// The tests follow the Handbook of Applied Cryptography, section 5.4.4, as CT1 does
/// (RandomTest.cpp). Bits are taken most significant bit first. A test is passed if the statistic
/// does not exceed the χ² quantile for the significance level `alpha` (CT1 offers 0.01, 0.05,
/// 0.10; default 0.05). Unlike CT1 (which by default repeated every test ten times on random
/// sections of the file) the tests are evaluated once on the complete data.
public enum RandomnessTests {

    /// Result of one test.
    public struct TestResult: Sendable {
        /// Test name (e.g. "Frequency-Test").
        public let name: String
        /// Value of the test statistic.
        public let statistic: Double
        /// Maximum allowed value (χ² quantile or FIPS limit).
        public let threshold: Double
        /// True if the data passed the test.
        public let passed: Bool
        /// Human readable details (German).
        public let details: String
        public init(name: String, statistic: Double, threshold: Double, passed: Bool, details: String) {
            self.name = name
            self.statistic = statistic
            self.threshold = threshold
            self.passed = passed
            self.details = details
        }
    }

    /// Significance levels offered by CT1.
    public static let alphaLevels: [Double] = [0.01, 0.05, 0.10]

    /// Minimum data size accepted by the CT1 test dialogs.
    public static let minimumByteCount = 16

    // MARK: HAC 5.4.4 tests

    /// Frequency (monobit) test: X₁ = (n₀ − n₁)² / n, χ² with 1 degree of freedom.
    public static func frequencyTest(_ bytes: [UInt8], alpha: Double = 0.05) -> TestResult {
        let name = "Frequency-Test"
        if let r = tooShort(name, bytes) { return r }
        let n = bytes.count * 8
        var ones = 0
        for b in bytes { ones += b.nonzeroBitCount }
        let zeros = n - ones
        let d = Double(zeros - ones)
        let x = d * d / Double(n)
        return chiResult(name, x, df: 1, alpha: alpha,
                         info: "Bits: \(n), Nullen: \(zeros), Einsen: \(ones)")
    }

    /// Serial (two-bit) test:
    /// X₂ = 4/(n−1)·(n₀₀²+n₀₁²+n₁₀²+n₁₁²) − 2/n·(n₀²+n₁²) + 1, χ² with 2 degrees of freedom.
    public static func serialTest(_ bytes: [UInt8], alpha: Double = 0.05) -> TestResult {
        let name = "Serial-Test"
        if let r = tooShort(name, bytes) { return r }
        let bits = bitArray(bytes)
        let n = bits.count
        var n1 = 0
        var pairs = [0, 0, 0, 0]
        for i in 0..<n {
            n1 += Int(bits[i])
            if i + 1 < n { pairs[Int(bits[i]) * 2 + Int(bits[i + 1])] += 1 }
        }
        let n0 = n - n1
        let sp = pairs.reduce(0.0) { $0 + Double($1) * Double($1) }
        let x = 4.0 / Double(n - 1) * sp - 2.0 / Double(n) * (Double(n0) * Double(n0) + Double(n1) * Double(n1)) + 1
        return chiResult(name, x, df: 2, alpha: alpha,
                         info: "n00: \(pairs[0]), n01: \(pairs[1]), n10: \(pairs[2]), n11: \(pairs[3])")
    }

    /// Poker test with non-overlapping blocks of `m` bits (k = ⌊n/m⌋ blocks):
    /// X₃ = 2^m/k · Σ nᵢ² − k, χ² with 2^m − 1 degrees of freedom.
    /// CT1's dialog default is m = 3 (tuple size 1 … 4 selectable; FIPS uses 4).
    public static func pokerTest(_ bytes: [UInt8], m: Int = 3, alpha: Double = 0.05) -> TestResult {
        let name = "Poker-Test"
        if let r = tooShort(name, bytes) { return r }
        let mm = max(1, min(m, 16))
        let bits = bitArray(bytes)
        let k = bits.count / mm
        guard k > 0 else { return TestResult(name: name, statistic: 0, threshold: 0, passed: false, details: "Zu wenige Daten.") }
        var counts = [Int](repeating: 0, count: 1 << mm)
        for b in 0..<k {
            var v = 0
            for j in 0..<mm { v = v << 1 | Int(bits[b * mm + j]) }
            counts[v] += 1
        }
        let sum = counts.reduce(0.0) { $0 + Double($1) * Double($1) }
        let x = Double(1 << mm) / Double(k) * sum - Double(k)
        var info = "Tupelgröße m = \(mm), Blöcke k = \(k)"
        if k < 5 * (1 << mm) { info += " (empfohlen: k ≥ 5·2^m = \(5 * (1 << mm)))" }
        return chiResult(name, x, df: (1 << mm) - 1, alpha: alpha, info: info)
    }

    /// Runs test: counts blocks (runs of ones) Bᵢ and gaps (runs of zeros) Gᵢ of length exactly
    /// i = 1 … k with the expected value eᵢ = (n − i + 3) / 2^(i+2);
    /// X₄ = Σ (Bᵢ − eᵢ)²/eᵢ + Σ (Gᵢ − eᵢ)²/eᵢ, χ² with 2k − 2 degrees of freedom.
    /// `maxRunLength` = k (CT1 default 3; HAC suggests the largest i with eᵢ ≥ 5).
    public static func runsTest(_ bytes: [UInt8], alpha: Double = 0.05, maxRunLength: Int = 3) -> TestResult {
        let name = "Runs-Test"
        if let r = tooShort(name, bytes) { return r }
        let k = max(2, maxRunLength)
        let (blocks, gaps, _) = runCounts(bitArray(bytes), maxLength: k)
        let n = Double(bytes.count * 8)
        var x = 0.0
        var info = "Länge | Blöcke | Lücken | erwartet\n"
        for i in 1...k {
            let e = (n - Double(i) + 3) / pow(2, Double(i + 2))
            let b = Double(blocks[i]), g = Double(gaps[i])
            x += (b - e) * (b - e) / e + (g - e) * (g - e) / e
            info += "\(i) | \(blocks[i]) | \(gaps[i]) | \(fmt(e, 1))\n"
        }
        return chiResult(name, x, df: 2 * k - 2, alpha: alpha, info: info.trimmingCharacters(in: .newlines))
    }

    /// Long-run test: fails if a run (of zeros or ones) of length ≥ `maxRun` occurs
    /// (CT1/FIPS 140-1 default 34). `statistic` = longest run, `passed` = statistic < threshold.
    public static func longRunTest(_ bytes: [UInt8], maxRun: Int = 34) -> TestResult {
        let name = "Long-Runs-Test"
        if let r = tooShort(name, bytes) { return r }
        let (_, _, longest) = runCounts(bitArray(bytes), maxLength: 1)
        let passed = longest < maxRun
        return TestResult(name: name, statistic: Double(longest), threshold: Double(maxRun), passed: passed,
                          details: "Maximaler Testwert: \(maxRun)\nLängster Run: \(longest)\n" + verdict(name, passed))
    }

    // MARK: FIPS PUB 140-1

    /// FIPS PUB 140-1 test battery on the first 20 000 bits (2500 bytes): monobit, poker (m = 4),
    /// runs and long-run test with the fixed FIPS limits. With fewer than 2500 bytes a single
    /// failed result with an explanation is returned.
    public static func fips140_1(_ bytes: [UInt8]) -> [TestResult] {
        guard bytes.count >= 2500 else {
            return [TestResult(name: "FIPS-PUB-140-1", statistic: Double(bytes.count), threshold: 2500, passed: false,
                               details: "Die FIPS-PUB-140-1 Testbatterie analysiert nach Spezifikation genau 2.500 Bytes. "
                                   + "Die Daten umfassen nur \(bytes.count) Bytes. Der Test kann deshalb nicht ausgeführt werden!")]
        }
        let data = Array(bytes.prefix(2500))
        let bits = bitArray(data)
        var results: [TestResult] = []

        // Monobit
        let ones = data.reduce(0) { $0 + $1.nonzeroBitCount }
        let monoPassed = ones > 9654 && ones < 10346
        results.append(TestResult(name: "Mono-Bit-Test", statistic: Double(ones), threshold: 10346, passed: monoPassed,
                                  details: "Anzahl Einsen: \(ones) (erlaubt: 9654 < X < 10346)\n" + verdict("Mono-Bit-Test", monoPassed)))

        // Poker m = 4
        var counts = [Int](repeating: 0, count: 16)
        for b in 0..<5000 {
            var v = 0
            for j in 0..<4 { v = v << 1 | Int(bits[b * 4 + j]) }
            counts[v] += 1
        }
        let x3 = 16.0 / 5000.0 * counts.reduce(0.0) { $0 + Double($1) * Double($1) } - 5000
        let pokerPassed = x3 > 1.03 && x3 < 57.4
        results.append(TestResult(name: "Poker-Test", statistic: x3, threshold: 57.4, passed: pokerPassed,
                                  details: "Testwert: \(fmt(x3, 4)) (erlaubt: 1,03 < X < 57,4)\n" + verdict("Poker-Test", pokerPassed)))

        // Runs
        let (blocks, gaps, longest) = runCounts(bits, maxLength: 6, aggregateLast: true)
        let bounds: [(Int, Int)] = [(2267, 2733), (1079, 1421), (502, 748), (223, 402), (90, 223), (90, 223)]
        var violations = 0
        var info = "Länge | Blöcke | Lücken | erlaubt\n"
        for i in 1...6 {
            let (lo, hi) = bounds[i - 1]
            if blocks[i] < lo || blocks[i] > hi { violations += 1 }
            if gaps[i] < lo || gaps[i] > hi { violations += 1 }
            info += "\(i == 6 ? "6+" : String(i)) | \(blocks[i]) | \(gaps[i]) | \(lo) … \(hi)\n"
        }
        let runsPassed = violations == 0
        results.append(TestResult(name: "Runs-Test", statistic: Double(violations), threshold: 0, passed: runsPassed,
                                  details: info + "Abweichungen: \(violations)\n" + verdict("Runs-Test", runsPassed)))

        // Long run
        let longPassed = longest < 34
        results.append(TestResult(name: "Long-Runs-Test", statistic: Double(longest), threshold: 34, passed: longPassed,
                                  details: "Längster Run: \(longest) (erlaubt: < 34)\n" + verdict("Long-Runs-Test", longPassed)))
        return results
    }

    // MARK: Vitányi

    /// Result of the Vitányi analysis (see `vitanyi`).
    public struct VitanyiResult: Sendable {
        /// Plotted values: normalised minimal triangle area divided by `mean`, for the point counts
        /// from 10 % of the data on (CT1 diagram "Vitányi-Diagramm", x axis "Eckpunkte").
        public let series: [Double]
        /// Number of the first point represented by `series[0]` (x axis offset).
        public let firstPoint: Int
        /// Mean of the normalised values ("Durchschnitt").
        public let mean: Double
        /// Standard deviation divided by the mean ("Variation").
        public let variation: Double
        /// Number of points (pairs of 32-bit words) evaluated.
        public let pointCount: Int
        /// True if three (almost) collinear points were found and the analysis stopped early –
        /// a strong sign of non-random data.
        public let degenerate: Bool
        public init(series: [Double], firstPoint: Int, mean: Double, variation: Double, pointCount: Int, degenerate: Bool) {
            self.series = series
            self.firstPoint = firstPoint
            self.mean = mean
            self.variation = variation
            self.pointCount = pointCount
            self.degenerate = degenerate
        }
    }

    /// CT1 "Vitányi" ("Dreieckeverfahren", Deutsche Bank 1998–2001): the first ≤ 8192 bytes are read
    /// as little-endian 32-bit words, consecutive pairs form points in the unit square. For every
    /// new point the minimal area of all triangles formed by the points so far is computed and
    /// scaled by the cube of the point index (for random points the minimal triangle area of k
    /// points shrinks like 1/k³ – Heilbronn's triangle problem, analysed by Vitányi et al. with
    /// Kolmogorov complexity). For good random data the plotted normalised values stay close to 1
    /// with small variation. O(k³) with k ≤ 1024 points.
    public static func vitanyi(_ bytes: [UInt8], cancel: CancellationToken? = nil) -> VitanyiResult {
        let len = min(bytes.count, 8192)
        guard len >= 9 else {
            return VitanyiResult(series: [], firstPoint: 0, mean: 0, variation: 0, pointCount: 0, degenerate: false)
        }
        let datalen = (len - 1) & ~7
        var ldl = datalen / 4
        var words = [Double](repeating: 0, count: ldl)
        for w in 0..<ldl {
            let b = w * 4
            words[w] = Double(UInt32(bytes[b]) | UInt32(bytes[b + 1]) << 8 | UInt32(bytes[b + 2]) << 16 | UInt32(bytes[b + 3]) << 24)
        }
        let maxU = Double(UInt32.max)
        var minArea = maxU * maxU
        var result: [Double] = []
        var degenerate = false
        var i = 4
        words.withUnsafeBufferPointer { ld in
            while i < ldl {
                if (i & 63) == 0, cancel?.isCancelled == true { break }
                let ax = ld[i], ay = ld[i + 1]
                var j = 2
                while j < i {
                    let bx = ld[j], by = ld[j + 1]
                    var k = 0
                    while k < j {
                        let cx = ld[k], cy = ld[k + 1]
                        // CalcTriangle(a = point i, b = point j, c = point k): twice the area
                        let t = abs((bx - ax) * (by + ay) + (cx - bx) * (by + cy) - (cx - ax) * (cy + ay))
                        if t < minArea { minArea = t }
                        if minArea < 0.0001 { ldl = i }
                        k += 2
                    }
                    j += 2
                }
                let di = Double(i)
                result.append(minArea * di * di * di / maxU / maxU * 0.5)
                if minArea < 0.0001 { degenerate = true }
                i += 2
            }
        }
        let resultlen = result.count
        guard resultlen > 0 else {
            return VitanyiResult(series: [], firstPoint: 0, mean: 0, variation: 0, pointCount: 0, degenerate: degenerate)
        }
        let start = resultlen / 10
        var m = 0.0
        for v in result[start...] { m += v }
        let mean = m / (Double(resultlen) * 0.9)
        var v = 0.0
        for x in result[start...] { v += (x - mean) * (x - mean) }
        let sd = sqrt(v / (Double(resultlen) * 0.9))
        let series = mean > 0 ? result[start...].map { $0 / mean } : Array(result[start...])
        return VitanyiResult(series: series, firstPoint: start + 3, mean: mean, variation: mean > 0 ? sd / mean : 0,
                             pointCount: resultlen + 2, degenerate: degenerate)
    }

    // MARK: χ² distribution

    /// Regularised lower incomplete gamma function P(a, x).
    public static func regularizedGammaP(_ a: Double, _ x: Double) -> Double {
        guard x > 0, a > 0 else { return 0 }
        let lnPre = a * log(x) - x - lgamma(a)
        if x < a + 1 {
            // series
            var sum = 1.0 / a
            var term = sum
            var ap = a
            for _ in 0..<10_000 {
                ap += 1
                term *= x / ap
                sum += term
                if abs(term) < abs(sum) * 1e-16 { break }
            }
            return min(1, sum * exp(lnPre))
        } else {
            // continued fraction (modified Lentz) for Q(a, x)
            let tiny = 1e-300
            var b = x + 1 - a
            var c = 1 / tiny
            var d = 1 / b
            var h = d
            for i in 1..<10_000 {
                let an = -Double(i) * (Double(i) - a)
                b += 2
                d = an * d + b
                if abs(d) < tiny { d = tiny }
                c = b + an / c
                if abs(c) < tiny { c = tiny }
                d = 1 / d
                let del = d * c
                h *= del
                if abs(del - 1) < 1e-16 { break }
            }
            return max(0, 1 - exp(lnPre) * h)
        }
    }

    /// Cumulative distribution function of the χ² distribution with `df` degrees of freedom.
    public static func chiSquareCDF(_ x: Double, df: Int) -> Double {
        regularizedGammaP(Double(df) / 2, x / 2)
    }

    /// Quantile of the χ² distribution: the x with CDF(x) = p (e.g. p = 0.95 → critical value for
    /// α = 0.05). χ²(0.95; 1) = 3.8415, χ²(0.95; 15) = 24.9958.
    public static func chiSquareQuantile(_ p: Double, df: Int) -> Double {
        guard df > 0, p > 0 else { return 0 }
        guard p < 1 else { return .infinity }
        var lo = 0.0
        var hi = max(1.0, Double(df))
        while chiSquareCDF(hi, df: df) < p { hi *= 2; if hi > 1e12 { break } }
        for _ in 0..<200 {
            let mid = (lo + hi) / 2
            if chiSquareCDF(mid, df: df) < p { lo = mid } else { hi = mid }
            if hi - lo < 1e-12 * max(1, hi) { break }
        }
        return (lo + hi) / 2
    }

    /// Critical value of a χ² test for significance level `alpha`.
    public static func chiSquareThreshold(alpha: Double, df: Int) -> Double {
        chiSquareQuantile(1 - alpha, df: df)
    }

    // MARK: helpers

    static func bitArray(_ bytes: [UInt8]) -> [UInt8] {
        var bits = [UInt8](repeating: 0, count: bytes.count * 8)
        for (i, b) in bytes.enumerated() {
            for j in 0..<8 { bits[i * 8 + j] = (b >> (7 - j)) & 1 }
        }
        return bits
    }

    /// Counts runs of exactly length i (1…maxLength; if `aggregateLast`, index maxLength counts all
    /// runs ≥ maxLength). Returns (blocks = runs of ones, gaps = runs of zeros, longest run).
    static func runCounts(_ bits: [UInt8], maxLength: Int, aggregateLast: Bool = false) -> ([Int], [Int], Int) {
        var blocks = [Int](repeating: 0, count: maxLength + 1)
        var gaps = [Int](repeating: 0, count: maxLength + 1)
        var longest = 0
        guard !bits.isEmpty else { return (blocks, gaps, 0) }
        var run = 1
        func record(_ bit: UInt8, _ len: Int) {
            longest = max(longest, len)
            var idx = len
            if len > maxLength {
                guard aggregateLast else { return }
                idx = maxLength
            }
            if bit == 1 { blocks[idx] += 1 } else { gaps[idx] += 1 }
        }
        for i in 1..<bits.count {
            if bits[i] == bits[i - 1] { run += 1 } else { record(bits[i - 1], run); run = 1 }
        }
        record(bits[bits.count - 1], run)
        return (blocks, gaps, longest)
    }

    private static func tooShort(_ name: String, _ bytes: [UInt8]) -> TestResult? {
        guard bytes.count < minimumByteCount else { return nil }
        return TestResult(name: name, statistic: 0, threshold: 0, passed: false,
                          details: "Die Daten müssen mindestens \(minimumByteCount) Bytes groß sein!")
    }

    private static func verdict(_ name: String, _ passed: Bool) -> String {
        passed ? "\(name) bestanden!" : "\(name) nicht bestanden!"
    }

    private static func chiResult(_ name: String, _ x: Double, df: Int, alpha: Double, info: String) -> TestResult {
        let t = chiSquareThreshold(alpha: alpha, df: df)
        let passed = x <= t
        let details = "Signifikanzniveau α = \(fmt(alpha, 2)), Freiheitsgrade: \(df)\n"
            + "Maximaler Testwert: \(fmt(t, 4))\nTestergebnis: \(fmt(x, 4))\n"
            + info + "\n" + verdict(name, passed)
        return TestResult(name: name, statistic: x, threshold: t, passed: passed, details: details)
    }
}
