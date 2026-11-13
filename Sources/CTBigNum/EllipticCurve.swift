import Foundation
import CTCommon

/// Point on an elliptic curve over F_p (affine coordinates or the point at infinity O).
public enum ECPoint: Hashable, Sendable, Codable {
    case infinity
    case affine(x: BigUInt, y: BigUInt)

    public var isInfinity: Bool { if case .infinity = self { return true }; return false }
    /// x coordinate (nil for O).
    public var x: BigUInt? { if case let .affine(x, _) = self { return x }; return nil }
    /// y coordinate (nil for O).
    public var y: BigUInt? { if case let .affine(_, y) = self { return y }; return nil }

    /// "(x, y)" or "O".
    public var displayString: String {
        switch self {
        case .infinity: return "O"
        case let .affine(x, y): return "(\(x), \(y))"
        }
    }
}

/// Elliptic curve y² = x³ + a·x + b over F_p with base point G = (gx, gy) of order n and
/// cofactor h. Toy curves created with `init(p:a:b:)` have no base point (n = 0).
public struct EllipticCurve: Hashable, Sendable, Codable {
    public var name: String
    public var p: BigUInt
    public var a: BigUInt
    public var b: BigUInt
    public var gx: BigUInt
    public var gy: BigUInt
    /// Order of the base point (0 = unknown).
    public var n: BigUInt
    /// Cofactor.
    public var h: BigUInt

    public init(name: String, p: BigUInt, a: BigUInt, b: BigUInt, gx: BigUInt, gy: BigUInt, n: BigUInt, h: BigUInt) {
        self.name = name
        self.p = p
        self.a = p.isZero ? a : a % p
        self.b = p.isZero ? b : b % p
        self.gx = gx
        self.gy = gy
        self.n = n
        self.h = h
    }

    /// Small curve without base point (for demos, e.g. listing all points).
    public init(p: BigUInt, a: BigUInt, b: BigUInt) {
        self.init(name: "", p: p, a: a, b: b, gx: 0, gy: 0, n: 0, h: 1)
    }

    /// Base point G (O if the curve has none).
    public var generator: ECPoint { n.isZero ? .infinity : .affine(x: gx, y: gy) }

    /// Bit length of the order n.
    public var orderBits: Int { n.bitLength }

    /// Discriminant condition 4a³ + 27b² ≢ 0 (mod p).
    public var isNonSingular: Bool {
        let a3 = (a.power(3, modulus: p) * 4) % p
        let b2 = (b * b * 27) % p
        return !((a3 + b2) % p).isZero
    }

    /// Right-hand side x³ + a·x + b mod p.
    public func rhs(_ x: BigUInt) -> BigUInt {
        let xx = x % p
        return ((xx * xx % p + a) % p * xx % p + b) % p
    }

    /// True if P lies on the curve (O always does).
    public func contains(_ P: ECPoint) -> Bool {
        guard case let .affine(x, y) = P else { return true }
        guard x < p, y < p else { return false }
        return (y * y) % p == rhs(x)
    }

    /// −P
    public func negate(_ P: ECPoint) -> ECPoint {
        guard case let .affine(x, y) = P else { return .infinity }
        return .affine(x: x, y: y.isZero ? y : p - y)
    }

    /// P + Q (affine formulas).
    public func add(_ P: ECPoint, _ Q: ECPoint) -> ECPoint {
        guard case let .affine(x1, y1) = P else { return Q }
        guard case let .affine(x2, y2) = Q else { return P }
        let lambda: BigUInt
        if x1 == x2 {
            if (y1 + y2) % p == 0 { return .infinity }
            return double(P)
        } else {
            let num = y2.subtractedModulo(y1, p)
            let den = x2.subtractedModulo(x1, p)
            guard let inv = den.inverse(modulo: p) else { return .infinity }
            lambda = (num * inv) % p
        }
        let x3 = (lambda * lambda % p).subtractedModulo((x1 + x2) % p, p)
        let y3 = (lambda * x1.subtractedModulo(x3, p) % p).subtractedModulo(y1, p)
        return .affine(x: x3, y: y3)
    }

    /// 2P (affine formulas).
    public func double(_ P: ECPoint) -> ECPoint {
        guard case let .affine(x, y) = P else { return .infinity }
        if y.isZero { return .infinity }
        let num = (3 * (x * x % p) + a) % p
        guard let inv = (2 * y % p).inverse(modulo: p) else { return .infinity }
        let lambda = (num * inv) % p
        let x3 = (lambda * lambda % p).subtractedModulo((2 * x) % p, p)
        let y3 = (lambda * x.subtractedModulo(x3, p) % p).subtractedModulo(y, p)
        return .affine(x: x3, y: y3)
    }

    /// P − Q
    public func subtract(_ P: ECPoint, _ Q: ECPoint) -> ECPoint { add(P, negate(Q)) }

    /// k·P (Jacobian coordinates, left-to-right double-and-add).
    public func multiply(_ k: BigUInt, _ P: ECPoint) -> ECPoint {
        guard case let .affine(px, py) = P, !k.isZero else { return .infinity }
        let f = Field(p: p)
        var R = Jacobian.infinity
        let base = Jacobian(X: px, Y: py, Z: 1)
        let bl = k.bitLength
        for i in stride(from: bl - 1, through: 0, by: -1) {
            R = f.double(R, a: a)
            if k.bit(at: i) { R = f.add(R, base, a: a) }
        }
        return f.toAffine(R)
    }

    /// k·P + l·Q (Shamir's trick).
    public func multiplyAdd(_ k: BigUInt, _ P: ECPoint, _ l: BigUInt, _ Q: ECPoint) -> ECPoint {
        guard case let .affine(px, py) = P else { return multiply(l, Q) }
        guard case let .affine(qx, qy) = Q else { return multiply(k, P) }
        let f = Field(p: p)
        let jp = Jacobian(X: px, Y: py, Z: 1), jq = Jacobian(X: qx, Y: qy, Z: 1)
        let jpq = f.add(jp, jq, a: a)
        var R = Jacobian.infinity
        for i in stride(from: max(k.bitLength, l.bitLength) - 1, through: 0, by: -1) {
            R = f.double(R, a: a)
            switch (k.bit(at: i), l.bit(at: i)) {
            case (true, true): R = f.add(R, jpq, a: a)
            case (true, false): R = f.add(R, jp, a: a)
            case (false, true): R = f.add(R, jq, a: a)
            default: break
            }
        }
        return f.toAffine(R)
    }

    /// Point with the given x coordinate (the one with even y), or nil if x³+ax+b is no square.
    public func lift(x: BigUInt) -> ECPoint? {
        let r = rhs(x)
        guard let y = r.modularSquareRoot(prime: p) else { return nil }
        let yy = y.isOdd ? (p - y) % p : y
        return .affine(x: x % p, y: yy)
    }

    /// Random affine point on the curve.
    public func randomPoint() -> ECPoint {
        while true {
            let x = BigUInt.random(below: p)
            if var P = lift(x: x) {
                if Bool.random() { P = negate(P) }
                return P
            }
        }
    }

    /// All points of a small curve (O first), at most `limit` points.
    public func allPoints(limit: Int) -> [ECPoint] {
        var out: [ECPoint] = [.infinity]
        guard let p64 = p.uint64Value, limit > 1 else { return out }
        let a64 = a.uint64Value!, b64 = b.uint64Value!
        // squares table: for each residue r, list of roots
        if p64 <= 2_000_000 {
            var roots = [[UInt64]](repeating: [], count: Int(p64))
            for y in 0..<p64 { roots[Int(BigUInt.mulMod64(y, y, p64))].append(y) }
            for x in 0..<p64 {
                let r = (BigUInt.mulMod64(BigUInt.mulMod64(x, x, p64), x, p64) &+ BigUInt.mulMod64(a64, x, p64) % p64 + b64) % p64
                for y in roots[Int(r)] {
                    out.append(.affine(x: BigUInt(x), y: BigUInt(y)))
                    if out.count >= limit { return out }
                }
            }
            return out
        }
        var x: UInt64 = 0
        while x < p64 && out.count < limit {
            if let P = lift(x: BigUInt(x)), case let .affine(px, py) = P {
                out.append(P)
                if !py.isZero && out.count < limit { out.append(.affine(x: px, y: p - py)) }
            }
            x += 1
        }
        return out
    }

    /// Number of points #E(F_p) for small p (≤ 10^7) by counting with Legendre symbols, nil if
    /// p is too large.
    public func pointCount() -> BigUInt? {
        guard let p64 = p.uint64Value, p64 <= 10_000_000 else { return nil }
        if p64 == 2 { return BigUInt(UInt64(allPoints(limit: 10).count)) }
        let a64 = a.uint64Value!, b64 = b.uint64Value!
        var count: Int64 = 1 + Int64(p64)
        let e = (p64 - 1) / 2
        for x in 0..<p64 {
            let r = (BigUInt.mulMod64(BigUInt.mulMod64(x, x, p64), x, p64) + BigUInt.mulMod64(a64, x, p64) + b64) % p64
            if r == 0 { continue }
            let l = BigUInt.powMod64(r, e, p64)
            count += (l == 1) ? 1 : -1
        }
        return BigUInt(UInt64(count))
    }

    /// Order of the point P (smallest k ≥ 1 with k·P = O), found by stepping up to `limit`.
    public func order(of P: ECPoint, limit: Int = 10_000_000) -> BigUInt? {
        if P.isInfinity { return 1 }
        var Q = P
        var k = 1
        while k <= limit {
            if Q.isInfinity { return BigUInt(k) }
            Q = add(Q, P)
            k += 1
        }
        return nil
    }
}

// MARK: - Jacobian arithmetic (internal)

struct Jacobian {
    var X: BigUInt
    var Y: BigUInt
    var Z: BigUInt
    static let infinity = Jacobian(X: 1, Y: 1, Z: 0)
    var isInfinity: Bool { Z.isZero }
}

struct Field {
    let p: BigUInt
    @inline(__always) func mul(_ x: BigUInt, _ y: BigUInt) -> BigUInt { (x * y) % p }
    @inline(__always) func sqr(_ x: BigUInt) -> BigUInt { x.squared() % p }
    @inline(__always) func add(_ x: BigUInt, _ y: BigUInt) -> BigUInt { let s = x + y; return s >= p ? s - p : s }
    @inline(__always) func sub(_ x: BigUInt, _ y: BigUInt) -> BigUInt { x >= y ? x - y : p - (y - x) }

    func double(_ P: Jacobian, a: BigUInt) -> Jacobian {
        if P.isInfinity || P.Y.isZero { return .infinity }
        let XX = sqr(P.X), YY = sqr(P.Y), YYYY = sqr(YY), ZZ = sqr(P.Z)
        let S = mul(4, mul(P.X, YY))
        let M = add(mul(3, XX), mul(a, sqr(ZZ)))
        let X3 = sub(sqr(M), add(S, S))
        let Y3 = sub(mul(M, sub(S, X3)), mul(8, YYYY))
        let Z3 = mul(add(P.Y, P.Y), P.Z)
        return Jacobian(X: X3, Y: Y3, Z: Z3)
    }

    func add(_ P: Jacobian, _ Q: Jacobian, a: BigUInt) -> Jacobian {
        if P.isInfinity { return Q }
        if Q.isInfinity { return P }
        let Z1Z1 = sqr(P.Z), Z2Z2 = sqr(Q.Z)
        let U1 = mul(P.X, Z2Z2), U2 = mul(Q.X, Z1Z1)
        let S1 = mul(P.Y, mul(Q.Z, Z2Z2)), S2 = mul(Q.Y, mul(P.Z, Z1Z1))
        if U1 == U2 {
            if S1 != S2 { return .infinity }
            return double(P, a: a)
        }
        let H = sub(U2, U1), R = sub(S2, S1)
        let HH = sqr(H), HHH = mul(H, HH)
        let U1HH = mul(U1, HH)
        let X3 = sub(sub(sqr(R), HHH), add(U1HH, U1HH))
        let Y3 = sub(mul(R, sub(U1HH, X3)), mul(S1, HHH))
        let Z3 = mul(H, mul(P.Z, Q.Z))
        return Jacobian(X: X3, Y: Y3, Z: Z3)
    }

    func toAffine(_ P: Jacobian) -> ECPoint {
        if P.isInfinity { return .infinity }
        guard let zi = P.Z.inverse(modulo: p) else { return .infinity }
        let zi2 = sqr(zi)
        return .affine(x: mul(P.X, zi2), y: mul(P.Y, mul(zi2, zi)))
    }
}

// MARK: - Named curves

extension EllipticCurve {
    private static func h(_ s: String) -> BigUInt { BigUInt(s, radix: 16)! }

    /// NIST P-192 (secp192r1 / prime192v1).
    public static let secp192r1 = EllipticCurve(
        name: "secp192r1",
        p: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFF"),
        a: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFC"),
        b: h("64210519E59C80E70FA7E9AB72243049FEB8DEECC146B9B1"),
        gx: h("188DA80EB03090F67CBF20EB43A18800F4FF0AFD82FF1012"),
        gy: h("07192B95FFC8DA78631011ED6B24CDD573F977A11E794811"),
        n: h("FFFFFFFFFFFFFFFFFFFFFFFF99DEF836146BC9B1B4D22831"), h: 1)

    /// NIST P-224 (secp224r1).
    public static let secp224r1 = EllipticCurve(
        name: "secp224r1",
        p: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001"),
        a: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFE"),
        b: h("B4050A850C04B3ABF54132565044B0B7D7BFD8BA270B39432355FFB4"),
        gx: h("B70E0CBD6BB4BF7F321390B94A03C1D356C21122343280D6115C1D21"),
        gy: h("BD376388B5F723FB4C22DFE6CD4375A05A07476444D5819985007E34"),
        n: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFF16A2E0B8F03E13DD29455C5C2A3D"), h: 1)

    /// NIST P-256 (secp256r1 / prime256v1).
    public static let secp256r1 = EllipticCurve(
        name: "secp256r1",
        p: h("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF"),
        a: h("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC"),
        b: h("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B"),
        gx: h("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"),
        gy: h("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"),
        n: h("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551"), h: 1)

    /// NIST P-384 (secp384r1).
    public static let secp384r1 = EllipticCurve(
        name: "secp384r1",
        p: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFF"),
        a: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFC"),
        b: h("B3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875AC656398D8A2ED19D2A85C8EDD3EC2AEF"),
        gx: h("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7"),
        gy: h("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F"),
        n: h("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52973"), h: 1)

    /// NIST P-521 (secp521r1).
    public static let secp521r1 = EllipticCurve(
        name: "secp521r1",
        p: h("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
        a: h("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC"),
        b: h("0051953EB9618E1C9A1F929A21A0B68540EEA2DA725B99B315F3B8B489918EF109E156193951EC7E937B1652C0BD3BB1BF073573DF883D2C34F1EF451FD46B503F00"),
        gx: h("00C6858E06B70404E9CD9E3ECB662395B4429C648139053FB521F828AF606B4D3DBAA14B5E77EFE75928FE1DC127A2FFA8DE3348B3C1856A429BF97E7E31C2E5BD66"),
        gy: h("011839296A789A3BC0045C8A5FB42C7D1BD998F54449579B446817AFBD17273E662C97EE72995EF42640C550B9013FAD0761353C7086A272C24088BE94769FD16650"),
        n: h("01FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA51868783BF2F966B7FCC0148F709A5D03BB5C9B8899C47AEBB6FB71E91386409"), h: 1)

    /// Brainpool P256r1 (RFC 5639).
    public static let brainpoolP256r1 = EllipticCurve(
        name: "brainpoolP256r1",
        p: h("A9FB57DBA1EEA9BC3E660A909D838D726E3BF623D52620282013481D1F6E5377"),
        a: h("7D5A0975FC2C3057EEF67530417AFFE7FB8055C126DC5C6CE94A4B44F330B5D9"),
        b: h("26DC5C6CE94A4B44F330B5D9BBD77CBF958416295CF7E1CE6BCCDC18FF8C07B6"),
        gx: h("8BD2AEB9CB7E57CB2C4B482FFC81B7AFB9DE27E1E3BD23C23A4453BD9ACE3262"),
        gy: h("547EF835C3DAC4FD97F8461A14611DC9C27745132DED8E545C1D54C72F046997"),
        n: h("A9FB57DBA1EEA9BC3E660A909D838D718C397AA3B561A6F7901E0E82974856A7"), h: 1)

    /// All built-in named curves.
    public static var namedCurves: [EllipticCurve] {
        [secp192r1, secp224r1, secp256r1, secp384r1, secp521r1, brainpoolP256r1]
    }

    /// Looks up a named curve (also accepts "P-256", "prime256v1", …).
    public static func named(_ name: String) -> EllipticCurve? {
        let aliases: [String: String] = ["p-192": "secp192r1", "prime192v1": "secp192r1", "p-224": "secp224r1",
                                         "p-256": "secp256r1", "prime256v1": "secp256r1", "p-384": "secp384r1",
                                         "p-521": "secp521r1"]
        let key = name.lowercased()
        let target = aliases[key] ?? key
        return namedCurves.first { $0.name.lowercased() == target }
    }
}

// MARK: - Keys, ECDSA, ECDH

/// EC key pair: private scalar d and public point Q = d·G.
public struct ECKeyPair: Codable, Hashable, Sendable {
    public var curve: EllipticCurve
    public var d: BigUInt
    public var Q: ECPoint

    /// Key pair from a given private scalar (1 ≤ d < n).
    public init(curve: EllipticCurve, d: BigUInt) {
        self.curve = curve
        self.d = d
        self.Q = curve.multiply(d, curve.generator)
    }

    /// Random key pair.
    public static func generate(curve: EllipticCurve) -> ECKeyPair {
        precondition(!curve.n.isZero, "The curve has no base point")
        return ECKeyPair(curve: curve, d: BigUInt.random(below: curve.n - 1) + 1)
    }
}

/// ECDSA (ANSI X9.62 / FIPS 186): hash values are truncated to the bit length of n.
public enum ECDSA {
    /// Leftmost bitlen(n) bits of the hash as integer.
    public static func hashToInteger(_ hash: [UInt8], curve: EllipticCurve) -> BigUInt {
        let e = BigUInt(bigEndianBytes: hash)
        let hb = hash.count * 8
        let nb = curve.n.bitLength
        return hb > nb ? e >> (hb - nb) : e
    }

    /// Signs a hash value with a random nonce.
    public static func sign(hash: [UInt8], key: ECKeyPair) -> (r: BigUInt, s: BigUInt) {
        let n = key.curve.n
        while true {
            let k = BigUInt.random(below: n - 1) + 1
            if let sig = sign(hash: hash, key: key, nonce: k) { return sig }
        }
    }

    /// Signs with a given nonce k (for demonstrations; nil if r or s would be 0).
    public static func sign(hash: [UInt8], key: ECKeyPair, nonce k: BigUInt) -> (r: BigUInt, s: BigUInt)? {
        let c = key.curve
        let n = c.n
        let e = hashToInteger(hash, curve: c) % n
        guard case let .affine(x1, _) = c.multiply(k, c.generator) else { return nil }
        let r = x1 % n
        if r.isZero { return nil }
        guard let kinv = k.inverse(modulo: n) else { return nil }
        let s = (kinv * ((e + key.d * r) % n)) % n
        if s.isZero { return nil }
        return (r, s)
    }

    /// Verifies a signature (r, s) of a hash value with the public point.
    public static func verify(hash: [UInt8], r: BigUInt, s: BigUInt, curve: EllipticCurve, publicKey: ECPoint) -> Bool {
        let n = curve.n
        guard !n.isZero, r > 0, r < n, s > 0, s < n else { return false }
        guard !publicKey.isInfinity, curve.contains(publicKey) else { return false }
        guard let w = s.inverse(modulo: n) else { return false }
        let e = hashToInteger(hash, curve: curve) % n
        let u1 = (e * w) % n
        let u2 = (r * w) % n
        guard case let .affine(x, _) = curve.multiplyAdd(u1, curve.generator, u2, publicKey) else { return false }
        return x % n == r
    }
}

/// Elliptic curve Diffie–Hellman.
public enum ECDH {
    /// x coordinate of d·Q. Throws if Q is not a valid point or the result is O.
    public static func sharedSecret(privateKey: BigUInt, publicKey: ECPoint, curve: EllipticCurve) throws -> BigUInt {
        guard !publicKey.isInfinity, curve.contains(publicKey) else {
            throw CTError("The public key is not a valid point on the curve.")
        }
        let S = curve.multiply(privateKey, publicKey)
        guard case let .affine(x, _) = S else {
            throw CTError("The shared secret is the point at infinity.")
        }
        return x
    }
}
