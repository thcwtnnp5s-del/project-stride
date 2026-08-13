// The first physical-iPhone sync, reconstructed as a test.
//
// Free Personal Team signing put Project Stride on the owner's real iPhone. The
// first sync reconciled cleanly — eight pages, two origins, 721 UTC buckets,
// 837,163 steps observed and 407,105 newly granted — and reported seven
// `cursorOfferedWhenProhibited` faults. Seven faults across eight pages is not a
// coincidence: it is one per non-final page.
//
// The cause was native. `HKAnchoredObjectQuery` returns one updated anchor per
// page, and `HealthKitStepStore` assigned it to BOTH the continuation and the
// candidate cursor, on every page, drained or not. `HealthKitAdapter.map` then
// forwarded it as `nextCursor` without consulting `isFinalPage` — the one field
// of the three that was not gated, next to a completeness assertion and a
// continuation that both were.
//
// This file exists for two separate reasons, and they should not be collapsed:
//
//   1. THE FIX. A multi-page delivery shaped the way the corrected adapter now
//      sends it must be fault-free, and the candidate must appear exactly once,
//      on the drained page. `RunnerTests.swift` asserts the same rule against
//      the Swift mapping; this asserts what the ledger does with the result.
//
//   2. THE EVIDENCE. The delivery shaped the way the DEFECTIVE adapter sent it
//      must reach byte-identical durable state. That is the proof that the save
//      currently on the owner's iPhone is accounting-safe and does not need to
//      be reset — the refusal held, seven times, and nothing prohibited ever
//      became durable. It is also the guard that stops
//      `cursorOfferedWhenProhibited` being softened once the native side no
//      longer trips it.
//
// No device, no channel, no health service, no wall clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'adapter_ledger_support.dart';

/// Pages in the delivery, as the device produced it.
const int _pageCount = 8;

/// Buckets per page. Eight pages of twelve hours, delivered newest-first, which
/// is what HealthKit actually does.
const int _bucketsPerPage = 12;

/// The hour index one past the last bucket in the read.
const int _horizon = _pageCount * _bucketsPerPage;

const int _stepsPerBucket = 100;

/// The eight-page delivery.
///
/// [nativeOffersOnNonFinalPages] is the whole variable. False is the corrected
/// adapter; true is the adapter that ran on the iPhone. Everything else —
/// observations, completeness, pagination, continuations — is identical, so
/// nothing but the candidate cursor can explain a difference in outcome.
List<PlatformSyncPage> _delivery({required bool nativeOffersOnNonFinalPages}) {
  return <PlatformSyncPage>[
    for (int page = 0; page < _pageCount; page++)
      if (page == _pageCount - 1)
        pincrementalPage(
          isFinalPage: true,
          completeness: PlatformCompletenessKind.completeThrough,
          observations: <PlatformStepObservation>[
            for (int h = 0; h < _bucketsPerPage; h++)
              pobs(phoneBytes, h, _stepsPerBucket),
          ],
          throughIndex: _horizon,
          toIndex: _horizon,
          nextCursor: 'drained',
        )
      else
        pincrementalPage(
          isFinalPage: false,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[
            // Newest first: page 0 is the most recent twelve hours.
            for (int h = 0; h < _bucketsPerPage; h++)
              pobs(
                phoneBytes,
                _horizon - (page + 1) * _bucketsPerPage + h,
                _stepsPerBucket,
              ),
          ],
          continuation: 'page${page + 1}',
          // The defect, in the one field that carried it.
          nextCursor: nativeOffersOnNonFinalPages ? 'mid$page' : null,
        ),
  ];
}

/// Canonical durable state with the two pure bookkeeping counters flattened.
///
/// `eventSequence` and `checkpoint.syncCount` both move on a replay and are
/// *supposed* to: they count commits, and a replay is a commit. Neither decides
/// an amount, a settle, or a cursor. Everything else — totals, granted slices,
/// watermarks, the cursor itself, recovery phase — must be untouched, and is
/// compared exactly.
///
/// Normalized rather than dropped: comparing only the totals would pass on a
/// state whose watermarks or granted slices had moved underneath it, which is
/// the failure mode this comparison exists to catch.
String _amountBearingState(GameState state) => canonicalDurableGameState(
  state.copyWith(
    eventSequence: 0,
    steps: state.steps.copyWith(
      checkpoint: SyncCheckpoint(
        cursor: state.steps.checkpoint.cursor,
        watermarkMillis: state.steps.checkpoint.watermarkMillis,
        originWatermarks: state.steps.checkpoint.originWatermarks,
      ),
    ),
  ),
);

/// Runs a whole delivery into a fresh engine and reports what happened per page.
///
/// Returns, for each page, the faults raised, the authorization outcome, the
/// steps credited, and the cursor that was durable AFTER the page committed.
({
  List<List<SyncFault>> faults,
  List<CursorAuthorization?> authorizations,
  List<int> granted,
  List<SyncCursor?> durableCursorAfter,
  GameEngine engine,
})
_run(List<PlatformSyncPage> pages) {
  final GameEngine engine = newEngine();
  final List<List<SyncFault>> faults = <List<SyncFault>>[];
  final List<CursorAuthorization?> authorizations = <CursorAuthorization?>[];
  final List<int> granted = <int>[];
  final List<SyncCursor?> durable = <SyncCursor?>[];

  for (final PlatformSyncPage page in pages) {
    final SyncFetch fetch = translate(page);
    faults.add(fetch.faults);
    authorizations.add(fetch.cursorAuthorization);
    granted.add(grantedBy(reconcile(engine, fetch)));
    durable.add(engine.state.steps.checkpoint.cursor);
  }

  return (
    faults: faults,
    authorizations: authorizations,
    granted: granted,
    durableCursorAfter: durable,
    engine: engine,
  );
}

void main() {
  group('an eight-page HealthKit delivery', () {
    test('the corrected adapter offers a candidate only on the drained page', () {
      final List<PlatformSyncPage> pages = _delivery(
        nativeOffersOnNonFinalPages: false,
      );

      for (int i = 0; i < _pageCount - 1; i++) {
        expect(
          pages[i].nextCursor,
          isNull,
          reason:
              'page $i of $_pageCount is non-final: pages remain outstanding, '
              'so there is no position the adapter may claim to have reached',
        );
        expect(
          pages[i].pagination.continuation,
          isNotNull,
          reason:
              'the same anchor is still legal as in-flight read state. The two '
              'fields mean different things and only one of them is durable',
        );
      }
      expect(
        pages.last.nextCursor,
        isNotNull,
        reason: 'the drained page is the safe terminal point, and offers',
      );

      final result = _run(pages);

      expect(
        result.faults.expand((List<SyncFault> f) => f),
        isEmpty,
        reason:
            'a correct adapter draining in eight pages must produce no faults '
            'at all. Seven of eight pages faulting was the defect',
      );
      expect(
        result.authorizations,
        <CursorAuthorization>[
          ...List<CursorAuthorization>.filled(
            _pageCount - 1,
            CursorAuthorization.absent,
          ),
          CursorAuthorization.authorized,
        ],
        reason:
            'absent is not a refusal — no candidate was offered, so nothing '
            'was refused, and no fault is owed',
      );
    });

    test('only the authorized final cursor becomes durable', () {
      final result = _run(_delivery(nativeOffersOnNonFinalPages: false));

      expect(
        result.durableCursorAfter.take(_pageCount - 1),
        everyElement(isNull),
        reason:
            'seven commits landed with real steps in them and the cursor did '
            'not move once. An interrupted read resumes from before page one',
      );
      expect(result.durableCursorAfter.last, cursor('drained'));
      expect(
        result.engine.state.steps.checkpoint.syncCount,
        _pageCount,
        reason: 'eight pages committed, each counted',
      );
    });

    test('every page is credited exactly once and the read totals', () {
      final result = _run(_delivery(nativeOffersOnNonFinalPages: false));

      const int perPage = _bucketsPerPage * _stepsPerBucket;
      expect(result.granted, List<int>.filled(_pageCount, perPage));
      expect(
        result.engine.state.steps.totalGranted,
        _pageCount * perPage,
        reason:
            'the oldest page arrives last and is real movement; lateness is '
            'not a reason to discard it',
      );
      expect(
        result.engine.state.steps.lateDiscardedSlices,
        0,
        reason: 'nothing was discarded, so nothing may be counted as discarded',
      );
      expect(
        result.engine.state.steps.checkpoint.originWatermarks.keys,
        <StepOriginKey>[phone],
        reason: 'only the drained page settles, and only for its own origin',
      );
    });

    test('repeating the whole sync cannot duplicate a grant', () {
      final List<PlatformSyncPage> pages = _delivery(
        nativeOffersOnNonFinalPages: false,
      );
      final result = _run(pages);
      final int after = result.engine.state.steps.totalGranted;
      final String durable = _amountBearingState(result.engine.state);

      // The same eight pages again — a resume that re-reads what it already
      // had, which is what a cursor arriving from the wrong page would cause.
      for (final PlatformSyncPage page in pages) {
        expect(
          grantedBy(reconcile(result.engine, translate(page))),
          0,
          reason: 'an absolute restatement of a granted slice grants nothing',
        );
      }

      expect(result.engine.state.steps.totalGranted, after);
      expect(
        _amountBearingState(result.engine.state),
        durable,
        reason:
            'a replay moves the commit counters and nothing that decides an '
            'amount. Compared as whole canonical state rather than by totals '
            'alone, because a totals check passes on a state whose watermarks '
            'or granted slices moved underneath it',
      );
      expect(
        result.engine.state.steps.checkpoint.syncCount,
        _pageCount * 2,
        reason:
            'the replay did commit — sixteen syncs, not eight. The state is '
            'unchanged because the arithmetic is idempotent, not because the '
            'pages were ignored',
      );
    });
  });

  group('the delivery the iPhone actually produced', () {
    test('offered a candidate on all seven non-final pages and was refused', () {
      final result = _run(_delivery(nativeOffersOnNonFinalPages: true));

      final int faultingPages = result.faults
          .where(
            (List<SyncFault> f) =>
                f.contains(SyncFault.cursorOfferedWhenProhibited),
          )
          .length;
      expect(
        faultingPages,
        _pageCount - 1,
        reason:
            'exactly the seven faults the device reported across its eight '
            'pages. This is the reconstruction, not a hypothesis about it',
      );
      expect(
        result.faults.last,
        isEmpty,
        reason: 'the drained page was entitled to offer and did not fault',
      );
      expect(
        result.authorizations,
        <CursorAuthorization>[
          ...List<CursorAuthorization>.filled(
            _pageCount - 1,
            CursorAuthorization.prohibitedNonFinalPage,
          ),
          CursorAuthorization.authorized,
        ],
        reason:
            'refused for the right reason. A refusal that names the wrong rule '
            'is indistinguishable from a correct one, which is how a matrix '
            'stays green through a swapped pair',
      );
    });

    test('never made a prohibited candidate durable', () {
      final result = _run(_delivery(nativeOffersOnNonFinalPages: true));

      for (int i = 0; i < _pageCount - 1; i++) {
        expect(
          result.durableCursorAfter[i],
          isNull,
          reason:
              'page $i offered a prohibited candidate and the bridge dropped '
              'it before the reconciler could see it. `StepCheckpointAuthorized` '
              'carried the unchanged cursor forward',
        );
      }
      expect(
        result.durableCursorAfter.last,
        cursor('drained'),
        reason: 'the only cursor that ever reached the save',
      );
    });

    test('reached the same durable state as a correct adapter would have', () {
      // The accounting-safety proof for the save currently on the device: the
      // defect was noisy and inert. If these two states differed in any field
      // that decides an amount, the iPhone save would have to be reset.
      final defective = _run(_delivery(nativeOffersOnNonFinalPages: true));
      final corrected = _run(_delivery(nativeOffersOnNonFinalPages: false));

      expect(
        canonicalDurableGameState(defective.engine.state),
        canonicalDurableGameState(corrected.engine.state),
        reason:
            'no step was skipped and no step was granted twice. The seven '
            'faults were a report about the adapter, not damage to the ledger',
      );
      expect(defective.granted, corrected.granted);
    });

    test(
      'a resume from the prohibited candidate is what was being prevented',
      () {
        // Why the refusal is load-bearing, stated as an outcome rather than as
        // a comment. Had page one's candidate become durable, a process death
        // before page two would resume from "the whole read is done" and pages
        // two through eight would never be delivered again — silently, because
        // completeness was correctly partial, so nothing counts it.
        final List<PlatformSyncPage> pages = _delivery(
          nativeOffersOnNonFinalPages: true,
        );

        final GameEngine engine = newEngine();
        reconcile(engine, translate(pages.first));

        expect(
          engine.state.steps.checkpoint.cursor,
          isNull,
          reason:
              'resuming would skip seven eighths of the read, and the steps '
              'would be unreachable forever',
        );
        expect(
          engine.state.steps.totalGranted,
          _bucketsPerPage * _stepsPerBucket,
          reason: 'page one is credited in full; only its cursor is refused',
        );
      },
    );
  });
}
