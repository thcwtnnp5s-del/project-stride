/// The activity list: every gather node at this location as a compact,
/// selectable row, with one expanded detail for the selected activity.
///
/// ## What this replaces (PRESENTATION_WORLD_REWARD_FEEL_01 §6–§7)
///
/// One full `GatherNodeCard` per node — each ~380 dp with its own stage, its
/// own Traveler, its own tiles and button — was the single largest source of
/// vertical mass on Adventure. The rows here are ~48 dp each; only the
/// selected activity expands into queue controls, requirement gates, tiles
/// and the action. Locked activities stay visible as compact aspirational
/// rows: the name, the concrete requirement, and nothing else.
///
/// The queue semantics are untouched: everything below dispatches through
/// the same [ActivityController] / [SessionController] paths the old card
/// used, every figure is a live projection, and the engine re-validates
/// every dispatch (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition, ToolKind;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../state/activity_controller.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

/// The panel: rows for every node here, the selected one expanded.
class ActivityPanel extends StatelessWidget {
  const ActivityPanel({
    super.key,
    required this.nodes,
    required this.selected,
    required this.onSelect,
  });

  final List<ResourceNodeDefinition> nodes;

  /// The selected activity, or null when the stage is idle.
  final ContentId? selected;

  /// Called with the tapped node, or null when the selected row is tapped
  /// again — deselection returns the stage to its ambient idle.
  final ValueChanged<ContentId?> onSelect;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;

    if (nodes.isEmpty) {
      return const SectionCard(
        child: Text(
          'There is nothing to gather here.',
          style: StrideType.body,
        ),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Activities'),
          const SizedBox(height: StrideSpace.s6),
          for (final ResourceNodeDefinition node in nodes) ...<Widget>[
            _ActivityRow(
              node: node,
              session: s,
              selected: selected == node.id,
              onTap: () => onSelect(selected == node.id ? null : node.id),
            ),
            if (selected == node.id)
              Padding(
                padding: const EdgeInsets.only(
                  top: StrideSpace.s6,
                  bottom: StrideSpace.s6,
                ),
                child: ActivityDetail(node: node),
              ),
          ],
        ],
      ),
    );
  }
}

/// One compact activity row: what it is, what it needs, what it gives.
///
/// Unlocked: `Copper Seam · 140 steps` over `Mining 1 · ×1 Copper Ore ·
/// +14 XP`. Locked: the name muted, and the concrete gap — `Requires Mining
/// 3 — you are 1` — because a wall with a distance written on it is a plan
/// (§7: visible and aspirational, never a giant card).
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.node,
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final ResourceNodeDefinition node;
  final StrideSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StrideSession s = session;
    final GatherEligibility e = s.gatherEligibilityOf(node.id);
    final int cost = s.costOf(node.id) ?? node.stepCost;
    final String skillName = s.displayNameOf(node.skill);
    final String yieldName = s.displayNameOf(node.yieldsItem);
    final bool locked = !e.skillMet;

    final String subLine = locked
        ? 'Requires $skillName ${e.requiredLevel} — you are ${e.currentLevel}'
        : <String>[
            '$skillName ${node.requiredLevel}',
            '×${node.yieldsQuantity} $yieldName',
            '+${node.xp} XP',
            if (!e.toolMet && node.requiredToolKind != ToolKind.none)
              'needs a ${node.requiredToolKind.name}',
          ].join(' · ');

    return Semantics(
      button: true,
      selected: selected,
      label: node.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: StrideSpace.s4),
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? StrideColors.surfaceRaised
                : StrideColors.surfaceBlock,
            border: Border.all(
              color: selected
                  ? StrideColors.forSkill(node.skill)
                  : StrideColors.borderDefault,
            ),
            borderRadius: StrideRadius.inner,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveText(
                      node.displayName,
                      style: StrideType.itemName,
                      color: locked
                          ? StrideColors.textMuted
                          : StrideColors.textPrimary,
                    ),
                    Text(
                      subLine,
                      style: StrideType.micro.copyWith(
                        color: locked
                            ? StrideColors.textMuted
                            : StrideColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              if (!locked) ...<Widget>[
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.s4),
                Text(
                  formatSteps(cost),
                  style: StrideType.itemCount.copyWith(
                    color: StrideColors.textPrimary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ] else
                Text(
                  'LOCKED',
                  style: StrideType.microLabel.copyWith(
                    color: StrideColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected activity's working surface: gates, the queue, the tiles, and
/// the action — everything the old card carried except the stage and the
/// identity, which live on the location stage and the row above.
class ActivityDetail extends StatefulWidget {
  const ActivityDetail({super.key, required this.node});

  final ResourceNodeDefinition node;

  @override
  State<ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<ActivityDetail> {
  /// The requested queue length. Ephemeral UI selection, never a game figure
  /// (`RULES.md` E-2): the count actually offered is re-clamped against live
  /// affordability on every build.
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

    final GatherEligibility eligibility = s.gatherEligibilityOf(node.id);

    final int affordable = cost > 0
        ? s.usableEnergy ~/ cost
        : ActivityController.maxQueue;
    final int maxCount = affordable.clamp(0, ActivityController.maxQueue);
    final int count = _requested.clamp(1, maxCount > 0 ? maxCount : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The gates, only when something actually gates: a met requirement
        // is stated on the row's sub-line, and restating it here as a chip
        // costs a row the fold no longer has to spend (§44 hierarchy).
        if (!eligibility.skillMet || !eligibility.toolMet) ...<Widget>[
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              if (!eligibility.skillMet)
                RequirementGate(
                  label:
                      'Requires $skillName ${node.requiredLevel} — '
                      'you are ${eligibility.currentLevel}',
                  unmet: true,
                ),
              if (!eligibility.toolMet)
                RequirementGate(
                  label: 'Needs a ${node.requiredToolKind.name} — not equipped',
                  unmet: true,
                ),
            ],
          ),
          const SizedBox(height: StrideSpace.s8),
        ],

        if (!activeHere) ...<Widget>[
          _QuantitySelector(
            count: count,
            maxCount: maxCount,
            enabled: eligibility.eligible,
            onChanged: (int value) => setState(() => _requested = value),
          ),
          const SizedBox(height: StrideSpace.s6),
          // What the queue will make, as arithmetic the player can check.
          // The skill's name is deliberately absent: the completion strips
          // print "+N Foraging XP" and the projection must never be
          // mistakable for a result.
          Text(
            '$count × ${formatSteps(cost)} = ${formatSteps(cost * count)} '
            'steps · ×${node.yieldsQuantity * count} $yieldName · '
            '+${node.xp * count} XP',
            style: StrideType.micro,
          ),
          const SizedBox(height: StrideSpace.s10),
        ],

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
    );
  }
}

/// The ×1 / ×5 / ×10 presets and the −/+ stepper.
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
  /// unmet. Every control disables at once.
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
          // not say why.
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
        // the full line width (see `RequirementGate`'s own comment).
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

  /// True while a queue runs at some other node; this activity's controls are
  /// disabled with the one-line reason rather than starting a second queue.
  final bool activeElsewhere;

  /// The node's static prerequisites, projected by the session from the same
  /// rules the engine enforces. Unmet disables the button with the concrete
  /// reason on its sub-label.
  final GatherEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final ActivityController activity = ActivityScope.of(context);
    final StrideSession s = c.session;

    // `canGather` is a hint used to DISABLE, never to decide. The engine
    // re-validates on execute and its answer is authoritative.
    final bool affordable = s.canGather(node.id);
    final int shortfall = cost - s.usableEnergy;

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

    // A level gained — by the queue, or by a single gather — is a MEDIUM
    // result and rises in the reward layer (PLAYABLE_POLISH_01 §4); the
    // strip beneath then shows nothing of it. The queue's token is its
    // finished figures (the controller holds one summary at a time); a
    // single gather's is its report.
    final bool queueHeld = summaryHere && activity.levelledUp;
    final bool reportHeld = !summaryHere && report != null && report.levelledUp;
    final Object? heldToken = queueHeld
        ? 'queue:${node.id.value}:${activity.completed}:${activity.skillLevelAfter}'
        : reportHeld
        ? report
        : null;

    return RewardRaise(
      token: heldToken,
      tier: RewardTier.medium,
      accent: StrideColors.forSkill(node.skill),
      beats: queueHeld
          ? _QueueSummaryStrip.heldBeats(activity, node.skill)
          : reportHeld
          ? _ResultStrip.heldBeats(report, node.skill)
          : const <Widget>[],
      onDismiss: queueHeld
          ? ActivityScope.read(context).dismissSummary
          : () {},
      child: Column(
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
        if (summaryHere && !queueHeld) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _QueueSummaryStrip(activity: activity, skill: node.skill),
        ] else if (report != null && !reportHeld) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _ResultStrip(report: report, skill: node.skill),
        ],
      ],
      ),
    );
  }
}

/// The running queue's panel: progress, cumulative gains, and Stop.
///
/// Everything here is presentation over committed facts (`DECISIONS/0022`):
/// the completed count and the gains come from the committed queue's
/// reconciliation reports, and the bar depicts the committed anchor against
/// the wall clock. The spend happens at each completion's commit, never
/// partially.
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
        RepetitionBar(activity: activity, skill: node.skill),
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
/// never per frame. On every controller notification the bar snaps to the
/// authoritative elapsed fraction and animates to full over the remainder.
/// The ticker is vsync-driven, so `TickerMode` and backgrounding stop it like
/// every other stage animation.
///
/// Public: the craft flow's timed presentation reuses it (§14–§17), so the
/// two activities' progress cannot drift apart visually.
class RepetitionBar extends StatefulWidget {
  const RepetitionBar({super.key, required this.activity, required this.skill});

  final ActivityController activity;
  final ContentId skill;

  @override
  State<RepetitionBar> createState() => _RepetitionBarState();
}

class _RepetitionBarState extends State<RepetitionBar>
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
  void didUpdateWidget(RepetitionBar old) {
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
    // where the durable queue actually is (`DECISIONS/0022`).
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
/// did. Accumulated from returned reports, cleared on a timer, never
/// persisted.
class _QueueSummaryStrip extends StatelessWidget {
  const _QueueSummaryStrip({required this.activity, required this.skill});

  final ActivityController activity;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final ActionReport? refusal = activity.stopReport;
    final AwaySummary? away = activity.awaySummary;
    final String item = activity.gainedItemName ?? 'Items';
    final String? skillName = activity.gainedSkillName;
    final int done = activity.completed;

    // The queue's completion beat (PLAYABLE_EXPERIENCE_REFINEMENT_01 §10):
    // how many, the total yield, the total XP — one MINOR beat, with the
    // universal level-up beneath it when the climb crossed a level. The
    // away line stays a fact on the beat rather than a second card.
    final List<String> lines = <String>[
      if (activity.gainedQuantity > 0) '$item ×${activity.gainedQuantity}',
      if (skillName != null && activity.gainedXp > 0)
        '+${activity.gainedXp} $skillName XP',
      if (away != null && away.quantity > 0)
        '${away.quantity} ${away.itemName ?? item} gathered while away',
      if (refusal != null) gatherRefusalText(refusal),
    ];
    final String eyebrow = refusal != null
        ? 'STOPPED'
        : done > 0
        ? 'GATHERING COMPLETE'
        : 'GATHERING';
    final String title = done > 0
        ? '$done ${done == 1 ? 'repetition' : 'repetitions'} completed'
        : (refusal != null ? 'Nothing completed' : '');

    return StaggeredReveal(
      children: <Widget>[
        if (title.isNotEmpty || lines.isNotEmpty)
          RewardBeat(
            tier: RewardTier.minor,
            eyebrow: eyebrow,
            title: title,
            lines: lines,
          ),
      ],
    );
  }

  /// The layer's beats for a queue that crossed a level: the completion
  /// beat, the item row, and the universal level-up.
  static List<Widget> heldBeats(ActivityController activity, ContentId skill) {
    final String item = activity.gainedItemName ?? 'Items';
    final String? skillName = activity.gainedSkillName;
    final int done = activity.completed;
    final AwaySummary? away = activity.awaySummary;
    return <Widget>[
      RewardBeat(
        tier: RewardTier.medium,
        eyebrow: 'GATHERING COMPLETE',
        title: '$done ${done == 1 ? 'repetition' : 'repetitions'} completed',
        accent: StrideColors.forSkill(skill),
        lines: <String>[
          if (activity.gainedQuantity > 0) '$item ×${activity.gainedQuantity}',
          if (skillName != null && activity.gainedXp > 0)
            '+${activity.gainedXp} $skillName XP',
          if (away != null && away.quantity > 0)
            '${away.quantity} ${away.itemName ?? item} gathered while away',
        ],
      ),
      LevelUpCard(
        name: skillName ?? '',
        level: activity.skillLevelAfter ?? 0,
        skill: skill,
        unlocked: activity.unlockedNames,
        why: activity.unlockedNames.isEmpty
            ? null
            : 'Richer sites and recipes are open to you',
      ),
    ];
  }
}

/// The result of the single gather that just happened.
///
/// **Ephemeral by construction.** Every value comes from the `ActionReport`
/// the command just returned — not from state, not accumulated, not
/// persisted. It clears on a timer, on the next command, and on a tab change.
/// A MINOR beat; the universal level-up beneath it when the gather crossed a
/// level (§10, §29).
class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.report, required this.skill});

  final ActionReport report;

  /// The node's skill, for the hue only.
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
    final String? skillName = report.skillName;
    final int? xp = report.experience;

    return StaggeredReveal(
      children: <Widget>[
        RewardBeat(
          tier: RewardTier.minor,
          eyebrow: 'GATHERED',
          title: '$item ×${report.quantity ?? 0}',
          lines: <String>[
            if (skillName != null && xp != null) '+$xp $skillName XP',
          ],
        ),
      ],
    );
  }

  /// The layer's beats for a single gather that crossed a level.
  static List<Widget> heldBeats(ActionReport report, ContentId skill) {
    final String item = report.itemName ?? 'items';
    final String? skillName = report.skillName;
    final int? xp = report.experience;
    return <Widget>[
      RewardBeat(
        tier: RewardTier.minor,
        eyebrow: 'GATHERED',
        title: '$item ×${report.quantity ?? 0}',
        lines: <String>[
          if (skillName != null && xp != null) '+$xp $skillName XP',
        ],
      ),
      LevelUpCard(
        name: skillName ?? '',
        level: report.skillLevelAfter ?? 0,
        skill: skill,
        unlocked: report.unlockedNames,
        why: report.unlockedNames.isEmpty
            ? null
            : 'Richer sites and recipes are open to you',
      ),
    ];
  }
}

/// The player-facing sentence for a gather refusal — one mapping, shared by
/// the single-gather result strip and the queue's stop reason, so the same
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
