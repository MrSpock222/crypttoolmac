import AppKit
import SwiftUI

/// CT1 "Über CrypTool" (IDD_ABOUT) with the sub-dialogs "Mitwirkende" (IDD_AUTHORS) and
/// "Übersetzungen" (IDD_TRANSLATIONS).
@MainActor
enum AboutDialog {
    static func show() {
        WindowPresenter.tool(id: "about", title: "Über CrypTool", size: CGSize(width: 560, height: 500), resizable: false) {
            AboutView()
        }
    }

    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.x"
    }

    /// Names from CT1's authors.txt: (implementation/documentation/translation, review/feedback), sorted.
    static func authors() -> ([String], [String]) {
        guard let text = Resources.text("Docs/authors.txt") else { return ([], []) }
        var impl: [String] = [], review: [String] = []
        var section = 0
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                if line.contains("[IMPLEMENTATION") { section = 1 }
                if line.contains("[REVIEW") { section = 2 }
                continue
            }
            guard !line.isEmpty else { continue }
            if section == 1 { impl.append(line) } else if section == 2 { review.append(line) }
        }
        let byLastName: (String, String) -> Bool = {
            ($0.split(separator: " ").last.map(String.init) ?? $0) < ($1.split(separator: " ").last.map(String.init) ?? $1)
        }
        return (impl.sorted(by: byLastName), review.sorted(by: byLastName))
    }
}

private struct AboutView: View {
    @CTState private var showAuthors = false
    @CTState private var showTranslations = false

    var body: some View {
        VStack(spacing: 10) {
            Text("CrypTool \(AboutDialog.version)").font(.system(size: 28, weight: .bold))
            Text("CrypTool ist ein kostenloses und umfangreiches Lernprogramm\nzu klassischer und moderner Kryptographie/Kryptoanalyse.\n\nGemeinsam mit den Sponsoren")
                .multilineTextAlignment(.center)
            HStack(spacing: 40) {
                logo("logo_db")
                logo("logo_secude")
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            Text("haben es die Universitäten Siegen und Darmstadt\nund viele freiwillige Entwickler in einem Open-Source-Projekt entwickelt.")
                .multilineTextAlignment(.center)
            Text("CrypTool wird weltweit zur Lehre an Schulen und Hochschulen, und zur Ausbildung und Mitarbeiter-Awareness in Firmen und Behörden eingesetzt.")
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                GroupBox("Release-Informationen") {
                    Text("CrypTool \(AboutDialog.version) für macOS (Apple Silicon),\nnative Portierung von CrypTool 1.4.x")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true)
                }
                GroupBox("Kontakt-Informationen") {
                    Text("bernhard.esslinger@uni-siegen.de\nInternet: http://www.cryptool.de")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .center).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("(C) 1998-2022 CrypTool-Team\nOpen-Source anhand der Apache-Lizenz 2.0")
                .font(.callout).multilineTextAlignment(.center)
            Text("macOS-Portierung: inoffiziell, ebenfalls Apache-Lizenz 2.0")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Button("Mitwirkende") { showAuthors = true }
                Button("Übersetzungen") { showTranslations = true }
                Spacer()
                Button("Schließen", action: closeKeyWindow).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 560, height: 500)
        .sheet(isPresented: $showAuthors) { AuthorsView(close: { showAuthors = false }) }
        .sheet(isPresented: $showTranslations) { TranslationsView(close: { showTranslations = false }) }
    }

    private func logo(_ name: String) -> some View {
        Group {
            if let url = Resources.url("Images/\(name).png"), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).interpolation(.high)
            }
        }
    }
}

private struct AuthorsView: View {
    let close: () -> Void
    var body: some View {
        let (impl, review) = AboutDialog.authors()
        VStack(spacing: 8) {
            Text("Personen, die zu CrypTool beitrugen").font(.headline)
                .frame(maxWidth: .infinity).padding(4)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
            group(" Idee, Sponsoring, Challenges, QA, Leitung", "Bernhard Esslinger")
            group(" Planung, Betreuung und Architektur", "Peer Wichmann (bis Version 1.2)\nJoerg Cornelius Schneider (ab Version 1.3)")
            group(" Kümmerer Version 1.3 und 1.4", "Henrik Koy\nFlorian Marchal")
            HStack(alignment: .top, spacing: 10) {
                list(" Entwicklung, Dokumentation, Übersetzung ", impl)
                list(" Review und Feedback", review)
            }
            HStack { Spacer(); Button("Schließen", action: close).keyboardShortcut(.defaultAction) }
        }
        .padding(16)
        .frame(width: 560, height: 520)
    }

    private func group(_ title: String, _ text: String) -> some View {
        GroupBox(title) { Text(text).multilineTextAlignment(.center).frame(maxWidth: .infinity) }
    }

    private func list(_ title: String, _ names: [String]) -> some View {
        GroupBox(title) {
            ScrollView { Text(names.joined(separator: "\n")).frame(maxWidth: .infinity) }
        }
    }
}

private struct TranslationsView: View {
    let close: () -> Void
    private let text = """
    Polnische Übersetzung
    Erstübersetzung: Universität Warschau, Polen (http://www.ee.pw.edu.pl),
    Dr. Bartosz Sawicki und seine Studenten
    Weitere Updates: Pawel Polewski

    Serbische Übersetzung
    Erstübersetzung: Advanced School of Electrical Engineering, Belgrad, Serbien (http://www.viser.edu.rs),
    Prof. Dragan Pleskonjic, Bojan Dimitrovski und seine Kommilitonen
    Weitere Updates: Bojan Dimitrovski, Vesna Milosavljevic

    Spanische Übersetzung
    Erstübersetzung: Universität Madrid, Spanien (http://www.csic.es),
    Dr. Gonzalo Alvarez Maranon und seine Studenten
    Weitere Updates: Raphael Labaca Castro

    Französische Übersetzung
    Erstübersetzung: Alain Stephan
    Weitere Updates: Alain Stephan

    Griechische Übersetzung
    Erstübersetzung: Universität von Mazedonien, Thessaloniki, Griechenland (http://infosec.uom.gr),
    Prof. Ioannis Mavridis
    Weitere Updates: Vasilios Mavroudis, Dr. Theodoros Mastoras

    Die macOS-Version enthält nur die deutsche Sprachversion.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Die Sprachversionen Deutsch und Englisch wurden vom CrypTool-Kernteam entwickelt.")
            ResultBox(text: text, minHeight: 380)
            HStack { Spacer(); Button("Schließen", action: close).keyboardShortcut(.defaultAction) }
        }
        .padding(16)
        .frame(width: 560, height: 500)
    }
}
