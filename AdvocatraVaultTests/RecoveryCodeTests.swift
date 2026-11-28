// SPDX-License-Identifier: AGPL-3.0-only
//
// Mirrors packages/crypto/src/recovery.test.ts's structure.
import Testing

@testable import AdvocatraVault

@Suite struct RecoveryCodeTests {
    @Test func producesFiveGroupsOfFiveCrockfordBase32CharactersHyphenSeparated() {
        let code = RecoveryCode.generate()
        let groups = code.split(separator: "-", omittingEmptySubsequences: false)
        #expect(groups.count == 5)
        for group in groups {
            #expect(group.count == 5)
            #expect(group.allSatisfy { "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains($0) })
        }
    }

    @Test func neverContainsTheExcludedLookAlikeLettersILOU() {
        for _ in 0..<20 {
            #expect(!RecoveryCode.generate().contains(where: { "ILOU".contains($0) }))
        }
    }

    @Test func isNotDeterministicAcrossCalls() {
        #expect(RecoveryCode.generate() != RecoveryCode.generate())
    }
}
