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

  /// The recovery from a stale session: reread the save and rebuild from disk.
  Future<void> reload() async {
    if (_busy) return;
    _busy = true;
    _clearResults(notify: false);
    notifyListeners();
    try {
      await _session.reload();
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
