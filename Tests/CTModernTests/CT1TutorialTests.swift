import Foundation
import CTCommon
import CTModern

/// Steps of CT1's tutorials (online help "Szenarien", CrypTool1-Presentation-de.pdf) with
/// concrete results – called from main.swift.
func runCT1TutorialTests() {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// Example file as loaded by the app (text examples in CT1's Windows-1252 bytes).
    func example(_ name: String) -> [UInt8] {
        let d = [UInt8](FileManager.default.contents(atPath: root.appendingPathComponent("Resources/Examples/\(name)").path) ?? Data())
        return name.hasSuffix(".txt") ? TextCoding.bytes(from: TextCoding.string(from: d)) : d
    }

    begin("CT1-Tutorials: Beispieldateien wie in CT1")
    check(example("CrypTool-de.txt").count == 1517, "CrypTool-de.txt hat CT1s 1517 Bytes (Windows-1252)")
    check(example("Startbeispiel-de.txt").count == 1892, "Startbeispiel-de.txt hat 1892 Bytes")
    check(example("CrypTool.bmp").count == 158166, "CrypTool.bmp vorhanden")
    check(TextCoding.bytes(from: "Schlüssel für das Vernam Verschlüsselungsverfahren.") ==   // the help's hex has a blank, its text a hyphen
          h("53 63 68 6C FC 73 73 65 6C 20 66 FC 72 20 64 61 73 20 56 65 72 6E 61 6D 20 56 65 72 73 63 68 6C FC 73 73 65 6C 75 6E 67 73 76 65 72 66 61 68 72 65 6E 2E"),
          "Szenario Vernam: getippter Schlüsseltext = Hex-Schlüssel der Hilfe")

    begin("CT1-Szenario Triple DES (CBC): CrypTool-de.txt, Schlüssel 12 34 AB CD 00 …")
    do {
        let plain = example("CrypTool-de.txt")
        let key = h("12 34 AB CD 00 00 00 00 00 00 00 00 00 00 00 00")
        let c = try SymmetricCipher.encrypt(.tripleDESCBC, key: key, data: plain)
        check(c.count == 1520, "PKCS#7 → 1520 Bytes (got \(c.count))")
        checkEq(try SymmetricCipher.decrypt(.tripleDESCBC, key: key, data: c), plain, "3DES-CBC Entschlüsselung")
        let r = try SymmetricBruteForce.run(.tripleDESCBC, ciphertext: c, keyPattern: "****ABCD000000000000000000000000",
                                            cancel: CancellationToken(), progress: nil)
        check(r.first?.key == key, "Brute-Force ** ** AB CD 00 … findet den Schlüssel (got \(r.first?.keyHex ?? "-"))")
    } catch { check(false, "3DES-Szenario: \(error)") }

    begin("CT1-Präsentation (5): schwache DES-Schlüssel, DES (ECB) mit Null-Padding")
    do {
        let weak = h("01 01 01 01 01 01 01 01")
        let p = Array("DES weak key demo".utf8)
        let c1 = try SymmetricCipher.encrypt(.desECB, key: weak, data: p)
        checkEq(c1, h("0B 76 4F 0A 1A 2E 70 A8 2D 3B A3 4B F0 76 6E 2B E0 2B A4 26 58 2B 63 31"), "DES (ECB) wie Folie 64")
        let c2 = try SymmetricCipher.encrypt(.desECB, key: weak, data: c1)
        checkEq(c2, p + [UInt8](repeating: 0, count: 7), "2× verschlüsseln ergibt wieder den Klartext (+ Null-Padding)")
    } catch { check(false, "schwache DES-Schlüssel: \(error)") }

    begin("CT1-Hilfe DES (CBC): X.923-Padding, Null-Schlüssel, „CRYPTOOL“")
    do {
        let c = try SymmetricCipher.encrypt(.desCBC, key: [UInt8](repeating: 0, count: 8), data: Array("CRYPTOOL".utf8))
        checkEq(c, h("8C 55 5A 6B A0 F2 9B B5 43 52 59 50 54 4F 4F 4C"), "DES (CBC) wie Screenshot der Hilfe")
        for n in [0, 1, 7, 8, 9, 16, 17] {
            let d = (0..<n).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 1) }
            let k = h("13 34 57 79 9B BC DF F1")
            let e = try SymmetricCipher.encrypt(.desCBC, key: k, data: d)
            check(e.count == (n / 8 + 1) * 8, "DES (CBC) Länge \(n) → \(e.count)")
            checkEq(try SymmetricCipher.decrypt(.desCBC, key: k, data: e), d, "DES (CBC) Rundreise \(n)")
            let z = try SymmetricCipher.encrypt(.tripleDESECB, key: k + k.reversed(), data: d)
            check(z.count == (n + 7) / 8 * 8, "3DES (ECB) Null-Padding Länge \(n) → \(z.count)")
        }
    } catch { check(false, "DES (CBC): \(error)") }

    begin("CT1-Präsentation (23): Brute-Force-Tabelle DES (ECB), 8 ASCII-Zeichen")
    for (pattern, cipher) in [("68ac78dd40bbefd*", "66b9354452d29eb5"), ("0123456789ab****", "1f0dd05d8ed51583"),
                              ("000000000000****", "0ed33fed7f46c585")] {
        do {
            let printable = (0..<256).map { $0 >= 0x20 && $0 < 0x7F }
            let r = try SymmetricBruteForce.run(.desECB, ciphertext: h(cipher), keyPattern: pattern.uppercased(), maxResults: 10,
                                                windowLength: 8, cancel: CancellationToken(), progress: nil, allowedBytes: printable)
            let ascii = r.filter { $0.plaintextPreview.count == 8 && $0.plaintextPreview.allSatisfy { $0 >= 0x20 && $0 < 0x7F } }
            check(!ascii.isEmpty, "\(pattern): ein Schlüssel liefert 8 ASCII-Zeichen")
            print("    \(pattern) → " + ascii.map { "\($0.keyHex): \(String(decoding: $0.plaintextPreview, as: UTF8.self))" }.joined(separator: ", "))
        } catch { check(false, "Brute-Force \(pattern): \(error)") }
    }

    begin("CT1-Komprimieren (Zip): „CTZ“ + Deflate, Kompressionsgrad")
    do {
        let plain = example("CrypTool-de.txt")
        let z = try CT1Zip.compress(plain)
        check(z.count == 731 && z.starts(with: Array("CTZ".utf8)), "CrypTool-de.txt → 731 Bytes wie CT1 (got \(z.count))")
        check(CT1Zip.compressionMessage(original: plain.count, compressed: z.count) == "Kompressionsgrad: 51 %.", "Meldung")
        checkEq(try CT1Zip.decompress(z), plain, "UnZip")
        check(try CT1Zip.compress([]) == Array("CTZ".utf8), "leeres Dokument")
        checkThrows("UnZip ohne Magic-Number") { _ = try CT1Zip.decompress([1, 2, 3, 4]) }
        let psion = example("psion-de-enc.hex")
        let zp = try CT1Zip.compress(psion)
        checkEq(try CT1Zip.decompress(zp), psion, "UnZip psion")
        print("    psion-de-enc.hex: \(CT1Zip.compressionMessage(original: psion.count, compressed: zp.count)) (CT1: 21 %)")
    } catch { check(false, "Zip: \(error)") }
}
