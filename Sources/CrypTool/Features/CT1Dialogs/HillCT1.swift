import AppKit
import SwiftUI
import CTCommon
import CTClassic

// CT1 Hill: IDD_KEY_HILL5X5 / IDD_KEY_HILL_10X10 (KeyHillBase.cpp), "Hill-Optionen" (IDD_Hill_Options,
// DlgHillOptions.cpp), key string (CKeyHillBase::keyToStr), details window (CHillEncryption::OutputHillmatrix)
// and "Anzeige Hill-Schlüsselmatrix" (IDD_SHOW_KEY_HILL5x5).

/// Persistent "Weitere Hill-Optionen" (CT1 registry "Hill": OrdChrOffset, PaddingDefaultChr, PaddingOwnChr).
enum HillOptionsStore {
    private static let d = UserDefaults.standard
    static var offsetOne: Bool {
        get { d.bool(forKey: "ct1.hill.offset") }
        set { d.set(newValue, forKey: "ct1.hill.offset") }
    }
    static var useFirstCharForPadding: Bool {
        get { d.object(forKey: "ct1.hill.paddingDefault") as? Bool ?? true }
        set { d.set(newValue, forKey: "ct1.hill.paddingDefault") }
    }
    static var ownPaddingChar: String {
        get { d.string(forKey: "ct1.hill.paddingChar") ?? "" }
        set { d.set(newValue, forKey: "ct1.hill.paddingChar") }
    }

    /// Padding character for `HillCipher` (nil = CT1 default: character with number 0).
    static func paddingCharacter(alphabet: [Character]) -> Character? {
        guard !useFirstCharForPadding, let c = ownPaddingChar.first, alphabet.contains(c) else { return nil }
        return c
    }
}

/// CT1 Hill key string and helpers.
enum HillKey {
    /// "DIM 2, KEY: AB CD , ALPHABET: A…Z, ALPHABET_OFFSET: 0 MULTIPLICATION_VARIANT: 0 "
    static func string(numbers m: [[Int]], alphabet: [Character], offsetOne: Bool, multiplication: HillMultiplication) -> String {
        var s = "DIM \(m.count), KEY: "
        for row in m {
            for v in row { s.append(letter(v, alphabet: alphabet, offsetOne: offsetOne)) }
            s += " "
        }
        s += ", ALPHABET: " + String(alphabet)
        s += ", ALPHABET_OFFSET: \(offsetOne ? 1 : 0) "
        s += "MULTIPLICATION_VARIANT: \(multiplication == .matrixTimesVector ? 0 : 1) "
        return s
    }

    /// Letter of a Hill number (CKeyHillBase::chr).
    static func letter(_ v: Int, alphabet: [Character], offsetOne: Bool) -> Character {
        let n = alphabet.count
        let i = offsetOne ? ((v - 1) % n + n) % n : ((v % n) + n) % n
        return alphabet[i]
    }

    /// Hill number of a letter (CKeyHillBase::ord), nil if not in the alphabet.
    static func number(_ c: Character, alphabet: [Character], offsetOne: Bool) -> Int? {
        guard let i = alphabet.firstIndex(of: c) else { return nil }
        return (i + (offsetOne ? 1 : 0)) % alphabet.count
    }

    struct Parsed {
        var letters: [[Character]]
        var alphabet: [Character]
        var offsetOne: Bool
        var multiplication: HillMultiplication
    }

    /// Parses a CT1 key string (see `string`).
    static func parse(_ s: String) -> Parsed? {
        guard s.hasPrefix("DIM "), let comma = s.firstIndex(of: ","),
              let dim = Int(s[s.index(s.startIndex, offsetBy: 4)..<comma].trimmingCharacters(in: .whitespaces)),
              (1...10).contains(dim), let k = s.range(of: "KEY: ") else { return nil }
        let chars = Array(s[k.upperBound...])
        guard chars.count >= dim * (dim + 1) else { return nil }
        var rows: [[Character]] = []
        for r in 0..<dim { rows.append(Array(chars[(r * (dim + 1))..<(r * (dim + 1) + dim)])) }
        guard let a = s.range(of: ", ALPHABET: "), let o = s.range(of: ", ALPHABET_OFFSET:", options: .backwards),
              a.upperBound <= o.lowerBound else { return nil }
        let alphabet = Array(s[a.upperBound..<o.lowerBound])
        let rest = s[o.upperBound...]
        let offset = rest.trimmingCharacters(in: .whitespaces).first == "1"
        var mult = HillMultiplication.matrixTimesVector
        if let mv = rest.range(of: "MULTIPLICATION_VARIANT:") {
            mult = rest[mv.upperBound...].trimmingCharacters(in: .whitespaces).first == "1" ? .vectorTimesMatrix : .matrixTimesVector
        }
        return Parsed(letters: rows, alphabet: alphabet, offsetOne: offset, multiplication: mult)
    }
}

// MARK: - Key dialog

struct HillDialog: View {
    let document: CTDocument
    let close: () -> Void
    @EnvironmentObject var settings: AppSettings
    @CTState private var dim = 2
    @CTState private var large = false
    @CTState private var letters: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)
    @CTState private var numbers: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)
    @CTState private var editLetters = true
    @CTState private var multiplication: HillMultiplication = .matrixTimesVector
    @CTState private var details = false
    @CTState private var showOptions = false
    @CTState private var offsetOne = HillOptionsStore.offsetOne

    private var alphabet: [Character] { settings.textOptions.alphabetCharacters }
    private var n: Int { alphabet.count }

    // MARK: number <-> text
    private func fmt(_ v: Int) -> String {
        let shown = (offsetOne && v == 0) ? n : v
        return String(format: n > 100 ? "%03d" : "%02d", shown)
    }

    private func letterBinding(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: { letters[r][c] }, set: { new in
            let (f, rejected) = CT1KeyInput.filter(String(new.suffix(1)), alphabet: alphabet)
            if rejected { NSSound.beep() }
            letters[r][c] = f
            numbers[r][c] = f.first.flatMap { HillKey.number($0, alphabet: alphabet, offsetOne: offsetOne) }.map(fmt) ?? ""
        })
    }

    private func numberBinding(_ r: Int, _ c: Int) -> Binding<String> {
        Binding(get: { numbers[r][c] }, set: { new in
            let d = new.filter { $0.isASCII && $0.isNumber }
            if d.count != new.count { NSSound.beep() }
            let t = String(d.suffix(String(n).count))
            numbers[r][c] = t
            if let v = Int(t), v <= n, offsetOne || v < n {
                letters[r][c] = String(HillKey.letter(v, alphabet: alphabet, offsetOne: offsetOne))
            } else {
                letters[r][c] = ""
            }
        })
    }

    private func load(numbers m: [[Int]]) {
        dim = m.count
        if dim > 5 { large = true }
        for r in 0..<10 { for c in 0..<10 {
            if r < m.count, c < m.count {
                letters[r][c] = String(HillKey.letter(m[r][c], alphabet: alphabet, offsetOne: offsetOne))
                numbers[r][c] = fmt(((m[r][c] % n) + n) % n)
            } else { letters[r][c] = ""; numbers[r][c] = "" }
        } }
    }

    private func clearKey() {
        letters = Array(repeating: Array(repeating: "", count: 10), count: 10)
        numbers = letters
    }

    private func resyncNumbers() {
        for r in 0..<10 { for c in 0..<10 {
            numbers[r][c] = letters[r][c].first.flatMap { HillKey.number($0, alphabet: alphabet, offsetOne: offsetOne) }.map(fmt) ?? ""
        } }
    }

    /// Hill numbers of the key matrix, nil if a cell is empty/invalid.
    private var matrix: [[Int]]? {
        var m: [[Int]] = []
        for r in 0..<dim {
            var row: [Int] = []
            for c in 0..<dim {
                guard let ch = letters[r][c].first, let v = HillKey.number(ch, alphabet: alphabet, offsetOne: offsetOne) else { return nil }
                row.append(v)
            }
            m.append(row)
        }
        return m
    }

    private func grid(_ binding: @escaping (Int, Int) -> Binding<String>, editable: Bool) -> some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<dim, id: \.self) { r in
                GridRow {
                    ForEach(0..<dim, id: \.self) { c in
                        TextField("", text: binding(r, c))
                            .multilineTextAlignment(.center)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: dim > 5 ? 30 : 36)
                            .disabled(!editable)
                    }
                }
            }
        }
    }

    var body: some View {
        DialogScaffold(title: "Schlüsseleingabe: Hill", minWidth: dim > 5 ? 900 : 700) {
            CT1Group(title: "Beschreibung") {
                Text("Die Hill-Chiffre ist eine polygraphische Substitutionsverschlüsselung, die auf Linearer Algebra basiert. Dies war die erste polygraphische Substitutionsverschlüsselung, bei der man die Einzeloperationen auch praktikabel auf einer Gruppe von mehr als 3 Klartextbuchstaben (Blöcke) ausführen konnte. Der Schlüssel ist eine quadratische Matrix, deren Dimension dieser Blocklänge entspricht.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            CT1Group(title: "Informationen zur Verschlüsselung") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("Benutztes Alphabet (\(n) Zeichen)")
                        CT1ReadOnlyLine(text: String(alphabet))
                    }
                    Spacer()
                    Text("Wert des ersten Alphabetzeichens").multilineTextAlignment(.trailing).frame(width: 130)
                    Text(offsetOne ? "1" : "0").font(.system(.body, design: .monospaced)).padding(.top, 2)
                }
            }
            HStack(alignment: .top) {
                CT1Group(title: "Hill-Schlüsselmatrix") {
                    HStack {
                        VStack(alignment: .leading) {
                            CT1Radio(title: "Alphabetzeichen", selected: editLetters) { editLetters = true }
                            CT1Radio(title: "Zahlenwerte", selected: !editLetters) { editLetters = false }
                        }
                        Spacer()
                        CT1PasteKeyButton(method: "hill") { pasteKey($0) }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        GroupBox("Alphabetzeichen") { grid(letterBinding, editable: editLetters).padding(4) }
                        GroupBox("Zahlenwerte") { grid(numberBinding, editable: !editLetters).padding(4) }
                    }
                    Button("Zufälligen Schlüssel erzeugen") { load(numbers: HillCipher.randomKey(size: dim, modulus: n)) }
                        .frame(maxWidth: .infinity)
                    Button("Schlüssel zurücksetzen") { clearKey() }
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading) {
                    CT1Group(title: "Multiplikationsart") {
                        CT1Radio(title: "(Vektorreihe) * (Matrix)", selected: multiplication == .vectorTimesMatrix) { multiplication = .vectorTimesMatrix }
                        CT1Radio(title: "(Matrix) * (Vektorspalte)", selected: multiplication == .matrixTimesVector) { multiplication = .matrixTimesVector }
                    }
                    CT1Group(title: "Dimension") {
                        ForEach(Array(large ? 1...10 : 1...5), id: \.self) { d in
                            CT1Radio(title: "\(d) x \(d)", selected: dim == d) { dim = d }
                        }
                        Button(large ? "Kleinere Matrix" : "Größere Matrix") {
                            large.toggle()
                            if !large && dim > 5 { dim = 5 }
                        }
                    }
                }.frame(width: 190)
            }
            Toggle("Details und Zwischenschritte der Hill-Verschlüsselung ausgeben", isOn: $details)
        } buttons: {
            Button("Weitere Hill-Optionen") { showOptions = true }
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, textOptions: true, help: .hill)
        }
        .sheet(isPresented: $showOptions, onDismiss: {
            offsetOne = HillOptionsStore.offsetOne
            resyncNumbers()
        }) {
            HillOptionsSheet(alphabet: alphabet) { showOptions = false }
        }
    }

    private func pasteKey(_ s: String) {
        guard let p = HillKey.parse(s) else { return }
        dim = p.letters.count
        if dim > 5 { large = true }
        multiplication = p.multiplication
        for r in 0..<10 { for c in 0..<10 {
            if r < dim, c < dim {
                let ch = p.letters[r][c]
                letters[r][c] = alphabet.contains(ch) ? String(ch) : ""
            } else { letters[r][c] = "" }
        } }
        resyncNumbers()
    }

    // Kept for other features (Hill known-plaintext analysis) that write a plain matrix as key.
    static func format(_ m: [[Int]]) -> String { m.map { $0.map(String.init).joined(separator: " ") }.joined(separator: "; ") }

    static func parse(_ s: String) -> [[Int]]? {
        let rows = s.split(separator: ";").map { $0.split(separator: " ").compactMap { Int($0) } }
        guard !rows.isEmpty, rows.allSatisfy({ $0.count == rows.count }) else { return nil }
        return rows
    }

    private func run(_ encrypt: Bool) {
        guard let m = matrix else {
            Alerts.error(String(format: "Alle Felder der Schlüsselmatrix müssen ein erlaubtes Zeichen enthalten. Links sind nur Zeichen des eingestellten Alphabets erlaubt, rechts nur Zahlen zwischen %d und %d (für ein Alphabet von %d Zeichen).",
                                offsetOne ? 1 : 0, offsetOne ? n : n - 1, n), title: "Schlüssel nicht verwendbar")
            return
        }
        guard HillCipher.inverse(of: m, modulus: n) != nil else {
            Alerts.error(String(format: "Die eingegebene %@-Matrix kann modulo %d nicht invertiert werden. Deshalb kann sie für das Hill-Verfahren nicht verwendet werden. \nBitte ändern Sie entweder die Elemente der Matrix, die Dimension der Matrix oder die Anzahl der Elemente des Alphabets.\nAlternativ können Sie in der Hill-Schlüsseleingabe-Maske auch auf \"Zufälligen Schlüssel erzeugen\" klicken: Dann werden die Matrixelemente so gewählt, dass die Schlüsselmatrix für die eingestellte Dimension und die gegebene Alphabetlänge invertierbar ist.",
                                "\(dim)x\(dim)", n), title: "Schlüssel nicht verwendbar")
            return
        }
        let o = settings.textOptions
        let key = HillKey.string(numbers: m, alphabet: alphabet, offsetOne: offsetOne, multiplication: multiplication)
        do {
            let h = try HillCipher(matrix: m, options: o, multiplication: multiplication,
                                   paddingCharacter: HillOptionsStore.paddingCharacter(alphabet: alphabet),
                                   firstLetterIsOne: offsetOne)
            let input = document.text
            let result = encrypt ? h.encrypt(input) : h.decrypt(input)
            KeyMemory.remember(key, for: "hill")
            DocumentFactory.openResult(text: result, title: CT1.title("Hill", encrypt: encrypt, of: document, key: key),
                                       parent: document, method: "hill", key: key)
            if details {
                let plain = encrypt ? input : result
                let text = HillDetails.text(cipher: h, plaintext: plain)
                DocumentFactory.openResult(text: text, title: CT1.title("Details zur Hill", encrypt: encrypt, of: document, key: key),
                                           parent: document)
            }
            close()
        } catch {
            Alerts.error(error.localizedDescription)
        }
    }
}

/// "Hill-Optionen" (IDD_Hill_Options).
struct HillOptionsSheet: View {
    let alphabet: [Character]
    let close: () -> Void
    @CTState private var offsetOne = HillOptionsStore.offsetOne
    @CTState private var useFirst = HillOptionsStore.useFirstCharForPadding
    @CTState private var own = HillOptionsStore.ownPaddingChar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hill-Optionen").font(.title3.weight(.semibold))
            CT1Group(title: "Optionen zur Interpretation des Alphabetzeichens") {
                CT1Radio(title: "Wert des ersten Alphabetzeichens = 0 (z.B. \"A\"=0)", selected: !offsetOne) { offsetOne = false }
                CT1Radio(title: "Wert des ersten Alphabetzeichens = 1 (z.B. \"A\"=1)", selected: offsetOne) { offsetOne = true }
            }
            CT1Group(title: "Zeichen zum Auffüllen des Klartextes (falls nötig)") {
                HStack {
                    CT1Radio(title: "Erstes Zeichen im Alphabet verwenden (dies ist der Default)", selected: useFirst) { useFirst = true }
                    Spacer()
                    Text(alphabet.first.map(String.init) ?? "").font(.system(.body, design: .monospaced)).frame(width: 24)
                }
                HStack {
                    CT1Radio(title: "Zeichen selbst vergeben", selected: !useFirst) { useFirst = false }
                    Spacer()
                    TextField("", text: $own).frame(width: 30).multilineTextAlignment(.center).disabled(useFirst)
                        .ct1Filter($own) { s in
                            // DlgHillOptions::OnEnChangeEdit2: one character, upper-cased, must be in the alphabet
                            guard let c = s.last else { return ("", false) }
                            let u = Character(String(c).uppercased())
                            return alphabet.contains(u) ? (String(u), false) : ("", true)
                        }
                }
            }
            HStack {
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
                Button("OK") {
                    HillOptionsStore.offsetOne = offsetOne
                    HillOptionsStore.useFirstCharForPadding = useFirst
                    HillOptionsStore.ownPaddingChar = own.isEmpty ? String(alphabet.first ?? "A") : own
                    close()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 460)
    }
}

// MARK: - Details window (CHillEncryption::OutputHillmatrix, IDS_HILL_DUMP)

enum HillDetails {
    static let template = "Hill-Ver-/Entschlüsselung:\n\nDiese Detailbeschreibung der Hill-Verschlüsselung hat folgende Teile: \n 1. Alphabet-Codierung in Zahlen\n 2. Verschlüsselungsparameter und Eigenschaften\n 3. Hill-Verschlüsselung\n 4. Hill-Entschlüsselung\n \nDiese Log-Datei zeigt alle Ver-/Entschlüsselungs-Berechnungen mit der gegenwärtigen Hill Schlüssel-Matrix und den ersten Zeichen der gewählten Nachricht.\n\n\n1. Alphabet-Codierung in Zahlen:\n\nDas aktuell im Menü \"Optionen / Textoptionen\" gewählte Alphabet und dessen Codierung in Zahlen lautet:\n \n%ALPHABET_MAPPING%\n \nDas aktuelle Alphabet besteht aus %ALPHABET_SIZE% Zeichen. Der erste Alphabet-Buchstabe hat den Zahlenwert %ALPHABET_CODING_OFFSET%.\n\n\n2. Verschlüsselungsparameter und Eigenschaften:\n\nDie Ver- und Entschlüsselung ist unten beispielhaft durchgerechnet für die %HILL_DIMENSION% ersten Buchstaben aus dem Klartext, die zum Alphabet gehören.\n\nHier die Parameter der ausgewählten Hill-Verschlüsselung:\n  o Zur Ver- bzw. Entschlüsselung wird die Hill-Matrix mit einem %HILL_MULTIPLICATION_TYPE% multipliziert.\n  o Die gewählte Hill-Matrix hat die Dimension %HILL_DIMENSION%x%HILL_DIMENSION%.\n  o Der Klartext besteht aus %HILL_PLAINTEXT_SIZE% Buchstaben. Davon sind %HILL_NON_ALPHABET_CHARS% Nichtalphabetzeichen (Nichtalphabetzeichen werden ignoriert). Wenn das Alphabet nur Großbuchstaben enthält, werden die entsprechenden Kleinbuchstaben aber ebenfalls verschlüsselt; nicht umgekehrt.  Die Ver- und Entschlüsselung ist unten beispielhaft durchgerechnet für die %HILL_DIMENSION% ersten Buchstaben aus dem Klartext, die zum Alphabet gehören.\n \n\n3. Hill-Verschlüsselung:\n\nDie gewählte Hill-Matrix zum Verschlüsseln ist:\n \n%HILL_ENCRYPTION_TEXTMATRIX%\n \nDiese Matrix codiert in Zahlen:\n \n%HILL_ENCRYPTION_INTMATRIX%\n \nVerschlüsselung des Klartextes: \"%PLAINTEXT%\": \nKlartext(engl. Plaintext)-Vektor P codiert in Zahlen: %HILL_PLAINTEXT_VECTOR%\n \nBerechnung der Hill-Chiffrierung durch das %HILL_VECTOR_MATRIX_MULTTYPE% (der Vektor P[n] ist ein %HILL_VECTORTYPE%): \n%HILL_ENCRYPTION%\n \nDer Hill-Geheimtext lautet: \"%CIPHERTEXT%\". \n\n\n4. Hill-Entschlüsselung:\n\nDie inverse Hill-Matrix zum Entschlüsseln ist: \n%HILL_DECRYPTION_TEXTMATRIX%\n \nDiese Matrix codiert in Zahlen: \n%HILL_DECRYPTION_INTMATRIX%\n \nEntschlüsselung des Geheimtextes: \"%CIPHERTEXT%\": \nGeheimtext-Vektor C codiert in Zahlen: \n%HILL_CIPHERTEXT_VECTOR%\n \nBerechnung der Hill-Dechiffrierung durch das %HILL_VECTOR_MATRIX_MULTTYPE% (der Vektor C[n] ist ein %HILL_VECTORTYPE%): \n%HILL_DECRYPTION%\n \nDer Hill-Klartext lautet: \"%PLAINTEXT%\". \n\n\n"

    static func text(cipher h: HillCipher, plaintext: String) -> String {
        let alphabet = h.options.alphabetCharacters
        let n = alphabet.count, dim = h.size, off = h.firstLetterIsOne
        let left = h.multiplication == .vectorTimesMatrix
        func num(_ i: Int) -> String { String(format: n > 100 ? "%03i" : "%02i", i) }
        func pos(_ v: Int) -> Int { off && v == 0 ? n : v }
        func ch(_ v: Int) -> Character { HillKey.letter(v, alphabet: alphabet, offsetOne: off) }
        let enc = h.matrix, dec = h.inverseMatrix

        // first `dim` plaintext letters as Hill numbers (padded like the cipher)
        let idx = h.options.indices(of: plaintext)
        var p = idx.prefix(dim).map { (($0 + (off ? 1 : 0)) % n) }
        let padNumber = HillKey.number(h.paddingCharacter, alphabet: alphabet, offsetOne: off) ?? 0
        while p.count < dim { p.append(padNumber) }
        let plainExample = String(p.map(ch))

        var t = template
        t = t.replacingOccurrences(of: "%PLAINTEXT%", with: plainExample)

        // 1. alphabet mapping in 4 columns
        let floorRows = n / 4, remainder = n % 4
        var map = ""
        for i in 0...floorRows {
            if i == floorRows && remainder == 0 { break }
            var ndx = i
            map += "\t"
            for j in 0..<4 {
                if i == floorRows && j >= remainder { break }
                map += String(alphabet[ndx]) + " " + (off ? " --> " : " -->") + "\t" + num(ndx + (off ? 1 : 0)) + " \t"
                ndx += floorRows
                if j < remainder { ndx += 1 }
            }
            map += "\n"
        }
        t = t.replacingOccurrences(of: "%ALPHABET_MAPPING%", with: map)
        t = t.replacingOccurrences(of: "%ALPHABET_SIZE%", with: String(n))
        t = t.replacingOccurrences(of: "%ALPHABET_CODING_OFFSET%", with: off ? "1" : "0")
        t = t.replacingOccurrences(of: "%HILL_MULTIPLICATION_TYPE%", with: left ? "Zeilenvektor von links" : "Spaltenvektor von rechts")
        t = t.replacingOccurrences(of: "%HILL_VECTORTYPE%", with: left ? "Zeilenvektor" : "Spaltenvektor")
        t = t.replacingOccurrences(of: "%HILL_VECTOR_MATRIX_MULTTYPE%", with: left ? "Zeilen-Spalten Vektor-Matrixprodukt" : "Zeilen-Spalten Matrix-Vektorprodukt")
        t = t.replacingOccurrences(of: "%HILL_DIMENSION%", with: String(dim))
        t = t.replacingOccurrences(of: "%HILL_PLAINTEXT_SIZE%", with: String(plaintext.count))
        t = t.replacingOccurrences(of: "%HILL_NON_ALPHABET_CHARS%", with: String(plaintext.count - idx.count))

        func matrixText(_ label: String, _ m: [[Int]], numbers: Bool, transposed: Bool = false) -> String {
            var s = label
            for i in 0..<dim {
                s += i == 0 ? "\t[\t" : "\t\t\t[\t"
                for j in 0..<dim {
                    let v = transposed ? m[j][i] : m[i][j]
                    s += numbers ? num(pos(v)) + "\t" : String(ch(v)) + "\t"
                }
                s += "]\n"
            }
            return s
        }
        func vectorText(_ label: String, _ v: [Int]) -> String {
            label + v.map { num(pos($0)) + "\t" }.joined() + "]"
        }
        func products(_ m: [[Int]], _ v: [Int]) -> (lines: String, result: [Int]) {
            var lines = "", res: [Int] = []
            for i in 0..<dim {
                var c = 0
                for j in 0..<dim { c = (c + (left ? v[j] * m[j][i] : m[i][j] * v[j])) % n }
                res.append(c)
                lines += String(ch(c)) + "\t<--\t" + num(c) + " = "
                for j in 0..<dim {
                    lines += left ? num(v[j]) + "*" + num(pos(m[j][i])) + " " : num(pos(m[i][j])) + "*" + num(v[j]) + " "
                    if j < dim - 1 { lines += "+ " }
                }
                lines += " (mod " + num(n) + ")\n"
            }
            return (lines, res)
        }

        t = t.replacingOccurrences(of: "%HILL_ENCRYPTION_TEXTMATRIX%", with: matrixText("H[t] =", enc, numbers: false))
        t = t.replacingOccurrences(of: "%HILL_ENCRYPTION_INTMATRIX%", with: matrixText("H[n] =", enc, numbers: true))
        t = t.replacingOccurrences(of: "%HILL_PLAINTEXT_VECTOR%", with: vectorText("\n\nP[n] = \t[\t", p))
        let e = products(enc, p)
        t = t.replacingOccurrences(of: "%HILL_ENCRYPTION%", with: e.lines)
        t = t.replacingOccurrences(of: "%CIPHERTEXT%", with: String(e.result.map(ch)))
        t = t.replacingOccurrences(of: "%HILL_DECRYPTION_TEXTMATRIX%", with: matrixText("D[t] =", dec, numbers: false))
        t = t.replacingOccurrences(of: "%HILL_DECRYPTION_INTMATRIX%", with: matrixText("D[n] =", dec, numbers: true, transposed: left))
        t = t.replacingOccurrences(of: "%HILL_CIPHERTEXT_VECTOR%", with: vectorText("C[n] = \t[\t", e.result))
        let d = products(dec, e.result)
        t = t.replacingOccurrences(of: "%HILL_DECRYPTION%", with: d.lines)
        return t
    }
}

// MARK: - "Anzeige Hill-Schlüsselmatrix" (IDD_SHOW_KEY_HILL5x5 / 10x10)

struct HillKeyDisplay: View {
    let key: String
    let parsed: HillKey.Parsed
    let close: () -> Void
    @CTState private var inverse = false

    private var numbers: [[Int]] {
        parsed.letters.map { $0.map { HillKey.number($0, alphabet: parsed.alphabet, offsetOne: parsed.offsetOne) ?? 0 } }
    }
    private var shown: [[Int]]? {
        inverse ? HillCipher.inverse(of: numbers, modulus: parsed.alphabet.count) : numbers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anzeige Hill-Schlüsselmatrix").font(.title3.weight(.semibold))
            CT1Group(title: "Hill-Schlüsselmatrix") {
                if let m = shown {
                    let n = parsed.alphabet.count
                    HStack(alignment: .top, spacing: 16) {
                        CharMatrixView(matrix: m.map { $0.map { HillKey.letter($0, alphabet: parsed.alphabet, offsetOne: parsed.offsetOne) } })
                        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                            ForEach(m.indices, id: \.self) { r in
                                GridRow {
                                    ForEach(m[r].indices, id: \.self) { c in
                                        let v = m[r][c]
                                        Text(String(format: n > 100 ? "%03d" : "%02d", parsed.offsetOne && v == 0 ? n : v))
                                            .font(.system(.body, design: .monospaced))
                                            .frame(width: 32, height: 22)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Die Matrix ist nicht invertierbar.").foregroundStyle(.red)
                }
                CT1Radio(title: "Hill-Schlüsselmatrix (Verschlüsseln)", selected: !inverse) { inverse = false }
                CT1Radio(title: "Inverse Hill-Schlüsselmatrix (Entschlüsseln)", selected: inverse) { inverse = true }
            }
            HStack {
                Button("Schlüssel kopieren") { CT1KeyStore.shared.copy(key, method: "hill") }
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(minWidth: 420)
    }
}
