import Foundation

/// Gitterreduktion nach LLL (Lenstra–Lenstra–Lovász), exakte Ganzzahl-Variante.
///
/// Grundlage der drei gitterbasierten RSA-Angriffe von CrypTool 1
/// (Faktorisieren mit teilweise bekanntem p, Angriff auf stereotype Nachrichten,
/// Angriff auf kleine geheime Schlüssel). Die Implementierung folgt
/// H. Cohen, *A Course in Computational Algebraic Number Theory*, Algorithmus 2.6.7
/// ("integer LLL"): sämtliche Zwischenwerte bleiben ganzzahlig, es wird nicht mit
/// Gleitkomma gerechnet, das Ergebnis ist also exakt und reproduzierbar.
public enum Lattice {

    /// LLL-reduziert die Zeilen von `basis` (jede Zeile ein Gittervektor). Der Parameter δ
    /// (`deltaNum/deltaDen`, Standard 3/4) steuert die Reduktionsqualität; Werte nahe 1
    /// (z. B. 99/100) liefern kürzere Vektoren und werden für Coppersmith/Boneh-Durfee benötigt.
    /// Die Vektoren müssen linear unabhängig sein.
    public static func reduce(_ basis: [[BigInt]], deltaNum: Int = 3, deltaDen: Int = 4) -> [[BigInt]] {
        let n = basis.count
        guard n > 0 else { return basis }
        let dim = basis[0].count

        // 1-basierte Ablage (Index 0 bleibt ungenutzt), wie in Cohen 2.6.7.
        var b = [[BigInt]](repeating: [], count: n + 1)
        for i in 1...n { b[i] = basis[i - 1] }

        var d = [BigInt](repeating: BigInt(0), count: n + 1)   // d[0..n]
        d[0] = BigInt(1)
        var lambda = [[BigInt]](repeating: [BigInt](repeating: BigInt(0), count: n + 1), count: n + 1)

        func dot(_ x: [BigInt], _ y: [BigInt]) -> BigInt {
            var s = BigInt(0)
            for k in 0..<dim { s += x[k] * y[k] }
            return s
        }

        // round(a / m) für m > 0, Rundung der Hälfte aufwärts.
        func nearest(_ a: BigInt, _ m: BigInt) -> BigInt {
            (BigInt(2) * a + m).floorDivided(by: BigInt(2) * m)
        }

        func reduceStep(_ k: Int, _ l: Int) {
            // |2·λ[k][l]| ≤ d[l]  ⇒  nichts zu tun
            if (BigInt(2) * lambda[k][l].absoluteValue) <= d[l] { return }
            let q = nearest(lambda[k][l], d[l])
            for t in 0..<dim { b[k][t] = b[k][t] - q * b[l][t] }
            lambda[k][l] = lambda[k][l] - q * d[l]
            if l >= 2 {
                for i in 1...(l - 1) { lambda[k][i] = lambda[k][i] - q * lambda[l][i] }
            }
        }

        var kMax = 1
        d[1] = dot(b[1], b[1])

        var k = 2
        while k <= n {
            // --- Schritt 2: inkrementelle Gram-Schmidt-Orthogonalisierung ---
            if k > kMax {
                kMax = k
                for j in 1...k {
                    var u = dot(b[k], b[j])
                    if j >= 2 {
                        for i in 1...(j - 1) {
                            u = (d[i] * u - lambda[k][i] * lambda[j][i]) / d[i - 1]
                        }
                    }
                    if j < k { lambda[k][j] = u } else { d[k] = u }
                }
            }

            // --- Schritt 3: Lovász-Bedingung testen ---
            reduceStep(k, k - 1)
            // δd·d_k·d_{k-2} < δn·d_{k-1}² − δd·λ²   (δ = deltaNum/deltaDen)
            let dn = BigInt(deltaNum), dd = BigInt(deltaDen)
            let lhs = dd * d[k] * d[k - 2]
            let rhs = dn * d[k - 1] * d[k - 1] - dd * lambda[k][k - 1] * lambda[k][k - 1]
            if lhs < rhs {
                // SWAP(k)
                let lam = lambda[k][k - 1]
                let B = (d[k - 2] * d[k] + lam * lam) / d[k - 1]
                b.swapAt(k, k - 1)
                if k > 2 {
                    for j in 1...(k - 2) {
                        let t = lambda[k][j]; lambda[k][j] = lambda[k - 1][j]; lambda[k - 1][j] = t
                    }
                }
                if k < kMax {
                    for i in (k + 1)...kMax {
                        let t = lambda[i][k]
                        lambda[i][k] = (d[k] * lambda[i][k - 1] - lam * t) / d[k - 1]
                        lambda[i][k - 1] = (B * t + lam * lambda[i][k]) / d[k]
                    }
                }
                d[k - 1] = B
                k = max(2, k - 1)
            } else {
                var l = k - 2
                while l >= 1 { reduceStep(k, l); l -= 1 }
                k += 1
            }
        }

        var out: [[BigInt]] = []
        for i in 1...n { out.append(b[i]) }
        return out
    }
}
