/// The persistence-port conformance suite: defined once, run against every
/// implementation of the `stride_core` storage ports.
///
/// ## Why this is a library and not a test file
///
/// There are two implementations of `SnapshotSlotStore`, `LedgerJournal`, and
/// `ReconciliationIdentityStore`: the in-memory `FaultingDevice` that makes the
/// crash matrix testable in milliseconds, and the real `dart:io` adapters that
/// actually run on a phone. A suite written twice is two suites that will
/// eventually disagree, and the one that drifts will be the one nobody runs on
/// a device. So the suite is written once, here, and both packages execute it.
///
/// ## What this suite is *not*
///
/// It is not the crash/fault matrix. That lives in `stride_core` and needs
/// fault injection a real filesystem cannot provide. This suite asserts the
/// properties that must hold on **any** backing store: slot selection,
/// compare-and-swap, replay, damage diagnosis, fail-closed refusals, watermark
/// persistence, and the privacy invariants over the durable bytes themselves.
///
/// ## The one rule
///
/// Every assertion here is made through the ports or over the raw durable
/// bytes. Nothing reaches into an implementation. A test that needed to know
/// whether it was talking to a disk would not be a conformance test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// The fixture
// ---------------------------------------------------------------------------

/// Canonical names for the durable artifacts.
///
/// Roles rather than filenames. The in-memory device calls its journal
/// `journal` and the filesystem adapter calls it `ledger_journal`; a suite that
/// asserted over filenames would be asserting over an implementation detail,
/// and the equivalence transcript could never match across the two.
abstract final class ArtifactRole {
  static const String slotA = 'slot_a';
  static const String slotB = 'slot_b';
  static const String journal = 'journal';
  static const String sidecar = 'sidecar';
  static const String identity = 'identity';

  /// The artifacts that make up the save proper.
  ///
  /// The identity is deliberately excluded: it is the one artifact that holds
  /// the salt, and the invariant is that the salt never reaches these.
  static const List<String> saveArtifacts = <String>[
    slotA,
    slotB,
    journal,
    sidecar,
  ];
}

/// One implementation of the persistence ports, freshly opened.
final class PersistenceFixture {
  const PersistenceFixture({
    required this.snapshots,
    required this.journal,
    required this.identity,
    required this.readArtifacts,
    required this.seedIdentity,
    required this.teardown,
    this.lock = const UncontendedLock(),
  });

  final SnapshotSlotStore snapshots;
  final LedgerJournal journal;
  final ReconciliationIdentityStore identity;

  /// The transaction lock the suite builds its repositories with.
  ///
  /// The in-memory fixture has no medium to contend over and keeps the
  /// default. A fixture over a real directory **must** supply the real lock,
  /// or the suite would be certifying a configuration that never ships.
  final TransactionLock lock;

  /// Every durable artifact that currently exists, keyed by [ArtifactRole],
  /// read **from the medium itself and not through the ports**.
  ///
  /// This is what makes the privacy assertions worth anything. Reading the
  /// bytes back through `SnapshotSlotStore.read` would prove only that the
  /// adapter returns what it was given; reading the file off disk proves what
  /// is actually sitting on the device.
  final Future<Map<String, Uint8List>> Function() readArtifacts;

  /// Writes an identity the way the **app** writes one: salt included.
  ///
  /// The port's own `write` carries only a fingerprint, and a fingerprint
  /// cannot produce a salt — so an implementation that persists salt material
  /// needs a second, app-facing way in. This is that way, and the suite uses it
  /// to establish a realistic starting state before exercising the port.
  final Future<void> Function(String saveId, Uint8List salt) seedIdentity;

  final FutureOr<void> Function() teardown;
}

// ---------------------------------------------------------------------------
// Fixture data
// ---------------------------------------------------------------------------

/// The lineage id every conformance save is written under.
const String conformanceSaveId = 'save-conformance-0001';

/// A fixed salt. A constant, never a random draw: the suite must be
/// deterministic, and a random salt would make the identity artifact's bytes
/// differ between runs and between implementations.
final Uint8List conformanceSalt = Uint8List.fromList(<int>[
  0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, //
  0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x01,
]);

/// Two pseudonymous origins. Sixteen hex characters, because that is what a
/// pseudonymizer emits and what `StepOriginKey` will accept — a key that could
/// hold `Robs iPhone` is a key that will eventually hold one.
final StepOriginKey conformancePhone = StepOriginKey('a1b2c3d4e5f60718');
final StepOriginKey conformanceWatch = StepOriginKey('0f1e2d3c4b5a6978');

const int _hour = 60 * 60 * 1000;

/// A fixed origin instant. A constant, never a clock read.
const int _t0 = 1750000000000;

// Quantities are distinct and non-summing — 137, 291, 613, 1000 — so a drop, a
// duplicate, and an off-by-one each land on a different number.
const int _first = 613;
const int _secondGrant = 291;
const int _secondSpend = 137;
const int _grantedAfterBoth = 904;

StepObservation _obs(StepOriginKey origin, int index, int steps) =>
    StepObservation(
      key: ObservationKey(
        origin: origin,
        bucket: TimeBucket(
          startMillis: _t0 + index * _hour,
          endMillis: _t0 + (index + 1) * _hour,
        ),
      ),
      steps: steps,
    );

IncrementalSync _incremental(
  List<StepObservation> observations, {
  String? next,
  int? completeThroughIndex,
}) => IncrementalSync(
  observations: observations,
  nextCursor: next == null ? null : SyncCursor.ofString(next),
  completeness: completeThroughIndex == null
      ? const PartialDelivery()
      : CompleteThrough(
          throughMillis: _t0 + completeThroughIndex * _hour,
          scope: CompletenessScope(
            dataType: HealthDataType.steps,
            origins: const AllOrigins(),
            intervalStartMillis: _t0,
            intervalEndMillis: _t0 + completeThroughIndex * _hour,
            queryGeneration: 1,
          ),
        ),
);

int _grantedBy(EngineResult result) => result.events
    .whereType<StepsGranted>()
    .fold<int>(0, (int sum, StepsGranted e) => sum + e.steps);

// ---------------------------------------------------------------------------
// Small helpers shared by the suite
// ---------------------------------------------------------------------------

SaveRepository _repo(PersistenceFixture f, {int maxCommitRetries = 3}) =>
    SaveRepository(
      snapshots: f.snapshots,
      journal: f.journal,
      maxCommitRetries: maxCommitRetries,
      lock: f.lock,
    );

Future<CommitOutcome> _commit(
  SaveRepository repo, {
  required GameState after,
  required List<GameEvent> events,
  required int generation,
  required int lastTransaction,
  String? originSaltFingerprint,
}) => repo.commit(
  after: after,
  events: events,
  saveId: conformanceSaveId,
  originSaltFingerprint: originSaltFingerprint,
  expectation: CommitExpectation(
    expectedSnapshotGeneration: generation,
    expectedLastAppliedTransaction: lastTransaction,
  ),
);

/// A canonical, legible dump of every durable byte.
///
/// Used for "a refusal changed nothing" assertions. Length *and* digest, so a
/// same-length rewrite is still visible.
Future<String> durableImage(PersistenceFixture f) async {
  final Map<String, Uint8List> artifacts = await f.readArtifacts();
  final List<String> roles = artifacts.keys.toList()..sort();
  return roles
      .map(
        (String r) => '$r:${artifacts[r]!.length}:${crc32cHex(artifacts[r]!)}',
      )
      .join('\n');
}

List<SaveDiagnosis> _diagnoses(List<SaveRepair> repairs) =>
    repairs.map((SaveRepair r) => r.diagnosis).toList();

/// A snapshot of a state carrying [steps] granted and nothing else unusual.
Uint8List _snapshotOf(
  ContentRegistry registry,
  int steps, {
  int generation = 0,
  int lastTransaction = 0,
  String? originSaltFingerprint,
}) {
  final GameEngine engine = GameEngine.newGame(registry: registry)
    ..execute(GrantSyntheticSteps(steps: steps, reason: 'conformance fixture'));
  return encodeSnapshot(
    state: engine.state,
    saveId: conformanceSaveId,
    generation: generation,
    lastAppliedTransaction: lastTransaction,
    originSaltFingerprint: originSaltFingerprint,
  );
}

/// Decodes [framed], applies [mutate], and re-frames with a **correct** digest.
///
/// The digest is recomputed on purpose: these cases test envelope validators,
/// and a stale checksum would short-circuit every one of them at the frame
/// layer and prove nothing.
Uint8List _remake(
  Uint8List framed,
  void Function(Map<String, Object?> envelope, Map<String, Object?> state)
  mutate,
) {
  final FrameResult result = unframe(framed);
  expect(result.verified, isTrue, reason: 'the base fixture must be healthy');
  final Map<String, Object?> envelope =
      jsonDecode(utf8.decode(result.payload!)) as Map<String, Object?>;
  mutate(envelope, envelope['state']! as Map<String, Object?>);
  return frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));
}

// ---------------------------------------------------------------------------
// The equivalence transcript
// ---------------------------------------------------------------------------

/// Runs a fixed operation sequence and returns everything observable about it.
///
/// Both implementations run this and both are compared against the same frozen
/// literal, which is what makes it an *equivalence* check rather than two
/// unrelated assertions. Artifact digests are included deliberately: the two
/// implementations must not merely reach the same outcomes, they must leave the
/// same bytes, because the protocol's correctness argument is about bytes.
Future<String> runPersistenceScript(
  PersistenceFixture f,
  ContentRegistry registry,
) async {
  final List<String> out = <String>[];
  final SaveRepository repo = _repo(f);
  final GameEngine engine = GameEngine.newGame(registry: registry);

  String describe(CommitOutcome outcome) => switch (outcome) {
    final CommitDurable d =>
      'durable tx=${d.transactionId} gen=${d.generation} '
          'slot=${d.slot.name} snapshotDurable=${d.snapshotDurable} '
          'retries=${d.retries}',
    final CommitRefused r => 'refused ${r.reason.name}',
  };

  final EngineResult one = engine.execute(
    const GrantSyntheticSteps(steps: _first, reason: 'script-1'),
  );
  final CommitOutcome first = await _commit(
    repo,
    after: engine.state,
    events: one.events,
    generation: -1,
    lastTransaction: 0,
  );
  out.add('commit1 ${describe(first)}');

  final EngineResult twoA = engine.execute(
    const GrantSyntheticSteps(steps: _secondGrant, reason: 'script-2'),
  );
  final EngineResult twoB = engine.execute(
    const AllocateSteps(steps: _secondSpend),
  );
  final CommitOutcome second = await _commit(
    repo,
    after: engine.state,
    events: <GameEvent>[...twoA.events, ...twoB.events],
    generation: 0,
    lastTransaction: 1,
  );
  out.add('commit2 ${describe(second)}');

  // A writer that still believes the save is empty.
  final GameEngine stale = GameEngine.newGame(registry: registry);
  final EngineResult staleBatch = stale.execute(
    const GrantSyntheticSteps(steps: 1000, reason: 'script-stale'),
  );
  final CommitOutcome refused = await _commit(
    repo,
    after: stale.state,
    events: staleBatch.events,
    generation: -1,
    lastTransaction: 0,
  );
  out.add('stale ${describe(refused)}');

  final LoadOutcome loaded = await _repo(f).load(registry: registry);
  out.add(switch (loaded) {
    final SaveLoaded l =>
      'load loaded slot=${l.fromSlot.name} gen=${l.generation} '
          'granted=${l.state.steps.totalGranted} '
          'spent=${l.state.steps.totalSpent} '
          'lastTx=${l.lastAppliedTransaction} replayed=${l.replayedTransactions} '
          'skipped=${l.skippedTransactions} '
          'repairs=[${_diagnoses(l.repairs).map((SaveDiagnosis d) => d.name).join(',')}]',
    final LoadRefused r => 'load refused ${r.reason.name}',
    NoSaveFound() => 'load none',
  });

  await f.seedIdentity(conformanceSaveId, conformanceSalt);
  final ReconciliationIdentity? identity = await f.identity.read();
  out.add(
    'identity saveId=${identity?.saveId} '
    'fingerprint=${identity?.saltFingerprint}',
  );

  out.add('journalLines ${(await f.journal.readLines()).length}');
  out.add(await durableImage(f));
  return out.join('\n');
}

/// The frozen expectation for [runPersistenceScript].
///
/// Reviewed by hand, not regenerated. If a change moves these numbers, that is
/// a save-format or protocol change and it needs a decision, not an update to
/// this string. The digests are the strongest part: two implementations that
/// reach the same outcomes by writing different bytes are not equivalent.
///
/// ## Amended once, for state version 2 — and here is the review
///
/// The Phase 2 economy epoch (`DECISIONS/0016`) added `steps.epoch` to the
/// encoder, so both slot lengths and both digests moved. That is the
/// save-format change this comment demands a decision for, and it has one.
///
/// **Every behavioural line above the digests is byte-identical to what it was**
/// — the same transaction ids, generations, slots, retry counts, the same
/// `granted=904 spent=137`, the same replay and skip counts, the same identity
/// and fingerprint, the same journal length and journal digest. Only the two
/// snapshot slots changed, which is exactly and only what adding a field to the
/// snapshot encoder should do.
///
/// The magnitude was checked rather than accepted. Both slots grew by **46
/// bytes**, and 46 is the exact length of the inserted canonical JSON at origin
/// values: `,"epoch":{"grantedAtStart":0,"spentAtStart":0}`. A field that had
/// also perturbed something else would not have landed on that number, and a
/// second field would have overshot it. The frozen v1→v2 save fixture grew by
/// 51 for the same reason with non-zero marks (1041 and 400 are three more
/// digits than 0 and 0, plus the two-byte key-order shift), which is the same
/// arithmetic confirming itself against different data.
///
/// ## Amended a second time, for state version 3 — same review
///
/// The Transformation playtest epoch (`DECISIONS/0018`) added
/// `establishedAtStateVersion` inside `steps.epoch`, so both slot lengths and
/// both digests moved again. Every behavioural line above the digests is again
/// byte-identical — same journal length and journal digest included, because
/// the conformance sequence contains no migration and so writes no
/// `EconomyEpochEstablished` record. Both slots grew by **30 bytes**, which is
/// the exact length of `"establishedAtStateVersion":0,` (a 25-character key in
/// quotes, a colon, one digit and the separating comma; the key sorts first
/// inside the epoch object so the comma follows it). The frozen v2→v3 fixture
/// grew by the same 30 with the digit `3` in place of `0`.
///
/// ## Amended a third time, for state version 4 — same review
///
/// Combat Slice 01 (`DECISIONS/0020`) added `encounter` (null when no fight is
/// on) at the top of the state and `drivenOff` (a sorted list, empty here)
/// inside `world`, so both slot lengths and both digests moved again. Every
/// behavioural line above the digests is again byte-identical, journal length
/// and digest included — the conformance sequence fights nothing and so writes
/// no combat record. Both slots grew by **32 bytes**, which is exactly
/// `"encounter":null,` (17) plus `"drivenOff":[],` (15). The frozen v3→v4
/// fixture grew by the same 32.
///
/// ## Amended a fourth time, for state version 5 — same review
///
/// Repeatable encounters (`DECISIONS/0021`) replaced `world.drivenOff` — a
/// sorted list of enemy ids — with `world.visitVictories`, an object of enemy
/// id → count, so both slot lengths and both digests moved again. Every
/// behavioural line above the digests is byte-identical once more, journal
/// length and digest included: the conformance sequence still fights nothing,
/// so it writes no combat record and the map is empty either way.
///
/// Both slots grew by **5 bytes**, and that figure is arithmetic rather than
/// an observation. Inside `world` the keys sort, so at v4 the empty list sat
/// between `currentLocation` and `unlockedLocations` as `"drivenOff":[],` —
/// 14 characters and the separating comma, 15 in all. At v5 the empty object
/// sorts *last*, after `unlockedLocations`, so it is `,"visitVictories":{}` —
/// 19 characters and the comma that now precedes it, 20 in all. 20 − 15 = 5,
/// and `gameStateVersion` / `stateVersion` moved from `4` to `5`, which is one
/// digit either way. A change that had perturbed anything else would not land
/// on 5 in both slots.
const String expectedPersistenceTranscript = '''
commit1 durable tx=1 gen=0 slot=a snapshotDurable=true retries=0
commit2 durable tx=2 gen=1 slot=b snapshotDurable=true retries=0
stale refused conflictRetryLimitExhausted
load loaded slot=b gen=1 granted=904 spent=137 lastTx=2 replayed=0 skipped=1 repairs=[]
identity saveId=save-conformance-0001 fingerprint=48ea03704e5fbe8e
journalLines 1
identity:68:e7502a24
journal:218:0e84a81c
slot_a:1340:979018da
slot_b:1342:94562b74''';

// ---------------------------------------------------------------------------
// The suite
// ---------------------------------------------------------------------------

/// Runs the whole conformance suite against one implementation.
///
/// [open] must return a **fresh, empty** store on every call; a fixture that
/// leaked state between tests would make the ordering of this file part of its
/// correctness argument.
void runPersistenceConformance({
  required String name,
  required ContentRegistry registry,
  required FutureOr<PersistenceFixture> Function() open,
}) {
  Future<PersistenceFixture> fixture() async {
    final PersistenceFixture f = await open();
    addTearDown(() async => f.teardown());
    return f;
  }

  group('persistence conformance [$name]', () {
    // --- the fixture is not lying about being empty -----------------------

    test('a fresh fixture is genuinely empty', () async {
      final PersistenceFixture f = await fixture();

      expect(await f.snapshots.read(SnapshotSlot.a), isNull);
      expect(await f.snapshots.read(SnapshotSlot.b), isNull);
      expect(await f.journal.readLines(), isEmpty);
      expect(await f.identity.read(), isNull);
      expect(
        await f.readArtifacts(),
        isEmpty,
        reason:
            'a fixture that starts with artifacts would make every '
            '"nothing was written" assertion below meaningless',
      );
    });

    // --- slot selection ---------------------------------------------------

    group('slot selection', () {
      test(
        'the first commit lands in slot a and writes nothing else',
        () async {
          final PersistenceFixture f = await fixture();
          final SaveRepository repo = _repo(f);
          final GameEngine engine = GameEngine.newGame(registry: registry);
          final EngineResult r = engine.execute(
            const GrantSyntheticSteps(steps: _first, reason: 'first'),
          );

          final CommitOutcome outcome = await _commit(
            repo,
            after: engine.state,
            events: r.events,
            generation: -1,
            lastTransaction: 0,
          );

          expect(outcome, isA<CommitDurable>());
          final CommitDurable durable = outcome as CommitDurable;
          expect(durable.transactionId, 1);
          expect(durable.generation, 0);
          expect(durable.slot, SnapshotSlot.a);
          expect(durable.snapshotDurable, isTrue);
          expect(durable.retries, 0);

          final Map<String, Uint8List> artifacts = await f.readArtifacts();
          expect(artifacts.keys.toSet(), <String>{
            ArtifactRole.slotA,
            ArtifactRole.journal,
          });
          expect(artifacts[ArtifactRole.slotA], isNotEmpty);
          expect(artifacts[ArtifactRole.journal], isNotEmpty);
        },
      );

      test('commits alternate and never overwrite the live slot', () async {
        final PersistenceFixture f = await fixture();
        final SaveRepository repo = _repo(f);
        final GameEngine engine = GameEngine.newGame(registry: registry);

        final List<SnapshotSlot> written = <SnapshotSlot>[];
        int generation = -1;
        int transaction = 0;
        Uint8List? slotAAfterFirst;

        for (final int steps in <int>[137, 291, 613, 137]) {
          final EngineResult r = engine.execute(
            GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
          );
          final CommitDurable d =
              await _commit(
                    repo,
                    after: engine.state,
                    events: r.events,
                    generation: generation,
                    lastTransaction: transaction,
                  )
                  as CommitDurable;
          written.add(d.slot);
          generation = d.generation;
          transaction = d.transactionId;

          if (written.length == 1) {
            slotAAfterFirst = (await f.readArtifacts())[ArtifactRole.slotA];
          }
          if (written.length == 2) {
            expect(
              (await f.readArtifacts())[ArtifactRole.slotA],
              slotAAfterFirst,
              reason:
                  'atomicity here is a property of never touching the live '
                  'copy, not of rename semantics',
            );
          }
        }

        expect(written, <SnapshotSlot>[
          SnapshotSlot.a,
          SnapshotSlot.b,
          SnapshotSlot.a,
          SnapshotSlot.b,
        ]);
      });

      test('the highest generation wins on load', () async {
        final PersistenceFixture f = await fixture();
        final SaveRepository repo = _repo(f);
        final GameEngine engine = GameEngine.newGame(registry: registry);

        int generation = -1;
        int transaction = 0;
        for (final int steps in <int>[137, 291, 613]) {
          final EngineResult r = engine.execute(
            GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
          );
          final CommitDurable d =
              await _commit(
                    repo,
                    after: engine.state,
                    events: r.events,
                    generation: generation,
                    lastTransaction: transaction,
                  )
                  as CommitDurable;
          generation = d.generation;
          transaction = d.transactionId;
        }

        // A fresh repository over the same durable bytes.
        final LoadOutcome outcome = await _repo(f).load(registry: registry);

        expect(outcome, isA<SaveLoaded>());
        final SaveLoaded loaded = outcome as SaveLoaded;
        expect(loaded.state.steps.totalGranted, 1041);
        expect(loaded.generation, 2);
        expect(loaded.replayedTransactions, 0);
        expect(_diagnoses(loaded.repairs), <SaveDiagnosis>[]);
      });

      test('no artifacts at all is the only new-game path', () async {
        final PersistenceFixture f = await fixture();
        expect(await _repo(f).load(registry: registry), isA<NoSaveFound>());
      });
    });

    // --- compare-and-swap -------------------------------------------------

    group('compare-and-swap', () {
      test('a stale expectation is refused and nothing is written', () async {
        final PersistenceFixture f = await fixture();
        final SaveRepository repo = _repo(f);
        final GameEngine engine = GameEngine.newGame(registry: registry);

        final EngineResult first = engine.execute(
          const GrantSyntheticSteps(steps: _first, reason: 'first'),
        );
        await _commit(
          repo,
          after: engine.state,
          events: first.events,
          generation: -1,
          lastTransaction: 0,
        );

        final String before = await durableImage(f);
        expect(before, isNotEmpty, reason: 'the fixture must be on the medium');

        final EngineResult second = engine.execute(
          const GrantSyntheticSteps(steps: _secondGrant, reason: 'stale'),
        );
        final CommitOutcome outcome = await _commit(
          repo,
          after: engine.state,
          events: second.events,
          generation: -1,
          lastTransaction: 0,
        );

        expect(outcome, isA<CommitRefused>());
        expect(
          (outcome as CommitRefused).reason,
          CommitRefusal.conflictRetryLimitExhausted,
        );
        expect(
          await durableImage(f),
          before,
          reason: 'a refused commit must not write anything at all',
        );
      });

      test('the retry budget is bounded and refuses in a typed way', () async {
        final PersistenceFixture f = await fixture();
        final GameEngine engine = GameEngine.newGame(registry: registry);
        final EngineResult first = engine.execute(
          const GrantSyntheticSteps(steps: _first, reason: 'baseline'),
        );
        await _commit(
          _repo(f),
          after: engine.state,
          events: first.events,
          generation: -1,
          lastTransaction: 0,
        );

        // One retry. An unbounded loop against a writer that never yields is a
        // hang, and a hang during a step sync looks to the player exactly like
        // the game losing their walk.
        final SaveRepository bounded = _repo(f, maxCommitRetries: 1);
        final String before = await durableImage(f);

        final EngineResult batch = engine.execute(
          const GrantSyntheticSteps(steps: _secondGrant, reason: 'doomed'),
        );
        final CommitOutcome outcome = await _commit(
          bounded,
          after: engine.state,
          events: batch.events,
          generation: 4,
          lastTransaction: 9,
        );

        expect(outcome, isA<CommitRefused>());
        final CommitRefused refused = outcome as CommitRefused;
        expect(refused.reason, CommitRefusal.conflictRetryLimitExhausted);
        expect(refused.detail, contains('reload'));
        expect(await durableImage(f), before);
      });

      test(
        'a reload after a conflict lets the retry land exactly once',
        () async {
          final PersistenceFixture f = await fixture();
          final SaveRepository repo = _repo(f);
          final GameEngine engine = GameEngine.newGame(registry: registry);

          final EngineResult first = engine.execute(
            const GrantSyntheticSteps(steps: _first, reason: 'baseline'),
          );
          await _commit(
            repo,
            after: engine.state,
            events: first.events,
            generation: -1,
            lastTransaction: 0,
          );

          // A stale writer, refused.
          final GameEngine stale = GameEngine.newGame(registry: registry);
          final EngineResult attempt = stale.execute(
            const GrantSyntheticSteps(steps: _secondGrant, reason: 'stale'),
          );
          expect(
            await _commit(
              repo,
              after: stale.state,
              events: attempt.events,
              generation: -1,
              lastTransaction: 0,
            ),
            isA<CommitRefused>(),
          );

          // The prescribed recovery: reload, reconcile against the newer state,
          // try again.
          final SaveLoaded fresh =
              await repo.load(registry: registry) as SaveLoaded;
          expect(fresh.state.steps.totalGranted, _first);

          final GameEngine resumed = GameEngine(
            registry: registry,
            state: fresh.state,
          );
          final EngineResult grant = resumed.execute(
            const GrantSyntheticSteps(steps: _secondGrant, reason: 'retry'),
          );
          final EngineResult spend = resumed.execute(
            const AllocateSteps(steps: _secondSpend),
          );
          final CommitOutcome landed = await _commit(
            repo,
            after: resumed.state,
            events: <GameEvent>[...grant.events, ...spend.events],
            generation: fresh.generation,
            lastTransaction: fresh.lastAppliedTransaction,
          );

          expect(landed, isA<CommitDurable>());
          expect((landed as CommitDurable).transactionId, 2);

          final SaveLoaded reloaded =
              await _repo(f).load(registry: registry) as SaveLoaded;
          expect(reloaded.state.steps.totalGranted, _grantedAfterBoth);
          expect(
            reloaded.state.steps.totalSpent,
            _secondSpend,
            reason: 'a re-applied retry would read 274 here, not 137',
          );
        },
      );
    });

    // --- replay -----------------------------------------------------------

    group('journal replay', () {
      test('a snapshot behind the journal is caught up exactly once', () async {
        final PersistenceFixture f = await fixture();
        final GameEngine engine = GameEngine.newGame(registry: registry);
        final GameState genesis = engine.state;

        final EngineResult one = engine.execute(
          const GrantSyntheticSteps(steps: _secondGrant, reason: 'tx1'),
        );
        final GameState afterOne = engine.state;
        final EngineResult twoGrant = engine.execute(
          const GrantSyntheticSteps(steps: _first, reason: 'tx2'),
        );
        // A spend, so replay is observable. Step reconciliation is idempotent
        // by construction, so `totalGranted` alone cannot tell "once" from
        // "four times"; `totalSpent` can.
        final EngineResult twoSpend = engine.execute(
          const AllocateSteps(steps: _secondSpend),
        );

        await f.snapshots.write(
          SnapshotSlot.a,
          encodeSnapshot(
            state: genesis,
            saveId: conformanceSaveId,
            generation: 0,
            lastAppliedTransaction: 0,
            originSaltFingerprint: null,
          ),
        );
        await f.journal.appendLine(
          encodeJournalLine(
            JournalRecord(
              formatVersion: SaveFormatVersion.current,
              saveId: conformanceSaveId,
              transactionId: 1,
              eventSequenceBefore: genesis.eventSequence,
              eventSequenceAfter: afterOne.eventSequence,
              events: one.events,
            ),
          ),
        );
        await f.journal.appendLine(
          encodeJournalLine(
            JournalRecord(
              formatVersion: SaveFormatVersion.current,
              saveId: conformanceSaveId,
              transactionId: 2,
              eventSequenceBefore: afterOne.eventSequence,
              eventSequenceAfter: engine.state.eventSequence,
              events: <GameEvent>[...twoGrant.events, ...twoSpend.events],
            ),
          ),
        );

        final LoadOutcome outcome = await _repo(f).load(registry: registry);

        expect(outcome, isA<SaveLoaded>());
        final SaveLoaded loaded = outcome as SaveLoaded;
        expect(loaded.state.steps.totalGranted, _grantedAfterBoth);
        expect(loaded.state.steps.totalSpent, _secondSpend);
        expect(loaded.replayedTransactions, 2);
        expect(loaded.lastAppliedTransaction, 2);
        expect(_diagnoses(loaded.repairs), <SaveDiagnosis>[
          SaveDiagnosis.snapshotOlderThanJournal,
        ]);
      });

      test('a torn tail is returned as a line, not swallowed', () async {
        final PersistenceFixture f = await fixture();
        final GameEngine engine = GameEngine.newGame(registry: registry);
        final GameState genesis = engine.state;
        final EngineResult one = engine.execute(
          const GrantSyntheticSteps(steps: _secondGrant, reason: 'tx1'),
        );

        final Uint8List complete = encodeJournalLine(
          JournalRecord(
            formatVersion: SaveFormatVersion.current,
            saveId: conformanceSaveId,
            transactionId: 1,
            eventSequenceBefore: genesis.eventSequence,
            eventSequenceAfter: engine.state.eventSequence,
            events: one.events,
          ),
        );
        await f.journal.appendLine(complete);
        // A second append cut short: the process died mid-write.
        await f.journal.appendLine(
          Uint8List.sublistView(complete, 0, complete.length ~/ 2),
        );

        final List<Uint8List> lines = await f.journal.readLines();
        expect(
          lines,
          hasLength(2),
          reason:
              'an adapter that swallowed the unterminated fragment would hide '
              'the one condition readLines exists to surface',
        );
        expect(lines.first.last, 0x0A);
        expect(lines.last.last, isNot(0x0A));
      });

      test('an interrupted compaction is discarded, never adopted', () async {
        final PersistenceFixture f = await fixture();

        expect(await f.journal.discardIncompleteCompaction(), isFalse);

        await f.journal.appendLine(
          Uint8List.fromList(utf8.encode('{"not":"a record"}\n')),
        );
        // replaceLines writes the sidecar first, so a completed compaction must
        // leave none behind.
        await f.journal.replaceLines(<Uint8List>[]);
        expect(
          await f.journal.discardIncompleteCompaction(),
          isFalse,
          reason: 'a completed compaction must not leave a sidecar behind',
        );
        expect(await f.journal.readLines(), isEmpty);
      });
    });

    // --- damage -----------------------------------------------------------

    group('damage', () {
      test(
        'a bit flip that still parses as JSON is caught by the digest',
        () async {
          final PersistenceFixture f = await fixture();

          final Uint8List healthy = _snapshotOf(registry, 1000);
          final String text = utf8.decode(healthy);
          expect(text, contains('"totalGranted":1000'));

          final String tampered = text.replaceFirst(
            '"totalGranted":1000',
            '"totalGranted":4000',
          );
          final Uint8List bytes = Uint8List.fromList(utf8.encode(tampered));
          expect(
            bytes.length,
            healthy.length,
            reason:
                'the tamper must not change the length, or this is a truncation '
                'test wearing an integrity test as a disguise',
          );

          // Proof the payload really does still parse — otherwise the parser,
          // not the digest, is what rejected it.
          final Map<String, Object?> stillParses =
              jsonDecode(tampered.substring(tampered.indexOf('\n') + 1))
                  as Map<String, Object?>;
          expect(
            ((stillParses['state']! as Map<String, Object?>)['steps']!
                as Map<String, Object?>)['totalGranted'],
            4000,
            reason: 'the corrupted payload must still be valid, plausible JSON',
          );
          expect(unframe(bytes).fault, FrameFault.integrityMismatch);

          await f.snapshots.write(SnapshotSlot.a, bytes);
          final LoadOutcome outcome = await _repo(f).load(registry: registry);

          expect(
            outcome,
            isNot(isA<SaveLoaded>()),
            reason: 'a silently accepted 4000 is 3000 fabricated steps',
          );
          expect(outcome, isA<LoadRefused>());
          final LoadRefused refused = outcome as LoadRefused;
          expect(refused.reason, LoadRefusal.allSlotsUnreadable);
          expect(
            _diagnoses(refused.repairs),
            contains(SaveDiagnosis.slotIntegrityMismatch),
          );
        },
      );

      test('a short file is diagnosed as truncated, not as corrupt', () async {
        final PersistenceFixture f = await fixture();
        final Uint8List healthy = _snapshotOf(registry, _first);

        await f.snapshots.write(
          SnapshotSlot.a,
          Uint8List.sublistView(healthy, 0, healthy.length - 20),
        );

        // The adapter must hand back the partial file exactly as found; an
        // adapter that decided a short file was "empty" would hide the one
        // condition this read exists to surface.
        final Uint8List? readBack = await f.snapshots.read(SnapshotSlot.a);
        expect(readBack, isNotNull);
        expect(readBack, hasLength(healthy.length - 20));

        final LoadOutcome outcome = await _repo(f).load(registry: registry);

        expect(outcome, isA<LoadRefused>());
        final List<SaveDiagnosis> found = _diagnoses(
          (outcome as LoadRefused).repairs,
        );
        expect(found, contains(SaveDiagnosis.slotTruncated));
        expect(
          found,
          isNot(contains(SaveDiagnosis.slotIntegrityMismatch)),
          reason: 'truncation and corruption have different causes and fixes',
        );
        expect(found, isNot(contains(SaveDiagnosis.slotMalformedEncoding)));
      });

      test(
        'a truncated newest slot falls back and is never a fresh game',
        () async {
          final PersistenceFixture f = await fixture();
          final Uint8List newer = _snapshotOf(
            registry,
            1041,
            generation: 1,
            lastTransaction: 2,
          );
          await f.snapshots.write(
            SnapshotSlot.a,
            Uint8List.sublistView(newer, 0, newer.length - 20),
          );
          await f.snapshots.write(
            SnapshotSlot.b,
            _snapshotOf(registry, _first),
          );

          final LoadOutcome outcome = await _repo(f).load(registry: registry);

          expect(
            outcome,
            isA<SaveLoaded>(),
            reason: 'a wiped newest slot must never present as a new character',
          );
          final SaveLoaded loaded = outcome as SaveLoaded;
          expect(loaded.fromSlot, SnapshotSlot.b);
          expect(loaded.state.steps.totalGranted, _first);
          expect(loaded.state.steps.totalGranted, isNot(0));
          expect(loaded.degraded, isTrue);
          expect(
            _diagnoses(loaded.repairs),
            contains(SaveDiagnosis.slotTruncated),
          );
        },
      );

      test(
        'an empty slot file with a journal refuses rather than reporting a new game',
        () async {
          final PersistenceFixture f = await fixture();
          await f.snapshots.write(SnapshotSlot.a, Uint8List(0));
          await f.journal.appendLine(
            Uint8List.fromList(utf8.encode('{"torn":true}\n')),
          );

          final LoadOutcome outcome = await _repo(f).load(registry: registry);

          expect(outcome, isNot(isA<NoSaveFound>()));
          expect(outcome, isA<LoadRefused>());
          expect(
            (outcome as LoadRefused).reason,
            LoadRefusal.allSlotsUnreadable,
          );
        },
      );

      test(
        'divergent slots at one generation fail closed and delete nothing',
        () async {
          final PersistenceFixture f = await fixture();

          await f.snapshots.write(
            SnapshotSlot.a,
            _snapshotOf(registry, _first, generation: 4, lastTransaction: 7),
          );
          await f.snapshots.write(
            SnapshotSlot.b,
            _snapshotOf(
              registry,
              _grantedAfterBoth,
              generation: 4,
              lastTransaction: 9,
            ),
          );

          final String before = await durableImage(f);
          final LoadOutcome outcome = await _repo(f).load(registry: registry);

          expect(outcome, isA<LoadRefused>());
          final LoadRefused refused = outcome as LoadRefused;
          expect(refused.reason, LoadRefusal.divergentSlotsAtSameGeneration);
          expect(
            _diagnoses(refused.repairs),
            contains(SaveDiagnosis.slotGenerationTie),
          );
          expect(
            await durableImage(f),
            before,
            reason:
                'a refusal must leave the human recovery path intact — deleting '
                'either slot turns a recoverable situation into permanent loss',
          );
        },
      );
    });

    // --- identity and the origin salt -------------------------------------

    group('reconciliation identity', () {
      test(
        'absence is not an error, and a seeded identity round-trips',
        () async {
          final PersistenceFixture f = await fixture();

          expect(
            await f.identity.read(),
            isNull,
            reason: 'absence means "new installation", which is legitimate',
          );

          await f.seedIdentity(conformanceSaveId, conformanceSalt);

          final ReconciliationIdentity? read = await f.identity.read();
          expect(read, isNotNull);
          expect(read!.saveId, conformanceSaveId);
          expect(
            read.saltFingerprint,
            OriginSaltPolicy.fingerprint(conformanceSalt),
            reason:
                'the core must receive a fingerprint, and the same salt must '
                'fingerprint identically on every implementation',
          );

          await f.identity.erase();
          expect(await f.identity.read(), isNull);
        },
      );

      test(
        'the port write round-trips when no salt is on the medium',
        () async {
          // `write` is part of the port contract. An adapter that throws where
          // the contract says it writes is a Liskov violation, and the caller
          // that trusted the interface finds out in the field.
          final PersistenceFixture f = await fixture();
          const ReconciliationIdentity identity = ReconciliationIdentity(
            saveId: conformanceSaveId,
            saltFingerprint: 'aaaaaaaaaaaaaaaa',
          );

          await f.identity.write(identity);

          expect(await f.identity.read(), identity);
        },
      );

      test(
        'a port write preserves salt material already on the medium',
        () async {
          // The core only ever holds a fingerprint. If writing one dropped the
          // salt beside it, the next launch would re-key every origin and grant
          // the whole live retention window a second time — the exact failure the
          // fail-closed salt check exists to prevent, caused by the safeguard's
          // own bookkeeping.
          final PersistenceFixture f = await fixture();
          await f.seedIdentity(conformanceSaveId, conformanceSalt);
          final String derived = OriginSaltPolicy.fingerprint(conformanceSalt);

          await f.identity.write(
            ReconciliationIdentity(
              saveId: 'save-relineaged-0002',
              saltFingerprint: derived,
            ),
          );

          final ReconciliationIdentity? after = await f.identity.read();
          expect(after, isNotNull);
          expect(after!.saveId, 'save-relineaged-0002');
          expect(after.saltFingerprint, derived);
          expect(
            utf8.decode(
              (await f.readArtifacts())[ArtifactRole.identity]!,
              allowMalformed: true,
            ),
            contains(base64Encode(conformanceSalt)),
            reason: 'the salt must survive a core-supplied write',
          );
        },
      );

      test('a changed salt fingerprint fails closed', () async {
        final PersistenceFixture f = await fixture();
        await f.snapshots.write(
          SnapshotSlot.a,
          _snapshotOf(
            registry,
            _first,
            originSaltFingerprint: 'aaaaaaaaaaaaaaaa',
          ),
        );

        final LoadOutcome outcome = await _repo(
          f,
        ).load(registry: registry, originSaltFingerprint: 'bbbbbbbbbbbbbbbb');

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.originKeyReset);
        // Both fingerprints are derived from health-source identity, and this
        // string reaches a diagnostic surface.
        expect(refused.explanation, isNot(contains('aaaaaaaaaaaaaaaa')));
        expect(refused.explanation, isNot(contains('bbbbbbbbbbbbbbbb')));
        expect(refused.explanation, contains('Reconnect health'));
      });

      test('a matching salt fingerprint loads normally', () async {
        final PersistenceFixture f = await fixture();
        await f.snapshots.write(
          SnapshotSlot.a,
          _snapshotOf(
            registry,
            _first,
            originSaltFingerprint: 'aaaaaaaaaaaaaaaa',
          ),
        );

        final LoadOutcome outcome = await _repo(
          f,
        ).load(registry: registry, originSaltFingerprint: 'aaaaaaaaaaaaaaaa');

        expect(outcome, isA<SaveLoaded>());
        expect((outcome as SaveLoaded).state.steps.totalGranted, _first);
      });

      test(
        'a save committed under one salt refuses to load under another',
        () async {
          // The end-to-end version of the two tests above: not a hand-seeded
          // snapshot, but a save the protocol itself wrote. This is the case
          // that matters, because it is the only one a player can own.
          //
          // A lost or rotated salt re-keys every origin, so the live retention
          // window looks ungranted and would be granted a second time.
          // `totalGranted` is origin-independent, so nothing downstream would
          // ever detect it — hence fail closed.
          final PersistenceFixture f = await fixture();
          final GameEngine engine = GameEngine.newGame(registry: registry);
          final EngineResult r = engine.execute(
            ReconcileStepSync(
              response: _incremental(<StepObservation>[
                _obs(conformancePhone, 0, _first),
              ], next: 'c1'),
            ),
          );
          final String fingerprint = OriginSaltPolicy.fingerprint(
            conformanceSalt,
          );
          expect(
            await _commit(
              _repo(f),
              after: engine.state,
              events: r.events,
              generation: -1,
              lastTransaction: 0,
              originSaltFingerprint: fingerprint,
            ),
            isA<CommitDurable>(),
          );

          // The fingerprint must actually have reached the bytes, or the
          // refusal below would be proving nothing.
          expect(
            utf8.decode(
              (await f.readArtifacts())[ArtifactRole.slotA]!,
              allowMalformed: true,
            ),
            contains(fingerprint),
          );

          final LoadOutcome refused = await _repo(
            f,
          ).load(registry: registry, originSaltFingerprint: 'bbbbbbbbbbbbbbbb');
          expect(refused, isA<LoadRefused>());
          expect((refused as LoadRefused).reason, LoadRefusal.originKeyReset);

          final LoadOutcome accepted = await _repo(
            f,
          ).load(registry: registry, originSaltFingerprint: fingerprint);
          expect(accepted, isA<SaveLoaded>());
          expect((accepted as SaveLoaded).state.steps.totalGranted, _first);
        },
      );
    });

    // --- balance profile authority ----------------------------------------

    group('balance profile', () {
      Uint8List withProfile(String profileId) => _remake(
        _snapshotOf(registry, _first),
        (Map<String, Object?> envelope, Map<String, Object?> state) {
          envelope['balanceProfileId'] = profileId;
          state['profileId'] = profileId;
        },
      );

      test('an unknown profile is refused', () async {
        final PersistenceFixture f = await fixture();
        await f.snapshots.write(
          SnapshotSlot.a,
          withProfile('profile.homebrew'),
        );

        final LoadOutcome outcome = await _repo(f).load(registry: registry);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.unknownProfile);
        expect(refused.explanation, contains('profile.homebrew'));
      });

      test('a profile the app is not running requires a migration', () async {
        // Reinterpreting QA pacing as production pacing silently changes what
        // every number in the save means.
        final PersistenceFixture f = await fixture();
        await f.snapshots.write(
          SnapshotSlot.a,
          withProfile('profile.accelerated_qa'),
        );

        final LoadOutcome outcome = await _repo(f).load(registry: registry);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.profileMigrationRequired);
        expect(refused.explanation, contains('profile.accelerated_qa'));
        expect(refused.explanation, contains('profile.production'));
      });

      test('an accelerated QA save is refused by a release build', () async {
        final PersistenceFixture f = await fixture();
        await f.snapshots.write(
          SnapshotSlot.a,
          withProfile('profile.accelerated_qa'),
        );

        final LoadOutcome outcome = await _repo(
          f,
        ).load(registry: registry, treatAsRelease: true);

        expect(outcome, isA<LoadRefused>());
        expect(
          (outcome as LoadRefused).reason,
          LoadRefusal.qaProfileForbiddenInRelease,
        );
      });
    });

    // --- watermarks and retention -----------------------------------------

    group('per-origin watermarks and retention', () {
      /// Fourteen days of walking, committed one day at a time.
      ///
      /// Long enough that compaction must occur, which is the point: the
      /// watermark map is the only durable record that a settled bucket was
      /// already granted, once the journal record carrying it has been removed.
      Future<GameEngine> walkAFortnight(PersistenceFixture f) async {
        final SaveRepository repo = _repo(f);
        final GameEngine engine = GameEngine.newGame(registry: registry);
        int generation = -1;
        int transaction = 0;

        for (int day = 0; day < 14; day++) {
          final EngineResult r = engine.execute(
            ReconcileStepSync(
              response: _incremental(
                <StepObservation>[_obs(conformancePhone, day * 24, 1000)],
                next: 'd$day',
                completeThroughIndex: day * 24 + 1,
              ),
            ),
          );
          final CommitDurable d =
              await _commit(
                    repo,
                    after: engine.state,
                    events: r.events,
                    generation: generation,
                    lastTransaction: transaction,
                  )
                  as CommitDurable;
          generation = d.generation;
          transaction = d.transactionId;
        }
        return engine;
      }

      test(
        'a settled origin stays settled across a reload from bytes alone',
        () async {
          final PersistenceFixture f = await fixture();
          final GameEngine engine = await walkAFortnight(f);

          final Map<StepOriginKey, int> before =
              engine.state.steps.checkpoint.originWatermarks;
          expect(
            before,
            isNotEmpty,
            reason: 'the fixture must actually settle something',
          );
          expect(engine.state.steps.totalGranted, 14000);

          // The journal must genuinely have been compacted, or this test proves
          // only that replay works and the watermark map is redundant.
          expect(
            (await f.journal.readLines()).length,
            lessThan(14),
            reason:
                'without compaction the journal is a permanent unbounded step '
                'history, and the watermark map is not load-bearing',
          );

          final LoadOutcome outcome = await _repo(f).load(registry: registry);
          expect(outcome, isA<SaveLoaded>());
          final SaveLoaded loaded = outcome as SaveLoaded;

          expect(
            loaded.state.steps.checkpoint.originWatermarks,
            before,
            reason:
                'a dropped watermark map re-grants the whole retention window',
          );
          expect(loaded.state.steps.totalGranted, 14000);

          // The proof that matters: replay an already-settled bucket after the
          // reload and confirm it grants nothing.
          final GameEngine resumed = GameEngine(
            registry: registry,
            state: loaded.state,
          );
          final EngineResult replay = resumed.execute(
            ReconcileStepSync(
              response: _incremental(<StepObservation>[
                _obs(conformancePhone, 0, 1000),
              ], next: 'again'),
            ),
          );
          expect(
            _grantedBy(replay),
            0,
            reason: 'a settled bucket must grant zero on replay',
          );
          expect(resumed.state.steps.totalGranted, 14000);
        },
      );

      test(
        'the journal does not accumulate an unbounded step history',
        () async {
          final PersistenceFixture f = await fixture();
          await walkAFortnight(f);

          // Every reconciliation record carries a full granted-slice map, so an
          // uncompacted journal is exactly the permanent step history the
          // retention ruling bounds, reintroduced through the back door.
          expect(
            (await f.journal.readLines()).length,
            lessThanOrEqualTo(2),
            reason: 'compaction is a privacy control with a hard obligation',
          );
        },
      );

      test('no health-source identifier reaches the durable bytes', () async {
        final PersistenceFixture f = await fixture();
        await walkAFortnight(f);
        await f.seedIdentity(conformanceSaveId, conformanceSalt);

        final Map<String, Uint8List> artifacts = await f.readArtifacts();
        expect(artifacts, isNotEmpty);

        String textOf(String role) =>
            utf8.decode(artifacts[role] ?? Uint8List(0), allowMalformed: true);

        final String saveText = ArtifactRole.saveArtifacts
            .map(textOf)
            .join('\n');
        final String allText = artifacts.values
            .map((Uint8List b) => utf8.decode(b, allowMalformed: true))
            .join('\n');

        // Positive control. Without it this test would pass just as happily
        // against an empty string.
        expect(
          saveText,
          contains('grantedSlices'),
          reason: 'the scan must be looking at real save bytes',
        );

        for (final String forbidden in <String>[
          'HKSource',
          'sampleId',
          'HKQuantityTypeIdentifier',
          'com.apple.health',
          'deviceName',
          'sourceRevision',
          'Health Connect',
          'iPhone',
          'Apple Watch',
          'Pixel',
        ]) {
          expect(
            allText,
            isNot(contains(forbidden)),
            reason: '"$forbidden" must never reach a durable artifact',
          );
        }

        // Anything shaped like a human-named device. A literal space rather
        // than \s, so the join between artifacts cannot manufacture a match.
        expect(
          RegExp("[A-Z][a-z]+['’]?s +[A-Za-z]+").hasMatch(allText),
          isFalse,
          reason: 'a device-name-shaped string reached the durable bytes',
        );

        // The salt lives in the identity artifact by design — it is what the
        // save's origin keys are validated against. It must not reach the save.
        expect(
          textOf(ArtifactRole.identity),
          contains(base64Encode(conformanceSalt)),
          reason: 'the identity fixture must actually hold a salt',
        );
        expect(
          saveText,
          isNot(contains(base64Encode(conformanceSalt))),
          reason:
              'a reader holding the salt could re-derive every origin mapping '
              'the save contains',
        );

        // Every persisted origin must be a pseudonym, not a platform id.
        final List<String> origins = RegExp(
          r'"o":"([^"]*)"',
        ).allMatches(saveText).map((RegExpMatch m) => m.group(1)!).toList();
        expect(
          origins,
          isNotEmpty,
          reason: 'the fixture must have persisted at least one origin',
        );
        for (final String origin in origins) {
          expect(
            RegExp(r'^[0-9a-f]{16}$').hasMatch(origin),
            isTrue,
            reason: 'origin "$origin" is not a pseudonymous key',
          );
        }
      });
    });

    // --- reset ------------------------------------------------------------

    test('eraseAll removes every save artifact', () async {
      final PersistenceFixture f = await fixture();
      final SaveRepository repo = _repo(f);
      final GameEngine engine = GameEngine.newGame(registry: registry);
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: _first, reason: 'to be erased'),
      );
      await _commit(
        repo,
        after: engine.state,
        events: r.events,
        generation: -1,
        lastTransaction: 0,
      );
      expect(await durableImage(f), isNotEmpty);

      await repo.eraseAll();

      expect(await f.snapshots.read(SnapshotSlot.a), isNull);
      expect(await f.snapshots.read(SnapshotSlot.b), isNull);
      expect(await f.journal.readLines(), isEmpty);
      expect(await _repo(f).load(registry: registry), isA<NoSaveFound>());
    });

    // --- equivalence ------------------------------------------------------

    test('the observable transcript matches the frozen expectation', () async {
      final PersistenceFixture f = await fixture();
      expect(
        await runPersistenceScript(f, registry),
        expectedPersistenceTranscript,
        reason:
            'every implementation must produce the same outcomes AND the same '
            'durable bytes for the same operation sequence',
      );
    });
  });
}
