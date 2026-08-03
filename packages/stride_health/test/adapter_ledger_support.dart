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

/// A completeness declaration, exactly as native would send it.
///
/// [throughIndex] is the assertion; [fromIndex]/[toIndex] are the interval the
/// adapter says it actually queried. They are separate parameters on purpose:
/// an adapter that vouches beyond what it queried is a case a test must be able
/// to express.
PlatformCompleteness pcomplete({
  PlatformCompletenessKind kind = PlatformCompletenessKind.partial,
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

/// One page from the platform.
PlatformSyncPage ppage({
  PlatformSyncStatus status = PlatformSyncStatus.incremental,
  List<PlatformStepObservation> observations =
      const <PlatformStepObservation>[],
  PlatformCompleteness? complete,
  bool isFinalPage = true,
  String? continuation,
  String? nextCursor,
  PlatformRescanWindow? rescan,
  PlatformUnavailableReason? unavailableReason,
}) => PlatformSyncPage(
  status: status,
  observations: observations,
  completeness: complete ?? pcomplete(),
  pagination: PlatformPagination(
    pageIndex: 0,
    isFinalPage: isFinalPage,
    continuation: continuation == null ? null : bytesOf(continuation),
  ),
  nextCursor: nextCursor == null ? null : bytesOf(nextCursor),
  rescan: rescan,
  unavailableReason: unavailableReason,
);

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
