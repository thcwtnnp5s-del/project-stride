/// The location's contract board: local needs, bounties, regional contracts,
/// and community projects — one backend, this place's fiction
/// (`DECISIONS/0023` §2–3).
///
/// Every control is a hint: `CompleteContract`, `AcceptContract` and
/// `ContributeToProject` re-validate on execute, and the engine's refusal is
/// rendered when it disagrees (`RULES.md` E-2). Nothing here computes a rule —
/// eligibility, rotation and rewards all arrive projected from the session.
///
/// Completion presentation follows the reward hierarchy (brief §67): a
/// delivery's result is an inline line; a taught recipe or revealed rumor gets
/// a held panel; a project stage is a held panel; project completion is the
/// major tier — a full-card banner with the world change, held until
/// Continue.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, ContractClass;

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
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

  Future<void> _complete(SessionController c, ContentId contract) async {
    final ContractReport? report = await c.completeContract(contract);
    if (!mounted || report == null) return;
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

          for (final ContractView need in board.localNeeds) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
            _ContractTile(
              contract: need,
              busy: c.busy,
              onComplete: () => _complete(c, need.id),
              onAccept: null,
              onTrack: () => c.trackGoalContract(need.id),
            ),
          ],
          for (final ContractView bounty in board.bounties) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
            _ContractTile(
              contract: bounty,
              busy: c.busy,
              onComplete: () => _complete(c, bounty.id),
              onAccept: () => _accept(c, bounty.id),
              onTrack: () => c.trackGoalContract(bounty.id),
            ),
          ],
          for (final ContractView regional in board.regionals) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
            _ContractTile(
              contract: regional,
              busy: c.busy,
              onComplete: () => _complete(c, regional.id),
              onAccept: regional.bounty == null
                  ? null
                  : () => _accept(c, regional.id),
              onTrack: () => c.trackGoalContract(regional.id),
            ),
          ],
          for (final ProjectView project in board.projects) ...<Widget>[
            const SizedBox(height: StrideSpace.s8),
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

/// One contract, as a nested block.
class _ContractTile extends StatelessWidget {
  const _ContractTile({
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
    final bool done = contract.isCompletedOneTime;
    final BountyView? bounty = contract.bounty;

    final List<String> rewardWords = <String>[
      for (final RequirementLine line in contract.rewardItems)
        '${line.name} ×${line.required}',
      for (final SkillXpLine line in contract.rewardSkillXp)
        '+${line.xp} ${line.skillName} XP',
      if (contract.rewardCharacterXp > 0)
        '+${contract.rewardCharacterXp} Character XP',
      if (contract.teachesRecipeName case final String recipe)
        'teaches $recipe',
    ];

    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                // Wraps rather than shrinks: an authored board title can
                // outrun even AdaptiveText's shrink floor at accessibility
                // scale on a narrow phone, and a name may take two lines but
                // never lose a character.
                child: Text(
                  contract.name,
                  style: done
                      ? StrideType.itemName.copyWith(
                          color: StrideColors.textMuted,
                        )
                      : StrideType.itemName,
                ),
              ),
              Text(
                done
                    ? 'DONE'
                    : switch (contract.contractClass) {
                        ContractClass.localNeed => 'ORDER',
                        ContractClass.bounty => 'BOUNTY',
                        ContractClass.regional => 'CONTRACT',
                      },
                style: StrideType.microLabel.copyWith(
                  color: StrideColors.textMuted,
                ),
              ),
            ],
          ),
          if (!done) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(contract.brief, style: StrideType.micro, maxLines: 3),
          ],
          if (!done && !contract.available &&
              contract.unavailableReason != null) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              contract.unavailableReason!,
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ],
          if (!done && contract.available) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                for (final RequirementLine line in contract.requires)
                  _RequirementChip(line: line),
                for (final RequirementLine line in contract.requiresOwned)
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
              const SizedBox(height: StrideSpace.s6),
              Text(
                'Reward: ${rewardWords.join(' · ')}',
                style: StrideType.micro.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: StrideSpace.s8),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                if (bounty != null && !bounty.accepted)
                  StrideButton.secondary(
                    label: busy ? '…' : 'Accept',
                    onPressed: busy ? null : onAccept,
                  )
                else
                  StrideButton.secondary(
                    label: busy
                        ? '…'
                        : contract.contractClass == ContractClass.bounty
                        ? 'Claim'
                        : 'Deliver',
                    onPressed: busy || !contract.canComplete
                        ? null
                        : onComplete,
                  ),
                StrideButton.secondary(
                  label: 'Track',
                  onPressed: busy ? null : onTrack,
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
class _ProjectTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final List<String> offer = <String>[];
    // Names resolved by the session are already in the lines; the offer's
    // words come from the current stage's lines so they match.
    final ProjectStageView current = project.stages[project.currentStage];
    for (final RequirementLine line in current.lines) {
      final int amount = project.contributable[line.item] ?? 0;
      if (amount > 0) offer.add('${line.name} ×$amount');
    }

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
              Text(
                project.isComplete
                    ? 'COMPLETE'
                    : 'STAGE ${project.currentStage + 1} / '
                          '${project.stages.length}',
                style: StrideType.microLabel.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          Text(project.brief, style: StrideType.micro, maxLines: 4),
          if (!project.isComplete) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(
              current.name.toUpperCase(),
              style: StrideType.microLabel,
            ),
            const SizedBox(height: StrideSpace.s4),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                for (final RequirementLine line in current.lines)
                  _ProgressChip(
                    label: line.name,
                    progress: line.progress,
                    required: line.required,
                    satisfied: line.satisfied,
                  ),
              ],
            ),
            const SizedBox(height: StrideSpace.s8),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                StrideButton.secondary(
                  label: busy
                      ? '…'
                      : offer.isEmpty
                      ? 'Nothing to contribute'
                      : 'Contribute ${offer.join(', ')}',
                  onPressed: busy ? null : onContribute,
                ),
                StrideButton.secondary(
                  label: 'Track',
                  onPressed: busy ? null : onTrack,
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

/// The held panel for a contract command's outcome.
class _ContractResultPanel extends StatelessWidget {
  const _ContractResultPanel({required this.report, required this.onContinue});

  final ContractReport report;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return SurfaceBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(report.detail ?? 'That could not be done.',
                style: StrideType.micro),
            const SizedBox(height: StrideSpace.s6),
            StrideButton.secondary(label: 'OK', onPressed: onContinue),
          ],
        ),
      );
    }
    if (report.accepted) {
      return SurfaceBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${report.contractName} accepted — victories count from now.',
              style: StrideType.body,
            ),
            const SizedBox(height: StrideSpace.s6),
            StrideButton.secondary(label: 'OK', onPressed: onContinue),
          ],
        ),
      );
    }
    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${report.contractName.toUpperCase()} COMPLETE',
            style: StrideType.sectionHeading,
          ),
          const SizedBox(height: StrideSpace.s6),
          for (final RewardLine line in report.rewardItems)
            Text('+${line.quantity} ${line.name}', style: StrideType.body),
          for (final SkillXpLine line in report.rewardSkillXp)
            Text('+${line.xp} ${line.skillName} XP', style: StrideType.sub),
          if (report.characterXp > 0)
            Text(
              '+${report.characterXp} Character XP'
              '${report.levelledUp ? ' — Level ${report.levelAfter}!' : ''}',
              style: StrideType.sub,
            ),
          if (report.taughtRecipeName case final String recipe)
            Text(
              'New recipe learned: $recipe',
              style: StrideType.body.copyWith(color: StrideColors.textPrimary),
            ),
          for (final String rumor in report.revealedRumorNames)
            Text(
              'Rumor heard: $rumor',
              style: StrideType.sub.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

/// The held panel for a project contribution — the **major** tier on full
/// completion (brief §70): headline, the settlement's change, and what is
/// newly possible.
class _ProjectResultPanel extends StatelessWidget {
  const _ProjectResultPanel({required this.report, required this.onContinue});

  final ProjectReport report;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return SurfaceBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(report.detail ?? 'That could not be contributed.',
                style: StrideType.micro),
            const SizedBox(height: StrideSpace.s6),
            StrideButton.secondary(label: 'OK', onPressed: onContinue),
          ],
        ),
      );
    }

    if (report.projectCompleted) {
      return SurfaceBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              report.completionHeadline ??
                  '${report.projectName.toUpperCase()} COMPLETE',
              style: StrideType.sectionHeading.copyWith(
                color: StrideColors.textPrimary,
              ),
            ),
            if (report.developmentChanged) ...<Widget>[
              const SizedBox(height: StrideSpace.s6),
              Text(
                '${report.developmentBefore} → ${report.developmentAfter}',
                style: StrideType.body,
              ),
            ],
            if (report.characterXp > 0) ...<Widget>[
              const SizedBox(height: StrideSpace.s4),
              Text(
                '+${report.characterXp} Character XP'
                '${report.levelledUp ? ' — Level ${report.levelAfter}!' : ''}',
                style: StrideType.sub,
              ),
            ],
            for (final String rumor in report.revealedRumorNames) ...<Widget>[
              const SizedBox(height: StrideSpace.s4),
              Text(
                'Rumor heard: $rumor',
                style: StrideType.sub.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: StrideSpace.s8),
            StrideButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      );
    }

    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            report.stageCompleted
                ? '${report.stageName.toUpperCase()} COMPLETE'
                : 'Contributed to ${report.projectName}',
            style: report.stageCompleted
                ? StrideType.sectionHeading
                : StrideType.body,
          ),
          const SizedBox(height: StrideSpace.s4),
          for (final RewardLine line in report.contributed)
            Text('−${line.quantity} ${line.name}', style: StrideType.sub),
          if (report.characterXp > 0)
            Text(
              '+${report.characterXp} Character XP'
              '${report.levelledUp ? ' — Level ${report.levelAfter}!' : ''}',
              style: StrideType.sub,
            ),
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}
