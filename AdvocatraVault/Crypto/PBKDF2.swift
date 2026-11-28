// SPDX-License-Identifier: AGPL-3.0-only
//
// PBKDF2-HMAC-SHA256 (RFC 8018), hand-assembled from CryptoKit's HMAC --
// CryptoKit has no PBKDF2 of its own. Mirrors packages/crypto's use of Web
// Crypto's native PBKDF2 (`deriveKeyEncryptionKey` in passphrase-kdf.ts);
// verified byte-identical against it, not just internally consistent --
// see AdvocatraVaultTests/CrossPlatformFixtureTests.swift.
import CryptoKit
import Foundation

enum PBKDF2 {
    private static let hashLength = 32 // SHA-256 digest size

    static func deriveBits(password: Data, salt: Data, iterations: Int, byteCount: Int) -> Data {
        let key = SymmetricKey(data: password)
        let blockCount = (byteCount + hashLength - 1) / hashLength
        var output = Data()

        for blockIndex in 1...blockCount {
            let blockIndexBytes = withUnsafeBytes(of: UInt32(blockIndex).bigEndian) { Data($0) }
            var u = Data(HMAC<SHA256>.authenticationCode(for: salt + blockIndexBytes, using: key))
            var blockResult = u
            for _ in 1..<iterations {
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                blockResult = Data(zip(blockResult, u).map { $0 ^ $1 })
            }
            output.append(blockResult)
        }
        return output.prefix(byteCount)
    }
}
