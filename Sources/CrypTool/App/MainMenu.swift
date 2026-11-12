import AppKit

/// Menu item whose title AppKit may not change: AppKit renames the items for `undo:`/`redo:` to
/// "Widerrufen …"/"Wiederholen …"; CT1 shows "Rückgängig"/"Wiederherstellen".
final class FixedTitleMenuItem: NSMenuItem {
    private var locked = false

    override init(title: String, action selector: Selector?, keyEquivalent charCode: String) {
        super.init(title: title, action: selector, keyEquivalent: charCode)
        locked = true
    }

    required init(coder: NSCoder) { super.init(coder: coder) }

    override var title: String {
        get { super.title }
        set { if !locked { super.title = newValue } }
    }

    static func isUndoRedo(_ sel: Selector?) -> Bool {
        sel == Selector(("undo:")) || sel == Selector(("redo:"))
    }
}

/// Builds the menu bar exactly following CT1's German menu (IDR_TEXTTYPE in CrypTool.rc).
/// Only the macOS application menu ("CrypTool") is added in front.
@MainActor
enum MainMenu {
    private indirect enum Node {
        case item(String, CTAction, key: String = "", mods: NSEvent.ModifierFlags = [.command])
        case std(String, Selector, key: String = "", mods: NSEvent.ModifierFlags = [.command], tag: Int = 0)
        case sub(String, [Node])
        case recent
        case sep
    }

    static func build() -> NSMenu {
        let main = NSMenu(title: "Hauptmenü")
        main.addItem(submenu(appMenu()))
        for (title, nodes) in menus() {
            main.addItem(submenu(NSMenu.make(title: title, items: nodes.map(makeItem))))
        }
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func makeItem(_ node: Node) -> NSMenuItem {
        switch node {
        case .sep:
            return .separator()
        case let .item(title, action, key, mods):
            let i = NSMenuItem(title: title, action: #selector(CTActionHandling.performCTAction(_:)), keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.representedObject = ActionBox(action)
            return i
        case let .std(title, sel, key, mods, tag):
            let i = FixedTitleMenuItem.isUndoRedo(sel)
                ? FixedTitleMenuItem(title: title, action: sel, keyEquivalent: key)
                : NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.tag = tag
            return i
        case let .sub(title, children):
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            i.submenu = NSMenu.make(title: title, items: children.map(makeItem))
            return i
        case .recent:
            // NSDocumentController fills a submenu that contains "clearRecentDocuments:".
            let i = NSMenuItem(title: "Zuletzt geöffnete Dateien", action: nil, keyEquivalent: "")
            let m = NSMenu(title: "Zuletzt geöffnete Dateien")
            m.addItem(withTitle: "Liste leeren", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
            i.submenu = m
            return i
        }
    }

    /// AppKit inserts its own "Open Recent" menu ("Benutzte Dokumente") and only fills that one.
    /// It is moved to the place of CT1's "Zuletzt geöffnete Dateien" and given CT1's titles.
    static func adoptSystemRecentMenu() {
        guard let file = NSApp.mainMenu?.items.first(where: { $0.title == "Datei" })?.submenu,
              let ours = file.items.first(where: { $0.title == "Zuletzt geöffnete Dateien" }) else { return }
        let clear = #selector(NSDocumentController.clearRecentDocuments(_:))
        guard let system = file.items.first(where: { $0 !== ours && $0.submenu?.items.contains { $0.action == clear } == true })
        else { return }
        file.removeItem(system)
        guard let index = file.items.firstIndex(of: ours) else { return }
        file.removeItem(ours)
        system.title = "Zuletzt geöffnete Dateien"
        system.submenu?.title = "Zuletzt geöffnete Dateien"
        system.submenu?.items.first { $0.action == clear }?.title = "Liste leeren"
        file.insertItem(system, at: index)
    }

    private static func appMenu() -> NSMenu {
        let m = NSMenu(title: "CrypTool")
        m.addItem(withTitle: "Über CrypTool", action: #selector(CTActionHandling.performCTAction(_:)), keyEquivalent: "")
            .representedObject = ActionBox(.about)
        m.addItem(.separator())
        let settings = m.addItem(withTitle: "Einstellungen …", action: #selector(CTActionHandling.performCTAction(_:)), keyEquivalent: ",")
        settings.representedObject = ActionBox(.textOptions)
        m.addItem(.separator())
        let services = NSMenuItem(title: "Dienste", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Dienste")
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        m.addItem(services)
        m.addItem(.separator())
        m.addItem(withTitle: "CrypTool ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = m.addItem(withTitle: "Andere ausblenden", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        m.addItem(withTitle: "Alle einblenden", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "CrypTool beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return m
    }

    private static func sym(_ title: String, _ raw: String, key: String = "", mods: NSEvent.ModifierFlags = [.command]) -> Node {
        .item(title, .symmetric(raw), key: key, mods: mods)
    }

    private static func bf(_ title: String, _ raw: String) -> Node { .item(title, .bruteForce(raw)) }

    private static func fontItems(_ family: String) -> [Node] {
        [8, 10, 12, 14, 16, 18, 20].map { .item("\(family) \($0)", .font(family, $0)) }
    }

    private static var latticeAttacks: Node {
        .sub("Gitterbasierte Angriffe auf RSA", [
            .item("Faktorisieren mit teilweise bekanntem p …", .factorHint),
            .item("Angriff auf stereotype Nachrichten …", .stereotypedAttack),
            .item("Angriff auf kleine geheime Schlüssel …", .bloemerMay),
        ])
    }

    private static func menus() -> [(String, [Node])] {
        let file: [Node] = [
            .std("Neu", #selector(NSDocumentController.newDocument(_:)), key: "n"),
            .std("Öffnen …", #selector(NSDocumentController.openDocument(_:)), key: "o"),
            .std("Schließen", #selector(NSWindow.performClose(_:)), key: "w"),
            .std("Speichern", #selector(NSDocument.save(_:)), key: "s"),
            .std("Speichern als …", #selector(NSDocument.saveAs(_:)), key: "s", mods: [.command, .shift]),
            .sep,
            .item("Dokument-Eigenschaften …", .documentProperties, key: "d"),
            .std("Drucken …", #selector(NSDocument.printDocument(_:)), key: "p"),
            .std("Drucker einstellen …", #selector(NSDocument.runPageLayout(_:)), key: "p", mods: [.command, .shift]),
            .sep,
            .recent,
            .sub("Beispieldateien", [
                .item("Startbeispiel (deutsch)", .openExample("Startbeispiel-de.txt")),
                .item("Starting example (English)", .openExample("Startingexample-en.txt")),
                .item("CrypTool (deutsch)", .openExample("CrypTool-de.txt")),
                .item("CrypTool (English)", .openExample("CrypTool-en.txt")),
                .item("Probetext (deutsch)", .openExample("probetext-de.txt")),
                .item("Playfair-verschlüsselt (deutsch)", .openExample("Playfair-enc-de.txt")),
                .item("Vernam", .openExample("vernam.txt")),
                .item("Original (Signaturangriff)", .openExample("Original.txt")),
                .item("Fälschung (Signaturangriff)", .openExample("Faelschung.txt")),
                .item("CrypTool.bmp", .openExample("CrypTool.bmp")),
                .sep,
                .item("psion-de-enc.hex", .openExample("psion-de-enc.hex")),
                .item("psion-en-enc.hex", .openExample("psion-en-enc.hex")),
                .item("state2.hex", .openExample("state2.hex")),
                .item("state2-enc.hex", .openExample("state2-enc.hex")),
            ]),
            .sep,
            .std("Beenden", #selector(NSApplication.terminate(_:))),
        ]

        let edit: [Node] = [
            .std("Rückgängig", Selector(("undo:")), key: "z"),
            .std("Wiederherstellen", Selector(("redo:")), key: "y"),
            .sep,
            .std("Ausschneiden", #selector(NSText.cut(_:)), key: "x"),
            .std("Kopieren", #selector(NSText.copy(_:)), key: "c"),
            .std("Einfügen", #selector(NSText.paste(_:)), key: "v"),
            .std("Löschen", #selector(NSText.delete(_:))),
            .sep,
            .item("Suchen/Ersetzen …", .findReplace, key: "f"),
            .item("Suche nächstes", .findNext, key: "g"),
            .sep,
            .std("Alles markieren", #selector(NSText.selectAll(_:)), key: "a"),
            .sep,
            .item("Schlüssel anzeigen …", .showKey, key: "k"),
            .item("Übergeordnetes Fenster", .gotoParent, key: "u", mods: [.command, .option]),
        ]

        let view: [Node] = [
            .item("Symbolleiste", .toggleToolbar),
            .item("Statusleiste", .toggleStatusBar),
            .sep,
            .item("Als Text anzeigen", .viewAsText, key: "1"),
            .item("Als HexDump anzeigen", .viewAsHex, key: "2"),
            .sep,
            .item("Balkendiagramm", .plotAsBars),
            .sep,
            .item("Alphabet", .viewAlphabet),
            .item("Zeilenende", .viewEndOfLine),
            .item("Zeilenumbruch", .toggleLineWrap),
            .item("Leerzeichen", .viewWhitespace),
            .sub("Schriftart", fontItems("Arial") + fontItems("Courier") + [
                .sep,
                .item("Schrift vergrößern", .fontLarger, key: "+"),
                .item("Schrift verkleinern", .fontSmaller, key: "-"),
            ]),
            .item("Textdokument formatieren …", .formatTextDocument),
            .sep,
            .item("Box (Würfelkanten zeigen)", .show3DBox),
        ]

        let crypt: [Node] = [
            .sub("Symmetrisch (klassisch)", [
                .item("Caesar / Rot-13 …", .caesar),
                .item("Vigenère …", .vigenere),
                .item("Hill …", .hill),
                .item("Substitution / Atbash …", .substitution),
                .item("Playfair …", .playfair),
                .item("ADFGVX …", .adfgvx),
                .item("Byteweise Addition …", .byteAddition),
                .item("XOR …", .xor),
                .item("Vernam / OTP …", .vernam),
                .item("Homophone …", .homophone),
                .item("Permutation / Transposition …", .permutation),
                .item("Solitaire …", .solitaire),
                .item("Skytale / Gartenzaun …", .scytaleRailFence),
            ]),
            .sub("Symmetrisch (modern)", [
                sym("IDEA …", "idea"),
                sym("RC2 …", "rc2"),
                sym("RC4 …", "rc4"),
                sym("DES (ECB) …", "desECB"),
                sym("DES (CBC) …", "desCBC"),
                sym("Triple DES (ECB) …", "tripleDESECB"),
                sym("Triple DES (CBC) …", "tripleDESCBC"),
                sym("AES (CBC) …", "aes", key: "r", mods: [.command, .shift]),
                .sep,
                .sub("Weitere Algorithmen", [
                    sym("MARS …", "mars"),
                    sym("RC6 …", "rc6"),
                    sym("Serpent …", "serpent"),
                    sym("Twofish …", "twofish"),
                    .sep,
                    sym("DESX …", "desx"),
                    sym("DESL …", "desl"),
                    sym("DESXL …", "desxl"),
                ]),
                .sep,
                .item("AES (selbstextrahierend) …", .aesSelfExtract),
            ]),
            .sub("Asymmetrisch", [
                .item("RSA-Verschlüsselung …", .rsaEncrypt),
                .item("RSA-Entschlüsselung …", .rsaDecrypt),
                .item("RSA-Demo …", .rsaDemo),
            ]),
            .sub("Hybrid", [
                .item("RSA-AES-Verschlüsselung …", .hybridRSAEncrypt),
                .item("RSA-AES-Entschlüsselung …", .hybridRSADecrypt),
                .item("ECC-AES-Verschlüsselung …", .hybridECCEncrypt),
                .item("ECC-AES-Entschlüsselung …", .hybridECCDecrypt),
            ]),
        ]

        let pki: [Node] = [
            .sub("PKI", [
                .item("Schlüssel erzeugen/importieren …", .keyGeneration),
                .item("Schlüssel anzeigen/exportieren …", .keyList),
            ]),
            .item("Dokument signieren …", .signDocument),
            .item("Signatur überprüfen …", .verifySignature),
            .item("Signatur extrahieren", .extractSignature),
            .item("Signaturdemo (Signaturerzeugung) …", .signatureDemo),
        ]

        let indiv: [Node] = [
            .sub("Hashverfahren", [
                .item("MD2", .hash("md2")),
                .item("MD4", .hash("md4")),
                .item("MD5", .hash("md5")),
                .item("SHA", .hash("sha0")),
                .item("SHA-1", .hash("sha1")),
                .item("SHA-256", .hash("sha256")),
                .item("SHA-512", .hash("sha512")),
                .item("RIPEMD-160", .hash("ripemd160")),
                .sep,
                .item("Hashwert einer Datei …", .hashOfFile),
                .item("Hash-Demo …", .hashDemo),
                .item("Schlüssel aus Passwort generieren (PKCS #5) …", .pkcs5),
                .item("Generieren von HMACs …", .hmac),
            ]),
            .sub("RSA-Kryptosystem", [
                .item("Primzahltest …", .primeTest),
                .item("Primzahlen generieren …", .primeGeneration),
                .item("Faktorisieren einer Zahl …", .factorization),
                .item("RSA-Demo …", .rsaDemo),
                .item("Signaturdemo (Signaturerzeugung) …", .signatureDemo),
                latticeAttacks,
            ]),
            .sub("Protokolle", [
                .item("Diffie-Hellman-Demo …", .diffieHellman),
                .item("Authentisierungsverfahren im Netz …", .challengeResponse),
                .item("Sichere E-Mail mit S/MIME …", .smime),
            ]),
            .sub("Anwendungen des Chinesischen Restsatzes", [
                .item("Astronomie und Planetenbewegung …", .crtAstronomy),
                .item("Modulare Hin- und Rücktransformation …", .crtTransformation),
                .item("Secret-Sharing mittels CRT …", .crtSecretSharing),
            ]),
            .sub("Visualisierung von Algorithmen", [
                .item("Caesar …", .caesarAnimation),
                .item("Vigenère …", .vigenereAnimation),
                .item("Nihilist …", .nihilistAnimation),
                .item("DES …", .desAnimation),
                .sep,
                .sub("AES", [
                    .item("Rijndael-Animation …", .rijndaelAnimation),
                    .item("Rijndael-Inspektor …", .aesInspector),
                    .item("Rijndael-Flussvisualisierung …", .rijndaelFlow),
                ]),
                .item("Enigma …", .enigma),
                .sep,
                .item("Caesar-Scheibe …", .caesarVisualization),
            ]),
            .item("Secret-Sharing-Demo (nach Shamir) …", .shamirSecretSharing),
            .sep,
            .sub("Tools", [
                .sub("Codierungen", [
                    .sub("Base64-Codierung/Decodierung", [
                        .item("Base64 codieren", .base64Encode),
                        .item("Base64 decodieren", .base64Decode),
                    ]),
                    .sub("UU-Codierung/Decodierung", [
                        .item("UU codieren", .uuEncode),
                        .item("UU decodieren", .uuDecode),
                    ]),
                    .item("ASN.1-Decodieren eines Dokuments", .asn1Decode),
                ]),
                .sep,
                .sub("Komprimieren", [
                    .item("Zip", .zip, key: "z", mods: [.command, .shift, .option]),
                    .item("UnZip", .unzip, key: "u", mods: [.command, .shift, .option]),
                ]),
                .item("Zufallsdaten erzeugen …", .randomGenerator),
                .item("Passwort-Qualitätsmesser …", .passwordQuality),
                .item("Passwörter mit bestimmter Entropie erzeugen …", .passwordEntropy),
                .item("Länge einer Zahl …", .numberLength),
            ]),
            .sep,
            .sub("Lernspiele", [
                .item("Der Zahlenhai", .numberShark),
            ]),
            .sep,
            .sub("Zahlentheorie interaktiv", [
                .item("Lernprogramm für Zahlentheorie …", .numberTheoryLearning),
                .item("Punktaddition auf Elliptischen Kurven …", .ecPointAddition),
                .item("Mersenne-Zahlen berechnen …", .mersenne),
                .item("Generischer t-adic-NAF-Schlüsselgenerator …", .tadicNAF),
            ]),
        ]

        let analysis: [Node] = [
            .sub("Werkzeuge zur Analyse", [
                .item("Entropie", .entropy),
                .item("Gleitende Häufigkeit", .floatingFrequency),
                .item("Histogramm", .histogram),
                .item("N-Gramm …", .ngram),
                .item("Autokorrelation", .autocorrelation),
                .item("Periode", .periodicity),
            ]),
            .sep,
            .sub("Symmetrische Verschlüsselung (klassisch)", [
                .sub("Ciphertext-Only", [
                    .item("Caesar", .caesarAnalysis),
                    .item("Vigenère", .vigenereAnalysis),
                    .item("Vigenère (Analyse nach Schrödel) …", .vigenereSchroedel),
                    .item("ADFGVX …", .adfgvxAnalysis),
                    .item("Substitution …", .substitutionAnalysis),
                    .item("Solitaire …", .solitaireAnalysis),
                    .sep,
                    .item("Byteweise Addition", .byteAdditionAnalysis),
                    .item("XOR / Vernam", .xorAnalysis),
                ]),
                .sub("Known Plaintext", [
                    .item("Hill …", .hillAnalysis),
                    .item("Einstufige Spaltentransposition …", .transpositionAnalysis),
                ]),
                .sub("Manuelle Analyse", [
                    .item("Substitution …", .manualSubstitution),
                    .item("Playfair …", .playfairAnalysis),
                    .item("Solitaire …", .solitaireAnalysis),
                ]),
            ]),
            .sub("Symmetrische Verschlüsselung (modern)", [
                bf("IDEA …", "idea"),
                bf("RC2 …", "rc2"),
                bf("RC4 …", "rc4"),
                bf("DES (ECB) …", "desECB"),
                bf("DES (CBC) …", "desCBC"),
                bf("Triple DES (ECB) …", "tripleDESECB"),
                bf("Triple DES (CBC) …", "tripleDESCBC"),
                bf("AES (CBC) …", "aes"),
                .sub("Weitere Algorithmen", [
                    bf("MARS …", "mars"),
                    bf("RC6 …", "rc6"),
                    bf("Serpent …", "serpent"),
                    bf("Twofish …", "twofish"),
                    .sep,
                    bf("DESX …", "desx"),
                    bf("DESL …", "desl"),
                    bf("DESXL …", "desxl"),
                ]),
            ]),
            .sub("Asymmetrische Verfahren", [
                .item("Faktorisieren einer Zahl …", .factorization),
                latticeAttacks,
                .item("Seitenkanalangriff auf \"Textbook-RSA\" …", .sideChannelAttack),
            ]),
            .sub("Hashverfahren", [
                .item("Angriff auf den Hashwert der digitalen Signatur …", .signatureAttack),
            ]),
            .sub("Zufallsanalyse", [
                .item("Frequency-Test …", .randomFrequencyTest),
                .item("Poker-Test …", .randomPokerTest),
                .item("Runs-Test …", .randomRunsTest),
                .item("Serial-Test …", .randomSerialTest),
                .sep,
                .item("FIPS PUB-140-1 Testbatterie", .randomFIPS),
                .sep,
                .item("Vitányi", .randomVitanyi),
                .item("3D-Visualisierung …", .random3D),
            ]),
        ]

        let options: [Node] = [
            .item("Grafikoptionen …", .plotOptions),
            .item("Analyseoptionen …", .analysisOptions),
            .item("Textoptionen …", .textOptions),
            .item("Startoptionen …", .startOptions),
        ]

        let window: [Node] = [
            .item("Überlappend anordnen", .windowCascade),
            .item("Nichtüberlappend anordnen", .windowTile),
            .item("Symbole anordnen", .windowArrangeIcons),
            .item("Alle schließen", .windowCloseAll),
            .sep,
            .std("Im Dock ablegen", #selector(NSWindow.performMiniaturize(_:)), key: "m"),
            .std("Zoomen", #selector(NSWindow.performZoom(_:))),
            .std("Alle nach vorne bringen", #selector(NSApplication.arrangeInFront(_:))),
        ]

        let help: [Node] = [
            .item("Startseite", .helpStart),
            .item("Index", .helpIndex),
            .item("Szenarien (Tutorials)", .helpScenarios),
            .item("Kontexthilfe", .contextHelp, key: String(Character(UnicodeScalar(NSF1FunctionKey)!)), mods: []),
            .sep,
            .item("Readme", .helpReadme),
            .item("CT-Buch", .helpBook),
            .item("Präsentation", .helpPresentation),
            .item("CrypTool-Webseite", .helpWebsite),
            .item("Lizenz", .helpLicense),
            .sep,
            .item("Über CrypTool …", .about),
        ]

        return [
            ("Datei", file),
            ("Bearbeiten", edit),
            ("Ansicht", view),
            ("Ver-/Entschlüsseln", crypt),
            ("Digitale Signaturen/PKI", pki),
            ("Einzelverfahren", indiv),
            ("Analyse", analysis),
            ("Optionen", options),
            ("Fenster", window),
            ("Hilfe", help),
        ]
    }
}

extension NSMenu {
    static func make(title: String, items: [NSMenuItem]) -> NSMenu {
        let m = NSMenu(title: title)
        items.forEach { m.addItem($0) }
        if title == "Fenster" { NSApp.windowsMenu = m }
        if title == "Hilfe" { NSApp.helpMenu = m }
        return m
    }
}
