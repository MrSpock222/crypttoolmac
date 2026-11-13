import AppKit
import SwiftUI

/// Entry points of the formerly external CT1 tools "AES (self extracting)" (AES-Tool 2.7) and
/// "Generic t-adic NAF Key Generator" (t-adicNAF.hta / t-adicNAF.exe 1.3.3).
@MainActor
enum CT1Tools {
    private static weak var aesModel: AESToolModel?

    /// CT1 (CCryptDoc::OnAesSelfextract) starts AESTool.exe with a temporary copy of the active
    /// document (including unsaved changes) as input file; without document the field stays empty.
    static func openAESTool(document: CTDocument?) {
        let input = document.flatMap(temporaryCopy(of:))
        if let m = aesModel, let w = m.window {
            if let input { m.setInput(input.path) }
            w.makeKeyAndOrderFront(nil)
            return
        }
        let model = AESToolModel()
        if let input { model.setInput(input.path) }
        aesModel = model
        model.window = WindowPresenter.tool(id: "ct1tools.aestool", title: AESToolModel.version,
                                            size: CGSize(width: 600, height: 420), resizable: false) {
            AESToolView(model: model)
        }
    }

    static func openTadicNAF() {
        WindowPresenter.tool(id: "ct1tools.tadicnaf", title: "Generic t-adic NAF Key Generator",
                             size: CGSize(width: 720, height: 780)) {
            TadicNAFView()
        }
    }

    /// Writes the document to a temporary file named like the document (CT1: %TEMP%\cryN.org);
    /// the name ends up in the AES-Tool info block and is proposed when decrypting.
    private static func temporaryCopy(of doc: CTDocument) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CrypTool-AES-Tool", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = doc.shortName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        if name.isEmpty { name = "cry.org" }
        let url = dir.appendingPathComponent(name)
        do {
            try Data(doc.bytes).write(to: url)
            return url
        } catch {
            Alerts.error("The temporary file \(url.path) could not be written.")
            return nil
        }
    }
}
