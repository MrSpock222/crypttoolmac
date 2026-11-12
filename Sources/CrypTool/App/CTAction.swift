import AppKit

/// All CrypTool menu commands. Parameterised cases carry the raw value of the
/// corresponding algorithm enum of the crypto modules.
enum CTAction: Hashable {
    // Datei / Bearbeiten / Ansicht
    case documentProperties, showKey, gotoParent, findReplace, findNext
    case viewAsText, viewAsHex, editHex
    case fontLarger, fontSmaller, toggleLineWrap
    case toggleToolbar, toggleStatusBar, viewAlphabet, viewEndOfLine, viewWhitespace
    case font(String, Int)
    case formatTextDocument, plotAsBars

    // Ver-/Entschlüsseln – klassisch
    case caesar, vigenere, hill, substitution, playfair, adfgvx
    case byteAddition, xor, vernam, homophone, permutation, solitaire, scytaleRailFence
    // modern
    case symmetric(String)
    case aesSelfExtract
    // asymmetrisch / hybrid
    case rsaEncrypt, rsaDecrypt, rsaDemo
    case hybridRSAEncrypt, hybridRSADecrypt, hybridECCEncrypt, hybridECCDecrypt

    // Digitale Signaturen / PKI
    case keyGeneration, keyList, signDocument, verifySignature, extractSignature, signatureDemo

    // Einzelverfahren
    case hash(String), hashOfFile, hashDemo, pkcs5, hmac
    case primeTest, primeGeneration, factorization
    case factorHint, stereotypedAttack, bloemerMay
    case diffieHellman, challengeResponse, smime
    case crtAstronomy, crtTransformation, crtSecretSharing
    case caesarVisualization, caesarAnimation, vigenereAnimation, nihilistAnimation, desAnimation
    case rijndaelAnimation, aesInspector, rijndaelFlow, enigma
    case shamirSecretSharing
    case base64Encode, base64Decode, uuEncode, uuDecode, asn1Decode
    case zip, unzip
    case randomGenerator, passwordQuality, passwordEntropy, numberLength
    case numberShark
    case ecPointAddition, mersenne, tadicNAF, numberTheoryLearning

    // Analyse
    case entropy, floatingFrequency, histogram, ngram, autocorrelation, periodicity
    case caesarAnalysis, vigenereAnalysis, vigenereSchroedel, adfgvxAnalysis, substitutionAnalysis, solitaireAnalysis
    case byteAdditionAnalysis, xorAnalysis
    case hillAnalysis, transpositionAnalysis
    case manualSubstitution, playfairAnalysis
    case bruteForce(String)
    case sideChannelAttack, signatureAttack
    case randomFrequencyTest, randomPokerTest, randomRunsTest, randomSerialTest, randomFIPS, randomVitanyi, random3D

    // Optionen / Fenster / Hilfe
    case plotOptions, textOptions, analysisOptions, startOptions
    case windowCascade, windowTile, windowArrangeIcons, windowCloseAll
    case openExample(String)
    case helpStart, helpIndex, helpScenarios, helpReadme, helpBook, helpPresentation, contextHelp
    case helpWebsite, helpLicense, about

    /// Whether the command operates on the active document.
    var requiresDocument: Bool {
        switch self {
        case .documentProperties, .showKey, .gotoParent, .findReplace, .findNext, .viewAsText, .viewAsHex, .editHex, .formatTextDocument,
             .caesar, .vigenere, .hill, .substitution, .playfair, .adfgvx,
             .byteAddition, .xor, .vernam, .homophone, .permutation, .solitaire, .scytaleRailFence,
             .symmetric, .rsaEncrypt, .rsaDecrypt,
             .hybridRSAEncrypt, .hybridRSADecrypt, .hybridECCEncrypt, .hybridECCDecrypt,
             .signDocument, .verifySignature, .extractSignature,
             .hash, .base64Encode, .base64Decode, .uuEncode, .uuDecode, .asn1Decode, .zip, .unzip,
             .entropy, .floatingFrequency, .histogram, .ngram, .autocorrelation, .periodicity,
             .caesarAnalysis, .vigenereAnalysis, .vigenereSchroedel, .adfgvxAnalysis, .substitutionAnalysis, .solitaireAnalysis,
             .byteAdditionAnalysis, .xorAnalysis, .hillAnalysis, .transpositionAnalysis,
             .manualSubstitution, .playfairAnalysis, .bruteForce,
             .randomFrequencyTest, .randomPokerTest, .randomRunsTest, .randomSerialTest, .randomFIPS, .randomVitanyi, .random3D:
            return true
        default:
            return false
        }
    }
}

/// NSMenuItem.representedObject wrapper.
final class ActionBox: NSObject {
    let action: CTAction
    init(_ action: CTAction) { self.action = action }
}

extension NSMenuItem {
    var ctAction: CTAction? { (representedObject as? ActionBox)?.action }
}

/// Selector shared by window controllers and the app delegate.
@MainActor @objc protocol CTActionHandling {
    func performCTAction(_ sender: Any?)
}

/// CT1's context help button ("?" in the toolbar): the next menu command shows its help page
/// instead of being executed.
@MainActor
enum ContextHelp {
    private(set) static var armed = false

    static func arm() {
        armed = true
        NSCursor.contextualMenu.push()
    }

    /// Returns true if the action was consumed by the context help.
    static func consume(_ action: CTAction) -> Bool {
        guard armed else { return false }
        armed = false
        NSCursor.pop()
        HelpLink.show(for: action)
        return true
    }
}
