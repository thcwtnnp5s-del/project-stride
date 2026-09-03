/// Combat Slice 01 — the product UI's integration with the combat commands.
///
/// `test/combat_session_test.dart` proves the session; this file covers the
/// new surface only, and each case names the defect it catches: an encounter
/// card where content has no enemy, a combat screen that does not follow the
/// committed figures, a result that vanishes before it is read, and a
/// Character block that does not follow the loadout.
library;

import 'dart:io';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/screens/adventure/encounter_card.dart';
import 'package:stride/ui/screens/combat/combat_stage.dart';
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

/// The tap target around one command's word on the rail.
///
/// EPO03 replaced the 2 × 2 grid of `StrideButton`s with `_CommandPlate` — a
/// private widget, because a 64 dp stacked plate is not the product's general
/// button and `StrideButton` is NAV-owned. The plate wraps its content in one
/// `GestureDetector`, so this is the same assertion `onPressed == null` used
/// to be, one widget out.
GestureDetector command(WidgetTester tester, String label) =>
    tester.widget<GestureDetector>(
      find
          .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
          .first,
    );

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
    // The three commands are `_CommandPlate`s on the rail now, not
    // `StrideButton`s in a card (`DIR-11`), so they are found by the word
    // they carry; the tap target around it is the plate's own
    // `GestureDetector`, which is what [command] reads for enablement.
    expect(find.text('Attack'), findsOneWidget);
    expect(find.text('Eat'), findsOneWidget);
    expect(find.text('Retreat — nothing is lost'), findsOneWidget);
    // Provisioned with broths, but at full health on turn 1: the button is
    // disabled with the truthful reason — the same fact the engine would
    // refuse as `health_full` (`combat_session_test.dart`).
    expect(command(tester, 'Eat').onTap, isNull);
    expect(find.text('Health is full'), findsOneWidget);
    expect(find.text('Nothing to eat'), findsNothing);

    await tapAndSettle(tester, find.text('Attack'));
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
    // …and the rest of the round is one tap away, not gone: the tap opens
    // the same lines the block used to print, from the report and never from
    // state, naming each blow's quality from the event's own roll
    // (PLAYABLE_POLISH_01 §8).
    //
    // **Where they open changed with the chassis (EPO03).** The sill is 40 dp
    // and holds exactly one line, so the round no longer grows in place over
    // the picture — it resolves on the leather page beneath the fight, which
    // is the surface that used to be bare ground. The sill keeps its
    // headline while it does, so the flurry's two enemy strikes appear twice
    // in the opened round and once more on the sill: three, not two.
    await tapAndSettle(tester, enemyLine);
    expect(
      find.textContaining(
        RegExp(r'^(You strike|A strong hit|A glancing blow) for [0-9]+'),
      ),
      findsOneWidget,
    );
    expect(enemyLine, findsNWidgets(3));

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
    // command rail locked.
    //
    // Locked, not relabelled: the cells used to read "Fighting…" while held,
    // which on a rail of three plates is three identical words where three
    // verbs were, so the wait is stated once on the intent line and the plates
    // keep their names and lose their callbacks (`ART-12` §6). A null tap is
    // also the assertion that actually protects the player — a label cannot
    // dispatch a command.
    expect(find.text('0 / 20'), findsOneWidget);
    expect(find.text('Attack'), findsOneWidget);
    expect(command(tester, 'Attack').onTap, isNull);
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

  testWidgets('the fight outweighs the commands: 398 dp of chassis against a '
      '120 dp rail, and every plate is a whole plate', (
    WidgetTester tester,
  ) async {
    // **This test replaces "the command card fits its 210 dp budget."**
    //
    // That number was the right guard for the layout it guarded: `ART-12` §6
    // budgeted 210 dp for a command *card* and the build measured 219, and
    // holding that ceiling is what kept the card from growing back. EPO03
    // deletes the card. There is no longer a `SectionCard` under the stage to
    // measure, so the guard is re-pointed at the thing the owner actually
    // ruled on — "make the battlefield visually dominant; buttons should not
    // outweigh the fight" — and states it as the ratio it is.
    //
    // At 393 × 852 the host list gives the screen 727 − 28 = 699 dp:
    //
    //   chassis   398   19 frame · 64 lintel · 256 picture · 40 sill · 19
    //   intent     18
    //   page      163   leather, no card
    //   rail      120   12 welt · 64 plates · 44 Retreat
    //   ---------------
    //             699
    //
    // 398 : 120 is **3.3 : 1**, against about 1.2 : 1 on 4d9a81f. The
    // assertions below are the three figures a future change would have to
    // argue with rather than quietly spend: the chassis is at least half the
    // content column, the rail is at most a sixth and a bit, and the ratio
    // does not fall under three.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final double chassis = tester.getSize(find.byType(CombatStage)).height;
    // The stage publishes the figure it lays out; the two agree by
    // construction and this is the check that they do.
    expect(chassis, CombatStage.chassisHeight());
    expect(chassis, 398, reason: '19 + 64 + 256 + 40 + 19');

    // `_CommandRail` is private, so the rail is measured the way a player
    // finds it — from the stitched welt along its top edge to the bottom of
    // Retreat's own hit region.
    final Finder retreat = find.text('Retreat — nothing is lost');
    final Finder attack = find.text('Attack');
    expect(retreat, findsOneWidget);
    // The welt is 12 dp of `KitTile.navWelt` above the plate row — the same
    // stitch the nav strap and the header shelf wear, which is why it cannot
    // be found by type here: there are three of them on screen and they are
    // all correct.
    final double railTop =
        tester
            .getTopLeft(
              find.ancestor(of: attack, matching: find.byType(KitPlate)).first,
            )
            .dy -
        12;
    final double railBottom = tester
        .getBottomLeft(
          find.ancestor(of: retreat, matching: find.byType(GestureDetector)).first,
        )
        .dy;

    // The content column the two share, from the top of the chassis to the
    // bottom of the rail.
    final double chassisTop = tester.getTopLeft(find.byType(CombatStage)).dy;
    final double content = railBottom - chassisTop;
    expect(content, greaterThan(600));
    final double rail = railBottom - railTop;
    expect(rail, 120, reason: '12 welt + 64 plates + 44 Retreat');
    // The figures this run measures, held so a later change argues with them:
    // chassis 398 of a 699 dp column (57 %), rail 120 (17 %), and the rail's
    // top edge 652 dp down the 852 dp screen — the tab bar is what is under
    // it, not bare ground.
    expect(content, 699);
    expect(railTop, greaterThanOrEqualTo(560));

    expect(
      chassis / content,
      greaterThanOrEqualTo(0.50),
      reason: 'the fight is at least half the column it is fought in',
    );
    expect(
      rail / content,
      lessThanOrEqualTo(0.18),
      reason: 'the commands outgrew their sixth of the screen',
    );
    expect(
      chassis / rail,
      greaterThanOrEqualTo(3.0),
      reason: 'fight-to-rail fell under 3 : 1',
    );

    // Three plates, one row, equal, and each one well over the 44 dp floor in
    // both dimensions.
    final Size attackPlate = tester.getSize(
      find.ancestor(of: attack, matching: find.byType(KitPlate)).first,
    );
    expect(attackPlate.height, 64);
    expect(attackPlate.width, greaterThanOrEqualTo(44));
    for (final String other in <String>['Brace', 'Eat']) {
      expect(
        tester.getSize(
          find.ancestor(of: find.text(other), matching: find.byType(KitPlate)).first,
        ),
        attackPlate,
        reason: '$other is not the same plate as Attack',
      );
      expect(
        tester.getTopLeft(find.text(other)).dy,
        closeTo(tester.getTopLeft(attack).dy, 8),
        reason: '$other left the plate row',
      );
    }

    // **Q-22 closes here.** The three commands wore `plate_attack/brace/eat`
    // as centred ornaments — blobs on a transparent field with empty corners
    // and empty edge runs, three of them in three perspectives, one with a
    // checker ground baked in. They are gone from this screen; the plate is
    // `KitFrame.btnPlateV2`, a real nine-patch drawn through `PixelFrame`,
    // which paints four corners once and tiles four edges and can therefore
    // be any size without an edge appearing inside the cell.
    for (final String gone in <String>[
      CombatHudAssets.plateAttack,
      CombatHudAssets.plateBrace,
      CombatHudAssets.plateEat,
    ]) {
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is PixelAsset && w.assetPath == gone,
        ),
        findsNothing,
        reason: '$gone is a centred ornament and Q-22 retired it',
      );
    }

    // Retreat is never a plate, and its hit region still clears the floor.
    expect(
      find.ancestor(of: retreat, matching: find.byType(KitPlate)),
      findsNothing,
      reason: 'leaving is not one of the three things you do in a fight',
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(of: retreat, matching: find.byType(GestureDetector))
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );

    // Eat is disabled in this fixture — nothing edible — so it is also the
    // disabled case. The plate stays, dimmed (FMPO02 wave 3, FINAL-01 #1):
    // it used to vanish, and the result was cells that changed shape twice a
    // round. The glyph goes and the words that say why take its place.
    expect(command(tester, 'Eat').onTap, isNull);
    expect(find.text('Nothing to eat'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Eat'), matching: find.byType(KitPlate)).first,
        matching: find.byWidgetPredicate(
          (Widget w) => w is PixelAsset && w.assetPath == CombatHudAssets.iconEat,
        ),
      ),
      findsNothing,
      reason: 'the words that say why outrank the icon',
    );

    // The log block is gone from under the fight entirely, heading and all.
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

  testWidgets('the command emblems clear AA under their own labels', (
    WidgetTester tester,
  ) async {
    // FMPO02 wave 3, FINAL-10 #1: "Attack and Brace carry raster emblems
    // sitting behind and colliding with their own labels." The plate stays
    // behind the word — it is the cell's identity, and dropping it left four
    // rectangles of one size reading as four accidents — but it is now drawn
    // at `_emblemBehindText` over the control's own face rather than at full
    // strength over a hole.
    //
    // The measurement is of the shipped PNGs, not of a claim about them: each
    // plate's **brightest** pixel, composited at that opacity over the face
    // the button now paints, against the label ink. A re-roll with a hotter
    // core fails here rather than on a device.
    //
    // 4.5:1 is the same WCAG AA floor every readable surface in this app is
    // held to, and the same one the narration strip failed at 2.90 below.
    late final Map<String, double> worst;
    await tester.runAsync(() async {
      final Map<String, double> out = <String, double>{};
      for (final String path in <String>[
        CombatHudAssets.plateAttack,
        CombatHudAssets.plateBrace,
        CombatHudAssets.plateEat,
      ]) {
        final ByteData bytes = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final ui.Image image = (await codec.getNextFrame()).image;
        expect(image.width, CombatHudAssets.plateNativeWidth);
        expect(image.height, CombatHudAssets.plateNativeHeight);
        final ByteData px = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        double brightest = -1;
        for (int i = 0; i < px.lengthInBytes; i += 4) {
          // `rawRgba` is premultiplied, so the plate over the face is
          // `src + face × (1 − a)`; the ornament's own opacity multiplies
          // both the source and the alpha it hides the face with.
          final double a =
              (px.getUint8(i + 3) / 255) * StrideButton.emblemBehindText;
          double channel(int o, double faceChannel) =>
              px.getUint8(i + o) * StrideButton.emblemBehindText +
              faceChannel * 255 * (1 - a);
          final double l = _luminance(
            channel(0, StrideColors.surfaceRaised.r),
            channel(1, StrideColors.surfaceRaised.g),
            channel(2, StrideColors.surfaceRaised.b),
          );
          if (l > brightest) brightest = l;
        }
        out[path] = brightest;
        image.dispose();
        codec.dispose();
      }
      worst = out;
    });

    final double ink = _luminance(0xF0, 0xE7, 0xD8); // textPrimary
    for (final MapEntry<String, double> e in worst.entries) {
      expect(
        (ink + 0.05) / (e.value + 0.05),
        greaterThanOrEqualTo(4.5),
        reason:
            '${e.key} is too bright under its label: lower '
            '`_emblemBehindText` or re-author the plate darker',
      );
    }
  });

  testWidgets('the narration keeps its translucent fill: the authored '
      'parchment strip fails AA on the rows the type sits on', (
    WidgetTester tester,
  ) async {
    // `narration_strip.png` was authored for exactly this ground and is
    // packaged and unused. This is the measurement that decided it, held so
    // that a darker re-authored strip swaps in on a figure rather than on an
    // argument — and so that the *misleading* figure cannot be quoted at the
    // decision either.
    //
    // The whole-canvas mean passes AA and is the wrong number: nine of the
    // sixteen rows are fully transparent, so averaging them in measures the
    // stage showing through rather than the parchment a line of type sits on.
    late final List<double> luminance;
    await tester.runAsync(() async {
      final ByteData bytes = await rootBundle.load(
        CombatHudAssets.narrationStrip,
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
      );
      final ui.Image image = (await codec.getNextFrame()).image;
      expect(image.width, CombatHudAssets.narrationStripWidth);
      expect(image.height, CombatHudAssets.narrationStripHeight);
      final ByteData px = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      // Row means, each pixel composited over the stage's own ground. `rawRgba`
      // is premultiplied, so `src + ground × (1 − a)` is the composite, exactly.
      luminance = <double>[
        for (int y = 0; y < image.height; y++)
          () {
                double sum = 0;
                for (int x = 0; x < image.width; x++) {
                  final int i = (y * image.width + x) * 4;
                  final double a = px.getUint8(i + 3) / 255;
                  sum += _luminance(
                    px.getUint8(i) + StrideColors.surfaceGround.r * 255 * (1 - a),
                    px.getUint8(i + 1) +
                        StrideColors.surfaceGround.g * 255 * (1 - a),
                    px.getUint8(i + 2) +
                        StrideColors.surfaceGround.b * 255 * (1 - a),
                  );
                }
                return sum / image.width;
              }(),
      ];
      image.dispose();
      codec.dispose();
    });

    double meanOf(int from, int to) {
      double s = 0;
      for (int y = from; y <= to; y++) {
        s += luminance[y];
      }
      return s / (to - from + 1);
    }

    final double text = _luminance(0xF0, 0xE7, 0xD8);
    double contrast(double ground) => (text + 0.05) / (ground + 0.05);

    // The whole canvas: 5.32 : 1, and a pass — on nine rows of nothing.
    expect(contrast(meanOf(0, 15)), closeTo(5.32, 0.05));
    // The drawn body: 2.90 : 1. The rows a line of type actually crosses.
    expect(
      contrast(meanOf(4, 10)),
      closeTo(2.90, 0.05),
      reason: 'if this rose above 4.5 the strip may be drawn: swap the '
          'translucent fill in `_CombatLog` for the tiled parchment',
    );
    expect(contrast(meanOf(4, 10)), lessThan(4.5));
    // Its bright core is 1.85 : 1 — parchment as pale as the ink on it.
    expect(contrast(meanOf(6, 9)), closeTo(1.85, 0.05));
  });
}

/// sRGB relative luminance (WCAG 2.1), on 0..255 channels.
double _luminance(double r, double g, double b) {
  double c(double v) {
    final double s = v / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b);
}
