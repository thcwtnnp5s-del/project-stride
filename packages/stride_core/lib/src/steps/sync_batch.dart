import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'completeness.dart';
import 'step_origin_key.dart';

/// A window of time, as data.
///
/// Milliseconds since the Unix epoch, UTC. Not a `DateTime`, and never read
/// from a clock — the core is forbidden both. Timestamps arrive from the
/// platform as numbers and stay numbers.
///
/// **No day boundaries, no local calendar.** A bucket is an arbitrary interval
/// the adapter chose; the reconciler never asks what day it falls on. That is
/// what makes daylight saving, travel across timezones, and midnight into
/// non-events.
@immutable
final class TimeBucket implements Comparable<TimeBucket> {
  const TimeBucket({required this.startMillis, required this.endMillis})
    : assert(endMillis > startMillis, 'a bucket must cover a positive span');

  final int startMillis;
  final int endMillis;

  /// The narrowest bucket the reconciler will accept.
  ///
  /// The privacy ruling bounds retention *length* — seven days — and says
  /// nothing about *resolution*. One-minute buckets would satisfy it exactly
  /// as written, and produce roughly ten thousand entries per origin: a
  /// minute-by-minute record of when the player moved, kept for a week. That
  /// is a far finer activity log than "coarse recent reconciliation history"
  /// describes, and nobody would have decided to build it.
  ///
  /// One hour is also what the retention document's own sizing estimate
  /// assumes — *(hours in the window) × (devices)*. Before this constant that
  /// assumption was uneforced, and the adapter that would have had to honour
  /// it is not written yet.
  ///
  /// Enforced at the reconciler boundary as a typed refusal rather than by
  /// `assert`, because asserts are stripped from release builds and release is
  /// exactly where a player's data is.
  static const int minimumWidthMillis = 60 * 60 * 1000;

  int get durationMillis => endMillis - startMillis;

  /// True when this bucket is coarse enough to persist.
  bool get isPersistable => durationMillis >= minimumWidthMillis;

  bool overlaps(TimeBucket other) =>
      startMillis < other.endMillis && other.startMillis < endMillis;

  @override
  int compareTo(TimeBucket other) {
    final int byStart = startMillis.compareTo(other.startMillis);
    return byStart != 0 ? byStart : endMillis.compareTo(other.endMillis);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeBucket &&
      other.startMillis == startMillis &&
      other.endMillis == endMillis;

  @override
  int get hashCode => Object.hash(startMillis, endMillis);

  @override
  String toString() => '[$startMillis,$endMillis)';
}

/// Identifies one observable slice of step data.
///
/// The pair `(origin, bucket)` is the unit the reconciler reasons about. It is
/// the smallest thing a platform can restate, correct, or delete, which makes it
/// the smallest thing the game must be able to recognise as *already counted*.
@immutable
final class ObservationKey implements Comparable<ObservationKey> {
  const ObservationKey({required this.origin, required this.bucket});

  final StepOriginKey origin;
  final TimeBucket bucket;

  @override
  int compareTo(ObservationKey other) {
    final int byBucket = bucket.compareTo(other.bucket);
    return byBucket != 0 ? byBucket : origin.compareTo(other.origin);
  }

  @override
  bool operator ==(Object other) =>
      other is ObservationKey &&
      other.origin == origin &&
      other.bucket == bucket;

  @override
  int get hashCode => Object.hash(origin, bucket);

  /// Diagnostic only. **Never** the serialized form: an origin key and a
  /// bucket concatenated with a separator can split or merge on round-trip,
  /// which silently re-grants or under-grants a device's whole window. The
  /// save encodes the two fields structurally.
  @override
  String toString() => '${origin.value}@$bucket';
}

/// What the source currently says about one slice.
///
/// An **absolute** figure, not a delta. That is the whole design: a restated
/// observation of 400 steps means the source now believes that slice contains
/// 400 steps, whether it previously said 0, 300, or 900. Deltas cannot express
/// a correction, and cannot be replayed safely.
@immutable
final class StepObservation {
  const StepObservation({required this.key, required this.steps})
    : assert(steps >= 0, 'an observation cannot be negative');

  StepObservation.of({
    required StepOriginKey origin,
    required int startMillis,
    required int endMillis,
    required int steps,
  }) : this(
         key: ObservationKey(
           origin: origin,
           bucket: TimeBucket(startMillis: startMillis, endMillis: endMillis),
         ),
         steps: steps,
       );

  final ObservationKey key;

  /// The source's current total for this slice. Zero means deleted.
  final int steps;

  @override
  bool operator ==(Object other) =>
      other is StepObservation && other.key == key && other.steps == steps;

  @override
  int get hashCode => Object.hash(key, steps);

  @override
  String toString() => '$key=$steps';
}

/// An opaque platform cursor.
///
/// A HealthKit anchor or a Health Connect changes token. The core stores and
/// returns it without inspecting it, which is what lets one ledger serve two
/// genuinely different sync primitives.
@immutable
final class SyncCursor {
  SyncCursor(Uint8List bytes) : bytes = Uint8List.fromList(bytes);

  SyncCursor.ofString(String value)
    : bytes = Uint8List.fromList(value.codeUnits);

  /// Copied on construction and on read, so a cursor cannot be edited in place
  /// by whoever handed it over or whoever receives it.
  final Uint8List bytes;

  Uint8List get copy => Uint8List.fromList(bytes);

  @override
  bool operator ==(Object other) {
    if (other is! SyncCursor) return false;
    if (other.bytes.length != bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'cursor(${bytes.length}B)';
}

/// The bounded window a rescan covers, and the recovery contract behind it.
///
/// ## The problem
///
/// Incremental sync reports change since a cursor. When the platform
/// invalidates that cursor, the change stream is broken and the adapter cannot
/// say what changed. The two obvious responses are both wrong:
///
/// * Grant everything rescanned — double-counts every step already granted.
/// * Reset the ledger and start over — erases the player's earned progress.
///
/// ## The binding contract
///
/// Recovery must, by whatever mechanism:
///
/// 1. never reset the game ledger
/// 2. never treat rescanned history as all new
/// 3. never claw back granted progress
/// 4. never silently discard the cursor and grant full history
/// 5. persist a replacement cursor only after the batch is committed
/// 6. be safe to retry after interruption, recomputing the same result
///
/// Reconciliation scenario 13 (F-04) asserts that contract, not any particular
/// arithmetic, so the mechanism can change without the guarantees moving.
///
/// ## How it is satisfied here
///
/// The adapter re-reads the window authoritatively, **per origin and per
/// bucket**, and sends those absolute figures as ordinary [StepObservation]s
/// alongside this window. The reconciler already knows what it granted for each
/// `(origin, bucket)` slice, so the overlap correction is per-slice
/// subtraction rather than a single global watermark — which is the fix that
/// closed LG-3, where one global watermark could not express "settled for the
/// phone, still open for the watch". The no-clawback rule turns any shortfall
/// into recorded discrepancy rather than lost progress.
///
/// ## Why interrupted recovery is safe to retry
///
/// Recovery reads state and computes a number; it mutates nothing until the
/// ledger batch is committed. If the process dies at any point before that, the
/// ledger and the old cursor are unchanged, so the next attempt recomputes
/// exactly the same result. Combined with the ledger's batch-identity replay
/// guard, recovery is idempotent.
///
/// ## On record identity
///
/// Health Connect exposes per-record UIDs, and deduplicating by UID inside the
/// overlap window would be more precise than per-slice arithmetic. It is
/// deliberately not the primary mechanism: retaining identifiers indefinitely is
/// unbounded storage, and it would leave the game holding a shadow copy of
/// health data, which `GAME_BIBLE/HEALTH_INTEGRATION` forbids. Identity may be
/// used *within* a single recovery pass as a refinement; the per-slice absolute
/// figures are what the correctness argument rests on.
@immutable
final class RescanWindow {
  const RescanWindow({
    required this.startMillis,
    required this.endMillis,
    required this.truncated,
  });

  /// The longest window the game will ever ask to re-read.
  ///
  /// Steps older than this are unreachable after cursor loss and are recorded
  /// rather than granted. Milliseconds, not a `Duration`: the core takes time
  /// as data and never reads a clock, and this figure crosses the platform
  /// boundary as a number.
  static const int maxWindowMillis = 30 * 24 * 60 * 60 * 1000;

  final int startMillis;
  final int endMillis;

  /// True when the adapter clamped the window, leaving an unreachable gap.
  ///
  /// Steps in that gap are recorded and **never granted**: they cannot be
  /// distinguished from steps already counted, and inventing progress is worse
  /// than missing it. The truncation is reported, not silently dropped.
  final bool truncated;
}

/// Why a provider could not answer.
enum ProviderUnavailableReason {
  /// The health service is absent — Health Connect not installed, HealthKit
  /// unavailable on the device.
  serviceUnavailable,

  /// Authorization has not been granted, or cannot be determined.
  ///
  /// HealthKit deliberately does not distinguish "denied" from "granted but
  /// empty", so neither does this.
  permissionUnavailable,

  /// The read failed and may succeed later.
  transientFailure,
}

/// A platform-neutral answer from a step provider.
///
/// No HealthKit or Health Connect type appears here or anywhere in
/// `stride_core`. An adapter normalizes; the core reconciles.
@immutable
sealed class SyncResponse {
  const SyncResponse();

  String get kind;
}

/// How far the adapter guarantees it has delivered everything.
///
/// ## Why the core cannot work this out for itself
///
/// The reconciler used to infer completeness from the newest bucket it had
/// seen, and compact anything older than the retention window behind it. That
/// silently discarded steps in two ordinary situations:
///
/// * a provider paginating newest-first — the recent page advanced the
///   watermark past the older page, which then arrived already "settled"
/// * a second device uploading a backlog after being offline
///
/// Both lost real steps with no error. The core cannot detect either, because
/// only the adapter knows whether more pages are coming or whether a source has
/// finished catching up.
///
/// So completeness is now **asserted, not inferred**. An adapter sets this only
/// when it can honestly say "everything at or before this instant has been
/// delivered". When it is absent the reconciler does not compact at all, which
/// is the safe default: the ledger grows a little rather than losing a grant.
///
/// The source reported observations, incrementally.
///
/// Covers the ordinary case and, without needing a separate shape, delayed
/// records, overlapping batches, upward and downward corrections, and
/// deletions — because every observation is absolute and keyed.
@immutable
final class IncrementalSync extends SyncResponse {
  IncrementalSync({
    required List<StepObservation> observations,
    this.nextCursor,
    this.completeness = const PartialDelivery(),
  }) : observations = List<StepObservation>.unmodifiable(observations);

  final List<StepObservation> observations;

  /// The cursor to persist — **but only after the ledger commits**.
  final SyncCursor? nextCursor;

  /// The adapter's completeness assertion. Null means "do not compact".
  final SyncCompleteness completeness;

  @override
  String get kind => 'incremental';
}

/// Nothing changed since the cursor.
@immutable
final class NoChangeSync extends SyncResponse {
  const NoChangeSync({
    this.nextCursor,
    this.completeness = const PartialDelivery(),
  });

  final SyncCursor? nextCursor;

  /// See [IncrementalSync.completeness].
  final SyncCompleteness completeness;

  @override
  String get kind => 'no_change';
}

/// The cursor was rejected; here is an authoritative re-read instead.
///
/// Health Connect can expire a changes token. HealthKit anchors do not expire,
/// so this is the one genuinely Android-specific path — but the model is
/// platform-neutral, and the iOS adapter uses it for a missing or unarchivable
/// anchor.
@immutable
final class CursorInvalidatedSync extends SyncResponse {
  CursorInvalidatedSync({
    required this.window,
    required List<StepObservation> observations,
    this.nextCursor,
    this.completeness = const PartialDelivery(),
  }) : observations = List<StepObservation>.unmodifiable(observations);

  final RescanWindow window;

  /// The authoritative contents of [window], per origin and bucket.
  final List<StepObservation> observations;

  final SyncCursor? nextCursor;

  /// See [IncrementalSync.completeness].
  final SyncCompleteness completeness;

  @override
  String get kind => 'cursor_invalidated';
}

/// The provider could not answer.
@immutable
final class ProviderUnavailableSync extends SyncResponse {
  const ProviderUnavailableSync(this.reason);

  final ProviderUnavailableReason reason;

  @override
  String get kind => 'unavailable';
}

/// Groups observations by key, keeping the last value for a repeated key.
///
/// A batch that restates the same slice twice is answering with its final
/// figure, not asking for both to be counted.
Map<ObservationKey, int> collapseObservations(
  Iterable<StepObservation> observations,
) {
  final SplayTreeMap<ObservationKey, int> collapsed =
      SplayTreeMap<ObservationKey, int>();
  for (final StepObservation observation in observations) {
    collapsed[observation.key] = observation.steps;
  }
  return UnmodifiableMapView<ObservationKey, int>(collapsed);
}
