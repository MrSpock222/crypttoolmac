import AppKit
import SwiftUI

// MARK: - Shell bitmaps (shells-de.bmp: 5 states à 45×45, background made transparent)

@MainActor
enum SharkShells {
    static let free: NSImage? = frame(0)
    static let taken: NSImage? = frame(2)

    private static func frame(_ index: Int) -> NSImage? {
        guard let img = CT1Games.image("shells.png"),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width / 5, h = cg.height
        guard let crop = cg.cropping(to: CGRect(x: index * w, y: 0, width: w, height: h)),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let raw = ctx.data else { return nil }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = raw.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let bg = (Int(px[0]), Int(px[1]), Int(px[2]))
        func isBG(_ i: Int) -> Bool {
            abs(Int(px[i * 4]) - bg.0) + abs(Int(px[i * 4 + 1]) - bg.1) + abs(Int(px[i * 4 + 2]) - bg.2) < 36
        }
        // Flood fill from the border so that light pixels inside the shell stay opaque.
        var seen = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
        for y in 0..<h { stack.append(y * w); stack.append(y * w + w - 1) }
        while let i = stack.popLast() {
            if seen[i] || !isBG(i) { continue }
            seen[i] = true
            for k in 0..<4 { px[i * 4 + k] = 0 }
            let x = i % w, y = i / w
            if x > 0 { stack.append(i - 1) }
            if x < w - 1 { stack.append(i + 1) }
            if y > 0 { stack.append(i - w) }
            if y < h - 1 { stack.append(i + w) }
        }
        guard let out = ctx.makeImage() else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: w, height: h))
    }
}

// MARK: - Main dialog (IDD_MFCZAHLENHAI_DIALOG)

struct CT1SharkView: View {
    @ObservedObject var model: SharkGameModel

    private static let leftWidth: CGFloat = 584
    private static let lightBlue = Color(red: 213 / 255, green: 227 / 255, blue: 241 / 255)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                topArea.frame(width: Self.leftWidth, height: 262)
                shellArea.frame(width: Self.leftWidth)
                bottomArea.frame(width: Self.leftWidth, height: 92)
            }
            rightColumn.frame(width: 112)
        }
        .padding(10)
        .sheet(item: $model.sheet) { s in
            switch s {
            case .options: SharkOptionsView(model: model)
            case .rules: SharkRulesView { model.sheet = nil }
            case .summary(let sum): SharkSummaryView(summary: sum) { model.summaryClosed(writeFile: $0) }
            }
        }
    }

    // MARK: Picture / game history table

    @ViewBuilder private var topArea: some View {
        if model.playing {
            GroupBox(label: Text(SharkText.listGroupBox)) { historyTable }
        } else if let img = CT1Games.image(SharkGameModel.pictures[model.pictureIndex]) {
            Image(nsImage: img).resizable().scaledToFill()
                .frame(width: Self.leftWidth, height: 262).clipped()
                .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
        } else {
            Color.black
        }
    }

    private var historyTable: some View {
        let widths = SharkText.columnWidths
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { j in
                    Text(SharkText.columns[j])
                        .font(.system(size: 11))
                        .multilineTextAlignment(j == 0 ? .leading : .center)
                        .frame(width: widths[j], height: 32, alignment: j == 0 ? .leading : .center)
                        .padding(.leading, j == 0 ? 2 : 0)
                        .overlay(Rectangle().frame(width: 1).foregroundColor(Color.gray.opacity(0.5)), alignment: .trailing)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.black)
            .background(Color(white: 0.93))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.6)), alignment: .bottom)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.rows) { r in
                            HStack(spacing: 0) {
                                ForEach(0..<6, id: \.self) { j in
                                    Text(r.cells[j])
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                        .frame(width: widths[j] - 6, alignment: j == 0 ? .leading : .trailing)
                                        .padding(.horizontal, 3)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(height: 17)
                            .foregroundColor(.black)
                            .background(r.id % 2 == 1 ? Self.lightBlue : Color.white)
                            .id(r.id)
                        }
                    }
                }
                .background(Color.white)
                .onChange(of: model.rows.count) { _, _ in
                    if let last = model.rows.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onAppear { if let last = model.rows.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .overlay(Rectangle().stroke(Color.gray.opacity(0.6)))
    }

    // MARK: Shell field (Muschelfeld)

    private var shellArea: some View {
        GroupBox(label: Text(model.shellStyle ? SharkText.shellGroupBox : SharkText.normalGroupBox)) {
            VStack(alignment: .leading, spacing: 4) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: model.tabCount > 9) {
                        LazyHStack(spacing: 0) {
                            ForEach(0..<model.tabCount, id: \.self) { i in
                                Button { model.tab = i } label: {
                                    Text(model.tabTitle(i))
                                        .font(.system(size: 11))
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(model.tab == i ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .windowBackgroundColor))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(model.tab == i ? 0.9 : 0.45)))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(i)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 26)
                    .onChange(of: model.tab) { _, t in proxy.scrollTo(t) }
                }
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<10, id: \.self) { col in
                                shellButton(model.tab * SharkGameModel.buttonsPerTab + row * 10 + col + 1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: model.limit) { _, _ in if model.tab >= model.tabCount { model.tab = 0 } }
    }

    @ViewBuilder private func shellButton(_ n: Int) -> some View {
        if n > model.limit {
            Color.clear.frame(width: 47, height: 44)
        } else {
            let free = model.game.owner[n] == .free
            Button { model.pick(n) } label: {
                if model.shellStyle {
                    ZStack {
                        if let img = free ? SharkShells.free : SharkShells.taken {
                            Image(nsImage: img).resizable().frame(width: 45, height: 45)
                        }
                        Text("\(n)")
                            .font(.custom("Arial", size: 19))
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .foregroundColor(free ? Color(red: 1, green: 1, blue: 0) : Color(white: 0.55))
                            .shadow(color: free ? .black.opacity(0.55) : .clear, radius: 0.6)
                            .frame(width: 44)
                    }
                    .frame(width: 47, height: 44)
                    .contentShape(Rectangle())
                } else {
                    Text("\(n)")
                        .font(.custom("Arial", size: 20))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(width: 41, height: 34)
                }
            }
            .buttonStyle(ShellButtonStyle(shells: model.shellStyle))
            .disabled(!free)
            .help(model.showToolTips && free ? model.toolTip(for: n) : "")
        }
    }

    // MARK: Settings for a new game / LED score

    @ViewBuilder private var bottomArea: some View {
        if model.playing {
            CT1SevenSegmentDisplay(text: model.ledText)
                .frame(height: 86)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.6)))
        } else {
            GroupBox(label: Text("Settings for a new game")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Number stack from 1 to:")
                        TextField("", text: $model.limitText)
                            .frame(width: 64)
                            .disabled(model.inputLocked)
                            .onSubmit { model.confirmLimit() }
                            .onChange(of: model.limitText) { _, v in
                                let f = String(v.filter(\.isNumber).prefix(5))
                                if f != v { model.limitText = f }
                            }
                        Button("OK") { model.confirmLimit() }
                            .disabled(model.inputLocked)
                            .help(SharkText.ttOK)
                    }
                    Text(model.sumText).font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
        }
    }

    // MARK: Button column

    private func columnButton(_ title: String, tall: Bool = true, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: tall ? 26 : 18)
        }
        .help(help)
    }

    private var rightColumn: some View {
        GroupBox {
            VStack(spacing: 8) {
                columnButton("Rules of the game", help: SharkText.ttRules) { model.sheet = .rules }
                columnButton("Help", help: SharkText.ttHelp) { CT1Games.showSharkHelp() }
                    .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(UInt16(NSF1FunctionKey))!)), modifiers: [])
                columnButton("Change style", tall: false, help: SharkText.ttSwitchStyle) { model.toggleStyle() }
                    .keyboardShortcut("c", modifiers: [.shift, .option])
                Spacer(minLength: 20)
                Text("Elapsed time:").font(.callout)
                Text(model.timeText).font(.system(.body, design: .monospaced))
                Spacer(minLength: 16)
                columnButton("Shark food", help: model.restToolTip) { model.feedShark() }
                    .disabled(model.restNumbers.isEmpty)
                columnButton("Game options", help: SharkText.ttOption) { model.sheet = .options }
                HStack(spacing: 14) {
                    Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!model.canUndo).help(SharkText.ttUndo)
                    Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(!model.canRedo).help(SharkText.ttRedo)
                }
                .padding(.vertical, 4)
                columnButton("Load", tall: false, help: SharkText.ttLoad) { model.loadGame() }
                    .keyboardShortcut("l", modifiers: [.shift, .option])
                columnButton("Save", tall: false, help: SharkText.ttSave) { model.saveGame() }
                    .keyboardShortcut("s", modifiers: [.shift, .option])
                Spacer(minLength: 16)
                columnButton("New game", help: SharkText.ttStartNew) { model.newGame() }
                columnButton("Exit", help: SharkText.ttEnd) { model.endProgram() }
            }
            .padding(.vertical, 6)
        }
        .frame(height: 460)
    }
}

private struct ShellButtonStyle: ButtonStyle {
    let shells: Bool
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        if shells {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
        } else {
            configuration.label
                .foregroundColor(enabled ? .primary : .secondary)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlColor)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.6)))
                .frame(width: 47, height: 44)
        }
    }
}

// MARK: - Rules (IDD_GAME_RULES)

struct SharkRulesView: View {
    let close: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Text("Game rules  / game description").font(.headline)
            ScrollView {
                Text(SharkText.rules + SharkText.rules2)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
            Button("Back", action: close).keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .frame(width: 820, height: 500)
    }
}

// MARK: - Game summary (IDD_GAME_SUMMARY)

struct SharkSummaryView: View {
    let summary: SharkSummary
    let close: (Bool) -> Void
    @CTState private var save = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.headline).font(.title3.weight(.semibold))
            Text(summary.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Back to the game") { close(save) }.keyboardShortcut(.defaultAction)
                Spacer()
            }
            GroupBox(label: Text("Save the result as summary?")) {
                Picker("", selection: $save) {
                    Text(SharkText.radioEdit1(summary.fileName, summary.folder))
                        .fixedSize(horizontal: false, vertical: true).tag(true)
                    Text("No.").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
        }
        .padding(16)
        .frame(width: 540)
    }
}

// MARK: - Game options (IDD_DIALOG1)

private struct SharkResult: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SharkOptionsView: View {
    @ObservedObject var model: SharkGameModel
    @CTState private var tab = 0
    @CTState private var calculate = true
    @CTState private var askAlgorithm = false
    @CTState private var search: SharkSearch?
    @CTState private var result: SharkResult?
    @CTState private var showPrecalculated = false

    var body: some View {
        VStack(spacing: 10) {
            Text(SharkText.optionsHead)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            TabView(selection: $tab) {
                welcome.tabItem { Text("Welcome") }.tag(0)
                standard.tabItem { Text("Standard") }.tag(1)
                maxPoints.tabItem { Text("Maximum score") }.tag(2)
                accelerators.tabItem { Text("Shortcuts") }.tag(3)
            }
            .frame(height: 340)
            Button("To the game") {
                model.sheet = nil
                model.updateTitle()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .frame(width: 560)
        .alert(SharkText.numberShark, isPresented: $askAlgorithm) {
            Button("Yes") { startSearch(backtracking: true) }
            Button("No") { startSearch(backtracking: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(SharkText.selectSearchAlgorithm)
        }
        .alert(item: $result) { r in
            Alert(title: Text(r.title), message: Text(r.message), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $search) { s in SharkSearchProgressView(search: s) }
        .sheet(isPresented: $showPrecalculated) { SharkPrecalculatedView { showPrecalculated = false } }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(SharkText.gameIdea)
            Text(SharkText.infoText)
            Text(SharkText.disclaimer)
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func optionBox(_ text: String, _ value: Binding<Bool>) -> some View {
        GroupBox {
            HStack(alignment: .top) {
                Text(text).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Toggle("", isOn: value).labelsHidden()
            }
            .padding(4)
        }
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox {
                HStack {
                    Text("Your name:")
                    TextField("", text: $model.playerName)
                }
                .padding(4)
            }
            optionBox(SharkText.optionsToolTips, $model.showToolTips)
            optionBox(SharkText.optionsShowDialog, $model.showOptionsAtStart)
            optionBox(SharkText.optionsShowNumbers, $model.rememberLimit)
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private var maxPoints: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(SharkText.optionsMaxPoints(CT1Games.sep(model.limit)))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .center) {
                        Picker("", selection: $calculate) {
                            Text(SharkText.tabRadio1).tag(true)
                            Text(SharkText.tabRadio2).tag(false)
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        Spacer()
                        Button("Start") {
                            if calculate { askAlgorithm = true } else { showPrecalculated = true }
                        }
                        .controlSize(.large)
                    }
                }
                .padding(6)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private var accelerators: some View {
        ScrollView {
            Text(SharkText.accelerators)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private func startSearch(backtracking: Bool) {
        let s = SharkSearch(backtracking: backtracking, limit: model.limit)
        s.onFinish = { title, message in
            search = nil
            guard !message.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                result = SharkResult(title: title, message: message)
            }
        }
        search = s
        s.begin()
    }
}

// MARK: - Search progress (IDD_SEARCH_PROGRESS)

struct SharkSearchProgressView: View {
    @ObservedObject var search: SharkSearch

    var body: some View {
        VStack(spacing: 12) {
            Text("Search Progress").font(.headline)
            Text(SharkText.searchProgress1(search.algorithmName, search.limit))
                .fixedSize(horizontal: false, vertical: true)
            Text(SharkText.searchProgress2(search.elapsed))
            ProgressView().progressViewStyle(.linear)
            Text(SharkText.searchProgressInfo)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Cancel") { search.cancel() }.keyboardShortcut(.cancelAction)
        }
        .padding(16)
        .frame(width: 340)
    }
}

// MARK: - Precalculated scores (IDD_SHOW_PRECALCULATED_SCORES[_IN_DETAIL])

extension SharkGameDataBlock: Identifiable { var id: Int { limit } }

struct SharkPrecalculatedView: View {
    let close: () -> Void
    @CTState private var selection: Int?
    @CTState private var showDetails = false
    private let blocks = SharkGameData.sorted

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Show precalculated scores").font(.headline)
            Text(SharkText.precalculatedIntro(SharkGameData.provedCount, blocks.count))
                .fixedSize(horizontal: false, vertical: true)
            Table(blocks, selection: $selection) {
                TableColumn("Number") { Text(String($0.limit)) }
                TableColumn("Result") { Text($0.score) }
                TableColumn("Result optimal?") { Text($0.proved ? "Proven" : "Unknown") }
            }
            .frame(height: 260)
            HStack {
                Button("Show details") { showDetails = true }
                Spacer()
                Button("Close", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 400)
        .sheet(isPresented: $showDetails) { SharkPrecalculatedDetailView { showDetails = false } }
    }
}

struct SharkPrecalculatedDetailView: View {
    let close: () -> Void
    @CTState private var text: String = {
        var t = ""
        for b in SharkGameData.sorted {
            t += "Number: \(b.limit)\nResult: \(b.score)\nResult optimal? \(b.proved ? "Proven" : "Unknown")\n"
            t += "Sequence length: \(b.sequenceLength)\nSequence: \(b.sequence)\n\n"
        }
        return t
    }()

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("Show precalculated scores in detail").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: .constant(text))
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 520, minHeight: 380)
            Button("Close", action: close).keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }
}
