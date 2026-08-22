/// Startup, as an explicit state machine over ports.
///
/// Pure. It orchestrates a `ContentSource`, a `SaveRepository`, and a
/// `ReconciliationIdentityStore` — all of which are abstractions — so the whole
/// of startup is testable by `dart test` on Windows in milliseconds, including
/// every way it can refuse.
///
/// ## The rule the states exist to enforce
///
/// **Never silently create a new game when an existing save is unreadable.**
///
/// That failure is the worst one available here: it is a *successful* startup
/// that returns a wiped character, and by the time the player notices, the
/// evidence has usually been overwritten. So "no save" and "a save I cannot
/// read" are different states reached by different paths, and the second is
/// always [BootstrapBlocked].
///
/// A blocked bootstrap **never deletes a save, a journal, or an identity that
/// could interpret one.** Refusing is recoverable — a newer build, a fixed
/// content pack, a health reconnect. Deleting is not.
///
/// That claim used to be the unqualified "never deletes anything", and it was
/// not true of the code beneath it even then. There is exactly one deletion on
/// any path here, it is narrow, and it is stated rather than hidden: an
/// **orphan identity** — one that the load has conclusively proven has no save
/// and no journal beside it — is removed before a new lineage is provisioned.
/// Nothing else is ever deleted, and the proof required for that one case is
/// the strongest the protocol can produce (see rule 5 below).
///
/// ## The identity ordering
///
/// Five rules, in the order they are enforced. They are stated here because
/// several of them look like defects to a reader who does not know the failure
/// they prevent.
///
/// 1. **Read the identity before the save, and refuse if the read faults.**
///    The identity is what the save's origin keys were produced from, so the
///    save cannot be interpreted without it. A read that *faults* is not
///    absence, and is [BootstrapBlockReason.storageUnavailable]. A save that is
///    merely *busy* is neither, and is
///    [BootstrapBlockReason.storageBusy] — the storage is available and in use.
/// 2. **Existing save, no identity ⇒ [BootstrapBlockReason.originIdentityMissing].**
///    Distinct from a mismatch, because the causes and the diagnostics differ:
///    a mismatch means two identities exist, and a miss means the device-bound
///    one did not travel. On iOS the second is the *expected* shape of an
///    iCloud restore onto a new phone, and it is the whole point of the
///    Keychain being `ThisDeviceOnly`.
/// 3. **Existing save, different identity ⇒
///    [BootstrapBlockReason.originIdentityMismatch].**
/// 4. **Provisioning is identity-first, and the load runs before any of it.**
///    [mintIdentity] is never called until the save has been looked for and the
///    load has concluded [NoSaveFound]. Minting first and then discovering a
///    save would leave a fresh identity beside a save it cannot interpret,
///    which is unrecoverable in the direction that matters: the save is then
///    refused forever, by an identity we created ourselves. Within provisioning
///    the identity is written *before* the first commit, because the two
///    orderings fail asymmetrically — see `_startNewGame`.
/// 5. **An orphan identity is replaced, not reused — and only on the strongest
///    possible proof.** An identity with no save is what an interrupted first
///    save leaves behind. Reusing it looks harmless and is not: its `saveId`
///    would become the lineage of a *different*, later save, so a lineage id
///    would stop meaning "the save it was minted for". It is therefore deleted
///    and reprovisioned — but only through [NoSaveFound], which requires both
///    slots to be conclusively **absent** and the journal to be empty. A
///    truncated slot, a corrupt slot, a busy lock, or an unreadable device all
///    fail closed and delete nothing, because none of them proves absence.
///
/// Rule 4 is why `mintIdentity` is a callback rather than a value. A value
/// would be computed by the caller before `run` is entered, and the ordering
/// would then be a property of the *caller's* code — which is where it was
/// wrong before, and where it would go wrong again.
library;

import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/content_loader.dart';
import '../content/content_registry.dart';
import '../content/validation.dart';
import '../engine/commands.dart';
import '../engine/events.dart';
import '../engine/game_engine.dart';
import '../engine/game_state.dart';
import '../engine/rejection.dart';
import '../engine/state_migrations.dart';
import '../engine/state_version.dart';
import '../ports/identity_store.dart';
import '../save/save_outcomes.dart';
import '../save/save_repository.dart';
import '../steps/step_ledger.dart';

/// Where startup has got to.
///
/// Ordered as they occur, so a phase reported in a diagnostic says how far the
/// app got before it stopped.
enum BootstrapPhase {
  starting,
  loadingContent,
  openingStorage,
  loadingSave,
  recoveringJournal,
  validatingState,
  readyNewGame,
  readyExistingGame,
  blocked,
}

/// Why startup could not proceed.
///
/// Every one of these is a refusal to guess. The alternative in each case is a
/// game that opens onto something the player did not leave behind.
enum BootstrapBlockReason {
  /// The content pack failed validation. The game's rules are not loadable.
  invalidContent,

  /// Neither snapshot slot could be read, and this is not a new installation.
  bothSlotsInvalid,

  /// The save was written by a newer build.
  unsupportedSaveVersion,

  /// A release build was asked to open an `accelerated_qa` save.
  qaProfileForbidden,

  /// The save's balance profile is unknown, or differs from the running one.
  profileMismatch,

  /// A save exists and there is **no** reconciliation identity beside it.
  ///
  /// Distinct from [originIdentityMismatch], and the distinction is the point
  /// of this whole refusal rather than a taxonomic nicety.
  ///
  /// On iOS this is the expected shape of an **iCloud restore onto a second
  /// device**. The identity lives in the Keychain with
  /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so it does not travel
  /// in a backup; the save and the ledger, absent the backup exclusions, might.
  /// The restored device therefore finds progress with no key, and that is
  /// exactly what must stop the ledger replaying against a HealthKit source the
  /// original device has already consumed from.
  ///
  /// Before the identity was device-bound, this case could not arise from a
  /// restore at all — the identity file travelled *with* the save, the
  /// fingerprints matched, and the fail-closed check was defeated by the exact
  /// transport it was designed to detect.
  ///
  /// A mismatch says two identities exist and disagree. A miss says the
  /// device-bound one did not come with the device. Same refusal, different
  /// causes, and a diagnostic that conflated them would send anyone
  /// investigating to the wrong place.
  originIdentityMissing,

  /// The pseudonymization salt does not match the one the save was written
  /// with, so every origin would re-key and the retention window would be
  /// granted a second time. Or the identity belongs to a different lineage.
  originIdentityMismatch,

  /// The save references content that does not exist in this build.
  unknownContentReferences,

  /// Storage could not be opened at all.
  ///
  /// Includes a secure store that could not answer — a Keychain read before the
  /// first unlock since boot returns `errSecInteractionNotAllowed`, which is
  /// "ask me later" and must never be read as "there is nothing here".
  storageUnavailable,

  /// The save is in use by another process, and this launch waited long enough.
  ///
  /// **Deliberately distinct from [storageUnavailable].** The storage is
  /// available; it is open, healthy, and held by someone else — a background
  /// step sync, most likely. Folding the two together would send anyone
  /// investigating towards a broken device, and would let a transient condition
  /// wear the wording of a permanent one. Nothing was read, nothing was
  /// written, and the next launch normally succeeds.
  storageBusy,

  /// A full reset was started and did not finish.
  ///
  /// The durable reset intent is still present. This is what stops a
  /// half-erased directory presenting as a new installation; re-running the
  /// reset completes it.
  resetIncomplete,

  /// A journal was present but its correctness could not be established.
  ///
  /// The catch-all for "recovery ran and could not prove the result", which is
  /// exactly when guessing is most tempting and least safe.
  recoveryNotProvable,

  /// A save needed a state migration and the migrated state would not commit.
  ///
  /// Refused rather than played, deliberately. Continuing on the in-memory
  /// migrated state would give the player a session whose economy has been
  /// re-based and whose save still says otherwise — and the next launch would
  /// migrate again, from a ledger that had moved. One migration applied twice
  /// against different totals is a permanently wrong balance, so a migration
  /// that cannot be made durable stops startup instead.
  ///
  /// Nothing is lost by stopping: the pre-migration save is untouched on disk,
  /// and a later launch that can write will migrate it identically.
  stateMigrationNotCommittable,

  /// A new game was committed and did not read back.
  ///
  /// The first snapshot is written, verified by the repository, and then
  /// **reloaded** before the player is told the game exists. A commit that
  /// reports success over storage that cannot reproduce it is not a ready
  /// game, and handing one back would make the first session the one the player
  /// loses.
  newGameNotVerifiable,
}

/// The outcome of startup.
@immutable
sealed class BootstrapOutcome {
  const BootstrapOutcome();

  BootstrapPhase get phase;
}

/// No save existed. A new game was created and persisted.
final class BootstrapNewGame extends BootstrapOutcome {
  const BootstrapNewGame({
    required this.engine,
    required this.registry,
    required this.identity,
    required this.load,
  });

  final GameEngine engine;
  final ContentRegistry registry;
  final ReconciliationIdentity identity;

  /// The verification read of the save that was just written.
  ///
  /// Carried for the same reason [BootstrapExistingGame.load] is: a caller that
  /// intends to commit needs `generation` and `lastAppliedTransaction` to build
  /// a [CommitExpectation], and there is no other way to obtain them without
  /// performing a second full load. Without this the app's first commit after a
  /// new game would have to guess the durable head, and a guess that is wrong
  /// is refused as a compare-and-swap conflict rather than being detected.
  ///
  /// It is the same `SaveLoaded` step 6 already produced, so nothing extra is
  /// read to supply it.
  final SaveLoaded load;

  @override
  BootstrapPhase get phase => BootstrapPhase.readyNewGame;
}

/// What a state migration did, when one ran.
///
/// Reported rather than performed silently. A launch that re-based the player's
/// economy is the single most consequential thing startup can do to a save, and
/// the acceptance script has to be able to see that it happened exactly once —
/// on the first launch after the upgrade, and on no launch after that.
@immutable
final class StateMigrationReport {
  const StateMigrationReport({
    required this.fromStateVersion,
    required this.toStateVersion,
    required this.retiredSteps,
    required this.previouslyRetiredSteps,
    required this.bankedAfter,
    required this.stepsApplied,
  });

  final int fromStateVersion;
  final int toStateVersion;

  /// Steps that were banked before the current playable economy began and are
  /// not spendable — the **whole** retired body, across every cutover.
  ///
  /// They are not gone — `totalGranted` still carries every one of them, and
  /// `EconomyEpoch.retiredSteps` still reports them. They are simply outside the
  /// playable economy now.
  final int retiredSteps;

  /// Of [retiredSteps], the part that was already retired *before* this launch
  /// — the Phase 2 body, when the Transformation epoch runs on a v2 save. Zero
  /// when the save came from the origin epoch.
  final int previouslyRetiredSteps;

  /// What this launch retired: [retiredSteps] − [previouslyRetiredSteps]. The
  /// figure the acceptance script compares against the balance it saw before
  /// upgrading.
  int get newlyRetiredSteps => retiredSteps - previouslyRetiredSteps;

  /// The playable balance the migration produced. Zero, for every re-basing
  /// step so far.
  final int bankedAfter;

  /// The table steps this launch applied, in order.
  final List<StateMigrationStep> stepsApplied;

  @override
  String toString() =>
      'StateMigrationReport(v$fromStateVersion→v$toStateVersion; '
      'steps=${stepsApplied.length}; retired=$retiredSteps '
      '(previously $previouslyRetiredSteps, newly $newlyRetiredSteps); '
      'banked=$bankedAfter)';
}

/// The result of applying a migration path to a state, in memory.
///
/// Pure. Nothing here has touched storage; the caller commits [engine]'s state
/// and [events] together, once, and only a `CommitDurable` makes the migration
/// real.
@immutable
sealed class StateMigrationApplication {
  const StateMigrationApplication();
}

/// Every step applied. [engine] holds the migrated state; [events] is what the
/// steps produced, to be committed with it; [report] is what happened.
final class StateMigrationApplied extends StateMigrationApplication {
  const StateMigrationApplied({
    required this.engine,
    required this.events,
    required this.report,
  });

  final GameEngine engine;
  final List<GameEvent> events;
  final StateMigrationReport report;
}

/// A step's command was refused by the engine. Only reachable if the state
/// already carried an epoch established at or beyond the step's version, which
/// no decoder for an older version can produce.
final class StateMigrationRefused extends StateMigrationApplication {
  const StateMigrationRefused({required this.step, required this.rejection});

  final StateMigrationStep step;
  final CommandRejection rejection;
}

/// Applies [path] to [state], exactly as the coordinator does: reshape to the
/// current version first, then every re-basing step's `EstablishEconomyEpoch`,
/// in order, through the real engine.
///
/// The one implementation of "run the migration table", shared by the
/// bootstrap-time path and the deferred one, so the two cannot drift.
StateMigrationApplication applyStateMigrationPath({
  required ContentRegistry registry,
  required GameState state,
  required List<StateMigrationStep> path,
}) {
  final int from = state.stateVersion;
  final EconomyEpoch epochBefore = state.steps.epoch;

  // Format first, meaning second. `migratedToCurrentVersion` restates the
  // shape; the steps supply what the new shape *means*.
  final GameEngine engine = GameEngine(
    registry: registry,
    state: state.migratedToCurrentVersion(),
  );

  final List<GameEvent> events = <GameEvent>[];
  for (final StateMigrationStep step in path) {
    if (step.rebasesEconomy) {
      final EngineResult result = engine.execute(
        EstablishEconomyEpoch(
          fromStateVersion: step.from,
          toStateVersion: step.to,
        ),
      );
      final CommandRejection? refused = result.rejection;
      if (refused != null) {
        return StateMigrationRefused(step: step, rejection: refused);
      }
      events.addAll(result.events);
    }
    if (step.clearsStaleTrackedContract &&
        _trackedContractIsStale(registry, engine.state)) {
      final EngineResult result = engine.execute(
        const TrackGoal(slot: GoalSlot.contract),
      );
      final CommandRejection? refused = result.rejection;
      if (refused != null) {
        return StateMigrationRefused(step: step, rejection: refused);
      }
      events.addAll(result.events);
    }
  }

  return StateMigrationApplied(
    engine: engine,
    events: events,
    report: StateMigrationReport(
      fromStateVersion: from,
      toStateVersion: StateVersion.current.value,
      retiredSteps: engine.state.steps.epoch.retiredSteps,
      previouslyRetiredSteps: epochBefore.retiredSteps,
      bankedAfter: engine.state.steps.banked,
      stepsApplied: path,
    ),
  );
}

/// Whether the Contract tracker points at work the player is not actually
/// pursuing (`StateMigrationStep.clearsStaleTrackedContract`).
///
/// Both halves of the predicate are load-bearing, and each one exists to
/// protect a case the other would damage:
///
/// - **Not accepted.** An accepted contract is live work, whatever its
///   history, so an accepted tracker is never touched. This is the half that
///   protects a repeatable contract the player has completed before and is
///   right now doing again.
/// - **Completed at least once.** A contract the player has never finished
///   cannot be residue from a completion, so tracking one is an intention,
///   not a leftover. This is the half that protects an aspirational tracker
///   on a contract the player has lined up but not yet accepted — which the
///   Goal Board explicitly allows.
///
/// A delivery order has no acceptance step, so `acceptedContracts` never
/// holds one; a tracked delivery order that has been completed before is
/// therefore repaired too, which is correct — that is the same residue.
///
/// Projects are excluded outright. A project's tracker is answered from
/// `projects`/`completedProjects`, never rotates, and is cleared by the
/// reducer on the completing contribution.
bool _trackedContractIsStale(ContentRegistry registry, GameState state) {
  final ContentId? tracked = state.progress.tracked.contract;
  if (tracked == null) return false;
  if (registry.projects.containsKey(tracked)) return false;
  if (!registry.contracts.containsKey(tracked)) return false;
  if (state.progress.acceptedContracts.contains(tracked)) return false;
  return state.progress.completionsOf(tracked) > 0;
}

/// A migration the coordinator loaded but deliberately did not commit.
///
/// Produced when the save's remaining path contains a step that says
/// `afterFirstReconcile` (`StateMigrationStep.afterFirstReconcile`). The engine
/// handed back with it is at the save's **on-disk** version, and every commit
/// the session makes before completing the migration — the first sync's, above
/// all — is written at that version too. The next launch therefore reads an
/// old-version save, finds the same pending migration, and completes it then if
/// this launch could not; exactly-once is still the state version.
///
/// [apply] runs the whole path over whatever state the session has reached —
/// **after** the first sync, so the epoch marks totals that include the
/// backlog. The session commits the result once, through its ordinary commit
/// path.
@immutable
final class PendingStateMigration {
  const PendingStateMigration({
    required this.fromStateVersion,
    required this.steps,
  });

  /// The version the save was read at.
  final int fromStateVersion;

  /// The whole remaining path, in order.
  final List<StateMigrationStep> steps;

  /// Applies [steps] to [state]. Pure; see [applyStateMigrationPath].
  StateMigrationApplication apply({
    required ContentRegistry registry,
    required GameState state,
  }) => applyStateMigrationPath(registry: registry, state: state, path: steps);

  @override
  String toString() =>
      'PendingStateMigration(v$fromStateVersion→v${StateVersion.current.value}; '
      'steps=${steps.length})';
}

/// An existing save loaded.
final class BootstrapExistingGame extends BootstrapOutcome {
  BootstrapExistingGame({
    required this.engine,
    required this.registry,
    required this.identity,
    required this.load,
    this.migration,
    this.pendingMigration,
  }) : assert(
         migration == null || pendingMigration == null,
         'a migration is either done or pending, not both',
       );

  final GameEngine engine;
  final ContentRegistry registry;
  final ReconciliationIdentity identity;

  /// What loading actually did — which slot, how much replay, what repairs.
  ///
  /// **When [migration] is non-null this is the *pre-migration* read.** The
  /// migration commits after it, so `generation` and `lastAppliedTransaction`
  /// here are one transaction behind the durable head. A caller building a
  /// [CommitExpectation] must use [expectation], not these.
  final SaveLoaded load;

  /// Set when this launch migrated the save at bootstrap. Null on every
  /// ordinary launch, and null when the migration is [pendingMigration].
  final StateMigrationReport? migration;

  /// Set when the save needs a migration that must wait for the session's first
  /// foreground sync. Nothing was committed; [engine] is at the save's on-disk
  /// version, and [expectation] is the load's own head.
  final PendingStateMigration? pendingMigration;

  /// The compare-and-swap expectation for this session's next commit.
  ///
  /// Exists because [load] stops being the durable head the moment a migration
  /// commits, and a caller that kept using it would have its first real commit
  /// refused as a conflict — a confusing failure whose cause is two launches
  /// away from where it surfaces.
  CommitExpectation get expectation => migration == null
      ? CommitExpectation(
          expectedSnapshotGeneration: load.generation,
          expectedLastAppliedTransaction: load.lastAppliedTransaction,
        )
      : CommitExpectation(
          expectedSnapshotGeneration: load.generation + 1,
          expectedLastAppliedTransaction: load.lastAppliedTransaction + 1,
        );

  @override
  BootstrapPhase get phase => BootstrapPhase.readyExistingGame;
}

/// Startup stopped, and nothing was created or deleted.
final class BootstrapBlocked extends BootstrapOutcome {
  BootstrapBlocked({
    required this.reason,
    required this.stoppedAt,
    required this.explanation,
    this.detail = const <String>[],
  });

  final BootstrapBlockReason reason;

  /// The phase that failed, so a diagnostic can say how far startup got.
  final BootstrapPhase stoppedAt;

  /// Player-legible. Never carries an origin key, a bucket, a cursor, or
  /// anything else derived from health data.
  final String explanation;

  /// Additional lines — content ids, profile names. Never health-derived.
  final List<String> detail;

  @override
  BootstrapPhase get phase => BootstrapPhase.blocked;
}

/// Runs startup.
final class BootstrapCoordinator {
  const BootstrapCoordinator({
    required this.repository,
    required this.identityStore,
    required this.profileId,
    this.treatAsRelease = false,
  });

  final SaveRepository repository;
  final ReconciliationIdentityStore identityStore;

  /// Whether to apply release-build rules — chiefly refusing a QA-profile save.
  final bool treatAsRelease;

  /// Which balance profile to load content under.
  ///
  /// The save may still refuse it -- the save's own profile is authoritative
  /// -- but content has to be loaded under something before that comparison
  /// can happen.
  final ContentId profileId;

  /// Loads content, opens storage, and produces a ready engine or a refusal.
  ///
  /// [mintIdentity] supplies a save id and salt fingerprint for a brand-new
  /// installation. The core cannot generate either — no clock, no randomness —
  /// so the app provides them, and this is the only place they enter.
  ///
  /// **[mintIdentity] is called at most once, and never before the save has
  /// been looked for.** See the library comment, rule 4.
  Future<BootstrapOutcome> run({
    required Future<ContentSource> Function() loadContent,
    required ReconciliationIdentity Function() mintIdentity,
  }) async {
    // --- content --------------------------------------------------------
    final ContentSource source;
    try {
      source = await loadContent();
    } on Object catch (e) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.invalidContent,
        stoppedAt: BootstrapPhase.loadingContent,
        explanation: 'Stride could not read its content files.',
        detail: <String>['$e'],
      );
    }

    final ContentLoadResult result = const ContentLoader().load(
      source,
      profileId: profileId,
    );
    final ContentRegistry? registry = result.registry;
    if (registry == null) {
      // Fail with a typed error rather than partially loading. A registry that
      // is half-built is a game whose rules are half-defined, and every
      // downstream failure would point somewhere other than here.
      return BootstrapBlocked(
        reason: BootstrapBlockReason.invalidContent,
        stoppedAt: BootstrapPhase.loadingContent,
        explanation: 'Stride could not start because its content is invalid.',
        detail: result.report.errors
            .map((ValidationError e) => e.toString())
            .toList(),
      );
    }

    // --- identity, step 1 of the ordering -------------------------------
    //
    // Read first, because the save's origin keys were produced from it and
    // cannot be interpreted without it.
    //
    // A *fault* here is not absence, and the difference is the whole reason
    // the port distinguishes them. A Keychain read before the first unlock
    // since boot returns `errSecInteractionNotAllowed`; treating that as "no
    // identity" would take this launch straight down the path where a
    // replacement identity is minted over a live save. So it refuses, and the
    // next launch — after an unlock — succeeds.
    final ReconciliationIdentity? stored;
    try {
      stored = await identityStore.read();
    } on Object catch (e) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.storageUnavailable,
        stoppedAt: BootstrapPhase.openingStorage,
        explanation: 'Stride could not open its local storage.',
        detail: <String>['$e'],
      );
    }

    // --- save -----------------------------------------------------------
    //
    // Always before any minting. `_startNewGame` is reachable only through
    // `NoSaveFound`, which is the load's own conclusion and not a guess made
    // from a missing identity.
    final LoadOutcome outcome;
    try {
      outcome = await repository.load(
        registry: registry,
        treatAsRelease: treatAsRelease,
        originSaltFingerprint: stored?.saltFingerprint,
      );
    } on Object catch (e) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.storageUnavailable,
        stoppedAt: BootstrapPhase.loadingSave,
        explanation: 'Stride could not read its save files.',
        detail: <String>['$e'],
      );
    }

    return switch (outcome) {
      NoSaveFound() => _startNewGame(registry, stored, mintIdentity),
      SaveLoaded() => _resume(registry, outcome, stored),
      LoadRefused() => _blockedFrom(outcome),
    };
  }

  Future<BootstrapOutcome> _startNewGame(
    ContentRegistry registry,
    ReconciliationIdentity? stored,
    ReconciliationIdentity Function() mint,
  ) async {
    // Steps 1 and 2 of the provisioning protocol are already done, and were
    // done by the only component entitled to do them. Reaching here means the
    // load returned `NoSaveFound`, which it produces *only* when both slots
    // read as conclusively absent and the journal is empty — not when a slot is
    // truncated, malformed, integrity-broken, busy, or unreadable, each of
    // which is a refusal that never arrives here. Re-deriving that conclusion
    // in this method would be a second, weaker copy of it.

    if (stored != null) {
      // Step 3, the orphan case. An identity with no save at all is what an
      // interrupted first save leaves behind, and it is **replaced, not
      // reused**.
      //
      // Reuse was the previous behaviour and looks like the conservative
      // choice. It is not. The orphan's `saveId` is the lineage of a save that
      // was never written; binding it to a different, later save makes a
      // lineage id stop meaning "the save it was minted for", and every
      // downstream check that compares lineages — `_resume`, the journal scan,
      // `_checkSalt` — is weakened by exactly the amount that identifier stops
      // being trustworthy.
      //
      // The deletion is safe here and nowhere else, because `NoSaveFound` is
      // the strongest absence proof the protocol produces. A failed delete is
      // not fatal: it leaves the same orphan we started with, which the next
      // launch meets again.
      try {
        await identityStore.erase();
      } on Object catch (e) {
        return BootstrapBlocked(
          reason: BootstrapBlockReason.storageUnavailable,
          stoppedAt: BootstrapPhase.openingStorage,
          explanation:
              'Stride could not clear a leftover key from a previous '
              'start.',
          detail: <String>['$e'],
        );
      }
    }

    // Steps 3 and 4. Mint, and hold the fingerprint and saveId the first
    // snapshot will be written under.
    final ReconciliationIdentity identity = mint();

    // Written before the first commit, not after.
    //
    // The two orderings fail differently, and one of them is recoverable:
    //
    //   identity then save : a crash in between leaves an identity with no
    //                        save. The next launch proves the save is absent,
    //                        clears the orphan, and provisions again.
    //   save then identity : a crash in between leaves a save with no
    //                        identity — `originIdentityMissing`, forever,
    //                        caused by us.
    //
    // A store that refuses the write therefore stops startup here, with no
    // save on disk to be orphaned.
    try {
      await identityStore.write(identity);
    } on Object catch (e) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.storageUnavailable,
        stoppedAt: BootstrapPhase.openingStorage,
        explanation: 'Stride could not create its local storage.',
        detail: <String>['$e'],
      );
    }

    final GameEngine fresh = GameEngine.newGame(registry: registry);

    // Step 5. Persisted immediately, and the caller is told only after it is
    // durable. A "new game" that exists solely in memory is a first session the
    // player loses to a process kill.
    final CommitOutcome commit = await repository.commit(
      after: fresh.state,
      events: const <GameEvent>[],
      saveId: identity.saveId,
      expectation: const CommitExpectation(
        expectedSnapshotGeneration: -1,
        expectedLastAppliedTransaction: 0,
      ),
      // The whole point of the identity: the first snapshot records the
      // fingerprint that every later load validates against.
      originSaltFingerprint: identity.saltFingerprint,
    );

    if (commit is CommitRefused) {
      // Cleanup is *attempted*, and its failure is not.
      //
      // The identity we just wrote has no save under it and — because the
      // commit refused without writing anything — provably cannot acquire one
      // from this launch, so it is the same orphan rule as above.
      //
      // If the cleanup itself throws we still return a typed refusal. The
      // residue is a recoverable orphan, not a crash: the next launch either
      // proves absence again and clears it, or finds a save and diagnoses the
      // lineage properly. Turning a failed cleanup into an escaping exception
      // would convert a recoverable state into a launch that cannot report
      // anything at all.
      try {
        await identityStore.erase();
      } on Object {
        // Deliberately swallowed, and the reason is above.
      }
      return BootstrapBlocked(
        reason: commit.reason == CommitRefusal.storageBusy
            ? BootstrapBlockReason.storageBusy
            : BootstrapBlockReason.storageUnavailable,
        stoppedAt: BootstrapPhase.openingStorage,
        explanation: 'Stride could not save a new game.',
        detail: <String>[commit.reason.name],
      );
    }

    // Step 6. Reload and validate before returning.
    //
    // A new game that was committed but does not read back is not ready. The
    // repository verifies its own snapshot write, but that is a check of the
    // bytes it just produced; this is the first read that goes through the
    // whole load path — framing, envelope, lineage, salt, profile, content —
    // which is the path every later launch will use.
    final LoadOutcome verified;
    try {
      verified = await repository.load(
        registry: registry,
        treatAsRelease: treatAsRelease,
        originSaltFingerprint: identity.saltFingerprint,
      );
    } on Object catch (e) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.newGameNotVerifiable,
        stoppedAt: BootstrapPhase.validatingState,
        explanation: 'Stride saved a new game but could not read it back.',
        detail: <String>['$e'],
      );
    }

    if (verified is! SaveLoaded || verified.saveId != identity.saveId) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.newGameNotVerifiable,
        stoppedAt: BootstrapPhase.validatingState,
        explanation: 'Stride saved a new game but could not read it back.',
        detail: <String>[verified.runtimeType.toString()],
      );
    }

    // Step 7. The state the player is handed is the state that is durable, not
    // the one that was written — if those ever differ, the difference belongs
    // on the player's side of the boundary rather than hidden behind it.
    return BootstrapNewGame(
      engine: GameEngine(registry: registry, state: verified.state),
      registry: registry,
      identity: identity,
      load: verified,
    );
  }

  Future<BootstrapOutcome> _resume(
    ContentRegistry registry,
    SaveLoaded load,
    ReconciliationIdentity? stored,
  ) async {
    if (stored == null) {
      // A save exists and the identity that produced its origin keys does not.
      // Every origin would re-key on the next sync and the live retention
      // window would be granted twice. Refuse rather than guess.
      //
      // On iOS this is what an iCloud restore onto a second device looks like:
      // the Keychain item is `ThisDeviceOnly` and does not travel, so the
      // restored phone finds progress with no key. That is the refusal doing
      // its job — the ledger must not replay against a HealthKit source the
      // original device has already consumed from.
      return BootstrapBlocked(
        reason: BootstrapBlockReason.originIdentityMissing,
        stoppedAt: BootstrapPhase.validatingState,
        explanation:
            'Stride found saved progress but not the health-source key that '
            'goes with it. Reconnect health to continue; your earned progress '
            'is kept.',
      );
    }

    if (stored.saveId != load.saveId) {
      // The identity belongs to a different save.
      //
      // Resuming would write every later commit under the mismatched id,
      // which forks the journal lineage on the very next transaction and
      // leaves the next launch with `lineageMismatch` and no way out. The
      // origin keys in this save were also produced by a salt this identity
      // does not have.
      return BootstrapBlocked(
        reason: BootstrapBlockReason.originIdentityMismatch,
        stoppedAt: BootstrapPhase.validatingState,
        explanation:
            'Stride found saved progress that belongs to a different '
            'installation. Reconnect health to continue; your earned progress '
            'is kept.',
      );
    }

    if (StateVersion.migrationRequired(load.state.stateVersion)) {
      return _migrate(registry, load, stored);
    }

    final GameEngine engine = GameEngine(registry: registry, state: load.state);

    return BootstrapExistingGame(
      engine: engine,
      registry: registry,
      identity: stored,
      load: load,
    );
  }

  /// Brings an older save up to [StateVersion.current], durably, exactly once
  /// — at bootstrap, or, for a path that must see the first sync, by handing
  /// the session a [PendingStateMigration] to complete (see the last section).
  ///
  /// ## Why this runs here and not in the decoder
  ///
  /// A decoder-side upgrade would be recomputed on every launch and would never
  /// become durable, so nothing on disk would ever record that the cutover had
  /// happened. Running it here makes it a **transaction**: it inherits the
  /// whole-repository lock, the compare-and-swap against the durable head, the
  /// journal-first write order, and the read-back verification — everything a
  /// gather already gets.
  ///
  /// ## Exactly once
  ///
  /// The commit writes a state at [StateVersion.current]. The next launch reads
  /// that version, [StateVersion.migrationRequired] is false, and this method is
  /// never entered again. The version is the only signal, which is the point:
  /// see `EstablishEconomyEpoch` for why a second flag beside it would be a
  /// liability rather than a belt.
  ///
  /// ## The table, and one commit for the whole path
  ///
  /// The steps come from `StateMigrations.pathFrom`, and only a step that
  /// declares `rebasesEconomy` issues `EstablishEconomyEpoch` — with its own
  /// `toStateVersion`, so the command's guard can tell a v2 epoch from a v3 one.
  /// A v1 save therefore runs the v1→v2 step and then the v2→v3 step, in that
  /// order, and every event they produce is committed **once**, together. Two
  /// commits would make representable a durable save at an intermediate version
  /// carrying a later step's epoch — after a crash between them — which is
  /// exactly the shape the command would then refuse forever.
  ///
  /// ## Crash safety
  ///
  /// Every step before the commit is pure. If the process dies at any point, the
  /// pre-migration save is still on disk, unchanged, and the next launch derives
  /// the identical migration from the identical inputs. There is no partial
  /// state to detect and no repair to run, because nothing was written.
  ///
  /// ## The deferred path — a step that must see the first sync
  ///
  /// A re-basing step marks the epoch at the ledger's *current* totals, and at
  /// bootstrap those totals do not include the steps walked since the player's
  /// last sync. A bootstrap-time v2→v3 mark would leave that backlog outside the
  /// retired body, and the first sync — which runs after the first frame —
  /// would then grant it as spendable: the owner's playtest would begin at
  /// "whatever I walked since yesterday" rather than at zero.
  ///
  /// So a step may declare `afterFirstReconcile`, and when any step on the
  /// save's remaining path does, this method **commits nothing**. It returns
  /// [BootstrapExistingGame] with the engine at the save's on-disk version and
  /// [BootstrapExistingGame.pendingMigration] carrying the whole path. The
  /// session runs its first foreground sync against that engine — the sync
  /// commits at the old version, which the codec writes and the next launch
  /// reads back as that version — and then applies the path to the post-sync
  /// state, through [PendingStateMigration.apply], and commits once.
  ///
  /// The whole path is deferred, not just the deferring step, so the migration
  /// remains one commit; a v1 save is not committed at v2 in between. That is
  /// the same one-transaction property this method already has, and it costs
  /// nothing here: a v1 save's Phase 1 body would be retired by the v1→v2 mark
  /// either way, and the v2→v3 mark then finds nothing to add.
  ///
  /// Exactly-once is unchanged: the version is still the only signal. A crash
  /// between the sync's commit and the migration's commit leaves an old-version
  /// save whose cursor has already advanced; the next launch re-enters this
  /// path, its first sync grants nothing new, and the migration completes then
  /// with the same result. If the migration's commit is refused, the session
  /// goes stale like any other refused commit and a reload re-enters the
  /// pending state from disk.
  Future<BootstrapOutcome> _migrate(
    ContentRegistry registry,
    SaveLoaded load,
    ReconciliationIdentity identity,
  ) async {
    final int from = load.state.stateVersion;
    final List<StateMigrationStep> path = StateMigrations.pathFrom(from);

    if (StateMigrations.defersPastFirstReconcile(path)) {
      return BootstrapExistingGame(
        engine: GameEngine(registry: registry, state: load.state),
        registry: registry,
        identity: identity,
        load: load,
        pendingMigration: PendingStateMigration(
          fromStateVersion: from,
          steps: path,
        ),
      );
    }

    final StateMigrationApplication applied = applyStateMigrationPath(
      registry: registry,
      state: load.state,
      path: path,
    );
    if (applied is StateMigrationRefused) {
      // Only reachable if the save already carried an epoch established at
      // or beyond this step's version, which no decoder for an older version
      // can produce. Refused rather than ignored: a migration that cannot
      // explain itself must not proceed quietly.
      return BootstrapBlocked(
        reason: BootstrapBlockReason.stateMigrationNotCommittable,
        stoppedAt: BootstrapPhase.validatingState,
        explanation:
            'Stride could not upgrade your saved progress. Nothing was '
            'changed, and your progress is kept.',
        detail: <String>['${applied.step}', applied.rejection.format()],
      );
    }
    final StateMigrationApplied migrated = applied as StateMigrationApplied;

    final CommitOutcome outcome = await repository.commit(
      after: migrated.engine.state,
      events: migrated.events,
      saveId: load.saveId,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: load.generation,
        expectedLastAppliedTransaction: load.lastAppliedTransaction,
      ),
      originSaltFingerprint: identity.saltFingerprint,
    );

    if (outcome is! CommitDurable) {
      return BootstrapBlocked(
        reason: BootstrapBlockReason.stateMigrationNotCommittable,
        stoppedAt: BootstrapPhase.validatingState,
        explanation:
            'Stride could not save the upgrade to your progress. Nothing was '
            'changed. Try again; if it keeps happening, free some storage.',
        detail: <String>['state v$from → v${StateVersion.current.value}'],
      );
    }

    return BootstrapExistingGame(
      engine: migrated.engine,
      registry: registry,
      identity: identity,
      load: load,
      migration: migrated.report,
    );
  }

  BootstrapOutcome _blockedFrom(LoadRefused refusal) {
    final BootstrapBlockReason reason = switch (refusal.reason) {
      LoadRefusal.futureSaveFormat ||
      LoadRefusal.unsupportedStateVersion ||
      LoadRefusal.unsupportedContentSchema =>
        BootstrapBlockReason.unsupportedSaveVersion,
      LoadRefusal.qaProfileForbiddenInRelease =>
        BootstrapBlockReason.qaProfileForbidden,
      LoadRefusal.unknownProfile || LoadRefusal.profileMigrationRequired =>
        BootstrapBlockReason.profileMismatch,
      LoadRefusal.unknownContent =>
        BootstrapBlockReason.unknownContentReferences,
      // A fingerprint that exists and differs. The *absent* case never reaches
      // here: `_checkSalt` returns early when the running fingerprint is null,
      // so a missing identity is diagnosed by `_resume` as
      // `originIdentityMissing` rather than being folded into this one.
      LoadRefusal.originKeyReset => BootstrapBlockReason.originIdentityMismatch,
      LoadRefusal.allSlotsUnreadable ||
      LoadRefusal.divergentSlotsAtSameGeneration =>
        BootstrapBlockReason.bothSlotsInvalid,
      LoadRefusal.lineageMismatch ||
      LoadRefusal.journalForked => BootstrapBlockReason.recoveryNotProvable,
      // Available and in use, which is not the same as unavailable. Read as
      // "no save" it would start a new game over a live one; read as
      // `storageUnavailable` it would report a broken device that is fine.
      LoadRefusal.storageBusy => BootstrapBlockReason.storageBusy,
      LoadRefusal.resetIncomplete => BootstrapBlockReason.resetIncomplete,
    };

    return BootstrapBlocked(
      reason: reason,
      stoppedAt: reason == BootstrapBlockReason.recoveryNotProvable
          ? BootstrapPhase.recoveringJournal
          : BootstrapPhase.loadingSave,
      // The repository's explanation is already player-legible and already
      // free of health-derived values; it is not rewritten here, because two
      // wordings of the same refusal eventually disagree.
      explanation: refusal.explanation,
      detail: refusal.repairs.map((SaveRepair r) => r.diagnosis.name).toList(),
    );
  }
}
