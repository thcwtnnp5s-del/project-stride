/// One enemy at this location, what fighting it means, and the action.
///
/// Reads an [EncounterOption] projection and dispatches
/// `SessionController.startEncounter`. It carries **no step cost anywhere**:
/// starting an encounter is free by decision (`DECISIONS/0020` §3), and a cost
/// tile here would be the most convincing lie on the tab.
///
/// ## The creature is present before the fight
///
/// The card opens with the enemy itself — its committed combat idle, grounded
/// on a small stage band — so the tab says "this creature is here, and I can
/// choose to fight it" rather than listing one (`ACTIVITY_FEEL_PRESENTATION_01`
/// §1.3). It is deliberately **not** an inventory icon and not a boss overlay:
/// the same art the combat stage will fell, at the same grounding rule, on a
/// band the size of the creature standing on it and tinted with the region's
/// own deep ink (`ART-12` §7) — a strip, still, not a scene. The idle
/// loops for one bounded visit and then holds its first frame — a figure that
/// never stops moving implies something is happening, and nothing is — and
/// resumes on a return to the app, exactly as `CombatStage` and
/// `AmbientPlayer` reason. An enemy the art table does not know renders the
/// card as it always was: no strip, no empty box, no crash (`RULES.md` E-5).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, EnemyBehavior, KnowledgeTier;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/band_plate.dart';
import '../../components/data_display.dart';
import '../../components/grounded_sprite.dart';
import '../../components/rarity_item_title.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/surfaces.dart';
import '../../icons/combat_assets.dart';
import '../../icons/encounter_habitat.dart';
import '../../state/audio_scope.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

/// The encounter list: every enemy here as a compact, selectable row, with
/// one expanded detail for the selected creature.
///
/// ## What this replaces (PRESENTATION_WORLD_REWARD_FEEL_01 §15)
///
/// One full [EncounterCard] per enemy — the 120 dp creature band, the chips,
/// three stat tiles, the XP line, the drops and the button, about 400 dp
/// each — permanently expanded, for every enemy at the location. Once the
/// gather cards became rows, this was the tallest thing left on Adventure;
/// the owner's device found Salamander and Cave Goblin between them
/// consuming most of a screen.
///
/// The rows are ~48 dp. Everything the card carried is still here and still
/// exact — the creature's own idle, its knowledge tier, its known drops in
/// their rarity ink, its stats, Start Combat — inside the one enemy the
/// player is actually considering. This is the same shape `ActivityPanel`
/// uses for gathering, deliberately: two lists that behave differently for
/// no reason are two things to learn.
///
/// Combat itself is untouched. Nothing here decides an outcome, and every
/// dispatch is still re-validated by the engine (`RULES.md` E-2).
class EncounterPanel extends StatelessWidget {
  const EncounterPanel({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<EncounterOption> options;

  /// The expanded enemy, or null when the list is fully collapsed.
  final ContentId? selected;

  /// Called with the tapped enemy, or null when the open row is tapped again.
  final ValueChanged<ContentId?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Encounters'),
          const SizedBox(height: StrideSpace.s6),
          // Trodden ground, under the list of what walks it (FMPO02).
          const BandPlate(band: StrideBand.encounterGround),
          const SizedBox(height: StrideSpace.s6),
          for (final EncounterOption o in options) ...<Widget>[
            _EncounterRow(
              option: o,
              selected: selected == o.enemyId,
              onTap: () => onSelect(selected == o.enemyId ? null : o.enemyId),
            ),
            if (selected == o.enemyId)
              Padding(
                padding: const EdgeInsets.only(
                  top: StrideSpace.s6,
                  bottom: StrideSpace.s6,
                ),
                child: EncounterCard(option: o),
              ),
          ],
        ],
      ),
    );
  }
}

/// One compact encounter row: what it is, what it does, and how much of this
/// visit is left.
///
/// The name over the tier and the three combat figures, with the
/// remaining-this-visit count on the right — or SPENT, because the one thing
/// a collapsed row must never hide is that the creature cannot be fought.
class _EncounterRow extends StatelessWidget {
  const _EncounterRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final EncounterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EncounterOption o = option;
    final String subLine = <String>[
      EncounterCard.knowledgeLabel(o),
      'HP ${o.maxHealth}',
      'ATK ${o.attack}',
      'DEF ${o.defence}',
    ].join(' · ');

    return Semantics(
      button: true,
      selected: selected,
      label: o.name,
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
            // One border weight and one border colour, by the palette's own
            // rule — the open row is distinguished by its raised fill, a
            // quiet rule in the commit control's own edge, and by the detail
            // beneath it; no colour is invented for this list
            // (PLAYABLE_EXPERIENCE_REFINEMENT_01 §20). The edge and not the
            // walking accent's dim form since FMPO02 wave 3: L-16 reserves
            // teal for step figures, and a selection is not one.
            border: Border.all(
              color: selected
                  ? StrideColors.actionEdge
                  : StrideColors.borderDefault,
            ),
            borderRadius: StrideRadius.inner,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveText(
                      o.isBoss ? '${o.name} · Boss' : o.name,
                      style: StrideType.itemName,
                      color: StrideColors.textPrimary,
                    ),
                    Text(
                      subLine,
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              // SPENT means "exhausted this visit — travel resets it", and
              // only that. A knowledge-gated veteran says LOCKED instead:
              // a wrong word here teaches a false rule about what walking
              // buys (FDO01 final review, `DECISIONS/0028`).
              Text(
                o.available
                    ? '${o.remainingThisVisit}/${o.encountersPerVisit}'
                    : o.reason == 'enemy_not_known'
                    ? 'LOCKED'
                    : 'SPENT',
                style: StrideType.microLabel.copyWith(
                  color: o.available
                      ? StrideColors.textSecondary
                      : StrideColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected enemy's detail, as a **field-guide entry**: the creature in
/// its habitat, what the habitat is, what is known about it, and the action.
///
/// ## Why a dossier and not a card of chips
///
/// EPO03's direction for this surface is the field guide (`DIR-12`). The
/// previous detail was the round's own failure list in miniature — a habitat
/// band, then a row of three pill chips repeating what the lines beside them
/// already said, then three bordered value tiles, on a bordered card inside a
/// bordered card. Everything it stated is still stated here and still exact;
/// none of it is stated twice:
///
/// * the **tier is a stamp** on the name plate (`KitMark.ribbonLabel`), where
///   a field guide puts the status of a sighting, instead of a chip;
/// * the **boss** says so in the name line ("Guards this place"), where the
///   card already had a sentence for it;
/// * the **habitat is named** under the creature — "Frostmere ·
///   wind-packed snow" — which is the one fact a habitat window cannot say on
///   its own and the whole reason the window is worth drawing;
/// * **HP / ATK / DEF are one ruled threat line**, not three boxes;
/// * the **behaviour** is a sentence under it, because that is what it is.
///
/// The page is `journalLeaf`, the guide's own paper. `startEncounter` and
/// every projection value it reads are untouched.
class EncounterCard extends StatelessWidget {
  const EncounterCard({super.key, required this.option});

  final EncounterOption option;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final EncounterOption o = option;
    final CombatantArt? art = CombatAssets.enemyFor(o.enemyId);
    final ContentId? here = c.session.currentLocation;
    // The habitat is resolved here rather than inside the stage, because the
    // page names it in words as well as drawing it. One lookup, one truth:
    // the caption and the window can never disagree about where this is.
    final HabitatPlate? plate = here == null
        ? null
        : EncounterHabitat.plateFor(here, enemy: o.enemyId);

    return SectionCard(
      // The guide's paper. The list around it is the board; this is the leaf
      // pinned to it.
      surface: PanelSurface.journalLeaf,
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (art != null) ...<Widget>[
            // The habitat window. Its ground, its tint and what is drawn in
            // front of the creature belong to the *place*, not to the
            // creature: an enemy is standing somewhere, and the somewhere is
            // where the player is.
            _EnemyStage(art: art, place: here, plate: plate, boss: o.isBoss),
            const SizedBox(height: StrideSpace.s10),
          ],
          // The name plate: species, standing, habitat — and the sighting's
          // tier stamped beside it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdaptiveText(o.name, style: StrideType.cardTitle),
                    Text(
                      o.isBoss ? 'Guards this place' : 'Roams here',
                      style: StrideType.sub,
                      maxLines: 1,
                    ),
                    if (habitatLine(c, plate) case final String where)
                      Text(
                        where,
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              // The compact knowledge tier (`DECISIONS/0023` §5): Seen,
              // Studied, Known — and then it stops. Presentation only.
              TierStamp(tier: o.knowledge),
            ],
          ),
          const SizedBox(height: StrideSpace.s6),
          // The entry's rule. `ruleOrnateA` is the kit's own "rule under a
          // name" ornament and this surface is one of the two it was authored
          // for (KIT_CONTRACT §3); it falls back to the hairline the card
          // already drew.
          const KitOrnament(
            mark: KitMark.ruleOrnateA,
            fallback: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(color: StrideColors.separator),
                child: SizedBox(height: 1),
              ),
            ),
          ),
          const SizedBox(height: StrideSpace.s6),
          // The threat, as one line a reader scans rather than three boxes a
          // reader parses.
          Text(
            'HP ${o.maxHealth}   ATK ${o.attack}   DEF ${o.defence}',
            style: StrideType.itemName,
            maxLines: 1,
          ),
          const SizedBox(height: StrideSpace.s2),
          Text(
            _behaviorLabel(o.behavior),
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 2,
          ),
          if (studyLine(o) case final String study) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            Text(
              study,
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              maxLines: 1,
            ),
          ],
          // WHAT I KNOW ABOUT THIS CREATURE — learning the ecology
          // (PRESENTATION_WORLD_REWARD_FEEL_01 §24). The stamp above says how
          // far along the study is; this says what the study has bought:
          // each known drop in its own rarity's ink, and the signature as
          // `???` until the enemy is Known. Presentation only — the roll is
          // identical at every tier (`DECISIONS/0023` §5), and every value
          // here is the session's own projection.
          const SizedBox(height: StrideSpace.s10),
          Text(
            '+${o.xp} XP',
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
          ),
          if (o.drops.isNotEmpty) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            const Text('KNOWN DROPS', style: StrideType.microLabel),
            const SizedBox(height: StrideSpace.s4),
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s4,
              children: <Widget>[
                for (final DropPreview d in o.drops)
                  d.revealed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            RarityName(
                              name: d.signature ? '${d.name} ★' : d.name,
                              rarity: d.rarity,
                              style: StrideType.micro,
                            ),
                            // Studying pays off in words, knowing in figures
                            // (Fable V2 Iteration 02): the qualifier is the
                            // authored chance the engine rolls, graduated by
                            // tier — nothing below Studied, a frequency word
                            // at Studied, the exact percent at Known.
                            if (_chanceLabel(o, d) case final String chance)
                              Text(
                                ' · $chance',
                                style: StrideType.micro.copyWith(
                                  color: StrideColors.textSecondary,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          '???',
                          style: StrideType.micro.copyWith(
                            color: StrideColors.textMuted,
                          ),
                        ),
              ],
            ),
          ],
          const SizedBox(height: StrideSpace.s12),
          StrideButton(
            label: c.busy ? 'Starting…' : 'Start Combat',
            subLabel: c.busy ? null : _subLabel(o),
            onPressed: c.busy || !o.available
                ? null
                : () {
                    // The commit into danger — one medium tap as the fight
                    // begins, the punctuation between planning and combat.
                    AudioScope.maybeRead(context)?.hapticMedium();
                    c.startEncounter(o.enemyId);
                  },
          ),
        ],
      ),
    );
  }

  /// "Frostmere · wind-packed snow" — where this is, and what the ground is.
  /// Null before the game starts, when there is no place to name.
  static String? habitatLine(SessionController c, HabitatPlate? plate) {
    final String where = c.session.locationName;
    if (where.isEmpty || where == '—') return null;
    return plate == null ? where : '$where · ${plate.caption}';
  }

  /// The distance to the next tier, in the guide's own grammar, or null when
  /// the ladder has stopped. The tier word itself is on the stamp, so this
  /// says only what the stamp cannot.
  static String? studyLine(EncounterOption o) => switch (o.knowledge) {
    KnowledgeTier.unseen => 'Not yet sighted',
    KnowledgeTier.seen => '${o.victories}/${o.studiedAt} toward Studied',
    KnowledgeTier.studied => '${o.victories}/${o.knownAt} toward Known',
    KnowledgeTier.known => null,
  };

  static String _behaviorLabel(EnemyBehavior b) => switch (b) {
    EnemyBehavior.steady => 'One strike a turn',
    EnemyBehavior.flurry => 'Two light strikes a turn',
    EnemyBehavior.guarded => 'Heavy strike every third turn',
  };

  /// What the card may say about a drop's chance, by knowledge tier. The
  /// projection always carries the true figure; this decides how much of it
  /// the player has earned. Word boundaries: half the fights or better is
  /// "usually", a fifth or better "often", the rest "rarely".
  static String? _chanceLabel(EncounterOption o, DropPreview d) {
    if (!d.revealed || d.chancePercent <= 0) return null;
    return switch (o.knowledge) {
      KnowledgeTier.known => '${d.chancePercent}%',
      KnowledgeTier.studied =>
        d.chancePercent >= 50
            ? 'usually'
            : d.chancePercent >= 20
            ? 'often'
            : 'rarely',
      KnowledgeTier.unseen || KnowledgeTier.seen => null,
    };
  }

  /// The tier, with the distance to the next one while one exists. Shared
  /// with the collapsed row, so the two cannot describe one study
  /// differently.
  static String knowledgeLabel(EncounterOption o) => switch (o.knowledge) {
    KnowledgeTier.unseen => 'Unseen',
    KnowledgeTier.seen => 'Seen · ${o.victories}/${o.studiedAt} to Studied',
    KnowledgeTier.studied => 'Studied · ${o.victories}/${o.knownAt} to Known',
    KnowledgeTier.known => 'Known',
  };

  /// What the button says under itself: how much of this visit is left, or the
  /// truthful reason it is disabled, in the engine's order.
  ///
  /// An available enemy now carries a figure rather than nothing, because
  /// "you can fight this" and "you can fight this twice more before you have
  /// to travel" are different pieces of planning and the second is the one a
  /// player with a route in mind is actually asking about
  /// (`DECISIONS/0021` §1). The spent line is unchanged, word for word: the
  /// player's experience of it did not change, only how many wins it took.
  static String? _subLabel(EncounterOption o) => o.available
      ? '${o.remainingThisVisit} of ${o.encountersPerVisit} this visit'
      : _reasonText(o);

  /// The truthful reason the button is disabled, in the engine's order.
  static String? _reasonText(EncounterOption o) => switch (o.reason) {
    null => null,
    // The Veteran Hunts gate (`DECISIONS/0028`): the card states the same
    // rule the engine refuses with — study the species, the veteran waits.
    'enemy_not_known' =>
      o.requiresKnownEnemyName == null
          ? 'Will not show itself yet'
          : 'Know the ${o.requiresKnownEnemyName} to draw it out',
    'enemy_driven_off' => 'Driven off — returns after you travel',
    'encounter_in_progress' => 'Finish your current encounter',
    'session_not_ready' => 'Reload before fighting',
    _ => 'Not available right now',
  };
}

/// The creature on its ground: a small stage band carrying the enemy's combat
/// idle, grounded, bottom-aligned, with the headroom above it.
///
/// The band is the gather stage's visual language at encounter size — a
/// ground tone bright enough for a multiply contact shadow to darken (the
/// finding `gather_node_card.dart` records), the default border, the inner
/// radius, the figure seated low. It is a strip, not a scene: no backdrop, no
/// position, no camera.
///
/// FMPO02 changed two things about it and neither is decoration:
///
/// * **Its height is the creature's** ([heightFor]), not one constant sized
///   for the boss. That is the owner's "a small wolf in a giant blank
///   rectangle" answered at its cause.
/// * **Its tone is the region's** deep ink, and it has a slot for an authored
///   **habitat plate** (`encounter_habitat.dart`) under the figure. The plate
///   is a flat ground plane — contact and material — never the "full battle
///   background per card" the owner ruled out.
class _EnemyStage extends StatelessWidget {
  const _EnemyStage({
    required this.art,
    this.place,
    this.plate,
    this.boss = false,
  });

  final CombatantArt art;

  /// The habitat window for this creature here, resolved by the card. Null
  /// draws the tinted band alone, exactly as before any plate existed.
  final HabitatPlate? plate;

  /// Whether this creature guards the place: a heavier frame around the
  /// window, so the boss's presence is in the chrome as well as the art.
  final bool boss;

  /// Where the player is standing — the band's tint under the plate. Null
  /// before the game starts, which draws the untinted band rather than
  /// guessing a region.
  final ContentId? place;

  /// The tallest the band is ever drawn, and the height it takes whenever a
  /// habitat plate carries the ground.
  ///
  /// **152, and every creature is drawn at ×2** — because the rule before that
  /// inverted the roster's size ordering, which is the one thing this band
  /// exists to communicate.
  ///
  /// The old rule seated the 56-canvas figures at ×2 in a 120 band and dropped
  /// anything larger to ×1, on the reasoning that a 96 canvas would otherwise
  /// need 200 dp. That reasoning measured the **canvas**, and a combat canvas
  /// is mostly empty. Under it the player saw
  ///
  /// * wolf, ×2 → 58 dp of creature
  /// * **bear, demoted to ×1 → 50 dp** — the largest land animal in the game
  ///   drawn smaller than the wolf
  /// * **guardian, demoted to ×1 → 71 dp** — the boss drawn smaller than the
  ///   salamander's 92
  ///
  /// At ×2 the *content* needs (73 + 4) × 2 at worst, so 152 seats the entire
  /// roster with nothing clipped and in the right order. What it does **not**
  /// do is fit the roster: the wolf's 29 rows of content left 82 dp of empty
  /// rectangle above it, which is the owner's "a small wolf in a giant blank
  /// rectangle" verbatim. Hence [heightFor].
  static const double height = 152;

  /// The floor. Below this the band stops reading as ground and starts reading
  /// as a rule under a picture.
  static const double minHeight = 76;

  /// The band's height for one creature: its own content, doubled, plus 12 dp
  /// of headroom, inside [minHeight]..[height] (`ART-12_ux_brief.md` §7).
  ///
  /// Wolf 76, ram 80, crawler 82, boar 84, goblin 90, salamander 104, bear
  /// 112, guardian 152 — the ordering the 152 band was introduced to protect,
  /// now stated in the band itself rather than only in the figure inside it.
  ///
  /// A plate is the exception: an authored habitat window carries the floor,
  /// so a band with one takes **that plate's own height** whatever stands on
  /// it — 152 dp for a roadside habitat, 192 for a boss chamber. It was a
  /// single 152 constant until EPO03, which is why the Guardian's 146 dp of
  /// creature had six dp of air over its head and read cramped rather than
  /// large (`DIR-12` failure 3).
  static double heightFor(CombatantArt art, {HabitatPlate? plate}) {
    if (plate != null) return plate.displayHeight;
    final double derived = (_contentRows(art.idle) * scale + 12).toDouble();
    return derived.clamp(minHeight, height);
  }

  /// A track's opaque content height, in source rows.
  ///
  /// Measured off the PNGs — `png.bounds` over every frame of each idle track,
  /// the same measurement `Scripts/art/package-art.js` takes for the
  /// footprints — because [CombatTrack] carries the ground row and the contact
  /// span but not the opaque top, and a band derived from the canvas would be
  /// derived from mostly empty space, which is the defect this replaces.
  ///
  /// A track absent from the table falls back to its footprint's own bottom
  /// row, which assumes content all the way to row 0: taller than the truth,
  /// never shorter, so an enemy authored tomorrow is loose in its band rather
  /// than clipped by it.
  static int _contentRows(CombatTrack idle) =>
      _idleContentRows[idle.id] ?? (idle.footprint.bottom + 1);

  /// `top..bottom` inclusive, per idle track, from the union of its frames.
  static const Map<String, int> _idleContentRows = <String, int>{
    'wolf_idle': 29, // 56², rows 12..40
    'lynx_idle': 30, // 56², rows 10..39
    'ram2_idle': 34, // 56², rows 9..42 — the re-horned idle (EPO03)
    'ram_idle': 34, // 56², rows 9..42
    'crawler_idle': 35, // 48², rows 6..40
    'boar_idle': 36, // 56², rows 8..43
    'goblin_idle': 39, // 56², rows 8..46
    'salamander_idle': 46, // 56², rows 5..50
    'bear_idle': 50, // 76², rows 12..61
    'guardian_idle': 73, // 96², rows 11..83
    // The four Veteran Hunt elites (FMPO02 wave 3, FINAL-05 #2). Omitted when
    // the elites shipped, so each fell through to `footprint.bottom + 1` —
    // "taller than the truth, never shorter" — and three of the four reopened
    // the giant-blank-rectangle defect `_EnemyStage` exists to close: Old Grey
    // 41 rows against a true 28, the Foreman 47 against 39, the Matriarch 41
    // against 32. Measured with the same `png.bounds` union pass over the
    // shipped strips that produced every row above.
    'old_grey_idle': 28, // 56², rows 13..40
    'gallery_foreman_idle': 39, // 56², rows 8..46
    'rimeclaw_matriarch_idle': 32, // 56², rows 10..41
    'guardian_awakened_idle': 73, // 96², rows 11..83
  };

  /// The combat stage's own scale, for every creature without exception, so
  /// the thing on the card and the thing in the fight are the same size of
  /// thing. Integer scales only: pixel art never lands between multiples.
  static const int scale = 2;

  /// How far to push a figure down so every creature stands on one ground
  /// line.
  ///
  /// A combat canvas has empty rows *below* the feet as well as above —
  /// `bear_idle` ends at row 61 of 76 — so bottom-aligning the canvas seats
  /// each creature at a different height and the band stops reading as a
  /// floor. The footprint's lowest opaque row is exactly the measurement that
  /// removes it.
  static double groundOffset(CombatTrack idle, {int? scale}) =>
      (idle.canvasHeight - 1 - idle.footprint.bottom) *
      (scale ?? _EnemyStage.scale).toDouble();

  /// The frame around the window, by what stands in it. A boss gets the kit's
  /// heavy `stageFrame` — the same iron the fight itself is framed in — and
  /// everything else the quieter stage well. Both reserve their declared inset
  /// whether or not the raster has landed, so neither reflows later.
  static KitFrame frameFor({required bool boss}) =>
      boss ? KitFrame.stageFrame : KitFrame.insetStage;

  @override
  Widget build(BuildContext context) {
    final ContentId? here = place;
    final HabitatPlate? p = plate;
    final KitFrame frame = frameFor(boss: boss);
    final double window = heightFor(art, plate: p);
    return KitPlate(
      frame: frame,
      width: double.infinity,
      height: window + KitFrames.insetFor(frame) * 2,
      // The region's deep ink rather than one flat `surfaceBlock`
      // everywhere: the band still has to be bright enough for the figure's
      // multiply contact shadow to darken (the finding
      // `gather_node_card.dart` records), and every region deep is, so a
      // window without art still reads as this place's ground.
      fill: here == null
          ? StrideColors.surfaceBlock
          : StrideColors.forRegionDeep(here),
      child: ClipRect(
        // Clipped at the window's own edge: a figure exactly the window's
        // height must not paint over the frame.
        child: Stack(
          children: <Widget>[
            // 1 — THE GROUND, when this region has a habitat authored and
            // switched on. 384 dp of plate in a ~300 dp window, so it is
            // drawn through `PixelScene`, which clips and never rescales —
            // the plate's framing keeps nothing load-bearing at its flanks,
            // exactly as the combat backdrop's does. A plate whose PNG is
            // missing decodes to nothing and leaves the tinted window: no
            // plate, no hole, no crash (`RULES.md` E-5).
            if (p != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PixelScene(
                  assetPath: p.assetPath,
                  nativeWidth: HabitatPlate.nativeWidth,
                  nativeHeight: p.nativeHeight,
                  scale: HabitatPlate.scale,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            // 2 — THE CANOPY, hung from the top edge. Only the cave has one:
            // a stalactite fringe is the one thing a habitat legitimately
            // closes over a creature's head, and it is drawn under the
            // creature because the creature is standing beneath it.
            if (p?.canopyPath case final String canopy)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: PixelScene(
                  assetPath: canopy,
                  nativeWidth: HabitatPlate.nativeWidth,
                  nativeHeight: HabitatPlate.canopyHeight,
                  scale: HabitatPlate.scale,
                  alignment: Alignment.topCenter,
                ),
              ),
            // 3 — THE CREATURE, on the ground line the plate was authored to.
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, groundOffset(art.idle)),
                child: _EnemyIdle(track: art.idle, scale: scale),
              ),
            ),
            // 4 — THE FOREGROUND, **above** the creature. This is the layer
            // that turns a backdrop into a habitat: grass tufts, scree, a
            // drift lip, root loops crossing the creature's feet, so it is
            // *in* the place rather than a cut-out in front of a picture
            // (`DIR-12` failure 4). Transparent, so an absent PNG is simply
            // no foreground.
            if (p?.foregroundPath case final String fg)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PixelScene(
                  assetPath: fg,
                  nativeWidth: HabitatPlate.nativeWidth,
                  nativeHeight: HabitatPlate.foregroundHeight,
                  scale: HabitatPlate.scale,
                  alignment: Alignment.bottomCenter,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The sighting's tier, stamped on the kit's ribbon.
///
/// A field guide records the status of a sighting as a mark, not as a
/// sentence in a pill. The ribbon is `KitMark.ribbonLabel` (89 × 22, landed
/// 2026-09-02) and the word is drawn on Flutter's own fill, exactly as the
/// kit contract requires of it — the raster carries no text and no state.
class TierStamp extends StatelessWidget {
  const TierStamp({super.key, required this.tier});

  final KnowledgeTier tier;

  static String wordFor(KnowledgeTier t) => switch (t) {
    KnowledgeTier.unseen => 'UNSEEN',
    KnowledgeTier.seen => 'SEEN',
    KnowledgeTier.studied => 'STUDIED',
    KnowledgeTier.known => 'KNOWN',
  };

  @override
  Widget build(BuildContext context) {
    final String word = wordFor(tier);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        KitOrnament(
          mark: KitMark.ribbonLabel,
          fallback: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: StrideColors.borderDefault),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Text(
          word,
          style: StrideType.microLabel.copyWith(
            color: tier == KnowledgeTier.known
                ? StrideColors.positiveReady
                : StrideColors.textSecondary,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

/// One creature in its habitat at ×1 — the field guide's row illustration.
///
/// The same three layers the encounter window draws, at half its scale and a
/// third of its width: the plate cropped to the vignette's window, the idle's
/// first frame seated by the same `groundOffset` arithmetic, and the
/// foreground over its feet. It costs **no generations** — every raster it
/// draws is one the encounter card already ships — and it is static: thirteen
/// rows of tickers is the hidden-tab lesson the Bestiary was written to avoid.
///
/// A creature the guide has not sighted is drawn as an **ink silhouette**,
/// which is what "Unseen" looks like in a field guide and what the word alone
/// could only assert.
class HabitatVignette extends StatelessWidget {
  const HabitatVignette({
    super.key,
    required this.art,
    required this.plate,
    this.silhouette = false,
    this.width = 96,
    this.height = 76,
  });

  final CombatantArt art;
  final HabitatPlate? plate;

  /// Draw the creature as flat ink: not yet sighted.
  final bool silhouette;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final HabitatPlate? p = plate;
    final CombatTrack idle = art.idle;
    Widget figure = GroundedSprite(
      assetPath: idle.frame(0),
      footprint: idle.footprint,
      scale: 1,
      canvas: idle.canvasWidth,
      canvasHeight: idle.canvasHeight,
    );
    if (silhouette) {
      figure = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          StrideColors.textMuted,
          BlendMode.srcATop,
        ),
        child: figure,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StrideColors.surfaceBlock,
          border: Border.all(color: StrideColors.borderDefault),
        ),
        child: ClipRect(
          child: Stack(
            children: <Widget>[
              if (p != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PixelScene(
                    assetPath: p.assetPath,
                    nativeWidth: HabitatPlate.nativeWidth,
                    nativeHeight: p.nativeHeight,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, _EnemyStage.groundOffset(idle, scale: 1)),
                  child: figure,
                ),
              ),
              if (p?.foregroundPath case final String fg)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PixelScene(
                    assetPath: fg,
                    nativeWidth: HabitatPlate.nativeWidth,
                    nativeHeight: HabitatPlate.foregroundHeight,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The enemy's idle track, played as a bounded visit.
///
/// One `AnimationController`, no `Timer`, no clock read — `CombatStage`'s
/// idle machine at its smallest. The track loops for [_visit] after mount and
/// after every return to the app, then holds its first frame; `TickerMode`
/// mutes it, the lifecycle stops it, and reduced motion holds the first frame
/// throughout (`MediaQuery.disableAnimationsOf`, the convention
/// `AmbientPlayer` set). Bounded is also what lets every widget test
/// `pumpAndSettle`.
class _EnemyIdle extends StatefulWidget {
  const _EnemyIdle({required this.track, required this.scale});

  final CombatTrack track;
  final int scale;

  @override
  State<_EnemyIdle> createState() => _EnemyIdleState();
}

class _EnemyIdleState extends State<_EnemyIdle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// How long the idle loops before holding its first frame. Shorter than the
  /// combat stage's eight seconds: this is a card among cards, not the fight.
  static const Duration _visit = Duration(seconds: 6);

  /// Built in `initState`, not lazily: under reduced motion nothing ever
  /// reads a lazy controller, so its initialiser would run from `dispose` —
  /// an ancestor lookup on a deactivated element (`AmbientPlayer`'s finding).
  late final AnimationController _controller;

  int _frame = 0;
  bool _started = false;
  bool _reduceMotion = false;
  bool _heldByLifecycle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _visit)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _reduceMotion = reduce;
      for (final String frame in widget.track.track.frames) {
        precacheImage(AssetImage(frame), context);
      }
      // Started here rather than in `initState`, so the first decision
      // already knows whether the platform asked for reduced motion.
      if (!reduce) _begin();
      return;
    }
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _controller.stop();
      _hold();
    } else {
      _begin();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_reduceMotion) {
        _heldByLifecycle = false;
        return;
      }
      if (_heldByLifecycle) {
        _heldByLifecycle = false;
        _controller.forward();
      } else if (!_controller.isAnimating) {
        // Coming back to the app is what a visit is.
        _begin();
      }
      return;
    }
    if (_controller.isAnimating) {
      _heldByLifecycle = true;
      _controller.stop();
    }
  }

  void _begin() {
    _heldByLifecycle = false;
    _controller.forward(from: 0);
  }

  /// The visit is spent: the first frame, and nothing scheduled.
  void _hold() {
    if (_frame == 0) return;
    setState(() => _frame = 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _hold();
  }

  void _onTick() {
    final CombatTrack t = widget.track;
    final int passUs = t.duration.inMicroseconds;
    if (passUs <= 0) return;
    final Duration elapsed = _visit * _controller.value;
    // A modulo over the track's own pass, so the loop never freezes on the
    // pass's last slot mid-visit.
    final int next = t.frameAt(
      Duration(microseconds: elapsed.inMicroseconds % passUs),
    );
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CombatTrack t = widget.track;
    return GroundedSprite(
      assetPath: t.frame(_frame),
      footprint: t.footprint,
      scale: widget.scale,
      canvas: t.canvasWidth,
      canvasHeight: t.canvasHeight,
    );
  }
}
