import Foundation
import CTBigNum

/// Lesson 3–6 computations (primality, encryption, factorisation, discrete logarithms).
enum ZTCompute2 {
    typealias M = ZTM

    static func mersenneFermat(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n bis", "k bis"]); let (nMax, kMax) = (x[0], x[1])
        try M.check((2...127).contains(nMax) && (0...11).contains(kMax), "n ≤ 127 und k ≤ 11 bitte.")
        var out = ["Mersennezahlen M_n = 2ⁿ – 1  (n zusammengesetzt ⇒ M_n zusammengesetzt):"]
        for n in 2...nMax {
            let mn = BigUInt(1) << n - BigUInt(1)
            let prime = Primality.isProbablePrime(mn)
            let shown = mn.digitCount() <= 24 ? mn.description : "(\(mn.digitCount()) Stellen)"
            out.append("  n = \(M.pad(n, 3)): \(shown)  " + (prime ? "prim" : (M.isPrime(n) ? "zusammengesetzt" + (n <= 40 ? " = \(M.pfz(M.factor(Int(mn.uint64Value ?? 0))))" : "") : "zusammengesetzt (n = \(M.pfz(M.factor(n))))")))
        }
        out.append(""); out.append("Fermatzahlen F_k = 2^(2^k) + 1:")
        for k in 0...kMax {
            let f = BigUInt(1) << (1 << k) + BigUInt(1)
            let shown = f.digitCount() <= 24 ? f.description : "(\(f.digitCount()) Stellen)"
            out.append("  k = \(M.pad(k, 2)): \(shown)  " + (Primality.isProbablePrime(f) ? "prim" : "zusammengesetzt") + (k == 5 ? "  = 641 · 6700417 (Euler)" : ""))
        }
        return out.joined(separator: "\n")
    }

    static func fermatTest(_ v: [String]) throws -> String {
        let n = try M.ints([v[0]], labels: ["n"])[0], bases = try M.list(v[1])
        try M.check(n >= 3 && n <= 1_000_000_000_000_000, "3 ≤ n ≤ 10¹⁵ bitte.")
        var out = ["Fermat-Test für n = \(n):  Ist a^(n–1) ≢ 1 mod n, dann ist n zusammengesetzt (a ist Zeuge)."]
        for a in bases.prefix(12) {
            let g = M.gcd(a, n), r = M.powmod(a, n - 1, n)
            let verdict = g != 1 ? "ggT(a, n) = \(g) – n ist zusammengesetzt" : (r != 1 ? "Zeuge ⇒ n ist zusammengesetzt" : "bestanden" + (M.isPrime(n) ? "" : " – n ist Pseudoprimzahl zur Basis \(a)!"))
            out.append("  a = \(M.pad(a, 4)):  \(a)^\(n - 1) mod \(n) = \(r)   \(verdict)")
        }
        out.append("")
        out.append("Tatsächlich ist \(n) " + (M.isPrime(n) ? "eine Primzahl." : "zusammengesetzt: \(M.pfz(M.factor(n)))."))
        if n <= 200_000 && !M.isPrime(n) {
            let units = (1..<n).filter { M.gcd($0, n) == 1 }
            let liars = units.filter { M.powmod($0, n - 1, n) == 1 }
            out.append("Fermat-Lügner: \(liars.count) von φ(n) = \(units.count) teilerfremden Basen"
                       + (liars.count == units.count ? " – alle! \(n) ist eine Carmichael-Zahl." : (liars.count * 2 <= units.count ? " (höchstens 50 %)." : ".")))
            if liars.count <= 40 { out.append("Lügner: " + M.set(liars)) }
        }
        return out.joined(separator: "\n")
    }

    static func carmichael(_ v: [String]) throws -> String {
        let limit = try M.ints(v, labels: ["Grenze"])[0]
        try M.check(limit >= 561 && limit <= 2_000_000, "561 ≤ Grenze ≤ 2·10⁶ bitte.")
        var spf = [Int](repeating: 0, count: limit + 1)
        for i in 2...limit where spf[i] == 0 { var j = i; while j <= limit { if spf[j] == 0 { spf[j] = i }; j += i } }
        var out = ["Korselt: n ist Carmichael-Zahl ⇔ n zusammengesetzt, quadratfrei und (p – 1) | (n – 1) für alle p | n.", ""]
        var count = 0
        for n in stride(from: 9, through: limit, by: 2) where spf[n] != n {
            var m = n, ps: [Int] = [], ok = true
            while m > 1 {
                let p = spf[m]; m /= p
                if m % p == 0 || (n - 1) % (p - 1) != 0 { ok = false; break }
                ps.append(p)
            }
            if ok && ps.count >= 2 {
                count += 1
                if count <= 60 { out.append("  \(M.pad(n, 9)) = " + ps.map(String.init).joined(separator: " · ")) }
            }
        }
        out.append(""); out.append("\(count) Carmichael-Zahlen ≤ \(limit). Jede hat mindestens 3 Primfaktoren.")
        return out.joined(separator: "\n")
    }

    static func millerRabin(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "a"]); let (n, a) = (x[0], x[1])
        try M.check(n >= 5 && n % 2 == 1 && n <= 1_000_000_000_000_000, "Ungerades n mit 5 ≤ n ≤ 10¹⁵ bitte.")
        try M.check(a >= 2 && a <= n - 2, "Basis 2 ≤ a ≤ n – 2 bitte.")
        var d = n - 1, s = 0
        while d % 2 == 0 { d /= 2; s += 1 }
        var out = ["n – 1 = \(n - 1) = 2\(M.sup(s)) · \(d)   (s = \(s), d = \(d))"]
        if M.gcd(a, n) != 1 { out.append("ggT(\(a), \(n)) = \(M.gcd(a, n)) – Glück gehabt, Teiler gefunden: n ist zusammengesetzt.") ; return out.joined(separator: "\n") }
        var b = M.powmod(a, d, n)
        out.append("b₀ = a^d mod n = \(a)^\(d) mod \(n) = \(b)" + (b == n - 1 ? " ≡ –1" : ""))
        var passes = b == 1 || b == n - 1
        if !passes {
            for r in 1..<max(1, s) {
                b = M.mulmod(b, b, n)
                out.append("b\(M.sub(r)) = b\(M.sub(r - 1))² mod n = \(b)" + (b == n - 1 ? " ≡ –1" : ""))
                if b == n - 1 { passes = true; break }
                if b == 1 { break }
            }
        }
        out.append("")
        if passes {
            out.append("n besteht den Test zur Basis \(a): n ist prim oder starke Pseudoprimzahl zur Basis \(a).")
            if !M.isPrime(n) { out.append("Tatsächlich ist \(n) = \(M.pfz(M.factor(n))) zusammengesetzt – \(a) ist ein starker Lügner!") }
        } else {
            out.append("\(a) ist ein (starker) Zeuge: \(n) ist zusammengesetzt" + (n < 1_000_000_000_000 ? " (\(M.pfz(M.factor(n))))." : "."))
        }
        if n <= 50_000 && !M.isPrime(n) {
            let liars = (2...(n - 2)).filter { Primality.isStrongProbablePrime(BigUInt(n), base: BigUInt($0)) }
            out.append("Starke Lügner unter 2 … n–2: \(liars.count) von \(n - 3)  (höchstens 1/4)" + (liars.count <= 30 && !liars.isEmpty ? ": " + M.set(liars) : ""))
        }
        return out.joined(separator: "\n")
    }

    // MARK: Lesson 4

    static func numbers(_ c: [Int]) -> String { c.map { String(format: "%02d", $0) }.joined(separator: " ") }

    static func caesar(_ v: [String]) throws -> String {
        guard let b = M.int(v[1]) else { throw ZTError("Schlüssel b muss eine ganze Zahl sein.") }
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Bitte einen Text eingeben.")
        let c = x.map { M.mod($0 + b, 27) }
        return "Alphabet: Leerzeichen = 0, A = 1, …, Z = 26  (|Alphabet| = 27)\n\n"
            + "Klartext:   \(M.text(x))\n            \(numbers(x))\nV(x) = x + \(b) (mod 27)\n"
            + "            \(numbers(c))\nGeheimtext: \(M.text(c))\n\nE(x) = x – \(b) (mod 27) ergibt wieder: \(M.text(c.map { $0 - b }))"
    }

    static func multiplicative(_ v: [String]) throws -> String {
        let k = try M.ints([v[1], v[2]], labels: ["a", "b"]); let (a, b) = (M.mod(k[0], 27), M.mod(k[1], 27))
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Bitte einen Text eingeben.")
        let c = x.map { M.mod(a * $0 + b, 27) }
        var out = ["V(x) = \(a)·x + \(b) (mod 27)", "Klartext:   \(M.text(x))", "            \(numbers(x))",
                   "            \(numbers(c))", "Geheimtext: \(M.text(c))", ""]
        if let ai = M.inverse(a, 27) {
            out.append("ggT(\(a), 27) = 1 ⇒ umkehrbar: a' = \(a)⁻¹ = \(ai) mod 27,  E(x) = \(ai)·(x – \(b)) (mod 27)")
            out.append("Entschlüsselt: \(M.text(c.map { ai * ($0 - b) }))")
        } else {
            out.append("ggT(\(a), 27) = \(M.gcd(a, 27)) ≠ 1 ⇒ NICHT umkehrbar – verschiedene Zeichen fallen zusammen!")
        }
        out.append("Anzahl Schlüssel: φ(27) · 27 = 18 · 27 = 486")
        return out.joined(separator: "\n")
    }

    static func frequency(_ v: [String]) throws -> String {
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Bitte einen Text eingeben.")
        var counts = [Int](repeating: 0, count: 27)
        for c in x { counts[c] += 1 }
        let maxC = counts.max() ?? 1
        let rows = counts.enumerated().filter { $0.element > 0 }.sorted { $0.element > $1.element }.map {
            "  '\(M.alphabet[$0.offset])'  \(M.pad($0.element, 4))  \(String(format: "%5.1f", 100.0 * Double($0.element) / Double(x.count))) %  "
                + String(repeating: "█", count: max(1, 40 * $0.element / maxC))
        }
        return (["\(x.count) Zeichen; häufigste zuerst:"] + rows
                + ["", "Im Deutschen sind Leerzeichen und E am häufigsten – bei Cäsar verrät das den Schlüssel."]).joined(separator: "\n")
    }

    static func textToNumber(_ v: [String]) throws -> String {
        let x = M.codes(v[0])
        let g = try M.big(v[1])
        try M.check(!x.isEmpty, "Bitte einen Text eingeben.")
        try M.check(g >= BigUInt(27), "Die Grenze G muss ≥ 27 sein.")
        var total = BigUInt(0)
        for c in x { total = total * BigUInt(27) + BigUInt(c) }
        var len = 0, p = BigUInt(27)
        while p <= g { len += 1; p = p * BigUInt(27) }
        len = max(1, len)
        var out = ["Ziffern (Basis B = 27): \(numbers(x))",
                   "Text als Zahl: Σ xᵢ·27^(k–i) = \(total)", "",
                   "Blocklänge L = ⌊log₂₇ G⌋ = \(len):"]
        var i = 0
        while i < x.count {
            let blk = Array(x[i..<min(i + len, x.count)])
            var n = BigUInt(0)
            for c in blk { n = n * BigUInt(27) + BigUInt(c) }
            out.append("  „\(M.text(blk))“ → \(n)")
            i += len
        }
        if x.first == 0 { out.append(""); out.append("Achtung: Der Text beginnt mit einem Leerzeichen (Ziffer 0) – eine führende 0 geht beim Lesen als Zahl verloren!") }
        return out.joined(separator: "\n")
    }

    static func primeAtLeast(_ x: BigUInt) -> BigUInt { Primality.isProbablePrime(x) ? x : Primality.nextPrime(after: x) }

    static func rsa(_ v: [String]) throws -> String {
        let p0 = try M.big(v[0]), q0 = try M.big(v[1]), b = try M.big(v[2]), n = try M.big(v[3])
        try M.check(p0.digitCount() <= 35 && q0.digitCount() <= 35, "p und q höchstens 35-stellig (wie in ZT).")
        let p = primeAtLeast(max(p0, BigUInt(3))), q = primeAtLeast(max(q0, BigUInt(3)))
        try M.check(p != q, "p und q müssen verschieden sein.")
        let m = p * q, ph = (p - BigUInt(1)) * (q - BigUInt(1))
        var out = ["p = \(p)" + (p != p0 ? "   (nächste Primzahl ≥ \(p0))" : ""), "q = \(q)" + (q != q0 ? "   (nächste Primzahl ≥ \(q0))" : ""),
                   "RSA-Modul m = p·q = \(m)", "φ(m) = (p–1)·(q–1) = \(ph)", ""]
        guard b.gcd(ph).isOne, let a = b.inverse(modulo: ph) else {
            out.append("ggT(b, φ(m)) = \(b.gcd(ph)) ≠ 1 – b muss teilerfremd zu φ(m) sein.")
            return out.joined(separator: "\n")
        }
        out += ["privater Schlüssel b = \(b)", "a = b⁻¹ mod φ(m) = \(a)   (Euklid; a·b ≡ 1 mod φ(m))",
                "öffentlicher Schlüssel (m, a) = (\(m), \(a))", ""]
        guard n < m else { out.append("Die Nachricht n muss kleiner als m sein."); return out.joined(separator: "\n") }
        let c = n.power(a, modulus: m), back = c.power(b, modulus: m)
        out += ["Sender:      c = n^a mod m = \(c)", "Empfängerin: c^b mod m = \(back)" + (back == n ? "  = n ✓" : ""),
                n.gcd(m).isOne ? "" : "Hinweis: n ist nicht teilerfremd zu m (ggT = \(n.gcd(m)))."]
        return out.joined(separator: "\n")
    }

    static func rabin(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "q", "n"]); let (p, q, n) = (x[0], x[1], x[2])
        try M.check(M.isPrime(p) && M.isPrime(q) && p % 4 == 3 && q % 4 == 3 && p != q && p < 3_000_000 && q < 3_000_000,
                    "p, q verschiedene Primzahlen ≡ 3 mod 4 (< 3·10⁶) bitte.")
        let m = p * q
        try M.check(n >= 0 && n < m, "0 ≤ n < m = \(m) bitte.")
        let c = M.mulmod(n, n, m)
        let rp = M.powmod(c, (p + 1) / 4, p), rq = M.powmod(c, (q + 1) / 4, q)
        let e = M.extGcd(p, q)
        func comb(_ a: Int, _ b: Int) -> Int { M.mod(M.mulmod(M.mulmod(a, q, m), M.mod(e.y, m), m) + M.mulmod(M.mulmod(b, p, m), M.mod(e.x, m), m), m) }
        let roots = [comb(rp, rq), comb(rp, q - rq), comb(p - rp, rq), comb(p - rp, q - rq)].map { M.mod($0, m) }
        return ["Öffentlich: m = p·q = \(m);  geheim: p = \(p), q = \(q)  (beide ≡ 3 mod 4)",
                "Verschlüsseln: c = n² mod m = \(n)² mod \(m) = \(c)", "",
                "Entschlüsseln: Wurzeln mod p und mod q (kleiner Fermat):",
                "  c^((p+1)/4) mod p = \(rp)    c^((q+1)/4) mod q = \(rq)",
                "Chinesischer Restsatz liefert die vier Wurzeln mod m:",
                "  " + roots.map { $0 == n ? "\($0) ⇐ n" : "\($0)" }.joined(separator: ",  "),
                "", "Welche der vier die Nachricht ist, muss die Empfängerin z. B. an einer Redundanz erkennen."].joined(separator: "\n")
    }

    static func diffieHellman(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "g", "x (Alice)", "y (Bob)"]); let (p, g, a, b) = (x[0], x[1], x[2], x[3])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p muss eine Primzahl ≤ 10¹² sein.")
        let A = M.powmod(g, a, p), B = M.powmod(g, b, p)
        var out = ["Öffentlich: Primzahl p = \(p), Basis g = \(g)"]
        if p <= 10_000_000, let o = M.ord(g, p) { out.append("ord(g) = \(o)" + (o == p - 1 ? " – g ist primitive Restklasse" : " (g ist keine primitive Restklasse)")) }
        out += ["Alice: geheim x = \(a), sendet A = g^x mod p = \(A)", "Bob:   geheim y = \(b), sendet B = g^y mod p = \(B)",
                "Alice: K = B^x mod p = \(M.powmod(B, a, p))", "Bob:   K = A^y mod p = \(M.powmod(A, b, p))", "",
                "Ein Lauscher kennt p, g, A, B – für K bräuchte er den diskreten Logarithmus von A oder B."]
        return out.joined(separator: "\n")
    }

    static func elgamal(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "g", "b (Alice)", "n", "k (Bob)"]); let (p, g, b, n, k) = (x[0], x[1], x[2], x[3], x[4])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p muss eine Primzahl ≤ 10¹² sein.")
        try M.check(n > 0 && n < p, "Die Nachricht n muss zwischen 1 und p–1 liegen.")
        let B = M.powmod(g, b, p), c1 = M.powmod(g, k, p), c2 = M.mulmod(n, M.powmod(B, k, p), p)
        let s = M.powmod(c1, p - 1 - M.mod(b, p - 1), p)
        return ["Alice: geheim b = \(b), öffentlich (p, g, B = g^b) = (\(p), \(g), \(B))",
                "Bob wählt zufällig k = \(k) und sendet", "  c₁ = g^k mod p = \(c1)", "  c₂ = n·B^k mod p = \(c2)", "",
                "Alice: c₁^(p–1–b) = (g^k)^(–b) mod p = \(s)   (kleiner Fermat)",
                "       n = c₂ · c₁^(p–1–b) mod p = \(M.mulmod(c2, s, p))",
                "", "Für jede Nachricht sollte Bob ein neues k wählen."].joined(separator: "\n")
    }

    // MARK: Lesson 5

    static func fermatFactor(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 3 && n % 2 == 1 && n <= 1_000_000_000_000_000, "Ungerades n (3 ≤ n ≤ 10¹⁵) bitte.")
        var a = M.isqrt(n); if a * a < n { a += 1 }
        var out = ["n = a² – b² = (a + b)(a – b).  Start mit a = ⌈√n⌉ = \(a):", ""]
        var steps = 0
        while steps < 2_000_000 {
            let d = a * a - n, b = M.isqrt(d)
            if steps < 20 { out.append("  a = \(a):  a² – n = \(d)" + (b * b == d ? " = \(b)²  ✓" : "  kein Quadrat")) }
            if b * b == d {
                out += ["", "\(n) = \(a)² – \(b)² = (\(a + b)) · (\(a - b))  nach \(steps + 1) Schritten",
                        a - b == 1 ? "Triviale Zerlegung – \(n) ist eine Primzahl." : ""]
                return out.joined(separator: "\n")
            }
            a += 1; steps += 1
        }
        out.append("… abgebrochen – die Faktoren liegen weit auseinander (Fermat lohnt nur bei nahe beieinander liegenden Faktoren).")
        return out.joined(separator: "\n")
    }

    static func birthday(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["k", "N"]); let (k, n) = (x[0], x[1])
        try M.check(k >= 1 && k <= 100_000 && n >= 1 && n <= 1_000_000_000, "1 ≤ k ≤ 10⁵, 1 ≤ N ≤ 10⁹ bitte.")
        func p(_ k: Int) -> Double { var q = 1.0; for i in 0..<k { q *= 1 - Double(i) / Double(n) }; return 1 - q }
        var out = ["Wahrscheinlichkeit, dass unter \(k) zufälligen Werten aus \(n) zwei gleich sind:",
                   "P = 1 – (1 – 1/N)(1 – 2/N)···(1 – (k–1)/N) = \(String(format: "%.4f", p(k)))", ""]
        for kk in [Int(Double(n).squareRoot() / 2), Int(Double(n).squareRoot()), Int(1.1774 * Double(n).squareRoot()), 2 * Int(Double(n).squareRoot())] where kk > 0 {
            out.append("  k = \(M.pad(kk, 7)):  P = \(String(format: "%.4f", p(kk)))")
        }
        out.append(""); out.append("Schon bei k ≈ 1,18·√N ist P ≈ 50 % – darauf beruht Pollards Rho-Methode.")
        return out.joined(separator: "\n")
    }

    static func rhoSequence(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "x₀", "c"]); let (n, x0, c) = (x[0], x[1], x[2])
        try M.check(n >= 2 && n <= 100_000, "2 ≤ n ≤ 100000 bitte.")
        func walk(_ m: Int) -> (seq: [Int], mu: Int, lambda: Int) {
            var seen: [Int: Int] = [:], s: [Int] = [], v = M.mod(x0, m)
            while seen[v] == nil { seen[v] = s.count; s.append(v); v = M.mod(v * v + c, m) }
            return (s, seen[v]!, s.count - seen[v]!)
        }
        var out: [String] = []
        let (s, mu, la) = walk(n)
        out.append("xᵢ₊₁ = xᵢ² + \(c) mod \(n):  " + s.prefix(60).map(String.init).joined(separator: ", ") + (s.count > 60 ? ", …" : "") + ", …")
        out.append("Vorperiode μ = \(mu), Periode λ = \(la) – die Folge läuft „im Kreis“ (Form des Buchstabens ρ).")
        if let d = M.factor(n).first?.p, d < n {
            let (t, mu2, la2) = walk(d)
            out.append(""); out.append("Dieselbe Folge mod \(d) (Primteiler von n): " + t.map(String.init).joined(separator: ", ") + ", …")
            out.append("μ = \(mu2), λ = \(la2) – der Kreis mod \(d) schließt sich viel früher; dann teilt \(d) die Differenz xᵢ – xⱼ.")
        }
        func f(_ v: Int) -> Int { M.mod(v * v + c, n) }
        var i = 1, a = f(M.mod(x0, n)), b = f(f(M.mod(x0, n)))
        while a != b && i < 10 * n { a = f(a); b = f(f(b)); i += 1 }
        out.append(""); out.append("Floyd: x_i = x_2i zuerst bei i = \(i) (Hase und Igel).")
        return out.joined(separator: "\n")
    }

    static func pollardRho(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "x₀", "c"]); let (n, x0, c) = (x[0], x[1], x[2])
        try M.check(n >= 4 && n <= 1_000_000_000_000_000_000, "4 ≤ n ≤ 10¹⁸ bitte.")
        if M.isPrime(n) { return "\(n) ist eine Primzahl." }
        func f(_ v: Int) -> Int { M.mod(M.mulmod(v, v, n) + M.mod(c, n), n) }
        var a = M.mod(x0, n), b = a, d = 1, i = 0
        var out = ["f(x) = x² + \(c) mod \(n), Floyd: x = f(x), y = f(f(y)), d = ggT(|x – y|, n)", "",
                   "     i                  x                  y        d"]
        while d == 1 && i < 2_000_000 {
            a = f(a); b = f(f(b)); i += 1
            d = M.gcd(abs(a - b), n)
            if i <= 30 || d != 1 { out.append("\(M.pad(i, 6)) \(M.pad(a, 18)) \(M.pad(b, 18)) \(M.pad(d, 8))") } else if i == 31 { out.append("   …") }
        }
        out.append("")
        if d == 1 { out.append("Kein Teiler nach \(i) Schritten – abgebrochen.") }
        else if d == n { out.append("Misserfolg: d = n. Andere Startwerte x₀ oder c probieren.") }
        else { out.append("Teiler gefunden: \(n) = \(d) · \(n / d)  nach \(i) Schritten") }
        return out.joined(separator: "\n")
    }

    static func pollardPm1(_ v: [String]) throws -> String {
        let n = try M.big(v[0])
        guard let bound = M.int(v[1]), let a0 = M.int(v[2]) else { throw ZTError("B und a müssen ganze Zahlen sein.") }
        try M.check(n > BigUInt(3) && n.digitCount() <= 70, "n mit höchstens 70 Stellen bitte (Produkte mit * erlaubt).")
        try M.check(bound >= 2 && bound <= 1_000_000 && a0 >= 2, "2 ≤ B ≤ 10⁶ und a ≥ 2 bitte.")
        var a = BigUInt(a0) % n
        var out = ["n = \(n)", "k = Produkt aller Primzahlpotenzen pᵉ ≤ B = \(bound);  berechne a^k mod n und ggT(a^k – 1, n)", ""]
        let primes = Primality.sieve(upTo: bound)
        var shown = 0
        for p in primes {
            var pe = p
            while pe <= bound / p { pe *= p }
            a = a.power(BigUInt(pe), modulus: n)
            let d = (a == BigUInt(0) ? n : (a + n - BigUInt(1)) % n).gcd(n)
            if shown < 15 { out.append("  pᵉ = \(M.pad(pe, 7)):  ggT(a^k – 1, n) = \(d)"); shown += 1 }
            if !d.isOne {
                out.append("")
                if d == n { out.append("ggT = n – alle Primfaktoren auf einmal erwischt. B verkleinern oder anderes a wählen.") }
                else { out.append("Teiler gefunden: \(d)  (p – 1 war \(bound)-glatt).  n = \(d) · \(n / d)") }
                return out.joined(separator: "\n")
            }
        }
        out.append(""); out.append("ggT = 1: Für keinen Primteiler p ist p – 1 \(bound)-glatt. B vergrößern.")
        return out.joined(separator: "\n")
    }

    // MARK: Lesson 6

    static func dlogEnum(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["g", "a", "p"]); let (g, a, p) = (x[0], x[1], x[2])
        try M.check(p >= 3 && p <= 100_000_000, "3 ≤ p ≤ 10⁸ bitte.")
        var out = ["Gesucht: x mit \(g)^x ≡ \(a) mod \(p)  (diskreter Logarithmus)", ""]
        var y = 1
        for e in 0..<p {
            if e < 25 { out.append("  \(g)^\(e) ≡ \(y)") } else if e == 25 { out.append("  …") }
            if y == M.mod(a, p) {
                out += ["", "x = \(e)  nach \(e + 1) Potenzen (Enumeration)", "Probe: \(g)^\(e) mod \(p) = \(M.powmod(g, e, p))"]
                return out.joined(separator: "\n")
            }
            y = M.mulmod(y, g, p)
            if y == 1 && e > 0 { break }
        }
        out.append(""); out.append("\(a) liegt nicht in ⟨\(g)⟩ – es gibt keinen Logarithmus.")
        return out.joined(separator: "\n")
    }

    static func bsgs(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["g", "a", "p"]); let (g, a, p) = (x[0], x[1], x[2])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p muss eine Primzahl ≤ 10¹² sein.")
        let n = p - 1
        var w = M.isqrt(n); if w * w < n { w += 1 }
        guard let gi = M.inverse(g, p) else { throw ZTError("g muss teilerfremd zu p sein.") }
        var table: [Int: Int] = [:], out = ["n = p – 1 = \(n),  w = ⌈√n⌉ = \(w)", "", "Babysteps (a·g^(–r) mod p, r):"]
        var bstep = M.mod(a, p), line: [String] = []
        for r in 0..<w {
            if table[bstep] == nil { table[bstep] = r }
            if r < 40 { line.append("(\(bstep), \(r))") }
            bstep = M.mulmod(bstep, gi, p)
        }
        out.append("  " + line.joined(separator: " ") + (w > 40 ? " …" : ""))
        if let r = table[1] { out += ["", "Paar (1, \(r)) ⇒ x = \(r)"]; return out.joined(separator: "\n") }
        let d = M.powmod(g, w, p)
        out += ["", "Giantsteps mit d = g^w = \(d):"]
        var y = 1
        for q in 1...w {
            y = M.mulmod(y, d, p)
            if q <= 20 { out.append("  q = \(q): d^q = \(y)" + (table[y] != nil ? "  ✓ in B" : "")) }
            if let r = table[y] {
                let xx = q * w + r
                out += ["", "x = q·w + r = \(q)·\(w) + \(r) = \(xx)", "Probe: \(g)^\(xx) mod \(p) = \(M.powmod(g, xx, p))"]
                return out.joined(separator: "\n")
            }
        }
        out.append(""); out.append("Kein Treffer – \(a) liegt nicht in ⟨\(g)⟩.")
        return out.joined(separator: "\n")
    }
}
