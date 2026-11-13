import CommonCrypto
import CTCommon
import Foundation

/// File format, key handling and en-/decryption of CT1's stand-alone "AES-Tool" (aestool.exe 2.7,
/// menu "AES (selbstextrahierend)"). Byte compatible with the Windows tool (aestoolcrypto.h):
///
///     PREFIX        arbitrary data (Windows: aestool.exe, macOS: self-decrypting shell script, .AES: empty)
///     IV            16 bytes
///     ENCDATA       AES-CBC(IV, key, data || 0x01 || 0x00…)  – no padding at all for empty data
///     IV            16 bytes (same IV again)
///     ENCINFOBLOCK  AES-CBC(IV, key, MAGIC || namelen || name || 0x00…)   (LE 32-bit values)
///     TAIL          encdatalen (LE32) || encinfoblocklen (LE32) || MAGIC (LE32 0x32904FFC)
///
/// The file is recognised from its end, therefore self-extracting EXEs (and the macOS
/// `.command` files) are decrypted exactly like `.AES` files.
public enum AESToolFile {
    public static let magic: UInt32 = 0x3290_4FFC
    /// Magic of AES-Tool 1.x files ("encrypted with an older version").
    public static let oldMagic: UInt32 = 0x1827_3645
    public static let tailLength = 12
    public static let salt = "theNotSoRandomCrypToolSalt"
    public static let iterations = 10_000
    /// AES-Tool limits: 64 hex digits resp. 32 characters.
    public static let maxHexDigits = 64
    public static let maxPasswordCharacters = 32

    // MARK: - Keys

    /// AES-Tool's "PKCS#5" password derivation (aestoolcrypto.cpp, createPKCS5Password). Note: this is
    /// not PBKDF2 – D = SHA256(P || salt || 00000001), then 9 999 times D ^= SHA256(P || D).
    public static func deriveKey(password: [UInt8], iterations: Int = AESToolFile.iterations) -> [UInt8] {
        var d = Hashing.hash(password + Array(salt.utf8) + [0, 0, 0, 1], algorithm: .sha256)
        if iterations > 1 {
            for _ in 1..<iterations {
                let t = Hashing.hash(password + d, algorithm: .sha256)
                for i in 0..<32 { d[i] ^= t[i] }
            }
        }
        return d
    }

    /// Password bytes as the Windows tool sees them: ANSI (CP1252), at most 32 characters.
    /// Characters outside CP1252 become "?" (Windows' best-fit default).
    public static func passwordBytes(_ password: String) -> [UInt8] {
        var out: [UInt8] = []
        for ch in password.prefix(maxPasswordCharacters) {
            out += cp1252(String(ch)) ?? [0x3F]
        }
        return out
    }

    /// Key bytes from hex input (blanks ignored). An odd number of digits is completed with "0"
    /// ("Abc" == "ABC0"), more than 32 bytes are cut off. Returns nil for invalid characters.
    public static func hexKey(_ text: String) -> [UInt8]? {
        var digits = text.filter { !$0.isWhitespace }
        guard digits.allSatisfy(\.isHexDigit) else { return nil }
        if digits.count % 2 == 1 { digits += "0" }
        guard let bytes = Hex.decode(digits) else { return nil }
        return Array(bytes.prefix(32))
    }

    /// Effective AES key: zero padded to 128, 192 or 256 bit (as aestool's `aescbc`).
    public static func aesKey(_ key: [UInt8]) -> [UInt8] {
        let k = Array(key.prefix(32))
        let len = k.count <= 16 ? 16 : (k.count <= 24 ? 24 : 32)
        return k + [UInt8](repeating: 0, count: len - k.count)
    }

    // MARK: - Recognition

    public struct Info: Sendable, Equatable {
        public var fileLength: UInt64
        public var iv: [UInt8]
        public var dataLength: UInt64
        public var infoBlock: [UInt8]
        /// Offset of ENCDATA (= fileLength − tail − infoblock − IV − data).
        public var dataOffset: UInt64 { fileLength - UInt64(tailLength + 16 + infoBlock.count) - dataLength }
        /// Length of the prefix (self-extractor program) before the first IV.
        public var prefixLength: UInt64 { dataOffset >= 16 ? dataOffset - 16 : 0 }
    }

    public enum Probe: Sendable, Equatable {
        case plain
        case encrypted(Info)
        /// AES-Tool 1.x file (other magic).
        case oldVersion
        case corrupt
    }

    /// Recognises an AES-Tool file from its last bytes (`readAt(offset, count)` must return exactly
    /// `count` bytes or nil).
    public static func probe(length: UInt64, readAt: (UInt64, Int) -> [UInt8]?) -> Probe {
        guard length >= UInt64(tailLength), let tail = readAt(length - UInt64(tailLength), tailLength) else { return .plain }
        let low = UInt64(le32(tail, 0)), infoLen = UInt64(le32(tail, 4)), m = le32(tail, 8)
        if m == oldMagic { return .oldVersion }
        guard m == magic else { return .plain }
        // CT1: the stored length has only 32 bits; the upper bits are taken from the file length.
        var dataLen = (length & ~0xFFFF_FFFF) | low
        if dataLen > length { dataLen &-= 1 << 32 }
        guard infoLen >= 16, infoLen % 16 == 0, infoLen <= 1 << 20, dataLen % 16 == 0,
              UInt64(tailLength) + 32 + infoLen + dataLen <= length,
              let ivAndInfo = readAt(length - UInt64(tailLength) - infoLen - 16, Int(infoLen) + 16)
        else { return .corrupt }
        return .encrypted(Info(fileLength: length, iv: Array(ivAndInfo[0..<16]), dataLength: dataLen,
                               infoBlock: Array(ivAndInfo[16...])))
    }

    public static func probe(bytes: [UInt8]) -> Probe {
        probe(length: UInt64(bytes.count)) { off, n in
            let o = Int(off)
            return o + n <= bytes.count ? Array(bytes[o..<(o + n)]) : nil
        }
    }

    public static func probe(url: URL) throws -> Probe {
        let fh = try FileHandle(forReadingFrom: url)
        defer { try? fh.close() }
        let length = try fh.seekToEnd()
        return probe(length: length) { off, n in
            guard (try? fh.seek(toOffset: off)) != nil, let d = try? fh.read(upToCount: n), d.count == n else { return nil }
            return [UInt8](d)
        }
    }

    /// Decrypts the info block; returns the original file name or nil (wrong key / corrupt file).
    public static func originalName(_ info: Info, key: [UInt8]) -> String? {
        guard let plain = try? cbc(decrypt: true, key: key, iv: info.iv, info.infoBlock),
              plain.count >= 8, le32(plain, 0) == magic else { return nil }
        let len = Int(le32(plain, 4))
        guard len >= 0, 8 + len <= plain.count else { return nil }
        return windows1252String(Array(plain[8..<(8 + len)]))
    }

    // MARK: - In-memory API

    /// Builds a complete AES-Tool file (`prefix` = self-extractor or empty for .AES).
    public static func encrypt(_ data: [UInt8], key: [UInt8], originalName: String,
                               prefix: [UInt8] = [], iv: [UInt8]? = nil) throws -> [UInt8] {
        var out: [UInt8] = []
        try encrypt(length: UInt64(data.count), read: { off, n in Array(data[Int(off)..<min(data.count, Int(off) + n)]) },
                    write: { out += $0 }, key: key, originalName: originalName, prefix: prefix, iv: iv)
        return out
    }

    /// Decrypts a complete AES-Tool file (any prefix). Returns the original name and the data.
    public static func decrypt(_ file: [UInt8], key: [UInt8]) throws -> (name: String, data: [UInt8]) {
        guard case .encrypted(let info) = probe(bytes: file) else { throw CTError(probeMessage(probe(bytes: file))) }
        guard let name = originalName(info, key: key) else { throw CTError("Wrong key or file corrupt.") }
        var out: [UInt8] = []
        try decrypt(info, read: { off, n in Array(file[Int(off)..<(Int(off) + n)]) }, write: { out += $0 }, key: key)
        return (name, out)
    }

    // MARK: - File API (streamed, 4 GB+ capable)

    public static func encryptFile(_ input: URL, to output: URL, key: [UInt8], originalName: String,
                                   prefix: [UInt8] = []) throws {
        let src = try FileHandle(forReadingFrom: input)
        defer { try? src.close() }
        let length = try src.seekToEnd()
        try src.seek(toOffset: 0)
        try writing(output) { dst in
            try encrypt(length: length, read: { _, n in [UInt8](try src.read(upToCount: n) ?? Data()) },
                        write: { try dst.write(contentsOf: $0) }, key: key, originalName: originalName, prefix: prefix, iv: nil)
        }
    }

    public static func decryptFile(_ input: URL, info: Info, to output: URL, key: [UInt8]) throws {
        let src = try FileHandle(forReadingFrom: input)
        defer { try? src.close() }
        try writing(output) { dst in
            try decrypt(info, read: { off, n in
                try src.seek(toOffset: off)
                let d = [UInt8](try src.read(upToCount: n) ?? Data())
                guard d.count == n else { throw CTError("This encrypted file is corrupt.") }
                return d
            }, write: { try dst.write(contentsOf: $0) }, key: key)
        }
    }

    /// CT1 "Sicheres Löschen": overwrite with 0x00, 0xF0, 0x0F, 0xFF (flushed after each pass), then delete.
    public static func secureDelete(_ url: URL) throws {
        let fh = try FileHandle(forWritingTo: url)
        let length = try fh.seekToEnd()
        for pattern: UInt8 in [0x00, 0xF0, 0x0F, 0xFF] {
            try fh.seek(toOffset: 0)
            let block = Data(repeating: pattern, count: 1 << 16)
            var done: UInt64 = 0
            while done < length {
                let n = Int(min(UInt64(block.count), length - done))
                try fh.write(contentsOf: block.prefix(n))
                done += UInt64(n)
            }
            try fh.synchronize()
        }
        try fh.close()
        try FileManager.default.removeItem(at: url)
    }

    /// CT1 message for a probe result that is not `.encrypted`.
    public static func probeMessage(_ p: Probe) -> String {
        switch p {
        case .oldVersion: return "This file has been encrypted with an older version of AES-Tool. \nPlease use the same version for decrypting."
        case .corrupt: return "This encrypted file is corrupt."
        default: return "The file is not an AES-Tool file."
        }
    }

    // MARK: - Core

    static let chunk = 1 << 16   // multiple of CT1's 4096-byte buffer (relevant for the padding check)

    static func encrypt(length: UInt64, read: (UInt64, Int) throws -> [UInt8], write: ([UInt8]) throws -> Void,
                        key: [UInt8], originalName: String, prefix: [UInt8], iv: [UInt8]?) throws {
        let iv = iv ?? randomBytes(16)
        let k = aesKey(key)
        if !prefix.isEmpty { try write(prefix) }
        try write(iv)
        let c = try Cryptor(decrypt: false, key: k, iv: iv)
        var done: UInt64 = 0, encLen: UInt64 = 0
        while done < length {
            var block = try read(done, Int(min(UInt64(chunk), length - done)))
            guard !block.isEmpty else { throw CTError("The input file could not be read completely.") }
            done += UInt64(block.count)
            if done == length {                  // CT1 padding: 0x01, then 0x00 up to a multiple of 16
                block.append(1)
                while block.count % 16 != 0 { block.append(0) }
            }
            let enc = try c.update(block)
            encLen += UInt64(enc.count)
            try write(enc)
        }
        try write(iv)
        // Info block: only the file name (without path), CP1252 like the Windows tool.
        let name = cp1252Lossy((originalName as NSString).lastPathComponent)
        var ib = le32Bytes(magic) + le32Bytes(UInt32(name.count)) + name
        while ib.count % 16 != 0 { ib.append(0) }
        try write(try cbc(decrypt: false, key: k, iv: iv, ib))
        try write(le32Bytes(UInt32(truncatingIfNeeded: encLen)) + le32Bytes(UInt32(ib.count)) + le32Bytes(magic))
    }

    static func decrypt(_ info: Info, read: (UInt64, Int) throws -> [UInt8], write: ([UInt8]) throws -> Void,
                        key: [UInt8]) throws {
        let c = try Cryptor(decrypt: true, key: aesKey(key), iv: info.iv)
        var done: UInt64 = 0
        let total = info.dataLength
        while done < total {
            let n = Int(min(UInt64(chunk), total - done))
            var plain = try c.update(try read(info.dataOffset + done, n))
            done += UInt64(n)
            if done == total {
                // CT1: strip trailing zeros of the last 4096-byte buffer, then the 0x01 marker.
                let ct1Last = Int((total - 1) % 4096) + 1
                let lower = plain.count - ct1Last
                var i = plain.count - 1
                while i > lower && plain[i] == 0 { i -= 1 }
                guard plain[i] == 1 else { throw CTError("Wrong key or file corrupt.") }
                plain.removeSubrange(i...)
            }
            try write(plain)
        }
    }

    static func writing(_ url: URL, _ body: (FileHandle) throws -> Void) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let fh = try? FileHandle(forWritingTo: url) else {
            throw CTError("The file \(url.path) cannot be written.")
        }
        do {
            try fh.truncate(atOffset: 0)
            try body(fh)
            try fh.close()
        } catch {
            try? fh.close()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    final class Cryptor {
        private var ref: CCCryptorRef?
        init(decrypt: Bool, key: [UInt8], iv: [UInt8]) throws {
            let st = CCCryptorCreate(CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                                     0, key, key.count, iv, &ref)
            guard st == kCCSuccess else { throw CTError("AES: Initialization failed (\(st)).") }
        }
        deinit { if let ref { CCCryptorRelease(ref) } }
        func update(_ data: [UInt8]) throws -> [UInt8] {
            if data.isEmpty { return [] }
            var out = [UInt8](repeating: 0, count: data.count + 16)
            var moved = 0
            let st = CCCryptorUpdate(ref, data, data.count, &out, out.count, &moved)
            guard st == kCCSuccess else { throw CTError("AES: Processing error (\(st)).") }
            return Array(out[0..<moved])
        }
    }

    static func cbc(decrypt: Bool, key: [UInt8], iv: [UInt8], _ data: [UInt8]) throws -> [UInt8] {
        try Cryptor(decrypt: decrypt, key: aesKey(key), iv: iv).update(data)
    }

    // MARK: - Helpers

    static func randomBytes(_ n: Int) -> [UInt8] {
        var g = SystemRandomNumberGenerator()
        return (0..<n).map { _ in UInt8.random(in: 0...255, using: &g) }
    }

    static func le32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
    }

    static func le32Bytes(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> (8 * $0)) } }

    static func cp1252(_ s: String) -> [UInt8]? { s.data(using: .windowsCP1252).map { [UInt8]($0) } }

    /// File names: characters outside CP1252 become "_" (valid on Windows and macOS).
    static func cp1252Lossy(_ s: String) -> [UInt8] { s.flatMap { cp1252(String($0)) ?? [0x5F] } }

    public static func windows1252String(_ b: [UInt8]) -> String {
        String(data: Data(b), encoding: .windowsCP1252) ?? String(decoding: b, as: UTF8.self)
    }
}
