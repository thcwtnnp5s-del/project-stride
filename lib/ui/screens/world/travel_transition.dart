/// The travel transition: the Traveler walking, briefly, between the tap
/// that spends the steps and the panel that says where they landed
/// (Fable V2 Iteration 02).
///
/// ## What this is, and is not
///
/// Travel is the game's biggest spend and it resolved in a silent frame: tap
/// Set out, and the map has already moved. This card is the missing beat —
/// the committed walk **presented**, after the engine has committed it. It
/// is presentation only: it plays after `travelJourney` returns, decides
/// nothing, blocks nothing but its own ~1.3 s, and a relaunch has no card to
/// restore (`RULES.md` E-2). It is not free-roam, not a loading screen, and
/// not a progress bar — the walk it depicts has already happened.
///
/// ## The art
///
/// The six-frame west walk from the Traveler's own character set (packaged
/// by `package-art.js`; west only — the east cycle's vest vanishes on two
/// frames, and mirroring is a creative change PixelLab owns, `RULES.md`
/// A-2/A-1). It plays over the destination's alt vignette — the second
/// framing the atlas inspector already uses — grounded with the same
/// contact shadow as every standing figure.
///
/// ## Restraint, by construction
///
/// - Reduced motion skips the card entirely: the result line is the beat.
/// - The frames and backdrop are precached before the route is pushed, so
///   the card never opens half-loaded.
/// - One one-shot `AnimationController` drives the whole card — a ticker,
///   so `TickerMode` and the app lifecycle govern it like every other
///   animation, and the card dismisses itself when it completes.
/// - A tap dismisses early — a transition the player cannot skip is a delay
///   wearing a costume.
library;

import 'package:flutter/widgets.dart';

import '../../components/pixel_asset.dart';
import '../../components/grounded_sprite.dart';
import '../../icons/sprite_footprints.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

const String _art = 'assets/art/v1';
const int _frameCount = 6;
const Duration _framePace = Duration(milliseconds: 110);

/// Two passes of the six-frame cycle.
const int _passes = 2;

List<String> get _walkFrames => List<String>.generate(
  _frameCount,
  (int i) => '$_art/anim/traveler_walk_west_f$i.png',
  growable: false,
);

/// Plays the walk card over [backdrop] and resolves when it has finished or
/// been tapped away. Under Reduce Motion it resolves immediately — the
/// travel result line is then the whole beat.
Future<void> showTravelTransition(
  BuildContext context, {
  required String? backdrop,
  required String destinationName,
}) async {
  if (MediaQuery.disableAnimationsOf(context)) return;
  // Precache so the card opens whole (Iteration 02, PERF-A): a walk cycle
  // whose third frame pops in from disk reads as a glitch, not a journey.
  // Bounded, not gating: image decode never completes under a widget test's
  // fake async, and a transition that can stall the travel flow is worse
  // than one that opens a frame early. On a device the cache wins the race.
  await Future.any(<Future<void>>[
    Future.wait(<Future<void>>[
      for (final String frame in _walkFrames)
        precacheImage(AssetImage(frame), context),
      if (backdrop != null) precacheImage(AssetImage(backdrop), context),
    ]),
    Future<void>.delayed(const Duration(milliseconds: 250)),
  ]);
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Travelling',
    barrierColor: const Color(0xB314120F),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
        _TravelCard(backdrop: backdrop, destinationName: destinationName),
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
  const _TravelCard({required this.backdrop, required this.destinationName});

  final String? backdrop;
  final String destinationName;

  @override
  State<_TravelCard> createState() => _TravelCardState();
}

class _TravelCardState extends State<_TravelCard>
    with SingleTickerProviderStateMixin {
  static final int _totalSlots = _frameCount * _passes;

  late final AnimationController _clock;

  int _frame = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Created eagerly in initState — a `late final` cascade would create
    // the controller on first touch, and if that first touch were dispose
    // (a card torn down before its first frame) the vsync registration
    // would look up a deactivated ancestor.
    _clock =
        AnimationController(vsync: this, duration: _framePace * _totalSlots)
          ..addListener(() {
            final int slot = (_clock.value * _totalSlots).floor().clamp(
              0,
              _totalSlots - 1,
            );
            final int frame = slot % _frameCount;
            if (frame != _frame) setState(() => _frame = frame);
          })
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed) _dismiss();
          })
          ..forward();
  }

  void _dismiss() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _dismiss,
    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: StrideSpace.s16),
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
                  if (widget.backdrop case final String art)
                    PixelScene.vignette(art, viewportHeight: 132)
                  else
                    const ColoredBox(color: StrideColors.surfaceBlock),
                  // The figure walks in place near the card's lower third;
                  // the west cycle leads with its left foot toward the road.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: Center(
                      child: RepaintBoundary(
                        child: GroundedSprite(
                          assetPath: _walkFrames[_frame],
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
              child: Text(
                'On the road to ${widget.destinationName}',
                textAlign: TextAlign.center,
                style: StrideType.sub.copyWith(color: StrideColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
