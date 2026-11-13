import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// Helpers shared by the CT1-aligned CRT dialogs (Astronomie, Hin-/Rücktransformation,
// Secret-Sharing mittels CRT) and the Shamir secret-sharing demo.

enum CRTUtil {
    /// Evaluates a formula field (CT1 CheckFormula/CEvalIntExpr: numbers and + - * / ^ ( )).
    static func formula(_ s: String) -> BigUInt? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if let v = BigUInt(t) { return v }
        if let v = try? BigExpression.evaluate(t), !v.isNegative { return v.magnitude }
        return nil
    }

    /// ES_NUMBER edit fields: keep digits only.
    static func digits(_ s: String) -> String { String(s.filter { $0.isASCII && $0.isNumber }) }

    /// CT1 CheckEdit: digits only, no leading zeros.
    static func digitsNoLeadingZeros(_ s: String) -> String {
        var d = digits(s)
        while d.first == "0" { d.removeFirst() }
        return d
    }

    /// CT1 "tausender": thousands separator IDS_STRING_PT (English: ",").
    static func thousands(_ s: String) -> String {
        var t = s
        var i = t.count - 3
        while i > 0 {
            t.insert(",", at: t.index(t.startIndex, offsetBy: i))
            i -= 3
        }
        return t
    }

    /// CT1 information message box (AfxMessageBox, MB_ICONINFORMATION).
    @MainActor static func message(_ text: String) {
        Alerts.info(text.replacingOccurrences(of: "\r\n", with: "\n"), title: "CrypTool")
    }

    /// Random prime from [lower, upper] (CT1 GetRandomPrime: random candidates, Miller-Rabin).
    static func randomPrime(_ lower: BigUInt, _ upper: BigUInt) -> BigUInt? {
        guard lower <= upper else { return nil }
        return Primality.randomPrime(in: lower...upper, method: .millerRabin)
    }
}

/// Enlarges the hosting tool window once so the CT1 dialog layout fits.
struct CRTWindowSizer: NSViewRepresentable {
    var minSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { apply(v) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    @MainActor private func apply(_ v: NSView) {
        guard let w = v.window else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { apply(v) }
            return
        }
        let cur = w.contentLayoutRect.size
        if cur.width < minSize.width || cur.height < minSize.height {
            w.setContentSize(CGSize(width: max(cur.width, minSize.width), height: max(cur.height, minSize.height)))
            w.center()
        }
    }
}

extension View {
    func crtMinWindowSize(_ w: CGFloat, _ h: CGFloat) -> some View {
        background(CRTWindowSizer(minSize: CGSize(width: w, height: h)).frame(width: 0, height: 0))
    }
}

/// Read-only CT1 edit field (single line scrolls horizontally, multi-line scrolls vertically).
struct CRTOutputField: View {
    var text: String
    var multiline = false
    var minHeight: CGFloat = 22
    var alignment: Alignment = .leading

    var body: some View {
        Group {
            if multiline {
                ScrollView {
                    Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading).padding(4)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(text.isEmpty ? " " : text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .lineLimit(1).fixedSize().padding(.horizontal, 4).padding(.vertical, 3)
                }
                .frame(maxWidth: .infinity, alignment: alignment)
            }
        }
        .frame(minHeight: minHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }
}

/// Group box with CT1 caption.
struct CRTGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) { content }.padding(4).frame(maxWidth: .infinity, alignment: .leading)
        } label: { Text(title) }
    }
}

/// Log/text window used by the CRT secret sharing (IDD_CRT_SECRETSHARING_LOG).
struct CRTLogSheet: View {
    var title: String
    var text: String
    var saveTitle: String
    var savedMessage: String
    var close: () -> Void
    @CTState private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ResultBox(text: text, minHeight: 300)
            HStack {
                Spacer()
                Button("Save") {
                    DocumentFactory.openResult(text: text.replacingOccurrences(of: "\r\n", with: "\n"), title: saveTitle)
                    saved = true
                    CRTUtil.message(savedMessage)
                    close()
                }.disabled(saved)
                Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(width: 600, height: 440)
    }
}
