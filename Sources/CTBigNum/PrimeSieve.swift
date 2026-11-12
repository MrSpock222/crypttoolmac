import Foundation
import CTCommon

/// Segmented sieve of Eratosthenes producing the primes in [from, to] in ascending order.
struct PrimeSieveIterator: IteratorProtocol {
    private let upper: UInt64
    private let basePrimes: [UInt64]
    private var segment: [Bool] = []
    private var segStart: UInt64          // first odd number of the current segment
    private var index = 0
    private var pending2: Bool
    private var done: Bool
    private static let segmentSize = 1 << 15 // odd numbers per segment

    init(from: UInt64, to: UInt64) {
        upper = to
        pending2 = from <= 2 && to >= 2
        var start = max(from, 3)
        if start & 1 == 0 { start += 1 }
        segStart = start
        done = start > to
        let root = BigUInt.isqrt64(to) + 1
        basePrimes = Primality.sieve(upTo: Int(min(root, UInt64(Int32.max)))).dropFirst().map { UInt64($0) }
        if !done { fill() }
    }

    private mutating func fill() {
        let n = PrimeSieveIterator.segmentSize
        if segment.count != n {
            segment = [Bool](repeating: true, count: n)
        } else {
            segment.withUnsafeMutableBufferPointer { $0.update(repeating: true) }
        }
        let segEnd = segStart &+ UInt64(2 * n) // exclusive
        let start = segStart
        segment.withUnsafeMutableBufferPointer { seg in
            for p in basePrimes {
                let pp = p * p
                if pp >= segEnd { break }
                var m = max(pp, ((start + p - 1) / p) * p)
                if m & 1 == 0 { m += p }
                var idx = Int((m - start) / 2)
                let step = Int(p)
                while idx < n {
                    seg[idx] = false
                    idx += step
                }
            }
        }
        index = 0
    }

    mutating func next() -> UInt64? {
        if pending2 { pending2 = false; return 2 }
        while !done {
            while index < segment.count {
                let v = segStart + UInt64(2 * index)
                if v > upper { done = true; return nil }
                let isP = segment[index]
                index += 1
                if isP { return v }
            }
            let nextStart = segStart &+ UInt64(2 * PrimeSieveIterator.segmentSize)
            if nextStart > upper || nextStart < segStart { done = true; return nil }
            segStart = nextStart
            fill()
        }
        return nil
    }
}

/// Time limit + cancellation helper.
struct Deadline {
    let end: Date
    let cancel: CancellationToken?
    init(seconds: TimeInterval, cancel: CancellationToken?) {
        end = seconds.isFinite ? Date().addingTimeInterval(seconds) : .distantFuture
        self.cancel = cancel
    }
    var expired: Bool {
        if cancel?.isCancelled == true { return true }
        return Date() >= end
    }
    var remaining: TimeInterval { end.timeIntervalSinceNow }
}
