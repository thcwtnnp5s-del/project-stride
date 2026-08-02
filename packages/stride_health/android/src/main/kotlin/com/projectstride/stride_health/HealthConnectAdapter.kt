package com.projectstride.stride_health

import android.content.Context

/**
 * Health Connect step reader.
 *
 * ## M-2 scope
 *
 * A compiling shell that satisfies the Pigeon contract and reports the platform
 * as unavailable. The real implementation is task **S-01**.
 *
 * Reporting `unavailable` is deliberate rather than throwing: it exercises the
 * same graceful-degradation path the game must handle when Health Connect is
 * genuinely absent, so the app is fully playable against this shell.
 *
 * ## What S-01 implements
 *
 * Health Connect's **Changes API** — `getChangesToken()` then
 * `getChanges(token)` — is the direct analogue of HealthKit's anchored query,
 * returning upserts and deletions since a token.
 *
 * * Read-only `StepsRecord` permission. No write scope, ever.
 * * `Metadata.recordingMethod` supplies the manual-entry filter.
 * * Health Connect is built into Android 14+; earlier versions require the
 *   Health Connect app. Absence must degrade gracefully — the same path as a
 *   denied permission.
 * * Deep-history permissions are not requested. The ledger never needs old
 *   data, only what is new since the last token.
 *
 * ## Token invalidation — the recovery contract
 *
 * Health Connect can expire or invalidate a changes token. HealthKit has no
 * equivalent, which makes this the one genuinely Android-specific failure mode
 * in the project. When it happens the adapter must NOT report the whole history
 * as new, and must NOT signal that the ledger should reset.
 *
 * Instead it returns `PlatformCursorStatus.INVALIDATED` with a `PlatformRescan`
 * carrying the **authoritative total** for the bounded window
 * `[watermarkMillis, now]`, clamped to the adapter's maximum window and flagged
 * `truncated` when clamping occurred.
 *
 * Reconciliation in `stride_core` then grants
 * `max(0, windowTotal - grantedSinceWatermark)` — the subtraction removes the
 * overlap so re-read data cannot be re-granted, and the `max` is the
 * no-clawback rule.
 *
 * No replacement token is persisted until recovery has been committed to the
 * ledger, which is what makes an interrupted recovery safe to retry.
 *
 * See `StepRescan` in stride_core and reconciliation scenario 13 in F-04.
 */
class HealthConnectAdapter(
    @Suppress("unused") private val context: Context
) : HealthHostApi {

    override fun isAvailable(): Boolean {
        // S-01: HealthConnectClient.getSdkStatus(context) == SDK_AVAILABLE
        return false
    }

    override fun requestAuthorization(
        callback: (Result<PlatformAuthorization>) -> Unit
    ) {
        // S-01: request read-only StepsRecord permission.
        callback(Result.success(PlatformAuthorization.UNAVAILABLE))
    }

    override fun fetchNewSteps(
        cursor: ByteArray?,
        watermarkMillis: Long?,
        callback: (Result<PlatformFetchResult>) -> Unit
    ) {
        // S-01: Changes API, deletion handling, manual-entry filter, and the
        // bounded rescan described above.
        callback(
            Result.success(
                PlatformFetchResult(
                    status = PlatformCursorStatus.VALID,
                    newSteps = 0L,
                    deletedSteps = 0L,
                    cursor = null,
                    rescan = null
                )
            )
        )
    }
}
