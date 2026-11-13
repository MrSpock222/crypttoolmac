import Foundation
import CTCommon

/// Tag class of an ASN.1 BER/DER element.
public enum ASN1TagClass: Int, Sendable {
    case universal = 0, application = 1, contextSpecific = 2, privateUse = 3
}

/// One element of a decoded ASN.1 structure (immutable).
public final class ASN1Node: Sendable {
    public let tagClass: ASN1TagClass
    public let constructed: Bool
    public let tagNumber: Int
    /// Offset of the first header byte in the (DER) input.
    public let offset: Int
    /// Number of header bytes (tag + length).
    public let headerLength: Int
    /// Length of the contents in bytes (for indefinite lengths: without the end-of-contents octets).
    public let length: Int
    /// True if the BER indefinite length form (0x80) was used.
    public let indefiniteLength: Bool
    /// Nesting depth (0 = top level).
    public let depth: Int
    /// Child elements of a constructed element.
    public let children: [ASN1Node]
    /// Contents octets of a primitive element (empty for constructed elements).
    public let value: [UInt8]
    /// DER structure found inside an OCTET STRING / BIT STRING (e.g. X.509 extensions,
    /// RSA public key), otherwise empty.
    public let encapsulated: [ASN1Node]

    init(tagClass: ASN1TagClass, constructed: Bool, tagNumber: Int, offset: Int, headerLength: Int,
         length: Int, indefiniteLength: Bool, depth: Int, children: [ASN1Node], value: [UInt8],
         encapsulated: [ASN1Node]) {
        self.tagClass = tagClass
        self.constructed = constructed
        self.tagNumber = tagNumber
        self.offset = offset
        self.headerLength = headerLength
        self.length = length
        self.indefiniteLength = indefiniteLength
        self.depth = depth
        self.children = children
        self.value = value
        self.encapsulated = encapsulated
    }

    /// Total encoded size including header (and end-of-contents octets).
    public var totalLength: Int { headerLength + length + (indefiniteLength ? 2 : 0) }

    /// Type name in the style of `openssl asn1parse` ("SEQUENCE", "INTEGER", "cont [ 0 ]" …).
    public var typeName: String {
        switch tagClass {
        case .application: return "appl [ \(tagNumber) ]"
        case .contextSpecific: return "cont [ \(tagNumber) ]"
        case .privateUse: return "priv [ \(tagNumber) ]"
        case .universal: return ASN1.universalTypeNames[tagNumber] ?? "[UNIVERSAL \(tagNumber)]"
        }
    }

    /// Decoded value for display (nil for constructed elements and NULL).
    public var valueDescription: String? {
        if constructed { return nil }
        guard tagClass == .universal else { return ASN1.hexPreview(value) }
        switch tagNumber {
        case 1: return value.first.map { $0 == 0 ? "FALSE" : "TRUE" } ?? ""
        case 2, 10: return ASN1.integerDescription(value)
        case 3:
            guard let unused = value.first else { return "" }
            let bits = Array(value.dropFirst())
            return (unused > 0 ? "(\(unused) unused bits) " : "") + ASN1.hexPreview(bits)
        case 4: return ASN1.hexPreview(value)
        case 5: return nil
        case 6:
            guard let oid = ASN1.oidString(value) else { return "invalid OID" }
            if let name = ASN1.oidNames[oid] { return "\(name) (\(oid))" }
            return oid
        case 13: return ASN1.relativeOIDString(value) ?? ASN1.hexPreview(value)
        case 12: return String(decoding: value, as: UTF8.self)
        case 18, 19, 20, 21, 22, 23, 24, 25, 26, 27:
            return String(bytes: value, encoding: .isoLatin1) ?? ASN1.hexPreview(value)
        case 30:
            return String(bytes: value, encoding: .utf16BigEndian) ?? ASN1.hexPreview(value)
        case 28:
            return String(bytes: value, encoding: .utf32BigEndian) ?? ASN1.hexPreview(value)
        default: return ASN1.hexPreview(value)
        }
    }

    /// The element and all descendants (including encapsulated ones) in document order.
    public var flattened: [ASN1Node] {
        var out: [ASN1Node] = [self]
        for c in children { out += c.flattened }
        for c in encapsulated { out += c.flattened }
        return out
    }
}

/// ASN.1 BER/DER decoder and `openssl asn1parse -i` style dump (CT1: "Einzelverfahren ▸
/// ASN.1-Decodierung").
public enum ASN1 {
    static let maxDepth = 64

    /// Parses DER/BER data. PEM ("-----BEGIN …-----") or plain Base64 text is decoded first.
    /// Returns the top level elements.
    public static func parse(_ der: [UInt8]) throws -> [ASN1Node] {
        try parseInput(der).nodes
    }

    /// Readable tree like `openssl asn1parse -i`: offset, depth, header length, length, type and
    /// decoded value. DER found inside OCTET/BIT STRINGs is shown indented and marked with "▹".
    public static func dump(_ der: [UInt8]) throws -> String {
        let nodes = try parse(der)
        var lines: [String] = []
        func emit(_ n: ASN1Node, encapsulated: Bool) {
            let len = n.indefiniteLength ? " inf" : String(format: "%4d", n.length)
            let indent = String(repeating: " ", count: n.depth)
            var line = String(format: "%5d:d=%-2d hl=%d l=", n.offset, n.depth, n.headerLength) + len
                + (n.constructed ? " cons: " : " prim: ") + indent + (encapsulated ? "▹" : "") + n.typeName
            if let v = n.valueDescription, !v.isEmpty {
                let pad = max(1, 18 - n.typeName.count - (encapsulated ? 1 : 0))
                line += String(repeating: " ", count: pad) + ":" + v
            }
            lines.append(line)
            for c in n.children { emit(c, encapsulated: false) }
            for c in n.encapsulated { emit(c, encapsulated: true) }
        }
        for n in nodes { emit(n, encapsulated: false) }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Converts PEM/Base64 input to DER (returns the input unchanged if it is not text).
    public static func derBytes(from input: [UInt8]) throws -> [UInt8] {
        try parseInput(input).der
    }

    // MARK: - Input handling

    private static func parseInput(_ input: [UInt8]) throws -> (der: [UInt8], nodes: [ASN1Node]) {
        if let text = String(bytes: input, encoding: .utf8), text.contains("-----BEGIN") {
            let der = try pemDecode(text)
            return (der, try parseDER(der))
        }
        do {
            return (input, try parseDER(input))
        } catch {
            if let text = String(bytes: input, encoding: .utf8),
               let der = try? Base64Codec.decode(text), !der.isEmpty,
               let nodes = try? parseDER(der) {
                return (der, nodes)
            }
            throw error
        }
    }

    private static func pemDecode(_ text: String) throws -> [UInt8] {
        var inBlock = false
        var body = ""
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("-----BEGIN") { inBlock = true; continue }
            if line.hasPrefix("-----END") { if inBlock { break } else { continue } }
            if inBlock && !line.contains(":") { body += line }   // skip "Proc-Type:" style headers
        }
        guard !body.isEmpty else { throw CTError("PEM: No Base64 content found between BEGIN and END.") }
        return try Base64Codec.decode(body)
    }

    // MARK: - DER parser

    static func parseDER(_ der: [UInt8]) throws -> [ASN1Node] {
        guard !der.isEmpty else { throw CTError("ASN.1: No data.") }
        var pos = 0
        var nodes: [ASN1Node] = []
        while pos < der.count {
            // tolerate trailing zero padding (e.g. block cipher padding)
            if der[pos...].allSatisfy({ $0 == 0 }) && !nodes.isEmpty { break }
            let node = try parseNode(der, &pos, end: der.count, depth: 0)
            nodes.append(node)
        }
        return nodes
    }

    private static func parseNode(_ d: [UInt8], _ pos: inout Int, end: Int, depth: Int) throws -> ASN1Node {
        guard depth <= maxDepth else { throw CTError("ASN.1: Nesting too deep (> \(maxDepth)).") }
        let start = pos
        func byte() throws -> UInt8 {
            guard pos < end else { throw CTError("ASN.1: Unexpected end of data at offset \(pos).") }
            defer { pos += 1 }
            return d[pos]
        }
        let first = try byte()
        let tagClass = ASN1TagClass(rawValue: Int(first >> 6))!
        let constructed = first & 0x20 != 0
        var tagNumber = Int(first & 0x1F)
        if tagNumber == 0x1F {
            tagNumber = 0
            var count = 0
            while true {
                let b = try byte()
                tagNumber = tagNumber << 7 | Int(b & 0x7F)
                count += 1
                guard count <= 4 else { throw CTError("ASN.1: Tag number too large at offset \(start).") }
                if b & 0x80 == 0 { break }
            }
        }
        let lb = try byte()
        var length = 0
        var indefinite = false
        if lb < 0x80 {
            length = Int(lb)
        } else if lb == 0x80 {
            guard constructed else { throw CTError("ASN.1: Indefinite length for a primitive element (offset \(start)).") }
            indefinite = true
        } else {
            let n = Int(lb & 0x7F)
            guard n <= 4 else { throw CTError("ASN.1: Length field too large at offset \(start).") }
            for _ in 0..<n { length = length << 8 | Int(try byte()) }
        }
        let headerLength = pos - start
        if !indefinite {
            guard length <= end - pos else {
                throw CTError("ASN.1: Length \(length) at offset \(start) exceeds the end of the data.")
            }
        }
        var children: [ASN1Node] = []
        var value: [UInt8] = []
        var encapsulated: [ASN1Node] = []
        if constructed {
            if indefinite {
                while true {
                    guard pos + 1 < end else { throw CTError("ASN.1: End-of-contents marker (00 00) is missing for the element at offset \(start).") }
                    if d[pos] == 0 && d[pos + 1] == 0 { break }
                    children.append(try parseNode(d, &pos, end: end, depth: depth + 1))
                }
                length = pos - start - headerLength
                pos += 2
            } else {
                let contentEnd = pos + length
                while pos < contentEnd {
                    children.append(try parseNode(d, &pos, end: contentEnd, depth: depth + 1))
                }
            }
        } else {
            value = Array(d[pos..<(pos + length)])
            // DER encapsulated in OCTET STRING / BIT STRING
            if tagClass == .universal && (tagNumber == 4 || tagNumber == 3) {
                let skip = tagNumber == 3 ? 1 : 0
                if value.count > skip + 1, tagNumber != 3 || value[0] == 0,
                   value[skip] == 0x30 || value[skip] == 0x31 || (tagNumber == 4 && value[skip] == 0x04) {
                    var p = pos + skip
                    var inner: [ASN1Node] = []
                    var ok = true
                    while p < pos + length {
                        guard let n = try? parseNode(d, &p, end: pos + length, depth: depth + 1) else { ok = false; break }
                        inner.append(n)
                    }
                    if ok && p == pos + length { encapsulated = inner }
                }
            }
            pos += length
        }
        return ASN1Node(tagClass: tagClass, constructed: constructed, tagNumber: tagNumber, offset: start,
                        headerLength: headerLength, length: length, indefiniteLength: indefinite, depth: depth,
                        children: children, value: value, encapsulated: encapsulated)
    }

    // MARK: - Value formatting

    static func hexPreview(_ bytes: [UInt8], limit: Int = 32) -> String {
        if bytes.count <= limit { return Hex.encode(bytes, separator: "") }
        return Hex.encode(bytes.prefix(limit), separator: "") + "… (\(bytes.count) bytes)"
    }

    static func integerDescription(_ v: [UInt8]) -> String {
        guard !v.isEmpty else { return "" }
        if v.count <= 8 {
            var x: Int64 = v[0] & 0x80 != 0 ? -1 : 0
            for b in v { x = x << 8 | Int64(b) }
            return String(x)
        }
        return "0x" + hexPreview(v, limit: 64)
    }

    /// Dotted OID notation of DER contents octets, nil if malformed.
    public static func oidString(_ v: [UInt8]) -> String? {
        guard !v.isEmpty, v.last! & 0x80 == 0 else { return nil }
        var parts: [String] = []
        var acc: UInt64 = 0
        var first = true
        for b in v {
            guard acc < (UInt64(1) << 56) else { return nil }
            acc = acc << 7 | UInt64(b & 0x7F)
            if b & 0x80 == 0 {
                if first {
                    let a = min(acc / 40, 2)
                    parts.append(String(a)); parts.append(String(acc - a * 40))
                    first = false
                } else {
                    parts.append(String(acc))
                }
                acc = 0
            }
        }
        return parts.joined(separator: ".")
    }

    static func relativeOIDString(_ v: [UInt8]) -> String? {
        guard !v.isEmpty, v.last! & 0x80 == 0 else { return nil }
        var parts: [String] = []
        var acc: UInt64 = 0
        for b in v {
            acc = acc << 7 | UInt64(b & 0x7F)
            if b & 0x80 == 0 { parts.append(String(acc)); acc = 0 }
        }
        return parts.joined(separator: ".")
    }

    static let universalTypeNames: [Int: String] = [
        0: "EOC", 1: "BOOLEAN", 2: "INTEGER", 3: "BIT STRING", 4: "OCTET STRING", 5: "NULL", 6: "OBJECT",
        7: "OBJECT DESCRIPTOR", 8: "EXTERNAL", 9: "REAL", 10: "ENUMERATED", 11: "EMBEDDED PDV",
        12: "UTF8STRING", 13: "RELATIVE OID", 16: "SEQUENCE", 17: "SET", 18: "NUMERICSTRING",
        19: "PRINTABLESTRING", 20: "T61STRING", 21: "VIDEOTEXSTRING", 22: "IA5STRING", 23: "UTCTIME",
        24: "GENERALIZEDTIME", 25: "GRAPHICSTRING", 26: "VISIBLESTRING", 27: "GENERALSTRING",
        28: "UNIVERSALSTRING", 30: "BMPSTRING",
    ]

    /// Names of common object identifiers (as printed by OpenSSL).
    public static let oidNames: [String: String] = [
        "1.2.840.113549.1.1.1": "rsaEncryption",
        "1.2.840.113549.1.1.2": "md2WithRSAEncryption",
        "1.2.840.113549.1.1.4": "md5WithRSAEncryption",
        "1.2.840.113549.1.1.5": "sha1WithRSAEncryption",
        "1.2.840.113549.1.1.10": "rsassaPss",
        "1.2.840.113549.1.1.11": "sha256WithRSAEncryption",
        "1.2.840.113549.1.1.12": "sha384WithRSAEncryption",
        "1.2.840.113549.1.1.13": "sha512WithRSAEncryption",
        "1.2.840.113549.1.1.14": "sha224WithRSAEncryption",
        "1.2.840.10040.4.1": "dsaEncryption",
        "1.2.840.10040.4.3": "dsaWithSHA1",
        "1.2.840.10045.2.1": "id-ecPublicKey",
        "1.2.840.10045.3.1.7": "prime256v1",
        "1.3.132.0.34": "secp384r1",
        "1.3.132.0.35": "secp521r1",
        "1.3.132.0.10": "secp256k1",
        "1.2.840.10045.4.1": "ecdsa-with-SHA1",
        "1.2.840.10045.4.3.2": "ecdsa-with-SHA256",
        "1.2.840.10045.4.3.3": "ecdsa-with-SHA384",
        "1.2.840.10045.4.3.4": "ecdsa-with-SHA512",
        "1.3.101.110": "X25519",
        "1.3.101.112": "ED25519",
        "1.2.840.113549.1.9.1": "emailAddress",
        "1.2.840.113549.1.9.3": "contentType",
        "1.2.840.113549.1.9.4": "messageDigest",
        "1.2.840.113549.1.9.5": "signingTime",
        "1.2.840.113549.1.9.14": "Extension Request",
        "1.2.840.113549.1.7.1": "pkcs7-data",
        "1.2.840.113549.1.7.2": "pkcs7-signedData",
        "1.2.840.113549.1.7.3": "pkcs7-envelopedData",
        "1.2.840.113549.1.5.12": "PBKDF2",
        "1.2.840.113549.1.5.13": "PBES2",
        "1.2.840.113549.2.2": "md2",
        "1.2.840.113549.2.5": "md5",
        "1.2.840.113549.2.7": "hmacWithSHA1",
        "1.2.840.113549.2.9": "hmacWithSHA256",
        "1.2.840.113549.3.2": "rc2-cbc",
        "1.2.840.113549.3.4": "rc4",
        "1.2.840.113549.3.7": "des-ede3-cbc",
        "1.3.14.3.2.7": "des-cbc",
        "1.3.14.3.2.26": "sha1",
        "1.3.36.3.2.1": "ripemd160",
        "2.16.840.1.101.3.4.1.2": "aes-128-cbc",
        "2.16.840.1.101.3.4.1.22": "aes-192-cbc",
        "2.16.840.1.101.3.4.1.42": "aes-256-cbc",
        "2.16.840.1.101.3.4.2.1": "sha256",
        "2.16.840.1.101.3.4.2.2": "sha384",
        "2.16.840.1.101.3.4.2.3": "sha512",
        "2.16.840.1.101.3.4.2.4": "sha224",
        "2.5.4.3": "commonName",
        "2.5.4.4": "surname",
        "2.5.4.5": "serialNumber",
        "2.5.4.6": "countryName",
        "2.5.4.7": "localityName",
        "2.5.4.8": "stateOrProvinceName",
        "2.5.4.9": "streetAddress",
        "2.5.4.10": "organizationName",
        "2.5.4.11": "organizationalUnitName",
        "2.5.4.12": "title",
        "2.5.4.42": "givenName",
        "2.5.4.43": "initials",
        "2.5.4.46": "dnQualifier",
        "0.9.2342.19200300.100.1.25": "domainComponent",
        "2.5.29.14": "X509v3 Subject Key Identifier",
        "2.5.29.15": "X509v3 Key Usage",
        "2.5.29.17": "X509v3 Subject Alternative Name",
        "2.5.29.18": "X509v3 Issuer Alternative Name",
        "2.5.29.19": "X509v3 Basic Constraints",
        "2.5.29.31": "X509v3 CRL Distribution Points",
        "2.5.29.32": "X509v3 Certificate Policies",
        "2.5.29.35": "X509v3 Authority Key Identifier",
        "2.5.29.37": "X509v3 Extended Key Usage",
        "1.3.6.1.5.5.7.1.1": "Authority Information Access",
        "1.3.6.1.5.5.7.3.1": "TLS Web Server Authentication",
        "1.3.6.1.5.5.7.3.2": "TLS Web Client Authentication",
        "1.3.6.1.5.5.7.3.3": "Code Signing",
        "1.3.6.1.5.5.7.3.4": "E-mail Protection",
        "1.3.6.1.5.5.7.48.1": "OCSP",
        "1.3.6.1.5.5.7.48.2": "CA Issuers",
        "2.16.840.1.113730.1.1": "Netscape Cert Type",
        "2.16.840.1.113730.1.13": "Netscape Comment",
    ]
}
