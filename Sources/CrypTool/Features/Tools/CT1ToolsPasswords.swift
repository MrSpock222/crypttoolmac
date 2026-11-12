import AppKit
import SwiftUI
import CTCommon
import CTAnalysis

extension Notification.Name {
    /// Sets the password of an open "Passwort-Qualitätsmesser" window (object: String).
    static let ct1ToolsMeasurePassword = Notification.Name("ct1tools.measurePassword")
}

// MARK: - Password guidelines (CT1 IDD_PASSWORD_GUIDELINES, registry "PasswordGuidelines")

enum CT1ToolsPasswordGuidelines {
    private static let prefix = "ct1tools.pwguidelines."

    static func load() -> PasswordTools.Policy {
        let d = UserDefaults.standard
        return PasswordTools.Policy(minimumLength: d.object(forKey: prefix + "minLength") as? Int ?? 8,
                                    minimumDigits: d.object(forKey: prefix + "minDigits") as? Int ?? 1,
                                    minimumSpecials: d.object(forKey: prefix + "minSpecial") as? Int ?? 1,
                                    specialCharacters: d.string(forKey: prefix + "specialGroup") ?? PasswordTools.ct1DefaultSpecialCharacters)
    }

    static func save(_ p: PasswordTools.Policy) {
        let d = UserDefaults.standard
        d.set(p.minimumLength, forKey: prefix + "minLength")
        d.set(p.minimumDigits, forKey: prefix + "minDigits")
        d.set(p.minimumSpecials, forKey: prefix + "minSpecial")
        d.set(p.specialCharacters, forKey: prefix + "specialGroup")
    }

    /// C `atoi`: leading blanks, optional sign, digits; anything else → 0.
    static func atoi(_ s: String) -> Int {
        var t = Substring(s.drop { $0 == " " || $0 == "\t" })
        var sign = 1
        if let f = t.first, f == "-" || f == "+" { sign = f == "-" ? -1 : 1; t = t.dropFirst() }
        let digits = t.prefix { $0.isASCII && $0.isNumber }.prefix(9)
        return sign * (Int(digits) ?? 0)
    }
}

struct CT1ToolsPasswordGuidelinesSheet: View {
    let onOK: (PasswordTools.Policy) -> Void
    @Environment(\.dismiss) private var dismiss
    @CTState private var length: String
    @CTState private var digits: String
    @CTState private var specials: String
    @CTState private var group: String

    init(onOK: @escaping (PasswordTools.Policy) -> Void) {
        self.onOK = onOK
        let p = CT1ToolsPasswordGuidelines.load()
        _length = CTState(initialValue: String(p.minimumLength))
        _digits = CTState(initialValue: String(p.minimumDigits))
        _specials = CTState(initialValue: String(p.minimumSpecials))
        _group = CTState(initialValue: p.specialCharacters)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passwort-Richtlinien").font(.headline)
            GroupBox("Beschreibung") {
                Text("Hier können Sie einstellen, welche Mindestanforderungen der in CrypTool integrierte Passwort-Qualitätsmesser an Ihre Passwörter stellt.")
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Mindestanforderung an Passwörter") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow { Text("Länge:").gridColumnAlignment(.trailing); small($length) }
                    GridRow { Text("Anzahl Ziffern:"); small($digits) }
                    GridRow { Text("Anzahl Sonderzeichen:"); small($specials) }
                    GridRow { Text("Gültige Sonderzeichen:"); TextField("", text: $group).frame(width: 220) }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            HStack {
                Button("OK", action: ok).keyboardShortcut(.defaultAction)
                Spacer()
                Button("Standard") {
                    // CT1 OnBnClickedDefault: 8 / 1 / 1 and the special characters of the text options
                    (length, digits, specials, group) = ("8", "1", "1", TextOptions.specialCharacters)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func small(_ b: Binding<String>) -> some View {
        TextField("", text: b).frame(width: 44).multilineTextAlignment(.trailing)
    }

    private func ok() {
        let s = CT1ToolsPasswordGuidelines.atoi(specials)
        if s > 0 && group.isEmpty {
            Alerts.error("Die Liste der Sonderzeichen ist leer!\nBitte geben Sie Sonderzeichen an, oder verringern Sie die Minimalzahl der Sonderzeichen auf Null.")
            return
        }
        // negative values would make every password non-compliant in CT1 (unsigned comparison)
        let p = PasswordTools.Policy(minimumLength: max(0, CT1ToolsPasswordGuidelines.atoi(length)),
                                     minimumDigits: max(0, CT1ToolsPasswordGuidelines.atoi(digits)),
                                     minimumSpecials: max(0, s), specialCharacters: group)
        CT1ToolsPasswordGuidelines.save(p)
        onOK(p)
        dismiss()
    }
}

// MARK: - Password quality meter (CT1 IDD_PASSWORDQUALITYMETER)

struct PasswordQualityView: View {
    var initialPassword: String = ""
    @CTState private var password = ""
    @CTState private var showPassword = true
    @CTState private var policy = CT1ToolsPasswordGuidelines.load()
    @CTState private var showGuidelines = false
    @CTState private var didAppear = false
    @CTState private var windowRef = CT1ToolsWindowRef()

    var body: some View {
        let r = PasswordTools.ct1Quality(of: password, policy: policy, hidePassword: !showPassword)
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Beschreibung") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Es ist nicht möglich, die Sicherheit von Passwörtern quantitativ eindeutig zu bestimmen. Allerdings ist es möglich, die Sicherheit von Passwörtern basierend auf bestimmten Hypothesen zu schätzen.")
                    Text("Unten finden Sie vier implementierte Hypothesen für Passwort-Qualitätsmesser, mit denen Sie die Sicherheit Ihres Passwortes einschätzen können.")
                }
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Eingabe des Passworts") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bitte geben Sie Ihr Passwort in das Eingabefeld ein. Die Qualität des Passworts wird prozentual angezeigt und nach jedem Tastendruck automatisch aktualisiert.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Passwort:").frame(width: 70, alignment: .trailing)
                        Group {
                            if showPassword { TextField("", text: $password) } else { SecureField("", text: $password) }
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Toggle("Passwort im Klartext anzeigen", isOn: $showPassword).toggleStyle(.checkbox)
                            .padding(.leading, 78)
                        Spacer()
                        Text("Passwortlänge:")
                        Text("\(password.count)").monospacedDigit()
                            .frame(width: 40, alignment: .trailing).padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Qualität des Passworts basierend auf Hypothesen (und Entropie des Passworts in Bits)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 16) {
                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                            meter("KeePass:", r.keePass, r.keePassText)
                            meter("Mozilla:", r.mozilla, r.mozillaText)
                            meter("PGP:", r.pgp, r.pgpText)
                            meter("CrypTool:", r.crypTool, r.crypToolText)
                        }
                        Spacer(minLength: 0)
                        CT1ToolsQualityFace(level: r.level).frame(width: 44, height: 44)
                            .help("Mittelwert der vier Verfahren: \(r.average) %")
                        Spacer(minLength: 0)
                    }
                    if r.showsTruncationNote {
                        Text("(Die CrypTool-PQM-Methode bewertet nur die ersten 32 Zeichen)")
                            .font(.callout).padding(.leading, 78)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Resistenz gegen Wörterbuch-Attacken (bewertet nur die ersten 32 Zeichen)") {
                ResultBox(text: r.resistance, minHeight: 150).padding(4)
            }
            HStack {
                Spacer()
                Button("Passwort-Richtlinien") { showGuidelines = true }
                Spacer()
                Button("Schließen") { windowRef.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 560, minHeight: 700)
        .background(CT1ToolsWindowAccessor(minContentSize: CGSize(width: 600, height: 740)) { windowRef.window = $0 })
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            if !initialPassword.isEmpty { password = PasswordTools.ct1CleanPassword(initialPassword) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ct1ToolsMeasurePassword)) { n in
            if let s = n.object as? String { password = PasswordTools.ct1CleanPassword(s) }
        }
        .onChange(of: password) { _, new in
            // CT1 removes all characters <= ' ' while typing
            let c = PasswordTools.ct1CleanPassword(new)
            if c != new { password = c }
        }
        .sheet(isPresented: $showGuidelines) {
            CT1ToolsPasswordGuidelinesSheet { policy = $0 }
        }
    }

    @ViewBuilder
    private func meter(_ label: String, _ value: Int, _ text: String) -> some View {
        GridRow {
            Text(label).frame(width: 70, alignment: .trailing)
            ProgressView(value: Double(min(max(value, 0), 100)), total: 100).frame(width: 220)
            Text(text).monospacedDigit().frame(width: 120, alignment: .leading)
        }
    }
}

/// CT1's five quality pictograms (PasswordQualityPoor/Low/Average/High/Great.gif): a smiley from
/// red/frowning to green/smiling.
struct CT1ToolsQualityFace: View {
    let level: Int

    private var color: Color {
        switch level {
        case 0: return Color(red: 1, green: 0, blue: 0)
        case 1: return Color(red: 1, green: 0.55, blue: 0)
        case 2: return Color(red: 1, green: 1, blue: 0)
        case 3: return Color(red: 0.6, green: 1, blue: 0)
        default: return Color(red: 0, green: 1, blue: 0)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let face = Path(ellipseIn: CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
            ctx.fill(face, with: .color(color))
            ctx.stroke(face, with: .color(.black), lineWidth: 1)
            for x in [0.36, 0.64] {
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - w * 0.05, y: h * 0.3, width: w * 0.1, height: h * 0.13)), with: .color(.black))
            }
            let curve = CGFloat(level - 2) / 2 * h * 0.16   // > 0 smile, < 0 frown
            var mouth = Path()
            mouth.move(to: CGPoint(x: w * 0.28, y: h * 0.66))
            mouth.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.66), control: CGPoint(x: w * 0.5, y: h * 0.66 + 2 * curve))
            ctx.stroke(mouth, with: .color(.black), style: StrokeStyle(lineWidth: max(1.5, w / 22), lineCap: .round))
        }
        .accessibilityLabel(["schlecht", "niedrig", "durchschnittlich", "hoch", "sehr hoch"][min(max(level, 0), 4)])
    }
}

// MARK: - Password generator with given entropy (CT1 IDD_PASSWORDENTROPY)

struct PasswordEntropyView: View {
    @EnvironmentObject private var settings: AppSettings
    @CTState private var bits = ""
    @CTState private var alphabet = ""
    @CTState private var useTextAlphabet = true
    @CTState private var written = false
    @CTState private var telephonic = false
    @CTState private var wlan = false
    @CTState private var example = ""
    @CTState private var initialized = false
    @CTState private var windowRef = CT1ToolsWindowRef()

    private var passwordLength: Int? {
        PasswordTools.ct1PasswordLength(entropyBits: Int(bits) ?? 0, alphabetSize: alphabet.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Beschreibung") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dieser Dialog berechnet ein zufälliges Passwort.")
                    Text("Die Passwort-Entropie beschreibt, wie schwer das Passwort zu erraten ist. Das Passwort-Alphabet bestimmt, welche Zeichen für das Passwort verwendet werden. Durch Entropie und Alphabet ergibt sich die Passwort-Länge.")
                }
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Input-Parameter zur Generierung des Passworts") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                    GridRow {
                        Text("Entropie:").gridColumnAlignment(.trailing)
                        HStack {
                            TextField("", text: $bits).frame(width: 60).multilineTextAlignment(.trailing)
                            Text("Bits")
                        }
                    }
                    GridRow {
                        Text("Alphabet:")
                        TextField("", text: $alphabet).font(.system(.body, design: .monospaced))
                    }
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        HStack {
                            Toggle("Aktuelles Text-Alphabet verwenden", isOn: $useTextAlphabet).toggleStyle(.checkbox)
                            Spacer()
                            Button("Textoptionen") { OptionsWindows.showTextOptions() }.disabled(!useTextAlphabet)
                        }
                    }
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Toggle("Keine verwechselbaren Zeichen verwenden (schriftliche Übertragung)", isOn: $written).toggleStyle(.checkbox)
                    }
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Toggle("Keine verwechselbaren Zeichen verwenden (telefonische Übertragung)", isOn: $telephonic).toggleStyle(.checkbox)
                    }
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Toggle("Alphabet für WLAN-Passwörter verwenden (64 Zeichen)", isOn: $wlan).toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            GroupBox("Generiertes Passwort") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                    GridRow {
                        Text("Passwort-Länge:").gridColumnAlignment(.trailing)
                        HStack {
                            readOnly(passwordLength.map(String.init) ?? "", width: 60, trailing: true)
                            Text("Zeichen")
                        }
                    }
                    GridRow {
                        Text("Passwort-Beispiel:")
                        readOnly(example, width: nil, trailing: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Passwort generieren", action: generate).keyboardShortcut(.defaultAction)
                Button("Passwort-Qualität messen", action: measure).disabled(example.isEmpty)
                Spacer()
                Button("Schließen") { windowRef.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 640, minHeight: 500)
        .background(CT1ToolsWindowAccessor(title: "Passwörter mit bestimmter Entropie erzeugen",
                                           minContentSize: CGSize(width: 680, height: 540)) { windowRef.window = $0 })
        .onAppear {
            guard !initialized else { return }
            initialized = true
            alphabet = settings.textOptions.alphabet   // CT1 default: alphabet of the text options
        }
        .onChange(of: bits) { _, new in
            // CT1 accepts digits only
            let d = String(new.filter { $0.isASCII && $0.isNumber }.prefix(6))
            if d != new { bits = d }
            if passwordLength == nil { example = "" }
        }
        .onChange(of: alphabet) { old, new in
            let d = PasswordTools.ct1RemovingDuplicates(new)
            if d != new { alphabet = d; return }
            if old != new { example = "" }
        }
        .onChange(of: useTextAlphabet) { _, _ in checkBoxesChanged() }
        .onChange(of: written) { _, _ in checkBoxesChanged() }
        .onChange(of: telephonic) { _, _ in checkBoxesChanged() }
        .onChange(of: wlan) { _, _ in checkBoxesChanged() }
        .onChange(of: settings.textOptions.alphabet) { _, _ in if useTextAlphabet { checkBoxesChanged() } }
    }

    private func readOnly(_ s: String, width: CGFloat?, trailing: Bool) -> some View {
        Text(s.isEmpty ? " " : s)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(1).truncationMode(.tail)
            .frame(width: width, alignment: trailing ? .trailing : .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor)))
    }

    private func checkBoxesChanged() {
        let new = PasswordTools.ct1EntropyAlphabet(textAlphabet: settings.textOptions.alphabet, useTextAlphabet: useTextAlphabet,
                                                   nonConfusableWritten: written, nonConfusableTelephonic: telephonic,
                                                   wlan: wlan, current: alphabet)
        if new != alphabet { alphabet = new; example = "" }
    }

    private func generate() {
        guard !bits.isEmpty, !alphabet.isEmpty else {
            Alerts.info("Bitte stellen Sie sicher, dass Sie\n- die gewünschte Passwort-Entropie und\n- das gewünschte Passwort-Alphabet\nangegeben haben.")
            return
        }
        example = PasswordTools.ct1RandomPassword(length: passwordLength ?? 0, alphabet: alphabet)
    }

    /// "Passwort-Qualität messen": opens (or updates) the quality meter with the generated password.
    private func measure() {
        let pw = example
        WindowPresenter.tool(id: "pwquality", title: "Passwort-Qualitätsmesser", size: CGSize(width: 520, height: 440)) {
            PasswordQualityView(initialPassword: pw)
        }
        NotificationCenter.default.post(name: .ct1ToolsMeasurePassword, object: pw)
    }
}
