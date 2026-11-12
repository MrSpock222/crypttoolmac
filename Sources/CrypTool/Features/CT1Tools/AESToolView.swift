import AppKit
import CTCommon
import CTModern
import SwiftUI
import UniformTypeIdentifiers

/// State and actions of the AES-Tool dialog (aestool/aestoolDlg.cpp, IDD_AESTOOL_DIALOG).
@MainActor
final class AESToolModel: ObservableObject {
    static let version = "AES-Tool 2.7"

    weak var window: NSWindow?

    // Defaults as in CAestoolDlg: key shown, hex input, no secure deletion, self-extracting format.
    @Published var showKey = true
    @Published var hexMode = true
    @Published var hexKey = "" { didSet { let f = Self.filterHex(hexKey); if f != hexKey { hexKey = f } } }
    @Published var textKey = "" { didSet { if textKey.count > AESToolFile.maxPasswordCharacters { textKey = String(textKey.prefix(AESToolFile.maxPasswordCharacters)) } } }
    @Published var inputPath = "" { didSet { if inputPath != oldValue { refreshSource() } } }
    @Published var secureDelete = false
    @Published var selfExtracting = true
    @Published private(set) var probe: AESToolFile.Probe?   // nil: no readable input file
    @Published private(set) var busy = false

    var isEncrypted: Bool { if case .encrypted = probe { return true } else { return false } }
    var sourceExists: Bool { probe != nil }
    var keyEntered: Bool { hexMode ? hexKey.contains { $0.isHexDigit } : !textKey.isEmpty }
    var canEncrypt: Bool { keyEntered && sourceExists && !isEncrypted && !busy }
    var canDecrypt: Bool { keyEntered && isEncrypted && !busy }

    var keyHeader: String {
        hexMode ? "Schlüssel [maximal 64 Hexzeichen (0, 1, ..., 8, 9, A, B, C, D, E, F)]" : "Schlüssel [maximal 32 Zeichen]"
    }

    func setInput(_ path: String) { inputPath = path }

    /// Hex edit of the original: only 0-9, A-F (upper case), at most 64 digits; blanks allowed.
    static func filterHex(_ s: String) -> String {
        var out = "", digits = 0
        for ch in s.uppercased() {
            if ch.isHexDigit, ch.isASCII { guard digits < AESToolFile.maxHexDigits else { continue }; digits += 1; out.append(ch) }
            else if ch == " " { out.append(ch) }
        }
        return out
    }

    /// Key bytes: hex input (zero padded by AES-Tool) or AES-Tool's PKCS#5 derivation of the text.
    var keyBytes: [UInt8] {
        hexMode ? (AESToolFile.hexKey(hexKey) ?? [])
                : AESToolFile.deriveKey(password: AESToolFile.passwordBytes(textKey))
    }

    private var sourceURL: URL { URL(fileURLWithPath: (inputPath as NSString).expandingTildeInPath) }

    /// SrcInfo::setName – determines whether the input file is an AES-Tool file.
    private func refreshSource() {
        let path = inputPath.trimmingCharacters(in: .whitespaces)
        var isDir: ObjCBool = false
        guard !path.isEmpty, FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDir), !isDir.boolValue,
              let p = try? AESToolFile.probe(url: sourceURL) else { probe = nil; return }
        switch p {
        case .oldVersion, .corrupt:
            probe = nil
            let msg = AESToolFile.probeMessage(p)
            DispatchQueue.main.async { Alerts.info(msg, title: Self.version) }
        default:
            probe = p
        }
    }

    func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if !inputPath.isEmpty { panel.directoryURL = sourceURL.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inputPath = url.path
    }

    func close() { window?.performClose(nil) }

    func help() { HelpCenter.show(topic: "hid_aes_selfextract.html") }

    // MARK: Encryption

    func encrypt() {
        guard canEncrypt else { return }
        let src = sourceURL
        let ext = selfExtracting ? AESToolSelfExtractor.fileExtension : "aes"
        let base = src.deletingPathExtension().lastPathComponent
        guard let dst = savePanel(directory: src.deletingLastPathComponent(), name: base + "." + ext) else { return }
        guard dst.standardizedFileURL.path != src.standardizedFileURL.path else {
            Alerts.error("Fehler beim Verschlüsseln: Ein- und Ausgabedatei dürfen nicht identisch sein.", title: Self.version)
            return
        }
        let key = keyBytes, prefix = selfExtracting ? AESToolSelfExtractor.prefix : [], exec = selfExtracting
        let deleteSource = secureDelete
        run(work: {
            try AESToolFile.encryptFile(src, to: dst, key: key, originalName: src.lastPathComponent, prefix: prefix)
            if exec { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path) }
        }, done: { [weak self] error in
            guard let self else { return }
            if let error {
                Alerts.error("Fehler beim Verschlüsseln: \(error.localizedDescription)", title: Self.version)
                return
            }
            Alerts.info("Die verschlüsselte Datei \(dst.path) wurde erfolgreich erstellt.", title: Self.version)
            if deleteSource { self.deleteSourceSecurely(src) }
        })
    }

    /// CAestoolDlg::securelyDeleteSourceFile: four overwrite passes, then delete; clears the input field.
    private func deleteSourceSecurely(_ src: URL) {
        do {
            try AESToolFile.secureDelete(src)
            inputPath = ""
        } catch {
            Alerts.info("Die Datei \(src.path) konnte nicht gelöscht werden.", title: "CrypTool")
        }
    }

    // MARK: Decryption

    func decrypt() {
        guard canDecrypt, case .encrypted(let info) = probe else { return }
        let src = sourceURL, key = keyBytes
        guard let original = AESToolFile.originalName(info, key: key) else {
            Alerts.error("Falscher Schlüssel oder Datei \(src.path) beschädigt.", title: Self.version)
            return
        }
        var name = original.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        if name.isEmpty || name.allSatisfy({ $0 == "." }) { name = "entschluesselt" }
        guard let dst = savePanel(directory: src.deletingLastPathComponent(), name: name) else { return }
        guard dst.standardizedFileURL.path != src.standardizedFileURL.path else {
            Alerts.error("Fehler beim Entschlüsseln: Ein- und Ausgabedatei dürfen nicht identisch sein.", title: Self.version)
            return
        }
        run(work: {
            try AESToolFile.decryptFile(src, info: info, to: dst, key: key)
        }, done: { error in
            if let error {
                Alerts.error("Fehler beim Entschlüsseln: \(error.localizedDescription)", title: Self.version)
            } else {
                Alerts.info("Die entschlüsselte Datei \(dst.path) wurde erfolgreich erstellt.", title: Self.version)
            }
        })
    }

    // MARK: Helpers

    private func savePanel(directory: URL, name: String) -> URL? {
        let panel = NSSavePanel()
        panel.directoryURL = directory
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func run(work: @escaping @Sendable () throws -> Void, done: @escaping @MainActor (Error?) -> Void) {
        busy = true
        Task.detached(priority: .userInitiated) {
            var failure: Error?
            do { try work() } catch { failure = error }
            let result = failure
            await MainActor.run {
                self.busy = false
                done(result)
            }
        }
    }
}

struct AESToolView: View {
    @ObservedObject var model: AESToolModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ver- oder Entschlüsseln einer Datei")
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }

            GroupBox(label: Text(model.keyHeader)) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Eingegebenen Schlüssel anzeigen", isOn: $model.showKey)
                    Toggle("Schlüssel hexadezimal eingeben", isOn: $model.hexMode)
                    keyField
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Eingabedatei")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("", text: $model.inputPath)
                            .textFieldStyle(.roundedBorder)
                            .dropDestination(for: URL.self) { urls, _ in
                                guard let u = urls.first, u.isFileURL else { return false }
                                model.inputPath = u.path
                                return true
                            }
                        Button("Durchsuchen...") { model.browse() }
                    }
                    Toggle("Sicheres Löschen der Eingabedatei nach Verschlüsselung", isOn: $model.secureDelete)
                        .disabled(model.isEncrypted)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Ausgabeformat")) {
                Picker("", selection: $model.selfExtracting) {
                    Text("Selbstextrahierend und verschlüsselt").tag(true)
                    Text("Verschlüsselt").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
                .disabled(model.isEncrypted)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(model.selfExtracting && !model.isEncrypted
                 ? "Selbstextrahierend (macOS): Datei „.command“, die sich per Doppelklick im Terminal entschlüsselt (nur perl und openssl von macOS nötig). Sie ist zugleich eine gültige AES-Tool-Datei."
                 : "Entschlüsselt werden AES-Tool-Dateien (.AES), selbstextrahierende Windows-Archive (.EXE) und „.command“-Dateien.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Verschlüsseln") { model.encrypt() }
                    .disabled(!model.canEncrypt)
                Button("Entschlüsseln") { model.decrypt() }
                    .disabled(!model.canDecrypt)
                Spacer()
                Button("Beenden") { model.close() }
                    .keyboardShortcut(.cancelAction)
                Button("Hilfe") { model.help() }
            }
        }
        .padding(16)
        .frame(width: 600)
    }

    @ViewBuilder private var keyField: some View {
        let font = Font.system(.body, design: .monospaced)
        if model.hexMode {
            if model.showKey {
                TextField("", text: $model.hexKey).font(font).textFieldStyle(.roundedBorder)
            } else {
                SecureField("", text: $model.hexKey).font(font).textFieldStyle(.roundedBorder)
            }
        } else {
            if model.showKey {
                TextField("", text: $model.textKey).font(font).textFieldStyle(.roundedBorder)
            } else {
                SecureField("", text: $model.textKey).font(font).textFieldStyle(.roundedBorder)
            }
        }
    }
}
