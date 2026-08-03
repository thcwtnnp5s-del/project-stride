// The adapter-to-ledger path, end to end, in pure Dart.
//
// `reconciliation_scenarios_test.dart` proves the reconciler's arithmetic from a
// hand-built `SyncResponse`. `platform_step_source_test.dart` proves the
// bridge's translation rules from a fabricated `PlatformSyncPage`. Neither runs
// the two together — and the gap between them is precisely where
// `DECISIONS/0014` found an entire ingestion model wired to nothing.
//
// So every test here starts from a `PlatformSyncPage` (or a scripted
// `MockStepSource`) and asserts on what the LEDGER ends up saying: steps
// granted, totals, cursor disposition, completeness horizon, source state.
// Nothing asserts the recovery arithmetic; the mechanism is a hypothesis and a
// test pinned to it is a test that will be weakened later.
//
// No device, no channel, no emulator, no health service, no wall clock.
//
// Two scenarios could not be made to pass and are NOT here: they live in
// `adapter_to_ledger_defects_test.dart`, failing, each naming a production
// defect. They were not adjusted into passing shape.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'adapter_ledger_support.dart';

void main() {
  _refusals(); // 1, 2, 17
  _ordinaryTraffic(); // 3, 4, 5, 6, 8, 9, 10, 11
  _pagination(); // 7, 13
  _origins(); // 12
  _commitOrder(); // 14, 15
  _recovery(); // 16
  _privacy(); // 18, 19, 20
}

// ===========================================================================
// 1, 2, 17 — the provider says no
// ===========================================================================

void _refusals() {
  group('a refusal is a state, never an error', () {
    /// A ledger with real progress, so "nothing changed" is a claim with
    /// something to lose. A refusal against an empty ledger proves very little.
    GameEngine engineWithProgress() {
      final GameEngine engine = newEngine();
      final EngineResult seeded = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 2000)],
          nextCursor: 'seed',
        ),
      );
      expect(seeded.isAccepted, isTrue);
      expect(engine.state.steps.totalGranted, 2000);
      return engine;
    }

    // -- 17 -----------------------------------------------------------------
    test(
      '17. every platform reason maps to its own core reason and retryability',
      () {
        expect(
          expectedRefusals.keys.toSet(),
          PlatformUnavailableReason.values.toSet(),
          reason:
              'a new platform reason must be given a core mapping here rather '
              'than defaulting into an existing one',
        );

        expectedRefusals.forEach((
          PlatformUnavailableReason platform,
          (ProviderUnavailableReason, ReconciliationCode, bool, SourceState)
          want,
        ) {
          final SyncFetch fetch = translate(
            ppage(
              status: PlatformSyncStatus.unavailable,
              unavailableReason: platform,
            ),
          );

          expect(
            (fetch.response as ProviderUnavailableSync).reason,
            want.$1,
            reason: '$platform must reach the core as ${want.$1}',
          );

          final ReconciliationRefused refused =
              StepReconciler().reconcile(
                    ledger: StepLedger.initial(),
                    response: fetch.response,
                  )
                  as ReconciliationRefused;
          expect(refused.code, want.$2, reason: '$platform refusal code');
          expect(
            refused.retryable,
            want.$3,
            reason:
                '$platform retryability. Reporting a fail-closed configuration '
                'fault as retryable invites a loop against a condition looping '
                'can never clear.',
          );

          final GameEngine engine = newEngine();
          reconcile(engine, fetch);
          expect(
            engine.state.steps.sourceState,
            want.$4,
            reason: '$platform must reach the player-facing source state',
          );
        });
      },
    );

    // -- 1 ------------------------------------------------------------------
    test('1. a denied permission grants nothing and moves no cursor', () {
      final GameEngine engine = engineWithProgress();
      final SyncCursor? before = engine.state.steps.checkpoint.cursor;
      final int syncCountBefore = engine.state.steps.checkpoint.syncCount;

      final EngineResult result = ingest(
        engine,
        ppage(
          status: PlatformSyncStatus.unavailable,
          unavailableReason: PlatformUnavailableReason.permissionUnavailable,
        ),
      );

      expect(result.isAccepted, isTrue, reason: 'denial is not an error');
      expect(grantedBy(result), 0);
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.banked, 2000);
      expect(
        didAuthorizeCheckpoint(result),
        isFalse,
        reason: 'a failed read must not advance the cursor',
      );
      expect(engine.state.steps.checkpoint.cursor, before);
      expect(
        engine.state.steps.checkpoint.syncCount,
        syncCountBefore,
        reason: 'a refused read is not a synchronization',
      );
      expect(engine.state.steps.sourceState, SourceState.permissionUnavailable);

      // The mock reports the same condition on the authorization port, and it
      // reports rather than throws.
      expect(
        MockStepSource(
          authorization: HealthAuthorization.denied,
        ).requestAuthorization(),
        completion(HealthAuthorization.denied),
      );
    });

    // -- 2 ------------------------------------------------------------------
    test('2. an unavailable service leaves the ledger and cursor untouched', () {
      final GameEngine engine = engineWithProgress();
      final String before = engine.state.steps.signature;

      final EngineResult result = ingest(
        engine,
        ppage(
          status: PlatformSyncStatus.unavailable,
          unavailableReason: PlatformUnavailableReason.serviceMissing,
        ),
      );

      expect(result.isAccepted, isTrue, reason: 'absence is not an error');
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.checkpoint.cursor, cursor('seed'));
      expect(engine.state.steps.sourceState, SourceState.serviceUnavailable);
      expect(engine.state.steps.grantedSlices, hasLength(1));

      // Exactly one thing changed. Asserted by reconstructing the whole
      // signature rather than by `isNot(before)`, which would also pass if the
      // totals had moved.
      expect(
        engine.state.steps
            .copyWith(sourceState: SourceState.available)
            .signature,
        before,
        reason: 'the source state is the ONLY field a refusal may move',
      );

      // And a source that is simply absent is still a state, not a throw.
      expect(
        MockStepSource(available: false).availability(),
        completion(
          isA<HealthAvailability>()
              .having((HealthAvailability a) => a.available, 'available', false)
              .having(
                (HealthAvailability a) => a.reason,
                'reason',
                ProviderUnavailableReason.serviceUnavailable,
              ),
        ),
      );
    });

    test('a repeated refusal does not fill the event stream', () {
      final GameEngine engine = engineWithProgress();
      final PlatformSyncPage down = ppage(
        status: PlatformSyncStatus.unavailable,
        unavailableReason: PlatformUnavailableReason.transientFailure,
      );

      expect(ingest(engine, down).events, isNotEmpty);
      expect(
        ingest(engine, down).events,
        isEmpty,
        reason: 'the state did not change, so there is nothing to say',
      );
    });
  });
}

// ===========================================================================
// 3, 4, 5, 6, 8, 9, 10, 11 — ordinary traffic
// ===========================================================================

void _ordinaryTraffic() {
  group('ordinary traffic', () {
    // -- 3 ------------------------------------------------------------------
    test('3. an empty initial sync grants nothing and stays available', () {
      final GameEngine engine = newEngine();

      final EngineResult result = ingest(
        engine,
        ppage(status: PlatformSyncStatus.noChange, nextCursor: 'c1'),
      );

      expect(result.isAccepted, isTrue);
      expect(grantedBy(result), 0);
      expect(engine.state.steps.totalGranted, 0);
      expect(engine.state.steps.totalObserved, 0);
      expect(engine.state.steps.banked, 0);
      expect(engine.state.steps.grantedSlices, isEmpty);
      expect(engine.state.steps.sourceState, SourceState.available);
      // An empty first read is a successful synchronization: the cursor may
      // advance, because there was nothing outstanding to lose.
      expect(authorizedCursor(result), cursor('c1'));
      expect(engine.state.steps.checkpoint.syncCount, 1);
      expect(
        engine.state.steps.checkpoint.originWatermarks,
        isEmpty,
        reason: 'an empty page vouches for nothing',
      );
    });

    // -- 4 ------------------------------------------------------------------
    test('4. a first valid sync credits exactly what the page reported', () {
      final GameEngine engine = newEngine();

      final EngineResult result = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1200),
            pobs(phoneBytes, 1, 800),
          ],
          nextCursor: 'c1',
        ),
      );

      expect(grantedBy(result), 2000);
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.totalObserved, 2000);
      expect(engine.state.steps.banked, 2000);
      expect(authorizedCursor(result), cursor('c1'));
      expect(engine.state.steps.recovery.isActive, isFalse);

      // Attribution survived the boundary as a pseudonym, and it is the key the
      // gateway derives — not a value this test made up.
      expect(
        engine.state.steps.grantedSlices.keys
            .map((ObservationKey k) => k.origin)
            .toSet(),
        <StepOriginKey>{phone},
      );
    });

    // -- 5 ------------------------------------------------------------------
    test('5. an incremental sync credits only the new slice', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          nextCursor: 'c1',
        ),
      );

      final EngineResult second = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 500)],
          nextCursor: 'c2',
        ),
      );

      expect(grantedBy(second), 500);
      expect(engine.state.steps.totalGranted, 1700);
      expect(engine.state.steps.totalObserved, 1700);
      expect(authorizedCursor(second), cursor('c2'));
    });

    // -- 6 ------------------------------------------------------------------
    test('6. the same page twice grants exactly once', () {
      final GameEngine engine = newEngine();
      final PlatformSyncPage batch = ppage(
        observations: <PlatformStepObservation>[
          pobs(phoneBytes, 0, 1200),
          pobs(phoneBytes, 1, 800),
        ],
        nextCursor: 'c1',
      );

      ingest(engine, batch);
      final StepLedger afterFirst = engine.state.steps;

      // Re-translated, not re-used: a replay from the platform is a fresh page
      // object, and a bridge that memoised would make this pass for the wrong
      // reason.
      final EngineResult replay = ingest(engine, batch);

      expect(grantedBy(replay), 0, reason: 'a replay must credit nothing');
      expect(engine.state.steps.totalGranted, 2000);
      expect(engine.state.steps.totalObserved, 2000);
      expect(engine.state.steps.banked, 2000);
      expect(engine.state.steps.grantedSlices, afterFirst.grantedSlices);
      expect(
        engine.state.steps.checkpoint.syncCount,
        afterFirst.checkpoint.syncCount + 1,
        reason:
            'only the sync counter advances, which is how a repeated '
            'reconciliation stays distinguishable from one that never happened',
      );
    });

    // -- 8 ------------------------------------------------------------------
    test('8. a delayed record is granted when it finally arrives', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 2, 900)],
          nextCursor: 'c1',
        ),
      );

      final EngineResult late = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 400)],
          nextCursor: 'c2',
        ),
      );

      expect(
        grantedBy(late),
        400,
        reason:
            'an older bucket arriving after a newer one is ordinary provider '
            'behaviour, not a fault',
      );
      expect(engine.state.steps.totalGranted, 1300);
      expect(engine.state.steps.lateDiscardedSlices, 0);
    });

    // -- 9 ------------------------------------------------------------------
    test('9. an upward correction grants only the increase', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 500)],
          nextCursor: 'c1',
        ),
      );

      final EngineResult corrected = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 800)],
          nextCursor: 'c2',
        ),
      );

      expect(
        grantedBy(corrected),
        300,
        reason: 'not 800 — 500 was already credited',
      );
      expect(engine.state.steps.totalGranted, 800);
      expect(engine.state.steps.totalObserved, 800);
      expect(engine.state.steps.correctionsObserved, 0);
    });

    // -- 10 -----------------------------------------------------------------
    test(
      '10. a downward correction is recorded discrepancy, never clawback',
      () {
        final GameEngine engine = newEngine();
        ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1000)],
            nextCursor: 'c1',
          ),
        );

        final EngineResult corrected = ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 400)],
            nextCursor: 'c2',
          ),
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
        expect(engine.state.steps.grantedAheadOfObserved, 600);

        // No event exists that a listener could react to by removing progress.
        // Asserted over the whole event vocabulary, not against one invented
        // name: a test that only excludes `StepsRemoved` would pass while a
        // differently-named removal event was added.
        for (final GameEvent event in corrected.events) {
          expect(
            event,
            anyOf(
              isA<StepObservationReconciled>(),
              isA<StepCheckpointAuthorized>(),
            ),
            reason:
                'a downward correction may only record and checkpoint; it '
                'emitted ${event.name}',
          );
        }

        // Restating the original figure must not re-grant it.
        final EngineResult restored = ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1000)],
            nextCursor: 'c3',
          ),
        );
        expect(grantedBy(restored), 0, reason: 'already credited once');
        expect(engine.state.steps.totalGranted, 1000);
      },
    );

    // -- 11 -----------------------------------------------------------------
    test('11. a deletion lowers observed and preserves granted', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 600),
            pobs(phoneBytes, 1, 600),
          ],
          nextCursor: 'c1',
        ),
      );

      // A deletion is an absolute restatement of zero. There is no separate
      // "deleted steps" figure anywhere on the boundary, which is why replay,
      // correction, deletion and overlap are one path rather than four.
      final EngineResult deleted = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 0)],
          nextCursor: 'c2',
        ),
      );

      expect(grantedBy(deleted), 0);
      expect(engine.state.steps.totalGranted, 1200);
      expect(engine.state.steps.totalObserved, 600);
      expect(engine.state.steps.banked, 1200);

      // The slice is still remembered as granted, which is what stops a later
      // restatement re-granting it.
      final EngineResult undeleted = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 600)],
          nextCursor: 'c3',
        ),
      );
      expect(grantedBy(undeleted), 0);
      expect(engine.state.steps.totalGranted, 1200);
    });
  });
}

// ===========================================================================
// 7, 13 — pagination
// ===========================================================================

void _pagination() {
  group('pagination', () {
    // -- 7 ------------------------------------------------------------------
    test('7. a paginated read credits every page exactly once', () {
      // Newest-first, which is what both platforms actually do and what
      // destroyed 55,200 steps when the core inferred completeness from the
      // newest bucket it happened to hold.
      final GameEngine engine = newEngine();

      final SyncFetch p1 = translate(
        ppage(
          observations: <PlatformStepObservation>[
            for (int h = 40; h < 48; h++) pobs(phoneBytes, h, 100),
          ],
          isFinalPage: false,
          continuation: 'p2',
        ),
      );
      final SyncFetch p2 = translate(
        ppage(
          observations: <PlatformStepObservation>[
            for (int h = 20; h < 40; h++) pobs(phoneBytes, h, 100),
          ],
          isFinalPage: false,
          continuation: 'p3',
        ),
      );
      final SyncFetch p3 = translate(
        ppage(
          observations: <PlatformStepObservation>[
            for (int h = 0; h < 20; h++) pobs(phoneBytes, h, 100),
          ],
          complete: pcomplete(
            kind: PlatformCompletenessKind.completeThrough,
            throughIndex: 48,
            toIndex: 48,
          ),
          nextCursor: 'drained',
        ),
      );

      expect(p1.isFinalPage, isFalse);
      expect(p1.continuation, isNotNull);
      expect(p3.isFinalPage, isTrue);
      expect(
        p3.continuation,
        isNull,
        reason: 'a drained read offers nothing to resume from',
      );

      expect(grantedBy(reconcile(engine, p1)), 800);
      expect(
        engine.state.steps.checkpoint.originWatermarks,
        isEmpty,
        reason: 'mid-read, nothing is settled',
      );

      expect(grantedBy(reconcile(engine, p2)), 2000);
      expect(engine.state.steps.checkpoint.originWatermarks, isEmpty);

      expect(
        grantedBy(reconcile(engine, p3)),
        2000,
        reason:
            'the oldest page is real movement and must be credited in full, '
            'however late in the read it arrives',
      );

      expect(engine.state.steps.totalGranted, 4800);
      expect(
        engine.state.steps.lateDiscardedSlices,
        0,
        reason: 'nothing was discarded, so nothing may be counted as discarded',
      );
      expect(
        engine.state.steps.checkpoint.originWatermarks.keys,
        <StepOriginKey>[phone],
        reason: 'only the drained page may settle, and only its own origin',
      );

      // Replaying the whole read credits nothing further.
      for (final SyncFetch page in <SyncFetch>[p1, p2, p3]) {
        expect(grantedBy(reconcile(engine, page)), 0);
      }
      expect(engine.state.steps.totalGranted, 4800);
    });

    // -- 13 -----------------------------------------------------------------
    test('13. a partial page cannot assert completeness', () {
      // The contrast pair. The two pages are identical in every field except
      // `isFinalPage`, so nothing but the page state can explain the
      // difference in what settles.
      PlatformSyncPage claiming({required bool isFinalPage}) => ppage(
        observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1000)],
        complete: pcomplete(
          kind: PlatformCompletenessKind.completeThrough,
          throughIndex: 1,
          toIndex: 1,
        ),
        isFinalPage: isFinalPage,
        continuation: isFinalPage ? null : 'more',
      );

      final SyncFetch mid = translate(claiming(isFinalPage: false));
      expect(
        (mid.response as IncrementalSync).completeness,
        isA<PartialDelivery>(),
        reason:
            'the 55,200-step defect in contract form: page one of nine looked '
            'exactly like page nine of nine',
      );
      expect(mid.faults, contains(SyncFault.completenessOnNonFinalPage));
      expect(
        (mid.response as IncrementalSync).observations,
        hasLength(1),
        reason: 'the observations are kept; only the settling is refused',
      );

      final GameEngine partial = newEngine();
      expect(grantedBy(reconcile(partial, mid)), 1000);
      expect(
        partial.state.steps.checkpoint.originWatermarks,
        isEmpty,
        reason: 'no watermark may advance on a PartialDelivery',
      );
      expect(partial.state.steps.checkpoint.watermarkMillis, isNull);

      // The negative control. Without it this test would still pass against a
      // reconciler that never advanced a watermark at all, and would therefore
      // be proving nothing.
      final GameEngine drained = newEngine();
      final SyncFetch last = translate(claiming(isFinalPage: true));
      expect(last.isClean, isTrue);
      expect(grantedBy(reconcile(drained, last)), 1000);
      expect(
        drained.state.steps.checkpoint.originWatermarks.keys,
        <StepOriginKey>[phone],
        reason: 'a drained page CAN settle — so the partial case is the rule',
      );
    });

    test('the scripted source expresses the same shape', () {
      // The mock is the harness the reconciliation scenarios run against. If it
      // cannot express a partial page, the case is untestable without a device,
      // which is exactly what went wrong with the model it replaces.
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          MockStepSource.partialPage(
            phone.value,
            startMillis: t0,
            endMillis: t0 + hour,
            steps: 55200,
          ),
        ],
      );

      expect(
        source.fetchSteps(const SyncRequest()),
        completion(
          isA<SyncFetch>()
              .having((SyncFetch f) => f.isFinalPage, 'isFinalPage', isFalse)
              .having(
                (SyncFetch f) => (f.response as IncrementalSync).completeness,
                'completeness',
                isA<PartialDelivery>(),
              ),
        ),
      );
    });
  });
}

// ===========================================================================
// 12 — multiple origins (LG-3)
// ===========================================================================

void _origins() {
  group('12. multiple origins', () {
    /// Fourteen days of the phone syncing and vouching for itself, after the
    /// watch delivered what it had and then went offline.
    ///
    /// [scopeKind] is the whole experiment: whether the phone's assertion
    /// claims to speak for every source or only for itself. Every other input
    /// is identical between the two runs.
    GameEngine fourteenDays(PlatformOriginScopeKind scopeKind) {
      final GameEngine engine = newEngine();

      // Both devices report. Both are real; neither cancels the other. The
      // watch reports two widely separated hours, which is what a device that
      // syncs sporadically actually looks like.
      final EngineResult first = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1000),
            pobs(watchBytes, 0, 900),
            pobs(watchBytes, 100, 100),
          ],
          nextCursor: 'day0',
        ),
      );
      expect(grantedBy(first), 2000, reason: 'two devices, three slices');

      // The watch then goes offline. The phone keeps syncing and keeps
      // asserting completeness.
      for (int day = 1; day < 14; day++) {
        ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[
              pobs(phoneBytes, day * 24, 1000),
            ],
            complete: pcomplete(
              kind: PlatformCompletenessKind.completeThrough,
              scopeKind: scopeKind,
              scoped: scopeKind == PlatformOriginScopeKind.allOrigins
                  ? const <Uint8List>[]
                  : <Uint8List>[phoneBytes],
              throughIndex: day * 24 + 1,
              toIndex: day * 24 + 1,
            ),
            nextCursor: 'day$day',
          ),
        );
      }
      return engine;
    }

    test('an assertion scoped to one origin never settles another', () {
      final GameEngine engine = fourteenDays(
        PlatformOriginScopeKind.someOrigins,
      );

      expect(
        engine.state.steps.checkpoint.originWatermarks.containsKey(watch),
        isFalse,
        reason:
            'the phone vouched for the phone. Silence about the watch is not '
            'an assertion about the watch.',
      );

      // The watch finally reconnects and uploads the walk it recorded while it
      // was away.
      final EngineResult backfill = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(watchBytes, 5, 8000)],
          nextCursor: 'watch',
        ),
      );

      expect(
        grantedBy(backfill),
        8000,
        reason:
            'this lands directly on the Kernel: the failure mode is precisely '
            '"the player went away, so their steps did not count"',
      );
      expect(engine.state.steps.lateDiscardedSlices, 0);
      expect(engine.state.steps.totalGranted, 2000 + 13000 + 8000);
    });

    test('the negative control — a wider scope DOES settle the watch', () {
      // Without this, the test above would pass against a reconciler that
      // never settled anything, and would be proving nothing. Here the adapter
      // claims to have enumerated every source, so the watch's own buckets are
      // legitimately compacted and its watermark legitimately advances — and
      // the same backlog is then correctly refused.
      //
      // The difference between the two tests is one enum value on the wire.
      // That is the whole of LG-3.
      final GameEngine engine = fourteenDays(
        PlatformOriginScopeKind.allOrigins,
      );

      expect(
        engine.state.steps.checkpoint.originWatermarks.containsKey(watch),
        isTrue,
        reason: 'an allOrigins assertion does vouch for the watch',
      );

      final EngineResult backfill = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(watchBytes, 5, 8000)],
          nextCursor: 'watch',
        ),
      );

      expect(grantedBy(backfill), 0);
      expect(
        engine.state.steps.lateDiscardedSlices,
        1,
        reason:
            'and the loss is counted rather than silent — a loss you cannot '
            'count is a haunting',
      );
    });

    test('a correction to one origin does not disturb the other', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1000),
            pobs(watchBytes, 0, 900),
          ],
          nextCursor: 'c1',
        ),
      );

      final EngineResult corrected = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(watchBytes, 0, 200)],
          nextCursor: 'c2',
        ),
      );

      expect(grantedBy(corrected), 0);
      expect(engine.state.steps.totalGranted, 1900);
      expect(engine.state.steps.totalObserved, 1200);
      // The phone's slice is untouched — same origin, same bucket, same figure.
      expect(
        engine.state.steps.grantedSlices[ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        )],
        1000,
      );
    });

    test('two origins in one hour are never merged into one key', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1000),
            pobs(watchBytes, 0, 900),
          ],
          nextCursor: 'c1',
        ),
      );

      expect(engine.state.steps.grantedSlices, hasLength(2));
      expect(
        engine.state.steps.grantedSlices.keys
            .map((ObservationKey k) => k.origin)
            .toSet(),
        <StepOriginKey>{phone, watch},
      );
    });
  });
}

// ===========================================================================
// 14, 15 — the commit order
// ===========================================================================

void _commitOrder() {
  group('14. the cursor is not committed before the ledger', () {
    /// Every accepted shape the bridge can produce, so the ordering claim is
    /// made about the whole surface rather than about one convenient page.
    List<PlatformSyncPage> acceptedShapes() => <PlatformSyncPage>[
      ppage(
        observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 900)],
        nextCursor: 'a',
      ),
      ppage(status: PlatformSyncStatus.noChange, nextCursor: 'b'),
      ppage(
        status: PlatformSyncStatus.noChange,
        observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 50)],
        nextCursor: 'c',
      ),
      ppage(
        observations: <PlatformStepObservation>[pobs(phoneBytes, 2, 700)],
        complete: pcomplete(
          kind: PlatformCompletenessKind.completeThrough,
          throughIndex: 3,
          toIndex: 3,
        ),
        nextCursor: 'd',
      ),
      ppage(
        status: PlatformSyncStatus.cursorInvalidated,
        observations: <PlatformStepObservation>[pobs(phoneBytes, 3, 400)],
        rescan: pwindow(fromIndex: 0, toIndex: 4),
        complete: pcomplete(
          kind: PlatformCompletenessKind.recoveryCompleteThrough,
          throughIndex: 4,
          toIndex: 4,
        ),
        nextCursor: 'e',
      ),
    ];

    test('the checkpoint is the last event, always, and there is one', () {
      final GameEngine engine = newEngine();
      for (final PlatformSyncPage page in acceptedShapes()) {
        final EngineResult result = ingest(engine, page);
        expect(result.isAccepted, isTrue);

        final List<GameEvent> events = result.events;
        expect(
          events.whereType<StepCheckpointAuthorized>(),
          hasLength(1),
          reason: 'exactly one authorization per accepted batch',
        );
        expect(
          events.last,
          isA<StepCheckpointAuthorized>(),
          reason:
              'the cursor becomes persistable strictly after the ledger has '
              'committed. Authorizing it first lets a crash resume past steps '
              'the player walked and would never see. Events were: '
              '${events.map((GameEvent e) => e.name).toList()}',
        );
      }
    });

    test(
      'a failure between the grant and the commit leaves the cursor back',
      () {
        final GameEngine engine = newEngine();
        ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 700)],
            nextCursor: 'c1',
          ),
        );
        final GameState committed = engine.state;
        expect(committed.steps.checkpoint.cursor, cursor('c1'));

        final PlatformSyncPage next = ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 500)],
          nextCursor: 'c2',
        );
        final EngineResult planned = ingest(engineAt(committed), next);

        // The grant lands; the authorization does not.
        final GameState partial = commitWithoutCheckpoint(
          committed,
          planned.events,
        );

        expect(partial.steps.totalGranted, 1200, reason: 'the grant committed');
        expect(
          partial.steps.checkpoint.cursor,
          cursor('c1'),
          reason:
              'the durable cursor is EXACTLY the old one. Asserted by value: '
              '"not c2" would also pass if the cursor had been cleared, which '
              'would restart the read from the beginning of time.',
        );
        expect(partial.steps.checkpoint.syncCount, 1);

        // Resuming from the old cursor replays the same batch, which must credit
        // nothing, because the grant already committed.
        final GameEngine resumed = engineAt(partial);
        final EngineResult replay = ingest(resumed, next);

        expect(grantedBy(replay), 0, reason: 'no double-grant after a crash');
        expect(resumed.state.steps.totalGranted, 1200);
        expect(resumed.state.steps.checkpoint.cursor, cursor('c2'));
      },
    );

    test('a failure before the ledger commits moves nothing at all', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 700)],
          nextCursor: 'c1',
        ),
      );
      final GameState committed = engine.state;
      final String before = committed.steps.signature;

      // Events computed and then dropped: the process died before the reducer
      // ran.
      final EngineResult planned = ingest(
        engineAt(committed),
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 300)],
          nextCursor: 'c2',
        ),
      );
      expect(planned.isAccepted, isTrue);

      expect(committed.steps.signature, before);
      expect(committed.steps.totalGranted, 700);
      expect(committed.steps.checkpoint.cursor, cursor('c1'));
    });

    test('a refused page authorizes no cursor and no sync', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 700)],
          nextCursor: 'c1',
        ),
      );

      // An invalidated cursor with no rescan window: refused by the bridge, so
      // the core sees a transient failure and the cursor the adapter offered is
      // never seen at all.
      final SyncFetch refused = translate(
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 5000)],
          nextCursor: 'poison',
        ),
      );
      expect(refused.faults, contains(SyncFault.invalidatedWithoutRescan));

      final EngineResult result = reconcile(engine, refused);
      expect(didAuthorizeCheckpoint(result), isFalse);
      expect(engine.state.steps.checkpoint.cursor, cursor('c1'));
      expect(engine.state.steps.checkpoint.syncCount, 1);
      expect(engine.state.steps.totalGranted, 700);
    });

    // -- 15 -----------------------------------------------------------------
    test('15. retrying after an interruption recomputes the same result', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 700)],
          nextCursor: 'c1',
        ),
      );
      final GameState committed = engine.state;

      final PlatformSyncPage next = ppage(
        observations: <PlatformStepObservation>[
          pobs(phoneBytes, 0, 700),
          pobs(phoneBytes, 1, 300),
        ],
        nextCursor: 'c2',
      );

      // Three attempts from the same uncommitted state. Each is a full
      // re-translation from the platform page, so a bridge that carried state
      // between reads would diverge here.
      final List<String> signatures = <String>[];
      final List<int> grants = <int>[];
      for (int attempt = 0; attempt < 3; attempt++) {
        final GameEngine retry = engineAt(committed);
        grants.add(grantedBy(ingest(retry, next)));
        signatures.add(retry.state.steps.signature);
      }

      expect(grants, <int>[300, 300, 300]);
      expect(
        signatures.toSet(),
        hasLength(1),
        reason:
            'the ledger is a pure function of the state and the response, so '
            'every retry must land on the identical ledger: $signatures',
      );
    });
  });
}

// ===========================================================================
// 16 — token expiry and bounded recovery
// ===========================================================================

void _recovery() {
  group('16. token expiry and bounded recovery', () {
    test('an expired token grants only what was not already credited', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 500),
            pobs(phoneBytes, 1, 500),
          ],
          nextCursor: 'c1',
        ),
      );

      final SyncFetch fetch = translate(
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 500),
            pobs(phoneBytes, 1, 500),
            pobs(phoneBytes, 2, 300),
          ],
          rescan: pwindow(fromIndex: 0, toIndex: 3),
          complete: pcomplete(
            kind: PlatformCompletenessKind.recoveryCompleteThrough,
            throughIndex: 3,
            toIndex: 3,
          ),
          nextCursor: 'c2',
        ),
      );
      expect(fetch.isClean, isTrue);
      expect(fetch.response, isA<CursorInvalidatedSync>());

      final EngineResult recovered = reconcile(engine, fetch);

      expect(
        grantedBy(recovered),
        300,
        reason: 'not 1300 — an authoritative rescan is not a new grant',
      );
      expect(engine.state.steps.totalGranted, 1300);
      expect(engine.state.steps.recovery.isActive, isFalse);
      expect(authorizedCursor(recovered), cursor('c2'));
      expect(engine.state.steps.unreachableGapEvents, 0);
    });

    test('a rescan reporting less than was granted never claws back', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 900)],
          nextCursor: 'c1',
        ),
      );

      ingest(
        engine,
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 100)],
          rescan: pwindow(fromIndex: 0, toIndex: 1),
          nextCursor: 'c2',
        ),
      );

      expect(engine.state.steps.totalGranted, 900, reason: 'no clawback');
      expect(engine.state.steps.totalObserved, 100);
      expect(engine.state.steps.banked, 900);
    });

    test('a full-history rescan does not re-grant', () {
      final GameEngine engine = newEngine();
      final List<PlatformStepObservation> history = <PlatformStepObservation>[
        for (int h = 0; h < 12; h++) pobs(phoneBytes, h, 100),
      ];

      ingest(engine, ppage(observations: history, nextCursor: 'c1'));
      expect(engine.state.steps.totalGranted, 1200);

      final EngineResult recovered = ingest(
        engine,
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: history,
          rescan: pwindow(fromIndex: 0, toIndex: 12),
          nextCursor: 'c2',
        ),
      );

      expect(
        grantedBy(recovered),
        0,
        reason: 'the accidental full-history grant',
      );
      expect(engine.state.steps.totalGranted, 1200);
    });

    test('a truncated window records the gap and settles nothing', () {
      final GameEngine engine = newEngine();

      // The adapter clamped the window and still claimed recovery completeness
      // for it. The bridge must downgrade that to PartialDelivery: settling on
      // a truncated rescan buries whatever fell outside the truncation, and
      // those steps are then unreachable forever.
      final SyncFetch fetch = translate(
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 5, 400)],
          rescan: pwindow(fromIndex: 5, toIndex: 6, truncated: true),
          complete: pcomplete(
            kind: PlatformCompletenessKind.recoveryCompleteThrough,
            throughIndex: 6,
            toIndex: 6,
          ),
          nextCursor: 'c1',
        ),
      );

      expect(
        (fetch.response as CursorInvalidatedSync).completeness,
        isA<PartialDelivery>(),
      );

      final EngineResult recovered = reconcile(engine, fetch);

      expect(recovered.isAccepted, isTrue);
      expect(
        grantedBy(recovered),
        400,
        reason:
            'only what the window actually contained is credited. The '
            'unreachable gap is recorded, never invented.',
      );
      expect(engine.state.steps.unreachableGapEvents, 1);
      expect(
        engine.state.steps.checkpoint.originWatermarks,
        isEmpty,
        reason: 'a truncated rescan settles nothing',
      );
      expect(engine.state.steps.checkpoint.watermarkMillis, isNull);

      // And the gap itself is never granted. A slice from inside the clamped-
      // away span is still fully grantable when it arrives by some other route,
      // which is the difference between "recorded" and "invented".
      final EngineResult inGap = ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 250)],
          nextCursor: 'c2',
        ),
      );
      expect(grantedBy(inGap), 250);
      expect(engine.state.steps.totalGranted, 650);
    });

    test('recovery interrupted before commit is safe to retry', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 500)],
          nextCursor: 'c1',
        ),
      );
      final GameState before = engine.state;

      final PlatformSyncPage rescanPage = ppage(
        status: PlatformSyncStatus.cursorInvalidated,
        observations: <PlatformStepObservation>[
          pobs(phoneBytes, 0, 500),
          pobs(phoneBytes, 1, 400),
        ],
        rescan: pwindow(fromIndex: 0, toIndex: 2),
        nextCursor: 'c2',
      );

      // First attempt dies before the reducer runs.
      ingest(engineAt(before), rescanPage);
      expect(before.steps.totalGranted, 500);
      expect(before.steps.checkpoint.cursor, cursor('c1'));
      expect(before.steps.recovery.isActive, isFalse);

      final GameEngine retry = engineAt(before);
      final EngineResult retried = ingest(retry, rescanPage);

      expect(grantedBy(retried), 400);
      expect(retry.state.steps.totalGranted, 900);
      expect(retry.state.steps.recovery.isActive, isFalse);
      expect(retry.state.steps.checkpoint.cursor, cursor('c2'));
    });

    test('recovery interrupted mid-flight is recorded as unfinished', () {
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 500)],
          nextCursor: 'c1',
        ),
      );
      final GameState before = engine.state;

      final PlatformSyncPage rescanPage = ppage(
        status: PlatformSyncStatus.cursorInvalidated,
        observations: <PlatformStepObservation>[
          pobs(phoneBytes, 0, 500),
          pobs(phoneBytes, 1, 400),
        ],
        rescan: pwindow(fromIndex: 0, toIndex: 2),
        nextCursor: 'c2',
      );
      final EngineResult planned = ingest(engineAt(before), rescanPage);

      // Death immediately after the recovery was announced and before anything
      // was reconciled — the one case where the ledger must be able to say
      // "a recovery began and never finished".
      final GameState midFlight = commitUpTo<StepObservationReconciled>(
        before,
        planned.events,
      );

      expect(midFlight.steps.recovery.isActive, isTrue);
      expect(midFlight.steps.totalGranted, 500, reason: 'nothing granted yet');
      expect(midFlight.steps.checkpoint.cursor, cursor('c1'));

      final GameEngine retry = engineAt(midFlight);
      final EngineResult retried = ingest(retry, rescanPage);

      expect(grantedBy(retried), 400);
      expect(retry.state.steps.totalGranted, 900);
      expect(retry.state.steps.recovery.isActive, isFalse);
    });

    test('an invalidated cursor without a window is refused, not guessed', () {
      // Without the window there is no authoritative figure and no safe move:
      // granting the rescanned content is the double-count, discarding it is
      // the lost grant. So the page is refused whole and the ledger is
      // untouched.
      final GameEngine engine = newEngine();
      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 500)],
          nextCursor: 'c1',
        ),
      );

      final EngineResult result = ingest(
        engine,
        ppage(
          status: PlatformSyncStatus.cursorInvalidated,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 9999)],
        ),
      );

      expect(grantedBy(result), 0);
      expect(engine.state.steps.totalGranted, 500);
      expect(
        engine.state.steps.sourceState,
        SourceState.transientlyUnavailable,
      );
      expect(engine.state.steps.recovery.isActive, isFalse);
    });
  });
}

// ===========================================================================
// 18, 19, 20 — privacy and containment
// ===========================================================================

void _privacy() {
  group('privacy and containment', () {
    // -- 18 -----------------------------------------------------------------
    test('18. no diagnostic surface carries a key, a cursor, or a salt', () {
      const String cursorSecret = 'ANCHOR-7f3a-DEVICE-ROB';
      final GameEngine engine = newEngine();

      ingest(
        engine,
        ppage(
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1000),
            pobs(watchBytes, 0, 900),
          ],
          complete: pcomplete(
            kind: PlatformCompletenessKind.completeThrough,
            throughIndex: 1,
            toIndex: 1,
          ),
          nextCursor: cursorSecret,
        ),
      );

      final StepLedger ledger = engine.state.steps;
      final SyncCursor durable = ledger.checkpoint.cursor!;

      // The cursor renders as its length and nothing else. Asserted as an exact
      // value: `isNot(contains(...))` would still pass for a cursor that leaked
      // half its bytes, or that leaked them hex-encoded.
      expect(durable.toString(), 'cursor(${cursorSecret.length}B)');

      for (final String surface in <String>[
        ledger.signature,
        ledger.toString(),
        engine.state.signature,
        engine.state.toString(),
        durable.toString(),
      ]) {
        expect(
          surface,
          isNot(contains(cursorSecret)),
          reason: 'a diagnostic surface carries the cursor: $surface',
        );
        expect(
          surface,
          isNot(contains('ANCHOR')),
          reason: 'a diagnostic surface carries part of the cursor: $surface',
        );
        for (final StepOriginKey origin in <StepOriginKey>[phone, watch]) {
          expect(
            surface,
            isNot(contains(origin.value)),
            reason: 'a diagnostic surface names an origin: $surface',
          );
        }
      }

      // What the signature DOES say: cardinalities and counters. Kept as a
      // positive assertion, because a redaction test that only checks absence
      // passes just as well against a surface that says nothing at all.
      expect(
        ledger.signature,
        contains('slices=${ledger.grantedSlices.length}'),
      );
      expect(ledger.signature, contains('granted=${ledger.totalGranted}'));

      // A fault is a category, and the category is the whole payload.
      for (final SyncFault fault in SyncFault.values) {
        expect(fault.toString(), startsWith('SyncFault.'));
      }
    });

    test('a refusal explanation names no bucket, origin, or count', () {
      // The explanation reaches diagnostics, and a bucket, an origin, and a
      // step count are all health-derived.
      final GameEngine engine = newEngine();
      final EngineResult result = engine.execute(
        ReconcileStepSync(
          response: IncrementalSync(
            observations: <StepObservation>[
              StepObservation(
                key: ObservationKey(
                  origin: phone,
                  bucket: TimeBucket(startMillis: t0, endMillis: t0 + 60000),
                ),
                steps: 4137,
              ),
            ],
            nextCursor: cursor('c1'),
          ),
        ),
      );

      expect(result.isRejected, isTrue);
      final String text = result.rejection!.explanation;
      expect(text, isNot(contains('$t0')));
      expect(text, isNot(contains(phone.value)));
      expect(text, isNot(contains('4137')));
      expect(engine.state.steps.totalGranted, 0);
      expect(engine.state.steps.checkpoint.cursor, isNull);
    });

    // -- 19 -----------------------------------------------------------------
    test('19. no raw platform identifier can reach the ledger', () {
      // The wire has no String origin field at all, so an identifier would have
      // to arrive as bytes — and only two lengths are legal. Everything else
      // refuses the whole page rather than dropping the slice, because dropping
      // one slice while honouring the page's completeness assertion would
      // settle the bucket the drop just emptied.
      const List<String> names = <String>[
        "Rob's iPhone",
        'iPhone 15 Pro',
        'Apple Watch Series 9',
        'com.apple.health',
        'Pixel 8',
        'My Watch',
      ];

      final GameEngine engine = newEngine();
      for (final String name in names) {
        final Uint8List asBytes = Uint8List.fromList(name.codeUnits);
        ingest(
          engine,
          ppage(
            observations: <PlatformStepObservation>[pobs(asBytes, 0, 100)],
            complete: pcomplete(scoped: <Uint8List>[asBytes]),
            nextCursor: 'c',
          ),
        );
      }

      // Whatever survived is a pseudonym or the reserved unknown. Nothing else
      // is representable, and this asserts it on the values that actually
      // reached the ledger rather than on the type in the abstract.
      for (final ObservationKey observationKey
          in engine.state.steps.grantedSlices.keys) {
        final String value = observationKey.origin.value;
        expect(
          value,
          anyOf(
            matches(RegExp(r'^[0-9a-f]{16}$')),
            StepOriginKey.unknown.value,
          ),
          reason: 'an origin key reached the ledger as "$value"',
        );
        for (final String name in names) {
          expect(value, isNot(contains(name)));
        }
      }

      // The named limit of this control, kept executable rather than as a
      // caveat: "My Watch" is exactly eight bytes, so it passes the length
      // check and becomes a key. The wire cannot tell eight bytes of digest
      // from eight bytes of anything. What closes that gap is native review and
      // `origin_key_vectors.dart`, not this layer.
      expect(
        gateway.decodeOrigin(Uint8List.fromList('My Watch'.codeUnits)),
        isNotNull,
      );
      expect(
        gateway.decodeOrigin(Uint8List.fromList("Rob's iPhone".codeUnits)),
        isNull,
        reason: 'twelve bytes is not an origin key',
      );
    });

    // -- 20 -----------------------------------------------------------------
    test('20. the health package constructs no persistence, in any isolate', () {
      // The F-06 binding rule, restated by `DECISIONS/0014` and unchanged by
      // S-01A: no background isolate, callback, worker, or platform entry point
      // may instantiate `SaveRepository`, construct filesystem persistence
      // stores, or touch the save directory.
      //
      // There is no runtime observation that can prove this — the property is
      // that a construction never happens, anywhere, including on a code path
      // no test calls. So it is asserted over the source text of this package's
      // production library, which is the only form the claim can take in Dart.
      // `Scripts/check-single-writer.sh` holds the same rule across the whole
      // repository and in three languages; this is the part that runs in
      // `flutter test`.
      // Matched against CODE, with comments stripped. A raw substring scan over
      // the whole file is not the same test: `origin_pseudonymizer.dart`
      // discusses `dart:io` in prose, and a guard that cannot tell an import
      // from a sentence gets weakened the first time it fires on one.
      final Map<String, RegExp> forbidden = <String, RegExp>{
        'a dart:io import': RegExp('''import\\s+['"]dart:io['"]'''),
        'SaveRepository': RegExp(r'\bSaveRepository\b'),
        'a save store': RegExp(r'\bFile\w*SaveStore\b|\bSaveStore\b'),
        'a background isolate registry': RegExp(
          r'\bIsolateNameServer\b|\bPluginUtilities\b'
          r'|\bBackgroundIsolateBinaryMessenger\b',
        ),
        'a documents directory': RegExp(r'getApplicationDocumentsDirectory'),
      };

      final Directory lib = Directory('lib');
      expect(
        lib.existsSync(),
        isTrue,
        reason: 'run from packages/stride_health or the repository root',
      );

      final List<File> sources = lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
      expect(
        sources.length,
        greaterThanOrEqualTo(6),
        reason:
            'the scan must actually be reading the package. A path that '
            'resolved to nothing would pass this test vacuously.',
      );

      /// Everything outside a comment. Line comments only, which is all this
      /// package uses.
      String codeOf(String text) => text
          .split('\n')
          .map((String line) {
            final int marker = line.indexOf('//');
            return marker < 0 ? line : line.substring(0, marker);
          })
          .join('\n');

      // The stripper's own self-test. Without it, a bug that returned the empty
      // string would make every assertion below pass while checking nothing —
      // which is the exact failure mode this project has already shipped once.
      final String gatewayCode = codeOf(
        File('lib/src/origin_gateway.dart').readAsStringSync(),
      );
      expect(gatewayCode, contains('final class OriginGateway'));
      expect(gatewayCode, isNot(contains('bundleIdentifier')));

      for (final File source in sources) {
        final String code = codeOf(source.readAsStringSync());
        forbidden.forEach((String what, RegExp pattern) {
          expect(
            pattern.hasMatch(code),
            isFalse,
            reason:
                '${source.path} contains $what. A background health callback '
                'that reached persistence directly would be a second writer, '
                'which DECISIONS/0013 forbids.',
          );
        });
      }
    });
  });
}
