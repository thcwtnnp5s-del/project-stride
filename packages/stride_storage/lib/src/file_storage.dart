/// Real files, for the pure-Dart ports `stride_core` defines.
///
/// ## What "durable" means here, precisely
///
/// The F-05 protocol says a write returns only once the bytes are durable. On
/// a real filesystem that phrase hides five distinct things, and conflating
/// them is how a save system comes to believe something it has not verified:
///
/// | Stage | What it means | Verified how |
/// |---|---|---|
/// | **write completed** | `write()` returned. The bytes are in the OS page cache | Return of the call |
/// | **flush requested** | `flush()` returned. We asked the OS to push them to the medium | Return of the call |
/// | **read-back verified** | Reading the file returns the bytes we wrote | An actual second read |
/// | **envelope validated** | Those bytes parse, and their digest matches | `unframe` + decode, in `SaveRepository` |
/// | **protocol commit durable** | All of the above, *and* the previous valid slot is untouched | The protocol, not this class |
///
/// **This adapter delivers the first three.** Stages four and five belong to
/// the protocol in `stride_core`: nothing here unframes or decodes anything,
/// and `writeVerified` compares bytes rather than envelopes.
///
/// The table said "the first four" until a probe wrote non-envelope bytes
/// through `FileSnapshotStore.write` and watched them be accepted. That is
/// the second time a doc comment in this package has claimed a property the
/// code did not have, which is precisely what a table like this is supposed
/// to prevent — so it is corrected rather than deleted.
///
/// **What none of this proves.** `flush()` is a request. Whether the bytes
/// survive sudden physical power loss depends on the device's write cache, its
/// controller, and whether it honours a barrier — none of which is observable
/// from Dart, and none of which a CI runner or an emulator can demonstrate.
/// The claim made here is *read-back verified after a flush request*, which is
/// strictly weaker than power-loss durable and is the strongest claim the
/// evidence supports.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

/// The on-disk layout.
///
/// One private directory under application support. No external storage, no
/// user-visible documents directory, and no name derived from a device or a
/// health source — the paths themselves are part of the privacy surface.
final class StorageLayout {
  const StorageLayout(this.root);

  /// The directory holding everything. Created if absent.
  final Directory root;

  static const String directoryName = 'project_stride';

  File get slotA => File('${root.path}/save_slot_a');
  File get slotB => File('${root.path}/save_slot_b');
  File get journal => File('${root.path}/ledger_journal');
  File get journalSidecar => File('${root.path}/ledger_journal.compacting');
  File get identity => File('${root.path}/reconciliation_identity');

  /// Holds no data. It exists only to give the OS something to lock, and is
  /// never read, written, or deleted — deleting a file another process holds
  /// a lock on leaves two processes locking two inodes that share a name.
  File get transactionLock => File('${root.path}/transaction.lock');

  /// Every file this layout may create.
  ///
  /// Exposed so a platform audit can assert that backup exclusions cover the
  /// *actual* filenames rather than filenames someone remembered.
  List<File> get allFiles => <File>[
    slotA,
    slotB,
    journal,
    journalSidecar,
    identity,
    transactionLock,
  ];

  Future<void> ensureExists() async {
    if (!root.existsSync()) await root.create(recursive: true);
  }
}

/// Thrown when the filesystem itself fails.
///
/// Distinct from the typed save outcomes: a corrupt save is an expected
/// condition with a typed result, whereas an unreadable *device* is not
/// something the protocol can reason about.
final class StorageException implements Exception {
  const StorageException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() => 'StorageException($operation): $cause';
}

/// Writes bytes and verifies they came back.
///
/// The read-back is not paranoia. A `write` + `flush` pair that returns
/// successfully and leaves a short or empty file is exactly the case two
/// snapshot slots exist to survive, and without reading back, this adapter
/// would report success and the protocol would advance its generation over
/// nothing.
///
/// **Public because otherwise the read-back cannot be proved.** Against a real
/// filesystem there is no way, from pure Dart, to make a write succeed and its
/// read-back return different bytes — so the only honest demonstration that the
/// verification happens at all is a test that hands this function a [File]
/// whose `readAsBytes` lies. A private helper would leave the "read-back
/// verified" row of the table above as an unverified claim, which is exactly
/// what that table exists to prevent.
Future<void> writeVerified(File file, Uint8List bytes) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open(mode: FileMode.write);
    await handle.writeFrom(bytes);
    // A request, not a guarantee — see the library comment.
    await handle.flush();
  } on Object catch (e) {
    throw StorageException('write ${file.path}', e);
  } finally {
    await handle?.close();
  }

  final Uint8List readBack;
  try {
    readBack = await file.readAsBytes();
  } on Object catch (e) {
    throw StorageException('read-back ${file.path}', e);
  }

  if (readBack.length != bytes.length) {
    throw StorageException(
      'read-back ${file.path}',
      'wrote ${bytes.length} bytes, read back ${readBack.length}',
    );
  }
  for (int i = 0; i < bytes.length; i++) {
    if (readBack[i] != bytes[i]) {
      // Byte index only. The differing *values* may be save payload, and this
      // message reaches a diagnostic.
      throw StorageException(
        'read-back ${file.path}',
        'byte $i differs from what was written',
      );
    }
  }
}

/// Re-applies the platform's backup exclusion to [paths].
///
/// Injected as a plain function from `lib/runtime/`, because this package must
/// not depend on Flutter — its conformance suite has to run headless under
/// `dart test`. Dart function types are structural, so this matches
/// `stride_secure_store`'s `ReapplyBackupExclusion` without either package
/// importing the other.
///
/// **Null off iOS**, rather than a no-op closure, so "the control is not active
/// on this platform" and "the control ran and did nothing" stay
/// distinguishable. On Android the exclusion is declarative and stronger.
///
/// Must not throw: it runs on the commit path, and a refused
/// `setResourceValues` must never turn a durable save into a failed one.
///
/// See `packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md`.
typedef ReapplyBackupExclusion = Future<void> Function(List<String> paths);

/// Two snapshot slots as two files.
final class FileSnapshotStore implements SnapshotSlotStore {
  const FileSnapshotStore(this.layout, {this.reapplyExclusion});

  final StorageLayout layout;

  /// Re-applied after every write. See [ReapplyBackupExclusion].
  final ReapplyBackupExclusion? reapplyExclusion;

  File _fileFor(SnapshotSlot slot) =>
      slot == SnapshotSlot.a ? layout.slotA : layout.slotB;

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async {
    final File file = _fileFor(slot);
    if (!file.existsSync()) return null;
    try {
      // Returned exactly as found, including a partial file. The core
      // diagnoses truncation; an adapter that decided a short file was "empty"
      // would hide the one condition this read exists to surface.
      return await file.readAsBytes();
    } on Object catch (e) {
      throw StorageException('read ${file.path}', e);
    }
  }

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async {
    await layout.ensureExists();
    // Writes the slot file in place, and touches nothing else. The protocol's
    // atomicity comes from never being asked to write the live slot.
    final File file = _fileFor(slot);
    await writeVerified(file, bytes);
    // The slot is created by its first write, which is *after* the launch
    // sweep looked for it and correctly reported it missing. Without this the
    // slot is never excluded at all. The directory is included because
    // `ensureExists` may have just recreated it, and a recreated node carries
    // none of the attributes the old one had.
    await reapplyExclusion?.call(<String>[layout.root.path, file.path]);
  }

  @override
  Future<void> erase(SnapshotSlot slot) async {
    final File file = _fileFor(slot);
    if (file.existsSync()) await file.delete();
  }
}

/// The write-ahead journal as one append-only file.
final class FileLedgerJournal implements LedgerJournal {
  const FileLedgerJournal(this.layout, {this.reapplyExclusion});

  final StorageLayout layout;

  /// Re-applied after every append and after **both halves** of a compaction
  /// swap. See [ReapplyBackupExclusion].
  final ReapplyBackupExclusion? reapplyExclusion;

  @override
  Future<List<Uint8List>> readLines() async {
    final File file = layout.journal;
    if (!file.existsSync()) return <Uint8List>[];

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object catch (e) {
      throw StorageException('read ${file.path}', e);
    }
    if (bytes.isEmpty) return <Uint8List>[];

    final List<Uint8List> lines = <Uint8List>[];
    int start = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) {
        lines.add(Uint8List.sublistView(bytes, start, i + 1));
        start = i + 1;
      }
    }
    // A trailing fragment with no terminator is returned as a line anyway, so
    // the core can diagnose a torn tail. Swallowing it here would turn a
    // detectable interrupted append into silence.
    if (start < bytes.length) {
      lines.add(Uint8List.sublistView(bytes, start));
    }
    return lines;
  }

  @override
  Future<void> appendLine(Uint8List line) async {
    await layout.ensureExists();
    final File file = layout.journal;

    // Captured *before* the append, because the check afterwards is relative.
    //
    // The previous version compared total file length against record length —
    // `length < line.length` — which is vacuously satisfied for any journal
    // already larger than the incoming record, i.e. every append after the
    // first. It could not detect the failure its own comment claimed it caught.
    // Found by the F-06 Technical Critic.
    final int lengthBefore = file.existsSync() ? await file.length() : 0;

    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.append);
      await handle.writeFrom(line);
      await handle.flush();
    } on Object catch (e) {
      throw StorageException('append ${file.path}', e);
    } finally {
      await handle?.close();
    }

    // This is the protocol's commit point, so it gets a genuine read-back: the
    // file must have grown by exactly this record, and the trailing bytes must
    // be the ones we wrote.
    try {
      final int length = await file.length();
      if (length != lengthBefore + line.length) {
        throw StorageException(
          'append ${file.path}',
          'file went from $lengthBefore to $length bytes appending '
              '${line.length}',
        );
      }

      final RandomAccessFile tail = await file.open();
      try {
        await tail.setPosition(lengthBefore);
        final Uint8List actual = await tail.read(line.length);
        for (int i = 0; i < line.length; i++) {
          if (actual[i] != line[i]) {
            // Offset only. The bytes are a save payload.
            throw StorageException(
              'append read-back ${file.path}',
              'byte $i of the appended record differs from what was written',
            );
          }
        }
      } finally {
        await tail.close();
      }

      // Retained so the original guard's intent survives the rewrite.
      if (length < line.length) {
        throw StorageException(
          'append ${file.path}',
          'file is $length bytes after appending ${line.length}',
        );
      }
    } on StorageException {
      rethrow;
    } on Object catch (e) {
      throw StorageException('append read-back ${file.path}', e);
    }

    // The journal is created by its first append, after the launch sweep
    // reported it missing.
    await reapplyExclusion?.call(<String>[
      layout.root.path,
      layout.journal.path,
    ]);
  }

  @override
  Future<void> replaceLines(List<Uint8List> lines) async {
    await layout.ensureExists();

    final List<int> joined = <int>[];
    for (final Uint8List line in lines) {
      joined.addAll(line);
    }
    final Uint8List bytes = Uint8List.fromList(joined);

    // Sidecar first, then **rename** it over the journal.
    //
    // It used to write the sidecar and then `writeVerified` the journal —
    // which opens `FileMode.write` and therefore TRUNCATES IN PLACE. Between
    // that truncate and the flush the journal was neither the old set nor the
    // new one, and the old bytes were already gone: exactly the partial
    // journal this port contract forbids. Worse, `discardIncompleteCompaction`
    // then deletes the sidecar, which in that window is the only complete
    // copy on the device. A probe that killed the swap mid-flight recovered
    // zero of three records.
    //
    // A rename replaces the directory entry rather than the file contents, so
    // an interrupted swap leaves the old, longer journal — which is what the
    // contract promises and what replay is idempotent against.
    //
    // Note this is a different trade from the snapshot slots, which
    // deliberately avoid relying on rename: there the concern is durability
    // *ordering* after a power loss, and two slots remove the dependency
    // entirely. Here the concern is only that no observer sees a half-written
    // file, and rename gives that without a second journal.
    await writeVerified(layout.journalSidecar, bytes);
    // Excluded *before* the rename, not after. A death between the two leaves
    // the sidecar on disk, and the launch sweep reported it missing because it
    // did not exist then.
    await reapplyExclusion?.call(<String>[layout.journalSidecar.path]);

    await layout.journalSidecar.rename(layout.journal.path);
    // The journal path now names the sidecar's node, carrying the sidecar's
    // attributes. This is the one case that is a *regression* rather than a
    // gap: the journal was excluded, and a routine compaction silently
    // unprotected it. Without this line the journal travels in an iCloud
    // restore from the first compaction onward.
    // See `testARenameOverTheTopDropsTheExclusion`.
    await reapplyExclusion?.call(<String>[layout.journal.path]);
  }

  @override
  Future<bool> discardIncompleteCompaction() async {
    if (!layout.journalSidecar.existsSync()) return false;
    // Never adopted, always discarded: the pre-compaction journal is always
    // sufficient, so there is nothing in a sidecar worth recovering.
    await layout.journalSidecar.delete();
    return true;
  }

  @override
  Future<void> erase() async {
    if (layout.journal.existsSync()) await layout.journal.delete();
    if (layout.journalSidecar.existsSync()) {
      await layout.journalSidecar.delete();
    }
  }
}

/// The identity as it exists on disk: the lineage id **and the salt itself**.
///
/// The salt has to live somewhere durable. Regenerating it per launch re-keys
/// every origin, which fails the save closed on the very next start — the game
/// would open exactly once. It lives here rather than inside the save because
/// it is what the save's origin keys are validated *against*, and a value
/// cannot validate itself.
///
/// `stride_core` never sees this type. It receives only the fingerprint.
final class StoredIdentity {
  const StoredIdentity({required this.saveId, required this.salt});

  final String saveId;

  /// Protected local reconciliation metadata. Never enters a save, never
  /// reaches a diagnostic, never leaves the device.
  final Uint8List salt;

  ReconciliationIdentity get public => ReconciliationIdentity(
    saveId: saveId,
    saltFingerprint: OriginSaltPolicy.fingerprint(salt),
  );
}

/// What the identity file actually contains.
///
/// ## Why this is a sealed result and not a nullable [StoredIdentity]
///
/// The file has **three** legitimate shapes, not two, and the third one is
/// produced by this package's own code:
///
/// | Shape | Written by | Carries |
/// |---|---|---|
/// | absent | nothing yet | — |
/// | full | [FileIdentityStore.writeStored], i.e. the app | lineage id **and salt** |
/// | core-facing | [FileIdentityStore.write], i.e. `ReconciliationIdentityStore` | lineage id and salt **fingerprint** |
///
/// The core-facing shape is what `BootstrapCoordinator` writes when this class
/// is wired as its identity store directly, because the core only ever holds a
/// fingerprint — it has no salt to hand over and inventing one would be a
/// fabrication. That record is **complete and correct**: it faithfully records
/// everything that exists.
///
/// `readStored` could not express it. It required a `salt` key and reported its
/// absence as *"missing a required field"* — a corruption message for a record
/// this package writes on purpose. The next `readStored` after an orphan
/// replacement therefore threw out of a read path, which is the
/// permanent-next-launch-failure shape the save rules forbid. Found by the F-06
/// Bootstrap agent, fixed here rather than at the one call site that happened
/// to reach it.
sealed class IdentityRecord {
  const IdentityRecord();
}

/// No identity file exists. A new installation, or a completed reset.
final class IdentityAbsent extends IdentityRecord {
  const IdentityAbsent();
}

/// A complete record: the lineage id and the salt itself.
final class IdentityWithSalt extends IdentityRecord {
  const IdentityWithSalt(this.identity);

  final StoredIdentity identity;
}

/// A lineage id and a salt **fingerprint**, with no salt.
///
/// Not damage. The core-facing port has no salt to write, so this is what a
/// faithful record looks like when the app's own vault was not the writer.
///
/// A caller that needs to *pseudonymize* cannot proceed from this — a
/// fingerprint cannot rebuild a salt — and must fail closed rather than
/// substitute one. A caller that only needs the lineage id, or only needs to
/// compare fingerprints, can proceed exactly as before.
final class IdentityWithoutSalt extends IdentityRecord {
  const IdentityWithoutSalt({
    required this.saveId,
    required this.saltFingerprint,
  });

  final String saveId;
  final String saltFingerprint;

  ReconciliationIdentity get public =>
      ReconciliationIdentity(saveId: saveId, saltFingerprint: saltFingerprint);
}

/// The reconciliation identity as one small file.
final class FileIdentityStore implements ReconciliationIdentityStore {
  const FileIdentityStore(this.layout, {this.reapplyExclusion});

  final StorageLayout layout;

  /// Re-applied after every write. See [ReapplyBackupExclusion].
  ///
  /// Null on the platform this store is actually used on — iOS keeps the
  /// identity in the Keychain, not here. Wired anyway, because the symmetry is
  /// what stops the next platform being a special case.
  final ReapplyBackupExclusion? reapplyExclusion;

  /// Reads the file and names which of the three shapes it holds.
  ///
  /// Total over every shape this package can write, so no legitimate record
  /// arrives as an exception. It still throws for genuine damage — unreadable
  /// bytes, non-JSON, no lineage id — because those are not shapes, they are
  /// faults, and reporting a fault as absence would present a corrupt identity
  /// as a new installation.
  Future<IdentityRecord> readRecord() async {
    final Map<String, Object?> json = await _readJson();
    if (json.isEmpty) return const IdentityAbsent();

    final Object? saveId = json['saveId'];
    if (saveId is! String) {
      throw const StorageException(
        'decode identity',
        'the reconciliation identity file has no saveId',
      );
    }

    // The salt wins when present, because a fingerprint derived from it cannot
    // drift from it, whereas a stored fingerprint can.
    final Object? salt = json['salt'];
    if (salt is String) {
      return IdentityWithSalt(
        StoredIdentity(
          saveId: saveId,
          salt: Uint8List.fromList(base64Decode(salt)),
        ),
      );
    }

    final Object? fingerprint = json['saltFingerprint'];
    if (fingerprint is! String) {
      throw const StorageException(
        'decode identity',
        'the reconciliation identity file has neither a salt nor a fingerprint',
      );
    }
    return IdentityWithoutSalt(saveId: saveId, saltFingerprint: fingerprint);
  }

  /// Reads the full stored identity, salt included.
  ///
  /// For the app, which needs the salt to build a pseudonymizer.
  ///
  /// **Prefer [readRecord].** This projection cannot express the core-facing
  /// shape, and it fails closed on it rather than guessing: returning null
  /// would present a live lineage as a new installation and let a second
  /// identity be minted beside a save it can no longer interpret, and
  /// substituting an empty salt would be worse still — an empty salt is a
  /// *valid-looking* key, so every origin would be pseudonymized under a
  /// constant that is not secret at all.
  ///
  /// The message names the shape, so a reader of a crash report can tell a
  /// deliberate refusal from a decode accident.
  Future<StoredIdentity?> readStored() async => switch (await readRecord()) {
    IdentityAbsent() => null,
    final IdentityWithSalt r => r.identity,
    IdentityWithoutSalt() => throw const StorageException(
      'decode identity',
      'the reconciliation identity holds a salt fingerprint but no salt, so '
          'it cannot pseudonymize an origin. It was written through the '
          'core-facing ReconciliationIdentityStore port, which has no salt to '
          'write. Use readRecord() to handle this shape.',
    ),
  };

  /// Writes the full identity, salt included.
  Future<void> writeStored(StoredIdentity identity) async {
    await layout.ensureExists();
    final String text = jsonEncode(<String, Object?>{
      'saveId': identity.saveId,
      'salt': base64Encode(identity.salt),
    });
    await writeVerified(layout.identity, Uint8List.fromList(utf8.encode(text)));
    await reapplyExclusion?.call(<String>[
      layout.root.path,
      layout.identity.path,
    ]);
  }

  Future<Map<String, Object?>> _readJson() async {
    final File file = layout.identity;
    if (!file.existsSync()) return const <String, Object?>{};

    final String text;
    try {
      text = await file.readAsString();
    } on Object catch (e) {
      throw StorageException('read ${file.path}', e);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      // Unreadable, not absent. Returning "absent" would present a corrupt
      // identity as a new installation, and the bootstrap would then mint a
      // second identity beside a save it can no longer interpret.
      throw const StorageException(
        'decode identity',
        'the reconciliation identity file is not valid JSON',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const StorageException(
        'decode identity',
        'the reconciliation identity file is not an object',
      );
    }
    return decoded;
  }

  /// The core-facing projection: lineage id and fingerprint, never the salt.
  ///
  /// Total over all three shapes, because both of the present ones can produce
  /// a fingerprint — one derives it, the other has it stored.
  @override
  Future<ReconciliationIdentity?> read() async => switch (await readRecord()) {
    IdentityAbsent() => null,
    final IdentityWithSalt r => r.identity.public,
    final IdentityWithoutSalt r => r.public,
  };

  /// Writes the core-facing identity: lineage id and salt **fingerprint**.
  ///
  /// An earlier version of this threw, on the reasoning that a fingerprint
  /// cannot reconstruct a salt and so the core had no business writing one.
  /// That was wrong — not about salts, but about types. `write` is part of the
  /// port contract, and an adapter that throws where the contract says it
  /// writes is a Liskov violation; the conformance suite caught it, which is
  /// exactly what a conformance suite is for.
  ///
  /// It writes what it was given and preserves any salt already on disk, so a
  /// record written here round-trips through [read] without ever inventing or
  /// discarding salt material.
  @override
  Future<void> write(ReconciliationIdentity identity) async {
    await layout.ensureExists();

    final Map<String, Object?> existing = await _readJson();
    final Object? salt = existing['salt'];

    final String text = jsonEncode(<String, Object?>{
      'saveId': identity.saveId,
      'saltFingerprint': identity.saltFingerprint,
      // Carried forward, never derived. Dropping it would silently re-key
      // every origin on the next launch.
      if (salt is String) 'salt': salt,
    });
    await writeVerified(layout.identity, Uint8List.fromList(utf8.encode(text)));
    await reapplyExclusion?.call(<String>[
      layout.root.path,
      layout.identity.path,
    ]);
  }

  @override
  Future<void> erase() async {
    if (layout.identity.existsSync()) await layout.identity.delete();
  }
}
