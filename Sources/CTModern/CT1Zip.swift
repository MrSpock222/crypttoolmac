import zlib
import CTCommon

/// CT1's "Einzelverfahren ▸ Tools ▸ Komprimieren ▸ Zip/UnZip" (MakeZip.cpp `dozip`/`dounzip`):
/// the document is stored as the magic number "CTZ" followed by a raw DEFLATE stream (Info-ZIP
/// deflate, level 9; an empty document is "CTZ" alone). zlib with the same parameters produces
/// the identical stream for small documents (e.g. CrypTool-de.txt); for large inputs CT1's older
/// deflate splits blocks differently, so sizes can differ slightly. Files are interchangeable
/// with CT1 in both directions.
public enum CT1Zip {
    public static let magic: [UInt8] = Array("CTZ".utf8)

    public static func compress(_ data: [UInt8]) throws -> [UInt8] {
        if data.isEmpty { return magic }
        var s = z_stream()
        guard deflateInit2_(&s, 9, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION,
                            Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw CTError("ZIP error") }
        defer { deflateEnd(&s) }
        var input = data
        var out = [UInt8](repeating: 0, count: Int(deflateBound(&s, uLong(data.count))) + 16)
        let capacity = out.count
        let status: Int32 = input.withUnsafeMutableBufferPointer { ip in
            out.withUnsafeMutableBufferPointer { op in
                s.next_in = ip.baseAddress; s.avail_in = uInt(ip.count)
                s.next_out = op.baseAddress; s.avail_out = uInt(capacity)
                return deflate(&s, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else { throw CTError("ZIP error") }
        return magic + out.prefix(Int(s.total_out))
    }

    /// True if `data` starts with CT1's magic number.
    public static func isCT1Zip(_ data: [UInt8]) -> Bool { data.starts(with: magic) }

    /// Inverse of `compress`; throws `CTError` with CT1's messages.
    public static func decompress(_ data: [UInt8]) throws -> [UInt8] {
        guard isCT1Zip(data) else { throw CTError("No ZIP file (\"Magic number\" error).") }
        var input = Array(data.dropFirst(3))
        if input.isEmpty { return [] }
        var s = z_stream()
        guard inflateInit2_(&s, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw CTError("Error in ZIP file")
        }
        defer { inflateEnd(&s) }
        var result: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 1 << 16)
        let chunkSize = chunk.count
        var status: Int32 = Z_OK
        input.withUnsafeMutableBufferPointer { ip in
            s.next_in = ip.baseAddress; s.avail_in = uInt(ip.count)
            while status == Z_OK {
                chunk.withUnsafeMutableBufferPointer { op in
                    s.next_out = op.baseAddress; s.avail_out = uInt(chunkSize)
                    status = inflate(&s, Z_NO_FLUSH)
                    result += op.prefix(chunkSize - Int(s.avail_out))
                }
                if status == Z_BUF_ERROR && s.avail_in == 0 { break }
            }
        }
        guard status == Z_STREAM_END else { throw CTError("Error in ZIP file") }
        return result
    }

    /// CT1 IDS_STRING_MSG_KOMPRESSION_FACTOR: (before − after) · 100 / before, integer division.
    public static func compressionMessage(original: Int, compressed: Int) -> String {
        "Rate of compression: \((original - compressed) * 100 / max(original, 1)) %"
    }
}
