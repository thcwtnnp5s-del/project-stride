/// The travel transition: the committed walk, presented as a journey rather
/// than a flash (Fable V2 Iteration 02; re-paced by
/// GAME_FEEL_CHARACTER_PRESENTATION_01 after the owner's device verdict —
/// "good directionally, but MUCH too fast").
///
/// ## What this is, and is not
///
/// Travel is the game's biggest spend and it used to resolve in ~1.3 s. This
/// card is the walk **presented**, after the engine has committed it. It is
/// presentation only: it plays after `travelJourney` returns, decides
/// nothing, and a relaunch has no card to restore (`RULES.md` E-2). It is
/// not a loading screen and not a progress bar — the walk it depicts has
/// already happened, and its length answers to `TravelPacing`, which scales
/// with the route's hop count and **never** with step cost or wall time.
///
/// ## The shape of the journey
///
/// Departure over the origin's framing (also the unskippable window — it
/// absorbs the reflex tap that follows Set out), the travel loop over the
/// destination's framing with the journey's committed cost, an arrival
/// anticipation, then one rest pass — the walk settles on its standing
/// frame under "Arrived at …" and the card dismisses itself.
///
/// The map's travel trace mirrors this card's own controller through
/// [TravelPresentationLink], so the dot on the atlas and the walking figure
/// are two views of one clock and cannot disagree — including under skip.
///
/// ## The art
///
/// The six-frame west walk from the Traveler's own character set, at its
/// authored 110 ms cadence — the longer hold is more passes, never slower
/// frames. It plays over the origin's and destination's alt vignettes, the
/// second framings the atlas inspector already uses.
///
/// ## Restraint, by construction
///
/// - Reduced motion skips the card entirely: the result line is the beat
///   (`MILESTONES/FABLE_V2_EXPERIMENT_01.md` checklist item 17 stays true).
/// - After the departure window a tap skips **to the arrival phase**, not
///   to nothing: an accidental tap loses the journey's middle, never the
///   arrival information. The skip surface is a real, labeled semantics
///   button, so assistive tech is never trapped behind an opaque gesture.
/// - One one-shot `AnimationController` drives the whole card; `TickerMode`
///   and the app lifecycle govern it like every other animation.
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart' show EquipmentVisualState;
import '../../components/pixel_asset.dart';
import '../../components/grounded_sprite.dart';
import '../../icons/sprite_footprints.dart';
import '../../icons/traveler_art.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'travel_pacing.dart';

/// Plays the journey card and resolves when it has finished or been skipped
/// to its arrival. Under Reduce Motion it resolves immediately — the travel
/// result line is then the whole beat.
Future<void> showTravelTransition(
  BuildContext context, {
  required String? backdrop,
  required String destinationName,
  String? originBackdrop,
  String? originName,
  int legs = 1,
  int stepsSpent = 0,
  EquipmentVisualState equipment = EquipmentVisualState.none,
}) async {
  if (MediaQuery.disableAnimationsOf(context)) return;
  // The walk cycle, resolved through the visible-equipment seam
  // (`TravelerArt`, item 5) — the base strip until an armor round lands.
  final List<String> walkFrames = TravelerArt.walkWestFor(equipment);
  // Precache so the card opens whole (Iteration 02, PERF-A). Bounded, not
  // gating: image decode never completes under a widget test's fake async,
  // and a transition that can stall the travel flow is worse than one that
  // opens a frame early. On a device the cache wins the race.
  await Future.any(<Future<void>>[
    Future.wait(<Future<void>>[
      for (final String frame in walkFrames)
        precacheImage(AssetImage(frame), context),
      if (backdrop != null) precacheImage(AssetImage(backdrop), context),
      if (originBackdrop != null)
        precacheImage(AssetImage(originBackdrop), context),
    ]),
    Future<void>.delayed(const Duration(milliseconds: 250)),
  ]);
  if (!context.mounted) return;
  // The one announcement, so a screen-reader user hears the journey the
  // sighted user watches (the barrier label alone is not an announcement).
  SemanticsService.sendAnnouncement(
    View.of(context),
    'Travelling to $destinationName',
    Directionality.of(context),
  );
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Travelling',
    // Lighter than the old 0xB3 dim: the atlas behind the card is the
    // journey's second view — the trace dot riding the same clock — and a
    // barrier dark enough to hide it wastes the synchronization.
    barrierColor: const Color(0x6614120F),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
        _TravelCard(
          backdrop: backdrop,
          originBackdrop: originBackdrop,
          destinationName: destinationName,
          originName: originName,
          legs: legs,
          stepsSpent: stepsSpent,
          walkFrames: walkFrames,
        ),
    transitionBuilder:
        (
          BuildContext ctx,
          Animation<double> a,
          Animation<double> b,
          Widget child,
        ) => FadeTransition(opacity: a, child: child),
  );
}

class _TravelCard extends StatefulWidget {
  const _TravelCard({
    required this.backdrop,
    required this.originBackdrop,
    required this.destinationName,
    required this.originName,
    required this.legs,
    required this.stepsSpent,
    required this.walkFrames,
  });

  final String? backdrop;
  final String? originBackdrop;
  final String destinationName;
  final String? originName;
  final int legs;
  final int stepsSpent;
  final List<String> walkFrames;

  @override
  State<_TravelCard> createState() => _TravelCardState();
}

class _TravelCardState extends State<_TravelCard>
    with SingleTickerProviderStateMixin {
  late final int _totalSlots =
      TravelPacing.walkFrameCount * TravelPacing.passesForLegs(widget.legs);

  late final AnimationController _clock;

  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Created eagerly in initState — a `late final` cascade would create
    // the controller on first touch, and if that first touch were dispose
    // (a card torn down before its first frame) the vsync registration
    // would look up a deactivated ancestor.
    _clock =
        AnimationController(
            vsync: this,
            duration: TravelPacing.durationForLegs(widget.legs),
          )
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed) _dismiss();
          })
          ..forward();
    // The map trace mirrors this clock for as long as the card plays.
    // Registered after the frame, never during it: the link's listeners
    // live in other routes' trees, and a notify from initState is a
    // markNeedsBuild during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TravelPresentationLink.active.value = TravelPresentationHandle(
        clock: _clock,
        legs: widget.legs,
      );
    });
  }

  void _dismiss() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
  }

  bool get _skippable =>
      _clock.value >= TravelPacing.skipFractionForLegs(widget.legs);

  bool get _resting =>
      _clock.value >= TravelPacing.restFractionForLegs(widget.legs);

  /// A tap inside the departure window does nothing; after it, the journey
  /// jumps to its arrival phase — the rest pass still plays, the arrival
  /// line still shows, and only then does the card leave. A tap during the
  /// rest itself dismisses.
  void _onTap() {
    if (!_skippable) return;
    if (_resting) {
      _dismiss();
      return;
    }
    _clock.forward(from: TravelPacing.restFractionForLegs(widget.legs));
  }

  @override
  void dispose() {
    if (TravelPresentationLink.active.value?.clock == _clock) {
      TravelPresentationLink.active.value = null;
    }
    _clock.dispose();
    super.dispose();
  }

  String _caption(double t) {
    final int legs = widget.legs;
    if (t < TravelPacing.skipFractionForLegs(legs)) {
      final String? origin = widget.originName;
      return origin == null ? 'Setting out' : 'Leaving $origin';
    }
    if (t >= TravelPacing.restFractionForLegs(legs)) {
      return 'Arrived at ${widget.destinationName}';
    }
    if (t >= TravelPacing.anticipationFractionForLegs(legs)) {
      return 'Arriving at ${widget.destinationName}';
    }
    return 'On the road to ${widget.destinationName}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (BuildContext context, Widget? _) => Semantics(
      button: true,
      // Honest state: during the departure window the escape exists and
      // says so, but reports disabled and offers no action — assistive
      // tech is never handed a button that silently no-ops (FINAL-A N-1).
      enabled: _skippable,
      label: 'Skip travel',
      // Its own node, never merged into the caption text below it — the
      // whole point is that assistive tech can find the escape by name.
      container: true,
      onTap: _skippable ? _onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Center(
          child: Builder(
            builder: (BuildContext context) {
              final double t = _clock.value;
            final int slot = (t * _totalSlots).floor().clamp(
              0,
              _totalSlots - 1,
            );
            final bool resting =
                t >= TravelPacing.restFractionForLegs(widget.legs);
            final int frame =
                resting ? 0 : slot % TravelPacing.walkFrameCount;
            // The backdrop crossfades from origin to destination across the
            // travel loop's midpoint — one pass wide, so the switch reads
            // as the road passing rather than a cut.
            final double cross = TravelPacing.crossfadeFractionForLegs(
              widget.legs,
            );
            final double halfPass =
                0.5 / TravelPacing.passesForLegs(widget.legs);
            final double destOpacity = widget.originBackdrop == null
                ? 1
                : ((t - (cross - halfPass)) / (2 * halfPass)).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: StrideSpace.s16,
              ),
              constraints: const BoxConstraints(maxWidth: 361),
              decoration: BoxDecoration(
                color: StrideColors.surfaceCard,
                border: Border.all(color: StrideColors.borderDefault),
                borderRadius: StrideRadius.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: 132,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (widget.originBackdrop case final String origin)
                          PixelScene.vignette(origin, viewportHeight: 132)
                        else if (widget.backdrop == null)
                          const ColoredBox(color: StrideColors.surfaceBlock),
                        if (widget.backdrop case final String art)
                          Opacity(
                            opacity: destOpacity,
                            child: PixelScene.vignette(
                              art,
                              viewportHeight: 132,
                            ),
                          ),
                        // The figure walks in place near the card's lower
                        // third; the west cycle leads toward the road.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 2,
                          child: Center(
                            child: RepaintBoundary(
                              child: GroundedSprite(
                                assetPath: widget.walkFrames[frame],
                                footprint: SpriteFootprints.travelerWalkWest,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StrideSpace.s12,
                      vertical: StrideSpace.s8,
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          _caption(t),
                          textAlign: TextAlign.center,
                          style: StrideType.sub.copyWith(
                            color: StrideColors.textPrimary,
                          ),
                        ),
                        if (widget.stepsSpent > 0) ...<Widget>[
                          const SizedBox(height: StrideSpace.s2),
                          Text(
                            '${widget.stepsSpent} steps',
                            textAlign: TextAlign.center,
                            style: StrideType.micro.copyWith(
                              color: StrideColors.textSecondary,
                            ),
                          ),
                        ],
                        // The skip affordance: a stated option, not a
                        // control that invites a reach. Present only once
                        // the departure window has passed.
                        const SizedBox(height: StrideSpace.s4),
                        Opacity(
                          opacity: _skippable && !resting ? 1 : 0,
                          child: Text(
                            'Tap to continue',
                            textAlign: TextAlign.center,
                            style: StrideType.micro.copyWith(
                              color: StrideColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            },
          ),
        ),
      ),
    ),
  );
}
