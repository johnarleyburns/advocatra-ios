// SPDX-License-Identifier: AGPL-3.0-only
//
// Stores the unwrapped vault master key in the Keychain, gated by
// biometrics or device passcode (`.userPresence`) and device-only
// (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never synced to iCloud
// Keychain) — see TECHNICAL-DESIGN.md §5's explicit iOS requirement.
//
// Not covered by AdvocatraVaultTests: `.userPresence` access control
// requires an interactive biometric/passcode prompt, which a headless CI
// runner has no way to satisfy. Verify this manually on a real device —
// see the PR description.
import Foundation
import Security

public enum VaultKeychainError: Error {
    case accessControlCreationFailed
    case storeFailed(OSStatus)
    case readFailed(OSStatus)
}

public enum VaultKeychain {
    private static let service = "guru.parso.advocatra.vault-master-key"

    public static func store(masterKeyMaterial: Data, account: String) throws {
        var accessControlError: Unmanaged<CFError>?
        guard
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &accessControlError
            )
        else {
            throw VaultKeychainError.accessControlCreationFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = masterKeyMaterial
        attributes[kSecAttrAccessControl as String] = accessControl

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultKeychainError.storeFailed(status) }
    }

    public static func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultKeychainError.readFailed(status) }
        return result as? Data
    }

    public static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
