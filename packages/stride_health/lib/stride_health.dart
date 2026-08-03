/// Project Stride first-party step integration.
///
/// HealthKit on iOS, Health Connect on Android, behind one Pigeon-typed
/// boundary that produces the value the simulation actually consumes — a
/// `SyncResponse` from `stride_core`.
///
/// S-01A scope: the boundary, the Dart bridge, the origin-privacy gateway, and
/// native shells. The real HealthKit and Health Connect reads follow.
///
/// The `StepProvider` / `StepFetchResult` model this package used to implement
/// is gone, not deprecated. See `DECISIONS/0014`.
///
/// `messages.g.dart` is deliberately NOT exported. The generated platform types
/// — and `PlatformStepObservation.sourceIdentifier` in particular — must not be
/// reachable from outside this package. See `src/origin_gateway.dart`.
library;

export 'src/cursor_authorization.dart';
export 'src/mock_step_source.dart';
export 'src/origin_gateway.dart';
export 'src/origin_pseudonymizer.dart';
export 'src/platform_step_source.dart';
export 'src/step_sync_source.dart';
