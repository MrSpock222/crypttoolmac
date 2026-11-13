import SwiftUI
import CTBigNum

/// The interactive ("Try it") parts attached to ZT/NT pages.
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
        case .divisorPairs: return "Divisors and complementary divisors"
        case .divides: return "Divisibility a | b"
        case .divisorSet: return "Divisor set"
        case .gcdSets: return "GCD via divisor sets"
        case .trialDivision: return "Trial division"
        case .sieve: return "Sieve of Eratosthenes"
        case .factorize: return "Prime decomposition"
        case .hilbert: return "Primes in H = {4n + 1}"
        case .divisorCount: return "Number of divisors"
        case .gcdFactor: return "GCD and LCM by means of the prime decomposition"
        case .linearCombination: return "Linear combinations a·x + b·y"
        case .subtractiveGcd: return "GCD(a, b) = GCD(b, a – b)"
        case .euclid: return "Euclidian algorithm"
        case .extEuclid: return "Extended Euclidian algorithm"
        case .gcdMany: return "GCD of several numbers"
        case .lcm: return "LCM"
        case .divRest: return "Division with remainder"
        case .congruence: return "Congruence modulo m"
        case .residueClass: return "Residue class and standard representative"
        case .modTables: return "Addition and multiplication tables in ℤm"
        case .checkNine: return "Calculation check modulo 9 and 11"
        case .crossSums: return "Transversal sums"
        case .units: return "Prime residue classes ℤm*"
        case .inverse: return "Inverting with Euclid"
        case .linearCongruence: return "Solving the congruence a·x ≡ b mod m"
        case .phiTable: return "Values of the Euler function"
        case .phi: return "Euler function φ(n)"
        case .crt: return "Chinese remainder theorem (clock setting)"
        case .crtMap: return "Decomposition ℤn → ℤm₁ × … × ℤmₖ"
        case .eulerFermat: return "Euler-Fermat"
        case .squareMultiply: return "Fast modular exponentiation"
        case .order: return "Order and generation ⟨a⟩"
        case .primitiveRoots: return "Finding primitive residue classes"
        case .mersenneFermat: return "Mersenne and Fermat numbers"
        case .fermatTest: return "Fermat test"
        case .carmichael: return "Carmichael numbers"
        case .millerRabin: return "Miller-Rabin test"
        case .caesar: return "Caesar"
        case .multiplicative: return "E(x) = a·x + b (mod 27)"
        case .frequency: return "Frequency analysis"
        case .textToNumber: return "Text as number"
        case .rsa: return "RSA"
        case .rabin: return "Rabin"
        case .diffieHellman: return "Diffie-Hellman"
        case .elgamal: return "ElGamal"
        case .fermatFactor: return "Fermat factorization"
        case .birthday: return "Birthday paradox"
        case .rhoSequence: return "Sequence xᵢ₊₁ = xᵢ² + c"
        case .pollardRho: return "Pollard's Rho factorization"
        case .pollardPm1: return "Pollard's p–1 factorization"
        case .dlogEnum: return "Discrete logarithm by enumeration"
        case .bsgs: return "Babystep giantstep"
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
        case .hilbert: return [("n", "441", false), ("Limit", "100", false)]
        case .divisorCount: return [("n", "360", false)]
        case .gcdFactor: return [("a", "360", false), ("b", "84", false)]
        case .linearCombination: return [("a", "12", false), ("b", "18", false)]
        case .subtractiveGcd: return [("a", "91", false), ("b", "35", false)]
        case .euclid: return [("a", "1071", false), ("b", "1029", false)]
        case .extEuclid: return [("a", "99", false), ("b", "78", false)]
        case .gcdMany: return [("Numbers", "84, 126, 210", true)]
        case .lcm: return [("Numbers", "4, 6, 10", true)]
        case .divRest: return [("a", "-17", false), ("b", "5", false)]
        case .congruence: return [("a", "13", false), ("b", "1", false), ("m", "12", false)]
        case .residueClass: return [("a", "-25", false), ("m", "2", false)]
        case .modTables: return [("m", "6", false)]
        case .checkNine: return [("a", "1234", false), ("b", "5678", false)]
        case .crossSums: return [("x", "5214", true), ("k", "1", false)]
        case .units: return [("m", "12", false)]
        case .inverse: return [("a", "7", false), ("m", "26", false)]
        case .linearCongruence: return [("a", "6", false), ("b", "4", false), ("m", "10", false)]
        case .phiTable: return [("up to n", "36", false)]
        case .phi: return [("n", "360", true)]
        case .crt: return [("Remainders a₁, a₂, …", "2, 3, 2", true), ("Moduli m₁, m₂, …", "3, 5, 7", true)]
        case .crtMap: return [("Moduli", "3, 4", true)]
        case .eulerFermat: return [("a", "3", false), ("m", "10", false)]
        case .squareMultiply: return [("a", "7", false), ("Exponent", "560", false), ("Modulus", "561", false)]
        case .order: return [("a", "2", false), ("m", "13", false)]
        case .primitiveRoots: return [("m", "13", false)]
        case .mersenneFermat: return [("n up to", "31", false), ("k up to", "6", false)]
        case .fermatTest: return [("n", "341", false), ("Bases a", "2, 3", true)]
        case .carmichael: return [("Limit", "100000", false)]
        case .millerRabin: return [("n", "561", false), ("a", "2", false)]
        case .caesar: return [("Text", "ZAHLENTHEORIE", true), ("Key b", "3", false)]
        case .multiplicative: return [("Text", "ZAHLENTHEORIE", true), ("a", "5", false), ("b", "3", false)]
        case .frequency: return [("Text", "DIE ZAHLENTHEORIE IST DIE KOENIGIN DER MATHEMATIK", true)]
        case .textToNumber: return [("Text", "ZAHL", true), ("Limit G", "1000000", false)]
        case .rsa: return [("p", "47", false), ("q", "59", false), ("b (private)", "157", false), ("Message n", "920", false)]
        case .rabin: return [("p", "7", false), ("q", "11", false), ("Message n", "20", false)]
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
                Button("Calculate", action: run).keyboardShortcut(.return, modifiers: [.command])
                Button("Example") { values = tool.fields.map { $0.1 }; run() }
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
                Text("Limit g =")
                TextField("g", text: $limitText).textFieldStyle(.roundedBorder).frame(width: 80).onSubmit(reset)
                Button("New", action: reset)
                Button("Next step", action: step).disabled(finished)
                Button("Automatically") { while !finished { step() } }.disabled(finished)
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
            return "Done: All numbers ≤ \(limit) that are not struck out are primes (\(ps.count) of them). "
                + "Only the multiples of the primes p ≤ √g ≈ \(String(format: "%.1f", Double(limit).squareRoot())) had to be struck out."
        }
        if let p = current { return "The multiples of p = \(p) from p² = \(p * p) on are struck out (orange). Primes so far: \(primesSoFar.count)." }
        return "1 is no prime. The next number that is not struck out is prime; strike out its multiples."
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
