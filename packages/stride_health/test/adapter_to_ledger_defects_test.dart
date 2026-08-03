// TWO DEFECTS, WRITTEN AS TESTS BEFORE EITHER WAS FIXED. BOTH NOW PASS.
//
// This file was headed "TWO FAILING TESTS ... DO NOT ADJUST THEM", and the
// instruction held: neither test was adjusted, and both went green when the
// production code moved to meet them. `authorizeCursor` closed defect 1, and
// `CompleteThrough.horizonFor` now clamps, which closed defect 2 — the "not
// applied here" notes below describe fixes that have since been applied
// exactly as written. They are kept, unedited, as the record of what the
// defect was and what it cost, which is the part a diff six months from now
// will not otherwise carry.
//
// What must NOT change is the assertions. They are the regression pins.
//
// Both were found while building the S-01A adapter-to-ledger evidence suite.
// Both are reachable from an ordinary, well-meaning native adapter — neither
// needs a crash, a race, or a malicious page. Both lose a player's real steps
// silently: no event, no counter, no divergence in any diagnostic.
//
// They are here, failing, rather than folded into the passing suite in a shape
// that accommodates the current behaviour. This project has repeatedly found
// that the expensive defects are the ones a test was quietly adjusted around,
// and the accommodation is invisible in a diff six months later.
//
// The fixes are in `stride_health/lib/src/platform_step_source.dart` and
// `stride_core/lib/src/steps/completeness.dart`, both of which are outside the
// S-01A evidence agent's file ownership. They are described below and are NOT
// applied here.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'adapter_ledger_support.dart';

void main() {
  _cursorOnANonFinalPage(); // defect 1
  _completenessBeyondTheQueriedInterval(); // defect 2
}

// ===========================================================================
// DEFECT 1 — a mid-read cursor becomes durable while pages are outstanding
// ===========================================================================
//
// ## What happens
//
// `PlatformStepSource.translate` builds `SyncCursor` from `page.nextCursor`
// unconditionally:
//
//     final SyncCursor? cursor =
//         page.nextCursor == null ? null : SyncCursor(page.nextCursor!);
//
// It never consults `page.pagination.isFinalPage`. So a page that declares
// itself NOT final and still offers a cursor has that cursor carried into
// `IncrementalSync.nextCursor` → `ReconciliationAccepted.cursorToAuthorize` →
// `StepCheckpointAuthorized` → **the durable checkpoint**, while pages 2..n of
// the read have not been delivered.
//
// ## Why it costs steps
//
// Reconcile page 1 of 9. The cursor advances to "after the whole read". The
// process then dies, or the app is backgrounded, or the user force-quits — none
// of which is exotic on a phone. The next launch resumes from that cursor, the
// provider reports nothing new, and pages 2..9 are never delivered again.
//
// Nothing detects it. Completeness is correctly downgraded to `PartialDelivery`
// so nothing is *settled*, and `lateDiscardedSlices` therefore never
// increments — the counter that exists to make the design's one lossy path
// visible does not fire, because this is a different lossy path. The steps are
// simply never asked for again.
//
// This is the 55,200-step defect on the cursor axis rather than the
// completeness axis. `DECISIONS/0014` closed the completeness axis
// structurally; the cursor axis was not closed with it.
//
// ## Why it is a bridge defect and not "the caller's job"
//
// Three reasons.
//
// 1. `PlatformStepSource`'s own contract says so. Its class comment: "It
//    converts, validates the combination of fields the adapter sent, and
//    reports what it had to correct." A cursor on a non-final page is exactly a
//    combination of fields, and it is exactly the kind the class already
//    validates — it drops a cursor offered alongside `unavailable` and raises
//    `SyncFault.cursorOfferedWhenProhibited` for it. A non-final page is the
//    same prohibition; the fault's own doc comment says "a path that must not
//    advance one", not "the unavailable path".
//
// 2. There is no caller. Grep for `fetchSteps` across `lib/` and every
//    package's `lib/`: the only hits are the two implementations and the
//    interface. No production code drains pages, so there is nowhere else the
//    rule could currently live, and the first driver written will inherit
//    whatever the bridge permits.
//
// 3. `SyncFetch` deliberately does not expose pagination to the reconciler —
//    "Pagination is the caller's loop state, not something the reconciler ever
//    sees." So the core structurally *cannot* refuse this. The bridge is the
//    only layer that holds both facts at once.
//
// ## The fix, not applied here
//
// In `translate`, in `packages/stride_health/lib/src/platform_step_source.dart`:
// build the cursor only when `page.pagination.isFinalPage`, and add
// `SyncFault.cursorOfferedWhenProhibited` when a non-final page offered one.
// That is the existing fault, the existing bias ("settles fewer buckets and
// grants no more steps"), and a two-line change. `Scripts/check-step-model.sh`
// would then be the natural place to anchor it.

void _cursorOnANonFinalPage() {
  group('DEFECT: a non-final page advances the durable cursor', () {
    // An ordinary mid-read page: `partial`, because it is, and offering a
    // candidate cursor anyway — which adapters do, and which is exactly what
    // `authorizeCursor` exists to refuse. Offering is not the defect; adopting
    // it would be.
    PlatformSyncPage midRead() => pincrementalPage(
      isFinalPage: false,
      completeness: PlatformCompletenessKind.partial,
      observations: <PlatformStepObservation>[pobs(phoneBytes, 40, 800)],
      continuation: 'page2',
      nextCursor: 'drained-anchor',
    );

    test('the bridge drops a cursor offered mid-read', () {
      final SyncFetch fetch = translate(midRead());

      expect(fetch.isFinalPage, isFalse);
      expect(
        fetch.continuation,
        isNotNull,
        reason: 'the read is resumable, which is what makes it unfinished',
      );

      expect(
        (fetch.response as IncrementalSync).nextCursor,
        isNull,
        reason:
            'a cursor the adapter offered before it had drained the read is a '
            'cursor it cannot stand behind. Persisting one would make the next '
            'sync claim progress the ledger never recorded.',
      );
      expect(fetch.faults, contains(SyncFault.cursorOfferedWhenProhibited));
    });

    test('a crash mid-read does not skip the pages that were never delivered', () {
      // The whole cost, as an observable outcome: steps that exist, that the
      // adapter would have delivered, and that the player never receives.
      final GameEngine engine = newEngine();

      // Page 1 of 2 is reconciled and committed.
      final EngineResult first = ingest(engine, midRead());
      expect(grantedBy(first), 800);

      expect(
        engine.state.steps.checkpoint.cursor,
        isNull,
        reason:
            'the durable cursor must not move until the read is drained. It '
            'currently becomes "drained-anchor" — the position AFTER page 2 — '
            'so a resume from here asks the provider for changes since a point '
            'past data it never sent.',
      );

      // What the resume then looks like. The provider honours the cursor it was
      // given and reports nothing new, because as far as it is concerned this
      // read completed.
      final EngineResult resumed = ingest(
        engineAt(engine.state),
        pnoChangePage(isFinalPage: true, nextCursor: 'drained-anchor'),
      );
      expect(grantedBy(resumed), 0);

      expect(
        engine.state.steps.lateDiscardedSlices,
        0,
        reason:
            'and nothing counts the loss: the slices were never settled, so '
            'the one counter that exists for a lost step does not fire',
      );
    });
  });
}

// ===========================================================================
// DEFECT 2 — a completeness assertion settles beyond the interval it queried
// ===========================================================================
//
// ## What happens
//
// `CompleteThrough.horizonFor` returns `throughMillis` whenever the scope
// covers the origin. It never consults `scope.intervalEndMillis` — the interval
// the adapter says it actually queried.
//
//     int? horizonFor(StepOriginKey origin) =>
//         scope.origins.covers(origin) ? throughMillis : null;
//
// Its sibling does clamp, with the reason written out:
//
//     // RecoveryCompleteThrough
//     // Never claim more than the window actually covered.
//     return throughMillis < scope.intervalEndMillis
//         ? throughMillis : scope.intervalEndMillis;
//
// `CompletenessScope.coversBucket` also encodes the intended rule —
// `bucketEndMillis > intervalStartMillis && bucketEndMillis <=
// intervalEndMillis` — and is called from nowhere in production. The rule was
// written down twice and applied to only one of the two settling shapes.
//
// ## Why it costs steps
//
// `PlatformStepSource._completeness` copies `throughMillis` and the interval
// straight off the wire, unrelated to each other and unvalidated. So an adapter
// that queried a short interval and reported a stale or optimistic
// `throughMillis` — a HealthKit anchored query whose `throughMillis` is "now"
// rather than the end of the sampled interval is the obvious way to write it by
// accident — settles every bucket up to that instant, for every origin in
// scope, including buckets it never looked at.
//
// A later delivery for one of those buckets is then `isSettled`, grants
// nothing, and increments `lateDiscardedSlices`. Permanent, per the design:
// "the record proving whether it was already credited is gone".
//
// ## Why it is not caught today
//
// Every existing test builds the two figures equal. `step_support.dart`'s
// `completeThrough(index)` sets `intervalEndMillis: t0 + index * hour` and
// `throughMillis: t0 + index * hour` from the same argument, so the divergence
// is unrepresentable in the core's own suite. The support builder in
// `adapter_ledger_support.dart` takes them as separate parameters for exactly
// this reason.
//
// ## The fix, not applied here
//
// Either clamp in `CompleteThrough.horizonFor` exactly as
// `RecoveryCompleteThrough` already does — one line, in
// `packages/stride_core/lib/src/steps/completeness.dart` — or refuse the
// contradiction at the bridge with a fault, in the same family as
// `contradictoryOriginScope`. Clamping is the smaller change and matches the
// documented bias: "settles fewer buckets and grants no more steps".

void _completenessBeyondTheQueriedInterval() {
  group('DEFECT: completeness settles past the interval it queried', () {
    test('an assertion never vouches beyond what it says it read', () {
      final CompleteThrough overclaimed = CompleteThrough(
        throughMillis: t0 + 600 * hour,
        scope: CompletenessScope(
          dataType: HealthDataType.steps,
          origins: SomeOrigins(<StepOriginKey>{phone}),
          intervalStartMillis: t0,
          intervalEndMillis: t0 + 10 * hour,
          queryGeneration: 1,
        ),
      );

      expect(
        overclaimed.horizonFor(phone),
        lessThanOrEqualTo(t0 + 10 * hour),
        reason:
            'the adapter queried ten hours and vouched for six hundred. It '
            'cannot have delivered what it did not read. RecoveryCompleteThrough '
            'clamps for exactly this reason; CompleteThrough does not.',
      );
    });

    test('an over-claimed horizon buries a bucket the adapter never read', () {
      // The cost, end to end and observable. Two runs of identical data; the
      // only difference is the `throughMillis` the adapter put on the wire.
      GameEngine run({required int throughIndex}) {
        final GameEngine engine = newEngine();

        // A long-lived ledger: an early bucket, and a recent one far enough
        // ahead that retention alone is not what decides this.
        ingest(
          engine,
          pincrementalPage(
            isFinalPage: true,
            completeness: PlatformCompletenessKind.completeThrough,
            observations: <PlatformStepObservation>[
              pobs(phoneBytes, 0, 100),
              pobs(phoneBytes, 700, 100),
            ],
            throughIndex: throughIndex,
            // The adapter says it queried ten hours, and says so honestly.
            // Only its completeness claim differs between the two runs.
            fromIndex: 0,
            toIndex: 10,
            nextCursor: 'c1',
          ),
        );
        return engine;
      }

      // Honest: vouches for the ten hours it queried.
      final GameEngine honest = run(throughIndex: 10);
      // A later delivery, and nothing more. It vouches for nothing and offers
      // no cursor: the question is whether the EARLIER assertion settled hour
      // 400, so this page must not make an assertion of its own.
      final EngineResult honestLate = ingest(
        honest,
        pincrementalPage(
          isFinalPage: true,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 400, 5000)],
        ),
      );
      expect(
        grantedBy(honestLate),
        5000,
        reason: 'the control: hour 400 is outside any settled span',
      );

      // Over-claiming: same query, same data, a `throughMillis` six hundred
      // hours out.
      final GameEngine overclaiming = run(throughIndex: 600);
      final EngineResult overclaimedLate = ingest(
        overclaiming,
        pincrementalPage(
          isFinalPage: true,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 400, 5000)],
        ),
      );

      expect(
        grantedBy(overclaimedLate),
        5000,
        reason:
            'hour 400 was never queried and never delivered, so nothing can '
            'have settled it. It currently grants 0 and increments '
            'lateDiscardedSlices — five thousand real steps, permanently.',
      );
      expect(overclaiming.state.steps.lateDiscardedSlices, 0);
    });
  });
}
