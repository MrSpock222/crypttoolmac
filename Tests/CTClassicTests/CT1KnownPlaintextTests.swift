import Foundation
import CTCommon
import CTClassic

/// CT1 Hill / transposition known-plaintext parity – called from main.swift.
func runCT1KnownPlaintextTests() {
    let o = TextOptions.default
    let plain = "Dies ist ein Beispieltext fuer die Known-Plaintext-Analyse mit CrypTool. Er sollte lang genug sein."

    group("CT1 KnownPlaintext: Hill") {
        let key = [[3, 3], [2, 5]]
        let mv = try HillCipher(matrix: key, options: o, multiplication: .matrixTimesVector)
        let c = mv.encrypt(plain)
        guard case .found(let r) = CT1HillKnownPlaintext.search(plaintext: plain, ciphertext: c, dimensions: 1...10,
                                                                multiplication: .matrixTimesVector, options: o) else {
            expect(false, "Hill 2x2 nicht gefunden"); return
        }
        expectEqual(r.dimension, 2)
        expectEqual(r.matrix, key)
        expect(!r.lengthMismatch)
        // row-vector form = transpose, and it reproduces the ciphertext
        guard case .found(let rv) = CT1HillKnownPlaintext.search(plaintext: plain, ciphertext: c, dimensions: 1...10,
                                                                 multiplication: .vectorTimesMatrix, options: o) else {
            expect(false, "Hill VM nicht gefunden"); return
        }
        expectEqual(rv.matrix, [[3, 2], [3, 5]])
        expectEqual(try HillCipher(matrix: rv.matrix, options: o, multiplication: .vectorTimesMatrix).encrypt(plain), c)

        // 3x3 with offset 1 (A = 1)
        let k3 = [[6, 24, 1], [13, 16, 10], [20, 17, 15]]
        let h3 = try HillCipher(matrix: k3, options: o, multiplication: .matrixTimesVector, firstLetterIsOne: true)
        let c3 = h3.encrypt(plain)
        if case .found(let r3) = CT1HillKnownPlaintext.search(plaintext: plain, ciphertext: c3, dimensions: 1...10,
                                                              multiplication: .matrixTimesVector, options: o, firstLetterIsOne: true) {
            expectEqual(r3.dimension, 3)
            expectEqual(r3.matrix, k3)
        } else { expect(false, "Hill 3x3 (A=1) nicht gefunden") }

        // ciphertext with extra letters → HILL_OK_LAENGE_UNTERSCHIEDLICH
        if case .found(let r4) = CT1HillKnownPlaintext.search(plaintext: plain, ciphertext: c + "ABCD", dimensions: 2...2,
                                                              multiplication: .matrixTimesVector, options: o) {
            expect(r4.lengthMismatch)
            expectEqual(r4.matrix, key)
        } else { expect(false, "Hill mit Längenunterschied nicht gefunden") }

        // a 2×2 key is also a (block diagonal) 4×4 key; dimension 3 contradicts
        guard case .notFound(let f) = CT1HillKnownPlaintext.search(plaintext: plain, ciphertext: c, dimensions: 3...3,
                                                                   multiplication: .matrixTimesVector, options: o) else {
            expect(false, "Dimension 3 dürfte nicht gefunden werden"); return
        }
        expectEqual(f, [3: .conflict])
        expectEqual(CT1HillKnownPlaintext.notFoundMessage(f), "The key could not be found due to a conflict!")

        // mixed reasons: dim 1 contradiction, dim 2 too short
        guard case .notFound(let g) = CT1HillKnownPlaintext.search(plaintext: "BC", ciphertext: "XY", dimensions: 1...10,
                                                                   multiplication: .matrixTimesVector, options: o) else {
            expect(false, "BC/XY"); return
        }
        expectEqual(g, [1: .conflict, 2: .textTooShort])
        expectEqual(CT1HillKnownPlaintext.notFoundMessage(g),
                    "A key of dimension 1 could not be found due to a conflict.\nA key of dimension 2 could not be found because the text was too short.")
        // no alphabet letters / nothing tested → "Text zu kurz"
        if case .notFound(let h) = CT1HillKnownPlaintext.search(plaintext: "123", ciphertext: "456", dimensions: 1...10,
                                                                multiplication: .matrixTimesVector, options: o) {
            expectEqual(CT1HillKnownPlaintext.notFoundMessage(h), "The key could not be found as the text was too short!")
        } else { expect(false, "123/456") }

        expectEqual(CT1HillKnownPlaintext.keyString(matrix: key, alphabet: o.alphabetCharacters, firstLetterIsOne: false,
                                                    multiplication: .matrixTimesVector),
                    "DIM 2, KEY: DD CF , ALPHABET: ABCDEFGHIJKLMNOPQRSTUVWXYZ, ALPHABET_OFFSET: 0 MULTIPLICATION_VARIANT: 0 ")
    }

    group("CT1 KnownPlaintext: Spaltentransposition") {
        typealias KP = CT1PermutationKnownPlaintext
        let all: Set<PermutationOptions.Direction> = [.rowWise, .columnWise]
        let letters = KP.textElements(plain, options: o)
        var rng = SystemRandomNumberGenerator()
        // every CT1 variant: found, and every listed key reproduces the ciphertext
        for readIn in PermutationOptions.Direction.allCases {
            for permute in PermutationOptions.Direction.allCases {
                for readOut in PermutationOptions.Direction.allCases {
                    for len in [3, 5, 7, 12] {
                        let key = Array(1...len).shuffled(using: &rng)
                        let opts = PermutationOptions(first: .init(readIn: readIn, permute: permute, readOut: readOut), lettersOnly: true)
                        let cipher = try PermutationCipher(firstKey: key, options: opts).encrypt(elements: letters)
                        let res = KP.search(plain: letters, cipher: cipher, sizes: 1...100,
                                            readIn: all, permute: all, readOut: all) ?? []
                        let tag = "\(readIn)/\(permute)/\(readOut) n=\(len)"
                        expect(res.contains { $0.permutation.count == len && $0.readIn == readIn && $0.permute == permute && $0.readOut == readOut },
                               "Schlüssel nicht gefunden: \(tag)")
                        for k in res {
                            let again = try PermutationCipher(firstKey: k.permutation, options: k.options(textMode: true)).encrypt(elements: letters)
                            expect(again == cipher, "falscher Schlüssel \(k.display) \(k.readIn)/\(k.permute)/\(k.readOut) für \(tag)")
                        }
                        // smallest size first
                        expect(zip(res, res.dropFirst()).allSatisfy { $0.permutation.count <= $1.permutation.count }, "Reihenfolge \(tag)")
                    }
                }
            }
        }
        // classic CT1 default (row in, permute columns, column out), text mode on a string
        let k = PermutationCipher.permutation(fromKeyword: "ZEBRAS")
        let c = try PermutationCipher(firstKey: k, options: PermutationOptions(lettersOnly: true)).encrypt(plain, textOptions: o)
        let res = KP.search(plain: letters, cipher: KP.textElements(c, options: o), sizes: 6...6,
                            readIn: [.rowWise], permute: [.columnWise], readOut: [.columnWise]) ?? []
        expectEqual(res.map(\.permutation), [k])
        expectEqual(res.first?.keyString(textMode: true), "6, 3, 2, 4, 1, 5 PARAMETER: TEXT, 0,1,1,0,0,0")
        expectEqual(res.first?.display, "6, 3, 2, 4, 1, 5")

        // binary mode on bytes (all characters)
        let bytes = Array(plain.utf8).map(Int.init)
        let bc = try PermutationCipher(firstKey: [2, 4, 1, 3], options: PermutationOptions()).encrypt(elements: bytes)
        let br = KP.search(plain: bytes, cipher: bc, sizes: 1...10, readIn: all, permute: all, readOut: all) ?? []
        expect(br.contains { $0.permutation == [2, 4, 1, 3] && $0.stage == PermutationOptions.Stage() }, "binär")
        expectEqual(br.first { $0.permutation == [2, 4, 1, 3] && $0.stage == PermutationOptions.Stage() }?.keyString(textMode: false),
                    "2, 4, 1, 3 PARAMETER: BINARY, 0,1,1,0,0,0")

        // CT1 input checks and range handling
        expectEqual(KP.check(plain: [], cipher: []), .empty)
        expectEqual(KP.check(plain: [1, 2], cipher: [1]), .differentSizes)
        expectEqual(KP.check(plain: [1, 2], cipher: [1, 1]), .differentHistograms)
        expectEqual(KP.check(plain: [1, 2], cipher: [2, 1]), nil)
        expect(KP.effectiveRange(from: 0, to: 0, size: 42) == (1, 42))
        expect(KP.effectiveRange(from: 3, to: 500, size: 42) == (3, 100))
        expectEqual(KP.search(plain: [1, 2, 3], cipher: [3, 1, 2], sizes: 5...9, readIn: all, permute: all, readOut: all), [])
    }
}
