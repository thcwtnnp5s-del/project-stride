// The durable activity queue over the real session (`DECISIONS/0022`,
// `MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` correction brief §38).
//
// `s01a_vertical_slice_test.dart` proves one gather spends, grants and
// persists exactly once. `packages/stride_core/test/activity_queue_test.dart`
// proves the queue's commit arithmetic at engine level. This file proves the
// controller drives that arithmetic correctly through the app: repetition
// boundaries in the foreground, reconciliation on resume and relaunch,
// stop-with-partial-discard, and every stop reason surfaced truthfully.
//
// ## The owner's ruling, and what happened to the pause tests
//
// The earlier suite asserted that backgrounding PAUSED the queue ("lifecycle
// pause banks the elapsed foreground time; background time is never
// counted"). That behaviour is now WRONG by owner ruling on hardware
// (`DECISIONS/0022`): a finite, player-initiated queue advances by elapsed
// wall-clock time across background, lock, and relaunch — every completion
// still spending banked steps through the unchanged gather semantics. Those
// tests are replaced here by progress-across-background tests asserting the
// opposite, deliberately and with this paragraph as the record.
//
// Timing is entirely fake — the injected wall clock and one-shot timers
// advance by hand, so a "five minutes in the pocket" case is exact rather
// than slept. The same fake clock feeds `StrideSession.activityWallClock`,
// so the controller's bar and the engine's commands read one clock, exactly
// as production does.

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

  /// A cold launch over [root], funded with [steps] spendable steps and
  /// reading [fake]'s wall clock: the first sync is the new game's baseline
  /// over an empty store (`DECISIONS/0019`), the second banks the page.
  Future<StrideSession> funded(int steps, FakeTiming fake) async {
    final StrideSession session = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(
        script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(steps)],
      ),
    );
    session.activityWallClock = fake.wallClock;
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

  /// Gives any in-flight no-op dispatch its turn without asserting anything.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  ResourceNodeDefinition nodeOf(StrideSession s) =>
      s.nodesHere.singleWhere((ResourceNodeDefinition n) => n.id == kNode);

  int xpOf(StrideSession s) => s.engine!.state.skills.experienceIn(kForaging);

  /// Starts a queue and waits until the start's whole dispatch has settled —
  /// the durable queue committed and the session's single flight released.
  /// The anchor is the wall clock at the command's execute, so tests advance
  /// time only from a known, settled anchor.
  Future<void> startAndCommit(
    SessionController sessions,
    ActivityController a,
    StrideSession s,
    int repetitions,
  ) async {
    a.start(nodeOf(s), repetitions);
    await until(
      () => s.activityQueue != null && !s.isBusy && !sessions.busy,
      reason: 'the start commits the durable queue',
    );
  }

  void background(ActivityController a) {
    // inactive → hidden → paused is one background, not three.
    a.didChangeAppLifecycleState(AppLifecycleState.inactive);
    a.didChangeAppLifecycleState(AppLifecycleState.hidden);
    a.didChangeAppLifecycleState(AppLifecycleState.paused);
  }

  test('queue ×1: one completion is exactly one spend, one grant, one XP '
      'award — and only after the full repetition time', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 1);
    expect(a.active, isTrue);
    expect(a.queued, 1);
    expect(a.repetitionDuration, kRep);
    expect(a.elapsedOfCurrent, Duration.zero);

    // One second short of the repetition: nothing has been committed, and
    // the bar reads exactly the wall-clock elapsed against the anchor.
    fake.advance(const Duration(seconds: 9));
    await settle();
    expect(s.totalSpent, 0);
    expect(s.inventoryCount(kHerb), 0);
    expect(a.elapsedOfCurrent, const Duration(seconds: 9));

    fake.advance(const Duration(seconds: 1));
    await until(() => a.completed == 1, reason: 'the repetition completes');

    expect(s.totalSpent, 80, reason: 'exactly one cost');
    expect(s.inventoryCount(kHerb), 1, reason: 'exactly one yield');
    expect(xpOf(s), 10, reason: 'exactly one XP award');
    expect(a.active, isFalse, reason: 'the queue of one is finished');
    expect(s.activityQueue, isNull, reason: 'and durably cleared');

    // The finished queue's summary, accumulated from the committed report.
    expect(a.summaryNode, kNode);
    expect(a.gainedItemName, 'Meadow Herb');
    expect(a.gainedQuantity, 1);
    expect(a.gainedSkillName, 'Foraging');
    expect(a.gainedXp, 10);
    expect(a.stopReason, isNull);
    expect(sessions.busy, isFalse);

    // The summary clears on its own lifetime, like every result line.
    fake.advance(const Duration(seconds: 6));
    expect(a.summaryNode, isNull);
  });

  test('queue ×10 in the foreground: ten boundary reconciles are exactly '
      'ten commits, and an eleventh never happens', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 10);
    for (int k = 1; k <= 10; k++) {
      fake.advance(kRep);
      await until(() => a.completed == k, reason: 'repetition $k completes');
      expect(s.totalSpent, 80 * k, reason: 'exactly $k costs after $k');
    }

    expect(s.totalSpent, 800);
    expect(s.inventoryCount(kHerb), 10);
    expect(xpOf(s), 100);
    expect(a.active, isFalse);
    expect(a.gainedQuantity, 10);
    expect(a.gainedXp, 100);

    // No eleventh: time passing after the queue finished commits nothing.
    fake.advance(const Duration(minutes: 5));
    await settle();
    expect(s.totalSpent, 800);
  });

  test('background under one repetition: resuming completes nothing — and '
      'the elapsed time is NOT lost, because the anchor never moved', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 3);
    fake.advance(const Duration(seconds: 4));
    background(a);

    // Five more seconds in the pocket: nine of ten elapsed, no boundary.
    fake.elapseInBackground(const Duration(seconds: 5));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(a.completed, 0);
    expect(s.totalSpent, 0);
    // The pocketed time counts — the bar resumes at nine seconds, not four.
    // This is the exact inversion of the pre-0022 pause semantics, by owner
    // ruling.
    expect(a.elapsedOfCurrent, const Duration(seconds: 9));

    // One more second and the boundary timer, re-armed on resume for the
    // remainder, completes the repetition.
    fake.advance(const Duration(seconds: 1));
    await until(() => a.completed == 1, reason: 'completes on the boundary');
    expect(s.totalSpent, 80);
  });

  test('background across one boundary: resuming commits exactly one, '
      'surfaced as the while-away summary — and no health sync ran', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );
    final int syncsBefore = s.syncCount;

    await startAndCommit(sessions, a, s, 3);
    background(a);
    fake.elapseInBackground(const Duration(seconds: 12));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => a.completed == 1, reason: 'the away repetition commits');

    expect(s.totalSpent, 80);
    expect(s.inventoryCount(kHerb), 1);
    expect(a.active, isTrue);
    final AwaySummary away = a.awaySummary!;
    expect(away.quantity, 1);
    expect(away.experience, 10);
    expect(away.itemName, 'Meadow Herb');
    expect(away.finishedQueue, isFalse);

    // The reconcile path must never touch health sync (`DECISIONS/0022` §2):
    // no background delivery, no sync — the cursor and count are untouched.
    expect(s.syncCount, syncsBefore);
  });

  test('background across N boundaries: resuming commits exactly N', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 5);
    background(a);
    // Three and a half repetitions in the pocket.
    fake.elapseInBackground(const Duration(seconds: 35));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => a.completed == 3, reason: 'three away repetitions');

    expect(s.totalSpent, 240);
    expect(s.inventoryCount(kHerb), 3);
    expect(xpOf(s), 30);
    expect(a.active, isTrue);
    expect(a.awaySummary!.quantity, 3);
    // And the durable anchor sits mid-repetition, five seconds in.
    expect(a.elapsedOfCurrent, const Duration(seconds: 5));
  });

  test('background beyond the whole queue: capped at the requested count, '
      'finished, compact completion summary, normal controls', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 3);
    background(a);
    fake.elapseInBackground(const Duration(hours: 2));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => !a.active, reason: 'the whole queue finished away');

    expect(a.completed, 3, reason: 'capped at requested — finite by design');
    expect(s.totalSpent, 240);
    expect(s.inventoryCount(kHerb), 3);
    expect(s.activityQueue, isNull);
    expect(a.summaryNode, kNode, reason: 'normal controls with a summary');
    expect(a.stopReason, isNull);
    final AwaySummary away = a.awaySummary!;
    expect(away.quantity, 3);
    expect(away.finishedQueue, isTrue);
  });

  test('resuming twice commits nothing twice', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 5);
    background(a);
    fake.elapseInBackground(const Duration(seconds: 12));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => a.completed == 1, reason: 'the away repetition commits');
    expect(s.totalSpent, 80);

    // A second background/resume cycle with no elapsed time: the reconcile
    // finds nothing left — exactly-once is the commit, not the trigger.
    background(a);
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(a.completed, 1);
    expect(s.totalSpent, 80);

    // And an explicit extra reconcile is equally harmless.
    a.reconcileNow();
    await settle();
    expect(s.totalSpent, 80);
  });

  test('kill and relaunch: a save carrying an active queue reconciles on '
      'construction — correct completions, cumulative display reconstructed, '
      'no duplicates', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    // Built by hand rather than through `controllers()`: this test disposes
    // the first pair itself � that IS the scenario � and a teardown disposing
    // them again would throw.
    final SessionController sessions = SessionController(s);
    final ActivityController a = ActivityController(
      sessions,
      timing: fake.timing,
    );
    sessions.onExclusiveCommand = a.cancelForExclusiveCommand;

    await startAndCommit(sessions, a, s, 5);
    fake.advance(kRep);
    await until(() => a.completed == 1, reason: 'one watched completion');
    expect(s.totalSpent, 80);

    // The process dies mid-second-repetition. Nothing is flushed, nothing is
    // stopped: the queue is already durable.
    a.dispose();
    sessions.dispose();

    // Relaunch 25 seconds of wall-clock later: two more repetitions elapsed
    // (at 20 s and 30 s from the anchor... the second and third boundaries),
    // and the fourth is half way.
    final FakeTiming relaunchClock = FakeTiming()
      ..elapseInBackground(
        Duration(milliseconds: fake.nowEpochMillis - FakeTiming.epochStart),
      )
      ..elapseInBackground(const Duration(seconds: 25));
    final StrideSession relaunched = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(script: const <SyncFetch>[]),
    );
    relaunched.activityWallClock = relaunchClock.wallClock;
    expect(relaunched.activityQueue, isNotNull, reason: 'the queue survived');
    expect(relaunched.activityQueue!.completed, 1);

    final SessionController sessions2 = SessionController(relaunched);
    final ActivityController a2 = ActivityController(
      sessions2,
      timing: relaunchClock.timing,
    );
    addTearDown(() {
      a2.dispose();
      sessions2.dispose();
    });

    // The card is restored before any dispatch: the cumulative display is
    // reconstructed deterministically from completed × the profile-scaled
    // yield/xp — the same figures the committed events carried.
    expect(a2.active, isTrue);
    expect(a2.queued, 5);
    expect(a2.completed, 1);
    expect(a2.gainedQuantity, 1);
    expect(a2.gainedXp, 10);

    // Construction scheduled the reconcile; the fake clock delivers it.
    relaunchClock.advance(Duration.zero);
    await until(() => a2.completed == 3, reason: 'two away repetitions');

    expect(relaunched.totalSpent, 240, reason: 'no duplicates across death');
    expect(relaunched.inventoryCount(kHerb), 3);
    expect(a2.awaySummary!.quantity, 2, reason: 'the two committed while away');
    expect(a2.active, isTrue);
    expect(a2.gainedQuantity, 3);

    // A second reconcile finds nothing.
    a2.reconcileNow();
    await settle();
    expect(relaunched.totalSpent, 240);
  });

  test('stop at 27 s of a 10 s × 5 queue: exactly 2 committed, the partial '
      'discarded, the queue cleared — and a relaunch agrees', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 5);
    // Locked for 27 seconds — no foreground boundary ever fired, so the
    // stop's own closing reconciliation does the committing.
    background(a);
    fake.elapseInBackground(const Duration(seconds: 27));
    a.stop();
    await until(
      () => s.activityQueue == null && !a.active,
      reason: 'the stop commits and the panel settles',
    );

    expect(a.active, isFalse);
    expect(a.completed, 2);
    expect(s.totalSpent, 160);
    expect(s.inventoryCount(kHerb), 2);
    expect(xpOf(s), 20);
    expect(a.stopReason, isNull, reason: 'a player stop is not a refusal');

    // Relaunch: exactly two are durable, the partial third does not exist.
    final StrideSession relaunched = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(script: const <SyncFetch>[]),
    );
    expect(relaunched.totalSpent, 160);
    expect(relaunched.inventoryCount(kHerb), 2);
    expect(relaunched.activityQueue, isNull);
    expect(relaunched.usableEnergy, 1000 - 160);
  });

  test(
    'stop before the first completion spends nothing and grants nothing',
    () async {
      final FakeTiming fake = FakeTiming();
      final StrideSession s = await funded(1000, fake);
      final (SessionController sessions, ActivityController a) = controllers(
        s,
        fake,
      );

      await startAndCommit(sessions, a, s, 3);
      fake.advance(const Duration(seconds: 5));
      a.stop();
      await until(
        () => s.activityQueue == null && !a.active,
        reason: 'the stop commits and the panel settles',
      );

      expect(a.active, isFalse);
      expect(a.summaryNode, isNull, reason: 'nothing happened to summarise');
      expect(s.totalSpent, 0);
      expect(s.inventoryCount(kHerb), 0);
      expect(xpOf(s), 0);

      // Dead queue: more time changes nothing.
      fake.advance(const Duration(minutes: 1));
      await settle();
      expect(s.totalSpent, 0);
    },
  );

  test('a backward clock produces no phantom progress and never moves the '
      'anchor', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 3);
    final int anchor = s.activityQueue!.anchorEpochMillis;

    fake.rewind(const Duration(hours: 1));
    a.reconcileNow();
    await settle();

    expect(a.completed, 0);
    expect(s.totalSpent, 0);
    expect(
      s.activityQueue!.anchorEpochMillis,
      anchor,
      reason: 'never move the anchor on a backward clock — that eats progress',
    );
    expect(a.elapsedOfCurrent, Duration.zero, reason: 'clamped, not negative');

    // The clock recovering resumes exactly where the queue left off: the
    // original boundary timer is still armed for anchor + 10 s.
    fake.advance(const Duration(hours: 1));
    await settle();
    expect(a.completed, 0, reason: 'back to the anchor instant, no boundary');
    fake.advance(kRep);
    await until(() => a.completed == 1, reason: 'the honest first completion');
    expect(s.totalSpent, 80);
  });

  test('insufficient banked steps mid-queue stops it at the right count, '
      'with the truthful reason and no negative balance', () async {
    final FakeTiming fake = FakeTiming();
    // Funds two gathers (160) with 40 left over — the third completion is
    // the engine's refusal, not a UI prediction.
    final StrideSession s = await funded(200, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 5);
    background(a);
    fake.elapseInBackground(const Duration(seconds: 60));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => !a.active, reason: 'the refused third stops the queue');

    expect(a.completed, 2, reason: 'the refused repetition is not counted');
    expect(a.stopReason, 'insufficient_steps');
    expect(s.usableEnergy, 40, reason: 'no negative, no third spend');
    expect(s.inventoryCount(kHerb), 2);
    expect(xpOf(s), 20);
    expect(s.activityQueue, isNull, reason: 'stopped queues do not linger');
  });

  test('prerequisites invalid at reconcile: the queue stops before the '
      'invalid completion and keeps every prior one', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(5000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 5);
    fake.advance(kRep);
    await until(() => a.completed == 1, reason: 'one honest completion');

    // The state changes under the queue: the player travels away, through
    // the session directly — deliberately bypassing the controller's
    // exclusive seam, which is exactly the kind of path (or crash timing)
    // the reconcile-time validation exists to survive.
    background(a);
    final TravelReport travel = await s.travel(kWoods);
    expect(travel.succeeded, isTrue, reason: '${travel.rejection}');
    fake.elapseInBackground(const Duration(seconds: 30));
    a.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await until(() => !a.active, reason: 'the impossible completion refuses');

    expect(a.completed, 1, reason: 'the prior completion is kept');
    expect(a.stopReason, 'resource_node_not_here');
    expect(s.totalSpent, 80 + travel.cost, reason: 'nothing else was charged');
    expect(s.inventoryCount(kHerb), 1);
    expect(s.activityQueue, isNull);
  });

  test('travel through the controller cancels the queue via the exclusive '
      'seam: the partial repetition is discarded safely', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(5000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 3);
    fake.advance(const Duration(seconds: 5));

    await sessions.travel(kWoods);
    final TravelReport travel = sessions.lastTravel!;
    expect(
      travel.succeeded,
      isTrue,
      reason: '${travel.rejection}: ${travel.detail}',
    );
    expect(a.active, isFalse, reason: 'the exclusive command cancelled it');

    // The deferred StopActivityQueue lands on a timer tick after the journey
    // � ordering the two commits rather than racing them. Under load it may
    // take a busy-retry hop or two; drive the retry cadence until it lands.
    for (int i = 0; i < 20 && s.activityQueue != null; i++) {
      fake.advance(const Duration(milliseconds: 250));
      await settle();
    }
    await until(
      () => s.activityQueue == null && !a.active,
      reason: 'the stop commits and the panel settles',
    );

    expect(
      s.inventoryCount(kHerb),
      0,
      reason: 'the abandoned repetition granted nothing',
    );
    expect(s.totalSpent, travel.cost, reason: 'only the journey was charged');

    // Dead queue: no gather can land at a place the player has left.
    fake.advance(const Duration(minutes: 1));
    await settle();
    expect(s.totalSpent, travel.cost);
    expect(s.inventoryCount(kHerb), 0);
  });

  test('a busy session defers the boundary reconcile to a retry — one '
      'repetition still commits exactly once', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    await startAndCommit(sessions, a, s, 1);

    // A manual command holds the session's single-flight at the exact moment
    // the boundary fires. `gather` marks the session busy synchronously, and
    // nothing awaits between here and the advance, so the collision is
    // deterministic.
    final Future<ActionReport> manual = s.gather(kNode);
    expect(s.isBusy, isTrue);
    fake.advance(kRep);

    // The boundary found the session busy: nothing committed yet.
    expect(a.completed, 0);

    final ActionReport manualReport = await manual;
    expect(manualReport.succeeded, isTrue);
    expect(s.totalSpent, 80, reason: 'only the manual gather so far');

    // The retry timer fires and the deferred reconcile commits — once.
    fake.advance(const Duration(milliseconds: 250));
    await until(() => a.completed == 1, reason: 'the deferred reconcile lands');
    expect(s.totalSpent, 160, reason: 'manual + exactly one queue commit');
    expect(s.inventoryCount(kHerb), 2);
    expect(xpOf(s), 20);
    expect(a.active, isFalse);
  });

  test('a double start is one queue', () async {
    final FakeTiming fake = FakeTiming();
    final StrideSession s = await funded(1000, fake);
    final (SessionController sessions, ActivityController a) = controllers(
      s,
      fake,
    );

    // Two calls with no await between them: the second must be ignored by
    // the synchronous guard, and the engine would refuse it anyway
    // (`activity_queue_active` — defence in depth).
    a.start(nodeOf(s), 2);
    a.start(nodeOf(s), 10);
    await until(() => s.activityQueue != null, reason: 'one start commits');

    expect(s.activityQueue!.requested, 2, reason: 'the first tap won');
    fake.advance(const Duration(minutes: 1));
    await until(() => !a.active, reason: 'the queue of two finishes');
    expect(s.totalSpent, 160, reason: 'two commits, never twelve');
  });
}
