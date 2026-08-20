/// A manually advanced wall clock and the one-shot timers armed against it —
/// the test double for `ActivityTiming`'s two seams, and for
/// `StrideSession.activityWallClock`, which must read the **same** clock so
/// the controller's bar and the engine's commit arithmetic agree in tests
/// exactly as they do in production (`DECISIONS/0022` §8).
///
/// [FakeTiming.advance] moves the clock and fires every due timer in due
/// order — the foreground: elapsed time during which one-shot timers fire.
/// [FakeTiming.elapseInBackground] moves the clock and fires **nothing** —
/// the pocket: a suspended process runs no timers, and only the wall clock
/// moves. [FakeTiming.rewind] moves the clock backwards, for the
/// backward-clock cases. No real time passes anywhere; a "five minutes in the
/// background" case is exact rather than slept.
library;

import 'dart:async';

import 'package:stride/ui/state/activity_controller.dart';

final class FakeTiming {
  /// An arbitrary epoch instant; only differences matter.
  static const int epochStart = 1750000000000;

  int _nowEpochMillis = epochStart;
  final List<_FakeTimer> _pending = <_FakeTimer>[];

  late final ActivityTiming timing = ActivityTiming(
    startTimer: _start,
    nowEpochMillis: () => _nowEpochMillis,
  );

  /// The reading `StrideSession.activityWallClock` should be assigned, so the
  /// session's commands carry this same fake clock.
  int wallClock() => _nowEpochMillis;

  int get nowEpochMillis => _nowEpochMillis;

  Timer _start(Duration duration, void Function() onFire) {
    final _FakeTimer timer = _FakeTimer(
      _nowEpochMillis + duration.inMilliseconds,
      onFire,
    );
    _pending.add(timer);
    return timer;
  }

  /// Foreground time: advances the clock, firing every due timer in due
  /// order. A timer armed *by* a firing (the next repetition's boundary)
  /// lands after the advance's target and fires on a later advance — exactly
  /// the shape of the real thing.
  void advance(Duration duration) {
    final int target = _nowEpochMillis + duration.inMilliseconds;
    while (true) {
      _FakeTimer? next;
      for (final _FakeTimer t in _pending) {
        if (!t.isActive || t.due > target) continue;
        if (next == null || t.due < next.due) next = t;
      }
      if (next == null) break;
      _nowEpochMillis = next.due;
      next.fire();
    }
    _nowEpochMillis = target;
    _pending.removeWhere((_FakeTimer t) => !t.isActive);
  }

  /// Background or killed-process time: the wall clock moves and **no timer
  /// fires** — a suspended process runs nothing, and correctness comes from
  /// reconciliation on resume/relaunch, never from the process staying alive
  /// (`DECISIONS/0022` §4).
  void elapseInBackground(Duration duration) {
    _nowEpochMillis += duration.inMilliseconds;
  }

  /// A clock that ran backwards. Fires nothing and un-dues nothing: a real
  /// armed timer would still fire on its original schedule, and the engine's
  /// arithmetic is what must absorb the jump.
  void rewind(Duration duration) {
    _nowEpochMillis -= duration.inMilliseconds;
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._onFire);

  /// Epoch milliseconds at which this timer is due.
  final int due;
  final void Function() _onFire;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _onFire();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
