// Two save slots at the same generation must agree about EVERYTHING.
//
// ===========================================================================
// The defect this file exists for
// ===========================================================================
//
// `SaveRepository` refuses to guess when both slots claim the same snapshot
// generation and disagree. That refusal was gated on `GameState.signature`, a
// hand-written summary that omitted:
//
//   * `checkpoint.cursor` — the durable sync position
//   * `checkpoint.originWatermarks` — the per-origin settled horizons
//   * the CONTENTS of granted slices; it carried only their count
//
// So two slots differing in exactly those fields compared equal, the refusal
// did not fire, and control fell through to a generation sort that is a tie —
// picking an arbitrary slot.
//
// Pick the one whose cursor is further along and the next sync resumes from a
// position the chosen ledger never granted. Every step in the gap is
// unrecoverable and NOTHING COUNTS IT: no completeness assertion was violated,
// so no bucket settled early and `lateDiscardedSlices` never fires. The same
// shape as the 55,200-step defect, sitting in the corruption check instead of
// the bridge.
//
// The comparison is now `durableGameStatesEqual`, which compares the exact
// bytes a save file carries. There is no list of fields here to fall behind.
//
// ===========================================================================
// What every test below actually asserts
// ===========================================================================
//
// **Refusal, not "the signature differed".** Each case seeds two real slots at
// one generation, calls `load`, and requires `divergentSlotsAtSameGeneration`.
// Asserting on the comparison helper alone would prove the helper works while
// leaving open whether the repository consults it.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId whisperingWoods = ContentId.unchecked(
  'location.whispering_woods',
);

void main() {
  const int tiedGeneration = 4;
  const int tiedTransaction = 7;

  /// A state with a cursor, a watermark and three granted slices already in
  /// place — so "differs only in the cursor" is a claim with something to lose.
  GameState baseline() {
    final GameEngine engine = newEngine()
      ..execute(const GrantSyntheticSteps(steps: 5000, reason: 'baseline'))
      ..execute(const AllocateSteps(steps: 2000));

    final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
    final StepOriginKey watch = StepOriginKey('0f1e2d3c4b5a6978');

    return engine.state.copyWith(
      steps: engine.state.steps.copyWith(
        checkpoint: SyncCheckpoint(
          cursor: SyncCursor.ofString('cursor-alpha'),
          watermarkMillis: 1750000000000,
          originWatermarks: <StepOriginKey, int>{
            phone: 1750003600000,
            watch: 1750007200000,
          },
          syncCount: 3,
        ),
        grantedSlices: <ObservationKey, int>{
          ObservationKey(
            origin: phone,
            bucket: TimeBucket(
              startMillis: 1750000000000,
              endMillis: 1750003600000,
            ),
          ): 613,
          ObservationKey(
            origin: phone,
            bucket: TimeBucket(
              startMillis: 1750003600000,
              endMillis: 1750007200000,
            ),
          ): 291,
          ObservationKey(
            origin: watch,
            bucket: TimeBucket(
              startMillis: 1750003600000,
              endMillis: 1750007200000,
            ),
          ): 137,
        },
      ),
    );
  }

  /// Seeds both slots at one generation and loads.
  Future<LoadOutcome> loadWith(
    GameState a,
    GameState b, {
    int transactionA = tiedTransaction,
    int transactionB = tiedTransaction,
  }) async {
    final (:SaveRepository repo, :FaultingDevice device) = newRepo();
    device
      ..seed(
        'save_slot_a',
        encodeSnapshot(
          state: a,
          saveId: testSaveId,
          generation: tiedGeneration,
          lastAppliedTransaction: transactionA,
          originSaltFingerprint: null,
        ),
      )
      ..seed(
        'save_slot_b',
        encodeSnapshot(
          state: b,
          saveId: testSaveId,
          generation: tiedGeneration,
          lastAppliedTransaction: transactionB,
          originSaltFingerprint: null,
        ),
      );
    return repo.load(registry: saveRegistry);
  }

  /// Requires a fail-closed refusal, in BOTH slot orders.
  ///
  /// The order sweep is not ceremony. `verified.first` after a tied sort is
  /// whichever slot happened to be read first, so a comparison that was
  /// accidentally asymmetric — or a refusal that depended on which slot was
  /// "left" — would show up here and nowhere else.
  Future<void> expectRefusedBothWays(
    GameState a,
    GameState b,
    String what, {
    int transactionA = tiedTransaction,
    int transactionB = tiedTransaction,
  }) async {
    for (final bool swapped in <bool>[false, true]) {
      final LoadOutcome outcome = swapped
          ? await loadWith(
              b,
              a,
              transactionA: transactionB,
              transactionB: transactionA,
            )
          : await loadWith(
              a,
              b,
              transactionA: transactionA,
              transactionB: transactionB,
            );

      expect(
        outcome,
        isA<LoadRefused>(),
        reason:
            'slots differing in $what were accepted (swapped: $swapped). A '
            'winner was chosen arbitrarily and the other slot\'s progress is '
            'now unreachable.',
      );
      final LoadRefused refused = outcome as LoadRefused;
      expect(
        refused.reason,
        LoadRefusal.divergentSlotsAtSameGeneration,
        reason: '$what (swapped: $swapped)',
      );
      expect(
        refused.repairs.map((SaveRepair r) => r.diagnosis),
        contains(SaveDiagnosis.slotGenerationTie),
      );
    }
  }

  // =========================================================================
  // 1. The fields the old comparison could not see
  // =========================================================================
  //
  // These three are the defect. Every one of them passed before this commit.
  group('divergence the signature was blind to', () {
    test('the durable cursor alone', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(
        steps: a.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: SyncCursor.ofString('cursor-beta'),
            watermarkMillis: a.steps.checkpoint.watermarkMillis,
            originWatermarks: a.steps.checkpoint.originWatermarks,
            syncCount: a.steps.checkpoint.syncCount,
          ),
        ),
      );

      await expectRefusedBothWays(
        a,
        b,
        'the durable cursor and nothing else — the exact case that resumes a '
        'read past steps the chosen ledger never granted',
      );
    });

    test('one per-origin watermark alone', () async {
      final GameState a = baseline();
      final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
      final Map<StepOriginKey, int> moved = Map<StepOriginKey, int>.of(
        a.steps.checkpoint.originWatermarks,
      )..[phone] = 1750090000000;

      final GameState b = a.copyWith(
        steps: a.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: a.steps.checkpoint.cursor,
            watermarkMillis: a.steps.checkpoint.watermarkMillis,
            originWatermarks: moved,
            syncCount: a.steps.checkpoint.syncCount,
          ),
        ),
      );

      await expectRefusedBothWays(
        a,
        b,
        'one origin watermark — the further horizon buries buckets the other '
        'slot would still have accepted',
      );
    });

    test('one slice REVISED, with the slice count unchanged', () async {
      // The signature carried `slices=<count>`, so this was invisible by
      // construction: same three keys, one different grant.
      final GameState a = baseline();
      final Map<ObservationKey, int> revised = Map<ObservationKey, int>.of(
        a.steps.grantedSlices,
      );
      final ObservationKey first = revised.keys.first;
      revised[first] = revised[first]! + 1;

      final GameState b = a.copyWith(
        steps: a.steps.copyWith(grantedSlices: revised),
      );

      expect(
        b.steps.grantedSlices.length,
        a.steps.grantedSlices.length,
        reason: 'the fixture is worthless unless the COUNT is identical',
      );

      await expectRefusedBothWays(
        a,
        b,
        'the contents of one granted slice at an unchanged slice count',
      );
    });
  });

  // =========================================================================
  // 2. The rest of the durable surface
  // =========================================================================
  //
  // The old comparison did catch these. They are here so that a future change
  // to the mechanism cannot quietly narrow it back.
  group('divergence the signature already caught', () {
    test('recovery state', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(
        steps: a.steps.copyWith(
          recovery: RecoveryState(
            phase: RecoveryPhase.awaitingCommit,
            windowStartMillis: 1750000000000,
            windowEndMillis: 1750007200000,
          ),
        ),
      );
      await expectRefusedBothWays(a, b, 'recovery state');
    });

    test('source state', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(
        steps: a.steps.copyWith(sourceState: SourceState.permissionUnavailable),
      );
      await expectRefusedBothWays(a, b, 'source state');
    });

    test('granted, spent and observed totals', () async {
      final GameState a = baseline();
      for (final (String name, StepLedger ledger) in <(String, StepLedger)>[
        (
          'totalGranted',
          a.steps.copyWith(totalGranted: a.steps.totalGranted + 1),
        ),
        ('totalSpent', a.steps.copyWith(totalSpent: a.steps.totalSpent + 1)),
        (
          'totalObserved',
          a.steps.copyWith(totalObserved: a.steps.totalObserved + 1),
        ),
      ]) {
        await expectRefusedBothWays(a, a.copyWith(steps: ledger), name);
      }
    });

    test('inventory', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(
        inventory: a.inventory.adding(trainingSword, 1),
      );
      await expectRefusedBothWays(a, b, 'inventory');
    });

    test('skills', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(
        skills: a.skills.adding(ContentId.unchecked('skill.mining'), 25),
      );
      await expectRefusedBothWays(a, b, 'skill experience');
    });

    test('equipment', () async {
      final GameState a = baseline().copyWith(equipment: Equipment.empty());
      final GameState b = a.copyWith(
        equipment: Equipment.empty().equipping(
          EquipmentSlot.weapon,
          trainingSword,
        ),
      );
      await expectRefusedBothWays(a, b, 'equipment');
    });

    test('world state', () async {
      final GameState a = baseline();
      final GameState b = a.copyWith(world: a.world.unlocking(whisperingWoods));
      await expectRefusedBothWays(a, b, 'unlocked locations');
    });

    test('lastAppliedTransaction, with identical durable state', () async {
      // Transaction identity is a separate conjunct, and it must stay one: two
      // slots that agree on every byte of state but disagree about which
      // transaction produced it have not converged, they have collided.
      final GameState same = baseline();
      await expectRefusedBothWays(
        same,
        same,
        'lastAppliedTransaction',
        transactionA: 7,
        transactionB: 9,
      );
    });
  });

  // =========================================================================
  // 3. The other direction — refusing too much is also a defect
  // =========================================================================
  group('agreement is still agreement', () {
    test('byte-identical slots load without a refusal', () async {
      final GameState same = baseline();
      final LoadOutcome outcome = await loadWith(same, same);

      expect(
        outcome,
        isA<SaveLoaded>(),
        reason:
            'a comparison that refuses everything is not fail-closed, it is '
            'broken. The player cannot open their save.',
      );
    });

    test('map insertion order does not manufacture divergence', () async {
      // The real risk in moving to an encoded comparison. Two states that mean
      // the same thing, built by inserting the same entries in the opposite
      // order, must encode identically — the codec sorts, and this proves it
      // rather than trusting it.
      final GameState a = baseline();

      final Map<StepOriginKey, int> reversedMarks = <StepOriginKey, int>{
        for (final StepOriginKey k
            in a.steps.checkpoint.originWatermarks.keys.toList().reversed)
          k: a.steps.checkpoint.originWatermarks[k]!,
      };
      final Map<ObservationKey, int> reversedSlices = <ObservationKey, int>{
        for (final ObservationKey k
            in a.steps.grantedSlices.keys.toList().reversed)
          k: a.steps.grantedSlices[k]!,
      };

      final GameState b = a.copyWith(
        steps: a.steps.copyWith(
          grantedSlices: reversedSlices,
          checkpoint: SyncCheckpoint(
            cursor: a.steps.checkpoint.cursor,
            watermarkMillis: a.steps.checkpoint.watermarkMillis,
            originWatermarks: reversedMarks,
            syncCount: a.steps.checkpoint.syncCount,
          ),
        ),
      );

      expect(
        canonicalDurableGameState(b),
        canonicalDurableGameState(a),
        reason:
            'insertion order changed the encoding. Every save would then look '
            'divergent from itself and no player could load.',
      );
      expect(await loadWith(a, b), isA<SaveLoaded>());
    });
  });

  // =========================================================================
  // 4. Field sensitivity, area by area
  // =========================================================================
  group('the canonical encoding responds to every major state area', () {
    // Independent of the repository, and deliberately NOT a key count. A
    // top-level key count is satisfied by an encoder that emits the right
    // number of keys and the wrong values; what has to be true is that
    // touching each area MOVES the bytes.
    final Map<String, GameState Function(GameState)>
    mutations = <String, GameState Function(GameState)>{
      'player experience': (GameState s) => s.copyWith(
        player: s.player.copyWith(experience: s.player.experience + 10),
      ),
      'event sequence': (GameState s) =>
          s.copyWith(eventSequence: s.eventSequence + 1),
      'inventory': (GameState s) =>
          s.copyWith(inventory: s.inventory.adding(trainingSword, 1)),
      'equipment': (GameState s) => s.copyWith(
        equipment: Equipment.empty().equipping(
          EquipmentSlot.weapon,
          trainingSword,
        ),
      ),
      'skills': (GameState s) => s.copyWith(
        skills: s.skills.adding(ContentId.unchecked('skill.mining'), 25),
      ),
      'world': (GameState s) =>
          s.copyWith(world: s.world.unlocking(whisperingWoods)),
      'durable cursor': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: SyncCursor.ofString('moved'),
            watermarkMillis: s.steps.checkpoint.watermarkMillis,
            originWatermarks: s.steps.checkpoint.originWatermarks,
            syncCount: s.steps.checkpoint.syncCount,
          ),
        ),
      ),
      'origin watermarks': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: s.steps.checkpoint.cursor,
            watermarkMillis: s.steps.checkpoint.watermarkMillis,
            originWatermarks: <StepOriginKey, int>{
              ...s.steps.checkpoint.originWatermarks,
              StepOriginKey('ffffffffffffffff'): 1750100000000,
            },
            syncCount: s.steps.checkpoint.syncCount,
          ),
        ),
      ),
      'sync count': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: s.steps.checkpoint.cursor,
            watermarkMillis: s.steps.checkpoint.watermarkMillis,
            originWatermarks: s.steps.checkpoint.originWatermarks,
            syncCount: s.steps.checkpoint.syncCount + 1,
          ),
        ),
      ),
      'granted slice contents': (GameState s) {
        final Map<ObservationKey, int> revised = Map<ObservationKey, int>.of(
          s.steps.grantedSlices,
        );
        revised[revised.keys.first] = revised[revised.keys.first]! + 1;
        return s.copyWith(steps: s.steps.copyWith(grantedSlices: revised));
      },
      'totals': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(totalGranted: s.steps.totalGranted + 1),
      ),
      'recovery': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          recovery: const RecoveryState(phase: RecoveryPhase.awaitingCommit),
        ),
      ),
      'source state': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(sourceState: SourceState.permissionUnavailable),
      ),
      'late discards': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          lateDiscardedSlices: s.steps.lateDiscardedSlices + 1,
        ),
      ),
      'corrections': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          correctionsObserved: s.steps.correctionsObserved + 1,
        ),
      ),
      'unreachable gaps': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          unreachableGapEvents: s.steps.unreachableGapEvents + 1,
        ),
      ),
      'granted before watermark': (GameState s) => s.copyWith(
        steps: s.steps.copyWith(
          grantedBeforeWatermark: s.steps.grantedBeforeWatermark + 1,
        ),
      ),
    };

    for (final MapEntry<String, GameState Function(GameState)> area
        in mutations.entries) {
      test('${area.key} changes the encoding', () {
        final GameState before = baseline();
        final GameState after = area.value(before);

        expect(
          canonicalDurableGameState(after),
          isNot(canonicalDurableGameState(before)),
          reason:
              '${area.key} moved but the durable encoding did not. Two slots '
              'differing in it would compare equal and one would be discarded '
              'without a word.',
        );
        expect(durableGameStatesEqual(before, after), isFalse);
      });
    }

    test('a state equals itself, and equality is symmetric', () {
      final GameState a = baseline();
      final GameState b = baseline();
      expect(durableGameStatesEqual(a, a), isTrue);
      expect(durableGameStatesEqual(a, b), isTrue);
      expect(durableGameStatesEqual(b, a), isTrue);
    });
  });
}
