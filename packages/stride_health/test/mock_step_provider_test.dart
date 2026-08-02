// The mock provider is the instrument the thirteen reconciliation scenarios
// are measured with, so it gets tested before it is trusted.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  group('MockStepProvider', () {
    test('serves scripted results in order', () async {
      final MockStepProvider provider = MockStepProvider(
        script: <StepFetchResult>[
          MockStepProvider.delta(1200),
          MockStepProvider.delta(800),
        ],
      );

      expect((await provider.fetchNewSteps()).newSteps, 1200);
      expect((await provider.fetchNewSteps()).newSteps, 800);
      expect(provider.fetchCount, 2);
      expect(provider.isExhausted, isTrue);
    });

    test(
      'an exhausted script yields nothing new rather than throwing',
      () async {
        final MockStepProvider provider = MockStepProvider();
        final StepFetchResult result = await provider.fetchNewSteps();

        // Tests that fetch more often than they scripted are usually asserting
        // idempotence. That should read as a no-op, not an error.
        expect(result.newSteps, 0);
        expect(result.status, CursorStatus.valid);
      },
    );

    test('records the cursors and watermarks it was handed', () async {
      final MockStepProvider provider = MockStepProvider(
        script: <StepFetchResult>[MockStepProvider.delta(10, cursor: 'a')],
      );
      final DateTime watermark = DateTime.utc(2026, 7, 25);

      final StepFetchResult first = await provider.fetchNewSteps();
      await provider.fetchNewSteps(cursor: first.cursor, watermark: watermark);

      // Lets a scenario assert the caller persisted a cursor only after
      // committing its batch — persisting early makes an interrupted sync
      // unrecoverable.
      expect(provider.cursorsSeen.first, isNull);
      expect(provider.cursorsSeen.last!.bytes, first.cursor!.bytes);
      expect(provider.watermarksSeen.last, watermark);
    });

    test('a deletion reports removal without offering a delta', () async {
      final MockStepProvider provider = MockStepProvider(
        script: <StepFetchResult>[MockStepProvider.deletion(300)],
      );
      final StepFetchResult result = await provider.fetchNewSteps();

      expect(result.deletedSteps, 300);
      expect(result.newSteps, 0);
    });

    test(
      'an invalidated cursor carries a rescan and no replacement cursor',
      () async {
        // Scenario 13. Health Connect can expire a changes token.
        final MockStepProvider provider = MockStepProvider(
          script: <StepFetchResult>[
            MockStepProvider.invalidated(
              windowStart: DateTime.utc(2026, 7, 25),
              windowEnd: DateTime.utc(2026, 8, 1),
              windowTotal: 42000,
            ),
          ],
        );

        final StepFetchResult result = await provider.fetchNewSteps();

        expect(result.status, CursorStatus.invalidated);
        expect(result.rescan!.windowTotal, 42000);
        expect(result.rescan!.truncated, isFalse);

        // newSteps must be zero on this path. The delta stream is broken, and
        // treating a rescan total as a delta is exactly the double-count that
        // scenario 13 exists to prevent.
        expect(result.newSteps, 0);

        // No replacement cursor until recovery has been committed.
        expect(result.cursor, isNull);
      },
    );

    test('a truncated rescan is flagged', () async {
      final MockStepProvider provider = MockStepProvider(
        script: <StepFetchResult>[
          MockStepProvider.invalidated(
            windowStart: DateTime.utc(2026, 7, 2),
            windowEnd: DateTime.utc(2026, 8, 1),
            windowTotal: 250000,
            truncated: true,
          ),
        ],
      );

      final StepFetchResult result = await provider.fetchNewSteps();

      // Steps in the unreachable gap are recorded, never granted. Inventing
      // progress is worse than missing it.
      expect(result.rescan!.truncated, isTrue);
    });

    test('reports denial and unavailability without throwing', () async {
      final MockStepProvider denied = MockStepProvider(
        authorization: StepAuthorization.denied,
        available: false,
      );

      expect(await denied.requestAuthorization(), StepAuthorization.denied);
      expect(await denied.isAvailable(), isFalse);
    });
  });
}
