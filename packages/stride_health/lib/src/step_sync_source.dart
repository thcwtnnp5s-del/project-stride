/// The port through which the app obtains a [SyncResponse].
///
/// ===========================================================================
/// Why this interface is here and not in `stride_core`
/// ===========================================================================
///
/// It used to be: `StepProvider` lived in `packages/stride_core/lib/src/ports/`
/// and nothing in the core ever called it. `DECISIONS/0014` records why that
/// mattered — a port in the core reads as the way steps enter the simulation,
/// and it was not. The real entry point is the command
/// `ReconcileStepSync(SyncResponse)`, which the app dispatches into
/// `GameEngine`. The core consumes a *value*; it does not call a *provider*.
///
/// Putting the interface back into the core would recreate exactly the shape
/// this task exists to remove: a layer that looks live and is reachable by
/// nothing. So it lives in the adapter package, beside its implementations, and
/// the core keeps no opinion about where a `SyncResponse` came from.
///
/// The types crossing this interface are core types — `SyncResponse`,
/// `SyncCursor`, `StepObservation`. That is deliberate: the boundary's whole job
/// is to produce the value the core already consumes, so it must not invent a
/// second vocabulary on the way.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stride_core/stride_core.dart';

/// Whether the platform's health service is present and usable.
///
/// A value rather than a bare bool, so "no" arrives with a reason and a caller
/// cannot accidentally treat an unknown state as available.
@immutable
final class HealthAvailability {
  const HealthAvailability({required this.available, this.reason});

  const HealthAvailability.unavailable(ProviderUnavailableReason this.reason)
    : available = false;

  final bool available;

  /// Set when [available] is false.
  final ProviderUnavailableReason? reason;
}

/// Whether the platform will give us step data.
///
/// Neither platform reliably distinguishes "denied" from "granted but empty" —
/// HealthKit deliberately hides read denial so an app cannot infer that a user
/// has no data. The game therefore treats both identically, and nothing about a
/// missing permission ever blocks a screen, a craft, or a fight.
enum HealthAuthorization { granted, denied, unavailable }

/// What the caller wants from one read.
@immutable
final class SyncRequest {
  const SyncRequest({
    this.cursor,
    this.continuation,
    this.rescanFloorMillis,
    this.bucketWidthMillis = TimeBucket.minimumWidthMillis,
    this.maxRescanWindowMillis = RescanWindow.maxWindowMillis,
    this.includeManualEntries = false,
  });

  /// The durable sync position, or null for a first read.
  final SyncCursor? cursor;

  /// Resume token from the previous page, or null to start a fresh read.
  ///
  /// **Not a cursor.** A continuation is in-flight read state and is never
  /// persisted; a cursor is durable position and is persisted only after the
  /// ledger commits. Conflating them would persist a position mid-read.
  final Uint8List? continuation;

  /// The oldest instant a recovery rescan need reach, or null for the adapter's
  /// full window.
  final int? rescanFloorMillis;

  /// The bucket resolution the caller will accept. Never below
  /// [TimeBucket.minimumWidthMillis]; see that constant for why one hour.
  final int bucketWidthMillis;

  /// The longest window a recovery rescan may cover.
  final int maxRescanWindowMillis;

  /// Whether manually-entered samples count. False by default: the default
  /// reflects real movement, and the choice belongs to the player.
  final bool includeManualEntries;
}

/// An adapter behaviour the bridge had to correct or refuse.
///
/// Every one of these is an adapter bug. They are enumerated rather than
/// thrown because a health read that goes wrong is a normal outcome the game
/// survives, and because a fault that only exists as a stack trace in a release
/// build is a fault nobody will ever see.
///
/// **A fault never carries a raw identifier, a device name, or a step count.**
/// It is a category, and the category is the whole payload.
enum SyncFault {
  /// An observation had a non-positive, inverted, or sub-hour bucket, a
  /// negative count, or an origin key of an illegal length.
  ///
  /// The whole page is refused rather than the slice dropped. Dropping one
  /// slice while accepting the page's completeness assertion would settle the
  /// bucket the drop just emptied, and the steps would be unreachable forever.
  malformedObservation,

  /// A completeness scope named an origin whose key was not decodable.
  ///
  /// The page is refused. A scope that vouches for a source nobody can identify
  /// is not a narrower assertion, it is an unusable one, and settling against
  /// it would settle the wrong buckets.
  malformedOriginKey,

  /// The adapter reported that the device-bound keying salt is not installed.
  ///
  /// Not transient and not retryable. The adapter refused to read, which is
  /// correct: observations keyed under no salt would re-key every origin and
  /// grant the whole retention window a second time.
  originKeyingUnconfigured,

  /// The page claimed `completeThrough` while reporting that it is not the
  /// final page.
  ///
  /// Downgraded to [PartialDelivery]. This is the 55,200-step defect in
  /// contract form: page one of nine looked exactly like page nine of nine.
  completenessOnNonFinalPage,

  /// The scope claimed to speak for every source while naming a subset.
  ///
  /// Narrowed to the named set. Under-settling costs a little ledger growth;
  /// over-settling costs a grant permanently.
  contradictoryOriginScope,

  /// `cursorInvalidated` arrived without a rescan window.
  ///
  /// The page is refused: without the window there is no authoritative figure
  /// and no safe move.
  invalidatedWithoutRescan,

  /// `unavailable` arrived without a reason. Treated as
  /// [ProviderUnavailableReason.transientFailure].
  unavailableWithoutReason,

  /// A cursor was offered on a path that must not advance one.
  ///
  /// Dropped. Persisting a cursor the adapter cannot stand behind would make
  /// the next sync claim progress the ledger never recorded.
  cursorOfferedWhenProhibited,

  /// Observations arrived alongside `noChange`.
  ///
  /// The response is promoted to `incremental` rather than the observations
  /// discarded — real steps must not be thrown away over a status mismatch.
  observationsOnNoChange,
}

/// One read's outcome: the value the core consumes, plus what went wrong.
///
/// The faults are a separate channel on purpose. Folding them into
/// [SyncResponse] would put adapter diagnostics inside the type the reconciler
/// switches on, and the reconciler must never branch on how well the adapter
/// behaved.
@immutable
final class SyncFetch {
  SyncFetch(
    this.response, {
    List<SyncFault> faults = const <SyncFault>[],
    this.isFinalPage = true,
    this.continuation,
  }) : faults = List<SyncFault>.unmodifiable(faults);

  /// The platform-neutral answer, ready for `ReconcileStepSync`.
  final SyncResponse response;

  /// Adapter faults the bridge corrected or refused. Empty on a clean read.
  final List<SyncFault> faults;

  /// False while pages remain. The caller loops until this is true.
  ///
  /// Pagination is the caller's loop state, not something the reconciler ever
  /// sees: the core learns "there is more coming" from [PartialDelivery] on the
  /// completeness assertion, which is the only form of it that can affect a
  /// settle decision.
  final bool isFinalPage;

  /// Resume token for the next [SyncRequest], or null when the read is drained.
  ///
  /// **Never persisted.** A continuation that outlived the process would resume
  /// a read whose earlier pages were never committed.
  final Uint8List? continuation;

  bool get isClean => faults.isEmpty;
}

/// A source of step synchronization pages.
///
/// Implementations: the real platform bridge, and a scriptable mock for tests.
abstract interface class StepSyncSource {
  /// Whether the platform's health service is present and usable.
  Future<HealthAvailability> availability();

  /// Requests read-only step authorization.
  Future<HealthAuthorization> requestAuthorization();

  /// Reads one page.
  ///
  /// Must never throw for an expected condition. Denial, absence, an invalid
  /// cursor, and an empty result are all reported through the returned
  /// [SyncResponse].
  ///
  /// **The returned cursor is a candidate, not a commitment.** The commit order
  /// is inviolable: this returns data and a candidate cursor, reconciliation
  /// produces grants, the ledger and snapshot commit, and only then is the
  /// cursor made durable. Nothing in an adapter may cache or advance one.
  Future<SyncFetch> fetchSteps(SyncRequest request);
}
