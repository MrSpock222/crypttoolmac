import CTCommon

/// Monoalphabetic substitution (CT1 "Substitution / Atbash").
public struct SubstitutionCipher: Sendable {
    public let options: TextOptions
    /// Image of every alphabet character: `keyAlphabet[i]` replaces `alphabet[i]`.
    public let keyAlphabet: [Character]
    /// Same mapping as alphabet indices.
    public let keyIndices: [Int]
    private let inverseIndices: [Int]

    /// Creates the cipher from a complete key alphabet (a permutation of the alphabet).
    public init(keyAlphabet: String, options: TextOptions) throws {
        let alphabet = options.alphabetCharacters
        let n = alphabet.count
        guard n > 0 else { throw CTError("The alphabet is empty.") }
        let mapper = LetterMapper(options)
        var idx: [Int] = []
        for ch in keyAlphabet {
            guard let (i, _) = mapper.lookup(ch) else {
                throw CTError("The character \"\(ch)\" of the key is not contained in the alphabet.")
            }
            idx.append(i)
        }
        guard idx.count == n else {
            throw CTError("The key must contain exactly \(n) characters (one per alphabet character), it contains \(idx.count).")
        }
        var inv = [Int](repeating: -1, count: n)
        for (pos, i) in idx.enumerated() {
            guard inv[i] < 0 else {
                throw CTError("The character \"\(alphabet[i])\" occurs more than once in the key. The key must be a permutation of the alphabet.")
            }
            inv[i] = pos
        }
        self.options = options
        self.keyIndices = idx
        self.keyAlphabet = idx.map { alphabet[$0] }
        self.inverseIndices = inv
    }

    /// Unchecked initialiser for internally generated permutations.
    init(validIndices idx: [Int], options: TextOptions) {
        let alphabet = options.alphabetCharacters
        var inv = [Int](repeating: 0, count: idx.count)
        for (pos, i) in idx.enumerated() { inv[i] = pos }
        self.options = options
        self.keyIndices = idx
        self.keyAlphabet = idx.map { alphabet[$0] }
        self.inverseIndices = inv
    }

    /// Key alphabet from a keyword as in CT1's substitution dialog: the distinct keyword letters
    /// are placed starting at position `offset` (cyclically), the free positions are then filled –
    /// starting at position 0 – with the remaining alphabet letters in ascending (or descending)
    /// order. Keyword characters not in the alphabet are tried in upper/lower case, else ignored.
    public static func keyAlphabet(fromKeyword keyword: String, options: TextOptions,
                                   remainingDescending: Bool = false, offset: Int = 0) -> [Character] {
        let alphabet = options.alphabetCharacters
        let n = alphabet.count
        guard n > 0 else { return [] }
        var inserted: [Int] = []
        var used = Set<Int>()
        for ch in keyword {
            var i = alphabet.firstIndex(of: ch)
            let up = String(ch).uppercased(), low = String(ch).lowercased()
            if i == nil, up.count == 1 { i = alphabet.firstIndex(of: Character(up)) }
            if i == nil, low.count == 1 { i = alphabet.firstIndex(of: Character(low)) }
            if let i = i, !used.contains(i) { used.insert(i); inserted.append(i) }
        }
        var remaining = (0..<n).filter { !used.contains($0) }
        if remainingDescending { remaining.reverse() }
        var mapped = [Int?](repeating: nil, count: n)
        let off = mod(offset, n)
        for (k, i) in inserted.enumerated() { mapped[(off + k) % n] = i }
        var r = 0
        for p in 0..<n where mapped[p] == nil { mapped[p] = remaining[r]; r += 1 }
        return mapped.map { alphabet[$0!] }
    }

    /// Cipher from a keyword (see `keyAlphabet(fromKeyword:…)`).
    public static func fromKeyword(_ keyword: String, options: TextOptions,
                                   remainingDescending: Bool = false, offset: Int = 0) -> SubstitutionCipher {
        let alphabet = options.alphabetCharacters
        let key = keyAlphabet(fromKeyword: keyword, options: options, remainingDescending: remainingDescending, offset: offset)
        return SubstitutionCipher(validIndices: key.map { alphabet.firstIndex(of: $0)! }, options: options)
    }

    /// Atbash: the alphabet reversed.
    public static func atbash(options: TextOptions) -> SubstitutionCipher {
        let n = options.alphabetSize
        return SubstitutionCipher(validIndices: Array((0..<n).reversed()), options: options)
    }

    /// Random key alphabet.
    public static func random(options: TextOptions) -> SubstitutionCipher {
        return SubstitutionCipher(validIndices: Array(0..<options.alphabetSize).shuffled(), options: options)
    }

    /// The key alphabet as string (CT1 key display).
    public var keyString: String { String(keyAlphabet) }

    /// Replaces every alphabet letter by its image.
    public func encrypt(_ text: String) -> String {
        LetterMapper(options).mapLetters(text) { i, _ in keyIndices[i] }
    }

    /// Inverse substitution.
    public func decrypt(_ text: String) -> String {
        LetterMapper(options).mapLetters(text) { i, _ in inverseIndices[i] }
    }
}
