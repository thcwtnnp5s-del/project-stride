/// Storage ports for the save system.
///
/// Pure Dart. `dart:io` is forbidden in this package, so both implementations
/// live in the app layer; these interfaces are the whole of what the core
/// knows about a filesystem, which is: bytes go in, bytes come out, and
/// sometimes a write does not survive a power loss.
///
/// The transaction protocol is deliberately **not** here — it lives in
/// `SaveRepository`, inside the core. The protocol *is* the crash-safety
/// argument, and pushed into the app layer it could not be tested by
/// `dart test` on Windows in milliseconds, which is the one property the whole
/// verification strategy rests on.
library;

import 'dart:typed_data';

import '../save/save_outcomes.dart';

/// Durable storage for the two snapshot slots.
///
/// Correctness does not depend on rename semantics, on a current-slot pointer,
/// or on any ordering between the two slots. It depends on one promise:
/// **[write] must not touch the other slot.**
abstract interface class SnapshotSlotStore {
  /// The exact bytes last written to [slot], or null if it has never been
  /// written or its file is absent.
  ///
  /// Never throws for absence. A partially-written slot must be returned as-is,
  /// bytes and all — the core diagnoses truncation; the adapter does not get to
  /// decide that a short file is "empty".
  Future<Uint8List?> read(SnapshotSlot slot);

  /// Writes [bytes] to [slot], returning **only once they are durable** on the
  /// storage medium (`flush: true`, i.e. fsync).
  ///
  /// Must write the slot file in place. Must not write through a temp file and
  /// rename, and must not read, write, or delete the other slot.
  Future<void> write(SnapshotSlot slot, Uint8List bytes);

  /// Removes [slot]. Full reset only.
  Future<void> erase(SnapshotSlot slot);
}

/// The write-ahead journal: a bounded durability and recovery log.
///
/// **Not an event store.** Records are retained only until their grant is
/// represented in a verified snapshot and compaction is safe. An uncompacted
/// journal is a permanent unbounded step history, because every reconciliation
/// record carries a granted-slice map — exactly what the retention ruling
/// bounds, reintroduced through the back door.
abstract interface class LedgerJournal {
  /// Every `\n`-terminated record, in append order.
  ///
  /// A trailing fragment **without** a terminator is returned as a line anyway,
  /// so the core can diagnose a torn tail. An adapter that silently swallows it
  /// hides the one condition this method exists to surface.
  Future<List<Uint8List>> readLines();

  /// Appends one record, returning **only once the bytes and the file's length
  /// metadata are durable**.
  ///
  /// This is the project's commit point. If it returns, the transaction
  /// survives power loss. If it throws, the caller must assume the record may
  /// or may not be present — the torn-tail and duplicate-transaction paths
  /// cover both.
  ///
  /// Must open in append mode and must never rewrite existing bytes.
  Future<void> appendLine(Uint8List line);

  /// Replaces the journal with exactly [lines]. Compaction only.
  ///
  /// If the swap does not survive, the **old, longer** journal must remain.
  /// Never a partial one.
  Future<void> replaceLines(List<Uint8List> lines);

  /// Removes any leftover compaction sidecar, returning true if one was found.
  ///
  /// How a filesystem-level condition reaches a pure core as a typed diagnosis
  /// without the core learning what a file is.
  Future<bool> discardIncompleteCompaction();

  /// Empties the journal. Full reset only.
  Future<void> erase();
}
