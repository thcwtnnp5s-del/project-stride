import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Whether the platform will give us step data.
///
/// Neither platform reliably distinguishes "denied" from "granted but empty" —
/// HealthKit deliberately hides read denial so an app cannot infer that a user
/// has no data. The game therefore treats both identically, and nothing about a
/// missing permission ever blocks a screen, a craft, or a fight.
enum StepAuthorization { granted, denied, unavailable }

/// An opaque platform cursor.
///
/// On iOS this wraps an archived `HKQueryAnchor`; on Android, a Health Connect
/// changes token. The core stores and returns it without ever inspecting it.
///
/// That opacity is what lets one ledger serve two genuinely different sync
/// primitives. Nothing in `stride_core` may branch on which platform produced
/// a cursor.
@immutable
class StepCursor {
  const StepCursor(this.bytes);

  final Uint8List bytes;
}

/// Why a fetch could not continue incrementally.
enum CursorStatus {
  /// The cursor was accepted; [StepFetchResult.newSteps] is a true delta.
  valid,

  /// The platform rejected the cursor — expired, invalidated, or from a
  /// reinstalled data store. Health Connect can do this; HealthKit does not.
  ///
  /// The adapter must then perform a bounded authoritative rescan rather than
  /// reporting the whole history as new. See [StepRescan].
  invalidated,
}

/// The result of an incremental fetch.
@immutable
class StepFetchResult {
  const StepFetchResult({
    required this.status,
    required this.newSteps,
    required this.deletedSteps,
    required this.cursor,
    this.rescan,
  });

  final CursorStatus status;

  /// Steps added since the cursor. Never negative.
  final int newSteps;

  /// Steps removed by corrections or deletions since the cursor.
  ///
  /// This is *information*, not an instruction. Reconciliation records a
  /// discrepancy and absorbs it against future ingestion; it never revokes
  /// progress the player has already been granted.
  final int deletedSteps;

  /// The cursor to persist for the next fetch.
  ///
  /// **Persist only after the resulting batch is committed to the ledger.**
  /// Persisting early makes an interrupted sync unrecoverable — the cursor
  /// would claim progress the ledger never recorded.
  final StepCursor? cursor;

  /// Present only when [status] is [CursorStatus.invalidated].
  final StepRescan? rescan;
}

/// An authoritative re-read of a bounded window, used to recover from cursor
/// loss without double-counting and without granting the whole history.
///
/// ## The problem
///
/// Incremental sync reports deltas. When the platform invalidates the cursor,
/// that delta stream is broken and the adapter cannot say what changed. The two
/// obvious responses are both wrong:
///
/// * Grant everything rescanned — double-counts every step already granted.
/// * Reset the ledger and start over — erases the player's earned progress.
///
/// ## The strategy: watermark plus overlap arithmetic
///
/// The game persists two values alongside the cursor:
///
/// * `sourceWatermark` — an instant such that all source data at or before it
///   has been fully accounted for.
/// * `grantedSinceWatermark` — how many steps the game has granted from source
///   data *after* that watermark.
///
/// On recovery the adapter re-reads the authoritative total for the window
/// `[sourceWatermark, now]` and reports it as [windowTotal]. Reconciliation
/// then grants:
///
/// ```text
/// newlyGrantable = max(0, windowTotal - grantedSinceWatermark)
/// ```
///
/// The subtraction is the overlap correction: whatever the game already granted
/// from inside the rescanned window is deducted, so re-reading data cannot
/// re-grant it. The `max(0, …)` is the no-clawback rule — if the source now
/// reports *less* than was granted, the shortfall becomes recorded discrepancy
/// rather than lost progress.
///
/// The watermark advances only after a successful recovery, and
/// `grantedSinceWatermark` resets to zero at that moment.
///
/// ## Why bounded
///
/// [windowStart] is clamped to [maxRescanWindow] before now. If the watermark
/// is older than that, the window is truncated and [truncated] is set. The
/// steps in the unreachable gap are **not** granted: they cannot be
/// distinguished from steps already counted, and inventing progress is worse
/// than missing it. The truncation is recorded, not silently dropped.
///
/// ## Why interrupted recovery is safe to retry
///
/// Recovery reads state and computes a number; it mutates nothing until the
/// ledger batch is committed. If the process dies at any point before that, the
/// watermark, `grantedSinceWatermark`, and the old cursor are all unchanged, so
/// the next attempt recomputes exactly the same result. Combined with the
/// ledger's batch-identity replay guard, recovery is idempotent.
///
/// ## On record identity
///
/// Health Connect exposes per-record UIDs, and deduplicating by UID inside the
/// overlap window would be more precise than arithmetic. It is deliberately not
/// the primary mechanism: retaining identifiers indefinitely is unbounded
/// storage, and it would leave the game holding a shadow copy of health data,
/// which `GAME_BIBLE/HEALTH_INTEGRATION` forbids. Identity may be used *within*
/// a single recovery pass as a refinement; the watermark arithmetic is what the
/// correctness argument rests on.
///
/// Reconciliation scenario 13 (F-04) tests this path.
@immutable
class StepRescan {
  const StepRescan({
    required this.windowStart,
    required this.windowEnd,
    required this.windowTotal,
    required this.truncated,
  });

  /// The longest window the game will ever re-read. Steps older than this are
  /// unreachable after cursor loss and are recorded rather than granted.
  static const Duration maxRescanWindow = Duration(days: 30);

  /// Start of the rescanned window — the persisted watermark, clamped to
  /// [maxRescanWindow].
  final DateTime windowStart;

  /// End of the rescanned window, as reported by the platform.
  final DateTime windowEnd;

  /// The authoritative step total the source reports for the window.
  ///
  /// A total, not a delta. This is the whole point: after cursor loss only an
  /// absolute figure can be reconciled against what was already granted.
  final int windowTotal;

  /// Whether [windowStart] was clamped, leaving an unreachable gap.
  final bool truncated;
}

/// The port through which the simulation receives steps.
///
/// Implementations: HealthKit (Swift), Health Connect (Kotlin), and a mock for
/// tests. The core depends on this interface and never on any of them.
abstract interface class StepProvider {
  Future<StepAuthorization> requestAuthorization();

  /// Whether the platform's health service is present and usable.
  ///
  /// False on Android where Health Connect is not installed. That is a normal
  /// state, handled by the same graceful path as a denied permission — the game
  /// remains fully playable.
  Future<bool> isAvailable();

  /// Fetch steps since [cursor], or from the beginning when null.
  ///
  /// Must never throw for an expected condition — denial, absence, or an
  /// invalid cursor are all reported through the result. On genuine error the
  /// implementation leaves the cursor untouched, and the caller must not
  /// advance `stepsIngested`.
  Future<StepFetchResult> fetchNewSteps({
    StepCursor? cursor,
    DateTime? watermark,
  });
}
