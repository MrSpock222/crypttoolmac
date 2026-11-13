// Test runner for CTModern / CTCipherC (plain executable, see Package.swift).
//   swift run --scratch-path .build-modern -c release CTModernTests
import CTCipherC
import CTCommon
import CTModern
import Foundation

var passed = 0
var failed = 0
var section = ""

func begin(_ name: String) { section = name; print("▸ \(name)") }

func check(_ cond: Bool, _ what: @autoclosure () -> String) {
    if cond { passed += 1 } else { failed += 1; print("  FAIL [\(section)] \(what())") }
}

func checkEq(_ a: [UInt8], _ b: [UInt8], _ what: @autoclosure () -> String) {
    check(a == b, "\(what()): got \(Hex.encode(a, separator: "")) expected \(Hex.encode(b, separator: ""))")
}

func checkThrows(_ what: String, _ f: () throws -> Void) {
    do { try f(); check(false, "\(what): no error thrown") } catch { check(true, what) }
}

func h(_ s: String) -> [UInt8] {
    guard let v = Hex.decode(s) else { fatalError("bad hex in test: \(s)") }
    return v
}

func b(_ s: String) -> [UInt8] { Array(s.utf8) }

/// Runs a shell command, returns (status, stdout+stderr).
@discardableResult
func shell(_ args: [String], cwd: URL? = nil) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: args[0])
    p.arguments = Array(args.dropFirst())
    if let cwd { p.currentDirectoryURL = cwd }
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}

/// Scratch directory for files written by the tests.
let scratch: URL = {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("CTModernTests-\(getpid())")
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}()

// MARK: - Block cipher primitives (official vectors)

begin("AES (FIPS-197 C.1–C.3)")
do {
    let pt = h("00112233445566778899aabbccddeeff")
    let vectors: [(String, String)] = [
        ("000102030405060708090a0b0c0d0e0f", "69c4e0d86a7b0430d8cdb78070b4c55a"),
        ("000102030405060708090a0b0c0d0e0f1011121314151617", "dda97ca4864cdfe06eaf70a0ec0d7191"),
        ("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", "8ea2b7ca516745bfeafc49904b496089"),
    ]
    for (k, c) in vectors {
        checkEq(try SymmetricCipher.encryptRaw(.aes, key: h(k), data: pt), h(c), "AES-\(k.count * 4)")
    }
}

begin("DES / Triple DES")
do {
    checkEq(try SymmetricCipher.encryptRaw(.desECB, key: h("133457799BBCDFF1"), data: h("0123456789ABCDEF")),
            h("85E813540F0AB405"), "DES classic vector")
    // FIPS 81 / NBS: key 0123456789ABCDEF, "Now is the time for all " ECB
    checkEq(try SymmetricCipher.encryptRaw(.desECB, key: h("0123456789ABCDEF"), data: b("Now is the time for all ")),
            h("3FA40E8A984D48156A271787AB8883F9893D51EC4B563B53"), "DES FIPS 81 ECB")
    do { // FIPS 81 CBC uses IV 1234567890ABCDEF – with zero IV: XOR the IV into the first block
        var p = b("Now is the time for all ")
        let iv = h("1234567890ABCDEF")
        for i in 0..<8 { p[i] ^= iv[i] }
        checkEq(try SymmetricCipher.encryptRaw(.desCBC, key: h("0123456789ABCDEF"), data: p),
                h("E5C7CDDE872BF27C43E934008C389C0F683788499A7C05F6"), "DES FIPS 81 CBC")
    }
    // Two-key 3DES = E_K1(D_K2(E_K1(P)))
    let k1 = h("0123456789ABCDEF"), k2 = h("FEDCBA9876543210"), p = h("4E6F772069732074")
    let e1 = try SymmetricCipher.encryptRaw(.desECB, key: k1, data: p)
    let d2 = try SymmetricCipher.decryptRaw(.desECB, key: k2, data: e1 + [])
    let ede = try SymmetricCipher.encryptRaw(.desECB, key: k1, data: d2)
    checkEq(try SymmetricCipher.encryptRaw(.tripleDESECB, key: k1 + k2, data: p), ede, "2-key 3DES EDE")
    let k3 = h("89ABCDEF01234567")
    let e3 = try SymmetricCipher.encryptRaw(.desECB, key: k3,
                                            data: try SymmetricCipher.decryptRaw(.desECB, key: k2, data: e1))
    checkEq(try SymmetricCipher.encryptRaw(.tripleDESECB, key: k1 + k2 + k3, data: p), e3, "3-key 3DES EDE")
}

begin("C DES/3DES (brute-force fast path) == CommonCrypto")
do {
    var x: UInt64 = 987654321
    func rnd(_ n: Int) -> [UInt8] { (0..<n).map { _ in x = x &* 6364136223846793005 &+ 1442695040888963407; return UInt8(truncatingIfNeeded: x >> 37) } }
    for (alg, kl, cbc) in [(SymmetricAlgorithm.desECB, 8, Int32(0)), (.desCBC, 8, 1), (.tripleDESECB, 16, 0), (.tripleDESCBC, 16, 1), (.tripleDESCBC, 24, 1)] {
        for _ in 0..<25 {
            let k = rnd(kl), p = rnd(40)
            let ref = try SymmetricCipher.encryptRaw(alg, key: k, data: p)
            var out = [UInt8](repeating: 0, count: 40), back = [UInt8](repeating: 0, count: 40)
            check(ctc_des_crypt(0, cbc, k, k.count, nil, p, &out, 40) == CTC_OK, "status")
            checkEq(out, ref, "C \(alg) kl=\(kl) encrypt")
            check(ctc_des_crypt(1, cbc, k, k.count, nil, out, &back, 40) == CTC_OK, "status")
            checkEq(back, p, "C \(alg) kl=\(kl) decrypt")
        }
    }
}

begin("DESX / DESL / DESXL (CT1 DESXL.cpp port)")
do {
    // DESX with zero whitening keys == DES-CBC (CommonCrypto)
    let data = b("Dies ist ein Test fuer DESX!!!!!")
    let k = h("133457799BBCDFF1")
    checkEq(try SymmetricCipher.encryptRaw(.desx, key: k + [UInt8](repeating: 0, count: 16), data: data),
            try SymmetricCipher.encryptRaw(.desCBC, key: k, data: data), "DESX(0,0) == DES-CBC")
    // Independent bit-level reference (FIPS 46 tables + DESL S-box, scratchpad des_ref.py)
    let pt = h("0123456789abcdeffedcba98765432100011223344556677")
    let ref: [(SymmetricAlgorithm, String, String)] = [
        (.desl, "0123456789abcdef", "d4ea41681aee771f469e0bc77dcbc567c3cb235b1116ee47"),
        (.desl, "133457799bbcdff1", "cf245c04cce076612bda81b07e2aa0723a35e278aa7d6b56"),
        (.desl, "0000000000000000", "f9e32a0d27ef6a88bf181400dd3f01c4be53d204a543a2c3"),
        (.desx, "0123456789abcdef112233445566778899aabbccddeeff00", "ba7d3eb884cab215ec6423acec31287922c45422cad3aba9"),
        (.desxl, "0123456789abcdef112233445566778899aabbccddeeff00", "d3f5e40c86815d99c02faf4309a82582bb86ea64564eae59"),
        (.desxl, "133457799bbcdff10000000000000000ffffffffffffffff", "30dba3fb331f899e27d62c219ddeacbbc90a5a21540fd410"),
    ]
    for (alg, key, ct) in ref {
        checkEq(try SymmetricCipher.encryptRaw(alg, key: h(key), data: pt), h(ct), "\(alg.displayName) \(key)")
        checkEq(try SymmetricCipher.decryptRaw(alg, key: h(key), data: h(ct) + h("0000000000000000")).prefix(24).map { $0 }, pt,
                "\(alg.displayName) decrypt \(key)")
    }
}

begin("IDEA (Crypto++ ideaval.dat)")
do {
    let vectors = """
    00010002000300040005000600070008  0000000100020003  11FBED2B01986DE5
    00010002000300040005000600070008  0102030405060708  540E5FEA18C2F8B1
    00010002000300040005000600070008  0019324B647D96AF  9F0A0AB6E10CED78
    00010002000300040005000600070008  F5202D5B9C671B08  CF18FD7355E2C5C5
    00010002000300040005000600070008  FAE6D2BEAA96826E  85DF52005608193D
    00010002000300040005000600070008  0A141E28323C4650  2F7DE750212FB734
    00010002000300040005000600070008  050A0F14191E2328  7B7314925DE59C09
    0005000A000F00140019001E00230028  0102030405060708  3EC04780BEFF6E20
    3A984E2000195DB32EE501C8C47CEA60  0102030405060708  97BCD8200780DA86
    006400C8012C019001F4025802BC0320  05320A6414C819FA  65BE87E7A2538AED
    9D4075C103BC322AFB03E7BE6AB30006  0808080808080808  F5DB1AC45E5EF9F9
    """
    for line in vectors.split(separator: "\n") {
        let f = line.split(separator: " ").map(String.init)
        checkEq(try SymmetricCipher.encryptRaw(.idea, key: h(f[0]), data: h(f[1])), h(f[2]), "IDEA enc \(f[0]) \(f[1])")
        checkEq(try SymmetricCipher.decryptRaw(.idea, key: h(f[0]), data: h(f[2])), h(f[1]), "IDEA dec \(f[0]) \(f[2])")
    }
}

begin("RC2 (RFC 2268 section 5)")
do {
    let vectors: [(String, Int32, String, String)] = [
        ("0000000000000000", 63, "0000000000000000", "ebb773f993278eff"),
        ("ffffffffffffffff", 64, "ffffffffffffffff", "278b27e42e2f0d49"),
        ("3000000000000000", 64, "1000000000000001", "30649edf9be7d2c2"),
        ("88", 64, "0000000000000000", "61a8a244adacccf0"),
        ("88bca90e90875a", 64, "0000000000000000", "6ccf4308974c267f"),
        ("88bca90e90875a7f0f79c384627bafb2", 64, "0000000000000000", "1a807d272bbe5db1"),
        ("88bca90e90875a7f0f79c384627bafb2", 128, "0000000000000000", "2269552ab0f85ca6"),
        ("88bca90e90875a7f0f79c384627bafb216f80a6f85920584c42fceb0be255daf1e", 129, "0000000000000000", "5b78d3a43dfff1f1"),
    ]
    for (k, eff, p, c) in vectors {
        let key = h(k), pt = h(p)
        var out = [UInt8](repeating: 0, count: 8)
        var back = [UInt8](repeating: 0, count: 8)
        check(ctc_rc2_crypt(0, 0, key, key.count, eff, nil, pt, &out, 8) == CTC_OK, "RC2 status")
        checkEq(out, h(c), "RC2 \(k) eff=\(eff)")
        check(ctc_rc2_crypt(1, 0, key, key.count, eff, nil, out, &back, 8) == CTC_OK, "RC2 status")
        checkEq(back, pt, "RC2 decrypt \(k)")
    }
    // public API uses effective bits = 8 * key length
    checkEq(try SymmetricCipher.encryptRaw(.rc2, key: h("88bca90e90875a7f0f79c384627bafb2"), data: h("0000000000000000")),
            h("2269552ab0f85ca6"), "RC2 public API (eff = 128)")
}

begin("RC4 (RFC 6229, classic vectors)")
do {
    checkEq(try SymmetricCipher.encrypt(.rc4, key: h("0102030405"), data: [UInt8](repeating: 0, count: 32)),
            h("b2396305f03dc027ccc3524a0a1118a86982944f18fc82d589c403a47a0d0919"), "RFC 6229 40-bit key")
    checkEq(try SymmetricCipher.encrypt(.rc4, key: b("Key"), data: b("Plaintext")), h("BBF316E8D940AF0AD3"), "Key/Plaintext")
    checkEq(try SymmetricCipher.encrypt(.rc4, key: b("Wiki"), data: b("pedia")), h("1021BF0420"), "Wiki/pedia")
    checkEq(try SymmetricCipher.encrypt(.rc4, key: b("Secret"), data: b("Attack at dawn")), h("45A01F645FC35B383552544B9BF5"), "Secret")
}

begin("MARS (Crypto++ marsval.dat / AES submission KAT)")
do {
    let vectors = """
    00000000000000000000000000000000   00000000000000000000000000000000   DCC07B8DFB0738D6E30A22DFCF27E886
    00000000000000000000000000000000   DCC07B8DFB0738D6E30A22DFCF27E886   33CAFFBDDC7F1DDA0F9C15FA2F30E2FF
    CB14A1776ABBC1CDAFE7243DEF2CEA02   F94512A9B42D034EC4792204D708A69B   225DA2CB64B73F79069F21A5E3CB8522
    86EDF4DA31824CABEF6A4637C40B0BAB   4DF955AD5B398D66408D620A2B27E1A9   A4B737340AE6D2CAFD930BA97D86129F
    000000000000000000000000000000000000000000000000   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   97778747D60E425C2B4202599DB856FB
    D158860838874D9500000000000000000000000000000000   93A953A82C10411DD158860838874D95   4FA0E5F64893131712F01408D233E9F7
    791739A58B04581A93A953A82C10411DD158860838874D95   6761C42D3E6142D2A84FBFADB383158F   F706BC0FD97E28B6F1AF4E17D8755FFF
    0000000000000000000000000000000000000000000000000000000000000000   62E45B4CF3477F1DD65063729D9ABA8F   0F4B897EA014D21FBC20F1054A42F719
    FBA167983E7AEF22317CE28C02AAE1A3E8E5CC3CEDBEA82A99DBC39AD65E7227   1344ABA4D3C44708A8A72116D4F49384   458335D95EA42A9F4DCCD41AECC2390D
    80000000000000000000000000000000   00000000000000000000000000000000   B3E2AD5608AC1B6733A7CB4FDF8F9952
    """
    for line in vectors.split(separator: "\n") {
        let f = line.split(separator: " ").map(String.init)
        checkEq(try SymmetricCipher.encryptRaw(.mars, key: h(f[0]), data: h(f[1])), h(f[2]), "MARS enc \(f[0].prefix(16))…")
        checkEq(try SymmetricCipher.decryptRaw(.mars, key: h(f[0]), data: h(f[2])), h(f[1]), "MARS dec \(f[0].prefix(16))…")
    }
}

begin("RC6 (Crypto++ rc6val.dat / RC6 paper)")
do {
    let vectors = """
    00000000000000000000000000000000 00000000000000000000000000000000 8FC3A53656B1F778C129DF4E9848A41E
    0123456789ABCDEF0112233445566778 02132435465768798A9BACBDCEDFE0F1 524E192F4715C6231F51F6367EA43F18
    000000000000000000000000000000000000000000000000 00000000000000000000000000000000 6cd61bcb190b30384e8a3f168690ae82
    0123456789abcdef0112233445566778899aabbccddeeff0 02132435465768798a9bacbdcedfe0f1 688329d019e505041e52e92af95291d4
    0000000000000000000000000000000000000000000000000000000000000000 00000000000000000000000000000000 8f5fbd0510d15fa893fa3fda6e857ec2
    0123456789abcdef0112233445566778899aabbccddeeff01032547698badcfe 02132435465768798a9bacbdcedfe0f1 c8241816f0d7e48920ad16a1674e5d48
    """
    for line in vectors.split(separator: "\n") {
        let f = line.split(separator: " ").map(String.init)
        checkEq(try SymmetricCipher.encryptRaw(.rc6, key: h(f[0]), data: h(f[1])), h(f[2]), "RC6 enc \(f[0].prefix(16))…")
        checkEq(try SymmetricCipher.decryptRaw(.rc6, key: h(f[0]), data: h(f[2])), h(f[1]), "RC6 dec \(f[0].prefix(16))…")
    }
}

begin("Twofish (Crypto++ twofishv.dat / Twofish paper)")
do {
    let vectors = """
    00000000000000000000000000000000  00000000000000000000000000000000  9F589F5CF6122C32B6BFEC2F2AE8C35A
    00000000000000000000000000000000  9F589F5CF6122C32B6BFEC2F2AE8C35A  D491DB16E7B1C39E86CB086B789F5419
    9F589F5CF6122C32B6BFEC2F2AE8C35A  D491DB16E7B1C39E86CB086B789F5419  019F9809DE1711858FAAC3A3BA20FBC3
    D491DB16E7B1C39E86CB086B789F5419  019F9809DE1711858FAAC3A3BA20FBC3  6363977DE839486297E661C6C9D668EB
    000000000000000000000000000000000000000000000000  00000000000000000000000000000000  EFA71F788965BD4453F860178FC19101
    EFA71F788965BD4453F860178FC191010000000000000000  88B2B2706B105E36B446BB6D731A1E88  39DA69D6BA4997D585B6DC073CA341B2
    88B2B2706B105E36B446BB6D731A1E88EFA71F788965BD44  39DA69D6BA4997D585B6DC073CA341B2  182B02D81497EA45F9DAACDC29193A65
    0000000000000000000000000000000000000000000000000000000000000000  00000000000000000000000000000000  57FF739D4DC92C1BD7FC01700CC8216F
    D43BB7556EA32E46F2A282B7D45B4E0D57FF739D4DC92C1BD7FC01700CC8216F  90AFE91BB288544F2C32DC239B2635E6  6CB4561C40BF0A9705931CB6D408E7FA
    """
    for line in vectors.split(separator: "\n") {
        let f = line.split(separator: " ").map(String.init)
        checkEq(try SymmetricCipher.encryptRaw(.twofish, key: h(f[0]), data: h(f[1])), h(f[2]), "Twofish enc \(f[0].prefix(16))…")
        checkEq(try SymmetricCipher.decryptRaw(.twofish, key: h(f[0]), data: h(f[2])), h(f[1]), "Twofish dec \(f[0].prefix(16))…")
    }
}

begin("Serpent (Crypto++ serpentv.dat incl. NESSIE set 1 #0)")
do {
    // The AES submission API used by CT1 reads the hex key as one big-endian number, i.e. the
    // CT1 key bytes are the reverse of the usual (NESSIE/Crypto++) byte order.
    let vectors = """
    00000000000000000000000000000000  d29d576fcea3a3a7ed9099f29273d78e  b2288b968ae8b08648d1ce9606fd992d
    00000000000000000000000000000000  d29d576fcea3a3a7ed9099f26d8c2871  563a8403ff5309d62370b1dcf5a11edd
    ffeeddccbbaa99887766554433221100  1032547698badcfeefcdab8967452301  d5baa00a4bb9d8a7c981c8dc90d89d92
    ffeeddccbbaa99887766554433221100  145f0b8b663176b95dcab7e9dcd5cc24  1032547698badcfeefcdab8967452301
    80000000000000000000000000000000  00000000000000000000000000000000  264E5481EFF42A4606ABDA06C0BFDA3D
    000000000000000000000000000000000000000000000000  d29d576fceaba3a7ed9899f2927bd78e  130e353e1037c22405e8faefb2c3c3e9
    8899aabbccddeeffffeeddccbbaa99887766554433221100  1032547698badcfeefcdab8967452301  da860842b720802bf404a4c71034879a
    8899aabbccddeeffffeeddccbbaa99887766554433221100  b2696bd0d98c17953e4239225d27202c  1032547698badcfeefcdab8967452301
    000102030405060708090A0B0C0D0E0F1011121314151617  4528CACCB954D450655E8CFD71CBFAC7  00112233445566778899AABBCCDDEEFF
    0000000000000000000000000000000000000000000000000000000000000000  92074732d84e1841a013a0034c52bf50  81c4eb7b8ad9a8d0f2aa5d7bd626b560
    00112233445566778899aabbccddeeffffeeddccbbaa99887766554433221100  1032547698badcfeefcdab8967452301  93df9a3cafe387bd999eebe393a17fca
    000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F  3DA46FFA6F4D6F30CD258333E5A61369  00112233445566778899AABBCCDDEEFF
    """
    for line in vectors.split(separator: "\n") {
        let f = line.split(separator: " ").map(String.init)
        let key = Array(h(f[0]).reversed())
        checkEq(try SymmetricCipher.encryptRaw(.serpent, key: key, data: h(f[1])), h(f[2]), "Serpent enc \(f[0].prefix(16))…")
        checkEq(try SymmetricCipher.decryptRaw(.serpent, key: key, data: h(f[2])), h(f[1]), "Serpent dec \(f[0].prefix(16))…")
    }
}

// MARK: - CT1 conventions (padding, CBC, round trips)

begin("CT1 padding / CBC / round trips")
do {
    let msg = b("CrypTool – Lernen und Erfahren von Kryptografie. ")
    for alg in SymmetricAlgorithm.allCases {
        for bits in alg.keySizesBits where bits <= 256 && (bits % 64 == 0 || alg == .rc2 || alg == .rc4) {
            let key = (0..<(bits / 8)).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) }
            for len in [0, 1, 15, 16, 17, msg.count] {
                let data = Array(msg.prefix(len)) + (len > msg.count ? [] : [])
                do {
                    let c = try SymmetricCipher.encrypt(alg, key: key, data: data)
                    if alg.usesCT1Padding { check(c.count == (data.count / 16 + 1) * 16, "\(alg) CT1 padded length") }
                    else if alg.usesZeroPadding {
                        // SECUDE desECB/desEDE: zero padding, cannot be removed
                        check(c.count == (data.count + 7) / 8 * 8, "\(alg) zero padded length")
                        if c.isEmpty { continue }
                        let p = try SymmetricCipher.decrypt(alg, key: key, data: c)
                        checkEq(p, data + [UInt8](repeating: 0, count: c.count - data.count), "\(alg.displayName) \(bits) bit round trip len \(len)")
                        continue
                    }
                    else if alg.blockSize > 0 { check(c.count == (data.count / alg.blockSize + 1) * alg.blockSize, "\(alg) PKCS7/X.923 length") }
                    else { check(c.count == data.count, "\(alg) stream length") }
                    let p = try SymmetricCipher.decrypt(alg, key: key, data: c)
                    checkEq(p, data, "\(alg.displayName) \(bits) bit round trip len \(len)")
                } catch {
                    check(false, "\(alg.displayName) \(bits) bit len \(len): \(error)")
                }
            }
        }
    }
    // CT1 padding layout & zero-IV CBC: AES of "A" == raw AES-CBC of 41 01 00…
    let k = h("000102030405060708090a0b0c0d0e0f")
    checkEq(try SymmetricCipher.encrypt(.aes, key: k, data: b("A")),
            try SymmetricCipher.encryptRaw(.aes, key: k, data: h("41010000000000000000000000000000")), "CT1 padding layout")
    // CBC chaining with zero IV: second block = E(P2 xor C1)
    let two = try SymmetricCipher.encryptRaw(.serpent, key: k, data: [UInt8](repeating: 0x55, count: 32))
    let first = try SymmetricCipher.encryptRaw(.serpent, key: k, data: [UInt8](repeating: 0x55, count: 16))
    let second = try SymmetricCipher.encryptRaw(.serpent, key: k, data: zip(first, [UInt8](repeating: 0x55, count: 16)).map { $0 ^ $1 })
    checkEq(two, first + second, "Serpent CBC chaining")
    // errors
    checkThrows("wrong AES key size") { _ = try SymmetricCipher.encrypt(.aes, key: [1, 2, 3], data: [1]) }
    checkThrows("ciphertext length") { _ = try SymmetricCipher.decrypt(.mars, key: k, data: [1, 2, 3]) }
    checkThrows("bad CT1 padding") { _ = try SymmetricCipher.decrypt(.aes, key: k, data: try SymmetricCipher.encryptRaw(.aes, key: k, data: [UInt8](repeating: 7, count: 16))) }
    checkThrows("bad PKCS7 padding") { _ = try SymmetricCipher.decrypt(.idea, key: k, data: try SymmetricCipher.encryptRaw(.idea, key: k, data: [UInt8](repeating: 0, count: 8))) }
    checkThrows("IDEA key size") { _ = try SymmetricCipher.encrypt(.idea, key: [UInt8](repeating: 0, count: 8), data: [1]) }
    // large buffer (> 1 MiB chunk in the C wrappers)
    let big = (0..<(3 * 1024 * 1024 + 5)).map { UInt8(truncatingIfNeeded: $0 &* 7) }
    for alg in [SymmetricAlgorithm.mars, .twofish, .aes] {
        let c = try SymmetricCipher.encrypt(alg, key: k, data: big)
        check(try SymmetricCipher.decrypt(alg, key: k, data: c) == big, "\(alg) 3 MiB round trip")
    }
}


// MARK: - Python reference helper

/// Runs `python3 -I -c script` with `input` on stdin; nil if Python is unavailable.
func python(_ script: String, input: String) -> String? {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return nil }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    p.arguments = ["-I", "-c", script]
    let inPipe = Pipe(), outPipe = Pipe()
    p.standardInput = inPipe
    p.standardOutput = outPipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let writer = Thread { inPipe.fileHandleForWriting.write(Data(input.utf8)); try? inPipe.fileHandleForWriting.close() }
    writer.start()
    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return p.terminationStatus == 0 ? String(decoding: out, as: UTF8.self) : nil
}

/// Deterministic test messages of many lengths (padding boundaries etc.).
let testMessages: [[UInt8]] = {
    var lens = Array(0...3) + [55, 56, 57, 63, 64, 65, 111, 112, 119, 120, 127, 128, 129, 200, 1000, 4097]
    lens.append(100_003)
    return lens.map { n in (0..<n).map { UInt8(truncatingIfNeeded: $0 &* 131 &+ n &* 7 &+ 3) } }
}()

// MARK: - Hashes

begin("Hashes (RFC 1319/1320/1321, FIPS 180, RIPEMD-160 paper)")
do {
    let rfcStrings = ["", "a", "abc", "message digest", "abcdefghijklmnopqrstuvwxyz",
                      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
                      String(repeating: "1234567890", count: 8)]
    let md2 = ["8350e5a3e24c153df2275c9f80692773", "32ec01ec4a6dac72c0ab96fb34c0b5d1", "da853b0d3f88d99b30283a69e6ded6bb",
               "ab4f496bfb2a530b219ff33031fe06b0", "4e8ddff3650292ab5a4108c3aa47940b", "da33def2a42df13975352846c30338cd",
               "d5976f79d83d3a0dc9806c3c66f3efd8"]
    let md4 = ["31d6cfe0d16ae931b73c59d7e0c089c0", "bde52cb31de33e46245e05fbdbd6fb24", "a448017aaf21d8525fc10ae87aa6729d",
               "d9130a8164549fe818874806e1c7014b", "d79e1c308aa5bbcdeea8ed63df412da9", "043f8582f241db351ce627e153e7f0e4",
               "e33b4ddc9c38f2199c3e7b164fcc0536"]
    let md5 = ["d41d8cd98f00b204e9800998ecf8427e", "0cc175b9c0f1b6a831c399e269772661", "900150983cd24fb0d6963f7d28e17f72",
               "f96b697d7cb7938d525a2f31aaf161d0", "c3fcd3d76192e4007dfb496cca67e13b", "d174ab98d277d9f5a5611c2c9f419d9f",
               "57edf4a22be3c955ac49da2e2107b67a"]
    let rmd = ["9c1185a5c5e9fc54612808977ee8f548b2258d31", "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe",
               "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc", "5d0689ef49d2fae572b881b123a85ffa21595f36",
               "f71c27109c692c1b56bbdceb5b9d2865b3708dbc", "b0e20b6e3116640286ed3a87a5713079b21f5189",
               "9b752e45573d4b39f4dbd3323cab82bf63326bfb"]
    for (i, s) in rfcStrings.enumerated() {
        checkEq(Hashing.hash(s, algorithm: .md2), h(md2[i]), "MD2(\"\(s.prefix(10))\")")
        checkEq(Hashing.hash(s, algorithm: .md4), h(md4[i]), "MD4(\"\(s.prefix(10))\")")
        checkEq(Hashing.hash(s, algorithm: .md5), h(md5[i]), "MD5(\"\(s.prefix(10))\")")
        checkEq(Hashing.hash(s, algorithm: .ripemd160), h(rmd[i]), "RIPEMD-160(\"\(s.prefix(10))\")")
    }
    // SHA-0 (FIPS 180 [1993] examples) and SHA-1 (FIPS 180-1)
    let abcdb = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    checkEq(Hashing.hash("abc", algorithm: .sha0), h("0164b8a914cd2a5e74c4f7ff082c4d97f1edf880"), "SHA-0(abc)")
    checkEq(Hashing.hash(abcdb, algorithm: .sha0), h("d2516ee1acfa5baf33dfc1c471e438449ef134c8"), "SHA-0(abcdbcd…)")
    checkEq(Hashing.hash(String(repeating: "a", count: 1_000_000), algorithm: .sha0),
            h("3232affa48628a26653b5aaa44541fd90d690603"), "SHA-0(1 000 000 × a)")
    checkEq(Hashing.hash("abc", algorithm: .sha1), h("a9993e364706816aba3e25717850c26c9cd0d89d"), "SHA-1(abc)")
    checkEq(Hashing.hash(abcdb, algorithm: .ripemd160), h("12a053384a9c0c88e405a06c27dcf49ada62eb2b"), "RIPEMD-160(abcdbcd…)")
    checkEq(Hashing.hash(String(repeating: "a", count: 1_000_000), algorithm: .ripemd160),
            h("52783243c1697bdbe16d37f97f68f08325dc1528"), "RIPEMD-160(1 000 000 × a)")
    checkEq(Hashing.hash("abc", algorithm: .sha256), h("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"), "SHA-256(abc)")
    for alg in HashAlgorithm.allCases {
        check(Hashing.hash([1, 2, 3], algorithm: alg).count == alg.digestLength, "\(alg) digest length")
    }

    // Cross-check with Python hashlib for many lengths
    let algs: [HashAlgorithm] = [.md4, .md5, .sha1, .sha256, .sha512, .ripemd160]
    let pyNames: [HashAlgorithm: String] = [.md4: "md4", .md5: "md5", .sha1: "sha1", .sha256: "sha256", .sha512: "sha512", .ripemd160: "ripemd160"]
    var req = ""
    for m in testMessages { for a in algs { req += "\(pyNames[a]!) \(Hex.encode(m, separator: ""))\n" } }
    let script = "import sys,hashlib\nfor l in sys.stdin:\n p=l.split()\n d=bytes.fromhex(p[1]) if len(p)>1 else b''\n print(hashlib.new(p[0],d).hexdigest())"
    if let out = python(script, input: req) {
        let expected = out.split(separator: "\n").map(String.init)
        var k = 0
        for m in testMessages {
            for a in algs {
                checkEq(Hashing.hash(m, algorithm: a), h(expected[k]), "\(a.displayName) len \(m.count) vs Python")
                k += 1
            }
        }
    } else { print("  (Python nicht verfügbar – Querprüfung übersprungen)") }
}

begin("Hash throughput (8 MiB, info only)")
do {
    let big = [UInt8](repeating: 0x61, count: 8 << 20)
    var line = " "
    for alg in HashAlgorithm.allCases {
        let t0 = Date()
        _ = Hashing.hash(big, algorithm: alg)
        line += String(format: " %@ %.0f MB/s", alg.displayName, 8.0 / Date().timeIntervalSince(t0))
    }
    print(line)
}

// MARK: - MACs, PBKDF

begin("HMAC (RFC 2202, RFC 4231, RFC 2286) and other MAC constructions")
do {
    // RFC 2202 / 4231 test cases 1, 2, 3
    let k1 = [UInt8](repeating: 0x0b, count: 20), m1 = b("Hi There")
    let k2 = b("Jefe"), m2 = b("what do ya want for nothing?")
    let k3 = [UInt8](repeating: 0xaa, count: 20), m3 = [UInt8](repeating: 0xdd, count: 50)
    checkEq(MAC.hmac(hash: .md5, key: [UInt8](repeating: 0x0b, count: 16), message: m1), h("9294727a3638bb1c13f48ef8158bfc9d"), "HMAC-MD5 #1")
    checkEq(MAC.hmac(hash: .md5, key: k2, message: m2), h("750c783e6ab0b503eaa86e310a5db738"), "HMAC-MD5 #2")
    checkEq(MAC.hmac(hash: .sha1, key: k1, message: m1), h("b617318655057264e28bc0b6fb378c8ef146be00"), "HMAC-SHA1 #1")
    checkEq(MAC.hmac(hash: .sha1, key: k2, message: m2), h("effcdf6ae5eb2fa2d27416d5f184df9c259a7c79"), "HMAC-SHA1 #2")
    checkEq(MAC.hmac(hash: .sha1, key: k3, message: m3), h("125d7342b9ac11cd91a39af48aa17b4f63f175d3"), "HMAC-SHA1 #3")
    checkEq(MAC.hmac(hash: .sha1, key: [UInt8](repeating: 0xaa, count: 80), message: b("Test Using Larger Than Block-Size Key - Hash Key First")),
            h("aa4ae5e15272d00e95705637ce8a3b55ed402112"), "HMAC-SHA1 #6 (long key)")
    checkEq(MAC.hmac(hash: .sha256, key: k1, message: m1), h("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"), "HMAC-SHA256 #1")
    checkEq(MAC.hmac(hash: .sha256, key: k2, message: m2), h("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"), "HMAC-SHA256 #2")
    checkEq(MAC.hmac(hash: .sha512, key: k2, message: m2),
            h("164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737"), "HMAC-SHA512 #2")
    checkEq(MAC.hmac(hash: .sha512, key: [UInt8](repeating: 0xaa, count: 131), message: b("Test Using Larger Than Block-Size Key - Hash Key First")),
            h("80b24263c7c1a3ebb71493c1dd7be8b49b46d1f41b4aeec1121b013783f8f3526b56d037e05f2598bd0fd2215d6a1e5295e64f73f63f0aec8b915a985d786598"), "HMAC-SHA512 #6 (long key)")
    checkEq(MAC.hmac(hash: .ripemd160, key: k1, message: m1), h("24cb4bd67d20fc1a5d2ed7732dcc39377f0a5668"), "HMAC-RIPEMD160 #1 (RFC 2286)")
    checkEq(MAC.hmac(hash: .ripemd160, key: k2, message: m2), h("dda6c0213a485a9e24f4742064a7f033b43c4069"), "HMAC-RIPEMD160 #2")
    checkEq(MAC.hmac(hash: .ripemd160, key: k3, message: m3), h("b0b105360de759960ab4f35298e116e295d8e7c1"), "HMAC-RIPEMD160 #3")

    // Python hmac cross-check (various key lengths incl. > block)
    let algs: [HashAlgorithm] = [.md4, .md5, .sha1, .sha256, .sha512, .ripemd160]
    let names: [HashAlgorithm: String] = [.md4: "md4", .md5: "md5", .sha1: "sha1", .sha256: "sha256", .sha512: "sha512", .ripemd160: "ripemd160"]
    let keys: [[UInt8]] = [[], [7], (0..<64).map { UInt8($0) }, (0..<65).map { UInt8($0) }, (0..<129).map { UInt8($0 ^ 0x5a) }]
    var req = ""
    for k in keys { for m in testMessages.prefix(14) { for a in algs { req += "\(names[a]!) \(Hex.encode(k, separator: "")). \(Hex.encode(m, separator: "")).\n" } } }
    let script = "import sys,hmac\nfor l in sys.stdin:\n a,k,m=l.split()\n print(hmac.new(bytes.fromhex(k[:-1]),bytes.fromhex(m[:-1]),a).hexdigest())"
    if let out = python(script, input: req) {
        let expected = out.split(separator: "\n").map(String.init)
        var i = 0
        for k in keys { for m in testMessages.prefix(14) { for a in algs {
            checkEq(MAC.hmac(hash: a, key: k, message: m), h(expected[i]), "HMAC-\(a.displayName) k=\(k.count) m=\(m.count) vs Python")
            i += 1
        } } }
    } else { print("  (Python nicht verfügbar – Querprüfung übersprungen)") }

    // simple constructions
    let k = b("geheim"), k2b = b("zweiter"), m = b("Nachricht")
    for a in HashAlgorithm.allCases {
        checkEq(MAC.compute(.secretPrefix, hash: a, key: k, message: m), Hashing.hash(k + m, algorithm: a), "H(k,m) \(a)")
        checkEq(MAC.compute(.secretSuffix, hash: a, key: k, message: m), Hashing.hash(m + k, algorithm: a), "H(m,k) \(a)")
        checkEq(MAC.compute(.envelope, hash: a, key: k, message: m), Hashing.hash(k + m + k, algorithm: a), "H(k,m,k) \(a)")
        checkEq(MAC.compute(.doubleKey, hash: a, key: k, message: m, secondKey: k2b), Hashing.hash(k + m + k2b, algorithm: a), "H(k,m,k') \(a)")
        let d = MAC.details(.hmac, hash: a, key: k, message: m)
        check(d.innerHash?.count == a.digestLength && d.outerInput.count == a.hmacBlockLength + a.digestLength, "HMAC details \(a)")
    }
    check(MACConstruction.allCases.count == 5 && MACConstruction.doubleKey.requiresSecondKey, "MAC constructions")
}

begin("PBKDF2 (RFC 6070, Python) and CT1 PBKDF1")
do {
    checkEq(try PasswordKeyDerivation.pbkdf2(password: b("password"), salt: b("salt"), iterations: 1, keyLength: 20, hash: .sha1),
            h("0c60c80f961f0e71f3a9b524af6012062fe037a6"), "RFC 6070 #1")
    checkEq(try PasswordKeyDerivation.pbkdf2(password: b("password"), salt: b("salt"), iterations: 2, keyLength: 20, hash: .sha1),
            h("ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957"), "RFC 6070 #2")
    checkEq(try PasswordKeyDerivation.pbkdf2(password: b("password"), salt: b("salt"), iterations: 4096, keyLength: 20, hash: .sha1),
            h("4b007901b765489abead49d926f721d065a429c1"), "RFC 6070 #3")
    checkEq(try PasswordKeyDerivation.pbkdf2(password: b("passwordPASSWORDpassword"), salt: b("saltSALTsaltSALTsaltSALTsaltSALTsalt"),
                                             iterations: 4096, keyLength: 25, hash: .sha1),
            h("3d2eec4fe41c849b80c8d83662c0e44a8b291a964cf2f07038"), "RFC 6070 #5")
    checkEq(try PasswordKeyDerivation.pbkdf2(password: b("pass\0word"), salt: b("sa\0lt"), iterations: 4096, keyLength: 16, hash: .sha1),
            h("56fa6aa75548099dcc37d7f03425e0c3"), "RFC 6070 #6")
    let cases: [(HashAlgorithm, String, String, Int, Int)] = [
        (.md5, "password", "salt", 1, 16), (.md5, "CrypTool", "NaCl", 1000, 40), (.sha256, "password", "salt", 4096, 32),
        (.sha512, "Passwort", "Salz", 777, 100), (.sha1, "x", "", 10, 64), (.md4, "abc", "def", 5, 20),
        (.ripemd160, "abc", "def", 300, 50), (.sha256, String(repeating: "p", count: 100), "s", 3, 70),
    ]
    let names: [HashAlgorithm: String] = [.md4: "md4", .md5: "md5", .sha1: "sha1", .sha256: "sha256", .sha512: "sha512", .ripemd160: "ripemd160"]
    var req = ""
    for (a, p, s, it, len) in cases { req += "\(names[a]!) \(Hex.encode(b(p), separator: "")). \(Hex.encode(b(s), separator: "")). \(it) \(len)\n" }
    let script = "import sys,hashlib\nfor l in sys.stdin:\n a,p,s,i,n=l.split()\n print(hashlib.pbkdf2_hmac(a,bytes.fromhex(p[:-1]),bytes.fromhex(s[:-1]),int(i),int(n)).hex())"
    if let out = python(script, input: req) {
        let expected = out.split(separator: "\n").map(String.init)
        for (i, (a, p, s, it, len)) in cases.enumerated() where i < expected.count {
            checkEq(try PasswordKeyDerivation.pbkdf2(password: b(p), salt: b(s), iterations: it, keyLength: len, hash: a),
                    h(expected[i]), "PBKDF2-\(a.displayName) it=\(it) vs Python")
        }
    } else { print("  (Python nicht verfügbar – Querprüfung übersprungen)") }
    // PBKDF1 as CT1: T1 = H(P||S), Ti = H(Ti-1)
    var t = Hashing.hash(b("Passwort") + b("Salz"), algorithm: .md5)
    for _ in 1..<1000 { t = Hashing.hash(t, algorithm: .md5) }
    checkEq(try PasswordKeyDerivation.pbkdf1(password: b("Passwort"), salt: b("Salz"), iterations: 1000, keyLength: 16, hash: .md5), t, "PBKDF1-MD5")
    checkEq(try PasswordKeyDerivation.pbkdf1(password: b("pw"), salt: b("s"), iterations: 0, keyLength: 10, hash: .sha1),
            Array(Hashing.hash(b("pws"), algorithm: .sha1).prefix(10)), "PBKDF1 iterations 0 = single hash (CT1)")
    if let out = python("import hashlib\nt=hashlib.sha1(b'passwordsalt').digest()\nfor i in range(999): t=hashlib.sha1(t).digest()\nprint(t.hex())", input: "") {
        checkEq(try PasswordKeyDerivation.pbkdf1(password: b("password"), salt: b("salt"), iterations: 1000, keyLength: 20, hash: .sha1),
                h(out.trimmingCharacters(in: .whitespacesAndNewlines)), "PBKDF1-SHA1 vs Python")
    }
    checkThrows("PBKDF1 key too long") { _ = try PasswordKeyDerivation.pbkdf1(password: [1], salt: [], iterations: 1, keyLength: 17, hash: .md2) }
    checkThrows("PBKDF2 0 iterations") { _ = try PasswordKeyDerivation.pbkdf2(password: [1], salt: [], iterations: 0, keyLength: 16, hash: .sha1) }
    check(PasswordKeyDerivation.supportedHashes.contains(.md2) && PasswordKeyDerivation.pbkdf1Hashes == [.md2, .md5, .sha1], "supported hashes")
    check((try? PasswordKeyDerivation.pbkdf2(password: b("a"), salt: b("b"), iterations: 2, keyLength: 33, hash: .md2).count) == 33, "PBKDF2-MD2 length")
}

// MARK: - Encodings

begin("Base64 (RFC 4648) / UU")
do {
    let rfc = [("", ""), ("f", "Zg=="), ("fo", "Zm8="), ("foo", "Zm9v"), ("foob", "Zm9vYg=="), ("fooba", "Zm9vYmE="), ("foobar", "Zm9vYmFy")]
    for (p, e) in rfc {
        check(Base64Codec.encode(b(p)) == e, "Base64 encode \(p)")
        check((try? Base64Codec.decode(e)) == b(p), "Base64 decode \(e)")
    }
    for m in testMessages.prefix(20) {
        let ours = Base64Codec.encode(m)
        let foundation = Data(m).base64EncodedString(options: .lineLength76Characters).replacingOccurrences(of: "\r\n", with: "\n")
        check(ours == foundation, "Base64 vs Foundation len \(m.count)")
        check((try? Base64Codec.decode(ours)) == m, "Base64 round trip len \(m.count)")
        check((try? Base64Codec.decode(Base64Codec.encode(m, lineLength: 0))) == m, "Base64 no wrap len \(m.count)")
    }
    check(Base64Codec.encode([UInt8](repeating: 0, count: 100), lineLength: 64).split(separator: "\n").first?.count == 64, "line length 64")
    check((try? Base64Codec.decode(" Zm9v\r\n Ym Fy \t")) == b("foobar"), "whitespace ignored")
    check((try? Base64Codec.decode("Zm9vYg")) == b("foob"), "missing padding tolerated")
    checkThrows("invalid Base64 char") { _ = try Base64Codec.decode("Zm9v!") }
    checkThrows("Base64 single trailing char") { _ = try Base64Codec.decode("Zm9vY") }

    // UU
    let data = testMessages[testMessages.count - 3]   // 1000 bytes
    let uu = UUCodec.encode(data, fileName: "test.bin")
    check(uu.hasPrefix("begin 644 test.bin\n") && uu.hasSuffix("`\nend\n"), "UU header/trailer")
    if let dec = try? UUCodec.decode(uu) { checkEq(dec.bytes, data, "UU round trip"); check(dec.fileName == "test.bin", "UU file name") }
    else { check(false, "UU decode") }
    check((try? UUCodec.decode(UUCodec.encode([]))).map { $0.bytes.isEmpty } ?? false, "UU empty")
    check(UUCodec.encode(b("Cat")) == "begin 644 CrypTool.bin\n#0V%T\n`\nend\n", "UU 'Cat'")
    // with /usr/bin/uudecode and /usr/bin/uuencode
    if FileManager.default.isExecutableFile(atPath: "/usr/bin/uudecode") {
        let f = scratch.appendingPathComponent("t.uu")
        try? uu.write(to: f, atomically: true, encoding: .utf8)
        let (st, _) = shell(["/usr/bin/uudecode", "-o", scratch.appendingPathComponent("t.out").path, f.path])
        check(st == 0 && (try? Data(contentsOf: scratch.appendingPathComponent("t.out"))).map(Array.init) == data, "uudecode accepts our output")
        let src = scratch.appendingPathComponent("src.bin")
        try? Data(data).write(to: src)
        let (st2, enc) = shell(["/usr/bin/uuencode", src.path, "x.bin"])
        if st2 == 0, let d = try? UUCodec.decode(enc) { checkEq(d.bytes, data, "decode uuencode output"); check(d.fileName == "x.bin", "uuencode file name") }
        else { check(false, "uuencode") }
    }
}

// MARK: - ASN.1

let testCertificatePEM = """
-----BEGIN CERTIFICATE-----
MIICGTCCAYKgAwIBAgIUCt/sNDoQLPWqjcmN1TbBUjHHPcAwDQYJKoZIhvcNAQEL
BQAwLzELMAkGA1UEBhMCREUxETAPBgNVBAoMCENyeXBUb29sMQ0wCwYDVQQDDARU
ZXN0MB4XDTI2MTExMjE0MTIzNVoXDTI3MTExMjE0MTIzNVowLzELMAkGA1UEBhMC
REUxETAPBgNVBAoMCENyeXBUb29sMQ0wCwYDVQQDDARUZXN0MIGfMA0GCSqGSIb3
DQEBAQUAA4GNADCBiQKBgQC5XsqX5w4m2YdxICZDuf4pDVATTXcqRJZH+4aJ10p/
jGcgiiVDUOMQc7nkFRpsNdFPwf5UGnQqK5x39mmToFCGN98RkDyiRF/7LvUjkhPF
eSFPtth/OGP6NDBzZAZARHDECWFTFOLuLQDjU3tDtm5zu6lI7NmXRoUOLd/g1EN8
uwIDAQABozIwMDAdBgNVHQ4EFgQUHN/Jg3TFSCWzH2d/bCh294qg/QwwDwYDVR0T
AQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOBgQArQlYRvzrizbrhwjBse2XsFsmF
v4Qh0hM4Qh7NjV0f2b/wrjjIkGPCxjdtRL5Y3++yuCcUPhr5B+Q3QcX6zEuQEU+c
ZRwn+kbia5Nlpef+8tkL49Ueh3tM2jUp89NHCdDmIf8UpEHJetxC6rxdgcKArHAC
oyNI/B9FXTvlygk6zw==
-----END CERTIFICATE-----
"""

begin("ASN.1 (X.509 certificate generated by OpenSSL)")
do {
    // offset depth hl l as printed by `openssl asn1parse` for this certificate
    let opensslTree = "0 0 4 537;4 1 4 386;8 2 2 3;10 3 2 1;13 2 2 20;35 2 2 13;37 3 2 9;48 3 2 0;50 2 2 47;52 3 2 11;54 4 2 9;56 5 2 3;61 5 2 2;65 3 2 17;67 4 2 15;69 5 2 3;74 5 2 8;84 3 2 13;86 4 2 11;88 5 2 3;93 5 2 4;99 2 2 30;101 3 2 13;116 3 2 13;131 2 2 47;133 3 2 11;135 4 2 9;137 5 2 3;142 5 2 2;146 3 2 17;148 4 2 15;150 5 2 3;155 5 2 8;165 3 2 13;167 4 2 11;169 5 2 3;174 5 2 4;180 2 3 159;183 3 2 13;185 4 2 9;196 4 2 0;198 3 3 141;342 2 2 50;344 3 2 48;346 4 2 29;348 5 2 3;353 5 2 22;377 4 2 15;379 5 2 3;384 5 2 1;387 5 2 5;394 1 2 13;396 2 2 9;407 2 2 0;409 1 3 129"
    func plain(_ n: ASN1Node) -> [ASN1Node] { [n] + n.children.flatMap(plain) }
    do {
        let nodes = try ASN1.parse(Array(testCertificatePEM.utf8))
        check(nodes.count == 1, "one top-level node")
        let flat = nodes.flatMap(plain)
        let ours = flat.map { "\($0.offset) \($0.depth) \($0.headerLength) \($0.length)" }.joined(separator: ";")
        check(ours == opensslTree, "structure equals openssl asn1parse")
        let der = try ASN1.derBytes(from: Array(testCertificatePEM.utf8))
        check(der.count == 541, "DER length")
        check(try ASN1.parse(der).flatMap(plain).count == flat.count, "DER and PEM input equal")
        check(try ASN1.parse(Array(Base64Codec.encode(der).utf8)).flatMap(plain).count == flat.count, "plain Base64 input")
        let byOffset = Dictionary(uniqueKeysWithValues: flat.map { ($0.offset, $0) })
        check(byOffset[10]?.valueDescription == "2", "INTEGER version")
        check(byOffset[37]?.valueDescription == "sha256WithRSAEncryption (1.2.840.113549.1.1.11)", "OID name")
        check(byOffset[56]?.valueDescription == "countryName (2.5.4.6)", "countryName")
        check(byOffset[61]?.valueDescription == "DE", "PrintableString")
        check(byOffset[74]?.valueDescription == "CrypTool", "UTF8String")
        check(byOffset[101]?.valueDescription == "261112141235Z", "UTCTime")
        check(byOffset[101]?.typeName == "UTCTIME" && byOffset[8]?.typeName == "cont [ 0 ]", "type names")
        check(byOffset[384]?.valueDescription == "TRUE", "BOOLEAN")
        check(byOffset[185]?.valueDescription?.hasPrefix("rsaEncryption") == true, "rsaEncryption")
        check(byOffset[198]?.encapsulated.first?.children.count == 2, "RSA key inside BIT STRING")
        check(byOffset[198]?.encapsulated.first?.children.last?.valueDescription == "65537", "RSA exponent 65537")
        check(byOffset[387]?.encapsulated.first?.typeName == "SEQUENCE", "extension value encapsulated")
        let dump = try ASN1.dump(der)
        if ProcessInfo.processInfo.environment["CTMODERN_SHOW"] != nil { print(dump) }
        check(dump.contains("    0:d=0  hl=4 l= 537 cons: SEQUENCE"), "dump first line")
        check(dump.contains("   37:d=3  hl=2 l=   9 prim:    OBJECT            :sha256WithRSAEncryption"), "dump OBJECT line")
        check(dump.contains("commonName") && dump.contains(":Test") && dump.contains("▹"), "dump content")
    } catch {
        check(false, "certificate parse: \(error)")
    }
    // BER indefinite length, high tag numbers, errors
    do {
        let ber = h("30800201050C03616263A080050000000000")
        let n = try ASN1.parse(ber)
        check(n.count == 1 && n[0].indefiniteLength && n[0].children.count == 3 && n[0].children[2].indefiniteLength, "indefinite length")
        check(n[0].children[0].valueDescription == "5" && n[0].children[1].valueDescription == "abc", "BER values")
        let hi = try ASN1.parse(h("9F8101016A"))
        check(hi[0].tagNumber == 129 && hi[0].tagClass == .contextSpecific && hi[0].headerLength == 4, "high tag number")
        check(try ASN1.parse(h("020180"))[0].valueDescription == "-128", "negative INTEGER")
        check(try ASN1.parse(h("06092A864886F70D01010B"))[0].valueDescription?.hasPrefix("sha256WithRSAEncryption") == true, "OID decode")
        check(ASN1.oidString(h("2B0601040182371514")) == "1.3.6.1.4.1.311.21.20", "OID dotted")
    } catch {
        check(false, "BER: \(error)")
    }
    checkThrows("truncated DER") { _ = try ASN1.parse(h("300A020101")) }
    checkThrows("empty") { _ = try ASN1.parse([]) }
    checkThrows("bad PEM") { _ = try ASN1.parse(b("-----BEGIN X-----\n-----END X-----\n")) }
    // deeply nested input must not crash
    checkThrows("too deep") { _ = try ASN1.parse([UInt8](repeating: 0x30, count: 100) + [UInt8](repeating: 0x80, count: 100)) }
}

// MARK: - ZIP

begin("ZIP (verified with /usr/bin/unzip and /usr/bin/zip)")
do {
    let text = Array(String(repeating: "CrypTool ist ein Lernprogramm für Kryptografie. ", count: 200).utf8)
    var rng: UInt64 = 0x9E3779B97F4A7C15
    let random: [UInt8] = (0..<5000).map { _ in rng = rng &* 6364136223846793005 &+ 1442695040888963407; return UInt8(truncatingIfNeeded: rng >> 33) }
    let entries: [(name: String, data: [UInt8])] = [("text.txt", text), ("zufall.bin", random), ("leer.txt", []),
                                                    ("Übung/äöü.txt", b("Umlaute")), ("a", [42])]
    check(CRC32.checksum(b("123456789")) == 0xCBF43926, "CRC-32 check value")
    do {
        let archive = try ZipArchive.create(entries: entries)
        check(archive.count < text.count, "deflate compresses")
        let back = try ZipArchive.extract(archive)
        check(back.count == entries.count && archive.count > 0, "entry count")
        for (e, r) in zip(entries, back) { check(e.name == r.name && e.data == r.data, "round trip \(e.name)") }
        let url = scratch.appendingPathComponent("test.zip")
        try Data(archive).write(to: url)
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip") {
            let (st, out) = shell(["/usr/bin/unzip", "-t", url.path])
            check(st == 0 && out.contains("No errors detected"), "unzip -t: \(out)")
            let dir = scratch.appendingPathComponent("unz")
            let (st2, _) = shell(["/usr/bin/unzip", "-o", "-q", url.path, "-d", dir.path])
            check(st2 == 0, "unzip extract")
            for e in entries {
                let d = (try? Data(contentsOf: dir.appendingPathComponent(e.name))).map(Array.init)
                check(d == e.data, "unzip content \(e.name)")
            }
        }
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") {
            let src = scratch.appendingPathComponent("zsrc")
            try FileManager.default.createDirectory(at: src.appendingPathComponent("sub"), withIntermediateDirectories: true)
            try Data(text).write(to: src.appendingPathComponent("text.txt"))
            try Data(random).write(to: src.appendingPathComponent("sub/zufall.bin"))
            try Data().write(to: src.appendingPathComponent("sub/leer"))
            let zurl = scratch.appendingPathComponent("byzip.zip")
            let (st, out) = shell(["/usr/bin/zip", "-r", "-q", zurl.path, "."], cwd: src)
            check(st == 0, "zip ran: \(out)")
            let ex = try ZipArchive.extract(Array(try Data(contentsOf: zurl)))
            let dict = Dictionary(uniqueKeysWithValues: ex.map { ($0.name, $0.data) })
            check(dict["text.txt"] == text && dict["sub/zufall.bin"] == random && dict["sub/leer"] == [], "extract /usr/bin/zip archive")
            check(!dict.keys.contains("sub/"), "directory entries skipped")
        }
        var bad = archive
        bad[40] ^= 0xFF   // inside compressed data of first entry
        checkThrows("corrupt archive detected") { _ = try ZipArchive.extract(bad) }
        checkThrows("not a zip") { _ = try ZipArchive.extract(b("hello world, definitely not a zip archive")) }
    } catch {
        check(false, "ZIP: \(error)")
    }
}

// MARK: - AES inspector

begin("AES inspector (FIPS-197 Appendix B, C)")
do {
    let t = try AESInspector.trace(key: h("2b7e151628aed2a6abf7158809cf4f3c"), block: h("3243f6a8885a308d313198a2e0370734"))
    checkEq(t.ciphertext, h("3925841d02dc09fbdc118597196a0b32"), "Appendix B ciphertext")
    check(t.roundKeys.count == 11, "11 round keys")
    checkEq(t.roundKeys[1], h("a0fafe1788542cb123a339392a6c7605"), "round key 1")
    checkEq(t.roundKeys[10], h("d014f9a8c9ee2589e13f0cc8b6630ca6"), "round key 10")
    func state(_ round: Int, _ op: String) -> [UInt8] { t.steps.first { $0.round == round && $0.operation == op }?.state ?? [] }
    checkEq(state(0, "AddRoundKey"), h("193de3bea0f4e22b9ac68d2ae9f84808"), "start of round 1")
    checkEq(state(1, "SubBytes"), h("d42711aee0bf98f1b8b45de51e415230"), "round 1 SubBytes")
    checkEq(state(1, "ShiftRows"), h("d4bf5d30e0b452aeb84111f11e2798e5"), "round 1 ShiftRows")
    checkEq(state(1, "MixColumns"), h("046681e5e0cb199a48f8d37a2806264c"), "round 1 MixColumns")
    checkEq(state(1, "AddRoundKey"), h("a49c7ff2689f352b6b5bea43026a5049"), "start of round 2")
    check(t.steps.first?.operation == "Input" && t.steps.last?.operation == "Output", "first/last step")
    check(t.steps.count == 2 + 9 * 4 + 3 + 1, "step count AES-128")
    check(!t.steps.contains { $0.round == 10 && $0.operation == "MixColumns" }, "no MixColumns in last round")
    let pt = h("00112233445566778899aabbccddeeff")
    checkEq(try AESInspector.trace(key: h("000102030405060708090a0b0c0d0e0f"), block: pt).ciphertext, h("69c4e0d86a7b0430d8cdb78070b4c55a"), "C.1")
    let t192 = try AESInspector.trace(key: h("000102030405060708090a0b0c0d0e0f1011121314151617"), block: pt)
    checkEq(t192.ciphertext, h("dda97ca4864cdfe06eaf70a0ec0d7191"), "C.2"); check(t192.roundKeys.count == 13, "13 round keys")
    let t256 = try AESInspector.trace(key: h("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"), block: pt)
    checkEq(t256.ciphertext, h("8ea2b7ca516745bfeafc49904b496089"), "C.3"); check(t256.roundKeys.count == 15, "15 round keys")
    // random comparison against CommonCrypto
    var x: UInt64 = 12345
    func rnd(_ n: Int) -> [UInt8] { (0..<n).map { _ in x = x &* 6364136223846793005 &+ 1; return UInt8(truncatingIfNeeded: x >> 40) } }
    for ks in [16, 24, 32] { for _ in 0..<20 {
        let k = rnd(ks), p = rnd(16)
        checkEq(try AESInspector.trace(key: k, block: p).ciphertext, try SymmetricCipher.encryptRaw(.aes, key: k, data: p), "inspector vs CommonCrypto")
    } }
    check(AESInspector.sbox[0x00] == 0x63 && AESInspector.sbox[0x53] == 0xED, "S-box")
    checkThrows("bad key length") { _ = try AESInspector.trace(key: [1], block: pt) }
}

begin("HashDemo")
do {
    check(HashDemo.bitDifference([0xFF, 0x00], [0x0F, 0x01]) == (5, 16), "bit difference")
    check(HashDemo.bitDifference([1, 2, 3], [1, 2, 3]) == (0, 24), "equal")
    check(HashDemo.bitDifference([1], [1, 0]) == (8, 16), "length difference")
    check(HashDemo.differingBitPositions([0x80], [0x01]) == [0, 7], "bit positions")
    let a = Hashing.hash(b("CrypTool"), algorithm: .sha1), c = Hashing.hash(b("CrypToal"), algorithm: .sha1)
    let d = HashDemo.bitDifference(a, c)
    check(d.totalBits == 160 && d.differentBits > 40 && d.differentBits < 120, "avalanche plausible")
}

// MARK: - Brute force

begin("Symmetric brute force")
do {
    let plain = b("Kryptografie ist die Wissenschaft der Verschlüsselung von Informationen. Dieser Text dient als Testklartext für die Analyse.")
    let cases: [(SymmetricAlgorithm, String, String)] = [
        (.aes, "2B7E151628AED2A6ABF7158809CF4F3C", "2B7E151628AED2A6ABF7158809CF4***"),
        (.mars, "00112233445566778899AABBCCDDEEFF", "0011223344556677 8899AABBCCDDE**F"),
        (.rc6, "000102030405060708090A0B0C0D0E0F1011121314151617", "000102030405060708090A0B0C0D0E0F10111213141516**"),
        (.serpent, "FFEEDDCCBBAA99887766554433221100", "FFEEDDCCBBAA998877665544332211**"),
        (.twofish, "0123456789ABCDEFFEDCBA9876543210", "0123456789ABCDEFFEDCBA98765432**"),
        (.desCBC, "133457799BBCDFF1", "13345779 9BBCD**1"),
        (.desECB, "0123456789ABCDEF", "0123456789ABC*E*"),
        (.tripleDESCBC, "0123456789ABCDEFFEDCBA9876543210", "0123456789ABCDEFFEDCBA98765432*0"),
        (.desx, "0123456789ABCDEF1122334455667788 99AABBCCDDEEFF00", "0123456789ABCDEF112233445566778*99AABBCCDDEEFF*0"),
        (.desl, "0123456789ABCDEF", "0123456789AB*D*F"),
        (.desxl, "0123456789ABCDEF112233445566778899AABBCCDDEEFF00", "0123456789ABCDE*112233445566778899AABBCCDDEEFF*0"),
        (.idea, "000102030405060708090A0B0C0D0E0F", "000102030405060708090A0B0C0D0E**"),
        (.rc2, "A1B2C3D4E5", "A1B2C3D4**"),
        (.rc4, "4B6579", "4B6**9"),
    ]
    for (alg, keyHex, pattern) in cases {
        let key = h(keyHex)
        do {
            let ct = try SymmetricCipher.encrypt(alg, key: key, data: plain)
            let r = try SymmetricBruteForce.run(alg, ciphertext: ct, keyPattern: pattern, maxResults: 5,
                                                cancel: CancellationToken(), progress: nil)
            check(r.count == min(5, Int(SymmetricBruteForce.keyspaceSize(pattern: pattern, algorithm: alg))), "\(alg) result count \(r.count)")
            guard let best = r.first else { check(false, "\(alg) no result"); continue }
            // DES parity bits are not enumerated: compare the decryption, not the key bytes
            let window = min(ct.count, 128) / alg.paddingUnit * alg.paddingUnit
            check(best.plaintextPreview == Array(SymmetricCipher.pad(alg, plain).prefix(window)), "\(alg.displayName): best candidate decrypts correctly (key \(best.keyHex))")
            if !alg.hasDESParity { checkEq(best.key, key, "\(alg.displayName) key found") }
            check(r.map(\.entropy) == r.map(\.entropy).sorted(), "\(alg) sorted by entropy")
            if r.count > 1 { check(r[0].entropy < r[1].entropy, "\(alg) correct key clearly best") }
        } catch {
            check(false, "\(alg.displayName) brute force: \(error)")
        }
    }
    check(SymmetricBruteForce.keyspaceSize(pattern: "00 ** 1*") == 4096, "keyspace")
    check(SymmetricBruteForce.keyspaceSize(pattern: "0123456789ABCD**", algorithm: .desECB) == 128, "keyspace with DES parity")
    check(SymmetricBruteForce.keyspaceSize(pattern: String(repeating: "0", count: 30) + "**", algorithm: .aes) == 256, "keyspace AES")
    checkThrows("pattern wrong length") { _ = try SymmetricBruteForce.run(.aes, ciphertext: [UInt8](repeating: 0, count: 16), keyPattern: "00**", cancel: CancellationToken(), progress: nil) }
    checkThrows("pattern invalid char") { _ = try SymmetricBruteForce.run(.desECB, ciphertext: [UInt8](repeating: 0, count: 8), keyPattern: "00112233445566XY", cancel: CancellationToken(), progress: nil) }
    checkThrows("ciphertext too short") { _ = try SymmetricBruteForce.run(.aes, ciphertext: [1, 2], keyPattern: String(repeating: "0", count: 31) + "*", cancel: CancellationToken(), progress: nil) }
    // cancellation
    let token = CancellationToken()
    let ct = try SymmetricCipher.encrypt(.aes, key: [UInt8](repeating: 0, count: 16), data: plain)
    let cancelStart = Date()
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { token.cancel() }
    let partial = try SymmetricBruteForce.run(.aes, ciphertext: ct, keyPattern: String(repeating: "0", count: 22) + String(repeating: "*", count: 10),
                                              cancel: token, progress: nil)
    check(Date().timeIntervalSince(cancelStart) < 3 && partial.count == 10, "cancellation returns partial results quickly")

    // Throughput
    func measure(_ alg: SymmetricAlgorithm, _ keyHex: String, _ pattern: String) {
        do {
            let ct = try SymmetricCipher.encrypt(alg, key: h(keyHex), data: plain)
            let n = SymmetricBruteForce.keyspaceSize(pattern: pattern, algorithm: alg)
            final class Box: @unchecked Sendable { let lock = NSLock(); var value = 0.0 }
            let box = Box()
            let t0 = Date()
            let r = try SymmetricBruteForce.run(alg, ciphertext: ct, keyPattern: pattern, cancel: CancellationToken(),
                                                progress: { p in box.lock.lock(); box.value = max(box.value, p); box.lock.unlock() })
            let dt = Date().timeIntervalSince(t0)
            check(box.value == 1.0, "\(alg) progress reaches 1")
            check(r.first?.plaintextPreview == Array(SymmetricCipher.pad(alg, plain).prefix(128)), "\(alg) throughput run finds key")
            print(String(format: "  %@: %.0f Schlüssel in %.2f s = %.2f Mio. Schlüssel/s (%d Kerne, %d Byte Fenster)",
                         alg.displayName, n, dt, n / dt / 1e6, ProcessInfo.processInfo.activeProcessorCount, 128))
        } catch { check(false, "\(alg) throughput: \(error)") }
    }
    measure(.aes, "2B7E151628AED2A6ABF7158809CF4F3C", "2B7E151628AED2A6ABF7158809******")
    measure(.desCBC, "133457799BBCDFF1", "*3*4*7*9*B*CDFF1")
    measure(.desECB, "133457799BBCDFF1", "*3*4*7*9*B*CDFF1")
    measure(.mars, "00112233445566778899AABBCCDDEEFF", "00112233445566778899AABBCC******")
    measure(.twofish, "00112233445566778899AABBCCDDEEFF", "00112233445566778899AABBCCD*****")
    measure(.serpent, "00112233445566778899AABBCCDDEEFF", "00112233445566778899AABBCC******")
    measure(.rc6, "00112233445566778899AABBCCDDEEFF", "00112233445566778899AABBCC******")
    measure(.idea, "00112233445566778899AABBCCDDEEFF", "00112233445566778899AABBCCD*****")
    measure(.desxl, "0123456789ABCDEF112233445566778899AABBCCDDEEFF00", "0123456789AB*D*F112233445566778899AABBCCDDEEF***")
    measure(.rc4, "4B65794B6579", "4B6579******")
}

// MARK: - Signature attack (CT1 birthday attack on truncated hashes)
do {
    print("— Signaturangriff")
    let harmless = Array("Sehr geehrter Herr Einkaufgern,\n\nbitte bestellen Sie eine Schreibmaschine fuer unser Buero im zweiten Stock.\n\nMit freundlichen Gruessen\nIhre Assistentin\n".utf8)
    let dangerous = Array("Sehr geehrter Herr Einkaufgern,\n\nbitte ueberweisen Sie heute noch 100.000 Euro auf das Konto des Lieferanten.\n\nMit freundlichen Gruessen\nIhre Assistentin\n".utf8)
    for method in [SignatureAttack.Method.blanks(beforeLineEnd: true, doubleBlanks: true), .attachments(printable: true), .attachments(printable: false)] {
        for (hash, bits) in [(HashAlgorithm.md5, 16), (.sha1, 20), (.md2, 12)] {
            do {
                let r = try SignatureAttack.run(harmless: harmless, dangerous: dangerous,
                                                options: .init(hash: hash, significantBits: bits, method: method))
                check(r.success, "Signaturangriff \(hash) \(bits) Bit \(method) erfolgreich")
                if r.success {
                    check(SignatureAttack.truncate(r.harmlessHash, bits: bits) == SignatureAttack.truncate(r.dangerousHash, bits: bits),
                          "Signaturangriff: gekürzte Hashwerte gleich")
                    check(r.harmless != r.dangerous, "Signaturangriff: Nachrichten verschieden")
                    check(r.harmless.starts(with: Array("Sehr geehrter".utf8)) && TextCoding.string(from: r.dangerous).contains("100.000"), "Signaturangriff: Inhalte erhalten")
                }
            } catch { check(false, "Signaturangriff \(hash): \(error)") }
        }
    }
    checkThrows("Signaturangriff: zu wenige Stellen") {
        _ = try SignatureAttack.run(harmless: Array("a b".utf8), dangerous: Array("c d".utf8), options: .standard)
    }
    check(SignatureAttack.expectedSteps(bits: 16) == 640, "erwartete Schritte 16 Bit")
}

runAESToolTests()

runCT1TutorialTests()

print("")
print("CTModernTests: \(passed) passed, \(failed) failed")
try? FileManager.default.removeItem(at: scratch)
exit(failed == 0 ? 0 : 1)
