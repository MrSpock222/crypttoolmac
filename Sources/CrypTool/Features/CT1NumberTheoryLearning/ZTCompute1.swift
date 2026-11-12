import Foundation
import CTBigNum

/// Lesson 1 and 2 computations ("Ausprobieren" parts). Each returns the text shown below the input row.
enum ZTCompute1 {
    typealias M = ZTM

    static func divisorPairs(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 1 && n <= 1_000_000_000_000, "n muss zwischen 1 und 10¹² liegen.")
        let r = M.isqrt(n)
        var out = ["n = \(n),   √n ≈ \(String(format: "%.4f", Double(n).squareRoot()))", "",
                   "Teiler d ≤ √n   ·   Komplementärteiler n/d"]
        var count = 0
        for d in 1...max(1, r) where n % d == 0 {
            out.append("  \(M.pad(d, 8)) · \(n / d) = \(n)")
            count += d * d == n ? 1 : 2
        }
        out.append("")
        out.append("Anzahl der Teiler: \(count) – " + (r * r == n ? "ungerade, denn n = \(r)² ist Quadratzahl (Teiler \(r) tritt „doppelt“ auf)." : "gerade."))
        return out.joined(separator: "\n")
    }

    static func divides(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (x[0], x[1])
        if a == 0 {
            return b == 0 ? "0 | 0, denn 0·z = 0 (sogar für jedes z ∈ ℤ).\nTrotzdem ist die Division 0 : 0 nicht definiert."
                          : "0 ∤ \(b): Nur 0 wird von 0 geteilt (Regel 4)."
        }
        if b % a == 0 {
            return "\(a) | \(b), denn es existiert z = \(b / a) ∈ ℤ mit \(a)·(\(b / a)) = \(b).\n"
                + "Ebenso gilt \(-a) | \(b) und \(a) | \(-b) (Regel: –a | b ⇔ a | b ⇔ a | –b)."
        }
        let q = Int((Double(b) / Double(a)).rounded(.down))
        return "\(a) ∤ \(b): Es gibt kein z ∈ ℤ mit \(a)·z = \(b).\n"
            + "\(a)·(\(q)) = \(a * q)  und  \(a)·(\(q + 1)) = \(a * (q + 1)) – \(b) liegt dazwischen."
    }

    static func divisorSet(_ v: [String]) throws -> String {
        let a = try M.ints(v, labels: ["a"])[0]
        if a == 0 { return "T₀ = ℕ (jede natürliche Zahl teilt 0)." }
        try M.check(abs(a) <= 1_000_000_000_000, "|a| ≤ 10¹² bitte.")
        let t = M.divisors(a)
        return "T\(a) = { x ∈ ℕ | x | \(a) } = \(M.set(t, limit: 200))\n|T\(a)| = \(t.count)"
            + (a < 0 ? "\nWegen T\(a) = T\(-a) genügt es, a ∈ ℕ zu untersuchen." : "")
    }

    static func gcdSets(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (x[0], x[1])
        try M.check(a != 0 || b != 0, "a und b dürfen nicht beide 0 sein.")
        try M.check(abs(a) <= 1_000_000_000 && abs(b) <= 1_000_000_000, "Bitte |a|, |b| ≤ 10⁹.")
        if a == 0 || b == 0 {
            let c = a == 0 ? b : a
            return "T₀ = ℕ, also T\(a) ∩ T\(b) = T\(abs(c)) und ggT(\(a), \(b)) = \(abs(c))."
        }
        let ta = M.divisors(a), tb = M.divisors(b)
        let common = ta.filter { tb.contains($0) }
        return ["T\(a) = \(M.set(ta))", "T\(b) = \(M.set(tb))", "T\(a) ∩ T\(b) = \(M.set(common))",
                "⇒ ggT(\(a), \(b)) = \(common.last ?? 1)" + (common.count == 1 ? "   – die Zahlen sind teilerfremd." : ""),
                "", "Die gemeinsamen Teiler sind genau die Teiler des ggT: T\(common.last ?? 1) = \(M.set(M.divisors(common.last ?? 1)))"]
            .joined(separator: "\n")
    }

    static func trialDivision(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 2 && n <= 100_000_000_000_000, "n zwischen 2 und 10¹⁴ bitte.")
        let r = M.isqrt(n)
        var out = ["Probedivision von n = \(n) durch alle Primzahlen p ≤ √n ≈ \(String(format: "%.2f", Double(n).squareRoot()))", ""]
        let primes = Primality.sieve(upTo: max(2, min(r, 10_000_000)))
        var shown = 0
        for p in primes {
            let rest = n % p
            if shown < 25 || rest == 0 { out.append("  \(M.pad(n, 1)) mod \(M.pad(p, 5)) = \(rest)" + (rest == 0 ? "   ⇐ Teiler gefunden" : "")) }
            else if shown == 25 { out.append("  …") }
            shown += 1
            if rest == 0 {
                out.append(""); out.append("\(n) = \(p) · \(n / p) ist zusammengesetzt.")
                out.append("Primfaktorzerlegung: \(n) = \(M.pfz(M.factor(n)))")
                return out.joined(separator: "\n")
            }
        }
        out.append(""); out.append("Keine Primzahl p ≤ √n teilt \(n) ⇒ \(n) ist eine Primzahl (\(primes.count) Probedivisionen).")
        return out.joined(separator: "\n")
    }

    static func factorize(_ v: [String]) throws -> String {
        let n = try M.big(v[0])
        try M.check(n > BigUInt(1), "Bitte eine natürliche Zahl n > 1 eingeben.")
        try M.check(n.digitCount() <= 40, "Höchstens 40 Stellen bitte.")
        let f = try Factorization.factorize(n)
        let s = f.map { $0.exponent == 1 ? $0.prime.description : $0.prime.description + M.sup($0.exponent) }.joined(separator: " · ")
        var out = ["\(n) = \(s)"]
        if f.count == 1 && f[0].exponent == 1 { out.append("\(n) ist eine Primzahl.") }
        let tau = f.reduce(1) { $0 * ($1.exponent + 1) }
        out.append("Primteiler: \(f.map { $0.prime.description }.joined(separator: ", "))   –   Anzahl der Teiler: \(tau)")
        out.append("Diese kanonische Zerlegung ist nach dem Fundamentalsatz eindeutig.")
        return out.joined(separator: "\n")
    }

    static func hilbert(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "Grenze"]); let (n, g) = (x[0], x[1])
        try M.check(n >= 1 && n % 4 == 1 && n <= 10_000_000, "n muss die Form 4k + 1 haben (n ≤ 10⁷).")
        try M.check(g >= 5 && g <= 5000, "Grenze zwischen 5 und 5000.")
        func hPrime(_ h: Int) -> Bool {
            guard h > 1 else { return false }
            var d = 5
            while d * d <= h { if h % d == 0 && (h / d) % 4 == 1 { return false }; d += 4 }
            return true
        }
        let hp = stride(from: 5, through: g, by: 4).filter(hPrime)
        var facts: [[Int]] = []
        func rec(_ m: Int, _ minF: Int, _ acc: [Int]) {
            if m == 1 { facts.append(acc); return }
            guard facts.count < 20 else { return }
            var d = minF
            while d * d <= m {
                if m % d == 0 && (m / d) % 4 == 1 && hPrime(d) { rec(m / d, d, acc + [d]) }
                d += 4
            }
            if m >= minF && hPrime(m) { facts.append(acc + [m]) }
        }
        if n > 1 { rec(n, 5, []) }
        var out = ["H = {1, 5, 9, 13, 17, …} ist multiplikativ abgeschlossen.",
                   "„Primzahlen in H“ ≤ \(g) (nur durch 1 und sich selbst aus H teilbar):", M.set(hp, limit: 80), ""]
        out.append(facts.isEmpty ? "\(n): keine Zerlegung" : "Zerlegungen von \(n) in H-Primzahlen:")
        for f in facts { out.append("  \(n) = " + f.map(String.init).joined(separator: " · ")) }
        if facts.count > 1 { out.append("⇒ In H ist die Zerlegung NICHT eindeutig!") }
        return out.joined(separator: "\n")
    }

    static func divisorCount(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 1 && n <= 1_000_000_000_000, "1 ≤ n ≤ 10¹² bitte.")
        let f = M.factor(n)
        let tau = f.reduce(1) { $0 * ($1.e + 1) }
        let form: String = f.isEmpty ? "1" : f.enumerated().map { "\($0.element.p)^β\(M.sub($0.offset + 1))" }.joined(separator: " · ")
        let prod: String = f.isEmpty ? "1" : f.map { "(\($0.e)+1)" }.joined(separator: "·")
        var out: [String] = ["\(n) = \(M.pfz(f))", ""]
        out.append("Jeder Teiler hat die Form \(form) mit 0 ≤ βᵢ ≤ αᵢ.")
        out.append("Anzahl der Teiler = \(prod) = \(tau)")
        if tau <= 240 { out.append("Teiler: " + M.set(M.divisors(n), limit: 240)) }
        return out.joined(separator: "\n")
    }

    static func gcdFactor(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (x[0], x[1])
        try M.check(a >= 1 && b >= 1 && a <= 1_000_000_000_000 && b <= 1_000_000_000_000, "1 ≤ a, b ≤ 10¹² bitte.")
        let fa = M.factor(a), fb = M.factor(b)
        let ps = Array(Set(fa.map(\.p) + fb.map(\.p))).sorted()
        func e(_ f: [(p: Int, e: Int)], _ p: Int) -> Int { f.first { $0.p == p }?.e ?? 0 }
        var out = ["a = \(a) = \(M.pfz(fa))", "b = \(b) = \(M.pfz(fb))", "",
                   "     p      α(a)  β(b)  min  max"]
        var g: [(p: Int, e: Int)] = [], l: [(p: Int, e: Int)] = []
        for p in ps {
            let (x, y) = (e(fa, p), e(fb, p))
            out.append("\(M.pad(p, 6))  \(M.pad(x, 6))\(M.pad(y, 6))\(M.pad(min(x, y), 5))\(M.pad(max(x, y), 5))")
            if min(x, y) > 0 { g.append((p, min(x, y))) }
            l.append((p, max(x, y)))
        }
        let lcm = BigUInt(a).lcm(BigUInt(b))
        out += ["", "ggT(a, b) = \(M.pfz(g)) = \(M.gcd(a, b))", "kgV(a, b) = \(M.pfz(l)) = \(lcm)"]
        return out.joined(separator: "\n")
    }

    static func linearCombination(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (x[0], x[1])
        try M.check(abs(a) <= 100_000 && abs(b) <= 100_000, "|a|, |b| ≤ 100000 bitte.")
        var out = ["Vielfachsummen a·x + b·y für x, y ∈ {–3, …, 3}:", "", "  y\\x " + (-3...3).map { M.pad($0, 8) }.joined()]
        for y in (-3...3).reversed() { out.append(M.pad(y, 5) + " " + (-3...3).map { M.pad(a * $0 + b * y, 8) }.joined()) }
        let g = M.extGcd(a, b)
        out += ["", "Alle Vielfachsummen sind Vielfache von ggT(\(a), \(b)) = \(g.g).",
                "Die kleinste positive Vielfachsumme ist der ggT: \(g.g) = \(a)·(\(g.x)) + \(b)·(\(g.y))."]
        return out.joined(separator: "\n")
    }

    static func subtractiveGcd(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); var (a, b) = (abs(x[0]), abs(x[1]))
        try M.check(a > 0 && b > 0, "a, b > 0 bitte.")
        var out: [String] = [], steps = 0
        while b != 0 && steps < 300 {
            if a < b { swap(&a, &b) }
            out.append("ggT(\(a), \(b)) = ggT(\(b), \(a) – \(b)) = ggT(\(b), \(a - b))")
            a -= b; steps += 1
            if a == 0 { break }
        }
        if steps >= 300 { out.append("… (nach 300 Subtraktionen abgebrochen – Euklid fasst viele Subtraktionen zu einer Division zusammen)") }
        out.append("ggT = \(max(a, b))")
        return out.joined(separator: "\n")
    }

    static func euclid(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); var (a, b) = (abs(x[0]), abs(x[1]))
        try M.check(a > 0 && b > 0, "a, b ∈ ℕ bitte (ggT(a, b) = ggT(±a, ±b)).")
        var out = ["  a = z · b + r"]
        let w = String(max(a, b)).count
        while b != 0 {
            let z = a / b, r = a % b
            out.append("  \(M.pad(a, w)) = \(M.pad(z, w)) · \(M.pad(b, w)) + \(M.pad(r, w))")
            (a, b) = (b, r)
        }
        out.append(""); out.append("Beim Rest 0 hört man auf. Der letzte Rest > 0 ist der ggT: ggT(\(abs(x[0])), \(abs(x[1]))) = \(a)")
        out.append("Anzahl der Divisionsschritte: \(out.count - 3)")
        return out.joined(separator: "\n")
    }

    static func extEuclidTable(_ a0: Int, _ b0: Int) -> (String, Int, Int, Int) {
        var (r0, r1, x0, x1, y0, y1) = (a0, b0, 1, 0, 0, 1)
        let w = max(String(a0).count, String(b0).count) + 2
        var out = ["\(M.pad("r", w)) \(M.pad("z", w)) \(M.pad("x", w)) \(M.pad("y", w))    r = a·x + b·y",
                   "\(M.pad(r0, w)) \(M.pad("", w)) \(M.pad(x0, w)) \(M.pad(y0, w))"]
        while r1 != 0 {
            let q = r0 / r1
            out.append("\(M.pad(r1, w)) \(M.pad(q, w)) \(M.pad(x1, w)) \(M.pad(y1, w))")
            (r0, r1) = (r1, r0 - q * r1); (x0, x1) = (x1, x0 - q * x1); (y0, y1) = (y1, y0 - q * y1)
        }
        out.append("\(M.pad(0, w))")
        return (out.joined(separator: "\n"), r0, x0, y0)
    }

    static func extEuclid(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (abs(x[0]), abs(x[1]))
        try M.check(a > 0 && b > 0 && a <= 1_000_000_000_000 && b <= 1_000_000_000_000, "a, b ∈ ℕ (≤ 10¹²) bitte.")
        let (t, g, s, u) = extEuclidTable(a, b)
        return t + "\n\nggT(\(a), \(b)) = \(g) = \(a)·(\(s)) + \(b)·(\(u))\nDer ggT ist also eine Vielfachsumme von a und b."
    }

    static func gcdMany(_ v: [String]) throws -> String {
        let xs = try M.list(v[0]).map { abs($0) }
        try M.check(xs.count >= 2 && xs.count <= 8 && xs.allSatisfy { $0 <= 1_000_000 }, "2 bis 8 Zahlen ≤ 10⁶ bitte.")
        var g = xs[0], c = [1], out: [String] = []
        for a in xs.dropFirst() {
            let e = M.extGcd(g, a)
            out.append("ggT(\(g), \(a)) = \(e.g)")
            c = c.map { $0 * e.x } + [e.y]; g = e.g
        }
        out.append(""); out.append("ggT(\(xs.map(String.init).joined(separator: ", "))) = \(g)")
        out.append("Vielfachsumme: \(g) = " + zip(c, xs).map { "\($1)·(\($0))" }.joined(separator: " + "))
        var pairwise = true
        for i in 0..<xs.count { for j in (i + 1)..<xs.count where M.gcd(xs[i], xs[j]) != 1 { pairwise = false } }
        out.append(g == 1 ? (pairwise ? "Die Zahlen sind paarweise teilerfremd." : "Die Zahlen sind teilerfremd, aber nicht paarweise teilerfremd.") : "")
        return out.joined(separator: "\n")
    }

    static func lcm(_ v: [String]) throws -> String {
        let xs = try M.list(v[0]).map { abs($0) }
        try M.check(!xs.isEmpty && xs.count <= 10 && xs.allSatisfy { $0 >= 1 && $0 <= 1_000_000_000 }, "1 bis 10 natürliche Zahlen ≤ 10⁹ bitte.")
        var l = BigUInt(xs[0]), out: [String] = []
        for a in xs.dropFirst() {
            let g = l.gcd(BigUInt(a))
            let n = l.lcm(BigUInt(a))
            out.append("kgV(\(l), \(a)) = \(l)·\(a) / ggT(\(l), \(a)) = \(l * BigUInt(a)) / \(g) = \(n)")
            l = n
        }
        out.append(""); out.append("kgV(\(xs.map(String.init).joined(separator: ", "))) = \(l)")
        if let li = l.uint64Value, li < 1_000_000_000_000 { out.append("= " + M.pfz(M.factor(Int(li))) + "   (je Primzahl der größte vorkommende Exponent)") }
        return out.joined(separator: "\n")
    }

    // MARK: Lesson 2

    static func divRest(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (x[0], x[1])
        try M.check(b > 0, "Der Divisor b muss > 0 sein.")
        let r = M.mod(a, b), q = (a - r) / b
        return "\(a) = \(q) · \(b) + \(r)     mit 0 ≤ r = \(r) < \(b)\n\nQuotient q = \(q),  Rest r = \(a) mod \(b) = \(r)\n"
            + "q und r sind eindeutig bestimmt:  q = ⌊\(a)/\(b)⌋,  r = \(a) – q·\(b)"
    }

    static func congruence(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b", "m"]); let (a, b, m) = (x[0], x[1], x[2])
        try M.check(m >= 1, "Der Modul m muss ∈ ℕ sein.")
        let d = a - b, ok = d % m == 0
        return "a – b = \(a) – (\(b)) = \(d)\n\(m) \(ok ? "|" : "∤") \(d)   ⇒   \(a) \(ok ? "≡" : "≢") \(b) mod \(m)\n\n"
            + "Reste:  \(a) mod \(m) = \(M.mod(a, m)),   \(b) mod \(m) = \(M.mod(b, m))"
            + (ok ? "  – gleicher Rest." : "  – verschiedene Reste.")
    }

    static func residueClass(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "m"]); let (a, m) = (x[0], x[1])
        try M.check(m >= 1 && m <= 1_000_000, "1 ≤ m ≤ 10⁶ bitte.")
        let r = M.mod(a, m)
        let members = (-3...3).map { String(r + $0 * m) }.joined(separator: ", ")
        let sym = r > m / 2 ? r - m : r
        return "\(a) mod \(m) = { x ∈ ℤ | x ≡ \(a) mod \(m) } = { …, \(members), … }\n\n"
            + "Standardvertreter (0 ≤ r < m):  \(r)\nbetragskleinster Vertreter:  \(sym)\n"
            + "ℤ\(m) hat genau \(m) Restklassen: 0 mod \(m), …, \(m - 1) mod \(m)."
    }

    static func modTables(_ v: [String]) throws -> String {
        let m = try M.ints(v, labels: ["m"])[0]
        try M.check(m >= 2 && m <= 26, "2 ≤ m ≤ 26 bitte.")
        let w = String(m - 1).count + 1
        func table(_ op: String, _ f: (Int, Int) -> Int) -> [String] {
            var t = [M.pad(op, w) + " |" + (0..<m).map { M.pad($0, w) }.joined(),
                     String(repeating: "-", count: w + 2 + w * m)]
            for a in 0..<m { t.append(M.pad(a, w) + " |" + (0..<m).map { M.pad(f(a, $0), w) }.joined()) }
            return t
        }
        let units = (1..<m).filter { M.gcd($0, m) == 1 }
        let zero = (1..<m).filter { M.gcd($0, m) != 1 }
        return (table("+", { ($0 + $1) % m }) + [""] + table("·", { ($0 * $1) % m }) + ["",
                "Einheiten (invertierbar): \(M.set(units))",
                "Nullteiler: \(zero.isEmpty ? "keine – ℤ\(m) ist ein Körper" : M.set(zero))"]).joined(separator: "\n")
    }

    static func checkNine(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b"]); let (a, b) = (abs(x[0]), abs(x[1]))
        try M.check(a <= 1_000_000_000 && b <= 1_000_000_000, "a, b ≤ 10⁹ bitte.")
        let c = a * b
        func row(_ m: Int) -> String {
            "mod \(m):  \(a) ≡ \(a % m),  \(b) ≡ \(b % m),  \(a % m)·\(b % m) = \(a % m * (b % m)) ≡ \(a % m * (b % m) % m)   und   \(c) ≡ \(c % m)   "
                + (a % m * (b % m) % m == c % m ? "✓" : "✗")
        }
        return "Rechenkontrolle für \(a) · \(b) = \(c):\n\n\(row(9))\n\(row(11))\n\n"
            + "Stimmen die Reste nicht überein, ist das Produkt sicher falsch (Neuner- bzw. Elferprobe)."
    }

    static func crossSums(_ v: [String]) throws -> String {
        let digits = v[0].filter(\.isNumber)
        guard let k = M.int(v[1]), (1...3).contains(k), !digits.isEmpty, digits.count <= 60 else { throw ZTError("Zahl (≤ 60 Stellen) und k ∈ {1, 2, 3} bitte.") }
        var blocks: [Int] = []
        var s = Substring(digits)
        while !s.isEmpty { blocks.append(Int(s.suffix(k))!); s = s.dropLast(min(k, s.count)) }
        let q = blocks.reduce(0, +)
        let alt = blocks.enumerated().reduce(0) { $0 + ($1.offset % 2 == 0 ? $1.element : -$1.element) }
        let p = Int(pow(10.0, Double(k)))
        let x = BigUInt(digits)!
        let m1 = p - 1, m2 = p + 1
        func divs(_ n: Int) -> String { M.divisors(n).filter { $0 > 1 }.map(String.init).joined(separator: ", ") }
        return ["x = \(digits),  \(k)er-Blöcke von rechts: " + blocks.map(String.init).joined(separator: " | "),
                "Q\(k)(x) = \(q)          (\(k)-stufige Quersumme)",
                "Q'\(k)(x) = \(alt)          (alternierende \(k)-stufige Quersumme)", "",
                "Wegen 10\(M.sup(k)) ≡ 1 mod \(m1) gilt x ≡ Q\(k)(x) mod \(m1):   \(x % BigUInt(m1)) = \(M.mod(q, m1))",
                "Wegen 10\(M.sup(k)) ≡ –1 mod \(m2) gilt x ≡ Q'\(k)(x) mod \(m2):   \(x % BigUInt(m2)) = \(M.mod(alt, m2))", "",
                "Teilbarkeitsregeln für die Teiler von \(m1) (\(divs(m1))) und von \(m2) (\(divs(m2)))."]
            .joined(separator: "\n")
    }

    static func units(_ v: [String]) throws -> String {
        let m = try M.ints(v, labels: ["m"])[0]
        try M.check(m >= 2 && m <= 200, "2 ≤ m ≤ 200 bitte.")
        var out = ["   a   ggT(a,m)   a⁻¹ mod \(m)"]
        for a in 1..<m {
            let g = M.gcd(a, m)
            out.append("\(M.pad(a, 4))   \(M.pad(g, 6))     " + (g == 1 ? "\(M.inverse(a, m) ?? 0)" : "– (Nullteiler: \(a)·\(m / g) ≡ 0)"))
        }
        let u = (1..<m).filter { M.gcd($0, m) == 1 }
        out += ["", "ℤ\(m)* = \(M.set(u, limit: 200))", "|ℤ\(m)*| = φ(\(m)) = \(u.count)"]
        return out.joined(separator: "\n")
    }

    static func inverse(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "m"]); let (a, m) = (M.mod(x[0], max(1, x[1])), x[1])
        try M.check(m >= 2 && m <= 1_000_000_000_000, "2 ≤ m ≤ 10¹² bitte.")
        let (t, g, _, y) = extEuclidTable(m, a)
        var out = ["Erweiterter Euklid mit m = \(m) und a = \(a):", t, ""]
        if g != 1 {
            out.append("ggT(\(a), \(m)) = \(g) ≠ 1  ⇒  \(a) mod \(m) ist nicht invertierbar (Nullteiler).")
        } else {
            let inv = M.mod(y, m)
            out.append("1 = \(m)·x + \(a)·(\(y))   ⇒   \(a)·(\(y)) ≡ 1 mod \(m)")
            out.append("Inverses: \(a)⁻¹ ≡ \(inv) mod \(m)     Probe: \(a)·\(inv) = \(a * inv) ≡ \(M.mulmod(a, inv, m))")
        }
        return out.joined(separator: "\n")
    }

    static func linearCongruence(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "b", "m"]); let (a, b, m) = (x[0], x[1], x[2])
        try M.check(m >= 2 && m <= 1_000_000_000, "2 ≤ m ≤ 10⁹ bitte.")
        let d = M.gcd(a, m)
        var out = ["\(a)·x ≡ \(b) mod \(m),   d = ggT(\(a), \(m)) = \(d)"]
        guard M.mod(b, d) == 0 else { return (out + ["d ∤ \(b)  ⇒  keine Lösung."]).joined(separator: "\n") }
        let a1 = M.mod(a / d, m / d), b1 = M.mod(b / d, m / d), m1 = m / d
        let inv = m1 == 1 ? 0 : (M.inverse(a1, m1) ?? 0)
        let x0 = m1 == 1 ? 0 : M.mulmod(inv, b1, m1)
        out.append("d | \(b)  ⇒  genau \(d) Lösung(en) modulo \(m).")
        if d > 1 { out.append("Kürzen durch d: \(a1)·x ≡ \(b1) mod \(m1)") }
        out.append("x ≡ \(a1)⁻¹·\(b1) ≡ \(inv)·\(b1) ≡ \(x0) mod \(m1)")
        out.append("Lösungen mod \(m): " + M.set((0..<min(d, 50)).map { x0 + $0 * m1 }))
        return out.joined(separator: "\n")
    }

    static func phiTable(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["bis n"])[0]
        try M.check(n >= 1 && n <= 300, "1 ≤ n ≤ 300 bitte.")
        var out: [String] = []
        for start in stride(from: 1, through: n, by: 12) {
            let r = Array(start...min(n, start + 11))
            out.append("   n  " + r.map { M.pad($0, 5) }.joined())
            out.append("φ(n)  " + r.map { M.pad(M.phi($0), 5) }.joined())
            out.append("")
        }
        out.append("Für Primzahlen p ist φ(p) = p – 1.  Σ φ(d) über alle Teiler d von n ergibt n.")
        return out.joined(separator: "\n")
    }

    static func phi(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 1 && n <= 999_999_999_999_999, "1 ≤ n < 10¹⁵ bitte.")
        let f = M.factor(n)
        let ph = f.reduce(n) { $0 / $1.p * ($1.p - 1) }
        let parts = f.map { $0.e == 1 ? "(\($0.p)–1)" : "(\($0.p)–1)·\($0.p)\(M.sup($0.e - 1))" }.joined(separator: " · ")
        return "n = \(n) = \(M.pfz(f))\n\nφ(n) = " + (f.isEmpty ? "1" : parts) + " = \(ph)\n"
            + "Formel: φ(p₁^α₁ ··· p_k^α_k) = (p₁–1)·p₁^(α₁–1) ··· (p_k–1)·p_k^(α_k–1)"
    }

    static func crt(_ v: [String]) throws -> String {
        let a = try M.list(v[0]), m = try M.list(v[1])
        try M.check(a.count == m.count && a.count >= 2 && a.count <= 6, "Gleich viele Reste und Moduln (2 bis 6) bitte.")
        try M.check(m.allSatisfy { $0 >= 2 && $0 <= 1_000_000 }, "Moduln zwischen 2 und 10⁶ bitte.")
        var out = (0..<a.count).map { "x ≡ \(a[$0]) mod \(m[$0])" }
        out.append("")
        var coprime = true
        for i in 0..<m.count { for j in (i + 1)..<m.count where M.gcd(m[i], m[j]) != 1 { coprime = false } }
        if coprime {
            let n = m.reduce(1, *)
            out.append("n = " + m.map(String.init).joined(separator: "·") + " = \(n)")
            var x = 0
            for i in 0..<m.count {
                let mi = n / m[i], yi = M.inverse(mi % m[i], m[i]) ?? 0
                out.append("M\(i + 1) = n/m\(i + 1) = \(mi),  y\(i + 1) = M\(i + 1)⁻¹ mod \(m[i]) = \(yi)")
                x = M.mod(x + M.mulmod(M.mulmod(M.mod(a[i], n), mi, n), yi, n), n)
            }
            out.append("x ≡ Σ aᵢ·Mᵢ·yᵢ ≡ \(x) mod \(n)")
        } else {
            out.append("Die Moduln sind nicht paarweise teilerfremd.")
        }
        if let s = ChineseRemainder.solve(remainders: (0..<a.count).map { BigUInt(M.mod(a[$0], m[$0])) }, moduli: m.map { BigUInt($0) }) {
            out.append("Lösung (CTBigNum): x ≡ \(s.solution) mod \(s.modulus)")
        } else {
            out.append("Das System ist nicht lösbar.")
        }
        return out.joined(separator: "\n")
    }

    static func crtMap(_ v: [String]) throws -> String {
        let m = try M.list(v[0])
        try M.check(m.count >= 2 && m.count <= 4 && m.allSatisfy { $0 >= 2 }, "2 bis 4 Moduln ≥ 2 bitte.")
        let n = m.reduce(1, *)
        try M.check(n <= 120, "Das Produkt der Moduln sollte ≤ 120 sein.")
        var out = ["x mod \(n)  ↦  (" + m.map { "x mod \($0)" }.joined(separator: ", ") + ")"]
        for x in 0..<n { out.append(M.pad(x, 6) + "    ↦  (" + m.map { String(x % $0) }.joined(separator: ", ") + ")") }
        var coprime = true
        for i in 0..<m.count { for j in (i + 1)..<m.count where M.gcd(m[i], m[j]) != 1 { coprime = false } }
        out.append("")
        out.append(coprime ? "Alle Kombinationen kommen genau einmal vor: ℤ\(n) ≅ " + m.map { "ℤ\($0)" }.joined(separator: " × ")
                           : "Die Moduln sind nicht teilerfremd – manche Kombinationen fehlen, die Abbildung ist nicht bijektiv.")
        return out.joined(separator: "\n")
    }

    static func eulerFermat(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "m"]); let (a, m) = (x[0], x[1])
        try M.check(m >= 2 && m <= 1_000_000_000_000, "2 ≤ m ≤ 10¹² bitte.")
        let ph = M.phi(m), g = M.gcd(a, m)
        var out = ["φ(\(m)) = \(ph),  ggT(\(a), \(m)) = \(g)",
                   "\(a)\(M.sup(ph)) mod \(m) = \(M.powmod(a, ph, m))" + (g == 1 ? "   (Euler-Fermat: = 1)" : "   (a nicht teilerfremd – Satz nicht anwendbar)")]
        if M.isPrime(m) { out.append("m ist prim: kleiner Fermat  \(a)\(M.sup(m - 1)) ≡ \(M.powmod(a, m - 1, m)) mod \(m)") }
        if ph <= 60 {
            out.append(""); out.append("Potenzen a^k mod m:")
            out.append((1...ph).map { "k=\($0): \(M.powmod(a, $0, m))" }.joined(separator: "   "))
        }
        out.append("Folgerung: Exponenten darf man modulo φ(m) reduzieren: a^b ≡ a^(b mod φ(m)) mod m (für ggT(a, m) = 1).")
        return out.joined(separator: "\n")
    }

    static func squareMultiply(_ v: [String]) throws -> String {
        let a = try M.big(v[0]), e = try M.big(v[1]), m = try M.big(v[2])
        try M.check(m > BigUInt(1) && e.bitLength <= 4096, "Modul > 1 und Exponent ≤ 4096 Bit bitte.")
        let bits = e.toString(radix: 2)
        var out = ["\(e) = \(bits)₂", "", "Bit   Operation          Ergebnis"]
        var r = BigUInt(1), first = true
        for (i, ch) in bits.enumerated() {
            if !first { r = r * r % m }
            if ch == "1" { r = first ? a % m : r * a % m }
            let op = first ? "a" : (ch == "1" ? "quadrieren, mal a" : "quadrieren")
            if bits.count <= 60 || i < 30 || i >= bits.count - 10 {
                out.append("\(M.pad(String(ch), 3))   " + op.padding(toLength: 20, withPad: " ", startingAt: 0) + "\(r)")
            } else if i == 30 { out.append("…") }
            first = false
        }
        out.append(""); out.append("\(a)^\(e) mod \(m) = \(r)")
        out.append("Benötigt: \(bits.count - 1) Quadrierungen und \(bits.filter { $0 == "1" }.count - 1) Multiplikationen.")
        out.append("Kontrolle (CTBigNum): \(a.power(e, modulus: m))")
        return out.joined(separator: "\n")
    }

    static func order(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["a", "m"]); let (a, m) = (x[0], x[1])
        try M.check(m >= 2 && m <= 1_000_000, "2 ≤ m ≤ 10⁶ bitte.")
        guard let o = M.ord(a, m) else { return "ggT(\(a), \(m)) ≠ 1: \(a) mod \(m) liegt nicht in ℤ\(m)*." }
        let ph = M.phi(m)
        var gen: [Int] = [], y = M.mod(a, m)
        for _ in 0..<min(o, 300) { gen.append(y); y = M.mulmod(y, a, m) }
        var out = ["|ℤ\(m)*| = φ(\(m)) = \(ph)",
                   "ord(\(M.mod(a, m))) = \(o)   (kleinstes k ≥ 1 mit a^k ≡ 1)",
                   "⟨\(M.mod(a, m))⟩ = { a¹, a², …, a\(M.sup(o)) } = \(M.set(gen, limit: 300))",
                   "Lagrange: ord(a) = |⟨a⟩| teilt |G|:  \(o) | \(ph)  ✓"]
        out.append(o == ph ? "⇒ \(M.mod(a, m)) erzeugt ganz ℤ\(m)*: ℤ\(m)* ist zyklisch, \(M.mod(a, m)) ist primitive Restklasse."
                           : "⇒ ⟨\(M.mod(a, m))⟩ ist eine echte Untergruppe (Index \(ph / o)).")
        if o > 1 {
            out.append(""); out.append("ord(a^k) = ord(a)/ggT(k, ord(a)):")
            out.append((1...min(o, 12)).map { "k=\($0): \(o / M.gcd($0, o))" }.joined(separator: "   "))
        }
        return out.joined(separator: "\n")
    }

    static func primitiveRoots(_ v: [String]) throws -> String {
        let m = try M.ints(v, labels: ["m"])[0]
        try M.check(m >= 2 && m <= 10_000_000, "2 ≤ m ≤ 10⁷ bitte.")
        let ph = M.phi(m)
        let qs = M.factor(ph).map(\.p)
        var out = ["φ(\(m)) = \(ph) = \(M.pfz(M.factor(ph)))",
                   "a ist primitiv ⇔ a^(φ/q) ≢ 1 für alle Primteiler q von φ(m) = " + qs.map(String.init).joined(separator: ", "), ""]
        var g: Int? = nil, tested = 0
        for a in 2..<max(3, m) where M.gcd(a, m) == 1 {
            let tests = qs.map { (q: $0, r: M.powmod(a, ph / $0, m)) }
            if tested < 12 { out.append("a = \(a): " + tests.map { "a^\(ph / $0.q) ≡ \($0.r)" }.joined(separator: ",  ") + (tests.allSatisfy { $0.r != 1 } ? "   ⇒ primitiv" : "")) }
            tested += 1
            if tests.allSatisfy({ $0.r != 1 }) { g = a; break }
            if tested > 5000 { break }
        }
        if m == 2 { g = 1 }
        out.append("")
        guard let gg = g else {
            out.append("ℤ\(m)* ist nicht zyklisch – es gibt keine primitive Restklasse.")
            out.append("ℤm* ist genau für m = 1, 2, 4, p^k und 2·p^k (p ungerade Primzahl) zyklisch.")
            return out.joined(separator: "\n")
        }
        let all = (1...ph).filter { M.gcd($0, ph) == 1 }.map { M.powmod(gg, $0, m) }.sorted()
        out.append("Kleinste primitive Restklasse: \(gg)")
        out.append("Alle \(all.count) = φ(φ(\(m))) primitiven Restklassen (g^k mit ggT(k, φ(m)) = 1): " + M.set(all, limit: 120))
        return out.joined(separator: "\n")
    }
}
