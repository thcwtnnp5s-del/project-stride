/// The location's contract board: local needs, bounties, regional contracts,
/// and community projects — one backend, this place's fiction
/// (`DECISIONS/0023` §2–3).
///
/// Every control is a hint: `CompleteContract`, `AcceptContract` and
/// `ContributeToProject` re-validate on execute, and the engine's refusal is
/// rendered when it disagrees (`RULES.md` E-2). Nothing here computes a rule —
/// eligibility, rotation and rewards all arrive projected from the session.
///
/// Completion presentation (PLAYABLE_POLISH_01 §3–§4): a delivery, a claimed
/// bounty, a finished stage and a completed project each rise over the board
/// in the reward layer (`reward_layer.dart`) — the board is the ledger, the
/// payoff is its own plane — and are held until Continue. A plain
/// contribution that finishes nothing, an acceptance, and a refusal stay
/// inline: they are bookkeeping, not payoffs.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, ContractClass;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class LocationBoardCard extends StatefulWidget {
  const LocationBoardCard({super.key});

  @override
  State<LocationBoardCard> createState() => _LocationBoardCardState();
}

class _LocationBoardCardState extends State<LocationBoardCard> {
  /// Held presentation from the last completion — ephemeral, never state
  /// (`RULES.md` E-2): a relaunch has none, and the game figures it shows are
  /// copies off the committed report.
  ContractReport? _contractResult;
  ProjectReport? _projectResult;

  /// The open job, or null when the board is fully collapsed. Ephemeral UI
  /// selection, never a game figure (`RULES.md` E-2).
  ContentId? _open;

  void _toggle(ContentId id) =>
      setState(() => _open = _open == id ? null : id);

  Future<void> _complete(SessionController c, ContractView job) async {
    final ContractReport? report = await c.completeContract(job.id);
    if (!mounted || report == null) return;
    if (report.succeeded) {
      // The payoff, above the board. The row beneath has already rotated
      // to the next need or marked itself DONE; the layer is what the tap
      // was for.
      setState(() {
        _contractResult = null;
        _projectResult = null;
        _open = null;
      });
      await showRewardLayer(
        context,
        tier: RewardTier.medium,
        accent: _TypeChip.rewardInkOf(job.contractClass),
        beats: contractRewardBeats(report, job.contractClass),
      );
      return;
    }
    setState(() {
      _contractResult = report;
      _projectResult = null;
    });
  }

  Future<void> _accept(SessionController c, ContentId contract) async {
    final ContractReport? report = await c.acceptContract(contract);
    if (!mounted || report == null || report.succeeded) return;
    setState(() {
      _contractResult = report;
      _projectResult = null;
    });
  }

  Future<void> _contribute(SessionController c, ProjectView project) async {
    final ProjectReport? report = await c.contributeToProject(
      project.id,
      project.contributable,
    );
    if (!mounted || report == null) return;
    if (report.succeeded &&
        (report.stageCompleted || report.projectCompleted)) {
      setState(() {
        _projectResult = null;
        _contractResult = null;
      });
      await showRewardLayer(
        context,
        tier: report.projectCompleted ? RewardTier.major : RewardTier.medium,
        accent: StrideColors.accentSteps,
        beats: projectRewardBeats(report),
      );
      return;
    }
    setState(() {
      _projectResult = report;
      _contractResult = null;
    });
  }

  void _dismissResults() => setState(() {
    _contractResult = null;
    _projectResult = null;
  });

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final BoardView? board = c.session.boardHere;
    if (board == null) return const SizedBox.shrink();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            label: board.boardName,
            trailing: board.developmentState == null
                ? null
                : Text(
                    board.developmentState!.toUpperCase(),
                    style: StrideType.microLabel.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
          ),

          // The held result panels, above the listings so a completion is the
          // first thing read after the tap that caused it.
          if (_projectResult case final ProjectReport r) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
            _ProjectResultPanel(report: r, onContinue: _dismissResults),
          ],
          if (_contractResult case final ContractReport r) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
            _ContractResultPanel(report: r, onContinue: _dismissResults),
          ],

          // Every job on this board as one scannable row, with the one the
          // player opened expanded beneath it (§11). Orders, bounties and
          // regional contracts share the row; they are distinguished by the
          // type word, not by three separate layouts.
          for (final ContractView job in <ContractView>[
            ...board.localNeeds,
            ...board.bounties,
            ...board.regionals,
          ]) ...<Widget>[
            _ContractRow(
              contract: job,
              selected: _open == job.id,
              onTap: () => _toggle(job.id),
              // The open job's detail lives inside the row's own frame, so
              // the expanded state is one block rather than a row with loose
              // prose beneath it (PLAYABLE_POLISH_01 §3).
              detail: _open == job.id
                  ? _ContractDetail(
                      contract: job,
                      busy: c.busy,
                      onComplete: () => _complete(c, job),
                      onAccept: job.bounty == null
                          ? null
                          : () => _accept(c, job.id),
                      onTrack: () => c.trackGoalContract(job.id),
                    )
                  : null,
            ),
          ],

          // Community projects stay visually distinct and stay above the
          // fold of their own section (§12): they are the place's story, not
          // another job. They keep their full tile — stage, animated
          // material bars, permanent consequence — because that treatment is
          // the point of them, and the owner asked for it to be preserved.
          for (final ProjectView project in board.projects) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            _ProjectTile(
              project: project,
              busy: c.busy,
              onContribute: project.hasSomethingToGive
                  ? () => _contribute(c, project)
                  : null,
              onTrack: () => c.trackGoalContract(project.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// The beats a completed contract raises in the layer: what was completed
/// (the eyebrow names the type — ORDER DELIVERED, BOUNTY CLAIMED, CONTRACT
/// COMPLETE), the items, the experience, anything learned or heard, and the
/// universal level-up beneath. Every figure is a copy off the committed
/// report; nothing is re-derived from state (`RULES.md` E-2).
List<Widget> contractRewardBeats(ContractReport r, ContractClass kind) {
  final Color ink = _TypeChip.rewardInkOf(kind);
  return <Widget>[
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: switch (kind) {
        ContractClass.localNeed => 'ORDER DELIVERED',
        ContractClass.bounty => 'BOUNTY CLAIMED',
        ContractClass.regional => 'CONTRACT COMPLETE',
      },
      title: r.contractName,
      accent: ink,
      lines: <String>[
        if (r.consumed.isNotEmpty)
          'Handed over: ${r.consumed.map((RewardLine l) => '${l.name} ×${l.quantity}').join(', ')}',
      ],
    ),
    if (r.rewardItems.isNotEmpty)
      RewardFacts(
        label: 'ITEMS',
        gap: StrideSpace.s6,
        children: <Widget>[
          for (final RewardLine line in r.rewardItems)
            RewardItemRow(
              id: line.id,
              name: line.name,
              quantity: line.quantity,
              rarity: line.rarity,
            ),
        ],
      ),
    if (r.rewardSkillXp.isNotEmpty || r.characterXp > 0)
      RewardFacts.lines('EXPERIENCE', <String>[
        for (final SkillXpLine line in r.rewardSkillXp)
          '+${line.xp} ${line.skillName} XP',
        if (r.characterXp > 0) '+${r.characterXp} Character XP',
      ]),
    if (r.taughtRecipeName case final String recipe)
      RewardBeat(
        tier: RewardTier.medium,
        eyebrow: 'RECIPE LEARNED',
        title: recipe,
        accent: StrideColors.categoryQuest,
        lines: const <String>['Ready at the bench'],
      ),
    if (r.revealedRumorNames.isNotEmpty)
      RewardFacts.lines(
        'RUMOR HEARD',
        r.revealedRumorNames,
        color: StrideColors.textSecondary,
      ),
    if (r.levelledUp)
      LevelUpCard(
        name: 'Traveler',
        level: r.levelAfter ?? 0,
        why: '+2 Max HP · harder fights are within reach',
      ),
  ];
}

/// The beats a finished stage or a completed project raises: the headline,
/// the settlement's change, what was given, the experience, rumors, and
/// the level-up. A completed project is the MAJOR tier — the one event in
/// the game that permanently changes a place.
List<Widget> projectRewardBeats(ProjectReport r) => <Widget>[
  if (r.projectCompleted)
    RewardBeat(
      tier: RewardTier.major,
      eyebrow: 'PROJECT COMPLETE',
      title: r.completionHeadline ?? r.projectName,
      accent: StrideColors.accentSteps,
      lines: <String>[
        if (r.completionHeadline != null) r.projectName,
        if (r.developmentChanged)
          '${r.developmentBefore} → ${r.developmentAfter}',
        'The work is done; its benefits are permanent.',
      ],
    )
  else
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'STAGE COMPLETE',
      title: r.stageName,
      accent: StrideColors.accentSteps,
      lines: <String>[r.projectName],
    ),
  if (r.contributed.isNotEmpty)
    RewardFacts.lines('CONTRIBUTED', <String>[
      for (final RewardLine line in r.contributed)
        '${line.name} ×${line.quantity}',
    ], color: StrideColors.textSecondary),
  if (r.characterXp > 0)
    RewardFacts.lines('EXPERIENCE', <String>['+${r.characterXp} Character XP']),
  if (r.revealedRumorNames.isNotEmpty)
    RewardFacts.lines(
      'RUMOR HEARD',
      r.revealedRumorNames,
      color: StrideColors.textSecondary,
    ),
  if (r.levelledUp)
    LevelUpCard(
      name: 'Traveler',
      level: r.levelAfter ?? 0,
      why: '+2 Max HP · harder fights are within reach',
    ),
];

/// One contract, collapsed to a scannable row.
///
/// ## The density problem this exists for (§9, §11)
///
/// Moving the board off Adventure was the right architecture and the owner
/// said so — and then found the board itself "still much too dense on
/// physical hardware… a long wall of prose, cards, repeated Track buttons,
/// repeated Deliver/Accept actions, rewards, project content". Relocating a
/// wall is not the same as taking it down.
///
/// Every contract used to render its title, a **three-line brief**, its
/// requirement chips, a full reward sentence and two buttons, permanently,
/// for every job on the board. The prose sat at the same visual weight as the
/// progress and the reward, which is precisely backwards: flavour is what you
/// read once, progress is what you came to check.
///
/// So a row is four facts and nothing else — **title, type, progress,
/// reward** — and the brief and the actions live in the one job the player
/// opened. Same shape as the activity list and the encounter list; three
/// lists that behave differently would be three things to learn.
///
/// Nothing is hidden that a player needs in order to decide: the state word
/// on the right says READY, ACCEPTED, LOCKED or DONE, so a row never conceals
/// that a job is finishable.
class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.contract,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final ContractView contract;
  final bool selected;
  final VoidCallback onTap;

  /// The open job's brief, requirements and actions, drawn inside this
  /// row's frame beneath a rule. Null when collapsed.
  final Widget? detail;

  /// The one line that says how far along this job is.
  ///
  /// A bounty counts kills, an order counts goods, and a contract that wants
  /// both says both. Falls back to the unavailability reason, because "you
  /// cannot do this yet" is progress information too.
  static String progressLine(ContractView c) {
    final BountyView? bounty = c.bounty;
    final List<String> parts = <String>[
      for (final RequirementLine line in c.requires)
        '${line.name} ${line.progress}/${line.required}',
      for (final RequirementLine line in c.requiresOwned)
        '${line.name} ${line.progress}/${line.required}',
      if (bounty != null)
        '${bounty.enemyName} '
            '${bounty.accepted ? bounty.progress : 0}/${bounty.required}',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return c.unavailableReason ?? 'Ready to hand in';
  }

  /// The reward, compressed to one line. The expanded detail spells it out.
  static String rewardLine(ContractView c) => <String>[
    for (final RequirementLine line in c.rewardItems)
      '${line.name} ×${line.required}',
    for (final SkillXpLine line in c.rewardSkillXp)
      '+${line.xp} ${line.skillName}',
    if (c.rewardCharacterXp > 0) '+${c.rewardCharacterXp} XP',
    if (c.teachesRecipeName != null) 'recipe',
  ].join(' · ');

  /// What state the job is in, in one word, on the right of the row.
  static (String, Color) state(ContractView c) {
    if (c.isCompletedOneTime) return ('DONE', StrideColors.textMuted);
    if (c.canComplete) return ('READY', StrideColors.accentSteps);
    if (c.bounty?.accepted ?? false) {
      return ('ACCEPTED', StrideColors.textSecondary);
    }
    if (!c.available) return ('LOCKED', StrideColors.textMuted);
    return ('OPEN', StrideColors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final ContractView c = contract;
    final bool done = c.isCompletedOneTime;
    final bool locked = !done && !c.available;
    final (String word, Color ink) = state(c);
    final String reward = rewardLine(c);
    // A finishable job is the one thing on the board worth finding at a
    // glance, so its frame takes the dim step accent along with the word;
    // everything else keeps the one border weight.
    final Color frame = c.canComplete && !done
        ? StrideColors.accentStepsDim
        : StrideColors.borderDefault;

    // The open row's head is raised; its detail beneath sits on the block
    // fill so the primary control — itself the raised level — stands out
    // against it rather than vanishing into a raised ground.
    final Widget head = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: StrideSpace.s10,
          vertical: StrideSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? StrideColors.surfaceRaised : null,
          borderRadius: detail == null
              ? StrideRadius.inner
              : const BorderRadius.vertical(top: Radius.circular(9)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: AdaptiveText(
                          c.name,
                          style: StrideType.itemName,
                          color: done || locked
                              ? StrideColors.textMuted
                              : StrideColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: StrideSpace.s6),
                      _TypeChip(
                        contractClass: c.contractClass,
                        done: done || locked,
                      ),
                    ],
                  ),
                  if (!done) ...<Widget>[
                    const SizedBox(height: StrideSpace.s2),
                    Text(
                      progressLine(c),
                      style: StrideType.micro.copyWith(
                        color: locked
                            ? StrideColors.textMuted
                            : StrideColors.textSecondary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                      maxLines: 2,
                    ),
                    if (reward.isNotEmpty)
                      Text(
                        reward,
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textMuted,
                        ),
                        maxLines: 1,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            Text(word, style: StrideType.microLabel.copyWith(color: ink)),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: c.name,
      child: Container(
        margin: const EdgeInsets.only(top: StrideSpace.s6),
        decoration: BoxDecoration(
          color: StrideColors.surfaceBlock,
          border: Border.all(color: frame),
          borderRadius: StrideRadius.inner,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            head,
            if (detail case final Widget d) d,
          ],
        ),
      ),
    );
  }
}

/// The job's type, as a restrained chip: a 6 px mark in the type's own ink
/// beside the word (PLAYABLE_EXPERIENCE_REFINEMENT_01 §24).
///
/// Three types, three inks — an ORDER is the settlement's need (the step
/// accent, dimmed: it is walking turned into goods), a BOUNTY is a fight (the
/// Rare rank's blue, the ink the encounter rows already use for knowledge),
/// a CONTRACT is the region's story (the quest category's ink). The word is
/// always present; the mark and the ink only make three rows scannable at a
/// glance. No card theme, no second layout.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.contractClass, required this.done});

  final ContractClass contractClass;
  final bool done;

  static String labelOf(ContractClass c) => switch (c) {
    ContractClass.localNeed => 'ORDER',
    ContractClass.bounty => 'BOUNTY',
    ContractClass.regional => 'CONTRACT',
  };

  static Color inkOf(ContractClass c) => switch (c) {
    ContractClass.localNeed => StrideColors.accentStepsDim,
    ContractClass.bounty => StrideColors.rarityRare,
    ContractClass.regional => StrideColors.categoryQuest,
  };

  /// The same three inks at reveal strength: the layer's frame and eyebrow
  /// for a completion of this type. An ORDER's dimmed accent is right for a
  /// 6 px mark and wrong for a frame, so it takes the full step accent.
  static Color rewardInkOf(ContractClass c) => switch (c) {
    ContractClass.localNeed => StrideColors.accentSteps,
    ContractClass.bounty => StrideColors.rarityRare,
    ContractClass.regional => StrideColors.categoryQuest,
  };

  @override
  Widget build(BuildContext context) {
    final Color ink = done ? StrideColors.textMuted : inkOf(contractClass);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.55)),
        borderRadius: StrideRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: ink, borderRadius: StrideRadius.gate),
          ),
          const SizedBox(width: StrideSpace.s4),
          Text(
            labelOf(contractClass),
            style: StrideType.microLabel.copyWith(
              color: done ? StrideColors.textMuted : StrideColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The open contract: the flavour, the full reward, and the actions.
///
/// Everything the old permanently-expanded tile carried, in the one job the
/// player asked about. The brief is here rather than in the row because
/// prose is what you read once and progress is what you came to check.
class _ContractDetail extends StatelessWidget {
  const _ContractDetail({
    required this.contract,
    required this.busy,
    required this.onComplete,
    required this.onAccept,
    required this.onTrack,
  });

  final ContractView contract;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback? onAccept;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final ContractView c = contract;
    if (c.isCompletedOneTime) return const SizedBox.shrink();
    final BountyView? bounty = c.bounty;

    final List<String> rewardWords = <String>[
      for (final RequirementLine line in c.rewardItems)
        '${line.name} ×${line.required}',
      for (final SkillXpLine line in c.rewardSkillXp)
        '+${line.xp} ${line.skillName} XP',
      if (c.rewardCharacterXp > 0) '+${c.rewardCharacterXp} Character XP',
      if (c.teachesRecipeName case final String recipe) 'teaches $recipe',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.s10,
        StrideSpace.s8,
        StrideSpace.s10,
        StrideSpace.s10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            c.brief,
            style: StrideType.micro.copyWith(
              color: StrideColors.textSecondary,
            ),
            maxLines: 4,
          ),
          if (!c.available && c.unavailableReason != null) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              c.unavailableReason!,
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ],
          if (c.available) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                for (final RequirementLine line in c.requires)
                  _RequirementChip(line: line),
                for (final RequirementLine line in c.requiresOwned)
                  _RequirementChip(line: line),
                if (bounty != null)
                  _ProgressChip(
                    label: bounty.enemyName,
                    progress: bounty.accepted ? bounty.progress : 0,
                    required: bounty.required,
                    satisfied: bounty.met,
                    note: bounty.accepted ? null : 'accept first',
                  ),
              ],
            ),
            if (rewardWords.isNotEmpty) ...<Widget>[
              const SizedBox(height: StrideSpace.s8),
              const Text('REWARD', style: StrideType.microLabel, maxLines: 1),
              const SizedBox(height: StrideSpace.s2),
              Text(
                rewardWords.join(' · '),
                style: StrideType.micro.copyWith(
                  color: StrideColors.textPrimary,
                ),
              ),
            ],
            const SizedBox(height: StrideSpace.s10),
            // One game action per job, primary; Track is a utility beside
            // it. Deliver is a real command (it spends goods) and Accept is
            // the bounty's first step, so both take the filled control; not
            // ready yet is the same control, disabled, never a second shape.
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: bounty != null && !bounty.accepted
                      ? StrideButton(
                          label: busy ? '…' : 'Accept',
                          onPressed: busy ? null : onAccept,
                        )
                      : StrideButton(
                          label: busy
                              ? '…'
                              : c.contractClass == ContractClass.bounty
                              ? 'Claim'
                              : 'Deliver',
                          onPressed: busy || !c.canComplete
                              ? null
                              : onComplete,
                        ),
                ),
                const SizedBox(width: StrideSpace.s8),
                Expanded(
                  flex: 2,
                  child: StrideButton.secondary(
                    label: 'Track',
                    onPressed: busy ? null : onTrack,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One community project, as a nested block: staged progress and the
/// contribute control.
class _ProjectTile extends StatefulWidget {
  const _ProjectTile({
    required this.project,
    required this.busy,
    required this.onContribute,
    required this.onTrack,
  });

  final ProjectView project;
  final bool busy;
  final VoidCallback? onContribute;
  final VoidCallback onTrack;

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  /// Whether the long brief is open. Ephemeral UI state; the tile's facts —
  /// stage, materials, consequence, actions — never hide behind it.
  bool _briefOpen = false;

  @override
  Widget build(BuildContext context) {
    final ProjectView project = widget.project;
    final bool busy = widget.busy;
    final List<String> offer = <String>[];
    // Names resolved by the session are already in the lines; the offer's
    // words come from the current stage's lines so they match.
    final ProjectStageView current = project.stages[project.currentStage];
    for (final RequirementLine line in current.lines) {
      final int amount = project.contributable[line.item] ?? 0;
      if (amount > 0) offer.add('${line.name} ×$amount');
    }

    // A project is not an ordinary contract (brief §12): it gets the stage
    // ladder, an animated per-material bar, and the permanent-change preview
    // that makes contributing feel like building something. Its hierarchy
    // is tightened (PLAYABLE_EXPERIENCE_REFINEMENT_01 §26): title and stage,
    // the materials with their bars, the consequence, the actions — and the
    // lore folded behind one small toggle rather than four lines of prose
    // above the figures the player came to check.
    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                // Wraps rather than shrinks, as the contract title above: a
                // project name may take two lines but never lose a character.
                child: Text(project.name, style: StrideType.itemName),
              ),
              _StagePill(
                label: project.isComplete
                    ? 'COMPLETE'
                    : 'STAGE ${project.currentStage + 1} / '
                          '${project.stages.length}',
                done: project.isComplete,
              ),
            ],
          ),
          // The lore, subordinate: one tappable line, open on request.
          const SizedBox(height: StrideSpace.s2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _briefOpen = !_briefOpen),
            child: Text(
              _briefOpen
                  ? project.brief
                  // No glyph: the chevron and triangle code points are not
                  // in every face the app resolves to, and a missing glyph
                  // is a box. A word never is.
                  : 'About this project · more',
              style: StrideType.micro.copyWith(
                color: _briefOpen
                    ? StrideColors.textSecondary
                    : StrideColors.textMuted,
              ),
              maxLines: _briefOpen ? 6 : 1,
            ),
          ),
          if (!project.isComplete) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(
              current.name.toUpperCase(),
              style: StrideType.microLabel,
            ),
            const SizedBox(height: StrideSpace.s4),
            for (final RequirementLine line in current.lines) ...<Widget>[
              _MaterialProgressRow(line: line),
              const SizedBox(height: StrideSpace.s4),
            ],
            // The permanent change, previewed before the work is done — the
            // reason to contribute, not a surprise at the end (§12).
            if (project.completionHeadline != null ||
                project.developmentTo != null) ...<Widget>[
              const SizedBox(height: StrideSpace.s4),
              Text(
                'On completion: ${<String>[
                  ?project.completionHeadline,
                  if (project.developmentTo != null)
                    'the settlement becomes ${project.developmentTo}',
                ].join(' · ')}',
                style: StrideType.micro.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: StrideSpace.s10),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: StrideButton(
                    label: busy
                        ? '…'
                        : offer.isEmpty
                        ? 'Nothing to contribute'
                        : 'Contribute',
                    subLabel: busy || offer.isEmpty ? null : offer.join(', '),
                    onPressed: busy ? null : widget.onContribute,
                  ),
                ),
                const SizedBox(width: StrideSpace.s8),
                Expanded(
                  flex: 2,
                  child: StrideButton.secondary(
                    label: 'Track',
                    onPressed: busy ? null : widget.onTrack,
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(
              'The work is done; its benefits are permanent.',
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The project's stage, as the same restrained chip the contract rows wear
/// for their type, so the two kinds of tile share one grammar.
class _StagePill extends StatelessWidget {
  const _StagePill({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color ink = done ? StrideColors.textMuted : StrideColors.accentSteps;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StrideSpace.s6,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.55)),
        borderRadius: StrideRadius.chip,
      ),
      child: Text(
        label,
        style: StrideType.microLabel.copyWith(
          color: done ? StrideColors.textMuted : StrideColors.textSecondary,
        ),
      ),
    );
  }
}

/// One project material as a name, a live `held / required`, and an animated
/// fill — so a contribution visibly *builds* (brief §12: animate 2/12 →
/// 4/12) instead of a chip's number silently changing.
///
/// The animation is presentation over committed figures: the target fraction
/// is always the projected line the session returned, and
/// `TweenAnimationBuilder` merely eases the bar from wherever it last drew.
/// Reduced motion collapses the ease to its end state by the framework's own
/// duration handling.
class _MaterialProgressRow extends StatelessWidget {
  const _MaterialProgressRow({required this.line});

  final RequirementLine line;

  @override
  Widget build(BuildContext context) {
    final double fraction = line.required == 0
        ? 1
        : (line.progress / line.required).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                line.name,
                style: StrideType.micro.copyWith(
                  color: line.satisfied
                      ? StrideColors.textPrimary
                      : StrideColors.textSecondary,
                ),
              ),
            ),
            // The figure pulses once when it changes — the impact beat of a
            // contribution (PLAYABLE_EXPERIENCE_REFINEMENT_01 §27): `2 / 12`
            // becomes `3 / 12` with a short settle, the bar eases beneath it.
            // Keyed on the progress so a rebuild with the same figure plays
            // nothing.
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(line.progress),
              tween: Tween<double>(begin: 1.3, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (BuildContext context, double scale, Widget? child) =>
                  Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerRight,
                    child: child,
                  ),
              child: Text(
                '${formatSteps(line.progress)} / ${formatSteps(line.required)}'
                '${line.satisfied ? ' ✓' : ''}',
                style: StrideType.micro.copyWith(
                  color: line.satisfied
                      ? StrideColors.textPrimary
                      : StrideColors.textSecondary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: fraction),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) =>
              Container(
            height: 6,
            decoration: BoxDecoration(
              color: StrideColors.surfaceGround,
              borderRadius: StrideRadius.gate,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: StrideColors.accentSteps,
                  borderRadius: StrideRadius.gate,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Oak Plank 5 / 12" as a small capsule; green-ish text when satisfied is
/// not available (no success hue exists), so weight carries it instead.
class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.line});

  final RequirementLine line;

  @override
  Widget build(BuildContext context) => _ProgressChip(
    label: line.name,
    progress: line.progress,
    required: line.required,
    satisfied: line.satisfied,
    note: line.keptNotConsumed ? 'kept' : null,
  );
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.label,
    required this.progress,
    required this.required,
    required this.satisfied,
    this.note,
  });

  final String label;
  final int progress;
  final int required;
  final bool satisfied;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: StrideSpace.s8,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: StrideColors.surfaceRaised,
      borderRadius: StrideRadius.inner,
    ),
    child: Text(
      '$label ${formatSteps(progress)} / ${formatSteps(required)}'
      '${satisfied ? ' ✓' : ''}${note == null ? '' : ' · $note'}',
      style: StrideType.micro.copyWith(
        color: satisfied ? StrideColors.textPrimary : StrideColors.textSecondary,
      ),
    ),
  );
}

/// The inline panel for a contract command that is **not** a payoff: a
/// refusal, or an acceptance. Both are bookkeeping the board answers in
/// place; a completion never lands here (it rises in the reward layer).
class _ContractResultPanel extends StatelessWidget {
  const _ContractResultPanel({required this.report, required this.onContinue});

  final ContractReport report;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return _InlineNotice(
        text: report.detail ?? 'That could not be done.',
        onDismiss: onContinue,
      );
    }
    return RewardBeat(
      tier: RewardTier.minor,
      eyebrow: 'ACCEPTED',
      title: report.contractName,
      lines: const <String>['Victories count from now.'],
      onContinue: onContinue,
    );
  }
}

/// The inline panel for a project contribution that finished nothing, or a
/// refusal. A finished stage and a completed project rise in the reward
/// layer instead.
class _ProjectResultPanel extends StatelessWidget {
  const _ProjectResultPanel({required this.report, required this.onContinue});

  final ProjectReport report;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return _InlineNotice(
        text: report.detail ?? 'That could not be contributed.',
        onDismiss: onContinue,
      );
    }
    return RewardBeat(
      tier: RewardTier.minor,
      eyebrow: 'CONTRIBUTED',
      title: report.projectName,
      lines: <String>[
        for (final RewardLine line in report.contributed)
          '${line.name} ×${line.quantity}',
        if (report.characterXp > 0) '+${report.characterXp} Character XP',
      ],
      onContinue: onContinue,
    );
  }
}

/// A refusal, in place: one line and a way to clear it.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            style: StrideType.micro.copyWith(
              color: StrideColors.textSecondary,
            ),
            maxLines: 3,
          ),
        ),
        const SizedBox(width: StrideSpace.s8),
        StrideButton.secondary(label: 'OK', onPressed: onDismiss),
      ],
    ),
  );
}
