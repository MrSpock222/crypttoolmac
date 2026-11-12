import Foundation
import CTCommon
import CTAnalysis

// Minimal test harness (no XCTest available with the Command Line Tools).
var passed = 0
var failed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #fileID, line: Int = #line) {
    if condition() {
        passed += 1
    } else {
        failed += 1
        print("FAIL [\(line)]: \(message)")
    }
}

func approx(_ a: Double, _ b: Double, _ tol: Double, _ message: String, line: Int = #line) {
    check(abs(a - b) <= tol, "\(message): \(a) ≠ \(b) (±\(tol))", line: line)
}

func section(_ name: String) { print("— \(name)") }

/// Timing assertions only apply to optimised builds (`swift run -c release CTAnalysisTests`).
#if DEBUG
let isRelease = false
#else
let isRelease = true
#endif

func timed<T>(_ body: () -> T) -> (T, Double) {
    let t0 = Date()
    let r = body()
    return (r, Date().timeIntervalSince(t0))
}

// Repository paths
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
func reference(_ name: String) -> String {
    let url = repoRoot.appendingPathComponent("Resources/Reference/\(name)")
    guard let s = try? String(contentsOf: url, encoding: .utf8) else {
        print("FATAL: cannot read \(url.path)")
        exit(1)
    }
    return s
}

let opts = TextOptions.default
let az = Array(TextOptions.uppercaseLetters)
let german = reference("deutsch.txt")
let english = reference("english.txt")
let germanLetters = opts.filtered(german)   // raw text incl. ß and umlauts (skipped for A–Z)
let englishLetters = opts.filtered(english)

/// Splits the letters into a training part (first 70 %) and a test part (rest).
func split(_ letters: String) -> (train: String, test: [Character]) {
    let chars = Array(letters)
    let cut = chars.count * 7 / 10
    return (String(chars[..<cut]), Array(chars[cut...]))
}
let (germanTrain, germanTest) = split(germanLetters)
let (englishTrain, englishTest) = split(englishLetters)
let germanModel = LanguageModel.from(referenceText: germanTrain, options: opts)
let englishModel = LanguageModel.from(referenceText: englishTrain, options: opts)
let germanFullModel = LanguageModel.from(referenceText: german, options: opts)

var rng = SystemRandomNumberGenerator()
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
var srng = SeededRNG(state: 0xC0FFEE)

func chunk(_ letters: [Character], length: Int) -> String {
    let start = Int.random(in: 0..<(letters.count - length), using: &srng)
    return String(letters[start..<(start + length)])
}

func idx(_ c: Character) -> Int { az.firstIndex(of: c)! }
func vigenereEncrypt(_ text: String, key: [Int]) -> String {
    String(text.enumerated().map { az[(idx($0.element) + key[$0.offset % key.count]) % 26] })
}

// MARK: - Statistics

section("Statistics")
approx(Statistics.entropy(bytes: (0...255).map { UInt8($0) }), 8, 1e-12, "entropy of all bytes")
approx(Statistics.entropy(bytes: [UInt8](repeating: 7, count: 100)), 0, 1e-12, "entropy constant")
approx(Statistics.entropy(text: "aAbB, cc!", options: opts), log2(3), 1e-12, "text entropy")
approx(Statistics.maximumEntropy(symbolCount: 26), 4.70044, 1e-5, "max entropy 26")
check(Statistics.byteHistogram([1, 1, 255]) [1] == 2 && Statistics.byteHistogram([1, 1, 255])[255] == 1, "byte histogram")
let lc = Statistics.letterCounts("Hallo Welt!", options: opts)
check(lc.count == 26 && lc[7].symbol == "H" && lc[7].count == 1 && lc[11].count == 3, "letter counts")
let sz = Statistics.letterCounts("Straße STRASSE", options: opts)   // must not crash on ß
check(sz[18].count == 4 && sz[0].count == 2, "letter counts with ß: \(sz[18].count)")
let umlautOpts = TextOptions(alphabet: TextOptions.uppercaseLetters + "ÄÖÜß")
let szu = Statistics.letterCounts("Straße ÄÖÜ äöü", options: umlautOpts)
check(szu[29].count == 1 && szu[26].count == 2, "umlaut alphabet counts")

let ng = Statistics.ngrams("ABAB AB", n: 2, options: opts)
check(ng.count == 2 && ng[0].gram == "AB" && ng[0].count == 3 && abs(ng[0].percent - 75) < 1e-9, "bigrams (no spanning)")
let ng2 = Statistics.ngrams("abab ab", n: 2, options: opts, acrossNonAlphabet: true)
check(ng2[0].gram == "AB" && ng2[0].count == 3 && ng2[1].count == 2, "bigrams across gaps")
let tri = Statistics.ngrams(german, n: 3, options: opts, limit: 5)
check(tri.count == 5 && ["EIN", "ICH", "SCH", "DER", "UND", "NDE", "CHE", "TEU", "STE", "GEN", "UER"].contains(tri[0].gram), "German top trigram \(tri.map { $0.gram })")
let bng = Statistics.byteNGrams([1, 2, 1, 2], n: 2)
check(bng.count == 2 && bng[0].gram == "01 02" && bng[0].count == 2, "byte bigrams")
check(Statistics.byteNGrams(Array("abcabcabc".utf8), n: 3, limit: 1)[0].count == 3, "byte trigrams")

let ac = Statistics.autocorrelation(Array("ABCABCABC".utf8), maxShift: 4)
check(ac == [0, 0, 6, 0], "autocorrelation \(ac)")
check(Statistics.defaultAutocorrelationMaxShift(count: 1000) == 199 && Statistics.defaultAutocorrelationMaxShift(count: 100) == 49, "default autocorr shift")
let act = Statistics.autocorrelation(text: "ab-ca bc", options: opts, maxShift: 3)
check(act == [0, 0, 3], "text autocorrelation \(act)")

check(Statistics.floatingFrequency([1, 1, 2, 3, 4, 4], window: 4) == [3, 4, 3], "floating frequency")
check(Statistics.floatingFrequency([1, 2], window: 4).isEmpty, "floating frequency short")
let ff = Statistics.floatingFrequency(Array(german.utf8))
check(ff.count == german.utf8.count - 63 && ff.max()! <= 64 && ff.min()! >= 1, "floating frequency of reference text")
let fe = Statistics.floatingEntropy((0..<128).map { UInt8($0) }, window: 64)
approx(fe[0], 6, 1e-9, "floating entropy")

approx(Statistics.indexOfCoincidence("AAAA", options: opts), 1, 1e-12, "IC constant")
let icDE = Statistics.indexOfCoincidence(german, options: opts)
let icEN = Statistics.indexOfCoincidence(english, options: opts)
check(icDE > 0.072 && icDE < 0.082, "IC German \(icDE)")
check(icEN > 0.062 && icEN < 0.070, "IC English \(icEN)")

var per = Statistics.periodicity(Array("xababab".utf8))
check(per.count == 1 && per[0].offset == 1 && per[0].length == 2 && per[0].repetitions == 3 && per[0].pattern == Array("ab".utf8), "periodicity xababab \(per)")
per = Statistics.periodicity(Array("aaaa".utf8))
check(per.count == 1 && per[0].offset == 0 && per[0].length == 1 && per[0].repetitions == 4, "periodicity aaaa")
per = Statistics.periodicity(Array("Hallo123123123123".utf8))
check(per.first?.length == 3 && per.first?.offset == 5 && per.first?.repetitions == 4, "periodicity tail \(per)")
// nested: inner period "aab" ×3 inside an outer period repeated twice
per = Statistics.periodicity(Array("QZabababZababab".utf8))
check(per.count == 2 && per[0].offset == 1 && per[0].length == 7 && per[0].repetitions == 2
      && per[1].offset == 9 && per[1].length == 2 && per[1].repetitions == 3, "nested periods, outer first \(per.map { ($0.offset, $0.length, $0.repetitions) })")
check(Statistics.periodicity(Array("abcdefgh".utf8)).isEmpty, "no periodicity")

// MARK: - Language model

// ß / umlauts: CTAnalysis must agree exactly with CTCommon's TextOptions for German text
do {
    let sampleDE = "Größe, Maß und Fuß: Ärger über Öl – ÄÖÜ äöü ẞ ß Straße STRASSE\r\nEnde. " + String(german.prefix(3000))
    let optionVariants = [opts, umlautOpts,
                          TextOptions(alphabet: TextOptions.uppercaseLetters + "ÄÖÜß", keepCase: false),
                          TextOptions(alphabet: TextOptions.lowercaseLetters + "äöüß"),
                          TextOptions(alphabet: TextOptions.uppercaseLetters + TextOptions.lowercaseLetters + "ÄÖÜäöüß", distinguishCase: true),
                          TextOptions(alphabet: TextOptions.uppercaseLetters + "ÄÖÜß", keepNonAlphabet: false)]
    for o in optionVariants {
        let ref = o.indices(of: sampleDE)
        let counts = Statistics.letterCounts(sampleDE, options: o).map { $0.count }
        var refCounts = [Int](repeating: 0, count: o.alphabetSize); for i in ref { refCounts[i] += 1 }
        check(counts == refCounts, "letter counts = CTCommon for alphabet \(o.alphabet)")
        let n = o.alphabetSize
        let perm = (0..<n).map { ($0 * 7 + 3) % n }
        check(SubstitutionAnalysis.apply(key: perm, to: sampleDE, options: o) == o.mapLetters(sampleDE) { i, _ in perm[i] },
              "substitution apply = CTCommon mapLetters for alphabet \(o.alphabet)")
        let shifts = [3, 1, 4, 1, 5]
        let enc = o.mapLetters(sampleDE) { i, p in i + shifts[p % shifts.count] }
        check(VigenereAnalysis.decrypt(enc, shifts: shifts, options: o) == o.mapLetters(enc) { i, p in i - shifts[p % shifts.count] },
              "Vigenère decrypt = CTCommon for alphabet \(o.alphabet)")
        check(CaesarAnalysis.decrypt(o.mapLetters(sampleDE) { i, _ in i + 5 }, shift: 5, options: o)
              == o.mapLetters(o.mapLetters(sampleDE) { i, _ in i + 5 }) { i, _ in i - 5 }, "Caesar decrypt = CTCommon for alphabet \(o.alphabet)")
    }
    check(Statistics.letterCounts("ß ẞ", options: umlautOpts)[29].count == 2, "ß and capital ẞ counted as ß")
    approx(Statistics.entropy(text: "ÄÖÜß", options: umlautOpts), 2, 1e-12, "entropy over umlauts")
    check(Statistics.ngrams("Straße straße", n: 3, options: umlautOpts, limit: 1)[0].count == 2, "trigrams with ß")
}

section("LanguageModel")
let gm = germanFullModel
approx(gm.letterFrequencies.reduce(0, +), 1, 1e-9, "frequencies sum")
check(gm.letterFrequencies.firstIndex(of: gm.letterFrequencies.max()!) == 4, "E most frequent (German)")
check(gm.hasNGrams && gm.maxNGramOrder == 4, "German model has quadgrams")
check(gm.kappa > 0.07 && gm.kappa < 0.085, "German kappa \(gm.kappa)")
let sample = opts.indices(of: chunk(germanTest, length: 300))
var shuffled = sample; shuffled.shuffle(using: &srng)
check(gm.score(indices: sample) > gm.score(indices: shuffled) + 100, "score real > shuffled")
var sampleCounts = [Int](repeating: 0, count: 26); for i in sample { sampleCounts[i] += 1 }
check(gm.chiSquared(counts: sampleCounts) < gm.chiSquared(counts: [Int](repeating: sample.count / 26, count: 26)), "chi² real < uniform")
let dg = LanguageModel.defaultGerman(options: opts), de = LanguageModel.defaultEnglish(options: opts)
check(dg.letterFrequencies.firstIndex(of: dg.letterFrequencies.max()!) == 4 && !dg.hasNGrams, "default German")
check(de.letterFrequencies[19] > de.letterFrequencies[0] && abs(de.letterFrequencies.reduce(0, +) - 1) < 1e-9, "default English")
let dgU = LanguageModel.defaultGerman(options: umlautOpts)
check(dgU.alphabetSize == 30 && dgU.letterFrequencies[29] > 0.001, "default German with umlauts")
let (_, tModel) = timed { LanguageModel.from(referenceText: german, options: opts) }
print("   model from 149 KB reference text: \(String(format: "%.3f", tModel)) s")
check(!isRelease || tModel < 2.0, "model build time")

// MARK: - Caesar

section("Caesar")
var caesarOK = 0, caesarDefaultOK = 0, caesarShortOK = 0, ct1Style = 0
for t in 0..<50 {
    let plain = chunk(t % 2 == 0 ? germanTest : englishTest, length: 120)
    let shift = Int.random(in: 0..<26, using: &srng)
    let cipher = String(plain.map { az[(idx($0) + shift) % 26] })
    let model = t % 2 == 0 ? germanModel : englishModel
    if CaesarAnalysis.analyze(cipher, options: opts, model: model).shift == shift { caesarOK += 1 }
    if CaesarAnalysis.analyze(cipher, options: opts, model: t % 2 == 0 ? dg : de).shift == shift { caesarDefaultOK += 1 }
    let corr = CaesarAnalysis.correlation(cipher, options: opts, model: model)
    if corr.firstIndex(of: corr.max()!) == shift { ct1Style += 1 }
    let short = String(cipher.prefix(25))
    if CaesarAnalysis.analyze(short, options: opts, model: model).shift == shift { caesarShortOK += 1 }
}
print("   Caesar 120 letters: n-gram \(caesarOK)/50, default model \(caesarDefaultOK)/50, CT1 correlation \(ct1Style)/50; 25 letters: \(caesarShortOK)/50")
check(caesarOK == 50 && caesarDefaultOK >= 48, "Caesar success")
check(caesarShortOK >= 45, "Caesar short texts")
let caesarText = "Hallo Welt, das ist ein geheimer Text über Straßen."
let caesarEnc = String(caesarText.map { ch -> Character in
    if ch.isASCII, let i = az.firstIndex(of: Character(ch.uppercased())) { let c = az[(i + 3) % 26]; return ch.isLowercase ? Character(c.lowercased()) : c }
    return ch
})
check(CaesarAnalysis.decrypt(caesarEnc, shift: 3, options: opts) == caesarText, "Caesar decrypt keeps case and ß")
check(CaesarAnalysis.mostFrequentLetterShift(String(repeating: "H", count: 5) + "ABC", options: opts) == 3, "most frequent letter → E")

// MARK: - Vigenère

section("Vigenère")
for (lang, testLetters, model) in [("Deutsch", germanTest, germanModel), ("Englisch", englishTest, englishModel)] {
    for length in [300, 400] {
        var ok = 0, lenOK = 0, total = 0
        var t = 0.0
        for keyLen in 3...15 {
            for _ in 0..<4 {
                let key = (0..<keyLen).map { _ in Int.random(in: 0..<26, using: &srng) }
                // avoid keys that are themselves periodic
                if keyLen > 1 && (1..<keyLen).contains(where: { p in keyLen % p == 0 && (0..<keyLen).allSatisfy { key[$0] == key[$0 % p] } }) { continue }
                let plain = chunk(testLetters, length: length)
                let cipher = vigenereEncrypt(plain, key: key)
                let (r, dt) = timed { VigenereAnalysis.analyze(cipher, options: opts, model: model) }
                t += dt
                total += 1
                if r.shifts == key { ok += 1 }
                if r.keyLength == keyLen { lenOK += 1 }
            }
        }
        print("   \(lang) \(length) letters, key length 3–15: key \(ok)/\(total), length \(lenOK)/\(total), avg \(String(format: "%.1f", t / Double(total) * 1000)) ms")
        check(Double(ok) >= 0.95 * Double(total), "Vigenère \(lang) \(length): \(ok)/\(total)")
    }
}
do {
    // default model (letters only) with longer texts
    var ok = 0, total = 0
    for keyLen in 3...12 {
        let key = (0..<keyLen).map { _ in Int.random(in: 0..<26, using: &srng) }
        let cipher = vigenereEncrypt(chunk(germanTest, length: 1000), key: key)
        let r = VigenereAnalysis.analyze(cipher, options: opts, model: dg)
        total += 1
        if r.shifts == key || (r.shifts.count < keyLen && (0..<keyLen).allSatisfy { key[$0] == r.shifts[$0 % r.shifts.count] }) { ok += 1 }
    }
    print("   default German model, 1000 letters: \(ok)/\(total)")
    check(ok >= total - 1, "Vigenère with default model")
}
do {
    let key = [2, 17, 24, 15, 19, 14, 14, 11]   // "CRYPTOOL"
    let plain = chunk(germanTest, length: 2000)
    let cipher = vigenereEncrypt(plain, key: key)
    let f = VigenereAnalysis.friedmanKeyLength(cipher, options: opts, model: germanModel)
    check(f > 5 && f < 12, "Friedman estimate \(f)")
    let kas = VigenereAnalysis.kasiski(cipher, options: opts)
    check(kas.prefix(3).allSatisfy { $0.distance % 8 == 0 }, "Kasiski distances \(kas.prefix(3).map { $0.distance })")
    let kls = VigenereAnalysis.keyLengthScores(cipher, options: opts, maxLength: 20)
    let bestKL = kls.max { $0.score < $1.score }!.length
    check(bestKL % 8 == 0, "key length scores best \(bestKL)")
    check(VigenereAnalysis.autocorrelationKeyLength(cipher, options: opts) == 8, "CT1 autocorrelation period")
    let r = VigenereAnalysis.analyze(cipher, options: opts, model: germanModel)
    check(r.key == "CRYPTOOL", "key string \(r.key)")
    check(VigenereAnalysis.analyze(cipher, options: opts, model: germanModel, keyLength: 16).key == "CRYPTOOL", "given key length 16 reduced to 8")
    let dec = VigenereAnalysis.decrypt("Icmnp Yfnu!", shifts: [1, 2], options: opts)
    check(dec == "Hallo Welt!", "Vigenère decrypt keeps case: \(dec)")
}

// German alphabet with umlauts and ß (30 symbols, quadgram model from the raw reference text)
do {
    let cut = german.index(german.startIndex, offsetBy: german.count * 7 / 10)
    let umlautModel = LanguageModel.from(referenceText: String(german[..<cut]), options: umlautOpts)
    check(umlautModel.alphabetSize == 30 && umlautModel.maxNGramOrder == 4 && umlautModel.letterFrequencies[29] > 0.001,
          "umlaut model: ß frequency \(umlautModel.letterFrequencies[29])")
    let testText = String(german[cut...])
    let testLetters = Array(umlautOpts.filtered(testText))
    check(testLetters.contains("ß") && testLetters.contains("Ü"), "test part contains ß and umlauts")
    var vigOK = 0, subAcc = 0.0, caesarOK = 0
    for t in 0..<8 {
        let plain = chunk(testLetters, length: 400)
        let key = (0..<(4 + t)).map { _ in Int.random(in: 0..<30, using: &srng) }
        let vc = umlautOpts.mapLetters(plain) { i, p in i + key[p % key.count] }
        if VigenereAnalysis.analyze(vc, options: umlautOpts, model: umlautModel).shifts == key { vigOK += 1 }
        let shift = Int.random(in: 1..<30, using: &srng)
        if CaesarAnalysis.analyze(umlautOpts.mapLetters(plain) { i, _ in i + shift }, options: umlautOpts, model: umlautModel).shift == shift { caesarOK += 1 }
        var perm = Array(0..<30); perm.shuffle(using: &srng)
        let sc = umlautOpts.mapLetters(plain) { i, _ in perm[i] }
        let r = SubstitutionAnalysis.automatic(sc, options: umlautOpts, model: umlautModel, restarts: 20, iterations: 2000, seed: UInt64(50 + t))
        subAcc += Double(zip(plain, r.plaintext).filter { $0 == $1 }.count) / Double(plain.count) / 8
    }
    print("   Umlaut alphabet (30 symbols), 400 letters: Vigenère \(vigOK)/8, Caesar \(caesarOK)/8, substitution avg \(String(format: "%.1f", subAcc * 100)) %")
    check(vigOK >= 7 && caesarOK == 8 && subAcc >= 0.9, "cracking with umlaut alphabet")
    // mixed-case German text with ß, punctuation and line breaks
    let original = String(testText.prefix(1200))
    let key = [11, 4, 18, 4, 17]
    let enc = umlautOpts.mapLetters(original) { i, p in i + key[p % key.count] }
    let r = VigenereAnalysis.analyze(enc, options: umlautOpts, model: umlautModel)
    // (case is compared insensitively: letters encrypted to the caseless "ß" lose their case)
    check(r.shifts == key && VigenereAnalysis.decrypt(enc, shifts: r.shifts, options: umlautOpts).uppercased() == original.uppercased(),
          "Vigenère round trip of formatted German text (key \(r.key))")
}

// MARK: - Byte-wise XOR / addition

section("ByteKeyAnalysis")
do {
    let englishBytes = Array(english.utf8)
    let refBytes = Array(englishBytes.prefix(englishBytes.count * 7 / 10))   // reference part
    let testBytes = Array(englishBytes.suffix(from: englishBytes.count * 7 / 10))
    var lenOK = 0, xorBytes = 0, addBytes = 0, keyBytes = 0, refXOR = 0, refADD = 0, total = 0
    for keyLen in 1...20 {
        let key = (0..<keyLen).map { _ in UInt8.random(in: 0...255, using: &srng) }
        let start = Int.random(in: 0..<(testBytes.count - 3000), using: &srng)
        let plain = Array(testBytes[start..<(start + 3000)])
        let xc = plain.enumerated().map { $0.element ^ key[$0.offset % keyLen] }
        let ac = plain.enumerated().map { $0.element &+ key[$0.offset % keyLen] }
        total += 1
        keyBytes += keyLen
        if ByteKeyAnalysis.estimateKeyLength(xc) % keyLen == 0 { lenOK += 1 }
        // CT1 method (most frequent byte ↦ space) with the true length: count correct key bytes
        let kx = ByteKeyAnalysis.analyzeXOR(xc, keyLength: keyLen)
        let ka = ByteKeyAnalysis.analyzeAddition(ac, keyLength: keyLen)
        xorBytes += zip(kx, key).filter { $0 == $1 }.count
        addBytes += zip(ka, key).filter { $0 == $1 }.count
        // reference variant, fully automatic
        if ByteKeyAnalysis.analyzeXOR(xc, referenceBytes: refBytes).key == key { refXOR += 1 }
        if ByteKeyAnalysis.analyzeAddition(ac, referenceBytes: refBytes).key == key { refADD += 1 }
        if keyLen == 7 {
            check(ByteKeyAnalysis.decryptXOR(xc, key: key) == plain, "XOR decrypt")
            check(ByteKeyAnalysis.decryptAddition(ac, key: key) == plain, "addition decrypt")
        }
    }
    print("   3000 bytes English, key length 1–20: CT1 length (or multiple) \(lenOK)/\(total); CT1 key bytes XOR \(xorBytes)/\(keyBytes), ADD \(addBytes)/\(keyBytes); reference variant exact keys XOR \(refXOR)/\(total), ADD \(refADD)/\(total)")
    check(lenOK >= total - 1, "CT1 key length estimate")
    check(Double(xorBytes) >= 0.8 * Double(keyBytes) && Double(addBytes) >= 0.8 * Double(keyBytes), "CT1 key bytes")
    check(refXOR >= total - 1 && refADD >= total - 1, "reference variant")
    // long text, short key: CT1 method finds the exact key automatically
    let key: [UInt8] = Array("CrypTool".utf8)
    let plain = Array(testBytes.prefix(12_000))
    let xc = plain.enumerated().map { $0.element ^ key[$0.offset % key.count] }
    let r = ByteKeyAnalysis.analyzeXOR(xc)
    check(r.keyLength == 8 && r.key == key, "CT1 XOR automatic \(Hex.encode(r.key))")
    let ac = plain.enumerated().map { $0.element &+ key[$0.offset % key.count] }
    check(ByteKeyAnalysis.analyzeAddition(ac).key == key, "CT1 addition automatic")
    // CT1 dialog default "00": binary data where 0x00 dominates every column
    var bin = [UInt8](repeating: 0, count: 6000)
    for i in 0..<bin.count where Int.random(in: 0..<10, using: &srng) < 4 { bin[i] = UInt8.random(in: 0...255, using: &srng) }
    let bkey: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x42]
    let enc = bin.enumerated().map { $0.element ^ bkey[$0.offset % bkey.count] }
    check(ByteKeyAnalysis.analyzeXOR(enc, expectedMostFrequent: 0x00).key == bkey, "XOR binary data with 0x00")
}

// MARK: - Substitution

section("Substitution")
for (lang, testLetters, model) in [("Deutsch", germanTest, germanModel), ("Englisch", englishTest, englishModel)] {
    var accs: [Double] = []
    var times: [Double] = []
    for trial in 0..<10 {
        var perm = Array(0..<26); perm.shuffle(using: &srng)      // encryption: plain p → cipher perm[p]
        let plain = chunk(testLetters, length: 400)
        let cipher = String(plain.map { az[perm[idx($0)]] })
        let (r, dt) = timed {
            SubstitutionAnalysis.automatic(cipher, options: opts, model: model, restarts: 20, iterations: 2000, seed: UInt64(trial + 1))
        }
        times.append(dt)
        let correct = zip(plain, r.plaintext).filter { $0 == $1 }.count
        accs.append(Double(correct) / Double(plain.count))
        if correct < plain.count * 9 / 10 {
            let trueScore = model.score(indices: opts.indices(of: plain))
            print("   diag: trial \(trial): acc \(correct), found score \(r.score), true score \(trueScore)\n   plain \(plain.prefix(80))\n   got   \(r.plaintext.prefix(80))")
        }
    }
    let minAcc = accs.min()!, avgAcc = accs.reduce(0, +) / Double(accs.count)
    print("   \(lang) 400 letters: min \(String(format: "%.1f", minAcc * 100)) %, avg \(String(format: "%.1f", avgAcc * 100)) %, time avg \(String(format: "%.2f", times.reduce(0, +) / Double(times.count))) s, max \(String(format: "%.2f", times.max()!)) s")
    check(minAcc >= 0.9, "substitution \(lang) ≥ 90 % (min \(minAcc))")
    check(!isRelease || times.max()! < 5, "substitution time (release)")
}
for length in [150, 200, 300] {
    var accSum = 0.0
    for trial in 0..<10 {
        var perm = Array(0..<26); perm.shuffle(using: &srng)
        let plain = chunk(trial % 2 == 0 ? germanTest : englishTest, length: length)
        let cipher = String(plain.map { az[perm[idx($0)]] })
        let r = SubstitutionAnalysis.automatic(cipher, options: opts, model: trial % 2 == 0 ? germanModel : englishModel,
                                               restarts: 20, iterations: 2000, seed: UInt64(100 + trial))
        let a = Double(zip(plain, r.plaintext).filter { $0 == $1 }.count) / Double(length)
        accSum += a
        if a < 0.9 { print("   diag: len \(length) trial \(trial) acc \(a) found \(r.score) true \(trial % 2 == 0 ? germanModel.score(indices: opts.indices(of: plain)) : englishModel.score(indices: opts.indices(of: plain)))") }
    }
    print("   (info) \(length) letters: avg \(String(format: "%.1f", accSum * 10)) % correct")
}
do {
    // keeps case and non-letters; key semantics
    let key = Array((0..<26).map { ($0 + 1) % 26 })     // cipher A → plain B …
    check(SubstitutionAnalysis.apply(key: key, to: "Abc, xyZ!", options: opts) == "Bcd, yzA!", "apply keeps case")
    check(SubstitutionAnalysis.invert(key)[1] == 0 && SubstitutionAnalysis.keyString(key, options: opts).hasPrefix("BCD"), "invert/keyString")
    // shorter text with a German sentence incl. spaces and punctuation
    var perm = Array(0..<26); perm.shuffle(using: &srng)
    let plain = String(german.dropFirst(5000).prefix(900))
    let cipher = TextOptions.default.mapLetters(plain) { i, _ in perm[i] }
    let token = CancellationToken()
    let progressBox = ProgressBox()
    let r = SubstitutionAnalysis.automatic(cipher, options: opts, model: germanModel, cancel: token, progress: { p in progressBox.set(p) })
    let ref = opts.filtered(plain)
    let got = opts.filtered(r.plaintext)
    let acc = Double(zip(ref, got).filter { $0 == $1 }.count) / Double(ref.count)
    check(acc >= 0.9 && progressBox.value == 1, "substitution with punctuation \(acc)")
    let cancelled = CancellationToken(); cancelled.cancel()
    let (_, tc) = timed { SubstitutionAnalysis.automatic(cipher, options: opts, model: germanModel, cancel: cancelled) }
    check(tc < 0.5, "cancellation")
}
final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock(); private var v = 0.0
    func set(_ x: Double) { lock.lock(); v = x; lock.unlock() }
    var value: Double { lock.lock(); defer { lock.unlock() }; return v }
}

// MARK: - Randomness tests

section("RandomnessTests")
approx(RandomnessTests.chiSquareQuantile(0.95, df: 1), 3.8415, 1e-4, "χ²(0.95;1)")
approx(RandomnessTests.chiSquareQuantile(0.95, df: 2), 5.9915, 1e-4, "χ²(0.95;2)")
approx(RandomnessTests.chiSquareQuantile(0.95, df: 7), 14.0671, 1e-4, "χ²(0.95;7)")
approx(RandomnessTests.chiSquareQuantile(0.95, df: 15), 24.9958, 1e-4, "χ²(0.95;15)")
approx(RandomnessTests.chiSquareQuantile(0.99, df: 4), 13.2767, 1e-4, "χ²(0.99;4)")
approx(RandomnessTests.chiSquareQuantile(0.90, df: 4), 7.7794, 1e-4, "χ²(0.90;4)")
approx(RandomnessTests.chiSquareQuantile(0.99, df: 255), 310.4574, 1e-3, "χ²(0.99;255)")
approx(RandomnessTests.chiSquareCDF(3.8415, df: 1), 0.95, 1e-5, "χ² CDF")

// HAC Example 5.31: 160 bits = 20 bytes
let hacBits = String(repeating: "1110001100010001010011101111001001001001", count: 4)
var hacBytes: [UInt8] = []
for i in stride(from: 0, to: 160, by: 8) {
    let s = hacBits.dropFirst(i).prefix(8)
    hacBytes.append(UInt8(s, radix: 2)!)
}
let f1 = RandomnessTests.frequencyTest(hacBytes)
approx(f1.statistic, 0.4, 1e-9, "HAC frequency X1")
check(f1.passed && abs(f1.threshold - 3.8415) < 1e-4, "HAC frequency passes")
approx(RandomnessTests.serialTest(hacBytes).statistic, 0.6252, 1e-4, "HAC serial X2")
let p3 = RandomnessTests.pokerTest(hacBytes, m: 3)
approx(p3.statistic, 9.6415, 1e-4, "HAC poker X3")
check(p3.passed && abs(p3.threshold - 14.0671) < 1e-4, "HAC poker threshold")
let r4 = RandomnessTests.runsTest(hacBytes)
approx(r4.statistic, 31.7913, 1e-4, "HAC runs X4")
check(!r4.passed && abs(r4.threshold - 9.4877) < 1e-4, "HAC runs fails")

var gen = SeededRNG(state: 42)
let randomData = (0..<20_000).map { _ in UInt8.random(in: 0...255, using: &gen) }
for t in [RandomnessTests.frequencyTest(randomData, alpha: 0.01), RandomnessTests.serialTest(randomData, alpha: 0.01),
          RandomnessTests.pokerTest(randomData, alpha: 0.01), RandomnessTests.pokerTest(randomData, m: 4, alpha: 0.01),
          RandomnessTests.runsTest(randomData, alpha: 0.01), RandomnessTests.longRunTest(randomData)] {
    check(t.passed, "random data passes \(t.name): \(t.statistic) > \(t.threshold)")
}
let textData = Array(german.utf8.prefix(20_000))
check(!RandomnessTests.frequencyTest(textData).passed && !RandomnessTests.pokerTest(textData).passed, "text fails tests")
check(!RandomnessTests.longRunTest([UInt8](repeating: 0, count: 100)).passed, "long run on zeros fails")
check(!RandomnessTests.frequencyTest([1, 2, 3]).passed, "too short")
let fips = RandomnessTests.fips140_1(randomData)
check(fips.count == 4 && fips.allSatisfy { $0.passed }, "FIPS random passes: \(fips.filter { !$0.passed }.map { $0.name })")
let fipsText = RandomnessTests.fips140_1(textData)
check(fipsText.count == 4 && !fipsText[0].passed, "FIPS text fails monobit")
let fipsShort = RandomnessTests.fips140_1([UInt8](repeating: 1, count: 100))
check(fipsShort.count == 1 && !fipsShort[0].passed, "FIPS too short")

let (vr, tv) = timed { RandomnessTests.vitanyi(randomData) }
print("   Vitányi random 8 KB: mean \(String(format: "%.4f", vr.mean)), variation \(String(format: "%.3f", vr.variation)), points \(vr.pointCount), \(String(format: "%.2f", tv)) s")
check(!vr.degenerate && vr.pointCount == 1023 && !vr.series.isEmpty, "Vitányi random")
check(!isRelease || tv < 3, "Vitányi time")
let vz = RandomnessTests.vitanyi([UInt8](repeating: 0, count: 1000))
check(vz.degenerate, "Vitányi zeros degenerate")
let vt = RandomnessTests.vitanyi(textData)
print("   Vitányi text: mean \(vt.mean), variation \(String(format: "%.3f", vt.variation)), degenerate \(vt.degenerate), points \(vt.pointCount)")

// MARK: - Password tools

section("PasswordTools")
check(PasswordTools.alphabetSize(of: "abc") == 26, "alphabet size lower")
check(PasswordTools.alphabetSize(of: "aB1!") == 78, "alphabet size mixed")
check(PasswordTools.alphabetSize(of: "aB1!:") == 95, "alphabet size full ASCII")
approx(PasswordTools.entropy(length: 8, alphabetSize: 26), 37.6035, 1e-4, "entropy length 8")
check(PasswordTools.requiredLength(entropyBits: 128, alphabetSize: 16) == 32, "required length")
let pwd = PasswordTools.generate(entropyBits: 128, alphabet: "0123456789ABCDEF")
check(pwd.count == 32 && pwd.allSatisfy { "0123456789ABCDEF".contains($0) }, "generate hex")
let pwd2 = PasswordTools.generate(entropyBits: 80, alphabet: "aab")
check(pwd2.count == 80 && Set(pwd2).isSubset(of: ["a", "b"]), "generate dedups alphabet")
check(PasswordTools.generate(entropyBits: 80, alphabet: "aaa").isEmpty, "generate needs ≥ 2 chars")
check(PasswordTools.alphabetPresets.count >= 8 && PasswordTools.alphabetPresets[0].name == "Kleinbuchstaben", "presets")
check(PasswordTools.qualityKeePass("abcdefgh") == 29, "KeePass quality")
check(PasswordTools.qualityMozilla("abcdefgh") == 30, "Mozilla quality")
check(PasswordTools.qualityPGP("abcdefgh") == 31, "PGP quality")
for (pw, levels) in [("123456", ["sehr schwach"]), ("password", ["sehr schwach"]), ("qwertz", ["sehr schwach"]),
                     ("Sommer2024", ["sehr schwach", "schwach"]),
                     ("x7#Kp!2vQz", ["mittel", "stark"]),
                     ("G7$kq!Zp2#vW9@rT4&mY", ["stark", "sehr stark"])] {
    let q = PasswordTools.quality(of: pw)
    check(levels.contains(q.level), "quality of \(pw): \(q.level) (score \(q.score), \(String(format: "%.1f", q.entropyBits)) bit) \(q.remarks)")
}
let qp = PasswordTools.quality(of: "passwort12.03.1990")
check(qp.remarks.contains { $0.hasPrefix("Wörterbuch") } && qp.remarks.contains { $0.hasPrefix("Muster") }, "remarks found word and date: \(qp.remarks)")
let qk = PasswordTools.quality(of: "asdfgh")
check(qk.remarks.contains { $0.hasPrefix("Tastatur") } && qk.entropyBits < 20, "keyboard sequence \(qk.entropyBits)")
let qs = PasswordTools.quality(of: "abcdefg")
check(qs.remarks.contains { $0.hasPrefix("Folgen") } && qs.components == "abcdefg", "sequence components '\(qs.components)'")
check(PasswordTools.quality(of: "").score == 0, "empty password")

// MARK: - CT1 analyses (separate files)

runCT1SchroedelTests()
runCT1SubstitutionTests()
runCT1AnalysisToolsTests()
runCT1ClassicFlowTests()
runCT1PasswordTests()
runCT1TutorialTests()
runCracklibTests()

// MARK: - Summary

print("\nCTAnalysisTests: \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
