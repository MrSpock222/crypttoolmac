import Foundation
import CTBigNum

/// Small-number helpers for the ZT learning program (inputs are deliberately small, like in ZT).
struct ZTError: Error { let message: String; init(_ m: String) { message = m } }

enum ZTM {
    static func int(_ s: String) -> Int? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for (a, b) in [(" ", ""), ("\u{2009}", ""), ("–", "-"), ("−", "-"), (".", "")] { t = t.replacingOccurrences(of: a, with: b) }
        return Int(t)
    }

    static func ints(_ v: [String], labels: [String]) throws -> [Int] {
        try zip(v, labels).map { s, l in
            guard let x = int(s) else { throw ZTError("Please enter an integer for \"\(l)\".") }
            return x
        }
    }

    static func list(_ s: String) throws -> [Int] {
        let parts = s.split(whereSeparator: { ",;".contains($0) || $0 == " " }).map(String.init).filter { !$0.isEmpty }
        let r = parts.compactMap(int)
        guard r.count == parts.count, !r.isEmpty else { throw ZTError("Please enter comma-separated integers.") }
        return r
    }

    /// Parses a natural number; "·", "*" and "^" are allowed (as in ZT's p–1 demo).
    static func big(_ s: String) throws -> BigUInt {
        let t = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "·", with: "*")
        guard !t.isEmpty else { throw ZTError("Please enter a natural number.") }
        var result = BigUInt(1)
        for factor in t.split(separator: "*") {
            let pw = factor.split(separator: "^")
            guard let b = BigUInt(String(pw[0])) else { throw ZTError("\"\(factor)\" is not a natural number.") }
            var e = 1
            if pw.count == 2, let x = Int(pw[1]), x >= 0, x <= 4096 { e = x } else if pw.count != 1 { throw ZTError("Invalid exponent.") }
            result = result * b.power(e)
        }
        return result
    }

    static func check(_ ok: Bool, _ msg: String) throws { if !ok { throw ZTError(msg) } }

    static func mod(_ a: Int, _ m: Int) -> Int { let r = a % m; return r < 0 ? r + m : r }

    static func gcd(_ a: Int, _ b: Int) -> Int {
        Int(BigUInt(a.magnitude).gcd(BigUInt(b.magnitude)).uint64Value ?? 0)
    }

    static func mulmod(_ a: Int, _ b: Int, _ m: Int) -> Int {
        let x = mod(a, m), y = mod(b, m)
        let p = x.multipliedFullWidth(by: y)
        return m.dividingFullWidth((high: p.high, low: p.low)).remainder
    }

    static func powmod(_ a: Int, _ e: Int, _ m: Int) -> Int {
        if m == 1 { return 0 }
        let r = BigUInt(mod(a, m)).power(BigUInt(e), modulus: BigUInt(m))
        return Int(r.uint64Value ?? 0)
    }

    static func inverse(_ a: Int, _ m: Int) -> Int? {
        guard m > 1, let r = BigUInt(mod(a, m)).inverse(modulo: BigUInt(m)) else { return nil }
        return Int(r.uint64Value ?? 0)
    }

    static func isPrime(_ n: Int) -> Bool { n >= 2 && Primality.isPrime64(UInt64(n)) }

    /// Extended Euclid: returns (g, x, y) with a·x + b·y = g.
    static func extGcd(_ a: Int, _ b: Int) -> (g: Int, x: Int, y: Int) {
        var (r0, r1, x0, x1, y0, y1) = (a, b, 1, 0, 0, 1)
        while r1 != 0 {
            let q = r0 / r1
            (r0, r1) = (r1, r0 - q * r1); (x0, x1) = (x1, x0 - q * x1); (y0, y1) = (y1, y0 - q * y1)
        }
        return r0 < 0 ? (-r0, -x0, -y0) : (r0, x0, y0)
    }

    static func isqrt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        var r = Int(Double(n).squareRoot())
        while r * r > n { r -= 1 }
        while (r + 1) * (r + 1) <= n { r += 1 }
        return r
    }

    /// Prime factorisation (trial division up to 10^12, CTBigNum beyond).
    static func factor(_ n: Int) -> [(p: Int, e: Int)] {
        guard n > 1 else { return [] }
        if n > 1_000_000_000_000 {
            if let f = try? Factorization.factorize(BigUInt(n)) {
                return f.map { (Int($0.prime.uint64Value ?? 0), $0.exponent) }
            }
        }
        var m = n, out: [(Int, Int)] = [], p = 2
        while p * p <= m {
            if m % p == 0 { var e = 0; while m % p == 0 { m /= p; e += 1 }; out.append((p, e)) }
            p += p == 2 ? 1 : 2
        }
        if m > 1 { out.append((m, 1)) }
        return out
    }

    static func phi(_ n: Int) -> Int { factor(n).reduce(n) { $0 / $1.p * ($1.p - 1) } }

    static func divisors(_ n: Int) -> [Int] {
        let n = abs(n)
        guard n > 0 else { return [] }
        var small: [Int] = [], large: [Int] = []
        var d = 1
        while d * d <= n {
            if n % d == 0 { small.append(d); if d * d != n { large.append(n / d) } }
            d += 1
        }
        return small + large.reversed()
    }

    static let superDigits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
    static func sup(_ n: Int) -> String {
        (n < 0 ? "⁻" : "") + String(String(abs(n)).compactMap { $0.wholeNumberValue.map { superDigits[$0] } })
    }

    static let subDigits: [Character] = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
    static func sub(_ n: Int) -> String { String(String(n).compactMap { $0.wholeNumberValue.map { subDigits[$0] } }) }

    static func pfz(_ f: [(p: Int, e: Int)]) -> String {
        f.isEmpty ? "1" : f.map { $0.e == 1 ? "\($0.p)" : "\($0.p)\(sup($0.e))" }.joined(separator: " · ")
    }

    static func set(_ xs: [Int], limit: Int = 60) -> String {
        let shown = xs.prefix(limit).map(String.init).joined(separator: ", ")
        return "{" + shown + (xs.count > limit ? ", …" : "") + "}"
    }

    static func pad(_ s: Any, _ w: Int) -> String {
        let t = "\(s)"
        return t.count >= w ? t : String(repeating: " ", count: w - t.count) + t
    }

    static func ord(_ a: Int, _ m: Int) -> Int? {
        guard m > 1, gcd(a, m) == 1 else { return nil }
        var x = mod(a, m), k = 1
        while x != 1 { x = mulmod(x, a, m); k += 1; if k > m { return nil } }
        return k
    }

    /// ZT alphabet: space plus A–Z, numbered 0…26.
    static let alphabet: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    static func codes(_ text: String) -> [Int] {
        var s = text.uppercased()
        for (a, b) in [("Ä", "AE"), ("Ö", "OE"), ("Ü", "UE"), ("ß", "SS"), ("\n", " ")] { s = s.replacingOccurrences(of: a, with: b) }
        return s.compactMap { alphabet.firstIndex(of: $0) }
    }
    static func text(_ codes: [Int]) -> String { String(codes.map { alphabet[mod($0, 27)] }) }
}
