import CTCommon

/// Nihilist cipher (extra, not part of CT1): a 5×5 Polybius square (J = I) built from a keyword;
/// every plaintext letter's coordinates (11…55) are added to the coordinates of the cyclically
/// repeated key letters. The ciphertext is a sequence of numbers separated by spaces.
public enum Nihilist {
    /// Polybius square from a keyword (distinct keyword letters, then the rest of A–Z without J).
    public static func square(keyword: String) -> [[Character]] {
        PlayfairCipher.makeMatrix(keyword: keyword, size: .fiveByFive)
    }

    private static func coordinates(_ text: String, square: [[Character]]) -> [Int] {
        var pos: [Character: Int] = [:]
        for (r, row) in square.enumerated() { for (c, ch) in row.enumerated() { pos[ch] = (r + 1) * 10 + c + 1 } }
        return text.compactMap { PlayfairCipher.normalize($0, size: .fiveByFive) }.compactMap { pos[$0] }
    }

    /// Encrypts to space-separated numbers.
    public static func encrypt(_ text: String, squareKeyword: String, key: String) throws -> String {
        let sq = square(keyword: squareKeyword)
        let k = coordinates(key, square: sq)
        guard !k.isEmpty else { throw CTError("Der Schlüssel enthält keine Buchstaben.") }
        let p = coordinates(text, square: sq)
        return p.enumerated().map { String($0.element + k[$0.offset % k.count]) }.joined(separator: " ")
    }

    /// Decrypts space-separated numbers (throws on numbers that do not fit the key).
    public static func decrypt(_ text: String, squareKeyword: String, key: String) throws -> String {
        let sq = square(keyword: squareKeyword)
        let k = coordinates(key, square: sq)
        guard !k.isEmpty else { throw CTError("Der Schlüssel enthält keine Buchstaben.") }
        var out = String()
        for (i, token) in text.split(whereSeparator: { !$0.isNumber }).enumerated() {
            guard let v = Int(token) else { throw CTError("„\(token)“ ist keine gültige Zahl.") }
            let d = v - k[i % k.count]
            let r = d / 10, c = d % 10
            guard (1...5).contains(r), (1...5).contains(c) else {
                throw CTError("Die Zahl \(v) passt nicht zum Schlüssel (Position \(i + 1)).")
            }
            out.append(sq[r - 1][c - 1])
        }
        return out
    }
}
