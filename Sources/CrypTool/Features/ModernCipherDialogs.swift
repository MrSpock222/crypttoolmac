import AppKit
import SwiftUI
import CTCommon
import CTModern

/// CT1 names of the modern symmetric algorithms (IDS_CRYPT_*), used in captions and titles.
extension SymmetricAlgorithm {
    var ct1Name: String {
        switch self {
        case .tripleDESECB: return "Triple-DES (ECB)"
        case .tripleDESCBC: return "Triple-DES (CBC)"
        case .aes: return "Rijndael (AES)"
        default: return displayName
        }
    }

    /// CT1 combo entry "%d Bit" plus " (%d Bit effektiv)" for algorithms with DES parity bits.
    func ct1KeyLengthLabel(_ bits: Int) -> String {
        switch self {
        case .desECB, .desCBC, .desl, .tripleDESECB, .tripleDESCBC: return "\(bits) Bit (\(7 * bits / 8) Bit effektiv)"
        case .desx, .desxl: return "\(bits) Bit (184 Bit effektiv)"
        default: return "\(bits) Bit"
        }
    }
}

// MARK: - Symmetric (modern) encryption (IDD_KEY_HEX_FIXED_LEN)

struct SymmetricDialog: View {
    let algorithm: SymmetricAlgorithm
    let document: CTDocument
    let close: () -> Void
    @CTState private var keyBits = 0
    @CTState private var keyHex = ""

    private var keyBytes: [UInt8]? { CT1KeyInput.hexBytes(keyHex) }
    private var keyValid: Bool { keyBytes?.count == keyBits / 8 }
    private var method: String { "sym." + algorithm.rawValue }

    private var caption: String {
        switch algorithm {
        case .mars, .rc6, .serpent, .twofish: return "Schlüsseleingabe: \(algorithm.ct1Name) (AES-Kandidat)"
        default: return "Schlüsseleingabe: \(algorithm.ct1Name)"
        }
    }

    var body: some View {
        DialogScaffold(title: caption, minWidth: 520) {
            Text("Geben Sie den Schlüssel mit Hexadezimalzeichen (0..9, A..F) ein.")
            Picker("Schlüssellänge:", selection: $keyBits) {
                ForEach(algorithm.keySizesBits, id: \.self) { Text(algorithm.ct1KeyLengthLabel($0)).tag($0) }
            }
            .frame(width: 320)
            .onChange(of: keyBits) { _, b in adjustKey(to: b) }
            HStack {
                CT1FixedHexField(text: $keyHex, byteLength: keyBits / 8)
                    .frame(height: keyBits > 192 ? 52 : 36)
                CT1PasteKeyButton(method: method) { pasteKey($0) }
            }
            HStack {
                Text(keyValid ? "" : "Der Schlüssel muss \(keyBits / 8) Bytes lang sein.").font(.caption).foregroundStyle(.red)
                Spacer()
                Button("Zufälliger Schlüssel") { randomKey() }.controlSize(.small)
            }
            if algorithm.blockSize > 0 {
                Text("\(algorithm.modeDescription)").font(.caption).foregroundStyle(.secondary)
            }
        } buttons: {
            CipherButtons(cancel: close, decrypt: { run(false) }, encrypt: { run(true) }, disabled: !keyValid,
                          help: .symmetric(algorithm.rawValue))
        }
        .onAppear {
            // CT1 pre-selects the first (smallest) key length; the hex field shows zero bytes.
            let bits = algorithm.keySizesBits.first ?? algorithm.defaultKeyBits
            keyBits = bits
            keyHex = Hex.encode([UInt8](repeating: 0, count: bits / 8))
        }
    }

    private func adjustKey(to bits: Int) {
        var b = CT1KeyInput.hexBytes(keyHex) ?? []
        let n = bits / 8
        if b.count < n { b += [UInt8](repeating: 0, count: n - b.count) } else { b = Array(b.prefix(n)) }
        keyHex = Hex.encode(b)
    }

    private func pasteKey(_ s: String) {
        guard let b = CT1KeyInput.hexBytes(s), algorithm.keySizesBits.contains(b.count * 8) else { return }
        keyBits = b.count * 8
        DispatchQueue.main.async { keyHex = Hex.encode(b) }
    }

    private func randomKey() {
        var b = [UInt8](repeating: 0, count: keyBits / 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, b.count, &b)
        keyHex = Hex.encode(b)
    }

    private func run(_ encrypt: Bool) {
        guard let key = keyBytes, keyValid else { return }
        let input = document.bytes
        if CipherRun.bytes(document, method: method, name: algorithm.ct1Name, encrypt: encrypt,
                           key: Hex.encode(key), viewMode: encrypt ? .hex : nil, {
            encrypt ? try SymmetricCipher.encrypt(algorithm, key: key, data: input)
                    : try SymmetricCipher.decrypt(algorithm, key: key, data: input)
        }) { close() }
    }
}

// MARK: - Brute-force analysis (IDD_BRUTEFORCE → IDD_SHOW_PROGRESS → IDD_LIST_RESULTS)

@MainActor
final class BruteForceModel: ObservableObject {
    @Published var running = false
    @Published var progress = 0.0
    @Published var results: [BruteForceResult] = []
    @Published var error: String?
    @Published var elapsed: TimeInterval = 0
    @Published var cancelled = false
    private(set) var started = Date()
    private(set) var windowLength = 128
    private var token: CancellationToken?
    var onFinish: (() -> Void)?

    /// CT1 BRUTEFORCE_HEAPSIZE.
    static let heapSize = 50

    func start(_ alg: SymmetricAlgorithm, ciphertext: [UInt8], pattern: String) {
        let token = CancellationToken()
        self.token = token
        running = true
        progress = 0
        results = []
        error = nil
        started = Date()
        let window = max(1, UserDefaults.standard.object(forKey: "analysis.bruteForceBytes") as? Int ?? 128)
        windowLength = min(window, ciphertext.count)
        let allowed = BruteForceModel.allowedBytes()
        let heap = BruteForceModel.heapSize
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let r = try SymmetricBruteForce.run(alg, ciphertext: ciphertext, keyPattern: pattern, maxResults: heap,
                                                    windowLength: window, cancel: token, progress: { p in
                    Task { @MainActor in self.progress = p; self.elapsed = Date().timeIntervalSince(self.started) }
                }, allowedBytes: allowed)
                await MainActor.run {
                    self.results = r
                    self.finish(cancelled: token.isCancelled)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.finish(cancelled: false)
                }
            }
        }
    }

    private func finish(cancelled: Bool) {
        running = false
        self.cancelled = cancelled
        elapsed = Date().timeIntervalSince(started)
        onFinish?()
    }

    func cancel() { token?.cancel() }

    /// CT1 analysis option "Zeichensatz für den zu erwartenden Klartext" (0 = alle 256 Zeichen,
    /// 1 = druckbare Zeichen, 2 = Textoptionen-Alphabet); NUL, LF, CR and TAB are always allowed.
    static func allowedBytes() -> [Bool]? {
        let mode = UserDefaults.standard.object(forKey: "analysis.bruteForceCharset") as? Int ?? 1
        guard mode != 0 else { return nil }
        var t = [Bool](repeating: false, count: 256)
        if mode == 1 {
            for i in 32..<256 { t[i] = true }
        } else {
            for c in AppSettings.shared.textOptions.alphabetCharacters {
                if let v = c.unicodeScalars.first?.value, v < 256, c.unicodeScalars.count == 1 { t[Int(v)] = true }
            }
        }
        for i in [0, 9, 10, 13] { t[i] = true }
        return t
    }

    /// CDlgShowProgress::duration – remaining time.
    var remainingTime: String {
        guard progress > 0 else { return "?" }
        let rest = elapsed / progress - elapsed
        if rest < 86_400 {
            let error = 0.01 / progress
            let s = Int(rest + 0.5)
            if error < 1 { return String(format: "%02d:%02d:%02d h", s / 3600, (s / 60) % 60, s % 60) }
            if error < 60 { return String(format: "%02d:%02d h", s / 3600, (s / 60) % 60) }
            return String(format: "%02d h", s / 3600)
        }
        if rest < 86_400 * 365 { return String(format: "%.1f Tage", rest / 86_400).replacingOccurrences(of: ".", with: ",") }
        return String(format: "%.2g Jahre", rest / (86_400 * 365)).replacingOccurrences(of: ".", with: ",")
    }
}

/// Step 1: "Brute-Force-Analyse von <Verfahren>" – key length and partially known key.
struct BruteForceDialog: View {
    let algorithm: SymmetricAlgorithm
    let document: CTDocument
    let close: () -> Void
    @CTState private var keyBits = 0
    @CTState private var pattern = ""

    private var digitCount: Int { keyBits / 4 }
    /// Pattern with CT1's fill character '*' for missing trailing digits.
    private var normalizedPattern: String {
        let p = pattern.filter { !$0.isWhitespace }
        return p + String(repeating: "*", count: max(0, digitCount - p.count))
    }

    var body: some View {
        DialogScaffold(title: "Brute-Force-Analyse von \(algorithm.ct1Name)", minWidth: 560) {
            Text("Sie können den Suchraum einschränken, um die Suchzeit zu verkürzen. Geben Sie dazu bekannte Teile des Schlüssels hexadezimal ein, unbekannte mit <*>.")
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .topLeading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("Beispiel:")
                    Text("Mit der Eingabe <00 ** AB ** ... **>  durchsuchen Sie alle Schlüssel, die mit einem Nullbyte beginnen, gefolgt von einem unbekannten Byte, dem Byte <AB>, und einem unbekannten Rest.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                GridRow {
                    Text("Tipp:")
                    Text("Die Suchzeit bewegt sich im Bereich von Minuten oder Stunden, wenn Sie höchstens 6 Sterne (*) (= 24 Bit) verwenden.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.font(.callout)
            Picker("Schlüssellänge:", selection: $keyBits) {
                ForEach(algorithm.keySizesBits, id: \.self) { Text(algorithm.ct1KeyLengthLabel($0)).tag($0) }
            }
            .frame(width: 320)
            .onChange(of: keyBits) { _, _ in pattern = CT1KeyInput.bruteForcePattern(pattern, digits: digitCount) }
            CT1FixedHexField(text: $pattern, byteLength: keyBits / 8, fill: "*", allowStar: true)
                .frame(height: keyBits > 192 ? 52 : 36)
        } buttons: {
            Button("Hilfe") { HelpCenter.show(action: .bruteForce(algorithm.rawValue)) }
            Button("Analyseoptionen") { OptionsWindows.showAnalysisOptions() }
            Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            Button("Starten") { start() }.keyboardShortcut(.defaultAction)
        }
        .onAppear {
            let bits = algorithm.keySizesBits.first ?? algorithm.defaultKeyBits
            keyBits = bits
            pattern = CT1KeyInput.bruteForcePattern("", digits: bits / 4)
        }
    }

    static func preview(_ b: [UInt8]) -> String {
        String(b.prefix(64).map { $0 >= 0x20 && $0 < 0x7F ? Character(UnicodeScalar($0)) : "·" })
    }

    private func start() {
        let p = normalizedPattern, alg = algorithm, doc = document
        close()
        DispatchQueue.main.async { BruteForceFlow.run(alg, document: doc, pattern: p) }
    }
}

extension CT1KeyInput {
    /// CT1 brute-force field: hex digits and '*', fixed byte length, '*' as fill character,
    /// shown in byte groups ("00 ** AB **").
    static func bruteForcePattern(_ s: String, digits: Int) -> String {
        var d = s.uppercased().filter { ($0.isHexDigit && $0.isASCII) || $0 == "*" || $0 == "?" }.map { $0 == "?" ? "*" : $0 }
        if d.count > digits { d = Array(d.prefix(digits)) }
        while d.count < digits { d.append("*") }
        var out = ""
        for (i, c) in d.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(c)
        }
        return out
    }
}

/// Steps 2 and 3: progress window "Fortschritt", then "Ergebnisse der Brute-Force-Analyse".
@MainActor
enum BruteForceFlow {
    static func run(_ alg: SymmetricAlgorithm, document doc: CTDocument, pattern: String) {
        let model = BruteForceModel()
        let window = CT1.window(of: doc)
        let searchBits = Int(log2(max(1, SymmetricBruteForce.keyspaceSize(pattern: pattern, algorithm: alg))).rounded())
        WindowPresenter.sheet(on: window, title: "Fortschritt") { close in
            BruteForceProgressView(model: model, title: "Brute-Force-Analyse von \(alg.ct1Name)", searchBits: searchBits, close: close)
        }
        model.onFinish = { [weak model] in
            DispatchQueue.main.async {
                guard let model else { return }
                if let e = model.error { Alerts.error(e); return }
                if model.results.isEmpty {
                    Alerts.info("Im Suchbereich befinden sich keine gültigen Schlüssel für den verschlüsselten Text!")
                    return
                }
                WindowPresenter.sheet(on: window, title: "Ergebnisse der Brute-Force-Analyse") { close in
                    BruteForceResultsView(algorithm: alg, document: doc, results: model.results, windowLength: model.windowLength, close: close)
                }
            }
        }
        model.start(alg, ciphertext: doc.bytes, pattern: pattern)
    }
}

struct BruteForceProgressView: View {
    @ObservedObject var model: BruteForceModel
    let title: String
    let searchBits: Int
    let close: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            ProgressView(value: model.progress)
            Text("Vollständige \(searchBits) Bit-Suche zu \(Int(model.progress * 100))% erledigt.\nRestzeit: \(model.remainingTime)")
                .multilineTextAlignment(.center)
            Button("Abbrechen") { model.cancel() }.keyboardShortcut(.cancelAction)
        }
        .padding(18)
        .frame(width: 380)
        .onChange(of: model.running) { _, running in if !running { close() } }
    }
}

struct BruteForceResultsView: View {
    let algorithm: SymmetricAlgorithm
    let document: CTDocument
    let results: [BruteForceResult]
    let windowLength: Int
    let close: () -> Void
    @CTState private var selected: Int? = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ergebnisse der Brute-Force-Analyse").font(.title3.weight(.semibold))
            Text("Die Brute-Force-Analyse entschlüsselte die ersten \(windowLength) Zeichen des Chiffrats - indem nacheinander alle möglichen Schlüssel aus dem gegebenen Schlüsselraum angewendet wurden. Danach wurde für jede entschlüsselte Nachricht der Entropiewert bestimmt. Die folgende Liste enthält die entschlüsselten Nachrichten mit den niedrigsten Entropiewerten.\nGerade bei sehr kurzen Chiffraten kann es sein, dass es falsche Kandidaten mit einem kleinen Entropiewert gibt. Sie haben hier die Möglichkeit, den Kandidaten mit der richtigen Entschlüsselung von Hand auszuwählen.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Table(results.enumerated().map { BruteForceRow(id: $0.offset, element: $0.element) }, selection: $selected) {
                TableColumn("Entropie") { r in Text(String(format: "%3.4f", r.element.entropy)).monospacedDigit() }.width(70)
                TableColumn("Entschlüsselung: Hex-Dump") { r in
                    Text(r.element.plaintextPreview.prefix(256).map { String(format: "%02X ", $0) }.joined()).font(.system(.caption, design: .monospaced))
                }
                TableColumn("Entschlüsselung") { r in
                    Text(String(r.element.plaintextPreview.prefix(256).map { $0 >= 32 && $0 < 128 ? Character(UnicodeScalar($0)) : "." }))
                        .font(.system(.caption, design: .monospaced))
                }
                TableColumn("Schlüssel") { r in Text(Hex.encode(r.element.key)).font(.system(.caption, design: .monospaced)) }
            }
            .frame(minHeight: 240)
            HStack {
                Spacer()
                Button("Auswahl übernehmen") { accept() }.keyboardShortcut(.defaultAction)
                Button("Abbrechen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(minWidth: 820)
    }

    private func accept() {
        guard let i = selected, i < results.count else {
            Alerts.info("Bitte selektieren Sie einen Entschlüsselungskandidaten, oder\nwählen Sie \"Abbrechen\" in der Maske mit den Analyse-Ergebnissen, wenn der Angriff nicht erfolgreich war.")
            return
        }
        let key = results[i].key
        let keyHex = Hex.encode(key)
        // CT1 IDS_STRING_AUTOMATIC_ANALYSE "%s-Analyse von <%s>, Schlüssel <%s>"
        let title = DocumentFactory.title("\(algorithm.ct1Name)-Analyse", of: document, key: keyHex)
        if CipherRun.open(bytes: document, method: "sym." + algorithm.rawValue, title: title, key: keyHex, {
            try SymmetricCipher.decrypt(algorithm, key: key, data: document.bytes)
        }) != nil { close() }
    }
}

/// Row of the brute-force result list.
struct BruteForceRow: Identifiable {
    let id: Int
    let element: BruteForceResult
}
