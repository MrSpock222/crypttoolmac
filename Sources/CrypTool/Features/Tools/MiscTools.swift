import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTAnalysis

// The random data generator and the password tools live in CT1ToolsRandomGenerator.swift and
// CT1ToolsPasswords.swift.

// MARK: - Number shark (Zahlenhai)

struct NumberSharkView: View {
    enum Owner { case free, player, shark }
    @CTState private var limit = 20
    @CTState private var owner: [Owner] = []
    @CTState private var history: [[Owner]] = []
    @CTState private var message = "Wählen Sie eine Zahl. Der Hai erhält alle noch freien Teiler dieser Zahl."

    private var playerScore: Int { owner.indices.filter { owner[$0] == .player }.map { $0 + 1 }.reduce(0, +) }
    private var sharkScore: Int { owner.indices.filter { owner[$0] == .shark }.map { $0 + 1 }.reduce(0, +) }
    private var total: Int { limit * (limit + 1) / 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Stepper("Zahlen 1 bis \(limit)", value: $limit, in: 5...100)
                    .onChange(of: limit) { _, _ in newGame() }
                Spacer()
                Button("Rückgängig") { if let h = history.popLast() { owner = h } }.disabled(history.isEmpty)
                Button("Neues Spiel", action: newGame)
            }
            Text("Regeln: Sie dürfen nur Zahlen wählen, von denen noch mindestens ein echter Teiler frei ist. Alle freien Teiler der gewählten Zahl bekommt der Zahlenhai. Gibt es keinen gültigen Zug mehr, bekommt der Hai alle restlichen Zahlen. Ziel: mehr Punkte (Summe der Zahlen) als der Hai.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(52), spacing: 6), count: 10), spacing: 6) {
                ForEach(0..<owner.count, id: \.self) { i in
                    let n = i + 1
                    Button { pick(n) } label: {
                        Text("\(n)").font(.title3.monospacedDigit().bold())
                            .frame(width: 48, height: 36)
                            .background(color(owner[i]).opacity(owner[i] == .free ? (isValid(n) ? 0.25 : 0.08) : 0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(owner[i] != .free || !isValid(n))
                }
            }
            HStack(spacing: 30) {
                Label("Sie: \(playerScore)", systemImage: "person.fill").foregroundStyle(.green).font(.title3.bold())
                Label("Zahlenhai: \(sharkScore)", systemImage: "fish.fill").foregroundStyle(.red).font(.title3.bold())
                Text("Noch frei: \(total - playerScore - sharkScore)").foregroundStyle(.secondary)
            }
            Text(message).font(.callout)
            Spacer(minLength: 0)
        }
        .padding()
        .onAppear(perform: newGame)
    }

    private func color(_ o: Owner) -> Color {
        switch o { case .free: return .blue; case .player: return .green; case .shark: return .red }
    }

    private func freeDivisors(of n: Int) -> [Int] {
        guard n > 1 else { return [] }
        return (1..<n).filter { n % $0 == 0 && owner[$0 - 1] == .free }
    }

    private func isValid(_ n: Int) -> Bool { owner[n - 1] == .free && !freeDivisors(of: n).isEmpty }

    private func newGame() {
        owner = Array(repeating: .free, count: limit)
        history = []
        message = "Wählen Sie eine Zahl. Der Hai erhält alle noch freien Teiler dieser Zahl."
    }

    private func pick(_ n: Int) {
        guard isValid(n) else { return }
        history.append(owner)
        let divs = freeDivisors(of: n)
        owner[n - 1] = .player
        divs.forEach { owner[$0 - 1] = .shark }
        message = "Sie erhalten \(n), der Hai frisst " + divs.map(String.init).joined(separator: ", ") + "."
        if !(1...limit).contains(where: isValid) {
            let rest = (1...limit).filter { owner[$0 - 1] == .free }
            rest.forEach { owner[$0 - 1] = .shark }
            if !rest.isEmpty { message += " Kein gültiger Zug mehr – der Hai bekommt die restlichen Zahlen: " + rest.map(String.init).joined(separator: ", ") + "." }
            message += playerScore > sharkScore ? " 🎉 Gewonnen!" : (playerScore == sharkScore ? " Unentschieden." : " Der Hai hat gewonnen.")
        }
    }
}
