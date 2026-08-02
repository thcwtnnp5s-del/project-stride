/// Typed results for every save, load, and recovery path.
///
/// Nothing throws for a condition the design anticipated. A corrupt slot, a
/// future format, a wrong balance profile, and an exhausted retry budget are
/// all *outcomes* — the caller must be made to handle them, which a sealed
/// hierarchy does and an exception does not.
///
/// The governing rule from the owner: **recover automatically only when
/// correctness is provable; otherwise fail closed. Never guess in a way that
/// can duplicate grants.**
library;

import 'package:meta/meta.dart';

import '../engine/game_state.dart';

/// Which of the two snapshot slots.
///
/// Two slots, ping-pong, because Dart cannot fsync a directory and so the
/// durability of a rename is not verifiable from where we stand. Atomicity
/// here is a property of *never overwriting the live copy*, not of the
/// filesystem's rename semantics.
enum SnapshotSlot {
  a,
  b;

  SnapshotSlot get other =>
      this == SnapshotSlot.a ? SnapshotSlot.b : SnapshotSlot.a;

  String get fileName => 'save_slot_$name';
}

/// Why a single artifact could not be used.
///
/// Per-artifact findings, accumulated during recovery. Distinct from
/// [LoadRefusal], which is a decision about the whole load: a truncated slot
/// with a healthy sibling is a *successful* load that happens to have a
/// diagnosis attached.
enum SaveDiagnosis {
  slotAbsent,
  slotTruncated,
  slotMalformedEncoding,
  slotIntegrityMismatch,
  slotFutureSaveFormat,
  slotUnsupportedStateVersion,
  slotIncompleteCommit,
  slotHeaderDisagreesWithPayload,
  slotGenerationTie,
  journalTailTorn,
  journalCorruptInterior,
  journalSequenceGap,
  journalDuplicateTransaction,
  journalForked,
  journalOrphaned,
  snapshotOlderThanJournal,
  interruptedCompaction,

  /// A slice carried an origin that is not a valid pseudonymous key.
  ///
  /// Distinct from generic malformed encoding because the cause and the fix
  /// differ: this one means an adapter wrote a raw platform identifier past
  /// the pseudonymization boundary.
  originKeyRejected,
}

// `journalLineageMismatch` and `snapshotNewerThanJournal` were declared here
// and never produced. Removed rather than left as aspiration: the first is
// covered by `LoadRefusal.lineageMismatch`, which *is* produced, and the second
// described the normal state between a commit and the next compaction — a
// repair that is always present tells nobody anything.

/// Why a load was refused outright.
enum LoadRefusal {
  /// The save was written by a newer build.
  futureSaveFormat,

  /// The state version is outside the supported range.
  unsupportedStateVersion,

  /// The content schema is not one this build can read.
  unsupportedContentSchema,

  /// The save references content that no longer exists.
  ///
  /// **Refuse, never drop.** Dropping silently deletes the player's
  /// possessions, and since content IDs are permanent, a missing one means
  /// someone broke that rule — which should stop a build, not a player.
  unknownContent,

  /// The save's balance profile is not one this build knows.
  unknownProfile,

  /// A release build was asked to load an `accelerated_qa` save.
  qaProfileForbiddenInRelease,

  /// The save's profile differs from the running one and needs a deliberate
  /// migration or a new game.
  profileMigrationRequired,

  /// Journal records belong to a different save lineage.
  lineageMismatch,

  /// Two records claim the same transaction with different contents.
  journalForked,

  /// Neither slot could be read.
  allSlotsUnreadable,

  /// Both slots are valid, carry the same generation, and disagree.
  ///
  /// Fail closed. There is no principled way to choose, and choosing wrong
  /// either duplicates or destroys a grant.
  divergentSlotsAtSameGeneration,

  /// The origin pseudonymization key changed, so every persisted origin would
  /// be re-keyed and every device would look new.
  originKeyReset,
}

/// A repair recovery performed, or a condition it noticed.
@immutable
final class SaveRepair {
  const SaveRepair(this.diagnosis, {this.detail});

  final SaveDiagnosis diagnosis;
  final String? detail;

  @override
  String toString() =>
      detail == null ? diagnosis.name : '${diagnosis.name}: $detail';
}

/// The result of loading a save.
@immutable
sealed class LoadOutcome {
  const LoadOutcome();
}

/// No save exists. A new game is the correct response.
///
/// Reached **only** when both slots are absent *and* the journal is empty.
/// Anything less is a corruption case, because treating "no primary snapshot"
/// as "new player" is a successful load that returns a wiped character.
final class NoSaveFound extends LoadOutcome {
  const NoSaveFound();
}

/// The save loaded.
final class SaveLoaded extends LoadOutcome {
  SaveLoaded({
    required this.state,
    required this.saveId,
    required this.fromSlot,
    required this.generation,
    required this.lastAppliedTransaction,
    required this.replayedTransactions,
    required this.skippedTransactions,
    required List<SaveRepair> repairs,
  }) : repairs = List<SaveRepair>.unmodifiable(repairs);

  final GameState state;

  /// The lineage the loaded snapshot was written under.
  ///
  /// Exposed so a caller can compare it with the identity it holds. Without
  /// it, an identity from another lineage resumes silently and every later
  /// commit is written under the mismatched id -- which forks the journal on
  /// the next transaction.
  final String saveId;

  final SnapshotSlot fromSlot;
  final int generation;
  final int lastAppliedTransaction;
  final int replayedTransactions;
  final int skippedTransactions;
  final List<SaveRepair> repairs;

  /// True when the load fell back or discarded something.
  bool get degraded => repairs.isNotEmpty;
}

/// This build cannot safely read this save.
///
/// A refusal **never deletes anything**. It means "not by me, not now" — a
/// version skew that deletes the save turns a recoverable situation into
/// permanent loss.
final class LoadRefused extends LoadOutcome {
  LoadRefused({
    required this.reason,
    required this.explanation,
    List<SaveRepair> repairs = const <SaveRepair>[],
  }) : repairs = List<SaveRepair>.unmodifiable(repairs);

  final LoadRefusal reason;

  /// Player-legible, and names the artifact. Never contains an origin key,
  /// a bucket, or anything derived from health data.
  final String explanation;

  final List<SaveRepair> repairs;
}

/// The result of committing a transaction.
@immutable
sealed class CommitOutcome {
  const CommitOutcome();
}

/// The transaction is durable.
final class CommitDurable extends CommitOutcome {
  const CommitDurable({
    required this.transactionId,
    required this.generation,
    required this.slot,
    required this.snapshotDurable,
    required this.retries,
  });

  final int transactionId;
  final int generation;
  final SnapshotSlot slot;

  /// False when the journal committed but the snapshot write did not.
  ///
  /// **This is not an error and must not be reported as one.** The journal is
  /// the commit point; the snapshot is a cache, and the next launch replays.
  final bool snapshotDurable;

  /// How many compare-and-swap conflicts were resolved before this succeeded.
  final int retries;
}

/// The commit did not happen, and nothing partial was written.
final class CommitRefused extends CommitOutcome {
  const CommitRefused({required this.reason, required this.detail});

  final CommitRefusal reason;
  final String detail;
}

/// Why a commit was refused.
enum CommitRefusal {
  /// Durable state no longer matched `expectedSnapshotGeneration` or
  /// `expectedLastAppliedTransaction`, and the bounded retry budget ran out.
  ///
  /// The caller must reload and reconcile again rather than force the write.
  conflictRetryLimitExhausted,

  /// The journal append failed. The caller must treat the transaction as **not
  /// committed** and must not release the cursor.
  journalAppendFailed,

  /// Another writer held the transaction lock past the timeout.
  ///
  /// Nothing was written. The caller may retry; the lock exists so that a
  /// second repository over the same directory waits rather than forking
  /// the journal.
  storageBusy,

  // storageFull and writerBusy were declared here and never produced.
  //
  // A full disk arrives as an opaque exception the core cannot classify, so it
  // surfaces as `journalAppendFailed` — which carries exactly the same
  // obligation: the batch did not commit, and the cursor must not advance.
  // And the single-writer queue serializes callers rather than refusing them,
  // so nothing is ever busy.
  //
  // Dead members in a safety hierarchy read as coverage that does not exist.
}

/// The result of compacting the journal.
@immutable
final class CompactionOutcome {
  const CompactionOutcome({
    required this.removed,
    required this.retainedFrom,
    this.refusal,
  });

  /// A no-op is a success.
  const CompactionOutcome.skipped(this.refusal) : removed = 0, retainedFrom = 0;

  final int removed;
  final int retainedFrom;

  /// Set when compaction declined to run.
  final CompactionRefusal? refusal;
}

/// Why compaction declined.
enum CompactionRefusal {
  /// Fewer than two slots verify, so the floor is undefined.
  ///
  /// Compacting anyway can delete the only record a fallback would need.
  insufficientVerifiedSlots,

  /// Nothing to remove.
  nothingBelowFloor,
}
