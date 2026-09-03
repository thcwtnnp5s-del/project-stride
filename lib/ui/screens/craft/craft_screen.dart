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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ItemCategory, Rarity;

import '../../../audio/audio_controller.dart';
import '../../../audio/audio_events.dart';
import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/band_plate.dart';
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
import '../../icons/reward_art.dart';
import '../../icons/sprite_footprints.dart';
import '../../icons/traveler_art.dart';
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
import 'craft_art.dart';

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

/// **The screen's one readiness grammar** (`DIR-06` §4, failure 5).
///
/// Readiness used to be said three ways — "1 more Herb" on a tile, "2
/// materials short" on another, "Needs Smithing 6 — you are 1" on a button,
/// "4 more at Smithing 3" in the ledger — so the player had to re-learn the
/// sentence at every scale of the screen. There is now one:
///
/// * `Ready ×N` — the bag funds it, and how many times;
/// * `Short by 2 Copper Ore` / `Short by 3 materials` — what is missing;
/// * `Opens at Cooking 5` — a level gate, said **once per chapter** in the
///   recipe book's tier header and never on a row;
/// * `Not written yet` — taught by other work.
///
/// [_craftReason] is deliberately **not** folded into this. It is the
/// disabled *action*'s explanation, it is the sentence three other tests and
/// two other screens already read, and it names every short material rather
/// than the first — a button that refuses has to say the whole reason.
String _readinessLine(RecipeOption recipe) => switch (recipe.band) {
  ReadinessBand.ready => 'Ready ×${recipe.craftableCount}',
  ReadinessBand.oneAway => () {
    final RecipeIngredientLine short = recipe.ingredients.firstWhere(
      (RecipeIngredientLine i) => !i.satisfied,
    );
    return 'Short by ${short.shortfall} ${short.displayName}';
  }(),
  ReadinessBand.missing =>
    'Short by '
        '${recipe.ingredients.where((RecipeIngredientLine i) => !i.satisfied).length}'
        ' materials',
  ReadinessBand.skillLocked =>
    'Opens at ${recipe.skillName} ${recipe.requiredLevel}',
  ReadinessBand.gated => 'Not written yet',
};

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

  /// The finished queue whose completion sound has already played, by the
  /// same token the result presentation itself is keyed to. Presentation
  /// memory of nothing durable.
  Object? _cuedCompletion;

  /// The sound a finished craft makes, fired once as its result is presented
  /// — the held summary's raise, or the transient card's arrival, whichever
  /// this completion earned.
  ///
  /// Sorted by what was **made**, not by how loudly it is shown: the queue's
  /// briefs are a quenching hiss for finished metal, a lid onto a pot for
  /// food, one dry knock for everything else
  /// (`AUDIO/AUDIO_PRODUCTION_QUEUE_02.md` §5.3). A tool is gear here — a
  /// finished bronze pick comes off the same anvil as a sword, and
  /// `CraftCategory` splits them for a filter row, not for the ear.
  void _cueCraftCompletion(Object token, RecipeOption? recipe) {
    if (token == _cuedCompletion) return;
    _cuedCompletion = token;
    final AudioController? audio = AudioScope.maybeRead(context);
    if (audio == null) return;
    // A completion whose recipe cannot be resolved is still a completion;
    // the quiet knock is the honest answer, never silence and never a ring.
    switch (recipe == null
        ? CraftCategory.materials
        : CraftCategory.of(recipe)) {
      case CraftCategory.gear:
      case CraftCategory.tools:
        audio.playEvent('craft.complete.gear');
      case CraftCategory.food:
        audio.playEvent('craft.complete.food');
      case CraftCategory.materials:
        audio.playEvent('craft.complete.minor');
    }
  }

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

    // The completion's sound, at the moment the completion is presented: the
    // held summary's raise (MEDIUM/MAJOR) or the transient card's arrival
    // (MINOR) — the two are mutually exclusive above, so a completion is
    // heard exactly once. Gated on the queue being **finished**: a run of ten
    // planks is one knock at the end, not ten, and the bench already sounds
    // while it works (`playSkillCue`, `_ActiveCraftPanel`).
    if (!craft.active && craft.completed > 0) {
      final Object? completion = held ? craft.lastReport : craftToken;
      final ContentId? made = craft.summaryRecipe ?? craft.activeRecipe;
      if (completion != null) {
        _cueCraftCompletion(
          completion,
          made == null
              ? pinnedRecipe
              : recipes.cast<RecipeOption?>().firstWhere(
                  (RecipeOption? r) => r!.id == made,
                  orElse: () => null,
                ),
        );
      }
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
      // The ceiling of craft quality (an Epic-or-better output, the same
      // test `craftSignificanceOf` already made) wears the masterwork seal
      // — a banner, not the 48² plate, so it needs the layer's own slot
      // size (ART-10 §1, §3).
      emblem: held && craft.significance == CraftSignificance.major
          ? RewardArt.sealMasterwork
          : null,
      emblemSize: const Size(96, 48),
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
              child: PageGround(
                // The workshop is written on bench oak, full bleed
                // (`DIR-06` §1). One material, no card round the page, and
                // therefore no rectangle-inside-a-rectangle at the top of
                // the tab — which was the second-named failure.
                surface: PanelSurface.benchOak,
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
                  // No card: the bench oak is the page itself now, and the
                  // strip is furniture standing on it (`DIR-06` §1, §2).
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
                  const SizedBox(height: StrideSpace.rhythmRow),

                  // The chosen station's own place, under its name (FMPO02).
                  // Untitled on purpose: the strip above already labels the
                  // plate the player just tapped, and a band repeating that
                  // word is the same heading twice. Absent for a kind with no
                  // authored band rather than borrowing another's.
                  if (StrideBands.forStation(station) case final StrideBand b)
                    ...<Widget>[
                      BandPlate(band: b),
                      const SizedBox(height: StrideSpace.rhythmRow),
                    ],

                  // The category rail, on the band's lower edge: glyph-led
                  // tabs with a brass underline pin, never a filled chip
                  // (`DIR-06` §3). The honest census of what the filter
                  // shows sits at the rail's right end — two figures in one
                  // shape, whatever the numbers are, because nothing
                  // craftable is a fact about the bag and not a
                  // disappointment to soften.
                  _CategoryRail(
                    selected: _category,
                    onSelect: (CraftCategory? c) =>
                        setState(() => _category = c),
                    census: '$ready craftable · ${shown.length} known',
                    censusLit: ready > 0,
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
                    const SizedBox(height: StrideSpace.rhythmHero),
                    _RecipeBook(locked: locked, onOpen: _openSheet),
                  ],
                ],
              ),
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
              // never gave anything. Since EPO03 it sits in the kit's own
              // plinth well rather than a rounded recess, and a finished
              // craft presses its impression onto it (`DIR-06` §5).
              KitPlate.well(
                frame: KitFrame.slotWell,
                contentWidth: 96,
                contentHeight: 96,
                child: _MadeStamp(
                  token: summaryHere ? craft.lastReport : null,
                  child: PixelAsset.item(
                    PixelIcons.recipeIconFor(recipe.id, recipe.outputItem),
                    scale: 2,
                  ),
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
                    const SizedBox(height: StrideSpace.s6),
                    // The one readiness sentence, on the folio (`DIR-06` §4).
                    AdaptiveText(
                      _readinessLine(recipe),
                      style: StrideType.sub,
                      color: recipe.canCraft
                          ? StrideColors.positiveReady
                          : StrideColors.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              _PursuitRibbon(recipe: recipe, enabled: !controller.busy),
            ],
          ),
          const SizedBox(height: StrideSpace.rhythmRow),

          _IngredientTray(recipe: recipe),

          const SizedBox(height: StrideSpace.rhythmRow),
          if (activeHere)
            _ActiveCraftPanel(recipe: recipe)
          else ...<Widget>[
            if (recipe.canCraft && maxCount > 1) ...<Widget>[
              _QuantityStepper(
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
                      // The commit sound beside the pulse (QUEUE_03 §8).
                      AudioEvents.commit(AudioScope.read(context));
                      CraftScope.read(context).start(recipe, count);
                    },
            ),
            // The Pursuit hook is the bookmark on this folio's top edge now
            // (`DIR-06` §7) — one primary action per screen, and a second
            // full-width button was saying the two were comparable.
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

/// The impression a finished craft presses onto the output well
/// (`DIR-06` §5).
///
/// 200 ms, once per completion, over the thing that was made — the physical
/// beat the bench owes the player at the moment the work lands, beside the
/// `ActivityResultCard` that says what it was. Reduce Motion holds the stamp
/// still rather than removing it: the mark is information, the press is the
/// decoration.
class _MadeStamp extends StatefulWidget {
  const _MadeStamp({required this.token, required this.child});

  /// The completion this stamp belongs to. A new non-null token presses;
  /// null means nothing has just been made.
  final Object? token;

  final Widget child;

  @override
  State<_MadeStamp> createState() => _MadeStampState();
}

class _MadeStampState extends State<_MadeStamp>
    with SingleTickerProviderStateMixin {
  /// Created eagerly, never lazily: a `late final` controller that the
  /// build never touched would be **constructed inside dispose()**, which
  /// looks up a deactivated element and throws. The stamp is often never
  /// pressed (its row has not landed), so that path is the common one.
  late final AnimationController _press;
  Object? _pressed;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.token == null || widget.token == _pressed) return;
    _pressed = widget.token;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _press.value = 1;
    } else {
      _press.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final CraftMark? art = CraftArt.stampMade;
    if (art == null || widget.token == null) return widget.child;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        widget.child,
        AnimatedBuilder(
          animation: _press,
          builder: (BuildContext context, Widget? mark) => Opacity(
            opacity: _press.value,
            child: Transform.scale(
              // Down onto the page, never up off it.
              scale: 1.4 - (0.4 * _press.value),
              child: mark,
            ),
          ),
          child: SizedBox(
            width: CraftArt.stamp,
            height: CraftArt.stamp,
            child: PixelAsset(
              assetPath: art.assetPath,
              nativeWidth: art.nativeWidth,
              nativeHeight: art.nativeHeight,
              scale: art.scale,
            ),
          ),
        ),
      ],
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
  static const double _slot = 64;

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
                  Stack(
                    children: <Widget>[
                      Opacity(
                        opacity: line.satisfied ? 1 : 0.55,
                        child: KitPlate.well(
                          frame: KitFrame.slotWell,
                          contentWidth: 48,
                          contentHeight: 48,
                          child: PixelAsset.item(PixelIcons.itemFor(line.item)),
                        ),
                      ),
                      // The shortfall cartouche (`DIR-06` §4): a slot that
                      // cannot pay says how far it is short, on the slot,
                      // instead of leaving the folio's one sentence to
                      // enumerate every material.
                      if (!line.satisfied)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            color: StrideColors.surfaceGround,
                            child: Text(
                              '−${line.shortfall}',
                              style: StrideType.micro.copyWith(
                                color: StrideColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
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
  });

  final List<RecipeOption> recipes;
  final ValueChanged<RecipeOption> onOpen;

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
    // One grammar, screen-wide (`DIR-06` §4).
    final String state = _readinessLine(recipe);

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

// ----------------------------------------------------------- the recipe book

/// The locked half of the workshop, as a **book** rather than a ledger.
///
/// ## The verdict this answers
///
/// The owner's EPO03 read: the screen "is improved but still not premium
/// enough", and its lower half "must not devolve into '1 more at Cooking 5 /
/// 1 more at Cooking 6'. Locked content should feel like progression, not
/// spreadsheet rows."
///
/// The FMPO02 ledger was a real improvement over twenty identical cards and
/// was still, structurally, a spreadsheet: one grey row per gate, each saying
/// the same sentence with a different numeral, sorted by that numeral. Every
/// row restated the gate, so the gate — the only interesting fact — was said
/// eleven times and read as debt.
///
/// ## What replaces it (`DIR-06` §6)
///
/// A book of **chapters**. Locked recipes group by trade into level bands of
/// three (1–3, 4–6, 7–9, 10+); each band is a chapter that **opens once**
/// with an illustrated tier header carrying its skill, its range and its one
/// "Opens at Cooking 4". Beneath the header the chapter's recipes are sealed
/// pages: the output drawn as an **ink silhouette** (a `ColorFilter` over the
/// icon the screen already ships — zero new art), a wax seal stamped with the
/// level the page asks for, and the name in rarity ink. **No row says a
/// gate.** The gate belongs to the chapter.
///
/// The first chapter above the player is **lit** — full-value header, warm
/// seals — and later chapters recede, so the book reads as a road with a next
/// step on it rather than a list of refusals. Contract-gated recipes close
/// the book as "Unwritten pages": they are not a level away from anything and
/// pretending otherwise would be the ledger's mistake in a nicer frame.
///
/// No lock, padlock or keyhole appears anywhere (`ART-02` §5), and the
/// recipe's own reason sentence is still the only statement of why — it lives
/// in the sheet a page opens, unchanged.
class _RecipeBook extends StatelessWidget {
  const _RecipeBook({required this.locked, required this.onOpen});

  final List<RecipeOption> locked;
  final ValueChanged<RecipeOption> onOpen;

  /// The band a level belongs to: three levels to a chapter, and everything
  /// from 10 up in the last one. Three is the figure that makes a chapter a
  /// page-worth rather than a scroll, and it is the same span the skills
  /// journey already groups by.
  static int bandStart(int level) => level >= 10 ? 10 : ((level - 1) ~/ 3) * 3 + 1;

  static String bandLabel(int start) =>
      start >= 10 ? 'LEVELS 10+' : 'LEVELS $start–${start + 2}';

  @override
  Widget build(BuildContext context) {
    // Chapters, keyed by trade and band. A gated recipe has no level to
    // stand on and goes to the unwritten pages at the end.
    final Map<String, List<RecipeOption>> chapters =
        <String, List<RecipeOption>>{};
    final List<RecipeOption> unwritten = <RecipeOption>[];
    for (final RecipeOption r in locked) {
      if (r.band == ReadinessBand.gated) {
        unwritten.add(r);
        continue;
      }
      chapters
          .putIfAbsent(
            '${r.skillName}|${bandStart(r.requiredLevel)}',
            () => <RecipeOption>[],
          )
          .add(r);
    }

    final List<String> order = chapters.keys.toList()
      ..sort((String a, String b) {
        final int level = int.parse(a.split('|')[1])
            .compareTo(int.parse(b.split('|')[1]));
        return level != 0 ? level : a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(
          label: 'The recipe book',
          trailing: Text(
            '${locked.length}',
            style: StrideType.microLabel.copyWith(
              color: StrideColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: StrideSpace.rhythmRow),
        for (int i = 0; i < order.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: StrideSpace.rhythmHero),
          _Chapter(
            // The first chapter above the player is the next thing that
            // happens to them, and reads that way.
            lit: i == 0,
            skill: order[i].split('|')[0],
            // The gate, said once, in the header — never on a page.
            gate: 'Opens at ${order[i].split('|')[0]} '
                '${chapters[order[i]]!.map((RecipeOption r) => r.requiredLevel).reduce((int a, int b) => a < b ? a : b)}',
            range: bandLabel(int.parse(order[i].split('|')[1])),
            recipes: chapters[order[i]]!,
            onOpen: onOpen,
          ),
        ],
        if (unwritten.isNotEmpty) ...<Widget>[
          const SizedBox(height: StrideSpace.rhythmHero),
          _Chapter(
            lit: false,
            skill: 'taught',
            gate: 'Learned elsewhere',
            range: 'UNWRITTEN PAGES',
            recipes: unwritten,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

/// One chapter: an illustrated tier header, then its sealed pages.
class _Chapter extends StatelessWidget {
  const _Chapter({
    required this.lit,
    required this.skill,
    required this.gate,
    required this.range,
    required this.recipes,
    required this.onOpen,
  });

  /// Whether this is the first chapter above the player. A lit chapter is at
  /// full value; the ones after it recede, which is what makes the book read
  /// as a road with a next step rather than a wall of refusals.
  final bool lit;

  final String skill;
  final String gate;
  final String range;
  final List<RecipeOption> recipes;
  final ValueChanged<RecipeOption> onOpen;

  /// How far a chapter behind the next one recedes. Not a disabled state —
  /// the pages stay tappable and their names stay legible; the chapter is
  /// simply further down the road.
  static const double _recede = 0.62;

  @override
  Widget build(BuildContext context) {
    final List<RecipeOption> sorted = recipes.toList()
      ..sort((RecipeOption a, RecipeOption b) {
        final int level = a.requiredLevel.compareTo(b.requiredLevel);
        return level != 0 ? level : a.displayName.compareTo(b.displayName);
      });
    final int rows = (sorted.length + 1) ~/ 2;

    return Opacity(
      opacity: lit ? 1 : _recede,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TierHeader(skill: skill, range: range, gate: gate, lit: lit),
          const SizedBox(height: StrideSpace.rhythmRow),
          for (int row = 0; row < rows; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: StrideSpace.rhythmRow),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _SealedPage(
                      recipe: sorted[row * 2],
                      lit: lit,
                      onTap: () => onOpen(sorted[row * 2]),
                    ),
                  ),
                  const SizedBox(width: StrideSpace.rhythmRow),
                  Expanded(
                    child: row * 2 + 1 < sorted.length
                        ? _SealedPage(
                            recipe: sorted[row * 2 + 1],
                            lit: lit,
                            onTap: () => onOpen(sorted[row * 2 + 1]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A chapter's opening: the illustrated divider, the trade, the range, and
/// the gate — **once**.
class _TierHeader extends StatelessWidget {
  const _TierHeader({
    required this.skill,
    required this.range,
    required this.gate,
    required this.lit,
  });

  final String skill;
  final String range;
  final String gate;
  final bool lit;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: '$skill, $range. $gate',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The kit's illustrated divider, drawn once and clipped — a chapter
        // opening, not a repeated rule (`KIT_CONTRACT` §8).
        Align(
          alignment: Alignment.centerLeft,
          child: ClipRect(
            child: SizedBox(
              height: KitMarks.sizeFor(KitMark.ruleOrnateA).height,
              child: const KitOrnament(mark: KitMark.ruleOrnateA),
            ),
          ),
        ),
        const SizedBox(height: StrideSpace.s6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: AdaptiveText(
                // The unwritten chapter has no trade to name — it is the
                // pages nobody has written for you yet, and "TAUGHT ·" in
                // front of that is the ledger's habit of labelling a thing
                // twice.
                skill == 'taught'
                    ? range
                    : '${skill.toUpperCase()} · $range',
                style: StrideType.cardTitle,
                color: lit
                    ? StrideColors.textPrimary
                    : StrideColors.textSecondary,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            AdaptiveText(
              gate,
              style: StrideType.micro,
              color: lit
                  ? StrideColors.textSecondary
                  : StrideColors.textMuted,
            ),
          ],
        ),
      ],
    ),
  );
}

/// One locked recipe, as a sealed page.
///
/// The output is an **ink silhouette** — the icon the screen already ships,
/// pushed through a `ColorFilter` so it reads as a drawing on a page rather
/// than as a dimmed copy of the item. Zero new art, and it is honest: the
/// player has not made this thing, so they have not seen it.
///
/// The wax seal carries the level the page asks for, set in type over a blank
/// seal (L-18: no numeral is ever baked into a raster). The name is in rarity
/// ink, because rank is identity and not availability (§20).
class _SealedPage extends StatelessWidget {
  const _SealedPage({
    required this.recipe,
    required this.lit,
    required this.onTap,
  });

  final RecipeOption recipe;
  final bool lit;
  final VoidCallback onTap;

  /// The silhouette's display size: 24 native at ×2, the same integer
  /// multiple every item icon on this screen already uses.
  static const double _silhouette = 48;

  /// The ink a sealed output is drawn in — the page's own line weight, warmer
  /// on the lit chapter than on the ones behind it.
  static Color _ink(bool lit) =>
      lit ? StrideColors.textSecondary : StrideColors.textMuted;

  /// The folded corner: the mark when the row has landed, the painted fold
  /// while it has not, at the same reserved size either way.
  static Widget _dogEar() {
    final CraftMark? m = CraftArt.dogEarMark;
    if (m == null) return const _PaintedDogEar();
    return PixelAsset(
      assetPath: m.assetPath,
      nativeWidth: m.nativeWidth,
      nativeHeight: m.nativeHeight,
      scale: m.scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget silhouette = ColorFiltered(
      // `srcATop` keeps the icon's own alpha — the shape survives, every
      // colour inside it becomes one ink.
      colorFilter: ColorFilter.mode(_ink(lit), BlendMode.srcATop),
      child: PixelAsset.item(
        PixelIcons.recipeIconFor(recipe.id, recipe.outputItem),
      ),
    );

    return Semantics(
      button: true,
      label: '${recipe.displayName}, sealed until '
          '${recipe.skillName} ${recipe.requiredLevel}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: KitPlate(
          frame: KitFrame.pageSealed,
          fill: StrideColors.surfaceCard,
          surface: PanelSurface.journalLeaf,
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: _silhouette,
                        height: _silhouette,
                        child: silhouette,
                      ),
                      const Spacer(),
                      _WaxSeal(
                        skill: recipe.isLocked ? 'taught' : recipe.skillName,
                        level: recipe.isLocked ? null : recipe.requiredLevel,
                        lit: lit,
                      ),
                    ],
                  ),
                  const SizedBox(height: StrideSpace.s6),
                  Text(
                    recipe.displayName,
                    style: StrideType.itemName.copyWith(
                      color: RarityStyle.inkOr(
                        recipe.outputRarity,
                        StrideColors.textPrimary,
                      ).withValues(alpha: lit ? 0.85 : 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // The dog-ear: the page's outer corner, folded. Lifted on the
              // lit chapter, flat behind it. Reserved either way.
              Positioned(
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: lit ? 1 : 0.5,
                  child: SizedBox(
                    width: CraftArt.dogEar,
                    height: CraftArt.dogEar,
                    child: _dogEar(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dog-ear's fallback: a folded triangle in the page's own inks, drawn
/// with the one weight the kit fallbacks use.
class _PaintedDogEar extends StatelessWidget {
  const _PaintedDogEar();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DogEarPainter(), size: Size.square(CraftArt.dogEar));
}

class _DogEarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path fold = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fold, Paint()..color = StrideColors.surfaceGround);
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height),
      Paint()
        ..color = StrideColors.separator
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DogEarPainter oldDelegate) => false;
}

/// A blank wax seal with the level it asks for set over it.
///
/// The seal is the only place on a sealed page that carries a number, and it
/// carries it in type — the raster is a blank seal by rule (L-18), so one
/// seal per trade serves every level that trade gates.
class _WaxSeal extends StatelessWidget {
  const _WaxSeal({required this.skill, required this.level, required this.lit});

  final String skill;

  /// The level stamped into the wax, or null for the taught seal — a recipe
  /// somebody has to show you has no number to give.
  final int? level;

  final bool lit;

  @override
  Widget build(BuildContext context) {
    final CraftMark? art = CraftArt.sealFor(skill);
    final Color wax = lit
        ? StrideColors.actionEdge
        : StrideColors.borderDefault;
    return SizedBox(
      width: CraftArt.seal,
      height: CraftArt.seal,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (art != null)
            Opacity(
              opacity: lit ? 1 : 0.7,
              child: PixelAsset(
                assetPath: art.assetPath,
                nativeWidth: art.nativeWidth,
                nativeHeight: art.nativeHeight,
                scale: art.scale,
              ),
            )
          else
            // The fallback seal: a pressed disc in the same two weights the
            // kit's plates use, at exactly the size the raster will take.
            Center(
              child: Container(
                width: CraftArt.seal - 12,
                height: CraftArt.seal - 12,
                decoration: BoxDecoration(
                  color: StrideColors.surfaceBlock,
                  shape: BoxShape.circle,
                  border: Border.all(color: wax, width: 2),
                ),
              ),
            ),
          Text(
            level == null ? '·' : '$level',
            style: StrideType.cardTitle.copyWith(
              color: lit
                  ? StrideColors.textPrimary
                  : StrideColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
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

/// The category rail: All plus the four categories, as **tabs on the bench's
/// lower edge** rather than as filled chips (`DIR-06` §3).
///
/// The chips were the fourth-named failure: category and quantity shared one
/// `_Chip`, so a filter and a batch size looked like the same kind of object
/// and both looked like pills. A rail is a different thing from a stepper by
/// construction — a glyph, a written label, and a brass underline pin on the
/// one you are standing in. No fill, no border, no radius.
///
/// The glyphs are `CraftArt` rows and are absent until they land; the written
/// label is present either way, so the rail is legible today and gains its
/// pictures later without moving (`CraftArt`'s doctrine).
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.selected,
    required this.onSelect,
    required this.census,
    required this.censusLit,
  });

  final CraftCategory? selected;
  final ValueChanged<CraftCategory?> onSelect;

  /// "1 craftable · 10 known", at the rail's right end.
  final String census;
  final bool censusLit;

  /// The rail's tokens, in the order it draws them. `all` first because it is
  /// the state the screen opens in.
  static const List<(String token, String label, CraftCategory? category)>
  _tabs = <(String, String, CraftCategory?)>[
    ('all', 'All', null),
    ('materials', 'Materials', CraftCategory.materials),
    ('food', 'Food', CraftCategory.food),
    ('gear', 'Gear', CraftCategory.gear),
    ('tools', 'Tools', CraftCategory.tools),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final (String token, String label, CraftCategory? c) in _tabs)
            Expanded(
              child: _CategoryTab(
                token: token,
                label: label,
                selected: selected == c,
                onTap: () => onSelect(c),
              ),
            ),
        ],
      ),
      const SizedBox(height: StrideSpace.s6),
      Align(
        alignment: Alignment.centerRight,
        child: AdaptiveText(
          census,
          style: StrideType.micro,
          color: censusLit
              ? StrideColors.textSecondary
              : StrideColors.textMuted,
        ),
      ),
    ],
  );
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.token,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String token;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The pin under the chosen tab. Brass, because selection is a chosen thing
  /// and never a walking quantity (L-16).
  static const double pin = 2;

  @override
  Widget build(BuildContext context) {
    final CraftMark? glyph = CraftArt.categoryFor(token);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: StrideGeometry.buttonHitFloor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // Reserved whether or not the glyph has landed, so the rail
              // does not grow the day the art arrives.
              SizedBox(
                width: CraftArt.categoryGlyph,
                height: CraftArt.categoryGlyph / 2,
                child: glyph == null
                    ? null
                    : Center(
                        child: Opacity(
                          opacity: selected ? 1 : 0.6,
                          child: PixelAsset(
                            assetPath: glyph.assetPath,
                            nativeWidth: glyph.nativeWidth,
                            nativeHeight: glyph.nativeHeight,
                            scale: glyph.scale,
                          ),
                        ),
                      ),
              ),
              AdaptiveText(
                label,
                style: StrideType.microLabel,
                textAlign: TextAlign.center,
                color: selected
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
              const SizedBox(height: StrideSpace.s4),
              Container(
                height: pin,
                color: selected
                    ? StrideColors.actionEdge
                    : StrideColors.separator,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              const SizedBox(width: StrideSpace.s8),
              // The same bookmark the folio wears (`DIR-06` §7), holding the
              // same verbatim call site.
              _PursuitRibbon(recipe: recipe, enabled: !controller.busy),
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
              _QuantityStepper(
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
                      // The commit sound beside the pulse (QUEUE_03 §8).
                      AudioEvents.commit(AudioScope.read(context));
                      CraftScope.read(context).start(recipe, count);
                      widget.onCraftStarted?.call();
                    },
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

/// The batch size, as a **stepper** rather than as three more chips
/// (`DIR-06` §4).
///
/// `×1 / ×5 / ×10` was the same `_Chip` the category filter used, so quantity
/// and category read as one kind of control; and it could not say ×3, which
/// is the count a bag full of two ores actually funds. A stepper says every
/// number, reaches the maximum in one tap, and cannot be mistaken for a
/// filter.
///
/// − and + are 44 dp hit targets with press-and-hold repeat; the count is set
/// in the display face between them; MAX jumps to what the held ingredients
/// fund. The value is clamped to `craftableCount` by the caller and the
/// engine re-validates on dispatch either way (`RULES.md` E-2) — nothing here
/// can request a craft the bag cannot pay for.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.count,
    required this.maxCount,
    required this.onChanged,
  });

  final int count;
  final int maxCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Batch size, $count of $maxCount',
    child: Row(
      children: <Widget>[
        _StepperKey(
          glyph: '−',
          semanticLabel: 'One fewer',
          enabled: count > 1,
          onTap: () => onChanged(count - 1),
        ),
        Expanded(
          child: Center(
            child: AdaptiveText(
              '×$count',
              style: StrideType.cardTitle,
              color: StrideColors.textPrimary,
            ),
          ),
        ),
        _StepperKey(
          glyph: '+',
          semanticLabel: 'One more',
          enabled: count < maxCount,
          onTap: () => onChanged(count + 1),
        ),
        const SizedBox(width: StrideSpace.s8),
        _StepperKey(
          glyph: 'MAX',
          semanticLabel: 'All $maxCount',
          wide: true,
          enabled: count < maxCount,
          onTap: () => onChanged(maxCount),
        ),
      ],
    ),
  );
}

/// One key of the stepper: a kit plate, pressed by touch, repeating on hold.
class _StepperKey extends StatefulWidget {
  const _StepperKey({
    required this.glyph,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    this.wide = false,
  });

  final String glyph;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;
  final bool wide;

  /// The platform floor, and the figure `DIR-06`'s success criterion 6 names.
  static const double edge = 44;

  @override
  State<_StepperKey> createState() => _StepperKeyState();
}

class _StepperKeyState extends State<_StepperKey> {
  Timer? _repeat;
  bool _down = false;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    setState(() => _down = true);
    widget.onTap();
    // A hold walks the count up; the caller clamps, so a hold that runs past
    // the maximum simply stops moving.
    _repeat = Timer.periodic(const Duration(milliseconds: 140), (Timer _) {
      if (!widget.enabled) return;
      widget.onTap();
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    if (mounted) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: widget.semanticLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        child: KitPlate(
          frame: KitFrame.btnPlateV2,
          // Pressed keys sink; the rest stand off the page. The same lit /
          // shadowed rim the kit's own plates use.
          raised: !_down,
          fill: StrideColors.surfaceBlock,
          padding: EdgeInsets.zero,
          width: widget.wide ? _StepperKey.edge * 1.6 : _StepperKey.edge,
          height: _StepperKey.edge,
          child: Center(
            child: Text(
              widget.glyph,
              style: StrideType.microLabel.copyWith(
                color: StrideColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The Pursuit hook as a **bookmark** rather than a second full-width button
/// (`DIR-06` §7).
///
/// A folio with two stacked buttons says the two are comparable, and they are
/// not: one makes the thing, the other remembers you want it. A ribbon
/// hanging off the folio's top edge is a different kind of object, costs no
/// vertical rhythm, and reads as marking a page.
///
/// The call site is verbatim and unmoved:
/// `SessionScope.read(context).trackGoalPursuit(recipe.outputItem)`.
class _PursuitRibbon extends StatefulWidget {
  const _PursuitRibbon({required this.recipe, required this.enabled});

  final RecipeOption recipe;
  final bool enabled;

  @override
  State<_PursuitRibbon> createState() => _PursuitRibbonState();
}

class _PursuitRibbonState extends State<_PursuitRibbon> {
  /// The subject this ribbon has been dropped for. Presentation memory of
  /// nothing durable — the pursuit itself lives in the session.
  ContentId? _tracked;

  @override
  Widget build(BuildContext context) {
    final bool tracked = _tracked == widget.recipe.outputItem;
    final CraftMark? art = CraftArt.ribbonPursuit;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: tracked ? 'Tracked as pursuit' : 'Track as Pursuit',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !widget.enabled
            ? null
            : () async {
                await SessionScope.read(
                  context,
                ).trackGoalPursuit(widget.recipe.outputItem);
                if (mounted) {
                  setState(() => _tracked = widget.recipe.outputItem);
                }
              },
        child: Padding(
          // The drop: a tracked ribbon settles 4 dp lower, as a bookmark
          // pushed into the page does.
          padding: EdgeInsets.only(top: tracked ? 4 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: CraftArt.ribbon.width,
                height: CraftArt.ribbon.height,
                child: art == null
                    ? CustomPaint(painter: _RibbonPainter(lit: tracked))
                    : Opacity(
                        opacity: tracked ? 1 : 0.8,
                        child: PixelAsset(
                          assetPath: art.assetPath,
                          nativeWidth: art.nativeWidth,
                          nativeHeight: art.nativeHeight,
                          scale: art.scale,
                        ),
                      ),
              ),
              const SizedBox(height: StrideSpace.s2),
              AdaptiveText(
                tracked ? 'Tracked' : 'Track',
                style: StrideType.micro,
                color: tracked
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ribbon's fallback: a swallowtail in the page's own inks, at exactly
/// the size the raster will take.
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.lit});

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final Path ribbon = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 8)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = lit ? StrideColors.actionEdge : StrideColors.surfaceRaised,
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = StrideColors.actionEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => oldDelegate.lit != lit;
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
    // The Traveler works in what he equipped (FMPO02, FINAL-03 blocker 1:
    // Craft drew the base body while every other stage wore the armour).
    // The armoured craft loop is the same seven frames re-dressed, so its
    // ping-pong, canvas and strike index are the base loop's; only the
    // frames, the footprint and the rest pose change.
    final EquipmentVisualState visual =
        SessionScope.of(context).session.equipmentVisualState;
    final GatherStrip? dressed = TravelerArt.craftLoopFor(skill, visual);
    final List<String>? loop =
        dressed?.frames ??
        (AmbientAssets.hasActivityLoop(skill)
            ? AmbientAssets.activityLoopFor(skill)
            : null);
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
                        scenes: TravelerArt.idleScenesFor(
                          visual,
                          base: AmbientAssets.scenes,
                        ),
                        restFrame:
                            TravelerArt.restFrameFor(visual) ??
                            AmbientAssets.restFrame,
                        restFootprint:
                            TravelerArt.restFootprintFor(visual) ??
                            AmbientAssets.restFootprint,
                        prop: AmbientAssets.stationFor(station),
                        activityFrames: loop,
                        activityFootprint:
                            dressed?.footprint ??
                            AmbientAssets.activityFootprintFor(skill),
                        activityCanvas:
                            dressed?.canvasWidth ??
                            AmbientAssets.activityCanvasFor(skill),
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
