/// Equipment, evaluated at a glance (PLAYABLE_POLISH_01 §6).
///
/// The owner's device found gear unreadable: a Bronze Sword in the bag and
/// a Bronze Sword on the bench said a name and a rank, and whether either
/// was worth making or wearing was a guess. Two presentations of one
/// projection (`StrideSession.gearStatsOf`) answer it:
///
/// - [GearStatsBlock] — the full story for a surface with room: the stat,
///   what is worn in the slot and its figure, the verdict word, the passives
///   in player words. The Craft detail carries it.
/// - [GearStatLine] — the one line a grid tile can afford: `ATK 7 · +2`,
///   `DEF 3 · WORN`, `PICKAXE · T1`. The Inventory tile carries it on the
///   marker line it already reserved.
///
/// No new hue. The verdict is a word, and the figures are the primary ink;
/// a downgrade is muted rather than red, because the palette has no red
/// that is not a skill's.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show EquipmentSlot, ToolKind;

import '../../runtime/stride_session.dart'
    show GearStats, GearVerdict, toolProfessionOf;
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'surfaces.dart';

/// The full evaluation, for the Craft detail and anywhere else with a row.
class GearStatsBlock extends StatelessWidget {
  const GearStatsBlock({super.key, required this.stats});

  final GearStats stats;

  @override
  Widget build(BuildContext context) {
    final GearStats g = stats;
    final bool tool = g.slot == EquipmentSlot.tool;
    final Color verdictInk = switch (g.verdict) {
      GearVerdict.upgrade ||
      GearVerdict.firstInSlot => StrideColors.textPrimary,
      GearVerdict.equipped ||
      GearVerdict.sidegrade ||
      GearVerdict.toolSwap => StrideColors.textSecondary,
      GearVerdict.downgrade => StrideColors.textMuted,
    };
    // A tool names the worn tool's profession and tier — `Bronze Pickaxe ·
    // Mining tool · Tier 1` — never a power figure (the correction pass).
    final String wornLine = switch (g.verdict) {
      GearVerdict.equipped => 'Worn now',
      GearVerdict.firstInSlot => 'Nothing in the ${_slotWord(g.slot)} slot',
      _ when tool =>
        'Currently equipped: ${g.wornName} · '
            '${toolProfessionOf(g.wornToolKind ?? ToolKind.none)} tool · '
            'Tier ${g.wornTier}',
      _ => 'Worn: ${g.wornName} ${g.wornPower}',
    };

    // **Ruled, not boxed** (EPO03 `DIR-05`). This block used to be a
    // `surfaceBlock` rectangle with a radius — one more of the thirty-four
    // dark cards the round exists to end — and it appears on two pages made
    // of something: the pack's canvas and the bench's folio. So it sits on
    // whatever it is opened over, under a rule, and the material shows
    // through. Nothing about what it says changed.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StrideSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const KitRule(style: KitRuleStyle.chart),
          const SizedBox(height: StrideSpace.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tool
                          ? '${g.profession!.toUpperCase()} TOOL'
                          : g.statName.toUpperCase(),
                      style: StrideType.microLabel,
                      maxLines: 1,
                    ),
                    const SizedBox(height: StrideSpace.s2),
                    AdaptiveText(
                      tool ? 'Tier ${g.tier}' : '${g.power}',
                      style: tool ? StrideType.sub : StrideType.numericValue,
                      color: StrideColors.textPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    g.verdictLabel,
                    style: StrideType.microLabel.copyWith(color: verdictInk),
                    maxLines: 1,
                  ),
                  if (!tool)
                    if (g.deltaLabel case final String delta) ...<Widget>[
                      const SizedBox(height: StrideSpace.s2),
                      AdaptiveText(
                        delta,
                        style: StrideType.sub,
                        color: verdictInk,
                      ),
                    ],
                ],
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s4),
          Text(
            wornLine,
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 2,
          ),
          for (final String passive in g.passives) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            Text(
              passive,
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
              maxLines: 3,
            ),
          ],
          // What the worn piece gives up if this one replaces it — the same
          // sentences the worn piece's own passives read as, capped at two
          // so the block stays a glance (`DECISIONS/0028` §6).
          for (final String lost in g.tradeOffLines.take(2)) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            Text(
              'Trades away: $lost',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              maxLines: 2,
            ),
          ],
          // The derived lineage's forward pointer, so a piece's future is
          // known before it is spent.
          if (g.upgradeLine case final String upgrade) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            Text(
              'Later: $upgrade',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  static String _slotWord(EquipmentSlot slot) => switch (slot) {
    EquipmentSlot.weapon => 'weapon',
    EquipmentSlot.armor => 'armour',
    EquipmentSlot.tool => 'tool',
  };
}

/// The one line a tile can afford.
///
/// `ATK 7 +2` for a weapon that beats the worn one by two; `DEF 3` for the
/// armour on the Traveler's back (the Unequip beneath it says worn);
/// `TIER 1` for a tool, whose worth is what it opens rather than a
/// figure. Compact label role, one line, never wraps — the tile reserved
/// exactly this line for `EQUIPPED`, and a 393 dp four-column cell gives
/// it about 68 dp, so every form stays within ten characters.
class GearStatLine extends StatelessWidget {
  const GearStatLine({super.key, required this.stats});

  final GearStats stats;

  /// The same figure, **split for stamping** (EPO03): the hard little label,
  /// the numeral, and the comparison — three parts the equipment case sets at
  /// three weights instead of one running sentence. Derived from the same
  /// projection as [textOf], from the same fields, so the case and the pocket
  /// still cannot disagree about a piece.
  static String labelOf(GearStats g) =>
      g.slot == EquipmentSlot.tool ? 'TIER' : g.statShort;

  static String figureOf(GearStats g) =>
      g.slot == EquipmentSlot.tool ? '${g.tier}' : '${g.power}';

  /// `+2` against the worn piece, or null where there is nothing to compare —
  /// a tool's worth is what it opens, and a worn piece is not better than
  /// itself.
  static String? noteOf(GearStats g) {
    if (g.slot == EquipmentSlot.tool) return null;
    return switch (g.verdict) {
      GearVerdict.equipped || GearVerdict.firstInSlot => null,
      _ => g.deltaLabel,
    };
  }

  static String textOf(GearStats g) {
    // A tool's line is its tier alone: the icon and the name beside it
    // already say axe or pickaxe, and `PICKAXE T0` needs 70 dp where the
    // cell has 68 (the clipping detector in ui_responsive_test caught it).
    if (g.slot == EquipmentSlot.tool) return 'TIER ${g.tier}';
    final String tail = switch (g.verdict) {
      GearVerdict.equipped || GearVerdict.firstInSlot => '',
      _ => g.deltaLabel ?? '',
    };
    return '${g.statShort} ${g.power}${tail.isEmpty ? '' : ' $tail'}';
  }

  @override
  Widget build(BuildContext context) {
    final GearStats g = stats;
    final Color ink = switch (g.verdict) {
      GearVerdict.downgrade => StrideColors.textMuted,
      GearVerdict.sidegrade ||
      GearVerdict.toolSwap => StrideColors.textSecondary,
      _ => StrideColors.textPrimary,
    };
    return Text(
      textOf(g),
      style: StrideType.compactLabel.copyWith(color: ink),
      maxLines: 1,
      textAlign: TextAlign.center,
    );
  }
}
