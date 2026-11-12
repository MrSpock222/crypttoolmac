import Foundation
import CTCommon
import CTClassic

// Minimal test harness (no XCTest available with the Command Line Tools).

var failures = 0
var checks = 0
var currentGroup = ""

func group(_ name: String, _ body: () throws -> Void) {
    currentGroup = name
    let before = failures
    do { try body() } catch { fail("unerwarteter Fehler: \(error)") }
    print((failures == before ? "✓ " : "✗ ") + name)
}

func fail(_ msg: String, file: StaticString = #file, line: UInt = #line) {
    failures += 1
    print("  FEHLER [\(currentGroup)] Zeile \(line): \(msg)")
}

func expect(_ cond: Bool, _ msg: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !cond { fail(msg(), file: file, line: line) }
}

func expectEqual<T: Equatable>(_ a: T, _ b: T, _ msg: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if a != b { fail("\(a) != \(b) \(msg())", file: file, line: line) }
}

func expectThrows(_ msg: String = "", file: StaticString = #file, line: UInt = #line, _ body: () throws -> Void) {
    checks += 1
    do { try body(); fail("Fehler erwartet: \(msg)", file: file, line: line) } catch {}
}

// MARK: - Option combinations and sample texts

let alphabets = [
    TextOptions.uppercaseLetters,
    TextOptions.uppercaseLetters + TextOptions.lowercaseLetters,
    TextOptions.uppercaseLetters + TextOptions.digits,
    TextOptions.uppercaseLetters + TextOptions.lowercaseLetters + TextOptions.digits + TextOptions.umlautsUpper + TextOptions.umlautsLower + " .,",
]

var optionSets: [TextOptions] = []
for a in alphabets {
    for dc in [false, true] { for kc in [false, true] { for kn in [false, true] {
        optionSets.append(TextOptions(alphabet: a, distinguishCase: dc, keepCase: kc, keepNonAlphabet: kn))
    } } }
}

let samples = [
    "Hello, World! Straße Ärger 123 xyz",
    "Der Schatz liegt unter der alten Eiche – 42 Schritte nach Norden.\r\nZweite Zeile: ÄÖÜ äöü ß ẞ 🙂 é",
    "ATTACKATDAWN",
    "",
    "a",
]

var rng = SystemRandomNumberGenerator()
let pool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,;:!?-ÄÖÜäöüßéè\n\t🙂")
func randomText(_ n: Int) -> String { String((0..<n).map { _ in pool.randomElement(using: &rng)! }) }
let allSamples = samples + (0..<6).map { _ in randomText(Int.random(in: 1...300, using: &rng)) }

/// Identity transformation with the same options (= what a round trip must give).
func normalized(_ s: String, _ o: TextOptions) -> String { Caesar.encrypt(s, shift: 0, options: o) }

/// CT1/TextOptions semantics: the case of a letter is a property of its *position*. If the
/// alphabet contains characters without case (digits, punctuation, ß …) a lowercase position may
/// receive such a character in the ciphertext and the case information is lost (CT1 behaves the
/// same). For such alphabets round trips are compared case-insensitively.
func hasUncasedCharacters(_ o: TextOptions) -> Bool {
    o.alphabetCharacters.contains { String($0).lowercased() == String($0).uppercased() || String($0).uppercased().count != 1 }
}

func expectRoundTrip(_ result: String, _ expected: String, _ o: TextOptions, _ msg: @autoclosure () -> String = "", line: UInt = #line) {
    checks += 1
    if result == expected { return }
    if !o.distinguishCase && o.keepCase && hasUncasedCharacters(o) && result.uppercased() == expected.uppercased() { return }
    fail("\(result.debugDescription) != \(expected.debugDescription) \(msg())", line: line)
}

// MARK: - Caesar / ROT13

group("Caesar") {
    let o = TextOptions.default
    expectEqual(Caesar.encrypt("HELLO", shift: 3, options: o), "KHOOR")
    expectEqual(Caesar.decrypt("KHOOR", shift: 3, options: o), "HELLO")
    expectEqual(Caesar.encrypt("Hello, World!", shift: 3, options: o), "Khoor, Zruog!")
    expectEqual(Caesar.encrypt("xyz", shift: 3, options: o), "abc")
    var o2 = o; o2.keepNonAlphabet = false
    expectEqual(Caesar.encrypt("Hello, World!", shift: 3, options: o2), "KhoorZruog")
    var o3 = o; o3.keepCase = false
    expectEqual(Caesar.encrypt("Hello", shift: 1, options: o3), "IFMMP")
    expectEqual(Caesar.shift(forKeyLetter: "D", options: o, firstLetterIsOne: false), 3)
    expectEqual(Caesar.shift(forKeyLetter: "d", options: o, firstLetterIsOne: false), 3)
    expectEqual(Caesar.shift(forKeyLetter: "D", options: o, firstLetterIsOne: true), 4)
    expectEqual(Caesar.shift(forKeyLetter: "Z", options: o, firstLetterIsOne: true), 0)
    expect(Caesar.shift(forKeyLetter: "!", options: o, firstLetterIsOne: false) == nil)
    expectEqual(Caesar.keyLetter(forShift: 4, options: o, firstLetterIsOne: true), "D")
    expectEqual(Caesar.rot13("Hello, World!"), "Uryyb, Jbeyq!")
    expectEqual(Caesar.rot13(Caesar.rot13("Straße")), "Straße")
    expectEqual(Caesar.targetAlphabet(shift: 3, options: o), "DEFGHIJKLMNOPQRSTUVWXYZABC")
    // distinguish case: lowercase letters are not in the alphabet
    var o4 = o; o4.distinguishCase = true
    expectEqual(Caesar.encrypt("Hello", shift: 1, options: o4), "Iello")
    for opt in optionSets {
        for s in allSamples {
            for k in [0, 1, 7, 25, 100, -3] {
                let c = Caesar.encrypt(s, shift: k, options: opt)
                expectRoundTrip(Caesar.decrypt(c, shift: k, options: opt), normalized(s, opt), opt, "Caesar k=\(k)")
            }
        }
    }
}

// MARK: - Vigenère & co.

group("Vigenère / Autokey / Beaufort / Affin") {
    let o = TextOptions.default
    expectEqual(try Vigenere.encrypt("ATTACKATDAWN", key: "LEMON", options: o), "LXFOPVEFRNHR")
    expectEqual(try Vigenere.decrypt("LXFOPVEFRNHR", key: "LEMON", options: o), "ATTACKATDAWN")
    expectEqual(try Vigenere.encrypt("attack at dawn", key: "le-mon!", options: o), "lxfopv ef rnhr")
    expectThrows("leerer Schlüssel") { _ = try Vigenere.encrypt("ABC", key: "123", options: o) }
    expectEqual(try VigenereAutokey.encrypt("ATTACKATDAWN", key: "QUEENLY", options: o), "QNXEPVYTWTWP")
    expectEqual(try VigenereAutokey.decrypt("QNXEPVYTWTWP", key: "QUEENLY", options: o), "ATTACKATDAWN")
    expectEqual(try Beaufort.encrypt("A", key: "K", options: o), "K")
    expectEqual(try Beaufort.encrypt("B", key: "K", options: o), "J")
    expectEqual(try Affine.encrypt("AFFINE CIPHER", a: 5, b: 8, options: o), "IHHWVC SWFRCP")
    expectEqual(try Affine.decrypt("IHHWVC SWFRCP", a: 5, b: 8, options: o), "AFFINE CIPHER")
    expectThrows("a nicht invertierbar") { _ = try Affine.encrypt("ABC", a: 13, b: 1, options: o) }
    for opt in optionSets {
        for s in allSamples {
            for key in ["KEY", "Lemon", "zz9"] {
                guard (try? Vigenere.keyShifts(key, options: opt)) != nil else { continue }
                let n = normalized(s, opt)
                expectRoundTrip(try Vigenere.decrypt(try Vigenere.encrypt(s, key: key, options: opt), key: key, options: opt), n, opt)
                expectRoundTrip(try VigenereAutokey.decrypt(try VigenereAutokey.encrypt(s, key: key, options: opt), key: key, options: opt), n, opt)
                expectRoundTrip(try Beaufort.decrypt(try Beaufort.encrypt(s, key: key, options: opt), key: key, options: opt), n, opt)
            }
            if let a = [3, 5, 7, 11].first(where: { (try? Affine.validate(a: $0, options: opt)) != nil }) {
                expectRoundTrip(try Affine.decrypt(try Affine.encrypt(s, a: a, b: 4, options: opt), a: a, b: 4, options: opt), normalized(s, opt), opt)
            }
        }
    }
}

// MARK: - Hill

group("Hill") {
    let o = TextOptions.default
    let k3 = HillCipher.matrix(fromKeyword: "GYBNQKURP", size: 3, options: o)!
    expectEqual(k3, [[6, 24, 1], [13, 16, 10], [20, 17, 15]])
    let h3 = try HillCipher(matrix: k3, options: o)
    expectEqual(h3.encrypt("ACT"), "POH")
    expectEqual(h3.encrypt("CAT"), "FIN")
    expectEqual(h3.decrypt("POH"), "ACT")
    let h2 = try HillCipher(matrix: [[3, 3], [2, 5]], options: o)
    expectEqual(h2.encrypt("HELP"), "HIAT")
    expectEqual(h2.decrypt("HIAT"), "HELP")
    expectEqual(h2.inverseMatrix, [[15, 17], [20, 9]])
    // padding: incomplete block padded with "A", padding appended
    let c = h2.encrypt("HEL")
    expectEqual(c.count, 4)
    expectEqual(h2.decrypt(c), "HELA")
    let hp = try HillCipher(matrix: [[3, 3], [2, 5]], options: o, paddingCharacter: "x")
    expectEqual(hp.decrypt(hp.encrypt("HEL")), "HELX")
    // keeps non-alphabet characters and case
    expectEqual(h2.decrypt(h2.encrypt("He, lp!")), "He, lp!")
    // vector × matrix = transposed matrix × vector
    let hv = try HillCipher(matrix: [[3, 2], [3, 5]], options: o, multiplication: .vectorTimesMatrix)
    expectEqual(hv.encrypt("HELP"), "HIAT")
    expectThrows("nicht invertierbar") { _ = try HillCipher(matrix: [[2, 4], [1, 2]], options: o) }
    expectThrows("nicht quadratisch") { _ = try HillCipher(matrix: [[1, 2, 3], [1, 2]], options: o) }
    expectThrows("zu groß") { _ = try HillCipher(matrix: Array(repeating: Array(repeating: 1, count: 11), count: 11), options: o) }
    expectEqual(HillCipher.determinant(of: [[3, 3], [2, 5]], modulus: 26), 9)
    expectEqual(HillCipher.determinant(of: k3, modulus: 26), 25)
    // A=1 numbering
    let h1 = try HillCipher(matrix: [[3, 3], [2, 5]], options: o, firstLetterIsOne: true)
    expectEqual(h1.decrypt(h1.encrypt("HELLOWORLD")), "HELLOWORLD")
    for size in 1...6 {
        for modulus in [26, 36, 52, 29] {
            let m = HillCipher.randomKey(size: size, modulus: modulus)
            guard let inv = HillCipher.inverse(of: m, modulus: modulus) else { fail("randomKey nicht invertierbar"); continue }
            // m · inv = I
            for i in 0..<size { for j in 0..<size {
                var s = 0
                for k in 0..<size { s += m[i][k] * inv[k][j] }
                expectEqual(s % modulus, i == j ? 1 : 0)
            } }
        }
    }
    for opt in optionSets where opt.alphabetSize >= 2 {
        for mult in HillMultiplication.allCases {
            let key = HillCipher.randomKey(size: Int.random(in: 1...4, using: &rng), modulus: opt.alphabetSize)
            let h = try HillCipher(matrix: key, options: opt, multiplication: mult)
            for s in allSamples {
                let n = normalized(s, opt)
                let r = h.decrypt(h.encrypt(s))
                expectRoundTrip(String(r.prefix(n.count)), n, opt, "Hill Rundreise")
                expect(r.count - n.count < key.count, "Hill Padding zu lang")
            }
        }
    }
}

group("Hill Known-Plaintext") {
    let o = TextOptions.default
    let plain = "Ein Klartext, der lang genug ist, um den Hill-Schluessel eindeutig zu bestimmen. Noch etwas Text hinterher."
    for mult in HillMultiplication.allCases {
        for size in 1...5 {
            let key = HillCipher.randomKey(size: size, modulus: 26)
            let h = try HillCipher(matrix: key, options: o, multiplication: mult)
            let c = h.encrypt(plain)
            let found = HillAnalysis.knownPlaintext(plaintext: plain, ciphertext: c, size: size, options: o, multiplication: mult)
            expectEqual(found ?? [], key, "Größe \(size) \(mult)")
            if let r = HillAnalysis.knownPlaintext(plaintext: plain, ciphertext: c, sizes: 1...6, options: o, multiplication: mult) {
                // a smaller size may not exist; the found key must reproduce the ciphertext
                let h2 = try HillCipher(matrix: r.matrix, options: o, multiplication: mult)
                expectEqual(LetterMapperFree.letters(h2.encrypt(plain)), LetterMapperFree.letters(c))
                expect(r.size <= size)
            } else { fail("Größensuche erfolglos") }
        }
    }
    // too short text → nil
    let h = try HillCipher(matrix: [[3, 3], [2, 5]], options: o)
    expect(HillAnalysis.knownPlaintext(plaintext: "HE", ciphertext: h.encrypt("HE"), size: 2, options: o) == nil)
    // ciphertext of another cipher: the found key (if any) must reproduce it
    let other = try Vigenere.encrypt(plain, key: "KEYWORD", options: o)
    if let k = HillAnalysis.knownPlaintext(plaintext: plain, ciphertext: other, size: 3, options: o) {
        expectEqual(LetterMapperFree.letters(try HillCipher(matrix: k, options: o).encrypt(plain)), LetterMapperFree.letters(other))
    }
}

enum LetterMapperFree { static func letters(_ s: String) -> String { String(s.uppercased().filter { $0.isASCII && $0.isLetter }) } }

// MARK: - Substitution

group("Substitution / Atbash") {
    let o = TextOptions.default
    let at = SubstitutionCipher.atbash(options: o)
    expectEqual(at.encrypt("ABC xyz!"), "ZYX cba!")
    let kw = SubstitutionCipher.fromKeyword("KEYWORD", options: o)
    expectEqual(kw.keyString, "KEYWORDABCFGHIJLMNPQSTUVXZ")
    expectEqual(kw.encrypt("HELLO"), "AOGGJ")
    expectEqual(String(SubstitutionCipher.keyAlphabet(fromKeyword: "keyword", options: o, remainingDescending: true)),
                "KEYWORDZXVUTSQPNMLJIHGFCBA")
    expectEqual(String(SubstitutionCipher.keyAlphabet(fromKeyword: "KEY", options: o, offset: 3)),
                "ABCKEYDFGHIJLMNOPQRSTUVWXZ")
    expectEqual(String(SubstitutionCipher.keyAlphabet(fromKeyword: "KEY", options: o, offset: 25)),
                "EYABCDFGHIJLMNOPQRSTUVWXZK")
    expectThrows("keine Permutation") { _ = try SubstitutionCipher(keyAlphabet: "AACDEFGHIJKLMNOPQRSTUVWXYZ", options: o) }
    expectThrows("zu kurz") { _ = try SubstitutionCipher(keyAlphabet: "ABC", options: o) }
    let manual = try SubstitutionCipher(keyAlphabet: "qwertyuiopasdfghjklzxcvbnm", options: o)
    expectEqual(manual.encrypt("Hello"), "Itssg")
    for opt in optionSets {
        let ciphers = [SubstitutionCipher.random(options: opt), SubstitutionCipher.atbash(options: opt),
                       SubstitutionCipher.fromKeyword("Geheimnis", options: opt, remainingDescending: true, offset: 5)]
        for c in ciphers { for s in allSamples { expectRoundTrip(c.decrypt(c.encrypt(s)), normalized(s, opt), opt) } }
    }
}

// MARK: - Playfair

group("Playfair") {
    let pf = PlayfairCipher(keyword: "playfair example")
    expectEqual(pf.matrixString, "PLAYFIREXMBCDGHKNOQSTUVWZ")
    expectEqual(pf.preformat("Hide the gold in the tree stump").joined(separator: " "),
                "HI DE TH EG OL DI NT HE TR EX ES TU MP")
    let c = pf.encrypt("Hide the gold in the tree stump")
    expectEqual(c, "BMODZBXDNABEKUDMUIXMMOUVIF")
    expectEqual(pf.decrypt(c), "HIDETHEGOLDINTHETREXESTUMP")
    expectEqual(PlayfairCipher.grouped(c), "BM OD ZB XD NA BE KU DM UI XM MO UV IF")
    // keyword: J dropped (CT1); text: J → I, odd length padding, XX separated by Y
    expect(PlayfairCipher(keyword: "Jazz").matrixString.hasPrefix("AZB"))
    expect(PlayfairCipher(keyword: "Jazz", size: .sixBySix).matrixString.hasPrefix("JAZB"))
    expectEqual(pf.preformat("jax").joined(separator: " "), "IA XY")
    expectEqual(pf.preformat("XXX").joined(separator: " "), "XY XY XY")
    // separate doubles also across pairs
    let pf2 = PlayfairCipher(keyword: "KEY", separateOnlyWithinPairs: false)
    expectEqual(pf2.preformat("ABBC").joined(separator: " "), "AB XB CX")
    let pf3 = PlayfairCipher(keyword: "KEY", doubleLetterRule: false)
    expectEqual(pf3.preformat("LLAMA").joined(separator: " "), "LL AM AX")
    expectEqual(pf3.decrypt(pf3.encrypt("LLAMA")), "LLAMAX")
    // duplicate key letters replaced by the next unused letter (CT1 option)
    let m = PlayfairCipher.makeMatrix(keyword: "AAB", size: .fiveByFive, ignoreDuplicateKeyLetters: false)
    expectEqual(String(m.flatMap { $0 }.prefix(4)), "ABCD")
    let m2 = PlayfairCipher.makeMatrix(keyword: "ABA", size: .fiveByFive, ignoreDuplicateKeyLetters: false)
    expectEqual(String(m2.flatMap { $0 }.prefix(4)), "ABCD")
    // 6×6
    let p6 = PlayfairCipher(keyword: "Geheim 2024", size: .sixBySix)
    expectEqual(p6.matrix.count, 6)
    let t6 = "Treffen um 1900 Uhr am Bahnhof Jena"
    expectEqual(p6.decrypt(p6.encrypt(t6)), p6.preformat(t6).joined())
    // explicit matrix
    let pm = try PlayfairCipher(matrix: pf.matrix)
    expectEqual(pm.encrypt("Hide the gold"), pf.encrypt("Hide the gold"))
    expectThrows("doppelte Zeichen") { _ = try PlayfairCipher(matrix: Array(repeating: Array("AAAAA"), count: 5)) }
    for s in allSamples {
        let p = PlayfairCipher(keyword: "Kryptologie")
        expectEqual(p.decrypt(p.encrypt(s)), p.preformat(s).joined())
    }
}

// MARK: - ADFGVX

group("ADFGVX") {
    let mat = ["NA1C3H", "8TB2OM", "E5WRPD", "4F6G7I", "9J0KLQ", "SUVXYZ"].map { Array($0) }
    let a = try ADFGVXCipher(matrix: mat, transpositionKey: "privacy")
    expectEqual(a.substitute("attack at 1200am"), "ADDDDDADAGVGADDDAFDGVFVFADDX")
    expectEqual(a.encrypt("attack at 1200am", blockSize: 4), "DGDD DAGD DGAF ADDF DADV DVFA ADVX")
    expectEqual(try a.decrypt("DGDD DAGD DGAF ADDF DADV DVFA ADVX"), "attackat1200am")
    expectEqual(a.numberedKey, [4, 5, 3, 6, 1, 2, 7])
    expectThrows("ungültiges Zeichen") { _ = try a.decrypt("DGDB") }
    expectThrows("ungerade") { _ = try a.decrypt("DGD") }
    expectThrows("leeres Passwort") { _ = try ADFGVXCipher(matrix: mat, transpositionKey: "!!") }
    expectThrows("ungültige Matrix") { _ = try ADFGVXCipher(matrix: Array(repeating: Array("AAAAAA"), count: 6), transpositionKey: "KEY") }
    let std = try ADFGVXCipher(matrix: ADFGVXCipher.standardMatrix, transpositionKey: "KEY")
    expectEqual(std.substitute("Bär"), "AD" + "AA" + "AV" + "FX")
    // matrix from keyword
    let mk = ADFGVXCipher.matrix(fromKeyword: "Geheimnis 2024")
    expectEqual(String(mk.flatMap { $0 }.prefix(10)), "GEHIMNS204")
    expectEqual(Set(mk.flatMap { $0 }).count, 36)
    expectEqual(Set(ADFGVXCipher.randomMatrix().flatMap { $0 }).count, 36)
    // repeated key letters: stable order, round trip
    let dup = try ADFGVXCipher(matrix: ADFGVXCipher.randomMatrix(), transpositionKey: "BANANA")
    expectEqual(dup.numberedKey, [4, 1, 5, 2, 6, 3])
    for s in allSamples {
        for key in ["PRIVACY", "BANANA", "X", "LONGERKEYWITHMANYLETTERS"] {
            let c = try ADFGVXCipher(matrix: ADFGVXCipher.randomMatrix(), transpositionKey: key)
            let expected = String(ADFGVXCipher.plaintextSymbols(s)).lowercased()
            expectEqual(try c.decrypt(c.encrypt(s)), expected)
            expectEqual(try c.decrypt(c.encrypt(s, blockSize: 0)), expected)
        }
    }
}

// MARK: - Byte ciphers

group("Byte-Chiffren") {
    let d: [UInt8] = Array("Hallo Welt".utf8)
    let k: [UInt8] = [0x01, 0xFF, 0x80]
    expectEqual(ByteCiphers.add([0xFF, 0x01], key: [0x02]), [0x01, 0x03])
    expectEqual(ByteCiphers.subtract(ByteCiphers.add(d, key: k), key: k), d)
    expectEqual(ByteCiphers.xor(ByteCiphers.xor(d, key: k), key: k), d)
    expectEqual(ByteCiphers.xor([0x0F, 0xF0], key: [0xFF]), [0xF0, 0x0F])
    expectEqual(ByteCiphers.xor(d, key: []), d)
    let pad = (0..<20).map { _ in UInt8.random(in: 0...255, using: &rng) }
    expectEqual(try ByteCiphers.vernam(try ByteCiphers.vernam(d, pad: pad), pad: pad), d)
    expectThrows("Pad zu kurz") { _ = try ByteCiphers.vernam(d, pad: [1, 2]) }
    expectThrows("Pad leer") { _ = try ByteCiphers.vernam(d, pad: []) }
}

// MARK: - Homophone

group("Homophone") {
    let o = TextOptions.default
    let key = Homophone.generateKey(options: o, letterFrequencies: Homophone.germanFrequencies)
    expectEqual(key.codeCount, 256)
    expectEqual(key.table.values.reduce(0) { $0 + $1.count }, 256)
    expect(key.table.values.allSatisfy { !$0.isEmpty })
    try key.validate()
    let eCount = key.table["E"]!.count
    expect(key.table.values.allSatisfy { $0.count <= eCount }, "E sollte die meisten Homophone haben")
    expect((44...45).contains(eCount), "E: \(eCount) Codes")  // ⌊256·0.174⌋ = 44 (+ Korrektur)
    expectEqual(Homophone.allocate(frequencies: [0.5, 0.3, 0.2], total: 10), [5, 3, 2])
    expectEqual(Homophone.allocate(frequencies: [0.98, 0.01, 0.01], total: 10), [8, 1, 1])
    let text = "Das ist ein geheimer Text! Äpfel und Birnen."
    let codes = Homophone.encrypt(text, key: key, options: o)
    expectEqual(Homophone.decrypt(codes, key: key), "DASISTEINGEHEIMERTEXTPFELUNDBIRNEN")
    let codesU = Homophone.encrypt(text, key: key, options: o, transcribeUmlauts: true)
    expectEqual(Homophone.decrypt(codesU, key: key), "DASISTEINGEHEIMERTEXTAEPFELUNDBIRNEN")
    for f in HomophoneOutputFormat.allCases {
        expectEqual(try Homophone.parse(Homophone.format(codes, as: f), as: f), codes, "\(f)")
    }
    expectEqual(Homophone.format([1, 10, 255], as: .hex), "01 0A FF")
    expectEqual(Homophone.format([1, 10, 255], as: .decimal), "1 10 255")
    expectThrows("ungültiger Code") { _ = try Homophone.parse("12 x4", as: .decimal) }
    expectEqual(Homophone.unpack(Homophone.pack(codes, codeCount: 256), codeCount: 256), codes)
    let k64 = Homophone.generateKey(options: o, letterFrequencies: Homophone.englishFrequencies, codeCount: 64)
    let c64 = Homophone.encrypt("HELLO WORLD", key: k64, options: o)
    expectEqual(Homophone.unpack(Homophone.pack(c64, codeCount: 64), codeCount: 64).prefix(c64.count).map { $0 }, c64)
    expectEqual(Homophone.bitLength(256), 8)
    expectEqual(Homophone.bitLength(64), 6)
    // Codable
    let data = try JSONEncoder().encode(key)
    let back = try JSONDecoder().decode(HomophoneKey.self, from: data)
    expectEqual(back, key)
    // uniform without frequencies, small code count raised to alphabet size
    let small = Homophone.generateKey(options: o, letterFrequencies: nil, codeCount: 10)
    expectEqual(small.codeCount, 26)
    for opt in optionSets {
        let k = Homophone.generateKey(options: opt, letterFrequencies: LetterFrequencies.measure(samples[1], options: opt), codeCount: 300)
        try k.validate()
        for s in allSamples {
            let expected = String(normalized(s, TextOptions(alphabet: opt.alphabet, distinguishCase: opt.distinguishCase, keepCase: false, keepNonAlphabet: false)))
            expectEqual(Homophone.decrypt(Homophone.encrypt(s, key: k, options: opt), key: k), expected)
        }
    }
}

// MARK: - Permutation

group("Permutation / Transposition") {
    let o = TextOptions.default
    expectEqual(PermutationCipher.permutation(fromKeyword: "ZEBRAS", options: o), [6, 3, 2, 4, 1, 5])
    expectEqual(PermutationCipher.permutation(fromKeyword: "BANANA", options: o), [4, 1, 5, 2, 6, 3])
    expectEqual(PermutationCipher.parsePermutation("3,1,2"), [3, 1, 2])
    expectEqual(PermutationCipher.parsePermutation("zebras"), [6, 3, 2, 4, 1, 5])
    expect(PermutationCipher.parsePermutation("3,1,1") == nil)
    expect(PermutationCipher.parsePermutation("0,1,2") == nil)
    expectEqual(PermutationCipher.inverse(of: [3, 1, 2]), [2, 3, 1])
    expectEqual(PermutationCipher.display([3, 1, 2]), "( 3, 1, 2 )")
    expectThrows("keine Permutation") { _ = try PermutationCipher(firstKey: [1, 1]) }
    expectThrows("leer") { _ = try PermutationCipher(firstKey: []) }
    let letters = PermutationOptions(lettersOnly: true)
    let z = try PermutationCipher(firstKey: [6, 3, 2, 4, 1, 5], options: letters)
    expectEqual(z.encrypt("WEAREDISCOVEREDFLEEATONCE", textOptions: o), "EVLNACDTESEAROFODEECWIREE")
    expectEqual(z.encrypt("We are discovered. Flee at once!", textOptions: o), "Ev lna cdtesearof. Odee cw iree!")
    expectEqual(z.decrypt("EVLNACDTESEAROFODEECWIREE", textOptions: o), "WEAREDISCOVEREDFLEEATONCE")
    // binary mode permutes all characters
    let zb = try PermutationCipher(firstKey: [2, 1])
    expectEqual(zb.encrypt("AB CD", textOptions: o), "BCA D")
    // apply inverse = using the inverse key
    let inv = try PermutationCipher(firstKey: [6, 3, 2, 5, 1, 4], options: PermutationOptions(applyInverse: true, lettersOnly: true))
    let viaInv = try PermutationCipher(firstKey: PermutationCipher.inverse(of: [6, 3, 2, 5, 1, 4]), options: letters)
    expectEqual(inv.encrypt("WEAREDISCOVEREDFLEEATONCE", textOptions: o), viaInv.encrypt("WEAREDISCOVEREDFLEEATONCE", textOptions: o))
    // double transposition, all direction combinations
    let dirs = PermutationOptions.Direction.allCases
    var stages: [PermutationOptions.Stage] = []
    for a in dirs { for b in dirs { for c in dirs { stages.append(.init(readIn: a, permute: b, readOut: c)) } } }
    let bytes: [UInt8] = (0..<97).map { _ in UInt8.random(in: 0...255, using: &rng) }
    for s1 in stages {
        for s2 in [stages[0], stages[5], stages[7]] {
            for invFlag in [false, true] {
                for lettersOnly in [false, true] {
                    let po = PermutationOptions(first: s1, second: s2, applyInverse: invFlag, lettersOnly: lettersOnly)
                    let c = try PermutationCipher(firstKey: [3, 1, 4, 2], secondKey: [2, 5, 1, 3, 4, 7, 6], options: po)
                    for s in allSamples {
                        let e = c.encrypt(s, textOptions: o)
                        expectEqual(c.decrypt(e, textOptions: o), lettersOnly ? normalized(s, o) : s)
                    }
                    expectEqual(c.decrypt(bytes: c.encrypt(bytes: bytes)), bytes)
                    let single = try PermutationCipher(firstKey: [2, 3, 1], options: po)
                    expectEqual(single.decrypt(bytes: single.encrypt(bytes: bytes)), bytes)
                    for len in 0..<12 {
                        let b = Array(bytes.prefix(len))
                        expectEqual(single.decrypt(bytes: single.encrypt(bytes: b)), b)
                    }
                }
            }
        }
    }
    for opt in optionSets {
        let c = try PermutationCipher(firstKey: [4, 2, 1, 3], secondKey: [1, 3, 2], options: letters)
        for s in allSamples { expectRoundTrip(c.decrypt(c.encrypt(s, textOptions: opt), textOptions: opt), normalized(s, opt), opt) }
    }
}

group("Transpositionsanalyse") {
    let o = TextOptions.default
    let plain = "WEAREDISCOVEREDFLEEATONCEANDMUSTLEAVEIMMEDIATELY"
    let key = [6, 3, 2, 5, 1, 4]
    let c = try PermutationCipher(firstKey: key, options: PermutationOptions(lettersOnly: true)).encrypt(plain, textOptions: o)
    let found = TranspositionAnalysis.knownPlaintextSingleColumn(plaintext: plain, ciphertext: c, options: o)
    expect(found.contains(key), "Schlüssel nicht gefunden: \(found)")
    for k in found {
        let r = try PermutationCipher(firstKey: k, options: PermutationOptions(lettersOnly: true)).encrypt(plain, textOptions: o)
        expectEqual(r, c)
    }
    expect(TranspositionAnalysis.knownPlaintextSingleColumn(plaintext: plain, ciphertext: Caesar.encrypt(plain, shift: 1, options: o), options: o).isEmpty)
    for _ in 0..<5 {
        let L = Int.random(in: 2...8, using: &rng)
        let k = Array(1...L).shuffled(using: &rng)
        let p = randomText(80)
        let cc = try PermutationCipher(firstKey: k, options: PermutationOptions(lettersOnly: true)).encrypt(p, textOptions: o)
        expect(TranspositionAnalysis.knownPlaintextSingleColumn(plaintext: p, ciphertext: cc, options: o).contains(k))
    }
}

// MARK: - Solitaire

group("Solitaire") {
    let unkeyed = Solitaire(deck: Solitaire.orderedDeck)
    expectEqual(unkeyed.keystream(count: 10), [4, 23, 10, 24, 8, 25, 18, 6, 4, 7])
    expectEqual(unkeyed.encrypt("AAAAAAAAAAAAAAA"), "EXKYI ZSGEH UNTIQ")
    let vectors: [(String, String, String)] = [
        ("", "AAAAAAAAAAAAAAA", "EXKYIZSGEHUNTIQ"),
        ("f", "AAAAAAAAAAAAAAA", "XYIUQBMHKKJBEGY"),
        ("fo", "AAAAAAAAAAAAAAA", "TUJYMBERLGXNDIW"),
        ("foo", "AAAAAAAAAAAAAAA", "ITHZUJIWGRFARMW"),
        ("a", "AAAAAAAAAAAAAAA", "XODALGSCULIQNSC"),
        ("aa", "AAAAAAAAAAAAAAA", "OHGWMXXCAIMCIQP"),
        ("aaa", "AAAAAAAAAAAAAAA", "DCSQYHBQZNGDRUT"),
        ("b", "AAAAAAAAAAAAAAA", "XQEEMOITLZVDSQS"),
        ("bc", "AAAAAAAAAAAAAAA", "QNGRKQIHCLGWSCE"),
        ("bcd", "AAAAAAAAAAAAAAA", "FMUBYBMAXHNQXCJ"),
        ("cryptonomicon", "AAAAAAAAAAAAAAAAAAAAAAAAA", "SUGSRSXSWQRMXOHIPBFPXARYQ"),
        ("cryptonomicon", "SOLITAIREX", "KIRAKSFJAN"),
    ]
    for (pass, p, c) in vectors {
        let s = Solitaire(passphrase: pass)
        expectEqual(s.encrypt(p).replacingOccurrences(of: " ", with: ""), c, "Passphrase \(pass)")
        expectEqual(s.decrypt(c).replacingOccurrences(of: " ", with: ""), p, "Passphrase \(pass)")
    }
    let s = Solitaire(passphrase: "CRYPTONOMICON")
    expectEqual(s.encrypt("Solitaire", padWithX: true), "KIRAK SFJAN")
    expectEqual(s.encrypt("Solitaire"), "KIRAK SFJA")
    expectEqual(s.decrypt("KIRAK SFJAN"), "SOLIT AIREX")
    // umlauts, grouping with line breaks after 14 groups
    expectEqual(Solitaire.letters("Äß!"), [1, 5, 19, 19])
    let long = unkeyed.encrypt(String(repeating: "A", count: 80))
    expectEqual(long.split(separator: "\n").count, 2)
    let r = unkeyed.run("AAAAA", decrypt: false)
    expectEqual(r.keystream, [4, 23, 10, 24, 8])
    expectEqual(r.finalDeck, unkeyed.finalDeck(after: 5))
    expect(r.finalDeck != Solitaire.orderedDeck)
    expectThrows("ungültiges Deck") { _ = try Solitaire(validating: [1, 2, 2]) }
    expectThrows("ungültiges Deck") { _ = try Solitaire.parseDeck("1,2,x") }
    expectEqual(try Solitaire.parseDeck(unkeyed.deckString), Solitaire.orderedDeck)
    // smaller decks and random decks: round trip
    for cards in [3, 10, 28, 40, 54] {
        let d = Solitaire(deck: Solitaire.shuffledDeck(cards: cards))
        expectEqual(d.cardCount, cards)
        for t in allSamples {
            let plain = Solitaire.letters(t).map { String(Character(Unicode.Scalar(UInt8(64 + $0)))) }.joined()
            expectEqual(d.decrypt(d.encrypt(t)).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: ""), plain)
        }
    }
    expectEqual(Solitaire.cardName(53), "Joker A")
    expectEqual(Solitaire.cardName(1), "♣A")
}

// MARK: - Scytale / Rail fence

group("Skytale / Gartenzaun") {
    expectEqual(Scytale.encrypt("IAMHURTVERYBADLYHELP", circumference: 4), "IRYYATBHMVAEHEDLURLP")
    expectEqual(Scytale.decrypt("IRYYATBHMVAEHEDLURLP", circumference: 4), "IAMHURTVERYBADLYHELP")
    expectEqual(RailFence.encrypt("WEAREDISCOVEREDFLEEATONCE", rails: 3), "WECRLTEERDSOEEFEAOCAIVDEN")
    expectEqual(RailFence.decrypt("WECRLTEERDSOEEFEAOCAIVDEN", rails: 3), "WEAREDISCOVEREDFLEEATONCE")
    // CT1 behaviour with text options: only alphabet characters move, others stay in place
    let o = TextOptions.default
    expectEqual(Scytale.encrypt("I am hurt very badly help", circumference: 4, options: o), "I ry yatb hmva ehedl urlp")
    var o2 = o; o2.keepNonAlphabet = false
    expectEqual(Scytale.encrypt("I am hurt very badly help", circumference: 4, options: o2), "Iryyatbhmvaehedlurlp")
    // offsets
    expectEqual(RailFence.encrypt("ABCDEFG", rails: 3, offset: 1), "DACEGBF")
    expectEqual(RailFence.encrypt("ABCDEF", rails: 3, offset: 2), "CBDFAE")
    expect(Scytale.isValidKey(2, forLength: 10) && !Scytale.isValidKey(1, forLength: 10) && !RailFence.isValidKey(10, forLength: 10))
    for s in allSamples {
        for k in 1...7 {
            for off in [0, 1, 3, 9, 100] {
                expectEqual(Scytale.decrypt(Scytale.encrypt(s, circumference: k, offset: off), circumference: k, offset: off), s, "Skytale k=\(k) off=\(off)")
                expectEqual(RailFence.decrypt(RailFence.encrypt(s, rails: k, offset: off), rails: k, offset: off), s, "Zaun k=\(k) off=\(off)")
                for opt in [o, o2, optionSets[5], optionSets[30]] {
                    let n = String(s.filter { ch in opt.keepNonAlphabet || LetterProbe.isLetter(ch, opt) })
                    expectEqual(Scytale.decrypt(Scytale.encrypt(s, circumference: k, offset: off, options: opt), circumference: k, offset: off, options: opt), n)
                    expectEqual(RailFence.decrypt(RailFence.encrypt(s, rails: k, offset: off, options: opt), rails: k, offset: off, options: opt), n)
                }
            }
        }
    }
}

enum LetterProbe {
    static func isLetter(_ ch: Character, _ o: TextOptions) -> Bool {
        var o2 = o; o2.keepNonAlphabet = false
        return !Caesar.encrypt(String(ch), shift: 0, options: o2).isEmpty
    }
}

// MARK: - Enigma

group("Enigma") {
    var e = try Enigma(rotors: [.I, .II, .III], reflector: .B, ringSettings: [0, 0, 0], positions: [0, 0, 0], plugboard: [])
    expectEqual(e.encrypt("AAAAA"), "BDZGO")
    expectEqual(e.positionsString, "AAF")
    var d = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "AAA", start: "AAA")
    expectEqual(d.decrypt("BDZGO"), "AAAAA")
    // double stepping: ADU → ADV → AEW → BFX → BFY
    var s = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "AAA", start: "ADU")
    var seen: [String] = []
    for _ in 0..<4 { s.step(); seen.append(s.positionsString) }
    expectEqual(seen, ["ADV", "AEW", "BFX", "BFY"])
    // ring setting B on all rotors, start AAA: "AAAAA" → "EWTYX"
    var r = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "BBB", start: "AAA")
    expectEqual(r.encrypt("AAAAA"), "EWTYX")
    // Wikipedia/well-known: rotors II IV V, reflector B, rings BUL, start BLA, plugboard AV BS CG DL FU HZ IN KM OW RX
    var w = try Enigma(rotors: [.II, .IV, .V], reflector: .B, rings: "BUL", start: "BLA", plugboard: "AV BS CG DL FU HZ IN KM OW RX")
    expectEqual(w.encrypt("EDPUDNRGYSZRCXNUYTPOMRMBOFKTBZREZKMLXLVEFGUEYSIOZVEQMIKUBPMMYLKLTTDEISMDICAGYKUACTCDOMOHWXMUUIAUBSTSLRNBZSZWNRFXWFYSSXJZVIJHIDISHPRKLKAYUPADTXQSPINQMATLPIFSVKDASCTACDPBOPVHJK"),
                "AUFKLXABTEILUNGXVONXKURTINOWAXKURTINOWAXNORDWESTLXSEBEZXSEBEZXUAFFLIEGERSTRASZERIQTUNGXDUBROWKIXDUBROWKIXOPOTSCHKAXOPOTSCHKAXUMXEINSAQTDREINULLXUHRANGETRETENXANGRIFFXINFXRGTX")
    // M4 with beta at A + thin B == M3 with B
    var m4 = try Enigma(rotors: [.I, .II, .III], reflector: .B, ringSettings: [0, 0, 0], positions: [0, 0, 0], plugboard: [],
                        greekRotor: .beta, greekRing: 0, greekPosition: 0)
    expectEqual(m4.encrypt("AAAAA"), "BDZGO")
    expectEqual(m4.positionsString, "AAAF")
    expectThrows("doppelte Walze") { _ = try Enigma(rotors: [.I, .I, .III], reflector: .B, ringSettings: [0, 0, 0], positions: [0, 0, 0], plugboard: []) }
    expectThrows("Stecker doppelt") { _ = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "AAA", start: "AAA", plugboard: "AB AC") }
    expectThrows("Stecker selbst") { _ = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "AAA", start: "AAA", plugboard: "AA") }
    for _ in 0..<20 {
        let rot = Array(EnigmaRotor.allCases.shuffled(using: &rng).prefix(3))
        let refl = EnigmaReflector.allCases.randomElement(using: &rng)!
        let rings = (0..<3).map { _ in Int.random(in: 0..<26, using: &rng) }
        let pos = (0..<3).map { _ in Int.random(in: 0..<26, using: &rng) }
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").shuffled(using: &rng)
        let plug = (0..<10).map { (letters[2 * $0], letters[2 * $0 + 1]) }
        let greek: EnigmaGreekRotor? = Bool.random(using: &rng) ? .gamma : nil
        var a = try Enigma(rotors: rot, reflector: refl, ringSettings: rings, positions: pos, plugboard: plug, greekRotor: greek, greekRing: 3, greekPosition: 7)
        var b = a
        let t = randomText(200)
        let c = a.encrypt(t)
        expectEqual(b.decrypt(c), String(t.filter { $0.isASCII && $0.isLetter }).uppercased())
        expect(zip(c, String(t.filter { $0.isASCII && $0.isLetter }).uppercased()).allSatisfy { $0 != $1 }, "Enigma verschlüsselt nie auf sich selbst")
    }
    expectEqual(e.encrypt("Hallo Welt", groupSize: 5).count, 10)
}

// MARK: - Nihilist

group("Nihilist") {
    let c = try Nihilist.encrypt("DYNAMITE WINTER PALACE", squareKeyword: "ZEBRAS", key: "RUSSIAN")
    expectEqual(c, "37 106 62 36 67 47 86 26 104 53 62 77 27 55 57 66 55 36 54 27")
    expectEqual(try Nihilist.decrypt(c, squareKeyword: "ZEBRAS", key: "RUSSIAN"), "DYNAMITEWINTERPALACE")
    expectThrows("leerer Schlüssel") { _ = try Nihilist.encrypt("A", squareKeyword: "X", key: "123") }
}

// MARK: - Robustness: characters whose case mapping has several graphemes must not crash

group("Robustheit") {
    let o = TextOptions.default
    for s in ["ß", "ŉ", "ﬁ", "İ", "🙂", "\r\n", "e\u{301}"] {
        _ = Caesar.encrypt(s, shift: 3, options: o)
        _ = try Vigenere.encrypt(s, key: "ßKEY", options: o)
        _ = SubstitutionCipher.fromKeyword("ßİ", options: o).encrypt(s)
        _ = try HillCipher(matrix: [[3, 3], [2, 5]], options: o).encrypt(s)
        _ = PlayfairCipher(keyword: s).encrypt(s)
        _ = try ADFGVXCipher(matrix: ADFGVXCipher.standardMatrix, transpositionKey: "KEY" + s).encrypt(s)
        _ = Solitaire(passphrase: s).encrypt(s)
        _ = Scytale.encrypt(s + "abc", circumference: 2, options: o)
        if !s.allSatisfy(\.isWhitespace) {
            expectThrows("ADFGVX ungültig") { _ = try ADFGVXCipher(matrix: ADFGVXCipher.standardMatrix, transpositionKey: "KEY").decrypt(s + "AD") }
        }
    }
    expect(true)
}

// MARK: - Timing smoke test (prints only)

group("Laufzeit (1 MB Text)") {
    let big = String(repeating: samples[1] + " ", count: 1_000_000 / (samples[1].utf8.count + 1))
    let o = TextOptions.default
    func time(_ name: String, _ body: () throws -> Void) rethrows {
        let t0 = Date()
        try body()
        print(String(format: "    %-28@ %6.2f s", name as NSString, Date().timeIntervalSince(t0)))
    }
    time("Caesar") { _ = Caesar.encrypt(big, shift: 3, options: o) }
    try time("Vigenère") { _ = try Vigenere.encrypt(big, key: "GEHEIM", options: o) }
    time("Substitution") { _ = SubstitutionCipher.atbash(options: o).encrypt(big) }
    try time("Hill 3×3") { _ = try HillCipher(matrix: [[6, 24, 1], [13, 16, 10], [20, 17, 15]], options: o).encrypt(big) }
    try time("Permutation (Text)") { _ = try PermutationCipher(firstKey: [3, 1, 4, 2], secondKey: [2, 1, 3], options: .init(lettersOnly: true)).encrypt(big, textOptions: o) }
    time("Playfair") { _ = PlayfairCipher(keyword: "KEY").encrypt(big) }
    try time("ADFGVX") { _ = try ADFGVXCipher(matrix: ADFGVXCipher.standardMatrix, transpositionKey: "PRIVACY").encrypt(big) }
    time("Homophon") { _ = Homophone.encrypt(big, key: Homophone.generateKey(options: o, letterFrequencies: Homophone.germanFrequencies), options: o) }
    time("Gartenzaun") { _ = RailFence.encrypt(big, rails: 5, options: o) }
    time("Solitaire (100 kB)") { _ = Solitaire(passphrase: "KEY").encrypt(String(big.prefix(100_000))) }
    try time("Enigma") { var e = try Enigma(rotors: [.I, .II, .III], reflector: .B, rings: "AAA", start: "AAA"); _ = e.encrypt(big) }
}

// MARK: - CT1 analyses (separate files)

runCT1ADFGVXAnalysisTests()
runCT1PlayfairAnalysisTests()
runCT1SolitaireAnalysisTests()
runCT1KnownPlaintextTests()

print("\nCTClassicTests: \(checks) Prüfungen, \(failures) Fehler")
if failures > 0 { exit(1) }
