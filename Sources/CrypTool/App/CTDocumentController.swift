import AppKit
import CTCommon

/// CT1's tutorials open their sample files with "Datei \\ Öffnen" from the folder
/// "CrypTool\\examples" (the Windows file dialog starts in the installation folder). The Mac app
/// keeps a writable copy of the bundled examples – text files in CT1's Windows-1252 encoding, so
/// they are byte-identical to CT1's – and shows that folder the first time "Öffnen" is used.
@MainActor
final class CTDocumentController: NSDocumentController {
    private static let shownKey = "ct1.openPanel.examplesShown"

    /// ~/Library/Application Support/CrypTool/examples (created/refreshed on demand).
    static func examplesFolder() -> URL? {
        let fm = FileManager.default
        guard let src = Resources.url("Examples"),
              let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("CrypTool/examples", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for name in try fm.contentsOfDirectory(atPath: src.path) where !name.hasPrefix(".") {
                let target = dir.appendingPathComponent(name)
                if fm.fileExists(atPath: target.path) { continue }   // never overwrite the user's changes
                guard let data = fm.contents(atPath: src.appendingPathComponent(name).path) else { continue }
                var bytes = [UInt8](data)
                if (name as NSString).pathExtension.lowercased() == "txt" {
                    bytes = TextCoding.bytes(from: TextCoding.string(from: bytes))
                }
                try Data(bytes).write(to: target)
            }
        } catch {
            return nil
        }
        return dir
    }

    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?,
                                 completionHandler: @escaping (Int) -> Void) {
        prepare(openPanel)
        super.beginOpenPanel(openPanel, forTypes: inTypes, completionHandler: completionHandler)
    }

    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        prepare(openPanel)
        return super.runModalOpenPanel(openPanel, forTypes: types)
    }

    private func prepare(_ panel: NSOpenPanel) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.shownKey), let dir = Self.examplesFolder() else { return }
        defaults.set(true, forKey: Self.shownKey)
        panel.directoryURL = dir
    }
}
