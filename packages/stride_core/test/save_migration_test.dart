// The migration boundary, pinned to a frozen artifact.
//
// ## The fixture
//
// `test/fixtures/save/v1_baseline.save` was generated **once**, from a real
// [GameState] built by the engine, and is frozen forever. It was produced by:
//
// ```text
// GameEngine.newGame(registry: production)
// sync  incremental([phone hour 0 = 613], nextCursor 'cursor-1')
// sync  incremental([phone hour 1 = 291, watch hour 1 = 137], 'cursor-2')
// spend AllocateSteps(400)
// equip EquipItem(item.training_sword)
// encodeSnapshot(saveId 'v1-baseline-0001', generation 7, lastApplied 4)
// ```
//
// Those numbers are distinct and non-summing so a drop, a duplicate, or an
// off-by-one each move a different one.
//
// ## Regeneration policy — read before touching this file
//
// **The fixture is never regenerated. Not when a field is added to
// [GameState]. Not when the encoder changes. Not to make this suite green.**
//
// It is the only thing in the repository that represents a save written by a
// build that no longer exists, which is the only thing a player's phone
// actually contains. Regenerating it deletes the evidence and replaces it with
// a restatement of whatever the code does today — after which every assertion
// here is a tautology and the first real migration ships untested.
//
// When `StateVersion.current` becomes 2:
//
// 1. Add a `_V2StateDecoder` to `StateCodecs._decoders`. Do not touch
//    `V1StateDecoder`, and do not touch this file's fixture.
// 2. Test A (signature) and Test C/D (refusals) stay as they are: v1 must keep
//    decoding into whatever the current `GameState` is.
// 3. Test B becomes **decode-only**. `encode(decode(v1))` cannot be
//    byte-identical to a v1 artifact once the encoder emits v2 — there is one
//    encoder and it only ever writes the current version. Replace the byte
//    comparison with an assertion on the migrated state's signature, and add a
//    *new* frozen fixture `v2_baseline.save` that carries the round-trip
//    property forward for v2.
// 4. Never chain v1→v2→v3. `StateCodecs` is a fan-in of direct decoders; see
//    the note on `StateDecoder`.
//
// `dart:io` is used here and only here in this file's own directory. Only
// `lib/` is guarded by `Scripts/check-core-purity.sh` and
// `core_purity_test.dart`; test files read from disk freely, which is why the
// fixture can be a real file rather than a base64 blob in a string literal.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';
import 'save_support.dart';

/// The exact durable state of the frozen fixture.
///
/// A literal, not a computation. Deriving it from the fixture would make this
/// assert that decoding is self-consistent rather than that it is *correct*.
///
/// ## Why this literal was replaced, and why that is not fixture-fitting
///
/// It used to be the `GameState.signature` string. That property is gone — it
/// omitted the durable cursor and the per-origin watermarks, and a save-slot
/// divergence check was relying on it (see `durable_state.dart`). The frozen
/// value had to move to the replacement encoding with it.
///
/// The rule this file states — *fix the decoder, never the fixture and never
/// this literal* — is intact, because the new literal was not taken on trust
/// from a passing run. Every field of the old signature was checked to survive
/// into the new one with the same value:
///
/// | old | new | value |
/// |---|---|---|
/// | `v1` | `stateVersion` | 1 |
/// | `profile=` | `profileId` | `profile.production` |
/// | `seq=` | `eventSequence` | 10 |
/// | `lvl=`, `xp=` | `player` | 1, 0 |
/// | `obs=` | `totalObserved` | 1041 |
/// | `granted=` | `totalGranted` | 1041 |
/// | `spent=` | `totalSpent` | 400 |
/// | `banked=641` | *derived* | 1041 − 400 = 641 |
/// | `pre=` | `grantedBeforeWatermark` | 0 |
/// | `slices=3` | `grantedSlices` | 3, now enumerated |
/// | `sync=` | `checkpoint.syncCount` | 2 |
/// | `wm=null` | `checkpoint.watermarkMillis` | null |
/// | `recovery=` | `recovery.phase` | idle |
/// | `source=` | `sourceState` | available |
/// | `corrections=`, `gaps=`, `late=` | same names | 0, 0, 0 |
/// | `at=`, `open=` | `world` | havens_rest |
/// | `inv=`, `eq=`, `skills=` | same names | unchanged |
///
/// It is a **strict superset**. Three things the old literal could not pin are
/// now pinned: `contentPackVersion`, the three granted slices by value rather
/// than by count, and — the reason any of this happened — the durable cursor,
/// `Y3Vyc29yLTI=`, which is base64 for `cursor-2`.
const String expectedV1Signature =
    '{"contentPackVersion":1,'
    '"equipment":{"weapon":"item.training_sword"},'
    '"eventSequence":10,'
    '"inventory":[{"id":"item.training_axe","n":1},'
    '{"id":"item.training_pickaxe","n":1},'
    '{"id":"item.training_sword","n":1},'
    '{"id":"item.traveler_tunic","n":1}],'
    '"player":{"experience":0,"level":1},'
    '"profileId":"profile.production",'
    '"skills":[{"id":"skill.cooking","n":0},{"id":"skill.foraging","n":0},'
    '{"id":"skill.mining","n":0},{"id":"skill.smithing","n":0},'
    '{"id":"skill.woodcutting","n":0}],'
    '"stateVersion":1,'
    '"steps":{"checkpoint":{"cursor":"Y3Vyc29yLTI=","syncCount":2,'
    '"watermarkMillis":null},'
    '"correctionsObserved":0,"grantedBeforeWatermark":0,'
    '"grantedSlices":['
    '{"e":1750007200000,"g":137,"o":"0f1e2d3c4b5a6978","s":1750003600000},'
    '{"e":1750003600000,"g":613,"o":"a1b2c3d4e5f60718","s":1750000000000},'
    '{"e":1750007200000,"g":291,"o":"a1b2c3d4e5f60718","s":1750003600000}],'
    '"lateDiscardedSlices":0,'
    '"recovery":{"attempts":0,"phase":"idle","truncated":false,'
    '"windowEndMillis":null,"windowStartMillis":null},'
    '"sourceState":"available","totalGranted":1041,"totalObserved":1041,'
    '"totalSpent":400,"unreachableGapEvents":0},'
    '"world":{"currentLocation":"location.havens_rest",'
    '"unlockedLocations":["location.havens_rest"]}}';

/// The fixture's byte length, asserted so a line-ending translation on
/// checkout is caught here rather than as a mysterious CRC failure.
const int expectedV1ByteLength = 1478;

const String slotA = 'save_slot_a';

File get fixtureFile => File('${fixtureDirectory.path}/save/v1_baseline.save');

Uint8List get v1Baseline {
  final File file = fixtureFile;
  if (!file.existsSync()) {
    throw StateError(
      'Missing frozen fixture ${file.path}. It must be restored from git, '
      'never regenerated — see the header of save_migration_test.dart.',
    );
  }
  return file.readAsBytesSync();
}

/// Re-encodes [framed] with the envelope mutated, digest recomputed.
Uint8List remake(
  Uint8List framed,
  void Function(Map<String, Object?> envelope, Map<String, Object?> state)
  mutate,
) {
  final FrameResult result = unframe(framed);
  expect(result.verified, isTrue, reason: 'the frozen fixture must verify');
  final Map<String, Object?> envelope =
      jsonDecode(utf8.decode(result.payload!)) as Map<String, Object?>;
  mutate(envelope, envelope['state']! as Map<String, Object?>);
  return frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));
}

Future<LoadOutcome> loadWithoutThrowing(Uint8List slotBytes) async {
  final FaultingDevice device = FaultingDevice()..seed(slotA, slotBytes);
  Object? thrown;
  LoadOutcome? outcome;
  try {
    outcome = await newRepo(device).repo.load(registry: saveRegistry);
  } on Object catch (e) {
    thrown = e;
  }
  expect(
    thrown,
    isNull,
    reason: 'a version skew must be a typed refusal, never a throw: $thrown',
  );
  return outcome!;
}

void main() {
  group('the fixture is intact', () {
    test('the bytes on disk are the bytes that were checked in', () {
      final Uint8List bytes = v1Baseline;

      expect(
        bytes.length,
        expectedV1ByteLength,
        reason:
            'the fixture changed size. If this fires on a fresh clone the '
            'cause is almost certainly line-ending translation — check that '
            'test/fixtures/save/.gitattributes marks *.save as binary.',
      );
      expect(
        bytes.contains(0x0D),
        isFalse,
        reason: 'a CR in a frozen save means git rewrote it on checkout',
      );
      expect(unframe(bytes).verified, isTrue);
    });

    test('it still loads through the repository', () async {
      final LoadOutcome outcome = await loadWithoutThrowing(v1Baseline);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(loaded.generation, 7);
      expect(loaded.lastAppliedTransaction, 4);
      expect(loaded.replayedTransactions, 0);
      expect(loaded.repairs, isEmpty);
      // The construction described in the header, asserted rather than
      // documented, so the fixture stays self-describing without a generator.
      expect(loaded.state.steps.totalGranted, 1041);
      expect(loaded.state.steps.totalSpent, 400);
      expect(loaded.state.steps.grantedSlices, hasLength(3));
      expect(
        loaded.state.equipment.inSlot(EquipmentSlot.weapon),
        ContentId.unchecked('item.training_sword'),
      );
    });
  });

  group('A — decoding the frozen fixture', () {
    test('produces the exact expected state', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v1Baseline).payload!,
      );

      expect(envelope.gameStateVersion, 1);
      expect(envelope.saveFormatVersion, SaveFormatVersion.current);
      expect(envelope.saveId, 'v1-baseline-0001');
      expect(envelope.commitComplete, isTrue);
      expect(
        canonicalDurableGameState(envelope.state),
        expectedV1Signature,
        reason:
            'a v1 save must decode to the same state it always has. If this '
            'fires, a decoder changed meaning — fix the decoder, never the '
            'fixture and never this literal.',
      );
    });
  });

  group('B — the round trip', () {
    test('encode(decode(fixture)) is byte-identical to the fixture', () {
      final Uint8List fixture = v1Baseline;
      final SaveEnvelope envelope = decodeEnvelope(unframe(fixture).payload!);

      final Uint8List reencoded = encodeSnapshot(
        state: envelope.state,
        saveId: envelope.saveId,
        generation: envelope.snapshotGeneration,
        lastAppliedTransaction: envelope.lastAppliedTransaction,
        originSaltFingerprint: null,
      );

      // The trap that fires the day someone adds a field to GameState without
      // thinking about saves. Without it the change is entirely silent until a
      // player's save fails to load in the field.
      //
      // If this fires: the encoder and the v1 decoder no longer agree. Either
      // the new field belongs in state version 2 (add a decoder, add a new
      // fixture, and make this test decode-only for v1), or the encoder has an
      // ordering or type defect. Editing the fixture is never the fix.
      expect(
        reencoded,
        fixture,
        reason:
            'the canonical encoder no longer reproduces a v1 save. See the '
            'regeneration policy at the top of this file.',
      );
    });
  });

  group('C — a state version below the supported floor', () {
    test('there is no decoder for version 0', () {
      expect(StateCodecs.decoderFor(0), isNull);
      expect(StateCodecs.decoderFor(1), isNotNull);
      expect(StateCodecs.decoderFor(1)!.version, 1);
      expect(StateVersion.supports(0), isFalse);
    });

    test('a version-0 save refuses cleanly rather than throwing', () async {
      final Uint8List bytes = remake(v1Baseline, (
        Map<String, Object?> envelope,
        Map<String, Object?> state,
      ) {
        envelope['gameStateVersion'] = 0;
        state['stateVersion'] = 0;
      });

      final LoadOutcome outcome = await loadWithoutThrowing(bytes);

      expect(outcome, isA<LoadRefused>());
      final LoadRefused refused = outcome as LoadRefused;
      expect(refused.reason, LoadRefusal.unsupportedStateVersion);
      expect(
        refused.repairs.any(
          (SaveRepair r) =>
              r.diagnosis == SaveDiagnosis.slotUnsupportedStateVersion,
        ),
        isTrue,
        reason: '${refused.repairs}',
      );
      expect(
        outcome,
        isNot(isA<NoSaveFound>()),
        reason: 'an unreadable version must never present as a new player',
      );
    });
  });

  group('D — a state version from the future', () {
    test('refuses, names the skew, and deletes nothing', () async {
      final int future = StateVersion.current.value + 1;
      final Uint8List bytes = remake(v1Baseline, (
        Map<String, Object?> envelope,
        Map<String, Object?> state,
      ) {
        envelope['gameStateVersion'] = future;
        state['stateVersion'] = future;
      });

      final FaultingDevice device = FaultingDevice()..seed(slotA, bytes);
      final String before = device.image();

      final LoadOutcome outcome = await newRepo(
        device,
      ).repo.load(registry: saveRegistry);

      expect(outcome, isA<LoadRefused>());
      expect(
        (outcome as LoadRefused).reason,
        LoadRefusal.unsupportedStateVersion,
      );
      expect(outcome.explanation, contains('Update the app'));
      expect(
        device.image(),
        before,
        reason: 'a refusal never deletes; the save must survive the downgrade',
      );
    });
  });
}
