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
import 'package:stride/ui/screens/adventure/encounter_card.dart';
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

  testWidgets('the guardian takes the band at native scale — 96 at ×2 would '
      'not fit a card', (WidgetTester tester) async {
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
    expect(sprite.scale, 1);
    expect(sprite.canvas, 96);
    expect(find.text('Hollow Guardian'), findsOneWidget);
    expect(find.text('BOSS'), findsOneWidget);
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
}
