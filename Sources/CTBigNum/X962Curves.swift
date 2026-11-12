import CTCommon

// ANSI X9.62-1998 prime curves (Annex J.5) as used by CrypTool 1 (EC-Param.ini):
// prime192v1 … prime256v1, default prime239v1. The base point G is given compressed
// (02/03 ‖ x) in CT1; the y coordinate is recovered here.

extension EllipticCurve {
    private static func hx(_ s: String) -> BigUInt { BigUInt(s.replacingOccurrences(of: " ", with: ""), radix: 16)! }

    /// Builds a curve from X9.62 data with a compressed base point (`yOdd` = prefix 03).
    private static func x962(_ name: String, p: BigUInt, b: String, gx: String, yOdd: Bool, r: String) -> EllipticCurve {
        let a = p - 3
        let bb = hx(b), x = hx(gx)
        var c = EllipticCurve(name: name, p: p, a: a, b: bb, gx: x, gy: 0, n: hx(r), h: 1)
        guard case let .affine(_, y0)? = c.lift(x: x) else { preconditionFailure("X9.62-Basispunkt ungültig") }
        c.gy = (y0.isOdd == yOdd) ? y0 : (p - y0) % p
        return c
    }

    private static let p192 = hx("FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFE FFFFFFFF FFFFFFFF")
    private static let p239 = BigUInt("883423532389192164791648750360308885314476597252960362792450860609699839")!
    private static let p256 = hx("FFFFFFFF 00000001 00000000 00000000 00000000 FFFFFFFF FFFFFFFF FFFFFFFF")

    public static let prime192v1 = x962("prime192v1", p: p192,
        b: "64210519 E59C80E7 0FA7E9AB 72243049 FEB8DEEC C146B9B1",
        gx: "188DA80E B03090F6 7CBF20EB 43A18800 F4FF0AFD 82FF1012", yOdd: true,
        r: "FFFFFFFF FFFFFFFF FFFFFFFF 99DEF836 146BC9B1 B4D22831")
    public static let prime192v2 = x962("prime192v2", p: p192,
        b: "CC22D6DF B95C6B25 E49C0D63 64A4E598 0C393AA2 1668D953",
        gx: "EEA2BAE7 E1497842 F2DE7769 CFE9C989 C072AD69 6F48034A", yOdd: true,
        r: "FFFFFFFF FFFFFFFF FFFFFFFE 5FB1A724 DC804186 48D8DD31")
    public static let prime192v3 = x962("prime192v3", p: p192,
        b: "22123DC2 395A05CA A7423DAE CCC94760 A7D46225 6BD56916",
        gx: "7D297781 00C65A1D A1783716 588DCE2B 8B4AEE8E 228F1896", yOdd: false,
        r: "FFFFFFFF FFFFFFFF FFFFFFFF 7A62D031 C83F4294 F640EC13")
    public static let prime239v1 = x962("prime239v1", p: p239,
        b: "6B01 6C3BDCF1 8941D0D6 54921475 CA71A9DB 2FB27D1D 37796185 C2942C0A",
        gx: "0FFA 963CDCA8 816CCC33 B8642BED F905C3D3 58573D3F 27FBBD3B 3CB9AAAF", yOdd: false,
        r: "7FFF FFFFFFFF FFFFFFFF FFFF7FFF FF9E5E9A 9F5D9071 FBD15226 88909D0B")
    public static let prime239v2 = x962("prime239v2", p: p239,
        b: "617F AB683257 6CBBFED5 0D99F024 9C3FEE58 B94BA003 8C7AE84C 8C832F2C",
        gx: "38AF 09D98727 705120C9 21BB5E9E 26296A3C DCF2F357 57A0EAFD 87B830E7", yOdd: false,
        r: "7FFF FFFFFFFF FFFFFFFF FFFF8000 00CFA7E8 594377D4 14C03821 BC582063")
    public static let prime239v3 = x962("prime239v3", p: p239,
        b: "2557 05FA2A30 6654B1F4 CB03D6A7 50A30C25 0102D498 8717D9BA 15AB6D3E",
        gx: "6768 AE8E18BB 92CFCF00 5C949AA2 C6D94853 D0E660BB F854B1C9 505FE95A", yOdd: true,
        r: "7FFF FFFFFFFF FFFFFFFF FFFF7FFF FF975DEB 41B3A605 7C3C4321 46526551")
    public static let prime256v1 = x962("prime256v1", p: p256,
        b: "5AC635D8 AA3A93E7 B3EBBD55 769886BC 651D06B0 CC53B0F6 3BCE3C3E 27D2604B",
        gx: "6B17D1F2 E12C4247 F8BCE6E5 63A440F2 77037D81 2DEB33A0 F4A13945 D898C296", yOdd: true,
        r: "FFFFFFFF 00000000 FFFFFFFF FFFFFFFF BCE6FAAD A7179E84 F3B9CAC2 FC632551")

    /// The curve list of CT1's key generation dialog (CURVE_ID_LIST of EC-Param.ini).
    public static var ct1Curves: [EllipticCurve] {
        [prime192v1, prime192v2, prime192v3, prime239v1, prime239v2, prime239v3, prime256v1]
    }

    /// CT1 default curve (SELECT_DEFAULT_CURVE_ID).
    public static let ct1DefaultCurveName = "prime239v1"

    /// Looks up a CT1 X9.62 curve or any other built-in named curve.
    public static func anyNamed(_ name: String) -> EllipticCurve? {
        ct1Curves.first { $0.name.lowercased() == name.lowercased() } ?? named(name)
    }
}
