import Foundation

/// Gitterreduktion nach LLL (Lenstra–Lenstra–Lovász), exakte Ganzzahl-Variante.
///
/// Grundlage der drei gitterbasierten RSA-Angriffe von CrypTool 1
/// (Faktorisieren mit teilweise bekanntem p, Angriff auf stereotype Nachrichten,
/// Angriff auf kleine geheime Schlüssel). Die Implementierung folgt
/// H. Cohen, *A Course in Computational Algebraic Number Theory*, Algorithmus 2.6.7
/// ("integer LLL"): sämtliche Zwischenwerte bleiben ganzzahlig, es wird nicht mit
/// Gleitkomma gerechnet, das Ergebnis ist also exakt und reproduzierbar.
///
/// Laufzeit: Die Zeit steckt in den Zeilen-Updates beim Tausch (je Zeile vier große Produkte und
/// zwei exakte Divisionen). Ab `parallelLimbs` werden diese unabhängigen Rechnungen auf mehrere
/// Kerne verteilt und die Divisionen über einen gemeinsamen Kehrwert ausgeführt
/// (`SharedExactDivisor`). Das ändert nur die Rechenzeit: Reihenfolge der Schritte, alle
/// Zwischenwerte und die reduzierte Basis sind dieselben wie bei der schlichten Fassung
/// (CTLatticeTests vergleicht beide bitgenau).
public enum Lattice {

    /// Nur für Tests: exakte Quotienten `dividends[i] / divisor` über den gemeinsamen Kehrwert.
    public static func exactQuotients(of dividends: [BigUInt], by divisor: BigUInt) -> [BigUInt] {
        let dv = SharedExactDivisor(divisor, maxDividendWords: dividends.map { $0.wordCount }.max() ?? 0)
        return dividends.map { dv.quotient($0) }
    }

    /// Ab dieser Größe (64-Bit-Worte von d_{k-1}) werden unabhängige Teilrechnungen auf mehrere
    /// Kerne verteilt. Reine Laufzeitfrage: die berechneten Werte sind dieselben.
    static let parallelLimbs = 48

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
            let lam = lambda[k][k - 1]
            let dk = d[k], dk1 = d[k - 1], dk2 = d[k - 2]
            let big = dk1.magnitude.wordCount >= Lattice.parallelLimbs
            // die drei großen Produkte des Tests; d_k·d_{k-2} und λ² werden bei SWAP wiederverwendet
            var prod = [BigInt](repeating: BigInt(0), count: 3)
            if big {
                prod.withUnsafeMutableBufferPointer { buf in
                    let out = buf
                    DispatchQueue.concurrentPerform(iterations: 3) { j in
                        switch j {
                        case 0: out[0] = dk * dk2
                        case 1: out[1] = dk1 * dk1
                        default: out[2] = lam * lam
                        }
                    }
                }
            } else {
                prod[0] = dk * dk2; prod[1] = dk1 * dk1; prod[2] = lam * lam
            }
            let lhs = dd * prod[0]
            let rhs = dn * prod[1] - dd * prod[2]
            if lhs < rhs {
                // SWAP(k)
                let bNum = prod[0] + prod[2]                 // B = (d_{k-2}·d_k + λ²) / d_{k-1}
                var B = BigInt(0)
                b.swapAt(k, k - 1)
                if k > 2 {
                    for j in 1...(k - 2) {
                        let t = lambda[k][j]; lambda[k][j] = lambda[k - 1][j]; lambda[k - 1][j] = t
                    }
                }
                let rows = kMax - k
                if rows == 0 || !big {
                    B = bNum / dk1
                }
                if rows > 0 {
                    // Cohen 2.6.7:  t = λ[i][k];  λ[i][k]   ← (d_k·λ[i][k-1] − λ·t) / d_{k-1}
                    //                             λ[i][k-1] ← (B·t + λ·λ[i][k]) / d_k
                    // Die zweite Zuweisung ist wegen B·d_{k-1} = d_{k-2}·d_k + λ² identisch zu
                    //                             λ[i][k-1] ← (d_{k-2}·t + λ·λ[i][k-1]alt) / d_{k-1}
                    // (gleiche ganze Zahl). So hängen beide Werte nur von den alten Werten ab, alle
                    // Divisionen haben den Divisor d_{k-1}, und die Zeilen i können unabhängig
                    // voneinander – auch parallel – berechnet werden.
                    let ts = (0..<rows).map { lambda[k + 1 + $0][k] }
                    let olds = (0..<rows).map { lambda[k + 1 + $0][k - 1] }
                    var res = [BigInt](repeating: BigInt(0), count: 2 * rows + 1)
                    @inline(__always) func numerator(_ j: Int) -> BigInt {
                        let r = j >> 1
                        return j & 1 == 0 ? dk * olds[r] - lam * ts[r] : dk2 * ts[r] + lam * olds[r]
                    }
                    if big {
                        // obere Schranke für die Wortzahl aller Zähler (für den gemeinsamen Kehrwert)
                        var maxWords = bNum.magnitude.wordCount
                        let wk = dk.magnitude.wordCount, wl = lam.magnitude.wordCount, wk2 = dk2.magnitude.wordCount
                        for r in 0..<rows {
                            let wt = ts[r].magnitude.wordCount, wo = olds[r].magnitude.wordCount
                            maxWords = max(maxWords, max(wk + wo, wl + wt) + 1, max(wk2 + wt, wl + wo) + 1)
                        }
                        var divider: SharedExactDivisor? = nil
                        res.withUnsafeMutableBufferPointer { buf in
                            let out = buf
                            // Phase 1: Zähler und Kehrwert
                            withUnsafeMutablePointer(to: &divider) { dp in
                                let dptr = dp
                                DispatchQueue.concurrentPerform(iterations: 2 * rows + 1) { j in
                                    if j == 2 * rows {
                                        dptr.pointee = SharedExactDivisor(dk1.magnitude, maxDividendWords: maxWords)
                                    } else {
                                        out[j] = numerator(j)
                                    }
                                }
                            }
                            // Phase 2: exakte Quotienten
                            let dv = divider!
                            out[2 * rows] = bNum
                            DispatchQueue.concurrentPerform(iterations: 2 * rows + 1) { j in
                                out[j] = dv.quotient(out[j])
                            }
                        }
                        B = res[2 * rows]
                    } else {
                        for j in 0..<(2 * rows) { res[j] = numerator(j) / dk1 }
                    }
                    for r in 0..<rows {
                        lambda[k + 1 + r][k] = res[2 * r]
                        lambda[k + 1 + r][k - 1] = res[2 * r + 1]
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
