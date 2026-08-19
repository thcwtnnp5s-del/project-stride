/// What the atlas says about the place the player tapped, and the one control
/// that may follow from it.
///
/// This began as `_DestinationRow` moved under the map, and the rules have not
/// changed: the button is the control; every reason it might be disabled is
/// stated on it, in the order the engine refuses (requirement, then price); it
/// exists only because `TravelTo` exists and dispatches only
/// `SessionController.travel`. A place with no road from here is described and
/// is **not** offered — the panel says which way it is reached and stops there,
/// because the engine would refuse the journey and a disabled button with no
/// sentence is a broken one.
///
/// ## What the inspector added, and the line it did not cross
///
/// The panel used to say a name, a terrain and a resource *count*. It now says
/// what kind of place it is, which nodes stand there and which creatures wait
/// there — because a count is a number a player cannot plan with, and "2
/// resources" is true of a copper seam and a herb patch alike.
///
/// Every one of those rows is a **real system**: a gathering row names a node
/// the engine will let the player work, an encounter row names an enemy the
/// engine will let them fight. There is no row here for anything that does not
/// exist, no row that is a plan, and no row that is a button in disguise. When
/// the session has nothing to say about a place, the section is **absent** —
/// not an empty heading, and never a placeholder.
///
/// ## Two widgets, and why
///
/// [AtlasSelectionPanel] reads the session and hands everything to
/// [AtlasInspector], which is a pure function of its arguments. That is what
/// lets the presentation be tested against a fabricated place — a boss, a
/// driven-off enemy, four gathering nodes — none of which the shipped content
/// need contain today, without a fake session that would have to reimplement
/// the projections to lie convincingly.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Terrain;

import '../../../../runtime/stride_session.dart';
import '../../../components/adaptive_text.dart';
import '../../../components/data_display.dart';
import '../../../components/screen_header.dart' show formatSteps;
import '../../../components/surfaces.dart';
import '../../../components/walking_glyph.dart';
import '../../../state/session_controller.dart';
import '../../../state/session_scope.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_metrics.dart';
import '../../../theme/stride_typography.dart';
import 'atlas_layout.dart';
import 'atlas_place_info.dart';

class AtlasSelectionPanel extends StatelessWidget {
  const AtlasSelectionPanel({
    super.key,
    required this.scene,
    required this.selected,
    required this.onTravelled,
  });

  final AtlasScene scene;

  /// The place under discussion. The screen defaults it to the current
  /// location, so the panel is never empty.
  final AtlasNode selected;

  /// Called after a travel is dispatched, so the screen can let the selection
  /// follow the player. Not a result callback — the result is the session's.
  final VoidCallback onTravelled;

  @override
  Widget build(BuildContext context) {
    final SessionController watched = SessionScope.of(context);
    final SessionController controller = SessionScope.read(context);
    final RegionPlace place = selected.place;
    final TravelOption? option = scene.optionFor(place.id);

    return AtlasInspector(
      name: place.displayName,
      info: AtlasPlaceInfo.from(watched.session, place),
      way: scene.routeSummary(place.id),
      option: option,
      banked: watched.session.usableEnergy,
      busy: watched.busy,
      ready: watched.session.isReady,
      lastTravel: watched.lastTravel,
      onTravel: option == null
          ? null
          : () {
              controller.travel(option.id);
              onTravelled();
            },
    );
  }

  /// The one line that explains why a journey is refused, or null when it is
  /// open — an open road needs no sentence beside its button.
  ///
  /// Ordered the way the engine refuses: the requirement first, then the price.
  /// Telling a player they are 400 steps short of Forgotten Hollow, when the
  /// real answer is that it needs a Bronze Sword, sends them walking toward a
  /// wall they will still hit.
  static String? subtitleFor(TravelOption option, int banked) {
    if (option.isBlocked) {
      return 'Needs ${option.missingRequirements.join(', ')}';
    }
    if (!option.affordable) {
      return 'Walk ${formatSteps(option.shortfallFrom(banked))} more steps';
    }
    return null;
  }

  /// The terrain, as a word a player would use rather than an enum name.
  /// Canonical in [AtlasPlaceInfo]; restated here because the pre-atlas
  /// fallback presentation calls it and has no info object to hand.
  static String terrainWord(Terrain terrain) =>
      AtlasPlaceInfo.terrainWordFor(terrain);
}

/// The inspector itself: a pure widget over everything it prints.
class AtlasInspector extends StatelessWidget {
  const AtlasInspector({
    super.key,
    required this.name,
    required this.info,
    required this.way,
    required this.option,
    required this.banked,
    required this.busy,
    required this.ready,
    required this.lastTravel,
    required this.onTravel,
  });

  final String name;
  final AtlasPlaceInfo info;

  /// The walk from here to this place: its hops and its costs. Null when this
  /// *is* here, or when no chain of roads reaches it.
  final AtlasWay? way;

  /// The journey the session offers, when a road runs here directly.
  final TravelOption? option;

  final int banked;
  final bool busy;
  final bool ready;
  final TravelReport? lastTravel;

  /// Dispatches the journey. Null when there is nothing to dispatch.
  final VoidCallback? onTravel;

  @override
  Widget build(BuildContext context) {
    final String? refusal = option == null
        ? null
        : AtlasSelectionPanel.subtitleFor(option!, banked);
    final bool open = option != null && option!.canTravel && !busy && ready;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveText(name, style: StrideType.cardTitle),
                    const SizedBox(height: StrideSpace.s2),
                    AdaptiveText(
                      '${info.kindWord} · ${info.terrainWord}',
                      style: StrideType.micro,
                      color: StrideColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (option case final TravelOption o) ...<Widget>[
                const SizedBox(width: StrideSpace.s8),
                // The step figure keeps the muted "steps as a unit" glyph. It
                // is a price, still a quantity of steps rather than the
                // player's own balance, and L-16's two-tone rule turns on
                // exactly that distinction.
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.s4),
                AdaptiveText(
                  formatSteps(o.stepCost),
                  style: StrideType.itemCount,
                  color: o.affordable
                      ? StrideColors.textPrimary
                      : StrideColors.textMuted,
                ),
              ],
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          AdaptiveText(
            statusLine(info),
            style: StrideType.micro,
            color: StrideColors.textMuted,
          ),

          if (info.gatherSites.isNotEmpty) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            const SectionHeading(label: 'Gathering'),
            const SizedBox(height: StrideSpace.s6),
            for (final AtlasGatherLine site in info.gatherSites)
              Padding(
                padding: const EdgeInsets.only(bottom: StrideSpace.s4),
                child: _Sentence(
                  gatherLine(site),
                  style: StrideType.sub,
                  color: StrideColors.textSecondary,
                ),
              ),
          ],

          if (info.encounters.isNotEmpty) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            const SectionHeading(label: 'Encounters'),
            const SizedBox(height: StrideSpace.s6),
            for (final AtlasEncounterLine e in info.encounters)
              Padding(
                padding: const EdgeInsets.only(bottom: StrideSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: AdaptiveText(
                            e.name,
                            style: StrideType.itemName,
                          ),
                        ),
                        if (e.isBoss) ...<Widget>[
                          const SizedBox(width: StrideSpace.s6),
                          const _BossBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: StrideSpace.s2),
                    _Sentence(
                      encounterLine(e),
                      style: StrideType.micro,
                      color: StrideColors.textMuted,
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: StrideSpace.s10),
          _Sentence(
            routeLine(info: info, way: way),
            style: StrideType.micro,
            color: StrideColors.textSecondary,
          ),

          if (option != null) ...<Widget>[
            if (refusal case final String reason) ...<Widget>[
              const SizedBox(height: StrideSpace.s4),
              AdaptiveText(
                reason,
                style: StrideType.micro,
                color: StrideColors.textMuted,
              ),
            ],
            const SizedBox(height: StrideSpace.s10),
            StrideButton(
              label: busy ? 'Travelling…' : 'Travel',
              onPressed: open ? onTravel : null,
            ),
          ],

          if (lastTravel case final TravelReport report) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            TravelResultLine(report: report),
          ],
        ],
      ),
    );
  }

  /// `You are here · Safe`, `Reached`, `Not yet reached · Safe`.
  static String statusLine(AtlasPlaceInfo info) => <String>[
    if (info.isCurrent)
      'You are here'
    else if (info.isUnlocked)
      'Reached'
    else
      'Not yet reached',
    if (info.isSafe) 'Safe',
  ].join(' · ');

  /// `Oak Stand · Woodcutting Lv 1 · Axe`. The tool is dropped when the node
  /// needs none, rather than printed as "none".
  static String gatherLine(AtlasGatherLine site) => <String>[
    site.name,
    '${site.skill} Lv ${site.level}',
    ?site.tool,
  ].join(' · ');

  /// `Cautious · 2 of 2 this visit`, or `Wary · 2 per visit`.
  ///
  /// The two halves answer different questions and both are wanted: what the
  /// creature does, and how many fights are left. Where the player is standing
  /// the count is a live figure from the save; anywhere else it is the
  /// authored per-visit number, because a place resets when it is entered
  /// (`DECISIONS/0021`) and quoting a remainder for somewhere unvisited would
  /// be a fiction.
  static String encounterLine(AtlasEncounterLine e) {
    final String state;
    if (!e.isCurrentLocation) {
      state = e.perVisit == 1 ? '1 per visit' : '${e.perVisit} per visit';
    } else if (e.remaining <= 0) {
      state = 'Driven off — returns after you travel';
    } else {
      state = '${e.remaining} of ${e.perVisit} this visit';
    }
    return '${e.behaviorWord} · $state';
  }

  /// The one line about getting there.
  ///
  /// Four cases, and the third is the one the panel exists for: a place two
  /// roads away has a total price a player can plan a week's walking around,
  /// **and** a first leg that is the only figure any button will charge. Both
  /// are printed, and which is which is said in words rather than by position.
  static String routeLine({
    required AtlasPlaceInfo info,
    required AtlasWay? way,
  }) {
    if (info.isCurrent) return 'Tap a place on the map to see the way there.';
    if (way == null) return 'No route runs there from here.';
    if (way.isDirect) {
      return 'Road from here · ${formatSteps(way.totalCost)} steps';
    }
    final String via = way.via
        .map((AtlasNode node) => node.place.displayName)
        .join(', then ');
    return 'By way of $via · ${formatSteps(way.totalCost)} steps in all, '
        '${formatSteps(way.firstLegCost)} for the first leg';
  }
}

/// A line of prose, which wraps.
///
/// [AdaptiveText] is the right primitive for a **value** — a name, a figure, a
/// caption — because a value that wraps is a value read wrong, and D-01 was
/// about a value silently clipped. A sentence is the other case: *By way of
/// Stonefall Mine · 2,300 steps in all, 800 for the first leg* does not fit one
/// line on a 320 dp phone at a 1.4× text scale, and it should not try. Shrinking
/// it to fit would make it smaller than the values above it for no reason.
///
/// So sentences wrap and values do not, and this widget is where that
/// distinction is written down rather than left to whoever edits next.
class _Sentence extends StatelessWidget {
  const _Sentence(this.data, {required this.style, required this.color});

  final String data;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(data, style: style.copyWith(color: color));
}

/// `BOSS`, as a plate rather than a colour. The palette has one accent and
/// L-16 spends it on walking, so importance here is a shape.
class _BossBadge extends StatelessWidget {
  const _BossBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: StrideSpace.s6,
      vertical: StrideSpace.s2,
    ),
    decoration: BoxDecoration(
      color: StrideColors.surfaceRaised,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.gate,
    ),
    child: Text('BOSS', style: StrideType.microLabel, maxLines: 1),
  );
}

/// What the last journey did, while the line is still on screen.
class TravelResultLine extends StatelessWidget {
  const TravelResultLine({super.key, required this.report});

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
          : refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  /// Keyed on the stable wire code, never on the explanation sentence.
  static String refusalText(TravelReport report) => switch (report.rejection) {
    'insufficient_steps' => 'Not enough banked steps for that journey.',
    'entry_requirement_unmet' =>
      'You are not carrying what that place requires.',
    'route_not_found' => 'No route runs there from here.',
    'encounter_in_progress' => 'Finish or retreat from your encounter first.',
    'already_at_location' => 'You are already there.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before travelling again.',
    _ => 'You could not travel there.',
  };
}
