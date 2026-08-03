/// The bridge: the Pigeon boundary in, a `SyncResponse` out.
///
/// This class replaces `PlatformStepProvider`, which converted the platform
/// boundary into `StepFetchResult` — a flat `newSteps: int` that nothing in the
/// simulation consumed. `DECISIONS/0014` records the finding; the short version
/// is that the flat contract could not express per-origin attribution, scoped
/// completeness, or partial pages, so an adapter written honestly against it
/// could not have satisfied the core.
///
/// It contains no reconciliation logic. It converts, validates the combination
/// of fields the adapter sent, and reports what it had to correct. Ledger
/// arithmetic lives in `stride_core`, where it is tested without a device.
///
/// ## Fail-closed by construction
///
/// There is no public constructor. The only way to obtain a source is [open],
/// which installs the device-bound keying salt into the native adapter and
/// hands back a usable source **only if the adapter accepted it**. An unkeyed
/// source is therefore not a state this class can be in — which matters,
/// because observations keyed under no salt or the wrong salt would re-key
/// every origin and grant the whole retention window a second time.
///
/// ## The bias in every judgement call here
///
/// When the adapter contradicts itself, this class chooses the option that
/// **settles fewer buckets and grants no more steps**. Under-settling costs a
/// little ledger growth, which compaction reclaims later. Over-settling buries
/// a bucket that a late page was about to fill, and those steps are unreachable
/// forever. The two errors are not symmetric and are not treated as if they
/// were.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:stride_core/stride_core.dart';

import 'messages.g.dart';
import 'origin_gateway.dart';
import 'origin_pseudonymizer.dart';
import 'step_sync_source.dart';

/// Why the device identity could not be installed into the adapter.
enum OriginKeyingRefusal {
  /// The adapter does not implement the requested algorithm version.
  unsupportedAlgorithm,

  /// The adapter rejected the salt as malformed.
  rejected,

  /// The salt offered was empty.
  ///
  /// Refused before the channel is touched. An empty salt would make every
  /// origin key a bare unkeyed digest of a package name — trivially reversible
  /// by anyone with a list of package names, which is everyone.
  emptySalt,
}

/// The result of opening a keyed platform source.
@immutable
final class OriginKeyingInstall {
  const OriginKeyingInstall.installed(PlatformStepSource this.source)
    : refusal = null;

  const OriginKeyingInstall.refused(OriginKeyingRefusal this.refusal)
    : source = null;

  /// Non-null only when the adapter accepted the identity.
  final PlatformStepSource? source;

  /// Non-null only when it did not.
  final OriginKeyingRefusal? refusal;

  bool get isInstalled => source != null;
}

/// Reads steps from the real platform through the Pigeon boundary.
final class PlatformStepSource implements StepSyncSource {
  PlatformStepSource._(this._api);

  /// Installs the device identity and returns a keyed source, or the refusal.
  ///
  /// [salt] is the device-bound salt from `IdentityVault` — the iOS Keychain
  /// item under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, or the
  /// app-private Android file. It is handed to native **once per engine
  /// attachment** and held there in memory only.
  ///
  /// A launch that could not resolve the identity has already been blocked by
  /// `BootstrapCoordinator` with `BootstrapBlockReason.originIdentityMissing`,
  /// so in practice this is never called without one. The empty-salt refusal is
  /// here anyway, because "the caller would never" is how it happens.
  static Future<OriginKeyingInstall> open({
    required Uint8List salt,
    HealthHostApi? api,
    int algorithmVersion = originKeyingAlgorithmVersion,
  }) async {
    if (salt.isEmpty) {
      return const OriginKeyingInstall.refused(OriginKeyingRefusal.emptySalt);
    }

    final HealthHostApi channel = api ?? HealthHostApi();
    final PlatformOriginKeyingResult result = await channel.installOriginKeying(
      Uint8List.fromList(salt),
      algorithmVersion,
    );

    return switch (result.outcome) {
      PlatformOriginKeyingOutcome.installed => OriginKeyingInstall.installed(
        PlatformStepSource._(channel),
      ),
      PlatformOriginKeyingOutcome.unsupportedAlgorithm =>
        const OriginKeyingInstall.refused(
          OriginKeyingRefusal.unsupportedAlgorithm,
        ),
      PlatformOriginKeyingOutcome.rejected => const OriginKeyingInstall.refused(
        OriginKeyingRefusal.rejected,
      ),
    };
  }

  final HealthHostApi _api;

  /// The origin decoder. Stateless — it validates, it does not key.
  static const OriginGateway gateway = OriginGateway();

  @override
  Future<HealthAvailability> availability() async {
    final PlatformAvailabilityResult result = await _api.availability();
    if (result.available) return const HealthAvailability(available: true);
    return HealthAvailability.unavailable(
      _reason(result.reason) ?? ProviderUnavailableReason.serviceUnavailable,
    );
  }

  @override
  Future<HealthAuthorization> requestAuthorization() async {
    final PlatformAuthorizationResult result = await _api
        .requestAuthorization();
    return switch (result.state) {
      PlatformAuthorizationState.granted => HealthAuthorization.granted,
      PlatformAuthorizationState.denied => HealthAuthorization.denied,
      PlatformAuthorizationState.unavailable => HealthAuthorization.unavailable,
    };
  }

  @override
  Future<SyncFetch> fetchSteps(SyncRequest request) async {
    final PlatformSyncPage page = await _api.fetchSteps(
      PlatformSyncRequest(
        dataType: PlatformHealthDataType.steps,
        // Clamped up, never down. An adapter cannot be talked into a
        // minute-resolution read by a caller that asked for one.
        bucketWidthMillis:
            request.bucketWidthMillis < TimeBucket.minimumWidthMillis
            ? TimeBucket.minimumWidthMillis
            : request.bucketWidthMillis,
        maxRescanWindowMillis: request.maxRescanWindowMillis,
        includeManualEntries: request.includeManualEntries,
        cursor: request.cursor?.copy,
        continuation: request.continuation,
        rescanFloorMillis: request.rescanFloorMillis,
      ),
    );
    return translate(page, gateway);
  }

  /// Turns one platform page into the value the core consumes.
  ///
  /// Static and gateway-injected so every rule below is testable with a
  /// fabricated page, no channel, no device, and no health service.
  static SyncFetch translate(PlatformSyncPage page, OriginGateway gateway) {
    final List<SyncFault> faults = <SyncFault>[];

    if (page.status == PlatformSyncStatus.unavailable) {
      final ProviderUnavailableReason? reason = _reason(page.unavailableReason);
      if (reason == null) faults.add(SyncFault.unavailableWithoutReason);
      if (page.unavailableReason ==
          PlatformUnavailableReason.originKeyingUnconfigured) {
        // Not transient, and not the player's problem to retry. It means the
        // adapter is reading without the device identity, which would re-key
        // every origin — so the adapter refused, correctly, and the fault is
        // how that reaches a diagnostic without being mistaken for a network
        // blip.
        faults.add(SyncFault.originKeyingUnconfigured);
      }
      if (page.nextCursor != null) {
        faults.add(SyncFault.cursorOfferedWhenProhibited);
      }
      return SyncFetch(
        ProviderUnavailableSync(
          reason ?? ProviderUnavailableReason.transientFailure,
        ),
        faults: faults,
      );
    }

    // Every observation is converted before anything is decided. A page with a
    // single malformed slice is refused whole: dropping the slice while
    // honouring the page's completeness assertion would settle the bucket the
    // drop just emptied, and those steps would never be reachable again.
    final List<StepObservation> observations = <StepObservation>[];
    for (final PlatformStepObservation raw in page.observations) {
      final StepObservation? converted = gateway.toObservation(raw);
      if (converted == null) {
        return SyncFetch(
          const ProviderUnavailableSync(
            ProviderUnavailableReason.transientFailure,
          ),
          faults: <SyncFault>[...faults, SyncFault.malformedObservation],
        );
      }
      observations.add(converted);
    }

    if (OriginGateway.scopeIsContradictory(page.completeness.scope)) {
      faults.add(SyncFault.contradictoryOriginScope);
    }

    final SyncCompleteness? completeness = _completeness(page, gateway, faults);
    if (completeness == null) {
      // A scope naming an origin nobody can identify is not a narrower
      // assertion, it is an unusable one — and settling against it would settle
      // the wrong buckets.
      return SyncFetch(
        const ProviderUnavailableSync(
          ProviderUnavailableReason.transientFailure,
        ),
        faults: <SyncFault>[...faults, SyncFault.malformedOriginKey],
      );
    }

    final SyncCursor? cursor = page.nextCursor == null
        ? null
        : SyncCursor(page.nextCursor!);
    final bool isFinalPage = page.pagination.isFinalPage;
    final Uint8List? continuation = isFinalPage
        ? null
        : page.pagination.continuation;

    switch (page.status) {
      case PlatformSyncStatus.cursorInvalidated:
        final PlatformRescanWindow? window = page.rescan;
        if (window == null) {
          // No window means no authoritative figure and no safe move. Granting
          // the rescanned content without knowing what it covers is the
          // double-count; discarding it silently is the lost grant.
          return SyncFetch(
            const ProviderUnavailableSync(
              ProviderUnavailableReason.transientFailure,
            ),
            faults: <SyncFault>[...faults, SyncFault.invalidatedWithoutRescan],
          );
        }
        return SyncFetch(
          CursorInvalidatedSync(
            window: RescanWindow(
              startMillis: window.startMillis,
              endMillis: window.endMillis,
              truncated: window.truncated,
            ),
            observations: observations,
            nextCursor: cursor,
            // A truncated rescan covered less than it was asked to. Settling on
            // it would bury whatever fell outside the truncation.
            completeness: window.truncated
                ? const PartialDelivery()
                : completeness,
          ),
          faults: faults,
          isFinalPage: isFinalPage,
          continuation: continuation,
        );

      case PlatformSyncStatus.noChange:
        if (observations.isNotEmpty) {
          // Real steps are never thrown away over a status mismatch. The
          // response is promoted rather than the observations discarded.
          faults.add(SyncFault.observationsOnNoChange);
          return SyncFetch(
            IncrementalSync(
              observations: observations,
              nextCursor: cursor,
              completeness: completeness,
            ),
            faults: faults,
            isFinalPage: isFinalPage,
            continuation: continuation,
          );
        }
        return SyncFetch(
          NoChangeSync(nextCursor: cursor, completeness: completeness),
          faults: faults,
          isFinalPage: isFinalPage,
          continuation: continuation,
        );

      case PlatformSyncStatus.incremental:
        return SyncFetch(
          IncrementalSync(
            observations: observations,
            nextCursor: cursor,
            completeness: completeness,
          ),
          faults: faults,
          isFinalPage: isFinalPage,
          continuation: continuation,
        );

      case PlatformSyncStatus.unavailable:
        // Handled above, before any conversion. Unreachable.
        throw StateError('unavailable pages are handled before translation');
    }
  }

  /// Builds the completeness assertion, downgrading anything unsafe.
  ///
  /// **This is the only place in the program that constructs a settling
  /// completeness.** `CompleteThrough` and `RecoveryCompleteThrough` are built
  /// here and nowhere else, and this function returns [PartialDelivery] before
  /// it reaches either of them unless the page says it is final. That is the
  /// structural form of "a partial page may not advance a settled watermark" —
  /// not a rule the caller has to remember, but the only path that exists.
  /// `Scripts/check-step-model.sh` anchors those two constructors to this file
  /// so a second path cannot appear.
  ///
  /// Returns null when the scope is undecodable, which refuses the page.
  static SyncCompleteness? _completeness(
    PlatformSyncPage page,
    OriginGateway gateway,
    List<SyncFault> faults,
  ) {
    final PlatformCompleteness declared = page.completeness;
    if (declared.kind == PlatformCompletenessKind.partial) {
      return const PartialDelivery();
    }

    if (!page.pagination.isFinalPage) {
      // The 55,200-step defect, in contract form. A completeness assertion made
      // on page one of nine is indistinguishable, from inside the core, from
      // one made on page nine — so the contract carries the page state and this
      // is the line that reads it.
      faults.add(SyncFault.completenessOnNonFinalPage);
      return const PartialDelivery();
    }

    final OriginScope? origins = gateway.toScope(declared.scope);
    if (origins == null) return null;

    final CompletenessScope scope = CompletenessScope(
      dataType: HealthDataType.steps,
      origins: origins,
      intervalStartMillis: declared.intervalStartMillis,
      intervalEndMillis: declared.intervalEndMillis,
      queryGeneration: declared.queryGeneration,
    );

    return switch (declared.kind) {
      PlatformCompletenessKind.completeThrough => CompleteThrough(
        throughMillis: declared.throughMillis,
        scope: scope,
      ),
      PlatformCompletenessKind.recoveryCompleteThrough =>
        RecoveryCompleteThrough(
          throughMillis: declared.throughMillis,
          scope: scope,
        ),
      PlatformCompletenessKind.partial => const PartialDelivery(),
    };
  }

  static ProviderUnavailableReason? _reason(
    PlatformUnavailableReason? reason,
  ) => switch (reason) {
    null => null,
    PlatformUnavailableReason.serviceMissing =>
      ProviderUnavailableReason.serviceUnavailable,
    PlatformUnavailableReason.permissionUnavailable =>
      ProviderUnavailableReason.permissionUnavailable,
    PlatformUnavailableReason.transientFailure =>
      ProviderUnavailableReason.transientFailure,
    // Deliberately NOT transientFailure. Retrying will not install an
    // identity, and a reconciler that treats this as a blip would retry
    // forever. `serviceUnavailable` is the honest mapping: the provider
    // genuinely cannot serve, and `SyncFault.originKeyingUnconfigured`
    // carries the specific reason to a diagnostic.
    //
    // See the report's named ambiguity: the cleaner answer is a fourth
    // `ProviderUnavailableReason` in stride_core, which was not taken here
    // because `StepReconciler` switches on that enum and belongs to another
    // agent's surface this milestone.
    PlatformUnavailableReason.originKeyingUnconfigured =>
      ProviderUnavailableReason.serviceUnavailable,
  };
}
