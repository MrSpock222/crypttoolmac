import CTCommon

/// Reference letter frequencies (relative, A–Z; values sum to ≈ 1).
public enum LetterFrequencies {
    /// German letter frequencies (A–Z only, umlauts and ß not included; normalised).
    public static let german: [Character: Double] = normalize([
        "A": 6.51, "B": 1.89, "C": 3.06, "D": 5.08, "E": 17.40, "F": 1.66, "G": 3.01, "H": 4.76,
        "I": 7.55, "J": 0.27, "K": 1.21, "L": 3.44, "M": 2.53, "N": 9.78, "O": 2.51, "P": 0.79,
        "Q": 0.02, "R": 7.00, "S": 7.27, "T": 6.15, "U": 4.35, "V": 0.67, "W": 1.89, "X": 0.03,
        "Y": 0.04, "Z": 1.13,
    ])

    /// English letter frequencies (normalised).
    public static let english: [Character: Double] = normalize([
        "A": 8.167, "B": 1.492, "C": 2.782, "D": 4.253, "E": 12.702, "F": 2.228, "G": 2.015, "H": 6.094,
        "I": 6.966, "J": 0.153, "K": 0.772, "L": 4.025, "M": 2.406, "N": 6.749, "O": 7.507, "P": 1.929,
        "Q": 0.095, "R": 5.987, "S": 6.327, "T": 9.056, "U": 2.758, "V": 0.978, "W": 2.360, "X": 0.150,
        "Y": 1.974, "Z": 0.074,
    ])

    static func normalize(_ f: [Character: Double]) -> [Character: Double] {
        let sum = f.values.reduce(0, +)
        return f.mapValues { $0 / sum }
    }

    /// Relative frequencies of the alphabet letters in `text` (case folded according to the options).
    public static func measure(_ text: String, options: TextOptions) -> [Character: Double] {
        let m = LetterMapper(options)
        var counts = [Int](repeating: 0, count: m.size)
        var total = 0
        for ch in text { if let (i, _) = m.lookup(ch) { counts[i] += 1; total += 1 } }
        var out: [Character: Double] = [:]
        guard total > 0 else { return out }
        for (i, c) in counts.enumerated() { out[m.characters[i]] = Double(c) / Double(total) }
        return out
    }
}

/// Key of the homophone cipher: for every plaintext character the list of its codes (homophones).
public struct HomophoneKey: Codable, Equatable, Sendable {
    /// Plaintext character → codes (each code 0 ..< codeCount belongs to exactly one character).
    public var table: [Character: [Int]]
    /// Total number of codes (CT1 default 256).
    public var codeCount: Int

    public init(table: [Character: [Int]], codeCount: Int) {
        self.table = table
        self.codeCount = codeCount
    }

    /// Reverse table code → character.
    public var decryptionTable: [Int: Character] {
        var r: [Int: Character] = [:]
        for (ch, codes) in table { for c in codes { r[c] = ch } }
        return r
    }

    /// Checks that every code is used at most once and lies in 0 ..< codeCount.
    public func validate() throws {
        var seen = Set<Int>()
        for (ch, codes) in table {
            for c in codes {
                guard c >= 0 && c < codeCount else {
                    throw CTError("Der Code \(c) für „\(ch)“ liegt außerhalb des Bereichs 0…\(codeCount - 1).")
                }
                guard seen.insert(c).inserted else {
                    throw CTError("Der Code \(c) ist im Homophon-Schlüssel mehreren Zeichen zugeordnet.")
                }
            }
        }
    }

    /// Characters of the key sorted by alphabet order of the options (others appended).
    public func characters(options: TextOptions) -> [Character] {
        let alpha = options.alphabetCharacters
        let inAlpha = alpha.filter { table[$0] != nil }
        let rest = table.keys.filter { !alpha.contains($0) }.sorted()
        return inAlpha + rest
    }

    /// Human readable key ("A: 12, 200, 7 | B: …"), codes in decimal.
    public func description(options: TextOptions) -> String {
        characters(options: options).map { ch in
            "\(ch): " + (table[ch] ?? []).map(String.init).joined(separator: ",")
        }.joined(separator: " | ")
    }

    // Codable: Character is not Codable, encode as [String: [Int]].
    private enum CodingKeys: String, CodingKey { case table, codeCount }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([String: [Int]].self, forKey: .table)
        var t: [Character: [Int]] = [:]
        for (k, v) in raw {
            guard k.count == 1, let ch = k.first else {
                throw DecodingError.dataCorruptedError(forKey: .table, in: c, debugDescription: "Ungültiges Zeichen im Homophon-Schlüssel")
            }
            t[ch] = v
        }
        table = t
        codeCount = try c.decode(Int.self, forKey: .codeCount)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        var raw: [String: [Int]] = [:]
        for (k, v) in table { raw[String(k)] = v }
        try c.encode(raw, forKey: .table)
        try c.encode(codeCount, forKey: .codeCount)
    }
}

/// Output format of the homophone codes.
public enum HomophoneOutputFormat: String, CaseIterable, Codable, Sendable {
    /// Decimal numbers separated by spaces ("17 3 201").
    case decimal
    /// Hexadecimal numbers separated by spaces ("11 03 C9"), width according to the code count.
    case hex
    /// One character per code (U+0000 … U+00FF, requires ≤ 256 codes) – the bytes CT1 wrote into
    /// its binary output document for 256 codes.
    case bytes

    public var displayName: String {
        switch self {
        case .decimal: return "Dezimal"
        case .hex: return "Hexadezimal"
        case .bytes: return "Bytes"
        }
    }
}

/// Homophone substitution (CT1 "Homophone"): every alphabet character gets a number of codes
/// proportional to its frequency; encryption picks one of them at random.
public enum Homophone {
    public static let germanFrequencies = LetterFrequencies.german
    public static let englishFrequencies = LetterFrequencies.english

    /// Generates a key for the alphabet of `options` (CT1 `Make_enc_table` + `Generate_key`):
    /// character i gets ⌊codeCount · fᵢ⌋ codes (at least 1); the sum is then corrected to exactly
    /// `codeCount` by repeatedly adding a code to the character with the largest fᵢ·N/countᵢ
    /// resp. removing one from the character with the smallest ratio. The codes are distributed
    /// randomly. Without frequencies all characters are weighted equally. `codeCount` is raised to
    /// the alphabet size if necessary.
    public static func generateKey(options: TextOptions, letterFrequencies: [Character: Double]?, codeCount: Int = 256) -> HomophoneKey {
        let alpha = options.alphabetCharacters
        let n = alpha.count
        guard n > 0 else { return HomophoneKey(table: [:], codeCount: max(codeCount, 0)) }
        let size = max(codeCount, n)
        let m = LetterMapper(options)
        // frequencies per alphabet index (keys of the table may use other case)
        var freq = [Double](repeating: 0, count: n)
        if let lf = letterFrequencies {
            for (ch, f) in lf where f > 0 {
                if let (i, _) = m.lookup(ch) { freq[i] += f }
            }
            let sum = freq.reduce(0, +)
            if sum > 0 { freq = freq.map { $0 / sum } } else { freq = [Double](repeating: 1.0 / Double(n), count: n) }
        } else {
            freq = [Double](repeating: 1.0 / Double(n), count: n)
        }
        let counts = allocate(frequencies: freq, total: size)
        var codes = Array(0..<size)
        codes.shuffle()
        var table: [Character: [Int]] = [:]
        var p = 0
        for i in 0..<n {
            table[alpha[i]] = Array(codes[p..<(p + counts[i])])
            p += counts[i]
        }
        return HomophoneKey(table: table, codeCount: size)
    }

    /// Number of codes per character (CT1 algorithm), sum == total (total ≥ count of frequencies).
    public static func allocate(frequencies freq: [Double], total size: Int) -> [Int] {
        let n = freq.count
        var cnt = [Int](repeating: 0, count: n)
        var fixed = [Bool](repeating: false, count: n)
        for i in 0..<n {
            cnt[i] = max(Int((Double(size) * freq[i]).rounded(.down)), 0)
            if cnt[i] == 0 { cnt[i] = 1; fixed[i] = true }
        }
        var sum = cnt.reduce(0, +)
        while sum != size {
            if sum < size {
                var best = -1, value = 0.0001
                for i in 0..<n where freq[i] > 0 && !fixed[i] {
                    let v = freq[i] * Double(size) / Double(cnt[i])
                    if v > value { value = v; best = i }
                }
                if best < 0 { best = (0..<n).max { cnt[$0] > cnt[$1] } ?? 0 }  // fallback (all fixed)
                cnt[best] += 1
                sum += 1
            } else {
                var best = -1, value = Double.greatestFiniteMagnitude
                for i in 0..<n where freq[i] > 0 && !fixed[i] && cnt[i] > 1 {
                    let v = freq[i] * Double(size) / Double(cnt[i])
                    if v < value { value = v; best = i }
                }
                if best < 0 { best = (0..<n).max { cnt[$0] < cnt[$1] } ?? 0 }
                guard cnt[best] > 1 else { break }
                cnt[best] -= 1
                sum -= 1
            }
        }
        return cnt
    }

    /// Encrypts the alphabet characters of `text` (case folded according to the options; other
    /// characters are skipped, like CT1). With `transcribeUmlauts` ä/ö/ü/ß are first replaced by
    /// ae/oe/ue/ss (CT1 option "Umlaute kodieren").
    public static func encrypt(_ text: String, key: HomophoneKey, options: TextOptions, transcribeUmlauts: Bool = false) -> [Int] {
        let m = LetterMapper(options)
        // lookup by alphabet index
        var codesByIndex = [[Int]](repeating: [], count: m.size)
        for (ch, codes) in key.table { if let i = m.characters.firstIndex(of: ch) { codesByIndex[i] = codes } }
        var rng = SystemRandomNumberGenerator()
        var out: [Int] = []
        out.reserveCapacity(text.count)
        func emit(_ ch: Character) {
            if let (i, _) = m.lookup(ch) {
                let c = codesByIndex[i]
                if !c.isEmpty { out.append(c[Int.random(in: 0..<c.count, using: &rng)]) }
            } else if let c = key.table[ch], !c.isEmpty {
                out.append(c[Int.random(in: 0..<c.count, using: &rng)])
            }
        }
        for ch in text {
            if transcribeUmlauts, let t = umlautTranscription(ch) { for c in t { emit(c) } } else { emit(ch) }
        }
        return out
    }

    /// Decrypts codes (unknown codes are skipped).
    public static func decrypt(_ codes: [Int], key: HomophoneKey) -> String {
        let table = key.decryptionTable
        return String(codes.compactMap { table[$0] })
    }

    /// Formats codes. For `.hex` the digit count is chosen for `codeCount` (default 256 → 2 digits).
    public static func format(_ codes: [Int], as format: HomophoneOutputFormat, codeCount: Int = 256) -> String {
        switch format {
        case .decimal:
            return codes.map(String.init).joined(separator: " ")
        case .hex:
            let width = max(2, String(max(codeCount - 1, 0), radix: 16).count)
            return codes.map { c in
                let h = String(c, radix: 16, uppercase: true)
                return String(repeating: "0", count: max(0, width - h.count)) + h
            }.joined(separator: " ")
        case .bytes:
            return String(String.UnicodeScalarView(codes.compactMap { Unicode.Scalar(UInt32(max(0, min($0, 255)))) }))
        }
    }

    /// Parses codes written by `format`. Separators: whitespace, commas, semicolons.
    public static func parse(_ text: String, as format: HomophoneOutputFormat) throws -> [Int] {
        switch format {
        case .decimal, .hex:
            let radix = format == .decimal ? 10 : 16
            var out: [Int] = []
            for token in text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }) {
                guard let v = Int(token, radix: radix), v >= 0 else {
                    throw CTError("„\(token)“ ist kein gültiger \(radix == 10 ? "Dezimal" : "Hexadezimal")-Code.")
                }
                out.append(v)
            }
            return out
        case .bytes:
            var out: [Int] = []
            for s in text.unicodeScalars {
                guard s.value <= 255 else {
                    throw CTError("Das Zeichen „\(s)“ ist kein gültiger Byte-Code (U+0000 … U+00FF).")
                }
                out.append(Int(s.value))
            }
            return out
        }
    }

    /// CT1 binary representation: codes packed with ⌈log₂ codeCount⌉ bits each, least significant
    /// bits first (for 256 codes simply one byte per code).
    public static func pack(_ codes: [Int], codeCount: Int) -> [UInt8] {
        let bits = bitLength(codeCount)
        var out: [UInt8] = []
        var acc: UInt64 = 0
        var accBits = 0
        for c in codes {
            acc |= UInt64(c & ((1 << bits) - 1)) << UInt64(accBits)
            accBits += bits
            while accBits >= 8 { out.append(UInt8(acc & 0xFF)); acc >>= 8; accBits -= 8 }
        }
        if accBits > 0 { out.append(UInt8(acc & 0xFF)) }
        return out
    }

    /// Inverse of `pack` (trailing bits that do not form a full code are ignored).
    public static func unpack(_ bytes: [UInt8], codeCount: Int) -> [Int] {
        let bits = bitLength(codeCount)
        var out: [Int] = []
        var acc: UInt64 = 0
        var accBits = 0
        for b in bytes {
            acc |= UInt64(b) << UInt64(accBits)
            accBits += 8
            while accBits >= bits { out.append(Int(acc & ((1 << UInt64(bits)) - 1))); acc >>= UInt64(bits); accBits -= bits }
        }
        return out
    }

    /// Number of bits per code for the given code count.
    public static func bitLength(_ codeCount: Int) -> Int {
        var b = 1
        while (1 << b) < codeCount { b += 1 }
        return b
    }
}
