import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

/// A scriptable [StepProvider] for tests and development.
///
/// This is the provider the thirteen reconciliation scenarios run against. It
/// exists so that the highest-severity system in the project can be tested
/// exhaustively on Windows, with no device, no emulator, no health service, and
/// no wall clock — in under a second.
///
/// Every awkward real-world case is expressible here: duplicate batches,
/// out-of-order samples, deletions, corrections that exceed what was granted,
/// week-long absences, transport errors, and an invalidated cursor.
class MockStepProvider implements StepProvider {
  MockStepProvider({
    List<StepFetchResult> script = const <StepFetchResult>[],
    this.authorization = StepAuthorization.granted,
    this.available = true,
  }) : _script = List<StepFetchResult>.of(script);

  final List<StepFetchResult> _script;

  /// What [requestAuthorization] reports.
  final StepAuthorization authorization;

  /// What [isAvailable] reports. False models Android without Health Connect
  /// installed — a normal state the game must remain fully playable through.
  final bool available;

  /// Cursors the caller has handed back, in order.
  ///
  /// Lets a test assert the caller persisted a cursor only after committing the
  /// batch — persisting early is what makes an interrupted sync unrecoverable.
  final List<StepCursor?> cursorsSeen = <StepCursor?>[];

  /// Watermarks the caller supplied, in order. Used by recovery scenarios.
  final List<DateTime?> watermarksSeen = <DateTime?>[];

  int _index = 0;

  /// How many fetches have been served.
  int get fetchCount => _index;

  /// Whether the script has been exhausted.
  bool get isExhausted => _index >= _script.length;

  /// Appends a step to the script after construction.
  void enqueue(StepFetchResult result) => _script.add(result);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<StepAuthorization> requestAuthorization() async => authorization;

  @override
  Future<StepFetchResult> fetchNewSteps({
    StepCursor? cursor,
    DateTime? watermark,
  }) async {
    cursorsSeen.add(cursor);
    watermarksSeen.add(watermark);

    if (isExhausted) {
      // An exhausted script yields "nothing new" rather than throwing. A test
      // that fetches more often than it scripted is usually asserting
      // idempotence, and that should read as no-op, not as an error.
      return const StepFetchResult(
        status: CursorStatus.valid,
        newSteps: 0,
        deletedSteps: 0,
        cursor: null,
      );
    }

    return _script[_index++];
  }

  // -- Convenience constructors for common scenario shapes ------------------

  /// A plain delta of [steps], returning [cursor] as the next cursor.
  static StepFetchResult delta(int steps, {String cursor = 'c'}) =>
      StepFetchResult(
        status: CursorStatus.valid,
        newSteps: steps,
        deletedSteps: 0,
        cursor: StepCursor(Uint8List.fromList(cursor.codeUnits)),
      );

  /// A correction removing [steps]. Information for the ledger to absorb —
  /// never an instruction to revoke granted progress.
  static StepFetchResult deletion(int steps, {String cursor = 'c'}) =>
      StepFetchResult(
        status: CursorStatus.valid,
        newSteps: 0,
        deletedSteps: steps,
        cursor: StepCursor(Uint8List.fromList(cursor.codeUnits)),
      );

  /// An invalidated cursor carrying a bounded authoritative rescan.
  ///
  /// This is scenario 13. Health Connect can expire a changes token; HealthKit
  /// does not. Note that `newSteps` is zero: on this path the delta stream is
  /// broken, and treating a rescan as a delta is precisely the double-count the
  /// scenario exists to prevent.
  static StepFetchResult invalidated({
    required DateTime windowStart,
    required DateTime windowEnd,
    required int windowTotal,
    bool truncated = false,
  }) => StepFetchResult(
    status: CursorStatus.invalidated,
    newSteps: 0,
    deletedSteps: 0,
    // No replacement cursor is offered until recovery succeeds.
    cursor: null,
    rescan: StepRescan(
      windowStart: windowStart,
      windowEnd: windowEnd,
      windowTotal: windowTotal,
      truncated: truncated,
    ),
  );
}
