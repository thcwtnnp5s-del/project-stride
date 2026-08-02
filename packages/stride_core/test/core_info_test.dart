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

  group('StepProvider contract', () {
    test('rescan window is bounded', () {
      // After cursor loss, an unbounded rescan would either double-count or
      // invent progress. The bound is what makes recovery safe.
      expect(StepRescan.maxRescanWindow.inDays, greaterThan(0));
      expect(StepRescan.maxRescanWindow.inDays, lessThanOrEqualTo(90));
    });

    test('a truncated rescan is flagged, not silently accepted', () {
      final StepRescan rescan = StepRescan(
        windowStart: DateTime.utc(2026, 7, 1),
        windowEnd: DateTime.utc(2026, 8, 1),
        windowTotal: 120000,
        truncated: true,
      );
      expect(rescan.truncated, isTrue);
      expect(rescan.windowTotal, greaterThan(0));
    });

    test('an invalidated fetch carries a rescan', () {
      final StepFetchResult result = StepFetchResult(
        status: CursorStatus.invalidated,
        newSteps: 0,
        deletedSteps: 0,
        cursor: null,
        rescan: StepRescan(
          windowStart: DateTime.utc(2026, 7, 25),
          windowEnd: DateTime.utc(2026, 8, 1),
          windowTotal: 42000,
          truncated: false,
        ),
      );

      expect(result.status, CursorStatus.invalidated);
      expect(result.rescan, isNotNull);
      // newSteps is meaningless on this path — the delta stream is broken, and
      // treating it as a delta is exactly the double-count scenario 13 exists
      // to prevent.
      expect(result.newSteps, 0);
    });
  });
}
