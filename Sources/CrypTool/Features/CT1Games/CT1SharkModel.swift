import AppKit
import SwiftUI

// Port of CT1's "Der Zahlenhai" (NumberShark 1.2.4, MFC): EvoZahlenHai (rules), zhl (back-tracking
// search), zahl (brute-force search), ZahlenHaiOptionen/GameSummary/... (dialogs). German captions
// are taken from the German resources of MFC-ZahlenHai.rc.

// MARK: - German texts (MFC-ZahlenHai.rc, LANG_GERMAN)

enum SharkText {
    static let numberShark = "Zahlenhai"
    static let titleVersion = " - Version 1.2.4"
    static let sharkAgainst = " gegen "
    static let primeInfo = "(prim)"
    static let rules = "Beschreibung:\n - Im Zahlenhai-Spiel entscheidet man sich zu Beginn für die Größe des Muschelfeldes, also mit wie viel Zahlen man spielen möchte.\n    Diese Größe des Muschelfeldes bezeichnen wir mit \"n\" und nennen sie die \"Anzahl der auswählbaren Zahlen\". Der Zahlenvorrat beginnt bei 1\n    und geht bis zu der Zahl, die Du als Größe für das Muschelfeld ausgewählt hast (vorgeschlagen ist zu Beginn die Zahl 20).\n    Danach werden alle Zahlen aus dem Zahlenvorrat nach den Regeln, die Du weiter unten findest, zwischen Dir und dem Computer (\"Zahlenhai\") aufgeteilt.\n - Standardmäßig sind beim Start des Spiels 20 Zahlen in dem Muschelfeld eingestellt. Du kannst als Gesamtzahl n jede Zahl von 1 bis 9999 wählen.\n\nZiel:\n - Dein Ziel ist es, dass die Summe Deiner Zahlen größer ist als die Summe aller Zahlen, die der Zahlenhai gefressen hat.\n\nRegeln:\n - Du hast immer den ersten Zug, d.h. Du beginnst die erste Runde.\n - In der ersten Runde kannst Du Dir eine beliebige Zahl aus dem Zahlenvorrat auswählen\n   (der Zahlenvorrat umfasst n Zahlen und wird im Muschelfeld angezeigt).\n - Immer bekommt der Zahlenhai von der ausgewählten Zahl alle echten Teiler, sofern diese noch nicht ausgewählt wurden\n   (6 ist zum Beispiel teilbar durch 1,2,3,6. Die echten Teiler sind 1,2,3).\n - In allen darauf folgenden Runden kannst Du nur Zahlen wählen, die Du vorher noch nicht gewählt hast und die\n    noch nicht vom Zahlenhai gefressen wurden (also nur die blauen Muscheln).\n - ABER: Der Zahlenhai darf nie leer ausgehen!\n - Wählst Du eine Zahl, deren Teiler alle schon verteilt wurden, so bekommt der Zahlenhai die gewählte Zahl\n    und Du erhältst 0 Punkte in dieser Runde.\n\n"
    static let rules2 = "Während des Spielens kannst Du mit der Tastenkombination SHIFT+ALT+C die Muscheln auf den Buttons sichtbar und unsichtbar machen.\nDadurch kann man die Zahlen auf den Buttons noch besser lesen und das Spiel kann dadurch auch flüssiger dargestellt werden.\n\nHilfen und weitere Hinweise stehen in der Online-Hilfe. Diese kannst Du an jeder Stelle im Zahlenhai-Spiel mit der F1-Taste öffnen.\n\nDie Online-Hilfe enthält eine ausführliche Bedienungsanleitung, einen konkreten kommentierten Spielverlauf (Probespiel), Informationen zur Entstehung des Spiels\nsowie eine Herausforderung an Euch, mit der Ihr uns helfen könnt, dieses Spiel zu verbessern.\n"
    static func playerWins(_ n: String, _ p: String, _ n2: String, _ best: String) -> String {
        "Glückwunsch, Du hast gegen den Zahlenhai gewonnen!\n\nWenn Du eine größere Herausforderung suchst, dann nimm eine höhere Zahl als \(n).\n\nDu hast \(p) Punkte erreicht. Maximal wären bei \(n2) Zahlen \(best) Punkte möglich gewesen."
    }
    static func playerWins2(_ n: String, _ p: String) -> String {
        "Glückwunsch, Du hast gegen den Hai gewonnen!\n\nWenn Du eine größere Herausforderung suchst, dann nimm eine höhere Zahl als \(n).\n\nDu hast \(p) Punkte erreicht."
    }
    static func playerWins3(_ n: String, _ p: String, _ n2: String, _ best: String) -> String {
        "Glückwunsch, Du hast gegen den Zahlenhai gewonnen!\n\nWenn Du eine größere Herausforderung suchst, dann nimm eine höhere Zahl als \(n).\n\nDu hast \(p) Punkte erreicht. Bis jetzt haben wir bei \(n2) Zahlen maximal \(best) Punkte erreicht."
    }
    static func playerWinsOptimal(_ p: String, _ n: String, _ n2: String) -> String {
        "GLÜCKWUNSCH, Du hast gegen den Hai gewonnen!\n\nMit \(p) Punkten hast Du sogar die maximale Punktzahl bei \(n) Zahlen erreicht.\n\nWenn Du eine größere Herausforderung suchst, dann nimm eine höhere Zahl als \(n2)."
    }
    static func playerWinsOptimal2(_ p: String, _ best: String, _ n: String) -> String {
        "GLÜCKWUNSCH, Du hast gegen den Hai gewonnen!\n\nMit \(p) Punkten hast Du sogar mehr Punkte erreicht als wir bisher geschafft haben. Unser bestes Ergebnis war bisher \(best) Punkte bei \(n) Zahlen.\n\nBitte schicke die Zusammenfassung an esslinger@fb5.uni-siegen.de."
    }
    static func computerWins(_ c: String, _ p: String) -> String {
        "Diesmal hat der Zahlenhai gewonnen! :,-(\n\nEr hat Dich mit \(c) zu \(p) Punkten geschlagen.\n\nLos! Versuch es gleich nochmal!"
    }
    static func numberOne(_ c: String, _ p: String) -> String {
        "Diesmal hat der Zahlenhai gewonnen! :,-(\n\nEr hat Dich mit \(c) zu \(p) Punkten geschlagen.\n\nWenn nur die Zahl '1' im Muschelfeld liegt, kann man auch nicht gewinnen.\n\nLos! Versuch es gleich nochmal!"
    }
    static func draw(_ p: String) -> String {
        "Unentschieden!?!\n\nDas kommt nur sehr selten vor!\n\nDu und der Zahlenhai haben jeweils \(p) Punkte."
    }
    static let drawHeadline = "Unentschieden!"
    static let computerWinsHeadline = "Verloren!"
    static let playerWinsHeadline = "Gewonnen!"
    static func invalidInput(_ max: String) -> String { "Für den Zahlenhai können nur Zahlen zwischen 1 und \(max) eingegeben werden!" }
    static let validInputHeadline = "Die eingegebene Zahl ist zu groß!"
    static let validInputHeadlineLow = "Die eingegebene Zahl ist zu klein."
    static let startInfo = "Jetzt kannst Du Dir eine von den Muscheln aussuchen und mit dem Spiel beginnen."
    static func sumText(_ n: String, _ s: String) -> String { "Bei \(n) Zahlen werden insgesamt \(s) Punkte an den Zahlenhai und an Dich vergeben. " }
    static let shellGroupBox = "Muschelfeld (blau bedeutet \"frei wählbar\"; grau bedeutet \"schon vergeben\")"
    static let normalGroupBox = "Muschelfeld"
    static let listGroupBox = "Spielverlaufstabelle  [ In der Tabelle sind die Primzahlen mit \"(prim)\" markiert ]"
    // Column headers (IDS_ZUG … IDS_REST) and their one-line variants for the summary file.
    static let columns = [" Zug", "Deine\nZahlen", "Zahlenhai-\nZahlen", "Deine\nPunkte", "Hai-\nPunkte", "Rest-\nZahlen"]
    static let columns2 = [" Zug", "Deine Zahlen", "Zahlenhai Zahlen", "Deine Punkte", "Hai Punkte", "Rest Zahlen"]
    static let columnWidths: [CGFloat] = [39, 88, 189, 90, 90, 55]
    // Tooltips
    static let ttStartNew = "Ein neues Spiel starten."
    static let ttEnd = "Spiel beenden."
    static let ttRules = "Spielregeln durchlesen."
    static let ttOK = "Startet das Spiel mit dem eingestellten Zahlenvorrat."
    static let ttOption = "Spieloptionen anzeigen."
    static let ttHelp = "Zeigt Dir die Online-Hilfe des Zahlenhai-Spiels."
    static let ttUndo = "Undo/Backward:\nÜber den \"Rückwärts\"-Knopf kannst Du Deine letzten Züge rückgängig machen\nund einen neuen Weg ausprobieren, um die höchste Punktzahl zu erreichen."
    static let ttRedo = "Redo/Foreward:\nÜber den \"Vorwärts\"-Knopf kannst Du Deine rückgängig gemachten Züge solange wieder vorwärts gehen,\nsolange Du keine Änderung im Spielverlauf vornimmst."
    static let ttLoad = "Lädt ein vorhandenes Spiel."
    static let ttSave = "Speichert das aktuelle Spiel."
    static let ttSwitchStyle = "Wechselt den Anzeigestil (Muscheln oder Zahlen)."
    static func ttRest(_ list: String) -> String { "Der Hai frisst alle Zahlen, die Dir keine Punkte mehr bringen können.\nFolgende Zahlen könnte der Hai sofort fressen: \(list)" }
    // Options dialog
    static let optionsHead = "Um gleich zu starten, kannst Du auch einfach die Enter-Taste drücken oder auf den Button  \"Zum Spiel\"  klicken."
    static let optionsToolTips = "ToolTips für die Muscheln aktivieren\n[Verweilt man mit der Maus etwas länger über einer der blauen Muscheln (mit den noch auswählbaren Zahlen), so wird ein Rechteck (ToolTip) eingeblendet, das u.a. die noch verfügbaren Teiler dieser Zahl anzeigt]."
    static let optionsShowDialog = "Den Spieloptionen-Dialog beim nächsten Programmstart anzeigen."
    static let optionsShowNumbers = "Die zuletzt gewählte Anzahl der auswählbaren Zahlen im Zahlenvorrat beim nächsten Programmstart wieder eintragen."
    static func optionsMaxPoints(_ n: String) -> String {
        "Hier kannst Du die maximal mögliche Punktzahl, und einen Weg dahin, für den eingestellten Zahlenvorrat von \(n) Zahlen berechnen.\nDies könnte aber sehr lange dauern...\n\nStattdessen kannst Du Dir die Werte anzeigen lassen, die wir bereits vorberechnet haben."
    }
    static let gameIdea = "Grips-Spiel: Für ein oder mehrere Spieler ab 10 Jahre.\n\nSpielzeit: Für 20 Zahlen benötigt man nicht länger als 3 Minuten, bei 9.999 Zahlen kann man aber schon über ein Jahr brauchen."
    static let infoText = "Das Programm Zahlenhai entstand als Ergänzung zum Freeware- und Open-Source-Projekt CrypTool: www.cryptool.de"
    static let disclaimer = "Bitte beachte die Lizenzbestimmungen und die Informationen zum Haftungsausschluss für eventuelle Schäden durch das Zahlenhai-Programm.\n(C) 2018 CrypTool Team"
    static let tabRadio1 = "Die maximal mögliche Punktzahl berechnen."
    static let tabRadio2 = "Die besten bisher bekannten Punktzahlen anzeigen."
    static let accelerators = "TAB: Auswahl der Muschel im angezeigten Zahlenblock (eines Reiters).\n\nENTER / LEERTASTE: Auswahl der Zahl der selektierten Muschel per Tastatur.\n\nSHIFT + ALT + C: Verändert das Aussehen der Buttons im Muschelfeld.\n\nSHIFT + ALT + L: Lädt ein vorhandenes Spiel.\n\nSHIFT + ALT + S: Speichert das aktuelle Spiel.\n\n"
    static let selectSearchAlgorithm = "Der Zahlenhai beinhaltet zwei verschiedene Algorithmen für die Suche nach der maximalen Punktzahl: Der ursprünglich verfügbare Brute-Force-Algorithmus wurde um einen Back-Tracking-Algorithmus ergänzt.\n\nMit dem Brute-Force-Algorithmus hat ein 3 GHz Rechner für 20 Zahlen knapp 8 Stunden am Stück gerechnet. Bei 22 Zahlen dauerte das schon ca. 9 Tage. Und bei 30 Zahlen sind es wahrscheinlich Wochen oder Monate.\n\nDer neue Algorithmus ist bedeutend schneller.\n\nWillst Du den neuen Algorithmus verwenden?"
    static func backtrackingResult(_ n: String, _ s: String, _ t: String, _ p: String, _ seq: String) -> String {
        "Um bei \(n) Zahlen die maximal mögliche Punktzahl \(s) zu berechnen, hat das Programm \(t) Sekunden gebraucht.\n\nDie höchste Primzahl ist \(p). Mit dieser Zahl musst Du das Spiel beginnen, um die maximal mögliche Punktzahl erreichen zu können.\n\nDie höchste Punktzahl kannst Du unter anderem mit folgender Zugfolge (Weg) erreichen: \(seq)."
    }
    static func maxPointsNew(_ n: String, _ s: String, _ t: String, _ k: String, _ p: String, _ seq: String) -> String {
        "Um bei \(n) Zahlen die maximal mögliche Punktzahl von \(s) Punkten zu berechnen, hat das Programm \(t) Sekunden benötigt und musste dabei \(k) Knoten durchlaufen.\n\nDie höchste Primzahl ist \(p). Mit dieser Zahl musst Du das Spiel beginnen, um die maximal mögliche Punktzahl erreichen zu können.\n\nDie höchste Punktzahl kannst Du unter anderem mit folgender Zugfolge (Weg) erreichen: \(seq)."
    }
    static let maxPointsHeadline = "Maximale Punktzahl"
    static func searchProgress1(_ alg: String, _ n: Int) -> String { "Der Zahlenhai sucht mit einem \(alg)-Algorithmus nach der bestmöglichen Punktausbeute für \(n) Zahlen." }
    static func searchProgress2(_ s: Int) -> String { "Verstrichene Zeit: \(s) Sekunden" }
    static let searchProgressInfo = "Leider können wir nicht genau vorhersagen, wie lange die Suche dauern wird. Wenn Du möchtest, kannst Du die Suche jederzeit abbrechen."
    static func precalculatedIntro(_ proved: Int, _ total: Int) -> String {
        "Für die Zahlen 1 bis \(proved) kennen wir die optimalen Wege.\nFür die höheren Zahlen \(proved + 1) bis \(total) zeigen wir hier die besten bisher bekannten Werte -- ob diese Werte oberhalb von \(proved) auch optimal sind, wissen wir nicht."
    }
    static func loadFailed(_ f: String) -> String { "Die Datei \"\(f)\" konnte nicht richtig eingelesen werden." }
    static func noSummary(_ f: String, _ dir: String) -> String {
        "Die Datei \"\(f)\" konnte nicht erstellt werden, da Du wahrscheinlich nicht genügend Zugriffsrechte in dem Ordner\n\"\(dir)\" hast.\n"
    }
    static func radioEdit1(_ f: String, _ dir: String) -> String { "Ja,\nin der Datei  \"\(f)\" im Ordner\n\"\(dir)\"." }
    static let fileName = "Zusammenfassung.txt"
}

// MARK: - Game rules (EvoZahlenHai)

struct SharkGame {
    enum Owner: UInt8 { case free = 0, computer = 1, player = 2 }

    private(set) var limit: Int
    private(set) var owner: [Owner]
    private(set) var round = 0
    private(set) var pointsPlayer = 0
    private(set) var pointsComputer = 0
    /// Divisors the shark took in the last round (`computerNumbers`).
    private(set) var lastComputerNumbers: [Int] = []
    /// Numbers the player received, in order (`optimalNumbers`).
    private(set) var playerNumbers: [Int] = []
    private(set) var freeCount: Int

    init(limit: Int) {
        self.limit = limit
        owner = Array(repeating: .free, count: limit + 1)
        freeCount = limit
    }

    var finished: Bool { freeCount == 0 }

    /// `startRound`: the shark takes all free proper divisors (searched up to limit/2); if there is
    /// none, the shark gets the chosen number itself. Returns true if the player got the number.
    @discardableResult
    mutating func startRound(_ choice: Int) -> Bool {
        lastComputerNumbers = []
        var i = 1
        while i < limit / 2 + 1 {
            if owner[i] == .free && choice % i == 0 && choice != i {
                owner[i] = .computer
                pointsComputer += i
                freeCount -= 1
                lastComputerNumbers.append(i)
            }
            i += 1
        }
        round += 1
        if owner[choice] == .free { freeCount -= 1 }
        if lastComputerNumbers.isEmpty {
            owner[choice] = .computer
            pointsComputer += choice
            return false
        }
        owner[choice] = .player
        pointsPlayer += choice
        playerNumbers.append(choice)
        return true
    }

    /// Free proper divisors of `n` (tooltip "Übrige Teiler").
    func freeDivisors(of n: Int) -> [Int] {
        guard n > 1 else { return [] }
        return (1...(n / 2 + 1)).filter { owner[$0] == .free && n % $0 == 0 && n != $0 }
    }

    /// Free multiples of `n` (tooltip "Ist Teiler von"), only for n < limit/2+1, at most 10.
    func freeMultiples(of n: Int) -> [Int] {
        guard n < limit / 2 + 1, owner[n] == .free else { return [] }
        var r: [Int] = []
        var j = 2 * n
        while j <= limit && r.count < 10 {
            if owner[j] == .free { r.append(j) }
            j += n
        }
        return r
    }

    /// Numbers above limit/2 without free divisors ("Haifutter"), from the top down.
    func restNumbers() -> [Int] {
        guard limit >= 1 else { return [] }
        var r: [Int] = []
        var i = limit
        while i > limit / 2 {
            if owner[i] == .free {
                var found = false
                var j = 1
                while j <= i / 2 && !found {
                    if owner[j] == .free { found = i % j == 0 }
                    j += 1
                }
                if !found { r.append(i) }
            }
            i -= 1
        }
        return r
    }

    /// Current points plus all free numbers except primes above limit/2 (brute-force bound).
    func maxPossiblePointsPlayer() -> Int {
        let border = limit / 2 + 1
        var s = pointsPlayer
        for i in 1...max(1, limit) where i <= limit && owner[i] == .free && !(i >= border && Self.isPrime(i)) { s += i }
        return s
    }

    static func isPrime(_ z: Int) -> Bool {
        if z <= 1 { return false }
        var i = 2
        while i * i <= z { if z % i == 0 { return false }; i += 1 }
        return true
    }

    static func maxPrime(_ n: Int) -> Int {
        var z = n
        while z > n / 2 { if isPrime(z) { return z }; z -= 1 }
        return 1
    }
}

struct SharkRow: Identifiable {
    let id: Int
    let cells: [String]
}

// MARK: - Precalculated scores (GameData.txt)

struct SharkGameDataBlock {
    let limit: Int
    let score: String
    let sequence: String
    let sequenceLength: String
    let leadingPrime: String
    let proved: Bool
}

enum SharkGameData {
    static let blocks: [Int: SharkGameDataBlock] = {
        var map: [Int: SharkGameDataBlock] = [:]
        var section = ""
        for raw in CT1GamesData.gameData.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("proved") { section = "proved"; continue }
            if line.hasPrefix("best known") { section = "best known"; continue }
            let f = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, let n = Int(f[0]) else { continue }
            map[n] = SharkGameDataBlock(limit: n, score: f[1], sequence: f[2], sequenceLength: f[3], leadingPrime: f[4], proved: section == "proved")
        }
        return map
    }()
    static var sorted: [SharkGameDataBlock] { blocks.keys.sorted().compactMap { blocks[$0] } }
    static var provedCount: Int { blocks.values.filter(\.proved).count }
}

// MARK: - Searches for the maximum score

final class SharkSearchCancel: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
}

/// zhl: back-tracking search (flomar 2010), ported 1:1.
final class SharkBacktracking {
    private let n: Int
    private var zahlen: [UInt8]          // 0 frei, 1 zahlenhai, 2 spieler
    private var teiler: [[Int]]          // divisors > 1 including the number itself (last)
    private var wegAktuell: [Int]
    private(set) var wegOptimal: [Int] = []
    private(set) var wegOptimalSummeSpieler = 0
    private var summeSpieler = 0
    private var summeZahlenhai = 0
    private var gewaehlt = 0
    private var zusaetzlich = 0
    private var counter = 0
    private let cancel: SharkSearchCancel
    private(set) var aborted = false

    init(n: Int, cancel: SharkSearchCancel) {
        self.n = n
        self.cancel = cancel
        zahlen = Array(repeating: 0, count: n + 1)
        wegAktuell = Array(repeating: 0, count: n + 1)
        teiler = Array(repeating: [], count: n + 1)
        if n >= 1 {
            for i in 1...n {
                var t: [Int] = []
                var j = 2
                while j * j <= i {
                    if i % j == 0 {
                        t.append(j)
                        if i / j != j { t.append(i / j) }
                    }
                    j += 1
                }
                if i != 1 { t.append(i) }
                teiler[i] = t
            }
        }
    }

    private func isPrime(_ z: Int) -> Bool { teiler[z].count == 1 }

    private func maxPrime() -> Int {
        var z = n
        while z > n / 2 { if isPrime(z) { return z }; z -= 1 }
        return 1
    }

    /// Returns false if the search was cancelled.
    func run() -> Bool {
        guard n >= 1 else { return true }
        var rueck: [Int] = []
        _ = zuSpielerAusgewaehlt(maxPrime(), [1], &rueck)
        zahlenZuZahlenhai(&rueck)
        rek()
        return !aborted
    }

    private func rek() {
        if aborted { return }
        counter += 1
        if counter & 0xFFF == 0 && cancel.isCancelled { aborted = true; return }
        if gewaehlt + zusaetzlich == n {
            if wegOptimalSummeSpieler < summeSpieler {
                wegOptimalSummeSpieler = summeSpieler
                wegOptimal = Array(wegAktuell[0..<gewaehlt])
            }
            return
        }
        var i = n
        while i >= 2 {
            if zahlen[i] == 0 {
                var rueck: [Int] = []
                if zuSpielerAusgewaehlt(i, teiler[i], &rueck) {
                    zahlenZuZahlenhai(&rueck)
                    if zusatzZahlenSummeSpieler() + summeSpieler > wegOptimalSummeSpieler {
                        rek()
                    }
                }
                zahlen[i] = 0
                summeSpieler -= i
                for r in rueck { zahlen[r] = 0; summeZahlenhai -= r }
                gewaehlt -= 1
                zusaetzlich -= rueck.count
            }
            i -= 1
        }
    }

    private func zusatzZahlenSummeSpieler() -> Int {
        var anz = (n - gewaehlt - zusaetzlich) / 2
        var i = n
        var s = 0
        while anz > 0 && i >= 1 {
            if zahlen[i] == 0 { s += i; anz -= 1 }
            i -= 1
        }
        return s
    }

    private func zahlenZuZahlenhai(_ rueck: inout [Int]) {
        var i = n
        while i >= n / 2 + 1 {
            if zahlen[i] == 0 {
                let t = teiler[i]
                var found = false
                var j = 0
                while j < t.count - 1 && !found { if zahlen[t[j]] == 0 { found = true }; j += 1 }
                if !found { zuZahlenhai(i); rueck.append(i) }
            }
            i -= 1
        }
        i = n / 2
        while i >= 2 {
            if zahlen[i] == 0 {
                let t = teiler[i]
                var found = false
                var j = 0
                while j < t.count - 1 && !found { if zahlen[t[j]] == 0 { found = true }; j += 1 }
                if !found {
                    var m = 2 * i
                    while m <= n && !found { if zahlen[m] == 0 { found = true }; m += i }
                }
                if !found { zuZahlenhai(i); rueck.append(i) }
            }
            i -= 1
        }
    }

    private func zuZahlenhai(_ i: Int) {
        zahlen[i] = 1
        summeZahlenhai += i
        zusaetzlich += 1
    }

    private func zuSpielerAusgewaehlt(_ i: Int, _ t: [Int], _ rueck: inout [Int]) -> Bool {
        zahlen[i] = 2
        summeSpieler += i
        wegAktuell[gewaehlt] = i
        gewaehlt += 1
        var forShark = false
        for d in t where zahlen[d] == 0 {
            zuZahlenhai(d)
            rueck.append(d)
            forShark = true
        }
        return forShark
    }
}

/// zahl: original brute-force search (SucheNRek) with the same bound and node counting.
final class SharkBruteForce {
    private let n: Int
    private let cancel: SharkSearchCancel
    private(set) var maxEndPoints = 0
    private(set) var nodes: Int64 = 0
    private(set) var best: SharkGame
    private(set) var aborted = false

    init(n: Int, cancel: SharkSearchCancel) {
        self.n = n
        self.cancel = cancel
        best = SharkGame(limit: n)
    }

    func run() -> Bool {
        var g = SharkGame(limit: n)
        if n >= 1 { g.startRound(SharkGame.maxPrime(n)) }
        rek(g)
        return !aborted
    }

    private func rek(_ g: SharkGame) {
        if aborted { return }
        if n >= 1 {
            for idx in 1...n where g.owner[idx] == .free {
                if aborted { return }
                var child = g
                child.startRound(idx)
                if g.maxPossiblePointsPlayer() > maxEndPoints {
                    nodes += 1
                    if nodes & 0xFFF == 0 && cancel.isCancelled { aborted = true; return }
                    rek(child)
                }
            }
        }
        if g.pointsPlayer > maxEndPoints {
            if g.pointsPlayer > best.pointsPlayer { best = g }
            maxEndPoints = g.pointsPlayer
        }
    }
}

// MARK: - Search progress (DlgSearchProgress)

@MainActor
final class SharkSearch: ObservableObject, Identifiable {
    /// Searches still running (cancelled when the game window closes).
    static var running: [SharkSearch] = []
    let id = UUID()
    let backtracking: Bool
    let limit: Int
    @Published var elapsed = 0
    private let start = Date()
    private var timer: Timer?
    let cancelFlag = SharkSearchCancel()
    var onFinish: ((String, String) -> Void)?   // (title, message)

    var algorithmName: String { backtracking ? "Back-Tracking" : "Brute-Force" }

    init(backtracking: Bool, limit: Int) {
        self.backtracking = backtracking
        self.limit = limit
    }

    func begin() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let s = self { s.elapsed = Int(Date().timeIntervalSince(s.start)) } }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Self.running.append(self)
        let n = limit, flag = cancelFlag, bt = backtracking
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = Date()
            var title = SharkText.numberShark, message = ""
            var ok = false
            if bt {
                let s = SharkBacktracking(n: n, cancel: flag)
                ok = s.run()
                let secs = Date().timeIntervalSince(t0)
                let score = s.wegOptimal.reduce(0, +)
                message = SharkText.backtrackingResult(String(n), String(score), String(format: "%01.3f", secs),
                                                       String(s.wegOptimal.first ?? 1), s.wegOptimal.map(String.init).joined(separator: ","))
            } else {
                let s = SharkBruteForce(n: n, cancel: flag)
                ok = s.run()
                let secs = Int(Date().timeIntervalSince(t0))
                title = SharkText.maxPointsHeadline
                message = SharkText.maxPointsNew(CT1Games.sep(n), CT1Games.sep(s.maxEndPoints), CT1Games.sep(secs), CT1Games.sep(s.nodes),
                                                 CT1Games.sep(SharkGame.maxPrime(n)), s.best.playerNumbers.map(String.init).joined(separator: " , "))
            }
            let done = ok
            let (tt, mm) = (title, message)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.timer?.invalidate()
                    SharkSearch.running.removeAll { $0 === self }
                    self.onFinish?(done ? tt : "", done ? mm : "")
                }
            }
        }
    }

    func cancel() { cancelFlag.cancel() }
}

// MARK: - Main dialog model (CMFCZahlenHaiDlg)

struct SharkSummary: Identifiable {
    let id = UUID()
    let headline: String
    let text: String
    let fileName: String
    let folder: String
}

enum SharkSheet: Identifiable {
    case options, rules, summary(SharkSummary)
    var id: String {
        switch self {
        case .options: return "options"
        case .rules: return "rules"
        case .summary(let s): return s.id.uuidString
        }
    }
}

@MainActor
final class SharkGameModel: ObservableObject {
    static let maxNumbers = 9999
    static let buttonsPerTab = 30

    @Published var game: SharkGame { didSet { restCache = nil } }
    private var restCache: [Int]?
    @Published var rows: [SharkRow] = []
    @Published var moves: [Int] = []
    @Published var limitText: String
    @Published var inputLocked = false
    @Published var playing = false
    @Published var seconds = 0
    @Published var shellStyle = true
    @Published var tab = 0
    @Published var pictureIndex = 0
    @Published var sheet: SharkSheet?

    // Options (CT1: registry HKCU\Software\Zahlenhai\Settings)
    @Published var playerName: String { didSet { updateTitle() } }
    @Published var showToolTips: Bool
    @Published var showOptionsAtStart: Bool
    @Published var rememberLimit: Bool

    private var winnerShown = false
    /// CT1 `checkList`: set by the first click after "Neues Spiel"/"Laden" (starts the clock).
    private var started = false
    private var timer: Timer?
    weak var window: NSWindow?

    static let pictures = ["hai01.jpg", "Hai04-vers5.jpg", "shark.jpg", "HaiAnAngel.jpg"] + (1...9).map { String(format: "Zahlenhai%02d.jpg", $0) }

    private static let defaultsPrefix = "CT1Zahlenhai."

    init() {
        let d = UserDefaults.standard
        let p = Self.defaultsPrefix
        let hasSettings = d.object(forKey: p + "OptionenSettings") != nil
        var limit = 20
        var name = d.string(forKey: p + "Spielername") ?? ""
        let showOpt = hasSettings ? d.bool(forKey: p + "OptionenSettings") : true
        let remember = hasSettings ? d.bool(forKey: p + "Startnummer") : true
        if hasSettings && remember {
            let v = d.integer(forKey: p + "Startzahl")
            if v >= 1 && v <= Self.maxNumbers { limit = v }
        }
        if !showOpt { name = "" }
        game = SharkGame(limit: limit)
        limitText = String(limit)
        playerName = name
        showToolTips = hasSettings ? d.bool(forKey: p + "ToolTipSettings") : false
        showOptionsAtStart = showOpt
        rememberLimit = remember
    }

    func attach(window w: NSWindow) {
        window = w
        updateTitle()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopTimer()
                self?.writeSettings()
                SharkSearch.running.forEach { $0.cancel() }
            }
        }
        if showOptionsAtStart {
            DispatchQueue.main.async { [weak self] in self?.sheet = .options }
        }
    }

    var title: String {
        playerName.isEmpty ? SharkText.numberShark + SharkText.titleVersion
            : SharkText.numberShark + SharkText.sharkAgainst + playerName + SharkText.titleVersion
    }

    func updateTitle() { window?.title = title }

    // MARK: Derived state

    var limit: Int { game.limit }
    var tabCount: Int { (limit + Self.buttonsPerTab - 1) / Self.buttonsPerTab }
    func tabTitle(_ i: Int) -> String {
        let a = 1 + i * Self.buttonsPerTab
        return "\(a)-\(min(a + Self.buttonsPerTab - 1, limit))"
    }
    var timeText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    var ledText: String { "\(game.pointsPlayer):\(game.pointsComputer)" }
    var sumText: String { SharkText.sumText(CT1Games.sep(limit), CT1Games.sep(limit + limit * (limit - 1) / 2)) }
    var restNumbers: [Int] {
        if let c = restCache { return c }
        let r = game.restNumbers()
        restCache = r
        return r
    }
    var canUndo: Bool { game.round > 0 }
    var canRedo: Bool { game.round < moves.count }

    var restToolTip: String {
        let r = restNumbers
        var s = r.prefix(10).map(String.init).joined(separator: ", ")
        if r.count >= 10 { s += "....." }
        return SharkText.ttRest(s)
    }

    /// Tooltip of a shell (CMFCZahlenHaiDlg::updateButtons).
    func toolTip(for n: Int) -> String {
        let factors = game.freeDivisors(of: n).map(String.init).joined(separator: ", ")
        let multiples = game.freeMultiples(of: n)
        var isFactor = multiples.map(String.init).joined(separator: ", ")
        if multiples.count == 10 { isFactor += "...." }
        let number = "Zahl: \(n)"
        if factors.isEmpty {
            let f = isFactor.isEmpty ? "Teilt keine andere Zahl." : isFactor
            return "\(number)\nKeine Teiler mehr vorhanden!\nIst Teiler von: \(f)"
        }
        let t = isFactor.isEmpty ? "Teilt keine andere Zahl." : "Ist Teiler von: \(isFactor)"
        return "\(number)\nÜbrige Teiler: \(factors)\n\(t) "
    }

    // MARK: Timer

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.seconds += 1 }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Actions

    /// OK button: take over the size of the number pool.
    func confirmLimit() {
        let digits = limitText.filter(\.isNumber)
        let v = Int(digits.prefix(6)) ?? 0
        if v < 1 || v > Self.maxNumbers {
            let head = v > Self.maxNumbers ? SharkText.validInputHeadline : SharkText.validInputHeadlineLow
            limitText = v > Self.maxNumbers ? String(Self.maxNumbers) : "1"
            CT1Games.messageBox(SharkText.invalidInput(CT1Games.sep(Self.maxNumbers)), title: head, style: .warning, on: window)
            return
        }
        game = SharkGame(limit: v)
        rows = []
        moves = []
        tab = 0
        inputLocked = true
        CT1Games.messageBox(SharkText.startInfo, title: SharkText.numberShark, on: window) { [weak self] in
            self?.startTimer()
        }
    }

    /// Click on a shell.
    func pick(_ n: Int) {
        guard n >= 1, n <= limit, game.owner[n] == .free else { return }
        if !started {
            startTimer()
            started = true
            playing = true
        }
        writeIntoUndo(n)
        afterUpdate()
    }

    private func writeIntoUndo(_ n: Int) {
        moves = Array(moves.prefix(game.round)) + [n]
        game.startRound(n)
        rows.append(makeRow(n, game))
    }

    private func makeRow(_ choice: Int, _ g: SharkGame) -> SharkRow {
        func p(_ v: Int) -> String { "\(v)" + (SharkGame.isPrime(v) ? SharkText.primeInfo : "") }
        let found = !g.lastComputerNumbers.isEmpty
        let player = found ? p(choice) : "0"
        let shark = found ? g.lastComputerNumbers.map(p).joined(separator: ", ") : p(choice)
        return SharkRow(id: g.round, cells: [String(g.round), player, shark, String(g.pointsPlayer),
                                             String(g.pointsComputer), String(g.freeCount)])
    }

    /// "Haifutter": the shark takes every number above n/2 without free divisors.
    func feedShark() {
        for i in restNumbers where game.owner[i] == .free { writeIntoUndo(i) }
        afterUpdate()
    }

    func undo() {
        guard game.round > 0 else { return }
        winnerShown = false
        let last = game.round - 1
        replay(Array(moves.prefix(last)))
        afterUpdate()
    }

    func redo() {
        guard canRedo else { return }
        let v = moves[game.round]
        game.startRound(v)
        rows.append(makeRow(v, game))
        afterUpdate()
    }

    private func replay(_ list: [Int]) {
        var g = SharkGame(limit: limit)
        var r: [SharkRow] = []
        for m in list {
            g.startRound(m)
            r.append(makeRow(m, g))
        }
        game = g
        rows = r
    }

    func newGame() {
        winnerShown = false
        playing = false
        started = false
        game = SharkGame(limit: limit)
        rows = []
        moves = []
        pictureIndex = (pictureIndex + 1) % Self.pictures.count
        stopTimer()
        seconds = 0
        inputLocked = false
    }

    func toggleStyle() { shellStyle.toggle() }

    func endProgram() {
        writeSettings()
        stopTimer()
        window?.close()
    }

    private func afterUpdate() {
        guard !winnerShown, game.finished else { return }
        stopTimer()
        winnerShown = true
        sheet = .summary(makeSummary())
    }

    // MARK: Game summary (CGameSummary)

    static var summaryFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Zahlenhai")
    }

    private var summaryFileName: String {
        "\(limit)_\(game.pointsPlayer)_\(playerName.isEmpty ? "name" : playerName)_" + SharkText.fileName
    }

    private func makeSummary() -> SharkSummary {
        let pp = game.pointsPlayer, pc = game.pointsComputer, n = limit
        let count = SharkGameData.blocks.count
        let best = Int(SharkGameData.blocks[n]?.score ?? "") ?? 0
        let sP = CT1Games.sep(pp), sC = CT1Games.sep(pc), sN = CT1Games.sep(n), sB = CT1Games.sep(best)
        var headline: String, text: String
        if pp > pc {
            headline = SharkText.playerWinsHeadline
            if n <= 2 * count && best != 0 {
                if pp == best { text = SharkText.playerWinsOptimal(sP, sN, sN) }
                else if pp > best { text = SharkText.playerWinsOptimal2(sP, sB, sN) }
                else if n <= count { text = SharkText.playerWins(sN, sP, sN, sB) }
                else { text = SharkText.playerWins3(sN, sP, sN, sB) }
            } else {
                text = SharkText.playerWins2(sN, sP)
            }
        } else if pp < pc {
            headline = SharkText.computerWinsHeadline
            text = n == 1 ? SharkText.numberOne(sC, sP) : SharkText.computerWins(sC, sP)
        } else {
            headline = SharkText.drawHeadline
            text = SharkText.draw(sP)
        }
        return SharkSummary(headline: headline, text: text, fileName: summaryFileName, folder: Self.summaryFolder.path)
    }

    /// Called when the summary dialog is closed.
    func summaryClosed(writeFile: Bool) {
        sheet = nil
        guard writeFile else { return }
        DispatchQueue.main.async { [weak self] in self?.writeLogFile() }
    }

    /// writeLogFile: game protocol "<n>_<points>_<name>_Zusammenfassung.txt".
    func writeLogFile() {
        let name = summaryFileName
        let folder = Self.summaryFolder
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMMM dd, yyyy, HH:mm"
        var out = "\r\n" + name
        out += "\r\n\r\nDatum/Uhrzeit:                " + df.string(from: Date())
        out += "\r\n\r\nName des Spielers:            " + playerName
        out += "\r\n\r\nZahlenvorrat:                 " + String(limit)

        var heads = SharkText.columns2
        var nMax = Array(repeating: 0, count: 6)
        for r in rows {
            for j in 0..<6 {
                let text = r.cells[j]
                nMax[j] = heads[j].count
                while heads[j].count < text.count { heads[j] = " " + heads[j] }
                if nMax[j] < 2 * text.count { nMax[j] = 2 * text.count }
            }
        }
        out += "\r\n\r\nDiese Datei zeigt die einzelnen Spielzüge und welche Punktzahl sich daraus für\r\nDich und den Zahlenhai ergeben haben.\r\nDie Tabelle enthält die gleichen Infos wie die Spielverlaufstabelle im Spielfenster.\r\n\r\n"
        let head = heads.joined(separator: " | ") + " |\r\n"
        out += head
        var allNumbers = ""
        for (i, r) in rows.enumerated() {
            var line = "\r\n"
            for j in 0..<6 {
                var cell = r.cells[j]
                while cell.count < nMax[j] { cell = " " + cell }
                line += cell + " | "
                if j == 1 && r.cells[j] != "0" { allNumbers += r.cells[j] + " , " }
                if i != 0 && i % 50 == 0 && j == 0 && rows.count > 50 { out += "\r\n\r\n" + head }
            }
            out += line
        }
        if rows.count >= 60 { out += "\r\n\r\n" + head }
        if allNumbers.count >= 2 { allNumbers.removeLast(2) }
        allNumbers = allNumbers.replacingOccurrences(of: SharkText.primeInfo, with: "")
        out += "\r\n\r\nPunkte des Spielers:          " + String(game.pointsPlayer)
        out += "\r\nDeine gewählten Zahlen:       " + allNumbers
        out += "\r\nPunkte des Zahlenhais:        " + String(game.pointsComputer)
        out += "\r\nBenötigte Züge:               " + String(game.round)
        if game.pointsPlayer > game.pointsComputer {
            out += "\r\nVorsprung:                    " + String(game.pointsPlayer - game.pointsComputer)
        } else if game.pointsPlayer < game.pointsComputer {
            out += "\r\nRückstand:                    " + String(game.pointsComputer - game.pointsPlayer)
        }
        if limit <= SharkGameData.blocks.count, let b = SharkGameData.blocks[limit] {
            out += "\r\nMaximal mögliche Punkte für Dich:   " + b.score
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try out.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        } catch {
            CT1Games.messageBox(SharkText.noSummary(name, folder.path), title: SharkText.numberShark, on: window)
        }
    }

    // MARK: Save / load ("Zahlenhai.save")

    static var saveURL: URL { summaryFolder.appendingPathComponent(SharkText.numberShark + ".save") }

    func saveGame() {
        var s = String(limit) + ","
        for m in moves.prefix(game.round) { s += String(m) + "," }
        try? FileManager.default.createDirectory(at: Self.summaryFolder, withIntermediateDirectories: true)
        try? s.write(to: Self.saveURL, atomically: true, encoding: .utf8)
    }

    func loadGame() {
        let file = SharkText.numberShark + ".save"
        func fail() { CT1Games.messageBox(SharkText.loadFailed(file), title: SharkText.numberShark, style: .warning, on: window) }
        guard let s = try? String(contentsOf: Self.saveURL, encoding: .utf8) else { fail(); return }
        let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard let first = parts.first, let n = Int(first), n >= 1, n <= Self.maxNumbers else { fail(); return }
        var list: [Int] = []
        for p in parts.dropFirst() where !p.isEmpty {
            guard let v = Int(p), v >= 1, v <= n, list.count < n else { fail(); return }
            list.append(v)
        }
        newGame()
        limitText = String(n)
        var g = SharkGame(limit: n)
        var r: [SharkRow] = []
        for m in list where g.owner[m] == .free {
            g.startRound(m)
            r.append(makeRow(m, g))
        }
        game = g
        rows = r
        moves = Array(list.prefix(game.round))
        tab = 0
        playing = true
        inputLocked = true
        afterUpdate()
    }

    // MARK: Settings

    func writeSettings() {
        let d = UserDefaults.standard
        let p = Self.defaultsPrefix
        d.set(showOptionsAtStart, forKey: p + "OptionenSettings")
        d.set(showToolTips, forKey: p + "ToolTipSettings")
        d.set(playerName, forKey: p + "Spielername")
        d.set(rememberLimit, forKey: p + "Startnummer")
        d.set(limit, forKey: p + "Startzahl")
    }
}
