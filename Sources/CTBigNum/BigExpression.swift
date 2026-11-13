import Foundation
import CTCommon

/// Evaluates integer expressions such as `2^127-1`, `(3+4)*5`, `0xFF*10!`, `-2^10 % 7`.
///
/// Grammar: numbers (decimal or `0x` hexadecimal, `_` separators allowed), `+ - * / %`,
/// `^` (power, right associative, binds stronger than unary minus: −2^2 = −4), unary `+`/`-`,
/// postfix `!` (factorial), parentheses. Implicit multiplication like `3(1+1)` is accepted as
/// in CT1. Division truncates toward zero, `%` has the sign of the dividend.
/// Results are limited to about 10 million bits.
public enum BigExpression {
    /// Maximum result size in bits.
    public static let maxBits = 10_000_000

    /// Evaluates the expression; throws `CTError` with an English message on syntax errors,
    /// division by zero or absurd sizes.
    public static func evaluate(_ expr: String) throws -> BigInt {
        var p = Parser(Array(expr.unicodeScalars))
        let v = try p.parseExpression()
        p.skipSpaces()
        if p.pos < p.chars.count {
            throw CTError("Unexpected character \"\(String(p.chars[p.pos]))\" at position \(p.pos + 1).")
        }
        return v
    }

    /// Evaluates and requires a non-negative result.
    public static func evaluateUnsigned(_ expr: String) throws -> BigUInt {
        let v = try evaluate(expr)
        if v.isNegative { throw CTError("The result is negative.") }
        return v.magnitude
    }

    private struct Parser {
        let chars: [Unicode.Scalar]
        var pos = 0
        init(_ c: [Unicode.Scalar]) { chars = c }

        mutating func skipSpaces() {
            while pos < chars.count, chars[pos] == " " || chars[pos] == "\t" || chars[pos] == "\n" || chars[pos] == "\r" { pos += 1 }
        }

        mutating func peek() -> Unicode.Scalar? {
            skipSpaces()
            return pos < chars.count ? chars[pos] : nil
        }

        // expression := term (('+'|'-') term)*
        mutating func parseExpression() throws -> BigInt {
            var v = try parseTerm()
            while let c = peek(), c == "+" || c == "-" || c == "−" {
                pos += 1
                let r = try parseTerm()
                v = (c == "+") ? v + r : v - r
                try checkSize(v)
            }
            return v
        }

        // term := unary (('*'|'/'|'%'|implicit) unary)*
        mutating func parseTerm() throws -> BigInt {
            var v = try parseUnary()
            while let c = peek() {
                if c == "*" || c == "·" || c == "×" || c == "/" || c == ":" || c == "%" {
                    pos += 1
                    let r = try parseUnary()
                    switch c {
                    case "/", ":":
                        if r.isZero { throw CTError("Division by zero.") }
                        v = v / r
                    case "%":
                        if r.isZero { throw CTError("Division by zero.") }
                        v = v % r
                    default:
                        try checkProduct(v, r)
                        v = v * r
                    }
                } else if c == "(" {
                    // implicit multiplication: 3(1+1)
                    let r = try parseUnary()
                    try checkProduct(v, r)
                    v = v * r
                } else {
                    break
                }
            }
            return v
        }

        // unary := ('+'|'-') unary | power
        mutating func parseUnary() throws -> BigInt {
            if let c = peek(), c == "-" || c == "−" || c == "+" {
                pos += 1
                let v = try parseUnary()
                return c == "+" ? v : -v
            }
            return try parsePower()
        }

        // power := postfix ('^' unary)?   (right associative)
        mutating func parsePower() throws -> BigInt {
            let base = try parsePostfix()
            if let c = peek(), c == "^" {
                pos += 1
                let e = try parseUnary()
                return try power(base, e)
            }
            if let c = peek(), c == "*", pos + 1 < chars.count, chars[pos + 1] == "*" {
                pos += 2
                let e = try parseUnary()
                return try power(base, e)
            }
            return base
        }

        // postfix := primary '!'*
        mutating func parsePostfix() throws -> BigInt {
            var v = try parsePrimary()
            while let c = peek(), c == "!" {
                pos += 1
                guard !v.isNegative, let n = v.intValue else { throw CTError("The factorial is only defined for non-negative numbers.") }
                if n > 300_000 { throw CTError("The factorial \(n)! is too large.") }
                v = BigInt(BigUInt.factorial(n))
            }
            return v
        }

        mutating func parsePrimary() throws -> BigInt {
            guard let c = peek() else { throw CTError("Unexpected end of the expression.") }
            if c == "(" {
                pos += 1
                let v = try parseExpression()
                guard let close = peek(), close == ")" else { throw CTError("Closing parenthesis is missing.") }
                pos += 1
                return v
            }
            if ("0"..."9").contains(c) {
                // hexadecimal?
                if c == "0", pos + 1 < chars.count, chars[pos + 1] == "x" || chars[pos + 1] == "X" {
                    pos += 2
                    let start = pos
                    while pos < chars.count, chars[pos].properties.isASCIIHexDigit || chars[pos] == "_" { pos += 1 }
                    let s = String(String.UnicodeScalarView(chars[start..<pos]))
                    guard let v = BigUInt(s, radix: 16) else { throw CTError("Invalid hexadecimal number.") }
                    return BigInt(v)
                }
                let start = pos
                while pos < chars.count, ("0"..."9").contains(chars[pos]) || chars[pos] == "_" { pos += 1 }
                let s = String(String.UnicodeScalarView(chars[start..<pos]))
                guard let v = BigUInt(s, radix: 10) else { throw CTError("Invalid number.") }
                return BigInt(v)
            }
            throw CTError("Unexpected character \"\(String(c))\" at position \(pos + 1).")
        }

        func power(_ base: BigInt, _ e: BigInt) throws -> BigInt {
            if e.isNegative {
                // only ±1 have integer inverses
                if base.magnitude.isOne { return base.power(Int(e.magnitude.low64 & 1)) }
                throw CTError("Negative exponents are not allowed.")
            }
            if base.isZero { return e.isZero ? 1 : 0 }
            if base.magnitude.isOne { return base.power(Int(e.magnitude.low64 & 1)) }
            guard let ei = e.magnitude.intValue else { throw CTError("The exponent is too large.") }
            let bits = Double(base.magnitude.bitLength - 1) * Double(ei)
            if bits > Double(BigExpression.maxBits) {
                throw CTError("The result would be too large (more than \(BigExpression.maxBits) bits).")
            }
            return base.power(ei)
        }

        func checkSize(_ v: BigInt) throws {
            if v.magnitude.bitLength > BigExpression.maxBits + 64 {
                throw CTError("The result would be too large (more than \(BigExpression.maxBits) bits).")
            }
        }

        func checkProduct(_ a: BigInt, _ b: BigInt) throws {
            if a.magnitude.bitLength + b.magnitude.bitLength > BigExpression.maxBits + 64 {
                throw CTError("The result would be too large (more than \(BigExpression.maxBits) bits).")
            }
        }
    }
}

// MARK: - Mersenne numbers

/// Mersenne numbers 2^p − 1 (CT1 "Mersenne-Zahlen berechnen").
public enum Mersenne {
    /// 2^exponent − 1 (exponent ≥ 0).
    public static func number(exponent: Int) -> BigUInt {
        precondition(exponent >= 0)
        return (BigUInt(1) << exponent) - 1
    }

    /// Exponents p of the known Mersenne primes (as of 2024, 52 primes).
    public static let knownPrimeExponents: [Int] = [
        2, 3, 5, 7, 13, 17, 19, 31, 61, 89, 107, 127, 521, 607, 1279, 2203, 2281, 3217, 4253, 4423,
        9689, 9941, 11213, 19937, 21701, 23209, 44497, 86243, 110503, 132049, 216091, 756839, 859433,
        1257787, 1398269, 2976221, 3021377, 6972593, 13466917, 20996011, 24036583, 25964951, 30402457,
        32582657, 37156667, 42643801, 43112609, 57885161, 74207281, 77232917, 82589933, 136279841,
    ]

    /// Lucas–Lehmer test: true iff 2^p − 1 is prime (p ≥ 2). Uses the fast reduction
    /// x mod (2^p − 1) = (x & M) + (x >> p). Returns false if cancelled.
    public static func lucasLehmer(exponent p: Int, cancel: CancellationToken? = nil,
                                   progress: ((Double) -> Void)? = nil) -> Bool {
        if p < 2 { return false }
        if p == 2 { return true }
        if !Primality.isPrime64(UInt64(p)) { return false }
        let m = number(exponent: p)
        var s = BigUInt(4)
        let step = max(1, (p - 2) / 200)
        for i in 0..<(p - 2) {
            // s = s² − 2 mod M
            var t = s.squared()
            t = (t >> p) + t.truncated(toBits: p)
            if t >= m { t = t - m }
            if t >= m { t = t - m }
            if t < 2 { t = t + m }
            s = t - 2
            if i % step == 0 {
                if cancel?.isCancelled == true { return false }
                progress?(Double(i) / Double(p - 2))
            }
        }
        progress?(1)
        return s.isZero
    }
}
