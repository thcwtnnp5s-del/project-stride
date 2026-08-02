// In-memory storage with an explicit durability model.
//
// The central idea is a *durability* model, not a failure model. "Fail here" is
// not enough: the interesting bug is the write that succeeded, was acknowledged,
// and did not survive the power loss. So bytes land in `_pending` and move to
// `_committed` only on an explicit flush; `reboot()` discards `_pending` and
// returns a NEW instance, so a test physically cannot leak in-memory state
// across the restart it claims to be testing.
//
// A test that passes without the implementation ever flushing is proving that
// this harness is lossless, not that the code is correct.

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

/// What a fault does when it fires.
enum FaultEffect {
  /// The operation does nothing and throws.
  failBefore,

  /// The operation **fully applies**, then throws — the lost acknowledgement.
  failAfter,

  /// A partial write of `truncateTo` bytes, then throws.
  truncate,

  /// A partial write of `truncateTo` bytes that returns *successfully*.
  ///
  /// Some platforms really do this, and no clean-failure model can express it.
  silentShortWrite,

  /// The bytes land in pending and are never made durable.
  dropDurability,
}

/// One scheduled fault, matched by operation kind, path, and ordinal.
///
/// Matched positionally rather than by a clock or `Random`: the core forbids
/// both, and the tests must not need them either.
final class Fault {
  const Fault({
    required this.op,
    required this.path,
    required this.effect,
    this.ordinal = 0,
    this.truncateTo,
  });

  final String op;
  final String path;
  final FaultEffect effect;
  final int ordinal;
  final int? truncateTo;
}

/// A recorded operation.
final class StoreOp {
  const StoreOp(this.kind, this.path, this.bytes);

  final String kind;
  final String path;
  final int bytes;

  @override
  String toString() => '$kind($path, $bytes)';
}

/// Thrown by a fault. Caught only by the harness, never by production code.
final class InjectedFault implements Exception {
  const InjectedFault(this.message);
  final String message;

  @override
  String toString() => 'InjectedFault: $message';
}

/// Backing bytes shared by the two ports, so a "device" is one object.
final class FaultingDevice {
  FaultingDevice();

  FaultingDevice._committed(Map<String, Uint8List> committed) {
    _committed.addAll(committed);
  }

  final Map<String, Uint8List> _committed = <String, Uint8List>{};
  final Map<String, Uint8List> _pending = <String, Uint8List>{};
  final List<Fault> _faults = <Fault>[];
  final Map<String, int> _counts = <String, int>{};

  /// Every operation attempted, in order.
  final List<StoreOp> trace = <StoreOp>[];

  void plan(List<Fault> faults) {
    _faults
      ..clear()
      ..addAll(faults);
  }

  /// Discards everything not durable and returns a fresh device.
  ///
  /// A new object on purpose — a `reboot()` that mutated in place would let a
  /// test keep its reference and share memory across the "restart", which is
  /// theatre rather than a test.
  FaultingDevice reboot() => FaultingDevice._committed(_committed);

  /// Canonical dump of durable bytes. Legible failures, not object graphs.
  String image() {
    final List<String> keys = _committed.keys.toList()..sort();
    return keys
        .map(
          (String k) =>
              '$k:${_committed[k]!.length}:${crc32cHex(_committed[k]!)}',
        )
        .join('\n');
  }

  int flushCountFor(String path) => _counts['flush:$path'] ?? 0;

  Fault? _match(String op, String path) {
    final String key = '$op:$path';
    final int n = _counts[key] ?? 0;
    _counts[key] = n + 1;
    for (final Fault f in _faults) {
      if (f.op == op && f.path == path && f.ordinal == n) return f;
    }
    return null;
  }

  Uint8List? read(String path) {
    trace.add(StoreOp('read', path, _committed[path]?.length ?? 0));
    final Uint8List? bytes = _committed[path];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  void write(String path, Uint8List bytes, {bool append = false}) {
    trace.add(StoreOp(append ? 'append' : 'write', path, bytes.length));
    final Fault? fault = _match(append ? 'append' : 'write', path);

    if (fault?.effect == FaultEffect.failBefore) {
      throw InjectedFault('$path write refused');
    }

    Uint8List payload = bytes;
    final bool partial =
        fault?.effect == FaultEffect.truncate ||
        fault?.effect == FaultEffect.silentShortWrite;
    if (partial) {
      payload = Uint8List.sublistView(bytes, 0, fault!.truncateTo ?? 0);
    }

    final Uint8List existing = append
        ? (_pending[path] ?? _committed[path] ?? Uint8List(0))
        : Uint8List(0);
    _pending[path] = Uint8List.fromList(<int>[...existing, ...payload]);

    if (fault?.effect == FaultEffect.dropDurability) return;

    if (fault?.effect == FaultEffect.truncate) {
      _flush(path);
      throw InjectedFault('$path truncated at ${fault!.truncateTo}');
    }
    if (fault?.effect == FaultEffect.silentShortWrite) {
      _flush(path);
      return;
    }

    _flush(path);

    if (fault?.effect == FaultEffect.failAfter) {
      throw InjectedFault('$path written but acknowledgement lost');
    }
  }

  void _flush(String path) {
    _counts['flush:$path'] = (_counts['flush:$path'] ?? 0) + 1;
    trace.add(StoreOp('flush', path, _pending[path]?.length ?? 0));
    final Uint8List? pending = _pending.remove(path);
    if (pending != null) _committed[path] = pending;
  }

  void erase(String path) {
    trace.add(const StoreOp('erase', '', 0));
    _committed.remove(path);
    _pending.remove(path);
  }

  bool exists(String path) => _committed.containsKey(path);

  /// Directly seeds durable bytes, for corruption fixtures.
  void seed(String path, Uint8List bytes) =>
      _committed[path] = Uint8List.fromList(bytes);

  Uint8List? committedBytes(String path) => _committed[path];
}

/// Snapshot slots over a [FaultingDevice].
final class FaultingSnapshotStore implements SnapshotSlotStore {
  FaultingSnapshotStore(this.device);

  final FaultingDevice device;

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async =>
      device.read(slot.fileName);

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async =>
      device.write(slot.fileName, bytes);

  @override
  Future<void> erase(SnapshotSlot slot) async => device.erase(slot.fileName);
}

/// A journal over a [FaultingDevice].
final class FaultingJournal implements LedgerJournal {
  FaultingJournal(this.device);

  static const String path = 'journal';
  static const String sidecar = 'journal.compacting';

  final FaultingDevice device;

  @override
  Future<List<Uint8List>> readLines() async {
    final Uint8List? bytes = device.read(path);
    if (bytes == null || bytes.isEmpty) return <Uint8List>[];

    final List<Uint8List> lines = <Uint8List>[];
    int start = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) {
        lines.add(Uint8List.sublistView(bytes, start, i + 1));
        start = i + 1;
      }
    }
    // A trailing fragment is returned as a line anyway, so the core can
    // diagnose a torn tail rather than have this quietly swallow it.
    if (start < bytes.length) {
      lines.add(Uint8List.sublistView(bytes, start));
    }
    return lines;
  }

  @override
  Future<void> appendLine(Uint8List line) async =>
      device.write(path, line, append: true);

  @override
  Future<void> replaceLines(List<Uint8List> lines) async {
    final List<int> joined = <int>[];
    for (final Uint8List l in lines) {
      joined.addAll(l);
    }
    // Sidecar first, then swap — so an interrupted compaction leaves the old,
    // longer journal rather than a partial one.
    device.write(sidecar, Uint8List.fromList(joined));
    device.write(path, Uint8List.fromList(joined));
    device.erase(sidecar);
  }

  @override
  Future<bool> discardIncompleteCompaction() async {
    if (!device.exists(sidecar)) return false;
    device.erase(sidecar);
    return true;
  }

  @override
  Future<void> erase() async => device.erase(path);
}
