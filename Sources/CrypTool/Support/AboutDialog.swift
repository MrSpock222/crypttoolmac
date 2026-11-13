import AppKit
import SwiftUI

/// CT1 "Über CrypTool" (IDD_ABOUT) with the sub-dialogs "Mitwirkende" (IDD_AUTHORS) and
/// "Übersetzungen" (IDD_TRANSLATIONS).
@MainActor
enum AboutDialog {
    static func show() {
        WindowPresenter.tool(id: "about", title: "About CrypTool", size: CGSize(width: 560, height: 500), resizable: false) {
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
            Text("CrypTool is a free and comprehensive e-learning program about\nclassic and contemporary cryptography and cryptanalysis.\n\nIn a joint effort with the sponsors")
                .multilineTextAlignment(.center)
            HStack(spacing: 40) {
                logo("logo_db")
                logo("logo_secude")
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            Text("the universities Siegen and Darmstadt developed it within an\nopen source project thanks to the help of many voluntary developers.")
                .multilineTextAlignment(.center)
            Text("CrypTool is used world-wide for education in schools and universities, and for education and employee awareness in companies and government organizations.")
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                GroupBox("Release information") {
                    Text("CrypTool \(AboutDialog.version) for macOS (Apple Silicon),\nnative port of CrypTool 1.4.x")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .center).fixedSize(horizontal: false, vertical: true)
                }
                GroupBox("Contact information") {
                    Text("bernhard.esslinger@uni-siegen.de\nInternet: http://www.cryptool.org")
                        .font(.callout).frame(maxWidth: .infinity, alignment: .center).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("(C) 1998-2022 CrypTool Team\nDistributed as open source under the terms of the Apache License 2.0")
                .font(.callout).multilineTextAlignment(.center)
            Text("macOS port: unofficial, also Apache License 2.0")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Button("Contributors") { showAuthors = true }
                Button("Translations") { showTranslations = true }
                Spacer()
                Button("Close", action: closeKeyWindow).keyboardShortcut(.defaultAction)
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
            Text("Persons Contributing to CrypTool").font(.headline)
                .frame(maxWidth: .infinity).padding(4)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
            group(" Idea, Sponsoring, Challenges, QA, Lead ", "Bernhard Esslinger")
            group(" Design, Support and Architecture", "Peer Wichmann (till release 1.2)\nJoerg Cornelius Schneider (from release 1.3)")
            group(" Main Persons Taking Overall Care for Version 1.3 and 1.4", "Henrik Koy\nFlorian Marchal")
            HStack(alignment: .top, spacing: 10) {
                list(" Implementation, Documentation, Translation ", impl)
                list(" Review and Feedback", review)
            }
            HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction) }
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

/// Text assembled as in CT1 (DlgTranslations.cpp): heading, "=" underline of 2/3 heading length,
/// initial work, further work; order French, Greek, Polish, Serbian, Spanish.
private struct TranslationsView: View {
    let close: () -> Void
    private let text = """
    French Translation
    ============
    Initial translation: Alain Stephan
    Further updates: Alain Stephan


    Greek Translation
    ===========
    Initial translation: University of Macedonia, Thessaloniki, Greece (http://infosec.uom.gr),
    Prof. Ioannis Mavridis
    Further updates: Vasilios Mavroudis, Dr. Theodoros Mastoras


    Polish Translation
    ============
    Initial translation: Warsaw University, Poland (http://www.ee.pw.edu.pl),
    Dr. Bartosz Sawicki and his students
    Further updates: Pawel Polewski


    Serbian Translation
    ============
    Initial translation: Advanced School of Electrical Engineering, Belgrade, Serbia (http://www.viser.edu.rs),
    Prof. Dragan Pleskonjic, Bojan Dimitrovski and his fellow students
    Further updates: Bojan Dimitrovski, Vesna Milosavljevic


    Spanish Translation
    ============
    Initial translation: Madrid University, Spain (http://www.csic.es),
    Dr. Gonzalo Alvarez Maranon and his students
    Further updates: Raphael Labaca Castro


    The macOS version contains the English language version only.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The CrypTool versions in English and German have been created by the CrypTool core team.")
            ResultBox(text: text, minHeight: 380)
            HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction) }
        }
        .padding(16)
        .frame(width: 560, height: 500)
    }
}
