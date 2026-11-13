import AppKit

/// Menu item whose title AppKit may not change: AppKit renames the items for `undo:`/`redo:` to
/// "Undo <action>"/"Redo <action>"; CT1 shows plain "Undo"/"Redo".
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

/// Builds the menu bar exactly following CT1's English menu (IDR_TEXTTYPE in CrypTool.rc).
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
        let main = NSMenu(title: "Main Menu")
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
            let i = NSMenuItem(title: "Recent Files", action: nil, keyEquivalent: "")
            let m = NSMenu(title: "Recent Files")
            m.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
            i.submenu = m
            return i
        }
    }

    /// AppKit inserts its own "Open Recent" menu and only fills that one.
    /// It is moved to the place of CT1's "Recent Files" and given CT1's title.
    static func adoptSystemRecentMenu() {
        guard let file = NSApp.mainMenu?.items.first(where: { $0.title == "File" })?.submenu,
              let ours = file.items.first(where: { $0.title == "Recent Files" }) else { return }
        let clear = #selector(NSDocumentController.clearRecentDocuments(_:))
        guard let system = file.items.first(where: { $0 !== ours && $0.submenu?.items.contains { $0.action == clear } == true })
        else { return }
        file.removeItem(system)
        guard let index = file.items.firstIndex(of: ours) else { return }
        file.removeItem(ours)
        system.title = "Recent Files"
        system.submenu?.title = "Recent Files"
        system.submenu?.items.first { $0.action == clear }?.title = "Clear Menu"
        file.insertItem(system, at: index)
    }

    private static func appMenu() -> NSMenu {
        let m = NSMenu(title: "CrypTool")
        m.addItem(withTitle: "About CrypTool", action: #selector(CTActionHandling.performCTAction(_:)), keyEquivalent: "")
            .representedObject = ActionBox(.about)
        m.addItem(.separator())
        let settings = m.addItem(withTitle: "Settings...", action: #selector(CTActionHandling.performCTAction(_:)), keyEquivalent: ",")
        settings.representedObject = ActionBox(.textOptions)
        m.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        m.addItem(services)
        m.addItem(.separator())
        m.addItem(withTitle: "Hide CrypTool", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = m.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        m.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "Quit CrypTool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
        .sub("Lattice-Based Attacks on RSA", [
            .item("Factoring with a Hint...", .factorHint),
            .item("Attack on Stereotyped Messages...", .stereotypedAttack),
            .item("Attack on Small Secret Keys...", .bloemerMay),
        ])
    }

    private static func menus() -> [(String, [Node])] {
        let file: [Node] = [
            .std("New", #selector(NSDocumentController.newDocument(_:)), key: "n"),
            .std("Open...", #selector(NSDocumentController.openDocument(_:)), key: "o"),
            .std("Close", #selector(NSWindow.performClose(_:)), key: "w"),
            .std("Save", #selector(NSDocument.save(_:)), key: "s"),
            .std("Save as...", #selector(NSDocument.saveAs(_:)), key: "s", mods: [.command, .shift]),
            .sep,
            .item("Document Properties...", .documentProperties, key: "d"),
            .std("Print...", #selector(NSDocument.printDocument(_:)), key: "p"),
            .std("Print Setup...", #selector(NSDocument.runPageLayout(_:)), key: "p", mods: [.command, .shift]),
            .sep,
            .recent,
            .sub("Example Files", [
                .item("Starting example (English)", .openExample("Startingexample-en.txt")),
                .item("Starting example (German)", .openExample("Startbeispiel-de.txt")),
                .item("CrypTool (English)", .openExample("CrypTool-en.txt")),
                .item("CrypTool (German)", .openExample("CrypTool-de.txt")),
                .item("Sample text (German)", .openExample("probetext-de.txt")),
                .item("Playfair encrypted (German)", .openExample("Playfair-enc-de.txt")),
                .item("Vernam", .openExample("vernam.txt")),
                .item("Original (signature attack)", .openExample("original.txt")),
                .item("Fake (signature attack)", .openExample("fake.txt")),
                .item("CrypTool.bmp", .openExample("CrypTool.bmp")),
                .sep,
                .item("psion-de-enc.hex", .openExample("psion-de-enc.hex")),
                .item("psion-en-enc.hex", .openExample("psion-en-enc.hex")),
                .item("state2.hex", .openExample("state2.hex")),
                .item("state2-enc.hex", .openExample("state2-enc.hex")),
            ]),
            .sep,
            .std("Exit", #selector(NSApplication.terminate(_:))),
        ]

        let edit: [Node] = [
            .std("Undo", Selector(("undo:")), key: "z"),
            .std("Redo", Selector(("redo:")), key: "y"),
            .sep,
            .std("Cut", #selector(NSText.cut(_:)), key: "x"),
            .std("Copy", #selector(NSText.copy(_:)), key: "c"),
            .std("Paste", #selector(NSText.paste(_:)), key: "v"),
            .std("Delete", #selector(NSText.delete(_:))),
            .sep,
            .item("Find/Replace...", .findReplace, key: "f"),
            .item("Find Next", .findNext, key: "g"),
            .sep,
            .std("Select All", #selector(NSText.selectAll(_:)), key: "a"),
            .sep,
            .item("Show Key...", .showKey, key: "k"),
            .item("Parent Window", .gotoParent, key: "u", mods: [.command, .option]),
        ]

        let view: [Node] = [
            .item("Toolbar", .toggleToolbar),
            .item("Status Bar", .toggleStatusBar),
            .sep,
            .item("Show as Text", .viewAsText, key: "1"),
            .item("Show as HexDump", .viewAsHex, key: "2"),
            .sep,
            .item("Bar Chart", .plotAsBars),
            .sep,
            .item("Alphabet", .viewAlphabet),
            .item("End of Line", .viewEndOfLine),
            .item("Line Wrap", .toggleLineWrap),
            .item("Whitespace", .viewWhitespace),
            .sub("Font", fontItems("Arial") + fontItems("Courier") + [
                .sep,
                .item("Increase Font Size", .fontLarger, key: "+"),
                .item("Decrease Font Size", .fontSmaller, key: "-"),
            ]),
            .item("Format Text Document...", .formatTextDocument),
            .sep,
            .item("Show Box (cube's borderlines)", .show3DBox),
        ]

        let crypt: [Node] = [
            .sub("Symmetric (classic)", [
                .item("Caesar / Rot-13...", .caesar),
                .item("Vigenère...", .vigenere),
                .item("Hill...", .hill),
                .item("Substitution / Atbash...", .substitution),
                .item("Playfair...", .playfair),
                .item("ADFGVX...", .adfgvx),
                .item("Byte Addition...", .byteAddition),
                .item("XOR...", .xor),
                .item("Vernam / OTP...", .vernam),
                .item("Homophone...", .homophone),
                .item("Permutation / Transposition...", .permutation),
                .item("Solitaire...", .solitaire),
                .item("Scytale / Rail Fence...", .scytaleRailFence),
            ]),
            .sub("Symmetric (modern)", [
                sym("IDEA...", "idea"),
                sym("RC2...", "rc2"),
                sym("RC4...", "rc4"),
                sym("DES (ECB)...", "desECB"),
                sym("DES (CBC)...", "desCBC"),
                sym("Triple DES (ECB)...", "tripleDESECB"),
                sym("Triple DES (CBC)...", "tripleDESCBC"),
                sym("AES (CBC)...", "aes", key: "r", mods: [.command, .shift]),
                .sep,
                .sub("Further Algorithms", [
                    sym("MARS...", "mars"),
                    sym("RC6...", "rc6"),
                    sym("Serpent...", "serpent"),
                    sym("Twofish...", "twofish"),
                    .sep,
                    sym("DESX...", "desx"),
                    sym("DESL...", "desl"),
                    sym("DESXL...", "desxl"),
                ]),
                .sep,
                .item("AES (self extracting)...", .aesSelfExtract),
            ]),
            .sub("Asymmetric", [
                .item("RSA Encryption...", .rsaEncrypt),
                .item("RSA Decryption...", .rsaDecrypt),
                .item("RSA Demonstration...", .rsaDemo),
            ]),
            .sub("Hybrid", [
                .item("RSA-AES Encryption...", .hybridRSAEncrypt),
                .item("RSA-AES Decryption...", .hybridRSADecrypt),
                .item("ECC-AES Encryption...", .hybridECCEncrypt),
                .item("ECC-AES Decryption...", .hybridECCDecrypt),
            ]),
        ]

        let pki: [Node] = [
            .sub("PKI", [
                .item("Generate/Import Keys...", .keyGeneration),
                .item("Display/Export Keys...", .keyList),
            ]),
            .item("Sign Document...", .signDocument),
            .item("Verify Signature...", .verifySignature),
            .item("Extract Signature", .extractSignature),
            .item("Signature Demonstration (Signature Generation)...", .signatureDemo),
        ]

        let indiv: [Node] = [
            .sub("Hash", [
                .item("MD2", .hash("md2")),
                .item("MD4", .hash("md4")),
                .item("MD5", .hash("md5")),
                .item("SHA", .hash("sha0")),
                .item("SHA-1", .hash("sha1")),
                .item("SHA-256", .hash("sha256")),
                .item("SHA-512", .hash("sha512")),
                .item("RIPEMD-160", .hash("ripemd160")),
                .sep,
                .item("Hash Value of a File...", .hashOfFile),
                .item("Hash Demonstration...", .hashDemo),
                .item("Key Generation from Password (PKCS #5)...", .pkcs5),
                .item("Generation of HMACs...", .hmac),
            ]),
            .sub("RSA Cryptosystem", [
                .item("Prime Number Test...", .primeTest),
                .item("Generate Prime Numbers...", .primeGeneration),
                .item("Factorization of a Number...", .factorization),
                .item("RSA Demonstration...", .rsaDemo),
                .item("Signature Demonstration (Signature Generation)...", .signatureDemo),
                latticeAttacks,
            ]),
            .sub("Protocols", [
                .item("Diffie-Hellman Demonstration...", .diffieHellman),
                .item("Network Authentication...", .challengeResponse),
                .item("Secure E-Mail with S/MIME...", .smime),
            ]),
            .sub("Chinese Remainder Theorem Applications", [
                .item("Astronomy and Planetary Motion...", .crtAstronomy),
                .item("Modular Forward and Backward Transformation...", .crtTransformation),
                .item("Secret Sharing by CRT...", .crtSecretSharing),
            ]),
            .sub("Visualization of Algorithms", [
                .item("Caesar...", .caesarAnimation),
                .item("Vigenère...", .vigenereAnimation),
                .item("Nihilist...", .nihilistAnimation),
                .item("DES...", .desAnimation),
                .sep,
                .sub("AES", [
                    .item("Rijndael Animation...", .rijndaelAnimation),
                    .item("Rijndael Inspector...", .aesInspector),
                    .item("Rijndael Flow Visualization...", .rijndaelFlow),
                ]),
                .item("Enigma...", .enigma),
                .sep,
                .item("Caesar Disk...", .caesarVisualization),
            ]),
            .item("Secret Sharing Demonstration (Shamir)...", .shamirSecretSharing),
            .sep,
            .sub("Tools", [
                .sub("Codes", [
                    .sub("Base64 Encode/Decode", [
                        .item("Base64 Encode", .base64Encode),
                        .item("Base64 Decode", .base64Decode),
                    ]),
                    .sub("UU Encode/Decode", [
                        .item("UU Encode", .uuEncode),
                        .item("UU Decode", .uuDecode),
                    ]),
                    .item("Decode ASN.1 Code of a Document", .asn1Decode),
                ]),
                .sep,
                .sub("Compress", [
                    .item("Zip", .zip, key: "z", mods: [.command, .shift, .option]),
                    .item("UnZip", .unzip, key: "u", mods: [.command, .shift, .option]),
                ]),
                .item("Generate Random Numbers...", .randomGenerator),
                .item("Password Quality Meter...", .passwordQuality),
                .item("Generate Passwords with Given Entropy...", .passwordEntropy),
                .item("Length of a Number...", .numberLength),
            ]),
            .sep,
            .sub("Educational Games", [
                .item("Number Shark", .numberShark),
            ]),
            .sep,
            .sub("Number Theory - Interactive", [
                .item("Learning Tool for Number Theory...", .numberTheoryLearning),
                .item("Point Addition on Elliptic Curves...", .ecPointAddition),
                .item("Compute Mersenne Numbers...", .mersenne),
                .item("Generic t-adic NAF Key Generator...", .tadicNAF),
            ]),
        ]

        let analysis: [Node] = [
            .sub("Tools for Analysis", [
                .item("Entropy", .entropy),
                .item("Floating Frequency", .floatingFrequency),
                .item("Histogram", .histogram),
                .item("N-Gram...", .ngram),
                .item("Autocorrelation", .autocorrelation),
                .item("Periodicity", .periodicity),
            ]),
            .sep,
            .sub("Symmetric Encryption (classic)", [
                .sub("Ciphertext-Only", [
                    .item("Caesar", .caesarAnalysis),
                    .item("Vigenère", .vigenereAnalysis),
                    .item("Vigenère (Analysis according to Schroedel)...", .vigenereSchroedel),
                    .item("ADFGVX...", .adfgvxAnalysis),
                    .item("Substitution...", .substitutionAnalysis),
                    .item("Solitaire...", .solitaireAnalysis),
                    .sep,
                    .item("Byte Addition", .byteAdditionAnalysis),
                    .item("XOR / Vernam", .xorAnalysis),
                ]),
                .sub("Known Plaintext", [
                    .item("Hill...", .hillAnalysis),
                    .item("Single Column Transposition...", .transpositionAnalysis),
                ]),
                .sub("Manual Analysis", [
                    .item("Substitution...", .manualSubstitution),
                    .item("Playfair...", .playfairAnalysis),
                    .item("Solitaire...", .solitaireAnalysis),
                ]),
            ]),
            .sub("Symmetric Encryption (modern)", [
                bf("IDEA...", "idea"),
                bf("RC2...", "rc2"),
                bf("RC4...", "rc4"),
                bf("DES (ECB)...", "desECB"),
                bf("DES (CBC)...", "desCBC"),
                bf("Triple DES (ECB)...", "tripleDESECB"),
                bf("Triple DES (CBC)...", "tripleDESCBC"),
                bf("AES (CBC)...", "aes"),
                .sub("Further Algorithms", [
                    bf("MARS...", "mars"),
                    bf("RC6...", "rc6"),
                    bf("Serpent...", "serpent"),
                    bf("Twofish...", "twofish"),
                    .sep,
                    bf("DESX...", "desx"),
                    bf("DESL...", "desl"),
                    bf("DESXL...", "desxl"),
                ]),
            ]),
            .sub("Asymmetric Encryption", [
                .item("Factorization of a Number...", .factorization),
                latticeAttacks,
                .item("Side-Channel Attack on \"Textbook RSA\"...", .sideChannelAttack),
            ]),
            .sub("Hash", [
                .item("Attack on the Hash Value of the Digital Signature...", .signatureAttack),
            ]),
            .sub("Analyze Randomness", [
                .item("Frequency Test...", .randomFrequencyTest),
                .item("Poker Test...", .randomPokerTest),
                .item("Runs Test...", .randomRunsTest),
                .item("Serial Test...", .randomSerialTest),
                .sep,
                .item("FIPS PUB-140-1 Test Battery", .randomFIPS),
                .sep,
                .item("Vitányi", .randomVitanyi),
                .item("3D Visualization...", .random3D),
            ]),
        ]

        let options: [Node] = [
            .item("Plot Options...", .plotOptions),
            .item("Analysis Options...", .analysisOptions),
            .item("Text Options...", .textOptions),
            .item("Starting Options...", .startOptions),
        ]

        let window: [Node] = [
            .item("Cascade", .windowCascade),
            .item("Tile", .windowTile),
            .item("Arrange Icons", .windowArrangeIcons),
            .item("Close All", .windowCloseAll),
            .sep,
            .std("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"),
            .std("Zoom", #selector(NSWindow.performZoom(_:))),
            .std("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ]

        let help: [Node] = [
            .item("Starting Page", .helpStart),
            .item("Index", .helpIndex),
            .item("Scenarios (Tutorials)", .helpScenarios),
            .item("Context Help", .contextHelp, key: String(Character(UnicodeScalar(NSF1FunctionKey)!)), mods: []),
            .sep,
            .item("Readme", .helpReadme),
            .item("CT Book", .helpBook),
            .item("Presentation", .helpPresentation),
            .item("CrypTool Website", .helpWebsite),
            .item("License", .helpLicense),
            .sep,
            .item("About CrypTool...", .about),
        ]

        return [
            ("File", file),
            ("Edit", edit),
            ("View", view),
            ("Encrypt/Decrypt", crypt),
            ("Digital Signatures/PKI", pki),
            ("Indiv. Procedures", indiv),
            ("Analysis", analysis),
            ("Options", options),
            ("Window", window),
            ("Help", help),
        ]
    }
}

extension NSMenu {
    static func make(title: String, items: [NSMenuItem]) -> NSMenu {
        let m = NSMenu(title: title)
        items.forEach { m.addItem($0) }
        if title == "Window" { NSApp.windowsMenu = m }
        if title == "Help" { NSApp.helpMenu = m }
        return m
    }
}
