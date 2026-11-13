import CTCommon

/// Order of the matrix multiplication of the Hill cipher (CT1 offers both).
public enum HillMultiplication: String, CaseIterable, Codable, Sendable {
    /// c = K · p with p as column vector (CT1 default, "Matrix * Spaltenvektor").
    case matrixTimesVector
    /// c = p · K with p as row vector ("Zeilenvektor * Matrix").
    case vectorTimesMatrix

    public var displayName: String {
        switch self {
        case .matrixTimesVector: return "Matrix × column vector"
        case .vectorTimesMatrix: return "Row vector × matrix"
        }
    }
}

/// Hill cipher over the alphabet of the text options (CT1 "Hill").
///
/// CT1 semantics: only alphabet letters are processed (case folded as configured); an incomplete
/// last block is padded with the padding character (default: the alphabet character with number 0);
/// the padding letters are appended to the output. Non-alphabet characters are re-inserted at their
/// positions if "keep non-alphabet characters" is set ("Reformat").
public struct HillCipher: Sendable {
    public let matrix: [[Int]]
    public let inverseMatrix: [[Int]]
    public let options: TextOptions
    public let multiplication: HillMultiplication
    /// Letter numbering: false → A = 0, B = 1 …; true → A = 1, …, last letter = 0 (CT1 option).
    public let firstLetterIsOne: Bool
    public let paddingCharacter: Character
    /// Matrix dimension.
    public var size: Int { matrix.count }
    /// Alphabet size (modulus of the arithmetic).
    public var modulus: Int { options.alphabetSize }

    /// Creates a Hill cipher. Throws if the matrix is not square of size 1…10, the alphabet is too
    /// small or the matrix is not invertible modulo the alphabet size.
    public init(matrix: [[Int]], options: TextOptions, multiplication: HillMultiplication = .matrixTimesVector,
                paddingCharacter: Character? = nil, firstLetterIsOne: Bool = false) throws {
        let n = options.alphabetSize
        guard n >= 2 else { throw CTError("The alphabet must contain at least two characters.") }
        let d = matrix.count
        guard (1...10).contains(d), matrix.allSatisfy({ $0.count == d }) else {
            throw CTError("The Hill key matrix must be square (dimension 1 to 10).")
        }
        let m = matrix.map { $0.map { mod($0, n) } }
        guard let inv = HillCipher.inverse(of: m, modulus: n) else {
            throw CTError("The key matrix is not invertible modulo \(n) (the determinant must be coprime to the alphabet length). Please choose another key.")
        }
        let mapper = LetterMapper(options)
        var pad = options.alphabetCharacters[firstLetterIsOne ? n - 1 : 0]
        if let p = paddingCharacter {
            guard let (pi, _) = mapper.lookup(p) else {
                throw CTError("The padding character \"\(p)\" is not contained in the alphabet.")
            }
            pad = options.alphabetCharacters[pi]
        }
        self.matrix = m
        self.inverseMatrix = inv
        self.options = options
        self.multiplication = multiplication
        self.firstLetterIsOne = firstLetterIsOne
        self.paddingCharacter = pad
    }

    // Letter index (position in alphabet) ↔ Hill number
    private func number(_ index: Int) -> Int { firstLetterIsOne ? (index + 1) % modulus : index }
    private func index(_ number: Int) -> Int { firstLetterIsOne ? mod(number - 1, modulus) : number }

    /// Applies `mat` blockwise to the alphabet indices (padding the last block).
    func transform(indices: [Int], with mat: [[Int]]) -> [Int] {
        let d = size, n = modulus
        guard !indices.isEmpty else { return [] }
        let padIndex = LetterMapper(options).index(of: paddingCharacter) ?? 0
        var nums = indices.map(number)
        while nums.count % d != 0 { nums.append(number(padIndex)) }
        var out = [Int](repeating: 0, count: nums.count)
        var b = 0
        while b < nums.count {
            for j in 0..<d {
                var s = 0
                for k in 0..<d {
                    let coeff = multiplication == .matrixTimesVector ? mat[j][k] : mat[k][j]
                    s = (s + coeff * nums[b + k]) % n
                }
                out[b + j] = s
            }
            b += d
        }
        return out.map(index)
    }

    /// Encrypts the alphabet letters of `text` (layout restored according to the text options).
    public func encrypt(_ text: String) -> String {
        let m = LetterMapper(options)
        return m.reformat(original: text, letters: transform(indices: m.indices(of: text), with: matrix))
    }

    /// Decrypts with the inverse matrix (padding letters of the last block remain).
    public func decrypt(_ text: String) -> String {
        let m = LetterMapper(options)
        return m.reformat(original: text, letters: transform(indices: m.indices(of: text), with: inverseMatrix))
    }

    /// The key as letters (row by row), e.g. for the CT1 key string.
    public var keyLetters: String {
        let chars = options.alphabetCharacters
        return matrix.map { String($0.map { chars[index($0)] }) }.joined(separator: " ")
    }

    // MARK: Matrix utilities

    /// Inverse of a square matrix modulo `modulus` (works for composite moduli), nil if singular.
    public static func inverse(of matrix: [[Int]], modulus n: Int) -> [[Int]]? {
        let d = matrix.count
        guard d > 0, n >= 1, matrix.allSatisfy({ $0.count == d }) else { return nil }
        var a = matrix.map { $0.map { mod($0, n) } }
        var inv = (0..<d).map { i in (0..<d).map { $0 == i ? 1 % n : 0 } }
        guard reduce(&a, &inv, columns: d, modulus: n) else { return nil }
        return inv
    }

    /// Determinant modulo `modulus`.
    public static func determinant(of matrix: [[Int]], modulus n: Int) -> Int {
        let d = matrix.count
        guard d > 0, n > 1 else { return 0 }
        // Bareiss-free approach: Laplace for small, otherwise fraction-free elimination with
        // unimodular row operations tracking the sign.
        var a = matrix.map { $0.map { mod($0, n) } }
        var det = 1
        for col in 0..<d {
            for r in (col + 1)..<max(col + 1, d) {
                while a[r][col] != 0 {
                    let q = a[col][col] / a[r][col]
                    for c in col..<d { a[col][c] = mod(a[col][c] - q * a[r][c], n) }
                    a.swapAt(col, r)
                    det = mod(-det, n)
                }
            }
            det = det * a[col][col] % n
            if det == 0 { return 0 }
        }
        return det
    }

    /// Random key matrix of the given size that is invertible modulo `modulus`.
    public static func randomKey(size: Int, modulus: Int) -> [[Int]] {
        let d = max(1, min(size, 10))
        guard modulus > 1 else { return Array(repeating: Array(repeating: 0, count: d), count: d) }
        var rng = SystemRandomNumberGenerator()
        while true {
            let m = (0..<d).map { _ in (0..<d).map { _ in Int.random(in: 0..<modulus, using: &rng) } }
            if inverse(of: m, modulus: modulus) != nil { return m }
        }
    }

    /// Key matrix from a keyword (CT1 "alphabetic" key entry): the first size² alphabet letters of
    /// the keyword fill the matrix row by row. Returns nil if the keyword is too short.
    public static func matrix(fromKeyword keyword: String, size: Int, options: TextOptions, firstLetterIsOne: Bool = false) -> [[Int]]? {
        let n = options.alphabetSize
        guard size >= 1, n > 0 else { return nil }
        let idx = LetterMapper(options).indices(of: keyword)
        guard idx.count >= size * size else { return nil }
        return (0..<size).map { r in (0..<size).map { c in
            let i = idx[r * size + c]
            return firstLetterIsOne ? (i + 1) % n : i
        } }
    }

    /// Gauss–Jordan elimination over Z_n using only unimodular row operations (extended Euclid),
    /// applied simultaneously to `a` (rows × columns) and `b`. On success the first `columns` rows of
    /// `a` form the identity and the remaining rows are zero. Returns false if a pivot is not a unit.
    static func reduce(_ a: inout [[Int]], _ b: inout [[Int]], columns d: Int, modulus n: Int) -> Bool {
        let rows = a.count
        guard rows >= d else { return false }
        let bw = b.first?.count ?? 0
        for col in 0..<d {
            // collect the gcd of column `col` (rows col…) into row `col`
            for r in (col + 1)..<max(col + 1, rows) {
                while a[r][col] != 0 {
                    let q = a[col][col] / a[r][col]
                    if q != 0 {
                        for c in 0..<d { a[col][c] = mod(a[col][c] - q * a[r][c], n) }
                        for c in 0..<bw { b[col][c] = mod(b[col][c] - q * b[r][c], n) }
                    }
                    a.swapAt(col, r)
                    b.swapAt(col, r)
                }
            }
            guard let pinv = modInverse(a[col][col], n) else { return false }
            if pinv != 1 {
                for c in 0..<d { a[col][c] = a[col][c] * pinv % n }
                for c in 0..<bw { b[col][c] = b[col][c] * pinv % n }
            }
            for r in 0..<rows where r != col && a[r][col] != 0 {
                let f = a[r][col]
                for c in 0..<d { a[r][c] = mod(a[r][c] - f * a[col][c], n) }
                for c in 0..<bw { b[r][c] = mod(b[r][c] - f * b[col][c], n) }
            }
        }
        return true
    }
}

/// Known-plaintext attack on the Hill cipher (CT1 "Hill – Known-Plaintext-Analyse").
public enum HillAnalysis {
    /// Determines the key matrix of the given size from a plaintext/ciphertext pair. Returns nil if
    /// the texts are too short (key not uniquely determined) or contradictory.
    /// Like CT1, both texts are padded with the padding character if their rounded lengths agree,
    /// otherwise only complete blocks of both texts are used.
    public static func knownPlaintext(plaintext: String, ciphertext: String, size: Int, options: TextOptions,
                                      multiplication: HillMultiplication = .matrixTimesVector,
                                      firstLetterIsOne: Bool = false) -> [[Int]]? {
        let n = options.alphabetSize
        guard n >= 2, (1...10).contains(size) else { return nil }
        let mapper = LetterMapper(options)
        let numberOf: (Int) -> Int = { firstLetterIsOne ? ($0 + 1) % n : $0 }
        let p = mapper.indices(of: plaintext).map(numberOf)
        let c = mapper.indices(of: ciphertext).map(numberOf)
        guard !p.isEmpty, !c.isEmpty else { return nil }
        let padNumber = 0
        func rounded(_ l: Int) -> Int { ((l - 1) / size + 1) * size }

        var attempts: [([Int], [Int])] = []
        if rounded(p.count) == rounded(c.count) {
            let len = rounded(p.count)
            attempts.append((p + Array(repeating: padNumber, count: len - p.count),
                             c + Array(repeating: padNumber, count: len - c.count)))
        }
        let full = (min(p.count, c.count) / size) * size
        if full > 0 { attempts.append((Array(p.prefix(full)), Array(c.prefix(full)))) }

        for (pp, cc) in attempts {
            if let k = solve(plain: pp, cipher: cc, size: size, modulus: n, multiplication: multiplication) {
                return k
            }
        }
        return nil
    }

    /// Tries all sizes of `sizes` (ascending, like CT1) and returns the first key that reproduces
    /// the ciphertext.
    public static func knownPlaintext(plaintext: String, ciphertext: String, sizes: ClosedRange<Int>, options: TextOptions,
                                      multiplication: HillMultiplication = .matrixTimesVector,
                                      firstLetterIsOne: Bool = false) -> (size: Int, matrix: [[Int]])? {
        for d in sizes where (1...10).contains(d) {
            if let k = knownPlaintext(plaintext: plaintext, ciphertext: ciphertext, size: d, options: options,
                                      multiplication: multiplication, firstLetterIsOne: firstLetterIsOne) {
                return (d, k)
            }
        }
        return nil
    }

    /// Solves X·A = Y over Z_n (X: plaintext blocks as rows, Y: ciphertext blocks as rows).
    static func solve(plain: [Int], cipher: [Int], size d: Int, modulus n: Int, multiplication: HillMultiplication) -> [[Int]]? {
        let blocks = min(plain.count, cipher.count) / d
        guard blocks >= d else { return nil }
        var x = (0..<blocks).map { b in Array(plain[(b * d)..<(b * d + d)]) }
        var y = (0..<blocks).map { b in Array(cipher[(b * d)..<(b * d + d)]) }
        guard HillCipher.reduce(&x, &y, columns: d, modulus: n) else { return nil }
        // remaining rows must be consistent (0 = 0)
        for r in d..<blocks where y[r].contains(where: { $0 != 0 }) { return nil }
        let a = Array(y.prefix(d))
        // matrix × column vector: c = K p  ⇔  cᵀ = pᵀ Kᵀ  ⇒  K = Aᵀ
        let k: [[Int]] = multiplication == .vectorTimesMatrix ? a : (0..<d).map { i in (0..<d).map { j in a[j][i] } }
        guard HillCipher.inverse(of: k, modulus: n) != nil else { return nil }
        // verify against all blocks
        for b in 0..<blocks {
            for j in 0..<d {
                var s = 0
                for i in 0..<d {
                    let coeff = multiplication == .matrixTimesVector ? k[j][i] : k[i][j]
                    s = (s + coeff * plain[b * d + i]) % n
                }
                if s != cipher[b * d + j] { return nil }
            }
        }
        return k
    }
}
