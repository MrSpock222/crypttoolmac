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
        WindowPresenter.tool(id: "ct1-smime", title: "S/MIME Visualization Control Center", size: CGSize(width: 560, height: 760)) {
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
        guard st == kCCSuccess else { throw CTError("Encryption execution failed") }
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
        let sub = signing ? (p.multipartSigned ? "S/MIME: Signing E-Mail (using the multipart/signed format)"
                                               : "S/MIME: Signing E-Mail (using the signed-data format)")
                          : "S/MIME: Encrypting E-Mail"
        let verb = signing ? "digitally signed" : "encrypted"

        // Prolog
        b.chapter("Prologue")
        b.text("sub", sub, x: 20, y: 10, size: 19, bold: true)
        b.text("author", "designed by Michael Linden · original cartoon characters by Parker/Stone", x: 20, y: 36, size: 11, color: .secondary)
        say("Welcome to the S/MIME visualization. Use the buttons below for navigation or use the chapter menu to access chapters directly.",
            "Start by clicking on 'Continue'.")
        b.commit()
        b.text("alice", "👩", x: 24, y: 52, size: 38, z: 4)
        b.text("aliceL", "Alice", x: 72, y: 66, size: 15, bold: true)
        say("This is Alice. Alice is going to write an e-mail to her friend Bob. She uses an e-mail client with S/MIME capability.")
        b.commit()

        // E-Mail schreiben
        b.chapter("Compose E-Mail")
        b.box("scr", x: screenX, y: screenY, w: 560, h: 432, fill: .white, stroke: .gray, z: 0)
        b.box("scrBar", x: screenX, y: screenY, w: 560, h: 22, fill: .cellAlt, stroke: .gray, z: 0)
        b.text("scrT", "", x: screenX + 10, y: screenY + 3, size: 12, bold: true, z: 2)
        screen(["From:     \(p.from)", "To:       \(p.to)", "Subject:  \(p.subject)", ""] + p.text.components(separatedBy: "\n"),
               title: "Alice's e-mail client – New message")
        if signing {
            say("To ensure authenticity she makes use of the e-mail client's S/MIME features. One of these features enables her to attach a digital signature.",
                "Alice normally doesn’t see her signature when she has composed the message, so let's take a look behind the scenes.")
        } else {
            say("To ensure privacy she makes use of the e-mail client's S/MIME features. One of these features enables her to encrypt messages.",
                "Alice normally doesn’t see her encrypted text on screen when she has composed the message, so let's take a look behind the scenes.")
        }
        b.commit()
        screen(c.plainLines, title: "Source code of the e-mail")
        say("There's a lot more information packed in an e-mail than just the message itself. In order to reduce complexity, this information usually remains",
            "hidden to the user's eye. Now what you can see on Alice's display above is the source code of the e-mail that you entered in the Control Center.")
        b.commit()
        let headerSteps: [(String, [String])] = [
            ("Date:", ["The first line of the source code is the date, referenced by the keyword 'Date:'. It consists of the day, month, year and time the e-mail was written.",
                       "At the end of the line there's the offset in hours/minutes from a special time reference."]),
            ("From:", ["The second line denotes the originator of the e-mail. The user's e-mail address is followed by the keyword 'From:'. It is also possible to additionally use",
                       "a so called 'friendly name', giving the originator's real name. If that is the case, the e-mail address has to be enclosed in angle brackets (< >)."]),
            ("To:", ["The keyword 'To:' defines the recipient of the e-mail. Valid input to this field is either one or more e-mail addresses. Here it is Bob only."]),
            ("Subject:", ["The fourth line gives the subject of the e-mail, as defined by the keyword 'Subject:'."]),
            ("MIME-Version:", ["For detailed information about attachments, a more complex set of keywords is being used. 'MIME-Version:' references the version of the specifications",
                               "the e-mail body is built upon."]),
            ("Content-Type:", ["This line describes the property of the attached content (MIME-type) in detail. The information allows for correct processing and interpretation of",
                               "content on the receiving end. The underlying data format (text, audio, documents, etc.) is arbitrary."]),
        ]
        for (prefix, t) in headerSteps {
            highlight(prefix)
            if t.count == 2 { say(t[0], t[1]) } else { say(t[0]) }
            b.commit()
        }
        highlight("Date:", count: 6, color: .cellAlt)
        say("The sum of the above information is called the 'header' of the e-mail. In fact there are many more keywords possible in MIME, but the entire scope",
            "is not subject to this visualization.")
        b.commit()
        let bodyStart = c.plainLines.count - p.text.components(separatedBy: "\n").count
        highlight(c.plainLines[bodyStart].isEmpty ? nil : c.plainLines[bodyStart], count: p.text.components(separatedBy: "\n").count)
        say("Followed by the header is the 'body', holding information about the specified content-type(s). All sorts of attachments can be stored in this section.",
            "At this point there's only written text, because Alice did not attach any files to her message.")
        b.commit()
        if let i = c.plainLines.firstIndex(of: "") {
            let y = screenY + 27 + CGFloat(i) * lineH
            b.move("hl", x: screenX + 6, y: y); b.setSize("hl", w: 548, h: lineH + 1); b.setFill("hl", .highlight)
        }
        say("Header and Body are separated by one blank line.")
        b.commit()

        // Kanonisierung
        b.chapter("Canonicalize")
        b.remove("hl")
        screen(c.canonicalLines, title: "Source code of the e-mail – canonicalized")
        say("The next step is the canonicalization of the e-mail, a process in which the e-mail client automatically converts characters for consistent representation",
            "on other computer platforms or operating systems.")
        b.commit()
        highlight("Content-Type:")
        say("The procedure is dependent on the content-type: In this example the content type 'text/plain' comes in a character set called '\(c.charset)'.",
            "The ASCII (American Standard Code for Information Interchange) character-encoding scheme is the most commonly used character set on the internet.")
        b.commit()

        // Transfercodierung
        b.chapter("Transfer Encoding")
        b.remove("hl")
        say("The following step is referred to as 'transfer encoding' - a method which guarantees consistent data delivery over the internet. Due to the fact that",
            "there are 8-bit character sets, but some mail gateways on the internet support only 7-bit, conversion is mandatory for lossless transfer.")
        b.commit()
        screen(c.encodedLines, title: "Source code of the e-mail – transfer encoded")
        highlight("Content-Transfer-Encoding:")
        let cte = p.base64 ? "base64" : "quoted-printable"
        say("There are different Transfer Encoding types. These are specified by one additional keyword in the Header called 'Content-Transfer-Encoding'. The",
            "encoding used in the source code of Alice's e-mail is called '\(cte)'. In comparison to 'quoted-printable', 'base64' is not readable by the human eye.")
        b.commit()
        let encStart = c.encodedLines.count - (c.encodedLines.count - (c.encodedLines.firstIndex(of: "") ?? 0) - 1)
        if encStart < c.encodedLines.count {
            highlight(c.encodedLines[encStart], count: c.encodedLines.count - encStart)
        }
        if p.base64 {
            say("The encoding 'base64' translates 8-bit binary data into a string based on selected ASCII-characters. These characters are codepage independent",
                "and include: A–Z, a–z, 0–9, + and /. The character = defines the end of the string.")
        } else {
            say("The encoding 'quoted printable' translates non-ASCII-characters into a string of 3 ASCII characters, affecting the body of the e-mail.")
            b.commit()
            say("If entered, you can see converted umlauts in the example above, plus additional encoding for carriage return (<CR>) and line feed (<LF>). As the",
                "encoding is now all 7-bit ASCII, the possibility of a gateway messing up content (and therefore the signature) of Alice's e-mail is eliminated.")
            b.commit()
            say("The advantage of 'quoted-printable' is its readability. Even if Bob's e-mail client doesn't support the encoding, he is still able to read Alice's message",
                "without much inconvenience.")
        }
        b.commit()

        // S/MIME-Gateway
        b.chapter("S/MIME-Gateway")
        b.remove("hl")
        b.box("intranet", x: 598, y: 40, w: 394, h: 270, fill: .clear, stroke: .gray, z: -1)
        b.text("intranetL", "Corporate network (intranet)", x: 606, y: 290, size: 11, color: .secondary)
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
        say("Alice's corporate network features a site-to-site S/MIME solution. Thus her e-mail is not \(signing ? "digitally signed" : "encrpyted") on her own computer directly, but forwarded",
            "to a dedicated S/MIME gateway through the company’s intranet. This gateway \(signing ? "signs all e-mails coming from employees" : "encrypts all e-mails for the employees").")
        b.commit()
        envelope(at: 1); hl(node: 1)
        say("The routing of the network ensures that the e-mail is delivered to the Mail-Gateway.")
        b.commit()
        envelope(at: 2); hl(node: 2)
        say("From this node the e-mail is being delivered to the S/MIME-Gateway for further processing.")
        b.commit()
        let party = signing ? c.alice : c.bob
        let nBytes = party.key.publicKey.byteLength
        info(["Certificate from the PSE:",
              "  Owner:        CN=\(party.name), E=\(party.email)",
              "  Issuer:       CN=CrypTool Demo-CA",
              String(format: "  Serial no.:   %04X", party.serial),
              "  Key:          RSA \(party.key.bitLength) bits, e = \(party.key.e)",
              "  n = " + String(party.key.n.toString(radix: 16).lowercased().prefix(40)) + "…"])
        if signing {
            say("To apply Alice's signature, a special algorithm and a Personal Security Environment (PSE) are used. The PSE on this server contains all employee’s",
                "private keys and all certificates. In a first step the server looks for Alice's certificate in its database.")
        } else {
            say("For encryption a special algorithm and a Personal Security Environment (PSE) are used. A PSE is a set of certificates providing special",
                "keys. All correspondence's certificates are stored in the PSE. In a first step the server looks for Bob's certificate in its database.")
        }
        b.commit()
        say("The certificate has a set of special attributes and a unique ID for identification of its owner.")
        b.commit()

        // Signieren / Verschlüsseln
        b.chapter(signing ? "Signing" : "Encrypting")
        let hx = { (v: [UInt8], n: Int) -> String in v.prefix(n).map { String(format: "%02x", $0) }.joined() + (v.count > n ? "…" : "") }
        if signing {
            info(["\(p.hash.displayName)(MIME part) =", "  " + hx(c.digest, 24),
                  "Signature = RSA(Alice's private key, DigestInfo)", "  " + hx(c.signature, 20) + " (\(c.signature.count) bytes)"])
            say("In the next step the S/MIME Gateway calculates the digital signature with Alice's private key.")
        } else {
            info(["Session key (\(p.aes ? "AES-128" : "Triple-DES"), random) =", "  " + hx(c.sessionKey, 24),
                  "IV = " + hx(c.iv, 16),
                  "Body: \(p.aes ? "AES" : "3DES")-CBC → \(c.encryptedContent.count) bytes of ciphertext",
                  "Session key with Bob's public key (RSA):", "  " + hx(c.encryptedKey, 20) + " (\(nBytes) bytes)"])
            say("In the next step the S/MIME gateway encrypts Alice’s mail: This means it calculates the ciphertext from the mail body using Bob’s public key from",
                "his certificate. (More precisely: The body is encrypted symmetrically with a random session key,",
                "only this session key is encrypted with Bob's public RSA key – hybrid encryption.)")
        }
        b.commit()
        screen(c.finalLines, title: "Source code of the e-mail – \(verb)")
        say("As before here you see the source code of the e-mail which was processed by the S/MIME gateway.")
        b.commit()
        highlight("Content-Type:", count: 2)
        if signing && p.multipartSigned {
            say("Following information is added or replaced: The MIME-content-type now describes the structure of the signature being attached. It is no longer simply",
                "'text/plain'; the content has become 'multipart/signed'.")
            b.commit()
            say("'multipart/signed' means that the message body is split into several parts. The e-mail now consists of the original message plus Alice's digital signature.",
                "Both parts are separated by the string defined with the keyword ‘boundary’.")
            b.commit()
            if let s = c.finalLines.firstIndex(of: "--\(c.boundary)") {
                let e = c.finalLines[(s + 1)...].firstIndex(of: "--\(c.boundary)") ?? s + 1
                highlight(c.finalLines[s], count: min(e - s, maxLines - s))
                say("This is the message.")
                b.commit()
                highlight("Content-Type: application/pkcs7-signature", count: max(1, min(maxLines, c.finalLines.count) - e - 1))
                say("This is the message.... followed by the signature.")
                b.commit()
            }
            highlight("\tmicalg")
            say("A hash value was calculated to build Alice’s signature. In order to allow Bob’s computer to verify the signature, he has to know which hash method",
                "was used.")
            b.commit()
            say("The hash algorithm used in this example is called \(p.hash.displayName), having 'micalg' as its identifier. The hash value itself is stored in the signature part of the",
                "e-mail.")
            b.commit()
            highlight("Content-Transfer-Encoding: base64")
            say("Just like the message text, the signature must be converted into a 7-bit format, before it is passed through the internet. Specifications suggest",
                "'base64' as the default choice for Transfer Encoding.")
            b.commit()
            highlight("Content-Disposition:")
            say("The keyword 'Content-Disposition' specifies that the signature is a file attachment with the extension '.p7s'. That extension is commonly used",
                "for files holding cryptographic content. The underlying structure is defined in the Cryptographic Message Syntax Standard (aka PKCS#7).")
            b.commit()
        } else if signing {
            say("Following information is added or replaced: The MIME-content-type now describes a new object. It is no longer simply 'text/plain' but",
                "'application/pkcs7-mime' with the type 'signed-data', meaning the body holds cryptographic information.")
            b.commit()
            if let i = c.finalLines.firstIndex(of: "") {
                highlight(c.finalLines[min(i + 1, c.finalLines.count - 1)], count: min(maxLines, c.finalLines.count) - i - 1)
            }
            say("'signed-data' means that both the original message and the signature are stored in a single PKCS#7 object, which is base64 encoded.",
                "The hash value itself is stored in the signature part of the e-mail.")
            b.commit()
        } else {
            say("Following information is added or replaced: The MIME-content-type now describes a new object. It is no longer simply 'text/plain' but",
                "'application/pkcs7-mime', meaning the body holds cryptographic information.")
            b.commit()
            say("Specifically it's 'enveloped-data', meaning that the attached content is encrypted.")
            b.commit()
            if let i = c.finalLines.firstIndex(of: "") {
                highlight(c.finalLines[min(i + 1, c.finalLines.count - 1)], count: min(maxLines, c.finalLines.count) - i - 1)
            }
            say("This is the encrypted message.")
            b.commit()
            say("The encrypted content has also been converted into a special transfer encoding. This is necessary to ensure the integrity of the message while it is",
                "being transferred through different Mail-Gateways of the internet. For further reference take a look at the visualization of signing S/MIME e-mails.")
            b.commit()
        }
        if signing {
            say("The PKCS#7 syntax is used to digitally sign, digest, authenticate, or encrypt arbitrary message content. The scope of this specification is huge, so it is not",
                "discussed any further at this point.")
            b.commit()
            info(["PKCS#7/CMS SignedData (\(c.cms.count) bytes):", "  contentType  signedData", "  digestAlg    \(p.hash.displayName)",
                  "  signerInfo   CN=CrypTool Demo-CA, no. \(String(format: "%04X", c.alice.serial))", "  signature    \(c.signature.count) bytes RSA"])
            say("This PKCS#7 object contains the signature with all necessary data required for its verification.")
            b.commit()
        }

        // Versand
        b.chapter("Transport")
        b.remove("hl")
        info([])
        envelope(at: 3); hl(node: 3)
        say("After the e-mail has been \(verb), the S/MIME-Gateway passes the message to the company's Mail-Gateway.")
        b.commit()
        envelope(at: 4); hl(node: 4)
        say("The e-mail then leaves the secure boundaries of the corporate network and is sent through the internet to Bob. Due to the \(signing ? "signing" : "encryption")",
            signing ? "by means of the S/MIME format the mail is protected against unnoticed modifications on its entire way through the internet." : "by means of the S/MIME format the mail is secure on its entire way through the internet.")
        b.commit()

        // Empfang
        b.chapter("Reception")
        envelope(at: 5); hl(node: 5)
        if signing {
            info(["Bob's e-mail client verifies the signature:", "  calculate \(p.hash.displayName) of the received MIME part,",
                  "  verify signature with Alice's public key:", c.verified ? "  ✓ Signature valid" : "  ✗ Signature invalid"])
            say("Bob fetches his e-mail which is instantly checked for authenticity. The certificate is valid, and he is confident that Alice is the true originator.")
        } else {
            info(["Bob's e-mail client decrypts:", "  the session key with Bob's private key,", "  then the body (\(p.aes ? "AES" : "3DES")-CBC):",
                  "  " + String(p.text.prefix(44))])
            say("Bob fetches his e-mail which is instantly decrypted by his e-mail client by using his private key. He is now able to read Alice's original message",
                "in plain text.")
        }
        b.commit()
        say("End of visualization. Close the window or use the navigation buttons to jump back.")
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
                Text("S/MIME Visualization Control Center").font(.title3.bold())
                DisclosureGroup("Description") {
                    Text("In this window you can dynamically configure parameters for secure email messaging.\n\nThe visualization is then done in two steps (control center and animation):\n- In the contol center you can choose whether to encrypt or sign an email and then select the appropriate parameters.\n- After clicking the start button the chosen procedure will be visualized with an animation.\n\nYou can open more than one animation simultaneously with different parameters from the control center.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Sign or encrypt") {
                Picker("", selection: $prm.sign) {
                    Text("Signing").tag(true)
                    Text("Encrypting").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Section("Text of the message") {
                TextField("Sender:", text: $prm.from)
                TextField("Receiver:", text: $prm.to)
                TextField("Subject:", text: $prm.subject)
                TextField("Text", text: Binding(get: { prm.text }, set: { prm.text = String($0.prefix(50)) }),
                          prompt: Text("Enter the email text here..."), axis: .vertical)
                    .lineLimit(2...3)
                HStack {
                    Text("Note: In this demonstration, the text field can only handle 50 characters.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Load message text from file …", action: loadText)
                }
            }
            Section("Control parameters") {
                if prm.sign {
                    Picker("Hash function:", selection: $prm.hash) {
                        Text("SHA-1").tag(DigestAlgorithmID.sha1)
                        Text("MD5").tag(DigestAlgorithmID.md5)
                    }
                    LabeledContent("Signature algorithm:") {
                        Text("RSA").help("DSA (additionally selectable in CT1) is not offered here.")
                    }
                    Picker("MIME type:", selection: $prm.multipartSigned) {
                        Text("multipart/signed").tag(true)
                        Text("PKCS#7/signed-data").tag(false)
                    }
                } else {
                    Picker("Encryption algorithm :", selection: $prm.aes) {
                        Text("AES").tag(true)
                        Text("Triple-DES").tag(false)
                    }
                }
                Picker("transfer encoding:", selection: $prm.base64) {
                    Text("Base64").tag(true)
                    Text("quoted-printable").tag(false)
                }
            }
            Section(prm.sign ? "Choose sender's PSE" : "Choose receiver's certificate") {
                Text(prm.sign ? "Internal PSE (Alice, RSA 1024 bits)" : "Internal certificate (Bob, RSA 1024 bits)")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    if keys.alice == nil {
                        ProgressView().controlSize(.small)
                        Text("Generating keys …").foregroundStyle(.secondary)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    Spacer()
                    Button(prm.sign ? "Start signing" : "Start encrypting", action: start)
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
            let title = prm.sign ? "S/MIME: Signing E-Mail" : "S/MIME: Encrypting E-Mail"
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
