// SPDX-License-Identifier: AGPL-3.0-only
//
// Crockford base32 recovery code generation and formatting. Ported
// line-for-line (pure logic, no crypto library involved) from
// packages/crypto/src/recovery.ts.

/// Shown to the user exactly once, at vault creation. Never stored, never
/// uploaded — losing both this and the passphrase makes the vault
/// permanently unrecoverable, by design.
public enum RecoveryCode {
    /// Crockford base32's 32-symbol alphabet: digits plus A-Z excluding I,
    /// L, O and U (each dropped for looking like another symbol), so a
    /// user can transcribe it by hand without guessing.
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let groupSize = 5
    private static let groupCount = 5

    public static func generate() -> String {
        let bytes = (0..<20).map { _ in UInt8.random(in: 0...255) }
        let raw = String(encodeBase32(bytes).prefix(groupSize * groupCount))
        var groups: [String] = []
        var index = raw.startIndex
        while index < raw.endIndex {
            let end = raw.index(index, offsetBy: groupSize, limitedBy: raw.endIndex) ?? raw.endIndex
            groups.append(String(raw[index..<end]))
            index = end
        }
        return groups.joined(separator: "-")
    }

    private static func encodeBase32(_ bytes: [UInt8]) -> String {
        var bits = 0
        var value = 0
        var output = ""
        for byte in bytes {
            value = (value << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                output.append(alphabet[(value >> (bits - 5)) & 0x1f])
                bits -= 5
            }
        }
        if bits > 0 {
            output.append(alphabet[(value << (5 - bits)) & 0x1f])
        }
        return output
    }
}
