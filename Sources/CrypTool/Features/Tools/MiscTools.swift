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
    @CTState private var message = "Choose a number. The shark gets all free divisors of this number."

    private var playerScore: Int { owner.indices.filter { owner[$0] == .player }.map { $0 + 1 }.reduce(0, +) }
    private var sharkScore: Int { owner.indices.filter { owner[$0] == .shark }.map { $0 + 1 }.reduce(0, +) }
    private var total: Int { limit * (limit + 1) / 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Stepper("Numbers 1 to \(limit)", value: $limit, in: 5...100)
                    .onChange(of: limit) { _, _ in newGame() }
                Spacer()
                Button("Undo") { if let h = history.popLast() { owner = h } }.disabled(history.isEmpty)
                Button("New game", action: newGame)
            }
            Text("Rules: You may only choose numbers that still have at least one free proper divisor. The number shark gets all free divisors of the chosen number. If there is no valid move left, the shark gets all remaining numbers. Goal: more points (sum of the numbers) than the shark.")
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
                Label("You: \(playerScore)", systemImage: "person.fill").foregroundStyle(.green).font(.title3.bold())
                Label("Number Shark: \(sharkScore)", systemImage: "fish.fill").foregroundStyle(.red).font(.title3.bold())
                Text("Still free: \(total - playerScore - sharkScore)").foregroundStyle(.secondary)
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
        message = "Choose a number. The shark gets all free divisors of this number."
    }

    private func pick(_ n: Int) {
        guard isValid(n) else { return }
        history.append(owner)
        let divs = freeDivisors(of: n)
        owner[n - 1] = .player
        divs.forEach { owner[$0 - 1] = .shark }
        message = "You get \(n), the shark eats " + divs.map(String.init).joined(separator: ", ") + "."
        if !(1...limit).contains(where: isValid) {
            let rest = (1...limit).filter { owner[$0 - 1] == .free }
            rest.forEach { owner[$0 - 1] = .shark }
            if !rest.isEmpty { message += " No valid move left – the shark gets the remaining numbers: " + rest.map(String.init).joined(separator: ", ") + "." }
            message += playerScore > sharkScore ? " 🎉 You won!" : (playerScore == sharkScore ? " Draw." : " The shark won.")
        }
    }
}
