/// The travel pacing spec, pinned (GAME_FEEL_CHARACTER_PRESENTATION_01,
/// item 2): ranges rather than exact milliseconds where the design says
/// "roughly", exact pass arithmetic where cleanliness is the point.
library;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/screens/world/travel_pacing.dart';

void main() {
  group('durations', () {
    test('every leg count lands inside the owner window and on whole passes',
        () {
      for (int legs = 0; legs <= 8; legs++) {
        final Duration d = TravelPacing.durationForLegs(legs);
        // The owner's target: roughly 10–15 s. The one-road walk may sit
        // just under ten; nothing may exceed fifteen.
        expect(d.inMilliseconds, greaterThanOrEqualTo(9000),
            reason: '$legs legs');
        expect(d.inMilliseconds, lessThanOrEqualTo(15000),
            reason: '$legs legs');
        // Exact multiples of one 660 ms walk pass — the loop always
        // completes cleanly.
        expect(d.inMicroseconds % TravelPacing.walkPass.inMicroseconds, 0,
            reason: '$legs legs');
      }
    });

    test('longer journeys never present shorter', () {
      for (int legs = 1; legs < 8; legs++) {
        expect(
          TravelPacing.durationForLegs(legs + 1),
          greaterThanOrEqualTo(TravelPacing.durationForLegs(legs)),
        );
      }
    });

    test('the cap holds', () {
      expect(TravelPacing.durationForLegs(4), TravelPacing.durationForLegs(40));
    });
  });

  group('phases', () {
    test('the unskippable window is inside the asked 1.5–2 s', () {
      for (int legs = 1; legs <= 5; legs++) {
        final double f = TravelPacing.skipFractionForLegs(legs);
        final Duration window = TravelPacing.durationForLegs(legs) * f;
        expect(window.inMilliseconds, greaterThanOrEqualTo(1500));
        expect(window.inMilliseconds, lessThanOrEqualTo(2000));
      }
    });

    test('phase boundaries are ordered and inside the whole', () {
      for (int legs = 1; legs <= 5; legs++) {
        final double skip = TravelPacing.skipFractionForLegs(legs);
        final double cross = TravelPacing.crossfadeFractionForLegs(legs);
        final double anticipate =
            TravelPacing.anticipationFractionForLegs(legs);
        final double rest = TravelPacing.restFractionForLegs(legs);
        expect(0, lessThan(skip));
        expect(skip, lessThan(cross));
        expect(cross, lessThan(anticipate));
        expect(anticipate, lessThan(rest));
        expect(rest, lessThan(1));
      }
    });

    test('the arrival rest is one whole pass', () {
      for (int legs = 1; legs <= 5; legs++) {
        final Duration whole = TravelPacing.durationForLegs(legs);
        final Duration rest =
            whole * (1 - TravelPacing.restFractionForLegs(legs));
        expect(
          (rest - TravelPacing.walkPass).inMicroseconds.abs(),
          lessThan(1000),
        );
      }
    });
  });

  group('the shared course mapping', () {
    test('holds the ends and eases the middle', () {
      for (int legs = 1; legs <= 4; legs++) {
        expect(TravelPacing.courseProgress(0, legs), 0);
        expect(
          TravelPacing.courseProgress(
            TravelPacing.skipFractionForLegs(legs),
            legs,
          ),
          0,
        );
        expect(
          TravelPacing.courseProgress(
            TravelPacing.restFractionForLegs(legs),
            legs,
          ),
          1,
        );
        expect(TravelPacing.courseProgress(1, legs), 1);
        // Monotonic through the travel loop.
        double last = 0;
        for (double t = 0; t <= 1.0001; t += 0.05) {
          final double p = TravelPacing.courseProgress(t, legs);
          expect(p, greaterThanOrEqualTo(last - 1e-9));
          last = p;
        }
      }
    });
  });

  group('the presentation link', () {
    test('registers and clears a handle', () {
      expect(TravelPresentationLink.active.value, isNull);
      final AnimationController clock = AnimationController(
        vsync: const TestVSync(),
        duration: TravelPacing.durationForLegs(2),
      );
      addTearDown(clock.dispose);
      final TravelPresentationHandle handle = TravelPresentationHandle(
        clock: clock,
        legs: 2,
      );
      TravelPresentationLink.active.value = handle;
      expect(TravelPresentationLink.active.value, same(handle));
      TravelPresentationLink.active.value = null;
      expect(TravelPresentationLink.active.value, isNull);
    });
  });
}
