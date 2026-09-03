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

/// The loadout every stage in this file is built with.
///
/// These tests prove the *choreography* — segment order, frame timing, what
/// the stage settles on — and every duration in them was measured against the
/// base Traveler's strips. The VAWO01 weapon round made the default loadout
/// (nothing equipped) resolve to the unarmed set, whose attack runs seven
/// frames rather than four, which moves every pumped instant below. Naming
/// the training sword keeps these cases pointed at the art they were written
/// against; `combat_gear_variant_test.dart` covers which set a loadout picks.
const EquipmentVisualState _armed = EquipmentVisualState(
  weapon: EquippedVisualFact(
    itemId: 'item.training_sword',
    tier: 0,
    toolKind: 'none',
  ),
);

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

/// A whole wolf round: the strike, then the flurry's two replies, turn 2.
const CombatReport flurryRound = CombatReport(
  succeeded: true,
  enemyName: 'Forest Wolf',
  events: <CombatBeat>[
    PlayerStruckBeat(damage: 7, enemyHpAfter: 13),
    EnemyStruckBeat(damage: 4, playerHpAfter: 36, heavy: false, strikeIndex: 0),
    EnemyStruckBeat(damage: 3, playerHpAfter: 33, heavy: false, strikeIndex: 1),
    RoundEndedBeat(turn: 2, telegraph: false),
  ],
);

/// The HUD's one exact `hp / max` figure for the combatant with [max]; the
/// log's prose never matches the whole-string pattern.
int shownHp(WidgetTester tester, int max) {
  final RegExp re = RegExp(
    r'^(\d+) / '
    '$max'
    r'$',
  );
  final List<int> hits = <int>[
    for (final Text t in tester.widgetList<Text>(find.byType(Text)))
      if (t.data != null && re.hasMatch(t.data!))
        int.parse(re.firstMatch(t.data!)!.group(1)!),
  ];
  expect(hits, hasLength(1), reason: 'one HUD figure per combatant');
  return hits.single;
}

Widget host(Widget child, {bool tickers = true, bool reduceMotion = false}) =>
    MediaQuery(
      data: MediaQueryData(
        size: const Size(393, 852),
        disableAnimations: reduceMotion,
      ),
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
        CombatStage(
          equipment: _armed,
          view: view(),
          report: null,
          onPlayingChanged: playing.add,
        ),
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
          equipment: _armed,
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
        CombatStage(
          equipment: _armed,
          view: view(),
          report: null,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
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
          equipment: _armed,
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
    // Anchor row 83 on ground row 120, both ×2: the canvas top is 74 dp
    // down the 256 dp backdrop, and its foot row lands on 240. The ground row
    // moved with the taller 192 × 128 family (FMPO02 wave 2) and the figure
    // did not — it stands the same 8 native rows up from the canvas bottom.
    final Positioned placed = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byWidget(guardian),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(placed.top, 240 - 83 * 2);
    // Column 128 of the backdrop — 138 until EPO03, moved 10 native columns
    // in to close the 80 dp gap between the two figures (`DIR-11`) — which is
    // 12 dp left of the 361 dp stage ((361 − 384) / 2 floored), minus the
    // footprint centre (38..57 → 48). The figure did not move on the ground
    // row and its canvas did not change; only the column it stands on did.
    expect(placed.left, -12 + CombatAssets.enemyColumn * 2 - 48 * 2);
    expect(CombatAssets.enemyColumn, 128, reason: 'the closed gap');
    expect(find.text('BOSS'), findsOneWidget);
    expect(find.text('Hollow Guardian'), findsOneWidget);
  });

  testWidgets('the Frost Lynx fights at Frostmere on the alpine backdrop, '
      'feet on the ground row', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(
            enemy: 'enemy.frost_lynx',
            enemyName: 'Frost Lynx',
            location: 'location.frostmere',
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
      CombatAssets.backdropFrostmere,
    ]);
    final GroundedSprite lynx = tester
        .widgetList<GroundedSprite>(find.byType(GroundedSprite))
        .last;
    expect(lynx.assetPath, endsWith('lynx_idle_f0.png'));
    expect(lynx.canvas, 56);
    // Anchor row 39 on ground row 120, both ×2.
    final Positioned placed = tester.widget<Positioned>(
      find
          .ancestor(of: find.byWidget(lynx), matching: find.byType(Positioned))
          .first,
    );
    expect(placed.top, 240 - 39 * 2);
    expect(find.text('Frost Lynx'), findsOneWidget);
  });

  testWidgets('under TickerMode(enabled: false) nothing advances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CombatStage(equipment: _armed, view: view(), report: null),
        tickers: false,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
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
      host(
        CombatStage(equipment: _armed, view: view(enemyHp: 5), report: null),
      ),
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
      host(
        CombatStage(
          equipment: _armed,
          view: view(enemyHp: 5),
          report: won,
          ended: true,
        ),
      ),
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

  testWidgets('a flurry round shows two distinct player decreases and never '
      'an increase', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(CombatStage(equipment: _armed, view: view(), report: null)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(turn: 2, playerHp: 33, enemyHp: 13),
          report: flurryRound,
        ),
      ),
    );
    await tester.pump();
    expect(shownHp(tester, 40), 40, reason: 'nothing has landed yet');
    expect(shownHp(tester, 20), 20);

    final List<int> player = <int>[40];
    final List<int> enemy = <int>[20];
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      player.add(shownHp(tester, 40));
      enemy.add(shownHp(tester, 20));
    }
    for (int i = 1; i < player.length; i++) {
      expect(
        player[i] <= player[i - 1],
        isTrue,
        reason: 'shown player HP rose mid-round (the heal-back): $player',
      );
      expect(
        enemy[i] <= enemy[i - 1],
        isTrue,
        reason: 'shown enemy HP rose mid-round: $enemy',
      );
    }
    expect(
      player,
      contains(36),
      reason: 'the first wolf hit must show its own value',
    );
    expect(player.last, 33);
    expect(enemy.last, 13);
    await tester.pumpAndSettle();
    expect(find.text('TURN 2'), findsOneWidget);
  });

  testWidgets('a tap mid-flurry skips to the exact committed figures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(CombatStage(equipment: _armed, view: view(), report: null)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(turn: 2, playerHp: 33, enemyHp: 13),
          report: flurryRound,
        ),
      ),
    );
    await tester.pump();
    // Mid first wolf strike: one hit has landed, the other has not.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byType(CombatStage));
    await tester.pump();
    expect(shownHp(tester, 40), 33);
    expect(shownHp(tester, 20), 13);
    expect(find.text('TURN 2'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a report arriving while a replay runs applies the old round '
      'whole and replays the new one to its committed end', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(CombatStage(equipment: _armed, view: view(), report: null)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(turn: 2, playerHp: 36, enemyHp: 13),
          report: round,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Mid-replay, the next round's report lands (not reachable from the
    // controls, which lock — but the stage must stay exact regardless).
    const CombatReport next = CombatReport(
      succeeded: true,
      enemyName: 'Forest Wolf',
      events: <CombatBeat>[
        PlayerStruckBeat(damage: 7, enemyHpAfter: 6),
        EnemyStruckBeat(
          damage: 4,
          playerHpAfter: 32,
          heavy: false,
          strikeIndex: 0,
        ),
        EnemyStruckBeat(
          damage: 3,
          playerHpAfter: 29,
          heavy: false,
          strikeIndex: 1,
        ),
        RoundEndedBeat(turn: 3, telegraph: false),
      ],
    );
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(turn: 3, playerHp: 29, enemyHp: 6),
          report: next,
        ),
      ),
    );
    await tester.pump();
    // The interrupted round's end state applied at once, never lost.
    expect(shownHp(tester, 40), 36);
    expect(shownHp(tester, 20), 13);

    final List<int> player = <int>[36];
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      player.add(shownHp(tester, 40));
    }
    for (int i = 1; i < player.length; i++) {
      expect(
        player[i] <= player[i - 1],
        isTrue,
        reason: 'shown player HP rose across the hand-over: $player',
      );
    }
    expect(shownHp(tester, 40), 29);
    expect(shownHp(tester, 20), 6);
    expect(find.text('TURN 3'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  test('a flurry round choreographs one segment per beat, each HP change '
      'tweening inside its own segment', () {
    final List<StageSegment> s = choreograph(
      flurryRound.events,
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(s, hasLength(4));
    // The strike: only the enemy's figure moves, at the blow, not at zero.
    expect(s[0].enemyHpTo, 13);
    expect(s[0].playerHpTo, isNull);
    expect(s[0].hpTweenStart, const Duration(milliseconds: 200));
    // Each wolf hit carries its own committed figure — two distinct
    // decreases, never one jump and never a correction.
    expect(s[1].playerHpTo, 36);
    expect(s[1].enemyHpTo, isNull);
    expect(s[1].hpTweenStart, const Duration(milliseconds: 500));
    expect(s[2].playerHpTo, 33);
    expect(s[2].enemyHpTo, isNull);
    expect(s[3].turn, 2);
    // Every tween completes inside its segment, so no figure can bleed into
    // the next beat's span.
    for (final StageSegment seg in s) {
      expect(seg.hpTweenEnd, lessThanOrEqualTo(seg.duration));
      expect(seg.hpTweenStart, lessThanOrEqualTo(seg.hpTweenEnd));
    }
  });

  testWidgets('Reduce Motion zeroes the recoil and keeps every fact', (
    WidgetTester tester,
  ) async {
    // `combat_stage.dart` had no `disableAnimationsOf` branch at all
    // (PCE01 §4, `ART-09` §6). The wolf has no flinch track, so a landed blow
    // jerks its figure 6 dp — the one translate on this stage — and that is
    // the motion the flag is about. What the blow *means* is not: the burst,
    // the HP tween and the narration all still say the wolf was hit.
    double wolfLeft() => tester
        .widget<Positioned>(
          find
              .ancestor(
                of: find.byWidget(
                  tester
                      .widgetList<GroundedSprite>(find.byType(GroundedSprite))
                      .last,
                ),
                matching: find.byType(Positioned),
              )
              .first,
        )
        .left!;

    Future<double> leftAtImpact({required bool reduceMotion}) async {
      await tester.pumpWidget(
        host(
          CombatStage(equipment: _armed, view: view(), report: null),
          reduceMotion: reduceMotion,
        ),
      );
      await tester.pumpAndSettle();
      final double idle = wolfLeft();
      await tester.pumpWidget(
        host(
          CombatStage(
            equipment: _armed,
            view: view(turn: 2, playerHp: 36, enemyHp: 13),
            report: round,
          ),
          reduceMotion: reduceMotion,
        ),
      );
      await tester.pump();
      // 210 ms: the slash frame, where the impact lands and the recoil is at
      // its widest.
      await tester.pump(const Duration(milliseconds: 210));
      final double atImpact = wolfLeft();
      // The blow itself is still presented either way.
      expect(
        tester
            .widgetList<PixelAsset>(find.byType(PixelAsset))
            .where((PixelAsset p) => p.assetPath.contains('fx_impact')),
        isNotEmpty,
      );
      await tester.pumpAndSettle();
      return atImpact - idle;
    }

    expect(await leftAtImpact(reduceMotion: false), isNot(0));
    expect(await leftAtImpact(reduceMotion: true), 0);
  });

  test('the braced hold is marked, and it is the only segment that is', () {
    // Brace was the one cue in `GAME_BIBLE` §2.1's combat table marked "new
    // `hapticLight`" and the one the code never fired
    // (`ART-11_audio_brief.md` §4). The stage plays segments and deliberately
    // does not know what a `CombatBeat` is, so the flag is how the pulse
    // finds the moment: at the held stance's start, where the player commits.
    final List<StageSegment> braced = choreograph(
      const <CombatBeat>[
        BracedBeat(),
        EnemyStruckBeat(
          damage: 2,
          playerHpAfter: 38,
          heavy: false,
          strikeIndex: 0,
        ),
        RoundEndedBeat(turn: 2, telegraph: false),
      ],
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(braced.where((StageSegment s) => s.braced), hasLength(1));
    expect(braced.first.braced, isTrue);
    // And it is held long enough to read as a decision (FMPO02 wave 3,
    // FINAL-06): at 350 ms the round the player chose to spend on defence was
    // shorter than the settle an incidental knockdown gets for free, so the
    // deliberate act read as the smaller event.
    expect(
      braced.first.duration,
      greaterThanOrEqualTo(const Duration(milliseconds: 500)),
      reason: 'a chosen stance outlasts an incidental beat',
    );
    // A round without a brace stays silent — a pulse on every held idle would
    // be a phone that buzzes for nothing.
    final List<StageSegment> ordinary = choreograph(
      flurryRound.events,
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(ordinary.any((StageSegment s) => s.braced), isFalse);
  });

  test('replays() agrees exactly with choreograph() emitting segments', () {
    final List<List<CombatBeat>> cases = <List<CombatBeat>>[
      const <CombatBeat>[],
      const <CombatBeat>[
        EncounterStartedBeat(
          enemyName: 'Forest Wolf',
          playerHp: 40,
          playerMaxHp: 40,
          enemyHp: 20,
          enemyMaxHp: 20,
        ),
      ],
      round.events,
      flurryRound.events,
      const <CombatBeat>[RetreatedBeat(retreatToName: "Haven's Rest")],
      const <CombatBeat>[
        PlayerStruckBeat(damage: 7, enemyHpAfter: 0),
        WonBeat(xp: 30, levelBefore: 1, levelAfter: 1, drops: <RewardLine>[]),
      ],
    ];
    for (final List<CombatBeat> beats in cases) {
      expect(
        replays(beats),
        choreograph(
          beats,
          traveler: CombatAssets.traveler,
          enemy: CombatAssets.wolf,
          strikeEffect: CombatAssets.fxBite,
        ).isNotEmpty,
        reason: 'replays() must mirror the stage for $beats',
      );
    }
  });

  test('a lost round choreographs the final strike, the stagger to a held '
      'kneel, and a settle beat with the enemy back in idle', () {
    const CombatReport lost = CombatReport(
      succeeded: true,
      enemyName: 'Forest Wolf',
      events: <CombatBeat>[
        EnemyStruckBeat(
          damage: 4,
          playerHpAfter: 0,
          heavy: false,
          strikeIndex: 0,
        ),
        LostBeat(retreatToName: "Haven's Rest"),
      ],
    );
    final List<StageSegment> s = choreograph(
      lost.events,
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(s, hasLength(3), reason: 'strike, stagger, settle');

    // The enemy's final strike is unchanged: the wolf lunges, the blow lands,
    // the player's bar tweens to 0 inside this segment.
    expect(s[0].enemyTrack?.id, 'wolf_attack');
    expect(s[0].playerHpTo, 0);
    expect(s[0].duration, const Duration(milliseconds: 900));

    // The stagger: nine frames at 8 fps, through to the kneel, held.
    expect(s[1].travelerTrack?.id, 'traveler_stagger');
    expect(s[1].travelerHoldsPose, isTrue);
    expect(s[1].duration, const Duration(milliseconds: 1125));
    expect(s[1].enemyTrack, isNull, reason: 'the wolf returns to idle');
    expect(s[1].telegraph, isFalse);
    expect(s[1].playerHpTo, isNull, reason: 'the strike already settled it');

    // The settle beat: the enemy holds its ground over the kneeling
    // Traveler; only after this does the sequence end and the panel appear.
    expect(s[2].duration, const Duration(milliseconds: 500));
    expect(s[2].travelerTrack, isNull, reason: 'the held kneel carries it');
    expect(s[2].enemyTrack, isNull);

    // Budget: the defeat beat replaced a 750 ms flinch with 1625 ms of
    // stagger and settle — 875 ms added, under the ~1.5 s allowance.
    expect(
      s[1].duration + s[2].duration,
      lessThan(const Duration(milliseconds: 750 + 1500)),
    );
  });

  test('a won beat holds the defeat pose 700 ms past the track, so the fall '
      'lands before the panel', () {
    final List<StageSegment> s = choreograph(
      const <CombatBeat>[
        PlayerStruckBeat(damage: 7, enemyHpAfter: 0),
        WonBeat(xp: 30, levelBefore: 1, levelAfter: 1, drops: <RewardLine>[]),
      ],
      traveler: CombatAssets.traveler,
      enemy: CombatAssets.wolf,
      strikeEffect: CombatAssets.fxBite,
    );
    expect(s.last.enemyTrack?.id, 'wolf_defeat');
    expect(s.last.enemyHoldsPose, isTrue);
    // wolf_defeat is 875 ms (7 frames at 8 fps); the tail was 300 ms and the
    // device correction found the panel settled before the fall read.
    expect(s.last.duration, const Duration(milliseconds: 875 + 700));
  });

  testWidgets('a lost round staggers the Traveler to a held kneel while the '
      'wolf holds its ground in idle, and only then ends', (
    WidgetTester tester,
  ) async {
    final List<bool> playing = <bool>[];
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(playerHp: 4),
          report: null,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const CombatReport lost = CombatReport(
      succeeded: true,
      enemyName: 'Forest Wolf',
      events: <CombatBeat>[
        EnemyStruckBeat(
          damage: 4,
          playerHpAfter: 0,
          heavy: false,
          strikeIndex: 0,
        ),
        LostBeat(retreatToName: "Haven's Rest"),
      ],
    );
    // The encounter has cleared: the parent passes the remembered view.
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(playerHp: 4),
          report: lost,
          ended: true,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pump();
    expect(playing, <bool>[true]);

    // The final strike: the wolf lunges (f5 = the bite at 500 ms).
    await tester.pump(const Duration(milliseconds: 520));
    expect(enemySprite(tester), contains('wolf_attack_f5'));

    // Across the segment boundary (900 ms) into the stagger: the Traveler
    // stumbles while the wolf is back in idle, holding its ground.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(travelerSprite(tester), contains('traveler_stagger'));
    expect(enemySprite(tester), contains('wolf_idle'));
    expect(find.text('0 / 40'), findsOneWidget, reason: 'the blow settled it');

    // Past the stagger's end (1125 ms) into the settle beat: the kneel is
    // held, the wolf still idles, and the sequence has not ended — the panel
    // is still held back.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(travelerSprite(tester), endsWith('traveler_stagger_f8.png'));
    expect(enemySprite(tester), contains('wolf_idle'));
    expect(playing, <bool>[true], reason: 'the settle beat holds the panel');

    // The settle beat (500 ms) ends: only now is the parent told.
    await tester.pump(const Duration(milliseconds: 600));
    expect(playing, <bool>[true, false]);

    // The kneel is held through whatever follows — the outcome panel's whole
    // lifetime, here the bounded idle.
    await tester.pumpAndSettle();
    expect(travelerSprite(tester), endsWith('traveler_stagger_f8.png'));
    expect(enemySprite(tester), endsWith('wolf_idle_f0.png'));
    expect(find.text('0 / 40'), findsOneWidget);
  });

  testWidgets('a tap mid-defeat skips to the exact end: HP 0, kneel held, '
      'wolf idle', (WidgetTester tester) async {
    final List<bool> playing = <bool>[];
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(playerHp: 4),
          report: null,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    const CombatReport lost = CombatReport(
      succeeded: true,
      enemyName: 'Forest Wolf',
      events: <CombatBeat>[
        EnemyStruckBeat(
          damage: 4,
          playerHpAfter: 0,
          heavy: false,
          strikeIndex: 0,
        ),
        LostBeat(retreatToName: "Haven's Rest"),
      ],
    );
    await tester.pumpWidget(
      host(
        CombatStage(
          equipment: _armed,
          view: view(playerHp: 4),
          report: lost,
          ended: true,
          onPlayingChanged: playing.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(CombatStage));
    await tester.pump();
    expect(playing, <bool>[true, false]);
    expect(find.text('0 / 40'), findsOneWidget);
    expect(travelerSprite(tester), endsWith('traveler_stagger_f8.png'));
    expect(enemySprite(tester), contains('wolf_idle'));
    await tester.pumpAndSettle();
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
