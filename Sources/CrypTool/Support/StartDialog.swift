import AppKit
import SwiftUI

/// CT1 "Wie Sie starten" (IDD_TIPPS_AND_TRICKS) – shown at program start.
@MainActor
enum StartDialog {
    static func show() {
        WindowPresenter.tool(id: "startdialog", title: "Wie Sie starten", size: CGSize(width: 420, height: 380), resizable: false) {
            StartDialogView()
        }
    }
}

struct StartDialogView: View {
    @EnvironmentObject var settings: AppSettings
    @CTState private var dontShow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = Resources.url("Images/CrypToolStartLogo-de.png"), let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            HStack {
                Toggle("Diesen Dialog in Zukunft nicht mehr anzeigen", isOn: $dontShow)
                Spacer()
                Button("Hilfe (F1)") { HelpLink.startPage() }
                    .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!)), modifiers: [])
                Button("Schließen") {
                    settings.showStartDialog = !dontShow
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .onAppear { dontShow = !settings.showStartDialog }
    }
}
