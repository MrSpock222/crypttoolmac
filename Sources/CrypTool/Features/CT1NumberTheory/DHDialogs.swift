import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// CT1 Diffie-Hellman-Demo (CDlgDiffieHellmanVisualization and its sub-dialogs).

/// CT1 string table entries (IDS_DH_*).
enum DHText {
    static let windowTitle = "Diffie-Hellman-Demo - Visualisierung des Schlüsselaustauschverfahrens nach Diffie-Hellman"
    static let noSafePrime = "Keine sichere Primzahl!"
    static let generatorInvalid = "Dem Generator konnte kein gültiger Wert zugewiesen werden, bitte überprüfen Sie Ihre Eingaben (1 < g < p)."
    static let primeInvalid = "Der Primzahl konnte kein gültiger Wert zugewiesen werden, bitte wählen Sie ggf. einen kleineren Wert!"
    static let ppNoInput = "Bitte lassen Sie die Eingabefelder nicht leer!"
    static let ppNonDecimal = "Bitte geben Sie nur natürliche Zahlen in dezimaler Form ein (keine Buchstaben und/oder sonstige Sonderzeichen)."
    static let ppPrimeInvalid = "Die von Ihnen eingegebene Zahl ist keine Primzahl!\nBitte beachten Sie, dass das Verfahren mit dem gewählten Primzahlmodul unter Umständen nicht sicher ist!"
    static let ppGeneratorInvalid = "Sie wählten einen Generator (g), der entweder gleich Null, ein Vielfaches des Primzahlmoduls (p) oder anderweitig kritisch ist.\nBeachten Sie, dass das Verfahren mit dem gewählten Generator unter Umständen nicht sicher ist!"
    static let secretDangerous = "Das von Ihnen eingegebene Geheimnis S ist entweder gleich Null oder gleich einem weiteren, kritischen Wert.\nBeachten Sie, dass das Verfahren mit dieser Wahl nicht sicher ist!"
    static let secretPredictable = "Das von Ihnen eingegebene Geheimnis S ist 1. Das gewählte Geheimnis sollte größer als 1 sein.\nDas Verfahren ist mit diesem Geheimnis nicht sicher, da der ausgehandelte geheime und gemeinsame Schlüssel erratbar ist!\nVergleichen Sie bitte am Ende der Demo den geheimen und gemeinsamen Schlüssel mit dem öffentlichen Generator g bzw. den öffentlichen Teilschlüsseln."
    static let secretExceedsPrime = "Das Geheimnis ist größer als der Primzahlmodul und wird deshalb verkürzt auf eine Zahl kleiner als diese Primzahl!"
    static let secretSetAlice = "Alice hat ihr Geheimnis a gewählt. Da dies aber niemandem bekannt sein darf, werden im entsprechenden Textfeld nur Sternchen angezeigt."
    static let secretSetBob = "Bob hat sein Geheimnis b gewählt. Da dies niemandem bekannt sein darf, werden im entsprechenden Textfeld nur Sternchen angezeigt."
    static let publicAlice = "Alice hat ihren öffentlichen Teilschlüssel A = g^a mod p berechnet.\nDieser Teilschlüssel wird nun im entsprechenden Textfeld ausgegeben."
    static let publicBob = "Bob hat seinen öffentlichen Teilschlüssel B = g^b mod p berechnet.\nDieser Teilschlüssel wird nun im entsprechenden Textfeld ausgegeben."
    static let sessionAlice = "Alice hat anhand des öffentlichen Schlüssels von Bob (B) und ihres Geheimnisses (a) den gemeinsamen Schlüssel S = B^a = (g^b)^a berechnet.\nDieser Schlüssel wird nun im Textfeld unter dem Button angezeigt."
    static let sessionBob = "Bob hat anhand des öffentlichen Schlüssels von Alice (A) und seines Geheimnisses (b) den gemeinsamen Schlüssel S = A^b = (g^a)^b berechnet.\nDieser Schlüssel wird nun im Textfeld unter dem Button angezeigt."
    static let keyTooltip = "Anzeige des ausgehandelten geheimen Schlüssels und Abspeichern der Logdatei."
    static let logCreated = "Der Protokollverlauf mit Ihren Zahlen wurde erfolgreich in ein Fenster im CrypTool-Hauptprogramm geschrieben."
    static let verificationYes = "Verifikation erfolgreich! - Die Schlüssel von Alice und Bob sind identisch."
    static let verificationNo = "Verifikation fehlgeschlagen! - Die Schlüssel von Alice und Bob sind nicht identisch!"

    static let intro = """
    Willkommen zur Visualisierung des Diffie-Hellman-Schlüsselaustauschverfahrens!

    Das Verfahren behandelt die folgende Problemstellung:

    Zwei Kommunikationspartner -- in diesem Fall Alice und Bob -- wollen einen geheimen Schlüssel über einen unsicheren Kanal aushandeln.
    Dabei soll jedoch kein Angreifer die Möglichkeit haben, den ausgehandelten Schlüssel zu erlangen, auch wenn er den Kanal komplett abhören kann.

    Dieses Problem wird mit dem Schlüsselaustauschverfahren nach Diffie-Hellman gelöst.

    Die folgende interaktive Visualisierung des Verfahrens erfordert Benutzereingaben von Ihnen.

    Bei Fragen erhalten Sie mit der F1-Taste kontextbezogene Hilfe.
    """

    /// Info dialogs preceding the five steps (IDD_DIFFIEHELLMAN_SETPUBLIC … _GENERATEFINALKEY).
    static let steps: [(caption: String, text: String)] = [
        ("Öffentliche Parameter setzen",
         "Nach einem Klick auf OK werden Sie aufgefordert, die öffentlichen Parameter des Schlüsselaustauschs einzugeben, den Primzahlmodul (p) und den Generator (g)."),
        ("Geheimnisse wählen",
         "Sie können nun jeweils nacheinander die Geheimnisse für Alice (a) bzw. Bob (b) festlegen. Die entsprechenden Buttons werden nach einem Klick auf OK aktiviert."),
        ("Öffentliche Teilschlüssel erzeugen",
         "Nun können Sie die öffentlichen Schlüssel von Alice (A) und Bob (B) erzeugen, sofern Sie im vorigen Schritt schon deren Geheimnisse a und b festgelegt haben.\n\nDie beiden Teilschlüssel lassen sich wie folgt berechnen: A=g^a mod p bzw. B=g^b mod p."),
        ("Öffentliche Teilschlüssel austauschen",
         "Damit Alice und Bob letztendlich ihren gemeinsamen Schlüssel S berechnen können, müssen zunächst ihre öffentlichen Schlüssel A und B ausgetauscht werden."),
        ("Geheimen Schlüssel generieren",
         "Nachdem Sie auf die Schaltfläche 'OK' gedrückt haben, können Sie getrennt voneinander für Alice und Bob den geheimen und gemeinsamen Schlüssel S berechnen.\n\nDieser gemeinsame Session Key S wird auf Seiten von Alice berechnet als B^a mod p und auf Seiten von Bob als A^b mod p."),
    ]

    static let finalInfo = "Mit dem Diffie-Hellman-Verfahren wurde erfolgreich ein gemeinsamer und geheimer Schlüssel erzeugt.\n\nDieser geheime Schlüssel kann nun als Sessionkey für eine folgende symmetrische Verschlüsselung verwendet werden.\n\nDurch Drücken des Schlüsselsymbols erhalten Sie Details zum Verfahren mit den von Ihnen gewählten Zahlen."
}

@MainActor
enum DHAlert {
    /// Step info dialog with "OK" / "Abbrechen" ("Schritt n"); returns false on cancel.
    static func step(_ i: Int) -> Bool {
        let a = NSAlert()
        a.alertStyle = .informational
        a.messageText = "Schritt \(i + 1): \(DHText.steps[i].caption)"
        a.informativeText = DHText.steps[i].text
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Abbrechen")
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
            window.sheet("Einleitung Diffie-Hellman-Demo") { close in
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
        window.sheet("Öffentliche Parameter setzen") { close in
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
        guard hasParties else { DHAlert.warning("Ein interner Fehler ist aufgetreten!"); return }
        if showInfo && !DHAlert.step(i) { return }
        perform(i)
    }

    func chooseSecret(alice: Bool) {
        guard hasParties else { return }
        let name = alice ? "Alice" : "Bob"
        let prev = alice ? secretA : secretB
        window.sheet("\(name)'s Geheimnis festlegen") { close in
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
        window.sheet("Schlüssel-Details - Geheimer und gemeinsamer Schlüssel von Alice und Bob") { close in
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
            DHAlert.info(DHText.finalInfo, title: "Diffie-Hellman-Schlüsselaustausch erfolgreich")
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
        var t = "Zunächst einigten sich Alice und Bob auf die öffentlichen Parameter des Schlüsselaustauschs. Hierzu wählten sie eine Primzahl p und einen Generator g:" + br
        t += "p: " + prime + br
        t += "g: " + generator + br
        t += "Nun wählten sowohl Alice als auch Bob jeweils für sich ihre Geheimzahlen. Alice und Bob legten ihre Geheimnisse a und b wie folgt fest:" + br
        t += "a: " + secretA + br
        t += "b: " + secretB + br
        t += "Falls die gewählten Geheimnisse a und b größer oder gleich dem Primzahlmodul p sind, werden sie Modulo p reduziert. Nachfolgend sind die tatsächlich verwendeten Werte angegeben:" + br
        t += "a (reduziert mod p):\n" + ra + br
        t += "b (reduziert mod p):\n" + rb + br
        t += "Anhand ihrer zuvor gewählten Geheimnisse erzeugte Alice ihren öffentlichen Teilschlüssel A. Bob erzeugte parallel dazu seinen öffentlichen Teilschlüssel B:" + br
        t += "A: " + sharedA + br
        t += "B: " + sharedB + br
        t += "Als nächstes tauschten Alice und Bob ihre öffentlichen Teilschlüssel aus, d.h. Alice sendete ihren Schlüssel A an Bob und Bob sendete seinen Schlüssel B an Alice." + br
        t += "Nun konnten Alice und Bob jeweils den geheimen und gemeinsamen Sessionkey erzeugen. Alice berechnete ihren Schlüssel SA, Bob berechnete den Schlüssel SB:" + br
        t += "SA: " + sessionA + br
        t += "SB: " + sessionB + br
        t += "Theoretisch wäre es Alice und Bob nun möglich, mit Hilfe des jeweils berechneten Sessionkeys SA und SB untereinander auszutauschende Dokumente zum Schutz vor Dritten zu verschlüsseln bzw. zu entschlüsseln."
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
            Text("Beide Parameter -- sowohl der Generator (g) als auch der Primzahlmodul (p) -- dürfen öffentlich bekannt sein.")
                .fixedSize(horizontal: false, vertical: true)
            GroupBox("Primzahlmodul") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Der Primzahlmodul (p) sollte eine Primzahl sein. Für die spätere Wahl des Generators g ist es notwendig, dass die Faktorisierung von Phi(p) bekannt ist.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Primzahlmodul:").frame(width: 100, alignment: .leading)
                        TextField("", text: $prime).font(.system(.body, design: .monospaced))
                        Button("Primzahl erzeugen...", action: generatePrime).frame(width: 150)
                    }
                }.padding(4)
            }
            GroupBox("Generator") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Als Generator (g) bezeichnet man eine natürliche Zahl, die nach Möglichkeit nicht Null oder Eins und kein Vielfaches des Primzahlmoduls (p) sein sollte.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Generator:").frame(width: 100, alignment: .leading)
                        TextField("", text: $generator).font(.system(.body, design: .monospaced))
                        Button("Generator erzeugen", action: generateGenerator).frame(width: 150)
                    }
                }.padding(4)
            }
            HStack {
                Button("Parameter übernehmen", action: accept).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
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
        ref.sheet("Sichere Primzahl erzeugen") { close in
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
            Text("Bitte legen Sie nun das Geheimnis für \(party) fest.").font(.headline)
            Text("Bitte achten Sie darauf, dass Sie sich für eine natürliche Zahl entscheiden, die möglichst größer als Eins und kleiner als der zuvor gewählte Primzahlmodul (p) ist.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Falls Sie selbst kein Geheimnis eingeben wollen, so klicken Sie bitte auf den Button 'Geheimnis erzeugen' und lassen somit eine Zufallszahl erzeugen, welche die obige Bedingung erfüllt.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Geheimnis").frame(width: 80, alignment: .leading)
                TextField("", text: $secret).font(.system(.body, design: .monospaced))
                Button("Geheimnis erzeugen") {
                    secret = prime.isZero ? "0" : BigUInt.random(below: prime).description
                }.frame(width: 150)
            }
            HStack {
                Button("Geheimnis übernehmen", action: accept).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
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
            Text("Unabhängig voneinander haben Alice und Bob jeweils für sich den Session Key berechnet:")
            keyRow("Alice's Session Key S:", sessionAlice)
            keyRow("Bob's Session Key S:", sessionBob)
            GroupBox("Verifikation") {
                Text(BigUInt(sessionAlice) == BigUInt(sessionBob) ? DHText.verificationYes : DHText.verificationNo)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Damit ist das Ziel erreicht") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Jede Partei (Alice und Bob) berechnete für sich aus den eigenen geheimen Informationen und aus den übertragenen Informationen das gemeinsame Geheimnis.")
                    Text("Dieses Geheimnis bzw. den Session Key kann ein \"Lauscher\" nicht in Erfahrung bringen, wenn die gewählten Parameter groß genug sind. Der Session Key kann nun z.B. für eine symmetrische Verschlüsselung zwischen Alice und Bob verwendet werden.")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("OK", action: close).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Log-Text anzeigen") {
                    guard let log else { return }
                    DocumentFactory.openResult(text: log, title: "Diffie-Hellman-Log")
                    Alerts.info(DHText.logCreated)
                }.disabled(log == nil)
                Spacer()
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
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
                Text("Schlüssellänge [bit]:")
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
