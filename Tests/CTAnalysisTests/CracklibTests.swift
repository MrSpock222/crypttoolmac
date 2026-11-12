import Foundation
import CTAnalysis

/// CT1 presentation slide: password quality with the cracklib dictionary.
func runCracklibTests() {
    print("— Passwort-Qualität mit cracklib-Wörterbuch")
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/Words/cracklib-words.deflate")
    guard let d = try? Data(contentsOf: url), let raw = try? (d as NSData).decompressed(using: .zlib) else {
        check(false, "cracklib-words.deflate lesbar"); return
    }
    let dict = PasswordDictionary(sortedWordList: [UInt8](raw as Data))
    check(dict.count == 1_648_594, "cracklib: 1.648.594 Wörter (\(dict.count))")
    check(dict.contains("password") && dict.contains("brucellosis") && !dict.contains("xq7zzv"), "cracklib: Suche")
    PasswordTools.dictionary = dict
    let q = PasswordTools.quality(of: "X40bTRds&11w_dks")
    print("  X40bTRds&11w_dks → CrypTool \(q.qualityCrypTool) %")
    check(q.qualityCrypTool == 77, "CT1-Folie: X40bTRds&11w_dks = 77 % (CrypTool-Maß), ist \(q.qualityCrypTool)")
    PasswordTools.dictionary = nil
}
