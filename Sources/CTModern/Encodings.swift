import CTCommon

/// Base64 (RFC 4648 / MIME) as CT1's "Codierungen ▸ Base64".
public enum Base64Codec {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    private static let decodeTable: [Int8] = {
        var t = [Int8](repeating: -1, count: 256)
        for (i, c) in alphabet.enumerated() { t[Int(c)] = Int8(i) }
        return t
    }()

    /// Encodes `bytes`; a line break ("\n") is inserted after every `lineLength` characters
    /// (0 = no line breaks).
    public static func encode(_ bytes: [UInt8], lineLength: Int = 76) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 4 / 3 + bytes.count / 48 + 4)
        var col = 0
        func emit(_ c: UInt8) {
            if lineLength > 0 && col == lineLength { out.append(0x0A); col = 0 }
            out.append(c)
            col += 1
        }
        var i = 0
        while i + 3 <= bytes.count {
            let v = UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2])
            emit(alphabet[Int(v >> 18)]); emit(alphabet[Int((v >> 12) & 63)])
            emit(alphabet[Int((v >> 6) & 63)]); emit(alphabet[Int(v & 63)])
            i += 3
        }
        let rest = bytes.count - i
        if rest == 1 {
            let v = UInt32(bytes[i]) << 16
            emit(alphabet[Int(v >> 18)]); emit(alphabet[Int((v >> 12) & 63)]); emit(0x3D); emit(0x3D)
        } else if rest == 2 {
            let v = UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8
            emit(alphabet[Int(v >> 18)]); emit(alphabet[Int((v >> 12) & 63)])
            emit(alphabet[Int((v >> 6) & 63)]); emit(0x3D)
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Decodes Base64; whitespace is ignored, missing '=' padding is tolerated.
    public static func decode(_ string: String) throws -> [UInt8] {
        var out: [UInt8] = []
        var acc: UInt32 = 0
        var n = 0
        var padding = 0
        var position = 0
        for c in string.utf8 {
            position += 1
            switch c {
            case 0x20, 0x09, 0x0A, 0x0D, 0x0B, 0x0C: continue
            case 0x3D:
                padding += 1
                continue
            default:
                let v = decodeTable[Int(c)]
                if v < 0 {
                    throw CTError("Ungültiges Zeichen für Base64 an Position \(position): „\(String(decoding: [c], as: UTF8.self))“.")
                }
                if padding > 0 { throw CTError("Base64: Daten nach dem Füllzeichen „=“.") }
                acc = acc << 6 | UInt32(v)
                n += 1
                if n == 4 {
                    out.append(UInt8(acc >> 16)); out.append(UInt8((acc >> 8) & 255)); out.append(UInt8(acc & 255))
                    acc = 0; n = 0
                }
            }
        }
        switch n {
        case 0: break
        case 1: throw CTError("Base64: Unvollständige Daten (Länge ist kein gültiges Vielfaches von 4 Zeichen).")
        case 2: out.append(UInt8((acc >> 4) & 255))
        default: out.append(UInt8((acc >> 10) & 255)); out.append(UInt8((acc >> 2) & 255))
        }
        return out
    }
}

/// UU encoding (uuencode/uudecode) as CT1's "Codierungen ▸ UU".
public enum UUCodec {
    @inline(__always) private static func enc(_ v: UInt8) -> UInt8 { v == 0 ? 0x60 : v + 0x20 }

    /// Encodes `bytes` with "begin 644 <fileName>" header, 45 bytes per line and "`\nend\n" trailer.
    public static func encode(_ bytes: [UInt8], fileName: String = "CrypTool.bin") -> String {
        var out = Array("begin 644 \(fileName)\n".utf8)
        var i = 0
        while i < bytes.count {
            let n = min(45, bytes.count - i)
            out.append(enc(UInt8(n)))
            var j = 0
            while j < n {
                let b0 = bytes[i + j]
                let b1: UInt8 = j + 1 < n ? bytes[i + j + 1] : 0
                let b2: UInt8 = j + 2 < n ? bytes[i + j + 2] : 0
                out.append(enc(b0 >> 2))
                out.append(enc(((b0 << 4) | (b1 >> 4)) & 63))
                out.append(enc(((b1 << 2) | (b2 >> 6)) & 63))
                out.append(enc(b2 & 63))
                j += 3
            }
            out.append(0x0A)
            i += n
        }
        out.append(contentsOf: Array("`\nend\n".utf8))
        return String(decoding: out, as: UTF8.self)
    }

    /// Decodes UU-encoded text. The "begin <mode> <name>" line is optional (then `fileName` is nil);
    /// decoding stops at "end".
    public static func decode(_ string: String) throws -> (bytes: [UInt8], fileName: String?) {
        var lines = string.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
        var fileName: String? = nil
        if let idx = lines.firstIndex(where: { $0.hasPrefix("begin ") }) {
            let parts = lines[idx].split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            if parts.count >= 3 { fileName = String(parts[2]) }
            lines.removeSubrange(0...idx)
        }
        var out: [UInt8] = []
        var lineNo = 0
        for line in lines {
            lineNo += 1
            if line == "end" || line.hasPrefix("end ") { return (out, fileName) }
            let u = Array(line.utf8)
            if u.isEmpty { continue }
            func dec(_ c: UInt8) throws -> UInt8 {
                guard c >= 0x20 && c <= 0x60 else {
                    throw CTError("UU-Decodierung: ungültiges Zeichen in Zeile \(lineNo).")
                }
                return (c - 0x20) & 63
            }
            let n = Int(try dec(u[0]))
            if n == 0 { continue }
            let needed = (n + 2) / 3 * 4
            guard u.count - 1 >= (n * 4 + 2) / 3 else {
                throw CTError("UU-Decodierung: Zeile \(lineNo) ist zu kurz.")
            }
            var chars = Array(u[1...])
            while chars.count < needed { chars.append(0x60) }   // tolerate stripped trailing blanks
            var got = 0
            var k = 0
            while got < n {
                let c0 = try dec(chars[k]), c1 = try dec(chars[k + 1]), c2 = try dec(chars[k + 2]), c3 = try dec(chars[k + 3])
                let bytes3: [UInt8] = [c0 << 2 | c1 >> 4, (c1 << 4) | (c2 >> 2), (c2 << 6) | c3]
                for b in bytes3 where got < n { out.append(b); got += 1 }
                k += 4
            }
        }
        if fileName != nil {
            throw CTError("UU-Decodierung: Die Zeile „end“ fehlt.")
        }
        return (out, fileName)
    }
}
