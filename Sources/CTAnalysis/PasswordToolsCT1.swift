import Foundation
import CTCommon

/// CT1 parity layer for "Passwort-Qualitätsmesser" (`DlgPasswordQualityMeter.cpp`,
/// `passwordchecker.cpp`), "Passwort-Richtlinien" (`DlgPasswordGuidelines.cpp`) and
/// "Passwörter mit bestimmter Entropie erzeugen" (`DlgPasswordEntropy.cpp`).
extension PasswordTools {

    // MARK: Password entropy dialog

    /// "Keine verwechselbaren Zeichen verwenden (schriftliche Übertragung)".
    public static let ct1NonConfusableWrittenAlphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPRSTUVWXYZ23456789"
    /// "Keine verwechselbaren Zeichen verwenden (telefonische Übertragung)".
    public static let ct1NonConfusableTelephonicAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    /// "Alphabet für WLAN-Passwörter verwenden (64 Zeichen)".
    public static let ct1WLANAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+,-./:=?@[]^_{}~"

    /// CT1 `CheckBoxesAlphabetChanged`: the alphabet is the intersection of all checked sets (in the
    /// order text alphabet, written, telephonic, WLAN); if nothing is checked, `current` is kept.
    public static func ct1EntropyAlphabet(textAlphabet: String, useTextAlphabet: Bool, nonConfusableWritten: Bool,
                                          nonConfusableTelephonic: Bool, wlan: Bool, current: String) -> String {
        let sets = [(useTextAlphabet, textAlphabet), (nonConfusableWritten, ct1NonConfusableWrittenAlphabet),
                    (nonConfusableTelephonic, ct1NonConfusableTelephonicAlphabet), (wlan, ct1WLANAlphabet)]
            .filter { $0.0 }.map { $0.1 }
        guard var result = sets.first else { return current }
        for s in sets { result = String(result.filter { s.contains($0) }) }
        return result
    }

    /// CT1 `EditPasswordAlphabetChanged`: removes duplicates, keeping the last occurrence of each
    /// character ("ABCA" → "BCA").
    public static func ct1RemovingDuplicates(_ alphabet: String) -> String {
        let chars = Array(alphabet)
        var out = ""
        for (i, c) in chars.enumerated() where !chars[(i + 1)...].contains(c) { out.append(c) }
        return out
    }

    /// CT1 `updatePasswordLength`: ⌈bits / log2(|alphabet|)⌉; nil (empty field) for length 0 or an
    /// alphabet with fewer than two characters.
    public static func ct1PasswordLength(entropyBits: Int, alphabetSize: Int) -> Int? {
        guard alphabetSize > 1, entropyBits > 0 else { return nil }
        let n = Int(ceil(Double(entropyBits) / log2(Double(alphabetSize))))
        return n > 0 ? n : nil
    }

    /// Random password of `length` characters of `alphabet` (CT1 uses `rand()`; here the system CSPRNG).
    public static func ct1RandomPassword(length: Int, alphabet: String) -> String {
        let chars = Array(alphabet)
        guard !chars.isEmpty, length > 0 else { return "" }
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count, using: &rng)] })
    }

    // MARK: Password quality meter

    /// CT1 evaluates the CrypTool measure and the dictionary resistance on the first 32 characters.
    public static let ct1CheckerLength = 32
    /// Special characters CT1's checker uses when no guideline is stored.
    public static let ct1DefaultSpecialCharacters = "^°!\"§$%&/()=?´`\\<>|,;:.-_#'+*~@"

    /// CT1 removes all characters ≤ ' ' from the input field.
    public static func ct1CleanPassword(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.filter { $0.value > 0x20 }))
    }

    /// Everything CT1's password quality meter shows.
    public struct CT1QualityReport: Sendable {
        public let length: Int
        public let keePass: Int, mozilla: Int, pgp: Int, crypTool: Int
        /// CT1's pattern-aware entropy of the first 32 characters (bits).
        public let crypToolEntropy: Double
        /// Cheapest decomposition, e.g. "pass + wort + 1".
        public let components: String
        /// Text of "Resistenz gegen Wörterbuch-Attacken" (lines separated by "\n").
        public let resistance: String
        public let compliant: Bool

        /// Average of the four measures (basis of the pictogram).
        public var average: Int { (keePass + mozilla + pgp + crypTool) / 4 }
        /// Pictogram 0 = poor, 1 = low, 2 = average, 3 = high, 4 = great (CT1 thresholds 25/50/75/90).
        public var level: Int {
            let a = average
            if a > 90 { return 4 }
            if a > 75 { return 3 }
            if a > 50 { return 2 }
            if a > 25 { return 1 }
            return 0
        }
        public var keePassText: String { "\(keePass) % (\(keePass * 128 / 100) Bits)" }
        public var mozillaText: String { "\(mozilla) %" }
        public var pgpText: String { "\(pgp) % (\(pgp * 128 / 100) Bits)" }
        public var crypToolText: String { "\(crypTool) % (\(crypTool * 128 / 100) Bits)" }
        /// "(Die CrypTool-PQM-Methode bewertet nur die ersten 32 Zeichen)" is shown only for longer passwords.
        public var showsTruncationNote: Bool { length > PasswordTools.ct1CheckerLength }
    }

    /// CT1 password quality meter (`UpdateUserInterface` + `checkPassword`). `hidePassword` replaces
    /// the found substrings by '*' as CT1 does while "Passwort im Klartext anzeigen" is off.
    public static func ct1Quality(of password: String, policy: Policy = Policy(specialCharacters: ct1DefaultSpecialCharacters),
                                  hidePassword: Bool = false) -> CT1QualityReport {
        let full = Array(password)
        let pw = Array(full.prefix(ct1CheckerLength))
        let n = pw.count

        // compliance (on the truncated password)
        let digits = pw.filter { "1234567890".contains($0) }.count
        let specials = pw.filter { policy.specialCharacters.contains($0) }.count
        var text = "Passwort-Richtlinie erfüllt:\n"
        var compliant = true
        if n < policy.minimumLength { compliant = false; text += "- Nein (Passwort ist zu kurz: \(n)/\(policy.minimumLength))\n" }
        if digits < policy.minimumDigits { compliant = false; text += "- Nein (Passwort enthält zu wenig Ziffern: \(digits)/\(policy.minimumDigits))\n" }
        if specials < policy.minimumSpecials { compliant = false; text += "- Nein (Passwort enthält zu wenig Sonderzeichen: \(specials)/\(policy.minimumSpecials))\n" }
        if compliant { text += "- Ja\n" }

        // weak substrings
        let lowered: [Character] = pw.map { c in
            let l = String(c).lowercased()
            return l.count == 1 ? l.first! : c
        }
        var flags = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: n + 1)
        if n >= 3 {
            for len in 3...n {
                for j in 0...(n - len) {
                    let sub = Array(lowered[j..<(j + len)])
                    var f = 0
                    if ct1IsPattern(sub) { f |= CT1Flag.pattern }
                    if ct1IsSequence(sub) { f |= CT1Flag.serial }
                    if ct1IsKeyboardSequence(sub) { f |= CT1Flag.keyboard }
                    if isDictionaryWord(String(sub)) { f |= CT1Flag.dict }
                    flags[j][len] = f
                }
            }
        }
        // closure: concatenations of adjacent finds
        var stack: [(j: Int, i: Int)] = []
        for i in 0...n { for j in 0...n where flags[j][i] != 0 { stack.append((j, i)) } }
        while let (j, i) = stack.popLast() {
            guard j + i <= n, n > 3 else { continue }
            for k in 3..<n where flags[j + i][k] != 0 && flags[j][i + k] == 0 {
                flags[j][i + k] |= CT1Flag.closure
                stack.append((j, i + k))
            }
        }

        let (entropy, components) = ct1Entropy(pw, flags: flags)

        // remove finds contained in larger ones
        func cleanUp(_ check: Int, _ remove: Int) {
            for j in 0...n {
                for i in 0...n where flags[j][i] & remove != 0 {
                    search: for l in 0...j {
                        let kMin = i + (j - l)
                        guard kMin <= n else { continue }
                        for k in kMin...n where flags[l][k] & check != 0 && !(l == j && k == i) {
                            flags[j][i] -= remove
                            break search
                        }
                    }
                }
            }
        }
        cleanUp(CT1Flag.pattern, CT1Flag.pattern)
        cleanUp(CT1Flag.serial, CT1Flag.serial)
        cleanUp(CT1Flag.keyboard, CT1Flag.keyboard)
        cleanUp(CT1Flag.dict, CT1Flag.dict)
        cleanUp(CT1Flag.pattern | CT1Flag.serial | CT1Flag.keyboard | CT1Flag.dict | CT1Flag.composed | CT1Flag.closure, CT1Flag.closure)

        func list(_ flag: Int) -> String {
            var items: [String] = []
            for j in 0...n {
                for i in 0...n where flags[j][i] & flag != 0 {
                    items.append(hidePassword ? String(repeating: "*", count: i) : String(full[j..<(j + i)]))
                }
            }
            return items.isEmpty ? " -" : items.joined(separator: ", ")
        }
        text += "\nRekonstruktion aus Wörtern, Folgen und Mustern:"
        text += "\nGefunden: " + list(CT1Flag.closure)
        text += "\nMuster: " + list(CT1Flag.pattern)
        text += "\nFolgen: " + list(CT1Flag.serial)
        text += "\nTastatur-Folgen: " + list(CT1Flag.keyboard)
        text += "\nWörterbuch-Einträge [\(ct1GroupedNumber(dictionarySize))]: " + list(CT1Flag.dict)

        let crypTool = min(100, Int(floor(entropy / 128 * 100)))
        return CT1QualityReport(length: full.count,
                                keePass: min(100, qualityKeePass(password)), mozilla: min(100, qualityMozilla(password)),
                                pgp: min(100, qualityPGP(password)), crypTool: crypTool,
                                crypToolEntropy: entropy, components: components, resistance: text, compliant: compliant)
    }

    /// German digit grouping as CT1's `createStringNumberWithDigitGrouping` ("1999" → "1.999").
    public static func ct1GroupedNumber(_ v: Int) -> String {
        var s = String(v)
        var i = s.count - 3
        while i > 0 { s.insert(".", at: s.index(s.startIndex, offsetBy: i)); i -= 3 }
        return s
    }

    // MARK: internals (passwordchecker.cpp)

    private enum CT1Flag {
        static let pattern = 1, serial = 2, keyboard = 4, dict = 8, composed = 16, closure = 32
    }

    /// `PasswordEntropyChecker`: cheapest description of the password (bits) and its components.
    private static func ct1Entropy(_ pw: [Character], flags: [[Int]]) -> (Double, String) {
        let n = pw.count
        guard n > 0 else { return (0, "") }
        let space = alphabetSize(of: String(pw))
        let bitsPerChar = space > 0 ? log2(Double(space)) : 0
        let dictionaryWordEntropy = Self.dictionaryWordEntropy   // CT1: ln(size of the cracklib dictionary), fallback 14
        var best = (0...n).map { Double(($0 + 1) * 8) }
        best[0] = 0
        var pred = [Int](repeating: 0, count: n + 1)
        for start in 0..<n {
            let e = best[start]
            if e + bitsPerChar < best[start + 1] { best[start + 1] = e + bitsPerChar; pred[start + 1] = start }
            guard n - start >= 2 else { continue }
            for len in 2...(n - start) {
                let f = flags[start][len]
                let charBits = log2(Double(max(alphabetSize(of: String(pw[start..<(start + len)])), 1)))
                var delta = Double(len) * 8
                if f & (CT1Flag.pattern | CT1Flag.serial | CT1Flag.keyboard) != 0 { delta = min(delta, 2 * charBits + Double(len - 2)) }
                if f & CT1Flag.dict != 0 { delta = min(delta, dictionaryWordEntropy) }
                if delta < Double(len) * 8 && e + delta < best[start + len] {
                    best[start + len] = e + delta
                    pred[start + len] = start
                }
            }
        }
        var parts: [String] = []
        var pos = n
        while pos > 0 { parts.append(String(pw[pred[pos]..<pos])); pos = pred[pos] }
        return (best[n], parts.reversed().joined(separator: " + "))
    }

    /// `checkPasswordAgainstPatterns`: dates (cracklib classes d/p/s) or a repeated prefix of length 2 … 10.
    public static func ct1IsPattern(_ s: [Character]) -> Bool {
        func cls(_ p: Character, _ c: Character) -> Bool {
            switch p {
            case "d": return c.isASCII && c.isNumber
            case "p": return ".`,:;'!?\"".contains(c)
            case "s": return "$%^&*()-_+=|\\[]{}#@/~".contains(c)
            default: return p == c
            }
        }
        for p in ["ddpddpdddd", "ddpddpdd", "ddsddsdddd", "ddsddsdd"] where p.count == s.count {
            if zip(p, s).allSatisfy({ cls($0, $1) }) { return true }
        }
        let n = s.count
        guard n >= 4 else { return false }
        for i in 2...min(n / 2, 10) {
            var ok = true
            for k in i..<n where s[k] != s[k % i] { ok = false; break }
            if ok { return true }
        }
        return false
    }

    /// `checkPasswordAgainstSequences`: the whole substring ascends, descends or repeats one code.
    public static func ct1IsSequence(_ s: [Character]) -> Bool {
        let codes = s.map { $0.unicodeScalars.first.map { Int($0.value) } ?? -1 }
        var endMax = 0
        for delta in -1...1 {
            var i = 1, p = 0
            while p + 1 < codes.count && codes[p] == codes[p + 1] + delta { i += 1; p += 1 }
            if i > 2 && i > endMax { endMax = i }
        }
        return endMax >= s.count
    }

    /// CT1's German keyboard rows.
    private static let ct1KeyboardRows: [[Character]] = [
        "^1234567890ß", "°!\"§$%&/()=?", "qwertzuiopü+", "QWERTZUIOPÜ*", "asdfghjklöä#", "ASDFGHJKLÖÄ'",
        "<yxcvbnm,.-", ">YXCVBNM;:_",
    ].map { Array($0) }

    /// `checkPasswordAgainstKeyboardSequences` including CT1's limits (a backwards run stops before
    /// the first key of a row).
    public static func ct1IsKeyboardSequence(_ s: [Character]) -> Bool {
        guard let first = s.first else { return false }
        var endMax = 0
        for delta in [-1, 1] {
            for row in ct1KeyboardRows {
                guard var idx = row.firstIndex(of: first) else { continue }
                var i = 0, p = 0
                while p < s.count && idx >= 0 && idx < row.count && s[p] == row[idx] {
                    p += 1; idx += delta; i += 1
                    if idx == 0 || idx >= row.count { break }
                }
                if i > 2 && i > endMax { endMax = i }
            }
        }
        return endMax >= s.count
    }
}
