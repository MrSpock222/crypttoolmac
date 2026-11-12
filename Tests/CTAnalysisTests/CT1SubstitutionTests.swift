import Foundation
import CTCommon
import CTAnalysis

/// CT1 substitution analyses (manual / automatic incl. "Methode 2") – called from main.swift.
func runCT1SubstitutionTests() {
    section("CT1 Substitutionsanalyse")

    func words(_ name: String) -> [[Int8]] {
        let url = repoRoot.appendingPathComponent("Resources/Words/\(name)")
        let s = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return CT1SubstHart.words(fromList: s)
    }
    func example(_ name: String) -> String {
        let url = repoRoot.appendingPathComponent("Resources/Examples/\(name)")
        guard let d = try? Data(contentsOf: url) else { return "" }
        return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .windowsCP1252) ?? ""
    }
    /// Encrypts A–Z (case kept) with `key[p]` = ciphertext index; other characters unchanged.
    func encrypt(_ text: String, _ key: [Int]) -> String {
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            let v = s.value
            if v >= 65 && v <= 90 { out.append(Unicode.Scalar(UInt8(65 + key[Int(v) - 65]))) } else if v >= 97 && v <= 122 { out.append(Unicode.Scalar(UInt8(97 + key[Int(v) - 97]))) } else { out.append(s) }
        }
        return String(out)
    }
    /// Fraction of letters of `plain` that `mapping` decrypts correctly (unknown = wrong) and the
    /// number of wrongly assigned letters of the mapping.
    func quality(_ plain: String, _ key: [Int], _ mapping: [Int]) -> (correct: Double, wrongAssignments: Int) {
        let dec = CT1SubstJakobsen.invert(key)   // ciphertext → plaintext
        var wrong = 0
        for c in 0..<26 where mapping[c] >= 0 && mapping[c] != dec[c] { wrong += 1 }
        var total = 0, ok = 0
        for s in plain.uppercased().unicodeScalars where s.value >= 65 && s.value <= 90 {
            let p = Int(s.value) - 65
            total += 1
            if mapping[key[p]] == p { ok += 1 }
        }
        return (total > 0 ? Double(ok) / Double(total) : 0, wrong)
    }
    /// Deterministic generator (reproducible test keys).
    struct LCG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state ^ (state >> 29) }
    }
    var rng = LCG(state: 0xC0FFEE)
    func randomKey() -> [Int] { Array(0..<26).shuffled(using: &rng) }

    // --- word lists
    let de = words("SubstitutionAnalysisMethod2-de.txt"), en = words("SubstitutionAnalysisMethod2-en.txt")
    check(de.count == 106 && en.count == 135, "CT1 word lists \(de.count)/\(en.count)")

    // --- manual dialog text handling
    let sym = CT1SubstText.symbols("Ab, c\nÄß!", convertUmlauts: true)
    check(sym == [0, 1, 26, 2, 26, 0, 4, 18, 18], "symbols with umlauts \(sym)")
    check(CT1SubstText.symbols("Ab,\nc", convertUmlauts: false) == [0, 1, 2], "symbols raw")
    var m = [Int](repeating: -1, count: 26)
    m[0] = 4; m[1] = 13   // a → E, b → N
    check(CT1SubstText.display(CT1SubstText.symbols("ab c", convertUmlauts: true), mapping: m) == "EN c", "display")
    check(CT1SubstText.output("Ab-c ab\nBä", mapping: m, convertUmlauts: true) == "En-c en\nNee", "output \(CT1SubstText.output("Ab-c ab\nBä", mapping: m, convertUmlauts: true))")
    check(CT1SubstText.titleKey(m) == "****A********B************", "title key \(CT1SubstText.titleKey(m))")
    check(CT1SubstText.mapping(fromTitleKey: CT1SubstText.titleKey(m)) == m, "title key round trip")
    let ck = CT1SubstText.copyKey(m)
    check(ck == "ENABCDFGHIJKLMOPQRSTUVWXYZ", "copy key \(ck)")
    check(CT1SubstText.invertAlphabet(ck).hasPrefix("CDEF") && CT1SubstText.invertAlphabet(ck)[CT1SubstText.invertAlphabet(ck).index(CT1SubstText.invertAlphabet(ck).startIndex, offsetBy: 4)] == "A", "invert alphabet")

    // --- Verfahren 2 (Hart): German example text, word boundaries kept
    let startDe = CT1SubstText.transcribed(example("Startbeispiel-de.txt"))
    check(startDe.count > 500, "Startbeispiel-de.txt loaded")
    for (opt1, opt2) in [(false, false), (true, false), (true, true)] {
        let key = randomKey()
        let cipher = encrypt(startDe, key)
        let (r, t) = timed { CT1SubstHart.analyze(cipher, wordList: de, assumeE: opt1, extended: opt2) }
        let q = quality(startDe, key, r.mapping)
        print(String(format: "  Hart DE (e: %@, erweitert: %@): %.1f %% korrekt, %d falsch, %d Klassen, Score %d, %.2f s",
                     opt1 ? "ja" : "nein", opt2 ? "ja" : "nein", q.correct * 100, q.wrongAssignments, r.patternClasses, r.score, t))
        // the extended analysis (CT1 heuristics for n, r, i) may guess wrong letters
        check(opt2 ? q.correct >= 0.4 : (q.correct >= 0.7 && q.wrongAssignments <= 2), "Hart German e=\(opt1) ext=\(opt2): \(q)")
        check(!isRelease || t < 20, "Hart German runtime \(t)")
    }
    // German legal text (reference file), first ~1500 characters
    let deText = CT1SubstText.transcribed(String(german.prefix(1500)))
    do {
        let key = randomKey()
        let r = CT1SubstHart.analyze(encrypt(deText, key), wordList: de, assumeE: true, extended: false)
        let q = quality(deText, key, r.mapping)
        check(q.correct >= 0.65 && q.wrongAssignments <= 2, "Hart German legal text: \(q)")
    }
    // English
    let enText = String(english.prefix(1500))
    do {
        let key = randomKey()
        let (r, t) = timed { CT1SubstHart.analyze(encrypt(enText, key), wordList: en, assumeE: false, extended: false) }
        let q = quality(enText, key, r.mapping)
        print(String(format: "  Hart EN: %.1f %% korrekt, %d falsch, %.2f s", q.correct * 100, q.wrongAssignments, t))
        check(q.correct >= 0.75 && q.wrongAssignments <= 2, "Hart English: \(q)")
    }
    // the manual dialog's result of the Hart mapping reproduces the plaintext (upper case = known)
    do {
        let key = randomKey()
        let cipher = encrypt(startDe, key)
        let r = CT1SubstHart.analyze(cipher, wordList: de, assumeE: true, extended: false)
        let out = CT1SubstText.output(cipher, mapping: r.mapping, convertUmlauts: true)
        check(out.count == startDe.count, "output keeps the layout")
        let ok = zip(out.uppercased(), startDe.uppercased()).filter { $0 == $1 }.count
        check(Double(ok) / Double(max(1, out.count)) > 0.7, "output mostly decrypted")
        // cancellation
        let token = CancellationToken(); token.cancel()
        check(CT1SubstHart.analyze(cipher, wordList: de, assumeE: false, extended: false, cancel: token).cancelled, "Hart cancel")
    }
    // without spaces Verfahren 2 cannot work (only one long "word")
    do {
        let key = randomKey()
        let r = CT1SubstHart.analyze(encrypt(startDe, key).filter { $0 != " " && $0 != "\n" && $0 != "\r\n" }, wordList: de, assumeE: false, extended: false)
        check(r.patternClasses <= 1, "no word boundaries → no classes (\(r.patternClasses))")
    }

    // --- Verfahren 1 (Jakobsen)
    let j26 = CT1SubstJakobsen(spaceInAlphabet: false)
    let j27 = CT1SubstJakobsen(spaceInAlphabet: true)
    check(j26.guessLanguage(String(german.suffix(20000))) == .german, "language guess German")
    check(j26.guessLanguage(String(english.suffix(20000))) == .english, "language guess English")
    // CT1 normalises by all symbols incl. the removed space → German texts are usually detected as
    // English when the space is part of the alphabet (only the initial key depends on it).
    _ = j27.guessLanguage(String(german.suffix(20000)))
    check(j26.validCharacterCount("Ab c!") == 3 && j27.validCharacterCount("Ab c!") == 4, "valid characters")
    let refDe = String(german.prefix(german.count * 7 / 10)), testDe = CT1SubstText.transcribed(String(german.suffix(6000)))
    let refEn = String(english.prefix(english.count * 7 / 10)), testEn = String(english.suffix(6000))
    let stdDe = j26.referenceMatrix(refDe), stdEn = j26.referenceMatrix(refEn)
    approx(Double(stdDe.reduce(0, +)), 1, 1e-3, "reference digram matrix sums to 1")
    for (name, text, std, lang) in [("DE", testDe, stdDe, CT1SubstLanguage.german), ("EN", testEn, stdEn, CT1SubstLanguage.english)] {
        let key = randomKey()
        let cipher = encrypt(text, key)
        check(j26.guessLanguage(cipher) == lang, "Jakobsen language \(name)")
        let (r, t) = timed { j26.analyze(cipher, referenceMatrix: std, language: lang) }
        let q = quality(text, key, CT1SubstJakobsen.invert(r.key))
        print(String(format: "  Jakobsen %@: %.1f %% korrekt, %d Verbesserungen, %.2f s", name, q.correct * 100, r.improvements, t))
        check(q.correct >= 0.8, "Jakobsen \(name) solves long text: \(q.correct)")
        // decrypting with the found key = applying the mapping
        let d = j26.decrypt(cipher, key: r.key)
        check(d.count == cipher.count, "Jakobsen decrypt keeps layout")
        let ok = zip(d, text).filter { $0 == $1 }.count
        check(Double(ok) / Double(text.count) >= 0.8, "Jakobsen decrypt text \(name)")
        // deterministic like CT1
        check(j26.analyze(cipher, referenceMatrix: std, language: lang).key == r.key, "Jakobsen deterministic")
    }
    // space substituted (27 symbols)
    do {
        var key27 = Array(0..<27); key27.shuffle(using: &rng)
        let plain = testDe.uppercased()
        var out = String.UnicodeScalarView()
        for s in plain.unicodeScalars {
            if s.value >= 65 && s.value <= 90 { let c = key27[Int(s.value) - 65]; out.append(c == 26 ? " " : Unicode.Scalar(UInt8(65 + c))) } else if s == " " { let c = key27[26]; out.append(c == 26 ? " " : Unicode.Scalar(UInt8(65 + c))) } else { out.append(s) }
        }
        let cipher = String(out)
        let r = j27.analyze(cipher, reference: refDe, language: .german)
        let d = j27.decrypt(cipher, key: r.key)
        let ok = zip(d, plain).filter { $0 == $1 }.count
        print(String(format: "  Jakobsen DE mit Leerzeichen: %.1f %% korrekt", Double(ok) * 100 / Double(plain.count)))
        check(Double(ok) / Double(plain.count) >= 0.7, "Jakobsen with substituted space")
        check(CT1SubstJakobsen.keyString(r.key).count == 27, "key string 27")
    }
}
