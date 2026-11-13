import Foundation
import CTCommon
import CTBigNum
import CTModern

/// Asymmetric key types supported by the local PKI (CT1: "Schlüssel erzeugen/importieren").
enum AsymmetricKeyType: Codable, Hashable {
    case rsa(bits: Int)
    case ecc(curve: String)
    case dsa(bits: Int)

    /// CT1 key type column ("RSA-1024", "DSA-1024", "EC-prime239v1").
    var displayName: String {
        switch self {
        case .rsa(let bits): return "RSA-\(bits)"
        case .ecc(let curve): return "EC-\(curve)"
        case .dsa(let bits): return "DSA-\(bits)"
        }
    }

    var kind: PKIKeyKind {
        switch self {
        case .rsa: return .rsa
        case .ecc: return .ec
        case .dsa: return .dsa
        }
    }

    var isRSA: Bool { kind == .rsa }
}

/// Key families of CT1's type filter ("RSA-Schlüssel", "DSA-Schlüssel", "EC-Schlüssel").
enum PKIKeyKind: String, CaseIterable, Hashable {
    case rsa, dsa, ec
}

/// Entry of the key store. Private keys are encrypted with a PIN derived AES key
/// (PBKDF2-HMAC-SHA-256, AES-256-CBC).
struct StoredKey: Codable, Identifiable, Hashable {
    var id: UUID
    var lastName: String
    var firstName: String
    var label: String
    var created: Date
    var type: AsymmetricKeyType
    var rsaPublic: RSAPublicKey?
    var ecCurveName: String?
    var ecPublic: ECPoint?
    var dsaParameters: DSAParameters?
    var dsaPublic: BigUInt?
    var salt: Data
    var encryptedPrivate: Data

    var ownerDescription: String { "\(lastName), \(firstName)" + (label.isEmpty ? "" : " (\(label))") }
    var listTitle: String { "\(ownerDescription) – \(type.displayName)" }

    var curve: EllipticCurve? {
        guard let n = ecCurveName else { return nil }
        return EllipticCurve.anyNamed(n)
    }

    // MARK: CT1 naming

    /// Seconds since 1970 – CT1's "Interne ID-Nr." (part of the key identifier).
    var internalID: String { String(Int(created.timeIntervalSince1970)) }

    /// CT1 "Erstellt am" (dd.MM.yyyy HH:mm:ss, local time).
    var createdString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f.string(from: created)
    }

    /// CT1 key identifier (PSE file name): "[Name][Vorname][RSA-1024][<sec>][Kennung]".
    var ct1Identifier: String {
        "[\(lastName)][\(firstName)][\(type.displayName)][\(internalID)]" + (label.isEmpty ? "" : "[\(label)]")
    }

    /// CT1 distinguished name of the certificate (CKeyFile::CreateDistName).
    var distinguishedName: String { "CN=\(firstName) \(lastName) [\(internalID)], DC=cryptool, DC=org" }

    /// "Vorname Name" as used in CT1 window titles.
    var firstLast: String { "\(firstName) \(lastName)" }
}

enum PrivateKeyMaterial: Codable {
    case rsa(RSAKeyPair)
    case ecc(ECKeyPair)
    case dsa(DSAKeyPair)
}

@MainActor
final class KeyStore: ObservableObject {
    static let shared = KeyStore()
    @Published private(set) var keys: [StoredKey] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrypTool", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("keys.json")
    }

    private init() { load() }

    private func load() {
        guard let d = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        keys = (try? dec.decode([StoredKey].self, from: d)) ?? []
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(keys) {
            try? d.write(to: fileURL, options: .atomic)
        }
    }

    private static func pinKey(_ pin: String, salt: [UInt8]) throws -> [UInt8] {
        try PasswordKeyDerivation.pbkdf2(password: Array(pin.utf8), salt: salt, iterations: 20_000, keyLength: 32, hash: .sha256)
    }

    @discardableResult
    func add(lastName: String, firstName: String, label: String, material: PrivateKeyMaterial, pin: String,
             created: Date = Date()) throws -> StoredKey {
        var salt = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        let plain = try JSONEncoder().encode(material)
        // prepend a check value so a wrong PIN is detected reliably
        let payload = Array("CTKEY1".utf8) + [UInt8](plain)
        let encrypted = try SymmetricCipher.encrypt(.aes, key: try KeyStore.pinKey(pin, salt: salt), data: payload)
        // CT1 identifiers contain the creation second – keep them unique
        var date = Date(timeIntervalSince1970: created.timeIntervalSince1970.rounded(.down))
        while keys.contains(where: { Int($0.created.timeIntervalSince1970) == Int(date.timeIntervalSince1970) }) {
            date += 1
        }
        var entry = StoredKey(id: UUID(), lastName: lastName, firstName: firstName, label: label, created: date,
                              type: .rsa(bits: 0), rsaPublic: nil, ecCurveName: nil, ecPublic: nil,
                              dsaParameters: nil, dsaPublic: nil,
                              salt: Data(salt), encryptedPrivate: Data(encrypted))
        switch material {
        case .rsa(let k):
            entry.type = .rsa(bits: k.n.bitLength)
            entry.rsaPublic = k.publicKey
        case .ecc(let k):
            entry.type = .ecc(curve: k.curve.name)
            entry.ecCurveName = k.curve.name
            entry.ecPublic = k.Q
        case .dsa(let k):
            entry.type = .dsa(bits: k.parameters.p.bitLength)
            entry.dsaParameters = k.parameters
            entry.dsaPublic = k.y
        }
        keys.append(entry)
        save()
        return entry
    }

    func privateKey(of entry: StoredKey, pin: String) throws -> PrivateKeyMaterial {
        let k = try KeyStore.pinKey(pin, salt: [UInt8](entry.salt))
        guard let d = try? SymmetricCipher.decrypt(.aes, key: k, data: [UInt8](entry.encryptedPrivate)),
              d.starts(with: Array("CTKEY1".utf8)) else {
            throw CTError("Incorrect PIN code entered.")
        }
        return try JSONDecoder().decode(PrivateKeyMaterial.self, from: Data(d.dropFirst(6)))
    }

    func delete(_ entry: StoredKey) {
        keys.removeAll { $0.id == entry.id }
        save()
    }

    func key(id: UUID) -> StoredKey? { keys.first { $0.id == id } }

    /// Finds a key by its CT1 identifier ("[Name][Vorname][RSA-1024][…]").
    func key(ct1Identifier: String) -> StoredKey? {
        let t = ct1Identifier.trimmingCharacters(in: .whitespaces)
        return keys.first { $0.ct1Identifier == t }
    }
}
