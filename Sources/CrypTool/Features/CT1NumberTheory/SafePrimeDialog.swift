import AppKit
import SwiftUI
import CTCommon
import CTBigNum

/// CT1 "Sichere Primzahl erzeugen" (IDD_GENERATE_SAVE_PRIME, CDlgGenerateSavePrime).
/// Like NTL's GenGermainPrime, "Bitlänge" is the bit length of the Sophie-Germain prime q;
/// the dialog returns p = 2q + 1.
struct SafePrimeDialog: View {
    var close: () -> Void
    var onAccept: (String) -> Void

    @CTState private var bitText = "256"
    @CTState private var prime = ""
    @CTState private var busy = false
    @CTState private var token = CancellationToken()

    static let badLength = "Please select a bit length between 2 and 16384."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This dialog generates a safe prime number p. Primes q are selected until p = 2q+1 is also a prime. Please note the time to generate a safe prime is in general significantly longer compared to generate a prime without this property.\nSafe primes are important for discrete-log based cryptosystems like the Diffie-Hellman method.")
                .fixedSize(horizontal: false, vertical: true)
            GroupBox("Generate a prime") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bit length").frame(width: 70, alignment: .leading)
                        TextField("", text: $bitText).frame(width: 70)
                            .onChange(of: bitText) { _, v in
                                let f = v.filter(\.isNumber)
                                if f != v { bitText = f }
                            }
                        if busy { ProgressView().controlSize(.small) }
                        Spacer()
                    }
                    HStack {
                        Text("Prime").frame(width: 70, alignment: .leading)
                        Text(prime.isEmpty ? " " : prime)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3).truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(3)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                    }
                }.padding(4)
            }
            HStack {
                Button("Generate prime", action: generate).disabled(busy)
                Button("Accept prime") { close(); onAccept(prime) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(prime.isEmpty || busy)
                Spacer()
                Button("Cancel") { token.cancel(); close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 600)
    }

    private func generate() {
        guard let bits = Int(bitText), bits > 1, bits <= 16384 else {
            Alerts.info(Self.badLength)
            return
        }
        let t = CancellationToken()
        token = t
        busy = true
        Task.detached(priority: .userInitiated) {
            let p = SafePrimeGenerator.germainSafePrime(qBits: bits, cancel: t)
            await MainActor.run {
                busy = false
                if let p { prime = p.description }
            }
        }
    }
}

/// Cancellable generation of safe primes p = 2q + 1 with q a Sophie-Germain prime of `qBits` bits.
enum SafePrimeGenerator {
    static func germainSafePrime(qBits l: Int, cancel: CancellationToken) -> BigUInt? {
        if l <= 20 {
            let lo = 1 << (l - 1), hi = (1 << l) - 1
            let primes = Primality.sieve(upTo: 2 * hi + 1)
            let set = Set(primes)
            let qs = primes.filter { $0 >= lo && $0 <= hi && set.contains(2 * $0 + 1) }
            guard let q = qs.randomElement() else { return nil }
            return BigUInt(2 * q + 1)
        }
        let small = Primality.sieve(upTo: min(max(l * 8, 2000), 100_000)).dropFirst().map { UInt64($0) } // without 2
        let upper = (BigUInt(1) << l) - 1
        while true {
            if cancel.isCancelled { return nil }
            let start = BigUInt.random(bits: l, exact: true).settingBit(0).settingBit(l - 1)
            var rs = small.map { start.remainder(dividingBy: $0) }
            var k: UInt64 = 0
            while k < UInt64(l) * 400 {
                if k & 0xFF == 0 && cancel.isCancelled { return nil }
                var ok = true
                for i in 0..<small.count {
                    let s = small[i], r = rs[i]
                    if r == 0 || (2 * r + 1) % s == 0 { ok = false; break }
                }
                if ok {
                    let q = start + BigUInt(2 * k)
                    if q > upper { break }
                    let p = 2 * q + 1
                    if BigUInt(2).power(p - 1, modulus: p).isOne,
                       Primality.isProbablePrime(q), Primality.isProbablePrime(p) {
                        return p
                    }
                    if cancel.isCancelled { return nil }
                }
                for i in 0..<small.count {
                    var r = rs[i] + 2
                    if r >= small[i] { r -= small[i] }
                    rs[i] = r
                }
                k += 1
            }
        }
    }
}
