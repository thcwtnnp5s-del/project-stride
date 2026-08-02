// AppShellTests.swift
// Project Stride — app target tests
//
// F-01 scope: prove the app target links StrideCore and honors its platform
// constraints. Gameplay tests live in StrideCoreTests, where they run without a
// simulator.

import XCTest
import StrideCore
@testable import Stride

final class AppShellTests: XCTestCase {

    func testAppTargetLinksStrideCore() {
        XCTAssertFalse(StrideCore.version.isEmpty)
    }

    func testDeploymentTargetIsIOS17() throws {
        // `MinimumOSVersion` is injected into the built Info.plist from the
        // target's deployment target, so this checks the build setting itself.
        //
        // An earlier version asserted the *runtime* OS version, which passes on
        // any modern device regardless of how the target is configured — a test
        // that could not fail for the reason it claimed to test.
        let minimum = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String
        )
        XCTAssertEqual(
            minimum, "17.0",
            "Deployment target must be iOS 17.0. See DECISIONS/0009."
        )
    }

    func testTargetsIPhoneOnly() throws {
        let families = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int]
        )
        XCTAssertEqual(
            families, [1],
            "Milestone 01 is iPhone only — no iPad idiom. See DECISIONS/0009."
        )
    }

    func testSupportsPortraitOnly() throws {
        let orientations = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String]
        )
        XCTAssertEqual(
            orientations,
            ["UIInterfaceOrientationPortrait"],
            "Milestone 01 is portrait only. See DECISIONS/0009."
        )
    }
}
