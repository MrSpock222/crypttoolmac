import Foundation
import CTBigNum

/// Lesson 3–6 computations (primality, encryption, factorisation, discrete logarithms).
enum ZTCompute2 {
    typealias M = ZTM

    static func mersenneFermat(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n up to", "k up to"]); let (nMax, kMax) = (x[0], x[1])
        try M.check((2...127).contains(nMax) && (0...11).contains(kMax), "n ≤ 127 and k ≤ 11 please.")
        var out = ["Mersenne numbers M_n = 2ⁿ – 1  (n composite ⇒ M_n composite):"]
        for n in 2...nMax {
            let mn = BigUInt(1) << n - BigUInt(1)
            let prime = Primality.isProbablePrime(mn)
            let shown = mn.digitCount() <= 24 ? mn.description : "(\(mn.digitCount()) digits)"
            out.append("  n = \(M.pad(n, 3)): \(shown)  " + (prime ? "prime" : (M.isPrime(n) ? "composite" + (n <= 40 ? " = \(M.pfz(M.factor(Int(mn.uint64Value ?? 0))))" : "") : "composite (n = \(M.pfz(M.factor(n))))")))
        }
        out.append(""); out.append("Fermat numbers F_k = 2^(2^k) + 1:")
        for k in 0...kMax {
            let f = BigUInt(1) << (1 << k) + BigUInt(1)
            let shown = f.digitCount() <= 24 ? f.description : "(\(f.digitCount()) digits)"
            out.append("  k = \(M.pad(k, 2)): \(shown)  " + (Primality.isProbablePrime(f) ? "prime" : "composite") + (k == 5 ? "  = 641 · 6700417 (Euler)" : ""))
        }
        return out.joined(separator: "\n")
    }

    static func fermatTest(_ v: [String]) throws -> String {
        let n = try M.ints([v[0]], labels: ["n"])[0], bases = try M.list(v[1])
        try M.check(n >= 3 && n <= 1_000_000_000_000_000, "3 ≤ n ≤ 10¹⁵ please.")
        var out = ["Fermat test for n = \(n):  If a^(n–1) ≢ 1 mod n, then n is composite (a is a witness)."]
        for a in bases.prefix(12) {
            let g = M.gcd(a, n), r = M.powmod(a, n - 1, n)
            let verdict = g != 1 ? "GCD(a, n) = \(g) – n is composite" : (r != 1 ? "witness ⇒ n is composite" : "passed" + (M.isPrime(n) ? "" : " – n is a pseudo prime to base \(a)!"))
            out.append("  a = \(M.pad(a, 4)):  \(a)^\(n - 1) mod \(n) = \(r)   \(verdict)")
        }
        out.append("")
        out.append("In fact \(n) is " + (M.isPrime(n) ? "prime." : "composite: \(M.pfz(M.factor(n)))."))
        if n <= 200_000 && !M.isPrime(n) {
            let units = (1..<n).filter { M.gcd($0, n) == 1 }
            let liars = units.filter { M.powmod($0, n - 1, n) == 1 }
            out.append("Fermat liars: \(liars.count) of φ(n) = \(units.count) coprime bases"
                       + (liars.count == units.count ? " – all of them! \(n) is a Carmichael number." : (liars.count * 2 <= units.count ? " (at most 50 %)." : ".")))
            if liars.count <= 40 { out.append("Liars: " + M.set(liars)) }
        }
        return out.joined(separator: "\n")
    }

    static func carmichael(_ v: [String]) throws -> String {
        let limit = try M.ints(v, labels: ["Limit"])[0]
        try M.check(limit >= 561 && limit <= 2_000_000, "561 ≤ limit ≤ 2·10⁶ please.")
        var spf = [Int](repeating: 0, count: limit + 1)
        for i in 2...limit where spf[i] == 0 { var j = i; while j <= limit { if spf[j] == 0 { spf[j] = i }; j += i } }
        var out = ["Korselt: n is a Carmichael number ⇔ n composite, squarefree and (p – 1) | (n – 1) for all p | n.", ""]
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
        out.append(""); out.append("\(count) Carmichael numbers ≤ \(limit). Each has at least 3 prime factors.")
        return out.joined(separator: "\n")
    }

    static func millerRabin(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "a"]); let (n, a) = (x[0], x[1])
        try M.check(n >= 5 && n % 2 == 1 && n <= 1_000_000_000_000_000, "Odd n with 5 ≤ n ≤ 10¹⁵ please.")
        try M.check(a >= 2 && a <= n - 2, "Base 2 ≤ a ≤ n – 2 please.")
        var d = n - 1, s = 0
        while d % 2 == 0 { d /= 2; s += 1 }
        var out = ["n – 1 = \(n - 1) = 2\(M.sup(s)) · \(d)   (s = \(s), d = \(d))"]
        if M.gcd(a, n) != 1 { out.append("GCD(\(a), \(n)) = \(M.gcd(a, n)) – lucky, divisor found: n is composite.") ; return out.joined(separator: "\n") }
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
            out.append("n passes the test to base \(a): n is prime or a strong pseudo prime to base \(a).")
            if !M.isPrime(n) { out.append("In fact \(n) = \(M.pfz(M.factor(n))) is composite – \(a) is a strong liar!") }
        } else {
            out.append("\(a) is a (strong) witness: \(n) is composite" + (n < 1_000_000_000_000 ? " (\(M.pfz(M.factor(n))))." : "."))
        }
        if n <= 50_000 && !M.isPrime(n) {
            let liars = (2...(n - 2)).filter { Primality.isStrongProbablePrime(BigUInt(n), base: BigUInt($0)) }
            out.append("Strong liars among 2 … n–2: \(liars.count) of \(n - 3)  (at most 1/4)" + (liars.count <= 30 && !liars.isEmpty ? ": " + M.set(liars) : ""))
        }
        return out.joined(separator: "\n")
    }

    // MARK: Lesson 4

    static func numbers(_ c: [Int]) -> String { c.map { String(format: "%02d", $0) }.joined(separator: " ") }

    static func caesar(_ v: [String]) throws -> String {
        guard let b = M.int(v[1]) else { throw ZTError("Key b must be an integer.") }
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Please enter a text.")
        let c = x.map { M.mod($0 + b, 27) }
        return "Alphabet: space character = 0, A = 1, …, Z = 26  (|alphabet| = 27)\n\n"
            + "Plain text:  \(M.text(x))\n             \(numbers(x))\nE(x) = x + \(b) (mod 27)\n"
            + "             \(numbers(c))\nCipher text: \(M.text(c))\n\nD(x) = x – \(b) (mod 27) yields again: \(M.text(c.map { $0 - b }))"
    }

    static func multiplicative(_ v: [String]) throws -> String {
        let k = try M.ints([v[1], v[2]], labels: ["a", "b"]); let (a, b) = (M.mod(k[0], 27), M.mod(k[1], 27))
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Please enter a text.")
        let c = x.map { M.mod(a * $0 + b, 27) }
        var out = ["E(x) = \(a)·x + \(b) (mod 27)", "Plain text:  \(M.text(x))", "             \(numbers(x))",
                   "             \(numbers(c))", "Cipher text: \(M.text(c))", ""]
        if let ai = M.inverse(a, 27) {
            out.append("GCD(\(a), 27) = 1 ⇒ reversible: a' = \(a)⁻¹ = \(ai) mod 27,  D(x) = \(ai)·(x – \(b)) (mod 27)")
            out.append("Decrypted: \(M.text(c.map { ai * ($0 - b) }))")
        } else {
            out.append("GCD(\(a), 27) = \(M.gcd(a, 27)) ≠ 1 ⇒ NOT reversible – different symbols coincide!")
        }
        out.append("Number of keys: φ(27) · 27 = 18 · 27 = 486")
        return out.joined(separator: "\n")
    }

    static func frequency(_ v: [String]) throws -> String {
        let x = M.codes(v[0])
        try M.check(!x.isEmpty, "Please enter a text.")
        var counts = [Int](repeating: 0, count: 27)
        for c in x { counts[c] += 1 }
        let maxC = counts.max() ?? 1
        let rows = counts.enumerated().filter { $0.element > 0 }.sorted { $0.element > $1.element }.map {
            "  '\(M.alphabet[$0.offset])'  \(M.pad($0.element, 4))  \(String(format: "%5.1f", 100.0 * Double($0.element) / Double(x.count))) %  "
                + String(repeating: "█", count: max(1, 40 * $0.element / maxC))
        }
        return (["\(x.count) symbols; most frequent first:"] + rows
                + ["", "In German the space character and E are the most frequent – with Caesar this reveals the key."]).joined(separator: "\n")
    }

    static func textToNumber(_ v: [String]) throws -> String {
        let x = M.codes(v[0])
        let g = try M.big(v[1])
        try M.check(!x.isEmpty, "Please enter a text.")
        try M.check(g >= BigUInt(27), "The limit G must be ≥ 27.")
        var total = BigUInt(0)
        for c in x { total = total * BigUInt(27) + BigUInt(c) }
        var len = 0, p = BigUInt(27)
        while p <= g { len += 1; p = p * BigUInt(27) }
        len = max(1, len)
        var out = ["Digits (base B = 27): \(numbers(x))",
                   "Text as number: Σ xᵢ·27^(k–i) = \(total)", "",
                   "Block length L = ⌊log₂₇ G⌋ = \(len):"]
        var i = 0
        while i < x.count {
            let blk = Array(x[i..<min(i + len, x.count)])
            var n = BigUInt(0)
            for c in blk { n = n * BigUInt(27) + BigUInt(c) }
            out.append("  \"\(M.text(blk))\" → \(n)")
            i += len
        }
        if x.first == 0 { out.append(""); out.append("Attention: The text begins with a space character (digit 0) – a leading 0 vanishes when the text is read as a number!") }
        return out.joined(separator: "\n")
    }

    static func primeAtLeast(_ x: BigUInt) -> BigUInt { Primality.isProbablePrime(x) ? x : Primality.nextPrime(after: x) }

    static func rsa(_ v: [String]) throws -> String {
        let p0 = try M.big(v[0]), q0 = try M.big(v[1]), b = try M.big(v[2]), n = try M.big(v[3])
        try M.check(p0.digitCount() <= 35 && q0.digitCount() <= 35, "p and q with at most 35 digits (as in NT).")
        let p = primeAtLeast(max(p0, BigUInt(3))), q = primeAtLeast(max(q0, BigUInt(3)))
        try M.check(p != q, "p and q must be different.")
        let m = p * q, ph = (p - BigUInt(1)) * (q - BigUInt(1))
        var out = ["p = \(p)" + (p != p0 ? "   (next prime ≥ \(p0))" : ""), "q = \(q)" + (q != q0 ? "   (next prime ≥ \(q0))" : ""),
                   "RSA-modulus m = p·q = \(m)", "φ(m) = (p–1)·(q–1) = \(ph)", ""]
        guard b.gcd(ph).isOne, let a = b.inverse(modulo: ph) else {
            out.append("GCD(b, φ(m)) = \(b.gcd(ph)) ≠ 1 – b must be coprime to φ(m).")
            return out.joined(separator: "\n")
        }
        out += ["private key b = \(b)", "a = b⁻¹ mod φ(m) = \(a)   (Euclid; a·b ≡ 1 mod φ(m))",
                "public key (m, a) = (\(m), \(a))", ""]
        guard n < m else { out.append("The message n must be less than m."); return out.joined(separator: "\n") }
        let c = n.power(a, modulus: m), back = c.power(b, modulus: m)
        out += ["Sender:    c = n^a mod m = \(c)", "Addressee: c^b mod m = \(back)" + (back == n ? "  = n ✓" : ""),
                n.gcd(m).isOne ? "" : "Note: n is not coprime to m (GCD = \(n.gcd(m)))."]
        return out.joined(separator: "\n")
    }

    static func rabin(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "q", "n"]); let (p, q, n) = (x[0], x[1], x[2])
        try M.check(M.isPrime(p) && M.isPrime(q) && p % 4 == 3 && q % 4 == 3 && p != q && p < 3_000_000 && q < 3_000_000,
                    "p, q different primes ≡ 3 mod 4 (< 3·10⁶) please.")
        let m = p * q
        try M.check(n >= 0 && n < m, "0 ≤ n < m = \(m) please.")
        let c = M.mulmod(n, n, m)
        let rp = M.powmod(c, (p + 1) / 4, p), rq = M.powmod(c, (q + 1) / 4, q)
        let e = M.extGcd(p, q)
        func comb(_ a: Int, _ b: Int) -> Int { M.mod(M.mulmod(M.mulmod(a, q, m), M.mod(e.y, m), m) + M.mulmod(M.mulmod(b, p, m), M.mod(e.x, m), m), m) }
        let roots = [comb(rp, rq), comb(rp, q - rq), comb(p - rp, rq), comb(p - rp, q - rq)].map { M.mod($0, m) }
        return ["Public: m = p·q = \(m);  secret: p = \(p), q = \(q)  (both ≡ 3 mod 4)",
                "Encrypt: c = n² mod m = \(n)² mod \(m) = \(c)", "",
                "Decrypt: square roots mod p and mod q (little Fermat):",
                "  c^((p+1)/4) mod p = \(rp)    c^((q+1)/4) mod q = \(rq)",
                "The Chinese Remainder Theorem yields the four square roots mod m:",
                "  " + roots.map { $0 == n ? "\($0) ⇐ n" : "\($0)" }.joined(separator: ",  "),
                "", "Which of the four is the message, the addressee has to recognize, e.g. by a redundancy."].joined(separator: "\n")
    }

    static func diffieHellman(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "g", "x (Alice)", "y (Bob)"]); let (p, g, a, b) = (x[0], x[1], x[2], x[3])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p must be a prime ≤ 10¹².")
        let A = M.powmod(g, a, p), B = M.powmod(g, b, p)
        var out = ["Public: prime p = \(p), base g = \(g)"]
        if p <= 10_000_000, let o = M.ord(g, p) { out.append("ord(g) = \(o)" + (o == p - 1 ? " – g is a primitive residue class" : " (g is no primitive residue class)")) }
        out += ["Alice: secret x = \(a), sends A = g^x mod p = \(A)", "Bob:   secret y = \(b), sends B = g^y mod p = \(B)",
                "Alice: K = B^x mod p = \(M.powmod(B, a, p))", "Bob:   K = A^y mod p = \(M.powmod(A, b, p))", "",
                "An eavesdropper knows p, g, A, B – for K he would need the discrete logarithm of A or B."]
        return out.joined(separator: "\n")
    }

    static func elgamal(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["p", "g", "b (Alice)", "n", "k (Bob)"]); let (p, g, b, n, k) = (x[0], x[1], x[2], x[3], x[4])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p must be a prime ≤ 10¹².")
        try M.check(n > 0 && n < p, "The message n must be between 1 and p–1.")
        let B = M.powmod(g, b, p), c1 = M.powmod(g, k, p), c2 = M.mulmod(n, M.powmod(B, k, p), p)
        let s = M.powmod(c1, p - 1 - M.mod(b, p - 1), p)
        return ["Alice: secret b = \(b), public (p, g, B = g^b) = (\(p), \(g), \(B))",
                "Bob randomly chooses k = \(k) and sends", "  c₁ = g^k mod p = \(c1)", "  c₂ = n·B^k mod p = \(c2)", "",
                "Alice: c₁^(p–1–b) = (g^k)^(–b) mod p = \(s)   (little Fermat)",
                "       n = c₂ · c₁^(p–1–b) mod p = \(M.mulmod(c2, s, p))",
                "", "Bob should choose a new k for each message."].joined(separator: "\n")
    }

    // MARK: Lesson 5

    static func fermatFactor(_ v: [String]) throws -> String {
        let n = try M.ints(v, labels: ["n"])[0]
        try M.check(n >= 3 && n % 2 == 1 && n <= 1_000_000_000_000_000, "Odd n (3 ≤ n ≤ 10¹⁵) please.")
        var a = M.isqrt(n); if a * a < n { a += 1 }
        var out = ["n = a² – b² = (a + b)(a – b).  Start with a = ⌈√n⌉ = \(a):", ""]
        var steps = 0
        while steps < 2_000_000 {
            let d = a * a - n, b = M.isqrt(d)
            if steps < 20 { out.append("  a = \(a):  a² – n = \(d)" + (b * b == d ? " = \(b)²  ✓" : "  no square")) }
            if b * b == d {
                out += ["", "\(n) = \(a)² – \(b)² = (\(a + b)) · (\(a - b))  after \(steps + 1) steps",
                        a - b == 1 ? "Trivial decomposition – \(n) is prime." : ""]
                return out.joined(separator: "\n")
            }
            a += 1; steps += 1
        }
        out.append("… stopped – the factors are far apart (Fermat only pays off if the factors are close together).")
        return out.joined(separator: "\n")
    }

    static func birthday(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["k", "N"]); let (k, n) = (x[0], x[1])
        try M.check(k >= 1 && k <= 100_000 && n >= 1 && n <= 1_000_000_000, "1 ≤ k ≤ 10⁵, 1 ≤ N ≤ 10⁹ please.")
        func p(_ k: Int) -> Double { var q = 1.0; for i in 0..<k { q *= 1 - Double(i) / Double(n) }; return 1 - q }
        var out = ["Probability that among \(k) random values out of \(n) two are equal:",
                   "P = 1 – (1 – 1/N)(1 – 2/N)···(1 – (k–1)/N) = \(String(format: "%.4f", p(k)))", ""]
        for kk in [Int(Double(n).squareRoot() / 2), Int(Double(n).squareRoot()), Int(1.1774 * Double(n).squareRoot()), 2 * Int(Double(n).squareRoot())] where kk > 0 {
            out.append("  k = \(M.pad(kk, 7)):  P = \(String(format: "%.4f", p(kk)))")
        }
        out.append(""); out.append("Already for k ≈ 1.18·√N is P ≈ 50 % – Pollard's Rho method is based on this.")
        return out.joined(separator: "\n")
    }

    static func rhoSequence(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "x₀", "c"]); let (n, x0, c) = (x[0], x[1], x[2])
        try M.check(n >= 2 && n <= 100_000, "2 ≤ n ≤ 100000 please.")
        func walk(_ m: Int) -> (seq: [Int], mu: Int, lambda: Int) {
            var seen: [Int: Int] = [:], s: [Int] = [], v = M.mod(x0, m)
            while seen[v] == nil { seen[v] = s.count; s.append(v); v = M.mod(v * v + c, m) }
            return (s, seen[v]!, s.count - seen[v]!)
        }
        var out: [String] = []
        let (s, mu, la) = walk(n)
        out.append("xᵢ₊₁ = xᵢ² + \(c) mod \(n):  " + s.prefix(60).map(String.init).joined(separator: ", ") + (s.count > 60 ? ", …" : "") + ", …")
        out.append("Preperiod μ = \(mu), period λ = \(la) – the sequence runs \"in a cycle\" (shape of the letter ρ).")
        if let d = M.factor(n).first?.p, d < n {
            let (t, mu2, la2) = walk(d)
            out.append(""); out.append("The same sequence mod \(d) (prime divisor of n): " + t.map(String.init).joined(separator: ", ") + ", …")
            out.append("μ = \(mu2), λ = \(la2) – the cycle mod \(d) closes much earlier; then \(d) divides the difference xᵢ – xⱼ.")
        }
        func f(_ v: Int) -> Int { M.mod(v * v + c, n) }
        var i = 1, a = f(M.mod(x0, n)), b = f(f(M.mod(x0, n)))
        while a != b && i < 10 * n { a = f(a); b = f(f(b)); i += 1 }
        out.append(""); out.append("Floyd: x_i = x_2i first at i = \(i) (tortoise and hare).")
        return out.joined(separator: "\n")
    }

    static func pollardRho(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["n", "x₀", "c"]); let (n, x0, c) = (x[0], x[1], x[2])
        try M.check(n >= 4 && n <= 1_000_000_000_000_000_000, "4 ≤ n ≤ 10¹⁸ please.")
        if M.isPrime(n) { return "\(n) is prime." }
        func f(_ v: Int) -> Int { M.mod(M.mulmod(v, v, n) + M.mod(c, n), n) }
        var a = M.mod(x0, n), b = a, d = 1, i = 0
        var out = ["f(x) = x² + \(c) mod \(n), Floyd: x = f(x), y = f(f(y)), d = GCD(|x – y|, n)", "",
                   "     i                  x                  y        d"]
        while d == 1 && i < 2_000_000 {
            a = f(a); b = f(f(b)); i += 1
            d = M.gcd(abs(a - b), n)
            if i <= 30 || d != 1 { out.append("\(M.pad(i, 6)) \(M.pad(a, 18)) \(M.pad(b, 18)) \(M.pad(d, 8))") } else if i == 31 { out.append("   …") }
        }
        out.append("")
        if d == 1 { out.append("No divisor after \(i) steps – stopped.") }
        else if d == n { out.append("Failure: d = n. Try other initial values x₀ or c.") }
        else { out.append("Divisor found: \(n) = \(d) · \(n / d)  after \(i) steps") }
        return out.joined(separator: "\n")
    }

    static func pollardPm1(_ v: [String]) throws -> String {
        let n = try M.big(v[0])
        guard let bound = M.int(v[1]), let a0 = M.int(v[2]) else { throw ZTError("B and a must be integers.") }
        try M.check(n > BigUInt(3) && n.digitCount() <= 70, "n with at most 70 digits please (products with * are possible).")
        try M.check(bound >= 2 && bound <= 1_000_000 && a0 >= 2, "2 ≤ B ≤ 10⁶ and a ≥ 2 please.")
        var a = BigUInt(a0) % n
        var out = ["n = \(n)", "k = product of all prime powers pᵉ ≤ B = \(bound);  compute a^k mod n and GCD(a^k – 1, n)", ""]
        let primes = Primality.sieve(upTo: bound)
        var shown = 0
        for p in primes {
            var pe = p
            while pe <= bound / p { pe *= p }
            a = a.power(BigUInt(pe), modulus: n)
            let d = (a == BigUInt(0) ? n : (a + n - BigUInt(1)) % n).gcd(n)
            if shown < 15 { out.append("  pᵉ = \(M.pad(pe, 7)):  GCD(a^k – 1, n) = \(d)"); shown += 1 }
            if !d.isOne {
                out.append("")
                if d == n { out.append("GCD = n – all prime factors caught at once. Decrease B or change a.") }
                else { out.append("Divisor found: \(d)  (p – 1 was \(bound)-smooth).  n = \(d) · \(n / d)") }
                return out.joined(separator: "\n")
            }
        }
        out.append(""); out.append("GCD = 1: For no prime divisor p is p – 1 \(bound)-smooth. Increase B.")
        return out.joined(separator: "\n")
    }

    // MARK: Lesson 6

    static func dlogEnum(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["g", "a", "p"]); let (g, a, p) = (x[0], x[1], x[2])
        try M.check(p >= 3 && p <= 100_000_000, "3 ≤ p ≤ 10⁸ please.")
        var out = ["Wanted: x with \(g)^x ≡ \(a) mod \(p)  (discrete logarithm)", ""]
        var y = 1
        for e in 0..<p {
            if e < 25 { out.append("  \(g)^\(e) ≡ \(y)") } else if e == 25 { out.append("  …") }
            if y == M.mod(a, p) {
                out += ["", "x = \(e)  after \(e + 1) powers (enumeration)", "Check: \(g)^\(e) mod \(p) = \(M.powmod(g, e, p))"]
                return out.joined(separator: "\n")
            }
            y = M.mulmod(y, g, p)
            if y == 1 && e > 0 { break }
        }
        out.append(""); out.append("\(a) is not in ⟨\(g)⟩ – there is no logarithm.")
        return out.joined(separator: "\n")
    }

    static func bsgs(_ v: [String]) throws -> String {
        let x = try M.ints(v, labels: ["g", "a", "p"]); let (g, a, p) = (x[0], x[1], x[2])
        try M.check(M.isPrime(p) && p <= 1_000_000_000_000, "p must be a prime ≤ 10¹².")
        let n = p - 1
        var w = M.isqrt(n); if w * w < n { w += 1 }
        guard let gi = M.inverse(g, p) else { throw ZTError("g must be coprime to p.") }
        var table: [Int: Int] = [:], out = ["n = p – 1 = \(n),  w = ⌈√n⌉ = \(w)", "", "Babysteps (a·g^(–r) mod p, r):"]
        var bstep = M.mod(a, p), line: [String] = []
        for r in 0..<w {
            if table[bstep] == nil { table[bstep] = r }
            if r < 40 { line.append("(\(bstep), \(r))") }
            bstep = M.mulmod(bstep, gi, p)
        }
        out.append("  " + line.joined(separator: " ") + (w > 40 ? " …" : ""))
        if let r = table[1] { out += ["", "Pair (1, \(r)) ⇒ x = \(r)"]; return out.joined(separator: "\n") }
        let d = M.powmod(g, w, p)
        out += ["", "Giantsteps with d = g^w = \(d):"]
        var y = 1
        for q in 1...w {
            y = M.mulmod(y, d, p)
            if q <= 20 { out.append("  q = \(q): d^q = \(y)" + (table[y] != nil ? "  ✓ in B" : "")) }
            if let r = table[y] {
                let xx = q * w + r
                out += ["", "x = q·w + r = \(q)·\(w) + \(r) = \(xx)", "Check: \(g)^\(xx) mod \(p) = \(M.powmod(g, xx, p))"]
                return out.joined(separator: "\n")
            }
        }
        out.append(""); out.append("No hit – \(a) is not in ⟨\(g)⟩.")
        return out.joined(separator: "\n")
    }
}
