import CTCommon

// Port of CT1's manual Playfair analysis ("Analyse ▸ Symmetrische Verschlüsselung (klassisch) ▸
// Manuelle Analyse ▸ Playfair", PlayfairAnalysis.cpp / DlgPlayfairAnalysis.cpp):
//
// * letter graph built from the guessed plaintext ("Buchstabeninformationen": LROU, Nb?, Horizontal,
//   Vertikal, row or col?, Metrik) by Thomas Gauweiler's rules incl. CT1's consistency errors,
// * "Erzeuge Matrix": Peer Wichmann's constraint propagation / backtracking that reconstructs a
//   (partial) key matrix from the known digram pairs,
// * the three-line analysis display (Chiffrat / Eingabe / ermittelter Klartext) for the first
//   1000 characters, password ↔ matrix handling and the final decryption.
//
// Positions refer to the Unicode scalars of the ciphertext (CT1: bytes), so a CR LF line break
// occupies two positions as in CT1.

/// One row of CT1's "Buchstabeninformationen" table.
public struct PlayfairAnalysisLetterInfo: Identifiable, Equatable, Sendable {
    public var id: Character { letter }
    public let letter: Character
    /// "LROU": sure neighbours left, right, above (oben), below (unten); '*' = unknown.
    public let neighbours: String
    /// "Nb?": letters left or above / right or below.
    public let possibleNeighbours: String
    /// "Horizontal": X! sure in the row, X. row or below, X° row or above.
    public let horizontal: String
    /// "Vertikal": letters surely in the same column.
    public let vertical: String
    /// "row or col?": letters in the same row or the same column.
    public let rowOrColumn: String
    /// "Metrik": weight of the collected information.
    public let weight: Int
}

/// Consistency error of the guessed plaintext (CT1 `playfair_error`).
public struct PlayfairAnalysisGraphError: Error, Equatable, Sendable {
    /// CT1 error code (1, 2, 101…107, 113/114, 201…204).
    public let code: Int
    /// CT1 position value (as CT1 reports it: digram based for code 1/2, otherwise internal).
    public let position: Int
    public let letter: Character

    /// German message from CT1's string table (IDS_STRING_PLAYFAIR_ERRMSG…).
    public var message: String {
        let p = position + 1
        switch code {
        case 1:
            return "Bei Playfair sind Klarbuchstabe und Chiffrezeichen immer verschieden.\nPosition=\(p), Buchstabe=\(letter)"
        case 101...107:
            return "Fehler bei der Klartextanalyse !\nEine der Tabellen ist übergelaufen: Position=\(p), Buchstabe=\(letter).\nBitte korrigieren Sie die Eingabe."
        case 113, 114:
            return "Fehler bei der Klartextanalyse !\nZuordnungsfehler bei den Nachbarn: Position=\(p), Buchstabe=\(letter).\nBitte korrigieren Sie die Eingabe."
        case 201...204:
            return "Fehler bei der Klartextanalyse !\nEiner der Nachbarn war schon sicher: Position=\(p), Buchstabe=\(letter).\nBitte korrigieren Sie die Eingabe."
        default:
            return "Bei der Playfair-Analyse kam es zu einem Fehler in der Erstellung des Graphen.\n Position=\(p), Buchstabe=\(letter)"
        }
    }
}

/// State of CT1's Playfair analysis dialog (without the UI).
public final class PlayfairAnalysisSession {
    /// CT1 null element (unknown letter / empty matrix cell).
    public static let nullLetter: Character = "*"
    /// CT1 `MAXSHOWLETTER`: the dialog works on the first 1000 characters.
    public static let maxShowLetters = 1000

    /// Warning CT1 shows when the dialog is opened.
    public enum Warning: Equatable, Sendable {
        /// 'J' or digits in the ciphertext (IDS_STRING_PLAYFAIR_WARNMSG001).
        case possibly6x6
        /// Characters outside the Playfair alphabet (IDS_STRING_PLAYFAIR_WARNMSG002).
        case invalidCharacters

        public var message: String {
            switch self {
            case .possibly6x6:
                return "Da 'J' oder Ziffern im Chiffrat auftreten, könnte es sich um eine 6x6 Verschlüsselungsmatrix handeln."
            case .invalidCharacters:
                return "Das Chiffrat enthält auch Zeichen, die nicht zum Playfair-Alphabet gehören (alle Zeichen des Felds \"Analyseergebnis\"). Sie werden durch einen Punkt ausmaskiert."
            }
        }
    }

    /// CT1 IDS_STRING_PLAYFAIR_WARNMSG003.
    public static let invalidGuessLetterMessage = "Der Buchstabe 'J' und die Ziffern '0'-'9' dürfen bei einer 5x5 Matrix nicht verwendet werden. Verwenden Sie ggf. eine 6x6 Matrix."
    /// CT1 IDS_STRING_PLAYFAIR_NOMATRIX.
    public static let noMatrixMessage = "Keine passende Matrix gefunden."

    /// The ciphertext as Unicode scalars (CT1: bytes of the file).
    public let ciphertext: [Character]
    /// Warning detected when opening (nil: ciphertext consists of 5×5 Playfair letters only).
    public let warning: Warning?

    public private(set) var size: PlayfairCipher.Size
    /// Key matrix (rows); `nullLetter` marks unknown cells.
    public private(set) var matrix: [[Character]]
    /// Contents of CT1's "Passwort" field.
    public private(set) var password: String = ""
    /// CT1 checkbox "Doppelte wurden ignoriert" (repeated password letters are skipped; otherwise
    /// replaced by the next unused letter).
    public private(set) var ignoreDuplicateLetters = true
    /// Order of the letters in the "Buchstabeninformationen" table (sorted by weight by "Erzeuge Matrix").
    public private(set) var letterOrder: [Character]
    /// Second line of the analysis display before the first plaintext analysis (CT1 shows it empty).
    private var digramLetters: [Character]? = nil
    private var graph: LetterGraph

    // MARK: Setup

    /// Opens the analysis for a ciphertext (CT1 `InitListBox`): detects 'J'/digits (6×6 possible) and
    /// non-Playfair characters and chooses the matrix size like CT1.
    public init(ciphertext text: String) {
        ciphertext = text.unicodeScalars.map { Character($0) }
        var possible6 = false, invalid = false
        for ch in ciphertext.prefix(Self.maxShowLetters) where Self.letterIndex(ch, size: .fiveByFive) == nil {
            let u = Self.upper(ch)
            if u == "J" || ("0"..."9").contains(u) { possible6 = true } else { invalid = true }
        }
        warning = invalid ? .invalidCharacters : (possible6 ? .possibly6x6 : nil)
        size = (possible6 && !invalid) ? .sixBySix : .fiveByFive
        let d = size.dimension
        matrix = Array(repeating: Array(repeating: Self.nullLetter, count: d), count: d)
        letterOrder = size.alphabet
        graph = LetterGraph(letters: size.alphabet.count, setSize: d)
        // CT1 runs OnSechs (and therefore the plaintext analysis) only if a warning was shown
        if warning != nil { digramLetters = analyzeGuess([]).line }
    }

    /// CT1 "5x5 Matrix" / "6x6 Matrix" (`OnSechs`): clears password and matrix and re-analyses the guess.
    @discardableResult
    public func setSize(_ newSize: PlayfairCipher.Size, guess: String) -> GuessResult {
        size = newSize
        let d = newSize.dimension
        password = ""
        matrix = Array(repeating: Array(repeating: Self.nullLetter, count: d), count: d)
        letterOrder = newSize.alphabet
        return analyzePlaintext(guess)
    }

    // MARK: Password and matrix

    /// User input in the "Passwort" field (CT1 `OnUpdate`): upper case, accented letters converted,
    /// invalid characters removed (CT1 beeps); the matrix is built from the password.
    /// - Returns: false if characters had to be removed.
    @discardableResult
    public func setPassword(_ typed: String) -> Bool {
        var res: [Character] = []
        var ok = true
        for ch in typed {
            if let c = Self.replaceInvalid(ch), Self.letterIndex(c, size: size) != nil {
                res.append(c)
            } else {
                ok = false
            }
        }
        password = String(res.prefix(36))
        matrix = PlayfairCipher.makeMatrix(keyword: password, size: size, ignoreDuplicateKeyLetters: ignoreDuplicateLetters)
        return ok
    }

    /// CT1 checkbox "Doppelte wurden ignoriert": the password is applied again with the new rule.
    public func setIgnoreDuplicateLetters(_ flag: Bool) {
        ignoreDuplicateLetters = flag
        setPassword(password.filter { $0 != Self.nullLetter })
    }

    /// Input of `typed` into the matrix cell (row, column) (CT1 `CChEdit::OnChar`): the letter is
    /// written into the cell; if it already stood somewhere else, the old cell content moves there
    /// (swap). The password field then shows the matrix row by row.
    /// - Returns: false if the character is not part of the Playfair alphabet (CT1 beeps).
    @discardableResult
    public func setCell(row: Int, column: Int, to typed: Character) -> Bool {
        let d = size.dimension
        guard row >= 0, row < d, column >= 0, column < d else { return false }
        guard let c = Self.replaceInvalid(typed), Self.letterIndex(c, size: size) != nil else { return false }
        let old = matrix[row][column]
        if c == old { return true }
        var other: (Int, Int)? = nil
        for r in 0..<d { for k in 0..<d where matrix[r][k] == c { other = (r, k) } }
        matrix[row][column] = c
        if let (r, k) = other { matrix[r][k] = old }
        password = matrixString
        return true
    }

    /// Replaces the whole matrix (rows of letters or `nullLetter`); the password shows the matrix.
    public func setMatrix(_ rows: [[Character]]) {
        let d = size.dimension
        var m = Array(repeating: Array(repeating: Self.nullLetter, count: d), count: d)
        for r in 0..<min(d, rows.count) {
            for c in 0..<min(d, rows[r].count) {
                let ch = Self.upper(rows[r][c])
                m[r][c] = Self.letterIndex(ch, size: size) != nil ? ch : Self.nullLetter
            }
        }
        matrix = m
        password = matrixString
    }

    /// Matrix row by row (CT1 `CreatePassfromMatrix`, '*' for unknown cells).
    public var matrixString: String { String(matrix.flatMap { $0 }) }

    // MARK: Plaintext guess ("Vermuteter Klartext")

    /// Result of analysing the guessed plaintext.
    public struct GuessResult: Sendable {
        /// Consistency error (CT1 shows it in a message box).
        public var error: PlayfairAnalysisGraphError?
        /// The guess contains 'J' or digits although a 5×5 matrix is used (IDS_STRING_PLAYFAIR_WARNMSG003).
        public var containsInvalidLetters: Bool
    }

    /// CT1 `OnManAnalyse`: builds the digram assignments from the guess (aligned character by
    /// character with the ciphertext), shows them in line 2 and builds the letter graph.
    @discardableResult
    public func analyzePlaintext(_ guess: String) -> GuessResult {
        let g = Array(guess.unicodeScalars.prefix(Self.maxShowLetters)).map { Character($0) }
        var invalid = false
        if size == .fiveByFive {
            for ch in g where Self.letterIndex(ch, size: size) == nil {
                let u = Self.upper(ch)
                if u == "J" || ("0"..."9").contains(u) { invalid = true }
            }
        }
        let r = analyzeGuess(g)
        digramLetters = r.line
        return GuessResult(error: r.error, containsInvalidLetters: invalid)
    }

    /// The letter graph rows in table order.
    public var letterInfos: [PlayfairAnalysisLetterInfo] {
        let alpha = size.alphabet
        return letterOrder.compactMap { ch in
            guard let i = alpha.firstIndex(of: ch) else { return nil }
            return graph.info(i, alphabet: alpha)
        }
    }

    // MARK: "Erzeuge Matrix"

    /// CT1 "Erzeuge Matrix" (`CreateMatrixStandalone`, analysis by Peer Wichmann): reconstructs a
    /// key matrix that maps the ciphertext to the guess (pairs containing unknown letters are
    /// ignored). Unknown cells stay '*'. The letter table is sorted by weight and the password
    /// shows the matrix.
    /// - Returns: false if no matrix fulfils the guess (CT1 "Keine passende Matrix gefunden.").
    @discardableResult
    public func createMatrix(guess: String) -> Bool {
        sortLetterOrderByWeight()
        let d = size.dimension
        matrix = Array(repeating: Array(repeating: Self.nullLetter, count: d), count: d)
        defer { password = matrixString }
        let stip = Array(guess.unicodeScalars.prefix(Self.maxShowLetters)).map { Character($0) }
        // valid letters of ciphertext and guess (CT1 workaround: pairs with unknown letters dropped)
        var tmpCipher: [Character] = [], tmpPlain: [Character] = []
        var j = 0, skip = false
        while j < stip.count, j < ciphertext.count, tmpCipher.count <= Self.maxShowLetters + 1 {
            let c = Self.upper(ciphertext[j])
            if Self.letterIndex(c, size: size) != nil {
                if skip { skip = false; j += 1; continue }
                let p = Self.upper(stip[j])
                if Self.letterIndex(p, size: size) != nil {
                    if c == p { return false }   // plaintext letter = cipher letter: impossible
                    tmpCipher.append(c); tmpPlain.append(p)
                } else if tmpCipher.count % 2 == 1 {
                    tmpCipher.removeLast(); tmpPlain.removeLast()   // drop the whole pair
                } else {
                    skip = true                                     // drop the pair partner too
                }
            }
            j += 1
        }
        let pairs = tmpCipher.count / 2
        var data: [PlayfairAnalysisSearch.Pair] = []
        for k in 0..<pairs {
            data.append(.init(a1: wichmannIndex(tmpPlain[2 * k]), a2: wichmannIndex(tmpPlain[2 * k + 1]),
                              c1: wichmannIndex(tmpCipher[2 * k]), c2: wichmannIndex(tmpCipher[2 * k + 1])))
        }
        var search = PlayfairAnalysisSearch(n: d, data: data)
        if let m = search.run() {
            for r in 0..<d {
                for c in 0..<d {
                    let v = m[c * d + (d - 1 - r)]   // Wichmann: x = column, y = row counted from below
                    matrix[r][c] = v < 0 ? Self.nullLetter : size.alphabet[Int(v)]
                }
            }
        }
        // CT1 checks the matrix by decrypting the used ciphertext letters (DoCipher with stipulation)
        let out = decryptLetters(tmpCipher)
        let n = tmpPlain.count
        var k = 0
        while k < out.count {
            if k + 1 == n { return tmpPlain[k] == out[k] || out[k] == Self.nullLetter }
            if k + 1 >= out.count || tmpPlain[k] != out[k] || tmpPlain[k + 1] != out[k + 1] { return false }
            if k + 2 == n { return true }
            k += 2
        }
        return true
    }

    /// Reconstructs a key matrix from known plaintext/ciphertext digrams (letters only, aligned,
    /// even length). Convenience wrapper around "Erzeuge Matrix" used by tests and tools.
    public static func reconstructMatrix(plaintext: String, ciphertext: String, size: PlayfairCipher.Size = .fiveByFive) -> [[Character]]? {
        let s = PlayfairAnalysisSession(ciphertext: ciphertext)
        if s.size != size { s.setSize(size, guess: "") }
        s.analyzePlaintext(plaintext)
        return s.createMatrix(guess: plaintext) ? s.matrix : nil
    }

    // MARK: Analysis display

    /// The three lines of CT1's "Analyseergebnis" (first 1000 characters): ciphertext (non-Playfair
    /// characters as '.'), the digram assignments from the guess, the decryption with the matrix.
    public var analysisLines: (cipher: String, guess: String, plain: String) {
        let window = Array(ciphertext.prefix(Self.maxShowLetters))
        let dec = decryptLetters(window.compactMap { Self.letterIndex($0, size: size) != nil ? Self.upper($0) : nil })
        var l1 = "", l2 = "", l3 = ""
        var k = 0
        var l2Open = true
        let dig = digramLetters ?? []
        for ch in window {
            if Self.letterIndex(ch, size: size) != nil {
                l1.append(Self.upper(ch))
                if k < dig.count { if l2Open { l2.append(dig[k]) } } else { l2Open = false }   // C string ends
                l3.append(k < dec.count ? dec[k] : Self.nullLetter)
                k += 1
            } else {
                l1.append("."); l3.append(".")
                if l2Open { l2.append(".") }
            }
        }
        if digramLetters == nil { l2 = "" }
        return (l1, l2, l3)
    }

    /// Decryption of the first 1000 characters with the current matrix, aligned with the ciphertext
    /// ('.' for other characters, '*' for undecryptable letters) – CT1 writes it into "Vermuteter
    /// Klartext" when "Vermuteten Klartext anhand der Matrix aktualisieren" is set.
    public var expectedPlaintext: String { analysisLines.plain }

    /// CT1 "Ergebnis der Analyse ausgeben": the whole ciphertext reduced to Playfair letters
    /// (J → I for 5×5, accented letters converted, odd length padded with X) and decrypted with the
    /// matrix. Letters that are not in the matrix give '*'.
    public func decryptAll() -> String {
        var letters: [Character] = []
        for ch in ciphertext {
            if let c = Self.convertForCipher(ch, size: size), Self.letterIndex(c, size: size) != nil { letters.append(c) }
        }
        return String(decryptLetters(letters))
    }

    // MARK: - Internals

    /// Decrypts letter pairs (odd length: last letter paired with 'X', CT1 `DoCipher`).
    private func decryptLetters(_ letters: [Character]) -> [Character] {
        let d = size.dimension
        var pos: [Character: (Int, Int)] = [:]
        for r in 0..<d { for c in 0..<d where matrix[r][c] != Self.nullLetter { pos[matrix[r][c]] = (r, c) } }
        var out: [Character] = []
        out.reserveCapacity(letters.count + 1)
        var i = 0
        while i < letters.count {
            var a = letters[i], b: Character = i + 1 < letters.count ? letters[i + 1] : "X"
            if size == .fiveByFive { if a == "J" { a = "I" }; if b == "J" { b = "I" } }
            if let (r1, c1) = pos[a], let (r2, c2) = pos[b] {
                if r1 == r2 {
                    out.append(matrix[r1][(c1 + d - 1) % d]); out.append(matrix[r1][(c2 + d - 1) % d])
                } else if c1 == c2 {
                    out.append(matrix[(r1 + d - 1) % d][c1]); out.append(matrix[(r2 + d - 1) % d][c1])
                } else {
                    out.append(matrix[r1][c2]); out.append(matrix[r2][c1])
                }
            } else {
                out.append(Self.nullLetter); out.append(Self.nullLetter)
            }
            i += 2
        }
        return out
    }

    /// CT1 `playfair_digrammlist` + `AnalyseDigramme`: returns the second display line (plaintext
    /// letters of every cipher digram) and the first consistency error.
    private func analyzeGuess(_ guess: [Character]) -> (line: [Character], error: PlayfairAnalysisGraphError?) {
        let alpha = size.alphabet
        var letters: [Int: (Int, Int)] = [:]        // cipher digram → plaintext letters (-1 = unknown)
        var list: [Int] = []
        let charlen = min(Self.maxShowLetters, ciphertext.count)
        var j = 0, eol = false
        pairs: while list.count < charlen / 2 {
            var c = [Int](), p = [Int]()
            for _ in 0..<2 {
                var ci: Int? = nil
                var pi = -1
                repeat {
                    guard j < ciphertext.count else { break pairs }
                    ci = Self.letterIndex(ciphertext[j], size: size)
                    if j < guess.count { pi = Self.letterIndex(guess[j], size: size) ?? -1 } else { eol = true; pi = -1 }
                    j += 1
                } while ci == nil
                c.append(ci!); p.append(pi)
            }
            let key = c[0] * 64 + c[1]
            if letters[key] == nil { letters[key] = (-1, -1) }
            if !eol { letters[key] = (p[0], p[1]) }
            list.append(key)
        }
        var line: [Character] = []
        for key in list {
            let (p1, p2) = letters[key]!
            line.append(p1 >= 0 ? alpha[p1] : Self.nullLetter)
            line.append(p2 >= 0 ? alpha[p2] : Self.nullLetter)
        }
        graph = LetterGraph(letters: alpha.count, setSize: size.dimension)
        var visited = Set<Int>()
        do {
            for (i, key) in list.enumerated() {
                let (l1, l2) = letters[key]!
                if visited.contains(key) || l1 < 0 || l2 < 0 { continue }
                let c1 = key / 64, c2 = key % 64
                if l1 == c1 { throw LetterGraph.Failure(code: 1, position: 2 * i, letter: l1) }
                if l2 == c2 { throw LetterGraph.Failure(code: 1, position: 2 * i + 1, letter: l2) }
                if l1 == c2 {
                    try graph.insert(.rightOrBelow, l1, c1)
                    try graph.insert(.rightOrBelow, l2, c2)
                    if l2 == c1 { throw LetterGraph.Failure(code: 2, position: 2 * i, letter: l2) }
                } else if l2 == c1 {
                    try graph.insert(.rightOrBelow, l1, c1)
                    try graph.insert(.rightOrBelow, l2, c2)
                    if l1 == c2 { throw LetterGraph.Failure(code: 2, position: 2 * i, letter: l1) }
                } else {
                    try graph.insert(.rowOrBelow, l1, c1)
                    try graph.insert(.rowOrBelow, l2, c2)
                    try graph.insert(.rowOrCol, l1, c2)
                    try graph.insert(.rowOrCol, l2, c1)
                }
                visited.insert(key)
            }
        } catch let f as LetterGraph.Failure {
            let letter: Character = f.letter >= 0 && f.letter < alpha.count ? alpha[f.letter] : Self.nullLetter
            return (line, PlayfairAnalysisGraphError(code: f.code, position: f.position, letter: letter))
        } catch {
            return (line, nil)
        }
        return (line, nil)
    }

    /// CT1 `sortViaWeight` (selection sort, descending).
    private func sortLetterOrderByWeight() {
        let alpha = size.alphabet
        let w = letterOrder.map { ch in alpha.firstIndex(of: ch).map { graph.weight[$0] } ?? 0 }
        var order = letterOrder, weights = w
        for i in 0..<order.count {
            var maxW = weights[i], index = i
            for j in (i + 1)..<max(i + 1, order.count) where maxW < weights[j] { maxW = weights[j]; index = j }
            if index != i { order.swapAt(i, index); weights.swapAt(i, index) }
        }
        letterOrder = order
    }

    /// Index used by Wichmann's search (CT1 C2I): letter position in the size's alphabet.
    private func wichmannIndex(_ ch: Character) -> Int {
        size.alphabet.firstIndex(of: ch == "J" && size == .fiveByFive ? "I" : ch) ?? 0
    }

    /// Alphabet index of a character if it is a Playfair letter of the given size (CT1 `myisalpha2`;
    /// lower case accepted, 'J' only for 6×6).
    static func letterIndex(_ ch: Character, size: PlayfairCipher.Size) -> Int? {
        guard let v = ch.asciiValue else { return nil }
        var u = v
        if v >= 97 && v <= 122 { u = v - 32 }
        if u >= 65 && u <= 90 {
            if size == .fiveByFive {
                if u == 74 { return nil }
                return Int(u) - 65 - (u > 74 ? 1 : 0)
            }
            return Int(u) - 65
        }
        if u >= 48 && u <= 57 { return size == .sixBySix ? Int(u) - 48 + 26 : nil }
        return nil
    }

    static func upper(_ ch: Character) -> Character {
        if let v = ch.asciiValue, v >= 97, v <= 122 { return Character(Unicode.Scalar(v - 32)) }
        return ch
    }

    /// CT1 `CPlayfairAlphabet::replaceInvalidLetter(true, …)`: upper case, digits kept, accented
    /// letters to their base letter, everything else nil.
    static func replaceInvalid(_ ch: Character) -> Character? {
        let u = upper(ch)
        if let v = u.asciiValue {
            if (65...90).contains(v) || (48...57).contains(v) { return u }
            if v == 64 { return "A" }   // '@'
            return nil
        }
        return accentedBase(u)
    }

    /// CT1 `convertCharacterToPlayfair` (used for the final decryption).
    static func convertForCipher(_ ch: Character, size: PlayfairCipher.Size) -> Character? {
        var u = upper(ch)
        if size == .fiveByFive && u == "J" { u = "I" }
        if let v = u.asciiValue { return v == 64 ? "A" : u }
        return accentedBase(u)
    }

    private static func accentedBase(_ ch: Character) -> Character? {
        switch ch {
        case "À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "à", "á", "â", "ã", "ä", "å", "æ": return "A"
        case "Ç", "ç", "¢": return "C"
        case "Ð", "ð": return "D"
        case "È", "É", "Ê", "Ë", "è", "é", "ê", "ë", "€": return "E"
        case "Ì", "Í", "Î", "Ï", "ì", "í", "î", "ï": return "I"
        case "Ñ", "ñ": return "N"
        case "Ò", "Ó", "Ô", "Õ", "Ö", "Ø", "Œ", "ò", "ó", "ô", "õ", "ö", "ø": return "O"
        case "Š": return "S"
        case "Ù", "Ú", "Û", "Ü", "ù", "ú", "û", "ü": return "U"
        case "ÿ", "Ÿ", "¥", "Ý", "ý": return "Y"
        case "Ž": return "Z"
        default: return nil
        }
    }
}

// MARK: - Letter graph (CT1 playfair_letter, analysis by Thomas Gauweiler)

private struct LetterGraph {
    enum Kind { case rowSure, colSure, rightOrBelow, leftOrAbove, rowOrBelow, rowOrAbove, rowOrCol }
    enum Neighbour: Int { case above = 1, below = 2, left = 3, right = 4 }   // CT1 enum values
    struct Failure: Error { let code: Int; let position: Int; let letter: Int }

    // CT1 weights are octal literals (0120, 0050, 0030, 0040, 0005)
    static let weightNeighbour = 80, weightRowSure = 40, weightRow = 24, weightColSure = 32, weightCol = 5

    /// CT1 `my_maxsetsize` (= matrix dimension).
    let n: Int
    var left: [Int?], right: [Int?], above: [Int?], below: [Int?]
    var rightOrBelow: [[Int]], leftOrAbove: [[Int]], rowSure: [[Int]], colSure: [[Int]]
    var rowOrBelow: [[Int]], rowOrAbove: [[Int]], rowOrCol: [[Int]]
    var weight: [Int]

    init(letters: Int, setSize: Int) {
        n = setSize
        left = Array(repeating: nil, count: letters); right = left; above = left; below = left
        rightOrBelow = Array(repeating: [], count: letters)
        leftOrAbove = rightOrBelow; rowSure = rightOrBelow; colSure = rightOrBelow
        rowOrBelow = rightOrBelow; rowOrAbove = rightOrBelow; rowOrCol = rightOrBelow
        weight = Array(repeating: 0, count: letters)
    }

    /// CT1 `isinset` (respects the list limits).
    func contains(_ kind: Kind, _ me: Int, _ s: Int) -> Bool {
        switch kind {
        case .rowSure: return rowSure[me].prefix(n).contains(s)
        case .colSure: return colSure[me].prefix(n).contains(s)
        case .rightOrBelow: return rightOrBelow[me].prefix(2).contains(s)
        case .leftOrAbove: return leftOrAbove[me].prefix(2).contains(s)
        case .rowOrBelow: return rowOrBelow[me].prefix(n).contains(s)
        case .rowOrAbove: return rowOrAbove[me].prefix(n).contains(s)
        case .rowOrCol: return rowOrCol[me].prefix(2 * n).contains(s)
        }
    }

    /// CT1 `insert2set` with all implicit and explicit rules (same order of evaluation).
    mutating func insert(_ kind: Kind, _ me: Int, _ s: Int, _ pos: Int = -1) throws {
        if contains(kind, me, s) { return }
        switch kind {
        case .rowSure:
            if rowSure[me].count > n - 1 { throw Failure(code: 101, position: pos, letter: me) }
            rowSure[me].append(s); weight[me] += Self.weightRowSure
            try insert(.rowSure, s, me)
            try insert(.rowOrAbove, me, s)
            try insert(.rowOrBelow, me, s)
            try insert(.rowOrCol, me, s)
            var i = 0
            while i < rowSure[s].count {
                let x = rowSure[s][i]
                if x != me { try insert(.rowSure, me, x) }
                i += 1
            }
            if rowSure[me].count == n - 1 {
                i = 0
                while i < rowSure[me].count, i < rowOrAbove[me].count {
                    let x = rowOrAbove[me][i]
                    if !contains(.rowSure, me, x) { try setNeighbour(.above, me, x, pos) }
                    i += 1
                }
                i = 0
                while i < rowSure[me].count, i < rowOrBelow[me].count {
                    let x = rowOrBelow[me][i]
                    if !contains(.rowSure, me, x) { try setNeighbour(.below, me, x, pos) }
                    i += 1
                }
                i = 0
                while i < rowOrCol[me].count {
                    let x = rowOrCol[me][i]
                    if !contains(.rowSure, me, x) { try insert(.colSure, me, x, pos) }
                    i += 1
                }
            }
        case .colSure:
            if colSure[me].count > n - 1 { throw Failure(code: 102, position: pos, letter: me) }
            colSure[me].append(s); weight[me] += Self.weightColSure
            try insert(.colSure, s, me)
            try insert(.rowOrCol, me, s)
            var i = 0
            while i < colSure[s].count {
                let x = colSure[s][i]
                if x != me { try insert(.colSure, me, x) }
                i += 1
            }
        case .rightOrBelow:
            if rightOrBelow[me].count > 1 { throw Failure(code: 103, position: pos, letter: me) }
            rightOrBelow[me].append(s); weight[me] += Self.weightNeighbour
            try insert(.leftOrAbove, s, me)
            try insert(.rowOrCol, me, s)
            if rowSure[me].count == n - 1 && !contains(.rowSure, me, s) { try setNeighbour(.below, me, s, pos) }
            if contains(.colSure, me, s) {
                try setNeighbour(.below, me, s, pos)
                if rightOrBelow[me].count > 1 { try setNeighbour(.right, me, rightOrBelow[me][0], pos) }
                if contains(.rowOrAbove, me, s) { throw Failure(code: 113, position: pos, letter: me) }
            } else if contains(.rowOrAbove, me, s) {
                try setNeighbour(.right, me, s, pos)
                if rightOrBelow[me].count > 1 { try setNeighbour(.below, me, rightOrBelow[me][0], pos) }
            }
        case .leftOrAbove:
            if leftOrAbove[me].count > 1 { throw Failure(code: 104, position: pos, letter: me) }
            leftOrAbove[me].append(s); weight[me] += Self.weightNeighbour
            try insert(.rightOrBelow, s, me)
            try insert(.rowOrCol, me, s)
            if rowSure[me].count == n - 1 && !contains(.rowSure, me, s) { try setNeighbour(.above, me, s, pos) }
            if contains(.colSure, me, s) {
                try setNeighbour(.above, me, s, pos)
                if leftOrAbove[me].count > 1 { try setNeighbour(.left, me, leftOrAbove[me][0], pos) }
                if contains(.rowOrBelow, me, s) { throw Failure(code: 114, position: pos, letter: me) }
            } else if contains(.rowOrBelow, me, s) {
                try setNeighbour(.left, me, s, pos)
                if leftOrAbove[me].count > 1 { try setNeighbour(.above, me, leftOrAbove[me][0], pos) }
            }
        case .rowOrAbove:
            if rowOrAbove[me].count > n - 1 { throw Failure(code: 105, position: pos, letter: me) }
            rowOrAbove[me].append(s); weight[me] += Self.weightRow
            try insert(.rowOrBelow, s, me)
            try insert(.rowOrCol, me, s)
            if rowSure[me].count == n - 1 && !contains(.rowSure, me, s) { try setNeighbour(.above, me, s, pos) }
            if contains(.rightOrBelow, me, s) { try setNeighbour(.right, me, s, pos) }
            if contains(.rowOrBelow, me, s) { try insert(.rowSure, me, s) }
        case .rowOrBelow:
            if rowOrBelow[me].count > n - 1 { throw Failure(code: 106, position: pos, letter: me) }
            rowOrBelow[me].append(s); weight[me] += Self.weightRow
            try insert(.rowOrAbove, s, me)
            try insert(.rowOrCol, me, s)
            if rowSure[me].count == n - 1 && !contains(.rowSure, me, s) { try setNeighbour(.below, me, s, pos) }
            if contains(.leftOrAbove, me, s) { try setNeighbour(.left, me, s, pos) }
            if contains(.rowOrAbove, me, s) { try insert(.rowSure, me, s) }
        case .rowOrCol:
            if rowOrCol[me].count > 2 * n - 1 { throw Failure(code: 107, position: pos, letter: me) }
            rowOrCol[me].append(s); weight[me] += Self.weightCol
            try insert(.rowOrCol, s, me)
            if rowSure[me].count == n - 1 && !contains(.rowSure, me, s) { try insert(.colSure, me, s) }
        }
    }

    /// CT1 `setNeighbour` (note: CT1 passes the neighbour kind as position to the recursive call).
    mutating func setNeighbour(_ kind: Neighbour, _ me: Int, _ s: Int, _ lpos: Int) throws {
        switch kind {
        case .above:
            if let a = above[me] { if a != s { throw Failure(code: 201, position: lpos, letter: me) }; return }
            above[me] = s
            try setNeighbour(.below, s, me, kind.rawValue)
            weight[me] += Self.weightNeighbour
            try insert(.colSure, me, s)
        case .below:
            if let b = below[me] { if b != s { throw Failure(code: 202, position: lpos, letter: me) }; return }
            below[me] = s
            try setNeighbour(.above, s, me, kind.rawValue)
            weight[me] += Self.weightNeighbour
            try insert(.colSure, me, s)
        case .left:
            if let l = left[me] { if l != s { throw Failure(code: 203, position: lpos, letter: me) }; return }
            left[me] = s
            try setNeighbour(.right, s, me, kind.rawValue)
            weight[me] += Self.weightNeighbour
            try insert(.rowSure, me, s)
        case .right:
            if let r = right[me] { if r != s { throw Failure(code: 204, position: lpos, letter: me) }; return }
            right[me] = s
            try setNeighbour(.left, s, me, kind.rawValue)
            weight[me] += Self.weightNeighbour
            try insert(.rowSure, me, s)
        }
    }

    /// Table row (CT1 `getNeighboursString` … `getRoworcolString`, including CT1's index handling).
    func info(_ i: Int, alphabet a: [Character]) -> PlayfairAnalysisLetterInfo {
        let null = PlayfairAnalysisSession.nullLetter
        func ch(_ x: Int?) -> Character { x.map { a[$0] } ?? null }
        let lrou = String([ch(left[i]), ch(right[i]), ch(above[i]), ch(below[i])])
        var nb = leftOrAbove[i].prefix(2).map { String(a[$0]) }.joined(separator: ",")
        nb += "/" + rightOrBelow[i].prefix(2).map { String(a[$0]) }.joined(separator: ",")
        // getRowString: CT1 does not reset the index between the three lists
        var row: [Character] = []
        var j = 0
        while j < n && j < rowSure[i].count { row += [a[rowSure[i][j]], "!", ","]; j += 1 }
        while j < n && j < rowOrBelow[i].count {
            let c = a[rowOrBelow[i][j]]; j += 1
            if !row.contains(c) { row += [c, ".", ","] }
        }
        while j < n && j < rowOrAbove[i].count {
            let c = a[rowOrAbove[i][j]]; j += 1
            if !row.contains(c) { row += [c, "°", ","] }
        }
        if !row.isEmpty { row.removeLast() }
        let col = colSure[i].prefix(n).map { String(a[$0]) + "!" }.joined(separator: ",")
        let roc = rowOrCol[i].prefix(2 * n).map { String(a[$0]) }.joined(separator: ",")
        return PlayfairAnalysisLetterInfo(letter: a[i], neighbours: lrou, possibleNeighbours: nb, horizontal: String(row),
                                          vertical: col, rowOrColumn: roc, weight: weight[i])
    }
}

// MARK: - Matrix search (CT1 playfair_backtrace, analysis by Peer Wichmann)

/// Constraint propagation with backtracking. Coordinates as in CT1: x = column, y = row counted
/// from the bottom; plaintext → ciphertext moves right in a row and down (y − 1) in a column.
struct PlayfairAnalysisSearch {
    struct Pair { let a1: Int, a2: Int, c1: Int, c2: Int
        func contains(_ c: Int) -> Bool { c == a1 || c == a2 || c == c1 || c == c2 }
    }
    enum Signal: Error { case backtrack, success([Int16]), limit }

    let n: Int
    let size: Int
    let data: [Pair]
    let freq: [Int]
    /// Safety net (CT1 has none): number of search nodes before giving up.
    var nodeLimit = 200_000
    private var nodes = 0

    init(n: Int, data: [Pair]) {
        self.n = n
        size = n * n
        self.data = data
        var f = [Int](repeating: 0, count: n * n)
        for d in data { f[d.a1] += 1; f[d.a2] += 1; f[d.c1] += 1; f[d.c2] += 1 }
        freq = f
    }

    /// Cells `m[x * n + y]` (letter index or -1), nil if no matrix exists (or the limit was hit).
    mutating func run() -> [Int16]? {
        var c1 = -1, maxn = 0
        for i in 0..<size where maxn < freq[i] { c1 = i; maxn = freq[i] }
        guard c1 >= 0 else { return [Int16](repeating: -1, count: size) }
        var info = State(n: n)
        do {
            try test(c1, 0, 0, &info)
        } catch Signal.success(let m) {
            return m
        } catch {
            return nil
        }
        return nil
    }

    private mutating func test(_ ch: Int, _ x1: Int, _ y1: Int, _ info: inout State) throws {
        nodes += 1
        if nodes > nodeLimit { throw Signal.limit }
        try info.set(ch, x1, y1)
        while info.dirty {
            info.dirty = false
            for c in 0..<size {
                if !info.cDirty[c] { continue }
                info.cDirty[c] = false
                for d in data where d.contains(c) { try info.testRule(d) }
            }
        }
        var minn = Int.max, maxf = 0, c1 = -1
        for i in 0..<size where info.cSet[i] == -1 {
            let p = Int(info.cPossible[i])
            if minn > p { c1 = i; minn = p; maxf = freq[i] } else if minn == p && maxf < freq[i] { c1 = i; maxf = freq[i] }
        }
        if maxf == 0 { throw Signal.success(info.m) }
        for x in 0..<n {
            for y in 0..<n where info.p[(c1 * n + x) * n + y] != 0 {
                var next = info
                do {
                    try test(c1, x, y, &next)
                    return
                } catch Signal.backtrack {
                }
            }
        }
        throw Signal.backtrack
    }

    /// CT1 `playfair_arrinfo`.
    struct State {
        let n: Int
        let size: Int
        var p: [UInt8]          // p[(ch * n + x) * n + y]: ch possible at (x, y)
        var cPossible: [Int16]
        var cSet: [Int16]       // -1 or x + (y << 4)
        var cDirty: [Bool]
        var cellPossible: [Int16]
        var m: [Int16]
        var dirty = false
        var missing: Int

        init(n: Int) {
            self.n = n
            size = n * n
            p = [UInt8](repeating: 1, count: size * size)
            cPossible = [Int16](repeating: Int16(size), count: size)
            cSet = [Int16](repeating: -1, count: size)
            cDirty = [Bool](repeating: false, count: size)
            cellPossible = [Int16](repeating: Int16(size), count: size)
            m = [Int16](repeating: -1, count: size)
            missing = size
        }

        @inline(__always) func r(_ x: Int) -> Int { (x + n) % n }
        @inline(__always) func pos(_ ch: Int, _ x: Int, _ y: Int) -> Bool { p[(ch * n + x) * n + y] != 0 }

        mutating func disable(_ ch: Int, _ x: Int, _ y: Int) throws {
            let k = (ch * n + x) * n + y
            guard p[k] != 0 else { return }
            p[k] = 0
            cPossible[ch] -= 1
            if cPossible[ch] == 0 { throw Signal.backtrack }
            cDirty[ch] = true
            cellPossible[x * n + y] -= 1
            if cellPossible[x * n + y] == 1 {
                for i in 0..<size where p[(i * n + x) * n + y] != 0 {
                    try set(i, x, y)
                    break
                }
            }
            dirty = true
        }

        mutating func set(_ ch: Int, _ x1: Int, _ y1: Int) throws {
            if p[(ch * n + x1) * n + y1] == 0 { throw Signal.backtrack }
            if m[x1 * n + y1] == ch { return }
            cSet[ch] = Int16(x1 + (y1 << 4))
            m[x1 * n + y1] = Int16(ch)
            missing -= 1
            for i in 0..<size where i != ch { try disable(i, x1, y1) }
            for x in 0..<n { for y in 0..<n where x != x1 || y != y1 { try disable(ch, x, y) } }
            cDirty[ch] = true
            dirty = true
            if missing == 0 { throw Signal.success(m) }
        }

        mutating func forceColOrRow(_ ch: Int, _ x1: Int, _ y1: Int) throws {
            for x in 0..<n { for y in 0..<n where y != y1 && x != x1 { try disable(ch, x, y) } }
        }
        mutating func forceRowOrPos(_ ch: Int, _ y1: Int, _ x2: Int, _ y2: Int) throws {
            for x in 0..<n { for y in 0..<n where y != y1 && (x != x2 || y != y2) { try disable(ch, x, y) } }
        }
        mutating func forceColOrPos(_ ch: Int, _ x1: Int, _ x2: Int, _ y2: Int) throws {
            for x in 0..<n { for y in 0..<n where x != x1 && (x != x2 || y != y2) { try disable(ch, x, y) } }
        }
        mutating func forceCol(_ ch: Int, _ x1: Int) throws {
            for x in 0..<n where x != x1 { for y in 0..<n { try disable(ch, x, y) } }
        }

        /// CT1 `test_rule`: propagates one known digram pair.
        mutating func testRule(_ d: Pair) throws {
            let a1Set = cSet[d.a1] != -1, a2Set = cSet[d.a2] != -1, c1Set = cSet[d.c1] != -1, c2Set = cSet[d.c2] != -1
            let a1x = Int(cSet[d.a1] & 0x0f), a1y = Int(cSet[d.a1] >> 4)
            let a2x = Int(cSet[d.a2] & 0x0f), a2y = Int(cSet[d.a2] >> 4)
            let c1x = Int(cSet[d.c1] & 0x0f), c1y = Int(cSet[d.c1] >> 4)
            let c2x = Int(cSet[d.c2] & 0x0f), c2y = Int(cSet[d.c2] >> 4)
            if a1Set && a2Set {
                let c1px, c1py, c2px, c2py: Int
                if a1y == a2y { c1px = r(a1x + 1); c2px = r(a2x + 1); c1py = a1y; c2py = a1y }
                else if a1x == a2x { c1py = r(a1y - 1); c2py = r(a2y - 1); c1px = a1x; c2px = a1x }
                else { c1px = a2x; c1py = a1y; c2px = a1x; c2py = a2y }
                if c1Set && (c1px != c1x || c1py != c1y) { throw Signal.backtrack }
                if c2Set && (c2px != c2x || c2py != c2y) { throw Signal.backtrack }
                try set(d.c1, c1px, c1py)
                try set(d.c2, c2px, c2py)
                return
            }
            if c1Set && c2Set {
                let a1px, a1py, a2px, a2py: Int
                if c1y == c2y { a1px = r(c1x - 1); a2px = r(c2x - 1); a1py = c1y; a2py = c1y }
                else if c1x == c2x { a1py = r(c1y + 1); a2py = r(c2y + 1); a1px = c1x; a2px = c1x }
                else { a1px = c2x; a1py = c1y; a2px = c1x; a2py = c2y }
                if a1Set && (a1px != a1x || a1py != a1y) { throw Signal.backtrack }
                if a2Set && (a2px != a2x || a2py != a2y) { throw Signal.backtrack }
                try set(d.a1, a1px, a1py)
                try set(d.a2, a2px, a2py)
                return
            }
            if a1Set && c1Set {
                if a1x == c1x {
                    if a1y != r(c1y + 1) { throw Signal.backtrack }
                    try forceCol(d.a2, a1x)
                    try forceCol(d.c2, a1x)
                    for i in 0..<n {
                        if !pos(d.c2, a1x, i) { try disable(d.a2, a1x, r(i + 1)) }
                        else if !pos(d.a2, a1x, i) { try disable(d.c2, a1x, r(i - 1)) }
                    }
                    return
                }
                if c1y != a1y { throw Signal.backtrack }
                try forceColOrRow(d.c2, a1x, a1y)
                try forceColOrRow(d.a2, c1x, c1y)
                for i in 0..<n {
                    if !pos(d.c2, a1x, i) { try disable(d.a2, c1x, i) }
                    else if !pos(d.a2, c1x, i) { try disable(d.c2, a1x, i) }
                }
                if a1x == r(c1x - 1) {
                    for i in 0..<n {
                        if !pos(d.a2, i, a1y) { try disable(d.c2, r(i + 1), a1y) }
                        else if !pos(d.c2, i, a1y) { try disable(d.a2, r(i - 1), a1y) }
                    }
                }
                return
            }
            if a2Set && c2Set {
                if a2x == c2x {
                    if c2y != r(a2y - 1) { throw Signal.backtrack }
                    try forceCol(d.a1, a2x)
                    try forceCol(d.c1, a2x)
                    for i in 0..<n {
                        if !pos(d.c1, a2x, i) { try disable(d.a1, a2x, r(i + 1)) }
                        else if !pos(d.a1, a2x, i) { try disable(d.c1, a2x, r(i - 1)) }
                    }
                    return
                }
                if c2y != a2y { throw Signal.backtrack }
                try forceColOrRow(d.c1, a2x, a2y)
                try forceColOrRow(d.a1, c2x, c2y)
                for i in 0..<n {
                    if !pos(d.c1, a2x, i) { try disable(d.a1, c2x, i) }
                    else if !pos(d.a1, c2x, i) { try disable(d.c1, a2x, i) }
                }
                if a2x == r(c2x - 1) {
                    for i in 0..<n {
                        if !pos(d.a1, i, a2y) { try disable(d.c1, r(i + 1), a2y) }
                        else if !pos(d.c1, i, a2y) { try disable(d.a1, r(i - 1), a2y) }
                    }
                }
                return
            }
            if a1Set && c2Set {
                if d.a1 == d.c2 {   // "3 vertical" or "3 horizontal"
                    try forceRowOrPos(d.c1, a1y, a1x, r(a1y - 1))
                    try forceColOrPos(d.c1, a1x, r(a1x + 1), a1y)
                    try forceRowOrPos(d.a2, a1y, a1x, r(a1y + 1))
                    try forceColOrPos(d.a2, a1x, r(a1x - 1), a1y)
                    if !pos(d.a2, r(a1x - 1), a1y) { try disable(d.c1, r(a1x + 1), a1y) }
                    else if !pos(d.c1, r(a1x + 1), a1y) { try disable(d.a2, r(a1x - 1), a1y) }
                    if !pos(d.a2, a1x, r(a1y - 1)) { try disable(d.c1, a1x, r(a1y + 1)) }
                    else if !pos(d.c1, a1x, r(a1y + 1)) { try disable(d.a2, a1x, r(a1y - 1)) }
                    if pos(d.a2, r(a1x - 1), a1y) {
                        if pos(d.a2, a1x, r(a1y + 1)) { return }
                        try set(d.a2, r(a1x - 1), a1y)
                        try set(d.c1, r(a1x + 1), a1y)
                    } else {
                        if pos(d.a2, a1x, r(a1y + 1)) {
                            try set(d.a2, a1x, r(a1y + 1))
                            try set(d.c1, a1x, r(a1y - 1))
                        } else {
                            throw Signal.backtrack
                        }
                    }
                    return
                }
                if a1y == c2y {
                    try set(d.c1, r(a1x + 1), a1y)
                    try set(d.a2, r(c2x - 1), a1y)
                    return
                }
                if a1x != c2x { throw Signal.backtrack }
                try forceRowOrPos(d.c1, a1y, a1x, r(a1y - 1))
                try forceRowOrPos(d.a2, c2y, c2x, r(c2y + 1))
                for i in 0..<n {
                    if !pos(d.c1, i, a1y) { try disable(d.a2, i, c2y) }
                    else if !pos(d.a2, i, c2y) { try disable(d.c1, i, a1y) }
                }
                if !pos(d.c1, a1x, r(a1y - 1)) { try disable(d.a2, a1x, r(c2y + 1)) }
                else if !pos(d.a2, a1x, r(c2y + 1)) { try disable(d.c1, a1x, r(a1y - 1)) }
                return
            }
            if a2Set && c1Set {
                if d.a2 == d.c1 {
                    try forceRowOrPos(d.c2, a2y, a2x, r(a2y - 1))
                    try forceColOrPos(d.c2, a2x, r(a2x + 1), a2y)
                    try forceRowOrPos(d.a1, a2y, a2x, r(a2y + 1))
                    try forceColOrPos(d.a1, a2x, r(a2x - 1), a2y)
                    if !pos(d.a1, r(a2x - 1), a2y) { try disable(d.c2, r(a2x + 1), a2y) }
                    else if !pos(d.c2, r(a2x + 1), a2y) { try disable(d.a1, r(a2x - 1), a2y) }
                    if !pos(d.a1, a2x, r(a2y - 1)) { try disable(d.c2, a2x, r(a2y + 1)) }
                    else if !pos(d.c2, a2x, r(a2y + 1)) { try disable(d.a1, a2x, r(a2y - 1)) }
                    if pos(d.a1, r(a2x - 1), a2y) {
                        if pos(d.a1, a2x, r(a2y + 1)) { return }
                        try set(d.a1, r(a2x - 1), a2y)
                        try set(d.c2, r(a2x + 1), a2y)
                    } else {
                        if pos(d.a1, a2x, r(a2y + 1)) {
                            try set(d.a1, a2x, r(a2y + 1))
                            try set(d.c2, a2x, r(a2y - 1))
                        } else {
                            throw Signal.backtrack
                        }
                    }
                    return
                }
                if a2y == c1y {
                    try set(d.c2, r(a2x + 1), a2y)
                    try set(d.a1, r(c1x - 1), c1y)
                    return
                }
                if a2x != c1x { throw Signal.backtrack }
                try forceRowOrPos(d.c2, a2y, a2x, r(a2y - 1))
                try forceRowOrPos(d.a1, c1y, c1x, r(c1y + 1))
                for i in 0..<n {
                    if !pos(d.c2, i, a2y) { try disable(d.a1, i, c1y) }
                    else if !pos(d.a1, i, c1y) { try disable(d.c2, i, a2y) }
                }
                if !pos(d.c2, a2x, r(a2y - 1)) { try disable(d.a1, a2x, r(c1y + 1)) }
                else if !pos(d.a1, a2x, r(c1y + 1)) { try disable(d.c2, a2x, r(a2y - 1)) }
                return
            }
            if a1Set {
                try forceRowOrPos(d.c1, a1y, a1x, r(a1y - 1))
                try forceColOrRow(d.c2, a1x, a1y)
                return
            }
            if a2Set {
                try forceRowOrPos(d.c2, a2y, a2x, r(a2y - 1))
                try forceColOrRow(d.c1, a2x, a2y)
                return
            }
            if c1Set {
                try forceRowOrPos(d.a1, c1y, c1x, r(c1y + 1))
                try forceColOrRow(d.a2, c1x, c1y)
                return
            }
            if c2Set {
                try forceRowOrPos(d.a2, c2y, c2x, r(c2y + 1))
                try forceColOrRow(d.a1, c2x, c2y)
            }
        }
    }
}
