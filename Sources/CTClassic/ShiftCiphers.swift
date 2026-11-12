import CTCommon

// MARK: - Caesar / ROT13

/// Caesar cipher (CT1 "Caesar / ROT-13"): every alphabet letter is shifted by a fixed distance
/// within the alphabet of the text options. Non-alphabet characters and case are handled as
/// configured in `TextOptions`.
public enum Caesar {
    /// Encrypts by shifting each letter `shift` positions forward (modulo the alphabet size).
    public static func encrypt(_ text: String, shift: Int, options: TextOptions) -> String {
        LetterMapper(options).mapLetters(text) { i, _ in i + shift }
    }

    /// Decrypts by shifting each letter `shift` positions backward.
    public static func decrypt(_ text: String, shift: Int, options: TextOptions) -> String {
        LetterMapper(options).mapLetters(text) { i, _ in i - shift }
    }

    /// Shift distance for a key letter as in CT1: the alphabet index of the letter (A = 0), or
    /// index + 1 if `firstLetterIsOne` (A = 1, …, Z = 26 ≡ 0). If the letter is not part of the
    /// alphabet, its upper- and lowercase forms are tried (like CT1). Returns nil if not found.
    public static func shift(forKeyLetter letter: Character, options: TextOptions, firstLetterIsOne: Bool) -> Int? {
        let chars = options.alphabetCharacters
        guard !chars.isEmpty else { return nil }
        var idx = chars.firstIndex(of: letter)
        if idx == nil, let up = String(letter).uppercased().first, String(letter).uppercased().count == 1 { idx = chars.firstIndex(of: up) }
        if idx == nil, let low = String(letter).lowercased().first, String(letter).lowercased().count == 1 { idx = chars.firstIndex(of: low) }
        guard let i = idx else { return nil }
        return firstLetterIsOne ? (i + 1) % chars.count : i
    }

    /// Key letter that corresponds to a numeric shift (inverse of `shift(forKeyLetter:…)`).
    public static func keyLetter(forShift shift: Int, options: TextOptions, firstLetterIsOne: Bool) -> Character? {
        let chars = options.alphabetCharacters
        guard !chars.isEmpty else { return nil }
        let i = mod(firstLetterIsOne ? shift - 1 : shift, chars.count)
        return chars[i]
    }

    /// ROT13 as in CT1: shift by half the alphabet size (only defined for alphabets of even size;
    /// for odd sizes the text is shifted by ⌊n/2⌋ which is not self-inverse).
    public static func rot13(_ text: String, options: TextOptions = .default) -> String {
        encrypt(text, shift: options.alphabetSize / 2, options: options)
    }

    /// True if ROT13 is available for these options (CT1 requires an even alphabet size).
    public static func isROT13Available(options: TextOptions) -> Bool {
        let n = options.alphabetSize
        return n > 0 && n % 2 == 0
    }

    /// The target ("shifted") alphabet displayed in CT1's Caesar dialog.
    public static func targetAlphabet(shift: Int, options: TextOptions) -> String {
        let chars = options.alphabetCharacters
        guard !chars.isEmpty else { return "" }
        return String((0..<chars.count).map { chars[mod($0 + shift, chars.count)] })
    }
}

// MARK: - Vigenère

/// Vigenère cipher (CT1 semantics: key characters not contained in the alphabet are ignored, the
/// key only advances on alphabet letters of the text, key letter A means shift 0).
public enum Vigenere {
    /// Alphabet indices of the usable key characters; throws if none are left.
    public static func keyShifts(_ key: String, options: TextOptions) throws -> [Int] {
        let k = LetterMapper(options).indices(of: key)
        guard !k.isEmpty else {
            throw CTError("Der Schlüssel enthält keine Zeichen des eingestellten Alphabets.")
        }
        return k
    }

    /// Encrypts: letter i is shifted by key letter (i mod key length); throws if the key is empty.
    public static func encrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        let k = try keyShifts(key, options: options)
        return LetterMapper(options).mapLetters(text) { i, p in i + k[p % k.count] }
    }

    /// Decrypts (inverse of `encrypt`).
    public static func decrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        let k = try keyShifts(key, options: options)
        return LetterMapper(options).mapLetters(text) { i, p in i - k[p % k.count] }
    }
}

/// Vigenère with autokey: the key is followed by the plaintext itself (not part of CT1, extra).
public enum VigenereAutokey {
    /// Encrypts with the key followed by the plaintext letters as running key.
    public static func encrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        let m = LetterMapper(options)
        var k = try Vigenere.keyShifts(key, options: options)
        let plain = m.indices(of: text)
        k.append(contentsOf: plain)
        return m.mapLetters(text) { i, p in i + k[p] }
    }

    /// Decrypts (the recovered plaintext extends the running key).
    public static func decrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        let m = LetterMapper(options)
        var k = try Vigenere.keyShifts(key, options: options)
        let n = m.size
        return m.mapLetters(text) { i, p in
            let plain = mod(i - k[p], n)
            k.append(plain)
            return plain
        }
    }
}

/// Beaufort cipher: c = k − p (modulo the alphabet size). Encryption and decryption are identical.
public enum Beaufort {
    /// Encrypts (c = k − p); throws if the key contains no alphabet characters.
    public static func encrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        let k = try Vigenere.keyShifts(key, options: options)
        return LetterMapper(options).mapLetters(text) { i, p in k[p % k.count] - i }
    }

    /// Decrypts (identical to `encrypt`).
    public static func decrypt(_ text: String, key: String, options: TextOptions) throws -> String {
        try encrypt(text, key: key, options: options)
    }
}

/// Affine cipher c = a·p + b (modulo the alphabet size n); `a` must be coprime to n.
public enum Affine {
    /// Throws a German error message if `a` is not invertible modulo the alphabet size.
    public static func validate(a: Int, options: TextOptions) throws {
        let n = options.alphabetSize
        guard n > 0 else { throw CTError("Das Alphabet ist leer.") }
        guard modInverse(a, n) != nil else {
            throw CTError("Der Faktor a = \(a) ist nicht teilerfremd zur Alphabetlänge \(n) und daher nicht umkehrbar.")
        }
    }

    /// Encrypts c = a·p + b.
    public static func encrypt(_ text: String, a: Int, b: Int, options: TextOptions) throws -> String {
        try validate(a: a, options: options)
        return LetterMapper(options).mapLetters(text) { i, _ in a * i + b }
    }

    /// Decrypts p = a⁻¹·(c − b).
    public static func decrypt(_ text: String, a: Int, b: Int, options: TextOptions) throws -> String {
        try validate(a: a, options: options)
        let n = options.alphabetSize
        let inv = modInverse(a, n)!
        return LetterMapper(options).mapLetters(text) { i, _ in inv * mod(i - b, n) }
    }
}
