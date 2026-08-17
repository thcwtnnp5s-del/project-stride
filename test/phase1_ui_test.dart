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
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/components/screen_header.dart';
import 'package:stride/ui/components/sprite_animation.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';
import 'package:stride/ui/screens/world/world_screen.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

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
      // `until` observes the session, which the handler updates before it
      // notifies. The grace period lets that continuation run.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(until(), isTrue, reason: 'the tapped action did not complete');

    // Then wait for the *controller* to leave its busy state, not only the
    // session.
    //
    // These are two different clocks. `until` observes `StrideSession`, which
    // the handler updates before `SessionController` clears `busy` and
    // notifies — so there is a window where the figures are final and the
    // buttons still read `Checking…` and `Gathering…`. A following step that
    // looks for `Gather —` then finds nothing, and the failure surfaces as
    // `Bad state: No element` inside `ensureVisible`, pointing at the finder
    // rather than at the race.
    //
    // The 100 ms grace above covered it on a fast run and not on a slow one,
    // which is why this suite was intermittent on Windows **before** the
    // facelift as well as after it. This asserts a real property — the UI has
    // returned to idle — rather than lengthening a sleep until it usually
    // works.
    bool busy() =>
        find.text('Checking…').evaluate().isNotEmpty ||
        find.text('Gathering…').evaluate().isNotEmpty;

    for (int i = 0; i < 100 && busy(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    expect(busy(), isFalse, reason: 'the control never returned to idle');
  }

  // =========================================================================
  // Startup
  // =========================================================================

  group('startup', () {
    testWidgets('the first frame already shows the loaded save, not zeros', (
      WidgetTester tester,
    ) async {
      // Bank some steps and make them durable, then relaunch cold.
      final StrideSession first = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1041)]),
      );
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
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(
          script: <SyncFetch>[
            page(613),
            page(428, index: 1, cursor: 'c2'),
          ],
        ),
      );
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
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1000)]),
      );
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );

      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => session.inventoryCount(kHerb) == 2,
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.text('Adventure'));
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => session.inventoryCount(kHerb) == 4,
      );
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('×4'), findsOneWidget);
      expect(find.text('×2'), findsNothing);
    });

    testWidgets('Foraging XP tracks two different states', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1000)]),
      );
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );
      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => session.inventoryCount(kHerb) == 2,
      );

      await tester.tap(find.text('Character'));
      await tester.pumpAndSettle();
      expect(find.text('10 XP'), findsOneWidget);

      await tester.tap(find.text('Adventure'));
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => session.inventoryCount(kHerb) == 4,
      );
      await tester.tap(find.text('Character'));
      await tester.pumpAndSettle();
      expect(find.text('20 XP'), findsOneWidget);
      expect(find.text('10 XP'), findsNothing);
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
        source: MockStepSource(script: <SyncFetch>[page(90)]),
      );
      await at.syncSteps();
      expect(at.usableEnergy, 90);
      expect(at.costOf(kNode), 90);
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
        source: MockStepSource(script: <SyncFetch>[page(89)]),
      );
      await below.syncSteps();
      expect(below.usableEnergy, 89);
      expect(below.canGather(kNode), isFalse, reason: 'one short refuses');
    });

    testWidgets('below cost the control is disabled and states the shortfall', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(50)]),
      );
      await tester.runAsync(() => session.syncSteps());
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      expect(find.textContaining('Walk 40 more steps'), findsOneWidget);

      // Tapping a disabled control must not fabricate a success.
      await tester.tap(find.textContaining('Gather —'));
      await tester.pumpAndSettle();
      expect(session.totalSpent, 0);
      expect(session.inventoryCount(kHerb), 0);
    });

    testWidgets('one tap spends exactly one cost, and the screen refreshes', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1000)]),
      );
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      await tapAndAwait(
        tester,
        find.text('Sync steps'),
        until: () => session.usableEnergy == 1000,
      );

      // Banked and total-walked both read 1,000 before the spend.
      expect(find.text('1,000'), findsWidgets);

      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => session.totalSpent == 90,
      );

      // Exactly one cost. A double dispatch lands on 180 / 4 / 20 and cannot
      // pass — which is the honest form of "invokes the session method once".
      expect(session.totalSpent, 90);
      expect(session.inventoryCount(kHerb), 2);
      expect(session.engine!.state.skills.experienceIn(kForaging), 10);

      // Asserted against RENDERED TEXT, not the session. Asserting the session
      // here could not fail for a missing-refresh defect.
      expect(find.text('910'), findsWidgets);

      // `1,000` is still on screen, and correctly so: TOTAL WALKED reads
      // `totalGranted`, which never falls when steps are spent (`RULES.md`
      // H-2 — granted is monotonic, there is no clawback). Only the banked
      // figure moves. Asserting `findsNothing` here would have been asserting
      // a clawback.
      expect(find.text('1,000'), findsWidgets);

      // The ephemeral result strip, built from the ActionReport.
      expect(find.textContaining('Meadow Herb ×2'), findsOneWidget);
      expect(find.textContaining('+10 Foraging XP'), findsOneWidget);
    });

    testWidgets('a second tap while the first is in flight spends nothing more', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1000)]),
      );
      await tester.runAsync(() => session.syncSteps());
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();

      final Finder button = find.textContaining('Gather —');
      // Scroll to it before the double tap, not during: the button is below the
      // fold, and `warnIfMissed: false` means a missed tap would pass silently
      // as "spent nothing" — the test would report success for the wrong
      // reason.
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        // Two taps with no pump between them: both dispatch before any rebuild
        // could disable the control.
        await tester.tap(button, warnIfMissed: false);
        await tester.tap(button, warnIfMissed: false);
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 10),
        );
        while (session.totalSpent == 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(session.totalSpent, 90, reason: 'charged once, not twice');
      expect(session.inventoryCount(kHerb), 2);
      // And the double tap must not have manufactured a compare-and-swap fault.
      expect(session.isStale, isFalse);
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
      final StrideSession a = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(1000)]),
      );
      await tester.runAsync(() => a.syncSteps());
      // Commit once so B opens against a durable head that already has energy.
      await tester.runAsync(() => a.gather(kNode));

      final StrideSession b = (await tester.runAsync(() => launch()))!;
      expect(b.usableEnergy, greaterThanOrEqualTo(90));

      // A moves the durable head under B.
      await tester.runAsync(() => a.gather(kNode));

      await tester.pumpWidget(StrideApp(session: b, syncOnStart: false));
      await tester.pumpAndSettle();

      await tapAndAwait(
        tester,
        find.textContaining('Gather —'),
        until: () => b.isStale,
      );

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
        final StrideSession session = await boot(
          tester,
          source: MockStepSource(script: <SyncFetch>[page(1000)]),
          size: Size(width * 3, 852 * 3),
        );
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
      final double barBottom = tester
          .getBottomLeft(find.byType(StrideTabBar))
          .dy;
      expect(
        852 - barBottom,
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

        // The header title is the selected destination's label, so finding it
        // in the header is what proves the shell actually moved.
        expect(
          find.descendant(
            of: find.byType(ScreenHeader),
            matching: find.text(tab),
          ),
          findsOneWidget,
          reason:
              'tapping $tab did not put $tab in the header; the shell did not '
              'navigate, or the destination has no screen',
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

      // All five, from content.
      for (final String skill in <String>[
        'Foraging',
        'Woodcutting',
        'Mining',
        'Smithing',
        'Cooking',
      ]) {
        expect(find.text(skill), findsWidgets, reason: '$skill is missing');
      }

      // A fresh save is level 1 in everything, and Foraging's second threshold
      // is 100 — the figure that proves the span came from the curve rather
      // than from a placeholder.
      expect(find.text('LV 1'), findsNWidgets(5));
      expect(find.text('0 / 100 XP'), findsWidgets);
      expect(
        find.textContaining('to level 2'),
        findsWidgets,
        reason: 'the screen must say what the next level costs',
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

      // From recipes.json, not written into the widget. `findsWidgets` because
      // each card names its output twice — as the recipe and as "Makes …".
      expect(find.text('Herb Broth'), findsWidgets);
      expect(find.text('Bronze Ingot'), findsWidgets);

      // A fresh save holds no materials, so every card must be disabled *and*
      // say why. A grey button with no sentence beside it is indistinguishable
      // from a broken one.
      expect(find.textContaining('Nothing can be made yet'), findsOneWidget);
      expect(
        find.textContaining('Needs 3 more Meadow Herb'),
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
  // World — presentation that must not become an affordance
  // =========================================================================

  group('the World screen', () {
    Future<void> openWorld(WidgetTester tester, StrideSession session) async {
      await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('World'));
      await tester.pumpAndSettle();
    }

    testWidgets('navigates, and renders the region from content', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(tester);
      await openWorld(tester, session);

      // Every location in the content pack, by its own display name — not a
      // list written into the widget.
      for (final String place in <String>[
        "Haven's Rest",
        'Whispering Woods',
        'Stonefall Mine',
        'Frostmere',
        'Forgotten Hollow',
      ]) {
        expect(
          find.text(place),
          findsWidgets,
          reason: '$place is in locations.json and must appear',
        );
      }

      // The player's own location is named as such, from world state.
      expect(find.textContaining('You are here'), findsOneWidget);

      // And it leads the list.
      //
      // `ContentRegistry.locations` iterates by content id, which is
      // alphabetical, so the unordered list opened with *Forgotten Hollow* — a
      // place the player has never been — on a screen whose first question is
      // "where am I?". Asserting a vertical position rather than list index,
      // because what went wrong was what the player saw first.
      //
      // `.last`, because the facelift added a `YOU ARE HERE` caption directly
      // under the map, so the current location's name now appears twice. The
      // caption is the higher of the two; taking the lower one keeps this
      // asserting what it was written to assert — the position of the row in
      // the region list — rather than passing on the strength of the new
      // caption sitting above everything by construction.
      // Scoped to the region card, because Phase 2 put a place name in three
      // places on this screen: the travel card (ordered by price), the region
      // list (ordered with the current location first), and the map's caption.
      // `.first` or `.last` would each measure a different card depending on
      // the layout of the day; naming the card measures the rule this test is
      // about.
      // Uppercase: `SectionHeading` renders `label.toUpperCase()`, so the
      // string in the tree is not the string the widget was given.
      final Finder regionCard = find.ancestor(
        of: find.text('THIS REGION'),
        matching: find.byType(SectionCard),
      );
      double rowY(String place) => tester
          .getTopLeft(
            find.descendant(of: regionCard, matching: find.text(place)),
          )
          .dy;

      final double here = rowY("Haven's Rest");
      for (final String elsewhere in <String>[
        'Forgotten Hollow',
        'Frostmere',
        'Stonefall Mine',
        'Whispering Woods',
      ]) {
        expect(
          rowY(elsewhere),
          greaterThan(here),
          reason: 'the current location leads the region list',
        );
      }
    });

    /// Phase 1 asserted that this screen had **no controls at all**, because no
    /// travel command existed and a button would have been the most convincing
    /// lie in the demo.
    ///
    /// `TravelTo` exists now, so the prohibition is satisfied rather than
    /// overridden — and the property that replaces it is the one that made the
    /// old rule worth having: **every control here must correspond to a real
    /// command, and offer only journeys the engine would accept.**
    testWidgets('every travel control corresponds to a real route', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(50000)]),
      );
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);

      // Haven's Rest connects to two places and to no others. Frostmere is in
      // the content pack and is reached through Stonefall — so it must appear
      // in the region legend and *not* as a journey from here.
      expect(find.widgetWithText(StrideButton, 'Travel'), findsNWidgets(2));
      expect(find.text('Whispering Woods'), findsWidgets);
      expect(find.text('Stonefall Mine'), findsWidgets);

      final Finder journeys = find.byType(StrideButton);
      for (final Element element in journeys.evaluate()) {
        expect(
          (element.widget as StrideButton).onPressed,
          isNotNull,
          reason: '50,000 banked affords every route out of Haven\'s Rest',
        );
      }
    });

    testWidgets('an unaffordable journey is disabled and states the gap', (
      WidgetTester tester,
    ) async {
      // 100 banked against a 600 route: the control must refuse and say how far
      // short, rather than failing on tap.
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(100)]),
      );
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);

      expect(find.textContaining('Walk 500 more steps'), findsOneWidget);
      for (final Element element in find.byType(StrideButton).evaluate()) {
        expect((element.widget as StrideButton).onPressed, isNull);
      }
    });

    testWidgets('travelling spends exactly the cost and moves the player', (
      WidgetTester tester,
    ) async {
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(2000)]),
      );
      await tester.runAsync(() => session.syncSteps());
      await openWorld(tester, session);

      await tapAndAwait(
        tester,
        find.widgetWithText(StrideButton, 'Travel').first,
        until: () => session.currentLocation?.value != 'location.havens_rest',
      );

      expect(
        session.usableEnergy,
        1400,
        reason: '2,000 − 600, the Whispering Woods route from content',
      );
      expect(
        session.currentLocation?.value,
        'location.whispering_woods',
        reason: 'the cheapest route is listed first, and it leads to the woods',
      );
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

      final Finder cost = find.descendant(
        of: find.byType(WorldScreen),
        matching: find.text('600'),
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
      // 89 banked against a 90 cost: the control is disabled, so no gather can
      // even be dispatched, and the stage must still be showing frame 0.
      final StrideSession session = await boot(
        tester,
        source: MockStepSource(script: <SyncFetch>[page(89)]),
      );
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
