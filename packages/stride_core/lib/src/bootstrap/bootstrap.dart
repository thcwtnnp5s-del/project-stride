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
import '../engine/events.dart';
import '../engine/game_engine.dart';
import '../ports/identity_store.dart';
import '../save/save_outcomes.dart';
import '../save/save_repository.dart';

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

/// An existing save loaded.
final class BootstrapExistingGame extends BootstrapOutcome {
  BootstrapExistingGame({
    required this.engine,
    required this.registry,
    required this.identity,
    required this.load,
  });

  final GameEngine engine;
  final ContentRegistry registry;
  final ReconciliationIdentity identity;

  /// What loading actually did — which slot, how much replay, what repairs.
  final SaveLoaded load;

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

    final GameEngine engine = GameEngine(registry: registry, state: load.state);

    return BootstrapExistingGame(
      engine: engine,
      registry: registry,
      identity: stored,
      load: load,
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
