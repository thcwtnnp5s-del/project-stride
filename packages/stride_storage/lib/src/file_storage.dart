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
/// | **envelope validated** | Those bytes parse, and their digest matches | `unframe` + decode |
/// | **protocol commit durable** | All of the above, *and* the previous valid slot is untouched | The protocol, not this class |
///
/// This adapter delivers the first four. The fifth is a property of the
/// two-slot protocol in `stride_core` and cannot be delivered by any single
/// file operation.
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
Future<void> _writeVerified(File file, Uint8List bytes) async {
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

/// Two snapshot slots as two files.
final class FileSnapshotStore implements SnapshotSlotStore {
  const FileSnapshotStore(this.layout);

  final StorageLayout layout;

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
    await _writeVerified(_fileFor(slot), bytes);
  }

  @override
  Future<void> erase(SnapshotSlot slot) async {
    final File file = _fileFor(slot);
    if (file.existsSync()) await file.delete();
  }
}

/// The write-ahead journal as one append-only file.
final class FileLedgerJournal implements LedgerJournal {
  const FileLedgerJournal(this.layout);

  final StorageLayout layout;

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

    // This is the protocol's commit point, so it gets the same read-back as a
    // snapshot: the file must now be at least as long as what we appended.
    // Cheaper than re-reading the whole journal, and it catches the failure
    // that matters — an append that reported success and landed nothing.
    try {
      final int length = await file.length();
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
  }

  @override
  Future<void> replaceLines(List<Uint8List> lines) async {
    await layout.ensureExists();

    final List<int> joined = <int>[];
    for (final Uint8List line in lines) {
      joined.addAll(line);
    }
    final Uint8List bytes = Uint8List.fromList(joined);

    // Sidecar first. If the swap does not survive, the old and longer journal
    // remains — never a partial one. Replay is idempotent, so a journal that
    // is longer than necessary costs a little startup work and nothing else.
    await _writeVerified(layout.journalSidecar, bytes);
    await _writeVerified(layout.journal, bytes);
    if (layout.journalSidecar.existsSync()) {
      await layout.journalSidecar.delete();
    }
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

/// The reconciliation identity as one small file.
final class FileIdentityStore implements ReconciliationIdentityStore {
  const FileIdentityStore(this.layout);

  final StorageLayout layout;

  /// Reads the full stored identity, salt included.
  ///
  /// For the app, which needs the salt to build a pseudonymizer. The core-facing
  /// [read] projects this to a fingerprint.
  Future<StoredIdentity?> readStored() async {
    final Map<String, Object?> json = await _readJson();
    if (json.isEmpty) return null;

    final Object? saveId = json['saveId'];
    final Object? salt = json['salt'];
    if (saveId is! String || salt is! String) {
      throw const StorageException(
        'decode identity',
        'the reconciliation identity file is missing a required field',
      );
    }
    return StoredIdentity(
      saveId: saveId,
      salt: Uint8List.fromList(base64Decode(salt)),
    );
  }

  /// Writes the full identity, salt included.
  Future<void> writeStored(StoredIdentity identity) async {
    await layout.ensureExists();
    final String text = jsonEncode(<String, Object?>{
      'saveId': identity.saveId,
      'salt': base64Encode(identity.salt),
    });
    await _writeVerified(
      layout.identity,
      Uint8List.fromList(utf8.encode(text)),
    );
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

  @override
  Future<ReconciliationIdentity?> read() async {
    final StoredIdentity? stored = await readStored();
    return stored?.public;
  }

  /// Writes an identity the core supplied.
  ///
  /// Refused, because the core only ever holds a fingerprint and a fingerprint
  /// cannot reconstruct the salt. The app writes the identity through
  /// [writeStored] before startup, so this path exists only to satisfy the
  /// port and to fail loudly if anyone routes through it by accident.
  @override
  Future<void> write(ReconciliationIdentity identity) async {
    throw const StorageException(
      'write identity',
      'the salt cannot be recovered from a fingerprint; use writeStored',
    );
  }

  @override
  Future<void> erase() async {
    if (layout.identity.existsSync()) await layout.identity.delete();
  }
}
