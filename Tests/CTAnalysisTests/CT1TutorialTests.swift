import Foundation
import CTCommon
import CTAnalysis

/// Steps of CT1's tutorials (online help "Szenarien", CrypTool1-Presentation-de.pdf) with
/// concrete results – called from main.swift.
func runCT1TutorialTests() {
    section("CT1 Tutorials (Szenarien / Präsentation)")
    typealias A = CT1AutoAnalysis
    /// Example file as the app loads it (text examples as CT1's Windows-1252 bytes).
    func example(_ name: String) -> [UInt8] {
        let d = [UInt8](FileManager.default.contents(atPath: repoRoot.appendingPathComponent("Resources/Examples/\(name)").path) ?? Data())
        return name.hasSuffix(".txt") ? TextCoding.bytes(from: TextCoding.string(from: d)) : d
    }
    func analyze(_ c: [UInt8], expected: UInt8, xor: Bool) -> (period: Int, key: [UInt8])? {
        guard let ac = A.autocorrelation(bytes: c) else { return nil }
        let p = A.keyLength(autocorrelation: ac)
        return (p, A.byteKey(c, period: p, expected: expected, xor: xor))
    }
    let refCounts = A.counts(opts.indices(of: german), symbolCount: 26)

    // Szenario Addition: CrypTool-de.txt, Schlüssel 12 34 AB CD, häufigstes Zeichen 'e' = 65
    let cryptool = example("CrypTool-de.txt")
    let addKey: [UInt8] = [0x12, 0x34, 0xAB, 0xCD]
    let add = cryptool.enumerated().map { $0.element &+ addKey[$0.offset % 4] }
    if let r = analyze(add, expected: 0x65, xor: false) {
        check(r.period == 4 && r.key == addKey, "Szenario ADD: Länge 4, Schlüssel 12 34 AB CD (got \(r.period), \(A.hexKeyString(r.key)))")
    } else { check(false, "Szenario ADD: keine Autokorrelation") }

    // Szenario XOR: CrypTool.bmp, häufigstes Byte FF, Schlüssel 12 34 56 78
    let bmp = example("CrypTool.bmp")
    var hist = [Int](repeating: 0, count: 256)
    for b in bmp { hist[Int(b)] += 1 }
    check(hist.firstIndex(of: hist.max() ?? 0) == 255, "Szenario XOR: häufigstes Byte von CrypTool.bmp ist 255")
    let xorKey: [UInt8] = [0x12, 0x34, 0x56, 0x78]
    let xorCipher = bmp.enumerated().map { $0.element ^ xorKey[$0.offset % 4] }
    if let r = analyze(xorCipher, expected: 0xFF, xor: true) {
        check(r.period == 4 && r.key == xorKey, "Szenario XOR: Länge 4, Schlüssel 12 34 56 78 (got \(r.period), \(A.hexKeyString(r.key)))")
    } else { check(false, "Szenario XOR: keine Autokorrelation") }

    // Präsentation (4): PSION 5, binäre Addition, Länge 32, 'e' = 65 (Folie 62)
    let psion = example("psion-de-enc.hex")
    if let r = analyze(psion, expected: 0x65, xor: false) {
        check(r.period == 32, "PSION: Schlüssellänge 32 (got \(r.period))")
        check(A.hexKeyString(Array(r.key.prefix(11))) == "12 86 5B EF 14 98 87 2C 39 3E 43", "PSION: Schlüssel wie Folie 62 (got \(A.hexKeyString(r.key)))")
        let plain = psion.prefix(16).enumerated().map { $0.element &- r.key[$0.offset % r.key.count] }
        check(A.hexKeyString(plain) == "65 72 67 AA 73 65 74 7A 20 28 55 53 74 47 29 06", "PSION: Klartextanfang wie Folie 62")
    } else { check(false, "PSION: keine Autokorrelation") }

    // Präsentation (1): Vigenère-Analyse von Startbeispiel-de.txt mit TEST und TESTETE (Folie 33).
    // The slide shows length 4 for TEST; CT1 1.4.x's rule (ported 1:1, c[4] = 110 < s = 116) yields
    // 8 and reduces TESTTEST to TEST – the found key is the same.
    let start = TextCoding.string(from: example("Startbeispiel-de.txt"))
    for (key, period) in [("TEST", 8), ("TESTETE", 14)] {
        let k = opts.indices(of: key)
        let seq = opts.indices(of: opts.mapLetters(start) { i, p in i + k[p % k.count] })
        guard let ac = A.autocorrelation(seq) else { check(false, "Vigenère \(key): keine Autokorrelation"); continue }
        let p = A.keyLength(autocorrelation: ac)
        check(p == period, "Folie 33: \(key) → Schlüssellänge \(period) (got \(p))")
        let found = A.vigenereKey(seq, period: p, referenceCounts: refCounts)
        let reduced = A.reducedKey(found) ?? found
        check(opts.string(from: reduced) == key, "Folie 33: ermittelter Schlüssel \(key) (got \(opts.string(from: found)))")
    }

    // Präsentation (22): Passwort-Qualitätsmesser (Folie 95)
    let q1 = PasswordTools.ct1Quality(of: "1234")
    check([q1.keePassText, q1.mozillaText, q1.pgpText, q1.crypToolText] == ["10 % (12 Bits)", "50 %", "9 % (11 Bits)", "6 % (7 Bits)"],
          "PQM 1234 wie Folie 95 (got \(q1.keePassText), \(q1.mozillaText), \(q1.pgpText), \(q1.crypToolText))")
    // CT1's CrypTool measure shows 77 % (98 Bits): it finds "bTR" and "Rds" in the cracklib dictionary
    // (1.65 million words, setup/template/words) – the port's built-in word list is much smaller.
    let q2 = PasswordTools.ct1Quality(of: "X40bTRds&11w_dks")
    check([q2.keePassText, q2.mozillaText, q2.pgpText] == ["82 % (104 Bits)", "100 %", "63 % (80 Bits)"],
          "PQM X40bTRds&11w_dks wie Folie 95 (got \(q2.keePassText), \(q2.mozillaText), \(q2.pgpText))")
}
