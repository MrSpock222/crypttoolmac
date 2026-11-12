import Foundation
import CTCommon

/// Ciphertext-only analysis of the byte-wise periodic ciphers of CT1
/// ("Byteweise Addition" and "XOR / Vernam"), mimicking CT1's `AddAuto` / `XorAuto`:
///
/// 1. Autocorrelation of the bytes for the shifts 1 … min(N, 200) − 1.
/// 2. Key length = first shift whose coincidence count exceeds (average + maximum) / 2
///    (limited to `maxKeyLength`).
/// 3. Split into `keyLength` columns; key byte = most frequent ciphertext byte of the column
///    combined with the assumed most frequent plaintext byte (XOR: c ⊕ e, addition: c − e mod 256).
///    CT1 asks for that byte in a dialog with the default "00" (binary files); for texts the
///    space (0x20) is the better choice, hence the default here.
/// 4. An iterated key ("ABAB") is reduced to its period ("AB").
public enum ByteKeyAnalysis {

    /// XOR / Vernam analysis. Returns the key length and the key bytes.
    public static func analyzeXOR(_ data: [UInt8], expectedMostFrequent: UInt8 = 0x20, maxKeyLength: Int = 64) -> (keyLength: Int, key: [UInt8]) {
        analyze(data, expectedMostFrequent: expectedMostFrequent, maxKeyLength: maxKeyLength, keyLength: nil) { c, e in c ^ e }
    }

    /// XOR analysis with a given key length (CT1 lets the user edit the proposed length).
    public static func analyzeXOR(_ data: [UInt8], keyLength: Int, expectedMostFrequent: UInt8 = 0x20) -> [UInt8] {
        analyze(data, expectedMostFrequent: expectedMostFrequent, maxKeyLength: keyLength, keyLength: keyLength) { c, e in c ^ e }.key
    }

    /// Byte-wise addition analysis (cipher = plain + key mod 256). Returns key length and key bytes.
    public static func analyzeAddition(_ data: [UInt8], expectedMostFrequent: UInt8 = 0x20, maxKeyLength: Int = 64) -> (keyLength: Int, key: [UInt8]) {
        analyze(data, expectedMostFrequent: expectedMostFrequent, maxKeyLength: maxKeyLength, keyLength: nil) { c, e in c &- e }
    }

    /// Addition analysis with a given key length.
    public static func analyzeAddition(_ data: [UInt8], keyLength: Int, expectedMostFrequent: UInt8 = 0x20) -> [UInt8] {
        analyze(data, expectedMostFrequent: expectedMostFrequent, maxKeyLength: keyLength, keyLength: keyLength) { c, e in c &- e }.key
    }

    /// CT1's key length estimate (see type documentation, step 2). Returns at least 1.
    public static func estimateKeyLength(_ data: [UInt8], maxKeyLength: Int = 64) -> Int {
        let maxShift = min(data.count, max(200, maxKeyLength + 1)) - 1
        guard maxShift >= 1 else { return 1 }
        let p = VigenereAnalysis.ct1Period(data.map { Int($0) }, maxShift: maxShift)
        return max(1, min(p, maxKeyLength, data.count))
    }

    /// Decrypts XOR-encrypted data with a periodic key.
    public static func decryptXOR(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        return data.enumerated().map { $0.element ^ key[$0.offset % key.count] }
    }

    /// Decrypts data encrypted by byte-wise addition with a periodic key.
    public static func decryptAddition(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        return data.enumerated().map { $0.element &- key[$0.offset % key.count] }
    }

    // MARK: Variant with a reference byte distribution (extension, not in CT1)

    /// XOR analysis where every key byte is chosen by maximum likelihood against the byte
    /// distribution of `referenceBytes` (e.g. the UTF-8 bytes of the reference text) instead of
    /// assuming a single most frequent byte. Much more reliable for short columns. Key length as CT1.
    public static func analyzeXOR(_ data: [UInt8], referenceBytes: [UInt8], maxKeyLength: Int = 64) -> (keyLength: Int, key: [UInt8]) {
        let logp = byteLogProbabilities(referenceBytes)
        return analyze(data, maxKeyLength: maxKeyLength, keyLength: nil) { counts in
            bestKeyByte(counts, logp) { c, k in c ^ k }
        }
    }

    /// Addition analysis with a reference byte distribution (see the XOR variant).
    public static func analyzeAddition(_ data: [UInt8], referenceBytes: [UInt8], maxKeyLength: Int = 64) -> (keyLength: Int, key: [UInt8]) {
        let logp = byteLogProbabilities(referenceBytes)
        return analyze(data, maxKeyLength: maxKeyLength, keyLength: nil) { counts in
            bestKeyByte(counts, logp) { c, k in c &- k }
        }
    }

    private static func byteLogProbabilities(_ ref: [UInt8]) -> [Double] {
        let h = Statistics.byteHistogram(ref)
        let total = Double(ref.count) + 2.56
        return h.map { log((Double($0) + 0.01) / total) }
    }

    private static func bestKeyByte(_ counts: [Int], _ logp: [Double], _ decrypt: (UInt8, UInt8) -> UInt8) -> UInt8 {
        let used = (0..<256).filter { counts[$0] > 0 }
        var best = 0
        var bestLL = -Double.infinity
        for k in 0..<256 {
            var ll = 0.0
            for c in used { ll += Double(counts[c]) * logp[Int(decrypt(UInt8(c), UInt8(k)))] }
            if ll > bestLL { bestLL = ll; best = k }
        }
        return UInt8(best)
    }

    // MARK: internals

    private static func analyze(_ data: [UInt8], expectedMostFrequent: UInt8, maxKeyLength: Int, keyLength: Int?,
                                combine: (UInt8, UInt8) -> UInt8) -> (keyLength: Int, key: [UInt8]) {
        analyze(data, maxKeyLength: maxKeyLength, keyLength: keyLength) { counts in
            // CT1 scans 255 … 0 with ">" → the smallest byte value wins ties
            var best = 0
            for j in 1..<256 where counts[j] > counts[best] { best = j }
            return combine(UInt8(best), expectedMostFrequent)
        }
    }

    private static func analyze(_ data: [UInt8], maxKeyLength: Int, keyLength: Int?,
                                column: ([Int]) -> UInt8) -> (keyLength: Int, key: [UInt8]) {
        guard !data.isEmpty else { return (0, []) }
        let L = keyLength.map { max(1, min($0, data.count)) } ?? estimateKeyLength(data, maxKeyLength: max(1, maxKeyLength))
        var key = [UInt8](repeating: 0, count: L)
        for c in 0..<L {
            var counts = [Int](repeating: 0, count: 256)
            var k = c
            while k < data.count { counts[Int(data[k])] += 1; k += L }
            key[c] = column(counts)
        }
        if keyLength == nil {
            // CT1: an iterated key ("ABAB") is reduced to its period
            for p in 1..<L where L % p == 0 {
                if (0..<L).allSatisfy({ key[$0] == key[$0 % p] }) { key = Array(key.prefix(p)); break }
            }
        }
        return (key.count, key)
    }
}
