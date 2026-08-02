// CorePurityTests.swift
// Project Stride — StrideCore tests
//
// The architectural boundary, enforced.
//
// StrideCore must not depend on any platform framework. This is not purity for
// its own sake: it is what keeps the simulation testable in milliseconds without
// a simulator, keeps balance work independent of the UI, and means a future port
// re-implements a specified system rather than reverse-engineering one out of
// view code.
//
// See DECISIONS/0002_TECHNOLOGY_STACK.md and ARCHITECTURE_IMPLEMENTATION_PLAN.md §2.2.

import Foundation
import Testing
@testable import StrideCore

@Suite("StrideCore purity")
struct CorePurityTests {

    /// Locates `Sources/StrideCore` relative to this test file, so the check
    /// works from any working directory and on any machine.
    static var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)          // .../Tests/StrideCoreTests/CorePurityTests.swift
            .deletingLastPathComponent()          // .../Tests/StrideCoreTests
            .deletingLastPathComponent()          // .../Tests
            .deletingLastPathComponent()          // package root
            .appendingPathComponent("Sources")
            .appendingPathComponent("StrideCore")
    }

    static func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }

    /// Matches a real import statement, not the word appearing in a comment or
    /// a string literal. Handles `import X`, `import X.Y`, and `@testable import X`.
    static func importedModules(in source: String) -> [String] {
        source
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let withoutTestable = trimmed.hasPrefix("@testable ")
                    ? String(trimmed.dropFirst("@testable ".count)).trimmingCharacters(in: .whitespaces)
                    : trimmed
                guard withoutTestable.hasPrefix("import ") else { return nil }
                let module = withoutTestable
                    .dropFirst("import ".count)
                    .trimmingCharacters(in: .whitespaces)
                    .split(separator: ".")
                    .first
                    .map(String.init)
                return module
            }
    }

    @Test("Sources directory is discoverable")
    func sourcesDirectoryIsDiscoverable() throws {
        let files = try Self.swiftFiles(in: Self.sourcesDirectory)
        // A silently empty scan would let this suite pass while checking nothing.
        #expect(!files.isEmpty, "No Swift sources found at \(Self.sourcesDirectory.path)")
    }

    @Test("No source file imports a platform framework")
    func noSourceImportsPlatformFramework() throws {
        let forbidden = Set(StrideCore.forbiddenImports)
        var violations: [String] = []

        for file in try Self.swiftFiles(in: Self.sourcesDirectory) {
            let source = try String(contentsOf: file, encoding: .utf8)
            for module in Self.importedModules(in: source) where forbidden.contains(module) {
                violations.append("\(file.lastPathComponent): import \(module)")
            }
        }

        #expect(
            violations.isEmpty,
            """
            StrideCore must not import platform frameworks.
            Violations:
            \(violations.joined(separator: "\n"))

            Fix by moving the platform work into the app target behind a protocol
            defined in StrideCore. Do not relax this rule.
            """
        )
    }

    @Test("The detector recognizes a violation")
    func detectorRecognizesViolation() {
        // Guards against the check silently breaking and passing forever.
        let sample = """
        // A comment mentioning SwiftUI must not trigger the check.
        let name = "HealthKit"
        import Foundation
        @testable import UIKit
        import AVFoundation.AVAudioEngine
        """
        let modules = Self.importedModules(in: sample)
        #expect(modules.contains("Foundation"))
        #expect(modules.contains("UIKit"))
        #expect(modules.contains("AVFoundation"))
        #expect(!modules.contains("SwiftUI"), "A comment must not be read as an import")

        let forbidden = Set(StrideCore.forbiddenImports)
        let caught = modules.filter { forbidden.contains($0) }
        #expect(Set(caught) == ["UIKit", "AVFoundation"])
    }
}
