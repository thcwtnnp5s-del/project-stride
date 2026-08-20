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
// That is what happened for state version 2 (`DECISIONS/0016`), and it happened
// again for state version 3 (`DECISIONS/0018`): `V3StateDecoder`, a frozen
// `v3_baseline.save` generated once by `tool/generate_v3_baseline.dart` from
// the v2 fixture through the real migration, and the v2 round trip became
// decode-only in its turn. Neither older fixture was touched. And again for
// state version 4 (`DECISIONS/0020`, Combat Slice 01): `V4StateDecoder`,
// `v4_baseline.save` from `tool/generate_v4_baseline.dart`, and the v3 round
// trip became decode-only. No older fixture was touched. And again for state
// version 5 (`DECISIONS/0021`, repeatable encounters): `V5StateDecoder`,
// `v5_baseline.save` from `tool/generate_v5_baseline.dart`, and the v4 round
// trip became decode-only in its turn. No older fixture was touched.
// (Rule 4 is about
// *decoders* — the meaning applied after decoding is a table of steps,
// `StateMigrations`, and that one is deliberately a chain.)
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
///
/// ## The Phase 2 amendment, and why it is not fixture-fitting either
///
/// `"epoch":{"grantedAtStart":0,"spentAtStart":0}` was added when
/// `StateVersion.current` became 2 (`DECISIONS/0016`).
///
/// This literal is the output of `canonicalDurableGameState`, which is the
/// **current** encoder — the file header's own instruction is that "v1 must keep
/// decoding into whatever the current `GameState` is". So when the current state
/// gains a durable field, this literal gains it too. What must never change is
/// any value that describes *the fixture*, and none did: every one of the
/// twenty-odd figures above is byte-identical to what it was before.
///
/// The added value is not taken on trust from a passing run. `0/0` is the origin
/// epoch, and it is the only value a v1 save can decode to, because a v1 save
/// has no epoch field for `V1StateDecoder` to read — its absence *is* the origin,
/// which is precisely what a v1 save meant: every granted step is playable.
/// `banked` therefore still reads 641, exactly as it did before this field
/// existed, which is asserted directly below rather than left to inference.
///
/// ## The state version 3 amendment
///
/// `"establishedAtStateVersion":0` was added inside the epoch when
/// `StateVersion.current` became 3 (`DECISIONS/0018`), on the same reasoning:
/// the current encoder writes it, and `0` is the only value a v1 save can decode
/// to, because the origin epoch was established by no migration. Every other
/// value in the literal is byte-identical to what it was.
///
/// ## The state version 4 amendment
///
/// `"encounter":null` and `"world.drivenOff":[]` were added when
/// `StateVersion.current` became 4 (`DECISIONS/0020`, Combat Slice 01), on the
/// same reasoning: the current encoder writes both, and null / empty are the
/// only values a v1 save can decode to, because a v1 save has neither field —
/// combat did not exist, so no fight was on and nothing was driven off. Every
/// other value in the literal is byte-identical to what it was.
///
/// ## The state version 5 amendment
///
/// `"world.drivenOff":[]` became `"world.visitVictories":{}` when
/// `StateVersion.current` became 5 (`DECISIONS/0021`, repeatable encounters),
/// on the same reasoning again: the current encoder writes the map and never
/// the list, and an empty map is the only value a v1 save can decode to,
/// because a v1 save has neither field — combat did not exist, so nothing had
/// been beaten this visit. The key sorts after `unlockedLocations` rather than
/// before it, which is why the line moved as well as changed. Every other
/// value in the literal is byte-identical to what it was.
///
/// ## The state version 6 amendment
///
/// `"activityQueue":null` was added when `StateVersion.current` became 6
/// (`DECISIONS/0022`, finite background activity), on the same reasoning
/// again: the current encoder writes it, and null is the only value a v1 save
/// can decode to, because a v1 save has no such field — no queue could
/// outlive the process before v6, so none was ever stored. The key sorts
/// before `contentPackVersion`, so it opens the object. Every other value in
/// the literal is byte-identical to what it was.
const String expectedV1Signature =
    '{"activityQueue":null,'
    '"contentPackVersion":1,'
    '"encounter":null,'
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
    '"correctionsObserved":0,'
    '"epoch":{"establishedAtStateVersion":0,"grantedAtStart":0,'
    '"spentAtStart":0},'
    '"grantedBeforeWatermark":0,'
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
    '"unlockedLocations":["location.havens_rest"],'
    '"visitVictories":{}}}';

/// The fixture's byte length, asserted so a line-ending translation on
/// checkout is caught here rather than as a mysterious CRC failure.
const int expectedV1ByteLength = 1478;

const String slotA = 'save_slot_a';

File get fixtureFile => File('${fixtureDirectory.path}/save/v1_baseline.save');

File get v2FixtureFile =>
    File('${fixtureDirectory.path}/save/v2_baseline.save');

Uint8List _frozen(File file) {
  if (!file.existsSync()) {
    throw StateError(
      'Missing frozen fixture ${file.path}. It must be restored from git, '
      'never regenerated — see the header of save_migration_test.dart.',
    );
  }
  return file.readAsBytesSync();
}

Uint8List get v1Baseline => _frozen(fixtureFile);

/// The v1 fixture, after the Phase 2 cutover, frozen in its turn.
///
/// Generated **once** by `tool/generate_v2_baseline.dart`, which reads
/// `v1_baseline.save` and runs it through the real migration. It is frozen on
/// the same terms as v1 and for the same reason: it is the shape a save written
/// by today's build actually has, and the only artifact that can prove tomorrow's
/// build still reads one.
///
/// The generator exists in the repository rather than being a note in a comment
/// so the provenance of these bytes is checkable, and it is deliberately not
/// wired into the test run — a fixture a test can regenerate is a fixture that
/// silently agrees with whatever the code does today.
Uint8List get v2Baseline => _frozen(v2FixtureFile);

File get v3FixtureFile =>
    File('${fixtureDirectory.path}/save/v3_baseline.save');

/// The v2 fixture, after the Transformation playtest epoch, frozen in its turn.
///
/// Generated **once** by `tool/generate_v3_baseline.dart` from `v2_baseline.save`
/// through the real v2→v3 step (`DECISIONS/0018`). Same terms as v1 and v2.
Uint8List get v3Baseline => _frozen(v3FixtureFile);

File get v4FixtureFile =>
    File('${fixtureDirectory.path}/save/v4_baseline.save');

/// The v3 fixture, after the Combat Slice 01 format bump, frozen in its turn.
///
/// Generated **once** by `tool/generate_v4_baseline.dart` from `v3_baseline.save`
/// through the real v3→v4 step (`DECISIONS/0020`). Same terms as v1–v3.
Uint8List get v4Baseline => _frozen(v4FixtureFile);

File get v5FixtureFile =>
    File('${fixtureDirectory.path}/save/v5_baseline.save');

/// The v4 fixture, after the repeatable-encounter format bump, frozen in its
/// turn.
///
/// Generated **once** by `tool/generate_v5_baseline.dart` from `v4_baseline.save`
/// through the real v4→v5 step (`DECISIONS/0021`). Same terms as v1–v4.
Uint8List get v5Baseline => _frozen(v5FixtureFile);

File get v6FixtureFile =>
    File('${fixtureDirectory.path}/save/v6_baseline.save');

/// The v5 fixture, after the activity-queue format bump, frozen in its turn.
///
/// Generated **once** by `tool/generate_v6_baseline.dart` from `v5_baseline.save`
/// through the real v5→v6 step (`DECISIONS/0022`). Same terms as v1–v5.
Uint8List get v6Baseline => _frozen(v6FixtureFile);

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

  // ## Why B is decode-only from Phase 2 onward
  //
  // `encode(decode(v1))` cannot be byte-identical to a v1 artifact once the
  // encoder emits v2: there is one encoder and it only ever writes the current
  // version. That is the asymmetry `StateCodecs` is built on — decode fans in,
  // encode does not fan out — so a byte comparison here would be asserting that
  // the encoder had *not* moved, which is the opposite of what this file guards.
  //
  // What is worth keeping is the property underneath it: **decoding a v1 save
  // must not change what the save says.** That survives as a value comparison
  // against the frozen literal, and the round-trip property itself moves to
  // `v2_baseline.save`, where it can still be byte-exact.
  group('B — decoding a v1 save changes no value it carries', () {
    test('the decoded state matches the frozen literal, field for field', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v1Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(canonicalDurableGameState(state), expectedV1Signature);

      // Spelled out rather than left to the literal, because these are the
      // figures the Phase 2 cutover is about and a reader should not have to
      // parse JSON to check that decoding left them alone.
      expect(state.stateVersion, 1);
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      expect(
        state.steps.epoch,
        const EconomyEpoch.origin(),
        reason:
            'a v1 save has no epoch field, and its absence is the origin '
            'epoch — not a default standing in for missing data',
      );
      expect(
        state.steps.banked,
        641,
        reason:
            'the whole point of the origin epoch: a v1 save decodes to exactly '
            'the balance it had before the field existed. 1041 - 400 = 641.',
      );
    });

    test('a v1 save is still flagged as needing migration', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v1Baseline).payload!,
      );
      expect(
        StateVersion.migrationRequired(envelope.state.stateVersion),
        isTrue,
        reason:
            'this flag is the only durable signal that the Phase 2 cutover has '
            'not run on a save. If it is ever false for a v1 state, the '
            "owner's device would resume with 459,043 spendable steps.",
      );
    });
  });

  // ## Why B2 is decode-only from state version 3 onward
  //
  // The same reasoning as B, one version later. `v2_baseline.save` is now the
  // artifact a device that took the Phase 2 cutover but not the Transformation
  // epoch actually holds, and what must hold is that decoding it changes no
  // value it carries — including that its epoch reads as *established at v2*,
  // which is what the v2→v3 step's exactly-once guard turns on.
  group('B2 — decoding a v2 save changes no value it carries', () {
    test('the v2 fixture is the migrated v1 fixture, and says so', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v2Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(state.stateVersion, 2);
      // History intact: the same two totals the v1 fixture carried.
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      // And the cutover applied to them.
      expect(
        state.steps.epoch,
        const EconomyEpoch(
          grantedAtStart: 1041,
          spentAtStart: 400,
          establishedAtStateVersion: 2,
        ),
        reason:
            'a v2 save has no establishedAtStateVersion field, and a non-origin '
            'mark in one can only have been set by the Phase 2 cutover — so it '
            'reads as established at 2, not as missing data',
      );
      expect(state.steps.banked, 0);
      expect(state.steps.epoch.retiredSteps, 641);
    });

    test('a v2 save is flagged as needing migration', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v2Baseline).payload!,
      );
      expect(
        StateVersion.migrationRequired(envelope.state.stateVersion),
        isTrue,
        reason:
            'this flag is the only durable signal that the Transformation '
            'playtest epoch has not run on a save (`DECISIONS/0018`)',
      );
    });
  });

  // ## Why B3 is decode-only from state version 4 onward
  //
  // The same reasoning as B and B2, one version later. `v3_baseline.save` is
  // now the artifact a device that took the Transformation epoch but not the
  // Combat Slice 01 format bump actually holds. What must hold is that decoding
  // it changes no value it carries — and that it decodes with no fight on and
  // nothing driven off, which is what a v3 save meant.
  group('B3 — decoding a v3 save changes no value it carries', () {
    test('the v3 fixture is the migrated v2 fixture, and says so', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v3Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(state.stateVersion, 3);
      // History intact, twice over.
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      // The v2 fixture was already at banked 0, so the v3 step re-based at the
      // same two marks — and recorded that it did so, at v3.
      expect(
        state.steps.epoch,
        const EconomyEpoch(
          grantedAtStart: 1041,
          spentAtStart: 400,
          establishedAtStateVersion: 3,
        ),
      );
      expect(state.steps.banked, 0);
      expect(state.steps.epoch.retiredSteps, 641);
      // Combat did not exist at v3. Absence is what those saves meant.
      expect(state.encounter, isNull);
      expect(state.world.visitVictories, isEmpty);
    });

    test('a v3 save is flagged as needing migration', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v3Baseline).payload!,
      );
      expect(
        StateVersion.migrationRequired(envelope.state.stateVersion),
        isTrue,
        reason:
            'the v3→v4 step is a format bump only, but the save still has to '
            'be committed at v4 so the next launch reads it as current',
      );
    });
  });

  // ## Why B4 is decode-only from state version 5 onward
  //
  // The same reasoning as B, B2 and B3, one version later. `v4_baseline.save`
  // is now the artifact a device that took the Combat Slice 01 format bump but
  // not the repeatable-encounter one actually holds. What must hold is that
  // decoding it changes no value it carries — and, the part that is new, that
  // its `drivenOff` list decodes into the current `visitVictories` map at a
  // count of one each, which is what a v4 save said.
  group('B4 — decoding a v4 save changes no value it carries', () {
    test('the v4 fixture is the migrated v3 fixture, and says so', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v4Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(state.stateVersion, 4);
      // History intact, three times over — and the epoch untouched, because
      // the v3→v4 step does not re-base (`DECISIONS/0020`).
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      expect(
        state.steps.epoch,
        const EconomyEpoch(
          grantedAtStart: 1041,
          spentAtStart: 400,
          establishedAtStateVersion: 3,
        ),
        reason: 'a format bump must not move the economy mark',
      );
      expect(state.steps.banked, 0);
      expect(state.encounter, isNull);
      expect(state.world.visitVictories, isEmpty);
    });

    test('a v4 save is flagged as needing migration', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v4Baseline).payload!,
      );
      expect(
        StateVersion.migrationRequired(envelope.state.stateVersion),
        isTrue,
        reason:
            'the v4→v5 step is a format bump only, but the save still has to '
            'be committed at v5 so the next launch reads it as current',
      );
    });

    test('a v4 drivenOff entry decodes as one victory this visit', () {
      // The baseline's list is empty, so the rule is exercised against a v4
      // envelope carrying an actual driven-off enemy — the frozen fixture is
      // the migrated lineage of the older ones and is not edited to carry a
      // value it never had (`DECISIONS/0021` §3).
      final Uint8List bytes = remake(v4Baseline, (
        Map<String, Object?> envelope,
        Map<String, Object?> state,
      ) {
        (state['world']! as Map<String, Object?>)['drivenOff'] = <Object?>[
          'enemy.forest_wolf',
        ];
      });

      final GameState state = decodeEnvelope(unframe(bytes).payload!).state;

      expect(state.world.visitVictories, <ContentId, int>{
        ContentId.unchecked('enemy.forest_wolf'): 1,
      });
      // One is what the v4 rule meant, so the enemy stays spent for an enemy
      // that still authors a single encounter a visit, and is fightable once
      // more where content now authors two. Nothing was inferred.
      expect(
        state.world.isAvailable(ContentId.unchecked('enemy.forest_wolf'), 1),
        isFalse,
      );
      expect(
        state.world.isAvailable(ContentId.unchecked('enemy.forest_wolf'), 2),
        isTrue,
      );
    });
  });

  // ## Why B5 is decode-only from state version 6 onward
  //
  // The same reasoning as B–B4, one version later. `v5_baseline.save` is now
  // the artifact a device that took the repeatable-encounter format bump but
  // not the activity-queue one actually holds. What must hold is that
  // decoding it changes no value it carries — and that it decodes with no
  // activity queue, which is what a v5 save meant: no queue could outlive the
  // process before v6. The round-trip property moves to `v6_baseline.save`.
  group('B5 — decoding a v5 save changes no value it carries', () {
    test('the v5 fixture is the migrated v4 fixture, and says so', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v5Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(state.stateVersion, 5);
      // History intact, four times over — and the epoch untouched, because
      // the v4→v5 step does not re-base either (`DECISIONS/0021` §3).
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      expect(
        state.steps.epoch,
        const EconomyEpoch(
          grantedAtStart: 1041,
          spentAtStart: 400,
          establishedAtStateVersion: 3,
        ),
        reason: 'a format bump must not move the economy mark',
      );
      expect(state.steps.banked, 0);
      expect(state.encounter, isNull);
      expect(state.world.visitVictories, isEmpty);
      expect(
        state.activityQueue,
        isNull,
        reason:
            'a v5 save has no activityQueue field, and its absence means no '
            'queue was running — not a default standing in for missing data',
      );
    });

    test('a v5 save is flagged as needing migration', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v5Baseline).payload!,
      );
      expect(
        StateVersion.migrationRequired(envelope.state.stateVersion),
        isTrue,
        reason:
            'the v5→v6 step is a format bump only, but the save still has to '
            'be committed at v6 so the next launch reads it as current',
      );
    });

    test('the v5 fixture grew by exactly the one reshaped key', () {
      // `"drivenOff":[],` (15) left; `,"visitVictories":{}` (20) arrived, and
      // it sorts after `unlockedLocations` rather than before it, so the comma
      // moved with it. 20 − 15 = 5, and the version digit is one either way. A
      // change that had also perturbed something else would not land on 5.
      expect(v5Baseline.length - v4Baseline.length, 5);
    });
  });

  group('B6 — the round trip, carried forward to v6', () {
    test('encode(decode(fixture)) is byte-identical to the v6 fixture', () {
      final Uint8List fixture = v6Baseline;
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
      // If this fires: the encoder and the v6 decoder no longer agree. Either
      // the new field belongs in state version 7 (add a decoder, add a new
      // fixture, add a `StateMigrations` step that says whether it re-bases —
      // it should not — and make this test decode-only for v6), or the encoder
      // has an ordering or type defect. Editing the fixture is never the fix.
      expect(
        reencoded,
        fixture,
        reason:
            'the canonical encoder no longer reproduces a v6 save. See the '
            'regeneration policy at the top of this file.',
      );
    });

    test('the v6 fixture is the migrated v5 fixture, and says so', () {
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(v6Baseline).payload!,
      );
      final GameState state = envelope.state;

      expect(state.stateVersion, 6);
      // History intact, five times over — and the epoch untouched, because
      // the v5→v6 step does not re-base either (`DECISIONS/0022` §5).
      expect(state.steps.totalGranted, 1041);
      expect(state.steps.totalSpent, 400);
      expect(
        state.steps.epoch,
        const EconomyEpoch(
          grantedAtStart: 1041,
          spentAtStart: 400,
          establishedAtStateVersion: 3,
        ),
        reason: 'a format bump must not move the economy mark',
      );
      expect(state.steps.banked, 0);
      expect(state.encounter, isNull);
      expect(state.world.visitVictories, isEmpty);
      expect(state.activityQueue, isNull);
      expect(
        StateVersion.migrationRequired(state.stateVersion),
        isFalse,
        reason: 'a migrated save must never migrate again',
      );
    });

    test('the v6 fixture grew by exactly the one added key', () {
      // `"activityQueue":null,` arrived — 15 bytes of key, a colon, `null`,
      // and the comma: 21 — and it sorts first in the state object, so
      // nothing else moved. The version digit is one byte either way. A
      // change that had also perturbed something else would not land on 21.
      expect(v6Baseline.length - v5Baseline.length, 21);
    });
  });

  group('C — a state version below the supported floor', () {
    test('there is a decoder for every supported version, and no other', () {
      expect(StateCodecs.decoderFor(0), isNull);
      expect(StateCodecs.decoderFor(1), isNotNull);
      expect(StateCodecs.decoderFor(1)!.version, 1);
      expect(StateCodecs.decoderFor(2), isNotNull);
      expect(StateCodecs.decoderFor(2)!.version, 2);
      expect(StateCodecs.decoderFor(3), isNotNull);
      expect(StateCodecs.decoderFor(3)!.version, 3);
      expect(StateCodecs.decoderFor(4), isNotNull);
      expect(StateCodecs.decoderFor(4)!.version, 4);
      expect(StateCodecs.decoderFor(5), isNotNull);
      expect(StateCodecs.decoderFor(5)!.version, 5);
      expect(StateCodecs.decoderFor(6), isNotNull);
      expect(StateCodecs.decoderFor(6)!.version, 6);
      expect(
        StateCodecs.decoderFor(StateVersion.current.value + 1),
        isNull,
        reason: 'a decoder for an unreleased version would be guessing',
      );
      expect(StateVersion.supports(0), isFalse);

      // Every version in the supported range must have a decoder. Without this,
      // widening `minimumSupported` without adding the decoder would present as
      // `allSlotsUnreadable` on a real device rather than as a failing test.
      for (
        int v = StateVersion.minimumSupported.value;
        v <= StateVersion.current.value;
        v++
      ) {
        expect(
          StateCodecs.decoderFor(v),
          isNotNull,
          reason: 'state version $v is supported but has no decoder',
        );
      }
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
