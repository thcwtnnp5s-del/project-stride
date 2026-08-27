/// The location inspector: what the panel under the atlas says about a place.
///
/// ## Why this drives the widget directly rather than the screen
///
/// [AtlasInspector] is a pure function of an [AtlasPlaceInfo], and that is the
/// point of the split. The rows it has to get right — a boss, an enemy driven
/// off, four gathering nodes, a place two roads away — are states the shipped
/// content does not all contain today, and a session fake would have to
/// reimplement the projections convincingly enough to produce them. Handing
/// the widget the view model is both cheaper and stricter: nothing here can
/// pass because the content happened to line up.
///
/// The wiring from session to view model is exercised by `atlas_screen_test`,
/// which drives the real screen over a real save.
///
/// ## The risks these cover, named before the work
///
/// - **An empty section with a heading.** "Gathering" over nothing reads as a
///   place with no resources; the truth is that the panel has nothing to say.
/// - **A fabricated row.** Every gathering and encounter row must come from
///   the info object; none is composed here.
/// - **A price a player cannot plan with.** For a place two roads off the
///   panel must print the total *and* the leg the button charges, and say
///   which is which.
/// - **A control with no command behind it.** No travel option, no button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_selection_panel.dart';
import 'package:stride/ui/state/session_controller.dart' show JourneySummary;
import 'package:stride_core/stride_core.dart'
    show ContentId, LocationKind, Terrain;

import 'support/real_font.dart';

ContentId _id(String slug) => ContentId.unchecked('location.$slug');

AtlasNode _node(String slug, String name) => AtlasNode(
  place: RegionPlace(
    id: _id(slug),
    displayName: name,
    isCurrent: false,
    isSafe: false,
    isUnlocked: true,
    stepCostFromHere: null,
    resourceCount: 0,
    terrain: Terrain.foothills,
    kind: LocationKind.wilds,
  ),
  x: 0,
  y: 0,
);

AtlasPlaceInfo _info({
  AtlasPlaceKind kind = AtlasPlaceKind.worksite,
  String terrain = 'Foothills',
  bool isSafe = false,
  bool isCurrent = false,
  bool isUnlocked = true,
  List<AtlasGatherLine> gather = const <AtlasGatherLine>[],
  List<AtlasEncounterLine> encounters = const <AtlasEncounterLine>[],
}) => AtlasPlaceInfo(
  kind: kind,
  terrainWord: terrain,
  isSafe: isSafe,
  isCurrent: isCurrent,
  isUnlocked: isUnlocked,
  gatherSites: gather,
  encounters: encounters,
);

/// A direct road to Stonefall Mine at [cost].
AtlasWay _direct({int cost = 800}) {
  final AtlasNode mine = _node('stonefall_mine', 'Stonefall Mine');
  return AtlasWay(
    hops: <AtlasNode>[mine],
    edges: <AtlasEdge>[],
    totalCost: cost,
    firstLegCost: cost,
  );
}

/// A two-leg walk: here → Stonefall Mine → Frostmere, 800 then 1,500.
AtlasWay _twoLegs() {
  final AtlasNode mine = _node('stonefall_mine', 'Stonefall Mine');
  final AtlasNode far = _node('frostmere', 'Frostmere');
  return AtlasWay(
    hops: <AtlasNode>[mine, far],
    edges: <AtlasEdge>[AtlasEdge(a: mine, b: far)],
    totalCost: 2300,
    firstLegCost: 800,
  );
}

Future<void> pumpInspector(
  WidgetTester tester, {
  required AtlasPlaceInfo info,
  String name = 'Stonefall Mine',
  AtlasWay? way,
  List<String> missingEntry = const <String>[],
  int banked = 50000,
  bool busy = false,
  bool ready = true,
  JourneySummary? lastJourney,
  VoidCallback? onTravel,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AtlasInspector(
            name: name,
            info: info,
            way: way,
            missingEntry: missingEntry,
            banked: banked,
            busy: busy,
            ready: ready,
            lastJourney: lastJourney,
            onTravel: onTravel ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  group('the header and status', () {
    testWidgets('names the place, its kind and its ground', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info());
      expect(find.text('Stonefall Mine'), findsOneWidget);
      expect(find.text('Worksite · Foothills'), findsOneWidget);
    });

    test('says where the player stands, and whether it is safe', () {
      expect(
        AtlasInspector.statusLine(_info(isCurrent: true, isSafe: true)),
        'You are here · Safe',
      );
      expect(AtlasInspector.statusLine(_info()), 'Reached');
      expect(
        AtlasInspector.statusLine(_info(isUnlocked: false)),
        'Not yet reached',
      );
    });

    test('gives every kind a word a player would use', () {
      expect(AtlasPlaceKind.haven.word, 'Settlement');
      expect(AtlasPlaceKind.wilds.word, 'Wilds');
      expect(AtlasPlaceKind.worksite.word, 'Worksite');
      expect(AtlasPlaceKind.perilous.word, 'Perilous');
    });
  });

  group('gathering', () {
    testWidgets('lists what stands here, with its skill, level and tool', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(
          gather: const <AtlasGatherLine>[
            (
              name: 'Copper Seam',
              skill: 'Mining',
              level: 1,
              tool: 'Pickaxe',
              eligible: true,
              gap: null,
            ),
            (
              name: 'Meadow Herbs',
              skill: 'Foraging',
              level: 1,
              tool: null,
              eligible: true,
              gap: null,
            ),
          ],
        ),
      );
      expect(find.text('GATHERING'), findsOneWidget);
      expect(find.text('Copper Seam · Mining Lv 1 · Pickaxe'), findsOneWidget);
      // A node needing no tool prints no tool, rather than "none".
      expect(find.text('Meadow Herbs · Foraging Lv 1'), findsOneWidget);
    });

    testWidgets('has no heading at all when there is nothing to gather', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info());
      expect(find.text('GATHERING'), findsNothing);
    });
  });

  group('encounters', () {
    testWidgets('counts down where the player stands', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(
          isCurrent: true,
          encounters: const <AtlasEncounterLine>[
            (
              name: 'Grey Wolf',
              isBoss: false,
              behaviorWord: 'Aggressive',
              perVisit: 2,
              remaining: 2,
              isCurrentLocation: true,
            ),
            (
              name: 'Hollow Guardian',
              isBoss: true,
              behaviorWord: 'Defensive',
              perVisit: 1,
              remaining: 0,
              isCurrentLocation: true,
            ),
          ],
        ),
      );
      expect(find.text('ENCOUNTERS'), findsOneWidget);
      expect(find.text('Grey Wolf'), findsOneWidget);
      expect(find.text('Aggressive · 2 of 2 this visit'), findsOneWidget);
      expect(find.text('BOSS'), findsOneWidget);
      expect(
        find.text('Defensive · Driven off — returns after you travel'),
        findsOneWidget,
      );
    });

    testWidgets('quotes the authored number for somewhere not yet reached', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(
          encounters: const <AtlasEncounterLine>[
            (
              name: 'Frost Lynx',
              isBoss: false,
              behaviorWord: 'Wary',
              perVisit: 2,
              remaining: 2,
              isCurrentLocation: false,
            ),
          ],
        ),
      );
      expect(find.text('Wary · 2 per visit'), findsOneWidget);
      expect(find.text('BOSS'), findsNothing);
    });

    test('never says "1 per visits"', () {
      expect(
        AtlasInspector.encounterLine((
          name: 'Hollow Guardian',
          isBoss: true,
          behaviorWord: 'Defensive',
          perVisit: 1,
          remaining: 1,
          isCurrentLocation: false,
        )),
        'Defensive · 1 per visit',
      );
    });

    testWidgets('has no heading at all when nothing waits here', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info());
      expect(find.text('ENCOUNTERS'), findsNothing);
    });
  });

  group('the route line', () {
    testWidgets('a direct road quotes the one price', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info(), way: _direct(cost: 600));
      expect(find.text('Road from here · 600 steps'), findsOneWidget);
    });

    testWidgets('two roads off quotes the whole way, and offers it', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        name: 'Frostmere',
        info: _info(kind: AtlasPlaceKind.perilous, terrain: 'Alpine'),
        way: _twoLegs(),
      );
      expect(
        find.text('By way of Stonefall Mine · 2,300 steps in all'),
        findsOneWidget,
      );
      // The whole journey is offered as one decision (B-2): the button is
      // there, and its confirmation quotes the way and the total.
      expect(find.widgetWithText(StrideButton, 'Travel'), findsOneWidget);
    });

    testWidgets('a place no road chain reaches gets no control', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info(), way: null);
      expect(find.widgetWithText(StrideButton, 'Travel'), findsNothing);
    });

    test('says so plainly when no chain of roads reaches it', () {
      expect(
        AtlasInspector.routeLine(info: _info(), way: null),
        'No route runs there from here.',
      );
    });

    test('invites a tap when the selection is where the player stands', () {
      expect(
        AtlasInspector.routeLine(info: _info(isCurrent: true), way: null),
        'Tap a place on the map to see the way there.',
      );
    });
  });

  group('the travel control', () {
    testWidgets('is offered and enabled when the road is open', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpInspector(
        tester,
        info: _info(),
        way: _direct(),
        onTravel: () => taps++,
      );
      final Finder button = find.widgetWithText(StrideButton, 'Travel');
      expect(button, findsOneWidget);
      expect((tester.widget(button) as StrideButton).onPressed, isNotNull);

      // The tap opens the confirmation step (brief §53) — nothing dispatches
      // until the player confirms.
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'the first tap only asks');
      expect(find.text('Set out for Stonefall Mine?'), findsOneWidget);
      await tester.tap(find.widgetWithText(StrideButton, 'Set out'));
      expect(taps, 1);
    });

    testWidgets('the confirmation can be declined, and nothing dispatches', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpInspector(
        tester,
        info: _info(),
        way: _direct(),
        onTravel: () => taps++,
      );
      await tester.tap(find.widgetWithText(StrideButton, 'Travel'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StrideButton, 'Stay'));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(find.text('Set out for Stonefall Mine?'), findsNothing);
      expect(find.widgetWithText(StrideButton, 'Travel'), findsOneWidget);
    });

    testWidgets('the confirmation quotes the whole journey and its way', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpInspector(
        tester,
        name: 'Frostmere',
        info: _info(kind: AtlasPlaceKind.perilous, terrain: 'Alpine'),
        way: _twoLegs(),
        banked: 3000,
        onTravel: () => taps++,
      );
      await tester.tap(find.widgetWithText(StrideButton, 'Travel'));
      await tester.pumpAndSettle();
      expect(find.text('Set out for Frostmere?'), findsOneWidget);
      // The whole way's price, the way itself, and the balance it leaves —
      // never the first leg presented as the trip (B-2).
      expect(
        find.text(
          'By way of Stonefall Mine · 2,300 steps in all · leaves 700 banked',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(StrideButton, 'Set out'));
      expect(taps, 1);
    });

    testWidgets('states the requirement before the price, and disables', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(),
        // Both refusals at once: the engine checks the requirement first, so
        // that is the sentence the panel must show.
        way: _direct(),
        missingEntry: const <String>['Bronze Sword'],
        banked: 100,
      );
      expect(find.text('Needs Bronze Sword'), findsOneWidget);
      expect(find.textContaining('more steps'), findsNothing);
      final Finder button = find.widgetWithText(StrideButton, 'Travel');
      expect((tester.widget(button) as StrideButton).onPressed, isNull);
    });

    testWidgets('says how far short the player is when only the price bites', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info(), way: _direct(), banked: 100);
      expect(find.text('Walk 700 more steps'), findsOneWidget);
      final Finder button = find.widgetWithText(StrideButton, 'Travel');
      expect((tester.widget(button) as StrideButton).onPressed, isNull);
    });

    testWidgets('is disabled while the session is busy or not ready', (
      WidgetTester tester,
    ) async {
      await pumpInspector(tester, info: _info(), way: _direct(), busy: true);
      expect(
        (tester.widget(find.byType(StrideButton)) as StrideButton).onPressed,
        isNull,
      );
      expect(find.text('Travelling…'), findsOneWidget);

      await pumpInspector(tester, info: _info(), way: _direct(), ready: false);
      expect(
        (tester.widget(find.byType(StrideButton)) as StrideButton).onPressed,
        isNull,
      );
    });
  });

  group('the arrival line (B-2)', () {
    JourneySummary summary({
      bool succeeded = true,
      int totalSpent = 4400,
      int finalLegCost = 3000,
      int legsCompleted = 2,
      int legsPlanned = 2,
      bool firstVisit = false,
      TravelReport? failure,
      String arrivedName = 'Frostmere',
    }) => JourneySummary(
      succeeded: succeeded,
      destinationName: 'Frostmere',
      arrivedName: arrivedName,
      totalSpent: totalSpent,
      finalLegCost: finalLegCost,
      legsCompleted: legsCompleted,
      legsPlanned: legsPlanned,
      firstVisit: firstVisit,
      failure: failure,
    );

    testWidgets('a multi-leg arrival names the journey total, not the leg', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(),
        lastJourney: summary(firstVisit: true),
      );
      expect(
        find.text(
          'Arrived at Frostmere for the first time · 4,400-step journey '
          '(final leg 3,000)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a direct arrival keeps the plain single figure', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(),
        lastJourney: summary(
          totalSpent: 800,
          finalLegCost: 800,
          legsCompleted: 1,
          legsPlanned: 1,
          arrivedName: 'Stonefall Mine',
        ),
      );
      expect(
        find.text('Arrived at Stonefall Mine · 800 steps'),
        findsOneWidget,
      );
    });

    testWidgets('a walk stopped mid-way says where, why, and what it spent', (
      WidgetTester tester,
    ) async {
      await pumpInspector(
        tester,
        info: _info(),
        lastJourney: summary(
          succeeded: false,
          totalSpent: 1400,
          finalLegCost: 1400,
          legsCompleted: 1,
          arrivedName: 'Stonefall Mine',
          failure: const TravelReport(
            succeeded: false,
            destinationName: 'Frostmere',
            cost: 0,
            rejection: 'insufficient_steps',
          ),
        ),
      );
      expect(
        find.text(
          'Stopped at Stonefall Mine — Not enough banked steps for that '
          'journey. (1,400 steps walked)',
        ),
        findsOneWidget,
      );
    });
  });
}
