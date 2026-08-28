/// The scene dwell (GAME_FEEL_CHARACTER_PRESENTATION_01, item 3): a full
/// scene with phasing settles in — intro once, the loopable middle held for
/// a drawn dwell with its companion layers sustained, outro once — and the
/// harness seam keeps every unphased playback exactly as it was.
///
/// Same idiom as `ambient_cadence_test.dart`: stand-in frames never decoded,
/// small pumps, shape assertions with one-step slack, scaled-down fixed
/// bounds so a dwell is a number rather than a range.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_player.dart';
import 'package:stride/ui/components/ambient_scene.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';

List<String> _frames(String id, int count) => List<String>.generate(
  count,
  (int i) => 'assets/art/v1/ambient/${id}_f$i.png',
  growable: false,
);

const Duration _step = Duration(milliseconds: 25);

/// A 10-frame arc at 10 fps over **real packaged frames** (the harness
/// decodes what it draws): intro 0–2, loop 3–6 (ping-pong), outro 7–9.
/// Straight through it is exactly one second.
AmbientScene _arcScene(String id) => AmbientScene(
  id: id,
  traveler: AmbientTrack(
    frames: _frames('traveler_sit_ground', 10),
    fps: 10,
    loop: AmbientLoop.once,
  ),
  footprint: SpriteFootprints.ambientTravelerSitGround,
  phasing: const ScenePhasing(
    introEnd: 2,
    loopStart: 3,
    loopEnd: 6,
    outroStart: 7,
    outroEnd: 9,
  ),
  layers: <AmbientLayer>[
    // A short companion pass (400 ms) that must keep living through the
    // whole dwell instead of clamping on its last slot.
    AmbientLayer(
      track: AmbientTrack(frames: _frames('cat_lie_rest', 4), fps: 10),
      canvas: 40,
      footprint: SpriteFootprints.ambientCatLieRest,
      dy: 35,
    ),
  ],
);

/// The dwell scaled down: hold exactly 1 s, neutral gap exactly 600 ms.
const AmbientCadence _fixed = AmbientCadence(
  microRestShortest: Duration(milliseconds: 300),
  microRestLongest: Duration(milliseconds: 300),
  sceneRestShortest: Duration(milliseconds: 900),
  sceneRestLongest: Duration(milliseconds: 900),
  sceneHoldShortest: Duration(seconds: 1),
  sceneHoldLongest: Duration(seconds: 1),
  neutralRestShortest: Duration(milliseconds: 600),
  neutralRestLongest: Duration(milliseconds: 600),
);

int? _frameShown(WidgetTester tester, String prefix) {
  for (final GroundedSprite s in tester.widgetList<GroundedSprite>(
    find.byType(GroundedSprite),
  )) {
    final RegExpMatch? m = RegExp(
      '$prefix' r'_f(\d+)\.png$',
    ).firstMatch(s.assetPath);
    if (m != null) return int.parse(m.group(1)!);
  }
  return null;
}

Future<void> _mount(
  WidgetTester tester, {
  required AmbientSceneSet scenes,
  bool resumed = true,
  AmbientCadence? cadence = _fixed,
}) async {
  if (resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(tester.binding.resetInternalState);
  }
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: AmbientPlayer(
          scenes: scenes,
          restFrame: 'assets/art/v1/anim/gather_f0.png',
          restFootprint: SpriteFootprints.gather,
          restBetween: const Duration(milliseconds: 300),
          cadence: cadence,
          seed: 7,
        ),
      ),
    ),
  );
}

void main() {
  group('the shipped table', () {
    test('every full scene declares a coherent phasing; idle-only never', () {
      for (final AmbientScene s in AmbientAssets.scenes.scenes) {
        if (s.idleOnly) {
          expect(s.phasing, isNull, reason: '${s.id} is a micro-idle');
          continue;
        }
        final ScenePhasing? p = s.phasing;
        expect(p, isNotNull, reason: '${s.id} is a full scene and must dwell');
        expect(p!.loopStart, greaterThanOrEqualTo(0), reason: s.id);
        expect(p.loopEnd, lessThan(s.traveler.frames.length), reason: s.id);
        if (p.introEnd case final int intro) {
          expect(intro, lessThan(p.loopStart), reason: s.id);
        }
        if (p.outroStart case final int start) {
          expect(start, greaterThan(p.loopEnd), reason: s.id);
          expect(p.outroEnd!, lessThan(s.traveler.frames.length),
              reason: s.id);
        }
      }
    });

    test("a held scene's total lands in the owner's 20-30 s window", () {
      const AmbientCadence c = AmbientCadence.standard;
      for (final AmbientScene s in AmbientAssets.scenes.scenes) {
        final ScenePhasing? p = s.phasing;
        if (p == null) continue;
        final double fps = s.traveler.fps;
        for (final Duration bound in <Duration>[
          c.sceneHoldShortest,
          c.sceneHoldLongest,
        ]) {
          final Duration total =
              p.introDuration(fps) +
              p.quantizedHold(bound, fps) +
              p.outroDuration(fps);
          expect(total.inMilliseconds, greaterThanOrEqualTo(19000),
              reason: '${s.id} at $bound');
          expect(total.inMilliseconds, lessThanOrEqualTo(31000),
              reason: '${s.id} at $bound');
        }
      }
    });
  });

  group('the dwell', () {
    testWidgets('intro, held wrapping loop with a living layer, outro', (
      WidgetTester tester,
    ) async {
      final AmbientSceneSet set = AmbientSceneSet(<AmbientScene>[
        _arcScene('arc'),
      ]);
      await _mount(tester, scenes: set);

      // Through the 300 ms visit rest and into the intro.
      Future<void> run(Duration d) async {
        final int steps = d.inMilliseconds ~/ _step.inMilliseconds;
        for (int i = 0; i < steps; i++) {
          await tester.pump(_step);
        }
      }

      await run(const Duration(milliseconds: 400));
      final int? introFrame = _frameShown(tester, 'traveler_sit_ground');
      expect(introFrame, isNotNull, reason: 'the scene is on stage');
      expect(introFrame, lessThanOrEqualTo(2), reason: 'the entry arc first');

      // Deep in the hold: the frame stays inside the loop range, and the
      // range is revisited — a wrap, not a clamp.
      final Set<int> seen = <int>{};
      final Set<int> layerSeen = <int>{};
      await run(const Duration(milliseconds: 400));
      for (int i = 0; i < 24; i++) {
        await run(const Duration(milliseconds: 25));
        final int? f = _frameShown(tester, 'traveler_sit_ground');
        if (f != null) seen.add(f);
        final int? l = _frameShown(tester, 'cat_lie_rest');
        if (l != null) layerSeen.add(l);
      }
      expect(seen, isNotEmpty);
      expect(seen.every((int f) => f >= 3 && f <= 6), isTrue,
          reason: 'the hold lives in the loop range, saw $seen');
      expect(seen.length, greaterThan(1), reason: 'the loop moves');
      // The companion's own 400 ms pass wrapped rather than clamping: at
      // ~1 s+ into the scene it is still changing frames.
      expect(layerSeen.length, greaterThan(1),
          reason: 'the layer sustains, saw $layerSeen');

      // The outro closes the arc, then the stage rests.
      await run(const Duration(milliseconds: 700));
      await tester.pump(_step);
      final int? after = _frameShown(tester, 'traveler_sit_ground');
      expect(after == null || after >= 7 || after <= 2, isTrue,
          reason: 'outro or rest after the hold, saw $after');
    });

    testWidgets('the harness seam holds: no lifecycle state, no dwell', (
      WidgetTester tester,
    ) async {
      final AmbientSceneSet set = AmbientSceneSet(<AmbientScene>[
        _arcScene('arc'),
        _arcScene('brc'),
      ]);
      await _mount(tester, scenes: set, resumed: false);
      // Straight-through scenes and short rests settle exactly as every
      // screen test in the repository depends on.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
