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

/// Which semantic audio event a segment carries, and nothing about the sound
/// itself.
///
/// ## Why an enum and not the event id string
///
/// The stage turns each of these into exactly one `playEvent('<id>')` call
/// with a literal id (`combat_stage.dart`), which is what
/// `test/audio/event_call_sites_test.dart` greps for. An id threaded through
/// here as a `String` would satisfy the compiler and leave that grep — and so
/// the guard against `MISTAKES.md` M-16, a cue whose caller quietly went away
/// — with nothing to find. The analyzer's exhaustiveness check over this enum
/// is what keeps the two files in step.
///
/// The choreography therefore says *what happened*; only the stage says what
/// it sounds like.
enum StageCue {
  playerSwing,
  playerImpact,
  enemyAttack,
  enemyImpact,
  heavyTelegraph,
  heavyImpact,
  brace,
  braceAbsorb,
  heal,
  enemyDefeated,
}

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
    this.travelerHoldsPose = false,
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
    this.heavyImpactAt,
    this.enemyFallOut = false,
    this.braced = false,
    this.startCue,
    this.impactCue,
    this.impactCueAt = Duration.zero,
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

  /// True when the Traveler keeps [travelerTrack]'s last frame after this
  /// segment — the stagger's kneel, held while the enemy stands over him and
  /// on through the outcome panel. The Traveler's mirror of [enemyHoldsPose].
  final bool travelerHoldsPose;

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

  /// The enemy sinks and fades over this segment instead of playing a track:
  /// the killing blow's answer for a creature with no defeat and no flinch
  /// art. Mutually exclusive with [enemyHoldsPose] by construction — a figure
  /// that has a pose to hold does not need this.
  final bool enemyFallOut;

  /// When in this segment a heavy blow actually **lands**, for the haptic.
  ///
  /// Null on every segment that is not a heavy strike
  /// (PRESENTATION_COMBAT_EVOLUTION_01). The heavy haptic used to fire at the
  /// segment's *start*, under a comment claiming it landed "as it lands on
  /// screen" — but the Guardian's heavy strike frame is 500 ms into a 1,167 ms
  /// track, and the Bear's is 625 ms into 1,125. The wrist was arriving up to
  /// two thirds of a second before the arm came down, which reads as a phone
  /// glitch rather than as a blow.
  ///
  /// This is the same `lands` offset the effect burst, the recoil and the HP
  /// tween already use, so all four now agree on when the hit happened.
  final Duration? heavyImpactAt;

  /// The player set their feet: this segment **is** the brace.
  ///
  /// Brace has no authored stance pose, so on screen it is a held idle — the
  /// one commitment in the fight the player cannot see themselves make
  /// (`ART-11_audio_brief.md` §4, the one real haptic gap). The stage answers
  /// it in the hand instead, one light pulse at the segment's start, which is
  /// also where the queued `combat.brace.01` cue will play. A flag rather
  /// than a beat type because the stage plays segments and has deliberately
  /// never known what a `CombatBeat` is.
  final bool braced;

  /// The event this segment **begins** with — the swing leaving the shoulder,
  /// the enemy's lunge, the wind-up of a heavy blow, the feet being set, the
  /// stopper coming out of the flask, the body going down.
  ///
  /// Fired from `_startSegment`, which is the state machine's own transition
  /// and not a frame callback (`MISTAKES.md` M-16).
  final StageCue? startCue;

  /// The event fired at the instant the blow **lands**, [impactCueAt] into
  /// the segment.
  ///
  /// Separate from [startCue] because intent and impact are two different
  /// sounds at two different times: the swing is the segment's start, the
  /// thud is the strike frame the manifest names — the same `lands` offset
  /// the effect burst, the recoil, the HP tween and [heavyImpactAt] already
  /// share, so all six agree on when the hit happened.
  final StageCue? impactCue;
  final Duration impactCueAt;
}

/// How long a figure without a flinch track recoils.
const Duration recoilDuration = Duration(milliseconds: 150);

/// How long a figure with **no defeat and no flinch track** takes to sink and
/// fade on the killing blow. See the `WonBeat` case.
const Duration _fallOut = Duration(milliseconds: 500);

/// How far it sinks, in logical pixels, over that time.
const int fallOutDrop = 6;

/// The window over which an HP bar tweens after a blow lands.
const Duration _hpTween = Duration(milliseconds: 250);

/// The least a strike segment runs on after the blow lands.
const Duration _afterBlow = Duration(milliseconds: 400);

/// How long the fallen enemy's pose stands before the sequence ends and the
/// Victory panel may appear — the beat in which the defeat lands emotionally.
/// The device correction found the shipped 300 ms tail let the panel settle
/// before the fall had read.
const Duration _wonHold = Duration(milliseconds: 700);

/// The beat after the Traveler's stagger has reached its kneel: the enemy
/// stays in idle, holding its ground over the kneeling Traveler, before the
/// "Driven back" panel appears. Defeat is retreat, never death, and the
/// picture must say "overwhelmed", not "dead".
const Duration _lostSettle = Duration(milliseconds: 500);

/// The planted beat a brace holds before the enemy's halved reply — long
/// enough to read as a chosen stance, short enough not to slow the round.
///
/// 500 ms since FMPO02 wave 3 (FINAL-06). At 350 the one round the player
/// *chose* to spend on defence was held for less time than [_lostSettle]
/// gives an incidental knockdown, so the deliberate act read as the smaller
/// event. The stance is now the longest single held pose in an ordinary
/// round, which is what "I braced" is supposed to feel like.
const Duration _bracedHold = Duration(milliseconds: 500);

Duration _frameTime(CombatTrack t, int frame) =>
    Duration(microseconds: (frame / t.track.fps * 1000000).round());

Duration _max(Duration a, Duration b) => a > b ? a : b;

/// Whether [beats] produce any segment — the exact condition under which the
/// stage replays a report rather than absorbing it silently ([choreograph]
/// emits at least one segment per beat except [EncounterStartedBeat], which
/// emits none; [LostBeat] emits two — the stagger and the settle).
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
  // Whether the player set their feet this round. Every enemy strike after a
  // `BracedBeat` lands at half damage (`DECISIONS/0027`, the beat's own doc),
  // so from here on the reply is a blow *arriving into a guard* rather than a
  // blow arriving — which is a different sound, and the only place the player
  // is told their choice worked.
  bool braced = false;
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
            startCue: StageCue.playerSwing,
            impactCue: StageCue.playerImpact,
            impactCueAt: lands,
          ),
        );

      case BracedBeat():
        // Brace (`DECISIONS/0027`). FMPO02 authored a stance for every
        // PixelLab loadout — the sword across the body, or forearms crossed
        // — played once and held on its last frame for the rest of the beat.
        // The shipped base + steel set predates PixelLab and has none, so it
        // keeps the held, planted idle that every set used before.
        final CombatTrack? brace = traveler.brace;
        braced = true;
        out.add(
          StageSegment(
            duration: brace == null || brace.duration < _bracedHold
                ? _bracedHold
                : brace.duration,
            travelerTrack: brace ?? traveler.idle,
            travelerHoldsPose: brace != null,
            braced: true,
            startCue: StageCue.brace,
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
            heavyImpactAt: b.heavy ? lands : null,
            startCue: b.heavy
                ? StageCue.heavyTelegraph
                : StageCue.enemyAttack,
            // A heavy blow stays a heavy blow even into a guard: the wrist
            // fires `hapticHeavy` here either way (`heavyImpactAt` above is
            // set on `b.heavy` alone), and a sound that disagreed with the
            // hand about what just landed would be worse than either alone.
            // The brace's own answer is therefore the *ordinary* reply it
            // halves, which is also the common case — brace exists to be the
            // counter to a telegraphed heavy, so keying `braceAbsorb` to
            // heavies would have starved `combat.heavy.impact` instead.
            impactCue: b.heavy
                ? StageCue.heavyImpact
                : (braced ? StageCue.braceAbsorb : StageCue.enemyImpact),
            impactCueAt: lands,
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
            startCue: StageCue.heal,
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
        // **The Scree Crawler could not be seen to die.** It is the one enemy
        // with neither a defeat track nor a hit track, so `held` was null, the
        // segment collapsed to a bare 400 ms, and the stage went on drawing
        // its *idle* until the victory panel covered it. The player killed
        // something and watched it keep breathing.
        //
        // With no art to play, the fall-out is a deterministic presentation of
        // a fact the beat already carries: the last standing frame sinks
        // toward the ground line and fades out. A translate and an alpha over
        // an approved frame — no new silhouette, no invented pose (`RULES.md`
        // A-2, the same class as the recoil this file already runs on). It is
        // not a defeat animation and does not pretend to be one; it is the
        // difference between a creature dying off-screen and a creature dying.
        final bool fallOut = enemy != null && held == null;
        out.add(
          StageSegment(
            duration: held != null
                ? held.duration + _wonHold
                : (fallOut ? _fallOut + _wonHold : _afterBlow),
            enemyTrack: held,
            enemyHoldsPose: held != null,
            enemyFallOut: fallOut,
            enemyHpTo: 0,
            hpTweenEnd: const Duration(milliseconds: 150),
            telegraph: false,
            startCue: StageCue.enemyDefeated,
          ),
        );

      case LostBeat():
        // The enemy's final strike is the preceding EnemyStruckBeat segment.
        // Then the Traveler staggers back and drops to one knee, holds it,
        // and the enemy — back in idle — stands its ground over him for a
        // settle beat before the "Driven back" panel is let through. Two
        // segments, so the kneel is already held while the enemy idles.
        final CombatTrack? stagger = traveler.stagger;
        if (stagger != null) {
          out.add(
            StageSegment(
              duration: stagger.duration,
              travelerTrack: stagger,
              travelerHoldsPose: true,
              telegraph: false,
            ),
          );
          // Not `const`: the constructor's `duration > Duration.zero` assert
          // cannot be const-evaluated.
          out.add(StageSegment(duration: _lostSettle));
        } else {
          // No stagger track packaged: the old flinch stands in.
          out.add(
            StageSegment(
              duration: traveler.hit?.duration ?? _afterBlow,
              travelerTrack: traveler.hit,
              telegraph: false,
            ),
          );
        }

      case RetreatedBeat():
        out.add(StageSegment(duration: _afterBlow, telegraph: false));
    }
  }
  return out;
}
