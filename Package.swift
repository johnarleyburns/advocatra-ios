// swift-tools-version: 6.0
// SPDX-License-Identifier: AGPL-3.0-only
import PackageDescription

// Linux deliberately resolves only the pure package and its tests, same as
// Saldima's own Package.swift. Apple builds add the SwiftUI app through the
// generated Xcode project (project.yml / xcodegen), not through this manifest.
let package = Package(
    name: "Advocatra",
    platforms: [.iOS("27.0"), .macOS(.v15)],
    products: [
        .library(name: "AdvocatraCore", targets: ["AdvocatraCore"])
    ],
    targets: [
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
)
