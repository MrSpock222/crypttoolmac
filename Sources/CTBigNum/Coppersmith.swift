import Foundation

/// Nullstellensuche nach Coppersmith/Howgrave-Graham und die darauf aufbauenden
/// gitterbasierten RSA-Angriffe von CrypTool 1.
///
/// Alle drei Verfahren formen ihr Problem in die Suche nach einer **kleinen** Nullstelle x₀
/// eines Polynoms f mit f(x₀) ≡ 0 (mod b) um und finden diese mit [`Lattice.reduce`]:
///
/// * `stereotypedMessage` – f(x) = (m_b + x)^e − c  (mod N), kleiner öffentlicher Exponent e
/// * `factorWithKnownBits` – f(x) = P + x  (mod p), p teilt N  (Boneh/Durfee/Howgrave-Graham)
/// * `wienerSmallSecretKey` – kleiner geheimer Exponent d über Kettenbruchentwicklung
///
/// Die Howgrave-Graham-Konstruktion baut aus f die Hilfspolynome
/// N^{m−i}·x^j·f(x)^i und x^j·f(x)^m, reduziert deren mit X skalierte Koeffizienten­vektoren
/// per LLL und liest aus dem kürzesten Vektor ein Polynom h mit ganzzahliger Nullstelle x₀ ab.
public enum Coppersmith {

    // MARK: - Öffentliche Angriffe

    /// Ergebnis eines gitterbasierten Angriffs mit Laufzeit-Kennzahlen (für die Dialoge).
    public struct Result<Value> {
        public var value: Value
        public var latticeDimension: Int
        public var reductions: Int
    }

    /// Angriff auf stereotype Nachrichten: Aus Chiffrat `c`, Modulus `N`, kleinem Exponenten `e`
    /// und dem bekannten Nachrichtenteil `known` (die vollständige Nachricht, bei der die
    /// unbekannten Stellen auf 0 gesetzt sind) wird der unbekannte Teil x₀ < `bound` bestimmt.
    /// Rückgabe: die vollständige Nachricht m mit m^e ≡ c (mod N).
    /// `shift` ist der Stellenwert des unbekannten Blocks: m = known + shift·x₀ mit x₀ < `bound`
    /// (für einen unbekannten Teil am Ende der Nachricht ist shift = 1).
    public static func stereotypedMessage(n: BigUInt, e: Int, cipher c: BigUInt,
                                          known: BigUInt, bound: BigUInt, shift: BigUInt = BigUInt(1),
                                          latticeParameter h: Int = 0) -> BigUInt? {
        let N = BigInt(n)
        // f(x) = (known + shift·x)^e − c, Koeffizienten mod N; anschließend monisch machen.
        var f = polyPow(poly: [BigInt(known), BigInt(shift)], exponent: e, mod: n)
        f[0] = (f[0] - BigInt(c)).modulo(n).asBigInt
        // Leitkoeffizient ist shift^e; mit dessen Inversem multiplizieren ⇒ monisch.
        let lead = f[e].modulo(n)
        guard let invLead = lead.inverse(modulo: n) else { return nil }
        f = f.map { BigInt(($0.modulo(n) * invLead) % n) }
        let X = BigInt(bound)
        let m = h > 0 ? h : max(2, (e + 1) / 2 + 1)
        let t = e
        for root in smallRoots(f: f, modulus: N, bound: X, m: m, t: t) {
            if root.signum >= 0 {
                let cand = (known + shift * root.magnitude) % n
                if cand.power(e, modulus: n) == c { return cand }
            }
        }
        return nil
    }

    /// Faktorisieren mit teilweise bekanntem p. `known` ist der bekannte Teil P von p,
    /// `pBits` die Bitlänge von p, `unknownBits` die Anzahl der unbekannten Bits.
    /// Bei `highBits == true` sind die höchstwertigen Bits bekannt (p = P + x₀,
    /// x₀ < 2^unknownBits), sonst die niederstwertigen (p = x₀·2^s + P mit s = pBits − unknownBits).
    /// Rückgabe: ein echter Teiler p von N (p·q = N) oder nil.
    public static func factorWithKnownBits(n: BigUInt, known P: BigUInt, pBits: Int, unknownBits: Int,
                                           highBits: Bool, latticeParameter h: Int = 0) -> (p: BigUInt, q: BigUInt)? {
        let N = BigInt(n)
        let X = BigInt(BigUInt(1) << unknownBits)
        let shiftBits = max(0, pBits - unknownBits)        // Anzahl bekannter Bits (LSB-Fall)
        let f: [BigInt]
        if highBits {
            // p = P + x₀,  0 ≤ x₀ < 2^unknownBits
            f = [BigInt(P), BigInt(1)]
        } else {
            // p = x₀·2^s + P  ⇒  f(x) = x + P·(2^s)^{-1}  (monisch), x₀ = (p − P)/2^s
            let shift = BigUInt(1) << shiftBits
            guard let inv = shift.inverse(modulo: n) else { return nil }
            f = [BigInt((P * inv) % n), BigInt(1)]
        }
        let m = h > 0 ? h : 6
        let t = m
        for root in smallRoots(f: f, modulus: N, bound: X, m: m, t: t) {
            let p: BigUInt
            if highBits {
                let cand = BigInt(P) + root
                guard cand.signum > 0, let u = BigUInt(cand) else { continue }
                p = u
            } else {
                guard root.signum >= 0 else { continue }
                p = root.magnitude * (BigUInt(1) << shiftBits) + P
            }
            if !p.isZero && p != BigUInt(1) && n % p == BigUInt(0) {
                return (p, n / p)
            }
        }
        return nil
    }

    /// Angriff auf kleine geheime Schlüssel über Wiener-Kettenbrüche (sicher für δ < 0,25,
    /// also d < N^{1/4}). Rückgabe: geheimer Exponent d und die Faktoren p, q.
    public static func wienerSmallSecretKey(n: BigUInt, e: BigUInt) -> (d: BigUInt, p: BigUInt, q: BigUInt)? {
        // Kettenbruchentwicklung von e/N, Konvergenten k/d testen.
        var num = e, den = n
        var hPrev2 = BigUInt(0), hPrev1 = BigUInt(1)   // Zähler der Konvergenten (= k)
        var kPrev2 = BigUInt(1), kPrev1 = BigUInt(0)   // Nenner der Konvergenten (= d)
        while !den.isZero {
            let a = num / den
            let h = a * hPrev1 + hPrev2
            let kk = a * kPrev1 + kPrev2
            (num, den) = (den, num - a * den)
            (hPrev2, hPrev1) = (hPrev1, h)
            (kPrev2, kPrev1) = (kPrev1, kk)

            let kGuess = h       // Zähler ≙ k
            let dGuess = kk      // Nenner ≙ d
            if kGuess.isZero || dGuess.isZero { continue }
            // φ(N) = (e·d − 1) / k
            let ed1 = e * dGuess - BigUInt(1)
            if ed1 % kGuess != BigUInt(0) { continue }
            let phi = ed1 / kGuess
            if phi >= n { continue }
            // p + q = N − φ + 1,  p·q = N
            let s = n - phi + BigUInt(1)                       // = p + q
            let disc = s * s                                    // s² − 4N
            let fourN = BigUInt(4) * n
            if disc < fourN { continue }
            let d2 = disc - fourN
            let r = d2.squareRoot()
            if r * r != d2 { continue }
            if (s + r).isEven == false { continue }
            let p = (s + r) / BigUInt(2)
            let q = (s - r) / BigUInt(2)
            if !p.isZero && p * q == n { return (dGuess, p, q) }
        }
        return nil
    }

    // MARK: - Howgrave-Graham-Kern

    /// Kleine ganzzahlige Nullstellen x₀ (|x₀| ≤ `bound`) eines monischen Polynoms `f`
    /// mit f(x₀) ≡ 0 (mod b) für einen Teiler b von `modulus`. `m`, `t` steuern die Gittergröße.
    static func smallRoots(f: [BigInt], modulus N: BigInt, bound X: BigInt, m: Int, t: Int) -> [BigInt] {
        let d = f.count - 1
        guard d >= 1, X.signum > 0 else { return [] }
        let dim = d * m + t

        // Hilfspolynome g in aufsteigendem Leitgrad: N^{m-i}·x^j·f^i und x^j·f^m.
        var polys: [[BigInt]] = []
        for i in 0..<m {
            let fi = polyPow(poly: f, exponent: i)                 // über Z (klein genug)
            let scale = powBig(N, m - i)
            for j in 0..<d {
                polys.append(shift(scalarMul(fi, scale), by: j))
            }
        }
        let fm = polyPow(poly: f, exponent: m)
        for j in 0..<t { polys.append(shift(fm, by: j)) }

        // Gitterbasis: Zeile r = Koeffizienten von g_r(x·X).
        var basis = [[BigInt]](repeating: [BigInt](repeating: BigInt(0), count: dim), count: dim)
        for r in 0..<dim {
            let g = polys[r]
            var xc = BigInt(1)
            for c in 0..<dim {
                if c < g.count { basis[r][c] = g[c] * xc }
                xc = xc * X
            }
        }

        let reduced = Lattice.reduce(basis)

        // Aus den reduzierten Vektoren je ein Polynom h ablesen und ganzzahlige Nullstellen prüfen.
        var found: [BigInt] = []
        for r in 0..<reduced.count {
            let row = reduced[r]
            var hpoly = [BigInt](repeating: BigInt(0), count: dim)
            var xc = BigInt(1)
            var ok = true
            for c in 0..<dim {
                if row[c].isZero { hpoly[c] = BigInt(0) }
                else {
                    let (q, rem) = row[c].quotientAndRemainder(dividingBy: xc)
                    if !rem.isZero { ok = false; break }
                    hpoly[c] = q
                }
                xc = xc * X
            }
            guard ok else { continue }
            for root in integerRoots(exact: hpoly, scaled: row, bound: X) where !found.contains(root) {
                found.append(root)
            }
        }
        return found
    }

    // MARK: - Polynom-Hilfsfunktionen (Koeffizient i ≙ x^i)

    static func trim(_ a: [BigInt]) -> [BigInt] {
        var r = a
        while r.count > 1 && r.last!.isZero { r.removeLast() }
        return r
    }

    static func scalarMul(_ a: [BigInt], _ s: BigInt) -> [BigInt] { a.map { $0 * s } }

    static func shift(_ a: [BigInt], by j: Int) -> [BigInt] {
        guard j > 0 else { return a }
        return [BigInt](repeating: BigInt(0), count: j) + a
    }

    static func polyMul(_ a: [BigInt], _ b: [BigInt], mod n: BigUInt? = nil) -> [BigInt] {
        var r = [BigInt](repeating: BigInt(0), count: a.count + b.count - 1)
        for i in 0..<a.count where !a[i].isZero {
            for j in 0..<b.count where !b[j].isZero {
                r[i + j] = r[i + j] + a[i] * b[j]
            }
        }
        if let n { r = r.map { BigInt($0.modulo(n)) } }
        return r
    }

    static func polyPow(poly a: [BigInt], exponent e: Int, mod n: BigUInt? = nil) -> [BigInt] {
        var result: [BigInt] = [BigInt(1)]
        var base = a
        var ex = e
        while ex > 0 {
            if ex & 1 == 1 { result = polyMul(result, base, mod: n) }
            ex >>= 1
            if ex > 0 { base = polyMul(base, base, mod: n) }
        }
        return result
    }

    static func powBig(_ a: BigInt, _ e: Int) -> BigInt { a.power(e) }

    static func evalBig(_ a: [BigInt], _ x: BigInt) -> BigInt {
        var r = BigInt(0)
        for c in stride(from: a.count - 1, through: 0, by: -1) { r = r * x + a[c] }
        return r
    }

    // MARK: - Ganzzahlige Nullstellen eines Polynoms (|Wurzel| ≤ bound)

    /// `exact` ist h (coeffs i ≙ x^i), `scaled` sind die LLL-Zeileneinträge, also zugleich die
    /// Koeffizienten von H(y) = h(X·y). Dessen Nullstellen y₀ = x₀/X liegen in [−1, 1] und sind
    /// numerisch gutartig; sie liefern die Startpunkte für die exakte Suche auf h.
    static func integerRoots(exact h: [BigInt], scaled row: [BigInt], bound X: BigInt) -> [BigInt] {
        let a = trim(h)
        let deg = a.count - 1
        guard deg >= 1 else { return [] }
        var roots: [BigInt] = []

        func consider(_ cand: BigInt) {
            if cand.absoluteValue <= X && evalBig(a, cand).isZero && !roots.contains(cand) {
                roots.append(cand)
            }
        }

        if deg == 1 {
            // a1·x + a0 = 0
            let (q, r) = (-a[0]).quotientAndRemainder(dividingBy: a[1])
            if r.isZero { consider(q) }
            return roots
        }

        // Startpunkte: Nullstellen von H(y) in [−1,1] (auf x = X·y abgebildet) sowie ein
        // gleichmäßiges Raster über [−X, X]. Von jedem Startpunkt aus wird exakt verfeinert;
        // das Raster stellt sicher, dass kein Vorzeichenwechsel übersehen wird.
        var seeds: [BigInt] = [BigInt(0)]
        for y in DurandKerner.realRoots(trim(row)) where y.isFinite && abs(y) <= 1.2 {
            seeds.append(scaleUnit(X, by: y))
        }
        let grid = 64
        for k in 0...grid {
            seeds.append((BigInt(2) * X * BigInt(k)).floorDivided(by: BigInt(grid)) - X)
        }
        for seed in seeds {
            if let root = refineRoot(a, seed: seed, bound: X) { consider(root) }
        }
        return roots
    }

    /// round(X · y) für y ∈ [−1,1], exakt über eine 2⁵²-Festkomma-Näherung von y.
    static func scaleUnit(_ X: BigInt, by y: Double) -> BigInt {
        let unit = 4_503_599_627_370_496.0   // 2^52
        let num = BigInt(Int((y * unit).rounded()))
        return (X * num).floorDivided(by: BigInt(BigUInt(1) << 52))
    }

    /// Exakte ganzzahlige Nullstelle nahe `seed` per Vorzeichenwechsel-Suche und Bisektion.
    static func refineRoot(_ a: [BigInt], seed: BigInt, bound X: BigInt) -> BigInt? {
        func f(_ x: BigInt) -> BigInt { evalBig(a, x) }
        if f(seed).isZero { return seed }

        var lo = seed, hi = seed
        var flo = f(lo), fhi = f(hi)
        var step = BigInt(1)
        for _ in 0..<300 {
            var nlo = lo - step, nhi = hi + step
            if nlo < -X { nlo = -X }
            if nhi > X { nhi = X }
            let fnlo = f(nlo), fnhi = f(nhi)
            if fnlo.isZero { return nlo }
            if fnhi.isZero { return nhi }
            if fnlo.signum != flo.signum { return bisect(f, nlo, fnlo, lo, flo) }
            if fnhi.signum != fhi.signum { return bisect(f, hi, fhi, nhi, fnhi) }
            lo = nlo; flo = fnlo; hi = nhi; fhi = fnhi
            step = step * 2
            if lo == -X && hi == X { break }
        }
        return nil
    }

    /// Bisektion auf [lo, hi] mit sign(f(lo)) ≠ sign(f(hi)).
    private static func bisect(_ f: (BigInt) -> BigInt, _ lo0: BigInt, _ flo0: BigInt, _ hi0: BigInt, _ fhi0: BigInt) -> BigInt? {
        var lo = lo0, hi = hi0, flo = flo0
        while hi - lo > BigInt(1) {
            let mid = (lo + hi).floorDivided(by: BigInt(2))
            let fm = f(mid)
            if fm.isZero { return mid }
            if fm.signum == flo.signum { lo = mid; flo = fm } else { hi = mid }
        }
        if f(lo).isZero { return lo }
        if f(hi).isZero { return hi }
        return nil
    }

    /// Ganzzahl-Näherung eines (auch sehr großen) Double-Wertes.
    static func bigIntFromDouble(_ v: Double) -> BigInt {
        guard v.isFinite, v != 0 else { return BigInt(0) }
        let neg = v < 0
        let av = abs(v).rounded()
        if av < 9.0e18 { return BigInt(neg ? -Int(av) : Int(av)) }
        let e = max(0, Int(floor(log2(av))) - 52)
        let f = (av / pow(2.0, Double(e))).rounded()
        var r = BigInt(BigUInt(Int(f)) << e)
        if neg { r = -r }
        return r
    }

    /// Ganzzahlige Nullstellen eines Polynoms (|Wurzel| ≤ bound) ohne skalierte Zeile:
    /// Startpunkte aus Durand-Kerner und einem Raster, exakte Verfeinerung per Bisektion.
    static func integerRoots(_ h: [BigInt], bound X: BigInt) -> [BigInt] {
        let a = trim(h)
        guard a.count >= 2 else { return [] }
        var roots: [BigInt] = []
        func consider(_ c: BigInt) {
            if c.absoluteValue <= X && evalBig(a, c).isZero && !roots.contains(c) { roots.append(c) }
        }
        if a.count == 2 {
            let (q, r) = (-a[0]).quotientAndRemainder(dividingBy: a[1])
            if r.isZero { consider(q) }
            return roots
        }
        var seeds: [BigInt] = [BigInt(0)]
        for y in DurandKerner.realRoots(a) where y.isFinite { seeds.append(bigIntFromDouble(y)) }
        let grid = 128
        for k in 0...grid {
            seeds.append((BigInt(2) * X * BigInt(k)).floorDivided(by: BigInt(grid)) - X)
        }
        for seed in seeds {
            if let r = refineRoot(a, seed: seed, bound: X) { consider(r) }
        }
        return roots
    }

    /// Näherung von x / 2^scaleBits als Double (für die numerische Nullstellensuche).
    static func approxDouble(_ x: BigInt, scaleBits: Int) -> Double {
        let mag = x.magnitude
        let bl = mag.bitLength
        if bl == 0 { return 0 }
        let keep = 52
        let sh = max(0, bl - keep)
        let top = Double((mag >> sh).low64)
        var v = top * pow(2.0, Double(sh - scaleBits))
        if x.isNegative { v = -v }
        return v
    }
}

private extension BigUInt {
    var asBigInt: BigInt { BigInt(self) }
}
