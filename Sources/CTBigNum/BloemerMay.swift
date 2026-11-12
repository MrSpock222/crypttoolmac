import Foundation

/// Angriff auf kleine geheime RSA-Exponenten nach Boneh/Durfee bzw. Blömer/May
/// (Gitterverfahren, δ = log(d)/log(N) < 0,292), portiert aus CrypTool 1
/// (`BloemerMayAttack.cpp`, `ZZXY.cpp`).
///
/// Aus e·d ≡ 1 (mod φ(N)) folgt k·(A − (p+q)) + 1 ≡ 0 (mod e) mit A = N+1. Das bivariate
/// Polynom f(x,y) = 1 + A·x + x·y hat die kleine Nullstelle (x,y) = (k, −(p+q)). Über
/// Verschiebungspolynome x^i·f^k·e^{m−k} und y^j·f^k·e^{m−k} wird ein Gitter gebildet, per LLL
/// reduziert; aus zwei kurzen Vektoren entsteht über die **Resultante** ein Polynom in y, dessen
/// ganzzahlige Nullstelle p+q liefert. Daraus ergeben sich p und q.
public enum BloemerMay {

    public struct Result: Sendable {
        public let p: BigUInt
        public let q: BigUInt
        public let d: BigUInt
        public let latticeDimension: Int
    }

    /// Führt den Angriff aus. `delta` ist die geschätzte Größe von d, `m`/`t` die Gitterparameter
    /// (t aus m optimal, siehe `optimalT`). Rückgabe: p, q, d oder nil.
    public static func attack(n N: BigUInt, e: BigUInt, delta: Double, m: Int, t: Int) -> Result? {
        let A = BigInt(N) + BigInt(1)
        // Schranken wie in CT1: X = e^δ, Y = 3·√N (≈ 3·√e)
        let X = BigInt(BigUInt(1) << max(1, Int((delta * Double(e.bitLength)).rounded())))
        let Y = BigInt(BigUInt(3) * N.squareRoot())

        // f(x,y) = 1 + A·x + x·y
        var f = BivPoly()
        f[Mono(1, 0)] = A
        f[Mono(1, 1)] = BigInt(1)
        f[Mono(0, 0)] = BigInt(1)

        // Verschiebungspolynome
        let eBig = BigInt(e)
        var shifts: [BivPoly] = []
        var fpow: [BivPoly] = [BivPoly(constant: 1)]
        for _ in 1...max(1, m) { fpow.append(fpow.last! * f) }
        for k in 0...m {
            let fk = fpow[k]
            let emk = eBig.power(m - k)
            for i in 0...(m - k) {
                shifts.append((fk * Mono(i, 0)).scaled(emk))           // x^i · f^k · e^{m-k}
            }
        }
        for k in 0...m {
            let fk = fpow[k]
            let emk = eBig.power(m - k)
            if t >= 1 {
                for j in 1...t {
                    shifts.append((fk * Mono(0, j)).scaled(emk))       // y^j · f^k · e^{m-k}
                }
            }
        }

        // Monombasis
        var monoSet = Set<Mono>()
        for g in shifts { for k in g.coeffs.keys { monoSet.insert(k) } }
        let monos = monoSet.sorted { ($0.x + $0.y, $0.y, $0.x) < ($1.x + $1.y, $1.y, $1.x) }
        let dim = monos.count

        // Gitterbasis: Zeile = Koeffizienten von g(x·X, y·Y)
        var basis = [[BigInt]](repeating: [BigInt](repeating: BigInt(0), count: dim), count: shifts.count)
        for (r, g) in shifts.enumerated() {
            for (c, mo) in monos.enumerated() {
                if let v = g.coeffs[mo] { basis[r][c] = v * X.power(mo.x) * Y.power(mo.y) }
            }
        }

        let reduced = Lattice.reduce(basis, deltaNum: 99, deltaDen: 100)

        // reduzierte Vektoren → bivariate Polynome (Koeffizient / X^x·Y^y)
        var polys: [(norm: BigInt, poly: BivPoly)] = []
        for row in reduced {
            var p = BivPoly()
            var norm = BigInt(0)
            var ok = true
            for (c, mo) in monos.enumerated() {
                let v = row[c]
                norm = norm + v * v
                if v.isZero { continue }
                let sc = X.power(mo.x) * Y.power(mo.y)
                let (q, rem) = v.quotientAndRemainder(dividingBy: sc)
                if !rem.isZero { ok = false; break }
                p[mo] = q
            }
            if ok && !p.coeffs.isEmpty { polys.append((norm, p)) }
        }
        polys.sort { $0.norm < $1.norm }

        let searchBound = BigInt(BigUInt(4) * N.squareRoot())

        func solveFromSum(_ yRoot: BigInt) -> Result? {
            // y = −(p+q)  ⇒  s = p+q = −yRoot
            let s = -yRoot
            guard s.signum > 0, let sU = BigUInt(s) else { return nil }
            let disc = s * s - BigInt(4) * BigInt(N)
            guard disc.signum >= 0, let discU = BigUInt(disc) else { return nil }
            let r = discU.squareRoot()
            if r * r != discU { return nil }
            guard (sU + r).isEven else { return nil }
            let p = (sU + r) / BigUInt(2)
            let q = (sU - r) / BigUInt(2)
            if !p.isZero && p * q == N {
                let lambda = lcm(p - BigUInt(1), q - BigUInt(1))
                let d = e.inverse(modulo: lambda) ?? BigUInt(0)
                return Result(p: max(p, q), q: min(p, q), d: d, latticeDimension: dim)
            }
            return nil
        }

        let limit = min(polys.count, 8)
        // Ein bereits univariates Polynom in y (x-Grad 0) direkt prüfen.
        for i in 0..<limit {
            if polys[i].poly.xDegree == 0 {
                let uni = polys[i].poly.asYPolynomial()
                for root in Coppersmith.integerRoots(uni, bound: searchBound) {
                    if let res = solveFromSum(root) { return res }
                }
            }
        }
        // Paare: Resultante bzgl. x → Polynom in y → Nullstellen.
        for j in 1..<max(1, limit) {
            for i in 0..<j {
                let res = BivPoly.resultantX(polys[i].poly, polys[j].poly)
                let uni = Coppersmith.trim(res)
                if uni.count <= 1 { continue }
                for root in Coppersmith.integerRoots(uni, bound: searchBound) {
                    if let r = solveFromSum(root) { return r }
                }
            }
        }
        return nil
    }

    /// CT1 `optimalT`: zu m das t, das den abgedeckten δ-Bereich maximiert.
    public static func optimalT(_ m: Int) -> Int {
        let mm = Double(m)
        var d = 3 * mm * (2 * mm + 1) * (mm + 1) * (mm + 1)
        d = 6 * d.squareRoot()
        d = d - 6 * mm * mm - 12 * mm - 2
        d = d / (30 * mm * mm + 36 * mm - 2)
        let inner = -36*d*d*mm*mm - 36*d*mm + 3 + 12*d*d - 36*d*d*mm - 18*d*mm*mm - 6*d + 9*mm*mm + 9*mm
        guard inner >= 0 else { return 2 }
        var tt = inner.squareRoot()
        tt = 12 * d * mm - 6 + 2 * tt
        tt = tt / (12 * d + 6)
        return tt > 2 ? Int(tt) : 2
    }
}

// MARK: - Monom und bivariates Polynom

struct Mono: Hashable {
    let x: Int
    let y: Int
    init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
}

struct BivPoly {
    var coeffs: [Mono: BigInt] = [:]

    init() {}
    init(constant c: BigInt) { if !c.isZero { coeffs[Mono(0, 0)] = c } }

    subscript(_ m: Mono) -> BigInt {
        get { coeffs[m] ?? BigInt(0) }
        set { if newValue.isZero { coeffs[m] = nil } else { coeffs[m] = newValue } }
    }

    var xDegree: Int { coeffs.keys.map { $0.x }.max() ?? 0 }
    var yDegree: Int { coeffs.keys.map { $0.y }.max() ?? 0 }

    static func * (a: BivPoly, b: BivPoly) -> BivPoly {
        var r = BivPoly()
        for (ma, va) in a.coeffs {
            for (mb, vb) in b.coeffs {
                let m = Mono(ma.x + mb.x, ma.y + mb.y)
                r[m] = r[m] + va * vb
            }
        }
        return r
    }

    /// Multiplikation mit einem Monom x^m.x · y^m.y.
    static func * (a: BivPoly, m: Mono) -> BivPoly {
        var r = BivPoly()
        for (k, v) in a.coeffs { r.coeffs[Mono(k.x + m.x, k.y + m.y)] = v }
        return r
    }

    func scaled(_ s: BigInt) -> BivPoly {
        var r = BivPoly()
        for (k, v) in coeffs { r.coeffs[k] = v * s }
        return r
    }

    /// Nur gültig für x-Grad 0: Koeffizienten als Polynom in y (Index = y-Grad).
    func asYPolynomial() -> [BigInt] {
        let dy = yDegree
        var out = [BigInt](repeating: BigInt(0), count: dy + 1)
        for (k, v) in coeffs { out[k.y] = v }
        return out
    }

    /// Koeffizienten nach x-Grad gruppiert; jedes Element ein Polynom in y (Index = y-Grad).
    func xCoefficients() -> [[BigInt]] {
        let dx = xDegree, dy = yDegree
        var out = [[BigInt]](repeating: [BigInt](repeating: BigInt(0), count: dy + 1), count: dx + 1)
        for (k, v) in coeffs { out[k.x][k.y] = v }
        return out.map { Coppersmith.trim($0) }
    }

    /// Resultante von f und g bezüglich x (Elimination von x) als Polynom in y.
    /// Sylvester-Matrix mit Einträgen aus ℤ[y], Determinante bruchfrei (Bareiss).
    static func resultantX(_ f: BivPoly, _ g: BivPoly) -> [BigInt] {
        let fc = f.xCoefficients()   // fc[i] = Koeffizient von x^i (Polynom in y)
        let gc = g.xCoefficients()
        let df = fc.count - 1, dg = gc.count - 1
        guard df >= 1, dg >= 1 else { return [] }
        let n = df + dg
        // Sylvester-Matrix (n×n), Einträge sind y-Polynome.
        var M = [[[BigInt]]](repeating: [[BigInt]](repeating: [BigInt(0)], count: n), count: n)
        for i in 0..<dg {
            for j in 0...df { M[i][i + j] = fc[df - j] }
        }
        for i in 0..<df {
            for j in 0...dg { M[dg + i][i + j] = gc[dg - j] }
        }
        return PolyMatrix.bareissDet(&M)
    }
}

// MARK: - Hilfsfunktionen über ℤ[y]

enum PolyMatrix {
    /// Bruchfreie Determinante (Bareiss) einer Matrix mit Polynom-Einträgen (ℤ[y]).
    static func bareissDet(_ M: inout [[[BigInt]]]) -> [BigInt] {
        let n = M.count
        if n == 0 { return [BigInt(1)] }
        var sign = 1
        var prev: [BigInt] = [BigInt(1)]
        for k in 0..<(n - 1) {
            if isZero(M[k][k]) {
                guard let sw = (k+1..<n).first(where: { !isZero(M[$0][k]) }) else { return [BigInt(0)] }
                M.swapAt(k, sw); sign = -sign
            }
            for i in (k + 1)..<n {
                for j in (k + 1)..<n {
                    let num = sub(mul(M[i][j], M[k][k]), mul(M[i][k], M[k][j]))
                    M[i][j] = divExact(num, prev)
                }
            }
            prev = M[k][k]
        }
        let det = M[n - 1][n - 1]
        return sign < 0 ? det.map { -$0 } : det
    }

    static func isZero(_ p: [BigInt]) -> Bool { p.allSatisfy { $0.isZero } }

    static func mul(_ a: [BigInt], _ b: [BigInt]) -> [BigInt] { Coppersmith.polyMul(a, b) }

    static func sub(_ a: [BigInt], _ b: [BigInt]) -> [BigInt] {
        let n = max(a.count, b.count)
        var r = [BigInt](repeating: BigInt(0), count: n)
        for i in 0..<n { r[i] = (i < a.count ? a[i] : BigInt(0)) - (i < b.count ? b[i] : BigInt(0)) }
        return Coppersmith.trim(r)
    }

    /// Exakte Polynomdivision a / b (Rest ist in Bareiss garantiert 0).
    static func divExact(_ a: [BigInt], _ b: [BigInt]) -> [BigInt] {
        let bb = Coppersmith.trim(b)
        if bb.count == 1 {
            if bb[0] == BigInt(1) { return a }
            if bb[0] == BigInt(-1) { return a.map { -$0 } }
            return a.map { $0 / bb[0] }
        }
        var rem = Coppersmith.trim(a)
        let dideg = bb.count - 1
        let lead = bb[dideg]
        var quot = [BigInt](repeating: BigInt(0), count: max(1, rem.count - dideg))
        while rem.count - 1 >= dideg && !isZero(rem) {
            let deg = rem.count - 1
            let coeff = rem[deg] / lead
            quot[deg - dideg] = coeff
            for i in 0...dideg { rem[deg - dideg + i] = rem[deg - dideg + i] - coeff * bb[i] }
            rem = Coppersmith.trim(rem)
        }
        return Coppersmith.trim(quot)
    }
}

// MARK: - ggT/kgV auf BigUInt

func lcm(_ a: BigUInt, _ b: BigUInt) -> BigUInt {
    if a.isZero || b.isZero { return BigUInt(0) }
    return a / a.gcd(b) * b
}
