import AppKit
import SwiftUI
import CTCommon

/// State of a CT1 progress dialog (`theApp.fs`: title, message with %d%% and "Restzeit", Abbrechen).
@MainActor
final class NTProgressModel: ObservableObject {
    @Published var fraction: Double = 0
    @Published var message = ""
    /// Message format: "%d" placeholders are not used – the closure builds the text from percent and remaining time.
    var format: (Int, String) -> String = { p, rest in "\(p)% erledigt.\nRestzeit: \(rest)" }
    let token = CancellationToken()
    private var start = Date()
    private var dismissAction: (() -> Void)?
    private(set) var isShown = false

    func update(_ f: Double) {
        fraction = max(0, min(1, f))
        message = format(Int((fraction * 100).rounded(.down)), remaining())
    }

    private func remaining() -> String {
        let elapsed = Date().timeIntervalSince(start)
        guard fraction > 0.0001 else { return "wird berechnet …" }
        let rest = elapsed * (1 - fraction) / fraction
        return ntRemainingTime(rest)
    }

    /// Shows the progress dialog as a sheet on `window`.
    func show(on window: NSWindow?, title: String) {
        start = Date()
        update(0)
        isShown = true
        WindowPresenter.sheet(on: window, title: title) { close in
            self.dismissAction = close
            return NTProgressSheet(model: self)
        }
    }

    func dismiss() {
        guard isShown else { return }
        isShown = false
        dismissAction?()
        dismissAction = nil
    }
}

/// Formats a remaining time like CT1's progress dialog (days / h:mm:ss).
func ntRemainingTime(_ seconds: Double) -> String {
    if !seconds.isFinite || seconds > 1e12 { return "unbekannt" }
    var s = Int(seconds.rounded())
    let years = s / (365 * 86400)
    if years >= 1 { return "\(years) Jahre" }
    let d = s / 86400; s %= 86400
    let h = s / 3600; s %= 3600
    let m = s / 60; s %= 60
    if d > 0 { return String(format: "%d Tage, %02d:%02d:%02d Stunden", d, h, m, s) }
    if h > 0 { return String(format: "%d:%02d:%02d Stunden", h, m, s) }
    if m > 0 { return String(format: "%d:%02d Minuten", m, s) }
    return "\(s) Sekunden"
}

struct NTProgressSheet: View {
    @ObservedObject var model: NTProgressModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.message).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: model.fraction)
            HStack {
                Spacer()
                Button("Abbrechen") {
                    model.token.cancel()
                    model.dismiss()
                }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

/// CT1 time format of the factorisation dialog (IDS_STRING_FMT_*).
func ntCT1Time(_ seconds: Double) -> String {
    let total = max(0, seconds)
    let whole = Int(total)
    let ms = Int(((total - Double(whole)) * 1000).rounded(.down))
    let d = whole / 86400
    let h = (whole % 86400) / 3600
    let m = (whole % 3600) / 60
    let s = whole % 60
    if d >= 1 { return String(format: "%4d Tage, %02d:%02d:%02d Stunden.", d, h, m, s).trimmingCharacters(in: .whitespaces) }
    if h >= 1 { return String(format: "%2d:%02d:%02d Stunden.", h, m, s).trimmingCharacters(in: .whitespaces) }
    if m >= 1 { return String(format: "%2d:%02d Minuten.", m, s).trimmingCharacters(in: .whitespaces) }
    return String(format: "%2d,%03d Sekunden.", s, ms).trimmingCharacters(in: .whitespaces)
}

/// Read-only result line as in CT1's "Ergebnis" edit fields.
struct NTReadOnlyText: View {
    let text: String
    var color: Color? = nil
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(color ?? .primary)
            .lineLimit(1).truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.vertical, 3)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}
