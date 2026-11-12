import Foundation

/// Text options as known from CT1 ("Optionen ▸ Textoptionen").
///
/// Classical ciphers operate on the characters of `alphabet` only. The flags decide what
/// happens with all other characters and with upper/lower case:
///
/// * `distinguishCase == false` (CT1 default): a lowercase letter whose uppercase form is in the
///   alphabet is treated as that alphabet letter.
/// * `keepCase` (only relevant when case is not distinguished): the output letter gets the case
///   of the input letter.
/// * `keepNonAlphabet`: characters that are not in the alphabet are copied unchanged to the output;
///   otherwise they are removed.
public struct TextOptions: Codable, Equatable, Hashable, Sendable {
    public var alphabet: String
    public var distinguishCase: Bool
    public var keepCase: Bool
    public var keepNonAlphabet: Bool

    public init(alphabet: String = TextOptions.uppercaseLetters,
                distinguishCase: Bool = false,
                keepCase: Bool = true,
                keepNonAlphabet: Bool = true) {
        self.alphabet = alphabet
        self.distinguishCase = distinguishCase
        self.keepCase = keepCase
        self.keepNonAlphabet = keepNonAlphabet
    }

    public static let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    public static let lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
    public static let digits = "0123456789"
    /// CT1 character groups (DlgTextOptions.cpp).
    public static let umlautsUpper = "ÄÖÜ"
    public static let umlautsLower = "äöü"
    public static let specialCharacters = ".,:;!?()-+*/[]{}@_><#~=\\\"&%$§"
    /// All characters CT1 allows in an alphabet.
    public static let allowedCharacters = uppercaseLetters + lowercaseLetters + " " + digits + specialCharacters + umlautsUpper + umlautsLower

    /// CT1 "complete_alphabet": appends the characters of `set` that are missing.
    public mutating func addCharacters(_ set: String) {
        for c in set where !alphabet.contains(c) { alphabet.append(c) }
    }

    /// CT1 "remove_charset": removes all characters of `set`.
    public mutating func removeCharacters(_ set: String) {
        alphabet.removeAll { set.contains($0) }
    }

    /// CT1 default: A–Z, case ignored but preserved, other characters kept.
    public static let `default` = TextOptions()

    /// The alphabet as ordered array of unique characters.
    public var alphabetCharacters: [Character] {
        var seen = Set<Character>()
        var out: [Character] = []
        for c in alphabet where !seen.contains(c) {
            seen.insert(c)
            out.append(c)
        }
        return out
    }

    public var alphabetSize: Int { alphabetCharacters.count }

    /// Lookup table for fast character → index mapping.
    public func makeMapper() -> AlphabetMapper { AlphabetMapper(options: self) }

    /// Applies a per-letter transformation. `transform(index, position)` receives the alphabet
    /// index of the current letter and the running position (0, 1, 2 … counting alphabet letters
    /// only) and returns the new alphabet index (taken modulo the alphabet size).
    public func mapLetters(_ text: String, _ transform: (_ index: Int, _ position: Int) -> Int) -> String {
        let m = makeMapper()
        let n = m.size
        guard n > 0 else { return text }
        var out = String()
        out.reserveCapacity(text.utf8.count)
        var position = 0
        for ch in text {
            if let (idx, lower) = m.lookup(ch) {
                var r = transform(idx, position) % n
                if r < 0 { r += n }
                out.append(m.character(at: r, lowercase: lower))
                position += 1
            } else if keepNonAlphabet {
                out.append(ch)
            }
        }
        return out
    }

    /// Returns the alphabet indices of all letters of `text` (non-alphabet characters are skipped).
    public func indices(of text: String) -> [Int] {
        let m = makeMapper()
        var out: [Int] = []
        out.reserveCapacity(text.count)
        for ch in text {
            if let (idx, _) = m.lookup(ch) { out.append(idx) }
        }
        return out
    }

    /// Converts indices back to a string of alphabet characters.
    public func string(from indices: [Int]) -> String {
        let chars = alphabetCharacters
        let n = chars.count
        guard n > 0 else { return "" }
        return String(indices.map { chars[(($0 % n) + n) % n] })
    }

    /// Text reduced to alphabet letters (normalised to alphabet characters).
    public func filtered(_ text: String) -> String { string(from: indices(of: text)) }
}

/// Fast mapping between characters and alphabet indices honouring the case options.
public struct AlphabetMapper: Sendable {
    public let characters: [Character]
    public let size: Int
    private let table: [Character: Int]
    private let distinguishCase: Bool
    private let keepCase: Bool

    public init(options: TextOptions) {
        characters = options.alphabetCharacters
        size = characters.count
        var t: [Character: Int] = [:]
        for (i, c) in characters.enumerated() { t[c] = i }
        table = t
        distinguishCase = options.distinguishCase
        keepCase = options.keepCase
    }

    /// Returns (alphabet index, input was lowercase-folded) or nil if not part of the alphabet.
    @inline(__always)
    public func lookup(_ ch: Character) -> (Int, Bool)? {
        if let i = table[ch] { return (i, false) }
        if !distinguishCase {
            // Case mappings may change the length ("ß" → "SS"); only single characters qualify.
            if let up = AlphabetMapper.singleCharacter(String(ch).uppercased()), up != ch, let i = table[up] { return (i, true) }
            if let low = AlphabetMapper.singleCharacter(String(ch).lowercased()), low != ch, let i = table[low] { return (i, false) }
        }
        return nil
    }

    @inline(__always)
    public func character(at index: Int, lowercase: Bool) -> Character {
        let c = characters[index]
        if lowercase && keepCase && !distinguishCase,
           let low = AlphabetMapper.singleCharacter(String(c).lowercased()), low != c,
           table[low] == nil {   // never emit a different alphabet member
            return low
        }
        return c
    }

    @inline(__always)
    static func singleCharacter(_ s: String) -> Character? {
        s.count == 1 ? s.first : nil
    }
}
