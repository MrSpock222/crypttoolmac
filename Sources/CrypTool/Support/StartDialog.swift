import AppKit
import SwiftUI

/// CT1 "Wie Sie starten" (IDD_TIPPS_AND_TRICKS) – shown at program start.
@MainActor
enum StartDialog {
    static func show() {
        WindowPresenter.tool(id: "startdialog", title: "How to Start", size: CGSize(width: 420, height: 380), resizable: false) {
            StartDialogView()
        }
    }
}

struct StartDialogView: View {
    @EnvironmentObject var settings: AppSettings
    @CTState private var dontShow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = Resources.url("Images/CrypToolStartLogo-en.png"), let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            HStack {
                Toggle("Don't show this dialog again", isOn: $dontShow)
                Spacer()
                Button("Help (F1)") { HelpLink.startPage() }
                    .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!)), modifiers: [])
                Button("Close") {
                    settings.showStartDialog = !dontShow
                    closeKeyWindow()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .onAppear { dontShow = !settings.showStartDialog }
    }
}
