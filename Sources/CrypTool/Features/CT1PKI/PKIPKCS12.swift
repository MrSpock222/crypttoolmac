import AppKit
import UniformTypeIdentifiers
import CTCommon
import CTBigNum
import CTModern

/// CT1 "PKCS #12-Import" (key generation) and "PSE exportieren (PKCS#12)" (key list) for RSA and
/// DSA keys. The PKCS #12 container is built/read with the system's /usr/bin/openssl; the CT1 key
/// identifier is stored as friendlyName so a round trip keeps Name, Vorname and Kennung.
@MainActor
enum PKIPKCS12 {
    // MARK: Export

    static func export(_ k: StoredKey) {
        guard let pin = PKIPinAccess.ask(for: k), let material = PKIPinAccess.open(k, pin: pin) else { return }
        guard let pw = askPasswords(first: "Bitte geben Sie die PIN für die PKCS#12-Datei ein.", second: nil) else { return }
        let save = NSSavePanel()
        save.nameFieldStringValue = k.ct1Identifier + ".p12"
        guard save.runModal() == .OK, let url = save.url else { return }
        let keyDER: [UInt8]
        let pemType: String
        switch material {
        case .rsa(let r):
            keyDER = PKIDER.seq([PKIDER.int(0), PKIDER.int(r.n), PKIDER.int(r.e), PKIDER.int(r.d), PKIDER.int(r.p), PKIDER.int(r.q),
                              PKIDER.int(r.dp), PKIDER.int(r.dq), PKIDER.int(r.qInv)])
            pemType = "RSA PRIVATE KEY"
        case .dsa(let d):
            let pr = d.parameters
            keyDER = PKIDER.seq([PKIDER.int(0), PKIDER.int(pr.p), PKIDER.int(pr.q), PKIDER.int(pr.g), PKIDER.int(d.y), PKIDER.int(d.x)])
            pemType = "DSA PRIVATE KEY"
        case .ecc:
            return PKIModal.warning("PKCS#12-Struktur konnte nicht erzeugt werden.")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ctp12-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let keyURL = dir.appendingPathComponent("key.pem"), certURL = dir.appendingPathComponent("cert.pem")
            try pem(keyDER, type: pemType).write(to: keyURL, atomically: true, encoding: .ascii)
            let subject = "/CN=\(k.firstName) \(k.lastName) [\(k.internalID)]/DC=cryptool/DC=org"
            _ = try openssl(["req", "-new", "-x509", "-utf8", "-key", keyURL.path, "-subj", subject, "-days", "365", "-sha1", "-out", certURL.path])
            _ = try openssl(["pkcs12", "-export", "-inkey", keyURL.path, "-in", certURL.path, "-name", k.ct1Identifier,
                             "-out", url.path, "-passout", "env:CTP12PASS"], password: pw)
            PKIModal.info("Die PSE wurde als PKCS#12-Datei gespeichert:\n\(url.path)")
        } catch {
            PKIModal.warning("PKCS#12-Struktur konnte nicht erzeugt werden.\n\n\(error.localizedDescription)")
        }
    }

    // MARK: Import

    static func importFile(defaultName: String, defaultFirstName: String, completion: (StoredKey) -> Void) {
        let open = NSOpenPanel()
        open.allowedContentTypes = ["p12", "pfx"].compactMap { UTType(filenameExtension: $0) }
        open.allowsOtherFileTypes = true
        guard open.runModal() == .OK, let url = open.url else { return }
        guard let p12pw = askPasswords(first: "Bitte geben Sie die PIN für die PKCS#12-Datei ein.", second: nil, verify: false),
              let psePin = askPasswords(first: "Bitte geben Sie die PSE-PIN ein.", second: nil), !psePin.isEmpty else { return }
        do {
            let out = try openssl(["pkcs12", "-in", url.path, "-nodes", "-passin", "env:CTP12PASS"], password: p12pw)
            let text = String(decoding: out, as: UTF8.self)
            guard let (der, type) = pemBlock(text, types: ["PRIVATE KEY", "RSA PRIVATE KEY", "DSA PRIVATE KEY"]) else {
                throw CTError("Die PKCS#12-Datei enthält keinen privaten Schlüssel.")
            }
            let material = try parsePrivateKey(der, type: type)
            var (name, first, label, created) = (defaultName.isEmpty ? "Import" : defaultName,
                                                 defaultFirstName.isEmpty ? url.deletingPathExtension().lastPathComponent : defaultFirstName,
                                                 "", Date())
            if let friendly = line(text, prefix: "friendlyName:"), friendly.hasPrefix("[") {
                let parts = friendly.dropFirst().dropLast().components(separatedBy: "][")
                if parts.count >= 4 {
                    name = parts[0]; first = parts[1]
                    if let t = TimeInterval(parts[3]) { created = Date(timeIntervalSince1970: t) }
                    if parts.count >= 5 { label = parts[4] }
                }
            } else if let subj = line(text, prefix: "subject="), let cn = subj.components(separatedBy: "CN=").dropFirst().first {
                let cnValue = cn.components(separatedBy: CharacterSet(charactersIn: "/,")).first ?? cn
                let words = cnValue.replacingOccurrences(of: #"\s*\[.*\]"#, with: "", options: .regularExpression).split(separator: " ")
                if words.count >= 2 { first = String(words[0]); name = words.dropFirst().joined(separator: " ") }
            }
            let k = try KeyStore.shared.add(lastName: name, firstName: first, label: label, material: material, pin: psePin, created: created)
            PKIModal.info("Die von ihnen gewählten Parameter und das erzeugte\nSchlüsselpaar wurden erfolgreich abgespeichert.\nDer zugewiesene Schlüsselbezeichner ist:\n'\(k.ct1Identifier)'")
            completion(k)
        } catch {
            PKIModal.warning("Could not decode PKCS#12 file\n\n\(error.localizedDescription)")
        }
    }

    // MARK: Helpers

    /// CT1 IDD_CHANGE_PIN style prompt: PIN (+ verification).
    static func askPasswords(first: String, second: String?, verify: Bool = true) -> String? {
        let a = NSAlert()
        a.messageText = "PIN-Eingabe"
        a.informativeText = first
        let f1 = NSSecureTextField(frame: NSRect(x: 0, y: 30, width: 240, height: 24))
        let f2 = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        f1.placeholderString = "PIN"
        f2.placeholderString = "Verifikation"
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: verify ? 54 : 24))
        if verify { box.addSubview(f1); box.addSubview(f2) } else { f1.frame.origin.y = 0; box.addSubview(f1) }
        a.accessoryView = box
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Abbrechen")
        a.window.initialFirstResponder = f1
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        if verify && f1.stringValue != f2.stringValue {
            PKIModal.warning("PIN und PIN-Verifikation stimmen nicht überein.\nBitte nochmal eingeben.")
            return nil
        }
        return f1.stringValue
    }

    private static func openssl(_ args: [String], password: String? = nil) throws -> Data {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        if let password { env["CTP12PASS"] = password }
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(decoding: errData, as: UTF8.self).split(separator: "\n").first.map(String.init) ?? "openssl-Fehler"
            throw CTError(msg)
        }
        return data
    }

    private static func pem(_ der: [UInt8], type: String) -> String {
        "-----BEGIN \(type)-----\n" + Base64Codec.encode(der, lineLength: 64) + "\n-----END \(type)-----\n"
    }

    private static func pemBlock(_ text: String, types: [String]) -> ([UInt8], String)? {
        for t in types {
            guard let a = text.range(of: "-----BEGIN \(t)-----"), let b = text.range(of: "-----END \(t)-----", range: a.upperBound..<text.endIndex) else { continue }
            let body = text[a.upperBound..<b.lowerBound].filter { !$0.isWhitespace }
            if let der = try? Base64Codec.decode(String(body)) { return (der, t) }
        }
        return nil
    }

    private static func line(_ text: String, prefix: String) -> String? {
        for l in text.split(separator: "\n") {
            let s = l.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix(prefix) { return s.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }

    private static func parsePrivateKey(_ der: [UInt8], type: String) throws -> PrivateKeyMaterial {
        let bad = CTError("Der private Schlüssel konnte nicht gelesen werden.")
        guard let top = PKIDER.parse(der) else { throw bad }
        func ints(_ n: PKIDER.Node) -> [BigUInt] { n.children.filter { $0.tag == 0x02 }.map { BigUInt(bigEndianBytes: $0.value) } }
        switch type {
        case "RSA PRIVATE KEY":
            let v = ints(top)
            guard v.count >= 6 else { throw bad }
            return .rsa(try RSAKeyPair(p: v[4], q: v[5], e: v[2], d: v[3]))
        case "DSA PRIVATE KEY":
            let v = ints(top)
            guard v.count >= 6 else { throw bad }
            return .dsa(DSAKeyPair(parameters: DSAParameters(p: v[1], q: v[2], g: v[3]), x: v[5]))
        default: // PKCS #8
            guard top.children.count >= 3, let inner = PKIDER.parse(top.children[2].value) else { throw bad }
            let alg = top.children[1]
            let oid = alg.children.first?.value ?? []
            if oid == [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01] {   // rsaEncryption
                let v = ints(inner)
                guard v.count >= 6 else { throw bad }
                return .rsa(try RSAKeyPair(p: v[4], q: v[5], e: v[2], d: v[3]))
            }
            if oid == [0x2A, 0x86, 0x48, 0xCE, 0x38, 0x04, 0x01], alg.children.count >= 2 {   // id-dsa
                let pqg = ints(alg.children[1])
                guard pqg.count == 3, inner.tag == 0x02 else { throw bad }
                return .dsa(DSAKeyPair(parameters: DSAParameters(p: pqg[0], q: pqg[1], g: pqg[2]), x: BigUInt(bigEndianBytes: inner.value)))
            }
            throw CTError("Nur RSA- und DSA-Schlüssel können importiert werden.")
        }
    }
}

/// Minimal DER encoder/decoder for key structures.
enum PKIDER {
    struct Node {
        var tag: UInt8
        var value: [UInt8]
        var children: [Node]
    }

    static func length(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var b: [UInt8] = []
        var v = n
        while v > 0 { b.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
        return [0x80 | UInt8(b.count)] + b
    }

    static func int(_ v: BigUInt) -> [UInt8] {
        var b = v.bigEndianBytes
        if b.isEmpty { b = [0] }
        if b[0] & 0x80 != 0 { b.insert(0, at: 0) }
        return [0x02] + length(b.count) + b
    }

    static func int(_ v: Int) -> [UInt8] { int(BigUInt(v)) }

    static func seq(_ items: [[UInt8]]) -> [UInt8] {
        let body = items.flatMap { $0 }
        return [0x30] + length(body.count) + body
    }

    /// Parses one TLV (constructed SEQUENCE/SET children are parsed recursively).
    static func parse(_ d: [UInt8]) -> Node? {
        var i = 0
        return node(d, &i)
    }

    private static func node(_ d: [UInt8], _ i: inout Int) -> Node? {
        guard i + 2 <= d.count else { return nil }
        let tag = d[i]; i += 1
        var len = Int(d[i]); i += 1
        if len & 0x80 != 0 {
            let n = len & 0x7F
            guard n > 0, n <= 4, i + n <= d.count else { return nil }
            len = 0
            for _ in 0..<n { len = len << 8 | Int(d[i]); i += 1 }
        }
        guard i + len <= d.count else { return nil }
        let value = Array(d[i..<i + len])
        i += len
        var children: [Node] = []
        if tag & 0x20 != 0 {
            var j = 0
            while j < value.count, let c = node(value, &j) { children.append(c) }
        }
        return Node(tag: tag, value: value, children: children)
    }
}
