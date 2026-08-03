// The scriptable source, which is the harness the reconciliation scenarios run
// against. If it cannot express a case, that case is untestable without a
// device — which is exactly what went wrong with the model it replaces.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

const int hour = 60 * 60 * 1000;
const int t0 = 1753401600000;
const String phone = '00112233aabbccdd';
const String watch = 'ffeeddcc99887766';

void main() {
  test('a script is served in order and then goes quiet', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[
        MockStepSource.observed(
          phone,
          startMillis: t0,
          endMillis: t0 + hour,
          steps: 1200,
        ),
        MockStepSource.observed(
          phone,
          startMillis: t0 + hour,
          endMillis: t0 + 2 * hour,
          steps: 800,
        ),
      ],
    );

    expect(
      ((await source.fetchSteps(const SyncRequest())).response
              as IncrementalSync)
          .observations
          .single
          .steps,
      1200,
    );
    expect(
      ((await source.fetchSteps(const SyncRequest())).response
              as IncrementalSync)
          .observations
          .single
          .steps,
      800,
    );

    // An exhausted script yields "nothing new" rather than throwing. A test
    // that fetches more often than it scripted is usually asserting
    // idempotence, and that should read as a no-op.
    expect(
      (await source.fetchSteps(const SyncRequest())).response,
      isA<NoChangeSync>(),
    );
    expect(source.fetchCount, 2);
    expect(source.requestsSeen, hasLength(3));
  });

  test('requests are recorded, so cursor discipline can be asserted', () async {
    final MockStepSource source = MockStepSource();

    await source.fetchSteps(const SyncRequest());
    await source.fetchSteps(SyncRequest(cursor: SyncCursor.ofString('a')));

    // The first read carries no cursor; the second carries the one the caller
    // made durable only after committing. A test that wants to prove the caller
    // did not persist early asserts on this list.
    expect(source.requestsSeen.first.cursor, isNull);
    expect(source.requestsSeen.last.cursor, SyncCursor.ofString('a'));
  });

  test('a partial page settles nothing and offers a continuation', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[
        MockStepSource.partialPage(
          phone,
          startMillis: t0,
          endMillis: t0 + hour,
          steps: 55200,
        ),
      ],
    );

    final SyncFetch fetch = await source.fetchSteps(const SyncRequest());

    expect(fetch.isFinalPage, isFalse);
    expect(fetch.continuation, isNotNull);
    // The shape that destroyed 55,200 steps when the core inferred completeness
    // from the newest bucket it had been handed.
    expect(
      (fetch.response as IncrementalSync).completeness,
      isA<PartialDelivery>(),
    );
  });

  test(
    'a completeness assertion is scoped to the origin that made it',
    () async {
      final MockStepSource source = MockStepSource(
        script: <SyncFetch>[
          MockStepSource.observed(
            phone,
            startMillis: t0,
            endMillis: t0 + hour,
            steps: 1200,
            completeThroughMillis: t0 + hour,
          ),
        ],
      );

      final IncrementalSync sync =
          (await source.fetchSteps(const SyncRequest())).response
              as IncrementalSync;
      final CompleteThrough asserted = sync.completeness as CompleteThrough;

      // "Settled for the phone, still open for the watch" is the case a single
      // global watermark could not express, and the case that discarded a
      // returning player's backlog.
      expect(asserted.horizonFor(StepOriginKey(phone)), t0 + hour);
      expect(asserted.horizonFor(StepOriginKey(watch)), isNull);
    },
  );

  test('a deletion is a restatement of zero', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[
        MockStepSource.deleted(phone, startMillis: t0, endMillis: t0 + hour),
      ],
    );

    final IncrementalSync sync =
        (await source.fetchSteps(const SyncRequest())).response
            as IncrementalSync;
    expect(sync.observations.single.steps, 0);
  });

  test('recovery carries authoritative per-origin content', () async {
    final MockStepSource source = MockStepSource(
      script: <SyncFetch>[
        MockStepSource.invalidated(
          windowStartMillis: t0,
          windowEndMillis: t0 + 24 * hour,
          observations: <StepObservation>[
            StepObservation.of(
              origin: StepOriginKey(phone),
              startMillis: t0,
              endMillis: t0 + hour,
              steps: 4200,
            ),
            StepObservation.of(
              origin: StepOriginKey(watch),
              startMillis: t0,
              endMillis: t0 + hour,
              steps: 300,
            ),
          ],
          truncated: true,
        ),
      ],
    );

    final CursorInvalidatedSync sync =
        (await source.fetchSteps(const SyncRequest())).response
            as CursorInvalidatedSync;

    expect(sync.observations, hasLength(2));
    expect(sync.window.truncated, isTrue);
    // No replacement cursor until recovery has been committed to the ledger.
    expect(sync.nextCursor, isNull);
  });

  test('absence and denial are states, not errors', () async {
    final MockStepSource absent = MockStepSource(
      available: false,
      authorization: HealthAuthorization.denied,
    );

    final HealthAvailability availability = await absent.availability();
    expect(availability.available, isFalse);
    expect(availability.reason, ProviderUnavailableReason.serviceUnavailable);
    expect(await absent.requestAuthorization(), HealthAuthorization.denied);

    // And the game stays playable: nothing here throws.
    expect(
      (await MockStepSource(
        script: <SyncFetch>[
          MockStepSource.unavailable(
            ProviderUnavailableReason.permissionUnavailable,
          ),
        ],
      ).fetchSteps(const SyncRequest())).response,
      isA<ProviderUnavailableSync>(),
    );
  });
}
