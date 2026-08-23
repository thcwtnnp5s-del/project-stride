/// The bridge between `StrideSession` and the widget tree.
///
/// ## What it is, and deliberately is not
///
/// It is a change *notification*, never a second copy of state. It holds no game
/// figure — no banked steps, no counts, no XP. Widgets read those live through
/// [session] after each notification, which is what keeps `RULES.md` E-2 true:
/// a widget that cached them would be holding durable state of its own, and the
/// cache would be the thing a refused commit made a lie of.
///
/// The only state here is ephemeral and presentational: whether a command is in
/// flight, and the report from the last one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, EquipmentSlot, GoalSlot;

import '../../runtime/stride_session.dart';

/// How long a success or refusal line stays on screen.
///
/// Auto-clearing is load-bearing, not cosmetic. A result line that persists is
/// indistinguishable from a durable "recent gains" system, and no such system
/// exists (Q-UI-7) or is authorised for Phase 1.
const Duration _resultLifetime = Duration(seconds: 5);

/// One walked journey's presentation summary — one or more legs, each an
/// ordinary committed `TravelTo`, aggregated for display only.
///
/// Ephemeral by construction, like every report the controller holds: each
/// figure is copied off a returned [TravelReport], nothing here is a second
/// copy of durable state, and a relaunch has none (`RULES.md` E-2).
///
/// Exists for PRESENTATION_WORLD_REWARD_FEEL_01 B-2: the owner walked
/// Haven → Frostmere, was correctly charged 4,400 across two legs, and the
/// arrival card said "3,000 steps" — the final leg, presented as if it were
/// the trip. The journey total and the final leg are now both first-class.
final class JourneySummary {
  const JourneySummary({
    required this.succeeded,
    required this.destinationName,
    required this.arrivedName,
    required this.totalSpent,
    required this.finalLegCost,
    required this.legsCompleted,
    required this.legsPlanned,
    required this.firstVisit,
    this.failure,
  });

  /// Every leg landed and the player stands at the destination.
  final bool succeeded;

  /// Where the journey was headed.
  final String destinationName;

  /// Where the player actually is now — the destination on success, the last
  /// successful leg's arrival on a mid-way refusal, or the origin when the
  /// first leg refused.
  final String arrivedName;

  /// The sum of every successful leg's charged cost — the journey's true
  /// price, as committed.
  final int totalSpent;

  /// What the last successful leg cost, 0 when no leg landed.
  final int finalLegCost;

  final int legsCompleted;
  final int legsPlanned;

  /// Whether the final arrival opened the destination.
  final bool firstVisit;

  /// The refusing leg's report, or null on success.
  final TravelReport? failure;

  bool get isMultiLeg => legsPlanned > 1;
}

class SessionController extends ChangeNotifier {
  SessionController(this._session);

  final StrideSession _session;

  /// The live session. Widgets read every game figure through this, after each
  /// notification, and never cache what they read.
  StrideSession get session => _session;

  bool _busy = false;
  ActionReport? _lastAction;
  ContentId? _lastActionNode;
  SyncReport? _lastSync;
  TravelReport? _lastTravel;
  CraftReport? _lastCraft;
  ContentId? _lastCraftRecipe;
  EquipReport? _lastEquip;
  bool _lastEquipRemoved = false;
  CombatReport? _lastCombat;
  bool _startupSyncDone = false;
  Timer? _resultTimer;

  /// Called immediately before an **exclusive** command — travel, or any
  /// combat command — executes. The activity queue registers here so starting
  /// a journey or a fight cancels its in-progress repetition safely
  /// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4a).
  ///
  /// One nullable callback, deliberately, and not a listener list or an event
  /// bus: there is exactly one consumer, and the seam should stay too small to
  /// grow sideways. It is presentation wiring — nothing here decides whether
  /// the command runs, and the engine's own refusals
  /// (`resource_node_not_here`, `encounter_in_progress`) remain the authority.
  VoidCallback? onExclusiveCommand;

  /// True while a session command is in flight. For a spinner and a disabled
  /// control — **not** what enforces single-flight. `StrideSession` refuses
  /// re-entrancy itself, because a disabled `onPressed` only takes effect on the
  /// next rebuild and two taps inside one frame both dispatch before
  /// `notifyListeners` ever runs.
  bool get busy => _busy;

  /// The report from the last gather, while it is still on screen.
  ActionReport? get lastAction => _lastAction;
  ContentId? get lastActionNode => _lastActionNode;

  /// The report from the last sync, while it is still on screen.
  SyncReport? get lastSync => _lastSync;

  /// The report from the last single travel leg, while it is still on
  /// screen. Prefer [lastJourney] for presentation — it carries the whole
  /// walk; this remains for the final leg's raw report.
  TravelReport? get lastTravel => _lastTravel;

  /// The last walked journey's summary, while it is still on screen.
  JourneySummary? get lastJourney => _lastJourney;
  JourneySummary? _lastJourney;

  /// The report from the last craft, and which recipe it was — so a card knows
  /// whether the line on screen is about it.
  CraftReport? get lastCraft => _lastCraft;
  ContentId? get lastCraftRecipe => _lastCraftRecipe;

  /// The report from the last equip or unequip, while it is still on screen,
  /// and whether that command was an unequip — the report itself does not say,
  /// and the line reads differently for taking something off.
  EquipReport? get lastEquip => _lastEquip;
  bool get lastEquipRemoved => _lastEquipRemoved;

  /// True while a combat command is in flight.
  ///
  /// Exists for one mounting decision: on a killing blow's mid-commit frame
  /// the encounter is already cleared in memory and the report has not yet
  /// returned, so `session.encounter` and [lastCombat] are BOTH null. The
  /// Adventure screen reading only those two unmounted the whole combat stage
  /// for that frame — the location cards flashed and the victory replay was
  /// skipped. This flag holds the stage up across the gap. A subset of [busy],
  /// never a second source of game state.
  bool _combatBusy = false;
  bool get combatBusy => _combatBusy;

  /// The report from the last combat command — start, attack, eat or retreat.
  ///
  /// **Not on the result timer.** The combat stage plays the round's beats in
  /// order and needs the report to stand until that sequence has played, so
  /// it is cleared by [acknowledgeCombat] (the stage's "OK", or the end of its
  /// sequence) and by the next command — never by the clock. It is still
  /// ephemeral: it is the report the command returned, not state, and a
  /// relaunch has none.
  CombatReport? get lastCombat => _lastCombat;

  /// Clears [lastCombat] once the stage has finished presenting it.
  void acknowledgeCombat() {
    if (_lastCombat == null) return;
    _lastCombat = null;
    notifyListeners();
  }

  /// Runs a foreground step sync and keeps its report for display — and,
  /// when the sync banked something, the step-sync motivation highlights
  /// **this sync made true** (`DECISIONS/0023` §1; brief §5).
  ///
  /// ## Why the highlights are a difference and not a snapshot
  ///
  /// `syncOpportunities()` answers "what is true right now", which is the
  /// right question for a panel and the wrong one for a celebration. Asked
  /// only after the sync, it re-announces every standing fact: the owner's
  /// device raised **Journey Ready — Frostmere can now be reached** on a sync
  /// that banked nothing new, for a journey that had been affordable for
  /// hours. A reward that fires when nothing happened is not a reward, and it
  /// devalues the one that fires when something did.
  ///
  /// So the same projection is taken **before** the sync as a baseline, and
  /// only what is newly true is reported. Nothing about the reward's contents
  /// changes; what changes is that "can now be reached" is now the truth.
  /// A sync that banks steps without crossing any threshold reports the
  /// banked figure alone, which is exactly what happened.
  Future<void> syncSteps() async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      // The baseline, from before anything is granted. A pure projection —
      // it commits nothing and costs no state.
      final Set<String> before = _session
          .syncOpportunities()
          .map(_opportunityKey)
          .toSet();
      _lastSync = await _session.syncSteps();
      final int banked = _lastSync?.newlyGranted ?? 0;
      // Only when walking actually banked, only what the banking made
      // possible, and held until acknowledged — a moment, not a wall of noise.
      _lastOpportunities = banked > 0
          ? _session
                .syncOpportunities()
                .where(
                  (SyncOpportunity o) =>
                      !before.contains(_opportunityKey(o)),
                )
                .toList(growable: false)
          : const <SyncOpportunity>[];
      // The banner outlives `_lastSync`, which the result timer clears. It
      // therefore keeps its own copy of the figure it announces: reading a
      // field that had been nulled underneath it is what produced the
      // owner's "+0 STEPS BANKED" card.
      _lastOpportunityBanked = _lastOpportunities.isEmpty ? 0 : banked;
      _lastOpportunityOrigins = _lastOpportunities.isEmpty
          ? 0
          : (_lastSync?.originCount ?? 0);
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  static String _opportunityKey(SyncOpportunity o) =>
      '${o.kind.name}|${o.headline}|${o.detail}';

  /// The motivation highlights from the last granting sync, until the banner
  /// is dismissed. Empty when the last sync banked nothing, and empty when it
  /// banked something that made nothing newly possible.
  List<SyncOpportunity> get lastOpportunities => _lastOpportunities;
  List<SyncOpportunity> _lastOpportunities = const <SyncOpportunity>[];

  /// What the sync that raised [lastOpportunities] banked. Held beside them
  /// so the banner cannot outlive its own headline figure.
  int get lastOpportunityBanked => _lastOpportunityBanked;
  int _lastOpportunityBanked = 0;

  /// How many step sources the sync behind [lastOpportunities] read from.
  /// A count only (`RULES.md` H-7), held beside the banked figure for the
  /// same reason: the banner owns everything it renders. The banner names
  /// the count only when it exceeds one — a walk recorded by two devices is
  /// banked by both, and the player should be able to see that it was.
  int get lastOpportunityOrigins => _lastOpportunityOrigins;
  int _lastOpportunityOrigins = 0;

  /// Dismisses the step-sync highlights banner.
  void acknowledgeOpportunities() {
    if (_lastOpportunities.isEmpty) return;
    _lastOpportunities = const <SyncOpportunity>[];
    _lastOpportunityBanked = 0;
    _lastOpportunityOrigins = 0;
    notifyListeners();
  }

  // -- Exploration & Progression Loop 01 (`DECISIONS/0023`) -------------------
  //
  // Passthroughs on the shared busy flag, like everything above. Each returns
  // its report so the calling screen can stage the right presentation tier —
  // an inline line for a delivery, a dialog for a taught recipe or a project
  // completion — without the controller holding a growing report museum.

  /// The report from the last out-of-combat meal, while it is on screen.
  FoodReport? get lastFood => _lastFood;
  FoodReport? _lastFood;

  /// Eats one owned consumable outside combat.
  Future<FoodReport?> eatFood(ContentId item) async {
    final FoodReport? report = await _run(() => _session.eatFood(item));
    if (report != null) {
      _lastFood = report;
      _armResultTimer();
      notifyListeners();
    }
    return report;
  }

  /// Sets or clears one tracked-objective slot.
  Future<GoalReport?> trackGoal(GoalSlot slot, ContentId? target) =>
      _run(() => _session.trackGoal(slot, target));

  /// Tracks [contract] (a contract or a project) in the Contract slot.
  Future<GoalReport?> trackGoalContract(ContentId contract) =>
      trackGoal(GoalSlot.contract, contract);

  /// Tracks [item] in the Pursuit slot.
  Future<GoalReport?> trackGoalPursuit(ContentId item) =>
      trackGoal(GoalSlot.pursuit, item);

  /// Tracks [destination] in the Journey slot.
  Future<GoalReport?> trackGoalJourney(ContentId destination) =>
      trackGoal(GoalSlot.journey, destination);

  /// Accepts a bounty contract; victories count from here.
  Future<ContractReport?> acceptContract(ContentId contract) =>
      _run(() => _session.acceptContract(contract));

  /// Completes a contract at its board.
  Future<ContractReport?> completeContract(ContentId contract) =>
      _run(() => _session.completeContract(contract));

  /// Donates materials to a community project's current stage.
  Future<ProjectReport?> contributeToProject(
    ContentId project,
    Map<ContentId, int> contributions,
  ) => _run(() => _session.contributeToProject(project, contributions));

  /// Begins a fresh playtest (`DECISIONS/0025`). A fresh start discards any
  /// running queue, so the activity controller is told first, exactly as a
  /// fight is announced; the baseline-only reset is refused by the engine
  /// while a queue runs, so nothing needs telling.
  Future<PlaytestResetReport?> resetPlaytest({required bool freshStart}) {
    if (freshStart) onExclusiveCommand?.call();
    return _run(() => _session.resetPlaytest(freshStart: freshStart));
  }

  /// One progression-loop command: busy-gated, results cleared, listeners
  /// notified, report returned to the caller. Null when busy.
  Future<T?> _run<T>(Future<T> Function() command) async {
    if (_busy) return null;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      return await command();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Reconciles new foreground health data once, shortly after launch.
  ///
  /// ## What this is, and what it deliberately is not
  ///
  /// It is **one** sync, on the first frame after startup, and nothing more.
  /// `RULES.md` H-5 permits foreground sync only; there is no observer query, no
  /// background delivery, no lifecycle hook, and — asserted by
  /// `s01a_vertical_slice_test.dart` — no `Timer.periodic` anywhere in `lib/`.
  ///
  /// ## Why it runs after the first frame rather than before it
  ///
  /// Startup already awaits `StrideSession.start()` above `runApp`, so the save
  /// is loaded and every figure is real before anything is painted. Awaiting a
  /// HealthKit round trip there too would hold the first frame on a permission
  /// dialog or a slow read.
  ///
  /// Running it after means **save load and health reconciliation stay visibly
  /// distinguishable**, which is what the milestone asked for: the player sees
  /// their real banked figure immediately, and the sync either adds to it or
  /// truthfully says why it could not. There is no flash of zero, because zero
  /// is never rendered — the loaded save is.
  ///
  /// Idempotent by [_startupSyncDone], so a rebuild cannot fire a second one.
  /// A duplicate would grant nothing anyway — the ledger's slice bookkeeping
  /// sees to that — but it would spend a device read and race the manual button.
  ///
  /// Gated by `canSync`, not `isReady`: on the launch that migrates a save to
  /// the Transformation epoch (`DECISIONS/0018`) the session is deliberately
  /// not ready for actions until this sync has run, because the sync is what
  /// completes the migration. `isReady` here would skip the one sync the
  /// cutover is waiting for.
  Future<void> startupSync() async {
    if (_startupSyncDone) return;
    _startupSyncDone = true;
    if (!_session.canSync) return;
    await syncSteps();
  }

  /// Works [node] once.
  ///
  /// Nothing is rendered optimistically across the await. The engine applies the
  /// gather before the commit resolves, so a widget that incremented a count
  /// before awaiting would be showing exactly the "herbs that vanish on the next
  /// launch" the session's own comment names — visible for one frame on success,
  /// and permanently wrong on a refused commit.
  Future<void> gather(ContentId node) async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastAction = await _session.gather(node);
      _lastActionNode = node;
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Walks a route to [destination] — one adjacent leg.
  ///
  /// Nothing is rendered optimistically across the await, for the reason
  /// [gather] gives — and here the optimistic render would be the player's own
  /// location, which is the last thing that should be shown wrong.
  Future<void> travel(ContentId destination) =>
      travelJourney(<ContentId>[destination]);

  /// Walks a whole journey: each entry in [legs] is one adjacent hop,
  /// dispatched as the same one-leg engine command it always was, in order.
  ///
  /// **No new travel semantics.** Every leg is atomic, charged exactly once,
  /// and engine-validated; a refused leg stops the walk truthfully where the
  /// player stands, keeping every leg already committed. What is new is only
  /// the aggregation: [lastJourney] carries the journey's true total beside
  /// the final leg, so a two-leg 4,400-step walk is never presented as its
  /// 3,000-step last road (B-2).
  Future<void> travelJourney(List<ContentId> legs) async {
    if (_busy || legs.isEmpty) return;
    onExclusiveCommand?.call();
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      final String origin = _session.locationName;
      int totalSpent = 0;
      int finalLegCost = 0;
      int completed = 0;
      bool firstVisit = false;
      String arrivedName = origin;
      TravelReport? failure;
      TravelReport? last;
      for (final ContentId leg in legs) {
        final TravelReport report = await _session.travel(leg);
        last = report;
        if (!report.succeeded) {
          failure = report;
          break;
        }
        totalSpent += report.cost;
        finalLegCost = report.cost;
        completed += 1;
        firstVisit = report.firstVisit;
        arrivedName = report.destinationName;
        // Between legs the UI rebuilds from committed state on the final
        // notification; intermediate arrivals are not flashed one by one.
      }
      _lastTravel = last;
      _lastJourney = JourneySummary(
        succeeded: failure == null,
        destinationName: _session.locationNameOf(legs.last) ?? arrivedName,
        arrivedName: arrivedName,
        totalSpent: totalSpent,
        finalLegCost: finalLegCost,
        legsCompleted: completed,
        legsPlanned: legs.length,
        firstVisit: firstVisit,
        failure: failure,
      );
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// One craft repetition dispatched by the craft queue's presentation
  /// (`CraftController`): the same command as [craft], atomically committed,
  /// but the report goes back to the queue rather than onto the shared
  /// result timer — the queue owns its own completion presentation. Null
  /// when another command holds the busy flag; the caller retries on its
  /// injectable timer, exactly as the gather queue does.
  Future<CraftReport?> craftQueued(ContentId recipe) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await _session.craft(recipe);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Makes [recipe] once.
  Future<void> craft(ContentId recipe) async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastCraft = await _session.craft(recipe);
      _lastCraftRecipe = recipe;
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Wears or wields [item]. Costs no steps; the engine swaps out whatever the
  /// slot already held.
  Future<void> equip(ContentId item) =>
      _equipment(() => _session.equip(item), removed: false);

  /// Empties [slot].
  Future<void> unequip(EquipmentSlot slot) =>
      _equipment(() => _session.unequip(slot), removed: true);

  /// One equipment command, like [craft]: nothing is rendered optimistically
  /// across the await, and the report rides the result timer.
  Future<void> _equipment(
    Future<EquipReport> Function() command, {
    required bool removed,
  }) async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastEquip = await command();
      _lastEquipRemoved = removed;
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Begins a fight with [enemy]. Costs no steps.
  Future<void> startEncounter(ContentId enemy) =>
      _combat(() => _session.startEncounter(enemy));

  /// One round: strike, then take the enemy's reply.
  Future<void> combatAttack() => _combat(_session.combatAttack);

  /// One round: eat one [item], then take the enemy's reply.
  Future<void> combatEat(ContentId item) =>
      _combat(() => _session.combatEat(item));

  /// Leaves the fight for the nearest safe place. Nothing is lost.
  Future<void> combatRetreat() => _combat(_session.combatRetreat);

  /// One combat command, like [gather]: nothing is rendered optimistically
  /// across the await, and the report is kept for the stage to play — see
  /// [lastCombat] for why it does not ride the result timer.
  Future<void> _combat(Future<CombatReport> Function() command) async {
    if (_busy) return;
    onExclusiveCommand?.call();
    _busy = true;
    _combatBusy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastCombat = await command();
    } finally {
      _busy = false;
      _combatBusy = false;
      notifyListeners();
    }
  }

  // -- The activity queue (`DECISIONS/0022`) --------------------------------
  //
  // Passthroughs, so queue commands ride the same busy flag and the same
  // notification the other commands do — the header's banked figure rebuilds
  // when a completion spends, because this controller notified, exactly as it
  // does for a manual gather. Reports go back to `ActivityController`, which
  // owns the queue's presentation; none of these rides the result timer.
  //
  // Each returns null when another command holds the busy flag — the
  // activity controller retries on its injectable timer rather than dropping
  // or double-dispatching.

  /// Starts a finite queue at [node]. Null when busy — retry.
  Future<ActivityQueueReport?> startActivityQueue(
    ContentId node,
    int repetitions, {
    required Duration repetitionDuration,
  }) async {
    if (_busy) return null;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      return await _session.startActivityQueue(
        node,
        repetitions,
        repetitionDuration: repetitionDuration,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Reconciles the queue's elapsed time. Null when busy — retry.
  ///
  /// Deliberately does **not** clear the result lines: a repetition boundary
  /// or a resume must not wipe an unrelated report off the screen. Listeners
  /// are notified only when something actually committed.
  Future<ActivityQueueReport?> reconcileActivityQueue() async {
    if (_busy) return null;
    _busy = true;
    try {
      final ActivityQueueReport report = await _session
          .reconcileActivityQueue();
      if (report.completions.isNotEmpty ||
          report.stopReason != null ||
          !report.succeeded) {
        notifyListeners();
      }
      return report;
    } finally {
      _busy = false;
    }
  }

  /// Stops the queue. Null when busy — retry.
  Future<ActivityQueueReport?> stopActivityQueue() async {
    if (_busy) return null;
    _busy = true;
    try {
      return await _session.stopActivityQueue();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The recovery from a stale session: reread the save and rebuild from disk.
  ///
  /// If the disk still holds a save that owes the first-sync migration — the
  /// case where that migration's own commit was the one refused — the reload
  /// re-enters the pending state, and a sync is run straight after so the
  /// session does not sit unready waiting for a tap on a control the pending
  /// state has disabled. The sync grants only what the disk has not already
  /// recorded, and completes the migration.
  Future<void> reload() async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      await _session.reload();
      if (_session.migrationPending && _session.canSync) {
        _lastSync = await _session.syncSteps();
        _armResultTimer();
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _armResultTimer() {
    _resultTimer?.cancel();
    _resultTimer = Timer(
      _resultLifetime,
      () => _clearResults(notify: true, combat: false, opportunities: false),
    );
  }

  /// Clears the result lines. [combat] is false only from the timer: the
  /// combat report is cleared by the next command or by [acknowledgeCombat],
  /// never by the clock. [opportunities] likewise — the step-sync highlights
  /// banner is dismissed by the player or displaced by the next command,
  /// never swept away mid-read by a five-second timer.
  void _clearResults({
    required bool notify,
    bool combat = true,
    bool opportunities = true,
  }) {
    _resultTimer?.cancel();
    _resultTimer = null;
    _lastAction = null;
    _lastActionNode = null;
    _lastSync = null;
    _lastTravel = null;
    _lastJourney = null;
    _lastCraft = null;
    _lastCraftRecipe = null;
    _lastEquip = null;
    _lastEquipRemoved = false;
    _lastFood = null;
    if (combat) _lastCombat = null;
    if (opportunities) {
      _lastOpportunities = const <SyncOpportunity>[];
      _lastOpportunityBanked = 0;
    }
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    // A timer outliving the notifier fires notifyListeners on a disposed object,
    // which throws in debug and leaks in release. Tab switches and hot reload
    // are both ways to get there.
    _resultTimer?.cancel();
    _resultTimer = null;
    super.dispose();
  }
}
