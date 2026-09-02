/// The encounter card's enemy presence — the creature visible before Start
/// Combat (`ACTIVITY_FEEL_PRESENTATION_01` §1.3).
///
/// `combat_ui_test.dart` proves the card arrives from content on the real
/// Adventure tab; this file proves the card's own anatomy against hand-built
/// options and a real session: the idle art on its band, the scale rule, the
/// bounded visit that still lets the suite settle, reduced motion, and the
/// clean fallback for an enemy the art table does not know.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/icons/encounter_habitat.dart';
import 'package:stride/ui/screens/adventure/encounter_card.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart'
    show MockStepSource, SyncFetch;

EncounterOption option({
  String enemy = 'enemy.forest_wolf',
  String name = 'Forest Wolf',
  bool boss = false,
  EnemyBehavior behavior = EnemyBehavior.flurry,
  int remaining = 2,
  KnowledgeTier knowledge = KnowledgeTier.unseen,
  int dropChance = 0,
}) => EncounterOption(
  enemyId: ContentId.unchecked(enemy),
  name: name,
  isBoss: boss,
  behavior: behavior,
  maxHealth: 20,
  attack: 4,
  defence: 1,
  xp: 30,
  drops: <DropPreview>[
    DropPreview(
      id: ContentId.unchecked('item.meadow_herb'),
      name: 'Meadow Herb',
      rarity: Rarity.common,
      chancePercent: dropChance,
    ),
  ],
  encountersPerVisit: 2,
  remainingThisVisit: remaining,
  available: remaining > 0,
  reason: remaining > 0 ? null : 'enemy_driven_off',
  knowledge: knowledge,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('stride_encounter_card'),
  );
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// The card needs a live controller for `busy` and the button's dispatch;
  /// a minimal real session provides one (the concrete types have no seams).
  Future<SessionController> boot(WidgetTester tester) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final StrideSession s = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: <SyncFetch>[]),
      ),
    ))!;
    final SessionController c = SessionController(s);
    addTearDown(c.dispose);
    return c;
  }

  Widget shell(
    SessionController c,
    EncounterOption o, {
    bool reduceMotion = false,
  }) => MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      disableAnimations: reduceMotion,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SessionScope(
        controller: c,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 361, child: EncounterCard(option: o)),
        ),
      ),
    ),
  );

  String enemySprite(WidgetTester tester) =>
      tester.widget<GroundedSprite>(find.byType(GroundedSprite)).assetPath;

  testWidgets('the wolf card shows the creature on its band, idling for a '
      'bounded visit, above the unchanged facts', (WidgetTester tester) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, option()));
    await tester.pump();

    // The presence: the combat idle art, grounded, at the combat scale.
    final GroundedSprite sprite = tester.widget<GroundedSprite>(
      find.byType(GroundedSprite),
    );
    expect(sprite.assetPath, contains('wolf_idle'));
    expect(sprite.scale, 2);
    expect(sprite.canvas, 56);

    // Everything the card already said, still said.
    expect(find.text('Forest Wolf'), findsOneWidget);
    expect(find.text('Roams here'), findsOneWidget);
    expect(find.text('HEALTH'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('DEFENCE'), findsOneWidget);
    // The reward preview, restructured by PRESENTATION_WORLD_REWARD_FEEL_01
    // §24: the XP on its own line and each known drop in its rarity's ink
    // under a KNOWN DROPS heading, so the card reads as what studying the
    // creature has taught rather than as one run-on sentence.
    expect(find.text('+30 XP'), findsOneWidget);
    expect(find.text('KNOWN DROPS'), findsOneWidget);
    expect(find.text('Meadow Herb'), findsOneWidget);
    final StrideButton start = tester.widget(
      find.widgetWithText(StrideButton, 'Start Combat'),
    );
    expect(start.onPressed, isNotNull);
    expect(start.subLabel, '2 of 2 this visit');

    // The idle moves during the visit…
    final String at0 = enemySprite(tester);
    bool moved = false;
    for (int i = 0; i < 10 && !moved; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      moved = enemySprite(tester) != at0;
    }
    expect(moved, isTrue, reason: 'the idle track never advanced');

    // …and the visit is bounded: the suite settles, on the first frame.
    await tester.pumpAndSettle();
    expect(enemySprite(tester), endsWith('wolf_idle_f0.png'));
  });

  testWidgets('the guardian takes the band at the combat stage scale', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(
      shell(
        c,
        option(
          enemy: 'enemy.hollow_guardian',
          name: 'Hollow Guardian',
          boss: true,
          behavior: EnemyBehavior.guarded,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final GroundedSprite sprite = tester.widget<GroundedSprite>(
      find.byType(GroundedSprite),
    );
    expect(sprite.assetPath, contains('guardian_idle'));
    // Was ×1, on the reasoning that a 96 canvas at ×2 would need a 200 dp
    // band. That measured the canvas; a combat canvas is mostly empty, and
    // `guardian_idle`'s content is 71 rows, needing 150. See below for why
    // the reasoning mattered rather than just the number.
    expect(sprite.scale, 2);
    expect(sprite.canvas, 96);
    expect(find.text('Hollow Guardian'), findsOneWidget);
    expect(find.text('BOSS'), findsOneWidget);
  });

  testWidgets('a larger creature is never drawn smaller than a smaller one', (
    WidgetTester tester,
  ) async {
    // The property the old rule broke, and the reason this test exists rather
    // than an assertion about any one creature's scale.
    //
    // Demoting the big canvases to ×1 inverted the roster: measured content
    // heights are wolf 29 rows, crawler 33, salamander 46, bear 50, guardian
    // 71 — but the player saw the bear at 50 dp against the wolf's 58, and the
    // boss guardian at 71 against the salamander's 92. The card told them the
    // bear was the smallest thing in the game.
    //
    // One scale for the whole roster is what makes that unrepresentable: with
    // a single multiplier, drawn order *is* authored order, and no future
    // creature can re-break it by being large.
    final SessionController c = await boot(tester);

    final Map<String, int> scales = <String, int>{};
    for (final (String id, String name) in <(String, String)>[
      ('enemy.grey_wolf', 'Grey Wolf'),
      ('enemy.scree_crawler', 'Scree Crawler'),
      ('enemy.ember_salamander', 'Ember Salamander'),
      ('enemy.oakback_bear', 'Oakback Bear'),
      ('enemy.hollow_guardian', 'Hollow Guardian'),
    ]) {
      await tester.pumpWidget(shell(c, option(enemy: id, name: name)));
      await tester.pumpAndSettle();
      final Finder f = find.byType(GroundedSprite);
      if (f.evaluate().isEmpty) continue; // an enemy with no art table entry
      scales[id] = tester.widget<GroundedSprite>(f).scale;
    }

    expect(scales, isNotEmpty);
    expect(
      scales.values.toSet(),
      hasLength(1),
      reason:
          'Enemies are drawn at more than one scale, so the card no longer '
          'reports relative size honestly: $scales',
    );
  });

  testWidgets('an enemy the art table does not know renders the card exactly '
      'as before — no strip, no empty box, no crash', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(
      shell(c, option(enemy: 'enemy.unknown_beast', name: 'Unknown Beast')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroundedSprite), findsNothing);
    expect(find.text('Unknown Beast'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Start Combat'), findsOneWidget);
    expect(find.text('2 of 2 this visit'), findsOneWidget);
  });

  testWidgets('reduced motion holds the first frame throughout', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, option(), reduceMotion: true));
    await tester.pump();
    expect(enemySprite(tester), endsWith('wolf_idle_f0.png'));
    await tester.pump(const Duration(seconds: 2));
    expect(enemySprite(tester), endsWith('wolf_idle_f0.png'));
    // Nothing is scheduled: it settles immediately.
    await tester.pumpAndSettle();
  });

  testWidgets('drop chances graduate by knowledge: nothing below Studied, a '
      'frequency word at Studied, the figure at Known', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);

    // Seen: the drop's name alone — the chance has not been earned.
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.seen, dropChance: 65)),
    );
    await tester.pump();
    expect(find.text('Meadow Herb'), findsOneWidget);
    expect(find.textContaining('usually'), findsNothing);
    expect(find.textContaining('%'), findsNothing);

    // Studied: a frequency word, banded by the authored chance.
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.studied, dropChance: 65)),
    );
    await tester.pump();
    expect(find.text(' · usually'), findsOneWidget);
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.studied, dropChance: 30)),
    );
    await tester.pump();
    expect(find.text(' · often'), findsOneWidget);
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.studied, dropChance: 10)),
    );
    await tester.pump();
    expect(find.text(' · rarely'), findsOneWidget);

    // Known: the exact figure the engine rolls.
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.known, dropChance: 65)),
    );
    await tester.pump();
    expect(find.text(' · 65%'), findsOneWidget);

    // A zero chance says nothing at any tier — no invented figure.
    await tester.pumpWidget(
      shell(c, option(knowledge: KnowledgeTier.known, dropChance: 0)),
    );
    await tester.pump();
    expect(find.textContaining('%'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a spent visit still renders the disabled card with its art', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, option(remaining: 0)));
    await tester.pumpAndSettle();
    expect(find.byType(GroundedSprite), findsOneWidget);
    final StrideButton start = tester.widget(
      find.widgetWithText(StrideButton, 'Start Combat'),
    );
    expect(start.onPressed, isNull);
    expect(start.subLabel, 'Driven off — returns after you travel');
  });

  /// The band the creature stands on, measured on screen.
  double bandHeight(WidgetTester tester) => tester
      .getSize(
        find
            .ancestor(
              of: find.byType(GroundedSprite),
              matching: find.byType(Container),
            )
            .first,
      )
      .height;

  testWidgets('the band is the creature\'s own size, not one constant — the '
      'empty box the owner named', (WidgetTester tester) async {
    // The defect: "a small wolf in a giant blank rectangle". Every band was
    // 152 dp because the guardian needs 152, so the wolf — 29 rows of content
    // — sat under 82 dp of nothing. The height is derived now
    // (`ART-12_ux_brief.md` §7), and the roster's ordering, which is the one
    // thing the band exists to say, is preserved by construction.
    final SessionController c = await boot(tester);
    final Map<String, double> bands = <String, double>{};
    // The test boots at Haven's Rest, which has no habitat plate, so every
    // band here is the derived height — except the salamander, whose plate is
    // keyed by species (Q-21) and follows it anywhere: a plate *is* the
    // ground, so its band is the plate's own 152.
    for (final (String id, String name, double expected)
        in <(String, String, double)>[
          ('enemy.forest_wolf', 'Forest Wolf', 76), // 29 rows, at the floor
          ('enemy.scree_crawler', 'Scree Crawler', 82),
          ('enemy.oakback_bear', 'Oakback Bear', 112),
          ('enemy.hollow_guardian', 'Hollow Guardian', 152), // at the ceiling
          ('enemy.salamander', 'Salamander', 152), // plated by species
        ]) {
      await tester.pumpWidget(shell(c, option(enemy: id, name: name)));
      await tester.pumpAndSettle();
      expect(bandHeight(tester), expected, reason: id);
      bands[id] = expected;
      // Nothing clips: the figure, drawn at ×2 from its own ground line,
      // still fits inside the band it was measured for.
      final GroundedSprite g = tester.widget<GroundedSprite>(
        find.byType(GroundedSprite),
      );
      expect(g.scale, 2, reason: 'one scale for the roster, still');
    }
    final List<double> ordered = bands.values.toList();
    for (int i = 1; i < ordered.length; i++) {
      expect(
        ordered[i],
        greaterThanOrEqualTo(ordered[i - 1]),
        reason: 'a larger creature took a smaller band: $bands',
      );
    }
  });

  testWidgets('the band is tinted by the region, not one flat block', (
    WidgetTester tester,
  ) async {
    final SessionController c = await boot(tester);
    await tester.pumpWidget(shell(c, option()));
    await tester.pumpAndSettle();
    final ContentId here = c.session.currentLocation!;
    final Container band = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(GroundedSprite),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (band.decoration! as BoxDecoration).color,
      StrideColors.forRegionDeep(here),
      reason: 'the strip should read as this place\'s ground',
    );
  });

  test('every switched-on habitat plate exists, and the species split holds', () {
    // The five plates landed in FMPO02 (`ENEMIES_report.md`). A switched-on
    // slug whose PNG is missing would hold the band at its full 152 dp with
    // nothing in it — the exact empty rectangle this wave removed — so the
    // switch and the files are held to each other here.
    for (final String slug in EncounterHabitat.enabled) {
      expect(
        File('assets/art/v1/combat/habitat_$slug.png').existsSync(),
        isTrue,
        reason: 'switched on, not packaged: $slug',
      );
    }
    for (final ContentId place in <ContentId>[
      ContentId.unchecked('location.whispering_woods'),
      ContentId.unchecked('location.stonefall_mine'),
      ContentId.unchecked('location.frostmere'),
      ContentId.unchecked('location.forgotten_hollow'),
    ]) {
      expect(EncounterHabitat.plateFor(place), isNotNull, reason: place.value);
    }
    // No enemy lives at Haven's Rest; no plate is authored for a card that is
    // never drawn.
    expect(
      EncounterHabitat.plateFor(ContentId.unchecked('location.havens_rest')),
      isNull,
    );
    // Q-21: the salamander's chamber follows the species, not the place, and
    // the other Stonefall creatures keep the ledge.
    final ContentId mine = ContentId.unchecked('location.stonefall_mine');
    expect(
      EncounterHabitat.plateFor(
        mine,
        enemy: ContentId.unchecked('enemy.salamander'),
      ),
      EncounterHabitat.caveShadow,
    );
    expect(
      EncounterHabitat.plateFor(
        mine,
        enemy: ContentId.unchecked('enemy.cave_goblin'),
      ),
      EncounterHabitat.rockyLedge,
    );
    expect(
      EncounterHabitat.byPlace.map(
        (String place, HabitatPlate plate) =>
            MapEntry<String, String>(place, plate.assetPath),
      ),
      <String, String>{
        'location.whispering_woods':
            'assets/art/v1/combat/habitat_forest_floor.png',
        'location.stonefall_mine':
            'assets/art/v1/combat/habitat_rocky_ledge.png',
        'location.frostmere': 'assets/art/v1/combat/habitat_snowbank.png',
        'location.forgotten_hollow':
            'assets/art/v1/combat/habitat_hollow_rootbed.png',
      },
    );
    // 192 × 76 at ×2 lands on the band's own ceiling exactly — no new density
    // plane, no L-18a exception.
    expect(HabitatPlate.displayHeight, 152);
  });
}
