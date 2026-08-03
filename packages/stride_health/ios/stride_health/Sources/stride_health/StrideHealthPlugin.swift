import Flutter
import UIKit

/// Project Stride — iOS step integration.
///
/// S-01A scope: registration, the Pigeon boundary, and the FOREGROUND
/// HealthKit reader in `HealthKitStepStore`.
///
/// There is deliberately no `HKObserverQuery`, no `enableBackgroundDelivery`,
/// and no background mode registered here. Background synchronization is S-01B
/// and is blocked on a real persistence coordinator — see `DECISIONS/0014`.
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

        // Published so the engine has somewhere to deliver the detach
        // callback. Without a published instance `detachFromEngineForRegistrar:`
        // is never sent, and the salt would outlive the attachment it belongs
        // to — which is the difference between "in memory for the lifetime of
        // the attachment" as a claim and as a fact.
        registrar.publish(StrideHealthPlugin())
    }

    /// Drops the keying salt when the engine goes away.
    ///
    /// After this, `fetchSteps` is fail-closed again with
    /// `originKeyingUnconfigured` until the app installs the identity afresh.
    /// Nothing is written anywhere on the way out: there is no native store to
    /// flush, by design.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        StrideHealthPlugin.adapter?.forgetOriginKeying()
        StrideHealthPlugin.adapter = nil
        HealthHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    }
}
