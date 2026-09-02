/// The combat screen at the reference viewport, as a golden — and, when asked,
/// as evidence renders a person can look at.
///
/// Same claims and same limits as `phase1_golden_test.dart`: a regression
/// golden between Flutter revisions, with a real font so type is visible, no
/// safe-area insets, Roboto rather than SF Pro. Green means the layout has not
/// moved; it does not mean the stage looks right. **Look at the image.**
///
/// The golden is the Whispering Woods, the wolf, turn 1, both figures idle on
/// their first frame (the idle visit is spent once the tester settles). The
/// stage under a replay is not a golden — its frames are timing, and
/// `combat_stage_test.dart` proves the timing — but with
/// `COMBAT_EVIDENCE_DIR` set this file also writes three PNGs there for a
/// reviewer: the wolf stage mid-swing (the impact burst on the wolf), the
/// guardian idle in the Hollow, and the guardian's heavy blow landing. Those
/// are evidence, not tests: nothing compares them.
///
/// Regenerate with:
///   flutter test test/combat_golden_test.dart --update-goldens
@Tags(<String>['golden'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/panel_skin.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/icons/combat_assets.dart';
import 'package:stride/ui/screens/combat/combat_stage.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride/ui/theme/stride_colors.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

EncounterView guardianView({int turn = 1, bool telegraph = false}) =>
    EncounterView(
      enemyId: ContentId.unchecked('enemy.hollow_guardian'),
      enemyName: 'Hollow Guardian',
      location: ContentId.unchecked('location.forgotten_hollow'),
      locationName: 'Forgotten Hollow',
      turn: turn,
      playerHp: 40,
      playerMaxHp: 40,
      playerAttack: 5,
      playerDefence: 2,
      enemyHp: 60,
      enemyMaxHp: 60,
      telegraph: telegraph,
      behavior: EnemyBehavior.guarded,
      isBoss: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_cgolden'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  /// Decodes every `Image` in the tree, then settles — `pumpAndSettle` does
  /// not wait for asset decode (`phase1_golden_test.dart`).
  Future<void> settleImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final Element e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
      for (final Element e in find.byType(PixelFrame).evaluate()) {
        // PixelFrame is NOT an `Image`: it resolves an AssetImage through an
        // ImageStream and paints with CustomPaint, so the loop above never
        // sees it and the chassis frame decoded whenever it happened to
        // finish. Skills won that race and Adventure lost it in the same run,
        // which is a flaky golden rather than a wrong one — the worse of the
        // two, because it fails for whoever runs it next.
        await precacheImage(
          AssetImage((e.widget as PixelFrame).skin.assetPath),
          e,
        );
        final SurfaceTile? tile = (e.widget as PixelFrame).surface;
        if (tile != null) await precacheImage(AssetImage(tile.assetPath), e);
      }
      for (final Element e in find.byType(SurfaceFill).evaluate()) {
        await precacheImage(
          AssetImage((e.widget as SurfaceFill).tile.assetPath),
          e,
        );
      }
    });
    await tester.pumpAndSettle();
  }

  /// Decodes every frame the stage may draw for [enemy] at [location] — a
  /// replay is caught mid-frame, so the images must already be in the cache
  /// before the frame is pumped.
  Future<void> warm(
    WidgetTester tester,
    Finder context,
    String enemy,
    String location,
  ) async {
    final BuildContext ctx = tester.element(context);
    await tester.runAsync(() async {
      for (final String f in CombatAssets.framesFor(
        ContentId.unchecked(enemy),
        ContentId.unchecked(location),
      )) {
        await precacheImage(AssetImage(f), ctx);
      }
    });
  }

  /// Writes what [finder] paints to `<COMBAT_EVIDENCE_DIR>/<name>.png`, when
  /// that variable is set. Silent otherwise.
  Future<void> evidence(WidgetTester tester, Finder finder, String name) async {
    final String? dir = Platform.environment['COMBAT_EVIDENCE_DIR'];
    if (dir == null || dir.isEmpty) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(finder.evaluate().single);
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets(
    'the combat screen at 393 x 852: Whispering Woods, wolf, turn 1',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      final StrideSession s = (await tester.runAsync(() async {
        final StrideSession s = await StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(
            script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(5000)],
          ),
        );
        await s.syncSteps();
        await s.syncSteps();
        await s.equip(trainingSword);
        await s.equip(tunic);
        final TravelReport t = await s.travel(woods);
        expect(t.succeeded, isTrue, reason: '${t.rejection}');
        return s;
      }))!;

      await tester.pumpWidget(StrideApp(session: s, syncOnStart: false));
      await tester.pumpAndSettle();
      final Element scope = find.byType(SessionScope).evaluate().first;
      final SessionController c = (scope.widget as SessionScope).notifier!;
      await tester.runAsync(() => c.startEncounter(wolf));
      await tester.pumpAndSettle();
      await settleImages(tester);
      expect(find.text('TURN 1'), findsOneWidget);
      expect(find.text('20 / 20'), findsOneWidget);

      await expectLater(
        find.byType(StrideApp),
        matchesGoldenFile('goldens/combat_stage.png'),
      );

      // Evidence: the first round, caught mid-swing on the slash frame with the
      // impact on the wolf.
      await warm(
        tester,
        find.byType(CombatStage),
        'enemy.forest_wolf',
        'location.whispering_woods',
      );
      await tester.runAsync(() => c.combatAttack());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      await evidence(tester, find.byType(StrideApp), 'combat_wolf_slash');
      await tester.pumpAndSettle();
      await evidence(tester, find.byType(StrideApp), 'combat_wolf_turn2');
    },
  );

  testWidgets('the victory panel at 393 x 852: the wolf felled, XP and the '
      'drops as rarity rows', (WidgetTester tester) async {
    // World & Reward Depth 01: the shipped look of winning — VICTORY, the
    // EXPERIENCE block, one framed reward row per drop with icon, rank ink,
    // badge and count, and Continue. A golden so a change to the rarity style
    // or the panel is a deliberate regeneration.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession s = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(5000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      await s.equip(trainingSword);
      await s.equip(tunic);
      final TravelReport t = await s.travel(woods);
      expect(t.succeeded, isTrue, reason: '${t.rejection}');
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: s, syncOnStart: false));
    await tester.pumpAndSettle();
    final Element scope = find.byType(SessionScope).evaluate().first;
    final SessionController c = (scope.widget as SessionScope).notifier!;
    // The seeded resolver makes the fight deterministic, so the drops — and
    // therefore the golden — are stable across runs.
    await tester.runAsync(() async {
      await c.startEncounter(wolf);
      for (int i = 0; i < 60 && s.encounter != null; i++) {
        await c.combatAttack();
      }
    });
    expect(s.encounter, isNull);
    expect(c.lastCombat?.outcome, isA<WonBeat>());
    await tester.pumpAndSettle();
    await settleImages(tester);
    expect(find.text('VICTORY'), findsOneWidget);
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/combat_victory.png'),
    );
  });

  testWidgets('evidence: the guardian in the Hollow, idle and landing the '
      'heavy blow', (WidgetTester tester) async {
    if ((Platform.environment['COMBAT_EVIDENCE_DIR'] ?? '').isEmpty) return;
    tester.view.physicalSize = const Size(393, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget host(EncounterView v, CombatReport? r) => MediaQuery(
      data: const MediaQueryData(size: Size(393, 400)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        // The app's theme names Roboto for it; this bare host must say so.
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: ColoredBox(
            color: StrideColors.surfaceGround,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: const ValueKey<String>('stage'),
                  child: CombatStage(view: v, report: r),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(guardianView(telegraph: true), null));
    await tester.pumpAndSettle();
    final Finder stage = find.byKey(const ValueKey<String>('stage'));
    await warm(
      tester,
      stage,
      'enemy.hollow_guardian',
      'location.forgotten_hollow',
    );
    await tester.pumpAndSettle();
    await evidence(tester, stage, 'combat_guardian_idle');

    const CombatReport heavy = CombatReport(
      succeeded: true,
      enemyName: 'Hollow Guardian',
      events: <CombatBeat>[
        PlayerStruckBeat(damage: 5, enemyHpAfter: 55),
        EnemyStruckBeat(
          damage: 9,
          playerHpAfter: 31,
          heavy: true,
          strikeIndex: 0,
        ),
        RoundEndedBeat(turn: 2, telegraph: false),
      ],
    );
    await tester.pumpWidget(
      host(guardianView(turn: 2, telegraph: true), heavy),
    );
    await tester.pump();
    // Slash frame with the impact on the guardian's hit pose.
    await tester.pump(const Duration(milliseconds: 260));
    await evidence(tester, stage, 'combat_guardian_struck');
    // Into the heavy blow: segment 1 is 700 ms; the arm comes down 500 ms in.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 520));
    await evidence(tester, stage, 'combat_guardian_heavy');
    await tester.pumpAndSettle();
  });
}
