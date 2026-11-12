import CryptoKit
import CTCommon

/// Hash functions offered by CT1 ("Einzelverfahren ▸ Hashverfahren", HMAC dialog, hash demo).
public enum HashAlgorithm: String, CaseIterable, Codable, Sendable {
    case md2, md4, md5, sha0, sha1, sha256, sha512, ripemd160

    /// Name as shown in CT1 ("SHA" is SHA-0 from FIPS 180).
    public var displayName: String {
        switch self {
        case .md2: return "MD2"
        case .md4: return "MD4"
        case .md5: return "MD5"
        case .sha0: return "SHA"
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        case .ripemd160: return "RIPEMD-160"
        }
    }

    /// Digest length in bytes.
    public var digestLength: Int {
        switch self {
        case .md2, .md4, .md5: return 16
        case .sha0, .sha1, .ripemd160: return 20
        case .sha256: return 32
        case .sha512: return 64
        }
    }

    /// Block length of the compression function in bytes.
    public var blockLength: Int {
        switch self {
        case .md2: return 16
        case .sha512: return 128
        default: return 64
        }
    }

    /// Block length used for HMAC (RFC 2104 "B"). As in CT1 (DlgHMAC.cpp) this is 64 bytes for
    /// all functions except SHA-512 (128 bytes) – including MD2.
    public var hmacBlockLength: Int { self == .sha512 ? 128 : 64 }
}

/// One-shot hash computation.
public enum Hashing {
    /// Computes the hash of `data`.
    public static func hash(_ data: [UInt8], algorithm: HashAlgorithm) -> [UInt8] {
        switch algorithm {
        case .md5: return Array(Insecure.MD5.hash(data: data))
        case .sha1: return Array(Insecure.SHA1.hash(data: data))
        case .sha256: return Array(SHA256.hash(data: data))
        case .sha512: return Array(SHA512.hash(data: data))
        case .md2: return MD2.hash(data)
        case .md4: return MD4.hash(data)
        case .sha0: return SHA0.hash(data)
        case .ripemd160: return RIPEMD160.hash(data)
        }
    }

    /// Hash of the UTF-8 encoding of `string`.
    public static func hash(_ string: String, algorithm: HashAlgorithm) -> [UInt8] {
        hash(Array(string.utf8), algorithm: algorithm)
    }
}

// MARK: - Own implementations (MD2, MD4, SHA-0, RIPEMD-160)

@inline(__always) private func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 { (x << n) | (x >> (32 - n)) }

/// Merkle–Damgård padding with 64-bit length (bits); `bigEndian` selects the length byte order.
private func mdPad(_ data: [UInt8], bigEndian: Bool) -> [UInt8] {
    var m = data
    let bitLen = UInt64(data.count) &* 8
    m.append(0x80)
    while m.count % 64 != 56 { m.append(0) }
    for i in 0..<8 {
        let shift = bigEndian ? UInt64(56 - 8 * i) : UInt64(8 * i)
        m.append(UInt8(truncatingIfNeeded: bitLen >> shift))
    }
    return m
}

/// MD2 (RFC 1319).
enum MD2 {
    private static let S: [UInt8] = [
        41, 46, 67, 201, 162, 216, 124, 1, 61, 54, 84, 161, 236, 240, 6, 19, 98, 167, 5, 243, 192, 199, 115, 140,
        152, 147, 43, 217, 188, 76, 130, 202, 30, 155, 87, 60, 253, 212, 224, 22, 103, 66, 111, 24, 138, 23, 229, 18,
        190, 78, 196, 214, 218, 158, 222, 73, 160, 251, 245, 142, 187, 47, 238, 122, 169, 104, 121, 145, 21, 178, 7, 63,
        148, 194, 16, 137, 11, 34, 95, 33, 128, 127, 93, 154, 90, 144, 50, 39, 53, 62, 204, 231, 191, 247, 151, 3,
        255, 25, 48, 179, 72, 165, 181, 209, 215, 94, 146, 42, 172, 86, 170, 198, 79, 184, 56, 210, 150, 164, 125, 182,
        118, 252, 107, 226, 156, 116, 4, 241, 69, 157, 112, 89, 100, 113, 135, 32, 134, 91, 207, 101, 230, 45, 168, 2,
        27, 96, 37, 173, 174, 176, 185, 246, 28, 70, 97, 105, 52, 64, 126, 15, 85, 71, 163, 35, 221, 81, 175, 58,
        195, 92, 249, 206, 186, 197, 234, 38, 44, 83, 13, 110, 133, 40, 132, 9, 211, 223, 205, 244, 65, 129, 77, 82,
        106, 220, 55, 200, 108, 193, 171, 250, 36, 225, 123, 8, 12, 189, 177, 74, 120, 136, 149, 139, 227, 99, 232, 109,
        233, 203, 213, 254, 59, 0, 29, 57, 242, 239, 183, 14, 102, 88, 208, 228, 166, 119, 114, 248, 235, 117, 75, 10,
        49, 68, 80, 180, 143, 237, 31, 26, 219, 153, 141, 51, 159, 17, 131, 20,
    ]

    static func hash(_ data: [UInt8]) -> [UInt8] {
        var m = data
        let padLen = 16 - m.count % 16
        m.append(contentsOf: [UInt8](repeating: UInt8(padLen), count: padLen))
        var checksum = [UInt8](repeating: 0, count: 16)
        var x = [UInt8](repeating: 0, count: 48)
        S.withUnsafeBufferPointer { s in
            m.withUnsafeBufferPointer { mp in
                checksum.withUnsafeMutableBufferPointer { cs in
                    var l: UInt8 = 0
                    for b in stride(from: 0, to: mp.count, by: 16) {
                        for j in 0..<16 {
                            cs[j] ^= s[Int(mp[b + j] ^ l)]
                            l = cs[j]
                        }
                    }
                }
                x.withUnsafeMutableBufferPointer { xp in
                    func compress(_ block: UnsafePointer<UInt8>) {
                        for j in 0..<16 {
                            xp[16 + j] = block[j]
                            xp[32 + j] = block[j] ^ xp[j]
                        }
                        var t: UInt8 = 0
                        for j in 0..<18 {
                            for k in 0..<48 {
                                xp[k] ^= s[Int(t)]
                                t = xp[k]
                            }
                            t = t &+ UInt8(j)
                        }
                    }
                    for b in stride(from: 0, to: mp.count, by: 16) { compress(mp.baseAddress! + b) }
                    checksum.withUnsafeBufferPointer { compress($0.baseAddress!) }
                }
            }
        }
        return Array(x[0..<16])
    }
}

/// MD4 (RFC 1320).
enum MD4 {
    static func hash(_ data: [UInt8]) -> [UInt8] {
        let m = mdPad(data, bigEndian: false)
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476]
        var x = [UInt32](repeating: 0, count: 16)
        for b in stride(from: 0, to: m.count, by: 64) {
            for i in 0..<16 {
                x[i] = UInt32(m[b + 4 * i]) | UInt32(m[b + 4 * i + 1]) << 8 | UInt32(m[b + 4 * i + 2]) << 16 | UInt32(m[b + 4 * i + 3]) << 24
            }
            var a = h[0], bb = h[1], c = h[2], d = h[3]
            func f(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & y) | (~x & z) }
            func g(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & y) | (x & z) | (y & z) }
            func hh(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { x ^ y ^ z }
            let s1: [UInt32] = [3, 7, 11, 19], s2: [UInt32] = [3, 5, 9, 13], s3: [UInt32] = [3, 9, 11, 15]
            for i in 0..<16 {
                let t = rotl(a &+ f(bb, c, d) &+ x[i], s1[i % 4])
                a = d; d = c; c = bb; bb = t
            }
            let o2 = [0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15]
            for i in 0..<16 {
                let t = rotl(a &+ g(bb, c, d) &+ x[o2[i]] &+ 0x5A827999, s2[i % 4])
                a = d; d = c; c = bb; bb = t
            }
            let o3 = [0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15]
            for i in 0..<16 {
                let t = rotl(a &+ hh(bb, c, d) &+ x[o3[i]] &+ 0x6ED9EBA1, s3[i % 4])
                a = d; d = c; c = bb; bb = t
            }
            h[0] &+= a; h[1] &+= bb; h[2] &+= c; h[3] &+= d
        }
        var out: [UInt8] = []
        for v in h { for i in 0..<4 { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) } }
        return out
    }
}

/// SHA-0 (FIPS 180, 1993): SHA-1 without the rotation in the message schedule.
enum SHA0 {
    static func hash(_ data: [UInt8]) -> [UInt8] { sha(data, rotateSchedule: false) }

    /// Shared SHA-0/SHA-1 core.
    static func sha(_ data: [UInt8], rotateSchedule: Bool) -> [UInt8] {
        let m = mdPad(data, bigEndian: true)
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
        var w = [UInt32](repeating: 0, count: 80)
        for b in stride(from: 0, to: m.count, by: 64) {
            for i in 0..<16 {
                w[i] = UInt32(m[b + 4 * i]) << 24 | UInt32(m[b + 4 * i + 1]) << 16 | UInt32(m[b + 4 * i + 2]) << 8 | UInt32(m[b + 4 * i + 3])
            }
            for i in 16..<80 {
                let v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
                w[i] = rotateSchedule ? rotl(v, 1) : v
            }
            var a = h[0], bb = h[1], c = h[2], d = h[3], e = h[4]
            for i in 0..<80 {
                let f: UInt32, k: UInt32
                switch i {
                case 0..<20: f = (bb & c) | (~bb & d); k = 0x5A827999
                case 20..<40: f = bb ^ c ^ d; k = 0x6ED9EBA1
                case 40..<60: f = (bb & c) | (bb & d) | (c & d); k = 0x8F1BBCDC
                default: f = bb ^ c ^ d; k = 0xCA62C1D6
                }
                let t = rotl(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d; d = c; c = rotl(bb, 30); bb = a; a = t
            }
            h[0] &+= a; h[1] &+= bb; h[2] &+= c; h[3] &+= d; h[4] &+= e
        }
        var out: [UInt8] = []
        for v in h { for i in 0..<4 { out.append(UInt8(truncatingIfNeeded: v >> (24 - 8 * UInt32(i)))) } }
        return out
    }
}

/// RIPEMD-160 (Dobbertin, Bosselaers, Preneel 1996).
enum RIPEMD160 {
    private static let r: [Int] = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
    ]
    private static let rp: [Int] = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
    ]
    private static let s: [UInt32] = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
    ]
    private static let sp: [UInt32] = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
    ]
    private static let k: [UInt32] = [0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E]
    private static let kp: [UInt32] = [0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000]

    @inline(__always) private static func f(_ j: Int, _ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        switch j / 16 {
        case 0: return x ^ y ^ z
        case 1: return (x & y) | (~x & z)
        case 2: return (x | ~y) ^ z
        case 3: return (x & z) | (y & ~z)
        default: return x ^ (y | ~z)
        }
    }

    static func hash(_ data: [UInt8]) -> [UInt8] {
        let m = mdPad(data, bigEndian: false)
        var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
        var x = [UInt32](repeating: 0, count: 16)
        for b in stride(from: 0, to: m.count, by: 64) {
            for i in 0..<16 {
                x[i] = UInt32(m[b + 4 * i]) | UInt32(m[b + 4 * i + 1]) << 8 | UInt32(m[b + 4 * i + 2]) << 16 | UInt32(m[b + 4 * i + 3]) << 24
            }
            var al = h[0], bl = h[1], cl = h[2], dl = h[3], el = h[4]
            var ar = h[0], br = h[1], cr = h[2], dr = h[3], er = h[4]
            for j in 0..<80 {
                var t = rotl(al &+ f(j, bl, cl, dl) &+ x[r[j]] &+ k[j / 16], s[j]) &+ el
                al = el; el = dl; dl = rotl(cl, 10); cl = bl; bl = t
                t = rotl(ar &+ f(79 - j, br, cr, dr) &+ x[rp[j]] &+ kp[j / 16], sp[j]) &+ er
                ar = er; er = dr; dr = rotl(cr, 10); cr = br; br = t
            }
            let t = h[1] &+ cl &+ dr
            h[1] = h[2] &+ dl &+ er
            h[2] = h[3] &+ el &+ ar
            h[3] = h[4] &+ al &+ br
            h[4] = h[0] &+ bl &+ cr
            h[0] = t
        }
        var out: [UInt8] = []
        for v in h { for i in 0..<4 { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) } }
        return out
    }
}
