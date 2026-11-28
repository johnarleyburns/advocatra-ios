// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/crypto/src/derive.ts's `deriveDataKey`: an HKDF-SHA256
// per-purpose AES-256-GCM key, derived from the vault master key with an
// empty salt and the purpose string as HKDF info. An empty salt and an
// omitted salt are equivalent for HKDF-SHA256 (both zero-pad to the same
// HMAC block), so this matches Web Crypto's explicit `salt: new
// Uint8Array(0)` — verified empirically, not just argued, by
// AdvocatraVaultTests/CrossPlatformFixtureTests.swift's records-envelope
// vector, which exercises this exact function.
import CryptoKit
import Foundation

enum DataKey {
    static func derive(masterKeyMaterial: Data, purpose: EnvelopePurpose) -> SymmetricKey {
        let inputKey = SymmetricKey(data: masterKeyMaterial)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(),
            info: Data(purpose.rawValue.utf8),
            outputByteCount: 32
        )
    }
}
