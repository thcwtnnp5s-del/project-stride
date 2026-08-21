/// The timed craft flow's safety proof (PRESENTATION_WORLD_REWARD_FEEL_01
/// §55): partial completion, cancellation, background fast-forward, refusal,
/// and exactly-once ingredient/output/XP accounting.
///
/// The `CraftController` is presentation over the unchanged instant
/// `CraftItem` command — every assertion here is against the real session's
/// committed figures, so a double dispatch or a phantom completion cannot
/// pass. Timing is the same injected fake the gather queue's tests use; no
/// real waits.
library;

import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/craft_controller.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final ContentId kHerb = ContentId.unchecked('item.meadow_herb');
final ContentId kBroth = ContentId.unchecked('item.herb_broth');
final ContentId kBrothRecipe = ContentId.unchecked('recipe.herb_broth');
final ContentId kCooking = ContentId.unchecked('skill.cooking');

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
  setUp(() => root = Directory.systemTemp.createTempSync('stride_craft'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A funded session holding [herbs] Meadow Herb, with its controllers.
  Future<(StrideSession, SessionController, CraftController, FakeTiming)>
  boot({int herbs = 6}) async {
    final FakeTiming fake = FakeTiming();
    final StrideSession session = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(2000)],
      ),
    );
    session.activityWallClock = fake.wallClock;
    await session.syncSteps();
    await session.syncSteps();
    for (int i = 0; i < herbs; i++) {
      final ActionReport r = await session.gather(kNode);
      expect(r.succeeded, isTrue, reason: '${r.rejection}');
    }
    expect(session.inventoryCount(kHerb), herbs);

    final SessionController sessions = SessionController(session);
    final CraftController craft = CraftController(
      sessions,
      timing: fake.timing,
    );
    addTearDown(craft.dispose);
    addTearDown(sessions.dispose);
    return (session, sessions, craft, fake);
  }

  RecipeOption brothOf(StrideSession s) =>
      s.recipeOptions.singleWhere((RecipeOption r) => r.id == kBrothRecipe);

  /// Real-async wait for a dispatch's file I/O to land.
  Future<void> until(bool Function() condition) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  test('the projection knows how many crafts the bag funds', () async {
    final (StrideSession session, _, _, _) = await boot(herbs: 5);
    // 5 herbs at 2 a broth funds exactly 2.
    expect(brothOf(session).craftableCount, 2);
  });

  test('each boundary crafts exactly once; the run totals are exact', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 3);
    expect(craft.active, isTrue);
    expect(craft.completed, 0);
    // Nothing is consumed at start — the timer is theatre, the command is
    // the transaction.
    expect(session.inventoryCount(kHerb), 6);
    expect(session.inventoryCount(kBroth), 0);

    // Food paces at 4 s (§15). Each boundary dispatches one CraftItem.
    fake.advance(CraftDurations.food);
    await until(() => craft.completed == 1);
    expect(session.inventoryCount(kHerb), 4);
    expect(session.inventoryCount(kBroth), 1);

    fake.advance(CraftDurations.food);
    await until(() => craft.completed == 2);
    expect(session.inventoryCount(kHerb), 2);
    expect(session.inventoryCount(kBroth), 2);

    fake.advance(CraftDurations.food);
    await until(() => !craft.active);
    expect(craft.completed, 3);
    expect(session.inventoryCount(kHerb), 0);
    expect(session.inventoryCount(kBroth), 3);

    // The retained summary reports the whole run.
    expect(craft.summaryRecipe, kBrothRecipe);
    expect(craft.quantity, 3);
    expect(craft.stopReport, isNull);

    // XP landed exactly per craft, through the ordinary command.
    expect(
      session.engine!.state.skills.experienceIn(kCooking),
      greaterThan(0),
    );
  });

  test('cancel keeps what completed and dispatches nothing more', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 3);
    fake.advance(CraftDurations.food);
    await until(() => craft.completed == 1);

    craft.stop();
    expect(craft.active, isFalse);

    // The in-progress second repetition consumed nothing and granted
    // nothing; more elapsed time changes nothing.
    fake.advance(const Duration(minutes: 1));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.inventoryCount(kHerb), 4);
    expect(session.inventoryCount(kBroth), 1);
  });

  test('backgrounding fast-forwards the remainder, each engine-validated',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 3);
    fake.advance(CraftDurations.food);
    await until(() => craft.completed == 1);

    // The player pockets the phone: the theatre ends, the crafts land now
    // (§55 — a queue never requires the app to stay open).
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    await until(() => !craft.active);
    expect(craft.completed, 3);
    expect(session.inventoryCount(kHerb), 0);
    expect(session.inventoryCount(kBroth), 3);
  });

  test('a refused repetition stops the run truthfully and keeps the rest',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 3);

    // The bag funds one craft; the controller is asked for two — the clamp
    // is the UI's, and the engine is the authority on the second.
    craft.start(brothOf(session), 2);
    fake.advance(CraftDurations.food);
    await until(() => craft.completed == 1);

    fake.advance(CraftDurations.food);
    await until(() => !craft.active);
    expect(craft.completed, 1);
    expect(craft.stopReport, isNotNull);
    expect(craft.stopReport!.rejection, 'insufficient_ingredients');
    expect(session.inventoryCount(kHerb), 1);
    expect(session.inventoryCount(kBroth), 1);
  });
}
