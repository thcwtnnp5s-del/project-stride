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
/// - **Backgrounding does not complete anything.** The queue carries a
///   wall-clock **anchor** for the repetition in flight, exactly as the
///   gathering queue does (`DECISIONS/0022` §6). Going to the background
///   cancels only the foreground boundary timer; the anchor stays, elapsed
///   time keeps accruing against it, and **the resume reconciles** — it
///   commits only the whole repetitions the elapsed time legitimately
///   completed, clamped to the requested count, and advances the anchor by
///   exactly the completions it committed. Backgrounding is never itself a
///   completion trigger, and no amount of elapsed time can produce more
///   than the count the player asked for.
///
/// **Where this deliberately differs from gathering, and why.** The gather
/// queue is durable state in the save (`GameState.activityQueue`, v6)
/// because each completion *spends banked steps* the player committed, so a
/// killed process must not lose them. Crafting costs no steps and its queue
/// is **ephemeral presentation**: a force-quit or an OS eviction ends the
/// run, granting nothing and consuming nothing for repetitions that had not
/// committed, while every repetition that did commit is already atomically
/// on disk. Nothing is owed and nothing is lost, so no schema addition is
/// warranted (brief §56).
///
/// ## Why this is not a second `RULES.md` P-4 exception
///
/// P-4 forbids *wall-clock progression masquerading as walking* — time
/// standing in for movement. Nothing here does that, and the reason is
/// structural rather than a promise: **crafting is free and instant in the
/// domain**. A player can make ten planks with ten taps, right now, at zero
/// step cost; the queue's clock cannot unlock anything those taps could not
/// already produce. Time is a **brake on presentation**, never an engine of
/// production — it delays output the player had already earned by walking
/// for the ingredients, and it can produce nothing beyond the count they
/// asked for. `DECISIONS/0022`'s exception exists because gathering's
/// completions *spend banked steps*; there is no equivalent claim to make
/// here, so no new decision is owed.
///
/// It also adds **no schema change**: the anchor is in memory, and a killed
/// process ends the run rather than resuming it (see above).
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

/// How long one crafted repetition takes at the bench.
///
/// **Crafting costs zero steps**, so it cannot take the gathering pace
/// (100 steps a minute); instead every shipped recipe authors its own
/// `craftSeconds` in `recipes.json` (the correction pass, finding I) so a
/// component is a small job (30–45 s), a meal a little longer (45–90 s) and
/// a piece of gear a real one (120–180 s). These category defaults catch a
/// recipe that authored none. Presentation pacing only: the engine
/// validates and commits each repetition unchanged, and a queue frozen at
/// start keeps its own figure.
abstract final class CraftDurations {
  const CraftDurations._();

  static const Duration component = Duration(seconds: 40);
  static const Duration food = Duration(seconds: 60);
  static const Duration equipment = Duration(seconds: 120);

  static Duration of(RecipeOption recipe) {
    if (recipe.craftSeconds case final int authored) {
      return Duration(seconds: authored);
    }
    return switch (recipe.outputCategory) {
      ItemCategory.consumable => food,
      ItemCategory.equipment => equipment,
      _ => component,
    };
  }
}

/// How long the finished queue's summary stays on the panel — the same
/// lifetime every other result line gets, for the same reason.
/// A MINOR result's life on the card. Four seconds: long enough to read
/// `CRAFTED · Bronze Ingot ×1 · +30 Smithing XP`, short enough never to read
/// as bookkeeping the card kept (the correction pass, finding C).
const Duration _summaryLifetime = Duration(seconds: 4);

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

  /// The wall-clock instant the repetition in flight began — the same
  /// anchor semantics `GameState.activityQueue` carries for gathering. It
  /// advances by exactly one duration per COMMITTED repetition, which is
  /// what makes reconciliation exactly-once (`DECISIONS/0022` §6).
  int _anchor = 0;

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
    int elapsed = _timing.nowEpochMillis() - _anchor;
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
    _anchor = _timing.nowEpochMillis();
    _armBoundary();
    notifyListeners();
  }

  /// Cancels the queue (`DECISIONS/0022` §7): every repetition that had
  /// **fully elapsed** when the player tapped Cancel still commits, the
  /// partial one is discarded, and the remainder is dropped. The partial
  /// repetition consumed nothing, because nothing is consumed until its
  /// boundary command commits.
  void stop() {
    if (!_running || _stopRequested) return;
    _stopRequested = true;
    _cancelTimer();
    _settleStop();
  }

  // -- Lifecycle --------------------------------------------------------------

  /// The last lifecycle state the binding reported. Null — never reported,
  /// the widget-test harness and a fresh launch — is treated as foreground,
  /// the same seam `ActivityController` documents.
  AppLifecycleState? _lifecycle;

  bool get _halted =>
      _lifecycle != null && _lifecycle != AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    final bool wasHalted = _halted;
    _lifecycle = state;
    if (!_running || _halted == wasHalted) return;

    if (_halted) {
      // Background: cancel the foreground boundary timer and NOTHING else.
      // The anchor is kept and elapsed time keeps accruing against it; the
      // resume reconciles (`DECISIONS/0022` §6). Backgrounding must never be
      // a completion trigger — an earlier revision of this controller
      // dispatched the whole remainder here, which made Home a Skip Queue
      // button, and that is the defect this shape exists to prevent.
      _cancelTimer();
      notifyListeners();
      return;
    }

    // Resumed: everything that legitimately elapsed commits now, once.
    _reconcile();
    notifyListeners();
  }

  // -- The machine ------------------------------------------------------------

  /// How many whole repetitions the elapsed time has completed but not yet
  /// committed — clamped to what remains of the request, and to zero against
  /// a backward clock. The **only** source of "how many should land".
  int _dueCount() {
    if (_durationMillis <= 0) return _requested - _completed;
    final int elapsed = _timing.nowEpochMillis() - _anchor;
    if (elapsed <= 0) return 0;
    final int whole = elapsed ~/ _durationMillis;
    final int remaining = _requested - _completed;
    return whole < remaining ? whole : remaining;
  }

  /// Commits every repetition the clock has legitimately finished, advancing
  /// the anchor by exactly the completions it commits, then re-arms.
  ///
  /// Exactly-once comes from the anchor arithmetic, not from the timers: a
  /// second reconcile with no further elapsed time finds `_dueCount() == 0`
  /// and commits nothing.
  Future<void> _reconcile() async {
    if (!_running || _stopRequested || _dispatchInFlight) return;

    int due = _dueCount();
    while (due > 0) {
      final bool committed = await _dispatchOne();
      // A refusal, a busy retry or a stop mid-flight: that path has already
      // decided what happens next, and the anchor must not move.
      if (!committed) return;
      _anchor += _durationMillis;
      due -= 1;
      if (_completed >= _requested) {
        _finish();
        return;
      }
      if (!_running || _stopRequested) return;
    }
    _armBoundary();
    notifyListeners();
  }

  /// Arms the one-shot timer for the moment the current repetition is due —
  /// never `Timer.periodic`, and never while halted (the resume reconciles
  /// instead). A boundary already in the past arms at zero and lands on the
  /// next tick, where [_reconcile] sees it as due.
  void _armBoundary() {
    _cancelTimer();
    if (_halted || !_running) return;
    final int remaining =
        _anchor + _durationMillis - _timing.nowEpochMillis();
    _timer = _timing.startTimer(
      Duration(milliseconds: remaining < 0 ? 0 : remaining),
      () {
        _timer = null;
        _reconcile();
      },
    );
  }

  /// Dispatches exactly one craft. Returns true only when a repetition
  /// actually committed — the caller advances the anchor on that and on
  /// nothing else.
  Future<bool> _dispatchOne() async {
    if (_dispatchInFlight) return false;
    if (_sessions.busy || _session.isBusy) {
      _retryLater(_reconcile);
      return false;
    }
    _dispatchInFlight = true;
    final CraftReport? report = await _sessions.craftQueued(_recipe!);
    _dispatchInFlight = false;
    if (!_running || _stopRequested) return false;
    if (report == null) {
      _retryLater(_reconcile);
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

  /// Stop's settle (`DECISIONS/0022` §7): every repetition that had **fully
  /// elapsed** at the moment of the stop still commits; the partial one is
  /// discarded with the remainder.
  Future<void> _settleStop() async {
    int due = _dueCount();
    while (due > 0 && _running) {
      if (_dispatchInFlight || _sessions.busy || _session.isBusy) break;
      _dispatchInFlight = true;
      final CraftReport? report = await _sessions.craftQueued(_recipe!);
      _dispatchInFlight = false;
      if (report == null || !report.succeeded) {
        if (report != null) _stopReport = report;
        break;
      }
      _anchor += _durationMillis;
      _completed += 1;
      _lastReport = report;
      _outputName = report.outputName ?? _outputName;
      _quantity += report.quantity ?? 0;
      _xp += report.experience ?? 0;
      _skillName = report.skillName ?? _skillName;
      due -= 1;
    }
    _finish();
  }

  void _retryLater(void Function() action) {
    _cancelTimer();
    _timer = _timing.startTimer(_busyRetry, () {
      _timer = null;
      action();
    });
  }

  /// Whether the finished summary is a MEDIUM beat — equipment, or a level
  /// gained — and therefore held for acknowledgement rather than timed out
  /// (PLAYABLE_EXPERIENCE_REFINEMENT_01 §12, §13, §32).
  bool get summaryHeld {
    final CraftReport? last = _lastReport;
    return last != null && (last.levelledUp || last.equipDelta != null);
  }

  /// Dismisses a held summary. Idempotent; a no-op while a queue runs.
  void dismissSummary() {
    if (_running || _recipe == null) return;
    _clearSummary();
    notifyListeners();
  }

  void _finish() {
    _running = false;
    _stopRequested = false;
    if (_completed > 0 && summaryHeld) {
      _summaryTimer?.cancel();
      _summaryTimer = null;
    } else if (_completed > 0 || _stopReport != null) {
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
