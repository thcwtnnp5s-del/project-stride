/// The ambient scene system: frames advance under pumped time, the app's
/// lifecycle stops it, a gather takes priority and hands back, scenes do not
/// repeat back to back, and nothing in it can reach the session.
///
/// Every scene here is built from stand-in frames; the assets are never
/// decoded, because these are timing and priority tests, not pixel tests.
library;

import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_player.dart';
import 'package:stride/ui/components/ambient_scene.dart';
import 'package:stride/ui/components/ambient_stage.dart';
import 'package:stride/ui/components/grounded_sprite.dart';
import 'package:stride/ui/components/sprite_animation.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';

const List<String> _gather = <String>[
  'assets/art/v1/anim/gather_f0.png',
  'assets/art/v1/anim/gather_f1.png',
  'assets/art/v1/anim/gather_f2.png',
  'assets/art/v1/anim/gather_f3.png',
];

const Duration _rest = Duration(milliseconds: 500);

AmbientScene _scene(String id, {double weight = 1}) => AmbientScene(
  id: id,
  traveler: AmbientTrack(frames: _gather, fps: 10, loop: AmbientLoop.once),
  footprint: SpriteFootprints.gather,
  weight: weight,
);

final AmbientSceneSet _set = AmbientSceneSet(<AmbientScene>[
  _scene('a'),
  _scene('b'),
  _scene('c', weight: 2),
]);

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

/// The asset the Traveler's `GroundedSprite` is currently showing.
String _travelerAsset(WidgetTester tester) {
  final Iterable<GroundedSprite> sprites = tester.widgetList<GroundedSprite>(
    find.byType(GroundedSprite),
  );
  return sprites.first.assetPath;
}

void main() {
  group('AmbientTrack timing', () {
    test('loop, pingpong and once traverse as declared', () {
      const AmbientTrack loop = AmbientTrack(
        frames: _gather,
        fps: 4,
        repeats: 2,
      );
      expect(loop.slotCount, 8);
      expect(loop.duration, const Duration(seconds: 2));
      expect(loop.frameAt(const Duration(milliseconds: 1250)), 1);

      const AmbientTrack pp = AmbientTrack(
        frames: _gather,
        fps: 1,
        loop: AmbientLoop.pingpong,
      );
      expect(pp.slotCount, 6);
      expect(
        List<int>.generate(6, (int i) => pp.frameAt(Duration(seconds: i))),
        <int>[0, 1, 2, 3, 2, 1],
      );

      const AmbientTrack once = AmbientTrack(
        frames: _gather,
        fps: 1,
        loop: AmbientLoop.once,
        repeats: 5,
      );
      expect(once.slotCount, 4, reason: 'once ignores repeats');
      expect(once.frameAt(const Duration(seconds: 99)), 3, reason: 'holds');
    });

    test('pick is weighted and never returns the avoided scene', () {
      for (double roll = 0; roll < 1; roll += 0.05) {
        expect(_set.pick(roll, avoidId: 'c').id, isNot('c'));
      }
      // With `c` avoided the pool is a, b at equal weight: the halves.
      expect(_set.pick(0.1, avoidId: 'c').id, 'a');
      expect(_set.pick(0.9, avoidId: 'c').id, 'b');
    });
  });

  group('AmbientPlayer', () {
    testWidgets('frames advance with pumped time, and the visit settles', (
      WidgetTester tester,
    ) async {
      final List<String?> seen = <String?>[];
      await tester.pumpWidget(
        _host(
          AmbientPlayer(
            scenes: _set,
            restFrame: _gather.first,
            restFootprint: SpriteFootprints.gather,
            restBetween: _rest,
            scenesPerVisit: 2,
            seed: 7,
            onSceneChanged: (AmbientScene? s) => seen.add(s?.id),
          ),
        ),
      );

      // Resting first.
      expect(_travelerAsset(tester), _gather.first);
      expect(seen, isEmpty);

      // Into the first scene: frame 0, then frame 1 at 100 ms at 10 fps.
      await tester.pump(_rest);
      await tester.pump(const Duration(milliseconds: 1));
      expect(seen.length, 1);
      expect(_travelerAsset(tester), _gather[0]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_travelerAsset(tester), _gather[1]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_travelerAsset(tester), _gather[3]);

      // The scene ends, a rest follows, then the second scene, then spent.
      await tester.pumpAndSettle();
      expect(
        seen,
        <String?>[seen[0], null, seen[2], null],
        reason: 'scene, rest, scene, rest — and then nothing schedules a frame',
      );
      expect(seen[0], isNot(seen[2]));
      expect(_travelerAsset(tester), _gather.first);
    });

    testWidgets('no scene repeats immediately, across a long visit', (
      WidgetTester tester,
    ) async {
      final List<String> order = <String>[];
      await tester.pumpWidget(
        _host(
          AmbientPlayer(
            scenes: _set,
            restFrame: _gather.first,
            restFootprint: SpriteFootprints.gather,
            restBetween: _rest,
            scenesPerVisit: 40,
            seed: 3,
            onSceneChanged: (AmbientScene? s) {
              if (s != null) order.add(s.id);
            },
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(order.length, 40);
      for (int i = 1; i < order.length; i++) {
        expect(order[i], isNot(order[i - 1]), reason: 'position $i');
      }
      expect(order.toSet(), <String>{'a', 'b', 'c'}, reason: 'all get a turn');
    });

    testWidgets('pauses while the app is not resumed, and picks up after', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AmbientPlayer(
            scenes: _set,
            restFrame: _gather.first,
            restFootprint: SpriteFootprints.gather,
            restBetween: _rest,
            scenesPerVisit: 3,
            seed: 1,
          ),
        ),
      );
      await tester.pump(_rest);
      await tester.pump(const Duration(milliseconds: 1)); // past the rest
      await tester.pump(const Duration(milliseconds: 101));
      expect(_travelerAsset(tester), _gather[1]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(
        _travelerAsset(tester),
        _gather[1],
        reason: 'nothing advances while backgrounded',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'no ticker runs while the app is not in the foreground',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _travelerAsset(tester),
        _gather[2],
        reason: 'resumes where it was',
      );
    });

    testWidgets('a companion layer is composited with its own shadow', (
      WidgetTester tester,
    ) async {
      final AmbientSceneSet set = AmbientSceneSet(<AmbientScene>[
        AmbientScene(
          id: 'cat',
          traveler: const AmbientTrack(frames: _gather, fps: 10),
          footprint: SpriteFootprints.gather,
          layers: const <AmbientLayer>[
            AmbientLayer(
              track: AmbientTrack(frames: _gather, fps: 5),
              canvas: 32,
              footprint: SpriteFootprint(left: 8, right: 23, bottom: 30),
              dx: 40,
              dy: 33,
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(
        _host(
          AmbientPlayer(
            scenes: set,
            restFrame: _gather.first,
            restFootprint: SpriteFootprints.gather,
            restBetween: _rest,
            scenesPerVisit: 1,
            seed: 1,
          ),
        ),
      );
      await tester.pump(_rest);
      await tester.pump(const Duration(milliseconds: 1)); // past the rest
      await tester.pump(const Duration(milliseconds: 201));

      final List<GroundedSprite> sprites = tester
          .widgetList<GroundedSprite>(find.byType(GroundedSprite))
          .toList();
      expect(sprites.length, 2, reason: 'the Traveler and the cat');
      expect(sprites[1].canvas, 32);
      expect(
        sprites[1].assetPath,
        _gather[1],
        reason: '5 fps: frame 1 at 200 ms',
      );
      expect(sprites[0].assetPath, _gather[2], reason: '10 fps: frame 2');

      final Offset traveler = tester.getTopLeft(find.byWidget(sprites[0]));
      final Offset cat = tester.getTopLeft(find.byWidget(sprites[1]));
      expect(cat - traveler, const Offset(80, 66), reason: '(40, 33) at ×2');
    });
  });

  group('AmbientStage', () {
    testWidgets('a play token shows the gather; ambient resumes after', (
      WidgetTester tester,
    ) async {
      Widget stage(Object? token) => _host(
        AmbientStage(
          gatherFrames: _gather,
          gatherFootprint: SpriteFootprints.gather,
          playToken: token,
          scenes: _set,
          restFrame: _gather.first,
          restFootprint: SpriteFootprints.gather,
          scenesPerVisit: 2,
          seed: 5,
        ),
      );

      bool gatherVisible() => tester
          .widget<Visibility>(
            find.ancestor(
              of: find.byType(SpriteAnimation),
              matching: find.byType(Visibility),
            ),
          )
          .visible;
      Image gatherImage() => tester.widget<Image>(
        find.descendant(
          of: find.byType(SpriteAnimation),
          matching: find.byType(Image),
        ),
      );
      Image ambientImage() => tester.widget<Image>(
        find.descendant(
          of: find.byType(AmbientPlayer),
          matching: find.byType(Image),
        ),
      );

      await tester.pumpWidget(stage(null));
      // Into an ambient scene: the gather widget is hidden, the player is on.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 1)); // past the rest
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(AmbientPlayer), findsOneWidget, reason: 'onstage');
      expect(
        gatherVisible(),
        isFalse,
        reason: 'the gather widget is kept mounted but hidden under a scene',
      );
      expect(
        (ambientImage().image as AssetImage).assetName,
        _gather[1],
        reason: '10 fps: frame 1 at 150 ms',
      );

      // A gather lands mid-scene: it takes the stage at once.
      await tester.pumpWidget(stage(Object()));
      await tester.pump();
      expect(gatherVisible(), isTrue);
      expect(find.byType(AmbientPlayer), findsNothing, reason: 'offstage');
      await tester.pump(const Duration(milliseconds: 230));
      expect((gatherImage().image as AssetImage).assetName, _gather[2]);

      // The gather ends (4 × 110 ms); the stage rests, then a new visit.
      await tester.pump(const Duration(milliseconds: 300));
      expect(gatherVisible(), isTrue);
      expect((gatherImage().image as AssetImage).assetName, _gather.first);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 1)); // past the rest
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(AmbientPlayer), findsOneWidget);
      expect(gatherVisible(), isFalse);

      // And everything settles: the gather widget at its rest frame.
      await tester.pumpAndSettle();
      expect(gatherVisible(), isTrue);
      expect(find.byType(AmbientPlayer), findsNothing);
      expect((gatherImage().image as AssetImage).assetName, _gather.first);
      expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    });

    testWidgets('the stand-in table rests on the gather rest pose', (
      WidgetTester tester,
    ) async {
      expect(AmbientAssets.restFrame, endsWith('gather_f0.png'));
      expect(AmbientAssets.scenes.isEmpty, isFalse);
      for (final AmbientScene s in AmbientAssets.scenes.scenes) {
        expect(s.duration, greaterThan(Duration.zero), reason: s.id);
      }
    });
  });

  group('boundary', () {
    test('ambient sources touch nothing but presentation', () {
      final Directory dir = Directory('lib/ui/components');
      final List<File> files = dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.contains('ambient_'))
          .toList();
      expect(files.length, 3, reason: 'scene, player, stage');
      final List<File> all = <File>[
        ...files,
        File('lib/ui/icons/ambient_assets.dart'),
      ];

      const List<String> forbidden = <String>[
        'SessionController',
        'SessionScope',
        'StrideSession',
        'stride_core',
        'Timer',
        'DateTime',
        'SharedPreferences',
        'gather(',
        'syncSteps',
        'travel(',
        'craft(',
        'usableEnergy',
        'totalGranted',
      ];
      for (final File f in all) {
        final String code = f
            .readAsStringSync()
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        for (final String p in forbidden) {
          expect(
            code,
            isNot(contains(p)),
            reason: '${f.path} mentions "$p" — ambient is presentation only',
          );
        }
      }
    });
  });
}
