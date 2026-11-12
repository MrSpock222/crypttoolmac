import Foundation
import CTCommon
import CTClassic

/// CT1 manual Playfair analysis (PlayfairAnalysis.cpp) – called from main.swift.
/// The scenario follows CT1's help ("Szenarien ▸ Playfair", chapter 3) with Playfair-enc-de.txt.
func runCT1PlayfairAnalysisTests() {
    group("CT1 Playfair-Analyse: Szenario Playfair-enc-de.txt") {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources/Examples/Playfair-enc-de.txt")
        guard let data = try? Data(contentsOf: url), let cipher = String(data: data, encoding: .utf8) else {
            fail("Playfair-enc-de.txt nicht lesbar"); return
        }
        let s = PlayfairAnalysisSession(ciphertext: cipher)
        expectEqual(s.warning, .invalidCharacters, "Leerzeichen/Satzzeichen → WARNMSG002")
        expectEqual(s.size, .fiveByFive)
        expectEqual(s.matrixString, String(repeating: "*", count: 25), "Startmatrix leer")
        // 3.5: guessed beginning of the letter
        let g1 = "SEHR GEEHRTE DAMEN UND HERREN"
        let r1 = s.analyzePlaintext(g1)
        expect(r1.error == nil, "keine Inkonsistenz: \(r1.error?.message ?? "")")
        let l = s.analysisLines
        expect(l.cipher.hasPrefix("TGIG.HRRIEFR.XVNIX.AXL.RRGGRX"), l.cipher)
        // help: SE>TG HR>IG GE>HR EH>RI RT>EF ED>RX AM>VN EN>IX UN>AX DH>LR ER>RG RE>GR
        // line 2: digram letters substituted throughout; the last N pairs with an unguessed letter
        expect(l.guess.hasPrefix("SEHR.GEEHRTE.DAMEN.UND.HERRE*"), l.guess)
        expect(l.guess.contains(".GE****ER."), "gefundene Digramme durchgehend ersetzt: \(l.guess)")
        // letter information like CT1 (E/R/G/H/I in one row)
        let infoE = s.letterInfos.first { $0.letter == "E" }!
        expectEqual(infoE.neighbours, "*R**", "E: R rechts daneben")
        expectEqual(infoE.horizontal, "R!,I.")
        let infoR = s.letterInfos.first { $0.letter == "R" }!
        expectEqual(infoR.neighbours, "E***")
        expectEqual(infoR.horizontal, "E!")
        // 3.6 "Erzeuge Matrix"
        expect(s.createMatrix(guess: g1), "Matrix 1 gefunden")
        expect(s.letterInfos.first!.weight >= s.letterInfos.last!.weight, "Tabelle nach Metrik sortiert")
        let e1 = s.expectedPlaintext
        expect(e1.hasPrefix("SEHR.GEEHRTE.DAMEN.UND.HERREN"), e1)
        expect(e1.contains("E**.*IEMLI**"), "Teilworte E**.*IEMLI** (Hilfe 3.8): \(e1)")
        // 3.8: complete to EIN.ZIEMLICH
        let g2 = e1.replacingOccurrences(of: "E**.*IEMLI**", with: "EIN.ZIEMLICH")
        expect(s.analyzePlaintext(g2).error == nil)
        expect(s.createMatrix(guess: g2), "Matrix 2 gefunden")
        // help 3.8 shows "***KB UZ**A XDMLN TFSCO ERGHI" (hand-made table); V is forced by AM > VN
        // with A and M placed – it appears at exactly this position in the help's matrix of 3.10
        expectEqual(s.matrixString, "***KBUZV*AXDMLNTFSCOERGHI", "Matrix wie in Hilfe 3.8 (+ V)")
        let e2 = s.expectedPlaintext
        expect(e2.contains("GEHEIMER.*X**.BLEIOT.NICH*.IMMER.**NGE.GEHEIM"), e2)
        expect(e2.contains("MI*.*DXUNDLICHEN.GRUX**EN"), e2)
        // 3.9: corrections
        var g3 = e2
        for (a, b) in [("*X**", "****"), ("BLEIOT", "BLEIBT"), ("NICH*", "NICHT"), ("**NGE", "LANGE"),
                       ("MI*.*DXUNDLICHEN", "MIT.FREUNDLICHEN"), ("GRUX**EN", "GRUESSEN")] {
            g3 = g3.replacingOccurrences(of: a, with: b)
        }
        expect(s.analyzePlaintext(g3).error == nil)
        expect(s.createMatrix(guess: g3), "Matrix 3 gefunden")
        expectEqual(s.matrixString, "TFSKBUZVWAXDMLN***COERGHI", "Matrix wie in Hilfe 3.10")
        let e3 = s.expectedPlaintext
        expect(e3.contains("GEHEIMER.TE**.BLEIBT"), e3)
        // 3.11: TEXT
        let g4 = e3.replacingOccurrences(of: "TE**", with: "TEXT")
        expect(s.analyzePlaintext(g4).error == nil)
        expect(s.createMatrix(guess: g4), "Matrix 4 gefunden")
        expectEqual(s.matrixString, "TFSKBUZVWAXDMLNP**COERGHI", "Matrix wie in Hilfe 3.11")
        let plain = "SEHRGEEHRTEDAMENUNDHERRENEINZIEMLICHGEHEIMERTEXTBLEIBTNICHTIMMERLANGEGEHEIMMITFREUNDLICHENGRUESSEN"
        expect(s.decryptAll().hasPrefix(plain), s.decryptAll())
        expectEqual(s.password, "TFSKBUZVWAXDMLNP**COERGHI")
        // 3.12: the original key (duplicates not ignored) yields a cyclically shifted, equivalent matrix
        let key = PlayfairCipher(keyword: "HIERGIBTESWASZUENTDECKEN", ignoreDuplicateKeyLetters: false)
        expect(key.decrypt(cipher).hasPrefix(plain), "Originalschlüssel")
        s.setIgnoreDuplicateLetters(false)
        s.setPassword("hierGIBTesWASzuENTDECKEN")
        expectEqual(s.password, "HIERGIBTESWASZUENTDECKEN")
        expectEqual(s.matrix, key.matrix, "Passwort → Matrix wie Playfair-Verschlüsselung")
        expect(s.decryptAll().hasPrefix(plain))
        expect(!s.expectedPlaintext.contains("*"))
    }

    group("CT1 Playfair-Analyse: Buchstabengraph und Fehler") {
        // help example: cipher ABCD, guess QWCA → C at position 3 maps to itself
        let s = PlayfairAnalysisSession(ciphertext: "ABCD")
        expect(s.warning == nil)
        let r = s.analyzePlaintext("QWCA")
        expectEqual(r.error?.code, 1)
        expectEqual(r.error?.position, 2)
        expectEqual(r.error?.letter, "C")
        expect(r.error?.message.hasPrefix("Bei Playfair sind Klarbuchstabe und Chiffrezeichen immer verschieden.\nPosition=3, Buchstabe=C") == true)
        // digram AB → BC: B right of/below A, C right of/below B
        let t = PlayfairAnalysisSession(ciphertext: "BC")
        expect(t.analyzePlaintext("AB").error == nil)
        let a = t.letterInfos.first { $0.letter == "A" }!
        expectEqual(a.possibleNeighbours, "/B")
        expectEqual(a.weight, 80 + 5)
        expectEqual(a.neighbours, "****")
        let b = t.letterInfos.first { $0.letter == "B" }!
        expectEqual(b.possibleNeighbours, "A/C")
        // rectangle rule: AB → CD gives "row or below" / "row or col"
        let u = PlayfairAnalysisSession(ciphertext: "CD")
        u.analyzePlaintext("AB")
        let ua = u.letterInfos.first { $0.letter == "A" }!
        expectEqual(ua.horizontal, "C.")
        expectEqual(ua.rowOrColumn, "C,D")
        let uc = u.letterInfos.first { $0.letter == "C" }!
        expectEqual(uc.horizontal, "A°")
        // same cipher digram with two different guesses → the later one counts (CT1)
        // J in a 5×5 guess is reported
        expect(u.analyzePlaintext("JB").containsInvalidLetters)
        // inconsistent guess: the same plaintext digram may not give two different neighbours
        let v = PlayfairAnalysisSession(ciphertext: "BCBD")
        expect(v.analyzePlaintext("ABAB").error == nil, "Graph erkennt den Widerspruch nicht (wie CT1)")
        expect(!v.createMatrix(guess: "ABAB"), "AB → BC und AB → BD widersprechen sich")
        // overflow of a list: five letters surely in A's row (5×5)
        let w = PlayfairAnalysisSession(ciphertext: "BCCDDE")
        let rw = w.analyzePlaintext("ABACAD")   // B, C and D all right of/below A
        expectEqual(rw.error?.code, 103)
        expect(rw.error?.message.contains("Eine der Tabellen ist übergelaufen: Position=0, Buchstabe=A") == true, rw.error?.message ?? "")
    }

    group("CT1 Playfair-Analyse: Matrix, Passwort, Größe") {
        let cipherKey = PlayfairCipher(keyword: "PEGASOS")
        let plain = "CRYPTOOLISTEINLERNPROGRAMMFUERKRYPTOGRAPHIEUNDKRYPTOANALYSE"
        let c = cipherKey.encrypt(plain)
        let pre = cipherKey.preformat(plain).joined()
        // full known plaintext → complete matrix equivalent to the key matrix
        guard let m = PlayfairAnalysisSession.reconstructMatrix(plaintext: pre, ciphertext: c) else {
            fail("keine Matrix rekonstruiert"); return
        }
        let flat = m.flatMap { $0 }
        if !flat.contains("*") {
            let k = try PlayfairCipher(matrix: m)
            expectEqual(k.decrypt(c), cipherKey.decrypt(c), "äquivalente Matrix")
        } else {
            let s = PlayfairAnalysisSession(ciphertext: c)
            s.setMatrix(m)
            expectEqual(s.decryptAll(), cipherKey.decrypt(c), "Teilmatrix entschlüsselt den bekannten Text")
        }
        // contradiction → no matrix, matrix stays empty
        let s = PlayfairAnalysisSession(ciphertext: "BCBD")
        expect(!s.createMatrix(guess: "ABAB"), "Widerspruch")
        expectEqual(s.matrixString, String(repeating: "*", count: 25))
        expect(!s.createMatrix(guess: "BX"), "Klarbuchstabe = Chiffrebuchstabe")
        // password field: invalid characters removed, J not allowed for 5×5, umlauts converted
        let p = PlayfairAnalysisSession(ciphertext: "ABCD")
        expect(!p.setPassword("Mäjor 1"))
        expectEqual(p.password, "MAOR")
        expectEqual(String(p.matrix[0]), "MAORB")
        // cell input swaps letters
        expect(p.setCell(row: 0, column: 0, to: "b"))
        expectEqual(String(p.matrix[0]), "BAORM")
        expectEqual(p.password, "BAORMCDEFGHIKLNPQSTUVWXYZ")
        expect(!p.setCell(row: 0, column: 0, to: "J"), "J ungültig bei 5x5")
        // 6×6
        let six = PlayfairAnalysisSession(ciphertext: "AB1J")
        expectEqual(six.warning, .possibly6x6)
        expectEqual(six.size, .sixBySix)
        expectEqual(six.matrixString.count, 36)
        six.setSize(.fiveByFive, guess: "")
        expectEqual(six.matrixString.count, 25)
        expectEqual(six.analysisLines.cipher, "AB..")
        // analysis lines: initial second line empty (no warning), then digram letters
        expectEqual(PlayfairAnalysisSession(ciphertext: "KXVA").analysisLines.guess, "")
        let q = PlayfairAnalysisSession(ciphertext: "KX VA")
        expectEqual(q.analysisLines.guess, "**.**")
        q.analyzePlaintext("CR YP")
        expectEqual(q.analysisLines.guess, "CR.YP")
        expectEqual(q.analysisLines.plain, "**.**")
        q.setPassword("PEGASOS")
        expectEqual(q.analysisLines.plain, "CR.YP")
        expectEqual(q.decryptAll(), "CRYP")
    }

    group("CT1 Playfair-Analyse: Laufzeit") {
        // a consistent guess for a long text must be solved quickly
        let k = PlayfairCipher(keyword: "GEHEIMSCHLUESSEL")
        let text = "DIEPLAYFAIRVERSCHLUESSELUNGWURDEVONCHARLESWHEATSTONEERFUNDENUNDVONLORDPLAYFAIRBEKANNTGEMACHT"
        let pre = k.preformat(text).joined()
        let c = k.encrypt(text)
        let t0 = Date()
        let m = PlayfairAnalysisSession.reconstructMatrix(plaintext: pre, ciphertext: c)
        expect(m != nil)
        expect(Date().timeIntervalSince(t0) < 5, "Laufzeit \(Date().timeIntervalSince(t0)) s")
    }
}
