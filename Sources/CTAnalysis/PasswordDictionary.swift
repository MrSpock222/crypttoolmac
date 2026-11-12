import Foundation

/// CT1 checks password substrings against the cracklib dictionary (1.65 million words, shipped
/// with CT1 as `words/cracklib-words`). The word list is kept as one sorted byte buffer with a
/// line index and searched binarily, which needs far less memory than a `Set<String>`.
public final class PasswordDictionary: @unchecked Sendable {
    private let data: [UInt8]
    private let offsets: [Int32]

    /// - Parameter sortedWordList: newline separated words, sorted by bytes (as cracklib-words).
    public init(sortedWordList: [UInt8]) {
        data = sortedWordList
        var o: [Int32] = []
        o.reserveCapacity(sortedWordList.count / 9)
        var start = 0
        for (i, b) in sortedWordList.enumerated() where b == 0x0A {
            if i > start { o.append(Int32(start)) }
            start = i + 1
        }
        if start < sortedWordList.count { o.append(Int32(start)) }
        offsets = o
    }

    public var count: Int { offsets.count }

    private func entry(at i: Int) -> ArraySlice<UInt8> {
        let s = Int(offsets[i])
        var e = s
        while e < data.count && data[e] != 0x0A { e += 1 }
        return data[s..<e]
    }

    public func contains(_ word: String) -> Bool {
        let key = Array(word.utf8)
        var lo = 0, hi = offsets.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let w = entry(at: mid)
            if w.elementsEqual(key) { return true }
            if w.lexicographicallyPrecedes(key) { lo = mid + 1 } else { hi = mid - 1 }
        }
        return false
    }
}

extension PasswordTools {
    /// The cracklib dictionary, set by the app once it is loaded. Without it a small built-in
    /// list is used (CT1's fallback entropy of 14 bit per dictionary word).
    nonisolated(unsafe) public static var dictionary: PasswordDictionary?

    static func isDictionaryWord(_ s: String) -> Bool {
        if let d = dictionary { return d.contains(s) }
        return commonWords.contains(s)
    }

    /// CT1: entropy of a dictionary word = ln(dictionary size), 14 if no dictionary is available.
    static var dictionaryWordEntropy: Double {
        if let d = dictionary, d.count > 0 { return log(Double(d.count)) }
        return 14.0
    }

    static var dictionarySize: Int { dictionary?.count ?? commonWords.count }
}
