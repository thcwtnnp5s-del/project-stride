import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Which app or device wrote a step record.
///
/// Opaque to the core. HealthKit calls it a source revision; Health Connect
/// calls it a data origin. Neither type appears here — the platform adapter
/// normalizes whatever it has into a stable string.
///
/// Origin matters because two devices reporting the same walk must not both be
/// granted. Overlap between origins is the multi-device double-count, and it is
/// invisible to any model that only tracks totals.
@immutable
final class StepOrigin implements Comparable<StepOrigin> {
  const StepOrigin(this.id);

  /// The platform's stable identifier for the writing source.
  final String id;

  /// Used when a platform reports no origin at all.
  static const StepOrigin unknown = StepOrigin('unknown');

  @override
  int compareTo(StepOrigin other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) => other is StepOrigin && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

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

  int get durationMillis => endMillis - startMillis;

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

  final StepOrigin origin;
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

  @override
  String toString() => '${origin.id}@$bucket';
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
    required StepOrigin origin,
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

/// The bounded window a rescan covers.
@immutable
final class RescanWindow {
  const RescanWindow({
    required this.startMillis,
    required this.endMillis,
    required this.truncated,
  });

  final int startMillis;
  final int endMillis;

  /// True when the adapter clamped the window, leaving an unreachable gap.
  ///
  /// Steps in that gap are recorded and **never granted**: they cannot be
  /// distinguished from steps already counted, and inventing progress is worse
  /// than missing it.
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
    this.completeThroughMillis,
  }) : observations = List<StepObservation>.unmodifiable(observations);

  final List<StepObservation> observations;

  /// The cursor to persist — **but only after the ledger commits**.
  final SyncCursor? nextCursor;

  /// The adapter's completeness assertion. Null means "do not compact".
  final int? completeThroughMillis;

  @override
  String get kind => 'incremental';
}

/// Nothing changed since the cursor.
@immutable
final class NoChangeSync extends SyncResponse {
  const NoChangeSync({this.nextCursor, this.completeThroughMillis});

  final SyncCursor? nextCursor;

  /// See [IncrementalSync.completeThroughMillis].
  final int? completeThroughMillis;

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
    this.completeThroughMillis,
  }) : observations = List<StepObservation>.unmodifiable(observations);

  final RescanWindow window;

  /// The authoritative contents of [window], per origin and bucket.
  final List<StepObservation> observations;

  final SyncCursor? nextCursor;

  /// See [IncrementalSync.completeThroughMillis].
  final int? completeThroughMillis;

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
