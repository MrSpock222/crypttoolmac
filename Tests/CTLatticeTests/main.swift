import Foundation
import CTCommon
import CTBigNum

// Kleiner Testrahmen (wie die übrigen CT*-Tests).
nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var passes = 0

func check(_ cond: Bool, _ msg: @autoclosure () -> String = "", line: Int = #line) {
    if cond { passes += 1 } else { failures += 1; print("  FEHLER Zeile \(line): \(msg())") }
}

func section(_ name: String, _ body: () -> Void) {
    let start = Date()
    body()
    print(name.padding(toLength: 44, withPad: " ", startingAt: 0) + String(format: "%8.3f s", Date().timeIntervalSince(start)))
}

// MARK: - LLL

section("LLL: kürzester Vektor (2D)") {
    // Gitter enthält (1,0) = b1 − 1000000·b2; LLL muss einen Vektor der Länge 1 finden.
    let reduced = Lattice.reduce([[BigInt(1), BigInt(1_000_000)], [BigInt(0), BigInt(1)]])
    var minNorm2 = BigInt(0)
    for (i, v) in reduced.enumerated() {
        let n2 = v[0] * v[0] + v[1] * v[1]
        if i == 0 || n2 < minNorm2 { minNorm2 = n2 }
    }
    check(minNorm2 == BigInt(1), "kürzeste Norm² = \(minNorm2.toString())")
}

section("LLL: Determinante erhalten (3D)") {
    let basis = [[BigInt(2), BigInt(7), BigInt(3)], [BigInt(1), BigInt(5), BigInt(0)], [BigInt(4), BigInt(1), BigInt(6)]]
    func det3(_ m: [[BigInt]]) -> BigInt {
        m[0][0]*(m[1][1]*m[2][2]-m[1][2]*m[2][1])
      - m[0][1]*(m[1][0]*m[2][2]-m[1][2]*m[2][0])
      + m[0][2]*(m[1][0]*m[2][1]-m[1][1]*m[2][0])
    }
    let before = det3(basis).absoluteValue
    let after = det3(Lattice.reduce(basis)).absoluteValue
    check(before == after, "det vorher \(before.toString()) ≠ nachher \(after.toString())")
}

// MARK: - Angriff auf stereotype Nachrichten (Coppersmith, e = 3)

section("Stereotype Nachrichten (e=3)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let e = 3
    // Zufällige Nachricht, die unteren 30 Bit sind dem Angreifer unbekannt.
    let m = Primality.randomPrime(bits: 250)
    let u = 30
    let twoU = BigUInt(1) << u
    let x0 = m % twoU
    let known = m - x0
    let c = m.power(e, modulus: N)
    let start = Date()
    let rec = Coppersmith.stereotypedMessage(n: N, e: e, cipher: c, known: known, bound: twoU)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(rec == m, "Nachricht nicht wiederhergestellt (rec=\(rec?.toString() ?? "nil"))")
}

// MARK: - Faktorisieren mit teilweise bekanntem p (höchstwertige Bits)

section("Teilweise bekanntes p (MSB)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let u = 40                       // unbekannte niederwertige Bits von p
    let twoU = BigUInt(1) << u
    let P = p - (p % twoU)           // bekannte höchstwertige Bits
    let start = Date()
    let r = Coppersmith.factorWithKnownBits(n: N, known: P, pBits: 128, unknownBits: u, highBits: true, latticeParameter: 5)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(r != nil && (r!.p == p || r!.p == q), "p nicht gefunden")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

section("Teilweise bekanntes p (LSB)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let u = 38                       // unbekannte höchstwertige Bits von p; untere 90 bekannt
    let s = 128 - u
    let P = p % (BigUInt(1) << s)    // bekannte niederstwertige Bits
    let r = Coppersmith.factorWithKnownBits(n: N, known: P, pBits: 128, unknownBits: u, highBits: false, latticeParameter: 5)
    check(r != nil && (r!.p == p || r!.p == q), "p (LSB) nicht gefunden")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

// MARK: - Angriff auf kleine geheime Schlüssel (Wiener)

section("Kleine geheime Schlüssel (Wiener)") {
    let p = Primality.randomPrime(bits: 128)
    let q = Primality.randomPrime(bits: 128)
    let N = p * q
    let phi = (p - BigUInt(1)) * (q - BigUInt(1))
    // Kleiner geheimer Exponent d < N^{1/4}.
    var d = Primality.randomPrime(bits: 50)
    while d.gcd(phi) != BigUInt(1) { d = Primality.randomPrime(bits: 50) }
    guard let e = d.inverse(modulo: phi) else { check(false, "kein e"); return }
    let start = Date()
    let r = Coppersmith.wienerSmallSecretKey(n: N, e: e)
    print(String(format: "      Laufzeit %.3f s", Date().timeIntervalSince(start)))
    check(r != nil && r!.d == d, "d nicht gefunden (\(r?.d.toString() ?? "nil"))")
    if let r { check(r.p * r.q == N, "p·q ≠ N") }
}

// MARK: - Seitenkanalangriff auf Textbook-RSA (Kühn)

section("Seitenkanalangriff (Textbook-RSA)") {
    // RSA-512 wie in CT1 (Bob), significantBits = 128 ⇒ L(N)=512 > 3·128+3 = 387.
    let p = Primality.randomPrime(bits: 256)
    let q = Primality.randomPrime(bits: 256)
    let N = p * q
    let phi = (p - BigUInt(1)) * (q - BigUInt(1))
    var e = BigUInt(65537)
    while e.gcd(phi) != BigUInt(1) { e = e + BigUInt(2) }
    guard let d = e.inverse(modulo: phi) else { check(false, "kein d"); return }
    let bits = 128
    // Sessionkey K ist ein b-Bit-Schlüssel (Textbook-RSA ohne Polsterung), c = K^e mod N
    let K = BigUInt.random(below: BigUInt(1) << bits)
    let c = K.power(e, modulus: N)
    let trueSecret = K % (BigUInt(1) << bits)
    let start = Date()
    do {
        let r = try SideChannel.run(n: N, e: e, d: d, cipher: c, significantBits: bits)
        print(String(format: "      Laufzeit %.3f s, %d Anfragen", Date().timeIntervalSince(start), r.queries))
        check(r.secret == trueSecret, "Geheimnis falsch\n  erhalten:  \(r.secret.toString())\n  erwartet:  \(trueSecret.toString())")
    } catch {
        check(false, "Angriff warf Ausnahme: \(error)")
    }
}

print("\nCTLatticeTests: \(passes) bestanden, \(failures) fehlgeschlagen")
exit(failures == 0 ? 0 : 1)
