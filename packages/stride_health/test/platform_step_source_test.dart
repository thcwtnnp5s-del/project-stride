// The bridge's translation rules.
//
// Every case here is fabricated: no channel, no device, no health service, no
// wall clock. That is the property that made the thirteen reconciliation
// scenarios worth having, and it is why the bridge's judgement calls live in a
// static function rather than behind an await.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

/// The gateway is stateless now: keying happens natively, and this only
/// validates and decodes. There is no salt on this side of the boundary.
const OriginGateway gateway = OriginGateway();

const int hour = 60 * 60 * 1000;
const int t0 = 1753401600000;

/// A well-formed eight-byte origin key, as native would have produced it.
Uint8List key(int seed) =>
    Uint8List.fromList(<int>[seed, 1, 2, 3, 4, 5, 6, seed]);

PlatformStepObservation observation({
  Uint8List? originKey,
  int start = t0,
  int? end,
  int steps = 4200,
}) => PlatformStepObservation(
  originKey: originKey ?? key(0xAB),
  bucket: PlatformTimeBucket(
    startMillis: start,
    endMillis: end ?? start + hour,
  ),
  steps: steps,
);

PlatformCompleteness completeness({
  PlatformCompletenessKind kind = PlatformCompletenessKind.partial,
  PlatformOriginScopeKind scopeKind = PlatformOriginScopeKind.someOrigins,
  List<Uint8List>? scoped,
  int through = t0 + hour,
}) => PlatformCompleteness(
  kind: kind,
  dataType: PlatformHealthDataType.steps,
  scope: PlatformOriginScope(
    kind: scopeKind,
    originKeys: scoped ?? <Uint8List>[key(0xAB)],
  ),
  intervalStartMillis: t0,
  intervalEndMillis: t0 + hour,
  queryGeneration: 3,
  throughMillis: through,
);

PlatformSyncPage page({
  PlatformSyncStatus status = PlatformSyncStatus.incremental,
  List<PlatformStepObservation>? observations,
  PlatformCompleteness? complete,
  bool isFinalPage = true,
  Uint8List? continuation,
  Uint8List? nextCursor,
  PlatformRescanWindow? rescan,
  PlatformUnavailableReason? unavailableReason,
}) => PlatformSyncPage(
  status: status,
  observations: observations ?? <PlatformStepObservation>[observation()],
  completeness: complete ?? completeness(),
  pagination: PlatformPagination(
    pageIndex: 0,
    isFinalPage: isFinalPage,
    continuation: continuation,
  ),
  nextCursor: nextCursor,
  rescan: rescan,
  unavailableReason: unavailableReason,
);

void main() {
  group('the ordinary case', () {
    test('observations become origin-attributed core observations', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(nextCursor: Uint8List.fromList(<int>[1, 2])),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      expect(fetch.isClean, isTrue);
      expect(sync.observations.single.steps, 4200);
      expect(sync.nextCursor, isNotNull);
      // Attribution survived, and it survived as a pseudonym.
      expect(sync.observations.single.key.origin.value, hasLength(16));
    });

    test('an empty page with noChange stays noChange', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.noChange,
          observations: <PlatformStepObservation>[],
        ),
        gateway,
      );

      expect(fetch.response, isA<NoChangeSync>());
      expect(fetch.isClean, isTrue);
    });

    test('a deletion is an absolute zero, not a separate figure', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(observations: <PlatformStepObservation>[observation(steps: 0)]),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      expect(sync.observations.single.steps, 0);
      expect(fetch.isClean, isTrue);
    });
  });

  group('completeness is never taken on trust', () {
    test('completeThrough on a non-final page is downgraded', () {
      // The 55,200-step defect in contract form. Page one of nine used to look
      // exactly like page nine of nine.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
          ),
          isFinalPage: false,
          continuation: Uint8List.fromList(<int>[7]),
        ),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      expect(sync.completeness, isA<PartialDelivery>());
      expect(fetch.faults, contains(SyncFault.completenessOnNonFinalPage));
      // The observations are kept. Only the settling is refused.
      expect(sync.observations, hasLength(1));
      expect(fetch.isFinalPage, isFalse);
      expect(fetch.continuation, isNotNull);
    });

    test('completeThrough on a final page survives with its scope', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
          ),
        ),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      final CompleteThrough asserted = sync.completeness as CompleteThrough;
      expect(asserted.throughMillis, t0 + hour);
      expect(asserted.scope.queryGeneration, 3);
      expect(asserted.scope.origins, isA<SomeOrigins>());
      expect(fetch.isClean, isTrue);
    });

    test('a scope claiming allOrigins while naming some is narrowed', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
            scopeKind: PlatformOriginScopeKind.allOrigins,
            scoped: <Uint8List>[key(0xAB)],
          ),
        ),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      final CompleteThrough asserted = sync.completeness as CompleteThrough;
      // Narrowed, not widened. Under-settling costs a little ledger growth;
      // over-settling costs a grant permanently.
      expect(asserted.scope.origins, isA<SomeOrigins>());
      expect(fetch.faults, contains(SyncFault.contradictoryOriginScope));
    });

    test('a genuine allOrigins scope with no names is honoured', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
            scopeKind: PlatformOriginScopeKind.allOrigins,
            scoped: const <Uint8List>[],
          ),
        ),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      expect(
        (sync.completeness as CompleteThrough).scope.origins,
        isA<AllOrigins>(),
      );
      expect(fetch.isClean, isTrue);
    });
  });

  group('malformed observations refuse the whole page', () {
    test('a sub-hour bucket is refused', () {
      // A minute-resolution read is a minute-by-minute record of when the
      // player moved, kept for a week. Nobody decided to build that.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          observations: <PlatformStepObservation>[observation(end: t0 + 60000)],
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
          ),
        ),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.malformedObservation));
    });

    test('an inverted bucket is refused', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          observations: <PlatformStepObservation>[
            observation(start: t0 + hour, end: t0),
          ],
        ),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.malformedObservation));
    });

    test('a negative count is refused', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(observations: <PlatformStepObservation>[observation(steps: -1)]),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.malformedObservation));
    });

    test('an origin key of the wrong length is refused', () {
      // The length check is the only thing standing between a truncated raw
      // identifier and the ledger. Eight bytes of "Rob's iP" would pass; nine
      // bytes of anything must not, because a variable-length field is a field
      // a string can travel in.
      for (final int length in <int>[1, 4, 7, 9, 16, 32]) {
        final SyncFetch fetch = PlatformStepSource.translate(
          page(
            observations: <PlatformStepObservation>[
              observation(originKey: Uint8List(length)),
            ],
          ),
          gateway,
        );

        expect(
          fetch.response,
          isA<ProviderUnavailableSync>(),
          reason: 'a $length-byte origin key must refuse the page',
        );
        expect(fetch.faults, contains(SyncFault.malformedObservation));
      }
    });

    test('a zero-length origin key is the unknown origin, not a fault', () {
      // Zero bytes is the wire's "no source reported". It is deliberately not
      // eight zero bytes, which would be an ordinary key the hash could
      // produce.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          observations: <PlatformStepObservation>[
            observation(originKey: Uint8List(0)),
          ],
        ),
        gateway,
      );

      final IncrementalSync sync = fetch.response as IncrementalSync;
      expect(sync.observations.single.key.origin, StepOriginKey.unknown);
      expect(fetch.isClean, isTrue);
    });

    test('an undecodable origin in a completeness scope refuses the page', () {
      // A scope vouching for a source nobody can identify is not a narrower
      // assertion, it is an unusable one, and settling against it would settle
      // the wrong buckets.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
            scoped: <Uint8List>[Uint8List(3)],
          ),
        ),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.malformedOriginKey));
    });

    test('one bad slice refuses the page rather than dropping the slice', () {
      // Dropping the slice while honouring the page's completeness assertion
      // would settle the bucket the drop just emptied, and those steps would
      // never be reachable again.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          observations: <PlatformStepObservation>[
            observation(),
            observation(start: t0 + hour, end: t0 + hour + 1000),
            observation(start: t0 + 2 * hour),
          ],
          complete: completeness(
            kind: PlatformCompletenessKind.completeThrough,
          ),
        ),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
    });
  });

  group('recovery', () {
    test('an invalidated cursor carries the window and the authority', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.cursorInvalidated,
          rescan: PlatformRescanWindow(
            startMillis: t0,
            endMillis: t0 + 24 * hour,
            truncated: false,
          ),
          complete: completeness(
            kind: PlatformCompletenessKind.recoveryCompleteThrough,
          ),
        ),
        gateway,
      );

      final CursorInvalidatedSync sync =
          fetch.response as CursorInvalidatedSync;
      expect(sync.window.truncated, isFalse);
      expect(sync.observations, hasLength(1));
      expect(sync.completeness, isA<RecoveryCompleteThrough>());
      expect(fetch.isClean, isTrue);
    });

    test('a truncated rescan settles nothing', () {
      // A recovery's authority stops at the window it could actually reach.
      // Settling on a truncated one buries whatever fell outside it.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.cursorInvalidated,
          rescan: PlatformRescanWindow(
            startMillis: t0,
            endMillis: t0 + 24 * hour,
            truncated: true,
          ),
          complete: completeness(
            kind: PlatformCompletenessKind.recoveryCompleteThrough,
          ),
        ),
        gateway,
      );

      final CursorInvalidatedSync sync =
          fetch.response as CursorInvalidatedSync;
      expect(sync.completeness, isA<PartialDelivery>());
    });

    test('an invalidated cursor with no window is refused outright', () {
      // Without the window there is no authoritative figure and no safe move:
      // granting is the double-count, discarding is the lost grant.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(status: PlatformSyncStatus.cursorInvalidated),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.invalidatedWithoutRescan));
    });
  });

  group('unavailability', () {
    test('a named reason survives', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.unavailable,
          observations: <PlatformStepObservation>[],
          unavailableReason: PlatformUnavailableReason.permissionUnavailable,
        ),
        gateway,
      );

      expect(
        (fetch.response as ProviderUnavailableSync).reason,
        ProviderUnavailableReason.permissionUnavailable,
      );
      expect(fetch.isClean, isTrue);
    });

    test('a missing reason becomes transient and is recorded as a fault', () {
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.unavailable,
          observations: <PlatformStepObservation>[],
        ),
        gateway,
      );

      expect(
        (fetch.response as ProviderUnavailableSync).reason,
        ProviderUnavailableReason.transientFailure,
      );
      expect(fetch.faults, contains(SyncFault.unavailableWithoutReason));
    });

    test('unconfigured keying is reported as its own fault, not a blip', () {
      // Retrying will not install an identity. A reconciler that treated this
      // as transient would retry forever, and an adapter that read anyway
      // would key every origin under nothing and re-grant the retention
      // window.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.unavailable,
          observations: <PlatformStepObservation>[],
          unavailableReason: PlatformUnavailableReason.originKeyingUnconfigured,
        ),
        gateway,
      );

      expect(fetch.faults, contains(SyncFault.originKeyingUnconfigured));
      expect(
        (fetch.response as ProviderUnavailableSync).reason,
        isNot(ProviderUnavailableReason.transientFailure),
      );
    });

    test('a cursor offered while unavailable is dropped', () {
      // Persisting a cursor the adapter cannot stand behind would make the next
      // sync claim progress the ledger never recorded.
      final SyncFetch fetch = PlatformStepSource.translate(
        page(
          status: PlatformSyncStatus.unavailable,
          observations: <PlatformStepObservation>[],
          unavailableReason: PlatformUnavailableReason.serviceMissing,
          nextCursor: Uint8List.fromList(<int>[9]),
        ),
        gateway,
      );

      expect(fetch.response, isA<ProviderUnavailableSync>());
      expect(fetch.faults, contains(SyncFault.cursorOfferedWhenProhibited));
    });
  });

  test('observations alongside noChange are kept, not discarded', () {
    // Real steps are never thrown away over a status mismatch.
    final SyncFetch fetch = PlatformStepSource.translate(
      page(status: PlatformSyncStatus.noChange),
      gateway,
    );

    expect(fetch.response, isA<IncrementalSync>());
    expect((fetch.response as IncrementalSync).observations, hasLength(1));
    expect(fetch.faults, contains(SyncFault.observationsOnNoChange));
  });
}
