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
/// A blocked bootstrap **never deletes anything**. Refusing is recoverable —
/// a newer build, a fixed content pack, a health reconnect. Deleting is not.
///
/// ## The identity ordering
///
/// Four rules, in the order they are enforced. They are stated here because the
/// third and fourth are the ones that look like defects to a reader who does
/// not know the failure they prevent.
///
/// 1. **Read the identity before the save, and refuse if the read faults.**
///    The identity is what the save's origin keys were produced from, so the
///    save cannot be interpreted without it. A read that *faults* is not
///    absence, and is [BootstrapBlockReason.storageUnavailable].
/// 2. **Existing save, no identity ⇒ [BootstrapBlockReason.originIdentityMissing].**
///    Distinct from a mismatch, because the causes and the diagnostics differ:
///    a mismatch means two identities exist, and a miss means the device-bound
///    one did not travel. On iOS the second is the *expected* shape of an
///    iCloud restore onto a new phone, and it is the whole point of the
///    Keychain being `ThisDeviceOnly`.
/// 3. **Existing save, different identity ⇒
///    [BootstrapBlockReason.originIdentityMismatch].**
/// 4. **No save and no identity ⇒ mint, and only then.** The load runs *before*
///    [mintIdentity] is ever called. Minting first and then discovering a save
///    would leave a fresh identity beside a save it cannot interpret, which is
///    unrecoverable in the direction that matters: the save is then refused
///    forever, by an identity we created ourselves.
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

  /// A journal was present but its correctness could not be established.
  ///
  /// The catch-all for "recovery ran and could not prove the result", which is
  /// exactly when guessing is most tempting and least safe.
  recoveryNotProvable,
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
  });

  final GameEngine engine;
  final ContentRegistry registry;
  final ReconciliationIdentity identity;

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
    // An identity present with no save is not automatically wrong — a crash
    // between minting and the first commit produces exactly that — so it is
    // reused rather than replaced. Minting a second identity would orphan any
    // save that did in fact exist.
    final ReconciliationIdentity identity = stored ?? mint();
    if (stored == null) {
      // Written before the first commit, not after.
      //
      // The two orderings fail differently, and one of them is recoverable:
      //
      //   identity then save : a crash in between leaves an identity with no
      //                        save. The next launch reuses it. Harmless.
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
    }

    final GameEngine engine = GameEngine.newGame(registry: registry);

    // Persisted immediately, and the caller is told only after it is durable.
    // A "new game" that exists solely in memory is a first session the player
    // loses to a process kill.
    final CommitOutcome commit = await repository.commit(
      after: engine.state,
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
      // The identity we just wrote is deliberately left in place. Erasing it
      // here would be a blocked bootstrap deleting something, and the next
      // launch reuses an orphan identity perfectly well — whereas a save
      // written under an identity we then deleted could never be opened again.
      return BootstrapBlocked(
        reason: BootstrapBlockReason.storageUnavailable,
        stoppedAt: BootstrapPhase.openingStorage,
        explanation: 'Stride could not save a new game.',
        detail: <String>[commit.reason.name],
      );
    }

    return BootstrapNewGame(
      engine: engine,
      registry: registry,
      identity: identity,
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
