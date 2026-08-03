// Fixtures for the adapter-to-ledger evidence suite (S-01A).
//
// The core's own reconciliation tests start from a hand-built `SyncResponse`.
// These start one layer earlier — from a `PlatformSyncPage`, the value a native
// adapter actually sends — and run it through `PlatformStepSource.translate`
// (or `MockStepSource`) into `GameEngine`. The gap between those two layers is
// where `DECISIONS/0014` found the whole dead ingestion model, so it is the gap
// worth having evidence for.
//
// Nothing here reads a clock, touches a device, opens a channel, or needs a
// health service. `dart:io` appears only to load the production content bundle,
// which is a test concern and never a core one.

import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_health/src/messages.g.dart';
import 'package:stride_health/stride_health.dart';

/// Stateless: keying happens natively, and there is no salt on this side.
const OriginGateway gateway = OriginGateway();

const int hour = 60 * 60 * 1000;

/// A fixed origin instant. A constant, not a clock read.
const int t0 = 1753401600000;

// -- Content -----------------------------------------------------------------

ContentRegistry? _registry;

/// The production registry, loaded once.
///
/// Resolved relative to the package so `flutter test` from either this package
/// or the repository root finds it.
ContentRegistry get stepRegistry => _registry ??= _loadRegistry();

ContentRegistry _loadRegistry() {
  for (final String candidate in <String>[
    '../../assets/content/v1',
    'assets/content/v1',
  ]) {
    final Directory directory = Directory(candidate);
    if (!directory.existsSync()) continue;
    final Map<String, String> files = <String, String>{};
    for (final FileSystemEntity entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      files[entity.uri.pathSegments.last] = entity.readAsStringSync();
    }
    return const ContentLoader()
        .load(ContentSource(files), profileId: BalanceProfile.productionId)
        .requireRegistry;
  }
  throw StateError(
    'Could not locate assets/content/v1 from ${Directory.current.path}. '
    'Run from packages/stride_health or the repository root.',
  );
}

/// A fresh engine with an empty ledger.
GameEngine newEngine() => GameEngine.newGame(registry: stepRegistry);

/// An engine resumed from an existing state — the shape a crash-and-retry takes.
GameEngine engineAt(GameState state) =>
    GameEngine(registry: stepRegistry, state: state);

// -- Origins -----------------------------------------------------------------

/// Two devices, as eight opaque bytes each — the only shape the wire can carry.
final Uint8List phoneBytes = Uint8List.fromList(<int>[
  0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x07, 0x18, //
]);
final Uint8List watchBytes = Uint8List.fromList(<int>[
  0x0f, 0x1e, 0x2d, 0x3c, 0x4b, 0x5a, 0x69, 0x78, //
]);

/// The core keys those bytes decode to. Derived through the gateway rather than
/// written out, so a test can never disagree with the decoder about what an
/// origin key is.
final StepOriginKey phone = gateway.decodeOrigin(phoneBytes)!;
final StepOriginKey watch = gateway.decodeOrigin(watchBytes)!;

// -- Platform page builders --------------------------------------------------

/// One platform observation. [index] is an hour offset from [t0].
PlatformStepObservation pobs(
  Uint8List origin,
  int index,
  int steps, {
  int spanHours = 1,
}) => PlatformStepObservation(
  originKey: origin,
  bucket: PlatformTimeBucket(
    startMillis: t0 + index * hour,
    endMillis: t0 + (index + spanHours) * hour,
  ),
  steps: steps,
);

// ---------------------------------------------------------------------------
// The page builders are SEMANTIC, and there is no general-purpose one
// ---------------------------------------------------------------------------
//
// There used to be `ppage` and `pcomplete`. Between them they took a status, a
// completeness kind, a pagination flag, a window and a cursor as independent
// parameters, each with a default — and the completeness default was
// `partial`. So the shortest way to write a page was also a page that vouched
// for nothing, and the shortest way to write a page was what most tests wrote.
//
// That produced tests whose NAME said one thing and whose DATA said another:
// "a failure between the grant and the commit leaves the cursor back" asserted
// that a cursor became durable, on a page that declared the read unfinished.
// They passed because the bridge handed the cursor over regardless. When
// `authorizeCursor` closed that hole, the tests failed — not because the
// behaviour regressed, but because the fixtures had never said what the tests
// claimed. Ten of them.
//
// So the builders below are named for what a delivery IS, each one requires the
// facts that decide its outcome, and each REFUSES AT CONSTRUCTION the
// completeness variant its kind cannot legally carry. An ordinary test can no
// longer express an impossible page by leaving a parameter out.
//
// The line they draw: a builder refuses exactly the combinations the bridge
// rejects as `ContractViolationSync`. Combinations the bridge *corrects* —
// completeness on a non-final page, a cursor offered where authorization will
// refuse it — stay expressible, because they are legitimate things an adapter
// does and the correction is what several tests are about. Offering a cursor is
// never itself a defect: adapters OFFER candidates, `authorizeCursor` decides.

/// The completeness declaration, exactly as native would send it.
///
/// Private, and [kind] is a required positional. Every public builder passes
/// the kind it is allowed to express, so there is no path on which a page
/// acquires a completeness kind by default. That default is what made three
/// tests assert completed-read behaviour on data that said the read was still
/// going.
///
/// [throughIndex] is the assertion; [fromIndex]/[toIndex] are the interval the
/// adapter says it actually queried. Separate on purpose: an adapter that
/// vouches beyond what it queried is a case a test must be able to express, and
/// the core's own suite could not, because its helper set both from one
/// argument.
PlatformCompleteness _pcompleteness(
  PlatformCompletenessKind kind, {
  PlatformOriginScopeKind scopeKind = PlatformOriginScopeKind.someOrigins,
  List<Uint8List>? scoped,
  int throughIndex = 1,
  int fromIndex = 0,
  int? toIndex,
  int queryGeneration = 1,
}) => PlatformCompleteness(
  kind: kind,
  dataType: PlatformHealthDataType.steps,
  scope: PlatformOriginScope(
    kind: scopeKind,
    originKeys: scoped ?? <Uint8List>[phoneBytes],
  ),
  intervalStartMillis: t0 + fromIndex * hour,
  intervalEndMillis: t0 + (toIndex ?? throughIndex) * hour,
  queryGeneration: queryGeneration,
  throughMillis: t0 + throughIndex * hour,
);

PlatformSyncPage _ppage({
  required PlatformSyncStatus status,
  required List<PlatformStepObservation> observations,
  required PlatformCompleteness completeness,
  required bool isFinalPage,
  String? continuation,
  String? nextCursor,
  PlatformRescanWindow? rescan,
  PlatformUnavailableReason? unavailableReason,
}) => PlatformSyncPage(
  status: status,
  observations: observations,
  completeness: completeness,
  pagination: PlatformPagination(
    pageIndex: 0,
    isFinalPage: isFinalPage,
    continuation: continuation == null ? null : bytesOf(continuation),
  ),
  nextCursor: nextCursor == null ? null : bytesOf(nextCursor),
  rescan: rescan,
  unavailableReason: unavailableReason,
);

/// An ordinary incremental read.
///
/// [isFinalPage] and [completeness] are required because they are the two facts
/// that decide whether anything settles and whether a cursor may advance.
///
/// [completeness] accepts only [PlatformCompletenessKind.partial] or
/// [PlatformCompletenessKind.completeThrough]. An incremental read asserting
/// recovery completeness is
/// [SyncContractViolation.mismatchedCompleteness] and belongs in
/// [pcontractViolationPage].
PlatformSyncPage pincrementalPage({
  required bool isFinalPage,
  required PlatformCompletenessKind completeness,
  List<PlatformStepObservation> observations =
      const <PlatformStepObservation>[],
  PlatformOriginScopeKind scopeKind = PlatformOriginScopeKind.someOrigins,
  List<Uint8List>? scoped,
  int throughIndex = 1,
  int fromIndex = 0,
  int? toIndex,
  int queryGeneration = 1,
  String? continuation,
  String? nextCursor,
}) {
  if (completeness == PlatformCompletenessKind.recoveryCompleteThrough) {
    throw ArgumentError.value(
      completeness,
      'completeness',
      'an incremental read has no rescan window, so a recovery completeness '
          'assertion has no bound to be read against. That is '
          'SyncContractViolation.mismatchedCompleteness — build it with '
          'pcontractViolationPage and say so.',
    );
  }
  return _ppage(
    status: PlatformSyncStatus.incremental,
    observations: observations,
    completeness: _pcompleteness(
      completeness,
      scopeKind: scopeKind,
      scoped: scoped,
      throughIndex: throughIndex,
      fromIndex: fromIndex,
      toIndex: toIndex,
      queryGeneration: queryGeneration,
    ),
    isFinalPage: isFinalPage,
    continuation: continuation,
    nextCursor: nextCursor,
  );
}

/// A bounded authoritative rescan after the platform invalidated the cursor.
///
/// [isTruncated] is required and builds the window, so a recovery cannot exist
/// here without one: an invalidation with no rescan window is an adapter defect
/// and belongs in [pcontractViolationPage].
///
/// [completeness] accepts only [PlatformCompletenessKind.partial] or
/// [PlatformCompletenessKind.recoveryCompleteThrough]. A recovery asserting
/// ordinary [PlatformCompletenessKind.completeThrough] is the more dangerous
/// half of [SyncContractViolation.mismatchedCompleteness] — ordinary
/// completeness is unbounded, so adopting it from a rescan settles past the
/// window the rescan covered.
///
/// A truncated window asserting recovery completeness is deliberately still
/// buildable: the bridge downgrades it, and that downgrade is what several
/// tests are about.
PlatformSyncPage precoveryPage({
  required bool isFinalPage,
  required bool isTruncated,
  required PlatformCompletenessKind completeness,
  List<PlatformStepObservation> observations =
      const <PlatformStepObservation>[],
  int windowFromIndex = 0,
  int windowToIndex = 2,
  PlatformOriginScopeKind scopeKind = PlatformOriginScopeKind.someOrigins,
  List<Uint8List>? scoped,
  int throughIndex = 1,
  int fromIndex = 0,
  int? toIndex,
  int queryGeneration = 1,
  String? continuation,
  String? nextCursor,
}) {
  if (completeness == PlatformCompletenessKind.completeThrough) {
    throw ArgumentError.value(
      completeness,
      'completeness',
      'a recovery may only vouch for the window it could reach. Ordinary '
          'completeThrough is unbounded, so adopting it here settles past the '
          'rescan. That is SyncContractViolation.mismatchedCompleteness — '
          'build it with pcontractViolationPage and say so.',
    );
  }
  return _ppage(
    status: PlatformSyncStatus.cursorInvalidated,
    observations: observations,
    completeness: _pcompleteness(
      completeness,
      scopeKind: scopeKind,
      scoped: scoped,
      throughIndex: throughIndex,
      fromIndex: fromIndex,
      toIndex: toIndex,
      queryGeneration: queryGeneration,
    ),
    isFinalPage: isFinalPage,
    rescan: pwindow(
      fromIndex: windowFromIndex,
      toIndex: windowToIndex,
      truncated: isTruncated,
    ),
    continuation: continuation,
    nextCursor: nextCursor,
  );
}

/// The platform reported no change since the cursor.
///
/// Emptiness is **structural**, not a default: there is no observations
/// parameter, no completeness parameter and no rescan parameter, so a no-change
/// page cannot acquire a payload by being written carelessly. All three of
/// those are [SyncContractViolation]s and all three must be written out
/// deliberately, in [pcontractViolationPage].
///
/// [PlatformCompletenessKind.partial] is the only honest declaration here:
/// knowing that nothing arrived says nothing about what the window held. That
/// is also precisely what makes the no-change cursor exception safe — nothing
/// is settled, so a later delivery inside the window is still grantable.
PlatformSyncPage pnoChangePage({
  required bool isFinalPage,
  String? continuation,
  String? nextCursor,
}) => _ppage(
  status: PlatformSyncStatus.noChange,
  observations: const <PlatformStepObservation>[],
  completeness: _pcompleteness(PlatformCompletenessKind.partial),
  isFinalPage: isFinalPage,
  continuation: continuation,
  nextCursor: nextCursor,
);

/// The provider could not answer.
///
/// Carries no observations and no completeness worth asserting; the reason is
/// the entire content. [nextCursor] exists because an adapter offering one on a
/// path that answers nothing is a real defect the bridge drops and faults.
PlatformSyncPage punavailablePage({
  required PlatformUnavailableReason reason,
  String? nextCursor,
}) => _ppage(
  status: PlatformSyncStatus.unavailable,
  observations: const <PlatformStepObservation>[],
  completeness: _pcompleteness(PlatformCompletenessKind.partial),
  isFinalPage: true,
  nextCursor: nextCursor,
  unavailableReason: reason,
);

/// The **only** builder permitted to express a page the contract forbids.
///
/// [violation] is required and must name, in prose, what is deliberately being
/// broken. It is not decoration and it is not a comment that can drift away
/// from the call: a helper that can build anything becomes the helper everyone
/// reaches for, and the value of the builders above is exactly that they cannot
/// build these. Requiring the caller to write the defect down is what keeps
/// this from becoming `ppage` again under a longer name.
///
/// Everything is explicit here — status, completeness kind, pagination, window
/// — because a defect fixture that inherited a default would be a defect
/// fixture nobody could read.
PlatformSyncPage pcontractViolationPage({
  required String violation,
  required PlatformSyncStatus status,
  required PlatformCompletenessKind completeness,
  List<PlatformStepObservation> observations =
      const <PlatformStepObservation>[],
  bool isFinalPage = true,
  PlatformRescanWindow? rescan,
  PlatformOriginScopeKind scopeKind = PlatformOriginScopeKind.someOrigins,
  List<Uint8List>? scoped,
  int throughIndex = 1,
  int fromIndex = 0,
  int? toIndex,
  int queryGeneration = 1,
  String? continuation,
  String? nextCursor,
  PlatformUnavailableReason? unavailableReason,
}) {
  if (violation.trim().isEmpty) {
    throw ArgumentError.value(
      violation,
      'violation',
      'name the contract this page deliberately breaks',
    );
  }
  return _ppage(
    status: status,
    observations: observations,
    completeness: _pcompleteness(
      completeness,
      scopeKind: scopeKind,
      scoped: scoped,
      throughIndex: throughIndex,
      fromIndex: fromIndex,
      toIndex: toIndex,
      queryGeneration: queryGeneration,
    ),
    isFinalPage: isFinalPage,
    rescan: rescan,
    continuation: continuation,
    nextCursor: nextCursor,
    unavailableReason: unavailableReason,
  );
}

/// Every platform refusal, and everything it must become.
///
/// A table rather than a property, because the property that matters is
/// **exhaustive and exact**: each platform condition reaches its own core
/// reason, its own refusal code, its own retryability, and its own source
/// state. Asserting only that the core reasons are mutually *distinct* is
/// satisfied by a mapping that has been permuted — `serviceMissing` arriving as
/// `permissionUnavailable` and vice versa passes a distinctness check and puts
/// the wrong sentence in front of the player.
///
/// Shared with `platform_step_source_test.dart` so there is one table rather
/// than two that can drift.
const Map<
  PlatformUnavailableReason,
  (ProviderUnavailableReason, ReconciliationCode, bool, SourceState)
>
expectedRefusals =
    <
      PlatformUnavailableReason,
      (ProviderUnavailableReason, ReconciliationCode, bool, SourceState)
    >{
      PlatformUnavailableReason.serviceMissing: (
        ProviderUnavailableReason.serviceUnavailable,
        ReconciliationCode.serviceUnavailable,
        true,
        SourceState.serviceUnavailable,
      ),
      PlatformUnavailableReason.permissionUnavailable: (
        ProviderUnavailableReason.permissionUnavailable,
        ReconciliationCode.permissionUnavailable,
        true,
        SourceState.permissionUnavailable,
      ),
      PlatformUnavailableReason.transientFailure: (
        ProviderUnavailableReason.transientFailure,
        ReconciliationCode.transientFailure,
        true,
        SourceState.transientlyUnavailable,
      ),
      // The only non-retryable member. Retrying cannot install an identity.
      PlatformUnavailableReason.originKeyingUnconfigured: (
        ProviderUnavailableReason.originKeyingUnconfigured,
        ReconciliationCode.originKeyingUnconfigured,
        false,
        SourceState.originKeyingUnconfigured,
      ),
    };

/// A rescan window, in hour indices.
PlatformRescanWindow pwindow({
  required int fromIndex,
  required int toIndex,
  bool truncated = false,
}) => PlatformRescanWindow(
  startMillis: t0 + fromIndex * hour,
  endMillis: t0 + toIndex * hour,
  truncated: truncated,
);

Uint8List bytesOf(String value) => Uint8List.fromList(value.codeUnits);

SyncCursor cursor(String value) => SyncCursor.ofString(value);

/// Translates a platform page with the real gateway.
SyncFetch translate(PlatformSyncPage page) =>
    PlatformStepSource.translate(page, gateway);

// -- Driving the ledger ------------------------------------------------------

/// Reconciles one adapter fetch into [engine].
///
/// This is the whole path under test: platform page → bridge → `SyncResponse` →
/// `ReconcileStepSync` → reducer → ledger.
EngineResult reconcile(GameEngine engine, SyncFetch fetch) =>
    engine.execute(ReconcileStepSync(response: fetch.response));

/// Translates and reconciles in one step.
EngineResult ingest(GameEngine engine, PlatformSyncPage page) =>
    reconcile(engine, translate(page));

/// Steps credited by a sync, read off the event stream rather than by
/// differencing totals — the observable outcome, not an inference.
int grantedBy(EngineResult result) => result.events
    .whereType<StepsGranted>()
    .fold<int>(0, (int sum, StepsGranted e) => sum + e.steps);

/// The cursor the engine authorized for persistence, or null if none was.
SyncCursor? authorizedCursor(EngineResult result) {
  final Iterable<StepCheckpointAuthorized> authorizations = result.events
      .whereType<StepCheckpointAuthorized>();
  return authorizations.isEmpty ? null : authorizations.last.cursor;
}

bool didAuthorizeCheckpoint(EngineResult result) =>
    result.events.whereType<StepCheckpointAuthorized>().isNotEmpty;

/// Applies every event up to, but not including, the first [T].
///
/// Truncates rather than filters. Filtering one event type out and applying
/// everything after it models no crash that can happen, and would quietly
/// encode the conclusion that the checkpoint is last — which is the property
/// under test, not an assumption available to the test.
GameState commitUpTo<T extends GameEvent>(
  GameState from,
  List<GameEvent> events,
) => const EventReducer().applyAll(
  from,
  events.takeWhile((GameEvent e) => e is! T).toList(),
);

/// A process that died after committing the ledger but before the cursor could
/// be made durable.
GameState commitWithoutCheckpoint(GameState from, List<GameEvent> events) =>
    commitUpTo<StepCheckpointAuthorized>(from, events);
