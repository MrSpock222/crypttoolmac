import Foundation
import CTCommon

/// CT1 "Halbautomatische Analyse von ADFGVX" (Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸
/// Ciphertext-Only ▸ ADFGVX), ported from CT1's `adfgvx.cpp` (analysis functions) and
/// `DlgAdfgvxManual.cpp`.
///
/// Workflow as in CT1:
/// 1. **Stage 2 (transposition)**: all transposition passwords of the selected length range are tried
///    by brute force. The candidates are the permutations of the first *n* letters "AB…" in
///    lexicographic order (`std::next_permutation`). For every candidate the transposition is undone
///    and the ADFGVX bigrams of stage 1 are counted. A candidate is accepted ("good enough") if the
///    most frequent bigram reaches the frequency of the most frequent letter of the reference text
///    (in percent, minus 1). Pressing "Analysieren" again continues the search after the last found
///    password.
/// 2. **Stage 1 (substitution)**: for an accepted password the substitution matrix is pre-filled by
///    frequency matching: the bigrams sorted by frequency receive the letters of the reference text
///    sorted by frequency (CT1 default without reference text: "ENISR"). All other cells stay "*".
///    The user completes the matrix by hand; unassigned bigrams appear as ADFGVX pairs in the
///    plaintext, assigned ones as lowercase plaintext characters.
public struct ADFGVXAnalysis: Sendable {
    /// Marker for an unassigned matrix cell (CT1 shows "*").
    public static let unassigned: Character = "*"
    /// The 36 matrix symbols A–Z, 0–9.
    public static let symbols: [Character] = ADFGVXCipher.symbols
    /// Labels of rows and columns.
    public static let labels: [Character] = ADFGVXCipher.labels

    /// Ciphertext symbols as indices 0…5 (A, D, F, G, V, X).
    public let cipherSymbols: [UInt8]
    /// Frequency ranking of the reference language (most frequent first).
    public var frequencyTable: [Character] = Array("ENISR")
    /// Acceptance threshold in percent for the most frequent stage-1 bigram (CT1 default 16 = E in German).
    public var highestFrequency: Int = 16

    /// Number of ADFGVX letters of the ciphertext.
    public var count: Int { cipherSymbols.count }

    /// Reads the ciphertext like CT1 (`adfgvx::readCiphertext`): whitespace is ignored, lowercase is
    /// accepted, every other character or an odd number of letters is rejected with CT1's message.
    public init(ciphertext: String) throws {
        var out: [UInt8] = []
        out.reserveCapacity(ciphertext.utf8.count)
        for ch in ciphertext {
            if ch.isWhitespace { continue }
            guard let i = ADFGVXAnalysis.labels.firstIndex(of: asciiUppercased(ch)) else {
                throw CTError(ADFGVXAnalysis.invalidCiphertextMessage)
            }
            out.append(UInt8(i))
        }
        guard out.count % 2 == 0 else { throw CTError(ADFGVXAnalysis.invalidCiphertextMessage) }
        cipherSymbols = out
    }

    /// CT1 IDS_STRING_ADFGVX_ERROR_10.
    public static let invalidCiphertextMessage = "The input text is not a valid AFXGVX ciphertext."

    // MARK: - Reference statistics (CDlgAdfgvxManual::SetFrequenciesFromReference)

    /// Frequency ranking and acceptance threshold derived from a reference text.
    public struct ReferenceStatistics: Sendable, Equatable {
        /// Letters (and digits) of the reference text, most frequent first (only those that occur).
        public var letters: [Character]
        /// `Int(highest relative frequency · 100) − 1`.
        public var highestFrequency: Int
    }

    /// Counts A–Z (case-insensitive; with `includeDigits` also 0–9, CT1: if the CrypTool alphabet
    /// contains "0123456789") in the reference text. Returns nil if the text contains none of them.
    public static func referenceStatistics(_ text: String, includeDigits: Bool) -> ReferenceStatistics? {
        let rows = includeDigits ? 36 : 26
        var counts = [Int](repeating: 0, count: rows)
        var total = 0
        for u in text.utf8 {
            var v = Int(u)
            if v >= 97 && v <= 122 { v -= 32 }
            if v >= 65 && v <= 90 { counts[v - 65] += 1; total += 1 } else if includeDigits && v >= 48 && v <= 57 { counts[v - 48 + 26] += 1; total += 1 }
        }
        guard total > 0 else { return nil }
        var table = counts
        var letters: [Character] = []
        // repeatedly pick the highest remaining count (ties: lowest position), like CT1
        for _ in 0..<rows {
            var best = -1, max = 0
            for j in 0..<rows where table[j] > 0 && table[j] > max { best = j; max = table[j] }
            guard best >= 0 else { break }
            letters.append(symbols[best])
            table[best] = -1
        }
        let maxFreq = Double(counts.max() ?? 0) / Double(total)
        return ReferenceStatistics(letters: letters, highestFrequency: Int(maxFreq * 100) - 1)
    }

    /// Applies reference statistics (CT1 `adfgvx::SetFrequencyTable`, at most 36 characters).
    public mutating func setFrequencyTable(_ s: ReferenceStatistics) {
        frequencyTable = Array(s.letters.prefix(36))
        highestFrequency = s.highestFrequency
    }

    // MARK: - Transposition

    /// Column read order of a transposition password (columns sorted by character, stable).
    public static func columnOrder(_ password: String) -> [Int] {
        let k = Array(password.unicodeScalars.map(\.value))
        return k.indices.sorted { k[$0] != k[$1] ? k[$0] < k[$1] : $0 < $1 }
    }

    /// Undoes the transposition (CT1 `repermutation`); stage-1 symbols 0…5 in row order.
    public func stage1(password: String) -> [UInt8] {
        let order = ADFGVXAnalysis.columnOrder(password)
        let cols = order.count, n = cipherSymbols.count
        guard cols > 0 else { return [] }
        let start = ADFGVXAnalysis.columnStarts(order: order, length: n)
        var out = [UInt8](repeating: 0, count: n)
        var row = 0, col = 0
        for k in 0..<n {
            out[k] = cipherSymbols[start[col] + row]
            col += 1
            if col == cols { col = 0; row += 1 }
        }
        return out
    }

    /// Stage-1 text (ADFGVX letters) for a password.
    public func stage1Text(password: String) -> String {
        String(stage1(password: password).map { ADFGVXAnalysis.labels[Int($0)] })
    }

    private static func columnStarts(order: [Int], length n: Int) -> [Int] {
        let cols = order.count
        let rows = n / cols, extra = n % cols
        var start = [Int](repeating: 0, count: cols)
        var p = 0
        for c in order {
            start[c] = p
            p += rows + (c < extra ? 1 : 0)
        }
        return start
    }

    /// Bigram counts of stage 1 (index row·6 + column of the substitution matrix) – CT1 `countBigram`.
    public func bigramCounts(password: String) -> [Int] {
        var counts = [Int](repeating: 0, count: 36)
        let order = ADFGVXAnalysis.columnOrder(password)
        guard !order.isEmpty else { return counts }
        countBigrams(order: order, into: &counts)
        return counts
    }

    private func countBigrams(order: [Int], into counts: inout [Int]) {
        let cols = order.count
        let n = cipherSymbols.count
        let start = ADFGVXAnalysis.columnStarts(order: order, length: n)
        for i in 0..<36 { counts[i] = 0 }
        cipherSymbols.withUnsafeBufferPointer { c in
            start.withUnsafeBufferPointer { s in
                counts.withUnsafeMutableBufferPointer { cnt in
                    var row = 0, col = 0
                    var first = 0
                    for k in 0..<n {
                        let v = Int(c[s[col] + row])
                        if k & 1 == 0 { first = v } else { cnt[first * 6 + v] += 1 }
                        col += 1
                        if col == cols { col = 0; row += 1 }
                    }
                }
            }
        }
    }

    /// Relative bigram frequencies in percent as computed by CT1 (`count / chars · 2 · 100`).
    public func bigramFrequencies(_ counts: [Int]) -> [Float] {
        let chars = Float(max(cipherSymbols.count, 1))
        return counts.map { Float($0) / chars * 2 * 100 }
    }

    /// CT1 `goodenough`: the most frequent bigram reaches `highestFrequency` percent.
    public func isGoodEnough(_ counts: [Int]) -> Bool {
        guard !cipherSymbols.isEmpty else { return false }
        let top = Float(counts.max() ?? 0) / Float(cipherSymbols.count) * 2 * 100
        return !(top < Float(highestFrequency))
    }

    /// Substitution matrix pre-filled by frequency matching (CT1 `goodenough`): the bigrams sorted by
    /// decreasing frequency (ties: matrix order) receive the characters of `frequencyTable`.
    public func frequencyMatrix(_ counts: [Int]) -> [[Character]] {
        var m = ADFGVXAnalysis.emptyMatrix
        let ranking = (0..<36).sorted { counts[$0] != counts[$1] ? counts[$0] > counts[$1] : $0 < $1 }
        for (i, ch) in frequencyTable.prefix(36).enumerated() {
            let idx = ranking[i]
            m[idx / 6][idx % 6] = ch
        }
        return m
    }

    /// CT1 "Übernehmen" (`ForcePassword`): matrix pre-filled for the given password, accepted or not.
    public func forcedMatrix(password: String) -> [[Character]] {
        frequencyMatrix(bigramCounts(password: password))
    }

    /// CT1 `resubstitution`: assigned bigrams become the lowercase matrix character, unassigned
    /// ones ("*") stay as the two ADFGVX letters.
    public func plaintext(password: String, matrix: [[Character]]) -> String {
        let s = stage1(password: password)
        var out = String()
        out.reserveCapacity(s.count)
        var i = 0
        while i + 1 < s.count {
            let r = Int(s[i]), c = Int(s[i + 1])
            let ch = r < matrix.count && c < matrix[r].count ? matrix[r][c] : ADFGVXAnalysis.unassigned
            if ch == ADFGVXAnalysis.unassigned {
                out.append(ADFGVXAnalysis.labels[r]); out.append(ADFGVXAnalysis.labels[c])
            } else {
                out += String(ch).lowercased()
            }
            i += 2
        }
        return out
    }

    // MARK: - Password search (CT1 adfgvx::nextPassword)

    public struct SearchResult: Sendable {
        /// Found password ("" if none was found in the range, CT1 semantics).
        public var password: String
        /// Pre-filled substitution matrix for the found password.
        public var matrix: [[Character]]?
        /// Number of tested candidates.
        public var tested: Int
        /// True if the search was cancelled (password is "" then).
        public var cancelled: Bool
    }

    /// Searches the next transposition password whose stage-1 bigram statistics are "good enough".
    ///
    /// Exactly CT1's loop: with an empty `start` the search begins with "A…" of length `minLength`;
    /// otherwise with `start` itself (if `start` is the last found password, with its lexicographic
    /// successor). Lengths increase up to `maxLength`.
    /// - Parameters:
    ///   - minLength, maxLength: password length range (1…26).
    ///   - lastPasswordFound: result of the previous search ("" if none).
    ///   - progress: (tested candidates, current length, fraction 0…1 of the remaining search space).
    public func searchNextPassword(minLength: Int, maxLength: Int, start: String, lastPasswordFound: String,
                                   cancel: CancellationToken? = nil,
                                   progress: (@Sendable (Int, Int, Double) -> Void)? = nil) -> SearchResult {
        let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var password: [Character] = []
        var length: Int
        var startSet: Bool
        if !start.isEmpty {
            length = start.count
            startSet = true
            password = Array(start)
        } else {
            length = max(1, minLength)
            startSet = false
        }
        // size of the search space (for the progress display)
        var space = 0.0
        var f = 1.0
        let first = max(1, length)
        for l in 1...max(first, min(26, maxLength)) {
            f *= Double(l)
            if l >= first { space += f }
        }
        var tested = 0
        var counts = [Int](repeating: 0, count: 36)
        var good = false
        var pwd = ""
        var cancelled = false
        outer: repeat {
            if startSet {
                startSet = false
                if lastPasswordFound == start { _ = ADFGVXAnalysis.nextPermutation(&password) }
            } else {
                password = Array(letters.prefix(length))
            }
            length += 1
            repeat {
                pwd = String(password)
                countBigrams(order: ADFGVXAnalysis.columnOrder(pwd), into: &counts)
                good = isGoodEnough(counts)
                tested += 1
                if tested & 2047 == 0 {
                    if cancel?.isCancelled == true { cancelled = true; break outer }
                    if tested & 32767 == 0 { progress?(tested, password.count, min(1, Double(tested) / max(space, 1))) }
                }
            } while !good && ADFGVXAnalysis.nextPermutation(&password)
        } while !good && password.count < maxLength
        if cancelled { return SearchResult(password: "", matrix: nil, tested: tested, cancelled: true) }
        progress?(tested, password.count, 1)
        guard good else { return SearchResult(password: "", matrix: nil, tested: tested, cancelled: false) }
        return SearchResult(password: pwd, matrix: frequencyMatrix(counts), tested: tested, cancelled: false)
    }

    /// `std::next_permutation`: rearranges into the lexicographically next permutation; returns false
    /// (and sorts ascending) if `a` was the last permutation.
    @discardableResult
    public static func nextPermutation(_ a: inout [Character]) -> Bool {
        guard a.count > 1 else { return false }
        var i = a.count - 2
        while i >= 0 && !(a[i] < a[i + 1]) { i -= 1 }
        if i < 0 { a.reverse(); return false }
        var j = a.count - 1
        while !(a[i] < a[j]) { j -= 1 }
        a.swapAt(i, j)
        a[(i + 1)...].reverse()
        return true
    }

    // MARK: - Input validation (adfgvx::CheckPassword / CleansePassword / LettersToNumbers)

    public enum PasswordCheck: Sendable, Equatable {
        case valid
        /// CT1 error 6: length must be > 0.
        case empty
        /// CT1 error 4: characters outside the CrypTool alphabet.
        case invalidCharacters
        /// CT1 error 7: repeated characters (CT1 then does nothing).
        case duplicateCharacters
    }

    public static func checkPassword(_ password: String, alphabet: String) -> PasswordCheck {
        if password.contains(where: { !alphabet.contains($0) }) { return .invalidCharacters }
        if Set(password).count != password.count { return .duplicateCharacters }
        return .valid
    }

    /// Removes characters that are not in the CrypTool alphabet.
    public static func cleansePassword(_ password: String, alphabet: String) -> String {
        String(password.filter { alphabet.contains($0) })
    }

    /// CT1 "Reihenfolge der Spalten", e.g. "CAB" → "-3-1-2-" ("" for an empty password).
    public static func numberedPassword(_ password: String) -> String {
        let p = Array(password.unicodeScalars.map(\.value))
        guard !p.isEmpty else { return "" }
        var numbers = [Int](repeating: 0, count: p.count)
        for current in 0..<p.count {
            for next in stride(from: current + 1, to: p.count, by: 1) {
                if p[current] > p[next] { numbers[current] += 1 } else { numbers[next] += 1 }
            }
        }
        return "-" + numbers.map { "\($0 + 1)-" }.joined()
    }

    // MARK: - Matrix helpers

    /// Matrix with all cells unassigned.
    public static var emptyMatrix: [[Character]] { Array(repeating: Array(repeating: unassigned, count: 6), count: 6) }

    /// CT1 "Standardmatrix" (A…Z, 0…9 row by row).
    public static var standardMatrix: [[Character]] { ADFGVXCipher.standardMatrix }

    /// CT1 "Noch nicht zugewiesene Zeichen".
    public static func remainingCharacters(_ matrix: [[Character]]) -> String {
        let used = Set(matrix.flatMap { $0 })
        return String(symbols.filter { !used.contains($0) })
    }

    /// CT1 "Verbleibende Möglichkeiten": (number of "*" cells)!, 0 if every cell is assigned.
    public static func remainingPossibilities(_ matrix: [[Character]]) -> Double {
        var stars = Double(matrix.flatMap { $0 }.filter { $0 == unassigned }.count)
        var remaining = stars
        while stars > 1 { stars -= 1; remaining *= stars }
        return remaining
    }

    /// CT1 "Zeichenkette eingeben": uppercase, duplicates removed, filled up with the remaining
    /// characters A–Z, 0–9 (row by row). Returns nil if the input contains no usable character.
    public static func matrix(fromString input: String) -> [[Character]]? {
        var seq: [Character] = []
        for ch in input {
            let u = asciiUppercased(ch)
            if symbols.contains(u) && !seq.contains(u) { seq.append(u) }
        }
        guard !seq.isEmpty else { return nil }
        for ch in symbols where !seq.contains(ch) { seq.append(ch) }
        return (0..<6).map { r in Array(seq[(r * 6)..<(r * 6 + 6)]) }
    }

    /// Key in the format of the Mac ADFGVX dialog: "<36 matrix characters> / <password>".
    public static func keyString(password: String, matrix: [[Character]]) -> String {
        "\(String(matrix.flatMap { $0 })) / \(password)"
    }

    /// Parses a key "<matrix36> / <password>" (Mac format) or "<password>, <matrix36>" (CT1 key store).
    public static func parseKey(_ key: String) -> (password: String, matrix: [[Character]])? {
        func matrix(_ s: Substring) -> [[Character]]? {
            let chars = Array(s.trimmingCharacters(in: .whitespaces)).map(asciiUppercased)
            guard chars.count == 36 else { return nil }
            return (0..<6).map { r in Array(chars[(r * 6)..<(r * 6 + 6)]) }
        }
        if let r = key.range(of: " / ") {
            if let m = matrix(key[..<r.lowerBound]) {
                return (key[r.upperBound...].trimmingCharacters(in: .whitespaces), m)
            }
        }
        if let r = key.firstIndex(of: ",") {
            if let m = matrix(key[key.index(after: r)...]) {
                return (String(key[..<r]).trimmingCharacters(in: .whitespaces), m)
            }
        }
        return nil
    }
}
