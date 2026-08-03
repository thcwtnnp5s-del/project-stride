package com.projectstride.stride_health

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.Dispatchers

/**
 * JVM unit tests for the Health Connect adapter.
 *
 * Every one of these asserts a property the reconciliation ledger depends on.
 * The platform is behind [StepSource], so a case that would need a phone, a
 * week of walking, and an expired token is here as three lines of setup -- and
 * runs on every push instead of when somebody has a device.
 *
 * **What this suite does NOT prove**: that [HealthConnectStepSource] translates
 * Health Connect correctly. Real permissions, real records, a real changes
 * token and a real expiry need a device, and that evidence category is
 * deliberately kept separate (DECISIONS/0014).
 */
internal class HealthConnectAdapterTest {

    private val hour = 60L * 60L * 1000L
    private val day = 24L * hour

    /** 2023-11-14T22:13:20Z. Deliberately not on a bucket boundary. */
    private val now = 1_700_000_000_000L
    private val currentBucket = StepBucketing.bucketStart(now, hour)

    private val phone = "com.projectstride.app"
    private val watch = "com.google.android.apps.fitness"

    private fun source(): FakeStepSource = FakeStepSource(now = now)

    private fun adapter(source: StepSource): HealthConnectAdapter =
        // Unconfined, so a `launch` runs inline and the Pigeon callback has
        // fired by the time the call returns. Nothing here needs a scheduler.
        HealthConnectAdapter(source, Dispatchers.Unconfined)

    private fun keyed(source: StepSource): HealthConnectAdapter {
        val created = adapter(source)
        var outcome: PlatformOriginKeyingOutcome? = null
        created.installOriginKeying(
            byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8),
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION,
        ) { r -> outcome = r.getOrThrow().outcome }
        assertEquals(PlatformOriginKeyingOutcome.INSTALLED, outcome)
        return created
    }

    private fun request(
        cursor: String? = null,
        continuation: ByteArray? = null,
        maxRescanWindowMillis: Long = 30L * day,
        rescanFloorMillis: Long? = null,
        includeManualEntries: Boolean = false,
        bucketWidthMillis: Long = hour,
    ): PlatformSyncRequest = PlatformSyncRequest(
        dataType = PlatformHealthDataType.STEPS,
        bucketWidthMillis = bucketWidthMillis,
        maxRescanWindowMillis = maxRescanWindowMillis,
        includeManualEntries = includeManualEntries,
        cursor = cursor?.toByteArray(Charsets.UTF_8),
        continuation = continuation,
        rescanFloorMillis = rescanFloorMillis,
    )

    private fun HealthConnectAdapter.fetch(request: PlatformSyncRequest): PlatformSyncPage {
        var page: PlatformSyncPage? = null
        fetchSteps(request) { r -> page = r.getOrThrow() }
        return requireNotNull(page) { "fetchSteps did not answer" }
    }

    /** Every page of a read, drained the way the caller is expected to. */
    private fun HealthConnectAdapter.drain(
        first: PlatformSyncRequest,
        limit: Int = 32,
    ): List<PlatformSyncPage> {
        val pages = mutableListOf<PlatformSyncPage>()
        var page = fetch(first)
        pages.add(page)
        var guard = 0
        while (!page.pagination.isFinalPage && guard++ < limit) {
            val continuation = requireNotNull(page.pagination.continuation) {
                "a non-final page must offer a continuation"
            }
            page = fetch(request(continuation = continuation))
            pages.add(page)
        }
        return pages
    }

    private fun PlatformSyncPage.stepsFor(key: ByteArray, bucketStart: Long): Long? =
        observations.firstOrNull {
            it.originKey.contentEquals(key) && it.bucket.startMillis == bucketStart
        }?.steps

    private fun key(identifier: String): ByteArray =
        OriginKeying(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8)).keyBytes(identifier)

    // =======================================================================
    // Fail-closed, and the keying handshake
    // =======================================================================

    @Test
    fun `reading without the device identity is refused, not attempted`() {
        // Observations keyed under no salt would re-key every origin, and a
        // re-keyed origin looks exactly like a new device: its recent buckets
        // look ungranted and the whole retention window is granted a second
        // time. Nothing detects that.
        val source = source()
        val page = adapter(source).fetch(request())

        assertEquals(PlatformSyncStatus.UNAVAILABLE, page.status)
        assertEquals(PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED, page.unavailableReason)
        assertTrue(page.observations.isEmpty())
        assertEquals(0, source.readCalls, "nothing may be READ before the identity is installed")
    }

    @Test
    fun `a mismatched algorithm version is refused rather than absorbed`() {
        var outcome: PlatformOriginKeyingOutcome? = null
        adapter(source()).installOriginKeying(byteArrayOf(1, 2, 3), 9999L) { r ->
            outcome = r.getOrThrow().outcome
        }
        assertEquals(PlatformOriginKeyingOutcome.UNSUPPORTED_ALGORITHM, outcome)
    }

    @Test
    fun `an empty salt is refused`() {
        // An empty salt makes every origin key a bare unkeyed digest of a
        // package name, trivially reversible by anyone holding a list of
        // package names -- that is, everyone.
        var outcome: PlatformOriginKeyingOutcome? = null
        adapter(source()).installOriginKeying(
            ByteArray(0),
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION,
        ) { r -> outcome = r.getOrThrow().outcome }
        assertEquals(PlatformOriginKeyingOutcome.REJECTED, outcome)
    }

    @Test
    fun `forgetting the identity returns the adapter to fail-closed`() {
        val created = keyed(source())
        created.forgetOriginKeying()
        assertEquals(
            PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED,
            created.fetch(request()).unavailableReason,
        )
    }

    @Test
    fun `installing the identity says nothing about the salt`() {
        // The diagnostic is never the salt, never a fingerprint of it, and
        // never a source identifier. There is nothing safe to put here.
        var result: PlatformOriginKeyingResult? = null
        adapter(source()).installOriginKeying(
            byteArrayOf(9, 9, 9),
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION,
        ) { r -> result = r.getOrThrow() }
        assertNull(requireNotNull(result).diagnostic)
    }

    // =======================================================================
    // Availability and authorization
    // =======================================================================

    @Test
    fun `an absent health service reports unavailable rather than throwing`() {
        // Android without Health Connect installed is a normal state, not an
        // error. The game stays fully playable through it (DECISIONS/0008).
        val source = source()
        source.platformAvailability = SourceAvailability.SERVICE_MISSING

        var result: PlatformAvailabilityResult? = null
        adapter(source).availability { r -> result = r.getOrThrow() }

        val availability = requireNotNull(result)
        assertFalse(availability.available)
        assertEquals(PlatformUnavailableReason.SERVICE_MISSING, availability.reason)
    }

    @Test
    fun `a provider that needs updating is unavailable, not an error`() {
        val source = source()
        source.platformAvailability = SourceAvailability.PROVIDER_UPDATE_REQUIRED

        var result: PlatformAvailabilityResult? = null
        adapter(source).availability { r -> result = r.getOrThrow() }

        assertFalse(requireNotNull(result).available)
        assertEquals(PlatformUnavailableReason.SERVICE_MISSING, result!!.reason)
    }

    @Test
    fun `an available service reports available with no reason`() {
        var result: PlatformAvailabilityResult? = null
        adapter(source()).availability { r -> result = r.getOrThrow() }

        assertTrue(requireNotNull(result).available)
        assertNull(result!!.reason)
    }

    @Test
    fun `an already-granted permission is not asked for again`() {
        val source = source()
        source.permissionGranted = true

        var result: PlatformAuthorizationResult? = null
        adapter(source).requestAuthorization { r -> result = r.getOrThrow() }

        assertEquals(PlatformAuthorizationState.GRANTED, requireNotNull(result).state)
        assertEquals(0, source.permissionRequests)
    }

    @Test
    fun `a denied permission is a state, never an exception`() {
        val source = source()
        source.permissionGranted = false
        source.permissionRequestOutcome = PlatformAuthorizationState.DENIED

        var result: PlatformAuthorizationResult? = null
        adapter(source).requestAuthorization { r -> result = r.getOrThrow() }

        assertEquals(PlatformAuthorizationState.DENIED, requireNotNull(result).state)
        assertEquals(1, source.permissionRequests)
    }

    @Test
    fun `authorization is not requested when the service is absent`() {
        val source = source()
        source.platformAvailability = SourceAvailability.SERVICE_MISSING

        var result: PlatformAuthorizationResult? = null
        adapter(source).requestAuthorization { r -> result = r.getOrThrow() }

        assertEquals(PlatformAuthorizationState.UNAVAILABLE, requireNotNull(result).state)
        assertEquals(0, source.permissionRequests)
    }

    @Test
    fun `a read without permission reports the permission rather than an empty page`() {
        // Health Connect answers an unauthorized read with an empty result,
        // which is indistinguishable from a player who did not move. Reporting
        // the permission is what stops an empty page being mistaken for a
        // settled one.
        val source = source()
        source.permissionGranted = false

        val page = keyed(source).fetch(request())

        assertEquals(PlatformSyncStatus.UNAVAILABLE, page.status)
        assertEquals(PlatformUnavailableReason.PERMISSION_UNAVAILABLE, page.unavailableReason)
        assertEquals(0, source.readCalls)
    }

    @Test
    fun `a read against an absent service is unavailable, with no cursor`() {
        val source = source()
        source.platformAvailability = SourceAvailability.SERVICE_MISSING

        val page = keyed(source).fetch(request())

        assertEquals(PlatformUnavailableReason.SERVICE_MISSING, page.unavailableReason)
        assertNull(page.nextCursor, "a cursor here would claim progress the ledger never recorded")
        assertEquals(PlatformCompletenessKind.PARTIAL, page.completeness.kind)
        assertNull(page.rescan)
    }

    @Test
    fun `a platform failure is transient and offers nothing`() {
        // On a genuine error the adapter leaves its own state untouched and
        // reports a retryable failure. No cursor, so the next attempt resumes
        // from exactly the same position.
        val source = object : StepSource by source() {
            override suspend fun hasStepReadPermission(): Boolean = true
            override suspend fun acquireChangesToken(): String = throw IllegalStateException("boom")
        }
        val page = keyed(source).fetch(request())

        assertEquals(PlatformSyncStatus.UNAVAILABLE, page.status)
        assertEquals(PlatformUnavailableReason.TRANSIENT_FAILURE, page.unavailableReason)
        assertNull(page.nextCursor)
    }

    // =======================================================================
    // The initial read
    // =======================================================================

    @Test
    fun `the changes token is acquired before the authoritative read`() {
        // A record written during the read then falls into the NEXT sync's
        // change stream rather than into the gap between the two. The worst
        // case is a slice restated with the same absolute figure, which costs
        // nothing because every figure is absolute.
        val source = source()
        keyed(source).fetch(request())

        val token = source.callOrder.indexOf("token")
        val read = source.callOrder.indexOfFirst { it.startsWith("read:") }
        assertTrue(token in 0 until read, "the token must be registered before the window is read")
    }

    @Test
    fun `an initial read states an absolute total per origin per bucket`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 3 * hour, currentBucket - 2 * hour, 400)
        source.records += stepRecord(watch, currentBucket - 3 * hour, currentBucket - 2 * hour, 90)

        val pages = keyed(source).drain(request())
        val all = pages.flatMap { it.observations }

        val phoneKey = key(phone)
        val watchKey = key(watch)
        assertEquals(
            400L,
            all.first { it.originKey.contentEquals(phoneKey) && it.bucket.startMillis == currentBucket - 3 * hour }.steps,
        )
        assertEquals(
            90L,
            all.first { it.originKey.contentEquals(watchKey) && it.bucket.startMillis == currentBucket - 3 * hour }.steps,
        )
    }

    @Test
    fun `several origins never collapse into one`() {
        // The case that discarded a returning player's backlog: a flat total
        // cannot say WHICH source produced it, so the reconciler cannot tell
        // "the phone is settled" from "the watch has been offline a week".
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 1_000)
        source.records += stepRecord(watch, currentBucket - hour, currentBucket, 1_000)

        val observations = keyed(source).drain(request()).flatMap { it.observations }
        val keysInBucket = observations
            .filter { it.bucket.startMillis == currentBucket - hour }
            .map { OriginKeying.toCoreHex(it.originKey) }
            .toSet()

        assertEquals(2, keysInBucket.size, "two sources, two keys")
        assertTrue(keysInBucket.contains(OriginKeying.toCoreHex(key(phone))))
        assertTrue(keysInBucket.contains(OriginKeying.toCoreHex(key(watch))))
    }

    @Test
    fun `a record spanning buckets is apportioned without inventing or losing a step`() {
        val source = source()
        // Three hours, 301 steps: not divisible, so the rounding is the point.
        source.records += stepRecord(phone, currentBucket - 3 * hour, currentBucket, 301)

        val observations = keyed(source).drain(request()).flatMap { it.observations }
        val phoneKey = key(phone)
        val total = observations
            .filter { it.originKey.contentEquals(phoneKey) }
            .sumOf { it.steps }

        assertEquals(301L, total, "the shares must sum to exactly the record's count")
    }

    @Test
    fun `manual entries are excluded unless the player asked for them`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 500, manuallyEntered = true)

        val phoneKey = key(phone)
        val excluded = keyed(source).drain(request(includeManualEntries = false))
            .flatMap { it.observations }
            .filter { it.originKey.contentEquals(phoneKey) }
            .sumOf { it.steps }
        assertEquals(0L, excluded)

        val included = keyed(source).drain(request(includeManualEntries = true))
            .flatMap { it.observations }
            .filter { it.originKey.contentEquals(phoneKey) }
            .sumOf { it.steps }
        assertEquals(500L, included)
    }

    @Test
    fun `a bucket width narrower than the minimum is clamped up, never honoured`() {
        // The privacy ruling bounds retention LENGTH and says nothing about
        // resolution. One-minute buckets would satisfy it exactly as written
        // and build a minute-by-minute record of when the player moved.
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 10)

        val page = keyed(source).fetch(request(bucketWidthMillis = 60_000L))

        for (observation in page.observations) {
            assertTrue(
                observation.bucket.endMillis - observation.bucket.startMillis >=
                    HealthConnectAdapter.MINIMUM_BUCKET_WIDTH_MILLIS,
                "a bucket narrower than an hour must never leave the adapter",
            )
        }
    }

    // =======================================================================
    // Completeness
    // =======================================================================

    @Test
    fun `the current bucket is delivered but never settled`() {
        // The read runs to the end of the bucket the clock is inside so recent
        // steps arrive promptly. The assertion stops at the boundary before it,
        // because settling a bucket that is still accumulating buries whatever
        // lands in it next.
        val source = source()
        source.records += stepRecord(phone, currentBucket, now, 250)

        val pages = keyed(source).drain(request())
        val last = pages.last()

        assertEquals(currentBucket, last.completeness.throughMillis)
        val phoneKey = key(phone)
        assertEquals(
            250L,
            pages.flatMap { it.observations }
                .first { it.originKey.contentEquals(phoneKey) && it.bucket.startMillis == currentBucket }
                .steps,
            "the current bucket's steps are DELIVERED",
        )
        assertTrue(
            last.completeness.throughMillis < currentBucket + hour,
            "and the current bucket is NOT vouched for",
        )
    }

    @Test
    fun `allOrigins is claimed only when the platform was actually asked`() {
        val declining = source()
        declining.records += stepRecord(phone, currentBucket - hour, currentBucket, 5)
        declining.originEnumeration = null

        val narrow = keyed(declining).drain(request()).last().completeness.scope
        assertEquals(PlatformOriginScopeKind.SOME_ORIGINS, narrow.kind)
        assertTrue(narrow.originKeys.isNotEmpty(), "a narrow scope must name what it vouches for")

        val enumerating = source()
        enumerating.records += stepRecord(phone, currentBucket - hour, currentBucket, 5)
        enumerating.originEnumeration = setOf(phone, watch)

        val wide = keyed(enumerating).drain(request()).last().completeness.scope
        assertEquals(PlatformOriginScopeKind.ALL_ORIGINS, wide.kind)
        assertTrue(
            wide.originKeys.isEmpty(),
            "a scope that claims to speak for every source must name none -- the bridge " +
                "reads naming some as contradictory",
        )
    }

    @Test
    fun `an enumerated source with no records is still stated, as zero`() {
        // Silence is not a zero. A source that stopped contributing has to SAY
        // zero, or the core has no figure to reconcile the emptied slice
        // against.
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 5)
        source.originEnumeration = setOf(phone, watch)

        val observations = keyed(source).drain(request()).flatMap { it.observations }
        val watchKey = key(watch)

        assertEquals(
            0L,
            observations.first {
                it.originKey.contentEquals(watchKey) && it.bucket.startMillis == currentBucket - hour
            }.steps,
        )
    }

    @Test
    fun `every page but the last is partial`() {
        // The 55,200-step defect, in contract form. A completeness assertion on
        // page one of nine is indistinguishable, from inside the core, from one
        // on page nine.
        val source = source()
        source.records += stepRecord(phone, currentBucket - 25 * day, currentBucket, 100_000)

        val pages = keyed(source).drain(request(), limit = 64)
        assertTrue(pages.size > 1, "this window must actually paginate")

        for (page in pages.dropLast(1)) {
            assertEquals(PlatformCompletenessKind.PARTIAL, page.completeness.kind)
            assertFalse(page.pagination.isFinalPage)
            assertNotNull(page.pagination.continuation)
            assertNull(page.nextCursor, "a cursor mid-read would record a position for unseen pages")
        }

        val last = pages.last()
        assertTrue(last.pagination.isFinalPage)
        assertNull(last.pagination.continuation)
        assertEquals(PlatformCompletenessKind.COMPLETE_THROUGH, last.completeness.kind)
        assertNotNull(last.nextCursor)
    }

    @Test
    fun `page indices are sequential and slices are never repeated or skipped`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 25 * day, currentBucket, 100_000)

        val pages = keyed(source).drain(request(), limit = 64)
        pages.forEachIndexed { index, page ->
            assertEquals(index.toLong(), page.pagination.pageIndex)
        }

        val slices = pages.flatMap { page ->
            page.observations.map { OriginKeying.toCoreHex(it.originKey) + "@" + it.bucket.startMillis }
        }
        assertEquals(slices.size, slices.toSet().size, "no slice may be delivered twice")
    }

    @Test
    fun `a resumed page is a pure function of its continuation`() {
        // What makes an interrupted read safe to retry rather than merely
        // unlikely to be interrupted: the adapter mutates nothing, so the same
        // token recomputes the same page.
        val source = source()
        source.records += stepRecord(phone, currentBucket - 25 * day, currentBucket, 100_000)

        val adapter = keyed(source)
        val first = adapter.fetch(request())
        val continuation = requireNotNull(first.pagination.continuation)

        val second = adapter.fetch(request(continuation = continuation))
        val again = adapter.fetch(request(continuation = continuation))

        assertEquals(second.pagination.pageIndex, again.pagination.pageIndex)
        assertEquals(second.observations.size, again.observations.size)
        for (i in second.observations.indices) {
            assertContentEquals(second.observations[i].originKey, again.observations[i].originKey)
            assertEquals(second.observations[i].bucket.startMillis, again.observations[i].bucket.startMillis)
            assertEquals(second.observations[i].steps, again.observations[i].steps)
        }
        assertEquals(second.completeness.queryGeneration, again.completeness.queryGeneration)
    }

    @Test
    fun `a continuation this adapter did not write starts a fresh read`() {
        // A stale token from a previous process is not an error. Starting over
        // is always safe, because every figure is absolute.
        val source = source()
        val page = keyed(source).fetch(request(continuation = byteArrayOf(7, 7, 7, 7, 7)))

        assertEquals(PlatformSyncStatus.INCREMENTAL, page.status)
        assertEquals(0L, page.pagination.pageIndex)
    }

    // =======================================================================
    // Incremental change: corrections, deletions
    // =======================================================================

    @Test
    fun `no change since the cursor settles nothing and offers the fresh token`() {
        val source = source()
        source.changes = ChangeStream.Drained(emptyList(), sawDeletion = false, nextToken = "t2")

        val page = keyed(source).fetch(request(cursor = "t1"))

        assertEquals(PlatformSyncStatus.NO_CHANGE, page.status)
        assertTrue(page.observations.isEmpty())
        assertEquals(
            PlatformCompletenessKind.PARTIAL,
            page.completeness.kind,
            "knowing nothing arrived says nothing about what the window already held",
        )
        assertContentEquals("t2".toByteArray(), page.nextCursor)
        assertEquals(0, source.readCalls, "nothing changed, so nothing is re-read")
    }

    @Test
    fun `a correction arrives as a restated absolute, not a delta`() {
        val source = source()
        val bucket = currentBucket - 5 * hour
        // The platform now holds 250 where it once held 900. The change stream
        // reports the edit; the adapter states what the slice CONTAINS.
        source.records += stepRecord(phone, bucket, bucket + hour, 250)
        source.changes = ChangeStream.Drained(
            upserts = listOf(stepRecord(phone, bucket, bucket + hour, 250)),
            sawDeletion = false,
            nextToken = "t2",
        )

        val page = keyed(source).drain(request(cursor = "t1")).last()

        assertEquals(PlatformSyncStatus.INCREMENTAL, page.status)
        assertEquals(250L, page.stepsFor(key(phone), bucket))
    }

    @Test
    fun `a correction only restates the buckets it touched`() {
        val source = source()
        val touched = currentBucket - 5 * hour
        source.records += stepRecord(phone, touched, touched + hour, 250)
        source.records += stepRecord(phone, currentBucket - 20 * hour, currentBucket - 19 * hour, 900)
        source.changes = ChangeStream.Drained(
            upserts = listOf(stepRecord(phone, touched, touched + hour, 250)),
            sawDeletion = false,
            nextToken = "t2",
        )

        val pages = keyed(source).drain(request(cursor = "t1"))
        val starts = pages.flatMap { it.observations }.map { it.bucket.startMillis }.toSet()

        assertTrue(starts.contains(touched))
        assertFalse(
            starts.contains(currentBucket - 20 * hour),
            "an upsertion carries its own time, so the re-read is bounded by it",
        )
    }

    @Test
    fun `a deletion becomes a bucket that reads zero`() {
        // Health Connect reports a deletion as a bare record id: no time, no
        // origin, no count. The adapter cannot point at the emptied bucket, so
        // it restates the whole bounded window -- and the emptied slice says
        // zero because it genuinely is zero.
        val source = source()
        val emptied = currentBucket - 4 * hour
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 120)
        source.changes = ChangeStream.Drained(
            upserts = emptyList(),
            sawDeletion = true,
            nextToken = "t2",
        )

        val pages = keyed(source).drain(request(cursor = "t1"), limit = 64)
        val observations = pages.flatMap { it.observations }
        val phoneKey = key(phone)

        assertEquals(
            0L,
            observations.first {
                it.originKey.contentEquals(phoneKey) && it.bucket.startMillis == emptied
            }.steps,
            "the emptied slice must SAY zero, not say nothing",
        )
        assertEquals(
            120L,
            observations.first {
                it.originKey.contentEquals(phoneKey) && it.bucket.startMillis == currentBucket - hour
            }.steps,
            "and the surviving slice keeps its absolute total",
        )
    }

    @Test
    fun `a deletion widens the read to the bounded window, and no further`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 2 * hour, currentBucket - hour, 40)
        source.changes = ChangeStream.Drained(emptyList(), sawDeletion = true, nextToken = "t2")

        val pages = keyed(source).drain(
            request(cursor = "t1", maxRescanWindowMillis = 3 * day),
            limit = 64,
        )
        val starts = pages.flatMap { it.observations }.map { it.bucket.startMillis }

        assertTrue(starts.isNotEmpty())
        assertTrue(
            starts.min() >= currentBucket - 3 * day,
            "the widened read is bounded by maxRescanWindowMillis",
        )
        assertEquals(
            PlatformSyncStatus.INCREMENTAL,
            pages.last().status,
            "a deletion is not a cursor invalidation -- the cursor is still good",
        )
    }

    // =======================================================================
    // Token expiry and bounded recovery
    // =======================================================================

    @Test
    fun `an expired token becomes a bounded authoritative rescan`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 2 * hour, currentBucket - hour, 600)
        source.changes = ChangeStream.Expired

        val pages = keyed(source).drain(
            request(cursor = "stale", maxRescanWindowMillis = 7 * day),
            limit = 64,
        )
        val last = pages.last()

        for (page in pages) {
            assertEquals(PlatformSyncStatus.CURSOR_INVALIDATED, page.status)
            val window = requireNotNull(page.rescan) {
                "an invalidated cursor without a window leaves the core no safe move"
            }
            assertTrue(window.endMillis > window.startMillis)
            assertTrue(window.startMillis >= currentBucket - 7 * day)
        }
        assertEquals(
            600L,
            pages.flatMap { it.observations }.first {
                it.originKey.contentEquals(key(phone)) &&
                    it.bucket.startMillis == currentBucket - 2 * hour
            }.steps,
            "the rescan's observations are the AUTHORITATIVE contents of the window",
        )
        assertEquals(PlatformCompletenessKind.RECOVERY_COMPLETE_THROUGH, last.completeness.kind)
    }

    @Test
    fun `a recovery never reports the rescan as new and never resets`() {
        // The two obvious responses to a broken change stream are both wrong:
        // granting everything rescanned double-counts, and resetting erases
        // earned progress. The adapter does neither -- it states absolutes and
        // lets the core do the overlap arithmetic.
        val source = source()
        source.records += stepRecord(phone, currentBucket - 2 * hour, currentBucket - hour, 600)
        source.changes = ChangeStream.Expired

        val pages = keyed(source).drain(request(cursor = "stale", maxRescanWindowMillis = 2 * day), limit = 64)

        // Every figure is a bucket total, never a sum, never a "since" figure,
        // and never a signal to discard anything.
        for (observation in pages.flatMap { it.observations }) {
            assertTrue(observation.steps >= 0)
        }
        assertEquals(
            600L,
            pages.flatMap { it.observations }.sumOf { it.steps },
            "the window's total is what the window contains -- not what changed",
        )
    }

    @Test
    fun `a truncated rescan is reported and settles nothing`() {
        // Steps in the unreachable gap are recorded and never granted: they
        // cannot be distinguished from steps already counted, and inventing
        // progress is worse than missing it.
        val source = source()
        source.changes = ChangeStream.Expired

        val pages = keyed(source).drain(
            request(
                cursor = "stale",
                maxRescanWindowMillis = 2 * day,
                // Older than the clamp allows.
                rescanFloorMillis = now - 60 * day,
            ),
            limit = 64,
        )
        val last = pages.last()

        assertTrue(requireNotNull(last.rescan).truncated, "the clamping must be REPORTED")
        assertTrue(last.rescan!!.startMillis >= currentBucket - 2 * day)
        assertEquals(
            PlatformCompletenessKind.PARTIAL,
            last.completeness.kind,
            "a truncated recovery is not recoveryCompleteThrough for what it could not reach",
        )
    }

    @Test
    fun `an untruncated rescan honours a floor inside the clamp`() {
        val source = source()
        source.changes = ChangeStream.Expired

        val last = keyed(source).drain(
            request(
                cursor = "stale",
                maxRescanWindowMillis = 30 * day,
                rescanFloorMillis = now - 2 * day,
            ),
            limit = 64,
        ).last()

        val window = requireNotNull(last.rescan)
        assertFalse(window.truncated)
        assertEquals(StepBucketing.bucketStart(now - 2 * day, hour), window.startMillis)
    }

    @Test
    fun `a recovery offers its replacement token only once it has been drained`() {
        // Withholding it forever would leave the invalid cursor in place and
        // repeat the recovery on every sync -- a worse failure than the one it
        // would avoid. Offering it mid-read would record a position for pages
        // the caller has not seen.
        val source = source()
        source.records += stepRecord(phone, currentBucket - 25 * day, currentBucket, 100_000)
        source.changes = ChangeStream.Expired

        val pages = keyed(source).drain(request(cursor = "stale"), limit = 64)
        assertTrue(pages.size > 1)
        for (page in pages.dropLast(1)) assertNull(page.nextCursor)
        assertNotNull(pages.last().nextCursor)
    }

    @Test
    fun `recovery recomputes the same answer after an interruption`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 3 * hour, currentBucket, 900)
        source.changes = ChangeStream.Expired

        val first = keyed(source).drain(request(cursor = "stale", maxRescanWindowMillis = day), limit = 64)
        // A second adapter is a fresh process, as far as this matters: the old
        // one persisted nothing, so there is nothing to carry over.
        val second = keyed(source).drain(request(cursor = "stale", maxRescanWindowMillis = day), limit = 64)

        assertEquals(
            first.flatMap { it.observations }.sumOf { it.steps },
            second.flatMap { it.observations }.sumOf { it.steps },
        )
        assertEquals(
            first.flatMap { it.observations }.size,
            second.flatMap { it.observations }.size,
        )
    }

    @Test
    fun `the query generation advances with each new read`() {
        // An assertion made under an anchor that has since been invalidated is
        // stale, and acting on it would settle buckets a rescan is about to
        // restate.
        val source = source()
        val adapter = keyed(source)

        val first = adapter.fetch(request()).completeness.queryGeneration
        val second = adapter.fetch(request()).completeness.queryGeneration

        assertTrue(second > first)
    }

    // =======================================================================
    // Privacy on the wire
    // =======================================================================

    @Test
    fun `every origin key is eight bytes, or empty for an unknown source`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 10)
        source.records += stepRecord("", currentBucket - hour, currentBucket, 3)

        val pages = keyed(source).drain(request())
        for (observation in pages.flatMap { it.observations }) {
            assertTrue(
                observation.originKey.size == 8 || observation.originKey.isEmpty(),
                "eight bytes, or zero for no source reported -- the length check is what " +
                    "stops a truncated raw string reaching the ledger",
            )
        }
        for (page in pages) {
            for (scopeKey in page.completeness.scope.originKeys) {
                assertTrue(scopeKey.size == 8 || scopeKey.isEmpty())
            }
        }
    }

    @Test
    fun `no raw package name or display name crosses the boundary`() {
        // Eight bytes of output is not evidence of hashing. `My Watch` is
        // exactly eight bytes of UTF-8, so a raw identifier on the wire would
        // have the correct WIDTH and every length check would pass it.
        val source = source()
        val displayName = "My Watch"
        source.records += stepRecord(displayName, currentBucket - hour, currentBucket, 42)
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 42)

        val pages = keyed(source).drain(request())
        val forbidden = listOf(displayName, phone).map { it.toByteArray(Charsets.UTF_8) }

        for (page in pages) {
            for (observation in page.observations) {
                for (raw in forbidden) {
                    assertFalse(
                        observation.originKey.contentEquals(raw),
                        "a raw identifier travelled as an origin key",
                    )
                    assertFalse(
                        observation.originKey.contentEquals(raw.copyOf(8)),
                        "a truncated or zero-padded raw identifier travelled as an origin key",
                    )
                }
            }
            for (scopeKey in page.completeness.scope.originKeys) {
                for (raw in forbidden) {
                    assertFalse(scopeKey.contentEquals(raw))
                    assertFalse(scopeKey.contentEquals(raw.copyOf(8)))
                }
            }
        }
    }

    @Test
    fun `no diagnostic ever carries a source identifier`() {
        // Device logs are readable, exportable, and outlive the app. The
        // diagnostic field is the one place on this contract a string could
        // travel, so the adapter puts nothing in it on any path that has seen
        // an origin.
        val source = source()
        source.records += stepRecord("Rob's iPhone", currentBucket - hour, currentBucket, 7)

        for (page in keyed(source).drain(request())) {
            assertNull(page.diagnostic)
        }

        val missing = source()
        missing.platformAvailability = SourceAvailability.SERVICE_MISSING
        var availability: PlatformAvailabilityResult? = null
        adapter(missing).availability { r -> availability = r.getOrThrow() }
        val note = requireNotNull(availability).diagnostic
        assertNotNull(note)
        assertFalse(note.contains("Rob"))
        assertFalse(note.contains("com."))
    }

    // =======================================================================
    // Page shape invariants
    // =======================================================================

    @Test
    fun `only an invalidated cursor carries a rescan window`() {
        // Attaching one to any other status would invite the bridge to treat an
        // absolute window total as ordinary incremental data.
        val source = source()
        source.records += stepRecord(phone, currentBucket - hour, currentBucket, 10)

        for (page in keyed(source).drain(request())) {
            if (page.status != PlatformSyncStatus.CURSOR_INVALIDATED) assertNull(page.rescan)
        }
    }

    @Test
    fun `no observation carries a negative count or an inverted bucket`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 2 * hour, currentBucket, 77)

        for (observation in keyed(source).drain(request()).flatMap { it.observations }) {
            assertTrue(observation.steps >= 0, "steps must never be negative")
            assertTrue(
                observation.bucket.endMillis > observation.bucket.startMillis,
                "a bucket must cover a positive span",
            )
        }
    }

    @Test
    fun `a final page offers no continuation`() {
        val source = source()
        for (page in keyed(source).drain(request())) {
            if (page.pagination.isFinalPage) assertNull(page.pagination.continuation)
        }
    }

    @Test
    fun `a completeness assertion never reaches past the interval it queried`() {
        val source = source()
        source.records += stepRecord(phone, currentBucket - 3 * hour, currentBucket, 30)

        val last = keyed(source).drain(request()).last()
        val completeness = last.completeness

        assertEquals(PlatformHealthDataType.STEPS, completeness.dataType)
        assertTrue(completeness.intervalEndMillis >= completeness.intervalStartMillis)
        assertTrue(completeness.throughMillis <= completeness.intervalEndMillis)
    }
}
