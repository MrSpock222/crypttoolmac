import CTCommon

// CT1 known-plaintext analyses: "Hill-Analyse (Known Plaintext)" (DlgHillAnalysis.cpp, HillAnalysis.cpp,
// CHillEncryption::angriff) and "Analyse einer einstufigen Spaltentransposition (Known Plaintext)"
// (DlgAutomatedPermAnalysis.cpp, automated_permanalysis.cpp).

// MARK: - Hill

/// CT1 Hill known-plaintext attack over a range of dimensions with CT1's per-dimension failure reasons.
public enum CT1HillKnownPlaintext {
    /// Reason why no key of a dimension was found (hill.h).
    public enum Failure: Error, Equatable, Sendable {
        /// HILL_NICHT_OK_NICHT_GEFUNDEN – the plaintext blocks do not determine the key ("Text zu kurz").
        case textTooShort
        /// HILL_NICHT_OK_WIDERSPRUCH – a key was determined but contradicts other blocks or is singular.
        case conflict
    }

    public struct Result: Equatable, Sendable {
        /// Matrix dimension.
        public var dimension: Int
        /// Key matrix (Hill numbers, see `firstLetterIsOne`) for `multiplication` – usable with `HillCipher`.
        public var matrix: [[Int]]
        public var multiplication: HillMultiplication
        /// HILL_OK_LAENGE_UNTERSCHIEDLICH: the (block-rounded) lengths of the texts differ.
        public var lengthMismatch: Bool
    }

    public enum Outcome: Equatable, Sendable {
        case found(Result)
        /// Failure reason per tested dimension (CT1 tests only dimensions ≤ the letter counts).
        case notFound([Int: Failure])
    }

    /// CHillEncryption::angriff. Dimensions are tried in ascending order; the first key found is returned.
    /// Like CT1 both texts are reduced to the alphabet letters (case folded per the text options), an
    /// incomplete last block is padded with the padding character if the rounded lengths agree, otherwise
    /// only complete blocks of both texts are used. The key is unique, it is returned in the form for
    /// `multiplication` (the "(Vektorreihe) x (Matrix)" form is the transpose of the other one).
    public static func search(plaintext: String, ciphertext: String, dimensions: ClosedRange<Int>,
                              multiplication: HillMultiplication, options: TextOptions,
                              firstLetterIsOne: Bool = false, paddingCharacter: Character? = nil) -> Outcome {
        let n = options.alphabetSize
        guard n >= 2 else { return .notFound([:]) }
        let mapper = LetterMapper(options)
        let number: (Int) -> Int = { firstLetterIsOne ? ($0 + 1) % n : $0 }
        let p = mapper.indices(of: plaintext).map(number)
        let c = mapper.indices(of: ciphertext).map(number)
        var pad = 0
        if let ch = paddingCharacter, let (i, _) = mapper.lookup(ch) { pad = number(i) }
        let lo = max(1, dimensions.lowerBound)
        let hi = min(10, dimensions.upperBound, p.count, c.count)
        var failures: [Int: Failure] = [:]
        guard lo <= hi else { return .notFound(failures) }
        for d in lo...hi {
            let lp = ((p.count - 1) / d + 1) * d, lc = ((c.count - 1) / d + 1) * d
            var pp: [Int], cc: [Int]
            if lp == lc {
                pp = p + Array(repeating: pad, count: lp - p.count)
                cc = c + Array(repeating: pad, count: lc - c.count)
            } else {
                let l = (min(p.count, c.count) / d) * d
                pp = Array(p.prefix(l)); cc = Array(c.prefix(l))
            }
            switch solveRowForm(plain: pp, cipher: cc, size: d, modulus: n) {
            case .success(let k):
                let m = multiplication == .vectorTimesMatrix ? k : transpose(k)
                return .found(Result(dimension: d, matrix: m, multiplication: multiplication, lengthMismatch: lp != lc))
            case .failure(let f):
                failures[d] = f
            }
        }
        return .notFound(failures)
    }


    /// Solves C = P·K (blocks as row vectors). Fails with `.textTooShort` if the plaintext blocks do not
    /// generate Z_n^d, with `.conflict` if the system is inconsistent or K is not invertible.
    static func solveRowForm(plain: [Int], cipher: [Int], size d: Int, modulus n: Int) -> Swift.Result<[[Int]], Failure> {
        let blocks = min(plain.count, cipher.count) / d
        guard blocks >= d else { return .failure(.textTooShort) }
        var x = (0..<blocks).map { b in Array(plain[(b * d)..<(b * d + d)]) }
        var y = (0..<blocks).map { b in Array(cipher[(b * d)..<(b * d + d)]) }
        guard HillCipher.reduce(&x, &y, columns: d, modulus: n) else { return .failure(.textTooShort) }
        for r in d..<blocks where y[r].contains(where: { $0 != 0 }) { return .failure(.conflict) }
        let k = Array(y.prefix(d))
        guard HillCipher.inverse(of: k, modulus: n) != nil else { return .failure(.conflict) }
        return .success(k)
    }

    static func transpose(_ m: [[Int]]) -> [[Int]] {
        m.indices.map { i in m.indices.map { j in m[j][i] } }
    }

    /// CT1 error text of HillAnalysis::analyze for a failed search.
    public static func notFoundMessage(_ failures: [Int: Failure]) -> String {
        let reasons = Set(failures.values)
        if reasons == [.conflict] { return "Der Schlüssel konnte nicht gefunden werden (Widerspruch) !" }
        if reasons.count <= 1 { return "Der Schlüssel konnte nicht gefunden werden (Text zu kurz) !" }
        func list(_ f: Failure) -> String {
            failures.filter { $0.value == f }.keys.sorted().map(String.init).joined(separator: ", ")
        }
        return "Ein Schlüssel der Dimension \(list(.conflict)) konnte wegen eines Widerspruches nicht gefunden werden.\n"
             + "Ein Schlüssel der Dimension \(list(.textTooShort)) konnte wegen des zu kurzen Textes nicht gefunden werden."
    }

    /// Letter of a Hill number (CKeyHillBase::chr).
    public static func letter(_ v: Int, alphabet: [Character], firstLetterIsOne: Bool) -> Character {
        let n = alphabet.count
        let i = firstLetterIsOne ? ((v - 1) % n + n) % n : (v % n + n) % n
        return alphabet[i]
    }

    /// CKeyHillBase::keyToStr: "DIM 2, KEY: AB CD , ALPHABET: A…Z, ALPHABET_OFFSET: 0 MULTIPLICATION_VARIANT: 0 "
    /// (variant 0 = (Matrix) x (Vektorspalte), 1 = (Vektorreihe) x (Matrix) – as in the Mac Hill dialog).
    public static func keyString(matrix: [[Int]], alphabet: [Character], firstLetterIsOne: Bool,
                                 multiplication: HillMultiplication) -> String {
        var s = "DIM \(matrix.count), KEY: "
        for row in matrix {
            for v in row { s.append(letter(v, alphabet: alphabet, firstLetterIsOne: firstLetterIsOne)) }
            s += " "
        }
        s += ", ALPHABET: " + String(alphabet)
        s += ", ALPHABET_OFFSET: \(firstLetterIsOne ? 1 : 0) "
        s += "MULTIPLICATION_VARIANT: \(multiplication == .matrixTimesVector ? 0 : 1) "
        return s
    }
}

// MARK: - Single columnar transposition

/// CT1 known-plaintext analysis of a single columnar transposition (automated_permanalysis.cpp).
public enum CT1PermutationKnownPlaintext {
    public typealias Direction = PermutationOptions.Direction

    /// CT1 MAX_PERM_LENGTH.
    public static let maxPermutationSize = 100

    /// One found key (CT1 `permkey`).
    public struct Key: Equatable, Hashable, Sendable {
        /// Permutation, 1-based ranks per column/row as in CT1's display ("3, 1, 2") and `PermutationCipher`.
        public var permutation: [Int]
        /// "Einlesen" (dirPlain).
        public var readIn: Direction
        /// "Permutieren" (dirPerm).
        public var permute: Direction
        /// "Auslesen" (dirCipher).
        public var readOut: Direction

        public init(permutation: [Int], readIn: Direction, permute: Direction, readOut: Direction) {
            self.permutation = permutation
            self.readIn = readIn
            self.permute = permute
            self.readOut = readOut
        }

        /// Stage of `PermutationOptions` that reproduces the ciphertext with `permutation` as first key.
        public var stage: PermutationOptions.Stage { .init(readIn: readIn, permute: permute, readOut: readOut) }

        /// Options for `PermutationCipher` (text mode = only alphabet letters).
        public func options(textMode: Bool) -> PermutationOptions {
            PermutationOptions(first: stage, second: PermutationOptions.Stage(), applyInverse: false, lettersOnly: textMode)
        }

        /// CT1 str_permutation: "3, 1, 2".
        public var display: String { permutation.map(String.init).joined(separator: ", ") }

        /// CT1 key store string (copy_perm_key::copy_key): "3, 1, 2 PARAMETER: TEXT, 0,1,1,0,0,0".
        public func keyString(textMode: Bool) -> String {
            func v(_ d: Direction) -> Int { d == .columnWise ? 1 : 0 }
            return "\(display) PARAMETER: \(textMode ? "TEXT, " : "BINARY, ")\(v(readIn)),\(v(permute)),\(v(readOut)),0,0,0"
        }

        /// IDS_IOP_ROW / IDS_IOP_COL.
        public static func name(_ d: Direction) -> String { d == .columnWise ? "Spaltenweise" : "Zeilenweise" }
    }

    public enum InputError: Error, Equatable, Sendable {
        case empty, differentSizes, differentHistograms, range

        /// CT1 message texts (IDS_PA_EMPTYFILE, ID_PA_ERROR_DIFFERNT_DOCUMENT_SIZES, …).
        public var message: String {
            switch self {
            case .empty: return "Beide Dateien (Klartext- und Geheimtextdatei) sind leer. "
            case .differentSizes: return "Die Dokumentgrößen stimmen nicht überein."
            case .differentHistograms:
                return "Die Histogramme (Häufigkeitsverteilung der gültigen Alphabetzeichen) der Dokumente stimmen nicht überein.\nDer Geheimtext kann nicht das Ergebnis einer Permutations-Verschlüsselung im ausgewählten Modus (Textmodus bzw. Binärmodus) sein.\nSie können diesen Modus umschalten und es nochmal probieren."
            case .range:
                return "Bitte überprüfen Sie die Eingabe des Suchraums für die Permutationsgröße:\r\nDie untere Grenze (von) muss kleiner oder gleich die der oberen Grenze (bis) sein."
            }
        }
    }

    /// CT1 readSource in text mode: alphabet letters only (case folded per the text options).
    public static func textElements(_ text: String, options: TextOptions) -> [Int] {
        LetterMapper(options).indices(of: text)
    }

    /// CT1 setFilenames checks: equal sizes and equal histograms (plus: not both empty).
    public static func check(plain: [Int], cipher: [Int]) -> InputError? {
        if plain.isEmpty && cipher.isEmpty { return .empty }
        if plain.count != cipher.count { return .differentSizes }
        if plain.sorted() != cipher.sorted() { return .differentHistograms }
        return nil
    }

    /// CT1 OnBnClickedCompute range handling: from 0 → 1, to 0 → data size, to > 100 → 100.
    /// Returns the effective (from, to) as shown in the dialog afterwards.
    public static func effectiveRange(from: Int, to: Int, size: Int) -> (from: Int, to: Int) {
        let lo = from <= 0 ? 1 : from
        var hi = to == 0 ? size : to
        if hi > maxPermutationSize { hi = maxPermutationSize }
        return (lo, hi)
    }

    /// iterate_key_param: tries all sizes `sizes` (descending) and the allowed directions; at most one key
    /// per combination. The result is in CT1's list order (smallest size first; within a size the
    /// combinations in reverse iteration order). Sizes larger than the data length are skipped (they
    /// only produce degenerate keys). Returns nil if cancelled.
    public static func search(plain: [Int], cipher: [Int], sizes: ClosedRange<Int>,
                              readIn: Set<Direction>, permute: Set<Direction>, readOut: Set<Direction>,
                              cancel: CancellationToken? = nil, progress: ((Double) -> Void)? = nil) -> [Key]? {
        guard plain.count == cipher.count, !plain.isEmpty else { return [] }
        let upper = min(sizes.upperBound, plain.count, maxPermutationSize)
        let lower = max(1, sizes.lowerBound)
        guard lower <= upper else { return [] }
        let order: [Direction] = [.rowWise, .columnWise]
        var found: [Key] = []
        var done = 0
        for size in stride(from: upper, through: lower, by: -1) {
            if cancel?.isCancelled == true { return nil }
            for pd in order where permute.contains(pd) {
                for cd in order where readOut.contains(cd) {
                    for id in order where readIn.contains(id) {
                        var s = Search(plain: plain, cipher: cipher, permSize: size,
                                       readDir: id == .columnWise ? 1 : 0, permDir: pd == .columnWise ? 1 : 0)
                        if let k = s.run(linear: pd == cd) {
                            found.append(Key(permutation: k, readIn: id, permute: pd, readOut: cd))
                        }
                    }
                }
            }
            done += 1
            progress?(Double(done) / Double(upper - lower + 1))
        }
        return found.reversed()
    }

    /// Port of CT1's perm_table / seek_linear / seek_scattered (1-based indices as in the original).
    struct Search {
        let plain: [Int], cipher: [Int]
        let size: Int, permSize: Int, readDir: Int, permDir: Int
        let p: Int, q: Int
        var rem: [Bool]
        var pk: [Int]

        init(plain: [Int], cipher: [Int], permSize: Int, readDir: Int, permDir: Int) {
            self.plain = plain; self.cipher = cipher
            size = plain.count
            self.permSize = permSize; self.readDir = readDir; self.permDir = permDir
            p = size / permSize; q = size % permSize
            rem = Array(repeating: true, count: permSize + 1)
            pk = Array(repeating: 0, count: permSize + 1)
        }

        /// Length of unit (row/column) `ndx`.
        func unitSize(_ ndx: Int) -> Int { p + (ndx <= q ? 1 : 0) }

        /// perm_table::get(r, c) of the plaintext table.
        func plainAt(_ r: Int, _ c: Int) -> Int {
            var x: Int
            if permDir == 0 {
                if readDir == 0 { x = (r <= q) ? r - 1 : q; x += (r - 1) * p + c }
                else { x = (c - 1) * permSize + r }
            } else {
                if readDir == 1 { x = (c <= q) ? c - 1 : q; x += (c - 1) * p + r }
                else { x = (r - 1) * permSize + c }
            }
            return plain[x - 1]
        }

        /// Element `i` of plaintext unit `px`.
        func unitElement(_ px: Int, _ i: Int) -> Int { permDir == 0 ? plainAt(px, i) : plainAt(i, px) }

        func compareLinear(_ px: Int, _ cx: Int) -> Bool {
            let l = unitSize(px)
            if size - cx < l - 1 { return false }
            for i in stride(from: 1, through: l, by: 1) where unitElement(px, i) != cipher[cx - 2 + i] { return false }
            return true
        }

        func compareScattered(_ px: Int, _ rx: Int, _ ur: Int) -> Bool {
            for i in stride(from: 1, through: unitSize(px), by: 1) {
                let pos = i > p ? p * permSize + ur : rx + (i - 1) * permSize
                if pos > size || unitElement(px, i) != cipher[pos - 1] { return false }
            }
            return true
        }

        /// found / found_s: first unused unit of the class (extra = the q longer units) that matches.
        /// `t` is the cipher position (linear) or `ur` (scattered).
        mutating func found(linear: Bool, t: Int, rank: Int, extra: Bool) -> Int {
            if extra && q == 0 { return 0 }
            let from = extra ? 1 : q + 1, to = extra ? q : permSize
            guard from <= to else { return 0 }
            for i in from...to where rem[i] {
                if linear ? compareLinear(i, t) : compareScattered(i, rank, t) {
                    pk[i] = rank
                    rem[i] = false
                    return i
                }
            }
            return 0
        }

        mutating func seekLinear(_ f: Int, _ t: Int, _ rank: Int) -> Bool {
            if f == 0 { return false }
            if t > size { return rank > permSize }
            if seekLinear(found(linear: true, t: t, rank: rank, extra: false), t + p, rank + 1) { return true }
            if seekLinear(found(linear: true, t: t, rank: rank, extra: true), t + p + 1, rank + 1) { return true }
            rem[f] = true
            return false
        }

        mutating func seekScattered(_ f: Int, _ rank: Int, _ ur: Int) -> Bool {
            if f == 0 { return false }
            if rank > permSize { return true }
            if seekScattered(found(linear: false, t: ur, rank: rank, extra: false), rank + 1, ur) { return true }
            if seekScattered(found(linear: false, t: ur, rank: rank, extra: true), rank + 1, ur + 1) { return true }
            rem[f] = true
            return false
        }

        /// automated_permanalysis::analyse – returns the key (pk[1…permSize]) or nil.
        mutating func run(linear: Bool) -> [Int]? {
            let ok = linear ? seekLinear(1, 1, 1) : seekScattered(1, 1, 1)
            return ok ? Array(pk[1...]) : nil
        }
    }
}
