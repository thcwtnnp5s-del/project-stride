package com.projectstride.stride_health

import android.content.Context

/**
 * Health Connect step reader.
 *
 * ## Current scope: a compiling shell
 *
 * It satisfies the S-01A boundary and reports the platform as unavailable. The
 * real Health Connect read is a separate task and a separate agent's work.
 *
 * Reporting `unavailable` is deliberate rather than throwing: it exercises the
 * same graceful-degradation path the game must handle when Health Connect is
 * genuinely absent, so the app is fully playable against this shell.
 *
 * ## What the real implementation must honour
 *
 * Health Connect's **Changes API** — `getChangesToken()` then
 * `getChanges(token)` — is the direct analogue of HealthKit's anchored query,
 * returning upserts and deletions since a token.
 *
 * * Read-only `StepsRecord` permission. No write scope, ever.
 * * `Metadata.recordingMethod` supplies the manual-entry filter, driven by
 *   `PlatformSyncRequest.includeManualEntries`.
 * * Health Connect is built into Android 14+; earlier versions require the
 *   Health Connect app. Absence must degrade gracefully — the same path as a
 *   denied permission.
 * * Deep-history permissions are not requested. The ledger never needs old
 *   data, only what is new since the last cursor.
 *
 * ### 1. Observations are ABSOLUTE, per source and per bucket
 *
 * The boundary carries `PlatformStepObservation`, not a flat delta. Each one is
 * the source's **current total** for one `(source, bucket)` slice. So when the
 * Changes API reports a deletion or an edit, the adapter must RE-READ the
 * affected bucket with an aggregate query and send its new absolute total. A
 * bucket that is now empty is sent as `steps = 0`, not omitted. Forwarding "a
 * record was removed" without restating the bucket leaves the core with nothing
 * to reconcile against.
 *
 * Buckets must be at least `PlatformSyncRequest.bucketWidthMillis` wide. The
 * bridge refuses anything narrower and the refusal costs the whole page — a
 * minute-resolution read would be a minute-by-minute record of when the player
 * moved, which the privacy ruling does not permit and nobody decided to build.
 *
 * ### 2. Origins are keyed HERE, and the raw package name never leaves
 *
 * `PlatformStepObservation.originKey` is eight bytes: FNV-1a, 64-bit,
 * big-endian, over `salt || 0x1F || utf8(packageName)`. The input must be
 * `record.metadata.dataOrigin.packageName`. **Never `Device.model`,
 * `Device.manufacturer`, or any user-visible label** — those are display names,
 * and a player may have called their device anything at all.
 * `Scripts/check-origin-privacy.sh` rejects those APIs in this file.
 *
 * The raw package name exists inside the keying function and nowhere else. It
 * is not stored in a field, not put in a log, and not sent across Pigeon —
 * there is no field on the contract that could carry it.
 *
 * The salt arrives through [installOriginKeying] and is held **in memory
 * only**, for the lifetime of the engine attachment. It is never generated
 * here and never written to `SharedPreferences`, a DataStore, or a file. A
 * second identity would re-key every origin, and a re-keyed origin looks
 * exactly like a new device: its recent buckets look ungranted and the whole
 * retention window is granted again.
 *
 * `Long` is signed. Use `ushr`, not `shr`, when rendering the digest to bytes —
 * an arithmetic shift sign-extends for half of all hash values and would
 * produce a stable, self-consistent, and completely wrong key. Assert against
 * `packages/stride_health/test/origin_key_vectors.dart` before believing the
 * implementation works.
 *
 * ### 3. Completeness is asserted, never guessed
 *
 * `PlatformCompletenessKind.COMPLETE_THROUGH` may be sent only after every page
 * for the declared scope has been drained. `ALL_ORIGINS` is legitimate only if
 * the adapter actually enumerated every source Health Connect knows about; "the
 * sources that appeared in this batch" is `SOME_ORIGINS`. Asserting completeness
 * early is indistinguishable, from inside the core, from the data not existing,
 * and the consequence is a silent permanent lost grant.
 *
 * Set `pagination.isFinalPage = false` and supply a `continuation` for every
 * page but the last. The bridge downgrades a completeness assertion made on a
 * non-final page, which is a correction, not a licence to be sloppy.
 *
 * ### 4. Token invalidation — the recovery contract
 *
 * Health Connect can expire or invalidate a changes token. HealthKit has no
 * equivalent, which makes this the one genuinely Android-specific failure mode
 * in the project. When it happens the adapter must NOT report the whole history
 * as new, and must NOT signal that the ledger should reset.
 *
 * Instead it returns `PlatformSyncStatus.CURSOR_INVALIDATED` with a
 * `PlatformRescanWindow` describing the bounded window
 * `[rescanFloorMillis, now]` — clamped to `maxRescanWindowMillis` and flagged
 * `truncated` when clamping occurred — and observations that are the
 * **authoritative per-origin, per-bucket contents of that window**. The core
 * reconciles those absolutes against what it already granted for the same
 * slices; the subtraction is the overlap correction and the no-clawback rule
 * turns any shortfall into recorded discrepancy rather than lost progress.
 *
 * Steps in a truncated gap are recorded and never granted: they cannot be
 * distinguished from steps already counted, and inventing progress is worse than
 * missing it.
 *
 * ### 5. The cursor is never native state
 *
 * The adapter returns a candidate `nextCursor` and forgets it. It must not
 * write one to `SharedPreferences`, a DataStore, or a file. The commit order is
 * inviolable: return data and a candidate cursor, reconciliation produces
 * grants, the ledger and snapshot commit, and only then is the cursor durable.
 * `Scripts/check-origin-privacy.sh` rejects native persistence APIs here.
 *
 * No replacement token is offered on the invalidated path until recovery has
 * been committed, which is what makes an interrupted recovery safe to retry.
 */
class HealthConnectAdapter(
    @Suppress("unused") private val context: Context
) : HealthHostApi {

    /**
     * The device-bound keying salt, in memory only.
     *
     * `private` and never written anywhere durable. Cleared on detach by
     * [StrideHealthPlugin]. Until it is set, [fetchSteps] refuses.
     */
    private var originSalt: ByteArray? = null

    override fun installOriginKeying(
        salt: ByteArray,
        algorithmVersion: Long,
        callback: (Result<PlatformOriginKeyingResult>) -> Unit
    ) {
        if (algorithmVersion != ORIGIN_KEYING_ALGORITHM_VERSION) {
            // A typed refusal rather than a silent fallback. Keys that nothing
            // else on the device agrees with look exactly like a new device.
            callback(
                Result.success(
                    PlatformOriginKeyingResult(
                        outcome = PlatformOriginKeyingOutcome.UNSUPPORTED_ALGORITHM,
                        diagnostic = null
                    )
                )
            )
            return
        }
        if (salt.isEmpty()) {
            callback(
                Result.success(
                    PlatformOriginKeyingResult(
                        outcome = PlatformOriginKeyingOutcome.REJECTED,
                        diagnostic = null
                    )
                )
            )
            return
        }
        originSalt = salt.copyOf()
        callback(
            Result.success(
                PlatformOriginKeyingResult(
                    outcome = PlatformOriginKeyingOutcome.INSTALLED,
                    diagnostic = null
                )
            )
        )
    }

    /** Drops the salt. Called when the engine detaches. */
    fun forgetOriginKeying() {
        originSalt?.fill(0)
        originSalt = null
    }

    override fun availability(
        callback: (Result<PlatformAvailabilityResult>) -> Unit
    ) {
        // Real: HealthConnectClient.getSdkStatus(context) == SDK_AVAILABLE
        callback(
            Result.success(
                PlatformAvailabilityResult(
                    available = false,
                    reason = PlatformUnavailableReason.SERVICE_MISSING,
                    diagnostic = "health connect adapter is a shell"
                )
            )
        )
    }

    override fun requestAuthorization(
        callback: (Result<PlatformAuthorizationResult>) -> Unit
    ) {
        // Real: request read-only StepsRecord permission.
        callback(
            Result.success(
                PlatformAuthorizationResult(
                    state = PlatformAuthorizationState.UNAVAILABLE,
                    diagnostic = null
                )
            )
        )
    }

    override fun fetchSteps(
        request: PlatformSyncRequest,
        callback: (Result<PlatformSyncPage>) -> Unit
    ) {
        // Fail-closed, and checked before anything is read. Observations keyed
        // under no salt would re-key every origin and grant the retention
        // window a second time -- and nothing would detect it.
        if (originSalt == null) {
            callback(
                Result.success(
                    unavailablePage(PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED)
                )
            )
            return
        }
        callback(
            Result.success(unavailablePage(PlatformUnavailableReason.SERVICE_MISSING))
        )
    }

    companion object {
        /**
         * The keying scheme this adapter implements.
         *
         * Must match `originKeyingAlgorithmVersion` in
         * `lib/src/origin_pseudonymizer.dart`. A mismatch is refused rather
         * than absorbed.
         */
        const val ORIGIN_KEYING_ALGORITHM_VERSION = 1L

        /**
         * The answer when the service cannot be reached.
         *
         * No cursor, no rescan, and `PARTIAL` completeness. Every one of those
         * is load-bearing: a cursor here would claim progress the ledger never
         * recorded, and any completeness assertion would settle buckets on the
         * strength of a read that never happened.
         */
        fun unavailablePage(reason: PlatformUnavailableReason): PlatformSyncPage =
            PlatformSyncPage(
                status = PlatformSyncStatus.UNAVAILABLE,
                observations = emptyList(),
                completeness = PlatformCompleteness(
                    kind = PlatformCompletenessKind.PARTIAL,
                    dataType = PlatformHealthDataType.STEPS,
                    scope = PlatformOriginScope(
                        kind = PlatformOriginScopeKind.SOME_ORIGINS,
                        originKeys = emptyList()
                    ),
                    intervalStartMillis = 0L,
                    intervalEndMillis = 0L,
                    queryGeneration = 0L,
                    throughMillis = 0L
                ),
                pagination = PlatformPagination(
                    pageIndex = 0L,
                    isFinalPage = true,
                    continuation = null
                ),
                nextCursor = null,
                rescan = null,
                unavailableReason = reason,
                diagnostic = null
            )
    }
}
