import Dispatch
import Foundation
import CTCommon

/// A key candidate of the brute-force analysis.
public struct BruteForceResult: Sendable {
    /// The full key.
    public let key: [UInt8]
    /// Shannon entropy (bits per byte) of the decrypted prefix – the lower, the more plausible.
    public let entropy: Double
    /// The decrypted prefix (without padding removal).
    public let plaintextPreview: [UInt8]

    public init(key: [UInt8], entropy: Double, plaintextPreview: [UInt8]) {
        self.key = key
        self.entropy = entropy
        self.plaintextPreview = plaintextPreview
    }

    /// Key as hex string with spaces ("00 11 22 …").
    public var keyHex: String { Hex.encode(key) }
}

/// Brute-force analysis of modern symmetric ciphers (CT1: "Analyse ▸ Symmetrische
/// Verschlüsselung (modern)"). Unknown hex digits of the key are marked with '*'; each key is used
/// to decrypt the first bytes of the ciphertext, candidates are ranked by the entropy of the result.
///
/// As in CT1 the parity bits of DES-based keys (least significant bit of every key byte; for
/// DESX/DESXL only in the first 64 bits) are not enumerated – a '*' in a low nibble then runs
/// through 8 instead of 16 values.
public enum SymmetricBruteForce {

    /// Default number of ciphertext bytes that are decrypted per key (CT1 "Entropiefenster").
    public static let defaultWindowLength = 128

    /// Number of keys described by `pattern` (16 per '*'), ignoring parity bits.
    public static func keyspaceSize(pattern: String) -> Double {
        pow(16, Double(pattern.filter { $0 == "*" || $0 == "?" }.count))
    }

    /// Number of keys that `run` actually tests for `algorithm` (parity bits of DES keys skipped).
    public static func keyspaceSize(pattern: String, algorithm: SymmetricAlgorithm) -> Double {
        guard let p = try? Pattern(pattern, algorithm) else { return keyspaceSize(pattern: pattern) }
        return p.radices.reduce(1.0) { $0 * Double($1) }
    }

    /// Searches the keys described by `keyPattern`.
    /// - Parameters:
    ///   - keyPattern: hex digits, '*' (or '?') for unknown nibbles; spaces are ignored. Its length
    ///     must correspond to a key length valid for `alg`.
    ///   - maxResults: number of best candidates returned (ascending entropy).
    ///   - cancel: checked frequently; on cancellation the best candidates found so far are returned.
    ///   - progress: 0…1, called from worker threads (throttled).
    public static func run(_ alg: SymmetricAlgorithm, ciphertext: [UInt8], keyPattern: String, maxResults: Int = 10,
                           cancel: CancellationToken, progress: ProgressHandler?) throws -> [BruteForceResult] {
        try run(alg, ciphertext: ciphertext, keyPattern: keyPattern, maxResults: maxResults,
                windowLength: defaultWindowLength, cancel: cancel, progress: progress)
    }

    /// As `run(_:ciphertext:keyPattern:maxResults:cancel:progress:)` with a configurable number of
    /// ciphertext bytes (`windowLength`) that are decrypted and evaluated per key.
    ///
    /// `allowedBytes` (256 entries, optional) is CT1's analysis option "Zeichensatz für den zu
    /// erwartenden Klartext": candidates whose decrypted prefix contains a byte that is not allowed
    /// are skipped before the entropy test (Cryptography.cpp SymmetricBruteForce).
    public static func run(_ alg: SymmetricAlgorithm, ciphertext: [UInt8], keyPattern: String, maxResults: Int = 10,
                           windowLength: Int, cancel: CancellationToken, progress: ProgressHandler?,
                           allowedBytes: [Bool]? = nil) throws -> [BruteForceResult] {
        let allowed: [Bool]? = allowedBytes.map { $0.count == 256 ? $0 : Array(($0 + [Bool](repeating: true, count: 256)).prefix(256)) }
        let pattern = try Pattern(keyPattern, alg)
        let total = pattern.radices.reduce(1.0) { $0 * Double($1) }
        guard total <= Double(1 << 62) else {
            throw CTError("The key space (\(String(format: "%.3g", total)) keys) is too large for an exhaustive search.")
        }
        let keyCount = pattern.radices.reduce(UInt64(1)) { $0 * UInt64($1) }

        // ciphertext prefix (block aligned)
        let unit = alg == .rc4 ? 1 : alg.paddingUnit
        guard ciphertext.count >= unit, !ciphertext.isEmpty else {
            throw CTError("The ciphertext is too short (at least \(unit) bytes for \(alg.displayName)).")
        }
        let window = max(windowLength, unit)
        let prefixLength = min(ciphertext.count, window) / unit * unit
        let prefix = Array(ciphertext.prefix(prefixLength))
        let keep = max(1, maxResults)

        // entropy helper: H = log2(n) - (1/n) Σ c·log2(c)
        let n = prefixLength
        let clog: [Double] = (0...n).map { $0 == 0 ? 0 : Double($0) * log2(Double($0)) }
        let log2n = log2(Double(n))

        // A few large chunks per core (cancellation and progress are handled inside a chunk).
        let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let targetChunks = UInt64(cores * 8)
        let chunkSize = max(256, (keyCount + targetChunks - 1) / targetChunks)
        let chunks = Int((keyCount + chunkSize - 1) / chunkSize)
        let reportInterval: UInt64 = 4096

        let lock = NSLock()
        var best: [BruteForceResult] = []
        var doneKeys: UInt64 = 0
        var lastReport: UInt64 = 0
        /// Adds `count` tested keys and calls `progress` at most every 50 ms.
        func reportProgress(_ count: UInt64) {
            lock.lock()
            doneKeys += count
            let now = DispatchTime.now().uptimeNanoseconds
            let report = now &- lastReport > 50_000_000
            if report { lastReport = now }
            let fraction = Double(doneKeys) / Double(keyCount)
            lock.unlock()
            if report { progress?(fraction) }
        }

        DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
            if cancel.isCancelled { return }
            let start = UInt64(chunk) * chunkSize
            let end = min(start + chunkSize, keyCount)
            var local: [BruteForceResult] = []
            var worst = Double.infinity
            var key = pattern.baseKey
            var digits = pattern.digits(for: start)
            for (i, d) in digits.enumerated() { pattern.setNibble(&key, i, d) }
            var out = [UInt8](repeating: 0, count: prefixLength)
            let scratchSize = 8192
            let scratch = UnsafeMutableRawPointer.allocate(byteCount: scratchSize, alignment: 64)
            defer { scratch.deallocate() }
            var counts = [Int](repeating: 0, count: 256)
            var unreported: UInt64 = 0   // keys tested but not yet added to the progress counter
            prefix.withUnsafeBufferPointer { inp in
                out.withUnsafeMutableBufferPointer { outp in
                    counts.withUnsafeMutableBufferPointer { cnt in
                        var index = start
                        while index < end {
                            if unreported == reportInterval {
                                if cancel.isCancelled { break }
                                reportProgress(unreported)
                                unreported = 0
                            }
                            let ok = key.withUnsafeBufferPointer { k in
                                alg == .aes
                                    ? SymmetricCipher.aesDecryptNoAlloc(key: k, input: inp, output: outp,
                                                                        scratch: scratch, scratchSize: scratchSize)
                                    : SymmetricCipher.rawCryptFast(alg, decrypt: true, key: k, input: inp, output: outp)
                            }
                            unreported += 1
                            var accepted = ok
                            if ok, let allowed {
                                for j in 0..<n where !allowed[Int(outp[j])] { accepted = false; break }
                            }
                            if accepted {
                                for j in 0..<256 { cnt[j] = 0 }
                                for j in 0..<n { cnt[Int(outp[j])] += 1 }
                                var s = 0.0
                                for j in 0..<256 where cnt[j] > 0 { s += clog[cnt[j]] }
                                let h = max(0, log2n - s / Double(n))
                                if local.count < keep || h < worst {
                                    local.append(BruteForceResult(key: key, entropy: h, plaintextPreview: Array(outp)))
                                    if local.count > keep {
                                        local.sort { $0.entropy < $1.entropy }
                                        local.removeLast(local.count - keep)
                                    }
                                    worst = local.count < keep ? .infinity : local.map(\.entropy).max()!
                                }
                            }
                            // next key (odometer, last unknown nibble fastest)
                            index += 1
                            if index < end {
                                var pos = digits.count - 1
                                while pos >= 0 {
                                    digits[pos] += 1
                                    if digits[pos] < pattern.radices[pos] {
                                        pattern.setNibble(&key, pos, digits[pos]); break
                                    }
                                    digits[pos] = 0
                                    pattern.setNibble(&key, pos, 0)
                                    pos -= 1
                                }
                            }
                        }
                    }
                }
            }
            lock.lock()
            best += local
            best.sort { $0.entropy < $1.entropy }
            if best.count > keep { best.removeLast(best.count - keep) }
            lock.unlock()
            reportProgress(unreported)
        }
        progress?(cancel.isCancelled ? Double(doneKeys) / Double(keyCount) : 1.0)
        return best.sorted { a, b in
            a.entropy != b.entropy ? a.entropy < b.entropy : a.key.lexicographicallyPrecedes(b.key)
        }
    }

    /// Parsed key pattern.
    struct Pattern {
        /// Key with all unknown nibbles set to 0.
        let baseKey: [UInt8]
        /// Nibble index (0 = high nibble of byte 0) of each unknown position, left to right.
        let positions: [Int]
        /// Number of values per unknown position (16, or 8 for nibbles containing a parity bit).
        let radices: [Int]
        /// Step per value (1, or 2 for parity nibbles: the parity bit stays 0).
        let steps: [UInt8]

        init(_ text: String, _ alg: SymmetricAlgorithm) throws {
            var nibbles: [Int?] = []
            for ch in text.unicodeScalars {
                switch ch {
                case " ", "\t", "\n", "\r": continue
                case "*", "?": nibbles.append(nil)
                default:
                    guard let v = Int(String(ch), radix: 16) else {
                        throw CTError("Invalid character \"\(ch)\" in the key pattern (allowed: 0-9, A-F and *).")
                    }
                    nibbles.append(v)
                }
            }
            guard !nibbles.isEmpty, nibbles.count % 2 == 0 else {
                throw CTError("The key pattern must consist of whole bytes (even number of hex digits).")
            }
            let bytes = nibbles.count / 2
            guard alg.isValidKeyLength(bytes) else {
                throw CTError("The key pattern describes \(bytes * 8) bits; \(alg.displayName) allows \(alg.keySizesText).")
            }
            var key = [UInt8](repeating: 0, count: bytes)
            var positions: [Int] = [], radices: [Int] = [], steps: [UInt8] = []
            for (i, nib) in nibbles.enumerated() {
                if let v = nib {
                    key[i / 2] |= UInt8(v) << (i % 2 == 0 ? 4 : 0)
                } else {
                    let parity = alg.hasDESParity && i % 2 == 1 && ((alg != .desx && alg != .desxl) || i < 16)
                    positions.append(i)
                    radices.append(parity ? 8 : 16)
                    steps.append(parity ? 2 : 1)
                }
            }
            baseKey = key
            self.positions = positions
            self.radices = radices
            self.steps = steps
        }

        /// Mixed-radix digits of key number `index` (last position least significant).
        func digits(for index: UInt64) -> [Int] {
            var d = [Int](repeating: 0, count: radices.count)
            var x = index
            for i in stride(from: radices.count - 1, through: 0, by: -1) {
                d[i] = Int(x % UInt64(radices[i]))
                x /= UInt64(radices[i])
            }
            return d
        }

        @inline(__always)
        func setNibble(_ key: inout [UInt8], _ unknown: Int, _ digit: Int) {
            let nib = positions[unknown]
            let v = UInt8(digit) &* steps[unknown]
            if nib % 2 == 0 {
                key[nib / 2] = (key[nib / 2] & 0x0F) | (v << 4)
            } else {
                key[nib / 2] = (key[nib / 2] & 0xF0) | v
            }
        }
    }
}
