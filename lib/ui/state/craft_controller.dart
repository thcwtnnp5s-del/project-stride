/// The crafting flow's presentation queue — short, visible making, over the
/// unchanged instant `CraftItem` command (PRESENTATION_WORLD_REWARD_FEEL_01
/// §14–§16, §55).
///
/// ## What this is, and deliberately is not
///
/// Crafting is **domain-instant and costs no steps**; the owner's device
/// finding was that it *felt* instant — "press Craft, inventory changes,
/// tiny text" — and asked for a real activity presentation. This controller
/// adds exactly that and nothing else:
///
/// - **Start** begins a presentation timer for the first repetition. Nothing
///   is consumed or granted at start.
/// - **Each boundary** dispatches one ordinary `CraftItem` through
///   `SessionController.craft` — the same command a bare button tap ran,
///   with the same atomic commit, exact ingredient consumption, exact
///   output, exact XP, exactly once. A refusal stops the queue truthfully.
/// - **Cancel** keeps every completed craft and dispatches nothing more; the
///   in-progress repetition consumed nothing because nothing is consumed
///   until its boundary's command commits.
/// - **Backgrounding fast-forwards the remainder**: the timer is theatre,
///   the crafts are instant, and the owner's preference is that a queue
///   never requires the phone to stay open (§55). On `paused` the controller
///   dispatches every remaining repetition immediately, engine-validated
///   each time. A force-quit mid-queue keeps completed crafts and grants
///   nothing for undispatched ones — the documented behaviour.
///
/// **No schema change, no new `RULES.md` P-4 exception**: nothing here
/// advances by wall-clock time in the domain's sense — there is no durable
/// queue, no anchor, and closing the app mid-queue loses only theatre.
///
/// Timing is injectable ([ActivityTiming], the same seam the gather queue
/// uses) so tests advance deterministically.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, ItemCategory;

import '../../runtime/stride_session.dart'
    show CraftReport, RecipeOption, StrideSession;
import 'activity_controller.dart' show ActivityTiming;
import 'session_controller.dart';

/// How long one crafted repetition's presentation takes (§15) — authored
/// presentation pacing, not domain content, exactly like
/// `ActivityDurations`. These are the starting targets the brief names.
abstract final class CraftDurations {
  const CraftDurations._();

  static const Duration component = Duration(seconds: 3);
  static const Duration food = Duration(seconds: 4);
  static const Duration equipment = Duration(seconds: 6);

  static Duration of(RecipeOption recipe) => switch (recipe.outputCategory) {
    ItemCategory.consumable => food,
    ItemCategory.equipment => equipment,
    _ => component,
  };
}

/// How long the finished queue's summary stays on the panel — the same
/// lifetime every other result line gets, for the same reason.
const Duration _summaryLifetime = Duration(seconds: 6);

/// Retry pace when a dispatch finds the session busy.
const Duration _busyRetry = Duration(milliseconds: 250);

class CraftController extends ChangeNotifier with WidgetsBindingObserver {
  CraftController(this._sessions, {ActivityTiming? timing}) {
    _timing =
        timing ??
        ActivityTiming.real(
          wallClock: () => _sessions.session.activityWallClock(),
        );
    WidgetsBinding.instance.addObserver(this);
  }

  /// The most repetitions one craft queue may hold (§16: x1 / x5 / x10).
  static const int maxQueue = 10;

  final SessionController _sessions;
  late final ActivityTiming _timing;

  StrideSession get _session => _sessions.session;

  ContentId? _recipe;
  int _requested = 0;
  int _completed = 0;
  bool _running = false;
  bool _stopRequested = false;
  bool _dispatchInFlight = false;
  int _durationMillis = 3000;
  int _repetitionStartedAt = 0;

  Timer? _timer;
  Timer? _summaryTimer;

  // Cumulative gains this queue, accumulated from the returned reports.
  String? _outputName;
  int _quantity = 0;
  int _xp = 0;
  String? _skillName;

  /// The last completed craft's full report — the completion feedback panel
  /// reads it for the equipment reveal (stat delta, rarity, level-up).
  CraftReport? _lastReport;

  /// The refusal that stopped the queue, when one did.
  CraftReport? _stopReport;

  // -- What the UI reads ------------------------------------------------------

  bool get active => _running;
  ContentId? get activeRecipe => _running ? _recipe : null;

  /// The recipe the retained finished-queue summary is about, or null.
  ContentId? get summaryRecipe => _running ? null : _recipe;

  int get queued => _requested;
  int get completed => _completed;

  Duration get repetitionDuration => Duration(milliseconds: _durationMillis);

  /// Presentation time into the current repetition, clamped.
  Duration get elapsedOfCurrent {
    if (!_running) return Duration.zero;
    int elapsed = _timing.nowEpochMillis() - _repetitionStartedAt;
    if (elapsed < 0) elapsed = 0;
    if (elapsed > _durationMillis) elapsed = _durationMillis;
    return Duration(milliseconds: elapsed);
  }

  String? get outputName => _outputName;
  int get quantity => _quantity;
  int get xp => _xp;
  String? get skillName => _skillName;
  CraftReport? get lastReport => _lastReport;
  CraftReport? get stopReport => _stopReport;

  // -- Commands ---------------------------------------------------------------

  /// Begins a presentation queue of [count] crafts of [recipe].
  void start(RecipeOption recipe, int count) {
    if (_running) return;
    _clearSummary();
    _recipe = recipe.id;
    _requested = count.clamp(1, maxQueue);
    _completed = 0;
    _running = true;
    _stopRequested = false;
    _durationMillis = CraftDurations.of(recipe).inMilliseconds;
    _repetitionStartedAt = _timing.nowEpochMillis();
    _armBoundary();
    notifyListeners();
  }

  /// Cancels the queue: completed crafts remain, the in-progress repetition
  /// dispatches nothing (§16 cancellation semantics).
  void stop() {
    if (!_running || _stopRequested) return;
    _stopRequested = true;
    _cancelTimer();
    _finish();
  }

  // -- Lifecycle --------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // The §55 choice: the player put the phone away — finish the theatre
      // instantly. Every remaining repetition is the same validated command;
      // the first refusal stops the run truthfully.
      _cancelTimer();
      _fastForward();
    }
  }

  Future<void> _fastForward() async {
    while (_running && !_stopRequested && _completed < _requested) {
      final bool advanced = await _dispatchOne();
      if (!advanced) return; // refusal or retry state already handled
    }
    if (_running) _finish();
  }

  // -- The machine ------------------------------------------------------------

  void _armBoundary() {
    _cancelTimer();
    final int remaining =
        _repetitionStartedAt + _durationMillis - _timing.nowEpochMillis();
    _timer = _timing.startTimer(
      Duration(milliseconds: remaining < 0 ? 0 : remaining),
      () {
        _timer = null;
        _onBoundary();
      },
    );
  }

  Future<void> _onBoundary() async {
    if (!_running || _stopRequested) return;
    final bool advanced = await _dispatchOne();
    if (!advanced || !_running) return;
    if (_completed >= _requested) {
      _finish();
      return;
    }
    _repetitionStartedAt = _timing.nowEpochMillis();
    _armBoundary();
    notifyListeners();
  }

  /// Dispatches exactly one craft. Returns false when the caller should not
  /// continue (busy retry armed, refusal finished the queue, or a stop).
  Future<bool> _dispatchOne() async {
    if (_dispatchInFlight) return false;
    if (_sessions.busy || _session.isBusy) {
      _retryLater(_onBoundary);
      return false;
    }
    _dispatchInFlight = true;
    final CraftReport? report = await _sessions.craftQueued(_recipe!);
    _dispatchInFlight = false;
    if (!_running || _stopRequested) return false;
    if (report == null) {
      _retryLater(_onBoundary);
      return false;
    }
    if (!report.succeeded) {
      _stopReport = report;
      _finish();
      return false;
    }
    _completed += 1;
    _lastReport = report;
    _outputName = report.outputName ?? _outputName;
    _quantity += report.quantity ?? 0;
    _xp += report.experience ?? 0;
    _skillName = report.skillName ?? _skillName;
    return true;
  }

  void _retryLater(void Function() action) {
    _cancelTimer();
    _timer = _timing.startTimer(_busyRetry, () {
      _timer = null;
      action();
    });
  }

  void _finish() {
    _running = false;
    _stopRequested = false;
    if (_completed > 0 || _stopReport != null) {
      _summaryTimer?.cancel();
      _summaryTimer = _timing.startTimer(_summaryLifetime, () {
        _summaryTimer = null;
        _clearSummary();
        notifyListeners();
      });
    } else {
      _clearSummary();
    }
    notifyListeners();
  }

  void _clearSummary() {
    _summaryTimer?.cancel();
    _summaryTimer = null;
    _recipe = null;
    _requested = 0;
    _completed = 0;
    _outputName = null;
    _quantity = 0;
    _xp = 0;
    _skillName = null;
    _lastReport = null;
    _stopReport = null;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _summaryTimer?.cancel();
    _summaryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Makes the [CraftController] reachable from the Craft screen, beside the
/// other scopes and for the same reasons.
class CraftScope extends InheritedNotifier<CraftController> {
  const CraftScope({
    super.key,
    required CraftController controller,
    required super.child,
  }) : super(notifier: controller);

  static CraftController of(BuildContext context) {
    final CraftScope? scope = context
        .dependOnInheritedWidgetOfExactType<CraftScope>();
    assert(scope != null, 'No CraftScope above this widget.');
    return scope!.notifier!;
  }

  static CraftController read(BuildContext context) {
    final CraftScope? scope = context
        .getInheritedWidgetOfExactType<CraftScope>();
    assert(scope != null, 'No CraftScope above this widget.');
    return scope!.notifier!;
  }
}
