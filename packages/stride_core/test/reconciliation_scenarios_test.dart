// The thirteen canonical reconciliation scenarios.
//
// Black-box: every assertion is on an observable outcome — steps newly granted,
// final observed, final granted, checkpoint disposition, recovery state, retry
// safety. **No test asserts the arithmetic.** The recovery mechanism is an
// implementation hypothesis and may change; these must survive that change or
// they are not testing the contract.
//
// This is the project's primary defence against risk A-01. A double-count or a
// lost step is invisible until a player notices their walk did not count, and
// by then the ledger has been wrong for weeks.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  group('the thirteen scenarios', () {
    // -- 1 ------------------------------------------------------------------
    test('1. first synchronization', () {
      final GameEngine engine = newEngine();
      expect(engine.state.steps.totalGranted, 0);

      final EngineResult result = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 1200),
          obs(phone, 1, 800),
        ], next: 'c1'),
      );

      expect(result.isAccepted, isTrue);
      expect(grantedBy(result), 2000);
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.totalObserved, 2000);
      expect(engine.state.steps.banked, 2000);
      expect(authorizedCursor(result), cursor('c1'));
      expect(engine.state.steps.recovery.isActive, isFalse);
    });

    // -- 2 ------------------------------------------------------------------
    test('2. normal incremental synchronization', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 1200)], next: 'c1'),
      );

      final EngineResult second = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 1, 500)], next: 'c2'),
      );

      // Only the new slice is credited.
      expect(grantedBy(second), 500);
      expect(engine.state.steps.totalGranted, 1700);
      expect(engine.state.steps.totalObserved, 1700);
      expect(authorizedCursor(second), cursor('c2'));
    });

    // -- 3 ------------------------------------------------------------------
    test('3. identical batch replay grants nothing and changes nothing', () {
      final GameEngine engine = newEngine();
      final IncrementalSync batch = incremental(<StepObservation>[
        obs(phone, 0, 1200),
        obs(phone, 1, 800),
      ], next: 'c1');

      sync(engine, batch);
      final String afterFirst = engine.state.steps.signature;
      final int syncCountAfterFirst = engine.state.steps.checkpoint.syncCount;

      final EngineResult replay = sync(engine, batch);

      expect(grantedBy(replay), 0, reason: 'a replay must credit nothing');
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.totalObserved, 2000);

      // The ledger is otherwise identical; only the sync counter advanced,
      // which is how a repeated reconciliation is distinguishable from one
      // that never happened without needing a clock.
      expect(
        engine.state.steps
            .copyWith(
              checkpoint: SyncCheckpoint(
                cursor: engine.state.steps.checkpoint.cursor,
                watermarkMillis: engine.state.steps.checkpoint.watermarkMillis,
                syncCount: syncCountAfterFirst,
              ),
            )
            .signature,
        afterFirst,
      );
    });

    // -- 4 ------------------------------------------------------------------
    test('4. overlapping batches do not double-count', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 1000),
          obs(phone, 1, 1000),
        ], next: 'c1'),
      );

      // The second batch restates hour 1 and adds hour 2.
      final EngineResult overlapping = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 1, 1000),
          obs(phone, 2, 700),
        ], next: 'c2'),
      );

      expect(grantedBy(overlapping), 700, reason: 'only the new hour counts');
      expect(engine.state.steps.totalGranted, 2700);
      expect(engine.state.steps.totalObserved, 2700);
    });

    // -- 5 ------------------------------------------------------------------
    test('5. delayed records are granted when they arrive', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 2, 900)], next: 'c1'),
      );

      // Hour 0 shows up late, after a later hour was already synced.
      final EngineResult late = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 400)], next: 'c2'),
      );

      expect(grantedBy(late), 400);
      expect(engine.state.steps.totalGranted, 1300);
      expect(engine.state.steps.totalObserved, 1300);
    });

    // -- 6 ------------------------------------------------------------------
    test('6. upward correction grants only the increase', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
      );

      final EngineResult corrected = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 800)], next: 'c2'),
      );

      expect(
        grantedBy(corrected),
        300,
        reason: 'not 800 — 500 was already credited',
      );
      expect(engine.state.steps.totalGranted, 800);
      expect(engine.state.steps.totalObserved, 800);
    });

    // -- 7 ------------------------------------------------------------------
    test('7. downward correction lowers observed but never granted', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 1000)], next: 'c1'),
      );

      final EngineResult corrected = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 400)], next: 'c2'),
      );

      expect(grantedBy(corrected), 0);
      expect(
        engine.state.steps.totalGranted,
        1000,
        reason: 'no clawback, ever',
      );
      expect(engine.state.steps.totalObserved, 400);
      expect(engine.state.steps.banked, 1000);
      expect(engine.state.steps.correctionsObserved, 1);

      // No removal event exists to be reacted to.
      expect(
        corrected.events.map((GameEvent e) => e.name),
        isNot(contains('StepsRemoved')),
      );

      // And restating the original figure must not re-grant it.
      final EngineResult restored = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 1000)], next: 'c3'),
      );
      expect(grantedBy(restored), 0, reason: 'already credited once');
      expect(engine.state.steps.totalGranted, 1000);
    });

    // -- 8 ------------------------------------------------------------------
    test('8. deletion lowers observed and preserves granted', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 600),
          obs(phone, 1, 600),
        ], next: 'c1'),
      );

      // Hour 0 deleted entirely.
      final EngineResult deleted = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 0)], next: 'c2'),
      );

      expect(grantedBy(deleted), 0);
      expect(engine.state.steps.totalGranted, 1200);
      expect(engine.state.steps.totalObserved, 600);
      expect(engine.state.steps.banked, 1200);
    });

    // -- 9 ------------------------------------------------------------------
    test(
      '9. interruption before ledger commit changes nothing and retries safely',
      () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 700)], next: 'c1'),
        );
        final GameState committed = engine.state;

        // A sync whose events are computed and then dropped — the process died
        // before the reducer ran.
        final GameEngine doomed = GameEngine(
          registry: stepRegistry,
          state: committed,
        );
        final EngineResult planned = sync(
          doomed,
          incremental(<StepObservation>[obs(phone, 1, 300)], next: 'c2'),
        );
        expect(planned.isAccepted, isTrue);

        // The original state never saw those events.
        expect(committed.steps.totalGranted, 700);
        expect(committed.steps.checkpoint.cursor, cursor('c1'));

        // Retrying from the uncommitted state produces the same answer.
        final GameEngine retry = GameEngine(
          registry: stepRegistry,
          state: committed,
        );
        final EngineResult retried = sync(
          retry,
          incremental(<StepObservation>[obs(phone, 1, 300)], next: 'c2'),
        );

        expect(grantedBy(retried), 300);
        expect(retry.state.steps.totalGranted, 1000);
      },
    );

    // -- 10 -----------------------------------------------------------------
    test('10. ledger committed but checkpoint interrupted is retry-safe', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 700)], next: 'c1'),
      );
      final GameState before = engine.state;

      final EngineResult result = sync(
        GameEngine(registry: stepRegistry, state: before),
        incremental(<StepObservation>[obs(phone, 1, 500)], next: 'c2'),
      );

      // The grant lands; the checkpoint authorization does not.
      final GameState partial = commitWithoutCheckpoint(before, result.events);

      expect(partial.steps.totalGranted, 1200, reason: 'the grant committed');
      expect(
        partial.steps.checkpoint.cursor,
        cursor('c1'),
        reason:
            'the cursor must still be the old one — authorizing it before '
            'the ledger commits is what would lose steps on a crash',
      );

      // Resuming from the old cursor replays the same batch. It must credit
      // nothing, because the grant already committed.
      final GameEngine resumed = GameEngine(
        registry: stepRegistry,
        state: partial,
      );
      final EngineResult replay = sync(
        resumed,
        incremental(<StepObservation>[obs(phone, 1, 500)], next: 'c2'),
      );

      expect(
        grantedBy(replay),
        0,
        reason: 'no double-grant after a partial commit',
      );
      expect(resumed.state.steps.totalGranted, 1200);
      expect(resumed.state.steps.checkpoint.cursor, cursor('c2'));
    });

    // -- 11 -----------------------------------------------------------------
    test('11. multiple origins are counted separately, never merged', () {
      final GameEngine engine = newEngine();

      // Two devices report the same hour. Both are real; neither cancels the
      // other, and neither is double-counted on replay.
      final EngineResult first = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 1000),
          obs(watch, 0, 900),
        ], next: 'c1'),
      );
      expect(grantedBy(first), 1900);

      // Replaying only the watch's slice grants nothing further.
      final EngineResult replay = sync(
        engine,
        incremental(<StepObservation>[obs(watch, 0, 900)], next: 'c2'),
      );
      expect(grantedBy(replay), 0);

      // A correction to one origin does not disturb the other.
      final EngineResult corrected = sync(
        engine,
        incremental(<StepObservation>[obs(watch, 0, 200)], next: 'c3'),
      );
      expect(grantedBy(corrected), 0);
      expect(engine.state.steps.totalGranted, 1900);
      expect(engine.state.steps.totalObserved, 1200);
    });

    // -- 12 -----------------------------------------------------------------
    test(
      '12. an empty no-change sync grants nothing and still advances the cursor',
      () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 400)], next: 'c1'),
        );
        final int grantedBefore = engine.state.steps.totalGranted;

        final EngineResult empty = sync(
          engine,
          NoChangeSync(nextCursor: cursor('c2')),
        );

        expect(empty.isAccepted, isTrue);
        expect(grantedBy(empty), 0);
        expect(engine.state.steps.totalGranted, grantedBefore);
        expect(authorizedCursor(empty), cursor('c2'));

        // An incremental batch with no observations behaves the same way.
        final EngineResult none = sync(
          engine,
          incremental(const <StepObservation>[], next: 'c3'),
        );
        expect(grantedBy(none), 0);
        expect(engine.state.steps.totalGranted, grantedBefore);
      },
    );

    // -- 13 -----------------------------------------------------------------
    group('13. expired cursor with bounded authoritative recovery', () {
      test('recovery grants only what was not already credited', () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[
            obs(phone, 0, 500),
            obs(phone, 1, 500),
          ], next: 'c1'),
        );

        // The token expires. The provider answers with an authoritative re-read
        // of the window, which restates what was already granted and adds more.
        final EngineResult recovered = sync(
          engine,
          rescan(
            <StepObservation>[
              obs(phone, 0, 500),
              obs(phone, 1, 500),
              obs(phone, 2, 300),
            ],
            fromIndex: 0,
            toIndex: 3,
            next: 'c2',
          ),
        );

        expect(
          grantedBy(recovered),
          300,
          reason: 'not 1300 — the rest was credited',
        );
        expect(engine.state.steps.totalGranted, 1300);
        expect(engine.state.steps.recovery.isActive, isFalse);
        expect(authorizedCursor(recovered), cursor('c2'));
      });

      test('the ledger is never reset', () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 900)], next: 'c1'),
        );

        // A rescan reporting far less than was granted.
        sync(
          engine,
          rescan(
            <StepObservation>[obs(phone, 0, 100)],
            fromIndex: 0,
            toIndex: 1,
            next: 'c2',
          ),
        );

        expect(engine.state.steps.totalGranted, 900, reason: 'no clawback');
        expect(engine.state.steps.totalObserved, 100);
      });

      test('a full-history rescan does not re-grant', () {
        final GameEngine engine = newEngine();
        final List<StepObservation> history = <StepObservation>[
          for (int i = 0; i < 12; i++) obs(phone, i, 100),
        ];
        sync(engine, incremental(history, next: 'c1'));
        expect(engine.state.steps.totalGranted, 1200);

        final EngineResult recovered = sync(
          engine,
          rescan(history, fromIndex: 0, toIndex: 12, next: 'c2'),
        );

        expect(
          grantedBy(recovered),
          0,
          reason: 'the accidental full-history grant',
        );
        expect(engine.state.steps.totalGranted, 1200);
      });

      test('a truncated window records the gap and grants nothing for it', () {
        final GameEngine engine = newEngine();

        final EngineResult recovered = sync(
          engine,
          rescan(
            <StepObservation>[obs(phone, 5, 400)],
            fromIndex: 5,
            toIndex: 6,
            truncated: true,
            next: 'c1',
          ),
        );

        expect(recovered.isAccepted, isTrue);
        expect(engine.state.steps.unreachableGapEvents, 1);
        // Only what the window actually contained is credited. The unreachable
        // gap is recorded, never invented.
        expect(grantedBy(recovered), 400);
      });

      test('recovery interrupted before commit is safe to retry', () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
        );
        final GameState before = engine.state;

        final CursorInvalidatedSync response = rescan(
          <StepObservation>[obs(phone, 0, 500), obs(phone, 1, 400)],
          fromIndex: 0,
          toIndex: 2,
          next: 'c2',
        );

        // First attempt dies before the reducer runs.
        sync(GameEngine(registry: stepRegistry, state: before), response);
        expect(before.steps.totalGranted, 500);
        expect(before.steps.checkpoint.cursor, cursor('c1'));

        // Retry produces the same answer.
        final GameEngine retry = GameEngine(
          registry: stepRegistry,
          state: before,
        );
        final EngineResult retried = sync(retry, response);

        expect(grantedBy(retried), 400);
        expect(retry.state.steps.totalGranted, 900);
        expect(retry.state.steps.recovery.isActive, isFalse);
      });

      test('recovery interrupted mid-flight is recorded as unfinished', () {
        final GameEngine engine = newEngine();
        sync(
          engine,
          incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
        );
        final GameState before = engine.state;

        final CursorInvalidatedSync response = rescan(
          <StepObservation>[obs(phone, 0, 500), obs(phone, 1, 400)],
          fromIndex: 0,
          toIndex: 2,
          next: 'c2',
        );
        final EngineResult planned = sync(
          GameEngine(registry: stepRegistry, state: before),
          response,
        );

        // Death immediately after the recovery was announced and before
        // anything was reconciled — the one case where the ledger must be able
        // to say "a recovery began and never finished".
        final List<GameEvent> onlyStart = planned.events
            .takeWhile((GameEvent e) => e is! StepObservationReconciled)
            .toList();
        final GameState midFlight = const EventReducer().applyAll(
          before,
          onlyStart,
        );

        expect(midFlight.steps.recovery.isActive, isTrue);
        expect(midFlight.steps.recovery.attempts, 1);
        expect(
          midFlight.steps.totalGranted,
          500,
          reason: 'nothing granted yet',
        );
        expect(midFlight.steps.checkpoint.cursor, cursor('c1'));

        // Retrying from there completes cleanly and grants the same 400.
        final GameEngine retry = GameEngine(
          registry: stepRegistry,
          state: midFlight,
        );
        final EngineResult retried = sync(retry, response);

        expect(grantedBy(retried), 400);
        expect(retry.state.steps.totalGranted, 900);
        expect(retry.state.steps.recovery.isActive, isFalse);
      });

      test(
        'recovery interrupted after grant but before checkpoint is retry-safe',
        () {
          final GameEngine engine = newEngine();
          sync(
            engine,
            incremental(<StepObservation>[obs(phone, 0, 500)], next: 'c1'),
          );
          final GameState before = engine.state;

          final CursorInvalidatedSync response = rescan(
            <StepObservation>[obs(phone, 0, 500), obs(phone, 1, 400)],
            fromIndex: 0,
            toIndex: 2,
            next: 'c2',
          );

          final EngineResult planned = sync(
            GameEngine(registry: stepRegistry, state: before),
            response,
          );
          final GameState partial = commitWithoutCheckpoint(
            before,
            planned.events,
          );

          expect(partial.steps.totalGranted, 900);
          expect(partial.steps.checkpoint.cursor, cursor('c1'));
          // Recovery genuinely completed — `StepRecoveryCompleted` precedes the
          // checkpoint, and the ledger was consistent before the cursor was
          // authorized. Only cursor persistence was lost, which is the cheapest
          // possible thing to lose: the retry replays and grants nothing.
          expect(partial.steps.recovery.isActive, isFalse);

          final GameEngine resumed = GameEngine(
            registry: stepRegistry,
            state: partial,
          );
          final EngineResult replay = sync(resumed, response);

          expect(grantedBy(replay), 0, reason: 'no double-grant');
          expect(resumed.state.steps.totalGranted, 900);
          expect(resumed.state.steps.recovery.isActive, isFalse);
          expect(resumed.state.steps.checkpoint.cursor, cursor('c2'));
        },
      );
    });
  });

  group('provider unavailability', () {
    test('an unavailable service leaves the ledger untouched', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 300)], next: 'c1'),
      );
      final String before = engine.state.steps.signature;

      final EngineResult result = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.serviceUnavailable,
        ),
      );

      expect(result.isAccepted, isTrue, reason: 'absence is not an error');
      expect(grantedBy(result), 0);
      expect(engine.state.steps.totalGranted, 300);
      expect(engine.state.steps.checkpoint.cursor, cursor('c1'));
      expect(engine.state.steps.sourceState, SourceState.serviceUnavailable);
      expect(
        didAuthorizeCheckpoint(result),
        isFalse,
        reason: 'a failed read must not advance the cursor',
      );
      expect(engine.state.steps.signature, isNot(before)); // only sourceState
    });

    test('permission unavailable is reported, not thrown', () {
      final GameEngine engine = newEngine();
      final EngineResult result = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.permissionUnavailable,
        ),
      );

      expect(result.isAccepted, isTrue);
      expect(engine.state.steps.sourceState, SourceState.permissionUnavailable);
      expect(engine.state.steps.totalGranted, 0);
    });

    test('a repeated failure does not fill the event stream', () {
      final GameEngine engine = newEngine();
      const ProviderUnavailableSync down = ProviderUnavailableSync(
        ProviderUnavailableReason.transientFailure,
      );

      final EngineResult first = sync(engine, down);
      final EngineResult second = sync(engine, down);

      expect(first.events, isNotEmpty);
      expect(second.events, isEmpty, reason: 'nothing new to say');
    });

    test('a malformed batch is rejected, not thrown', () {
      final GameEngine engine = newEngine();
      final EngineResult result = sync(
        engine,
        CursorInvalidatedSync(
          window: const RescanWindow(
            startMillis: 5000,
            endMillis: 1000,
            truncated: false,
          ),
          observations: const <StepObservation>[],
        ),
      );

      expect(result.isRejected, isTrue);
      expect(result.rejection!.code, RejectionCode.malformedSyncBatch);
    });
  });
}
