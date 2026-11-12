import Foundation
import Security
import CTCommon

/// CT1 "Angriff auf den Hashwert der digitalen Signatur" (SignatureAttack.cpp):
/// birthday-paradox search for a harmless and a dangerous message whose hash values agree in
/// the first `significantBits` bits. Both messages are modified by semantically neutral changes
/// (extra blanks or appended characters) that are driven by the current truncated hash value;
/// Floyd's cycle finding detects the collision.
public enum SignatureAttack {
    /// Message modification method (CT1 options "Leerzeichen einfügen" / "Zeichen anhängen").
    public enum Method: Equatable, Sendable {
        /// Insert a blank before line ends and/or double existing blanks.
        case blanks(beforeLineEnd: Bool, doubleBlanks: Bool)
        /// Append characters (printable "ABCD" for demonstration, or non-printable TAB/LF/SPACE/NBSP).
        case attachments(printable: Bool)
    }

    public struct Options: Equatable, Sendable {
        public var hash: HashAlgorithm
        public var significantBits: Int
        public var method: Method
        public init(hash: HashAlgorithm, significantBits: Int, method: Method) {
            self.hash = hash
            self.significantBits = significantBits
            self.method = method
        }
        /// CT1 "Standard wiederherstellen": MD2, 16 bit, blanks before line end + doubling.
        public static let standard = Options(hash: .md2, significantBits: 16, method: .blanks(beforeLineEnd: true, doubleBlanks: true))
        /// The six hash functions offered by CT1's option dialog.
        public static let hashes: [HashAlgorithm] = [.md2, .md4, .md5, .sha0, .sha1, .ripemd160]
    }

    public struct RunStatistics: Sendable {
        public let run: Int
        public let collisionSteps: Int
        public let confirmationSteps: Int
        public let outcome: String
    }

    public struct Result: Sendable {
        public let success: Bool
        public let harmless: [UInt8]
        public let dangerous: [UInt8]
        public let harmlessHash: [UInt8]
        public let dangerousHash: [UInt8]
        public let runs: [RunStatistics]
        public let totalSteps: Int
        public let hashOperations: Int
        public let elapsed: TimeInterval
        public let expectedSteps: Int
        public let expectedSeconds: Double
        public let addedBytesHarmless: Int
        public let addedBytesDangerous: Int
        public let cancelled: Bool
    }

    public static let maxRuns = 10

    /// Expected number of steps: ⌈2^(bits/2) · 2.5⌉ (CT1).
    public static func expectedSteps(bits: Int) -> Int {
        Int((pow(2.0, Double(bits) / 2) * 2.5).rounded(.up))
    }

    /// Number of modifiable positions for the blanks method.
    public static func modifiablePositions(_ message: [UInt8], beforeLineEnd: Bool, doubleBlanks: Bool) -> Int {
        message.reduce(0) { $0 + (((beforeLineEnd && ($1 == 0x0A || $1 == 0x0D)) || (doubleBlanks && $1 == 0x20)) ? 1 : 0) }
    }

    /// Bit i of the value, counted from the most significant bit of byte 0.
    @inline(__always)
    static func bit(_ value: [UInt8], _ i: Int) -> Bool {
        (value[i / 8] >> (7 - UInt8(i % 8))) & 1 == 1
    }

    /// Truncates a hash value to the first `bits` bits (remaining bits of the last byte zeroed).
    public static func truncate(_ hash: [UInt8], bits: Int) -> [UInt8] {
        let n = (bits + 7) / 8
        var t = Array(hash.prefix(n))
        if bits % 8 != 0, !t.isEmpty { t[n - 1] &= UInt8(0xFF << (8 - bits % 8) & 0xFF) }
        return t
    }

    /// Parity of the first `bits` bits.
    public static func parity(_ value: [UInt8], bits: Int) -> Int {
        var p = 0
        for i in 0..<bits where bit(value, i) { p ^= 1 }
        return p
    }

    /// Modifies `message` according to the first `bits` bits of `value` (CT1 ModifiedDocument_*).
    public static func modify(_ message: [UInt8], value: [UInt8], bits: Int, method: Method, run: Int) throws -> [UInt8] {
        switch method {
        case let .blanks(beforeLineEnd, doubleBlanks):
            // collect positions from the end of the message
            var positions: [Int] = []
            var i = message.count - 1
            while i >= 0 && positions.count < bits {
                let b = message[i]
                if (beforeLineEnd && (b == 0x0A || b == 0x0D)) || (doubleBlanks && b == 0x20) {
                    // for CR LF insert before the CR
                    if b == 0x0A && i > 0 && message[i - 1] == 0x0D { i -= 1 }
                    positions.append(i)
                }
                i -= 1
            }
            guard positions.count >= bits else {
                throw CTError("Mindestens eine Nachricht enthält weniger modifizierbare Stellen als signifikante Bits in den Optionen eingestellt wurden.")
            }
            var out = message
            // positions are descending, so inserting keeps the remaining indices valid
            for (k, pos) in positions.enumerated() where bit(value, k) {
                out.insert(0x20, at: pos)
            }
            return out
        case let .attachments(printable):
            let chars: [[UInt8]] = printable ? [[0x41], [0x42], [0x43], [0x44]] : [[0x09], [0x0A], [0x20], [0xC2, 0xA0]]
            var out = message
            out += chars[(run / 4) % 4] + chars[run % 4]
            var bitIndex = 0
            while bitIndex + 1 < bits {
                let v = (bit(value, bitIndex) ? 2 : 0) + (bit(value, bitIndex + 1) ? 1 : 0)
                out += chars[v]
                bitIndex += 2
            }
            if bitIndex < bits { out += chars[bit(value, bitIndex) ? 2 : 0] }
            return out
        }
    }

    /// Runs the attack. `progress` receives values in 0…1 (per run).
    public static func run(harmless: [UInt8], dangerous: [UInt8], options: Options,
                           cancel: CancellationToken? = nil, progress: ProgressHandler? = nil) throws -> Result {
        let bits = options.significantBits
        let hashLen = options.hash.digestLength * 8
        guard bits >= 1, bits <= hashLen else {
            throw CTError("Die signifikante Bitlänge muss zwischen 1 und \(hashLen) liegen.")
        }
        if case let .blanks(le, db) = options.method {
            guard le || db else { throw CTError("Bitte mindestens eine Art der Leerzeichen-Modifikation wählen.") }
            if modifiablePositions(harmless, beforeLineEnd: le, doubleBlanks: db) < bits
                || modifiablePositions(dangerous, beforeLineEnd: le, doubleBlanks: db) < bits {
                throw CTError("Mindestens eine Nachricht enthält weniger modifizierbare Stellen als signifikante Bits in den Optionen eingestellt wurden.")
            }
        }

        let docs = [harmless, dangerous]
        let expected = expectedSteps(bits: bits)
        let cap = expected * max(1, bits)
        var hashOps = 0
        var totalSteps = 0
        var runs: [RunStatistics] = []
        let start = Date()

        // measure hash speed for the time estimate
        let probeStart = Date()
        var probes = 0
        while probes < 50 && Date().timeIntervalSince(probeStart) < 0.05 {
            _ = Hashing.hash(harmless, algorithm: options.hash); probes += 1
        }
        let perSecond = Double(probes) / max(Date().timeIntervalSince(probeStart), 1e-6)

        for run in 0..<maxRuns {
            var runHashOps = 0
            func g(_ t: [UInt8]) throws -> [UInt8] {
                let p = parity(t, bits: bits)
                let m = try modify(docs[p], value: t, bits: bits, method: options.method, run: run)
                runHashOps += 1
                return truncate(Hashing.hash(m, algorithm: options.hash), bits: bits)
            }

            var seed = [UInt8](repeating: 0, count: options.hash.digestLength)
            _ = SecRandomCopyBytes(kSecRandomDefault, seed.count, &seed)
            let t0 = truncate(seed, bits: bits)

            // Phase 1: Floyd – tortoise one step, hare two steps
            var tortoise = try g(t0)
            var hare = try g(try g(t0))
            var steps = 1
            var aborted = false
            while tortoise != hare {
                if steps >= cap { aborted = true; break }
                if cancel?.isCancelled == true { break }
                tortoise = try g(tortoise)
                hare = try g(try g(hare))
                steps += 1
                if steps % 256 == 0 { progress?(min(1, Double(steps) / Double(expected))) }
            }
            totalSteps += steps
            if cancel?.isCancelled == true {
                hashOps += runHashOps
                runs.append(RunStatistics(run: run + 1, collisionSteps: steps, confirmationSteps: 0, outcome: "abgebrochen"))
                return Result(success: false, harmless: harmless, dangerous: dangerous, harmlessHash: [], dangerousHash: [],
                              runs: runs, totalSteps: totalSteps, hashOperations: hashOps, elapsed: Date().timeIntervalSince(start),
                              expectedSteps: expected, expectedSeconds: Double(expected) * 5 / perSecond,
                              addedBytesHarmless: 0, addedBytesDangerous: 0, cancelled: true)
            }
            if aborted {
                hashOps += runHashOps
                runs.append(RunStatistics(run: run + 1, collisionSteps: steps, confirmationSteps: 0, outcome: "Schrittlimit erreicht"))
                continue
            }

            // Phase 2: find the two predecessors that map to the same value
            var x = t0, y = tortoise
            var confirm = 0
            if x == y {
                hashOps += runHashOps
                runs.append(RunStatistics(run: run + 1, collisionSteps: steps, confirmationSteps: 0, outcome: "unbrauchbare Kollision"))
                continue
            }
            var found: ([UInt8], [UInt8])?
            while true {
                let gx = try g(x), gy = try g(y)
                confirm += 1
                if gx == gy { found = (x, y); break }
                x = gx; y = gy
                if confirm > cap { break }
            }
            totalSteps += confirm
            hashOps += runHashOps
            guard let (a, b) = found, parity(a, bits: bits) != parity(b, bits: bits) else {
                runs.append(RunStatistics(run: run + 1, collisionSteps: steps, confirmationSteps: confirm, outcome: "unbrauchbare Kollision (gleiche Nachricht)"))
                continue
            }
            // a and b have different parities → one modifies the harmless, the other the dangerous text
            let (hv, dv) = parity(a, bits: bits) == 0 ? (a, b) : (b, a)
            let h = try modify(harmless, value: hv, bits: bits, method: options.method, run: run)
            let d = try modify(dangerous, value: dv, bits: bits, method: options.method, run: run)
            runs.append(RunStatistics(run: run + 1, collisionSteps: steps, confirmationSteps: confirm, outcome: "erfolgreich"))
            progress?(1)
            return Result(success: true, harmless: h, dangerous: d,
                          harmlessHash: Hashing.hash(h, algorithm: options.hash),
                          dangerousHash: Hashing.hash(d, algorithm: options.hash),
                          runs: runs, totalSteps: totalSteps, hashOperations: hashOps,
                          elapsed: Date().timeIntervalSince(start),
                          expectedSteps: expected, expectedSeconds: Double(expected) * 5 / perSecond,
                          addedBytesHarmless: h.count - harmless.count, addedBytesDangerous: d.count - dangerous.count,
                          cancelled: false)
        }
        return Result(success: false, harmless: harmless, dangerous: dangerous, harmlessHash: [], dangerousHash: [],
                      runs: runs, totalSteps: totalSteps, hashOperations: hashOps, elapsed: Date().timeIntervalSince(start),
                      expectedSteps: expected, expectedSeconds: Double(expected) * 5 / perSecond,
                      addedBytesHarmless: 0, addedBytesDangerous: 0, cancelled: false)
    }
}
