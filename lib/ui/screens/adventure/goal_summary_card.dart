/// The tracked goals Adventure keeps pinned, now that the full planning
/// surface lives on the Goal Board (PRESENTATION_WORLD_REWARD_FEEL_01 §9).
///
/// One **note plate** per filled slot — the goal's name and the single most
/// useful figure — and two navigation controls beneath. The full tracker with
/// its per-line material breakdowns, sources and clear controls is the Goal
/// Board's overview tab; Adventure answers "what am I working toward" at a
/// glance and nothing more (§44: tertiary information does not live on every
/// Adventure card).
///
/// ## Pinned notes, not a third list (FMPO02, `ART-12_ux_brief.md` §5)
///
/// The three summary lines were a label column and a dotted sentence, which
/// is the same shape as the activity rows above them and the walking facts
/// above those — three lists in one scroll, distinguishable only by reading.
/// A goal is a note somebody pinned up, so it is drawn as one: a `boardSlip`
/// plate on `cork`, two to a row, 88 dp tall. The row is laid out by measuring
/// rather than by writing 176 down — 176 is what (393 − 32 − 8) / 2 comes to
/// at the reference width, and a written constant would be wrong at every
/// other one.
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'bestiary_screen.dart';
import 'goal_board_screen.dart';

class GoalSummaryCard extends StatelessWidget {
  const GoalSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final TrackedGoalsView goals = c.session.trackedGoals;

    final List<Widget> plates = <Widget>[
      if (goals.journey case final JourneyGoalView j)
        _NotePlate(
          label: 'JOURNEY',
          name: j.destinationName,
          status: _journeyStatus(j),
          emphasised: j.ready && !j.arrived,
        ),
      if (goals.pursuit case final PursuitGoalView p)
        _NotePlate(
          label: 'PURSUIT',
          name: p.itemName,
          status: _pursuitStatus(p),
          emphasised: p.owned || (!p.owned && p.needs.isEmpty),
        ),
      if (goals.contract case final ContractGoalView k)
        _NotePlate(
          label: 'CONTRACT',
          name: k.name,
          status: _contractStatus(k),
          emphasised: k.readyToAdvance && !k.complete,
        ),
    ];

    if (plates.isEmpty) {
      // The empty slot is the new player's one natural signpost, and it used
      // to point at nothing (Fable V2, `DECISIONS/0027`). One plate, so the
      // board is visibly a board with nothing on it yet, and one sentence of
      // direction phrased as invitation, never as a task: nothing here
      // expires, counts down, or nags (`RULES.md` P-5).
      plates.add(
        _NotePlate(
          label: 'NOTHING PINNED',
          name: '',
          status: c.session.usableEnergy > 0
              ? 'The Goal Board has work wanting doing, and the World tab '
                    'shows where a walk could take you.'
              : 'Steps you walk bank here — come back after a stroll and '
                    'see what they open.',
          emphasised: false,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The heading on its rule — the same construction the expedition kit
        // above uses, so the two sections of the spread are two entries in one
        // book rather than two components.
        const KitRule(style: KitRuleStyle.journal, title: 'Current goals'),
        const SizedBox(height: StrideSpace.rhythmRow),
        // The board itself: cork, pinned to the page. The slips stand on it;
        // the page shows around it. This is the one place on Adventure where
        // the material changes, and it changes because the object changes —
        // a goal is a note somebody pinned up, not a line of the ledger.
        _CorkBoard(child: _PlateRows(plates: plates)),
        const SizedBox(height: StrideSpace.rhythmRow),
        // Navigation, not a commit — the neutral register, so opening a
        // board never outranks the screen's game action
        // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
        Row(
          children: <Widget>[
            Expanded(
              child: StrideButton.secondary(
                label: 'Goal Board',
                onPressed: () => GoalBoardScreen.open(context),
              ),
            ),
            const SizedBox(width: StrideSpace.rhythmRow),
            // The hunt-planning surface (`DECISIONS/0028` §6): same
            // navigation register as the board — never outranking the
            // screen's game action.
            Expanded(
              child: StrideButton.secondary(
                label: 'Field Notes',
                onPressed: () => BestiaryScreen.open(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _journeyStatus(JourneyGoalView j) {
    if (j.arrived) return 'you are here';
    if (j.totalCost == null) return 'no known route';
    if (j.ready) return 'READY';
    return '${formatSteps(j.shortfall ?? 0)} more steps';
  }

  static String _pursuitStatus(PursuitGoalView p) {
    if (p.owned) return 'in hand';
    if (p.needs.isEmpty) return 'ready to craft';
    return 'needs ${p.needs.map((PursuitNeedView n) => '${n.quantity} ${n.name}').join(', ')}';
  }

  static String _contractStatus(ContractGoalView k) {
    if (k.complete) return 'complete';
    if (k.readyToAdvance) return 'ready to deliver';
    final PursuitLineView? first = k.lines
        .where((PursuitLineView l) => !l.satisfied)
        .firstOrNull;
    if (first == null) return 'in progress';
    return '${first.name} ${first.held} / ${first.required}';
  }
}

/// The plates, two to a row.
///
/// The cell width is measured, not written: `(width − gap) / 2`, which is 176
/// at the 393 dp reference and correct at 320 and 430 as well. The plates
/// floor at 88 dp and grow with the text scaler rather than clipping (D-01),
/// so in the ordinary case a row of two is a row of two 88 dp notes.
///
/// **Deliberately not `IntrinsicHeight`.** Equalising the pair to the taller
/// one is the tidier row, and it costs a second layout pass of the whole
/// subtree inside a lazy sliver — which trips the framework's own
/// `!semantics.parentDataDirty` assertion when the semantics tree is compiled
/// for the same frame (`screen_evidence_test`, every Adventure case). Two
/// notes pinned at slightly different depths is what a board looks like
/// anyway.
class _PlateRows extends StatelessWidget {
  const _PlateRows({required this.plates});

  final List<Widget> plates;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < plates.length; i += 2) ...<Widget>[
        if (i > 0) const SizedBox(height: StrideSpace.rhythmRow),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: plates[i]),
            const SizedBox(width: StrideSpace.rhythmRow),
            // The odd plate keeps its half of the row rather than
            // stretching across it: a note is a note's width, and a
            // full-bleed one would read as the card the plates replaced.
            Expanded(
              child: i + 1 < plates.length
                  ? plates[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ],
  );
}

/// The cork the slips are pinned to.
///
/// A strip of the shipped `cork` grain with 8 dp of board showing round the
/// notes — the margin is what makes it a board rather than a container. It has
/// no border and no radius: on a page, an edge is where one material stops.
class _CorkBoard extends StatelessWidget {
  const _CorkBoard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SurfaceTile? tile = PanelSurfaces.of(PanelSurface.cork);
    final Widget body = Padding(
      padding: const EdgeInsets.all(StrideSpace.s8),
      child: child,
    );
    if (tile == null) {
      return ColoredBox(color: StrideColors.surfaceBlock, child: body);
    }
    return SurfaceFill(
      tile: tile,
      fill: StrideColors.surfaceBlock,
      child: body,
    );
  }
}

/// One pinned note: what kind of goal, which one, and where it stands.
///
/// `KitFrame.slipPinned` (`KIT_CONTRACT` §1) with a brass pin through its
/// head. The frame is declared and its raster has not landed, so the plate
/// paints the kit's square, one-weight fallback at exactly the inset it will
/// spend when the art arrives — the note is finished work today and gains
/// material later without reflowing.
class _NotePlate extends StatelessWidget {
  const _NotePlate({
    required this.label,
    required this.name,
    required this.status,
    required this.emphasised,
  });

  final String label;

  /// The goal's own name. Empty on the empty-state plate, which has a status
  /// sentence and nothing to name.
  final String name;

  final String status;

  /// Whether this is the "go now" state — READY, in hand, ready to deliver.
  final bool emphasised;

  /// The plate's rhythm height. A floor, never an exact box.
  static const double height = 88;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // Outside the plate, not inside it: a minimum applied to the *content*
    // would be 88 dp of text plus the frame's own inset, and the slip would
    // come out at 118.
    constraints: const BoxConstraints(minHeight: height),
    child: Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        KitPlate(
          frame: KitFrame.slipPinned,
          raised: true,
          fill: StrideColors.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: StrideType.microLabel),
              if (name.isNotEmpty) ...<Widget>[
                const SizedBox(height: StrideSpace.s2),
                AdaptiveText(name, style: StrideType.itemName),
              ],
              const SizedBox(height: StrideSpace.s2),
              Text(
                status,
                style: StrideType.micro.copyWith(
                  color: emphasised
                      ? StrideColors.positiveReady
                      : StrideColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // The pin. Four pixels of brass at the slip's head — the whole
        // difference between a note lying on a board and a note pinned to it,
        // and the reason the slips do not need a border to read as objects.
        const Positioned(
          top: 2,
          child: SizedBox(
            width: 6,
            height: 6,
            child: ColoredBox(color: StrideColors.goalActive),
          ),
        ),
      ],
    ),
  );
}
