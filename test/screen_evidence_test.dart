// The screen-evidence harness (PLAYABLE_POLISH_01): the real app at phone
// width, driven into the states a polish pass needs to *look at* — a gear
// recipe open on Craft, the Inventory with equipment, the Character tab —
// and written to `SCREEN_EVIDENCE_DIR` when that variable is set. Silent
// without it, and then a mount-and-drive smoke test. The same pattern as
// `stage_evidence_test.dart` and `board_reward_layer_test.dart`, for the
// same reason (MISTAKES.md M-06): a golden is regression evidence between
// revisions; this is for seeing.
//
// Usage:
//   SCREEN_EVIDENCE_DIR=/tmp/screens flutter test test/screen_evidence_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_selection_panel.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);
  final String? dir = Platform.environment['SCREEN_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_screens'));
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
        final Image image = e.widget as Image;
        await precacheImage(image.image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (dir == null) return;
    await settleImages(tester);
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

  Future<void> open(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(StrideTabBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the polished surfaces, driven into their telling states', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(12480)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      for (int i = 0; i < 3; i++) {
        await s.gather(kNode);
      }
      await s.equip(trainingSword);
      await s.equip(tunic);
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await capture(tester, 'adventure');

    await open(tester, 'Inventory');
    await capture(tester, 'inventory');

    await open(tester, 'Craft');
    await tester.tap(find.text('Bronze Sword').first);
    await tester.pumpAndSettle();
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    await capture(tester, 'craft_gear_open');

    await open(tester, 'Character');
    await capture(tester, 'character');
    // The foot of the sheet: the owner's playtest controls, and the
    // confirmation they open (`DECISIONS/0025`).
    await tester.dragUntilVisible(
      find.text('Reset walking baseline'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a fresh playtest'));
    await tester.pumpAndSettle();
    expect(find.text('START A FRESH PLAYTEST?'), findsOneWidget);
    await capture(tester, 'character_playtest_confirm');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open(tester, 'Skills');
    await capture(tester, 'skills');
  });

  testWidgets('the World inspector, a reached destination selected', (
    WidgetTester tester,
  ) async {
    // The Fable V2 inspector states the default golden cannot show — a
    // *destination* with its vignette variant, its Work line, the
    // carry-wanted sentence, an out-of-reach gather line's gap, and the
    // journey controls — over a fabricated place, which is exactly what
    // `AtlasInspector` being a pure widget is for.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RegionPlace stonefall = RegionPlace(
      id: ContentId.unchecked('location.stonefall_mine'),
      displayName: 'Stonefall Mine',
      isCurrent: false,
      isSafe: false,
      isUnlocked: true,
      stepCostFromHere: 1400,
      resourceCount: 4,
      terrain: Terrain.foothills,
      kind: LocationKind.worksite,
    );
    final AtlasNode node = AtlasNode(place: stonefall, x: 100, y: 100);
    final AtlasWay way = AtlasWay(
      hops: <AtlasNode>[node],
      edges: const <AtlasEdge>[],
      totalCost: 1400,
      firstLegCost: 1400,
    );
    const AtlasPlaceInfo info = AtlasPlaceInfo(
      kind: AtlasPlaceKind.worksite,
      terrainWord: 'Foothills',
      isSafe: false,
      isCurrent: false,
      isUnlocked: true,
      developmentWord: 'Strained',
      board: (
        boardName: 'Mine Ledger',
        openContracts: 6,
        readyToComplete: 1,
        projectName: 'Reopen the Stonefall Lift',
        projectHasSomethingToGive: true,
        carryingSomethingWanted: true,
      ),
      gatherSites: <AtlasGatherLine>[
        (
          name: 'Copper Seam',
          skill: 'Mining',
          level: 1,
          tool: 'Pickaxe',
          eligible: true,
          gap: null,
        ),
        (
          name: 'Deep Tin Seam',
          skill: 'Mining',
          level: 4,
          tool: 'Pickaxe',
          eligible: false,
          gap: 'you are Lv 2',
        ),
        (
          name: 'Hardened Copper Seam',
          skill: 'Mining',
          level: 5,
          tool: 'Pickaxe',
          eligible: false,
          gap: 'opens with Reopen the Stonefall Lift',
        ),
      ],
      encounters: <AtlasEncounterLine>[
        (
          name: 'Scree Crawler',
          isBoss: false,
          behaviorWord: 'Steady',
          perVisit: 2,
          remaining: 2,
          isCurrentLocation: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: const Color(0xFF14120F),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AtlasInspector(
              name: 'Stonefall Mine',
              info: info,
              way: way,
              missingEntry: const <String>[],
              banked: 12320,
              busy: false,
              ready: true,
              lastJourney: null,
              vignette:
                  'assets/art/v1/location/alt_stonefall_mine.png',
              onTravel: () {},
              onTrackJourney: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mine Ledger · 6 open · 1 ready to turn in'),
        findsOneWidget);
    expect(
      find.textContaining('Deep Tin Seam · Mining Lv 4 · Pickaxe — you are'),
      findsOneWidget,
    );

    if (dir != null) {
      await settleImages(tester);
      await tester.runAsync(() async {
        final ui.Image image = await captureImage(
          find.byType(MaterialApp).evaluate().single,
        );
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        Directory(dir).createSync(recursive: true);
        File('$dir/world_inspector_destination.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
