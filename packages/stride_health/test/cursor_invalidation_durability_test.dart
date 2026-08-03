// When a replacement cursor may become durable after invalidation — and when
// it may not.
//
// A changes token can expire. The adapter then reports `cursorInvalidated`,
// performs a bounded authoritative rescan, and offers a replacement token. The
// question this file settles is **when that replacement is allowed to stick**.
//
// The rule:
//
//   A replacement cursor may become durable ONLY when
//     1. bounded authoritative recovery completed
//     2. the result is the final page
//     3. recovery completeness is valid (not truncated, not partial)
//     4. the ledger and snapshot commit succeeds
//
//   A partial, interrupted, malformed or unsuccessful recovery must DROP the
//   candidate, and the previous durable cursor remains authoritative.
//
// Both directions matter, and the second is the dangerous one. A replacement
// cursor persisted after an incomplete recovery means the next sync resumes
// from a point the ledger never reached — every step in the gap is
// unrecoverable, and nothing reports it, because a cursor carries no evidence
// of what it skipped.
//
// **Every assertion is on actual cursor DISPOSITION**, not on a status code or
// the presence of a fault. A fault raised beside a cursor that still became
// durable is not a refusal; it is a note attached to a loss.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'adapter_ledger_support.dart';

void main() {
  /// An engine with a durable cursor already established, so "the previous
  /// cursor remains authoritative" is a claim with something to lose.
  (GameEngine, SyncCursor) engineWithCursor() {
    final GameEngine engine = newEngine();
    final EngineResult seeded = ingest(
      engine,
      pincrementalPage(
        isFinalPage: true,
        completeness: PlatformCompletenessKind.completeThrough,
        observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
        throughIndex: 1,
        toIndex: 1,
        nextCursor: 'established',
      ),
    );
    expect(seeded.isAccepted, isTrue);
    final SyncCursor? established = authorizedCursor(seeded);
    expect(
      established,
      isNotNull,
      reason: 'the fixture needs a durable cursor',
    );
    return (engine, established!);
  }

  // The local `window()` helper is gone: `precoveryPage` requires
  // `isTruncated` and builds the window from it, so a recovery fixture cannot
  // be written without saying whether its window was clamped. The default
  // window — hour 0 to hour 2 — is the same one this helper produced.

  // =========================================================================
  // 1. The allowed case
  // =========================================================================
  group('a completed bounded recovery MAY replace the cursor', () {
    test('the replacement is authorized on a final, untruncated recovery', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[
            pobs(phoneBytes, 0, 1200),
            pobs(phoneBytes, 1, 900),
          ],
          throughIndex: 2,
          toIndex: 2,
          nextCursor: 'replacement',
        ),
      );

      expect(result.isAccepted, isTrue);
      expect(
        authorizedCursor(result),
        cursor('replacement'),
        reason:
            'a completed bounded recovery is exactly the case a replacement '
            'exists for. Withholding it forever would leave the caller passing '
            'a dead cursor and repeating recovery on every sync.',
      );
      expect(authorizedCursor(result), isNot(before));
    });

    test('it becomes durable only AFTER the ledger commits', () {
      // The ordering rule, asserted structurally: replay the events up to but
      // not including the authorization and confirm the ledger has already
      // moved. If the checkpoint were emitted first, this state would show no
      // grant while claiming a new cursor.
      final (GameEngine engine, SyncCursor before) = engineWithCursor();
      final GameState atRecovery = engine.state;

      final EngineResult result = ingest(
        engine,
        precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 900)],
          throughIndex: 2,
          toIndex: 2,
          nextCursor: 'replacement',
        ),
      );

      final GameState beforeCheckpoint = commitUpTo<StepCheckpointAuthorized>(
        atRecovery,
        result.events,
      );

      expect(
        beforeCheckpoint.steps.checkpoint.cursor,
        before,
        reason:
            'until the checkpoint event is applied, the OLD cursor is still '
            'the durable one. A crash here must resume from it.',
      );
      expect(
        beforeCheckpoint.steps.totalGranted,
        greaterThan(atRecovery.steps.totalGranted),
        reason:
            'the grant is already durable at the moment the cursor is '
            'authorized -- the ledger leads, the cursor follows',
      );
    });

    test('a crash between grant and checkpoint keeps the old cursor', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();
      final GameState atRecovery = engine.state;

      final EngineResult result = ingest(
        engine,
        precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 900)],
          throughIndex: 2,
          toIndex: 2,
          nextCursor: 'replacement',
        ),
      );

      final GameState crashed = commitUpTo<StepCheckpointAuthorized>(
        atRecovery,
        result.events,
      );

      expect(crashed.steps.checkpoint.cursor, before);
      expect(crashed.steps.checkpoint.cursor, isNot(cursor('replacement')));
      // Neither assertion above can fail. `commitUpTo<StepCheckpointAuthorized>`
      // truncates before the only event that writes `checkpoint.cursor`, so the
      // applied prefix cannot move it whatever the bridge does — fed
      // `const <GameEvent>[]` this test still passed, start to finish.
      //
      // The claim in the test's name is about ORDER, and this is the assertion
      // that carries it: the grant has already landed in the state a crash
      // would wake up in. Its live sibling above pins the same property; this
      // one exists because the crash direction is the one that loses steps, and
      // it was the half that was resting on nothing.
      expect(
        crashed.steps.totalGranted,
        greaterThan(atRecovery.steps.totalGranted),
        reason:
            'a crash here must resume from the old cursor with the recovery '
            'grant already durable. Re-reading the same window is then safe: '
            'the overlap arithmetic sees a slice it has already credited. If '
            'the checkpoint were emitted first, this state would claim a new '
            'cursor over a ledger that recorded nothing.',
      );
    });
  });

  // =========================================================================
  // 2. The refused cases — the dangerous direction
  // =========================================================================
  group('an incomplete recovery may NOT replace the cursor', () {
    /// Asserts the candidate was dropped and the established cursor survives.
    ///
    /// **Disposition, not event absence.** An earlier version of this helper
    /// required that NO checkpoint event be emitted, and that was wrong: the
    /// engine legitimately re-affirms the existing checkpoint on a refused
    /// recovery — same cursor, updated sync bookkeeping. Asserting on the event
    /// would have failed correct behaviour while saying nothing about the value
    /// that actually persists.
    ///
    /// What matters is that the durable cursor is still the old one and the
    /// candidate never became it.
    void expectCursorUnmoved(
      EngineResult result,
      GameEngine engine,
      SyncCursor before,
      String why,
    ) {
      final SyncCursor? authorized = authorizedCursor(result);
      if (authorized != null) {
        expect(
          authorized,
          before,
          reason:
              'a checkpoint was authorized carrying a DIFFERENT cursor. The '
              'candidate was adopted: $why',
        );
      }
      expect(
        engine.state.steps.checkpoint.cursor,
        before,
        reason: 'the previous durable cursor remains authoritative: $why',
      );
      expect(
        engine.state.steps.checkpoint.cursor,
        isNot(cursor('replacement')),
        reason: 'the replacement must never become durable here: $why',
      );
    }

    test('a TRUNCATED recovery drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        // The adapter clamped the window and STILL declared the recovery
        // complete. Deliberate: with the declaration set to `partial` the
        // candidate would be refused for two independent reasons at once, and
        // the test could not say which one it was observing. Truncation is now
        // the only thing wrong with this page, and the bridge's downgrade to
        // PartialDelivery is what the refusal rests on.
        precoveryPage(
          isFinalPage: true,
          isTruncated: true,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 900)],
          throughIndex: 2,
          toIndex: 2,
          nextCursor: 'replacement',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'the window was clamped, so an unreachable gap exists. A replacement '
        'cursor would place the next read after data nobody ever delivered.',
      );
    });

    test('a NON-FINAL recovery page drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        // `partial` is the honest declaration for a page that says more are
        // coming, so non-finality is what the refusal must rest on.
        precoveryPage(
          isFinalPage: false,
          isTruncated: false,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          nextCursor: 'replacement',
          continuation: 'page2',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'pages remain outstanding. This is the 55,200-step defect on the '
        'cursor axis: resume from here and pages 2..N are never delivered.',
      );
    });

    test('a recovery with PARTIAL completeness drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          nextCursor: 'replacement',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'the adapter did not vouch for the window it read',
      );
    });

    test('an invalidation with NO window drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        pcontractViolationPage(
          violation:
              'cursorInvalidated with no rescan window — a recovery that '
              'claims to have completed a window it never names',
          status: PlatformSyncStatus.cursorInvalidated,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          throughIndex: 2,
          toIndex: 2,
          rescan: null,
          nextCursor: 'replacement',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'without a window there is no authoritative figure and no bound. '
        'Granting from it would be guessing.',
      );
    });

    test('an invalidation with NO window REPORTS the dropped cursor', () {
      // The full disposition, asserted in one place, because the drop and the
      // report are separate acts and only one of them was happening.
      //
      // The candidate was always discarded — `ProviderUnavailableSync` has no
      // field a cursor could travel in — but no fault named it. The
      // structurally identical `unavailable` path did raise
      // `cursorOfferedWhenProhibited`, and the asymmetry was an ordering
      // artefact rather than a decision: `authorizeCursor` runs first and
      // answers `authorized` for a page that is final, recovery-complete and
      // untruncated, so the fault channel was settled before the missing window
      // was noticed. A cursor silently dropped is a cursor nobody investigates.
      final (GameEngine engine, SyncCursor before) = engineWithCursor();
      final GameState atRefusal = engine.state;

      final SyncFetch fetch = translate(
        pcontractViolationPage(
          violation:
              'cursorInvalidated with no rescan window, offering a replacement '
              'token anyway',
          status: PlatformSyncStatus.cursorInvalidated,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          throughIndex: 2,
          toIndex: 2,
          rescan: null,
          nextCursor: 'replacement',
        ),
      );

      expect(
        fetch.faults,
        containsAll(<SyncFault>[
          SyncFault.invalidatedWithoutRescan,
          SyncFault.cursorOfferedWhenProhibited,
        ]),
        reason:
            'both faults: one names the missing window, the other names the '
            'token that was thrown away because of it',
      );

      final EngineResult result = reconcile(engine, fetch);

      expect(engine.state.steps.checkpoint.cursor, before);
      expect(
        engine.state.steps.checkpoint.cursor,
        isNot(cursor('replacement')),
      );
      expect(grantedBy(result), 0, reason: 'a refused page grants nothing');
      expect(
        engine.state.steps.checkpoint.originWatermarks,
        atRefusal.steps.checkpoint.originWatermarks,
        reason: 'no horizon may move on a delivery that answered nothing',
      );
    });

    test('an invalidation with no window and NO candidate is quiet', () {
      // The fault must name a real event. Raising it on a page that offered
      // nothing would make it fire on ordinary traffic, and a diagnostic that
      // fires on ordinary traffic is one nobody reads.
      // Neither the engine nor the established cursor matters here: the claim
      // is entirely about which faults the bridge raises.

      final SyncFetch fetch = translate(
        pcontractViolationPage(
          violation: 'cursorInvalidated with no rescan window and no token',
          status: PlatformSyncStatus.cursorInvalidated,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          throughIndex: 2,
          toIndex: 2,
          rescan: null,
        ),
      );

      expect(fetch.faults, contains(SyncFault.invalidatedWithoutRescan));
      expect(
        fetch.faults,
        isNot(contains(SyncFault.cursorOfferedWhenProhibited)),
        reason: 'nothing was offered, so nothing was refused',
      );
    });

    test('a MALFORMED OBSERVATION in a recovery drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      // Built with `precoveryPage`, not `pcontractViolationPage`. Nothing about
      // this page's SHAPE is illegal — a final, untruncated, recovery-complete
      // page is the one combination that may replace a cursor. The defect is
      // one observation, and it is caught by `OriginGateway.toObservation`
      // rather than by the contract check. Using the violation builder here
      // said "this page breaks the contract" about a page that does not, which
      // is the builder standing in for "I want a weird observation" — not what
      // it is for.
      //
      // The name changed with it: the bridge answers `ProviderUnavailableSync`
      // and never reaches `malformedSyncBatch`, so calling it a malformed
      // *batch* named a code path the test does not take.
      final EngineResult result = ingest(
        engine,
        precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: <PlatformStepObservation>[
            // Negative steps: an adapter fault, not a gameplay outcome.
            pobs(phoneBytes, 0, -50),
          ],
          throughIndex: 2,
          toIndex: 2,
          nextCursor: 'replacement',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'a batch that violated an invariant was refused; nothing it carried, '
        'including its cursor, may be adopted',
      );
    });

    test('an unavailable provider mid-recovery drops the candidate', () {
      final (GameEngine engine, SyncCursor before) = engineWithCursor();

      final EngineResult result = ingest(
        engine,
        punavailablePage(
          reason: PlatformUnavailableReason.transientFailure,
          nextCursor: 'replacement',
        ),
      );

      expectCursorUnmoved(
        result,
        engine,
        before,
        'the provider could not answer; a cursor it offered anyway stands '
        'behind nothing',
      );
    });
  });
}
