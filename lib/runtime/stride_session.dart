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

    switch (outcome) {
      case BootstrapNewGame(:final SaveLoaded load):
        engine = outcome.engine;
        registry = outcome.registry;
        saveId = outcome.identity.saveId;
        generation = load.generation;
        lastTransaction = load.lastAppliedTransaction;
      case BootstrapExistingGame(:final SaveLoaded load):
        engine = outcome.engine;
        registry = outcome.registry;
        saveId = outcome.identity.saveId;
        generation = load.generation;
        lastTransaction = load.lastAppliedTransaction;
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
    );
  }

  final StrideRuntime runtime;
  final BootstrapOutcome outcome;

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

  /// How many of [item] the player holds.
  int inventoryCount(ContentId item) =>
      engine?.state.inventory.quantityOf(item) ?? 0;

  /// The player's current location, by display name.
  String get locationName {
    final ContentId? here = engine?.state.world.currentLocation;
    if (here == null) return '—';
    return registry?.locations[here]?.displayName ?? here.value;
  }

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
