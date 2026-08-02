/// The one ordered path that destroys a player's save.
///
/// It is a separate, explicitly-named entry point rather than a method on
/// something else, and that is a safety property rather than tidiness. A reset
/// must be reachable **only** from a deliberate player action; if it were a
/// step inside recovery, every fault that recovery could not classify would
/// eventually be routed through it, and the difference between "Stride cannot
/// read this" and "Stride deleted this" is the difference between a refusal the
/// player recovers from and a loss they do not.
///
/// ## The ordering, and why it is this way round
///
/// Save and journal first, identity last:
///
/// | | left behind by a death mid-reset | recoverable? |
/// |---|---|---|
/// | **save, journal, then identity** | an identity with no save | yes — the next launch clears the orphan and reprovisions |
/// | **identity, then save, journal** | a save with no identity | no — `originIdentityMissing`, permanently, caused by us |
///
/// The right-hand column is the whole argument. Every step is also *verified*
/// rather than assumed: `SaveRepository.eraseAll` reads the artifacts back, and
/// only its [EraseComplete] authorizes the identity delete below.
///
/// The ordering lives here, in the pure core, rather than in the app layer.
/// Sequencing rules that live next to the platform code are testable only on a
/// device, and this one has to be provable in milliseconds.
library;

import '../ports/identity_store.dart';
import 'save_outcomes.dart';
import 'save_repository.dart';

/// Runs a full reset, in order, and reports the step that stopped.
final class ResetCoordinator {
  const ResetCoordinator({
    required this.repository,
    required this.identityStore,
  });

  final SaveRepository repository;
  final ReconciliationIdentityStore identityStore;

  /// Deletes every save artifact and then the identity.
  ///
  /// Returns [EraseComplete] only when both halves are gone. Anything else is
  /// an [EraseRefused] naming the step, and leaves the durable reset intent in
  /// place — so the next launch refuses with [LoadRefusal.resetIncomplete]
  /// rather than presenting a half-erased directory as a new installation, and
  /// calling this again resumes the reset.
  ///
  /// **Only from an explicit player action.** Never from a failed load, a
  /// corrupt slot, an unreadable identity, or any other fault.
  Future<EraseOutcome> resetEverything() async {
    final EraseOutcome storage = await repository.eraseAll();
    if (storage is EraseRefused) return storage;

    // Last, and only now. Until this line the identity is the only thing that
    // could still interpret a save artifact, and one of them might have
    // survived a step above.
    try {
      await identityStore.erase();
    } on Object catch (e) {
      // A recoverable orphan, and named as one. The save is gone, so the next
      // launch finds an identity with conclusively no save artifacts beside it
      // and clears it before provisioning.
      return EraseRefused(
        reason: EraseRefusal.identityEraseFailed,
        detail: '$e',
      );
    }

    return const EraseComplete();
  }
}
