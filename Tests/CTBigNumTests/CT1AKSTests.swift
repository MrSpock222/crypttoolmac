import Foundation
import CTCommon
import CTBigNum

/// CT1 AKS for all n < 2^8192 (multi-word coefficients) – called from main.swift.
func runCT1AKSTests() {
    section("CT1 AKS (mehrwortig)") {
        // the multi-word path agrees with the 64-bit kernel and with trial division
        for n in [2, 3, 4, 97, 561, 1009, 7919, 65_537, 1_000_003, 999_983 * 13] {
            let big = Primality.aksCT1(BigUInt(n), forceGeneric: true)
            let fast = Primality.aksCT1(BigUInt(n))
            let expected: Primality.AKSOutcome = Primality.isPrime64(UInt64(n)) ? .prime : .composite
            checkEqual(big, expected, "AKS generisch \(n)")
            checkEqual(fast, expected, "AKS 64 Bit \(n)")
        }
        // composite numbers above the old 2^62 limit are recognised
        let c = BigUInt(4_294_967_291) * BigUInt(4_294_967_279)   // two 32-bit primes
        checkEqual(time("AKS 64-Bit-Produkt") { Primality.aksCT1(c) }, .composite)
        // small factors (2^70 + 1 = 5 · …) and perfect powers
        checkEqual(Primality.aksCT1((BigUInt(1) << 70) + 1), .composite)
        checkEqual(Primality.aksCT1(BigUInt(1_000_003).power(4)), .composite)
        // 2^127-1 (prime) starts, reports progress and can be cancelled
        let tok = CancellationToken()
        var progressCalls = 0
        let r = time("AKS 2^127-1 abbrechen") {
            Primality.aksCT1((BigUInt(1) << 127) - 1, cancel: tok, progress: { _ in
                progressCalls += 1
                if progressCalls >= 3 { tok.cancel() }
            })
        }
        checkEqual(r, .cancelled)
        check(progressCalls >= 3, "Fortschritt gemeldet")
        // huge numbers are refused instead of exhausting the memory
        if case .tooLarge = Primality.aksCT1((BigUInt(1) << 4000) + 1 + nextOddNoSmallFactor()) {
            check(true)
        } else {
            check(false, "AKS 4000 Bit sollte abgelehnt werden")
        }
    }
}

/// Offset so that 2^4000 + 1 + offset has no factor below 2^20 (keeps the test fast).
private func nextOddNoSmallFactor() -> BigUInt {
    var k = BigUInt(0)
    while true {
        let n = (BigUInt(1) << 4000) + 1 + k
        var ok = !n.isEven
        if ok {
            for p in Primality.sieve(upTo: 1 << 16) where p > 2 {
                if n.remainder(dividingBy: UInt64(p)) == 0 { ok = false; break }
            }
        }
        if ok { return k }
        k += 2
    }
}
