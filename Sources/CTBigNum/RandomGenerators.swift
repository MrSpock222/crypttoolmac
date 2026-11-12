import Foundation
import CTCommon

/// Pseudo random generators of CT1's dialog "Zufallsdaten erzeugen".
///
/// Bit extraction mimics CT1 (`DlgRandomGenerator.cpp`, `IntegerArithmetic.cpp`): every output
/// byte consists of 8 consecutive generator outputs; for each bit the generator state is advanced
/// first, then one bit is taken and placed from the most significant to the least significant
/// bit of the byte.
/// * x² mod N (Blum-Blum-Shub): x ← x² mod N, bit = x mod 2.
/// * LCG: x ← (a·x + b) mod N, bit = 1 if x > ⌊N/2⌋.
/// * ICG: x_i = (a·(seed + c_i) + b)⁻¹ mod N (0 if not invertible), bit = 1 if x > ⌊N/2⌋, with
///   CT1's peculiar counter sequence c = 0,0,1,…,6, 7,9,10,…,15, 16,18,… (see `icgCounter`).
public enum RandomGenerators {
    /// CT1 default seed ("314159").
    public static let defaultSeed: BigUInt = 314159
    /// CT1 default modulus of the x² mod N generator.
    public static let defaultX2ModNModulus: BigUInt = 245438302030331732360701189397045881523
    /// CT1 LCG defaults: a = 23, b = 0, N = 100000001.
    public static let defaultLCGA: BigUInt = 23
    public static let defaultLCGB: BigUInt = 0
    public static let defaultLCGModulus: BigUInt = 100000001
    /// CT1 ICG defaults: a = 22211, b = 11926380, N = 2147483053.
    public static let defaultICGA: BigUInt = 22211
    public static let defaultICGB: BigUInt = 11926380
    public static let defaultICGModulus: BigUInt = 2147483053
    /// CT1 default amount of data (bytes).
    public static let defaultByteCount = 2500

    /// Cryptographically secure random bytes (SecRandomCopyBytes; replaces CT1's SECUDE generator).
    public static func secure(count: Int) -> [UInt8] {
        BigUInt.secureRandomBytes(count)
    }

    /// x² mod N generator (Blum-Blum-Shub).
    public static func x2modN(seed: BigUInt, modulus: BigUInt, count: Int) -> [UInt8] {
        x2modN(seed: seed, modulus: modulus, count: count, states: nil)
    }

    /// x² mod N generator; optionally records the internal states (one per bit, CT1 option
    /// "Interne Zustände ausgeben"). `states` receives the seed followed by every state.
    public static func x2modN(seed: BigUInt, modulus: BigUInt, count: Int, states: ((BigUInt) -> Void)?) -> [UInt8] {
        guard modulus > 1, count > 0 else { return [] }
        var out = [UInt8](repeating: 0, count: count)
        states?(seed)
        if modulus.isOdd {
            let ctx = MontgomeryContext(modulus: modulus, registers: 1)
            ctx.set(0, seed)
            for i in 0..<count {
                var o: UInt8 = 0
                for bit in 0..<8 {
                    ctx.sqr(0, 0)
                    let x = ctx.get(0)
                    if x.isOdd { o |= 0x80 >> UInt8(bit) }
                    states?(x)
                }
                out[i] = o
            }
        } else {
            var x = seed % modulus
            for i in 0..<count {
                var o: UInt8 = 0
                for bit in 0..<8 {
                    x = x.squared() % modulus
                    if x.isOdd { o |= 0x80 >> UInt8(bit) }
                    states?(x)
                }
                out[i] = o
            }
        }
        return out
    }

    /// Linear congruential generator x ← (a·x + b) mod N.
    public static func lcg(seed: BigUInt, a: BigUInt, b: BigUInt, modulus: BigUInt, count: Int) -> [UInt8] {
        lcg(seed: seed, a: a, b: b, modulus: modulus, count: count, states: nil)
    }

    /// LCG with optional state recording.
    public static func lcg(seed: BigUInt, a: BigUInt, b: BigUInt, modulus: BigUInt, count: Int,
                           states: ((BigUInt) -> Void)?) -> [UInt8] {
        guard !modulus.isZero, count > 0 else { return [] }
        var out = [UInt8](repeating: 0, count: count)
        let half = modulus / 2
        states?(seed)
        if let n = modulus.uint64Value, let a64 = (a % modulus).uint64Value, let b64 = (b % modulus).uint64Value,
           states == nil, seed.bitLength <= 64 {
            var x = seed.uint64Value!
            let h = half.uint64Value!
            // CT1 applies (a·x + b) mod N to the unreduced seed – identical result after one step
            var first = true
            for i in 0..<count {
                var o: UInt8 = 0
                for bit in 0..<8 {
                    if first {
                        x = ((seed * a + b) % modulus).uint64Value!
                        first = false
                    } else {
                        let (hi, lo) = a64.multipliedFullWidth(by: x)
                        let t = n.dividingFullWidth((hi % n, lo)).remainder
                        let (s, ov) = t.addingReportingOverflow(b64)
                        x = (ov || s >= n) ? s &- n : s
                    }
                    if x > h { o |= 0x80 >> UInt8(bit) }
                }
                out[i] = o
            }
            return out
        }
        var x = seed
        for i in 0..<count {
            var o: UInt8 = 0
            for bit in 0..<8 {
                x = (a * x + b) % modulus
                if x > half { o |= 0x80 >> UInt8(bit) }
                states?(x)
            }
            out[i] = o
        }
        return out
    }

    /// Counter value CT1 uses for bit `i` (0…7) of byte `k`: byte 0 uses 0,0,1,2,3,4,5,6, every
    /// later byte k uses 9k−2 for its first bit and 9k+i−1 for the others.
    public static func icgCounter(byte k: Int, bit i: Int) -> Int {
        if i == 0 { return k == 0 ? 0 : 9 * (k - 1) + 7 }
        return 9 * k + i - 1
    }

    /// Inversive congruential generator x_i = (a·(seed + c_i) + b)⁻¹ mod N (CT1 counter sequence).
    public static func icg(seed: BigUInt, a: BigUInt, b: BigUInt, modulus: BigUInt, count: Int) -> [UInt8] {
        icg(seed: seed, a: a, b: b, modulus: modulus, count: count, states: nil)
    }

    /// ICG with optional state recording.
    public static func icg(seed: BigUInt, a: BigUInt, b: BigUInt, modulus: BigUInt, count: Int,
                           states: ((BigUInt) -> Void)?) -> [UInt8] {
        guard modulus > 1, count > 0 else { return [] }
        var out = [UInt8](repeating: 0, count: count)
        let half = modulus / 2
        states?(seed)
        for k in 0..<count {
            var o: UInt8 = 0
            for bit in 0..<8 {
                let c = BigUInt(icgCounter(byte: k, bit: bit))
                let v = (a * (seed + c) + b) % modulus
                let x = v.inverse(modulo: modulus) ?? 0
                if x > half { o |= 0x80 >> UInt8(bit) }
                states?(x)
            }
            out[k] = o
        }
        return out
    }
}
