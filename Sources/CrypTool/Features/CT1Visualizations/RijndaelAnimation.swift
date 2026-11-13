import AppKit
import SwiftUI
import CTCommon
import CTModern

// Native version of CT1's Flash animation "Rijndael Animation" (Enrique Zabala, version 4.0,
// Rijndael_Animation_v4_eng.swf): intro, the encryption process (initial round, round 1 in
// detail, rounds 2–9, final round) and the key expansion. Data: FIPS-197 Appendix B as in CT1;
// own data (128-bit key) can be entered. Values come from CTModern.AESInspector.

extension CT1Visualizations {
    static func openRijndaelAnimation() {
        WindowPresenter.tool(id: "ct1-rijndael-anim", title: "Rijndael Animation", size: CGSize(width: 1120, height: 860)) {
            RijndaelAnimationView()
        }
    }
}

enum RijndaelAnimationScript {
    static let stage = CGSize(width: 1000, height: 680)
    static let exampleBlock: [UInt8] = [0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d, 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07, 0x34]
    static let exampleKey: [UInt8] = [0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c]
    static let mixMatrix: [[UInt8]] = [[2, 3, 1, 1], [1, 2, 3, 1], [1, 1, 2, 3], [3, 1, 1, 2]]

    static func build(block: [UInt8], key: [UInt8]) throws -> AnimScript {
        let tr = try AESInspector.trace(key: key, block: block)
        let b = AnimScriptBuilder()
        Script(b: b, steps: tr.steps, roundKeys: tr.roundKeys, key: key, block: block, cipher: tr.ciphertext).run()
        return AnimScript(b, size: stage)
    }

    static func h(_ v: UInt8) -> String { String(format: "%02x", v) }

    private final class Script {
        let b: AnimScriptBuilder
        let steps: [AESTraceStep]
        let roundKeys: [[UInt8]]
        let key: [UInt8], block: [UInt8], cipher: [UInt8]
        var lines: [String] = []
        var counter = 0
        var slideIDs: [String] = []

        init(b: AnimScriptBuilder, steps: [AESTraceStep], roundKeys: [[UInt8]], key: [UInt8], block: [UInt8], cipher: [UInt8]) {
            self.b = b; self.steps = steps; self.roundKeys = roundKeys; self.key = key; self.block = block; self.cipher = cipher
        }

        func state(_ round: Int, _ op: String) -> [UInt8] {
            steps.first { $0.round == round && $0.operation == op }?.state ?? []
        }

        // MARK: helpers

        func say(_ ls: String...) {
            for l in ls {
                counter += 1
                let id = "tx\(counter)"
                b.text(id, l, x: 20, y: 540 + CGFloat(lines.count) * 19, size: 14)
                lines.append(id)
            }
        }

        func clearText() { b.remove(lines); lines = [] }

        @discardableResult
        func s(_ id: String) -> String { slideIDs.append(id); return id }

        /// Starts a new slide (chapter): removes the previous slide's elements and texts.
        func slide(_ number: Int, _ title: String, subtitle: String? = nil) {
            b.remove(slideIDs); slideIDs = []
            clearText()
            b.chapter(String(format: "%02d – ", number) + title)
            b.text(s("title"), title, x: 20, y: 10, size: 22, bold: true)
            if let subtitle { b.text(s("subtitle"), subtitle, x: 20, y: 42, size: 14, color: .secondary) }
            b.text(s("slideNo"), String(format: "%02d / 18", number), x: 920, y: 14, size: 12, color: .secondary)
        }

        func label(_ id: String, _ t: String, x: CGFloat, y: CGFloat, size: CGFloat = 14, color: AnimColor = .text, bold: Bool = false) {
            b.text(s(id), t, x: x, y: y, size: size, color: color, bold: bold)
        }

        /// 4×4 byte matrix; byte i (column-major, FIPS-197) at row i % 4, column i / 4.
        func matrix(_ p: String, _ bytes: [UInt8], x: CGFloat, y: CGFloat, cw: CGFloat = 40, ch: CGFloat = 30,
                    fill: AnimColor = .cell, size: CGFloat = 15, title: String? = nil) {
            if let title { b.text(s(p + "T"), title, x: x, y: y - 22, size: 13) }
            for i in 0..<16 {
                let x0 = x + CGFloat(i / 4) * cw, y0 = y + CGFloat(i % 4) * ch
                b.box(s("\(p)b\(i)"), x: x0, y: y0, w: cw, h: ch, fill: fill)
                b.cellText(s("\(p)\(i)"), h(bytes[i]), x: x0, y: y0, w: cw, h: ch, size: size)
            }
        }

        func setMatrix(_ p: String, _ bytes: [UInt8], indices: [Int]? = nil, color: AnimColor = .text) {
            for i in indices ?? Array(0..<16) { b.setText("\(p)\(i)", h(bytes[i])); b.setColor("\(p)\(i)", color) }
        }

        func colorMatrix(_ p: String, _ c: AnimColor, indices: [Int]? = nil) {
            for i in indices ?? Array(0..<16) { b.setColor("\(p)\(i)", c) }
        }

        func h(_ v: UInt8) -> String { RijndaelAnimationScript.h(v) }

        // MARK: script

        func run() {
            intro()
            dataSlide()
            overview()
            transformations()
            initialRound()
            subBytes()
            shiftRows()
            mixColumns()
            addRoundKey1()
            rounds2to9()
            finalRound()
            ciphertext()
            keyScheduleIntro()
            keyFirstWords()
            keyRotSub()
            keyXorRcon()
            keyRest()
            keyAll()
        }

        func intro() {
            slide(1, "Rijndael")
            label("big", "Rijndael", x: 60, y: 90, size: 54, bold: true)
            label("win", "(winner of the AES selection)", x: 64, y: 160, size: 18)
            b.commit()
            label("len1", "Animation using a 128 bit size", x: 64, y: 220, size: 16)
            label("len2", "for each the data block and the key", x: 64, y: 242, size: 16)
            b.commit()
            label("hexT", "Hexadecimal notation (sample):", x: 64, y: 320, size: 16)
            b.box(s("hexB"), x: 64, y: 350, w: 44, h: 32, fill: .highlight)
            b.cellText(s("hexV"), "32", x: 64, y: 350, w: 44, h: 32, size: 17)
            label("hexE", "=  00110010 (1 byte)", x: 120, y: 356, size: 16)
            label("ver", "Animation by Enrique Zabala · Version 4.0 - made for the CrypTool project (www.cryptool.org) with the help of Bernhard Esslinger",
                  x: 20, y: 500, size: 11, color: .secondary)
            say("How to navigate through the animation: use \"Continue\" (Enter key) to advance; use the chapter menu to jump directly to individual slides.")
            b.commit()
        }

        func dataSlide() {
            slide(2, "Plaintext block (State) and Cipher key")
            for i in 0..<16 {
                b.cellText(s("inRow\(i)"), h(block[i]), x: 60 + CGFloat(i) * 30, y: 80, w: 30, h: 22, size: 14)
                b.cellText(s("keyRow\(i)"), h(key[i]), x: 60 + CGFloat(i) * 30, y: 300, w: 30, h: 22, size: 14)
            }
            label("inL", "Input:", x: 4, y: 82, size: 13, color: .secondary)
            label("keyL", "Key:", x: 4, y: 302, size: 13, color: .secondary)
            say("This is a block from the plaintext message (State) to be encrypted, and the Cipher key.")
            b.commit()
            // the bytes move column by column into the matrices
            for i in 0..<16 {
                b.spawnCopy(of: "inRow\(i)", as: s("st\(i)"), z: 6)
                b.spawnCopy(of: "keyRow\(i)", as: s("ky\(i)"), z: 6)
            }
            for i in 0..<16 {
                let x0 = 600 + CGFloat(i / 4) * 40, y0 = 70 + CGFloat(i % 4) * 30
                b.box(s("stb\(i)"), x: x0, y: y0, w: 40, h: 30, fill: .cell)
                b.setSize("st\(i)", w: 40, h: 30); b.move("st\(i)", x: x0, y: y0)
                let y1 = 290 + CGFloat(i % 4) * 30
                b.box(s("kyb\(i)"), x: x0, y: y1, w: 40, h: 30, fill: .cellAlt)
                b.setSize("ky\(i)", w: 40, h: 30); b.move("ky\(i)", x: x0, y: y1)
            }
            label("stT", "Plaintext block (State)", x: 600, y: 46, size: 13)
            label("kyT", "Cipher key", x: 600, y: 266, size: 13)
            say("The 16 bytes are written column by column (!) into a 4×4 byte matrix (16 bytes = 128 bits).")
            b.commit()
        }

        func overview() {
            slide(3, "Encryptor")
            matrix("st", block, x: 60, y: 110, title: "Plaintext block (State)")
            matrix("ky", key, x: 60, y: 300, fill: .cellAlt, title: "Cipher key")
            b.box(s("encB"), x: 300, y: 110, w: 560, h: 120, fill: .cellAlt)
            label("encT", "Encryption Process", x: 316, y: 120, size: 17, bold: true)
            label("enc1", "(Performing the encryption of the given plaintext block using", x: 316, y: 150, size: 14)
            label("enc2", "4 different transformations in the initial round, the 9 main rounds", x: 316, y: 170, size: 14)
            label("enc3", "and the final round)", x: 316, y: 190, size: 14)
            b.line(s("encA"), [CGPoint(x: 222, y: 170), CGPoint(x: 296, y: 170)])
            b.commit()
            b.box(s("expB"), x: 300, y: 300, w: 560, h: 120, fill: .cell)
            label("expT", "Key Schedule", x: 316, y: 310, size: 17, bold: true)
            label("exp1", "(Expansion of the given Cipher key into 11 partial keys, used in the", x: 316, y: 340, size: 14)
            label("exp2", "initial round, the 9 main rounds and the final round)", x: 316, y: 360, size: 14)
            b.line(s("expA"), [CGPoint(x: 222, y: 360), CGPoint(x: 296, y: 360)])
            b.line(s("expA2"), [CGPoint(x: 580, y: 300), CGPoint(x: 580, y: 234)])
            label("expA2t", "Round key", x: 590, y: 256, size: 12, color: .secondary)
            b.commit()
        }

        func transformations() {
            slide(4, "Encryption Process: Transformations")
            label("tT", "The 4 types of transformations:", x: 60, y: 80, size: 17, bold: true)
            let names = ["1 - SubBytes", "2 - ShiftRows", "3 - MixColumns", "4 - AddRoundKey"]
            for (i, n) in names.enumerated() { label("tn\(i)", n, x: 80, y: 112 + CGFloat(i) * 26, size: 16) }
            b.commit()
            let col: [(String, [String])] = [("initial round", ["AddRoundKey"]),
                                             ("9 main rounds", ["SubBytes", "ShiftRows", "MixColumns", "AddRoundKey"]),
                                             ("final round", ["SubBytes", "ShiftRows", "AddRoundKey"])]
            for (j, c) in col.enumerated() {
                let x = 340 + CGFloat(j) * 210
                b.box(s("rb\(j)"), x: x, y: 80, w: 180, h: 30, fill: .cellAlt)
                b.cellText(s("rt\(j)"), c.0, x: x, y: 80, w: 180, h: 30, size: 15, bold: true, mono: false)
                for (k, op) in c.1.enumerated() {
                    b.box(s("ro\(j)_\(k)"), x: x + 20, y: 126 + CGFloat(k) * 36, w: 140, h: 28, fill: .cell)
                    b.cellText(s("rot\(j)_\(k)"), op, x: x + 20, y: 126 + CGFloat(k) * 36, w: 140, h: 28, size: 14, mono: false)
                }
            }
            b.line(s("ra1"), [CGPoint(x: 522, y: 95), CGPoint(x: 548, y: 95)])
            b.line(s("ra2"), [CGPoint(x: 732, y: 95), CGPoint(x: 758, y: 95)])
            say("These transformations are applied to the State for 9 more rounds.",
                "The final round does not include the MixColumns transformation.")
            b.setColor("rot2_2", .text)
            b.commit()
        }

        /// State ⊕ round key = result, column by column.
        func addRoundKeySteps(prefixState: String, before: [UInt8], roundKey: [UInt8], after: [UInt8], keyTitle: String) {
            matrix("ark", roundKey, x: 300, y: 120, fill: .cellAlt, title: keyTitle)
            label("xorSign", "⊕", x: 245, y: 165, size: 30)
            label("eqSign", "=", x: 485, y: 168, size: 26)
            for i in 0..<16 {
                let x0 = 540 + CGFloat(i / 4) * 40, y0 = 120 + CGFloat(i % 4) * 30
                b.box(s("arrb\(i)"), x: x0, y: y0, w: 40, h: 30, fill: .white)
            }
            b.commit()
            let ex = 0
            colorMatrix(prefixState, .red, indices: [ex]); colorMatrix("ark", .red, indices: [ex])
            b.cellText(s("arr\(ex)"), h(after[ex]), x: 540, y: 120, w: 40, h: 30, size: 15, color: .red)
            label("arkEx", "\(h(before[ex])) ⊕ \(h(roundKey[ex])) = \(h(after[ex]))", x: 540, y: 270, size: 15, color: .red)
            b.commit()
            colorMatrix(prefixState, .text); colorMatrix("ark", .text)
            b.setColor("arr\(ex)", .text)
            for i in 1..<16 {
                b.cellText(s("arr\(i)"), h(after[i]), x: 540 + CGFloat(i / 4) * 40, y: 120 + CGFloat(i % 4) * 30, w: 40, h: 30, size: 15)
            }
            b.commit()
        }

        func initialRound() {
            slide(5, "Initial round: AddRoundKey", subtitle: "Round 0")
            matrix("st", block, x: 60, y: 120, title: "State")
            say("AddRoundKey: Each byte of the State is XORed with the corresponding byte of the Round key.",
                "In the initial round the Cipher key is used as Round key.")
            addRoundKeySteps(prefixState: "st", before: block, roundKey: roundKeys[0], after: state(0, "AddRoundKey"), keyTitle: "Cipher key")
        }

        func subBytes() {
            slide(6, "Round 1: SubBytes", subtitle: "1 - SubBytes")
            let before = state(0, "AddRoundKey"), after = state(1, "SubBytes")
            matrix("st", before, x: 60, y: 120, title: "State")
            // S-box
            let sx: CGFloat = 400, sy: CGFloat = 96, cw: CGFloat = 34, ch: CGFloat = 20
            label("sbT", "Byte substitution table (S-Box)", x: sx, y: sy - 34, size: 14, bold: true)
            label("sbY", "y", x: sx + 20 + 8 * cw, y: sy - 16, size: 11, color: .secondary)
            label("sbX", "x", x: sx - 14, y: sy + 8 * ch, size: 11, color: .secondary)
            for j in 0..<16 {
                b.cellText(s("sbc\(j)"), String(j, radix: 16), x: sx + 20 + CGFloat(j) * cw, y: sy, w: cw, h: ch, size: 12, color: .secondary, bold: true)
                b.cellText(s("sbr\(j)"), String(j, radix: 16), x: sx, y: sy + ch + CGFloat(j) * ch, w: 20, h: ch, size: 12, color: .secondary, bold: true)
                for i in 0..<16 {
                    b.box(s("sbb\(j)_\(i)"), x: sx + 20 + CGFloat(i) * cw, y: sy + ch + CGFloat(j) * ch, w: cw, h: ch, fill: .white)
                    b.cellText(s("sbv\(j)_\(i)"), h(AESInspector.sbox[j * 16 + i]), x: sx + 20 + CGFloat(i) * cw, y: sy + ch + CGFloat(j) * ch,
                               w: cw, h: ch, size: 11)
                }
            }
            say("SubBytes: Each byte of the State is replaced by another byte using the byte substitution table (S-Box).")
            b.commit()
            for ex in [0, 1] {
                let v = before[ex], x = Int(v >> 4), y = Int(v & 0x0f)
                b.setColor("st\(ex)", .red)
                for i in 0..<16 { b.setFill("sbb\(x)_\(i)", .highlight) }
                for j in 0..<16 { b.setFill("sbb\(j)_\(y)", .highlight) }
                b.setColor("sbv\(x)_\(y)", .red)
                label("sbEx\(ex)", "\(h(v)): row x = \(String(x, radix: 16)), column y = \(String(y, radix: 16))  →  \(h(after[ex]))",
                      x: 60, y: 280 + CGFloat(ex) * 24, size: 14, color: .red)
                b.commit()
                b.setText("st\(ex)", h(after[ex]))
                b.setFill("stb\(ex)", .highlight)
                b.commit()
                for i in 0..<16 { b.setFill("sbb\(x)_\(i)", .white) }
                for j in 0..<16 { b.setFill("sbb\(j)_\(y)", .white) }
                b.setColor(["sbv\(x)_\(y)", "st\(ex)", "sbEx\(ex)"], .text)
                b.setFill("stb\(ex)", .cell)
            }
            setMatrix("st", after, indices: Array(2..<16), color: .red)
            b.commit()
            colorMatrix("st", .text)
            b.commit()
        }

        func shiftRows() {
            slide(7, "Round 1: ShiftRows", subtitle: "2 - ShiftRows")
            let before = state(1, "SubBytes")
            let x0: CGFloat = 200, y0: CGFloat = 120, cw: CGFloat = 50, ch: CGFloat = 40
            for i in 0..<16 {
                let r = i % 4, c = i / 4
                b.box(s("srb\(i)"), x: x0 + CGFloat(c) * cw, y: y0 + CGFloat(r) * ch, w: cw, h: ch, fill: .cell)
                b.cellText(s("sr\(i)"), h(before[i]), x: x0 + CGFloat(c) * cw, y: y0 + CGFloat(r) * ch, w: cw, h: ch, size: 17, z: 4)
            }
            label("srT", "State", x: x0, y: y0 - 24, size: 13)
            say("ShiftRows: The rows of the State are cyclically shifted to the left – row 0 remains unchanged,",
                "row 1 is rotated over 1 byte, row 2 over 2 bytes and row 3 over 3 bytes.")
            b.commit()
            let names = ["", "rotate over 1 byte", "rotate over 2 bytes", "rotate over 3 bytes"]
            for r in 1..<4 {
                label("srL\(r)", names[r], x: x0 + 4 * cw + 30, y: y0 + CGFloat(r) * ch + 10, size: 14, color: .red)
                for c in 0..<4 {
                    let id = "sr\(r + 4 * c)"
                    let nc = (c - r + 4) % 4
                    if c < r { b.setZ(id, 8); b.setColor(id, .orange) } else { b.setColor(id, .red) }
                    b.move(id, x: x0 + CGFloat(nc) * cw, y: y0 + CGFloat(r) * ch)
                }
                b.commit()
                for c in 0..<4 { b.setColor("sr\(r + 4 * c)", .text) }
                b.setColor("srL\(r)", .text)
            }
            b.commit()
        }

        func mixColumns() {
            slide(8, "Round 1: MixColumns", subtitle: "3 - MixColumns")
            let before = state(1, "ShiftRows"), after = state(1, "MixColumns")
            matrix("st", before, x: 60, y: 120, title: "State")
            label("mmT", "Matrix", x: 300, y: 98, size: 13)
            for r in 0..<4 {
                for c in 0..<4 {
                    b.box(s("mmb\(r)_\(c)"), x: 300 + CGFloat(c) * 34, y: 120 + CGFloat(r) * 30, w: 34, h: 30, fill: .cellAlt)
                    b.cellText(s("mm\(r)_\(c)"), String(format: "%02x", RijndaelAnimationScript.mixMatrix[r][c]),
                               x: 300 + CGFloat(c) * 34, y: 120 + CGFloat(r) * 30, w: 34, h: 30, size: 15)
                }
            }
            label("mmX", "·", x: 450, y: 160, size: 30)
            say("The four numbers of one column are modulo multiplied in Rijndael's Galois Field by a given matrix.")
            b.commit()
            // column 0
            for r in 0..<4 { b.setColor("st\(r)", .red); b.setFill("stb\(r)", .highlight) }
            for r in 0..<4 {
                b.box(s("mcb\(r)"), x: 470, y: 120 + CGFloat(r) * 30, w: 40, h: 30, fill: .highlight)
                b.cellText(s("mc\(r)"), h(before[r]), x: 470, y: 120 + CGFloat(r) * 30, w: 40, h: 30, size: 15, color: .red)
            }
            b.commit()
            label("mcEq", "=", x: 524, y: 168, size: 26)
            for r in 0..<4 {
                let m = RijndaelAnimationScript.mixMatrix[r]
                let terms = (0..<4).map { "\(String(format: "%02x", m[$0]))·\(h(before[$0]))" }.joined(separator: " ⊕ ")
                b.box(s("mrb\(r)"), x: 552, y: 120 + CGFloat(r) * 30, w: 40, h: 30, fill: .white)
                b.cellText(s("mr\(r)"), h(after[r]), x: 552, y: 120 + CGFloat(r) * 30, w: 40, h: 30, size: 15, color: .red)
                label("mrT\(r)", "= " + terms, x: 600, y: 126 + CGFloat(r) * 30, size: 13, color: .secondary)
                if let it = b.item("mrT\(r)") { var m2 = it; m2.mono = true; b.put(m2) }
            }
            b.commit()
            for r in 0..<4 {
                b.remove("mr\(r)")
                b.setText("st\(r)", h(after[r])); b.setFill("stb\(r)", .cell)
            }
            b.remove(["mcEq"] + (0..<4).flatMap { ["mcb\($0)", "mc\($0)", "mrb\($0)", "mrT\($0)"] })
            b.commit()
            setMatrix("st", after, indices: Array(4..<16), color: .red)
            for r in 0..<4 { b.setColor("st\(r)", .text) }
            b.commit()
            colorMatrix("st", .text)
            say("The MixColumns step along with the ShiftRows step is the primary source of diffusion in Rijndael.")
            b.commit()
        }

        func addRoundKey1() {
            slide(9, "Round 1: AddRoundKey", subtitle: "4 - AddRoundKey")
            let before = state(1, "MixColumns")
            matrix("st", before, x: 60, y: 120, title: "State")
            say("The State is XORed with Round key 1",
                "(produced as Round key during the Key Schedule).")
            addRoundKeySteps(prefixState: "st", before: before, roundKey: roundKeys[1], after: state(1, "AddRoundKey"), keyTitle: "Round key 1")
        }

        /// One FIPS-197 Appendix B style row: start, SubBytes, ShiftRows, (MixColumns), round key → result.
        func roundRow(_ r: Int, y: CGFloat) {
            let start = state(r - 1, "AddRoundKey")
            var cols: [(String, [UInt8], AnimColor)] = [("Start of round", start, .cell),
                                                        ("After SubBytes", state(r, "SubBytes"), .cell),
                                                        ("After ShiftRows", state(r, "ShiftRows"), .cell)]
            if r < roundKeys.count - 1 { cols.append(("After MixColumns", state(r, "MixColumns"), .cell)) }
            cols.append(("Round key \(r)", roundKeys[r], .cellAlt))
            cols.append(("Result", state(r, "AddRoundKey"), .highlight))
            for (k, c) in cols.enumerated() {
                matrix("r\(r)m\(k)", c.1, x: 40 + CGFloat(k) * 155, y: y, cw: 30, ch: 24, fill: c.2, size: 13, title: c.0)
                if k > 0 {
                    let sym = c.0.hasPrefix("Round key") ? "⊕" : (c.0 == "Result" ? "=" : "→")
                    label("r\(r)a\(k)", sym, x: 40 + CGFloat(k) * 155 - 30, y: y + 34, size: 20, color: .secondary)
                }
            }
        }

        func rounds2to9() {
            slide(10, "Rounds 2 to 9", subtitle: "SubBytes → ShiftRows → MixColumns → AddRoundKey")
            say("The remaining main rounds follow the same scheme.")
            let last = roundKeys.count - 1
            for r in 2..<last {
                b.remove(slideIDs.filter { $0.hasPrefix("r\(r - 1)") || $0 == "roundL" })
                slideIDs.removeAll { $0.hasPrefix("r\(r - 1)") || $0 == "roundL" }
                label("roundL", "Round \(r)", x: 40, y: 110, size: 20, color: .red, bold: true)
                roundRow(r, y: 190)
                b.commit()
            }
        }

        func finalRound() {
            let last = roundKeys.count - 1
            slide(11, "Final round (Round \(last))", subtitle: "SubBytes → ShiftRows → AddRoundKey (without MixColumns)")
            label("roundL", "Round \(last)", x: 40, y: 110, size: 20, color: .red, bold: true)
            roundRow(last, y: 190)
            say("The final round does not include the MixColumns transformation.")
            b.commit()
        }

        func ciphertext() {
            slide(12, "Ciphertext")
            matrix("ct", cipher, x: 80, y: 120, cw: 50, ch: 38, fill: .highlight, size: 18, title: "Ciphertext")
            label("ctT", "This is the encrypted block:", x: 340, y: 130, size: 15)
            label("ctH", cipher.map { h($0) }.joined(separator: " "), x: 340, y: 160, size: 16, bold: true)
            if let it = b.item("ctH") { var m = it; m.mono = true; b.put(m) }
            label("ctN", "(read from the matrix column by column)", x: 340, y: 188, size: 13, color: .secondary)
            say("The output is again 16 bytes. The matrix is read column by column.")
            if block == RijndaelAnimationScript.exampleBlock && key == RijndaelAnimationScript.exampleKey {
                say("The data is taken from FIPS-197, Appendix B.")
            }
            b.commit()
        }

        // MARK: key expansion

        let wx0: CGFloat = 32, wcw: CGFloat = 21.5, wy0: CGFloat = 130, wch: CGFloat = 22

        func words() -> [[UInt8]] {
            roundKeys.flatMap { rk in (0..<4).map { Array(rk[(4 * $0)..<(4 * $0 + 4)]) } }
        }

        func wordGrid(filled: Int) {
            for i in 0..<44 {
                b.cellText(s("wi\(i)"), "\(i)", x: wx0 + CGFloat(i) * wcw, y: wy0 - 18, w: wcw, h: 16, size: 9, color: .secondary, mono: false)
                for r in 0..<4 {
                    b.box(s("wb\(i)_\(r)"), x: wx0 + CGFloat(i) * wcw, y: wy0 + CGFloat(r) * wch, w: wcw, h: wch,
                          fill: (i / 4) % 2 == 0 ? .cell : .cellAlt)
                }
                if i < filled { fillWord(i, color: .text) }
            }
            for k in 0..<11 {
                b.cellText(s("rkL\(k)"), k == 0 ? "Cipher key" : "RK \(k)", x: wx0 + CGFloat(4 * k) * wcw, y: wy0 + 4 * wch + 2,
                           w: 4 * wcw, h: 14, size: 9, color: .secondary, mono: false)
            }
        }

        func fillWord(_ i: Int, color: AnimColor) {
            let w = words()[i]
            for r in 0..<4 {
                b.cellText(s("w\(i)_\(r)"), h(w[r]), x: wx0 + CGFloat(i) * wcw, y: wy0 + CGFloat(r) * wch, w: wcw, h: wch, size: 10.5, color: color)
            }
        }

        func colWord(_ p: String, _ w: [UInt8], x: CGFloat, title: String, fill: AnimColor = .cell, color: AnimColor = .text) {
            b.text(s(p + "T"), title, x: x - 10, y: 252, size: 11.5, color: .secondary)
            for r in 0..<4 {
                b.box(s("\(p)b\(r)"), x: x, y: 272 + CGFloat(r) * 26, w: 36, h: 26, fill: fill)
                b.cellText(s("\(p)\(r)"), h(w[r]), x: x, y: 272 + CGFloat(r) * 26, w: 36, h: 26, size: 14, color: color)
            }
        }

        func keyScheduleIntro() {
            slide(13, "Key Schedule", subtitle: "(Expansion of the given Cipher key into 11 partial keys)")
            wordGrid(filled: 0)
            say("The expanded key can be seen as an array of 32-bit words (columns),",
                "numbered from 0 to 43.")
            b.commit()
        }

        func keyFirstWords() {
            slide(14, "Key Schedule: Cipher key", subtitle: "Columns 0 to 3")
            wordGrid(filled: 0)
            matrix("ky", key, x: 60, y: 300, fill: .cellAlt, title: "Cipher key")
            b.commit()
            for i in 0..<4 {
                for r in 0..<4 { b.spawnCopy(of: "ky\(i * 4 + r)", as: s("w\(i)_\(r)"), z: 6) }
                for r in 0..<4 {
                    b.setSize("w\(i)_\(r)", w: wcw, h: wch)
                    b.move("w\(i)_\(r)", x: wx0 + CGFloat(i) * wcw, y: wy0 + CGFloat(r) * wch)
                }
            }
            say("The first four columns are filled with the given Cipher key.")
            b.commit()
        }

        func keyRotSub() {
            slide(15, "Key Schedule: RotWord and SubBytes", subtitle: "Column 4")
            wordGrid(filled: 4)
            let w = words()
            for r in 0..<4 { b.setColor("w3_\(r)", .red) }
            say("Words in positions that are a multiple of 4 are calculated by:",
                "a) applying the RotWord and SubBytes transformation to the previous word.")
            b.commit()
            colWord("cw3", w[3], x: 80, title: "Column 3")
            b.commit()
            let rot = [w[3][1], w[3][2], w[3][3], w[3][0]]
            label("a1", "→", x: 128, y: 310, size: 22, color: .secondary)
            colWord("crot", rot, x: 160, title: "RotWord", color: .red)
            b.commit()
            let sub = rot.map { AESInspector.sbox[Int($0)] }
            label("a2", "→", x: 208, y: 310, size: 22, color: .secondary)
            colWord("csub", sub, x: 240, title: "SubBytes", color: .red)
            b.setColor(["crot0", "crot1", "crot2", "crot3"], .text)
            b.commit()
            b.setColor(["csub0", "csub1", "csub2", "csub3"], .text)
            for r in 0..<4 { b.setColor("w3_\(r)", .text) }
        }

        func keyXorRcon() {
            slide(16, "Key Schedule: XOR with Rcon", subtitle: "Column 4")
            wordGrid(filled: 4)
            let w = words()
            let rot = [w[3][1], w[3][2], w[3][3], w[3][0]]
            let sub = rot.map { AESInspector.sbox[Int($0)] }
            colWord("csub", sub, x: 80, title: "SubBytes")
            say("b) Adding (XOR) this result to the word 4 positions earlier,",
                "plus a round constant Rcon.")
            b.commit()
            for r in 0..<4 { b.setColor("w0_\(r)", .red) }
            label("x1", "⊕", x: 126, y: 312, size: 22)
            colWord("cw0", w[0], x: 160, title: "Column 0", color: .red)
            b.commit()
            let rcon: [UInt8] = [1, 0, 0, 0]
            label("x2", "⊕", x: 206, y: 312, size: 22)
            colWord("crc", rcon, x: 240, title: "Rcon(1)", fill: .cellAlt, color: .red)
            b.commit()
            label("x3", "=", x: 286, y: 312, size: 22)
            colWord("cw4", w[4], x: 320, title: "Column 4", fill: .highlight, color: .red)
            b.commit()
            for r in 0..<4 { b.spawnCopy(of: "cw4\(r)", as: s("w4_\(r)"), z: 6) }
            for r in 0..<4 {
                b.setSize("w4_\(r)", w: wcw, h: wch); b.move("w4_\(r)", x: wx0 + 4 * wcw, y: wy0 + CGFloat(r) * wch)
                b.setColor("w0_\(r)", .text)
            }
            label("rconT", "Rcon: 01 02 04 08 10 20 40 80 1b 36 (first byte each, rest 00)", x: 420, y: 290, size: 12, color: .secondary)
            b.commit()
        }

        func keyRest() {
            slide(17, "Key Schedule: the remaining columns", subtitle: "Columns 5 to 7")
            wordGrid(filled: 5)
            let w = words()
            say("The remaining 32-bit words are calculated by adding (XOR) the previous word",
                "with the word 4 positions earlier.")
            b.commit()
            for i in 5..<8 {
                b.remove(slideIDs.filter { $0.hasPrefix("cA") || $0.hasPrefix("cB") || $0.hasPrefix("cC") || $0.hasPrefix("xx") })
                slideIDs.removeAll { $0.hasPrefix("cA") || $0.hasPrefix("cB") || $0.hasPrefix("cC") || $0.hasPrefix("xx") }
                for r in 0..<4 { b.setColor("w\(i - 1)_\(r)", .red); b.setColor("w\(i - 4)_\(r)", .blue) }
                colWord("cA", w[i - 1], x: 80, title: "Column \(i - 1)", color: .red)
                label("xx1", "⊕", x: 126, y: 312, size: 22)
                colWord("cB", w[i - 4], x: 160, title: "Column \(i - 4)", color: .blue)
                label("xx2", "=", x: 206, y: 312, size: 22)
                colWord("cC", w[i], x: 240, title: "Column \(i)", fill: .highlight)
                b.commit()
                for r in 0..<4 { b.spawnCopy(of: "cC\(r)", as: s("w\(i)_\(r)"), z: 6) }
                for r in 0..<4 {
                    b.setSize("w\(i)_\(r)", w: wcw, h: wch); b.move("w\(i)_\(r)", x: wx0 + CGFloat(i) * wcw, y: wy0 + CGFloat(r) * wch)
                    b.setColor("w\(i - 1)_\(r)", .text); b.setColor("w\(i - 4)_\(r)", .text)
                }
                b.commit()
            }
        }

        func keyAll() {
            slide(18, "Key Schedule: all Round keys", subtitle: "Columns 8 to 43")
            wordGrid(filled: 8)
            say("Columns 8 to 43, i.e. Round keys 2 to 10, are produced by the same scheme.")
            b.commit()
            for k in 2..<11 {
                for i in (4 * k)..<(4 * k + 4) { fillWord(i, color: .red) }
                b.setColor("rkL\(k)", .red)
                b.commit()
                for i in (4 * k)..<(4 * k + 4) { for r in 0..<4 { b.setColor("w\(i)_\(r)", .text) } }
                b.setColor("rkL\(k)", .secondary)
            }
            var rows: [String] = []
            for (k, rk) in roundKeys.enumerated() {
                rows.append((k == 0 ? "Cipher key   " : String(format: "Round key %2d ", k)) + rk.map { h($0) }.joined(separator: " "))
            }
            for (i, r) in rows.enumerated() {
                label("rkrow\(i)", r, x: 40, y: 246 + CGFloat(i) * 21, size: 13)
                if let it = b.item("rkrow\(i)") { var m = it; m.mono = true; b.put(m) }
            }
            b.commit()
        }
    }
}

struct RijndaelAnimationView: View {
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 1.6)
    @CTState private var script = AnimScript.empty
    @CTState private var blockHex = RijndaelAnimationScript.exampleBlock.ct1Hex
    @CTState private var keyHex = RijndaelAnimationScript.exampleKey.ct1Hex
    @CTState private var error: String?

    var body: some View {
        ScriptedAnimationView(script: script, player: player) {
            AnimationInputBar(note: error ?? "As in CT1, the example from FIPS-197, Appendix B, is preset. Plaintext block and key: 16 bytes hexadecimal each.",
                              rebuild: rebuild,
                              resetToExample: {
                                  blockHex = RijndaelAnimationScript.exampleBlock.ct1Hex
                                  keyHex = RijndaelAnimationScript.exampleKey.ct1Hex
                                  rebuild()
                              }) {
                Text("Plaintext").foregroundStyle(.secondary)
                TextField("16 bytes hex", text: $blockHex).font(.system(.body, design: .monospaced)).frame(width: 300)
                Text("Key").foregroundStyle(.secondary)
                TextField("16 bytes hex", text: $keyHex).font(.system(.body, design: .monospaced)).frame(width: 300)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        guard let blk = Hex.decode(blockHex), blk.count == 16, let k = Hex.decode(keyHex), k.count == 16 else {
            error = "Please enter plaintext block and key with exactly 16 bytes (128 bits) hexadecimal each."
            return
        }
        do {
            script = try RijndaelAnimationScript.build(block: blk, key: k)
            error = nil
            player.reset(count: script.frames.count)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
