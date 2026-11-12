import AppKit
import SwiftUI
import CTCommon
import CTBigNum

// MARK: - Diffie-Hellman

/// CT1 "Diffie-Hellman-Demo" (IDD_DIFFIEHELLMANVISUALIZATION): five step buttons on the left,
/// public parameters on top, Alice and Bob with per-party buttons, key symbol for the details.
/// Model and sub-dialogs: CT1NumberTheory/DHDialogs.swift.
struct DiffieHellmanView: View {
    @StateObject private var m = DHModel()

    private static let stepTitles = [
        "Öffentliche Parameter setzen", "Geheimnisse wählen", "Öffentliche Teilschlüssel erzeugen",
        "Öffentliche Teilschlüssel austauschen", "Geheimen Schlüssel generieren",
    ]
    private let rowHeight: CGFloat = 62
    private let panel = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
                GridRow {
                    stepButton(0)
                    publicParameters.gridCellColumns(3)
                }
                GridRow {
                    Color.clear.frame(height: 10)
                    Color.clear.frame(height: 10).gridCellColumns(3)
                }
                GridRow {
                    Color.clear.frame(height: 22)
                    Text("Alice").font(.headline).frame(maxWidth: .infinity, minHeight: 22).background(panel)
                    Color.clear.frame(width: 90)
                    Text("Bob").font(.headline).frame(maxWidth: .infinity, minHeight: 22).background(panel)
                }
                GridRow {
                    stepButton(1)
                    partyCell(button: 5, icon: "lock.fill", tip: "Geheimnis wählen", label: "a:", value: masked(m.shownSecretA)) { m.chooseSecret(alice: true) }
                    Color.clear.frame(width: 90)
                    partyCell(button: 6, icon: "lock.fill", tip: "Geheimnis wählen", label: "b:", value: masked(m.shownSecretB)) { m.chooseSecret(alice: false) }
                }
                GridRow {
                    stepButton(2)
                    partyCell(button: 7, icon: "function", tip: "A = g^a mod p berechnen", label: "A:", value: m.sharedA) { m.computePublic(alice: true) }
                    Color.clear.frame(width: 90)
                    partyCell(button: 8, icon: "function", tip: "B = g^b mod p berechnen", label: "B:", value: m.sharedB) { m.computePublic(alice: false) }
                }
                GridRow {
                    stepButton(3)
                    Color.clear.frame(height: rowHeight).frame(maxWidth: .infinity).background(panel)
                    exchangeIndicator
                    Color.clear.frame(height: rowHeight).frame(maxWidth: .infinity).background(panel)
                }
                GridRow {
                    stepButton(4)
                    partyCell(button: 9, icon: "function", tip: "S = B^a mod p berechnen", label: "S:", value: m.sessionA) { m.computeSession(alice: true) }
                    keyButton
                    partyCell(button: 10, icon: "function", tip: "S = A^b mod p berechnen", label: "S:", value: m.sessionB) { m.computeSession(alice: false) }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Beenden") { m.window.window?.close() }
                CT1HelpButton(action: .diffieHellman)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("Einleitungsdialog anzeigen", isOn: $m.showIntro)
                    Toggle("Informationsdialoge anzeigen", isOn: $m.showInfo)
                }
            }
        }
        .padding()
        .frame(minWidth: 1040, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .topLeading)
        .ct1Window(title: DHText.windowTitle, ref: m.window)
        .onAppear { m.presentIntroIfNeeded() }
    }

    private func masked(_ s: String) -> String { String(repeating: "*", count: s.count) }

    private var publicParameters: some View {
        GroupBox("Von beiden benutzte öffentliche Parameter") {
            VStack(spacing: 6) {
                HStack {
                    Text("Primzahlmodul p:").frame(width: 120, alignment: .leading)
                    DHReadOnly(text: m.prime)
                }
                HStack {
                    Text("Generator g:").frame(width: 120, alignment: .leading)
                    DHReadOnly(text: m.generator)
                }
            }.padding(4)
        }
    }

    private func stepButton(_ i: Int) -> some View {
        Button {
            if i == 0 { m.step1() } else { m.step(i) }
        } label: {
            HStack(spacing: 8) {
                Text("\(i + 1)").font(.title2.bold()).frame(width: 22)
                Text(Self.stepTitles[i]).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if m.done[i] { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            .frame(width: 210, height: 40, alignment: .leading)
        }
        .disabled(!m.isActive(i))
        .frame(height: i == 0 ? nil : rowHeight)
    }

    private func partyCell(button: Int, icon: String, tip: String, label: String, value: String,
                           action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    if m.done[button] { Image(systemName: "checkmark").foregroundStyle(.green) }
                }.frame(width: 50)
            }
            .help(tip)
            .disabled(!m.isActive(button))
            HStack {
                Text(label).frame(width: 18, alignment: .leading)
                DHReadOnly(text: value)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .background(panel)
    }

    private var exchangeIndicator: some View {
        VStack(spacing: 2) {
            if m.done[3] {
                Text("A →").font(.system(.body, design: .monospaced))
                Text("← B").font(.system(.body, design: .monospaced))
            }
        }
        .frame(width: 90, height: rowHeight)
    }

    private var keyButton: some View {
        Button { m.showKeyDetails() } label: {
            Image(systemName: "key.fill").font(.title2).frame(width: 50, height: 28)
        }
        .help(DHText.keyTooltip)
        .disabled(!m.isActive(11))
        .frame(width: 90, height: rowHeight)
    }
}
