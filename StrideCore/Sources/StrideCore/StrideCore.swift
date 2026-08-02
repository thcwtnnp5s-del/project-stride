// StrideCore.swift
// Project Stride — StrideCore
//
// Module marker and build metadata. No gameplay lives here.
//
// F-01 establishes the package and its boundary only. Game state, events, and
// the engine arrive in F-03; content schemas in F-02.

/// Namespace for module-level metadata.
public enum StrideCore {

    /// The version of the core simulation module.
    ///
    /// Distinct from the app's marketing version and from the save schema
    /// version in `SaveEnvelope` (F-05). Bumped when simulation rules change in
    /// a way that affects outcomes.
    public static let version = "0.1.0"

    /// Frameworks this module must never import.
    ///
    /// Declared here so the rule is discoverable from inside the module it
    /// governs, and read by `CorePurityTests` so the test and the rule cannot
    /// drift apart.
    ///
    /// See `DECISIONS/0002_TECHNOLOGY_STACK.md`.
    public static let forbiddenImports = [
        "SwiftUI",
        "UIKit",
        "AppKit",
        "HealthKit",
        "AVFoundation",
        "AVFAudio",
        "CoreHaptics",
        "CoreLocation",
        "CoreMotion",
        "WidgetKit",
        "Combine"
    ]
}
