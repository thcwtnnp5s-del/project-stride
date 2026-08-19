/// The idle cadence: what the stage does once a visit's scenes are spent.
///
/// The device "freeze" the owner reported was `AmbientPlayer` reaching its
/// terminal phase after four scenes and holding the rest frame until the app
/// resumed or a gather ended (`MILESTONES/WORLD_REWARD_DEPTH_01.md` §3, §9).
/// These tests hold the fix to its contract from both sides:
///
/// - **resumed** — the app in front of the player — never ends on a held
///   frame; and
/// - **no lifecycle state**, which is the widget-test harness and every
///   `pumpAndSettle` in this repository, still settles on the rest frame.
///
/// That asymmetry is the whole test seam, and it is stated once in
/// `ambient_player.dart`'s library doc. It is the same rule
/// `AtlasViewport._animate` ships with, and `atlas_screen_test` exercises it
/// the same way: send `resumed`, and reset it in a tear-down.
///
/// ## Reading the timings
///
/// A phase that starts inside a frame callback does not get its ticker's start
/// time until the *next* frame, so a single `pump(phaseLength)` always lands
/// short. Rather than hand-count epsilons, everything below advances in small
/// steps and asserts on the **shape** of the cadence — the order
/// of the pools, and rest lengths in step counts. Each phase then loses at
/// most one step, which every assertion allows for.
///
/// Every scene here is built from stand-in frames; the assets are never
/// decoded, because these are timing and priority tests, not pixel tests.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_player.dart';
import 'package:stride/ui/components/ambient_scene.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';

const List<String> _gather = <String>[
  'assets/art/v1/anim/gather_f0.png',
  'assets/art/v1/anim/gather_f1.png',
  'assets/art/v1/anim/gather_f2.png',
  'assets/art/v1/anim/gather_f3.png',
];

/// Every stand-in scene is 4 frames at 10 fps, played once: 400 ms.
const Duration _visitRest = Duration(milliseconds: 500);

const Duration _step = Duration(milliseconds: 25);

/// Fixed bounds, so an idle rest is a number rather than a range. The draws
/// inside the bounds are exercised on the shipped cadence, further down.
const AmbientCadence _fixed = AmbientCadence(
  microRestShortest: Duration(milliseconds: 300),
  microRestLongest: Duration(milliseconds: 300),
  sceneRestShortest: Duration(milliseconds: 900),
  sceneRestLongest: Duration(milliseconds: 900),
  fullSceneEvery: 3,
);

AmbientScene _scene(
  String id, {
  double weight = 1,
  double idleWeight = 0,
  bool idleOnly = false,
}) => AmbientScene(
  id: id,
  traveler: AmbientTrack(frames: _gather, fps: 10, loop: AmbientLoop.once),
  footprint: SpriteFootprints.gather,
  weight: weight,
  idleWeight: idleWeight,
  idleOnly: idleOnly,
);

/// Three full scenes and two idle-only ones, so which pool a beat drew from is
/// readable straight off the recorded id.
final AmbientSceneSet _set = AmbientSceneSet(<AmbientScene>[
  _scene('a'),
  _scene('b'),
  _scene('c', weight: 2),
  _scene('breathe', idleWeight: 1, idleOnly: true),
  _scene('look', idleWeight: 1, idleOnly: true),
]);

const Set<String> _micro = <String>{'breathe', 'look'};
const Set<String> _full = <String>{'a', 'b', 'c'};

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

/// Records what the player says it is showing, and when.
final class _Log {
  final List<String?> events = <String?>[];

  /// Steps elapsed when each event arrived.
  final List<int> at = <int>[];
  int _now = 0;

  void tick() => _now += 1;
  void add(String? id) {
    events.add(id);
    at.add(_now);
  }

  List<String> get ids => events.whereType<String>().toList();
  String? get last => events.isEmpty ? null : events.last;
}

Future<void> _advanceLogged(WidgetTester tester, _Log log, int steps) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(_step);
    log.tick();
  }
}

void main() {
  group('the pools come from the table', () {
    test('a visit never draws an idle-only scene, and both pools are real', () {
      expect(_set.visitScenes.scenes.map((AmbientScene s) => s.id), <String>[
        'a',
        'b',
        'c',
      ]);
      expect(_set.microIdles.scenes.map((AmbientScene s) => s.id), <String>[
        'breathe',
        'look',
      ]);
      expect(
        _set.microIdles.scenes.every((AmbientScene s) => s.weight == 1),
        isTrue,
        reason: 'the pool is weighted by idleWeight, not the visit weight',
      );
    });

    test('a table with no idle weights has an empty pool', () {
      final AmbientSceneSet plain = AmbientSceneSet(<AmbientScene>[
        _scene('a'),
      ]);
      expect(plain.microIdles.isEmpty, isTrue);
      expect(plain.visitScenes.scenes, hasLength(1));
    });

    test('withWeight carries every measured number across', () {
      final AmbientScene s = AmbientAssets.scenes.scenes.firstWhere(
        (AmbientScene s) => s.id == 'wipe_brow',
      );
      final AmbientScene idle = s.withWeight(s.idleWeight);
      expect(idle.weight, s.idleWeight);
      expect(idle.bounds.toString(), s.bounds.toString());
      expect(idle.footprint, s.footprint);
      expect(idle.canvas, s.canvas);
      expect(idle.canvasHeight, s.canvasHeight);
      expect(idle.anchorX, s.anchorX);
      expect(idle.companionAllowance, s.companionAllowance);
      expect(idle.duration, s.duration);
    });

    test(
      'the shipped table declares a micro-idle pool from its own scenes',
      () {
        final List<String> ids = AmbientAssets.scenes.microIdles.scenes
            .map((AmbientScene s) => s.id)
            .toList();
        expect(ids, isNotEmpty, reason: 'the device would idle on full scenes');
        final Set<String> table = AmbientAssets.scenes.scenes
            .map((AmbientScene s) => s.id)
            .toSet();
        for (final String id in ids) {
          expect(
            table.contains(id),
            isTrue,
            reason: '$id is not in the measured table, so nothing composes it',
          );
        }
        for (final AmbientScene s in AmbientAssets.scenes.microIdles.scenes) {
          expect(
            s.duration,
            lessThanOrEqualTo(const Duration(seconds: 4)),
            reason: '${s.id}: a micro-idle recurs, so it has to be short',
          );
        }
      },
    );
  });

  /// Mounts a player that is already in the foreground, as the app is at
  /// launch: the lifecycle state exists before the widget does.
  Future<_Log> mount(
    WidgetTester tester, {
    AmbientCadence? cadence = _fixed,
    int scenesPerVisit = 2,
    int seed = 7,
    bool resumed = true,
  }) async {
    final _Log log = _Log();
    if (resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.binding.resetInternalState);
    }
    await tester.pumpWidget(
      _host(
        AmbientPlayer(
          scenes: _set,
          restFrame: _gather.first,
          restFootprint: SpriteFootprints.gather,
          restBetween: _visitRest,
          scenesPerVisit: scenesPerVisit,
          cadence: cadence,
          seed: seed,
          onSceneChanged: (AmbientScene? s) => log.add(s?.id),
        ),
      ),
    );
    return log;
  }

  group('idle cadence, app resumed', () {
    testWidgets('the visit runs out into micro-idles and periodic scenes', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester);
      // Nine seconds: the two-scene visit, then two full idle cycles.
      await _advanceLogged(tester, log, 360);

      final List<String> ids = log.ids;
      expect(
        ids.length,
        greaterThanOrEqualTo(8),
        reason: 'the visit plus six idle beats',
      );
      // The visit.
      expect(ids[0], isIn(_full));
      expect(ids[1], isIn(_full));
      // Then the cadence: micro, micro, full — twice over.
      expect(ids[2], isIn(_micro), reason: 'the first idle beat');
      expect(ids[3], isIn(_micro));
      expect(ids[4], isIn(_full), reason: 'every third beat is a full scene');
      expect(ids[5], isIn(_micro));
      expect(ids[6], isIn(_micro));
      expect(ids[7], isIn(_full));
      for (int i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]), reason: 'position $i');
      }
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the cadence is still running — this is the freeze regression',
      );
    });

    testWidgets('the rest before a full scene is the longer one', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester);
      await _advanceLogged(tester, log, 360);

      // Rest length in steps: the gap between the null that ends a beat and
      // the id that begins the next. 300 ms is 12 steps, 900 ms is 36.
      final List<int> beforeMicro = <int>[];
      final List<int> beforeFull = <int>[];
      for (int i = 1; i < log.events.length; i++) {
        final String? id = log.events[i];
        if (id == null || log.events[i - 1] != null) continue;
        final int rest = log.at[i] - log.at[i - 1];
        (_micro.contains(id) ? beforeMicro : beforeFull).add(rest);
      }
      // The first entry of `beforeFull` is a visit rest (500 ms), not an idle
      // one; drop it and the visit's other rests by only reading the tail.
      expect(beforeMicro, isNotEmpty);
      for (final int r in beforeMicro) {
        expect(r, inInclusiveRange(12, 14), reason: '300 ms in 25 ms steps');
      }
      expect(beforeFull.length, greaterThanOrEqualTo(3));
      for (final int r in beforeFull.skip(1)) {
        expect(r, inInclusiveRange(36, 38), reason: '900 ms in 25 ms steps');
      }
    });

    testWidgets('it keeps going for cycles, and never holds a frame', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester);
      for (int i = 0; i < 480; i++) {
        await tester.pump(_step);
        log.tick();
        expect(
          tester.binding.hasScheduledFrame,
          isTrue,
          reason: 'nothing scheduled at step $i: the stage has frozen',
        );
      }
      final List<String> idle = log.ids.skip(2).toList();
      expect(idle.length, greaterThan(6));
      expect(
        idle.where(_micro.contains).length,
        greaterThan(idle.where(_full.contains).length),
        reason: 'idling is mostly micro-idles',
      );
    });

    testWidgets('the shipped cadence varies its rests inside the bounds', (
      WidgetTester tester,
    ) async {
      // 2–4 s before a micro-idle: 80–160 steps of 25 ms.
      final _Log log = await mount(tester, cadence: const AmbientCadence());
      await _advanceLogged(tester, log, 2400);

      final List<int> rests = <int>[];
      for (int i = 1; i < log.events.length; i++) {
        final String? id = log.events[i];
        if (id == null || !_micro.contains(id)) continue;
        if (log.events[i - 1] != null) continue;
        rests.add(log.at[i] - log.at[i - 1]);
      }
      expect(rests.length, greaterThanOrEqualTo(4));
      for (final int r in rests) {
        expect(r, inInclusiveRange(80, 162), reason: '2–4 s, plus a step');
      }
      expect(
        rests.toSet().length,
        greaterThan(1),
        reason: 'every idle rest the same length is not a varied cadence',
      );
    });

    testWidgets('cadence: null is the visit and then the rest frame', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester, cadence: null);
      await tester.pumpAndSettle();
      expect(log.ids, hasLength(2));
      expect(log.last, isNull);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'an explicit opt-out still finishes',
      );
    });
  });

  group('the suite seam', () {
    testWidgets('with no lifecycle state the visit settles on the rest frame', (
      WidgetTester tester,
    ) async {
      // No `handleAppLifecycleStateChanged`: exactly how every screen test in
      // this repository mounts the stage.
      final _Log log = await mount(tester, resumed: false, scenesPerVisit: 3);
      await tester.pumpAndSettle();
      expect(log.ids, hasLength(3));
      expect(log.ids.every(_full.contains), isTrue, reason: 'no idle-only');
      expect(log.last, isNull, reason: 'ends standing');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a resume turns the endless cadence on mid-life', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester, resumed: false, scenesPerVisit: 1);
      await tester.pumpAndSettle();
      expect(log.ids, hasLength(1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.binding.resetInternalState);
      await tester.pump();
      await _advanceLogged(tester, log, 200);
      expect(log.ids.length, greaterThan(3));
      expect(log.ids.skip(2).any(_micro.contains), isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('reduced motion is the standing figure and nothing else', (
      WidgetTester tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.binding.resetInternalState);
      final _Log log = _Log();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: AmbientPlayer(
                scenes: _set,
                restFrame: _gather.first,
                restFootprint: SpriteFootprints.gather,
                restBetween: _visitRest,
                seed: 2,
                onSceneChanged: (AmbientScene? s) => log.add(s?.id),
              ),
            ),
          ),
        ),
      );
      await _advanceLogged(tester, log, 400);
      expect(log.events, isEmpty, reason: 'no scene ever started');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('lifecycle', () {
    /// Runs until the player is showing a micro-idle, or gives up.
    Future<void> intoAMicroIdle(WidgetTester tester, _Log log) async {
      for (int i = 0; i < 400; i++) {
        if (log.last != null && _micro.contains(log.last)) return;
        await tester.pump(_step);
        log.tick();
      }
      fail('the cadence never reached a micro-idle');
    }

    testWidgets('paused mid-idle stops everything; resumed carries on', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester, scenesPerVisit: 1, seed: 11);
      await intoAMicroIdle(tester, log);
      final String? beat = log.last;
      final int played = log.ids.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'the cadence does not run in the background',
      );
      expect(log.last, beat, reason: 'still on the same idle beat');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log.last, beat, reason: 'continues the beat, not a fresh visit');
      await _advanceLogged(tester, log, 60);
      expect(
        log.ids.length,
        greaterThan(played),
        reason: 'the cadence carried on after the resume',
      );
      expect(
        log.ids[played],
        isIn(_micro),
        reason: 'it resumed the idle cadence, not the opening visit',
      );
    });

    testWidgets('inactive without paused stops it, and resumed picks it up', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester, scenesPerVisit: 1, seed: 11);
      await intoAMicroIdle(tester, log);
      final String? beat = log.last;
      final int played = log.ids.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(log.last, beat);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _advanceLogged(tester, log, 60);
      expect(log.ids.length, greaterThan(played));
      expect(log.ids[played], isIn(_micro));
    });

    testWidgets('a run of background states is still one background', (
      WidgetTester tester,
    ) async {
      final _Log log = await mount(tester, scenesPerVisit: 1, seed: 11);
      await intoAMicroIdle(tester, log);
      final String? beat = log.last;
      final int played = log.ids.length;

      for (final AppLifecycleState s in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(log.last, beat);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await _advanceLogged(tester, log, 60);
      expect(
        log.ids.length,
        greaterThan(played),
        reason: 'hidden and paused did not lose the held flag',
      );
    });
  });

  group('the gather still has priority', () {
    testWidgets('suspended mid-idle rests; released starts a fresh visit', (
      WidgetTester tester,
    ) async {
      final _Log log = _Log();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.binding.resetInternalState);

      Widget player({required bool suspended}) => _host(
        AmbientPlayer(
          scenes: _set,
          restFrame: _gather.first,
          restFootprint: SpriteFootprints.gather,
          restBetween: _visitRest,
          scenesPerVisit: 1,
          cadence: _fixed,
          suspended: suspended,
          seed: 13,
          onSceneChanged: (AmbientScene? s) => log.add(s?.id),
        ),
      );

      await tester.pumpWidget(player(suspended: false));
      for (int i = 0; i < 400; i++) {
        if (log.last != null && _micro.contains(log.last)) break;
        await tester.pump(_step);
        log.tick();
      }
      expect(log.last, isIn(_micro), reason: 'idling before the gather');

      await tester.pumpWidget(player(suspended: true));
      await tester.pump();
      expect(log.last, isNull, reason: 'the rest frame while a gather plays');
      await tester.pump(const Duration(seconds: 10));
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'suspended stops the cadence dead',
      );

      await tester.pumpWidget(player(suspended: false));
      await tester.pump();
      final int mark = log.ids.length;
      await _advanceLogged(tester, log, 30);
      expect(
        log.ids.skip(mark).single,
        isIn(_full),
        reason: 'released into a fresh visit, not back into the idle beat',
      );
      await _advanceLogged(tester, log, 60);
      expect(log.ids.last, isIn(_micro), reason: 'and on into the cadence');
    });
  });
}
