import Foundation

/// Näherungsweise Bestimmung der reellen Nullstellen eines Polynoms mit sehr großen
/// Ganzzahl-Koeffizienten. Dient nur dazu, Kandidaten für die exakte (ganzzahlige)
/// Prüfung in [`Coppersmith.integerRoots`] zu liefern; die endgültige Bestätigung
/// erfolgt stets exakt mit BigInt.
enum DurandKerner {

    private struct Complex {
        var re: Double
        var im: Double
        static let one = Complex(re: 1, im: 0)
        var abs2: Double { re * re + im * im }
        static func + (a: Complex, b: Complex) -> Complex { Complex(re: a.re + b.re, im: a.im + b.im) }
        static func - (a: Complex, b: Complex) -> Complex { Complex(re: a.re - b.re, im: a.im - b.im) }
        static func * (a: Complex, b: Complex) -> Complex {
            Complex(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re)
        }
        static func / (a: Complex, b: Complex) -> Complex {
            let d = b.abs2
            return Complex(re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d)
        }
    }

    /// Reelle Nullstellen von `coeffs` (coeffs[i] ≙ Koeffizient von x^i).
    static func realRoots(_ coeffs: [BigInt]) -> [Double] {
        let n = coeffs.count - 1
        guard n >= 1 else { return [] }

        // Alle Koeffizienten mit demselben Faktor 2^−scaleBits nach Double bringen
        // (Nullstellen bleiben dabei erhalten), anschließend monisch normieren.
        let maxBits = coeffs.map { $0.magnitude.bitLength }.max() ?? 0
        let scaleBits = max(0, maxBits - 50)
        var c = coeffs.map { Coppersmith.approxDouble($0, scaleBits: scaleBits) }
        let lead = c[n]
        guard lead != 0 else { return [] }
        for i in 0...n { c[i] /= lead }

        func eval(_ z: Complex) -> Complex {
            var r = Complex(re: 0, im: 0)
            for i in stride(from: n, through: 0, by: -1) {
                r = r * z + Complex(re: c[i], im: 0)
            }
            return r
        }

        var z = [Complex](repeating: .one, count: n)
        let seed = Complex(re: 0.4, im: 0.9)
        var p = Complex.one
        for k in 0..<n { p = p * seed; z[k] = p }

        for _ in 0..<500 {
            var maxDelta = 0.0
            for k in 0..<n {
                let num = eval(z[k])
                var den = Complex.one
                for j in 0..<n where j != k { den = den * (z[k] - z[j]) }
                if den.abs2 == 0 { continue }
                let delta = num / den
                z[k] = z[k] - delta
                maxDelta = max(maxDelta, delta.abs2)
            }
            if maxDelta < 1e-28 { break }
        }

        return z.filter { abs($0.im) < 1e-6 * (1 + abs($0.re)) }.map { $0.re }
    }
}
