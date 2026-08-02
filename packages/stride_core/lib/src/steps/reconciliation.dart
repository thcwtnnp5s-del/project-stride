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
  const StepReconciler({this.retentionWindowMillis = defaultRetentionMillis});

  /// 48 hours.
  ///
  /// Long enough to cover the realistic arrival window for delayed and
  /// corrected records; short enough that what persists is reconciliation state
  /// rather than anything resembling a diary. The number is a judgement and is
  /// stated as one — see the privacy document.
  static const int defaultRetentionMillis = 48 * 60 * 60 * 1000;

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
      ):
        return _apply(
          ledger: ledger,
          observations: observations,
          cursor: nextCursor,
          isRecovery: false,
          truncated: false,
        );

      case CursorInvalidatedSync(
        :final List<StepObservation> observations,
        :final RescanWindow window,
        :final SyncCursor? nextCursor,
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

    for (final MapEntry<ObservationKey, int> entry in incoming.entries) {
      final ObservationKey key = entry.key;
      final int observed = entry.value;

      // A slice behind the watermark is settled. Its detail has been compacted
      // and it can never be granted again — which is the whole point of
      // compaction, and the reason recovery is bounded rather than unbounded.
      if (ledger.isSettled(key)) continue;

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

    return ReconciliationAccepted(
      newlyGranted: newlyGranted,
      observedAfter: observedAfter < 0 ? 0 : observedAfter,
      grantedAfter: ledger.totalGranted + newlyGranted,
      grantedSlicesAfter: _compact(slices),
      correctionsSeen: corrections,
      wasRecovery: isRecovery,
      truncatedGap: truncated,
      windowStartMillis: windowStartMillis,
      windowEndMillis: windowEndMillis,
      cursorToAuthorize: cursor,
    );
  }

  /// Drops slices that have aged past the retention horizon.
  ///
  /// Returns only the surviving slices; the caller folds the dropped amounts
  /// into `grantedBeforeWatermark` when it commits, so no granted total is lost.
  Map<ObservationKey, int> _compact(Map<ObservationKey, int> slices) {
    if (slices.isEmpty) return slices;

    int newestEnd = 0;
    for (final ObservationKey key in slices.keys) {
      if (key.bucket.endMillis > newestEnd) newestEnd = key.bucket.endMillis;
    }
    final int horizon = newestEnd - retentionWindowMillis;

    return <ObservationKey, int>{
      for (final MapEntry<ObservationKey, int> entry in slices.entries)
        if (entry.key.bucket.endMillis > horizon) entry.key: entry.value,
    };
  }

  /// The watermark implied by a compacted slice set.
  ///
  /// Everything at or before it is settled and will never be granted again.
  int? watermarkFor(Map<ObservationKey, int> slices, {int? previous}) {
    if (slices.isEmpty) return previous;

    int newestEnd = 0;
    for (final ObservationKey key in slices.keys) {
      if (key.bucket.endMillis > newestEnd) newestEnd = key.bucket.endMillis;
    }
    final int horizon = newestEnd - retentionWindowMillis;
    if (previous != null && previous > horizon) return previous;
    return horizon;
  }

  /// How much granted credit is dropped when [after] replaces [before].
  int compactedGrantedBetween(
    Map<ObservationKey, int> before,
    Map<ObservationKey, int> after,
  ) {
    int dropped = 0;
    for (final MapEntry<ObservationKey, int> entry in before.entries) {
      if (after.containsKey(entry.key)) continue;
      dropped += entry.value;
    }
    return dropped;
  }
}
