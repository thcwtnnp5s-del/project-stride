/// A manually advanced clock and the one-shot timers armed against it — the
/// test double for `ActivityTiming`'s two seams.
///
/// [FakeTiming.advance] moves the clock and fires every due timer in due
/// order. A timer armed *by* a firing (the next repetition's) lands after the
/// advance's target and fires on a later advance — which is exactly the shape
/// of the real thing, one repetition per elapsed duration. No real time
/// passes; a "300 s in the background" case is exact rather than slept.
library;

import 'dart:async';

import 'package:stride/ui/state/activity_controller.dart';

final class FakeTiming {
  // A monotonic reading, like the production Stopwatch — see ActivityTiming.
  Duration _now = Duration.zero;
  final List<_FakeTimer> _pending = <_FakeTimer>[];

  late final ActivityTiming timing = ActivityTiming(
    startTimer: _start,
    now: () => _now,
  );

  Timer _start(Duration duration, void Function() onFire) {
    final _FakeTimer timer = _FakeTimer(_now + duration, onFire);
    _pending.add(timer);
    return timer;
  }

  void advance(Duration duration) {
    final Duration target = _now + duration;
    while (true) {
      _FakeTimer? next;
      for (final _FakeTimer t in _pending) {
        if (!t.isActive || t.due > target) continue;
        if (next == null || t.due < next.due) next = t;
      }
      if (next == null) break;
      _now = next.due;
      next.fire();
    }
    _now = target;
    _pending.removeWhere((_FakeTimer t) => !t.isActive);
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._onFire);

  final Duration due;
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
