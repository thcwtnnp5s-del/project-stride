// The Q-08 reproduction, named as a suite instead of implied by one scenario.
//
// On the owner's phone the Oura app showed 3,121 while Stride showed 5,732 —
// the shape this file pins: **two Health sources covering the same walking
// hours are two sets of `(origin, bucket)` keys, and the ledger sums them by
// design** (`RULES.md` H-1; `reconciliation.dart`'s own table row: "Multiple
// origins | Different keys, counted separately, never merged"). These tests
// document CURRENT semantics — Fable V2 Iteration 02, forensics outcome B —
// so that any future change to overlap accounting (Q-08's owner decision)
// fails loudly here and is made deliberately, never by drift.
//
// Nothing here prescribes a fix. The one arithmetic that would match the
// Health app's headline (Apple's priority-de-duplicated merge) is a figure
// the adapter deliberately never reads.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  group('case 4 — two origins over the same walking hours', () {
    test('the bank gains both origins\' sums — 3,000 + 2,900 banks 5,900', () {
      final GameEngine engine = newEngine();

      // The afternoon of the owner's screenshot, as the adapter would emit
      // it: per-source absolute totals for the same two hour buckets.
      final EngineResult first = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 13, 1500),
          obs(phone, 14, 1500),
          obs(watch, 13, 1450),
          obs(watch, 14, 1450),
        ], next: 'c1'),
      );

      expect(first.isAccepted, isTrue, reason: '${first.rejection}');
      expect(
        grantedBy(first),
        5900,
        reason:
            'four distinct (origin, bucket) keys — the overlap is never '
            'correlated, by design (Q-08 option 1, the current semantics)',
      );
      expect(engine.state.steps.banked, 5900);

      // A full replay of both origins grants nothing: idempotence holds
      // per key even while the semantic overlap stands.
      final EngineResult replay = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 13, 1500),
          obs(phone, 14, 1500),
          obs(watch, 13, 1450),
          obs(watch, 14, 1450),
        ], next: 'c2'),
      );
      expect(grantedBy(replay), 0);
      expect(engine.state.steps.banked, 5900);

      // One origin restated alone re-grants nothing either.
      final EngineResult watchOnly = sync(
        engine,
        incremental(<StepObservation>[
          obs(watch, 13, 1450),
          obs(watch, 14, 1450),
        ], next: 'c3'),
      );
      expect(grantedBy(watchOnly), 0);
      expect(engine.state.steps.banked, 5900);
    });
  });

  group('case 5 — a wearable batch arriving after the phone was granted', () {
    test('same-day late origin is credited in full, never settled away', () {
      final GameEngine engine = newEngine();

      // The phone syncs first, with the adapter's real completeness shape:
      // scoped to the origins it saw — the phone only.
      final EngineResult phoneFirst = sync(
        engine,
        incremental(
          <StepObservation>[obs(phone, 13, 1500), obs(phone, 14, 1500)],
          next: 'c1',
          completeness: completeThrough(
            15,
            origins: <StepOriginKey>{phone},
          ),
        ),
      );
      expect(grantedBy(phoneFirst), 3000);

      // The phone-scoped completeness must not have settled the watch: an
      // origin the scope never covered has no watermark to refuse by.
      expect(
        engine.state.steps.checkpoint.originWatermarks.containsKey(watch),
        isFalse,
        reason:
            'a SomeOrigins scope vouches only for the origins it names '
            '(the multi-device backlog argument H-1 preserves)',
      );

      // The wearable's batch for those same past hours lands later — the
      // late-sync shape the owner's device shows — and is granted in full.
      final EngineResult watchLate = sync(
        engine,
        incremental(<StepObservation>[
          obs(watch, 13, 1450),
          obs(watch, 14, 1450),
        ], next: 'c2'),
      );
      expect(grantedBy(watchLate), 2900);
      expect(engine.state.steps.banked, 5900);
    });
  });

  group('case 7 — bucket identity is the only overlap guard', () {
    test('a misaligned bucket from one origin would double-grant; the '
        'alignment invariant lives in the adapter\'s epoch grid', () {
      final GameEngine engine = newEngine();

      final EngineResult aligned = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
      );
      expect(grantedBy(aligned), 500);

      // Same origin, same physical half-hour inside it, but a bucket shifted
      // by 30 minutes: a different (origin, bucket) key, so the ledger
      // grants it in full. The iOS adapter makes this shape impossible —
      // every bucket is floored onto an epoch-anchored UTC grid
      // (`HealthKitStepStore.swift`) — so this test is the tripwire for any
      // future bucket-width or adapter change that would break that grid.
      final EngineResult shifted = sync(
        engine,
        incremental(<StepObservation>[
          StepObservation(
            key: ObservationKey(
              origin: phone,
              bucket: TimeBucket(
                startMillis: t0 + hour ~/ 2,
                endMillis: t0 + hour + hour ~/ 2,
              ),
            ),
            steps: 500,
          ),
        ], next: 'c2'),
      );
      expect(
        grantedBy(shifted),
        500,
        reason:
            'CURRENT semantics: bucket identity is exact (start, end); '
            'nothing correlates overlapping intervals — the grid upstream '
            'is the real invariant',
      );
      expect(engine.state.steps.banked, 1000);
    });
  });

  group('case 8 edge — a pre-epoch bucket restated upward', () {
    test('after a playtest reset, only the increase lands in the new bank',
        () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 600)], next: 'c1'),
      );
      expect(engine.state.steps.banked, 600);

      // The owner's reset (`DECISIONS/0025`): counters re-marked, slices,
      // watermarks and cursor untouched.
      final EngineResult reset = engine.execute(
        const ResetPlaytest(stateVersion: 9, freshStart: false),
      );
      expect(reset.isAccepted, isTrue, reason: '${reset.rejection}');
      expect(engine.state.steps.banked, 0);

      // The same bucket restated upward — a late source correction. Only
      // the +100 delta is new, and only it enters the post-reset bank.
      final EngineResult restated = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 700)], next: 'c2'),
      );
      expect(grantedBy(restated), 100);
      expect(
        engine.state.steps.banked,
        100,
        reason:
            'the retained slice map is what stops the old 600 rebanking; '
            'the delta is genuinely new walking-record and is credited',
      );
    });
  });
}
