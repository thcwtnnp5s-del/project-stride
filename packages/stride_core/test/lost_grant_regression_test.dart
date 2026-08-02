// Regression tests for three lost-grant defects found by the F-05 Technical
// Critic review, 2026-08-02.
//
// All three shared one root cause: the settled watermark was *inferred* from
// the newest bucket the core happened to have been handed, rather than
// *asserted* by the adapter that knows what it has delivered. Data arriving
// later but timestamped older than `newest - retention` was silently dropped —
// no event, no counter, no divergence in any diagnostic, and no recovery on
// retry, because the retry consults exactly the field that lied.
//
// Two of the three require no crash at all. They are ordinary provider
// behaviour: HealthKit anchored queries and Health Connect change tokens both
// page, and a watch that has been offline uploads its backlog whenever it
// reconnects.
//
// The fix is that the core never infers completeness. `completeThroughMillis`
// is an assertion the adapter makes; absent it, nothing compacts and the
// watermark does not move. These tests fail against the pre-fix reconciler.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  group('lost grants (F-05 critic review)', () {
    test('a newest-first paginated backfill loses nothing', () {
      // A 30-day cold-launch backfill delivered as two pages, newest first.
      // Pre-fix this granted 9,600 of 64,800 steps and destroyed the rest:
      // page 1 settled the watermark 7 days back from *its own* newest hour,
      // and every bucket in page 2 was then already behind it.
      final GameEngine engine = newEngine();

      final EngineResult page1 = sync(
        engine,
        incremental(<StepObservation>[
          for (int h = 648; h < 720; h++) obs(phone, h, 100),
        ], next: 'p1'),
      );

      final EngineResult page2 = sync(
        engine,
        incremental(<StepObservation>[
          for (int h = 0; h < 648; h++) obs(phone, h, 100),
        ], next: 'p2'),
      );

      expect(grantedBy(page1), 7200);
      expect(
        grantedBy(page2),
        64800,
        reason: 'the older page is real movement and must be credited in full',
      );
      expect(engine.state.steps.totalGranted, 72000);
      expect(
        engine.state.steps.lateDiscardedSlices,
        0,
        reason: 'nothing was discarded, so nothing may be counted as discarded',
      );
    });

    test('a device that was offline can still backfill', () {
      // The player walks, goes away for twenty days, walks again — and only
      // then does an offline watch reconnect and upload the walk it recorded
      // in between. Pre-fix the phone's recent slice had already settled the
      // watermark past the watch's window, and 8,000 real steps vanished.
      //
      // This one lands directly on the Kernel: the failure mode is precisely
      // "the player went away, so their steps did not count."
      final GameEngine engine = newEngine();

      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'a'),
      );
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 480, 500)], next: 'b'),
      );

      final EngineResult lateWatch = sync(
        engine,
        incremental(<StepObservation>[obs(watch, 120, 8000)], next: 'c'),
      );

      expect(
        grantedBy(lateWatch),
        8000,
        reason:
            'one origin being current says nothing about whether another '
            'origin has finished delivering',
      );
      expect(engine.state.steps.totalGranted, 9000);
    });

    test('compaction requires an assertion, and never an inference', () {
      // The structural statement of the fix: identical data, and the only
      // difference is whether the adapter claimed completeness.
      GameEngine build({int? completeThrough}) {
        final GameEngine engine = newEngine();
        for (int day = 0; day < 14; day++) {
          sync(
            engine,
            incremental(
              <StepObservation>[obs(phone, day * 24, 1000)],
              next: 'd$day',
              completeThroughIndex: completeThrough == null
                  ? null
                  : day * 24 + 1,
            ),
          );
        }
        return engine;
      }

      final StepLedger silent = build().state.steps;
      final StepLedger asserted = build(completeThrough: 1).state.steps;

      expect(silent.totalGranted, 14000);
      expect(asserted.totalGranted, 14000);

      expect(
        silent.grantedSlices.length,
        14,
        reason: 'no assertion means no compaction — the ledger grows instead',
      );
      expect(silent.checkpoint.watermarkMillis, isNull);

      expect(
        asserted.grantedSlices.length,
        lessThan(14),
        reason: 'an assertion permits compaction, which bounds the ledger',
      );
      expect(asserted.checkpoint.watermarkMillis, isNotNull);
    });

    test('the watermark never advances past what compaction actually kept', () {
      // The defect's real home. Compaction correctly declined to drop the
      // older page while a separately-recomputed watermark advanced past it
      // regardless. The two figures are now the same figure.
      final GameEngine engine = newEngine();

      sync(
        engine,
        incremental(
          <StepObservation>[for (int h = 0; h < 480; h++) obs(phone, h, 10)],
          next: 'x',
          completeThroughIndex: 300,
        ),
      );

      final StepLedger ledger = engine.state.steps;
      final int watermark = ledger.checkpoint.watermarkMillis!;

      for (final ObservationKey key in ledger.grantedSlices.keys) {
        expect(
          key.bucket.endMillis,
          greaterThan(watermark),
          reason: 'a retained slice must never be behind the settled floor',
        );
      }
      expect(
        watermark,
        lessThanOrEqualTo(t0 + 300 * hour),
        reason:
            'the adapter asserted completeness only through hour 300; '
            'nothing past that may be settled',
      );
      expect(ledger.totalGranted, 4800);
    });

    test('a genuinely late slice is counted, never silently dropped', () {
      // The residual loss the design still permits: a record arriving after
      // its bucket was compacted cannot be granted, because the evidence of
      // whether it was already credited is gone. That is a defensible trade —
      // but it must be countable. A loss you can count is a bug; a loss you
      // cannot count is a haunting.
      final GameEngine engine = newEngine();

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
      expect(engine.state.steps.lateDiscardedSlices, 0);

      final EngineResult late = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 5000)], next: 'late'),
      );

      expect(
        grantedBy(late),
        0,
        reason: 'a settled slice cannot be re-granted',
      );
      expect(
        engine.state.steps.lateDiscardedSlices,
        1,
        reason: 'and the discard must be visible to anyone investigating',
      );
    });
  });

  _bucketWidth();
}

// Bucket resolution is a privacy bound, not a correctness one.
//
// Found by the F-05 Privacy Auditor: the ruling bounds retention *length* and
// says nothing about *resolution*. Minute buckets would have been fully
// compliant as written and would have produced a minute-by-minute record of
// when the player moved, kept for a week.
void _bucketWidth() {
  group('bucket resolution', () {
    test('a batch finer than the minimum width is refused', () {
      final GameEngine engine = newEngine();
      const int minute = 60 * 1000;

      final EngineResult result = sync(
        engine,
        IncrementalSync(
          observations: <StepObservation>[
            StepObservation(
              key: ObservationKey(
                origin: phone,
                bucket: TimeBucket(startMillis: t0, endMillis: t0 + minute),
              ),
              steps: 400,
            ),
          ],
          nextCursor: cursor('fine'),
        ),
      );

      expect(result.isRejected, isTrue);
      expect(
        engine.state.steps.totalGranted,
        0,
        reason: 'a refused batch must not move the ledger at all',
      );
      expect(engine.state.steps.checkpoint.cursor, isNull);
    });

    test('the refusal names no bucket bounds', () {
      // The explanation reaches diagnostics, and a bucket is health-derived.
      final GameEngine engine = newEngine();
      final EngineResult result = sync(
        engine,
        IncrementalSync(
          observations: <StepObservation>[
            StepObservation(
              key: ObservationKey(
                origin: phone,
                bucket: TimeBucket(startMillis: t0, endMillis: t0 + 1000),
              ),
              steps: 5,
            ),
          ],
        ),
      );

      final String text = result.rejection!.explanation;
      expect(text, isNot(contains('$t0')));
      expect(text, isNot(contains(phone.value)));
    });

    test('an hour bucket is accepted', () {
      // The boundary itself, so the constant cannot drift upward unnoticed.
      final GameEngine engine = newEngine();
      expect(
        grantedBy(
          sync(
            engine,
            incremental(<StepObservation>[obs(phone, 0, 613)], next: 'ok'),
          ),
        ),
        613,
      );
      expect(TimeBucket.minimumWidthMillis, 60 * 60 * 1000);
    });
  });
}
