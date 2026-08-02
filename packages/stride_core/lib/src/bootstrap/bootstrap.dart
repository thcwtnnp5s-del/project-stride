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

  /// The pseudonymization salt does not match the one the save was written
  /// with, so every origin would re-key and the retention window would be
  /// granted a second time.
  originIdentityMismatch,

  /// The save references content that does not exist in this build.
  unknownContentReferences,

  /// Storage could not be opened at all.
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

    // --- storage --------------------------------------------------------
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
      return BootstrapBlocked(
        reason: BootstrapBlockReason.originIdentityMismatch,
        stoppedAt: BootstrapPhase.validatingState,
        explanation:
            'Stride found saved progress but not the health-source key that '
            'goes with it. Reconnect health to continue; your earned progress '
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
