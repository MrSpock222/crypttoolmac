import CTCommon
import Foundation

/// "Generic τ-adic NAF key generator" by Anastasios Kanakis (University of Sheffield), shipped with
/// CT1 as t-adicNAF.exe 1.3.3 + t-adicNAF.hta (setup/template/tadicnafkeys, documentation
/// t-adicNAF.pdf). Re-implemented from the documentation and verified digit by digit against the
/// original executable (run in an x86 emulator on all keys up to 14 bits and random keys up to 300 bits).
///
/// For a binary key k of n bits on the Koblitz curve E_a: y² + xy = x³ + a·x² + 1 over GF(2^n):
/// * Algorithm A – τNAF(k) (Solinas: repeated division by τ, τ² = μτ − 2); about 2n digits.
/// * Algorithm B – reduction to n digits using τ^n = 1 (Frobenius on GF(2^n)): digit-wise sum of the
///   n-digit blocks (digits −3…3, no longer a NAF).
/// * Algorithm C – regeneration: from the least significant digit upwards every non-zero digit
///   u_i (with u_{i+1}) is replaced by τ^i·τNAF(u_i + u_{i+1}τ).
///
/// Behaviour of the original program that is kept for parity:
/// * μ = +1 for a = 0 and μ = −1 for a = 1 (the reverse of Solinas' μ = (−1)^(1−a)).
/// * The key is held in an n-bit register: for k = 2^n − 1 (n ≥ 2) the first step k + 1 overflows
///   to 0, so Algorithm A yields "-1".
/// * Algorithm C drops digits that would land above position n−1 (the original's overflow buffer is
///   never filled) and τNAF(r0 + r1τ) is limited to 9 digits.
public enum TauAdicNAF {
    public struct Result: Sendable, Equatable {
        public var key: String            // binary key, MSB first
        public var a: Int
        public var generated: [Int]       // Algorithm A, MSB first
        public var reduced: [Int]         // Algorithm B, MSB first (n digits)
        public var regenerated: [Int]     // Algorithm C, MSB first (n digits)
    }

    public enum Failure: Error, Equatable, LocalizedError {
        case empty
        case notADigit(after: Int)
        case notBinary(after: Int)
        case generatedWrongly
        case outOfRegion
        case temporaryBuffer
        case regeneratedWrongly

        public var errorDescription: String? {
            switch self {
            case .empty: return "Der binäre Schlüssel ist leer."
            case .notADigit(let n): return "Das Zeichen nach \(n) Ziffern im binären Schlüssel ist keine Ziffer.\nDer binäre Schlüssel darf nur die Ziffern 0 und 1 enthalten!"
            case .notBinary(let n): return "Die Ziffer nach \(n) Ziffern im binären Schlüssel ist nicht 0 oder 1.\nDer binäre Schlüssel darf nur die Ziffern 0 und 1 enthalten!"
            case .generatedWrongly: return "Der t-adic-NAF-Schlüssel wurde falsch erzeugt!\nBitte prüfen Sie, ob das MSB 0 ist oder der Betrag zweier benachbarter Stellen größer als 1 ist."
            case .outOfRegion: return "Die Länge des t-adic-NAF-Schlüssels liegt außerhalb des zulässigen Bereichs!\nSie ist größer als das Dreifache der Länge des binären Schlüssels.\nBitte ändern Sie den Parameter „a“."
            case .temporaryBuffer: return "Der temporäre TNAF-Puffer benötigt mehr als 10 Stellen."
            case .regeneratedWrongly: return "Der regenerierte t-adic-NAF-Schlüssel ist nicht korrekt."
            }
        }
    }

    /// μ as used by t-adicNAF.exe (see type documentation).
    public static func mu(a: Int) -> Int { a == 0 ? 1 : -1 }

    /// Validates the key text like the original (only "0"/"1"; the position of the first wrong
    /// character is reported). Leading/trailing white space (e.g. a final line break) is ignored.
    public static func parseKey(_ text: String) throws -> String {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var count = 0
        for ch in key {
            if ch == "0" || ch == "1" { count += 1; continue }
            throw ch.isASCII && ch.isNumber ? Failure.notBinary(after: count) : Failure.notADigit(after: count)
        }
        if count == 0 { throw Failure.empty }
        return key
    }

    /// τNAF of r0 + r1·τ, least significant digit first (Algorithm A of the documentation).
    public static func tnaf(_ r0: BigInt, _ r1: BigInt, mu: Int, registerBits: Int? = nil) -> [Int] {
        var r0 = r0, r1 = r1, u: [Int] = []
        let two = BigInt(2), muB = BigInt(mu)
        let overflow = registerBits.map { BigInt(BigUInt.powerOfTwo($0)) }
        while !r0.isZero || !r1.isZero {
            var ui = 0
            if r0.isOdd {
                ui = 2 - ((r0 - two * r1).modulo(BigUInt(4)).intValue ?? 0)
                r0 -= BigInt(ui)
                if u.isEmpty, let o = overflow, r0 == o { r0 = BigInt() }   // n-bit register wraps
            }
            u.append(ui)
            let t = r0
            r0 = r1 + muB * (r0 / two)
            r1 = -(t / two)
        }
        return u
    }

    /// Runs Algorithms A, B and C as t-adicNAF.exe does.
    public static func generate(key text: String, a: Int) throws -> Result {
        let key = try parseKey(text)
        let n = key.count
        let mu = mu(a: a)
        guard let k = BigUInt(key, radix: 2) else { throw Failure.notBinary(after: 0) }
        // Algorithm A
        let u = tnaf(BigInt(k), BigInt(), mu: mu, registerBits: n)
        if u.count > 3 * n { throw Failure.outOfRegion }
        if u.last ?? 0 == 0 || !isNAF(u) { throw Failure.generatedWrongly }
        // Algorithm B: τ^n = 1
        var red = [Int](repeating: 0, count: n)
        for (i, d) in u.enumerated() { red[i % n] += d }
        let reduced = Array(red.reversed())
        // Algorithm C (array MSB first, processed from the LSB, c = position + 1)
        var w = reduced
        for c in stride(from: n, through: 1, by: -1) where w[c - 1] != 0 {
            let r0 = w[c - 1], r1 = c >= 2 ? w[c - 2] : 0
            w[c - 1] = 0
            if c >= 2 { w[c - 2] = 0 }
            let digits = tnaf(BigInt(r0), BigInt(r1), mu: mu)
            if digits.count >= 10 { throw Failure.temporaryBuffer }
            for (j, d) in digits.enumerated() where c - 1 - j >= 0 { w[c - 1 - j] += d }
        }
        if !isNAF(w) { throw Failure.regeneratedWrongly }
        return Result(key: key, a: a, generated: Array(u.reversed()), reduced: reduced, regenerated: w)
    }

    /// No two adjacent digits of absolute value 1 (the check of the original program).
    static func isNAF(_ d: [Int]) -> Bool {
        d.count < 2 || !(0..<(d.count - 1)).contains { abs(d[$0]) == 1 && abs(d[$0 + 1]) == 1 }
    }

    /// Digits as printed by the original: "1", "0", "-1", "2", "-3" … without separators.
    public static func digitString(_ d: [Int]) -> String { d.map(String.init).joined() }

    /// The block t-adicNAF.exe appends to "key-out.txt" (original English wording, "\n" line ends).
    public static func keyOutText(_ r: Result, source: String, milliseconds: Int) -> String {
        "\nInput: 'a' = \(r.a); binary key from '\(source)'"
            + "\nLength of input key: \(r.key.count) bit\nBinary key from the most significant (MSB) to the least significant bit (LSB):\n"
            + r.key
            + "\n\nOutput:\nResult of algorithm A:\nLength of the generated key: \(r.generated.count) bit\nGenerated 't-adic NAF' key (from MSB to LSB):\n"
            + digitString(r.generated)
            + "\nResult of algorithm B:\nLength of the reduced key: \(r.key.count) bit\nReduced key (from MSB to LSB):\n"
            + digitString(r.reduced)
            + "\nResult of algorithm C:\nLength of the regenerated key: \(r.key.count) bit\nThe regenerated 't-adic NAF' key (from MSB to LSB):\n"
            + digitString(r.regenerated)
            + "\nTotal time for calculations: \(milliseconds) msec"
            + "\n-------------------------------------\n"
    }
}
