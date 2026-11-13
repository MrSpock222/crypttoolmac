import Compression
import Foundation
import CTCommon

/// CRC-32 (ISO 3309 / ITU-T V.42, as used by ZIP, PNG, gzip).
public enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    /// CRC-32 of `bytes` (optionally continuing from a previous `crc`).
    public static func checksum(_ bytes: [UInt8], crc: UInt32 = 0) -> UInt32 {
        var c = ~crc
        bytes.withUnsafeBufferPointer { p in
            table.withUnsafeBufferPointer { t in
                for b in p { c = t[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
            }
        }
        return ~c
    }
}

/// ZIP archives (PKWARE APPNOTE): CT1 "Einzelverfahren ▸ Tools ▸ Komprimieren ▸ Zip/UnZip".
/// Deflate (method 8) via the Compression framework, stored (method 0) if not smaller.
/// No ZIP64, no encryption.
public enum ZipArchive {

    /// Creates a .zip archive from the given entries (file names in UTF-8).
    public static func create(entries: [(name: String, data: [UInt8])]) throws -> [UInt8] {
        guard entries.count < 0xFFFF else { throw CTError("ZIP: Too many entries (at most 65534).") }
        var out: [UInt8] = []
        var central: [UInt8] = []
        let (dosTime, dosDate) = dosDateTime(Date())
        for entry in entries {
            let name = Array(entry.name.utf8)
            guard !name.isEmpty, name.count <= 0xFFFF else { throw CTError("ZIP: Invalid file name \"\(entry.name)\".") }
            guard entry.data.count < 0xFFFF_FFFF, out.count < 0xFFFF_FFFF else {
                throw CTError("ZIP: File too large (ZIP64 is not supported).")
            }
            let crc = CRC32.checksum(entry.data)
            var method: UInt16 = 0
            var payload = entry.data
            if let deflated = deflate(entry.data), deflated.count < entry.data.count {
                method = 8
                payload = deflated
            }
            let version: UInt16 = method == 8 ? 20 : 10
            let flags: UInt16 = 0x0800   // UTF-8 file names
            let localOffset = UInt32(out.count)
            // local file header
            put32(&out, 0x04034B50); put16(&out, version); put16(&out, flags); put16(&out, method)
            put16(&out, dosTime); put16(&out, dosDate); put32(&out, crc)
            put32(&out, UInt32(payload.count)); put32(&out, UInt32(entry.data.count))
            put16(&out, UInt16(name.count)); put16(&out, 0)
            out += name
            out += payload
            // central directory header
            put32(&central, 0x02014B50); put16(&central, 0x0300 | 20); put16(&central, version)
            put16(&central, flags); put16(&central, method); put16(&central, dosTime); put16(&central, dosDate)
            put32(&central, crc); put32(&central, UInt32(payload.count)); put32(&central, UInt32(entry.data.count))
            put16(&central, UInt16(name.count)); put16(&central, 0); put16(&central, 0)
            put16(&central, 0); put16(&central, 0); put32(&central, 0o100644 << 16); put32(&central, localOffset)
            central += name
        }
        guard out.count + central.count < 0xFFFF_FFFF else { throw CTError("ZIP: Archive too large (ZIP64 is not supported).") }
        let cdOffset = UInt32(out.count)
        out += central
        // end of central directory
        put32(&out, 0x06054B50); put16(&out, 0); put16(&out, 0)
        put16(&out, UInt16(entries.count)); put16(&out, UInt16(entries.count))
        put32(&out, UInt32(central.count)); put32(&out, cdOffset); put16(&out, 0)
        return out
    }

    /// Extracts all files of a .zip archive (directory entries are skipped). CRCs are verified.
    public static func extract(_ archive: [UInt8]) throws -> [(name: String, data: [UInt8])] {
        let a = archive
        func u16(_ p: Int) throws -> Int {
            guard p >= 0, p + 2 <= a.count else { throw corrupt() }
            return Int(a[p]) | Int(a[p + 1]) << 8
        }
        func u32(_ p: Int) throws -> Int {
            guard p >= 0, p + 4 <= a.count else { throw corrupt() }
            return Int(a[p]) | Int(a[p + 1]) << 8 | Int(a[p + 2]) << 16 | Int(a[p + 3]) << 24
        }
        // locate end of central directory record
        guard a.count >= 22 else { throw CTError("ZIP: Not a valid ZIP file (too short).") }
        var eocd = -1
        var p = a.count - 22
        let lowest = max(0, a.count - 22 - 0xFFFF)
        while p >= lowest {
            if a[p] == 0x50 && a[p + 1] == 0x4B && a[p + 2] == 0x05 && a[p + 3] == 0x06 { eocd = p; break }
            p -= 1
        }
        guard eocd >= 0 else { throw CTError("ZIP: Not a valid ZIP file (end of central directory not found).") }
        let count = try u16(eocd + 10)
        let cdOffset = try u32(eocd + 16)
        if count == 0xFFFF || cdOffset == 0xFFFF_FFFF { throw CTError("ZIP64 archives are not supported.") }
        var result: [(name: String, data: [UInt8])] = []
        var q = cdOffset
        for _ in 0..<count {
            guard try u32(q) == 0x02014B50 else { throw corrupt() }
            let flags = try u16(q + 8)
            let method = try u16(q + 10)
            let crc = UInt32(try u32(q + 16))
            let csize = try u32(q + 20)
            let usize = try u32(q + 24)
            let nameLen = try u16(q + 28)
            let extraLen = try u16(q + 30)
            let commentLen = try u16(q + 32)
            let localOffset = try u32(q + 42)
            guard q + 46 + nameLen <= a.count else { throw corrupt() }
            let nameBytes = Array(a[(q + 46)..<(q + 46 + nameLen)])
            let name = flags & 0x0800 != 0
                ? String(decoding: nameBytes, as: UTF8.self)
                : (String(bytes: nameBytes, encoding: .utf8) ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? "?")
            q += 46 + nameLen + extraLen + commentLen
            if name.hasSuffix("/") && usize == 0 { continue }   // directory
            if flags & 0x0001 != 0 { throw CTError("ZIP: \"\(name)\" is encrypted - not supported.") }
            guard try u32(localOffset) == 0x04034B50 else { throw corrupt() }
            let dataStart = localOffset + 30 + (try u16(localOffset + 26)) + (try u16(localOffset + 28))
            guard dataStart + csize <= a.count else { throw corrupt() }
            let payload = Array(a[dataStart..<(dataStart + csize)])
            let data: [UInt8]
            switch method {
            case 0: data = payload
            case 8:
                guard let d = inflate(payload, size: usize) else {
                    throw CTError("ZIP: \"\(name)\" could not be unpacked (deflate error).")
                }
                data = d
            default:
                throw CTError("ZIP: Compression method \(method) of \"\(name)\" is not supported.")
            }
            guard data.count == usize, CRC32.checksum(data) == crc else {
                throw CTError("ZIP: CRC error in \"\(name)\" - file corrupt.")
            }
            result.append((name, data))
        }
        return result
    }

    // MARK: - Helpers

    private static func corrupt() -> CTError { CTError("ZIP: The file is corrupt or not a ZIP file.") }

    private static func put16(_ a: inout [UInt8], _ v: UInt16) { a.append(UInt8(v & 0xFF)); a.append(UInt8(v >> 8)) }
    private static func put32(_ a: inout [UInt8], _ v: UInt32) {
        for i in 0..<4 { a.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) }
    }

    private static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, min(2107, c.year ?? 1980))
        let time = UInt16((c.hour ?? 0) << 11 | (c.minute ?? 0) << 5 | (c.second ?? 0) / 2)
        let day = UInt16((year - 1980) << 9 | (c.month ?? 1) << 5 | (c.day ?? 1))
        return (time, day)
    }

    /// Raw DEFLATE (RFC 1951) via Compression's COMPRESSION_ZLIB; nil if not compressible.
    static func deflate(_ data: [UInt8]) -> [UInt8]? {
        guard !data.isEmpty else { return nil }
        let cap = data.count + data.count / 16 + 64
        var dst = [UInt8](repeating: 0, count: cap)
        let n = data.withUnsafeBufferPointer { src in
            dst.withUnsafeMutableBufferPointer { d in
                compression_encode_buffer(d.baseAddress!, cap, src.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n > 0 else { return nil }
        return Array(dst.prefix(n))
    }

    /// Raw INFLATE of `data` with known decompressed `size`.
    static func inflate(_ data: [UInt8], size: Int) -> [UInt8]? {
        if size == 0 { return [] }
        guard !data.isEmpty else { return nil }
        var dst = [UInt8](repeating: 0, count: size + 1)
        let n = data.withUnsafeBufferPointer { src in
            dst.withUnsafeMutableBufferPointer { d in
                compression_decode_buffer(d.baseAddress!, size + 1, src.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n == size else { return nil }
        return Array(dst.prefix(n))
    }
}
