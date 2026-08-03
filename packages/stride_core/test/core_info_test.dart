// Proves the package builds, links, and is testable with no Flutter, no
// emulator, and no simulator — the whole point of the Flutter migration.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

void main() {
  group('StrideCore module', () {
    test('exposes a version', () {
      expect(StrideCore.version, isNotEmpty);
    });
  });

  group('recovery contract', () {
    test('the rescan window is bounded', () {
      // After cursor loss, an unbounded rescan would either double-count or
      // invent progress. The bound is what makes recovery safe.
      const int day = 24 * 60 * 60 * 1000;
      expect(RescanWindow.maxWindowMillis, greaterThan(0));
      expect(RescanWindow.maxWindowMillis, lessThanOrEqualTo(90 * day));
    });

    test('a truncated rescan is flagged, not silently accepted', () {
      const RescanWindow window = RescanWindow(
        startMillis: 1751328000000,
        endMillis: 1754006400000,
        truncated: true,
      );
      expect(window.truncated, isTrue);
      expect(window.endMillis, greaterThan(window.startMillis));
    });

    test('an invalidated cursor carries the window and the authority', () {
      // The observations on this path are the AUTHORITATIVE contents of the
      // window, per origin and per bucket — not a delta. Treating them as a
      // delta is exactly the double-count scenario 13 exists to prevent, and
      // the type is what makes that mistake unavailable: there is no flat
      // total on this response to misread.
      final CursorInvalidatedSync response = CursorInvalidatedSync(
        window: const RescanWindow(
          startMillis: 1753401600000,
          endMillis: 1754006400000,
          truncated: false,
        ),
        observations: <StepObservation>[
          StepObservation.of(
            origin: StepOriginKey('00112233aabbccdd'),
            startMillis: 1753401600000,
            endMillis: 1753405200000,
            steps: 42000,
          ),
        ],
      );

      expect(response.kind, 'cursor_invalidated');
      expect(response.window.truncated, isFalse);
      expect(response.observations.single.steps, 42000);
      // No replacement cursor until recovery has been committed to the ledger.
      expect(response.nextCursor, isNull);
      // And nothing may be settled until the adapter says the read is drained.
      expect(response.completeness, isA<PartialDelivery>());
    });
  });
}
