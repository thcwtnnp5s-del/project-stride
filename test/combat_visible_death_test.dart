/// No creature may die off-screen.
///
/// The Scree Crawler *was* the only enemy in the game with **neither a defeat
/// track nor a flinch track** — FMPO02 wave 2 authored both, so it now dies on
/// its own art and the fall-out is exercised here on a constructed combatant
/// instead. On the killing blow that meant `held` was null,
/// the victory segment collapsed to a bare 400 ms, and the stage went on
/// drawing its *idle* until the reward panel covered it. The player struck the
/// last blow and watched the thing keep breathing until a modal hid it.
///
/// It is not a content authoring mistake to withhold a defeat animation — this
/// repository does it deliberately, and `combat_assets.dart` records which
/// frames are withheld and why. What was wrong is that the stage had no answer
/// for it. Now it does: a fall-out, which is a translate and an alpha over an
/// approved frame rather than an invented pose.
///
/// This guard is written over `CombatAssets.enemyFor` rather than over one id,
/// so it also protects the next content pack: an enemy added with partial art
/// fails here instead of dying invisibly on a device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/screens/combat/combat_choreography.dart';
import 'package:stride_core/stride_core.dart';

void main() {
  // Every enemy the art table knows, base tier and Veterans.
  const List<String> enemies = <String>[
    'enemy.forest_wolf',
    'enemy.wild_boar',
    'enemy.oakback_bear',
    'enemy.cave_goblin',
    'enemy.salamander',
    'enemy.scree_crawler',
    'enemy.frost_lynx',
    'enemy.mountain_ram',
    'enemy.hollow_guardian',
    'enemy.old_grey',
    'enemy.gallery_foreman',
    'enemy.rimeclaw_matriarch',
    'enemy.guardian_awakened',
  ];

  List<StageSegment> victoryFor(String id) => choreograph(
    <CombatBeat>[const WonBeat(xp: 10, levelBefore: 1, levelAfter: 1, drops: <RewardLine>[])],
    traveler: CombatAssets.traveler,
    enemy: CombatAssets.enemyFor(ContentId.unchecked(id)),
    strikeEffect: CombatAssets.fxImpact,
  );

  test('every enemy is visibly finished — a track, a held pose, or a fall', () {
    for (final String id in enemies) {
      final List<StageSegment> segments = victoryFor(id);
      expect(segments, isNotEmpty, reason: id);
      final StageSegment won = segments.last;

      final bool playsTrack = won.enemyTrack != null;
      final bool holds = won.enemyHoldsPose;
      final bool falls = won.enemyFallOut;

      expect(
        playsTrack || holds || falls,
        isTrue,
        reason:
            '$id resolves its own death with nothing on screen — no defeat '
            'track, no held hit pose, and no fall-out. That is the Scree '
            'Crawler defect returning.',
      );
    }
  });

  test('the crawler now dies on its own art, not on the fall-out', () {
    // The named case moved on. FMPO02 wave 2 authored `crawler_defeat` (and a
    // flinch), so the enemy this file is named after no longer reaches the
    // fallback: it plays a defeat track like every other creature with one.
    // The test is kept rather than deleted because it is the pin on the
    // original defect — the crawler must never again resolve its death with
    // nothing on screen, and now it must do it with the better of the two
    // answers.
    final StageSegment won = victoryFor('enemy.scree_crawler').last;
    expect(won.enemyTrack, isNotNull, reason: 'it has authored defeat art now');
    expect(won.enemyHoldsPose, isTrue);
    expect(won.enemyFallOut, isFalse);
    expect(
      won.duration.inMilliseconds,
      greaterThanOrEqualTo(1000),
      reason: 'the defeat plus the hold must outlast the old bare 400 ms',
    );
  });

  test('the fall-out still answers a combatant with neither track', () {
    // No enemy in the shipped table reaches the fall-out any more, which is
    // exactly why this case is constructed rather than named: the fallback
    // exists for the next content pack that arrives with partial art, and a
    // path nothing exercises is a path that rots. Real tracks, deliberately
    // no `hit` and no `defeat`.
    final List<StageSegment> segments = choreograph(
      <CombatBeat>[
        const WonBeat(xp: 10, levelBefore: 1, levelAfter: 1, drops: <RewardLine>[]),
      ],
      traveler: CombatAssets.traveler,
      enemy: CombatantArt(
        idle: CombatAssets.crawler.idle,
        attack: CombatAssets.crawler.attack,
        strikeFrame: 4,
        impactRise: 17,
      ),
      strikeEffect: CombatAssets.fxImpact,
    );
    final StageSegment won = segments.last;
    expect(won.enemyTrack, isNull);
    expect(won.enemyFallOut, isTrue);
    expect(
      won.duration.inMilliseconds,
      greaterThanOrEqualTo(1000),
      reason: 'the fall plus the hold must outlast the old bare 400 ms',
    );
  });

  test('an enemy with real defeat art is untouched by the fall-out', () {
    // The fall-out is a fallback, not a new default. A creature that has a
    // defeat animation must still play it, and must not also fade.
    final StageSegment won = victoryFor('enemy.cave_goblin').last;
    expect(won.enemyTrack, isNotNull);
    expect(won.enemyHoldsPose, isTrue);
    expect(won.enemyFallOut, isFalse);
  });

  test('a withheld-defeat enemy holds its hit pose rather than falling', () {
    // The Hollow Guardian's defeat frames are packaged and deliberately
    // withheld; it holds the hit pose instead. That is an authored decision
    // and the fall-out must not override it.
    final StageSegment won = victoryFor('enemy.hollow_guardian').last;
    expect(won.enemyHoldsPose, isTrue);
    expect(won.enemyFallOut, isFalse);
  });

  test('an unknown enemy does not crash the victory beat', () {
    // A content pack naming an enemy the art table does not know still has to
    // resolve its fight: the round plays with no enemy figure.
    final List<StageSegment> segments = choreograph(
      <CombatBeat>[const WonBeat(xp: 5, levelBefore: 1, levelAfter: 1, drops: <RewardLine>[])],
      traveler: CombatAssets.traveler,
      enemy: null,
      strikeEffect: CombatAssets.fxImpact,
    );
    expect(segments, isNotEmpty);
    expect(segments.last.enemyFallOut, isFalse);
  });
}
