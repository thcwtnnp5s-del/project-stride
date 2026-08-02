/// The transaction protocol, slot selection, compare-and-swap, and recovery.
///
/// This is a concrete class in `stride_core`, not a port. The protocol **is**
/// the crash-safety argument: pushed into the app layer it could not be tested
/// by `dart test` on Windows in milliseconds, and a second implementation
/// (test double against real) would eventually disagree about ordering.
/// The two ports underneath it promise only "bytes, durably" and know nothing
/// about transactions.
///
/// ## The invariants
///
/// | | |
/// |---|---|
/// | **P1** | A grant the engine accepted is never lost |
/// | **P2** | A batch is never granted twice |
/// | **P3** | Retrying an old cursor is safe |
/// | **P4** | **The durable cursor never leads the durable granted state** |
/// | **P5** | Snapshot corruption is recoverable from the journal |
/// | **P6** | Replay is deterministic |
/// | **P7** | Compaction cannot remove the only durable record of a grant |
///
/// P4 is the keystone; the rest follow from it plus F-04's arithmetic. It holds
/// structurally rather than by argument: `SyncCheckpoint.cursor` lives inside
/// `StepLedger` inside `GameState`, and the whole batch is one journal record,
/// so the cursor and the grant that authorized it are *the same bytes*. There
/// is no durable state in which one advanced and the other did not.
///
/// **This is why a native adapter must never persist a cursor of its own.** A
/// cached anchor in `NSUserDefaults` or `SharedPreferences` decouples the two,
/// and a snapshot fallback then rolls back the ledger but not the cursor —
/// making everything between them permanently unrecoverable.
library;

import 'dart:async';
import 'dart:typed_data';

import '../content/balance_profile.dart';
import '../content/content_id.dart';
import '../content/content_registry.dart';
import '../engine/event_reducer.dart';
import '../engine/events.dart';
import '../engine/game_state.dart';
import '../engine/state_version.dart';
import '../ports/save_store.dart';
import '../ports/transaction_lock.dart';
import 'journal_record.dart';
import 'save_codec.dart';
import 'save_outcomes.dart';

/// What a caller believes the durable state to be.
///
/// Optimistic concurrency: the commit lands only if durable state still
/// matches. An in-memory mutex is **not** sufficient by itself — Health
/// Connect background delivery can run in a separate worker, and a mutex in
/// one isolate says nothing about another.
final class CommitExpectation {
  const CommitExpectation({
    required this.expectedSnapshotGeneration,
    required this.expectedLastAppliedTransaction,
  });

  /// The generation this caller loaded from. -1 means "no save existed".
  final int expectedSnapshotGeneration;

  final int expectedLastAppliedTransaction;
}

/// A verified slot, or the reason it was rejected.
final class _SlotReading {
  const _SlotReading.verified(this.slot, this.envelope) : diagnosis = null;
  const _SlotReading.rejected(this.slot, this.diagnosis) : envelope = null;

  final SnapshotSlot slot;
  final SaveEnvelope? envelope;
  final SaveDiagnosis? diagnosis;

  bool get verified => envelope != null;
}

/// Durable state for one save.
final class SaveRepository {
  SaveRepository({
    required SnapshotSlotStore snapshots,
    required LedgerJournal journal,
    this.maxCommitRetries = 3,
    TransactionLock lock = const UncontendedLock(),
    this.lockTimeout = const Duration(seconds: 5),
    // The fields are private and named parameters cannot be, so the
    // initializing-formal shorthand is unavailable here.
    // ignore: prefer_initializing_formals
  }) : _snapshots = snapshots,
       // ignore: prefer_initializing_formals
       _journal = journal,
       // ignore: prefer_initializing_formals
       _lock = lock;

  final SnapshotSlotStore _snapshots;
  final LedgerJournal _journal;

  /// Held across the **entire** transaction, not just the append.
  ///
  /// Everything from reading the durable head through CAS validation, the
  /// journal append, read-back, the snapshot write, cursor authorization and
  /// compaction happens inside one hold. Narrowing it to the append alone
  /// would leave the read-head-to-append window open, which is the window
  /// the whole race lives in.
  final TransactionLock _lock;

  /// How long to wait for another holder before refusing.
  final Duration lockTimeout;

  /// How many compare-and-swap conflicts to absorb before refusing.
  ///
  /// Bounded on purpose. An unbounded retry loop against a writer that never
  /// yields is a hang, and a hang during a step sync looks to the player
  /// exactly like the game losing their walk.
  final int maxCommitRetries;

  /// Serializes every operation within this process.
  ///
  /// Dart is single-isolate but `await` interleaving is real: two overlapping
  /// commits would interleave appends and fork the journal. Necessary, and by
  /// itself not sufficient — see [CommitExpectation].
  Future<void> _writer = Future<void>.value();

  /// Serializes within this process, then across processes.
  ///
  /// Two layers, because they solve different problems. The queue stops one
  /// isolate interleaving its own awaits; the OS lock stops a second process
  /// -- a background worker -- from interleaving with this one. Neither
  /// substitutes for the other.
  ///
  /// [onBusy] supplies the typed result when the lock cannot be taken. A
  /// caller that has no meaningful busy value passes null and gets a throw,
  /// which is correct for a read: a load that cannot start has nothing safe
  /// to return.
  Future<T> _serialized<T>(
    Future<T> Function() action, {
    T Function()? onBusy,
  }) {
    final Completer<T> result = Completer<T>();
    _writer = _writer.then((_) async {
      TransactionLockHandle? held;
      late T value;
      bool produced = false;
      Object? failure;
      StackTrace? failureStack;

      try {
        held = await _lock.acquire(lockTimeout);
        if (held == null) {
          if (onBusy == null) {
            throw StateError(
              'the save is in use by another process; no safe result exists',
            );
          }
          // Nothing has been written at this point -- the lock is taken
          // before any read or write -- so a busy result is a clean refusal.
          value = onBusy();
        } else {
          value = await action();
        }
        produced = true;
      } on Object catch (e, st) {
        failure = e;
        failureStack = st;
      } finally {
        // Always. A lock leaked by an exception would block every later
        // launch, and on a real filesystem only a process death would clear
        // it.
        try {
          await held?.release();
        } on Object catch (e, st) {
          // A release failure after a *durable* transaction is a leaked
          // descriptor, not a lost commit. Reporting it as a throw would make
          // the caller assume the batch did not land and withhold the cursor,
          // which is the one thing P1 forbids. It is only allowed to surface
          // when there is no result to protect.
          if (!produced) {
            failure = e;
            failureStack = st;
          }
        }
      }

      // Completed only after the lock is gone.
      //
      // The previous version completed inside the `try`, so `await commit(...)`
      // returned while the handle was still open: the caller could start the
      // next operation, or erase the directory, against a save this process
      // had not finished letting go of. On Windows that is an immediate
      // sharing violation; everywhere it is a spurious `storageBusy` for a
      // second instance that was told the first had finished.
      if (produced) {
        result.complete(value);
      } else {
        result.completeError(failure!, failureStack!);
      }
    });
    return result.future;
  }

  // --- loading ------------------------------------------------------------

  /// Reads both slots and the journal, and reconstructs the newest safe state.
  /// [originSaltFingerprint] is the fingerprint of the salt the app currently
  /// holds. If it does not match the one the save was written with, the load
  /// **fails closed** — see [_checkSalt].
  Future<LoadOutcome> load({
    required ContentRegistry registry,
    bool treatAsRelease = false,
    String? originSaltFingerprint,
  }) =>
      _serialized(() => _load(registry, treatAsRelease, originSaltFingerprint));

  Future<LoadOutcome> _load(
    ContentRegistry registry,
    bool treatAsRelease,
    String? originSaltFingerprint,
  ) async {
    final List<SaveRepair> repairs = <SaveRepair>[];

    // Step 0. Never adopt a compaction sidecar; the pre-compaction journal is
    // always sufficient, so there is nothing to resume.
    if (await _journal.discardIncompleteCompaction()) {
      repairs.add(const SaveRepair(SaveDiagnosis.interruptedCompaction));
    }

    final List<_SlotReading> readings = <_SlotReading>[
      await _readSlot(SnapshotSlot.a),
      await _readSlot(SnapshotSlot.b),
    ];
    final List<_SlotReading> verified = readings
        .where((_SlotReading r) => r.verified)
        .toList();

    for (final _SlotReading r in readings) {
      if (r.verified) continue;
      // An absent second slot is the normal state before the first ping-pong,
      // not damage. Recording it as a repair would make every healthy new save
      // report itself degraded, and a `degraded` flag that is always true
      // tells nobody anything.
      if (r.diagnosis == SaveDiagnosis.slotAbsent && verified.isNotEmpty) {
        continue;
      }
      repairs.add(SaveRepair(r.diagnosis!, detail: r.slot.fileName));
    }
    final List<Uint8List> lines = await _journal.readLines();

    // Step 2. Nothing readable.
    if (verified.isEmpty) {
      final bool bothAbsent = readings.every(
        (_SlotReading r) => r.diagnosis == SaveDiagnosis.slotAbsent,
      );
      // The *only* legitimate new-game path. Anything less would let a
      // file-wipe bug present as a fresh character.
      if (bothAbsent && lines.isEmpty) return const NoSaveFound();

      final SaveDiagnosis? blocking = readings
          .map((_SlotReading r) => r.diagnosis)
          .firstWhere(
            (SaveDiagnosis? d) =>
                d == SaveDiagnosis.slotFutureSaveFormat ||
                d == SaveDiagnosis.slotUnsupportedStateVersion,
            orElse: () => null,
          );
      if (blocking != null) {
        return LoadRefused(
          reason: blocking == SaveDiagnosis.slotFutureSaveFormat
              ? LoadRefusal.futureSaveFormat
              : LoadRefusal.unsupportedStateVersion,
          explanation:
              'This save was written by a newer version of Stride. Update the '
              'app to open it. Nothing has been changed or deleted.',
          repairs: repairs,
        );
      }
      return LoadRefused(
        reason: LoadRefusal.allSlotsUnreadable,
        explanation:
            'Neither save slot could be read. The files are still on the '
            'device and have not been modified.',
        repairs: repairs,
      );
    }

    // Step 3. Equal generations that disagree: fail closed. There is no
    // principled way to choose, and choosing wrong duplicates or destroys a
    // grant.
    if (verified.length == 2) {
      final SaveEnvelope x = verified[0].envelope!;
      final SaveEnvelope y = verified[1].envelope!;
      if (x.snapshotGeneration == y.snapshotGeneration) {
        final bool identical =
            x.state.signature == y.state.signature &&
            x.lastAppliedTransaction == y.lastAppliedTransaction;
        if (!identical) {
          repairs.add(const SaveRepair(SaveDiagnosis.slotGenerationTie));
          return LoadRefused(
            reason: LoadRefusal.divergentSlotsAtSameGeneration,
            explanation:
                'Both save slots claim to be the same version but contain '
                'different progress. Stride will not guess which is correct.',
            repairs: repairs,
          );
        }
      }
    }

    verified.sort(
      (_SlotReading a, _SlotReading b) => b.envelope!.snapshotGeneration
          .compareTo(a.envelope!.snapshotGeneration),
    );
    final _SlotReading chosen = verified.first;
    final SaveEnvelope envelope = chosen.envelope!;

    final LoadRefused? saltRefusal = _checkSalt(
      envelope,
      originSaltFingerprint,
      repairs,
    );
    if (saltRefusal != null) return saltRefusal;

    // Step 4. Profile authority. The save's profile governs, not the app's.
    final LoadRefused? profileRefusal = _checkProfile(
      envelope,
      registry,
      treatAsRelease,
      repairs,
    );
    if (profileRefusal != null) return profileRefusal;

    if (!contentSchemaSupported(envelope.contentSchemaVersion)) {
      return LoadRefused(
        reason: LoadRefusal.unsupportedContentSchema,
        explanation:
            'This save uses content schema '
            '${envelope.contentSchemaVersion}, which this build cannot read.',
        repairs: repairs,
      );
    }

    final List<String> missing = _missingContent(envelope.state, registry);
    if (missing.isNotEmpty) {
      // Refuse, never drop. Dropping silently deletes the player's
      // possessions; content IDs are permanent, so a missing one means someone
      // broke that rule, and that should stop a build rather than a player.
      return LoadRefused(
        reason: LoadRefusal.unknownContent,
        explanation:
            'This save refers to content that is not in this build: '
            '${missing.join(', ')}.',
        repairs: repairs,
      );
    }

    // Steps 5-6. Journal.
    final _JournalScan scan = _scanJournal(lines, envelope.saveId, repairs);
    if (scan.refusal != null) {
      return LoadRefused(
        reason: scan.refusal!,
        explanation: scan.explanation!,
        repairs: repairs,
      );
    }

    GameState state = envelope.state;
    int replayed = 0;
    int skipped = 0;
    final int watermark = envelope.lastAppliedTransaction;

    for (final JournalRecord record in scan.records) {
      if (record.transactionId <= watermark) {
        skipped++;
        continue;
      }
      if (record.eventSequenceBefore != state.eventSequence) {
        // A hole. Applying the tail would break continuity, and F-04's
        // arithmetic will re-grant the window on the next sync anyway, because
        // the snapshot's cursor is by P4 no newer than its granted state.
        repairs.add(
          const SaveRepair(
            SaveDiagnosis.journalOrphaned,
            detail: 'event sequence discontinuity; tail not replayed',
          ),
        );
        break;
      }
      state = const EventReducer().applyAll(state, record.events);
      replayed++;
    }

    // Replay is a repair: the snapshot was behind and had to be caught up.
    // The converse — a journal fully covered by the snapshot — is simply the
    // normal state between a commit and the next compaction, so it is not
    // recorded as one.
    if (replayed > 0) {
      repairs.add(const SaveRepair(SaveDiagnosis.snapshotOlderThanJournal));
    }

    return SaveLoaded(
      state: state,
      saveId: envelope.saveId,
      fromSlot: chosen.slot,
      generation: envelope.snapshotGeneration,
      lastAppliedTransaction: watermark + replayed,
      replayedTransactions: replayed,
      skippedTransactions: skipped,
      repairs: repairs,
    );
  }

  Future<_SlotReading> _readSlot(SnapshotSlot slot) async {
    final Uint8List? bytes = await _snapshots.read(slot);
    if (bytes == null) {
      return _SlotReading.rejected(slot, SaveDiagnosis.slotAbsent);
    }
    if (bytes.isEmpty) {
      // Present but empty is **truncated**, not absent.
      //
      // A slot write opens with truncate-first semantics, so a death between
      // the truncate and the write leaves exactly this. Collapsing it into
      // "absent" let a zero-length *pair* reach the new-game path and hand the
      // player a wiped character — the precise failure the bootstrap state
      // machine exists to prevent, arriving underneath it through storage.
      return _SlotReading.rejected(slot, SaveDiagnosis.slotTruncated);
    }

    final FrameResult framed = unframe(bytes);
    if (!framed.verified) {
      return _SlotReading.rejected(slot, switch (framed.fault!) {
        FrameFault.malformedEncoding => SaveDiagnosis.slotMalformedEncoding,
        FrameFault.futureFormat => SaveDiagnosis.slotFutureSaveFormat,
        FrameFault.truncated => SaveDiagnosis.slotTruncated,
        FrameFault.integrityMismatch => SaveDiagnosis.slotIntegrityMismatch,
      });
    }

    final SaveEnvelope envelope;
    try {
      envelope = decodeEnvelope(framed.payload!);
    } on SaveCodecException catch (e) {
      return _SlotReading.rejected(slot, switch (e.message) {
        final String m when m.contains('gameStateVersion') =>
          SaveDiagnosis.slotUnsupportedStateVersion,
        // Named separately because the cause and the fix differ from generic
        // malformed encoding: this one means an adapter wrote a raw platform
        // identifier past the pseudonymization boundary.
        final String m when m.contains('origin key') =>
          SaveDiagnosis.originKeyRejected,
        _ => SaveDiagnosis.slotMalformedEncoding,
      });
    }

    if (!envelope.commitComplete) {
      return _SlotReading.rejected(slot, SaveDiagnosis.slotIncompleteCommit);
    }
    if (!StateVersion.supports(envelope.gameStateVersion)) {
      return _SlotReading.rejected(
        slot,
        SaveDiagnosis.slotUnsupportedStateVersion,
      );
    }
    // A save that disagrees with its own header is not a save.
    if (envelope.eventSequence != envelope.state.eventSequence ||
        envelope.gameStateVersion != envelope.state.stateVersion ||
        envelope.balanceProfileId != envelope.state.profileId.value) {
      return _SlotReading.rejected(
        slot,
        SaveDiagnosis.slotHeaderDisagreesWithPayload,
      );
    }

    return _SlotReading.verified(slot, envelope);
  }

  /// Refuses when the origin pseudonymization salt has changed.
  ///
  /// A changed or lost salt re-keys every origin. The newly-keyed origins have
  /// no `grantedSlices`, so their recent buckets look ungranted and **the whole
  /// live retention window would be granted a second time**. No credit is lost
  /// — `totalGranted` is origin-independent — so this is a bounded double-grant
  /// rather than a lost grant, and nothing downstream would ever detect it.
  ///
  /// Refusing is recoverable: the player can be offered a health reconnect,
  /// which clears health state and keeps earned progress. A silent double-grant
  /// is not recoverable, so this fails closed.
  ///
  /// A save with no fingerprint has not read a health source yet and has no
  /// origins to re-key, so there is nothing to refuse.
  LoadRefused? _checkSalt(
    SaveEnvelope envelope,
    String? current,
    List<SaveRepair> repairs,
  ) {
    final String? saved = envelope.originSaltFingerprint;
    if (saved == null || current == null || saved == current) return null;

    return LoadRefused(
      reason: LoadRefusal.originKeyReset,
      // Neither fingerprint appears: both are derived from health-source
      // identity, and this string reaches a diagnostic surface.
      explanation:
          'This save was written with a different health-source key. Loading '
          'it now could count recent steps twice. Reconnect health to '
          'continue; your earned progress is kept.',
      repairs: repairs,
    );
  }

  LoadRefused? _checkProfile(
    SaveEnvelope envelope,
    ContentRegistry registry,
    bool treatAsRelease,
    List<SaveRepair> repairs,
  ) {
    final String saved = envelope.balanceProfileId;
    final String running = registry.profile.id.value;

    if (saved == BalanceProfile.acceleratedQaId.value && treatAsRelease) {
      return LoadRefused(
        reason: LoadRefusal.qaProfileForbiddenInRelease,
        explanation:
            'This save was created with accelerated QA pacing and cannot be '
            'opened by a release build.',
        repairs: repairs,
      );
    }
    if (saved != BalanceProfile.productionId.value &&
        saved != BalanceProfile.acceleratedQaId.value) {
      return LoadRefused(
        reason: LoadRefusal.unknownProfile,
        explanation:
            'This save uses balance profile "$saved", which this build does '
            'not have.',
        repairs: repairs,
      );
    }
    if (saved != running) {
      // Never silently reinterpret. Changing a save's profile is a deliberate
      // migration or a new game.
      return LoadRefused(
        reason: LoadRefusal.profileMigrationRequired,
        explanation:
            'This save uses balance profile "$saved" and the app is running '
            '"$running". Opening it would change what its progress means.',
        repairs: repairs,
      );
    }
    return null;
  }

  bool _known(ContentRegistry registry, ContentId id) =>
      registry.items.containsKey(id) ||
      registry.skills.containsKey(id) ||
      registry.locations.containsKey(id) ||
      registry.resourceNodes.containsKey(id) ||
      registry.recipes.containsKey(id) ||
      registry.enemies.containsKey(id);

  List<String> _missingContent(GameState state, ContentRegistry registry) {
    final Set<String> missing = <String>{};
    for (final ContentId id in <ContentId>[
      ...state.inventory.counts.keys,
      ...state.equipment.bySlot.values,
      ...state.skills.experienceBySkill.keys,
      state.world.currentLocation,
      ...state.world.unlockedLocations,
    ]) {
      if (!_known(registry, id)) missing.add(id.value);
    }
    return missing.toList()..sort();
  }

  // --- journal scanning ---------------------------------------------------

  _JournalScan _scanJournal(
    List<Uint8List> lines,
    String saveId,
    List<SaveRepair> repairs,
  ) {
    final List<JournalRecord> records = <JournalRecord>[];

    for (int i = 0; i < lines.length; i++) {
      final JournalLineResult parsed = decodeJournalLine(lines[i]);
      if (!parsed.ok) {
        if (i == lines.length - 1) {
          // A torn tail is benign: the transaction simply did not commit.
          repairs.add(const SaveRepair(SaveDiagnosis.journalTailTorn));
          break;
        }
        // A hole in the middle of an append-only file means the storage is
        // lying. The usable tail ends here.
        repairs.add(
          SaveRepair(SaveDiagnosis.journalCorruptInterior, detail: 'record $i'),
        );
        break;
      }

      final JournalRecord record = parsed.record!;
      if (record.saveId != saveId) {
        return _JournalScan.refused(
          LoadRefusal.lineageMismatch,
          'A recovery record belongs to a different save.',
        );
      }

      if (records.isNotEmpty) {
        final JournalRecord previous = records.last;
        if (record.transactionId == previous.transactionId) {
          // The retry case: an append whose acknowledgement was lost. Absorbing
          // an identical duplicate is correct, because at-least-once appending
          // is exactly what an unconfirmed flush produces.
          final bool sameShape =
              record.eventSequenceBefore == previous.eventSequenceBefore &&
              record.eventSequenceAfter == previous.eventSequenceAfter &&
              record.events.length == previous.events.length;
          if (sameShape) {
            repairs.add(
              const SaveRepair(SaveDiagnosis.journalDuplicateTransaction),
            );
            continue;
          }
          // Two different histories at one sequence. Identity is not a
          // function of content, so nothing after this is trustworthy.
          return _JournalScan.refused(
            LoadRefusal.journalForked,
            'Two different recovery records claim the same transaction.',
          );
        }
        if (record.transactionId != previous.transactionId + 1) {
          repairs.add(const SaveRepair(SaveDiagnosis.journalSequenceGap));
          break;
        }
      }
      records.add(record);
    }

    return _JournalScan(records);
  }

  // --- committing ---------------------------------------------------------

  /// Commits one batch of events.
  ///
  /// Order, and why each step is where it is:
  ///
  /// 1. Verify the caller's expectation against durable state (compare-and-swap)
  /// 2. Append the journal record and **wait for durability** — the commit point
  /// 3. The caller may now publish, and only now release the cursor
  /// 4. Write the snapshot to the *older* slot, leaving the live one untouched
  /// 5. Compact, floored at the older of two verified slots
  Future<CommitOutcome> commit({
    required GameState after,
    required List<GameEvent> events,
    required String saveId,
    required CommitExpectation expectation,
    required String? originSaltFingerprint,
  }) => _serialized(
    () => _commitWithRetry(
      after,
      events,
      saveId,
      expectation,
      originSaltFingerprint,
    ),
    onBusy: () => const CommitRefused(
      reason: CommitRefusal.storageBusy,
      detail: 'another process holds the save; nothing was written',
    ),
  );

  Future<CommitOutcome> _commitWithRetry(
    GameState after,
    List<GameEvent> events,
    String saveId,
    CommitExpectation expectation,
    String? originSaltFingerprint,
  ) async {
    for (int attempt = 0; attempt <= maxCommitRetries; attempt++) {
      final _DurableHead head = await _readHead();

      final bool matches =
          head.generation == expectation.expectedSnapshotGeneration &&
          head.lastAppliedTransaction ==
              expectation.expectedLastAppliedTransaction;

      if (!matches) {
        if (attempt == maxCommitRetries) {
          // Nothing partial was written. The caller reloads, reconciles again
          // against the newer state, and tries once more — which is safe
          // precisely because F-04 grants max(0, observed - granted).
          return const CommitRefused(
            reason: CommitRefusal.conflictRetryLimitExhausted,
            detail:
                'durable state advanced under this transaction; reload and '
                'reconcile against the newer state',
          );
        }
        continue;
      }

      return _commitOnce(
        after,
        events,
        saveId,
        head,
        attempt,
        originSaltFingerprint,
      );
    }
    return const CommitRefused(
      reason: CommitRefusal.conflictRetryLimitExhausted,
      detail: 'retry budget exhausted',
    );
  }

  Future<CommitOutcome> _commitOnce(
    GameState after,
    List<GameEvent> events,
    String saveId,
    _DurableHead head,
    int retries,
    String? originSaltFingerprint,
  ) async {
    final int transactionId = head.maxJournalTransaction + 1;
    final JournalRecord record = JournalRecord(
      formatVersion: SaveFormatVersion.current,
      saveId: saveId,
      transactionId: transactionId,
      eventSequenceBefore: after.eventSequence - events.length,
      eventSequenceAfter: after.eventSequence,
      events: events,
    );

    try {
      await _journal.appendLine(encodeJournalLine(record));
    } on Object catch (e) {
      // Not committed. The caller must not release the cursor — the platform
      // will re-report the same data and F-04 will grant it exactly once.
      return CommitRefused(
        reason: CommitRefusal.journalAppendFailed,
        detail: '$e',
      );
    }

    // The transaction is durable from here. Everything below is cache
    // maintenance, and its failure is not the caller's problem.
    final SnapshotSlot target = head.staleSlot;
    final int generation = head.generation + 1;
    bool snapshotDurable = true;
    try {
      await _snapshots.write(
        target,
        encodeSnapshot(
          state: after,
          saveId: saveId,
          generation: generation,
          lastAppliedTransaction: transactionId,
          originSaltFingerprint: originSaltFingerprint,
        ),
      );
      // Read back and validate the full envelope before treating the slot as
      // a candidate. A write that returned successfully and landed corrupt is
      // exactly the case two slots exist to survive.
      final _SlotReading check = await _readSlot(target);
      snapshotDurable =
          check.verified && check.envelope!.snapshotGeneration == generation;
    } on Object {
      snapshotDurable = false;
    }

    if (snapshotDurable) {
      // Guarded, and this is not defensive clutter. Compaction is journal
      // hygiene *after* the commit point: a failure here leaves a longer
      // journal and nothing else. Letting it escape would turn a durable
      // transaction into a thrown exception at the call site, and a caller
      // that sees a throw must assume the batch did not commit and must not
      // release the cursor - so an unwritable sidecar would stall step
      // ingestion permanently on a save that is, in fact, committed.
      try {
        await _compact();
      } on Object {
        // Deliberately swallowed. The next commit tries again, and until then
        // the retained records are redundant rather than wrong.
      }
    }

    return CommitDurable(
      transactionId: transactionId,
      generation: snapshotDurable ? generation : head.generation,
      slot: target,
      snapshotDurable: snapshotDurable,
      retries: retries,
    );
  }

  // --- compaction ---------------------------------------------------------

  /// Removes journal records whose effect is durable in **two** snapshots.
  ///
  /// Aggressive on purpose, and not for size. Every reconciliation record
  /// carries a full granted-slice map, so an uncompacted journal is a
  /// permanent unbounded step history — the thing the retention ruling bounds,
  /// reintroduced through the back door. Compaction is a privacy control with
  /// a hard obligation.
  Future<CompactionOutcome> compact() => _serialized(_compact);

  Future<CompactionOutcome> _compact() async {
    final List<_SlotReading> readings = <_SlotReading>[
      await _readSlot(SnapshotSlot.a),
      await _readSlot(SnapshotSlot.b),
    ];
    final List<SaveEnvelope> verified = readings
        .where((_SlotReading r) => r.verified)
        .map((_SlotReading r) => r.envelope!)
        .toList();

    // Fewer than two verified slots means the floor is undefined. Compacting
    // anyway can delete the only record a fallback would need.
    if (verified.length < 2) {
      return const CompactionOutcome.skipped(
        CompactionRefusal.insufficientVerifiedSlots,
      );
    }

    final int floor = verified
        .map((SaveEnvelope e) => e.lastAppliedTransaction)
        .reduce((int a, int b) => a < b ? a : b);

    final List<Uint8List> lines = await _journal.readLines();
    final List<Uint8List> keep = <Uint8List>[];
    for (final Uint8List line in lines) {
      final JournalLineResult parsed = decodeJournalLine(line);
      if (!parsed.ok || parsed.record!.transactionId > floor) keep.add(line);
    }

    if (keep.length == lines.length) {
      return const CompactionOutcome.skipped(
        CompactionRefusal.nothingBelowFloor,
      );
    }

    await _journal.replaceLines(keep);
    return CompactionOutcome(
      removed: lines.length - keep.length,
      retainedFrom: floor + 1,
    );
  }

  /// Clears every artifact. Full reset only — **not** the health disconnect,
  /// which keeps gameplay progress and is an ordinary commit.
  Future<void> eraseAll() => _serialized(() async {
    await _snapshots.erase(SnapshotSlot.a);
    await _snapshots.erase(SnapshotSlot.b);
    await _journal.erase();
  });

  // --- durable head -------------------------------------------------------

  Future<_DurableHead> _readHead() async {
    final List<_SlotReading> readings = <_SlotReading>[
      await _readSlot(SnapshotSlot.a),
      await _readSlot(SnapshotSlot.b),
    ];
    final List<_SlotReading> verified =
        readings.where((_SlotReading r) => r.verified).toList()..sort(
          (_SlotReading a, _SlotReading b) => b.envelope!.snapshotGeneration
              .compareTo(a.envelope!.snapshotGeneration),
        );

    int maxTx = 0;
    for (final Uint8List line in await _journal.readLines()) {
      final JournalLineResult parsed = decodeJournalLine(line);
      if (parsed.ok && parsed.record!.transactionId > maxTx) {
        maxTx = parsed.record!.transactionId;
      }
    }

    if (verified.isEmpty) {
      return _DurableHead(
        generation: -1,
        lastAppliedTransaction: 0,
        maxJournalTransaction: maxTx,
        staleSlot: SnapshotSlot.a,
      );
    }

    final SaveEnvelope live = verified.first.envelope!;
    return _DurableHead(
      generation: live.snapshotGeneration,
      lastAppliedTransaction: live.lastAppliedTransaction,
      maxJournalTransaction: maxTx > live.lastAppliedTransaction
          ? maxTx
          : live.lastAppliedTransaction,
      // Write to the slot that is not live. When only one verifies, the other
      // is by definition the safe target.
      staleSlot: verified.first.slot.other,
    );
  }
}

final class _DurableHead {
  const _DurableHead({
    required this.generation,
    required this.lastAppliedTransaction,
    required this.maxJournalTransaction,
    required this.staleSlot,
  });

  final int generation;
  final int lastAppliedTransaction;
  final int maxJournalTransaction;
  final SnapshotSlot staleSlot;
}

final class _JournalScan {
  const _JournalScan(this.records) : refusal = null, explanation = null;
  const _JournalScan.refused(this.refusal, this.explanation)
    : records = const <JournalRecord>[];

  final List<JournalRecord> records;
  final LoadRefusal? refusal;
  final String? explanation;
}
