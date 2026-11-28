// SPDX-License-Identifier: AGPL-3.0-only
import CryptoKit
import Foundation
import Testing

@testable import AdvocatraVault

@Suite struct VaultKeyTests {
    @Test func unwrapsWhatItWrapped() throws {
        let kek = SymmetricKey(size: .bits256)
        let material = VaultKey.generateMasterKeyMaterial()
        let wrapped = try VaultKey.wrap(material: material, kek: kek)
        let unwrapped = try VaultKey.unwrap(wrapped: wrapped, kek: kek)
        #expect(unwrapped == material)
    }

    @Test func aDifferentKekCannotUnwrap() throws {
        let material = VaultKey.generateMasterKeyMaterial()
        let wrapped = try VaultKey.wrap(material: material, kek: SymmetricKey(size: .bits256))
        #expect(throws: (any Error).self) {
            try VaultKey.unwrap(wrapped: wrapped, kek: SymmetricKey(size: .bits256))
        }
    }

    @Test func generatesDistinctMasterKeysEveryCall() {
        #expect(VaultKey.generateMasterKeyMaterial() != VaultKey.generateMasterKeyMaterial())
    }
}
