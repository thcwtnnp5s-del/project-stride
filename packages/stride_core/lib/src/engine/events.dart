import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/reconciliation.dart';
import '../steps/step_ledger.dart';
import '../steps/step_origin_key.dart';
import '../steps/sync_batch.dart';

/// Something that has happened.
///
/// An event is an accepted fact. By the time one exists, validation has already
/// passed, so applying it through the reducer cannot fail and cannot be
/// refused. That is what makes replay meaningful: feeding the same events into
/// the same starting state must always produce the same result, with no
/// re-validation and no opportunity to disagree with the original run.
///
/// Events are also the only channel to audio, haptics, and the return summary.
/// The simulation emits `ItemEquipped`; something else decides what that sounds
/// like. Nothing in here names a sound, an animation, or a screen.
@immutable
sealed class GameEvent {
  const GameEvent({required this.sequence});

  /// Position in the event stream, starting at 0.
  ///
  /// Monotonic and gap-free. Gives every event a stable identity, which is what
  /// lets a replay be verified and — once F-05 exists — lets a crash between
  /// writing an event and writing a snapshot be detected rather than guessed at.
  final int sequence;

  String get name;
}

/// A new game began.
///
/// Emitted as an event rather than assumed, so that the very first thing in a
/// game's history is a fact in the same stream as everything after it. A save
/// whose event log does not start here is a save that began somewhere unknown.
@immutable
final class GameStarted extends GameEvent {
  const GameStarted({
    required super.sequence,
    required this.profileId,
    required this.startLocation,
    required this.grantedItems,
  });

  final ContentId profileId;
  final ContentId startLocation;
  final List<ContentId> grantedItems;

  @override
  String get name => 'GameStarted';
}

/// Steps entered the ledger from a synthetic source.
@immutable
final class SyntheticStepsGranted extends GameEvent {
  const SyntheticStepsGranted({
    required super.sequence,
    required this.steps,
    required this.reason,
  });

  final int steps;
  final String reason;

  @override
  String get name => 'SyntheticStepsGranted';
}

/// Banked steps were committed.
@immutable
final class StepsAllocated extends GameEvent {
  const StepsAllocated({required super.sequence, required this.steps});

  final int steps;

  @override
  String get name => 'StepsAllocated';
}

/// A resource node was worked once: steps spent, yield taken, experience gained.
///
/// **One event, not three.** The spend, the item, and the experience are a
/// single fact and are applied by a single reducer branch, so there is no
/// instant — in memory, in the journal, or in a replay — at which the steps are
/// gone and the herbs have not arrived. Splitting it into `StepsAllocated` plus
/// an inventory event plus an experience event would make that instant real and
/// reachable: the journal is append-only and a process killed between two
/// records leaves the first one durable.
///
/// Every figure is recorded on the event rather than recomputed from content at
/// replay time. A content pack that retunes `stepCost` or `xp` next month must
/// not change what a gather the player already performed did to their save —
/// replay would then produce a different state than the one that was committed,
/// which is the one thing a replay may never do.
@immutable
final class ResourceGathered extends GameEvent {
  const ResourceGathered({
    required super.sequence,
    required this.node,
    required this.stepsSpent,
    required this.item,
    required this.quantity,
    required this.skill,
    required this.experience,
  });

  final ContentId node;

  /// Profile-scaled, as charged. Never the raw content value.
  final int stepsSpent;

  final ContentId item;
  final int quantity;
  final ContentId skill;

  /// Profile-scaled, as awarded. May be zero; a node with no xp is legal.
  final int experience;

  @override
  String get name => 'ResourceGathered';
}

/// An item was placed in a slot.
@immutable
final class ItemEquipped extends GameEvent {
  const ItemEquipped({
    required super.sequence,
    required this.item,
    required this.slot,
  });

  final ContentId item;
  final EquipmentSlot slot;

  @override
  String get name => 'ItemEquipped';
}

/// A slot was emptied.
@immutable
final class ItemUnequipped extends GameEvent {
  const ItemUnequipped({
    required super.sequence,
    required this.item,
    required this.slot,
  });

  final ContentId item;
  final EquipmentSlot slot;

  @override
  String get name => 'ItemUnequipped';
}

/// A location became available.
@immutable
final class LocationUnlocked extends GameEvent {
  const LocationUnlocked({required super.sequence, required this.location});

  final ContentId location;

  @override
  String get name => 'LocationUnlocked';
}

/// The player moved.
@immutable
final class LocationEntered extends GameEvent {
  const LocationEntered({
    required super.sequence,
    required this.from,
    required this.location,
  });

  final ContentId from;
  final ContentId location;

  @override
  String get name => 'LocationEntered';
}

/// A bounded recovery began.
///
/// Emitted **before** the observation is reconciled, so a process that dies
/// mid-recovery leaves a ledger that knows one was started and never finished.
/// Without it, a retry could not tell an interrupted first attempt from a fresh
/// one.
@immutable
final class StepRecoveryStarted extends GameEvent {
  const StepRecoveryStarted({
    required super.sequence,
    required this.windowStartMillis,
    required this.windowEndMillis,
    required this.truncated,
  });

  final int windowStartMillis;
  final int windowEndMillis;
  final bool truncated;

  @override
  String get name => 'StepRecoveryStarted';
}

/// A batch was reconciled: observed totals and slice records updated.
///
/// Carries the downward-correction count, but **there is no `StepsRemoved`
/// event**. A health correction changes what the source says, never what the
/// player has been credited, so there is no removal to announce — inventing one
/// would invite a listener to undo a grant.
@immutable
final class StepObservationReconciled extends GameEvent {
  StepObservationReconciled({
    required super.sequence,
    required this.observedAfter,
    required Map<ObservationKey, int> grantedSlicesAfter,
    required this.grantedCompactedAway,
    required this.lateDiscarded,
    required this.watermarkMillis,
    required Map<StepOriginKey, int> originWatermarks,
    required this.correctionsSeen,
    required this.truncatedGap,
    required this.wasRecovery,
  }) : grantedSlicesAfter = Map<ObservationKey, int>.unmodifiable(
         grantedSlicesAfter,
       ),
       originWatermarks = Map<StepOriginKey, int>.unmodifiable(
         originWatermarks,
       );

  final int observedAfter;
  final Map<ObservationKey, int> grantedSlicesAfter;

  /// Granted credit for slices dropped by compaction, folded into the
  /// pre-watermark total so no granted step is ever lost.
  final int grantedCompactedAway;

  /// Observations that arrived after their bucket had been compacted away.
  ///
  /// These cannot be granted — the record proving whether they were already
  /// credited is gone. Carried as a fact rather than dropped in silence,
  /// because this is the one lossy path the design still permits.
  final int lateDiscarded;

  /// Diagnostic. The lowest per-origin watermark.
  final int? watermarkMillis;

  /// Per origin, the point through which that origin is accounted for.
  final Map<StepOriginKey, int> originWatermarks;
  final int correctionsSeen;
  final bool truncatedGap;
  final bool wasRecovery;

  @override
  String get name => 'StepObservationReconciled';
}

/// Steps were credited to the player.
///
/// Separate from [StepObservationReconciled] on purpose. Observing and granting
/// are different facts: a batch can update what the source says while granting
/// nothing, and anything reacting to *progress* — audio, the return summary —
/// should hear only this one.
@immutable
final class StepsGranted extends GameEvent {
  const StepsGranted({
    required super.sequence,
    required this.steps,
    required this.grantedTotalAfter,
  }) : assert(steps > 0, 'a grant event must credit something');

  final int steps;
  final int grantedTotalAfter;

  @override
  String get name => 'StepsGranted';
}

/// The replacement cursor is now safe to persist.
///
/// **Always the last event of a reconciliation batch.** The reducer applies
/// events in order, so the ledger has already committed the grant by the time
/// this lands.
///
/// That ordering is the entire crash-safety argument. Persisting a cursor first
/// would let a process die before the grant and resume from a point whose steps
/// were never credited — steps the player walked and will never see. Doing it
/// last means an interrupted commit leaves the old cursor in place and the
/// retry recomputes exactly the same result.
@immutable
final class StepCheckpointAuthorized extends GameEvent {
  const StepCheckpointAuthorized({
    required super.sequence,
    required this.cursor,
    required this.syncCount,
  });

  /// Null when the provider offered none — an unrecovered cursor stays absent
  /// rather than being invented.
  final SyncCursor? cursor;

  final int syncCount;

  @override
  String get name => 'StepCheckpointAuthorized';
}

/// A recovery finished and the ledger is consistent again.
@immutable
final class StepRecoveryCompleted extends GameEvent {
  const StepRecoveryCompleted({
    required super.sequence,
    required this.newlyGranted,
    required this.truncated,
  });

  final int newlyGranted;
  final bool truncated;

  @override
  String get name => 'StepRecoveryCompleted';
}

/// The provider's availability changed.
@immutable
final class StepSourceStateChanged extends GameEvent {
  const StepSourceStateChanged({
    required super.sequence,
    required this.sourceState,
    this.code,
  });

  final SourceState sourceState;
  final ReconciliationCode? code;

  @override
  String get name => 'StepSourceStateChanged';
}
