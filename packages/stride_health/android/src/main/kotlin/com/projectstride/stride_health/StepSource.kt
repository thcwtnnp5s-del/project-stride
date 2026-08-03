package com.projectstride.stride_health

/**
 * The narrow platform surface [HealthConnectAdapter] is written against.
 *
 * ## Why this interface exists
 *
 * Everything the boundary contract is strict about -- absolute per-origin
 * bucket totals, partial versus complete delivery, corrections, deletions,
 * token expiry, bounded recovery, pagination -- is *decision* logic, and none of
 * it needs Health Connect to be present in order to be wrong. Putting the
 * platform calls behind this interface makes all of it assertable on a plain
 * JVM, which is the difference between a suite that runs on every push and one
 * that runs when somebody has a phone.
 *
 * [HealthConnectStepSource] is the only production implementation.
 *
 * ## Foreground only
 *
 * There is no subscribe, register, or observe method here, and there must not
 * be one while S-01A is open. Background delivery is S-01B and is blocked on a
 * real persistence coordinator (DECISIONS/0013, DECISIONS/0014).
 */
internal interface StepSource {

    /** Whether the platform's health service is present and usable. */
    fun availability(): SourceAvailability

    /** Whether read access to steps has already been granted. */
    suspend fun hasStepReadPermission(): Boolean

    /**
     * Asks the user for read-only step access, in the foreground.
     *
     * Returns the state afterwards. Never throws for a denial: refusal is an
     * ordinary answer the game stays fully playable through.
     */
    suspend fun requestStepReadPermission(): PlatformAuthorizationState

    /**
     * Registers for change notifications from now on, and returns the token.
     *
     * Acquired BEFORE the authoritative read that accompanies it, so that a
     * record written during the read is reported by the next sync rather than
     * falling into the gap between the two.
     */
    suspend fun acquireChangesToken(): String

    /**
     * Drains every page of the change stream that follows [token].
     *
     * Returns [ChangeStream.Expired] when the platform rejects the token, which
     * is the one genuinely Android-specific failure mode in this project.
     */
    suspend fun drainChanges(token: String): ChangeStream

    /**
     * Every step record overlapping `[startMillis, endMillis)`, authoritatively.
     *
     * "Authoritatively" is the whole point: this is what turns a change
     * notification into an absolute per-slice total, and what makes a deletion
     * expressible as a bucket that now reads zero.
     */
    suspend fun readRecords(startMillis: Long, endMillis: Long): List<RawStepRecord>

    /**
     * The FULL set of sources the platform knows contributed to
     * `[startMillis, endMillis)`, or null when the platform would not say.
     *
     * Null is not a failure -- it is the difference between `ALL_ORIGINS` and
     * `SOME_ORIGINS`, and answering `ALL_ORIGINS` without having actually asked
     * is how a completeness assertion settles a source it never read.
     */
    suspend fun enumerateOrigins(startMillis: Long, endMillis: Long): Set<String>?

    /** UTC milliseconds. The adapter owns the clock; the core never reads one. */
    fun nowMillis(): Long
}

/** Whether the platform can answer at all, and why not when it cannot. */
internal enum class SourceAvailability {
    AVAILABLE,

    /** Health Connect is not installed, or the OS is too old for it. */
    SERVICE_MISSING,

    /** Installed, but the provider needs an update before it will answer. */
    PROVIDER_UPDATE_REQUIRED,
}

/**
 * One step record, as the adapter sees it.
 *
 * [originIdentifier] is `metadata.dataOrigin.packageName`. It exists between
 * this type and [OriginKeying.keyBytes] and nowhere else: it is never put on the
 * Pigeon wire, never logged, and never retained past the call that keyed it.
 * There is deliberately no device label, no record identifier, and no
 * sub-record detail on this type -- the boundary has no field for any of them,
 * and a shadow copy of health data is what GAME_BIBLE/HEALTH_INTEGRATION
 * forbids.
 */
internal data class RawStepRecord(
    val originIdentifier: String,
    val startMillis: Long,
    val endMillis: Long,
    val count: Long,
    val manuallyEntered: Boolean,
)

/** What the change stream said. */
internal sealed interface ChangeStream {

    /**
     * The stream was drained.
     *
     * @param upserts records written or edited since the token. A correction
     *   arrives here as an ordinary upsert, which is why corrections need no
     *   separate path.
     * @param sawDeletion true when the platform reported at least one deletion.
     *   Health Connect gives a deletion as a bare record id with no time and no
     *   origin, so this flag is all the localization available -- see
     *   [HealthConnectAdapter] for what the adapter does about it.
     * @param nextToken the candidate cursor. Returned to the caller and
     *   forgotten; never written to any durable native store.
     */
    data class Drained(
        val upserts: List<RawStepRecord>,
        val sawDeletion: Boolean,
        val nextToken: String,
    ) : ChangeStream

    /**
     * The token expired or was rejected.
     *
     * Not an error and not a reset. The adapter answers with a bounded
     * authoritative re-read; the core reconciles those absolutes against what
     * it already granted.
     */
    data object Expired : ChangeStream
}
