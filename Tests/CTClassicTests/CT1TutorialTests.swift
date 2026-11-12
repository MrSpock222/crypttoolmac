import Foundation
import CTCommon
import CTClassic

/// Steps of CT1's tutorials (online help "Szenarien", CrypTool1-Presentation-de.pdf) with
/// concrete results – called from main.swift.
func runCT1TutorialTests() {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    func example(_ name: String) -> String {
        TextCoding.string(from: [UInt8](FileManager.default.contents(atPath: root.appendingPathComponent("Resources/Examples/\(name)").path) ?? Data()))
    }
    let o = TextOptions.default
    let cryptool = example("CrypTool-de.txt")

    group("CT1-Szenario Caesar (CrypTool-de.txt, Schlüssel A, Offset 1 = Verschiebung 1)") {
        // CT1 1.4.x's CrypTool-de.txt starts with "Was ist CrypTool?" (the scenario's older file with "CrypTool ist …")
        let c = Caesar.encrypt(cryptool, shift: 1, options: o)
        expect(c.hasPrefix("Xbt jtu DszqUppm?"), "Was ist CrypTool → Xbt jtu DszqUppm (got \(c.prefix(17)))")
        expectEqual(Caesar.decrypt(c, shift: 1, options: o), cryptool)
        // Textoptionen: Formatierung und Groß-/Kleinschreibung nicht beibehalten
        let plain = TextOptions(alphabet: TextOptions.uppercaseLetters, distinguishCase: false, keepCase: false, keepNonAlphabet: false)
        let c2 = Caesar.encrypt(cryptool, shift: 1, options: plain)
        expect(c2.hasPrefix("XBTJTUDSZQUPPMDSZQUPPMW"), "ohne Formatierung: XBTJTUDSZQUPPM… (got \(c2.prefix(23)))")
        expect(Caesar.decrypt(c2, shift: 1, options: plain).hasPrefix("WASISTCRYPTOOLCRYPTOOLV"), "WASISTCRYPTOOLCRYPTOOLV…")
    }

    group("CT1-Präsentation: Caesar, Vigenère (Folien 11, 12)") {
        expectEqual(Caesar.encrypt("GALLIA EST OMNIS DIVISA", shift: 3, options: o), "JDOOLD HVW RPQLV GLYLVD")
        expectEqual(try Vigenere.encrypt("VIGENERE", key: "CHIFFRE", options: o), "XPOJSVVG")
    }

    group("CT1-Szenario Vigenère (CrypTool-de.txt, CRYPTOOL)") {
        let c = try Vigenere.encrypt(cryptool, key: "CRYPTOOL", options: o)
        expectEqual(try Vigenere.decrypt(c, key: "CRYPTOOL", options: o), cryptool)
    }

    group("CT1-Szenario Hill / Präsentation (25)") {
        // CT1 1.4.x always multiplies (Matrix) * (Vektorspalte) (iHillMultiplicationType = 0).
        let test = HillCipher.matrix(fromKeyword: "TEST", size: 2, options: o)!
        expectEqual(test, [[19, 4], [18, 19]])
        let h = try HillCipher(matrix: test, options: o, multiplication: .matrixTimesVector)
        // the scenario text (older CT1) shows RYRTAEVLSB = (Vektorreihe) * (Matrix)
        expectEqual(h.encrypt("Hillcipher"), "Jstrsgbnof")
        expectEqual(try HillCipher(matrix: test, options: o, multiplication: .vectorTimesMatrix).encrypt("HILLCIPHER"), "RYRTAEVLSB")
        if case .found(let r) = CT1HillKnownPlaintext.search(plaintext: "Hillcipher", ciphertext: "Jstrsgbnof", dimensions: 1...10,
                                                               multiplication: .matrixTimesVector, options: o) {
            expectEqual(r.matrix, test, "Known-Plaintext findet T E S T")
        } else { expect(false, "Hill-Analyse Hillcipher") }
        // Folie 101: Schlüssel LVMH, "CrypTool" → "PnhdJovl", verkürzter Klar-/Geheimtext findet den Schlüssel
        let lvmh = HillCipher.matrix(fromKeyword: "LVMH", size: 2, options: o)!
        let h2 = try HillCipher(matrix: lvmh, options: o, multiplication: .matrixTimesVector)
        expectEqual(h2.encrypt("CrypTool"), "PnhdJovl")
        let start = example("Startbeispiel-de.txt")
        if case .found(let r) = CT1HillKnownPlaintext.search(plaintext: start, ciphertext: h2.encrypt(start), dimensions: 1...10,
                                                               multiplication: .matrixTimesVector, options: o) {
            expectEqual(r.matrix, lvmh, "Startbeispiel-de.txt: Schlüssel LVMH")
        } else { expect(false, "Hill-Analyse Startbeispiel") }
        if case .found(let r) = CT1HillKnownPlaintext.search(plaintext: "CrypTool", ciphertext: "PnhdJovl", dimensions: 1...10,
                                                               multiplication: .matrixTimesVector, options: o) {
            expectEqual(r.matrix, lvmh, "CrypTool/PnhdJovl: Schlüssel LVMH")
        } else { expect(false, "Hill-Analyse CrypTool/PnhdJovl") }
    }

    group("CT1-Szenario Playfair (PEGASOS)") {
        let p = PlayfairCipher(keyword: "PEGASOS")
        expectEqual(p.matrixString, "PEGASOBCDFHIKLMNQRTUVWXYZ")
        // CT1 1.4.x default "Doppelbuchstaben nur innerhalb von Paaren trennen" (DlgKeyPlayfair.cpp)
        expectEqual(p.preformat("CrypTool ist").joined(), "CRYPTOOLISTX")
        // the scenario's CRYPTOXOLIST / KXVANDVCMKAU: option switched off
        let q = PlayfairCipher(keyword: "PEGASOS", separateOnlyWithinPairs: false)
        expectEqual(q.preformat("CrypTool ist").joined(), "CRYPTOXOLIST")
        expectEqual(q.encrypt("CrypTool ist").filter { !$0.isWhitespace }, "KXVANDVCMKAU")
    }

    group("CT1-Szenario monoalphabetische Substitution (CRYPTOOL)") {
        // the scenario's table A→C, B→R, C→Y, D→P … Y→B, Z→A is CT1's variant
        // "Restliche Zeichen absteigend füllen"
        let k = String(SubstitutionCipher.keyAlphabet(fromKeyword: "CRYPTOOL", options: o, remainingDescending: true, offset: 0))
        expect(k.hasPrefix("CRYPTOL") && k.hasSuffix("BA"), "absteigend: \(k)")
        let asc = String(SubstitutionCipher.keyAlphabet(fromKeyword: "CRYPTOOL", options: o, remainingDescending: false, offset: 0))
        expect(asc.hasPrefix("CRYPTOLABD"), "aufsteigend (CT1-Vorgabe): \(asc)")
        let c = try SubstitutionCipher(keyAlphabet: k, options: o)
        let probe = example("probetext-de.txt")
        expectEqual(c.decrypt(c.encrypt(probe)), probe)
    }
}
