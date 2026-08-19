/// The animated combat stage, driven directly — no session, no file I/O.
///
/// `combat_ui_test.dart` proves the screen against a real session; this file
/// proves the stage's replay against hand-built views and reports, and each
/// case names the defect it catches: a replay that plays the wrong track or
/// settles on the wrong figure, a skip that leaves a bar mid-tween, a guardian
/// drawn on the wrong backdrop or standing off the ground row, a stage that
/// keeps ticking under `TickerMode`, and an idle loop that never lets a test
/// settle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/screens/combat/combat_choreography.dart';
import 'package:stride/ui/screens/combat/combat_stage.dart';
import 'package:stride_core/stride_core.dart';

EncounterView view({
  String enemy = 'enemy.forest_wolf',
  String enemyName = 'Forest Wolf',
  String location = 'location.whispering_woods',
  int turn = 1,
  int playerHp = 40,
  int enemyHp = 20,
  bool telegraph = false,
  bool boss = false,
}) => EncounterView(
  enemyId: ContentId.unchecked(enemy),
  enemyName: enemyName,
  location: ContentId.unchecked(location),
  locationName: 'Somewhere',
  turn: turn,
  playerHp: playerHp,
  playerMaxHp: 40,
  playerAttack: 3,
  playerDefence: 1,
  enemyHp: enemyHp,
  enemyMaxHp: 20,
  telegraph: telegraph,
  behavior: EnemyBehavior.flurry,
  isBoss: boss,
);

/// One round: the Traveler strikes for 7, the wolf strikes back for 4, turn 2.
const CombatReport round = CombatReport(
  succeeded: true,
  enemyName: 'Forest Wolf',
  events: <CombatBeat>[
    PlayerStruckBeat(damage: 7, enemyHpAfter: 13),
    EnemyStruckBeat(damage: 4, playerHpAfter: 36, heavy: false, strikeIndex: 0),
    RoundEndedBeat(turn: 2, telegraph: false),
  ],
);

Widget host(Widget child, {bool tickers = true}) => MediaQuery(
  data: const MediaQueryData(size: Size(393, 852)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: TickerMode(
      enabled: tickers,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 361, child: RepaintBoundary(child: child)),
      ),
    ),
  ),
);

/// The asset paths of every grounded sprite on the stage, in tree order:
/// the Traveler first, then the enemy.
List<String> sprites(WidgetTester tester) => tester
    .widgetList<GroundedSprite>(find.byType(GroundedSprite))
    .map((GroundedSprite g) => g.assetPath)
    .toList();

String travelerSprite(WidgetTester tester) => sprites(tester).first;
String enemySprite(WidgetTester tester) => sprites(tester).last;

void main() {
  testWidgets('a round replays attack → impact → enemy strike → flinch in '
      'order and settles on the committed figures', (
    WidgetTester tester,
  ) async {
    final List<bool> playing = <bool>[];
    await tester.pumpWidget(
      host(
        CombatStage(view: view(), report: null, onPlayingChanged: playing.add),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.text('40 / 40'), findsOneWidget);
    expect(find.text('TURN 1'), findsOneWidget);
    expect(travelerSprite(tester), contains('traveler_combat_idle'));
    expect(enemySprite(tester), contains('wolf_idle'));

    // The report arrives with the committed view: the stage replays it, and
    // the HUD still shows the pre-round figures until the blows land.
    await tester.pumpWidget(
      host(
        CombatStage(
          view: view(turn: 2, playerHp: 36, enemyHp: 13),
          report: round,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pump();
    expect(playing, <bool>[true]);
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.text('TURN 1'), findsOneWidget, reason: 'not yet');
    expect(travelerSprite(tester), contains('traveler_attack_f0'));

    // 200 ms: the slash frame — the impact bursts at the wolf, which has no
    // flinch track and recoils instead; the wolf's bar begins to fall.
    await tester.pump(const Duration(milliseconds: 210));
    expect(travelerSprite(tester), contains('traveler_attack_f2'));
    final Iterable<PixelAsset> fx = tester
        .widgetList<PixelAsset>(find.byType(PixelAsset))
        .where((PixelAsset p) => p.assetPath.contains('fx_'));
    expect(fx.map((PixelAsset p) => p.assetPath), <String>[
      'assets/art/v1/combat/fx_impact_f0.png',
    ]);
    // Frame 2 lands 200 ms in; the segment runs 617 ms (200 + the 417 ms
    // burst) and the bar settles at 450 ms.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('13 / 20'), findsOneWidget);
    expect(
      find.text('40 / 40'),
      findsOneWidget,
      reason: 'the wolf has not bitten',
    );

    // Second segment: the wolf lunges (f5 = the bite at 500 ms), the bite
    // bursts at the Traveler and he flinches.
    await tester.pump(const Duration(milliseconds: 150));
    expect(enemySprite(tester), contains('wolf_attack'));
    await tester.pump(const Duration(milliseconds: 520));
    expect(enemySprite(tester), contains('wolf_attack_f5'));
    expect(travelerSprite(tester), contains('traveler_hit_f0'));
    expect(
      tester
          .widgetList<PixelAsset>(find.byType(PixelAsset))
          .where((PixelAsset p) => p.assetPath.contains('fx_bite')),
      hasLength(1),
    );

    // Then everything settles: idle tracks, committed figures, turn 2, and the
    // parent told the replay is over — before the idle visit is spent, so the
    // stage is still moving. One segment boundary is crossed per frame, so
    // the round-end segment (250 ms) needs a frame of its own.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('13 / 20'), findsOneWidget);
    expect(find.text('36 / 40'), findsOneWidget);
    expect(find.text('TURN 2'), findsOneWidget);
    expect(playing, <bool>[true, false]);
    expect(travelerSprite(tester), contains('traveler_combat_idle'));
    expect(enemySprite(tester), contains('wolf_idle'));

    // The idle visit is bounded: the stage settles.
    await tester.pumpAndSettle();
    expect(travelerSprite(tester), endsWith('traveler_combat_idle_f0.png'));
    expect(enemySprite(tester), endsWith('wolf_idle_f0.png'));
  });

  testWidgets('a tap on the stage skips the replay to its end state', (
    WidgetTester tester,
  ) async {
    final List<bool> playing = <bool>[];
    await tester.pumpWidget(
      host(
        CombatStage(view: view(), report: null, onPlayingChanged: playing.add),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        CombatStage(
          view: view(turn: 2, playerHp: 36, enemyHp: 13),
          report: round,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(travelerSprite(tester), contains('traveler_attack'));
    expect(find.text('20 / 20'), findsOneWidget);

    await tester.tap(find.byType(CombatStage));
    await tester.pump();
    expect(playing, <bool>[true, false]);
    expect(find.text('13 / 20'), findsOneWidget);
    expect(find.text('36 / 40'), findsOneWidget);
    expect(find.text('TURN 2'), findsOneWidget);
    expect(travelerSprite(tester), contains('traveler_combat_idle'));
    expect(enemySprite(tester), contains('wolf_idle'));
    await tester.pumpAndSettle();
  });

  testWidgets('the guardian fights in the Hollow, on the 96 canvas, feet on '
      'the ground row', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        CombatStage(
          view: view(
            enemy: 'enemy.hollow_guardian',
            enemyName: 'Hollow Guardian',
            location: 'location.forgotten_hollow',
            boss: true,
          ),
          report: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Iterable<PixelAsset> backdrops = tester
        .widgetList<PixelAsset>(find.byType(PixelAsset))
        .where((PixelAsset p) => p.assetPath.contains('backdrop_'));
    expect(backdrops.map((PixelAsset p) => p.assetPath), <String>[
      CombatAssets.backdropHollow,
    ]);

    final GroundedSprite guardian = tester
        .widgetList<GroundedSprite>(find.byType(GroundedSprite))
        .last;
    expect(guardian.assetPath, endsWith('guardian_idle_f0.png'));
    expect(guardian.canvas, 96);
    expect(guardian.canvasHeight, 96);
    // Anchor row 83 on ground row 88, both ×2: the canvas top is 10 dp down
    // the backdrop, and its foot row lands on 176.
    final Positioned placed = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byWidget(guardian),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(placed.top, 176 - 83 * 2);
    // Column 138 of the backdrop, which is 12 dp left of the 361 dp stage
    // ((361 − 384) / 2 floored), minus the footprint centre (38..57 → 48).
    expect(placed.left, -12 + 138 * 2 - 48 * 2);
    expect(find.text('BOSS'), findsOneWidget);
    expect(find.text('Hollow Guardian'), findsOneWidget);
  });

  testWidgets('under TickerMode(enabled: false) nothing advances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(CombatStage(view: view(), report: null), tickers: false),
    );
    await tester.pump();
    await tester.pumpWidget(
      host(
        CombatStage(
          view: view(turn: 2, playerHp: 36, enemyHp: 13),
          report: round,
        ),
        tickers: false,
      ),
    );
    await tester.pump();
    final String at0 = travelerSprite(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(travelerSprite(tester), at0);
    expect(find.text('20 / 20'), findsOneWidget, reason: 'the tween never ran');
    expect(find.text('TURN 1'), findsOneWidget);
    // And it settles: a muted ticker schedules no frame.
    await tester.pumpAndSettle();
  });

  testWidgets('a lost round fells nobody, a won round fells the wolf and holds '
      'the pose', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(CombatStage(view: view(enemyHp: 5), report: null)),
    );
    await tester.pumpAndSettle();
    // Not `const`: a `RewardLine` carries a parsed `ContentId`, and parsing
    // is a method call.
    final CombatReport won = CombatReport(
      succeeded: true,
      enemyName: 'Forest Wolf',
      events: <CombatBeat>[
        PlayerStruckBeat(damage: 7, enemyHpAfter: 0),
        WonBeat(
          xp: 30,
          levelBefore: 1,
          levelAfter: 1,
          drops: <RewardLine>[
            RewardLine(
              id: ContentId.unchecked('item.meadow_herb'),
              name: 'Meadow Herb',
              quantity: 1,
              rarity: Rarity.uncommon,
            ),
          ],
        ),
      ],
    );
    // The encounter has cleared: the parent passes the remembered view.
    await tester.pumpWidget(
      host(CombatStage(view: view(enemyHp: 5), report: won, ended: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(enemySprite(tester), contains('wolf_defeat'));
    await tester.pumpAndSettle();
    expect(enemySprite(tester), endsWith('wolf_defeat_f6.png'));
    expect(find.text('0 / 20'), findsOneWidget);
    expect(find.text('40 / 40'), findsOneWidget);
  });

  test('the choreography reads the manifest timing: strike frames land where '
      'the notes say', () {
    final List<StageSegment> s = choreograph(
      round.events,
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(s, hasLength(3));
    // Traveler attack f2 at 10 fps.
    expect(s[0].effects.single.start, const Duration(milliseconds: 200));
    expect(s[0].recoil, StageActor.enemy);
    expect(s[0].enemyHpTo, 13);
    // Wolf bite f5 at 10 fps; the flinch is cut at 900 ms, the attack's end.
    expect(s[1].effects.single.start, const Duration(milliseconds: 500));
    expect(s[1].duration, const Duration(milliseconds: 900));
    expect(s[1].playerHpTo, 36);
    expect(s[2].turn, 2);
    // A whole wolf round is under 2 s.
    final Duration total = s.fold(
      Duration.zero,
      (Duration a, StageSegment b) => a + b.duration,
    );
    expect(total, lessThan(const Duration(milliseconds: 2000)));

    // The guardian's heavy blow is the file called guardian_attack, f3 at
    // 6 fps.
    final List<StageSegment> heavy = choreograph(
      const <CombatBeat>[
        EnemyStruckBeat(
          damage: 9,
          playerHpAfter: 20,
          heavy: true,
          strikeIndex: 0,
        ),
      ],
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.guardian,
      strikeEffect: CombatAssets.fxImpact,
    );
    expect(heavy.single.enemyTrack?.id, 'guardian_attack');
    expect(
      heavy.single.effects.single.start,
      const Duration(milliseconds: 500),
    );
    expect(heavy.single.heavyFlash, isTrue);
  });

  test('withheld art is never referenced', () {
    for (final ContentId e in <String>[
      'enemy.forest_wolf',
      'enemy.cave_goblin',
      'enemy.hollow_guardian',
    ].map(ContentId.unchecked)) {
      for (final String f in CombatAssets.framesFor(
        e,
        ContentId.unchecked('location.whispering_woods'),
      )) {
        expect(f, isNot(contains('wolf_hit')));
        expect(f, isNot(contains('guardian_defeat')));
      }
    }
  });
}
