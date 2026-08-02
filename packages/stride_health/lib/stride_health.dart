/// Project Stride first-party step integration.
///
/// HealthKit on iOS, Health Connect on Android, behind one Pigeon-typed
/// boundary and one platform-neutral `StepProvider` from `stride_core`.
///
/// M-2 scope: the boundary, the Dart adapters, and native shells. The real
/// HealthKit and Health Connect implementations arrive in S-01 and S-01b.
library;

export 'src/mock_step_provider.dart';
export 'src/origin_pseudonymizer.dart';
export 'src/platform_step_provider.dart';
