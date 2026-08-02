import 'dart:collection';

import 'package:meta/meta.dart';

import 'step_ledger.dart';
import 'sync_batch.dart';

/// Why a reconciliation could not be applied.
enum ReconciliationCode {
  /// The provider has no health service.
  serviceUnavailable('service_unavailable'),

  /// Authorization is missing or indeterminate.
  permissionUnavailable('permission_unavailable'),

  /// The read failed; retrying may work.
  transientFailure('transient_failure'),

  /// A batch violated an invariant — a negative observation, a malformed
  /// window. A programming or adapter fault, not a gameplay outcome.
  malformedBatch('malformed_batch');

  const ReconciliationCode(this.wire);

  /// Stable. May be added to, never renamed.
  final String wire;
}

/// What reconciling a batch produced.
///
/// Typed rather than thrown. An absent health service, a denied permission, a
/// failed read — all are ordinary states the game must survive calmly, and all
/// are reported here. Only impossible states assert.
@immutable
sealed class ReconciliationOutcome {
  const ReconciliationOutcome();

  bool get isAccepted => this is ReconciliationAccepted;
}

/// The batch was reconciled.
///
/// [newlyGranted] may be zero — a replayed or empty batch is accepted and
/// grants nothing, which is exactly what idempotence looks like.
@immutable
final class ReconciliationAccepted extends ReconciliationOutcome {
  ReconciliationAccepted({
    required this.newlyGranted,
    required this.observedAfter,
    required this.grantedAfter,
    required Map<ObservationKey, int> grantedSlicesAfter,
    required this.correctionsSeen,
    required this.wasRecovery,
    required this.truncatedGap,
    this.lateDiscardedSlices = 0,
    this.watermarkAfter,
    this.compactedGranted = 0,
    this.windowStartMillis,
    this.windowEndMillis,
    this.cursorToAuthorize,
  }) : grantedSlicesAfter = UnmodifiableMapView<ObservationKey, int>(
         SplayTreeMap<ObservationKey, int>.of(grantedSlicesAfter),
       ),
       assert(newlyGranted >= 0, 'a grant can never be negative');

  /// Steps credited by this batch. Always >= 0.
  final int newlyGranted;

  final int observedAfter;
  final int grantedAfter;
  final Map<ObservationKey, int> grantedSlicesAfter;

  /// How many slices the source revised downward. Diagnostic; no clawback.
  final int correctionsSeen;

  final bool wasRecovery;

  /// A rescan window was clamped, leaving an unreachable gap that is recorded
  /// and never granted.
  final bool truncatedGap;

  /// Slices that arrived after their bucket had been compacted away.
  ///
  /// Counted rather than silent: this is the one place the design can lose a
  /// real step, and a player asking why a walk did not count deserves better
  /// than a shrug.
  final int lateDiscardedSlices;

  /// The settled floor after this reconciliation, or null to leave it alone.
  ///
  /// This is the horizon compaction actually used, not a figure recomputed from
  /// the surviving slices. Recomputing it independently was how a paginated
  /// backfill lost 55,200 steps: compaction correctly declined to drop the
  /// older page, and the watermark advanced past it anyway.
  final int? watermarkAfter;

  /// Granted credit dropped by compaction, to fold into `grantedBeforeWatermark`.
  ///
  /// Computed where the merged pre-compaction map is in hand. Deriving it from
  /// the ledger's *previous* slices folded in a stale amount for any slice both
  /// raised and compacted in the same batch.
  final int compactedGranted;

  /// The rescan window, when this was a recovery.
  ///
  /// Carried so the recovery event reports real bounds. A field that exists and
  /// is always zero is worse than no field: someone eventually trusts it.
  final int? windowStartMillis;
  final int? windowEndMillis;

  /// The cursor that becomes persistable **once the ledger has committed**.
  ///
  /// Carried, not applied. Authorizing it is a separate event the reducer
  /// applies after the grant — see [ReconciliationPlan].
  final SyncCursor? cursorToAuthorize;
}

/// The batch could not be reconciled, but the state is untouched.
@immutable
final class ReconciliationRefused extends ReconciliationOutcome {
  const ReconciliationRefused({
    required this.code,
    required this.explanation,
    required this.retryable,
  });

  final ReconciliationCode code;
  final String explanation;

  /// Whether trying again later could succeed.
  final bool retryable;
}

/// Reconciles normalized provider responses against the ledger.
///
/// ## The strategy: per-slice granted amounts, bounded
///
/// The ledger remembers how much it has already granted for each
/// `(origin, bucket)` slice within a recent window. Reconciling one observation
/// is then:
///
/// ```text
/// alreadyGranted = ledger.grantedFor(key)
/// newlyGranted  += max(0, observed - alreadyGranted)
/// grantedFor(key) = max(alreadyGranted, observed)
/// ```
///
/// Every awkward case falls out of that without a special branch:
///
/// | Case | Why it works |
/// |---|---|
/// | Replay | `observed == alreadyGranted`, so the delta is zero |
/// | Overlap | The same key resolves to the same slot |
/// | Delayed record | A new key, granted once |
/// | Upward correction | Only the increase is granted |
/// | Downward correction | `max(0, …)` grants nothing; `max(alreadyGranted, …)` keeps the credit |
/// | Deletion | Observed goes to zero; granted stays |
/// | Multiple origins | Different keys, counted separately, never merged |
/// | **Recovery** | An authoritative rescan is the *same arithmetic* over a window |
///
/// That last row is why this was chosen. Recovery is not a special path with
/// its own rules to get wrong; it is ordinary reconciliation over a bounded set
/// of slices. See `TECHNICAL/STEP_RECONCILIATION_STRATEGY.md` for the
/// alternatives considered and why each was set aside.
///
/// ## Bounded retention
///
/// Slices older than [retentionWindowMillis] behind the newest observation are
/// compacted: their granted amounts fold into
/// `StepLedger.grantedBeforeWatermark`, the watermark advances, and the
/// individual slices are dropped. A settled slice grants nothing further, so
/// forgetting the detail is safe.
///
/// This is what keeps a step history from accumulating. See
/// `TECHNICAL/STEP_LEDGER_PRIVACY.md`.
final class StepReconciler {
  StepReconciler({this.retentionWindowMillis = defaultRetentionMillis}) {
    if (retentionWindowMillis < minimumRetentionMillis) {
      throw ArgumentError.value(
        retentionWindowMillis,
        'retentionWindowMillis',
        'retention below the supported minimum of $minimumRetentionMillis ms '
            '(48 hours) would silently under-grant delayed corrections',
      );
    }
  }

  /// **7 days.** The prototype default.
  ///
  /// Provisional until S-01 measures how late real corrections actually arrive
  /// on each platform. Too short and delayed records are silently under-granted
  /// — the quietest possible failure, and one no test here can catch, because
  /// no test here has real health data.
  static const int defaultRetentionMillis = 7 * 24 * 60 * 60 * 1000;

  /// **48 hours.** The floor a configuration may not go below.
  ///
  /// A hard floor rather than a warning: a retention window shorter than this
  /// trades a privacy gain nobody asked for against a correctness loss that is
  /// invisible until a player's walk fails to count.
  static const int minimumRetentionMillis = 48 * 60 * 60 * 1000;

  /// How far back per-slice detail is kept before compaction.
  ///
  /// Slices older than this are removed entirely; only non-temporal cumulative
  /// totals survive. See `TECHNICAL/STEP_LEDGER_PRIVACY.md`.
  final int retentionWindowMillis;

  /// Reconciles [response] against [ledger] without mutating anything.
  ///
  /// Pure: the same ledger and the same response always produce the same
  /// outcome. Committing is the caller's job, through the reducer.
  ReconciliationOutcome reconcile({
    required StepLedger ledger,
    required SyncResponse response,
  }) {
    switch (response) {
      case ProviderUnavailableSync(:final ProviderUnavailableReason reason):
        return switch (reason) {
          ProviderUnavailableReason.serviceUnavailable =>
            const ReconciliationRefused(
              code: ReconciliationCode.serviceUnavailable,
              explanation:
                  'the health service is not available on this device; the '
                  'game remains fully playable without it',
              retryable: true,
            ),
          ProviderUnavailableReason.permissionUnavailable =>
            const ReconciliationRefused(
              code: ReconciliationCode.permissionUnavailable,
              explanation:
                  'step data is not readable; permission is denied or cannot '
                  'be determined',
              retryable: true,
            ),
          ProviderUnavailableReason.transientFailure =>
            const ReconciliationRefused(
              code: ReconciliationCode.transientFailure,
              explanation:
                  'the read failed; the cursor is unchanged and the '
                  'next attempt will retry from the same point',
              retryable: true,
            ),
        };

      case NoChangeSync(:final SyncCursor? nextCursor):
        return ReconciliationAccepted(
          newlyGranted: 0,
          observedAfter: ledger.totalObserved,
          grantedAfter: ledger.totalGranted,
          grantedSlicesAfter: ledger.grantedSlices,
          correctionsSeen: 0,
          wasRecovery: false,
          truncatedGap: false,
          cursorToAuthorize: nextCursor,
        );

      case IncrementalSync(
        :final List<StepObservation> observations,
        :final SyncCursor? nextCursor,
        :final int? completeThroughMillis,
      ):
        return _apply(
          ledger: ledger,
          observations: observations,
          cursor: nextCursor,
          isRecovery: false,
          truncated: false,
          completeThroughMillis: completeThroughMillis,
        );

      case CursorInvalidatedSync(
        :final List<StepObservation> observations,
        :final RescanWindow window,
        :final SyncCursor? nextCursor,
        :final int? completeThroughMillis,
      ):
        if (window.endMillis < window.startMillis) {
          return const ReconciliationRefused(
            code: ReconciliationCode.malformedBatch,
            explanation: 'the rescan window ends before it starts',
            retryable: false,
          );
        }
        return _apply(
          ledger: ledger,
          observations: observations,
          cursor: nextCursor,
          isRecovery: true,
          truncated: window.truncated,
          completeThroughMillis: completeThroughMillis,
          windowStartMillis: window.startMillis,
          windowEndMillis: window.endMillis,
        );
    }
  }

  ReconciliationOutcome _apply({
    required StepLedger ledger,
    required List<StepObservation> observations,
    required SyncCursor? cursor,
    required bool isRecovery,
    required bool truncated,
    required int? completeThroughMillis,
    int? windowStartMillis,
    int? windowEndMillis,
  }) {
    final Map<ObservationKey, int> incoming = collapseObservations(
      observations,
    );

    final Map<ObservationKey, int> slices = <ObservationKey, int>{
      ...ledger.grantedSlices,
    };
    int newlyGranted = 0;
    int corrections = 0;
    int observedDelta = 0;
    int lateDiscarded = 0;

    for (final MapEntry<ObservationKey, int> entry in incoming.entries) {
      final ObservationKey key = entry.key;
      final int observed = entry.value;

      // A slice behind the watermark is settled. Its detail has been compacted
      // and it can never be granted again — which is the whole point of
      // compaction, and the reason recovery is bounded rather than unbounded.
      if (ledger.isSettled(key)) {
        // Arrived after its bucket was compacted. Nothing can be granted — the
        // record proving whether it was already credited is gone — but this is
        // counted rather than silent, because it is the one place the design
        // can lose a real step.
        if (observed > 0) lateDiscarded++;
        continue;
      }

      final int alreadyGranted = ledger.grantedFor(key);
      final int delta = observed - alreadyGranted;

      if (delta > 0) {
        newlyGranted += delta;
        slices[key] = observed;
        observedDelta += delta;
      } else if (delta < 0) {
        // The source walked this slice back. Observed falls; granted does not.
        // Keeping `slices[key]` at the higher figure is what prevents a later
        // restatement from re-granting what was already credited.
        corrections++;
        observedDelta += delta;
      }
      // delta == 0: an exact replay. Nothing to do, which is idempotence.
    }

    final int observedAfter = ledger.totalObserved + observedDelta;

    final _Compaction compaction = _compact(slices, completeThroughMillis);

    return ReconciliationAccepted(
      newlyGranted: newlyGranted,
      observedAfter: observedAfter < 0 ? 0 : observedAfter,
      grantedAfter: ledger.totalGranted + newlyGranted,
      grantedSlicesAfter: compaction.slices,
      watermarkAfter: compaction.horizon,
      compactedGranted: compaction.droppedGranted,
      correctionsSeen: corrections,
      wasRecovery: isRecovery,
      truncatedGap: truncated,
      lateDiscardedSlices: lateDiscarded,
      windowStartMillis: windowStartMillis,
      windowEndMillis: windowEndMillis,
      cursorToAuthorize: cursor,
    );
  }

  /// Drops slices that have aged past the retention horizon.
  ///
  /// Compaction happens only when the adapter *asserts* how far its delivery is
  /// complete. The core never infers completeness from whatever data it happens
  /// to have been handed: a provider paging newest-first, and a watch uploading
  /// a backlog, both look exactly like a complete delivery, and their older
  /// records would be settled before they ever arrived.
  ///
  /// The horizon this returns is the *only* watermark the caller may publish.
  /// Deriving the watermark separately reintroduces the bug this closes.
  _Compaction _compact(Map<ObservationKey, int> slices, int? completeThrough) {
    // No assertion means no compaction. The ledger grows a little rather than
    // risking a silent lost grant, and the watermark stays where it was.
    if (completeThrough == null || slices.isEmpty) {
      return _Compaction(slices, null, 0);
    }

    int newestEnd = 0;
    for (final ObservationKey key in slices.keys) {
      if (key.bucket.endMillis > newestEnd) newestEnd = key.bucket.endMillis;
    }
    final int byRetention = newestEnd - retentionWindowMillis;
    // Never settle past what the adapter says it has fully delivered.
    final int horizon = byRetention < completeThrough
        ? byRetention
        : completeThrough;

    final Map<ObservationKey, int> survivors = <ObservationKey, int>{};
    int dropped = 0;
    for (final MapEntry<ObservationKey, int> entry in slices.entries) {
      if (entry.key.bucket.endMillis > horizon) {
        survivors[entry.key] = entry.value;
      } else {
        dropped += entry.value;
      }
    }
    return _Compaction(survivors, horizon, dropped);
  }
}

/// What one compaction pass decided: the survivors, the floor it set, and the
/// granted credit it folded away.
final class _Compaction {
  const _Compaction(this.slices, this.horizon, this.droppedGranted);

  final Map<ObservationKey, int> slices;
  final int? horizon;
  final int droppedGranted;
}
