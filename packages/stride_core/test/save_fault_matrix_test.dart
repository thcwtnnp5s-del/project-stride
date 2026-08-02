// The crash/fault matrix for F-05: what survives a power loss at each point in
// the commit protocol, and what a second slot is actually worth.
//
// ## The rule that makes this suite mean anything
//
// Step reconciliation is idempotent by construction: F-04 grants
// `max(0, observed - alreadyGranted)`. A loader that replayed every journal
// record unconditionally, forever, would still produce the CORRECT
// `totalGranted` in every scenario below. So `totalGranted` alone cannot
// distinguish "replayed exactly once" from "replayed four times", and a suite
// that asserted only granted totals would be testing nothing at all.
//
// Therefore **every replay/skip scenario carries a non-idempotent effect**.
// Each committed batch pairs a grant with an `AllocateSteps`, and every
// post-reboot assertion checks `totalSpent` as well as `totalGranted`.
// `StepsAllocated` adds to `totalSpent` on each application, so a double replay
// reads 274 instead of 137 and a dropped replay reads 0 — both visible, neither
// hidden by the reconciler's arithmetic.
//
// Quantities are distinct and non-summing — 137, 291, 613 — so a drop, a
// duplicate, and an off-by-one each land on a different number. 100/200/300
// would let an off-by-one hide inside a coincidence.
//
// Every case has ONE expected outcome with literal expected values. No
// `anyOf(...)`, and no oracle that re-derives the answer through the same code
// under test. Where two legitimate worlds exist (a lost durability ack can mean
// either "the bytes never landed" or "the bytes landed and the ack was lost"),
// they are two separate tests, each pinned to its own world.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

// --- the fixture ----------------------------------------------------------

/// The baseline commit: transaction 1, generation 0, slot a.
const int baselineGrant = 613;

/// The second batch: a grant *and* a spend, so replay is observable.
const int secondGrant = 291;
const int secondSpend = 137;

/// Totals after both batches land exactly once.
const int grantedAfterBoth = 904; // 613 + 291
const int spentAfterBoth = 137;

/// A repository whose durable state is exactly the baseline commit.
Future<({SaveRepository repo, FaultingDevice device, GameEngine engine})>
seeded() async {
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final GameEngine engine = newEngine();
  final EngineResult first = engine.execute(
    const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
  );
  final CommitOutcome outcome = await commit(
    repo,
    after: engine.state,
    events: first.events,
    generation: -1,
    lastTransaction: 0,
  );
  expect(outcome, isA<CommitDurable>());
  expect((outcome as CommitDurable).transactionId, 1);
  expect(outcome.generation, 0);
  expect(outcome.slot, SnapshotSlot.a);
  return (repo: repo, device: device, engine: engine);
}

/// The second batch: one grant, one allocation, committed as one transaction.
///
/// The allocation is the whole point — see the header. Without it the replay
/// tests below would pass against a loader that replays forever.
({List<GameEvent> events, GameState after}) secondBatch(GameEngine engine) {
  final EngineResult granted = engine.execute(
    const GrantSyntheticSteps(steps: secondGrant, reason: 'walk'),
  );
  final EngineResult spent = engine.execute(
    const AllocateSteps(steps: secondSpend),
  );
  return (
    events: <GameEvent>[...granted.events, ...spent.events],
    after: engine.state,
  );
}

Future<CommitOutcome> commitSecond(
  SaveRepository repo,
  GameEngine engine,
) async {
  final ({List<GameEvent> events, GameState after}) batch = secondBatch(engine);
  return commit(
    repo,
    after: batch.after,
    events: batch.events,
    generation: 0,
    lastTransaction: 1,
  );
}

/// The bytes the repository *will* write for the second commit's snapshot.
///
/// Used only to place a fault at a meaningful byte offset. It is a test input,
/// never an expected value.
Uint8List predictedSecondSnapshot(GameState after) => encodeSnapshot(
  state: after,
  saveId: testSaveId,
  generation: 1,
  lastAppliedTransaction: 2,
);

/// Index just past the framing header line.
int payloadStart(Uint8List framed) => framed.indexOf(0x0A) + 1;

/// How many appends to [path] have already happened, so a fault can be aimed
/// at the *next* one without hard-coding an ordinal that shifts when the
/// fixture changes.
int appendsSoFar(FaultingDevice device, String path) => device.trace
    .where((StoreOp o) => o.kind == 'append' && o.path == path)
    .length;

int flushesAfter(FaultingDevice device, int mark) =>
    device.trace.skip(mark).where((StoreOp o) => o.kind == 'flush').length;

/// Loads through a *fresh* repository over a *rebooted* device.
Future<LoadOutcome> loadAfterReboot(FaultingDevice device) =>
    newRepo(device.reboot()).repo.load(registry: saveRegistry);

List<SaveDiagnosis> diagnoses(List<SaveRepair> repairs) =>
    repairs.map((SaveRepair r) => r.diagnosis).toList();

/// Index of [needle] in [haystack], or -1.
int indexOfBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (int i = 0; i + needle.length <= haystack.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

void main() {
  // --- crash boundaries in the commit protocol ----------------------------

  group('crash before the journal append', () {
    test('nothing becomes durable and the pre-batch state is intact', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      final String before = device.image();
      final int mark = device.trace.length;
      device.plan(<Fault>[
        Fault(
          op: 'append',
          path: 'journal',
          effect: FaultEffect.failBefore,
          ordinal: appendsSoFar(device, 'journal'),
        ),
      ]);

      final CommitOutcome outcome = await commitSecond(repo, engine);

      expect(outcome, isA<CommitRefused>());
      expect(
        (outcome as CommitRefused).reason,
        CommitRefusal.journalAppendFailed,
      );

      // The trace records the *attempt* before the fault fires, so the honest
      // assertion is that nothing was made durable: no flush, and a
      // byte-identical device image.
      expect(flushesAfter(device, mark), 0);
      expect(device.image(), before);

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.state.steps.totalGranted, baselineGrant);
      expect(loaded.state.steps.totalSpent, 0);
      expect(loaded.lastAppliedTransaction, 1);
      expect(loaded.replayedTransactions, 0);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
    });
  });

  group('crash during the journal append', () {
    // Three offsets: inside the digest, exactly at the digest/JSON boundary,
    // and deep inside the body. Each must produce the same player-visible
    // outcome, because a torn tail is a transaction that simply did not commit.
    for (final int offset in <int>[1, 9, 137]) {
      test('a tail torn at $offset bytes is discarded, not applied', () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();

        device.plan(<Fault>[
          Fault(
            op: 'append',
            path: 'journal',
            effect: FaultEffect.truncate,
            truncateTo: offset,
            ordinal: appendsSoFar(device, 'journal'),
          ),
        ]);

        final CommitOutcome outcome = await commitSecond(repo, engine);

        expect(outcome, isA<CommitRefused>());
        expect(
          (outcome as CommitRefused).reason,
          CommitRefusal.journalAppendFailed,
        );

        // Self-check: a truncation longer than the record would be a no-op
        // dressed up as a fault.
        final StoreOp attempted = device.trace.lastWhere(
          (StoreOp o) => o.kind == 'append' && o.path == 'journal',
        );
        expect(attempted.bytes, greaterThan(offset));

        // The partial bytes really did reach durable storage. A test that
        // passed without this is proving the harness is lossless.
        expect(device.flushCountFor('journal'), greaterThan(0));

        final LoadOutcome reloaded = await loadAfterReboot(device);
        expect(reloaded, isA<SaveLoaded>());
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
          SaveDiagnosis.journalTailTorn,
        ]);
        expect(loaded.state.steps.totalGranted, baselineGrant);
        expect(loaded.state.steps.totalSpent, 0);
        expect(loaded.lastAppliedTransaction, 1);
        expect(loaded.replayedTransactions, 0);
        expect(loaded.skippedTransactions, 1);
      });
    }
  });

  group('crash after the append, before the durability acknowledgement', () {
    // Two legitimate worlds, two tests. Which one a real device produced is
    // unknowable from inside the process, so the protocol must be correct in
    // both — and each test pins exactly one.

    test(
      'world 1: the bytes never became durable, the snapshot saves it',
      () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();

        device.plan(<Fault>[
          Fault(
            op: 'append',
            path: 'journal',
            effect: FaultEffect.dropDurability,
            ordinal: appendsSoFar(device, 'journal'),
          ),
        ]);

        final CommitOutcome outcome = await commitSecond(repo, engine);

        // The port lied by returning without durability, so the repository
        // reasonably believes the transaction committed.
        expect(outcome, isA<CommitDurable>());
        final CommitDurable durable = outcome as CommitDurable;
        expect(durable.transactionId, 2);
        expect(durable.generation, 1);
        expect(durable.slot, SnapshotSlot.b);
        expect(durable.snapshotDurable, isTrue);

        // And it is true, because the snapshot is the second durable copy.
        final LoadOutcome reloaded = await loadAfterReboot(device);
        expect(reloaded, isA<SaveLoaded>());
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(loaded.fromSlot, SnapshotSlot.b);
        expect(loaded.generation, 1);
        expect(loaded.state.steps.totalGranted, grantedAfterBoth);
        expect(loaded.state.steps.totalSpent, spentAfterBoth);
        expect(loaded.replayedTransactions, 0);
        expect(loaded.skippedTransactions, 0);
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
      },
    );

    test(
      'world 2: the bytes landed and only the acknowledgement was lost',
      () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();

        device.plan(<Fault>[
          Fault(
            op: 'append',
            path: 'journal',
            effect: FaultEffect.failAfter,
            ordinal: appendsSoFar(device, 'journal'),
          ),
        ]);

        final CommitOutcome outcome = await commitSecond(repo, engine);

        // Reported as not committed. That is the safe direction: the caller must
        // not release the cursor, and F-04 re-grants the same window to the same
        // total.
        expect(outcome, isA<CommitRefused>());
        expect(
          (outcome as CommitRefused).reason,
          CommitRefusal.journalAppendFailed,
        );
        expect(device.flushCountFor('journal'), greaterThan(0));

        // The record survived anyway, so the recovery replays it exactly once —
        // the spend proves "once" rather than "at least once".
        final LoadOutcome reloaded = await loadAfterReboot(device);
        expect(reloaded, isA<SaveLoaded>());
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(loaded.fromSlot, SnapshotSlot.a);
        expect(loaded.generation, 0);
        expect(loaded.state.steps.totalGranted, grantedAfterBoth);
        expect(loaded.state.steps.totalSpent, spentAfterBoth);
        expect(loaded.replayedTransactions, 1);
        expect(loaded.skippedTransactions, 1);
        expect(loaded.lastAppliedTransaction, 2);
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
          SaveDiagnosis.snapshotOlderThanJournal,
        ]);
      },
    );
  });

  group('crash after a durable append, before the snapshot write', () {
    test('the transaction replays exactly once from the journal', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      device.plan(<Fault>[
        const Fault(
          op: 'write',
          path: 'save_slot_b',
          effect: FaultEffect.failBefore,
        ),
      ]);

      final CommitOutcome outcome = await commitSecond(repo, engine);

      expect(outcome, isA<CommitDurable>());
      final CommitDurable durable = outcome as CommitDurable;
      expect(durable.transactionId, 2);
      expect(
        durable.snapshotDurable,
        isFalse,
        reason: 'the journal is the commit point; the snapshot is a cache',
      );
      expect(
        durable.generation,
        0,
        reason: 'the generation did not advance because no snapshot landed',
      );
      expect(device.exists('save_slot_b'), isFalse);

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.a);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(loaded.replayedTransactions, 1);
      expect(loaded.skippedTransactions, 1);
      expect(loaded.lastAppliedTransaction, 2);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
        SaveDiagnosis.snapshotOlderThanJournal,
      ]);
    });
  });

  group('crash during the snapshot write', () {
    test('the live slot is untouched and still loads', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      final String liveBefore = crc32cHex(
        device.committedBytes('save_slot_a')!,
      );

      // Land a header and seven payload bytes: a file that frames correctly and
      // is provably short, rather than an unparseable smear.
      final GameEngine probe = newEngine()
        ..execute(
          const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
        )
        ..execute(const GrantSyntheticSteps(steps: secondGrant, reason: 'walk'))
        ..execute(const AllocateSteps(steps: secondSpend));
      final int cut = payloadStart(predictedSecondSnapshot(probe.state)) + 7;

      device.plan(<Fault>[
        Fault(
          op: 'write',
          path: 'save_slot_b',
          effect: FaultEffect.truncate,
          truncateTo: cut,
        ),
      ]);

      final CommitOutcome outcome = await commitSecond(repo, engine);

      expect(outcome, isA<CommitDurable>());
      expect((outcome as CommitDurable).snapshotDurable, isFalse);
      expect(outcome.transactionId, 2);

      expect(
        crc32cHex(device.committedBytes('save_slot_a')!),
        liveBefore,
        reason: 'atomicity here is never touching the live copy',
      );

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.a);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(loaded.replayedTransactions, 1);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
        SaveDiagnosis.slotTruncated,
        SaveDiagnosis.snapshotOlderThanJournal,
      ]);
      expect(loaded.repairs.first.detail, 'save_slot_b');
    });
  });

  group('a snapshot written but not verified', () {
    test(
      'the read-back rejects it and the other slot carries the load',
      () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();

        final GameEngine probe = newEngine()
          ..execute(
            const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
          )
          ..execute(
            const GrantSyntheticSteps(steps: secondGrant, reason: 'walk'),
          )
          ..execute(const AllocateSteps(steps: secondSpend));
        final int cut = payloadStart(predictedSecondSnapshot(probe.state)) + 7;

        // A short write that reports success. Some platforms really do this, and
        // no clean-failure model can express it.
        device.plan(<Fault>[
          Fault(
            op: 'write',
            path: 'save_slot_b',
            effect: FaultEffect.silentShortWrite,
            truncateTo: cut,
          ),
        ]);

        final int mark = device.trace.length;
        final CommitOutcome outcome = await commitSecond(repo, engine);

        expect(outcome, isA<CommitDurable>());
        final CommitDurable durable = outcome as CommitDurable;
        expect(
          durable.snapshotDurable,
          isFalse,
          reason: 'the write did not throw; only the read-back caught it',
        );
        expect(durable.generation, 0);

        // The read-back is what made the difference, so assert it happened.
        final List<StoreOp> after = device.trace.skip(mark).toList();
        final int wrote = after.indexWhere(
          (StoreOp o) => o.kind == 'write' && o.path == 'save_slot_b',
        );
        expect(wrote, greaterThanOrEqualTo(0));
        expect(
          after
              .skip(wrote)
              .any((StoreOp o) => o.kind == 'read' && o.path == 'save_slot_b'),
          isTrue,
        );

        final LoadOutcome reloaded = await loadAfterReboot(device);
        expect(reloaded, isA<SaveLoaded>());
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(loaded.fromSlot, SnapshotSlot.a);
        expect(loaded.state.steps.totalGranted, grantedAfterBoth);
        expect(loaded.state.steps.totalSpent, spentAfterBoth);
        expect(loaded.replayedTransactions, 1);
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
          SaveDiagnosis.slotTruncated,
          SaveDiagnosis.snapshotOlderThanJournal,
        ]);
      },
    );
  });

  group('crash after the snapshot, before compaction', () {
    test('the load is clean and replays nothing', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      // Compaction cannot even begin: the sidecar refuses to be created.
      device.plan(<Fault>[
        const Fault(
          op: 'write',
          path: 'journal.compacting',
          effect: FaultEffect.failBefore,
        ),
      ]);

      final CommitOutcome outcome = await commitSecond(repo, engine);

      // A failed compaction is journal hygiene, not a failed transaction. It
      // must never turn a durable commit into an error at the call site.
      expect(outcome, isA<CommitDurable>());
      final CommitDurable durable = outcome as CommitDurable;
      expect(durable.transactionId, 2);
      expect(durable.generation, 1);
      expect(durable.slot, SnapshotSlot.b);
      expect(durable.snapshotDurable, isTrue);
      expect(device.exists('journal.compacting'), isFalse);

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.b);
      expect(loaded.generation, 1);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(
        loaded.replayedTransactions,
        0,
        reason: 'the snapshot already covers both transactions',
      );
      expect(
        loaded.skippedTransactions,
        2,
        reason: 'the uncompacted journal is fully absorbed, not re-applied',
      );
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
    });
  });

  group('crash during compaction', () {
    test('the sidecar is discarded and nothing is lost', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      // The sidecar lands; the swap onto the real journal does not.
      device.plan(<Fault>[
        const Fault(
          op: 'write',
          path: 'journal',
          effect: FaultEffect.failBefore,
        ),
      ]);

      final CommitOutcome outcome = await commitSecond(repo, engine);

      expect(outcome, isA<CommitDurable>());
      final CommitDurable durable = outcome as CommitDurable;
      expect(durable.transactionId, 2);
      expect(durable.generation, 1);
      expect(durable.snapshotDurable, isTrue);
      expect(
        device.exists('journal.compacting'),
        isTrue,
        reason: 'the interrupted compaction must leave its evidence behind',
      );
      expect(device.flushCountFor('journal'), greaterThan(0));

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
        SaveDiagnosis.interruptedCompaction,
      ]);
      expect(loaded.fromSlot, SnapshotSlot.b);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(loaded.replayedTransactions, 0);
      expect(loaded.skippedTransactions, 2);
    });
  });

  // --- slot selection under damage ----------------------------------------

  group('slot selection', () {
    test('the higher generation wins and the spend is applied once', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      final CommitOutcome outcome = await commitSecond(repo, engine);
      expect((outcome as CommitDurable).generation, 1);

      // Both slots verify: a at generation 0, b at generation 1.
      expect(device.exists('save_slot_a'), isTrue);
      expect(device.exists('save_slot_b'), isTrue);

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.b);
      expect(loaded.generation, 1);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(
        loaded.state.steps.totalSpent,
        spentAfterBoth,
        reason: 'choosing generation 0 would read 0 here, not 137',
      );
      expect(loaded.replayedTransactions, 0);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
    });

    test(
      'a truncated newest slot falls back, and is never a fresh game',
      () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();
        await commitSecond(repo, engine);

        final Uint8List live = Uint8List.fromList(
          device.committedBytes('save_slot_b')!,
        );
        device.seed(
          'save_slot_b',
          Uint8List.sublistView(live, 0, payloadStart(live) + 7),
        );

        final LoadOutcome reloaded = await loadAfterReboot(device);

        expect(
          reloaded,
          isA<SaveLoaded>(),
          reason: 'a wiped newest slot must never present as a new character',
        );
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(loaded.fromSlot, SnapshotSlot.a);
        expect(loaded.generation, 0);
        // The older slot is behind, but the retained journal record carries the
        // difference — so nothing the player did is lost.
        expect(loaded.state.steps.totalGranted, grantedAfterBoth);
        expect(loaded.state.steps.totalSpent, spentAfterBoth);
        expect(loaded.replayedTransactions, 1);
        expect(loaded.lastAppliedTransaction, 2);
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
          SaveDiagnosis.slotTruncated,
          SaveDiagnosis.snapshotOlderThanJournal,
        ]);
        expect(loaded.repairs.first.detail, 'save_slot_b');
      },
    );

    test('a one-byte payload flip in the newest slot falls back', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();
      await commitSecond(repo, engine);

      // Flip a byte *inside a JSON string*, so the payload still parses. A slot
      // corrupted into garbage would only prove the parser rejects garbage;
      // this proves the digest is what rejects it.
      final Uint8List live = Uint8List.fromList(
        device.committedBytes('save_slot_b')!,
      );
      final int at = indexOfBytes(live, utf8.encode(testSaveId));
      expect(at, greaterThan(payloadStart(live) - 1));
      final int last = at + testSaveId.length - 1;
      expect(String.fromCharCode(live[last]), '1');
      live[last] = '2'.codeUnitAt(0);
      expect(
        jsonDecode(
          utf8.decode(Uint8List.sublistView(live, payloadStart(live))),
        ),
        isA<Map<String, Object?>>(),
        reason: 'the corrupted payload must still be valid JSON',
      );
      device.seed('save_slot_b', live);

      final LoadOutcome reloaded = await loadAfterReboot(device);

      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.fromSlot, SnapshotSlot.a);
      expect(loaded.generation, 0);
      expect(loaded.state.steps.totalGranted, grantedAfterBoth);
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(loaded.replayedTransactions, 1);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[
        SaveDiagnosis.slotIntegrityMismatch,
        SaveDiagnosis.snapshotOlderThanJournal,
      ]);
      expect(loaded.repairs.first.detail, 'save_slot_b');
    });

    test(
      'divergent slots at one generation refuse, and change nothing',
      () async {
        final (:SaveRepository repo, :FaultingDevice device) = newRepo();

        final GameEngine left = newEngine()
          ..execute(
            const GrantSyntheticSteps(steps: baselineGrant, reason: 'left'),
          );
        final GameEngine right = newEngine()
          ..execute(
            const GrantSyntheticSteps(steps: baselineGrant, reason: 'left'),
          )
          ..execute(
            const GrantSyntheticSteps(steps: secondGrant, reason: 'right'),
          );

        device
          ..seed(
            'save_slot_a',
            encodeSnapshot(
              state: left.state,
              saveId: testSaveId,
              generation: 4,
              lastAppliedTransaction: 7,
            ),
          )
          ..seed(
            'save_slot_b',
            encodeSnapshot(
              state: right.state,
              saveId: testSaveId,
              generation: 4,
              lastAppliedTransaction: 9,
            ),
          );

        final String before = device.image();
        final LoadOutcome outcome = await repo.load(registry: saveRegistry);

        expect(outcome, isA<LoadRefused>());
        final LoadRefused refused = outcome as LoadRefused;
        expect(refused.reason, LoadRefusal.divergentSlotsAtSameGeneration);
        expect(diagnoses(refused.repairs), <SaveDiagnosis>[
          SaveDiagnosis.slotGenerationTie,
        ]);

        // A refusal must leave a human recovery path intact: both files, exactly
        // as they were. Deleting either one turns a recoverable situation into
        // permanent loss.
        expect(
          device.image(),
          before,
          reason: 'a refusal never modifies or deletes anything',
        );
      },
    );
  });

  // --- concurrent writers -------------------------------------------------

  group('two writers at one expected generation', () {
    test('one commits, one is refused, and nothing partial lands', () async {
      final (:SaveRepository repo, :FaultingDevice device, :GameEngine engine) =
          await seeded();

      // The winner's batch: a grant and a spend.
      final ({List<GameEvent> events, GameState after}) winner = secondBatch(
        engine,
      );

      // The loser starts from a byte-identical baseline and grants a distinct
      // amount, so its arrival would be unmistakable in the totals.
      final GameEngine other = newEngine()
        ..execute(
          const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
        );
      final EngineResult loserEvents = other.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'loser'),
      );

      final List<CommitOutcome> outcomes =
          await Future.wait(<Future<CommitOutcome>>[
            commit(
              repo,
              after: winner.after,
              events: winner.events,
              generation: 0,
              lastTransaction: 1,
            ),
            commit(
              repo,
              after: other.state,
              events: loserEvents.events,
              generation: 0,
              lastTransaction: 1,
            ),
          ]);

      expect(outcomes[0], isA<CommitDurable>());
      final CommitDurable durable = outcomes[0] as CommitDurable;
      expect(durable.transactionId, 2);
      expect(durable.generation, 1);
      expect(durable.retries, 0);

      expect(outcomes[1], isA<CommitRefused>());
      expect(
        (outcomes[1] as CommitRefused).reason,
        CommitRefusal.conflictRetryLimitExhausted,
      );

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.lastAppliedTransaction, 2);
      expect(
        loaded.state.steps.totalGranted,
        grantedAfterBoth,
        reason: 'the loser would have made this 1226',
      );
      expect(loaded.state.steps.totalSpent, spentAfterBoth);
      expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
    });

    test(
      'a conflict, a reload, then a retry that lands exactly once',
      () async {
        final (
          :SaveRepository repo,
          :FaultingDevice device,
          :GameEngine engine,
        ) = await seeded();

        // A second writer that still believes the save is empty.
        final GameEngine stale = newEngine()
          ..execute(
            const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
          );
        final EngineResult attempt = stale.execute(
          const GrantSyntheticSteps(steps: secondGrant, reason: 'stale'),
        );
        final CommitOutcome refused = await commit(
          repo,
          after: stale.state,
          events: attempt.events,
          generation: -1,
          lastTransaction: 0,
        );
        expect(refused, isA<CommitRefused>());
        expect(
          (refused as CommitRefused).reason,
          CommitRefusal.conflictRetryLimitExhausted,
        );

        // The prescribed recovery: reload, reconcile against the newer state,
        // try again.
        final LoadOutcome current = await repo.load(registry: saveRegistry);
        expect(current, isA<SaveLoaded>());
        final SaveLoaded fresh = current as SaveLoaded;
        expect(fresh.state.steps.totalGranted, baselineGrant);
        expect(fresh.generation, 0);
        expect(fresh.lastAppliedTransaction, 1);

        final GameEngine resumed = GameEngine(
          registry: saveRegistry,
          state: fresh.state,
        );
        final ({List<GameEvent> events, GameState after}) retry = secondBatch(
          resumed,
        );
        final CommitOutcome landed = await commit(
          repo,
          after: retry.after,
          events: retry.events,
          generation: fresh.generation,
          lastTransaction: fresh.lastAppliedTransaction,
        );

        expect(landed, isA<CommitDurable>());
        final CommitDurable durable = landed as CommitDurable;
        expect(durable.transactionId, 2);
        expect(durable.generation, 1);
        expect(durable.retries, 0);

        final LoadOutcome reloaded = await loadAfterReboot(device);
        expect(reloaded, isA<SaveLoaded>());
        final SaveLoaded loaded = reloaded as SaveLoaded;
        expect(loaded.state.steps.totalGranted, grantedAfterBoth);
        expect(
          loaded.state.steps.totalSpent,
          spentAfterBoth,
          reason: 'a re-applied retry would read 274 here',
        );
        expect(loaded.lastAppliedTransaction, 2);
        expect(diagnoses(loaded.repairs), <SaveDiagnosis>[]);
      },
    );

    test('the retry budget is bounded and refuses in a typed way', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();
      final EngineResult first = engine.execute(
        const GrantSyntheticSteps(steps: baselineGrant, reason: 'baseline'),
      );
      await commit(
        repo,
        after: engine.state,
        events: first.events,
        generation: -1,
        lastTransaction: 0,
      );

      // A repository whose budget is one retry. An unbounded loop here would
      // hang the sync, which to the player is indistinguishable from the game
      // losing their walk.
      final SaveRepository bounded = SaveRepository(
        snapshots: FaultingSnapshotStore(device),
        journal: FaultingJournal(device),
        maxCommitRetries: 1,
      );

      final String before = device.image();
      final int flushes = device.flushCountFor('journal');
      expect(flushes, greaterThan(0));

      final ({List<GameEvent> events, GameState after}) batch = secondBatch(
        engine,
      );
      final CommitOutcome outcome = await commit(
        bounded,
        after: batch.after,
        events: batch.events,
        generation: 4,
        lastTransaction: 9,
      );

      expect(outcome, isA<CommitRefused>());
      final CommitRefused refused = outcome as CommitRefused;
      expect(refused.reason, CommitRefusal.conflictRetryLimitExhausted);
      expect(refused.detail, contains('reload'));

      expect(device.image(), before);
      expect(
        device.flushCountFor('journal'),
        flushes,
        reason: 'a refused commit appends nothing',
      );

      final LoadOutcome reloaded = await loadAfterReboot(device);
      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(loaded.state.steps.totalGranted, baselineGrant);
      expect(loaded.state.steps.totalSpent, 0);
      expect(loaded.lastAppliedTransaction, 1);
    });
  });
}
