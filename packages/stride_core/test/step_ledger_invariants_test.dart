// Invariants and generated sequences.
//
// The thirteen scenarios prove the cases we thought of. These prove the
// properties that must hold for cases we did not — which is where a
// reconciliation bug actually lives.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

/// A deterministic generator.
///
/// Hand-rolled rather than `Random(seed)` so a failure reproduces byte-for-byte
/// on every Dart version and platform. A property test that cannot be replayed
/// exactly is a property test nobody can debug.
final class Lcg {
  Lcg(this.seed);

  int seed;

  int next(int bound) {
    seed =
        (seed * 6364136223846793005 + 1442695040888963407) & 0x7FFFFFFFFFFFFFFF;
    return (seed >> 16) % bound;
  }

  bool chance(int percent) => next(100) < percent;
}

void main() {
  group('ledger invariants', () {
    test('banked is always granted minus spent', () {
      final GameEngine engine = newEngine();

      for (final int steps in <int>[500, 1200, 90, 4000]) {
        sync(
          engine,
          incremental(<StepObservation>[
            obs(phone, steps % 7, steps),
          ], next: 's$steps'),
        );
        final StepLedger ledger = engine.state.steps;
        expect(ledger.banked, ledger.totalGranted - ledger.totalSpent);
      }

      engine.execute(const AllocateSteps(steps: 300));
      final StepLedger after = engine.state.steps;
      expect(after.banked, after.totalGranted - after.totalSpent);
    });

    test('spent can never exceed granted', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 1000)], next: 'c1'),
      );

      expect(
        engine.execute(const AllocateSteps(steps: 1001)).isRejected,
        isTrue,
      );
      expect(
        engine.execute(const AllocateSteps(steps: 1000)).isAccepted,
        isTrue,
      );
      expect(engine.state.steps.totalSpent, 1000);
      expect(engine.state.steps.banked, 0);
      expect(engine.execute(const AllocateSteps(steps: 1)).isRejected, isTrue);
    });

    test('a ledger with spent above granted cannot be constructed', () {
      expect(
        () => StepLedger.initial().copyWith(totalSpent: 5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => StepLedger.initial().copyWith(totalGranted: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('spending refuses rather than clamping', () {
      final StepLedger ledger = StepLedger.initial().copyWith(
        totalGranted: 100,
      );

      expect(ledger.spending(101), isNull);
      expect(ledger.spending(0), isNull);
      expect(ledger.spending(-5), isNull);
      expect(ledger.spending(100)!.totalSpent, 100);
    });

    test(
      'granted ahead of observed is recorded after a downward correction',
      () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 900)], next: 'c1'),
        );
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 200)], next: 'c2'),
        );

        // The player keeps their progress; the discrepancy is simply visible, so
        // "why does the game say more than Health does?" has an answer.
        expect(engine.state.steps.grantedAheadOfObserved, 700);
      },
    );
  });

  group('generated sequences', () {
    /// Builds a long, awkward sync sequence and checks the properties hold at
    /// every step.
    void runSequence(int seed) {
      final Lcg random = Lcg(seed);
      final GameEngine engine = newEngine();
      final Map<int, int> lastObserved = <int, int>{};

      int previousGranted = 0;
      int previousSpent = 0;

      for (int step = 0; step < 120; step++) {
        final int bucketIndex = random.next(6);
        final StepOriginKey origin = random.chance(30) ? watch : phone;

        // A mix of new data, restatements, corrections, and deletions.
        final int steps = switch (random.next(10)) {
          0 => 0, // deletion
          1 || 2 => lastObserved[bucketIndex] ?? random.next(500), // replay
          _ => random.next(900),
        };
        lastObserved[bucketIndex] = steps;

        final EngineResult result = switch (random.next(12)) {
          0 => sync(engine, NoChangeSync(nextCursor: cursor('s$step'))),
          1 => sync(
            engine,
            const ProviderUnavailableSync(
              ProviderUnavailableReason.transientFailure,
            ),
          ),
          2 => sync(
            engine,
            rescan(
              <StepObservation>[obs(origin, bucketIndex, steps)],
              fromIndex: bucketIndex,
              toIndex: bucketIndex + 1,
              next: 's$step',
            ),
          ),
          _ => sync(
            engine,
            incremental(<StepObservation>[
              obs(origin, bucketIndex, steps),
            ], next: 's$step'),
          ),
        };

        final StepLedger ledger = engine.state.steps;

        expect(
          grantedBy(result),
          greaterThanOrEqualTo(0),
          reason: 'seed $seed step $step: a grant went negative',
        );
        expect(
          ledger.totalGranted,
          greaterThanOrEqualTo(previousGranted),
          reason: 'seed $seed step $step: granted decreased',
        );
        expect(
          ledger.totalSpent,
          lessThanOrEqualTo(ledger.totalGranted),
          reason: 'seed $seed step $step: spent exceeded granted',
        );
        expect(ledger.banked, ledger.totalGranted - ledger.totalSpent);
        expect(ledger.totalObserved, greaterThanOrEqualTo(0));

        previousGranted = ledger.totalGranted;
        previousSpent = ledger.totalSpent;

        // Occasionally spend, to keep the two halves interacting.
        if (random.chance(20) && ledger.banked > 10) {
          final int spend = 1 + random.next(ledger.banked);
          final EngineResult spent = engine.execute(
            AllocateSteps(steps: spend),
          );
          if (spent.isAccepted) {
            expect(engine.state.steps.totalSpent, previousSpent + spend);
            previousSpent = engine.state.steps.totalSpent;
          }
        }
      }
    }

    for (final int seed in <int>[1, 7, 42, 1337, 20260802]) {
      test('properties hold across a generated sequence (seed $seed)', () {
        runSequence(seed);
      });
    }

    test('the same seed produces the same ledger', () {
      String run(int seed) {
        final Lcg random = Lcg(seed);
        final GameEngine engine = newEngine();
        for (int i = 0; i < 40; i++) {
          sync(
            engine,
            incremental(<StepObservation>[
              obs(
                random.chance(50) ? phone : watch,
                random.next(5),
                random.next(600),
              ),
            ], next: 'c$i'),
          );
        }
        return engine.state.steps.signature;
      }

      expect(run(99), run(99));
      expect(run(99), isNot(run(100)));
    });
  });

  group('idempotence', () {
    test('replaying a batch any number of times grants once', () {
      final GameEngine engine = newEngine();
      final IncrementalSync batch = incremental(<StepObservation>[
        obs(phone, 0, 300),
        obs(watch, 0, 250),
      ], next: 'c1');

      sync(engine, batch);
      final int granted = engine.state.steps.totalGranted;

      for (int i = 0; i < 10; i++) {
        expect(grantedBy(sync(engine, batch)), 0);
      }
      expect(engine.state.steps.totalGranted, granted);
    });

    test('an interleaved replay does not disturb newer data', () {
      final GameEngine engine = newEngine();
      final IncrementalSync first = incremental(<StepObservation>[
        obs(phone, 0, 400),
      ], next: 'c1');

      sync(engine, first);
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 1, 600)], next: 'c2'),
      );
      sync(engine, first); // an old batch arrives again

      expect(engine.state.steps.totalGranted, 1000);
      expect(engine.state.steps.totalObserved, 1000);
    });
  });

  group('state safety', () {
    test('a snapshot taken before a sync is unchanged by it', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
      );
      final GameState before = engine.state;
      final String beforeSignature = canonicalDurableGameState(before);

      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 1, 700)], next: 'c2'),
      );

      expect(canonicalDurableGameState(before), beforeSignature);
      expect(before.steps.totalGranted, 500);
      expect(engine.state.steps.totalGranted, 1200);
    });

    test('the granted-slice map on a snapshot cannot be mutated', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
      );
      final StepLedger ledger = engine.state.steps;

      expect(
        () =>
            ledger.grantedSlices[ObservationKey(
                  origin: phone,
                  bucket: const TimeBucket(startMillis: 0, endMillis: 1),
                )] =
                9999,
        throwsUnsupportedError,
      );
    });

    test('an unavailable provider does not advance the cursor', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
      );

      for (final ProviderUnavailableReason reason
          in ProviderUnavailableReason.values) {
        final EngineResult result = sync(
          engine,
          ProviderUnavailableSync(reason),
        );
        expect(didAuthorizeCheckpoint(result), isFalse, reason: reason.name);
        expect(engine.state.steps.checkpoint.cursor, cursor('c1'));
        expect(engine.state.steps.totalGranted, 500);
      }
    });
  });

  group('bounded retention', () {
    test('old slices are compacted without losing granted totals', () {
      final GameEngine engine = newEngine();

      // Well beyond the 7-day retention window. Each sync asserts completeness
      // through the hour it delivered — a healthy provider with nothing
      // outstanding. Without that assertion nothing compacts, which is the
      // point of the two tests below.
      for (int day = 0; day < 14; day++) {
        sync(
          engine,
          incremental(
            <StepObservation>[obs(phone, day * 24, 1000)],
            next: 'd$day',
            completeThroughIndex: day * 24 + 1,
          ),
        );
      }

      final StepLedger ledger = engine.state.steps;

      expect(ledger.totalGranted, 14000, reason: 'no granted step may be lost');
      expect(
        ledger.grantedSlices.length,
        lessThan(14),
        reason:
            'slices past the horizon must be compacted, or the ledger '
            'becomes a step history',
      );
      expect(ledger.grantedBeforeWatermark, greaterThan(0));
      expect(ledger.checkpoint.watermarkMillis, isNotNull);
    });

    test('a settled slice is never granted again', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 800)], next: 'c1'),
      );

      // Push the watermark far past hour 0.
      for (int day = 1; day <= 12; day++) {
        sync(
          engine,
          incremental(
            <StepObservation>[obs(phone, day * 24, 100)],
            next: 'd$day',
            completeThroughIndex: day * 24 + 1,
          ),
        );
      }
      final int granted = engine.state.steps.totalGranted;

      // A rescan restating the long-settled hour must credit nothing.
      final EngineResult late = sync(
        engine,
        rescan(
          <StepObservation>[obs(phone, 0, 5000)],
          fromIndex: 0,
          toIndex: 1,
          next: 'late',
        ),
      );

      expect(grantedBy(late), 0);
      expect(engine.state.steps.totalGranted, granted);
    });
  });
}
