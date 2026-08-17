/// Where the player is, where they can go, and what the journey costs.
///
/// ## What changed in Phase 2, and why the change was allowed
///
/// This screen used to carry a written prohibition, and it is worth preserving
/// the shape of it because it is the argument that had to be answered before a
/// button could appear here:
///
/// > It answers "where am I?" and "where can I eventually go?". It does not
/// > answer "how do I get there", because nothing in `stride_core` can. …
/// > **Nothing on this screen is a control.** … A `Travel` button here would be
/// > the most convincing lie in the demo: the map draws the roads, the content
/// > pack supplies real costs, and the player has real banked steps to spend.
/// > Every part of the illusion is present except the system.
///
/// **The system now exists.** `TravelTo` spends banked steps, moves the player
/// atomically, and is refused when the route, the requirements or the balance
/// do not allow it (`DECISIONS/0017`). So the affordance is no longer an
/// illusion, and the prohibition has been satisfied rather than overridden.
///
/// The distinction that mattered then still holds now: **a control may exist
/// here only because a command exists behind it.** Every button on this screen
/// dispatches `SessionController.travel`, and every disabled one says which of
/// the engine's own refusals it is anticipating. Nothing is computed here that
/// the engine does not also check.
///
/// ## Still not a joystick
///
/// Travel is strategic menu travel powered by real steps. There is no free
/// roam, no avatar token on the map, no drag, and no real-time walking figure.
/// The map remains an image with no hit testing; the controls are rows.
///
/// ## The current location is marked by weight, not by teal
///
/// `_PlaceRow` used to colour the player's own location with
/// `StrideColors.accentSteps`. `ART_DIRECTION.md` **L-16** reserves that teal
/// for *"walking, steps, and banked-step quantity — nothing else, anywhere,
/// ever"*, and a place name is none of those. It shipped anyway, and the UI
/// facelift's first pass deliberately left it alone as an identity question for
/// the owner (`JOURNAL/OPEN_QUESTIONS.md` Q-04).
///
/// **Leaving it stopped being defensible when the composition pass surfaced
/// it.** Moving the `YOU ARE HERE` caption onto the map brought the region card
/// above the fold, so a teal place name now sits in a bordered card at the
/// bottom of a map — and independent Visual QA, reading the render cold, called
/// it *a travel button to Haven's Rest*. That is the single affordance this
/// screen exists to refuse, arriving through a colour rather than through a
/// widget.
///
/// So the accent is removed and the row is marked by weight instead. This is
/// **not** the owner's Q-04 decision being taken here: it restores the state the
/// rule already requires. Whether the current location should have a colour of
/// its own remains open, and Q-04 stays open with it.
///
/// ## Why the map is a picture rather than a diagram
///
/// The illustrated map shows roads, a settlement, a mine mouth, a ruin. It must
/// not imply a joystick, free roam, or a character token that walks. There is no
/// avatar on it and no "you are here" pin that could be dragged — the current
/// location is named in the legend, in words, where a caption belongs.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Terrain;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
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
        // ## The travel card comes before the map, and that is a Phase 2 change
        //
        // The map is 640 px tall and is deliberately **not** cropped: its
        // subjects are distributed over its whole length — the settlement at the
        // top, the mine mouths on the right flank, the ruin at the bottom — so
        // any crop that buys a screenful of scrolling deletes a place the legend
        // then names. Cropping the world to shorten a scroll is the wrong trade,
        // and that reasoning is unchanged.
        //
        // What changed is the screen's job. In Phase 1 this was presentation, so
        // opening with the picture was right. It now carries the milestone's
        // main new control, and behind a 640 px image that control was
        // **entirely below the fold** — about 77 dp of the travel card visible
        // on a 393 × 852 phone. A feature the owner is meant to spend a week
        // testing should not require a scroll to discover.
        //
        // So the order follows the screen's question: *where can I go and what
        // does it cost*, then *what else is out there*, then the picture. Both
        // text sections are within a short scroll; the map is a full-bleed
        // illustration you arrive at rather than one you scroll past.
        //
        // Putting the map between them was tried and is worse: the legend
        // landed ~900 dp down, far enough that the lazy `ListView` had not even
        // built it — which is a fair proxy for "no player will see this".
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.screenGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: StrideSpace.s12),
              if (s.isStale) ...<Widget>[
                StaleBanner(busy: c.busy, onReload: c.reload),
                const SizedBox(height: StrideSpace.cardGap),
              ],
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(label: 'Travel from here'),
                    const SizedBox(height: StrideSpace.s10),
                    if (s.destinations.isEmpty)
                      Text(
                        'No route leads anywhere from here.',
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textMuted,
                        ),
                      ),
                    for (final TravelOption option in s.destinations)
                      _DestinationRow(option: option),
                    if (c.lastTravel != null) ...<Widget>[
                      const SizedBox(height: StrideSpace.s8),
                      _TravelResult(report: c.lastTravel!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: StrideSpace.cardGap),

              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(label: 'This region'),
                    const SizedBox(height: StrideSpace.s10),
                    for (final RegionPlace place in places)
                      _PlaceRow(place: place),
                    const SizedBox(height: StrideSpace.s4),
                    // The old line here said travel was not built. It is, so the
                    // sentence that remains is the one still worth saying: this
                    // list is the whole world, including the parts no road
                    // reaches from where the player is standing.
                    Text(
                      'Every place in the region. Routes run only between '
                      'neighbours, so some are reached by way of another.',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StrideSpace.cardGap),
            ],
          ),
        ),

        // Where the player is, written **on** the map's lower edge rather than
        // under it.
        //
        // The caption used to sit below the image as a separate block, which the
        // owner's device review read as "a large static image, then a label" —
        // two objects, with the relationship between them left to inference. On
        // the picture, over the same gradient the Adventure vignette uses, the
        // map and the place it says you are standing in are one object, and the
        // two art bands in the app now share a treatment.
        //
        // Still a caption, still not a control: no pin, no marker, nothing
        // tappable, and it names the place in words at the frame's edge rather
        // than pointing at a coordinate. A mark *on* the terrain is the thing a
        // player tries to drag, which is the affordance this screen must not
        // assert.
        PixelScene.regionMap(
          PixelIcons.regionMap,
          overlay: Align(
            alignment: Alignment.bottomLeft,
            child: _CurrentPlaceBar(places: places),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s16,
        StrideSpace.screenGutter,
        StrideSpace.s10,
      ),
      // A gradient, not a plate. Same reason and same values as the Adventure
      // vignette's caption: the map's lower edge is forest and trail, and a
      // solid band would cut the picture with a hard line where a gradient lets
      // the ground run out under the text.
      //
      // Three stops, not two, and the middle one is why. A linear fade reaches
      // only about a third of its opacity where `YOU ARE HERE` sits, and that
      // label lands on lit forest canopy — the brightest part of the map's
      // lower edge. The first render of this had a muted 11 px label over pale
      // green. Reaching most of the way to opaque by the time the text starts
      // keeps the whole caption legible while still letting the ground run out
      // under it rather than being cut by a plate.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x00000000),
            Color(0xC414120F),
            Color(0xF214120F),
          ],
          stops: <double>[0, 0.42, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

/// One journey the player could set out on.
///
/// The row is the control. Every reason it might be disabled is stated on it,
/// because a grey button with no sentence beside it is indistinguishable from a
/// broken one — and because the reasons are actionable in different ways: a
/// shortfall means walk, a requirement means go and make something.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.option});

  final TravelOption option;

  @override
  Widget build(BuildContext context) {
    final SessionController watched = SessionScope.of(context);
    final SessionController controller = SessionScope.read(context);
    final int banked = watched.session.usableEnergy;
    final bool enabled =
        option.canTravel && !watched.busy && watched.session.isReady;

    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  option.displayName,
                  style: StrideType.itemName,
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              // The step figure keeps the muted "steps as a unit" glyph it had
              // as a distance. It is a price now, but it is still a quantity of
              // steps rather than the player's own balance, and L-16's two-tone
              // rule turns on exactly that distinction.
              const WalkingGlyph(role: WalkingRole.unit),
              const SizedBox(width: StrideSpace.s4),
              AdaptiveText(
                formatSteps(option.stepCost),
                style: StrideType.itemCount,
                color: option.affordable
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          AdaptiveText(
            _subtitle(option, banked),
            style: StrideType.micro,
            color: StrideColors.textMuted,
          ),
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(
            label: watched.busy ? 'Travelling…' : 'Travel',
            onPressed: enabled ? () => controller.travel(option.id) : null,
          ),
        ],
      ),
    );
  }

  /// The one line that explains the row.
  ///
  /// Ordered the way the engine refuses: the requirement first, then the price.
  /// Telling a player they are 400 steps short of Forgotten Hollow, when the
  /// real answer is that it needs a Bronze Sword, sends them walking toward a
  /// wall they will still hit.
  static String _subtitle(TravelOption option, int banked) {
    if (option.isBlocked) {
      return 'Needs ${option.missingRequirements.join(', ')}';
    }
    if (!option.affordable) {
      return 'Walk ${formatSteps(option.shortfallFrom(banked))} more steps';
    }
    final String places = option.resourceCount == 1
        ? '1 resource'
        : '${option.resourceCount} resources';
    return option.isReached
        ? '${_terrainWord(option)} · $places'
        : 'Not yet reached · ${_terrainWord(option)} · $places';
  }

  /// The terrain, as a word a player would use rather than an enum name.
  static String _terrainWord(TravelOption option) => switch (option.terrain) {
    Terrain.grassland => 'Grassland',
    Terrain.forest => 'Forest',
    Terrain.foothills => 'Foothills',
    Terrain.alpine => 'Alpine',
  };
}

class _TravelResult extends StatelessWidget {
  const _TravelResult({required this.report});

  final TravelReport report;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: AdaptiveText(
      report.succeeded
          ? report.firstVisit
                ? 'Arrived at ${report.destinationName} for the first time · '
                      '${formatSteps(report.cost)} steps'
                : 'Arrived at ${report.destinationName} · '
                      '${formatSteps(report.cost)} steps'
          : _refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  /// Keyed on the stable wire code, never on the explanation sentence.
  static String _refusalText(TravelReport report) => switch (report.rejection) {
    'insufficient_steps' => 'Not enough banked steps for that journey.',
    'entry_requirement_unmet' =>
      'You are not carrying what that place requires.',
    'route_not_found' => 'No route runs there from here.',
    'already_at_location' => 'You are already there.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before travelling again.',
    _ => 'You could not travel there.',
  };
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
                    color: StrideColors.textPrimary,
                    // The current location leads the list and its detail line
                    // says `You are here`; the weight is what marks it, not a
                    // hue. Colouring the others by unlock state would read as an
                    // availability system — which is exactly the affordance this
                    // screen must not assert.
                    fontWeight: place.isCurrent
                        ? FontWeight.w700
                        : FontWeight.w600,
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
