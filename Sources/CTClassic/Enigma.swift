import CTCommon

/// Enigma rotors (Wehrmacht/Luftwaffe I–V, Kriegsmarine VI–VIII).
public enum EnigmaRotor: String, CaseIterable, Codable, Sendable {
    case I, II, III, IV, V, VI, VII, VIII

    /// Wiring (output for input A…Z at ring setting A, position A).
    public var wiring: String {
        switch self {
        case .I: return "EKMFLGDQVZNTOWYHXUSPAIBRCJ"
        case .II: return "AJDKSIRUXBLHWTMCQGZNPYFVOE"
        case .III: return "BDFHJLCPRTXVZNYEIWGAKMUSQO"
        case .IV: return "ESOVPZJAYQUIRHXLNFTGKDCMWB"
        case .V: return "VZBRGITYUPSDNHLXAWMJQOFECK"
        case .VI: return "JPGVOUMFYQBENHZRDKASXLICTW"
        case .VII: return "NZJHGRCXMYSWBOUFAIVLPEKQDT"
        case .VIII: return "FKQHTLXOCBJSPDZRAMEWNIUYGV"
        }
    }

    /// Window letters at which the rotor causes its left neighbour to step (turnover notch).
    public var notches: String {
        switch self {
        case .I: return "Q"
        case .II: return "E"
        case .III: return "V"
        case .IV: return "J"
        case .V: return "Z"
        case .VI, .VII, .VIII: return "ZM"
        }
    }
}

/// Reflectors (Umkehrwalzen). With a fourth (Greek) rotor the thin variants are used (M4).
public enum EnigmaReflector: String, CaseIterable, Codable, Sendable {
    case B, C

    public var wiring: String {
        switch self {
        case .B: return "YRUHQSLDPXNGOKMIEBFZCWVJAT"
        case .C: return "FVPJIAOYEDRZXWGCTKUQSBNMHL"
        }
    }

    /// Thin reflector for the M4 (B dünn / C dünn).
    public var thinWiring: String {
        switch self {
        case .B: return "ENKQAUYWJICOPBLMDXZVFTHRGS"
        case .C: return "RDOBJNTKVEHMLFCWZAXGYIPSUQ"
        }
    }
}

/// Greek rotors of the Kriegsmarine M4 (do not step).
public enum EnigmaGreekRotor: String, CaseIterable, Codable, Sendable {
    case beta, gamma

    public var wiring: String {
        switch self {
        case .beta: return "LEYJVCNIXWPBQMDRTAKZGFUHOS"
        case .gamma: return "FSOKANUERHMBTIYCWLQPZXVGJD"
        }
    }
}

/// Enigma I / M3 (three rotors, reflector B or C, plugboard) with correct double stepping, and
/// optionally the M4 (additional non-stepping Greek rotor with thin reflector).
///
/// Ring settings and positions are 0-based letter numbers (A = 0 … Z = 25; ring setting "01" = 0),
/// listed left to right. Only the letters A–Z are processed (umlauts are not transcribed); the
/// output is uppercase, all other characters are dropped.
public struct Enigma: Sendable {
    public let rotors: [EnigmaRotor]
    public let reflector: EnigmaReflector
    public let ringSettings: [Int]
    public let greekRotor: EnigmaGreekRotor?
    public let greekRing: Int
    public let plugboard: [(Character, Character)]
    /// Current rotor positions (left → right, 0…25).
    public private(set) var positions: [Int]
    public private(set) var greekPosition: Int

    private let forward: [[Int]]
    private let backward: [[Int]]
    private let notchSets: [[Bool]]
    private let reflect: [Int]
    private let plug: [Int]
    private let greekForward: [Int]
    private let greekBackward: [Int]

    /// Creates an Enigma. `rotors` left → right (three distinct rotors), `ringSettings` and
    /// `positions` 0…25 each. Plugboard: up to 13 pairs of different letters, each letter at most
    /// once. For an M4 pass `greekRotor` (with its ring setting and position).
    public init(rotors: [EnigmaRotor], reflector: EnigmaReflector, ringSettings: [Int], positions: [Int],
                plugboard: [(Character, Character)], greekRotor: EnigmaGreekRotor? = nil,
                greekRing: Int = 0, greekPosition: Int = 0) throws {
        guard rotors.count == 3 else { throw CTError("The Enigma requires exactly three rotors.") }
        guard Set(rotors).count == 3 else { throw CTError("Each rotor may only be used once.") }
        guard ringSettings.count == 3, positions.count == 3 else {
            throw CTError("A ring setting and an initial position are required for each of the three rotors.")
        }
        var plug = Array(0..<26)
        var used = Set<Int>()
        guard plugboard.count <= 13 else { throw CTError("The plugboard allows at most 13 plug connections.") }
        for (a, b) in plugboard {
            guard let x = latinLetterValue(a), let y = latinLetterValue(b) else {
                throw CTError("Plug connections may only connect the letters A-Z (\"\(a)\(b)\").")
            }
            guard x != y else { throw CTError("A letter cannot be plugged to itself (\"\(a)\(b)\").") }
            guard !used.contains(x), !used.contains(y) else {
                throw CTError("Each letter may only be used once on the plugboard (\"\(a)\(b)\").")
            }
            used.insert(x); used.insert(y)
            plug[x] = y; plug[y] = x
        }
        self.rotors = rotors
        self.reflector = reflector
        self.ringSettings = ringSettings.map { mod($0, 26) }
        self.positions = positions.map { mod($0, 26) }
        self.greekRotor = greekRotor
        self.greekRing = mod(greekRing, 26)
        self.greekPosition = mod(greekPosition, 26)
        self.plugboard = plugboard.map { (asciiUppercased($0.0), asciiUppercased($0.1)) }
        self.plug = plug
        func tables(_ wiring: String) -> ([Int], [Int]) {
            let f = wiring.unicodeScalars.map { Int($0.value) - 65 }
            var b = [Int](repeating: 0, count: 26)
            for (i, v) in f.enumerated() { b[v] = i }
            return (f, b)
        }
        var fw: [[Int]] = [], bw: [[Int]] = [], ns: [[Bool]] = []
        for r in rotors {
            let (f, b) = tables(r.wiring)
            fw.append(f); bw.append(b)
            var n = [Bool](repeating: false, count: 26)
            for s in r.notches.unicodeScalars { n[Int(s.value) - 65] = true }
            ns.append(n)
        }
        forward = fw; backward = bw; notchSets = ns
        reflect = (greekRotor == nil ? reflector.wiring : reflector.thinWiring).unicodeScalars.map { Int($0.value) - 65 }
        if let g = greekRotor { (greekForward, greekBackward) = tables(g.wiring) } else { (greekForward, greekBackward) = ([], []) }
    }

    /// Convenience: ring settings, positions and plugboard as letters ("AAA", "ADU", "AB CD EF").
    public init(rotors: [EnigmaRotor], reflector: EnigmaReflector, rings: String, start: String, plugboard: String = "") throws {
        let r = rings.compactMap(latinLetterValue), s = start.compactMap(latinLetterValue)
        guard r.count == 3, s.count == 3 else {
            throw CTError("Ring setting and initial position must each contain three letters.")
        }
        try self.init(rotors: rotors, reflector: reflector, ringSettings: r, positions: s,
                      plugboard: try Enigma.parsePlugboard(plugboard))
    }

    /// Parses plugboard pairs such as "AB CD EF" (letters are paired in order, other characters ignored).
    public static func parsePlugboard(_ s: String) throws -> [(Character, Character)] {
        let letters = s.filter { latinLetterValue($0) != nil }.map(asciiUppercased)
        guard letters.count % 2 == 0 else { throw CTError("The plugboard must consist of pairs of letters.") }
        return stride(from: 0, to: letters.count, by: 2).map { (letters[$0], letters[$0 + 1]) }
    }

    /// Current rotor positions as letters, e.g. "ADU" (with M4 the Greek rotor first).
    public var positionsString: String {
        var s = ""
        if greekRotor != nil { s.append(Character(Unicode.Scalar(UInt8(65 + greekPosition)))) }
        for p in positions { s.append(Character(Unicode.Scalar(UInt8(65 + p)))) }
        return s
    }

    /// Advances the rotors (before each key press), including the middle-rotor double step.
    public mutating func step() {
        let middleAtNotch = notchSets[1][positions[1]]
        let rightAtNotch = notchSets[2][positions[2]]
        if middleAtNotch { positions[0] = (positions[0] + 1) % 26 }
        if middleAtNotch || rightAtNotch { positions[1] = (positions[1] + 1) % 26 }
        positions[2] = (positions[2] + 1) % 26
    }

    @inline(__always)
    private func through(_ table: [Int], _ c: Int, position: Int, ring: Int) -> Int {
        let shift = position - ring
        return mod(table[mod(c + shift, 26)] - shift, 26)
    }

    /// Encrypts one letter value (0…25) without stepping.
    func encipher(_ input: Int) -> Int {
        var c = plug[input]
        for i in stride(from: 2, through: 0, by: -1) { c = through(forward[i], c, position: positions[i], ring: ringSettings[i]) }
        if greekRotor != nil { c = through(greekForward, c, position: greekPosition, ring: greekRing) }
        c = reflect[c]
        if greekRotor != nil { c = through(greekBackward, c, position: greekPosition, ring: greekRing) }
        for i in 0...2 { c = through(backward[i], c, position: positions[i], ring: ringSettings[i]) }
        return plug[c]
    }

    /// Encrypts (= decrypts) the letters of `text`; `groupSize` > 0 groups the output.
    public mutating func encrypt(_ text: String, groupSize: Int = 0) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        for ch in text {
            guard let v = latinLetterValue(ch) else { continue }
            step()
            out.append(Character(Unicode.Scalar(UInt8(65 + encipher(v)))))
        }
        return groupSize > 0 ? groupText(out, size: groupSize) : out
    }

    /// Same as `encrypt` (the Enigma is self-reciprocal).
    public mutating func decrypt(_ text: String, groupSize: Int = 0) -> String { encrypt(text, groupSize: groupSize) }
}
