import CTCommon
import CTModern
import Foundation

/// AES-Tool (CT1 "AES (selbstextrahierend)"). Reference vectors were produced by CT1's own code:
/// aestoolcrypto.cpp's encryption logic compiled with the original rijndael-api-fst.c from
/// aestool/ (fixed IV instead of rand()); see AESToolFile for the format.
func runAESToolTests() {
    begin("AES-Tool: Dateiformat (Referenz: CT1-aestool-Code)")
    let vectors: [(key: [UInt8], name: String, iv: String, data: String, file: String)] = [
        (AESToolFile.hexKey("12abcd")!, "test.txt", "000102030405060708090a0b0c0d0e0f", "Hallo CrypTool!",
         "000102030405060708090a0b0c0d0e0f39b90579585fc579c7d04b0320fa9c9b000102030405060708090a0b0c0d0e0fbb46d8d4fb2d150364de1ce2b44e9f381000000010000000fc4f9032"),
        (AESToolFile.deriveKey(password: AESToolFile.passwordBytes("geheim")), "Brief.txt", "0f0e0d0c0b0a09080706050403020100", "Hallo CrypTool!",
         "0f0e0d0c0b0a090807060504030201002fc3fac54a33cfbf92d95b203feaf4d80f0e0d0c0b0a09080706050403020100c7ddcc98dccf1883dca50a28aeaf6e4c55c7837873e4f095bb3f6814df7af97c1000000020000000fc4f9032"),
        (AESToolFile.hexKey("00")!, "leer.bin", "00000000000000000000000000000000", "",
         "0000000000000000000000000000000000000000000000000000000000000000fd3c721da68a2a8099581f21dd90e9cc0000000010000000fc4f9032"),
        (AESToolFile.hexKey("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")!, "x", "11111111111111111111111111111111", "0123456789abcdef",
         "11111111111111111111111111111111ba4c6db21ad39150e04fc5c84e47f8af170de0528ef93fe9e307d4f0d61bb3f91111111111111111111111111111111165c548d2032975b1940b6653189bb0c32000000010000000fc4f9032"),
        (AESToolFile.hexKey("0123456789ABCDEF01234")!, "y", "22222222222222222222222222222222", "abc",
         "222222222222222222222222222222220390de8da2f0b72928b9434286f45d0b222222222222222222222222222222228d62bd830b111baccf84f57f4a49d53a1000000010000000fc4f9032"),
    ]
    for v in vectors {
        do {
            let file = try AESToolFile.encrypt(Array(v.data.utf8), key: v.key, originalName: v.name, iv: h(v.iv))
            checkEq(file, h(v.file), "AES-Tool-Datei \(v.name)")
            let back = try AESToolFile.decrypt(h(v.file), key: v.key)
            check(back.name == v.name && back.data == Array(v.data.utf8), "AES-Tool entschlüsseln \(v.name)")
            // Windows self-extracting EXE: arbitrary prefix before the payload
            let exe = Array("MZ\u{90}\0 fake aestool.exe".utf8) + [UInt8](repeating: 0xCC, count: 777) + h(v.file)
            check((try? AESToolFile.decrypt(exe, key: v.key))?.data == Array(v.data.utf8), "EXE-Präfix \(v.name)")
        } catch { check(false, "AES-Tool \(v.name): \(error)") }
    }
    check(AESToolFile.hexKey("Abc") == AESToolFile.hexKey("ABC0") && AESToolFile.hexKey("abc00") == [0xAB, 0xC0, 0x00], "Hex-Schlüssel Abc == abc0")
    check(AESToolFile.hexKey("12 G4") == nil, "ungültiges Hex-Zeichen")
    check(AESToolFile.aesKey([1]).count == 16 && AESToolFile.aesKey([UInt8](repeating: 1, count: 17)).count == 24
          && AESToolFile.aesKey([UInt8](repeating: 1, count: 40)).count == 32, "Schlüssel auf 128/192/256 Bit aufgefüllt")
    check(AESToolFile.passwordBytes("Grüße€").count == 6 && AESToolFile.passwordBytes(String(repeating: "x", count: 40)).count == 32,
          "Passwort CP1252, max. 32 Zeichen")
    // wrong key, old version, corrupt, plain
    check((try? AESToolFile.decrypt(h(vectors[0].file), key: [0x12, 0xAB, 0xCE])) == nil, "falscher Schlüssel erkannt")
    var old = h(vectors[0].file); old.replaceSubrange((old.count - 4)..., with: [0x45, 0x36, 0x27, 0x18])
    check(AESToolFile.probe(bytes: old) == .oldVersion, "AES-Tool-1.x-Datei erkannt")
    var bad = h(vectors[0].file); bad[bad.count - 8] = 0xF0
    check(AESToolFile.probe(bytes: bad) == .corrupt, "beschädigte Infoblocklänge erkannt")
    check(AESToolFile.probe(bytes: Array("Hallo".utf8)) == .plain, "Klartextdatei")

    begin("AES-Tool: große Datei, Dateischnittstelle, sicheres Löschen")
    do {
        var big = [UInt8](repeating: 0, count: 200_003)
        for i in big.indices { big[i] = UInt8(truncatingIfNeeded: i &* 7 &+ i >> 9) }
        big += [0, 0, 0]   // trailing zeros must survive the CT1 padding
        let src = scratch.appendingPathComponent("gross.bin"), enc = scratch.appendingPathComponent("gross.aes")
        let dec = scratch.appendingPathComponent("gross.out")
        try Data(big).write(to: src)
        let key = AESToolFile.hexKey("00112233445566778899AABBCCDDEEFF0011")!
        try AESToolFile.encryptFile(src, to: enc, key: key, originalName: src.path)
        guard case .encrypted(let info) = try AESToolFile.probe(url: enc) else { check(false, "Probe"); return }
        check(info.prefixLength == 0 && info.dataLength == UInt64((big.count + 16) & ~15), "Datenlänge im Tail")
        check(AESToolFile.originalName(info, key: key) == "gross.bin", "Name ohne Pfad im Infoblock")
        try AESToolFile.decryptFile(enc, info: info, to: dec, key: key)
        check([UInt8](try Data(contentsOf: dec)) == big, "Datei-Roundtrip 200 KB")
        let mem = try AESToolFile.decrypt([UInt8](try Data(contentsOf: enc)), key: key)
        check(mem.data == big, "Speicher- und Dateischnittstelle kompatibel")
        try AESToolFile.secureDelete(src)
        check(!FileManager.default.fileExists(atPath: src.path), "sicheres Löschen entfernt Datei")
    } catch { check(false, "Datei-API: \(error)") }

    begin("AES-Tool: selbstentschlüsselnde .command-Datei (perl + openssl)")
    do {
        let dir = scratch.appendingPathComponent("selfextract")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plain = Array("Geheimer Brief – Grüße aus CrypTool!\n".utf8) + (0..<5000).map { UInt8(truncatingIfNeeded: $0) }
        for (input, key, name) in [("Pa ßwort", AESToolFile.deriveKey(password: AESToolFile.passwordBytes("Pa ßwort")), "Brief ä.txt"),
                                   ("12abcd", AESToolFile.hexKey("12abcd")!, "hex.bin"),
                                   ("abc", AESToolFile.deriveKey(password: AESToolFile.passwordBytes("abc")), "pw-hexartig.txt")] {
            let cmd = dir.appendingPathComponent("archiv.command")
            let file = try AESToolFile.encrypt(plain, key: key, originalName: name, prefix: AESToolSelfExtractor.prefix)
            try Data(file).write(to: cmd)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cmd.path)
            check((try? AESToolFile.decrypt(file, key: key))?.data == plain, "CrypTool entschlüsselt .command")
            let wrong = runWithInput(cmd.path, "falsch\nfalsch\nfalsch\n")
            check(wrong.status != 0 && wrong.output.contains("Wrong key"), "Skript: falscher Schlüssel abgelehnt")
            let r = runWithInput(cmd.path, input + "\n")
            let out = dir.appendingPathComponent(name)
            check(r.status == 0, "Skript läuft (\(name)): \(r.output)")
            check((try? Data(contentsOf: out)).map { [UInt8]($0) } == plain, "Skript entschlüsselt korrekt (\(name))")
            try? FileManager.default.removeItem(at: out)
        }
        // empty file
        let cmd = dir.appendingPathComponent("leer.command")
        try Data(try AESToolFile.encrypt([], key: [0x42], originalName: "leer.txt", prefix: AESToolSelfExtractor.prefix)).write(to: cmd)
        let r = runWithInput(cmd.path, "42\n")
        check(r.status == 0 && (try? Data(contentsOf: dir.appendingPathComponent("leer.txt")))?.isEmpty == true, "Skript: leere Datei")
    } catch { check(false, "Selbstentschlüsselnde Datei: \(error)") }
}

/// Runs `/bin/sh path` with `input` on stdin.
private func runWithInput(_ path: String, _ input: String) -> (status: Int32, output: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = [path]
    let inPipe = Pipe(), outPipe = Pipe()
    p.standardInput = inPipe
    p.standardOutput = outPipe
    p.standardError = outPipe
    do { try p.run() } catch { return (-1, "\(error)") }
    inPipe.fileHandleForWriting.write(Data(input.utf8))
    try? inPipe.fileHandleForWriting.close()
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}
