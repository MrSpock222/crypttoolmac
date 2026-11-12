import Foundation

/// Generic error type used by all CrypTool modules. `message` is user facing (German).
public struct CTError: Error, LocalizedError, CustomStringConvertible, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
    public var description: String { message }
}

/// Cooperative cancellation for long running operations (brute force, factorisation …).
public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    public init() {}
    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }
    public func cancel() {
        lock.lock(); _cancelled = true; lock.unlock()
    }
}

/// Progress callback, value in 0…1. May be called from any thread.
public typealias ProgressHandler = @Sendable (Double) -> Void

public enum Hex {
    private static let digits = Array("0123456789ABCDEF".utf8)

    /// "DE AD BE EF" style (separator configurable).
    public static func encode<S: Sequence>(_ bytes: S, separator: String = " ", uppercase: Bool = true) -> String where S.Element == UInt8 {
        var out = String()
        var first = true
        for b in bytes {
            if !first { out += separator }
            first = false
            let hi = digits[Int(b >> 4)], lo = digits[Int(b & 0x0F)]
            var s = String(UnicodeScalar(hi)) + String(UnicodeScalar(lo))
            if !uppercase { s = s.lowercased() }
            out += s
        }
        return out
    }

    /// Parses hex digits, ignoring whitespace, ':' and '-' separators. Returns nil on invalid
    /// characters or an odd number of digits.
    public static func decode(_ string: String) -> [UInt8]? {
        var out: [UInt8] = []
        var hi: UInt8? = nil
        for u in string.utf8 {
            let v: UInt8
            switch u {
            case 0x30...0x39: v = u - 0x30
            case 0x41...0x46: v = u - 0x41 + 10
            case 0x61...0x66: v = u - 0x61 + 10
            case 0x20, 0x09, 0x0A, 0x0D, 0x3A, 0x2D: continue
            default: return nil
            }
            if let h = hi { out.append(h << 4 | v); hi = nil } else { hi = v }
        }
        return hi == nil ? out : nil
    }
}

public extension Array where Element == UInt8 {
    var hexString: String { Hex.encode(self) }
}

public extension Data {
    var bytes: [UInt8] { [UInt8](self) }
}

/// Text <-> bytes conversion used throughout the app: UTF-8 if valid, otherwise ISO-8859-1
/// (CT1 documents were Windows-1252 encoded).
public enum TextCoding {
    public static func string(from bytes: [UInt8]) -> String {
        if let s = String(bytes: bytes, encoding: .utf8) { return s }
        if let s = String(bytes: bytes, encoding: .windowsCP1252) { return s }
        return String(bytes: bytes, encoding: .isoLatin1) ?? ""
    }

    public static func bytes(from string: String) -> [UInt8] { Array(string.utf8) }

    /// Heuristic: true if the bytes look like printable text.
    public static func looksLikeText(_ bytes: [UInt8]) -> Bool {
        if bytes.isEmpty { return true }
        let sample = bytes.prefix(4096)
        var bad = 0
        for b in sample {
            if b == 0 { return false }
            if b < 0x09 || (b > 0x0D && b < 0x20) || b == 0x7F { bad += 1 }
        }
        if String(bytes: sample, encoding: .utf8) == nil && sample.count == bytes.count {
            // invalid UTF-8 – still text if it is mostly printable Latin-1
            return bad * 20 < sample.count
        }
        return bad * 50 < sample.count
    }
}
