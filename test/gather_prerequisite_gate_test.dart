// Prerequisite gating for gathering (physical-device defect): a player at
// Foraging 1 could START a queue at a node requiring Foraging 3 — the
// authoritative completion refused it and spent nothing, but the player
// watched a long animation guaranteed to fail. An activity that cannot
// legally complete on KNOWN static prerequisites — skill level, equipped
// tool — must not be startable or queueable.
//
// Three surfaces are proven here:
//   1. UI — ineligible nodes disable the Gather button AND the quantity
//      presets/stepper, with the concrete reason on the button and the
//      failing RequirementGate carrying the unmet state.
//   2. UI — an eligible node's controls behave exactly as before.
//   3. Domain defense in depth — dispatching the gather anyway, at session
//      level, is still refused with zero steps spent, zero XP, zero items.
//      The UI check is a hint that mirrors the engine; the engine decides.
//
// The Whispering Woods provides both failing cases from the shipped content
// pack: Duskcap Grove requires Foraging 3 (a fresh player is 1), and Oak
// Stand requires an axe (a fresh player has none equipped).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/screens/adventure/activity_panel.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId oakStand = ContentId.unchecked('resource_node.oak_stand');
final ContentId duskcapGrove = ContentId.unchecked(
  'resource_node.duskcap_grove',
);
final ContentId duskcap = ContentId.unchecked('item.duskcap');
final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId foraging = ContentId.unchecked('skill.foraging');

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
  setUp(() => root = Directory.systemTemp.createTempSync('stride_prereq'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A cold launch over [root], funded with [steps] after the baseline sync
  /// (`DECISIONS/0019`).
  Future<StrideSession> fundedSession(int steps) async {
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

  /// Boots a funded session, optionally travels it to the Whispering Woods,
  /// and pumps the app.
  Future<StrideSession> pumpApp(
    WidgetTester tester, {
    required int steps,
    bool atWoods = false,
  }) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(
      () => fundedSession(steps),
    ))!;
    if (atWoods) {
      final TravelReport t = (await tester.runAsync(
        () => session.travel(woods),
      ))!;
      expect(t.succeeded, isTrue, reason: '${t.rejection}: ${t.detail}');
    }

    await tester.pumpWidget(
      StrideApp(
        session: session,
        syncOnStart: false,
        activityTiming: FakeTiming().timing,
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  /// Selects the activity row named [nodeName] in the compact list.
  Future<void> select(WidgetTester tester, String nodeName) async {
    final Finder row = find.text(nodeName);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// The expanded detail's primary gather button.
  StrideButton gatherButton(WidgetTester tester) => tester
      .widgetList<StrideButton>(
        find.descendant(
          of: find.byType(ActivityDetail),
          matching: find.byType(StrideButton),
        ),
      )
      .first;

  /// The requirement gates in the expanded detail. Only UNMET gates render
  /// since the Adventure restructure — met requirements live on the row's
  /// sub-line (PRESENTATION_WORLD_REWARD_FEEL_01 §44).
  List<RequirementGate> gates(WidgetTester tester) => tester
      .widgetList<RequirementGate>(
        find.descendant(
          of: find.byType(ActivityDetail),
          matching: find.byType(RequirementGate),
        ),
      )
      .toList();

  testWidgets('skill too low: row reads locked, controls disabled with the '
      'concrete reason', (WidgetTester tester) async {
    await pumpApp(tester, steps: 2000, atWoods: true);

    // The journal entry states the gap before anything is tapped (§7: locked
    // activities stay visible and aspirational). Three locked entries since
    // Fable Depth Offensive 01 added the Warded Grove (WC 6, behind the
    // Watchtower — `DECISIONS/0028`) beside Iteration 03's Heartwood Oak
    // (WC 4) and the grove.
    expect(find.text('Duskcap Grove'), findsOneWidget);
    expect(find.text('Requires Foraging 3 — you are 1'), findsOneWidget);

    // **The word `LOCKED` is gone and its absence is asserted** (FMPO02,
    // `ART-12` §5). It said, in a fourth place, what the reason line beside
    // it says with a distance attached.
    //
    // What marks a locked entry is now a **pencil remap** and not a dim
    // (EPO03, `DIR-05`: "Locked = dim" is its second-named phone-visible
    // failure, and "an A-2 pencil remap plus a margin note" is the
    // replacement it names by title). Opacity 0.55 said *switched off*; a
    // graphite sketch says *drawn, not inked yet*, which is what a site you
    // cannot work yet is. The assertion moves because the rule's owner moved
    // it, and it still asserts the same two things: the sketch and only the
    // sketch changes weight, and the sentence that matters stays at full
    // reading contrast — in the ledger's right-hand margin now.
    expect(find.text('LOCKED'), findsNothing);
    expect(
      tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(ActivityPanel),
              matching: find.byType(Opacity),
            ),
          )
          .where((Opacity o) => o.opacity == 0.55),
      isEmpty,
      reason: 'no locked entry is dimmed any more',
    );
    expect(
      find.descendant(
        of: find.byType(ActivityPanel),
        matching: find.byType(ColorFiltered),
      ),
      findsNWidgets(3),
      reason: 'three locked entries, three pencilled sketches',
    );
    await select(tester, 'Duskcap Grove');

    // The button is disabled and says exactly why — no modal.
    final StrideButton button = gatherButton(tester);
    expect(button.onPressed, isNull);
    expect(button.subLabel, 'Requires Foraging 3 — you are 1');

    // No gate chip any more: a locked activity used to state its
    // requirement three times — row sub-line, chip, button sub-label — and
    // the button's sentence is the one beside the action, so it is the one
    // that stays (Fable V2 UX audit S3).
    expect(gates(tester), isEmpty);

    // The quantity presets are dead: tapping ×5 must not change the offer.
    final Finder preset = find.descendant(
      of: find.byType(ActivityDetail),
      matching: find.text('×5'),
    );
    await tester.ensureVisible(preset);
    await tester.pump();
    await tester.tap(preset);
    await tester.pump();
    expect(gatherButton(tester).label, 'Gather ×1 — 130 steps');
    expect(find.textContaining('1 × 130 = 130 steps'), findsOneWidget);
  });

  testWidgets('missing required tool: controls disabled, equip reason, '
      'unmet tool gate', (WidgetTester tester) async {
    await pumpApp(tester, steps: 2000, atWoods: true);

    await select(tester, 'Oak Stand');

    final StrideButton button = gatherButton(tester);
    expect(button.onPressed, isNull);
    expect(button.subLabel, 'Equip a axe first');

    // Skill is met (Oak Stand asks Woodcutting 1) and is not restated, and
    // the tool gate lives on the button's own sentence (S3 — no chip).
    expect(gates(tester), isEmpty);

    // The stepper is dead too.
    final Finder plus = find.descendant(
      of: find.byType(ActivityDetail),
      matching: find.text('+'),
    );
    await tester.ensureVisible(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(gatherButton(tester).label, 'Gather ×1 — 120 steps');
  });

  testWidgets('eligible: controls enabled exactly as today', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, steps: 500);

    await select(tester, 'Meadow Patch');

    final StrideButton button = gatherButton(tester);
    expect(button.onPressed, isNotNull);
    expect(button.subLabel, isNull);

    // Nothing gates, so no gate chips render — the row's sub-line already
    // stated the met requirement.
    expect(gates(tester), isEmpty);

    // The presets still work: ×5 re-quotes the button.
    final Finder preset = find.descendant(
      of: find.byType(ActivityDetail),
      matching: find.text('×5'),
    );
    await tester.ensureVisible(preset);
    await tester.pump();
    await tester.tap(preset);
    await tester.pump();
    expect(gatherButton(tester).label, 'Gather ×5 — 400 steps');
  });

  test('the session projection mirrors the engine: unmet skill, unmet tool, '
      'and a met node', () async {
    final StrideSession s = await fundedSession(2000);
    final TravelReport t = await s.travel(woods);
    expect(t.succeeded, isTrue, reason: '${t.rejection}: ${t.detail}');

    final GatherEligibility grove = s.gatherEligibilityOf(duskcapGrove);
    expect(grove.skillMet, isFalse);
    expect(grove.requiredLevel, 3);
    expect(grove.currentLevel, 1);
    expect(grove.toolMet, isTrue);
    expect(grove.eligible, isFalse);

    final GatherEligibility oak = s.gatherEligibilityOf(oakStand);
    expect(oak.skillMet, isTrue);
    expect(oak.toolMet, isFalse, reason: 'no axe is equipped');
    expect(oak.eligible, isFalse);

    final GatherEligibility meadow = s.gatherEligibilityOf(meadowPatch);
    expect(meadow.skillMet, isTrue);
    expect(meadow.toolMet, isTrue);
    expect(meadow.eligible, isTrue);
  });

  test('domain defense: dispatching the gather anyway is refused with zero '
      'steps spent, zero XP, zero resources', () async {
    final StrideSession s = await fundedSession(2000);
    final TravelReport t = await s.travel(woods);
    expect(t.succeeded, isTrue, reason: '${t.rejection}: ${t.detail}');

    // Exact figures before: the travel spent 500 and nothing else moved.
    expect(s.totalSpent, 500);
    expect(s.usableEnergy, 1500);
    expect(s.inventoryCount(duskcap), 0);
    expect(s.inventoryCount(oakLog), 0);
    int foragingXp() => s.skillSummaries
        .singleWhere((SkillSummary k) => k.id == foraging)
        .experience;
    expect(foragingXp(), 0);

    // Skill too low: the engine refuses, whatever the UI would have allowed.
    final ActionReport grove = await s.gather(duskcapGrove);
    expect(grove.succeeded, isFalse);
    expect(grove.rejection, 'skill_level_too_low');

    // Tool missing: same authority, different rule.
    final ActionReport oak = await s.gather(oakStand);
    expect(oak.succeeded, isFalse);
    expect(oak.rejection, 'tool_required');

    // Exact figures after: identical. Nothing spent, granted, or gathered.
    expect(s.totalSpent, 500);
    expect(s.usableEnergy, 1500);
    expect(s.inventoryCount(duskcap), 0);
    expect(s.inventoryCount(oakLog), 0);
    expect(foragingXp(), 0);
  });
}
