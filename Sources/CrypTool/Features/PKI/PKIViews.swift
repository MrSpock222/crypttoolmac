import AppKit
import SwiftUI
import CTCommon
import CTBigNum
import CTModern

/// Editable combo box (CT1 CBS_DROPDOWN), e.g. "Bitlänge des RSA-Moduls".
struct PKIComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    var enabled = true

    func makeNSView(context: Context) -> NSComboBox {
        let c = NSComboBox()
        c.addItems(withObjectValues: items)
        c.completes = false
        c.numberOfVisibleItems = 8
        c.delegate = context.coordinator
        c.stringValue = text
        return c
    }

    func updateNSView(_ c: NSComboBox, context: Context) {
        if c.stringValue != text { c.stringValue = text }
        c.isEnabled = enabled
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: PKIComboBox
        init(_ p: PKIComboBox) { parent = p }
        func controlTextDidChange(_ n: Notification) {
            if let c = n.object as? NSComboBox { parent.text = c.stringValue }
        }
        func comboBoxSelectionDidChange(_ n: Notification) {
            guard let c = n.object as? NSComboBox, c.indexOfSelectedItem >= 0 else { return }
            parent.text = parent.items[c.indexOfSelectedItem]
        }
    }
}

/// Gives SwiftUI content access to its window (to close tool windows with "Schließen").
struct PKIWindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { onWindow(v.window) }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

final class PKIWindowBox: ObservableObject { weak var window: NSWindow? }

// MARK: - Key generation (CT1 IDD_KEYASYM_GENERATION "Erzeugung eines asymmetrischen Schlüsselpaares")

struct KeyGenerationView: View {
    private enum Method { case rsa, dsa, ec }
    @CTState private var method: Method = .rsa
    @CTState private var rsaBits = "1024"
    @CTState private var dsaBits = "1024"
    @CTState private var curveName = EllipticCurve.ct1DefaultCurveName
    @CTState private var lastName = ""
    @CTState private var firstName = ""
    @CTState private var label = ""
    @CTState private var pin = ""
    @CTState private var pin2 = ""
    @CTState private var base: PKINumberBase = .decimal
    @CTState private var busy = false
    @CTState private var lastKey: UUID?
    @StateObject private var windowBox = PKIWindowBox()

    private let forbidden = Set("\\/:*?\"<>|~$%&,;][")
    private var curve: EllipticCurve? { EllipticCurve.anyNamed(curveName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PKIGroup("Algorithm") {
                    methodRadio("RSA", .rsa)
                    HStack {
                        Text("Bit length of RSA modulus:").frame(width: 170, alignment: .leading)
                        PKIComboBox(text: $rsaBits, items: ["512", "768", "1024", "2048"], enabled: method == .rsa).frame(width: 90)
                    }.padding(.leading, 20)
                    methodRadio("DSA", .dsa)
                    HStack {
                        Text("Bit length of DSA prime number:").frame(width: 170, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        PKIComboBox(text: $dsaBits, items: ["512", "768", "1024", "2048"], enabled: method == .dsa).frame(width: 90)
                    }.padding(.leading, 20)
                    methodRadio("Elliptic curves", .ec)
                    HStack {
                        Text("Identifier (bit length and curve parameter):").frame(width: 170, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        Picker("", selection: $curveName) {
                            ForEach(EllipticCurve.ct1Curves, id: \.name) { Text($0.name).tag($0.name) }
                        }.labelsHidden().frame(width: 120).disabled(method != .ec)
                    }.padding(.leading, 20)
                }
                .frame(width: 340)
                PKIGroup("User data") {
                    Text("The key pair will be put in an encrypted PSE with the name shown below. The key pair will be protected by your PIN code.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                        GridRow { Text("Last name:"); TextField("", text: $lastName) }
                        GridRow { Text("First name:"); TextField("", text: $firstName) }
                        GridRow { Text("Key identifier\n(optional):").fixedSize(); TextField("", text: $label) }
                        GridRow { Text("PIN:"); SecureField("", text: $pin) }
                        GridRow { Text("PIN verification:"); SecureField("", text: $pin2) }
                    }
                }
            }
            if method == .ec, let c = curve {
                Text("Domain parameters of elliptic curve '\(c.name)':")
                PKIECParameterTable(rows: PKIECParameterTable.domainRows(c), base: base).frame(height: 190)
                PKIGroup("Base for presentation of numbers") { PKIBasePicker(base: $base) }.frame(width: 340)
            }
            Divider()
            HStack {
                Button("Generate new key pair...") { generate() }.keyboardShortcut(.defaultAction).disabled(busy)
                Button("PKCS #12 Import") { importP12() }.disabled(busy)
                Button("Show key pair...") { showKeyList() }.disabled(lastKey == nil)
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                PKIHelpButton(action: .keyGeneration)
                Button("Close") { windowBox.window?.close() }
            }
        }
        .padding(16)
        .frame(minWidth: 720)
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Generation of an Asymmetric Key Pair" })
    }

    private func methodRadio(_ title: String, _ m: Method) -> some View {
        Button { method = m } label: {
            HStack(spacing: 5) {
                Image(systemName: method == m ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(method == m ? Color.accentColor : .secondary)
                Text(title)
            }
        }.buttonStyle(.plain)
    }

    /// CT1 input checks (messages from the CT1 string table).
    private func validate() -> Bool {
        let l = lastName.trimmingCharacters(in: .whitespaces), f = firstName.trimmingCharacters(in: .whitespaces)
        if l.isEmpty { PKIModal.warning("Please enter a last name."); return false }
        if f.isEmpty { PKIModal.warning("Please enter a first name."); return false }
        if (l + f + label).contains(where: { forbidden.contains($0) }) {
            PKIModal.warning("The input fields for the last name, first name and the key identifier\nmust not contain any of the following special characters:\n\\/:*?\"<>|~$%&,;][")
            return false
        }
        if pin.isEmpty { PKIModal.warning("Please enter a PIN code."); return false }
        if pin != pin2 {
            PKIModal.warning("PIN and PIN confirmation do not agree.\\Please enter again.")
            pin = ""; pin2 = ""
            return false
        }
        return true
    }

    private func generate() {
        let maxBits = 4096
        var bits = 0
        switch method {
        case .rsa:
            guard let b = Int(rsaBits.trimmingCharacters(in: .whitespaces)), b > 300, b <= maxBits else {
                PKIModal.warning("For bit length L of the RSA modulus the following must be true:\n\n\t300 < L < \(maxBits + 1).\n\nPlease re-enter the bit length.")
                return
            }
            bits = b
        case .dsa:
            guard let b = Int(dsaBits.trimmingCharacters(in: .whitespaces)), b > 300, b <= maxBits, b % 64 == 0 else {
                PKIModal.warning("For bit length L of the DSA prime number the following must be true:\n\n300 < L < \(maxBits + 1) and L divisible by 64.\n\nPlease re-enter the bit length.")
                return
            }
            bits = b
        case .ec:
            break
        }
        guard validate() else { return }
        busy = true
        let m = method, c = curve
        let (ln, fn, lb, p) = (lastName.trimmingCharacters(in: .whitespaces), firstName.trimmingCharacters(in: .whitespaces),
                               label.trimmingCharacters(in: .whitespaces), pin)
        Task.detached(priority: .userInitiated) {
            let started = Date()
            let material: PrivateKeyMaterial?
            switch m {
            case .rsa: material = .rsa(RSAKeyPair.generate(bits: bits))
            case .dsa:
                let params = DSA.generateParameters(L: bits, N: 160)
                material = .dsa(DSA.generateKey(parameters: params))
            case .ec: material = c.map { .ecc(ECKeyPair.generate(curve: $0)) }
            }
            let t = Date().timeIntervalSince(started)
            await MainActor.run {
                busy = false
                guard let material else { return }
                do {
                    let k = try KeyStore.shared.add(lastName: ln, firstName: fn, label: lb, material: material, pin: p)
                    lastKey = k.id
                    pin = ""; pin2 = ""
                    PKIModal.info("The parameters chosen by you and the new\nkey pair have been successfully saved.\nThe assigned key identifier is \n'\(k.ct1Identifier)'.\n\nElapsed time while creating key pair: \(PKIText.seconds(t)) seconds.")
                } catch { Alerts.error(error.localizedDescription) }
            }
        }
    }

    private func showKeyList() {
        if let id = lastKey { KeyListView.preselect = id }
        WindowPresenter.tool(id: "keylist", title: "Available Asymmetric Key Pairs", size: CGSize(width: 860, height: 560)) { KeyListView() }
    }

    private func importP12() {
        PKIPKCS12.importFile(defaultName: lastName, defaultFirstName: firstName) { k in lastKey = k.id }
    }
}

// MARK: - Key list (CT1 IDD_KEY_ASYM "Verfügbare asymmetrische Schlüsselpaare")

struct KeyListView: View {
    /// Key to select when the window opens ("Schlüsselpaar anzeigen..." of the key generation).
    @MainActor static var preselect: UUID?

    @ObservedObject private var store = KeyStore.shared
    @CTState private var selection: UUID?
    @CTState private var filter = PKIKeyFilter()
    @StateObject private var windowBox = PKIWindowBox()

    private var key: StoredKey? { selection.flatMap(store.key(id:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The list below shows the asymmetric key pairs that are available.")
            Text("Select the desired name by clicking its row with the left mouse button.")
            PKIKeyTable(selection: $selection, filter: filter, minHeight: 260) { k in showPublic(k) }
            HStack(alignment: .top, spacing: 16) {
                PKIKeyFilterBox(filter: $filter)
                Grid(horizontalSpacing: 10, verticalSpacing: 6) {
                    GridRow {
                        Button("Show public parameters...") { if let k = key { showPublic(k) } else { selectFirst() } }
                            .frame(maxWidth: .infinity)
                        Button("Show all parameters...") { if let k = key { showAll(k) } }
                            .disabled(key?.type.kind != .ec).frame(maxWidth: .infinity)
                    }
                    GridRow {
                        Button("Show certificate") { if let k = key { PKICertificate.show(k) } else { selectFirst() } }
                            .disabled(key?.type.kind == .ec)
                        Button("Export PSE (PKCS#12)") { if let k = key { PKIPKCS12.export(k) } }
                            .disabled(key == nil || key?.type.kind == .ec)
                    }
                    GridRow {
                        Button("Delete...") { if let k = key { delete(k) } else { selectFirst() } }
                        Button("Close") { windowBox.window?.close() }.keyboardShortcut(.defaultAction)
                    }
                }
                .frame(width: 460)
                Spacer()
                PKIHelpButton(action: .keyList)
            }
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 480)
        .background(PKIWindowReader { windowBox.window = $0; $0?.title = "Available Asymmetric Key Pairs" })
        .onAppear {
            if let p = KeyListView.preselect { selection = p; KeyListView.preselect = nil }
        }
    }

    private func selectFirst() {
        PKIModal.info(store.keys.filter(filter.accepts).isEmpty
                      ? "There are currently no asymmetric keys of the desired type available.\nChoose another key type or create some new keys."
                      : "Choose a key identifier from the list.")
    }

    private func showPublic(_ k: StoredKey) {
        if k.type.kind == .ec {
            PKIModal.run(title: "Public Key (Asymmetric)") { close in PKIECKeyView(key: k, privateKey: nil, close: close) }
        } else {
            PKIModal.run(title: "Public Parameters") { close in PKIPublicParameterView(key: k, close: close) }
        }
    }

    private func showAll(_ k: StoredKey) {
        guard let pin = PKIPinAccess.ask(for: k), case .ecc(let pair)? = PKIPinAccess.open(k, pin: pin) else { return }
        PKIModal.run(title: "Public and Private Keys (Asymmetric)") { close in PKIECKeyView(key: k, privateKey: pair.d, close: close) }
    }

    private func delete(_ k: StoredKey) {
        guard Alerts.confirm("Are you sure that you wish the key files relating to key identifier\n'\(k.ct1Identifier)'\nto be DELETED?\n\nClick on OK to continue with the operation.",
                             title: "CrypTool") else { return }
        guard let pin = PKIPinAccess.ask(for: k), PKIPinAccess.open(k, pin: pin) != nil else { return }
        store.delete(k)
        selection = nil
    }
}
