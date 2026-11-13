import AppKit
import SwiftUI

// Port of CT1's "The Number Shark" (NumberShark 1.2.4, MFC): EvoZahlenHai (rules), zhl (back-tracking
// search), zahl (brute-force search), ZahlenHaiOptionen/GameSummary/... (dialogs). English captions
// are taken from the English resources of MFC-ZahlenHai.rc.

// MARK: - English texts (MFC-ZahlenHai.rc, LANG_ENGLISH)

enum SharkText {
    static let numberShark = "Number Shark"
    static let titleVersion = " - Version 1.2.4"
    static let sharkAgainst = " against "
    static let primeInfo = "(prime)"
    static let rules = "Description:\n - At the beginning of the Number Shark game you choose the size of the shell square, this is the amount of numbers you want to play with.\n    We name the size of the shell square with \"n\" and call it the \"count of selectable numbers\". The pool of numbers starts with 1\n    and ends with the number which you have chosen for the size of the shell square (we suggest the number 20 for the beginning).\n    After that all numbers from the shell square will be given to either you or the computer (\"Number Shark\").\n    You can read the rules of how the numbers are divided below in the text.\n - By default, there are 20 numbers in the shell square. As total number you can select every number from 1 to 9999 for n.\n\nGoal of the game:\n - It is your goal to achieve a higher score than the sum of the numbers that were eaten by the Number Shark.\n\nRules:\n - You always have the first turn, i.e. you are starting the first round.\n - In this round you can choose any of the n numbers from the shell square.\n - The Number Shark gets every available real factor of the number selected by you, if they have not been chosen yet\n    (6 for example is divisible by 1, 2, 3 and 6. The real factors are 1, 2 and 3).\n - In all subsequent rounds you can only choose numbers which have not been chosen by you,\n    or were eaten by the Number Shark in previous rounds (i.e. only the blue shells).\n - BUT: The Number Shark may never miss out!\n - If you choose a number which has no more factors, then the Number Shark gets your chosen number and you get 0 points in this round.\n\n"
    static let rules2 = "While playing the game you can make the shells on the buttons visible and invisible by pressing SHIFT+ALT+C on your keyboard.\nThis can help you to read the numbers on the buttons better and to make the game a bit faster.\n\nYou can get additional help and information by pressing the F1 button.\n\nThe online help contains a operation manual, a commented sample game course, some information about how the game was developed,\nand a challenge for you, which gives you the chance to help us improve the game.\n"
    static func playerWins(_ n: String, _ p: String, _ n2: String, _ best: String) -> String {
        "Congratulation, you have won against the Number Shark!\n\n If you are looking for a bigger challenge, then try a higher number than \(n).\n\nYou achieved \(p) points. The highest possible score with \(n2) numbers would have been \(best)."
    }
    static func playerWins2(_ n: String, _ p: String) -> String {
        "Congratulation, you have won against the Number Shark!\n\nIf you are looking for a bigger challenge, then try a higher number than \(n).\n\nYou achieved \(p) points."
    }
    static func playerWins3(_ n: String, _ p: String, _ n2: String, _ best: String) -> String {
        "Congratulation, you have won against the Number Shark!\n\n If you are looking for a bigger challenge, then try a higher number than \(n).\n\nYou achieved \(p) points. Until now the highest score we achieved with \(n2) numbers was \(best)."
    }
    static func playerWinsOptimal(_ p: String, _ n: String, _ n2: String) -> String {
        "Congratulation, you have won against the Number Shark!\n\nWith \(p) points you even achieved the highest possible score with \(n) numbers.\n\nIf you are looking for a bigger challenge, then try a higher number than \(n2)."
    }
    static func playerWinsOptimal2(_ p: String, _ best: String, _ n: String) -> String {
        "Congratulation, you have won against the Number Shark!\n\nWith \(p) points you even achieved a higher score than we did. Our best score was \(best) points with \(n) numbers.\n\nPlease send the summary of the game to esslinger@fb5.uni-siegen.de."
    }
    static func computerWins(_ c: String, _ p: String) -> String {
        "This time the Number Shark won :,-(\n\n It has beaten you with \(c) to \(p) points.\n\n Go -- Try again!"
    }
    static func numberOne(_ c: String, _ p: String) -> String {
        "This time the Number Shark won :,-(\n\nIt has beaten you with \(c) to \(p) points.\n\nYou can't win with only one number in the shell square.\n\n Go -- Try again!"
    }
    static func draw(_ p: String) -> String {
        "Draw!?!\n\nThis happens only very seldom!\n\nYou and the Number Shark have \(p) points each."
    }
    static let drawHeadline = "Draw!"
    static let computerWinsHeadline = "You didn't win!"
    static let playerWinsHeadline = "You have won!"
    static func invalidInput(_ max: String) -> String { "In the Number Shark game you can play with numbers between 1 and \(max)!" }
    static let validInputHeadline = "The entered number is too big!"
    static let validInputHeadlineLow = "The entered number is to low."
    static let startInfo = "Now you can choose one of the shells to start with the game."
    static func sumText(_ n: String, _ s: String) -> String { "With \(n) numbers: \(s) points can be assigned in total to you and to the Number Shark." }
    static let shellGroupBox = "Shell square (blue means \"still free to choose\"; gray means \"already distributed and eaten up\")"
    static let normalGroupBox = "Shell square"
    static let listGroupBox = "Course of the game -  [ \"prime\" marks a prime number ]"
    // Column headers (IDS_ZUG … IDS_REST) and their one-line variants for the summary file.
    static let columns = ["Move", "Your\nchoice", "Number Shark's\nchoice", "Your\npoints", "Number Shark's\npoints", "Remaining\nnumbers"]
    static let columns2 = ["Move", "Your choice", "Number Shark's choice", "Your points", "Number Shark's points", "Remaining numbers"]
    static let columnWidths: [CGFloat] = [39, 88, 189, 90, 90, 55]
    // Tooltips
    static let ttStartNew = "Start a new game."
    static let ttEnd = "Finish the game."
    static let ttRules = "Read the rules."
    static let ttOK = "Start the game with the selected number pool."
    static let ttOption = "Show the game options."
    static let ttHelp = "Shows you the help for the Number Shark game."
    static let ttUndo = "With \"Undo\" you can repeat previous rounds if you want to choose other numbers."
    static let ttRedo = "With \"Redo\" you can go forward through the game as many steps as you went back in the game via \"Undo\"."
    static let ttLoad = "Loads an existing game."
    static let ttSave = "Saves the current game."
    static let ttSwitchStyle = "Changes the display style (shells or numbers)."
    static func ttRest(_ list: String) -> String { "The Number Shark eats all numbers from which you can't get any more points. The Number Shark could eat the following numbers at once: \(list)" }
    // Options dialog
    static let optionsHead = "To start immediately just press \"Enter\" or press the  \"To the game\"  button."
    static let optionsToolTips = "Activate the tooltips for the shells\n[If you place the cursor a bit longer over one of the blue shells (the ones with the still active numbers), a little window (tooltip) opens and provides you with information, e.g. the factors still available for this number]."
    static let optionsShowDialog = "Show the \"Game options\" dialog at the next program start."
    static let optionsShowNumbers = "Remember the last total number of the number stack for the next program start."
    static func optionsMaxPoints(_ n: String) -> String {
        "Here you can calculate the maximum score for your selected number stack of \(n) numbers. But this might take a while...\n\nInstead, we could immediately show you the scores we have precalculated already."
    }
    static let gameIdea = "It's a savvy game for one or more players from age 10.\n\nPlay time: You shouldn't need more than 3 minutes for 20 numbers, but 9,999 numbers might take you more than a year."
    static let infoText = "The Number Shark program was created as an addition to the freeware and open source project CrypTool: www.cryptool.com"
    static let disclaimer = "Please note the terms of license and the information regarding non liability for any damage arising from the use of the Number Shark program.\n(C) 2018 CrypTool Team"
    static let tabRadio1 = "Calculate the maximum score."
    static let tabRadio2 = "Show the best known scores."
    static let accelerators = "TAB: Selects the next shell within the shown number block (of one tab).\n\nENTER / SPACE: Choose the number of the selected shell via keyboard.\n\nSHIFT + ALT + C: Changes the style of the buttons in the shell square.\n\nSHIFT + ALT + L: Loads an existing game.\n\nSHIFT + ALT + S: Saves the current game.\n\n"
    static let selectSearchAlgorithm = "The Number Shark contains two different algorithms to determine the maximum number of points possible: The originally available brute-force algorithm was complemented by a new back-tracking algorithm.\n\nUsing the brute-force algorithm, a 3 GHz PC had to calculate about 9 hours for 20 numbers. For 22 numbers the calculation took about 9 days. And we believe it will take weeks or months for 30 numbers.\n\nThe new algorithm is considerably faster.\n\nDo you want to use the new algorithm?"
    static func backtrackingResult(_ n: String, _ s: String, _ t: String, _ p: String, _ seq: String) -> String {
        "To calculate for \(n) numbers the highest score of \(s) points, the program spent \(t) seconds.\n\nThe highest prime number here is \(p). You should start the game with this prime to be able to reach the maximum score.\n\nTo achieve the highest score, you can choose the numbers in this order: \(seq)\n\n"
    }
    static func maxPointsNew(_ n: String, _ s: String, _ t: String, _ k: String, _ p: String, _ seq: String) -> String {
        "To calculate for \(n) numbers the highest score of \(s) points, the program spent \(t) seconds. It had to pass through \(k) knots.\n\nThe highest prime number here is \(p). You must start the game with this prime to be able to reach the maximum score.\n\nTo achieve the highest score, you can choose the numbers in this order: \(seq)"
    }
    static let maxPointsHeadline = "Highest possible score"
    static func searchProgress1(_ alg: String, _ n: Int) -> String { "The Number Shark is using a \(alg) algorithm to find the highest possible score for \(n) numbers." }
    static func searchProgress2(_ s: Int) -> String { "Elapsed time: \(s) seconds" }
    static let searchProgressInfo = "Unfortunately we cannot predict how much time the search will take, but you can cancel the search at any time."
    static func precalculatedIntro(_ proved: Int, _ total: Int) -> String {
        "For numbers 1 through \(proved) we know optimal ways to win.\nFor the higher numbers \(proved + 1) through \(total) we show the best known results already precalculated. However, we don't know whether these results from \(proved) up are optimal."
    }
    static func loadFailed(_ f: String) -> String { "The file \"\(f)\" could not be loaded." }
    static func noSummary(_ f: String, _ dir: String) -> String {
        "The file \"\(f)\" could not be written. Probably you do not have enough rights in the folder\n\"\(dir)\".\n"
    }
    static func radioEdit1(_ f: String, _ dir: String) -> String { "Yes\nas \"\(f)\" in the folder\n\"\(dir)\". " }
    static let fileName = "Summary.txt"
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

    /// Free proper divisors of `n` (tooltip "This time he would eat").
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

    var algorithmName: String { backtracking ? "back-tracking" : "brute-force" }

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
        let number = "Number: \(n)"
        if factors.isEmpty {
            let f = isFactor.isEmpty ? "Does not divide any other number." : isFactor
            return "\(number)\nNo more factors left!\nIs a factor of: \(f)"
        }
        let t = isFactor.isEmpty ? "Does not divide any other number." : "Is a factor of: \(isFactor)"
        return "\(number)\nThis time he would eat: \(factors)\n\(t)"
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
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Number Shark")
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

    /// writeLogFile: game protocol "<n>_<points>_<name>_Summary.txt".
    func writeLogFile() {
        let name = summaryFileName
        let folder = Self.summaryFolder
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMMM dd, yyyy, HH:mm"
        var out = "\r\n" + name
        out += "\r\n\r\nDate/Time:                   " + df.string(from: Date())
        out += "\r\n\r\nPlayer's name:               " + playerName
        out += "\r\n\r\nNumber pool:                 " + String(limit)

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
        out += "\r\n\r\nThis file shows you every single move and the score of both players.\r\nThe chart contains the same information as the \"course of the game\" chart in the game dialog.\r\n\r\n"
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
        out += "\r\n\r\nPlayer's points:             " + String(game.pointsPlayer)
        out += "\r\nYour chosen numbers: " + allNumbers
        out += "\r\nNumber Shark points:         " + String(game.pointsComputer)
        out += "\r\nRequired moves:              " + String(game.round)
        if game.pointsPlayer > game.pointsComputer {
            out += "\r\nYour lead:                   " + String(game.pointsPlayer - game.pointsComputer)
        } else if game.pointsPlayer < game.pointsComputer {
            out += "\r\nBehind:                      " + String(game.pointsComputer - game.pointsPlayer)
        }
        if limit <= SharkGameData.blocks.count, let b = SharkGameData.blocks[limit] {
            out += "\r\nHighest possible score for you:" + b.score
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try out.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        } catch {
            CT1Games.messageBox(SharkText.noSummary(name, folder.path), title: SharkText.numberShark, on: window)
        }
    }

    // MARK: Save / load ("Number Shark.save")

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
