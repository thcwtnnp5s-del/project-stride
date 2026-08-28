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
import 'package:stride_core/stride_core.dart' show ContentId, GoalSlot, Terrain;

import '../../../../runtime/stride_session.dart';
import '../../../components/adaptive_text.dart';
import '../../../components/data_display.dart';
import '../../../components/pixel_asset.dart';
import '../../../components/reward_beat.dart';
import '../../../components/reward_layer.dart';
import '../../../components/screen_header.dart' show formatSteps;
import '../../../components/surfaces.dart';
import '../../../components/walking_glyph.dart';
import '../../../icons/pixel_icons.dart';
import '../../../state/audio_scope.dart';
import '../../../state/session_controller.dart';
import '../../../state/session_scope.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_metrics.dart';
import '../../../theme/stride_typography.dart';
import '../travel_transition.dart';
import 'atlas_layout.dart';
import 'atlas_place_info.dart';

class AtlasSelectionPanel extends StatelessWidget {
  const AtlasSelectionPanel({
    super.key,
    required this.scene,
    required this.selected,
    required this.onTravelled,
    this.bare = false,
  });

  final AtlasScene scene;

  /// When true the inspector renders without its opaque [SectionCard], so it
  /// can sit directly on the World screen's translucent map-first panel and let
  /// the atlas show through. The pre-atlas fallback keeps the card (`bare`
  /// stays false there).
  final bool bare;

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
    final AtlasWay? way = scene.routeSummary(place.id);

    // Every hop of the walk, in order — the journey the Travel button now
    // dispatches whole (B-2). Each leg remains the same one-road engine
    // command it always was; the panel merely stops pretending a two-leg
    // walk is two separate decisions with two separate prices.
    final List<ContentId> legs = way == null
        ? const <ContentId>[]
        : <ContentId>[for (final AtlasNode hop in way.hops) hop.place.id];

    final JourneyGoalView? journey = watched.session.trackedGoals.journey;
    final bool journeyHere = journey?.destination == place.id;

    return AtlasInspector(
      name: place.displayName,
      info: AtlasPlaceInfo.from(watched.session, place),
      way: way,
      missingEntry: watched.session.missingEntryRequirementsFor(place.id),
      banked: watched.session.usableEnergy,
      busy: watched.busy,
      ready: watched.session.isReady,
      lastJourney: watched.lastJourney,
      bare: bare,
      // The destination's second framing (RCP01's vignette variants,
      // integrated by Fable V2) — shown for a *reached* place the player is
      // not standing in, so the panel carries a picture of where the walk
      // would end. An unreached place keeps its mystery, and *here* is
      // already on the screen behind the glass.
      vignette: !place.isCurrent && place.isUnlocked
          ? PixelIcons.altVignetteFor(place.id)
          : null,
      onTravel: legs.isEmpty
          ? null
          : () async {
              // Kept for the discovery check below: the panel rebuilds on
              // arrival and `place` then follows the selection home.
              final RegionPlace destination = place;
              // The origin, captured before the engine moves the player —
              // the departure beat's framing.
              final RegionPlace origin = scene.current.place;
              await controller.travelJourney(legs);
              onTravelled();
              final JourneySummary? journey = controller.lastJourney;
              // The walk, presented (Fable V2 Iteration 02; re-paced by
              // GAME_FEEL_CHARACTER_PRESENTATION_01): a committed arrival
              // plays the journey card — departure, the walk over the
              // destination's second framing, arrival — before anything
              // else speaks. Its length answers to `TravelPacing`; the map
              // trace mirrors its clock. Skipped under Reduce Motion,
              // skippable to its arrival after the departure window; a
              // refused journey goes straight to its sentence.
              if (journey != null && journey.succeeded && context.mounted) {
                await showTravelTransition(
                  context,
                  backdrop: PixelIcons.altVignetteFor(destination.id),
                  destinationName: journey.arrivedName,
                  originBackdrop: PixelIcons.altVignetteFor(origin.id),
                  originName: journey.originName,
                  legs: journey.legsCompleted,
                  stepsSpent: journey.totalSpent,
                  equipment: watched.session.equipmentVisualState,
                );
              }
              // Discovery is the payoff walking most directly buys, and it
              // used to rent half a sentence in a result line. A first
              // arrival now rises in the one reward grammar every other
              // payoff uses — the place's vignette, what stands there, what
              // waits there (Fable V2, `DECISIONS/0027`). Ordinary arrivals
              // stay quiet: the map moving is their acknowledgement.
              if (journey != null &&
                  journey.succeeded &&
                  journey.firstVisit &&
                  context.mounted) {
                await showDiscoveryLayer(
                  context,
                  session: watched.session,
                  place: destination,
                );
              }
            },
      // The Journey slot (`DECISIONS/0023` §1): any place but *here* can be
      // tracked. Reserves nothing; the tracker restates this panel's own
      // figures on the Adventure screen. When this place *is* the tracked
      // Journey, the same control clears it — a set goal the screen that
      // set it could not see was Fable V2's audit finding.
      journeyTracked: journeyHere,
      onTrackJourney: place.isCurrent
          ? null
          : journeyHere
          ? () => controller.trackGoal(GoalSlot.journey, null)
          : () => controller.trackGoalJourney(place.id),
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
    required this.missingEntry,
    required this.banked,
    required this.busy,
    required this.ready,
    required this.lastJourney,
    required this.onTravel,
    this.onTrackJourney,
    this.journeyTracked = false,
    this.vignette,
    this.bare = false,
  });

  final String name;
  final AtlasPlaceInfo info;

  /// Render without the opaque [SectionCard] wrapper, for the translucent
  /// map-first panel. See [AtlasSelectionPanel.bare].
  final bool bare;

  /// The walk from here to this place: its hops and its costs. Null when this
  /// *is* here, or when no chain of roads reaches it.
  final AtlasWay? way;

  /// Entry requirements the destination declares that the player does not
  /// hold, by name. A projection of the same check the engine makes at the
  /// door — a hint used to disable, never the authority (`RULES.md` E-2).
  final List<String> missingEntry;

  final int banked;
  final bool busy;
  final bool ready;
  final JourneySummary? lastJourney;

  /// Dispatches the journey. Null when there is nothing to dispatch.
  final VoidCallback? onTravel;

  /// Tracks this place in the Journey slot — or clears it, when
  /// [journeyTracked]. Null for *here*.
  final VoidCallback? onTrackJourney;

  /// Whether this place is the tracked Journey right now.
  final bool journeyTracked;

  /// The destination's vignette variant, or null where none is shown.
  final String? vignette;

  /// The one sentence explaining a closed journey, in the engine's own
  /// refusal order: the requirement first, then the price.
  String? get _refusal {
    if (way == null) return null;
    if (missingEntry.isNotEmpty) return 'Needs ${missingEntry.join(', ')}';
    if (way!.totalCost > banked) {
      return 'Walk ${formatSteps(way!.totalCost - banked)} more steps';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String? refusal = _refusal;
    final bool open =
        way != null && refusal == null && !busy && ready && onTravel != null;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The destination's second framing — a picture of where the walk
        // ends, cropped to a slim band so the panel stays an inspector.
        if (vignette case final String art) ...<Widget>[
          ClipRRect(
            borderRadius: StrideRadius.card,
            child: PixelScene.vignette(art, viewportHeight: 88),
          ),
          const SizedBox(height: StrideSpace.s8),
        ],
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
            if (way case final AtlasWay w) ...<Widget>[
              const SizedBox(width: StrideSpace.s8),
              // The step figure keeps the muted "steps as a unit" glyph. It
              // is a price, still a quantity of steps rather than the
              // player's own balance, and L-16's two-tone rule turns on
              // exactly that distinction. The figure is the WHOLE way's
              // cost — the journey the button now walks (B-2) — never the
              // first leg presented as the trip.
              const WalkingGlyph(role: WalkingRole.unit),
              const SizedBox(width: StrideSpace.s4),
              AdaptiveText(
                formatSteps(w.totalCost),
                style: StrideType.itemCount,
                color: w.totalCost <= banked
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

        // The board at a glance — the reason the walk exists. One line of
        // counts, and one sentence when the bag already answers a need.
        if (info.board case final AtlasBoardLine board) ...<Widget>[
          const SizedBox(height: StrideSpace.s10),
          const SectionHeading(label: 'Work'),
          const SizedBox(height: StrideSpace.s6),
          _Sentence(
            boardLine(board),
            style: StrideType.sub,
            color: StrideColors.textSecondary,
          ),
          if (carryLine(board) case final String carrying) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            _Sentence(
              carrying,
              style: StrideType.micro,
              color: StrideColors.textPrimary,
            ),
          ],
        ],

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
                // A site out of reach reads muted, with its gap in the
                // same sentence — the wasted-journey preventer, asked on
                // the map where the journey is being planned.
                color: site.eligible
                    ? StrideColors.textSecondary
                    : StrideColors.textMuted,
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
                        child: AdaptiveText(e.name, style: StrideType.itemName),
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

        if (way != null && onTravel != null) ...<Widget>[
          if (refusal case final String reason) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            AdaptiveText(
              reason,
              style: StrideType.micro,
              color: StrideColors.textMuted,
            ),
          ],
          const SizedBox(height: StrideSpace.s10),
          _TravelControls(
            destinationName: name,
            way: way!,
            banked: banked,
            busy: busy,
            open: open,
            onTravel: onTravel,
          ),
        ],

        if (onTrackJourney != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(
            label: journeyTracked ? 'Journey set — clear' : 'Set as Journey',
            onPressed: busy ? null : onTrackJourney,
          ),
        ],

        if (lastJourney case final JourneySummary journey) ...<Widget>[
          const SizedBox(height: StrideSpace.s10),
          TravelResultLine(journey: journey),
        ],
      ],
    );

    return bare ? content : SectionCard(child: content);
  }

  /// `You are here · Safe`, `Reached · Struggling`, `Not yet reached`.
  /// The development word is the settlement's named state — the thing
  /// community projects permanently change — so a place's trajectory reads
  /// from the map (Fable V2, `DECISIONS/0027`).
  static String statusLine(AtlasPlaceInfo info) => <String>[
    if (info.isCurrent)
      'You are here'
    else if (info.isUnlocked)
      'Reached'
    else
      'Not yet reached',
    if (info.isSafe) 'Safe',
    ?info.developmentWord,
  ].join(' · ');

  /// `Oak Stand · Woodcutting Lv 1 · Axe`, with the gap appended where one
  /// stands — `— you are Lv 1` — so the map never plans a journey toward a
  /// node the engine would refuse. The tool is dropped when the node needs
  /// none, rather than printed as "none".
  static String gatherLine(AtlasGatherLine site) {
    final String line = <String>[
      site.name,
      '${site.skill} Lv ${site.level}',
      ?site.tool,
    ].join(' · ');
    return site.gap == null ? line : '$line — ${site.gap}';
  }

  /// `Notice Board · 3 open` / `Mine Ledger · 4 open · 1 ready to turn in`.
  static String boardLine(AtlasBoardLine board) => <String>[
    board.boardName,
    board.openContracts == 1 ? '1 open' : '${board.openContracts} open',
    if (board.readyToComplete > 0)
      board.readyToComplete == 1
          ? '1 ready to turn in'
          : '${board.readyToComplete} ready to turn in',
  ].join(' · ');

  /// The sentence that turns the map into a plan — what the bag already
  /// answers at this place — or null when it answers nothing.
  static String? carryLine(AtlasBoardLine board) {
    if (board.readyToComplete > 0 && board.projectHasSomethingToGive) {
      return 'You carry what work here needs — a delivery, and materials '
          'for ${board.projectName}.';
    }
    if (board.readyToComplete > 0) {
      return 'You carry what a contract here needs.';
    }
    if (board.projectHasSomethingToGive) {
      return 'You carry materials ${board.projectName} needs.';
    }
    return null;
  }

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
  /// A place two roads away prints its way and its whole price — which is now
  /// also exactly what the Travel button charges, leg by committed leg (B-2).
  /// The "first leg" clause this line used to carry is gone with the
  /// leg-at-a-time button that made it necessary.
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
    return 'By way of $via · ${formatSteps(way.totalCost)} steps in all';
  }
}

/// A first arrival, raised in the one reward grammar every other payoff
/// uses (Fable V2, `DECISIONS/0027`): `DISCOVERED`, the place's name, its
/// vignette variant where one is packaged, and what actually stands and
/// waits there — every line a projection the inspector already shows.
///
/// MEDIUM, once, only on the arrival that opened the place. No XP, no
/// resource, no burst: discovery's reward is the place itself, said out
/// loud for the walk that earned it.
Future<void> showDiscoveryLayer(
  BuildContext context, {
  required StrideSession session,
  required RegionPlace place,
}) {
  final AtlasPlaceInfo info = AtlasPlaceInfo.from(session, place);
  final String? vignette = PixelIcons.altVignetteFor(place.id);
  return showRewardLayer(
    context,
    tier: RewardTier.medium,
    beats: <Widget>[
      RewardBeat(
        tier: RewardTier.medium,
        eyebrow: 'DISCOVERED',
        title: place.displayName,
        lines: <String>[
          '${info.kindWord} · ${info.terrainWord}'
              '${info.isSafe ? ' · Safe' : ''}',
          if (info.gatherSites.isNotEmpty)
            'Gathering: '
                '${info.gatherSites.map((AtlasGatherLine g) => g.name).join(', ')}',
          if (info.encounters.isNotEmpty)
            'Encounters: '
                '${info.encounters.map((AtlasEncounterLine e) => e.name).join(', ')}',
          if (info.board case final AtlasBoardLine board)
            '${board.boardName} · ${board.openContracts} open',
        ],
      ),
      if (vignette != null) ...<Widget>[
        const SizedBox(height: StrideSpace.s10),
        ClipRRect(
          borderRadius: StrideRadius.card,
          child: PixelScene.vignette(vignette, viewportHeight: 120),
        ),
      ],
    ],
  );
}

/// The travel control, with its confirmation step (brief §53).
///
/// Tap Travel and the button becomes a small confirmation block: the
/// destination, the WHOLE journey's cost with its way named, and the balance
/// it leaves — stated before the spend, so setting out is a decision rather
/// than a reflex (B-2: the first leg's price is never presented as the
/// trip's). Cancel costs nothing. The flag is presentation state: it
/// survives nothing, decides nothing, and the engine re-validates every leg
/// on confirm exactly as it always did.
class _TravelControls extends StatefulWidget {
  const _TravelControls({
    required this.destinationName,
    required this.way,
    required this.banked,
    required this.busy,
    required this.open,
    required this.onTravel,
  });

  final String destinationName;
  final AtlasWay way;
  final int banked;
  final bool busy;
  final bool open;
  final VoidCallback? onTravel;

  @override
  State<_TravelControls> createState() => _TravelControlsState();
}

class _TravelControlsState extends State<_TravelControls> {
  bool _confirming = false;

  @override
  void didUpdateWidget(_TravelControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new selection or a changed price is a new question.
    if (oldWidget.destinationName != widget.destinationName ||
        oldWidget.way.totalCost != widget.way.totalCost) {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_confirming) {
      return StrideButton(
        label: widget.busy ? 'Travelling…' : 'Travel',
        onPressed: widget.open
            ? () => setState(() => _confirming = true)
            : null,
      );
    }
    final AtlasWay way = widget.way;
    final int after = widget.banked - way.totalCost;
    final String via = way.via
        .map((AtlasNode node) => node.place.displayName)
        .join(', then ');
    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdaptiveText(
            'Set out for ${widget.destinationName}?',
            style: StrideType.itemName,
          ),
          const SizedBox(height: StrideSpace.s4),
          Text(
            way.isDirect
                ? '${formatSteps(way.totalCost)} steps · leaves '
                      '${formatSteps(after < 0 ? 0 : after)} banked'
                : 'By way of $via · ${formatSteps(way.totalCost)} steps '
                      'in all · leaves ${formatSteps(after < 0 ? 0 : after)} '
                      'banked',
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
          ),
          const SizedBox(height: StrideSpace.s8),
          // "Set out" is the biggest spend in the game and takes the
          // primary button; "Stay" keeps the utility class. Both were
          // secondary — 34 dp yes/no on a 2,000-step decision — until the
          // Fable V2 UX audit named the inversion (the metrics file itself
          // calls that height "nothing on the gameplay path").
          StrideButton(
            label: widget.busy ? 'Travelling…' : 'Set out',
            // The one warm glow in the system: the game's weightiest
            // commit spends its central real-world currency
            // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
            glow: true,
            onPressed: widget.busy || !widget.open
                ? null
                : () {
                    // The commit of the game's biggest spend — one light
                    // tap as the boots go on. Fired here, not on arrival:
                    // the decision is the moment.
                    AudioScope.maybeRead(context)?.hapticLight();
                    setState(() => _confirming = false);
                    widget.onTravel?.call();
                  },
          ),
          const SizedBox(height: StrideSpace.s6),
          StrideButton.secondary(
            label: 'Stay',
            onPressed: widget.busy
                ? null
                : () => setState(() => _confirming = false),
          ),
        ],
      ),
    );
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
///
/// A multi-leg arrival names the journey's true total with the final leg
/// distinguished (B-2); a refusal mid-way says where the player truthfully
/// stands and why the walk stopped — every committed leg stays committed.
class TravelResultLine extends StatelessWidget {
  const TravelResultLine({super.key, required this.journey});

  final JourneySummary journey;

  String get _sentence {
    final JourneySummary j = journey;
    if (j.succeeded) {
      final String first = j.firstVisit ? ' for the first time' : '';
      if (j.isMultiLeg) {
        return 'Arrived at ${j.arrivedName}$first · '
            '${formatSteps(j.totalSpent)}-step journey '
            '(final leg ${formatSteps(j.finalLegCost)})';
      }
      return 'Arrived at ${j.arrivedName}$first · '
          '${formatSteps(j.totalSpent)} steps';
    }
    final String why = j.failure == null
        ? 'the way was refused'
        : refusalText(j.failure!);
    if (j.legsCompleted > 0) {
      return 'Stopped at ${j.arrivedName} — $why '
          '(${formatSteps(j.totalSpent)} steps walked)';
    }
    return why;
  }

  @override
  Widget build(BuildContext context) {
    final Widget line = SurfaceBlock(
      child: AdaptiveText(
        _sentence,
        style: StrideType.sub,
        color: journey.succeeded
            ? StrideColors.textPrimary
            : StrideColors.textSecondary,
      ),
    );
    // The arrival line steps in once — keyed by the report, so it plays per
    // journey, not per rebuild. `TweenAnimationBuilder` does not honor
    // Reduce Motion on its own; the explicit branch does.
    if (MediaQuery.disableAnimationsOf(context)) return line;
    return TweenAnimationBuilder<double>(
      key: ObjectKey(journey),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: line,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
    );
  }

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
