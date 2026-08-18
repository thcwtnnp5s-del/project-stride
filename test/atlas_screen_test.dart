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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/surfaces.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layers.dart';
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

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[if (banked > 0) page(banked)],
        ),
      ),
    ))!;
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
  });

  testWidgets('tapping a place opens its panel with what the rows carried', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 5000);
    await pumpWorld(tester, session);

    // Before any tap: the panel is on the current location.
    final Finder panel = find.byType(SectionCard);
    expect(
      find.descendant(of: panel, matching: find.textContaining('You are here')),
      findsOneWidget,
    );

    await select(tester, 'location.stonefall_mine');
    expect(
      find.descendant(of: panel, matching: find.text('Stonefall Mine')),
      findsOneWidget,
    );
    // Terrain and resources, from content. Two nodes at the mine.
    expect(
      find.descendant(
        of: panel,
        matching: find.textContaining('Foothills · 2 resources'),
      ),
      findsOneWidget,
    );
    // The price, from content, profile-scaled.
    expect(
      find.descendant(of: panel, matching: find.text('800')),
      findsOneWidget,
    );
    // And exactly one Travel control, enabled: 5,000 affords 800.
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
    Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNull);
    expect(find.textContaining('Walk 700 more steps'), findsOneWidget);

    // A fresh save, 50,000 banked: the same road is open.
    await tester.pumpWidget(const SizedBox.shrink());
    root.deleteSync(recursive: true);
    root = Directory.systemTemp.createTempSync('stride_atlas');
    final StrideSession rich = await boot(tester, banked: 50000);
    await pumpWorld(tester, rich);
    await select(tester, 'location.stonefall_mine');
    button = find.widgetWithText(StrideButton, 'Travel');
    expect((tester.widget(button) as StrideButton).onPressed, isNotNull);
    expect(find.textContaining('more steps'), findsNothing);
  });

  testWidgets('a place with no road from here is described, not offered', (
    WidgetTester tester,
  ) async {
    final StrideSession session = await boot(tester, banked: 50000);
    await pumpWorld(tester, session);

    await select(tester, 'location.frostmere');
    expect(find.byType(StrideButton), findsNothing);
    expect(
      find.textContaining(
        'Not reachable from here directly · reached by way of Stonefall Mine',
      ),
      findsOneWidget,
    );

    // Two roads away: the way names both places, in order.
    await select(tester, 'location.forgotten_hollow');
    expect(find.byType(StrideButton), findsNothing);
    expect(
      find.textContaining('reached by way of Whispering Woods'),
      findsOneWidget,
    );
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
    expect(find.textContaining('Needs Bronze Sword'), findsOneWidget);
    final Finder button = find.widgetWithText(StrideButton, 'Travel');
    expect(button, findsOneWidget);
    expect((tester.widget(button) as StrideButton).onPressed, isNull);
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
    expect(state.zoom, AtlasZoom.min);

    expect(session.usableEnergy, bankedBefore);
    expect(session.currentLocation?.value, 'location.havens_rest');
    expect(controller.lastTravel, isNull);
    // And nothing was selected by dragging: the panel is still on *here*.
    expect(find.textContaining('You are here'), findsOneWidget);
    expect(find.widgetWithText(StrideButton, 'Travel'), findsNothing);
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
}
