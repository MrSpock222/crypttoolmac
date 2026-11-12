import CTCommon

/// ADFGVX cipher (CT1 "ADFGVX"): substitution with a 6×6 Polybius square over A–Z and 0–9
/// followed by a columnar transposition.
///
/// CT1 semantics: lowercase letters are treated as uppercase, umlauts/ß are transcribed (ä → AE,
/// ß → SS), other characters are dropped. The transposition writes the substitution result row
/// by row under the key and reads the columns in the alphabetical (character code) order of the
/// key characters; equal key characters are read left to right. The ciphertext is grouped in
/// blocks (default 5). Decryption ignores whitespace and returns the plaintext in lowercase.
public struct ADFGVXCipher: Sendable {
    /// Row/column labels.
    public static let labels: [Character] = ["A", "D", "F", "G", "V", "X"]
    /// The 36 symbols of the square.
    public static let symbols: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    /// CT1's default (unmixed) square.
    public static var standardMatrix: [[Character]] { (0..<6).map { r in Array(symbols[(r * 6)..<(r * 6 + 6)]) } }

    public let matrix: [[Character]]
    /// The normalised transposition key (uppercase A–Z / 0–9).
    public let transpositionKey: String
    private let coordinates: [Character: (Int, Int)]
    /// Column read order (indices into the key, stable by character).
    public let columnOrder: [Int]

    /// Creates the cipher. Throws if the matrix is not a 6×6 arrangement of A–Z/0–9 (each once) or
    /// the transposition key contains no usable characters (A–Z, 0–9; case-insensitive).
    public init(matrix: [[Character]], transpositionKey: String) throws {
        guard matrix.count == 6, matrix.allSatisfy({ $0.count == 6 }) else {
            throw CTError("Die ADFGVX-Matrix muss aus 6×6 Zeichen bestehen.")
        }
        let flat = matrix.flatMap { $0 }.map(asciiUppercased)
        for ch in flat where !ADFGVXCipher.symbols.contains(ch) {
            throw CTError("Die ADFGVX-Matrix darf nur die Zeichen A–Z und 0–9 enthalten („\(ch)“ ist ungültig).")
        }
        guard Set(flat).count == 36 else {
            throw CTError("Jedes Zeichen A–Z und 0–9 muss in der ADFGVX-Matrix genau einmal vorkommen.")
        }
        let key = ADFGVXCipher.normalizeKey(transpositionKey)
        guard !key.isEmpty else {
            throw CTError("Das Transpositions-Passwort ist leer. Bitte ein Passwort aus Buchstaben (oder Ziffern) eingeben.")
        }
        var coords: [Character: (Int, Int)] = [:]
        for (i, ch) in flat.enumerated() { coords[ch] = (i / 6, i % 6) }
        self.matrix = (0..<6).map { r in Array(flat[(r * 6)..<(r * 6 + 6)]) }
        self.transpositionKey = key
        self.coordinates = coords
        let k = Array(key)
        self.columnOrder = k.indices.sorted { k[$0] != k[$1] ? k[$0] < k[$1] : $0 < $1 }
    }

    /// Uppercase key reduced to A–Z and 0–9.
    public static func normalizeKey(_ key: String) -> String {
        String(key.uppercased().filter { symbols.contains($0) })
    }

    /// CT1 "numbered password": rank of each key character (1-based), e.g. "-3-1-2-".
    public var numberedKey: [Int] {
        var ranks = [Int](repeating: 0, count: columnOrder.count)
        for (rank, col) in columnOrder.enumerated() { ranks[col] = rank + 1 }
        return ranks
    }

    /// Square from a password (CT1 "Passwort für Matrix"): distinct password characters followed by
    /// the remaining characters A–Z, 0–9.
    public static func matrix(fromKeyword keyword: String) -> [[Character]] {
        var seq: [Character] = []
        for ch in keyword.uppercased() where symbols.contains(ch) && !seq.contains(ch) { seq.append(ch) }
        for ch in symbols where !seq.contains(ch) { seq.append(ch) }
        return (0..<6).map { r in Array(seq[(r * 6)..<(r * 6 + 6)]) }
    }

    /// Randomly shuffled square.
    public static func randomMatrix() -> [[Character]] {
        let s = symbols.shuffled()
        return (0..<6).map { r in Array(s[(r * 6)..<(r * 6 + 6)]) }
    }

    /// Plaintext characters accepted by the cipher (uppercase A–Z / 0–9 after transcription).
    public static func plaintextSymbols(_ text: String) -> [Character] {
        var out: [Character] = []
        for ch in text {
            if let t = umlautTranscription(ch) {
                out.append(contentsOf: t.uppercased())
            } else if let v = ch.asciiValue {
                if (97...122).contains(v) { out.append(Character(Unicode.Scalar(v - 32))) } else if (65...90).contains(v) || (48...57).contains(v) { out.append(ch) }
            }
        }
        return out
    }

    /// Stage 1 (substitution) result without grouping, e.g. "DGDDDA…".
    public func substitute(_ text: String) -> String {
        var s = String()
        for ch in ADFGVXCipher.plaintextSymbols(text) {
            guard let (r, c) = coordinates[ch] else { continue }
            s.append(ADFGVXCipher.labels[r]); s.append(ADFGVXCipher.labels[c])
        }
        return s
    }

    /// Encrypts; `blockSize` > 0 groups the result (CT1 default 5), `newLine` separates the blocks
    /// by line breaks instead of spaces.
    public func encrypt(_ text: String, blockSize: Int = 5, newLine: Bool = false) -> String {
        let stage1 = Array(substitute(text))
        let cols = transpositionKey.count
        var out = String()
        out.reserveCapacity(stage1.count)
        for col in columnOrder {
            var i = col
            while i < stage1.count { out.append(stage1[i]); i += cols }
        }
        return groupText(out, size: blockSize, separator: newLine ? "\n" : " ")
    }

    /// Undoes the transposition; returns the stage-1 text (pairs of ADFGVX letters).
    public func detranspose(_ text: String) throws -> String {
        var c: [Character] = []
        for ch in text {
            if ch.isWhitespace { continue }
            let u = asciiUppercased(ch)
            guard ADFGVXCipher.labels.contains(u) else {
                throw CTError("Der Geheimtext darf nur die Buchstaben A, D, F, G, V und X enthalten („\(ch)“ ist ungültig).")
            }
            c.append(u)
        }
        guard c.count % 2 == 0 else {
            throw CTError("Der Geheimtext muss eine gerade Anzahl von Buchstaben A, D, F, G, V, X enthalten.")
        }
        let cols = transpositionKey.count
        let rows = c.count / cols, extra = c.count % cols
        var stage1 = [Character](repeating: "A", count: c.count)
        var p = 0
        for col in columnOrder {
            let len = rows + (col < extra ? 1 : 0)
            for r in 0..<len { stage1[r * cols + col] = c[p]; p += 1 }
        }
        return String(stage1)
    }

    /// Decrypts (throws on characters other than ADFGVX/whitespace or an odd letter count).
    public func decrypt(_ text: String) throws -> String {
        let stage1 = Array(try detranspose(text))
        var out = String()
        var i = 0
        while i + 1 < stage1.count {
            let r = ADFGVXCipher.labels.firstIndex(of: stage1[i])!, cIdx = ADFGVXCipher.labels.firstIndex(of: stage1[i + 1])!
            out.append(Character(String(matrix[r][cIdx]).lowercased()))
            i += 2
        }
        return out
    }
}
