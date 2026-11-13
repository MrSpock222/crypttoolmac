import AppKit
import CTCommon
import UniformTypeIdentifiers

/// Describes how a document came into existence (CT1 shows this in the window title,
/// e.g. "Caesar encryption of <Startingexample-en.txt>, key <B>").
struct DocumentOrigin {
    var title: String
    /// Identifier of the producing method (used to pre-fill keys when decrypting).
    var method: String?
    /// Human readable key used for the operation ("Schlüssel anzeigen").
    var key: String?
    weak var parent: CTDocument?
}

enum DocumentViewMode {
    case text, hex
}

/// A CrypTool document: an arbitrary byte sequence shown as text or hex dump.
@objc(CTDocument)
final class CTDocument: NSDocument {
    /// Document contents. Setting it notifies the window controllers.
    var bytes: [UInt8] = [] {
        didSet { NotificationCenter.default.post(name: CTDocument.contentChanged, object: self) }
    }
    var origin: DocumentOrigin?
    var preferredViewMode: DocumentViewMode?
    private static var untitledCounter = 0
    private var untitledName: String?

    static let contentChanged = Notification.Name("CTDocumentContentChanged")

    override init() {
        super.init()
        hasUndoManager = true
    }

    convenience init(bytes: [UInt8], origin: DocumentOrigin?, viewMode: DocumentViewMode? = nil) {
        self.init()
        self.bytes = bytes
        self.origin = origin
        self.preferredViewMode = viewMode
        // CT1 result windows are not "dirty"; closing them doesn't ask.
        fileType = TextCoding.looksLikeText(bytes) ? UTType.plainText.identifier : UTType.data.identifier
    }

    override class var autosavesInPlace: Bool { false }

    override class var readableTypes: [String] { [UTType.plainText.identifier, UTType.data.identifier] }
    override class var writableTypes: [String] { [UTType.plainText.identifier, UTType.data.identifier] }
    override class func isNativeType(_ type: String) -> Bool { true }

    override func makeWindowControllers() {
        addWindowController(DocumentWindowController(document: self))
    }

    override func data(ofType typeName: String) throws -> Data { Data(bytes) }

    override func read(from data: Data, ofType typeName: String) throws {
        bytes = [UInt8](data)
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        if fileURL == nil {
            let base = shortName.replacingOccurrences(of: "/", with: "-")
            savePanel.nameFieldStringValue = TextCoding.looksLikeText(bytes) ? base + ".txt" : base + ".bin"
        }
        return true
    }

    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        nil // keep whatever the user typed
    }

    override var displayName: String! {
        get {
            if fileURL == nil, let o = origin { return o.title }
            if fileURL == nil, let n = untitledName { return n }
            return super.displayName
        }
        set { super.displayName = newValue }
    }

    /// Short name used inside generated titles ("… von <name>").
    var shortName: String {
        if let url = fileURL { return url.lastPathComponent }
        if let o = origin, o.parent == nil, o.method == nil, o.key == nil {
            return o.title   // opened example / readme: keep its name
        }
        if origin != nil {
            if untitledName == nil {
                CTDocument.untitledCounter += 1
                untitledName = "Unnamed \(CTDocument.untitledCounter)"
            }
            return untitledName!
        }
        return displayName ?? "Unnamed"
    }

    // MARK: Text access

    var text: String { TextCoding.string(from: bytes) }
    var isText: Bool { TextCoding.looksLikeText(bytes) }

    // MARK: Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = printInfo
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        tv.font = AppSettings.shared.editorFont
        let wc = windowControllers.first as? DocumentWindowController
        tv.string = (wc?.viewMode == .hex) ? HexDump.format(bytes) : text
        tv.sizeToFit()
        return NSPrintOperation(view: tv, printInfo: info)
    }
}

/// Classic hex dump formatting ("00000000  48 65 6C … |Hel…|").
enum HexDump {
    static func format(_ bytes: [UInt8], bytesPerLine: Int = 16) -> String {
        var out = String()
        out.reserveCapacity(bytes.count * 4 + 16)
        let hex = Array("0123456789ABCDEF")
        var offset = 0
        while offset < bytes.count || (offset == 0 && bytes.isEmpty == false) {
            let end = min(offset + bytesPerLine, bytes.count)
            out += String(format: "%08X  ", offset)
            for i in offset..<offset + bytesPerLine {
                if i < end {
                    let b = bytes[i]
                    out.append(hex[Int(b >> 4)]); out.append(hex[Int(b & 15)]); out.append(" ")
                } else {
                    out += "   "
                }
                if i == offset + bytesPerLine / 2 - 1 { out.append(" ") }
            }
            out += " |"
            for i in offset..<end {
                let b = bytes[i]
                out.append(b >= 0x20 && b < 0x7F ? Character(UnicodeScalar(b)) : ".")
            }
            out += "|\n"
            offset = end
            if end >= bytes.count { break }
        }
        return out
    }

    /// Hex pairs only, 16 per line – used for hex editing.
    static func editable(_ bytes: [UInt8]) -> String {
        var lines: [String] = []
        var i = 0
        while i < bytes.count {
            lines.append(Hex.encode(bytes[i..<min(i + 16, bytes.count)]))
            i += 16
        }
        return lines.joined(separator: "\n")
    }
}
