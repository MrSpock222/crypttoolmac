import CTCommon

/// Playfair cipher as implemented in CT1 (fixed alphabet, independent of the text options).
///
/// * 5×5: A–Z without J (J is replaced by I in the text, dropped from the keyword), 6×6: A–Z, 0–9.
/// * Lowercase letters are converted to uppercase, accented letters to their base letter
///   (Ä → A, É → E, …), all other characters are ignored.
/// * Preformatting (encryption): identical consecutive letters are separated by the separator
///   (`separator2` if the doubled letter is the separator itself); with `separateOnlyWithinPairs`
///   (CT1 default) only doubles that would fall into the same digraph are separated. An odd length
///   is padded with the separator (resp. `separator2`).
/// * The output consists of the uppercase cipher letters without spaces (CT1 shows them in its
///   Playfair view; use `grouped(_:)` for a digraph display).
public struct PlayfairCipher: Sendable {
    public enum Size: String, CaseIterable, Codable, Sendable {
        /// 5×5 matrix A–Z without J (J → I).
        case fiveByFive
        /// 6×6 matrix A–Z and 0–9.
        case sixBySix

        public var dimension: Int { self == .fiveByFive ? 5 : 6 }
        /// The letters of the matrix in their natural order.
        public var alphabet: [Character] {
            self == .fiveByFive ? Array("ABCDEFGHIKLMNOPQRSTUVWXYZ") : Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        }
        public var displayName: String { self == .fiveByFive ? "5×5 (J = I)" : "6×6 (A–Z, 0–9)" }
    }

    public let size: Size
    /// The key matrix (rows).
    public let matrix: [[Character]]
    public let separator: Character
    public let separator2: Character
    /// Separate doubled letters at all ("Doppelte Buchstaben trennen").
    public let doubleLetterRule: Bool
    /// Only separate doubles that would form one digraph (CT1 default).
    public let separateOnlyWithinPairs: Bool
    private let position: [Character: (Int, Int)]

    /// Creates the key matrix from a keyword. With `ignoreDuplicateKeyLetters` (CT1 default) repeated
    /// keyword letters are skipped; otherwise each repetition is replaced by the next unused letter
    /// of the alphabet (CT1 option). Invalid separators fall back to "X" / "Y" like CT1.
    public init(keyword: String, size: Size = .fiveByFive, separator: Character = "X", doubleLetterRule: Bool = true,
                separator2: Character = "Y", separateOnlyWithinPairs: Bool = true, ignoreDuplicateKeyLetters: Bool = true) {
        let mat = PlayfairCipher.makeMatrix(keyword: keyword, size: size, ignoreDuplicateKeyLetters: ignoreDuplicateKeyLetters)
        self.init(uncheckedMatrix: mat, size: size, separator: separator, separator2: separator2,
                  doubleLetterRule: doubleLetterRule, separateOnlyWithinPairs: separateOnlyWithinPairs)
    }

    /// Creates the cipher from an explicit matrix (every letter of the size's alphabet exactly once).
    public init(matrix: [[Character]], size: Size = .fiveByFive, separator: Character = "X", doubleLetterRule: Bool = true,
                separator2: Character = "Y", separateOnlyWithinPairs: Bool = true) throws {
        let d = size.dimension
        guard matrix.count == d, matrix.allSatisfy({ $0.count == d }) else {
            throw CTError("The Playfair matrix must contain \(d)×\(d) characters.")
        }
        let flat = matrix.flatMap { $0 }.map { PlayfairCipher.normalize($0, size: size) }
        guard flat.allSatisfy({ $0 != nil }), Set(flat.map { $0! }).count == d * d else {
            throw CTError("The Playfair matrix must contain each character of the alphabet (\(String(size.alphabet))) exactly once.")
        }
        let m = (0..<d).map { r in (0..<d).map { c in flat[r * d + c]! } }
        self.init(uncheckedMatrix: m, size: size, separator: separator, separator2: separator2,
                  doubleLetterRule: doubleLetterRule, separateOnlyWithinPairs: separateOnlyWithinPairs)
    }

    private init(uncheckedMatrix m: [[Character]], size: Size, separator: Character, separator2: Character,
                 doubleLetterRule: Bool, separateOnlyWithinPairs: Bool) {
        self.size = size
        self.matrix = m
        var pos: [Character: (Int, Int)] = [:]
        for (r, row) in m.enumerated() { for (c, ch) in row.enumerated() { pos[ch] = (r, c) } }
        self.position = pos
        // CT1: separators must be letters A–Z and different, otherwise X / Y
        var s1 = PlayfairCipher.normalize(separator, size: size) ?? "X"
        var s2 = PlayfairCipher.normalize(separator2, size: size) ?? "Y"
        if !(s1.isASCII && s1.isLetter) { s1 = "X" }
        if !(s2.isASCII && s2.isLetter) { s2 = "Y" }
        if s1 == s2 { s1 = "X"; s2 = "Y" }
        self.separator = s1
        self.separator2 = s2
        self.doubleLetterRule = doubleLetterRule
        self.separateOnlyWithinPairs = separateOnlyWithinPairs
    }

    /// Converts a character to a Playfair letter of the given size (nil if not representable).
    public static func normalize(_ ch: Character, size: Size) -> Character? {
        var c = ch
        if let v = c.asciiValue {
            if v >= 97 && v <= 122 { c = Character(Unicode.Scalar(v - 32)) }
            if c == "J" && size == .fiveByFive { return "I" }
            if let w = c.asciiValue, (65...90).contains(w) { return c }
            if let w = c.asciiValue, (48...57).contains(w) { return size == .sixBySix ? c : nil }
            if c == "@" { return "A" }
            return nil
        }
        switch c {
        case "À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "à", "á", "â", "ã", "ä", "å", "æ": return "A"
        case "Ç", "ç", "¢": return "C"
        case "Ð", "ð": return "D"
        case "È", "É", "Ê", "Ë", "è", "é", "ê", "ë", "€": return "E"
        case "Ì", "Í", "Î", "Ï", "ì", "í", "î", "ï": return "I"
        case "Ñ", "ñ": return "N"
        case "Ò", "Ó", "Ô", "Õ", "Ö", "Ø", "Œ", "ò", "ó", "ô", "õ", "ö", "ø", "œ": return "O"
        case "Š", "š": return "S"
        case "Ù", "Ú", "Û", "Ü", "ù", "ú", "û", "ü": return "U"
        case "Ý", "Ÿ", "ý", "ÿ", "¥": return "Y"
        case "Ž", "ž": return "Z"
        default: return nil
        }
    }

    /// Builds the matrix from the keyword (CT1 `CreateMatrixFromPass`). Like CT1's key field, a "J"
    /// in the keyword is dropped for the 5×5 matrix (in the text J is replaced by I).
    public static func makeMatrix(keyword: String, size: Size, ignoreDuplicateKeyLetters: Bool = true) -> [[Character]] {
        let alpha = size.alphabet
        let count = alpha.count
        let usable = size == .fiveByFive ? keyword.filter { $0 != "J" && $0 != "j" } : keyword
        let pass = Array(usable.compactMap { normalize($0, size: size) }.prefix(count))
        var key: [Character] = []
        if ignoreDuplicateKeyLetters {
            for ch in pass where !key.contains(ch) { key.append(ch) }
        } else {
            for ch in pass {
                if key.contains(ch) {
                    var k = (alpha.firstIndex(of: ch)! + 1) % count
                    while key.contains(alpha[k]) { k = (k + 1) % count }
                    key.append(alpha[k])
                } else {
                    key.append(ch)
                }
            }
        }
        let ordered = key + alpha.filter { !key.contains($0) }
        let d = size.dimension
        return (0..<d).map { r in Array(ordered[(r * d)..<(r * d + d)]) }
    }

    /// The matrix as one string (row by row).
    public var matrixString: String { String(matrix.flatMap { $0 }) }

    /// Playfair letters of the text (converted, invalid characters removed).
    public func letters(_ text: String) -> [Character] { text.compactMap { PlayfairCipher.normalize($0, size: size) } }

    /// CT1 preformatting of a plaintext into digraphs (separating doubles, padding odd length).
    public func preformat(_ text: String) -> [String] {
        var out: [Character] = []
        var old: Character? = nil
        for c in letters(text) {
            if c == old && doubleLetterRule && (!separateOnlyWithinPairs || out.count % 2 == 1) {
                out.append(old == separator ? separator2 : separator)
            }
            out.append(c)
            old = c
        }
        if out.count % 2 == 1 { out.append(out.last == separator ? separator2 : separator) }
        return stride(from: 0, to: out.count, by: 2).map { String(out[$0..<($0 + 2)]) }
    }

    private func digraphs(forDecryption text: String) -> [String] {
        var l = letters(text)
        if l.count % 2 == 1 { l.append(l.last == separator ? separator2 : separator) }
        return stride(from: 0, to: l.count, by: 2).map { String(l[$0..<($0 + 2)]) }
    }

    private func apply(_ pairs: [String], decrypt: Bool) -> String {
        let d = size.dimension
        let move = decrypt ? d - 1 : 1
        var out = String()
        out.reserveCapacity(pairs.count * 2)
        for p in pairs {
            let a = p.first!, b = p.last!
            guard let (r1, c1) = position[a], let (r2, c2) = position[b] else { continue }
            if r1 == r2 {
                out.append(matrix[r1][(c1 + move) % d]); out.append(matrix[r1][(c2 + move) % d])
            } else if c1 == c2 {
                out.append(matrix[(r1 + move) % d][c1]); out.append(matrix[(r2 + move) % d][c1])
            } else {
                out.append(matrix[r1][c2]); out.append(matrix[r2][c1])
            }
        }
        return out
    }

    /// Encrypts the text (preformatted first); result: uppercase letters without separators.
    public func encrypt(_ text: String) -> String { apply(preformat(text), decrypt: false) }

    /// Decrypts the text; the inserted separator letters remain in the plaintext (as in CT1).
    public func decrypt(_ text: String) -> String { apply(digraphs(forDecryption: text), decrypt: true) }

    /// Digraph display ("AB CD EF").
    public static func grouped(_ text: String) -> String { groupText(text, size: 2) }
}
