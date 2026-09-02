/// What walking has built.
///
/// ## Levels are shown, and that is not a rule in a widget
///
/// The skill level comes from `SkillDefinition.levelAt`, the same function
/// `GameEngine` gates gathering on. Calling it is **reading a domain function**,
/// not computing a rule, and it is projected through `StrideSession` rather than
/// reached for directly.
///
/// **XP into the current level is deliberately absent** — no `220 / 720` and no
/// bar. That span needs `xpThresholds[level - 1]` and `xpThresholds[level]`, and
/// indexing a content curve in a widget *is* rule math. If it is wanted later it
/// belongs on `SkillDefinition` beside `levelAt`, which is where the curve
/// already lives.
///
/// A progress track is therefore not built at all in Phase 1. There is nothing
/// honest to fill one with, and a track that exists with no legitimate caller is
/// a standing invitation to fabricate a fraction — which is exactly the Round 02
/// defect where four of five bars contradicted their captions.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show EquipmentSlot, SkillStanding;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/loadout_readout.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
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
import 'audio_block.dart';
import 'playtest_block.dart';
import 'steps_block.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<SkillSummary> skills = s.skillSummaries;
    final StepHistory history = s.stepHistory();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (s.isStale) ...<Widget>[
          StaleBanner(busy: c.busy, onReload: c.reload),
          const SizedBox(height: StrideSpace.rhythmRow),
        ],

        // Identity and standing, in one card.
        //
        // These were two: a portrait card whose right 40% was empty beside the
        // word `Traveler`, and a separate card of two tiles directly beneath it.
        // The screen therefore answered "who am I" and "how far along am I" in
        // two places that had to be read in sequence, and spent a card boundary
        // and 10 dp of gap separating a fact from its own subject.
        //
        // The earlier attempt to put a tile beside the portrait was reverted
        // because a 22 px numeral overflowed the 73 dp tile it produced at
        // 320 dp. What sits here now is not that tile — it is text that wraps
        // and shrinks, in a column that yields, so the failure mode it was
        // reverted for cannot occur. The two-tile pair is not recreated
        // elsewhere; the figures it carried are the two lines below.
        //
        // Both are projections, not rule math: the character level is stored,
        // and the skill totals sum `skillSummaries`, whose levels already came
        // from the content curve's own `levelAt`.
        SectionCard(
          role: PanelRole.heroPlate,
          surface: PanelSurface.journalLeaf,
          padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // **The portrait, not the figure.** VAWO01 first put the
                  // equipped armour's standing rotation here, to answer the
                  // owner's "I want to see what I'm wearing". Side by side at
                  // phone size that was a downgrade and the device evidence shows
                  // it plainly: a 64² full body in a 128 dp portrait well leaves
                  // the face a handful of pixels, and the Character screen's
                  // portrait is the one place the Traveler is a person rather
                  // than a sprite. The armour classes are barely separable at
                  // that size anyway.
                  //
                  // So the bust stays, and the figure moved to where a full body
                  // belongs — beside the equipment it depicts, in Inventory's
                  // equipment case.
                  InsetWell.square(
                    contentSize: StrideGeometry.portraitContent,
                    child: PixelAsset.portrait(PixelIcons.portraitTraveler),
                  ),
                  const SizedBox(width: StrideSpace.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const AdaptiveText(
                          'Traveler',
                          style: StrideType.numericHero,
                          minScale: 0.7,
                        ),
                        const SizedBox(height: StrideSpace.s8),

                        // A rule, not a gap. The name is the character; the two
                        // facts under it are the sheet. Without the separator the
                        // owner read the whole right column as metadata beside a
                        // portrait, which is a fair description of four unrelated
                        // text runs stacked at the same weight.
                        const _Rule(),
                        const SizedBox(height: StrideSpace.s8),
                        _IdentityFact(
                          // `Level`, not `Character level`. The longer wording read
                          // better and then needed 151 dp at text scale 1.4 in the
                          // 120 this column has beside the portrait at 320 dp — a
                          // clearer label that clips is not clearer. `Skill levels`
                          // directly beneath it supplies the contrast.
                          label: 'Level',
                          value: '${s.characterLevel}',
                          // The label already says which level this is; `character`
                          // beside the numeral was a qualifier reading as a
                          // sentence fragment.
                          unit: '',
                        ),
                        const SizedBox(height: StrideSpace.s8),
                        _IdentityFact(
                          label: 'Skill levels',
                          value:
                              '${skills.fold(0, (int a, SkillSummary k) => a + k.level)}'
                              ' / '
                              '${skills.fold(0, (int a, SkillSummary k) => a + k.maxLevel)}',
                          unit: '${skills.length} skills',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StrideSpace.rhythmRow),
              // What the traveller is dressed in, on the sheet that is about
              // the traveller (ART-12 §3). A readout: the pack owns the
              // controls, and this says only what is worn.
              _DressingStrip(equipped: s.equippedSummary),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.rhythmHero),

        // THE STEPS LEDGER — one ruled list where two rows of value tiles
        // used to sit (ART-12 §3).
        //
        // The tiles were four filled blocks carrying four figures of the same
        // kind, and a filled block is the app's way of saying "this one thing
        // matters". Four of them side by side says it four times and therefore
        // says nothing. A ledger is what a column of like figures looks like
        // when it is a record rather than a dashboard, and it is the shape the
        // Step Tracker behind it already uses.
        //
        // Every figure is a projection, and teal marks a walking figure and
        // nothing else — the skill XP total below them is deliberately not
        // teal, because it is not steps.
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeading(label: 'What walking has built'),
              const SizedBox(height: StrideSpace.rhythmRow),
              RuledLedger(
                rows: <Widget>[
                  LedgerRow(
                    label: 'Today',
                    value: formatSteps(history.today.granted),
                    leading: const WalkingGlyph(role: WalkingRole.stock),
                    valueColor: StrideColors.accentSteps,
                  ),
                  LedgerRow(
                    label: 'This week',
                    value: formatSteps(history.week),
                    note: 'last 7 days',
                    valueColor: StrideColors.accentSteps,
                  ),
                  LedgerRow(
                    label: 'Total walked',
                    // Since the last playtest reset, or lifetime when there
                    // has been none (`DECISIONS/0025`). The lifetime figure
                    // is named beneath once a reset has moved the baseline:
                    // history reported, never hidden.
                    value: formatSteps(s.walkedSinceBaseline),
                    // The source count is named only when more than one has
                    // been credited: a persisted count (never an identity)
                    // that explains a bank two devices both contributed to.
                    // This line is its one home on any surface.
                    note: <String>[
                      'steps earned',
                      if (s.walkedBaselineMoved)
                        'lifetime ${formatSteps(s.totalGranted)}',
                      if (s.ledgerOriginCount > 1)
                        '${s.ledgerOriginCount} sources',
                    ].join(' · '),
                    valueColor: StrideColors.accentSteps,
                  ),
                  LedgerRow(
                    label: 'Total skill XP',
                    value: formatSteps(s.totalSkillExperience),
                    note: 'across every skill',
                  ),
                  // The lifetime accounting, named as such, only once a reset
                  // has made "this playtest" and "ever" two different figures
                  // (`DECISIONS/0025`). The Adventure band shows this
                  // playtest's spend; this is the one place the lifetime spend
                  // is read.
                  if (s.walkedBaselineMoved) ...<Widget>[
                    LedgerRow(
                      label: 'Spent this playtest',
                      value: formatSteps(s.spentThisEpoch),
                      note: 'steps',
                      valueColor: StrideColors.accentSteps,
                    ),
                    LedgerRow(
                      label: 'Lifetime spent',
                      value: formatSteps(s.totalSpent),
                      note: 'every playtest',
                      valueColor: StrideColors.accentSteps,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.rhythmRow),

        // The tracker's door and the sync mark, directly under the figures
        // they are about (the physical-device polish pass, item 1;
        // `DECISIONS/0026`). Today and this week are in the ledger above now;
        // showing them twice on one screen was the duplication the ledger
        // exists to end.
        const StepsBlock(),
        const SizedBox(height: StrideSpace.rhythmGroup),

        // The skills, as spines rather than as five near-identical rows of
        // figures (ART-12 §3, §4): a plate, the name in the skill's own ink,
        // the level, and the progress rule flush to the bottom edge. What a
        // level *opens* is the Skills tab's answer, not this sheet's.
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeading(label: 'Skills'),
              const SizedBox(height: StrideSpace.rhythmRow),
              for (final SkillStanding standing in s.skillStandings)
                _SkillSpine(standing: standing),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.rhythmGroup),

        // COMBAT — the figures the next encounter will be snapshotted from.
        //
        // Every one of them is `combatFigures`, a projection of
        // `CombatRules.loadoutFor` and the level curve — the same function the
        // engine calls at encounter start. Nothing here is arithmetic in a
        // widget: "XP to next" is a field, not `threshold - experience` done
        // here, so the day the curve moves this card moves with it.
        //
        // Below the skills, not above them: the skills card is what walking
        // has built and stays above the fold at 393 dp; where this block sits
        // in the sheet's order is the owner's call once the slice is played.
        _CombatBlock(figures: s.combatFigures, equipped: s.equippedSummary),
        const SizedBox(height: StrideSpace.rhythmGroup),

        // The audio preferences (AUDIO_PRESENTATION_01): sound on/off and
        // the two bus volumes. Player-facing but quiet, above the owner's
        // instrument below.
        const AudioBlock(),
        const SizedBox(height: StrideSpace.rhythmGroup),

        // The owner's playtest controls, last and quiet (`DECISIONS/0025`).
        const PlaytestBlock(),
      ],
    );
  }
}

/// Level, XP to next, Max HP, Attack (with the weapon that counts), Defence
/// (with the armour that counts). Small, in the existing tile style.
///
/// ## Where the weapon and armour names sit, and why they moved
///
/// They were the `unit` line under the Attack and Defence figures, which is a
/// plain [StrideType.micro] string with no colour of its own — there is no way
/// to give one of those a rarity ink without teaching [LabeledValueTile] about
/// rarity, and that primitive is shared with three screens that have no items
/// on them.
///
/// So an occupied slot is now a **line of its own** beneath the tiles: the slot
/// word, the item's name in its rank's ink, and the rank as a word. An empty
/// slot keeps its `unarmed` / `no armour` unit line exactly as before, because
/// that belongs to the *figure* — it is why Attack is 1 — rather than to an
/// item. The name still appears once.
class _CombatBlock extends StatelessWidget {
  const _CombatBlock({required this.figures, required this.equipped});

  final CombatFigures figures;

  /// Every occupied slot, with rarity, from `StrideSession.equippedSummary` —
  /// the projection over the same `Equipment.bySlot` the fight reads.
  final List<EquippedSummary> equipped;

  /// The two slots that count in a fight, in the order the tiles above them
  /// run. The tool slot is deliberately absent: a tool never enters combat
  /// (`EquippedSummary.power`), and listing it here would imply it does.
  static const List<(EquipmentSlot, String)> _fighting =
      <(EquipmentSlot, String)>[
        (EquipmentSlot.weapon, 'Weapon'),
        (EquipmentSlot.armor, 'Armour'),
      ];

  EquippedSummary? _inSlot(EquipmentSlot slot) {
    for (final EquippedSummary e in equipped) {
      if (e.slot == slot) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final CombatFigures f = figures;
    final int? next = f.nextLevelThreshold;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Combat'),
          const SizedBox(height: StrideSpace.s10),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(label: 'Level', value: '${f.level}'),
              LabeledValueTile(
                label: 'Experience',
                value: formatSteps(f.experience),
                // At the cap there is no next threshold, and saying so is
                // more honest than a bar that cannot move.
                unit: next == null ? 'at the cap' : '/ ${formatSteps(next)}',
              ),
              // Persistent HP (`DECISIONS/0023` §4): the current figure over
              // the level's maximum, read live — food and safe arrivals move
              // it, and a screen showing only the ceiling would hide the one
              // number expedition planning turns on.
              LabeledValueTile(
                label: 'HP',
                value:
                    '${SessionScope.of(context).session.playerHp} / ${f.maxHp}',
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s8),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(
                label: 'Attack',
                value: '${f.attack}',
                unit: f.weaponName == null ? 'unarmed' : null,
              ),
              LabeledValueTile(
                label: 'Defence',
                value: '${f.defence}',
                unit: f.armorName == null ? 'no armour' : null,
              ),
            ],
          ),
          for (final (EquipmentSlot slot, String label) in _fighting)
            if (_inSlot(slot) case final EquippedSummary worn) ...<Widget>[
              const SizedBox(height: StrideSpace.s8),
              _EquippedLine(label: label, worn: worn),
            ],
        ],
      ),
    );
  }
}

/// `WEAPON · Bronze Sword · RARE` on one line, in the card's own ground.
///
/// Not a [SurfaceBlock]: the two tiles above it are already filled blocks, and
/// a third one would make the Combat card three competing surfaces. Same
/// reasoning as [_IdentityFact], one card down.
class _EquippedLine extends StatelessWidget {
  const _EquippedLine({required this.label, required this.worn});

  final String label;
  final EquippedSummary worn;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        // The wider of the two words at the designed size, so `Bronze Sword`
        // and `Traveler Tunic` start at the same x and the two lines read as a
        // column. Not a fixed box around a growing value — the *name* beside it
        // is the value, and it takes the rest of the row.
        width: 56,
        child: AdaptiveText(
          label.toUpperCase(),
          style: StrideType.compactLabel,
          minScale: 0.8,
        ),
      ),
      const SizedBox(width: StrideSpace.s6),
      // The worn piece's own approved icon
      // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5): equipment made
      // visible with existing art — swap the sword and the picture here
      // swaps with it. The full on-figure rendering waits for the
      // PixelLab gear rounds the milestone's gap register scopes.
      PixelAsset.item(PixelIcons.itemFor(worn.itemId)),
      const SizedBox(width: StrideSpace.s8),
      Expanded(
        child: RarityName(
          name: worn.displayName,
          rarity: worn.rarity,
          style: StrideType.sub,
        ),
      ),
      if (worn.rarity != null) ...<Widget>[
        const SizedBox(width: StrideSpace.s8),
        RarityBadge(rarity: worn.rarity),
      ],
    ],
  );
}

/// A label, a figure and a unit on one line, for the identity card.
///
/// Deliberately **not** a [LabeledValueTile]: a tile is a filled block, and two
/// of them stacked beside the portrait would give the card three competing
/// surfaces in 128 dp. These are lines of type in the card's own ground, so the
/// portrait stays the only object in the card.
class _IdentityFact extends StatelessWidget {
  const _IdentityFact({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // Adaptive, not plain: this column is what is left of a 320 dp card after
      // a 130 dp portrait, so it is the narrowest label surface in the app.
      AdaptiveText(
        label.toUpperCase(),
        style: StrideType.microLabel,
        minScale: 0.8,
      ),
      const SizedBox(height: StrideSpace.s2),
      // `numericValue`, not `sectionHeading`. At 16 px these figures sat beside
      // a 128 dp portrait and lost — the owner's device read was that the
      // portrait dominates and the progression beside it is metadata. 22 px is
      // the weight every other figure in the app gets, and it is what makes
      // this column a character sheet rather than a caption.
      AdaptiveText(value, style: StrideType.numericValue, minScale: 0.8),
      // The unit is on its own line, and that is a correction rather than a
      // preference.
      //
      // It first sat on the value's baseline, which rendered the skill-levels
      // fact as `5 / 100 5 skills` — three numbers and a slash in one run,
      // second thing the eye reaches on the screen. Visual QA misparsed it, and
      // a reviewer who cannot parse a figure has found a defect in the figure.
      if (unit.isNotEmpty) Text(unit, style: StrideType.micro, maxLines: 2),
    ],
  );
}

/// The three worn slots as chips, under the portrait row (ART-12 §3).
///
/// ## Where the strip sits, and why not in the right column
///
/// The brief puts the dressing strip in the folio's right column. Measured,
/// that column is what is left of the card after a 130 dp portrait well and a
/// 12 dp gap: about 175 dp at the 393 reference and **102 at 320**, which
/// gives three side-by-side chips 29 dp each — narrower than the icon they
/// carry. Spanning the card instead gives each chip ~100 dp at the reference
/// and 76 at 320, which a two-line wrapped name fits. The strip stays inside
/// the folio, under the row it belongs to; it is the arithmetic that moved it,
/// not a preference.
class _DressingStrip extends StatelessWidget {
  const _DressingStrip({required this.equipped});

  final List<EquippedSummary> equipped;

  static const List<(EquipmentSlot, String)> _slots = <(EquipmentSlot, String)>[
    (EquipmentSlot.weapon, 'Weapon'),
    (EquipmentSlot.armor, 'Armour'),
    (EquipmentSlot.tool, 'Tool'),
  ];

  @override
  Widget build(BuildContext context) {
    final Map<EquipmentSlot, EquippedSummary> worn =
        <EquipmentSlot, EquippedSummary>{
          for (final EquippedSummary e in equipped) e.slot: e,
        };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (EquipmentSlot slot, String label) in _slots) ...<Widget>[
          if (slot != _slots.first.$1)
            const SizedBox(width: StrideSpace.rhythmRow),
          Expanded(
            child: DressingChip(
              slot: label,
              itemName: worn[slot]?.displayName,
              rarity: worn[slot]?.rarity,
              iconPath: worn[slot] == null
                  ? null
                  : PixelIcons.itemFor(worn[slot]!.itemId),
            ),
          ),
        ],
      ],
    );
  }
}

/// One skill, as a spine (ART-12 §3, §4).
///
/// ## What left the row, and where it went
///
/// The row carried a name, an XP figure, `LEVEL n / 20` and a 26 dp icon rail —
/// four runs of type per skill, five skills deep, on a sheet whose subject is
/// the character rather than the skills. The spine keeps the two facts that
/// answer "where am I": the name in the skill's ink and the level. The XP
/// figures, the thresholds and what a level opens are the Skills tab's
/// answer, and this block defers to it rather than restating a third of it.
///
/// The progress rule is `SkillStanding.progress` — computed by
/// `SkillDefinition.standingAt` in `stride_core`, never by a fraction assembled
/// here. A widget indexing the XP curve is the defect this file's own header
/// exists to warn about.
class _SkillSpine extends StatelessWidget {
  const _SkillSpine({required this.standing});

  final SkillStanding standing;

  /// The plate's edge. The skill family is 24 native at ×1 (a documented
  /// density exception), so the plate is 32 and the sprite inside it stays on
  /// its own grid — a 32 dp *icon* would mean a fractional rescale.
  static const double _plate = 32;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(standing.skill);
    final Color accent = StrideColors.forSkill(standing.skill);
    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.rhythmRow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              // The rail is reserved whether or not this skill has an icon. A
              // row that collapsed when the icon was null would give the list
              // two different left margins and no alignment rail — which is
              // exactly what Visual QA found when only one of five skills had
              // a sprite.
              SizedBox(
                width: _plate + 2,
                height: _plate + 2,
                child: icon == null
                    ? null
                    : InsetWell.square(
                        contentSize: _plate,
                        child: PixelAsset.skill(icon),
                      ),
              ),
              const SizedBox(width: StrideSpace.s10),
              Expanded(
                child: AdaptiveText(
                  standing.displayName,
                  style: StrideType.cardTitle,
                  color: accent,
                  minScale: 0.8,
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Text(
                standing.isMaxLevel ? 'MAX' : 'LV ${standing.level}',
                style: StrideType.microLabel.copyWith(
                  fontFeatures: StrideType.tabularFigures,
                ),
                maxLines: 1,
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s6),
          // 4 dp, full bleed, flush to the spine's bottom edge: the one mark
          // that separates two spines, and it says something while doing it.
          // Not type, so it does not scale.
          ClipRRect(
            borderRadius: StrideRadius.chip,
            child: SizedBox(
              height: 4,
              child: Stack(
                children: <Widget>[
                  const ColoredBox(
                    color: StrideColors.surfaceBlock,
                    child: SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: standing.progress.clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: accent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline rule inside a card.
///
/// `separator`, not `borderDefault` — the border ladder is exactly one weight in
/// exactly one colour and is for *outlines*. This is a within-card division,
/// which is what `StrideColors.separator` was defined for and, until now, the
/// only thing in the palette with no caller.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: StrideColors.separator,
    child: SizedBox(height: 1, width: double.infinity),
  );
}
