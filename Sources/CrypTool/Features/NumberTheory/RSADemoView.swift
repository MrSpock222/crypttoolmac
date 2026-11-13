import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 "RSA-Demo" (IDD_RSA_DEMO, CDlgRSADemo): RSA with own primes or only with the public key,
/// step-by-step en-/decryption of text or numbers in four labelled fields.
struct RSADemoView: View {
    /// Kept for the router; CT1 starts with an empty input field.
    var initialText: String = ""

    @StateObject private var ref = CT1WindowRef()
    @CTState private var publicOnly = false
    @CTState private var pText = ""
    @CTState private var qText = ""
    @CTState private var nText = ""
    @CTState private var eText = "2^16+1"
    @CTState private var phiText = ""
    @CTState private var dText = ""
    @CTState private var asNumbers = false
    @CTState private var options = RSADemoOptions()
    @CTState private var input = ""
    @CTState private var hInput = ""
    @CTState private var h1 = ""
    @CTState private var h2 = ""
    @CTState private var h3 = ""
    @CTState private var s1 = ""
    @CTState private var s2 = ""
    @CTState private var s3 = ""
    // key status (CT1 KeyStatus…)
    @CTState private var modulus: BigUInt?
    @CTState private var pubE: BigUInt?
    @CTState private var privD: BigUInt?
    @CTState private var pValid = false
    @CTState private var qValid = false
    @CTState private var didInit = false
    /// Input as processed by the last en-/decryption (programmatic changes must not clear the steps).
    @CTState private var lastRunInput = ""

    private static let prefKey = "RSADemo"

    private var optionsValid: Bool { modulus != nil && pubE != nil && options.alphabetFits(modulus) }
    private var inputValid: Bool { !input.isEmpty }
    private var canEncrypt: Bool {
        publicOnly ? (inputValid && optionsValid) : (pValid && qValid && inputValid && optionsValid)
    }
    private var canDecrypt: Bool { !publicOnly && pValid && qValid && privD != nil && inputValid && optionsValid }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox("RSA using the private and public key -- or using only the public key") {
                VStack(alignment: .leading, spacing: 6) {
                    NTRadio(title: "Choose two prime numbers p and q. The composite number N = pq is the public RSA modulus, and phi(N) = (p-1)(q-1) is the Euler totient. The public key e is freely chosen but must be coprime to the totient. The private key d is then calculated such that d = e^(-1) (mod phi(N)).",
                            selected: !publicOnly) { setMode(publicOnly: false) }
                    NTRadio(title: "For data encryption or certificate verification, you will only need the public RSA parameters: the modulus N and the public key e.",
                            selected: publicOnly) { setMode(publicOnly: true) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox(publicOnly ? "Factorization attack" : "Prime number entry") {
                HStack(alignment: .top) {
                    if publicOnly {
                        Text("You may try to resolve the RSA modulus N into its prime factors p and q.")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Grid(alignment: .leading, verticalSpacing: 4) {
                            GridRow { Text("Prime number p").frame(width: 150, alignment: .leading); field($pText) }
                            GridRow { Text("Prime number q"); field($qText) }
                        }
                    }
                    Button(publicOnly ? "Factorize RSA modulus..." : "Generate prime numbers...", action: generateOrFactor)
                        .frame(width: 190)
                }.padding(4)
            }
            GroupBox("RSA parameters") {
                Grid(alignment: .leading, verticalSpacing: 4) {
                    GridRow {
                        Text("RSA modulus N").frame(width: 150, alignment: .leading)
                        if publicOnly { field($nText) } else { NTReadOnlyText(text: nText) }
                        Text("(public)").foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text("phi(N) = (p-1)(q-1)")
                        NTReadOnlyText(text: phiText)
                        Text("(secret)").foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text("Public key e")
                        field($eText)
                        Text("")
                    }
                    GridRow {
                        Text("Private key d")
                        NTReadOnlyText(text: dText)
                        Button("Update parameters", action: updateParameters)
                    }
                }.padding(4)
            }
            GroupBox("RSA encryption using e / decryption using d  [alphabet size: \(options.alphabetSize)]") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Input as")
                        NTRadio(title: "text", selected: !asNumbers) { setInputMode(numbers: false) }
                        NTRadio(title: "numbers", selected: asNumbers) { setInputMode(numbers: true) }
                        Spacer()
                        Button("Alphabet and number system options...", action: showOptions)
                            .disabled(publicOnly || !(pValid && qValid))
                    }
                    Text(hInput).font(.callout).foregroundStyle(.secondary)
                    TextField("", text: $input, axis: .vertical).lineLimit(1...3)
                        .font(.system(.body, design: .monospaced))
                    Text(h1).font(.callout).foregroundStyle(.secondary)
                    NTStepBox(text: s1)
                    Text(h2).font(.callout).foregroundStyle(.secondary)
                    NTStepBox(text: s2)
                    Text(h3).font(.callout).foregroundStyle(.secondary)
                    NTStepBox(text: s3)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("Encrypt", action: encrypt).disabled(!canEncrypt)
                Button("Decrypt", action: decrypt).disabled(!canDecrypt)
                Spacer()
                CT1HelpButton(action: .rsaDemo)
                Button("Close") { ref.window?.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 720)
        .ct1Window(title: "RSA Demonstration", ref: ref)
        .onAppear(perform: initialize)
        .onDisappear(perform: saveState)
        .onChange(of: pText) { _, v in filterThenCheck($pText, v) }
        .onChange(of: qText) { _, v in filterThenCheck($qText, v) }
        .onChange(of: eText) { _, v in filterThenCheck($eText, v) }
        .onChange(of: nText) { _, v in if publicOnly { filterThenCheck($nText, v) } }
        .onChange(of: input) { _, v in if v != lastRunInput { requestForInput(clear: false) } }
    }

    private func field(_ b: Binding<String>) -> some View {
        TextField("", text: b).font(.system(.body, design: .monospaced))
    }

    // MARK: Parameters

    private func filterThenCheck(_ b: Binding<String>, _ v: String) {
        let f = String(v.filter { "0123456789+-*^()".contains($0) })
        if f != v { b.wrappedValue = f; return }
        checkParameters()
        requestForInput(clear: false)
    }

    /// CT1 `CheckRSAParameter` (live, without messages).
    private func checkParameters() {
        if publicOnly {
            let n = ntEvaluate(nText).value, e = ntEvaluate(eText).value
            if let n, let e, e > 1, n > 2 { modulus = n; pubE = e } else { modulus = nil; pubE = nil }
            privD = nil; pValid = false; qValid = false
        } else {
            let p = ntEvaluate(pText).value, q = ntEvaluate(qText).value
            // CT1 InitParameter: p and q are valid only together (both prime, distinct, N < 2^8192)
            if let p, let q, p >= 2, q >= 2, p != q, p.bitLength + q.bitLength - 1 <= CT1BigNumber.maxBits,
               Primality.isProbablePrime(p), Primality.isProbablePrime(q) {
                pValid = true; qValid = true
                let n = p * q, phi = (p - 1) * (q - 1)
                modulus = n; nText = n.description; phiText = phi.description
                if let e = ntEvaluate(eText).value, e > 1, e.gcd(phi) == 1, let d = e.inverse(modulo: phi) {
                    pubE = e; privD = d; dText = d.description
                } else {
                    pubE = nil; privD = nil; dText = ""
                }
            } else {
                pValid = false; qValid = false
                modulus = nil; pubE = nil; privD = nil
                nText = ""; phiText = ""; dText = ""
            }
        }
        // CT1 SetDlgOptions(TRUE): the block length is reset to its maximum
        options.blockLength = options.maxBlockLength(modulus: modulus)
    }

    /// "Parameter aktualisieren" (CT1 `OnButtonUpdateRSAParameter` with its messages).
    private func updateParameters() {
        let fields = publicOnly ? [nText, eText] : [pText, qText, eText]
        for f in fields where (try? BigExpression.evaluate(f)) == nil {
            Alerts.error(NTMessages.inputFalse); checkParameters(); return
        }
        if !publicOnly {
            let p = ntEvaluate(pText), q = ntEvaluate(qText)
            if p.value == nil { Alerts.info(p.error ?? NTMessages.bigNumber); return }
            if q.value == nil { Alerts.info(q.error ?? NTMessages.bigNumber); return }
            let pp = p.value!, qq = q.value!
            let pPrime = pp >= 2 && Primality.isProbablePrime(pp), qPrime = qq >= 2 && Primality.isProbablePrime(qq)
            if !pPrime && !qPrime { Alerts.info("p and q are NO prime numbers !"); checkParameters(); return }
            if !pPrime { Alerts.info("The input for p is not a prime number !"); checkParameters(); return }
            if !qPrime { Alerts.info("The input for q is not a prime number !"); checkParameters(); return }
            if pp == qq { Alerts.info("The prime numbers p and q must be different!"); checkParameters(); return }
            if pp.bitLength + qq.bitLength - 1 > CT1BigNumber.maxBits {
                Alerts.error("The demonstration supports only positive integers of bit length smaller than 8192.\nThe bit length of the actually generated RSA modul exceeds 8192.\nPlease select primes p and q, whereby the RSA modul N = p*q is smaller than 2^8192.")
                return
            }
            checkParameters()
            if privD == nil {
                let a = NSAlert()
                a.messageText = "CrypTool"
                a.informativeText = "The parameter e (\(eText)) is not coprime to phi(N) (\(phiText)). Either a fixed public key is used (here: 2^16+1), or a new key is generated. Do you want to generate a new public key?"
                a.addButton(withTitle: "Yes"); a.addButton(withTitle: "No")
                if a.runModal() == .alertFirstButtonReturn {
                    // CT1 calculateSmallestE: smallest e > 1 coprime to phi(N)
                    let phi = (pp - 1) * (qq - 1)
                    var e = BigUInt(2)
                    while e.gcd(phi) != 1 { e += 1 }
                    eText = e.description
                } else {
                    eText = "2^16+1"
                }
                checkParameters()
                return
            }
        } else {
            checkParameters()
        }
        if modulus != nil {
            if options.blockLength != 0 && options.alphabetFits(modulus) {
                CT1Prefs.set(Self.prefKey + ".secret", "\(pText);\(qText);\(eText)")
            } else {
                modulusTooSmallMessage()
            }
        }
        requestForInput(clear: false)
    }

    private func modulusTooSmallMessage() {
        let a = options.alphabetSize, n = nText
        if !asNumbers {
            Alerts.error("The number of characters in the alphabet (here \(a) letters) must be smaller or equal to the size of the RSA modul (here N = \(n)).\nPlease modify the alphabet in the \"Text Options\" dialog or choose larger prime numbers.")
        } else {
            Alerts.error("The RSA encryption of numbers into text is incorrect, since the number of characters in the alphabet (here \(a)) is larger than the size of the RSA modul (here N=\(n)). Please modify the alphabet in \"options for alphabet and number-system...\" or chooses larger prime numbers.")
        }
    }

    private func setMode(publicOnly newValue: Bool) {
        guard newValue != publicOnly else { return }
        publicOnly = newValue
        if newValue {
            pText = ""; qText = ""; phiText = ""; dText = ""
        } else {
            nText = ""
        }
        checkParameters()
        requestForInput(clear: false)
    }

    private func setInputMode(numbers: Bool) {
        asNumbers = numbers
        requestForInput(clear: false)
    }

    /// CT1 `RequestForInput`.
    private func requestForInput(clear: Bool) {
        if clear { input = "" }
        s1 = ""; s2 = ""; s3 = ""
        h1 = ""; h2 = ""; h3 = ""
        hInput = asNumbers
            ? "Input of the message in the following format:  number(1) # number(2) # ... # number(n) (number in base \(options.base))."
            : "Enter the message for encryption or decryption either as text or as hex dump."
    }

    // MARK: Prime generation / factorisation attack

    private func generateOrFactor() {
        if !publicOnly {
            ref.sheet("Prime Number Generation") { close in
                PrimeGenerationView(onUse: { p, q in
                    pText = p.description; qText = q.description
                    if p.bitLength + q.bitLength - 1 > CT1BigNumber.maxBits {
                        Alerts.error("The demonstration supports only positive integers of bit length smaller than 8192.\nThe bit length of the actually generated RSA modul exceeds 8192.\nPlease select primes p and q, whereby the RSA modul N = p*q is smaller than 2^8192.")
                        pText = ""; qText = ""
                    }
                    checkParameters()
                }, close: close)
            }
            return
        }
        guard !nText.isEmpty, ntEvaluate(nText).value != nil else {
            Alerts.info("Please provide a valid RSA modulus.")
            return
        }
        let n = nText
        ref.sheet("Factorization of a Number") { close in
            FactorizationView(initialNumber: n, readOnly: true) { factors in
                close()
                evaluateFactorisation(factors)
            }
        }
    }

    private func evaluateFactorisation(_ factors: [FactorizationCT1Model.Factor]) {
        if factors.isEmpty || factors.contains(where: { !$0.isPrime }) {
            Alerts.info("The integer N is not factorized until yet.")
        } else if factors.count == 2 && factors.allSatisfy({ $0.exponent == 1 }) {
            Alerts.info("The RSA modulus N has been successfully factorized into the primes p and q!\nYou can now perform the RSA operation with the secret key d:\nPlease click the Decrypt button to continue.")
            publicOnly = false
            pText = factors[0].value.description
            qText = factors[1].value.description
            checkParameters()
            requestForInput(clear: false)
        } else {
            Alerts.info("The integer N is not an RSA modulus:\n- either N has been factorized into more than two numbers\n- or N = p^2 is a quadratic number.\n\nPlease correct the input of N.")
        }
    }

    private func showOptions() {
        let current = options, n = modulus
        ref.sheet("RSA Demonstration Options") { close in
            RSADemoOptionsView(options: current, modulus: n, onOK: { o in
                options = o
                requestForInput(clear: false)
                if modulus != nil && !options.alphabetFits(modulus) { modulusTooSmallMessage() }
            }, close: close)
        }
    }

    // MARK: En-/decryption

    private var base: Int { options.base }

    /// CT1 `CheckIfNumberStream`: text input that looks like numbers may be switched to numbers.
    private func checkIfNumberStream() {
        guard !asNumbers, RSADemoCodec.numberTokens(input, base: base) != nil,
              input.contains(where: { !$0.isWhitespace }) else { return }
        let a = NSAlert()
        a.messageText = "CrypTool"
        a.informativeText = "The input looks like a sequence of numbers!\n\nDo you wish to consider it as a sequence of numbers [yes/no]?"
        a.addButton(withTitle: "Yes"); a.addButton(withTitle: "No")
        if a.runModal() == .alertFirstButtonReturn { asNumbers = true }
    }

    /// CT1 `SkipWS`: removes characters that are not in the alphabet (after asking).
    private func skipWS() -> Bool {
        let set = Set(options.alphabet)
        let clean = String(input.filter { set.contains($0) })
        if clean.isEmpty {
            Alerts.info("The plaintext you entered does not contain a single character of the given alphabet.\nPlease correct your plaintext.", title: "RSA Demonstration")
            return false
        }
        if clean.count != input.count {
            if !Alerts.confirm("The input does contain characters which are not in the alphabet set!\nIf you click OK, only characters of the alphabet will be encrypted (the other characters will be erased from the input).", title: "RSA Demonstration") {
                return false
            }
        }
        input = clean
        return true
    }

    private func headingsText(encrypt: Bool) {
        hInput = "Input text"
        h1 = "The Input text will be separated into segments of Size \(blockSize) (the symbol '#' is used as separator)."
        h2 = "Numbers input in base \(base) format."
        h3 = encrypt ? "Encryption into ciphertext c[i] = m[i]^e (mod N)" : "Decryption into plaintext m[i] = c[i]^d (mod N)"
    }

    private func headingsNumbers(encrypt: Bool) {
        if encrypt {
            hInput = "Plaintext coded in numbers of base \(base)."
            h1 = "Encryption into ciphertext c[i] = m[i]^e (mod N)"
            h2 = "Output text from the encryption (into segments of size \(blockSize); the symbol '#' is used as separator)."
            h3 = "Ciphertext"
        } else {
            hInput = "Ciphertext coded in numbers of base \(base)"
            h1 = "Decryption into plaintext m[i] = c[i]^d (mod N)"
            h2 = "Output text from the decryption (into segments of size \(blockSize); the symbol '#' is used as separator)."
            h3 = "Plaintext"
        }
    }

    private var blockSize: Int { options.variant == 1 ? 1 : max(1, options.blockLength) }

    /// CT1 `Segmentation`: text → blocks (s1) → numbers (s2).
    private func segmentation() -> [String] {
        let k = blockSize
        var blocks: [String] = [], numbers: [String] = []
        if options.textOptions == 0 && options.variant == 0 {
            var bytes = RSADemoCodec.cp1252Bytes(input)
            let count = bytes.count
            if count % k != 0 { bytes += [UInt8](repeating: 0x20, count: k - count % k) }
            for i in stride(from: 0, to: bytes.count, by: k) {
                let block = Array(bytes[i..<i + k])
                blocks.append(RSADemoCodec.cp1252String(block))
                numbers.append(RSADemoCodec.encode(block.map(Int.init), alphabetSize: 256, base: base, basisSystem: options.coding == 1))
            }
        } else {
            let alpha = Array(options.alphabet)
            let a = alpha.count
            var chars = Array(input)
            if chars.count % k != 0 { chars += [Character](repeating: " ", count: k - chars.count % k) }
            let m = RSADemoCodec.modul(alphabetSize: a, base: base, basisSystem: options.coding == 1)
            for i in stride(from: 0, to: chars.count, by: k) {
                let block = Array(chars[i..<i + k])
                blocks.append(String(block))
                let values = block.map { c in alpha.firstIndex(of: c) ?? m }
                var num = RSADemoCodec.encode(values, alphabetSize: a, base: base, basisSystem: options.coding == 1 && options.variant == 0)
                if options.variant == 1 {
                    // CT1 RandRepr(…, 1, 1): index + 1
                    num = (BigUInt(num, radix: base)! + 1).toString(radix: base)
                }
                numbers.append(num)
            }
        }
        s1 = blocks.joined(separator: " # ")
        s2 = numbers.joined(separator: " # ")
        return numbers
    }

    /// CT1 `CRSADemo::Encrypt/Decrypt` on a list of numbers (strings in `base`); nil if a number ≥ N.
    private func rsa(_ numbers: [BigUInt], encrypt: Bool) -> String? {
        guard let n = modulus, let e = pubE else { return nil }
        let sisters = options.variant == 1
        let len = RSADemoCodec.outLength(n, base: base)
        var out: [String] = []
        for var m in numbers {
            if sisters { m %= n }
            if m >= n { return nil }
            var c: BigUInt
            if encrypt {
                c = m.power(e, modulus: n)
                if sisters { c += BigUInt(Int.random(in: 0..<20)) * n }
            } else {
                guard let d = privD else { return nil }
                c = m.power(d, modulus: n)
            }
            out.append(RSADemoCodec.pad(c.toString(radix: base), len))
        }
        return out.joined(separator: " # ")
    }

    /// CT1 `ReSegmentation`: numbers in s1 → text blocks (s2) and text (s3).
    private func reSegmentation(encrypt: Bool) {
        let k = blockSize
        let tokens = RSADemoCodec.numberTokens(s1, base: base) ?? []
        var blocks: [String] = []
        var rawBytes: [[UInt8]] = []
        var ok = true
        for var t in tokens {
            if options.variant == 1 {
                let a1 = BigUInt(options.alphabet.count + 1)
                let r = t % a1
                if r.isZero { ok = false; break }
                t = r - 1
                guard let v = RSADemoCodec.decode(t, alphabetSize: options.alphabet.count, base: base, basisSystem: false, blockLength: k) else { ok = false; break }
                let alpha = Array(options.alphabet)
                blocks.append(String(v.map { alpha[$0] }))
            } else if options.textOptions == 0 {
                guard let v = RSADemoCodec.decode(t, alphabetSize: 256, base: base, basisSystem: options.coding == 1, blockLength: k) else { ok = false; break }
                let b = v.map { UInt8($0) }
                rawBytes.append(b)
                blocks.append(RSADemoCodec.cp1252String(b))
            } else {
                let alpha = Array(options.alphabet)
                guard let v = RSADemoCodec.decode(t, alphabetSize: alpha.count, base: base, basisSystem: options.coding == 1, blockLength: k) else { ok = false; break }
                blocks.append(String(v.map { alpha[$0] }))
            }
        }
        if !ok {
            s2 = encrypt ? "The encrypted message could not be decoded into a text message!"
                         : "The decrypted message could not be decoded into a text message!"
            s3 = ""; h2 = ""; h3 = ""
            return
        }
        if options.textOptions == 0 && options.variant == 0 && rawBytes.joined().contains(where: { !RSADemoCodec.isPrintable($0) }) {
            // CT1 shows non-printable results as hex dump
            let hex = rawBytes.map { $0.map { String(format: "%02X", $0) }.joined(separator: " ") }
            s2 = hex.joined(separator: " # ")
            s3 = hex.joined(separator: " ")
            return
        }
        s2 = blocks.joined(separator: " # ")
        s3 = blocks.joined()
    }

    private func encrypt() { run(encrypt: true) }
    private func decrypt() { run(encrypt: false) }

    private func run(encrypt: Bool) {
        defer { lastRunInput = input }
        checkIfNumberStream()
        if !asNumbers {
            if options.variant == 1 || options.textOptions == 1 {
                if !skipWS() { return }
            }
            headingsText(encrypt: encrypt)
            let numbers = segmentation().compactMap { BigUInt($0, radix: base) }
            guard let out = rsa(numbers, encrypt: encrypt) else {
                Alerts.error("At least one number of the input is greater or equal the size of the RSA modulus N\n(the RSA exponentiation is for a number greater or equal than N not invertible)!\n\nPlease correct your input.")
                return
            }
            s3 = out
        } else {
            guard var numbers = RSADemoCodec.numberTokens(input, base: base) else {
                Alerts.error("Your input is not a sequence of numbers in base \(base). \nPlease correct your input or encrypt the input as text.")
                return
            }
            if options.variant == 1, let n = modulus { numbers = numbers.map { $0 % n } }
            guard let out = rsa(numbers, encrypt: encrypt) else {
                s1 = ""
                Alerts.error("At least one number of the input is greater or equal the size of the RSA modulus N\n(the RSA exponentiation is for a number greater or equal than N not invertible)!\n\nPlease correct your input.")
                return
            }
            s1 = out
            headingsNumbers(encrypt: encrypt)
            reSegmentation(encrypt: encrypt)
        }
    }

    // MARK: Persistence (CT1 IDS_PARAM_RSA_DEMO / "RSA-Demo: Geheime Parameter")

    private func initialize() {
        guard !didInit else { return }
        didInit = true
        let k = Self.prefKey
        if CT1Prefs.bool(k + ".saved", false) {
            publicOnly = CT1Prefs.bool(k + ".publicOnly", false)
            eText = CT1Prefs.string(k + ".e", "2^16+1")
            pText = CT1Prefs.string(k + ".p", "")
            qText = CT1Prefs.string(k + ".q", "")
            nText = CT1Prefs.string(k + ".N", "")
            asNumbers = CT1Prefs.bool(k + ".numbers", false)
            options.textOptions = CT1Prefs.int(k + ".textOptions", 0)
            options.alphabet = CT1Prefs.string(k + ".alphabet", RSATextCodec.defaultAlphabet)
            options.variant = CT1Prefs.int(k + ".variant", 0)
            options.numberBasis = CT1Prefs.int(k + ".base", 0)
            options.coding = CT1Prefs.int(k + ".coding", 0)
        } else {
            let secret = CT1Prefs.string(k + ".secret", "")
            let parts = secret.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            if parts.count == 3 { pText = parts[0]; qText = parts[1]; eText = parts[2] }
        }
        checkParameters()
        requestForInput(clear: true)
    }

    private func saveState() {
        let initialized = publicOnly ? modulus != nil : (modulus != nil && privD != nil)
        guard initialized else { return }
        let k = Self.prefKey
        CT1Prefs.set(k + ".saved", true)
        CT1Prefs.set(k + ".publicOnly", publicOnly)
        CT1Prefs.set(k + ".e", eText)
        CT1Prefs.set(k + ".p", pText)
        CT1Prefs.set(k + ".q", qText)
        CT1Prefs.set(k + ".N", publicOnly ? nText : "")
        CT1Prefs.set(k + ".numbers", asNumbers)
        CT1Prefs.set(k + ".textOptions", options.textOptions)
        CT1Prefs.set(k + ".alphabet", options.alphabet)
        CT1Prefs.set(k + ".variant", options.variant)
        CT1Prefs.set(k + ".base", options.numberBasis)
        CT1Prefs.set(k + ".coding", options.coding)
    }
}
