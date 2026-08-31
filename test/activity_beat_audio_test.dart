/// The working loop's **action beat** — the one signal that turns a visible
/// tool strike into a sound (`AmbientStage.onActivityBeat`).
///
/// ## Why this file exists
///
/// Nothing tested this callback. Every audio test in the repository iterated a
/// cue table and checked the world against it, which is structurally incapable
/// of noticing that the callback never fires. It did not fire, for every
/// player with Reduce Motion enabled, in every profession, for the whole life
/// of the audio layer: `_ActivityLoop` stopped its controller under
/// `MediaQuery.disableAnimationsOf`, so `_onTick` never ran, so `onBeat` never
/// called — a **total SFX blackout** with nothing on screen, in a log, or in a
/// suite to say so (PRESENTATION_COMBAT_EVOLUTION_01).
///
/// The fix separates the cadence cursor from the drawn frame. These tests pin
/// both halves of that separation: the picture must hold still, and the sound
/// must keep its timing. A future change that silences one to achieve the
/// other fails here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_stage.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';

/// One frame of the mining loop. Eight of these is a cycle (880 ms).
///
/// The loop is pumped a **frame at a time**, never a cycle at a time: the
/// cursor only moves when the frame index changes, so a single `pump(880ms)`
/// lands back on the frame it started from and steps nothing.
const Duration _frame = Duration(milliseconds: 110);

/// Advances [tester] by one full 8-frame cycle, one frame at a time.
Future<void> _pumpCycle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(_frame);
  }
}

void main() {
  const String skill = 'skill.mining';

  /// The stage in activity mode, counting strikes into [beats].
  Widget stage(List<int> beats, {required bool reduceMotion}) {
    final Widget app = MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: 393,
            height: 200,
            child: AmbientStage(
              gatherFrames: PixelIcons.gatherFrames,
              gatherFootprint: SpriteFootprints.gather,
              playToken: null,
              scenes: AmbientAssets.scenesFor('location.stonefall_mine'),
              restFrame: AmbientAssets.restFrame,
              restFootprint: AmbientAssets.restFootprint,
              activityFrames: AmbientAssets.activityLoopFor(skill),
              activityFootprint: AmbientAssets.activityFootprintFor(skill),
              activityCanvas: AmbientAssets.activityCanvasFor(skill),
              activityStrikeFrame: AmbientAssets.strikeFrameFor(skill),
              activityActive: true,
              onActivityBeat: () => beats.add(beats.length),
            ),
          ),
        ),
      ),
    );
    if (!reduceMotion) return app;
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }

  testWidgets('the working loop strikes, and each strike is one beat', (
    WidgetTester tester,
  ) async {
    final List<int> beats = <int>[];
    await tester.pumpWidget(stage(beats, reduceMotion: false));
    await tester.pump();

    // Three full cycles: three tool contacts, three beats. The count is the
    // claim — a loop that fired per frame would report 24.
    for (int i = 0; i < 3; i++) {
      await _pumpCycle(tester);
    }
    expect(
      beats.length,
      inInclusiveRange(2, 4),
      reason: 'three loop cycles should land roughly three strikes, got '
          '${beats.length}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'REDUCE MOTION: the picture holds still and the strikes still sound',
    (WidgetTester tester) async {
      final List<int> beats = <int>[];
      await tester.pumpWidget(stage(beats, reduceMotion: true));
      await tester.pump();

      // The regression, stated directly: this list was empty forever.
      for (int i = 0; i < 3; i++) {
        await _pumpCycle(tester);
      }
      expect(
        beats,
        isNotEmpty,
        reason:
            'Reduce Motion must silence the MOTION, not the GAME. An empty '
            'list here is the total-SFX-blackout defect returning: every '
            'profession cue lost, for every player who prefers a still '
            'picture, with no other symptom.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('REDUCE MOTION: the drawn frame never leaves the rest pose', (
    WidgetTester tester,
  ) async {
    final List<int> beats = <int>[];
    await tester.pumpWidget(stage(beats, reduceMotion: true));
    await tester.pump();

    final List<String> frames = AmbientAssets.activityLoopFor(skill);
    String? drawn() {
      for (final Element e in find.byType(Image).evaluate()) {
        final Object image = (e.widget as Image).image;
        if (image is AssetImage && frames.contains(image.assetName)) {
          return image.assetName;
        }
      }
      return null;
    }

    final String? first = drawn();
    expect(first, isNotNull, reason: 'the loop should be on screen');
    // The cursor advances underneath; the picture must not.
    for (int i = 0; i < 3; i++) {
      await _pumpCycle(tester);
      expect(
        drawn(),
        first,
        reason:
            'the held pose moved under Reduce Motion — the cadence cursor is '
            'leaking into the drawn frame',
      );
    }
    expect(first, frames.first);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
