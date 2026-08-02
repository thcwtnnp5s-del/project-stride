// ModuleTests.swift
// Project Stride — StrideCore tests
//
// Proves the package builds, links, and is testable without a simulator.

import Testing
@testable import StrideCore

@Suite("StrideCore module")
struct ModuleTests {

    @Test("Module exposes a version")
    func moduleExposesVersion() {
        #expect(!StrideCore.version.isEmpty)
    }

    @Test("Forbidden import list is populated")
    func forbiddenImportListIsPopulated() {
        // CorePurityTests is only meaningful if this list has content. An empty
        // list would make the purity test pass vacuously forever.
        #expect(StrideCore.forbiddenImports.count >= 5)
        #expect(StrideCore.forbiddenImports.contains("SwiftUI"))
        #expect(StrideCore.forbiddenImports.contains("HealthKit"))
    }
}
