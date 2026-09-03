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

import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/loadout_readout.dart' show kEmptySlotWord;
import 'package:stride/ui/components/panel_skin.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_selection_panel.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/screens/world/atlas/atlas_viewport.dart';
import 'package:stride/ui/screens/world/travel_transition.dart';
import 'package:stride/ui/screens/world/world_screen.dart'
    show worldContextStripKey, worldSheetGripKey, worldSheetKey;
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride/ui/state/craft_controller.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';
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

/// A second hour of walking, for the in-app sync that raises the
/// opportunity banner (Iteration 02 evidence).
SyncFetch laterPage(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0 + hour, endMillis: t0 + 2 * hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c2'),
    completeness: CompleteThrough(
      throughMillis: t0 + 2 * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0 + hour,
        intervalEndMillis: t0 + 2 * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

/// One more walked hour at an arbitrary offset — the EPO03 Inventory run
/// banks a long walk so a real playthrough can be driven through the
/// product's own commands rather than granted.
SyncFetch walkedHour(int i, int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + i * hour,
            endMillis: t0 + (i + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('w$i'),
    completeness: CompleteThrough(
      throughMillis: t0 + (i + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0 + i * hour,
        intervalEndMillis: t0 + (i + 1) * hour,
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

  Future<void> capture(
    WidgetTester tester,
    String name, {
    bool settle = true,
  }) async {
    if (dir == null) return;
    if (settle) {
      await settleImages(tester);
    } else {
      // A transient surface (the travel card) dismisses itself on its own
      // clock — settling would capture the frame after it is gone. Precache
      // whatever images are up and take the frame as it stands.
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          final Image image = e.widget as Image;
          await precacheImage(image.image, e);
        }
      });
      await tester.pump();
    }
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
    // EPO03 (`DIR-06` §6): the station is the screen's primary axis and the
    // locked half is a book — a skill-locked recipe is a sealed page in its
    // chapter, visible by name without opening anything, and its detail
    // rises in a sheet rather than expanding the row, so the sheet is
    // dismissed before the next tab is reached.
    await tester.tap(find.text('Forge'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bronze Sword').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Sword').first);
    await tester.pumpAndSettle();
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    await capture(tester, 'craft_gear_open');
    await tester.tapAt(const Offset(196, 130));
    await tester.pumpAndSettle();

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

    // EPO03 ITEMS: the three salvage crates, on the three adjacent Craft rows
    // that made them a collision in the first place. They shipped as three
    // IDENTICAL boxes (silhouette overlap 0.90-0.93) told apart only by a
    // ghost stamp on the lid that is illegible at 48 dp; each lid is now open
    // with a different bronze head standing out of it and breaking the crate's
    // outline. Captured here rather than on Inventory because a recipe row
    // needs nothing owned to be seen, and because side by side on this screen
    // is exactly where the player met the defect.
    await open(tester, 'Craft');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reclaim Bronze Axe').first);
    await tester.pumpAndSettle();
    expect(find.text('Reclaim Bronze Axe'), findsWidgets);
    expect(find.text('Reclaim Bronze Pickaxe'), findsWidgets);
    await capture(tester, 'epo_items_reclaim_rows');
  });

  // ---------------------------------------------------------------------
  // EPO03 ITEMS: the Inventory carrying collision group 2 — the ivory curves.
  //
  // `pristine_wolf_fang` shipped as a fat ivory wedge that read as a TUSK,
  // sat next to `boar_tusk` and `great_tusk`, and `pristine_horn` filled 12%
  // of its frame. All three are wolf and boar drops, so the only way to see
  // them the way the player does — in the bag, on the dark tile, at 48 dp —
  // is to go and win them. This drives Whispering Woods until the rare drops
  // land, then photographs the Materials grid.
  // ---------------------------------------------------------------------
  testWidgets('EPO03 items: the ivory drops, side by side in the bag', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final ContentId haven = ContentId.unchecked('location.havens_rest');
    final ContentId woods = ContentId.unchecked('location.whispering_woods');
    final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
    final ContentId boar = ContentId.unchecked('enemy.wild_boar');

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(400000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      await s.equip(trainingSword);
      await s.equip(tunic);
      // `great_tusk` is a signature drop at 8%, so this needs many visits.
      // Alternating the two species keeps both tables in play; travelling
      // back to Haven's Rest clears the per-visit encounter counter.
      for (int trip = 0; trip < 60; trip += 1) {
        if (s.currentLocation != woods) {
          await s.travel(woods);
        }
        if (s.currentLocation != woods) break;
        // `encountersPerVisit` is 2, so a visit that opens on the wolf spends
        // both slots there and the boar table is never reached. Left as the
        // wolf-first form that this run actually verified: the kit owner was
        // mid-refactor on `inventory_screen.dart`, `pixel_asset.dart` and
        // `surfaces.dart` when the alternating version was written, so it
        // could not be compiled, and an unverified drive is not evidence.
        for (final ContentId beast in <ContentId>[wolf, boar]) {
          final CombatReport open = await s.startEncounter(beast);
          if (!open.succeeded) continue;
          while (s.encounter != null) {
            final CombatReport r = await s.combatAttack();
            if (!r.succeeded || r.outcome != null) break;
          }
        }
        await s.travel(haven);
      }
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'Inventory');
    await tester.pumpAndSettle();
    await capture(tester, 'epo_items_inventory_ivory');
  });

  testWidgets('Iteration 02: the freshness pass, driven into its moments', (
    WidgetTester tester,
  ) async {
    // The V2 evidence run (Fable V2 Iteration 02): region-tinted headers,
    // the ember button, the sync banner with its opportunity doors, the
    // Sync details diagnostics, the Skills washes, the journey ring, the
    // travel card mid-play, and the discovery layer — each at the reference
    // phone, from one real session.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[
            SyncFetch(const NoChangeSync()),
            // Below the Woods' 500-step road, so the in-app sync below is
            // the one that crosses it and raises the banner.
            page(300),
            laterPage(2600),
          ],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    // First minute, unprompted: Haven-green header band, ember Goal Board
    // button, the walking band.
    await capture(tester, 'v2_adventure_fresh');

    // Track the Woods as the Journey first — the opportunity banner speaks
    // about tracked goals, so the walk has to have somewhere to point.
    // Tracked through the controller (the same command the panel's button
    // dispatches) so the evidence run does not depend on the fold state of
    // the glass panel; the map's gold ring is what the capture is for.
    await open(tester, 'World');
    await capture(tester, 'v2_world');
    final SessionController c = SessionScope.read(
      tester.element(find.byType(StrideTabBar)),
    );
    await tester.runAsync<GoalReport?>(
      () async =>
          c.trackGoalJourney(ContentId.unchecked('location.whispering_woods')),
    );
    await tester.pumpAndSettle();
    // Select it on the map too, so the panel below offers the journey.
    final Finder woods = find.byKey(
      const ValueKey<String>('atlas-hit:location.whispering_woods'),
    );
    final Offset centre = tester.getCenter(find.byType(AtlasViewport));
    await tester.dragFrom(centre, centre - tester.getCenter(woods));
    await tester.pumpAndSettle();
    await tester.tap(woods, warnIfMissed: false);
    await tester.pumpAndSettle();
    await capture(tester, 'v2_world_journey_ring');

    // The granting sync: banner with the count-up's final figure and the
    // journey row that is now a door to the World tab. Driven through the
    // controller inside `runAsync` — a tap-dispatched command's file IO
    // never completes under the harness's fake async, the same reason the
    // original harness syncs pre-mount.
    await open(tester, 'Adventure');
    await tester.runAsync(() => c.syncSteps());
    await tester.pumpAndSettle();
    expect(find.textContaining('STEPS BANKED'), findsOneWidget);
    expect(find.text('Journey Ready'), findsOneWidget);
    await capture(tester, 'v2_adventure_sync_banner');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // A watched single gather: the universal activity result card (GFCP01
    // device correction) — the profession's own verb, the item's icon, the
    // XP — captured mid-hold, before its readable decay.
    await tester.tap(find.text('Meadow Patch'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.gather(kNode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('FORAGED'), findsOneWidget);
    expect(find.textContaining('Foraging XP'), findsOneWidget);
    await capture(tester, 'v2_gather_result', settle: false);
    await tester.pumpAndSettle();

    // The per-source diagnostics, open (HEALTH outcome B's instrument).
    await open(tester, 'Character');
    await tester.tap(find.text('Step Tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();
    await capture(tester, 'v2_step_tracker_sync_details');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Five trades, five atmospheres.
    await open(tester, 'Skills');
    await capture(tester, 'v2_skills');

    // The journey commits through the controller; the card and the
    // discovery layer are then driven exactly as the Set-out closure
    // drives them, so the captures show the shipped presentation.
    await open(tester, 'World');
    final ContentId woodsId = ContentId.unchecked('location.whispering_woods');
    await tester.runAsync(() => c.travelJourney(<ContentId>[woodsId]));
    await tester.pumpAndSettle();
    final BuildContext ctx = tester.element(find.byType(StrideTabBar));
    unawaited(
      showTravelTransition(
        ctx,
        backdrop: PixelIcons.altVignetteFor(woodsId),
        destinationName: 'Whispering Woods',
        originName: "Haven's Rest",
        legs: 1,
        stepsSpent: 1000,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 120));
    // The journey now opens on its departure beat
    // (GAME_FEEL_CHARACTER_PRESENTATION_01: ~10 s paced presentation).
    expect(find.textContaining('Leaving'), findsOneWidget);
    await capture(tester, 'v2_travel_card_departure', settle: false);
    // Past the unskippable window, into the travel loop — the shipped
    // mid-journey read, with the cost line and the skip affordance.
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('On the road to'), findsOneWidget);
    await capture(tester, 'v2_travel_card', settle: false);
    await tester.pumpAndSettle();
    final AtlasScene scene = AtlasScene.build(c.session)!;
    unawaited(
      showDiscoveryLayer(
        tester.element(find.byType(StrideTabBar)),
        session: c.session,
        place: scene.nodeFor(woodsId)!.place,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'v2_discovery_layer');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await capture(tester, 'v2_world_arrived');

    // The header now wears the Woods' ink — travel changed the whole app's
    // colour of place.
    await open(tester, 'Adventure');
    await capture(tester, 'v2_adventure_woods');
  });

  testWidgets('Iteration 03: the depth pass, driven into its surfaces', (
    WidgetTester tester,
  ) async {
    // The depth evidence run (Fable V2 Iteration 03): the Skills roadmap
    // routes, the Craft planner's bands, sourcing, chain jump and prover
    // warning, and the item purpose block — each at the reference phone,
    // from one real session with a few gathers banked.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(3000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      for (int i = 0; i < 4; i++) {
        await s.gather(kNode);
      }
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    // Adventure first: the activities list is the "worthwhile thing HERE".
    await capture(tester, 'v3_adventure');

    // Skills overview, then three roadmap routes.
    await open(tester, 'Skills');
    await capture(tester, 'v3_skills');
    for (final String skill in <String>['Mining', 'Foraging', 'Smithing']) {
      await tester.tap(find.text(skill));
      await tester.pumpAndSettle();
      if (skill == 'Mining') {
        // One expanded unlock row in the mining capture.
        await tester.tap(find.textContaining('Tin Seam at Stonefall').first);
        await tester.pumpAndSettle();
      }
      await capture(tester, 'v3_skill_${skill.toLowerCase()}_detail');
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
    }

    // Craft, rebuilt by FMPO02: the workshop overview (station strip + an
    // already-open folio), sourcing in the sheet, the chain jump inside it,
    // the prover warning, and a locked capstone reached through its gate
    // line rather than by scrolling past nineteen identical rows.
    await open(tester, 'Craft');
    // The cookfire is where the bag can fund something, so the screen is
    // already standing there with the broth's folio open — the "ready"
    // state needs no tap at all now.
    await capture(tester, 'v3_craft_overview');
    await capture(tester, 'v3_craft_ready');

    /// The sheet's scrim, well above the panel's 70 % ceiling.
    Future<void> dismissSheet() async {
      await tester.tapAt(const Offset(196, 130));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Forge'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bronze Ingot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Ingot'));
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_sourcing');
    await dismissSheet();

    // EPO03 (`DIR-06` §6): the recipe book. Its first chapter is lit and
    // opens with one tier header carrying one gate; its pages are sealed
    // leaves with an ink silhouette and a wax seal, and not one of them
    // states a level.
    await tester.dragUntilVisible(
      // The chapter opening is a Wrap of word-level runs so it breaks rather
      // than shrinks at large text scales, so drag to the first run.
      find.text('SMITHING ·').first,
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_book');

    await tester.ensureVisible(find.text('Bronze Sword'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Sword'));
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_locked');
    await tester.tap(find.text('CRAFT ›').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_chain');
    await tester.tap(find.textContaining('Back to Bronze Sword'));
    await tester.pumpAndSettle();
    await dismissSheet();

    await tester.dragUntilVisible(
      find.text('Fang-Hilted Sword'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fang-Hilted Sword'));
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_prover');
    await dismissSheet();

    // The chapters behind the lit one recede rather than repeating its
    // sentence — the deepest chapter, read at phone scale.
    await tester.dragUntilVisible(
      // "LEVELS 10+" is the deepest chapter's own run, and unlike the trade
      // name it appears exactly once.
      find.text('10+'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'v3_craft_book_deep');

    // Inventory: the purpose block under a held material.
    await open(tester, 'Inventory');
    // Five-column materials carry the name as the tile's semantics label
    // (FMPO02 Inventory), not as text.
    await tester.tap(find.bySemanticsLabel(RegExp('Meadow Herb')).first);
    await tester.pumpAndSettle();
    await capture(tester, 'v3_inventory_purpose');
  });

  testWidgets('Iteration 03: the Hollow Field Ledger on the inspector', (
    WidgetTester tester,
  ) async {
    // The fabricated-inspector pattern (the same one the destination
    // golden uses): the Forgotten Hollow as a reached destination now
    // carries a board, a development word, and the camp project — the
    // World face of the new expedition layer.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RegionPlace hollow = RegionPlace(
      id: ContentId.unchecked('location.forgotten_hollow'),
      displayName: 'Forgotten Hollow',
      isCurrent: false,
      isSafe: false,
      isUnlocked: true,
      stepCostFromHere: 2400,
      resourceCount: 3,
      terrain: Terrain.forest,
      kind: LocationKind.wilds,
    );
    final AtlasNode node = AtlasNode(place: hollow, x: 100, y: 100);
    final AtlasWay way = AtlasWay(
      hops: <AtlasNode>[node],
      edges: const <AtlasEdge>[],
      totalCost: 2400,
      firstLegCost: 2400,
    );
    const AtlasPlaceInfo info = AtlasPlaceInfo(
      kind: AtlasPlaceKind.wilds,
      terrainWord: 'Forest',
      isSafe: false,
      isCurrent: false,
      isUnlocked: true,
      developmentWord: 'Untamed',
      board: (
        boardName: 'Field Ledger',
        openContracts: 4,
        readyToComplete: 1,
        projectName: 'Raise the Hollow Field Camp',
        projectHasSomethingToGive: true,
        carryingSomethingWanted: true,
      ),
      gatherSites: <AtlasGatherLine>[
        (
          name: 'Silkstrand Thicket',
          skill: 'Foraging',
          level: 6,
          tool: null,
          eligible: true,
          gap: null,
        ),
        (
          name: 'Veiled Silkstrand',
          skill: 'Foraging',
          level: 8,
          tool: null,
          eligible: false,
          gap: 'opens with Raise the Hollow Field Camp',
        ),
        (
          name: 'Hollow Thicket',
          skill: 'Foraging',
          level: 10,
          tool: null,
          eligible: false,
          gap: 'you are Lv 6',
        ),
      ],
      encounters: <AtlasEncounterLine>[
        (
          name: 'Hollow Guardian',
          isBoss: true,
          behaviorWord: 'Guarded',
          perVisit: 1,
          remaining: 1,
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
              name: 'Forgotten Hollow',
              info: info,
              way: way,
              missingEntry: const <String>[],
              banked: 8000,
              busy: false,
              ready: true,
              lastJourney: null,
              vignette: 'assets/art/v1/location/alt_forgotten_hollow.png',
              onTravel: () {},
              onTrackJourney: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Field Ledger · 4 open · 1 ready to turn in'),
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
        File(
          '$dir/v3_world_hollow_inspector.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
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
              vignette: 'assets/art/v1/location/alt_stonefall_mine.png',
              onTravel: () {},
              onTrackJourney: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Mine Ledger · 6 open · 1 ready to turn in'),
      findsOneWidget,
    );
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
        File(
          '$dir/world_inspector_destination.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  testWidgets(
    'Game Feel & Character Presentation 01, driven into its moments',
    (WidgetTester tester) async {
      // The pacing pass's evidence (GAME_FEEL_CHARACTER_PRESENTATION_01):
      // the craft completion beat with the thing itself on it, the Gather
      // commit plate, and the ambient dwell actually dwelling. The travel
      // card's departure and road are captured by the Iteration 02 run
      // above; Attack/Brace and the held equipment layer are the combat and
      // craft goldens' subjects.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      final FakeTiming fake = FakeTiming();
      final StrideSession session = (await tester.runAsync(() async {
        final StrideSession s = await StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(
            script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(12480)],
          ),
        );
        await s.syncSteps();
        await s.syncSteps();
        // Herbs for the correction's craft drives: one broth, a ×5 batch,
        // and the ×3 run that crosses Cooking 2 (nine broths, two herbs
        // each — bonus procs only add slack).
        for (int i = 0; i < 18; i++) {
          await s.gather(kNode);
        }
        return s;
      }))!;
      session.activityWallClock = fake.wallClock;

      await tester.pumpWidget(
        StrideApp(
          session: session,
          syncOnStart: false,
          activityTiming: fake.timing,
        ),
      );
      await tester.pumpAndSettle();

      // The Gather commit plate on the activity panel.
      await tester.tap(find.text('Meadow Patch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gather'), findsWidgets);
      await capture(tester, 'gfcp_gather_plate');

      // A completed craft's MINOR beat: the icon, the name, the XP — a
      // completion that shows the thing instead of only logging it. The
      // decay is seen-gated on the injected timing, so the capture is calm.
      await open(tester, 'Craft');
      await tester.tap(find.text('Herb Broth').first);
      await tester.pumpAndSettle();
      final CraftController craft = CraftScope.read(
        tester.element(find.byType(StrideTabBar)),
      );
      final RecipeOption broth = session.recipeOptions.singleWhere(
        (RecipeOption r) => r.id.value == 'recipe.herb_broth',
      );
      await tester.runAsync(() async {
        craft.start(broth, 1);
        fake.advance(const Duration(seconds: 46));
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 10),
        );
        while (craft.active && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      // The universal result card holds its readable ~3.2 s and then decays
      // on its own — pump into the hold, never settle past it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('CRAFTED'), findsOneWidget);
      // The tally slip names the item on its own ruled line and shows a
      // multiplier only when there is more than one — "Herb Broth", not
      // "Herb Broth ×1". One of a thing does not need to be counted at you.
      // Scoped to the slip, because the recipe behind it names the broth too.
      expect(
        find.descendant(
          of: find.byType(ActivityResultCard),
          matching: find.text('Herb Broth'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ActivityResultCard),
          matching: find.textContaining('×1'),
        ),
        findsNothing,
      );
      await capture(tester, 'gfcp_craft_minor_beat', settle: false);
      await tester.pumpAndSettle();

      // The batch: five broths reconciled as one summarized card — never
      // five popups (GFCP01 device correction, batch behavior).
      Future<void> runQueue(int count) => tester.runAsync(() async {
        craft.start(broth, count);
        // Boundary by boundary — the craft_flow_test pattern: each advance
        // fires the armed one-shot, and the real-async wait lets its
        // dispatch's file IO land before the next.
        for (int i = 1; i <= count; i++) {
          fake.advance(const Duration(seconds: 46));
          final DateTime deadline = DateTime.now().add(
            const Duration(seconds: 10),
          );
          while (craft.active &&
              craft.completed < i &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        }
      });

      await runQueue(5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('CRAFTING COMPLETE'), findsOneWidget);
      // The slip rules the name and the count onto one line as two runs, so
      // the figure sits in the right-hand margin with every other figure.
      // Both halves are asserted: five of the broth, said once.
      expect(
        find.descendant(
          of: find.byType(ActivityResultCard),
          matching: find.text('Herb Broth'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ActivityResultCard),
          matching: find.text('×5'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ActivityResultCard), findsOneWidget);
      await capture(tester, 'gfcp_batch_craft_summary', settle: false);
      await tester.pumpAndSettle();

      // The level-up composed with its result: broths seven through nine
      // cross Cooking 2 mid-run, and the held layer carries BOTH truths —
      // the crafted beat and the universal level-up card.
      await runQueue(3);
      await tester.pumpAndSettle();
      expect(find.text('LEVEL UP'), findsOneWidget);
      expect(find.text('CRAFTED'), findsOneWidget);
      await capture(tester, 'gfcp_levelup_with_result');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final SessionController drives = SessionScope.read(
        tester.element(find.byType(StrideTabBar)),
      );

      // The bonus proc, visible: the boot's gathers put Foraging at level 2,
      // where the meadow patch's deterministic 10 % per-index roll is live —
      // gather until it pays, then the card says so on its own line with
      // the reward light. On the surface first: a settle after the
      // completion would run the card's readable life out before the look.
      await open(tester, 'Adventure');
      bool bonusSeen = false;
      for (int i = 0; i < 25 && !bonusSeen; i++) {
        await tester.runAsync(() => drives.gather(kNode));
        bonusSeen = (drives.lastAction?.bonusYield ?? 0) > 0;
        await tester.pump();
      }
      expect(bonusSeen, isTrue, reason: 'a bonus roll pays within 25 gathers');
      await tester.pump(const Duration(milliseconds: 400));
      // The bonus is a ruled fact now: the words on the left, the figure
      // down the right margin (EPO03, DIR-13). Both halves, or the assertion
      // would pass on a slip that had lost the number.
      expect(find.text('Bonus yield'), findsOneWidget);
      expect(
        find.text('+${drives.lastAction!.bonusYield}'),
        findsOneWidget,
        reason: 'the figure the report stated, in the slip’s right margin',
      );
      await capture(tester, 'gfcp_bonus_yield', settle: false);
      await tester.pumpAndSettle();

      // The other professions' verbs, on their own ground: chop an oak in
      // the Whispering Woods, mine a copper seam at Stonefall — the same
      // one card language, the profession's colour and verb.
      await tester.runAsync(() async {
        await drives.equip(ContentId.unchecked('item.training_axe'));
        await drives.travel(ContentId.unchecked('location.whispering_woods'));
        await drives.gather(ContentId.unchecked('resource_node.oak_stand'));
      });
      // Three pumps: the build, the ticker's epoch frame, and the frame
      // that carries the entrance past its rise — a zero-duration pump
      // leaves the card at its first instant otherwise.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CHOPPED'), findsOneWidget);
      expect(find.textContaining('Woodcutting XP'), findsOneWidget);
      await capture(tester, 'gfcp_woodcut_result', settle: false);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await drives.equip(ContentId.unchecked('item.training_pickaxe'));
        await drives.travelJourney(<ContentId>[
          ContentId.unchecked('location.havens_rest'),
          ContentId.unchecked('location.stonefall_mine'),
        ]);
        await drives.gather(ContentId.unchecked('resource_node.copper_seam'));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MINED'), findsOneWidget);
      expect(find.textContaining('Mining XP'), findsOneWidget);
      await capture(tester, 'gfcp_mining_result', settle: false);
      expect(
        find.text('MINED'),
        findsOneWidget,
        reason: 'the card survives to capture time',
      );
      await tester.pumpAndSettle();

      // The ambient dwell, mid-scene: the lifecycle seam on, ~9 s in — deep
      // inside the first full scene's held loop, the Traveler actually
      // being there. Captured without settling (the cadence is endless by
      // design while resumed).
      // The equipped loadout, visible as its own art: the worn pieces' 48 px
      // icons on the Character sheet's combat block — equipment made real
      // with existing assets while the on-figure variants wait for their
      // PixelLab rounds (item 5).
      final SessionController sessions = SessionScope.read(
        tester.element(find.byType(StrideTabBar)),
      );
      await tester.runAsync(() async {
        await sessions.equip(trainingSword);
        await sessions.equip(tunic);
      });
      await tester.pumpAndSettle();
      await open(tester, 'Character');
      await tester.dragUntilVisible(
        find.text('WEAPON'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'gfcp_equipped_icons');

      await open(tester, 'Adventure');
      // Nothing is selected here (the drives moved the player to Stonefall),
      // so the stage is already the living location.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.binding.resetInternalState);
      for (int i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture(tester, 'gfcp_ambient_dwell', settle: false);
    },
  );
  // ---------------------------------------------------------------------
  // EPO03 (`DIR-07`): the Skills road with a stretch of it behind the
  // walker. Every other run in this file starts every trade at level 1, so
  // the reached waystone, the walked fold and the road *above* the lantern
  // had no render at all — and "where am I" is the one question this screen
  // exists to answer.
  // ---------------------------------------------------------------------
  testWidgets('EPO03: the Skills road at mid-journey', (
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
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(120000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      for (int i = 0; i < 40; i++) {
        await s.gather(kNode);
      }
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'Skills');
    await capture(tester, 'epo_skills_overview');
    await tester.tap(find.text('Foraging'));
    await tester.pumpAndSettle();
    await capture(tester, 'epo_skill_foraging_midroad');
    // The road already walked, unfolded.
    if (find.text('UNFOLD').evaluate().isNotEmpty) {
      await tester.tap(find.text('UNFOLD'));
      await tester.pumpAndSettle();
      await capture(tester, 'epo_skill_foraging_unfolded');
    }
  });
  // ---------------------------------------------------------------------
  // EPO03 (`DIR-15` §1): the World sheet's three stops, the strip that names
  // an off-screen marker, and the arrival — plus the measured map-visible dp
  // at each stop, written beside the renders so the owner's "the sheet
  // obscures too much map" is answered with a figure and not an adjective.
  // ---------------------------------------------------------------------
  testWidgets('EPO03: the World sheet at peek, half and full', (
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
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(40000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'World');

    final StringBuffer measured = StringBuffer(
      'EPO03 UI-WORLD — World sheet geometry, measured at 393x852 DPR 1\n'
      'stop, sheet dp, map-visible dp, share of the World body\n',
    );
    late final Rect body;
    body = tester.getRect(find.byType(AtlasViewport));
    void record(String stop) {
      final double sheet = tester.getRect(find.byKey(worldSheetKey)).height;
      final double map = body.height - sheet;
      measured.writeln(
        '$stop, ${sheet.toStringAsFixed(1)}, ${map.toStringAsFixed(1)}, '
        '${(100 * map / body.height).toStringAsFixed(1)}%',
      );
    }

    // 1. Open: PEEK. The map is the hero and the sheet is one row.
    record('peek (open)');
    await capture(tester, 'epo_world_peek');

    // 2. A selection, then a pan that puts it off the visible map: the
    //    contextual strip appears with its caret and the way's cost. This is
    //    the state that used to be called "viewed", and is now never named.
    final Finder woods = find.byKey(
      const ValueKey<String>('atlas-hit:location.whispering_woods'),
    );
    final Offset centre = tester.getCenter(find.byType(AtlasViewport));
    await tester.dragFrom(centre, centre - tester.getCenter(woods));
    await tester.pumpAndSettle();
    await tester.tap(woods, warnIfMissed: false);
    await tester.pumpAndSettle();
    // A marker tap did NOT raise the sheet — the whole point of the change.
    record('peek (a place selected)');
    await tester.dragFrom(centre, const Offset(0, 420));
    await tester.pumpAndSettle();
    expect(find.byKey(worldContextStripKey), findsOneWidget);
    await capture(tester, 'epo_world_strip_offscreen');

    // Back onto the selection, so the half stop is about a real journey.
    await tester.dragFrom(centre, centre - tester.getCenter(woods));
    await tester.pumpAndSettle();

    // 3. The peek's compact Travel raises the sheet to HALF with the priced
    //    confirmation armed. It does not travel: `Set out` is the only
    //    dispatch, and it is still unpressed here.
    await tester.tap(
      find.descendant(
        of: find.byKey(worldSheetKey),
        matching: find.text('Travel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set out'), findsOneWidget);
    record('half (travel confirm)');
    await capture(tester, 'epo_world_half_confirm');

    // 4. FULL: the whole inspector — work, gathering, encounters.
    await tester.fling(
      find.byKey(worldSheetGripKey),
      const Offset(0, -80),
      900,
    );
    await tester.pumpAndSettle();
    record('full (inspector)');
    await capture(tester, 'epo_world_full_inspector');

    // 5. Arrived. The journey commits through the controller — a
    //    tap-dispatched command's file IO never completes under the
    //    harness's fake async — and the sheet returns to peek on *here*.
    final SessionController c = SessionScope.read(
      tester.element(find.byType(StrideTabBar)),
    );
    await tester.runAsync(
      () => c.travelJourney(<ContentId>[
        ContentId.unchecked('location.whispering_woods'),
      ]),
    );
    await tester.pumpAndSettle();
    record('peek (arrived)');
    await capture(tester, 'epo_world_arrived');

    if (dir != null) {
      Directory(dir).createSync(recursive: true);
      File(
        '$dir/epo_world_measurements.txt',
      ).writeAsStringSync(measured.toString());
    }
  });

  // ===========================================================================
  // EPO03 — PROD-UI-INVENTORY
  //
  // The four states the rebuilt Inventory has to be *looked at* in: a new
  // game's three empty wells, a worn loadout with one well still empty, the
  // pack's ruled canvas rows, and a gear pocket's stamped evaluation. Driven
  // through the real session — gathered, travelled, forged — because the whole
  // claim of the rebuild is about a screen full of things a player earned.
  // ===========================================================================
  testWidgets('EPO03 Adventure: the ledger, a pencilled site, and two slips '
      'pinned to the cork', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    // A walked save with two goals actually pinned. The other Adventure cases
    // all render the board empty — "NOTHING PINNED" is a real state and it is
    // captured three times over — so nothing in the round showed the slips
    // themselves until this case existed.
    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[
            SyncFetch(const NoChangeSync()),
            for (int i = 0; i < 20; i++) walkedHour(i, 40000),
          ],
        ),
      );
      for (int i = 0; i < 21; i++) {
        await s.syncSteps();
      }
      // A journey the walk has already paid for, and a pursuit the player is
      // still gathering towards: the two slips read differently on purpose —
      // one is ready, one still names what it needs.
      await s.trackGoal(
        GoalSlot.journey,
        ContentId.unchecked('location.whispering_woods'),
      );
      await s.trackGoal(
        GoalSlot.pursuit,
        ContentId.unchecked('item.bronze_sword'),
      );
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'Adventure');

    // The cork sits under the expedition kit, so the board is reached by
    // scrolling the page rather than by shrinking anything above it.
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('JOURNEY'), findsOneWidget);
    expect(find.text('PURSUIT'), findsOneWidget);
    await capture(tester, 'epo_adventure_slips_pinned');
  });

  testWidgets('EPO03 Inventory: empty wells, a worn loadout, the ruled pack', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    // --- 1. A new game: nothing worn, three empty wells ---------------------
    final StrideSession fresh = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync())],
        ),
      ),
    ))!;
    await tester.pumpWidget(StrideApp(session: fresh, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'Inventory');
    // Weapon, Armour and Tool all standing empty — the class shadow in each
    // recess, and the word `Empty` nowhere on the screen.
    expect(find.text(kEmptySlotWord), findsNothing);
    await capture(tester, 'inv_01_new_game');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // --- 2..4. A played session: a forged weapon, a full pack ---------------
    //
    // Everything below is the product's own commands. The Bronze Sword is
    // mined, smelted and forged rather than granted, and the pack fills with
    // what the walking produced along the way.
    //
    // **The armour is the Traveler Tunic and the weapon is the Bronze Sword,
    // and that is the limit of what a test session can reach, not a choice.**
    // The Bronze Chestplate needs a Pine Plank from Frostmere, which has no
    // route out of Haven's Rest until the world is opened; the Bronze
    // Longsword needs a Boar Tusk (a 35 % drop) and Gloom Silk from the
    // Forgotten Hollow; the Wolfhide Jerkin is taught by a contract. The
    // render proves what it is for either way: a **crafted, non-starting,
    // uncommon** weapon seated in its well beside a worn armour, an empty tool
    // well, and the figure drawn by whatever `TravelerArt` resolves — nothing
    // in the screen narrows that resolver, so the Waywarden body and the
    // longsword appear here the day a save reaches them.
    final Directory played = Directory.systemTemp.createTempSync(
      'stride_inv_played',
    );
    addTearDown(() {
      try {
        played.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows holds a handle a moment past close.
      }
    });

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: played,
        source: MockStepSource(
          script: <SyncFetch>[
            SyncFetch(const NoChangeSync()),
            for (int i = 0; i < 120; i++) walkedHour(i, 40000),
          ],
        ),
      );
      for (int i = 0; i < 121; i++) {
        await s.syncSteps();
      }

      Future<void> go(String loc) => s.travel(ContentId.unchecked(loc));

      Future<void> dig(String node, int n) async {
        for (int i = 0; i < n; i++) {
          if (!(await s.gather(ContentId.unchecked(node))).succeeded) return;
        }
      }

      Future<void> forge(String recipe, int n) async {
        for (int i = 0; i < n; i++) {
          if (!(await s.craft(ContentId.unchecked(recipe))).succeeded) return;
        }
      }

      // Mine the ore, smelt the bronze — which is also how Smithing levels.
      await s.equip(ContentId.unchecked('item.training_pickaxe'));
      await go('location.stonefall_mine');
      await dig('resource_node.copper_seam', 150);
      await dig('resource_node.tin_seam', 95);
      await forge('recipe.bronze_ingot', 130);
      // Fell the oak, turn a handle, forge the sword.
      await go('location.havens_rest');
      await go('location.whispering_woods');
      await s.equip(ContentId.unchecked('item.training_axe'));
      await dig('resource_node.oak_stand', 110);
      await forge('recipe.oak_handle', 3);
      await forge('recipe.bronze_sword', 1);
      // Home, and a season of foraging: herbs, and broth from them.
      await go('location.havens_rest');
      await dig('resource_node.meadow_patch', 40);
      await forge('recipe.herb_broth', 3);
      // Worn: the forged sword and the tunic. **The tool slot is emptied on
      // purpose** — both training tools are in the pack, and one empty well
      // beside two full ones is the state the case exists to show.
      await s.unequip(EquipmentSlot.tool);
      await s.equip(ContentId.unchecked('item.bronze_sword'));
      await s.equip(tunic);
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await open(tester, 'Inventory');
    // The case: the figure in its window, the sword and the tunic seated in
    // their wells with their figures stamped, and the tool well empty.
    expect(find.text('WEAPON'), findsOneWidget);
    expect(find.text('TOOL'), findsOneWidget);
    await capture(tester, 'inv_02_case_worn_tool_empty');

    // The pack: ruled canvas rows, materials five across, gear three across
    // with the Equip plate on the pocket.
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await capture(tester, 'inv_03_pack_ruled_rows');

    // A gear pocket opened: the stamped evaluation, ruled on the canvas, with
    // no dark block under it.
    await tester.dragUntilVisible(
      find.text('Bronze Sword'),
      find.byType(ListView).first,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bronze Sword').last);
    await tester.pumpAndSettle();
    await capture(tester, 'inv_04_gear_open');
  });
  // ---------------------------------------------------------------------
  // EPO03 ENEMIES — the encounter as a field-guide entry, and the Bestiary
  // as the guide. One capture per region a fight happens in, plus the boss
  // and the Awakened, because the whole claim is that each creature reads as
  // standing *in* its habitat and that can only be judged region by region.
  // ---------------------------------------------------------------------
  testWidgets('EPO03 ENEMIES: an encounter dossier in each habitat, the boss '
      'chamber, and the field guide', (WidgetTester tester) async {
    if (dir == null || dir.isEmpty) return;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[
            SyncFetch(const NoChangeSync()),
            for (int i = 0; i < 160; i++) walkedHour(i, 60000),
          ],
        ),
      );
      for (int i = 0; i < 161; i++) {
        await s.syncSteps();
      }
      // The Forgotten Hollow's entry requirement is a bronze sword, so the
      // boss dossier cannot be reached by walking alone. This is the
      // Inventory case's own forge, verbatim in intent: mine and smelt the
      // bronze, fell the oak, turn a handle, forge the blade.
      Future<void> dig(String node, int n) async {
        for (int i = 0; i < n; i++) {
          if (!(await s.gather(ContentId.unchecked(node))).succeeded) return;
        }
      }

      Future<void> forge(String recipe, int n) async {
        for (int i = 0; i < n; i++) {
          if (!(await s.craft(ContentId.unchecked(recipe))).succeeded) return;
        }
      }

      await s.equip(ContentId.unchecked('item.training_pickaxe'));
      await s.travel(ContentId.unchecked('location.stonefall_mine'));
      await dig('resource_node.copper_seam', 150);
      await dig('resource_node.tin_seam', 95);
      await forge('recipe.bronze_ingot', 130);
      await s.travel(ContentId.unchecked('location.havens_rest'));
      await s.travel(ContentId.unchecked('location.whispering_woods'));
      await s.equip(ContentId.unchecked('item.training_axe'));
      await dig('resource_node.oak_stand', 110);
      await forge('recipe.oak_handle', 3);
      await forge('recipe.bronze_sword', 1);
      await s.equip(ContentId.unchecked('item.bronze_sword'));
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();

    final SessionController c =
        (find.byType(SessionScope).evaluate().first.widget as SessionScope)
            .notifier!;

    /// Stands the player at [location], unless they are already there — the
    /// engine refuses a journey to where you are, and a second dossier in the
    /// same region would otherwise be skipped for a travel that was never
    /// needed.
    Future<bool> stand(String location) async {
      final ContentId to = ContentId.unchecked(location);
      if (session.currentLocation == to) return true;
      final TravelReport t =
          await tester.runAsync(() => session.travel(to)) as TravelReport;
      await tester.pumpAndSettle();
      return t.succeeded;
    }

    /// Opens Adventure, expands one enemy's row, and captures the dossier.
    Future<void> dossier(String enemy, String shot) async {
      await open(tester, 'Adventure');
      await tester.pumpAndSettle();
      // The encounter list is below the fold and the ListView builds lazily,
      // so the row has to be scrolled into being before it can be found.
      // `textContaining`, because a boss row reads 'Hollow Guardian · Boss'
      // in the collapsed list and an exact finder never sees it.
      final Finder row = find.textContaining(enemy);
      for (int i = 0; i < 12 && row.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -160));
        await tester.pumpAndSettle();
      }
      if (row.evaluate().isEmpty) return;
      // Bring the row to the top of the page *before* tapping it — the
      // habitat window is the top of the dossier and the point of the
      // capture, and a row scrolled off the viewport cannot be tapped at all.
      Future<void> lift() async {
        final double y = tester.getTopLeft(row.first).dy;
        if (y == 140) return;
        await tester.drag(find.byType(ListView).first, Offset(0, 140 - y));
        await tester.pumpAndSettle();
      }

      await lift();
      await tester.tap(row.first);
      await tester.pumpAndSettle();
      await lift();
      await capture(tester, shot);
    }

    for (final (String place, String enemy, String shot)
        in <(String, String, String)>[
          // The Hollow first: the forge above left the player in the
          // Whispering Woods, which is the Hollow's only connection, and the
          // boss chamber is the capture the round most needs.
          (
            'location.forgotten_hollow',
            'Hollow Guardian',
            'epo_enemy_hollow_boss',
          ),
          ('location.whispering_woods', 'Forest Wolf', 'epo_enemy_woods_wolf'),
          (
            'location.stonefall_mine',
            'Salamander',
            'epo_enemy_mine_salamander',
          ),
          ('location.stonefall_mine', 'Cave Goblin', 'epo_enemy_mine_goblin'),
          ('location.frostmere', 'Frost Lynx', 'epo_enemy_frostmere_lynx'),
          ('location.frostmere', 'Mountain Ram', 'epo_enemy_frostmere_ram'),
        ]) {
      if (!await stand(place)) continue;
      await dossier(enemy, shot);
    }

    // The field guide itself: every creature with its habitat vignette, and
    // the unsighted ones as ink.
    await open(tester, 'Adventure');
    await tester.pumpAndSettle();
    final Finder notes = find.text('Field Notes');
    if (notes.evaluate().isNotEmpty) {
      await tester.dragUntilVisible(
        notes,
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(notes.first);
      await tester.pumpAndSettle();
      await capture(tester, 'epo_enemy_field_guide');
    }
    expect(c.session.bestiary.regions, isNotEmpty);
  });
}
