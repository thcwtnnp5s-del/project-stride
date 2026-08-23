// The Transformation epoch (`DECISIONS/0018`) through the real session: the
// v2→v3 cutover waits for the first foreground sync, so the steps walked
// between the owner's last Phase 2 sync and this launch — the backlog — are
// retired with everything before them, and the playtest begins at zero.
//
// `packages/stride_core/test/transformation_epoch_test.dart` group 5 proves
// the transaction with the session's steps reproduced by hand. This file
// proves `StrideSession` itself performs them, in the same order, over the
// real repository and the real file layout — the code path a device runs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/debug/dev_harness.dart' show kHarnessNode;
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

StepObservation obs(int index, int steps) => StepObservation(
  key: ObservationKey(
    origin: phone,
    bucket: TimeBucket(
      startMillis: t0 + index * hour,
      endMillis: t0 + (index + 1) * hour,
    ),
  ),
  steps: steps,
);

/// A drained, complete page: one origin, one bucket, a cursor.
SyncFetch page(int index, int steps, {required String cursor}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[obs(index, steps)],
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

/// The Phase 2 device: `TOTAL WALKED` 464,946, the Phase 2 epoch at 459,223 /
/// 180, 780 spent, so 5,123 banked. A v2 save.
StepLedger phase2Ledger() => StepLedger.initial().copyWith(
  totalObserved: 464946,
  totalGranted: 464946,
  totalSpent: 780,
  epoch: const EconomyEpoch(
    grantedAtStart: 459223,
    spentAtStart: 180,
    establishedAtStateVersion: 2,
  ),
  grantedSlices: <ObservationKey, int>{obs(300, 5723).key: 5723},
  checkpoint: SyncCheckpoint(
    cursor: SyncCursor.ofString('phase-2-review'),
    syncCount: 14,
    originWatermarks: <StepOriginKey, int>{phone: t0 + 300 * hour},
  ),
  sourceState: SourceState.available,
);

const int backlogSteps = 2213;
SyncFetch backlogPage() =>
    page(301, backlogSteps, cursor: 'transformation-first-sync');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_deferred'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> launch(StepSyncSource source) =>
      StrideSession.start(overrideRoot: root, source: source);

  /// Puts a v2 save on disk under [root], the way a Phase 2 device left one:
  /// start a game so the identity and lineage exist, then commit [ledger] as a
  /// v2 state on top of it. The repository writes the state at the version it
  /// declares, so the next launch reads a v2 save.
  Future<void> plantV2Save({StepLedger? ledger}) async {
    final StrideSession seed = await launch(MockStepSource());
    final SaveLoaded head = await seed.reload() as SaveLoaded;
    final GameState current = seed.engine!.state;
    final GameState v2 = GameState(
      stateVersion: 2,
      profileId: current.profileId,
      contentPackVersion: current.contentPackVersion,
      player: current.player,
      inventory: current.inventory,
      equipment: current.equipment,
      skills: current.skills,
      world: current.world,
      steps: ledger ?? phase2Ledger(),
      eventSequence: current.eventSequence,
    );
    final CommitOutcome planted = await seed.runtime.repository.commit(
      after: v2,
      events: const <GameEvent>[],
      saveId: seed.saveId!,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: head.generation,
        expectedLastAppliedTransaction: head.lastAppliedTransaction,
      ),
      originSaltFingerprint: seed.saltFingerprint,
    );
    expect(planted, isA<CommitDurable>(), reason: '$planted');
  }

  test(
    'a v2 save loads pending: unready for actions, syncable, at 0',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(script: <SyncFetch>[backlogPage()]),
      );

      expect(session.blocked, isNull);
      expect(session.migrationPending, isTrue);
      expect(session.migration, isNull);
      expect(session.engine!.state.stateVersion, 2);
      expect(session.engine!.state.steps.banked, 5123, reason: 'the ledger');
      expect(session.usableEnergy, 0, reason: 'the projection, not the ledger');
      expect(session.totalGranted, 464946, reason: 'history is not projected');
      expect(session.retiredSteps, 459043, reason: 'the Phase 2 body, as yet');
      expect(session.isReady, isFalse);
      expect(session.canSync, isTrue);
      expect(session.canGather(kHarnessNode), isFalse);
      expect(
        session.destinations.every((TravelOption o) => !o.affordable),
        isTrue,
        reason: 'nothing is affordable out of a balance about to be retired',
      );
    },
  );

  test('(e) gather, travel and craft refuse while pending', () async {
    await plantV2Save();
    final StrideSession session = await launch(MockStepSource());

    final ActionReport gathered = await session.gather(kHarnessNode);
    expect(gathered.succeeded, isFalse);
    expect(gathered.rejection, 'session_not_ready');
    expect(gathered.detail, contains('sync'));

    final TravelOption? somewhere = session.destinations.isEmpty
        ? null
        : session.destinations.first;
    if (somewhere != null) {
      final TravelReport travelled = await session.travel(somewhere.id);
      expect(travelled.succeeded, isFalse);
      expect(travelled.rejection, 'session_not_ready');
    }

    final RecipeOption? recipe = session.recipeOptions.isEmpty
        ? null
        : session.recipeOptions.first;
    if (recipe != null) {
      final CraftReport crafted = await session.craft(recipe.id);
      expect(crafted.succeeded, isFalse);
      expect(crafted.rejection, 'session_not_ready');
    }

    // Nothing moved: no commit, still pending, still v2.
    expect(session.migrationPending, isTrue);
    expect(session.engine!.state.stateVersion, 2);
    expect(session.isStale, isFalse);
  });

  test(
    '(a) the first sync retires the backlog and completes the cutover at 0',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(script: <SyncFetch>[backlogPage()]),
      );

      final SyncReport report = await session.syncSteps();
      expect(report.status, SyncStatus.reconciled);
      expect(report.newlyGranted, backlogSteps);

      expect(session.migrationPending, isFalse);
      expect(session.isReady, isTrue);
      expect(session.isStale, isFalse);
      final GameState after = session.engine!.state;
      // The migrating launch lands the save at the current version — 3 when this
      // test was written, 4 since Combat Slice 01 (DECISIONS/0020, a
      // non-rebasing step). The 0018 mark below is still established at 3.
      expect(after.stateVersion, StateVersion.current.value);
      expect(after.steps.epoch.establishedAtStateVersion, 3);
      expect(after.steps.banked, 0);
      expect(session.usableEnergy, 0);
      expect(after.steps.totalGranted, 464946 + backlogSteps);
      expect(after.steps.epoch.grantedAtStart, 464946 + backlogSteps);
      expect(after.steps.epoch.spentAtStart, 780);
      expect(
        after.steps.checkpoint.cursor,
        SyncCursor.ofString('transformation-first-sync'),
        reason: 'advanced by the sync, once; never rewound',
      );
      expect(session.retiredSteps, 464166 + backlogSteps);

      final StateMigrationReport migration = session.migration!;
      expect(migration.fromStateVersion, 2);
      expect(migration.toStateVersion, StateVersion.current.value);
      expect(
        migration.stepsApplied.map((StateMigrationStep s) => s.to).toList(),
        <int>[3, 4, 5, 6, 7, 8, StateVersion.current.value],
        reason:
            'the 0018 mark, the 0020 / 0021 / 0022 / 0023 format bumps and '
            'the 0024 tracker repair — still one commit, however many steps '
            'ride along',
      );
      expect(migration.bankedAfter, 0);
      expect(migration.previouslyRetiredSteps, 459043);
      expect(migration.newlyRetiredSteps, 5123 + backlogSteps);

      // Durable: a relaunch reads v3, owes nothing, and shows the same figures.
      final StrideSession relaunched = await launch(MockStepSource());
      expect(relaunched.migrationPending, isFalse);
      expect(relaunched.migration, isNull);
      expect(relaunched.engine!.state.stateVersion, StateVersion.current.value);
      expect(relaunched.usableEnergy, 0);
      expect(relaunched.totalGranted, 464946 + backlogSteps);
      expect(relaunched.isReady, isTrue);
    },
  );

  test('(b) an immediate repeat sync grants 0 and banked stays 0', () async {
    await plantV2Save();
    final StrideSession session = await launch(
      MockStepSource(script: <SyncFetch>[backlogPage(), backlogPage()]),
    );
    await session.syncSteps();
    expect(session.usableEnergy, 0);

    final SyncReport again = await session.syncSteps();
    expect(again.newlyGranted, 0);
    expect(session.usableEnergy, 0);
    expect(session.totalGranted, 464946 + backlogSteps);
  });

  test(
    '(c) steps walked after the cutover grant once and are spendable',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(
          script: <SyncFetch>[
            backlogPage(),
            page(302, 1187, cursor: 'after-transformation-1'),
            page(302, 1187, cursor: 'after-transformation-1'),
          ],
        ),
      );
      await session.syncSteps();
      expect(session.usableEnergy, 0);

      final SyncReport walk = await session.syncSteps();
      expect(walk.newlyGranted, 1187);
      expect(session.usableEnergy, 1187);

      final SyncReport replay = await session.syncSteps();
      expect(replay.newlyGranted, 0);
      expect(session.usableEnergy, 1187);

      final int cost = session.costOf(kHarnessNode)!;
      final ActionReport gathered = await session.gather(kHarnessNode);
      expect(gathered.succeeded, isTrue, reason: '${gathered.rejection}');
      expect(session.usableEnergy, 1187 - cost);
    },
  );

  test(
    '(d) a launch after the sync landed but the migration did not: the sync '
    'grants 0 and the migration completes with the backlog inside it',
    () async {
      // The on-disk shape a crash between the two commits leaves: a v2 save
      // whose totals and cursor already include the backlog. Planted directly
      // — the window is inside one `syncSteps` call and cannot be interrupted
      // from a test — which is the same bytes a real crash would leave.
      final StepLedger afterSync = phase2Ledger().copyWith(
        totalObserved: 464946 + backlogSteps,
        totalGranted: 464946 + backlogSteps,
        grantedSlices: <ObservationKey, int>{
          obs(300, 5723).key: 5723,
          obs(301, backlogSteps).key: backlogSteps,
        },
        checkpoint: SyncCheckpoint(
          cursor: SyncCursor.ofString('transformation-first-sync'),
          syncCount: 15,
          originWatermarks: <StepOriginKey, int>{phone: t0 + 301 * hour},
        ),
      );
      await plantV2Save(ledger: afterSync);

      final StrideSession session = await launch(
        // The provider restates the same batch from the durable cursor.
        MockStepSource(script: <SyncFetch>[backlogPage()]),
      );
      expect(session.migrationPending, isTrue);
      expect(session.engine!.state.steps.banked, 5123 + backlogSteps);
      expect(session.usableEnergy, 0);

      final SyncReport report = await session.syncSteps();
      expect(report.newlyGranted, 0, reason: 'granted exactly once, before');
      expect(session.migrationPending, isFalse);
      expect(session.usableEnergy, 0);
      expect(session.totalGranted, 464946 + backlogSteps);
      expect(
        session.engine!.state.steps.epoch.grantedAtStart,
        464946 + backlogSteps,
      );
      expect(session.migration!.newlyRetiredSteps, 5123 + backlogSteps);
    },
  );

  test(
    '(f) health unavailable at the cutover: it still completes, at 0',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(
          script: <SyncFetch>[
            MockStepSource.unavailable(
              ProviderUnavailableReason.serviceUnavailable,
            ),
          ],
        ),
      );

      final SyncReport report = await session.syncSteps();
      expect(report.status, SyncStatus.unavailable);
      expect(session.migrationPending, isFalse);
      expect(session.isReady, isTrue);
      expect(session.usableEnergy, 0);
      expect(session.totalGranted, 464946);
      expect(session.migration!.newlyRetiredSteps, 5123);
      expect(session.migration!.bankedAfter, 0);
      // The cursor did not move: nothing was observed.
      expect(
        session.engine!.state.steps.checkpoint.cursor,
        SyncCursor.ofString('phase-2-review'),
      );
    },
  );

  test(
    '(f) authorization denied at the cutover: it still completes, at 0',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(
          authorization: HealthAuthorization.denied,
          script: <SyncFetch>[
            MockStepSource.unavailable(
              ProviderUnavailableReason.permissionUnavailable,
            ),
          ],
        ),
      );
      expect(await session.requestPermission(), HealthAuthorization.denied);

      final SyncReport report = await session.syncSteps();
      expect(report.status, SyncStatus.unavailable);
      expect(session.migrationPending, isFalse);
      expect(session.usableEnergy, 0);
      expect(session.migration!.bankedAfter, 0);
    },
  );

  test(
    'the controller runs the startup sync even though isReady is false',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(script: <SyncFetch>[backlogPage()]),
      );
      final SessionController controller = SessionController(session);
      addTearDown(controller.dispose);
      expect(session.isReady, isFalse);

      await controller.startupSync();

      expect(session.migrationPending, isFalse);
      expect(session.isReady, isTrue);
      expect(session.usableEnergy, 0);
      expect(session.totalGranted, 464946 + backlogSteps);
      expect(controller.lastSync?.newlyGranted, backlogSteps);
    },
  );

  test(
    'reload re-derives pending from disk, and the controller syncs after it',
    () async {
      await plantV2Save();
      final StrideSession session = await launch(
        MockStepSource(script: <SyncFetch>[backlogPage()]),
      );
      expect(session.migrationPending, isTrue);

      // A reload before any sync: the disk still holds a v2 save, so the session
      // still owes the migration, and still projects zero.
      await session.reload();
      expect(session.migrationPending, isTrue);
      expect(session.usableEnergy, 0);
      expect(session.isReady, isFalse);

      // The controller's reload follows through with the sync that completes it.
      final SessionController controller = SessionController(session);
      addTearDown(controller.dispose);
      await controller.reload();
      expect(session.migrationPending, isFalse);
      expect(session.isReady, isTrue);
      expect(session.usableEnergy, 0);
      expect(session.totalGranted, 464946 + backlogSteps);

      // And a reload after completion finds v3 and owes nothing.
      await session.reload();
      expect(session.migrationPending, isFalse);
      expect(session.migration, isNotNull, reason: 'it happened this launch');
    },
  );
}
