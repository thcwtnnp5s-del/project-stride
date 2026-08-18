// OD-01 — the step-economy cutover, end to end.
//
// ## What is actually at risk here
//
// This is the one change in the project that deliberately reduces a player's
// spendable balance, and the owner's device holds a real save with roughly
// 459,000 banked steps that it will be applied to. Three ways it could go wrong
// are worse than it simply not working:
//
// 1. **It runs twice.** A cutover that re-bases on a second launch zeroes a
//    player who has since walked. The damage is permanent and silent.
// 2. **It rewinds the cursor.** Re-granting the retention window is the exact
//    failure `RULES.md` H-3 exists to prevent and that two device runs proved
//    absent. A "reset" that reintroduces it is a severe regression in the one
//    guarantee the architecture is for.
// 3. **It lowers `totalGranted`.** That contradicts H-2 outright, and it would
//    make the historical figure — which the player did walk — unreportable.
//
// So the assertions below are mostly about what the migration *does not* do.
// The part that it produces a zero balance is one line; the rest is the
// evidence that it produced it without touching anything else.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

/// A ledger shaped like the owner's device at Phase 1 closure.
///
/// The real figures, not round ones: 459,223 granted against 459,043 banked,
/// with 180 spent on the acceptance gathers. Round numbers hide off-by-ones and
/// let a wrong formula coincide with a right one.
StepLedger phase1DeviceLedger() => StepLedger.initial().copyWith(
  totalObserved: 459223,
  totalGranted: 459223,
  totalSpent: 180,
  checkpoint: SyncCheckpoint(
    cursor: cursor('phase-1-closure'),
    syncCount: 12,
    originWatermarks: <StepOriginKey, int>{phone: t0 + 100 * hour},
  ),
  sourceState: SourceState.available,
);

GameState stateAt(int version, StepLedger ledger) => GameState(
  stateVersion: version,
  profileId: BalanceProfile.productionId,
  contentPackVersion: 1,
  player: const PlayerState.initial(),
  inventory: Inventory.empty(),
  equipment: Equipment.empty(),
  skills: SkillProgress.empty(),
  world: WorldState(
    currentLocation: saveRegistry.startLocation.id,
    unlockedLocations: <ContentId>{saveRegistry.startLocation.id},
  ),
  steps: ledger,
  eventSequence: 0,
);

/// Runs the migration exactly as `BootstrapCoordinator._migrate` does.
///
/// The same order — reshape the format, then apply the meaning of every table
/// step from the save's version — through the real engine and the real
/// command. A helper that reimplemented the arithmetic would prove the helper
/// right and say nothing about the shipped path.
///
/// Since `DECISIONS/0018` a v1 save walks two re-basing steps (v1→v2, v2→v3).
/// Every assertion in this file that held for one still holds for two, which
/// is itself the point: the second step retires nothing further from a ledger
/// the first has just re-based, and it touches nothing else either.
GameEngine migrate(GameState loaded) {
  final GameEngine engine = GameEngine(
    registry: saveRegistry,
    state: loaded.migratedToCurrentVersion(),
  );
  for (final StateMigrationStep step in StateMigrations.pathFrom(
    loaded.stateVersion,
  )) {
    if (!step.rebasesEconomy) continue;
    final EngineResult result = engine.execute(
      EstablishEconomyEpoch(
        fromStateVersion: step.from,
        toStateVersion: step.to,
      ),
    );
    expect(result.isAccepted, isTrue, reason: '$step: ${result.rejection}');
  }
  return engine;
}

void main() {
  group('1 — the cutover produces a zero playable bank, exactly once', () {
    test('the old historical bank becomes 0 playable steps', () {
      final GameState before = stateAt(1, phase1DeviceLedger());
      expect(before.steps.banked, 459043, reason: 'the fixture is the device');

      final GameState after = migrate(before).state;

      expect(after.steps.banked, 0);
    });

    test('relaunching does not reset again', () {
      // The second launch reads a v2 save, so the coordinator never enters the
      // migration path at all. Asserted on the flag the coordinator branches on
      // rather than on a comment about it.
      final GameState migrated = migrate(
        stateAt(1, phase1DeviceLedger()),
      ).state;

      expect(migrated.stateVersion, StateVersion.current.value);
      expect(StateVersion.migrationRequired(migrated.stateVersion), isFalse);
    });

    test('and the command refuses even if something did call it twice', () {
      // Defence behind the version, not instead of it. If a future caller ever
      // reaches this command on an already-migrated ledger, it must refuse
      // loudly rather than quietly zeroing a player who has since walked.
      final GameEngine engine = migrate(stateAt(1, phase1DeviceLedger()));
      final int bankedAfterFirst = engine.state.steps.banked;

      // Walk, so a second cutover would be visibly destructive.
      engine.execute(
        const GrantSyntheticSteps(steps: 5000, reason: 'post-cutover walk'),
      );
      expect(engine.state.steps.banked, 5000);

      final EngineResult second = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 1, toStateVersion: 2),
      );

      expect(second.isRejected, isTrue);
      expect(second.rejection!.code, RejectionCode.economyEpochAlreadySet);
      expect(
        engine.state.steps.banked,
        5000,
        reason: 'a refused cutover must not have taken the 5,000 walked steps',
      );
      expect(bankedAfterFirst, 0);
    });
  });

  group('2 — nothing historical is destroyed', () {
    late GameState before;
    late GameState after;

    setUp(() {
      before = stateAt(1, phase1DeviceLedger());
      after = migrate(before).state;
    });

    test('historical granted is not decreased — H-2 holds', () {
      expect(after.steps.totalGranted, before.steps.totalGranted);
      expect(after.steps.totalGranted, 459223);
      expect(
        after.steps.totalGranted,
        greaterThanOrEqualTo(before.steps.totalGranted),
        reason: 'granted is monotonic; a cutover is not a clawback',
      );
    });

    test('historical spent is not decreased either', () {
      expect(after.steps.totalSpent, before.steps.totalSpent);
      expect(after.steps.totalSpent, 180);
    });

    test('observed is untouched', () {
      expect(after.steps.totalObserved, before.steps.totalObserved);
    });

    test('the retired steps are still reportable, not forgotten', () {
      // The product may still truthfully say "you have walked 459,223 steps".
      // A cutover that made the history unreportable would be a product lying
      // about the walking it exists to celebrate.
      expect(after.steps.epoch.retiredSteps, 459043);
      expect(after.steps.totalGranted, 459223);
    });
  });

  group('3 — the health cursor is not rewound', () {
    test('the cursor, watermarks and sync count all survive verbatim', () {
      final GameState before = stateAt(1, phase1DeviceLedger());
      final GameState after = migrate(before).state;

      expect(
        after.steps.checkpoint.cursor?.bytes,
        before.steps.checkpoint.cursor?.bytes,
        reason:
            'rewinding the cursor would re-grant the retention window — the '
            'exact failure H-3 exists to prevent',
      );
      expect(
        after.steps.checkpoint.originWatermarks,
        before.steps.checkpoint.originWatermarks,
        reason: 'an unsettled origin re-grants its whole live window',
      );
      expect(after.steps.checkpoint.syncCount, 12);
      expect(after.steps.grantedSlices, before.steps.grantedSlices);
      expect(
        after.steps.grantedBeforeWatermark,
        before.steps.grantedBeforeWatermark,
      );
    });

    test('the epoch is the only thing that changed about the ledger', () {
      // The strongest form of "it touched nothing else": rebuild the migrated
      // ledger with the epoch put back to the origin and compare the whole
      // canonical encoding. Any other difference, in any field, fails here —
      // including one added by a future change that forgets this rule.
      final GameState before = stateAt(1, phase1DeviceLedger());
      final GameState after = migrate(before).state;

      expect(
        canonicalDurableStepLedger(
          after.steps.copyWith(epoch: const EconomyEpoch.origin()),
        ),
        canonicalDurableStepLedger(before.steps),
      );
    });
  });

  group('4 — the economy runs normally after the cutover', () {
    late GameEngine engine;

    setUp(() {
      engine = migrate(stateAt(1, phase1DeviceLedger()));
    });

    test('the first post-cutover steps grant correctly', () {
      engine.execute(
        const GrantSyntheticSteps(steps: 1200, reason: 'a real walk'),
      );

      expect(engine.state.steps.banked, 1200);
      expect(
        engine.state.steps.totalGranted,
        460423,
        reason: '459,223 + 1,200 — history keeps accumulating underneath',
      );
    });

    test('a spend after cutover affects only the post-cutover balance', () {
      engine.execute(const GrantSyntheticSteps(steps: 1200, reason: 'walk'));
      engine.execute(const AllocateSteps(steps: 500));

      expect(engine.state.steps.banked, 700);
      expect(engine.state.steps.totalSpent, 680, reason: '180 + 500');
      expect(engine.state.steps.epoch.spentAtStart, 180);
    });

    test('spending more than the post-cutover bank is refused', () {
      engine.execute(const GrantSyntheticSteps(steps: 100, reason: 'walk'));

      final EngineResult result = engine.execute(
        const AllocateSteps(steps: 5000),
      );

      expect(result.isRejected, isTrue);
      expect(result.rejection!.code, RejectionCode.insufficientSteps);
      expect(
        result.rejection!.explanation,
        contains('100'),
        reason:
            'the refusal must quote the *playable* balance, not the 459,143 '
            'the ledger has granted in total — a message naming the historical '
            'figure would tell the player they have steps they cannot spend',
      );
    });

    test('the historical bank is not spendable, at any size of request', () {
      // The whole point, stated as directly as it can be: a request the old
      // balance would have covered is refused.
      final EngineResult result = engine.execute(
        const AllocateSteps(steps: 459043),
      );

      expect(result.isRejected, isTrue);
      expect(result.rejection!.code, RejectionCode.insufficientSteps);
      expect(engine.state.steps.banked, 0);
    });
  });

  group('5 — a duplicate sync still grants nothing', () {
    test('the same batch twice grants once, across the cutover', () {
      // The cutover must not disturb slice bookkeeping. If it did, the first
      // post-cutover sync would look novel and re-grant.
      final GameEngine engine = migrate(stateAt(1, phase1DeviceLedger()));
      final SyncResponse batch = incremental(<StepObservation>[
        obs(phone, 200, 640),
      ], next: 'after-cutover-1');

      expect(sync(engine, batch).isAccepted, isTrue);
      final int afterFirst = engine.state.steps.banked;

      expect(sync(engine, batch).isAccepted, isTrue);

      expect(afterFirst, 640);
      expect(
        engine.state.steps.banked,
        640,
        reason: 'a replayed batch must grant nothing the second time',
      );
    });
  });

  group('6 — a new game is unaffected', () {
    test('it starts at the origin epoch and behaves exactly as before', () {
      final GameEngine engine = GameEngine.newGame(registry: saveRegistry);

      expect(engine.state.steps.epoch, const EconomyEpoch.origin());
      expect(engine.state.steps.epoch.isOrigin, isTrue);
      expect(engine.state.steps.banked, 0);
      expect(engine.state.stateVersion, StateVersion.current.value);

      engine.execute(const GrantSyntheticSteps(steps: 900, reason: 'walk'));

      expect(
        engine.state.steps.banked,
        900,
        reason:
            'under the origin epoch the arithmetic must reduce exactly to '
            'granted - spent, or the epoch is a special case rather than a '
            'generalization',
      );
    });
  });

  group('7 — no partial cutover state is representable', () {
    test('an epoch ahead of its own counter is refused, not clamped', () {
      expect(
        () => StepLedger.initial().copyWith(
          totalGranted: 100,
          epoch: const EconomyEpoch(
            grantedAtStart: 500,
            spentAtStart: 0,
            establishedAtStateVersion: 2,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => StepLedger.initial().copyWith(
          totalGranted: 100,
          totalSpent: 10,
          epoch: const EconomyEpoch(
            grantedAtStart: 0,
            spentAtStart: 50,
            establishedAtStateVersion: 2,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('an epoch that would make banked negative is refused', () {
      // Marking only granted, and forgetting that the save had also spent, is
      // the mistake the two-axis epoch exists to prevent. It is unrepresentable
      // rather than merely discouraged.
      expect(
        () => StepLedger.initial().copyWith(
          totalGranted: 1000,
          totalSpent: 180,
          epoch: const EconomyEpoch(
            grantedAtStart: 1000,
            spentAtStart: 0,
            establishedAtStateVersion: 2,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('the epoch survives a save round trip', () {
      final GameState after = migrate(stateAt(1, phase1DeviceLedger())).state;

      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: after,
            saveId: 'round-trip-0001',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;

      expect(reloaded.steps.epoch, after.steps.epoch);
      expect(reloaded.steps.banked, 0);
      expect(reloaded.steps.totalGranted, 459223);
      expect(
        canonicalDurableGameState(reloaded),
        canonicalDurableGameState(after),
      );
    });
  });
}
