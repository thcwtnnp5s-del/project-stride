/// The animated combat stage: backdrop, two figures, effects, and the HUD that
/// reads the committed figures.
///
/// ## What drives it
///
/// One `AnimationController`, as `AmbientPlayer`: no `Timer`, no clock read.
/// Its duration is set to the current phase — one segment of the round's
/// choreography, or the bounded idle visit — and its status listener advances
/// the machine when the phase completes. `TickerMode` mutes it, and it is
/// stopped while the app is not resumed and picked up again on resume. Under
/// either, the stage depicts nothing and costs nothing.
///
/// ## What it presents, and never decides
///
/// Every value on the stage is a committed fact. Between rounds the HUD reads
/// the [EncounterView] the session projects. When a [CombatReport] arrives the
/// stage replays its beats — `combat_choreography.dart` turns them into
/// segments — and while that replay runs the HP bars tween from the figure
/// they showed to the figure the beat carries; the tween's end value is the
/// beat's, not a difference the stage computed. Nothing is rendered before the
/// commit (`GAME_BIBLE/COMBAT/02` §10, `RULES.md` E-2).
///
/// A report is only replayed when it **arrives** — `didUpdateWidget` — never
/// on mount. A cold relaunch mid-fight has no report and shows both figures
/// idle with the HP the state holds; a remount with last round's report still
/// in hand does not replay it.
///
/// ## Why the idle is bounded
///
/// The idle tracks loop for [CombatStage.idleVisit] after mount, after every
/// replay and on every return to the app, then hold their first frame. That
/// is the ambient stage's reasoning applied here — a figure that never stops
/// moving starts to imply that something is happening, and nothing is
/// happening between turns; the fight advances only when the player acts. It
/// is also what lets every widget test in the repository `pumpAndSettle`.
///
/// ## Geometry
///
/// The backdrop is 192 × 96 drawn at ×2 — 384 × 192 dp — and the stage is as
/// wide as its parent up to 384. On a 393 dp phone inside the tab's 16 dp
/// gutters that is 361, so the backdrop is clipped, centred, by 11–12 dp a
/// side (`(361 − 384) / 2`); on 320 dp it is 288 and the flanks lose 48 dp
/// each; on 430 dp the stage is the full 384 with 7 dp of app ground either
/// side. Nothing is ever resampled: the backdrop stays pixel-exact at ×2 and
/// the figures stand on fixed backdrop columns (`CombatAssets.travelerColumn`,
/// `enemyColumn` — 116 dp and 276 dp from the backdrop's left) so on every
/// width both are fully visible: the guardian's opaque box spans backdrop
/// columns 120..159 native = 240..318 dp, and at 288 dp of stage the offset is
/// −48, so its right edge sits at 270 dp. The ground row is 88 native =
/// 176 dp from the top; every figure's contact shadow, 8–9 dp deep, ends above
/// the backdrop's 192 dp bottom, and the guardian's head, 144 dp above the
/// ground, sits 32 dp below the top — no headroom band is needed.
///
/// The HUD is a strip **beneath** the backdrop, not an overlay: the guardian's
/// head reaches within 32 dp of the top, so bars over the sky would collide
/// with it on the one enemy the player fights last. Only the turn chip (and
/// BOSS) sit on the picture, in the two top corners, which every backdrop and
/// every figure leave clear.
library;

import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/grounded_sprite.dart';
import '../../components/pixel_asset.dart';
import '../../icons/combat_assets.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'combat_choreography.dart';

/// The whole picture: backdrop, figures, effects, and the HUD strip.
class CombatStage extends StatefulWidget {
  const CombatStage({
    super.key,
    required this.view,
    required this.report,
    this.ended = false,
    this.onPlayingChanged,
    this.idleVisit = const Duration(seconds: 8),
    this.scale = 2,
  });

  /// The committed figures. While [ended], this is the last view the parent
  /// saw before the encounter cleared, kept so the outcome can be staged; the
  /// HP figures then come from the replayed beats, not from it.
  final EncounterView view;

  /// The last combat report, replayed when it arrives.
  final CombatReport? report;

  /// True once the encounter has ended and only the report remains.
  final bool ended;

  /// True while a replay is running — the parent disables its controls.
  final ValueChanged<bool>? onPlayingChanged;

  /// How long the idle tracks loop before holding their first frame.
  final Duration idleVisit;

  final int scale;

  @override
  State<CombatStage> createState() => _CombatStageState();
}

enum _Phase {
  /// The idle tracks loop.
  idle,

  /// The idle visit is spent; both figures hold their first frame.
  spent,

  /// A round's segments are playing.
  playing,
}

/// What the stage draws this frame — compared on every tick so a rebuild
/// happens only when something visible changes.
final class _Shot {
  const _Shot({
    required this.travelerTrack,
    required this.travelerFrame,
    required this.enemyTrack,
    required this.enemyFrame,
    required this.effects,
    required this.travelerDx,
    required this.enemyDx,
    required this.enemyHp,
    required this.playerHp,
    required this.heal,
    required this.healRise,
    required this.heavyFlash,
  });

  final CombatTrack travelerTrack;
  final int travelerFrame;
  final CombatTrack? enemyTrack;
  final int enemyFrame;

  /// `(effect, actor, frame)`.
  final List<(EffectArt, StageActor, int)> effects;

  final int travelerDx;
  final int enemyDx;

  /// Shown HP, possibly mid-tween. Rounded for display.
  final double enemyHp;
  final double playerHp;

  final int? heal;
  final int healRise;
  final bool heavyFlash;

  bool sameAs(_Shot o) {
    if (travelerTrack != o.travelerTrack ||
        travelerFrame != o.travelerFrame ||
        enemyTrack != o.enemyTrack ||
        enemyFrame != o.enemyFrame ||
        travelerDx != o.travelerDx ||
        enemyDx != o.enemyDx ||
        enemyHp.round() != o.enemyHp.round() ||
        playerHp.round() != o.playerHp.round() ||
        heal != o.heal ||
        healRise != o.healRise ||
        heavyFlash != o.heavyFlash ||
        effects.length != o.effects.length) {
      return false;
    }
    for (int i = 0; i < effects.length; i++) {
      if (effects[i] != o.effects[i]) return false;
    }
    return true;
  }
}

class _CombatStageState extends State<CombatStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.idleVisit)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  late CombatantArt _traveler;
  CombatantArt? _enemy;
  late EffectArt _strikeEffect;

  _Phase _phase = _Phase.spent;

  List<StageSegment> _segments = const <StageSegment>[];
  int _index = 0;

  /// Time spent in the segments before the current one — the idle clock for
  /// a figure that has no track in the current segment.
  Duration _sequenceBase = Duration.zero;

  /// HP as shown: the committed value between rounds, the tween while a
  /// segment plays. The tween starts from these and ends on the beat's value.
  late double _enemyHp;
  late double _playerHp;
  double _enemyHpFrom = 0;
  double _playerHpFrom = 0;
  late int _turn;
  late bool _telegraph;

  /// The pose the enemy holds after a defeat (or a stood-in defeat), or `null`
  /// while it idles.
  (CombatTrack, int)? _heldEnemy;

  /// The pose the Traveler holds after his stagger — down on one knee, kept
  /// through the settle beat and the outcome panel — or `null` while he
  /// idles. The Traveler's mirror of [_heldEnemy], same shape, same life:
  /// set at a `travelerHoldsPose` segment's end, cleared by the next
  /// sequence.
  (CombatTrack, int)? _heldTraveler;

  late _Shot _shot;
  bool _precached = false;
  bool _heldByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindArt();
    _syncFromView();
    _shot = _shotAt(Duration.zero);
    _beginIdle();
  }

  void _bindArt() {
    _traveler = CombatAssets.traveler;
    _enemy = CombatAssets.enemyFor(widget.view.enemyId);
    _strikeEffect = CombatAssets.strikeEffectOf(widget.view.enemyId);
  }

  void _syncFromView() {
    final EncounterView v = widget.view;
    _enemyHp = v.enemyHp.toDouble();
    _playerHp = v.playerHp.toDouble();
    _turn = v.turn;
    _telegraph = v.telegraph;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final String frame in CombatAssets.framesFor(
      widget.view.enemyId,
      widget.view.location,
    )) {
      precacheImage(AssetImage(frame), context);
    }
  }

  @override
  void didUpdateWidget(CombatStage old) {
    super.didUpdateWidget(old);
    if (widget.view.enemyId != old.view.enemyId) _bindArt();
    final CombatReport? r = widget.report;
    if (r != null && !identical(r, old.report) && r.succeeded) {
      final List<StageSegment> segments = choreograph(
        r.events,
        traveler: _traveler,
        enemy: _enemy,
        strikeEffect: _strikeEffect,
      );
      if (segments.isNotEmpty) {
        // A new encounter's first report — its start beat only — carries no
        // segments and falls through to the sync below.
        _startSequence(segments);
        return;
      }
    }
    if (_phase != _Phase.playing && !widget.ended) {
      _syncFromView();
      _shot = _shotAt(_elapsed);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_heldByLifecycle) {
        _heldByLifecycle = false;
        _controller.forward();
      } else if (_phase == _Phase.spent) {
        // Coming back to the app is what an idle visit is.
        _beginIdle();
      }
      return;
    }
    if (_controller.isAnimating) {
      _heldByLifecycle = true;
      _controller.stop();
    }
  }

  // ------------------------------------------------------------ the machine

  void _beginIdle() {
    _heldByLifecycle = false;
    _phase = _Phase.idle;
    _sequenceBase = Duration.zero;
    _controller
      ..duration = widget.idleVisit
      ..forward(from: 0);
  }

  void _startSequence(List<StageSegment> segments) {
    if (_phase == _Phase.playing) _applyRemaining();
    _segments = segments;
    _index = 0;
    _sequenceBase = Duration.zero;
    _phase = _Phase.playing;
    _heldEnemy = null;
    _heldTraveler = null;
    _notifyPlaying(true);
    _startSegment();
  }

  void _startSegment() {
    final StageSegment s = _segments[_index];
    _enemyHpFrom = _enemyHp;
    _playerHpFrom = _playerHp;
    if (s.turn case final int t) _turn = t;
    if (s.telegraph case final bool t) _telegraph = t;
    _controller
      ..duration = s.duration
      ..forward(from: 0);
    _refresh(Duration.zero);
  }

  void _endSegment() {
    final StageSegment s = _segments[_index];
    _applySegmentEnd(s);
    _sequenceBase += s.duration;
    if (_index + 1 < _segments.length) {
      _index += 1;
      _startSegment();
    } else {
      _finishSequence();
    }
  }

  void _applySegmentEnd(StageSegment s) {
    if (s.enemyHpTo case final int hp) _enemyHp = hp.toDouble();
    if (s.playerHpTo case final int hp) _playerHp = hp.toDouble();
    if (s.turn case final int t) _turn = t;
    if (s.telegraph case final bool t) _telegraph = t;
    if (s.enemyHoldsPose) {
      if (s.enemyTrack case final CombatTrack t) {
        _heldEnemy = (t, t.frameCount - 1);
      }
    }
    if (s.travelerHoldsPose) {
      if (s.travelerTrack case final CombatTrack t) {
        _heldTraveler = (t, t.frameCount - 1);
      }
    }
  }

  /// Every remaining segment's end state, at once — the skip.
  void _applyRemaining() {
    for (int i = _index; i < _segments.length; i++) {
      _applySegmentEnd(_segments[i]);
    }
  }

  void _finishSequence() {
    _segments = const <StageSegment>[];
    _index = 0;
    // The last beat's figures are the commit's figures; the live view says
    // the same. Reading it here covers a round whose beats carried no HP.
    if (!widget.ended) _syncFromView();
    _beginIdle();
    _refresh(Duration.zero);
    _notifyPlaying(false);
  }

  /// A tap on the stage while a round plays: jump to its end state.
  void _skip() {
    if (_phase != _Phase.playing) return;
    _controller.stop();
    _applyRemaining();
    _finishSequence();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    switch (_phase) {
      case _Phase.playing:
        _endSegment();
      case _Phase.idle:
        _phase = _Phase.spent;
        _refresh(Duration.zero);
      case _Phase.spent:
        break;
    }
  }

  /// Both callbacks can fire from `didUpdateWidget` — a report arrives during
  /// this widget's own build — so the parent's `setState` waits for the end
  /// of the frame (`AmbientStage._rebuild`).
  void _notifyPlaying(bool playing) {
    final ValueChanged<bool>? cb = widget.onPlayingChanged;
    if (cb == null) return;
    final SchedulerBinding binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) cb(playing);
      });
      return;
    }
    cb(playing);
  }

  // --------------------------------------------------------------- frames

  Duration get _elapsed {
    final Duration d = _controller.duration ?? Duration.zero;
    return d * _controller.value;
  }

  void _onTick() => _refresh(_elapsed);

  void _refresh(Duration elapsed) {
    final _Shot next = _shotAt(elapsed);
    if (next.sameAs(_shot)) return;
    if (!mounted) {
      _shot = next;
      return;
    }
    // Inside a build (didUpdateWidget) the state is simply set; the build in
    // progress reads it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _shot = next;
      return;
    }
    setState(() => _shot = next);
  }

  /// The idle frame of [t] at [clock], looping — a modulo, not the track's
  /// clamped `frameAt`, so a figure idling through a long round never
  /// freezes on the pass's last slot.
  int _idleFrame(CombatTrack t, Duration clock) {
    final int passUs = t.duration.inMicroseconds;
    if (passUs <= 0) return 0;
    return t.frameAt(Duration(microseconds: clock.inMicroseconds % passUs));
  }

  double _tween(double from, int? to, StageSegment s, Duration e) {
    if (to == null) return from;
    if (e >= s.hpTweenEnd) return to.toDouble();
    if (e <= s.hpTweenStart) return from;
    final int span = (s.hpTweenEnd - s.hpTweenStart).inMicroseconds;
    final double f = span <= 0 ? 1 : (e - s.hpTweenStart).inMicroseconds / span;
    return from + (to - from) * f;
  }

  int _recoilAt(Duration since) {
    if (since < Duration.zero || since >= recoilDuration) return 0;
    final double f = 1 - since.inMicroseconds / recoilDuration.inMicroseconds;
    return (6 * f).round();
  }

  _Shot _shotAt(Duration elapsed) {
    final CombatantArt? enemy = _enemy;
    final Duration clock = _sequenceBase + elapsed;
    final bool moving = _phase != _Phase.spent;

    CombatTrack travelerTrack = _traveler.idle;
    int travelerFrame = moving ? _idleFrame(_traveler.idle, clock) : 0;
    if (_heldTraveler case (final CombatTrack t, final int f)) {
      travelerTrack = t;
      travelerFrame = f;
    }
    CombatTrack? enemyTrack = enemy?.idle;
    int enemyFrame = enemy != null && moving
        ? _idleFrame(enemy.idle, clock)
        : 0;
    if (_heldEnemy case (final CombatTrack t, final int f)) {
      enemyTrack = t;
      enemyFrame = f;
    }
    final List<(EffectArt, StageActor, int)> effects =
        <(EffectArt, StageActor, int)>[];
    int travelerDx = 0;
    int enemyDx = 0;
    double enemyHp = _enemyHp;
    double playerHp = _playerHp;
    int? heal;
    int healRise = 0;
    bool flash = false;

    if (_phase == _Phase.playing && _index < _segments.length) {
      final StageSegment s = _segments[_index];
      if (s.travelerTrack case final CombatTrack t
          when elapsed >= s.travelerStart) {
        travelerTrack = t;
        travelerFrame = t.frameAt(elapsed - s.travelerStart);
      }
      if (s.enemyTrack case final CombatTrack t when elapsed >= s.enemyStart) {
        enemyTrack = t;
        enemyFrame = t.frameAt(elapsed - s.enemyStart);
      }
      for (final StageEffect e in s.effects) {
        final Duration since = elapsed - e.start;
        if (since < Duration.zero || since >= e.art.duration) continue;
        effects.add((e.art, e.at, e.art.frameAt(since)));
      }
      switch (s.recoil) {
        case StageActor.enemy:
          enemyDx = _recoilAt(elapsed - s.recoilStart);
        case StageActor.traveler:
          travelerDx = -_recoilAt(elapsed - s.recoilStart);
        case null:
          break;
      }
      enemyHp = _tween(_enemyHpFrom, s.enemyHpTo, s, elapsed);
      playerHp = _tween(_playerHpFrom, s.playerHpTo, s, elapsed);
      if (s.heal case final int h) {
        heal = h;
        healRise = (12 * elapsed.inMicroseconds / s.duration.inMicroseconds)
            .round();
      }
      flash = s.heavyFlash && elapsed < const Duration(milliseconds: 400);
    }

    return _Shot(
      travelerTrack: travelerTrack,
      travelerFrame: travelerFrame,
      enemyTrack: enemyTrack,
      enemyFrame: enemyFrame,
      effects: effects,
      travelerDx: travelerDx,
      enemyDx: enemyDx,
      enemyHp: enemyHp,
      playerHp: playerHp,
      heal: heal,
      healRise: healRise,
      heavyFlash: flash,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final EncounterView v = widget.view;
    final _Shot shot = _shot;
    final bool playing = _phase == _Phase.playing;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int scale = widget.scale;
        final double full = (CombatAssets.backdropWidth * scale).toDouble();
        final double width = c.maxWidth.isFinite && c.maxWidth < full
            ? c.maxWidth.floorToDouble()
            : full;
        return Semantics(
          label: playing
              ? 'Combat stage. Tap to skip the replay.'
              : 'Combat stage: Traveler against ${v.enemyName}.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: playing ? _skip : null,
            child: Center(
              child: SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: StrideRadius.card,
                  child: ColoredBox(
                    color: StrideColors.surfaceGround,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        RepaintBoundary(
                          child: _Scene(
                            width: width,
                            scale: scale,
                            backdrop: CombatAssets.backdropFor(v.location),
                            traveler: _traveler,
                            enemy: _enemy,
                            shot: shot,
                            turn: _turn,
                            boss: v.isBoss,
                          ),
                        ),
                        _Hud(
                          view: v,
                          enemyHp: shot.enemyHp.round(),
                          playerHp: shot.playerHp.round(),
                          telegraph: _telegraph,
                          heavyFlash: shot.heavyFlash,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The picture: the backdrop, clipped and centred at ×2, and the figures on
/// its ground row.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.width,
    required this.scale,
    required this.backdrop,
    required this.traveler,
    required this.enemy,
    required this.shot,
    required this.turn,
    required this.boss,
  });

  final double width;
  final int scale;
  final String backdrop;
  final CombatantArt traveler;
  final CombatantArt? enemy;
  final _Shot shot;
  final int turn;
  final bool boss;

  @override
  Widget build(BuildContext context) {
    final int full = CombatAssets.backdropWidth * scale;
    final int height = CombatAssets.backdropHeight * scale;
    // Whole dp, so the backdrop stays on the pixel grid: (361 − 384) / 2 is
    // −11.5, drawn at −12.
    final int offset = ((width - full) / 2).floor();
    final int ground = CombatAssets.backdropGroundRow * scale;

    Widget figure(CombatTrack t, int frame, int column, int dx) {
      final int left =
          offset + column * scale - (t.footprint.centerX * scale).round() + dx;
      final int top = ground - t.anchorRow * scale;
      return Positioned(
        left: left.toDouble(),
        top: top.toDouble(),
        child: GroundedSprite(
          assetPath: t.frame(frame),
          footprint: t.footprint,
          scale: scale,
          canvas: t.canvasWidth,
          canvasHeight: t.canvasHeight,
        ),
      );
    }

    Widget effect((EffectArt, StageActor, int) e) {
      final (EffectArt art, StageActor at, int frame) = e;
      final int column = at == StageActor.traveler
          ? CombatAssets.travelerColumn
          : CombatAssets.enemyColumn;
      final int rise = at == StageActor.traveler
          ? traveler.impactRise
          : enemy?.impactRise ?? traveler.impactRise;
      final int half = art.canvas * scale ~/ 2;
      return Positioned(
        left: (offset + column * scale - half).toDouble(),
        top: (ground - rise * scale - half).toDouble(),
        child: PixelAsset(
          assetPath: art.frame(frame),
          nativeWidth: art.canvas,
          nativeHeight: art.canvas,
          scale: scale,
        ),
      );
    }

    final CombatantArt? e = enemy;
    return SizedBox(
      width: width,
      height: height.toDouble(),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned(
            left: offset.toDouble(),
            top: 0,
            child: PixelAsset(
              assetPath: backdrop,
              nativeWidth: CombatAssets.backdropWidth,
              nativeHeight: CombatAssets.backdropHeight,
              scale: scale,
            ),
          ),
          figure(
            shot.travelerTrack,
            shot.travelerFrame,
            CombatAssets.travelerColumn,
            shot.travelerDx,
          ),
          if (e != null && shot.enemyTrack != null)
            figure(
              shot.enemyTrack!,
              shot.enemyFrame,
              CombatAssets.enemyColumn,
              shot.enemyDx,
            ),
          for (final (EffectArt, StageActor, int) fx in shot.effects)
            effect(fx),
          // The turn, and BOSS, as chips in the sky's corners: the top-left
          // 60 dp is clear above the Traveler's head on every backdrop, and
          // the guardian's crown (opaque right edge 318 dp of the backdrop)
          // stops short of a top-right chip.
          Positioned(
            left: StrideSpace.s8,
            top: StrideSpace.s8,
            child: _Chip('TURN $turn'),
          ),
          if (boss)
            const Positioned(
              right: StrideSpace.s8,
              top: StrideSpace.s8,
              child: _Chip('BOSS'),
            ),
          if (shot.heal case final int heal)
            Positioned(
              left: (offset + CombatAssets.travelerColumn * scale - 24)
                  .toDouble(),
              top: (ground - traveler.idle.anchorRow * scale - shot.healRise)
                  .toDouble(),
              child: SizedBox(
                width: 48,
                child: Text(
                  '+$heal',
                  textAlign: TextAlign.center,
                  style: StrideType.numericValue.copyWith(
                    color: StrideColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small dark label over the scene.
class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xCC14120F),
      borderRadius: StrideRadius.chip,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StrideSpace.s6,
        vertical: StrideSpace.s4,
      ),
      child: Text(
        label,
        style: StrideType.microLabel.copyWith(color: StrideColors.textPrimary),
      ),
    ),
  );
}

/// The strip beneath the picture: both fighters' names, bars and figures, the
/// turn, and the telegraph line when it is set.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.view,
    required this.enemyHp,
    required this.playerHp,
    required this.telegraph,
    required this.heavyFlash,
  });

  final EncounterView view;
  final int enemyHp;
  final int playerHp;
  final bool telegraph;
  final bool heavyFlash;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      StrideSpace.s12,
      StrideSpace.s10,
      StrideSpace.s12,
      StrideSpace.s10,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _Combatant(
                name: 'Traveler',
                hp: playerHp,
                maxHp: view.playerMaxHp,
                alignEnd: false,
              ),
            ),
            const SizedBox(width: StrideSpace.s16),
            Expanded(
              child: _Combatant(
                name: view.enemyName,
                hp: enemyHp,
                maxHp: view.enemyMaxHp,
                alignEnd: true,
              ),
            ),
          ],
        ),
        if (telegraph) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Text(
            'The ${view.enemyName} gathers itself…',
            textAlign: TextAlign.center,
            // A heavy blow landing brightens the line for a moment. The
            // palette has no warning hue and this deliberately does not add
            // one (StrideColors); weight and value carry it.
            style: heavyFlash
                ? StrideType.sub.copyWith(
                    color: StrideColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  )
                : StrideType.sub.copyWith(color: StrideColors.textPrimary),
            maxLines: 2,
          ),
        ],
      ],
    ),
  );
}

/// One name, one bar, one `hp / max`.
class _Combatant extends StatelessWidget {
  const _Combatant({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.alignEnd,
  });

  final String name;
  final int hp;
  final int maxHp;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: <Widget>[
      // Shrinks rather than truncates: "Hollow Guardian" is 15 characters
      // and the column is about 138 dp on a 393 dp phone, less on a 320.
      AdaptiveText(
        name,
        style: StrideType.sectionHeading,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      ),
      const SizedBox(height: StrideSpace.s4),
      _HpBar(fraction: maxHp <= 0 ? 0 : (hp / maxHp).clamp(0, 1)),
      const SizedBox(height: StrideSpace.s2),
      Text(
        '$hp / $maxHp',
        style: StrideType.numericValue.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

/// A 6 dp bar. Fill on the text ladder, never the teal: teal is walking and
/// banked steps only (`ART_DIRECTION.md` L-16), and health is neither.
class _HpBar extends StatelessWidget {
  const _HpBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) {
      final double w = c.maxWidth.isFinite ? c.maxWidth : 96;
      // Whole dp, so the fill edge is crisp; a bar with any health shows at
      // least 2 dp of it.
      final double fill = fraction <= 0
          ? 0
          : (w * fraction).round().clamp(2, w.round()).toDouble();
      return SizedBox(
        width: w,
        height: 6,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: StrideColors.surfaceBlock,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: fill,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: StrideColors.textSecondary,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
