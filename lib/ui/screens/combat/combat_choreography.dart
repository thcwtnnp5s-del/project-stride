/// Turns a round's committed beats into the stage's timeline — pure data, no
/// widget, no clock.
///
/// ## What a segment is
///
/// The stage runs one `AnimationController` and plays a round as a list of
/// [StageSegment]s, one after another. Each segment has a fixed duration and
/// says, for that span, which track each figure plays and from when, which
/// effect bursts where and when, which HP figure tweens to which committed
/// value over which window, and what the round's turn and telegraph become.
/// The controller's elapsed time is the only input to "which frame now"; the
/// segment list is the only input to "which track". Nothing here reads a
/// clock, and nothing here decides a game fact — every target value below is
/// copied from a `CombatBeat` the engine already committed
/// (`GAME_BIBLE/COMBAT/02` §10: "a replay of facts already durable").
///
/// ## Timing decisions, and the one cut
///
/// Tracks play at the manifest's own fps: the art was timed by its author.
/// A blow lands on the strike frame the manifest names; the effect, the
/// target's reaction and the HP tween all start there. One shortening is
/// deliberate: an enemy-strike segment ends when the enemy's attack track ends
/// or 400 ms after the blow, whichever is later, so a 750 ms Traveler flinch
/// that began late is cut short by the next segment. That keeps a wolf's
/// two-strike round near the 2.5 s the presentation contract asks for instead
/// of 3.5 s; the flinch's extreme frame is already past by then.
library;

import '../../../runtime/stride_session.dart';
import '../../icons/combat_assets.dart';

/// Which figure a track, effect or recoil applies to.
enum StageActor { traveler, enemy }

/// A one-shot effect burst at a figure, starting [start] into the segment.
final class StageEffect {
  const StageEffect({required this.art, required this.at, required this.start});

  final EffectArt art;
  final StageActor at;
  final Duration start;
}

/// One span of the stage's timeline. See the library doc.
final class StageSegment {
  const StageSegment({
    required this.duration,
    this.travelerTrack,
    this.travelerStart = Duration.zero,
    this.enemyTrack,
    this.enemyStart = Duration.zero,
    this.enemyHoldsPose = false,
    this.effects = const <StageEffect>[],
    this.recoil,
    this.recoilStart = Duration.zero,
    this.enemyHpTo,
    this.playerHpTo,
    this.hpTweenStart = Duration.zero,
    this.hpTweenEnd = Duration.zero,
    this.turn,
    this.telegraph,
    this.heal,
    this.heavyFlash = false,
  }) : assert(duration > Duration.zero, 'a segment must take time');

  final Duration duration;

  /// The Traveler's track for this segment, from [travelerStart]; `null` is
  /// the idle loop.
  final CombatTrack? travelerTrack;
  final Duration travelerStart;

  /// The enemy's track, from [enemyStart]; `null` is the idle loop.
  final CombatTrack? enemyTrack;
  final Duration enemyStart;

  /// True when the enemy keeps [enemyTrack]'s last frame after this segment —
  /// the defeat, or the held hit pose that stands in for a withheld defeat.
  final bool enemyHoldsPose;

  final List<StageEffect> effects;

  /// A figure with no flinch track jerks back a few dp instead, from
  /// [recoilStart]. Presentation of a fact the beat carries.
  final StageActor? recoil;
  final Duration recoilStart;

  /// The committed HP the bar settles on, tweened over
  /// [hpTweenStart]..[hpTweenEnd]. At most one of the two per segment.
  final int? enemyHpTo;
  final int? playerHpTo;
  final Duration hpTweenStart;
  final Duration hpTweenEnd;

  /// The turn and telegraph the HUD shows from this segment on.
  final int? turn;
  final bool? telegraph;

  /// A `+N` heal float over the Traveler.
  final int? heal;

  /// The telegraph line brightens for a heavy blow.
  final bool heavyFlash;
}

/// How long a figure without a flinch track recoils.
const Duration recoilDuration = Duration(milliseconds: 150);

/// The window over which an HP bar tweens after a blow lands.
const Duration _hpTween = Duration(milliseconds: 250);

/// The least a strike segment runs on after the blow lands.
const Duration _afterBlow = Duration(milliseconds: 400);

Duration _frameTime(CombatTrack t, int frame) =>
    Duration(microseconds: (frame / t.track.fps * 1000000).round());

Duration _max(Duration a, Duration b) => a > b ? a : b;

/// Whether [beats] produce any segment — the exact condition under which the
/// stage replays a report rather than absorbing it silently ([choreograph]
/// emits one segment per beat except [EncounterStartedBeat]).
///
/// The screen asks this on the frame a report arrives, so it can lock its
/// controls and hold the outcome panel back **that frame**: the stage's own
/// `onPlayingChanged` is deferred to a post-frame callback (it fires from
/// `didUpdateWidget`, inside the build), which is one frame too late for the
/// panel not to flash.
bool replays(List<CombatBeat> beats) =>
    beats.any((CombatBeat b) => b is! EncounterStartedBeat);

/// The segments that replay [beats], in order.
///
/// [enemy] is `null` for an enemy the art table does not know: the round
/// still plays — the Traveler swings, effects burst, HP settles — with no
/// enemy figure to move.
List<StageSegment> choreograph(
  List<CombatBeat> beats, {
  required CombatantArt traveler,
  required CombatantArt? enemy,
  required EffectArt strikeEffect,
}) {
  final List<StageSegment> out = <StageSegment>[];
  for (final CombatBeat b in beats) {
    switch (b) {
      case EncounterStartedBeat():
        // The figures already stand where the view puts them.
        break;

      case PlayerStruckBeat():
        final CombatTrack atk = traveler.attack;
        final Duration lands = _frameTime(atk, traveler.strikeFrame);
        final CombatTrack? flinch = enemy?.hit;
        final Duration reaction = flinch?.duration ?? recoilDuration;
        out.add(
          StageSegment(
            duration: _max(
              _max(atk.duration, lands + reaction),
              lands + CombatAssets.fxImpact.duration,
            ),
            travelerTrack: atk,
            enemyTrack: flinch,
            enemyStart: lands,
            recoil: flinch == null && enemy != null ? StageActor.enemy : null,
            recoilStart: lands,
            effects: <StageEffect>[
              StageEffect(
                art: CombatAssets.fxImpact,
                at: StageActor.enemy,
                start: lands,
              ),
            ],
            enemyHpTo: b.enemyHpAfter,
            hpTweenStart: lands,
            hpTweenEnd: lands + _hpTween,
          ),
        );

      case EnemyStruckBeat():
        final CombatTrack? atk = b.heavy
            ? (enemy?.heavy ?? enemy?.attack)
            : enemy?.attack;
        final int strikeFrame = b.heavy && enemy?.heavy != null
            ? enemy!.heavyStrikeFrame!
            : enemy?.strikeFrame ?? 0;
        final Duration lands = atk == null
            ? Duration.zero
            : _frameTime(atk, strikeFrame);
        out.add(
          StageSegment(
            duration: _max(atk?.duration ?? _afterBlow, lands + _afterBlow),
            enemyTrack: atk,
            travelerTrack: traveler.hit,
            travelerStart: lands,
            recoil: traveler.hit == null ? StageActor.traveler : null,
            recoilStart: lands,
            effects: <StageEffect>[
              StageEffect(
                art: strikeEffect,
                at: StageActor.traveler,
                start: lands,
              ),
            ],
            playerHpTo: b.playerHpAfter,
            hpTweenStart: lands,
            hpTweenEnd: lands + _hpTween,
            heavyFlash: b.heavy,
          ),
        );

      case ConsumableUsedBeat():
        out.add(
          StageSegment(
            duration: const Duration(milliseconds: 600),
            playerHpTo: b.playerHpAfter,
            hpTweenStart: Duration.zero,
            hpTweenEnd: const Duration(milliseconds: 300),
            heal: b.healed,
          ),
        );

      case RoundEndedBeat():
        out.add(
          StageSegment(
            duration: const Duration(milliseconds: 250),
            turn: b.turn,
            telegraph: b.telegraph,
          ),
        );

      case WonBeat():
        final CombatTrack? defeat = enemy?.defeat;
        final CombatTrack? held = defeat ?? enemy?.hit;
        out.add(
          StageSegment(
            duration: held == null
                ? _afterBlow
                : held.duration + const Duration(milliseconds: 300),
            enemyTrack: held,
            enemyHoldsPose: held != null,
            enemyHpTo: 0,
            hpTweenEnd: const Duration(milliseconds: 150),
            telegraph: false,
          ),
        );

      case LostBeat():
        out.add(
          StageSegment(
            duration: traveler.hit?.duration ?? _afterBlow,
            travelerTrack: traveler.hit,
            telegraph: false,
          ),
        );

      case RetreatedBeat():
        out.add(StageSegment(duration: _afterBlow, telegraph: false));
    }
  }
  return out;
}
