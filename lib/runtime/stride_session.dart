/// The wire between the platform adapter, the engine, and the save.
///
/// ===========================================================================
/// What was missing, and why it is one object
/// ===========================================================================
///
/// Before S-01A the two halves of step ingestion both existed and were not
/// joined. `PlatformStepSource` produced a `SyncFetch`; `GameEngine` consumed a
/// `ReconcileStepSync`; `SaveRepository` committed a batch. Nothing called all
/// three in order, so a real walk could reach the boundary and stop there.
///
/// This is that call, and it is deliberately one object rather than three
/// helpers, because the ordering between them is the whole safety argument:
///
///   1. fetch a page                → a candidate cursor, never a durable one
///   2. reconcile it                → grants, and `StepCheckpointAuthorized` last
///   3. commit the batch            → the journal append is the commit point
///   4. only now is the cursor durable, and only now may the next page be asked for
///
/// Splitting it across call sites is how an earlier version of this project
/// ended up authorizing a cursor that the ledger never recorded. Keeping the
/// loop here means there is exactly one place where the order can be wrong, and
/// exactly one place to assert it.
///
/// ## Foreground only
///
/// Every method here runs because the player, in the foreground, pressed
/// something. There is no timer, no `WorkManager`, no isolate, no platform
/// callback, and no subscription. S-01A is foreground synchronization; S-01B is
/// blocked on a real persistence coordinator (`DECISIONS/0013`, `0014`).
///
/// ## One writer
///
/// The repository is the one `bootstrapStride` built. This file constructs no
/// store, no layout, and no lock — `Scripts/check-single-writer.sh` enumerates
/// the approved construction sites and this is not one of them, deliberately.
library;

import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'atlas_layout.dart';
import 'runtime_bootstrap.dart';

export 'atlas_layout.dart'
    show
        AtlasLandmark,
        AtlasLayout,
        AtlasLocation,
        AtlasOverlay,
        AtlasProp,
        AtlasRoute,
        AtlasRumorSpot,
        AtlasTile;

/// How far a sync got, in terms nothing outside this file has to interpret.
enum SyncStatus {
  /// Steps were read and reconciled. [SyncReport.newlyGranted] may still be
  /// zero — a repeated sync of the same walk grants nothing, and that is the
  /// system working rather than failing.
  reconciled,

  /// The provider said nothing had changed since the cursor.
  noChange,

  /// The platform could not answer. [SyncReport.unavailableReason] says why.
  unavailable,

  /// The adapter's page contradicted itself and was refused before it could
  /// touch the ledger.
  contractViolation,

  /// The batch reconciled but could not be made durable. **The in-memory state
  /// has advanced and the durable state has not**, so the session is marked
  /// stale and refuses further commands until [reload].
  commitRefused,

  /// The health source has not been opened, because the launch had no identity
  /// to key origins with. Not retryable.
  keyingUnconfigured,
}

/// What one sync did. Every field is safe to render.
///
/// **There is no origin key, bucket boundary, cursor byte, salt, or package
/// name on this type, and there must never be one.** It is built to be shown on
/// a screen and written to a log, and a diagnostic that carries an identifier is
/// a diagnostic that leaks one the first time somebody pastes it into a bug
/// report.
final class SyncReport {
  const SyncReport({
    required this.status,
    required this.pages,
    required this.originCount,
    required this.bucketCount,
    required this.observedSteps,
    required this.newlyGranted,
    required this.faults,
    required this.deliveryKind,
    this.unavailableReason,
    this.intervalStartMillis,
    this.intervalEndMillis,
    this.commitDetail,
    this.rejection,
    this.authorization,
  });

  const SyncReport.unavailable(ProviderUnavailableReason reason)
    : this(
        status: SyncStatus.unavailable,
        pages: 0,
        originCount: 0,
        bucketCount: 0,
        observedSteps: 0,
        newlyGranted: 0,
        faults: const <SyncFault>[],
        deliveryKind: 'unavailable',
        unavailableReason: reason,
      );

  final SyncStatus status;

  /// How many pages were drained. More than one is ordinary, not a warning.
  final int pages;

  /// **Counts, not identities.** How many distinct pseudonymous origins and how
  /// many UTC buckets appeared across the whole read. The harness is entitled
  /// to know that four sources contributed; it is not entitled to know which.
  final int originCount;
  final int bucketCount;

  /// The sum of the absolute figures delivered. Not a grant — a restated bucket
  /// counts here every time it is restated, which is exactly why it is shown
  /// beside [newlyGranted] rather than instead of it.
  final int observedSteps;

  /// Energy actually credited. Zero on a repeat sync of the same walk.
  final int newlyGranted;

  /// Adapter faults the bridge corrected or refused. Categories only.
  final List<SyncFault> faults;

  /// `incremental`, `noChange`, `recovery`, `unavailable`, `contractViolation`.
  final String deliveryKind;

  final ProviderUnavailableReason? unavailableReason;

  /// The interval the adapter vouched for, when it asserted one at all. Null
  /// under [PartialDelivery], where there is nothing to report and saying
  /// "0–0" would look like an answer.
  final int? intervalStartMillis;
  final int? intervalEndMillis;

  /// Why a commit refused, as the enum name. Never a path.
  final String? commitDetail;

  /// Why the engine refused the batch, as the stable rejection code.
  final String? rejection;

  /// What the platform said when the session asked for read access before
  /// this sync — or null when it did not ask (a source-less session, or a
  /// report built before the request). Read alongside [status]: on iOS a
  /// denied read comes back as an *empty* result, so a "no new steps" report
  /// with a non-granted authorization is not the same fact as one with a
  /// granted one, and a UI must not render them the same way.
  final HealthAuthorization? authorization;

  SyncReport withAuthorization(HealthAuthorization? value) => SyncReport(
    status: status,
    pages: pages,
    originCount: originCount,
    bucketCount: bucketCount,
    observedSteps: observedSteps,
    newlyGranted: newlyGranted,
    faults: faults,
    deliveryKind: deliveryKind,
    unavailableReason: unavailableReason,
    intervalStartMillis: intervalStartMillis,
    intervalEndMillis: intervalEndMillis,
    commitDetail: commitDetail,
    rejection: rejection,
    authorization: value,
  );
}

/// One line of the player's inventory, ready to render.
final class InventoryEntry {
  const InventoryEntry({
    required this.id,
    required this.displayName,
    required this.category,
    required this.rarity,
    required this.count,
  });

  final ContentId id;
  final String displayName;

  /// Null when the content pack has no definition for [id] — which is a content
  /// problem, not a rendering one, so it is reported rather than defaulted.
  final ItemCategory? category;

  /// The item's authored rarity, or null on the same terms as [category].
  ///
  /// **Nullable here and required in content.** `ItemDefinition.rarity` cannot
  /// be absent — the loader refuses an item without one — so a null in this
  /// projection means only that the *definition* is missing, which is the same
  /// content fault [category] reports and is never a rarity the author chose.
  /// A default would turn a missing definition into a plausible grey label.
  final Rarity? rarity;

  /// Always greater than zero.
  final int count;
}

/// One item in a reward, drop preview, or equipped line, with its rarity.
///
/// Three projections needed the same three fields — an id to look anything
/// else up by, a name to show, and a rank to colour by — so they share one
/// type rather than each growing their own (`DECISIONS/0021` §4: the UI has
/// **one** rarity style table, and one shape for it to read).
final class DropPreview {
  const DropPreview({
    required this.id,
    required this.name,
    required this.rarity,
    this.chancePercent = 0,
    this.signature = false,
    this.revealed = true,
  });

  final ContentId id;
  final String name;

  /// Null only when the content pack has no definition for [id].
  final Rarity? rarity;

  /// The authored whole-percent drop chance, exactly as the engine rolls it
  /// (Fable V2 Iteration 02, loot intelligence). What the card may *say*
  /// about it is graduated by knowledge tier in the presentation — a
  /// frequency word at Studied, the figure at Known — but the projection
  /// always carries the true number; the tiering is display, never data.
  final int chancePercent;

  /// A signature rare drop (`DECISIONS/0023` §5).
  final bool signature;

  /// False while a signature drop's existence is still concealed — the enemy
  /// is not yet Known. The card renders an unnamed "???" row; the roll is
  /// unchanged either way.
  final bool revealed;
}

/// One line of a victory reward: what dropped, how much, and its rarity.
final class RewardLine {
  const RewardLine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.rarity,
  });

  final ContentId id;
  final String name;

  /// As awarded, off the `EncounterWon` event — never recomputed here.
  final int quantity;

  /// Null only when the content pack has no definition for [id].
  final Rarity? rarity;
}

/// One occupied equipment slot, for the Character and Inventory screens.
///
/// Read straight off `Equipment.bySlot` — the same map `GameEngine` consults
/// when a gather asks for a tool or a fight reads the weapon — so the line the
/// screen shows is the line the rules use. Empty slots are simply absent;
/// a screen that wants to show "nothing equipped" knows its own slot list.
final class EquippedSummary {
  const EquippedSummary({
    required this.slot,
    required this.itemId,
    required this.displayName,
    required this.rarity,
    required this.power,
  });

  final EquipmentSlot slot;
  final ContentId itemId;
  final String displayName;

  /// Null only when the content pack has no definition for [itemId].
  final Rarity? rarity;

  /// The item's contribution: attack for a weapon, defence for armour, and
  /// nothing at all for a tool, which never counts in a fight.
  final int power;
}

/// One equipped slot's **visual facts**
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5): what the presentation
/// layer's art tables need to choose a Traveler strip, and nothing else.
/// String-keyed (`ContentId.value`, `ToolKind.name`) on the same deliberate
/// boundary `AmbientAssets.activityLoopFor` keeps — the art tables name no
/// `stride_core` type.
final class EquippedVisualFact {
  const EquippedVisualFact({
    required this.itemId,
    required this.tier,
    required this.toolKind,
  });

  final String itemId;
  final int tier;
  final String toolKind;

  @override
  bool operator ==(Object other) =>
      other is EquippedVisualFact &&
      other.itemId == itemId &&
      other.tier == tier &&
      other.toolKind == toolKind;

  @override
  int get hashCode => Object.hash(itemId, tier, toolKind);
}

/// The whole loadout as visual facts — the value `TravelerArt` resolves
/// strips against. Value-equal, so a surface can cheaply see that an
/// unchanged loadout selects unchanged art. A null slot is empty.
final class EquipmentVisualState {
  const EquipmentVisualState({this.weapon, this.armor, this.tool});

  final EquippedVisualFact? weapon;
  final EquippedVisualFact? armor;
  final EquippedVisualFact? tool;

  /// The empty loadout — also every surface's safe default.
  static const EquipmentVisualState none = EquipmentVisualState();

  @override
  bool operator ==(Object other) =>
      other is EquipmentVisualState &&
      other.weapon == weapon &&
      other.armor == armor &&
      other.tool == tool;

  @override
  int get hashCode => Object.hash(weapon, armor, tool);
}

/// How a piece of equipment compares with what is worn in its slot.
///
/// [toolSwap] is a tool of another profession going into the one tool
/// slot — an axe over a pickaxe. It is neither an upgrade nor a sidegrade:
/// the two do different work, and the only honest word is "swap".
enum GearVerdict {
  upgrade,
  downgrade,
  sidegrade,
  firstInSlot,
  equipped,
  toolSwap,
}

/// The profession a tool kind serves, in the player's word.
String toolProfessionOf(ToolKind kind) => switch (kind) {
  ToolKind.axe => 'Woodcutting',
  ToolKind.pickaxe => 'Mining',
  ToolKind.none => 'Utility',
};

/// What a piece of equipment does, for the Inventory and Craft screens
/// (PLAYABLE_POLISH_01 §6): its one stat, its passives, and how it stands
/// against the item in its slot today.
///
/// Every figure is content — `power`, `frostGuard`, the two yield
/// percentages, the tool kind and tier — read through the same registry the
/// engine reads, against the same `Equipment.bySlot` it consults. Nothing
/// here is computed by the screen and nothing here is persisted
/// (`RULES.md` E-2, E-5).
final class GearStats {
  const GearStats({
    required this.item,
    required this.slot,
    required this.statName,
    required this.statShort,
    required this.power,
    required this.tier,
    required this.toolKind,
    required this.passives,
    required this.wornName,
    required this.wornPower,
    required this.verdict,
    this.wornToolKind,
    this.wornTier = 0,
    this.tradeOffLines = const <String>[],
    this.upgradeLine,
  });

  final ContentId item;
  final EquipmentSlot slot;

  /// For a tool: the worn tool's kind and tier, so the comparison can say
  /// `Bronze Pickaxe · Mining tool · Tier 1` rather than a power figure.
  final ToolKind? wornToolKind;
  final int wornTier;

  /// `Woodcutting` / `Mining` for a tool; null for weapons and armour.
  String? get profession =>
      slot == EquipmentSlot.tool ? toolProfessionOf(toolKind) : null;

  /// "Attack", "Defence", "Tool power".
  final String statName;

  /// "ATK", "DEF", "TOOL" — for a tile with no room for the word.
  final String statShort;
  final int power;
  final int tier;
  final ToolKind toolKind;

  /// The item's passives, one sentence each, in player words.
  final List<String> passives;

  /// The item in the slot today, or null when the slot is empty.
  final String? wornName;
  final int wornPower;
  final GearVerdict verdict;

  /// What equipping this piece gives up: the worn piece's passive sentences
  /// the candidate does not carry, verbatim from the same builder that
  /// wrote [passives] (`DECISIONS/0028` §6). Empty when nothing is lost,
  /// when the slot is empty, or when comparing a piece with itself.
  final List<String> tradeOffLines;

  /// The derived lineage's forward pointer — "Reforges into Waywarden's
  /// Tunic (DEF 5)" — from the same recipe edges the craft bench executes.
  /// Null for a piece nothing upgrades.
  final String? upgradeLine;

  /// `+2`, `−1`, `±0` against the slot — or null when nothing is worn.
  String? get deltaLabel {
    // A tool has no figure to compare (see [GearVerdict.toolSwap]).
    if (wornName == null || slot == EquipmentSlot.tool) return null;
    final int d = power - wornPower;
    if (d > 0) return '+$d';
    if (d < 0) return '−${-d}';
    return '±0';
  }

  /// The verdict in one word, for a label.
  String get verdictLabel => switch (verdict) {
    GearVerdict.upgrade => 'UPGRADE',
    GearVerdict.downgrade => 'DOWNGRADE',
    GearVerdict.sidegrade => 'SIDEGRADE',
    GearVerdict.firstInSlot => 'EMPTY SLOT',
    GearVerdict.equipped => 'EQUIPPED',
    GearVerdict.toolSwap => 'TOOL SWAP',
  };
}

/// One skill's standing, with its level already derived from the content curve.
/// One location, as the region map's legend needs it.
///
/// Carries no command and no route geometry. It is what the content pack knows
/// about a place, projected for display.
final class RegionPlace {
  const RegionPlace({
    required this.id,
    required this.displayName,
    required this.isCurrent,
    required this.isSafe,
    required this.isUnlocked,
    required this.stepCostFromHere,
    required this.resourceCount,
    required this.terrain,
    required this.kind,
  });

  final ContentId id;
  final String displayName;

  /// What kind of place this is, **derived** from content by
  /// `LocationKinds.kindFor` (`DECISIONS/0021` §5) — never authored, so the
  /// atlas cannot disagree with the enemies and nodes the pack actually
  /// places here.
  final LocationKind kind;

  /// Whether the player is standing here.
  final bool isCurrent;

  /// Whether defeat returns the player here (`DECISIONS/0003`).
  final bool isSafe;

  /// Whether the save records this place as unlocked.
  final bool isUnlocked;

  /// The step cost of the route from the player's location, or null when there
  /// is no direct connection.
  ///
  /// **A price since Phase 2.** It used to be a distance with nothing that could
  /// spend it; `TravelTo` now charges exactly this figure, profile-scaled.
  final int? stepCostFromHere;

  /// How many gatherable nodes the content pack places here.
  final int resourceCount;

  /// What kind of ground this is, for the place's identity line.
  final Terrain terrain;

  /// Whether a route runs here from where the player is standing.
  ///
  /// A hint for rendering, not the authority. `TravelTo` re-checks adjacency in
  /// the engine, and the engine's answer is the one that counts.
  bool get isAdjacent => stepCostFromHere != null;
}

/// Everything the atlas inspector says about one place.
///
/// A separate projection from [RegionPlace], deliberately. The legend needs
/// one row per location and is built for every place at once; the inspector
/// needs the *contents* of one place — its gathering, its enemies — and
/// building that for five locations to render one of them would put four
/// unused walks of the content graph behind every map frame.
///
/// Everything here is read from content and from the committed state. No row
/// carries an affordance: `GatherResource` and `StartEncounter` re-check every
/// one of these on execute, and the engine's answer is the one that counts
/// (`RULES.md` E-2).
final class PlaceDetails {
  const PlaceDetails({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.isSafe,
    required this.terrain,
    required this.isCurrent,
    required this.gatherSites,
    required this.encounters,
  });

  final ContentId id;
  final String displayName;

  /// Derived by `LocationKinds.kindFor` (`DECISIONS/0021` §5).
  final LocationKind kind;

  /// Whether defeat returns the player here (`DECISIONS/0003`).
  final bool isSafe;
  final Terrain terrain;

  /// Whether the player is standing here. What makes [encounters]'
  /// `remainingThisVisit` a live figure rather than the authored maximum.
  final bool isCurrent;

  final List<GatherSiteLine> gatherSites;
  final List<PlaceEncounterLine> encounters;
}

/// One gatherable node at a place, with what it asks of the player.
final class GatherSiteLine {
  const GatherSiteLine({
    required this.id,
    required this.name,
    required this.skillName,
    required this.requiredLevel,
    required this.toolWord,
  });

  final ContentId id;
  final String name;

  /// The skill's display name, not its id — the inspector shows words.
  final String skillName;

  final int requiredLevel;

  /// "Axe" · "Pickaxe" · null when bare hands will do.
  ///
  /// A word rather than the `ToolKind` enum because the inspector's line is
  /// prose, and because the *tier* the node also asks for is not shown: the
  /// player's answer to "can I gather this" is the engine's, and a card that
  /// spelled out minimum tool tiers would be re-implementing the check.
  final String? toolWord;
}

/// Whether a gather at one node could legally complete, on its KNOWN static
/// prerequisites — the skill level and the equipped tool.
///
/// Built for exactly one job: **disabling controls that would start an
/// activity guaranteed to be refused.** On a physical device a player at
/// Mining 1 could start a 14-second mining queue that required Mining 3 —
/// the completion refused it correctly and spent nothing, but the player
/// watched an animation that could not succeed. The card asks this ahead of
/// time so that queue is never startable.
///
/// It is a *hint*, like [StrideSession.canGather]: the engine re-validates
/// both checks on every execute and its answer is the authoritative one.
/// Nothing here weakens or replaces the domain validation — it mirrors it.
final class GatherEligibility {
  const GatherEligibility({
    required this.skillMet,
    required this.requiredLevel,
    required this.currentLevel,
    required this.toolMet,
    this.requiredToolTier = 0,
    this.equippedToolTier,
    this.lockedByProjectName,
  });

  /// The player's level in the node's skill clears [requiredLevel].
  final bool skillMet;

  /// The node's required level, restated so the card can say the whole
  /// sentence — "Requires Mining 3 — you are 1" — without a second lookup.
  final int requiredLevel;

  /// The player's current level in the node's skill, from the same
  /// `SkillDefinition.levelAt` curve the engine gates on.
  final int currentLevel;

  /// A tool of the required kind and tier is equipped, or none is required.
  final bool toolMet;

  /// The node's minimum tool tier, restated so a gate sentence can say
  /// "Needs a tier-2 pickaxe — yours is tier 1" instead of the flat
  /// "not equipped" a device pass found misleading when a pickaxe *was*
  /// equipped, just under-tier (Fable V2, `DECISIONS/0027`).
  final int requiredToolTier;

  /// The highest equipped tier of the required kind, or null when nothing
  /// of that kind is equipped at all — the two halves of the same sentence.
  final int? equippedToolTier;

  /// The project standing between the player and this node, by display
  /// name — the engine's `nodeLocked` refusal mirrored ahead of time so the
  /// Gather button is never enabled for a node the engine must refuse
  /// (found by Fable V2's audit: pre-Lift, the Hardened Copper Seam's
  /// button could enable and then be refused).
  final String? lockedByProjectName;

  /// Every known static prerequisite is met.
  bool get eligible => skillMet && toolMet && lockedByProjectName == null;
}

/// One enemy at a place, with how much of this visit it has left.
final class PlaceEncounterLine {
  const PlaceEncounterLine({
    required this.enemyId,
    required this.name,
    required this.isBoss,
    required this.behavior,
    required this.encountersPerVisit,
    required this.remainingThisVisit,
  });

  final ContentId enemyId;
  final String name;
  final bool isBoss;
  final EnemyBehavior behavior;

  /// From content (`DECISIONS/0021` §1).
  final int encountersPerVisit;

  /// Fights left here before the player must travel.
  ///
  /// **Equal to [encountersPerVisit] when the place is not the player's
  /// current one**, and that is the truth rather than a placeholder: the visit
  /// count is emptied by every move, so a place the player is not standing in
  /// has a full allowance waiting the moment they arrive.
  final int remainingThisVisit;
}

/// One route the content pack draws between two places, as the atlas needs it.
///
/// **Adjacency only.** It says a road exists and what it would cost, from
/// content, so the atlas can draw the line and say "reached by way of". It is
/// not the authority on whether the player may walk it — `TravelTo` re-checks
/// adjacency, requirements and balance on execute — and it carries no
/// affordance of its own.
final class RegionRoute {
  const RegionRoute({
    required this.from,
    required this.to,
    required this.stepCost,
  });

  final ContentId from;
  final ContentId to;

  /// Profile-scaled, as it would be charged.
  final int stepCost;
}

/// One destination the player could set out for, as the World screen needs it.
///
/// Every field is a question the engine would answer on execute, asked ahead of
/// time so a control can explain itself. **None of them is the authority.**
/// `TravelTo` re-validates all of it, which is what keeps a UI from becoming a
/// second place the travel rules live (`RULES.md` E-2).
final class TravelOption {
  const TravelOption({
    required this.id,
    required this.displayName,
    required this.terrain,
    required this.stepCost,
    required this.isReached,
    required this.affordable,
    required this.missingRequirements,
    required this.resourceCount,
  });

  final ContentId id;
  final String displayName;
  final Terrain terrain;

  /// Profile-scaled, as it would be charged.
  final int stepCost;

  /// Whether the player has been here before.
  final bool isReached;

  final bool affordable;

  /// Items the destination requires that the player does not hold, by display
  /// name. Empty when the way is open.
  final List<String> missingRequirements;

  final int resourceCount;

  bool get isBlocked => missingRequirements.isNotEmpty;

  /// Whether a travel control should be enabled.
  bool get canTravel => !isBlocked && affordable;

  /// How many more steps are needed, or zero when the journey is affordable.
  int shortfallFrom(int banked) {
    final int gap = stepCost - banked;
    return gap < 0 ? 0 : gap;
  }
}

/// One recipe, with every reason it can or cannot be made right now.
///
/// The Craft screen's whole job is to be truthful about *why* something is
/// unavailable, so the reasons are separate fields rather than one boolean —
/// "you need Smithing 4" and "you need two more ingots" are different sentences
/// and the player acts on them differently.
final class RecipeOption {
  const RecipeOption({
    required this.id,
    required this.displayName,
    required this.skillName,
    required this.skill,
    required this.requiredLevel,
    required this.currentLevel,
    required this.ingredients,
    required this.outputItem,
    required this.outputName,
    required this.outputRarity,
    required this.outputQuantity,
    required this.experience,
    this.outputCategory,
    this.outputIsTool = false,
    this.lockReason,
    this.craftSeconds,
    this.station,
  });

  final ContentId id;
  final String displayName;
  final String skillName;

  /// The crafting skill's id — for the craft stage's profession loop and the
  /// presentation duration table (PRESENTATION_WORLD_REWARD_FEEL_01 §15).
  final ContentId skill;

  final int requiredLevel;
  final int currentLevel;

  final List<RecipeIngredientLine> ingredients;

  /// The item this recipe makes. Named `outputItem` since Phase 2 and kept —
  /// it is already the id the contract's `outputItemId` asks for, and renaming
  /// a field every caller reads would be churn with no reader behind it.
  final ContentId outputItem;
  final String outputName;

  /// The rarity of what this makes, so a Craft row can be coloured by what the
  /// player is working towards. Null only when the pack has no definition for
  /// [outputItem].
  final Rarity? outputRarity;

  /// The authored bench time for one repetition, or null for the category
  /// default (`RecipeDefinition.craftSeconds`).
  final int? craftSeconds;

  /// The authored workstation for the craft stage's scene, or null for the
  /// skill's default (`RecipeDefinition.station`). Presentation only.
  final CraftStation? station;

  /// Profile-scaled, as it would be produced.
  final int outputQuantity;

  /// Profile-scaled, as it would be awarded.
  final int experience;

  /// The output item's authored category, or null when the pack does not
  /// define the output. Drives the Craft screen's category filter
  /// (PRESENTATION_WORLD_REWARD_FEEL_01 §19) — derivation only, never a rule.
  final ItemCategory? outputCategory;

  /// Whether the output is a tool (an equipment item with a tool kind) — the
  /// filter separates Tools from Gear.
  final bool outputIsTool;

  /// Why this recipe is not currently craftable regardless of skill and
  /// materials — the engine's own sentence for a contract-taught recipe the
  /// player has not earned yet (`DECISIONS/0023` §3). Null when unlocked.
  final String? lockReason;

  bool get isLocked => lockReason != null;

  bool get skillMet => currentLevel >= requiredLevel;

  bool get ingredientsMet =>
      ingredients.every((RecipeIngredientLine i) => i.satisfied);

  bool get canCraft => !isLocked && skillMet && ingredientsMet;

  /// How many consecutive crafts the held ingredients could fund, floor 0.
  /// A hint for the queue selector's clamp — the engine re-validates every
  /// dispatch, exactly as gathering's affordability clamp works.
  int get craftableCount {
    if (!canCraft) return 0;
    int count = 1 << 30;
    for (final RecipeIngredientLine line in ingredients) {
      if (line.required <= 0) continue;
      final int affordable = line.held ~/ line.required;
      if (affordable < count) count = affordable;
    }
    return count == 1 << 30 ? 1 : count;
  }

  /// Which of the Craft planner's bands this recipe belongs to (Fable V2
  /// Iteration 03). Derived HERE, deliberately: if a widget classified,
  /// the section counts, the census line, and the engine could each tell a
  /// different story the first time the definitions drifted (E-2/F-07).
  /// Order follows the engine's own refusal order: lock, then skill, then
  /// ingredients. "One away" means exactly one ingredient LINE is short,
  /// whatever the quantity — a single clear next objective.
  ReadinessBand get band {
    if (isLocked) return ReadinessBand.gated;
    if (!skillMet) return ReadinessBand.skillLocked;
    if (canCraft) return ReadinessBand.ready;
    final int short = ingredients
        .where((RecipeIngredientLine i) => !i.satisfied)
        .length;
    return short == 1 ? ReadinessBand.oneAway : ReadinessBand.missing;
  }
}

/// The Craft planner's readiness bands, in display order.
enum ReadinessBand {
  ready('Ready'),
  oneAway('One ingredient away'),
  missing('Missing materials'),
  skillLocked('Skill locked'),
  gated('Locked');

  const ReadinessBand(this.label);
  final String label;
}

/// One line of a recipe's requirements, with what the player actually holds.
final class RecipeIngredientLine {
  const RecipeIngredientLine({
    required this.item,
    required this.displayName,
    required this.required,
    required this.held,
    this.craftedByRecipe,
  });

  final ContentId item;
  final String displayName;
  final int required;
  final int held;

  /// The recipe that produces this ingredient, or null when it is not a
  /// crafted good — the Craft planner's chain link (Fable V2 Iteration 03):
  /// tapping a short crafted ingredient jumps the bench to the recipe that
  /// makes it. Where several recipes share an output (the mill's plank
  /// pair), the projection picks the one the player can currently see.
  final ContentId? craftedByRecipe;

  bool get satisfied => held >= required;

  int get shortfall {
    final int gap = required - held;
    return gap < 0 ? 0 : gap;
  }
}

/// What kind of thing a [SkillUnlock] opens — the roadmap's row glyph and
/// the tap-detail's shape both key off it.
enum SkillUnlockKind { site, milestone, recipe }

/// One thing a skill level gates, and whether the player has it yet.
final class SkillUnlock {
  const SkillUnlock({
    required this.displayName,
    required this.requiredLevel,
    required this.unlocked,
    required this.where,
    this.gate,
    this.kind = SkillUnlockKind.site,
    this.detailLines = const <String>[],
    this.trackableItem,
  });

  final String displayName;
  final int requiredLevel;

  /// Site, milestone, or recipe — see [SkillUnlockKind].
  final SkillUnlockKind kind;

  /// The expanded row's whole story, pre-capped in the projection (Fable V2
  /// Iteration 03): a site says what it yields and what that feeds; a
  /// recipe says what it needs and what it makes possible. At most two
  /// lines — the roadmap is a plan, not a wiki, and capping HERE is what
  /// keeps a widget from growing the cap (E-2).
  final List<String> detailLines;

  /// The item this unlock produces, for the Track-as-Pursuit control, or
  /// null for a milestone.
  final ContentId? trackableItem;

  /// Actually available — the level **and** every other gate met. It used
  /// to mean "level met" alone, which made the Skills screen say "Level 2
  /// opens Wolfhide Jerkin" about a recipe a contract teaches — a promise
  /// the bench then broke (Fable V2 audit, `DECISIONS/0027`).
  final bool unlocked;

  /// The location that hosts it, for a gathering node. Null for a recipe, which
  /// can be made anywhere.
  final String? where;

  /// What else the unlock needs beyond the level, as a short phrase —
  /// `a contract at Stonefall Mine`, `the Stonefall Lift`, `a tier-2 axe` —
  /// or null when the level is the whole story.
  final String? gate;
}

/// Where one roadmap level stands relative to the player (Fable V2
/// Iteration 03): earned, the level they are on, the nearest level that
/// still holds content, or the road beyond it.
enum RoadmapLevelState { earned, current, next, future }

/// One level of a profession's roadmap: its number, its standing, and
/// every unlock authored at it. A level with no entries is a legitimate
/// breath in the ladder; the screen renders it as one muted line rather
/// than hiding the number.
final class RoadmapLevel {
  const RoadmapLevel({
    required this.level,
    required this.state,
    required this.entries,
    this.xpAway,
  });

  final int level;
  final RoadmapLevelState state;
  final List<SkillUnlock> entries;

  /// Experience still to go to reach this level — carried ONLY on the
  /// [RoadmapLevelState.next] band, deliberately: a distance on every
  /// future row is the spreadsheet this screen exists to not be.
  final int? xpAway;
}

/// A profession's whole plannable future: the standing the header restates
/// and the ladder from level 1 to the last level any content touches —
/// never padded to the curve's cap, because an empty promise is a lie the
/// player can walk toward.
final class SkillRoadmap {
  const SkillRoadmap({
    required this.standing,
    required this.levels,
    required this.openCount,
    required this.totalCount,
    this.contentHorizon = 0,
    this.maxLevel = 0,
  });

  final SkillStanding standing;
  final List<RoadmapLevel> levels;

  /// How many of the skill's unlocks are open / authored in total — the
  /// header's "6 of 14 unlocks open" line.
  final int openCount;
  final int totalCount;

  /// The last level any authored content touches, and the skill's own cap —
  /// so the ladder can end honestly ("the road runs out here; nothing is
  /// written above LV [contentHorizon] yet") instead of silently, and a
  /// finished horizon can say so (`DECISIONS/0028` §6).
  final int contentHorizon;
  final int maxLevel;

  /// True when every authored unlock is open — the ladder is walked.
  bool get horizonReached => totalCount > 0 && openCount == totalCount;
}

/// What a journey did.
final class TravelReport {
  const TravelReport({
    required this.succeeded,
    required this.destinationName,
    required this.cost,
    this.firstVisit = false,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String destinationName;

  /// Profile-scaled, as charged on success and as quoted on refusal.
  final int cost;

  /// Whether this arrival opened the place. False on refusal.
  final bool firstVisit;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;
}

/// What a craft did.
///
/// Every figure is copied from the `ItemCrafted` event, for the same reason
/// [ActionReport] gives: the recipe definition carries *base* values, and the
/// engine scales them through the active balance profile as it applies them.
final class CraftReport {
  const CraftReport({
    required this.succeeded,
    required this.recipeName,
    this.outputItemId,
    this.outputName,
    this.outputRarity,
    this.quantity,
    this.skillName,
    this.experience,
    this.skillLevelBefore,
    this.skillLevelAfter,
    this.unlockedNames = const <String>[],
    this.equipDelta,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String recipeName;
  final ContentId? outputItemId;
  final String? outputName;

  /// The output's authored rarity, for the craft celebration's colouring.
  final Rarity? outputRarity;
  final int? quantity;
  final String? skillName;
  final int? experience;

  /// The skill's level before/after and what the new level opens — the same
  /// shape [ActionReport] carries, for the same E-2 reason.
  final int? skillLevelBefore;
  final int? skillLevelAfter;
  final List<String> unlockedNames;

  /// For finished equipment: the stat story against what is worn now —
  /// "Attack 3 → 9". Null for materials and consumables.
  final EquipDelta? equipDelta;

  bool get levelledUp =>
      skillLevelBefore != null &&
      skillLevelAfter != null &&
      skillLevelAfter! > skillLevelBefore!;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;
}

/// The stat change a newly crafted piece of equipment offers over what is
/// currently in its slot — the equipment-craft presentation's one line
/// (brief §69). Figures come from content `power`, the same figure combat
/// reads.
final class EquipDelta {
  const EquipDelta({
    required this.slot,
    required this.statName,
    required this.before,
    required this.after,
  }) : toolLine = null,
       replaces = null,
       swapsProfession = false;

  const EquipDelta.tool({
    required this.toolLine,
    required this.replaces,
    this.swapsProfession = false,
  }) : slot = EquipmentSlot.tool,
       statName = 'Tool',
       before = 0,
       after = 0;

  final EquipmentSlot slot;

  /// "Attack" for weapons, "Defence" for armour. A tool has no stat the
  /// engine reads (`CombatRules` takes weapon and armour power; a tool is
  /// its kind and tier), so a tool delta carries [toolLine] instead and
  /// [statName] is never shown for one.
  final String statName;

  /// What the currently equipped item in the slot provides (0 when empty).
  final int before;

  /// What the crafted item provides.
  final int after;

  /// A profession tool's identity in player words — `Woodcutting tool ·
  /// Tier 1` — or null for a weapon or armour.
  final String? toolLine;

  /// What wearing the crafted tool would take off — `Bronze Pickaxe ·
  /// Mining tool · Tier 1` — or null when the slot is empty.
  final String? replaces;

  /// True when [replaces] is a tool of another profession: an axe over a
  /// pickaxe is a swap, never an upgrade or a sidegrade (the correction
  /// pass: "Tool power 4 → 4" was the wrong sentence).
  final bool swapsProfession;

  bool get isTool => toolLine != null;
  bool get isUpgrade => !isTool && after > before;
}

/// One local calendar day of the step tracker (`DECISIONS/0026`).
final class StepDayLine {
  const StepDayLine({
    required this.startOfDayMillis,
    required this.granted,
    required this.isToday,
  });

  /// Local midnight of this day, epoch millis — for labelling only.
  final int startOfDayMillis;

  /// Steps the ledger credited whose observation bucket starts in this day.
  final int granted;

  final bool isToday;
}

/// One hour of today with credited steps in it. Hours with nothing are
/// absent, not zero — the tracker draws the day from what exists.
final class StepHourLine {
  const StepHourLine({required this.startMillis, required this.granted});

  /// Local top-of-hour, epoch millis.
  final int startMillis;
  final int granted;
}

/// What the step tracker shows (`StrideSession.stepHistory`,
/// `DECISIONS/0026`): the last seven local days of credited steps, today's
/// hours, and the freshness facts that make the figures trustworthy.
final class StepHistory {
  const StepHistory({
    required this.days,
    required this.hoursToday,
    required this.lastSyncAtMillis,
    required this.originCount,
    required this.lifetimeGranted,
    required this.nowMillis,
  });

  /// Seven entries, oldest first; the last is today.
  final List<StepDayLine> days;

  /// Today's credited steps by local hour, ascending. See [StepHourLine].
  final List<StepHourLine> hoursToday;

  /// `StrideSession.lastSyncAtMillis`, copied so one object carries the
  /// whole tracker.
  final int? lastSyncAtMillis;

  /// How many distinct pseudonymous sources hold credit in the retained
  /// window — a count, never an identity (`RULES.md` H-7).
  final int originCount;

  /// Every step ever credited (`totalGranted`) — the lifetime context line.
  final int lifetimeGranted;

  /// The wall-clock reading the fold ran at, for relative labels.
  final int nowMillis;

  StepDayLine get today => days.isEmpty
      ? const StepDayLine(startOfDayMillis: 0, granted: 0, isToday: true)
      : days.last;

  /// The seven-day total, today included.
  int get week => days.fold(0, (int a, StepDayLine d) => a + d.granted);
}

/// One pseudonymous source's share of what the ledger credited (Fable V2
/// Iteration 02, the Q-08 forensic split). [label] is positional — `Source
/// A` — assigned in stable key order; no identifier is ever shown (H-7).
final class OriginDiagnosticsLine {
  const OriginDiagnosticsLine({
    required this.label,
    required this.todayGranted,
    required this.retainedGranted,
    required this.settledToWatermark,
  });

  final String label;

  /// Credited today (local day, same attribution as the Step Tracker).
  final int todayGranted;

  /// Credited across the whole retained window (~7 days).
  final int retainedGranted;

  /// Whether this source has a completeness watermark — i.e. the adapter
  /// has vouched for it at least once.
  final bool settledToWatermark;
}

/// Everything the ledger already persists that explains today's figure —
/// see [StrideSession.syncDiagnostics]. Read-only; no accounting change.
final class SyncDiagnosticsView {
  const SyncDiagnosticsView({
    required this.todayTotal,
    required this.perOrigin,
    required this.totalObserved,
    required this.totalGranted,
    required this.totalSpent,
    required this.banked,
    required this.grantedAheadOfObserved,
    required this.retiredSteps,
    required this.syncCount,
    required this.cursorPresent,
    required this.lateDiscardedSlices,
    required this.correctionsObserved,
    required this.unreachableGapEvents,
    required this.lastSyncAtMillis,
  });

  /// Today's credited total — by construction the sum of [perOrigin]'s
  /// today figures, and the same figure the Step Tracker's Today shows.
  final int todayTotal;

  /// One line per source holding credit in the retained window, stable
  /// order. Length is the source count the Character tab already shows.
  final List<OriginDiagnosticsLine> perOrigin;

  /// Lifetime observed vs granted vs spent, and the spendable remainder.
  final int totalObserved;
  final int totalGranted;
  final int totalSpent;
  final int banked;

  /// The getter that exists "so 'why does the game say more than Health
  /// does?' has an answer" — granted credit whose observations were later
  /// revised downward. Zero in the ordinary course.
  final int grantedAheadOfObserved;

  /// Steps retired by economy epochs — walked, remembered, not spendable.
  final int retiredSteps;

  final int syncCount;
  final bool cursorPresent;
  final int lateDiscardedSlices;
  final int correctionsObserved;
  final int unreachableGapEvents;
  final int? lastSyncAtMillis;

  /// The one-sentence explanation of a multi-source day, ready for the UI.
  bool get multiSource => perOrigin.length > 1;
}

final class SkillSummary {
  const SkillSummary({
    required this.id,
    required this.displayName,
    required this.experience,
    required this.level,
    required this.maxLevel,
  });

  final ContentId id;
  final String displayName;

  /// Total experience in this skill, not experience into the current level.
  ///
  /// Experience *into* the level would need `xpThresholds[level - 1]` and
  /// `xpThresholds[level]`, and indexing a content curve is a game rule. If a
  /// screen ever needs that span it belongs on `SkillDefinition` beside
  /// `levelAt`, not here and certainly not in a widget.
  final int experience;

  final int level;
  final int maxLevel;
}

/// What working a resource node did.
///
/// Every outcome figure here is copied from the `ResourceGathered` event, which
/// is the only place they are authoritative. **A caller must never recompute one
/// from content.** `ResourceNodeDefinition` carries *base* values; the engine
/// scales `stepCost`, `yieldsQuantity` and `xp` through the active balance
/// profile as it applies them. Under `profile.production` every multiplier is
/// 100 and the two coincide, which is exactly why reading content instead would
/// look correct right up until it wasn't.
final class ActionReport {
  const ActionReport({
    required this.succeeded,
    required this.nodeName,
    required this.cost,
    this.itemId,
    this.itemName,
    this.quantity,
    this.bonusYield = 0,
    this.skillName,
    this.experience,
    this.skillLevelBefore,
    this.skillLevelAfter,
    this.unlockedNames = const <String>[],
    this.rejection,
    this.detail,
    this.rarity,
  });

  final bool succeeded;
  final String nodeName;

  /// The yielded item's authored rarity, for the result card's frame.
  ///
  /// **Added in PRESENTATION_COMBAT_EVOLUTION_01**, because until then the
  /// gather path was blind to it. `InventoryEntry` and `DropPreview` both
  /// carried rarity already; this report simply dropped it, so the universal
  /// result card had nothing to escalate on and **a Rare Gloom Silk pulled
  /// from a silkstrand thicket rendered exactly like a Common Copper Ore** —
  /// same frame, same weight, same everything. The craft path had
  /// distinguished its outputs since GFCP01; the gather path never could.
  ///
  /// A projection of content the item definition already holds. No new domain
  /// data, no new event field, and nothing here decides anything.
  final Rarity? rarity;

  /// Profile-scaled, as it would be charged. Shown before the action is taken,
  /// which is why it is on the report rather than only on the event.
  final int cost;

  /// The yielded item's id, copied from the committed event — the activity
  /// result card's icon key (GFCP01 device correction). Null on refusal.
  final ContentId? itemId;

  final String? itemName;
  final int? quantity;

  /// How much of [quantity] a yield bonus contributed — the committed
  /// quantity against the node's authored base, so the result strip can say
  /// "+1 extra" when the tool or the level paid off instead of leaving the
  /// proc invisible (Fable V2 Iteration 02, feel-audit item 5). A
  /// restatement of the committed event's own figure; no roll re-derived.
  final int bonusYield;

  /// The skill the experience went to, by display name, and the amount awarded
  /// — both profile-scaled, as awarded, and both null unless [succeeded].
  ///
  /// These exist so that a success message can say "+10 Foraging XP" without the
  /// UI reading `ResourceNodeDefinition.xp` (an unscaled base value) or diffing
  /// `SkillProgress` across the await (widget arithmetic over durable state).
  /// Both of those are the failure `RULES.md` E-2 names, and both were reachable
  /// while this type dropped a field its source event already carried.
  ///
  /// [experience] may legitimately be zero: a node with no xp is legal.
  final String? skillName;
  final int? experience;

  /// The skill's level before and after this action, from the content curve
  /// — so a level-up presentation can say WHAT CHANGED without a widget
  /// diffing durable state (`RULES.md` E-2). Null unless [succeeded].
  final int? skillLevelBefore;
  final int? skillLevelAfter;

  /// The nodes and recipes the new level opens, by display name, when this
  /// action levelled the skill. Empty otherwise.
  final List<String> unlockedNames;

  bool get levelledUp =>
      skillLevelBefore != null &&
      skillLevelAfter != null &&
      skillLevelAfter! > skillLevelBefore!;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;
}

// -- The activity queue (`DECISIONS/0022`) -------------------------------------

/// The durable queue in progress, as the gather card needs it. Null when none.
///
/// Every figure is read from `ActivityQueueState` — the committed save state —
/// so what the progress bar derives and what reconciliation computes cannot
/// disagree (`DECISIONS/0022`, Consequences).
final class ActivityQueueView {
  const ActivityQueueView({
    required this.node,
    required this.requested,
    required this.completed,
    required this.durationMillis,
    required this.anchorEpochMillis,
  });

  final ContentId node;
  final int requested;
  final int completed;

  /// One repetition's authored duration, frozen at start.
  final int durationMillis;

  /// Wall-clock epoch millis at which the current repetition began.
  final int anchorEpochMillis;
}

/// One committed queue repetition, ready to render.
///
/// Copied from the `ActivityCompletion` payload on the committed event — the
/// same rule [ActionReport] states: a caller must never recompute these from
/// content, whose figures are unscaled base values.
final class ActivityCompletionLine {
  const ActivityCompletionLine({
    required this.stepsSpent,
    required this.itemName,
    required this.quantity,
    required this.skillName,
    required this.experience,
  });

  final int stepsSpent;
  final String itemName;
  final int quantity;
  final String skillName;
  final int experience;
}

/// What one activity-queue command did.
final class ActivityQueueReport {
  const ActivityQueueReport({
    required this.succeeded,
    required this.nodeName,
    this.completions = const <ActivityCompletionLine>[],
    this.active = false,
    this.completedAfter = 0,
    this.requested = 0,
    this.stopReason,
    this.skillLevelBefore,
    this.skillLevelAfter,
    this.unlockedNames = const <String>[],
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String nodeName;

  /// The repetitions this command committed, in order. Empty on a no-op
  /// reconcile — which is a success, not a failure.
  final List<ActivityCompletionLine> completions;

  /// Whether a queue is still active after this command.
  final bool active;

  /// The queue's completed count after this command (meaningful while a queue
  /// existed when it ran).
  final int completedAfter;

  /// The queue's requested count, for "n / m" displays.
  final int requested;

  /// The stable `RejectionCode.wire` value of the refusal that stopped the
  /// queue mid-reconciliation, or null. Distinct from [rejection]: the
  /// command *succeeded* — the queue stopped honestly.
  final String? stopReason;

  /// The worked skill's level before/after this batch, and what a new level
  /// opens — [ActionReport]'s shape, so the return-from-background summary
  /// can announce the level-up (brief §71).
  final int? skillLevelBefore;
  final int? skillLevelAfter;
  final List<String> unlockedNames;

  bool get levelledUp =>
      skillLevelBefore != null &&
      skillLevelAfter != null &&
      skillLevelAfter! > skillLevelBefore!;

  /// Why the command itself was refused, or null on success.
  final String? rejection;
  final String? detail;
}

// -- Combat (Combat Slice 01, `DECISIONS/0020`) --------------------------------

/// The fight in progress, as the combat stage needs it. Null when none.
///
/// Every figure is read from `EncounterState` — the snapshot the engine took
/// at encounter start — and from content for the names. Nothing here is
/// derived by arithmetic in this file: `enemyHp` is the committed value, and a
/// stage that animated towards anything else would be showing a fight the
/// disk does not have.
final class EncounterView {
  const EncounterView({
    required this.enemyId,
    required this.enemyName,
    required this.location,
    required this.locationName,
    required this.turn,
    required this.playerHp,
    required this.playerMaxHp,
    required this.playerAttack,
    required this.playerDefence,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.telegraph,
    required this.behavior,
    required this.isBoss,
    this.knowledge = KnowledgeTier.unseen,
    this.intentLine,
  });

  final ContentId enemyId;
  final String enemyName;
  final ContentId location;
  final String locationName;

  /// 1-based; the turn the player is about to take.
  final int turn;

  final int playerHp;
  final int playerMaxHp;
  final int playerAttack;
  final int playerDefence;
  final int enemyHp;
  final int enemyMaxHp;

  /// True when the enemy's next reply is a heavy strike (guarded behaviour).
  final bool telegraph;
  final EnemyBehavior behavior;
  final bool isBoss;

  /// The player's knowledge of this enemy, for the intent line's depth.
  final KnowledgeTier knowledge;

  /// What the enemy will do this round, in words earned by knowledge
  /// (`DECISIONS/0027`, experimental — the Studied tier's felt payoff).
  ///
  /// Truthful by construction: the resolver is deterministic, so the strike
  /// count and the telegraphs this line narrates are the round that will
  /// actually resolve. Null while the enemy is unseen — an unknown creature
  /// gives nothing away. Presentation only; no roll changes at any tier.
  final String? intentLine;
}

/// One enemy the player could fight where they stand, with the reason it
/// cannot be fought right now, if any.
///
/// **A hint, not the authority.** `StartEncounter` re-checks every one of
/// these on execute (`RULES.md` E-2). [reason] follows the engine's own
/// refusal order so the card and the refusal that would arrive anyway agree.
final class EncounterOption {
  const EncounterOption({
    required this.enemyId,
    required this.name,
    required this.isBoss,
    required this.behavior,
    required this.maxHealth,
    required this.attack,
    required this.defence,
    required this.xp,
    required this.drops,
    required this.encountersPerVisit,
    required this.remainingThisVisit,
    required this.available,
    this.reason,
    this.knowledge = KnowledgeTier.unseen,
    this.victories = 0,
    this.studiedAt = 3,
    this.knownAt = 6,
    this.requiresKnownEnemyName,
  });

  final ContentId enemyId;
  final String name;
  final bool isBoss;
  final EnemyBehavior behavior;

  /// Profile-scaled, as the encounter would begin — the same figure the
  /// engine writes on `EncounterStarted`.
  final int maxHealth;
  final int attack;
  final int defence;

  /// Profile-scaled, as it would be awarded.
  final int xp;

  /// Every possible drop, with the rarity to colour it by; chance is
  /// deliberately not shown. A preview of what could fall, not a promise.
  final List<DropPreview> drops;

  /// How many fights with this enemy one visit holds, from content
  /// (`DECISIONS/0021` §1).
  final int encountersPerVisit;

  /// How many of those are left before the player has to travel. Zero when the
  /// visit is spent, in which case [reason] is `enemy_driven_off`.
  final int remainingThisVisit;

  final bool available;

  /// `enemy_not_known` · `encounter_in_progress` · `enemy_driven_off` ·
  /// `session_not_ready`, or null when [available].
  final String? reason;

  /// When [reason] is `enemy_not_known`: the display name of the enemy that
  /// must be Known before this one shows itself (`DECISIONS/0028`), so the
  /// card can state the gate in the engine's own terms. Null otherwise.
  final String? requiresKnownEnemyName;

  /// The compact enemy-knowledge tier (`DECISIONS/0023` §5), with the
  /// victory counts the card can narrate progress from. Presentation only:
  /// nothing rolls differently at any tier.
  final KnowledgeTier knowledge;
  final int victories;
  final int studiedAt;
  final int knownAt;
}

/// The player's combat figures right now, for the Character screen.
///
/// From `CombatRules.loadoutFor` — the same function the engine snapshots an
/// encounter from — and `CombatRules.levelThresholds`. Reading a domain
/// function, not computing a rule.
final class CombatFigures {
  const CombatFigures({
    required this.maxHp,
    required this.attack,
    required this.defence,
    required this.level,
    required this.experience,
    this.weaponName,
    this.armorName,
    this.nextLevelThreshold,
  });

  final int maxHp;
  final int attack;
  final int defence;
  final String? weaponName;
  final String? armorName;
  final int level;

  /// Cumulative character experience.
  final int experience;

  /// Cumulative experience at which the next level is reached; null at the
  /// level cap.
  final int? nextLevelThreshold;

  /// Experience still to earn before the next level; null at the cap.
  int? get experienceToNextLevel {
    final int? next = nextLevelThreshold;
    if (next == null) return null;
    final int missing = next - experience;
    return missing < 0 ? 0 : missing;
  }
}

/// One owned consumable that heals, as the Eat chooser lists it.
final class EdibleOption {
  const EdibleOption({
    required this.itemId,
    required this.name,
    required this.healing,
    required this.count,
  });

  final ContentId itemId;
  final String name;

  /// The item's healing figure from content. What a bite actually restores is
  /// `min(healing, missing)` and is reported on the [ConsumableUsedBeat].
  final int healing;
  final int count;
}

/// One thing that happened in a round, in the order it happened.
///
/// A presentation-neutral narration of the engine's combat events, built by
/// the session from the events the command returned. **The stage animates from
/// these and never re-derives them from a state diff**: every figure is copied
/// from the event that carries it, so an HP bar settles to the committed value
/// and a level-up is shown exactly when the event that produced it was
/// applied. Sealed, so a stage that switches over the kinds is told by the
/// analyzer when a new kind arrives.
sealed class CombatBeat {
  const CombatBeat();
}

/// The fight began. Carries the opening figures.
final class EncounterStartedBeat extends CombatBeat {
  const EncounterStartedBeat({
    required this.enemyName,
    required this.playerHp,
    required this.playerMaxHp,
    required this.enemyHp,
    required this.enemyMaxHp,
  });

  final String enemyName;
  final int playerHp;
  final int playerMaxHp;
  final int enemyHp;
  final int enemyMaxHp;
}

/// The player hit the enemy.
/// How a blow landed, from its roll: the one word the narration and the
/// stage can say about it (PLAYABLE_POLISH_01 §8). Derived from the
/// committed event's own roll, never re-rolled.
enum StrikeQuality { weak, even, strong }

StrikeQuality _qualityOf(int roll) => switch (roll) {
  < 0 => StrikeQuality.weak,
  > 0 => StrikeQuality.strong,
  _ => StrikeQuality.even,
};

final class PlayerStruckBeat extends CombatBeat {
  const PlayerStruckBeat({
    required this.damage,
    required this.enemyHpAfter,
    this.quality = StrikeQuality.even,
  });

  final int damage;
  final int enemyHpAfter;
  final StrikeQuality quality;
}

/// The player ate. Exactly one of the item left the inventory.
final class ConsumableUsedBeat extends CombatBeat {
  const ConsumableUsedBeat({
    required this.itemName,
    required this.healed,
    required this.playerHpAfter,
  });

  final String itemName;

  /// As healed, never the item's raw healing figure.
  final int healed;
  final int playerHpAfter;
}

/// The player braced (`DECISIONS/0027`, experimental): no strike dealt, and
/// every enemy strike that follows this beat lands at half damage. The
/// halved figures ride the [EnemyStruckBeat]s themselves.
final class BracedBeat extends CombatBeat {
  const BracedBeat();
}

/// The enemy hit the player. A flurry produces two per round, [strikeIndex]
/// 0 and 1; a guarded enemy's every-third-turn blow carries [heavy].
final class EnemyStruckBeat extends CombatBeat {
  const EnemyStruckBeat({
    required this.damage,
    required this.playerHpAfter,
    required this.heavy,
    required this.strikeIndex,
    this.quality = StrikeQuality.even,
  });

  final int damage;
  final int playerHpAfter;
  final bool heavy;
  final int strikeIndex;
  final StrikeQuality quality;
}

/// The round is over and the fight goes on. [turn] is the turn the player is
/// about to take; [telegraph] warns of a heavy reply next round.
final class RoundEndedBeat extends CombatBeat {
  const RoundEndedBeat({required this.turn, required this.telegraph});

  final int turn;
  final bool telegraph;
}

/// The enemy fell. The whole reward, as awarded, once.
final class WonBeat extends CombatBeat {
  const WonBeat({
    required this.xp,
    required this.levelBefore,
    required this.levelAfter,
    required this.drops,
    this.enemyName = '',
    this.knowledgeBefore,
    this.knowledgeAfter,
    this.knowledgeXp = 0,
    this.understoodDrops = const <String>[],
    this.signatureDrops = const <String>[],
    this.bountyProgress = const <BountyProgressLine>[],
  });

  /// Profile-scaled, as awarded.
  final int xp;
  final int levelBefore;
  final int levelAfter;

  /// What dropped, as awarded, once — with the rarity each line is coloured
  /// by. Built from the `EncounterWon` event's own map; nothing here is
  /// re-derived from a state diff, which is what keeps a victory panel showing
  /// the reward the disk actually holds.
  final List<RewardLine> drops;

  final String enemyName;

  /// The enemy-knowledge tier this victory found and left (`DECISIONS/0023`
  /// §5), computed from the event's own `victoriesAfter` against the enemy's
  /// thresholds — so the beat announces exactly the crossing the commit
  /// made. Null on a record written before victories were counted.
  final KnowledgeTier? knowledgeBefore;
  final KnowledgeTier? knowledgeAfter;

  /// The one-time Known award, already inside [xp]; named so the bestiary
  /// milestone can be announced as its own beat.
  final int knowledgeXp;

  /// The enemy's ordinary drops by name — "newly understood" when the tier
  /// reaches Studied. Content, not a roll.
  final List<String> understoodDrops;

  /// The signature drops by name — revealed when the tier reaches Known;
  /// `???` until then, which the panel prints rather than this field.
  final List<String> signatureDrops;

  /// Accepted bounties this victory advanced, with the count after.
  final List<BountyProgressLine> bountyProgress;

  bool get levelledUp => levelAfter > levelBefore;

  /// True when this victory crossed a knowledge threshold.
  bool get knowledgeAdvanced =>
      knowledgeBefore != null &&
      knowledgeAfter != null &&
      knowledgeAfter!.index > knowledgeBefore!.index;

  /// The rarest thing that dropped, or null when nothing did.
  Rarity? get rarestDrop {
    Rarity? best;
    for (final RewardLine line in drops) {
      final Rarity? r = line.rarity;
      if (r == null) continue;
      if (best == null || r.index > best.index) best = r;
    }
    return best;
  }
}

/// One accepted bounty's progress after a victory: `Forest Wolf 2 / 3`.
final class BountyProgressLine {
  const BountyProgressLine({
    required this.contractName,
    required this.progress,
    required this.required,
  });

  final String contractName;
  final int progress;
  final int required;
}

/// The player fell and was moved to [retreatToName]. Nothing was lost.
final class LostBeat extends CombatBeat {
  const LostBeat({required this.retreatToName, this.healed = false});

  final String retreatToName;

  /// True when the safe destination restored the player's HP on arrival —
  /// said on the card so retreat never reads as death (§19).
  final bool healed;
}

/// The player chose to leave for [retreatToName]. Nothing was lost.
final class RetreatedBeat extends CombatBeat {
  const RetreatedBeat({required this.retreatToName});

  final String retreatToName;
}

/// What a combat command did.
///
/// On success [events] narrates the round in order; on refusal it is empty and
/// [rejection] carries the stable wire code.
final class CombatReport {
  const CombatReport({
    required this.succeeded,
    required this.enemyName,
    this.events = const <CombatBeat>[],
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String enemyName;

  /// The round's beats, in the order the engine emitted them.
  final List<CombatBeat> events;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;

  /// The beat that ended the encounter, if this round ended it: a [WonBeat],
  /// [LostBeat] or [RetreatedBeat]. Null while the fight goes on.
  CombatBeat? get outcome {
    if (events.isEmpty) return null;
    final CombatBeat last = events.last;
    return last is WonBeat || last is LostBeat || last is RetreatedBeat
        ? last
        : null;
  }
}

/// What an equip or unequip did.
/// What a playtest reset did (`DECISIONS/0025`).
final class PlaytestResetReport {
  const PlaytestResetReport({
    required this.succeeded,
    required this.freshStart,
    this.retiredBanked = 0,
    this.walkedRetired = 0,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final bool freshStart;

  /// Spendable steps the reset retired from the balance.
  final int retiredBanked;

  /// What the player-facing walked figure read before it started again.
  final int walkedRetired;

  final String? rejection;
  final String? detail;
}

final class EquipReport {
  const EquipReport({
    required this.succeeded,
    required this.itemName,
    this.rejection,
    this.detail,
    this.statLabel,
    this.statBefore,
    this.statAfter,
  });

  final bool succeeded;
  final String itemName;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;

  /// The stat story of a successful weapon or armor swap — `ATK` / `DEF`
  /// with the figure before and after, from the same `loadoutFor` the
  /// engine fights with (Fable V2, `DECISIONS/0027`). Null for tool swaps
  /// (never power-compared, by owner ruling) and refusals.
  final String? statLabel;
  final int? statBefore;
  final int? statAfter;

  /// Whether the swap moved the figure at all — equipping the same tier
  /// twice tells no story.
  bool get statChanged =>
      statLabel != null && statBefore != null && statBefore != statAfter;
}

/// A running game, with the health source opened if one could be.
///
/// Created by [start], which is the only entry point. A blocked bootstrap
/// produces a session with [outcome] set to `BootstrapBlocked` and no engine —
/// the harness renders the refusal rather than crashing, because a refusal is a
/// state the app is supposed to be able to present.
final class StrideSession {
  // The engine and the durable head are positional, and the rest are named.
  // They predate the SDK accepting `this._field` as a named initializing
  // formal; the two migration fields below use that form, and the older three
  // are left as they are.
  StrideSession._(
    this._engine,
    this._generation,
    this._lastTransaction, {
    required this.runtime,
    required this.outcome,
    required this.registry,
    required this.saveId,
    required this.saltFingerprint,
    required this.health,
    required this.keyingRefusal,
    required this.atlasLayout,
    required this.atlasLayoutProblems,
    // Non-final: a deferred migration fills the first and clears the second.
    this._migration,
    this._pendingMigration,
  });

  /// Opens storage, runs bootstrap, and installs the device identity into the
  /// native adapter.
  ///
  /// [source] substitutes the platform bridge, and exists so that every path
  /// below — including the ones a device would take an hour to reproduce — runs
  /// under `flutter test`. It is null in the app.
  static Future<StrideSession> start({
    Directory? overrideRoot,
    StepSyncSource? source,
    Future<OriginKeyingInstall> Function(Uint8List salt)? openSource,
    AssetBundle? atlasBundle,
  }) async {
    final StrideRuntime runtime = await bootstrapStride(
      overrideRoot: overrideRoot,
    );
    final BootstrapOutcome outcome = runtime.outcome;

    // The atlas layout is read the way the content pack is: once, here, before
    // any widget exists. It is presentation data and its absence blocks
    // nothing — a session with no layout still travels; the World screen falls
    // back to its list. Loaded before the switch so a blocked bootstrap and a
    // broken layout are two independent facts rather than one masking the
    // other.
    final ({AtlasLayout? layout, List<String> problems}) atlas =
        await _loadAtlas(atlasBundle, outcome);

    GameEngine? engine;
    ContentRegistry? registry;
    String? saveId;
    int generation = -1;
    int lastTransaction = 0;
    StateMigrationReport? migration;
    PendingStateMigration? pendingMigration;

    switch (outcome) {
      case BootstrapNewGame(:final SaveLoaded load):
        engine = outcome.engine;
        registry = outcome.registry;
        saveId = outcome.identity.saveId;
        generation = load.generation;
        lastTransaction = load.lastAppliedTransaction;
      case BootstrapExistingGame():
        engine = outcome.engine;
        registry = outcome.registry;
        saveId = outcome.identity.saveId;
        // `expectation`, not `load` — deliberately.
        //
        // When this launch migrated the save, the migration committed *after*
        // the load, so `load.generation` is one transaction behind the durable
        // head. Starting from it would make this session's first real commit
        // fail compare-and-swap, and a conflict surfacing two actions later
        // reads as a storage fault rather than as an arithmetic slip here.
        //
        // When the migration is *pending* nothing was committed and
        // `expectation` is the load's own head; the first sync commits on it.
        final CommitExpectation head = outcome.expectation;
        generation = head.expectedSnapshotGeneration;
        lastTransaction = head.expectedLastAppliedTransaction;
        migration = outcome.migration;
        pendingMigration = outcome.pendingMigration;
      case BootstrapBlocked():
        // No engine, no health source, nothing opened. The refusal is the
        // whole result and the harness renders it.
        break;
    }

    // Opened only when startup succeeded and a salt resolved. A blocked launch
    // has no business keying anything, and an unkeyed source is a state
    // `PlatformStepSource` deliberately cannot be in.
    StepSyncSource? health = source;
    OriginKeyingRefusal? refusal;
    final Uint8List? salt = runtime.healthKeyingSalt;
    if (health == null && engine != null && salt != null) {
      final OriginKeyingInstall install = openSource == null
          ? await PlatformStepSource.open(salt: salt)
          : await openSource(salt);
      health = install.source;
      refusal = install.refusal;
    }

    return StrideSession._(
      engine,
      generation,
      lastTransaction,
      runtime: runtime,
      outcome: outcome,
      registry: registry,
      saveId: saveId,
      saltFingerprint: engine == null
          ? null
          : switch (outcome) {
              BootstrapNewGame() => outcome.identity.saltFingerprint,
              BootstrapExistingGame() => outcome.identity.saltFingerprint,
              BootstrapBlocked() => null,
            },
      health: health,
      keyingRefusal: refusal,
      atlasLayout: atlas.layout,
      atlasLayoutProblems: atlas.problems,
      migration: migration,
      pendingMigration: pendingMigration,
    );
  }

  /// Reads the atlas layout and checks it against the content pack.
  ///
  /// Never throws. A layout that cannot be read or does not cover every content
  /// location comes back as `null` with the reasons, and the reasons are printed
  /// in debug so a broken layout is found at startup rather than on the World
  /// tab. In release nothing is printed and the atlas is simply absent.
  static Future<({AtlasLayout? layout, List<String> problems})> _loadAtlas(
    AssetBundle? bundle,
    BootstrapOutcome outcome,
  ) async {
    final List<String> problems = <String>[];
    AtlasLayout? layout;
    try {
      layout = await loadAtlasLayoutFromAssets(bundle: bundle);
    } on AtlasLayoutException catch (e) {
      problems.add(e.message);
    }
    if (layout != null) {
      final ContentRegistry? registry = switch (outcome) {
        BootstrapNewGame() => outcome.registry,
        BootstrapExistingGame() => outcome.registry,
        BootstrapBlocked() => null,
      };
      if (registry != null) {
        problems.addAll(layout.validateAgainst(registry.locations.keys));
      }
    }
    if (problems.isNotEmpty) {
      assert(() {
        for (final String problem in problems) {
          debugPrint('atlas_layout.json: $problem');
        }
        return true;
      }());
      return (layout: null, problems: List<String>.unmodifiable(problems));
    }
    return (layout: layout, problems: const <String>[]);
  }

  final StrideRuntime runtime;
  final BootstrapOutcome outcome;

  /// Set when *this launch* migrated the save — and, for the two migrations
  /// that exist, re-based the playable economy (`DECISIONS/0016`,
  /// `DECISIONS/0018`).
  ///
  /// Null on every ordinary launch, including every launch after the first. It
  /// exists so the acceptance script can see the cutover happen once and then
  /// never again — a migration nobody can observe is one nobody can verify.
  /// The developer harness renders it beside the energy figures.
  ///
  /// For a migration that waits for the first sync (`DECISIONS/0018`) this is
  /// null until [syncSteps] has completed it — see [migrationPending].
  StateMigrationReport? get migration => _migration;
  StateMigrationReport? _migration;

  /// The migration this launch still owes the save, or null.
  ///
  /// Set by bootstrap when the save's migration path contains a step that must
  /// run **after the first foreground reconciliation** — the v2→v3
  /// Transformation epoch. Bootstrap committed nothing; the engine is at the
  /// save's on-disk version, and the first [syncSteps] of this launch commits
  /// the backlog at that version and then applies and commits the migration
  /// once, through the ordinary commit path. Cleared only by that
  /// `CommitDurable`; re-derived from disk by [reload].
  PendingStateMigration? _pendingMigration;

  /// True while a save-version migration is waiting on the first sync.
  ///
  /// While true, [isReady] is false — gather, travel and craft refuse with
  /// `session_not_ready`, because the balance they would spend from is about to
  /// be retired — and [usableEnergy] projects the zero the cutover leaves. Only
  /// [syncSteps] proceeds, and it is what clears this.
  bool get migrationPending => _pendingMigration != null;

  /// Why the pending migration could not be applied, when the engine refused
  /// it. Null otherwise. Not reachable from a save any decoder produces; kept
  /// so a refusal is visible rather than silent.
  String? get migrationRefusal => _migrationRefusal;
  String? _migrationRefusal;

  /// The live engine, or null when the bootstrap was blocked.
  ///
  /// Replaced wholesale by [reload], which is the only thing that may swap it:
  /// a reloaded engine is built from the state that is actually on disk, and
  /// mutating the existing one in place would leave a half-rebuilt session
  /// observable to anything holding a reference.
  GameEngine? get engine => _engine;
  GameEngine? _engine;

  final ContentRegistry? registry;
  final String? saveId;
  final String? saltFingerprint;

  /// Null when startup was blocked, when the identity could not be keyed into
  /// the adapter, or on a platform with no implementation registered.
  final StepSyncSource? health;

  /// Why the adapter refused the device identity, when it did.
  final OriginKeyingRefusal? keyingRefusal;

  /// Where each place is drawn on the World Atlas, or null when the layout
  /// could not be read or does not cover the content pack — in which case
  /// [atlasLayoutProblems] says why and the World screen shows its list.
  ///
  /// Presentation data, loaded once at [start]. Not a game figure: nothing in
  /// the engine reads it, and a place with no coordinate is still a place.
  final AtlasLayout? atlasLayout;

  /// Every reason [atlasLayout] is null, as sentences. Empty when it is not.
  final List<String> atlasLayoutProblems;

  /// The durable head this session believes it is writing on top of.
  ///
  /// Advanced only by a `CommitDurable`. A refused commit leaves both figures
  /// where they were and sets [isStale], because the alternative — guessing —
  /// is what compare-and-swap exists to make impossible.
  int _generation;
  int _lastTransaction;

  bool _stale = false;

  /// True while a mutating call is between its first `await` and its commit.
  ///
  /// ## Why this lives here and not in a widget
  ///
  /// Every gate in this class — the [_stale] check in [syncSteps] and [gather] —
  /// is evaluated **before** the first `await` and never re-evaluated. That is
  /// safe if and only if calls are single-flight, and until now the guarantee
  /// lived in the dev harness's `_busy` flag: a widget's private field, one
  /// screen away from being forgotten by the next screen.
  ///
  /// Two concrete failures the widget-level flag does not close:
  ///
  /// - **A manufactured fault.** Two in-flight commits compute against the same
  ///   `_generation`; the loser is refused as a compare-and-swap conflict and
  ///   sets [_stale]. That is a real refusal, correctly reported, caused
  ///   entirely by a double tap — and indistinguishable from a storage fault.
  /// - **A gate bypass.** Call B can pass the [_stale] check before call A's
  ///   failed commit sets it, then execute and commit from a session the class
  ///   has already declared unsafe.
  ///
  /// Refusing re-entrancy here makes both unreachable regardless of what any
  /// widget remembers to do. A caller that double-taps gets a typed refusal
  /// rather than a corrupted expectation.
  bool _inFlight = false;

  /// True while a sync or a gather is running. A UI may render a spinner from
  /// this; it must not rely on it for correctness, because the refusal above is
  /// what actually enforces single-flight.
  bool get isBusy => _inFlight;

  /// True when the in-memory state has advanced past the durable state.
  ///
  /// Set by a refused commit. Every mutating method refuses while it is set:
  /// the honest recovery is [reload], which discards the in-memory divergence
  /// and rebuilds from what is actually on disk. Continuing to issue commands
  /// against a state the disk does not have would pile a second divergence on
  /// top of the first.
  ///
  /// **While this is set, every figure this class reports is ahead of disk.**
  /// A UI must stop presenting energy, inventory and skill values as truth and
  /// offer [reload], rather than showing a status row beside numbers the next
  /// launch will delete.
  bool get isStale => _stale;

  /// The most recent answer to the read-access request this session made
  /// before syncing (see [syncSteps]); null until the first sync. Presentation:
  /// lets a screen say "Health access is not granted" instead of "no new
  /// steps" when a read came back empty because nobody was allowed to read.
  HealthAuthorization? get lastAuthorization => _lastAuthorization;
  HealthAuthorization? _lastAuthorization;

  /// Whether a game action — gather, travel, craft — may be issued now.
  ///
  /// False while [migrationPending]: the balance an action would spend from is
  /// the one the imminent cutover retires. Syncing is gated by [canSync]
  /// instead, because the sync is what completes the migration.
  bool get isReady =>
      engine != null && !_stale && !_inFlight && !migrationPending;

  /// Whether [syncSteps] may run now. Unlike [isReady] this is true while a
  /// migration is pending — the first sync is the step that completes it.
  bool get canSync => engine != null && !_stale && !_inFlight;

  /// Banked energy: granted and unspent. Never expires (`DECISIONS/0008`).
  ///
  /// **Projects zero while [migrationPending].** The pending step is a
  /// deterministic re-basing that leaves `banked` at exactly zero (asserted by
  /// `transformation_epoch_test.dart`), and it lands within a second of the
  /// first frame. Showing the pre-cutover figure for that second would flash a
  /// balance the player is about to see vanish. This is the session's job as
  /// the projection layer, not a UI's: no widget knows a migration exists. It
  /// cannot mask a failed migration — a refused migration commit marks the
  /// session stale, and [reload] re-enters the pending state from disk, so the
  /// projection is only ever shown ahead of a cutover that will run.
  /// [totalGranted], [totalSpent] and [retiredSteps] are not projected: they
  /// are history, and the cutover moves none of them.
  int get usableEnergy =>
      migrationPending ? 0 : engine?.state.steps.banked ?? 0;

  /// True for a new game whose economy mark has not yet been set by its
  /// first authorised reconcile (`DECISIONS/0019`). Derived from the state,
  /// never a flag: a game that has synced once under a granted authorisation
  /// has left the origin. Deliberately **not** projected into [usableEnergy]:
  /// a new game holds nothing until that first read, and the one exception —
  /// a crash between the sync's commit and the baseline's — is healed by the
  /// very next sync, which the app runs at startup.
  bool get baselinePending => engine?.state.steps.epoch.isOrigin ?? false;

  int get totalGranted => engine?.state.steps.totalGranted ?? 0;
  int get totalSpent => engine?.state.steps.totalSpent ?? 0;

  /// Steps spent **in this economy** — since the current epoch's mark, which
  /// a playtest reset moves (`DECISIONS/0025`). The Adventure band shows
  /// this; [totalSpent] is the lifetime counter and stays on the Character
  /// tab. A projection: the ledger's `spentThisEpoch`, nothing stored.
  int get spentThisEpoch => engine?.state.steps.spentThisEpoch ?? 0;

  /// The walked figure the player is shown: everything credited since the
  /// last playtest reset, or the lifetime counter when there has been none
  /// (`DECISIONS/0025`). [totalGranted] stays the lifetime figure.
  int get walkedSinceBaseline => engine?.state.steps.walkedSinceBaseline ?? 0;

  /// Whether a playtest reset has ever moved the walked baseline — when it
  /// has, the Character tab names the lifetime figure beside the reset one,
  /// so history is reported rather than hidden (`DECISIONS/0016`).
  bool get walkedBaselineMoved =>
      (engine?.state.steps.epoch.walkedAtStart ?? 0) > 0;

  /// Whether a durable cursor exists. **Never its contents.**
  ///
  /// The bytes are an opaque Health Connect changes token. Rendering them would
  /// put platform sync state on a screen and, from there, into a screenshot in
  /// a bug report.
  bool get hasCursor => engine?.state.steps.checkpoint.cursor != null;

  int get syncCount => engine?.state.steps.checkpoint.syncCount ?? 0;

  /// How many distinct step sources the ledger currently holds credit for —
  /// the origins present in the retained granted slices. **A count, never an
  /// identity** (`RULES.md` H-7), and read from the committed ledger rather
  /// than from the last sync report, so it survives a relaunch.
  ///
  /// Instrumentation for the Playable Experience Refinement 01 accounting
  /// investigation: a ledger that sums two origins for the same hours — a
  /// phone and a watch, or a phone and an app that writes steps — banks that
  /// walk twice by arithmetic, not by fault, and this figure is what tells a
  /// player (and the owner) that their bank has two contributors.
  int get ledgerOriginCount {
    final StepLedger? ledger = engine?.state.steps;
    if (ledger == null) return 0;
    return ledger.grantedSlices.keys
        .map((ObservationKey k) => k.origin)
        .toSet()
        .length;
  }

  SourceState get sourceState =>
      engine?.state.steps.sourceState ?? SourceState.unknown;

  /// When the last successful foreground sync finished, in epoch millis —
  /// or null before the first one this launch.
  ///
  /// **Ephemeral, deliberately.** Persisting a sync timestamp would put a
  /// wall-clock fact in the save for a presentation nicety, and the save
  /// format is not moved for niceties. A cold launch syncs on its own
  /// bootstrap path, so the figure is populated within moments of the app
  /// existing; "null" is honestly "not yet, this launch".
  ///
  /// The reading comes from [activityWallClock] — the product's one
  /// injectable wall-clock seam (`DECISIONS/0022` §8, extended by `0026`) —
  /// never from a second `DateTime.now` site.
  int? get lastSyncAtMillis => _lastSyncAtMillis;
  int? _lastSyncAtMillis;

  /// The step tracker's projection (`DECISIONS/0026`): granted steps per
  /// local calendar day over the retained window, from the same committed
  /// slices the bank is summed from.
  ///
  /// ## The local-day policy, owned here
  ///
  /// `TimeBucket` is a UTC hour-granularity span. A "day" is the device's
  /// local calendar day **at read time**: each retained slice is attributed
  /// to the local day its bucket *starts* in, and hours of today are grouped
  /// the same way. This is the timezone policy Q-UI-9 refused to let a
  /// widget invent; it lives here, in one documented place, and feeds no
  /// rule — nothing in the engine reads it back.
  ///
  /// ## What the figures are, and are not
  ///
  /// Sums of **granted** slices — what the ledger actually credited, the
  /// same per-origin accounting the bank uses (`RULES.md` H-1). Two sources
  /// crediting the same hour both count, exactly as they do in the bank;
  /// [StepHistory.originCount] says when that is happening. Figures move
  /// only when a sync commits, which is the honest shape: the tracker shows
  /// what the game has counted, and [lastSyncAtMillis] says how fresh that
  /// is. Days older than the ledger's retention window are compacted away
  /// and shown as absent, never as zero walked.
  StepHistory stepHistory() {
    final StepLedger? ledger = engine?.state.steps;
    final int nowMillis = activityWallClock();
    if (ledger == null) {
      return StepHistory(
        days: const <StepDayLine>[],
        hoursToday: const <StepHourLine>[],
        lastSyncAtMillis: _lastSyncAtMillis,
        originCount: 0,
        lifetimeGranted: 0,
        nowMillis: nowMillis,
      );
    }
    final DateTime now = DateTime.fromMillisecondsSinceEpoch(nowMillis);
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    // Local-midnight boundaries for the last seven days, oldest first.
    final List<DateTime> starts = <DateTime>[
      for (int i = 6; i >= 0; i--)
        DateTime(todayStart.year, todayStart.month, todayStart.day - i),
    ];
    final List<int> totals = List<int>.filled(starts.length, 0);
    final Map<int, int> hourTotals = <int, int>{};

    for (final MapEntry<ObservationKey, int> slice
        in ledger.grantedSlices.entries) {
      if (slice.value <= 0) continue;
      final DateTime start = DateTime.fromMillisecondsSinceEpoch(
        slice.key.bucket.startMillis,
      );
      final DateTime day = DateTime(start.year, start.month, start.day);
      for (int i = 0; i < starts.length; i++) {
        if (day == starts[i]) {
          totals[i] += slice.value;
          break;
        }
      }
      if (day == todayStart) {
        final int hourStart = DateTime(
          start.year,
          start.month,
          start.day,
          start.hour,
        ).millisecondsSinceEpoch;
        hourTotals[hourStart] = (hourTotals[hourStart] ?? 0) + slice.value;
      }
    }

    return StepHistory(
      days: <StepDayLine>[
        for (int i = 0; i < starts.length; i++)
          StepDayLine(
            startOfDayMillis: starts[i].millisecondsSinceEpoch,
            granted: totals[i],
            isToday: i == starts.length - 1,
          ),
      ],
      hoursToday: <StepHourLine>[
        for (final int hour in hourTotals.keys.toList()..sort())
          StepHourLine(startMillis: hour, granted: hourTotals[hour]!),
      ],
      lastSyncAtMillis: _lastSyncAtMillis,
      originCount: ledgerOriginCount,
      lifetimeGranted: ledger.totalGranted,
      nowMillis: nowMillis,
    );
  }

  /// The sync-forensics projection (Fable V2 Iteration 02, Q-08 evidence):
  /// everything the ledger already persists that explains "why is today's
  /// figure what it is", per pseudonymous source — with zero accounting
  /// change.
  ///
  /// ## Why this exists
  ///
  /// On the owner's phone the Oura app showed 3,121 while Stride showed
  /// 5,732. The ledger credits per `(origin, bucket)` and sums origins
  /// (`RULES.md` H-1); Apple Health's own headline de-duplicates the
  /// overlap between sources, and Oura's app shows only the ring's share.
  /// Three arithmetics, three numbers — and until this projection, only
  /// Stride's total was visible. The per-source split turns the next
  /// device test into proof instead of comparison-shopping.
  ///
  /// ## H-7, honored not bent
  ///
  /// Origins are pseudonymous keys and stay that way: sources are labeled
  /// positionally — `Source A`, `Source B` — in stable key order, and no
  /// identifier, name, or key byte is ever displayed. The owner identifies
  /// a source by comparing its figure against the app that wrote it, which
  /// is a comparison Stride enables without ever naming anyone.
  ///
  /// Same read-time fold and local-day policy as [stepHistory]; the two can
  /// never disagree because both sum the same committed `grantedSlices`.
  SyncDiagnosticsView syncDiagnostics() {
    final StepLedger? ledger = engine?.state.steps;
    if (ledger == null) {
      return const SyncDiagnosticsView(
        todayTotal: 0,
        perOrigin: <OriginDiagnosticsLine>[],
        totalObserved: 0,
        totalGranted: 0,
        totalSpent: 0,
        banked: 0,
        grantedAheadOfObserved: 0,
        retiredSteps: 0,
        syncCount: 0,
        cursorPresent: false,
        lateDiscardedSlices: 0,
        correctionsObserved: 0,
        unreachableGapEvents: 0,
        lastSyncAtMillis: null,
      );
    }

    final int nowMillis = activityWallClock();
    final DateTime now = DateTime.fromMillisecondsSinceEpoch(nowMillis);
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    // Per-origin folds over the same slices the bank and tracker sum.
    final Map<StepOriginKey, int> todayByOrigin = <StepOriginKey, int>{};
    final Map<StepOriginKey, int> retainedByOrigin = <StepOriginKey, int>{};
    for (final MapEntry<ObservationKey, int> slice
        in ledger.grantedSlices.entries) {
      if (slice.value <= 0) continue;
      final StepOriginKey origin = slice.key.origin;
      retainedByOrigin[origin] = (retainedByOrigin[origin] ?? 0) + slice.value;
      final DateTime start = DateTime.fromMillisecondsSinceEpoch(
        slice.key.bucket.startMillis,
      );
      if (DateTime(start.year, start.month, start.day) == todayStart) {
        todayByOrigin[origin] = (todayByOrigin[origin] ?? 0) + slice.value;
      }
    }

    // Stable positional labels: sorted by the pseudonymous key so `Source A`
    // is the same source every time this save is opened. The key itself is
    // never surfaced (H-7).
    final List<StepOriginKey> origins = retainedByOrigin.keys.toList()
      ..sort((StepOriginKey a, StepOriginKey b) => a.value.compareTo(b.value));
    String labelFor(int index) =>
        'Source ${String.fromCharCode(0x41 + (index % 26))}';

    int todayTotal = 0;
    for (final int granted in todayByOrigin.values) {
      todayTotal += granted;
    }

    return SyncDiagnosticsView(
      todayTotal: todayTotal,
      perOrigin: <OriginDiagnosticsLine>[
        for (final (int i, StepOriginKey origin) in origins.indexed)
          OriginDiagnosticsLine(
            label: labelFor(i),
            todayGranted: todayByOrigin[origin] ?? 0,
            retainedGranted: retainedByOrigin[origin] ?? 0,
            settledToWatermark: ledger.checkpoint.originWatermarks.containsKey(
              origin,
            ),
          ),
      ],
      totalObserved: ledger.totalObserved,
      totalGranted: ledger.totalGranted,
      totalSpent: ledger.totalSpent,
      banked: ledger.banked,
      grantedAheadOfObserved: ledger.grantedAheadOfObserved,
      retiredSteps: ledger.epoch.retiredSteps,
      syncCount: ledger.checkpoint.syncCount,
      cursorPresent: ledger.checkpoint.cursor != null,
      lateDiscardedSlices: ledger.lateDiscardedSlices,
      correctionsObserved: ledger.correctionsObserved,
      unreachableGapEvents: ledger.unreachableGapEvents,
      lastSyncAtMillis: _lastSyncAtMillis,
    );
  }

  // -- Health ---------------------------------------------------------------

  /// Whether the platform's health service is present and usable.
  Future<HealthAvailability> checkAvailability() async {
    final StepSyncSource? source = health;
    if (source == null) {
      return const HealthAvailability.unavailable(
        // Not `serviceUnavailable`: the service may be present and authorized.
        // The adapter has no identity, and retrying cannot install one.
        ProviderUnavailableReason.originKeyingUnconfigured,
      );
    }
    return source.availability();
  }

  /// Asks for read-only step access, in the foreground.
  ///
  /// Denial is an ordinary answer. Nothing about it blocks a screen or an
  /// action — the game stays fully playable with no health source at all.
  Future<HealthAuthorization> requestPermission() async {
    final StepSyncSource? source = health;
    if (source == null) return HealthAuthorization.unavailable;
    return source.requestAuthorization();
  }

  /// Drains every page, reconciles each, and commits each before asking for the
  /// next.
  ///
  /// ## Why the commit is inside the loop
  ///
  /// A page's grants must be durable before the page after it is requested. The
  /// alternative — accumulate every page in memory and commit once — loses the
  /// whole read if the process dies on page nine, and the cursor is not the
  /// problem there: the *ledger* is, because the slices it already granted in
  /// memory were never written and the retry would grant them again. Per-page
  /// commits make an interruption cost one page.
  ///
  /// ## Why it stops rather than retries
  ///
  /// A refused commit means durable state moved under this transaction, or the
  /// journal would not take the append. Neither is fixed by trying harder from
  /// a state that has already diverged. The session goes stale and the harness
  /// offers a reload, which is the only honest recovery.
  Future<SyncReport> syncSteps({int maxPages = 64}) async {
    // Refused rather than queued. A second sync has nothing to add — the first
    // is already draining every page — and running it would commit against an
    // expected generation the first is about to move. The `finally` is what
    // makes the guard hold when a page throws rather than returning.
    if (_inFlight) {
      return const SyncReport.unavailable(
        ProviderUnavailableReason.transientFailure,
      );
    }
    _inFlight = true;
    try {
      // ## Ask before reading, and keep asking until the answer is "granted"
      //
      // Read access is requested here, in the foreground, immediately before
      // the read — not on a settings screen and not only from the dev harness.
      // A fresh install that never asks never appears in Health's app list,
      // its first read comes back empty, and the product shows "no new steps"
      // for a player who was never asked (the Transformation Build 01 device
      // finding). On iOS `requestAuthorization` presents the sheet only while
      // the answer is undetermined and returns at once afterwards, so calling
      // it before every sync until it reports granted costs nothing and lets a
      // player who denied and then allowed Steps in Settings be picked up by
      // the next tap of Sync. Still foreground-only (H-5), still no observer.
      if (_lastAuthorization != HealthAuthorization.granted) {
        _lastAuthorization = await requestPermission();
      }
      final SyncReport report = (await _syncSteps(
        maxPages,
      )).withAuthorization(_lastAuthorization);
      // A real read happened — the store answered, whether or not it had
      // anything new. Refusals, unavailability and keying faults do not
      // move the mark: "last synced" must mean "last actually read".
      if (report.status == SyncStatus.reconciled ||
          report.status == SyncStatus.noChange) {
        _lastSyncAtMillis = activityWallClock();
      }
      // After the sync, whatever it did. The pending migration waits for the
      // sync's one chance to observe the backlog, not for the backlog to have
      // been observed: an unavailable or denied source at the cutover means
      // the backlog could not be seen, and the epoch marks what is known.
      // Waiting for a sync that succeeds would leave the player unable to act
      // until health cooperates, which `startup_sync_test.dart` says the game
      // must never do.
      if (migrationPending && !_stale) await _completeMigration();
      // A brand-new game's first authorised reconcile sets its baseline
      // (DECISIONS/0019). After the migration branch, deliberately: a
      // migrated save has left the origin and this is a no-op for it.
      if (!_stale && _baselineDue(report)) await _establishNewGameBaseline();
      return report;
    } finally {
      _inFlight = false;
    }
  }

  /// Applies and commits the migration bootstrap deferred, once, over the
  /// post-sync state.
  ///
  /// The commit goes through [_commit] with the session's current expectation
  /// — the sync's own commit, if there was one, has already advanced it. On
  /// `CommitDurable` the engine is swapped for the migrated one, [migration] is
  /// populated (with `bankedAfter == 0` and the backlog inside the retired
  /// body), and the pending state clears.
  ///
  /// A refused commit is handled exactly like every other refused commit here:
  /// the session goes stale, the in-memory engine is left at the old version,
  /// and [reload] rebuilds from disk — which still holds an old-version save
  /// and so re-enters the pending state. It does not block startup. If the
  /// process dies before this commit lands, the next launch reads an
  /// old-version save whose cursor already advanced, its first sync grants
  /// nothing new, and this runs then with the same result.
  Future<void> _completeMigration() async {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final PendingStateMigration? pending = _pendingMigration;
    if (active == null || content == null || pending == null) return;

    final StateMigrationApplication applied = pending.apply(
      registry: content,
      state: active.state,
    );
    if (applied is StateMigrationRefused) {
      // Not reachable from a save any decoder produces. Left pending and
      // reported rather than played: a re-basing that cannot explain itself
      // must not proceed quietly, and continuing on an unmigrated state would
      // let the retired balance be spent.
      _migrationRefusal = '${applied.step}: ${applied.rejection.format()}';
      return;
    }
    final StateMigrationApplied migrated = applied as StateMigrationApplied;

    final CommitOutcome commit = await _commit(
      migrated.engine,
      migrated.events,
    );
    if (commit is CommitRefused) {
      _stale = true;
      return;
    }
    _engine = migrated.engine;
    _migration = migrated.report;
    _pendingMigration = null;
    _migrationRefusal = null;
  }

  /// Whether [report] is the first successful, authorised reconcile of a game
  /// whose economy mark is still the origin — the one moment 0019 fires.
  ///
  /// "Successful" means the store was actually read (`reconciled` or
  /// `noChange`) under a *granted* authorisation. A denied or undetermined
  /// answer, an unavailable service, a keying fault or a refused commit all
  /// leave the mark at the origin, so the baseline is set the first time a
  /// real read happens — never on the strength of an empty answer nobody was
  /// allowed to give.
  bool _baselineDue(SyncReport report) {
    final GameEngine? active = engine;
    if (active == null || migrationPending) return false;
    if (!active.state.steps.epoch.isOrigin) return false;
    if (report.authorization != HealthAuthorization.granted) return false;
    return report.status == SyncStatus.reconciled ||
        report.status == SyncStatus.noChange;
  }

  /// Retires what a new game's first authorised reconcile observed, so the
  /// game begins spendable-zero (`DECISIONS/0019`).
  ///
  /// One command, one commit, through the ordinary path — the sync's own
  /// commit has already advanced the head. Exactly-once is the epoch itself:
  /// the command is refused once the mark has left the origin, so a crash
  /// between the sync's commit and this one is followed by a launch whose
  /// first sync grants nothing new (the cursor advanced) and lands here with
  /// the same totals. A refused commit marks the session stale like any
  /// other; [reload] rebuilds from disk with the mark still at the origin, and
  /// the next sync tries again.
  Future<void> _establishNewGameBaseline() async {
    final GameEngine? active = engine;
    if (active == null) return;
    final EngineResult result = active.execute(
      EstablishNewGameBaseline(stateVersion: active.state.stateVersion),
    );
    if (result.rejection != null) return; // the mark already left the origin
    final CommitOutcome commit = await _commit(active, result.events);
    if (commit is CommitRefused) _stale = true;
  }

  Future<SyncReport> _syncSteps(int maxPages) async {
    final GameEngine? active = engine;
    if (active == null || _stale) {
      return const SyncReport.unavailable(
        ProviderUnavailableReason.transientFailure,
      );
    }
    final StepSyncSource? source = health;
    if (source == null) {
      return SyncReport(
        status: SyncStatus.keyingUnconfigured,
        pages: 0,
        originCount: 0,
        bucketCount: 0,
        observedSteps: 0,
        newlyGranted: 0,
        faults: const <SyncFault>[SyncFault.originKeyingUnconfigured],
        deliveryKind: 'unavailable',
        unavailableReason: ProviderUnavailableReason.originKeyingUnconfigured,
      );
    }

    final Set<StepOriginKey> origins = <StepOriginKey>{};
    final Set<TimeBucket> buckets = <TimeBucket>{};
    final List<SyncFault> faults = <SyncFault>[];
    int observed = 0;
    int granted = 0;
    int pages = 0;
    String kind = 'noChange';
    SyncStatus status = SyncStatus.noChange;
    ProviderUnavailableReason? unavailable;
    int? intervalStart;
    int? intervalEnd;
    String? commitDetail;
    String? rejectionCode;

    Uint8List? continuation;

    for (int page = 0; page < maxPages; page++) {
      final SyncFetch fetch = await source.fetchSteps(
        SyncRequest(
          // Read from the ledger every page, not captured once. The checkpoint
          // event moves it, and a captured cursor would resume a paginated
          // read from a position two pages stale.
          cursor: active.state.steps.checkpoint.cursor,
          continuation: continuation,
        ),
      );
      pages++;
      faults.addAll(fetch.faults);

      final SyncResponse response = fetch.response;
      switch (response) {
        case IncrementalSync(
          :final List<StepObservation> observations,
          :final SyncCompleteness completeness,
        ):
          kind = 'incremental';
          status = SyncStatus.reconciled;
          _tally(observations, origins, buckets);
          observed += observations.fold(
            0,
            (int a, StepObservation o) => a + o.steps,
          );
          _readInterval(completeness, (int s, int e) {
            intervalStart = s;
            intervalEnd = e;
          });
        case CursorInvalidatedSync(
          :final List<StepObservation> observations,
          :final SyncCompleteness completeness,
        ):
          kind = 'recovery';
          status = SyncStatus.reconciled;
          _tally(observations, origins, buckets);
          observed += observations.fold(
            0,
            (int a, StepObservation o) => a + o.steps,
          );
          _readInterval(completeness, (int s, int e) {
            intervalStart = s;
            intervalEnd = e;
          });
        case NoChangeSync():
          kind = 'noChange';
          if (status != SyncStatus.reconciled) status = SyncStatus.noChange;
        case ProviderUnavailableSync(:final ProviderUnavailableReason reason):
          kind = 'unavailable';
          status = SyncStatus.unavailable;
          unavailable = reason;
        case ContractViolationSync():
          kind = 'contractViolation';
          status = SyncStatus.contractViolation;
      }

      final EngineResult result = active.execute(
        ReconcileStepSync(response: response),
      );

      if (result case RejectedResult(:final CommandRejection rejection)) {
        // A malformed batch. Nothing was applied — `RejectedResult` carries the
        // state object unchanged, not a copy of it — so there is nothing to
        // commit and nothing to undo.
        rejectionCode = rejection.code.wire;
        status = SyncStatus.contractViolation;
        break;
      }

      granted += result.events.whereType<StepsGranted>().fold(
        0,
        (int a, StepsGranted e) => a + e.steps,
      );

      if (result.events.isNotEmpty) {
        final CommitOutcome commit = await _commit(active, result.events);
        if (commit is CommitRefused) {
          commitDetail = commit.reason.name;
          status = SyncStatus.commitRefused;
          _stale = true;
          break;
        }
      }

      // The read is drained. Anything else would ask the adapter to resume a
      // page it has already delivered.
      if (fetch.isFinalPage) break;
      continuation = fetch.continuation;
      if (continuation == null) break;
    }

    return SyncReport(
      status: status,
      pages: pages,
      originCount: origins.length,
      bucketCount: buckets.length,
      observedSteps: observed,
      newlyGranted: granted,
      faults: faults,
      deliveryKind: kind,
      unavailableReason: unavailable,
      intervalStartMillis: intervalStart,
      intervalEndMillis: intervalEnd,
      commitDetail: commitDetail,
      rejection: rejectionCode,
    );
  }

  // -- Gameplay -------------------------------------------------------------

  /// **The activity subsystem's one wall clock** (`DECISIONS/0022` §8).
  ///
  /// Epoch milliseconds, read here and nowhere else in the product: the
  /// activity commands carry the reading *into* `stride_core` as data, exactly
  /// as the health path's buckets arrive, and `lib/ui` derives its progress
  /// bars from differences of this seam against the committed anchor — never
  /// from `DateTime.now`, which `Scripts/check-ui-boundary.sh` (rule 5,
  /// Q-UI-9) continues to forbid there unchanged.
  ///
  /// This is deliberately wall-clock, not monotonic: the queue's whole point
  /// is to advance across background, lock, and process death, and only a
  /// wall clock survives those. A backward jump is harmless by construction —
  /// reconciliation clamps elapsed time at zero and never moves the anchor on
  /// a clock reading alone.
  ///
  /// Mutable so tests substitute a fake; the app never reassigns it.
  int Function() activityWallClock = _defaultActivityWallClock;

  static int _defaultActivityWallClock() =>
      DateTime.now().millisecondsSinceEpoch;

  /// The durable activity queue, or null when none runs. Read live from the
  /// committed state; a relaunch that finds a queue shows it here.
  ActivityQueueView? get activityQueue {
    final ActivityQueueState? queue = engine?.state.activityQueue;
    if (queue == null) return null;
    return ActivityQueueView(
      node: queue.node,
      requested: queue.requested,
      completed: queue.completed,
      durationMillis: queue.durationMillis,
      anchorEpochMillis: queue.anchorEpochMillis,
    );
  }

  /// The profile-scaled cost of working [node], or null when it is not content.
  ///
  /// Read from the registry through the same profile the engine charges with,
  /// so the number on the button and the number debited cannot disagree.
  int? costOf(ContentId node) {
    final ResourceNodeDefinition? definition = registry?.resourceNodes[node];
    if (definition == null || registry == null) return null;
    return registry!.profile.applyStepCost(definition.stepCost);
  }

  /// The profile-scaled yield of one working of [node], or null when it is
  /// not content — [costOf]'s counterpart, and the same rule: the same profile
  /// the engine grants with, so a reconstructed display cannot disagree with
  /// what the events actually granted.
  int? yieldOf(ContentId node) {
    final ResourceNodeDefinition? definition = registry?.resourceNodes[node];
    if (definition == null || registry == null) return null;
    return registry!.profile.applyYield(definition.yieldsQuantity);
  }

  /// The profile-scaled experience of one working of [node], or null when it
  /// is not content. Same terms as [yieldOf].
  int? xpOf(ContentId node) {
    final ResourceNodeDefinition? definition = registry?.resourceNodes[node];
    if (definition == null || registry == null) return null;
    return registry!.profile.applyXp(definition.xp);
  }

  /// The content definition of [node], or null. For the activity controller
  /// restoring a relaunched queue's card — the same object [nodesHere] hands
  /// out, found by id rather than by the player's location, because a queue
  /// can outlive a move and its summary must still name what it was.
  ResourceNodeDefinition? nodeDefinitionOf(ContentId node) =>
      registry?.resourceNodes[node];

  /// Whether [node] can be worked right now, without attempting it.
  ///
  /// Used to disable a button. It is a *hint*: the engine re-validates
  /// everything on execute, and the engine's answer is the one that counts. A
  /// UI predicate that were the only check would be a rule enforced by a
  /// widget.
  bool canGather(ContentId node) {
    final int? cost = costOf(node);
    return isReady && cost != null && cost <= usableEnergy;
  }

  /// The static prerequisites of gathering at [node], asked ahead of time.
  ///
  /// **Mirrors `GameEngine._gather` exactly** — the skill check is the same
  /// `SkillDefinition.levelAt` over the same banked experience, and the tool
  /// check is the same scan of *every* equipment slot for an item whose
  /// `toolKind` matches and whose `tier` clears `minimumToolTier` (equipped,
  /// not merely owned). If the engine's rules change, this projection must
  /// change with them; it exists so a widget never re-derives them itself.
  ///
  /// A hint used to DISABLE, never to decide (`RULES.md` E-2): the engine
  /// re-validates on execute and a refusal that arrives anyway is rendered.
  /// When the session is not ready to answer — no engine, no registry, or an
  /// unknown node — it reports *eligible*, because the button must then be
  /// governed by the readiness checks that already exist, not by a guess.
  GatherEligibility gatherEligibilityOf(ContentId node) {
    const GatherEligibility open = GatherEligibility(
      skillMet: true,
      requiredLevel: 0,
      currentLevel: 0,
      toolMet: true,
    );
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final ResourceNodeDefinition? definition = content?.resourceNodes[node];
    if (active == null || content == null || definition == null) return open;
    final SkillDefinition? skill = content.skills[definition.skill];
    if (skill == null) return open;

    final int level = skill.levelAt(
      active.state.skills.experienceIn(definition.skill),
    );

    bool toolMet = definition.requiredToolKind == ToolKind.none;
    int? equippedTier;
    if (!toolMet) {
      for (final ContentId equipped in active.state.equipment.bySlot.values) {
        final ItemDefinition? item = content.items[equipped];
        if (item == null) continue;
        if (item.toolKind != definition.requiredToolKind) continue;
        if (equippedTier == null || item.tier > equippedTier) {
          equippedTier = item.tier;
        }
        if (item.tier >= definition.minimumToolTier) {
          toolMet = true;
        }
      }
    }

    // The project gate, mirrored from the engine's own `nodeLocked` refusal
    // so a control is never enabled for a gather the engine must refuse.
    String? lockedBy;
    final ContentId? gate = definition.unlockedByProject;
    if (gate != null && !active.state.progress.isProjectComplete(gate)) {
      lockedBy = content.projects[gate]?.displayName ?? gate.value;
    }

    return GatherEligibility(
      skillMet: level >= definition.requiredLevel,
      requiredLevel: definition.requiredLevel,
      currentLevel: level,
      toolMet: toolMet,
      requiredToolTier: definition.minimumToolTier,
      equippedToolTier: equippedTier,
      lockedByProjectName: lockedBy,
    );
  }

  /// Works a resource node once and commits the result atomically with it.
  ///
  /// The spend, the yield, and the experience are one event and one
  /// transaction. There is no window in which the energy is gone and the herbs
  /// have not arrived, on disk or in memory.
  ///
  /// A re-entrant call is refused rather than queued: two concurrent gathers
  /// both validate against the same banked energy and both commit, so a single
  /// tap that arrived twice would charge the player twice. The engine and CAS
  /// keep that consistent, but consistent-and-charged-twice is still wrong.
  Future<ActionReport> gather(ContentId node) async {
    if (_inFlight) {
      final ResourceNodeDefinition? busyNode = registry?.resourceNodes[node];
      return ActionReport(
        succeeded: false,
        nodeName: busyNode?.displayName ?? node.value,
        cost: costOf(node) ?? 0,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      return await _gather(node);
    } finally {
      _inFlight = false;
    }
  }

  Future<ActionReport> _gather(ContentId node) async {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final ResourceNodeDefinition? definition = content?.resourceNodes[node];
    final String name = definition?.displayName ?? node.value;
    final int cost = costOf(node) ?? 0;

    if (active == null || content == null || _stale || migrationPending) {
      return ActionReport(
        succeeded: false,
        nodeName: name,
        cost: cost,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
            : migrationPending
            ? 'the save is being brought up to date; sync steps first'
            : 'the game did not start',
      );
    }

    final int? levelBefore = definition == null
        ? null
        : _skillLevelOf(definition.skill);

    final EngineResult result = active.execute(GatherResource(node: node));
    if (result case RejectedResult(:final CommandRejection rejection)) {
      return ActionReport(
        succeeded: false,
        nodeName: name,
        cost: cost,
        rejection: rejection.code.wire,
        detail: rejection.explanation,
      );
    }

    final CommitOutcome commit = await _commit(active, result.events);
    if (commit is CommitRefused) {
      // The engine applied it and the disk did not take it. Marked stale rather
      // than reported as a success: the player would otherwise see herbs that
      // vanish on the next launch.
      _stale = true;
      return ActionReport(
        succeeded: false,
        nodeName: name,
        cost: cost,
        rejection: 'commit_refused',
        detail: commit.reason.name,
      );
    }

    final ResourceGathered gathered = result.events
        .whereType<ResourceGathered>()
        .first;
    final int? levelAfter = _skillLevelOf(gathered.skill);
    // The committed quantity against [yieldOf] — the same profile-scaled
    // base the engine granted from — so "+1 extra" is a restatement of the
    // event's own figure, never a re-roll and never widget arithmetic.
    final int baseYield = yieldOf(node) ?? gathered.quantity;
    return ActionReport(
      succeeded: true,
      nodeName: name,
      cost: gathered.stepsSpent,
      itemId: gathered.item,
      itemName:
          content.items[gathered.item]?.displayName ?? gathered.item.value,
      quantity: gathered.quantity,
      bonusYield: gathered.quantity > baseYield
          ? gathered.quantity - baseYield
          : 0,
      // Both taken from the event rather than from the node definition, for the
      // reason on the type: the definition's figures are unscaled base values.
      skillName:
          content.skills[gathered.skill]?.displayName ?? gathered.skill.value,
      experience: gathered.experience,
      skillLevelBefore: levelBefore,
      skillLevelAfter: levelAfter,
      unlockedNames: _unlocksOpened(gathered.skill, levelBefore, levelAfter),
      rarity: content.items[gathered.item]?.rarity,
    );
  }

  /// The player's current level in [skill], from the same curve the engine
  /// gates on. Null when the session cannot answer.
  int? _skillLevelOf(ContentId skill) {
    final GameEngine? active = engine;
    final SkillDefinition? definition = registry?.skills[skill];
    if (active == null || definition == null) return null;
    return definition.levelAt(active.state.skills.experienceIn(skill));
  }

  /// The nodes and recipes [skill] opens strictly between [before] and
  /// [after], by display name — the "MINING LEVEL 3 · Tin Seam unlocked"
  /// sentence's content (brief §68). Empty when no level was gained.
  List<String> _unlocksOpened(ContentId skill, int? before, int? after) {
    final ContentRegistry? content = registry;
    if (content == null || before == null || after == null || after <= before) {
      return const <String>[];
    }
    return <String>[
      for (final ResourceNodeDefinition node in content.resourceNodes.values)
        if (node.skill == skill &&
            node.requiredLevel > before &&
            node.requiredLevel <= after)
          node.displayName,
      for (final RecipeDefinition recipe in content.recipes.values)
        if (recipe.skill == skill &&
            recipe.requiredLevel > before &&
            recipe.requiredLevel <= after)
          recipe.displayName,
    ];
  }

  // -- The activity queue (`DECISIONS/0022`) ---------------------------------
  //
  // Three commands, each one event and one commit, single-flighted through
  // `_inFlight` exactly as `gather` is. The wall clock is read here — the one
  // seam — and carried into the command as data; nothing below reads it twice
  // for one command, so the figure the engine reasons about is the figure
  // this method observed. None of these touches `syncSteps`: reconciling a
  // queue is step *spending*, and health sync stays foreground-only (H-5).

  /// Begins a finite queue of [repetitions] at [node]. Spends nothing;
  /// every completion pays at its own reconciliation.
  Future<ActivityQueueReport> startActivityQueue(
    ContentId node,
    int repetitions, {
    required Duration repetitionDuration,
  }) async {
    final String name =
        registry?.resourceNodes[node]?.displayName ?? node.value;
    if (_inFlight) return _activityBusy(name);
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return _activityNotReady(name);
      }
      final EngineResult result = active.execute(
        StartActivityQueue(
          node: node,
          requested: repetitions,
          durationMillis: repetitionDuration.inMilliseconds,
          nowEpochMillis: activityWallClock(),
        ),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return ActivityQueueReport(
          succeeded: false,
          nodeName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return _activityCommitRefused(name, commit);
      }
      final ActivityQueueState queue = active.state.activityQueue!;
      return ActivityQueueReport(
        succeeded: true,
        nodeName: name,
        active: true,
        completedAfter: 0,
        requested: queue.requested,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Resolves every repetition the elapsed wall-clock time completed.
  ///
  /// Safe to call at any moment: with no queue, nothing elapsed, or a
  /// backward clock the engine accepts with no events and **nothing is
  /// committed** — a second reconcile straight after a first is a no-op.
  Future<ActivityQueueReport> reconcileActivityQueue() async {
    final ActivityQueueView? before = activityQueue;
    final String name = before == null
        ? '—'
        : registry?.resourceNodes[before.node]?.displayName ??
              before.node.value;
    if (_inFlight) return _activityBusy(name);
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return _activityNotReady(name);
      }
      final ContentId? queueSkill = before == null
          ? null
          : registry?.resourceNodes[before.node]?.skill;
      final int? levelBefore = queueSkill == null
          ? null
          : _skillLevelOf(queueSkill);
      final EngineResult result = active.execute(
        ReconcileActivityQueue(nowEpochMillis: activityWallClock()),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        // Unreachable today — the command refuses nothing — kept for the
        // honesty of the shape.
        return ActivityQueueReport(
          succeeded: false,
          nodeName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      if (result.events.isEmpty) {
        // The no-op success: nothing changed, nothing committed.
        return ActivityQueueReport(
          succeeded: true,
          nodeName: name,
          active: before != null,
          completedAfter: before?.completed ?? 0,
          requested: before?.requested ?? 0,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return _activityCommitRefused(name, commit);
      }
      final ActivityQueueReconciled event = result.events
          .whereType<ActivityQueueReconciled>()
          .first;
      final int? levelAfter = queueSkill == null
          ? null
          : _skillLevelOf(queueSkill);
      return ActivityQueueReport(
        succeeded: true,
        nodeName: name,
        completions: _completionLines(event.completions),
        active: !event.cleared,
        completedAfter: event.completedAfter,
        requested: before?.requested ?? event.completedAfter,
        stopReason: event.stopReason,
        skillLevelBefore: levelBefore,
        skillLevelAfter: levelAfter,
        unlockedNames: queueSkill == null
            ? const <String>[]
            : _unlocksOpened(queueSkill, levelBefore, levelAfter),
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Stops the queue: the closing reconciliation's whole repetitions commit,
  /// the partial one does not, and the queue clears (`DECISIONS/0022` §7).
  /// With no queue it is a trivial success — the exclusive-command seam
  /// issues it unconditionally.
  Future<ActivityQueueReport> stopActivityQueue() async {
    final ActivityQueueView? before = activityQueue;
    final String name = before == null
        ? '—'
        : registry?.resourceNodes[before.node]?.displayName ??
              before.node.value;
    if (_inFlight) return _activityBusy(name);
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return _activityNotReady(name);
      }
      final EngineResult result = active.execute(
        StopActivityQueue(nowEpochMillis: activityWallClock()),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return ActivityQueueReport(
          succeeded: false,
          nodeName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      if (result.events.isEmpty) {
        // No queue: nothing to stop, nothing committed.
        return ActivityQueueReport(succeeded: true, nodeName: name);
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return _activityCommitRefused(name, commit);
      }
      final ActivityQueueStopped event = result.events
          .whereType<ActivityQueueStopped>()
          .first;
      return ActivityQueueReport(
        succeeded: true,
        nodeName: name,
        completions: _completionLines(event.completions),
        active: false,
        completedAfter: event.completedAfter,
        requested: before?.requested ?? event.completedAfter,
        stopReason: event.stopReason,
      );
    } finally {
      _inFlight = false;
    }
  }

  ActivityQueueReport _activityBusy(String name) => ActivityQueueReport(
    succeeded: false,
    nodeName: name,
    rejection: 'session_busy',
    detail: 'another action is still running',
  );

  ActivityQueueReport _activityNotReady(String name) => ActivityQueueReport(
    succeeded: false,
    nodeName: name,
    rejection: 'session_not_ready',
    detail: _notReadyDetail,
  );

  ActivityQueueReport _activityCommitRefused(
    String name,
    CommitRefused commit,
  ) => ActivityQueueReport(
    succeeded: false,
    nodeName: name,
    rejection: 'commit_refused',
    detail: commit.reason.name,
  );

  /// Per-completion payloads, names resolved from content, figures copied
  /// from the committed event — never recomputed.
  List<ActivityCompletionLine> _completionLines(
    List<ActivityCompletion> completions,
  ) => <ActivityCompletionLine>[
    for (final ActivityCompletion c in completions)
      ActivityCompletionLine(
        stepsSpent: c.stepsSpent,
        itemName: registry?.items[c.item]?.displayName ?? c.item.value,
        quantity: c.quantity,
        skillName: registry?.skills[c.skill]?.displayName ?? c.skill.value,
        experience: c.experience,
      ),
  ];

  /// Walks a route, spending banked steps and arriving atomically.
  ///
  /// Single-flighted for the same reason [gather] is, and it matters more here:
  /// two concurrent journeys both validate against the same banked steps and
  /// both commit, so a double tap on a travel button would charge for one trip
  /// and take the player on two.
  Future<TravelReport> travel(ContentId destination) async {
    if (_inFlight) {
      return TravelReport(
        succeeded: false,
        destinationName: _locationName(destination),
        cost: 0,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      return await _travel(destination);
    } finally {
      _inFlight = false;
    }
  }

  Future<TravelReport> _travel(ContentId destination) async {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final String name = _locationName(destination);

    if (active == null || content == null || _stale || migrationPending) {
      return TravelReport(
        succeeded: false,
        destinationName: name,
        cost: 0,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
            : migrationPending
            ? 'the save is being brought up to date; sync steps first'
            : 'the game did not start',
      );
    }

    final EngineResult result = active.execute(
      TravelTo(destination: destination),
    );
    if (result case RejectedResult(:final CommandRejection rejection)) {
      return TravelReport(
        succeeded: false,
        destinationName: name,
        cost: 0,
        rejection: rejection.code.wire,
        detail: rejection.explanation,
      );
    }

    final LocationTravelled travelled = result.events
        .whereType<LocationTravelled>()
        .first;

    final CommitOutcome commit = await _commit(active, result.events);
    if (commit is CommitRefused) {
      // The engine moved the player and the disk did not take it. Stale rather
      // than reported as success: otherwise they are somewhere the next launch
      // will not agree they went, having paid for the trip.
      _stale = true;
      return TravelReport(
        succeeded: false,
        destinationName: name,
        cost: travelled.stepsSpent,
        rejection: 'commit_refused',
        detail: commit.reason.name,
      );
    }

    return TravelReport(
      succeeded: true,
      destinationName: name,
      // From the event, as charged — not from the connection, which is a base
      // value the profile scales.
      cost: travelled.stepsSpent,
      firstVisit: travelled.firstVisit,
    );
  }

  /// Turns held materials into an item, and commits it atomically.
  ///
  /// Costs no steps (`GAME_BIBLE/SYSTEMS/04`), so this is the one mutating
  /// action that still works at a zero balance.
  Future<CraftReport> craft(ContentId recipe) async {
    if (_inFlight) {
      return CraftReport(
        succeeded: false,
        recipeName: registry?.recipes[recipe]?.displayName ?? recipe.value,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      return await _craft(recipe);
    } finally {
      _inFlight = false;
    }
  }

  Future<CraftReport> _craft(ContentId recipe) async {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final String name = content?.recipes[recipe]?.displayName ?? recipe.value;

    if (active == null || content == null || _stale || migrationPending) {
      return CraftReport(
        succeeded: false,
        recipeName: name,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
            : migrationPending
            ? 'the save is being brought up to date; sync steps first'
            : 'the game did not start',
      );
    }

    final RecipeDefinition? definition = content.recipes[recipe];
    final int? levelBefore = definition == null
        ? null
        : _skillLevelOf(definition.skill);
    // The stat story against what is worn NOW, captured before the craft so
    // "what you have" cannot already be the crafted item.
    final EquipDelta? delta = definition == null
        ? null
        : _equipDeltaFor(content.items[definition.outputItem], active.state);

    final EngineResult result = active.execute(CraftItem(recipe: recipe));
    if (result case RejectedResult(:final CommandRejection rejection)) {
      return CraftReport(
        succeeded: false,
        recipeName: name,
        rejection: rejection.code.wire,
        detail: rejection.explanation,
      );
    }

    final CommitOutcome commit = await _commit(active, result.events);
    if (commit is CommitRefused) {
      // The ingredients are gone in memory and the disk did not take it. Stale,
      // for the same reason as everywhere else: reporting success would show
      // the player an ingot that disappears on the next launch, along with the
      // ore they walked for.
      _stale = true;
      return CraftReport(
        succeeded: false,
        recipeName: name,
        rejection: 'commit_refused',
        detail: commit.reason.name,
      );
    }

    final ItemCrafted crafted = result.events.whereType<ItemCrafted>().first;
    final int? levelAfter = _skillLevelOf(crafted.skill);
    return CraftReport(
      succeeded: true,
      recipeName: name,
      outputItemId: crafted.item,
      outputName:
          content.items[crafted.item]?.displayName ?? crafted.item.value,
      outputRarity: content.items[crafted.item]?.rarity,
      quantity: crafted.quantity,
      skillName:
          content.skills[crafted.skill]?.displayName ?? crafted.skill.value,
      experience: crafted.experience,
      skillLevelBefore: levelBefore,
      skillLevelAfter: levelAfter,
      unlockedNames: _unlocksOpened(crafted.skill, levelBefore, levelAfter),
      equipDelta: delta,
    );
  }

  /// The stat story of crafting [item] against what currently occupies its
  /// slot, or null for anything that is not equipment.
  EquipDelta? _equipDeltaFor(ItemDefinition? item, GameState state) {
    final EquipmentSlot? slot = item?.slot;
    if (item == null || slot == null) return null;
    final ContentId? wornId = state.equipment.inSlot(slot);
    final ItemDefinition? worn = wornId == null
        ? null
        : registry?.items[wornId];
    if (slot == EquipmentSlot.tool) {
      return EquipDelta.tool(
        toolLine: '${toolProfessionOf(item.toolKind)} tool · Tier ${item.tier}',
        replaces: worn == null
            ? null
            : '${worn.displayName} · ${toolProfessionOf(worn.toolKind)} tool'
                  ' · Tier ${worn.tier}',
        swapsProfession: worn != null && worn.toolKind != item.toolKind,
      );
    }
    final String statName = switch (slot) {
      EquipmentSlot.weapon => 'Attack',
      EquipmentSlot.armor => 'Defence',
      EquipmentSlot.tool => 'Tool',
    };
    return EquipDelta(
      slot: slot,
      statName: statName,
      before: worn?.power ?? 0,
      after: item.power,
    );
  }

  // -- Equipment ------------------------------------------------------------

  /// Wears or wields an owned item, and commits it atomically.
  ///
  /// Costs no steps. Allowed during an encounter — the engine snapshotted the
  /// fight's figures at its start, so this changes the *next* fight only
  /// (`GAME_BIBLE/COMBAT/02` §8).
  Future<EquipReport> equip(ContentId item) =>
      _equipment(EquipItem(item: item), item);

  /// Empties [slot], and commits it atomically.
  Future<EquipReport> unequip(EquipmentSlot slot) =>
      _equipment(UnequipItem(slot: slot), engine?.state.equipment.inSlot(slot));

  /// Begins a fresh playtest (`DECISIONS/0025`): the spendable balance and
  /// the player-facing walked figure start again from zero; with
  /// [freshStart] so does the game. The step ledger's counters, dedupe
  /// slices, watermarks and cursor are untouched — the reset moves a mark,
  /// and the next sync reads forward from where the last one stopped.
  ///
  /// Single-flighted like every other command, committed through the same
  /// single-writer path. The owner's own control; confirmed on the Character
  /// tab before it is dispatched.
  Future<PlaytestResetReport> resetPlaytest({required bool freshStart}) async {
    if (_inFlight) {
      return PlaytestResetReport(
        succeeded: false,
        freshStart: freshStart,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return PlaytestResetReport(
          succeeded: false,
          freshStart: freshStart,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      final int bankedBefore = active.state.steps.banked;
      final int walkedBefore = active.state.steps.walkedSinceBaseline;
      final EngineResult result = active.execute(
        ResetPlaytest(
          freshStart: freshStart,
          stateVersion: StateVersion.current.value,
        ),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return PlaytestResetReport(
          succeeded: false,
          freshStart: freshStart,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return PlaytestResetReport(
          succeeded: false,
          freshStart: freshStart,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      return PlaytestResetReport(
        succeeded: true,
        freshStart: freshStart,
        retiredBanked: bankedBefore,
        walkedRetired: walkedBefore,
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<EquipReport> _equipment(GameCommand command, ContentId? item) async {
    final String name = item == null
        ? '—'
        : registry?.items[item]?.displayName ?? item.value;
    if (_inFlight) {
      return EquipReport(
        succeeded: false,
        itemName: name,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      final ContentRegistry? content = registry;
      if (active == null || content == null || _stale || migrationPending) {
        return EquipReport(
          succeeded: false,
          itemName: name,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      // The combat figures before, so a successful swap can say its story —
      // "ATK 7 → 9" — from the same `loadoutFor` the engine snapshots
      // fights with (Fable V2, `DECISIONS/0027`). Weapon and armor only:
      // profession tools are never power-compared, by owner ruling.
      final PlayerCombatLoadout before = CombatRules.loadoutFor(
        active.state,
        content,
      );
      final EngineResult result = active.execute(command);
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return EquipReport(
          succeeded: false,
          itemName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return EquipReport(
          succeeded: false,
          itemName: name,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      final PlayerCombatLoadout after = CombatRules.loadoutFor(
        active.state,
        content,
      );
      final EquipmentSlot? slot = item == null
          ? null
          : content.items[item]?.slot;
      return EquipReport(
        succeeded: true,
        itemName: name,
        statLabel: switch (slot) {
          EquipmentSlot.weapon => 'ATK',
          EquipmentSlot.armor => 'DEF',
          _ => null,
        },
        statBefore: switch (slot) {
          EquipmentSlot.weapon => before.attack,
          EquipmentSlot.armor => before.defence,
          _ => null,
        },
        statAfter: switch (slot) {
          EquipmentSlot.weapon => after.attack,
          EquipmentSlot.armor => after.defence,
          _ => null,
        },
      );
    } finally {
      _inFlight = false;
    }
  }

  // -- Combat (Combat Slice 01, `DECISIONS/0020`) ---------------------------
  //
  // Four commands, each one round and one commit, single-flighted through
  // `_inFlight` exactly as `gather` is and for the same reason: two concurrent
  // rounds would both compute against the same encounter and the loser's
  // commit would be refused as a compare-and-swap conflict — a real refusal
  // manufactured by a double tap. The reports narrate the round from the
  // engine's events (`CombatBeat`) so a stage never diffs state to find out
  // what happened.

  /// Begins a fight with [enemy] where the player stands. Costs no steps.
  Future<CombatReport> startEncounter(ContentId enemy) =>
      _combat(StartEncounter(enemy: enemy), enemy);

  /// One round: the player strikes, then the enemy replies unless it fell.
  Future<CombatReport> combatAttack() =>
      _combat(const CombatAttack(), engine?.state.encounter?.enemy);

  /// One round: the player eats one [item], then the enemy replies.
  Future<CombatReport> combatEat(ContentId item) =>
      _combat(CombatEat(item: item), engine?.state.encounter?.enemy);

  /// One round: the player braces — deals nothing — and the enemy's reply
  /// lands at half damage (`DECISIONS/0027`, experimental).
  Future<CombatReport> combatBrace() =>
      _combat(const CombatBrace(), engine?.state.encounter?.enemy);

  /// Leaves the fight for the nearest safe place. Nothing is lost.
  Future<CombatReport> combatRetreat() =>
      _combat(const CombatRetreat(), engine?.state.encounter?.enemy);

  Future<CombatReport> _combat(GameCommand command, ContentId? enemy) async {
    final String name = enemy == null
        ? '—'
        : registry?.enemies[enemy]?.displayName ?? enemy.value;
    if (_inFlight) {
      return CombatReport(
        succeeded: false,
        enemyName: name,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      return await _combatRound(command, name);
    } finally {
      _inFlight = false;
    }
  }

  Future<CombatReport> _combatRound(GameCommand command, String name) async {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;

    if (active == null || content == null || _stale || migrationPending) {
      return CombatReport(
        succeeded: false,
        enemyName: name,
        rejection: 'session_not_ready',
        detail: _notReadyDetail,
      );
    }

    final EngineResult result = active.execute(command);
    if (result case RejectedResult(:final CommandRejection rejection)) {
      return CombatReport(
        succeeded: false,
        enemyName: name,
        rejection: rejection.code.wire,
        detail: rejection.explanation,
      );
    }

    final CommitOutcome commit = await _commit(active, result.events);
    if (commit is CommitRefused) {
      // The engine resolved the round and the disk did not take it. Stale
      // rather than reported as success: the player would otherwise watch a
      // blow land that the next launch never saw.
      _stale = true;
      return CombatReport(
        succeeded: false,
        enemyName: name,
        rejection: 'commit_refused',
        detail: commit.reason.name,
      );
    }

    return CombatReport(
      succeeded: true,
      enemyName: name,
      events: <CombatBeat>[
        for (final GameEvent event in result.events)
          if (_beatOf(event, content) case final CombatBeat beat) beat,
      ],
    );
  }

  /// One event to one beat. Every figure is copied from the event; names come
  /// from content. Non-combat events (none are expected in a combat result)
  /// produce no beat.
  static CombatBeat? _beatOf(GameEvent event, ContentRegistry content) {
    String itemName(ContentId id) => content.items[id]?.displayName ?? id.value;
    String placeName(ContentId id) =>
        content.locations[id]?.displayName ?? id.value;
    return switch (event) {
      EncounterStarted(:final ContentId enemy) => EncounterStartedBeat(
        enemyName: content.enemies[enemy]?.displayName ?? enemy.value,
        playerHp: event.playerHp,
        playerMaxHp: event.playerMaxHp,
        enemyHp: event.enemyHp,
        enemyMaxHp: event.enemyMaxHp,
      ),
      CombatPlayerStruck() => PlayerStruckBeat(
        damage: event.damage,
        enemyHpAfter: event.enemyHpAfter,
        quality: _qualityOf(event.roll),
      ),
      CombatConsumableUsed() => ConsumableUsedBeat(
        itemName: itemName(event.item),
        healed: event.healed,
        playerHpAfter: event.playerHpAfter,
      ),
      CombatBraced() => const BracedBeat(),
      CombatEnemyStruck() => EnemyStruckBeat(
        damage: event.damage,
        playerHpAfter: event.playerHpAfter,
        heavy: event.heavy,
        strikeIndex: event.strikeIndex,
        quality: _qualityOf(event.roll),
      ),
      CombatRoundEnded() => RoundEndedBeat(
        turn: event.turn,
        telegraph: event.telegraph,
      ),
      EncounterWon() => () {
        final EnemyDefinition? enemy = content.enemies[event.enemy];
        final int? after = event.victoriesAfter;
        KnowledgeTier tierAt(int victories) => enemy == null
            ? KnowledgeTier.seen
            : victories >= enemy.knownAt
            ? KnowledgeTier.known
            : victories >= enemy.studiedAt
            ? KnowledgeTier.studied
            : KnowledgeTier.seen;
        return WonBeat(
          xp: event.characterXp,
          levelBefore: event.levelBefore,
          levelAfter: event.levelAfter,
          enemyName: enemy?.displayName ?? event.enemy.value,
          drops: <RewardLine>[
            for (final MapEntry<ContentId, int> d in event.drops.entries)
              RewardLine(
                id: d.key,
                name: itemName(d.key),
                quantity: d.value,
                rarity: content.items[d.key]?.rarity,
              ),
          ],
          knowledgeBefore: after == null ? null : tierAt(after - 1),
          knowledgeAfter: after == null ? null : tierAt(after),
          knowledgeXp: event.knowledgeXp,
          understoodDrops: <String>[
            if (enemy != null)
              for (final EnemyDrop drop in enemy.drops)
                if (!drop.signature) itemName(drop.item),
          ],
          signatureDrops: <String>[
            if (enemy != null)
              for (final EnemyDrop drop in enemy.drops)
                if (drop.signature) itemName(drop.item),
          ],
          bountyProgress: <BountyProgressLine>[
            for (final MapEntry<ContentId, int> b
                in event.bountyProgress.entries)
              if (content.contracts[b.key] case final ContractDefinition c
                  when c.bountyEnemy != null)
                BountyProgressLine(
                  contractName: c.displayName,
                  progress: b.value,
                  required: c.bountyCount,
                ),
          ],
        );
      }(),
      EncounterLost() => LostBeat(
        retreatToName: placeName(event.retreatTo),
        healed: event.restoredHp != null,
      ),
      EncounterRetreated() => RetreatedBeat(
        retreatToName: placeName(event.retreatTo),
      ),
      _ => null,
    };
  }

  String get _notReadyDetail => _stale
      ? 'the last commit did not land; reload before acting'
      : migrationPending
      ? 'the save is being brought up to date; sync steps first'
      : 'the game did not start';

  String _locationName(ContentId location) =>
      registry?.locations[location]?.displayName ?? location.value;

  /// How many of [item] the player holds.
  int inventoryCount(ContentId item) =>
      engine?.state.inventory.quantityOf(item) ?? 0;

  /// The player's current location, by display name.
  String get locationName {
    final ContentId? here = engine?.state.world.currentLocation;
    if (here == null) return '—';
    return registry?.locations[here]?.displayName ?? here.value;
  }

  /// The player's current location. Null before the game starts.
  ContentId? get currentLocation => engine?.state.world.currentLocation;

  // -- The UI read model ----------------------------------------------------
  //
  // Everything below exists so that a widget never has to reach through
  // `engine` or `runtime` to render a screen. That reach is what makes E-2
  // unenforceable: `engine.execute(...)` mutates durable state in memory with
  // no commit and no staleness, `runtime.repository` is a second write path
  // around compare-and-swap, and `runtime.healthKeyingSalt` is a raw
  // device-bound secret that H-7 forbids ever rendering.
  //
  // With these accessors in place, `Scripts/check-ui-boundary.sh` can forbid
  // `.engine`, `.runtime` and `.health` under `lib/ui/` outright, which turns
  // E-2 from a rule people remember into a rule the tree enforces.
  //
  // Each one is a projection. None holds state, none caches, and none decides a
  // game rule — levels come from the content curve's own `levelAt`, not from
  // arithmetic here.

  /// The player's character level. Stored, unlike skill levels.
  int get characterLevel => engine?.state.player.level ?? 0;

  /// Everything the player holds, in a stable order.
  ///
  /// Ordered because `Inventory.counts` is a `SplayTreeMap` keyed by
  /// [ContentId], so iteration is identical across runs and platforms — a grid
  /// that reshuffles between launches would look like a bug. Zero-quantity
  /// entries cannot appear: the inventory drops a key at zero so that "absent"
  /// and "zero" cannot both exist and disagree.
  List<InventoryEntry> get inventoryEntries {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <InventoryEntry>[];
    return <InventoryEntry>[
      for (final MapEntry<ContentId, int> e
          in active.state.inventory.counts.entries)
        InventoryEntry(
          id: e.key,
          displayName: content.items[e.key]?.displayName ?? e.key.value,
          category: content.items[e.key]?.category,
          rarity: content.items[e.key]?.rarity,
          count: e.value,
        ),
    ];
  }

  /// Every occupied equipment slot, in slot order, with rarity.
  ///
  /// `Equipment.bySlot` is ordered by slot rather than by insertion, so the
  /// Character screen's three lines do not reshuffle when the player swaps a
  /// weapon.
  List<EquippedSummary> get equippedSummary {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <EquippedSummary>[];
    return <EquippedSummary>[
      for (final MapEntry<EquipmentSlot, ContentId> e
          in active.state.equipment.bySlot.entries)
        EquippedSummary(
          slot: e.key,
          itemId: e.value,
          displayName: content.items[e.value]?.displayName ?? e.value.value,
          rarity: content.items[e.value]?.rarity,
          power: content.items[e.value]?.power ?? 0,
        ),
    ];
  }

  /// The equipped loadout as **visual facts** — the projection every
  /// Traveler-drawing surface resolves its art through
  /// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5; `TravelerArt`).
  ///
  /// Read straight off the same `Equipment.bySlot` the engine consults, on
  /// demand, holding nothing (`RULES.md` E-2) — and deliberately **facts,
  /// not art keys**: which strip a fact selects is the presentation
  /// layer's table, so an art round changes no session code. Lives here
  /// beside [gearStatsOf] rather than in `stride_core` because variant
  /// vocabulary is art-coupled packaging fact, not engine content.
  EquipmentVisualState get equipmentVisualState {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) {
      return const EquipmentVisualState();
    }
    EquippedVisualFact? factFor(EquipmentSlot slot) {
      final ContentId? worn = active.state.equipment.bySlot[slot];
      if (worn == null) return null;
      final ItemDefinition? def = content.items[worn];
      return EquippedVisualFact(
        itemId: worn.value,
        tier: def?.tier ?? 0,
        toolKind: (def?.toolKind ?? ToolKind.none).name,
      );
    }

    return EquipmentVisualState(
      weapon: factFor(EquipmentSlot.weapon),
      armor: factFor(EquipmentSlot.armor),
      tool: factFor(EquipmentSlot.tool),
    );
  }

  // -- Derived upgrade lineage (`DECISIONS/0028` §6) ------------------------

  /// The equipment lineage map, computed once per content load and never
  /// authored: for every recipe whose ingredients include a piece of
  /// equipment AND whose output is equipment, an edge from the consumed
  /// piece to the produced one. Both-ends-equipment keeps material-consuming
  /// crafts (and the reclaim recipes' ingot outputs) out of the lineage —
  /// reclaims surface through the bench's trade lines instead.
  ///
  /// Cached by registry identity: the fold is over static content, so it is
  /// wrong to recompute per build and wrong to survive a content reload.
  /// Progress-dependent filtering (a retired recipe is not a live upgrade)
  /// happens at read time in [itemLineageOf], so the cache stays load-stable.
  Map<ContentId, ItemLineageView>? _lineageCache;
  ContentRegistry? _lineageCacheFor;

  ItemLineageView? itemLineageOf(ContentId item) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    if (!identical(_lineageCacheFor, content)) {
      _lineageCache = _buildLineage(content);
      _lineageCacheFor = content;
    }
    final ItemLineageView? cached = _lineageCache![item];
    if (cached == null) return null;
    // A retired recipe is not a live upgrade — the same rule itemPurposeOf
    // applies to USED IN.
    bool live(LineageEdge e) {
      final RecipeDefinition? r = content.recipes[e.recipeId];
      if (r == null) return false;
      return !(r.retiredByProject != null &&
          active.state.progress.isProjectComplete(r.retiredByProject!));
    }

    final List<LineageEdge> to = cached.upgradesTo.where(live).toList();
    final List<LineageEdge> from = cached.upgradesFrom.where(live).toList();
    if (to.isEmpty && from.isEmpty) return null;
    return ItemLineageView(upgradesTo: to, upgradesFrom: from);
  }

  static Map<ContentId, ItemLineageView> _buildLineage(
    ContentRegistry content,
  ) {
    final Map<ContentId, List<LineageEdge>> to = <ContentId, List<LineageEdge>>{};
    final Map<ContentId, List<LineageEdge>> from =
        <ContentId, List<LineageEdge>>{};
    for (final RecipeDefinition r in content.recipes.values) {
      final ItemDefinition? output = content.items[r.outputItem];
      if (output == null || output.category != ItemCategory.equipment) {
        continue;
      }
      for (final RecipeIngredient i in r.ingredients) {
        final ItemDefinition? consumed = content.items[i.item];
        if (consumed == null ||
            consumed.category != ItemCategory.equipment) {
          continue;
        }
        final LineageEdge edge = LineageEdge(
          recipeId: r.id,
          recipeName: r.displayName,
          fromItem: i.item,
          fromName: consumed.displayName,
          toItem: r.outputItem,
          toName: output.displayName,
          quantity: i.quantity,
        );
        (to[i.item] ??= <LineageEdge>[]).add(edge);
        (from[r.outputItem] ??= <LineageEdge>[]).add(edge);
      }
    }
    return <ContentId, ItemLineageView>{
      for (final ContentId id in <ContentId>{...to.keys, ...from.keys})
        id: ItemLineageView(
          upgradesTo: List<LineageEdge>.unmodifiable(
            to[id] ?? const <LineageEdge>[],
          ),
          upgradesFrom: List<LineageEdge>.unmodifiable(
            from[id] ?? const <LineageEdge>[],
          ),
        ),
    };
  }

  /// What [item] is *for* — every consumer and source the content pack
  /// names, as display strings (Fable V2, `DECISIONS/0027`). Null for an
  /// item the pack does not define.
  ///
  /// A fold over the registry and current progress, computed on demand for
  /// the one tapped tile; nothing here decides a rule (`RULES.md` E-2).
  /// Built because a Boar Tusk, an Ember Core and a Bronze Ingot were
  /// indistinguishable in purpose from the grid — and a signature trophy
  /// looked like a craft material whose recipe the player had not found.
  ItemPurposeView? itemPurposeOf(ContentId item) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final ItemDefinition? def = content?.items[item];
    if (active == null || content == null || def == null) return null;
    final GameState state = active.state;

    String placeOf(ContentId location) =>
        content.locations[location]?.displayName ?? location.value;

    // An upgrade edge is the stronger statement, so its recipe leaves the
    // USED IN list — "upgrades into" and "used in" saying the same recipe
    // twice would read as two different uses (`DECISIONS/0028` §6).
    final ItemLineageView? lineage = itemLineageOf(item);
    final Set<ContentId> lineageRecipes = <ContentId>{
      for (final LineageEdge e in lineage?.upgradesTo ?? const <LineageEdge>[])
        e.recipeId,
    };

    final List<String> usedInRecipes = <String>[
      for (final RecipeDefinition r in content.recipes.values)
        if (r.ingredients.any((RecipeIngredient i) => i.item == item) &&
            !lineageRecipes.contains(r.id) &&
            // A retired recipe is not a live use.
            !(r.retiredByProject != null &&
                state.progress.isProjectComplete(r.retiredByProject!)))
          r.displayName,
    ]..sort();

    final List<String> wantedBy = <String>[
      for (final ContractDefinition c in content.contracts.values)
        if (c.requires.any((ItemQuantity q) => q.item == item) &&
            // A one-time contract already completed wants nothing now.
            !(c.contractClass == ContractClass.regional &&
                state.progress.completionsOf(c.id) > 0))
          '${c.displayName} — ${placeOf(c.location)}',
      // Shown-and-kept requirements count as wanting too — the Scholar asks
      // to *see* the Sigil, and a purpose block that missed that would call
      // this sprint's own flagship a dead keepsake (final review finding).
      for (final ContractDefinition c in content.contracts.values)
        if (c.requiresOwned.contains(item) &&
            !(c.contractClass == ContractClass.regional &&
                state.progress.completionsOf(c.id) > 0))
          '${c.displayName} — ${placeOf(c.location)} (shown, kept)',
      for (final ProjectDefinition p in content.projects.values)
        if (!state.progress.isProjectComplete(p.id) &&
            p.stages.any(
              (ProjectStage s) =>
                  s.requires.any((ItemQuantity q) => q.item == item),
            ))
          '${p.displayName} — ${placeOf(p.location)}',
    ]..sort();

    final List<String> gatheredAt = <String>[
      for (final ResourceNodeDefinition n in content.resourceNodes.values)
        if (n.yieldsItem == item)
          '${n.displayName}${_hostOf(n.id, content) == null ? '' : ', ${_hostOf(n.id, content)}'}',
    ]..sort();

    final List<String> droppedBy = <String>[
      for (final EnemyDefinition e in content.enemies.values)
        if (e.drops.any((EnemyDrop d) => d.item == item))
          '${e.displayName} — ${placeOf(e.location)}',
    ]..sort();

    final List<String> craftedBy = <String>[
      for (final RecipeDefinition r in content.recipes.values)
        if (r.outputItem == item &&
            !(r.retiredByProject != null &&
                state.progress.isProjectComplete(r.retiredByProject!)))
          r.displayName,
    ]..sort();

    final bool signature = content.enemies.values.any(
      (EnemyDefinition e) =>
          e.drops.any((EnemyDrop d) => d.item == item && d.signature),
    );
    final bool hasConsumer = usedInRecipes.isNotEmpty || wantedBy.isNotEmpty;

    return ItemPurposeView(
      usedInRecipes: usedInRecipes,
      wantedBy: wantedBy,
      gatheredAt: gatheredAt,
      droppedBy: droppedBy,
      craftedBy: craftedBy,
      upgradesInto: lineage?.upgradesTo ?? const <LineageEdge>[],
      reforgedFrom: lineage?.upgradesFrom ?? const <LineageEdge>[],
      healing: def.healing,
      // A hunter's proof: a signature (or the boss's quest token) that
      // nothing consumes is a keepsake by design (`DECISIONS/0023` §5),
      // and saying so is what stops it reading as a recipe not yet found.
      isTrophy:
          !hasConsumer && (signature || def.category == ItemCategory.quest),
    );
  }

  /// What [item] does as equipment, against what is worn in its slot — or
  /// null for anything that is not equipment, or that the pack does not
  /// define. See [GearStats].
  GearStats? gearStatsOf(ContentId item) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final ItemDefinition? def = content?.items[item];
    final EquipmentSlot? slot = def?.slot;
    if (active == null || content == null || def == null || slot == null) {
      return null;
    }
    final ContentId? wornId = active.state.equipment.inSlot(slot);
    final ItemDefinition? worn = wornId == null ? null : content.items[wornId];
    final int wornPower = worn?.power ?? 0;
    // A tool is judged by tier within its own profession, and a tool of
    // another profession is a swap — never a power comparison, because the
    // engine reads no tool power and an axe does not out-mine a pickaxe.
    final bool tool = slot == EquipmentSlot.tool;
    final int mine = tool ? def.tier : def.power;
    final int theirs = tool ? (worn?.tier ?? 0) : wornPower;
    final GearVerdict verdict = wornId == item
        ? GearVerdict.equipped
        : wornId == null
        ? GearVerdict.firstInSlot
        : tool && worn != null && worn.toolKind != def.toolKind
        ? GearVerdict.toolSwap
        : mine > theirs
        ? GearVerdict.upgrade
        : mine < theirs
        ? GearVerdict.downgrade
        : GearVerdict.sidegrade;
    final (String statName, String statShort) = switch (slot) {
      EquipmentSlot.weapon => ('Attack', 'ATK'),
      EquipmentSlot.armor => ('Defence', 'DEF'),
      EquipmentSlot.tool => ('Tool power', 'TOOL'),
    };
    final List<String> passives = _passiveLinesOf(content, def);
    // What equipping this piece gives up: the worn piece's passive sentences
    // that the candidate does not carry, built by the same builder so gain
    // and loss are verbatim mirrors — equipping over frostGuard or a yield
    // passive should never be a quiet surprise (`DECISIONS/0028` §6).
    final List<String> wornPassives = worn == null || wornId == item
        ? const <String>[]
        : _passiveLinesOf(content, worn);
    final List<String> tradeOffLines = <String>[
      for (final String line in wornPassives)
        if (!passives.contains(line)) line,
    ];
    // The derived lineage's forward pointer — "reforges into X" — so the
    // player learns an item's future before spending it.
    final LineageEdge? nextEdge = itemLineageOf(item)?.upgradesTo.firstOrNull;
    return GearStats(
      item: item,
      slot: slot,
      statName: statName,
      statShort: statShort,
      power: def.power,
      tier: def.tier,
      toolKind: def.toolKind,
      passives: passives,
      wornName: worn?.displayName ?? (wornId?.value),
      wornPower: wornPower,
      verdict: verdict,
      wornToolKind: worn?.toolKind,
      wornTier: worn?.tier ?? 0,
      tradeOffLines: tradeOffLines,
      upgradeLine: nextEdge == null
          ? null
          : 'Reforges into ${nextEdge.toName}'
                '${content.items[nextEdge.toItem] == null ? '' : ' ($statShort ${content.items[nextEdge.toItem]!.power})'}',
    );
  }

  /// The passive sentences a piece of equipment carries — one builder for
  /// both the candidate and the worn piece, so a gained and a lost passive
  /// are the same sentence.
  static List<String> _passiveLinesOf(
    ContentRegistry content,
    ItemDefinition def,
  ) => <String>[
    // A tool names the sites it actually opens, from the same node data
    // the engine gates gathering on — never a tier abstraction alone
    // (this pass, §5: "Tier 1" is functional; "Mines Copper Ore, Tin
    // Ore" is a reason to want the tool). The tier line stays as the
    // rule the names are instances of.
    if (def.toolKind != ToolKind.none) ...<String>[
      'Works ${def.toolKind == ToolKind.axe ? 'woodcutting' : 'mining'} '
          'sites up to tier ${def.tier}',
      ..._toolSiteLines(content, def),
    ],
    if (def.frostGuard > 0)
      'Cold weather: −${def.frostGuard} damage taken in alpine fights',
    if (def.wildernessYieldPercent > 0)
      'Wilderness ready: ${def.wildernessYieldPercent}% chance of +1 '
          'yield when woodcutting or foraging',
    if (def.toolBonusYieldPercent > 0)
      '${def.toolBonusYieldPercent}% chance of +1 yield at sites this '
          'tool works',
  ];

  /// The named-site lines a tool's passives carry: which sites in the pack
  /// this tool opens, what they yield, and — when the pack holds one — the
  /// first site the *next* tier would open. All read from the same
  /// `ResourceNodeDefinition` fields (`requiredToolKind`,
  /// `minimumToolTier`, `yieldsItem`) the engine validates a gather with,
  /// so the sentence and the gate cannot disagree.
  static List<String> _toolSiteLines(
    ContentRegistry content,
    ItemDefinition def,
  ) {
    final List<ResourceNodeDefinition> ofKind = content.resourceNodes.values
        .where((ResourceNodeDefinition n) => n.requiredToolKind == def.toolKind)
        .toList();
    if (ofKind.isEmpty) return const <String>[];

    final List<ResourceNodeDefinition> works =
        ofKind
            .where((ResourceNodeDefinition n) => n.minimumToolTier <= def.tier)
            .toList()
          // Tier order, so the sentence reads as the progression: the sites a
          // training tool opens first, the ones a better one added after. The
          // id is the tie-break because `List.sort` is not stable.
          ..sort((ResourceNodeDefinition a, ResourceNodeDefinition b) {
            final int byTier = a.minimumToolTier.compareTo(b.minimumToolTier);
            return byTier != 0 ? byTier : a.id.value.compareTo(b.id.value);
          });
    final List<ResourceNodeDefinition> beyond = ofKind
        .where((ResourceNodeDefinition n) => n.minimumToolTier > def.tier)
        .toList();

    // Site names, not yield names: the Hardened Copper Seam yields the same
    // ore the Copper Seam does, so a yield list makes a tier-2 pick read
    // identical to a tier-0 one — and access is exactly what the better
    // tool buys.
    String sites(Iterable<ResourceNodeDefinition> nodes) {
      final Set<String> seen = <String>{};
      final List<String> names = <String>[];
      for (final ResourceNodeDefinition n in nodes) {
        if (seen.add(n.displayName)) names.add(n.displayName);
      }
      return names.join(', ');
    }

    // The next tier's gap is one line naming the nearest locked site, not a
    // catalogue: the point is "a better tool matters", said with a real
    // place. Sorted so "nearest" is deterministic.
    beyond.sort((ResourceNodeDefinition a, ResourceNodeDefinition b) {
      final int byTier = a.minimumToolTier.compareTo(b.minimumToolTier);
      return byTier != 0 ? byTier : a.id.value.compareTo(b.id.value);
    });
    return <String>[
      if (works.isNotEmpty)
        '${def.toolKind == ToolKind.axe ? 'Chops' : 'Mines'}: '
            '${sites(works)}',
      if (beyond.isNotEmpty)
        'Tier ${beyond.first.minimumToolTier} opens '
            '${beyond.first.displayName}',
    ];
  }

  /// The item worn or wielded in [slot], or null when the slot is empty.
  ///
  /// Read straight off `Equipment.inSlot` — the same lookup `GameEngine` makes
  /// when a gather asks for a tool or a fight reads the weapon — so the slot
  /// the screen shows is the slot the rules consult.
  ContentId? equippedIn(EquipmentSlot slot) =>
      engine?.state.equipment.inSlot(slot);

  /// Whether [item] currently occupies any equipment slot.
  bool isEquipped(ContentId item) =>
      engine?.state.equipment.isEquipped(item) ?? false;

  /// Every skill in the content pack, with its level derived from the curve.
  ///
  /// The level comes from [SkillDefinition.levelAt] — the same function
  /// `GameEngine` gates gathering on. That is deliberate and it is the whole
  /// reason this projection exists rather than the UI walking `xpThresholds`
  /// itself: two implementations of a level curve agree until they don't, and
  /// the disagreement would be invisible.
  List<SkillSummary> get skillSummaries {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <SkillSummary>[];
    return <SkillSummary>[
      for (final MapEntry<ContentId, SkillDefinition> e
          in content.skills.entries)
        SkillSummary(
          id: e.key,
          displayName: e.value.displayName,
          experience: active.state.skills.experienceIn(e.key),
          level: e.value.levelAt(active.state.skills.experienceIn(e.key)),
          maxLevel: e.value.maxLevel,
        ),
    ];
  }

  /// Total experience across every skill.
  int get totalSkillExperience {
    final GameEngine? active = engine;
    if (active == null) return 0;
    return active.state.skills.experienceBySkill.values.fold(
      0,
      (int a, int b) => a + b,
    );
  }

  /// The fight in progress, or null. Read live from the engine's snapshot;
  /// nothing is cached, so a reload that restores an encounter shows it.
  EncounterView? get encounter {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final EncounterState? e = active?.state.encounter;
    if (active == null || content == null || e == null) return null;
    final EnemyDefinition? enemy = content.enemies[e.enemy];
    return EncounterView(
      enemyId: e.enemy,
      enemyName: enemy?.displayName ?? e.enemy.value,
      location: e.location,
      locationName: _locationName(e.location),
      turn: e.turn,
      playerHp: e.playerHp,
      playerMaxHp: e.playerMaxHp,
      playerAttack: e.playerAttack,
      playerDefence: e.playerDefence,
      enemyHp: e.enemyHp,
      enemyMaxHp: e.enemyMaxHp,
      telegraph: e.telegraph,
      behavior: enemy?.behavior ?? EnemyBehavior.steady,
      isBoss: enemy?.isBoss ?? false,
      knowledge: enemy == null
          ? KnowledgeTier.unseen
          : knowledgeTierFor(active.state, enemy),
      intentLine: enemy == null
          ? null
          : _intentLineFor(
              enemy,
              knowledgeTierFor(active.state, enemy),
              e.telegraph,
            ),
    );
  }

  /// What the enemy will do this round, in words earned by knowledge
  /// (`DECISIONS/0027`, experimental). A translation of engine facts the
  /// resolver already guarantees — behaviour's strike count, the guarded
  /// telegraph — never a new rule (`RULES.md` E-2).
  ///
  /// Unseen: nothing. Seen: the strike count, or "something heavy" on a
  /// telegraph turn — no more than the telegraph itself already shows.
  /// Studied and Known: the creature's authored tell — except that a
  /// *guarded* creature's tell describes its heavy, so it shows only on the
  /// telegraph turn; the other two turns say the ordinary strike, or the
  /// line would tell the player to brace against a blow that is not coming
  /// (the final review's finding — truthfulness is this feature's whole
  /// point).
  static String? _intentLineFor(
    EnemyDefinition enemy,
    KnowledgeTier tier,
    bool telegraph,
  ) {
    if (tier == KnowledgeTier.unseen) return null;
    final String count = enemy.behavior == EnemyBehavior.flurry
        ? 'It will strike twice.'
        : 'It will strike once.';
    if (tier == KnowledgeTier.seen) {
      return telegraph ? 'It is winding up something heavy.' : count;
    }
    final String tell = enemy.tellLine.isEmpty ? count : enemy.tellLine;
    if (enemy.behavior == EnemyBehavior.guarded) {
      return telegraph
          ? '$tell The heavy blow comes now — brace to take half.'
          : 'It strikes plainly this round — the heavy is not yet wound.';
    }
    return tell;
  }

  /// The enemies at the player's current location, each with whether it can
  /// be fought now and, if not, why — in the engine's refusal order.
  ///
  /// Health and XP are scaled through the same profile the engine applies at
  /// encounter start and at victory, so the card and the fight agree.
  List<EncounterOption> get encountersHere {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <EncounterOption>[];
    final ContentId here = active.state.world.currentLocation;
    final bool fighting = active.state.encounter != null;
    final bool ready = isReady;
    return <EncounterOption>[
      for (final EnemyDefinition enemy in content.enemies.values)
        if (enemy.location == here && _eliteVisible(active.state, content, enemy))
          _encounterOptionOf(
            active,
            content,
            enemy,
            fighting: fighting,
            ready: ready,
          ),
    ];
  }

  /// The Veteran Hunts visibility rule (`DECISIONS/0028`): an enemy gated by
  /// `requiresKnownEnemy` is hidden entirely while its base species is
  /// Unseen, shown locked from Seen, and offered at Known. Hidden-until-Seen
  /// is what keeps a fresh save's screens exactly as they were.
  static bool _eliteVisible(
    GameState state,
    ContentRegistry content,
    EnemyDefinition enemy,
  ) {
    final ContentId? mustKnow = enemy.requiresKnownEnemy;
    if (mustKnow == null) return true;
    final EnemyDefinition? base = content.enemies[mustKnow];
    if (base == null) return false;
    return knowledgeTierFor(state, base) != KnowledgeTier.unseen;
  }

  /// One enemy's card facts — shared by [encountersHere] and the Bestiary
  /// route, so a fight is described by exactly one builder.
  EncounterOption _encounterOptionOf(
    GameEngine active,
    ContentRegistry content,
    EnemyDefinition enemy, {
    required bool fighting,
    required bool ready,
  }) {
    final int remaining = active.state.world.remaining(
      enemy.id,
      enemy.encountersPerVisit,
    );
    // The knowledge gate outranks the transient reasons — the engine's
    // refusal is unconditional while it holds (`DECISIONS/0028`).
    final EnemyDefinition? knownGateBase = () {
      final ContentId? mustKnow = enemy.requiresKnownEnemy;
      if (mustKnow == null) return null;
      final EnemyDefinition? base = content.enemies[mustKnow];
      if (base == null ||
          knowledgeTierFor(active.state, base) != KnowledgeTier.known) {
        return base ?? enemy;
      }
      return null;
    }();
    final String? reason = knownGateBase != null
        ? 'enemy_not_known'
        : fighting
        ? 'encounter_in_progress'
        : remaining <= 0
        ? 'enemy_driven_off'
        : !ready
        ? 'session_not_ready'
        : null;
    final KnowledgeTier tier = knowledgeTierFor(active.state, enemy);
    return EncounterOption(
      enemyId: enemy.id,
      name: enemy.displayName,
      isBoss: enemy.isBoss,
      behavior: enemy.behavior,
      maxHealth: active.profile.applyEnemyHealth(enemy.health),
      attack: enemy.attack,
      defence: enemy.defence,
      xp: active.profile.applyXp(enemy.xp),
      drops: <DropPreview>[
        for (final EnemyDrop drop in enemy.drops)
          DropPreview(
            id: drop.item,
            name: content.items[drop.item]?.displayName ?? drop.item.value,
            rarity: content.items[drop.item]?.rarity,
            chancePercent: drop.chancePercent,
            signature: drop.signature,
            // A signature drop's existence is concealed until the
            // enemy is Known (`DECISIONS/0023` §5). Presentation
            // only: the roll is unchanged.
            revealed: !drop.signature || tier == KnowledgeTier.known,
          ),
      ],
      encountersPerVisit: enemy.encountersPerVisit,
      remainingThisVisit: remaining,
      available: reason == null,
      reason: reason,
      knowledge: tier,
      victories: active.state.progress.victoriesOf(enemy.id),
      studiedAt: enemy.studiedAt,
      knownAt: enemy.knownAt,
      requiresKnownEnemyName: knownGateBase?.displayName,
    );
  }

  /// The Field Notes route (`DECISIONS/0028` §6): every enemy whose
  /// existence the player can currently see, grouped by region with the
  /// journey cost to reach it — so a hunt is planned from home instead of
  /// discovered blind at a 3,000-step remove.
  ///
  /// Reuses the exact card builder [encountersHere] uses, so a fight is
  /// described by one set of facts everywhere. Gated veterans obey the same
  /// visibility rule as the location card (hidden until the base species is
  /// Seen). Pure projection over live state; nothing here is stored.
  BestiaryView get bestiary {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const BestiaryView();
    final ContentId here = active.state.world.currentLocation;
    final bool fighting = active.state.encounter != null;
    final bool ready = isReady;

    int visible = 0;
    int known = 0;
    final List<BestiaryRegionView> regions = <BestiaryRegionView>[];
    for (final LocationDefinition location in content.locations.values) {
      final List<EncounterOption> entries = <EncounterOption>[
        for (final EnemyDefinition enemy in content.enemies.values)
          if (enemy.location == location.id &&
              _eliteVisible(active.state, content, enemy))
            _encounterOptionOf(
              active,
              content,
              enemy,
              fighting: fighting,
              ready: ready,
            ),
      ];
      if (entries.isEmpty) continue;
      visible += entries.length;
      known += entries
          .where((EncounterOption o) => o.knowledge == KnowledgeTier.known)
          .length;
      final bool isHere = location.id == here;
      regions.add(
        BestiaryRegionView(
          locationId: location.id,
          locationName: location.displayName,
          isHere: isHere,
          distanceSteps: isHere
              ? null
              : journeyStatusFor(content, active.state, location.id).totalCost,
          entries: entries,
        ),
      );
    }
    return BestiaryView(
      regions: regions,
      knownCount: known,
      visibleCount: visible,
      // The completion FACT — never a pressure meter: true only when every
      // enemy in the whole pack is Known (at which point every gated
      // veteran is visible too, so the count is honest).
      complete: known == content.enemies.length,
    );
  }

  /// The player's combat figures right now, from `CombatRules.loadoutFor` —
  /// the same function the engine snapshots the next encounter from.
  CombatFigures get combatFigures {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) {
      return const CombatFigures(
        maxHp: 0,
        attack: 0,
        defence: 0,
        level: 0,
        experience: 0,
      );
    }
    final PlayerCombatLoadout loadout = CombatRules.loadoutFor(
      active.state,
      content,
    );
    final int level = active.state.player.level;
    final List<int> thresholds = CombatRules.levelThresholds;
    return CombatFigures(
      maxHp: loadout.maxHp,
      attack: loadout.attack,
      defence: loadout.defence,
      level: level,
      experience: active.state.player.experience,
      weaponName: loadout.weaponItem == null
          ? null
          : content.items[loadout.weaponItem!]?.displayName,
      armorName: loadout.armorItem == null
          ? null
          : content.items[loadout.armorItem!]?.displayName,
      // `thresholds[level]` is the cumulative XP that reaches level + 1; at
      // the cap there is no such entry.
      nextLevelThreshold: level >= 1 && level < thresholds.length
          ? thresholds[level]
          : null,
    );
  }

  /// Owned consumables that heal, in inventory order.
  List<EdibleOption> get edibles {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <EdibleOption>[];
    return <EdibleOption>[
      for (final MapEntry<ContentId, int> e
          in active.state.inventory.counts.entries)
        if (content.items[e.key] case final ItemDefinition item
            when item.category == ItemCategory.consumable && item.healing > 0)
          EdibleOption(
            itemId: e.key,
            name: item.displayName,
            healing: item.healing,
            count: e.value,
          ),
    ];
  }

  /// The resource nodes at the player's current location.
  ///
  /// Read from content, so no screen hardcodes a node id. Haven's Rest has
  /// exactly one today; a screen that assumed that would break on the second.
  List<ResourceNodeDefinition> get nodesHere {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) {
      return const <ResourceNodeDefinition>[];
    }
    final LocationDefinition? here =
        content.locations[active.state.world.currentLocation];
    if (here == null) return const <ResourceNodeDefinition>[];
    return <ResourceNodeDefinition>[
      for (final ContentId id in here.resourceNodes)
        if (content.resourceNodes[id] case final ResourceNodeDefinition d) d,
    ];
  }

  /// Every location in the content pack, for the region map's legend.
  ///
  /// ## What changed in Phase 2
  ///
  /// This used to carry no command and no affordance, because there was nothing
  /// to offer: `stride_core` had no travel activity, and a screen rendering the
  /// step figure as a button would have been inventing the system.
  ///
  /// `TravelTo` now exists (`DECISIONS/0017`), so the figure is a price rather
  /// than a distance. The affordance lives on [destinations], which answers the
  /// narrower question a control needs — *can I set out for this, right now,
  /// and if not why not*. This projection stays what it was: the legend,
  /// covering every place including the ones with no route from here.
  List<RegionPlace> get regionPlaces {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <RegionPlace>[];

    final ContentId here = active.state.world.currentLocation;
    final LocationDefinition? from = content.locations[here];

    // The player's own location leads, then the rest in the registry's order.
    //
    // `ContentRegistry.locations` iterates by content id, which is
    // alphabetical — so the first row of a screen whose first question is
    // "where am I?" was *Forgotten Hollow*, a place the player has never been.
    // This is presentation order, not a rule: no value changes, and the set is
    // the same set.
    final List<LocationDefinition> ordered = <LocationDefinition>[
      ?from,
      for (final LocationDefinition location in content.locations.values)
        if (location.id != here) location,
    ];

    return <RegionPlace>[
      for (final LocationDefinition location in ordered)
        RegionPlace(
          id: location.id,
          displayName: location.displayName,
          isCurrent: location.id == here,
          isSafe: location.isSafe,
          isUnlocked: active.state.world.isUnlocked(location.id),
          stepCostFromHere: location.id == here
              ? null
              : from?.connections
                    .where((LocationConnection c) => c.to == location.id)
                    .firstOrNull
                    ?.stepCost,
          resourceCount: location.resourceNodes.length,
          terrain: location.terrain,
          kind: LocationKinds.kindFor(content, location.id),
        ),
    ];
  }

  /// Everything the atlas inspector says about one place, or null when the
  /// content pack has no such location.
  ///
  /// Built on demand for the one place a player selected — see [PlaceDetails]
  /// for why this is not a field of [regionPlaces].
  PlaceDetails? placeDetailsFor(ContentId location) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    final LocationDefinition? place = content.locations[location];
    if (place == null) return null;

    final bool isCurrent = active.state.world.currentLocation == location;

    return PlaceDetails(
      id: place.id,
      displayName: place.displayName,
      kind: LocationKinds.kindFor(content, place.id),
      isSafe: place.isSafe,
      terrain: place.terrain,
      isCurrent: isCurrent,
      gatherSites: <GatherSiteLine>[
        for (final ContentId nodeId in place.resourceNodes)
          if (content.resourceNodes[nodeId] case final ResourceNodeDefinition n)
            GatherSiteLine(
              id: n.id,
              name: n.displayName,
              skillName: content.skills[n.skill]?.displayName ?? n.skill.value,
              requiredLevel: n.requiredLevel,
              toolWord: _toolWord(n.requiredToolKind),
            ),
      ],
      encounters: <PlaceEncounterLine>[
        for (final EnemyDefinition enemy in content.enemies.values)
          // The same visibility rule as the encounter list: a gated veteran
          // whose base species is Unseen does not exist on any surface yet
          // (`DECISIONS/0028`).
          if (enemy.location == place.id &&
              _eliteVisible(active.state, content, enemy))
            PlaceEncounterLine(
              enemyId: enemy.id,
              name: enemy.displayName,
              isBoss: enemy.isBoss,
              behavior: enemy.behavior,
              encountersPerVisit: enemy.encountersPerVisit,
              // Away from here the whole allowance is waiting, because every
              // move empties the visit map. That is the truth, not a
              // placeholder (`DECISIONS/0021` §1).
              remainingThisVisit: isCurrent
                  ? active.state.world.remaining(
                      enemy.id,
                      enemy.encountersPerVisit,
                    )
                  : enemy.encountersPerVisit,
            ),
      ],
    );
  }

  /// The word an inspector row uses for a tool requirement, or null for none.
  static String? _toolWord(ToolKind kind) => switch (kind) {
    ToolKind.axe => 'Axe',
    ToolKind.pickaxe => 'Pickaxe',
    ToolKind.none => null,
  };

  /// Every route the content pack draws, from every place — not only from
  /// where the player stands.
  ///
  /// The World Atlas draws its connection lines from this and answers "how
  /// would I get there" for a place with no direct road. Both are read from
  /// content adjacency, so a road drawn on the atlas is a road `TravelTo`
  /// knows about, and there is no second list of routes in a widget.
  ///
  /// Directed, exactly as content declares them: `A→B` and `B→A` are two
  /// entries when both are declared. A caller drawing lines dedupes; a caller
  /// walking the graph wants the direction. Costs are profile-scaled, as
  /// [destinations] scales them, so a figure shown from either projection is
  /// the same figure.
  List<RegionRoute> get regionRoutes {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <RegionRoute>[];
    return <RegionRoute>[
      for (final LocationDefinition from in content.locations.values)
        for (final LocationConnection route in from.connections)
          if (content.locations.containsKey(route.to))
            RegionRoute(
              from: from.id,
              to: route.to,
              stepCost: active.profile.applyStepCost(route.stepCost),
            ),
    ];
  }

  /// The places the player could set out for from where they are standing.
  ///
  /// Adjacency, cost, entry requirements and affordability, all read from the
  /// same content and state the engine validates against — asked ahead of time
  /// so a control can be disabled with a truthful reason instead of failing on
  /// tap.
  ///
  /// **It is a hint, not the authority.** `TravelTo` re-checks every one of
  /// these. A screen that treated this as the rule would be a second place the
  /// travel rules live, which is exactly the failure `RULES.md` E-2 names.
  List<TravelOption> get destinations {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <TravelOption>[];

    final LocationDefinition? from =
        content.locations[active.state.world.currentLocation];
    if (from == null) return const <TravelOption>[];

    // The projected figure, not the raw one, so a destination is not offered
    // as affordable out of a balance the pending cutover is about to retire.
    final int banked = usableEnergy;
    final List<TravelOption> options = <TravelOption>[];

    for (final LocationConnection route in from.connections) {
      final LocationDefinition? to = content.locations[route.to];
      if (to == null) continue;

      // Scaled here, once, through the same profile the engine charges by.
      // Reading `route.stepCost` raw would show the right number under
      // `profile.production` and the wrong one under any other — which is the
      // failure mode that looks correct right up until it isn't.
      final int cost = active.profile.applyStepCost(route.stepCost);

      options.add(
        TravelOption(
          id: to.id,
          displayName: to.displayName,
          terrain: to.terrain,
          stepCost: cost,
          isReached: active.state.world.isUnlocked(to.id),
          affordable: cost <= banked,
          missingRequirements: <String>[
            for (final ContentId item in to.entryRequirements)
              if (!active.state.inventory.has(item))
                content.items[item]?.displayName ?? item.value,
          ],
          resourceCount: to.resourceNodes.length,
        ),
      );
    }

    // Nearest first. A list of journeys is a list of prices, and the cheapest
    // one is the question a player with a small balance is actually asking.
    options.sort(
      (TravelOption a, TravelOption b) => a.stepCost.compareTo(b.stepCost),
    );
    return options;
  }

  /// Entry requirements [location] declares that the player does not hold,
  /// by display name. Empty when the way is open or the place is unknown.
  ///
  /// The same check `TravelTo` makes at the door, asked ahead of time so a
  /// multi-leg journey can warn before its final leg rather than stranding
  /// the player one road short. A hint, never the authority (`RULES.md` E-2):
  /// the engine re-validates on every leg's execute.
  List<String> missingEntryRequirementsFor(ContentId location) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <String>[];
    final LocationDefinition? place = content.locations[location];
    if (place == null) return const <String>[];
    return <String>[
      for (final ContentId item in place.entryRequirements)
        if (!active.state.inventory.has(item))
          content.items[item]?.displayName ?? item.value,
    ];
  }

  /// Every recipe in the content pack, with every reason it can or cannot be
  /// made right now.
  ///
  /// All of them, not only the craftable ones. A Craft screen that hid what the
  /// player cannot yet make would answer "what can I do" and never "what am I
  /// working towards", and the second question is the one that makes a walk
  /// feel aimed at something.
  List<RecipeOption> get recipeOptions {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <RecipeOption>[];

    // The chain-link join (Iteration 03): which VISIBLE recipe produces
    // each item, under exactly the filters below — a link to a hidden or
    // retired recipe would jump the bench to a row that does not exist.
    final Map<ContentId, ContentId> producerOf = <ContentId, ContentId>{};
    for (final RecipeDefinition recipe in content.recipes.values) {
      final ContentId? gate = recipe.unlockedByProject;
      if (gate != null && !active.state.progress.isProjectComplete(gate)) {
        continue;
      }
      final ContentId? retired = recipe.retiredByProject;
      if (retired != null && active.state.progress.isProjectComplete(retired)) {
        continue;
      }
      producerOf.putIfAbsent(recipe.outputItem, () => recipe.id);
    }

    final List<RecipeOption> options = <RecipeOption>[];
    for (final RecipeDefinition recipe in content.recipes.values) {
      final SkillDefinition? skill = content.skills[recipe.skill];
      if (skill == null) continue;

      // Project-gated recipes are hidden rather than shown locked: the Mill's
      // improved plank recipe would otherwise sit beside the one it replaces
      // as a second card with the same name, and the project card already
      // advertises the capability. Contract-taught recipes stay visible with
      // the engine's own lock sentence — they are destinations
      // (`DECISIONS/0023` §3).
      final ContentId? projectGate = recipe.unlockedByProject;
      if (projectGate != null &&
          !active.state.progress.isProjectComplete(projectGate)) {
        continue;
      }
      final ContentId? retiredBy = recipe.retiredByProject;
      if (retiredBy != null &&
          active.state.progress.isProjectComplete(retiredBy)) {
        continue;
      }

      options.add(
        RecipeOption(
          id: recipe.id,
          displayName: recipe.displayName,
          skillName: skill.displayName,
          skill: recipe.skill,
          requiredLevel: recipe.requiredLevel,
          currentLevel: skill.levelAt(
            active.state.skills.experienceIn(recipe.skill),
          ),
          ingredients: <RecipeIngredientLine>[
            for (final RecipeIngredient i in recipe.ingredients)
              RecipeIngredientLine(
                item: i.item,
                displayName: content.items[i.item]?.displayName ?? i.item.value,
                required: i.quantity,
                held: active.state.inventory.quantityOf(i.item),
                // Never self-referential: a recipe consuming another batch
                // of its own output cannot exist (the loader forbids it),
                // but an equipment upgrade consuming its base could chain
                // to itself through a shared output — guard anyway.
                craftedByRecipe: producerOf[i.item] == recipe.id
                    ? null
                    : producerOf[i.item],
              ),
          ],
          outputItem: recipe.outputItem,
          outputName:
              content.items[recipe.outputItem]?.displayName ??
              recipe.outputItem.value,
          outputRarity: content.items[recipe.outputItem]?.rarity,
          outputQuantity: active.profile.applyYield(recipe.outputQuantity),
          experience: active.profile.applyXp(recipe.xp),
          outputCategory: content.items[recipe.outputItem]?.category,
          outputIsTool:
              (content.items[recipe.outputItem]?.toolKind ?? ToolKind.none) !=
              ToolKind.none,
          lockReason: active.recipeLockReason(recipe, active.state),
          craftSeconds: recipe.craftSeconds,
          station: recipe.station,
        ),
      );
    }

    // Craftable first, then by the skill level they ask for. The player's own
    // progression is the order they think in, and "what can I make now" should
    // not be at the bottom of a list sorted alphabetically. Locked recipes
    // sink below unlocked ones of the same level — they are the furthest away.
    options.sort((RecipeOption a, RecipeOption b) {
      if (a.canCraft != b.canCraft) return a.canCraft ? -1 : 1;
      if (a.isLocked != b.isLocked) return a.isLocked ? 1 : -1;
      final int byLevel = a.requiredLevel.compareTo(b.requiredLevel);
      if (byLevel != 0) return byLevel;
      return a.displayName.compareTo(b.displayName);
    });
    return options;
  }

  /// Every skill's full standing — level, XP into the level, and the span to the
  /// next one. **F-07.**
  ///
  /// Derived by [SkillDefinition.standingAt], in `stride_core`, for the reason
  /// [skillSummaries] gives about levels and which applies twice as strongly
  /// here: the span between two thresholds is threshold math, and a widget
  /// doing it would be a second implementation of the curve.
  List<SkillStanding> get skillStandings {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <SkillStanding>[];
    return <SkillStanding>[
      for (final MapEntry<ContentId, SkillDefinition> e
          in content.skills.entries)
        e.value.standingAt(active.state.skills.experienceIn(e.key)),
    ];
  }

  /// What the player could gather with this skill, and what it still asks of
  /// them — so a Skills screen can say what a level is *for*.
  ///
  /// A progression screen that shows only a number tells the player they are
  /// level 4 and not what level 5 buys. These are the nodes and recipes that
  /// skill gates, in the order they open.
  List<SkillUnlock> unlocksFor(ContentId skill) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <SkillUnlock>[];

    final SkillDefinition? definition = content.skills[skill];
    if (definition == null) return const <SkillUnlock>[];
    final int level = definition.levelAt(
      active.state.skills.experienceIn(skill),
    );

    final GameState state = active.state;
    // The expanded row's "what that feeds" line, capped at two consumers —
    // one join through the same purpose projection the bag reads, so the
    // roadmap and the item detail cannot disagree.
    String? feedsLine(ContentId item) {
      final ItemPurposeView? purpose = itemPurposeOf(item);
      if (purpose == null) return null;
      final List<String> consumers = <String>[
        ...purpose.usedInRecipes,
        ...purpose.wantedBy,
      ];
      if (consumers.isEmpty) return null;
      final String head = consumers.take(2).join(' · ');
      final int more = consumers.length - 2;
      final String name = displayNameOf(item);
      return more > 0 ? '$name feeds $head · +$more more' : '$name feeds $head';
    }

    final List<SkillUnlock> unlocks = <SkillUnlock>[
      for (final ResourceNodeDefinition node in content.resourceNodes.values)
        if (node.skill == skill)
          () {
            // The node's other gates, named truthfully: the project that
            // must stand first, and the tool tier the work asks for.
            final ContentId? project = node.unlockedByProject;
            final bool projectMet =
                project == null || state.progress.isProjectComplete(project);
            final String? gate = !projectMet
                ? (content.projects[project]?.displayName ?? project.value)
                : node.minimumToolTier > 0
                ? 'a tier-${node.minimumToolTier} '
                      '${node.requiredToolKind.name}'
                : null;
            final int yieldQty = active.profile.applyYield(node.yieldsQuantity);
            return SkillUnlock(
              displayName: node.displayName,
              requiredLevel: node.requiredLevel,
              unlocked: level >= node.requiredLevel && projectMet,
              where: _hostOf(node.id, content),
              gate: gate,
              kind: SkillUnlockKind.site,
              trackableItem: node.yieldsItem,
              detailLines: <String>[
                'Yields ${displayNameOf(node.yieldsItem)}'
                    '${yieldQty > 1 ? ' ×$yieldQty' : ''}',
                if (feedsLine(node.yieldsItem) case final String feeds) feeds,
              ],
            );
          }(),
      // The quiet milestones: a level at which a node starts paying bonus
      // yield used to look dead on the Skills screen — it wasn't, the screen
      // just never said so (Fable V2 audit).
      for (final ResourceNodeDefinition node in content.resourceNodes.values)
        if (node.skill == skill && node.bonusYieldLevel > 0)
          SkillUnlock(
            displayName:
                '+${node.bonusYieldPercent}% yield at ${node.displayName}',
            requiredLevel: node.bonusYieldLevel,
            unlocked: level >= node.bonusYieldLevel,
            // The node's name already places it; a host would double the
            // "at" ("…at Meadow Patch at Haven's Rest").
            where: null,
            kind: SkillUnlockKind.milestone,
          ),
      for (final RecipeDefinition recipe in content.recipes.values)
        if (recipe.skill == skill &&
            // A recipe an incomplete project would add, or a completed one
            // has retired, is that project's story, not this ladder's — and
            // listing both "Oak Plank"s would be a duplicate promising
            // nothing.
            !(recipe.unlockedByProject != null &&
                !state.progress.isProjectComplete(recipe.unlockedByProject!)) &&
            !(recipe.retiredByProject != null &&
                state.progress.isProjectComplete(recipe.retiredByProject!)))
          () {
            final ContentId? contract = recipe.unlockedByContract;
            final bool taught =
                contract == null || state.progress.completionsOf(contract) > 0;
            final String? gate = taught
                ? null
                : () {
                    final ContractDefinition? c = content.contracts[contract];
                    final String? at = c == null
                        ? null
                        : content.locations[c.location]?.displayName;
                    return at == null ? 'a contract' : 'a contract at $at';
                  }();
            final ItemDefinition? output = content.items[recipe.outputItem];
            return SkillUnlock(
              displayName: recipe.displayName,
              requiredLevel: recipe.requiredLevel,
              unlocked: level >= recipe.requiredLevel && taught,
              where: null,
              gate: gate,
              kind: SkillUnlockKind.recipe,
              trackableItem: recipe.outputItem,
              detailLines: <String>[
                'Needs ${recipe.ingredients.map((RecipeIngredient i) => '${displayNameOf(i.item)} ×${i.quantity}').join(', ')}',
                if ((output?.healing ?? 0) > 0)
                  'Heals ${output!.healing}'
                else if (feedsLine(recipe.outputItem) case final String feeds)
                  feeds,
              ],
            );
          }(),
    ];

    unlocks.sort((SkillUnlock a, SkillUnlock b) {
      final int byLevel = a.requiredLevel.compareTo(b.requiredLevel);
      return byLevel != 0 ? byLevel : a.displayName.compareTo(b.displayName);
    });
    return unlocks;
  }

  static String? _hostOf(ContentId node, ContentRegistry content) {
    for (final LocationDefinition location in content.locations.values) {
      if (location.resourceNodes.contains(node)) return location.displayName;
    }
    return null;
  }

  /// A profession's whole plannable future (Fable V2 Iteration 03): the
  /// standing, and every level from 1 to the last one any content touches,
  /// each carrying its unlocks and its relation to the player — earned,
  /// current, the NEXT level that still holds content (with the true XP
  /// distance, from the same curve the engine gates with), or future.
  ///
  /// Derived entirely from [unlocksFor] and [SkillDefinition] — the Skills
  /// card's three lines and this ladder read one ordering, so they cannot
  /// disagree about what a level buys (the two-definitions risk the UX
  /// review named).
  SkillRoadmap? skillRoadmapFor(ContentId skill) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    final SkillDefinition? definition = content?.skills[skill];
    if (active == null || content == null || definition == null) return null;

    final SkillStanding standing = definition.standingAt(
      active.state.skills.experienceIn(skill),
    );
    final List<SkillUnlock> unlocks = unlocksFor(skill);
    if (unlocks.isEmpty) {
      return SkillRoadmap(
        standing: standing,
        levels: const <RoadmapLevel>[],
        openCount: 0,
        totalCount: 0,
        maxLevel: definition.maxLevel,
      );
    }

    final Map<int, List<SkillUnlock>> byLevel = <int, List<SkillUnlock>>{};
    int horizon = standing.level;
    // The last level any authored content touches — distinct from [horizon],
    // which the ladder also stretches to reach the player's own level.
    int contentHorizon = 0;
    for (final SkillUnlock u in unlocks) {
      byLevel.putIfAbsent(u.requiredLevel, () => <SkillUnlock>[]).add(u);
      if (u.requiredLevel > horizon) horizon = u.requiredLevel;
      if (u.requiredLevel > contentHorizon) contentHorizon = u.requiredLevel;
    }
    // The nearest level above the player that still holds content — the one
    // band that carries an XP distance.
    int? nextWithContent;
    for (int l = standing.level + 1; l <= horizon; l++) {
      if (byLevel.containsKey(l)) {
        nextWithContent = l;
        break;
      }
    }

    return SkillRoadmap(
      standing: standing,
      levels: <RoadmapLevel>[
        for (int l = 1; l <= horizon; l++)
          RoadmapLevel(
            level: l,
            state: l < standing.level
                ? RoadmapLevelState.earned
                : l == standing.level
                ? RoadmapLevelState.current
                : l == nextWithContent
                ? RoadmapLevelState.next
                : RoadmapLevelState.future,
            entries: byLevel[l] ?? const <SkillUnlock>[],
            xpAway: l == nextWithContent
                ? (definition.experienceForLevel(l) - standing.totalExperience)
                      .clamp(0, 1 << 62)
                : null,
          ),
      ],
      openCount: unlocks.where((SkillUnlock u) => u.unlocked).length,
      totalCount: unlocks.length,
      contentHorizon: contentHorizon,
      maxLevel: definition.maxLevel,
    );
  }

  /// Where a missing ingredient comes from, as one capped line — the same
  /// purpose joins the bag reads, so the bench and the bag agree. Null when
  /// the pack gives the item no source (which the content validator treats
  /// as its own problem, not this line's).
  String? ingredientSourceLine(ContentId item) {
    final ItemPurposeView? purpose = itemPurposeOf(item);
    if (purpose == null) return null;
    final List<String> sources = <String>[
      ...purpose.gatheredAt,
      ...purpose.droppedBy.map((String enemy) => 'dropped by $enemy'),
      ...purpose.craftedBy.map((String recipe) => 'crafted: $recipe'),
    ];
    if (sources.isEmpty) return null;
    final String head = sources.take(2).join(' · ');
    final int more = sources.length - 2;
    return more > 0 ? '$head · +$more more' : head;
  }

  /// The one warning the balance review demanded the bench say out loud
  /// (Fable V2 Iteration 03): this recipe consumes an item an UNCOMPLETED
  /// `requiresOwned` contract still asks to *see*. Crafting first turns
  /// that contract into a wait for another drop — a delay the player
  /// should choose, not discover.
  String? consumesProverWarning(RecipeOption recipe) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    for (final RecipeIngredientLine line in recipe.ingredients) {
      for (final ContractDefinition contract in content.contracts.values) {
        if (!contract.requiresOwned.contains(line.item)) continue;
        if (active.state.progress.completionsOf(contract.id) > 0) continue;
        final String at =
            content.locations[contract.location]?.displayName ??
            contract.location.value;
        return '${contract.displayName} at $at asks to see '
            '${line.displayName} first — this craft consumes it';
      }
    }
    return null;
  }

  /// The bench's other quiet-surprise warning (Iteration 03 review): this
  /// recipe consumes gear the player is wearing right now, with no spare
  /// copy to keep the slot backed. The engine takes it off as part of the
  /// craft; the bench says so before the tap rather than after.
  String? consumesWornGearWarning(RecipeOption recipe) {
    final GameEngine? active = engine;
    if (active == null) return null;
    for (final RecipeIngredientLine line in recipe.ingredients) {
      if (!active.state.equipment.isEquipped(line.item)) continue;
      if (active.state.inventory.quantityOf(line.item) - line.required >= 1) {
        continue; // A spare copy keeps the worn one on.
      }
      return '${line.displayName} is worn right now — '
          'crafting this takes it off';
    }
    return null;
  }

  /// Steps that were banked before the current playable economy began and are
  /// not spendable — the whole retired body, across the Phase 2 cutover and the
  /// Transformation playtest epoch.
  ///
  /// Zero for a game that has never migrated. Surfaced rather than hidden: the
  /// owner walked these, and a product that silently forgot them would be lying
  /// about its own history (`DECISIONS/0016`, `DECISIONS/0018`). `TOTAL WALKED`
  /// on the product screens is [totalGranted], which still carries every one.
  int get retiredSteps => engine?.state.steps.epoch.retiredSteps ?? 0;

  /// The display name of a content id, for anything the read model does not
  /// already project. Falls back to the raw id rather than throwing.
  String displayNameOf(ContentId id) =>
      registry?.items[id]?.displayName ??
      registry?.skills[id]?.displayName ??
      registry?.resourceNodes[id]?.displayName ??
      id.value;

  /// The display name of [location], or null when the pack does not define
  /// it. The nullable public face of the same lookup [travel]'s reports use.
  String? locationNameOf(ContentId location) =>
      registry?.locations[location]?.displayName;

  /// The refusal, when the bootstrap was blocked. Null on a started game.
  ///
  /// Exposed as its own accessor so a screen can branch without pattern-matching
  /// on [outcome] and, from there, discovering `outcome.engine`.
  BootstrapBlocked? get blocked {
    final BootstrapOutcome o = outcome;
    return o is BootstrapBlocked ? o : null;
  }

  // -- Exploration & Progression Loop 01 (`DECISIONS/0023`) -------------------

  /// The player's persistent HP, and the maximum the level provides.
  int get playerHp => engine?.state.player.hp ?? 0;
  int get playerMaxHp =>
      engine == null ? 0 : CombatRules.maxHpFor(engine!.state.player.level);

  /// A settlement's named development state, or null.
  String? developmentStateOf(ContentId location) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    return developmentStateFor(content, active.state, location);
  }

  /// Every rumor the player has heard, for the atlas and the journal-ish
  /// corners of the UI.
  List<RumorView> get revealedRumors {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <RumorView>[];
    return <RumorView>[
      for (final ContentId id in active.state.progress.revealedRumors)
        if (content.rumors[id] case final RumorDefinition rumor)
          RumorView(id: id, name: rumor.displayName, hint: rumor.hint),
    ];
  }

  /// Whether [rumor] has been revealed.
  bool isRumorRevealed(ContentId rumor) =>
      engine?.state.progress.revealedRumors.contains(rumor) ?? false;

  /// Eats one owned consumable outside combat (`DECISIONS/0023` §4).
  Future<FoodReport> eatFood(ContentId item) async {
    final String name = registry?.items[item]?.displayName ?? item.value;
    if (_inFlight) {
      return FoodReport(
        succeeded: false,
        itemName: name,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return FoodReport(
          succeeded: false,
          itemName: name,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      final EngineResult result = active.execute(EatFood(item: item));
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return FoodReport(
          succeeded: false,
          itemName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return FoodReport(
          succeeded: false,
          itemName: name,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      final FoodEaten eaten = result.events.whereType<FoodEaten>().first;
      return FoodReport(
        succeeded: true,
        itemName: name,
        healed: eaten.healed,
        hpAfter: eaten.hpAfter,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Sets or clears one tracked-objective slot (`DECISIONS/0023` §1).
  Future<GoalReport> trackGoal(GoalSlot slot, ContentId? target) async {
    if (_inFlight) {
      return const GoalReport(
        succeeded: false,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      if (active == null || registry == null || _stale || migrationPending) {
        return GoalReport(
          succeeded: false,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      final EngineResult result = active.execute(
        TrackGoal(slot: slot, target: target),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return GoalReport(
          succeeded: false,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      if (result.events.isEmpty) {
        // Tracking what is already tracked: a success with nothing to write.
        return const GoalReport(succeeded: true);
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return GoalReport(
          succeeded: false,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      return const GoalReport(succeeded: true);
    } finally {
      _inFlight = false;
    }
  }

  /// The three tracked slots, fully projected for the tracker panel.
  TrackedGoalsView get trackedGoals {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const TrackedGoalsView();
    final TrackedGoals tracked = active.state.progress.tracked;

    JourneyGoalView? journey;
    final ContentId? journeyTo = tracked.journey;
    if (journeyTo != null) {
      final JourneyStatus status = journeyStatusFor(
        content,
        active.state,
        journeyTo,
      );
      journey = JourneyGoalView(
        destination: journeyTo,
        destinationName:
            content.locations[journeyTo]?.displayName ?? journeyTo.value,
        legNames: <String>[
          for (final JourneyLeg leg in status.legs)
            content.locations[leg.to]?.displayName ?? leg.to.value,
        ],
        totalCost: status.totalCost,
        banked: usableEnergy,
        shortfall: status.totalCost == null
            ? null
            : (status.totalCost! - usableEnergy).clamp(0, 1 << 62),
        ready: status.totalCost != null && usableEnergy >= status.totalCost!,
        arrived: active.state.world.currentLocation == journeyTo,
      );
    }

    PursuitGoalView? pursuit;
    final ContentId? pursuitItem = tracked.pursuit;
    if (pursuitItem != null) {
      final PursuitPlan plan = pursuitPlanFor(
        content,
        active.state,
        pursuitItem,
      );
      pursuit = PursuitGoalView(
        item: pursuitItem,
        itemName: content.items[pursuitItem]?.displayName ?? pursuitItem.value,
        rarity: content.items[pursuitItem]?.rarity,
        recipeName: plan.recipe == null
            ? null
            : content.recipes[plan.recipe!]?.displayName,
        lines: <PursuitLineView>[
          for (final PursuitLine line in plan.lines)
            PursuitLineView(
              name: content.items[line.item]?.displayName ?? line.item.value,
              held: line.held,
              required: line.required,
            ),
        ],
        needs: <PursuitNeedView>[
          for (final PursuitNeed need in plan.needs)
            PursuitNeedView(
              name: content.items[need.item]?.displayName ?? need.item.value,
              quantity: need.quantity,
              sourceName: need.sourceLocation == null
                  ? null
                  : content.locations[need.sourceLocation!]?.displayName,
              viaEnemy: need.sourceEnemy != null,
            ),
        ],
        owned: plan.owned,
        complete: plan.complete,
      );
    }

    ContractGoalView? contractGoal;
    final ContentId? trackedContract = tracked.contract;
    if (trackedContract != null) {
      contractGoal = _contractGoalViewOf(trackedContract, active, content);
    }

    return TrackedGoalsView(
      journey: journey,
      pursuit: pursuit,
      contract: contractGoal,
    );
  }

  ContractGoalView? _contractGoalViewOf(
    ContentId id,
    GameEngine active,
    ContentRegistry content,
  ) {
    final ProjectDefinition? project = content.projects[id];
    if (project != null) {
      final ProjectView? view = projectViewOf(id);
      if (view == null) return null;
      final ProjectStageView? current = view.isComplete
          ? null
          : view.stages[view.currentStage];
      return ContractGoalView(
        id: id,
        name: project.displayName,
        isProject: true,
        locationName:
            content.locations[project.location]?.displayName ??
            project.location.value,
        stageLabel: view.isComplete
            ? 'Complete'
            : 'Stage ${view.currentStage + 1} / ${view.stages.length}',
        lines: current == null
            ? const <PursuitLineView>[]
            : <PursuitLineView>[
                for (final RequirementLine line in current.lines)
                  PursuitLineView(
                    name: line.name,
                    held: line.progress,
                    required: line.required,
                  ),
              ],
        readyToAdvance: view.canAdvanceNow,
        complete: view.isComplete,
      );
    }
    final ContractDefinition? contract = content.contracts[id];
    if (contract == null) return null;
    final ContractView view = _contractViewOf(contract, active, content);
    return ContractGoalView(
      id: id,
      name: contract.displayName,
      isProject: false,
      locationName:
          content.locations[contract.location]?.displayName ??
          contract.location.value,
      stageLabel: view.completions > 0 && !contract.isRepeatable
          ? 'Complete'
          : null,
      lines: <PursuitLineView>[
        for (final RequirementLine line in view.requires)
          PursuitLineView(
            name: line.name,
            held: line.progress,
            required: line.required,
          ),
        if (view.bounty != null)
          PursuitLineView(
            name: '${view.bounty!.enemyName} defeated',
            held: view.bounty!.progress,
            required: view.bounty!.required,
          ),
      ],
      readyToAdvance: view.canComplete,
      complete: view.completions > 0 && !contract.isRepeatable,
    );
  }

  /// The board where the player stands, or null when this place has none.
  BoardView? get boardHere {
    final ContentId? here = currentLocation;
    return here == null ? null : boardFor(here);
  }

  /// One location's contract board, fully projected (`DECISIONS/0023` §2).
  BoardView? boardFor(ContentId location) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    final LocationDefinition? place = content.locations[location];
    final String? boardName = place?.boardName;
    if (place == null || boardName == null) return null;

    final List<ContentId> slots = active.localNeedSlots(active.state, location);
    final List<ContractView> localNeeds = <ContractView>[
      for (final ContentId id in slots)
        if (content.contracts[id] case final ContractDefinition c)
          _contractViewOf(c, active, content),
    ];
    final List<ContractView> bounties = <ContractView>[];
    final List<ContractView> regionals = <ContractView>[];
    for (final ContractDefinition c in content.contracts.values) {
      if (c.location != location) continue;
      // A hunt on a gated veteran obeys the veteran's own visibility rule
      // (`DECISIONS/0028`): hidden entirely while the base species is
      // Unseen — a board must not name an enemy no surface admits exists —
      // then shown with the engine's own locked reason until Known.
      if (c.bountyEnemy case final ContentId quarry) {
        final EnemyDefinition? elite = content.enemies[quarry];
        if (elite != null &&
            !_eliteVisible(active.state, content, elite)) {
          continue;
        }
      }
      switch (c.contractClass) {
        case ContractClass.bounty:
          bounties.add(_contractViewOf(c, active, content));
        case ContractClass.regional:
          regionals.add(_contractViewOf(c, active, content));
        case ContractClass.localNeed:
          break;
      }
    }

    return BoardView(
      location: location,
      boardName: boardName,
      developmentState: developmentStateOf(location),
      localNeeds: localNeeds,
      bounties: bounties,
      regionals: regionals,
      projects: projectsAt(location),
    );
  }

  /// One location's board folded to a glance, for the World inspector
  /// (Fable V2, `DECISIONS/0027`). Null where the location keeps no board.
  ///
  /// A restatement of [boardFor] and [projectsAt] — same projections, same
  /// availability and readiness rules — so the map line and the Goal Board
  /// cannot disagree.
  BoardSummaryView? boardSummaryFor(ContentId location) {
    final BoardView? board = boardFor(location);
    if (board == null) return null;

    final List<ContractView> open = <ContractView>[
      ...board.localNeeds.where((ContractView c) => c.available),
      ...board.bounties.where((ContractView c) => c.available),
      ...board.regionals.where(
        (ContractView c) => c.available && !c.isCompletedOneTime,
      ),
    ];
    ProjectView? underway;
    for (final ProjectView p in board.projects) {
      if (!p.isComplete) {
        underway = p;
        break;
      }
    }
    return BoardSummaryView(
      boardName: board.boardName,
      openContracts: open.length,
      readyToComplete: open.where((ContractView c) => c.canComplete).length,
      projectName: underway?.name,
      projectHasSomethingToGive: underway?.hasSomethingToGive ?? false,
    );
  }

  ContractView _contractViewOf(
    ContractDefinition contract,
    GameEngine active,
    ContentRegistry content,
  ) {
    final GameState state = active.state;
    final String? unavailableReason = active.contractUnavailableReason(
      contract,
      state,
    );

    final List<RequirementLine> requires = <RequirementLine>[
      for (final ItemQuantity need in contract.requires)
        RequirementLine(
          item: need.item,
          name: content.items[need.item]?.displayName ?? need.item.value,
          rarity: content.items[need.item]?.rarity,
          required: need.quantity,
          progress: state.inventory.quantityOf(need.item) > need.quantity
              ? need.quantity
              : state.inventory.quantityOf(need.item),
        ),
    ];
    final List<RequirementLine> requiresOwned = <RequirementLine>[
      for (final ContentId item in contract.requiresOwned)
        RequirementLine(
          item: item,
          name: content.items[item]?.displayName ?? item.value,
          rarity: content.items[item]?.rarity,
          required: 1,
          progress: state.inventory.has(item) ? 1 : 0,
          keptNotConsumed: true,
        ),
    ];

    BountyView? bounty;
    final ContentId? bountyEnemy = contract.bountyEnemy;
    if (bountyEnemy != null) {
      final bool accepted = state.progress.acceptedContracts.contains(
        contract.id,
      );
      bounty = BountyView(
        enemy: bountyEnemy,
        enemyName:
            content.enemies[bountyEnemy]?.displayName ?? bountyEnemy.value,
        required: contract.bountyCount,
        progress: accepted
            ? (state.progress.bountyProgress[contract.id] ?? 0)
            : 0,
        accepted: accepted,
      );
    }

    final bool itemsMet =
        requires.every((RequirementLine l) => l.satisfied) &&
        requiresOwned.every((RequirementLine l) => l.satisfied);
    final bool bountyMet =
        bounty == null ||
        (bounty.accepted && bounty.progress >= bounty.required);

    return ContractView(
      id: contract.id,
      name: contract.displayName,
      brief: contract.brief,
      contractClass: contract.contractClass,
      location: contract.location,
      requires: requires,
      requiresOwned: requiresOwned,
      bounty: bounty,
      rewardItems: <RequirementLine>[
        for (final ItemQuantity given in contract.rewardItems)
          RequirementLine(
            item: given.item,
            name: content.items[given.item]?.displayName ?? given.item.value,
            rarity: content.items[given.item]?.rarity,
            required: active.profile.applyYield(given.quantity),
            progress: 0,
          ),
      ],
      rewardSkillXp: <SkillXpLine>[
        for (final SkillXpAward award in contract.rewardSkillXp)
          SkillXpLine(
            skillName:
                content.skills[award.skill]?.displayName ?? award.skill.value,
            xp: active.profile.applyXp(award.xp),
          ),
      ],
      rewardCharacterXp: active.profile.applyXp(contract.rewardCharacterXp),
      teachesRecipeName: _recipeTaughtBy(contract.id, content),
      completions: state.progress.completionsOf(contract.id),
      available: unavailableReason == null,
      unavailableReason: unavailableReason,
      canComplete:
          unavailableReason == null && itemsMet && bountyMet && isReady,
    );
  }

  String? _recipeTaughtBy(ContentId contract, ContentRegistry content) {
    for (final RecipeDefinition recipe in content.recipes.values) {
      if (recipe.unlockedByContract == contract) return recipe.displayName;
    }
    return null;
  }

  /// Accepts a bounty so victories start counting (`DECISIONS/0023` §2).
  Future<ContractReport> acceptContract(ContentId contract) =>
      _contractCommand(AcceptContract(contract: contract), contract);

  /// Completes a contract at its board: one command, one commit, exactly
  /// once.
  Future<ContractReport> completeContract(ContentId contract) =>
      _contractCommand(CompleteContract(contract: contract), contract);

  Future<ContractReport> _contractCommand(
    GameCommand command,
    ContentId contract,
  ) async {
    final String name =
        registry?.contracts[contract]?.displayName ?? contract.value;
    if (_inFlight) {
      return ContractReport(
        succeeded: false,
        contractName: name,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      final ContentRegistry? content = registry;
      if (active == null || content == null || _stale || migrationPending) {
        return ContractReport(
          succeeded: false,
          contractName: name,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      final EngineResult result = active.execute(command);
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return ContractReport(
          succeeded: false,
          contractName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return ContractReport(
          succeeded: false,
          contractName: name,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      final ContractCompleted? completed = result.events
          .whereType<ContractCompleted>()
          .firstOrNull;
      if (completed == null) {
        // An acceptance: nothing consumed, nothing rewarded yet.
        return ContractReport(
          succeeded: true,
          contractName: name,
          accepted: true,
        );
      }
      String itemName(ContentId id) =>
          content.items[id]?.displayName ?? id.value;
      return ContractReport(
        succeeded: true,
        contractName: name,
        consumed: <RewardLine>[
          for (final MapEntry<ContentId, int> e in completed.consumed.entries)
            RewardLine(
              id: e.key,
              name: itemName(e.key),
              quantity: e.value,
              rarity: content.items[e.key]?.rarity,
            ),
        ],
        rewardItems: <RewardLine>[
          for (final MapEntry<ContentId, int> e
              in completed.rewardItems.entries)
            RewardLine(
              id: e.key,
              name: itemName(e.key),
              quantity: e.value,
              rarity: content.items[e.key]?.rarity,
            ),
        ],
        rewardSkillXp: <SkillXpLine>[
          for (final MapEntry<ContentId, int> e
              in completed.rewardSkillXp.entries)
            SkillXpLine(
              skillName: content.skills[e.key]?.displayName ?? e.key.value,
              xp: e.value,
            ),
        ],
        characterXp: completed.characterXp,
        levelBefore: completed.levelBefore,
        levelAfter: completed.levelAfter,
        taughtRecipeName: _recipeTaughtBy(completed.contract, content),
        revealedRumorNames: <String>[
          for (final ContentId id in completed.revealedRumors)
            content.rumors[id]?.displayName ?? id.value,
        ],
      );
    } finally {
      _inFlight = false;
    }
  }

  /// The community projects hosted at [location], fully projected.
  List<ProjectView> projectsAt(ContentId location) {
    final ContentRegistry? content = registry;
    if (content == null) return const <ProjectView>[];
    return <ProjectView>[
      for (final ProjectDefinition project in content.projects.values)
        if (project.location == location)
          if (projectViewOf(project.id) case final ProjectView view) view,
    ];
  }

  /// One project's live view, or null when the id is not content.
  ProjectView? projectViewOf(ContentId id) {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return null;
    final ProjectDefinition? project = content.projects[id];
    if (project == null) return null;
    final GameState state = active.state;

    final bool complete = state.progress.isProjectComplete(id);
    final ProjectProgressState? live = state.progress.projects[id];
    final int currentStage = complete
        ? project.stages.length - 1
        : (live?.stage ?? 0);

    // The `requiresProject` gate (`DECISIONS/0028`): a gated project stays
    // visible with its gate stated — the engine owns the refusal, this
    // mirrors its reason (E-2). Nothing is reserved (P-9).
    final ContentId? gate = project.requiresProject;
    final bool locked =
        !complete && gate != null && !state.progress.isProjectComplete(gate);
    final String? gateName = gate == null
        ? null
        : (content.projects[gate]?.displayName ?? gate.value);

    final List<ProjectStageView> stages = <ProjectStageView>[];
    for (int s = 0; s < project.stages.length; s++) {
      final ProjectStage stage = project.stages[s];
      final bool stageDone = complete || s < currentStage;
      final Map<ContentId, int> contributed = (!stageDone && s == currentStage)
          ? (live?.contributed ?? const <ContentId, int>{})
          : const <ContentId, int>{};
      stages.add(
        ProjectStageView(
          name: stage.name,
          complete: stageDone,
          lines: <RequirementLine>[
            for (final ItemQuantity need in stage.requires)
              RequirementLine(
                item: need.item,
                name: content.items[need.item]?.displayName ?? need.item.value,
                rarity: content.items[need.item]?.rarity,
                required: need.quantity,
                progress: stageDone
                    ? need.quantity
                    : (contributed[need.item] ?? 0),
              ),
          ],
        ),
      );
    }

    // What the player could donate right now: per current-stage item,
    // min(held, remaining). Empty when nothing useful is in the bag.
    final Map<ContentId, int> contributable = <ContentId, int>{};
    if (!complete && !locked) {
      final ProjectStage stage = project.stages[currentStage];
      final Map<ContentId, int> contributed =
          live?.contributed ?? const <ContentId, int>{};
      for (final ItemQuantity need in stage.requires) {
        final int remaining = need.quantity - (contributed[need.item] ?? 0);
        if (remaining <= 0) continue;
        final int held = state.inventory.quantityOf(need.item);
        if (held <= 0) continue;
        contributable[need.item] = held < remaining ? held : remaining;
      }
    }

    return ProjectView(
      id: id,
      name: project.displayName,
      brief: project.brief,
      location: project.location,
      stages: stages,
      currentStage: currentStage,
      isComplete: complete,
      completionHeadline: project.completionHeadline,
      developmentTo: project.developmentTo,
      contributable: contributable,
      isLocked: locked,
      lockedReason: locked ? 'Opens once "$gateName" is complete' : null,
      followsName: gateName,
      canAdvanceNow:
          !complete &&
          !locked &&
          stages[currentStage].lines.every(
            (RequirementLine l) =>
                (contributable[l.item] ?? 0) + l.progress >= l.required,
          ),
      // The join over the gates the engine itself refuses with — a node's
      // `unlockedByProject`, a recipe's, and an order's `requiresProject` —
      // so the card can say why the mill is worth building.
      opens: complete
          ? const <String>[]
          : <String>[
              for (final ResourceNodeDefinition node
                  in content.resourceNodes.values)
                if (node.unlockedByProject == id) node.displayName,
              for (final RecipeDefinition recipe in content.recipes.values)
                if (recipe.unlockedByProject == id) recipe.displayName,
              for (final ContractDefinition contract
                  in content.contracts.values)
                if (contract.requiresProject == id) contract.displayName,
              for (final ProjectDefinition p in content.projects.values)
                if (p.requiresProject == id) p.displayName,
            ],
    );
  }

  /// Donates materials to a project's current stage (`DECISIONS/0023` §3).
  Future<ProjectReport> contributeToProject(
    ContentId project,
    Map<ContentId, int> contributions,
  ) async {
    final String name =
        registry?.projects[project]?.displayName ?? project.value;
    if (_inFlight) {
      return ProjectReport(
        succeeded: false,
        projectName: name,
        rejection: 'session_busy',
        detail: 'another action is still running',
      );
    }
    _inFlight = true;
    try {
      final GameEngine? active = engine;
      final ContentRegistry? content = registry;
      if (active == null || content == null || _stale || migrationPending) {
        return ProjectReport(
          succeeded: false,
          projectName: name,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
      final String? developmentBefore = developmentStateOf(
        content.projects[project]?.location ?? project,
      );
      final EngineResult result = active.execute(
        ContributeToProject(project: project, contributions: contributions),
      );
      if (result case RejectedResult(:final CommandRejection rejection)) {
        return ProjectReport(
          succeeded: false,
          projectName: name,
          rejection: rejection.code.wire,
          detail: rejection.explanation,
        );
      }
      final CommitOutcome commit = await _commit(active, result.events);
      if (commit is CommitRefused) {
        _stale = true;
        return ProjectReport(
          succeeded: false,
          projectName: name,
          rejection: 'commit_refused',
          detail: commit.reason.name,
        );
      }
      final ProjectContributed event = result.events
          .whereType<ProjectContributed>()
          .first;
      final ProjectDefinition? definition = content.projects[project];
      final String? developmentAfter = developmentStateOf(
        definition?.location ?? project,
      );
      return ProjectReport(
        succeeded: true,
        projectName: name,
        stageName: definition == null
            ? ''
            : definition.stages[event.stage].name,
        contributed: <RewardLine>[
          for (final MapEntry<ContentId, int> e in event.contributed.entries)
            RewardLine(
              id: e.key,
              name: content.items[e.key]?.displayName ?? e.key.value,
              quantity: e.value,
              rarity: content.items[e.key]?.rarity,
            ),
        ],
        stageCompleted: event.stageCompleted,
        projectCompleted: event.projectCompleted,
        completionHeadline: event.projectCompleted
            ? definition?.completionHeadline
            : null,
        characterXp: event.characterXp,
        levelBefore: event.levelBefore,
        levelAfter: event.levelAfter,
        developmentBefore: developmentBefore,
        developmentAfter: developmentAfter,
        revealedRumorNames: <String>[
          for (final ContentId id in event.revealedRumors)
            content.rumors[id]?.displayName ?? id.value,
        ],
      );
    } finally {
      _inFlight = false;
    }
  }

  /// The step-sync motivation highlights (`DECISIONS/0023` §1; brief §5):
  /// a few high-value, true-right-now sentences derived from the tracked
  /// goals and the freshly banked balance. Never auto-spends, never fakes
  /// progress, never notifies — the caller renders them once, after a
  /// granting sync.
  List<SyncOpportunity> syncOpportunities() {
    final GameEngine? active = engine;
    final ContentRegistry? content = registry;
    if (active == null || content == null) return const <SyncOpportunity>[];
    final List<SyncOpportunity> highlights = <SyncOpportunity>[];
    final TrackedGoalsView goals = trackedGoals;

    final JourneyGoalView? journey = goals.journey;
    if (journey != null && journey.ready && !journey.arrived) {
      highlights.add(
        SyncOpportunity(
          kind: SyncOpportunityKind.journeyReady,
          headline: 'Journey Ready',
          detail: '${journey.destinationName} can now be reached.',
        ),
      );
    }

    final PursuitGoalView? pursuit = goals.pursuit;
    if (pursuit != null && !pursuit.complete && pursuit.needs.isNotEmpty) {
      final int? gatherCost = _pursuitGatherCost(active, content);
      if (gatherCost != null && gatherCost > 0 && gatherCost <= usableEnergy) {
        highlights.add(
          SyncOpportunity(
            kind: SyncOpportunityKind.pursuit,
            headline: 'Pursuit Opportunity',
            detail:
                'Enough steps are available for the remaining '
                '${pursuit.itemName} gathers.',
          ),
        );
      }
    }

    final ContractGoalView? contract = goals.contract;
    if (contract != null && !contract.complete && contract.readyToAdvance) {
      highlights.add(
        SyncOpportunity(
          kind: SyncOpportunityKind.contract,
          headline: 'Contract Opportunity',
          detail: contract.isProject
              ? 'Enough materials are on hand to advance ${contract.name}.'
              : '${contract.name} can be completed now.',
        ),
      );
    }
    return highlights;
  }

  /// The step cost of gathering everything the tracked pursuit still needs,
  /// or null when a need has no gatherable source.
  int? _pursuitGatherCost(GameEngine active, ContentRegistry content) {
    final ContentId? item = active.state.progress.tracked.pursuit;
    if (item == null) return null;
    final PursuitPlan plan = pursuitPlanFor(content, active.state, item);
    int total = 0;
    for (final PursuitNeed need in plan.needs) {
      final ContentId? nodeId = need.sourceNode;
      if (nodeId == null) return null;
      final ResourceNodeDefinition? node = content.resourceNodes[nodeId];
      if (node == null) return null;
      final int perGather = active.profile.applyYield(node.yieldsQuantity);
      final int gathers = (need.quantity + perGather - 1) ~/ perGather;
      total += gathers * active.profile.applyStepCost(node.stepCost);
    }
    return total;
  }

  // -- Persistence ----------------------------------------------------------

  /// Rereads the save from disk and rebuilds the engine from it.
  ///
  /// The recovery from [isStale], and the harness's proof that what is on the
  /// screen is what is on the disk. It replays the journal exactly as a cold
  /// launch does, so a reload that disagrees with the screen is the same defect
  /// a relaunch would show — found in one tap instead of one force-stop.
  /// Null when the bootstrap was blocked and there is no registry to read a
  /// save against — which is an absence of a load rather than a refusal, and
  /// fabricating a `LoadRefused` for it would put a reason on the screen that
  /// the repository never gave.
  Future<LoadOutcome?> reload() async {
    final ContentRegistry? content = registry;
    if (content == null) return null;
    final LoadOutcome outcome = await runtime.repository.load(
      registry: content,
      originSaltFingerprint: saltFingerprint,
    );
    if (outcome is SaveLoaded) {
      _rebuild(outcome, content);
    }
    return outcome;
  }

  void _rebuild(SaveLoaded loaded, ContentRegistry content) {
    _generation = loaded.generation;
    _lastTransaction = loaded.lastAppliedTransaction;
    _stale = false;
    _engine = GameEngine(registry: content, state: loaded.state);
    // Re-derived from what is on disk, the same way bootstrap derives it. A
    // reload after a refused migration commit finds an old-version save and
    // owes it the same migration; a reload after a durable one finds the
    // current version and owes nothing. The report from a migration this
    // launch already completed is kept — it happened, and the disk agrees.
    if (StateVersion.migrationRequired(loaded.state.stateVersion)) {
      final List<StateMigrationStep> path = StateMigrations.pathFrom(
        loaded.state.stateVersion,
      );
      _pendingMigration = PendingStateMigration(
        fromStateVersion: loaded.state.stateVersion,
        steps: path,
      );
    } else {
      _pendingMigration = null;
    }
    _migrationRefusal = null;
  }

  /// Erases every local artifact.
  ///
  /// Developer-only, and the harness confirms before calling it. It goes
  /// through `SaveRepository.eraseAll`, which is resumable and records a marker,
  /// rather than deleting files — a half-deleted save directory is worse than
  /// either state.
  Future<EraseOutcome> resetLocalSave() async {
    final EraseOutcome outcome = await runtime.repository.eraseAll();
    if (outcome is EraseComplete) {
      _generation = -1;
      _lastTransaction = 0;
      _stale = true;
    }
    return outcome;
  }

  Future<CommitOutcome> _commit(
    GameEngine active,
    List<GameEvent> events,
  ) async {
    final CommitOutcome outcome = await runtime.repository.commit(
      after: active.state,
      events: events,
      saveId: saveId!,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: _generation,
        expectedLastAppliedTransaction: _lastTransaction,
      ),
      originSaltFingerprint: saltFingerprint,
    );
    if (outcome is CommitDurable) {
      _generation = outcome.generation;
      _lastTransaction = outcome.transactionId;
    }
    return outcome;
  }

  static void _tally(
    List<StepObservation> observations,
    Set<StepOriginKey> origins,
    Set<TimeBucket> buckets,
  ) {
    for (final StepObservation o in observations) {
      origins.add(o.key.origin);
      buckets.add(o.key.bucket);
    }
  }

  /// Reports the interval only when the delivery actually asserted one.
  ///
  /// A partial delivery has no scope, and rendering `0–0` for it would look like
  /// an answer rather than the absence of one.
  ///
  /// Read through `SyncCompleteness.assertedScope` rather than by switching on
  /// the variants. `Scripts/check-step-model.sh` anchors every mention of the
  /// two settling types to `PlatformStepSource`, and it cannot distinguish a
  /// destructuring pattern from a constructor call — nor should it try, because
  /// the case it exists to catch is worth the false positive. The accessor is
  /// how a diagnostic asks the question without asking for the type.
  static void _readInterval(
    SyncCompleteness completeness,
    void Function(int start, int end) sink,
  ) {
    final CompletenessScope? scope = completeness.assertedScope;
    if (scope == null) return;
    sink(scope.intervalStartMillis, scope.intervalEndMillis);
  }
}

// -- Exploration & Progression Loop 01 view types (`DECISIONS/0023`) -----------

/// One revealed rumor, as the atlas and journal render it.
final class RumorView {
  const RumorView({required this.id, required this.name, required this.hint});

  final ContentId id;
  final String name;
  final String hint;
}

/// What eating outside combat did.
final class FoodReport {
  const FoodReport({
    required this.succeeded,
    required this.itemName,
    this.healed,
    this.hpAfter,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String itemName;

  /// As healed: `min(healing, missing)`, never the raw content value.
  final int? healed;
  final int? hpAfter;
  final String? rejection;
  final String? detail;
}

/// What a goal-tracker change did.
final class GoalReport {
  const GoalReport({required this.succeeded, this.rejection, this.detail});

  final bool succeeded;
  final String? rejection;
  final String? detail;
}

/// One requirement or reward line: an item, a target amount, and how far
/// along the player is. Progress is clamped to the requirement, so the row
/// reads "1 / 3" and never "7 / 3".
final class RequirementLine {
  const RequirementLine({
    required this.item,
    required this.name,
    required this.rarity,
    required this.required,
    required this.progress,
    this.keptNotConsumed = false,
  });

  final ContentId item;
  final String name;
  final Rarity? rarity;
  final int required;
  final int progress;

  /// True for a requirement the board only asks to see — the item is kept.
  final bool keptNotConsumed;

  bool get satisfied => progress >= required;
}

/// One profession-XP reward line, profile-scaled.
final class SkillXpLine {
  const SkillXpLine({required this.skillName, required this.xp});

  final String skillName;
  final int xp;
}

/// A bounty's live standing.
final class BountyView {
  const BountyView({
    required this.enemy,
    required this.enemyName,
    required this.required,
    required this.progress,
    required this.accepted,
  });

  final ContentId enemy;
  final String enemyName;
  final int required;

  /// Qualifying victories since acceptance; zero while not accepted.
  final int progress;
  final bool accepted;

  bool get met => accepted && progress >= required;
}

/// One contract, fully projected for a board card.
///
/// Every flag is a **hint**: `CompleteContract` and `AcceptContract`
/// re-validate on execute (`RULES.md` E-2).
final class ContractView {
  const ContractView({
    required this.id,
    required this.name,
    required this.brief,
    required this.contractClass,
    required this.location,
    required this.requires,
    required this.requiresOwned,
    required this.bounty,
    required this.rewardItems,
    required this.rewardSkillXp,
    required this.rewardCharacterXp,
    required this.teachesRecipeName,
    required this.completions,
    required this.available,
    required this.unavailableReason,
    required this.canComplete,
  });

  final ContentId id;
  final String name;
  final String brief;
  final ContractClass contractClass;
  final ContentId location;

  /// Consumed on completion; progress is what is held now.
  final List<RequirementLine> requires;

  /// Shown-and-kept requirements.
  final List<RequirementLine> requiresOwned;

  final BountyView? bounty;

  /// Reward preview: `required` carries the granted amount.
  final List<RequirementLine> rewardItems;
  final List<SkillXpLine> rewardSkillXp;
  final int rewardCharacterXp;

  /// The recipe this contract teaches on completion, or null.
  final String? teachesRecipeName;

  /// How many times this contract has been completed.
  final int completions;

  /// Whether the board offers it right now; [unavailableReason] is the
  /// engine's own sentence when not.
  final bool available;
  final String? unavailableReason;

  /// Whether a Complete control should be enabled.
  final bool canComplete;

  bool get isCompletedOneTime =>
      contractClass == ContractClass.regional && completions > 0;
}

/// One location's whole board.
final class BoardView {
  const BoardView({
    required this.location,
    required this.boardName,
    required this.developmentState,
    required this.localNeeds,
    required this.bounties,
    required this.regionals,
    required this.projects,
  });

  final ContentId location;

  /// The board's fiction — "Notice Board", "Mine Ledger", …
  final String boardName;

  /// The settlement's named development state, or null.
  final String? developmentState;

  /// The rotation window, in board order.
  final List<ContractView> localNeeds;

  /// Standing repeatable combat orders.
  final List<ContractView> bounties;

  /// One-time regional contracts (completed ones included, flagged).
  final List<ContractView> regionals;

  /// Community projects hosted here.
  final List<ProjectView> projects;
}

/// What one item is for, as the inventory's detail block says it
/// (Fable V2, `DECISIONS/0027`). Every list is display strings; see
/// [StrideSession.itemPurposeOf].
final class ItemPurposeView {
  const ItemPurposeView({
    required this.usedInRecipes,
    required this.wantedBy,
    required this.gatheredAt,
    required this.droppedBy,
    required this.craftedBy,
    required this.healing,
    required this.isTrophy,
    this.upgradesInto = const <LineageEdge>[],
    this.reforgedFrom = const <LineageEdge>[],
  });

  final List<String> usedInRecipes;

  /// Recipes that consume this piece of equipment to make a better one —
  /// the derived lineage (`DECISIONS/0028` §6). The consuming recipe is
  /// deduplicated out of [usedInRecipes].
  final List<LineageEdge> upgradesInto;

  /// The edges that produce this piece by consuming another.
  final List<LineageEdge> reforgedFrom;

  /// Contracts and projects that want it now, with their places.
  final List<String> wantedBy;

  final List<String> gatheredAt;
  final List<String> droppedBy;
  final List<String> craftedBy;

  /// HP restored on eating; zero for anything that is not food.
  final int healing;

  /// A signature or quest keepsake nothing consumes — dead-by-design, and
  /// said so.
  final bool isTrophy;

  bool get isEmpty =>
      usedInRecipes.isEmpty &&
      wantedBy.isEmpty &&
      gatheredAt.isEmpty &&
      droppedBy.isEmpty &&
      craftedBy.isEmpty &&
      upgradesInto.isEmpty &&
      healing == 0 &&
      !isTrophy;
}

/// One derived upgrade edge: recipe [recipeName] consumes [quantity] of
/// [fromName] and produces [toName] (`DECISIONS/0028` §6). Computed from
/// recipes' equipment-consuming ingredients, never authored.
final class LineageEdge {
  const LineageEdge({
    required this.recipeId,
    required this.recipeName,
    required this.fromItem,
    required this.fromName,
    required this.toItem,
    required this.toName,
    required this.quantity,
  });

  final ContentId recipeId;
  final String recipeName;
  final ContentId fromItem;
  final String fromName;
  final ContentId toItem;
  final String toName;
  final int quantity;
}

/// One region's chapter of the Field Notes route — see
/// [StrideSession.bestiary].
final class BestiaryRegionView {
  const BestiaryRegionView({
    required this.locationId,
    required this.locationName,
    required this.isHere,
    required this.entries,
    this.distanceSteps,
  });

  final ContentId locationId;
  final String locationName;
  final bool isHere;

  /// The cheapest journey's step cost from where the player stands, from
  /// the same routing the Set out button quotes. Null when [isHere], or
  /// when no route exists yet.
  final int? distanceSteps;

  final List<EncounterOption> entries;
}

/// The Field Notes route, whole (`DECISIONS/0028` §6).
final class BestiaryView {
  const BestiaryView({
    this.regions = const <BestiaryRegionView>[],
    this.knownCount = 0,
    this.visibleCount = 0,
    this.complete = false,
  });

  final List<BestiaryRegionView> regions;

  /// Known enemies among those currently visible, and the visible total —
  /// a fact line, never a completion meter.
  final int knownCount;
  final int visibleCount;

  /// True when every enemy in the pack is Known — the "complete edition".
  final bool complete;
}

/// An item's place in the derived equipment lineage — see
/// [StrideSession.itemLineageOf].
final class ItemLineageView {
  const ItemLineageView({
    this.upgradesTo = const <LineageEdge>[],
    this.upgradesFrom = const <LineageEdge>[],
  });

  /// Edges where this item is consumed to make something better.
  final List<LineageEdge> upgradesTo;

  /// Edges where this item is the product.
  final List<LineageEdge> upgradesFrom;
}

/// One location's board, folded to the glance the World inspector shows
/// (Fable V2, `DECISIONS/0027`) — the map answers "is there work for me
/// there?" without building the whole board UI into a panel.
///
/// Derived entirely from [StrideSession.boardFor] and
/// [StrideSession.projectsAt]; every count restates a `ContractView` or
/// `ProjectView` fact and decides nothing of its own (`RULES.md` E-2).
final class BoardSummaryView {
  const BoardSummaryView({
    required this.boardName,
    required this.openContracts,
    required this.readyToComplete,
    required this.projectName,
    required this.projectHasSomethingToGive,
  });

  /// The board's fiction — "Notice Board", "Mine Ledger", …
  final String boardName;

  /// Contracts the board offers right now (rotation window, standing
  /// bounties, un-completed regionals).
  final int openContracts;

  /// Of those, how many the player could turn in this instant.
  final int readyToComplete;

  /// The location's community project still under way, or null.
  final String? projectName;

  /// Whether anything in the bag would advance that project now.
  final bool projectHasSomethingToGive;

  /// The one fact that turns a map into a plan: the player is carrying
  /// something this place wants.
  bool get carryingSomethingWanted =>
      readyToComplete > 0 || projectHasSomethingToGive;
}

/// One project stage, with its requirement lines.
final class ProjectStageView {
  const ProjectStageView({
    required this.name,
    required this.complete,
    required this.lines,
  });

  final String name;
  final bool complete;
  final List<RequirementLine> lines;
}

/// One community project, fully projected.
final class ProjectView {
  const ProjectView({
    required this.id,
    required this.name,
    required this.brief,
    required this.location,
    required this.stages,
    required this.currentStage,
    required this.isComplete,
    required this.completionHeadline,
    required this.developmentTo,
    required this.contributable,
    required this.canAdvanceNow,
    this.opens = const <String>[],
    this.isLocked = false,
    this.lockedReason,
    this.followsName,
  });

  final ContentId id;
  final String name;
  final String brief;
  final ContentId location;
  final List<ProjectStageView> stages;

  /// What completing this project opens, by display name — the nodes,
  /// recipes and orders content gates behind it (Fable V2 Iteration 02).
  /// The join is over the same `unlockedByProject` / `requiresProject`
  /// fields the engine refuses with, so the card's promise and the
  /// engine's gate cannot disagree. Empty once complete: a standing mill
  /// does not advertise what it already opened.
  final List<String> opens;

  /// 0-based; the last stage when complete.
  final int currentStage;
  final bool isComplete;
  final String? completionHeadline;
  final String? developmentTo;

  /// What the player could donate right now: item → min(held, remaining).
  /// Empty when nothing in the bag helps.
  final Map<ContentId, int> contributable;

  /// Whether donating everything in [contributable] would complete the
  /// current stage.
  final bool canAdvanceNow;

  /// The `requiresProject` gate (`DECISIONS/0028`): true while the
  /// prerequisite project is incomplete. A locked project stays visible —
  /// [lockedReason] states the gate in the engine's own wording, and
  /// [contributable] stays empty until it opens.
  final bool isLocked;
  final String? lockedReason;

  /// The prerequisite project's display name, whether or not it is complete —
  /// "follows the Mill" — so development reads as a ladder. Null when ungated.
  final String? followsName;

  bool get hasSomethingToGive => contributable.isNotEmpty;
}

/// What a contract command did.
final class ContractReport {
  const ContractReport({
    required this.succeeded,
    required this.contractName,
    this.accepted = false,
    this.consumed = const <RewardLine>[],
    this.rewardItems = const <RewardLine>[],
    this.rewardSkillXp = const <SkillXpLine>[],
    this.characterXp = 0,
    this.levelBefore,
    this.levelAfter,
    this.taughtRecipeName,
    this.revealedRumorNames = const <String>[],
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String contractName;

  /// True when the command was an acceptance rather than a completion.
  final bool accepted;

  final List<RewardLine> consumed;
  final List<RewardLine> rewardItems;
  final List<SkillXpLine> rewardSkillXp;
  final int characterXp;
  final int? levelBefore;
  final int? levelAfter;

  /// The recipe this completion taught, or null.
  final String? taughtRecipeName;
  final List<String> revealedRumorNames;

  final String? rejection;
  final String? detail;

  bool get levelledUp =>
      levelBefore != null && levelAfter != null && levelAfter! > levelBefore!;
}

/// What a project contribution did.
final class ProjectReport {
  const ProjectReport({
    required this.succeeded,
    required this.projectName,
    this.stageName = '',
    this.contributed = const <RewardLine>[],
    this.stageCompleted = false,
    this.projectCompleted = false,
    this.completionHeadline,
    this.characterXp = 0,
    this.levelBefore,
    this.levelAfter,
    this.developmentBefore,
    this.developmentAfter,
    this.revealedRumorNames = const <String>[],
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String projectName;
  final String stageName;
  final List<RewardLine> contributed;
  final bool stageCompleted;
  final bool projectCompleted;

  /// The authored completion banner, on full completion only.
  final String? completionHeadline;
  final int characterXp;
  final int? levelBefore;
  final int? levelAfter;

  /// The settlement's development state around this contribution — the
  /// "Struggling → Recovering" line when they differ.
  final String? developmentBefore;
  final String? developmentAfter;
  final List<String> revealedRumorNames;

  final String? rejection;
  final String? detail;

  bool get developmentChanged =>
      developmentBefore != null &&
      developmentAfter != null &&
      developmentBefore != developmentAfter;

  bool get levelledUp =>
      levelBefore != null && levelAfter != null && levelAfter! > levelBefore!;
}

/// The three tracked slots, projected.
final class TrackedGoalsView {
  const TrackedGoalsView({this.journey, this.pursuit, this.contract});

  final JourneyGoalView? journey;
  final PursuitGoalView? pursuit;
  final ContractGoalView? contract;

  bool get isEmpty => journey == null && pursuit == null && contract == null;
}

/// The Journey slot: a destination and what reaching it costs, against the
/// live balance. Informative, never escrow.
final class JourneyGoalView {
  const JourneyGoalView({
    required this.destination,
    required this.destinationName,
    required this.legNames,
    required this.totalCost,
    required this.banked,
    required this.shortfall,
    required this.ready,
    required this.arrived,
  });

  final ContentId destination;
  final String destinationName;

  /// The cheapest route's stop names, in travel order.
  final List<String> legNames;

  /// Null when no route connects from here.
  final int? totalCost;
  final int banked;

  /// Steps still missing (zero when affordable); null with no route.
  final int? shortfall;

  final bool ready;
  final bool arrived;
}

/// One Pursuit requirement row.
final class PursuitLineView {
  const PursuitLineView({
    required this.name,
    required this.held,
    required this.required,
  });

  final String name;
  final int held;
  final int required;

  bool get satisfied => held >= required;
}

/// One missing base material, with its suggested source.
final class PursuitNeedView {
  const PursuitNeedView({
    required this.name,
    required this.quantity,
    required this.sourceName,
    required this.viaEnemy,
  });

  final String name;
  final int quantity;

  /// "Stonefall Mine" — the place to go, or null when nothing sources it.
  final String? sourceName;

  /// True when the source is an enemy rather than a gathering node.
  final bool viaEnemy;
}

/// The Pursuit slot, fully projected.
final class PursuitGoalView {
  const PursuitGoalView({
    required this.item,
    required this.itemName,
    required this.rarity,
    required this.recipeName,
    required this.lines,
    required this.needs,
    required this.owned,
    required this.complete,
  });

  final ContentId item;
  final String itemName;
  final Rarity? rarity;

  /// The recipe the plan runs against, or null for a drop-only pursuit.
  final String? recipeName;
  final List<PursuitLineView> lines;
  final List<PursuitNeedView> needs;
  final bool owned;
  final bool complete;
}

/// The Contract slot: one contract or one project stage, compactly.
final class ContractGoalView {
  const ContractGoalView({
    required this.id,
    required this.name,
    required this.isProject,
    required this.locationName,
    required this.stageLabel,
    required this.lines,
    required this.readyToAdvance,
    required this.complete,
  });

  final ContentId id;
  final String name;
  final bool isProject;
  final String locationName;

  /// "Stage 2 / 3" for a project; null or "Complete" otherwise.
  final String? stageLabel;
  final List<PursuitLineView> lines;

  /// Whether the tracked thing could be advanced or completed right now.
  final bool readyToAdvance;
  final bool complete;
}

/// The kind of a step-sync highlight.
enum SyncOpportunityKind { journeyReady, pursuit, contract }

/// One step-sync motivation highlight (brief §5): true right now, derived
/// from state, never a reservation and never a notification.
final class SyncOpportunity {
  const SyncOpportunity({
    required this.kind,
    required this.headline,
    required this.detail,
  });

  final SyncOpportunityKind kind;
  final String headline;
  final String detail;
}
