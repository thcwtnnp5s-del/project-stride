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

  /// The report from the last journey, while it is still on screen.
  TravelReport? get lastTravel => _lastTravel;

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
  /// derived from the tracked goals (`DECISIONS/0023` §1; brief §5).
  Future<void> syncSteps() async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastSync = await _session.syncSteps();
      // Derived from the actual post-sync state, only when walking actually
      // banked, and held until acknowledged — a moment, not a wall of noise.
      _lastOpportunities = (_lastSync?.newlyGranted ?? 0) > 0
          ? _session.syncOpportunities()
          : const <SyncOpportunity>[];
      _armResultTimer();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The motivation highlights from the last granting sync, until the banner
  /// is dismissed. Empty when the last sync banked nothing.
  List<SyncOpportunity> get lastOpportunities => _lastOpportunities;
  List<SyncOpportunity> _lastOpportunities = const <SyncOpportunity>[];

  /// Dismisses the step-sync highlights banner.
  void acknowledgeOpportunities() {
    if (_lastOpportunities.isEmpty) return;
    _lastOpportunities = const <SyncOpportunity>[];
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

  /// Walks a route to [destination].
  ///
  /// Nothing is rendered optimistically across the await, for the reason
  /// [gather] gives — and here the optimistic render would be the player's own
  /// location, which is the last thing that should be shown wrong.
  Future<void> travel(ContentId destination) async {
    if (_busy) return;
    onExclusiveCommand?.call();
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastTravel = await _session.travel(destination);
      _armResultTimer();
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
    _lastCraft = null;
    _lastCraftRecipe = null;
    _lastEquip = null;
    _lastEquipRemoved = false;
    _lastFood = null;
    if (combat) _lastCombat = null;
    if (opportunities) _lastOpportunities = const <SyncOpportunity>[];
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
