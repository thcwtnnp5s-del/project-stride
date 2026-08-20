// The timed gathering queue over the real session
// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4a, §7).
//
// `s01a_vertical_slice_test.dart` proves one gather spends, grants and
// persists exactly once. This file proves the queue on top of it dispatches
// that command exactly N times for N completed repetitions — and never for an
// abandoned one: stop, refusal, lifecycle pause and exclusive commands all
// leave the ledger holding only what completed.
//
// Timing is entirely fake — the injected clock and one-shot timers advance by
// hand, so a ten-second repetition costs no test time and a "300 s in the
// background" case is exact rather than slept.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/activity_controller.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final ContentId kHerb = ContentId.unchecked('item.meadow_herb');
final ContentId kForaging = ContentId.unchecked('skill.foraging');
final ContentId kWoods = ContentId.unchecked('location.whispering_woods');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

/// Meadow Patch is Foraging, so one repetition presents for 10 s.
const Duration kRep = Duration(seconds: 10);

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
  setUp(() => root = Directory.systemTemp.createTempSync('stride_activity'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A cold launch over [root], funded with [steps] spendable steps: the
  /// first sync is the new game's baseline over an empty store
  /// (`DECISIONS/0019`), the second banks the page.
  Future<StrideSession> funded(int steps) async {
    final StrideSession session = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(steps)],
      ),
    );
    await session.syncSteps();
    await session.syncSteps();
    expect(session.usableEnergy, steps);
    return session;
  }

  /// The controller pair under test, torn down so no real result timer
  /// outlives the case.
  (SessionController, ActivityController) controllers(
    StrideSession session,
    FakeTiming fake,
  ) {
    final SessionController sessions = SessionController(session);
    final ActivityController activity = ActivityController(
      sessions,
      timing: fake.timing,
    );
    sessions.onExclusiveCommand = activity.cancelForExclusiveCommand;
    addTearDown(() {
      activity.dispose();
      sessions.dispose();
    });
    return (sessions, activity);
  }

  /// Waits (in real milliseconds) for the dispatch's file I/O to land.
  Future<void> until(
    bool Function() condition, {
    required String reason,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: reason);
  }

  ResourceNodeDefinition nodeOf(StrideSession s) =>
      s.nodesHere.singleWhere((ResourceNodeDefinition n) => n.id == kNode);

  int xpOf(StrideSession s) => s.engine!.state.skills.experienceIn(kForaging);

  test('queue ×1: one completion is exactly one spend, one grant, one XP '
      'award — and only after the full presentation time', () async {
    final StrideSession s = await funded(1000);
    final FakeTiming fake = FakeTiming();
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    a.start(nodeOf(s), 1);
    expect(a.active, isTrue);
    expect(a.queued, 1);
    expect(a.repetitionDuration, kRep);
    expect(a.elapsedOfCurrent, Duration.zero);

    // One second short of the repetition: nothing has been dispatched. The
    // command not existing yet is the cancel-safety property.
    fake.advance(const Duration(seconds: 9));
    expect(s.totalSpent, 0);
    expect(s.inventoryCount(kHerb), 0);
    expect(a.elapsedOfCurrent, const Duration(seconds: 9));

    fake.advance(const Duration(seconds: 1));
    await until(() => a.completed == 1, reason: 'the repetition completes');

    expect(s.totalSpent, 90, reason: 'exactly one cost');
    expect(s.inventoryCount(kHerb), 2, reason: 'exactly one yield');
    expect(xpOf(s), 10, reason: 'exactly one XP award');
    expect(a.active, isFalse, reason: 'the queue of one is finished');

    // The finished queue's summary, accumulated from the returned report.
    expect(a.summaryNode, kNode);
    expect(a.gainedItemName, 'Meadow Herb');
    expect(a.gainedQuantity, 2);
    expect(a.gainedSkillName, 'Foraging');
    expect(a.gainedXp, 10);
    expect(a.stopReason, isNull);
    expect(sessions.busy, isFalse);

    // The summary clears on its own lifetime, like every result line.
    fake.advance(const Duration(seconds: 6));
    expect(a.summaryNode, isNull);
  });

  test('queue ×10: ten completions are exactly ten commits', () async {
    final StrideSession s = await funded(1000);
    final FakeTiming fake = FakeTiming();
    final (_, ActivityController a) = controllers(s, fake);

    a.start(nodeOf(s), 10);
    for (int k = 1; k <= 10; k++) {
      fake.advance(kRep);
      await until(() => a.completed == k, reason: 'repetition $k completes');
      expect(s.totalSpent, 90 * k, reason: 'exactly $k costs after $k');
    }

    expect(s.totalSpent, 900);
    expect(s.inventoryCount(kHerb), 20);
    expect(xpOf(s), 100);
    expect(a.active, isFalse);
    expect(a.gainedQuantity, 20);
    expect(a.gainedXp, 100);

    // No eleventh: time passing after the queue finished dispatches nothing.
    fake.advance(const Duration(minutes: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(s.totalSpent, 900);
  });

  test('insufficient banked steps mid-queue stops it with the truthful '
      'reason and no negative balance', () async {
    // Funds two gathers (180) with 70 left over — the third dispatch is the
    // engine's refusal, not a UI prediction.
    final StrideSession s = await funded(250);
    final FakeTiming fake = FakeTiming();
    final (_, ActivityController a) = controllers(s, fake);

    a.start(nodeOf(s), 5);
    fake.advance(kRep);
    await until(() => a.completed == 1, reason: 'first completes');
    fake.advance(kRep);
    await until(() => a.completed == 2, reason: 'second completes');
    fake.advance(kRep);
    await until(() => !a.active, reason: 'the refused third stops the queue');

    expect(a.completed, 2, reason: 'the refused repetition is not counted');
    expect(a.stopReason, 'insufficient_steps');
    expect(s.usableEnergy, 70, reason: 'no negative, no third spend');
    expect(s.inventoryCount(kHerb), 4);
    expect(xpOf(s), 20);
  });

  test(
    'stop before the first completion spends nothing and grants nothing',
    () async {
      final StrideSession s = await funded(1000);
      final FakeTiming fake = FakeTiming();
      final (_, ActivityController a) = controllers(s, fake);

      a.start(nodeOf(s), 3);
      fake.advance(const Duration(seconds: 5));
      a.stop();

      expect(a.active, isFalse);
      expect(a.summaryNode, isNull, reason: 'nothing happened to summarise');
      expect(s.totalSpent, 0);
      expect(s.inventoryCount(kHerb), 0);
      expect(xpOf(s), 0);

      // The cancelled repetition's timer is dead: more time changes nothing.
      fake.advance(const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(s.totalSpent, 0);
    },
  );

  test('stop after k completions keeps exactly k, and a relaunch finds '
      'exactly k durable', () async {
    final StrideSession s = await funded(1000);
    final FakeTiming fake = FakeTiming();
    final (_, ActivityController a) = controllers(s, fake);

    a.start(nodeOf(s), 5);
    fake.advance(kRep);
    await until(() => a.completed == 1, reason: 'first completes');
    fake.advance(kRep);
    await until(() => a.completed == 2, reason: 'second completes');
    fake.advance(const Duration(seconds: 3)); // mid third repetition
    a.stop();

    expect(a.active, isFalse);
    expect(a.completed, 2);
    expect(s.totalSpent, 180);
    expect(s.inventoryCount(kHerb), 4);
    expect(xpOf(s), 20);

    // Relaunch: no queue exists (nothing was persisted) and nothing is lost —
    // the two completed repetitions are on disk, the abandoned third is not.
    final StrideSession relaunched = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(script: const <SyncFetch>[]),
    );
    expect(relaunched.totalSpent, 180);
    expect(relaunched.inventoryCount(kHerb), 4);
    expect(relaunched.usableEnergy, 1000 - 180);
  });

  test('lifecycle pause banks the elapsed foreground time; background time '
      'is never counted; resume finishes only the remainder', () async {
    final StrideSession s = await funded(1000);
    final FakeTiming fake = FakeTiming();
    final (_, ActivityController a) = controllers(s, fake);

    a.start(nodeOf(s), 1);
    fake.advance(const Duration(seconds: 4));
    expect(a.elapsedOfCurrent, const Duration(seconds: 4));

    // inactive → hidden → paused is one background, not three.
    a.didChangeAppLifecycleState(AppLifecycleState.inactive);
    a.didChangeAppLifecycleState(AppLifecycleState.hidden);
    a.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(a.paused, isTrue);

    // Five minutes in the pocket: the presentation clock does not move and
    // nothing completes.
    fake.advance(const Duration(minutes: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(a.completed, 0);
    expect(s.totalSpent, 0);
    expect(
      a.elapsedOfCurrent,
      const Duration(seconds: 4),
      reason: 'background time is never counted',
    );

    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(a.paused, isFalse);

    // Five of the six remaining seconds: still not done.
    fake.advance(const Duration(seconds: 5));
    expect(a.completed, 0);
    expect(s.totalSpent, 0);

    fake.advance(const Duration(seconds: 1));
    await until(
      () => a.completed == 1,
      reason: 'completes after exactly the foreground remainder',
    );
    expect(s.totalSpent, 90);
    expect(s.inventoryCount(kHerb), 2);
  });

  test(
    'travel during a queue cancels the in-progress repetition safely',
    () async {
      final StrideSession s = await funded(5000);
      final FakeTiming fake = FakeTiming();
      final (SessionController sessions, ActivityController a) = controllers(
        s,
        fake,
      );

      a.start(nodeOf(s), 3);
      fake.advance(const Duration(seconds: 5));

      await sessions.travel(kWoods);
      final TravelReport travel = sessions.lastTravel!;
      expect(
        travel.succeeded,
        isTrue,
        reason: '${travel.rejection}: ${travel.detail}',
      );

      expect(a.active, isFalse, reason: 'the exclusive command cancelled it');
      expect(
        s.inventoryCount(kHerb),
        0,
        reason: 'the abandoned repetition granted nothing',
      );
      expect(s.totalSpent, travel.cost, reason: 'only the journey was charged');

      // The cancelled repetition's timer must be dead — no gather can land at
      // a place the player has left.
      fake.advance(const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(s.totalSpent, travel.cost);
      expect(s.inventoryCount(kHerb), 0);
    },
  );

  test('a busy session defers the dispatch to a retry — one repetition still '
      'commits exactly once', () async {
    final StrideSession s = await funded(1000);
    final FakeTiming fake = FakeTiming();
    final (_, ActivityController a) = controllers(s, fake);

    a.start(nodeOf(s), 1);

    // A manual command holds the session's single-flight at the exact moment
    // the repetition completes. `gather` marks the session busy synchronously,
    // and nothing awaits between here and the advance, so the collision is
    // deterministic.
    final Future<ActionReport> manual = s.gather(kNode);
    expect(s.isBusy, isTrue);
    fake.advance(kRep);

    // The completion found the session busy: nothing dispatched yet.
    expect(a.completed, 0);

    final ActionReport manualReport = await manual;
    expect(manualReport.succeeded, isTrue);
    expect(s.totalSpent, 90, reason: 'only the manual gather so far');

    // The retry timer fires and the deferred repetition commits — once.
    fake.advance(const Duration(milliseconds: 250));
    await until(() => a.completed == 1, reason: 'the deferred dispatch lands');
    expect(s.totalSpent, 180, reason: 'manual + exactly one queue commit');
    expect(s.inventoryCount(kHerb), 4);
    expect(xpOf(s), 20);
    expect(a.active, isFalse);
  });
}
