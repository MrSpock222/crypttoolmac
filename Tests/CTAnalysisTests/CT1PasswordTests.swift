import Foundation
import CTCommon
import CTAnalysis

/// CT1 parity checks (Password) – called from main.swift.
func runCT1PasswordTests() {
    section("CT1 Password")
    typealias P = PasswordTools
    let dictSize = P.ct1GroupedNumber(dictionaryCount())

    // empty password (CT1 texts of checkPassword)
    let empty = P.ct1Quality(of: "")
    check(empty.resistance == """
    Compliant with password guidelines:
    - No (Password is too short: 0/8)
    - No (Password contains too few digits: 0/1)
    - No (Password contains too few special characters: 0/1)

    Reconstruction from words, sequences and patterns:
    Found:  -
    Patterns:  -
    Sequences:  -
    Keyboard sequences:  -
    Dictionary words [\(dictSize)]:  -
    """, "empty resistance: \(empty.resistance)")
    check(empty.keePassText == "0 % (0 bit)" && empty.mozillaText == "0 %" && empty.level == 0, "empty meters")

    // "abc123": sequences, keyboard run, dictionary word and their closure
    let r = P.ct1Quality(of: "abc123")
    check(r.resistance == """
    Compliant with password guidelines:
    - No (Password is too short: 6/8)
    - No (Password contains too few special characters: 0/1)

    Reconstruction from words, sequences and patterns:
    Found: abc123
    Patterns:  -
    Sequences: abc, 123
    Keyboard sequences: 123
    Dictionary words [\(dictSize)]: abc
    """, "abc123 resistance: \(r.resistance)")
    approx(r.crypToolEntropy, 2 * log2(26) + 1 + 2 * log2(10) + 1, 1e-9, "abc123 entropy")
    check(r.components == "abc + 123", "abc123 components \(r.components)")
    check(r.crypTool == 14 && r.crypToolText == "14 % (17 bit)", "abc123 CrypTool \(r.crypToolText)")
    check(r.keePass == 25 && r.keePassText == "25 % (32 bit)", "abc123 KeePass \(r.keePassText)")
    check(r.mozilla == 60 && r.mozillaText == "60 %", "abc123 Mozilla")
    check(r.pgp == P.qualityPGP("abc123"), "abc123 PGP")
    check(r.length == 6 && !r.compliant && !r.showsTruncationNote, "abc123 flags")

    // hidden password: CT1 shows '*' instead of the found substrings
    let hidden = P.ct1Quality(of: "abc123", hidePassword: true)
    check(hidden.resistance.contains("Found: ******\n") && hidden.resistance.contains("Sequences: ***, ***\n"), "hidden")

    // longer closure; "qwertz" is both a keyboard run and a dictionary word
    let k = P.ct1Quality(of: "abc123qwertz")
    check(k.resistance.contains("\nFound: abc123qwertz\n"), "closure: \(k.resistance)")
    check(k.resistance.contains("\nKeyboard sequences: 123, qwertz\n"), "keyboard: \(k.resistance)")
    check(k.resistance.hasSuffix("]: abc, qwertz"), "dictionary: \(k.resistance)")

    // compliance, guidelines and truncation
    let ok = P.ct1Quality(of: "Xy7!Qp9#Lm")
    check(ok.compliant && ok.resistance.hasPrefix("Compliant with password guidelines:\n- Yes\n\n"), "compliant")
    let strict = P.Policy(minimumLength: 12, minimumDigits: 3, minimumSpecials: 0, specialCharacters: "")
    let s = P.ct1Quality(of: "Xy7!Qp9#Lm", policy: strict)
    check(s.resistance.hasPrefix("Compliant with password guidelines:\n- No (Password is too short: 10/12)\n- No (Password contains too few digits: 2/3)\n\n"), "policy: \(s.resistance)")
    let long = String(repeating: "aZ5!", count: 10)
    let l = P.ct1Quality(of: long)
    check(l.length == 40 && l.showsTruncationNote, "truncation note")
    check(P.ct1Quality(of: long, policy: P.Policy(minimumLength: 40)).resistance.contains("too short: 32/40"), "compliance on 32 chars")

    // same CrypTool measure as the library for passwords without US keyboard rows
    for pw in ["abc123", "Passwort1!", "Xy7!Qp9#Lm", "12.03.1999abab", "hallo"] {
        check(P.ct1Quality(of: pw).crypTool == P.quality(of: pw).qualityCrypTool, "CrypTool measure \(pw)")
    }
    // pictogram thresholds (average of the four measures)
    check(P.ct1Quality(of: "Xy7!Qp9#Lm.Kw3$Zt8&").level >= 3, "strong password level")

    // CT1 substring checks
    check(P.ct1IsKeyboardSequence(Array("qwertz")) && !P.ct1IsKeyboardSequence(Array("qwerty")), "kbd qwertz/qwerty")
    check(P.ct1IsKeyboardSequence(Array("4321")) && !P.ct1IsKeyboardSequence(Array("321^")), "kbd backwards")
    check(!P.ct1IsKeyboardSequence(Array("ztrewq")), "kbd: CT1 stops before the first key of a row")
    check(P.ct1IsSequence(Array("abcd")) && P.ct1IsSequence(Array("cba")) && P.ct1IsSequence(Array("aaa")) && !P.ct1IsSequence(Array("abd")), "sequences")
    check(P.ct1IsPattern(Array("12.03.1999")) && P.ct1IsPattern(Array("abab")) && P.ct1IsPattern(Array("abcabc")) && !P.ct1IsPattern(Array("abcd")), "patterns")
    check(P.ct1CleanPassword("a b\tc\n") == "abc", "clean")
    check(P.ct1GroupedNumber(999) == "999" && P.ct1GroupedNumber(1999) == "1,999" && P.ct1GroupedNumber(1234567) == "1,234,567", "grouping")

    // password generator with given entropy
    let text = TextOptions.uppercaseLetters
    func alpha(_ t: Bool, _ w: Bool, _ ph: Bool, _ wl: Bool, current: String = "xyz") -> String {
        P.ct1EntropyAlphabet(textAlphabet: text, useTextAlphabet: t, nonConfusableWritten: w, nonConfusableTelephonic: ph, wlan: wl, current: current)
    }
    check(alpha(true, false, false, false) == text, "text alphabet")
    check(alpha(true, true, false, false) == "ABCDEFGHJKLMNPRSTUVWXYZ", "text ∩ written")
    check(alpha(true, false, true, false) == text, "text ∩ telephonic")
    check(alpha(false, true, false, true) == "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPRSTUVWXYZ", "written ∩ WLAN")
    check(alpha(false, false, false, true) == P.ct1WLANAlphabet, "WLAN")
    check(alpha(false, false, false, false) == "xyz", "none checked keeps alphabet")
    check(P.ct1RemovingDuplicates("ABCA") == "BCA" && P.ct1RemovingDuplicates("AABB") == "AB", "duplicates")
    check(P.ct1PasswordLength(entropyBits: 80, alphabetSize: 26) == 18, "length 80/26")
    check(P.ct1PasswordLength(entropyBits: 80, alphabetSize: 64) == 14, "length 80/64")
    check(P.ct1PasswordLength(entropyBits: 128, alphabetSize: 2) == 128, "length 128/2")
    check(P.ct1PasswordLength(entropyBits: 0, alphabetSize: 26) == nil && P.ct1PasswordLength(entropyBits: 80, alphabetSize: 1) == nil, "length empty")
    let pw = P.ct1RandomPassword(length: 18, alphabet: text)
    check(pw.count == 18 && pw.allSatisfy { text.contains($0) }, "random password")
    check(P.ct1RandomPassword(length: 5, alphabet: "") == "", "empty alphabet")
}

/// Size of the built-in dictionary as shown in "Wörterbuch-Einträge [n]".
private func dictionaryCount() -> Int {
    let t = PasswordTools.ct1Quality(of: "").resistance
    guard let a = t.range(of: "Dictionary words ["), let b = t.range(of: "]", range: a.upperBound..<t.endIndex) else { return 0 }
    return Int(t[a.upperBound..<b.lowerBound].replacingOccurrences(of: ".", with: "")) ?? 0
}
