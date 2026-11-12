import CTCommon

/// Byte-oriented classical ciphers of CT1 (“Byteweise Addition”, “XOR”, “Vernam”). The key is
/// repeated cyclically over the data.
public enum ByteCiphers {
    /// Bytewise addition modulo 256 (CT1 "Byteweise Addition", encryption).
    public static func add(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        var out = data
        for i in out.indices { out[i] = out[i] &+ key[i % key.count] }
        return out
    }

    /// Bytewise subtraction modulo 256 (decryption of `add`).
    public static func subtract(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        var out = data
        for i in out.indices { out[i] = out[i] &- key[i % key.count] }
        return out
    }

    /// Bytewise XOR (self-inverse).
    public static func xor(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        var out = data
        for i in out.indices { out[i] ^= key[i % key.count] }
        return out
    }

    /// Vernam / one-time pad: XOR with a key file. Throws if the pad is empty or shorter than the
    /// data (CT1 only warned and reused the key cyclically – use `xor` for that behaviour).
    public static func vernam(_ data: [UInt8], pad: [UInt8]) throws -> [UInt8] {
        guard !pad.isEmpty else {
            throw CTError("Die Schlüsseldatei ist leer. Für die Vernam-Verschlüsselung wird ein Schlüssel benötigt, der mindestens so lang ist wie die Daten.")
        }
        guard pad.count >= data.count else {
            throw CTError("Der Schlüssel (\(pad.count) Byte) ist kürzer als die Daten (\(data.count) Byte). Bei der Vernam-Chiffre muss der Schlüssel mindestens so lang sein wie der Klartext.")
        }
        var out = data
        for i in out.indices { out[i] ^= pad[i] }
        return out
    }
}
