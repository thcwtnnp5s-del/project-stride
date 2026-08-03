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

import 'cursor_authorization.dart';
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

    final bool isFinalPage = page.pagination.isFinalPage;
    final Uint8List? continuation = isFinalPage
        ? null
        : page.pagination.continuation;

    // A cursor is only meaningful once the read has drained.
    //
    // This is the 55,200-step defect on the CURSOR axis. `DECISIONS/0014`
    // closed the completeness axis — a non-final page is downgraded to
    // `PartialDelivery` so nothing settles — but the cursor was built from
    // `page.nextCursor` without consulting `isFinalPage` at all, so page 1 of 9
    // authorized a checkpoint meaning "after the whole read". Reconcile page 1,
    // get backgrounded, resume from that cursor, and pages 2 through 9 are
    // never delivered again. Nothing counts it: completeness was correctly
    // partial, so no origin settled and `lateDiscardedSlices` never fired. The
    // steps are simply gone, silently and permanently.
    //
    // Dropped here rather than refused in the core, because `SyncFetch`
    // deliberately does not expose pagination to the reconciler — the core
    // cannot see that a page was non-final, so it structurally cannot refuse
    // this. The bridge is the only place that knows.
    // ONE decision, made once, in `cursor_authorization.dart`.
    //
    // It used to be answered in three places — here for pagination, again in
    // the recovery branch for truncation, and implicitly by whichever
    // completeness happened to be attached. Three defects came out of that, the
    // third of them after the first two were fixed, because each fix landed
    // where its symptom appeared rather than where the rule lived.
    //
    // Native adapters OFFER a candidate. This authorizes it. Snapshot commit
    // determines durability.
    final SyncKind syncKind = switch (page.status) {
      PlatformSyncStatus.cursorInvalidated => SyncKind.recovery,
      PlatformSyncStatus.noChange => SyncKind.noChange,
      _ => SyncKind.incremental,
    };

    // The whole delivery, or nothing.
    //
    // A page whose status and completeness disagree about what was read cannot
    // be interpreted at all, and every interpretation of it is a guess. The
    // earlier behaviour guessed twice: a `noChange` page carrying observations
    // was promoted to `incremental`, and a mismatched completeness variant was
    // simply carried through. Both kept part of a page that had already proved
    // it could not be trusted about the other part.
    //
    // The owner ruled that back. `ContractViolationSync` reaches the reconciler
    // as `malformedBatch`, which `GameEngine` REJECTS — so no event is applied
    // and `GameState` is not touched, which is a stronger guarantee than
    // `ProviderUnavailableSync` gives (that one still moves `sourceState`).
    //
    // Checked on the DECLARED completeness kind, not the effective one. The
    // non-final-page downgrade below is a correction for pagination; it does
    // not make a contradictory statement non-contradictory, and reading the
    // corrected value here would let a mismatch hide behind an unrelated fix.
    final SyncContractViolation? violation = _violation(
      kind: syncKind,
      hasObservations: observations.isNotEmpty,
      hasRescanWindow: page.rescan != null,
      declared: page.completeness.kind,
    );
    if (violation != null) {
      if (syncKind == SyncKind.noChange && observations.isNotEmpty) {
        faults.add(SyncFault.observationsOnNoChange);
      }
      faults.add(switch (violation) {
        SyncContractViolation.noChangeWithPayload =>
          SyncFault.noChangeWithPayload,
        SyncContractViolation.mismatchedCompleteness =>
          SyncFault.mismatchedCompleteness,
      });
      // No continuation, and final by declaration. The delivery was rejected
      // whole, so there is no page to resume and nothing to wait for; handing
      // back a resume token would carry a rejected read forward.
      return SyncFetch(ContractViolationSync(violation), faults: faults);
    }

    // A truncated rescan covered less than it was asked to. Settling on it
    // would bury whatever fell outside the truncation, so completeness is
    // downgraded before the authorization sees it.
    final bool truncated = page.rescan?.truncated ?? false;
    final SyncCompleteness effectiveCompleteness =
        syncKind == SyncKind.recovery && truncated
        ? const PartialDelivery()
        : completeness;

    final CursorAuthorization authorization = authorizeCursor(
      hasCandidate: page.nextCursor != null,
      kind: syncKind,
      isFinalPage: isFinalPage,
      completeness: effectiveCompleteness,
      truncated: truncated,
    );
    if (authorization.raisesProhibitedFault) {
      faults.add(SyncFault.cursorOfferedWhenProhibited);
    }
    final SyncCursor? cursor = authorization.isAuthorized
        ? SyncCursor(page.nextCursor!)
        : null;

    switch (page.status) {
      case PlatformSyncStatus.cursorInvalidated:
        final PlatformRescanWindow? window = page.rescan;
        if (window == null) {
          // No window means no authoritative figure and no safe move. Granting
          // the rescanned content without knowing what it covers is the
          // double-count; discarding it silently is the lost grant.
          //
          // A candidate cursor offered here is dropped — `ProviderUnavailableSync`
          // has no field one could travel in — and the drop is now REPORTED.
          //
          // It was not, and the asymmetry was an ordering artefact rather than
          // a decision: `authorizeCursor` runs before this branch and answers
          // `authorized` for a page that is final, recovery-complete and
          // untruncated, so the fault channel had already been settled by the
          // time the missing window was noticed. The structurally identical
          // `unavailable` path raised the fault; this one silently did not.
          // `cursorOfferedWhenProhibited` is documented as "a cursor was
          // offered on a path that must not advance one", and a recovery that
          // cannot name its window is exactly such a path.
          return SyncFetch(
            const ProviderUnavailableSync(
              ProviderUnavailableReason.transientFailure,
            ),
            faults: <SyncFault>[
              ...faults,
              SyncFault.invalidatedWithoutRescan,
              if (page.nextCursor != null &&
                  !faults.contains(SyncFault.cursorOfferedWhenProhibited))
                SyncFault.cursorOfferedWhenProhibited,
            ],
            cursorAuthorization: authorization,
          );
        }
        // Truncation and cursor eligibility are both settled above, by the one
        // authorization. This branch only assembles the response.
        return SyncFetch(
          CursorInvalidatedSync(
            window: RescanWindow(
              startMillis: window.startMillis,
              endMillis: window.endMillis,
              truncated: window.truncated,
            ),
            observations: observations,
            nextCursor: cursor,
            completeness: effectiveCompleteness,
          ),
          faults: faults,
          isFinalPage: isFinalPage,
          continuation: continuation,
          cursorAuthorization: authorization,
        );

      case PlatformSyncStatus.noChange:
        // Observations, a rescan window, and a settling completeness are all
        // rejected above as contract violations, so what reaches here is a
        // structurally empty no-change page and nothing else.
        return SyncFetch(
          NoChangeSync(nextCursor: cursor, completeness: completeness),
          faults: faults,
          isFinalPage: isFinalPage,
          continuation: continuation,
          cursorAuthorization: authorization,
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
          cursorAuthorization: authorization,
        );

      case PlatformSyncStatus.unavailable:
        // Handled above, before any conversion. Unreachable.
        throw StateError('unavailable pages are handled before translation');
    }
  }

  /// Which part of the contract this page broke, or null if it broke none.
  ///
  /// ## Why `noChange` + a complete variant is a *mismatch* and not a *payload*
  ///
  /// Both enum members were documented as covering it —
  /// [SyncContractViolation.noChangeWithPayload] says "or a complete-through
  /// assertion", and [SyncContractViolation.mismatchedCompleteness] says "or a
  /// no-change asserting either". One of the two had to give, because the point
  /// of having two members is that a diagnostic can tell them apart.
  ///
  /// The split made here: **payload is structure, mismatch is completeness.**
  /// A no-change page that carries observations or a rescan window has a
  /// payload it cannot have; a no-change page that vouches for a window has a
  /// completeness variant that does not match its kind, which is what
  /// `mismatchedCompleteness` is named for. Each violation then names the field
  /// that is actually wrong. The doc comments on both members were corrected to
  /// match.
  static SyncContractViolation? _violation({
    required SyncKind kind,
    required bool hasObservations,
    required bool hasRescanWindow,
    required PlatformCompletenessKind declared,
  }) {
    switch (kind) {
      case SyncKind.noChange:
        if (hasObservations || hasRescanWindow) {
          return SyncContractViolation.noChangeWithPayload;
        }
        if (declared != PlatformCompletenessKind.partial) {
          return SyncContractViolation.mismatchedCompleteness;
        }
        return null;

      case SyncKind.incremental:
        // Recovery completeness is bounded by the window a rescan could reach.
        // An ordinary incremental read has no such window, so the assertion has
        // no bound to be read against.
        if (declared == PlatformCompletenessKind.recoveryCompleteThrough) {
          return SyncContractViolation.mismatchedCompleteness;
        }
        return null;

      case SyncKind.recovery:
        // The reverse, and the more dangerous direction: ordinary completeness
        // is unbounded, so adopting it from a rescan settles past the window
        // the rescan actually covered.
        if (declared == PlatformCompletenessKind.completeThrough) {
          return SyncContractViolation.mismatchedCompleteness;
        }
        return null;
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
    // Carried through as itself, not folded into anything.
    //
    // This was mapped to `serviceUnavailable` while the core had no member for
    // it, which reported a fail-closed configuration fault as **retryable** and
    // disguised it as "the platform has no health service" — a different
    // problem with a different fix. The owner ruled a fourth member in, with
    // `retryable: false`; see `ProviderUnavailableReason`.
    //
    // Retrying cannot install an identity. Resolution is to reopen or
    // construct the adapter with the existing device-bound origin-key identity.
    PlatformUnavailableReason.originKeyingUnconfigured =>
      ProviderUnavailableReason.originKeyingUnconfigured,
  };
}
