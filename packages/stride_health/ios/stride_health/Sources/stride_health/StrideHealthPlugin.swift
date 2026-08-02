import Flutter
import UIKit

/// Project Stride — iOS step integration.
///
/// M-2 scope: registration and the Pigeon boundary only. The HealthKit
/// implementation is task S-01b.
///
/// See DECISIONS/0010_CROSS_PLATFORM_STACK.md.
public class StrideHealthPlugin: NSObject, FlutterPlugin {

    private static var adapter: HealthKitAdapter?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let created = HealthKitAdapter()
        adapter = created
        HealthHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: created)
    }
}
