import CTCommon

// Internal text helpers shared by the classical ciphers.
//
// Note: `CTCommon.AlphabetMapper` builds `Character(String(ch).uppercased())`, which traps for
// characters whose case mapping has more than one grapheme (e.g. "ß" → "SS"). The ciphers in this
// module therefore use the crash-safe `LetterMapper` below, which implements the same semantics.

/// How the case of an input character relates to the matched alphabet character.
enum CaseFold {
    case exact      // character is literally in the alphabet
    case wasLower   // input was lowercase, its uppercase form is in the alphabet
    case wasUpper   // input was uppercase, its lowercase form is in the alphabet
}

/// Crash-safe character ↔ alphabet index mapping honouring `TextOptions` case handling.
struct LetterMapper {
    let characters: [Character]
    let size: Int
    private let table: [Character: Int]
    private let ascii: [Int]          // fast path for ASCII characters (-1 = not in alphabet)
    private let asciiFold: [CaseFold]
    let distinguishCase: Bool
    let keepCase: Bool
    let keepNonAlphabet: Bool
    /// Lower/upper case output forms per index. A case variant that is itself a (different)
    /// alphabet character is not used – otherwise the output could not be decrypted.
    private let lowerForm: [Character]
    private let upperForm: [Character]

    init(_ options: TextOptions) {
        characters = options.alphabetCharacters
        size = characters.count
        var t: [Character: Int] = [:]
        for (i, c) in characters.enumerated() { t[c] = i }
        table = t
        distinguishCase = options.distinguishCase
        keepCase = options.keepCase
        keepNonAlphabet = options.keepNonAlphabet
        var a = [Int](repeating: -1, count: 128)
        var f = [CaseFold](repeating: .exact, count: 128)
        for v in 0..<128 {
            let ch = Character(Unicode.Scalar(UInt8(v)))
            if let r = LetterMapper.slowLookup(ch, table: t, distinguishCase: options.distinguishCase) {
                a[v] = r.0
                f[v] = r.1
            }
        }
        ascii = a
        asciiFold = f
        func variant(_ c: Character, _ v: String) -> Character {
            guard let x = LetterMapper.singleCharacter(v), x != c, t[x] == nil else { return c }
            return x
        }
        lowerForm = characters.map { variant($0, String($0).lowercased()) }
        upperForm = characters.map { variant($0, String($0).uppercased()) }
    }

    private static func singleCharacter(_ s: String) -> Character? {
        var it = s.makeIterator()
        guard let first = it.next(), it.next() == nil else { return nil }
        return first
    }

    private static func slowLookup(_ ch: Character, table: [Character: Int], distinguishCase: Bool) -> (Int, CaseFold)? {
        if let i = table[ch] { return (i, .exact) }
        if !distinguishCase {
            let s = String(ch)
            if let up = singleCharacter(s.uppercased()), up != ch, let i = table[up] { return (i, .wasLower) }
            if let low = singleCharacter(s.lowercased()), low != ch, let i = table[low] { return (i, .wasUpper) }
        }
        return nil
    }

    /// Alphabet index and case relation of `ch`, or nil if `ch` is not an alphabet character.
    @inline(__always)
    func lookup(_ ch: Character) -> (Int, CaseFold)? {
        if let v = ch.asciiValue {
            let i = ascii[Int(v)]
            return i >= 0 ? (i, asciiFold[Int(v)]) : nil
        }
        return LetterMapper.slowLookup(ch, table: table, distinguishCase: distinguishCase)
    }

    @inline(__always)
    func index(of ch: Character) -> Int? { lookup(ch)?.0 }

    /// Output character for alphabet index `index`, adapted to the case of the input position.
    @inline(__always)
    func character(_ index: Int, fold: CaseFold) -> Character {
        guard keepCase && !distinguishCase else { return characters[index] }
        switch fold {
        case .exact: return characters[index]
        case .wasLower: return lowerForm[index]
        case .wasUpper: return upperForm[index]
        }
    }

    /// Alphabet indices of all letters of `text`.
    func indices(of text: String) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(text.utf8.count)
        for ch in text { if let (i, _) = lookup(ch) { out.append(i) } }
        return out
    }

    /// Plain alphabet characters for the given indices.
    func string(from indices: [Int]) -> String {
        guard size > 0 else { return "" }
        var s = String()
        s.reserveCapacity(indices.count)
        for i in indices { s.append(characters[((i % size) + size) % size]) }
        return s
    }

    /// Per-letter transformation (`transform(index, position)` → new index, reduced modulo the
    /// alphabet size). Non-alphabet characters are kept or removed according to the options.
    func mapLetters(_ text: String, _ transform: (_ index: Int, _ position: Int) -> Int) -> String {
        guard size > 0 else { return text }
        var out = String()
        out.reserveCapacity(text.utf8.count)
        var position = 0
        for ch in text {
            if let (idx, fold) = lookup(ch) {
                var r = transform(idx, position) % size
                if r < 0 { r += size }
                out.append(character(r, fold: fold))
                position += 1
            } else if keepNonAlphabet {
                out.append(ch)
            }
        }
        return out
    }

    /// CT1 "Reformat": puts the processed letters `letters` (alphabet indices) back into the layout of
    /// `original` – letter positions receive the next processed letter (with the case of the original
    /// position if case is preserved), other characters are kept or dropped according to the options.
    /// Surplus processed letters (e.g. Hill padding) are appended at the end.
    func reformat(original: String, letters: [Int]) -> String {
        guard size > 0 else { return original }
        var out = String()
        out.reserveCapacity(original.utf8.count + 8)
        var p = 0
        for ch in original {
            if let (_, fold) = lookup(ch) {
                if p < letters.count {
                    out.append(character(((letters[p] % size) + size) % size, fold: fold))
                    p += 1
                }
            } else if keepNonAlphabet {
                out.append(ch)
            }
        }
        while p < letters.count {
            out.append(characters[((letters[p] % size) + size) % size])
            p += 1
        }
        return out
    }
}

// MARK: - Small number helpers

@inline(__always)
func mod(_ a: Int, _ n: Int) -> Int {
    let r = a % n
    return r < 0 ? r + n : r
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a), y = abs(b)
    while y != 0 { (x, y) = (y, x % y) }
    return x
}

/// Multiplicative inverse of `a` modulo `n`, nil if it does not exist.
func modInverse(_ a: Int, _ n: Int) -> Int? {
    guard n > 0 else { return nil }
    if n == 1 { return 0 }
    var (oldR, r) = (mod(a, n), n)
    var (oldS, s) = (1, 0)
    while r != 0 {
        let q = oldR / r
        (oldR, r) = (r, oldR - q * r)
        (oldS, s) = (s, oldS - q * s)
    }
    guard oldR == 1 else { return nil }
    return mod(oldS, n)
}

/// Uppercase A–Z value (0…25) of an ASCII letter, nil otherwise.
@inline(__always)
func latinLetterValue(_ ch: Character) -> Int? {
    guard let v = ch.asciiValue else { return nil }
    switch v {
    case 65...90: return Int(v) - 65
    case 97...122: return Int(v) - 97
    default: return nil
    }
}

/// Converts ASCII a–z to A–Z, other characters unchanged (never traps, unlike
/// `Character(String(ch).uppercased())` for "ß").
@inline(__always)
func asciiUppercased(_ ch: Character) -> Character {
    if let v = ch.asciiValue, (97...122).contains(v) { return Character(Unicode.Scalar(v - 32)) }
    return ch
}

/// Expands German umlauts / ß to their two-letter transcription (CT1 does this for ADFGVX,
/// Solitaire and the homophone cipher). Returns nil for other characters.
@inline(__always)
func umlautTranscription(_ ch: Character) -> String? {
    switch ch {
    case "Ä": return "AE"
    case "ä": return "ae"
    case "Ö": return "OE"
    case "ö": return "oe"
    case "Ü": return "UE"
    case "ü": return "ue"
    case "ß": return "ss"
    case "ẞ": return "SS"
    default: return nil
    }
}

/// Groups `text` in blocks of `size` characters separated by `separator`; `blocksPerLine` > 0
/// inserts a line break instead of the separator after that many blocks.
func groupText(_ text: String, size: Int, separator: Character = " ", blocksPerLine: Int = 0) -> String {
    guard size > 0 else { return text }
    var out = String()
    out.reserveCapacity(text.count + text.count / size + 1)
    var n = 0
    for ch in text {
        if n > 0 && n % size == 0 {
            if blocksPerLine > 0 && n % (size * blocksPerLine) == 0 { out.append("\n") } else { out.append(separator) }
        }
        out.append(ch)
        n += 1
    }
    return out
}
