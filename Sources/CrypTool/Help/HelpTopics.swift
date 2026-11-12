import Foundation

/// Maps menu commands to the page of CT1's original online help (Resources/Help/de).
///
/// CT1 names the page of a menu command after its lower-case command ID without "ID_"
/// (ID_ROT13CAESAR_ASC → hid_rot13caesar_asc.html, see CrypTool.rc, menu IDR_TEXTTYPE).
/// Commands that only exist in the macOS port point to the closest CT1 page.
extension HelpCenter {
    static func topic(for action: CTAction) -> String? {
        switch action {
        // Datei / Bearbeiten / Ansicht
        case .documentProperties: return "hid_fileproperties.html"          // ID_FILEPROPERTIES
        case .showKey: return "hid_show_key.html"                           // ID_SHOW_KEY
        case .findReplace: return "hid_edit_find.html"                      // ID_EDIT_FIND
        case .findNext: return "hid_edit_find_next.html"                    // ID_EDIT_FIND_NEXT
        case .gotoParent: return "hid_goto_vater.html"                      // ID_GOTO_VATER
        case .viewAsText: return "hid_totxt.html"                           // ID_TOTXT
        case .viewAsHex: return "hid_tohex.html"                            // ID_TOHEX
        case .editHex: return "hid_tohex.html"                              // hex window = hex input in CT1
        case .fontLarger, .fontSmaller: return "menu_view_font.html"        // Ansicht ▸ Schriftart
        case .toggleLineWrap: return "hid_view_linewrap.html"               // ID_VIEW_LINEWRAP
        case .toggleToolbar: return "hid_view_toolbar.html"                 // ID_VIEW_TOOLBAR
        case .toggleStatusBar: return "hid_view_status_bar.html"            // ID_VIEW_STATUS_BAR
        case .viewAlphabet: return "hid_view_alphabet.html"                 // ID_VIEW_ALPHABET
        case .viewEndOfLine: return "hid_view_endofline.html"               // ID_VIEW_ENDOFLINE
        case .viewWhitespace: return "hid_view_whitespace.html"             // ID_VIEW_WHITESPACE
        case .font(let family, let size):                                   // ID_ZEICHENFORMAT_ARIAL08 …
            let page = String(format: "hid_zeichenformat_%@%02d.html", family.lowercased(), size)
            return HelpBook.url(for: page) != nil ? page : "menu_view_font.html"
        case .formatTextDocument: return "hid_format_text_document.html"    // ID_FORMAT_TEXT_DOCUMENT
        case .plotAsBars: return "hid_plotbar.html"                         // ID_PLOTBAR

        // Ver-/Entschlüsseln ▸ Symmetrisch (klassisch)
        case .caesar: return "hid_rot13caesar_asc.html"                     // ID_ROT13CAESAR_ASC
        case .vigenere: return "hid_vigenere_asc.html"                      // ID_VIGENERE_ASC
        case .hill: return "hid_hill.html"                                  // ID_HILL
        case .substitution: return "hid_cryptmono.html"                     // ID_CryptMono
        case .playfair: return "hid_playfair_bin.html"                      // ID_PLAYFAIR_BIN
        case .adfgvx: return "hid_encrypt_adfgvx.html"                      // ID_ENCRYPT_ADFGVX
        case .byteAddition: return "hid_add_bin.html"                       // ID_ADD_BIN
        case .xor: return "hid_xor_bin.html"                                // ID_XOR_BIN
        case .vernam: return "hid_vernam_bin.html"                          // ID_VERNAM_BIN
        case .homophone: return "hid_homophone_asc.html"                    // ID_HOMOPHONE_ASC
        case .permutation: return "hid_permutation.html"                    // ID_PERMUTATION
        case .solitaire: return "hid_symclassic_solitaire.html"             // ID_SYMCLASSIC_SOLITAIRE
        case .scytaleRailFence: return "hid_encryption_simple_transpositions.html" // ID_ENCRYPTION_SIMPLE_TRANSPOSITIONS

        // Ver-/Entschlüsseln ▸ Symmetrisch (modern) – raw values of SymmetricAlgorithm
        case .symmetric(let raw):
            switch raw {
            case "idea": return "hid_crypt_idea.html"
            case "rc2": return "hid_crypt_rc2.html"
            case "rc4": return "hid_crypt_rc4.html"
            case "desECB": return "hid_crypt_des_desecb.html"
            case "desCBC": return "hid_crypt_des_descbc.html"
            case "tripleDESECB": return "hid_crypt_3des_ecb.html"
            case "tripleDESCBC": return "hid_crypt_3des_cbc.html"
            case "aes": return "hid_crypt_aes_rijndael.html"
            case "mars": return "hid_crypt_aes_mars.html"
            case "rc6": return "hid_crypt_aes_rc6.html"
            case "serpent": return "hid_crypt_aes_serpent.html"
            case "twofish": return "hid_crypt_aes_twofish.html"
            case "desx": return "hid_crypt_desx.html"
            case "desl": return "hid_crypt_desl.html"
            case "desxl": return "hid_crypt_desxl.html"
            default: return "menu_crypt_symmetricmodern.html"
            }
        case .aesSelfExtract: return "hid_aes_selfextract.html"             // ID_AES_SELFEXTRACT

        // Asymmetrisch / Hybrid
        case .rsaEncrypt: return "hid_crypt_rsaenc.html"                    // ID_CRYPT_RsaEnc
        case .rsaDecrypt: return "hid_crypt_rsadec.html"                    // ID_CRYPT_RsaDec
        case .rsaDemo: return "hid_einzelverfahren_tutorial_rsaalgorithmus.html"
        case .hybridRSAEncrypt: return "hid_verentschlsseln_hybridverfahren_hybridverschlsselung.html"
        case .hybridRSADecrypt: return "hid_verentschlsseln_hybridverfahren_hybridentschlsselung.html"
        case .hybridECCEncrypt: return "hid_hybrid_eccenc.html"             // ID_HYBRID_ECCENC
        case .hybridECCDecrypt: return "hid_hybrid_eccdec.html"             // ID_HYBRID_ECCDEC

        // Digitale Signaturen/PKI
        case .keyGeneration: return "hid_crypt_keygen.html"                 // ID_CRYPT_KeyGen
        case .keyList: return "hid_show_all_ec_keys.html"                   // ID_SHOW_ALL_EC_KEYS
        case .signDocument: return "hid_crypt_sign.html"                    // ID_CRYPT_SIGN
        case .verifySignature: return "hid_crypt_verify.html"               // ID_CRYPT_VERIFY
        case .extractSignature: return "hid_crypt_extract.html"             // ID_CRYPT_EXTRACT
        case .signatureDemo: return "hid_einzelverfahren_sign_doc.html"     // ID_EINZELVERFAHREN_SIGN_DOC

        // Einzelverfahren ▸ Hashverfahren – raw values of HashAlgorithm
        case .hash(let raw):
            switch raw {
            case "md2": return "hid_crypt_hash_md2.html"
            case "md4": return "hid_crypt_hash_md4.html"
            case "md5": return "hid_crypt_hash_md5.html"
            case "sha0": return "hid_crypt_hash_sha.html"
            case "sha1": return "hid_crypt_hash_sha1.html"
            case "sha256": return "hid_crypt_hash_sha256.html"
            case "sha512": return "hid_crypt_hash_sha512.html"
            case "ripemd160": return "hid_crypt_hash_ripemd160.html"
            default: return "menu_individualprocedures_hashprocedures.html"
            }
        case .hashOfFile: return "hid_hash_ofafile.html"                    // ID_HASH_OFAFILE
        case .hashDemo: return "hid_einzelverfahren_hashwerte_hashdemo.html"
        case .pkcs5: return "hid_einzelverfahren_schluesselgenerieren.html"
        case .hmac: return "hid_generate_macs.html"                         // ID_GENERATE_MACS

        // Einzelverfahren ▸ RSA-Kryptosystem / Protokolle / CRT
        case .primeTest: return "hid_primenumber_test.html"                 // ID_PRIMENUMBER_TEST
        case .primeGeneration: return "hid_einzelverfahren_tutorial_primzahlengenerieren.html"
        case .factorization: return "hid_einzelverfahren_tutorialfrkleinezahlen_faktorisierenifp.html"
        case .factorHint: return "hid_rsa_factorhint.html"                  // ID_RSA_FACTORHINT
        case .stereotypedAttack: return "hid_rsa_stereotyped.html"          // ID_RSA_STEREOTYPED
        case .bloemerMay: return "hid_rsa_bloemermay.html"                  // ID_RSA_BLOEMERMAY
        case .diffieHellman: return "hid_einzelverfahren_diffiehellmandemo.html"
        case .challengeResponse: return "hid_cr_overview.html"              // ID_CHALLENGE_RESPONSE (alias)
        case .smime: return "hid_protokol_smime.html"                       // ID_PROTOKOL_SMIME
        case .crtAstronomy: return "hid_indiv_crt_planet.html"              // ID_INDIV_CRT_PLANET
        case .crtTransformation: return "hid_indiv_crt_demo.html"           // ID_INDIV_CRT_DEMO
        case .crtSecretSharing: return "hid_indiv_crt_secretsharing.html"   // ID_INDIV_CRT_SECRETSHARING

        // Einzelverfahren ▸ Visualisierung / Secret Sharing
        case .caesarVisualization: return "hid_rot13caesar_asc.html"        // Caesar disk (port only)
        case .caesarAnimation: return "hid_help_animal_caesar.html"         // ID_HELP_ANIMAL_CAESAR
        case .vigenereAnimation: return "hid_help_animal_vigenere.html"     // ID_HELP_ANIMAL_VIGENERE
        case .nihilistAnimation: return "hid_help_animal_nihilist.html"     // ID_HELP_ANIMAL_NIHILIST
        case .desAnimation: return "hid_help_animal_des.html"               // ID_HELP_ANIMAL_DES
        case .rijndaelAnimation: return "hid_flash_aesdemo.html"            // ID_FLASH_AESDEMO
        case .aesInspector: return "hid_flash_rijndael_inspector.html"      // ID_FLASH_RIJNDAEL_INSPECTOR
        case .rijndaelFlow: return "hid_aes_rijndael_flowvisualisation.html" // ID_AES_RIJNDAEL_FLOWVISUALISATION
        case .enigma: return "hid_flash_enigmademo.html"                    // ID_FLASH_ENIGMADEMO
        case .shamirSecretSharing: return "hid_individual_procedures_secretsharing.html"

        // Einzelverfahren ▸ Tools
        case .base64Encode: return "hid_encode_base64.html"
        case .base64Decode: return "hid_decode_base64.html"
        case .uuEncode: return "hid_encode_uu.html"
        case .uuDecode: return "hid_decode_uu.html"
        case .asn1Decode: return "hid_einzelverfahren_asn1decodieren.html"
        case .zip: return "hid_zip.html"
        case .unzip: return "hid_unzip.html"
        case .randomGenerator: return "hid_zufall_generatoren.html"         // ID_ZUFALL_GENERATOREN
        case .passwordQuality: return "hid_passwordqualitymeter.html"
        case .passwordEntropy: return "hid_passwordentropy.html"
        case .numberLength: return "hid_lengthofanumber.html"
        case .numberShark: return "hid_numbershark.html"
        case .ecPointAddition: return "hid_indiv_pointadditiononellipticcurves.html"
        case .mersenne: return "hid_compute_mersenne_numbers.html"
        case .tadicNAF: return "hid_generation_tadic_naf_keys.html"         // ID_GENERATION_TADIC_NAF_KEYS

        // Analyse ▸ Werkzeuge zur Analyse
        case .entropy: return "hid_entropy.html"
        case .floatingFrequency: return "hid_floating.html"
        case .histogram: return "hid_histogram.html"
        case .ngram: return "hid_analyse_ngram.html"
        case .autocorrelation: return "hid_auto.html"
        case .periodicity: return "hid_analyse_period.html"

        // Analyse ▸ Symmetrische Verschlüsselung (klassisch)
        case .caesarAnalysis: return "hid_caesar_auto.html"
        case .vigenereAnalysis: return "hid_vigenere_auto.html"
        case .vigenereSchroedel: return "hid_analysis_vigenere_schroedel.html"
        case .adfgvxAnalysis: return "hid_analyse_symclassic_adfgvx.html"
        case .solitaireAnalysis: return "hid_analyse_symclassic_ciphertextonly_solitaire.html"
        case .substitutionAnalysis: return "hid_ciphertext_only_substitution.html"
        case .byteAdditionAnalysis: return "hid_add_auto.html"
        case .xorAnalysis: return "hid_xor_auto.html"
        case .hillAnalysis: return "hid_hill_auto.html"
        case .transpositionAnalysis: return "hid_known_analysis_single_permutation.html"
        case .manualSubstitution: return "hid_analyze_subst.html"
        case .playfairAnalysis: return "hid_playfair_analyse.html"

        // Analyse ▸ Symmetrische Verschlüsselung (modern) – brute force, raw values of SymmetricAlgorithm
        case .bruteForce(let raw):
            switch raw {
            case "idea": return "hid_analyse_idea.html"
            case "rc2": return "hid_analyse_rc2.html"
            case "rc4": return "hid_analyse_rc4.html"
            case "desECB": return "hid_analyse_desecb.html"
            case "desCBC": return "hid_analyse_descbc.html"
            case "tripleDESECB": return "hid_analyse_tripledesecb.html"
            case "tripleDESCBC": return "hid_analyse_tripledescbc.html"
            case "aes": return "hid_analyse_aes_rijndael.html"
            case "mars": return "hid_analyse_aes_mars.html"
            case "rc6": return "hid_analyse_aes_rc6.html"
            case "serpent": return "hid_analyse_aes_serpent.html"
            case "twofish": return "hid_analyse_aes_twofish.html"
            case "desx": return "hid_analyse_desx.html"
            case "desl": return "hid_analyse_desl.html"
            case "desxl": return "hid_analyse_desxl.html"
            default: return "menu_analysis_symmetricmodern.html"
            }

        // Analyse ▸ Asymmetrische Verfahren / Hashverfahren
        case .sideChannelAttack: return "hid_einzelverfahren_sidechannelattack_on_hybridencryption.html"
        case .signatureAttack: return "hid_signatur_attack.html"            // ID_SIGNATUR_ATTACK

        // Analyse ▸ Zufallsanalyse
        case .randomFrequencyTest: return "hid_analyse_zufallstests_frequencytest.html"
        case .randomPokerTest: return "hid_analyse_zufallstests_pokertest.html"
        case .randomRunsTest: return "hid_analyse_zufallstests_runs.html"
        case .randomSerialTest: return "hid_analyse_zufallstests_serialtest.html"
        case .randomFIPS: return "hid_analyse_zufallstests_fipspub1401.html"
        case .randomVitanyi: return "hid_analyse_vitany.html"
        case .random3D: return "hid_analysis_random_3d_visualization.html"

        // Optionen / Fenster / Hilfe
        case .plotOptions: return "hid_options_plot.html"                   // ID_OPTIONS_PLOT
        case .textOptions: return "hid_opttext.html"                        // ID_OPTTEXT
        case .analysisOptions: return "hid_options_analysis.html"           // ID_OPTIONS_ANALYSIS
        case .startOptions: return "hid_options_startoptions.html"          // ID_OPTIONS_STARTOPTIONS
        case .windowCascade: return "hid_window_cascade.html"               // ID_WINDOW_CASCADE
        case .windowTile: return "hid_window_tile_horz.html"                // ID_WINDOW_TILE_HORZ
        case .windowArrangeIcons: return "hid_window_arrange.html"          // ID_WINDOW_ARRANGE
        case .windowCloseAll: return "hid_window_close_all.html"            // ID_WINDOW_CLOSE_ALL
        case .openExample: return "hid_file_open.html"                      // CT1: Datei ▸ Öffnen
        case .helpStart: return HelpBook.startPage                          // ID_HILFE_STARTSEITE (alias)
        case .helpIndex: return HelpBook.indexPage                          // ID_HILFE_INDEX (alias)
        case .helpScenarios: return HelpBook.scenariosPage                  // ID_HILFE_SZENARIEN
        case .helpBook: return "hid_script.html"                            // ID_SCRIPT (CT-Buch)
        case .helpPresentation: return "hid_help_presentation.html"         // ID_HELP_PRESENTATION
        case .contextHelp: return "hid_context_help.html"                   // ID_CONTEXT_HELP
        case .helpWebsite: return "cryptool.html"                           // "Das CrypTool-Projekt"
        case .helpReadme: return "hid_load_readme.html"                     // ID_LOAD_README
        case .helpLicense: return "gplgnu.html"                             // "CrypTool-Lizenz"
        case .about: return "hidd_about.html"                               // ID_APP_ABOUT (CrypTool_Alias.h)
        }
    }
}
