/// Device-size evidence for the FMPO02 craft re-dress: the smith and the cook
/// in every armour, at the station, as `_ActiveCraftPanel` composes them.
///
/// There is no grant path for a Bronze Chestplate inside a test session, so a
/// full-screen capture cannot show an armoured smith. What can be shown
/// honestly is the production stage widget fed the same inputs the craft
/// panel derives from the loadout — the same resolver, the same frames, the
/// same station prop, the same canvas — at the panel's own 140 dp height and
/// 361 dp width. FINAL-03 blocker 1 ("Craft still draws the base body") is
/// closed or not by what these pictures show.
///
/// Gated on `COMBAT_EVIDENCE_DIR`, like `combat_gear_evidence_test.dart`.
/// Silent in CI; it asserts only that the resolver picked the armoured strip.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/ambient_stage.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/sprite_footprints.dart';
import 'package:stride/ui/icons/traveler_art.dart';

import 'support/real_font.dart';

EquipmentVisualState _wearing(String armour) => EquipmentVisualState(
  armor: EquippedVisualFact(itemId: armour, tier: 1, toolKind: 'none'),
);

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(393, 852)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 361,
        height: 140,
        child: RepaintBoundary(
          child: ColoredBox(color: const Color(0xFF1B1916), child: child),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadRealFont);
  final String? dir = Platform.environment['COMBAT_EVIDENCE_DIR'];

  Future<void> shot(WidgetTester tester, String name) async {
    if (dir == null || dir.isEmpty) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(RepaintBoundary).evaluate().first,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final (String skill, String label) in <(String, String)>[
    ('skill.smithing', 'smith'),
    ('skill.cooking', 'cook'),
  ]) {
    for (final (String armour, String body) in <(String, String)>[
      ('item.bronze_chestplate', 'plate'),
      ('item.wolfhide_jerkin', 'jerkin'),
      ('item.bearhide_coat', 'coat'),
      // EPO03: the fifth body. The Waywarden's Tunic drew the starting shirt
      // at every station until this round.
      ('item.waywarden_tunic', 'warden'),
    ]) {
      testWidgets('$body at the $label station, as the craft panel draws it', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

        final EquipmentVisualState visual = _wearing(armour);
        final GatherStrip? dressed = TravelerArt.craftLoopFor(skill, visual);
        expect(dressed, isNotNull, reason: '$armour has no $label loop');
        expect(dressed!.frames.first, contains('traveler_${body}_'));
        final String station = AmbientAssets.craftStationKind(null, skill);

        await tester.pumpWidget(
          _host(
            AmbientStage(
              gatherFrames: PixelIcons.gatherFrames,
              gatherFootprint: SpriteFootprints.gather,
              playToken: null,
              scenes: TravelerArt.idleScenesFor(
                visual,
                base: AmbientAssets.scenes,
              ),
              restFrame:
                  TravelerArt.restFrameFor(visual) ?? AmbientAssets.restFrame,
              restFootprint:
                  TravelerArt.restFootprintFor(visual) ??
                  AmbientAssets.restFootprint,
              prop: AmbientAssets.stationFor(station),
              activityFrames: dressed.frames,
              activityFootprint: dressed.footprint,
              activityCanvas: dressed.canvasWidth,
              activityActive: true,
              activityStrikeFrame: dressed.strikeFrame,
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final BuildContext ctx = tester.element(find.byType(AmbientStage));
          for (final String f in dressed.frames.toSet()) {
            await precacheImage(AssetImage(f), ctx);
          }
        });
        await tester.pump();
        await shot(tester, 'stage_craft_${label}_${body}_f0');
        // Into the loop: the hammer down, the spoon in the pot.
        await tester.pump(const Duration(milliseconds: 650));
        await shot(tester, 'stage_craft_${label}_${body}_mid');
      });
    }
  }

  // EPO03 — the warden at work, in the three gather contexts the same stage
  // composes. The craft block above proves the smith and the cook; this proves
  // that mining, woodcutting and foraging draw the hooded body and the tool
  // the loadout actually carries, which is what DIR-08 failure 3 was about.
  for (final (String skill, String tool, String label) in <(String, String, String)>[
    ('skill.mining', 'item.bronze_pickaxe', 'mine_bronze'),
    ('skill.mining', 'item.training_pickaxe', 'mine_steel'),
    ('skill.woodcutting', 'item.bronze_axe', 'woodcut_bronze'),
    ('skill.woodcutting', 'item.training_axe', 'woodcut_steel'),
    ('skill.foraging', 'item.bronze_pickaxe', 'forage'),
  ]) {
    testWidgets('the warden at $label, as the work stage draws it', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      final EquipmentVisualState visual = EquipmentVisualState(
        armor: const EquippedVisualFact(
          itemId: 'item.waywarden_tunic',
          tier: 1,
          toolKind: 'none',
        ),
        tool: EquippedVisualFact(itemId: tool, tier: 1, toolKind: 'axe'),
      );
      final GatherStrip? strip = TravelerArt.gatherStripFor(skill, visual);
      expect(strip, isNotNull, reason: 'the warden has no $skill loop');
      expect(strip!.frames.first, contains('traveler_warden_'));

      await tester.pumpWidget(
        _host(
          AmbientStage(
            gatherFrames: PixelIcons.gatherFrames,
            gatherFootprint: SpriteFootprints.gather,
            playToken: null,
            scenes: TravelerArt.idleScenesFor(
              visual,
              base: AmbientAssets.scenes,
            ),
            restFrame:
                TravelerArt.restFrameFor(visual) ?? AmbientAssets.restFrame,
            restFootprint:
                TravelerArt.restFootprintFor(visual) ??
                AmbientAssets.restFootprint,
            activityFrames: strip.frames,
            activityFootprint: strip.footprint,
            activityCanvas: strip.canvasWidth,
            activityActive: true,
            activityStrikeFrame: strip.strikeFrame,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final BuildContext ctx = tester.element(find.byType(AmbientStage));
        for (final String f in strip.frames.toSet()) {
          await precacheImage(AssetImage(f), ctx);
        }
      });
      await tester.pump();
      await shot(tester, 'stage_warden_${label}_f0');
      await tester.pump(const Duration(milliseconds: 650));
      await shot(tester, 'stage_warden_${label}_mid');
    });
  }
}
