import Foundation
import CTCommon

/// Internal fast front end of `CTCommon.AlphabetMapper` (same semantics as
/// `TextOptions.indices(of:)` / `TextOptions.mapLetters`): ASCII characters and the lower-case
/// output characters are precomputed once, everything else is delegated to `AlphabetMapper.lookup`.
struct LetterTable {
    let characters: [Character]
    let size: Int
    private let mapper: AlphabetMapper
    private let ascii: [Int16]          // single-scalar ASCII characters: alphabet index or -1
    private let asciiLower: [Bool]
    private let lowerOutput: [Character]
    let keepCase: Bool
    let distinguishCase: Bool
    let keepNonAlphabet: Bool

    init(options: TextOptions) {
        mapper = options.makeMapper()
        characters = mapper.characters
        size = mapper.size
        keepCase = options.keepCase
        distinguishCase = options.distinguishCase
        keepNonAlphabet = options.keepNonAlphabet
        var a = [Int16](repeating: -1, count: 128)
        var al = [Bool](repeating: false, count: 128)
        for v in 0..<128 {
            if let (i, lower) = mapper.lookup(Character(Unicode.Scalar(UInt8(v)))) {
                a[v] = Int16(i)
                al[v] = lower
            }
        }
        ascii = a
        asciiLower = al
        let m = mapper
        lowerOutput = (0..<size).map { m.character(at: $0, lowercase: true) }
    }

    @inline(__always)
    func lookup(_ ch: Character) -> (index: Int, lower: Bool)? {
        let scalars = ch.unicodeScalars
        if scalars.count == 1, let s = scalars.first, s.value < 128 {
            let v = ascii[Int(s.value)]
            return v >= 0 ? (Int(v), asciiLower[Int(s.value)]) : nil
        }
        guard let (i, lower) = mapper.lookup(ch) else { return nil }
        return (i, lower)
    }

    @inline(__always)
    func character(at index: Int, lowercase: Bool) -> Character {
        lowercase ? lowerOutput[index] : characters[index]
    }

    /// Alphabet indices of all alphabet letters in `text`.
    func indices(_ text: String) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(text.utf8.count)
        for ch in text {
            if let (i, _) = lookup(ch) { out.append(i) }
        }
        return out
    }

    /// Indices with `-1` for every non-alphabet character (used where word boundaries matter).
    func indicesWithGaps(_ text: String) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(text.utf8.count)
        for ch in text {
            if let (i, _) = lookup(ch) { out.append(i) } else { out.append(-1) }
        }
        return out
    }

    /// Like `TextOptions.mapLetters`, but crash-safe.
    func mapLetters(_ text: String, _ transform: (_ index: Int, _ position: Int) -> Int) -> String {
        let n = size
        guard n > 0 else { return text }
        var out = String()
        out.reserveCapacity(text.utf8.count)
        var position = 0
        for ch in text {
            if let (idx, lower) = lookup(ch) {
                var r = transform(idx, position) % n
                if r < 0 { r += n }
                out.append(character(at: r, lowercase: lower))
                position += 1
            } else if keepNonAlphabet {
                out.append(ch)
            }
        }
        return out
    }

    func string(from indices: [Int]) -> String {
        guard size > 0 else { return "" }
        var s = String()
        s.reserveCapacity(indices.count)
        for i in indices { s.append(characters[((i % size) + size) % size]) }
        return s
    }
}

// MARK: - Small helpers

@inline(__always)
func mod(_ a: Int, _ n: Int) -> Int {
    let r = a % n
    return r < 0 ? r + n : r
}

/// Deterministic, fast PRNG (SplitMix64) – used where reproducibility matters (tests, restarts).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Formats a double with a fixed number of decimals (decimal point, as the English CT1).
func fmt(_ x: Double, _ decimals: Int = 4) -> String {
    String(format: "%.\(decimals)f", x)
}
