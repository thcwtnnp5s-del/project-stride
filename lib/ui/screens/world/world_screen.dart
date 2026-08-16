/// Where the player is, and what else is out there.
///
/// ## The two questions this screen answers, and the one it must not
///
/// It answers **"where am I?"** and **"where can I eventually go?"**. It does
/// not answer "how do I get there", because nothing in `stride_core` can.
///
/// There is no travel activity at any layer. `EnterLocation` exists, and its own
/// comment records the gap: *"No travel cost here. Travel consumes steps over
/// time."* The command that spends banked steps to cross a route is not
/// written.
///
/// So **nothing on this screen is a control.** The map is an image with no hit
/// testing, the legend rows are text, and the step figures beside them are
/// labelled as distances rather than prices. A `Travel` button here would be the
/// most convincing lie in the demo: the map draws the roads, the content pack
/// supplies real costs, and the player has real banked steps to spend. Every
/// part of the illusion is present except the system.
///
/// ## Why the map is a picture rather than a diagram
///
/// The illustrated map shows roads, a settlement, a mine mouth, a ruin. It must
/// not imply a joystick, free roam, or a character token that walks. There is no
/// avatar on it and no "you are here" pin that could be dragged — the current
/// location is named in the legend, in words, where a caption belongs.
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class WorldScreen extends StatelessWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<RegionPlace> places = s.regionPlaces;

    return ListView(
      // Full-bleed map, gutters re-applied per child. Same reason as Adventure.
      padding: const EdgeInsets.only(bottom: StrideSpace.s16),
      children: <Widget>[
        // The whole map, at ×1, scrolling with the page. It is 640 px tall — no
        // phone shows it at once, and squeezing it into a viewport would mean
        // downscaling a picture whose roads are two pixels wide.
        const PixelScene.regionMap(PixelIcons.regionMap),
        const SizedBox(height: StrideSpace.cardGap),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.screenGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (s.isStale) ...<Widget>[
                StaleBanner(busy: c.busy, onReload: c.reload),
                const SizedBox(height: StrideSpace.cardGap),
              ],

              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(label: 'This region'),
                    const SizedBox(height: StrideSpace.s10),
                    for (final RegionPlace place in places)
                      _PlaceRow(place: place),
                    const SizedBox(height: StrideSpace.s4),
                    // Stated outright rather than left to be inferred from the
                    // absence of buttons. A player who cannot find the travel
                    // control will conclude it is broken, or hunt the map for a
                    // tappable road. Saying so costs one line and removes both.
                    Text(
                      'Travelling between places is not built yet. The step '
                      'figures above are how far apart they are, not something '
                      'you can spend yet.',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final RegionPlace place;

  @override
  Widget build(BuildContext context) {
    final String detail = <String>[
      if (place.isCurrent)
        'You are here'
      else if (!place.isUnlocked)
        'Not yet reached',
      if (place.isSafe) 'Safe',
      if (place.resourceCount == 1)
        '1 resource'
      else if (place.resourceCount > 1)
        '${place.resourceCount} resources',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  place.displayName,
                  style: StrideType.sub.copyWith(
                    // The current location is the only emphasis on the list.
                    // Colouring the others by unlock state would read as an
                    // availability system — which is exactly the affordance this
                    // screen must not assert.
                    color: place.isCurrent
                        ? StrideColors.accentSteps
                        : StrideColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: StrideType.micro, maxLines: 2),
              ],
            ),
          ),
          if (place.stepCostFromHere case final int cost) ...<Widget>[
            const SizedBox(width: StrideSpace.s8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Muted, never teal. Teal is reserved for steps the player owns
                // (`ART_DIRECTION.md` L-16), and this is a distance.
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.iconLabelGap),
                Text(formatSteps(cost), style: StrideType.micro),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
