/// The single decision about whether a candidate cursor may enter a
/// [SyncResponse].
///
/// ## Why this exists as one function
///
/// Three separate defects came from cursor eligibility surviving a refusal
/// that was made somewhere else:
///
///   1. a non-final `incremental` page authorized a cursor meaning "after the
///      whole read". Completeness was correctly downgraded to
///      [PartialDelivery], so nothing settled — and the cursor advanced anyway.
///      Resume from it and pages 2..N are never delivered again.
///   2. `CompleteThrough.horizonFor` settled past the interval it queried,
///      while its recovery sibling clamped.
///   3. a truncated or partial recovery handed over its replacement token. The
///      completeness downgrade was right and was not enough: the ledger stood
///      still and the cursor walked on.
///
/// Each was fixed where it was found, which is how the third one existed after
/// the first two were closed. The rules were spread across a `switch`, so
/// "does the cursor survive?" was answered three times, in three places, by
/// three pieces of code that did not know about each other.
///
/// **This is now the only place that answers it.** Native adapters *offer* a
/// candidate. This authorizes it. Snapshot commit determines durability. No
/// adapter and no reconciler repeats these rules — the reconciler cannot even
/// see pagination, which is why it structurally could not refuse case 1.
///
/// ## The matrix
///
/// | kind | final | completeness | truncated | outcome |
/// |---|---|---|---|---|
/// | any | — | — | — | `absent` when no candidate was offered, with **no fault** |
/// | incremental | no | any | — | prohibited |
/// | incremental | yes | `PartialDelivery` | — | prohibited |
/// | incremental | yes | `CompleteThrough` | — | **authorized** |
/// | recovery | no | any | any | prohibited |
/// | recovery | yes | `PartialDelivery` | any | prohibited |
/// | recovery | yes | any | yes | prohibited |
/// | recovery | yes | `RecoveryCompleteThrough` | no | **authorized** |
/// | noChange | no | — | — | prohibited |
/// | noChange | yes | any | — | **authorized** — see below |
///
/// That row says *any* completeness, and it means it. Through the bridge only
/// `PartialDelivery` can arrive — a no-change page asserting a settling variant
/// is rejected as [SyncContractViolation.mismatchedCompleteness] before this
/// function is consulted — but this function is total, and a total function
/// answers the combinations its caller happens not to send as well as the ones
/// it does. The table used to name only the reachable row, which is how a
/// reader would conclude the other two were undefined rather than decided.
///
/// ## The noChange exception, and why it is not a hole
///
/// A no-change page carries zero observations and asserts [PartialDelivery]:
/// knowing that nothing arrived says nothing about what the window held, so it
/// settles no completeness watermark. It may still advance the cursor.
///
/// That is deliberate and owner-ruled. The token means "you have seen
/// everything up to here", and on a page where nothing changed that claim is
/// true without vouching for the window's contents. Refusing it would make a
/// quiet device re-read from the same point forever.
///
/// It is safe precisely because nothing was settled: no bucket was marked
/// accounted-for, so a later delivery inside that window is still grantable.
library;

import 'package:stride_core/stride_core.dart';

/// Which shape of response is being authorized.
enum SyncKind {
  /// An ordinary incremental read.
  incremental,

  /// A bounded authoritative rescan after the platform invalidated the cursor.
  recovery,

  /// The platform reported no change since the cursor.
  noChange,
}

/// The decision, and the reason when it is a refusal.
enum CursorAuthorization {
  /// The adapter offered no candidate. Not a refusal — there is nothing to
  /// refuse, and **no fault is raised**.
  absent,

  /// The candidate may enter the [SyncResponse].
  authorized,

  /// Pages remain outstanding.
  prohibitedNonFinalPage,

  /// The delivery vouched for nothing, so a cursor claiming completion of it
  /// would claim more than the adapter did.
  prohibitedIncompleteDelivery,

  /// The rescan window was clamped, leaving an unreachable gap. A replacement
  /// cursor would place the next read after data nobody delivered.
  prohibitedTruncatedRecovery,

  /// The completeness kind does not match the response kind — a recovery
  /// asserting [CompleteThrough], or an incremental asserting
  /// [RecoveryCompleteThrough]. Neither is a thing an adapter should produce,
  /// and guessing which it meant is how a wrong horizon gets adopted.
  ///
  /// **No longer reachable through `PlatformStepSource.translate`.** The owner
  /// ruled that a mismatch rejects the whole delivery, so the bridge returns
  /// `ContractViolationSync` before it ever asks the cursor question — which is
  /// strictly stronger than refusing the cursor alone, because a rejected batch
  /// applies no events at all.
  ///
  /// Kept anyway, and deliberately. This function is documented as pure and
  /// **total**: it answers every combination rather than assuming a caller
  /// filtered two of them out first. That assumption is exactly how "does the
  /// cursor survive?" came to be answered in three places by three pieces of
  /// code that did not know about each other. The matrix test names the
  /// exclusion so it cannot quietly become a surprise.
  prohibitedMismatchedCompleteness;

  bool get isAuthorized => this == CursorAuthorization.authorized;

  /// Whether this outcome should raise `SyncFault.cursorOfferedWhenProhibited`.
  ///
  /// [absent] must not: no candidate was offered, so nothing was refused.
  /// Raising a fault there would report a defect on every ordinary page an
  /// adapter chooses not to move the cursor on.
  bool get raisesProhibitedFault =>
      this != CursorAuthorization.absent &&
      this != CursorAuthorization.authorized;
}

/// Decides whether [hasCandidate] may become the response's `nextCursor`.
///
/// Pure, total, and exhaustively tested by
/// `test/cursor_authorization_matrix_test.dart`.
CursorAuthorization authorizeCursor({
  required bool hasCandidate,
  required SyncKind kind,
  required bool isFinalPage,
  required SyncCompleteness completeness,
  required bool truncated,
}) {
  // No candidate is not a refusal.
  if (!hasCandidate) return CursorAuthorization.absent;

  // Outstanding pages defeat every other consideration. This is case 1 above,
  // and it applies to recovery reads exactly as it applies to incremental
  // ones — a paginated rescan is still a rescan that has not finished.
  if (!isFinalPage) return CursorAuthorization.prohibitedNonFinalPage;

  switch (kind) {
    case SyncKind.noChange:
      // The documented exception. Nothing arrived, nothing was settled, and
      // the token still legitimately means "seen through here".
      return CursorAuthorization.authorized;

    case SyncKind.incremental:
      if (completeness is PartialDelivery) {
        return CursorAuthorization.prohibitedIncompleteDelivery;
      }
      if (completeness is RecoveryCompleteThrough) {
        return CursorAuthorization.prohibitedMismatchedCompleteness;
      }
      return CursorAuthorization.authorized;

    case SyncKind.recovery:
      // Truncation is checked before completeness so the refusal names the
      // real cause. A truncated window is downgraded to PartialDelivery
      // upstream, and "the delivery vouched for nothing" would be a true but
      // unhelpful thing to tell someone whose window was clamped.
      if (truncated) return CursorAuthorization.prohibitedTruncatedRecovery;
      if (completeness is PartialDelivery) {
        return CursorAuthorization.prohibitedIncompleteDelivery;
      }
      if (completeness is! RecoveryCompleteThrough) {
        return CursorAuthorization.prohibitedMismatchedCompleteness;
      }
      return CursorAuthorization.authorized;
  }
}
