// swift-tools-version: 6.0
// Project Stride — StrideCore
//
// The game simulation. Pure logic, deterministic, no platform frameworks.
//
// This package MUST NOT depend on SwiftUI, UIKit, HealthKit, AVFoundation,
// CoreHaptics, or any other Apple framework. Platform integrations live in the
// app target behind protocols defined here.
//
// The rule is enforced by CorePurityTests and Scripts/check-core-purity.sh.
// See DECISIONS/0002_TECHNOLOGY_STACK.md.

import PackageDescription

let package = Package(
    name: "StrideCore",
    products: [
        .library(name: "StrideCore", targets: ["StrideCore"])
    ],
    dependencies: [
        // Intentionally empty. A runtime dependency here requires a decision record.
    ],
    targets: [
        .target(
            name: "StrideCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "StrideCoreTests",
            dependencies: ["StrideCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
