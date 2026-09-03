/// The World Atlas — a pannable surface with real targets, and the one panel
/// under it that may offer a journey.
///
/// ## The risks these cover, named before the work
///
/// - **A place visible and dead.** A marker drawn beyond the first viewport's
///   worth of world that cannot be tapped (the OverflowBox-inside-Transform
///   hit-test defect, found while building this). Every place is selected by
///   panning to it and tapping, the way a player does.
/// - **A control with no command behind it.** A Travel button for a place with
///   no road from here, or one enabled when the engine would refuse. Asserted
///   from two states — affordable and not — so a literal cannot satisfy it.
/// - **The map as a joystick.** A drag on the atlas must move only the camera:
///   no travel dispatched, no steps spent, no location changed.
/// - **Motion that does not stop.** The pulse under the current location must
///   run only while the app is resumed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/components/screen_header.dart' show formatSteps;
import 'package:stride/ui/screens/world/atlas/atlas_layers.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_selection_panel.dart';
import 'package:stride/ui/screens/world/atlas/atlas_viewport.dart';
import 'package:stride/ui/screens/world/world_screen.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

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

Finder hit(String id) => find.byKey(ValueKey<String>('atlas-hit:$id'));

/// The shipped layout's own scale, read from the file the app ships rather
/// than written down here. Every zoom in this suite derives from it.
final int shippedAtlasScale =
    (jsonDecode(
              File(
                'assets/content/v1/atlas/atlas_layout.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>)['scale']!
        as int;

/// The range for the shipped `scale: 4` master-painting layout — derived
/// exactly as the viewport derives it: floor 1/scale, opening 2/scale, max
/// 4/scale. Taken from the SHIPPED layout's own scale rather than a literal,
/// because the correction round moved the continent from scale 4 to scale 6
/// and a test that pins 0.25/0.5/1 is testing the number, not the model.
final AtlasZoom zooms = AtlasZoom.forScale(shippedAtlasScale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_atlas'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A real session over a temp save, at a phone viewport. Same shape as
  /// `phase1_ui_test.dart`, and for the same reasons: the World screen is
  /// driven by projections a fake would have to reimplement.
  Future<StrideSession> boot(WidgetTester tester, {int banked = 0}) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    // A new game's first authorised sync is its baseline (DECISIONS/0019):
    // the store has nothing at install, one sync retires that nothing, and
    // only what is synced afterwards is spendable — so the funding page comes
    // second.
    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[
            SyncFetch(const NoChangeSync()),
            if (banked > 0) page(banked),
          ],
        ),
      ),
    ))!;
    await tester.runAsync(() => session.syncSteps());
    expect(session.baselinePending, isFalse);
    expect(session.usableEnergy, 0);
    if (banked > 0) await tester.runAsync(() => session.syncSteps());
    return session;
  }

  /// The World screen alone, under a scope — no shell, no header, so the
  /// viewport's own geometry is what is measured.
  Future<SessionController> pumpWorld(
    WidgetTester tester,
    StrideSession session,
  ) async {
    final SessionController controller = SessionController(session);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SessionScope(
          controller: controller,
          child: const Scaffold(body: WorldScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Raises the sheet from its peek stop to HALF, the way a player does: one
  /// tap on the grip.
  ///
  /// The World sheet opens at PEEK now (DIR-15 §1, the owner's "the sheet
  /// obscures too much map") and **a marker tap never raises it**, so every
  /// assertion about the inspector's own words has to say which stop it is
  /// reading at. HALF carries the whole head — name, kind, terrain, the route
  /// line, the price and the travel control — which is everything asserted
  /// below; the sections it drops (Work, Gathering, Encounters) live at FULL
  /// and have their own test.
  Future<void> raise(WidgetTester tester) async {
    await tester.tap(find.byKey(worldSheetGripKey));
    await tester.pumpAndSettle();
  }

  /// Pans the target into the viewport and taps it.
  Future<void> select(WidgetTester tester, String id) async {
    final Offset from = tester.getCenter(find.byType(AtlasViewport));
    await tester.dragFrom(from, from - tester.getCenter(hit(id)));
    await tester.pumpAndSettle();
    await tester.tap(hit(id));
    await tester.pumpAndSettle();
  }

  AtlasViewportState viewportState(WidgetTester tester) =>
      tester.state<AtlasViewportState>(find.byType(AtlasViewport));

  testWidgets('renders every place as a target, and marks the current one', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);

    expect(find.byType(AtlasViewport), findsOneWidget);
    for (final String id in <String>[
      'location.havens_rest',
      'location.whispering_woods',
      'location.stonefall_mine',
      'location.frostmere',
      'location.forgotten_hollow',
    ]) {
      expect(hit(id), findsOneWidget, reason: id);
      // 44 dp is the accessibility floor, and at zoom 1 world px are dp.
      final Size size = tester.getSize(hit(id));
      expect(size.width, greaterThanOrEqualTo(44), reason: id);
      expect(size.height, greaterThanOrEqualTo(44), reason: id);
    }

    // The pulse is centred on the current location — the same point as the
    // hit target for Haven's Rest — and there is exactly one of it.
    expect(find.byType(AtlasPulse), findsOneWidget);
    final Offset pulse = tester.getCenter(find.byType(AtlasPulse));
    final Offset here = tester.getCenter(hit('location.havens_rest'));
    expect((pulse - here).distance, lessThan(1));

    // And the camera opened on it: the current place is inside the window.
    final Rect window = tester.getRect(find.byType(AtlasViewport));
    expect(window.contains(here), isTrue);

    // Every place carries its kind glyph under the ring, from the shipped
    // table — one hut, two trees, one pick, one dead tree (DECISIONS/0021 §5)
    // — and each landmark its cairn. Twenty-three landmarks since World Map
    // Expansion Refinement 02: the two minor captions and twenty-one far
    // promises (Outer Shoal retired from the crowded south-east column;
    // Wayfarer's Pass, The White Reach and The Far Isles named on the second
    // frontier ring).
    // Scoped to the viewport: the peek row now shows the selected place's
    // kind glyph from the same table, and it is not a marker on the map.
    final List<String> glyphs = tester
        .widgetList<PixelAsset>(
          find.descendant(
            of: find.byType(AtlasViewport),
            matching: find.byType(PixelAsset),
          ),
        )
        .map((PixelAsset a) => a.assetPath)
        .where((String path) => path.contains('/world/marker_'))
        .toList();
    expect(glyphs, hasLength(28));
    int count(String tail) =>
        glyphs.where((String p) => p.endsWith(tail)).length;
    expect(count('marker_haven.png'), 1);
    expect(count('marker_wilds.png'), 2);
    expect(count('marker_worksite.png'), 1);
    expect(count('marker_perilous.png'), 1);
    expect(count('marker_landmark.png'), 23);
  });

  testWidgets('tapping a place opens its panel with what the rows carried', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 5000);
    await pumpWorld(tester, session);

    await raise(tester);
    // Before any tap: the panel is on the current location. The inspector is
    // now the map-first screen's translucent panel (`bare`, no SectionCard), so
    // the content is scoped to AtlasSelectionPanel rather than the card.
    final Finder panel = find.byType(AtlasSelectionPanel);
    expect(
      find.descendant(of: panel, matching: find.textContaining('You are here')),
      findsOneWidget,
    );

    await select(tester, 'location.stonefall_mine');
    expect(
      find.descendant(of: panel, matching: find.text('Stonefall Mine')),
      findsOneWidget,
    );
    // The kind word and the ground, from content, in the header caption.
    // Asserted on the terrain half only: the kind word is the one thing here
    // still coming from the `isSafe` placeholder derivation, and it changes to
    // "Worksite" the day `RegionPlace.kind` lands.
    expect(
      find.descendant(of: panel, matching: find.textContaining('· Foothills')),
      findsOneWidget,
    );
    // A road from here, and its price, said in words rather than implied.
    expect(
      find.descendant(
        of: panel,
        matching: find.text('Road from here · 1,400 steps'),
      ),
      findsOneWidget,
    );
    // The price, from content, profile-scaled.
    expect(
      find.descendant(of: panel, matching: find.text('1,400')),
      findsOneWidget,
    );
    // And exactly one Travel control, enabled: 5,000 affords 1,400.
    final Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNotNull);
  });

  testWidgets('the travel control follows the option, from two states', (
    WidgetTester tester,
  ) async {
    // 100 banked: neither road is affordable, and the panel says how short.
    final StrideSession poor = await boot(tester, banked: 100);
    await pumpWorld(tester, poor);
    await select(tester, 'location.stonefall_mine');
    await raise(tester);
    Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNull);
    expect(find.textContaining('Walk 1,300 more steps'), findsOneWidget);

    // A fresh save, 50,000 banked: the same road is open.
    await tester.pumpWidget(const SizedBox.shrink());
    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('stride_atlas');
    final StrideSession rich = await boot(tester, banked: 50000);
    await pumpWorld(tester, rich);
    await select(tester, 'location.stonefall_mine');
    await raise(tester);
    button = find.widgetWithText(StrideButton, 'Travel');
    expect((tester.widget(button) as StrideButton).onPressed, isNotNull);
    expect(find.textContaining('more steps'), findsNothing);
  });

  testWidgets('a place two roads off is offered as one whole journey (B-2)', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 50000);
    final SessionController controller = await pumpWorld(tester, session);

    await select(tester, 'location.frostmere');
    await raise(tester);
    // The whole journey, priced whole, from the content pack's own costs:
    // Haven → Stonefall Mine 1,400, Mine → Frostmere 3,000.
    expect(
      find.text('By way of Stonefall Mine · 4,400 steps in all'),
      findsOneWidget,
    );
    // And it is offered — one Travel control for the whole walk.
    final Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNotNull);

    // The confirmation quotes the whole way's price and what it leaves. The
    // map-first panel gives the info a scrolling third of the screen, so the
    // control can sit below the fold for a rich place — bring it into view the
    // way a player scrolls to it before tapping.
    final int before = session.usableEnergy;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'By way of Stonefall Mine · 4,400 steps in all · leaves '
        '${formatSteps(before - 4400)} banked',
      ),
      findsOneWidget,
    );

    // Walk it (dispatched under runAsync, as every real travel in this file
    // is — the commit is real file IO): both legs commit, the charge is the
    // journey's 4,400 — and the arrival line names the journey total with
    // the final leg distinguished, never the last leg presented as the trip.
    await tester.runAsync(
      () => controller.travelJourney(<ContentId>[
        ContentId.unchecked('location.stonefall_mine'),
        ContentId.unchecked('location.frostmere'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(session.usableEnergy, before - 4400);
    expect(session.currentLocation?.value, 'location.frostmere');
    expect(
      find.textContaining('4,400-step journey (final leg 3,000)'),
      findsOneWidget,
    );
  });

  testWidgets('the way names the place between, both directions', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 50000);
    await pumpWorld(tester, session);
    await select(tester, 'location.forgotten_hollow');
    await raise(tester);
    expect(find.textContaining('By way of Whispering Woods'), findsOneWidget);
  });

  testWidgets('the route preview highlights exactly the roads on the way', (
    WidgetTester tester,
  ) async {
    // The dots the player follows must be the edges of the walk the panel
    // describes — the same object, so the picture and the sentence cannot
    // disagree. Selecting *here* highlights nothing at all.
    final StrideSession session = await boot(tester, banked: 50000);
    await pumpWorld(tester, session);

    AtlasRouteLayer layer() =>
        tester.widget<AtlasRouteLayer>(find.byType(AtlasRouteLayer));

    expect(layer().way, isNull, reason: 'the selection opens on *here*');

    await select(tester, 'location.frostmere');
    final AtlasWay way = layer().way!;
    expect(way.totalCost, 4400);
    expect(way.firstLegCost, 1400);
    expect(way.edges.map((AtlasEdge e) => e.key).toSet(), <String>{
      AtlasEdge.keyOf(
        ContentId.unchecked('location.havens_rest'),
        ContentId.unchecked('location.stonefall_mine'),
      ),
      AtlasEdge.keyOf(
        ContentId.unchecked('location.stonefall_mine'),
        ContentId.unchecked('location.frostmere'),
      ),
    });
    // The surface has more roads than the walk uses, so this is a filter and
    // not "everything".
    expect(
      AtlasScene.build(session)!.edges.length,
      greaterThan(way.edges.length),
    );

    await select(tester, 'location.havens_rest');
    expect(layer().way, isNull);
  });

  testWidgets('a requirement is stated before a price, as the engine refuses', (
    WidgetTester tester,
  ) async {
    // Walk to the woods (2,000 − 600 = 1,400 banked), then look at the
    // Hollow: 1,400 covers its 1,300, so the only refusal left is the Bronze
    // Sword — and that is the sentence the panel must show, with the control
    // disabled on it.
    final StrideSession session = await boot(tester, banked: 2000);
    final SessionController controller = await pumpWorld(tester, session);
    await select(tester, 'location.whispering_woods');
    await tester.runAsync(() async {
      await controller.travel(ContentId.unchecked('location.whispering_woods'));
    });
    await tester.pumpAndSettle();
    expect(session.currentLocation?.value, 'location.whispering_woods');

    await select(tester, 'location.forgotten_hollow');
    await raise(tester);
    expect(find.textContaining('Needs Bronze Sword'), findsOneWidget);
    final Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNull);
  });

  testWidgets('the sheet has three stops and the map stays the hero', (
    WidgetTester tester,
  ) async {
    // The owner's brief, as an assertion: "the bottom World information sheet
    // currently obscures too much map — fix this; map must remain the hero."
    // The old panel opened at 34 % of the body and every marker tap re-opened
    // it. These are the three stops that replaced it (DIR-15 §1).
    final StrideSession session = await boot(tester, banked: 50000);
    await pumpWorld(tester, session);

    final Rect window = tester.getRect(find.byType(AtlasViewport));
    double sheet() => tester.getRect(find.byKey(worldSheetKey)).height;
    double mapShare() => (window.height - sheet()) / window.height;

    // PEEK is the opening move, and it is 64 dp.
    expect(sheet(), 64);
    expect(mapShare(), greaterThan(0.90));

    // A marker tap NEVER raises the sheet — the failure the brief named.
    await select(tester, 'location.stonefall_mine');
    expect(sheet(), 64, reason: 'a marker tap must not raise the sheet');
    // The peek answers the tap: the name is in the sheet, not only on the map.
    expect(
      find.descendant(
        of: find.byKey(worldSheetKey),
        matching: find.text('Stonefall Mine'),
      ),
      findsOneWidget,
    );

    // The peek's compact Travel does not travel: it raises the sheet to HALF
    // with the priced confirmation asked. `Set out` is still the only
    // dispatch, and the session has not moved.
    await tester.tap(find.widgetWithText(StrideButton, 'Travel'));
    await tester.pumpAndSettle();
    expect(
      sheet(),
      closeTo((window.height * 0.36).clamp(232, 300), 0.5),
      reason: 'HALF',
    );
    expect(mapShare(), greaterThan(0.60));
    expect(find.textContaining('Set out for Stonefall Mine'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Set out'), findsOneWidget);
    expect(session.currentLocation?.value, 'location.havens_rest');

    // The grip drags to FULL, which is the reading stop, and even there the
    // map keeps 30 % of the body.
    await tester.fling(
      find.byKey(worldSheetGripKey),
      const Offset(0, -80),
      900,
    );
    await tester.pumpAndSettle();
    expect(sheet(), closeTo(window.height * 0.70, 0.5), reason: 'FULL');
    expect(mapShare(), greaterThan(0.29));

    // A tap on open country — no marker under it — drops the sheet back to
    // peek. Found rather than guessed: the atlas is dense with 44 dp targets.
    final List<Rect> targets = <Rect>[
      for (final Element e
          in find
              .byWidgetPredicate(
                (Widget w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('atlas-hit:'),
              )
              .evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    Offset? gap;
    for (
      double y = window.top + 40;
      y < window.top + 200 && gap == null;
      y += 20
    ) {
      for (double x = window.left + 12; x < window.right - 12; x += 20) {
        final Offset point = Offset(x, y);
        if (targets.every((Rect r) => !r.contains(point))) {
          gap = point;
          break;
        }
      }
    }
    expect(gap, isNotNull, reason: 'the map has some open country on it');
    await tester.tapAt(gap!);
    await tester.pumpAndSettle();
    expect(sheet(), 64, reason: 'a tap on the map drops the sheet to peek');
  });

  testWidgets('panning moves the camera and dispatches nothing', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 50000);
    final SessionController controller = await pumpWorld(tester, session);
    final int bankedBefore = session.usableEnergy;
    final Offset before = viewportState(tester).camera;

    // A long drag, well past the world's edge — the clamp must hold.
    final Offset centre = tester.getCenter(find.byType(AtlasViewport));
    await tester.dragFrom(centre, const Offset(300, 900));
    await tester.pumpAndSettle();

    final AtlasViewportState state = viewportState(tester);
    expect(state.camera, isNot(before), reason: 'the drag moved the window');
    expect(state.camera.dx, greaterThanOrEqualTo(0));
    expect(state.camera.dy, greaterThanOrEqualTo(0));
    expect(state.zoom, zooms.initial);

    expect(session.usableEnergy, bankedBefore);
    expect(session.currentLocation?.value, 'location.havens_rest');
    expect(controller.lastTravel, isNull);
    // And nothing was selected by dragging: the sheet is still on *here*, at
    // its peek stop, saying `Settlement · You are here`.
    expect(find.widgetWithText(StrideButton, 'Travel'), findsNothing);

    // The drag put *here* off the visible map, so the contextual strip has
    // appeared and says which way it lies — the one place in this screen that
    // speaks about the camera, and it still never names it. Two sentences
    // carry the words now: the peek's status line and the strip's chip.
    expect(find.byKey(worldContextStripKey), findsOneWidget);
    expect(find.textContaining('You are here'), findsNWidgets(2));
  });

  /// A two-finger pinch about the viewport's centre, from [from] to [to]
  /// pixels apart, in ten steps.
  Future<void> pinch(WidgetTester tester, double from, double to) async {
    final Offset c = tester.getCenter(find.byType(AtlasViewport));
    final TestGesture a = await tester.startGesture(c - Offset(from / 2, 0));
    final TestGesture b = await tester.startGesture(c + Offset(from / 2, 0));
    await tester.pump();
    for (int i = 1; i <= 10; i++) {
      final double gap = from + (to - from) * i / 10;
      await a.moveTo(c - Offset(gap / 2, 0));
      await b.moveTo(c + Offset(gap / 2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  testWidgets('no two targets overlap, at either end of the zoom range', (
    WidgetTester tester,
  ) async {
    // Device review, checklist item 1. A thumb on one place must not be a
    // tap on another; the floor and the separation are checked at 1× and
    // again at 2×, where the targets are simply twice the size.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    const List<String> ids = <String>[
      'location.havens_rest',
      'location.whispering_woods',
      'location.stonefall_mine',
      'location.frostmere',
      'location.forgotten_hollow',
    ];
    void check(double minWidth) {
      for (int i = 0; i < ids.length; i++) {
        final Rect a = tester.getRect(hit(ids[i]));
        expect(a.width, greaterThanOrEqualTo(minWidth), reason: ids[i]);
        for (int j = i + 1; j < ids.length; j++) {
          expect(
            a.overlaps(tester.getRect(hit(ids[j]))),
            isFalse,
            reason: '${ids[i]} and ${ids[j]} share thumb space',
          );
        }
      }
    }

    // At the opening zoom a 48-world-px radius clears the 44 dp floor, and
    // at the ceiling it is simply twice that. Both are derived from the
    // layout's scale, not written down.
    check(44);
    await pinch(tester, 100, 300);
    expect(viewportState(tester).zoom, zooms.max);
    check(88);
  });

  testWidgets('pinch zoom is clamped and settles on whole device pixels', (
    WidgetTester tester,
  ) async {
    // Checklist item 5. Beyond the ceiling the map stops growing; below the
    // floor it stops shrinking; and a pinch that lets go in between lands on
    // a zoom at which one art pixel is a whole number of device pixels — at
    // dpr 3 and art scale 6, a multiple of one eighteenth — so pixel art
    // never blurs at rest. The unit is computed from the shipped scale.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    final AtlasViewportState state = viewportState(tester);

    await pinch(tester, 100, 133);
    final double settled = state.zoom;
    expect(settled, inExclusiveRange(state.minZoom, zooms.max));
    final int unit = shippedAtlasScale * 3; // art scale × dpr
    expect(
      (settled * unit).roundToDouble(),
      settled * unit,
      reason: 'one native art pixel is a whole number of device pixels',
    );
    await pinch(tester, 100, 400);
    expect(state.zoom, zooms.max);
    await pinch(tester, 300, 40);
    // The floor is native ×1 (0.25 at scale 4): the crispest reduction the
    // sampler will make, and for the 2752-wide continent it is the
    // absoluteFloor rather than a fit-the-width zoom — 393 / 2752 ≈ 0.14 is
    // below it, so the range stops where the art stops being worth looking
    // at rather than dropping columns.
    expect(state.zoom, state.minZoom);
    expect(state.zoom, zooms.absoluteFloor);

    // The property, in the form the correction round left it: at the survey
    // floor the continent extends past the window in **both** axes.
    //
    // It used to say the full height frames in one look, and that was true
    // and was the problem — a world you can take in vertically without
    // moving is a strip. The owner's acceptance target is panning that means
    // something in all four directions (§27), so north/south now has to fail
    // to frame exactly as east/west already did.
    final AtlasScene scene = AtlasScene.build(session)!;
    final Rect window = tester.getRect(find.byType(AtlasViewport));
    expect(
      scene.worldWidth * state.zoom,
      greaterThan(window.width),
      reason: 'the continent must extend past the window east and west',
    );
    expect(
      scene.worldHeight * state.zoom,
      greaterThan(window.height),
      reason: 'the whole north-south extent frames at the survey floor',
    );
  });

  testWidgets('the camera cannot leave the world', (WidgetTester tester) async {
    // Checklist item 6: a drag past any edge stops at it — no void, no
    // over-scroll — at both zooms.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    final AtlasViewportState state = viewportState(tester);
    final Rect window = tester.getRect(find.byType(AtlasViewport));
    final AtlasScene scene = AtlasScene.build(session)!;

    Future<void> dragAndCheck() async {
      final Offset centre = window.center;
      for (final Offset delta in <Offset>[
        const Offset(2000, 3000),
        const Offset(-2000, -3000),
      ]) {
        await tester.dragFrom(centre, delta);
        await tester.pumpAndSettle();
        final Offset camera = state.camera;
        expect(camera.dx, greaterThanOrEqualTo(0));
        expect(camera.dy, greaterThanOrEqualTo(0));
        expect(
          camera.dx,
          lessThanOrEqualTo(scene.worldWidth - window.width / state.zoom),
        );
        expect(
          camera.dy,
          lessThanOrEqualTo(scene.worldHeight - window.height / state.zoom),
        );
      }
    }

    await dragAndCheck();
    await pinch(tester, 100, 300);
    expect(state.zoom, zooms.max);
    await dragAndCheck();
  });

  testWidgets('overlays paint below the markers and take no taps', (
    WidgetTester tester,
  ) async {
    // Checklist item 7. Cloud, mist and smoke may drift under a place; they
    // may never cover its ring, its name or its target. That is a z-order
    // fact about one Stack, asserted here so a layer added later cannot
    // quietly land on top.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    final Stack world = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(AtlasMarkerLayer),
            matching: find.byType(Stack),
          )
          .first,
    );
    final List<Type> order = world.children
        .map((Widget w) => w.runtimeType)
        .toList();
    expect(order.indexOf(AtlasOverlayLayer), greaterThanOrEqualTo(0));
    expect(
      order.indexOf(AtlasOverlayLayer),
      lessThan(order.indexOf(AtlasMarkerLayer)),
    );
    expect(order.last, AtlasMarkerLayer, reason: 'nothing paints over a name');
    expect(
      find.descendant(
        of: find.byType(AtlasOverlayLayer),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('high air paints over ground life, with the shadows between', (
    WidgetTester tester,
  ) async {
    // v6 depth. The two dragons are high air and the gull loops are low air;
    // everything else is ground. The band decides paint order, NOT the row's
    // place in the JSON array, so a dragon crossing the coast passes over the
    // gulls instead of through them. Asserted against the shipped layout,
    // because the risk is a row landing in the wrong band later.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    final AtlasLayout layout = session.atlasLayout!;
    int count(bool Function(AtlasOverlay) test) => layout.overlays
        .where((AtlasOverlay o) => o.visibleAt(Duration.zero) && test(o))
        .length;
    final int ground = count((AtlasOverlay o) => o.depth == 0);
    final int shadows = count((AtlasOverlay o) => o.shadow != null);
    final int lowAir = count((AtlasOverlay o) => o.depth == 1);
    final int highAir = count((AtlasOverlay o) => o.depth == 2);
    expect(highAir, 2, reason: 'the red wyrm and the storm drake');
    expect(lowAir, greaterThan(0), reason: 'the gull loops');
    expect(shadows, greaterThan(0), reason: 'a dragon casts one');

    final Stack band = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(AtlasOverlayLayer),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(band.children.length, ground + shadows + lowAir + highAir);

    // A shadow is the only thing in this layer wearing a colour filter, so
    // the filtered children are exactly the shadow pass — and it sits after
    // the ground and before the air.
    bool filtered(Widget w) => switch (w) {
      ColorFiltered() => true,
      Positioned(child: final Widget c) => filtered(c),
      Opacity(child: final Widget c) => filtered(c),
      Transform(child: final Widget c?) => filtered(c),
      _ => false,
    };
    final List<int> shadowRows = <int>[
      for (final (int i, Widget child) in band.children.indexed)
        if (filtered(child)) i,
    ];
    expect(shadowRows, <int>[for (int i = 0; i < shadows; i++) ground + i]);
  });

  testWidgets('a stopped ticker stills the world, it does not empty it', (
    WidgetTester tester,
  ) async {
    // M-16. The overlay layer's clock never advances in a widget test, which
    // is the state reduced motion and a backgrounded app also put it in.
    // Every path overlay must still be built — pinned at its first waypoint,
    // frame 0 — because an accessibility setting may take the movement and
    // not the map.
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    final AtlasLayout layout = session.atlasLayout!;
    final List<AtlasOverlay> patrols = layout.overlays
        .where((AtlasOverlay o) => o.hasPath)
        .toList();
    expect(patrols.length, greaterThanOrEqualTo(12));

    for (final AtlasOverlay patrol in patrols) {
      expect(
        patrol.visibleAt(Duration.zero),
        isTrue,
        reason: '${patrol.asset} patrols, and a patrol has no quiet gap',
      );
      expect(
        patrol.topLeftAt(Duration.zero, layout.scale).x,
        closeTo(
          patrol.path!.points.first.x - patrol.width * layout.scale / 2,
          0.001,
        ),
        reason: '${patrol.asset} is pinned at its first waypoint',
      );
      expect(patrol.frameIndexAt(Duration.zero), 0);
    }

    // And they are really on screen: the stilled layer draws sprites, not an
    // empty stack.
    expect(
      find.descendant(
        of: find.byType(AtlasOverlayLayer),
        matching: find.byType(PixelAsset),
      ),
      findsWidgets,
    );
  });

  testWidgets('arriving somewhere recentres the window on it', (
    WidgetTester tester,
  ) async {
    // Checklist item 6: after a journey the map shows *here*, not the place
    // the player left — and the panel follows.
    final StrideSession session = await boot(tester, banked: 5000);
    final SessionController controller = await pumpWorld(tester, session);
    await select(tester, 'location.whispering_woods');
    expect(find.widgetWithText(StrideButton, 'Travel'), findsOneWidget);
    // Opening the screen is not an arrival: nothing bursts until one happens.
    expect(find.byType(AtlasArrivalBurst), findsNothing);

    await tester.runAsync(
      () => controller.travel(ContentId.unchecked('location.whispering_woods')),
    );
    await tester.pumpAndSettle();
    expect(session.currentLocation?.value, 'location.whispering_woods');

    // The map fills the window and the sheet overlays its lower edge, so the
    // arrived place centres in the VISIBLE map area above the sheet — not the
    // full window — or the you-are-here marker would open behind the glass.
    // Measured against the sheet itself rather than whatever scrollable is
    // inside it: at the peek stop the sheet is 64 dp and there is no list at
    // all, which is the whole point of the stop.
    final Rect window = tester.getRect(find.byType(AtlasViewport));
    final double sheetTop = tester.getRect(find.byKey(worldSheetKey)).top;
    final Offset visibleCentre = Offset(
      window.center.dx,
      (window.top + sheetTop) / 2,
    );
    final Offset here = tester.getCenter(hit('location.whispering_woods'));
    expect((visibleCentre - here).distance, lessThan(2));
    expect(find.textContaining('You are here'), findsOneWidget);

    // And the destination gets its one beat, on the marker the player now
    // stands on. No avatar walked there; the burst is the arrival's
    // punctuation.
    expect(find.byType(AtlasArrivalBurst), findsOneWidget);
    expect(
      (tester.getCenter(find.byType(AtlasArrivalBurst)) - here).distance,
      lessThan(1),
    );
  });

  testWidgets('the pulse runs only while the app is resumed', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester);
    await pumpWorld(tester, session);
    addTearDown(tester.binding.resetInternalState);

    // The harness starts with no lifecycle state, which is "not resumed":
    // nothing is scheduled, which is also why pumpAndSettle returned above.
    expect(tester.hasRunningAnimations, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'resumed: the pulse under the current location is breathing',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'paused: nothing on the atlas ticks',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the tracked Journey\'s destination reaches the marker layer, '
      'and an untracked one does not', (WidgetTester tester) async {
    final StrideSession session = await boot(tester);
    final SessionController controller = await pumpWorld(tester, session);

    AtlasMarkerLayer markers() =>
        tester.widget<AtlasMarkerLayer>(find.byType(AtlasMarkerLayer));

    // No journey set: no gold ring parameter.
    expect(markers().journey, isNull);

    // Track the Woods as the Journey — the same command the panel's
    // "Set as Journey" button dispatches — and the marker layer reads the
    // destination from the same projection the tracker card renders.
    final ContentId woods = ContentId.unchecked('location.whispering_woods');
    await tester.runAsync(() => controller.trackGoal(GoalSlot.journey, woods));
    await tester.pumpAndSettle();
    expect(markers().journey, woods);

    // Cleared: the ring goes with it.
    await tester.runAsync(() => controller.trackGoal(GoalSlot.journey, null));
    await tester.pumpAndSettle();
    expect(markers().journey, isNull);
  });
}
