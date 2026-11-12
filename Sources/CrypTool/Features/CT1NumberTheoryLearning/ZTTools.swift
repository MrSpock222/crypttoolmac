import SwiftUI
import CTBigNum

/// The interactive ("Ausprobieren") parts attached to ZT pages.
enum ZTTool: String, CaseIterable {
    case divisorPairs, divides, divisorSet, gcdSets, trialDivision, sieve, factorize, hilbert, divisorCount, gcdFactor
    case linearCombination, subtractiveGcd, euclid, extEuclid, gcdMany, lcm
    case divRest, congruence, residueClass, modTables, checkNine, crossSums
    case units, inverse, linearCongruence, phiTable, phi, crt, crtMap, eulerFermat, squareMultiply
    case order, primitiveRoots
    case mersenneFermat, fermatTest, carmichael, millerRabin
    case caesar, multiplicative, frequency, textToNumber, rsa, rabin, diffieHellman, elgamal
    case fermatFactor, birthday, rhoSequence, pollardRho, pollardPm1
    case dlogEnum, bsgs

    var title: String {
        switch self {
        case .divisorPairs: return "Teiler und Komplementärteiler"
        case .divides: return "Teilbarkeit a | b"
        case .divisorSet: return "Teilermenge"
        case .gcdSets: return "ggT über Teilermengen"
        case .trialDivision: return "Probedivision"
        case .sieve: return "Sieb des Eratosthenes"
        case .factorize: return "Primfaktorzerlegung"
        case .hilbert: return "Primzahlen in H = {4n + 1}"
        case .divisorCount: return "Anzahl der Teiler"
        case .gcdFactor: return "ggT und kgV mit Hilfe der PFZ"
        case .linearCombination: return "Vielfachsummen a·x + b·y"
        case .subtractiveGcd: return "ggT(a, b) = ggT(b, a – b)"
        case .euclid: return "Euklidischer Algorithmus"
        case .extEuclid: return "Erweiterter Euklidischer Algorithmus"
        case .gcdMany: return "ggT mehrerer Zahlen"
        case .lcm: return "kgV"
        case .divRest: return "Division mit Rest"
        case .congruence: return "Kongruenz modulo m"
        case .residueClass: return "Restklasse und Standardvertreter"
        case .modTables: return "Verknüpfungstafeln in ℤm"
        case .checkNine: return "Rechenkontrolle modulo 9 und 11"
        case .crossSums: return "Quersummen"
        case .units: return "Prime Restklassen ℤm*"
        case .inverse: return "Invertieren mit Euklid"
        case .linearCongruence: return "Kongruenz a·x ≡ b mod m lösen"
        case .phiTable: return "Werte der Euler-Funktion"
        case .phi: return "Euler-Funktion φ(n)"
        case .crt: return "Chinesischer Restsatz (Uhren verstellen)"
        case .crtMap: return "Zerlegung ℤn → ℤm₁ × … × ℤmₖ"
        case .eulerFermat: return "Euler-Fermat"
        case .squareMultiply: return "Schnelles modulares Potenzieren"
        case .order: return "Ordnung und Erzeugnis ⟨a⟩"
        case .primitiveRoots: return "Primitive Restklassen finden"
        case .mersenneFermat: return "Mersenne- und Fermatzahlen"
        case .fermatTest: return "Fermat-Test"
        case .carmichael: return "Carmichael-Zahlen"
        case .millerRabin: return "Miller-Rabin-Test"
        case .caesar: return "Cäsar"
        case .multiplicative: return "V(x) = a·x + b (mod 27)"
        case .frequency: return "Häufigkeitsanalyse"
        case .textToNumber: return "Text als Zahl"
        case .rsa: return "RSA"
        case .rabin: return "Rabin"
        case .diffieHellman: return "Diffie-Hellman"
        case .elgamal: return "ElGamal"
        case .fermatFactor: return "Fermat-Faktorisierung"
        case .birthday: return "Geburtstagsparadoxon"
        case .rhoSequence: return "Folge xᵢ₊₁ = xᵢ² + c"
        case .pollardRho: return "Pollards Rho-Faktorisierung"
        case .pollardPm1: return "Pollards p–1-Faktorisierung"
        case .dlogEnum: return "Diskreter Logarithmus durch Enumeration"
        case .bsgs: return "Babystep-Giantstep"
        }
    }

    /// (label, default value, wide field)
    var fields: [(String, String, Bool)] {
        switch self {
        case .divisorPairs: return [("n", "36", false)]
        case .divides: return [("a", "5", false), ("b", "-15", false)]
        case .divisorSet: return [("a", "-12", false)]
        case .gcdSets: return [("a", "-6", false), ("b", "15", false)]
        case .trialDivision: return [("n", "89", true)]
        case .sieve: return []
        case .factorize: return [("n", "360", true)]
        case .hilbert: return [("n", "441", false), ("Grenze", "100", false)]
        case .divisorCount: return [("n", "360", false)]
        case .gcdFactor: return [("a", "360", false), ("b", "84", false)]
        case .linearCombination: return [("a", "12", false), ("b", "18", false)]
        case .subtractiveGcd: return [("a", "91", false), ("b", "35", false)]
        case .euclid: return [("a", "1071", false), ("b", "1029", false)]
        case .extEuclid: return [("a", "99", false), ("b", "78", false)]
        case .gcdMany: return [("Zahlen", "84, 126, 210", true)]
        case .lcm: return [("Zahlen", "4, 6, 10", true)]
        case .divRest: return [("a", "-17", false), ("b", "5", false)]
        case .congruence: return [("a", "13", false), ("b", "1", false), ("m", "12", false)]
        case .residueClass: return [("a", "-25", false), ("m", "2", false)]
        case .modTables: return [("m", "6", false)]
        case .checkNine: return [("a", "1234", false), ("b", "5678", false)]
        case .crossSums: return [("x", "5214", true), ("k", "1", false)]
        case .units: return [("m", "12", false)]
        case .inverse: return [("a", "7", false), ("m", "26", false)]
        case .linearCongruence: return [("a", "6", false), ("b", "4", false), ("m", "10", false)]
        case .phiTable: return [("bis n", "36", false)]
        case .phi: return [("n", "360", true)]
        case .crt: return [("Reste a₁, a₂, …", "2, 3, 2", true), ("Moduln m₁, m₂, …", "3, 5, 7", true)]
        case .crtMap: return [("Moduln", "3, 4", true)]
        case .eulerFermat: return [("a", "3", false), ("m", "10", false)]
        case .squareMultiply: return [("a", "7", false), ("Exponent", "560", false), ("Modul", "561", false)]
        case .order: return [("a", "2", false), ("m", "13", false)]
        case .primitiveRoots: return [("m", "13", false)]
        case .mersenneFermat: return [("n bis", "31", false), ("k bis", "6", false)]
        case .fermatTest: return [("n", "341", false), ("Basen a", "2, 3", true)]
        case .carmichael: return [("Grenze", "100000", false)]
        case .millerRabin: return [("n", "561", false), ("a", "2", false)]
        case .caesar: return [("Text", "ZAHLENTHEORIE", true), ("Schlüssel b", "3", false)]
        case .multiplicative: return [("Text", "ZAHLENTHEORIE", true), ("a", "5", false), ("b", "3", false)]
        case .frequency: return [("Text", "DIE ZAHLENTHEORIE IST DIE KOENIGIN DER MATHEMATIK", true)]
        case .textToNumber: return [("Text", "ZAHL", true), ("Grenze G", "1000000", false)]
        case .rsa: return [("p", "47", false), ("q", "59", false), ("b (privat)", "157", false), ("Nachricht n", "920", false)]
        case .rabin: return [("p", "7", false), ("q", "11", false), ("Nachricht n", "20", false)]
        case .diffieHellman: return [("p", "23", false), ("g", "5", false), ("x (Alice)", "6", false), ("y (Bob)", "15", false)]
        case .elgamal: return [("p", "23", false), ("g", "5", false), ("b (Alice)", "6", false), ("n", "10", false), ("k (Bob)", "3", false)]
        case .fermatFactor: return [("n", "5959", false)]
        case .birthday: return [("k", "23", false), ("N", "365", false)]
        case .rhoSequence: return [("n", "55", false), ("x₀", "2", false), ("c", "1", false)]
        case .pollardRho: return [("n", "8051", true), ("x₀", "2", false), ("c", "1", false)]
        case .pollardPm1: return [("n", "1403", true), ("B", "10", false), ("a", "2", false)]
        case .dlogEnum: return [("g", "2", false), ("a", "9", false), ("p", "11", false)]
        case .bsgs: return [("g", "3", false), ("a", "13", false), ("p", "17", false)]
        }
    }

    func compute(_ v: [String]) throws -> String {
        typealias A = ZTCompute1
        typealias B = ZTCompute2
        switch self {
        case .divisorPairs: return try A.divisorPairs(v)
        case .divides: return try A.divides(v)
        case .divisorSet: return try A.divisorSet(v)
        case .gcdSets: return try A.gcdSets(v)
        case .trialDivision: return try A.trialDivision(v)
        case .sieve: return ""
        case .factorize: return try A.factorize(v)
        case .hilbert: return try A.hilbert(v)
        case .divisorCount: return try A.divisorCount(v)
        case .gcdFactor: return try A.gcdFactor(v)
        case .linearCombination: return try A.linearCombination(v)
        case .subtractiveGcd: return try A.subtractiveGcd(v)
        case .euclid: return try A.euclid(v)
        case .extEuclid: return try A.extEuclid(v)
        case .gcdMany: return try A.gcdMany(v)
        case .lcm: return try A.lcm(v)
        case .divRest: return try A.divRest(v)
        case .congruence: return try A.congruence(v)
        case .residueClass: return try A.residueClass(v)
        case .modTables: return try A.modTables(v)
        case .checkNine: return try A.checkNine(v)
        case .crossSums: return try A.crossSums(v)
        case .units: return try A.units(v)
        case .inverse: return try A.inverse(v)
        case .linearCongruence: return try A.linearCongruence(v)
        case .phiTable: return try A.phiTable(v)
        case .phi: return try A.phi(v)
        case .crt: return try A.crt(v)
        case .crtMap: return try A.crtMap(v)
        case .eulerFermat: return try A.eulerFermat(v)
        case .squareMultiply: return try A.squareMultiply(v)
        case .order: return try A.order(v)
        case .primitiveRoots: return try A.primitiveRoots(v)
        case .mersenneFermat: return try B.mersenneFermat(v)
        case .fermatTest: return try B.fermatTest(v)
        case .carmichael: return try B.carmichael(v)
        case .millerRabin: return try B.millerRabin(v)
        case .caesar: return try B.caesar(v)
        case .multiplicative: return try B.multiplicative(v)
        case .frequency: return try B.frequency(v)
        case .textToNumber: return try B.textToNumber(v)
        case .rsa: return try B.rsa(v)
        case .rabin: return try B.rabin(v)
        case .diffieHellman: return try B.diffieHellman(v)
        case .elgamal: return try B.elgamal(v)
        case .fermatFactor: return try B.fermatFactor(v)
        case .birthday: return try B.birthday(v)
        case .rhoSequence: return try B.rhoSequence(v)
        case .pollardRho: return try B.pollardRho(v)
        case .pollardPm1: return try B.pollardPm1(v)
        case .dlogEnum: return try B.dlogEnum(v)
        case .bsgs: return try B.bsgs(v)
        }
    }
}

struct ZTToolView: View {
    let tool: ZTTool
    var body: some View {
        if tool == .sieve { ZTSieveView() } else { ZTCalcView(tool: tool) }
    }
}

/// Generic input row + monospaced step-by-step output.
struct ZTCalcView: View {
    let tool: ZTTool
    @CTState private var values: [String]
    @CTState private var output = ""
    @CTState private var isError = false

    init(tool: ZTTool) {
        self.tool = tool
        _values = CTState(initialValue: tool.fields.map { $0.1 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(tool.fields.enumerated()), id: \.offset) { i, f in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.0).font(.caption).foregroundStyle(.secondary)
                        TextField(f.0, text: Binding(get: { values[i] }, set: { values[i] = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: f.2 ? 260 : 110)
                            .onSubmit(run)
                    }
                }
                Button("Berechnen", action: run).keyboardShortcut(.return, modifiers: [.command])
                Button("Beispiel") { values = tool.fields.map { $0.1 }; run() }
            }
            ScrollView([.vertical, .horizontal]) {
                Text(output)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(isError ? Color.red : Color.primary)
                    .textSelection(.enabled)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .frame(minHeight: 120, maxHeight: 420)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
        }
        .onAppear(perform: run)
    }

    private func run() {
        do {
            output = try tool.compute(values)
            isError = false
        } catch let e as ZTError {
            output = e.message; isError = true
        } catch {
            output = error.localizedDescription; isError = true
        }
    }
}

/// Sieve of Eratosthenes, step by step (ZT page 1.2 "Eratosthenes").
struct ZTSieveView: View {
    @CTState private var limitText = "120"
    @CTState private var limit = 120
    @CTState private var crossedBy: [Int: Int] = [:]
    @CTState private var current: Int? = nil
    @CTState private var finished = false

    private var primesSoFar: [Int] { (2...max(2, limit)).filter { crossedBy[$0] == nil && ($0 <= (current ?? 1) || finished) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Grenze g =")
                TextField("g", text: $limitText).textFieldStyle(.roundedBorder).frame(width: 80).onSubmit(reset)
                Button("Neu", action: reset)
                Button("Nächster Schritt", action: step).disabled(finished)
                Button("Automatisch") { while !finished { step() } }.disabled(finished)
            }
            Text(status).font(.callout).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 3), count: 10), alignment: .leading, spacing: 3) {
                ForEach(1...max(1, limit), id: \.self) { n in
                    let crossed = n == 1 || crossedBy[n] != nil
                    let isPrime = !crossed && (n <= (current ?? 1) || finished)
                    let justNow = current != nil && crossedBy[n] == current
                    Text("\(n)")
                        .font(.system(size: 12, design: .monospaced))
                        .strikethrough(crossed && n != 1)
                        .foregroundStyle(crossed ? Color.secondary : (isPrime ? Color.white : Color.primary))
                        .frame(width: 38, height: 22)
                        .background(RoundedRectangle(cornerRadius: 3).fill(
                            isPrime ? Color.accentColor : (justNow ? Color.orange.opacity(0.35) : Color(nsColor: .controlBackgroundColor))))
                }
            }
        }
    }

    private var status: String {
        if finished {
            let ps = (2...max(2, limit)).filter { crossedBy[$0] == nil }
            return "Fertig: Alle Zahlen ≤ \(limit), die nicht gestrichen sind, sind Primzahlen (\(ps.count) Stück). "
                + "Man musste nur die Vielfachen der Primzahlen p ≤ √g ≈ \(String(format: "%.1f", Double(limit).squareRoot())) streichen."
        }
        if let p = current { return "Die Vielfachen von p = \(p) ab p² = \(p * p) sind gestrichen (orange). Primzahlen bisher: \(primesSoFar.count)." }
        return "Die 1 ist keine Primzahl. Die nächste nicht gestrichene Zahl ist prim; streiche ihre Vielfachen."
    }

    private func reset() {
        limit = min(max(ZTM.int(limitText) ?? 120, 10), 1000)
        limitText = "\(limit)"
        crossedBy = [:]; current = nil; finished = false
    }

    private func step() {
        var p = (current ?? 1) + 1
        while p <= limit && crossedBy[p] != nil { p += 1 }
        guard p * p <= limit else { current = nil; finished = true; return }
        var m = p * p
        while m <= limit { if crossedBy[m] == nil { crossedBy[m] = p }; m += p }
        current = p
    }
}
