import Foundation
import CTCommon
import CTBigNum

/// Tests for the CT1 PKI additions: X9.62 curves, DSA, ECSP-NR.
func runCT1PKITests() {
    section("X9.62-Kurven (CT1)") {
        let expectedGy: [String: String] = [
            "prime192v1": "7192B95FFC8DA78631011ED6B24CDD573F977A11E794811",
            "prime192v2": "6574D11D69B6EC7A672BB82A083DF2F2B0847DE970B2DE15",
            "prime192v3": "38A90F22637337334B49DCB66A6DC8F9978ACA7648A943B0",
            "prime239v1": "7DEBE8E4E90A5DAE6E4054CA530BA04654B36818CE226B39FCCB7B02F1AE",
            "prime239v2": "5B0125E4DBEA0EC7206DA0FC01D9B081329FB555DE6EF460237DFF8BE4BA",
            "prime239v3": "1607E6898F390C06BC1D552BAD226F3B6FCFE48B6E818499AF18E3ED6CF3",
            "prime256v1": "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5",
        ]
        checkEqual(EllipticCurve.ct1Curves.count, 7)
        for c in EllipticCurve.ct1Curves {
            check(c.contains(c.generator), "\(c.name): G nicht auf der Kurve")
            check(c.multiply(c.n, c.generator).isInfinity, "\(c.name): n·G ≠ O")
            checkEqual(c.gy.toString(radix: 16), expectedGy[c.name] ?? "", c.name)
        }
        checkEqual(EllipticCurve.anyNamed("prime239v1")?.n.bitLength, 239)
        checkEqual(EllipticCurve.anyNamed("secp256r1")?.name, "secp256r1")
    }
    section("CT1 DSA (FIPS 186-2 Anhang 5)") {
        let h = { (s: String) in BigUInt(s, radix: 16)! }
        let dom = DSAParameters(p: h("8df2a494492276aa3d25759bb06869cbeac0d83afb8d0cf7cbb8324f0d7882e5d0762fc5b7210eafc2e9adac32ab7aac49693dfbf83724c2ec0736ee31c80291"),
                            q: h("c773218c737ec8ee993b4f2ded30f48edace915f"),
                            g: h("626d027839ea0a13413163a55b4cb500299d5522956cefcb3bff10f399ce2c2e71cb9de5fa24babf58e5b79521925c9cc42e9f6f464b088cc572af53e6d78802"))
        let key = DSAKeyPair(parameters: dom, x: h("2070b3223dba372fde1c0ffc7b2e3b498b260614"))
        let sha1abc: [UInt8] = [0xa9, 0x99, 0x3e, 0x36, 0x47, 0x06, 0x81, 0x6a, 0xba, 0x3e, 0x25, 0x71, 0x78, 0x50, 0xc2, 0x6c, 0x9c, 0xd0, 0xd8, 0x9d]
        let sig = DSA.sign(hash: sha1abc, key: key, nonce: h("358dad571462710f50e254cf1a376b2bdeaadfbf"))
        checkEqual(sig?.r.toString(radix: 16, uppercase: false), "8bac1ab66410435cb7181f95b16ab97c92b341c0")
        checkEqual(sig?.s.toString(radix: 16, uppercase: false), "41e2345f1f56df2458f426d155b4ba2db6dcd8c8")
        if let sig {
            check(DSA.verify(hash: sha1abc, r: sig.r, s: sig.s, parameters: dom, publicKey: key.y))
            check(!DSA.verify(hash: [0] + sha1abc.dropFirst(), r: sig.r, s: sig.s, parameters: dom, publicKey: key.y))
            let der = DSA.derEncode(r: sig.r, s: sig.s)
            let back = DSA.derDecode(der)
            checkEqual(back?.r, sig.r); checkEqual(back?.s, sig.s)
        }
        let gen = DSA.generateParameters(L: 512, N: 160)
        checkEqual(gen.p.bitLength, 512); checkEqual(gen.q.bitLength, 160)
        checkEqual((gen.p - 1) % gen.q, BigUInt(0))
        checkEqual(gen.g.power(gen.q, modulus: gen.p), BigUInt(1))
        let k2 = DSA.generateKey(parameters: gen)
        let s2 = DSA.sign(hash: sha1abc, key: k2)
        check(DSA.verify(hash: sha1abc, r: s2.r, s: s2.s, parameters: gen, publicKey: k2.y))
    }
    section("CT1 ECSP-NR / ECSP-DSA auf prime239v1") {
        let c = EllipticCurve.prime239v1
        let key = ECKeyPair.generate(curve: c)
        let hash: [UInt8] = (0..<20).map { UInt8($0 * 7 & 0xFF) }
        let nr = ECNR.sign(hash: hash, key: key)
        check(ECNR.verify(hash: hash, c: nr.c, d: nr.d, curve: c, publicKey: key.Q))
        var bad = hash; bad[0] ^= 1
        check(!ECNR.verify(hash: bad, c: nr.c, d: nr.d, curve: c, publicKey: key.Q))
        let other = ECKeyPair.generate(curve: c)
        check(!ECNR.verify(hash: hash, c: nr.c, d: nr.d, curve: c, publicKey: other.Q))
        let ds = ECDSA.sign(hash: hash, key: key)
        check(ECDSA.verify(hash: hash, r: ds.r, s: ds.s, curve: c, publicKey: key.Q))
    }
}
