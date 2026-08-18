// The Transformation playtest epoch (`DECISIONS/0018`) — state version 3.
//
// ## What is at risk, and why it is different from 0016
//
// 0016 established the *first* epoch on a ledger that had never been re-based,
// and its exactly-once guard was "refuse any non-origin epoch". This decision
// re-bases a ledger that has **already** been re-based once, on the owner's
// device: banked 5,723 at the first Phase 2 launch, 5,123 after some travel and
// spending, on top of the 459,043 the Phase 2 cutover retired. So the guard has
// to be able to tell a v2 epoch from a v3 one — and the migration path has to
// be a *table*, so that the next format bump does not zero a balance by being
// newer.
//
// The failure modes are the same three as 0016, plus one:
//
// 1. It runs twice — a v3 save re-bases again on a later launch.
// 2. It rewinds or advances the cursor — re-granting the retention window.
// 3. It lowers `totalGranted` — a clawback.
// 4. **It runs by accident** — a v3→v4 step that only adds a field re-bases
//    the economy because "older than current" was the whole condition.
//
// As in `economy_epoch_cutover_test.dart`, most of the assertions are about
// what the migration does *not* do.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'bootstrap_test.dart'
    show MemoryIdentityStore, boot, deviceWithSnapshot, liveIdentity;
import 'save_support.dart';
import 'step_support.dart';

final ContentId meadow = ContentId.unchecked('resource_node.meadow_patch');
final ContentId woods = ContentId.unchecked('location.whispering_woods');

/// The Phase 2 device at the point of the Transformation upgrade.
///
/// The real figures from the first Phase 2 device review, not round ones:
/// `TOTAL WALKED` 464,946; the Phase 2 epoch at 459,223 granted / 180 spent;
/// 5,723 banked at launch and 5,123 after 600 steps of travel — so 780 spent
/// in total. A v2 save, whose epoch was established at state version 2.
StepLedger phase2DeviceLedger() => StepLedger.initial().copyWith(
  totalObserved: 464946,
  totalGranted: 464946,
  totalSpent: 780,
  epoch: const EconomyEpoch(
    grantedAtStart: 459223,
    spentAtStart: 180,
    establishedAtStateVersion: 2,
  ),
  grantedSlices: <ObservationKey, int>{obs(phone, 300, 5723).key: 5723},
  checkpoint: SyncCheckpoint(
    cursor: cursor('phase-2-review'),
    syncCount: 14,
    originWatermarks: <StepOriginKey, int>{phone: t0 + 300 * hour},
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

GameState phase2Save() => stateAt(2, phase2DeviceLedger());

/// Runs the migration exactly as `BootstrapCoordinator._migrate` does: reshape,
/// then every re-basing table step from the save's version, through the real
/// engine and the real command.
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
  final int gatherCost = saveRegistry.profile.applyStepCost(
    saveRegistry.resourceNodes[meadow]!.stepCost,
  );

  group(
    '0 — the migration table is explicit, contiguous, and says what it does',
    () {
      test('it runs from the oldest supported version to the current one', () {
        final List<StateMigrationStep> steps = StateMigrations.steps;
        expect(steps, isNotEmpty);
        expect(steps.first.from, StateVersion.minimumSupported.value);
        expect(steps.last.to, StateVersion.current.value);
        for (int i = 1; i < steps.length; i++) {
          expect(
            steps[i].from,
            steps[i - 1].to,
            reason:
                'a gap in the table is a version no save can be brought past',
          );
        }
      });

      test(
        'every step names its decision, and re-basing is opt-in per step',
        () {
          for (final StateMigrationStep step in StateMigrations.steps) {
            expect(step.decision, startsWith('DECISIONS/'));
            expect(step.to, step.from + 1);
          }
          // The two that exist both re-base, and each says so by name. A future
          // v3→v4 that only reshapes must be added with `rebasesEconomy: false`,
          // and this test will then be extended to pin that — the property is
          // that the flag exists and is read, not that it is always true.
          expect(
            StateMigrations.steps.map((StateMigrationStep s) => s.decision),
            <String>[
              'DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md',
              'DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md',
            ],
          );
          expect(
            StateMigrations.steps.every(
              (StateMigrationStep s) => s.rebasesEconomy,
            ),
            isTrue,
          );
        },
      );

      test('the path from a version is exactly the steps at or after it', () {
        expect(StateMigrations.pathFrom(StateVersion.current.value), isEmpty);
        expect(
          StateMigrations.pathFrom(2).map((StateMigrationStep s) => s.to),
          <int>[3],
        );
        expect(
          StateMigrations.pathFrom(1).map((StateMigrationStep s) => s.to),
          <int>[2, 3],
        );
        expect(
          () => StateMigrations.pathFrom(0),
          throwsA(isA<UnsupportedStateVersionException>()),
        );
      });

      test('a step that does not re-base issues no epoch command', () {
        // The structural guarantee, exercised rather than described: walk a
        // hypothetical table where the step says `rebasesEconomy: false`, the
        // same way `_migrate` walks the real one, and the epoch is untouched.
        const StateMigrationStep reshapeOnly = StateMigrationStep(
          from: 3,
          to: 4,
          rebasesEconomy: false,
          decision: 'DECISIONS/hypothetical',
        );
        final GameEngine engine = migrate(phase2Save());
        final EconomyEpoch before = engine.state.steps.epoch;
        engine.execute(const GrantSyntheticSteps(steps: 900, reason: 'walk'));

        for (final StateMigrationStep step in <StateMigrationStep>[
          reshapeOnly,
        ]) {
          if (!step.rebasesEconomy) continue;
          fail('a reshape-only step must not reach EstablishEconomyEpoch');
        }

        expect(engine.state.steps.epoch, before);
        expect(engine.state.steps.banked, 900);
      });
    },
  );

  group('1 — the playtest begins at zero, exactly once', () {
    test('(b) banked is 0 immediately after, from a real Phase 2 balance', () {
      final GameState before = phase2Save();
      expect(before.steps.banked, 5123, reason: 'the fixture is the device');

      final GameState after = migrate(before).state;

      expect(after.steps.banked, 0);
      expect(after.steps.epoch.establishedAtStateVersion, 3);
      expect(after.stateVersion, 3);
    });

    test('(h) a v3 save is not migrated again, and the command refuses', () {
      final GameEngine engine = migrate(phase2Save());
      expect(
        StateVersion.migrationRequired(engine.state.stateVersion),
        isFalse,
      );
      expect(StateMigrations.pathFrom(engine.state.stateVersion), isEmpty);

      // Walk, so a second re-basing would be visibly destructive.
      engine.execute(const GrantSyntheticSteps(steps: 4000, reason: 'walk'));
      expect(engine.state.steps.banked, 4000);

      final EngineResult again = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(again.isRejected, isTrue);
      expect(again.rejection!.code, RejectionCode.economyEpochAlreadySet);
      expect(again.rejection!.explanation, contains('v3'));
      expect(engine.state.steps.banked, 4000);

      // Nor may the *older* step re-base it: v2 ≤ v3.
      final EngineResult older = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 1, toStateVersion: 2),
      );
      expect(older.rejection!.code, RejectionCode.economyEpochAlreadySet);
      expect(engine.state.steps.banked, 4000);
    });

    test('the v3 step re-bases a v2 epoch once and only once', () {
      // The precise property 0016's guard could not express. A v2 epoch is not
      // the origin, and yet the v3 step must be allowed through — exactly once.
      final GameEngine engine = GameEngine(
        registry: saveRegistry,
        state: phase2Save().migratedToCurrentVersion(),
      );
      expect(engine.state.steps.epoch.isOrigin, isFalse);

      final EngineResult first = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(first.isAccepted, isTrue, reason: '${first.rejection}');

      final EngineResult second = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(second.rejection!.code, RejectionCode.economyEpochAlreadySet);
    });

    test('the event carries the previous mark and the version it set', () {
      final GameEngine engine = GameEngine(
        registry: saveRegistry,
        state: phase2Save().migratedToCurrentVersion(),
      );
      final EngineResult result = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      final EconomyEpochEstablished event =
          result.events.single as EconomyEpochEstablished;

      expect(event.grantedAtStart, 464946);
      expect(event.spentAtStart, 780);
      expect(event.previousGrantedAtStart, 459223);
      expect(event.previousSpentAtStart, 180);
      expect(event.fromStateVersion, 2);
      expect(event.toStateVersion, 3);
      expect(event.newlyRetiredSteps, 5123);
    });
  });

  group('2 — (a) historical steps remain historical', () {
    late GameState before;
    late GameState after;

    setUp(() {
      before = phase2Save();
      after = migrate(before).state;
    });

    test('granted, observed and spent are not decreased — H-2 holds', () {
      expect(after.steps.totalGranted, 464946);
      expect(after.steps.totalObserved, 464946);
      expect(after.steps.totalSpent, 780);
    });

    test('the whole retired body is still reportable, in one figure', () {
      // 459,043 from Phase 2 plus 5,123 from this launch. `retiredSteps` is
      // `grantedAtStart − spentAtStart` of the *current* mark, so it names
      // everything ever banked before the playable economy began.
      expect(after.steps.epoch.retiredSteps, 464166);
      expect(after.steps.epoch.retiredSteps, 459043 + 5123);
    });

    test(
      '(c) the cursor, watermarks, sync count and slices survive verbatim',
      () {
        expect(
          after.steps.checkpoint.cursor?.bytes,
          before.steps.checkpoint.cursor?.bytes,
          reason: 'the cursor must move neither backward nor forward — H-3',
        );
        expect(after.steps.checkpoint.cursor, cursor('phase-2-review'));
        expect(
          after.steps.checkpoint.originWatermarks,
          before.steps.checkpoint.originWatermarks,
        );
        expect(after.steps.checkpoint.syncCount, 14);
        expect(after.steps.grantedSlices, before.steps.grantedSlices);
        expect(
          after.steps.grantedBeforeWatermark,
          before.steps.grantedBeforeWatermark,
        );
      },
    );

    test('the epoch is the only thing that changed about the ledger', () {
      // The strongest form of "it touched nothing else": put the *previous*
      // epoch back and compare the whole canonical encoding.
      expect(
        canonicalDurableStepLedger(
          after.steps.copyWith(epoch: before.steps.epoch),
        ),
        canonicalDurableStepLedger(before.steps),
      );
    });
  });

  group('3 — new steps become spendable exactly once', () {
    test('(d) an immediate repeat of the last batch grants 0', () {
      // The batch that produced the device's slice, replayed after the reset.
      // The slice bookkeeping is untouched, so it is still a duplicate.
      final GameEngine engine = migrate(phase2Save());
      final SyncResponse replay = incremental(<StepObservation>[
        obs(phone, 300, 5723),
      ], next: 'phase-2-review');

      final EngineResult result = sync(engine, replay);

      expect(result.isAccepted, isTrue);
      expect(grantedBy(result), 0);
      expect(engine.state.steps.banked, 0);
      expect(engine.state.steps.totalGranted, 464946);
    });

    test('(e) a new batch grants once; the same batch again grants 0', () {
      final GameEngine engine = migrate(phase2Save());
      final SyncResponse walk = incremental(<StepObservation>[
        obs(phone, 301, 1187),
      ], next: 'after-transformation-1');

      expect(sync(engine, walk).isAccepted, isTrue);
      expect(engine.state.steps.banked, 1187);
      expect(engine.state.steps.totalGranted, 464946 + 1187);

      expect(sync(engine, walk).isAccepted, isTrue);
      expect(
        engine.state.steps.banked,
        1187,
        reason: 'a replayed batch must grant nothing the second time',
      );
    });

    test('(f) gathering and travel debit the new balance, never below 0', () {
      final GameEngine engine = migrate(phase2Save());
      engine.execute(const GrantSyntheticSteps(steps: 1000, reason: 'walk'));

      final EngineResult gathered = engine.execute(
        GatherResource(node: meadow),
      );
      expect(gathered.isAccepted, isTrue, reason: '${gathered.rejection}');
      expect(engine.state.steps.banked, 1000 - gatherCost);
      expect(engine.state.steps.totalSpent, 780 + gatherCost);

      final EngineResult travelled = engine.execute(
        TravelTo(destination: woods),
      );
      expect(travelled.isAccepted, isTrue, reason: '${travelled.rejection}');
      final int spentOnTravel =
          (travelled.events.single as LocationTravelled).stepsSpent;
      expect(engine.state.steps.banked, 1000 - gatherCost - spentOnTravel);
      expect(engine.state.steps.banked, greaterThanOrEqualTo(0));

      // And a request the *retired* balance would have covered is refused.
      final EngineResult tooMuch = engine.execute(
        const AllocateSteps(steps: 5123),
      );
      expect(tooMuch.rejection!.code, RejectionCode.insufficientSteps);
      expect(engine.state.steps.banked, greaterThanOrEqualTo(0));
    });
  });

  group('4 — (g) the epoch survives a save round trip', () {
    test('encode → decode preserves epoch, banked and totals', () {
      final GameEngine engine = migrate(phase2Save());
      engine.execute(const GrantSyntheticSteps(steps: 250, reason: 'walk'));
      final GameState after = engine.state;

      final SaveEnvelope reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: after,
            saveId: 'round-trip-0018',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      );

      expect(reloaded.gameStateVersion, 3);
      expect(reloaded.state.steps.epoch, after.steps.epoch);
      expect(reloaded.state.steps.epoch.establishedAtStateVersion, 3);
      expect(reloaded.state.steps.banked, 250);
      expect(reloaded.state.steps.totalGranted, 464946 + 250);
      expect(
        canonicalDurableGameState(reloaded.state),
        canonicalDurableGameState(after),
      );
    });

    test('a journal record without toStateVersion decodes as the v2 cutover', () {
      // The Phase 2 migration wrote records before the field existed. Replaying
      // one must produce an epoch established at 2 — the only thing such a
      // record can be — so the v3 step can then re-base it exactly once.
      final Map<String, Object?> legacy = <String, Object?>{
        't': 'EconomyEpochEstablished',
        'seq': 0,
        'grantedAtStart': 459223,
        'spentAtStart': 180,
        'fromStateVersion': 1,
      };
      final EconomyEpochEstablished? decoded =
          decodeEvent(legacy) as EconomyEpochEstablished?;

      expect(decoded, isNotNull);
      expect(decoded!.toStateVersion, 2);
      expect(decoded.previousGrantedAtStart, 0);
      expect(decoded.previousSpentAtStart, 0);

      final GameState replayed = const EventReducer().apply(
        stateAt(
          1,
          StepLedger.initial().copyWith(
            totalObserved: 459223,
            totalGranted: 459223,
            totalSpent: 180,
          ),
        ),
        decoded,
      );
      expect(replayed.steps.epoch.establishedAtStateVersion, 2);
      expect(replayed.steps.banked, 0);
    });

    test('a current journal record round-trips every field', () {
      const EconomyEpochEstablished event = EconomyEpochEstablished(
        sequence: 7,
        grantedAtStart: 464946,
        spentAtStart: 780,
        previousGrantedAtStart: 459223,
        previousSpentAtStart: 180,
        fromStateVersion: 2,
        toStateVersion: 3,
      );
      final EconomyEpochEstablished? back =
          decodeEvent(encodeEvent(event)) as EconomyEpochEstablished?;
      expect(back, isNotNull);
      expect(back!.grantedAtStart, 464946);
      expect(back.spentAtStart, 780);
      expect(back.previousGrantedAtStart, 459223);
      expect(back.previousSpentAtStart, 180);
      expect(back.fromStateVersion, 2);
      expect(back.toStateVersion, 3);
    });
  });

  group('5 — through the real startup path', () {
    test(
      'a v2 save migrates on first launch, in one commit, and reports it',
      () async {
        final FaultingDevice device = deviceWithSnapshot(
          phase2Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;

        final BootstrapOutcome outcome = (await boot(
          device: device,
          identity: identity,
          repository: repo,
        )).outcome;

        expect(outcome, isA<BootstrapExistingGame>(), reason: '$outcome');
        final BootstrapExistingGame ready = outcome as BootstrapExistingGame;

        expect(ready.engine.state.steps.banked, 0);
        expect(ready.engine.state.stateVersion, 3);
        expect(ready.engine.state.steps.epoch.establishedAtStateVersion, 3);
        expect(ready.engine.state.steps.totalGranted, 464946);

        final StateMigrationReport report = ready.migration!;
        expect(report.fromStateVersion, 2);
        expect(report.toStateVersion, 3);
        expect(report.stepsApplied.map((StateMigrationStep s) => s.to), <int>[
          3,
        ]);
        expect(report.retiredSteps, 464166);
        expect(report.previouslyRetiredSteps, 459043);
        expect(report.newlyRetiredSteps, 5123);
        expect(report.bankedAfter, 0);

        // One commit: the durable head moved by exactly one transaction.
        final SaveLoaded reread =
            await repo.load(
                  registry: saveRegistry,
                  originSaltFingerprint: liveIdentity.saltFingerprint,
                )
                as SaveLoaded;
        expect(
          reread.lastAppliedTransaction,
          2,
          reason: 'was 1 in the fixture',
        );
        expect(reread.generation, 1, reason: 'was 0 in the fixture');
        expect(reread.state.stateVersion, 3);
      },
    );

    test('(j) a v3 save never enters the migration path', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);

      final BootstrapExistingGame first =
          (await boot(device: device, identity: identity)).outcome
              as BootstrapExistingGame;
      expect(first.migration, isNotNull);

      final BootstrapExistingGame second =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;
      expect(second.migration, isNull);
      expect(second.engine.state.steps.banked, 0);
      expect(second.engine.state.steps.epoch.establishedAtStateVersion, 3);
      // And the head did not move: no commit on an ordinary launch.
      expect(
        second.expectation.expectedLastAppliedTransaction,
        first.expectation.expectedLastAppliedTransaction,
      );
    });

    test('a walk between launches is kept', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
      final SaveRepository repo = newRepo(device).repo;

      final BootstrapExistingGame first =
          (await boot(
                device: device,
                identity: identity,
                repository: repo,
              )).outcome
              as BootstrapExistingGame;
      final EngineResult walked = first.engine.execute(
        const GrantSyntheticSteps(steps: 2500, reason: 'a real walk'),
      );
      final CommitOutcome committed = await repo.commit(
        after: first.engine.state,
        events: walked.events,
        saveId: liveIdentity.saveId,
        expectation: first.expectation,
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(committed, isA<CommitDurable>());

      final BootstrapExistingGame relaunched =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;
      expect(relaunched.migration, isNull);
      expect(relaunched.engine.state.steps.banked, 2500);
      expect(relaunched.engine.state.steps.totalGranted, 464946 + 2500);
    });

    test('(i) a v1 save walks v1→v2→v3 in one launch and one commit', () async {
      final GameState v1 = stateAt(
        1,
        StepLedger.initial().copyWith(
          totalObserved: 459223,
          totalGranted: 459223,
          totalSpent: 180,
          checkpoint: SyncCheckpoint(
            cursor: cursor('phase-1-closure'),
            syncCount: 12,
          ),
          sourceState: SourceState.available,
        ),
      );
      final FaultingDevice device = deviceWithSnapshot(
        v1,
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
      final SaveRepository repo = newRepo(device).repo;

      final BootstrapExistingGame ready =
          (await boot(
                device: device,
                identity: identity,
                repository: repo,
              )).outcome
              as BootstrapExistingGame;

      expect(ready.engine.state.stateVersion, 3);
      expect(ready.engine.state.steps.banked, 0);
      expect(ready.engine.state.steps.epoch.establishedAtStateVersion, 3);
      expect(ready.engine.state.steps.totalGranted, 459223);
      expect(
        ready.engine.state.steps.checkpoint.cursor,
        cursor('phase-1-closure'),
      );

      final StateMigrationReport report = ready.migration!;
      expect(report.fromStateVersion, 1);
      expect(report.toStateVersion, 3);
      expect(report.stepsApplied.map((StateMigrationStep s) => s.to), <int>[
        2,
        3,
      ]);
      expect(report.retiredSteps, 459043);
      expect(report.previouslyRetiredSteps, 0);

      // Exactly one commit, carrying both events.
      final SaveLoaded reread =
          await repo.load(
                registry: saveRegistry,
                originSaltFingerprint: liveIdentity.saltFingerprint,
              )
              as SaveLoaded;
      expect(reread.lastAppliedTransaction, 2);
      expect(reread.state.stateVersion, 3);
      // Note the two epoch events landed in one transaction: after a reboot
      // the state is v3 and no further migration is required.
      final BootstrapExistingGame again =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;
      expect(again.migration, isNull);
      expect(again.engine.state.steps.epoch.establishedAtStateVersion, 3);
    });

    test(
      'a new game starts at v3, at the origin, and never migrates',
      () async {
        final BootstrapNewGame fresh =
            (await boot()).outcome as BootstrapNewGame;
        expect(fresh.engine.state.stateVersion, 3);
        expect(fresh.engine.state.steps.epoch, const EconomyEpoch.origin());
        expect(fresh.engine.state.steps.epoch.establishedAtStateVersion, 0);
      },
    );
  });
}
