import Foundation

/// Seitenkanalangriff auf das Hybridverschlüsselungsprotokoll mit „Textbook-RSA“
/// (nach Ulrich Kühn), portiert aus CrypTool 1 (`SideChannelAttack.cpp`:
/// `SCA_Attacker::nextHybridEncryptedFile`, `processServerResponse`, `computeZ`).
///
/// Der Sessionkey K ist als c = K^e mod N (ungepolstertes RSA) verschlüsselt. Trudy modifiziert
/// das Chiffrat multiplikativ (c' = c · m^e mod N ⇒ Entschlüsselung liefert K·m mod N) und
/// erfährt über ein Orakel, ob die mit den niederwertigsten `significantBits` Bit des
/// entschlüsselten Wertes AES-entschlüsselte Nachricht gültig ist. Aus den Ja/Nein-Antworten
/// bestimmt eine Binärsuche z; am Ende ist das Geheimnis (N/(z+1)) mod 2^significantBits.
///
/// Der Algorithmus ist bit-genau wie in CT1 umgesetzt, damit die Zwischenwerte (Challenges,
/// Antworten, z) und das Ergebnis mit der Windows-Version übereinstimmen.
public enum SideChannel {

    public enum AttackError: Error { case conditionsNotMet, invalidParameters }

    /// Ein Schritt des Angriffs (eine an den Server gesendete Challenge und dessen Antwort).
    public struct Step: Sendable {
        public let index: Int
        public let phase: Int               // CT1 currentStep (2 oder 4)
        public let multiplier: BigUInt      // m in c' = c·m^e
        public let challenge: BigUInt       // c' (modifizierte Challenge)
        public let response: Bool           // Orakel-Antwort (Ampel grün/rot)
    }

    public struct Result: Sendable {
        public let secret: BigUInt          // rekonstruierte niederwertige Bits des Sessionkeys
        public let z: BigUInt
        public let steps: [Step]
        public var queries: Int { steps.count }
    }

    /// CT1 `SCA_Attacker::computeZ`: größte Zweierpotenz kleiner als N/2^significantBits.
    /// Wirft, wenn die Angriffsbedingung L(N) > 3·b + 3 verletzt ist.
    static func computeZ(n N: BigUInt, significantBits b: Int) throws -> BigUInt {
        let bitLengthModul = N.bitLength
        if !(bitLengthModul > 3 * b + 3) { throw AttackError.conditionsNotMet }
        let fraction = N / (BigUInt(1) << b)                 // N / B
        var i = bitLengthModul
        while i > 0 {
            let p = BigUInt(1) << i
            if p < fraction { return p }
            i -= 1
        }
        return BigUInt(0)
    }

    /// Führt den Angriff mit einem beliebigen Orakel aus. `oracle(c')` liefert die Serverantwort
    /// auf die Challenge c'. `significantBits` muss ein Vielfaches von 8 sein (CT1-Default 128).
    public static func run(n N: BigUInt, e: BigUInt, cipher c: BigUInt,
                           significantBits b: Int, oracle: (BigUInt) -> Bool) throws -> Result {
        guard b > 0, b % 8 == 0, !N.isZero else { throw AttackError.invalidParameters }
        let B = BigUInt(1) << b

        var z = BigUInt(0)
        var y = BigUInt(0)
        var b2 = 0
        var step = 1
        var steps: [Step] = []

        func sendMultiplier(_ m: BigUInt, phase: Int) -> Bool {
            let challenge = (c * m.power(e, modulus: N)) % N
            let resp = oracle(challenge)
            steps.append(Step(index: steps.count + 1, phase: phase, multiplier: m, challenge: challenge, response: resp))
            return resp
        }

        while true {
            // ** SCHRITT 1 ** – z berechnen, b' = b
            if step == 1 {
                z = try computeZ(n: N, significantBits: b)
                b2 = b
                step = 2
            }
            // ** SCHRITT 2 ** – z verdoppeln, solange der Server mit JA antwortet
            if step == 2 {
                let resp = sendMultiplier(2 * z + 1, phase: 2)   // m = 2z+1
                if resp {
                    z = z * 2
                    if b2 == 0 { step = 3 } else { b2 -= 1 }
                } else {
                    step = 3
                }
                continue
            }
            // ** SCHRITT 3 ** – y = z/2
            if step == 3 {
                y = z / 2
                step = 4
            }
            // ** SCHRITT 4 ** – Binärsuche über (z + y + 1)
            if step == 4 {
                if b2 >= 0 {
                    let resp = sendMultiplier(z + y + 1, phase: 4)   // m = z+y+1
                    b2 -= 1
                    if resp { z = z + y }
                    y = y / 2
                    continue
                } else {
                    step = 5
                }
            }
            // ** SCHRITT 5 ** – finale Berechnung des Geheimnisses
            if step == 5 {
                let secret = (N / (z + BigUInt(1))) % B
                return Result(secret: secret, z: z, steps: steps)
            }
        }
    }

    /// Bequeme Variante mit dem CT1-Serverorakel: der Server entschlüsselt die Challenge mit dem
    /// privaten Schlüssel d (K' = c'^d mod N) und meldet JA, wenn die niederwertigsten
    /// `significantBits` Bit mit denen des echten Sessionkeys übereinstimmen – genau das prüft in
    /// CT1 die AES-Entschlüsselung samt Schlüsselwortsuche.
    public static func run(n N: BigUInt, e: BigUInt, d: BigUInt, cipher c: BigUInt,
                           significantBits b: Int) throws -> Result {
        let B = BigUInt(1) << b
        let trueSecret = c.power(d, modulus: N) % B          // K mod 2^b
        return try run(n: N, e: e, cipher: c, significantBits: b) { challenge in
            (challenge.power(d, modulus: N) % B) == trueSecret
        }
    }
}
