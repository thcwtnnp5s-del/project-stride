package com.projectstride.stride_health

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The two pure pieces the page logic rests on: the bucket grid, and the
 * continuation codec.
 *
 * Both are small enough to look correct and consequential enough that "looks
 * correct" is not a standard. A grid that moved would produce a different
 * `(origin, bucket)` for the same instant on two reads, so an absolute
 * restatement would restate nothing; a codec that mis-decoded an offset would
 * skip or repeat a slice in a paginated read.
 */
internal class ReadPlanAndBucketingTest {

    private val hour = 60L * 60L * 1000L

    // =======================================================================
    // The bucket grid
    // =======================================================================

    @Test
    fun `the grid is anchored to the epoch, not to the read`() {
        // Two reads of the same instant must produce the same bucket, or an
        // absolute restatement is not a restatement of anything.
        assertEquals(0L, StepBucketing.bucketStart(0L, hour))
        assertEquals(0L, StepBucketing.bucketStart(hour - 1, hour))
        assertEquals(hour, StepBucketing.bucketStart(hour, hour))
        assertEquals(1_699_999_200_000L, StepBucketing.bucketStart(1_700_000_000_000L, hour))
    }

    @Test
    fun `the grid floors below the epoch rather than truncating toward zero`() {
        // Integer division truncates toward zero, which would put -1ms into the
        // bucket starting at 0 and give a bucket that does not contain its own
        // instant. Only pre-1970 clocks reach this, and a clock that has been
        // set wrong is exactly when a quiet off-by-one bucket appears.
        assertEquals(-hour, StepBucketing.bucketStart(-1L, hour))
        assertEquals(-hour, StepBucketing.bucketStart(-hour, hour))
        assertEquals(-2 * hour, StepBucketing.bucketStart(-hour - 1, hour))
    }

    @Test
    fun `apportioning a record never invents or loses a step`() {
        // Rounding each bucket independently would lose a step per boundary,
        // permanently and invisibly. The cumulative floor is what makes the
        // shares sum to exactly the count.
        for (count in listOf(1L, 7L, 101L, 999L, 100_000L)) {
            for (spanHours in 1..9) {
                val record = stepRecord("x", 0L, spanHours * hour, count)
                val shares = StepBucketing.apportion(record, hour)
                assertEquals(spanHours, shares.size)
                assertEquals(count, shares.sumOf { it.second }, "count=$count span=$spanHours")
                assertTrue(shares.all { it.second >= 0 })
            }
        }
    }

    @Test
    fun `an instantaneous record lands wholly in one bucket`() {
        val shares = StepBucketing.apportion(stepRecord("x", 90L * 60_000L, 90L * 60_000L, 12), hour)
        assertEquals(listOf(hour to 12L), shares)
    }

    @Test
    fun `absolutes state every slice for every origin, including the empty ones`() {
        // Silence is not a zero. A source that emptied has to SAY zero, or the
        // core has no figure to reconcile the emptied slice against.
        val totals = StepBucketing.absolutes(
            records = listOf(stepRecord("phone", hour, 2 * hour, 30)),
            origins = setOf("phone", "watch"),
            intervalStartMillis = 0L,
            intervalEndMillis = 3 * hour,
            bucketWidthMillis = hour,
        )

        assertEquals(6, totals.size, "two origins across three buckets")
        assertEquals(30L, totals.first { it.originIdentifier == "phone" && it.startMillis == hour }.steps)
        assertEquals(0L, totals.first { it.originIdentifier == "phone" && it.startMillis == 0L }.steps)
        assertEquals(0L, totals.first { it.originIdentifier == "watch" && it.startMillis == hour }.steps)
    }

    @Test
    fun `the ordering is stable, because a page offset indexes into it`() {
        val records = listOf(
            stepRecord("zebra", hour, 2 * hour, 1),
            stepRecord("alpha", 0L, hour, 2),
            stepRecord("middle", 2 * hour, 3 * hour, 3),
        )
        val first = StepBucketing.absolutes(records, setOf("zebra", "alpha", "middle"), 0L, 3 * hour, hour)
        val again = StepBucketing.absolutes(records.reversed(), setOf("middle", "alpha", "zebra"), 0L, 3 * hour, hour)

        assertEquals(first, again, "the order must not depend on map iteration or input order")
        // Bucket first, then origin -- the shape a resumed page depends on.
        assertTrue(first.zipWithNext().all { (a, b) -> a.startMillis <= b.startMillis })
    }

    // =======================================================================
    // The continuation codec
    // =======================================================================

    private fun plan(offset: Int = 0, pageIndex: Long = 0L) = ReadPlan(
        intervalStartMillis = 1_000L,
        intervalEndMillis = 9_000L,
        throughMillis = 8_000L,
        bucketWidthMillis = hour,
        queryGeneration = 42L,
        enumeratedAllOrigins = true,
        isRecovery = true,
        rescanTruncated = true,
        includeManualEntries = true,
        candidateCursor = "a-changes-token",
        offset = offset,
        pageIndex = pageIndex,
    )

    @Test
    fun `a continuation round-trips exactly`() {
        val original = plan(offset = 500, pageIndex = 1L)
        assertEquals(original, ReadPlan.decode(original.encode()))
    }

    @Test
    fun `every flag survives independently`() {
        val flagSets = listOf(
            listOf(false, false, false, false),
            listOf(true, false, false, false),
            listOf(false, true, false, false),
            listOf(false, false, true, false),
            listOf(false, false, false, true),
            listOf(true, true, true, true),
        )
        for (flags in flagSets) {
            val original = plan().copy(
                enumeratedAllOrigins = flags[0],
                isRecovery = flags[1],
                rescanTruncated = flags[2],
                includeManualEntries = flags[3],
            )
            assertEquals(original, ReadPlan.decode(original.encode()), "flags=$flags")
        }
    }

    @Test
    fun `a token this adapter did not write decodes to null, not to an exception`() {
        // A stale token from a previous process is not an error. Null means
        // "start a fresh read", which is always safe because every figure is
        // absolute -- and throwing here would turn a process restart into a
        // failed sync.
        assertNull(ReadPlan.decode(null))
        assertNull(ReadPlan.decode(ByteArray(0)))
        assertNull(ReadPlan.decode(byteArrayOf(1, 2, 3)))
        assertNull(ReadPlan.decode("not a continuation at all".toByteArray()))
    }

    @Test
    fun `a truncated token decodes to null rather than to a wrong offset`() {
        val encoded = plan(offset = 500).encode()
        for (length in 5 until encoded.size) {
            assertNull(
                ReadPlan.decode(encoded.copyOf(length)),
                "a token cut at $length bytes must not decode",
            )
        }
    }

    @Test
    fun `a token carries no salt and no source identifier`() {
        // It crosses the Pigeon boundary and comes back. The only string in it
        // is the platform's own changes token, which is opaque sync position
        // and not derived from any source.
        val encoded = plan().encode()
        val text = String(encoded, Charsets.ISO_8859_1)
        assertTrue(text.contains("a-changes-token"))
        assertTrue(!text.contains("com."), "no package name may ride in a continuation")
    }
}
