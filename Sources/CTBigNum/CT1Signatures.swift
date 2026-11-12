import CTCommon

// MARK: - DSA additions for CT1 (fixed nonce for test vectors, DER signature encoding)

extension DSA {
    /// Signature with a given nonce k (nil if r or s would be 0) – for test vectors and demos.
    public static func sign(hash: [UInt8], key: DSAKeyPair, nonce k: BigUInt) -> (r: BigUInt, s: BigUInt)? {
        let d = key.parameters
        let r = d.g.power(k, modulus: d.p) % d.q
        guard !r.isZero, let kinv = k.inverse(modulo: d.q) else { return nil }
        let z = hashToInteger(hash, bits: d.q.bitLength) % d.q
        let xr = (key.x * r) % d.q
        let s = (kinv * ((z + xr) % d.q)) % d.q
        return s.isZero ? nil : (r, s)
    }

    // MARK: DER (Dss-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER })

    public static func derEncode(r: BigUInt, s: BigUInt) -> [UInt8] {
        func int(_ v: BigUInt) -> [UInt8] {
            var b = v.bigEndianBytes
            if b.isEmpty { b = [0] }
            if b[0] & 0x80 != 0 { b.insert(0, at: 0) }
            return [0x02] + derLength(b.count) + b
        }
        let body = int(r) + int(s)
        return [0x30] + derLength(body.count) + body
    }

    public static func derDecode(_ der: [UInt8]) -> (r: BigUInt, s: BigUInt)? {
        var i = 0
        func readLen() -> Int? {
            guard i < der.count else { return nil }
            let l = Int(der[i]); i += 1
            if l < 0x80 { return l }
            let n = l & 0x7F
            guard n > 0, n <= 3, i + n <= der.count else { return nil }
            var v = 0
            for _ in 0..<n { v = v << 8 | Int(der[i]); i += 1 }
            return v
        }
        func readInt() -> BigUInt? {
            guard i < der.count, der[i] == 0x02 else { return nil }
            i += 1
            guard let l = readLen(), i + l <= der.count else { return nil }
            defer { i += l }
            return BigUInt(bigEndianBytes: Array(der[i..<i + l]))
        }
        guard der.first == 0x30 else { return nil }
        i = 1
        guard readLen() != nil, let r = readInt(), let s = readInt() else { return nil }
        return (r, s)
    }

    static func derLength(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var b: [UInt8] = []
        var v = n
        while v > 0 { b.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
        return [0x80 | UInt8(b.count)] + b
    }
}

// MARK: - ECSP-NR / ECVP-NR (IEEE P1363 Nyberg-Rueppel on elliptic curves, CT1 "ECSP-NR")

public enum ECNR {
    /// Intermediate values of a signature generation (for CT1's step-by-step display).
    public struct Trace: Sendable {
        public var f: BigUInt, u: BigUInt, V: ECPoint, i: BigUInt, c: BigUInt, d: BigUInt
    }

    /// Signs with a random one-time key (u, V). Returns (c, d).
    public static func sign(hash: [UInt8], key: ECKeyPair) -> (c: BigUInt, d: BigUInt) {
        while true {
            let u = BigUInt.random(below: key.curve.n - 1) + 1
            if let t = trace(hash: hash, key: key, nonce: u) { return (t.c, t.d) }
        }
    }

    /// Signature with given one-time key u (nil if c or d would be 0).
    public static func trace(hash: [UInt8], key: ECKeyPair, nonce u: BigUInt) -> Trace? {
        let c0 = key.curve, r = c0.n
        let f = ECDSA.hashToInteger(hash, curve: c0) % r
        let V = c0.multiply(u, c0.generator)
        guard case let .affine(vx, _) = V else { return nil }
        let i = vx
        let c = (i + f) % r
        if c.isZero { return nil }
        let sc = (key.d * c) % r
        let d = (u % r + r - sc) % r
        if d.isZero { return nil }
        return Trace(f: f, u: u, V: V, i: i, c: c, d: d)
    }

    /// Verification: P = d·G + c·W, i = x(P), f' = (c − i) mod r, compare with f.
    public static func verify(hash: [UInt8], c: BigUInt, d: BigUInt, curve: EllipticCurve, publicKey W: ECPoint) -> Bool {
        let r = curve.n
        guard c > 0, c < r, d < r, !W.isInfinity, curve.contains(W) else { return false }
        guard case let .affine(px, _) = curve.multiplyAdd(d, curve.generator, c, W) else { return false }
        let i = px % r
        let f1 = (c % r + r - i) % r
        return f1 == ECDSA.hashToInteger(hash, curve: curve) % r
    }
}
