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
        // A fresh adapter per registration, and therefore no keying salt until
        // the app installs one. That is the fail-closed path: `fetchSteps`
        // refuses with `originKeyingUnconfigured` until `installOriginKeying`
        // has succeeded, because observations keyed under no salt would re-key
        // every origin and grant the retention window a second time.
        adapter?.forgetOriginKeying()
        let created = HealthKitAdapter()
        adapter = created
        HealthHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: created)
    }
}
