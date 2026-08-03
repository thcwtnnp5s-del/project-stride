// A completeness assertion may never vouch beyond the interval it queried.
//
// This is the rule `CompletenessScope.coversBucket` used to express while
// nothing called it. The live path is `horizonFor`, and `CompleteThrough`
// returned `throughMillis` unclamped while its sibling
// `RecoveryCompleteThrough` clamped — an asymmetry justified by nothing.
//
// The consequence is not cosmetic. An adapter whose `throughMillis` is "now"
// rather than the end of the sampled interval settles buckets it never read;
// the real data then arrives behind the horizon and is discarded as late.
// Measured end to end in `stride_health`, that lost 5,000 steps with
// `granted: 0` and `lateDiscardedSlices: 1`.
//
// **Every case here uses DIVERGENT values**: `throughMillis` and
// `intervalEndMillis` are always different, and usually `throughMillis` is the
// larger. The core's own suite could not have caught the original defect
// because its `completeThrough(index)` helper set both figures from one
// argument, making the divergence unrepresentable.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

void main() {
  const int hour = 60 * 60 * 1000;
  const int intervalStart = 1753401600000;
  const int intervalEnd = intervalStart + (4 * hour);
  // Deliberately well past the end of what was queried.
  const int overclaimed = intervalEnd + (30 * hour);

  final StepOriginKey phone = StepOriginKey('0123456789abcdef');
  final StepOriginKey watch = StepOriginKey('fedcba9876543210');

  CompletenessScope scope({OriginScope? origins}) => CompletenessScope(
    dataType: HealthDataType.steps,
    origins: origins ?? SomeOrigins(<StepOriginKey>{phone}),
    intervalStartMillis: intervalStart,
    intervalEndMillis: intervalEnd,
    queryGeneration: 7,
  );

  group('CompleteThrough clamps to the queried interval', () {
    test('an over-claimed horizon is cut back to the interval end', () {
      final CompleteThrough asserted = CompleteThrough(
        throughMillis: overclaimed,
        scope: scope(),
      );

      expect(
        asserted.horizonFor(phone),
        intervalEnd,
        reason:
            'the adapter claimed $overclaimed but only queried through '
            '$intervalEnd. Settling the difference buries every bucket in it.',
      );
      expect(asserted.horizonFor(phone), lessThan(overclaimed));
    });

    test('a horizon inside the interval is honoured exactly', () {
      // The clamp must not become a blanket "always return intervalEnd" —
      // that would over-settle in the other direction.
      final int inside = intervalStart + hour;
      final CompleteThrough asserted = CompleteThrough(
        throughMillis: inside,
        scope: scope(),
      );

      expect(asserted.horizonFor(phone), inside);
      expect(asserted.horizonFor(phone), lessThan(intervalEnd));
    });

    test('an origin outside the scope gets no horizon at all', () {
      final CompleteThrough asserted = CompleteThrough(
        throughMillis: overclaimed,
        scope: scope(),
      );

      expect(
        asserted.horizonFor(watch),
        isNull,
        reason:
            'an assertion scoped to the phone must never settle the watch. '
            'That is the LG-3 defect: a player away for a week loses the '
            'backlog their watch was holding.',
      );
    });

    test('AllOrigins is still bounded by the interval', () {
      final CompleteThrough asserted = CompleteThrough(
        throughMillis: overclaimed,
        scope: scope(origins: const AllOrigins()),
      );

      // Covering every origin is not the same as covering every instant.
      expect(asserted.horizonFor(phone), intervalEnd);
      expect(asserted.horizonFor(watch), intervalEnd);
    });
  });

  group('RecoveryCompleteThrough clamps to the queried interval', () {
    test('an over-claimed recovery horizon is cut back', () {
      final RecoveryCompleteThrough asserted = RecoveryCompleteThrough(
        throughMillis: overclaimed,
        scope: scope(),
      );

      expect(asserted.horizonFor(phone), intervalEnd);
      expect(asserted.horizonFor(phone), lessThan(overclaimed));
    });

    test('a recovery horizon inside the window is honoured exactly', () {
      final int inside = intervalStart + (2 * hour);
      final RecoveryCompleteThrough asserted = RecoveryCompleteThrough(
        throughMillis: inside,
        scope: scope(),
      );

      expect(asserted.horizonFor(phone), inside);
    });

    test('an origin outside the recovery scope gets no horizon', () {
      final RecoveryCompleteThrough asserted = RecoveryCompleteThrough(
        throughMillis: overclaimed,
        scope: scope(),
      );

      expect(asserted.horizonFor(watch), isNull);
    });
  });

  group('the two variants agree', () {
    test('both clamp identically for the same divergent input', () {
      // The original defect was exactly this disagreement. Pinning the
      // equivalence means a future change to one has to justify itself against
      // the other rather than drifting silently.
      final CompletenessScope s = scope();
      for (final int through in <int>[
        intervalStart - hour,
        intervalStart,
        intervalStart + hour,
        intervalEnd - 1,
        intervalEnd,
        intervalEnd + 1,
        overclaimed,
      ]) {
        final int? normal = CompleteThrough(
          throughMillis: through,
          scope: s,
        ).horizonFor(phone);
        final int? recovery = RecoveryCompleteThrough(
          throughMillis: through,
          scope: s,
        ).horizonFor(phone);

        expect(
          normal,
          recovery,
          reason:
              'CompleteThrough and RecoveryCompleteThrough disagreed at '
              'throughMillis=$through. One clamped and the other did not, '
              'which is the defect this file exists for.',
        );
        expect(
          normal,
          lessThanOrEqualTo(intervalEnd),
          reason: 'no horizon may exceed the queried interval end',
        );
      }
    });
  });

  group('PartialDelivery settles nothing, whatever the scope', () {
    test('a partial delivery has no horizon for any origin', () {
      const PartialDelivery partial = PartialDelivery();
      expect(partial.horizonFor(phone), isNull);
      expect(partial.horizonFor(watch), isNull);
    });
  });
}
