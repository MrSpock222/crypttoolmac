import CTCommon

// CT1 "Skytale / Gartenzaun" (simple transpositions).
//
// Without text options all characters are transposed. With text options (CT1 behaviour) only the
// alphabet characters are transposed (the characters themselves are moved, including their case);
// all other characters either stay at their positions or are removed, depending on
// `keepNonAlphabet`. CT1 rejects keys ≤ 1 or ≥ the number of letters (see `isValidKey`); here
// such keys simply leave the text unchanged.

/// Splits text into the transposable characters and a function to re-insert them.
private func transposable(_ text: String, options: TextOptions?) -> (chars: [Character], rebuild: ([Character]) -> String) {
    guard let options = options else {
        return (Array(text), { String($0) })
    }
    let m = LetterMapper(options)
    let all = Array(text)
    let isLetter = all.map { m.lookup($0) != nil }
    let letters = zip(all, isLetter).filter { $0.1 }.map { $0.0 }
    let keep = options.keepNonAlphabet
    return (letters, { res in
        var out = String()
        var j = 0
        for (i, ch) in all.enumerated() {
            if isLetter[i] {
                if j < res.count { out.append(res[j]); j += 1 }
            } else if keep {
                out.append(ch)
            }
        }
        return out
    })
}

/// Scytale (Skytale): the text is written row by row around a rod with `circumference` rows
/// (CT1 "Schlüssel" = number of letters around the rod) and read off column by column.
/// `offset` = number of empty positions before the first letter (CT1 "Offset").
public enum Scytale {
    /// CT1 key check: 1 < key < number of transposed characters.
    public static func isValidKey(_ key: Int, forLength length: Int) -> Bool { key > 1 && key < length }

    /// Encrypts; `options` nil transposes all characters, otherwise only alphabet characters.
    public static func encrypt(_ text: String, circumference: Int, offset: Int = 0, options: TextOptions? = nil) -> String {
        let (chars, rebuild) = transposable(text, options: options)
        return rebuild(transform(chars, key: circumference, offset: offset, decrypt: false))
    }

    /// Decrypts (inverse of `encrypt` with the same parameters).
    public static func decrypt(_ text: String, circumference: Int, offset: Int = 0, options: TextOptions? = nil) -> String {
        let (chars, rebuild) = transposable(text, options: options)
        return rebuild(transform(chars, key: circumference, offset: offset, decrypt: true))
    }

    static func transform<T>(_ src: [T], key: Int, offset rawOffset: Int, decrypt: Bool) -> [T] {
        let len = src.count
        guard key > 1, key < len else { return src }
        var offset = max(0, min(rawOffset, len))
        var cols = (len + offset) / key
        if (len + offset) % key != 0 { cols += 1 }
        offset %= cols
        if !decrypt {
            // fill rows (row-major, `offset` empty cells first), read columns skipping empties
            var grid = [T?](repeating: nil, count: key * cols)
            for i in 0..<len { grid[offset + i] = src[i] }
            var out: [T] = []
            out.reserveCapacity(len)
            for c in 0..<cols { for r in 0..<key { if let v = grid[r * cols + c] { out.append(v) } } }
            return out
        } else {
            var grid = [T?](repeating: nil, count: key * cols)
            var p = 0
            for c in 0..<cols {
                for r in 0..<key {
                    let idx = r * cols + c
                    if idx < offset || idx - offset >= len { continue }
                    grid[idx] = src[p]; p += 1
                }
            }
            return grid.compactMap { $0 }
        }
    }
}

/// Rail fence (Gartenzaun): the text is written in a zigzag over `rails` rows and read row by row.
/// `offset` = number of zigzag positions skipped before the first letter (CT1 "Offset").
public enum RailFence {
    /// CT1 key check: 1 < rails < number of transposed characters.
    public static func isValidKey(_ key: Int, forLength length: Int) -> Bool { key > 1 && key < length }

    /// Encrypts; `options` nil transposes all characters, otherwise only alphabet characters.
    public static func encrypt(_ text: String, rails: Int, offset: Int = 0, options: TextOptions? = nil) -> String {
        let (chars, rebuild) = transposable(text, options: options)
        return rebuild(transform(chars, rails: rails, offset: offset, decrypt: false))
    }

    /// Decrypts (inverse of `encrypt` with the same parameters).
    public static func decrypt(_ text: String, rails: Int, offset: Int = 0, options: TextOptions? = nil) -> String {
        let (chars, rebuild) = transposable(text, options: options)
        return rebuild(transform(chars, rails: rails, offset: offset, decrypt: true))
    }

    /// Rail (0-based, top first) of zigzag position `index`.
    static func rail(_ index: Int, rails: Int) -> Int {
        let period = 2 * rails - 2
        let l = index % period
        return l < rails ? l : period - l
    }

    static func transform<T>(_ src: [T], rails: Int, offset rawOffset: Int, decrypt: Bool) -> [T] {
        let len = src.count
        guard rails > 1, len > 0 else { return src }
        let period = 2 * rails - 2
        let offset = mod(rawOffset, period)
        // positions of each text character on the fence, ordered rail by rail
        let railOf = (0..<len).map { rail($0 + offset, rails: rails) }
        var order: [Int] = []   // order[k] = text index of the k-th ciphertext character
        order.reserveCapacity(len)
        for r in 0..<rails { for i in 0..<len where railOf[i] == r { order.append(i) } }
        if !decrypt {
            return order.map { src[$0] }
        } else {
            var out = src
            for (k, i) in order.enumerated() { out[i] = src[k] }
            return out
        }
    }
}
