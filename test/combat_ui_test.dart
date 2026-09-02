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
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/screens/adventure/encounter_card.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId herbBrothRecipe = ContentId.unchecked('recipe.herb_broth');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');

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
  // Real type, because this file now asserts a layout budget in dp and the
  // harness's square fallback font measures the harness rather than the UI
  // (test/support/real_font.dart).
  setUpAll(loadRealFont);

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
    bool provisioned = false,
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
      if (provisioned) {
        // HP persists between fights (`DECISIONS/0023` §6): broths cooked at
        // Haven's meadow are what make a second fight winnable.
        for (int i = 0; i < 6; i++) {
          expect((await s.gather(meadowPatch)).succeeded, isTrue);
        }
        for (int i = 0; i < 3; i++) {
          expect((await s.craft(herbBrothRecipe)).succeeded, isTrue);
        }
      }
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

    // Compact rows, one open detail (§15). Nothing of the creature is drawn
    // until the row the player is considering is the open one — which is the
    // whole point of the change, so the test opens it the way a player does.
    expect(
      find.byType(EncounterCard),
      findsNothing,
      reason: 'no encounter is expanded until one is chosen',
    );
    await tapAndSettle(tester, find.text('Forest Wolf'));

    // The creature is present before the fight: its combat idle art in the
    // open row, beside the location stage's own figures.
    expect(
      tester
          .widgetList<GroundedSprite>(find.byType(GroundedSprite))
          .where((GroundedSprite g) => g.assetPath.contains('wolf_idle')),
      hasLength(1),
    );
    // Three enemies roam the woods now (Exploration & Progression Loop 01):
    // the wolf, the boar and the bear each get a row, and only one of them
    // is expanded.
    expect(find.text('Wild Boar'), findsOneWidget);
    expect(find.text('Oakback Bear'), findsOneWidget);
    expect(find.byType(EncounterCard), findsOneWidget);

    expect(find.text('Roams here'), findsOneWidget);
    expect(find.text('TWO LIGHT STRIKES A TURN'), findsOneWidget);
    // The signature fang exists but is concealed until the wolf is Known.
    // The reward block is the §24 ecology presentation: XP on its own line,
    // each known drop named in its rarity's ink under KNOWN DROPS, and the
    // unrevealed signature as `???`.
    final Finder wolfCard = find.ancestor(
      of: find.text('Forest Wolf'),
      matching: find.byType(EncounterCard),
    );
    expect(
      find.descendant(of: wolfCard, matching: find.text('+30 XP')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: wolfCard, matching: find.text('KNOWN DROPS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: wolfCard, matching: find.text('Wolf Pelt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: wolfCard, matching: find.text('???')),
      findsOneWidget,
      reason: 'the signature fang stays concealed until Known',
    );
    final Finder start = find.descendant(
      of: find.ancestor(
        of: find.text('Forest Wolf'),
        matching: find.byType(EncounterCard),
      ),
      matching: find.widgetWithText(StrideButton, 'Start Combat'),
    );
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
    final StrideSession s = await boot(tester, atWoods: true, provisioned: true);
    await show(tester, s);

    // Open the wolf's row, then start the fight from its detail (§15).
    await tapAndSettle(tester, find.text('Forest Wolf'));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('Forest Wolf'),
          matching: find.byType(EncounterCard),
        ),
        matching: find.widgetWithText(StrideButton, 'Start Combat'),
      ),
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
    // Provisioned with broths, but at full health on turn 1: the button is
    // disabled with the truthful reason — the same fact the engine would
    // refuse as `health_full` (`combat_session_test.dart`).
    expect(
      (tester.widget(find.widgetWithText(StrideButton, 'Eat')) as StrideButton)
          .onPressed,
      isNull,
    );
    expect(find.text('Health is full'), findsOneWidget);
    expect(find.text('Nothing to eat'), findsNothing);

    await tapAndSettle(tester, find.widgetWithText(StrideButton, 'Attack'));
    final EncounterView v = s.encounter!;
    expect(v.turn, 2);
    expect(find.text('TURN 2'), findsOneWidget);
    expect(find.text('${v.enemyHp} / 20'), findsOneWidget);
    expect(find.text('${v.playerHp} / 40'), findsOneWidget);
    expect(find.text('20 / 20'), findsNothing, reason: 'the wolf was hit');
    // The narration is one line now, on the stage's own bottom edge
    // (`ART-09` §4) — the most recent beat of the round, which against a
    // flurry is the wolf's second strike.
    final Finder enemyLine = find.textContaining(
      RegExp(r'^Forest Wolf (strikes|hits hard|grazes you) for [0-9]+'),
    );
    expect(enemyLine, findsOneWidget);
    // …and the rest of the round is one tap away, not gone: the strip opens
    // to the same lines the block used to print, from the report and never
    // from state, naming each blow's quality from the event's own roll
    // (PLAYABLE_POLISH_01 §8).
    await tapAndSettle(tester, enemyLine);
    expect(
      find.textContaining(
        RegExp(r'^(You strike|A strong hit|A glancing blow) for [0-9]+'),
      ),
      findsOneWidget,
    );
    expect(enemyLine, findsNWidgets(2));

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
    expect(find.text('Forest Wolf falls'), findsOneWidget);
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('+30 XP'), findsOneWidget);
    // Drops are chance-rolled now (Exploration & Progression Loop 01), so the
    // panel is checked against what the committed outcome actually awarded.
    final WonBeat wonOutcome = c.lastCombat!.outcome as WonBeat;
    if (wonOutcome.drops.isNotEmpty) {
      expect(find.text('REWARDS'), findsOneWidget);
      for (final RewardLine drop in wonOutcome.drops) {
        expect(find.text(drop.name), findsWidgets, reason: drop.name);
      }
    }
    // The drops are rows now, not a `Drops: …` sentence.
    expect(find.textContaining('Drops:'), findsNothing);
    // The stage stays up behind the panel with the wolf felled and the
    // command grid locked.
    //
    // Locked, not relabelled: the cells used to read "Fighting…" while held,
    // which in a 2 × 2 grid is four identical words where three verbs were,
    // so the wait is stated once on the intent line and the cells keep their
    // names and lose their callbacks (`ART-12` §6). `onPressed == null` is
    // also the assertion that actually protects the player — a label cannot
    // dispatch a command.
    expect(find.text('0 / 20'), findsOneWidget);
    final Finder attack = find.widgetWithText(StrideButton, 'Attack');
    expect(attack, findsOneWidget);
    expect((tester.widget(attack) as StrideButton).onPressed, isNull);
    expect(find.text('Fighting…'), findsOneWidget);
    expect(find.text('Start Combat'), findsNothing);
    await tester.tap(find.widgetWithText(StrideButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(c.lastCombat, isNull);

    // Back at the location, one of the visit's two fights is spent: the card
    // counts down and stays enabled (`DECISIONS/0021` §1).
    Finder start = find.descendant(
      of: find.ancestor(
        of: find.text('Forest Wolf'),
        matching: find.byType(EncounterCard),
      ),
      matching: find.widgetWithText(StrideButton, 'Start Combat'),
    );
    expect(start, findsOneWidget);
    expect((tester.widget(start) as StrideButton).onPressed, isNotNull);
    expect(find.text('1 of 2 this visit'), findsOneWidget);

    // HP persisted through the first fight; eat the provisioned broths back
    // to full before the rematch (`DECISIONS/0023` §6).
    await tester.runAsync(() async {
      while (s.playerHp < s.playerMaxHp && s.inventoryCount(herbBroth) > 0) {
        final FoodReport bite = await s.eatFood(herbBroth);
        expect(bite.succeeded, isTrue, reason: '${bite.rejection}');
      }
    });
    await tester.pumpAndSettle();

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

    start = find.descendant(
      of: find.ancestor(
        of: find.text('Forest Wolf'),
        matching: find.byType(EncounterCard),
      ),
      matching: find.widgetWithText(StrideButton, 'Start Combat'),
    );
    expect(start, findsOneWidget);
    expect((tester.widget(start) as StrideButton).onPressed, isNull);
    expect(find.text('Driven off — returns after you travel'), findsOneWidget);
  });

  testWidgets('the command card fits its 210 dp budget and the grid is 2 × 2', (
    WidgetTester tester,
  ) async {
    // The owner's verdict on 4d9a81f: "the giant lower command frame
    // dominates the fight." It was four full-width buttons, a log block and a
    // heading — about 276 dp of an 852 dp screen. `ART-12_ux_brief.md` §6
    // budgets 210 for the whole card and gives the rest back to the stage;
    // this is the number that keeps it given back.
    final StrideSession s = await boot(tester, atWoods: true);
    await show(tester, s);
    await tapAndSettle(tester, find.text('Forest Wolf'));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('Forest Wolf'),
          matching: find.byType(EncounterCard),
        ),
        matching: find.widgetWithText(StrideButton, 'Start Combat'),
      ),
    );

    final Finder attack = find.widgetWithText(StrideButton, 'Attack');
    final Finder brace = find.widgetWithText(StrideButton, 'Brace');
    final Finder eat = find.widgetWithText(StrideButton, 'Eat');
    final Finder card = find
        .ancestor(of: attack, matching: find.byType(SectionCard))
        .first;
    // The measured card is **219**, against the brief's 210, and the 9 dp are
    // two terms §6's arithmetic left out rather than anything this build
    // added. Stated in full so the next reader argues with the sum instead of
    // rediscovering it:
    //
    //   card padding      12
    //   intent line       13   (§6 allowed 16 for one `micro` line; it is 13)
    //   gap                8
    //   Attack / Brace    56
    //   gap                8
    //   Eat / (empty)     56
    //   gap                8
    //   Retreat           44   (§6 budgeted its 34 dp *visual*; the widget is
    //                           its 44 dp hit region, which is the floor and
    //                           is not negotiable)
    //   card padding      12
    //   card border        2   (`SectionCard`'s own 1 px, top and bottom)
    //   ---------------------
    //                    219
    //
    // Against ~276 before, with the log block and its heading gone from the
    // card entirely. The ceiling is asserted at 220 — one dp of slack, so a
    // rounding change is not a failure and a new row is.
    expect(
      tester.getSize(card).height,
      lessThanOrEqualTo(220),
      reason: 'the command card outgrew its budget',
    );

    // 2 × 2: Attack and Brace share a row, Eat opens the next one, and the
    // fourth place is empty because the fight has no fourth action.
    final Size attackSize = tester.getSize(attack);
    expect(attackSize.height, 56);
    expect(tester.getSize(brace), attackSize);
    expect(tester.getSize(eat), attackSize);
    expect(tester.getTopLeft(attack).dy, tester.getTopLeft(brace).dy);
    expect(tester.getTopLeft(attack).dx, tester.getTopLeft(eat).dx);
    expect(tester.getTopLeft(eat).dy, greaterThan(tester.getTopLeft(brace).dy));
    // 163.5, not §6's 176: (361 − 2 border − 24 card padding − 8 gap) / 2. The
    // brief measured the grid against the screen's content width and did not
    // subtract the card the grid sits inside. Every cell is still three times
    // the 44 dp floor in both dimensions.
    expect(attackSize.width, 163.5);
    // Retreat's own hit region clears the floor too — 34 dp of visual inside
    // 44, the pattern `StrideButton.secondary` already implements.
    final Finder retreat = find.widgetWithText(
      StrideButton,
      'Retreat — nothing is lost',
    );
    expect(tester.getSize(retreat).height, greaterThanOrEqualTo(44));
    // The log block is gone from the card entirely: its heading with it.
    expect(find.text('This round'), findsNothing);
  });

  testWidgets('the Character screen shows the combat figures and follows the '
      'loadout', (WidgetTester tester) async {
    final StrideSession s = await boot(tester);
    await show(tester, s);
    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();

    // The Combat card sits below the fold since the Steps card joined the
    // sheet (the physical-device polish pass); the list builds lazily, so
    // scroll it into being before asserting on it.
    await tester.scrollUntilVisible(
      find.text('COMBAT'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
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
