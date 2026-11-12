import AppKit
import SwiftUI
import CommonCrypto
import CTCommon
import CTBigNum
import CTModern

// Native version of CT1's "Sichere E-Mail mit S/MIME" (smimedemo: Java "S/MIME Visualisierungs-
// Control-Center" + Flash animation anim.swf by Michael Linden). The Control-Center offers the
// same parameters and defaults (smime.ini); "Signieren starten"/"Verschlüsselung starten" opens
// an independent animation window (like the Flash player) whose texts follow anim.fla. The
// S/MIME message is really computed: CMS SignedData / EnvelopedData (DER), RSA PKCS #1 v1.5,
// SHA-1/MD5, AES-128-CBC / 3DES-CBC, base64 / quoted-printable.

extension CT1Visualizations {
    static func openSMIME() {
        WindowPresenter.tool(id: "ct1-smime", title: "S/MIME Visualisierungs-Control-Center", size: CGSize(width: 560, height: 760)) {
            SMIMEControlCenterView()
        }
    }
}

// MARK: - Parameters and computation

struct SMIMEParameters {
    var sign = true
    var hash: DigestAlgorithmID = .sha1
    var multipartSigned = true          // false: PKCS#7/signed-data
    var base64 = false                  // smime.ini: transCode 1 = quoted-printable
    var aes = true                      // false: Triple-DES
    var from = "alice@wunderland.de"
    var to = "bob@web.de"
    var subject = "Hallo"
    var text = "Hallo Bob, schöne Grüße aus dem Wunderland!"
}

/// Minimal DER encoder for the CMS structures.
enum DERBuilder {
    static func length(_ n: Int) -> [UInt8] {
        if n < 128 { return [UInt8(n)] }
        var b: [UInt8] = []
        var v = n
        while v > 0 { b.insert(UInt8(v & 0xff), at: 0); v >>= 8 }
        return [0x80 | UInt8(b.count)] + b
    }
    static func tlv(_ tag: UInt8, _ c: [UInt8]) -> [UInt8] { [tag] + length(c.count) + c }
    static func seq(_ parts: [UInt8]...) -> [UInt8] { tlv(0x30, parts.flatMap { $0 }) }
    static func set(_ parts: [UInt8]...) -> [UInt8] { tlv(0x31, parts.flatMap { $0 }) }
    static func int(_ v: Int) -> [UInt8] { int(bytes: v == 0 ? [0] : withUnsafeBytes(of: UInt64(v).bigEndian, Array.init).drop { $0 == 0 }.map { $0 }) }
    static func int(bytes: [UInt8]) -> [UInt8] { tlv(0x02, (bytes.first ?? 0) & 0x80 != 0 ? [0] + bytes : bytes) }
    static func octet(_ b: [UInt8]) -> [UInt8] { tlv(0x04, b) }
    static let null: [UInt8] = [0x05, 0x00]
    static func explicit(_ n: UInt8, _ c: [UInt8]) -> [UInt8] { tlv(0xA0 | n, c) }
    static func oid(_ s: String) -> [UInt8] {
        let p = s.split(separator: ".").compactMap { Int($0) }
        var out: [UInt8] = [UInt8(p[0] * 40 + p[1])]
        for v in p.dropFirst(2) {
            var chunk: [UInt8] = [UInt8(v & 0x7f)]
            var x = v >> 7
            while x > 0 { chunk.insert(UInt8(x & 0x7f) | 0x80, at: 0); x >>= 7 }
            out += chunk
        }
        return tlv(0x06, out)
    }
    static func name(cn: String) -> [UInt8] {
        seq(set(seq(oid("2.5.4.3"), tlv(0x0C, Array(cn.utf8)))))
    }
}

struct SMIMEComputation {
    struct Party { let name: String; let email: String; let key: RSAKeyPair; let serial: Int }

    let p: SMIMEParameters
    let alice: Party, bob: Party
    let date: String
    let charset: String
    let boundary = "----=_Part_0_CrypTool"

    // results
    var plainLines: [String] = []
    var canonicalLines: [String] = []
    var encodedLines: [String] = []
    var finalLines: [String] = []
    var mimeEntity: [UInt8] = []
    var digest: [UInt8] = []
    var signature: [UInt8] = []
    var sessionKey: [UInt8] = []
    var iv: [UInt8] = []
    var encryptedKey: [UInt8] = []
    var encryptedContent: [UInt8] = []
    var cms: [UInt8] = []
    var verified = false
    var decrypted = ""

    static func hashAlgorithm(_ d: DigestAlgorithmID) -> HashAlgorithm { d == .md5 ? .md5 : .sha1 }

    init(parameters: SMIMEParameters, alice: RSAKeyPair, bob: RSAKeyPair) throws {
        p = parameters
        self.alice = Party(name: "Alice", email: parameters.from, key: alice, serial: 0x2A51)
        self.bob = Party(name: "Bob", email: parameters.to, key: bob, serial: 0x2B07)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        date = f.string(from: Date())
        charset = parameters.text.unicodeScalars.allSatisfy { $0.isASCII } ? "us-ascii" : "utf-8"
        try compute()
    }

    private var header: [String] {
        ["Date: \(date)", "From: \(p.from)", "To: \(p.to)", "Subject: \(p.subject)", "MIME-Version: 1.0"]
    }

    static func wrap(_ s: String, _ n: Int) -> [String] {
        var out: [String] = []
        var cur = Substring(s)
        while cur.count > n { out.append(String(cur.prefix(n))); cur = cur.dropFirst(n) }
        if !cur.isEmpty || out.isEmpty { out.append(String(cur)) }
        return out
    }

    static func quotedPrintable(_ text: String) -> [String] {
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            var out = ""
            var cur = ""
            let bytes = Array(line.utf8)
            for (i, b) in bytes.enumerated() {
                var piece: String
                let last = i == bytes.count - 1
                if (b >= 33 && b <= 126 && b != 61) || (b == 32 && !last) {
                    piece = String(UnicodeScalar(b))
                } else {
                    piece = String(format: "=%02X", b)
                }
                if cur.count + piece.count > 75 { out += cur + "=\n"; cur = "" }
                cur += piece
            }
            out += cur
            lines += out.components(separatedBy: "\n")
        }
        return lines
    }

    private func encodeBody() -> [String] {
        if p.base64 {
            return Base64Codec.encode(Array(p.text.utf8), lineLength: 76).components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        return Self.quotedPrintable(p.text)
    }

    private static func base64Lines(_ b: [UInt8]) -> [String] {
        Base64Codec.encode(b, lineLength: 76).components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func issuerAndSerial(_ party: Party) -> [UInt8] {
        DERBuilder.seq(DERBuilder.name(cn: "CrypTool Demo-CA"), DERBuilder.int(party.serial))
    }

    private static func cbc(_ alg: CCAlgorithm, key: [UInt8], iv: [UInt8], data: [UInt8], encrypt: Bool) throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: data.count + 32)
        var moved = 0
        let st = CCCrypt(CCOperation(encrypt ? kCCEncrypt : kCCDecrypt), alg, CCOptions(kCCOptionPKCS7Padding),
                         key, key.count, iv, data, data.count, &out, out.count, &moved)
        guard st == kCCSuccess else { throw CTError("Verschlüsselung konnte nicht ausgeführt werden") }
        return Array(out.prefix(moved))
    }

    private mutating func compute() throws {
        let body = p.text
        plainLines = header + ["Content-Type: text/plain", ""] + body.components(separatedBy: "\n")
        canonicalLines = header.map { $0 + " ␍␊" } + ["Content-Type: text/plain; charset=\(charset) ␍␊", " ␍␊"]
            + body.components(separatedBy: "\n").map { $0 + " ␍␊" }
        let cte = p.base64 ? "base64" : "quoted-printable"
        let enc = encodeBody()
        encodedLines = header + ["Content-Type: text/plain; charset=\(charset)", "Content-Transfer-Encoding: \(cte)", ""] + enc
        let entityText = "Content-Type: text/plain; charset=\(charset)\r\nContent-Transfer-Encoding: \(cte)\r\n\r\n"
            + enc.joined(separator: "\r\n") + "\r\n"
        mimeEntity = Array(entityText.utf8)

        let data = DERBuilder.oid("1.2.840.113549.1.7.1")
        let rsaAlg = DERBuilder.seq(DERBuilder.oid("1.2.840.113549.1.1.1"), DERBuilder.null)
        if p.sign {
            digest = Hashing.hash(mimeEntity, algorithm: Self.hashAlgorithm(p.hash))
            signature = try PKCS1.sign(hash: digest, algorithm: p.hash, key: alice.key)
            verified = PKCS1.verify(signature: signature, hash: digest, algorithm: p.hash, key: alice.key.publicKey)
            let digestAlg = DERBuilder.seq(DERBuilder.oid(p.hash.oid), DERBuilder.null)
            let signerInfo = DERBuilder.seq(DERBuilder.int(1), issuerAndSerial(alice), digestAlg, rsaAlg, DERBuilder.octet(signature))
            let encap = p.multipartSigned ? DERBuilder.seq(data)
                                          : DERBuilder.seq(data, DERBuilder.explicit(0, DERBuilder.octet(mimeEntity)))
            let signedData = DERBuilder.seq(DERBuilder.int(1), DERBuilder.set(digestAlg), encap, DERBuilder.set(signerInfo))
            cms = DERBuilder.seq(DERBuilder.oid("1.2.840.113549.1.7.2"), DERBuilder.explicit(0, signedData))
            let micalg = p.hash == .md5 ? "md5" : "sha1"
            if p.multipartSigned {
                finalLines = header + [
                    "Content-Type: multipart/signed; protocol=\"application/pkcs7-signature\";",
                    "\tmicalg=\(micalg); boundary=\"\(boundary)\"", "",
                    "--\(boundary)",
                    "Content-Type: text/plain; charset=\(charset)", "Content-Transfer-Encoding: \(cte)", ""] + enc + [
                    "--\(boundary)",
                    "Content-Type: application/pkcs7-signature; name=smime.p7s",
                    "Content-Transfer-Encoding: base64",
                    "Content-Disposition: attachment; filename=smime.p7s", ""] + Self.base64Lines(cms) + ["--\(boundary)--"]
            } else {
                finalLines = header + [
                    "Content-Type: application/pkcs7-mime; smime-type=signed-data;", "\tname=smime.p7m",
                    "Content-Transfer-Encoding: base64",
                    "Content-Disposition: attachment; filename=smime.p7m", ""] + Self.base64Lines(cms)
            }
        } else {
            sessionKey = (0..<(p.aes ? 16 : 24)).map { _ in UInt8.random(in: 0...255) }
            iv = (0..<(p.aes ? 16 : 8)).map { _ in UInt8.random(in: 0...255) }
            let alg = CCAlgorithm(p.aes ? kCCAlgorithmAES : kCCAlgorithm3DES)
            encryptedContent = try Self.cbc(alg, key: sessionKey, iv: iv, data: mimeEntity, encrypt: true)
            encryptedKey = try PKCS1.encrypt(sessionKey, key: bob.key.publicKey)
            let contentAlg = DERBuilder.seq(DERBuilder.oid(p.aes ? "2.16.840.1.101.3.4.1.2" : "1.2.840.113549.3.7"), DERBuilder.octet(iv))
            let recipient = DERBuilder.seq(DERBuilder.int(0), issuerAndSerial(bob), rsaAlg, DERBuilder.octet(encryptedKey))
            let eci = DERBuilder.seq(data, contentAlg, DERBuilder.tlv(0x80, encryptedContent))
            let env = DERBuilder.seq(DERBuilder.int(0), DERBuilder.set(recipient), eci)
            cms = DERBuilder.seq(DERBuilder.oid("1.2.840.113549.1.7.3"), DERBuilder.explicit(0, env))
            // Bob's side
            let k = try PKCS1.decrypt(encryptedKey, key: bob.key)
            let plain = try Self.cbc(alg, key: k, iv: iv, data: encryptedContent, encrypt: false)
            decrypted = String(decoding: plain, as: UTF8.self)
            finalLines = header + [
                "Content-Type: application/pkcs7-mime; smime-type=enveloped-data;", "\tname=smime.p7m",
                "Content-Transfer-Encoding: base64",
                "Content-Disposition: attachment; filename=smime.p7m", ""] + Self.base64Lines(cms)
        }
    }
}

// MARK: - Animation script

enum SMIMEAnimationScript {
    static let stage = CGSize(width: 1000, height: 640)

    static func build(_ c: SMIMEComputation) -> AnimScript {
        let b = AnimScriptBuilder()
        let p = c.p
        let screenX: CGFloat = 20, screenY: CGFloat = 104, lineH: CGFloat = 14.6, maxLines = 27
        var screenIDs: [String] = []
        var current: [String] = []
        var texts: [String] = []

        func say(_ lines: String...) {
            b.remove(texts); texts = []
            for (i, l) in lines.enumerated() {
                let id = "say\(i)"
                b.text(id, l, x: 20, y: 552 + CGFloat(i) * 20, size: 13.5)
                texts.append(id)
            }
        }
        func screen(_ lines: [String], title: String) {
            b.setText("scrT", title)
            current = Array(lines.prefix(maxLines))
            if lines.count > maxLines { current[maxLines - 1] = "…" }
            for (i, l) in current.enumerated() {
                let id = "src\(i)"
                if b.contains(id) { b.setText(id, l) } else {
                    b.text(id, l, x: screenX + 10, y: screenY + 28 + CGFloat(i) * lineH, size: 10.5, mono: true, z: 3)
                }
            }
            for i in current.count..<max(current.count, screenIDs.count) { b.remove("src\(i)") }
            screenIDs = (0..<current.count).map { "src\($0)" }
        }
        func highlight(_ prefix: String?, count: Int = 1, color: AnimColor = .highlight) {
            guard let prefix, let i = current.firstIndex(where: { $0.hasPrefix(prefix) }) else { b.remove("hl"); return }
            let y = screenY + 27 + CGFloat(i) * lineH
            if b.contains("hl") {
                b.move("hl", x: screenX + 6, y: y); b.setSize("hl", w: 548, h: lineH * CGFloat(count) + 1); b.setFill("hl", color)
            } else {
                b.box("hl", x: screenX + 6, y: y, w: 548, h: lineH * CGFloat(count) + 1, fill: color, stroke: .clear, z: 1)
            }
        }
        func info(_ lines: [String]) {
            b.removeAll(prefix: "inf")
            if lines.isEmpty { return }
            b.box("infB", x: 600, y: 418, w: 390, h: 22 + CGFloat(lines.count) * 15, fill: .cellAlt, stroke: .gray, z: 0)
            for (i, l) in lines.enumerated() { b.text("inf\(i)", l, x: 608, y: 424 + CGFloat(i) * 15, size: 10.5, mono: true, z: 2) }
        }
        // network
        let nodes: [(String, CGFloat, CGFloat)] = [("💻 Alice-PC", 612, 70), ("🗄 Mail-Server", 812, 70), ("🔐 S/MIME-Gateway", 812, 170),
                                                  ("📨 Mail-Gateway", 812, 270), ("🌐 Internet", 812, 360), ("👨 Bob", 612, 360)]
        func envelope(at n: Int) {
            let (_, x, y) = nodes[n]
            if b.contains("env") { b.move("env", x: x + 152, y: y - 4) } else { b.text("env", "✉️", x: x + 152, y: y - 4, size: 22, z: 8) }
        }
        func hl(node: Int?) {
            for i in nodes.indices { b.setFill("nodeB\(i)", i == node ? .highlight : .cell) }
        }

        let signing = p.sign
        let sub = signing ? (p.multipartSigned ? "S/MIME: Signieren von E-Mail (hier im multipart/signed-Format)"
                                               : "S/MIME: Signieren von E-Mail (hier im signed-data Format)")
                          : "S/MIME: Verschlüsseln von E-Mail"
        let verb = signing ? "signiert" : "verschlüsselt"

        // Prolog
        b.chapter("Prolog")
        b.text("sub", sub, x: 20, y: 10, size: 19, bold: true)
        b.text("author", "entworfen von Michael Linden · Zeichentrickfiguren in Anlehnung an Parker/Stone", x: 20, y: 36, size: 11, color: .secondary)
        say("Willkommen bei der visuellen Aufbereitung des S/MIME Protokolls. Zur Steuerung benutzen Sie bitte die Schaltflächen unterhalb",
            "der Darstellung. Beginnen Sie mit 'Weiter'. Über das Kapitelmenü können Sie direkt zu den einzelnen Abschnitten springen.")
        b.commit()
        b.text("alice", "👩", x: 24, y: 52, size: 38, z: 4)
        b.text("aliceL", "Alice", x: 72, y: 66, size: 15, bold: true)
        say("Das ist Alice. Alice möchte ihrem Freund Bob eine E-Mail senden. Dazu verwendet sie einen S/MIME-fähigen E-Mail-Client.")
        b.commit()

        // E-Mail schreiben
        b.chapter("E-Mail schreiben")
        b.box("scr", x: screenX, y: screenY, w: 560, h: 432, fill: .white, stroke: .gray, z: 0)
        b.box("scrBar", x: screenX, y: screenY, w: 560, h: 22, fill: .cellAlt, stroke: .gray, z: 0)
        b.text("scrT", "", x: screenX + 10, y: screenY + 3, size: 12, bold: true, z: 2)
        screen(["Von:      \(p.from)", "An:       \(p.to)", "Betreff:  \(p.subject)", ""] + p.text.components(separatedBy: "\n"),
               title: "E-Mail-Client von Alice – Neue Nachricht")
        if signing {
            say("Alice schreibt Bob die E-Mail, die Ihre digitale Signatur tragen soll. Die Signatur soll sicherstellen, dass die E-Mail tatsächlich von Alice stammt.",
                "Um zu sehen wie diese Signatur tatsächlich aussieht, werfen wir einen Blick hinter die Kulissen.")
        } else {
            say("Alice schreibt Bob die E-Mail, die verschlüsselt werden soll. Sie will sicherstellen, dass den Inhalt der E-Mail niemand anders außer Bob lesen kann.",
                "Um zu sehen, wie die verschlüsselte Nachricht tatsächlich aussieht, werfen wir einen Blick hinter die Kulissen.")
        }
        b.commit()
        screen(c.plainLines, title: "Quelltext der E-Mail")
        say("Hinter jeder E-Mail verbirgt sich der so genannte Quelltext. Dieser bleibt Alice in ihrem E-Mail-Client gewöhnlich verborgen.",
            "Auf dem Bildschirm sehen Sie den Quelltext der E-Mail, die Sie zuvor im S/MIME Visualisierungs-Control-Center eingegeben haben.")
        b.commit()
        let headerSteps: [(String, [String])] = [
            ("Date:", ["Die erste Zeile des Quelltextes gibt das Datum an, welches durch das Schlüsselwort 'Date:' definiert wird. Es setzt sich zusammen aus Wochentag,",
                       "Monat, Jahr und Uhrzeit, an der die E-Mail versendet wird. Am Ende wird die Differenz zu einer speziellen Zeitreferenz angegeben."]),
            ("From:", ["Die zweite Zeile gibt den Absender bzw. die Absenderin der E-Mail an. Das Schlüsselwort 'From:' definiert die E-Mail Adresse. Optional steht hier auch",
                       "eine Freundesbezeichnung ('friendly name') zur leichteren Identifizierung. In diesem Fall muss die E-Mail-Adresse in spitzen Klammern (< >) stehen."]),
            ("To:", ["In der dritten Zeile wird der Empfänger durch das Schlüsselwort 'To:' festgelegt."]),
            ("Subject:", ["Die vierte Zeile gibt den Betreff der E-Mail an und wird durch das Schlüsselwort 'Subject:' definiert."]),
            ("MIME-Version:", ["Um den Inhalt der E-Mail (Attachments, etc.) besser beschreiben zu können, werden erweiterte Schlüsselwörter herangezogen.",
                               "Das hier angezeigte Feld definiert die Versionsnummer, nach welcher die E-Mail aufgebaut ist."]),
            ("Content-Type:", ["In dieser Zeile wird der angefügte Inhaltstyp (MIME-Datentyp) genau beschrieben. Anhand dieser Information kann der Mail-Client des Empfängers das",
                               "entsprechende Anzeigemodul zur Weiterverarbeitung starten. Mögliche Inhalte sind z.B. Text, Audio und Dokumente."]),
        ]
        for (prefix, t) in headerSteps {
            highlight(prefix)
            if t.count == 2 { say(t[0], t[1]) } else { say(t[0]) }
            b.commit()
        }
        highlight("Date:", count: 6, color: .cellAlt)
        say("Die genannten Felder werden unter der Bezeichnung 'Header' zusammengefasst. Ihre Reihenfolge bestimmt dabei der E-Mail-Client und ist beliebig.",
            "In den MIME-Spezifikationen existieren noch eine Menge an weiteren Schlüsselwörtern, auf deren Darstellung an dieser Stelle jedoch verzichtet wird.")
        b.commit()
        let bodyStart = c.plainLines.count - p.text.components(separatedBy: "\n").count
        highlight(c.plainLines[bodyStart].isEmpty ? nil : c.plainLines[bodyStart], count: p.text.components(separatedBy: "\n").count)
        say("Nach dem Header folgt der so genannte 'Body', in dem die Inhaltstypen abgelegt werden können. Hier finden neben dem Nachrichtentext selbst",
            "alle möglichen Dateianhänge ihren Platz. An dieser Stelle gibt es nur Text als Inhaltstyp, denn Alice hat auf weitere Dateianhänge verzichtet.")
        b.commit()
        if let i = c.plainLines.firstIndex(of: "") {
            let y = screenY + 27 + CGFloat(i) * lineH
            b.move("hl", x: screenX + 6, y: y); b.setSize("hl", w: 548, h: lineH + 1); b.setFill("hl", .highlight)
        }
        say("Header und Body werden durch eine Leerzeile voneinander getrennt.")
        b.commit()

        // Kanonisierung
        b.chapter("Kanonisierung")
        b.remove("hl")
        screen(c.canonicalLines, title: "Quelltext der E-Mail – kanonisiert")
        say("Als nächstes wird die E-Mail automatisch umgeformt (kanonisiert), damit die in ihr enthaltenen Zeichen auf anderen Computersystemen einheitlich",
            "interpretiert werden können.")
        b.commit()
        highlight("Content-Type:")
        say("Dabei hängt das genaue Vorgehen vom MIME-Datentyp ab. Beim Typ 'text/plain' muss zusätzlich der verwendete Zeichensatz (hier charset=\(c.charset))",
            "mit angegeben werden. ASCII (American Standard Code for Information Interchange) ist der im Internet verbreitetste Standard.")
        b.commit()

        // Transfercodierung
        b.chapter("Transfercodierung")
        b.remove("hl")
        say("An dieser Stelle wird die E-Mail für den Versand vorbereitet. Die Transfercodierung schützt die E-Mail vor (ungewollten) Modifikationen durch",
            "Mailgateways bzw. -server die nicht mehr als 7-bit lange Zeichensätze verarbeiten können.")
        b.commit()
        screen(c.encodedLines, title: "Quelltext der E-Mail – transfercodiert")
        highlight("Content-Transfer-Encoding:")
        let cte = p.base64 ? "base64" : "quoted-printable"
        say("Es gibt verschiedene Arten von Transfercodierungen. Die hier gewählte ist '\(cte)'. Sie wird durch das Schlüsselwort",
            "'Content-Transfer-Encoding' im Header festgelegt. Im Vergleich zu 'quoted-printable' ist 'base64' vom menschlichen Auge nicht mehr lesbar.")
        b.commit()
        let encStart = c.encodedLines.count - (c.encodedLines.count - (c.encodedLines.firstIndex(of: "") ?? 0) - 1)
        if encStart < c.encodedLines.count {
            highlight(c.encodedLines[encStart], count: c.encodedLines.count - encStart)
        }
        if p.base64 {
            say("In 'base64' werden 8-bit Binärdaten in eine Zeichenfolge codiert, die aus selektierten, codepage-unabhängigen ASCII Zeichen besteht.",
                "Zur Codierung werden die Zeichen A–Z, a–z, 0–9, + und / herangezogen. Das Zeichen = definiert das Ende der Zeichenfolge.")
        } else {
            say("In 'quoted printable' werden Zeichen, die nicht dem ASCII-Zeichensatz entsprechen (z.B. Umlaute), durch eine Folge von drei ASCII-Zeichen ersetzt.",
                "Dies betrifft den gesamten Body der E-Mail.")
            b.commit()
            say("Umlaute werden konvertiert und die zusätzliche Notation für den Zeilenumbruch (<CR> <LF>) wird eingefügt.",
                "7-bit beschränkte Mail-Gateways können nun den Inhalt der E-Mail ohne Verluste weiter reichen.")
            b.commit()
            say("Das Verfahren hat den Vorteil, dass die meisten in ASCII enthaltenen Zeichen unverändert codiert werden und somit auch angezeigt werden",
                "können, falls die quoted-printable Codierung von Bob's E-Mail-Client nicht unterstützt wird. So ist der Text allgemein noch relativ gut lesbar.")
        }
        b.commit()

        // S/MIME-Gateway
        b.chapter("S/MIME-Gateway")
        b.remove("hl")
        b.box("intranet", x: 598, y: 40, w: 394, h: 270, fill: .clear, stroke: .gray, z: -1)
        b.text("intranetL", "Firmennetz (Intranet)", x: 606, y: 290, size: 11, color: .secondary)
        for (i, n) in nodes.enumerated() {
            b.box("nodeB\(i)", x: n.1, y: n.2 - 4, w: 148, h: 30, fill: .cell, stroke: .gray, z: 1)
            b.text("node\(i)", n.0, x: n.1 + 8, y: n.2 + 2, size: 13, z: 2)
        }
        let links: [(Int, Int)] = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
        for (k, l) in links.enumerated() {
            let a = nodes[l.0], z = nodes[l.1]
            let pa = CGPoint(x: a.1 + (l.0 == 0 ? 148 : 74), y: a.2 + (l.0 == 0 ? 11 : 26))
            let pz = CGPoint(x: z.1 + (l.1 == 1 ? 0 : (l.1 == 5 ? 148 : 74)), y: z.2 + (l.1 == 1 || l.1 == 5 ? 11 : -4))
            b.line("link\(k)", [pa, pz], color: .secondary, z: 0)
        }
        envelope(at: 0)
        hl(node: 0)
        say("Bei Site-to-Site-Implementierungen zwischen Firmen wird die E-Mail nicht auf dem Client-Rechner selbst \(verb), sondern über das Intranet an ein",
            "dediziertes S/MIME-Gateway weitergeleitet. Der \(signing ? "Signiervorgang" : "Verschlüsselungsvorgang") an sich ist lokal und serverseitig gleich.")
        b.commit()
        envelope(at: 1); hl(node: 1)
        say("Durch das firmeninterne Netzwerk wird die E-Mail an den Mail-Server des Unternehmens weitergeleitet.")
        b.commit()
        envelope(at: 2); hl(node: 2)
        say("Von dort aus wird die E-Mail nicht wie gewohnt direkt über ein Mail-Gateway ins Internet geschickt, sondern an den S/MIME-Gateway weitergeleitet.")
        b.commit()
        let party = signing ? c.alice : c.bob
        let nBytes = party.key.publicKey.byteLength
        info(["Zertifikat aus der PSE:",
              "  Inhaber:      CN=\(party.name), E=\(party.email)",
              "  Aussteller:   CN=CrypTool Demo-CA",
              String(format: "  Seriennummer: %04X", party.serial),
              "  Schlüssel:    RSA \(party.key.bitLength) Bit, e = \(party.key.e)",
              "  n = " + String(party.key.n.toString(radix: 16).lowercased().prefix(40)) + "…"])
        if signing {
            say("Auf dem S/MIME-Gateway findet das Signieren der E-Mail statt. Auf diesem Server sind alle Zertifikate in einer PSE (Personal Security Environment)",
                "abgelegt. Zunächst sucht der Server das Zertifikat des Absenders in seiner Datenbank.")
        } else {
            say("Auf dem S/MIME-Gateway findet das Verschlüsseln der E-Mail statt. Auf diesem Server sind alle Zertifikate in einer PSE (Personal Security",
                "Environment) abgelegt. Zertifikate enthalten spezielle Schlüssel. Zunächst sucht der Server Bobs Zertifikat in seiner Datenbank.")
        }
        b.commit()
        say("Das Zertifikat enthält eine Reihe von speziellen Attributen und eine eindeutige Seriennummer, die den Eigentümer bestätigen.")
        b.commit()

        // Signieren / Verschlüsseln
        b.chapter(signing ? "Signieren" : "Verschlüsseln")
        let hx = { (v: [UInt8], n: Int) -> String in v.prefix(n).map { String(format: "%02x", $0) }.joined() + (v.count > n ? "…" : "") }
        if signing {
            info(["\(p.hash.displayName)(MIME-Teil) =", "  " + hx(c.digest, 24),
                  "Signatur = RSA(privater Schlüssel Alice, DigestInfo)", "  " + hx(c.signature, 20) + " (\(c.signature.count) Byte)"])
            say("Danach beginnt der Signaturprozess. Der in der PSE enthaltene private Schlüssel wird eingesetzt, um mittels eines speziellen Signaturverfahrens Alice",
                "E-Mail digital zu signieren.")
        } else {
            info(["Sitzungsschlüssel (\(p.aes ? "AES-128" : "Triple-DES"), zufällig) =", "  " + hx(c.sessionKey, 24),
                  "IV = " + hx(c.iv, 16),
                  "Body: \(p.aes ? "AES" : "3DES")-CBC → \(c.encryptedContent.count) Byte Chiffretext",
                  "Sitzungsschlüssel mit Bobs öffentl. Schlüssel (RSA):", "  " + hx(c.encryptedKey, 20) + " (\(nBytes) Byte)"])
            say("Danach verschlüsselt das S/MIME-Gateway Alice E-Mail. Bob's öffentlicher Schlüssel aus seinem Zertifikat wird eingesetzt, um den Body mittels",
                "eines speziellen Verfahrens in Chiffretext umzuwandeln. (Genauer: Der Body wird mit einem zufälligen Sitzungsschlüssel symmetrisch verschlüsselt,",
                "nur dieser Sitzungsschlüssel wird mit Bobs öffentlichem RSA-Schlüssel verschlüsselt – hybride Verschlüsselung.)")
        }
        b.commit()
        screen(c.finalLines, title: "Quelltext der E-Mail – \(verb)")
        say("Das Ergebnis des Verfahrens ist im obigen Fenster zu sehen. Wie zuvor handelt es sich hierbei um den Quelltext der E-Mail, der durch das",
            "S/MIME-Gateway weiterverarbeitet wurde.")
        b.commit()
        highlight("Content-Type:", count: 2)
        if signing && p.multipartSigned {
            say("Folgende Informationen kommen hinzu bzw. werden ersetzt: Der angefügte Inhaltstyp (MIME-Datentyp) beschreibt nun die Form der Signatur,",
                "die an die E-Mail angehängt wurde. Er ist nicht länger vom Typ 'text/plain' sondern vom Typ 'multipart/signed'.")
            b.commit()
            say("Der Typ 'multipart/signed' setzt die E-Mail aus mehreren Teilen, dem",
                "Nachrichtentext und der Signatur des Absenders zusammen. Die Trennmarke wird durch das Schlüsselwort 'boundary' definiert.")
            b.commit()
            if let s = c.finalLines.firstIndex(of: "--\(c.boundary)") {
                let e = c.finalLines[(s + 1)...].firstIndex(of: "--\(c.boundary)") ?? s + 1
                highlight(c.finalLines[s], count: min(e - s, maxLines - s))
                say("Dies ist der Nachrichtenteil.")
                b.commit()
                highlight("Content-Type: application/pkcs7-signature", count: max(1, min(maxLines, c.finalLines.count) - e - 1))
                say("Dies ist der Nachrichtenteil.... gefolgt von der Signatur.")
                b.commit()
            }
            highlight("\tmicalg")
            say("Zur Erstellung der Signatur wurde ein Hashwert der Mail gebildet. Damit Bobs Rechner die Gültigkeit der von Alice erstellten Signatur überprüfen kann,",
                "muss er wissen, welches Hashverfahren verwendet wurde.")
            b.commit()
            say("Das Schlüsselwort zur Identifikation heißt 'micalg' und das Hashverfahren, welches hier zum Einsatz kommt, heißt \(p.hash.displayName).",
                "Der Hashwert selbst wird in der Signatur hinterlegt.")
            b.commit()
            highlight("Content-Transfer-Encoding: base64")
            say("Wie der Nachrichtentext muss auch die Signatur in einem 7-bit kompatiblen Format (Transfercodierung) vorliegen, bevor sie über das Internet",
                "verschickt werden kann. Dazu wird standardmäßig das base64-Format benutzt.")
            b.commit()
            highlight("Content-Disposition:")
            say("Das Schlüsselwort 'Content-Disposition' gibt an, dass die Signatur in einem Dateianhang mit der Erweiterung '.p7s' abgelegt ist. Diese Endung",
                "wird für Dateien mit kryptographischem Inhalt verwendet. Deren Struktur ist in den 'Cryptographic Message Syntax Standard' (PKCS#7) definiert.")
            b.commit()
        } else if signing {
            say("Folgende Informationen kommen hinzu bzw. werden ersetzt: Der Inhaltstyp (MIME-Datentyp) weist nun auf kryptographischen Inhalt hin, der an die",
                "E-Mail angehängt wurde. Anstelle von 'text/plain' rückt 'application/pkcs7-mime' mit dem Typ 'signed-data'.")
            b.commit()
            if let i = c.finalLines.firstIndex(of: "") {
                highlight(c.finalLines[min(i + 1, c.finalLines.count - 1)], count: min(maxLines, c.finalLines.count) - i - 1)
            }
            say("Im signed-data-Format stehen Nachricht und Signatur gemeinsam in einem PKCS#7-Objekt, das base64-codiert wird.",
                "Der Hashwert selbst wird in der Signatur hinterlegt.")
            b.commit()
        } else {
            say("Folgende Informationen kommen hinzu bzw. werden ersetzt: Der Inhaltstyp (MIME-Datentyp) weist nun auf kryptographischen Inhalt hin, der an die",
                "E-Mail angehängt wurde. Anstelle von 'text/plain' rückt 'application/pkcs7-mime'.")
            b.commit()
            say("Genauer gesagt haben wir es hier mit dem Typ 'enveloped-data' zu tun, der auf ein verschlüsseltes Objekt im Anhang hinweist.")
            b.commit()
            if let i = c.finalLines.firstIndex(of: "") {
                highlight(c.finalLines[min(i + 1, c.finalLines.count - 1)], count: min(maxLines, c.finalLines.count) - i - 1)
            }
            say("Dies ist die verschlüsselte Nachricht.")
            b.commit()
            say("Zudem ist das verschlüsselte Objekt in eine Kodierungsform gebracht worden, die die Integrität der Nachricht bei Versand über verschiedene",
                "Mail-Gateways im Internet schützt. Eine mögliche Form der Kodierung ist 'base64'. Sie erfahren mehr darüber in der Visualisierung für das Signieren.")
            b.commit()
        }
        if signing {
            say("Der PKCS#7-Standard beschreibt den syntaktischen Aufbau von Nachrichten für das Signieren, Verschlüsseln, oder Authentifizieren. Der Inhalt dieser",
                "Spezifikationen ist sehr umfangreich und wird an dieser Stelle nicht näher ausgeführt.")
            b.commit()
            info(["PKCS#7/CMS SignedData (\(c.cms.count) Byte):", "  contentType  signedData", "  digestAlg    \(p.hash.displayName)",
                  "  signerInfo   CN=CrypTool Demo-CA, Nr. \(String(format: "%04X", c.alice.serial))", "  signature    \(c.signature.count) Byte RSA"])
            say("Das PKCS#7-Objekt gibt hier die Signatur mit allen Informationen, die zur Verifikation der Signatur erforderlich sind, an.")
            b.commit()
        }

        // Versand
        b.chapter("Versand")
        b.remove("hl")
        info([])
        envelope(at: 3); hl(node: 3)
        say("Nachdem die E-Mail \(verb) wurde, leitet das S/MIME-Gateway die E-Mail weiter an das firmeninterne Mail-Gateway.")
        b.commit()
        envelope(at: 4); hl(node: 4)
        say("Nun verlässt die E-Mail das firmeninterne Netz. Aufgrund der \(signing ? "Signierung" : "Verschlüsselung") mit Hilfe des S/MIME-Formats ist die Mail auf ihrem ganzen Weg",
            signing ? "durch das Internet vor unbemerkten Veränderungen geschützt." : "durch das Internet sicher.")
        b.commit()

        // Empfang
        b.chapter("Empfang")
        envelope(at: 5); hl(node: 5)
        if signing {
            info(["Bobs E-Mail-Client prüft die Signatur:", "  \(p.hash.displayName) des empfangenen MIME-Teils berechnen,",
                  "  Signatur mit Alices öffentl. Schlüssel prüfen:", c.verified ? "  ✓ Signatur gültig" : "  ✗ Signatur ungültig"])
            say("Bob empfängt die E-Mail und kann dank der gültigen Signatur sicher sein, dass sie tatsächlich von Alice kommt.")
        } else {
            info(["Bobs E-Mail-Client entschlüsselt:", "  Sitzungsschlüssel mit Bobs privatem Schlüssel,", "  danach den Body (\(p.aes ? "AES" : "3DES")-CBC):",
                  "  " + String(p.text.prefix(44))])
            say("Bob empfängt die E-Mail. Sein E-Mail-Client entschlüsselt die Nachricht mit seinem privaten Schlüssel. Er liest Alice Nachricht in Klartext.")
        }
        b.commit()
        say("Ende der Visualisierung. Schließen Sie das Fenster oder nutzen Sie die Navigationsleiste, um zu den jeweiligen Kapiteln zu springen.")
        b.commit()
        return AnimScript(b, size: stage)
    }
}

// MARK: - Views

@MainActor
final class SMIMEKeys: ObservableObject {
    static let shared = SMIMEKeys()
    @Published var alice: RSAKeyPair?
    @Published var bob: RSAKeyPair?
    private var started = false

    func prepare() {
        guard !started else { return }
        started = true
        Task.detached(priority: .userInitiated) {
            let a = RSAKeyPair.generate(bits: 1024)
            let b = RSAKeyPair.generate(bits: 1024)
            await MainActor.run {
                SMIMEKeys.shared.alice = a
                SMIMEKeys.shared.bob = b
            }
        }
    }
}

struct SMIMEControlCenterView: View {
    @ObservedObject private var keys = SMIMEKeys.shared
    @CTState private var prm = SMIMEParameters()
    @CTState private var error: String?

    var body: some View {
        Form {
            Section {
                Text("S/MIME Visualisierungs-Control-Center").font(.title3.bold())
                DisclosureGroup("Beschreibung") {
                    Text("Hier sehen Sie, wie die dynamisch ausgewählten Daten zu einer sicheren E-Mail verarbeitet werden.\n\nDie Visualisierung dieser Abläufe beim Versenden einer E-Mail erfolgt in zwei Schritten (Control-Center & Animation):\n- In diesem Steuerfenster entscheiden Sie, ob Sie eine E-Mail verschlüsseln oder signieren wollen, und hier legen Sie die entsprechenden Steuer-Parameter fest.\n- Nach dem Drücken des Startknopfes werden diese Vorgänge in einer Animation visualisiert.\n\nSie können mit dem Steuerfenster auch mehrere parallel laufende Animationen erzeugen. Diese laufen unabhängig vom Steuerfenster.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Signieren oder Verschlüsseln") {
                Picker("", selection: $prm.sign) {
                    Text("Signieren").tag(true)
                    Text("Verschlüsseln").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Section("Text der Nachricht") {
                TextField("Absender:", text: $prm.from)
                TextField("Empfänger:", text: $prm.to)
                TextField("Betreff:", text: $prm.subject)
                TextField("Text", text: Binding(get: { prm.text }, set: { prm.text = String($0.prefix(50)) }),
                          prompt: Text("Hier den Text der E-Mail eingeben..."), axis: .vertical)
                    .lineLimit(2...3)
                HStack {
                    Text("Hinweis: In dieser Demo kann das Nachrichtenfeld maximal 50 Zeichen aufnehmen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Nachrichtentext aus Datei laden …", action: loadText)
                }
            }
            Section("Steuerungsparameter") {
                if prm.sign {
                    Picker("Hash-Funktion:", selection: $prm.hash) {
                        Text("SHA-1").tag(DigestAlgorithmID.sha1)
                        Text("MD5").tag(DigestAlgorithmID.md5)
                    }
                    LabeledContent("Signatur-Algorithmus:") {
                        Text("RSA").help("DSA (in CT1 zusätzlich wählbar) wird hier nicht angeboten.")
                    }
                    Picker("MIME-Typ:", selection: $prm.multipartSigned) {
                        Text("multipart/signed").tag(true)
                        Text("PKCS#7/signed-data").tag(false)
                    }
                } else {
                    Picker("Verschlüsselungsverfahren:", selection: $prm.aes) {
                        Text("AES").tag(true)
                        Text("Triple-DES").tag(false)
                    }
                }
                Picker("Transferkodierung:", selection: $prm.base64) {
                    Text("Base64").tag(true)
                    Text("quoted-printable").tag(false)
                }
            }
            Section(prm.sign ? "PSE des Senders auswählen" : "Zertifikat des Empfängers auswählen") {
                Text(prm.sign ? "Interne PSE (Alice, RSA 1024 Bit)" : "Internes Zertifikat (Bob, RSA 1024 Bit)")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    if keys.alice == nil {
                        ProgressView().controlSize(.small)
                        Text("Schlüssel werden erzeugt …").foregroundStyle(.secondary)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    Spacer()
                    Button(prm.sign ? "Signieren starten" : "Verschlüsselung starten", action: start)
                        .keyboardShortcut(.defaultAction)
                        .disabled(keys.alice == nil || prm.text.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { keys.prepare() }
    }

    private func loadText() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url, let d = try? Data(contentsOf: url) {
            prm.text = String(TextCoding.string(from: [UInt8](d)).prefix(50))
        }
    }

    private func start() {
        guard let a = keys.alice, let b = keys.bob else { return }
        do {
            let c = try SMIMEComputation(parameters: prm, alice: a, bob: b)
            error = nil
            let script = SMIMEAnimationScript.build(c)
            let title = prm.sign ? "S/MIME: Signieren von E-Mail" : "S/MIME: Verschlüsseln von E-Mail"
            WindowPresenter.tool(id: nil, title: title, size: CGSize(width: 1120, height: 800)) {
                SMIMEAnimationView(script: script)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SMIMEAnimationView: View {
    let script: AnimScript
    @StateObject private var player = StepPlayer(count: 1, baseInterval: 4)

    var body: some View {
        ScriptedAnimationView(script: script, player: player) { EmptyView() }
            .onAppear { player.reset(count: script.frames.count) }
    }
}
