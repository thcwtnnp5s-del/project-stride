/// The traveller's folio — what walking has built.
///
/// ## The page, not the cards (EPO03, `DIR-05`)
///
/// This screen was five dark rectangles in a column: a portrait card, a
/// figures card, a steps card, a skills card, and two more for audio and the
/// playtest instrument. Six radius-14 rounded blocks of the same weight,
/// which is the first item on `DIR-05`'s failure list and the reason the
/// round exists.
///
/// It is now **one folio**. A `journalLeaf` [PageGround] bound at the left by
/// `KitTile.edgeSpine`; the bust seated in a `KitFrame.insetWell` window with
/// the three worn pieces in `KitFrame.slotWell` **margin wells** beside it;
/// the name over `KitMark.ruleOrnateA`; the walking figures as a ruled vellum
/// ledger divided by `KitTile.ruleJournal`, with the sync line and the Step
/// Tracker tab as its **foot**; the skills as chapter lines; and the audio
/// and playtest blocks as quiet footnotes under their own rules. No
/// [SectionCard] survives on this screen. The old `_DressingStrip`,
/// `_CombatBlock` and `_Rule` widgets were **deleted** rather than restyled,
/// which is the instruction Craft and Skill detail already followed.
///
/// Every kit name it draws through reserves its declared geometry whether or
/// not its raster has landed (`KIT_CONTRACT` §0), so the layout is finished
/// today and gains material without reflowing.
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
import 'package:stride_core/stride_core.dart'
    show ContentId, EquipmentSlot, SkillStanding;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/loadout_readout.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/traveler_art.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';
import 'audio_block.dart';
import 'playtest_block.dart';
import 'steps_block.dart';

/// The page's left gutter: the bound edge plus a breath.
///
/// The spine is a real object with a real width — `KitTiles.thicknessFor`
/// answers the same 32 whether or not `edge_spine` decodes — so the page's
/// text starts clear of it rather than under it. The right gutter stays the
/// ordinary screen gutter: a bound folio is asymmetric, and that asymmetry is
/// the binding being visible.
double get _spineGutter =>
    KitTiles.thicknessFor(KitTile.edgeSpine) + StrideSpace.s8;

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<SkillSummary> skills = s.skillSummaries;
    final StepHistory history = s.stepHistory();

    return PageGround(
      // The folio: one material, full bleed, bound at the left
      // (`DIR-05` — "Character | `journalLeaf` folio").
      //
      // `spine: false` and the binding drawn here, which is Adventure's
      // resolution of the same problem and for the same reason: `PageGround`
      // positions `KitTile.edgeSpine` with three edges and no width, and a
      // vertical strip handed an unbounded main axis asserts
      // `BoxConstraints forces an infinite width` on every test that mounts
      // the app. The request is filed and seconded (`REQUESTS_NAV.md`,
      // 2026-09-03); until `EdgeStrip` takes the axis its `KitStrip` already
      // declares, the binding is the kit's own fallback register at the
      // declared width, so the swap back is one widget and reflows nothing.
      surface: PanelSurface.journalLeaf,
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(
              _spineGutter,
              StrideSpace.s12,
              StrideSpace.screenGutter,
              StrideSpace.s16,
            ),
            children: _leaves(context, c, s, skills, history),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: KitTiles.thicknessFor(KitTile.edgeSpine),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: StrideColors.surfaceGround,
                border: Border(
                  right: BorderSide(color: StrideColors.borderDefault),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The folio's leaves, in reading order.
  List<Widget> _leaves(
    BuildContext context,
    SessionController c,
    StrideSession s,
    List<SkillSummary> skills,
    StepHistory history,
  ) => <Widget>[
    if (s.isStale) ...<Widget>[
      StaleBanner(busy: c.busy, onReload: c.reload),
      const SizedBox(height: StrideSpace.rhythmRow),
    ],

    // THE DRESSING SPACE — a window, a margin of wells, and a name.
    //
    // Not a card. The bust sits in the kit's own inset window and the
    // three worn pieces sit in slot wells out in the right margin,
    // where a folio keeps its marginalia. What is worn is then *named*
    // once, in ruled lines beneath, in each piece's rank ink — so the
    // well carries the picture and the line carries the word, and
    // neither repeats the other.
    _DressingSpace(equipped: s.equippedSummary, visual: s.equipmentVisualState),
    const SizedBox(height: StrideSpace.rhythmRow),

    // The name over an ornate rule, and the two identity figures under
    // it (`DIR-05`). `ruleOrnateA` is picture class: drawn once at ×1,
    // clipped, never tiled.
    const AdaptiveText(
      'Traveler',
      style: StrideType.numericHero,
      minScale: 0.7,
    ),
    const SizedBox(height: StrideSpace.s6),
    const _OrnateRule(),
    const SizedBox(height: StrideSpace.rhythmRow),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _IdentityFact(
            // `Level`, not `Character level`. The longer wording read
            // better and then needed 151 dp at text scale 1.4 in the
            // column this had beside the old portrait. `Skill levels`
            // beside it supplies the contrast.
            label: 'Level',
            value: '${s.characterLevel}',
            unit: '',
          ),
        ),
        const SizedBox(width: StrideSpace.s12),
        Expanded(
          child: _IdentityFact(
            label: 'Skill levels',
            value:
                '${skills.fold(0, (int a, SkillSummary k) => a + k.level)}'
                ' / '
                '${skills.fold(0, (int a, SkillSummary k) => a + k.maxLevel)}',
            unit: '${skills.length} skills',
          ),
        ),
      ],
    ),
    const SizedBox(height: StrideSpace.rhythmHero),

    // THE WALKING LEDGER — ruled vellum, stamped numerals.
    //
    // The rows were four filled value tiles once and a card around a
    // `RuledLedger` after that; they are now the page's own ruled
    // lines, divided by the kit's journal rule rather than by a
    // hairline drawn inside a rectangle. Every figure is a projection,
    // and teal marks a walking figure and nothing else — the skill XP
    // total below them is deliberately not teal, because it is not
    // steps.
    const KitRule(title: 'What walking has built'),
    const SizedBox(height: StrideSpace.rhythmRow),
    _Vellum(
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
            if (s.ledgerOriginCount > 1) '${s.ledgerOriginCount} sources',
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

    // The ledger's foot: whether the count is current, and the tab
    // that opens the full record. Under the same rules as the figures
    // it is about, because it is the same page (`DECISIONS/0026`).
    const StepsBlock(),
    const SizedBox(height: StrideSpace.rhythmHero),

    // The skills, as chapter lines: a plate in the margin rail, the
    // name in the skill's own ink, the level, and the progress rule
    // flush to the line's bottom edge (`ART-12` §3, §4). What a level
    // *opens* is the Skills tab's answer, not this folio's.
    const KitRule(title: 'Skills'),
    const SizedBox(height: StrideSpace.rhythmRow),
    for (final SkillStanding standing in s.skillStandings)
      _SkillChapter(standing: standing),
    const SizedBox(height: StrideSpace.rhythmGroup),

    // COMBAT — the figures the next encounter will be snapshotted from,
    // as ledger lines rather than as two rows of filled tiles.
    //
    // Every one of them is `combatFigures`, a projection of
    // `CombatRules.loadoutFor` and the level curve — the same function
    // the engine calls at encounter start. Nothing here is arithmetic
    // in a widget: "XP to next" is a field, not `threshold -
    // experience` done here, so the day the curve moves this section
    // moves with it.
    //
    // The worn pieces are **not named again** here. They are named once
    // in the dressing space at the top of the folio, which is what
    // ended the screen's habit of answering "what am I wearing" in two
    // places (`DIR-05` §1). What is left is what a fight actually reads.
    _CombatLedger(figures: s.combatFigures, playerHp: s.playerHp),
    const SizedBox(height: StrideSpace.rhythmHero),

    // The two footnotes: the player's audio preferences and, last and
    // quietest, the owner's playtest instrument (`DECISIONS/0025`).
    const AudioBlock(),
    const SizedBox(height: StrideSpace.rhythmHero),
    const PlaytestBlock(),
  ];
}

/// The ornate divider under the name, drawn once and clipped.
///
/// `ruleOrnateA` is picture class like a band (`KIT_CONTRACT` §8): its
/// flourishes are once-only ornaments, so a repeating strip would beat them
/// across the page. The box is reserved at the declared size whether or not
/// the raster decodes, and the fallback is the one hairline the product
/// already draws.
class _OrnateRule extends StatelessWidget {
  const _OrnateRule();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ClipRect(
      child: SizedBox(
        height: KitMarks.sizeFor(KitMark.ruleOrnateA).height,
        child: const KitOrnament(
          mark: KitMark.ruleOrnateA,
          fallback: Center(
            child: ColoredBox(
              color: StrideColors.separator,
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The folio's dressing space: the bust in a window, the gear in the margin.
///
/// ## Why the wells are a column at the right, and the names are lines below
///
/// The previous screen put the three pieces in a row of three chips spanning
/// the card, with the name wrapped under each icon. That was arithmetic, not
/// design: the right column beside a 158 dp window is 30 dp at 320 dp, which
/// holds no word at any scale a shrink ladder may reach.
///
/// A margin does not need to hold words. The wells go where marginalia goes —
/// a vertical strip at the page's outer edge, 64 dp each, the picture and
/// nothing else — and what is worn is *named* underneath in full-width ruled
/// lines, where `Waywarden Hood` and `Bronze Longsword` fit at 320 dp without
/// wrapping and can carry their rank ink and rank badge. Picture in the
/// margin, word on the page.
///
/// The bust renders whatever [TravelerArt.portraitFor] resolves for the
/// current loadout — five armour bodies as of EPO03, and whatever the
/// resolver learns next. Nothing here narrows it: an unresolved state falls
/// through to the base portrait, exactly as the resolver's own contract says.
class _DressingSpace extends StatelessWidget {
  const _DressingSpace({required this.equipped, required this.visual});

  final List<EquippedSummary> equipped;
  final EquipmentVisualState visual;

  /// Slot, the word, and the class shadow's sprite — the starting piece of
  /// that family, flattened to one ink in an empty well (`ClassShadow`).
  static const List<(EquipmentSlot, String, String)> _slots =
      <(EquipmentSlot, String, String)>[
        (EquipmentSlot.weapon, 'Weapon', 'item.training_sword'),
        (EquipmentSlot.armor, 'Armour', 'item.traveler_tunic'),
        (EquipmentSlot.tool, 'Tool', 'item.training_pickaxe'),
      ];

  /// The sprite in a margin well: 48 native at ×1, the item family's size.
  static const double _wellContent = 48;

  @override
  Widget build(BuildContext context) {
    final Map<EquipmentSlot, EquippedSummary> worn =
        <EquipmentSlot, EquippedSummary>{
          for (final EquippedSummary e in equipped) e.slot: e,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // **The portrait, not the figure.** VAWO01 first put the equipped
            // armour's standing rotation here, to answer the owner's "I want
            // to see what I'm wearing". Side by side at phone size that was a
            // downgrade and the device evidence showed it plainly: a 64² full
            // body in a 128 dp window leaves the face a handful of pixels,
            // and this is the one place the Traveler is a person rather than
            // a sprite. The bust wears the armour the figure wears (FMPO02),
            // so the answer is here anyway.
            KitPlate.well(
              frame: KitFrame.insetWell,
              contentWidth: StrideGeometry.portraitContent,
              contentHeight: StrideGeometry.portraitContent,
              child: PixelAsset.portrait(
                TravelerArt.portraitFor(visual) ?? PixelIcons.portraitTraveler,
              ),
            ),
            // The margin is whatever is left, and it is the wells' business
            // to sit at its outer edge.
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final (EquipmentSlot slot, String label, String shadow)
                    in _slots) ...<Widget>[
                  if (slot != _slots.first.$1)
                    const SizedBox(height: StrideSpace.rhythmRow),
                  Semantics(
                    label:
                        '$label: ${worn[slot]?.displayName ?? kEmptySlotWord}',
                    child: ExcludeSemantics(
                      child: KitPlate.well(
                        frame: KitFrame.slotWell,
                        contentWidth: _wellContent,
                        contentHeight: _wellContent,
                        child: worn[slot] == null
                            ? ClassShadow(
                                assetPath: PixelIcons.itemFor(
                                  ContentId.unchecked(shadow),
                                ),
                              )
                            : PixelAsset.item(
                                PixelIcons.itemFor(worn[slot]!.itemId),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.rhythmRow),
        for (final (EquipmentSlot slot, String label, _) in _slots)
          _WornLine(label: label, worn: worn[slot]),
      ],
    );
  }
}

/// `WEAPON · Bronze Longsword · RARE` on one ruled line of the folio.
///
/// The rank ink is the item's own; an empty slot says so in the muted ink and
/// keeps its line, because three lines that come and go would give the
/// dressing space three different heights for three different loadouts.
class _WornLine extends StatelessWidget {
  const _WornLine({required this.label, required this.worn});

  final String label;
  final EquippedSummary? worn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StrideSpace.s6),
    child: Row(
      children: <Widget>[
        SizedBox(
          // The wider of the three words at the designed size, so the names
          // beside them start at the same x and the three lines read as a
          // column. Not a fixed box around a growing value — the *name* is
          // the value, and it takes the rest of the line.
          width: 56,
          child: AdaptiveText(
            label.toUpperCase(),
            style: StrideType.compactLabel,
            minScale: 0.8,
          ),
        ),
        const SizedBox(width: StrideSpace.s8),
        Expanded(
          child: worn == null
              ? Text(
                  kEmptySlotWord,
                  style: StrideType.sub.copyWith(color: StrideColors.textMuted),
                  maxLines: 1,
                )
              : RarityName(
                  name: worn!.displayName,
                  rarity: worn!.rarity,
                  style: StrideType.sub,
                ),
        ),
        if (worn?.rarity != null) ...<Widget>[
          const SizedBox(width: StrideSpace.s8),
          RarityBadge(rarity: worn!.rarity),
        ],
      ],
    ),
  );
}

/// A column of ledger lines divided by the kit's journal rule.
///
/// The rule is `KitTile.ruleJournal` — a real ruled line on `journalLeaf`,
/// reserved at its declared 12 dp whether or not the raster decodes, with the
/// product's one hairline as its fallback. This is the page's own ruling, not
/// a hairline drawn inside a card, and it is why the ledger needs no box.
class _Vellum extends StatelessWidget {
  const _Vellum({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < rows.length; i++) ...<Widget>[
        if (i > 0)
          const KitEdge(
            tile: KitTile.ruleJournal,
            fallbackColor: StrideColors.separator,
          ),
        rows[i],
      ],
    ],
  );
}

/// The fight's figures, as ledger lines on the folio.
class _CombatLedger extends StatelessWidget {
  const _CombatLedger({required this.figures, required this.playerHp});

  final CombatFigures figures;

  /// Persistent HP (`DECISIONS/0023` §4): the current figure, read live —
  /// food and safe arrivals move it, and a folio showing only the ceiling
  /// would hide the one number expedition planning turns on.
  final int playerHp;

  @override
  Widget build(BuildContext context) {
    final CombatFigures f = figures;
    final int? next = f.nextLevelThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const KitRule(title: 'Combat'),
        const SizedBox(height: StrideSpace.rhythmRow),
        _Vellum(
          rows: <Widget>[
            LedgerRow(label: 'Level', value: '${f.level}'),
            LedgerRow(
              label: 'Experience',
              value: formatSteps(f.experience),
              // At the cap there is no next threshold, and saying so is more
              // honest than a bar that cannot move.
              note: next == null
                  ? 'at the cap'
                  : 'of ${formatSteps(next)} to the next level',
            ),
            LedgerRow(label: 'HP', value: '$playerHp / ${f.maxHp}'),
            LedgerRow(
              label: 'Attack',
              value: '${f.attack}',
              note: f.weaponName == null ? 'unarmed' : null,
            ),
            LedgerRow(
              label: 'Defence',
              value: '${f.defence}',
              note: f.armorName == null ? 'no armour' : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// A label, a figure and a unit, in the page's own ground.
///
/// Deliberately **not** a `LabeledValueTile`: a tile is a filled block, and
/// this folio has no filled blocks in it. These are lines of type on the
/// vellum, under the name they belong to.
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
      AdaptiveText(
        label.toUpperCase(),
        style: StrideType.microLabel,
        minScale: 0.8,
      ),
      const SizedBox(height: StrideSpace.s2),
      // `numericValue`, not `sectionHeading`. 22 px is the weight every other
      // figure in the app gets, and it is what makes this a character sheet
      // rather than a caption.
      AdaptiveText(value, style: StrideType.numericValue, minScale: 0.8),
      // The unit is on its own line, and that is a correction rather than a
      // preference: on the value's baseline it rendered the skill-levels fact
      // as `5 / 100 5 skills` — three numbers and a slash in one run — and
      // Visual QA misparsed it.
      if (unit.isNotEmpty) Text(unit, style: StrideType.micro, maxLines: 2),
    ],
  );
}

/// One skill, as a chapter line on the folio.
///
/// ## What left the row, and where it went
///
/// The row carried a name, an XP figure, `LEVEL n / 20` and a 26 dp icon rail
/// — four runs of type per skill, five skills deep, on a page whose subject is
/// the character rather than the skills. The chapter line keeps the two facts
/// that answer "where am I": the name in the skill's ink and the level. The XP
/// figures, the thresholds and what a level opens are the Skills tab's answer,
/// and this section defers to it rather than restating a third of it.
///
/// The progress rule is `SkillStanding.progress` — computed by
/// `SkillDefinition.standingAt` in `stride_core`, never by a fraction
/// assembled here. A widget indexing the XP curve is the defect this file's
/// own header exists to warn about.
class _SkillChapter extends StatelessWidget {
  const _SkillChapter({required this.standing});

  final SkillStanding standing;

  /// The sprite's edge. The skill family is 24 native at ×1 (a documented
  /// density exception), so the well's content is 32 and the sprite inside it
  /// stays on its own grid.
  static const double _content = 32;

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
                width: _content + KitFrames.insetFor(KitFrame.slotWell) * 2,
                height: _content + KitFrames.insetFor(KitFrame.slotWell) * 2,
                child: icon == null
                    ? null
                    : KitPlate.well(
                        frame: KitFrame.slotWell,
                        contentWidth: _content,
                        contentHeight: _content,
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
          // 4 dp, full bleed, flush to the line's bottom edge: the one mark
          // that separates two chapters, and it says something while doing
          // it. Square, like everything else this round; not type, so it does
          // not scale.
          SizedBox(
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
        ],
      ),
    );
  }
}
