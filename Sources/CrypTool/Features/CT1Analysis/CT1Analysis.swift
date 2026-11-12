import AppKit
import SwiftUI
import CTCommon

/// Ports of CT1 analyses that were missing in the Mac version (Vigenère-Analyse nach Schrödel,
/// ADFGVX-Analyse, Solitaire-Analyse, manuelle Playfair-Analyse, CT1-Substitutionsanalysen).
///
/// Every feature adds its public `open…(document:)` entry point in its own file as an extension of
/// this enum; the menu wiring is done in the app's routers.
@MainActor
enum CT1Analysis {
    /// Contents of a bundled CT1 word/statistics file (`Resources/Words/<name>`, UTF-8), nil if missing.
    static func wordFile(_ name: String) -> String? {
        Resources.text("Words/\(name)")
    }
}
