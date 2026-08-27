/// The Craft screen — categories, a compact recipe list, one selected
/// recipe's working surface, and a timed craft flow
/// (PRESENTATION_WORLD_REWARD_FEEL_01 §14–§19, §47).
///
/// ## The rule this screen keeps
///
/// **A disabled recipe must say why it is disabled.** Every recipe in the
/// content pack is listed, not only the craftable ones — a locked recipe is a
/// destination. What changed is density: the old screen drew every recipe as
/// a full-height card ("functional prototype cards full of text"); rows are
/// now compact and only the selected recipe expands.
///
/// ## Crafting costs no steps — still
///
/// `GAME_BIBLE/SYSTEMS/04`: the steps were already spent gathering. The new
/// timed flow is **presentation pacing over the same instant command**
/// (`craft_controller.dart`): each completed repetition is one ordinary
/// engine-validated `CraftItem`, exact ingredients out, exact output in,
/// exactly once. This remains the one screen whose primary action works at a
/// zero balance.
///
/// No figure here is computed from a `RecipeDefinition`. `RecipeOption`
/// carries profile-scaled values from `StrideSession`, and the engine
/// re-validates everything on dispatch (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, ItemCategory;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/gear_stats.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/surfaces.dart';
import '../../icons/ambient_assets.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/sprite_footprints.dart';
import '../../components/ambient_stage.dart';
import '../../state/audio_scope.dart';
import '../../state/craft_controller.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/rarity_style.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

/// The craft stage's height: the location stage's own 176, because since
/// the physical-device polish pass (item 2) the stage carries a full work
/// backdrop — the forge interior, the bench room, the hearth — and the
/// 384 × 176 scene family sets the band. The figures' box inside it stays
/// the shared 140 (`LocationStage._stageHeight`'s reasoning).
const double _craftStageHeight = 176;

/// The figures' box: the 64-row sprite plus shadow bleed at ×2 — the same
/// interior the location stage reserves.
const double _craftFiguresHeight = 140;

/// The §19 categories, derived from the output item's authored data.
enum CraftCategory {
  materials('Materials'),
  food('Food'),
  gear('Gear'),
  tools('Tools');

  const CraftCategory(this.label);
  final String label;

  static CraftCategory of(RecipeOption recipe) {
    if (recipe.outputIsTool) return CraftCategory.tools;
    return switch (recipe.outputCategory) {
      ItemCategory.equipment => CraftCategory.gear,
      ItemCategory.consumable => CraftCategory.food,
      _ => CraftCategory.materials,
    };
  }
}

class CraftScreen extends StatefulWidget {
  const CraftScreen({super.key});

  @override
  State<CraftScreen> createState() => _CraftScreenState();
}

class _CraftScreenState extends State<CraftScreen> {
  /// The category filter. Null shows everything.
  CraftCategory? _category;

  /// The selected recipe — ephemeral UI selection (`RULES.md` E-2).
  ContentId? _selected;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final CraftController craft = CraftScope.of(context);
    final StrideSession session = controller.session;
    final List<RecipeOption> recipes = session.recipeOptions;

    // A running queue, or a finished one whose MEDIUM result is still held,
    // pins the selection to its recipe, so the working surface never
    // disappears under the player mid-craft. A MINOR result does **not**
    // pin (the correction pass): it is transient — on its timer, and gone
    // the moment the player opens another recipe — so a "CRAFTED · Bronze
    // Ingot" block can never sit in the way of the next job.
    final ContentId? pinned =
        craft.activeRecipe ?? (craft.summaryHeld ? craft.summaryRecipe : null);
    final ContentId? selectedId = pinned ?? _selected;

    final List<RecipeOption> shown = _category == null
        ? recipes
        : recipes
              .where((RecipeOption r) => CraftCategory.of(r) == _category)
              .toList();
    final int ready = shown.where((RecipeOption r) => r.canCraft).length;

    // A held summary — finished equipment, or a level gained — rises over
    // the screen in the reward layer (PLAYABLE_POLISH_01 §4) and is what
    // Continue acknowledges; the recipe detail beneath shows nothing of it.
    final RecipeOption? pinnedRecipe = pinned == null
        ? null
        : recipes.cast<RecipeOption?>().firstWhere(
            (RecipeOption? r) => r!.id == pinned,
            orElse: () => null,
          );
    final bool held = craft.summaryHeld && pinnedRecipe != null;

    return RewardRaise(
      token: held ? craft.lastReport : null,
      tier: RewardTier.medium,
      accent: held ? _CraftSummary.heldAccent(craft, pinnedRecipe) : null,
      beats: held ? _CraftSummary.heldBeats(context, craft, pinnedRecipe) : const <Widget>[],
      trailing: held ? _CraftSummary.equipControl(context, craft, pinnedRecipe) : null,
      onDismiss: CraftScope.read(context).dismissSummary,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (session.isStale) ...<Widget>[
          StaleBanner(busy: controller.busy, onReload: controller.reload),
          const SizedBox(height: StrideSpace.cardGap),
        ],

        // The filter, then the honest census of what it shows.
        //
        // Two figures in one shape, whatever the numbers are. The line read
        // "Nothing here can be made yet — 15 known" at zero and "5 of 15 can
        // be made now" otherwise: two different sentences, two different
        // lengths, and the empty case phrased as an apology. The owner asked
        // for the compact state instead (§8), and the same words at zero as
        // at five is also the honest presentation — nothing craftable is a
        // fact about the bag, not a disappointment to soften.
        _CategoryChips(
          selected: _category,
          onSelect: (CraftCategory? c) => setState(() => _category = c),
        ),
        const SizedBox(height: StrideSpace.s8),
        AdaptiveText(
          '$ready craftable · ${shown.length} known',
          style: StrideType.sub,
          color: ready == 0
              ? StrideColors.textMuted
              : StrideColors.textSecondary,
        ),
        const SizedBox(height: StrideSpace.cardGap),

        if (shown.isEmpty)
          const SectionCard(
            child: AdaptiveText(
              'Nothing in this category yet.',
              style: StrideType.body,
            ),
          ),

        for (final RecipeOption recipe in shown) ...<Widget>[
          _RecipeRow(
            recipe: recipe,
            selected: selectedId == recipe.id,
            onTap: () {
              // Opening or closing any row clears a transient result; a
              // held one has its own Continue.
              if (!craft.active && !craft.summaryHeld) {
                CraftScope.read(context).dismissSummary();
              }
              setState(
                () => _selected = _selected == recipe.id ? null : recipe.id,
              );
            },
          ),
          if (selectedId == recipe.id) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            _RecipeDetail(recipe: recipe),
          ],
          const SizedBox(height: StrideSpace.s6),
        ],
      ],
      ),
    );
  }
}

/// The filter chips: All plus the four categories.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelect});

  final CraftCategory? selected;
  final ValueChanged<CraftCategory?> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: StrideSpace.s6,
    runSpacing: StrideSpace.s4,
    children: <Widget>[
      _Chip(
        label: 'All',
        selected: selected == null,
        onTap: () => onSelect(null),
      ),
      for (final CraftCategory c in CraftCategory.values)
        _Chip(
          label: c.label,
          selected: selected == c,
          onTap: () => onSelect(c),
        ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: StrideSpace.s10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: selected
              ? StrideColors.surfaceRaised
              : StrideColors.surfaceBlock,
          border: Border.all(
            color: selected
                ? StrideColors.accentSteps
                : StrideColors.borderDefault,
          ),
          borderRadius: StrideRadius.chip,
        ),
        child: Text(
          label,
          style: StrideType.compactLabel.copyWith(
            color: selected
                ? StrideColors.textPrimary
                : StrideColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

/// One compact recipe row: the output's icon, its name in rarity ink, the
/// skill line, and the state at a glance.
class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.recipe,
    required this.selected,
    required this.onTap,
  });

  final RecipeOption recipe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String state = recipe.isLocked
        ? 'LOCKED'
        : !recipe.skillMet
        ? 'LV ${recipe.requiredLevel}'
        : recipe.canCraft
        ? '×${recipe.craftableCount}'
        : '—';
    final bool dim = !recipe.canCraft;

    return Semantics(
      button: true,
      selected: selected,
      label: recipe.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? StrideColors.surfaceRaised
                : StrideColors.surfaceCard,
            border: Border.all(
              color: selected
                  ? StrideColors.accentSteps
                  : StrideColors.borderDefault,
            ),
            borderRadius: StrideRadius.inner,
          ),
          child: Row(
            children: <Widget>[
              InsetWell.square(
                contentSize: 48,
                child: PixelAsset.item(PixelIcons.itemFor(recipe.outputItem)),
              ),
              const SizedBox(width: StrideSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Rarity ink always — the rank is the item's identity
                    // (§20), not its availability; the sub-line carries the
                    // dimming.
                    RarityName(
                      name: recipe.displayName,
                      rarity: recipe.outputRarity,
                      style: StrideType.itemName,
                    ),
                    Text(
                      '${recipe.skillName} ${recipe.requiredLevel} · '
                      '+${recipe.experience} XP',
                      style: StrideType.micro.copyWith(
                        color: dim
                            ? StrideColors.textMuted
                            : StrideColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Text(
                state,
                style: StrideType.microLabel.copyWith(
                  color: recipe.canCraft
                      ? StrideColors.accentSteps
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

/// The selected recipe's working surface: ingredients, the reason it cannot
/// be made when it cannot, the queue, the craft flow, and the Pursuit hook.
class _RecipeDetail extends StatefulWidget {
  const _RecipeDetail({required this.recipe});

  final RecipeOption recipe;

  @override
  State<_RecipeDetail> createState() => _RecipeDetailState();
}

class _RecipeDetailState extends State<_RecipeDetail> {
  int _requested = 1;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final CraftController craft = CraftScope.of(context);
    final RecipeOption recipe = widget.recipe;

    final bool activeHere = craft.active && craft.activeRecipe == recipe.id;
    final bool activeElsewhere = craft.active && !activeHere;
    final bool summaryHere =
        !craft.active && craft.summaryRecipe == recipe.id;

    final int maxCount = recipe.craftableCount.clamp(
      0,
      CraftController.maxQueue,
    );
    final int count = _requested.clamp(1, maxCount > 0 ? maxCount : 1);

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (recipe.outputRarity != null) ...<Widget>[
            RarityBadge(rarity: recipe.outputRarity),
            const SizedBox(height: StrideSpace.s6),
          ],
          if (recipe.outputQuantity != 1 ||
              recipe.outputName != recipe.displayName) ...<Widget>[
            AdaptiveText(
              recipe.outputQuantity == 1
                  ? 'Makes ${recipe.outputName}'
                  : 'Makes ${recipe.outputQuantity} × ${recipe.outputName}',
              style: StrideType.sub,
              color: StrideColors.textSecondary,
            ),
            const SizedBox(height: StrideSpace.s6),
          ],

          // Equipment says what it is worth before the materials are
          // counted (PLAYABLE_POLISH_01 §6): the stat, the worn piece, the
          // verdict, the passives — from the same projection the Inventory
          // tile reads, so the bench and the bag agree.
          if (controller.session.gearStatsOf(recipe.outputItem)
              case final GearStats g) ...<Widget>[
            GearStatsBlock(stats: g),
            const SizedBox(height: StrideSpace.s8),
          ]
          // A material recipe's why-chain used to stop one hop short: the
          // bench said what a plank costs and never what a plank is *for*.
          // One sentence closes it, from the same projection the bag's
          // detail reads (Fable V2, `DECISIONS/0027`).
          else if (controller.session.itemPurposeOf(recipe.outputItem)
              case final ItemPurposeView purpose) ...<Widget>[
            if (purpose.usedInRecipes.isNotEmpty ||
                purpose.wantedBy.isNotEmpty) ...<Widget>[
              Text(
                <String>[
                  if (purpose.usedInRecipes.isNotEmpty)
                    'Makes possible: ${purpose.usedInRecipes.join(', ')}',
                  // Capped: a staple like broth is wanted half the world
                  // over, and eight lines of admirers is card overload.
                  // Two names carry the point; the count says the rest.
                  if (purpose.wantedBy.isNotEmpty)
                    'Wanted by: ${purpose.wantedBy.take(2).join(' · ')}'
                        '${purpose.wantedBy.length > 2 ? ' · +${purpose.wantedBy.length - 2} more' : ''}',
                ].join('\n'),
                style: StrideType.micro.copyWith(
                  color: StrideColors.textSecondary,
                ),
              ),
              const SizedBox(height: StrideSpace.s8),
            ],
          ],

          // Held over required, always both — how close the player is and
          // whether they have any at all, in one line per material.
          for (final RecipeIngredientLine line in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: StrideSpace.s4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AdaptiveText(
                      line.displayName,
                      style: StrideType.sub,
                      color: line.satisfied
                          ? StrideColors.textSecondary
                          : StrideColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: StrideSpace.s8),
                  AdaptiveText(
                    '${line.held} / ${line.required}',
                    style: StrideType.itemCount,
                    color: line.satisfied
                        ? StrideColors.textPrimary
                        : StrideColors.textMuted,
                  ),
                ],
              ),
            ),

          const SizedBox(height: StrideSpace.s8),
          if (activeHere)
            _ActiveCraftPanel(recipe: recipe)
          else ...<Widget>[
            if (recipe.canCraft && maxCount > 1) ...<Widget>[
              _QueueChips(
                count: count,
                maxCount: maxCount,
                onChanged: (int v) => setState(() => _requested = v),
              ),
              const SizedBox(height: StrideSpace.s8),
            ],
            StrideButton(
              label: controller.busy || activeElsewhere
                  ? 'Crafting…'
                  : count > 1
                  ? 'Craft ×$count'
                  : 'Craft',
              subLabel: activeElsewhere
                  ? 'Finish or cancel your current craft'
                  : _reason(recipe),
              onPressed:
                  !recipe.canCraft || controller.busy || activeElsewhere ||
                      !controller.session.isReady
                  ? null
                  : () => CraftScope.read(context).start(recipe, count),
            ),
            const SizedBox(height: StrideSpace.s6),
            // The Pursuit hook (`DECISIONS/0023` §1): any recipe's output can
            // be tracked, and a locked or distant one is exactly the kind
            // worth tracking. Reserves nothing.
            StrideButton.secondary(
              label: 'Track as Pursuit',
              onPressed: controller.busy
                  ? null
                  : () => SessionScope.read(context)
                        .trackGoalPursuit(recipe.outputItem),
            ),
            if (summaryHere) ...<Widget>[
              const SizedBox(height: StrideSpace.s8),
              _CraftSummary(craft: craft, recipe: recipe),
            ],
          ],
        ],
      ),
    );
  }

  /// The one sentence that explains a disabled button — lock before skill,
  /// skill before ingredients, the engine's own refusal order.
  static String? _reason(RecipeOption recipe) {
    if (recipe.lockReason case final String locked) return locked;
    if (!recipe.skillMet) {
      return 'Needs ${recipe.skillName} ${recipe.requiredLevel} — you are '
          '${recipe.currentLevel}';
    }
    final List<RecipeIngredientLine> short = recipe.ingredients
        .where((RecipeIngredientLine i) => !i.satisfied)
        .toList();
    if (short.isEmpty) return null;
    return 'Needs ${short.map((RecipeIngredientLine i) => '${i.shortfall} more ${i.displayName}').join(', ')}';
  }
}

/// ×1 / ×5 / ×10, clamped to what the held ingredients fund.
class _QueueChips extends StatelessWidget {
  const _QueueChips({
    required this.count,
    required this.maxCount,
    required this.onChanged,
  });

  final int count;
  final int maxCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: StrideSpace.s6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      for (final int preset in const <int>[1, 5, 10])
        _Chip(
          label: '×$preset',
          selected: count == preset ||
              (preset > maxCount && count == maxCount && preset == 10),
          onTap: () => onChanged(preset),
        ),
      Text(
        'up to ×$maxCount',
        style: StrideType.micro.copyWith(color: StrideColors.textMuted),
      ),
    ],
  );
}

/// The running craft: the station stage (when the profession's working loop
/// exists), the progress bar, the count, and Cancel.
class _ActiveCraftPanel extends StatelessWidget {
  const _ActiveCraftPanel({required this.recipe});

  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) {
    final CraftController craft = CraftScope.of(context);
    final String skill = recipe.skill.value;
    final List<String>? loop = AmbientAssets.hasActivityLoop(skill)
        ? AmbientAssets.activityLoopFor(skill)
        : null;
    // The scene follows the recipe's authored workstation, with the skill
    // as fallback — an oak plank is bench work even though Smithing owns it
    // (`RecipeDefinition.station`, this pass, item 2).
    final String station = AmbientAssets.craftStationKind(
      recipe.station?.name,
      skill,
    );
    final String? backdrop = AmbientAssets.craftBackdropFor(station);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The craft stage — the Traveler working AT this recipe's station,
        // IN the station's own scene (PRESENTATION_WORLD_REWARD_FEEL_01
        // §17; the backdrop and the scene scale are the physical-device
        // polish pass, item 2 — the tiny forge-in-a-box read as
        // underwhelming on the phone).
        //
        // The station goes in the stage's **prop** slot, not its scenery
        // slot, and the difference is a blind-QA finding rather than a
        // preference: scenery is far-left and raised, which is right for
        // "this figure, at this place" and wrong for "this figure, working
        // on this thing". Composited that way the Traveler swung a hammer at
        // empty air with the anvil a screen away.
        //
        // The composition is the location stage's WORK mode: the 384 × 176
        // backdrop clipped and centred at ×1 (the combat stage's clipping
        // rule — a narrower card sees less of the flanks, never a shifted
        // scene), a quiet ground gradient so the contact shadows have a
        // floor, and the figures bottom-anchored on it.
        if (loop != null) ...<Widget>[
          SizedBox(
            height: _craftStageHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StrideColors.surfaceBlock,
                border: Border.all(color: StrideColors.borderDefault),
                borderRadius: StrideRadius.inner,
              ),
              child: ClipRRect(
                borderRadius: StrideRadius.inner,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (backdrop != null)
                      PixelScene.vignette(
                        backdrop,
                        viewportHeight: _craftStageHeight,
                      ),
                    // The figures' ground band (`LocationStage`'s): the
                    // multiply contact shadow needs something to darken.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x0014120F),
                              Color(0x8014120F),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 6,
                      height: _craftFiguresHeight,
                      child: AmbientStage(
                        gatherFrames: PixelIcons.gatherFrames,
                        gatherFootprint: SpriteFootprints.gather,
                        playToken: null,
                        scenes: AmbientAssets.scenes,
                        restFrame: AmbientAssets.restFrame,
                        restFootprint: AmbientAssets.restFootprint,
                        prop: AmbientAssets.stationFor(station),
                        activityFrames: loop,
                        activityFootprint:
                            AmbientAssets.activityFootprintFor(skill),
                        activityCanvas: AmbientAssets.activityCanvasFor(skill),
                        activityActive: true,
                        // The craft beats (AUDIO_PRESENTATION_01): the hammer
                        // lands, the stir turns — the one accepted cue per
                        // profession, on the visible strike frame, only while
                        // this stage is mounted. Leaving the screen stops the
                        // sound; the craft queue itself never sonifies.
                        activityStrikeFrame:
                            AmbientAssets.strikeFrameFor(skill),
                        onActivityBeat: () =>
                            AudioScope.read(context).playSkillCue(skill),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: StrideSpace.s8),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Crafting ${craft.completed} / ${craft.queued}',
                style: StrideType.sub.copyWith(
                  color: StrideColors.textPrimary,
                ),
              ),
            ),
            _CraftSecondsRemaining(craft: craft),
          ],
        ),
        const SizedBox(height: StrideSpace.s6),
        CraftRepetitionBar(craft: craft, skill: recipe.skill),
        if (craft.completed > 0) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${craft.outputName ?? recipe.outputName} made: '
                  '${craft.quantity}',
                  style: StrideType.micro.copyWith(
                    color: StrideColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '+${craft.xp} ${craft.skillName ?? recipe.skillName} XP',
                style: StrideType.micro.copyWith(
                  color: StrideColors.forSkill(recipe.skill),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: StrideSpace.s8),
        StrideButton(
          label: 'Cancel',
          onPressed: () => CraftScope.read(context).stop(),
        ),
      ],
    );
  }
}

class _CraftSecondsRemaining extends StatelessWidget {
  const _CraftSecondsRemaining({required this.craft});

  final CraftController craft;

  @override
  Widget build(BuildContext context) {
    final int seconds =
        (craft.repetitionDuration - craft.elapsedOfCurrent).inSeconds;
    return Text(
      '${seconds < 0 ? 0 : seconds}s',
      style: StrideType.micro.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The craft flow's smooth per-repetition bar — the same widget-side ticker
/// pattern as the gather queue's `RepetitionBar`, over the craft controller.
class CraftRepetitionBar extends StatefulWidget {
  const CraftRepetitionBar({
    super.key,
    required this.craft,
    required this.skill,
  });

  final CraftController craft;
  final ContentId skill;

  @override
  State<CraftRepetitionBar> createState() => _CraftRepetitionBarState();
}

class _CraftRepetitionBarState extends State<CraftRepetitionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.craft.repetitionDuration,
  );

  @override
  void initState() {
    super.initState();
    widget.craft.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final CraftController c = widget.craft;
    if (!c.active) {
      _fill.stop();
      return;
    }
    final Duration total = c.repetitionDuration;
    final Duration elapsed = c.elapsedOfCurrent;
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
    widget.craft.removeListener(_sync);
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

/// The finished queue's feedback, as a beat (PLAYABLE_EXPERIENCE_REFINEMENT_01
/// §12–§13, §29, §32).
///
/// The device review found the result embedded in the recipe card — `Oak
/// Plank ×1 · +12 Smithing XP / SMITHING LEVEL 4 / Frost-lined Jerkin · Pine
/// Plank unlocked.` — reading as diagnostic output the card had kept. It is
/// now a deliberate completion beat in the one reward language
/// (`reward_beat.dart`): MINOR for a component or a meal, MEDIUM for finished
/// equipment, and the universal [LevelUpCard] beneath either when a level
/// landed. MINOR resolves on the controller's timer; MEDIUM and a level-up
/// are held until acknowledged, then the card returns to the clean detail.
class _CraftSummary extends StatelessWidget {
  const _CraftSummary({required this.craft, required this.recipe});

  final CraftController craft;
  final RecipeOption recipe;

  @override
  Widget build(BuildContext context) {
    final CraftReport? refusal = craft.stopReport;

    if (craft.quantity == 0 && refusal != null) {
      return SurfaceBlock(
        child: AdaptiveText(
          _refusalText(refusal),
          style: StrideType.sub,
          color: StrideColors.textSecondary,
        ),
      );
    }
    if (craft.quantity == 0) return const SizedBox.shrink();

    // A held summary is the reward layer's (PLAYABLE_POLISH_01 §4); the
    // card beneath the scrim shows nothing of it, so the result is read
    // exactly once, in one place.
    if (craft.summaryHeld) return const SizedBox.shrink();

    final String skillName = craft.skillName ?? recipe.skillName;
    final String xpLine = '+${craft.xp} $skillName XP';

    // MINOR — components and food: the brief, truthful beat, on the timer.
    return StaggeredReveal(
      children: <Widget>[
        RewardBeat(
          tier: RewardTier.minor,
          eyebrow: 'CRAFTED',
          title: '${craft.outputName ?? recipe.outputName} ×${craft.quantity}',
          lines: <String>[
            xpLine,
            if (refusal != null) 'Stopped: ${_refusalText(refusal)}',
          ],
        ),
      ],
    );
  }

  /// The layer's frame: the item's rarity for finished equipment, the
  /// skill's hue for a level gained on a component run.
  static Color heldAccent(CraftController craft, RecipeOption recipe) =>
      craft.lastReport?.equipDelta != null
      ? (RarityStyle.maybe(recipe.outputRarity)?.accent ??
            StrideColors.forSkill(recipe.skill))
      : StrideColors.forSkill(recipe.skill);

  /// The beats a held craft summary raises: MEDIUM for finished equipment
  /// — the name in its rarity, the stat story against what is worn — or the
  /// MINOR crafted line when only the level-up made it held, and the
  /// universal [LevelUpCard] beneath when a level landed.
  static List<Widget> heldBeats(
    BuildContext context,
    CraftController craft,
    RecipeOption recipe,
  ) {
    final CraftReport? last = craft.lastReport;
    final EquipDelta? delta = last?.equipDelta;
    final String skillName = craft.skillName ?? recipe.skillName;
    final String xpLine = '+${craft.xp} $skillName XP';
    return <Widget>[
      if (delta != null && last != null)
        RewardBeat(
          tier: RewardTier.medium,
          eyebrow: 'CRAFTED',
          title: last.outputName ?? recipe.outputName,
          rarity: recipe.outputRarity,
          lines: <String>[
            // A tool says what it is and what it would replace; a weapon or
            // armour says the stat delta. No "Tool power 4 → 4".
            if (delta.isTool) ...<String>[
              delta.toolLine!,
              if (delta.replaces case final String r)
                delta.swapsProfession ? 'Swaps out $r' : 'Replaces $r',
            ] else
              '${delta.statName}  ${delta.before} → ${delta.after}',
            xpLine,
          ],
        )
      else
        RewardBeat(
          tier: RewardTier.minor,
          eyebrow: 'CRAFTED',
          title: '${craft.outputName ?? recipe.outputName} ×${craft.quantity}',
          lines: <String>[xpLine],
        ),
      if (last != null && last.levelledUp)
        LevelUpCard(
          name: last.skillName ?? skillName,
          level: last.skillLevelAfter ?? 0,
          skill: recipe.skill,
          unlocked: last.unlockedNames,
          why: last.unlockedNames.isEmpty
              ? null
              : 'New work is ready at the bench',
        ),
    ];
  }

  /// Equip, beside Continue, for finished equipment only. Dispatches the
  /// unchanged equip command; the layer stays up until Continue, so the
  /// player can equip and then read the rest.
  static Widget? equipControl(
    BuildContext context,
    CraftController craft,
    RecipeOption recipe,
  ) {
    if (craft.lastReport?.equipDelta == null) return null;
    return StrideButton.secondary(
      label: 'Equip',
      onPressed: () => SessionScope.read(context).equip(recipe.outputItem),
    );
  }

  static String _refusalText(CraftReport report) => switch (report.rejection) {
    'insufficient_ingredients' => 'Not enough materials.',
    'skill_level_too_low' => 'Your skill is not high enough yet.',
    'recipe_locked' => 'This recipe has not been learned yet.',
    'unknown_recipe' => 'That recipe is not in this content pack.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before crafting again.',
    _ => 'That could not be crafted.',
  };
}
