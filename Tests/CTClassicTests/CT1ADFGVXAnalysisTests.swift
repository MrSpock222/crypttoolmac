import Foundation
import CTCommon
import CTClassic

/// CT1 ADFGVX-Analyse (DlgAdfgvxManual / adfgvx.cpp) – called from main.swift.
func runCT1ADFGVXAnalysisTests() {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let reference = (try? String(contentsOf: root.appendingPathComponent("Resources/Reference/deutsch.txt"), encoding: .utf8)) ?? ""
    let sample = (try? String(contentsOf: root.appendingPathComponent("Resources/Examples/Startbeispiel-de.txt"), encoding: .utf8)) ?? ""

    group("CT1 ADFGVX-Analyse: Hilfsfunktionen") {
        expectEqual(ADFGVXAnalysis.numberedPassword("CAB"), "-3-1-2-")
        expectEqual(ADFGVXAnalysis.numberedPassword(""), "")
        expectEqual(ADFGVXAnalysis.numberedPassword("GEHEIM"), "-3-1-4-2-5-6-")   // equal letters: left first (CT1)
        var p: [Character] = Array("ACB")
        expect(ADFGVXAnalysis.nextPermutation(&p) && String(p) == "BAC", "next_permutation ACB → BAC")
        p = Array("CBA")
        expect(!ADFGVXAnalysis.nextPermutation(&p) && String(p) == "ABC", "next_permutation wraps")
        let f36 = (1...36).reduce(1.0) { $0 * Double($1) }
        expect(abs(ADFGVXAnalysis.remainingPossibilities(ADFGVXAnalysis.emptyMatrix) / f36 - 1) < 1e-12, "36!")
        expectEqual(ADFGVXAnalysis.remainingPossibilities(ADFGVXAnalysis.standardMatrix), 0)
        var m = ADFGVXAnalysis.standardMatrix
        m[0][0] = "*"; m[5][5] = "*"; m[2][2] = "*"
        expectEqual(ADFGVXAnalysis.remainingPossibilities(m), 6)
        expectEqual(ADFGVXAnalysis.remainingCharacters(m), "AO9")
        let sb = ADFGVXAnalysis.matrix(fromString: "geheimnis")!
        expectEqual(String(sb.flatMap { $0 }), "GEHIMNSABCDFJKLOPQRTUVWXYZ0123456789")
        expect(ADFGVXAnalysis.matrix(fromString: "!!") == nil, "Zeichenkette ohne gültige Zeichen")
        expectEqual(ADFGVXAnalysis.checkPassword("KEY", alphabet: TextOptions.uppercaseLetters), .valid)
        expectEqual(ADFGVXAnalysis.checkPassword("KEY1", alphabet: TextOptions.uppercaseLetters), .invalidCharacters)
        expectEqual(ADFGVXAnalysis.checkPassword("KEYK", alphabet: TextOptions.uppercaseLetters), .duplicateCharacters)
        expectEqual(ADFGVXAnalysis.cleansePassword("K-E1Y", alphabet: TextOptions.uppercaseLetters), "KEY")
        let key = ADFGVXAnalysis.keyString(password: "CAB", matrix: ADFGVXAnalysis.standardMatrix)
        expect(ADFGVXAnalysis.parseKey(key).map { $0.password == "CAB" && $0.matrix == ADFGVXAnalysis.standardMatrix } == true, "Schlüssel (Mac-Format)")
        expect(ADFGVXAnalysis.parseKey("CAB, ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map { $0.password == "CAB" && $0.matrix == ADFGVXAnalysis.standardMatrix } == true, "Schlüssel (CT1-Format)")
        expectThrows("ungültiges Chiffrat") { _ = try ADFGVXAnalysis(ciphertext: "ADFGVB") }
        expectThrows("ungerade Länge") { _ = try ADFGVXAnalysis(ciphertext: "ADF") }
        expect((try? ADFGVXAnalysis(ciphertext: "ad fg\nvx"))?.count == 6, "Leerraum/Kleinbuchstaben")
        let stats = ADFGVXAnalysis.referenceStatistics(reference, includeDigits: false)
        expect(stats.map { $0.letters.count == 26 && String($0.letters.prefix(2)) == "EN" } == true,
               "Häufigkeitsreihenfolge deutsch: \(String(stats?.letters ?? []))")
        expect(stats.map { (14...17).contains($0.highestFrequency) } == true, "Schwelle \(stats?.highestFrequency ?? -1)")
    }

    // Plaintext: CT1 start example (German); the transposition passwords below are within the default
    // search range 1…8 of CT1.
    let plain = String(sample.prefix(1600))
    let truth = ADFGVXCipher.symbols   // deterministic mixed matrix
    var rng = ADFGVXTestRNG(seed: 4711)
    let mixed = truth.shuffled(using: &rng)
    let matrix = (0..<6).map { r in Array(mixed[(r * 6)..<(r * 6 + 6)]) }
    let expectedPlain = String(ADFGVXCipher.plaintextSymbols(plain)).lowercased()

    for key in ["KEY", "WOLKE", "PRIVACY", "GEHEIM", "SCHWARZ"] {
        group("CT1 ADFGVX-Analyse: Transposition „\(key)“") {
            let cipher = try ADFGVXCipher(matrix: matrix, transpositionKey: key)
            let ct = cipher.encrypt(plain)
            var a = try ADFGVXAnalysis(ciphertext: ct)
            if let s = ADFGVXAnalysis.referenceStatistics(reference, includeDigits: false) { a.setFrequencyTable(s) }
            let trueStage1 = cipher.substitute(plain)
            // repeated "Analysieren" (CT1 continues after the last found password)
            var last = ""
            var current = ""
            var found: String? = nil
            var clicks = 0
            let t0 = Date()
            while clicks < 40 {
                clicks += 1
                let r = a.searchNextPassword(minLength: 1, maxLength: 8, start: current, lastPasswordFound: last)
                if r.password.isEmpty { break }
                last = r.password; current = r.password
                if a.stage1Text(password: r.password) == trueStage1 { found = r.password; break }
            }
            let elapsed = Date().timeIntervalSince(t0)
            guard let pw = found else { fail("Passwort für \(key) nicht gefunden (\(clicks) Klicks)"); return }
            expectEqual(ADFGVXAnalysis.columnOrder(pw), cipher.columnOrder, "Spaltenreihenfolge")
            expect(clicks <= (key.count % 2 == 1 ? 5 : 20), "Anzahl Klicks auf „Analysieren“: \(clicks)")
            print("    \(key): Passwort \(pw) \(ADFGVXAnalysis.numberedPassword(pw)) nach \(clicks) Klick(s), \(String(format: "%.2f", elapsed)) s")
            // stage 1: frequency matching puts E (most frequent letter) into the right cell
            let fm = a.forcedMatrix(password: pw)
            let eCell = matrix.flatMap { $0 }.firstIndex(of: "E")!
            expectEqual(fm[eCell / 6][eCell % 6], "E", "E per Häufigkeitsanalyse")
            let fmFlat: [Character] = fm.flatMap { $0 }
            let trueFlat: [Character] = matrix.flatMap { $0 }
            var correct = 0
            for i in 0..<36 where fmFlat[i] == trueFlat[i] { correct += 1 }
            expect(correct >= 3, "mindestens 3 Zellen richtig per Häufigkeit (\(correct))")
            // partial solution shows unassigned bigrams as ADFGVX pairs
            let partial = a.plaintext(password: pw, matrix: fm)
            expect(partial.contains("e") && partial.count > expectedPlain.count, "Teillösung")
            // completed matrix (manual stage) → plaintext as in CT1 (lowercase)
            expectEqual(a.plaintext(password: pw, matrix: matrix), expectedPlain, "Klartext")
            // "Übernehmen" with the real key (letters A–Z) gives the same
            expectEqual(a.plaintext(password: key, matrix: matrix), expectedPlain, "Übernehmen mit echtem Passwort")
        }
    }

    group("CT1 ADFGVX-Analyse: Suchbereich ohne Treffer / Abbruch") {
        let cipher = try ADFGVXCipher(matrix: matrix, transpositionKey: "PRIVACY")
        var a = try ADFGVXAnalysis(ciphertext: cipher.encrypt(plain))
        if let s = ADFGVXAnalysis.referenceStatistics(reference, includeDigits: false) { a.setFrequencyTable(s) }
        let r = a.searchNextPassword(minLength: 1, maxLength: 4, start: "", lastPasswordFound: "")
        expect(r.password.isEmpty && !r.cancelled, "kein Passwort der Länge 1…4: \(r.password)")
        let token = CancellationToken()
        token.cancel()
        let c = a.searchNextPassword(minLength: 9, maxLength: 9, start: "", lastPasswordFound: "", cancel: token)
        expect(c.cancelled && c.password.isEmpty, "Abbruch")
    }
}

/// Small deterministic generator for the test matrix.
struct ADFGVXTestRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
