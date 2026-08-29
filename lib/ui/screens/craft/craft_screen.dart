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
import 'package:stride_core/stride_core.dart'
    show ContentId, ItemCategory, Rarity;

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
import '../../components/activity_result.dart';
import '../../state/audio_scope.dart';
import '../../state/craft_controller.dart';
import '../../state/craft_significance.dart';
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

  /// The chain-jump breadcrumb (Fable V2 Iteration 03): tapping a short
  /// crafted ingredient jumps the selection to the recipe that makes it,
  /// and this remembers the way back. Depth in shipped content is ≤2
  /// (ore → ingot → sword), so one visible chip covers reality; any
  /// manual row tap clears it. Ephemeral presentation only.
  final List<ContentId> _chainStack = <ContentId>[];

  /// Jumps the bench to [recipe]'s row, remembering [from]. Clears the
  /// category filter — an ingot is Materials while the sword is Gear, and
  /// jumping inside a filtered list would land on a row that is not there.
  void _jumpTo(ContentId recipe, {required ContentId from}) {
    setState(() {
      _chainStack.add(from);
      _category = null;
      _selected = recipe;
    });
    _revealRow(recipe);
  }

  void _jumpBack() {
    if (_chainStack.isEmpty) return;
    final ContentId back = _chainStack.removeLast();
    setState(() => _selected = back);
    _revealRow(back);
  }

  /// The list's own controller, so a chain jump can reach a row the lazy
  /// list has not built yet.
  final ScrollController _list = ScrollController();

  /// One global key, on the SELECTED row only. A key on every lazy-list
  /// row caused viewport offset-correction storms ("exceeded its maximum
  /// number of layout cycles") as keyed children crossed the build range;
  /// the reveal only ever needs to find the row the jump selected.
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  /// Scrolls the jumped-to row into view. The list is lazy, so an
  /// off-screen row has no context yet: sweep a viewport-page at a time —
  /// upward first (an ingredient is more basic than its consumer, so its
  /// band sits higher), then downward — until the row builds, then settle
  /// it near the top. Bounded, instant page hops, one eased final settle
  /// (Duration.zero under Reduce Motion).
  Future<void> _revealRow(ContentId recipe) async {
    final GlobalKey key = _selectedRowKey;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    for (int attempt = 0; attempt < 14; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final BuildContext? target = key.currentContext;
      if (target != null) {
        if (!target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          alignment: 0.15,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!_list.hasClients) return;
      final ScrollPosition pos = _list.position;
      final double page = pos.viewportDimension;
      final double next = (attempt < 7 ? pos.pixels - page : pos.pixels + page)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (next != pos.pixels) _list.jumpTo(next);
    }
  }

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

    // The universal activity result (GFCP01 device correction): "nothing
    // happened after crafting" was the device verdict on the in-row beat —
    // a small text block inside whichever recipe was expanded, easy to
    // miss entirely. Every completion now lands a floating card at the
    // screen's foot: the running queue's committed totals update it in
    // place per boundary, and a finished MINOR summary stands on it until
    // read (the card's clock pauses while this tab is hidden, so a queue
    // that ends elsewhere waits with its summary). Held MEDIUM/MAJOR
    // results keep the reward layer; the card then shows nothing.
    ActivityResult? craftResult;
    Object? craftToken;
    if (!craft.summaryHeld && craft.quantity > 0) {
      final ContentId? outputId = craft.lastReport?.outputItemId;
      final Rarity? rarity = craft.lastReport?.outputRarity;
      craftResult = ActivityResult(
        verb: craft.active || craft.completed <= 1
            ? 'CRAFTED'
            : 'CRAFTING COMPLETE',
        itemId: outputId,
        itemName: craft.outputName ?? 'Items',
        quantity: craft.quantity,
        skillName: craft.skillName,
        xp: craft.xp,
        rarity: rarity,
      );
      craftToken =
          'craft:${craft.active}:${craft.activeRecipe?.value ?? craft.summaryRecipe?.value}'
          ':${craft.completed}:${craft.quantity}';
    }

    return RewardRaise(
      token: held ? craft.lastReport : null,
      // The layer's weight is the derived significance's call
      // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1): an Epic or better
      // output takes the MAJOR frame and its heavier haptic; everything
      // else held is MEDIUM. Never per-item.
      tier: craft.significance == CraftSignificance.major
          ? RewardTier.major
          : RewardTier.medium,
      accent: held ? _CraftSummary.heldAccent(craft, pinnedRecipe) : null,
      announcement: held ? 'Crafted ${pinnedRecipe.outputName}' : null,
      beats: held
          ? _CraftSummary.heldBeats(context, craft, pinnedRecipe)
          : const <Widget>[],
      trailing: held
          ? _CraftSummary.equipControl(context, craft, pinnedRecipe)
          : null,
      onDismiss: CraftScope.read(context).dismissSummary,
      child: ActivityResultHost(
        result: craftResult,
        resultToken: craftToken,
        // A finished summary's card, once read, acknowledges the
        // controller's summary; a mid-run card expiring acknowledges
        // nothing (dismissSummary is a no-op while the queue runs).
        onExpired: CraftScope.read(context).dismissSummary,
        child: ListView(
        controller: _list,
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

          // The planner's readiness bands (Fable V2 Iteration 03): the one
          // list, sectioned by the projection's own classification —
          // widgets never decide "one away", or the header counts and the
          // census line would drift apart (E-2). Empty bands are skipped
          // entirely; the census line above already covers the zero case.
          for (final (String label, List<RecipeOption> band) in _bands(
            shown,
          )) ...<Widget>[
            if (band.isNotEmpty) ...<Widget>[
              SectionHeading(
                label: label,
                trailing: Text(
                  '${band.length}',
                  style: StrideType.microLabel.copyWith(
                    color: StrideColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: StrideSpace.s6),
              for (final RecipeOption recipe in band) ...<Widget>[
                KeyedSubtree(
                  key: selectedId == recipe.id ? _selectedRowKey : null,
                  child: _RecipeRow(
                    recipe: recipe,
                    selected: selectedId == recipe.id,
                    onTap: () {
                      // Opening or closing any row clears a transient result;
                      // a held one has its own Continue. A manual tap also
                      // clears the chain breadcrumb — the player has walked
                      // their own way.
                      if (!craft.active && !craft.summaryHeld) {
                        CraftScope.read(context).dismissSummary();
                      }
                      setState(() {
                        _chainStack.clear();
                        _selected = _selected == recipe.id ? null : recipe.id;
                      });
                    },
                  ),
                ),
                if (selectedId == recipe.id) ...<Widget>[
                  const SizedBox(height: StrideSpace.s4),
                  if (_chainStack.isNotEmpty)
                    _ChainBackChip(
                      target: recipes.cast<RecipeOption?>().firstWhere(
                        (RecipeOption? r) => r!.id == _chainStack.last,
                        orElse: () => null,
                      ),
                      onTap: _jumpBack,
                    ),
                  _RecipeDetail(
                    recipe: recipe,
                    // The chain link: disabled while a craft pins the
                    // selection — the pin already wins and must keep
                    // winning.
                    onOpenIngredientRecipe: craft.active
                        ? null
                        : (ContentId target) =>
                              _jumpTo(target, from: recipe.id),
                  ),
                ],
                const SizedBox(height: StrideSpace.s6),
              ],
              const SizedBox(height: StrideSpace.s6),
            ],
          ],
        ],
        ),
      ),
    );
  }

  /// The display bands, in planning order. Skill-locked and gated rows
  /// share one LOCKED section — both are "not yet yours", and the row's
  /// own state chip already says which kind.
  static List<(String, List<RecipeOption>)> _bands(
    List<RecipeOption> shown,
  ) => <(String, List<RecipeOption>)>[
    (
      ReadinessBand.ready.label,
      shown.where((RecipeOption r) => r.band == ReadinessBand.ready).toList(),
    ),
    (
      ReadinessBand.oneAway.label,
      shown.where((RecipeOption r) => r.band == ReadinessBand.oneAway).toList(),
    ),
    (
      ReadinessBand.missing.label,
      shown.where((RecipeOption r) => r.band == ReadinessBand.missing).toList(),
    ),
    (
      'Locked',
      shown
          .where(
            (RecipeOption r) =>
                r.band == ReadinessBand.skillLocked ||
                r.band == ReadinessBand.gated,
          )
          .toList(),
    ),
  ];
}

/// The way back from a chain jump — a full-width chip naming where the
/// player came from, so the jump is a corridor and never a teleport.
class _ChainBackChip extends StatelessWidget {
  const _ChainBackChip({required this.target, required this.onTap});

  final RecipeOption? target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (target == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Back to ${target!.displayName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: StrideSpace.s4),
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s10,
          ),
          decoration: BoxDecoration(
            color: StrideColors.surfaceBlock,
            border: Border.all(color: StrideColors.borderDefault),
            borderRadius: StrideRadius.inner,
          ),
          child: Text(
            '◂ Back to ${target!.displayName}',
            style: StrideType.microLabel.copyWith(
              color: StrideColors.textSecondary,
            ),
          ),
        ),
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
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          // Brass, not teal: selection is a chosen thing, not a walking
          // quantity (L-16 repair, Fable V2 Iteration 02).
          border: Border.all(
            color: selected
                ? StrideColors.actionEdge
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
            // The readiness system (Fable V2 Iteration 02): a selected row
            // wears the brass bookmark (L-16 repair — selection was teal);
            // a craftable-but-unselected row wears the quiet moss edge, so
            // "make this now" is scannable down the whole list without
            // reading a single state chip.
            border: Border.all(
              color: selected
                  ? StrideColors.actionEdge
                  : recipe.canCraft
                  ? StrideColors.positiveReadyDim
                  : StrideColors.borderDefault,
            ),
            borderRadius: StrideRadius.inner,
          ),
          child: Row(
            children: <Widget>[
              // A locked recipe's icon recedes; identity stays readable,
              // availability reads at a glance.
              Opacity(
                opacity: dim && !selected ? 0.55 : 1,
                child: InsetWell.square(
                  contentSize: 48,
                  child: PixelAsset.item(PixelIcons.itemFor(recipe.outputItem)),
                ),
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
                      // A one-away row names its single missing material
                      // right on the row (Iteration 03) — the planner's
                      // whole payoff is that this band reads as a to-do
                      // list; by the band's definition the line always
                      // fits, because there is exactly one.
                      recipe.band == ReadinessBand.oneAway
                          ? '${recipe.skillName} ${recipe.requiredLevel} · '
                                'needs ${recipe.ingredients.firstWhere((RecipeIngredientLine i) => !i.satisfied).shortfall} more '
                                '${recipe.ingredients.firstWhere((RecipeIngredientLine i) => !i.satisfied).displayName}'
                          : '${recipe.skillName} ${recipe.requiredLevel} · '
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
              // Moss, not teal: "you can make N" is readiness, not a step
              // quantity (L-16 repair).
              Text(
                state,
                style: StrideType.microLabel.copyWith(
                  color: recipe.canCraft
                      ? StrideColors.positiveReady
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
  const _RecipeDetail({required this.recipe, this.onOpenIngredientRecipe});

  final RecipeOption recipe;

  /// The chain link (Iteration 03): jump the bench to the recipe that
  /// makes a short crafted ingredient. Null while a running craft pins the
  /// selection — the pin wins.
  final void Function(ContentId recipe)? onOpenIngredientRecipe;

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
    final bool summaryHere = !craft.active && craft.summaryRecipe == recipe.id;

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
          // whether they have any at all, in one line per material. A
          // SHORT line grows its sourcing answer directly beneath it
          // (Iteration 03) — the same purpose joins the bag reads — and a
          // short line whose material is itself crafted becomes the chain
          // link. A ready recipe therefore shows exactly what it always
          // did: the fast path stays fast.
          for (final RecipeIngredientLine line
              in recipe.ingredients) ...<Widget>[
            () {
              final bool chain =
                  !line.satisfied &&
                  line.craftedByRecipe != null &&
                  widget.onOpenIngredientRecipe != null;
              final Widget row = Container(
                constraints: chain ? const BoxConstraints(minHeight: 40) : null,
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
                    if (chain) ...<Widget>[
                      const SizedBox(width: StrideSpace.s8),
                      // Not brass: brass is selection; this is a quiet
                      // door (L-16).
                      Text(
                        'CRAFT ›',
                        style: StrideType.microLabel.copyWith(
                          color: StrideColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
              if (!chain) return row;
              return Semantics(
                button: true,
                label: 'Craft ${line.displayName}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      widget.onOpenIngredientRecipe!(line.craftedByRecipe!),
                  child: row,
                ),
              );
            }(),
            if (!line.satisfied)
              if (SessionScope.of(
                    context,
                  ).session.ingredientSourceLine(line.item)
                  case final String sources)
                Padding(
                  padding: const EdgeInsets.only(
                    left: StrideSpace.s10,
                    bottom: StrideSpace.s4,
                  ),
                  child: Text(
                    sources,
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textMuted,
                    ),
                  ),
                ),
          ],

          // The consumed-prover warning (Iteration 03, balance review): if
          // an ingredient is the item an uncompleted contract asks to SEE,
          // say so before the player melts it down.
          if (SessionScope.of(context).session.consumesProverWarning(recipe)
              case final String warning) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              warning,
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          ],

          // And the worn-gear one (Iteration 03 review): a reforge that
          // consumes what the player is wearing unequips it as part of the
          // craft — announced here, not discovered on the Character sheet.
          if (SessionScope.of(context).session.consumesWornGearWarning(recipe)
              case final String wornWarning) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              wornWarning,
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          ],

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
              // READY TO MAKE: a craftable recipe's button joins the moss
              // language its own row already speaks — enticing when the
              // bag funds it, strongly receded when it does not (the
              // disabled plate is flat and ledge-less by construction).
              variant: StrideButtonVariant.ready,
              subLabel: activeElsewhere
                  ? 'Finish or cancel your current craft'
                  : _reason(recipe),
              onPressed:
                  !recipe.canCraft ||
                      controller.busy ||
                      activeElsewhere ||
                      !controller.session.isReady
                  ? null
                  : () {
                      // One light pulse per commitment, as Gather and
                      // Set out — never per repetition loop beat.
                      AudioScope.read(context).hapticLight();
                      CraftScope.read(context).start(recipe, count);
                    },
            ),
            const SizedBox(height: StrideSpace.s6),
            // The Pursuit hook (`DECISIONS/0023` §1): any recipe's output can
            // be tracked, and a locked or distant one is exactly the kind
            // worth tracking. Reserves nothing.
            StrideButton.secondary(
              label: 'Track as Pursuit',
              onPressed: controller.busy
                  ? null
                  : () => SessionScope.read(
                      context,
                    ).trackGoalPursuit(recipe.outputItem),
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
          selected:
              count == preset ||
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
                        activityFootprint: AmbientAssets.activityFootprintFor(
                          skill,
                        ),
                        activityCanvas: AmbientAssets.activityCanvasFor(skill),
                        activityActive: true,
                        // The craft beats (AUDIO_PRESENTATION_01): the hammer
                        // lands, the stir turns — the one accepted cue per
                        // profession, on the visible strike frame, only while
                        // this stage is mounted. Leaving the screen stops the
                        // sound; the craft queue itself never sonifies.
                        activityStrikeFrame: AmbientAssets.strikeFrameFor(
                          skill,
                        ),
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
                style: StrideType.sub.copyWith(color: StrideColors.textPrimary),
              ),
            ),
            _CraftSecondsRemaining(craft: craft),
          ],
        ),
        const SizedBox(height: StrideSpace.s6),
        _CompletionPulse(
          craft: craft,
          skill: recipe.skill,
          child: CraftRepetitionBar(craft: craft, skill: recipe.skill),
        ),
        // The running queue's committed gains live on the universal
        // activity result card (GFCP01 device correction), which updates
        // in place per boundary — the micro-line here said the same thing
        // twice on one screen.
        const SizedBox(height: StrideSpace.s8),
        // An exit, not a commit — the neutral register
        // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 4).
        StrideButton.secondary(
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

/// One completed repetition's **boundary beat**
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1): a light haptic through the
/// audited seam and one brief flash over the repetition bar in the skill's
/// hue — a sensory event that says "one finished, one landed in the bag",
/// where before the bar simply snapped empty.
///
/// Restraint, by construction: one pulse per *increment observed while
/// watching* — a resume that reconciles five repetitions at once is one
/// pulse, not five; an unwatched queue pulses nothing because the widget is
/// not mounted; every card per item stays banned (the batch summary is the
/// queue's one card). The haptic rides `AudioController`'s own toggle gate;
/// reduced motion skips the flash and keeps the haptic, which is not motion.
class _CompletionPulse extends StatefulWidget {
  const _CompletionPulse({
    required this.craft,
    required this.skill,
    required this.child,
  });

  final CraftController craft;
  final ContentId skill;
  final Widget child;

  @override
  State<_CompletionPulse> createState() => _CompletionPulseState();
}

class _CompletionPulseState extends State<_CompletionPulse>
    with SingleTickerProviderStateMixin {
  // Rests at 1, where the tween below is fully transparent; a pulse runs
  // it 0 → 1, fading the wash out. Resting at 0 would paint the wash
  // permanently — the tween's loud end is its start.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..value = 1;
  late int _seen = widget.craft.completed;

  @override
  void initState() {
    super.initState();
    widget.craft.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    final int now = widget.craft.completed;
    if (now > _seen) {
      _seen = now;
      AudioScope.read(context).hapticLight();
      if (!MediaQuery.disableAnimationsOf(context)) _flash.forward(from: 0);
    } else if (now < _seen) {
      // A fresh queue started; nothing to celebrate yet.
      _seen = now;
    }
  }

  @override
  void dispose() {
    widget.craft.removeListener(_onChange);
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: FadeTransition(
            opacity: _flash.drive(
              Tween<double>(
                begin: 0.55,
                end: 0,
              ).chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StrideColors.forSkill(widget.skill),
                borderRadius: StrideRadius.gate,
              ),
            ),
          ),
        ),
      ),
    ],
  );
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

    // The completion itself now lands on the screen's universal activity
    // result card (GFCP01 device correction) — one home, visible whatever
    // row is expanded or scrolled to. What stays here is the refusal: the
    // sentence explaining a stopped queue belongs beside the recipe it
    // stopped on.
    if (refusal == null) return const SizedBox.shrink();
    return SurfaceBlock(
      child: AdaptiveText(
        craft.quantity == 0
            ? _refusalText(refusal)
            : 'Stopped: ${_refusalText(refusal)}',
        style: StrideType.sub,
        color: StrideColors.textSecondary,
      ),
    );
  }

  /// The layer's frame: the item's rarity ink for finished equipment and
  /// for anything significant enough to take the MAJOR frame; the skill's
  /// hue for a level gained on a component run.
  static Color heldAccent(CraftController craft, RecipeOption recipe) =>
      craft.lastReport?.equipDelta != null ||
          craft.significance == CraftSignificance.major
      ? (RarityStyle.maybe(recipe.outputRarity)?.accent ??
            StrideColors.forSkill(recipe.skill))
      : StrideColors.forSkill(recipe.skill);

  /// The beats a held craft summary raises: the crafted thing — its icon,
  /// its rarity, its stat story where it is equipment — and the universal
  /// [LevelUpCard] beneath when a level landed **anywhere in the queue**
  /// (the accumulated facts, not the last report's: a level on repetition
  /// three of ten used to vanish under the seven reports after it).
  static List<Widget> heldBeats(
    BuildContext context,
    CraftController craft,
    RecipeOption recipe,
  ) {
    final CraftReport? last = craft.lastReport;
    final EquipDelta? delta = last?.equipDelta;
    final String skillName = craft.skillName ?? recipe.skillName;
    final String xpLine = '+${craft.xp} $skillName XP';
    final Widget icon = PixelAsset.item(PixelIcons.itemFor(recipe.outputItem));
    return <Widget>[
      if (delta != null && last != null)
        RewardBeat(
          tier: RewardTier.medium,
          eyebrow: 'CRAFTED',
          title: last.outputName ?? recipe.outputName,
          rarity: recipe.outputRarity,
          icon: icon,
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
          rarity: recipe.outputRarity == Rarity.common
              ? null
              : recipe.outputRarity,
          icon: icon,
          lines: <String>[xpLine],
        ),
      if (craft.levelledUpAny)
        LevelUpCard(
          name: craft.levelReport?.skillName ?? skillName,
          level: craft.levelReport?.skillLevelAfter ?? 0,
          skill: recipe.skill,
          unlocked: craft.unlockedNamesAll,
          why: craft.unlockedNamesAll.isEmpty
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
