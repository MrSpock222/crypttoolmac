import CTCommon

/// Options of CT1's "Permutation / Transposition" (single or double columnar transposition).
public struct PermutationOptions: Codable, Equatable, Hashable, Sendable {
    /// Row-wise ("zeilenweise") or column-wise ("spaltenweise").
    public enum Direction: String, Codable, CaseIterable, Sendable {
        case rowWise, columnWise
        public var displayName: String { self == .rowWise ? "Line by line" : "Col by col" }
    }

    /// Settings of one permutation stage. CT1 default: read in row-wise, permute columns,
    /// read out column-wise (= classic columnar transposition).
    public struct Stage: Codable, Equatable, Hashable, Sendable {
        public var readIn: Direction
        /// `.columnWise` permutes the columns (default), `.rowWise` the rows.
        public var permute: Direction
        public var readOut: Direction

        public init(readIn: Direction = .rowWise, permute: Direction = .columnWise, readOut: Direction = .columnWise) {
            self.readIn = readIn
            self.permute = permute
            self.readOut = readOut
        }

        /// CT1 internal flags (Zin/Zout: 0 = row-wise, 1 = column-wise) as passed to DoPerm.
        var zin: Int { (readIn == .columnWise ? 1 : 0) ^ (permute == .columnWise ? 1 : 0) ^ 1 }
        var zout: Int { (readOut == .columnWise ? 1 : 0) ^ (permute == .columnWise ? 1 : 0) ^ 1 }
    }

    public var first: Stage
    public var second: Stage
    /// CT1 "Jeweils die inverse Permutation anwenden".
    public var applyInverse: Bool
    /// true: only the alphabet letters (text options) are permuted, other characters are re-inserted
    /// at their positions (CT1 "Text"); false: all characters are permuted (CT1 "Binäre Daten",
    /// the CT1 default).
    public var lettersOnly: Bool

    public init(first: Stage = Stage(), second: Stage = Stage(), applyInverse: Bool = false, lettersOnly: Bool = false) {
        self.first = first
        self.second = second
        self.applyInverse = applyInverse
        self.lettersOnly = lettersOnly
    }

    /// Convenience initialiser using the same settings for both stages.
    public init(readIn: Direction, permute: Direction, readOut: Direction, applyInverse: Bool = false, lettersOnly: Bool = false) {
        let s = Stage(readIn: readIn, permute: permute, readOut: readOut)
        self.init(first: s, second: s, applyInverse: applyInverse, lettersOnly: lettersOnly)
    }
}

/// CT1 permutation / (double) columnar transposition.
///
/// Keys are permutations written 1-based as in CT1's display: `key[i]` is the rank (read order) of
/// column i, e.g. the keyword "ZEBRAS" gives [6, 3, 2, 5, 1, 4]; "3,1,2" gives [3, 1, 2].
public struct PermutationCipher: Sendable {
    public static let maxKeyLength = 100

    public let firstKey: [Int]
    public let secondKey: [Int]?
    public let options: PermutationOptions

    /// Throws if a key is not a permutation of 1…n (n ≤ 100).
    public init(firstKey: [Int], secondKey: [Int]? = nil, options: PermutationOptions = .init()) throws {
        try PermutationCipher.validate(firstKey, name: "first")
        if let k = secondKey, !k.isEmpty { try PermutationCipher.validate(k, name: "second") }
        self.firstKey = firstKey
        self.secondKey = (secondKey?.isEmpty ?? true) ? nil : secondKey
        self.options = options
    }

    static func validate(_ key: [Int], name: String) throws {
        guard !key.isEmpty else { throw CTError("The \(name) permutation is empty.") }
        guard key.count <= maxKeyLength else {
            throw CTError("The \(name) permutation is too long (at most \(maxKeyLength) elements).")
        }
        var seen = [Bool](repeating: false, count: key.count)
        for v in key {
            guard v >= 1 && v <= key.count else {
                if v == 0 { throw CTError("The \(name) permutation contains a 0. Counting starts at 1.") }
                throw CTError("The value \(v) of the \(name) permutation is too large (allowed: 1…\(key.count)).")
            }
            guard !seen[v - 1] else { throw CTError("The value \(v) occurs more than once in the \(name) permutation.") }
            seen[v - 1] = true
        }
    }

    /// Permutation from a keyword (CT1/ADFGVX numbering: letters ranked alphabetically, equal
    /// letters left to right). CT1 uses the letters A–Z of the keyword (uppercased, max 100);
    /// the `options` are accepted for API symmetry – letters outside A–Z are ignored.
    public static func permutation(fromKeyword keyword: String, options: TextOptions = .default) -> [Int] {
        let letters = Array(keyword.map(asciiUppercased).filter { ($0.asciiValue.map { (65...90).contains($0) }) ?? false }.prefix(maxKeyLength))
        var p = [Int](repeating: 0, count: letters.count)
        for i in 0..<letters.count {
            for j in (i + 1)..<max(i + 1, letters.count) {
                if letters[i] > letters[j] { p[i] += 1 } else { p[j] += 1 }
            }
        }
        return p.map { $0 + 1 }
    }

    /// Parses "3,1,2" (numbers, 1-based) or a keyword. Returns nil for invalid input.
    public static func parsePermutation(_ s: String) -> [Int]? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return nil }
        if first.isNumber {
            let parts = t.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace })
            var out: [Int] = []
            for p in parts { guard let v = Int(p) else { return nil }; out.append(v) }
            return (try? validate(out, name: "")) != nil ? out : nil
        }
        let p = permutation(fromKeyword: t)
        return p.isEmpty ? nil : p
    }

    /// Inverse permutation (1-based).
    public static func inverse(of key: [Int]) -> [Int] {
        var inv = [Int](repeating: 0, count: key.count)
        for (i, v) in key.enumerated() where v >= 1 && v <= key.count { inv[v - 1] = i + 1 }
        return inv
    }

    /// CT1 display "( 3, 1, 2 )".
    public static func display(_ key: [Int]) -> String {
        key.count < 2 ? "( 1 )" : "( " + key.map(String.init).joined(separator: ", ") + " )"
    }

    // MARK: Core (CT1 DoPerm / DoInvPerm on generic arrays)

    /// `p` is CT1's 0-based column array (pinv for the normal case, p for "invert").
    static func doPerm<T>(_ src: [T], p: [Int], zin: Int, zout: Int) -> [T] {
        let len = src.count, plen = p.count
        guard len > 0, plen > 0 else { return src }
        var dest = src
        let rows = len / plen, last = len % plen
        var slen = [Int](repeating: rows, count: plen)
        for i in 0..<last { slen[i] = rows + 1 }
        var sstart = [Int](repeating: 0, count: plen)
        for i in 1..<max(1, plen) { sstart[i] = sstart[i - 1] + slen[i - 1] }
        let pres = p.filter { $0 < last }
        var pt = 0
        if zin == 0 {
            if zout == 1 {
                for i in 0..<plen { var k = p[i]; while k < len { dest[pt] = src[k]; pt += 1; k += plen } }
            } else {
                for _ in 0..<rows { for k in 0..<plen { dest[pt + k] = src[pt + p[k]] }; pt += plen }
                for i in 0..<last { dest[pt + i] = src[pt + pres[i]] }
            }
        } else {
            if zout == 1 {
                for i in 0..<plen { for k in 0..<slen[p[i]] { dest[pt + k] = src[sstart[p[i]] + k] }; pt += slen[p[i]] }
            } else {
                for i in 0..<rows { for k in 0..<plen { dest[pt] = src[sstart[p[k]] + i]; pt += 1 } }
                for i in 0..<last { dest[pt] = src[sstart[pres[i]] + rows]; pt += 1 }
            }
        }
        return dest
    }

    static func doInvPerm<T>(_ src: [T], p: [Int], zin: Int, zout: Int) -> [T] {
        let len = src.count, plen = p.count
        guard len > 0, plen > 0 else { return src }
        var dest = src
        let rows = len / plen, last = len % plen
        var slen = [Int](repeating: rows, count: plen)
        for i in 0..<last { slen[i] = rows + 1 }
        var sstart = [Int](repeating: 0, count: plen)
        for i in 1..<max(1, plen) { sstart[i] = sstart[i - 1] + slen[i - 1] }
        let pres = p.filter { $0 < last }
        var pt = 0
        if zin == 0 {
            if zout == 1 {
                for i in 0..<plen { var k = p[i]; while k < len { dest[k] = src[pt]; pt += 1; k += plen } }
            } else {
                for _ in 0..<rows { for k in 0..<plen { dest[pt + p[k]] = src[pt + k] }; pt += plen }
                for i in 0..<last { dest[pt + pres[i]] = src[pt + i] }
            }
        } else {
            if zout == 1 {
                for i in 0..<plen { for k in 0..<slen[p[i]] { dest[sstart[p[i]] + k] = src[pt + k] }; pt += slen[p[i]] }
            } else {
                for i in 0..<rows { for k in 0..<plen { dest[sstart[p[k]] + i] = src[pt]; pt += 1 } }
                for i in 0..<last { dest[sstart[pres[i]] + rows] = src[pt]; pt += 1 }
            }
        }
        return dest
    }

    /// CT1 array used by DoPerm: pinv (0-based) normally, p (0-based) with "apply inverse".
    private func workArray(_ key: [Int]) -> [Int] {
        options.applyInverse ? key.map { $0 - 1 } : PermutationCipher.inverse(of: key).map { $0 - 1 }
    }

    /// Permutes an arbitrary sequence (encryption).
    public func encrypt<T>(elements: [T]) -> [T] {
        var data = PermutationCipher.doPerm(elements, p: workArray(firstKey), zin: options.first.zin, zout: options.first.zout)
        if let k2 = secondKey {
            data = PermutationCipher.doPerm(data, p: workArray(k2), zin: options.second.zin, zout: options.second.zout)
        }
        return data
    }

    /// Inverse of `encrypt(elements:)`.
    public func decrypt<T>(elements: [T]) -> [T] {
        var data = elements
        if let k2 = secondKey {
            data = PermutationCipher.doInvPerm(data, p: workArray(k2), zin: options.second.zin, zout: options.second.zout)
        }
        return PermutationCipher.doInvPerm(data, p: workArray(firstKey), zin: options.first.zin, zout: options.first.zout)
    }

    /// Binary mode on raw bytes.
    public func encrypt(bytes: [UInt8]) -> [UInt8] { encrypt(elements: bytes) }
    /// Binary mode decryption.
    public func decrypt(bytes: [UInt8]) -> [UInt8] { decrypt(elements: bytes) }

    /// Encrypts text. With `options.lettersOnly` only alphabet letters are permuted (CT1 text mode,
    /// letters case-folded, non-alphabet characters and case re-inserted per position according to
    /// the text options); otherwise all characters are permuted.
    public func encrypt(_ text: String, textOptions: TextOptions) -> String {
        process(text, textOptions: textOptions, decrypt: false)
    }

    /// Decrypts text (inverse of `encrypt(_:textOptions:)`).
    public func decrypt(_ text: String, textOptions: TextOptions) -> String {
        process(text, textOptions: textOptions, decrypt: true)
    }

    private func process(_ text: String, textOptions: TextOptions, decrypt dec: Bool) -> String {
        if options.lettersOnly {
            let m = LetterMapper(textOptions)
            let idx = m.indices(of: text)
            let res = dec ? decrypt(elements: idx) : encrypt(elements: idx)
            return m.reformat(original: text, letters: res)
        }
        let chars = Array(text)
        return String(dec ? decrypt(elements: chars) : encrypt(elements: chars))
    }
}

/// Known-plaintext analysis of transpositions (CT1 "Transpositionsanalyse").
public enum TranspositionAnalysis {
    /// Finds all column permutations (1-based keys, see `PermutationCipher`) of length 1…`maxKeyLength`
    /// for which the single columnar transposition (read in row-wise, permute columns, read out
    /// column-wise; letters of the text options only) maps `plaintext` to `ciphertext`.
    /// Results are ordered by key length; at most `maxResults` keys are returned.
    public static func knownPlaintextSingleColumn(plaintext: String, ciphertext: String, options: TextOptions,
                                                  maxKeyLength: Int = 9, maxResults: Int = 100) -> [[Int]] {
        let m = LetterMapper(options)
        let p = m.indices(of: plaintext), c = m.indices(of: ciphertext)
        guard !p.isEmpty, p.count == c.count, p.sorted() == c.sorted() else { return [] }
        var results: [[Int]] = []
        let len = p.count
        for L in 1...max(1, min(maxKeyLength, len, PermutationCipher.maxKeyLength)) {
            let rows = len / L, extra = len % L
            let colLen = (0..<L).map { rows + ($0 < extra ? 1 : 0) }
            let cols: [[Int]] = (0..<L).map { j in stride(from: j, to: len, by: L).map { p[$0] } }
            var used = [Bool](repeating: false, count: L)
            var order: [Int] = []
            func search(_ pos: Int) {
                if results.count >= maxResults { return }
                if order.count == L {
                    var key = [Int](repeating: 0, count: L)
                    for (rank, col) in order.enumerated() { key[col] = rank + 1 }
                    results.append(key)
                    return
                }
                for j in 0..<L where !used[j] {
                    let l = colLen[j]
                    if pos + l > len { continue }
                    var ok = true
                    for k in 0..<l where cols[j][k] != c[pos + k] { ok = false; break }
                    if !ok { continue }
                    used[j] = true; order.append(j)
                    search(pos + l)
                    used[j] = false; order.removeLast()
                }
            }
            search(0)
            if results.count >= maxResults { break }
        }
        return results
    }
}
