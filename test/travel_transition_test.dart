/// The journey card's behavior (GAME_FEEL_CHARACTER_PRESENTATION_01,
/// item 2): the unskippable departure window, skip-to-arrival, the shared
/// clock's registration, reduced motion's full bypass, and the labeled skip
/// surface. Deterministic pumps — nothing here sleeps.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/screens/world/travel_pacing.dart';
import 'package:stride/ui/screens/world/travel_transition.dart';

void main() {
  Widget host({bool reduceMotion = false, required Widget child}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: child,
        ),
      );

  /// Opens the card from a button tap and returns after the dialog route
  /// has been pushed (one pump past the bounded precache race).
  Future<void> open(
    WidgetTester tester, {
    bool reduceMotion = false,
    int legs = 2,
  }) async {
    await tester.pumpWidget(
      host(
        reduceMotion: reduceMotion,
        child: Builder(
          builder: (BuildContext context) => GestureDetector(
            key: const ValueKey<String>('go'),
            onTap: () => showTravelTransition(
              context,
              backdrop: null,
              destinationName: 'Frostmere',
              originName: 'Haven\'s Rest',
              legs: legs,
              stepsSpent: 1400,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('go')));
    // The bounded precache race (≤250 ms), then the dialog's own fade.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('the departure window absorbs a reflex tap', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Leaving'), findsOneWidget);
    // Inside the ~1.98 s window a tap does nothing.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.textContaining('Leaving'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    // Still in the departure beat: the tap neither skipped nor dismissed.
    expect(find.textContaining('On the road'), findsNothing);
    expect(find.textContaining('Leaving'), findsOneWidget);
    // Let it run to completion so no ticker outlives the test.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('after the window a tap skips to the arrival, not to nothing', (
    WidgetTester tester,
  ) async {
    await open(tester);
    // Past the window, into the travel loop.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.textContaining('On the road to Frostmere'), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);
    await tester.tap(
      find.textContaining('On the road'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // The arrival rest still plays — the information survives the skip.
    expect(find.textContaining('Arrived at Frostmere'), findsOneWidget);
    expect(find.textContaining('1400 steps'), findsOneWidget);
    // ...and the card dismisses itself within the one rest pass.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Arrived at'), findsNothing);
  });

  testWidgets('the whole presentation runs its paced length and dismisses', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final Duration whole = TravelPacing.durationForLegs(2);
    // Mid-journey: the road caption and the cost line stand.
    await tester.pump(whole * 0.5);
    expect(find.textContaining('On the road to Frostmere'), findsOneWidget);
    // The whole ran: card gone, on its own.
    await tester.pump(whole * 0.55);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Frostmere'), findsNothing);
  });

  testWidgets('the shared clock registers while the card plays and clears '
      'when it leaves', (WidgetTester tester) async {
    await open(tester, legs: 3);
    final TravelPresentationHandle? handle =
        TravelPresentationLink.active.value;
    expect(handle, isNotNull);
    expect(handle!.legs, 3);
    await tester.pumpAndSettle(TravelPacing.durationForLegs(3));
    expect(TravelPresentationLink.active.value, isNull);
  });

  testWidgets('reduced motion never sees the card at all', (
    WidgetTester tester,
  ) async {
    await open(tester, reduceMotion: true);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Leaving'), findsNothing);
    expect(find.textContaining('On the road'), findsNothing);
    expect(TravelPresentationLink.active.value, isNull);
  });

  testWidgets('the skip surface is a real, labeled semantics button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);
    // The card's root semantics node carries the button role and the label,
    // so assistive tech always has a real, findable escape.
    // The caption text merges beneath it, so the match is a containment.
    expect(find.bySemanticsLabel(RegExp('Skip travel')), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 13));
    semantics.dispose();
  });

  testWidgets('opening announces the journey once', (
    WidgetTester tester,
  ) async {
    final List<String> announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (Object? message) async {
        if (message is Map<Object?, Object?> &&
            message['type'] == 'announce') {
          final Object? data = message['data'];
          if (data is Map<Object?, Object?>) {
            announced.add('${data['message']}');
          }
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    await open(tester);
    expect(announced, <String>['Travelling to Frostmere']);
    await tester.pumpAndSettle(const Duration(seconds: 13));
  });
}
