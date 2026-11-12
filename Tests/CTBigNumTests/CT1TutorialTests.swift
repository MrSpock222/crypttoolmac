import Foundation
import CTCommon
import CTBigNum

/// Number-theoretic steps of CT1's tutorials (online help "Szenario RSA-Demo",
/// CrypTool1-Presentation-de.pdf) – called from main.swift.
func runCT1TutorialTests() {
    section("CT1-Tutorials: Faktorisierung und RSA-Parameter") {
        func factors(_ s: String) throws -> String {
            try Factorization.factorize(BigUInt(s)!).map { $0.exponent == 1 ? "\($0.prime)" : "\($0.prime)^\($0.exponent)" }.joined(separator: " * ")
        }
        // Szenario RSA-Demo: Stinson- und Yan-Challenge
        checkEqual(try factors("31313"), "173 * 181")
        checkEqual(try factors("63978486879527143858831415041"), "145295143558111 * 440334654777631")
        // Präsentation Folie 34
        checkEqual(try factors("316775895367314538931177095642205088158145887517"),
                   "3 * 1129 * 6353 * 1159777 * 22383173213963 * 567102977853788110597")
        let p250 = (BigUInt(1) << 250) - 1
        checkEqual(try Factorization.factorize(p250).map { "\($0.prime)" }.joined(separator: " * "),
                   "3 * 11 * 31 * 251 * 601 * 1801 * 4051 * 229668251 * 269089806001 * 4710883168879506001 * 5519485418336288303251")
        // Präsentation Folie 41 (Bemerkung)
        let p255 = (BigUInt(1) << 255) - 1
        checkEqual(try Factorization.factorize(p255).map { "\($0.prime)" }.joined(separator: " * "),
                   "7 * 31 * 103 * 151 * 2143 * 11119 * 106591 * 131071 * 949111 * 9520972806333758431 * 5702451577639775545838643151")
        // Szenario RSA-Demo: geheime Schlüssel d
        func d(_ p: String, _ q: String, _ e: String) -> String {
            let phi = (BigUInt(p)! - 1) * (BigUInt(q)! - 1)
            return BigUInt(e)!.inverse(modulo: phi).map { "\($0)" } ?? "-"
        }
        checkEqual(d("47", "79", "37"), "97")
        checkEqual(d("251", "269", "65537"), "2473")
        // Stinson: c^d mod N of the first block (d from p = 173, q = 181, e = 4913)
        let dS = BigUInt(4913).inverse(modulo: BigUInt(172 * 180))!
        checkEqual("\(BigUInt(6340).power(dS, modulus: BigUInt(31313)))", "\(11 * 676 + 0 * 26 + 10)", "LAK")
    }
}
