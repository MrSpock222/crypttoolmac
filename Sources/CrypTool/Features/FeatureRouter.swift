import AppKit
import SwiftUI
import CTCommon
import CTModern
import CTAnalysis

/// Routes crypto/analysis commands to their feature implementations.
@MainActor
enum FeatureRouter {
    /// Commands of CT1 that are not available in the macOS version (shown greyed out, as CT1 does
    /// for features whose libraries are missing).
    static let unavailable: Set<CTAction> = []

    /// CT1 functions that are not part of the macOS version. The menu items stay active so that
    /// tutorials can be followed: they explain this and show the CT1 help page of the function.
    static let notIncluded: Set<CTAction> = []

    static func isAvailable(_ action: CTAction) -> Bool { !unavailable.contains(action) }

    static func perform(_ action: CTAction, document doc: CTDocument?, window: NSWindow?) {
        guard isAvailable(action) else { NSSound.beep(); return }
        if notIncluded.contains(action) {
            Alerts.info("This function of CrypTool 1 is not included in the macOS version.\n\nThe description from the CT1 online help will be displayed now.",
                        title: "Not included")
            HelpCenter.show(action: action)
            return
        }
        // Commands that work without a document
        switch action {
        case .aesSelfExtract:
            CT1Tools.openAESTool(document: doc)
            return
        case .tadicNAF:
            CT1Tools.openTadicNAF()
            return
        case .numberTheoryLearning:
            CT1NumberTheoryLearning.open()
            return
        case .signatureAttack:
            SignatureAttackWindows.openAttack()
            return
        case .factorHint:
            LatticeAttacks.openFactorHint()
            return
        case .stereotypedAttack:
            LatticeAttacks.openStereotyped()
            return
        case .bloemerMay:
            LatticeAttacks.openSmallSecretKey()
            return
        case .sideChannelAttack:
            LatticeAttacks.openSideChannel()
            return
        case .challengeResponse: CT1Visualizations.openChallengeResponse(); return
        case .smime: CT1Visualizations.openSMIME(); return
        case .caesarAnimation: CT1Visualizations.openCaesarAnimation(); return
        case .vigenereAnimation: CT1Visualizations.openVigenereAnimation(); return
        case .nihilistAnimation: CT1Visualizations.openNihilistAnimation(); return
        case .desAnimation: CT1Visualizations.openDESAnimation(); return
        case .rijndaelAnimation: CT1Visualizations.openRijndaelAnimation(); return
        case .rijndaelFlow: CT1Visualizations.openRijndaelFlow(); return
        case .rsaDemo:
            tool("rsademo", "RSA Demonstration", 720, 820) { RSADemoView(initialText: doc?.text ?? "") }
            return
        case .keyGeneration:
            tool("keygen", "Generation of an Asymmetric Key Pair", 760, 640) { KeyGenerationView() }
            return
        case .keyList:
            tool("keylist", "Available Asymmetric Key Pairs", 860, 560) { KeyListView() }
            return
        case .signatureDemo:
            tool("sigdemo", "Step by Step Signature Generation", 760, 820) { SignatureDemoView(document: doc) }
            return
        case .hashOfFile:
            tool(nil, "Hash of a file", 760, 360) { FileHashView() }
            return
        case .hashDemo:
            tool("hashdemo", "Hash Demonstration", 720, 820) { HashDemoView(document: doc) }
            return
        case .pkcs5:
            tool("pkcs5", "Key Generation from Password According to PKCS #5", 600, 480) { PKCS5View() }
            return
        case .hmac:
            tool("hmac", "Keyed-Hash Message Authentication Code (HMAC)", 800, 880) { HMACView(initialMessage: String((doc?.text ?? "").prefix(100_000)), sourceTitle: doc?.shortName) }
            return
        case .primeTest:
            tool("primetest", "Prime Number Test", 560, 480) { PrimeTestView() }
            return
        case .primeGeneration:
            tool("primegen", "Prime Number Generation", 640, 480) { PrimeGenerationView() }
            return
        case .factorization:
            tool("factor", "Factorization of a Number", 640, 700) { FactorizationView() }
            return
        case .diffieHellman:
            tool("dh", "Diffie-Hellman Demonstration - Visualization of the Diffie-Hellman Key Exchange Protocol", 1080, 660) { DiffieHellmanView() }
            return
        case .crtAstronomy:
            tool("crtastro", "Planetary Motion and the Chinese Remainder Theorem", 640, 460) { CRTAstronomyView() }
            return
        case .crtTransformation:
            tool("crttrans", "Visualization of the Transformation from Number Notation into the Modular Representation with the CRT", 620, 600) { CRTTransformationView() }
            return
        case .crtSecretSharing:
            tool("crtss", "Secret Sharing by CRT", 640, 640) { CRTSecretSharingView() }
            return
        case .shamirSecretSharing:
            tool("shamir", "Secret Sharing Demonstration: Initializing the Threshold Scheme", 680, 680) { ShamirView() }
            return
        case .enigma:
            CT1Games.openEnigma(document: doc)
            return
        case .aesInspector:
            tool("aesinspector", "Rijndael Inspector", 760, 560) { AESInspectorView() }
            return
        case .caesarVisualization:
            tool("caesardisk", "Caesar Disk", 720, 420) { CaesarDiskView() }
            return
        case .randomGenerator:
            tool("randomgen", "Generation of Random Numbers", 600, 560) { RandomGeneratorView() }
            return
        case .passwordQuality:
            tool("pwquality", "Password Quality Meter", 520, 440) { PasswordQualityView() }
            return
        case .passwordEntropy:
            tool("pwentropy", "Generate Passwords with Given Entropy", 560, 560) { PasswordEntropyView() }
            return
        case .numberLength:
            tool("numlength", "Length of a Number", 560, 440) { NumberLengthView() }
            return
        case .numberShark:
            CT1Games.openNumberShark()
            return
        case .ecPointAddition:
            CT1Games.openECCDemo()
            return
        case .mersenne:
            tool("mersenne", "Compute Mersenne Numbers", 560, 480) { MersenneView() }
            return
        default:
            break
        }

        guard let doc else { NSSound.beep(); return }

        switch action {
        // Klassisch
        case .caesar: sheet(window, "Caesar") { CaesarDialog(document: doc, close: $0) }
        case .vigenere: sheet(window, "Vigenère") { VigenereDialog(document: doc, close: $0) }
        case .hill: sheet(window, "Hill") { HillDialog(document: doc, close: $0) }
        case .substitution: sheet(window, "Substitution") { SubstitutionDialog(document: doc, close: $0) }
        case .playfair: sheet(window, "Playfair") { PlayfairDialog(document: doc, close: $0) }
        case .adfgvx: sheet(window, "ADFGVX") { ADFGVXDialog(document: doc, close: $0) }
        case .byteAddition: sheet(window, "Byte Addition") { ByteCipherDialog(kind: .addition, document: doc, close: $0) }
        case .xor: sheet(window, "XOR") { ByteCipherDialog(kind: .xor, document: doc, close: $0) }
        case .vernam: sheet(window, "Vernam") { VernamDialog(document: doc, close: $0) }
        case .homophone: sheet(window, "Homophone") { HomophoneDialog(document: doc, close: $0) }
        case .permutation: sheet(window, "Permutation") { PermutationDialog(document: doc, close: $0) }
        case .solitaire: sheet(window, "Solitaire") { SolitaireDialog(document: doc, close: $0) }
        case .scytaleRailFence: sheet(window, "Scytale / Rail Fence") { ScytaleDialog(document: doc, close: $0) }

        // Modern
        case .symmetric(let raw):
            guard let alg = SymmetricAlgorithm(rawValue: raw) else { return }
            sheet(window, alg.displayName) { SymmetricDialog(algorithm: alg, document: doc, close: $0) }
        case .bruteForce(let raw):
            guard let alg = SymmetricAlgorithm(rawValue: raw) else { return }
            sheet(window, "Brute-Force Analysis") { BruteForceDialog(algorithm: alg, document: doc, close: $0) }

        // Asymmetrisch / Hybrid / Signaturen
        case .rsaEncrypt: sheet(window, "RSA") { RSAEncryptDialog(document: doc, decrypt: false, close: $0) }
        case .rsaDecrypt: sheet(window, "RSA") { RSAEncryptDialog(document: doc, decrypt: true, close: $0) }
        case .hybridRSAEncrypt: sheet(window, "Hybrid") { HybridDialog(document: doc, ecc: false, decrypt: false, close: $0) }
        case .hybridRSADecrypt: sheet(window, "Hybrid") { HybridDialog(document: doc, ecc: false, decrypt: true, close: $0) }
        case .hybridECCEncrypt: sheet(window, "Hybrid") { HybridDialog(document: doc, ecc: true, decrypt: false, close: $0) }
        case .hybridECCDecrypt: sheet(window, "Hybrid") { HybridDialog(document: doc, ecc: true, decrypt: true, close: $0) }
        case .signDocument: sheet(window, "Sign a Document") { SignDialog(document: doc, close: $0) }
        case .verifySignature: SignatureOps.verify(doc)
        case .extractSignature: SignatureOps.extract(doc)

        // Hash
        case .hash(let raw):
            guard let alg = HashAlgorithm(rawValue: raw) else { return }
            sheet(window, "Hash value") { HashResultSheet(algorithm: alg, document: doc, close: $0) }

        // Codierungen / Kompression
        case .base64Encode:
            open(Base64Codec.encode(doc.bytes), "Base64 encoding", doc)
        case .base64Decode:
            run(doc) { DocumentFactory.openResult(try Base64Codec.decode(doc.text), title: DocumentFactory.title("Base64 decoding", of: doc), parent: doc) }
        case .uuEncode:
            open(UUCodec.encode(doc.bytes, fileName: doc.shortName), "UU Encoding", doc)
        case .uuDecode:
            run(doc) {
                let r = try UUCodec.decode(doc.text)
                DocumentFactory.openResult(r.bytes, title: DocumentFactory.title("UU Decoding", of: doc) + (r.fileName.map { " (\($0))" } ?? ""), parent: doc)
            }
        case .asn1Decode:
            run(doc) { open(try ASN1.dump(doc.bytes), "ASN.1 decoding", doc) }
        case .zip: CT1ZipFeature.zip(doc)
        case .unzip: CT1ZipFeature.unzip(doc)

        // Analyse-Werkzeuge
        case .entropy: CT1Analysis.openEntropy(document: doc)
        case .histogram:
            tool(nil, "Histogram of <\(doc.shortName)>", 820, 460) { HistogramView(document: doc) }
        case .floatingFrequency:
            let v = Statistics.floatingFrequency(doc.bytes, window: 64)
            tool(nil, "Floating frequency of <\(doc.shortName)>", 820, 420) {
                SeriesChartView(title: "Floating frequency", xLabel: "Section offset", yLabel: "Different characters per 64 byte block",
                                values: v, note: "Number of different characters in a sliding window of 64 bytes. Encrypted or compressed sections stand out clearly from plaintext.", parent: doc)
            }
        case .ngram: CT1Analysis.openNGram(document: doc)
        case .autocorrelation:
            let raw = Statistics.autocorrelation(doc.bytes, maxShift: min(max(1, doc.bytes.count - 1), 256)).map(Double.init)
            let relative = AppSettings.shared.plotRelativeAutocorrelation
            let v = relative ? raw.enumerated().map { $0.element * 100 / Double(max(1, doc.bytes.count - $0.offset - 1)) } : raw
            tool(nil, "Autocorrelation of <\(doc.shortName)>", 820, 420) {
                SeriesChartView(title: "Autocorrelation", xLabel: "Offset", yLabel: relative ? "Relative agreement [%]" : "Number of characters that match", values: v, xOffset: 1, bars: true,
                                note: "Number of matching bytes between the document and its copy shifted by k positions. Peaks at multiples of k indicate a period (key length).", parent: doc)
            }
        case .periodicity: CT1Analysis.openPeriodicity(document: doc)

        // Klassische Analyse
        case .caesarAnalysis: CT1Analysis.openCaesarAnalysis(document: doc)
        case .vigenereAnalysis: CT1Analysis.openVigenereAnalysis(document: doc)
        case .substitutionAnalysis: CT1Analysis.openAutomaticSubstitution(document: doc)
        case .byteAdditionAnalysis: CT1Analysis.openAdditionAnalysis(document: doc)
        case .xorAnalysis: CT1Analysis.openXORAnalysis(document: doc)
        case .hillAnalysis: CT1Analysis.openHillAnalysis(document: doc)
        case .transpositionAnalysis: CT1Analysis.openTranspositionAnalysis(document: doc)
        case .manualSubstitution: CT1Analysis.openManualSubstitution(document: doc)
        case .vigenereSchroedel: CT1Analysis.openVigenereSchroedel(document: doc)
        case .adfgvxAnalysis: CT1Analysis.openADFGVXAnalysis(document: doc)
        case .solitaireAnalysis: CT1Analysis.openSolitaireAnalysis(document: doc)
        case .playfairAnalysis: CT1Analysis.openPlayfairAnalysis(document: doc)

        // Zufallsanalyse
        case .randomFrequencyTest: CT1Analysis.openFrequencyTest(document: doc)
        case .randomPokerTest: CT1Analysis.openPokerTest(document: doc)
        case .randomRunsTest: CT1Analysis.openRunsTest(document: doc)
        case .randomSerialTest: CT1Analysis.openSerialTest(document: doc)
        case .randomFIPS: CT1Analysis.openFIPSTest(document: doc)
        case .randomVitanyi: CT1Analysis.openVitanyi(document: doc)
        case .random3D: CT1Analysis.open3DVisualization(document: doc)

        default:
            Alerts.info("This function is not available in the macOS version.", title: "Not available")
        }
    }

    static func openManualSubstitution(_ doc: CTDocument, initialKey: [Int]?) {
        tool(nil, "Manual substitution analysis of <\(doc.shortName)>", 900, 560) { ManualSubstitutionView(document: doc, initialKey: initialKey) }
    }

    // MARK: helpers

    private static func tool<V: View>(_ id: String?, _ title: String, _ w: CGFloat, _ h: CGFloat, @ViewBuilder _ content: () -> V) {
        WindowPresenter.tool(id: id, title: title, size: CGSize(width: w, height: h), content: content)
    }

    private static func sheet<V: View>(_ window: NSWindow?, _ title: String, @ViewBuilder _ content: (@escaping () -> Void) -> V) {
        WindowPresenter.sheet(on: window, title: title, content: content)
    }

    private static func open(_ text: String, _ op: String, _ doc: CTDocument) {
        DocumentFactory.openResult(text: text, title: DocumentFactory.title(op, of: doc), parent: doc)
    }

    private static func run(_ doc: CTDocument, _ body: () throws -> Void) {
        do { try body() } catch { Alerts.error(error.localizedDescription) }
    }

    private static func randomTest(_ kind: RandomTestView.Kind, _ doc: CTDocument) {
        tool(nil, "Randomness analysis of <\(doc.shortName)>", 600, 520) { RandomTestView(kind: kind, document: doc) }
    }
}
