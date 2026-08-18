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

/// Where the playable step economy begins.
///
/// ## Why this exists
///
/// Phase 1's device validation left the save holding roughly 459,000 banked
/// steps. Those steps are real — the device genuinely observed them, and the
/// ledger genuinely credited them — but they were accumulated by an integration
/// proving it could count, not by a player choosing to walk. Building
/// progression on top of them would mean the first playable economy started
/// with about five thousand gathers already paid for.
///
/// The owner's direction (`OD-01`) is that the playable economy restarts from
/// zero at a defined point. The obvious implementation — subtract, or rewrite
/// the ledger — is the one that must not be used:
///
/// * `RULES.md` **H-2** says granted is monotonic and there is no clawback.
///   Lowering [StepLedger.totalGranted] contradicts it directly.
/// * `RULES.md` **H-3** makes the cursor the mechanism that prevents
///   double-counting. Any reset that rewinds or discards it risks re-granting
///   history — the exact failure two device runs proved absent.
///
/// So nothing is subtracted and nothing is rewritten. The epoch is a **mark**,
/// recording what the two counters read at the cutover, and [StepLedger.banked]
/// is measured *from that mark* rather than from zero:
///
/// ```text
/// banked = (totalGranted - grantedAtStart) - (totalSpent - spentAtStart)
/// ```
///
/// Every historical figure survives untouched and stays reportable. The
/// historical steps simply stop being spendable, which is the whole of what was
/// asked for.
///
/// ## Why both counters, and not just granted
///
/// The Phase 1 save had also *spent* steps — 180 of them on gathers during
/// acceptance. Marking only granted would leave `banked` at −180 the instant the
/// epoch was set, and the ledger's own invariant would reject the state. The
/// epoch is a point on both axes because a balance is a difference of two
/// running totals, not one.
///
/// ## The origin epoch
///
/// A new game marks the epoch at `(0, 0)`, which makes the arithmetic above
/// reduce exactly to the pre-epoch definition. This is a generalization of the
/// old behaviour, not a special case bolted beside it — which is why no code
/// path needs to ask whether an epoch is "in effect".
///
/// ## Which migration established it
///
/// [establishedAtStateVersion] records the state version whose migration step
/// set this mark — `0` for the origin, `2` for the Phase 2 cutover
/// (`DECISIONS/0016`), `3` for the Transformation playtest epoch
/// (`DECISIONS/0018`). It is what lets a later, separately-decided re-basing
/// step run **exactly once** on a ledger that has already been re-based before:
/// `EstablishEconomyEpoch` refuses whenever the mark it finds was established
/// at, or after, the version it is being asked to establish. Without it the
/// second cutover would have had to choose between "refuse every non-origin
/// epoch" — which can never re-base a v2 save — and "re-base whatever is
/// there" — which would re-base a v3 save again on the day some caller asked.
@immutable
final class EconomyEpoch {
  const EconomyEpoch({
    required this.grantedAtStart,
    required this.spentAtStart,
    required this.establishedAtStateVersion,
  }) : assert(grantedAtStart >= 0, 'an epoch mark cannot be negative'),
       assert(spentAtStart >= 0, 'an epoch mark cannot be negative'),
       assert(
         establishedAtStateVersion >= 0,
         'an epoch cannot be established at a negative state version',
       );

  /// The epoch a new game starts under: everything ever granted is playable.
  const EconomyEpoch.origin()
    : grantedAtStart = 0,
      spentAtStart = 0,
      establishedAtStateVersion = 0;

  /// What [StepLedger.totalGranted] read when the playable economy began.
  final int grantedAtStart;

  /// What [StepLedger.totalSpent] read when the playable economy began.
  final int spentAtStart;

  /// The state version whose migration step established this mark.
  ///
  /// `0` for the origin. Otherwise the `toStateVersion` of the migration step
  /// that set it (`StateMigrations`), which is also the smallest state version
  /// a save carrying this exact mark can have been written at.
  final int establishedAtStateVersion;

  /// Whether this epoch retires nothing and was set by no migration — the
  /// state of a game that has never been through a cutover.
  bool get isOrigin =>
      grantedAtStart == 0 &&
      spentAtStart == 0 &&
      establishedAtStateVersion == 0;

  /// Steps credited before the cutover, and therefore not spendable.
  ///
  /// The **whole** retired body, across every cutover this ledger has been
  /// through: a v3 mark set on top of a v2 one still reads
  /// `grantedAtStart − spentAtStart`, which is everything ever banked before
  /// the current playable economy began.
  ///
  /// Reportable, deliberately. The player walked these, and a product that
  /// silently forgot them would be lying about its own history.
  int get retiredSteps => grantedAtStart - spentAtStart;

  @override
  bool operator ==(Object other) =>
      other is EconomyEpoch &&
      other.grantedAtStart == grantedAtStart &&
      other.spentAtStart == spentAtStart &&
      other.establishedAtStateVersion == establishedAtStateVersion;

  @override
  int get hashCode =>
      Object.hash(grantedAtStart, spentAtStart, establishedAtStateVersion);

  @override
  String toString() =>
      'EconomyEpoch(granted=$grantedAtStart;spent=$spentAtStart;'
      'establishedAt=v$establishedAtStateVersion)';
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
/// | [epoch] | Where the playable economy began | Set once, by cutover |
/// | [banked] | Earned and unspent **since the epoch** | derived |
///
/// The distinction between observed and granted is the whole safety argument.
/// If granted were derived from the latest observed total, a health correction
/// would silently revoke progress the player already earned and spent. Instead
/// observed may fall, granted may not, and the difference is simply recorded.
///
/// **`banked = (totalGranted - epoch.grantedAtStart) - (totalSpent -
/// epoch.spentAtStart)`**, with `0 <= totalSpent <= totalGranted`, both epoch
/// marks within their counters, and `banked >= 0`. All are asserted on every
/// construction. Under [EconomyEpoch.origin] this is exactly the pre-epoch
/// definition — see [EconomyEpoch].
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
    this.epoch = const EconomyEpoch.origin(),
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
    // An epoch mark ahead of its own counter would describe a cutover that had
    // not happened yet, and would make `banked` negative. Refused rather than
    // clamped: a clamped epoch is a silently different economy.
    if (epoch.grantedAtStart > totalGranted) {
      throw ArgumentError(
        'the epoch marks granted at ${epoch.grantedAtStart} but the ledger has '
        'only granted $totalGranted: the cutover cannot be ahead of history',
      );
    }
    if (epoch.spentAtStart > totalSpent) {
      throw ArgumentError(
        'the epoch marks spent at ${epoch.spentAtStart} but the ledger has only '
        'spent $totalSpent: the cutover cannot be ahead of history',
      );
    }
    if (spentThisEpoch > grantedThisEpoch) {
      throw ArgumentError(
        'spent since the epoch ($spentThisEpoch) cannot exceed granted since '
        'the epoch ($grantedThisEpoch): the player would owe steps they never '
        'earned in this economy',
      );
    }
  }

  StepLedger.initial()
    : totalObserved = 0,
      totalGranted = 0,
      totalSpent = 0,
      epoch = const EconomyEpoch.origin(),
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

  /// Where the playable economy begins. See [EconomyEpoch].
  final EconomyEpoch epoch;

  /// Credited since the epoch.
  int get grantedThisEpoch => totalGranted - epoch.grantedAtStart;

  /// Committed to activities since the epoch.
  int get spentThisEpoch => totalSpent - epoch.spentAtStart;

  /// Earned and unspent **since the epoch**. Never expires (`DECISIONS/0008`).
  ///
  /// `DECISIONS/0008` and `RULES.md` P-5 say nothing decays and earned
  /// opportunity never expires, and this figure keeps that promise: no banked
  /// step has ever been removed by the passage of time, by absence, or by any
  /// recurring mechanism. The epoch is a **single, deliberate, owner-authorized
  /// cutover** retiring one specific body of validation data
  /// (`DECISIONS/0016`, and once more for the Transformation playtest under
  /// `DECISIONS/0018`), not a decay rule — and no code path can move it except
  /// a migration step that names its own decision (`StateMigrations`).
  int get banked => grantedThisEpoch - spentThisEpoch;

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
    EconomyEpoch? epoch,
  }) => StepLedger(
    epoch: epoch ?? this.epoch,
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
      other.epoch == epoch &&
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
    epoch,
    const MapEquality<ObservationKey, int>().hash(grantedSlices),
  );

  String get signature =>
      'obs=$totalObserved;granted=$totalGranted;spent=$totalSpent;'
      'epoch=${epoch.grantedAtStart}/${epoch.spentAtStart}'
      '@v${epoch.establishedAtStateVersion};'
      'banked=$banked;pre=$grantedBeforeWatermark;'
      'slices=${grantedSlices.length};sync=${checkpoint.syncCount};'
      'wm=${checkpoint.watermarkMillis};recovery=${recovery.phase.name};'
      'source=${sourceState.name};corrections=$correctionsObserved;'
      'gaps=$unreachableGapEvents;late=$lateDiscardedSlices';

  @override
  String toString() => 'StepLedger($signature)';
}
