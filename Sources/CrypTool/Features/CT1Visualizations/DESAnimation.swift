import AppKit
import SwiftUI
import CTCommon
import CTModern

// Native version of CT1's ANIMAL animation "Visualisierung von Algorithmen ▸ DES"
// (des_de.aml, "DES Data-Encryption-Standard (ECB-Modus)"). Same chapters, texts and example
// (X = 16 BD 40 94 B4 53 8A 7B, K = E1 A4 BB 9B C2 E3 24 BB); all values are computed by
// `DESTrace`, so an own block/key can be animated too.

extension CT1Visualizations {
    static func openDESAnimation() {
        WindowPresenter.tool(id: "ct1-anim-des", title: "DES Data-Encryption-Standard (ECB-Modus) – Animation", size: CGSize(width: 1180, height: 860)) {
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
        /// indices per step (CT1: "Das bedeutet: Bit 58 … rückt an die erste Stelle …").
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

        // Schema on the right (CT1: "Schema")
        let schemaIDs = ["schX", "schK", "schIP", "schPC1", "schPI", "schPC2", "schR", "schTK", "schPO", "schIPI", "schY"]

        func schemaBox(_ id: String, _ s: String, x: CGFloat, y: CGFloat, w: CGFloat) {
            b.box(id + "b", x: x, y: y, w: w, h: 22, fill: .cellAlt)
            b.cellText(id, s, x: x, y: y, w: w, h: 22, size: 12, mono: false)
        }

        func drawSchema() {
            b.text("schT", "Schema", x: 868, y: 8, size: 14, bold: true)
            schemaBox("schX", "Eingabeblock X", x: 772, y: 36, w: 120)
            schemaBox("schK", "Schlüssel K", x: 912, y: 36, w: 110)
            b.cellText("schIP", "IP", x: 812, y: 76, w: 40, h: 20, size: 12, mono: false)
            b.cellText("schPC1", "PC1", x: 947, y: 76, w: 40, h: 20, size: 12, mono: false)
            schemaBox("schPI", "Permutierte Eingabe", x: 762, y: 112, w: 140)
            schemaBox("schPC2", "PC2(K)", x: 917, y: 112, w: 100)
            schemaBox("schR", "16 DES-Runden", x: 772, y: 162, w: 120)
            schemaBox("schTK", "16 Teilschlüssel", x: 912, y: 162, w: 110)
            schemaBox("schPO", "Pre-Ausgabe", x: 772, y: 212, w: 120)
            b.cellText("schIPI", "IP⁻¹", x: 812, y: 252, w: 40, h: 20, size: 12, mono: false)
            schemaBox("schY", "Ausgabeblock Y", x: 772, y: 288, w: 120)
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
            b.chapter("Voraussetzungen")
            label("bigDES", "DES", x: 150, y: 40, size: 72, bold: true)
            label("bigDES2", "Data Encryption Standard", x: 110, y: 150, size: 24)
            label("bigDES3", "(ECB-Modus)", x: 185, y: 186, size: 16)
            drawSchema()
            b.commit()
            say("- Im DES wird ein Klartext in gleichgrosse Blöcke mit jeweils 64 Bit unterteilt.")
            highlight("schX", "schK")
            b.commit()
            clearWork()
            label("lX", "Eingabeblock X  [64bit]", x: 20, y: 34)
            matrix("x", bits(t.x), cols: 8, x: 20, y: 56)
            label("lXh", "X = " + hx(t.x), x: 20, y: 240, size: 11, color: .secondary)
            label("lK", "Schlüssel K  [64bit]", x: 240, y: 34)
            matrix("k", bits(t.k), cols: 8, x: 240, y: 56)
            label("lKh", "K = " + hx(t.k), x: 240, y: 240, size: 11, color: .secondary)
            say("Jeder Block (hier: Eingabeblock X) durchläuft folgendes Schema zur kompletten Verschlüsselung.")
            highlight("schX", "schIP", "schPI", "schR", "schPO", "schIPI", "schY")
            b.commit()
            say("- Dazu werden die Bits des Klartextblocks erst gemäß der festen initialen Permutationsmatrix umgeordnet.")
            highlight("schX", "schIP")
            b.commit()
        }

        func initialPermutation() {
            b.chapter("Voraussetzungen: Initiale Permutation (IP)")
            clearText()
            for k in 0..<64 { b.remove("kb\(k)", "k\(k)") }
            b.remove("lK", "lKh")
            b.commit()
            label("lIP", "Initiale Permutationsmatrix", x: 240, y: 34)
            matrix("ip", DESTrace.ip.map(String.init), cols: 8, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lPI", "Permutierte Eingabe", x: 460, y: 34)
            emptyMatrix("pi", count: 64, cols: 8, x: 460, y: 56)
            highlight("schIP", "schPI")
            b.commit()
            say("- Dabei geben die Einträge in IP die Nummer desjenigen Bits im Eingabeblock an, das an diese Stelle verschoben wird.",
                "  Das bedeutet: Bit \(DESTrace.ip[0]) des Klartextblocks rückt an die erste Stelle, Bit \(DESTrace.ip[1]) an die zweite Stelle, usw...")
            b.commit()
            permute(src: (0..<64).map { "x\($0)" }, table: DESTrace.ip, tableIDs: (0..<64).map { "ip\($0)" }, dst: "pi",
                    dstOrigins: (0..<64).map { cellOrigin($0, cols: 8, x: 460, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 64, cols: 8, single: 8))
            label("lPIh", "= " + hx(t.permutedInput), x: 460, y: 240, size: 11, color: .secondary)
            say("  Wir erhalten die permutierte Eingabe.")
            highlight("schPI")
            b.commit()
        }

        func pc1() {
            b.chapter("Voraussetzungen: Schlüsselerzeugung: PC1")
            clearText()
            clearWork()
            label("lK", "Schlüssel K", x: 20, y: 34)
            matrix("k", bits(t.k), cols: 8, x: 20, y: 56)
            say("- Als nächstes muss der 64 Bit lange Schlüssel K ebenfalls einer Permutation (PC1) unterzogen werden.")
            highlight("schK", "schPC1")
            b.commit()
            say("- Vorher wird die 8. Spalte, also jedes 8. Bit aus K entfernt . Diese Bits sind als Paritätsbits gedacht und haben",
                "  auf das weitere Verfahren keinen wesentlichen Einfluss mehr.")
            for r in 0..<8 { b.setColor("k\(r * 8 + 7)", .red); b.setFill("kb\(r * 8 + 7)", .highlight) }
            b.commit()
            for r in 0..<8 { b.remove("k\(r * 8 + 7)", "kb\(r * 8 + 7)") }
            say("  Beachte: Dadurch verkürzt sich der Schlüssel auf effektiv 56 Bit!")
            b.commit()
            label("lPC1", "Permuted Choice (PC1)", x: 240, y: 34)
            matrix("pc1", DESTrace.pc1.map(String.init), cols: 7, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lKp", "56-Bit Schlüssel K'", x: 440, y: 34)
            emptyMatrix("kp", count: 56, cols: 7, x: 440, y: 56)
            say("- Dabei geben die Einträge in PC1 an, welches Bit aus Schlüssel K an diese Stelle verschoben wird.")
            b.commit()
            say("- Das bedeutet: Bit \(DESTrace.pc1[0]) des Schlüssels K rückt an die erste Stelle, Bit \(DESTrace.pc1[1]) an Stelle 2, usw...")
            b.commit()
            permute(src: (0..<64).map { "k\($0)" }, table: DESTrace.pc1, tableIDs: (0..<56).map { "pc1\($0)" }, dst: "kp",
                    dstOrigins: (0..<56).map { cellOrigin($0, cols: 7, x: 440, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 56, cols: 7, single: 7))
        }

        func subkeys() {
            b.chapter("Voraussetzungen: Schlüsselerzeugung: Ableitung von 16 Unterschlüsseln")
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
            say("- Nun werden aus dem 56-Bit Schlüssel K' 16 48-Bit Teilschlüssel K[1] bis K[16] abgeleitet.")
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
            say("- Dazu wird dieser zunächst in zwei 28 Bit-Blöcke L und R unterteilt.")
            b.commit()
            // rotation table
            let ty: CGFloat = 136
            label("lRn", "Runde Nr.", x: 214, y: ty + 3, size: 12)
            label("lRb", "Bits rotieren um", x: 214, y: ty + 25, size: 12)
            for i in 0..<16 {
                b.box(w("rtb\(i)"), x: 330 + CGFloat(i) * 24, y: ty, w: 24, h: 22, fill: .cellAlt)
                b.cellText(w("rtn\(i)"), "\(i + 1)", x: 330 + CGFloat(i) * 24, y: ty, w: 24, h: 22, size: 12)
                b.box(w("rtc\(i)"), x: 330 + CGFloat(i) * 24, y: ty + 22, w: 24, h: 22, fill: .white)
                b.cellText(w("rts\(i)"), "\(DESTrace.shifts[i])", x: 330 + CGFloat(i) * 24, y: ty + 22, w: 24, h: 22, size: 12)
            }
            say("- L und R werden in 16 Runden gemäß folgender Tabelle linksrotiert:")
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
            say("- L und R werden wieder zusammen gefügt und gemäß PC2 in bekannter Weise permutiert.")
            highlight("schPC2")
            b.commit()
            permute(src: cd, table: DESTrace.pc2, tableIDs: (0..<48).map { "pc2\($0)" }, dst: "k1",
                    dstOrigins: (0..<48).map { cellOrigin($0, cols: 6, x: 380, y: 222, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 48, cols: 6, single: 0))
            say("  Wir erhalten den 8 Bit kürzeren Schlüssel K[1].")
            b.setColor("lK1", .red)
            b.commit()
            b.setColor("lK1", .text)
            label("lKs", "Teilschlüssel (hex)", x: 560, y: 200, size: 12, bold: true)
            for i in 0..<16 {
                label("ks\(i)", String(format: "K[%d]", i + 1).padding(toLength: 6, withPad: " ", startingAt: 0) + "= " + hx(t.subkeys[i]),
                      x: 560, y: 222 + CGFloat(i) * 18, size: 11.5)
                if let it = b.item("ks\(i)") { var m = it; m.mono = true; b.put(m) }
            }
            say("- Die restlichen Schlüssel K[2]-K[16] werden gemäß der Rotationstabelle und der anschliessenden Permutation",
                "  gleichsam abgeleitet.")
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
            b.text(w(p + "lab"), "Runde \(i)", x: 580, y: yTop + 42, size: 15, bold: true)
            hexBox("fL\(i)", hx(t.l[i]), x: 60, y: yTop + 100, w: 160)
            hexBox("fR\(i)", hx(t.r[i]), x: 360, y: yTop + 100, w: 160)
            b.text(w("fLl\(i)"), "L[\(i)]", x: 22, y: yTop + 104, size: 12)
            b.text(w("fRl\(i)"), "R[\(i)]", x: 322, y: yTop + 104, size: 12)
        }

        func feistel() {
            b.chapter("DES-Kern: Feistel-Schema")
            clearText()
            clearWork()
            say("- Nach diesen Vorbereitungen kann der Kern des Algorithmus ausgeführt werden.")
            highlight("schTK", "schR")
            b.commit()
            say("- Den Kern der Verschlüsselung bildet die sogenannte Feistel-Chiffre, welche die permutierte Eingabe",
                "  in mehreren Runden (hier insgesamt 16) mit ebenso vielen Teilschlüsseln verarbeitet.")
            b.commit()
            say("- Aus Gründen der besseren Übersicht verlassen wir die binäre Darstellungsweise.")
            hexBox("fPI", hx(t.permutedInput), x: 140, y: 6, w: 300, fill: .cellAlt)
            label("fPIl", "Permutierte Eingabe (64-bit)", x: 450, y: 10, size: 11, color: .secondary)
            b.commit()
            say("- Der permutierte Eingabeblock wird in die Hälften L[0] und R[0] mit jeweils 32 Bit zerlegt.")
            b.line(w("fs1"), [CGPoint(x: 220, y: 30), CGPoint(x: 140, y: 58)])
            b.line(w("fs2"), [CGPoint(x: 360, y: 30), CGPoint(x: 440, y: 58)])
            hexBox("fL0", hx(t.l[0]), x: 60, y: 60, w: 160)
            hexBox("fR0", hx(t.r[0]), x: 360, y: 60, w: 160)
            b.text(w("fLl0"), "L[0]", x: 22, y: 64, size: 12)
            b.text(w("fRl0"), "R[0]", x: 322, y: 64, size: 12)
            label("f2x32", "2x32-bit", x: 580, y: 64, size: 11, color: .secondary)
            b.commit()
            say("- Es gilt für die 16 DES-Runden i=1,...,16:",
                "      L[i] = R[i-1]   und   R[i] = L[i-1] ⊕ f(R[i-1], K[i])")
            b.commit()
            say("- K[i] ist dabei der i-te Teilschlüssel und ⊕ steht für die bitweise Addition modulo 2 (XOR).")
            b.remove("f2x32")
            b.commit()
            feistelRound(1, yTop: 60)
            b.commit()
            feistelRound(2, yTop: 160)
            b.commit()
            label("fdots", "⋮", x: 132, y: 286, size: 26)
            label("fdots2", "⋮", x: 432, y: 286, size: 26)
            label("f315", "Runde 3-15", x: 580, y: 300, size: 15, bold: true)
            hexBox("fL15", hx(t.l[15]), x: 60, y: 344, w: 160)
            hexBox("fR15", hx(t.r[15]), x: 360, y: 344, w: 160)
            b.text(w("fLl15"), "L[15]", x: 16, y: 348, size: 12)
            b.text(w("fRl15"), "R[15]", x: 316, y: 348, size: 12)
            say("- Die Runden 3-15 sind hier verkürzt dargestellt.")
            b.commit()
            feistelRound(16, yTop: 344)
            b.commit()
            say("- Nach Runde 16 werden linker und rechter Block noch einmal vertauscht.")
            b.line(w("fsw1"), [CGPoint(x: 140, y: 468), CGPoint(x: 380, y: 496)])
            b.line(w("fsw2"), [CGPoint(x: 440, y: 468), CGPoint(x: 200, y: 496)])
            hexBox("fPO", hx(t.preOutput), x: 140, y: 498, w: 300, fill: .cellAlt)
            label("fPOl", "Pre-Ausgabe = R[16] L[16]", x: 450, y: 502, size: 11, color: .secondary)
            b.commit()
            say("  Wir erhalten die Pre-Ausgabe.")
            highlight("schPO")
            b.commit()
        }

        func gx(_ j: Int, _ bit: Int) -> CGFloat { 86 + CGFloat(j) * 80 + CGFloat(bit) * 12 }

        func functionF() {
            b.chapter("DES-Kern: Funktion f")
            clearText()
            clearWork()
            label("ftitle", "Die Funktion f", x: 20, y: 6, size: 18, bold: true)
            say("- Die Funktion f(R[i-1], K[i]), welche die Kernoperation im DES darstellt, wird im folgenden näher erläutert.")
            highlight("schR")
            b.commit()

            b.chapter("DES-Kern: Funktion f: Schlüsselexpandierung")
            let r0 = t.r[0]
            label("lR0", "R[0]", x: 20, y: 56, size: 13)
            for j in 0..<32 {
                let x = 86 + CGFloat(j) * 18
                b.cellText(w("r0i\(j)"), "\(j + 1)", x: x, y: 38, w: 18, h: 14, size: 8, color: .secondary, mono: false)
                b.box(w("r0b\(j)"), x: x, y: 54, w: 18, h: 20)
                b.cellText(w("r0\(j)"), "\(r0[j])", x: x, y: 54, w: 18, h: 20, size: 13)
            }
            label("l32", "32-Bit", x: 676, y: 56, size: 11, color: .secondary)
            say("- Bevor die 32-Bit lange rechte Teilhälfte R[i-1] mit dem 48-Bit Teilschlüssel K[i] XOR-verknüpft wird,",
                "  muss R[i-1] expandiert werden.")
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
            say("  Dazu werden einfach einige Bits nach einem festen Muster (Expansionstabelle E hier nicht aufgeführt) verdoppelt.")
            b.commit()

            b.chapter("DES-Kern: Funktion f: XOR-Operation")
            say("- Danach werden E(R[i-1]) und K[i] XOR-verknüpft.")
            b.commit()
            label("lXK", "XOR K[1]", x: 20, y: 160, size: 13)
            for k in 0..<48 {
                b.box(w("kb1_\(k)"), x: gx(k / 6, k % 6), y: 158, w: 12, h: 20, fill: .cellAlt)
                b.cellText(w("k1_\(k)"), "\(t.subkeys[0][k])", x: gx(k / 6, k % 6), y: 158, w: 12, h: 20, size: 13)
            }
            b.line(w("xline"), [CGPoint(x: 80, y: 184), CGPoint(x: 726, y: 184)], arrow: false)
            label("lB", "= B", x: 20, y: 194, size: 13)
            say("  Hier das Beispiel i=1 mit dem expandierten Eingabeblock R[0] und Teilschlüssel K[1].")
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
            say("- Das Ergebnis B wird nun in 8 Felder unterteilt.")
            b.commit()
            say("- Der Index von B gibt an, welche S-Box auf den jeweiligen Block angewendet wird.")
            b.commit()

            sboxes()
            permutationP()
        }

        func sboxTable(_ n: Int, y: CGFloat) {
            let p = "sb\(n)_"
            label(p + "t", "S-Box \(n + 1):", x: 20, y: y, size: 13, bold: true)
            b.text(w(p + "sp"), "Spalte", x: 96, y: y + 1, size: 10, color: .secondary)
            b.text(w(p + "re"), "Reihe", x: 20, y: y + 22, size: 10, color: .secondary)
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
            say("  Umrechnung des Binärwerts in Dezimal.")
            label("cr", "Reihe:  \(six[0])·2^1 + \(six[5])·2^0 = \(row)", x: 20, y: 396, size: 13, color: .orange)
            b.commit()
            label("cc", "Spalte: \(six[1])·2^3 + \(six[2])·2^2 + \(six[3])·2^1 + \(six[4])·2^0 = \(col)", x: 20, y: 418, size: 13, color: .blue)
            b.commit()
            let p = "sb\(j == 0 ? 0 : 7)_"
            for c in 0..<16 { b.setFill(p + "b\(row)_\(c)", .highlight) }
            for r in 0..<4 { b.setFill(p + "b\(r)_\(col)", .highlight) }
            b.setColor(p + "v\(row)_\(col)", .red)
            label("cv", "S\(n)(\(row), \(col)) = \(v)", x: 20, y: 444, size: 14, color: .red, bold: true)
            b.commit()
            say("  Umrechnung des Dezimalwerts in Binär.")
            var q = v, k = 0
            if q == 0 {
                label("cd0", "0 = 0000", x: 360, y: 396, size: 13)
                b.commit()
            }
            while q > 0 {
                label("cd\(k)", "\(k == 0 ? "\(v) := " : "")\(q) : 2 = \(q / 2) Rest \(q % 2)", x: k == 0 ? 330 : 360, y: 396 + CGFloat(k) * 20, size: 13)
                b.commit()
                q /= 2; k += 1
            }
            let four = [(v >> 3) & 1, (v >> 2) & 1, (v >> 1) & 1, v & 1]
            label("cbin", "→ \(four.map(String.init).joined())  (von unten nach oben gelesen, auf 4 Bit aufgefüllt)", x: 360, y: 396 + CGFloat(max(k, 1)) * 20 + 4, size: 12, color: .secondary)
            say("  B[\(n)] durch den \(last ? "" : "ermittelten ")S-Box Wert ersetzen.")
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
            b.chapter("DES-Kern: Funktion f: S-Boxen")
            clearText()
            // keep only B (moved to the top)
            let keep = Set((0..<48).flatMap { ["b\($0)", "bb\($0)"] } + (0..<8).map { "bl\($0)" } + ["ftitle"])
            b.remove(workIDs.filter { !keep.contains($0) })
            workIDs = workIDs.filter { keep.contains($0) }
            for k in 0..<48 { b.move("b\(k)", x: gx(k / 6, k % 6), y: 60); b.move("bb\(k)", x: gx(k / 6, k % 6), y: 60) }
            for j in 0..<8 { b.move("bl\(j)", x: gx(j, 0), y: 40) }
            label("lBtop", "B", x: 20, y: 62, size: 13)
            sboxTable(0, y: 110)
            say("- Die S-Boxen (Substitutions-Boxen) sind ein Satz von 8 4x16 Matrizen, deren Inhalt fest vorgegeben ist.")
            b.commit()
            sboxTable(7, y: 220)
            say("- Aus Platzgründen werden hier nur Box 1 und 8 dargestellt.")
            b.commit()
            say("- Nun wird jeweils eine Zahl von jeder der 8 S-Boxen auf folgende Weise extrahiert:")
            b.commit()
            say("- Für alle S[n] repräsentieren das erste und das letzte Bit von B[n] den Binärwert für die Reihe und die",
                "  mittleren 4 Bits den Wert für die Spalte der jeweiligen Box.",
                "  Es folgt das Beispiel für S[1], B[1] und S[8], B[8]. Alle anderen B[n] werden analog substituiert.")
            b.commit()
            clearText()
            sboxExample(0, tableY: 110, last: false)
            for k in 0..<4 { b.setColor("so\(k)", .text) }
            clearText()
            sboxExample(7, tableY: 220, last: true)
            for k in 28..<32 { b.setColor("so\(k)", .text) }
            say("- B[2] bis B[7] werden nach gleichem Schema ersetzt.")
            for j in 1..<7 { replaceGroup(j) }
            b.commit()
            for k in 0..<32 { b.setColor("so\(k)", .text) }
            // collect into a 8×4 matrix
            let keep2 = Set((0..<32).map { "so\($0)" } + ["ftitle"])
            b.remove(workIDs.filter { !keep2.contains($0) })
            workIDs = workIDs.filter { keep2.contains($0) }
            label("lRm", "R (32 Bit)", x: 20, y: 120)
            for k in 0..<32 {
                let o = cellOrigin(k, cols: 4, x: 20, y: 142, cw: 22, ch: 22)
                b.box(w("smb\(k)"), x: o.x, y: o.y, w: 22, h: 22)
                b.setSize("so\(k)", w: 22, h: 22)
                b.move("so\(k)", x: o.x, y: o.y)
            }
            say("- Das Resultat R wird nun wieder zu einem 32-Bit Wert zusammen geführt (hier direkt als Matrix).")
            b.commit()
        }

        func permutationP() {
            b.chapter("DES-Kern: Funktion f: Permutation P")
            clearText()
            label("lP", "Permutation P", x: 160, y: 120)
            matrix("pP", DESTrace.p.map(String.init), cols: 4, x: 160, y: 142, fill: .cellAlt, size: 12)
            label("lF", "f(R[0], K[1])", x: 300, y: 120)
            emptyMatrix("fm", count: 32, cols: 4, x: 300, y: 142)
            say("- Zuletzt durchläuft R in bekannter Weise Permutation P. Diese ist für alle 16 DES-Runden genau wie die",
                "  S-Boxen fest vorgegeben.")
            b.commit()
            permute(src: (0..<32).map { "so\($0)" }, table: DESTrace.p, tableIDs: (0..<32).map { "pP\($0)" }, dst: "fm",
                    dstOrigins: (0..<32).map { cellOrigin($0, cols: 4, x: 300, y: 142, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 32, cols: 4, single: 0))
            say("- Wir erhalten das Ergebnis von f(R[0], K[1]).")
            label("fres", "f(R[0] , K[1]) = " + hx(t.f[0]), x: 440, y: 150, size: 16, bold: true)
            b.commit()
            say("- Zur Erinnerung: Dieser Wert entsteht in Runde 1 von 16.")
            highlight("schR")
            b.commit()
            say("- Die anschliessende XOR-Verknüpfung mit L[0] ist nicht zu vergessen!")
            label("x1", "  L[0]          = " + hx(t.l[0]), x: 440, y: 190, size: 13)
            label("x2", "⊕ f(R[0], K[1]) = " + hx(t.f[0]), x: 440, y: 210, size: 13)
            label("x3", "= R[1]          = " + hx(t.r[1]), x: 440, y: 236, size: 13, color: .red, bold: true)
            for id in ["x1", "x2", "x3"] { if var it = b.item(id) { it.mono = true; b.put(it) } }
            b.commit()
            // rounds 2…16
            clearWork()
            label("rtitle", "Runde 2-16", x: 20, y: 6, size: 18, bold: true)
            var rows = ["Runde  K[i]                L[i]         R[i]"]
            for i in 1...16 {
                rows.append(String(format: "%5d  ", i) + hx(t.subkeys[i - 1]) + "   " + hx(t.l[i]) + "  " + hx(t.r[i]))
            }
            for (i, r) in rows.enumerated() {
                label("rt\(i)", r, x: 20, y: 40 + CGFloat(i) * 19, size: 12.5, bold: i == 0)
                if var it = b.item("rt\(i)") { it.mono = true; b.put(it) }
            }
            label("rtPO", "Pre-Ausgabe = R[16] L[16] = " + hx(t.preOutput), x: 20, y: 40 + 18 * 19, size: 13, color: .red, bold: true)
            say("- Diese Schritte sind bereits bekannt.")
            b.commit()
        }

        func finalPermutation() {
            b.chapter("Finalisierung: Inverse initiale Permutation")
            clearText()
            clearWork()
            label("lPO", "Pre-Ausgabe", x: 20, y: 34)
            matrix("po", bits(t.preOutput), cols: 8, x: 20, y: 56)
            say("- Die Pre-Ausgabe liefert die Eingabewerte für die inverse Initiale Permutation IP⁻¹, dem finalen Schritt im DES.")
            highlight("schPO", "schIPI")
            b.commit()
            label("lIPI", "IP⁻¹", x: 240, y: 34)
            matrix("ipi", DESTrace.ipInverse.map(String.init), cols: 8, x: 240, y: 56, fill: .cellAlt, size: 12)
            label("lY", "Ausgabeblock Y", x: 460, y: 34)
            emptyMatrix("y", count: 64, cols: 8, x: 460, y: 56)
            say("- Der Permutationsvorgang ist bereits bekannt.")
            b.commit()
            permute(src: (0..<64).map { "po\($0)" }, table: DESTrace.ipInverse, tableIDs: (0..<64).map { "ipi\($0)" }, dst: "y",
                    dstOrigins: (0..<64).map { cellOrigin($0, cols: 8, x: 460, y: 56, cw: 22, ch: 22) },
                    cw: 22, ch: 22, groups: groups(count: 64, cols: 8, single: 0))
            say("- Wir erhalten den Ausgabeblock Y.")
            label("yhex", "Y = " + hx(t.output), x: 460, y: 246, size: 15, color: .red, bold: true)
            let check = (try? SymmetricCipher.encryptRaw(.desECB, key: ct1Bytes(t.k), data: ct1Bytes(t.x))) ?? []
            if check == ct1Bytes(t.output) {
                label("ycheck", "Kontrolle: DES (ECB) von CrypTool liefert denselben Block.", x: 460, y: 272, size: 11, color: .green)
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
            AnimationInputBar(note: error ?? "Eingabeblock X und Schlüssel K: je 8 Byte hexadezimal.",
                              rebuild: rebuild,
                              resetToExample: { blockHex = DESTrace.ct1Plaintext.ct1Hex; keyHex = DESTrace.ct1Key.ct1Hex; rebuild() }) {
                Text("X").foregroundStyle(.secondary)
                TextField("Eingabeblock X (hex)", text: $blockHex).font(.system(.body, design: .monospaced)).frame(width: 230)
                Text("K").foregroundStyle(.secondary)
                TextField("Schlüssel K (hex)", text: $keyHex).font(.system(.body, design: .monospaced)).frame(width: 230)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        guard let x = Hex.decode(blockHex), x.count == 8, let k = Hex.decode(keyHex), k.count == 8 else {
            error = "Bitte je genau 8 Byte hexadezimal eingeben (z. B. 16 BD 40 94 B4 53 8A 7B)."
            return
        }
        error = nil
        script = DESAnimationScript.build(plaintext: x, key: k)
        player.reset(count: script.frames.count)
    }
}
