import AppKit
import CTCommon
import CTModern

/// CT1 "Einzelverfahren ▸ Tools ▸ Komprimieren ▸ Zip / UnZip" (MakeZip.cpp): "CTZ" + DEFLATE,
/// message "Kompressionsgrad: n %.", titles "ZIP-Kompression von <…>" / "ZIP-Dekompression von <…>".
/// UnZip also accepts ordinary .zip archives (Mac extension).
@MainActor
enum CT1ZipFeature {
    static func zip(_ doc: CTDocument) {
        do {
            let z = try CT1Zip.compress(doc.bytes)
            if !doc.bytes.isEmpty {
                Alerts.info(CT1Zip.compressionMessage(original: doc.bytes.count, compressed: z.count))
            }
            DocumentFactory.openResult(z, title: "ZIP compression of <\(doc.shortName)>", parent: doc, viewMode: .hex)
        } catch {
            Alerts.error(error.localizedDescription, title: "ZIP error")
        }
    }

    static func unzip(_ doc: CTDocument) {
        let b = doc.bytes
        if !CT1Zip.isCT1Zip(b), b.starts(with: [0x50, 0x4B, 0x03, 0x04]), let entries = try? ZipArchive.extract(b) {
            for e in entries { DocumentFactory.openResult(e.data, title: "ZIP decompression of <\(e.name)>", parent: doc) }
            return
        }
        guard CT1Zip.isCT1Zip(b) else {
            Alerts.error("No ZIP file (\"Magic number\" error).", title: "Error in ZIP file")
            return
        }
        do {
            let plain = try CT1Zip.decompress(b)
            DocumentFactory.openResult(plain, title: "ZIP decompression of <\(doc.shortName)>", parent: doc,
                                       viewMode: TextCoding.looksLikeText(plain) ? .text : .hex)
        } catch {
            Alerts.error("Error in ZIP file", title: "ZIP error")
        }
    }
}
