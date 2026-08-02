// The platform boundary — single source of truth for all three sides.
//
// Regenerate after any change:
//   cd packages/stride_health
//   dart run pigeon --input pigeons/health_api.dart
//
// Generated files are committed, and CI fails when they are stale. A contract
// change that is not reflected on all three sides fails to *compile* — with an
// untyped MethodChannel it would fail at runtime, as a null, in the system that
// decides whether the player's walk counted.
//
// The surface is deliberately tiny: three methods. That narrowness is what
// makes cross-platform fidelity achievable, and it is a property of steps-only
// integration.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/projectstride/stride_health/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.projectstride.stride_health'),
    // The plugin uses the Swift Package Manager layout. Generating into
    // ios/Classes/ would produce a file that is never compiled.
    swiftOut: 'ios/stride_health/Sources/stride_health/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'stride_health',
  ),
)
/// Mirrors `StepAuthorization` in stride_core.
enum PlatformAuthorization { granted, denied, unavailable }

/// Mirrors `CursorStatus` in stride_core.
enum PlatformCursorStatus { valid, invalidated }

/// An authoritative re-read of a bounded window, sent only when the cursor was
/// invalidated. See `StepRescan` in stride_core for the recovery strategy.
class PlatformRescan {
  PlatformRescan({
    required this.windowStartMillis,
    required this.windowEndMillis,
    required this.windowTotal,
    required this.truncated,
  });

  /// Start of the rescanned window — the watermark the caller supplied,
  /// clamped by the adapter to its maximum window.
  final int windowStartMillis;

  final int windowEndMillis;

  /// The authoritative total for the window. A total, not a delta: after cursor
  /// loss only an absolute figure can be reconciled against what was already
  /// granted.
  final int windowTotal;

  /// True when the window was clamped, leaving an unreachable gap. Those steps
  /// are recorded, never granted — inventing progress is worse than missing it.
  final bool truncated;
}

class PlatformFetchResult {
  PlatformFetchResult({
    required this.status,
    required this.newSteps,
    required this.deletedSteps,
    this.cursor,
    this.rescan,
  });

  final PlatformCursorStatus status;

  /// A true delta only when [status] is `valid`. Meaningless otherwise.
  final int newSteps;

  /// Steps removed by corrections since the cursor. Information, not an
  /// instruction — reconciliation never revokes granted progress.
  final int deletedSteps;

  /// Opaque. An archived HKQueryAnchor on iOS, a changes token on Android.
  /// The caller stores and returns it without inspecting it, and persists it
  /// only after the resulting batch is committed to the ledger.
  final Uint8List? cursor;

  final PlatformRescan? rescan;
}

@HostApi()
abstract class HealthHostApi {
  /// Whether the platform's health service is present and usable. False on
  /// Android without Health Connect installed — a normal state, not an error.
  bool isAvailable();

  @async
  PlatformAuthorization requestAuthorization();

  /// Fetch steps since [cursor]. [watermarkMillis] bounds the rescan window if
  /// the cursor turns out to be invalid.
  @async
  PlatformFetchResult fetchNewSteps(Uint8List? cursor, int? watermarkMillis);
}
