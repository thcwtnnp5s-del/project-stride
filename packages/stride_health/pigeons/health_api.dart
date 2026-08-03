// The platform boundary — single source of truth for all three sides.
//
// Regenerate after any change:
//   cd packages/stride_health
//   dart run pigeon --input pigeons/health_api.dart
//
// Generated files are committed, and CI fails when they are stale. A contract
// change that is not reflected on all three sides fails to *compile* — with an
// untyped MethodChannel it would fail at runtime, as a null, in the system that
// decides whether the player's walk counted.
//
// ===========================================================================
// Why this contract is no longer three flat methods (S-01A)
// ===========================================================================
//
// The previous version of this file carried `PlatformFetchResult`, whose payload
// was `newSteps: int` and `deletedSteps: int` — a flat delta with no origin, no
// completeness scope, and no pagination state. It was the F-01-era model, and
// `DECISIONS/0014` records what was wrong with it: **nothing consumed it.**
//
// The live ingestion path is `ReconcileStepSync(SyncResponse)` →
// `StepReconciler.reconcile`, which reasons about per-origin `StepObservation`
// keyed by `ObservationKey(origin, bucket)`, and settles buckets only against a
// scoped `SyncCompleteness`. A flat total cannot express any of that. An adapter
// written honestly against the old contract could not have satisfied the core:
//
//   * a flat delta cannot say WHICH source produced it, so the reconciler
//     cannot tell "the phone is settled through Tuesday" from "the watch has
//     been offline for a week" — the exact case that discarded a returning
//     player's backlog (F-05, LG-3)
//   * a flat delta cannot distinguish a first page from a last page, so a
//     paginated backfill looked complete on page one — the case that destroyed
//     55,200 steps
//   * a flat delta cannot restate a bucket, so a correction is unrepresentable
//     and a deletion is indistinguishable from data that never existed
//
// So this contract carries observations, not totals. Every figure is
// **absolute** for a `(source, bucket)` slice: 400 means "this slice now
// contains 400 steps", whatever was said before. Zero means deleted. That single
// property is what makes replay, correction, deletion, and overlap all one code
// path in the core rather than four.
//
// ===========================================================================
// The three obligations an adapter takes on by implementing this
// ===========================================================================
//
// 1. **ABSOLUTE, NOT DELTA.** When the platform reports a deletion or an edit,
//    the adapter must RE-READ the affected bucket and send its new absolute
//    total. Forwarding "a record was removed" without restating the bucket
//    leaves the core unable to act, because it has no figure to reconcile
//    against. A bucket that is now empty is sent as `steps: 0`, not omitted.
//
// 2. **COMPLETENESS IS ASSERTED, NEVER GUESSED.**
//    `PlatformCompletenessKind.completeThrough` may be sent only after the
//    adapter has drained every page for the declared scope AND has actually
//    asked the platform for its full source list if it declares `allOrigins`.
//    "I saw one source in this batch" is `someOrigins`. Asserting completeness
//    early is indistinguishable, from inside the core, from the data not
//    existing — and the consequence is a silent, permanent lost grant.
//
// 3. **THE CURSOR IS NEVER NATIVE STATE.** The adapter returns a candidate
//    `nextCursor` and forgets it. It must not write it to `UserDefaults`,
//    `SharedPreferences`, a DataStore, or a file. The commit order is
//    inviolable: adapter returns data + candidate cursor → reconciliation
//    produces grants → ledger and snapshot commit → *only then* is the cursor
//    durable. A cursor cached natively would claim progress the ledger never
//    recorded, and an interrupted sync would be unrecoverable.
//    `Scripts/check-origin-privacy.sh` rejects native persistence APIs in this
//    plugin's sources.
//
// ===========================================================================
// Origin privacy — THERE IS NO RAW IDENTIFIER ON THIS WIRE
// ===========================================================================
//
// **A raw platform source identifier must never reach Dart.** Pseudonymization
// happens in Swift and Kotlin, before the value crosses this boundary. The raw
// `HKSource.bundleIdentifier` or `dataOrigin.packageName` exists inside one
// native function call and is gone when it returns.
//
// So this contract has no `String` origin field for one to travel in.
// `PlatformStepObservation.originKey` and `PlatformOriginScope.originKeys` are
// `Uint8List` of **exactly eight bytes** — a 64-bit keyed digest, which is what
// `StepOriginKey` is: sixteen lowercase hex characters. A bundle identifier
// does not fit in eight bytes and neither does a device name, so the shape of
// the field is itself part of the control.
//
// **This is a constraint, not a proof, and the distinction matters.** Eight
// arbitrary bytes are still eight bytes: a native adapter could put the first
// eight characters of "Rob's iPhone" there and the wire could not tell. What
// the width buys is that no *complete* identifier or name survives, and that
// the only sensible thing to put in the field is the digest. Reviewing native
// origin derivation is a standing obligation, not a solved problem.
//
// ## Native must consume the app's identity, never mint its own
//
// The keying salt is the device-bound identity already resolved at bootstrap —
// iOS Keychain under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
// app-private storage on Android, via `IdentityVault`. Native receives it
// through [HealthHostApi.installOriginKeying] and holds it **in memory only,
// for the lifetime of the engine attachment**.
//
// A second native identity — generated natively, or cached in `UserDefaults`,
// `SharedPreferences`, or the Keychain by this plugin — would re-key every
// origin. Re-keyed origins have no `grantedSlices`, so their recent buckets look
// ungranted and the retention window is granted a second time. That is the
// double-grant `LoadRefusal.originKeyReset` and
// `BootstrapBlockReason.originIdentityMissing` exist to prevent, and it is
// undetectable once it happens. `Scripts/check-origin-privacy.sh` rejects
// durable native stores in this plugin's sources.
//
// Until the salt is installed the adapter must refuse to read, returning
// [PlatformUnavailableReason.originKeyingUnconfigured]. Fail-closed: a page of
// observations keyed under no salt, or under the wrong one, is worse than no
// page at all.
//
// ## The algorithm, and the risk it carries
//
// `FNV-1a`, 64-bit, over `salt || 0x1F || utf8(rawIdentifier)`, big-endian.
// Keyed rather than a bare digest: an unkeyed hash of a package name is
// trivially reversible by anyone with a list of package names, which is
// everyone. Not cryptographic, deliberately — the threat is casual
// identifiability inside a local save, not an attacker who already holds the
// device and could read the salt beside it.
//
// **Two native implementations are two chances to diverge**, and a divergence
// is silent: it looks exactly like a new device. `algorithmVersion` on
// [HealthHostApi.installOriginKeying] makes a version mismatch a typed refusal
// rather than a wrong answer, and
// `packages/stride_health/test/origin_key_vectors.dart` holds the shared test
// vectors both native suites must reproduce. Neither of those is a proof. The
// vectors are the closest thing available and every adapter must assert them.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/projectstride/stride_health/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.projectstride.stride_health'),
    // The plugin uses the Swift Package Manager layout. Generating into
    // ios/Classes/ would produce a file that is never compiled.
    swiftOut: 'ios/stride_health/Sources/stride_health/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'stride_health',
  ),
)
/// Mirrors `HealthDataType` in stride_core.
///
/// Only steps exist today. It is on the wire so that an adapter which later
/// reads distance or workouts cannot have its step-completeness assertion
/// silently widened to cover them.
enum PlatformHealthDataType { steps }

/// Whether the platform will give us step data.
///
/// Neither platform reliably distinguishes "denied" from "granted but empty" —
/// HealthKit deliberately hides read denial so an app cannot infer that a user
/// has no data. The game therefore treats both identically, and nothing about a
/// missing permission ever blocks a screen, a craft, or a fight.
enum PlatformAuthorizationState { granted, denied, unavailable }

/// Why a provider could not answer. Mirrors `ProviderUnavailableReason`.
enum PlatformUnavailableReason {
  /// Health Connect is not installed; HealthKit is unavailable on this device.
  serviceMissing,

  /// Authorization has not been granted, or cannot be determined.
  permissionUnavailable,

  /// The read failed and may succeed later.
  transientFailure,

  /// The device-bound origin-keying salt has not been installed, or was
  /// rejected.
  ///
  /// **Fail-closed, and not a transient condition.** An adapter in this state
  /// must refuse to read: observations keyed under no salt, or under the wrong
  /// one, would re-key every origin and grant the whole retention window a
  /// second time. Retrying will not fix it; installing the identity will.
  originKeyingUnconfigured,
}

/// The outcome of installing the device-bound keying salt.
enum PlatformOriginKeyingOutcome {
  /// The salt is held in memory for this engine attachment. Reads may proceed.
  installed,

  /// The adapter does not implement the requested `algorithmVersion`.
  ///
  /// A typed refusal rather than a silent fallback. A version mismatch that
  /// degraded quietly would produce keys that differ from every other
  /// platform's — which looks exactly like a new device, and re-grants the
  /// retention window.
  unsupportedAlgorithm,

  /// The salt was malformed — empty, or outside the accepted length.
  rejected,
}

/// What installing the salt achieved.
class PlatformOriginKeyingResult {
  PlatformOriginKeyingResult({required this.outcome, this.diagnostic});

  final PlatformOriginKeyingOutcome outcome;

  /// A short technical note. **Never the salt, never a fingerprint of it, and
  /// never a source identifier.**
  final String? diagnostic;
}

/// The shape of one page's answer. Mirrors the `SyncResponse` hierarchy.
enum PlatformSyncStatus {
  /// The source reported observations. Covers the ordinary case and, without a
  /// separate shape, delayed records, overlapping batches, upward and downward
  /// corrections, and deletions — because every observation is absolute.
  incremental,

  /// Nothing changed since the cursor.
  noChange,

  /// The cursor was rejected. [PlatformSyncPage.rescan] is then mandatory and
  /// [PlatformSyncPage.observations] is the authoritative content of the window.
  cursorInvalidated,

  /// The provider could not answer. [PlatformSyncPage.unavailableReason] is
  /// then mandatory, and no cursor is offered.
  unavailable,
}

/// Which sources a completeness assertion speaks for.
enum PlatformOriginScopeKind {
  /// The adapter asked the platform for its FULL source list and drained every
  /// one of them. Legitimate only then.
  allOrigins,

  /// The adapter vouches only for the sources it names. Use this whenever the
  /// full source list was not enumerated — including the common case of "these
  /// are the sources that happened to appear in this batch".
  someOrigins,
}

/// How complete a page is. Mirrors `SyncCompleteness`.
enum PlatformCompletenessKind {
  /// Pages remain outstanding, or the adapter cannot vouch for the interval.
  /// **Nothing may be settled.** This is the correct and safe default, and the
  /// correct value for every page but the last of a paginated read.
  partial,

  /// Every page for the declared scope has been drained. Everything at or
  /// before `throughMillis`, within the scope, has been delivered.
  completeThrough,

  /// A bounded recovery rescan completed and covered its whole window. Distinct
  /// from [completeThrough] because a recovery's authority stops at the window
  /// it could actually reach. A truncated rescan is [partial].
  recoveryCompleteThrough,
}

/// A closed-open UTC interval, in milliseconds since the Unix epoch.
///
/// No day boundaries and no local calendar anywhere in this contract. That is
/// what makes daylight saving, travel across timezones, and midnight into
/// non-events.
class PlatformTimeBucket {
  PlatformTimeBucket({required this.startMillis, required this.endMillis});

  final int startMillis;
  final int endMillis;
}

/// What one source currently says about one slice of time.
///
/// **Absolute, not a delta.** A restated observation of 400 steps means the
/// source now believes that slice contains 400 steps, whether it previously said
/// 0, 300, or 900. Deltas cannot express a correction and cannot be replayed
/// safely.
///
/// **A deletion is `steps: 0`.** Corrections and deletions carry origin
/// attribution for free, because every observation names its source.
class PlatformStepObservation {
  PlatformStepObservation({
    required this.originKey,
    required this.bucket,
    required this.steps,
  });

  /// The pseudonymized origin, as **exactly eight bytes**.
  ///
  /// Already keyed when it arrives here. The raw platform identifier —
  /// `HKSource.bundleIdentifier` on iOS, `metadata.dataOrigin.packageName` on
  /// Android — lived inside one native function call and is gone. There is no
  /// field on this contract that could carry it, which is the point: a
  /// `String` here would have been an invitation, and the obvious wrong value
  /// to put in one is `HKSource.name`, which is a device name a player may have
  /// called anything at all.
  ///
  /// Eight bytes is 64 bits, which the bridge renders as the sixteen lowercase
  /// hex characters `StepOriginKey` accepts.
  ///
  /// **Exactly two lengths are legal: eight, or zero.** Zero means the platform
  /// reported no source at all, and becomes `StepOriginKey.unknown` — which is
  /// the reserved literal `unknown`, deliberately not hex, so the keying
  /// function can never produce it and confuse it with a real source. Any other
  /// length is a malformed observation and refuses the whole page. That length
  /// check is the only thing standing between a truncated raw string and the
  /// ledger, so it is not negotiable and it is not a warning.
  final Uint8List originKey;

  final PlatformTimeBucket bucket;

  /// The source's current total for this slice. Never negative. Zero means the
  /// slice is now empty — a deletion or a correction to nothing.
  final int steps;
}

/// The sources a completeness assertion covers.
class PlatformOriginScope {
  PlatformOriginScope({required this.kind, required this.originKeys});

  final PlatformOriginScopeKind kind;

  /// Pseudonymized origins, meaningful only when [kind] is
  /// [PlatformOriginScopeKind.someOrigins]; empty otherwise.
  ///
  /// Each entry obeys the same rule as [PlatformStepObservation.originKey]:
  /// eight bytes, or zero for the unknown origin. A completeness assertion
  /// names the sources it vouches for, and it must name them in the same
  /// vocabulary the observations use or it would settle nothing it meant to.
  final List<Uint8List> originKeys;
}

/// A completeness assertion, with the scope that makes it actionable.
///
/// A bare boolean cannot distinguish these, and the difference between them is
/// a player's lost walk:
///
///  - "I delivered every page for every source through Tuesday"
///  - "I delivered page 1 of 9, whose newest record happens to be Tuesday"
///  - "I delivered everything the *phone* wrote through Tuesday, and the watch
///    has been offline for a week"
class PlatformCompleteness {
  PlatformCompleteness({
    required this.kind,
    required this.dataType,
    required this.scope,
    required this.intervalStartMillis,
    required this.intervalEndMillis,
    required this.queryGeneration,
    required this.throughMillis,
  });

  final PlatformCompletenessKind kind;
  final PlatformHealthDataType dataType;
  final PlatformOriginScope scope;

  /// UTC milliseconds. The interval the adapter actually queried — not the
  /// interval it was asked for, if those differ.
  final int intervalStartMillis;
  final int intervalEndMillis;

  /// Which query or token produced this.
  ///
  /// The adapter increments it whenever it starts a new anchored query or
  /// acquires a new changes token. An assertion made under an anchor that has
  /// since been invalidated is stale, and acting on it would settle buckets a
  /// rescan is about to restate.
  final int queryGeneration;

  /// UTC milliseconds through which the scope is vouched for. Ignored when
  /// [kind] is [PlatformCompletenessKind.partial].
  final int throughMillis;
}

/// Where this page sits in a paginated read.
///
/// The reason this is on the wire at all: without it, a first page and a last
/// page are byte-identical, and a completeness assertion on page one is
/// indistinguishable from one on page nine. The bridge cross-checks it — a page
/// that claims [PlatformCompletenessKind.completeThrough] while
/// [isFinalPage] is false is downgraded to partial and counted, because
/// settling on a mid-page assertion is how 55,200 steps were lost.
class PlatformPagination {
  PlatformPagination({
    required this.pageIndex,
    required this.isFinalPage,
    this.continuation,
  });

  /// Zero-based. Diagnostic and cross-check only; the bridge never does
  /// arithmetic on it.
  final int pageIndex;

  /// True only when the adapter has drained the read. Default to false when
  /// unsure — an over-cautious partial costs a little ledger growth, and a
  /// wrong `true` costs a grant permanently.
  final bool isFinalPage;

  /// Opaque resume token for the NEXT page of the SAME read, or null when
  /// [isFinalPage] is true.
  ///
  /// Distinct from [PlatformSyncPage.nextCursor], and the distinction matters:
  /// a continuation is in-flight read state that is never persisted, while a
  /// cursor is durable sync position that is persisted only after the ledger
  /// commits. Conflating them would persist a position mid-read.
  final Uint8List? continuation;
}

/// The bounded window a recovery rescan covers.
///
/// Sent only with [PlatformSyncStatus.cursorInvalidated], where it is mandatory.
///
/// ## Why bounded, and why the gap is never granted
///
/// Incremental sync reports change since a cursor. When the platform
/// invalidates that cursor, the change stream is broken and the adapter cannot
/// say what changed. The two obvious responses are both wrong: granting
/// everything rescanned double-counts every step already granted, and resetting
/// the ledger erases the player's earned progress.
///
/// So the adapter re-reads the window authoritatively, per origin and per
/// bucket, and the core reconciles those absolute figures against what it has
/// already granted for the same slices. The subtraction is the overlap
/// correction; the no-clawback rule is what turns a shortfall into recorded
/// discrepancy rather than lost progress.
///
/// The window is clamped to `PlatformSyncRequest.maxRescanWindowMillis`. If the
/// caller's floor is older than that, the window is truncated and [truncated] is
/// set. **Steps in the unreachable gap are recorded and never granted**: they
/// cannot be distinguished from steps already counted, and inventing progress is
/// worse than missing it. The truncation is reported, not silently dropped.
///
/// ## Why interrupted recovery is safe to retry
///
/// Recovery reads state and computes a number; it mutates nothing until the
/// ledger batch commits. If the process dies at any point before that, the
/// ledger and the old cursor are unchanged, so the next attempt recomputes
/// exactly the same result. Combined with the ledger's batch-identity replay
/// guard, recovery is idempotent.
///
/// ## On record identity
///
/// Health Connect exposes per-record UIDs, and deduplicating by UID inside the
/// overlap window would be more precise. It is deliberately not the primary
/// mechanism: retaining identifiers indefinitely is unbounded storage, and it
/// would leave the game holding a shadow copy of health data, which
/// `GAME_BIBLE/HEALTH_INTEGRATION` forbids. Identity may be used *within* a
/// single recovery pass as a refinement; the per-slice absolute arithmetic is
/// what the correctness argument rests on.
class PlatformRescanWindow {
  PlatformRescanWindow({
    required this.startMillis,
    required this.endMillis,
    required this.truncated,
  });

  final int startMillis;
  final int endMillis;

  /// True when the adapter clamped the window, leaving an unreachable gap.
  final bool truncated;
}

/// What the caller is asking for.
///
/// A request object rather than positional arguments, so a field can be added
/// without a three-language signature change — and so every field arrives with
/// its own name at each call site rather than as the third `int?`.
class PlatformSyncRequest {
  PlatformSyncRequest({
    required this.dataType,
    required this.bucketWidthMillis,
    required this.maxRescanWindowMillis,
    required this.includeManualEntries,
    this.cursor,
    this.continuation,
    this.rescanFloorMillis,
  });

  final PlatformHealthDataType dataType;

  /// The bucket resolution the caller will accept, in milliseconds.
  ///
  /// **The adapter must not send narrower buckets than this.** The privacy
  /// ruling bounds retention *length* — seven days — and says nothing about
  /// *resolution*. One-minute buckets satisfy it exactly as written and produce
  /// roughly ten thousand entries per origin: a minute-by-minute record of when
  /// the player moved, kept for a week. Nobody would have decided to build that.
  /// `TimeBucket.minimumWidthMillis` is one hour and the bridge refuses
  /// anything narrower.
  final int bucketWidthMillis;

  /// The longest window a recovery rescan may cover. The adapter clamps to this
  /// and reports `truncated`.
  final int maxRescanWindowMillis;

  /// Whether manually-entered samples count.
  ///
  /// False by default in the game: `HKMetadataKeyWasUserEntered` on iOS,
  /// `Metadata.recordingMethod` on Android. The default reflects real movement;
  /// the choice belongs to the player.
  final bool includeManualEntries;

  /// The durable sync position, or null for a first read. Opaque: an archived
  /// `HKQueryAnchor` on iOS, a Health Connect changes token on Android.
  final Uint8List? cursor;

  /// Resume token from the previous page's [PlatformPagination.continuation].
  /// Null starts a fresh read.
  final Uint8List? continuation;

  /// The oldest instant a recovery rescan need reach, if the cursor turns out
  /// to be invalid. Null means the adapter uses its full
  /// [maxRescanWindowMillis].
  final int? rescanFloorMillis;
}

/// Whether the platform's health service is present and usable.
///
/// A result rather than a bare bool so that "no" arrives with a reason, and a
/// typed result rather than an exception because absence is a NORMAL state the
/// game stays fully playable through — Android without Health Connect installed
/// is the ordinary case, not an error.
class PlatformAvailabilityResult {
  PlatformAvailabilityResult({
    required this.available,
    this.reason,
    this.diagnostic,
  });

  final bool available;

  /// Set when [available] is false.
  final PlatformUnavailableReason? reason;

  /// A short technical note for a log line. **Never player-facing, and never a
  /// source identifier, device name, or health value.**
  final String? diagnostic;
}

/// The outcome of an authorization request. Typed, never an exception.
class PlatformAuthorizationResult {
  PlatformAuthorizationResult({required this.state, this.diagnostic});

  final PlatformAuthorizationState state;

  /// See [PlatformAvailabilityResult.diagnostic]. Same prohibition.
  final String? diagnostic;
}

/// One page of an answer.
///
/// Every field's applicability is stated by [status]; the bridge validates the
/// combination rather than trusting it, and reports a malformed page as a typed
/// refusal instead of guessing what the adapter meant.
class PlatformSyncPage {
  PlatformSyncPage({
    required this.status,
    required this.observations,
    required this.completeness,
    required this.pagination,
    this.nextCursor,
    this.rescan,
    this.unavailableReason,
    this.diagnostic,
  });

  final PlatformSyncStatus status;

  /// Absolute per-`(source, bucket)` figures. Empty for
  /// [PlatformSyncStatus.noChange] and [PlatformSyncStatus.unavailable].
  ///
  /// For [PlatformSyncStatus.cursorInvalidated] these are the AUTHORITATIVE
  /// contents of [rescan]'s window, not a delta.
  final List<PlatformStepObservation> observations;

  final PlatformCompleteness completeness;

  final PlatformPagination pagination;

  /// The candidate durable cursor.
  ///
  /// **Returned and forgotten.** The adapter must not persist it. The caller
  /// makes it durable only after the ledger and snapshot have committed; see
  /// the commit-order note at the top of this file. Null when the adapter has
  /// nothing to offer — which is always the case for
  /// [PlatformSyncStatus.unavailable], and the case for
  /// [PlatformSyncStatus.cursorInvalidated] until recovery has been committed.
  final Uint8List? nextCursor;

  /// Mandatory when [status] is [PlatformSyncStatus.cursorInvalidated], absent
  /// otherwise. A bare invalidation would leave the core with no authoritative
  /// figure and no safe move.
  final PlatformRescanWindow? rescan;

  /// Mandatory when [status] is [PlatformSyncStatus.unavailable].
  final PlatformUnavailableReason? unavailableReason;

  /// See [PlatformAvailabilityResult.diagnostic]. Same prohibition.
  final String? diagnostic;
}

@HostApi()
abstract class HealthHostApi {
  /// Installs the device-bound origin-keying salt for this engine attachment.
  ///
  /// **The smallest surface that can work**, and it was chosen as the smallest:
  /// one method, one direction, one value, no reply channel, no storage.
  ///
  /// * **In memory only.** Native holds the salt for the lifetime of the engine
  ///   attachment and drops it on detach. It must not be written to
  ///   `UserDefaults`, `SharedPreferences`, a DataStore, a file, or the
  ///   Keychain — this plugin is a *consumer* of the app's identity, never a
  ///   second custodian of one.
  /// * **Never generated natively.** There is no "mint if absent" path and
  ///   there must never be one. `IdentityVault` owns the lifecycle, and a
  ///   launch that could not resolve the identity has already been blocked by
  ///   `BootstrapCoordinator` with
  ///   `BootstrapBlockReason.originIdentityMissing`.
  /// * **Fail-closed before it is called.** Until this returns
  ///   [PlatformOriginKeyingOutcome.installed], `fetchSteps` must answer
  ///   [PlatformUnavailableReason.originKeyingUnconfigured] and read nothing.
  ///
  /// [algorithmVersion] is the keying scheme the caller expects. An adapter
  /// that does not implement it refuses with
  /// [PlatformOriginKeyingOutcome.unsupportedAlgorithm] rather than falling
  /// back — a silent fallback produces keys nothing else on the device agrees
  /// with, which is indistinguishable from a new device and re-grants the whole
  /// retention window.
  ///
  /// ## Why the salt crosses at all
  ///
  /// It is the direct cost of pseudonymizing natively, and it is worth naming
  /// rather than burying. Keying in Dart would keep the salt in one address
  /// space, at the price of a raw identifier crossing the wire on every
  /// observation. Keying natively keeps every raw identifier inside its own
  /// process, at the price of the salt crossing once per attachment. The owner
  /// ruled for the second trade: an identifier crosses thousands of times and a
  /// salt crosses once, and the salt is not itself identifying — losing it
  /// costs a fail-closed refusal, which is recoverable, while a leaked device
  /// name is not.
  @async
  PlatformOriginKeyingResult installOriginKeying(
    Uint8List salt,
    int algorithmVersion,
  );

  /// Whether the platform's health service is present and usable.
  ///
  /// False on Android without Health Connect installed — a normal state, not an
  /// error, and one the game must remain fully playable through.
  @async
  PlatformAvailabilityResult availability();

  /// Requests read-only step authorization. Never throws for denial.
  @async
  PlatformAuthorizationResult requestAuthorization();

  /// Reads one page.
  ///
  /// Must never throw for an expected condition — denial, absence, an invalid
  /// cursor, an empty result — all of which are reported through
  /// [PlatformSyncPage]. On genuine error the adapter leaves its own state
  /// untouched and returns [PlatformSyncStatus.unavailable] with
  /// [PlatformUnavailableReason.transientFailure].
  @async
  PlatformSyncPage fetchSteps(PlatformSyncRequest request);
}
