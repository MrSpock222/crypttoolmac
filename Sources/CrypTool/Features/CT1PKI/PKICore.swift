import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

// Shared building blocks of the CT1 PKI dialogs: byte/text helpers (CT1 writes its
// headers in Windows-1252), number bases, timing messages, modal sub-dialogs, the
// column key list with type filter, PIN access and certificate texts.

enum PKIText {
    /// CT1 strings are Windows-1252 encoded.
    static func cp1252(_ s: String) -> [UInt8] {
        s.data(using: .windowsCP1252).map { [UInt8]($0) } ?? Array(s.utf8)
    }

    /// Text field contents as bytes like CT1 (Windows-1252, UTF-8 for characters outside it).
    static func bytes(_ s: String) -> [UInt8] { cp1252(s) }

    static func string(_ b: [UInt8]) -> String { TextCoding.string(from: b) }

    /// Index of `pattern` in `data` at or after `from`.
    static func find(_ pattern: [UInt8], in data: [UInt8], from: Int = 0) -> Int? {
        guard !pattern.isEmpty, data.count >= pattern.count, from <= data.count - pattern.count else { return nil }
        let first = pattern[0]
        var i = from
        let last = data.count - pattern.count
        while i <= last {
            if data[i] == first {
                var ok = true
                for j in 1..<pattern.count where data[i + j] != pattern[j] { ok = false; break }
                if ok { return i }
            }
            i += 1
        }
        return nil
    }

    /// Finds a CT1 label written either in Windows-1252 (CT1) or UTF-8. Returns (start, length).
    static func findLabel(_ label: String, in data: [UInt8], from: Int = 0) -> (Int, Int)? {
        var best: (Int, Int)?
        for enc in Set([cp1252(label), Array(label.utf8)]) {
            if let i = find(enc, in: data, from: from), best == nil || i < best!.0 { best = (i, enc.count) }
        }
        return best
    }

    /// CT1's double_fmt(duration, 3); the English program uses a decimal point (IDS_STRING_COMMA).
    static func seconds(_ t: TimeInterval) -> String {
        String(format: "%.3f", t)
    }

    /// Byte string as "A1 B2 C3" (CT1 hex dump of keys and hash values).
    static func hex(_ b: [UInt8]) -> String { Hex.encode(b, separator: " ") }
}

/// Number bases of CT1's radio groups "Zahlensystem der Parameterdarstellung".
enum PKINumberBase: Int, CaseIterable, Identifiable {
    case octal, decimal, hex
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .octal: return "Octal"
        case .decimal: return "Decimal"
        case .hex: return "Hexadecimal"
        }
    }
    var radix: Int { [8, 10, 16][rawValue] }
    func format(_ v: BigUInt) -> String { v.toString(radix: radix) }
}

// MARK: - Small UI helpers

/// CT1 style group box with a caption.
struct PKIGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        } label: {
            if !title.isEmpty { Text(title) }
        }
    }
}

/// Radio buttons for the number base.
struct PKIBasePicker: View {
    @Binding var base: PKINumberBase
    var body: some View {
        Picker("", selection: $base) {
            ForEach(PKINumberBase.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.radioGroup)
        .horizontalRadioGroupLayout()
        .labelsHidden()
    }
}

/// "Hilfe" button opening the page of a CT1 menu command.
struct PKIHelpButton: View {
    let action: CTAction
    var body: some View {
        Button("Help") { HelpCenter.show(action: action) }
    }
}

/// Runs SwiftUI dialogs application-modally (CT1's DoModal for sub-dialogs).
@MainActor
enum PKIModal {
    private final class Delegate: NSObject, NSWindowDelegate {
        var onClose: () -> Void = {}
        func windowWillClose(_ notification: Notification) { onClose() }
    }

    /// Shows `content` modally; returns after `close` was called or the window was closed.
    static func run<V: View>(title: String, @ViewBuilder content: (@escaping () -> Void) -> V) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = title
        panel.isReleasedWhenClosed = false
        let delegate = Delegate()
        var finished = false
        let finish = {
            if finished { return }
            finished = true
            NSApp.stopModal()
        }
        delegate.onClose = finish
        panel.delegate = delegate
        let host = NSHostingController(rootView: AnyView(content({ finish(); panel.orderOut(nil) })
            .environmentObject(AppSettings.shared)))
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host
        let fit = host.view.fittingSize
        if fit.width > 10, fit.height > 10 { panel.setContentSize(fit) }
        panel.center()
        NSApp.runModal(for: panel)
        panel.delegate = nil
        panel.orderOut(nil)
        withExtendedLifetime(delegate) {}
    }

    /// Information message box (CT1 AfxMessageBox with MB_ICONINFORMATION).
    static func info(_ text: String) {
        let a = NSAlert()
        a.alertStyle = .informational
        a.messageText = "CrypTool"
        a.informativeText = text
        a.runModal()
    }

    static func warning(_ text: String) {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = "CrypTool"
        a.informativeText = text
        a.runModal()
    }
}

// MARK: - Key list with columns (CT1 SysListView32 of the PSE dialogs)

/// Filter state of "Aufgelistete Schlüsseltypen:".
struct PKIKeyFilter: Equatable {
    var rsa = true
    var dsa = true
    var ec = true
    static let rsaOnly = PKIKeyFilter(rsa: true, dsa: false, ec: false)
    static let ecOnly = PKIKeyFilter(rsa: false, dsa: false, ec: true)
    func accepts(_ k: StoredKey) -> Bool {
        switch k.type.kind {
        case .rsa: return rsa
        case .dsa: return dsa
        case .ec: return ec
        }
    }
}

/// Check boxes "RSA-Schlüssel" / "DSA-Schlüssel" / "EC-Schlüssel".
struct PKIKeyFilterBox: View {
    @Binding var filter: PKIKeyFilter
    var hyphen = true
    var body: some View {
        PKIGroup("Listed key types:") {
            Toggle(hyphen ? "RSA keys" : "RSA keys", isOn: $filter.rsa)
            Toggle(hyphen ? "DSA keys" : "DSA keys", isOn: $filter.dsa)
            Toggle(hyphen ? "EC keys" : "EC keys", isOn: $filter.ec)
        }
        .fixedSize()
    }
}

/// Sortable table: Name | Vorname | Schlüsseltyp | Schlüsselkennung | Erstellt am | Interne ID-Nr.
struct PKIKeyTable: View {
    @ObservedObject private var store = KeyStore.shared
    @Binding var selection: UUID?
    var filter: PKIKeyFilter
    var minHeight: CGFloat = 160
    var onDoubleClick: ((StoredKey) -> Void)? = nil
    @CTState private var order: [KeyPathComparator<PKIKeyRow>] = [KeyPathComparator(\.name)]

    init(selection: Binding<UUID?>, filter: PKIKeyFilter, minHeight: CGFloat = 160, onDoubleClick: ((StoredKey) -> Void)? = nil) {
        self._selection = selection
        self.filter = filter
        self.minHeight = minHeight
        self.onDoubleClick = onDoubleClick
    }

    var rows: [PKIKeyRow] {
        store.keys.filter(filter.accepts).map(PKIKeyRow.init).sorted(using: order)
    }

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $order) {
            TableColumn("Last name", value: \.name)
            TableColumn("First name", value: \.firstName)
            TableColumn("Key type", value: \.keyType)
            TableColumn("Key identifier", value: \.label)
            TableColumn("Created", value: \.created) { Text($0.createdString) }
            TableColumn("Internal ID no.", value: \.internalID)
        }
        .contextMenu(forSelectionType: UUID.self) { _ in } primaryAction: { ids in
            if let id = ids.first, let k = store.key(id: id) { onDoubleClick?(k) }
        }
        .frame(minHeight: minHeight)
        .onChange(of: filter) { _, _ in
            if let s = selection, !rows.contains(where: { $0.id == s }) { selection = nil }
        }
    }
}

struct PKIKeyRow: Identifiable {
    let id: UUID
    let name: String
    let firstName: String
    let keyType: String
    let label: String
    let created: Date
    let createdString: String
    let internalID: String
    init(_ k: StoredKey) {
        id = k.id; name = k.lastName; firstName = k.firstName; keyType = k.type.displayName
        label = k.label; created = k.created; createdString = k.createdString; internalID = k.internalID
    }
}

// MARK: - PIN access (CT1 IDD_PIN_ACCESS "Autorisierung")

@MainActor
enum PKIPinAccess {
    /// Asks for the PIN of `key`; nil if cancelled.
    static func ask(for key: StoredKey) -> String? {
        let a = NSAlert()
        a.messageText = "Authorization"
        a.informativeText = "Key identifier:\n\(key.ct1Identifier)\n\nThe private key is protected by your PIN code.\n\nEnter the PIN code:"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        a.accessoryView = field
        a.addButton(withTitle: "Continue")
        a.addButton(withTitle: "Cancel")
        a.window.initialFirstResponder = field
        return a.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    /// Opens the private key; shows CT1's "Falscher PIN-Code eingegeben." on failure.
    static func open(_ key: StoredKey, pin: String) -> PrivateKeyMaterial? {
        do { return try KeyStore.shared.privateKey(of: key, pin: pin) } catch {
            PKIModal.warning("Incorrect PIN code entered.")
            return nil
        }
    }
}

// MARK: - Certificate data (CT1 IDD_SHOW_CERTIFICATE "Zertifikatsdaten")

enum PKICertificate {
    static func text(_ k: StoredKey) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        let until = Calendar.current.date(byAdding: .year, value: 1, to: k.created) ?? k.created
        var s = "Your Certificate Data:\n\n"
        s += "Certificate:\n"
        s += "   Version:               1\n"
        s += "   Serial number:         \(k.internalID)\n"
        let alg: String
        switch k.type.kind {
        case .rsa: alg = "md5WithRsaEncryption"
        case .dsa: alg = "dsaWithSHA1"
        case .ec: alg = "ecdsa-with-SHA1"
        }
        s += "   Signature algorithm:   \(alg)\n"
        s += "   Issuer:                CN=CrypTool CA, DC=cryptool, DC=org\n"
        s += "   Valid from:            \(f.string(from: k.created))\n"
        s += "   Valid until:           \(f.string(from: until))\n"
        s += "   Subject:               \(k.distinguishedName)\n"
        s += "   Key identifier:        \(k.ct1Identifier)\n\n"
        s += "Public key of the subject:\n"
        if let p = k.rsaPublic {
            s += "   Algorithm:    rsaEncryption (\(p.n.bitLength) bits)\n"
            s += "   Modulus N:    \(p.n.toString(radix: 16))\n"
            s += "   Exponent e:   \(p.e.toString(radix: 16))\n"
        }
        if let d = k.dsaParameters, let y = k.dsaPublic {
            s += "   Algorithm:    dsa (\(d.p.bitLength) bits)\n"
            s += "   p: \(d.p.toString(radix: 16))\n   q: \(d.q.toString(radix: 16))\n   g: \(d.g.toString(radix: 16))\n   y: \(y.toString(radix: 16))\n"
        }
        if let c = k.curve, case let .affine(x, y)? = k.ecPublic {
            s += "   Algorithm:    ecPublicKey (\(c.name))\n"
            s += "   Wx: \(x.toString(radix: 16))\n   Wy: \(y.toString(radix: 16))\n"
        }
        return s
    }

    @MainActor static func show(_ k: StoredKey) {
        PKIModal.run(title: "Certificate Data") { close in
            VStack(alignment: .leading, spacing: 10) {
                ResultBox(text: text(k), minHeight: 300)
                HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction); Spacer() }
            }
            .padding()
            .frame(width: 620)
        }
    }
}

// MARK: - Parameter dialogs

/// CT1 IDD_SHOW_KEY_PARAMETER "Öffentliche Parameter" (RSA: Modul/Exponent; DSA: p, q, g, y).
struct PKIPublicParameterView: View {
    let key: StoredKey
    let close: () -> Void
    @CTState private var base: PKINumberBase = .decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Public Parameters of: \(key.firstLast)").font(.headline)
            if let p = key.rsaPublic {
                Text("Modulus:")
                ResultBox(text: base.format(p.n), minHeight: 70)
                Text("Exponent:")
                ResultBox(text: base.format(p.e), minHeight: 26)
            }
            if let d = key.dsaParameters, let y = key.dsaPublic {
                ForEach([("Prime number p:", d.p), ("Prime number q:", d.q), ("Generator g:", d.g), ("Public value y:", y)], id: \.0) { item in
                    Text(item.0)
                    ResultBox(text: base.format(item.1), minHeight: 34)
                }
            }
            PKIGroup("Base for presentation of numbers") { PKIBasePicker(base: $base) }
            HStack {
                Spacer()
                Button("Back", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560)
    }
}

/// EC domain parameter table (CT1 "Parameter | Wert des Parameters | Bitlänge").
struct PKIECParameterTable: View {
    let rows: [(String, BigUInt)]
    let base: PKINumberBase
    var body: some View {
        let items = rows.enumerated().map { PKIParamRow(id: $0.offset, name: $0.element.0, value: base.format($0.element.1), bits: $0.element.1.bitLength) }
        Table(items) {
            TableColumn("Parameters") { Text($0.name) }.width(min: 90, ideal: 130)
            TableColumn("Value of the parameter") { Text($0.value).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
            TableColumn("Bit length") { Text("\($0.bits)") }.width(60)
        }
    }

    static func domainRows(_ c: EllipticCurve) -> [(String, BigUInt)] {
        [("a", c.a), ("b", c.b), ("p", c.p), ("x coordinates of G", c.gx), ("y coordinates of G", c.gy),
         ("k (cofactor)", c.h), ("r (order of G)", c.n)]
    }
}

struct PKIParamRow: Identifiable {
    let id: Int
    let name: String
    let value: String
    let bits: Int
}

/// CT1 IDD_SHOW_PUBLICKEY_EC / IDD_SHOW_PRIVATEKEY_EC: EC parameters with number base.
struct PKIECKeyView: View {
    let key: StoredKey
    let privateKey: BigUInt?
    let close: () -> Void
    @CTState private var base: PKINumberBase = .decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let c = key.curve {
                Text("Domain parameters of elliptic curve '\(c.name)':").font(.headline)
                PKIECParameterTable(rows: PKIECParameterTable.domainRows(c), base: base).frame(height: 190)
                Text("Public key W = (Wx, Wy) of \(key.firstLast):")
                if case let .affine(x, y)? = key.ecPublic {
                    PKIECParameterTable(rows: [("Wx", x), ("Wy", y)], base: base).frame(height: 80)
                }
                if let d = privateKey {
                    Text("Secret key s:")
                    PKIECParameterTable(rows: [("s", d)], base: base).frame(height: 56)
                }
            }
            PKIGroup("Base for presentation of numbers") { PKIBasePicker(base: $base) }
            HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction) }
        }
        .padding()
        .frame(width: 720)
    }
}
