package com.projectstride.stride_health

/**
 * A Health Connect stand-in with no Health Connect in it.
 *
 * Every rule the boundary contract is strict about is a decision the adapter
 * makes, and none of those decisions needs a device in order to be wrong. This
 * is what lets the interesting cases -- corrections, deletions, several
 * origins, token expiry, truncation, pagination, resumption -- be asserted on
 * every push rather than when somebody has a phone in their hand.
 *
 * It deliberately behaves like the real thing in the two ways that matter:
 * [readRecords] answers only for the interval it was asked about, and
 * [enumerateOrigins] can decline, because "the platform would not give me its
 * source list" is the difference between ALL_ORIGINS and SOME_ORIGINS.
 */
internal class FakeStepSource(
    var platformAvailability: SourceAvailability = SourceAvailability.AVAILABLE,
    var permissionGranted: Boolean = true,
    var now: Long = 0L,
) : StepSource {

    /** The authoritative contents of the platform, as records. */
    val records: MutableList<RawStepRecord> = mutableListOf()

    /** What the change stream will say next. */
    var changes: ChangeStream = ChangeStream.Drained(emptyList(), false, NEXT_TOKEN)

    /** Null means the platform declined to enumerate. */
    var originEnumeration: Set<String>? = null

    var permissionRequestOutcome: PlatformAuthorizationState = PlatformAuthorizationState.GRANTED

    var tokensAcquired: Int = 0
    var permissionRequests: Int = 0
    var readCalls: Int = 0
    var drainedTokens: MutableList<String> = mutableListOf()

    /** Records the order of calls, so "token before read" can be asserted. */
    val callOrder: MutableList<String> = mutableListOf()

    override fun availability(): SourceAvailability = platformAvailability

    override suspend fun hasStepReadPermission(): Boolean = permissionGranted

    override suspend fun requestStepReadPermission(): PlatformAuthorizationState {
        permissionRequests += 1
        return permissionRequestOutcome
    }

    override suspend fun acquireChangesToken(): String {
        tokensAcquired += 1
        callOrder.add("token")
        return "$NEXT_TOKEN-$tokensAcquired"
    }

    override suspend fun drainChanges(token: String): ChangeStream {
        drainedTokens.add(token)
        callOrder.add("drain")
        return changes
    }

    override suspend fun readRecords(startMillis: Long, endMillis: Long): List<RawStepRecord> {
        readCalls += 1
        callOrder.add("read:$startMillis-$endMillis")
        return records.filter { it.startMillis < endMillis && startMillis < maxOf(it.endMillis, it.startMillis + 1) }
    }

    override suspend fun enumerateOrigins(startMillis: Long, endMillis: Long): Set<String>? =
        originEnumeration

    override fun nowMillis(): Long = now

    companion object {
        const val NEXT_TOKEN = "changes-token"
    }
}

/** A step record, with the boilerplate that is never the point of a test. */
internal fun stepRecord(
    origin: String,
    startMillis: Long,
    endMillis: Long,
    count: Long,
    manuallyEntered: Boolean = false,
): RawStepRecord = RawStepRecord(
    originIdentifier = origin,
    startMillis = startMillis,
    endMillis = endMillis,
    count = count,
    manuallyEntered = manuallyEntered,
)
