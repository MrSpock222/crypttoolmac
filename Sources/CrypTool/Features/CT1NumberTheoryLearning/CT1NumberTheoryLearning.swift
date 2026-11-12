import AppKit
import SwiftUI

/// "Lernprogramm für Zahlentheorie" – native re-creation of CT1's Authorware program ZT
/// (Martin Ramberger). The page texts were recovered from ZT.exe and are shown verbatim;
/// the interactive parts are rebuilt in SwiftUI on top of CTBigNum.
@MainActor
enum CT1NumberTheoryLearning {
    static func open() {
        WindowPresenter.tool(id: "ct1.zt.learning", title: "Lernprogramm für Zahlentheorie",
                             size: CGSize(width: 1080, height: 760)) {
            ZTLearningView()
        }
    }
}

// MARK: - Model

struct ZTPage: Identifiable {
    let id: String
    let title: String
    let tool: ZTTool?
    let blocks: [String]
}

struct ZTChapter: Identifiable {
    let number: String
    let title: String
    let pages: [ZTPage]
    var id: String { number }
}

struct ZTLesson: Identifiable {
    let number: Int
    let title: String
    let chapters: [ZTChapter]
    var id: Int { number }
}

struct ZTGlossaryEntry: Identifiable {
    let term: String
    let pageID: String
    var id: String { term + "@" + pageID }
}

enum ZTContent {
    static let lessons: [ZTLesson] = [lesson1(), lesson2(), lesson3(), lesson4(), lesson5(), lesson6()]

    /// Flat page sequence (the order of "Seite vor" / "Zurück").
    static let flat: [(lesson: ZTLesson, chapter: ZTChapter, page: ZTPage)] =
        lessons.flatMap { l in l.chapters.flatMap { c in c.pages.map { (l, c, $0) } } }

    static func index(of pageID: String) -> Int? { flat.firstIndex { $0.page.id == pageID } }
}

// MARK: - Main view

struct ZTLearningView: View {
    @CTState private var selection: String? = nil
    @CTState private var showGlossary = false
    @CTState private var expanded: Set<String> = ["1.1"]

    private var current: Int? { selection.flatMap { ZTContent.index(of: $0) } }

    var body: some View {
        HSplitView {
            sidebar.frame(minWidth: 230, idealWidth: 270, maxWidth: 360)
            VStack(spacing: 0) {
                if let i = current {
                    ZTPageView(entry: ZTContent.flat[i]).id(ZTContent.flat[i].page.id)
                } else {
                    ZTStartView { selection = $0; reveal($0) }
                }
                Divider()
                navigationBar
            }
            .frame(minWidth: 620)
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showGlossary) {
            ZTGlossaryView { id in
                showGlossary = false
                selection = id
                reveal(id)
            } close: { showGlossary = false }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(ZTContent.lessons) { lesson in
                Section("\(lesson.number). \(lesson.title)") {
                    ForEach(lesson.chapters) { ch in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expanded.contains(ch.number) },
                            set: { if $0 { expanded.insert(ch.number) } else { expanded.remove(ch.number) } })) {
                            ForEach(Array(ch.pages.enumerated()), id: \.element.id) { n, page in
                                HStack(spacing: 6) {
                                    Text("\(n + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                        .frame(width: 16, alignment: .trailing)
                                    Text(page.title).lineLimit(2)
                                    if page.tool != nil {
                                        Spacer(minLength: 2)
                                        Image(systemName: "hand.point.up.left").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .tag(Optional(page.id))
                            }
                        } label: {
                            Text("\(ch.number) \(ch.title)").fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            Button { go(-1) } label: { Label("Zurück", systemImage: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(current == nil)
            Button { selection = nil } label: { Label("Lektionsverzeichnis", systemImage: "list.bullet") }
            Button { showGlossary = true } label: { Label("Begriffe", systemImage: "character.book.closed") }
            Spacer()
            if let i = current {
                let e = ZTContent.flat[i]
                let n = (e.chapter.pages.firstIndex { $0.id == e.page.id } ?? 0) + 1
                Text("Seite \(n) von \(e.chapter.pages.count)").foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            Button { go(1) } label: {
                HStack(spacing: 4) { Text("Seite vor"); Image(systemName: "chevron.right") }
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled((current ?? -1) >= ZTContent.flat.count - 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func go(_ delta: Int) {
        let next = (current ?? -1) + delta
        guard next >= 0 else { selection = nil; return }
        guard next < ZTContent.flat.count else { return }
        let id = ZTContent.flat[next].page.id
        selection = id
        reveal(id)
    }

    private func reveal(_ id: String) {
        if let i = ZTContent.index(of: id) { expanded.insert(ZTContent.flat[i].chapter.number) }
    }
}

// MARK: - Start page (Lektionsverzeichnis)

struct ZTStartView: View {
    let open: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Zahlentheorie zur asymmetrischen Verschlüsselung").font(.largeTitle.weight(.semibold))
                Text("Lernprogramm für Zahlentheorie – nach ZT von Martin Ramberger")
                    .font(.title3).foregroundStyle(.secondary)
                Text("Die Seitentexte stammen aus dem Original-Lernprogramm ZT (CrypTool 1). Die Mitmach-Teile "
                     + "(„Ausprobieren“) wurden für macOS nachgebaut: Geben Sie eigene kleine Zahlen ein und verfolgen "
                     + "Sie die Verfahren Schritt für Schritt. Blättern mit „Seite vor“/„Zurück“ (⌘→ / ⌘←).")
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], alignment: .leading, spacing: 14) {
                    ForEach(ZTContent.lessons) { lesson in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(lesson.chapters) { ch in
                                    Button {
                                        if let p = ch.pages.first { open(p.id) }
                                    } label: {
                                        Text("\(ch.number)  \(ch.title)").frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.link)
                                }
                            }
                            .padding(4)
                        } label: {
                            Text("\(lesson.number). \(lesson.title)").font(.headline)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Page view

struct ZTPageView: View {
    let entry: (lesson: ZTLesson, chapter: ZTChapter, page: ZTPage)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(entry.lesson.number). \(entry.lesson.title)  ▸  \(entry.chapter.number) \(entry.chapter.title)")
                    .font(.callout).foregroundStyle(.secondary)
                Text(entry.page.title).font(.title.weight(.semibold))
                if entry.page.blocks.isEmpty {
                    Text("(Diese Seite des Originals besteht nur aus einer Animation; Text siehe Ausprobieren.)")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(entry.page.blocks.enumerated()), id: \.offset) { _, block in
                    ZTRichText(block)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                }
                if let tool = entry.page.tool {
                    GroupBox {
                        ZTToolView(tool: tool).padding(6)
                    } label: {
                        Label("Ausprobieren – \(tool.title)", systemImage: "hand.point.up.left").font(.headline)
                    }
                    .padding(.top, 6)
                }
                Text("Seitentext aus ZT (Martin Ramberger, Diplomarbeit Uni Koblenz 2005); Mitmach-Teil nachgebaut.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Renders ZT text with \u{E000}…\u{E001} (superscript) and \u{E002}…\u{E003} (subscript) markers.
struct ZTRichText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(Self.attributed(text, monospaced: Self.isTable(text)))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    static func isTable(_ s: String) -> Bool {
        s.split(separator: "\n").filter { $0.components(separatedBy: "   ").count > 7 }.count >= 2
    }

    static func attributed(_ s: String, monospaced: Bool) -> AttributedString {
        let size = NSFont.systemFontSize + 1
        let base: Font = monospaced ? .system(size: size - 1, design: .monospaced) : .system(size: size)
        let small: Font = monospaced ? .system(size: size - 4, design: .monospaced) : .system(size: size - 4)
        var result = AttributedString()
        var buffer = ""
        var mode = 0  // 0 normal, 1 sup, 2 sub
        func flush() {
            guard !buffer.isEmpty else { return }
            var a = AttributedString(buffer)
            a.font = mode == 0 ? base : small
            if mode == 1 { a.baselineOffset = 6 } else if mode == 2 { a.baselineOffset = -3 }
            result += a
            buffer = ""
        }
        for ch in s {
            switch ch {
            case "\u{E000}": flush(); mode = 1
            case "\u{E002}": flush(); mode = 2
            case "\u{E001}", "\u{E003}": flush(); mode = 0
            default: buffer.append(ch)
            }
        }
        flush()
        return result
    }
}

// MARK: - Glossary ("Begriffe")

struct ZTGlossaryView: View {
    let open: (String) -> Void
    let close: () -> Void
    @CTState private var filter = ""

    private var entries: [ZTGlossaryEntry] {
        let f = filter.trimmingCharacters(in: .whitespaces).lowercased()
        return f.isEmpty ? ZTContent.glossary : ZTContent.glossary.filter { $0.term.lowercased().contains(f) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Begriffe").font(.title2.weight(.semibold))
            TextField("Suchen", text: $filter).textFieldStyle(.roundedBorder)
            List(entries) { e in
                Button {
                    open(e.pageID)
                } label: {
                    HStack {
                        Text(e.term)
                        Spacer()
                        if let i = ZTContent.index(of: e.pageID) {
                            Text("\(ZTContent.flat[i].chapter.number) \(ZTContent.flat[i].page.title)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 360)
            HStack {
                Spacer()
                Button("Schließen", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 520, height: 520)
    }
}
