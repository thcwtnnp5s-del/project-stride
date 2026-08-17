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
import '../../components/adaptive_text.dart';
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
        //
        // **Deliberately left at full height.** The obvious facelift move is to
        // give it a `viewportHeight` so the legend arrives sooner. The map's
        // subjects are distributed over its whole length — the settlement at the
        // top, the mine mouths on the right flank, the ruin at the bottom — so
        // any crop that buys a screenful of scrolling deletes a place the legend
        // then names. Cropping the world to shorten a scroll is the wrong trade.
        const PixelScene.regionMap(PixelIcons.regionMap),

        // Where the player is, immediately under the picture, before any card.
        //
        // The screen's first question is "where am I?" and the answer was in the
        // first row of a legend 640 dp below the top of the page — reachable
        // only by scrolling past the entire map. The legend still carries it;
        // this puts it where the eye lands.
        _CurrentPlaceBar(places: places),
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

/// `YOU ARE HERE · Haven's Rest`, on the map's own lower edge.
///
/// A caption, not a control: no border, no fill that reads as a chip, nothing
/// tappable. The World screen's whole discipline is that it must not imply
/// travel (see this file's header), and a highlighted place name is exactly the
/// element that would — so it is set as a label above a name, the same pattern
/// every read-only figure in the app uses, rather than as a pin or a button.
class _CurrentPlaceBar extends StatelessWidget {
  const _CurrentPlaceBar({required this.places});

  final List<RegionPlace> places;

  @override
  Widget build(BuildContext context) {
    // `regionPlaces` puts the player's own location first, so this is a lookup
    // rather than a search — but it is written as one, because "first" is a
    // presentation choice in `StrideSession` and this must not silently depend
    // on it.
    RegionPlace? here;
    for (final RegionPlace place in places) {
      if (place.isCurrent) here = place;
    }
    if (here == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('YOU ARE HERE', style: StrideType.microLabel, maxLines: 1),
          const SizedBox(height: StrideSpace.s2),
          // `textPrimary`, NOT the teal `_PlaceRow` uses for the same place.
          // `ART_DIRECTION.md` L-16 reserves teal for walking, steps and banked
          // quantity — "nothing else, anywhere, ever" — and a place name is
          // none of those. The label above it is what carries the emphasis.
          //
          // The existing teal in `_PlaceRow` is left alone: it predates this
          // pass, changing it is an identity call rather than a layout one, and
          // it is raised for the owner in the facelift report instead of being
          // decided here (`RULES.md` G-3).
          AdaptiveText(here.displayName, style: StrideType.cardTitle),
        ],
      ),
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
