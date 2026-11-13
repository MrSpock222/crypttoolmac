import Foundation
import CTCommon
import CTAnalysis

/// Deterministic xorshift64* byte stream for reproducible "random" data.
private func pseudoRandomBytes(_ n: Int, seed: UInt64) -> [UInt8] {
    var x = seed
    var out: [UInt8] = []
    out.reserveCapacity(n)
    while out.count < n {
        x ^= x >> 12; x ^= x << 25; x ^= x >> 27
        let v = x &* 2685821657736338717
        for k in 0..<8 where out.count < n { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(k)))) }
    }
    return out
}

/// CT1 parity checks (entropy/n-gram/periodicity, random tests, FIPS, 3D) – called from main.swift.
func runCT1AnalysisToolsTests() {
    section("CT1 Analyse-Werkzeuge: Zahlenformat")
    check(CT1Format.double(4.6999, decimals: 2) == "4.69", "double_fmt truncates: \(CT1Format.double(4.6999, decimals: 2))")
    check(CT1Format.double(7, decimals: 2) == "7.00", "double_fmt 7.00")
    check(CT1Format.double(1234.5, decimals: 1) == "1,234.5", "thousands separator")
    check(CT1Format.integer(1048575) == "1,048,575", "itoa_fmt")
    check(CT1Format.cDouble(3.841) == "3.841000", "%lf")

    section("CT1 Zufallstests: Quantile und Statistiken")
    check(CT1RandomTests.quantile(alpha: "0.05", index: 1) == 3.841, "χ²(1) 0.05")
    check(CT1RandomTests.Kind.poker(tupel: 4).quantileIndex == 11 && CT1RandomTests.quantile(alpha: "0.05", index: 11) == 25.0, "poker m=4 → χ²(15)")
    check(CT1RandomTests.Kind.poker(tupel: 3).quantileIndex == 7, "poker m=3 → 7 df")
    check(CT1RandomTests.Kind.runs(runLength: 3).quantileIndex == 3 && CT1RandomTests.quantile(alpha: "0.05", index: 3) == 7.815, "runs: CT1 uses df = run length")
    check(CT1RandomTests.quantile(alpha: "0.10", index: 15) == 0, "outside table → 0")
    let f = CT1RandomTests.frequencyStatistic([0xFF, 0x00, 0x0F], offset: 0, length: 3)
    check(f.ones == 12 && f.zeros == 12 && f.statistic == 0, "frequency counts")
    approx(CT1RandomTests.serialStatistic([0x01], offset: 0, length: 1), 4.0 * 37 / 7 - 12.5 + 1, 1e-9, "serial: CT1 bit order quirk")
    approx(CT1RandomTests.pokerStatistic([0x00, 0xFF], offset: 0, length: 2, tupel: 4), 28, 1e-9, "poker 0000 0000 1111 1111")
    check(CT1RandomTests.runCount([0x0F, 0xF0], offset: 0, count: 2, length: 8, ones: true) == 1, "run of 8 ones across bytes")
    check(CT1RandomTests.runCount([0x0F, 0xF0], offset: 0, count: 2, length: 4, ones: false) == 2, "two zero runs of 4")
    check(CT1RandomTests.longestRun([0xFF, 0xFF, 0x00, 0x00]) == 16, "longest run (last byte not evaluated)")
    check(CT1RandomTests.longestRun([0x0F, 0xF0, 0x00, 0x00]) == 4, "CT1 long-run byte-boundary quirk")
    check(CT1RandomTests.longestRunCorrect([0x0F, 0xF0, 0x00, 0x00]) == 20, "true longest run")
    check(CT1RandomTests.longestRunCorrect([0x0F, 0xF0, 0x00, 0x00], offset: 0, count: 2) == 8, "longest run in range")
    let lr = CT1RandomTests.longRunTest([UInt8](repeating: 0, count: 100))
    check(!lr.passed && lr.longest >= 34 && lr.info.hasPrefix("Maximal test value: 34\nLongest Run: "), "long-run test on zeros: \(lr.info)")

    section("CT1 Zufallstests: Dialoglogik")
    let rnd = pseudoRandomBytes(20_000, seed: 0x1234_5678_9ABC_DEF1)
    let zeros = [UInt8](repeating: 0, count: 2000)
    for kind in [CT1RandomTests.Kind.frequency, .serial, .poker(tupel: 3), .runs(runLength: 3)] {
        let good = CT1RandomTests.run(kind, data: rnd, alpha: "0.01")
        check(good?.passed == true && good?.blocks == 1, "\(kind.name) passes on pseudo random data: \(good?.info ?? "nil")")
        let bad = CT1RandomTests.run(kind, data: zeros, alpha: "0.05")
        check(bad?.passed == false, "\(kind.name) fails on zeros")
        check(bad?.verdict(kind.name) == "\(kind.name) failed!", "verdict text")
        var g = SystemRandomNumberGenerator()
        let blocks = CT1RandomTests.run(kind, data: rnd, alpha: "0.01", useDefaults: true, offset: 0, length: rnd.count, randomBlocks: true, using: &g)
        check(blocks != nil && blocks!.blocks >= 1 && blocks!.blocks <= 10, "random blocks run")
    }
    check(CT1RandomTests.run(.frequency, data: rnd, alpha: "0.05", useDefaults: false, offset: 19_000, length: 2000) == nil, "offset + length > file → nil")
    check(CT1RandomTests.run(.frequency, data: rnd, alpha: "0.05", useDefaults: false, offset: 100, length: 1000)?.blocks == 1, "explicit range")
    let part = CT1RandomTests.frequencyStatistic(rnd, offset: 100, length: 1000).statistic
    check(CT1RandomTests.run(.frequency, data: rnd, alpha: "0.05", useDefaults: false, offset: 100, length: 1000)?.statistic == part, "range statistic")

    section("CT1 FIPS-PUB-140-1")
    check(CT1RandomTests.fips140_1([UInt8](repeating: 0, count: 2499)) == nil, "needs 2500 bytes")
    if let r = CT1RandomTests.fips140_1(rnd) {
        check(r.batteryPassed, "battery passes on pseudo random data: ones \(r.monobitOnes) poker \(r.pokerStatistic) runs \(r.runBlocks)/\(r.runGaps) longest \(r.longestRun)")
        check(r.batteryLine == "Test battery passed!" && r.monobitLine == "Mono-Bit Test passed!", "FIPS texts")
        check(r.entropyLine.hasPrefix("Entropy: 7.9") && r.entropyLine.hasSuffix(" bit/character"), r.entropyLine)
    } else { check(false, "FIPS nil") }
    if let z = CT1RandomTests.fips140_1(zeros + zeros) {
        check(!z.batteryPassed && !z.monobitPassed && !z.longRunPassed && z.pokerLine == "Poker Test failed!", "FIPS fails on zeros")
    }

    section("CT1 N-Gramm-Liste")
    let ng = CT1NGram.text("abab AB-ab", n: 2, options: TextOptions.default)
    check(ng.total == 5 && ng.individuals == 2, "text digrams (non-alphabet characters interrupt): total \(ng.total)")
    check(ng.entries.first.map { ng.label($0) } == "AB" && ng.entries.first?.count == 4, "AB most frequent")
    let tie = CT1NGram.text("ZZYY", n: 1, options: TextOptions.default)
    check(tie.entries.map { tie.label($0) } == ["Y", "Z"], "ties sorted by symbol (memcmp)")
    let bin = CT1NGram.binary([0x41, 0x42, 0x41, 0x42], n: 2)
    check(bin.entries.first.map { bin.label($0) } == "41, 42" && bin.entries.first?.count == 2, "binary label")
    let doc = CT1NGram.listDocument(ng, rows: 2, method: CT1NGram.method(n: 2, freeN: false), title: "x.txt", fileSize: 10)
    let lines = doc.components(separatedBy: "\n")
    check(lines[0] == "Digram Analysis of <x.txt>. File size 10 bytes." && lines[1] == "Descending sorted on frequency.", "list header")
    check(lines[3] == "  No.\t  Substring\tFrequency (in %)\tFrequency", "column header: \(lines[3])")
    check(lines[4] == "    1\t         AB\t        80.0000\t      \t4", "row format: \(lines[4])")
    check(CT1NGram.method(n: 4, freeN: true) == "4 Gram" && CT1NGram.method(n: 3, freeN: true) == "3 Gram", "free N method")

    section("CT1 Periode")
    let pdata = Array("XYZABCABCABC".utf8)
    let per = Statistics.periodicity(pdata)
    check(per.first.map { $0.offset + 1 == 4 && $0.length == 3 && $0.repetitions == 3 } == true, "period ABC from offset 4 (CT1 offset+1): \(per)")
    if let p = per.first {
        check(CT1Periodicity.text(p) == "ABC" && CT1Periodicity.hex(p) == " 41 42 43", "content columns")
        let list = CT1Periodicity.listDocument(per, title: "p.txt").components(separatedBy: "\n")
        check(list[0] == "Periodicity analysis of p.txt:" && list[1] == "No.\tOffset\tLength\tNumber of cycles\tCycle content", "list header")
        check(list[2] == "1\t4\t3\t3\t\tABC\t 41 42 43", "list row: \(list[2].debugDescription)")
    }

    section("CT1 3D-Volumen")
    let vol = CT1Volume.volume([1, 2, 3, 4, 5, 6, 7], resolution: 64, density: 127, shiftPercent: 50, wordLength: 1)
    check(vol.count == 64 * 64 * 64 && vol.filter { $0 != 0 }.count == 1 && vol.max() == 254, "6 equal differences → one voxel hit twice")
    let wrap = CT1Volume.volume([UInt8](repeating: 9, count: 16), resolution: 64, density: 200, shiftPercent: 50, wordLength: 4)
    check(wrap.contains(200), "4-byte words, density 200")
    let v3 = CT1Volume.volume([UInt8](repeating: 0, count: 31), resolution: 64, density: 127, shiftPercent: 50, wordLength: 1)
    check(v3.firstIndex(of: 246) == 32 + 32 * 64 + 32 * 64 * 64, "density wraps modulo 256 (10 hits · 127 = 1270 ≡ 246)")
}
