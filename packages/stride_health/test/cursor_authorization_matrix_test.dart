// The whole cursor-authorization matrix, as a table.
//
// `cursor_authorization.dart` documents a matrix and says it is "exhaustively
// tested by test/cursor_authorization_matrix_test.dart". Until this file
// existed, it was not: the rules were exercised incidentally, by tests that
// were about something else and that happened to pass a page through the
// decision on their way somewhere. That is how a rule ends up asserted in three
// places and enforced in none, which is the exact history the authorization
// function was extracted to end.
//
// Two layers, deliberately:
//
//   1. `authorizeCursor` called directly — the pure decision, every row.
//   2. the same rows driven platform-page → bridge → `GameEngine` → ledger,
//      asserting what actually PERSISTS.
//
// The second is the one that matters. A decision that is right in isolation and
// discarded downstream is not a control, and this project has already shipped
// one fault raised beside a cursor that became durable anyway.
//
// Every row asserts, end to end:
//
//   * the cursor that entered the `SyncResponse`
//   * the durable cursor after a successful commit
//   * the durable cursor after an interruption before the checkpoint
//   * the fault raised, or the absence of one
//   * steps granted, and whether any watermark advanced
//   * for a contract violation, that `GameState` is COMPLETELY unchanged
//
// No device, no channel, no health service, no wall clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

import 'adapter_ledger_support.dart';

/// The candidate every row offers, except the one that offers none.
const String candidate = 'replacement';

/// The cursor already durable before each row runs.
const String established = 'established';

/// The cursor a response actually carried, whatever shape it took.
///
/// Read off the response rather than off a fault or a status: a fault beside a
/// cursor that still travelled is a note attached to a loss.
SyncCursor? responseCursor(SyncResponse response) => switch (response) {
  IncrementalSync(:final SyncCursor? nextCursor) => nextCursor,
  NoChangeSync(:final SyncCursor? nextCursor) => nextCursor,
  CursorInvalidatedSync(:final SyncCursor? nextCursor) => nextCursor,
  // Neither shape has a field a cursor could travel in, which is the
  // structural half of the guarantee.
  ProviderUnavailableSync() => null,
  ContractViolationSync() => null,
};

/// One row of the matrix.
final class Row {
  const Row({
    required this.name,
    required this.page,
    required this.authorization,
    required this.cursorSurvives,
    required this.grant,
    required this.settles,
    required this.fault,
    this.violation,
  });

  /// What the delivery is, in the vocabulary of the matrix.
  final String name;

  /// Built fresh per use: a bridge that memoised would otherwise make several
  /// of these pass for the wrong reason.
  final PlatformSyncPage Function() page;

  /// The pure decision, or null when the delivery is rejected before any
  /// cursor question is reached.
  final CursorAuthorization? authorization;

  /// Whether [candidate] reaches the response and then the durable checkpoint.
  final bool cursorSurvives;

  final int grant;

  /// Whether the phone's completeness watermark strictly advances.
  final bool settles;

  /// The fault this row must raise, or null for a clean read.
  final SyncFault? fault;

  /// Set when the delivery is rejected whole.
  final SyncContractViolation? violation;

  bool get isRejected => violation != null;
}

final List<PlatformStepObservation> _payload = <PlatformStepObservation>[
  pobs(phoneBytes, 1, 900),
];

final List<Row> matrix = <Row>[
  // -- incremental ----------------------------------------------------------
  Row(
    name: 'incremental, non-final',
    page: () => pincrementalPage(
      isFinalPage: false,
      completeness: PlatformCompletenessKind.partial,
      observations: _payload,
      continuation: 'p2',
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedNonFinalPage,
    cursorSurvives: false,
    grant: 900,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    name: 'incremental, final, partial delivery',
    page: () => pincrementalPage(
      isFinalPage: true,
      completeness: PlatformCompletenessKind.partial,
      observations: _payload,
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedIncompleteDelivery,
    cursorSurvives: false,
    grant: 900,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    name: 'incremental, final, valid completeThrough',
    page: () => pincrementalPage(
      isFinalPage: true,
      completeness: PlatformCompletenessKind.completeThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.authorized,
    cursorSurvives: true,
    grant: 900,
    settles: true,
    fault: null,
  ),

  // -- recovery -------------------------------------------------------------
  Row(
    name: 'recovery, non-final',
    page: () => precoveryPage(
      isFinalPage: false,
      isTruncated: false,
      completeness: PlatformCompletenessKind.partial,
      observations: _payload,
      continuation: 'p2',
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedNonFinalPage,
    cursorSurvives: false,
    grant: 900,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    name: 'recovery, final, partial delivery',
    page: () => precoveryPage(
      isFinalPage: true,
      isTruncated: false,
      completeness: PlatformCompletenessKind.partial,
      observations: _payload,
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedIncompleteDelivery,
    cursorSurvives: false,
    grant: 900,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    // The window was clamped, so a gap exists that nobody delivered. The
    // completeness declaration is deliberately the VALID one, so truncation is
    // the only thing this row can be refused for.
    name: 'recovery, final, truncated window',
    page: () => precoveryPage(
      isFinalPage: true,
      isTruncated: true,
      completeness: PlatformCompletenessKind.recoveryCompleteThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedTruncatedRecovery,
    cursorSurvives: false,
    grant: 900,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    name: 'recovery, final, valid recoveryCompleteThrough',
    page: () => precoveryPage(
      isFinalPage: true,
      isTruncated: false,
      completeness: PlatformCompletenessKind.recoveryCompleteThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.authorized,
    cursorSurvives: true,
    grant: 900,
    settles: true,
    fault: null,
  ),

  // -- noChange -------------------------------------------------------------
  Row(
    // The documented exception, and the only authorized row that settles
    // nothing. That is exactly what makes it safe: no bucket was marked
    // accounted-for, so a later delivery inside the window is still grantable.
    name: 'noChange, final, empty, partial',
    page: () => pnoChangePage(isFinalPage: true, nextCursor: candidate),
    authorization: CursorAuthorization.authorized,
    cursorSurvives: true,
    grant: 0,
    settles: false,
    fault: null,
  ),
  Row(
    name: 'noChange, non-final',
    page: () => pnoChangePage(
      isFinalPage: false,
      continuation: 'p2',
      nextCursor: candidate,
    ),
    authorization: CursorAuthorization.prohibitedNonFinalPage,
    cursorSurvives: false,
    grant: 0,
    settles: false,
    fault: SyncFault.cursorOfferedWhenProhibited,
  ),
  Row(
    name: 'noChange carrying observations',
    page: () => pcontractViolationPage(
      violation: 'noChange carrying the observations it says did not arrive',
      status: PlatformSyncStatus.noChange,
      completeness: PlatformCompletenessKind.partial,
      observations: _payload,
      nextCursor: candidate,
    ),
    authorization: null,
    cursorSurvives: false,
    grant: 0,
    settles: false,
    fault: SyncFault.noChangeWithPayload,
    violation: SyncContractViolation.noChangeWithPayload,
  ),
  Row(
    name: 'noChange asserting a complete scope',
    page: () => pcontractViolationPage(
      violation: 'noChange vouching for a window it says it did not read',
      status: PlatformSyncStatus.noChange,
      completeness: PlatformCompletenessKind.completeThrough,
      throughIndex: 2,
      toIndex: 2,
      nextCursor: candidate,
    ),
    authorization: null,
    cursorSurvives: false,
    grant: 0,
    settles: false,
    fault: SyncFault.mismatchedCompleteness,
    violation: SyncContractViolation.mismatchedCompleteness,
  ),

  // -- no candidate ---------------------------------------------------------
  Row(
    // Nothing was offered, so nothing was refused. This row exists to pin the
    // absence of a fault: raising one here would report a defect on every
    // ordinary page an adapter chooses not to move the cursor on, and a
    // diagnostic that fires constantly is a diagnostic nobody reads.
    name: 'candidate absent',
    page: () => pincrementalPage(
      isFinalPage: true,
      completeness: PlatformCompletenessKind.completeThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
    ),
    authorization: CursorAuthorization.absent,
    cursorSurvives: false,
    grant: 900,
    settles: true,
    fault: null,
  ),

  // -- mismatched completeness, both directions -----------------------------
  Row(
    name: 'incremental asserting recovery completeness',
    page: () => pcontractViolationPage(
      violation:
          'an incremental read has no rescan window, so a recovery '
          'completeness assertion has no bound to be read against',
      status: PlatformSyncStatus.incremental,
      completeness: PlatformCompletenessKind.recoveryCompleteThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
      nextCursor: candidate,
    ),
    authorization: null,
    cursorSurvives: false,
    grant: 0,
    settles: false,
    fault: SyncFault.mismatchedCompleteness,
    violation: SyncContractViolation.mismatchedCompleteness,
  ),
  Row(
    // The dangerous direction. Ordinary completeness is unbounded, so adopting
    // it from a rescan settles past the window the rescan actually covered.
    name: 'recovery asserting ordinary completeness',
    page: () => pcontractViolationPage(
      violation: 'a recovery adopting the unbounded completeness variant',
      status: PlatformSyncStatus.cursorInvalidated,
      completeness: PlatformCompletenessKind.completeThrough,
      observations: _payload,
      throughIndex: 2,
      toIndex: 2,
      rescan: pwindow(fromIndex: 0, toIndex: 2),
      nextCursor: candidate,
    ),
    authorization: null,
    cursorSurvives: false,
    grant: 0,
    settles: false,
    fault: SyncFault.mismatchedCompleteness,
    violation: SyncContractViolation.mismatchedCompleteness,
  ),
];

void main() {
  // =========================================================================
  // Layer 1 — the pure decision
  // =========================================================================
  group('authorizeCursor, called directly', () {
    CursorAuthorization decide({
      required SyncKind kind,
      required bool isFinalPage,
      required SyncCompleteness completeness,
      bool truncated = false,
      bool hasCandidate = true,
    }) => authorizeCursor(
      hasCandidate: hasCandidate,
      kind: kind,
      isFinalPage: isFinalPage,
      completeness: completeness,
      truncated: truncated,
    );

    final CompletenessScope scope = CompletenessScope(
      dataType: HealthDataType.steps,
      origins: SomeOrigins(<StepOriginKey>{phone}),
      intervalStartMillis: t0,
      intervalEndMillis: t0 + 2 * hour,
      queryGeneration: 1,
    );
    final CompleteThrough complete = CompleteThrough(
      throughMillis: t0 + 2 * hour,
      scope: scope,
    );
    final RecoveryCompleteThrough recoveryComplete = RecoveryCompleteThrough(
      throughMillis: t0 + 2 * hour,
      scope: scope,
    );
    const PartialDelivery partial = PartialDelivery();

    test('no candidate is absent, for every kind, and raises NO fault', () {
      // Swept over every kind and both page states: "absent" must not depend
      // on anything else about the page, or an ordinary page that simply does
      // not move the cursor would start reporting an adapter defect.
      for (final SyncKind kind in SyncKind.values) {
        for (final bool isFinalPage in <bool>[true, false]) {
          final CursorAuthorization decision = decide(
            hasCandidate: false,
            kind: kind,
            isFinalPage: isFinalPage,
            completeness: partial,
          );
          expect(
            decision,
            CursorAuthorization.absent,
            reason: '$kind, final=$isFinalPage',
          );
          expect(
            decision.raisesProhibitedFault,
            isFalse,
            reason: 'nothing was offered, so nothing was refused',
          );
          expect(decision.isAuthorized, isFalse);
        }
      }
    });

    test('a non-final page defeats every other consideration', () {
      for (final SyncKind kind in SyncKind.values) {
        for (final SyncCompleteness completeness in <SyncCompleteness>[
          partial,
          complete,
          recoveryComplete,
        ]) {
          expect(
            decide(kind: kind, isFinalPage: false, completeness: completeness),
            CursorAuthorization.prohibitedNonFinalPage,
            reason:
                '$kind with ${completeness.runtimeType} on a non-final page. '
                'A paginated rescan is still a rescan that has not finished.',
          );
        }
      }
    });

    test('incremental', () {
      expect(
        decide(
          kind: SyncKind.incremental,
          isFinalPage: true,
          completeness: partial,
        ),
        CursorAuthorization.prohibitedIncompleteDelivery,
      );
      expect(
        decide(
          kind: SyncKind.incremental,
          isFinalPage: true,
          completeness: complete,
        ),
        CursorAuthorization.authorized,
      );
      expect(
        decide(
          kind: SyncKind.incremental,
          isFinalPage: true,
          completeness: recoveryComplete,
        ),
        CursorAuthorization.prohibitedMismatchedCompleteness,
      );
    });

    test('recovery', () {
      expect(
        decide(
          kind: SyncKind.recovery,
          isFinalPage: true,
          completeness: partial,
        ),
        CursorAuthorization.prohibitedIncompleteDelivery,
      );
      expect(
        decide(
          kind: SyncKind.recovery,
          isFinalPage: true,
          completeness: recoveryComplete,
        ),
        CursorAuthorization.authorized,
      );
      expect(
        decide(
          kind: SyncKind.recovery,
          isFinalPage: true,
          completeness: complete,
        ),
        CursorAuthorization.prohibitedMismatchedCompleteness,
      );
      // Truncation is named before completeness, so the refusal reports the
      // real cause rather than the downgrade the real cause produced.
      expect(
        decide(
          kind: SyncKind.recovery,
          isFinalPage: true,
          completeness: recoveryComplete,
          truncated: true,
        ),
        CursorAuthorization.prohibitedTruncatedRecovery,
      );
      expect(
        decide(
          kind: SyncKind.recovery,
          isFinalPage: true,
          completeness: partial,
          truncated: true,
        ),
        CursorAuthorization.prohibitedTruncatedRecovery,
      );
    });

    test(
      'noChange on a final page is authorized — the documented exception',
      () {
        // All three completenesses, not just the reachable one. Only
        // `PartialDelivery` can arrive here through the bridge — the other two
        // are rejected as contract violations first — but this function is
        // documented as TOTAL, and the table used to name only the reachable
        // row, which reads as "the others are undefined" rather than "the
        // others are decided". Two of the three answers were undocumented and
        // untested.
        for (final SyncCompleteness completeness in <SyncCompleteness>[
          partial,
          complete,
          recoveryComplete,
        ]) {
          expect(
            decide(
              kind: SyncKind.noChange,
              isFinalPage: true,
              completeness: completeness,
            ),
            CursorAuthorization.authorized,
            reason:
                'noChange with ${completeness.runtimeType}. A drained change '
                'stream may advance the token whatever it claims about the '
                'window, because it settles nothing either way.',
          );
        }
      },
    );

    test('every outcome except absent and authorized raises the fault', () {
      for (final CursorAuthorization outcome in CursorAuthorization.values) {
        expect(
          outcome.raisesProhibitedFault,
          outcome != CursorAuthorization.absent &&
              outcome != CursorAuthorization.authorized,
          reason: '$outcome',
        );
      }
    });
  });

  // =========================================================================
  // Layer 2 — the same matrix, driven into the ledger
  // =========================================================================
  group('the matrix, end to end', () {
    /// An engine with a durable cursor and a settled watermark already in
    /// place, so "the old cursor is retained" and "no watermark advanced" are
    /// both claims with something to lose.
    GameEngine seeded() {
      final GameEngine engine = newEngine();
      final EngineResult result = ingest(
        engine,
        pincrementalPage(
          isFinalPage: true,
          completeness: PlatformCompletenessKind.completeThrough,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 0, 1200)],
          throughIndex: 1,
          toIndex: 1,
          nextCursor: established,
        ),
      );
      expect(result.isAccepted, isTrue);
      expect(engine.state.steps.checkpoint.cursor, cursor(established));
      expect(
        engine.state.steps.checkpoint.originWatermarks.containsKey(phone),
        isTrue,
        reason:
            'the fixture needs a watermark for "did not advance" to mean '
            'something',
      );
      return engine;
    }

    test('the table covers every authorization outcome the bridge can reach', () {
      // A row can be deleted, or a new outcome added to the enum, without
      // either showing up as a failure anywhere else. This is the guard.
      //
      // ## The one exclusion, and it is a finding
      //
      // `prohibitedMismatchedCompleteness` is **no longer reachable through
      // the bridge**. Rejecting the whole delivery moved that judgement
      // earlier: a mismatched completeness variant is now a
      // `ContractViolationSync` raised before `authorizeCursor` is consulted,
      // so the cursor question is never asked. The member is still correct and
      // still exercised — by layer 1 above, which calls the pure function
      // directly — but nothing in production can produce it any more.
      //
      // It is kept rather than deleted. `authorizeCursor` is documented as
      // pure and TOTAL, and a total function that answers every combination is
      // worth more than one that assumes a caller filtered two of them out
      // first — that assumption is precisely how the rule ended up answered in
      // three places before it was extracted. But an outcome no live path
      // reaches is the shape `DECISIONS/0014` keeps finding, so it is named
      // here rather than left to be rediscovered.
      const Set<CursorAuthorization> unreachableFromTheBridge =
          <CursorAuthorization>{
            CursorAuthorization.prohibitedMismatchedCompleteness,
          };

      final Set<CursorAuthorization> covered = matrix
          .map((Row r) => r.authorization)
          .whereType<CursorAuthorization>()
          .toSet();
      expect(
        covered,
        CursorAuthorization.values.toSet().difference(unreachableFromTheBridge),
        reason:
            'an authorization outcome no row exercises is an outcome nothing '
            'pins',
      );
      // The exclusion, PROVEN rather than declared.
      //
      // The set comparison above cannot establish this on its own: it compares
      // a hand-written list against the enum and never asks the bridge
      // anything. So the claim is put to the bridge directly — a page whose
      // only defect is a mismatched completeness variant, which is precisely
      // the delivery that used to reach `prohibitedMismatchedCompleteness`.
      final SyncFetch mismatched = translate(
        pcontractViolationPage(
          violation:
              'an incremental read asserting RECOVERY completeness — the '
              'delivery that used to reach prohibitedMismatchedCompleteness',
          status: PlatformSyncStatus.incremental,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
          observations: _payload,
          throughIndex: 2,
          toIndex: 2,
          nextCursor: candidate,
        ),
      );
      expect(
        mismatched.cursorAuthorization,
        isNull,
        reason:
            'the rejection lands BEFORE the cursor question is asked, which is '
            'the whole content of the exclusion. If this becomes non-null the '
            'exclusion is stale and the reasoning above needs re-reading, not '
            'the list editing.',
      );
      expect(mismatched.response, isA<ContractViolationSync>());

      final Set<SyncContractViolation> violations = matrix
          .map((Row r) => r.violation)
          .whereType<SyncContractViolation>()
          .toSet();
      expect(violations, SyncContractViolation.values.toSet());
    });

    for (final Row row in matrix) {
      test(row.name, () {
        final GameEngine engine = seeded();
        final GameState before = engine.state;
        final int? watermarkBefore =
            before.steps.checkpoint.originWatermarks[phone];

        final SyncFetch fetch = translate(row.page());

        // -- WHICH rule decided, not merely that one did ---------------------
        //
        // This assertion is why `SyncFetch.cursorAuthorization` exists. Without
        // it `Row.authorization` was decorative: an audit swapped the labels on
        // two rows — one refused for truncation, one for incompleteness — and
        // the suite stayed green, because nothing compared the label against
        // what the bridge actually decided.
        //
        // It also does the work the over-determination review could not. A
        // fixture refused for the wrong-but-still-refusing reason looks
        // identical to a correct refusal at every other assertion in this test.
        expect(
          fetch.cursorAuthorization,
          row.authorization,
          reason:
              '${row.name}: the cursor decision. A row that claims one refusal '
              'and receives another is testing a coincidence.',
        );

        // -- the cursor entering the SyncResponse ---------------------------
        expect(
          responseCursor(fetch.response),
          row.cursorSurvives ? cursor(candidate) : isNull,
          reason:
              '${row.name}: the candidate must ${row.cursorSurvives ? "reach" : "not reach"} '
              'the response. Asserted by VALUE — "not null" would pass for a '
              'cursor that arrived mangled.',
        );

        // -- fault behaviour ------------------------------------------------
        if (row.fault == null) {
          expect(
            fetch.faults,
            isEmpty,
            reason:
                '${row.name}: a clean read must raise nothing. A diagnostic '
                'that fires on ordinary traffic is one nobody reads.',
          );
        } else {
          expect(fetch.faults, contains(row.fault));
        }

        final EngineResult result = reconcile(engine, fetch);

        if (row.isRejected) {
          // -- the whole delivery, or nothing -------------------------------
          expect(
            (fetch.response as ContractViolationSync).violation,
            row.violation,
          );
          expect(result.isRejected, isTrue);
          expect(result.rejection!.code, RejectionCode.malformedSyncBatch);

          // GameState COMPLETELY unchanged.
          //
          // `identical()` is the guarantee, and it is a strong one:
          // `GameEngine.execute` returns `RejectedResult(state: before)` — the
          // very object it was holding — so nothing was rebuilt and nothing
          // could have been partly applied.
          //
          // The two assertions after it are NOT independent corroboration, and
          // an earlier version of this comment claimed they were. `signature`
          // and `grantedSlices` are pure getters over that same object, so
          // identity implies both; no mutation exists that they catch and
          // `identical()` misses. They are kept as cheap failure-message
          // detail — when identity breaks, they say what moved — not as
          // evidence.
          //
          // Worth recording, because it is a live defect elsewhere:
          // `GameState.signature` does NOT cover `checkpoint.cursor` or
          // `checkpoint.originWatermarks`. Two states differing only in the
          // durable cursor produce identical signatures. Any test that leans
          // on the signature alone for "unchanged" is weaker than it reads.
          expect(
            identical(engine.state, before),
            isTrue,
            reason:
                '${row.name}: a rejected batch must leave the very same state '
                'object. A rebuilt copy would mean events were applied.',
          );
          expect(engine.state.signature, before.signature);
          expect(engine.state.steps.grantedSlices, before.steps.grantedSlices);
          expect(
            engine.state.steps.sourceState,
            before.steps.sourceState,
            reason:
                'unlike an unavailability, a contract violation does not even '
                'move the source state',
          );
          expect(
            result.events,
            isEmpty,
            reason: 'a rejection emits nothing to apply',
          );
        } else {
          expect(result.isAccepted, isTrue);
        }

        // -- grant ------------------------------------------------------------
        expect(
          grantedBy(result),
          row.grant,
          reason: '${row.name}: steps granted',
        );

        // -- watermark --------------------------------------------------------
        final int? watermarkAfter =
            engine.state.steps.checkpoint.originWatermarks[phone];
        if (row.settles) {
          expect(
            watermarkAfter,
            greaterThan(watermarkBefore!),
            reason:
                '${row.name}: a delivery that vouches for its window must move '
                'the horizon it vouched for',
          );
        } else {
          expect(
            watermarkAfter,
            watermarkBefore,
            reason:
                '${row.name}: nothing this delivery said justifies settling a '
                'bucket. Over-settling buries a slice a later page was about '
                'to fill, and those steps are unreachable forever.',
          );
        }

        // -- the durable cursor after the commit ------------------------------
        expect(
          engine.state.steps.checkpoint.cursor,
          cursor(row.cursorSurvives ? candidate : established),
          reason:
              '${row.name}: the durable cursor. Asserted by VALUE, not as '
              '"not the replacement": a cleared cursor would restart the read '
              'from the beginning of time and would pass the weaker form.',
        );

        // -- the old cursor after an interruption -----------------------------
        //
        // The checkpoint is the last event, so replaying everything before it
        // is exactly the state a process that died after committing the ledger
        // would wake up in. The old cursor must still be authoritative there,
        // for EVERY row — including the authorized ones, which is where it
        // could go wrong.
        final GameState interrupted = commitWithoutCheckpoint(
          before,
          result.events,
        );
        expect(
          interrupted.steps.checkpoint.cursor,
          cursor(established),
          reason:
              '${row.name}: until the checkpoint event is applied the OLD '
              'cursor is still the durable one. A crash here must resume from '
              'it, or a read resumes past steps that were never credited.',
        );
        expect(
          interrupted.steps.checkpoint.cursor,
          isNot(cursor(candidate)),
          reason: '${row.name}: the candidate must never win a race',
        );
        // The two assertions above cannot fail on their own, and it took a
        // mutation to see it: only `StepCheckpointAuthorized` writes
        // `checkpoint.cursor`, and `commitWithoutCheckpoint` truncates before
        // the first one — so the applied prefix CANNOT move the cursor, for any
        // row, under any bridge behaviour. Fed `const <GameEvent>[]` the block
        // still passed. It was restating `seeded()`'s own precondition.
        //
        // This is what makes it an ordering claim: for a row that granted, the
        // ledger must ALREADY have moved at the moment the old cursor is still
        // authoritative. Checkpoint-first would show the reverse — a new cursor
        // over a ledger that had recorded nothing — and that is the shape in
        // which steps go missing without anything counting them.
        if (row.grant > 0) {
          expect(
            interrupted.steps.totalGranted,
            greaterThan(before.steps.totalGranted),
            reason:
                '${row.name}: the grant is durable BEFORE the cursor is. The '
                'ledger leads, the cursor follows.',
          );
        } else {
          expect(
            interrupted.steps.totalGranted,
            before.steps.totalGranted,
            reason:
                '${row.name}: a row that grants nothing must not move the '
                'ledger on the way to being refused',
          );
        }
      });
    }
  });
}
