package com.projectstride.stride_health

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregationResult
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ChangesResponse
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant

/**
 * The only production [StepSource]: real Health Connect, foreground only.
 *
 * Everything here is a thin translation of a platform call. No decision about
 * completeness, pagination, absoluteness, or recovery is made in this file --
 * those live in [HealthConnectAdapter], where they can be asserted without a
 * device. What this file owns is the part a JVM test genuinely cannot cover,
 * and keeping it thin is what keeps that untestable surface small.
 *
 * ## Read-only, steps only
 *
 * [STEP_READ_PERMISSION] is the only permission this plugin ever names. There
 * is no write permission, no history permission, and no second record type.
 * Deep-history access is deliberately not requested: the ledger never needs old
 * data, only what is new since the last cursor.
 *
 * ## Foreground only
 *
 * There is no `PassiveMonitoringClient`, no worker, no service, and no
 * registration of any kind. S-01A is foreground synchronization; background
 * delivery is S-01B and is blocked on a real persistence coordinator.
 */
internal class HealthConnectStepSource(
    private val context: Context,
    private val permissionRequester: PermissionRequester,
) : StepSource {

    private val client: HealthConnectClient by lazy { HealthConnectClient.getOrCreate(context) }

    override fun availability(): SourceAvailability {
        // Health Connect requires Android 8.0. Below that the client class is
        // not usable at all, so the check happens before it is touched --
        // absence is a normal state the game stays fully playable through, not
        // an exception to catch.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return SourceAvailability.SERVICE_MISSING

        return when (HealthConnectClient.getSdkStatus(context)) {
            HealthConnectClient.SDK_AVAILABLE -> SourceAvailability.AVAILABLE
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                SourceAvailability.PROVIDER_UPDATE_REQUIRED
            else -> SourceAvailability.SERVICE_MISSING
        }
    }

    override suspend fun hasStepReadPermission(): Boolean =
        client.permissionController.getGrantedPermissions().contains(STEP_READ_PERMISSION)

    override suspend fun requestStepReadPermission(): PlatformAuthorizationState {
        // The sheet needs a foreground activity. Without one there is nothing
        // to report except that the question could not be asked -- which is
        // not a denial, and is not recorded as one.
        val granted = permissionRequester.request(setOf(STEP_READ_PERMISSION))
            ?: return PlatformAuthorizationState.UNAVAILABLE

        return if (granted.contains(STEP_READ_PERMISSION)) {
            PlatformAuthorizationState.GRANTED
        } else {
            PlatformAuthorizationState.DENIED
        }
    }

    override suspend fun acquireChangesToken(): String =
        client.getChangesToken(ChangesTokenRequest(recordTypes = setOf(StepsRecord::class)))

    override suspend fun drainChanges(token: String): ChangeStream {
        var current = token
        val upserts = ArrayList<RawStepRecord>()
        var sawDeletion = false

        for (page in 0 until MAX_CHANGE_PAGES) {
            val response: ChangesResponse = try {
                client.getChanges(current)
            } catch (_: IllegalArgumentException) {
                // A token the provider will no longer accept. Indistinguishable
                // from expiry from here, and treated identically: a bounded
                // authoritative re-read, never a reset and never a windfall.
                return ChangeStream.Expired
            }
            if (response.changesTokenExpired) return ChangeStream.Expired

            for (change in response.changes) {
                when (change) {
                    is UpsertionChange -> {
                        val record = change.record
                        if (record is StepsRecord) upserts.add(record.toRaw())
                    }
                    // A bare record id: no time, no origin, no count. All the
                    // localization the API offers is "at least one". See
                    // HealthConnectAdapter for what is done about it.
                    is DeletionChange -> sawDeletion = true
                    else -> Unit
                }
            }

            current = response.nextChangesToken
            if (!response.hasMore) return ChangeStream.Drained(upserts, sawDeletion, current)
        }

        // The stream did not drain inside the bound. Reported as expiry rather
        // than as a partial delta, because a partial delta would be forwarded
        // as if it were the whole change set -- and the recovery path is the
        // one that is authoritative regardless of what the stream said.
        return ChangeStream.Expired
    }

    override suspend fun readRecords(
        startMillis: Long,
        endMillis: Long,
    ): List<RawStepRecord> {
        if (endMillis <= startMillis) return emptyList()

        val filter = TimeRangeFilter.between(
            Instant.ofEpochMilli(startMillis),
            Instant.ofEpochMilli(endMillis),
        )
        val out = ArrayList<RawStepRecord>()
        var pageToken: String? = null
        for (page in 0 until MAX_RECORD_PAGES) {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = filter,
                    pageToken = pageToken,
                )
            )
            response.records.forEach { out.add(it.toRaw()) }
            pageToken = response.pageToken
            if (pageToken == null) return out
        }
        // Draining ran out of pages. Refusing is the only honest answer: a
        // truncated read presented as authoritative would state a bucket total
        // that is missing records, and an absolute understatement is exactly
        // the shape of a lost grant.
        throw IllegalStateException("step record pagination exceeded its bound")
    }

    override suspend fun enumerateOrigins(
        startMillis: Long,
        endMillis: Long,
    ): Set<String>? {
        if (endMillis <= startMillis) return null
        return try {
            val result: AggregationResult = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startMillis),
                        Instant.ofEpochMilli(endMillis),
                    ),
                )
            )
            // The platform's own list of every source that contributed to this
            // interval -- an enumeration, not an inference from the batch. That
            // is what makes ALL_ORIGINS legitimate here and illegitimate
            // without it.
            result.dataOrigins.map { it.packageName }.toSet()
        } catch (_: Throwable) {
            // Not a failure. Null narrows the completeness scope to the sources
            // the adapter can actually vouch for, which under-settles rather
            // than over-settles.
            null
        }
    }

    override fun nowMillis(): Long = System.currentTimeMillis()

    /**
     * The raw platform identifier enters the process here and leaves it in
     * [OriginKeying.keyBytes].
     *
     * `metadata.dataOrigin.packageName`, and nothing else. Never a device label
     * -- a player may have called their phone anything at all, and a display
     * name hashed into an origin key is worse than useless because it looks
     * correct. `Scripts/check-origin-privacy.sh` rejects the display-name APIs
     * in this file.
     */
    private fun StepsRecord.toRaw(): RawStepRecord = RawStepRecord(
        originIdentifier = metadata.dataOrigin.packageName,
        startMillis = startTime.toEpochMilli(),
        endMillis = endTime.toEpochMilli(),
        count = count,
        manuallyEntered = metadata.recordingMethod == Metadata.RECORDING_METHOD_MANUAL_ENTRY,
    )

    companion object {
        /** Read-only. There is no write scope in this plugin. */
        val STEP_READ_PERMISSION: String = HealthPermission.getReadPermission(StepsRecord::class)

        /**
         * Bounds on platform pagination.
         *
         * Not tuning. An unbounded loop against a provider that keeps saying
         * `hasMore` would hang a foreground sync with no way out; a bound turns
         * that into a typed answer the core can act on.
         */
        private const val MAX_CHANGE_PAGES = 256
        private const val MAX_RECORD_PAGES = 1024
    }
}

/**
 * Asks the user for Health Connect permissions, in the foreground.
 *
 * Separate from [StepSource] because it needs an Activity and the rest of the
 * source does not, and because "there is no activity attached" has to be
 * answerable without pretending the user said no.
 */
internal interface PermissionRequester {
    /**
     * Launches the permission sheet and returns the granted set, or null when
     * there is no foreground activity to launch it from.
     *
     * Null is not a denial. The game never treats a question it could not ask
     * as an answer.
     */
    suspend fun request(permissions: Set<String>): Set<String>?
}
