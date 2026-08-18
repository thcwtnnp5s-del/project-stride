/// A brand-new game begins spendable-zero: its first authorised reconcile is
/// retired as history (`DECISIONS/0019`).
///
/// The device finding behind it: a fresh container has no save to migrate, so
/// the 0018 cutover cannot reach it, and the first sync would otherwise bank
/// the health store's whole retention window as currency.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps, {int index = 0, String cursor = 'c1'}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
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

/// The backlog a health store holds on the day the game is installed.
const int backlog = 23417;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_baseline'));
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

  test(
    'fresh game + backlog: first authorised reconcile retires it, banked 0',
    () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[page(backlog)],
      );
      final StrideSession session = await launch(source);
      expect(session.baselinePending, isTrue);
      expect(session.usableEnergy, 0);

      final SyncReport report = await session.syncSteps();
      expect(report.newlyGranted, backlog, reason: 'granted — as history');
      expect(session.totalGranted, backlog, reason: 'H-2: never lowered');
      expect(session.usableEnergy, 0, reason: 'retired by the baseline');
      expect(session.engine!.state.steps.banked, 0);
      expect(session.baselinePending, isFalse);
      final EconomyEpoch epoch = session.engine!.state.steps.epoch;
      expect(epoch.grantedAtStart, backlog);
      expect(epoch.spentAtStart, 0);
      expect(epoch.establishedAtStateVersion, StateVersion.current.value);
      expect(session.hasCursor, isTrue, reason: 'forward-only, not rewound');
      expect(session.totalSpent, 0);
      expect(session.isReady, isTrue);
    },
  );

  test('repeat sync grants nothing; new steps grant once and spend', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[page(backlog)],
    );
    final StrideSession session = await launch(source);
    await session.syncSteps();

    final SyncReport again = await session.syncSteps();
    expect(again.newlyGranted, 0);
    expect(session.usableEnergy, 0);

    source.enqueue(page(640, index: 1, cursor: 'c2'));
    final SyncReport walked = await session.syncSteps();
    expect(walked.newlyGranted, 640);
    expect(session.usableEnergy, 640, reason: 'post-baseline steps spend');
    expect(session.totalGranted, backlog + 640);
    expect((await session.syncSteps()).newlyGranted, 0, reason: 'once');
    expect(session.usableEnergy, 640);
  });

  test('a denied or unavailable answer does not set the baseline', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[page(backlog)],
      authorization: HealthAuthorization.denied,
    );
    final StrideSession session = await launch(source);
    // The mock still serves the page under "denied" (a real store would not),
    // so the ledger holds the backlog here; the point is that the *baseline*
    // waits for a granted read, and `usableEnergy` is deliberately not
    // projected while pending (see `StrideSession.baselinePending`).
    await session.syncSteps();
    expect(session.baselinePending, isTrue, reason: 'origin untouched');
    expect(session.totalGranted, backlog);

    // Now the player allows Steps. The next sync reads nothing new (the
    // cursor advanced) and the baseline lands over what is on the ledger.
    source.authorization = HealthAuthorization.granted;
    await session.syncSteps();
    expect(session.baselinePending, isFalse);
    expect(session.usableEnergy, 0);
    expect(session.totalGranted, backlog);
  });

  test(
    'crash after the sync commit, before the baseline: relaunch heals',
    () async {
      // First launch: sync commits the backlog, then the process dies before
      // the baseline commit — modelled by planting a state that has grants and
      // an origin epoch, which is exactly what such a crash leaves on disk.
      final StrideSession first = await launch(
        MockStepSource(script: <SyncFetch>[page(backlog)]),
      );
      final SaveLoaded head = await first.reload() as SaveLoaded;
      final GameState current = first.engine!.state;
      final GameEngine scratch = GameEngine(
        registry: first.registry!,
        state: current,
      );
      scratch.execute(ReconcileStepSync(response: page(backlog).response));
      final GameState crashed = scratch.state; // grants in, epoch still origin
      expect(crashed.steps.epoch.isOrigin, isTrue);
      expect(crashed.steps.banked, backlog);
      final CommitOutcome planted = await first.runtime.repository.commit(
        after: crashed,
        events: const <GameEvent>[],
        saveId: first.saveId!,
        expectation: CommitExpectation(
          expectedSnapshotGeneration: head.generation,
          expectedLastAppliedTransaction: head.lastAppliedTransaction,
        ),
        originSaltFingerprint: first.saltFingerprint,
      );
      expect(planted, isA<CommitDurable>(), reason: '$planted');

      // Relaunch: the ledger shows the backlog (and so does `usableEnergy`,
      // which is deliberately not projected while the baseline is pending —
      // this one window is what the app's startup sync heals), and the first
      // sync (nothing new — cursor advanced) sets the baseline.
      final StrideSession second = await launch(MockStepSource());
      expect(second.engine!.state.steps.banked, backlog);
      expect(second.baselinePending, isTrue);
      await second.syncSteps();
      expect(second.baselinePending, isFalse);
      expect(second.usableEnergy, 0);
      expect(second.totalGranted, backlog);

      // And it survives a reload from disk.
      await second.reload();
      expect(second.baselinePending, isFalse);
      expect(second.usableEnergy, 0);
    },
  );

  test('a save with no health at all stays playable and unbaselined', () async {
    final StrideSession session = await launch(
      MockStepSource(
        available: false,
        authorization: HealthAuthorization.unavailable,
      ),
    );
    await session.syncSteps();
    expect(session.baselinePending, isTrue);
    expect(session.isReady, isTrue, reason: 'crafting at zero still works');
  });
}
