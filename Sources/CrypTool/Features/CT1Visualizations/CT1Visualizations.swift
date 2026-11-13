import AppKit
import SwiftUI

/// Native replacements for the CT1 visualisations that were separate programs in CT1
/// (ANIMAL animations, Flash animations, Java applets and the challenge-response demo).
///
/// Every `open…` function (declared in an extension next to its view) opens a tool window via
/// `WindowPresenter.tool`.
@MainActor
enum CT1Visualizations {}

// MARK: - Step player (play / pause / step / back / speed)

/// Drives a step-by-step animation. `index` is the currently shown step (0-based).
@MainActor
final class StepPlayer: ObservableObject {
    @Published var index = 0
    @Published private(set) var isPlaying = false
    /// Speed factor (0.25 … 4); the auto-play interval is `baseInterval / speed`.
    @Published var speed: Double = 1
    @Published private(set) var count: Int

    /// Seconds per step at speed 1.
    var baseInterval: Double
    /// Optional per-step weight (e.g. 2 = show this step twice as long while playing).
    var weight: ((Int) -> Double)?

    private var timer: Timer?

    init(count: Int, baseInterval: Double = 1.5) {
        self.count = max(1, count)
        self.baseInterval = baseInterval
    }

    var canBack: Bool { index > 0 }
    var canForward: Bool { index < count - 1 }

    /// Duration of the transition animation between two steps.
    var transitionDuration: Double { min(0.6, 0.45 / max(0.25, speed)) }

    func reset(count: Int) {
        pause()
        self.count = max(1, count)
        index = 0
    }

    func next() { if canForward { index += 1 } }
    func back() { pause(); if canBack { index -= 1 } }
    func first() { pause(); index = 0 }
    func last() { pause(); index = count - 1 }
    func go(to i: Int) { pause(); index = min(max(0, i), count - 1) }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        if !canForward { index = 0 }
        isPlaying = true
        schedule()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func schedule() {
        timer?.invalidate()
        let w = weight?(index) ?? 1
        let t = Timer(timeInterval: max(0.05, baseInterval * w / max(0.25, speed)), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isPlaying else { return }
        if canForward {
            index += 1
            if canForward { schedule() } else { pause() }
        } else {
            pause()
        }
    }
}

/// A named section of an animation (CT1/ANIMAL "label").
struct StepChapter: Hashable {
    let title: String
    let step: Int
}

/// Control bar: ⏮ ◀ ▶/⏸ ▶ ⏭, step counter, speed slider and optional chapter menu.
struct StepControls: View {
    @ObservedObject var player: StepPlayer
    var chapters: [StepChapter] = []

    private var currentChapter: Int {
        var c = 0
        for (i, ch) in chapters.enumerated() where ch.step <= player.index { c = i }
        return c
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                Button { player.first() } label: { Image(systemName: "backward.end.fill") }
                    .help("Go to start")
                Button { player.back() } label: { Image(systemName: "backward.frame.fill") }
                    .help("One step back")
                    .disabled(!player.canBack)
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 16)
                }
                .help(player.isPlaying ? "Pause" : "Play automatically")
                Button { player.pause(); player.next() } label: {
                    Label("Continue", systemImage: "forward.frame.fill")
                }
                .help("Next step (Return key)")
                .keyboardShortcut(.defaultAction)
                .disabled(!player.canForward)
                Button { player.last() } label: { Image(systemName: "forward.end.fill") }
                    .help("Go to end")
            }
            Text("Step \(player.index + 1) of \(player.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 120, alignment: .leading)
            if chapters.count > 1 {
                Picker("Chapter", selection: Binding(get: { currentChapter }, set: { player.go(to: chapters[$0].step) })) {
                    ForEach(chapters.indices, id: \.self) { Text(chapters[$0].title).tag($0) }
                }
                .frame(maxWidth: 360)
            }
            Spacer(minLength: 8)
            Image(systemName: "tortoise").foregroundStyle(.secondary)
            Slider(value: Binding(get: { log2(player.speed) }, set: { player.speed = pow(2, $0) }), in: -2...2)
                .frame(width: 110)
                .help("Speed")
            Image(systemName: "hare").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onDisappear { player.pause() }
    }
}

// MARK: - Animated stage (native counterpart of an ANIMAL animation)

/// Colours of the stage elements (adapt to light/dark mode).
enum AnimColor: Hashable {
    case text, red, blue, green, gray, white, highlight, cell, cellAlt, orange, purple, clear, secondary

    var color: Color {
        switch self {
        case .text: return Color(nsColor: .labelColor)
        case .secondary: return Color(nsColor: .secondaryLabelColor)
        case .red: return Color(nsColor: .systemRed)
        case .blue: return Color(nsColor: .systemBlue)
        case .green: return Color(nsColor: .systemGreen)
        case .orange: return Color(nsColor: .systemOrange)
        case .purple: return Color(nsColor: .systemPurple)
        case .gray: return Color(nsColor: .tertiaryLabelColor)
        case .white: return Color(nsColor: .textBackgroundColor)
        case .highlight: return Color.yellow.opacity(0.75)
        case .cell: return Color.gray.opacity(0.28)
        case .cellAlt: return Color.accentColor.opacity(0.18)
        case .clear: return .clear
        }
    }
}

/// One element on the stage. Identity (`id`) is kept across steps, so position and colour
/// changes are animated (like ANIMAL's "Move" and "ColorChange"); appearing/disappearing
/// elements fade.
struct AnimItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case text(String)
        case box
        case line([CGPoint], arrow: Bool)
    }

    var id: String
    var kind: Kind
    /// Top-left corner (stage coordinates). Not used for lines.
    var origin: CGPoint = .zero
    /// Box size; for texts an optional frame (text centred in it), `.zero` = natural size.
    var size: CGSize = .zero
    var color: AnimColor = .text
    var fill: AnimColor = .cell
    var fontSize: CGFloat = 14
    var bold = false
    var mono = false
    var z: Double = 0
    /// Present but invisible (start position of a spawned copy).
    var hidden = false
}

/// Builds the frames of an animation with ANIMAL semantics: elements are added, moved,
/// recoloured and removed; `commit()` takes a snapshot that becomes one step.
final class AnimScriptBuilder {
    private var items: [String: AnimItem] = [:]
    private var order: [String] = []
    private(set) var frames: [[AnimItem]] = []
    private(set) var chapters: [StepChapter] = []
    private var pendingChapter: String?

    init() {}

    var snapshot: [AnimItem] { order.compactMap { items[$0] } }

    func contains(_ id: String) -> Bool { items[id] != nil }
    func item(_ id: String) -> AnimItem? { items[id] }

    func put(_ item: AnimItem) {
        if items[item.id] == nil { order.append(item.id) }
        items[item.id] = item
    }

    @discardableResult
    func text(_ id: String, _ s: String, x: CGFloat, y: CGFloat, size: CGFloat = 14, color: AnimColor = .text,
              bold: Bool = false, mono: Bool = false, width: CGFloat = 0, height: CGFloat = 0, z: Double = 2) -> String {
        put(AnimItem(id: id, kind: .text(s), origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height),
                     color: color, fontSize: size, bold: bold, mono: mono, z: z))
        return id
    }

    /// A letter/number centred in a cell (used for alphabets, matrices …).
    @discardableResult
    func cellText(_ id: String, _ s: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, size: CGFloat = 14,
                  color: AnimColor = .text, bold: Bool = false, mono: Bool = true, z: Double = 3) -> String {
        text(id, s, x: x, y: y, size: size, color: color, bold: bold, mono: mono, width: w, height: h, z: z)
    }

    @discardableResult
    func box(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, fill: AnimColor = .cell,
             stroke: AnimColor = .gray, z: Double = 0) -> String {
        put(AnimItem(id: id, kind: .box, origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h),
                     color: stroke, fill: fill, z: z))
        return id
    }

    @discardableResult
    func line(_ id: String, _ points: [CGPoint], arrow: Bool = true, color: AnimColor = .text, z: Double = 1) -> String {
        put(AnimItem(id: id, kind: .line(points, arrow: arrow), color: color, z: z))
        return id
    }

    func remove(_ ids: String...) { remove(ids) }
    func remove(_ ids: [String]) { for id in ids { items[id] = nil; order.removeAll { $0 == id } } }
    /// Removes all elements whose id starts with `prefix`.
    func removeAll(prefix: String) {
        let ids = order.filter { $0.hasPrefix(prefix) }
        remove(ids)
    }

    func move(_ id: String, x: CGFloat, y: CGFloat) { items[id]?.origin = CGPoint(x: x, y: y) }
    func setSize(_ id: String, w: CGFloat, h: CGFloat) { items[id]?.size = CGSize(width: w, height: h) }
    func setZ(_ id: String, _ z: Double) { items[id]?.z = z }
    func setColor(_ id: String, _ c: AnimColor) { items[id]?.color = c }
    func setColor(_ ids: [String], _ c: AnimColor) { for id in ids { items[id]?.color = c } }
    func setFill(_ id: String, _ c: AnimColor) { items[id]?.fill = c }
    func setText(_ id: String, _ s: String) { items[id]?.kind = .text(s) }

    /// Adds an element to the current scene *and* to the previously committed frame, so that a
    /// following `move` is animated from this start position (ANIMAL's "Move … via …").
    func spawn(_ item: AnimItem) {
        put(item)
        var ghost = item
        ghost.hidden = true
        if !frames.isEmpty { frames[frames.count - 1].append(ghost) }
    }

    /// Spawns a copy of an existing element (same position and look) under a new id.
    @discardableResult
    func spawnCopy(of id: String, as newID: String, z: Double? = nil) -> String {
        guard var it = items[id] else { return newID }
        it.id = newID
        if let z { it.z = z }
        spawn(it)
        return newID
    }

    /// Marks the start of a chapter at the next committed frame.
    func chapter(_ title: String) { pendingChapter = title }

    /// Takes a snapshot of the current scene as the next step.
    func commit() {
        if let c = pendingChapter {
            chapters.append(StepChapter(title: c, step: frames.count))
            pendingChapter = nil
        }
        frames.append(snapshot)
    }
}

/// A complete animation: frames (steps), chapters and the logical stage size.
struct AnimScript {
    var frames: [[AnimItem]]
    var chapters: [StepChapter]
    var size: CGSize

    static let empty = AnimScript(frames: [[]], chapters: [], size: CGSize(width: 800, height: 600))

    init(frames: [[AnimItem]], chapters: [StepChapter], size: CGSize) {
        self.frames = frames.isEmpty ? [[]] : frames
        self.chapters = chapters
        self.size = size
    }

    init(_ b: AnimScriptBuilder, size: CGSize) {
        self.init(frames: b.frames, chapters: b.chapters, size: size)
    }
}

/// Renders one frame of an animation, scaled to the available space. Changes between frames
/// are animated.
struct AnimStage: View {
    let items: [AnimItem]
    let stageSize: CGSize
    let token: Int
    var duration: Double = 0.45

    var body: some View {
        GeometryReader { geo in
            let s = max(0.3, min(geo.size.width / stageSize.width, geo.size.height / stageSize.height))
            let dx = max(0, (geo.size.width - stageSize.width * s) / 2)
            ZStack(alignment: .topLeading) {
                ForEach(items) { item in
                    AnimItemView(item: item, scale: s)
                        .opacity(item.hidden ? 0 : 1)
                        .zIndex(item.z)
                        .transition(.opacity)
                }
            }
            .frame(width: stageSize.width * s, height: stageSize.height * s, alignment: .topLeading)
            .offset(x: dx)
            .animation(.easeInOut(duration: duration), value: token)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct AnimItemView: View {
    let item: AnimItem
    let scale: CGFloat

    var body: some View {
        switch item.kind {
        case .text(let s):
            let font = Font.system(size: item.fontSize * scale, weight: item.bold ? .bold : .regular,
                                   design: item.mono ? .monospaced : .default)
            if item.size.width > 0 {
                Text(s).font(font).foregroundStyle(item.color.color)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .frame(width: item.size.width * scale, height: max(item.size.height, item.fontSize * 1.3) * scale)
                    .offset(x: item.origin.x * scale, y: item.origin.y * scale)
            } else {
                Text(s).font(font).foregroundStyle(item.color.color)
                    .fixedSize()
                    .offset(x: item.origin.x * scale, y: item.origin.y * scale)
            }
        case .box:
            RoundedRectangle(cornerRadius: 2 * scale)
                .fill(item.fill.color)
                .overlay(RoundedRectangle(cornerRadius: 2 * scale).stroke(item.color.color, lineWidth: 1))
                .frame(width: item.size.width * scale, height: item.size.height * scale)
                .offset(x: item.origin.x * scale, y: item.origin.y * scale)
        case .line(let pts, let arrow):
            ArrowPath(points: pts.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }, arrow: arrow, head: 7 * scale)
                .stroke(item.color.color, style: StrokeStyle(lineWidth: max(1, 1.4 * scale), lineCap: .round, lineJoin: .round))
        }
    }
}

/// Polyline with an optional arrow head at the last point.
struct ArrowPath: Shape {
    var points: [CGPoint]
    var arrow: Bool
    var head: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for q in points.dropFirst() { p.addLine(to: q) }
        if arrow, points.count >= 2 {
            let a = points[points.count - 2], b = points[points.count - 1]
            let ang = atan2(b.y - a.y, b.x - a.x)
            for d in [CGFloat.pi * 0.85, -CGFloat.pi * 0.85] {
                p.move(to: b)
                p.addLine(to: CGPoint(x: b.x + head * cos(ang + d), y: b.y + head * sin(ang + d)))
            }
        }
        return p
    }
}

/// Window content for a scripted animation: optional input area, stage, controls.
struct ScriptedAnimationView<Inputs: View>: View {
    let script: AnimScript
    @ObservedObject var player: StepPlayer
    @ViewBuilder var inputs: Inputs

    var body: some View {
        VStack(spacing: 0) {
            inputs
            Divider()
            AnimStage(items: script.frames[min(player.index, script.frames.count - 1)],
                      stageSize: script.size, token: player.index, duration: player.transitionDuration)
            Divider()
            StepControls(player: player, chapters: script.chapters)
        }
    }
}

/// Input row shown above an animation ("Eigene Eingabe").
struct AnimationInputBar<Fields: View>: View {
    var note: String? = nil
    let rebuild: () -> Void
    let resetToExample: () -> Void
    @ViewBuilder var fields: Fields

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                fields
                Spacer(minLength: 4)
                Button("Create animation", action: rebuild)
                Button("CT1 example", action: resetToExample)
                    .help("Resets the inputs to the example of the CT1 animation")
            }
            if let note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Small helpers

extension Array where Element == UInt8 {
    /// "16 BD 40 94 …"
    var ct1Hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}

/// Bits of a byte array, most significant bit first.
func ct1Bits(_ bytes: [UInt8]) -> [Int] {
    bytes.flatMap { b in (0..<8).map { Int((b >> (7 - UInt8($0))) & 1) } }
}

/// Bytes from bits (MSB first, length padded to a multiple of 8).
func ct1Bytes(_ bits: [Int]) -> [UInt8] {
    stride(from: 0, to: bits.count, by: 8).map { i in
        var v: UInt8 = 0
        for j in 0..<8 { v = (v << 1) | UInt8(i + j < bits.count ? bits[i + j] & 1 : 0) }
        return v
    }
}
