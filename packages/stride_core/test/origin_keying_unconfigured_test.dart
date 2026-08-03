// The one non-retryable refusal in the reconciliation hierarchy.
//
// `ProviderUnavailableReason.originKeyingUnconfigured` means the adapter holds
// no origin-keying identity, so it cannot pseudonymize a source and refused to
// read anything at all.
//
// It was briefly folded into `serviceUnavailable`, which reported it as
// **retryable** and disguised a configuration fault as "the platform has no
// health service" — a different problem with a different fix. Retrying can
// never install an identity. Resolution is to reopen or construct the adapter
// with the existing device-bound origin-key identity, which is an application
// action, not a later attempt at the same call.
//
// Every assertion here is on an observable outcome. The point is not that a
// particular enum member exists; it is that nothing moves.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  group('origin keying unconfigured', () {
    /// A ledger with real progress, so "nothing changed" is a claim with
    /// something to lose. A refusal against an empty ledger proves very little.
    GameEngine engineWithProgress() {
      final GameEngine engine = newEngine();
      final EngineResult seeded = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 1200),
          obs(phone, 1, 800),
        ], next: 'seed-cursor'),
      );
      expect(seeded.isAccepted, isTrue);
      expect(engine.state.steps.totalGranted, 2000);
      return engine;
    }

    test('the refusal is not retryable', () {
      final StepReconciler reconciler = StepReconciler();
      final ReconciliationOutcome outcome = reconciler.reconcile(
        ledger: newEngine().state.steps,
        response: const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      expect(outcome, isA<ReconciliationRefused>());
      final ReconciliationRefused refused = outcome as ReconciliationRefused;
      expect(
        refused.retryable,
        isFalse,
        reason:
            'retrying cannot install an identity. Reporting this as retryable '
            'invites a loop against a condition looping can never clear.',
      );
      expect(refused.code, ReconciliationCode.originKeyingUnconfigured);
    });

    test('it is NOT reported as serviceUnavailable', () {
      final ReconciliationOutcome outcome = StepReconciler().reconcile(
        ledger: newEngine().state.steps,
        response: const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      final ReconciliationRefused refused = outcome as ReconciliationRefused;
      expect(
        refused.code,
        isNot(ReconciliationCode.serviceUnavailable),
        reason:
            'the service may be present and authorized. Folding this into '
            'serviceUnavailable hides a configuration fault behind a platform '
            'one, and makes it retryable.',
      );
      expect(refused.code, isNot(ReconciliationCode.transientFailure));
    });

    test('every OTHER unavailable reason remains retryable', () {
      // Guards the inverse: this change must not have made the ordinary
      // transient conditions permanent.
      for (final ProviderUnavailableReason reason
          in ProviderUnavailableReason.values) {
        if (reason == ProviderUnavailableReason.originKeyingUnconfigured) {
          continue;
        }
        final ReconciliationRefused refused =
            StepReconciler().reconcile(
                  ledger: newEngine().state.steps,
                  response: ProviderUnavailableSync(reason),
                )
                as ReconciliationRefused;
        expect(
          refused.retryable,
          isTrue,
          reason: '$reason must still be retryable',
        );
      }
    });

    test('no observations are reconciled and no grant is made', () {
      final GameEngine engine = engineWithProgress();
      final int grantedBefore = engine.state.steps.totalGranted;
      final int observedBefore = engine.state.steps.totalObserved;

      final EngineResult result = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      expect(grantedBy(result), 0);
      expect(engine.state.steps.totalGranted, grantedBefore);
      expect(engine.state.steps.totalObserved, observedBefore);
      expect(engine.state.steps.banked, grantedBefore);
    });

    test('no cursor is authorized', () {
      final GameEngine engine = engineWithProgress();
      final SyncCursor? cursorBefore = engine.state.steps.checkpoint.cursor;

      final EngineResult result = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      expect(
        authorizedCursor(result),
        isNull,
        reason:
            'a refusal must not authorize a cursor. Authorizing one here would '
            'claim progress the ledger never recorded.',
      );
      expect(
        engine.state.steps.checkpoint.cursor,
        cursorBefore,
        reason: 'the durable cursor is unchanged',
      );
    });

    test('no completeness watermark advances', () {
      final GameEngine engine = engineWithProgress();
      final SyncCheckpoint before = engine.state.steps.checkpoint;

      sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      final SyncCheckpoint after = engine.state.steps.checkpoint;
      expect(after.watermarkMillis, before.watermarkMillis);
      expect(after.originWatermarks, before.originWatermarks);
      expect(
        after.syncCount,
        before.syncCount,
        reason: 'a refused read is not a synchronization',
      );
    });

    test('GameState is otherwise unchanged — only the source state moves', () {
      final GameEngine engine = engineWithProgress();
      final GameState before = engine.state;

      sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      final GameState after = engine.state;
      expect(after.inventory.counts, before.inventory.counts);
      expect(after.skills.experienceBySkill, before.skills.experienceBySkill);
      expect(after.world.currentLocation, before.world.currentLocation);
      expect(after.equipment.bySlot, before.equipment.bySlot);
      expect(after.steps.grantedSlices, before.steps.grantedSlices);
      expect(after.steps.recovery.isActive, before.steps.recovery.isActive);
    });

    test('the source state is configuration-blocked, not service-absent', () {
      // This is the value the developer harness presents. It must be
      // distinguishable from serviceUnavailable, because the remedies differ:
      // one is "install Health Connect", the other is "reconnect the source".
      final GameEngine engine = engineWithProgress();

      sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      expect(
        engine.state.steps.sourceState,
        SourceState.originKeyingUnconfigured,
      );
      expect(
        engine.state.steps.sourceState,
        isNot(SourceState.serviceUnavailable),
      );
    });

    test('a repeated refusal does not fill the event stream', () {
      final GameEngine engine = engineWithProgress();

      final EngineResult first = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );
      final EngineResult second = sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      expect(first.isAccepted, isTrue);
      expect(second.isAccepted, isTrue);
      expect(
        second.events,
        isEmpty,
        reason:
            'the state did not change, so there is nothing to say. A '
            'non-retryable condition the app surfaces once must not emit an '
            'event per attempt.',
      );
    });

    test('recovery from the condition is possible without data loss', () {
      // The resolution path: the adapter is reopened with the identity, and the
      // next sync proceeds normally from the unchanged cursor.
      final GameEngine engine = engineWithProgress();
      final int grantedBefore = engine.state.steps.totalGranted;

      sync(
        engine,
        const ProviderUnavailableSync(
          ProviderUnavailableReason.originKeyingUnconfigured,
        ),
      );

      final EngineResult resumed = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 2, 500)], next: 'c2'),
      );

      expect(resumed.isAccepted, isTrue);
      expect(grantedBy(resumed), 500);
      expect(engine.state.steps.totalGranted, grantedBefore + 500);
      expect(authorizedCursor(resumed), cursor('c2'));
      expect(engine.state.steps.sourceState, SourceState.available);
    });
  });
}
