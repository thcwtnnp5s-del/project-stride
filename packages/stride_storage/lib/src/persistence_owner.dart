/// One isolate owns the save directory. Everyone else asks it.
///
/// ## The finding this closes
///
/// `FileTransactionLock` is a real kernel lock, and `concurrency_test.dart`
/// proves it excludes a second **process**. It does not follow — and it is not
/// true — that it excludes a second **isolate**.
///
/// On Linux and macOS, Dart implements `RandomAccessFile.lock` with `fcntl`
/// record locks. `fcntl` locks are owned by the *process*, not by the file
/// descriptor and not by the thread: a second open in the same process asking
/// for the same range is **granted** it, and closing any descriptor onto that
/// file drops the whole process's locks. Two isolates share one process. So on
/// exactly the platform whose background-delivery case the lock's own
/// documentation cites — an Android Health Connect worker isolate running
/// beside the app — the lock is transparent.
///
/// Windows is different (`LockFileEx` is per-handle, so a second isolate *is*
/// refused), which is worse rather than better: the property would look proven
/// on the development machine and be absent on the shipping platform.
///
/// **Therefore the OS file lock alone is insufficient for same-process
/// isolates.** This file adds the layer that is.
///
/// ## The three layers, all retained
///
/// | Layer | Serializes | Does not cover |
/// |---|---|---|
/// | **This owner isolate** | callers *within one process* | a second process |
/// | **`FileTransactionLock`** | *separate processes* | isolates inside one process on POSIX |
/// | **Compare-and-swap** | stale revisions, whatever the source | nothing it is asked to |
///
/// None replaces another. The owner is not a reason to drop the OS lock: a
/// second OS process has no way to reach this isolate's ports. The OS lock is
/// not a reason to drop CAS: CAS is what catches a caller committing against a
/// head that moved underneath it, which is a logical race and not a locking
/// one. See `TECHNICAL/PERSISTENCE_CONCURRENCY.md`.
///
/// ## What crosses the port
///
/// Primitives, `String`s, `Uint8List`s and `SendPort`s. Nothing else.
///
/// `GameState` and `GameEvent` are **not** sent as objects. They travel through
/// the existing save codec: state as `encodeSnapshot`/`decodeEnvelope`, events
/// as `encodeJournalLine`/`decodeJournalLine`. That is deliberate. Dart will
/// happily deep-copy most object graphs between isolates in one group, and
/// relying on that would make the wire format an accident of whichever fields
/// the engine happened to have — the save codec is the one encoding that is
/// versioned, digested, and already tested for round-trip fidelity.
///
/// ## Failure is typed, never a hang — and the two kinds stay apart
///
/// **Storage was busy.** Another *process* holds the OS lock. The owner was
/// there, took no lock, and wrote nothing, so this is the core's own sealed
/// result — `LoadRefusal.storageBusy`, `CommitRefusal.storageBusy`,
/// `CompactionRefusal.storageBusy`, `EraseRefusal.storageBusy` — passed
/// straight through from `SaveRepository`. Ordinary, transient, retry.
///
/// **The owner was unreachable.** It died — killed, uncaught error, platform
/// pressure — or a reply never came at all. That is [PersistenceUnavailable],
/// and it is deliberately *not* `storageBusy`: an owner killed between a
/// durable journal append and its reply leaves an outcome nobody can report,
/// and `storageBusy`'s "nothing was written" would be a false statement.
///
/// The unreachable case is detected two ways. The supervisor sees the isolate
/// exit and fails every waiting caller; and independently, every request
/// carries a timer, because a supervision scheme that is merely *believed* to
/// be complete is how a save system acquires a permanent silent hang.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import 'file_lock.dart';
import 'file_storage.dart';

// ---------------------------------------------------------------------------
// Vocabulary
// ---------------------------------------------------------------------------

/// Why the owner isolate could not answer.
///
/// Carried by [PersistenceUnavailable]. It does **not** duplicate the core save
/// vocabulary: storage conditions the owner observed are reported in the core's
/// own sealed results and never reach this enum. This describes the channel to
/// the owner, which `stride_core` has no isolates, no ports, and no way to
/// observe.
///
/// The member names match the core's for the one case that can mean either
/// thing, so a reader does not have to learn two words for one condition.
enum PersistenceFailure {
  /// The owner was reached, and something inside it reported contention that
  /// could not be expressed as a typed result.
  ///
  /// Vestigial by design: `SaveRepository` now returns a typed `storageBusy`
  /// on every operation, so nothing produces this today. It is kept because a
  /// future refactor reintroducing a busy *throw* must not surface to players
  /// as a broken device — see `_Owner._classify`.
  storageBusy,

  /// A request was accepted and no reply came back within its deadline.
  ///
  /// The backstop fired, which means supervision missed something. The caller
  /// is safe either way; this one is also a bug report.
  lockTimeout,

  /// The owner isolate is not there — it never started, it died, or it was
  /// shut down.
  storageUnavailable,
}

/// The owner isolate could not be reached, or died holding the question.
///
/// ## Why this is not folded into `storageBusy`
///
/// `storageBusy` means something specific and reassuring: **the transaction
/// lock was taken before anything was written, so nothing was written.** The
/// repository can promise that because it was there.
///
/// A dead owner cannot promise it. If the isolate is killed after the journal
/// append and before the reply, the transaction *is* durable and a
/// `CommitRefused(storageBusy, 'nothing was written')` would be a lie — the
/// caller would withhold the step cursor over a batch that had in fact
/// committed, or worse, trust the phrase in some later reasoning. So an
/// unreachable owner is an **indeterminate** outcome and gets its own type.
///
/// Both are safe to treat the same way at the call site — do not release the
/// cursor, try again — because F-04 grants `max(0, observed - granted)` and the
/// journal absorbs an identical duplicate. They must still be distinguishable,
/// because one of them is a normal Tuesday and the other is a fault that wants
/// an owner restart.
final class PersistenceUnavailable implements Exception {
  const PersistenceUnavailable(this.failure, this.detail);

  final PersistenceFailure failure;
  final String detail;

  @override
  String toString() => 'PersistenceUnavailable(${failure.name}): $detail';
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Everything the owner isolate needs to build its own world.
///
/// A `ContentRegistry` cannot cross a port meaningfully, so the owner is given
/// the content *files* and loads them itself. That also keeps the owner honest:
/// it validates content with the same loader the app does, rather than
/// inheriting a registry someone else already blessed.
final class PersistenceOwnerConfig {
  const PersistenceOwnerConfig({
    required this.storageRoot,
    required this.contentFiles,
    required this.balanceProfileId,
    this.lockTimeout = const Duration(seconds: 5),
    this.maxCommitRetries = 3,
    this.treatAsRelease = false,
  });

  /// The directory a [StorageLayout] is built over.
  final Directory storageRoot;

  /// Filename to contents, exactly as `ContentSource` takes them.
  final Map<String, String> contentFiles;

  /// The balance profile id, e.g. `BalanceProfile.productionId.value`.
  final String balanceProfileId;

  final Duration lockTimeout;
  final int maxCommitRetries;
  final bool treatAsRelease;

  List<Object?> _wire() => <Object?>[
    storageRoot.path,
    Map<String, String>.from(contentFiles),
    balanceProfileId,
    lockTimeout.inMilliseconds,
    maxCommitRetries,
    treatAsRelease,
  ];
}

// ---------------------------------------------------------------------------
// Wire tags
// ---------------------------------------------------------------------------

const String _tagRequest = 'req';
const String _tagResponse = 'res';
const String _tagRegister = 'register';
const String _tagUnregister = 'unregister';
const String _tagRegistered = 'registered';
const String _tagOwnerDown = 'owner-down';
const String _tagOwnerUp = 'owner-up';
const String _tagOwnerReady = 'owner-ready';
const String _tagOwnerFailed = 'owner-failed';

const String _opLoad = 'load';
const String _opCommit = 'commit';
const String _opCompact = 'compact';
const String _opErase = 'erase';
const String _opStats = 'stats';
const String _opShutdown = 'shutdown';

const String _statusOk = 'ok';
const String _statusFail = 'fail';

// ---------------------------------------------------------------------------
// The endpoint — the only thing a caller isolate needs
// ---------------------------------------------------------------------------

/// The address of a running owner. Sendable to any isolate.
///
/// It names the **supervisor**, not the owner, and that is the whole design.
/// A `SendPort` to a dead isolate accepts messages and drops them silently:
/// there is no error, no exception, and no close event. A caller holding only
/// the owner's port would wait forever. The supervisor lives in the isolate
/// that spawned the owner, outlives it by construction, and is therefore the
/// only party that can tell a caller the owner is gone.
final class PersistenceEndpoint {
  const PersistenceEndpoint(this.supervisor);

  final SendPort supervisor;
}

// ---------------------------------------------------------------------------
// Supervisor — runs in the isolate that spawned the owner
// ---------------------------------------------------------------------------

/// A spawned persistence-owner isolate, plus its supervision.
final class PersistenceOwner {
  PersistenceOwner._(this._config);

  final PersistenceOwnerConfig _config;

  final ReceivePort _control = ReceivePort();
  final Set<SendPort> _clients = <SendPort>{};

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _exit;
  ReceivePort? _errors;
  bool _shutDown = false;
  String _downDetail = 'the persistence owner has not started';

  /// True while an owner isolate is running and reachable.
  bool get alive => _commands != null;

  /// Hand this to any isolate that needs persistence.
  PersistenceEndpoint get endpoint => PersistenceEndpoint(_control.sendPort);

  /// Spawns the owner and waits until it is serving.
  ///
  /// Throws [PersistenceUnavailable] with [PersistenceFailure.storageUnavailable]
  /// if the owner cannot start — a bad content pack, an unwritable directory.
  /// Failing to start is not a hang.
  static Future<PersistenceOwner> spawn(
    PersistenceOwnerConfig config, {
    Duration startTimeout = const Duration(seconds: 30),
  }) async {
    final PersistenceOwner owner = PersistenceOwner._(config);
    owner._control.listen(owner._onControl);
    await owner._start(startTimeout);
    return owner;
  }

  Future<void> _start(Duration startTimeout) async {
    final ReceivePort ready = ReceivePort();
    final ReceivePort exit = ReceivePort();
    final ReceivePort errors = ReceivePort();

    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _ownerMain,
        <Object?>[ready.sendPort, _config._wire()],
        onExit: exit.sendPort,
        onError: errors.sendPort,
        // The owner must never survive an uncaught error in a half-known
        // state. It dies, the supervisor sees the exit, and every caller is
        // told — which is a typed failure. A limping owner is not.
        errorsAreFatal: true,
        debugName: 'stride-persistence-owner',
      );
    } on Object catch (e) {
      ready.close();
      exit.close();
      errors.close();
      throw PersistenceUnavailable(
        PersistenceFailure.storageUnavailable,
        'could not spawn the persistence owner: $e',
      );
    }

    final Completer<Object?> first = Completer<Object?>();
    ready.listen((Object? message) {
      if (!first.isCompleted) first.complete(message);
    });

    final Object? announcement;
    try {
      announcement = await first.future.timeout(startTimeout);
    } on TimeoutException {
      isolate.kill(priority: Isolate.immediate);
      ready.close();
      exit.close();
      errors.close();
      throw PersistenceUnavailable(
        PersistenceFailure.storageUnavailable,
        'the persistence owner did not announce itself within $startTimeout',
      );
    } finally {
      ready.close();
    }

    if (announcement is! List<Object?> ||
        announcement.isEmpty ||
        announcement.first != _tagOwnerReady) {
      final String detail =
          announcement is List<Object?> &&
              announcement.length > 1 &&
              announcement.first == _tagOwnerFailed
          ? '${announcement[1]}'
          : 'the persistence owner announced $announcement';
      isolate.kill(priority: Isolate.immediate);
      exit.close();
      errors.close();
      throw PersistenceUnavailable(
        PersistenceFailure.storageUnavailable,
        detail,
      );
    }

    _isolate = isolate;
    _commands = announcement[1] as SendPort;
    _exit = exit;
    _errors = errors;
    // Replaced now that it has started, so a later death does not report the
    // pre-start reason. A stale detail on a real failure is how a crash report
    // sends someone looking in the wrong place.
    _downDetail = 'the persistence owner isolate exited';

    errors.listen((Object? message) {
      // errorsAreFatal means the exit follows; this only supplies the reason.
      _downDetail = 'the persistence owner failed: $message';
    });
    exit.listen((Object? _) => _declareDown(_downDetail));
  }

  void _declareDown(String detail) {
    if (_commands == null) return;
    _commands = null;
    _downDetail = detail;
    _exit?.close();
    _errors?.close();
    _exit = null;
    _errors = null;
    _isolate = null;
    for (final SendPort client in _clients) {
      client.send(<Object?>[_tagOwnerDown, detail]);
    }
  }

  void _onControl(Object? message) {
    if (message is! List<Object?> || message.isEmpty) return;
    switch (message.first) {
      case _tagRegister:
        final SendPort client = message[1] as SendPort;
        _clients.add(client);
        // The reply carries the current truth, so a client that registers
        // during a death cannot end up waiting on an owner that is already
        // gone. Registering and *then* being told is a race; being told as
        // part of registering is not.
        client.send(<Object?>[
          _tagRegistered,
          message[2],
          _commands,
          _commands == null ? _downDetail : null,
        ]);
      case _tagUnregister:
        _clients.remove(message[1] as SendPort);
    }
  }

  /// Kills the owner without letting it finish. Models process pressure and an
  /// uncaught error; used by the restart probes.
  Future<void> kill() async {
    final Isolate? isolate = _isolate;
    if (isolate == null) return;
    // Set before the kill, so the exit listener — which fires asynchronously
    // and cannot know why — reports the real cause.
    _downDetail =
        'the persistence owner was killed; the outcome of any request that '
        'was in flight is unknown';
    isolate.kill(priority: Isolate.immediate);
    // The exit port delivers asynchronously. Waiting for it here means a test
    // that kills and then asserts is asserting against a settled supervisor.
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (_commands != null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (_commands != null) _declareDown(_downDetail);
  }

  /// Brings a new owner up over the same directory and tells every registered
  /// client about it.
  ///
  /// Recovery is deliberately explicit rather than automatic. An owner that
  /// respawns itself after an uncaught error would loop on a save it cannot
  /// read, and each loop takes the OS lock — turning a diagnosable fault into
  /// a directory nothing else can open.
  Future<void> restart({
    Duration startTimeout = const Duration(seconds: 30),
  }) async {
    if (_shutDown) {
      throw const PersistenceUnavailable(
        PersistenceFailure.storageUnavailable,
        'this owner has been shut down and cannot be restarted',
      );
    }
    await kill();
    await _start(startTimeout);
    final SendPort commands = _commands!;
    for (final SendPort client in _clients) {
      client.send(<Object?>[_tagOwnerUp, commands]);
    }
  }

  /// Asks the owner to drain its queue and exit, then stops supervising.
  Future<void> shutdown() async {
    _shutDown = true;
    final SendPort? commands = _commands;
    if (commands != null) {
      final ReceivePort done = ReceivePort();
      commands.send(<Object?>[_tagRequest, 0, done.sendPort, _opShutdown]);
      try {
        await done.first.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // Fall through to the kill below. A shutdown that hangs is still a
        // shutdown.
      } finally {
        done.close();
      }
    }
    await kill();
    _declareDown('the persistence owner was shut down');
    _clients.clear();
    _control.close();
  }
}

// ---------------------------------------------------------------------------
// Client — runs in any isolate, including the one that spawned the owner
// ---------------------------------------------------------------------------

/// Diagnostic counters read straight out of the owner.
///
/// [maxConcurrentHandlers] is the assertion that matters: the owner runs one
/// request at a time. If it were ever 2, the layer would be decorative.
final class PersistenceOwnerStats {
  const PersistenceOwnerStats({
    required this.served,
    required this.maxConcurrentHandlers,
    required this.byOperation,
    required this.trace,
  });

  final int served;
  final int maxConcurrentHandlers;
  final Map<String, int> byOperation;

  /// `begin:<op>:<id>` / `end:<op>:<id>`, most recent last. Bounded.
  final List<String> trace;
}

/// A caller's connection to the owner.
///
/// One per isolate. Cheap to make, and it must be [close]d or its
/// `ReceivePort` keeps the isolate alive.
final class PersistenceClient {
  PersistenceClient._(this._endpoint, this._requestTimeout);

  final PersistenceEndpoint _endpoint;
  final Duration _requestTimeout;

  final ReceivePort _inbox = ReceivePort();
  final Map<int, _Pending> _pending = <int, _Pending>{};

  SendPort? _commands;
  String _downDetail = 'not connected';
  int _nextRequestId = 1;
  bool _closed = false;

  /// Registers with the supervisor and returns once the current owner is known.
  static Future<PersistenceClient> connect(
    PersistenceEndpoint endpoint, {
    Duration requestTimeout = const Duration(seconds: 30),
    Duration connectTimeout = const Duration(seconds: 30),
  }) async {
    final PersistenceClient client = PersistenceClient._(
      endpoint,
      requestTimeout,
    );
    client._inbox.listen(client._onMessage);

    final Completer<void> registered = Completer<void>();
    client._registration = registered;
    endpoint.supervisor.send(<Object?>[
      _tagRegister,
      client._inbox.sendPort,
      0,
    ]);
    try {
      await registered.future.timeout(connectTimeout);
    } on TimeoutException {
      client._inbox.close();
      throw PersistenceUnavailable(
        PersistenceFailure.storageUnavailable,
        'the persistence supervisor did not answer within $connectTimeout',
      );
    }
    return client;
  }

  Completer<void>? _registration;

  bool get connected => _commands != null;

  void _onMessage(Object? message) {
    if (message is! List<Object?> || message.isEmpty) return;
    switch (message.first) {
      case _tagRegistered:
        _commands = message[2] as SendPort?;
        _downDetail = (message[3] as String?) ?? 'not connected';
        final Completer<void>? registration = _registration;
        _registration = null;
        if (registration != null && !registration.isCompleted) {
          registration.complete();
        }
      case _tagOwnerUp:
        _commands = message[1] as SendPort;
      case _tagOwnerDown:
        _commands = null;
        _downDetail = '${message[1]}';
        // Every in-flight request is failed here, and this is the reason the
        // supervisor exists. Without it these completers are never touched
        // again by anything.
        _failAll(PersistenceFailure.storageUnavailable, _downDetail);
      case _tagResponse:
        final int id = message[1] as int;
        final _Pending? pending = _pending.remove(id);
        // Removed on first delivery, so a duplicated reply — a retry, a
        // confused owner — cannot complete a completer twice or be counted
        // twice by a caller.
        if (pending == null) return;
        pending.timer.cancel();
        pending.completer.complete(message);
    }
  }

  void _failAll(PersistenceFailure failure, String detail) {
    final List<_Pending> outstanding = _pending.values.toList();
    _pending.clear();
    for (final _Pending pending in outstanding) {
      pending.timer.cancel();
      pending.completer.complete(<Object?>[
        _tagResponse,
        -1,
        _statusFail,
        failure.name,
        detail,
      ]);
    }
  }

  Future<List<Object?>> _send(String op, List<Object?> args) {
    if (_closed) {
      return Future<List<Object?>>.value(<Object?>[
        _tagResponse,
        -1,
        _statusFail,
        PersistenceFailure.storageUnavailable.name,
        'this client is closed',
      ]);
    }
    final SendPort? commands = _commands;
    if (commands == null) {
      // Fail fast rather than enqueue against nothing. A request parked
      // waiting for an owner that may never come back is the hang.
      return Future<List<Object?>>.value(<Object?>[
        _tagResponse,
        -1,
        _statusFail,
        PersistenceFailure.storageUnavailable.name,
        _downDetail,
      ]);
    }

    final int id = _nextRequestId++;
    final Completer<List<Object?>> completer = Completer<List<Object?>>();
    // The backstop. Supervision is believed complete; a save system should not
    // rest on a belief, so an unanswered request expires on its own.
    final Timer timer = Timer(_requestTimeout, () {
      if (_pending.remove(id) == null) return;
      completer.complete(<Object?>[
        _tagResponse,
        id,
        _statusFail,
        PersistenceFailure.lockTimeout.name,
        'no reply from the persistence owner within $_requestTimeout',
      ]);
    });
    _pending[id] = _Pending(completer, timer);
    commands.send(<Object?>[_tagRequest, id, _inbox.sendPort, op, ...args]);
    return completer.future;
  }

  static Never _throwFailure(List<Object?> response) {
    throw PersistenceUnavailable(
      PersistenceFailure.values.byName(response[3] as String),
      '${response[4]}',
    );
  }

  static bool _failed(List<Object?> response) => response[2] == _statusFail;

  // --- operations ---------------------------------------------------------
  //
  // One rule governs every operation below:
  //
  //   * **The storage was busy or refused** -> the core's own sealed result.
  //     `LoadRefusal.storageBusy`, `CommitRefusal.storageBusy`,
  //     `CompactionRefusal.storageBusy`, `EraseRefusal.storageBusy`. The owner
  //     was there, it took no lock, and it wrote nothing. These come straight
  //     through from `SaveRepository`; this class does not synthesize them,
  //     which is what keeps the two conditions from blurring.
  //
  //   * **The owner was unreachable** -> [PersistenceUnavailable]. A different
  //     condition with a different remedy and, for a commit, a genuinely
  //     unknown outcome. See that class.

  /// Reads the durable state through the owner.
  ///
  /// Contention arrives as `LoadRefused(LoadRefusal.storageBusy)` — never
  /// `NoSaveFound`, which would be a wiped character, and never a fabricated
  /// `SaveLoaded`. An unreachable owner throws [PersistenceUnavailable].
  Future<LoadOutcome> load() async {
    final List<Object?> response = await _send(_opLoad, const <Object?>[]);
    if (_failed(response)) _throwFailure(response);

    switch (response[3]) {
      case 'none':
        return const NoSaveFound();
      case 'refused':
        return LoadRefused(
          reason: LoadRefusal.values.byName(response[4] as String),
          explanation: response[5] as String,
          repairs: _decodeRepairs(response[6] as List<Object?>),
        );
      default:
        final SaveEnvelope envelope = decodeEnvelope(
          unframe(response[4] as Uint8List).payload!,
        );
        return SaveLoaded(
          state: envelope.state,
          saveId: envelope.saveId,
          fromSlot: SnapshotSlot.values[response[5] as int],
          generation: response[6] as int,
          lastAppliedTransaction: response[7] as int,
          replayedTransactions: response[8] as int,
          skippedTransactions: response[9] as int,
          repairs: _decodeRepairs(response[10] as List<Object?>),
        );
    }
  }

  /// Commits one batch through the owner.
  ///
  /// Contention arrives as `CommitRefused(CommitRefusal.storageBusy)`, which
  /// promises nothing was written. An unreachable owner throws
  /// [PersistenceUnavailable], because that promise cannot be made: the isolate
  /// may have died between a durable journal append and its reply. Both mean
  /// "do not release the step cursor"; only one of them means "nothing
  /// happened".
  Future<CommitOutcome> commit({
    required GameState after,
    required List<GameEvent> events,
    required String saveId,
    required CommitExpectation expectation,
    required String? originSaltFingerprint,
  }) async {
    final Uint8List stateBytes = encodeSnapshot(
      state: after,
      saveId: saveId,
      // Transport only. The owner reads `state` out of this envelope and
      // nothing else; the real generation and transaction id are decided
      // inside the owner's lock, where they can be decided correctly.
      generation: 0,
      lastAppliedTransaction: 0,
      originSaltFingerprint: originSaltFingerprint,
    );
    final Uint8List eventBytes = encodeJournalLine(
      JournalRecord(
        formatVersion: SaveFormatVersion.current,
        saveId: saveId,
        transactionId: 0,
        eventSequenceBefore: after.eventSequence - events.length,
        eventSequenceAfter: after.eventSequence,
        events: events,
      ),
    );

    final List<Object?> response = await _send(_opCommit, <Object?>[
      stateBytes,
      eventBytes,
      saveId,
      expectation.expectedSnapshotGeneration,
      expectation.expectedLastAppliedTransaction,
      originSaltFingerprint,
    ]);

    if (_failed(response)) _throwFailure(response);
    if (response[3] == 'refused') {
      return CommitRefused(
        reason: CommitRefusal.values.byName(response[4] as String),
        detail: response[5] as String,
      );
    }
    return CommitDurable(
      transactionId: response[4] as int,
      generation: response[5] as int,
      slot: SnapshotSlot.values[response[6] as int],
      snapshotDurable: response[7] as bool,
      retries: response[8] as int,
    );
  }

  /// Compacts the journal through the owner.
  ///
  /// Contention skips with [CompactionRefusal.storageBusy]; an unreachable
  /// owner throws [PersistenceUnavailable]. Compaction is journal hygiene and
  /// is always safe to skip either way — it runs again after the next commit —
  /// but only the first of the two is an ordinary condition.
  Future<CompactionOutcome> compact() async {
    final List<Object?> response = await _send(_opCompact, const <Object?>[]);
    if (_failed(response)) _throwFailure(response);
    final String? refusal = response[5] as String?;
    if (refusal != null) {
      return CompactionOutcome.skipped(
        CompactionRefusal.values.byName(refusal),
      );
    }
    return CompactionOutcome(
      removed: response[3] as int,
      retainedFrom: response[4] as int,
    );
  }

  /// Erases every artifact through the owner.
  ///
  /// Contention arrives as `EraseRefused(EraseRefusal.storageBusy)`, which
  /// carries the guarantee that matters: the reset protocol takes the lock
  /// before writing anything, so no reset intent was recorded and nothing was
  /// deleted. An unreachable owner throws [PersistenceUnavailable] — an owner
  /// that died mid-reset may have recorded the intent and deleted a slot, and
  /// the next load is entitled to say so with `LoadRefusal.resetIncomplete`.
  Future<EraseOutcome> eraseAll() async {
    final List<Object?> response = await _send(_opErase, const <Object?>[]);
    if (_failed(response)) _throwFailure(response);
    if (response[3] == 'refused') {
      return EraseRefused(
        reason: EraseRefusal.values.byName(response[4] as String),
        detail: response[5] as String,
      );
    }
    return const EraseComplete();
  }

  /// Reads the owner's serialization counters.
  Future<PersistenceOwnerStats> stats() async {
    final List<Object?> response = await _send(_opStats, const <Object?>[]);
    if (_failed(response)) _throwFailure(response);
    final Map<String, int> byOperation = <String, int>{};
    for (final Object? entry in response[5] as List<Object?>) {
      final List<String> parts = (entry as String).split('=');
      byOperation[parts[0]] = int.parse(parts[1]);
    }
    return PersistenceOwnerStats(
      served: response[3] as int,
      maxConcurrentHandlers: response[4] as int,
      byOperation: byOperation,
      trace: <String>[
        for (final Object? line in response[6] as List<Object?>) line as String,
      ],
    );
  }

  /// Unregisters and releases the inbox.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _endpoint.supervisor.send(<Object?>[_tagUnregister, _inbox.sendPort]);
    _failAll(PersistenceFailure.storageUnavailable, 'this client is closed');
    _inbox.close();
  }

  static List<SaveRepair> _decodeRepairs(List<Object?> wire) => <SaveRepair>[
    for (final Object? entry in wire)
      () {
        final String text = entry as String;
        final int split = text.indexOf('|');
        return SaveRepair(
          SaveDiagnosis.values.byName(text.substring(0, split)),
          detail: split + 1 == text.length ? null : text.substring(split + 1),
        );
      }(),
  ];
}

final class _Pending {
  const _Pending(this.completer, this.timer);

  final Completer<List<Object?>> completer;
  final Timer timer;
}

// ---------------------------------------------------------------------------
// The owner isolate itself
// ---------------------------------------------------------------------------

/// The owner's entry point. Top-level because `Isolate.spawn` requires it.
Future<void> _ownerMain(List<Object?> bootstrap) async {
  final SendPort ready = bootstrap[0] as SendPort;
  final List<Object?> wire = bootstrap[1] as List<Object?>;

  final _Owner owner;
  try {
    owner = _Owner.build(wire);
  } on Object catch (e) {
    // A content pack that will not load, or a directory that cannot be
    // created. Reported as a value on the ready port rather than thrown,
    // because `spawn` is waiting on that port and a throw here would reach it
    // only as an exit with no reason attached.
    ready.send(<Object?>[
      _tagOwnerFailed,
      'the persistence owner cannot start: $e',
    ]);
    return;
  }

  final ReceivePort commands = ReceivePort();
  ready.send(<Object?>[_tagOwnerReady, commands.sendPort]);

  await for (final Object? message in commands) {
    if (message is! List<Object?> ||
        message.isEmpty ||
        message.first != _tagRequest) {
      continue;
    }
    final int id = message[1] as int;
    final SendPort reply = message[2] as SendPort;
    final String op = message[3] as String;
    final List<Object?> args = message.sublist(4);

    if (op == _opShutdown) {
      // Enqueued like any other request, so the drain is real: everything
      // already accepted runs before the port closes.
      unawaited(
        owner.enqueue(id, reply, op, args).whenComplete(commands.close),
      );
      continue;
    }
    // Not awaited on purpose — the loop must keep accepting messages. The
    // ordering guarantee lives in `enqueue`, not here.
    unawaited(owner.enqueue(id, reply, op, args));
  }
}

/// The single serialization point for every in-process caller.
final class _Owner {
  _Owner({
    required this.repository,
    required this.registry,
    required this.treatAsRelease,
  });

  factory _Owner.build(List<Object?> wire) {
    final Directory root = Directory(wire[0] as String);
    final Map<String, String> contentFiles = (wire[1] as Map<Object?, Object?>)
        .map(
          (Object? k, Object? v) =>
              MapEntry<String, String>(k as String, v as String),
        );
    final String profileId = wire[2] as String;
    final Duration lockTimeout = Duration(milliseconds: wire[3] as int);
    final int maxCommitRetries = wire[4] as int;
    final bool treatAsRelease = wire[5] as bool;

    final ContentRegistry registry = const ContentLoader()
        .load(
          ContentSource(contentFiles),
          profileId: ContentId.unchecked(profileId),
        )
        .requireRegistry;

    final StorageLayout layout = StorageLayout(root);
    if (!layout.root.existsSync()) layout.root.createSync(recursive: true);

    return _Owner(
      registry: registry,
      treatAsRelease: treatAsRelease,
      repository: SaveRepository(
        snapshots: FileSnapshotStore(layout),
        journal: FileLedgerJournal(layout),
        maxCommitRetries: maxCommitRetries,
        // Kept. The owner serializes this process; the OS lock is what
        // excludes a second one, and no arrangement of ports can do that.
        lock: FileTransactionLock(layout.transactionLock),
        lockTimeout: lockTimeout,
      ),
    );
  }

  final SaveRepository repository;
  final ContentRegistry registry;
  final bool treatAsRelease;

  /// The queue. One chain, so a handler starts only after the previous one has
  /// returned — including its awaits.
  Future<void> _queue = Future<void>.value();

  int _served = 0;
  int _inFlight = 0;
  int _maxInFlight = 0;
  final Map<String, int> _byOperation = <String, int>{};
  final List<String> _trace = <String>[];

  Future<void> enqueue(int id, SendPort reply, String op, List<Object?> args) {
    final Completer<void> settled = Completer<void>();
    _queue = _queue.then((_) async {
      _inFlight++;
      if (_inFlight > _maxInFlight) _maxInFlight = _inFlight;
      _note('begin:$op:$id');
      try {
        reply.send(<Object?>[_tagResponse, id, ...await _dispatch(op, args)]);
      } on Object catch (e) {
        // A handler that throws still owes exactly one reply. A silent
        // completer on the caller's side is the failure mode this whole file
        // exists to make impossible.
        reply.send(<Object?>[
          _tagResponse,
          id,
          _statusFail,
          _classify(e).name,
          '$e',
        ]);
      } finally {
        _served++;
        _byOperation[op] = (_byOperation[op] ?? 0) + 1;
        _inFlight--;
        _note('end:$op:$id');
        settled.complete();
      }
    });
    return settled.future;
  }

  void _note(String entry) {
    _trace.add(entry);
    // Bounded: an unbounded trace in a long-lived isolate is a leak, and the
    // interesting part of a serialization trace is always the recent part.
    if (_trace.length > 512) _trace.removeRange(0, _trace.length - 512);
  }

  /// Maps an exception to the caller-facing vocabulary.
  ///
  /// Contention no longer reaches here: `SaveRepository` returns a typed
  /// `storageBusy` result on every operation, so a lock it could not take is a
  /// value and not a throw. The `StateError` arm is kept anyway, because it
  /// costs one comparison and the alternative — a future refactor
  /// reintroducing a busy throw and having it surface to players as
  /// "storage unavailable" — is a misdiagnosis of a transient condition as a
  /// broken device.
  static PersistenceFailure _classify(Object error) =>
      error is StateError && error.message.contains('another process')
      ? PersistenceFailure.storageBusy
      : PersistenceFailure.storageUnavailable;

  Future<List<Object?>> _dispatch(String op, List<Object?> args) async {
    switch (op) {
      case _opLoad:
        return _load();
      case _opCommit:
        return _commit(args);
      case _opCompact:
        final CompactionOutcome outcome = await repository.compact();
        return <Object?>[
          _statusOk,
          outcome.removed,
          outcome.retainedFrom,
          outcome.refusal?.name,
        ];
      case _opErase:
        final EraseOutcome erase = await repository.eraseAll();
        return switch (erase) {
          EraseComplete() => <Object?>[_statusOk, 'complete'],
          final EraseRefused r => <Object?>[
            _statusOk,
            'refused',
            r.reason.name,
            r.detail,
          ],
        };
      case _opStats:
        return <Object?>[
          _statusOk,
          _served,
          _maxInFlight,
          <String>[
            for (final MapEntry<String, int> e in _byOperation.entries)
              '${e.key}=${e.value}',
          ],
          List<String>.from(_trace),
        ];
      case _opShutdown:
        return <Object?>[_statusOk];
      default:
        return <Object?>[
          _statusFail,
          PersistenceFailure.storageUnavailable.name,
          'unknown persistence operation "$op"',
        ];
    }
  }

  Future<List<Object?>> _load() async {
    final LoadOutcome outcome = await repository.load(
      registry: registry,
      treatAsRelease: treatAsRelease,
    );
    return switch (outcome) {
      NoSaveFound() => <Object?>[_statusOk, 'none'],
      final LoadRefused r => <Object?>[
        _statusOk,
        'refused',
        r.reason.name,
        r.explanation,
        _encodeRepairs(r.repairs),
      ],
      final SaveLoaded l => <Object?>[
        _statusOk,
        'loaded',
        // The state crosses as save bytes, not as an object graph.
        encodeSnapshot(
          state: l.state,
          saveId: l.saveId,
          generation: l.generation,
          lastAppliedTransaction: l.lastAppliedTransaction,
          originSaltFingerprint: null,
        ),
        l.fromSlot.index,
        l.generation,
        l.lastAppliedTransaction,
        l.replayedTransactions,
        l.skippedTransactions,
        _encodeRepairs(l.repairs),
      ],
    };
  }

  Future<List<Object?>> _commit(List<Object?> args) async {
    final SaveEnvelope envelope = decodeEnvelope(
      unframe(args[0] as Uint8List).payload!,
    );
    final JournalLineResult parsed = decodeJournalLine(args[1] as Uint8List);
    if (!parsed.ok) {
      // The transport itself is damaged, so the events cannot be trusted.
      // Refusing is the only safe answer: committing a partially-decoded batch
      // would advance the cursor over events that were never applied.
      return <Object?>[
        _statusOk,
        'refused',
        CommitRefusal.journalAppendFailed.name,
        'the commit payload did not survive transport: ${parsed.fault!.name}',
      ];
    }

    final CommitOutcome outcome = await repository.commit(
      after: envelope.state,
      events: parsed.record!.events,
      saveId: args[2] as String,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: args[3] as int,
        expectedLastAppliedTransaction: args[4] as int,
      ),
      originSaltFingerprint: args[5] as String?,
    );

    return switch (outcome) {
      final CommitRefused r => <Object?>[
        _statusOk,
        'refused',
        r.reason.name,
        r.detail,
      ],
      final CommitDurable d => <Object?>[
        _statusOk,
        'durable',
        d.transactionId,
        d.generation,
        d.slot.index,
        d.snapshotDurable,
        d.retries,
      ],
    };
  }

  static List<String> _encodeRepairs(List<SaveRepair> repairs) => <String>[
    for (final SaveRepair r in repairs) '${r.diagnosis.name}|${r.detail ?? ''}',
  ];
}
