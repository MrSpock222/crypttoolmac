// Bit-level DES trace for the DES animation (FIPS 46-3). Pure Swift without UI dependencies,
// verified against CTModern's DES (CommonCrypto). Bits are numbered 1…n from the left (MSB
// first) as in the standard; arrays hold 0/1 values.

struct DESTrace {
    static let ip = [58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
                     62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
                     57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
                     61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7]
    static let ipInverse = [40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
                            38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
                            36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
                            34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25]
    static let pc1 = [57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
                      10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
                      63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
                      14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4]
    static let pc2 = [14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
                      23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
                      41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
                      44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32]
    static let expansion = [32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
                            16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25, 24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1]
    static let p = [16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
                    2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25]
    static let shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
    static let sboxes: [[[Int]]] = [
        [[14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7], [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
         [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0], [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13]],
        [[15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10], [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
         [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15], [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9]],
        [[10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8], [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
         [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7], [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12]],
        [[7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15], [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
         [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4], [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14]],
        [[2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9], [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
         [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14], [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3]],
        [[12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11], [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
         [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6], [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13]],
        [[4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1], [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
         [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2], [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12]],
        [[13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7], [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
         [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8], [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11]],
    ]

    /// Example of CT1's DES animation (bit matrices of des_de.aml).
    static let ct1Plaintext: [UInt8] = [0x16, 0xBD, 0x40, 0x94, 0xB4, 0x53, 0x8A, 0x7B]
    static let ct1Key: [UInt8] = [0xE1, 0xA4, 0xBB, 0x9B, 0xC2, 0xE3, 0x24, 0xBB]

    let x: [Int]            // 64 input bits
    let k: [Int]            // 64 key bits
    let permutedInput: [Int]
    let kPlus: [Int]        // 56 bits after PC1
    let c: [[Int]]          // C0 … C16 (28 bits)
    let d: [[Int]]          // D0 … D16
    let subkeys: [[Int]]    // K1 … K16 (48 bits), index 0 = K1
    let l: [[Int]]          // L0 … L16
    let r: [[Int]]          // R0 … R16
    let expanded: [[Int]]   // E(R_{i-1}) for round i (index i-1)
    let xored: [[Int]]      // B = E(R_{i-1}) ⊕ K_i
    let sboxOut: [[Int]]    // 32 bits after the S-boxes
    let f: [[Int]]          // f(R_{i-1}, K_i) after P
    let preOutput: [Int]    // R16 L16
    let output: [Int]       // 64 output bits

    static func permute(_ bits: [Int], _ table: [Int]) -> [Int] { table.map { bits[$0 - 1] } }
    static func rotl(_ bits: [Int], _ n: Int) -> [Int] { Array(bits[n...] + bits[..<n]) }

    /// 6 bit block → (row, column, value) of S-box `box` (0-based).
    static func sbox(_ box: Int, _ six: [Int]) -> (row: Int, col: Int, value: Int) {
        let row = six[0] * 2 + six[5]
        let col = six[1] * 8 + six[2] * 4 + six[3] * 2 + six[4]
        return (row, col, sboxes[box][row][col])
    }

    init(plaintext: [UInt8], key: [UInt8]) {
        precondition(plaintext.count == 8 && key.count == 8)
        x = ct1Bits(plaintext)
        k = ct1Bits(key)
        permutedInput = Self.permute(x, Self.ip)
        kPlus = Self.permute(k, Self.pc1)
        var cs = [Array(kPlus[0..<28])], ds = [Array(kPlus[28..<56])]
        var keys: [[Int]] = []
        for i in 0..<16 {
            cs.append(Self.rotl(cs[i], Self.shifts[i]))
            ds.append(Self.rotl(ds[i], Self.shifts[i]))
            keys.append(Self.permute(cs[i + 1] + ds[i + 1], Self.pc2))
        }
        c = cs; d = ds; subkeys = keys
        var ls = [Array(permutedInput[0..<32])], rs = [Array(permutedInput[32..<64])]
        var es: [[Int]] = [], bs: [[Int]] = [], ss: [[Int]] = [], fs: [[Int]] = []
        for i in 0..<16 {
            let e = Self.permute(rs[i], Self.expansion)
            let b = zip(e, keys[i]).map { $0 ^ $1 }
            var s: [Int] = []
            for j in 0..<8 {
                let v = Self.sbox(j, Array(b[(6 * j)..<(6 * j + 6)])).value
                s += [(v >> 3) & 1, (v >> 2) & 1, (v >> 1) & 1, v & 1]
            }
            let fv = Self.permute(s, Self.p)
            es.append(e); bs.append(b); ss.append(s); fs.append(fv)
            ls.append(rs[i])
            rs.append(zip(ls[i], fv).map { $0 ^ $1 })
        }
        l = ls; r = rs; expanded = es; xored = bs; sboxOut = ss; f = fs
        preOutput = rs[16] + ls[16]
        output = Self.permute(preOutput, Self.ipInverse)
    }

    static func hex(_ bits: [Int]) -> String {
        stride(from: 0, to: bits.count, by: 4).map { i -> String in
            var v = 0
            for j in 0..<4 where i + j < bits.count { v = v * 2 + bits[i + j] }
            return String(v, radix: 16, uppercase: true)
        }.joined()
    }
}
