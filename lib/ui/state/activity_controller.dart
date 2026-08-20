/// The gathering queue's presentation, over the **durable** activity queue.
///
/// ## What this is, and deliberately is not
///
/// The queue itself lives in the save (`GameState.activityQueue`, state v6)
/// and advances by elapsed wall-clock time whether or not the app is running —
/// the owner-ruled exception to `RULES.md` P-4 (`DECISIONS/0022`). Everything
/// here is presentation over that durable fact:
///
/// - **Start** dispatches `StartActivityQueue` — one commit, nothing spent.
/// - **Progress** derives from the committed anchor plus the wall clock, so
///   what the bar shows and what reconciliation computes cannot disagree.
///   Backgrounding no longer pauses anything: the earlier monotonic
///   Stopwatch pause/bank machinery is gone **by owner ruling** — a player
///   who queued Oak Stand ×10 does not keep the phone awake to collect it.
/// - **Completions** are committed by `ReconcileActivityQueue`, dispatched at
///   each repetition boundary in the foreground (a one-shot timer — never
///   `Timer.periodic`), on every resume, and once at construction so an
///   evicted app's queue resolves on the next launch. Exactly-once is the
///   engine's commit arithmetic, not this controller's timers: a duplicate
///   reconcile finds nothing left to complete and commits nothing.
/// - **Stop** dispatches `StopActivityQueue`: fully-elapsed repetitions
///   commit, the partial one is discarded, the queue clears.
/// - If a completion cannot legally commit (steps, place, tool, skill), the
///   engine stops the queue with the truthful reason and this controller
///   renders it.
///
/// ## Timing is injectable, and wall-clock-based
///
/// [ActivityTiming] carries the two seams — a one-shot timer factory and the
/// wall clock — so tests advance deterministically with no real waits. The
/// production clock is `StrideSession.activityWallClock`, the activity
/// subsystem's **single** wall-clock seam (`DECISIONS/0022` §8): nothing in
/// `lib/ui` reads `DateTime.now`, and `Scripts/check-ui-boundary.sh` (rule 5,
/// Q-UI-9) still forbids it here unchanged.
///
/// The visible progress bar is NOT driven by this controller notifying per
/// frame: it notifies on queue changes (start, completions, stop, finish), and
/// a widget-side ticker renders the smooth fill from [elapsedOfCurrent] /
/// [repetitionDuration].
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition;

import '../../runtime/stride_session.dart'
    show
        ActionReport,
        ActivityCompletionLine,
        ActivityQueueReport,
        ActivityQueueView,
        StrideSession;
import 'session_controller.dart';

/// Starts a single-shot timer. Production is `Timer(duration, onFire)`; tests
/// substitute a fake that fires on a manually advanced clock.
typedef ActivityTimerFactory =
    Timer Function(Duration duration, void Function() onFire);

/// The controller's two timing seams, injectable together so a test cannot
/// fake one and forget the other.
///
/// [nowEpochMillis] is **the wall clock** — epoch milliseconds, the same
/// reading `StrideSession.activityWallClock` gives the engine's commands, so
/// the bar and the commit arithmetic read one clock (`DECISIONS/0022` §8).
/// This replaced the monotonic Stopwatch deliberately: the queue's whole
/// point is now to advance across background, lock, and relaunch, and only a
/// wall clock survives those. A backward jump is already harmless — the
/// engine clamps elapsed time at zero and never moves the anchor backward's
/// way, and this controller only clamps a bar.
final class ActivityTiming {
  const ActivityTiming({
    required this.startTimer,
    required this.nowEpochMillis,
  });

  /// The production pair: real one-shot timers over [wallClock] — which the
  /// caller takes from `StrideSession.activityWallClock`, keeping the one
  /// seam one.
  factory ActivityTiming.real({required int Function() wallClock}) =>
      ActivityTiming(startTimer: _realTimer, nowEpochMillis: wallClock);

  final ActivityTimerFactory startTimer;
  final int Function() nowEpochMillis;

  static Timer _realTimer(Duration duration, void Function() onFire) =>
      Timer(duration, onFire);
}

/// How long one repetition's animated work takes, per profession.
///
/// **Authored presentation pacing, not domain content** — the same precedent as
/// `CombatRules`' provisional constants. The figure is frozen onto the queue at
/// start (`StartActivityQueue.durationMillis`), so a retune here cannot re-time
/// a queue already running. It moves to content the day design wants per-node
/// durations (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4b).
abstract final class ActivityDurations {
  const ActivityDurations._();

  /// For a skill the table does not name — a future profession lands at a
  /// sane pace rather than at zero.
  static const Duration fallback = Duration(seconds: 12);

  /// Keyed by skill content id (`assets/content/v1/skills.json`).
  static const Map<String, Duration> _bySkill = <String, Duration>{
    'skill.woodcutting': Duration(seconds: 12),
    'skill.mining': Duration(seconds: 14),
    'skill.foraging': Duration(seconds: 10),
  };

  static Duration of(ContentId skill) => _bySkill[skill.value] ?? fallback;
}

/// How long the finished queue's summary (gains, or the refusal that stopped
/// it) stays on the card — the same lifetime `SessionController` gives a
/// result line, and for the same reason: a summary that persisted would be a
/// durable "recent gains" system, and no such system exists.
const Duration _summaryLifetime = Duration(seconds: 5);

/// How long to wait before re-trying a dispatch that found the session busy —
/// a manual sync in flight, usually. Retrying on the injectable timer, rather
/// than dropping or double-dispatching, keeps the queue moving without a
/// second queue. Exactly-once needs no help from this: a duplicate reconcile
/// commits nothing by the engine's own arithmetic.
const Duration _busyRetry = Duration(milliseconds: 250);

/// What a reconcile committed while the player was not watching, for the
/// card's one-line "while away" summary.
final class AwaySummary {
  const AwaySummary({
    required this.itemName,
    required this.quantity,
    required this.skillName,
    required this.experience,
    required this.finishedQueue,
  });

  final String? itemName;
  final int quantity;
  final String? skillName;
  final int experience;

  /// True when the whole queue finished while away — the card shows the
  /// compact completion summary and then the normal controls.
  final bool finishedQueue;
}

class ActivityController extends ChangeNotifier with WidgetsBindingObserver {
  ActivityController(this._sessions, {ActivityTiming? timing}) {
    _timing =
        timing ??
        ActivityTiming.real(
          // The one wall-clock seam, reached through the session
          // (`DECISIONS/0022` §8). Read lazily per call, never captured as
          // a value here.
          wallClock: () => _sessions.session.activityWallClock(),
        );
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    _restoreFromSave();
  }

  /// The most repetitions one queue may hold. A hard cap on the *request*,
  /// not an affordability claim — the card additionally clamps to what banked
  /// steps afford, and the engine re-validates every completion regardless.
  static const int maxQueue = 20;

  final SessionController _sessions;
  late final ActivityTiming _timing;

  StrideSession get _session => _sessions.session;

  ResourceNodeDefinition? _node;
  int _requested = 0;
  int _completed = 0;
  bool _running = false;

  /// True from the tap until the start's commit lands — the synchronous guard
  /// that makes a double tap one queue.
  bool _startPending = false;

  /// True while any queue dispatch's await is outstanding.
  bool _dispatchInFlight = false;

  /// True once a stop has been asked for; the next report finishes the queue
  /// whatever else it says.
  bool _stopRequested = false;

  int _durationMillis = ActivityDurations.fallback.inMilliseconds;

  /// The pending one-shot timer: the next repetition boundary, a busy retry,
  /// or a deferred dispatch. One at a time, by construction.
  Timer? _timer;
  Timer? _summaryTimer;

  // Cumulative gains this queue. Accumulated from the committed completions'
  // reported payloads; after a relaunch, reconstructed deterministically as
  // completed × the session's profile-scaled yield/xp — the same figures the
  // events carried, never the raw content values.
  String? _gainItemName;
  int _gainQuantity = 0;
  String? _gainSkillName;
  int _gainXp = 0;

  /// The refusal that stopped the queue, when one did, in the shape the card
  /// already renders. Null after a player stop or a clean finish.
  ActionReport? _stopReport;

  AwaySummary? _awaySummary;

  /// The last lifecycle state the binding reported. Null — never reported, the
  /// widget-test harness and a fresh launch — is treated as foreground, the
  /// same seam `AmbientPlayer` documents.
  AppLifecycleState? _lifecycle;

  bool get _halted =>
      _lifecycle != null && _lifecycle != AppLifecycleState.resumed;

  // -- What the UI reads ------------------------------------------------------

  /// True while a queue is running.
  bool get active => _running;

  /// The node the running queue works, or null when none runs.
  ContentId? get activeNode => _running ? _node?.id : null;

  /// The node the retained finished-queue summary is about, or null. Mutually
  /// exclusive with [activeNode] by construction.
  ContentId? get summaryNode => _running ? null : _node?.id;

  /// The running or summarised queue's skill, for hue and duration display.
  ContentId? get skill => _node?.skill;

  int get queued => _requested;
  int get completed => _completed;

  Duration get repetitionDuration => Duration(milliseconds: _durationMillis);

  /// Wall-clock time into the current repetition, clamped to the repetition —
  /// derived from the **committed anchor**, so the bar and the engine's
  /// arithmetic read the same fact. A widget-side ticker renders the smooth
  /// fill from this; the controller never notifies per frame.
  Duration get elapsedOfCurrent {
    if (!_running) return Duration.zero;
    final ActivityQueueView? queue = _session.activityQueue;
    if (queue == null) return Duration.zero;
    int elapsed = _timing.nowEpochMillis() - queue.anchorEpochMillis;
    if (elapsed < 0) elapsed = 0;
    if (elapsed > queue.durationMillis) elapsed = queue.durationMillis;
    return Duration(milliseconds: elapsed);
  }

  String? get gainedItemName => _gainItemName;
  int get gainedQuantity => _gainQuantity;
  String? get gainedSkillName => _gainSkillName;
  int get gainedXp => _gainXp;

  /// What committed while the player was away — surfaced once, compactly, in
  /// the card's active/summary panel; null when nothing did.
  AwaySummary? get awaySummary => _awaySummary;

  /// The refusing report, for the card to render with the same wording a
  /// single gather's refusal gets.
  ActionReport? get stopReport => _stopReport;

  /// The refusal's stable wire code, for tests and logs.
  String? get stopReason => _stopReport?.rejection;

  // -- Commands ---------------------------------------------------------------

  /// Begins a queue of [repetitions] at [node]. Ignored while one is running
  /// or starting — the card offers Stop instead, and a double tap must not
  /// start a second queue (the engine would refuse it anyway;
  /// `activity_queue_active` is defence in depth behind this guard).
  void start(ResourceNodeDefinition node, int repetitions) {
    if (_running || _startPending) return;
    _clearSummary();
    _node = node;
    _requested = repetitions.clamp(1, maxQueue);
    _completed = 0;
    _running = true;
    _startPending = true;
    _durationMillis = ActivityDurations.of(node.skill).inMilliseconds;
    _dispatchStart();
    notifyListeners();
  }

  /// Stops the queue: fully-elapsed repetitions commit, the partial one is
  /// discarded, the queue clears (`DECISIONS/0022` §7).
  void stop() {
    if (!_running || _stopRequested) return;
    _stopRequested = true;
    _cancelTimer();
    _dispatchStop();
  }

  /// The exclusive-command seam: travel or combat is about to execute, and a
  /// running queue must not still be gathering somewhere the player is
  /// leaving. The panel clears immediately; the `StopActivityQueue` dispatch
  /// is deferred one timer tick so it lands **after** the exclusive command
  /// rather than racing it for the session's single flight. Ordering is safe
  /// either way: whichever commits second sees the other's state, and a
  /// completion that became illegal is refused with the truthful reason —
  /// defence in depth, as ever.
  void cancelForExclusiveCommand() {
    if (!_running || _stopRequested) return;
    _stopRequested = true;
    // The panel clears now — the player chose the journey or the fight, and a
    // card still "gathering" somewhere they are leaving would be a lie for
    // however many frames the commit takes. The durable clear follows.
    _running = false;
    _cancelTimer();
    _timer = _timing.startTimer(Duration.zero, () {
      _timer = null;
      _dispatchStop();
    });
    notifyListeners();
  }

  /// Dispatches a reconcile now. Safe at any time; used by resume and
  /// relaunch, and available to tests.
  void reconcileNow() {
    if (!_running) return;
    _reconcile(watched: false);
  }

  // -- Lifecycle --------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    final bool wasHalted = _halted;
    _lifecycle = state;
    if (!_running || _halted == wasHalted) return;

    if (_halted) {
      // Background: cancel the foreground boundary timer and nothing else.
      // The queue keeps its anchor and keeps accruing wall-clock time — that
      // is the owner's ruling (`DECISIONS/0022`); the resume reconciles.
      _cancelTimer();
      notifyListeners();
      return;
    }

    // Resumed: everything that elapsed while away commits now, exactly once.
    _reconcile(watched: false);
    notifyListeners();
  }

  // -- The machine ------------------------------------------------------------

  /// Restores a relaunched queue: an evicted app's queue must resolve on the
  /// next launch (`DECISIONS/0022` §4 — correctness is durable state plus
  /// reconciliation, never the process staying alive).
  void _restoreFromSave() {
    final ActivityQueueView? queue = _session.activityQueue;
    if (queue == null) return;
    _node = _session.nodeDefinitionOf(queue.node);
    _requested = queue.requested;
    _completed = queue.completed;
    _durationMillis = queue.durationMillis;
    _running = true;

    // The cumulative display, reconstructed deterministically: completed ×
    // the profile-scaled per-completion figures — the exact values the
    // committed events carried, read through the session's projections
    // rather than raw content.
    final int? perYield = _session.yieldOf(queue.node);
    final int? perXp = _session.xpOf(queue.node);
    final ResourceNodeDefinition? node = _node;
    if (queue.completed > 0 && node != null) {
      _gainItemName = _session.displayNameOf(node.yieldsItem);
      _gainSkillName = _session.displayNameOf(node.skill);
      _gainQuantity = queue.completed * (perYield ?? 0);
      _gainXp = queue.completed * (perXp ?? 0);
    }

    // Reconcile on the next timer tick — deferred through the injectable
    // seam so construction stays synchronous and tests drive it.
    _timer = _timing.startTimer(Duration.zero, () {
      _timer = null;
      _reconcile(watched: false);
    });
  }

  Future<void> _dispatchStart() async {
    final ResourceNodeDefinition? node = _node;
    if (!_running || node == null || _dispatchInFlight) return;
    if (_sessions.busy || _session.isBusy) {
      _retryLater(_dispatchStart);
      return;
    }
    _dispatchInFlight = true;
    final ActivityQueueReport? report = await _sessions.startActivityQueue(
      node.id,
      _requested,
      repetitionDuration: Duration(milliseconds: _durationMillis),
    );
    _dispatchInFlight = false;
    _startPending = false;
    if (!_running) {
      // Stopped before the start landed; the stop dispatch settles the rest.
      return;
    }
    if (report == null || report.rejection == 'session_busy') {
      _startPending = true;
      _retryLater(_dispatchStart);
      return;
    }
    if (!report.succeeded) {
      _cancelTimer();
      _finish(rejection: report.rejection, detail: report.detail);
      return;
    }
    if (_stopRequested) return; // a stop raced the start; let it settle
    _armBoundary();
    notifyListeners();
  }

  /// Dispatches one reconcile and applies its report.
  ///
  /// [watched] is presentation truth only: a boundary-timer reconcile is one
  /// the player watched fill; a resume/relaunch reconcile that committed
  /// something becomes the "while away" summary. The commit arithmetic is
  /// identical either way.
  Future<void> _reconcile({required bool watched}) async {
    if (!_running || _dispatchInFlight || _stopRequested) return;
    if (_sessions.busy || _session.isBusy) {
      _retryLater(() => _reconcile(watched: watched));
      return;
    }
    _dispatchInFlight = true;
    final ActivityQueueReport? report = await _sessions
        .reconcileActivityQueue();
    _dispatchInFlight = false;
    if (!_running) return;
    if (_stopRequested) return; // the stop's own reconcile settles everything
    if (report == null || report.rejection == 'session_busy') {
      _retryLater(() => _reconcile(watched: watched));
      return;
    }
    if (!report.succeeded) {
      // session_not_ready or commit_refused: the queue cannot proceed here.
      _cancelTimer();
      _finish(rejection: report.rejection, detail: report.detail);
      return;
    }

    if (report.completions.isNotEmpty) {
      _accumulate(report.completions);
      _completed = report.completedAfter;
      if (!watched) {
        _awaySummary = _awayOf(report);
      } else {
        _awaySummary = null;
      }
    }

    if (report.stopReason != null) {
      _cancelTimer();
      _finish(rejection: report.stopReason);
      return;
    }
    if (!report.active) {
      _cancelTimer();
      _finish();
      return;
    }
    _armBoundary();
    notifyListeners();
  }

  Future<void> _dispatchStop() async {
    if (_dispatchInFlight) {
      _retryLater(_dispatchStop);
      return;
    }
    if (_sessions.busy || _session.isBusy) {
      _retryLater(_dispatchStop);
      return;
    }
    _dispatchInFlight = true;
    final ActivityQueueReport? report = await _sessions.stopActivityQueue();
    _dispatchInFlight = false;
    if (report == null || report.rejection == 'session_busy') {
      _retryLater(_dispatchStop);
      return;
    }
    if (report.succeeded && report.completions.isNotEmpty) {
      _accumulate(report.completions);
      _completed = report.completedAfter;
    }
    _finish(rejection: report.succeeded ? report.stopReason : report.rejection);
  }

  /// Arms the one-shot timer for the current repetition's boundary — never
  /// `Timer.periodic`; each completion re-arms for the next. Skipped while
  /// halted; the resume reconciles instead.
  void _armBoundary() {
    if (_halted || !_running) return;
    final ActivityQueueView? queue = _session.activityQueue;
    if (queue == null) return;
    final int remaining =
        queue.anchorEpochMillis +
        queue.durationMillis -
        _timing.nowEpochMillis();
    if (remaining <= 0) {
      // The boundary already passed — a slow commit, or wall-clock time that
      // moved on while a dispatch was in flight. Reconcile now rather than
      // arming a zero timer that merely restates the same fact one tick
      // later. Exactly-once is unthreatened either way: a duplicate
      // reconcile commits nothing.
      _cancelTimer();
      _reconcile(watched: true);
      return;
    }
    _cancelTimer();
    _timer = _timing.startTimer(Duration(milliseconds: remaining), () {
      _timer = null;
      _reconcile(watched: true);
    });
  }

  void _retryLater(void Function() action) {
    _timer?.cancel();
    _timer = _timing.startTimer(_busyRetry, () {
      _timer = null;
      action();
    });
  }

  void _accumulate(List<ActivityCompletionLine> completions) {
    for (final ActivityCompletionLine line in completions) {
      _gainItemName = line.itemName;
      _gainQuantity += line.quantity;
      _gainSkillName = line.skillName;
      _gainXp += line.experience;
    }
  }

  AwaySummary _awayOf(ActivityQueueReport report) {
    int quantity = 0;
    int xp = 0;
    String? itemName;
    String? skillName;
    for (final ActivityCompletionLine line in report.completions) {
      itemName = line.itemName;
      skillName = line.skillName;
      quantity += line.quantity;
      xp += line.experience;
    }
    return AwaySummary(
      itemName: itemName,
      quantity: quantity,
      skillName: skillName,
      experience: xp,
      finishedQueue: !report.active && report.stopReason == null,
    );
  }

  /// Ends the queue's presentation. What was gained (and the refusal, if one
  /// stopped it) stays readable as the summary for [_summaryLifetime], then
  /// clears.
  void _finish({String? rejection, String? detail}) {
    _running = false;
    _startPending = false;
    _stopRequested = false;
    _stopReport = rejection == null
        ? null
        : ActionReport(
            succeeded: false,
            nodeName: _node?.displayName ?? '—',
            cost: 0,
            rejection: rejection,
            detail: detail,
          );

    if (_completed > 0 || _stopReport != null || _awaySummary != null) {
      _summaryTimer?.cancel();
      _summaryTimer = _timing.startTimer(_summaryLifetime, () {
        _summaryTimer = null;
        _clearSummary();
        notifyListeners();
      });
    } else {
      // Stopped before anything completed: there is nothing to summarise.
      _clearSummary();
    }
    notifyListeners();
  }

  void _clearSummary() {
    _summaryTimer?.cancel();
    _summaryTimer = null;
    _node = null;
    _requested = 0;
    _completed = 0;
    _gainItemName = null;
    _gainQuantity = 0;
    _gainSkillName = null;
    _gainXp = 0;
    _stopReport = null;
    _awaySummary = null;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    // Timers outliving the notifier fire notifyListeners on a disposed
    // object — the same reasoning as `SessionController.dispose`.
    _cancelTimer();
    _summaryTimer?.cancel();
    _summaryTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Makes the [ActivityController] reachable from any screen, beside
/// [SessionScope] and for the same reasons — see `session_scope.dart` for why
/// `InheritedNotifier` and not a package.
class ActivityScope extends InheritedNotifier<ActivityController> {
  const ActivityScope({
    super.key,
    required ActivityController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, **subscribing** the caller to its notifications.
  static ActivityController of(BuildContext context) {
    final ActivityScope? scope = context
        .dependOnInheritedWidgetOfExactType<ActivityScope>();
    assert(scope != null, 'No ActivityScope above this widget.');
    return scope!.notifier!;
  }

  /// The controller **without** subscribing — for `onPressed` closures.
  static ActivityController read(BuildContext context) {
    final ActivityScope? scope = context
        .getInheritedWidgetOfExactType<ActivityScope>();
    assert(scope != null, 'No ActivityScope above this widget.');
    return scope!.notifier!;
  }
}
