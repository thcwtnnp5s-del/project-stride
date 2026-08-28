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

/// The screen is now **map-first**: the atlas fills the whole World content
/// area and the info panel floats over its lower third, translucent, so the
/// painting continues behind the words (the owner's device brief). The panel
/// scrolls within itself; the atlas never scrolls.
///
/// **~1/3 for the panel, down from the old half-and-half split.** The map used
/// to take a fixed top slice (0.5, clamped 240–560) with an opaque card
/// beneath; that gave the map at most half the height and none of it behind the
/// panel. Now the map dominates at ~2/3 and the panel is a responsive fraction
/// of the height, clamped so it stays readable on a short phone without eating
/// the map on a tall one. Fraction + clamp, never a device-tuned constant.
const double _panelFraction = 0.34;
const double _panelMinHeight = 220;
const double _panelMaxHeight = 360;

/// The collapsed panel: a slim strip carrying the selected place's name and a
/// handle, leaving the atlas essentially full-screen. Collapsing is a player
/// gesture (drag the handle down, or tap it); selecting a place expands the
/// panel again, because a tap on the map is a question and the panel is the
/// answer.
const double _panelPeekHeight = 76;

/// The drag handle strip at the top of the panel body: 4px bar inside s8
/// vertical padding. Named so the camera inset can subtract it — the marker
/// centres above the *readable* content, and the handle is chrome, not
/// content.
const double _panelHandleHeight = StrideSpace.s8 * 2 + 4;

/// The panel's top edge fades from fully transparent to the dark fill over this
/// many logical pixels, and that strip lets drags fall through to the atlas
/// (see [_WorldInfoPanel]). Kept in sync with the camera inset so the current
/// location centres above the readable body, not behind it.
const double _panelFadeHeight = 40;

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

  /// Whether the panel is folded to its peek strip. Expanded is the default:
  /// the panel is the screen's information surface, and hiding it is the
  /// player's own gesture, never the screen's opening move.
  bool _collapsed = false;

  /// Whether the player has panned or pinched the atlas this app run — the
  /// moment the how-to-look-around hint stops earning its row.
  bool _hasPanned = false;

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
        final double expandedHeight = (constraints.maxHeight * _panelFraction)
            .clamp(_panelMinHeight, _panelMaxHeight);
        final double panelHeight = _collapsed
            ? _panelPeekHeight
            : expandedHeight;
        // The camera centres above the panel's readable content (below the
        // fade and the handle), so the you-are-here marker never opens behind
        // glass.
        final double bottomInset =
            (panelHeight - _panelFadeHeight - _panelHandleHeight).clamp(
              0.0,
              constraints.maxHeight,
            );
        return Stack(
          children: <Widget>[
            // The atlas fills the whole area and continues behind the panel.
            Positioned.fill(
              child: AtlasViewport(
                scene: scene,
                selected: selected.id,
                kinds: kinds,
                way: way,
                bottomInset: bottomInset,
                // The pulse wears the warm arrival ink for as long as the
                // journey's result line stands in the panel (F4) — the same
                // held report, so the two cannot disagree.
                arrivalStanding: c.lastJourney?.succeeded ?? false,
                // The walked legs, for the trace's multi-leg course — only a
                // committed journey's, so a refused walk draws nothing new.
                travelLegPlaces: c.lastJourney?.succeeded == true
                    ? c.lastJourney!.legPlaces
                    : null,
                // The tracked Journey's destination wears its gold ring —
                // read from the same goal projection the tracker card
                // renders, so the map and the card cannot disagree.
                journey: s.trackedGoals.journey?.destination,
                onExplored: _hasPanned
                    ? null
                    : () => setState(() => _hasPanned = true),
                // A tap on the map is a question; the panel is the answer, so
                // selecting always unfolds it.
                onSelect: (ContentId id) => setState(() {
                  _selected = id;
                  _collapsed = false;
                }),
              ),
            ),
            // The translucent info panel over the lower third (or its peek
            // strip, if the player folded it away to look at the painting).
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: 0,
              height: panelHeight,
              child: _WorldInfoPanel(
                collapsed: _collapsed,
                onToggle: () => setState(() => _collapsed = !_collapsed),
                collapsedChild: _PanelPeekRow(
                  scene: scene,
                  selected: selected,
                  way: way,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    StrideSpace.screenGutter,
                    StrideSpace.s4,
                    StrideSpace.screenGutter,
                    StrideSpace.s16,
                  ),
                  children: <Widget>[
                    if (s.isStale) ...<Widget>[
                      StaleBanner(busy: c.busy, onReload: c.reload),
                      const SizedBox(height: StrideSpace.s10),
                    ],
                    AtlasSelectionPanel(
                      scene: scene,
                      selected: selected,
                      bare: true,
                      onTravelled: () => setState(() => _selected = null),
                    ),
                    // The pan/pinch tutorial line earns its place exactly
                    // once; after the first pan or pinch it stops renting a
                    // row of the panel (Fable V2 UX audit S8). Ephemeral by
                    // design — a fresh app start shows it again, which is
                    // the right cost for a hint.
                    if (!_hasPanned) ...<Widget>[
                      const SizedBox(height: StrideSpace.s8),
                      Text(
                        'Drag to look around; pinch to look closer. '
                        'Faint names are landmarks, not destinations.',
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The translucent, warm-brown "smoked parchment" panel the World info sits on,
/// over the lower third of the atlas.
///
/// Two regions stacked: a top fade strip that ramps from fully transparent to
/// the dark fill — wrapped in [IgnorePointer] so pans and pinches in it reach
/// the atlas behind — and a solid translucent body that owns its own gestures
/// (the list scrolls, the Travel button taps) and reads clearly against the
/// map. No blur: a [BackdropFilter] over nearest-neighbour pixel art turns the
/// posts to mush and costs a raster every frame; a semi-transparent dark fill
/// carries the "atlas continues behind" read at no cost.
class _WorldInfoPanel extends StatelessWidget {
  const _WorldInfoPanel({
    required this.child,
    required this.collapsedChild,
    required this.collapsed,
    required this.onToggle,
  });

  final Widget child;

  /// The one-line summary shown while folded to the peek strip.
  final Widget collapsedChild;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // The warm-brown ground (StrideColors.surfaceGround is 0xFF14120F), the
    // same ink the fallback's YOU-ARE-HERE caption fades to. The body is a
    // gradient rather than a flat fill: light enough near the top that the
    // painting genuinely reads through the glass, gathering weight toward the
    // bottom where the controls need a solid ground. No blur — a
    // [BackdropFilter] over nearest-neighbour pixel art turns the posts to
    // mush and costs a raster every frame; translucency alone carries the
    // "atlas continues behind" read at no cost.
    return Column(
      children: <Widget>[
        IgnorePointer(
          child: SizedBox(
            height: _panelFadeHeight,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x0014120F), Color(0xB414120F)],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xB414120F), Color(0xE614120F)],
              ),
              border: Border(
                top: BorderSide(color: StrideColors.borderDefault),
              ),
            ),
            child: Column(
              children: <Widget>[
                // The handle: the fold's own control. Drag down folds, drag up
                // unfolds, a tap toggles — and the strip is wide enough to hit
                // with a thumb.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  onVerticalDragEnd: (DragEndDetails d) {
                    final double v = d.velocity.pixelsPerSecond.dy;
                    if (collapsed && v < -80) onToggle();
                    if (!collapsed && v > 80) onToggle();
                  },
                  child: SizedBox(
                    height: _panelHandleHeight,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: StrideColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: collapsed ? collapsedChild : child),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The folded panel's one line: where the eye is (the selected place), what a
/// journey there costs, and nothing else — the map is the point of the fold.
class _PanelPeekRow extends StatelessWidget {
  const _PanelPeekRow({
    required this.scene,
    required this.selected,
    required this.way,
  });

  final AtlasScene scene;
  final AtlasNode selected;
  final AtlasWay? way;

  @override
  Widget build(BuildContext context) {
    final bool here = selected.id == scene.current.id;
    // The folded strip is exactly the map-browsing mode where "can I afford
    // this" matters, so the peek carries the panel's own affordability rule:
    // the figure mutes when the bank falls short, with the shortfall said.
    final int banked = SessionScope.of(context).session.usableEnergy;
    final bool affordable = way != null && way!.totalCost <= banked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StrideSpace.screenGutter),
      child: Row(
        children: <Widget>[
          Expanded(
            child: AdaptiveText(
              selected.place.displayName,
              style: StrideType.itemName,
            ),
          ),
          const SizedBox(width: StrideSpace.s8),
          if (here)
            Text('You are here', style: StrideType.micro)
          else if (way != null) ...<Widget>[
            if (!affordable) ...<Widget>[
              Text(
                'walk ${formatSteps(way!.totalCost - banked)} more · ',
                style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              ),
            ],
            const WalkingGlyph(role: WalkingRole.unit),
            const SizedBox(width: StrideSpace.s4),
            Text(
              formatSteps(way!.totalCost),
              style: StrideType.itemCount.copyWith(
                color: affordable
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ),
          ],
        ],
      ),
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
                    if (c.lastJourney != null) ...<Widget>[
                      const SizedBox(height: StrideSpace.s8),
                      TravelResultLine(journey: c.lastJourney!),
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
          // Promoted to the commit register: this row's Travel is the same
          // spend the atlas panel's Set out is, and the two read as one
          // action now (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
          StrideButton(
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
