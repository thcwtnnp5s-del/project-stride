// The playtest reset through the real session, repository and step source
// (`DECISIONS/0025`). The core proves the reducer; this proves the path the
// owner's thumb takes: reset → relaunch → the same Health samples → nothing
// re-banked → new walking banked once.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId node = ContentId.unchecked('resource_node.meadow_patch');
final ContentId herb = ContentId.unchecked('item.meadow_herb');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch walk({int steps = 3000, int index = 0, String cursor = 'c1'}) =>
    SyncFetch(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_ptreset'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  Future<StrideSession> launch(List<SyncFetch> script) => StrideSession.start(
    overrideRoot: root,
    source: MockStepSource(script: script),
  );

  /// A baselined game that has walked 3,000 and gathered twice.
  Future<StrideSession> played() async {
    final StrideSession s = await launch(<SyncFetch>[
      SyncFetch(const NoChangeSync()),
      walk(),
    ]);
    await s.syncSteps(); // the new-game baseline
    expect(s.baselinePending, isFalse);
    expect((await s.syncSteps()).newlyGranted, 3000);
    expect((await s.gather(node)).succeeded, isTrue);
    expect((await s.gather(node)).succeeded, isTrue);
    expect(s.inventoryCount(herb), greaterThan(0));
    return s;
  }

  test('the baseline reset: zero shown, history kept, replay grants nothing',
      () async {
    final StrideSession s = await played();
    final int granted = s.totalGranted;
    final int spent = s.totalSpent;
    final int herbs = s.inventoryCount(herb);
    expect(s.walkedSinceBaseline, granted);
    expect(s.walkedBaselineMoved, isFalse);

    final PlaytestResetReport r = await s.resetPlaytest(freshStart: false);
    expect(r.succeeded, isTrue, reason: '${r.rejection}: ${r.detail}');
    expect(r.retiredBanked, 3000 - spent);
    expect(r.walkedRetired, granted);

    expect(s.usableEnergy, 0);
    expect(s.walkedSinceBaseline, 0);
    expect(s.walkedBaselineMoved, isTrue);
    expect(s.totalGranted, granted, reason: 'lifetime is untouched');
    expect(s.totalSpent, spent);
    expect(s.inventoryCount(herb), herbs, reason: 'the bag is untouched');
    expect(s.hasCursor, isTrue, reason: 'the cursor is untouched');

    // Relaunch on the same save, and let the adapter re-deliver the same
    // walk — the shape of a Watch's late batch or a replayed page.
    final StrideSession again = await launch(<SyncFetch>[walk()]);
    expect(again.usableEnergy, 0, reason: 'the reset survived the save');
    expect(again.walkedSinceBaseline, 0);
    final SyncReport replay = await again.syncSteps();
    expect(replay.newlyGranted, 0, reason: 'old steps cannot come back');
    expect(again.usableEnergy, 0);
    expect(again.totalGranted, granted);

    // Then a genuinely new hour: banked once, shown once.
    final StrideSession later = await launch(<SyncFetch>[
      walk(steps: 1200, index: 1, cursor: 'c2'),
      walk(steps: 1200, index: 1, cursor: 'c2'),
    ]);
    expect((await later.syncSteps()).newlyGranted, 1200);
    expect(later.usableEnergy, 1200);
    expect(later.walkedSinceBaseline, 1200);
    expect((await later.syncSteps()).newlyGranted, 0);
    expect(later.usableEnergy, 1200);
    expect(later.totalGranted, granted + 1200);
  });

  test('the fresh start: the game is new, the ledger is not', () async {
    final StrideSession s = await played();
    final int granted = s.totalGranted;

    final PlaytestResetReport r = await s.resetPlaytest(freshStart: true);
    expect(r.succeeded, isTrue, reason: '${r.rejection}: ${r.detail}');
    expect(r.freshStart, isTrue);

    expect(s.usableEnergy, 0);
    expect(s.walkedSinceBaseline, 0);
    expect(s.totalGranted, granted);
    expect(s.inventoryCount(herb), 0, reason: 'the bag is new');
    expect(s.equippedSummary, isEmpty);
    expect(s.locationName, "Haven's Rest");
    for (final SkillSummary k in s.skillSummaries) {
      expect(k.experience, 0, reason: k.id.value);
    }

    // And it is durable: a relaunch with the same walk re-delivered banks
    // nothing and holds nothing.
    final StrideSession again = await launch(<SyncFetch>[walk()]);
    expect(again.inventoryCount(herb), 0);
    expect((await again.syncSteps()).newlyGranted, 0);
    expect(again.usableEnergy, 0);
    expect(again.totalGranted, granted);
  });

  test('a baseline reset is refused mid-queue; a fresh start drops it',
      () async {
    final StrideSession s = await played();
    expect(
      (await s.startActivityQueue(
        node,
        3,
        repetitionDuration: const Duration(seconds: 3),
      )).succeeded,
      isTrue,
    );
    final PlaytestResetReport refused = await s.resetPlaytest(
      freshStart: false,
    );
    expect(refused.succeeded, isFalse);
    expect(refused.rejection, 'activity_queue_active');

    final PlaytestResetReport fresh = await s.resetPlaytest(freshStart: true);
    expect(fresh.succeeded, isTrue, reason: '${fresh.rejection}');
    expect(s.engine!.state.activityQueue, isNull);
  });
}
