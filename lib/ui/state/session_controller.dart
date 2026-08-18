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
import 'package:stride_core/stride_core.dart' show ContentId;

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
  bool _startupSyncDone = false;
  Timer? _resultTimer;

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

  /// Runs a foreground step sync and keeps its report for display.
  Future<void> syncSteps() async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      _lastSync = await _session.syncSteps();
      _armResultTimer();
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
    _resultTimer = Timer(_resultLifetime, () => _clearResults(notify: true));
  }

  void _clearResults({required bool notify}) {
    _resultTimer?.cancel();
    _resultTimer = null;
    _lastAction = null;
    _lastActionNode = null;
    _lastSync = null;
    _lastTravel = null;
    _lastCraft = null;
    _lastCraftRecipe = null;
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
