import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// CT1 Diffie-Hellman-Demo (CDlgDiffieHellmanVisualization and its sub-dialogs).

/// CT1 string table entries (IDS_DH_*).
enum DHText {
    static let windowTitle = "Diffie-Hellman Demonstration - Visualization of the Diffie-Hellman Key Exchange Protocol"
    static let noSafePrime = "No safe prime number!"
    static let generatorInvalid = "Generator value incorrect! (1 < g < p)"
    static let primeInvalid = "An invalid value was assigned to the prime. Please correct your input or let CrypTool generate an appropriate prime by clicking the 'Generate Prime' button."
    static let ppNoInput = "Please fill all entry fields!"
    static let ppNonDecimal = "Please use natural numbers in decimal format only (no special characters)!"
    static let ppPrimeInvalid = "The number you chose is NOT a prime!\nThus, the proceeding might not be safe!"
    static let ppGeneratorInvalid = "You chose a generator (g) which is either zero, a multiple of the prime module (p) or otherwise considered critical!\nThus, the following proceeding might not be safe!"
    static let secretDangerous = "The secret number you chose is either zero or otherwise considered critical!\nThus, the proceeding might not be safe!"
    static let secretPredictable = "The secret number you chose is one. The chosen secret number should be greater than one.\nThe proceeding with this secret might not be safe, because someone can guess the calculated common secret (session key)!\nAt the end of this demo, please compare the session key with the public generator g respectively with public shared keys."
    static let secretExceedsPrime = "The secret exceeds the prime modulus and therefore it is shortened to a number smaller than this prime!"
    static let secretSetAlice = "Alice has chosen her secret! - Only wildcards are displayed in the text field to underline that the secret is solely known to Alice."
    static let secretSetBob = "Bob has chosen his secret! - Only wildcards are displayed in the text field to underline that the secret is solely known to Bob."
    static let publicAlice = "Alice has computed her shared key. It will be displayed in the respective text field."
    static let publicBob = "Bob has computed his shared key. It will be displayed in the respective text field."
    static let sessionAlice = "Alice has computed the Session Key on her part. - It will be displayed in the text field below the 'Calculate' button."
    static let sessionBob = "Bob has computed the Session Key on his part. - It will be displayed in the text field below the 'Calculate' button."
    static let keyTooltip = "Show a dialog with the negotiated secret key and to store log file."
    static let logCreated = "The log text of the procedure was successfully written into the main window of the CrypTool application."
    static let verificationYes = "Verification successful! - The keys of Alice and Bob are identical!"
    static let verificationNo = "Verification failed! The keys of Alice and Bob are NOT identical!"

    static let intro = """
    Welcome to the visualization of the Diffie-Hellman key exchange protocol.

    The protocol deals with the following problem:

    Two communication partners - Alice and Bob for instance - want to negotiate on a secret key over an insecure line.
    However, nobody should be able to acquire the key although listening into the line constantly.

    We will use the already mentioned key exchange protocol by Diffie-Hellman to solve this problem.

    Since this demonstration is an interactive visualization, you will be prompted for certain inputs a couple of times.

    Please feel free to use the context-sensitive help by pressing F1 whenever any obscurities occur.
    """

    /// Info dialogs preceding the five steps (IDD_DIFFIEHELLMAN_SETPUBLIC … _GENERATEFINALKEY).
    static let steps: [(caption: String, text: String)] = [
        ("Set Public Parameters",
         "After clicking the 'OK' button you will be prompted for the public parameters of the Diffie-Hellman key exchange protocol, that is the prime module (p) and the generator (g)."),
        ("Choose Secrets",
         "Now you can separately choose the secret numbers for Alice (a) and Bob (b). The necessary buttons will be activated as soon as you click the 'OK' button."),
        ("Create Shared Keys",
         "If you already chose secret numbers for Alice (a) or Bob (b), you can create their according shared keys A and B now.\n\nThe shared keys are computed as follows:\nA=g^a mod p and B=g^b mod p."),
        ("Exchange Shared Keys",
         "Before Alice and Bob can compute their Session Key, their previously calculated shared keys need to be exchanged. Please exchange the keys by clicking the 'OK' button."),
        ("Generate Common Session Key",
         "All preconditions to generate a common and secret Session Key S for Alice and Bob are fulfilled. You can generate Alice's and Bob's Session Key after a click on 'OK'.\n\nThe common Session Key S is computed by Alice as B^a mod p, and by Bob as A^b mod p."),
    ]

    static let finalInfo = "Using Diffie-Hellman key exchange a common and secret key was established.\n\nThis secret key can now be used as a session key in order to do symmetric encryption.\n\nYou can get the details how this protocol worked with the numbers you chose by hitting the key symbol."
}

@MainActor
enum DHAlert {
    /// Step info dialog with "OK" / "Abbrechen" ("Schritt n"); returns false on cancel.
    static func step(_ i: Int) -> Bool {
        let a = NSAlert()
        a.alertStyle = .informational
        a.messageText = "Step \(i + 1): \(DHText.steps[i].caption)"
        a.informativeText = DHText.steps[i].text
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        return a.runModal() == .alertFirstButtonReturn
    }

    static func info(_ text: String, title: String = "CrypTool") { Alerts.info(text, title: title) }
    static func warning(_ text: String) { Alerts.error(text) }

    static func okCancel(_ text: String) -> Bool { Alerts.confirm(text, title: "CrypTool") }
}

/// IsDecimalNumber of CT1 (digits only; the empty string counts as decimal).
func dhIsDecimal(_ s: String) -> Bool { s.allSatisfy { $0 >= "0" && $0 <= "9" } }

// MARK: - Model

@MainActor
final class DHModel: ObservableObject {
    let window = CT1WindowRef()

    @Published var prime = ""
    @Published var generator = ""
    /// Alice and Bob exist (CT1: DiffieHellmanParty objects created by step 1).
    @Published var hasParties = false
    /// Party secrets (kept for pre-filling the secret dialog) and the masked display values.
    @Published var secretA = ""
    @Published var secretB = ""
    @Published var shownSecretA = ""
    @Published var shownSecretB = ""
    @Published var sharedA = ""
    @Published var sharedB = ""
    @Published var sessionA = ""
    @Published var sessionB = ""
    /// Action state of CT1's 12 bitmap buttons: 0–4 steps, 5/6 secrets, 7/8 public keys,
    /// 9/10 session keys, 11 key symbol.
    @Published var done = [Bool](repeating: false, count: 12)
    @Published var log: String?
    @Published var showInfo: Bool { didSet { CT1Prefs.set("dh.showInfo", showInfo) } }
    @Published var showIntro: Bool { didSet { CT1Prefs.set("dh.showIntro", showIntro) } }
    var introPresented = false

    init() {
        showInfo = CT1Prefs.bool("dh.showInfo", true)
        showIntro = CT1Prefs.bool("dh.showIntro", true)
    }

    /// DiffieHellmanBitmapButtonControl::Update.
    func isActive(_ i: Int) -> Bool {
        switch i {
        case 0: return true
        case 1: return done[0]
        case 2: return done[5] || done[6]
        case 3: return done[7] && done[8]
        case 4: return done[3]
        case 5, 6: return done[1]
        case 7: return done[5] && done[2]
        case 8: return done[6] && done[2]
        case 9, 10: return done[4]
        case 11: return done[9] && done[10]
        default: return false
        }
    }

    private var p: BigUInt { BigUInt(prime) ?? 0 }
    private var g: BigUInt { BigUInt(generator) ?? 0 }

    // MARK: Intro

    func presentIntroIfNeeded() {
        guard !introPresented else { return }
        introPresented = true
        guard CT1Prefs.bool("dh.showIntro", true) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            window.sheet("Introduction Diffie-Hellman Demonstration") { close in
                CT1IntroDialog(text: DHText.intro, prefKey: "dh.showIntro") { [weak self] in
                    close()
                    self?.showIntro = CT1Prefs.bool("dh.showIntro", true)
                }
            }
        }
    }

    // MARK: Steps

    func step1() {
        if showInfo && !DHAlert.step(0) { return }
        let p0 = hasParties ? prime : "", g0 = hasParties ? generator : ""
        window.sheet("Set Public Parameters") { close in
            DHPublicParametersDialog(initialPrime: p0, initialGenerator: g0, close: close) { [weak self] p, g, safe in
                self?.applyParameters(p, g, safe: safe)
            }
        }
    }

    private func applyParameters(_ p: String, _ g: String, safe: Bool) {
        if !safe { DHAlert.info(DHText.noSafePrime) }
        // DiffieHellmanParty constructor: at most 310 decimal digits (MAX_KEY_LENGTH_IN_BYTE)
        var failed = false
        if g.count > 310 || g.isEmpty { DHAlert.warning(DHText.generatorInvalid); failed = true }
        if p.count > 310 || p.isEmpty { DHAlert.warning(DHText.primeInvalid); failed = true }
        if failed {
            hasParties = false
            prime = ""; generator = ""
            secretA = ""; secretB = ""
            done = [Bool](repeating: false, count: 12)
            clearFields(0)
            log = nil
            return
        }
        prime = p; generator = g
        hasParties = true
        secretA = ""; secretB = ""
        perform(0)
    }

    func step(_ i: Int) {
        guard hasParties else { DHAlert.warning("An internal error has occurred!"); return }
        if showInfo && !DHAlert.step(i) { return }
        perform(i)
    }

    func chooseSecret(alice: Bool) {
        guard hasParties else { return }
        let name = alice ? "Alice" : "Bob"
        let prev = alice ? secretA : secretB
        window.sheet("Choose \(name)'s secret") { close in
            DHSecretInputDialog(party: name, prime: BigUInt(self.prime) ?? 0, initialSecret: prev, close: close) { [weak self] s, exceeds in
                self?.applySecret(s, alice: alice, exceedsPrime: exceeds)
            }
        }
    }

    private func applySecret(_ s: String, alice: Bool, exceedsPrime: Bool) {
        if alice { secretA = s } else { secretB = s }
        if showInfo {
            var msg = alice ? DHText.secretSetAlice : DHText.secretSetBob
            if exceedsPrime { msg += "\n\n" + DHText.secretExceedsPrime }
            DHAlert.info(msg)
        }
        if alice { shownSecretA = s } else { shownSecretB = s }
        perform(alice ? 5 : 6)
    }

    func computePublic(alice: Bool) {
        guard hasParties else { return }
        let s = BigUInt(alice ? secretA : secretB) ?? 0
        let v = p.isOne ? BigUInt(0) : g.power(s, modulus: p)
        if alice { sharedA = v.description } else { sharedB = v.description }
        if showInfo { DHAlert.info(alice ? DHText.publicAlice : DHText.publicBob) }
        perform(alice ? 7 : 8)
    }

    func computeSession(alice: Bool) {
        guard hasParties else { return }
        let s = BigUInt(alice ? secretA : secretB) ?? 0
        let other = publicKey(alice: !alice)
        let v = p.isOne ? BigUInt(0) : other.power(s, modulus: p)
        if alice { sessionA = v.description } else { sessionB = v.description }
        if showInfo { DHAlert.info(alice ? DHText.sessionAlice : DHText.sessionBob) }
        perform(alice ? 9 : 10)
    }

    private func publicKey(alice: Bool) -> BigUInt {
        let s = BigUInt(alice ? secretA : secretB) ?? 0
        return p.isOne ? 0 : g.power(s, modulus: p)
    }

    func showKeyDetails() {
        let a = sessionA, b = sessionB, log = log
        window.sheet("Key Details - Secret and Common Key of Alice and Bob") { close in
            DHKeyDetailsDialog(sessionAlice: a, sessionBob: b, log: log, close: close)
        }
        done[11] = true
    }

    // MARK: Button state machine (DiffieHellmanBitmapButtonControl::PerformAction + UpdateGUI)

    private func perform(_ b: Int) {
        done[b] = true
        let cancels: [Int: [Int]] = [
            0: Array(1...10), 1: Array(2...10), 2: [3, 4, 7, 8, 9, 10], 3: [4, 9, 10], 4: [9, 10],
            5: [3, 4, 7, 9, 10], 6: [3, 4, 8, 9, 10], 7: [3, 4, 9, 10], 8: [3, 4, 9, 10],
        ]
        for c in cancels[b] ?? [] { done[c] = false }
        if !isActive(11) { done[11] = false }
        clearFields(b)
        if done[9] && done[10] {
            DHAlert.info(DHText.finalInfo, title: "Diffie-Hellman Key Exchange Successful")
            log = DHLog.text(prime: prime, generator: generator, secretA: secretA, secretB: secretB,
                             sharedA: publicKey(alice: true).description, sharedB: publicKey(alice: false).description,
                             sessionA: sessionA, sessionB: sessionB)
        }
    }

    private func clearFields(_ b: Int) {
        switch b {
        case 0, 1:
            shownSecretA = ""; shownSecretB = ""
            sharedA = ""; sharedB = ""; sessionA = ""; sessionB = ""
        case 2:
            sharedA = ""; sharedB = ""; sessionA = ""; sessionB = ""
        case 3, 4, 7, 8:
            sessionA = ""; sessionB = ""
        case 5:
            sharedA = ""; sessionA = ""; sessionB = ""
        case 6:
            sharedB = ""; sessionA = ""; sessionB = ""
        default:
            break
        }
    }
}

// MARK: - Log text (DiffieHellmanLogFile)

enum DHLog {
    static func text(prime: String, generator: String, secretA: String, secretB: String,
                     sharedA: String, sharedB: String, sessionA: String, sessionB: String) -> String {
        let br = "\n\n"
        let p = BigUInt(prime) ?? 1
        let ra = p.isZero ? "0" : ((BigUInt(secretA) ?? 0) % p).description
        let rb = p.isZero ? "0" : ((BigUInt(secretB) ?? 0) % p).description
        var t = "At first, Alice and Bob agreed on the public parameters. So they chose a prime p and a generator g:" + br
        t += "p: " + prime + br
        t += "g: " + generator + br
        t += "Alice chose her secret number 'a' while Bob chose his secret number 'b':" + br
        t += "a: " + secretA + br
        t += "b: " + secretB + br
        t += "If the chosen secret values a and b are greater or equal the prime module p, then they need to be reduced modulo p. The actual values are given below:" + br
        t += "a (reduced mod p):\n" + ra + br
        t += "b (reduced mod p):\n" + rb + br
        t += "On the basis of the previously chosen secret numbers, Alice and Bob created their respective shared keys. Alice computed her shared key A, while Bob computed his shared key B:" + br
        t += "A: " + sharedA + br
        t += "B: " + sharedB + br
        t += "In order to calculate their secret and common Session Key, Alice and Bob exchanged their shared keys: Alice sent her shared key A to Bob and Bob sent his shared key B to Alice." + br
        t += "Alice and Bob were able to calculate the secret and common Session Key now. Alice computed the Session Key SA, Bob computed the Session Key SB:" + br
        t += "SA: " + sessionA + br
        t += "SB: " + sessionB + br
        t += "Theoretically it is now possible for Alice and Bob to use their Session Keys to encrypt documents they would like to exchange covertly."
        return t
    }
}

// MARK: - "Öffentliche Parameter setzen" (IDD_DIFFIEHELLMAN_PUBLICPARAMETERS)

struct DHPublicParametersDialog: View {
    var close: () -> Void
    var onAccept: (String, String, Bool) -> Void
    @StateObject private var ref = CT1WindowRef()
    @CTState private var prime: String
    @CTState private var generator: String
    /// Prime last taken over from "Sichere Primzahl erzeugen" (b_isSavePrime until edited).
    @CTState private var generatedSafePrime: String?

    init(initialPrime: String, initialGenerator: String, close: @escaping () -> Void,
         onAccept: @escaping (String, String, Bool) -> Void) {
        self.close = close
        self.onAccept = onAccept
        _prime = CTState(initialValue: initialPrime)
        _generator = CTState(initialValue: initialGenerator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Both parameters, the generator (g) and the prime module (p) may be known publicly.")
                .fixedSize(horizontal: false, vertical: true)
            GroupBox("Primzahlmodul") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The prime module (p) needs to be a prime; if you don't know any large primes, just click the button 'Generate Prime'. A valid prime module will be created instantly.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Prime module:").frame(width: 100, alignment: .leading)
                        TextField("", text: $prime).font(.system(.body, design: .monospaced))
                        Button("Generate Prime", action: generatePrime).frame(width: 150)
                    }
                }.padding(4)
            }
            GroupBox("Generator") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The generator (g) is a natural number, preferably not zero or one and not a multiple of the prime module (p). Push the button 'Create Generator' to make CrypTool create a valid natural number.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Generator:").frame(width: 100, alignment: .leading)
                        TextField("", text: $generator).font(.system(.body, design: .monospaced))
                        Button("Create Generator", action: generateGenerator).frame(width: 150)
                    }
                }.padding(4)
            }
            HStack {
                Button("Accept parameters", action: accept).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
        .ct1Window(ref: ref)
    }

    private var isSafeKnown: Bool { generatedSafePrime != nil && generatedSafePrime == prime }

    private static func isSafe(_ p: BigUInt) -> Bool { Primality.isProbablePrime(p / 2) }

    /// CDlgDiffieHellmanPublicParameters::checkGenerator – nil or the error message.
    static func checkGenerator(prime: String, generator: String) -> String? {
        if prime.isEmpty || generator.isEmpty { return DHText.ppNoInput }
        if !dhIsDecimal(prime) || !dhIsDecimal(generator) { return DHText.ppNonDecimal }
        guard let P = BigUInt(prime), let G = BigUInt(generator) else { return DHText.ppNonDecimal }
        guard P > 1, Primality.isProbablePrime(P) else { return DHText.ppPrimeInvalid }
        let Q = P >> 1
        if Primality.isProbablePrime(Q) {
            if G >= P || G <= 1 { return DHText.ppGeneratorInvalid }
            if ((G * G) % P).isOne || G.power(Q, modulus: P).isOne { return DHText.ppGeneratorInvalid }
            return nil
        }
        if G == P - 1 || (G % P).isZero || G.isOne { return DHText.ppGeneratorInvalid }
        return nil
    }

    private func accept() {
        let safe = isSafeKnown || (BigUInt(prime).map(Self.isSafe) ?? false)
        if let err = Self.checkGenerator(prime: prime, generator: generator) {
            Alerts.error(err)
            return
        }
        let p = prime, g = generator
        close()
        DispatchQueue.main.async { onAccept(p, g, safe) }
    }

    private func generatePrime() {
        ref.sheet("Generate a Safe Prime") { close in
            SafePrimeDialog(close: close) { p in
                if p.isEmpty { prime = ""; generator = ""; return }
                prime = p
                generatedSafePrime = p
                if let G = BigUInt(generator), let P = BigUInt(p), G >= P { generator = "" }
            }
        }
    }

    private func generateGenerator() {
        if !dhIsDecimal(prime) { Alerts.error(DHText.ppNonDecimal); return }
        guard !prime.isEmpty, let P = BigUInt(prime), !P.isZero else { Alerts.error(DHText.ppPrimeInvalid); return }
        let safe = isSafeKnown || Self.isSafe(P)
        if safe {
            var counter = 0
            repeat {
                generator = BigUInt.random(below: P).description
                counter += 1
            } while counter < 4096 && Self.checkGenerator(prime: prime, generator: generator) != nil
        } else {
            generator = BigUInt.random(below: P).description
        }
    }
}

// MARK: - "Geheimnis wählen" (IDD_DIFFIEHELLMAN_SECRETINPUT)

struct DHSecretInputDialog: View {
    let party: String
    let prime: BigUInt
    var close: () -> Void
    var onAccept: (String, Bool) -> Void
    @CTState private var secret: String

    init(party: String, prime: BigUInt, initialSecret: String, close: @escaping () -> Void,
         onAccept: @escaping (String, Bool) -> Void) {
        self.party = party
        self.prime = prime
        self.close = close
        self.onAccept = onAccept
        _secret = CTState(initialValue: initialSecret)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Please choose the secret for \(party) now.").font(.headline)
            Text("Please make sure to choose a natural number, preferably bigger than one but smaller than the previously defined prime module (p).")
                .fixedSize(horizontal: false, vertical: true)
            Text("In case you do not want to make up any large number, click the button 'Generate Secret' to let CrypTool generate an appropriate number within a valid range of values.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Secret:").frame(width: 80, alignment: .leading)
                TextField("", text: $secret).font(.system(.body, design: .monospaced))
                Button("Generate Secret") {
                    secret = prime.isZero ? "0" : BigUInt.random(below: prime).description
                }.frame(width: 150)
            }
            HStack {
                Button("Accept secret", action: accept).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 640)
    }

    private func accept() {
        if secret.isEmpty { Alerts.error(DHText.ppNoInput); return }
        var s = secret
        if !dhIsDecimal(s), let v = try? BigExpression.evaluate(s), !v.isNegative { s = v.magnitude.description }
        guard dhIsDecimal(s), let S = BigUInt(s) else { Alerts.error(DHText.ppNonDecimal); return }
        let exceeds = S >= prime
        if S.isZero || (prime > 0 && S == prime - 1) {
            if !DHAlert.okCancel(DHText.secretDangerous) { return }
        } else if S.isOne {
            if !DHAlert.okCancel(DHText.secretPredictable) { return }
        }
        let value = S.description
        close()
        DispatchQueue.main.async { onAccept(value, exceeds) }
    }
}

// MARK: - Key details (IDD_DIFFIEHELLMAN_KEY)

struct DHKeyDetailsDialog: View {
    let sessionAlice: String
    let sessionBob: String
    let log: String?
    var close: () -> Void

    /// ceil(log2(S)) like CT1 (BitLength + ceil; 1 for S = 1).
    static func bitLength(_ s: String) -> Int {
        guard let v = BigUInt(s), !v.isZero else { return 0 }
        if v.isOne { return 1 }
        let bl = v.bitLength
        return v.nonzeroBitCount == 1 ? bl - 1 : bl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alice and Bob have computed their Session Key independently from each other:")
            keyRow("Alice's Session Key:", sessionAlice)
            keyRow("Bob's Session Key:", sessionBob)
            GroupBox("Verification") {
                Text(BigUInt(sessionAlice) == BigUInt(sessionBob) ? DHText.verificationYes : DHText.verificationNo)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Thus, the target is reached") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Using the secret information on the one hand and the public information on the other hand, each party (Alice and Bob) computed the common and secret Session Key on its own.")
                    Text("An eavesdropper cannot gain knowledge of the secret if the used parameters are big enough. The Session Key can now be used for a symmetric encryption.")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("OK", action: close).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Show log text") {
                    guard let log else { return }
                    DocumentFactory.openResult(text: log, title: "Diffie-Hellman-Log")
                    Alerts.info(DHText.logCreated)
                }.disabled(log == nil)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 700)
    }

    private func keyRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).frame(width: 150, alignment: .leading)
                DHReadOnly(text: value)
            }
            HStack {
                Spacer().frame(width: 150)
                Text("Key length [bit]:")
                DHReadOnly(text: "\(Self.bitLength(value))").frame(width: 70)
                Spacer()
            }
        }
    }
}

/// Read-only single-line field (CT1 ES_READONLY edit control).
struct DHReadOnly: View {
    let text: String
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1).truncationMode(.middle)
            .textSelection(.enabled)
            .help(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.vertical, 3)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}
