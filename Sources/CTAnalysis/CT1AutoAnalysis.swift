import Foundation
import CTCommon

/// The ciphertext-only analyses "Caesar", "Vigenère", "XOR" and "Byteweise Addition" exactly as
/// CT1 computes them (AutomaticAnalysis.cpp: `CaesarAuto`, `VigenereAuto`, `XorAuto`, `AddAuto`,
/// libanalyse `Correlation`/`NGram`).
///
/// * Caesar / per Vigenère column: `DCorrelation(reference + 1, text)` – cyclic correlation of the
///   relative letter frequencies of the reference file (every symbol shifted by +1) with those of
///   the ciphertext; the first maximum ("FindPeak") is the proposed shift.
/// * Key length (Vigenère, XOR, ADD): autocorrelation `SCorrelation(text, min(N, 200))`; with
///   av = ⌊Σc[1…]/size⌋ and mx = ⌊max c[1…]⌋ the key length is the first shift p ≥ 1 with
///   c[p] > ⌊(av + mx)/2⌋ (or `size` if there is none).
/// * XOR / ADD key byte: the most frequent byte of the column (CT1 scans 255 … 0 with ">", so the
///   *largest* byte value wins ties) combined with the expected most frequent plaintext byte.
/// * An iterated key ("ABAB") is replaced by its period ("AB").
public enum CT1AutoAnalysis {

    // MARK: - CT1 texts

    /// IDS_STRING_ERR_INPUT_TEXT_LENGTH.
    public static func inputTooShortMessage(_ minimum: Int) -> String {
        "The input must contain at least \(minimum) (not necessarily different) character(s) from the current alphabet. The alphabet can be configured in Options \\ Text Options."
    }

    /// IDS_ERRON_OPEN_REFERENCE_FILE.
    public static let referenceFileError = "Error opening the reference file! Please select a valid reference file via the menu Options / Text Options."

    /// IDS_STRING_MSG_ON_CONVERT_KEY.
    public static func repeatedKeyMessage(_ key: String) -> String {
        "The key shows recurring elements and will be replaced by the equivalent key <\(key)>!"
    }

    /// IDS_CAESAR_ANALYSIS_REMARK, filled like `CDlgCaesarAnalysis::createKeyOffsetRemark`
    /// (`derived` = proposed key letter, the alternative is the next alphabet letter).
    public static func caesarKeyOffsetRemark(derivedKey: Character, alphabet: [Character]) -> String {
        let alt: String
        if let pos = alphabet.firstIndex(of: derivedKey), !alphabet.isEmpty {
            alt = String(alphabet[(pos + 1) % alphabet.count])
        } else {
            alt = alphabet.first.map { String($0) } ?? ""   // CT1: Find() = -1 → position 0
        }
        return "Because of the key offset which was used during encryption, there are two keys possible: For a key offset of 1 the key is '\(derivedKey)', for a key offset of 0 the key is '\(alt)'."
    }

    /// IDS_STRING_ASCERTAINED_KEY_CHARACTER.
    public static func ascertainedKeyCharacterMessage(position: Int, key: Character) -> String {
        "Calculated \(position)th key character: <\(key)>"
    }

    /// The four ciphertext-only analyses.
    public enum Kind: Sendable {
        case caesar, vigenere, xor, addition

        /// Title of CT1's message boxes / dialogs (IDS_STRING_ANALYSE_…).
        public var analysisTitle: String {
            switch self {
            case .caesar: return "Caesar Analysis"
            case .vigenere: return "Vigenère Analysis"
            case .xor: return "XOR Analysis"
            case .addition: return "Byte-by-byte Addition Analysis"
            }
        }

        /// Format of the result window title (IDS_STRING_AUTOMATIC_…_ANALYSE_OF), `%1` = document, `%2` = key.
        var resultFormat: String {
            switch self {
            case .caesar: return "Automatic Caesar Analysis of <%s>, key: <%s>"
            case .vigenere: return "Automatic Vigenère Analysis of <%s>, key: <%s>"
            case .xor: return "Automatic XOR Analysis of <%s>, key: <%s>"
            case .addition: return "Automatic Addition Analysis of <%s>, key: <%s>"
            }
        }

        /// Column name for the per-column windows ("Caesar %d von <%s>", "XOR %d von <%s>" …).
        public var columnName: String {
            switch self {
            case .caesar, .vigenere: return "Caesar"
            case .xor: return "XOR"
            case .addition: return "Byte-by-byte Addition"
            }
        }
    }

    /// CT1 `MakeNewName2(line, 256, format, key, title)`: `format` has two `%s` (document, key);
    /// if the result would not fit into CT1's 256-byte buffer, the key is cut and "..." appended.
    public static func makeNewName2(_ format: String, document: String, key: String, bufferLength: Int = 256) -> String {
        func fill(_ k: String) -> String {
            var out = ""
            var args = [document, k][...]
            var rest = Substring(format)
            while let r = rest.range(of: "%s") {
                out += rest[..<r.lowerBound]
                out += args.popFirst() ?? ""
                rest = rest[r.upperBound...]
            }
            return out + rest
        }
        if format.count + key.count + document.count < bufferLength { return fill(key) }
        let remain = bufferLength - (format.count + document.count + 4)
        return fill(remain > 0 ? String(key.prefix(remain)) + "..." : "...")
    }

    /// Result window title, e.g. "Automatische Caesar-Analyse von <doc>, Schlüssel: <K>".
    public static func resultTitle(_ kind: Kind, document: String, key: String) -> String {
        if kind == .caesar { return makeNewName2(kind.resultFormat, document: document, key: "Key: <\(key)>") }
        return makeNewName2(kind.resultFormat, document: document, key: key)
    }

    /// CT1's key display for XOR / ADD (`sprintf(" %02.2X")` per byte without the leading blank): "1A 2B".
    public static func hexKeyString(_ key: [UInt8]) -> String {
        key.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - Autocorrelation and key length

    /// `SCorrelation(text, min(N, 200))`: c[k] = number of positions i (0 ≤ i < N − k) with
    /// s[i] = s[i + k], for k = 0 … size − 1 (c[0] = N). Returns nil if cancelled.
    public static func autocorrelation(_ seq: [Int], maxSize: Int = 200, cancel: CancellationToken? = nil,
                                       progress: ((Double) -> Void)? = nil) -> [Int]? {
        let n = seq.count
        let size = min(n, maxSize)
        guard size > 0 else { return [] }
        var c = [Int](repeating: 0, count: size)
        c[0] = n
        let ok: Bool = seq.withUnsafeBufferPointer { p in
            for k in 1..<max(size, 1) {
                if cancel?.isCancelled == true { return false }
                var cnt = 0
                var i = 0
                let end = n - k
                while i < end {
                    if p[i] == p[i + k] { cnt += 1 }
                    i += 1
                }
                c[k] = cnt
                if let progress, k % 5 == 0 { progress(Double(k) / Double(size)) }
            }
            return true
        }
        return ok ? c : nil
    }

    /// Byte variant of `autocorrelation(_:)`.
    public static func autocorrelation(bytes: [UInt8], maxSize: Int = 200, cancel: CancellationToken? = nil,
                                       progress: ((Double) -> Void)? = nil) -> [Int]? {
        autocorrelation(bytes.map { Int($0) }, maxSize: maxSize, cancel: cancel, progress: progress)
    }

    /// CT1's key length rule (see type documentation). `c` is the full array incl. c[0].
    public static func keyLength(autocorrelation c: [Int]) -> Int {
        let size = c.count
        guard size >= 2 else { return 1 }
        // GetAverage(1): sum of c[1…size-1] divided by the *full* size (CT1 quirk), truncated
        let av = Int(Double(c[1...].reduce(0, +)) / Double(size))
        let mx = c[1...].max() ?? 0
        let s = (av + mx) / 2
        for p in 1..<size where c[p] > s { return p }
        return size
    }

    /// Values as CT1 plots them in "Autokorrelation von <…>" (shifts 1 … size−1). Relative values are
    /// given in percent of the text length (CT1's standalone autocorrelation; the automatic analyses
    /// of CT1 divide by min(N, 200) instead, which yields values above 100 %).
    public static func autocorrelationPlotValues(_ c: [Int], textLength: Int, relative: Bool) -> [Double] {
        guard c.count > 1 else { return [] }
        return c[1...].map { relative ? Double($0) * 100 / Double(max(1, textLength)) : Double($0) }
    }

    // MARK: - Caesar correlation

    /// Letter counts (alphabet indices) of `seq`.
    public static func counts(_ seq: [Int], symbolCount: Int) -> [Int] {
        var h = [Int](repeating: 0, count: max(0, symbolCount))
        for s in seq where s >= 0 && s < symbolCount { h[s] += 1 }
        return h
    }

    /// Counts of column `column` (positions column, column + period, …).
    public static func columnCounts(_ seq: [Int], period: Int, column: Int, symbolCount: Int) -> [Int] {
        var h = [Int](repeating: 0, count: max(0, symbolCount))
        guard period > 0 else { return h }
        var i = column
        while i < seq.count {
            let s = seq[i]
            if s >= 0 && s < symbolCount { h[s] += 1 }
            i += period
        }
        return h
    }

    /// `DCorrelation(d, t)` with d = NGram(reference + 1), t = NGram(text): value k (0 ≤ k < n) is
    /// Σᵢ d[i]·t[(i + k) mod n] over the relative frequencies, summed in CT1's order (bit-identical).
    public static func caesarCorrelation(textCounts: [Int], referenceCounts: [Int]) -> [Double] {
        let n = min(textCounts.count, referenceCounts.count)
        guard n > 0 else { return [] }
        let rt = referenceCounts.prefix(n).reduce(0, +)
        let tt = textCounts.prefix(n).reduce(0, +)
        // reference += 1: symbol s becomes s + 1, so d[i] is the frequency of reference symbol i − 1
        let d: [Double] = (0..<n).map { rt == 0 ? 0 : Double(referenceCounts[($0 - 1 + n) % n]) / Double(rt) }
        let t: [Double] = (0..<n).map { tt == 0 ? 0 : Double(textCounts[$0]) / Double(tt) }
        return (0..<n).map { k in
            var cor = 0.0
            for i in 0..<n { cor += d[i] * t[(i + k) % n] }
            return cor
        }
    }

    /// `FindPeak()` = `GetMaxPos()`: first maximum.
    public static func findPeak(_ v: [Double]) -> Int {
        guard !v.isEmpty else { return 0 }
        var pos = 0
        for i in 1..<v.count where v[i] > v[pos] { pos = i }
        return pos
    }

    /// Caesar: alphabet index of the proposed key letter (CT1 shows it for key offset 1, i.e. the
    /// text is decrypted by `keyIndex + 1`).
    public static func caesarKeyIndex(textCounts: [Int], referenceCounts: [Int]) -> Int {
        findPeak(caesarCorrelation(textCounts: textCounts, referenceCounts: referenceCounts))
    }

    /// Vigenère: key letter index (key letter A = shift 0) of column `column`:
    /// `alphabet[(FindPeak + 1) % n]`.
    public static func vigenereKeyIndex(_ seq: [Int], period: Int, column: Int, referenceCounts: [Int]) -> Int {
        let n = referenceCounts.count
        guard n > 0 else { return 0 }
        let col = columnCounts(seq, period: period, column: column, symbolCount: n)
        return (caesarKeyIndex(textCounts: col, referenceCounts: referenceCounts) + 1) % n
    }

    /// Complete Vigenère key (letter indices) for a given period.
    public static func vigenereKey(_ seq: [Int], period: Int, referenceCounts: [Int]) -> [Int] {
        (0..<max(0, period)).map { vigenereKeyIndex(seq, period: period, column: $0, referenceCounts: referenceCounts) }
    }

    // MARK: - XOR / ADD

    /// Byte counts of column `column`.
    public static func byteColumnCounts(_ data: [UInt8], period: Int, column: Int) -> [Int] {
        var h = [Int](repeating: 0, count: 256)
        guard period > 0 else { return h }
        var i = column
        while i < data.count { h[Int(data[i])] += 1; i += period }
        return h
    }

    /// CT1: `for(j=255;j>=0;j--) if (ng[j]>m) …` – the largest byte among equally frequent ones.
    /// An empty column keeps `previous` (CT1 keeps the value of the previous column).
    public static func mostFrequentByte(_ counts: [Int], previous: Int = 0) -> Int {
        var best = previous
        var m = 0
        for j in stride(from: min(255, counts.count - 1), through: 0, by: -1) where counts[j] > m {
            m = counts[j]; best = j
        }
        return best
    }

    /// XOR / ADD key for a given period and expected most frequent plaintext byte.
    public static func byteKey(_ data: [UInt8], period: Int, expected: UInt8, xor: Bool) -> [UInt8] {
        var key: [UInt8] = []
        var shift = 0
        for i in 0..<max(0, period) {
            shift = mostFrequentByte(byteColumnCounts(data, period: period, column: i), previous: shift)
            let s = UInt8(shift)
            key.append(xor ? s ^ expected : s &- expected)
        }
        return key
    }

    // MARK: - Iterated keys

    /// CT1's check for an iterated key: the smallest i (1 ≤ i < n, n mod i = 0) with
    /// key[0..<n−i] = key[i..<n]. Returns the reduced key, or nil if the key is not iterated.
    public static func reducedKey<T: Equatable>(_ key: [T]) -> [T]? {
        let n = key.count
        guard n > 1 else { return nil }
        for i in 1..<n where n % i == 0 {
            if key[0..<(n - i)].elementsEqual(key[i..<n]) { return Array(key[0..<i]) }
        }
        return nil
    }
}
