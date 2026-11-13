import Foundation
import CTCommon

/// Password quality meter and password entropy / generator (CT1 "Einzelverfahren ▸ Tools ▸
/// Passwort-Qualitätsmesser" and "Passwort-Entropie").
public enum PasswordTools {

    /// Result of the password quality meter.
    public struct PasswordQuality: Sendable {
        /// Overall quality 0 … 100 = average of the four CT1 measures (KeePass, Mozilla, PGP, CrypTool).
        public let score: Int
        /// Pattern-aware entropy estimate in bits (CT1's "CrypTool" measure, H. Koy).
        public let entropyBits: Double
        /// "sehr schwach", "schwach", "mittel", "stark" or "sehr stark" (CT1 thresholds 25/50/75/90).
        public let level: String
        /// Remarks: policy compliance, found patterns, sequences, keyboard sequences,
        /// dictionary words and the cheapest reconstruction of the password.
        public let remarks: [String]
        /// Quality according to KeePass (character space · length, 128 bit = 100).
        public let qualityKeePass: Int
        /// Quality according to Mozilla (rule based).
        public let qualityMozilla: Int
        /// Quality according to PGP (mean of minimum and maximum entropy estimate, 128 bit = 100).
        public let qualityPGP: Int
        /// Quality according to CrypTool (`entropyBits`, 128 bit = 100).
        public let qualityCrypTool: Int
        /// The password decomposed into its cheapest components, e.g. "pass + wort + 1 + 2".
        public let components: String
        /// True if the password fulfils the default password policy (≥ 8 characters, ≥ 1 digit,
        /// ≥ 1 special character).
        public let compliant: Bool

        public init(score: Int, entropyBits: Double, level: String, remarks: [String],
                    qualityKeePass: Int = 0, qualityMozilla: Int = 0, qualityPGP: Int = 0, qualityCrypTool: Int = 0,
                    components: String = "", compliant: Bool = false) {
            self.score = score
            self.entropyBits = entropyBits
            self.level = level
            self.remarks = remarks
            self.qualityKeePass = qualityKeePass
            self.qualityMozilla = qualityMozilla
            self.qualityPGP = qualityPGP
            self.qualityCrypTool = qualityCrypTool
            self.components = components
            self.compliant = compliant
        }
    }

    /// Password policy (CT1 defaults: minimum length 8, at least one digit and one special character).
    public struct Policy: Sendable {
        public var minimumLength: Int
        public var minimumDigits: Int
        public var minimumSpecials: Int
        public var specialCharacters: String
        public init(minimumLength: Int = 8, minimumDigits: Int = 1, minimumSpecials: Int = 1,
                    specialCharacters: String = "^°!\"§$%&/()=?´`\\<>|,;:.-_#'+*~@") {
            self.minimumLength = minimumLength
            self.minimumDigits = minimumDigits
            self.minimumSpecials = minimumSpecials
            self.specialCharacters = specialCharacters
        }
    }

    /// Alphabet presets for the password generator. The first four entries are character classes,
    /// followed by combinations and the special alphabets of CT1's "Passwort-Entropie" dialog.
    public static let alphabetPresets: [(name: String, characters: String)] = [
        ("Lowercase letters", lower),
        ("Uppercase letters", upper),
        ("Numerals", digits),
        ("Special characters", specials),
        ("Lowercase and uppercase letters", lower + upper),
        ("Lowercase letters and numerals", lower + digits),
        ("Letters and numerals", upper + lower + digits),
        ("Letters, numerals and special characters", upper + lower + digits + specials),
        ("Hexadecimal digits", "0123456789ABCDEF"),
        ("Non-confusable characters (written transmission)", "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPRSTUVWXYZ23456789"),
        ("Non-confusable characters (telephonic transmission)", "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"),
        ("WLAN alphabet", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+,-./:=?@[]^_{}~"),
        ("CrypTool default alphabet", TextOptions.uppercaseLetters),
    ]

    private static let lower = "abcdefghijklmnopqrstuvwxyz"
    private static let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let digits = "0123456789"
    private static let specials = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"

    // MARK: Entropy / generator

    /// Size of the character space of a password as used by KeePass and CT1: lower case letters 26,
    /// upper case 26, digits 10, simple specials (space … '/') 16, other ASCII specials 17,
    /// characters beyond ASCII 112, control characters 60 – summed over the classes present.
    public static func alphabetSize(of password: String) -> Int {
        var set = 0
        for u in password.unicodeScalars { set |= keePassClass(u) }
        return keePassCharSpace(set)
    }

    /// Entropy in bits of a password of `length` characters chosen uniformly at random from an
    /// alphabet of `alphabetSize` characters: length · log2(alphabetSize).
    public static func entropy(length: Int, alphabetSize: Int) -> Double {
        guard length > 0, alphabetSize > 1 else { return 0 }
        return Double(length) * log2(Double(alphabetSize))
    }

    /// Number of characters needed to reach `entropyBits` with the given alphabet size
    /// (CT1: ⌈bits / log2(n)⌉).
    public static func requiredLength(entropyBits: Double, alphabetSize: Int) -> Int {
        guard alphabetSize > 1, entropyBits > 0 else { return 0 }
        return Int(ceil(entropyBits / log2(Double(alphabetSize)) - 1e-12))
    }

    /// Generates a password with at least `entropyBits` bits of entropy from the distinct characters
    /// of `alphabet`, using the system CSPRNG (uniform, no modulo bias). Empty if the alphabet has
    /// fewer than two distinct characters.
    public static func generate(entropyBits: Double, alphabet: String) -> String {
        var seen = Set<Character>()
        let chars = alphabet.filter { seen.insert($0).inserted }.map { $0 }
        guard chars.count > 1 else { return "" }
        let len = requiredLength(entropyBits: entropyBits, alphabetSize: chars.count)
        var rng = SystemRandomNumberGenerator()
        var out = String()
        for _ in 0..<len { out.append(chars[Int.random(in: 0..<chars.count, using: &rng)]) }
        return out
    }

    // MARK: Quality meter

    /// CT1 password quality meter. Combines four measures (KeePass, Mozilla, PGP and CT1's own
    /// pattern-aware entropy) to an average score and level. CT1 checks substrings against the
    /// cracklib dictionary; here a small built-in list of very common passwords and words is used.
    /// Like CT1, the CrypTool measure only considers the first 32 characters.
    public static func quality(of password: String, policy: Policy = Policy()) -> PasswordQuality {
        let pw = Array(password)
        let keePass = qualityKeePass(password)
        let mozilla = qualityMozilla(password)
        let pgp = qualityPGP(password)

        let truncated = Array(pw.prefix(32))
        let analysis = analyzeStructure(truncated)
        let crypTool = min(100, Int(floor(analysis.entropy / 128 * 100)))
        let score = (keePass + mozilla + pgp + crypTool) / 4

        var level = "very weak"
        if score > 25 { level = "weak" }
        if score > 50 { level = "medium" }
        if score > 75 { level = "strong" }
        if score > 90 { level = "very strong" }

        // remarks
        var remarks: [String] = []
        let digitsCount = pw.filter { $0.isASCII && $0.isNumber }.count
        let specialCount = pw.filter { policy.specialCharacters.contains($0) }.count
        var compliant = true
        if pw.isEmpty {
            remarks.append("No password entered.")
        }
        if pw.count < policy.minimumLength {
            compliant = false
            remarks.append("Not compliant with password guidelines: Password is too short (\(pw.count)/\(policy.minimumLength)).")
        }
        if digitsCount < policy.minimumDigits {
            compliant = false
            remarks.append("Not compliant with password guidelines: Password contains too few digits (\(digitsCount)/\(policy.minimumDigits)).")
        }
        if specialCount < policy.minimumSpecials {
            compliant = false
            remarks.append("Not compliant with password guidelines: Password contains too few special characters (\(specialCount)/\(policy.minimumSpecials)).")
        }
        if compliant { remarks.append("Compliant with password guidelines.") }
        func list(_ items: [String]) -> String { items.isEmpty ? "-" : items.joined(separator: ", ") }
        if !analysis.patterns.isEmpty { remarks.append("Patterns: " + list(analysis.patterns)) }
        if !analysis.sequences.isEmpty { remarks.append("Sequences: " + list(analysis.sequences)) }
        if !analysis.keyboard.isEmpty { remarks.append("Keyboard sequences: " + list(analysis.keyboard)) }
        if !analysis.words.isEmpty { remarks.append("Dictionary words: " + list(analysis.words)) }
        if !pw.isEmpty { remarks.append("Reconstruction from words, sequences and patterns: " + analysis.components) }
        if pw.count > 32 { remarks.append("Note: The CrypTool rating only considers the first 32 characters.") }
        let unique = Set(pw).count
        if pw.count >= 4 && unique * 2 <= pw.count { remarks.append("Many repeated characters (\(unique) different characters).") }

        return PasswordQuality(score: score, entropyBits: analysis.entropy, level: level, remarks: remarks,
                               qualityKeePass: keePass, qualityMozilla: mozilla, qualityPGP: pgp, qualityCrypTool: crypTool,
                               components: analysis.components, compliant: compliant)
    }

    /// KeePass quality: ⌈log2(charSpace) · length⌉ bits, 128 bits = 100.
    public static func qualityKeePass(_ password: String) -> Int {
        let len = password.unicodeScalars.count
        let space = alphabetSize(of: password)
        guard len > 0, space > 0 else { return 0 }
        let bits = Int(ceil(log2(Double(space)) * Double(len)))
        return bits > 128 ? 100 : bits * 100 / 128
    }

    /// Mozilla quality (rule based: length, digits, special characters, upper case letters).
    public static func qualityMozilla(_ password: String) -> Int {
        var len = 0, dig = 0, spe = 0, upp = 0
        for u in password.unicodeScalars {
            len += 1
            switch u.value {
            case 0x61...0x7A: break
            case 0x41...0x5A: upp += 1
            case 0x30...0x39: dig += 1
            default: spe += 1
            }
        }
        var q = 0
        if len >= 1 && len <= 5 { q += len * 10 }
        if len > 5 { q += 50 }
        q -= 20
        q += dig >= 1 && dig <= 3 ? dig * 10 : (dig > 3 ? 30 : 0)
        q += spe >= 1 && spe <= 3 ? spe * 15 : (spe > 3 ? 45 : 0)
        q += upp >= 1 && upp <= 3 ? upp * 10 : (upp > 3 ? 30 : 0)
        return max(0, min(100, q))
    }

    /// PGP quality: mean of the minimum and maximum entropy estimates of PGP's passphrase
    /// estimator, 128 bits = 100.
    public static func qualityPGP(_ password: String) -> Int {
        let codes = password.unicodeScalars.map { Int($0.value) }
        guard !codes.isEmpty else { return 0 }
        var minBits = 0
        for c in codes { minBits += sLog2(categoryLength(c)) }
        var have = [Bool](repeating: false, count: pgpRanges.count)
        var unrecognized = 0
        for c in codes {
            if let idx = category(c) { have[idx] = true } else { unrecognized += 1 }
        }
        var scope = unrecognized
        for (i, h) in have.enumerated() where h { scope += pgpRanges[i].total }
        let maxBits = codes.count * sLog2(scope)
        guard minBits <= maxBits else { return 0 }
        let result = minBits + (maxBits - minBits) / 2
        return result > 128 ? 100 : result * 100 / 128
    }

    // MARK: - internals: KeePass

    private static func keePassClass(_ u: Unicode.Scalar) -> Int {
        let v = u.value
        switch v {
        case 0..<0x20: return 64                    // escape / control
        case 0x41...0x5A: return 2                  // upper
        case 0x61...0x7A: return 1                  // lower
        case 0x30...0x39: return 4                  // digits
        case 0x20...0x2F: return 8                  // simple special
        case 0x3A...0x40, 0x5B...0x60, 0x7B...0x7E: return 16   // extended special
        default: return 32                          // high
        }
    }

    private static func keePassCharSpace(_ set: Int) -> Int {
        var s = 0
        if set & 64 != 0 { s += 60 }
        if set & 2 != 0 { s += 26 }
        if set & 1 != 0 { s += 26 }
        if set & 4 != 0 { s += 10 }
        if set & 8 != 0 { s += 16 }
        if set & 16 != 0 { s += 17 }
        if set & 32 != 0 { s += 112 }
        return s
    }

    private static func keePassSpace(_ chars: ArraySlice<Character>) -> Int {
        var set = 0
        for ch in chars { for u in ch.unicodeScalars { set |= keePassClass(u) } }
        return keePassCharSpace(set)
    }

    // MARK: internals: PGP

    private static let pgpRanges: [(base: Int, length: Int, total: Int)] = [
        (0x00, 32, 32), (0x20, 1, 1), (0x21, 3, 15), (0x24, 1, 1), (0x25, 3, 15), (0x28, 1, 3),
        (0x29, 1, 3), (0x2a, 1, 15), (0x2b, 1, 6), (0x2c, 1, 15), (0x2d, 1, 1), (0x2e, 2, 15),
        (0x30, 10, 10), (0x3a, 2, 15), (0x3c, 3, 6), (0x3f, 2, 15), (0x41, 26, 26), (0x5b, 1, 3),
        (0x5c, 1, 15), (0x5d, 1, 3), (0x5e, 1, 2), (0x5f, 1, 1), (0x60, 1, 2), (0x61, 26, 26),
        (0x7b, 1, 3), (0x7c, 1, 6), (0x7d, 1, 3), (0x7e, 1, 6), (0x7f, 33, 33),
    ]

    private static func category(_ c: Int) -> Int? {
        for (i, r) in pgpRanges.enumerated() where c >= r.base && c < r.base + r.length { return i }
        return nil
    }

    private static func categoryLength(_ c: Int) -> Int {
        category(c).map { pgpRanges[$0].total } ?? 1
    }

    /// PGP's rounded log2 (bit length, minus one if the value is closer to the lower power of two).
    private static func sLog2(_ c: Int) -> Int {
        guard c > 0 else { return 0 }
        let bits = Int.bitWidth - c.leadingZeroBitCount
        let mask1 = 1 << (bits - 1)
        return c - mask1 < mask1 / 2 ? bits - 1 : bits
    }

    // MARK: internals: CrypTool pattern analysis (H. Koy / F. Marchal)

    private struct Analysis {
        var entropy: Double
        var components: String
        var patterns: [String]
        var sequences: [String]
        var keyboard: [String]
        var words: [String]
    }

    private static let flagPattern = 1, flagSerial = 2, flagKeyboard = 4, flagDict = 8

    private static func analyzeStructure(_ pw: [Character]) -> Analysis {
        let n = pw.count
        guard n > 0 else { return Analysis(entropy: 0, components: "", patterns: [], sequences: [], keyboard: [], words: []) }
        let lowered: [Character] = pw.map { c in
            let l = String(c).lowercased()
            return l.count == 1 ? l.first! : c
        }
        // flags[j][i]: substring starting at j with length i
        var flags = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: n + 1)
        if n >= 3 {
            for len in 3...n {
                for j in 0...(n - len) {
                    let sub = Array(lowered[j..<(j + len)])
                    var f = 0
                    if isPattern(sub) { f |= flagPattern }
                    if isSequence(sub) { f |= flagSerial }
                    if isKeyboardSequence(sub) { f |= flagKeyboard }
                    if isDictionaryWord(String(sub)) { f |= flagDict }
                    flags[j][len] = f
                }
            }
        }

        // shortest "description" of the password (dynamic programming, CT1 PasswordEntropyChecker)
        let space = keePassSpace(pw[...])
        let bitsPerChar = space > 0 ? log2(Double(space)) : 0
        let dictionaryWordEntropy = Self.dictionaryWordEntropy   // CT1: ln(size of the cracklib dictionary), fallback 14
        var best = (0...n).map { Double(($0 + 1) * 8) }
        best[0] = 0
        var pred = [(from: Int, kind: Int)](repeating: (0, 0), count: n + 1)
        for start in 0..<n {
            let e = best[start]
            // single character
            if e + bitsPerChar < best[start + 1] {
                best[start + 1] = e + bitsPerChar
                pred[start + 1] = (start, 0)
            }
            if n - start >= 2 {
                for len in 2...(n - start) {
                    let f = flags[start][len]
                    guard f != 0 else { continue }
                    let charBits = log2(Double(max(keePassSpace(pw[start..<(start + len)]), 1)))
                    var delta = Double(len) * 8
                    if f & (flagPattern | flagSerial | flagKeyboard) != 0 {
                        delta = min(delta, 2 * charBits + Double(len - 2))
                    }
                    if f & flagDict != 0 { delta = min(delta, dictionaryWordEntropy) }
                    if delta < Double(len) * 8 && e + delta < best[start + len] {
                        best[start + len] = e + delta
                        pred[start + len] = (start, f)
                    }
                }
            }
        }
        var parts: [String] = []
        var pos = n
        while pos > 0 {
            let p = pred[pos]
            parts.append(String(pw[p.from..<pos]))
            pos = p.from
        }
        let components = parts.reversed().joined(separator: " + ")

        // maximal found substrings per category (CT1 removes substrings contained in larger finds)
        func maximal(_ flag: Int) -> [String] {
            var found: [(Int, Int)] = []
            for j in 0..<n { for len in 0...(n - j) where flags[j][len] & flag != 0 { found.append((j, len)) } }
            let kept = found.filter { a in
                !found.contains { b in (b.0 != a.0 || b.1 != a.1) && b.0 <= a.0 && b.0 + b.1 >= a.0 + a.1 }
            }
            return kept.map { String(pw[$0.0..<($0.0 + $0.1)]) }
        }
        return Analysis(entropy: best[n], components: components,
                        patterns: maximal(flagPattern), sequences: maximal(flagSerial),
                        keyboard: maximal(flagKeyboard), words: maximal(flagDict))
    }

    /// Dates like dd.dd.dddd / dd/dd/dd or repetitions of a prefix of length 2 … 10 ("abcabc").
    private static func isPattern(_ s: [Character]) -> Bool {
        for p in ["ddpddpdddd", "ddpddpdd", "ddsddsdddd", "ddsddsdd"] where matchesClassPattern(Array(p), s) { return true }
        let n = s.count
        if n >= 4 {
            for i in 2...min(n / 2, 10) {
                var ok = true
                for k in i..<n where s[k] != s[k % i] { ok = false; break }
                if ok { return true }
            }
        }
        return false
    }

    private static func matchesClassPattern(_ pattern: [Character], _ s: [Character]) -> Bool {
        guard pattern.count == s.count else { return false }
        for (p, c) in zip(pattern, s) {
            switch p {
            case "d": if !(c.isASCII && c.isNumber) { return false }
            case "p": if !".`,:;'!?\"".contains(c) { return false }
            case "s": if !"$%^&*()-_+=|\\[]{}#@/~".contains(c) { return false }
            default: if p != c { return false }
            }
        }
        return true
    }

    /// Ascending, descending or constant run of character codes ("abc", "987", "aaa").
    private static func isSequence(_ s: [Character]) -> Bool {
        guard s.count >= 3 else { return false }
        let codes = s.map { $0.unicodeScalars.first.map { Int($0.value) } ?? -1 }
        for delta in -1...1 {
            var ok = true
            for k in 1..<codes.count where codes[k] != codes[k - 1] + delta { ok = false; break }
            if ok { return true }
        }
        return false
    }

    /// German keyboard rows (as in CT1), forwards or backwards.
    private static let keyboardRows: [[Character]] = [
        "^1234567890ß", "°!\"§$%&/()=?", "qwertzuiopü+", "QWERTZUIOPÜ*", "asdfghjklöä#", "ASDFGHJKLÖÄ'",
        "<yxcvbnm,.-", ">YXCVBNM;:_", "qwertyuiop", "asdfghjkl", "zxcvbnm",
    ].map { Array($0) }

    private static func isKeyboardSequence(_ s: [Character]) -> Bool {
        guard s.count >= 3 else { return false }
        for row in keyboardRows {
            guard let start = row.firstIndex(of: s[0]) else { continue }
            for delta in [-1, 1] {
                var idx = start
                var ok = true
                for k in 1..<s.count {
                    idx += delta
                    if idx < 0 || idx >= row.count || row[idx] != s[k] { ok = false; break }
                }
                if ok { return true }
            }
        }
        return false
    }

    /// Small built-in replacement for the cracklib dictionary: very common passwords and words
    /// (lower case, length ≥ 3).
    static let commonWords: Set<String> = {
        let list = """
        password passwort passwd pass word wort kennwort geheim secret admin administrator root user login \
        welcome willkommen hallo hello letmein master qwerty qwertz azerty abc abcd iloveyou love liebe \
        ichliebedich schatz schatzi baby angel engel dragon drache monkey affe shadow sunshine sonne \
        princess prinzessin football fussball fußball baseball soccer hockey batman superman starwars pokemon \
        computer internet test testing sommer winter herbst fruehling frühling summer autumn spring \
        montag dienstag januar februar maerz april mai juni juli august september oktober november dezember \
        january february march june july october december monday friday sunday \
        berlin hamburg muenchen münchen koeln köln frankfurt stuttgart darmstadt siegen bayern borussia \
        schalke deutschland germany london paris america amerika \
        michael thomas andreas stefan daniel peter klaus hans juergen jürgen markus alexander christian \
        anna julia lisa maria sabine petra nicole sandra laura sarah jennifer jessica ashley robert david \
        john james william charlie george jordan hunter killer pepper ginger buster tigger \
        hund katze maus pferd tiger baer bär blume baum haus auto vogel fisch \
        cat dog mouse horse bird fish tree house flower \
        crypt crypto cryptool krypto kryptologie cipher chiffre key schluessel schlüssel \
        freedom freiheit trustno1 whatever nothing nichts something access zugang hallo123 \
        mustang ferrari porsche harley yamaha honda \
        matrix ninja hacker cookie banane banana apple apfel orange cherry kirsche \
        summer2024 winter2024 password1 passwort1 \
        one two three four five six seven eight nine ten eins zwei drei vier fuenf fünf sechs sieben acht neun zehn \
        red blue green black white rot blau gruen grün schwarz weiss weiß gelb \
        god gott jesus heaven himmel hell hoelle hölle \
        friend freund freundin family familie mother mutter father vater sister schwester brother bruder \
        money geld gold silver silber diamond diamant star stern moon mond sun \
        music musik rock metal jazz guitar gitarre piano klavier \
        game spiel player spieler winner gewinner lucky glueck glück magic zauber \
        open offen close change aendern ändern default standard system server database datenbank \
        office buero büro firma company work arbeit school schule student
        """
        return Set(list.split(whereSeparator: { $0 == " " || $0 == "\n" }).map { String($0) }.filter { $0.count >= 3 })
    }()
}
