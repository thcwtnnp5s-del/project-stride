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

import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'runtime_bootstrap.dart';

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
}

/// One line of the player's inventory, ready to render.
final class InventoryEntry {
  const InventoryEntry({
    required this.id,
    required this.displayName,
    required this.category,
    required this.count,
  });

  final ContentId id;
  final String displayName;

  /// Null when the content pack has no definition for [id] — which is a content
  /// problem, not a rendering one, so it is reported rather than defaulted.
  final ItemCategory? category;

  /// Always greater than zero.
  final int count;
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
  });

  final ContentId id;
  final String displayName;

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
    required this.outputQuantity,
    required this.experience,
  });

  final ContentId id;
  final String displayName;
  final String skillName;
  final int requiredLevel;
  final int currentLevel;

  final List<RecipeIngredientLine> ingredients;

  final ContentId outputItem;
  final String outputName;

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

/// A running game, with the health source opened if one could be.
///
/// Created by [start], which is the only entry point. A blocked bootstrap
/// produces a session with [outcome] set to `BootstrapBlocked` and no engine —
/// the harness renders the refusal rather than crashing, because a refusal is a
/// state the app is supposed to be able to present.
final class StrideSession {
  // The engine and the durable head are positional, and the rest are named.
  // A named parameter cannot begin with an underscore, so an initializing
  // formal for a private field is not expressible any other way — the same
  // constraint `IdentityVault` documents.
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
    this.migration,
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
  }) async {
    final StrideRuntime runtime = await bootstrapStride(
      overrideRoot: overrideRoot,
    );
    final BootstrapOutcome outcome = runtime.outcome;

    GameEngine? engine;
    ContentRegistry? registry;
    String? saveId;
    int generation = -1;
    int lastTransaction = 0;
    StateMigrationReport? migration;

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
        final CommitExpectation head = outcome.expectation;
        generation = head.expectedSnapshotGeneration;
        lastTransaction = head.expectedLastAppliedTransaction;
        migration = outcome.migration;
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
      migration: migration,
    );
  }

  final StrideRuntime runtime;
  final BootstrapOutcome outcome;

  /// Set when *this launch* re-based the playable economy (`DECISIONS/0016`).
  ///
  /// Null on every ordinary launch, including every launch after the first. It
  /// exists so the acceptance script can see the cutover happen once and then
  /// never again — a migration nobody can observe is one nobody can verify.
  final StateMigrationReport? migration;

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

  bool get isReady => engine != null && !_stale && !_inFlight;

  /// Banked energy: granted and unspent. Never expires (`DECISIONS/0008`).
  int get usableEnergy => engine?.state.steps.banked ?? 0;

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
      return await _syncSteps(maxPages);
    } finally {
      _inFlight = false;
    }
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

    if (active == null || content == null || _stale) {
      return ActionReport(
        succeeded: false,
        nodeName: name,
        cost: cost,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
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

    if (active == null || content == null || _stale) {
      return TravelReport(
        succeeded: false,
        destinationName: name,
        cost: 0,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
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

    if (active == null || content == null || _stale) {
      return CraftReport(
        succeeded: false,
        recipeName: name,
        rejection: 'session_not_ready',
        detail: _stale
            ? 'the last commit did not land; reload before acting'
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
          count: e.value,
        ),
    ];
  }

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

    final int banked = active.state.steps.banked;
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

  /// Steps that were banked before the Phase 2 cutover and are not spendable.
  ///
  /// Zero for a game that has never migrated. Surfaced rather than hidden: the
  /// owner walked these, and a product that silently forgot them would be lying
  /// about its own history (`DECISIONS/0016`).
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
