/// Where the player is, where they can go, and what the journey costs — as a
/// World Atlas: a pannable window onto the region, with the places on it as
/// real targets, and one panel beneath that says what a tap means.
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
/// here only because a command exists behind it.** The one button on this
/// screen dispatches `SessionController.travel`, and when it is disabled the
/// panel says which of the engine's own refusals it is anticipating. Nothing is
/// computed here that the engine does not also check.
///
/// ## What changed in the Transformation Build, and what did not
///
/// The map used to be a picture with no hit testing, and the controls were rows
/// in a card above it. It is now an **atlas**: the same art, at ×2, on a
/// surface the player pans and pinches, with every place a tappable target
/// (`atlas/`). Tapping a place *selects* it; the panel under the viewport
/// describes it and — only for a place with a road from here — offers the
/// journey. The information is what the rows carried: name, terrain, resources,
/// price, and the refusal reasons in the engine's order.
///
/// **Still not a joystick.** Travel is strategic menu travel powered by real
/// steps. There is no free roam, no avatar token on the map, nothing that can
/// be dragged but the camera, and no figure that walks. The current location is
/// marked by a pulsing ring — a caption in the shape of a circle — and the
/// player moves only when the engine says they did.
///
/// ## The current location is marked by weight, not by teal
///
/// `ART_DIRECTION.md` **L-16** reserves the accent for *"walking, steps, and
/// banked-step quantity — nothing else, anywhere, ever"*, and a place name is
/// none of those. Independent Visual QA once read a teal place name in a card
/// under a map as *a travel button to Haven's Rest* — the single affordance
/// this screen exists to refuse, arriving through a colour. So the current
/// place is heavier and brighter, never teal, on the map label and in the
/// panel alike. Whether it should have a colour of its own remains the owner's
/// question (`JOURNAL/OPEN_QUESTIONS.md` Q-04).
///
/// ## When there is no atlas
///
/// The layout is presentation data read at startup
/// (`lib/runtime/atlas_layout.dart`). If it is missing or does not cover the
/// content pack, the session says so and this screen shows the pre-atlas
/// presentation — the travel card, the region list, the map as a picture — with
/// the problems printed on it in debug. Nothing about travel depends on the
/// atlas existing.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

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
import 'atlas/atlas_layout.dart';
import 'atlas/atlas_place_info.dart';
import 'atlas/atlas_selection_panel.dart';
import 'atlas/atlas_viewport.dart';

/// How much of the screen the viewport takes. The rest is the panel, which
/// scrolls; the atlas never does.
///
/// **0.5, down from 0.56.** The panel grew from a name and a price into an
/// inspector with two optional sections, and the balance that was right for
/// three lines is not right for a dozen. The floor went the other way — 200 to
/// 240 — because the thing the fraction protects is the *map's* usefulness on a
/// short window, and a 200 dp atlas is a keyhole. Between them the atlas keeps
/// half the screen on a phone and the panel scrolls for the rest, which is the
/// arrangement the screen has always had: the atlas never scrolls.
const double _viewportFraction = 0.5;
const double _viewportMinHeight = 240;
const double _viewportMaxHeight = 560;

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  /// The place the player tapped. Null means "the current location", which
  /// is what the panel shows until a tap and again after every journey — so
  /// arriving somewhere shows *here*, not the place that was here.
  ContentId? _selected;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final AtlasScene? scene = AtlasScene.build(s);

    if (scene == null) return _ListFallback(problems: s.atlasLayoutProblems);

    final AtlasNode selected =
        (_selected == null ? null : scene.nodeFor(_selected!)) ?? scene.current;

    // Resolved once per build, for every place on the surface, through the one
    // adapter this stream reads place detail with. The marker layer wants a
    // kind per node; nothing below it asks the session anything.
    final Map<ContentId, AtlasPlaceKind> kinds = <ContentId, AtlasPlaceKind>{
      for (final AtlasNode node in scene.nodes)
        node.id: AtlasPlaceInfo.kindOf(s, node.place),
    };
    // The preview: the roads the selected journey would use. Null for *here*
    // and for a place no chain of roads reaches, and nothing highlights then.
    final AtlasWay? way = scene.routeSummary(selected.id);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportHeight =
            (constraints.maxHeight * _viewportFraction).clamp(
              _viewportMinHeight,
              _viewportMaxHeight,
            );
        return Column(
          children: <Widget>[
            SizedBox(
              height: viewportHeight,
              width: double.infinity,
              child: AtlasViewport(
                scene: scene,
                selected: selected.id,
                kinds: kinds,
                way: way,
                onSelect: (ContentId id) => setState(() => _selected = id),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  StrideSpace.screenGutter,
                  StrideSpace.s12,
                  StrideSpace.screenGutter,
                  StrideSpace.s16,
                ),
                children: <Widget>[
                  if (s.isStale) ...<Widget>[
                    StaleBanner(busy: c.busy, onReload: c.reload),
                    const SizedBox(height: StrideSpace.cardGap),
                  ],
                  AtlasSelectionPanel(
                    scene: scene,
                    selected: selected,
                    onTravelled: () => setState(() => _selected = null),
                  ),
                  const SizedBox(height: StrideSpace.cardGap),
                  Text(
                    'Drag to look around; pinch to look closer. '
                    'Routes run only between neighbours, so some places are '
                    'reached by way of another. Faint names are landmarks — '
                    'geography, not destinations.',
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The pre-atlas presentation, kept whole for the day the layout is absent.
///
/// Every string and every rule here is the panel's; only the shape differs. It
/// is not a second implementation of travel — the rows and the panel share
/// `AtlasSelectionPanel.subtitleFor` and `TravelResultLine`.
class _ListFallback extends StatelessWidget {
  const _ListFallback({required this.problems});

  /// Why the atlas is absent. Rendered in debug only.
  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<RegionPlace> places = s.regionPlaces;

    return ListView(
      // Full-bleed map, gutters re-applied per child. Same reason as Adventure.
      padding: const EdgeInsets.only(bottom: StrideSpace.s16),
      children: <Widget>[
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
              // A packaging fault, said out loud where a developer will see it
              // and nowhere a player will. Release builds show the list and
              // nothing else.
              if (kDebugMode && problems.isNotEmpty) ...<Widget>[
                SurfaceBlock(
                  child: Text(
                    'World Atlas layout unavailable (debug):\n'
                    '${problems.map((String p) => '· $p').join('\n')}',
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ),
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
                      TravelResultLine(report: c.lastTravel!),
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
        // The map as a picture, captioned on its lower edge. Still no hit
        // testing here: in the fallback there is no layout to place a target
        // by, and a caption is what a picture gets.
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
/// tappable. Set as a label above a name — the pattern every read-only figure
/// in the app uses — rather than as a pin or a button.
class _CurrentPlaceBar extends StatelessWidget {
  const _CurrentPlaceBar({required this.places});

  final List<RegionPlace> places;

  @override
  Widget build(BuildContext context) {
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
      // A gradient, not a plate, and three stops rather than two: the map's
      // lower edge is lit canopy, and a two-stop fade reaches only a third of
      // its opacity where the label sits.
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
          // `textPrimary`, never teal (L-16): the label above carries the
          // emphasis.
          AdaptiveText(here.displayName, style: StrideType.cardTitle),
        ],
      ),
    );
  }
}

/// One journey the player could set out on, as a row. Fallback only; the
/// atlas panel is the same control in the same words.
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
    final String? reason = AtlasSelectionPanel.subtitleFor(option, banked);
    final String places = option.resourceCount == 1
        ? '1 resource'
        : '${option.resourceCount} resources';

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
            reason ??
                (option.isReached
                    ? '${AtlasSelectionPanel.terrainWord(option.terrain)} · '
                          '$places'
                    : 'Not yet reached · '
                          '${AtlasSelectionPanel.terrainWord(option.terrain)} · '
                          '$places'),
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
                    // Weight marks the current place, never a hue.
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
                // Muted, never teal (L-16): this is a distance.
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
