import AppKit
import SwiftUI
import CTClassic

// Native versions of CT1's ANIMAL animations "Indiv. Procedures ▸ Visualization of Algorithms ▸
// Caesar / Vigenère / Nihilist" (setup/template-en/animal/anims/*_en.aml). The scripts were
// re-created step by step with the same texts, examples and order of steps; in addition the
// example can be replaced by an own plaintext/key.

extension CT1Visualizations {
    static func openCaesarAnimation() {
        WindowPresenter.tool(id: "ct1-anim-caesar", title: "Caesar Cipher (Animation)", size: CGSize(width: 900, height: 760)) {
            CaesarAnimationView()
        }
    }

    static func openVigenereAnimation() {
        WindowPresenter.tool(id: "ct1-anim-vigenere", title: "Vigenère Cipher (Animation)", size: CGSize(width: 1060, height: 780)) {
            VigenereAnimationView()
        }
    }

    static func openNihilistAnimation() {
        WindowPresenter.tool(id: "ct1-anim-nihilist", title: "Nihilist Cipher (Animation)", size: CGSize(width: 1120, height: 780)) {
            NihilistAnimationView()
        }
    }
}

// MARK: - Script generation

enum ClassicAnimations {
    static let upper = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    static let lower = Array("abcdefghijklmnopqrstuvwxyz")

    // MARK: Caesar

    static let caesarExample = "GALLIA EST OMNIS DIVISA"

    /// Plaintext as shown in the animation: A–Z and blanks, at most 26 positions.
    static func caesarNormalize(_ s: String) -> (text: [Character], truncated: Bool) {
        var out: [Character] = []
        for ch in s.uppercased() {
            let c: Character
            switch ch {
            case "Ä": c = "A"
            case "Ö": c = "O"
            case "Ü": c = "U"
            default: c = ch
            }
            if upper.contains(c) || (c == " " && !out.isEmpty && out.last != " ") { out.append(c) }
        }
        while out.last == " " { out.removeLast() }
        let truncated = out.count > 26
        return (Array(out.prefix(26)), truncated)
    }

    static func caesar(plaintext: String, shift: Int) -> AnimScript {
        let k = ((shift % 26) + 26) % 26
        let (pt, truncated) = caesarNormalize(plaintext)
        let showDots = truncated || plaintext.uppercased() == caesarExample
        let b = AnimScriptBuilder()
        let cw: CGFloat = 20, ch: CGFloat = 22, x0: CGFloat = 20
        let yPT: CGFloat = 165, yAlpha: CGFloat = 235, yCAlpha: CGFloat = 315, yCT: CGFloat = 395
        let labelX: CGFloat = 565
        func x(_ i: Int) -> CGFloat { x0 + CGFloat(i) * cw }

        // 1: title and introduction
        b.text("title", "Caesar Cipher", x: 20, y: 12, size: 24, bold: true)
        b.text("i1", "Caesar is a monoalphabetic substitution cipher using the key k=3 to shift the alphabet.", x: 20, y: 52, size: 15)
        b.text("i2", "Each plaintext character is replaced by the third following letter in alphabetical order.", x: 20, y: 72, size: 15)
        if k != 3 {
            b.text("i5", "In this animation the key \(k) is used.", x: 20, y: 132, size: 15, color: .blue)
        }
        b.commit()

        // 2: plaintext alphabet + explanation
        for i in 0..<26 {
            b.box("pab\(i)", x: x(i), y: yAlpha, w: cw, h: ch)
            b.cellText("pa\(i)", String(upper[i]), x: x(i), y: yAlpha, w: cw, h: ch, size: 15, mono: false)
        }
        b.text("lpa", "Plaintext alphabet", x: labelX, y: yAlpha + 2, size: 15)
        let yT: CGFloat = 445
        // "third" as in caesar_en.aml for the standard key, otherwise "1st", "2nd", "4th" …
        let kth = k == 3 ? "third" : "\(k)" + (k % 10 == 1 && k != 11 ? "st" : k % 10 == 2 && k != 12 ? "nd" : k % 10 == 3 && k != 13 ? "rd" : "th")
        b.text("e1", "The ciphertext alphabet, being the prerequisite for the encryption,", x: 30, y: yT, size: 15, color: .red)
        b.text("e2", "is conducted in the following manner:", x: 30, y: yT + 20, size: 15, color: .red)
        b.text("e3", "For each letter, put the \(kth) letter character next to the letter in the", x: 30, y: yT + 40, size: 15, color: .red)
        b.text("e4", "plaintext alphabet into the ciphertext alphabet.", x: 30, y: yT + 60, size: 15, color: .red)
        b.commit()

        // 3: empty ciphertext alphabet
        for i in 0..<26 { b.box("cab\(i)", x: x(i), y: yCAlpha, w: cw, h: ch) }
        b.text("lca", "Ciphertext alphabet", x: labelX, y: yCAlpha + 2, size: 15)
        b.commit()

        // 4: letters k…Z move down-left into the ciphertext alphabet
        for j in k..<26 { b.spawnCopy(of: "pa\(j)", as: "ca\(j - k)") }
        if k > 0 {
            b.line("arr1", [CGPoint(x: x(k) + cw / 2, y: yAlpha + ch), CGPoint(x: x(k) + cw / 2, y: yAlpha + ch + 30),
                            CGPoint(x: x(0) + cw / 2, y: yCAlpha - 4)], color: .secondary)
        }
        for j in k..<26 { b.move("ca\(j - k)", x: x(j - k), y: yCAlpha) }
        b.commit()

        // 5: the first k letters go to the end
        b.remove("arr1")
        if k > 0 {
            for j in 0..<k { b.spawnCopy(of: "pa\(j)", as: "ca\(26 - k + j)") }
            for j in 0..<k { b.move("ca\(26 - k + j)", x: x(26 - k + j), y: yCAlpha) }
            b.commit()
        }

        // 6: plaintext
        for (i, c) in pt.enumerated() where c != " " {
            b.box("ptb\(i)", x: x(i), y: yPT, w: cw, h: ch)
            b.cellText("pt\(i)", String(c), x: x(i), y: yPT, w: cw, h: ch, size: 15, mono: false)
        }
        if showDots { b.text("ptdots", "...", x: x(min(pt.count + 1, 24)), y: yPT, size: 15) }
        b.text("lpt", "Plaintext", x: labelX, y: yPT + 2, size: 15)
        b.setColor(["e1", "e2", "e3", "e4"], .text)
        b.text("f1", "Encryption is done by replacing every letter of the plaintext message", x: 30, y: yT + 90, size: 15, color: .red)
        b.commit()

        // 7: ciphertext row
        for (i, c) in pt.enumerated() where c != " " { b.box("ctb\(i)", x: x(i), y: yCT, w: cw, h: ch) }
        b.text("lct", "Ciphertext", x: labelX, y: yCT + 2, size: 15)

        var prevCT: String?
        for (i, c) in pt.enumerated() where c != " " {
            let p = upper.firstIndex(of: c)!
            let cIndex = p          // the ciphertext-alphabet cell directly below p (shows letter p + k)
            // a) highlight the plaintext letter (for the first letter together with step 7)
            if let prevCT { b.setColor(prevCT, .text) }
            b.setColor("pt\(i)", .red)
            b.setColor("f1", .red)
            if b.contains("f2") { b.setColor("f2", .text) }
            b.commit()
            // b) the letter moves down to the plaintext alphabet
            b.spawnCopy(of: "pt\(i)", as: "mv\(i)", z: 6)
            b.move("mv\(i)", x: x(p), y: yAlpha)
            b.setColor("pt\(i)", .text)
            b.commit()
            // c) the letter below it in the ciphertext alphabet
            b.setColor("mv\(i)", .text)
            b.setColor("ca\(cIndex)", .red)
            b.line("arrc", [CGPoint(x: x(p) + cw / 2, y: yAlpha + ch + 2), CGPoint(x: x(p) + cw / 2, y: yCAlpha - 3)], color: .red)
            b.commit()
            // d) and moves to the ciphertext
            b.remove("arrc", "mv\(i)")
            b.spawnCopy(of: "ca\(cIndex)", as: "ct\(i)", z: 6)
            b.move("ct\(i)", x: x(i), y: yCT)
            b.setColor("ca\(cIndex)", .text)
            if !b.contains("f2") {
                b.text("f2", "by the according letter of the ciphertext alphabet.", x: 30, y: yT + 110, size: 15, color: .red)
            }
            b.setColor("f2", .red)
            b.setColor("f1", .text)
            b.commit()
            prevCT = "ct\(i)"
        }
        // end
        if let prevCT { b.setColor(prevCT, .text) }
        if b.contains("f2") { b.setColor("f2", .text) }
        if showDots { b.text("ctdots", "...", x: x(min(pt.count + 1, 24)), y: yCT, size: 15) }
        b.commit()
        return AnimScript(b, size: CGSize(width: 740, height: 590))
    }

    // MARK: Vigenère

    static let vigenereExampleText = "dasistgeheim"
    static let vigenereExampleKey = "secret"

    static func lettersOnly(_ s: String, max: Int) -> [Int] {
        var out: [Int] = []
        for ch in s.lowercased() {
            let c: Character
            switch ch { case "ä": c = "a"; case "ö": c = "o"; case "ü": c = "u"; default: c = ch }
            if let i = lower.firstIndex(of: c) { out.append(i) }
            if out.count == max { break }
        }
        return out
    }

    static func vigenere(plaintext: String, key: String) -> AnimScript {
        let pt = lettersOnly(plaintext, max: 14)
        var kk = lettersOnly(key, max: 26)
        if kk.isEmpty { kk = [0] }
        let n = pt.count
        let ks = (0..<n).map { kk[$0 % kk.count] }
        let b = AnimScriptBuilder()
        let cw: CGFloat = 20, chh: CGFloat = 20, x0: CGFloat = 140
        let yKey: CGFloat = 200, yPT: CGFloat = 222, yCT: CGFloat = 254
        func x(_ i: Int) -> CGFloat { x0 + CGFloat(i) * cw }
        // square geometry
        let sqX: CGFloat = 430, sqY: CGFloat = 186, sq: CGFloat = 15, colX: CGFloat = 486
        func sx(_ j: Int) -> CGFloat { colX + CGFloat(j) * sq }
        let headerY = sqY + 15
        func ry(_ r: Int) -> CGFloat { sqY + 30 + CGFloat(r) * sq }

        // 1
        b.text("title", "Vigenère Cipher", x: 20, y: 12, size: 24, bold: true)
        let intro = [
            "Vigenère is a classical, polyalphabetic substitution cipher. During the encryption process,",
            "one character is replaced by varying characters. First, an arbitrary keyword (s) is chosen and",
            "written above the plaintext (k) one after another. Each plaintext character and its keyword",
            "character will make up the ciphertext character (c) by the formula c=(s+k) mod 26. Therefore,",
            "the characters of the alphabet are indexed from 0 to 25. In addition to the mathematical",
            "calculation we can use the Vigenère square for encryption.",
        ]
        for (i, l) in intro.enumerated() { b.text("i\(i)", l, x: 20, y: 50 + CGFloat(i) * 19, size: 14) }
        b.commit()
        // 2 plaintext
        b.text("lpt", "Plaintext (k):", x: 20, y: yPT + 1, size: 15)
        for i in 0..<n {
            b.box("ptb\(i)", x: x(i), y: yPT, w: cw, h: chh)
            b.cellText("pt\(i)", String(lower[pt[i]]), x: x(i), y: yPT, w: cw, h: chh, size: 15, mono: false)
        }
        b.commit()
        // 3 key
        b.text("lkey", "Keyword (s):", x: 20, y: yKey + 1, size: 15)
        for i in 0..<n {
            b.box("kb\(i)", x: x(i), y: yKey, w: cw, h: chh, fill: .cellAlt)
            b.cellText("k\(i)", String(lower[ks[i]]), x: x(i), y: yKey, w: cw, h: chh, size: 15, mono: false)
        }
        b.commit()
        // 4 ciphertext row, formula and square
        b.text("lct", "Ciphertext (c):", x: 20, y: yCT + 1, size: 15)
        for i in 0..<n { b.box("ctb\(i)", x: x(i), y: yCT, w: cw, h: chh) }
        b.text("fm0", "We can calculate the ciphertext with the formula:", x: 20, y: 340, size: 15)
        let fy1: CGFloat = 366, fy2: CGFloat = 396
        for (j, t) in ["c", "=", "(", "s", "+", "k", ")", "mod 26"].enumerated() {
            b.text("fa\(j)", t, x: 20 + CGFloat(j) * 22, y: fy1, size: 15)
        }
        for (j, t) in [(1, "="), (2, "("), (4, "+"), (6, ")"), (7, "mod 26")] {
            b.text("fb\(j)", t, x: 20 + CGFloat(j) * 22, y: fy2, size: 15)
        }
        b.box("sqbg", x: sqX, y: sqY - 4, w: 466, h: 30 + 26 * sq + 10, fill: .cell, stroke: .gray, z: -1)
        b.line("sqv", [CGPoint(x: colX - 6, y: sqY - 4), CGPoint(x: colX - 6, y: sqY + 36 + 26 * sq)], arrow: false, color: .gray)
        b.line("sqh", [CGPoint(x: sqX, y: headerY + 15), CGPoint(x: sqX + 466, y: headerY + 15)], arrow: false, color: .gray)
        b.text("sqIdx", "Index", x: sqX + 6, y: sqY, size: 10)
        b.text("sqKl", "Plaintext", x: sqX + 6, y: headerY, size: 10)
        for j in 0..<26 {
            b.cellText("sqi\(j)", "\(j)", x: sx(j), y: sqY, w: sq, h: sq, size: 9, mono: false)
            b.cellText("sqc\(j)", String(lower[j]), x: sx(j), y: headerY, w: sq, h: sq, size: 10, bold: true, mono: false)
        }
        for r in 0..<26 {
            b.text("sqr\(r)", r == 0 ? "Shift 0" : "\(r)", x: r == 0 ? sqX + 6 : sqX + 28, y: ry(r), size: 10)
            for j in 0..<26 {
                b.cellText("sq\(r)_\(j)", String(lower[(r + j) % 26]), x: sx(j), y: ry(r), w: sq, h: sq, size: 10,
                           bold: j == 0, mono: false, z: 3)
            }
        }
        b.commit()

        for i in 0..<n {
            let s = ks[i], k = pt[i], c = (s + k) % 26
            // a) key letter, row in the square
            b.setColor("k\(i)", .red)
            b.box("hlR", x: sx(0), y: ry(s), w: sq, h: sq, fill: .highlight, stroke: .text, z: 2)
            b.commit()
            // b) s value
            b.cellText("vs", "\(s)", x: 20 + 3 * 22 - 6, y: fy2, w: 30, h: 20, size: 15, color: .red, mono: false)
            b.commit()
            // c) plaintext letter, column in the square
            b.setColor("pt\(i)", .red)
            b.box("hlC", x: sx(k), y: headerY, w: sq, h: sq, fill: .highlight, stroke: .text, z: 2)
            b.commit()
            // d) k value
            b.cellText("vk", "\(k)", x: 20 + 5 * 22 - 6, y: fy2, w: 30, h: 20, size: 15, color: .red, mono: false)
            b.commit()
            // e) result
            b.cellText("vc", "\(c)", x: 10, y: fy2, w: 30, h: 20, size: 15, color: .red, mono: false)
            b.line("arrR", [CGPoint(x: sx(0) + sq, y: ry(s) + sq / 2), CGPoint(x: sx(k) + 2, y: ry(s) + sq / 2)], color: .text, z: 4)
            b.line("arrC", [CGPoint(x: sx(k) + sq / 2, y: headerY + sq), CGPoint(x: sx(k) + sq / 2, y: ry(s) - 1)], color: .text, z: 4)
            b.commit()
            // f) the ciphertext letter; highlight boxes move to the intersection
            b.cellText("ct\(i)", String(lower[c]), x: x(i), y: yCT, w: cw, h: chh, size: 15, color: .red, mono: false)
            b.move("hlR", x: sx(k), y: ry(s))
            b.move("hlC", x: sx(k), y: ry(s))
            b.setColor("sq\(s)_\(k)", .red)
            b.commit()
            // cleanup for the next letter
            b.remove("vs", "vk", "vc", "hlR", "hlC", "arrR", "arrC")
            b.setColor(["k\(i)", "pt\(i)", "ct\(i)", "sq\(s)_\(k)"], .text)
        }
        b.remove("fb1", "fb2", "fb4", "fb6", "fb7")
        b.commit()
        return AnimScript(b, size: CGSize(width: 900, height: 620))
    }

    // MARK: Nihilist

    static let nihilistExampleKey1 = "EXAMPLE"
    static let nihilistExampleKey2 = "NEXT"
    static let nihilistExampleText = "STOPTHAT"

    static func polybiusLetters(_ s: String, max: Int) -> [Character] {
        var out: [Character] = []
        for ch in s.uppercased() {
            var c = ch
            switch c { case "Ä": c = "A"; case "Ö": c = "O"; case "Ü": c = "U"; case "J": c = "I"; default: break }
            if upper.contains(c) { out.append(c) }
            if out.count == max { break }
        }
        return out
    }

    static func nihilist(key1: String, key2: String, plaintext: String) -> AnimScript {
        let k1 = polybiusLetters(key1, max: 20)
        var k2 = polybiusLetters(key2, max: 12)
        if k2.isEmpty { k2 = ["A"] }
        let pt = polybiusLetters(plaintext, max: 16)
        let square = Nihilist.square(keyword: String(k1))
        var coord: [Character: Int] = [:]
        for (r, row) in square.enumerated() { for (c, ch) in row.enumerated() { coord[ch] = (r + 1) * 10 + c + 1 } }
        func num(_ c: Character) -> Int { coord[c] ?? 0 }

        let b = AnimScriptBuilder()
        let cell: CGFloat = 22, sqX: CGFloat = 46, sqY: CGFloat = 340
        func cx(_ c: Int) -> CGFloat { sqX + CGFloat(c) * cell }
        func cy(_ r: Int) -> CGFloat { sqY + CGFloat(r) * cell }
        let ax0: CGFloat = 20, aw: CGFloat = 22, ay: CGFloat = 282
        func ax(_ i: Int) -> CGFloat { ax0 + CGFloat(i) * aw }
        let wx0: CGFloat = 440, ww: CGFloat = 32
        func wx(_ i: Int) -> CGFloat { wx0 + CGFloat(i) * ww }
        let yK1: CGFloat = 340, yK2: CGFloat = 400, yK2n: CGFloat = 424, yPT: CGFloat = 462, yPTn: CGFloat = 486
        let yRepK: CGFloat = 528, yRepP: CGFloat = 552, yCT: CGFloat = 592

        // 1
        b.text("title", "Nihilist Cipher", x: 20, y: 12, size: 24, bold: true)
        b.text("intro", "Nihilist is a classical cipher which consists of two steps each using a keyword of free choice.", x: 20, y: 48, size: 13)
        b.commit()

        // 2: Step 1
        b.chapter("Step 1: Distributing the letters of the first keyword into the square")
        b.text("s1", "Step 1:", x: 20, y: 76, size: 13, color: .red)
        b.text("s1a", "All letters of the alphabet (with J=I) are represented by 2-digit numbers using a 5*5 Polybius square.", x: 95, y: 76, size: 13)
        b.text("s1b", "First, the letters of the 1st keyword are put into the square. Here, same keyword characters are used only once.", x: 95, y: 95, size: 13)
        for i in 0..<5 {
            b.cellText("hc\(i)", "\(i + 1)", x: cx(i), y: sqY - cell, w: cell, h: cell, size: 15, mono: false)
            b.cellText("hr\(i)", "\(i + 1)", x: sqX - cell, y: cy(i), w: cell, h: cell, size: 15, mono: false)
            for j in 0..<5 { b.box("sqb\(i)_\(j)", x: cx(j), y: cy(i), w: cell, h: cell, fill: .white) }
        }
        for i in 0..<26 {
            b.box("ab\(i)", x: ax(i), y: ay, w: aw, h: cell)
            b.cellText("a\(i)", String(upper[i]), x: ax(i), y: ay, w: aw, h: cell, size: 15, mono: false)
        }
        b.text("ls1", "Step 1:", x: 200, y: yK1 - 20, size: 15, color: .red)
        b.text("lk1", "The first keyword:", x: 200, y: yK1 + 2, size: 15)
        for (i, c) in k1.enumerated() {
            b.box("k1b\(i)", x: wx(i), y: yK1, w: ww, h: cell, fill: .cellAlt)
            b.cellText("k1\(i)", String(c), x: wx(i), y: yK1, w: ww, h: cell, size: 15, mono: false)
        }
        b.commit()

        // Fill order: distinct keyword letters, then the rest (J is skipped / merged with I).
        var fillOrder: [Character] = []
        for row in square { fillOrder.append(contentsOf: row) }
        let keyDistinct = Set(k1).count
        var placed = Set<Int>()
        for (n, c) in fillOrder.enumerated() {
            let ai = upper.firstIndex(of: c)!
            let r = n / 5, col = n % 5
            if n == keyDistinct {
                b.text("s1c", "Then, the rest of the alphabet is filled in in alphabetical order. Each letter is designated", x: 95, y: 114, size: 13)
                b.text("s1d", "by a 2-digit number, coming from the row and the column index of the square.", x: 95, y: 133, size: 13)
            }
            b.setColor("a\(ai)", .red)
            b.commit()
            b.move("a\(ai)", x: cx(col), y: cy(r))
            b.setColor("a\(ai)", .text)
            b.remove("ab\(ai)")
            placed.insert(ai)
            if c == "I" { b.remove("a9", "ab9") }   // J = I
            b.commit()
        }
        // leftovers of the alphabet disappear
        for i in 0..<26 where !placed.contains(i) { b.remove("ab\(i)", "a\(i)") }

        // Step 2
        b.chapter("Step 2: Add the plaintext numbers to the repeatedly used numbers of the second keyword")
        b.setColor(["s1", "ls1"], .text)
        b.text("s2", "Step 2:", x: 20, y: 160, size: 13, color: .red)
        b.text("s2a", "A 2nd keyword is chosen and its characters are replaced by numbers according to the Polybius square.", x: 95, y: 160, size: 13)
        b.text("ls2", "Step 2:", x: 200, y: yK2 - 20, size: 15, color: .red)
        b.commit()
        b.text("lk2", "The second keyword:", x: 200, y: yK2 + 2, size: 15)
        for (i, c) in k2.enumerated() {
            b.box("k2b\(i)", x: wx(i), y: yK2, w: ww, h: cell, fill: .cellAlt)
            b.cellText("k2\(i)", String(c), x: wx(i), y: yK2, w: ww, h: cell, size: 15, mono: false)
        }
        b.commit()

        func coordinateSteps(letter c: Character, sourceID: String, targetID: String, tx: CGFloat, ty: CGFloat) {
            let v = num(c), r = v / 10 - 1, col = v % 10 - 1
            b.setColor(sourceID, .red)
            b.box("hlA", x: cx(col), y: cy(r), w: cell, h: cell, fill: .highlight, stroke: .text, z: 1)
            b.box("hlB", x: cx(col), y: cy(r), w: cell, h: cell, fill: .highlight, stroke: .text, z: 1)
            b.commit()
            b.move("hlA", x: sqX - cell, y: cy(r))
            b.move("hlB", x: cx(col), y: sqY - cell)
            b.line("arA", [CGPoint(x: cx(col), y: cy(r) + cell / 2), CGPoint(x: sqX - 2, y: cy(r) + cell / 2)], z: 4)
            b.line("arB", [CGPoint(x: cx(col) + cell / 2, y: cy(r)), CGPoint(x: cx(col) + cell / 2, y: sqY - 2)], z: 4)
            b.cellText(targetID, "\(v)", x: tx, y: ty, w: ww, h: cell, size: 15, color: .red, mono: false)
            b.commit()
            b.remove("hlA", "hlB", "arA", "arB")
            b.setColor([sourceID, targetID], .text)
        }

        for (i, c) in k2.enumerated() {
            coordinateSteps(letter: c, sourceID: "k2\(i)", targetID: "k2n\(i)", tx: wx(i), ty: yK2n)
        }
        b.text("s2b", "Same happens with the plaintext: Its letters are replaced by the row and column index of each plaintext letter.", x: 95, y: 179, size: 13)
        b.commit()
        b.text("lpt", "Plaintext:", x: 200, y: yPT + 2, size: 15)
        for (i, c) in pt.enumerated() {
            b.box("ptb\(i)", x: wx(i), y: yPT, w: ww, h: cell)
            b.cellText("pt\(i)", String(c), x: wx(i), y: yPT, w: ww, h: cell, size: 15, mono: false)
        }
        b.commit()
        for (i, c) in pt.enumerated() {
            coordinateSteps(letter: c, sourceID: "pt\(i)", targetID: "ptn\(i)", tx: wx(i), ty: yPTn)
        }
        b.text("s2c", "The numbers of the 2nd keyword are written above the plaintext numbers – one after another.", x: 95, y: 198, size: 13)
        b.commit()
        // repeated key numbers above copied plaintext numbers
        for i in pt.indices {
            b.spawnCopy(of: "k2n\(i % k2.count)", as: "rk\(i)")
            b.spawnCopy(of: "ptn\(i)", as: "rp\(i)")
        }
        b.text("lrk", "Keyword:", x: 200, y: yRepK + 2, size: 15, color: .secondary)
        b.text("lrp", "+ Plaintext:", x: 200, y: yRepP + 2, size: 15, color: .secondary)
        for i in pt.indices {
            b.move("rk\(i)", x: wx(i), y: yRepK)
            b.move("rp\(i)", x: wx(i), y: yRepP)
        }
        b.line("sum", [CGPoint(x: wx(0), y: yRepP + cell + 6), CGPoint(x: wx(max(pt.count, 1)), y: yRepP + cell + 6)], arrow: false)
        b.commit()
        b.text("s2d", "Each ciphertext character is the sum of the plaintext character and the according keyword character.", x: 95, y: 217, size: 13)
        b.text("lct", "Ciphertext:", x: 200, y: yCT + 2, size: 15)
        b.commit()
        for i in pt.indices {
            b.setColor("rk\(i)", .red)
            b.commit()
            b.setColor("rp\(i)", .red)
            b.commit()
            let v = num(k2[i % k2.count]) + num(pt[i])
            b.cellText("ct\(i)", "\(v)", x: wx(i), y: yCT, w: ww, h: cell, size: 15, color: .red, bold: true, mono: false)
            b.commit()
            b.setColor(["rk\(i)", "rp\(i)", "ct\(i)"], .text)
        }
        b.setColor(["s2", "ls2"], .text)
        b.commit()
        return AnimScript(b, size: CGSize(width: 1110, height: 625))
    }
}

// MARK: - Views

struct CaesarAnimationView: View {
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 1.3)
    @CTState private var script = AnimScript.empty
    @CTState private var plaintext = ClassicAnimations.caesarExample
    @CTState private var shift = 3

    var body: some View {
        ScriptedAnimationView(script: script, player: player) {
            AnimationInputBar(note: "Plaintext: letters A–Z and blanks, at most 26 characters are animated.",
                              rebuild: rebuild, resetToExample: { plaintext = ClassicAnimations.caesarExample; shift = 3; rebuild() }) {
                TextField("Plaintext", text: $plaintext).frame(width: 260)
                Stepper("Key: \(shift) (\(String(ClassicAnimations.upper[shift])))", value: $shift, in: 0...25)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        script = ClassicAnimations.caesar(plaintext: plaintext, shift: shift)
        player.reset(count: script.frames.count)
    }
}

struct VigenereAnimationView: View {
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 1.2)
    @CTState private var script = AnimScript.empty
    @CTState private var plaintext = ClassicAnimations.vigenereExampleText
    @CTState private var key = ClassicAnimations.vigenereExampleKey

    var body: some View {
        ScriptedAnimationView(script: script, player: player) {
            AnimationInputBar(note: "Letters a–z only; at most 14 plaintext letters are animated.",
                              rebuild: rebuild,
                              resetToExample: { plaintext = ClassicAnimations.vigenereExampleText; key = ClassicAnimations.vigenereExampleKey; rebuild() }) {
                TextField("Plaintext", text: $plaintext).frame(width: 220)
                TextField("Keyword", text: $key).frame(width: 140)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        script = ClassicAnimations.vigenere(plaintext: plaintext, key: key)
        player.reset(count: script.frames.count)
    }
}

struct NihilistAnimationView: View {
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 1.1)
    @CTState private var script = AnimScript.empty
    @CTState private var key1 = ClassicAnimations.nihilistExampleKey1
    @CTState private var key2 = ClassicAnimations.nihilistExampleKey2
    @CTState private var plaintext = ClassicAnimations.nihilistExampleText

    var body: some View {
        ScriptedAnimationView(script: script, player: player) {
            AnimationInputBar(note: "Letters A–Z (J = I); at most 16 plaintext letters are animated.",
                              rebuild: rebuild,
                              resetToExample: {
                                  key1 = ClassicAnimations.nihilistExampleKey1; key2 = ClassicAnimations.nihilistExampleKey2
                                  plaintext = ClassicAnimations.nihilistExampleText; rebuild()
                              }) {
                TextField("1st keyword", text: $key1).frame(width: 150)
                TextField("2nd keyword", text: $key2).frame(width: 130)
                TextField("Plaintext", text: $plaintext).frame(width: 180)
            }
        }
        .onAppear(perform: rebuild)
    }

    private func rebuild() {
        script = ClassicAnimations.nihilist(key1: key1, key2: key2, plaintext: plaintext)
        player.reset(count: script.frames.count)
    }
}
