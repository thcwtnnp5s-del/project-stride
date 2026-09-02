/// The Craft screen — a workshop of three stations, a folio open at the best
/// job in the one you are standing at, and everything else as tiles.
///
/// ## The verdict this rebuild answers
///
/// The owner's device read of the previous screen was "a long mobile
/// database/list of repeated rectangles", and that was a fair description of
/// its structure rather than of its styling: four text chips over one flat
/// list of 39 identically shaped rows, each row a bordered rectangle, each
/// expanding in place into another bordered rectangle. Nothing on the screen
/// named a place, nothing was bigger than anything else, and the only way to
/// find work was to read every row.
///
/// `MILESTONES/evidence/FMPO02/wave1/ART-12_ux_brief.md` §1 replaces that with
/// three moves, none of which touches content, save state or the engine:
///
/// 1. **The station is the axis.** `AmbientAssets.craftStationKind` already
///    resolves all 39 recipes to forge (23), cookfire (11) and woodbench (5),
///    and the props are already drawn and packaged. So the screen heads with
///    three plates you can point at. The categories survive as a secondary
///    filter *inside* a station. The selection is ephemeral UI state, exactly
///    as the old row selection was (`RULES.md` E-2).
/// 2. **One thing is bigger than the rest.** The best ready job in the station
///    is a full-width folio, already open: its output at 96 dp, its rarity,
///    its ingredient tray, its queue and its Craft button. No tap. When the
///    station has nothing ready the folio shows the nearest one-away recipe
///    and its shortfall, so the screen always answers "what now".
/// 3. **The rest are tiles, and detail opens over them.** Two columns, a 4 dp
///    readiness rule flush to each tile's bottom edge, and a hand-rolled
///    bottom sheet for detail — because inline expansion inside a 2-column
///    grid displaces the tile's row partner and shoves half the list off
///    screen, which is the scroll-hunt that made this read as a database.
///
/// The locked band stops being 20 near-identical rows and becomes a ledger:
/// one line per gate ("4 more at Smithing 3"), expanded on demand.
///
/// ## The rules this screen still keeps
///
/// **A disabled recipe must say why it is disabled.** Every recipe in the
/// content pack is still reachable, and the reason sentence is unchanged and
/// is still the only statement of why: the ledger line names the *gate*, the
/// tile's sheet carries `_craftReason` verbatim. **No lock, padlock or keyhole
/// anywhere** (`ART-02_ui_brief.md` §5).
///
/// **Crafting costs no steps — still.** `GAME_BIBLE/SYSTEMS/04`: the steps
/// were already spent gathering. The timed flow is presentation pacing over
/// the same instant command (`craft_controller.dart`): each completed
/// repetition is one ordinary engine-validated `CraftItem`, exact ingredients
/// out, exact output in, exactly once. This remains the one screen whose
/// primary action works at a zero balance, and **nothing about the crafting
/// semantics changed in this rebuild** — the same controller call, with the
/// same count, behind the same haptic.
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
import '../../components/bottom_sheet.dart';
import '../../components/data_display.dart';
import '../../components/gear_stats.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/station_strip.dart';
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
///
/// Demoted by FMPO02 from the screen's primary axis to a filter **inside** a
/// station: a forge holds gear, tools and materials, and the player who has
/// walked to the forge is asking a narrower question than "show me all gear".
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

/// The three stations, in the order the strip draws them, with the names the
/// player sees. The kinds are `AmbientAssets`' own, so the art table and this
/// list cannot drift.
const List<(String kind, String label)> _stations = <(String, String)>[
  ('forge', 'Forge'),
  ('woodbench', 'Bench'),
  ('cookfire', 'Cookfire'),
];

/// Which station a recipe belongs to — the authored workstation, with the
/// profession as fallback. Free data: an oak plank is bench work even though
/// Smithing owns it (`RecipeDefinition.station`).
String _stationOf(RecipeOption recipe) =>
    AmbientAssets.craftStationKind(recipe.station?.name, recipe.skill.value);

/// The one sentence that explains a disabled action — lock before skill,
/// skill before ingredients, the engine's own refusal order.
///
/// File-level since FMPO02 because two surfaces state it: the folio's button
/// and the sheet's. It is the same sentence in both, by construction.
String? _craftReason(RecipeOption recipe) {
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

class CraftScreen extends StatefulWidget {
  const CraftScreen({super.key});

  @override
  State<CraftScreen> createState() => _CraftScreenState();
}

class _CraftScreenState extends State<CraftScreen> {
  /// The category filter, inside the station. Null shows everything.
  CraftCategory? _category;

  /// The chosen station, or null while the screen is still choosing for the
  /// player. Ephemeral UI state — nothing durable, nothing saved
  /// (`RULES.md` E-2).
  ///
  /// Null does not mean "forge": it means the default is still being derived
  /// each build from what the bag can currently fund, so a player who gathers
  /// their way into a craftable meal finds the screen already standing at the
  /// cookfire. The moment they tap a plate the choice is theirs and stops
  /// moving.
  String? _station;

  /// The recipe whose detail sheet is open, or null. The sheet replaced
  /// inline expansion (`ART-12` §1) — see `bottom_sheet.dart` for why.
  ContentId? _sheetRecipe;

  /// The chain-jump breadcrumb (Fable V2 Iteration 03): tapping a short
  /// crafted ingredient jumps to the recipe that makes it, and this
  /// remembers the way back. Depth in shipped content is ≤2 (ore → ingot →
  /// sword), so one visible chip covers reality.
  ///
  /// Since FMPO02 the jump happens **inside the sheet**, replacing its
  /// content in place, so the list beneath never moves and the elaborate
  /// lazy-list reveal the old inline expansion needed is gone with it.
  final List<ContentId> _chainStack = <ContentId>[];

  /// Which locked gates the player has opened. Presentation only.
  final Set<String> _openGates = <String>{};

  void _openSheet(RecipeOption recipe) {
    // Opening detail clears a transient result; a held one has its own
    // Continue.
    final CraftController craft = CraftScope.read(context);
    if (!craft.active && !craft.summaryHeld) craft.dismissSummary();
    setState(() {
      _chainStack.clear();
      _sheetRecipe = recipe.id;
    });
  }

  void _closeSheet() {
    if (_sheetRecipe == null) return;
    setState(() {
      _sheetRecipe = null;
      _chainStack.clear();
    });
  }

  /// Replaces the sheet's content with [recipe], remembering [from].
  void _jumpTo(ContentId recipe, {required ContentId from}) {
    setState(() {
      _chainStack.add(from);
      _sheetRecipe = recipe;
    });
  }

  void _jumpBack() {
    if (_chainStack.isEmpty) return;
    final ContentId back = _chainStack.removeLast();
    setState(() => _sheetRecipe = back);
  }

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final CraftController craft = CraftScope.of(context);
    final StrideSession session = controller.session;
    final List<RecipeOption> recipes = session.recipeOptions;

    // A running queue, or a finished one whose MEDIUM result is still held,
    // pins the folio to its recipe, so the working surface never disappears
    // under the player mid-craft. A MINOR result does **not** pin (the
    // correction pass): it is transient — on its timer, and gone the moment
    // the player opens another recipe.
    final ContentId? pinned =
        craft.activeRecipe ?? (craft.summaryHeld ? craft.summaryRecipe : null);
    final RecipeOption? pinnedRecipe = pinned == null
        ? null
        : recipes.cast<RecipeOption?>().firstWhere(
            (RecipeOption? r) => r!.id == pinned,
            orElse: () => null,
          );

    // The station: the pinned craft's, while one runs — the player is
    // standing at that bench whether or not they chose it — then their own
    // choice, then the first station holding something they can make.
    final String station = pinnedRecipe != null
        ? _stationOf(pinnedRecipe)
        : _defaultStation(recipes);

    final List<RecipeOption> here = recipes
        .where((RecipeOption r) => _stationOf(r) == station)
        .toList();
    final List<RecipeOption> shown = _category == null
        ? here
        : here
              .where((RecipeOption r) => CraftCategory.of(r) == _category)
              .toList();
    final int ready = shown.where((RecipeOption r) => r.canCraft).length;

    // The folio's subject: what is running, else the best job this station
    // can fund, else the nearest one it cannot.
    final RecipeOption? hero = pinnedRecipe ?? _folioSubject(shown);

    final bool held = craft.summaryHeld && pinnedRecipe != null;

    // The universal activity result (GFCP01 device correction): "nothing
    // happened after crafting" was the device verdict on the in-row beat.
    // Every completion now lands a floating card at the screen's foot.
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

    final RecipeOption? sheetRecipe = _sheetRecipe == null
        ? null
        : recipes.cast<RecipeOption?>().firstWhere(
            (RecipeOption? r) => r!.id == _sheetRecipe,
            orElse: () => null,
          );

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
      // Back closes the sheet before it leaves the screen — the sheet is a
      // layer over this tab, so the gesture that dismisses a layer must
      // dismiss this one.
      child: PopScope<Object?>(
        canPop: sheetRecipe == null,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _closeSheet();
        },
        child: Stack(
          children: <Widget>[
            ActivityResultHost(
              result: craftResult,
              resultToken: craftToken,
              // A finished summary's card, once read, acknowledges the
              // controller's summary; a mid-run card expiring acknowledges
              // nothing (dismissSummary is a no-op while the queue runs).
              onExpired: CraftScope.read(context).dismissSummary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  StrideSpace.screenGutter,
                  StrideSpace.s12,
                  StrideSpace.screenGutter,
                  StrideSpace.s16,
                ),
                children: <Widget>[
                  if (session.isStale) ...<Widget>[
                    StaleBanner(
                      busy: controller.busy,
                      onReload: controller.reload,
                    ),
                    const SizedBox(height: StrideSpace.rhythmGroup),
                  ],

                  // The workshop's own axis. Counts are over the whole
                  // station, never the filtered view: a plate answers "what
                  // is over there", and a category filter is a question you
                  // ask after you have walked over.
                  StationStrip(
                    stations: <StationEntry>[
                      for (final (String kind, String label) in _stations)
                        _census(recipes, kind, label),
                    ],
                    selected: station,
                    onSelect: (String kind) => setState(() {
                      _station = kind;
                      _sheetRecipe = null;
                      _chainStack.clear();
                    }),
                  ),
                  const SizedBox(height: StrideSpace.rhythmGroup),

                  _CategoryChips(
                    selected: _category,
                    onSelect: (CraftCategory? c) =>
                        setState(() => _category = c),
                  ),
                  const SizedBox(height: StrideSpace.rhythmRow),

                  // The honest census of what the filter shows. Two figures
                  // in one shape, whatever the numbers are — nothing
                  // craftable is a fact about the bag, not a disappointment
                  // to soften.
                  AdaptiveText(
                    '$ready craftable · ${shown.length} known',
                    style: StrideType.sub,
                    color: ready == 0
                        ? StrideColors.textMuted
                        : StrideColors.textSecondary,
                  ),
                  const SizedBox(height: StrideSpace.rhythmGroup),

                  if (shown.isEmpty)
                    const SectionCard(
                      child: AdaptiveText(
                        'Nothing in this category yet.',
                        style: StrideType.body,
                      ),
                    ),

                  if (hero != null) ...<Widget>[
                    _HeroFolio(
                      key: ValueKey<String>('folio:${hero.id.value}'),
                      recipe: hero,
                    ),
                    const SizedBox(height: StrideSpace.rhythmHero),
                  ],

                  // Ready / One away / Missing, as tiles. The folio's own
                  // recipe is not repeated beneath itself.
                  for (final (String label, List<RecipeOption> band) in _bands(
                    shown,
                    exclude: hero?.id,
                  ))
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
                      const SizedBox(height: StrideSpace.rhythmRow),
                      _TileFolio(recipes: band, onOpen: _openSheet),
                      const SizedBox(height: StrideSpace.rhythmGroup),
                    ],

                  if (_locked(shown) case final List<RecipeOption> locked
                      when locked.isNotEmpty) ...<Widget>[
                    SectionHeading(
                      label: 'Locked',
                      trailing: Text(
                        '${locked.length}',
                        style: StrideType.microLabel.copyWith(
                          color: StrideColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: StrideSpace.rhythmRow),
                    _LockedLedger(
                      locked: locked,
                      open: _openGates,
                      onToggle: (String gate) => setState(() {
                        if (!_openGates.remove(gate)) _openGates.add(gate);
                      }),
                      onOpen: _openSheet,
                    ),
                  ],
                ],
              ),
            ),

            StrideSheet(
              open: sheetRecipe != null,
              onDismiss: _closeSheet,
              label: sheetRecipe?.displayName,
              child: sheetRecipe == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_chainStack.isNotEmpty)
                          _ChainBackChip(
                            target: recipes.cast<RecipeOption?>().firstWhere(
                              (RecipeOption? r) => r!.id == _chainStack.last,
                              orElse: () => null,
                            ),
                            onTap: _jumpBack,
                          ),
                        _RecipeDetail(
                          key: ValueKey<String>(
                            'detail:${sheetRecipe.id.value}',
                          ),
                          recipe: sheetRecipe,
                          // The chain link: disabled while a craft pins the
                          // folio — the pin already wins and must keep
                          // winning.
                          onOpenIngredientRecipe: craft.active
                              ? null
                              : (ContentId target) =>
                                    _jumpTo(target, from: sheetRecipe.id),
                          // A dispatched craft takes over the folio at the
                          // top of the screen, which is where the stage, the
                          // bar and Cancel live. Two live panels would mean
                          // two completion pulses per repetition — two
                          // haptics for one event — so the sheet stands
                          // down.
                          onCraftStarted: _closeSheet,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The station the screen stands at when the player has not chosen one:
  /// the first holding something they can make right now, else the forge.
  String _defaultStation(List<RecipeOption> recipes) {
    if (_station case final String chosen) return chosen;
    for (final (String kind, _) in _stations) {
      final bool anyReady = recipes.any(
        (RecipeOption r) => _stationOf(r) == kind && r.canCraft,
      );
      if (anyReady) return kind;
    }
    return _stations.first.$1;
  }

  static StationEntry _census(
    List<RecipeOption> recipes,
    String kind,
    String label,
  ) {
    int total = 0;
    int ready = 0;
    for (final RecipeOption r in recipes) {
      if (_stationOf(r) != kind) continue;
      total += 1;
      if (r.canCraft) ready += 1;
    }
    return StationEntry(kind: kind, label: label, total: total, ready: ready);
  }

  /// The folio's subject: the best ready recipe — highest tier, then the one
  /// the bag can fund most of — and, when nothing is ready, the nearest
  /// one-away recipe, so the screen always has an answer to "what now".
  static RecipeOption? _folioSubject(List<RecipeOption> shown) {
    final List<RecipeOption> ready = shown
        .where((RecipeOption r) => r.band == ReadinessBand.ready)
        .toList();
    if (ready.isNotEmpty) {
      ready.sort((RecipeOption a, RecipeOption b) {
        final int tier = _tier(b.outputRarity).compareTo(_tier(a.outputRarity));
        if (tier != 0) return tier;
        return b.craftableCount.compareTo(a.craftableCount);
      });
      return ready.first;
    }
    final List<RecipeOption> near = shown
        .where((RecipeOption r) => r.band == ReadinessBand.oneAway)
        .toList();
    if (near.isEmpty) return null;
    near.sort((RecipeOption a, RecipeOption b) {
      final int gap = _shortfall(a).compareTo(_shortfall(b));
      if (gap != 0) return gap;
      return _tier(b.outputRarity).compareTo(_tier(a.outputRarity));
    });
    return near.first;
  }

  /// A rarity's rank, and −1 for a pack with no definition — so an undefined
  /// output can never outrank a defined one.
  static int _tier(Rarity? rarity) => rarity?.index ?? -1;

  /// How many units short a one-away recipe is. By the band's own definition
  /// exactly one line is short, so this reads it rather than summing.
  static int _shortfall(RecipeOption recipe) => recipe.ingredients
      .firstWhere((RecipeIngredientLine i) => !i.satisfied)
      .shortfall;

  /// The tile bands, in planning order, with the folio's own recipe removed
  /// so the screen never shows one job twice.
  static List<(String, List<RecipeOption>)> _bands(
    List<RecipeOption> shown, {
    ContentId? exclude,
  }) {
    List<RecipeOption> of(ReadinessBand band) => shown
        .where((RecipeOption r) => r.band == band && r.id != exclude)
        .toList();
    return <(String, List<RecipeOption>)>[
      (ReadinessBand.ready.label, of(ReadinessBand.ready)),
      (ReadinessBand.oneAway.label, of(ReadinessBand.oneAway)),
      (ReadinessBand.missing.label, of(ReadinessBand.missing)),
    ];
  }

  /// Skill-locked and contract-gated rows share one ledger — both are "not
  /// yet yours", and the ledger's own line says which kind.
  static List<RecipeOption> _locked(List<RecipeOption> shown) => shown
      .where(
        (RecipeOption r) =>
            r.band == ReadinessBand.skillLocked ||
            r.band == ReadinessBand.gated,
      )
      .toList();
}

// ---------------------------------------------------------------- the folio

/// The station's open job: the one thing on this screen that is bigger than
/// the others.
///
/// Full width, already expanded, no tap and no sheet — inline expansion
/// survives here and only here, because the folio is single and full width
/// and therefore displaces nothing. `PanelRole.heroPlate` is one of the two
/// framed roles (`panel_skin.dart`), and `journalLeaf` is the recipe folio's
/// material (`ART-02` §2): a page in a workbook, not a card in a list.
class _HeroFolio extends StatefulWidget {
  const _HeroFolio({super.key, required this.recipe});

  final RecipeOption recipe;

  @override
  State<_HeroFolio> createState() => _HeroFolioState();
}

class _HeroFolioState extends State<_HeroFolio> {
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
      role: PanelRole.heroPlate,
      surface: PanelSurface.journalLeaf,
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The output at 96 dp — 48 native at ×2, an integer multiple
              // and zero new art. This is the prominence the old screen
              // never gave anything.
              InsetWell.square(
                contentSize: 96,
                child: PixelAsset.item(
                  PixelIcons.recipeIconFor(recipe.id, recipe.outputItem),
                  scale: 2,
                ),
              ),
              const SizedBox(width: StrideSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RarityName.wrapping(
                      name: recipe.displayName,
                      rarity: recipe.outputRarity,
                      style: StrideType.cardTitle,
                    ),
                    if (recipe.outputRarity != null) ...<Widget>[
                      const SizedBox(height: StrideSpace.s6),
                      RarityBadge(rarity: recipe.outputRarity),
                    ],
                    const SizedBox(height: StrideSpace.s6),
                    AdaptiveText(
                      '${recipe.skillName} ${recipe.requiredLevel} · '
                      '+${recipe.experience} XP',
                      style: StrideType.micro,
                      color: StrideColors.textSecondary,
                    ),
                    if (recipe.outputQuantity != 1 ||
                        recipe.outputName != recipe.displayName) ...<Widget>[
                      const SizedBox(height: StrideSpace.s4),
                      AdaptiveText(
                        recipe.outputQuantity == 1
                            ? 'Makes ${recipe.outputName}'
                            : 'Makes ${recipe.outputQuantity} × '
                                  '${recipe.outputName}',
                        style: StrideType.micro,
                        color: StrideColors.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.rhythmRow),

          _IngredientTray(recipe: recipe),

          const SizedBox(height: StrideSpace.rhythmRow),
          if (activeHere)
            _ActiveCraftPanel(recipe: recipe)
          else ...<Widget>[
            if (recipe.canCraft && maxCount > 1) ...<Widget>[
              _QueueChips(
                count: count,
                maxCount: maxCount,
                onChanged: (int v) => setState(() => _requested = v),
              ),
              const SizedBox(height: StrideSpace.rhythmRow),
            ],
            StrideButton(
              label: controller.busy || activeElsewhere
                  ? 'Crafting…'
                  : count > 1
                  ? 'Craft ×$count'
                  : 'Craft',
              // READY TO MAKE: a craftable recipe's button joins the moss
              // language the tiles' readiness rules already speak.
              variant: StrideButtonVariant.ready,
              subLabel: activeElsewhere
                  ? 'Finish or cancel your current craft'
                  : _craftReason(recipe),
              onPressed:
                  !recipe.canCraft ||
                      controller.busy ||
                      activeElsewhere ||
                      !controller.session.isReady
                  ? null
                  : () {
                      // One light pulse per commitment, as Gather and Set
                      // out — never per repetition loop beat.
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
              const SizedBox(height: StrideSpace.rhythmRow),
              _CraftSummary(craft: craft, recipe: recipe),
            ],
          ],
        ],
      ),
    );
  }
}

/// The folio's materials, as a tray rather than a table of lines.
///
/// A `Wrap` of 48 dp wells with held/required beneath each, on the waxed
/// canvas the materials tray wears everywhere (`ART-02` §2). The old detail
/// stated the same facts as a stack of `name … 3 / 5` rows, which is a
/// spreadsheet of a thing the player already recognises by sight.
class _IngredientTray extends StatelessWidget {
  const _IngredientTray({required this.recipe});

  final RecipeOption recipe;

  /// The well plus the count line's own column. Wide enough that `12 / 24`
  /// does not wrap under an enlarged scaler, narrow enough that four fit a
  /// 320 dp folio.
  static const double _slot = 56;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Wrap(
      spacing: StrideSpace.rhythmRow,
      runSpacing: StrideSpace.rhythmRow,
      children: <Widget>[
        for (final RecipeIngredientLine line in recipe.ingredients)
          Semantics(
            label: '${line.displayName}, ${line.held} of ${line.required} held',
            child: SizedBox(
              width: _slot,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Opacity(
                    opacity: line.satisfied ? 1 : 0.55,
                    child: InsetWell.square(
                      contentSize: 48,
                      child: PixelAsset.item(PixelIcons.itemFor(line.item)),
                    ),
                  ),
                  const SizedBox(height: StrideSpace.s4),
                  AdaptiveText(
                    '${line.held} / ${line.required}',
                    style: StrideType.micro,
                    textAlign: TextAlign.center,
                    color: line.satisfied
                        ? StrideColors.textPrimary
                        : StrideColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- the tiles

/// One band's recipes, as leaves of a single folio rather than as a column of
/// cards.
///
/// Two columns; a 1 px hairline between tile rows; the whole group on one
/// `journalLeaf` surface with one border. `ART-02` §4 is explicit about why:
/// the database read comes from the structural fact that **every recipe was
/// its own rounded card**, and killing that is the fix.
class _TileFolio extends StatelessWidget {
  const _TileFolio({
    required this.recipes,
    required this.onOpen,
    this.surfaced = true,
  });

  final List<RecipeOption> recipes;
  final ValueChanged<RecipeOption> onOpen;

  /// Whether this group draws its own folio surface.
  ///
  /// False inside the locked ledger, which is already one folio: nesting a
  /// second card there would put two borders and two grains around one set
  /// of leaves, which is the failure `panel_skin.dart` names by name.
  final bool surfaced;

  /// The height one tile row needs at [scaler], never below the designed
  /// floor.
  ///
  /// **Derived, never a constant.** `mainAxisExtent` is exact rather than
  /// minimum, and the Inventory grid shipped a documented *floor* straight
  /// into it: at text scale 1.4 the second line of a wrapped name had
  /// nowhere to go and clipped silently, which is D-01's shape one axis
  /// over. So the extent is computed from the same terms the tile spends —
  /// icon, two name lines, the state line, the readiness rule and the
  /// padding — under the ambient scaler.
  static double tileExtent(TextScaler scaler) {
    double lineOf(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1);

    const double iconEdge = 48 + 2; // InsetWell adds its 1 px border a side.
    const double padding = StrideSpace.s10 + StrideSpace.s8;
    const double gaps = StrideSpace.s6 * 2;
    const double rule = _RecipeTile.readinessRule;

    final double needed =
        padding +
        iconEdge +
        gaps +
        rule +
        lineOf(StrideType.itemName) * 2 +
        lineOf(StrideType.micro);

    return needed > _floor ? needed : _floor;
  }

  /// `ART-12` §1's floor. A tile shorter than this stops holding a 48 dp
  /// icon and two name lines at the same time.
  static const double _floor = 112;

  @override
  Widget build(BuildContext context) {
    final double extent = tileExtent(MediaQuery.textScalerOf(context));
    final int rows = (recipes.length + 1) ~/ 2;

    final Widget leaves = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) ...<Widget>[
            // The 8 dp row rhythm, with the hairline sitting in the
            // middle of it — one rule between leaves, not a border around
            // each.
            const SizedBox(height: StrideSpace.s4),
            Container(height: 1, color: StrideColors.separator),
            const SizedBox(height: StrideSpace.s4),
          ],
          SizedBox(
            height: extent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _RecipeTile(
                    recipe: recipes[row * 2],
                    onTap: () => onOpen(recipes[row * 2]),
                  ),
                ),
                const SizedBox(width: StrideSpace.rhythmRow),
                Expanded(
                  child: row * 2 + 1 < recipes.length
                      ? _RecipeTile(
                          recipe: recipes[row * 2 + 1],
                          onTap: () => onOpen(recipes[row * 2 + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (!surfaced) return leaves;
    return SectionCard(
      surface: PanelSurface.journalLeaf,
      padding: const EdgeInsets.all(StrideSpace.s10),
      child: leaves,
    );
  }
}

/// One recipe, as a leaf: its output, its name, its one state line, and a
/// readiness rule flush to the bottom edge.
class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.onTap});

  final RecipeOption recipe;
  final VoidCallback onTap;

  /// The mark that makes readiness scannable down a whole grid without
  /// reading a single word. Moss when the bag funds it; the ordinary border
  /// otherwise. Not a meter, not a fill, not a badge (`ART-02` §5).
  static const double readinessRule = 4;

  @override
  Widget build(BuildContext context) {
    final bool dim = !recipe.canCraft;
    final String state = switch (recipe.band) {
      ReadinessBand.ready => '×${recipe.craftableCount} ready',
      ReadinessBand.oneAway => () {
        final RecipeIngredientLine short = recipe.ingredients.firstWhere(
          (RecipeIngredientLine i) => !i.satisfied,
        );
        return '${short.shortfall} more ${short.displayName}';
      }(),
      ReadinessBand.missing =>
        '${recipe.ingredients.where((RecipeIngredientLine i) => !i.satisfied).length} materials short',
      ReadinessBand.skillLocked =>
        '${recipe.skillName} ${recipe.requiredLevel}',
      ReadinessBand.gated => 'Not learned yet',
    };

    return Semantics(
      button: true,
      label: '${recipe.displayName}, $state',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  StrideSpace.s10,
                  0,
                  StrideSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A locked recipe's icon recedes; identity stays
                    // readable, availability reads at a glance.
                    Opacity(
                      opacity: dim ? 0.55 : 1,
                      child: InsetWell.square(
                        contentSize: 48,
                        child: PixelAsset.item(
                          PixelIcons.recipeIconFor(
                            recipe.id,
                            recipe.outputItem,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: StrideSpace.s6),
                    // Rarity ink always — the rank is the item's identity
                    // (§20), not its availability; the state line carries
                    // the dimming.
                    Text(
                      recipe.displayName,
                      style: StrideType.itemName.copyWith(
                        color: RarityStyle.inkOr(
                          recipe.outputRarity,
                          StrideColors.textPrimary,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      state,
                      style: StrideType.micro.copyWith(
                        color: recipe.canCraft
                            ? StrideColors.positiveReady
                            : StrideColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: readinessRule,
              decoration: BoxDecoration(
                color: recipe.canCraft
                    ? StrideColors.positiveReady
                    : StrideColors.borderDefault,
                borderRadius: StrideRadius.gate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- the locked ledger

/// The locked band as a ledger: one line per **gate**, not one row per
/// recipe.
///
/// Twenty near-identical locked rows is the single largest contributor to the
/// database read, and every one of them says the same thing in the same
/// shape. A gate line says it once — "4 more at Smithing 3" — and opens into
/// the ordinary tiles when the player wants the names. No lock, padlock or
/// keyhole appears anywhere here, by rule; the recipe's own reason sentence,
/// unchanged, is still the only statement of why, and it lives in the tile's
/// sheet.
class _LockedLedger extends StatelessWidget {
  const _LockedLedger({
    required this.locked,
    required this.open,
    required this.onToggle,
    required this.onOpen,
  });

  final List<RecipeOption> locked;
  final Set<String> open;
  final ValueChanged<String> onToggle;
  final ValueChanged<RecipeOption> onOpen;

  /// The gate a recipe waits behind. Skill gates group by skill and level,
  /// because that is a destination the player can walk toward; contract and
  /// project gates share one line, because their sentences are per-recipe
  /// and belong in the sheet rather than in a ledger.
  static String _gateOf(RecipeOption recipe) => recipe.isLocked
      ? 'taught'
      : 'skill:${recipe.skillName}:${recipe.requiredLevel}';

  static String _labelOf(String gate, int count) => gate == 'taught'
      ? '$count more taught by other work'
      : '$count more at ${gate.split(':')[1]} ${gate.split(':')[2]}';

  @override
  Widget build(BuildContext context) {
    // Skill gates first, by the level they ask for — the ledger reads as a
    // road — and the taught line last.
    final Map<String, List<RecipeOption>> gates =
        <String, List<RecipeOption>>{};
    for (final RecipeOption r in locked) {
      gates.putIfAbsent(_gateOf(r), () => <RecipeOption>[]).add(r);
    }
    final List<String> order = gates.keys.toList()
      ..sort((String a, String b) {
        if (a == 'taught') return 1;
        if (b == 'taught') return -1;
        final int level = int.parse(
          a.split(':')[2],
        ).compareTo(int.parse(b.split(':')[2]));
        return level != 0 ? level : a.compareTo(b);
      });

    return SectionCard(
      surface: PanelSurface.journalLeaf,
      padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final String gate in order) ...<Widget>[
            if (gate != order.first)
              Container(height: 1, color: StrideColors.separator),
            _GateLine(
              label: _labelOf(gate, gates[gate]!.length),
              open: open.contains(gate),
              onTap: () => onToggle(gate),
            ),
            if (open.contains(gate)) ...<Widget>[
              const SizedBox(height: StrideSpace.s4),
              _TileFolio(
                recipes: gates[gate]!,
                onOpen: onOpen,
                surfaced: false,
              ),
              const SizedBox(height: StrideSpace.rhythmRow),
            ],
          ],
        ],
      ),
    );
  }
}

class _GateLine extends StatelessWidget {
  const _GateLine({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  /// 40 dp of line inside a 44 dp hit region — the visual weight the brief
  /// asks for, over the touch target the platform requires.
  static const double lineHeight = 40;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: StrideGeometry.buttonHitFloor,
        ),
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: lineHeight,
          child: Row(
            children: <Widget>[
              Expanded(
                child: AdaptiveText(
                  label,
                  style: StrideType.sub,
                  color: StrideColors.textSecondary,
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Text(
                open ? '▴' : '▾',
                style: StrideType.microLabel.copyWith(
                  color: StrideColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// -------------------------------------------------------------- the details

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

/// The filter chips: All plus the four categories — a **secondary** filter
/// inside the chosen station since FMPO02.
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

/// A tile's working surface, unchanged, now raised in a sheet: ingredients,
/// the reason it cannot be made when it cannot, the queue, the craft flow,
/// and the Pursuit hook.
class _RecipeDetail extends StatefulWidget {
  const _RecipeDetail({
    super.key,
    required this.recipe,
    this.onOpenIngredientRecipe,
    this.onCraftStarted,
  });

  final RecipeOption recipe;

  /// The chain link (Iteration 03): jump to the recipe that makes a short
  /// crafted ingredient. Null while a running craft pins the folio — the pin
  /// wins.
  final void Function(ContentId recipe)? onOpenIngredientRecipe;

  /// Run immediately after a craft is dispatched, so the host can stand the
  /// sheet down and let the folio's own live panel be the only one.
  final VoidCallback? onCraftStarted;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InsetWell.square(
                contentSize: 48,
                child: PixelAsset.item(
                  PixelIcons.recipeIconFor(recipe.id, recipe.outputItem),
                ),
              ),
              const SizedBox(width: StrideSpace.s10),
              Expanded(
                child: RarityName.wrapping(
                  name: recipe.displayName,
                  rarity: recipe.outputRarity,
                  style: StrideType.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: StrideSpace.s6),
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
              // language its own tile already speaks — enticing when the
              // bag funds it, strongly receded when it does not (the
              // disabled plate is flat and ledge-less by construction).
              variant: StrideButtonVariant.ready,
              subLabel: activeElsewhere
                  ? 'Finish or cancel your current craft'
                  : _craftReason(recipe),
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
                      widget.onCraftStarted?.call();
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
      style: StrideType.micro.copyWith(fontFeatures: StrideType.tabularFigures),
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
///
/// **Exactly one of these is ever mounted.** The live panel belongs to the
/// folio; a sheet that dispatches a craft closes itself, precisely so a
/// second copy of this widget cannot double every boundary haptic.
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
    // is expanded or scrolled to. What stays here is the refusal: the
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
    // The payoff shows the THING, so this is the output item's own icon and
    // never the recipe-level salvage art: what landed in the bag is an
    // ingot, whatever the job was called.
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
