import AppKit
import SwiftUI
import CTCommon
import CTModern

// Native version of CT1's ANIMAL animation "Visualization of Algorithms ▸ DES"
// (des_en.aml, "DES Data Encryption Standard (ECB Mode)"). Same chapters, texts and example
// (X = 16 BD 40 94 B4 53 8A 7B, K = E1 A4 BB 9B C2 E3 24 BB); all values are computed by
// `DESTrace`, so an own block/key can be animated too.

extension CT1Visualizations {
    static func openDESAnimation() {
        WindowPresenter.tool(id: "ct1-anim-des", title: "DES Data Encryption Standard (ECB Mode) – Animation", size: CGSize(width: 1180, height: 860)) {
            DESAnimationView()
        }
    }
}

enum DESAnimationScript {
    static let stage = CGSize(width: 1050, height: 735)

    static func build(plaintext: [UInt8], key: [UInt8]) -> AnimScript {
        let t = DESTrace(plaintext: plaintext, key: key)
        let b = AnimScriptBuilder()
        let s = Script(b: b, t: t)
        s.run()
        return AnimScript(b, size: stage)
    }

    private final class Script {
        let b: AnimScriptBuilder
        let t: DESTrace
        var textLines: [String] = []
        var textCounter = 0
        var workIDs: [String] = []

        init(b: AnimScriptBuilder, t: DESTrace) { self.b = b; self.t = t }

        // MARK: helpers

        let textY: CGFloat = 556, lineH: CGFloat = 19, maxLines = 9

        /// Adds explanation lines at the bottom (older lines scroll up, like a running text).
        func say(_ lines: String...) {
            for l in lines {
                if textLines.count == maxLines {
                    b.remove(textLines.removeFirst())
                    for (i, id) in textLines.enumerated() { b.move(id, x: 20, y: textY + CGFloat(i) * lineH) }
                }
                textCounter += 1
                let id = "txt\(textCounter)"
                b.text(id, l, x: 20, y: textY + CGFloat(textLines.count) * lineH, size: 13.5)
                textLines.append(id)
            }
        }

        func clearText() { b.remove(textLines); textLines = [] }

        /// Work-area element (removed by `clearWork`).
        @discardableResult
        func w(_ id: String) -> String { workIDs.append(id); return id }

        func clearWork() { b.remove(workIDs); workIDs = [] }

        func label(_ id: String, _ s: String, x: CGFloat, y: CGFloat, size: CGFloat = 13, color: AnimColor = .text, bold: Bool = false) {
            b.text(w(id), s, x: x, y: y, size: size, color: color, bold: bold)
        }

        func cellOrigin(_ k: Int, cols: Int, x: CGFloat, y: CGFloat, cw: CGFloat, ch: CGFloat) -> CGPoint {
            CGPoint(x: x + CGFloat(k % cols) * cw, y: y + CGFloat(k / cols) * ch)
        }

        func matrix(_ p: String, _ values: [String], cols: Int, x: CGFloat, y: CGFloat, cw: CGFloat = 22, ch: CGFloat = 22,
                    fill: AnimColor = .cell, size: CGFloat = 13, color: AnimColor = .text) {
            for (k, v) in values.enumerated() {
                let o = cellOrigin(k, cols: cols, x: x, y: y, cw: cw, ch: ch)
                b.box(w("\(p)b\(k)"), x: o.x, y: o.y, w: cw, h: ch, fill: fill)
                b.cellText(w("\(p)\(k)"), v, x: o.x, y: o.y, w: cw, h: ch, size: size, color: color)
            }
        }

        func emptyMatrix(_ p: String, count: Int, cols: Int, x: CGFloat, y: CGFloat, cw: CGFloat = 22, ch: CGFloat = 22) {
            for k in 0..<count {
                let o = cellOrigin(k, cols: cols, x: x, y: y, cw: cw, ch: ch)
                b.box(w("\(p)b\(k)"), x: o.x, y: o.y, w: cw, h: ch, fill: .white)
            }
        }

        func bits(_ v: [Int]) -> [String] { v.map(String.init) }

        /// Moves copies of `src[table[k]-1]` to the destination cells, `groups` of destination
        /// indices per step (CT1: "Meaning: Bit 58 … moves to the first position …").
        func permute(src: [String], table: [Int], tableIDs: [String]?, dst: String, dstOrigins: [CGPoint],
                     cw: CGFloat, ch: CGFloat, groups: [[Int]]) {
            for g in groups {
                for k in g { b.spawnCopy(of: src[table[k] - 1], as: w("\(dst)\(k)"), z: 6) }
                for k in g {
                    b.setColor(src[table[k] - 1], .red)
                    if let tableIDs { b.setColor(tableIDs[k], .red) }
                    b.setColor("\(dst)\(k)", .red)
                    b.setSize("\(dst)\(k)", w: cw, h: ch)
                    b.move("\(dst)\(k)", x: dstOrigins[k].x, y: dstOrigins[k].y)
                }
                b.commit()
                for k in g {
                    b.setColor(src[table[k] - 1], .text)
                    if let tableIDs { b.setColor(tableIDs[k], .text) }
                    b.setColor("\(dst)\(k)", .text)
                }
            }
        }

        func groups(count: Int, cols: Int, single: Int) -> [[Int]] {
            var g: [[Int]] = (0..<min(single, count)).map { [$0] }
            var k = single
            while k < count {
                let end = min(count, (k / cols + 1) * cols)
                g.append(Array(k..<end)); k = end
            }
            return g
        }

        // Schema on the right (CT1: "Overview")
        let schemaIDs = ["schX", "schK", "schIP", "schPC1", "schPI", "schPC2", "schR", "schTK", "schPO", "schIPI", "schY"]

        func schemaBox(_ id: String, _ s: String, x: CGFloat, y: CGFloat, w: CGFloat) {
            b.box(id + "b", x: x, y: y, w: w, h: 22, fill: .cellAlt)
            b.cellText(id, s, x: x, y: y, w: w, h: 22, size: 12, mono: false)
        }

        func drawSchema() {
            b.text("schT", "Overview", x: 868, y: 8, size: 14, bold: true)
            schemaBox("schX", "Input block X", x: 772, y: 36, w: 120)
            schemaBox("schK", "Key K", x: 912, y: 36, w: 110)
            b.cellText("schIP", "IP", x: 812, y: 76, w: 40, h: 20, size: 12, mono: false)
            b.cellText("schPC1", "PC1", x: 947, y: 76, w: 40, h: 20, size: 12, mono: false)
            schemaBox("schPI", "Permuted input", x: 762, y: 112, w: 140)
            schemaBox("schPC2", "PC2(K)", x: 917, y: 112, w: 100)
            schemaBox("schR", "16 DES rounds", x: 772, y: 162, w: 120)
            schemaBox("schTK", "16 subkeys", x: 912, y: 162, w: 110)
            schemaBox("schPO", "Pre-output", x: 772, y: 212, w: 120)
            b.cellText("schIPI", "IP⁻¹", x: 812, y: 252, w: 40, h: 20, size: 12, mono: false)
            schemaBox("schY", "Output block Y", x: 772, y: 288, w: 120)
            let a: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (832, 58, 832, 76), (832, 96, 832, 112), (967, 58, 967, 76), (967, 96, 967, 112),
                (832, 134, 832, 162), (967, 134, 967, 162), (912, 173, 893, 173), (832, 184, 832, 212),
                (832, 234, 832, 252), (832, 272, 832, 288)]
            for (i, l) in a.enumerated() {
                b.line("schA\(i)", [CGPoint(x: l.0, y: l.1), CGPoint(x: l.2, y: l.3)], color: .secondary)
            }
        }

        func highlight(_ ids: String...) {
            for id in schemaIDs { b.setColor(id, ids.contains(id) ? .red : .text) }
        }

        func hexBox(_ id: String, _ s: String, x: CGFloat, y: CGFloat, w wd: CGFloat, fill: AnimColor = .cell) {
            b.box(w(id + "b"), x: x, y: y, w: wd, h: 24, fill: fill)
            b.cellText(w(id), s, x: x, y: y, w: wd, h: 24, size: 13)
        }

        func hx(_ bits: [Int]) -> String {
            let h = DESTrace.hex(bits)
            return stride(from: 0, to: h.count, by: 2).map { i -> String in
                let a = h.index(h.startIndex, offsetBy: i)
                return String(h[a..<h.index(a, offsetBy: min(2, h.count - i))])
            }.joined(separator: " ")
        }

        // MARK: script

        func run() {
            intro()
            initialPermutation()
            pc1()
            subkeys()
            feistel()
            functionF()
            finalPermutation()
        }

        func intro() {
            b.chapter("Prerequisites")
            label("bigDES", "DES", x: 150, y: 40, size: 72, bold: true)
            label("bigDES2", "Data Encryption Standard", x: 110, y: 150, size: 24)
            label("bigDES3", "(ECB Mode)", x: 185, y: 186, size: 16)
            drawSchema()
            b.commit()
            say("- For DES encryption, the plaintext is split into blocks of 64 bits.")
            highlight("schX", "schK")
            b.commit()
            clearWork()
            label("lX", "Input block X  [64-bit]", x: 20, y: 34)
            matrix("x", bits(t.x), cols: 8, x: 20, y: 56)
            label("lXh", "X = " + hx(t.x), x: 20, y: 240, size: 11, color: .secondary)
            label("lK", "Key K  [64-bit]", x: 240, y: 34)
            matrix("k", bits(t.k), cols: 8, x: 240, y: 56)
            label("lKh", "K = " + hx(t.k), x: 240, y: 240, size: 11, color: .secondary)
            say("Each block (i.e. input X) will pass the following algorithm for complete plaintext encryption.")
            highlight("schX", "schIP", "schPI", "schR", "schPO", "schIPI", "schY")
            b.commit()
            say("- The first step is to rearrange all bits of input X according to the initial permutation (IP).")
            highlight("schX", "schIP")
            b.commit()
        }

        func initialPermutation() {
            b.chapter("Prerequsities: initial permutation (IP)")
            clearText()
            for k in 0..<64 { b.remove("kb\(k)", "k\(k)") }
            b.remove("lK", "lKh")
            b.commit()
            label("lIP", "Initial permutation matrix", x: 240, y: 34)
            matrix("ip", DESTrace.ip.map(String.init), cols: 8, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lPI", "Permuted input", x: 460, y: 34)
            emptyMatrix("pi", count: 64, cols: 8, x: 460, y: 56)
            highlight("schIP", "schPI")
            b.commit()
            say("- Therefore the numbers within IP mark the position of the input bit to be put into this place.",
                "  Meaning: Bit \(DESTrace.ip[0]) of input X moves to the first position, Bit \(DESTrace.ip[1]) to the second, and so on...")
            b.commit()
            permute(src: (0..<64).map { "x\($0)" }, table: DESTrace.ip, tableIDs: (0..<64).map { "ip\($0)" }, dst: "pi",
                    dstOrigins: (0..<64).map { cellOrigin($0, cols: 8, x: 460, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 64, cols: 8, single: 8))
            label("lPIh", "= " + hx(t.permutedInput), x: 460, y: 240, size: 11, color: .secondary)
            say("  Result is the permuted input.")
            highlight("schPI")
            b.commit()
        }

        func pc1() {
            b.chapter("Prerequisites: key generation: PC1")
            clearText()
            clearWork()
            label("lK", "Key K", x: 20, y: 34)
            matrix("k", bits(t.k), cols: 8, x: 20, y: 56)
            say("- Next step is to pass the 64-bit key K through a permutation called permuted choice 1 (PC1).")
            highlight("schK", "schPC1")
            b.commit()
            say("- Before doing so, the rightmost bits (every 8th bit) of K are stripped. These bits are for parity checking and have",
                "  no further influence on the encryption.")
            for r in 0..<8 { b.setColor("k\(r * 8 + 7)", .red); b.setFill("kb\(r * 8 + 7)", .highlight) }
            b.commit()
            for r in 0..<8 { b.remove("k\(r * 8 + 7)", "kb\(r * 8 + 7)") }
            say("  Notice that the key is now shortened to 56 bits!")
            b.commit()
            label("lPC1", "Permuted choice (PC1)", x: 240, y: 34)
            matrix("pc1", DESTrace.pc1.map(String.init), cols: 7, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lKp", "56-bit key K'", x: 440, y: 34)
            emptyMatrix("kp", count: 56, cols: 7, x: 440, y: 56)
            say("- Again, the numbers within PC1 mark the index of each bit in K that is moved into this place.")
            b.commit()
            say("- Meaning: Bit \(DESTrace.pc1[0]) moves to the first place, bit \(DESTrace.pc1[1]) to the second, and so on...")
            b.commit()
            permute(src: (0..<64).map { "k\($0)" }, table: DESTrace.pc1, tableIDs: (0..<56).map { "pc1\($0)" }, dst: "kp",
                    dstOrigins: (0..<56).map { cellOrigin($0, cols: 7, x: 440, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 56, cols: 7, single: 7))
        }

        func subkeys() {
            b.chapter("Prerequisites: key generation: derive 16 subkeys")
            clearText()
            // keep K' (moved to the left), remove the rest
            let keep = Set((0..<56).flatMap { ["kp\($0)", "kpb\($0)"] } + ["lKp"])
            b.remove(workIDs.filter { !keep.contains($0) })
            workIDs = workIDs.filter { keep.contains($0) }
            for k in 0..<56 {
                let o = cellOrigin(k, cols: 7, x: 20, y: 56, cw: 22, ch: 22)
                b.move("kp\(k)", x: o.x, y: o.y); b.move("kpb\(k)", x: o.x, y: o.y)
            }
            b.move("lKp", x: 20, y: 34)
            say("- The next step is to derive 16 48-bit keys K[1]-K[16] from K'.")
            highlight("schPC2", "schTK")
            b.commit()
            // split into L and R (rows of 28 bits)
            let rx: CGFloat = 214, cw: CGFloat = 16, yL: CGFloat = 56, yR: CGFloat = 92
            label("lL", "L", x: 196, y: yL + 2, size: 14, bold: true)
            label("lR", "R", x: 196, y: yR + 2, size: 14, bold: true)
            for k in 0..<56 {
                b.remove("kpb\(k)")
                b.setSize("kp\(k)", w: cw, h: 22)
                b.move("kp\(k)", x: rx + CGFloat(k % 28) * cw, y: k < 28 ? yL : yR)
                b.box(w("lrb\(k)"), x: rx + CGFloat(k % 28) * cw, y: k < 28 ? yL : yR, w: cw, h: 22, fill: k < 28 ? .cell : .cellAlt)
            }
            b.remove("lKp")
            say("- Therefore, K' is split in two halves L and R.")
            b.commit()
            // rotation table
            let ty: CGFloat = 136
            label("lRn", "Round number", x: 214, y: ty + 3, size: 12)
            label("lRb", "# of bits to rotate", x: 214, y: ty + 25, size: 12)
            for i in 0..<16 {
                b.box(w("rtb\(i)"), x: 330 + CGFloat(i) * 24, y: ty, w: 24, h: 22, fill: .cellAlt)
                b.cellText(w("rtn\(i)"), "\(i + 1)", x: 330 + CGFloat(i) * 24, y: ty, w: 24, h: 22, size: 12)
                b.box(w("rtc\(i)"), x: 330 + CGFloat(i) * 24, y: ty + 22, w: 24, h: 22, fill: .white)
                b.cellText(w("rts\(i)"), "\(DESTrace.shifts[i])", x: 330 + CGFloat(i) * 24, y: ty + 22, w: 24, h: 22, size: 12)
            }
            say("- According to the table below, we let all bits in R and L rotate left in 16 rounds by the number specified:")
            b.commit()
            // rotation of round 1
            let sh = DESTrace.shifts[0]
            b.setColor(["rtn0", "rts0"], .red)
            var cd = (0..<56).map { "kp\($0)" }    // ids at positions 0…55 after the rotation
            for half in 0..<2 {
                for j in 0..<28 {
                    let id = "kp\(half * 28 + j)"
                    let np = (j - sh + 28) % 28
                    b.move(id, x: rx + CGFloat(np) * cw, y: half == 0 ? yL : yR)
                    if j < sh { b.setColor(id, .red); b.setZ(id, 7) }
                    cd[half * 28 + np] = id
                }
            }
            b.commit()
            for j in 0..<56 { b.setColor("kp\(j)", .text) }
            b.setColor(["rtn0", "rts0"], .text)
            // PC2
            label("lPC2", "PC2", x: 214, y: 200)
            matrix("pc2", DESTrace.pc2.map(String.init), cols: 6, x: 214, y: 222, fill: .cellAlt, size: 12)
            label("lK1", "K[1]", x: 380, y: 200)
            emptyMatrix("k1", count: 48, cols: 6, x: 380, y: 222)
            say("- Next step is to pull both L and R back together and pass it through a permutation called PC2.")
            highlight("schPC2")
            b.commit()
            permute(src: cd, table: DESTrace.pc2, tableIDs: (0..<48).map { "pc2\($0)" }, dst: "k1",
                    dstOrigins: (0..<48).map { cellOrigin($0, cols: 6, x: 380, y: 222, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 48, cols: 6, single: 0))
            say("  The result is our first subkey K[1], which is 8 bits shorter than K'.")
            b.setColor("lK1", .red)
            b.commit()
            b.setColor("lK1", .text)
            label("lKs", "Subkeys (hex)", x: 560, y: 200, size: 12, bold: true)
            for i in 0..<16 {
                label("ks\(i)", String(format: "K[%d]", i + 1).padding(toLength: 6, withPad: " ", startingAt: 0) + "= " + hx(t.subkeys[i]),
                      x: 560, y: 222 + CGFloat(i) * 18, size: 11.5)
                if let it = b.item("ks\(i)") { var m = it; m.mono = true; b.put(m) }
            }
            say("- All other subkeys K[2]-K[16] are derived in the same manner in respect to the 16 rounds given in the table..")
            highlight("schTK")
            b.commit()
        }

        func feistelRound(_ i: Int, yTop: CGFloat) {
            let p = "fr\(i)"
            b.line(w(p + "a"), [CGPoint(x: 440, y: yTop + 24), CGPoint(x: 440, y: yTop + 40)])
            b.box(w(p + "fb"), x: 420, y: yTop + 40, w: 40, h: 26, fill: .cellAlt)
            b.cellText(w(p + "f"), "f", x: 420, y: yTop + 40, w: 40, h: 26, size: 15, bold: true, mono: false)
            b.text(w(p + "k"), "K[\(i)]", x: 510, y: yTop + 44, size: 13)
            b.line(w(p + "ka"), [CGPoint(x: 506, y: yTop + 53), CGPoint(x: 462, y: yTop + 53)])
            b.line(w(p + "fx"), [CGPoint(x: 420, y: yTop + 53), CGPoint(x: 154, y: yTop + 53)])
            b.cellText(w(p + "x"), "⊕", x: 126, y: yTop + 38, w: 28, h: 30, size: 22, mono: false)
            b.line(w(p + "lx"), [CGPoint(x: 140, y: yTop + 24), CGPoint(x: 140, y: yTop + 40)])
            b.line(w(p + "c1"), [CGPoint(x: 140, y: yTop + 68), CGPoint(x: 420, y: yTop + 98)])
            b.line(w(p + "c2"), [CGPoint(x: 500, y: yTop + 24), CGPoint(x: 500, y: yTop + 74), CGPoint(x: 160, y: yTop + 98)])
            b.text(w(p + "lab"), "round \(i)", x: 580, y: yTop + 42, size: 15, bold: true)
            hexBox("fL\(i)", hx(t.l[i]), x: 60, y: yTop + 100, w: 160)
            hexBox("fR\(i)", hx(t.r[i]), x: 360, y: yTop + 100, w: 160)
            b.text(w("fLl\(i)"), "L[\(i)]", x: 22, y: yTop + 104, size: 12)
            b.text(w("fRl\(i)"), "R[\(i)]", x: 322, y: yTop + 104, size: 12)
        }

        func feistel() {
            b.chapter("DES Core: Feistel scheme")
            clearText()
            clearWork()
            say("- The prerequisites for the main algorithm are finished, and we proceed to the DES core function.")
            highlight("schTK", "schR")
            b.commit()
            say("- The following process is called Feistel scheme. It is repeated 16 times, making up the 16 rounds of DES.",
                "  In every round, one subkey is used to perform an encryption on a specified block.")
            b.commit()
            say("- We switch the current viewpoint for better illustration.")
            hexBox("fPI", hx(t.permutedInput), x: 140, y: 6, w: 300, fill: .cellAlt)
            label("fPIl", "Permuted input (64-bit)", x: 450, y: 10, size: 11, color: .secondary)
            b.commit()
            say("- The permuted input is split in two halves called L[0] and R[0], each 32-bit wide.")
            b.line(w("fs1"), [CGPoint(x: 220, y: 30), CGPoint(x: 140, y: 58)])
            b.line(w("fs2"), [CGPoint(x: 360, y: 30), CGPoint(x: 440, y: 58)])
            hexBox("fL0", hx(t.l[0]), x: 60, y: 60, w: 160)
            hexBox("fR0", hx(t.r[0]), x: 360, y: 60, w: 160)
            b.text(w("fLl0"), "L[0]", x: 22, y: 64, size: 12)
            b.text(w("fRl0"), "R[0]", x: 322, y: 64, size: 12)
            label("f2x32", "2x32-bit", x: 580, y: 64, size: 11, color: .secondary)
            b.commit()
            say("- For i=1,...,16 (16 DES rounds) let",
                "      L[i] = R[i-1]   and   R[i] = L[i-1] ⊕ f(R[i-1], K[i])")
            b.commit()
            say("- K[i] is the subkey index and ⊕ means bitwise addition modulo 2 (also called XOR).")
            b.remove("f2x32")
            b.commit()
            feistelRound(1, yTop: 60)
            b.commit()
            feistelRound(2, yTop: 160)
            b.commit()
            label("fdots", "⋮", x: 132, y: 286, size: 26)
            label("fdots2", "⋮", x: 432, y: 286, size: 26)
            label("f315", "round 3-15", x: 580, y: 300, size: 15, bold: true)
            hexBox("fL15", hx(t.l[15]), x: 60, y: 344, w: 160)
            hexBox("fR15", hx(t.r[15]), x: 360, y: 344, w: 160)
            b.text(w("fLl15"), "L[15]", x: 16, y: 348, size: 12)
            b.text(w("fRl15"), "R[15]", x: 316, y: 348, size: 12)
            say("- In this schematic round 3 to 15 are abbreviated, but they run just the same.")
            b.commit()
            feistelRound(16, yTop: 344)
            b.commit()
            say("- Finally we swap L and R after round 16.")
            b.line(w("fsw1"), [CGPoint(x: 140, y: 468), CGPoint(x: 380, y: 496)])
            b.line(w("fsw2"), [CGPoint(x: 440, y: 468), CGPoint(x: 200, y: 496)])
            hexBox("fPO", hx(t.preOutput), x: 140, y: 498, w: 300, fill: .cellAlt)
            label("fPOl", "Pre-output = R[16] L[16]", x: 450, y: 502, size: 11, color: .secondary)
            b.commit()
            say("  The result is the pre-output.")
            highlight("schPO")
            b.commit()
        }

        func gx(_ j: Int, _ bit: Int) -> CGFloat { 86 + CGFloat(j) * 80 + CGFloat(bit) * 12 }

        func functionF() {
            b.chapter("DES core: function f")
            clearText()
            clearWork()
            label("ftitle", "Function f", x: 20, y: 6, size: 18, bold: true)
            say("- Let's take a closer look at the DES core function f(R[i-1], L[i]).")
            highlight("schR")
            b.commit()

            b.chapter("DES core: function f: key expansion")
            let r0 = t.r[0]
            label("lR0", "R[0]", x: 20, y: 56, size: 13)
            for j in 0..<32 {
                let x = 86 + CGFloat(j) * 18
                b.cellText(w("r0i\(j)"), "\(j + 1)", x: x, y: 38, w: 18, h: 14, size: 8, color: .secondary, mono: false)
                b.box(w("r0b\(j)"), x: x, y: 54, w: 18, h: 20)
                b.cellText(w("r0\(j)"), "\(r0[j])", x: x, y: 54, w: 18, h: 20, size: 13)
            }
            label("l32", "32-Bit", x: 676, y: 56, size: 11, color: .secondary)
            say("- Each 32-bit wide R[i-1] must be expanded before it can be XORed with its corresponding 48-bit subkey K[i].")
            b.commit()
            label("lE", "E(R[0])", x: 20, y: 120, size: 13)
            for k in 0..<48 { b.spawnCopy(of: "r0\(DESTrace.expansion[k] - 1)", as: w("e\(k)"), z: 6) }
            for k in 0..<48 {
                let x = gx(k / 6, k % 6)
                b.box(w("eb\(k)"), x: x, y: 118, w: 12, h: 20)
                b.setSize("e\(k)", w: 12, h: 20)
                b.move("e\(k)", x: x, y: 118)
                b.cellText(w("ei\(k)"), "\(DESTrace.expansion[k])", x: x - 2, y: 139, w: 16, h: 10, size: 7, color: .secondary, mono: false)
            }
            label("l48", "48-Bit", x: 676, y: 98, size: 11, color: .secondary)
            say("  That's why some of the values in R[i-1] have to be doubled. The figure above shows how. The exact mapping is determined",
                "  by the expansion table E, which is not shown here.")
            b.commit()

            b.chapter("DES Core: function f: XOR operation")
            say("  Next step is to XOR E(R[i-1]) and K[i].")
            b.commit()
            label("lXK", "XOR K[1]", x: 20, y: 160, size: 13)
            for k in 0..<48 {
                b.box(w("kb1_\(k)"), x: gx(k / 6, k % 6), y: 158, w: 12, h: 20, fill: .cellAlt)
                b.cellText(w("k1_\(k)"), "\(t.subkeys[0][k])", x: gx(k / 6, k % 6), y: 158, w: 12, h: 20, size: 13)
            }
            b.line(w("xline"), [CGPoint(x: 80, y: 184), CGPoint(x: 726, y: 184)], arrow: false)
            label("lB", "= B", x: 20, y: 194, size: 13)
            say("  This is an example for i=1, having the expanded input R[0] and its corresponding subkey K[1] XORed.")
            b.commit()
            for j in 0..<8 {
                for bit in 0..<6 {
                    let k = j * 6 + bit
                    b.box(w("bb\(k)"), x: gx(j, bit), y: 192, w: 12, h: 20, fill: .white)
                    b.cellText(w("b\(k)"), "\(t.xored[0][k])", x: gx(j, bit), y: 192, w: 12, h: 20, size: 13, color: .red)
                    b.setColor(["e\(k)", "k1_\(k)"], .red)
                }
                b.commit()
                for bit in 0..<6 { let k = j * 6 + bit; b.setColor(["b\(k)", "e\(k)", "k1_\(k)"], .text) }
            }
            for j in 0..<8 {
                b.cellText(w("bl\(j)"), "B[\(j + 1)]", x: gx(j, 0), y: 216, w: 72, h: 16, size: 12, color: .red, mono: false)
            }
            say("- The result B is divided into 8 blocks.")
            b.commit()
            say("- The index of B tells us which S-box is applied to the each block.")
            b.commit()

            sboxes()
            permutationP()
        }

        func sboxTable(_ n: Int, y: CGFloat) {
            let p = "sb\(n)_"
            label(p + "t", "S-box \(n + 1):", x: 20, y: y, size: 13, bold: true)
            b.text(w(p + "sp"), "column", x: 96, y: y + 1, size: 10, color: .secondary)
            b.text(w(p + "re"), "row", x: 20, y: y + 22, size: 10, color: .secondary)
            for c in 0..<16 {
                b.cellText(w(p + "c\(c)"), "\(c)", x: 140 + CGFloat(c) * 30, y: y, w: 30, h: 18, size: 11, color: .secondary, mono: false)
            }
            for r in 0..<4 {
                b.cellText(w(p + "r\(r)"), "\(r)", x: 100, y: y + 18 + CGFloat(r) * 18, w: 30, h: 18, size: 11, color: .secondary, mono: false)
                for c in 0..<16 {
                    let x = 140 + CGFloat(c) * 30, yy = y + 18 + CGFloat(r) * 18
                    b.box(w(p + "b\(r)_\(c)"), x: x, y: yy, w: 30, h: 18, fill: .cell)
                    b.cellText(w(p + "v\(r)_\(c)"), "\(DESTrace.sboxes[n][r][c])", x: x, y: yy, w: 30, h: 18, size: 12)
                }
            }
        }

        func sboxExample(_ j: Int, tableY: CGFloat, last: Bool) {
            let six = Array(t.xored[0][(6 * j)..<(6 * j + 6)])
            let (row, col, v) = DESTrace.sbox(j, six)
            let n = j + 1
            for bit in 0..<6 { b.setColor("b\(6 * j + bit)", bit == 0 || bit == 5 ? .orange : .blue) }
            b.setColor("bl\(j)", .red)
            say("  Calculating binary to decimal value.")
            label("cr", "Row:    \(six[0])·2^1 + \(six[5])·2^0 = \(row)", x: 20, y: 396, size: 13, color: .orange)
            b.commit()
            label("cc", "Column: \(six[1])·2^3 + \(six[2])·2^2 + \(six[3])·2^1 + \(six[4])·2^0 = \(col)", x: 20, y: 418, size: 13, color: .blue)
            b.commit()
            let p = "sb\(j == 0 ? 0 : 7)_"
            for c in 0..<16 { b.setFill(p + "b\(row)_\(c)", .highlight) }
            for r in 0..<4 { b.setFill(p + "b\(r)_\(col)", .highlight) }
            b.setColor(p + "v\(row)_\(col)", .red)
            label("cv", "S\(n)(\(row), \(col)) = \(v)", x: 20, y: 444, size: 14, color: .red, bold: true)
            b.commit()
            say("  Calculating decimal to binary value.")
            var q = v, k = 0
            if q == 0 {
                label("cd0", "0 = 0000", x: 360, y: 396, size: 13)
                b.commit()
            }
            while q > 0 {
                label("cd\(k)", "\(k == 0 ? "\(v) := " : "")\(q) : 2 = \(q / 2) rest \(q % 2)", x: k == 0 ? 330 : 360, y: 396 + CGFloat(k) * 20, size: 13)
                b.commit()
                q /= 2; k += 1
            }
            let four = [(v >> 3) & 1, (v >> 2) & 1, (v >> 1) & 1, v & 1]
            label("cbin", "→ \(four.map(String.init).joined())  (read from bottom to top, padded to 4 bits)", x: 360, y: 396 + CGFloat(max(k, 1)) * 20 + 4, size: 12, color: .secondary)
            say("  Substitution of B[\(n)] by the acquired S-box value.")
            b.commit()
            replaceGroup(j)
            for c in 0..<16 { b.setFill(p + "b\(row)_\(c)", .cell) }
            for r in 0..<4 { b.setFill(p + "b\(r)_\(col)", .cell) }
            b.setColor(p + "v\(row)_\(col)", .text)
            b.commit()
            b.remove(["cr", "cc", "cv", "cbin"] + (0..<5).map { "cd\($0)" })
            b.setColor("bl\(j)", .text)
        }

        func replaceGroup(_ j: Int) {
            for bit in 0..<6 { b.remove("b\(6 * j + bit)", "bb\(6 * j + bit)") }
            for bit in 0..<4 {
                let x = gx(j, bit + 1)
                b.box(w("sob\(4 * j + bit)"), x: x, y: 60, w: 12, h: 20, fill: .cellAlt)
                b.cellText(w("so\(4 * j + bit)"), "\(t.sboxOut[0][4 * j + bit])", x: x, y: 60, w: 12, h: 20, size: 13, color: .red)
            }
        }

        func sboxes() {
            b.chapter("DES core: function f: S-boxes")
            clearText()
            // keep only B (moved to the top)
            let keep = Set((0..<48).flatMap { ["b\($0)", "bb\($0)"] } + (0..<8).map { "bl\($0)" } + ["ftitle"])
            b.remove(workIDs.filter { !keep.contains($0) })
            workIDs = workIDs.filter { keep.contains($0) }
            for k in 0..<48 { b.move("b\(k)", x: gx(k / 6, k % 6), y: 60); b.move("bb\(k)", x: gx(k / 6, k % 6), y: 60) }
            for j in 0..<8 { b.move("bl\(j)", x: gx(j, 0), y: 40) }
            label("lBtop", "B", x: 20, y: 62, size: 13)
            sboxTable(0, y: 110)
            say("- S-boxes (Substitution-Boxes) are a set of 8 4x16 matrices with constant values.")
            b.commit()
            sboxTable(7, y: 220)
            say("- There's not enough space for all boxes on the screen, so let's restrict to box 1 and 8.")
            b.commit()
            say("- Now, eight numbers are extracted from the S-boxes; one from each box:")
            b.commit()
            say("- For every S[n] the first and last bits of B[n] are used as the row index, and the middle four bits as the column index.",
                "  Here is an example for S[1], B[1] and S[8], B[8]. All remaining B[n] are substituted in the same way.")
            b.commit()
            clearText()
            sboxExample(0, tableY: 110, last: false)
            for k in 0..<4 { b.setColor("so\(k)", .text) }
            clearText()
            sboxExample(7, tableY: 220, last: true)
            for k in 28..<32 { b.setColor("so\(k)", .text) }
            say("- B[2] to B[7] are substituted the same way.")
            for j in 1..<7 { replaceGroup(j) }
            b.commit()
            for k in 0..<32 { b.setColor("so\(k)", .text) }
            // collect into a 8×4 matrix
            let keep2 = Set((0..<32).map { "so\($0)" } + ["ftitle"])
            b.remove(workIDs.filter { !keep2.contains($0) })
            workIDs = workIDs.filter { keep2.contains($0) }
            label("lRm", "R (32-bit)", x: 20, y: 120)
            for k in 0..<32 {
                let o = cellOrigin(k, cols: 4, x: 20, y: 142, cw: 22, ch: 22)
                b.box(w("smb\(k)"), x: o.x, y: o.y, w: 22, h: 22)
                b.setSize("so\(k)", w: 22, h: 22)
                b.move("so\(k)", x: o.x, y: o.y)
            }
            say("- The result R is the concatenation of B[1] to B[8], shown in the matrix above.")
            b.commit()
        }

        func permutationP() {
            b.chapter("DES core: function f: permutation P")
            clearText()
            label("lP", "Permutation P", x: 160, y: 120)
            matrix("pP", DESTrace.p.map(String.init), cols: 4, x: 160, y: 142, fill: .cellAlt, size: 12)
            label("lF", "f(R[0], K[1])", x: 300, y: 120)
            emptyMatrix("fm", count: 32, cols: 4, x: 300, y: 142)
            say("- Finally, R is passed through the permutation P. Just like the other S-boxes, this matrix is constant.")
            b.commit()
            permute(src: (0..<32).map { "so\($0)" }, table: DESTrace.p, tableIDs: (0..<32).map { "pP\($0)" }, dst: "fm",
                    dstOrigins: (0..<32).map { cellOrigin($0, cols: 4, x: 300, y: 142, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 32, cols: 4, single: 0))
            say("- We get the result of f(R[0], K[1]).")
            label("fres", "f(R[0] , K[1]) = " + hx(t.f[0]), x: 440, y: 150, size: 16, bold: true)
            b.commit()
            say("- Remember: This value comes from round 1 of 16.")
            highlight("schR")
            b.commit()
            say("- Let's not forget to XOR the result with L[0] !")
            label("x1", "  L[0]          = " + hx(t.l[0]), x: 440, y: 190, size: 13)
            label("x2", "⊕ f(R[0], K[1]) = " + hx(t.f[0]), x: 440, y: 210, size: 13)
            label("x3", "= R[1]          = " + hx(t.r[1]), x: 440, y: 236, size: 13, color: .red, bold: true)
            for id in ["x1", "x2", "x3"] { if var it = b.item(id) { it.mono = true; b.put(it) } }
            b.commit()
            // rounds 2…16
            clearWork()
            label("rtitle", "round 2-16", x: 20, y: 6, size: 18, bold: true)
            var rows = ["Round  K[i]                L[i]         R[i]"]
            for i in 1...16 {
                rows.append(String(format: "%5d  ", i) + hx(t.subkeys[i - 1]) + "   " + hx(t.l[i]) + "  " + hx(t.r[i]))
            }
            for (i, r) in rows.enumerated() {
                label("rt\(i)", r, x: 20, y: 40 + CGFloat(i) * 19, size: 12.5, bold: i == 0)
                if var it = b.item("rt\(i)") { it.mono = true; b.put(it) }
            }
            label("rtPO", "Pre-output = R[16] L[16] = " + hx(t.preOutput), x: 20, y: 40 + 18 * 19, size: 13, color: .red, bold: true)
            say("- These steps you should be familiar with by now.")
            b.commit()
        }

        func finalPermutation() {
            b.chapter("Finalization: inverse initial permutation")
            clearText()
            clearWork()
            label("lPO", "Pre-output", x: 20, y: 34)
            matrix("po", bits(t.preOutput), cols: 8, x: 20, y: 56)
            say("- Pre-ouput is passed through the inverse initial permutation IP⁻¹, the final step in DES.")
            highlight("schPO", "schIPI")
            b.commit()
            label("lIPI", "IP⁻¹", x: 240, y: 34)
            matrix("ipi", DESTrace.ipInverse.map(String.init), cols: 8, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lY", "Output block Y", x: 460, y: 34)
            emptyMatrix("y", count: 64, cols: 8, x: 460, y: 56)
            say("- The procedure is the same as before.")
            b.commit()
            permute(src: (0..<64).map { "po\($0)" }, table: DESTrace.ipInverse, tableIDs: (0..<64).map { "ipi\($0)" }, dst: "y",
                    dstOrigins: (0..<64).map { cellOrigin($0, cols: 8, x: 460, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 64, cols: 8, single: 0))
            say("- Result is the Output block Y.")
            label("yhex", "Y = " + hx(t.output), x: 460, y: 246, size: 15, color: .red, bold: true)
            let check = (try? SymmetricCipher.encryptRaw(.desECB, key: ct1Bytes(t.k), data: ct1Bytes(t.x))) ?? []
            if check == ct1Bytes(t.output) {
                label("ycheck", "Check: CrypTool's DES (ECB) yields the same block.", x: 460, y: 272, size: 11, color: .green)
            }
            highlight("schY")
            b.commit()
        }
    }
}

struct DESAnimationView: View {
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 1.4)
    @CTState private var script = AnimScript.empty
    @CTState private var blockHex = DESTrace.ct1Plaintext.ct1Hex
    @CTState private var keyHex = DESTrace.ct1Key.ct1Hex
    @CTState private var error: String?

    var body: some View {
        ScriptedAnimationView(script: script, player: player) {
            AnimationInputBar(note: error ?? "Input block X and key K: 8 bytes hexadecimal each.",
                              rebuild: rebuild,
                              resetToExample: { blockHex = DESTrace.ct1Plaintext.ct1Hex; keyHex = DESTrace.ct1Key.ct1Hex; rebuild() }) {
                Text("X").foregroundStyle(.secondary)
                TextField("Input block X (hex)", text: $blockHex).font(.system(.body, design: .monospaced)).frame(width: 230)
                Text("K").foregroundStyle(.secondary)
                TextField("Key K (hex)", text: $keyHex).font(.system(.body, design: .monospaced)).frame(width: 230)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        guard let x = Hex.decode(blockHex), x.count == 8, let k = Hex.decode(keyHex), k.count == 8 else {
            error = "Please enter exactly 8 bytes hexadecimal each (e.g. 16 BD 40 94 B4 53 8A 7B)."
            return
        }
        error = nil
        script = DESAnimationScript.build(plaintext: x, key: k)
        player.reset(count: script.frames.count)
    }
}
