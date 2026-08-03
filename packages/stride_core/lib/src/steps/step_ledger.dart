import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'step_origin_key.dart';
import 'sync_batch.dart';

/// How the provider last presented itself.
enum SourceState {
  /// Never contacted.
  unknown,

  /// Answering normally.
  available,

  /// Present but not authorized, or authorization is indeterminate.
  permissionUnavailable,

  /// Absent — no Health Connect app, no HealthKit.
  serviceUnavailable,

  /// Failed in a way that may succeed later.
  transientlyUnavailable,

  /// The adapter has no origin-keying identity, so it refused to read.
  ///
  /// A **configuration** state, not a platform one: the service may be present
  /// and authorized. It is held separately from [serviceUnavailable] because
  /// the fix is different — reconnect the health source so the adapter is
  /// reopened with the device-bound identity — and because retrying alone can
  /// never clear it.
  ///
  /// The developer harness surfaces this as configuration-blocked.
  originKeyingUnconfigured,
}

/// Whether a bounded recovery is in flight.
///
/// Recovery is a two-phase operation: read authoritatively, then commit. If the
/// process dies between them, the ledger must be able to tell that a recovery
/// was started and was never finished — otherwise a retry cannot know whether
/// the first attempt already granted.
enum RecoveryPhase {
  /// No recovery in progress.
  idle,

  /// A rescan has been requested and not yet committed.
  awaitingCommit,
}

/// The state of an in-flight recovery.
@immutable
final class RecoveryState {
  const RecoveryState({
    required this.phase,
    this.windowStartMillis,
    this.windowEndMillis,
    this.truncated = false,
    this.attempts = 0,
  });

  const RecoveryState.idle() : this(phase: RecoveryPhase.idle);

  final RecoveryPhase phase;
  final int? windowStartMillis;
  final int? windowEndMillis;

  /// The rescan window was clamped; the gap is unreachable and ungranted.
  final bool truncated;

  /// How many times recovery has been attempted. Diagnostic only — the
  /// reconciler's behaviour does not depend on it, because a retry must produce
  /// the same answer as the first try.
  final int attempts;

  bool get isActive => phase != RecoveryPhase.idle;

  @override
  bool operator ==(Object other) =>
      other is RecoveryState &&
      other.phase == phase &&
      other.windowStartMillis == windowStartMillis &&
      other.windowEndMillis == windowEndMillis &&
      other.truncated == truncated &&
      other.attempts == attempts;

  @override
  int get hashCode => Object.hash(
    phase,
    windowStartMillis,
    windowEndMillis,
    truncated,
    attempts,
  );
}

/// Where synchronization last got to.
///
/// The cursor here is **authorized for persistence**. It is only ever written by
/// the checkpoint event, which the reducer applies *after* the grant event — so
/// a process that dies mid-commit leaves the old cursor in place and the retry
/// recomputes the same result.
@immutable
final class SyncCheckpoint {
  SyncCheckpoint({
    this.cursor,
    this.watermarkMillis,
    Map<StepOriginKey, int>? originWatermarks,
    this.syncCount = 0,
  }) : originWatermarks = UnmodifiableMapView<StepOriginKey, int>(
         SplayTreeMap<StepOriginKey, int>.of(
           originWatermarks ?? const <StepOriginKey, int>{},
         ),
       );

  SyncCheckpoint.initial() : this();

  /// The cursor safe to hand back to the provider next time.
  final SyncCursor? cursor;

  /// The lowest per-origin watermark. **Diagnostic only.**
  ///
  /// Deliberately not used to decide whether a slice is settled. A single
  /// scalar cannot express "settled for the phone, still open for the watch",
  /// and using one for that is a lost grant: an origin that has never synced
  /// has its whole history settled the first time some *other* origin's data
  /// pushed a global horizon past it.
  final int? watermarkMillis;

  /// Per origin, the point through which that origin is fully accounted for.
  ///
  /// An origin absent from this map has never been vouched for, so **nothing**
  /// of its is settled. That is the correct default: silence about a source is
  /// not an assertion about it.
  ///
  /// This is what makes a returning player's offline watch safe. The phone
  /// syncing hourly for a fortnight says nothing about the watch, so the
  /// watch's backlog is still grantable when it finally arrives.
  final Map<StepOriginKey, int> originWatermarks;

  /// How many syncs have committed. Gives a replayed batch something to be
  /// idempotent *against* without needing a clock.
  final int syncCount;

  @override
  bool operator ==(Object other) =>
      other is SyncCheckpoint &&
      other.cursor == cursor &&
      other.watermarkMillis == watermarkMillis &&
      const MapEquality<StepOriginKey, int>().equals(
        other.originWatermarks,
        originWatermarks,
      ) &&
      other.syncCount == syncCount;

  @override
  int get hashCode => Object.hash(
    cursor,
    watermarkMillis,
    const MapEquality<StepOriginKey, int>().hash(originWatermarks),
    syncCount,
  );
}

/// The step ledger.
///
/// ## Terminology
///
/// | Field | Meaning | Monotonic? |
/// |---|---|---|
/// | [totalObserved] | What the source currently says it has recorded | **No** — a correction or deletion lowers it |
/// | [totalGranted] | What the game has credited the player | **Yes** — never decreases, ever |
/// | [totalSpent] | What has been committed to activities | Yes |
/// | [banked] | Earned and unspent | derived |
///
/// The distinction between observed and granted is the whole safety argument.
/// If granted were derived from the latest observed total, a health correction
/// would silently revoke progress the player already earned and spent. Instead
/// observed may fall, granted may not, and the difference is simply recorded.
///
/// **`banked = totalGranted - totalSpent`**, and `0 <= totalSpent <= totalGranted`.
/// Both are asserted on every construction.
///
/// ## What is persisted, and why
///
/// See `TECHNICAL/STEP_LEDGER_PRIVACY.md`. In short: four counters, a checkpoint,
/// and a **bounded** map of already-granted amounts per `(origin, bucket)` for
/// the recent window only. That map is what makes replay, overlap, and
/// multi-device sync safe, and it is compacted into [grantedBeforeWatermark] as
/// soon as slices age out — so nothing resembling a step history accumulates.
@immutable
final class StepLedger {
  StepLedger({
    required this.totalObserved,
    required this.totalGranted,
    required this.totalSpent,
    required Map<ObservationKey, int> grantedSlices,
    required this.grantedBeforeWatermark,
    required this.checkpoint,
    required this.recovery,
    required this.sourceState,
    required this.correctionsObserved,
    required this.unreachableGapEvents,
    required this.lateDiscardedSlices,
  }) : grantedSlices = UnmodifiableMapView<ObservationKey, int>(
         SplayTreeMap<ObservationKey, int>.of(grantedSlices),
       ) {
    if (totalGranted < 0 || totalObserved < 0 || totalSpent < 0) {
      throw ArgumentError('ledger totals cannot be negative: $this');
    }
    if (totalSpent > totalGranted) {
      throw ArgumentError(
        'spent ($totalSpent) cannot exceed granted ($totalGranted): '
        'the player would owe steps they never earned',
      );
    }
  }

  StepLedger.initial()
    : totalObserved = 0,
      totalGranted = 0,
      totalSpent = 0,
      grantedSlices = UnmodifiableMapView<ObservationKey, int>(
        SplayTreeMap<ObservationKey, int>(),
      ),
      grantedBeforeWatermark = 0,
      checkpoint = SyncCheckpoint.initial(),
      recovery = const RecoveryState.idle(),
      sourceState = SourceState.unknown,
      correctionsObserved = 0,
      unreachableGapEvents = 0,
      lateDiscardedSlices = 0;

  /// The source's current view. May fall.
  final int totalObserved;

  /// What the player has been credited. Never falls.
  final int totalGranted;

  /// What has been committed to activities.
  final int totalSpent;

  /// Steps already granted per slice, for slices newer than the watermark.
  ///
  /// **Bounded.** Compacted into [grantedBeforeWatermark] once a slice ages past
  /// the retention horizon.
  final Map<ObservationKey, int> grantedSlices;

  /// Granted amount for everything compacted away.
  ///
  /// Keeps [totalGranted] reconstructable without retaining the slices.
  final int grantedBeforeWatermark;

  final SyncCheckpoint checkpoint;
  final RecoveryState recovery;
  final SourceState sourceState;

  /// How many downward corrections have been seen. Diagnostic; never affects
  /// granted progress.
  final int correctionsObserved;

  /// How many rescans were truncated, leaving an unreachable gap.
  final int unreachableGapEvents;

  /// How many observations arrived after their bucket had been compacted.
  ///
  /// Non-zero means real steps were probably lost. It is a counter rather than
  /// silence because this is the one lossy path in the design.
  final int lateDiscardedSlices;

  /// Earned and unspent. Never expires (`DECISIONS/0008`).
  int get banked => totalGranted - totalSpent;

  /// How much the source has walked back relative to what was granted.
  ///
  /// Recorded, never collected. It exists so a support question — "why does the
  /// game say more than Health does?" — has an answer.
  int get grantedAheadOfObserved =>
      totalGranted > totalObserved ? totalGranted - totalObserved : 0;

  /// Steps already granted for [key], or zero if unknown.
  ///
  /// A slice older than the watermark returns zero, which is correct: the
  /// reconciler treats pre-watermark slices as fully settled and grants nothing
  /// further for them.
  int grantedFor(ObservationKey key) => grantedSlices[key] ?? 0;

  bool isSettled(ObservationKey key) {
    // Per origin. An origin nobody vouched for has nothing settled — see
    // [SyncCheckpoint.originWatermarks] for why the scalar cannot do this job.
    final int? watermark = checkpoint.originWatermarks[key.origin];
    return watermark != null && key.bucket.endMillis <= watermark;
  }

  StepLedger copyWith({
    int? totalObserved,
    int? totalGranted,
    int? totalSpent,
    Map<ObservationKey, int>? grantedSlices,
    int? grantedBeforeWatermark,
    SyncCheckpoint? checkpoint,
    RecoveryState? recovery,
    SourceState? sourceState,
    int? correctionsObserved,
    int? unreachableGapEvents,
    int? lateDiscardedSlices,
  }) => StepLedger(
    totalObserved: totalObserved ?? this.totalObserved,
    totalGranted: totalGranted ?? this.totalGranted,
    totalSpent: totalSpent ?? this.totalSpent,
    grantedSlices: grantedSlices ?? this.grantedSlices,
    grantedBeforeWatermark:
        grantedBeforeWatermark ?? this.grantedBeforeWatermark,
    checkpoint: checkpoint ?? this.checkpoint,
    recovery: recovery ?? this.recovery,
    sourceState: sourceState ?? this.sourceState,
    correctionsObserved: correctionsObserved ?? this.correctionsObserved,
    unreachableGapEvents: unreachableGapEvents ?? this.unreachableGapEvents,
    lateDiscardedSlices: lateDiscardedSlices ?? this.lateDiscardedSlices,
  );

  /// Commits [steps] to an activity.
  ///
  /// Returns null when the player does not have them — spending is refused, not
  /// clamped, because silently spending less than asked would leave the caller
  /// believing it got what it requested.
  StepLedger? spending(int steps) {
    if (steps <= 0 || steps > banked) return null;
    return copyWith(totalSpent: totalSpent + steps);
  }

  @override
  bool operator ==(Object other) =>
      other is StepLedger &&
      other.totalObserved == totalObserved &&
      other.totalGranted == totalGranted &&
      other.totalSpent == totalSpent &&
      other.grantedBeforeWatermark == grantedBeforeWatermark &&
      other.checkpoint == checkpoint &&
      other.recovery == recovery &&
      other.sourceState == sourceState &&
      other.correctionsObserved == correctionsObserved &&
      other.unreachableGapEvents == unreachableGapEvents &&
      other.lateDiscardedSlices == lateDiscardedSlices &&
      const MapEquality<ObservationKey, int>().equals(
        other.grantedSlices,
        grantedSlices,
      );

  @override
  int get hashCode => Object.hash(
    totalObserved,
    totalGranted,
    totalSpent,
    grantedBeforeWatermark,
    checkpoint,
    recovery,
    sourceState,
    correctionsObserved,
    unreachableGapEvents,
    lateDiscardedSlices,
    const MapEquality<ObservationKey, int>().hash(grantedSlices),
  );

  String get signature =>
      'obs=$totalObserved;granted=$totalGranted;spent=$totalSpent;'
      'banked=$banked;pre=$grantedBeforeWatermark;'
      'slices=${grantedSlices.length};sync=${checkpoint.syncCount};'
      'wm=${checkpoint.watermarkMillis};recovery=${recovery.phase.name};'
      'source=${sourceState.name};corrections=$correctionsObserved;'
      'gaps=$unreachableGapEvents;late=$lateDiscardedSlices';

  @override
  String toString() => 'StepLedger($signature)';
}
