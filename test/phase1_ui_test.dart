/// Playable Demo Phase 1 — the product UI's integration with `StrideSession`.
///
/// ## What this file deliberately does NOT test
///
/// Nine of the fifteen cases the Phase 1 brief lists as "required" are already
/// proven, most of them more thoroughly than a widget test could manage:
/// `test/s01a_vertical_slice_test.dart` covers the literal 90 / 2 / 10 figures
/// across a relaunch, duplicate sync granting nothing, insufficient-energy
/// refusal, and exact-cost spend; `integration_test/restart_test.dart` and the
/// process-death harness cover persistence on a device.
///
/// Re-asserting those through a widget is the pattern `MISTAKES.md` M-01
/// records, wearing a new name. `RULES.md` G-1 requires a **concrete uncovered
/// risk, named before the work starts** — so this file covers the new surface
/// only, and each test below says which defect it catches.
///
/// ## Two design rules for the tests themselves
///
/// **A single-value render assertion is satisfiable by a hardcoded literal**,
/// which is the defect class half of these exist to catch. So every
/// "comes from state" test runs against **two different known states**.
///
/// **A test that cannot fail is worse than no test.** The first-frame test must
/// not call `pumpAndSettle` before asserting, and the refresh test must assert
/// against rendered text rather than against the session.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/components/screen_header.dart';
import 'package:stride/ui/components/sprite_animation.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';
import 'package:stride/ui/screens/skills/skills_screen.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_viewport.dart';
import 'package:stride/ui/screens/world/world_screen.dart';
import 'package:stride/ui/state/activity_controller.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final ContentId kHerb = ContentId.unchecked('item.meadow_herb');
final ContentId kForaging = ContentId.unchecked('skill.foraging');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');

const int hour = 60 * 60 * 1000;

/// A fixed instant. The engine reads no clock and neither does this suite.
const int t0 = 1750000000000;

/// A drained, complete one-page delivery of [steps] in bucket [index].
///
/// `CompleteThrough` on a final page is what authorizes a cursor.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('stride_phase1'));

  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close. The directory is under
      // systemTemp and the OS reclaims it.
    }
  });

  /// A cold launch over [root]. Passing a non-null `source` short-circuits
  /// `PlatformStepSource.open`, so no platform channel is touched. The real
  /// filesystem is used and must be: `Scripts/check-single-writer.sh` approves
  /// exactly six construction sites, and an in-memory store would need a
  /// seventh.
  Future<StrideSession> launch({StepSyncSource? source}) => StrideSession.start(
    overrideRoot: root,
    source: source ?? MockStepSource(script: const <SyncFetch>[]),
  );

  /// Boots inside `runAsync`. Mandatory, and its absence is a hang rather than a
  /// slow test: `testWidgets` runs under `FakeAsync`, where a future backed by
  /// real file I/O never completes.
  Future<StrideSession> boot(
    WidgetTester tester, {
    StepSyncSource? source,
    Size size = const Size(393 * 3, 852 * 3),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Unmount the tree before the test framework checks for pending work.
    //
    // A gather arms `SessionController`'s five-second result timer. If the test
    // body ends while that timer is live, it can fire against a controller the
    // framework has already finished with, and the failure surfaces as "failed
    // after test completion" — attributed to whichever test happened to be
    // slowest rather than to the one that armed it.
    //
    // Pumping an empty tree runs `dispose`, which cancels the timer. This is
    // test hygiene, not a workaround: the production path disposes the same way
    // when the app is torn down.
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    return (await tester.runAsync(() => launch(source: source)))!;
  }

  /// A health store that had nothing at install and serves [pages] afterwards.
  ///
  /// A brand-new game's first authorised sync is its baseline and retires
  /// whatever it read (DECISIONS/0019), so the leading empty answer is what a
  /// fresh session syncs to leave the origin, and every page after it is
  /// spendable — which is what the tests below fund themselves with.
  MockStepSource funded(List<SyncFetch> pages) => MockStepSource(
    script: <SyncFetch>[SyncFetch(const NoChangeSync()), ...pages],
  );

  /// Baselines a fresh [session] with one explicit sync over an empty store.
  Future<void> baseline(StrideSession session) async {
    await session.syncSteps();
    expect(session.baselinePending, isFalse);
    expect(session.usableEnergy, 0);
  }

  /// [boot], over a store that serves [pages] once the baseline is set. The
  /// funding sync is the caller's — a tap on `Sync steps` or an explicit call.
  Future<StrideSession> bootFunded(
    WidgetTester tester,
    List<SyncFetch> pages, {
    Size size = const Size(393 * 3, 852 * 3),
  }) async {
    final StrideSession session = await boot(
      tester,
      source: funded(pages),
      size: size,
    );
    await tester.runAsync(() => baseline(session));
    return session;
  }

  /// Opens the Skills tab and pushes Foraging's roadmap — where the per-skill
  /// XP figures live since FMPO02 (`ART-12` §3, §4).
  ///
  /// Both taps are scoped, because the shell keeps every tab mounted in an
  /// `IndexedStack`: `Skills` is a word on the tab bar and on the Character
  /// sheet, and `Foraging` is a word on both spine lists.
  Future<void> openForagingRoadmap(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(StrideTabBar),
        matching: find.text('Skills'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SkillsScreen, skipOffstage: false),
        matching: find.text('Foraging'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps, waits for the session to reach a condition, then settles.
  Future<void> tapAndAwait(
    WidgetTester tester,
    Finder finder, {
    required bool Function() until,
  }) async {
    // Scroll the control into view first. The Adventure screen is taller than a
    // phone once the location vignette and the activity stage are on it, so the
    // gather button sits below the fold at every supported width — and
    // `tester.tap` on an off-screen widget hits nothing and reports no error of
    // its own. Without this the failure surfaces as "the tapped action did not
    // complete", which points at the session rather than at the tap.
    //
    // This weakens nothing: the assertion afterwards is unchanged, and a player
    // reaching the button scrolls to it in exactly the same way.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(finder);
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!until() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(until(), isTrue, reason: 'the tapped action did not complete');

    // Then wait for the *controller* to leave its busy state, not only the
    // session.
    //
    // These are two different clocks. `until` observes `StrideSession`, which
    // the handler updates before `SessionController` clears `busy` and
    // notifies — so there is a window where the figures are final and the
    // command is still in flight. A test that returns inside that window ends
    // with real work outstanding, and the runner reports it against whichever
    // test happened to be running when the continuation landed: *"This test
    // failed after it had already completed."*
    //
    // ## Why this reads the controller instead of matching labels
    //
    // It used to look for the strings `Checking…` and `Gathering…`. That is a
    // hand-maintained list of every in-progress label in the product, and it
    // went out of date the moment Phase 2 added `Travelling…` and `Crafting…`
    // — so for travel and craft the loop saw no busy label, exited
    // immediately, and the 100 ms grace above was the only thing standing
    // between the test and its own pending commit. It held on a fast Windows
    // run and did not hold on a CI runner.
    //
    // `SessionScope` is an `InheritedNotifier<SessionController>`, so the
    // controller is reachable from the widget itself with no context. Reading
    // `busy` observes the actual condition, covers every command the product
    // has and every one it gains, and cannot fall out of date.
    //
    // The fixed 100 ms grace is gone with it. The loop below waits on a
    // property; it does not wait for a duration and hope.
    SessionController? controllerInTree() {
      final Iterable<Element> scopes = find.byType(SessionScope).evaluate();
      if (scopes.isEmpty) return null;
      return (scopes.first.widget as SessionScope).notifier;
    }

    bool busy() => controllerInTree()?.busy ?? false;

    // Bounded only so a genuine hang fails instead of running forever. The
    // loop's exit condition is the property, not the bound.
    for (int i = 0; i < 250 && busy(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    expect(busy(), isFalse, reason: 'the control never returned to idle');
  }

  /// Taps the gather control, advances [fake] through one repetition, and
  /// waits for the queue to finish its dispatch.
  ///
  /// One tap is one *queued* repetition (`DECISIONS/0022`): the start commits
  /// a durable queue, and the spend/grant commits when the wall clock crosses
  /// the repetition boundary — advanced by hand here, so no real wait. The
  /// app under test must have been pumped with `activityTiming: fake.timing`
  /// AND its session's `activityWallClock` pointed at the same fake, or the
  /// anchor and the fake boundary arithmetic would read two different clocks.
  Future<void> gatherOnce(
    WidgetTester tester,
    FakeTiming fake, {
    required bool Function() until,
  }) async {
    // Since the Adventure restructure (PRESENTATION_WORLD_REWARD_FEEL_01 §6)
    // the gather control lives in the selected activity's expanded detail;
    // select the row first when nothing is expanded yet.
    if (find.textContaining('Gather ×').evaluate().isEmpty) {
      final Finder row = find.text('Meadow Patch');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
    final Finder button = find.textContaining('Gather ×');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    ActivityController activityInTree() =>
        (find.byType(ActivityScope).evaluate().first.widget as ActivityScope)
            .notifier!;
    SessionController? sessionsInTree() {
      final Iterable<Element> scopes = find.byType(SessionScope).evaluate();
      if (scopes.isEmpty) return null;
      return (scopes.first.widget as SessionScope).notifier;
    }

    // Phase 1: the tap's StartActivityQueue dispatch settles. The tap ran in
    // the harness's fake-async zone, so its await continuations flush on
    // pumps between real-I/O waits — a bare runAsync loop would watch
    // forever. Exits on the durable queue, or on the attempt finishing any
    // other way (a refusal must fall through to the caller's assertion).
    bool settled() {
      final SessionController? c = sessionsInTree();
      if (c == null) return false;
      if (c.busy || c.session.isBusy) return false;
      return c.session.activityQueue != null || !activityInTree().active;
    }

    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!settled() && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    // Phase 2: one repetition boundary — Meadow Patch costs 80 steps, so
    // 48 s at 100 steps a minute. The boundary timer fires inside runAsync
    // (real zone), so the reconcile's file I/O completes in place.
    await tester.runAsync(() async {
      fake.advance(const Duration(seconds: 48));
      final DateTime d2 = DateTime.now().add(const Duration(seconds: 10));
      // Wait on the queue itself, not only the session: the figures move
      // inside the command, a beat before the controller counts the
      // completion and finishes the ×1 queue.
      while ((!until() || activityInTree().active) &&
          DateTime.now().isBefore(d2)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(until(), isTrue, reason: 'the queued gather did not complete');
    expect(
      activityInTree().active,
      isFalse,
      reason: 'the ×1 queue should have finished',
    );
    // Bounded pumps, not a settle: the finish lands on the universal
    // activity result card (GFCP01 device correction), and a settle here
    // would run its readable decay out before the caller can look at it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // =========================================================================
  // Startup
  // =========================================================================

  group('startup', () {
    testWidgets('the first frame already shows the loaded save, not zeros', (
      WidgetTester tester,
    ) async {
      // Bank some steps and make them durable, then relaunch cold.
      final StrideSession first = await bootFunded(tester, <SyncFetch>[
        page(1041),
      ]);
      await tester.runAsync(() => first.syncSteps());
      expect(first.usableEnergy, 1041);

      final StrideSession reopened = (await tester.runAsync(() => launch()))!;
      expect(reopened.usableEnergy, 1041);

      await tester.pumpWidget(StrideApp(session: reopened, syncOnStart: false));

      // NO pumpAndSettle before this assertion. With it, the test cannot fail
      // for the defect it exists to catch: a UI that loads after the first
      // frame would settle to the right number and pass anyway.
      expect(
        find.text('1,041'),
        findsWidgets,
        reason: 'the first frame must show the save, not a zero that jumps',
      );

      // Specifically the banked readout in the header. A blanket
      // `find.text('0')` would be wrong here: `SPENT` is legitimately zero on
      // a save that has never gathered, and asserting no zero anywhere would
      // fail on a correct screen.
      final Finder banked = find.descendant(
        of: find.byType(BankedStepsReadout),
        matching: find.text('0'),
      );
      expect(
        banked,
        findsNothing,
        reason: 'the banked figure must never render as a zero that jumps',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('a blocked bootstrap renders the refusal, not the shell', (
      WidgetTester tester,
    ) async {
      // A save directory containing an unreadable slot pair blocks the
      // bootstrap. Writing garbage where the save belongs is the cheapest way
      // to reach it through the public API.
      final StrideSession good = await boot(tester);
      expect(good.blocked, isNull);

      await tester.runAsync(() async {
        for (final FileSystemEntity e in root.listSync(recursive: true)) {
          if (e is File && e.path.endsWith('.bin')) {
            e.writeAsBytesSync(<int>[0, 0, 0, 0]);
          }
        }
      });

      final StrideSession broken = (await tester.runAsync(() => launch()))!;
      if (broken.blocked == null) {
        // The save layout did not produce a refusal this way. Skip rather than
        // assert a state we did not actually reach — a test that silently tests
        // the happy path is worse than an absent one.
        return;
      }

      await tester.pumpWidget(StrideApp(session: broken, syncOnStart: false));
      await tester.pumpAndSettle();

      expect(find.text('Stride could not start'), findsOneWidget);
      expect(find.text('Adventure'), findsNothing);
    });
  });

  // =========================================================================
  // Values come from state, not from literals
  // =========================================================================

  group('rendered values originate in the session', () {
    testWidgets('the banked figure tracks two different states', (
      WidgetTester tester,
    ) async {
      // Two non-summing figures, so no single constant satisfies both.
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(613),
        page(428, index: 1, cursor: 'c2'),
      ]);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets, reason: 'starts empty');

      // Driven through the UI, not by calling the session directly.
      //
      // That is deliberate and it is what makes this a refresh test as well as
      // an origin test: the screen subtree is `const StrideShell()`, so it
      // rebuilds only when the controller notifies. A version that called
      // `session.syncSteps()` behind the widget's back would leave the tree
      // showing the old figure and would be testing nothing.
      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 613,
      );
      expect(find.text('613'), findsWidgets);

      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1041,
      );
      expect(find.text('1,041'), findsWidgets);
      expect(find.text('613'), findsNothing);
    });

    testWidgets('the inventory count tracks two different states', (
      WidgetTester tester,
    ) async {
      final FakeTiming fake = FakeTiming();
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(1000),
      ]);
      // One wall clock: the session's activity commands read the same fake
      // the controller's timing does (`DECISIONS/0022` §8).
      session.activityWallClock = fake.wallClock;
      await tester.pumpWidget(
        StrideApp(
          session: session,
          syncOnStart: false,
          activityTiming: fake.timing,
        ),
      );
      await tester.pumpAndSettle();

      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );

      // Two gathers, then a third: `×1` is no longer distinguishing (the
      // starting kit's tiles read `×1` too), so the herb count is asserted at
      // the unique figures 2 and 3.
      await gatherOnce(
        tester,
        fake,
        until: () => session.inventoryCount(kHerb) == 1,
      );
      await gatherOnce(
        tester,
        fake,
        until: () => session.inventoryCount(kHerb) == 2,
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.text('Adventure'));
      await tester.pumpAndSettle();
      await gatherOnce(
        tester,
        fake,
        until: () => session.inventoryCount(kHerb) == 3,
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('×2'), findsNothing);
    });

    testWidgets('Foraging XP tracks two different states', (
      WidgetTester tester,
    ) async {
      final FakeTiming fake = FakeTiming();
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(1000),
      ]);
      // One wall clock: the session's activity commands read the same fake
      // the controller's timing does (`DECISIONS/0022` §8).
      session.activityWallClock = fake.wallClock;
      await tester.pumpWidget(
        StrideApp(
          session: session,
          syncOnStart: false,
          activityTiming: fake.timing,
        ),
      );
      await tester.pumpAndSettle();

      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );
      await gatherOnce(
        tester,
        fake,
        until: () => session.inventoryCount(kHerb) == 1,
      );

      // **In the skill's roadmap since FMPO02.** The per-skill XP figure left
      // the Character sheet with the spine restructure (`ART-12` §3) and left
      // the Skills list with §4: the spine answers "where am I", and the
      // figures, the thresholds and what the level opens are the roadmap's
      // answer. Same projection, same content curve — Foraging's second
      // threshold is 100.
      await openForagingRoadmap(tester);
      expect(find.text('10 / 100 XP'), findsOneWidget);

      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adventure'));
      await tester.pumpAndSettle();
      await gatherOnce(
        tester,
        fake,
        until: () => session.inventoryCount(kHerb) == 2,
      );
      await openForagingRoadmap(tester);
      expect(find.text('20 / 100 XP'), findsOneWidget);
      expect(find.text('10 / 100 XP'), findsNothing);
    });
  });

  // =========================================================================
  // The gather control
  // =========================================================================

  group('the gather control', () {
    /// The exactly-at-cost boundary is untested at any layer today. `canGather`
    /// uses `<=`; nothing proves it, and a `<` written by mistake would be
    /// invisible except to a player who walked to exactly the cost.
    test('affordability is inclusive at exactly the cost', () async {
      final StrideSession at = await launch(
        source: funded(<SyncFetch>[page(80)]),
      );
      await baseline(at);
      await at.syncSteps();
      expect(at.usableEnergy, 80);
      expect(at.costOf(kNode), 80);
      expect(
        at.canGather(kNode),
        isTrue,
        reason: 'exactly the cost affords it',
      );

      final Directory other = Directory.systemTemp.createTempSync('stride_p1b');
      addTearDown(() {
        try {
          other.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows handle lag.
        }
      });
      final StrideSession below = await StrideSession.start(
        overrideRoot: other,
        source: funded(<SyncFetch>[page(79)]),
      );
      await baseline(below);
      await below.syncSteps();
      expect(below.usableEnergy, 79);
      expect(below.canGather(kNode), isFalse, reason: 'one short refuses');
    });

    testWidgets('below cost the control is disabled and states the shortfall', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(50),
      ]);
      await tester.runAsync(() => session.syncSteps());
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      // The control lives in the selected activity's expanded detail (§6).
      await tester.tap(find.text('Meadow Patch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Walk 30 more steps'), findsOneWidget);

      // Tapping a disabled control must not fabricate a success — and must
      // not start a queue either.
      await tester.tap(find.textContaining('Gather ×'));
      await tester.pumpAndSettle();
      expect(session.totalSpent, 0);
      expect(session.inventoryCount(kHerb), 0);
      expect(find.text('Stop gathering'), findsNothing);
    });

    testWidgets('one tap spends exactly one cost, and the screen refreshes', (
      WidgetTester tester,
    ) async {
      final FakeTiming fake = FakeTiming();
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(1000),
      ]);
      // One wall clock: the session's activity commands read the same fake
      // the controller's timing does (`DECISIONS/0022` §8).
      session.activityWallClock = fake.wallClock;
      await tester.pumpWidget(
        StrideApp(
          session: session,
          syncOnStart: false,
          activityTiming: fake.timing,
        ),
      );
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );

      // Banked and total-walked both read 1,000 before the spend.
      expect(find.text('1,000'), findsWidgets);

      await gatherOnce(tester, fake, until: () => session.totalSpent == 80);

      // Exactly one cost. A double dispatch lands on 160 / 2 / 20 and cannot
      // pass — which is the honest form of "invokes the session method once".
      expect(session.totalSpent, 80);
      expect(session.inventoryCount(kHerb), 1);
      expect(session.engine!.state.skills.experienceIn(kForaging), 10);

      // Asserted against RENDERED TEXT, not the session. Asserting the session
      // here could not fail for a missing-refresh defect.
      expect(find.text('920'), findsWidgets);

      // The ephemeral summary strip, accumulated from the returned
      // ActionReports — asserted while the card is still in view, because the
      // strip is a lazily built list child.
      // The result slip writes the name and the figure as separate widgets
      // — name on the left, figure down the right margin (EPO03, DIR-13) —
      // and a quantity of one is a number the slip does not need to state.
      // Same two claims as before: the herb is named, the XP is +10.
      final Finder slip = find.byType(ActivityResultCard);
      expect(slip, findsOneWidget);
      expect(
        find.descendant(of: slip, matching: find.text('Meadow Herb')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slip, matching: find.text('Foraging XP')),
        findsOneWidget,
      );
      expect(find.descendant(of: slip, matching: find.text('+10')), findsOneWidget);

      // `1,000` is still on screen, and correctly so: TOTAL WALKED reads
      // `totalGranted`, which never falls when steps are spent (`RULES.md`
      // H-2 — granted is monotonic, there is no clawback). Only the banked
      // figure moves. Asserting `findsNothing` here would have been asserting
      // a clawback.
      //
      // Under the harness's fat fallback font the card takes the stacked
      // branch and the queue selector puts the gather control below the
      // (inset-free) viewport, so reaching it scrolled the walking band — a
      // lazily built list child — out of the element tree. Scroll back before
      // asserting it, exactly as a player would.
      // (The scroll-back distance grew with the screen: the step-sync
      // opportunity banner and the goal tracker now sit above the band.)
      await tester.drag(find.byType(ListView).first, const Offset(0, 2400));
      await tester.pumpAndSettle();
      expect(find.text('1,000'), findsWidgets);
    });

    testWidgets('a second tap while the first is in flight spends nothing more', (
      WidgetTester tester,
    ) async {
      final FakeTiming fake = FakeTiming();
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(1000),
      ]);
      await tester.runAsync(() => session.syncSteps());
      session.activityWallClock = fake.wallClock;
      await tester.pumpWidget(
        StrideApp(
          session: session,
          syncOnStart: false,
          activityTiming: fake.timing,
        ),
      );
      await tester.pumpAndSettle();

      // The control lives in the selected activity's expanded detail (§6).
      await tester.tap(find.text('Meadow Patch'));
      await tester.pumpAndSettle();

      final Finder button = find.textContaining('Gather ×');
      // Scroll to it before the double tap, not during: the button is below the
      // fold, and `warnIfMissed: false` means a missed tap would pass silently
      // as "spent nothing" — the test would report success for the wrong
      // reason.
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        // Two taps with no pump between them: both reach the controller before
        // any rebuild could replace the button with the active panel. The
        // second start() must be refused by the running queue.
        await tester.tap(button, warnIfMissed: false);
        await tester.tap(button, warnIfMissed: false);
        // One repetition's worth of presentation time: if the double tap had
        // started two queues, two dispatches would land here.
        fake.advance(const Duration(seconds: 48));
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 10),
        );
        while (session.totalSpent == 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(session.totalSpent, 80, reason: 'charged once, not twice');
      expect(session.inventoryCount(kHerb), 1);
      // And the double tap must not have manufactured a compare-and-swap fault.
      expect(session.isStale, isFalse);

      // Nor a second queued repetition: more time dispatches nothing further.
      await tester.runAsync(() async {
        fake.advance(const Duration(minutes: 1));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(session.totalSpent, 80);
    });
  });

  // =========================================================================
  // Stale — the one genuinely uncovered path
  // =========================================================================

  group('a stale session', () {
    /// `isStale` is exercised by nothing anywhere in the repository. It is the
    /// only path where the UI can show a player figures the disk will
    /// contradict, so it is the concrete uncovered risk that justifies this
    /// file under G-1.
    testWidgets('refuses the action and says so instead of reporting success', (
      WidgetTester tester,
    ) async {
      final StrideSession a = await bootFunded(tester, <SyncFetch>[page(1000)]);
      await tester.runAsync(() => a.syncSteps());
      // Commit once so B opens against a durable head that already has energy.
      await tester.runAsync(() => a.gather(kNode));

      final StrideSession b = (await tester.runAsync(() => launch()))!;
      expect(b.usableEnergy, greaterThanOrEqualTo(80));

      // A moves the durable head under B.
      await tester.runAsync(() => a.gather(kNode));

      final FakeTiming fake = FakeTiming();
      b.activityWallClock = fake.wallClock;
      await tester.pumpWidget(
        StrideApp(session: b, syncOnStart: false, activityTiming: fake.timing),
      );
      await tester.pumpAndSettle();

      await gatherOnce(tester, fake, until: () => b.isStale);

      expect(b.isStale, isTrue);

      // Note what is deliberately NOT asserted here: that `b.totalSpent` is
      // unchanged. It IS changed — the engine applies a gather before the
      // commit resolves, so B's in-memory state now holds a spend and a yield
      // the disk refused. That divergence is precisely what `isStale` means,
      // and asserting it away would be asserting the opposite of the invariant.
      //
      // What matters is that the SCREEN stops presenting those figures as
      // truth, which is what the rest of this test checks.

      // The screen must present this as a blocking state with a recovery, not
      // as a success and not as a status row beside numbers that are wrong.
      expect(find.text('The last save did not land'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
      expect(find.textContaining('Meadow Herb ×2'), findsNothing);
    });
  });

  // =========================================================================
  // Layout
  // =========================================================================

  group('layout', () {
    for (final double width in <double>[320, 360, 375, 393, 430]) {
      testWidgets('no overflow at ${width.toInt()} dp', (
        WidgetTester tester,
      ) async {
        final StrideSession session = await bootFunded(tester, <SyncFetch>[
          page(1000),
        ], size: Size(width * 3, 852 * 3));
        await tester.runAsync(() => session.syncSteps());
        await tester.runAsync(() => session.gather(kNode));

        await tester.pumpWidget(
          StrideApp(session: session, syncOnStart: false),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final String tab in <String>['Character', 'Inventory', 'World']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab overflowed at ${width.toInt()} dp',
          );
        }
      });
    }

    /// Visual QA saw the header sitting ~10 px from the top edge and the tab
    /// labels ~16 px from the bottom, and correctly declined to say whether
    /// that was an app defect or a harness default — `flutter test` supplies
    /// zero `viewPadding`.
    ///
    /// It is the harness. This test proves it rather than assuming it, by
    /// supplying real insets and asserting the shell honours them. It also
    /// guards the other half of the rule: exactly one `SafeArea` in the tree.
    /// A second one nested inside the first silently double-insets, which is
    /// how a tab bar acquires a 34 px float on one device family and looks
    /// perfect everywhere else.
    testWidgets('safe-area insets are applied, and applied exactly once', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);

      const EdgeInsets insets = EdgeInsets.only(top: 59, bottom: 34);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewPadding: insets, padding: insets),
          child: StrideApp(session: session, syncOnStart: false),
        ),
      );
      await tester.pumpAndSettle();

      // The header clears the status region rather than sitting under it.
      final double headerTop = tester.getTopLeft(find.byType(ScreenHeader)).dy;
      expect(
        headerTop,
        greaterThanOrEqualTo(59),
        reason: 'the header must sit below the status bar / Dynamic Island',
      );

      // The tab bar's ground reaches the bottom edge, and its content clears
      // the home indicator.
      //
      // **Measured against the content box, not the bar** (EPO03). The bar
      // became a leather strap that paints the home-indicator inset in its own
      // material, because a flat `surfaceCard` rectangle under a leather bar
      // was a seam across the bottom of every screen on a notched device
      // (`DIR-15_mobile_ux.md` §2). So `StrideTabBar`'s own bottom is now the
      // bottom of the glass by design, and it has stopped being a proxy for
      // where the tabs end. The invariant is unchanged and still 34: the
      // *tabs* must clear the home indicator. Only the thing it is measured
      // against moved, with the widget boundary.
      final double barBottom = tester
          .getBottomLeft(find.byType(StrideTabBar))
          .dy;
      expect(
        barBottom,
        852,
        reason: 'the strap itself must reach the bottom edge, leaving no seam',
      );
      final double contentBottom = tester
          .getBottomLeft(find.byKey(StrideTabBar.contentKey))
          .dy;
      expect(
        852 - contentBottom,
        greaterThanOrEqualTo(34),
        reason: 'tab-bar content must clear the home indicator',
      );

      // Exactly one SafeArea, from StrideScaffold. The product screens must not
      // add their own.
      expect(
        find.byType(SafeArea),
        findsNothing,
        reason:
            'StrideScaffold handles insets directly; a SafeArea anywhere under '
            'it would double-inset',
      );
    });

    /// Every string in the product was rendering with a yellow double underline,
    /// and nothing in this repository could see it.
    ///
    /// `MaterialApp` supplies a theme but not a `Material`. Without a `Material`
    /// ancestor, `DefaultTextStyle` resolves to Flutter's fallback — labelled,
    /// in Flutter's own source, "consider putting your text in a Material" —
    /// and that style carries `TextDecoration.underline`. No `StrideType` role
    /// sets a `decoration`, so all of them inherited it.
    ///
    /// It survived 93 widget tests and four goldens. Widget tests read the
    /// *content* of a string, never its decoration; the golden harness has no
    /// real font and draws every glyph as a filled rectangle, so the underline
    /// merged into the box. It took a screenshot from a running device.
    ///
    /// So this asserts the resolved style rather than the widget tree: checking
    /// for a `Material` would pass the moment someone added one anywhere, and
    /// the defect is about what the text actually inherits.
    testWidgets('no text inherits the missing-Material fallback style', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      for (final Element element in find.byType(Text).evaluate()) {
        final TextStyle inherited = DefaultTextStyle.of(element).style;
        expect(
          inherited.decoration,
          isNot(TextDecoration.underline),
          reason:
              'the text "${(element.widget as Text).data}" inherits Flutter\'s '
              'no-Material fallback, which underlines every glyph in yellow',
        );
      }
    });

    /// Phase 1 asserted the inverse of this — that Skills and Craft were inert,
    /// because neither had a screen and a live-looking tab that does nothing is
    /// the one genuinely misleading option. Both are built as of Phase 2
    /// (`DECISIONS/0017`), so the assertion flips with them.
    ///
    /// What is *not* dropped is the property underneath: a destination and the
    /// screen behind it must agree. That is now enforced by the shell's switch
    /// being exhaustive with no `_` arm, so a seventh tab added without a screen
    /// is a compile error rather than a blank tab.
    testWidgets('all six tabs navigate to their own screen', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      for (final String tab in <String>[
        'Skills',
        'Craft',
        'Inventory',
        'Character',
        'World',
        'Adventure',
      ]) {
        expect(find.text(tab), findsWidgets, reason: '$tab is missing');
        // The tab bar's own label, not a screen's — `Craft` is also a button on
        // the Craft screen, so tapping "any Craft" would be ambiguous.
        await tester.tap(
          find.descendant(
            of: find.byType(StrideTabBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();

        // **The tab's name is no longer in the header at all** (FMPO02,
        // `ART-12` §8). It was the title until
        // PRESENTATION_COMBAT_EVOLUTION_01 and the eyebrow after it; both
        // reprinted, four dp above the lit nav plate, the word the nav plate
        // was already saying. So the navigation claim is made against the
        // bar's own selection instead — which is the fact "the shell moved"
        // actually consists of — and the header is asserted for what it now
        // carries.
        expect(
          tester.widget<StrideTabBar>(find.byType(StrideTabBar)).selected.label,
          tab,
          reason:
              'tapping $tab did not select $tab; the shell did not navigate, '
              'or the destination has no screen',
        );
        expect(
          find.descendant(
            of: find.byType(ScreenHeader),
            matching: find.text(tab.toUpperCase()),
          ),
          findsNothing,
          reason:
              'the header is reprinting the tab name. Both lines of it are '
              'the place; the nav plate says which tab this is.',
        );

        // The eyebrow is the place's own descriptor, in the atlas
        // inspector's words — `SETTLEMENT · GRASSLAND` at Haven's Rest.
        final PlaceIdentity identity = session.placeIdentityOf(
          session.currentLocation!,
        )!;
        expect(
          find.descendant(
            of: find.byType(ScreenHeader),
            matching: find.text(
              AtlasPlaceInfo.descriptorFor(identity).toUpperCase(),
            ),
          ),
          findsOneWidget,
          reason: 'the header on $tab does not describe the place',
        );

        // And the header's TITLE is the place, on every tab.
        //
        // This is the inversion's whole point, so it is asserted rather than
        // assumed. The largest word on screen used to be the name of the menu
        // the player was standing in — reprinted by the tab bar four dp below
        // — which is the single strongest "this is an application" signal the
        // product had. It is now where you are, and it changes when you walk.
        expect(
          find.descendant(
            of: find.byType(ScreenHeader),
            matching: find.text(session.locationName),
          ),
          findsOneWidget,
          reason:
              'the header on $tab does not name the place. If the title has '
              'gone back to being the tab label, the inversion has regressed.',
        );
      }
    });

    testWidgets('the Skills screen shows derived progression, not raw XP', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StrideTabBar),
          matching: find.text('Skills'),
        ),
      );
      await tester.pumpAndSettle();

      // All five, from content. `skipOffstage: false`, because the richer
      // cards (each now lists its next few unlocks — Fable V2) scroll: the
      // fifth card sits below the fold at 852 dp, which is the cost of
      // cards that answer "what next" instead of one line.
      for (final String skill in <String>[
        'Foraging',
        'Woodcutting',
        'Mining',
        'Smithing',
        'Cooking',
      ]) {
        expect(
          find.text(skill, skipOffstage: false),
          findsWidgets,
          reason: '$skill is missing',
        );
      }

      // A fresh save is level 1 in everything, and Foraging's second threshold
      // is 100 — the figure that proves the span came from the curve rather
      // than from a placeholder.
      // Scoped to this screen since FMPO02: the Character sheet's skill block
      // is the same spine list now (`ART-12` §3), and the shell keeps every
      // tab mounted — so an unscoped `skipOffstage: false` finder counts both
      // screens' spines and reports ten.
      expect(
        find.descendant(
          of: find.byType(SkillsScreen, skipOffstage: false),
          matching: find.text('LV 1', skipOffstage: false),
          skipOffstage: false,
        ),
        findsNWidgets(5),
      );
      // **The XP span moved to the roadmap** (`ART-12` §4). The spine says
      // where you are; what the next level costs is the pushed route's
      // answer, and the route is one tap from any spine. Foraging's second
      // threshold is 100 — the figure that proves the span came from the
      // content curve rather than from a placeholder.
      await tester.tap(
        find.descendant(
          of: find.byType(SkillsScreen, skipOffstage: false),
          matching: find.text('Foraging'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 100 XP'), findsOneWidget);
      expect(
        find.textContaining('to level 2'),
        findsWidgets,
        reason: 'the roadmap must say what the next level costs',
      );
    });

    testWidgets('the Craft screen lists real recipes and refuses truthfully', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(StrideTabBar),
          matching: find.text('Craft'),
        ),
      );
      await tester.pumpAndSettle();

      // From recipes.json, not written into the widget. The **station** is
      // the screen's axis since FMPO02 (`ART-12` §1), so a fresh save stands
      // at the forge and sees the ingot; the broth is a walk away at the
      // cookfire, and the strip is how the player takes that walk.
      expect(find.text('Bronze Ingot'), findsWidgets);

      // A fresh save holds no materials: the census is honest.
      expect(
        find.textContaining('0 craftable · '),
        findsOneWidget,
        reason: 'the census is two figures in one shape at every count (§8)',
      );

      await tester.tap(find.text('Cookfire'));
      await tester.pumpAndSettle();
      expect(find.text('Herb Broth'), findsWidgets);
      // The cookfire's folio opens on the nearest thing to a meal, already
      // expanded, and its button carries the shortfall sentence.
      expect(
        find.textContaining('Needs 2 more Meadow Herb'),
        findsOneWidget,
        reason: 'the shortfall must name the item and the amount',
      );

      for (final Element element in find.byType(StrideButton).evaluate()) {
        final StrideButton button = element.widget as StrideButton;
        if (button.label != 'Craft') continue;
        expect(
          button.onPressed,
          isNull,
          reason: 'no recipe is craftable on a fresh save',
        );
      }
    });
  });

  // =========================================================================
  // World — the atlas: presentation that must not outrun the domain
  // =========================================================================

  group('the World screen', () {
    Future<void> openWorld(WidgetTester tester, StrideSession session) async {
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('World'));
      await tester.pumpAndSettle();
    }

    /// Selects a place on the atlas by its hit target. The panel beneath the
    /// viewport then describes it.
    ///
    /// Pans first, because the viewport opens on the current location and a
    /// place two roads away is off-screen — exactly as it is for a player, who
    /// drags the map to it. `tester.tap` on an off-screen target hits nothing
    /// and warns rather than failing, so a tap without the pan would pass on
    /// nothing.
    Future<void> selectPlace(WidgetTester tester, String id) async {
      final Finder target = find.byKey(ValueKey<String>('atlas-hit:$id'));
      final Finder viewport = find.byType(AtlasViewport);
      final Offset from = tester.getCenter(viewport);
      final Offset delta = from - tester.getCenter(target);
      await tester.dragFrom(from, delta);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      // The World sheet opens at its PEEK stop and a marker tap never raises
      // it (DIR-15 §1, the owner's "the sheet obscures too much map"). The
      // inspector these tests read is at the HALF stop, one grip tap away —
      // exactly the gesture a player makes to go from "what is that" to
      // "what is there, and what does it cost".
      await tester.tap(find.byKey(worldSheetGripKey));
      await tester.pumpAndSettle();
    }

    testWidgets('navigates, and renders the region from content', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await openWorld(tester, session);

      // Every location in the content pack, by its own display name — not a
      // list written into the widget. On the atlas each is a label under its
      // marker, and each has a hit target keyed by its content id.
      for (final (String id, String place) in <(String, String)>[
        ('location.havens_rest', "Haven's Rest"),
        ('location.whispering_woods', 'Whispering Woods'),
        ('location.stonefall_mine', 'Stonefall Mine'),
        ('location.frostmere', 'Frostmere'),
        ('location.forgotten_hollow', 'Forgotten Hollow'),
      ]) {
        expect(
          find.text(place),
          findsWidgets,
          reason: '$place is in locations.json and must appear',
        );
        expect(
          find.byKey(ValueKey<String>('atlas-hit:$id')),
          findsOneWidget,
          reason: '$place must be a target on the atlas',
        );
      }

      // The player's own location is named as such, from world state: the
      // panel opens on it before any tap.
      expect(find.textContaining('You are here'), findsOneWidget);
    });

    /// Phase 1 asserted that this screen had **no controls at all**, because no
    /// travel command existed and a button would have been the most convincing
    /// lie in the demo.
    ///
    /// `TravelTo` exists now, so the prohibition is satisfied rather than
    /// overridden — and the property that replaces it is the one that made the
    /// old rule worth having: **every control here must correspond to a real
    /// command, and offer only journeys the engine would accept.** On the atlas
    /// that means: a place with a road from here gets a Travel button when
    /// selected; a place without one gets a sentence and no button.
    testWidgets('every travel control corresponds to a real route', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(50000),
      ]);
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);

      // Nothing is offered until a place is chosen — the panel is on the
      // current location, and there is no journey to *here*.
      expect(find.widgetWithText(StrideButton, 'Travel'), findsNothing);

      // Haven's Rest connects to two places and to no others.
      for (final String id in <String>[
        'location.whispering_woods',
        'location.stonefall_mine',
      ]) {
        await selectPlace(tester, id);
        final Finder button = find.widgetWithText(StrideButton, 'Travel');
        expect(button, findsOneWidget, reason: '$id has a road from here');
        expect(
          (tester.widget(button) as StrideButton).onPressed,
          isNotNull,
          reason: '50,000 banked affords every route out of Haven\'s Rest',
        );
      }

      // Frostmere is in the content pack and is reached through Stonefall —
      // since PRESENTATION_WORLD_REWARD_FEEL_01 B-2 the whole two-leg walk is
      // offered as one journey, priced whole, enabled at 50,000 banked.
      await selectPlace(tester, 'location.frostmere');
      final Finder journey = find.widgetWithText(StrideButton, 'Travel');
      expect(journey, findsOneWidget);
      expect((tester.widget(journey) as StrideButton).onPressed, isNotNull);
      expect(
        find.text('By way of Stonefall Mine · 4,400 steps in all'),
        findsOneWidget,
      );
    });

    testWidgets('an unaffordable journey is disabled and states the gap', (
      WidgetTester tester,
    ) async {
      // 100 banked against a 500 route: the control must refuse and say how
      // far short, rather than failing on tap.
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(100),
      ]);
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);
      await selectPlace(tester, 'location.whispering_woods');

      expect(find.textContaining('Walk 400 more steps'), findsOneWidget);
      // The Travel control refuses; "Set as Journey" stays live on purpose —
      // tracking a goal never needs (or reserves) steps (`DECISIONS/0023` §3).
      final Finder travel = find.widgetWithText(StrideButton, 'Travel');
      expect(travel, findsOneWidget);
      expect((tester.widget(travel) as StrideButton).onPressed, isNull);
    });

    testWidgets('travelling spends exactly the cost and moves the player', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(2000),
      ]);
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);
      await selectPlace(tester, 'location.whispering_woods');

      // The tap opens the confirmation step (brief §53); the journey
      // dispatches on "Set out".
      await tester.ensureVisible(find.widgetWithText(StrideButton, 'Travel'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StrideButton, 'Travel'));
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.widgetWithText(StrideButton, 'Set out'),
        until: () => session.currentLocation?.value != 'location.havens_rest',
      );

      expect(
        session.usableEnergy,
        1500,
        reason: '2,000 − 500, the Whispering Woods route from content',
      );
      expect(session.currentLocation?.value, 'location.whispering_woods');

      // The panel follows the player: it now describes *here*, which is the
      // woods, and offers no journey to the place they are standing in.
      expect(find.textContaining('You are here'), findsOneWidget);
      expect(find.widgetWithText(StrideButton, 'Travel'), findsNothing);
    });

    /// Banked steps are teal; a route cost is not. `ART_DIRECTION.md` L-16
    /// reserves the accent for steps the player *owns*, and the route figures
    /// are the most tempting place to spend it wrongly — they are step
    /// quantities that are not the player's balance.
    ///
    /// Still true now that they are prices rather than distances: a price is a
    /// quantity of steps, not a holding of them.
    testWidgets('route costs do not use the banked-steps accent', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await openWorld(tester, session);
      await selectPlace(tester, 'location.whispering_woods');

      final Finder cost = find.descendant(
        of: find.byType(WorldScreen),
        matching: find.text('500'),
      );
      expect(
        cost,
        findsWidgets,
        reason: 'the Whispering Woods route cost, from content',
      );

      for (final Element element in cost.evaluate()) {
        expect(
          (element.widget as Text).style?.color,
          isNot(StrideColors.accentSteps),
          reason: 'a route price is not steps the player owns',
        );
      }
    });
  });

  // =========================================================================
  // The activity stage — art that must not outrun the domain
  // =========================================================================

  group('the activity stage', () {
    /// The animation depicts a command that succeeded. A refusal must leave the
    /// figure at rest, because a Traveler miming a pick the player did not get
    /// is the fabricated-success defect in motion — and more convincing than a
    /// text line would be.
    testWidgets('a refused gather leaves the figure at its rest frame', (
      WidgetTester tester,
    ) async {
      // 79 banked against an 80 cost: the control is disabled, so no gather
      // can even be dispatched, and the stage must still be showing frame 0.
      final StrideSession session = await bootFunded(tester, <SyncFetch>[
        page(79),
      ]);
      await tester.runAsync(() => session.syncSteps());
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      expect(
        find.byType(SpriteAnimation),
        findsOneWidget,
        reason: 'the stage is present whether or not anything has happened',
      );

      final Image rendered = tester.widget<Image>(
        find.descendant(
          of: find.byType(SpriteAnimation),
          matching: find.byType(Image),
        ),
      );
      expect(
        (rendered.image as AssetImage).assetName,
        PixelIcons.gatherFrames.first,
        reason: 'at rest, and rest is frame 0',
      );
    });

    /// The contact shadow is the composition rule for standalone sprites, and
    /// its width comes from the sprite rather than from a caller. This asserts
    /// the wiring — that the stage is grounded at all — because a
    /// `GroundedSprite` quietly replaced by a bare `PixelAsset.sprite` is
    /// exactly the regression that puts the figure back in the air.
    testWidgets('the figure is grounded, from its own measured footprint', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      final GroundedSprite grounded = tester.widget<GroundedSprite>(
        find.byType(GroundedSprite),
      );
      expect(grounded.footprint, same(SpriteFootprints.gather));

      // The measured contact span, not the sprite's 64 px box. If these were
      // equal the measurement would have collapsed to the bounding box and the
      // shadow would be as wide as the backpack.
      expect(grounded.footprint.width, lessThan(64));
      expect(grounded.footprint.width, greaterThan(0));
    });
  });
}
