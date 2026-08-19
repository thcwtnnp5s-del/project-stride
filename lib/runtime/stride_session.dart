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
  });

  final ContentId id;
  final String name;

  /// Null only when the content pack has no definition for [id].
  final Rarity? rarity;
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
    required this.requiredLevel,
    required this.currentLevel,
    required this.ingredients,
    required this.outputItem,
    required this.outputName,
    required this.outputRarity,
    required this.outputQuantity,
    required this.experience,
  });

  final ContentId id;
  final String displayName;
  final String skillName;
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

  /// Profile-scaled, as it would be produced.
  final int outputQuantity;

  /// Profile-scaled, as it would be awarded.
  final int experience;

  bool get skillMet => currentLevel >= requiredLevel;

  bool get ingredientsMet =>
      ingredients.every((RecipeIngredientLine i) => i.satisfied);

  bool get canCraft => skillMet && ingredientsMet;
}

/// One line of a recipe's requirements, with what the player actually holds.
final class RecipeIngredientLine {
  const RecipeIngredientLine({
    required this.item,
    required this.displayName,
    required this.required,
    required this.held,
  });

  final ContentId item;
  final String displayName;
  final int required;
  final int held;

  bool get satisfied => held >= required;

  int get shortfall {
    final int gap = required - held;
    return gap < 0 ? 0 : gap;
  }
}

/// One thing a skill level gates, and whether the player has it yet.
final class SkillUnlock {
  const SkillUnlock({
    required this.displayName,
    required this.requiredLevel,
    required this.unlocked,
    required this.where,
  });

  final String displayName;
  final int requiredLevel;
  final bool unlocked;

  /// The location that hosts it, for a gathering node. Null for a recipe, which
  /// can be made anywhere.
  final String? where;
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
    this.outputName,
    this.quantity,
    this.skillName,
    this.experience,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String recipeName;
  final String? outputName;
  final int? quantity;
  final String? skillName;
  final int? experience;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;
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
    this.itemName,
    this.quantity,
    this.skillName,
    this.experience,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String nodeName;

  /// Profile-scaled, as it would be charged. Shown before the action is taken,
  /// which is why it is on the report rather than only on the event.
  final int cost;

  final String? itemName;
  final int? quantity;

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

  /// The stable [RejectionCode.wire] value, or null on success.
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

  /// `encounter_in_progress` · `enemy_driven_off` · `session_not_ready`, or
  /// null when [available].
  final String? reason;
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
final class PlayerStruckBeat extends CombatBeat {
  const PlayerStruckBeat({required this.damage, required this.enemyHpAfter});

  final int damage;
  final int enemyHpAfter;
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

/// The enemy hit the player. A flurry produces two per round, [strikeIndex]
/// 0 and 1; a guarded enemy's every-third-turn blow carries [heavy].
final class EnemyStruckBeat extends CombatBeat {
  const EnemyStruckBeat({
    required this.damage,
    required this.playerHpAfter,
    required this.heavy,
    required this.strikeIndex,
  });

  final int damage;
  final int playerHpAfter;
  final bool heavy;
  final int strikeIndex;
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

  bool get levelledUp => levelAfter > levelBefore;
}

/// The player fell and was moved to [retreatToName]. Nothing was lost.
final class LostBeat extends CombatBeat {
  const LostBeat({required this.retreatToName});

  final String retreatToName;
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
final class EquipReport {
  const EquipReport({
    required this.succeeded,
    required this.itemName,
    this.rejection,
    this.detail,
  });

  final bool succeeded;
  final String itemName;

  /// The stable [RejectionCode.wire] value, or null on success.
  final String? rejection;
  final String? detail;
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

  /// Whether a durable cursor exists. **Never its contents.**
  ///
  /// The bytes are an opaque Health Connect changes token. Rendering them would
  /// put platform sync state on a screen and, from there, into a screenshot in
  /// a bug report.
  bool get hasCursor => engine?.state.steps.checkpoint.cursor != null;

  int get syncCount => engine?.state.steps.checkpoint.syncCount ?? 0;

  SourceState get sourceState =>
      engine?.state.steps.sourceState ?? SourceState.unknown;

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

  /// The profile-scaled cost of working [node], or null when it is not content.
  ///
  /// Read from the registry through the same profile the engine charges with,
  /// so the number on the button and the number debited cannot disagree.
  int? costOf(ContentId node) {
    final ResourceNodeDefinition? definition = registry?.resourceNodes[node];
    if (definition == null || registry == null) return null;
    return registry!.profile.applyStepCost(definition.stepCost);
  }

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
    return ActionReport(
      succeeded: true,
      nodeName: name,
      cost: gathered.stepsSpent,
      itemName:
          content.items[gathered.item]?.displayName ?? gathered.item.value,
      quantity: gathered.quantity,
      // Both taken from the event rather than from the node definition, for the
      // reason on the type: the definition's figures are unscaled base values.
      skillName:
          content.skills[gathered.skill]?.displayName ?? gathered.skill.value,
      experience: gathered.experience,
    );
  }

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
    return CraftReport(
      succeeded: true,
      recipeName: name,
      outputName:
          content.items[crafted.item]?.displayName ?? crafted.item.value,
      quantity: crafted.quantity,
      skillName:
          content.skills[crafted.skill]?.displayName ?? crafted.skill.value,
      experience: crafted.experience,
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
      if (active == null || registry == null || _stale || migrationPending) {
        return EquipReport(
          succeeded: false,
          itemName: name,
          rejection: 'session_not_ready',
          detail: _notReadyDetail,
        );
      }
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
      return EquipReport(succeeded: true, itemName: name);
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
      ),
      CombatConsumableUsed() => ConsumableUsedBeat(
        itemName: itemName(event.item),
        healed: event.healed,
        playerHpAfter: event.playerHpAfter,
      ),
      CombatEnemyStruck() => EnemyStruckBeat(
        damage: event.damage,
        playerHpAfter: event.playerHpAfter,
        heavy: event.heavy,
        strikeIndex: event.strikeIndex,
      ),
      CombatRoundEnded() => RoundEndedBeat(
        turn: event.turn,
        telegraph: event.telegraph,
      ),
      EncounterWon() => WonBeat(
        xp: event.characterXp,
        levelBefore: event.levelBefore,
        levelAfter: event.levelAfter,
        drops: <RewardLine>[
          for (final MapEntry<ContentId, int> d in event.drops.entries)
            RewardLine(
              id: d.key,
              name: itemName(d.key),
              quantity: d.value,
              rarity: content.items[d.key]?.rarity,
            ),
        ],
      ),
      EncounterLost() => LostBeat(retreatToName: placeName(event.retreatTo)),
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
    );
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
        if (enemy.location == here)
          () {
            final int remaining = active.state.world.remaining(
              enemy.id,
              enemy.encountersPerVisit,
            );
            final String? reason = fighting
                ? 'encounter_in_progress'
                : remaining <= 0
                ? 'enemy_driven_off'
                : !ready
                ? 'session_not_ready'
                : null;
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
                    name:
                        content.items[drop.item]?.displayName ??
                        drop.item.value,
                    rarity: content.items[drop.item]?.rarity,
                  ),
              ],
              encountersPerVisit: enemy.encountersPerVisit,
              remainingThisVisit: remaining,
              available: reason == null,
              reason: reason,
            );
          }(),
    ];
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
          if (enemy.location == place.id)
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

    final List<RecipeOption> options = <RecipeOption>[
      for (final RecipeDefinition recipe in content.recipes.values)
        if (content.skills[recipe.skill] case final SkillDefinition skill)
          RecipeOption(
            id: recipe.id,
            displayName: recipe.displayName,
            skillName: skill.displayName,
            requiredLevel: recipe.requiredLevel,
            currentLevel: skill.levelAt(
              active.state.skills.experienceIn(recipe.skill),
            ),
            ingredients: <RecipeIngredientLine>[
              for (final RecipeIngredient i in recipe.ingredients)
                RecipeIngredientLine(
                  item: i.item,
                  displayName:
                      content.items[i.item]?.displayName ?? i.item.value,
                  required: i.quantity,
                  held: active.state.inventory.quantityOf(i.item),
                ),
            ],
            outputItem: recipe.outputItem,
            outputName:
                content.items[recipe.outputItem]?.displayName ??
                recipe.outputItem.value,
            outputRarity: content.items[recipe.outputItem]?.rarity,
            outputQuantity: active.profile.applyYield(recipe.outputQuantity),
            experience: active.profile.applyXp(recipe.xp),
          ),
    ];

    // Craftable first, then by the skill level they ask for. The player's own
    // progression is the order they think in, and "what can I make now" should
    // not be at the bottom of a list sorted alphabetically.
    options.sort((RecipeOption a, RecipeOption b) {
      if (a.canCraft != b.canCraft) return a.canCraft ? -1 : 1;
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

    final List<SkillUnlock> unlocks = <SkillUnlock>[
      for (final ResourceNodeDefinition node in content.resourceNodes.values)
        if (node.skill == skill)
          SkillUnlock(
            displayName: node.displayName,
            requiredLevel: node.requiredLevel,
            unlocked: level >= node.requiredLevel,
            where: _hostOf(node.id, content),
          ),
      for (final RecipeDefinition recipe in content.recipes.values)
        if (recipe.skill == skill)
          SkillUnlock(
            displayName: recipe.displayName,
            requiredLevel: recipe.requiredLevel,
            unlocked: level >= recipe.requiredLevel,
            where: null,
          ),
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

  /// The refusal, when the bootstrap was blocked. Null on a started game.
  ///
  /// Exposed as its own accessor so a screen can branch without pattern-matching
  /// on [outcome] and, from there, discovering `outcome.engine`.
  BootstrapBlocked? get blocked {
    final BootstrapOutcome o = outcome;
    return o is BootstrapBlocked ? o : null;
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
