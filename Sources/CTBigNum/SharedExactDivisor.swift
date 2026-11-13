import Foundation

/// Exakte Division vieler Dividenden durch denselben Divisor (Barrett-Kehrwert).
///
/// In der ganzzahligen LLL werden bei jedem Tausch viele große Zahlen durch dasselbe d_{k-1}
/// geteilt, und jede dieser Divisionen geht ohne Rest auf. Statt jedes Mal die Schuldivision
/// auszuführen, wird einmal μ = ⌊β^(n+L)/d⌋ berechnet (β = 2^64); danach kostet ein Quotient nur
/// noch eine Multiplikation. Der Näherungsquotient liegt höchstens um 2 unter dem wahren Wert;
/// die Korrektur wird am niederwertigsten Wort abgelesen und das Ergebnis modulo 2^64 − 1
/// geprüft. Passt etwas nicht, wird auf die gewöhnliche Division zurückgegriffen – das Ergebnis
/// ist also immer der exakte Quotient.
struct SharedExactDivisor {
    let divisor: BigUInt
    private let n: Int          // Worte des Divisors
    private let maxL: Int       // größte unterstützte Quotientenlänge in Worten
    private let mu: BigUInt     // ⌊β^(n+maxL) / d⌋
    private let dLow: UInt64
    private let dMod: UInt64    // d mod (2^64 − 1)

    /// `maxDividendWords`: obere Schranke für die Wortzahl der Dividenden.
    init(_ d: BigUInt, maxDividendWords m: Int) {
        divisor = d
        n = d.limbs.count
        maxL = max(1, m - n + 1)
        mu = (BigUInt(1) << (64 * (n + maxL))) / d
        dLow = d.limbs.first ?? 0
        dMod = SharedExactDivisor.mod64m1(d.limbs)
    }

    /// x mod (2^64 − 1): Summe der Worte mit Übertragsrückführung.
    @inline(__always)
    static func mod64m1(_ a: [UInt64]) -> UInt64 {
        var s: UInt64 = 0
        for w in a {
            let (t, o) = s.addingReportingOverflow(w)
            s = t &+ (o ? 1 : 0)
        }
        return s == UInt64.max ? 0 : s
    }

    @inline(__always)
    static func mulMod64m1(_ a: UInt64, _ b: UInt64) -> UInt64 {
        let (hi, lo) = a.multipliedFullWidth(by: b)
        let (t, o) = hi.addingReportingOverflow(lo)
        let s = t &+ (o ? 1 : 0)
        return s == UInt64.max ? 0 : s
    }

    /// x / d für d | x (x ≥ 0).
    func quotient(_ x: BigUInt) -> BigUInt {
        let m = x.limbs.count
        if m == 0 { return BigUInt() }
        let L = m - n + 1
        // nicht abgedeckte oder mehrdeutige Fälle: gewöhnliche Division
        if L < 1 || L > maxL || n == 0 || dLow == 0 || dLow == (1 << 63) || dMod == 0 { return x / divisor }
        let muL = L == maxL ? mu : mu >> (64 * (maxL - L))
        var q = ((x >> (64 * (n - 1))) * muL) >> (64 * (L + 1))
        // wahre Differenz c = x/d − q ∈ {0, 1, 2}:  c·d ≡ x − q·d  (mod 2^64)
        let r0 = x.limbs[0] &- (q.limbs.first ?? 0) &* dLow
        if r0 == dLow { q = q + BigUInt(1) } else if r0 == dLow &* 2 { q = q + BigUInt(2) } else if r0 != 0 { return x / divisor }
        // Probe modulo 2^64 − 1
        if SharedExactDivisor.mulMod64m1(SharedExactDivisor.mod64m1(q.limbs), dMod) != SharedExactDivisor.mod64m1(x.limbs) {
            return x / divisor
        }
        return q
    }

    /// Vorzeichenbehaftete Variante (d > 0, d | x).
    func quotient(_ x: BigInt) -> BigInt {
        BigInt(magnitude: quotient(x.magnitude), isNegative: x.isNegative)
    }
}
