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
 * M-2/M-4 scope: these assert the *contract* the adapter must honour, which is
 * meaningful even against the shell implementation. Behavioral Health Connect
 * tests -- real permissions, real step records, real change tokens -- need a
 * physical device and arrive with S-01 and V-02b.
 *
 * The contract asserted here is not incidental. Every one of these is a
 * property the reconciliation ledger depends on.
 */
internal class HealthConnectAdapterTest {

    private fun adapter(): HealthConnectAdapter =
        HealthConnectAdapter(Mockito.mock(Context::class.java))

    @Test
    fun `absent health service reports unavailable rather than throwing`() {
        // Android without Health Connect installed is a normal state, not an
        // error. The game must stay fully playable through it (DECISIONS/0008).
        assertFalse(adapter().isAvailable())
    }

    @Test
    fun `authorization reports a state rather than throwing`() {
        var result: PlatformAuthorization? = null
        adapter().requestAuthorization { r -> result = r.getOrThrow() }

        assertEquals(PlatformAuthorization.UNAVAILABLE, result)
    }

    @Test
    fun `fetch returns a well-formed result with non-negative counts`() {
        var result: PlatformFetchResult? = null
        adapter().fetchNewSteps(null, null) { r -> result = r.getOrThrow() }

        val fetched = requireNotNull(result)
        assertTrue(fetched.newSteps >= 0, "newSteps must never be negative")
        assertTrue(fetched.deletedSteps >= 0, "deletedSteps must never be negative")
    }

    @Test
    fun `a valid status never carries a rescan`() {
        // A rescan is the recovery path for a lost cursor. Attaching one to a
        // healthy incremental fetch would invite reconciliation to apply an
        // absolute window total as though it were a delta -- the exact
        // double-count scenario 13 exists to prevent.
        var result: PlatformFetchResult? = null
        adapter().fetchNewSteps(null, null) { r -> result = r.getOrThrow() }

        val fetched = requireNotNull(result)
        if (fetched.status == PlatformCursorStatus.VALID) {
            assertNull(fetched.rescan)
        }
    }

    @Test
    fun `an unavailable service offers no cursor to persist`() {
        // Persisting a cursor the adapter cannot stand behind would make the
        // next sync claim progress the ledger never recorded.
        var result: PlatformFetchResult? = null
        adapter().fetchNewSteps(null, null) { r -> result = r.getOrThrow() }

        assertNull(requireNotNull(result).cursor)
    }
}
