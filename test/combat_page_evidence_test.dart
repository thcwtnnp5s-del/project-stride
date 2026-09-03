/// Device-size evidence for the EPO03 battle page: the whole screen at
/// 393 × 852, in the seven states `DIR-11` asks a reviewer to look at.
///
/// `combat_ui_test.dart` proves the arithmetic — 398 dp of chassis against a
/// 120 dp rail in a 699 dp column. It cannot prove the thing the owner
/// actually ruled on, which is whether the fight outweighs the buttons **at a
/// glance** (`RULES.md` A-3: the blind device read decides, metrics only
/// triage). So this writes what the screen paints, and a human looks at it.
///
/// Gated on `COMBAT_EVIDENCE_DIR`, like `combat_gear_evidence_test.dart`.
/// Silent in CI; it asserts nothing a golden would.
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
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId guardian = ContentId.unchecked('enemy.hollow_guardian');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId herbBrothRecipe = ContentId.unchecked('recipe.herb_broth');

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  final String? dir = Platform.environment['COMBAT_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_cpage'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<void> settleImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final Element e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
      for (final Element e in find.byType(PixelFrame).evaluate()) {
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

  Future<void> shot(WidgetTester tester, String name) async {
    if (dir == null || dir.isEmpty) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(StrideApp).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// The phone's own frame at DPR 1, so a dp in the PNG is a dp on the device.
  Future<StrideSession> boot(
    WidgetTester tester, {
    bool armed = true,
    bool provisioned = false,
    ContentId? travelTo,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    return (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(60000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      if (provisioned) {
        for (int i = 0; i < 6; i++) {
          await s.gather(meadowPatch);
        }
        for (int i = 0; i < 3; i++) {
          await s.craft(herbBrothRecipe);
        }
      }
      if (armed) {
        await s.equip(trainingSword);
        await s.equip(tunic);
      }
      if (travelTo != null) await s.travel(travelTo);
      return s;
    }))!;
  }

  SessionController controllerOf() {
    final Element scope = find.byType(SessionScope).evaluate().first;
    return (scope.widget as SessionScope).notifier!;
  }

  testWidgets('the wolf: a turn with a sword in the plate, a brace hold, and '
      'a landed hit', (WidgetTester tester) async {
    if (dir == null || dir.isEmpty) return;
    final StrideSession s = await boot(tester, travelTo: woods);
    await tester.pumpWidget(StrideApp(session: s, syncOnStart: false));
    await tester.pumpAndSettle();
    final SessionController c = controllerOf();
    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpAndSettle();
    await settleImages(tester);
    await warm(
      tester,
      find.byType(CombatStage),
      'enemy.forest_wolf',
      'location.whispering_woods',
    );
    // 1 — the turn: the chassis, the lintel's two wells, the intent line, the
    // leather page, three plates and Retreat. This is the ratio shot.
    await shot(tester, 'page_wolf_turn');

    // 2 — the blow landing: the picture displaced and veiled white, mid-replay.
    await tester.runAsync(() => c.combatAttack());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    await shot(tester, 'page_wolf_hit');
    await tester.pumpAndSettle();
    await settleImages(tester);

    // 3 — the brace: the guard sentence on the intent line, the round held.
    await tester.runAsync(() => c.combatBrace());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await shot(tester, 'page_wolf_brace');
    await tester.pumpAndSettle();
  });

  testWidgets('the guardian: a BOSS chip in the lintel and a crown clear of '
      'the frame', (WidgetTester tester) async {
    if (dir == null || dir.isEmpty) return;
    // **The chassis alone, not the page.** The Forgotten Hollow's entry
    // requirement is a bronze sword the fixture cannot mint, so the boss is
    // staged the way `combat_golden_test.dart` stages it — the widget driven
    // directly from a hand-built view. What this shot is evidence *for* is the
    // guardian-specific claim and nothing else: TURN and BOSS stacked in the
    // centre of the lintel rather than as chips on the sky, and the crown
    // clear of the frame's top beam at the closed enemy column. The rail and
    // the ratio are proved by the four whole-page shots beside it.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(393, 852)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: StrideColors.surfaceGround,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RepaintBoundary(
                  child: CombatStage(
                    view: EncounterView(
                      enemyId: ContentId.unchecked('enemy.hollow_guardian'),
                      enemyName: 'Hollow Guardian',
                      location: ContentId.unchecked(
                        'location.forgotten_hollow',
                      ),
                      locationName: 'Forgotten Hollow',
                      turn: 3,
                      playerHp: 31,
                      playerMaxHp: 40,
                      playerAttack: 5,
                      playerDefence: 2,
                      enemyHp: 44,
                      enemyMaxHp: 60,
                      telegraph: true,
                      behavior: EnemyBehavior.guarded,
                      isBoss: true,
                    ),
                    report: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleImages(tester);
    await tester.runAsync(() async {
      for (final String f in CombatAssets.framesFor(
        ContentId.unchecked('enemy.hollow_guardian'),
        ContentId.unchecked('location.forgotten_hollow'),
      )) {
        await precacheImage(AssetImage(f), tester.element(find.byType(CombatStage)));
      }
    });
    await tester.pumpAndSettle();
    if (dir.isNotEmpty) {
      await tester.runAsync(() async {
        final ui.Image image = await captureImage(
          find.byType(CombatStage).evaluate().single,
        );
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        Directory(dir).createSync(recursive: true);
        File('$dir/chassis_guardian.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  testWidgets('unarmed: the same page with nothing in the hand', (
    WidgetTester tester,
  ) async {
    if (dir == null || dir.isEmpty) return;
    final StrideSession s = await boot(tester, armed: false, travelTo: woods);
    await tester.pumpWidget(StrideApp(session: s, syncOnStart: false));
    await tester.pumpAndSettle();
    final SessionController c = controllerOf();
    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpAndSettle();
    await settleImages(tester);
    // 5 — the unarmed set, and Eat refused with its reason on the plate.
    await shot(tester, 'page_unarmed');
  });

  testWidgets('the Eat chooser resolves on the page, and Retreat is a link', (
    WidgetTester tester,
  ) async {
    if (dir == null || dir.isEmpty) return;
    final StrideSession s = await boot(
      tester,
      provisioned: true,
      travelTo: woods,
    );
    await tester.pumpWidget(StrideApp(session: s, syncOnStart: false));
    await tester.pumpAndSettle();
    final SessionController c = controllerOf();
    await tester.runAsync(() => c.startEncounter(wolf));
    await tester.pumpAndSettle();
    await settleImages(tester);

    // Take a wound first, so Eat is offered rather than refused for full HP.
    await tester.runAsync(() => c.combatAttack());
    await tester.pumpAndSettle();
    await settleImages(tester);

    // 6 — the chooser on the leather, in the room the card used to be.
    if (find.text('Eat').evaluate().isNotEmpty) {
      await tester.tap(find.text('Eat'));
      await tester.pumpAndSettle();
    }
    await shot(tester, 'page_eat_chooser');

    // 7 — the retreat moment: the result raised over the fight behind it.
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.combatRetreat());
    await tester.pumpAndSettle();
    await settleImages(tester);
    await shot(tester, 'page_retreat');
  });
}
