/// Combat Slice 01 — the product UI's integration with the combat commands.
///
/// `test/combat_session_test.dart` proves the session; this file covers the
/// new surface only, and each case names the defect it catches: an encounter
/// card where content has no enemy, a combat screen that does not follow the
/// committed figures, a result that vanishes before it is read, and a
/// Character block that does not follow the loadout.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

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
  setUp(() => root = Directory.systemTemp.createTempSync('stride_combat_ui'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// Boots inside `runAsync` (real file I/O never completes under
  /// `FakeAsync`), funded with [steps] and, when [atWoods], already standing
  /// in the Whispering Woods wearing the starting sword and tunic.
  Future<StrideSession> boot(
    WidgetTester tester, {
    int steps = 5000,
    bool atWoods = false,
  }) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Unmount before the framework checks for pending work, so a live result
    // timer is disposed with the controller.
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    return (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(steps)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      if (atWoods) {
        await s.equip(trainingSword);
        await s.equip(tunic);
        final TravelReport t = await s.travel(woods);
        expect(t.succeeded, isTrue, reason: '${t.rejection}');
      }
      return s;
    }))!;
  }

  Future<void> show(WidgetTester tester, StrideSession session) async {
    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
  }

  SessionController controller() {
    final Element scope = find.byType(SessionScope).evaluate().first;
    return (scope.widget as SessionScope).notifier!;
  }

  /// Taps and waits for the controller to leave its busy state.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    for (int i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      if (!controller().busy && i > 0) break;
    }
    expect(controller().busy, isFalse, reason: 'the command never returned');
  }

  testWidgets('the encounter card is where the content puts the enemy', (
    WidgetTester tester,
  ) async {
    // Haven's Rest: no enemy, no card — not even a disabled one.
    final StrideSession home = await boot(tester);
    await show(tester, home);
    expect(find.text('Start Combat'), findsNothing);
    expect(find.text('Forest Wolf'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    // The Woods: the wolf's card, from content, with its figures and no cost.
    final StrideSession woodsSession = await boot(tester, atWoods: true);
    await show(tester, woodsSession);
    expect(find.text('Forest Wolf'), findsOneWidget);
    // The creature is present before the fight: its combat idle art on the
    // card, beside the gather stage's own figures.
    expect(
      tester
          .widgetList<GroundedSprite>(find.byType(GroundedSprite))
          .where((GroundedSprite g) => g.assetPath.contains('wolf_idle')),
      hasLength(1),
    );
    expect(find.text('Roams here'), findsOneWidget);
    expect(find.text('TWO LIGHT STRIKES A TURN'), findsOneWidget);
    expect(find.text('Rewards: 30 XP, Meadow Herb, Wolf Pelt'), findsOneWidget);
    final Finder start = find.widgetWithText(StrideButton, 'Start Combat');
    expect(start, findsOneWidget);
    expect((tester.widget(start) as StrideButton).onPressed, isNotNull);
    // An available enemy now says how much of the visit is left, rather than
    // nothing (`DECISIONS/0021` §1).
    expect(
      (tester.widget(start) as StrideButton).subLabel,
      '2 of 2 this visit',
    );
  });

  testWidgets('Start Combat opens the fight, Attack follows the commit, and '
      'the outcome waits to be acknowledged', (WidgetTester tester) async {
    final StrideSession s = await boot(tester, atWoods: true);
    await show(tester, s);

    await tapAndSettle(
      tester,
      find.widgetWithText(StrideButton, 'Start Combat'),
    );
    expect(s.encounter, isNotNull);
    // The stage replaced the cards: the enemy and the Traveler at full HP,
    // turn 1, and the three controls.
    expect(find.text('Start Combat'), findsNothing);
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.text('40 / 40'), findsOneWidget);
    expect(find.text('TURN 1'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Attack'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Eat'), findsOneWidget);
    expect(
      find.widgetWithText(StrideButton, 'Retreat — nothing is lost'),
      findsOneWidget,
    );
    // Nothing to eat: the button is disabled and says so.
    expect(
      (tester.widget(find.widgetWithText(StrideButton, 'Eat')) as StrideButton)
          .onPressed,
      isNull,
    );
    expect(find.text('Nothing to eat'), findsOneWidget);

    await tapAndSettle(tester, find.widgetWithText(StrideButton, 'Attack'));
    final EncounterView v = s.encounter!;
    expect(v.turn, 2);
    expect(find.text('TURN 2'), findsOneWidget);
    expect(find.text('${v.enemyHp} / 20'), findsOneWidget);
    expect(find.text('${v.playerHp} / 40'), findsOneWidget);
    expect(find.text('20 / 20'), findsNothing, reason: 'the wolf was hit');
    // The log narrates the round from the report, not from state.
    expect(find.textContaining('You strike for'), findsOneWidget);
    expect(find.textContaining('Forest Wolf strikes for'), findsNWidgets(2));

    // Fight on through the controller until it resolves.
    final SessionController c = controller();
    await tester.runAsync(() async {
      for (int i = 0; i < 60 && s.encounter != null; i++) {
        await c.combatAttack();
      }
    });
    await tester.pumpAndSettle();
    expect(s.encounter, isNull);
    expect(c.lastCombat?.outcome, isA<WonBeat>());

    // The result panel stands until acknowledged — the cards do not return
    // on their own, because the encounter cleared on the winning commit.
    expect(find.text('VICTORY'), findsOneWidget);
    // The panel itemises: the fall, the experience on its own ground under
    // its own label, and one framed row per drop (the log keeps its one-line
    // form). `test/rarity_ui_test.dart` owns the row's anatomy.
    expect(find.text('Forest Wolf falls.'), findsOneWidget);
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('+30 XP'), findsOneWidget);
    expect(find.text('REWARDS'), findsOneWidget);
    expect(find.text('Meadow Herb'), findsOneWidget);
    // The drops are rows now, not a `Drops: …` sentence.
    expect(find.textContaining('Drops:'), findsNothing);
    // The stage stays up behind the panel with the wolf felled and the
    // controls gone.
    expect(find.text('0 / 20'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Attack'), findsNothing);
    expect(find.text('Start Combat'), findsNothing);
    await tester.tap(find.widgetWithText(StrideButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(c.lastCombat, isNull);

    // Back at the location, one of the visit's two fights is spent: the card
    // counts down and stays enabled (`DECISIONS/0021` §1).
    Finder start = find.widgetWithText(StrideButton, 'Start Combat');
    expect(start, findsOneWidget);
    expect((tester.widget(start) as StrideButton).onPressed, isNotNull);
    expect(find.text('1 of 2 this visit'), findsOneWidget);

    // Take the second one, and the card closes with the unchanged words.
    await tapAndSettle(tester, start);
    await tester.runAsync(() async {
      for (int i = 0; i < 60 && s.encounter != null; i++) {
        await c.combatAttack();
      }
    });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(StrideButton, 'Continue'));
    await tester.pumpAndSettle();

    start = find.widgetWithText(StrideButton, 'Start Combat');
    expect(start, findsOneWidget);
    expect((tester.widget(start) as StrideButton).onPressed, isNull);
    expect(find.text('Driven off — returns after you travel'), findsOneWidget);
  });

  testWidgets('the Character screen shows the combat figures and follows the '
      'loadout', (WidgetTester tester) async {
    final StrideSession s = await boot(tester);
    await show(tester, s);
    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();

    expect(find.text('COMBAT'), findsOneWidget);
    expect(find.text('unarmed'), findsOneWidget);
    expect(find.text('no armour'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget, reason: 'XP to level 2');
    final CombatFigures before = s.combatFigures;
    expect(before.attack, 1);

    await tester.runAsync(() => s.equip(trainingSword));
    // Nothing is cached: a rebuild reads the new loadout.
    controller().notifyListeners();
    await tester.pumpAndSettle();
    expect(s.combatFigures.attack, 3);
    expect(find.text('unarmed'), findsNothing);
    expect(find.text('Training Sword'), findsOneWidget);
  });
}
