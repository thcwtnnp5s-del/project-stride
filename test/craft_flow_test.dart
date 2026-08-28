/// The timed craft flow's safety proof (PRESENTATION_WORLD_REWARD_FEEL_01
/// §55): partial completion, cancellation, background/resume reconciliation,
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
    // Gathering rolls deterministic per-index yield bonuses (EPL01), so
    // N gathers can yield more than N herbs. Tests below work in deltas
    // off the real starting count rather than assuming the loop count.
    expect(session.inventoryCount(kHerb), greaterThanOrEqualTo(herbs));

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

    final int spentBefore = session.totalSpent;
    final int bankedBefore = session.usableEnergy;
    craft.start(brothOf(session), 3);
    expect(craft.active, isTrue);
    expect(craft.completed, 0);
    // Nothing is consumed at start — the timer is theatre, the command is
    // the transaction.
    expect(session.inventoryCount(kHerb), 6);
    expect(session.inventoryCount(kBroth), 0);

    // Food paces at 4 s (§15). Each boundary dispatches one CraftItem.
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => craft.completed == 1);
    expect(session.inventoryCount(kHerb), 4);
    expect(session.inventoryCount(kBroth), 1);

    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => craft.completed == 2);
    expect(session.inventoryCount(kHerb), 2);
    expect(session.inventoryCount(kBroth), 2);

    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => !craft.active);
    expect(craft.completed, 3);
    expect(session.inventoryCount(kHerb), 0);
    expect(session.inventoryCount(kBroth), 3);

    // Crafting costs zero steps, however long the bench takes (the
    // correction pass, finding I): the ledger did not move.
    expect(session.totalSpent, spentBefore);
    expect(session.usableEnergy, bankedBefore);

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

  test('a MINOR result is transient: it clears on its timer, and on dismiss',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 4);

    craft.start(brothOf(session), 1);
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => !craft.active);
    expect(craft.summaryRecipe, kBrothRecipe);
    expect(craft.quantity, 1);
    expect(craft.summaryHeld, isFalse, reason: 'a meal with no level is MINOR');

    // The decay is **seen-gated** (GAME_FEEL_CHARACTER_PRESENTATION_01,
    // item 1 — the owner's brief: a player who comes back to a finished
    // queue finds its summary waiting). Unseen, the timer never starts:
    fake.advance(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(craft.summaryRecipe, kBrothRecipe,
        reason: 'an unseen summary waits');

    // The Craft screen reports the sighting; the 4 s decay runs from there
    // (finding C of the correction pass, its lifetime unchanged): the card
    // returns to the clean detail on its own.
    craft.noteSummarySeen();
    fake.advance(const Duration(seconds: 4));
    await until(() => craft.summaryRecipe == null);
    expect(craft.quantity, 0);
    expect(craft.lastReport, isNull);

    // And a second one clears at once when dismissed — which the Craft
    // screen does when any row is opened.
    craft.start(brothOf(session), 1);
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => !craft.active);
    expect(craft.summaryRecipe, kBrothRecipe);
    craft.dismissSummary();
    expect(craft.summaryRecipe, isNull);
    expect(craft.quantity, 0);
  });

  test('a level gained mid-queue holds the summary (regression)', () async {
    // Broth pays +12 Cooking XP and level 2 costs 100, so repetition nine
    // of a full ×10 queue crosses the level and repetition ten does not —
    // exactly the shape whose LevelUpCard used to vanish: `_lastReport`
    // was overwritten by every later success and `summaryHeld` read only
    // the last (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1 — a truth
    // bug, not polish).
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 20);

    craft.start(brothOf(session), 10);
    for (int i = 1; i <= 10; i++) {
      fake.advance(CraftDurations.of(brothOf(session)));
      await until(() => craft.completed >= i || !craft.active);
    }
    await until(() => !craft.active);
    expect(craft.completed, 10);
    expect(
      craft.lastReport!.levelledUp,
      isFalse,
      reason: 'precondition: the level landed mid-run, not on the last rep',
    );
    expect(craft.levelledUpAny, isTrue);
    expect(craft.summaryHeld, isTrue, reason: 'a mid-queue level is not lost');
    expect(craft.levelReport?.skillLevelAfter, 2);
  });

  test('cancel keeps what completed and dispatches nothing more', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 3);
    fake.advance(CraftDurations.of(brothOf(session)));
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

  test('backgrounding is NOT a completion trigger; the resume reconciles '
      'only what legitimately elapsed', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 3);

    // Go to the background one second into the first repetition. NOTHING
    // may commit: the earlier revision dispatched the whole remainder here,
    // which made Home a Skip Queue button (`DECISIONS/0022` §6).
    fake.advance(const Duration(seconds: 1));
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(craft.completed, 0, reason: 'backgrounding completed a craft');
    expect(session.inventoryCount(kHerb), 6);
    expect(session.inventoryCount(kBroth), 0);

    // Forty-four more seconds pass in the pocket — with NO timers running, which
    // is what `elapseInBackground` models. One repetition (45 s broth pacing)
    // has now legitimately finished; the second has not.
    fake.elapseInBackground(const Duration(seconds: 44));
    expect(craft.completed, 0, reason: 'a suspended process runs nothing');

    // Resume: exactly the one finished repetition commits.
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => craft.completed == 1);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(craft.completed, 1, reason: 'only the elapsed repetition landed');
    expect(session.inventoryCount(kHerb), 4);
    expect(session.inventoryCount(kBroth), 1);
    expect(craft.active, isTrue, reason: 'the queue is still running');
  });

  test('a long background absence completes the queue and no more', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 20);

    final int startHerbs = session.inventoryCount(kHerb);
    craft.start(brothOf(session), 3);
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    // An hour away: far more elapsed time than the queue needs. The clamp is
    // the requested count — time can never produce unbounded output.
    fake.elapseInBackground(const Duration(hours: 1));
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => !craft.active);

    expect(craft.completed, 3, reason: 'exactly the requested count');
    expect(session.inventoryCount(kBroth), 3);
    expect(
      session.inventoryCount(kHerb),
      startHerbs - 6,
      reason: 'three broths consumed exactly two herbs each',
    );

    // And more time still produces nothing: the run is over.
    fake.advance(const Duration(hours: 1));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(session.inventoryCount(kBroth), 3);
  });

  test('a second reconcile with no elapsed time commits nothing', () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 8);

    craft.start(brothOf(session), 4);
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => craft.completed == 1);

    // Two resumes in a row, no time between them: the anchor already moved
    // by exactly the committed repetition, so the due count is zero and
    // nothing lands. Exactly-once is the arithmetic, not the timers.
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(craft.completed, 1);
    expect(session.inventoryCount(kBroth), 1);
    expect(session.inventoryCount(kHerb), 6);
  });

  test('a backward clock commits nothing and does not strand the queue',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 6);

    craft.start(brothOf(session), 2);
    fake.rewind(const Duration(minutes: 5));
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(craft.completed, 0, reason: 'negative elapsed commits nothing');
    expect(session.inventoryCount(kHerb), 6);

    // The clock catching back up resolves it normally.
    fake.elapseInBackground(const Duration(minutes: 5) + CraftDurations.of(brothOf(session)));
    craft.didChangeAppLifecycleState(AppLifecycleState.paused);
    craft.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => craft.completed >= 1);
    expect(session.inventoryCount(kBroth), greaterThanOrEqualTo(1));
  });

  test('cancel commits what fully elapsed and discards the partial one',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 8);

    craft.start(brothOf(session), 4);
    // One full repetition plus a fraction, with no boundary timer having
    // fired — the clock moved while nothing was scheduled.
    fake.elapseInBackground(CraftDurations.of(brothOf(session)) + const Duration(seconds: 1));

    craft.stop();
    await until(() => !craft.active);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    // `DECISIONS/0022` §7: the fully-elapsed repetition commits, the
    // partial one grants and consumes nothing.
    expect(craft.completed, 1);
    expect(session.inventoryCount(kBroth), 1);
    expect(session.inventoryCount(kHerb), 6);

    // Nothing further can land after the cancel.
    fake.advance(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(session.inventoryCount(kBroth), 1);
  });

  test('a dropped controller (force quit) grants and consumes nothing more',
      () async {
    final (
      StrideSession session,
      _,
      CraftController craft,
      FakeTiming fake,
    ) = await boot(herbs: 10);

    final int startHerbs = session.inventoryCount(kHerb);
    craft.start(brothOf(session), 5);
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => craft.completed == 1);

    // The process dies. `detached` is the last lifecycle state a dying app
    // reports; after it nothing resumes, no timer fires, and there is no
    // durable craft queue for a relaunch to reconcile — by design.
    craft.didChangeAppLifecycleState(AppLifecycleState.detached);
    fake.elapseInBackground(const Duration(hours: 2));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // The one committed repetition is on disk; nothing else moved.
    expect(session.inventoryCount(kBroth), 1);
    expect(session.inventoryCount(kHerb), startHerbs - 2);

    // And it survives a reload from disk — the commit was atomic.
    await session.reload();
    expect(session.inventoryCount(kBroth), 1);
    expect(session.inventoryCount(kHerb), startHerbs - 2);
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
    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => craft.completed == 1);

    fake.advance(CraftDurations.of(brothOf(session)));
    await until(() => !craft.active);
    expect(craft.completed, 1);
    expect(craft.stopReport, isNotNull);
    expect(craft.stopReport!.rejection, 'insufficient_ingredients');
    expect(session.inventoryCount(kHerb), 1);
    expect(session.inventoryCount(kBroth), 1);
  });
}
