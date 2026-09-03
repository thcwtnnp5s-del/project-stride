// The work-stage evidence harness (PLAYABLE_EXPERIENCE_REFINEMENT_01 §7,
// §44): renders the REAL `LocationStage` in work mode — backdrop, prop, the
// profession loop — at phone width, and writes every loop frame to
// `STAGE_EVIDENCE_DIR` when that variable is set, so tool/resource contact,
// ground-line agreement and the locked selection can be inspected in context
// rather than as isolated sprite strips. Silent without the variable, and
// then only a mount-and-pump smoke test of the five work compositions the
// brief names. The same pattern as `combat_golden_test.dart`'s
// `COMBAT_EVIDENCE_DIR`.
//
// Usage:
//   STAGE_EVIDENCE_DIR=/tmp/stage flutter test test/stage_evidence_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/icons/traveler_art.dart';
import 'package:stride/ui/screens/adventure/location_stage.dart';
import 'package:stride/ui/theme/stride_theme.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real type, or every label in the evidence is a row of tofu boxes and the
  // renders are unverifiable for anything but the sprite (FINAL-09).
  setUpAll(loadRealFont);
  final String? dir = Platform.environment['STAGE_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_stagecap'));
  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (dir == null) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(LocationStage).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final (String tag, String nodeId, String locId, bool locked) in <(String, String, String, bool)>[
    ('mine_copper', 'resource_node.copper_seam', 'location.stonefall_mine', false),
    ('mine_tin', 'resource_node.tin_seam', 'location.stonefall_mine', false),
    ('mine_hardened_locked', 'resource_node.hardened_copper_seam', 'location.stonefall_mine', true),
    ('woods_oak', 'resource_node.oak_stand', 'location.whispering_woods', false),
    ('haven_meadow', 'resource_node.meadow_patch', 'location.havens_rest', false),
    // EPO03 gather (`wave1/DIR-10_gathering.md`). The five rows above cover
    // three of the twelve scenes that round repainted; these six cover the
    // rest, so every replaced backdrop and every replaced plate is judged in
    // the composition the phone shows rather than as a plate on a sheet.
    // Verdicts and sheets: `GAME_BIBLE/ART/exploration/EPO03/ledger/GATHER.md`.
    ('haven_mill_garden', 'resource_node.mill_garden', 'location.havens_rest', false),
    ('frostmere_rimefrost', 'resource_node.rimefrost_hollow', 'location.frostmere', false),
    ('frostmere_oldgrowth', 'resource_node.oldgrowth_frostpine', 'location.frostmere', false),
    ('hollow_silkstrand', 'resource_node.silkstrand_thicket', 'location.forgotten_hollow', false),
    ('woods_duskcap', 'resource_node.duskcap_grove', 'location.whispering_woods', false),
    ('mine_deep_tin', 'resource_node.deep_tin_seam', 'location.stonefall_mine', false),
  ]) {
    testWidgets('capture $tag', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final StrideSession s = (await tester.runAsync(
        () => StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(script: <SyncFetch>[SyncFetch(const NoChangeSync())]),
        ),
      ))!;
      final ResourceNodeDefinition node =
          s.nodeDefinitionOf(ContentId.unchecked(nodeId))!;
      // The real location painting, not null.
      //
      // This was null, and that made the harness prove the wrong thing: the
      // work backdrop is resolved from the vignette (region x skill, VAWO01),
      // so a null vignette silently fell back to the legacy per-skill plate
      // and every captured frame showed art the app would not show. An
      // evidence harness that does not exercise the shipped path is evidence
      // of nothing.
      final String? vignette = PixelIcons.vignetteFor(ContentId.unchecked(locId));

      Widget stage({required bool active, required bool lock}) => MaterialApp(
        theme: strideTheme(),
        home: Material(
          child: Center(
            child: SizedBox(
              width: 393,
              child: LocationStage(
                locationName: locId,
                vignette: vignette,
                selectedNode: node,
                activityActive: active,
                playToken: null,
                locked: lock,
                lockReason: lock ? 'Needs a pickaxe' : null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(stage(active: false, lock: locked));
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await capture(tester, '${tag}_selected');

      if (locked) return;
      await tester.pumpWidget(stage(active: true, lock: false));
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      for (int f = 0; f < 9; f++) {
        await tester.pump(const Duration(milliseconds: 110));
        await capture(tester, '${tag}_f$f');
      }
    });
  }

  // =========================================================================
  // Equipped loadouts (FMPO02 wave 3, FINAL-01 blocker #2)
  // =========================================================================
  //
  // "Universal equipment claim is unverified by any real screen." Every
  // full-chrome device screen in the reviewed save showed base/Training gear,
  // because nothing in the save had a bronze piece in it — and the only
  // bronze-tier evidence was a test-harness render with blank stat blocks.
  //
  // There is no grant path for a Bronze Chestplate inside a test session, so
  // the honest answer is not a fabricated save: it is the **production
  // widget** fed the same `EquipmentVisualState` the session would hand it.
  // `LocationStage` resolves its strip through `TravelerArt.gatherStripFor`
  // exactly as it does on the device, so what these PNGs show is the shipped
  // path with a loadout the reviewer could not otherwise reach.
  //
  // 361 dp, not 393: that is the width the stage actually gets inside the
  // Adventure card's gutters, so the composition is the one on the phone.
  for (final (
    String skill,
    String nodeId,
    String locId,
    EquipmentVisualState gear,
    String name,
  )
      in <(String, String, String, EquipmentVisualState, String)>[
        // Plate and a bronze pick, in the mine. The headline case: the owner's
        // complaint was "Inventory shows Bronze, Adventure still shows the
        // white shirt".
        (
          'skill.mining',
          'resource_node.copper_seam',
          'location.stonefall_mine',
          EquipmentVisualState(
            armor: EquippedVisualFact(
              itemId: 'item.bronze_chestplate',
              tier: 2,
              toolKind: 'none',
            ),
            tool: EquippedVisualFact(
              itemId: 'item.bronze_pickaxe',
              tier: 2,
              toolKind: 'pickaxe',
            ),
          ),
          'stage_gather_mining_plate_pickbronze',
        ),
        // A jerkin and the steel training axe, in the woods — the mixed case,
        // where the body is armoured and the tool is not.
        (
          'skill.woodcutting',
          'resource_node.oak_stand',
          'location.whispering_woods',
          EquipmentVisualState(
            armor: EquippedVisualFact(
              itemId: 'item.wolfhide_jerkin',
              tier: 2,
              toolKind: 'none',
            ),
            tool: EquippedVisualFact(
              itemId: 'item.training_axe',
              tier: 1,
              toolKind: 'axe',
            ),
          ),
          'stage_gather_woodcutting_jerkin_axesteel',
        ),
        // A coat at the meadow: foraging has no tool, so this is the body
        // class alone, which is the row `gatherStripFor` reads differently.
        (
          'skill.foraging',
          'resource_node.meadow_patch',
          'location.havens_rest',
          EquipmentVisualState(
            armor: EquippedVisualFact(
              itemId: 'item.bearhide_coat',
              tier: 2,
              toolKind: 'none',
            ),
          ),
          'stage_gather_foraging_coat_none',
        ),
      ]) {
    testWidgets('capture $name', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final StrideSession s = (await tester.runAsync(
        () => StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(
            script: <SyncFetch>[SyncFetch(const NoChangeSync())],
          ),
        ),
      ))!;
      final ResourceNodeDefinition node =
          s.nodeDefinitionOf(ContentId.unchecked(nodeId))!;
      expect(node.skill.value, skill, reason: 'the node changed profession');

      // The strip the shipped path selects for this loadout — asserted, not
      // assumed. A null here would mean the render is the base loop wearing
      // the base clothes, which is the exact revert this evidence exists to
      // disprove.
      final GatherStrip strip = TravelerArt.gatherStripFor(skill, gear)!;

      final String? vignette = PixelIcons.vignetteFor(
        ContentId.unchecked(locId),
      );

      Widget stage({required bool active}) => MaterialApp(
        theme: strideTheme(),
        home: Material(
          child: Center(
            child: SizedBox(
              // The width the stage gets inside the Adventure card.
              width: 361,
              child: LocationStage(
                locationName: locId,
                vignette: vignette,
                selectedNode: node,
                activityActive: active,
                playToken: null,
                locked: false,
                equipment: gear,
              ),
            ),
          ),
        ),
      );

      Future<void> decode() => tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });

      // At rest: the armoured idle, standing at the seam.
      await tester.pumpWidget(stage(active: false));
      await decode();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await capture(tester, '${name}_rest');

      // And at the strike — the frame the tool meets the work, which is the
      // one that shows whether the head is bronze or steel.
      await tester.pumpWidget(stage(active: true));
      await decode();
      await tester.pump();
      for (int f = 0; f < strip.strikeFrame; f++) {
        await tester.pump(const Duration(milliseconds: 110));
      }
      await capture(tester, '${name}_strike');
    });
  }
}
