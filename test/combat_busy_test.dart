// `SessionController.combatBusy` — the flag that keeps the combat stage
// mounted across a killing blow's mid-commit frame.
//
// On that frame the encounter is already cleared in memory and the report has
// not yet returned, so `session.encounter` and `lastCombat` are both null;
// the Adventure screen reading only those two unmounted the stage for one
// frame, flashed the location cards, and skipped the victory replay. The
// screen now also reads `combatBusy`, and this file proves the flag spans the
// whole in-flight window: it is raised synchronously before the command's
// first await and cleared in its `finally` — so there is no frame inside a
// combat command where all three conditions are false.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId kWoods = ContentId.unchecked('location.whispering_woods');
final ContentId kWolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId kSword = ContentId.unchecked('item.training_sword');
final ContentId kTunic = ContentId.unchecked('item.traveler_tunic');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_cbusy'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  test('combatBusy spans every combat command from before its first await '
      'to its return — including the round that ends the fight', () async {
    final StrideSession s = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(5000)],
      ),
    );
    await s.syncSteps();
    await s.syncSteps();
    expect((await s.equip(kSword)).succeeded, isTrue);
    expect((await s.equip(kTunic)).succeeded, isTrue);
    expect((await s.travel(kWoods)).succeeded, isTrue);

    final SessionController c = SessionController(s);
    addTearDown(c.dispose);

    // Raised synchronously — no frame can observe the command in flight with
    // the flag down.
    final Future<void> started = c.startEncounter(kWolf);
    expect(c.combatBusy, isTrue);
    await started;
    expect(c.combatBusy, isFalse);
    expect(c.lastCombat!.succeeded, isTrue);

    // Attack to the end. On every round — the killing blow included — the
    // flag is up for the whole await, which is exactly the window where the
    // engine has cleared the encounter and the report has not yet landed.
    for (int i = 0; i < 60 && s.encounter != null; i++) {
      final Future<void> round = c.combatAttack();
      expect(c.combatBusy, isTrue);
      expect(
        s.encounter != null || c.lastCombat?.outcome != null || c.combatBusy,
        isTrue,
        reason: 'the Adventure screen mounting condition must hold in flight',
      );
      await round;
      expect(c.combatBusy, isFalse);
    }

    // The fight resolved, and after the final round the outcome report is
    // what holds the stage up — the flag hands over, never both-null.
    expect(s.encounter, isNull);
    expect(c.lastCombat?.outcome, isNotNull);
  });
}
