/// The adapter's completeness assertion, and its scope.
///
/// The core never infers how much of a provider's data has arrived. Inferring
/// it destroyed 55,200 steps of a paginated backfill and every backlog a
/// reconnecting watch carried — both times because "the newest bucket I was
/// handed" looked exactly like "everything that exists".
///
/// So completeness is *asserted*, and an assertion is only worth acting on if
/// it says **what** it covers. A bare boolean cannot distinguish these:
///
/// - "I delivered every page for every source through Tuesday"
/// - "I delivered page 1 of 9, whose newest record happens to be Tuesday"
/// - "I delivered everything the *phone* wrote through Tuesday, and the watch
///   has been offline for a week"
///
/// The third is the one that matters most. An assertion scoped to one origin
/// must never settle another origin's buckets — that is exactly the case where
/// a player's walk vanishes because they were away.
library;

import 'package:meta/meta.dart';

import 'step_origin_key.dart';

/// Which sources an assertion speaks for.
@immutable
sealed class OriginScope {
  const OriginScope();

  /// True when this scope vouches for [origin].
  bool covers(StepOriginKey origin);
}

/// The adapter enumerated every source the platform knows about.
///
/// Only legitimate when the adapter actually asked the platform for the full
/// source list. "I saw one source in this batch" is [SomeOrigins], not this.
final class AllOrigins extends OriginScope {
  const AllOrigins();

  @override
  bool covers(StepOriginKey origin) => true;
}

/// The adapter vouches only for the named sources.
final class SomeOrigins extends OriginScope {
  SomeOrigins(Set<StepOriginKey> origins)
    : origins = Set<StepOriginKey>.unmodifiable(origins);

  final Set<StepOriginKey> origins;

  @override
  bool covers(StepOriginKey origin) => origins.contains(origin);
}

/// What kind of data an assertion speaks for.
///
/// Only steps exist today. It is here because an adapter that later reads
/// distance or workouts must not have its step-completeness assertion silently
/// widened to cover them.
enum HealthDataType { steps }

/// The scope of a completeness assertion.
@immutable
final class CompletenessScope {
  const CompletenessScope({
    required this.dataType,
    required this.origins,
    required this.intervalStartMillis,
    required this.intervalEndMillis,
    required this.queryGeneration,
  });

  final HealthDataType dataType;
  final OriginScope origins;

  /// UTC milliseconds. The interval the adapter actually queried.
  final int intervalStartMillis;
  final int intervalEndMillis;

  /// Which query or token produced this.
  ///
  /// An assertion made under an anchor that has since been invalidated is
  /// stale, and acting on it would settle buckets a rescan is about to
  /// restate.
  final int queryGeneration;

  /// True when this scope vouches for [origin] at [bucketEndMillis].
  bool coversBucket(StepOriginKey origin, int bucketEndMillis) =>
      origins.covers(origin) &&
      bucketEndMillis > intervalStartMillis &&
      bucketEndMillis <= intervalEndMillis;
}

/// How complete a provider response is.
@immutable
sealed class SyncCompleteness {
  const SyncCompleteness();

  /// The point through which [origin] may be settled, or null for "do not
  /// compact this origin".
  int? horizonFor(StepOriginKey origin);
}

/// Pages remain outstanding. **Nothing may be settled.**
///
/// The correct value for any response the adapter has not fully drained —
/// which is every page but the last of a paginated read.
final class PartialDelivery extends SyncCompleteness {
  const PartialDelivery();

  @override
  int? horizonFor(StepOriginKey origin) => null;
}

/// The adapter has exhausted every page for the declared scope.
///
/// May be asserted **only** after full pagination. Asserting it early is
/// indistinguishable, from inside the core, from the data genuinely not
/// existing — and the consequence is a silent permanent lost grant.
final class CompleteThrough extends SyncCompleteness {
  const CompleteThrough({
    required this.throughMillis,
    required this.scope,
  });

  /// UTC milliseconds. Everything at or before this, within [scope], has been
  /// delivered.
  final int throughMillis;

  final CompletenessScope scope;

  @override
  int? horizonFor(StepOriginKey origin) =>
      scope.origins.covers(origin) ? throughMillis : null;
}

/// A bounded recovery rescan completed and covered its whole window.
///
/// Distinct from [CompleteThrough] because a recovery's authority stops at the
/// window it could actually reach. A truncated rescan is [PartialDelivery]: it
/// covered less than it was asked to, and settling on it would bury whatever
/// fell outside the truncation.
final class RecoveryCompleteThrough extends SyncCompleteness {
  const RecoveryCompleteThrough({
    required this.throughMillis,
    required this.scope,
  });

  final int throughMillis;
  final CompletenessScope scope;

  @override
  int? horizonFor(StepOriginKey origin) {
    if (!scope.origins.covers(origin)) return null;
    // Never claim more than the window actually covered.
    return throughMillis < scope.intervalEndMillis
        ? throughMillis
        : scope.intervalEndMillis;
  }
}
