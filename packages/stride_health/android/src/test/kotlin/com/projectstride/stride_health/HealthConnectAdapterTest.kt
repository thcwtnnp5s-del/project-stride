package com.projectstride.stride_health

import android.content.Context
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.mockito.Mockito

/**
 * JVM unit tests for the Health Connect adapter.
 *
 * These assert the *contract* the adapter must honour, which is meaningful even
 * against a shell implementation. Behavioural Health Connect tests — real
 * permissions, real step records, real change tokens — need a physical device.
 *
 * The contract asserted here is not incidental. Every one of these is a
 * property the reconciliation ledger depends on.
 */
internal class HealthConnectAdapterTest {

    private fun adapter(): HealthConnectAdapter =
        HealthConnectAdapter(Mockito.mock(Context::class.java))

    private fun request(): PlatformSyncRequest = PlatformSyncRequest(
        dataType = PlatformHealthDataType.STEPS,
        bucketWidthMillis = 60L * 60L * 1000L,
        maxRescanWindowMillis = 30L * 24L * 60L * 60L * 1000L,
        includeManualEntries = false,
        cursor = null,
        continuation = null,
        rescanFloorMillis = null
    )

    /** An adapter with the device identity installed, as the app would leave it. */
    private fun keyedAdapter(): HealthConnectAdapter {
        val created = adapter()
        var outcome: PlatformOriginKeyingOutcome? = null
        created.installOriginKeying(
            byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8),
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION
        ) { r -> outcome = r.getOrThrow().outcome }
        assertEquals(PlatformOriginKeyingOutcome.INSTALLED, outcome)
        return created
    }

    private fun page(adapter: HealthConnectAdapter = keyedAdapter()): PlatformSyncPage {
        var result: PlatformSyncPage? = null
        adapter.fetchSteps(request()) { r -> result = r.getOrThrow() }
        return requireNotNull(result)
    }

    @Test
    fun `reading without the device identity is refused, not attempted`() {
        // Fail-closed. Observations keyed under no salt would re-key every
        // origin, and a re-keyed origin looks exactly like a new device: its
        // recent buckets look ungranted and the whole retention window is
        // granted a second time. Nothing detects that.
        val fetched = page(adapter())

        assertEquals(PlatformSyncStatus.UNAVAILABLE, fetched.status)
        assertEquals(
            PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED,
            fetched.unavailableReason
        )
        assertTrue(fetched.observations.isEmpty())
    }

    @Test
    fun `a mismatched algorithm version is refused rather than absorbed`() {
        // A silent fallback produces keys nothing else on the device agrees
        // with, which is indistinguishable from a new device.
        var outcome: PlatformOriginKeyingOutcome? = null
        adapter().installOriginKeying(byteArrayOf(1, 2, 3), 9999L) { r ->
            outcome = r.getOrThrow().outcome
        }

        assertEquals(PlatformOriginKeyingOutcome.UNSUPPORTED_ALGORITHM, outcome)
    }

    @Test
    fun `an empty salt is refused`() {
        // An empty salt makes every origin key a bare unkeyed digest of a
        // package name, which is trivially reversible by anyone holding a list
        // of package names -- that is, everyone.
        var outcome: PlatformOriginKeyingOutcome? = null
        adapter().installOriginKeying(
            ByteArray(0),
            HealthConnectAdapter.ORIGIN_KEYING_ALGORITHM_VERSION
        ) { r -> outcome = r.getOrThrow().outcome }

        assertEquals(PlatformOriginKeyingOutcome.REJECTED, outcome)
    }

    @Test
    fun `forgetting the identity returns the adapter to fail-closed`() {
        // The salt is held for the lifetime of the engine attachment and
        // dropped on detach. That is what makes "in memory only" true rather
        // than merely intended.
        val created = keyedAdapter()
        created.forgetOriginKeying()

        assertEquals(
            PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED,
            page(created).unavailableReason
        )
    }

    @Test
    fun `every origin key is eight bytes, or empty for an unknown source`() {
        // The only two legal lengths. The length check is what stops a whole
        // raw package name travelling in a bytes field.
        for (observation in page().observations) {
            assertTrue(
                observation.originKey.size == 8 || observation.originKey.isEmpty(),
                "an origin key is eight bytes, or zero for no source reported"
            )
        }
    }

    @Test
    fun `absent health service reports unavailable rather than throwing`() {
        // Android without Health Connect installed is a normal state, not an
        // error. The game must stay fully playable through it (DECISIONS/0008).
        var result: PlatformAvailabilityResult? = null
        adapter().availability { r -> result = r.getOrThrow() }

        val availability = requireNotNull(result)
        assertFalse(availability.available)
        assertEquals(PlatformUnavailableReason.SERVICE_MISSING, availability.reason)
    }

    @Test
    fun `authorization reports a state rather than throwing`() {
        var result: PlatformAuthorizationResult? = null
        adapter().requestAuthorization { r -> result = r.getOrThrow() }

        assertEquals(
            PlatformAuthorizationState.UNAVAILABLE,
            requireNotNull(result).state
        )
    }

    @Test
    fun `an unavailable page names its reason`() {
        // The bridge maps a missing reason to transientFailure and records a
        // fault. An adapter that leaves it null is asking the caller to retry
        // forever against a service that is not installed.
        val fetched = page()
        assertEquals(PlatformSyncStatus.UNAVAILABLE, fetched.status)
        assertEquals(PlatformUnavailableReason.SERVICE_MISSING, fetched.unavailableReason)
    }

    @Test
    fun `an unavailable page offers no cursor to persist`() {
        // Persisting a cursor the adapter cannot stand behind would make the
        // next sync claim progress the ledger never recorded.
        assertNull(page().nextCursor)
    }

    @Test
    fun `an unavailable page asserts no completeness`() {
        // A completeness assertion settles buckets. Making one on the strength
        // of a read that never happened buries whatever those buckets were
        // about to receive, permanently.
        assertEquals(PlatformCompletenessKind.PARTIAL, page().completeness.kind)
    }

    @Test
    fun `only an invalidated cursor carries a rescan window`() {
        // A rescan is the recovery path for a lost cursor. Attaching one to any
        // other status would invite the bridge to treat an absolute window
        // total as ordinary incremental data — the exact double-count
        // scenario 13 exists to prevent.
        val fetched = page()
        if (fetched.status != PlatformSyncStatus.CURSOR_INVALIDATED) {
            assertNull(fetched.rescan)
        }
    }

    @Test
    fun `no observation carries a negative count or an inverted bucket`() {
        // The bridge refuses the WHOLE page on a malformed observation, rather
        // than dropping the slice: dropping one while honouring the page's
        // completeness assertion would settle the bucket the drop just emptied.
        for (observation in page().observations) {
            assertTrue(observation.steps >= 0, "steps must never be negative")
            assertTrue(
                observation.bucket.endMillis > observation.bucket.startMillis,
                "a bucket must cover a positive span"
            )
        }
    }

    @Test
    fun `a final page offers no continuation`() {
        val pagination = page().pagination
        if (pagination.isFinalPage) {
            assertNull(pagination.continuation)
        }
    }
}
