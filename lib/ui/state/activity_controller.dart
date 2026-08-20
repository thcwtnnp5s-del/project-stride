/// The foreground gathering queue: timed, queueable, and ephemeral.
///
/// ## What this is, and deliberately is not
///
/// Each completed repetition dispatches the **existing** gather command through
/// [SessionController.gather] — one atomic spend + grant + XP + persist,
/// exactly-once by the construction already proven on hardware
/// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4a). Everything here is
/// presentation state on top of that command:
///
/// - **No core change, no save-schema change, no persistence.** The queue is
///   ephemeral foreground state, like `SessionController.busy`. A relaunch has
///   no queue; completed repetitions are already durable.
/// - **Cancel aborts the in-progress repetition with nothing spent and nothing
///   granted** — the command was never dispatched. Completed repetitions stay.
/// - **Nothing completes in the background.** The presentation timer pauses on
///   any non-resumed lifecycle state; elapsed background time is never counted
///   (`RULES.md` P-4 — time passing is never a substitute for movement, and a
///   queue that ran while the phone was pocketed would be exactly that).
/// - If the engine refuses a dispatch, the queue stops and keeps the refusing
///   [ActionReport] so the card can show the truthful reason.
///
/// ## Timing is injectable, and single-shot only
///
/// [ActivityTiming] carries the two seams — a one-shot timer factory and a
/// clock — so tests advance deterministically with no real waits. Production
/// uses real one-shot `Timer`s that re-arm per repetition; `Timer.periodic` is
/// forbidden in `lib/` by `s01a_vertical_slice_test.dart` and nothing here
/// needs it.
///
/// The visible progress bar is NOT driven by this controller notifying per
/// frame: it notifies on segment boundaries (start, completion, pause, resume,
/// stop), and a widget-side ticker renders the smooth fill from
/// [elapsedOfCurrent] / [repetitionDuration] (§4a: domain completion and UI
/// progress are separate clocks).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition;

import '../../runtime/stride_session.dart' show ActionReport;
import 'session_controller.dart';

/// Starts a single-shot timer. Production is `Timer(duration, onFire)`; tests
/// substitute a fake that fires on a manually advanced clock.
typedef ActivityTimerFactory =
    Timer Function(Duration duration, void Function() onFire);

/// The controller's two timing seams, injectable together so a test cannot
/// fake one and forget the other.
///
/// [now] is a **monotonic elapsed reading, never a wall clock**. A Stopwatch
/// cannot jump with a timezone or a manual clock change, so a repetition's
/// remainder can never be inflated by one — and `lib/ui` deriving anything
/// from `DateTime.now` is exactly what the UI-boundary guard forbids
/// (Q-UI-9). Only differences of two readings are ever used.
final class ActivityTiming {
  const ActivityTiming({required this.startTimer, required this.now});

  factory ActivityTiming.real() {
    final Stopwatch watch = Stopwatch()..start();
    return ActivityTiming(startTimer: _realTimer, now: () => watch.elapsed);
  }

  final ActivityTimerFactory startTimer;
  final Duration Function() now;

  static Timer _realTimer(Duration duration, void Function() onFire) =>
      Timer(duration, onFire);
}

/// How long one repetition's animated work takes, per profession.
///
/// **Authored presentation pacing, not domain content** — the same precedent as
/// `CombatRules`' provisional constants. Nothing in the engine reads these; a
/// repetition's *cost* is the engine's, and only its on-screen duration is
/// authored here. It moves to content the day design wants per-node durations
/// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4b).
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
/// than dropping or double-dispatching, keeps exactly-once true without a
/// second queue.
const Duration _busyRetry = Duration(milliseconds: 250);

class ActivityController extends ChangeNotifier with WidgetsBindingObserver {
  ActivityController(this._sessions, {ActivityTiming? timing})
    : _timing = timing ?? ActivityTiming.real() {
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
  }

  /// The most repetitions one queue may hold. A hard cap on the *request*,
  /// not an affordability claim — the card additionally clamps to what banked
  /// steps afford, and the engine re-validates every dispatch regardless.
  static const int maxQueue = 20;

  final SessionController _sessions;
  final ActivityTiming _timing;

  ResourceNodeDefinition? _node;
  int _queued = 0;
  int _completed = 0;
  bool _running = false;
  Duration _repetitionDuration = ActivityDurations.fallback;

  /// Foreground time already spent on the current repetition before the
  /// running segment — banked by a lifecycle pause, so a resume arms a timer
  /// for exactly the remainder.
  Duration _banked = Duration.zero;

  /// The monotonic reading at which the running segment started, or null
  /// while nothing is timing (paused, or waiting on a dispatch).
  Duration? _segmentStart;

  /// The pending one-shot timer: a repetition's remainder, a busy retry, or
  /// the summary's lifetime. One at a time, by construction.
  Timer? _timer;
  Timer? _summaryTimer;

  /// True from the moment a repetition's presentation completes until its
  /// dispatch has been accepted — the window a pause/resume must re-enter at
  /// the dispatch, not at the timer.
  bool _awaitingDispatch = false;

  /// True across the dispatch's await. A stop that arrives inside it is
  /// deferred ([_stopRequested]): the command is already with the engine, so
  /// the honest outcome is to count what committed and then stop.
  bool _dispatchInFlight = false;
  bool _stopRequested = false;

  // Cumulative gains this queue, accumulated from the returned ActionReports —
  // never recomputed from content, which carries unscaled base values.
  String? _gainItemName;
  int _gainQuantity = 0;
  String? _gainSkillName;
  int _gainXp = 0;

  /// The report that stopped the queue, when a refusal did. Null after a
  /// player stop or a clean finish.
  ActionReport? _stopReport;

  /// The last lifecycle state the binding reported. Null — never reported, the
  /// widget-test harness and a fresh launch — is treated as foreground, the
  /// same seam `AmbientPlayer` documents.
  AppLifecycleState? _lifecycle;

  bool get _halted =>
      _lifecycle != null && _lifecycle != AppLifecycleState.resumed;

  // -- What the UI reads ------------------------------------------------------

  /// True while a queue is running (including paused-by-lifecycle).
  bool get active => _running;

  /// The node the running queue works, or null when none runs.
  ContentId? get activeNode => _running ? _node?.id : null;

  /// The node the retained finished-queue summary is about, or null. Mutually
  /// exclusive with [activeNode] by construction.
  ContentId? get summaryNode => _running ? null : _node?.id;

  /// The running or summarised queue's skill, for hue and duration display.
  ContentId? get skill => _node?.skill;

  int get queued => _queued;
  int get completed => _completed;

  /// True while the app is not resumed and a queue is held mid-repetition.
  bool get paused => _running && _halted;

  Duration get repetitionDuration => _repetitionDuration;

  /// Foreground time spent on the current repetition, capped at the duration.
  /// A widget-side ticker renders the smooth bar from this; the controller
  /// never notifies per frame.
  Duration get elapsedOfCurrent {
    Duration elapsed = _banked;
    final Duration? start = _segmentStart;
    if (start != null) elapsed += _timing.now() - start;
    return elapsed > _repetitionDuration ? _repetitionDuration : elapsed;
  }

  String? get gainedItemName => _gainItemName;
  int get gainedQuantity => _gainQuantity;
  String? get gainedSkillName => _gainSkillName;
  int get gainedXp => _gainXp;

  /// The refusing report, for the card to render with the same wording a
  /// single gather's refusal gets.
  ActionReport? get stopReport => _stopReport;

  /// The refusal's stable wire code, for tests and logs.
  String? get stopReason => _stopReport?.rejection;

  // -- Commands ---------------------------------------------------------------

  /// Begins a queue of [repetitions] at [node]. Ignored while one is running —
  /// the card offers Stop instead, and a double tap must not restart the
  /// repetition it raced.
  void start(ResourceNodeDefinition node, int repetitions) {
    if (_running) return;
    _clearSummary();
    _node = node;
    _queued = repetitions.clamp(1, maxQueue);
    _completed = 0;
    _running = true;
    _repetitionDuration = ActivityDurations.of(node.skill);
    _beginRepetition();
    notifyListeners();
  }

  /// Stops the queue. The in-progress repetition is abandoned with nothing
  /// spent and nothing granted — its command was never dispatched; completed
  /// repetitions are already durable and stay.
  void stop() {
    if (!_running) return;
    if (_dispatchInFlight) {
      // The command is already with the engine; let it land and count, then
      // stop. Aborting the await would not un-dispatch it.
      _stopRequested = true;
      return;
    }
    _cancelTimer();
    _finish(report: null);
  }

  /// The exclusive-command seam: travel or combat is about to execute, and a
  /// running queue must not still be gathering somewhere the player is
  /// leaving. Same semantics as [stop] — the engine would refuse the next
  /// dispatch anyway (`resource_node_not_here` / `encounter_in_progress`);
  /// this is defence in depth, and it keeps the card truthful immediately.
  void cancelForExclusiveCommand() => stop();

  // -- Lifecycle --------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    final bool wasHalted = _halted;
    _lifecycle = state;
    if (!_running || _halted == wasHalted) return;

    if (_halted) {
      // Pause: cancel the pending timer and bank the elapsed foreground time.
      // `inactive`, `paused` and `hidden` all pause — one background is one
      // pause however many states the platform walks through.
      _cancelTimer();
      final Duration? start = _segmentStart;
      if (start != null) {
        _banked += _timing.now() - start;
        if (_banked > _repetitionDuration) _banked = _repetitionDuration;
        _segmentStart = null;
      }
      notifyListeners();
      return;
    }

    // Resumed: continue exactly where it paused — the remainder of the
    // repetition, or the dispatch the completion was waiting to make.
    if (_awaitingDispatch) {
      _dispatch();
    } else {
      _arm();
    }
    notifyListeners();
  }

  // -- The machine ------------------------------------------------------------

  void _beginRepetition() {
    _banked = Duration.zero;
    _awaitingDispatch = false;
    _arm();
  }

  /// Arms the one-shot timer for the current repetition's remainder. Skipped
  /// while halted; the resume re-arms.
  void _arm() {
    if (_halted) return;
    final Duration remaining = _repetitionDuration - _banked;
    _segmentStart = _timing.now();
    _timer = _timing.startTimer(
      remaining.isNegative ? Duration.zero : remaining,
      _onPresentationDone,
    );
  }

  void _onPresentationDone() {
    _timer = null;
    // The repetition's visible work is done; cap the elapsed figure so the
    // bar reads full while the dispatch runs.
    _banked = _repetitionDuration;
    _segmentStart = null;
    _awaitingDispatch = true;
    _dispatch();
  }

  /// Dispatches exactly one gather for the completed repetition, through the
  /// session controller so busy/lastAction behaviour stays consistent
  /// app-wide. The report is read back for the cumulative gains.
  Future<void> _dispatch() async {
    if (!_running || _dispatchInFlight || _halted) return;
    // Busy — a manual sync in flight, or another command mid-commit. Wait and
    // retry rather than dropping the completed repetition or dispatching a
    // second time. The check and the call below have no await between them,
    // so the guard cannot be raced by this controller's own dispatch.
    if (_sessions.busy || _sessions.session.isBusy) {
      _retryLater();
      return;
    }
    final ResourceNodeDefinition node = _node!;
    _dispatchInFlight = true;
    await _sessions.gather(node.id);
    _dispatchInFlight = false;
    if (!_running) return;

    final ActionReport? report = _sessions.lastAction;
    if (report != null && !report.succeeded) {
      if (report.rejection == 'session_busy') {
        // The session-level single-flight refused it — same fact as the busy
        // check above, seen a moment later. Retry; nothing was spent.
        _retryLater();
        return;
      }
      // A real refusal — insufficient steps, wrong place, stale session.
      // The queue stops safely with the truthful reason; this repetition did
      // not complete and is not counted.
      _cancelTimer();
      _finish(report: report);
      return;
    }

    _awaitingDispatch = false;
    if (report != null) _accumulate(report);
    _completed += 1;

    if (_stopRequested || _completed >= _queued) {
      _finish(report: null);
      return;
    }
    _beginRepetition();
    notifyListeners();
  }

  void _retryLater() {
    _timer?.cancel();
    _timer = _timing.startTimer(_busyRetry, () {
      _timer = null;
      _dispatch();
    });
  }

  void _accumulate(ActionReport report) {
    _gainItemName = report.itemName ?? _gainItemName;
    _gainQuantity += report.quantity ?? 0;
    _gainSkillName = report.skillName ?? _gainSkillName;
    _gainXp += report.experience ?? 0;
  }

  /// Ends the queue. What was gained (and the refusal, if one stopped it)
  /// stays readable as the summary for [_summaryLifetime], then clears.
  void _finish({required ActionReport? report}) {
    _running = false;
    _awaitingDispatch = false;
    _stopRequested = false;
    _segmentStart = null;
    _banked = Duration.zero;
    _stopReport = report;

    if (_completed > 0 || report != null) {
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
    _queued = 0;
    _completed = 0;
    _gainItemName = null;
    _gainQuantity = 0;
    _gainSkillName = null;
    _gainXp = 0;
    _stopReport = null;
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
