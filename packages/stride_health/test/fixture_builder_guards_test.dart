// The semantic builders refuse to build a fixture that lies about itself.
//
// This file exists because that refusal was, until now, the only unguarded
// thing in the migration that produced it. `ppage` and `pcomplete` were deleted
// and ~99 call sites moved onto builders whose whole value is that
// `pincrementalPage` CANNOT be handed a recovery completeness — and an audit
// found that deleting all three checks left the suite green at 127 tests. The
// premise everything else rests on was resting on nothing.
//
// Why the builders refuse rather than accept-and-annotate: a fixture that
// declares a delivery kind and a contradictory completeness is not a hard case,
// it is a page no adapter may ever send. Ten such fixtures existed before the
// migration, every one of them declaring a completeness its test then asserted
// the opposite of, and they passed for years because the bridge handed cursors
// over regardless. The type that can express the contradiction is how the
// contradiction survives review.
//
// The escape hatch is `pcontractViolationPage`, which builds exactly those
// pages — and requires the author to name, in prose, the contract being broken.

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_health/src/messages.g.dart';

import 'adapter_ledger_support.dart';

void main() {
  group('pincrementalPage', () {
    test('refuses a RECOVERY completeness', () {
      expect(
        () => pincrementalPage(
          isFinalPage: true,
          completeness: PlatformCompletenessKind.recoveryCompleteThrough,
        ),
        throwsArgumentError,
        reason:
            'an incremental read has no rescan window, so a recovery '
            'completeness assertion has no bound to be read against. It is '
            'SyncContractViolation.mismatchedCompleteness, and the fixture has '
            'to say so.',
      );
    });

    test('accepts the two completenesses an incremental read can hold', () {
      // The refusal must be a rule, not a blanket. A builder that rejected
      // everything would pass the test above while making the whole set
      // useless.
      for (final PlatformCompletenessKind kind in <PlatformCompletenessKind>[
        PlatformCompletenessKind.partial,
        PlatformCompletenessKind.completeThrough,
      ]) {
        expect(
          () => pincrementalPage(isFinalPage: true, completeness: kind),
          returnsNormally,
          reason: '$kind is a legal incremental declaration',
        );
      }
    });
  });

  group('precoveryPage', () {
    test('refuses an ORDINARY completeThrough', () {
      expect(
        () => precoveryPage(
          isFinalPage: true,
          isTruncated: false,
          completeness: PlatformCompletenessKind.completeThrough,
        ),
        throwsArgumentError,
        reason:
            'a recovery may only vouch for the window it could reach. '
            'Ordinary completeThrough is unbounded, so adopting it settles '
            'past the rescan — and the steps behind that horizon are '
            'unreachable forever.',
      );
    });

    test('accepts the two completenesses a recovery can hold', () {
      for (final PlatformCompletenessKind kind in <PlatformCompletenessKind>[
        PlatformCompletenessKind.partial,
        PlatformCompletenessKind.recoveryCompleteThrough,
      ]) {
        expect(
          () => precoveryPage(
            isFinalPage: true,
            isTruncated: false,
            completeness: kind,
          ),
          returnsNormally,
          reason: '$kind is a legal recovery declaration',
        );
      }
    });
  });

  group('pcontractViolationPage', () {
    test('refuses an unnamed violation', () {
      // The prose is the point. A builder that let an author write
      // `violation: ''` would be `ppage` with extra steps: the deleted builder
      // permitted every illegal combination silently, and the reason the
      // replacement is safe to keep permitting them is that each use has to
      // state which contract it is breaking and why the test needs it broken.
      for (final String blank in <String>['', '   ', '\t\n ']) {
        expect(
          () => pcontractViolationPage(
            violation: blank,
            status: PlatformSyncStatus.noChange,
            completeness: PlatformCompletenessKind.partial,
          ),
          throwsArgumentError,
          reason: 'whitespace is not a name: ${blank.codeUnits}',
        );
      }
    });

    test('accepts a named violation', () {
      expect(
        () => pcontractViolationPage(
          violation: 'a no-change page carrying observations',
          status: PlatformSyncStatus.noChange,
          completeness: PlatformCompletenessKind.partial,
          observations: <PlatformStepObservation>[pobs(phoneBytes, 1, 900)],
        ),
        returnsNormally,
      );
    });
  });
}
