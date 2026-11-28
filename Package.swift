// swift-tools-version: 6.0
// SPDX-License-Identifier: AGPL-3.0-only
import PackageDescription

// Linux deliberately resolves only the pure package and its tests, same as
// Saldima's own Package.swift. Apple builds add the SwiftUI app through the
// generated Xcode project (project.yml / xcodegen), not through this manifest.
//
// AdvocatraVault (crypto/networking/Keychain for the real vault) needs
// CryptoKit and Security, neither of which exist on Linux -- it's wrapped
// in `#if canImport(Darwin)` below so `swift test` on the Linux CI job
// simply doesn't see it, the same way the rest of this package stays
// portable. The Apple CI job's own `swift test` run is where it actually
// builds and runs, on a real Darwin host.
var products: [Product] = [
    .library(name: "AdvocatraCore", targets: ["AdvocatraCore"])
]
var targets: [Target] = [
    .target(
        name: "AdvocatraCore",
        path: "AdvocatraCore",
        swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
        name: "AdvocatraCoreTests",
        dependencies: ["AdvocatraCore"],
        path: "AdvocatraCoreTests",
        swiftSettings: [.swiftLanguageMode(.v6)]
    ),
]

#if canImport(Darwin)
products.append(.library(name: "AdvocatraVault", targets: ["AdvocatraVault"]))
targets.append(
    .target(
        name: "AdvocatraVault",
        path: "AdvocatraVault",
        swiftSettings: [.swiftLanguageMode(.v6)]
    )
)
targets.append(
    .testTarget(
        name: "AdvocatraVaultTests",
        dependencies: ["AdvocatraVault"],
        path: "AdvocatraVaultTests",
        swiftSettings: [.swiftLanguageMode(.v6)]
    )
)
#endif

let package = Package(
    name: "Advocatra",
    platforms: [.iOS("27.0"), .macOS(.v15)],
    products: products,
    targets: targets
)
