/// One gatherable node, its cost, the queue selector, and the action.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition, ToolKind;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/ambient_stage.dart';
import '../../components/data_display.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../icons/ambient_assets.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/sprite_footprints.dart';
import '../../state/activity_controller.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class GatherNodeCard extends StatefulWidget {
  const GatherNodeCard({super.key, required this.node});

  final ResourceNodeDefinition node;

  @override
  State<GatherNodeCard> createState() => _GatherNodeCardState();
}

class _GatherNodeCardState extends State<GatherNodeCard> {
  /// The requested queue length. Ephemeral UI selection, never a game figure
  /// (`RULES.md` E-2): the count actually offered is re-clamped against live
  /// affordability on every build, so a spent balance shrinks the offer on the
  /// next frame and the stored preference merely remembers what was asked for.
  int _requested = 1;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final ActivityController activity = ActivityScope.of(context);
    final StrideSession s = c.session;
    final ResourceNodeDefinition node = widget.node;

    final int cost = s.costOf(node.id) ?? node.stepCost;
    final String skillName = s.displayNameOf(node.skill);
    final String yieldName = s.displayNameOf(node.yieldsItem);

    final bool activeHere = activity.active && activity.activeNode == node.id;
    final bool activeElsewhere = activity.active && !activeHere;

    // The KNOWN static prerequisites — skill level and equipped tool —
    // projected by the session from the same rules the engine enforces. A
    // hint used to DISABLE (`RULES.md` E-2): an activity that cannot legally
    // complete must not be startable or queueable, because the player would
    // watch a long animation guaranteed to be refused at completion. The
    // engine still re-validates every dispatch and stays authoritative.
    final GatherEligibility eligibility = s.gatherEligibilityOf(node.id);

    // What banked steps afford, hard-capped at the queue maximum. The button
    // never offers a count the balance cannot fund (cost × n ≤ usableEnergy):
    // a preset above the affordable count clamps down and the honest number is
    // what the stepper and the button show. A hint, as ever — the engine
    // re-validates every dispatch.
    final int affordable = cost > 0
        ? s.usableEnergy ~/ cost
        : ActivityController.maxQueue;
    final int maxCount = affordable.clamp(0, ActivityController.maxQueue);
    final int count = _requested.clamp(1, maxCount > 0 ? maxCount : 1);

    final Widget identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SkillChip(skill: node.skill, label: skillName),
        const SizedBox(height: StrideSpace.s6),
        Text(node.displayName, style: StrideType.cardTitle, maxLines: 2),
        Text('Gathering $yieldName', style: StrideType.sub, maxLines: 2),
        // The queue selector lives in the identity column, beside the stage,
        // because the fold does not have a row to spare: the gather control
        // clears the fold by 4 dp on a 393 dp phone (`fold_clearance_test`),
        // so any new row above the button would push the screen's only action
        // out of sight. The stage is 180 dp against ~72 dp of identity — the
        // selector spends slack that already exists.
        if (!activeHere) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _QuantitySelector(
            count: count,
            maxCount: maxCount,
            // A node the player cannot legally work offers no queue at all:
            // presets and stepper disable together with the button below.
            enabled: eligibility.eligible,
            onChanged: (int value) => setState(() => _requested = value),
          ),
          const SizedBox(height: StrideSpace.s6),
          // The projected total, as arithmetic the player can check.
          Text(
            '$count × ${formatSteps(cost)} = ${formatSteps(cost * count)} steps',
            style: StrideType.micro,
          ),
        ],
      ],
    );

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The figure and what it is doing, side by side.
          //
          // The stage used to be a full-width band above the identity: a
          // 128 dp sprite centred in a ~330 dp box, so about 85% of the largest
          // rectangle on the screen was empty ground, and the node's name
          // arrived below it. Two objects, ~220 dp, one of them mostly nothing.
          //
          // Beside each other they are one object about 145 dp tall, and the
          // card now says "this figure, gathering this thing, here" in a single
          // read. While a queue runs the stage loops the profession's working
          // animation instead of resting between one-shots.
          _StageAndIdentity(
            node: node,
            identity: identity,
            activityActive: activeHere,
          ),

          const SizedBox(height: StrideSpace.s10),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              // A failing gate states the concrete failure — the level the
              // player actually has — and carries the unmet emphasis. A met
              // gate reads exactly as before.
              RequirementGate(
                label: eligibility.skillMet
                    ? 'Requires $skillName ${node.requiredLevel}'
                    : 'Requires $skillName ${node.requiredLevel} — '
                          'you are ${eligibility.currentLevel}',
                unmet: !eligibility.skillMet,
              ),
              RequirementGate(
                label: node.requiredToolKind == ToolKind.none
                    ? 'No tool needed'
                    : eligibility.toolMet
                    ? 'Needs a ${node.requiredToolKind.name}'
                    // "Not equipped" rather than "not owned": the engine's
                    // check is equipped-in-a-slot at sufficient tier, and a
                    // pickaxe in the bag is a pickaxe not equipped.
                    : 'Needs a ${node.requiredToolKind.name} — not equipped',
                unmet: !eligibility.toolMet,
              ),
            ],
          ),

          // The `THIS ACTION` heading is gone. Three tiles labelled STEPS,
          // YIELD and EXPERIENCE, directly above a button that says
          // `Gather ×1 — 90 steps`, do not need a caption telling the player
          // they describe an action; it cost 28 dp between the player and the
          // control. During a queue the same tiles state what each completion
          // yields.
          const SizedBox(height: StrideSpace.s10),
          _CostTriple(
            node: node,
            cost: cost,
            yieldName: yieldName,
            skillName: skillName,
          ),

          // The `AVAILABLE 455,281` row that sat here is gone.
          //
          // It printed `s.usableEnergy` — the identical value the header prints
          // persistently, on this screen and every other, in accent teal at
          // 19 px. Three restatements of one number (header, the Your Walking
          // card's affordance sentence, and this row) is what made the card feel
          // like a form rather than an action, and the smallest of the three was
          // the one immediately above the button, competing with it.
          //
          // Nothing is lost: the shortfall case still names the exact number of
          // steps to walk, on the button itself, where the player is looking.
          const SizedBox(height: StrideSpace.s12),
          if (activeHere)
            _ActiveQueuePanel(node: node, skillName: skillName)
          else
            _GatherControl(
              node: node,
              cost: cost,
              count: count,
              activeElsewhere: activeElsewhere,
              eligibility: eligibility,
            ),
        ],
      ),
    );
  }
}

/// The ×1 / ×5 / ×10 presets and the −/+ stepper, wrapping onto two short rows
/// in the identity column's width.
///
/// **Not a monetization surface and shaped never to read as one**: no timer to
/// pay down, no "speed up", no capacity bar. It sets how many times the one
/// honest command will run, and the total it quotes is multiplication the
/// player can verify.
class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.count,
    required this.maxCount,
    required this.enabled,
    required this.onChanged,
  });

  /// The effective count — already clamped to what banked steps afford.
  final int count;

  /// The largest affordable count, possibly zero. Zero disables the stepper;
  /// the button below is already disabled with the shortfall.
  final int maxCount;

  /// False when the node's static prerequisites — skill level or tool — are
  /// unmet. Every control disables at once: sizing a queue that could never
  /// start is not the honest-but-clamped preset case, it is a dead end, and
  /// the reason lives on the gates above and the button below.
  final bool enabled;

  final ValueChanged<int> onChanged;

  static const List<int> _presets = <int>[1, 5, 10];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: StrideSpace.s6,
    runSpacing: StrideSpace.s4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      for (final int preset in _presets)
        _QuantityChip(
          label: '×$preset',
          selected: enabled && count == preset,
          // A preset above the affordable count is still tappable: the
          // selection clamps and the honest number appears on the stepper and
          // the button, which is more truthful than a dead control that does
          // not say why. An *ineligible* node is different — no count could
          // ever start, so the whole selector is dead and says so.
          onTap: enabled ? () => onChanged(preset) : null,
        ),
      _QuantityChip(
        label: '−',
        selected: false,
        onTap: enabled && count > 1 ? () => onChanged(count - 1) : null,
      ),
      Text(
        '$count',
        style: StrideType.sub.copyWith(
          color: enabled ? StrideColors.textPrimary : StrideColors.textMuted,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      _QuantityChip(
        label: '+',
        selected: false,
        onTap: enabled && count < maxCount ? () => onChanged(count + 1) : null,
      ),
    ],
  );
}

/// One selector chip: gate-sized, filled when selected, muted when disabled.
class _QuantityChip extends StatelessWidget {
  const _QuantityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Padding, NOT a fixed box with `alignment:` — `Container`'s alignment
        // expands to the incoming constraints, and inside a `Wrap` those are
        // the full line width, so an aligned chip is silently a full-width
        // capsule and the selector stacks one chip per run. The exact defect
        // `RequirementGate`'s own comment records; it was reproduced here once
        // and cost the fold 100 dp.
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: selected
                ? StrideColors.surfaceRaised
                : StrideColors.surfaceBlock,
            border: Border.all(color: StrideColors.borderDefault),
            borderRadius: StrideRadius.chip,
          ),
          child: Text(
            label,
            style: StrideType.compactLabel.copyWith(
              color: enabled
                  ? StrideColors.textPrimary
                  : StrideColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The stage beside the node's identity, or above it where the phone is too
/// narrow for both.
///
/// The threshold is **measured, not chosen**: the identity column needs enough
/// width for the node's own title, so the same `AdaptiveText.fitsWithin` the
/// title will use is asked first. A longer name from a future content pack, or
/// an enlarged text scale, drops it back to the stacked arrangement rather than
/// crushing the title.
///
/// ## Why the stage stays beside the identity, and what it costs
///
/// The owner's device review asked for two things that pull against each other:
/// **a stage generous enough to hold a future animation**, and **the gather
/// control still above the fold**. The arithmetic is worth writing down, because
/// the next person to grow either of them needs it.
///
/// A real iPhone at 852 dp gives the scroll view roughly **634 dp** once the
/// status inset (59), the header (61), the tab bar (64) and the home indicator
/// (34) are taken. The stack above the button spends:
///
/// ```text
/// vignette             176
/// walking band          70
/// gap                   10
/// card padding          12
/// STAGE                180   <-- StrideGeometry.activityStage
/// gap                   10
/// requirement gates     24
/// gap                   10
/// cost tiles            78
/// gap                   12
/// button                48
///                      ----
/// button bottom        630   against 634
/// ```
///
/// So the stage can be 180 **only because the identity sits beside it rather
/// than under it** — and it is also why the queue selector lives *inside* the
/// identity column: those 4 dp are the whole budget, and any new row above the
/// button spends ~40. Stacking them adds the identity's ~94 dp and puts the
/// button 90 dp below the fold. That is what happens at 320 dp, where there is
/// no room for both — and it is the right trade there, because a crushed node
/// title is worse than a scroll.
///
/// The goldens flatter this by about 93 dp: `flutter test` supplies no insets,
/// so the button looks comfortably clear in an image and is 4 dp clear on a
/// phone. Judge it on the phone (`MISTAKES.md` M-06).
class _StageAndIdentity extends StatelessWidget {
  const _StageAndIdentity({
    required this.node,
    required this.identity,
    required this.activityActive,
  });

  final ResourceNodeDefinition node;
  final Widget identity;
  final bool activityActive;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double beside =
            constraints.maxWidth - _stageWidth - StrideSpace.s12;
        final bool sideBySide =
            beside > 0 &&
            AdaptiveText.fitsWithin(
              node.displayName,
              inherited.merge(StrideType.cardTitle),
              scaler,
              beside,
            );

        final Widget stage = _ActivityStage(
          node: node,
          activityActive: activityActive,
        );

        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              stage,
              const SizedBox(height: StrideSpace.s10),
              identity,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(width: StrideGeometry.activityStage, child: stage),
            const SizedBox(width: StrideSpace.s12),
            Expanded(child: identity),
          ],
        );
      },
    );
  }

  /// The width the identity column is measured against.
  ///
  /// The stage's own edge plus the gap between them. Stated once so the
  /// fits-or-stacks decision and the box that decision is about cannot drift
  /// apart.
  static const double _stageWidth = StrideGeometry.activityStage;
}

/// The activity's contextual art: the Traveler, standing on ground, who gathers
/// once when a single gather succeeds — and works continuously while a queue
/// runs at this node.
///
/// This is the ACTIVITY presentation scale — "UI-driven action plus contextual
/// art". It is deliberately **not** a scene the player moves through. There is
/// no terrain to cross, no position, and no camera; there is a figure performing
/// the action the button just executed.
///
/// ## It is a viewport, not a frame around a sprite
///
/// The box is [StrideGeometry.activityStage] square and the figure in it is
/// 128 dp. **That slack is the feature.** The composition pass sized this to the
/// rest pose plus padding, which was correct for the one animation that exists
/// and wrong for every one that does not yet: a gathering swing, a recoil, a
/// second combatant in a later milestone. The owner's device review asked for
/// the room back and asked for it to be held.
///
/// So the figure is **seated low rather than centred** — its feet near the
/// stage's floor, with the headroom above it. That is where an arc, a raised
/// tool, or a projectile goes, and it is also simply how a figure standing on
/// ground reads. Centring the sprite in a taller box would put the slack under
/// its feet, which reads as floating and gives the animation nothing.
///
/// **Do not shrink this to fit the current sprite.** If a future layout needs
/// the height back, the number and its cost are in
/// `StrideGeometry.activityStage` and in `_StageAndIdentity`'s own doc.
class _ActivityStage extends StatelessWidget {
  const _ActivityStage({required this.node, required this.activityActive});

  final ResourceNodeDefinition node;
  final bool activityActive;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);

    // The identity of a *successful* gather at this node, and nothing else. A
    // refusal leaves this null, so the figure does not mime picking a herb the
    // player did not receive. While a queue runs the token is suppressed
    // outright: completion feedback is UI-level, and the working loop already
    // has the stage (`ACTIVITY_FEEL_PRESENTATION_01` §4a).
    final ActionReport? report = c.lastActionNode == node.id
        ? c.lastAction
        : null;
    final Object? playToken =
        !activityActive && report != null && report.succeeded ? report : null;

    return Container(
      width: double.infinity,
      // A **minimum**, so the stage cannot be squeezed below the room the
      // animations need, and so an enlarged text scale grows the card around it
      // rather than cropping the figure.
      constraints: const BoxConstraints(
        minHeight: StrideGeometry.activityStage,
      ),
      padding: const EdgeInsets.symmetric(vertical: StrideSpace.s6),
      decoration: BoxDecoration(
        // `surfaceBlock`, deliberately, and NOT the darker `surfaceGround` the
        // inset wells use.
        //
        // The contact shadow multiplies against whatever is underneath, so the
        // figure darkens the ground it stands on rather than carrying a grey
        // patch that would be the same colour on any surface. That is the right
        // technique and it has one requirement: **there has to be something to
        // darken.** Against `surfaceGround` (#14120F) a 0.72 multiply moves the
        // pixels by about four values, and the first render of this stage
        // reproduced the exact failure the shadow spec was tuned to escape — a
        // shadow nobody could perceive.
        //
        // This is the same finding the blind reviewer made at strength 0.45,
        // arriving by a different route: there, the shadow was too weak; here,
        // the ground was too dark for any strength to show. Raising the
        // strength would have been the wrong fix, because the ellipse would
        // then be invisible here and far too heavy on the next surface.
        color: StrideColors.surfaceBlock,
        border: Border.all(color: StrideColors.borderDefault),
        borderRadius: StrideRadius.inner,
      ),
      // Bottom-aligned, not centred: the figure stands on the stage's floor and
      // the slack is headroom. See this class's doc — that is where a swing or
      // a raised tool goes, and slack under a standing figure reads as floating.
      //
      // Between gathers the stage is not empty: `AmbientStage` rotates the
      // Traveler through a few ambient scenes and settles back on the same
      // rest pose. Presentation only — the scenes grant nothing, read nothing,
      // and the gather still plays exactly on `playToken`, taking priority.
      // While a queue runs the same stage loops the profession's working
      // frames instead, and the ambient cadence does not run.
      //
      // The node itself — an oak stand, a copper seam — is the stage's far
      // scenery: ×1 art behind the ×2 figure, raised off the figure's ground
      // line, so the stage reads "this figure, at this place" rather than a
      // figure standing through a shrub. Where it goes, and where the figure
      // and the cat go, is `AmbientStageLayout`'s — one place, one test. Not a
      // scene the player moves through: nothing here is a position.
      //
      // Clipped at the stage's own rounded edge. A `Stack` only clips
      // children it knows overflow, and a companion cat drawn by a nested
      // stack is not one of them: on the phone it painted over the card.
      child: ClipRRect(
        borderRadius: StrideRadius.inner,
        child: SizedBox(
          height: _innerHeight,
          child: AmbientStage(
            gatherFrames: PixelIcons.gatherFrames,
            gatherFootprint: SpriteFootprints.gather,
            playToken: playToken,
            scenes: AmbientAssets.scenes,
            restFrame: AmbientAssets.restFrame,
            restFootprint: AmbientAssets.restFootprint,
            scenery: AmbientAssets.sceneryFor(PixelIcons.nodeFor(node.id)),
            // By the skill's id string: the ambient boundary guard keeps
            // `ContentId` out of the asset table — see `activityLoopFor`.
            activityFrames: AmbientAssets.activityLoopFor(node.skill.value),
            activityFootprint: AmbientAssets.activityFootprintFor(
              node.skill.value,
            ),
            activityCanvas: AmbientAssets.activityCanvasFor(node.skill.value),
            activityActive: activityActive,
          ),
        ),
      ),
    );
  }

  /// The stage's interior: the box less its 1 dp border and its vertical
  /// padding. Stated so the figures' floor is the stage floor, and so an
  /// unbounded parent (the stacked layout's column) cannot let it drift.
  static const double _innerHeight =
      StrideGeometry.activityStage - 2 * StrideSpace.s6 - 2;
}

/// `STEPS 90 → YIELD ×2 → EXPERIENCE +10`.
class _CostTriple extends StatelessWidget {
  const _CostTriple({
    required this.node,
    required this.cost,
    required this.yieldName,
    required this.skillName,
  });

  final ResourceNodeDefinition node;
  final int cost;
  final String yieldName;
  final String skillName;

  /// Three tiles, no arrows and no glyph — and both removals are measurements
  /// rather than taste.
  ///
  /// At 320 dp the card has 264 dp inside its padding. Two arrow glyphs at
  /// 24 dp plus their 8 dp of padding took **64 of it — a quarter of the card**
  /// — to decorate a sequence the three labels already state in order. What was
  /// left gave each tile 65 dp, and the leading walking glyph took 30 of the
  /// first tile's 45 dp of content, so `90` was drawn in 16 dp and needed 19.8.
  /// The step figure on the gather card was clipped on every 320 dp phone.
  ///
  /// Without them each tile has 82 dp and every value and label fits at full
  /// size. The walking glyph is not lost: it is on the header permanently and
  /// on the Your Walking card above, both of which have room for it.
  @override
  Widget build(BuildContext context) => ValueTileRow(
    tiles: <LabeledValueTile>[
      LabeledValueTile(
        label: 'Steps',
        value: formatSteps(cost),
        unit: 'per gather',
      ),
      LabeledValueTile(
        label: 'Yield',
        // Not scaled by the balance profile, unlike cost — there is no
        // `yieldOf` to match `costOf`. Under `profile.production` every
        // multiplier is 100 so this is exact; under an accelerated QA profile
        // it would under-report. Recorded as Q-UI-10, not silently ignored.
        value: '×${node.yieldsQuantity}',
        unit: yieldName,
      ),
      LabeledValueTile(
        label: 'Experience',
        value: '+${node.xp}',
        unit: '$skillName XP',
      ),
    ],
  );
}

// The `→` glyph that sat between the cost tiles is gone; `_CostTriple`'s own
// doc records the measurement. It was additionally positioned by `top: 24`, a
// constant that is correct at exactly one text scale — the label line, the gap
// and the value line above it all grow with the scaler — so it was a second
// instance of a number standing in for a measurement, on the vertical axis.
//
// `PixelIcons.arrowGlyph` is left in the asset set and the packaging script. It
// is not deleted here: whether the sequence arrow returns in some form is a
// visual-identity question for the owner, and removing the asset would make
// that decision on their behalf.

/// The button, and the ephemeral line beneath it.
class _GatherControl extends StatelessWidget {
  const _GatherControl({
    required this.node,
    required this.cost,
    required this.count,
    required this.activeElsewhere,
    required this.eligibility,
  });

  final ResourceNodeDefinition node;
  final int cost;

  /// The queue length the button will start — already clamped to affordable.
  final int count;

  /// True while a queue runs at some other node; this card's controls are
  /// disabled with the one-line reason rather than starting a second queue.
  final bool activeElsewhere;

  /// The node's static prerequisites, projected by the session from the same
  /// rules the engine enforces. Unmet disables the button with the concrete
  /// reason on its sub-label — no modal, no animation that cannot succeed.
  final GatherEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final ActivityController activity = ActivityScope.of(context);
    final StrideSession s = c.session;

    // `canGather` is a hint used to DISABLE, never to decide. It checks
    // affordability and readiness only; the static prerequisites — skill
    // level and equipped tool — arrive on [eligibility], projected from the
    // same rules the engine enforces. Location stays unchecked here. The
    // engine re-validates all five on execute and its answer is authoritative,
    // so a refusal that arrives anyway is rendered rather than pre-empted.
    final bool affordable = s.canGather(node.id);
    final int shortfall = cost - s.usableEnergy;

    // One concise reason, in the engine's own checking order: skill before
    // tool, prerequisites before the shortfall. The skill line restates the
    // failing gate above so the sentence sits where the player is looking.
    final String? blockedReason = !eligibility.skillMet
        ? 'Requires ${s.displayNameOf(node.skill)} ${eligibility.requiredLevel}'
              ' — you are ${eligibility.currentLevel}'
        : !eligibility.toolMet
        ? 'Equip a ${node.requiredToolKind.name} first'
        : null;

    final ActionReport? report = c.lastActionNode == node.id
        ? c.lastAction
        : null;
    final bool summaryHere = activity.summaryNode == node.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StrideButton(
          label: c.busy
              ? 'Gathering…'
              : 'Gather ×$count — ${formatSteps(cost * count)} steps',
          subLabel: activeElsewhere
              ? 'Finish or stop your current activity'
              : blockedReason ??
                    (!c.busy && !affordable && shortfall > 0
                        ? 'Walk ${formatSteps(shortfall)} more steps'
                        : null),
          onPressed:
              c.busy || !affordable || activeElsewhere || blockedReason != null
              ? null
              : () => ActivityScope.read(context).start(node, count),
        ),
        // The finished queue's summary takes the strip while it lives; a lone
        // report (the last repetition's) only shows when no summary does, so
        // the same fact is never printed twice.
        if (summaryHere) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _QueueSummaryStrip(activity: activity, skill: node.skill),
        ] else if (report != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _ResultStrip(report: report, skill: node.skill),
        ],
      ],
    );
  }
}

/// The running queue's panel: progress, cumulative gains, and Stop.
///
/// Replaces the gather button while the queue works this node. Everything here
/// is presentation over committed facts: the completed count and the gains
/// come from the committed queue's reconciliation reports, and the bar depicts
/// the **committed anchor against the wall clock** (`DECISIONS/0022`,
/// Consequences) — the queue advances across background and lock, so there is
/// no paused state to render. The spend happens at each completion's commit,
/// never partially.
class _ActiveQueuePanel extends StatelessWidget {
  const _ActiveQueuePanel({required this.node, required this.skillName});

  final ResourceNodeDefinition node;
  final String skillName;

  @override
  Widget build(BuildContext context) {
    final ActivityController activity = ActivityScope.of(context);
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;

    final String itemName =
        activity.gainedItemName ?? s.displayNameOf(node.yieldsItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Gathering ${activity.completed} / ${activity.queued}',
                style: StrideType.sub.copyWith(color: StrideColors.textPrimary),
              ),
            ),
            _SecondsRemaining(activity: activity),
          ],
        ),
        const SizedBox(height: StrideSpace.s6),
        _RepetitionBar(activity: activity, skill: node.skill),
        // What the queue finished while the player was away — surfaced once,
        // compactly, and never as per-repetition popups (`DECISIONS/0022`).
        if (activity.awaySummary case final AwaySummary away
            when away.quantity > 0) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Text(
            '+${away.quantity} ${away.itemName ?? itemName} · '
            '+${away.experience} '
            '${away.skillName ?? skillName} XP while away',
            style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
          ),
        ],
        if (activity.completed > 0) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$itemName gained: ${activity.gainedQuantity}',
                  style: StrideType.micro.copyWith(
                    color: StrideColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '+${activity.gainedXp} '
                '${activity.gainedSkillName ?? skillName} XP',
                style: StrideType.micro.copyWith(
                  color: StrideColors.forSkill(node.skill),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: StrideSpace.s8),
        StrideButton(
          label: 'Stop gathering',
          onPressed: () => ActivityScope.read(context).stop(),
        ),
      ],
    );
  }
}

/// Seconds left in the current repetition, ticking with the bar's clock.
class _SecondsRemaining extends StatelessWidget {
  const _SecondsRemaining({required this.activity});

  final ActivityController activity;

  @override
  Widget build(BuildContext context) {
    final int seconds =
        (activity.repetitionDuration - activity.elapsedOfCurrent).inSeconds;
    return Text(
      '${seconds < 0 ? 0 : seconds}s',
      style: StrideType.micro.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The smooth per-repetition progress bar.
///
/// **A widget-side `AnimationController`, synced from the controller's segment
/// data** — the `ActivityController` notifies on segment boundaries only and
/// never per frame (`ACTIVITY_FEEL_PRESENTATION_01` §4a: domain completion and
/// UI progress are separate clocks). On every controller notification the bar
/// snaps to the authoritative elapsed fraction and animates to full over the
/// remainder; paused queues hold still. The ticker is vsync-driven, so
/// `TickerMode` and backgrounding stop it like every other stage animation.
class _RepetitionBar extends StatefulWidget {
  const _RepetitionBar({required this.activity, required this.skill});

  final ActivityController activity;
  final ContentId skill;

  @override
  State<_RepetitionBar> createState() => _RepetitionBarState();
}

class _RepetitionBarState extends State<_RepetitionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.activity.repetitionDuration,
  );

  @override
  void initState() {
    super.initState();
    widget.activity.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(_RepetitionBar old) {
    super.didUpdateWidget(old);
    if (!identical(widget.activity, old.activity)) {
      old.activity.removeListener(_sync);
      widget.activity.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    if (!mounted) return;
    final ActivityController a = widget.activity;
    if (!a.active) {
      _fill.stop();
      return;
    }
    // The authoritative fraction is the committed anchor against the wall
    // clock, so a resume after any amount of background time snaps the bar to
    // where the durable queue actually is — there is no paused state any more
    // (`DECISIONS/0022`).
    final Duration total = a.repetitionDuration;
    final Duration elapsed = a.elapsedOfCurrent;
    final double fraction = total.inMicroseconds == 0
        ? 1
        : (elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    _fill.value = fraction;
    if (fraction < 1) {
      _fill.animateTo(1, duration: total - elapsed);
    }
  }

  @override
  void dispose() {
    widget.activity.removeListener(_sync);
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 10,
    decoration: BoxDecoration(
      color: StrideColors.surfaceGround,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.gate,
    ),
    child: ClipRRect(
      borderRadius: StrideRadius.gate,
      child: AnimatedBuilder(
        animation: _fill,
        builder: (BuildContext context, Widget? child) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _fill.value,
          child: child,
        ),
        child: ColoredBox(color: StrideColors.forSkill(widget.skill)),
      ),
    ),
  );
}

/// What the finished queue did: gains, and the refusal that stopped it, if one
/// did. Same lifetime and same construction as [_ResultStrip] — accumulated
/// from returned reports, cleared on a timer, never persisted.
class _QueueSummaryStrip extends StatelessWidget {
  const _QueueSummaryStrip({required this.activity, required this.skill});

  final ActivityController activity;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final ActionReport? refusal = activity.stopReport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The whole queue finished while the player was away: the compact
        // completion summary leads, once, and the normal controls are already
        // back (`DECISIONS/0022`).
        if (activity.awaySummary case final AwaySummary away
            when away.quantity > 0) ...<Widget>[
          Text(
            '+${away.quantity} ${away.itemName ?? 'items'} · '
            '+${away.experience} ${away.skillName ?? ''} XP while away',
            style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
          ),
          const SizedBox(height: StrideSpace.s4),
        ],
        if (activity.gainedQuantity > 0)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${activity.gainedItemName ?? 'Items'} '
                  '×${activity.gainedQuantity}',
                  style: StrideType.micro.copyWith(
                    color: StrideColors.textPrimary,
                  ),
                ),
              ),
              if (activity.gainedSkillName case final String skillName)
                Text(
                  '+${activity.gainedXp} $skillName XP',
                  style: StrideType.micro.copyWith(
                    color: StrideColors.forSkill(skill),
                  ),
                ),
            ],
          ),
        if (refusal != null) ...<Widget>[
          if (activity.gainedQuantity > 0)
            const SizedBox(height: StrideSpace.s4),
          Text(
            gatherRefusalText(refusal),
            style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
          ),
        ],
      ],
    );
  }
}

/// The result of the gather that just happened.
///
/// **Ephemeral by construction.** Every value comes from the `ActionReport` the
/// command just returned — not from state, not accumulated, not persisted. It
/// clears on a timer, on the next command, and on a tab change, because a result
/// line that persisted would be indistinguishable from the durable "recent
/// gains" system Phase 1 does not have.
class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.report, required this.skill});

  final ActionReport report;

  /// The node's skill, for the hue only. The report carries the skill's display
  /// *name*, which is the right thing to print but cannot be mapped back to a
  /// content id — so the id comes from the node this card is already for, which
  /// is the same skill by construction.
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return Text(
        gatherRefusalText(report),
        style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
      );
    }

    final String item = report.itemName ?? 'items';
    final String qty = '${report.quantity ?? 0}';
    // Both from the report, which takes them from the ResourceGathered event.
    // Reading `node.xp` here would be the unscaled base value, and diffing skill
    // XP across the await would be widget arithmetic over durable state.
    final String? skillName = report.skillName;
    final int? xp = report.experience;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$item ×$qty',
            style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
          ),
        ),
        if (skillName != null && xp != null)
          Text(
            '+$xp $skillName XP',
            style: StrideType.micro.copyWith(
              color: StrideColors.forSkill(skill),
            ),
          ),
      ],
    );
  }
}

/// The player-facing sentence for a gather refusal — one mapping, shared by the
/// single-gather result strip and the queue's stop reason, so the same
/// rejection never reads two ways.
String gatherRefusalText(ActionReport r) => switch (r.rejection) {
  'insufficient_steps' => 'Not enough banked steps yet',
  'encounter_in_progress' => 'Finish or retreat from your encounter first',
  'session_busy' => 'Still finishing the last action',
  'session_not_ready' => 'Reload before gathering again',
  'commit_refused' => 'That could not be saved — reload before continuing',
  'skill_level_too_low' => 'Your skill level is too low here',
  'tool_required' => 'You need the right tool for this',
  'resource_node_not_here' => 'That is not available at this location',
  _ => r.detail ?? 'That action was refused',
};
