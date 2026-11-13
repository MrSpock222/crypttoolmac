import Foundation
import CTCommon
import CTAnalysis

/// CT1 parity checks (ClassicFlow) – called from main.swift.
func runCT1ClassicFlowTests() {
    section("CT1 ClassicFlow")
    typealias A = CT1AutoAnalysis

    func example(_ name: String) -> String {
        (try? String(contentsOf: repoRoot.appendingPathComponent("Resources/Examples/\(name)"), encoding: .utf8)) ?? ""
    }
    let start = example("Startbeispiel-de.txt")
    let cryptool = example("CrypTool-de.txt")
    check(!start.isEmpty && !cryptool.isEmpty, "example files readable")
    let refCounts = A.counts(opts.indices(of: german), symbolCount: 26)

    // --- Caesar: correlation peak against the reference file (reference + 1) ---
    for shift in [1, 4, 13, 26] {          // key offset 1: key letter index = shift − 1
        let c = opts.mapLetters(start) { i, _ in i + shift }
        let k = A.caesarKeyIndex(textCounts: A.counts(opts.indices(of: c), symbolCount: 26), referenceCounts: refCounts)
        check(k == (shift - 1 + 26) % 26, "Caesar Startbeispiel shift \(shift) → key index \(k)")
    }
    // the correlation has 26 values and its peak is the proposed key letter
    let corr = A.caesarCorrelation(textCounts: A.counts(opts.indices(of: opts.mapLetters(cryptool) { i, _ in i + 1 }), symbolCount: 26),
                                   referenceCounts: refCounts)
    check(corr.count == 26 && A.findPeak(corr) == 0, "Caesar CrypTool-de key A (offset 1) – CT1 scenario")
    approx(corr.reduce(0, +), 1.0, 1e-9, "Σ correlation = Σd·Σt = 1")
    check(A.findPeak([1, 3, 3, 2]) == 1, "FindPeak: first maximum")
    check(A.caesarKeyOffsetRemark(derivedKey: "A", alphabet: az) ==
          "Because of the key offset which was used during encryption, there are two keys possible: For a key offset of 1 the key is 'A', for a key offset of 0 the key is 'B'.",
          "Caesar key offset remark")
    check(A.caesarKeyOffsetRemark(derivedKey: "Z", alphabet: az).hasSuffix("of 0 the key is 'A'."), "remark wraps Z → A")
    check(A.resultTitle(.caesar, document: "Startbeispiel-de.txt", key: "D") ==
          "Automatic Caesar Analysis of <Startbeispiel-de.txt>, key: <Key: <D>>", "Caesar result title")

    // --- Vigenère: CT1 scenario CrypTool-de.txt / CRYPTOOL → key length 8, key CRYPTOOL ---
    let keyIdx = opts.indices(of: "CRYPTOOL")
    let vCipher = opts.mapLetters(cryptool) { i, p in i + keyIdx[p % keyIdx.count] }
    let vSeq = opts.indices(of: vCipher)
    if let c = A.autocorrelation(vSeq) {
        check(c.count == 200 && c[0] == vSeq.count, "autocorrelation size min(N, 200), c[0] = N")
        let p = A.keyLength(autocorrelation: c)
        check(p == 8, "Vigenère key length 8 (got \(p))")
        let key = opts.string(from: A.vigenereKey(vSeq, period: p, referenceCounts: refCounts))
        check(key == "CRYPTOOL", "Vigenère key CRYPTOOL (got \(key))")
        // doubled period: CT1 finds the iterated key and reduces it
        let k16 = A.vigenereKey(vSeq, period: 16, referenceCounts: refCounts)
        check(A.reducedKey(k16).map { opts.string(from: $0) } == "CRYPTOOL", "period 16 → iterated key reduced to CRYPTOOL")
    } else { check(false, "autocorrelation not computed") }
    check(A.resultTitle(.vigenere, document: "x", key: "AB") == "Automatic Vigenère Analysis of <x>, key: <AB>", "Vigenère title")
    check(A.repeatedKeyMessage("AB") == "The key shows recurring elements and will be replaced by the equivalent key <AB>!", "repeated key message")

    // --- key length rule details ---
    check(A.keyLength(autocorrelation: [10, 0, 0, 0]) == 4, "no shift above threshold → size")
    // av = ⌊(1+5+1+5)/5⌋ = 2, mx = 5, s = 3 → first c[p] > 3 is p = 2
    check(A.keyLength(autocorrelation: [9, 1, 5, 1, 5]) == 2, "threshold (av + mx)/2, av divided by full size")
    // av = ⌊(4+0+4)/4⌋ = 2 (divided by 4, not 3), s = 3 → p = 1
    check(A.keyLength(autocorrelation: [9, 4, 0, 4]) == 1, "GetAverage(1) divides by size")
    check(A.autocorrelation([1, 2, 1, 2, 1]) == [5, 0, 3, 0, 1], "autocorrelation counts")

    // --- iterated keys ---
    check(A.reducedKey(Array("ABAB")) == Array("AB"), "ABAB → AB")
    check(A.reducedKey(Array("AAAA")) == Array("A"), "AAAA → A")
    check(A.reducedKey(Array("ABCABC")) == Array("ABC"), "ABCABC → ABC")
    check(A.reducedKey(Array("ABCABD")) == nil, "ABCABD unchanged")
    check(A.reducedKey(Array("ABA")) == nil, "ABA unchanged (3 not divisible by 2)")
    check(A.reducedKey([0x1A, 0x2B, 0x1A, 0x2B] as [UInt8]) == [0x1A, 0x2B], "byte key reduced")

    // --- XOR / ADD (CT1 scenarios) ---
    let plain = Array(cryptool.utf8)
    let addKey: [UInt8] = [0x12, 0x34, 0xAB, 0xCD]
    let addCipher = plain.enumerated().map { $0.element &+ addKey[$0.offset % 4] }
    if let c = A.autocorrelation(bytes: addCipher) {
        let p = A.keyLength(autocorrelation: c)
        check(p == 4, "ADD key length 4 (got \(p))")
        // CT1 rule: key byte j is right iff the most frequent byte of plaintext column j is the expected one
        for e: UInt8 in [0x20, 0x65] {
            let k = A.byteKey(addCipher, period: p, expected: e, xor: false)
            for j in 0..<4 {
                let pm = A.mostFrequentByte(A.byteColumnCounts(plain, period: 4, column: j))
                check((k[j] == addKey[j]) == (pm == Int(e)), "ADD column \(j) expected \(String(format: "%02X", e)) (got \(A.hexKeyString(k)))")
            }
        }
        // a plaintext whose most frequent byte is the space in every column
        let spaced = Array((cryptool + String(repeating: " ", count: plain.count / 4)).utf8)
        let sc = spaced.enumerated().map { $0.element &+ addKey[$0.offset % 4] }
        check(A.byteKey(sc, period: 4, expected: 0x20, xor: false) == addKey, "ADD key 12 34 AB CD recovered")
    } else { check(false, "autocorrelation (bytes) not computed") }
    let xorKey: [UInt8] = [0x12, 0x34, 0x56, 0x78]
    let xorCipher = plain.enumerated().map { $0.element ^ xorKey[$0.offset % 4] }
    if let c = A.autocorrelation(bytes: xorCipher) {
        let p = A.keyLength(autocorrelation: c)
        check(p == 4, "XOR key length 4 (got \(p))")
        let k = A.byteKey(xorCipher, period: p, expected: 0x20, xor: true)
        for j in 0..<4 {
            let pm = A.mostFrequentByte(A.byteColumnCounts(plain, period: 4, column: j))
            check((k[j] == xorKey[j]) == (pm == 0x20), "XOR column \(j) (got \(A.hexKeyString(k)))")
        }
    }
    var counts = [Int](repeating: 0, count: 256)
    counts[0x20] = 7; counts[0x65] = 7; counts[0x41] = 3
    check(A.mostFrequentByte(counts) == 0x65, "tie → largest byte value (CT1 scans 255 … 0)")
    check(A.mostFrequentByte([Int](repeating: 0, count: 256), previous: 0x42) == 0x42, "empty column keeps previous value")
    check(A.byteKey([0x00, 0x10, 0x00, 0x10], period: 2, expected: 0x01, xor: false) == [0xFF, 0x0F], "ADD key = c − e mod 256")
    check(A.hexKeyString([0x1A, 0x02, 0xFF]) == "1A 02 FF", "hex key format")
    check(A.resultTitle(.xor, document: "d", key: "1A 2B") == "Automatic XOR Analysis of <d>, key: <1A 2B>", "XOR title")
    check(A.resultTitle(.addition, document: "d", key: "1A") == "Automatic Addition Analysis of <d>, key: <1A>", "ADD title")

    // --- CT1 MakeNewName2 truncation (256-byte buffer, key is cut) ---
    let longKey = String(repeating: "K", count: 300)
    let t = A.resultTitle(.vigenere, document: "doc", key: longKey)
    let fmtLen = "Automatic Vigenère Analysis of <%s>, key: <%s>".count
    check(t.hasSuffix("...>") && t.count == fmtLen - 4 + 3 + (256 - (fmtLen + 3 + 4)) + 3, "long key truncated like CT1 (\(t.count))")
    check(A.inputTooShortMessage(8).hasPrefix("The input must contain at least 8 (not necessarily different) character(s)"), "too short message")
}
