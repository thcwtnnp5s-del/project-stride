package com.projectstride.stride_health

import java.nio.BufferUnderflowException
import java.nio.ByteBuffer

/**
 * Everything a page of a paginated read needs in order to be recomputed.
 *
 * ## Why the continuation is self-describing rather than an in-memory handle
 *
 * A handle into adapter state would make page two depend on the process that
 * produced page one. This one does not: it carries the resolved interval, the
 * bucket width, the query generation, the scope the first page settled on, the
 * candidate cursor, and the offset -- so page two is a pure function of the
 * token and the platform's current contents.
 *
 * That is what makes an interrupted read safe to retry rather than merely
 * unlikely to be interrupted. The adapter mutates nothing, so a repeated page
 * recomputes the same answer, and every figure is absolute so a page that
 * arrives twice restates rather than accumulates.
 *
 * ## What it is NOT
 *
 * It is not a cursor. A continuation is in-flight read state and is never
 * persisted by anybody; a cursor is durable sync position and is persisted only
 * after the ledger and snapshot commit. Conflating them would persist a
 * position mid-read. They travel in different fields on the contract for
 * exactly that reason, and the candidate cursor rides inside this token only so
 * that the FINAL page can offer it -- it is never offered before then.
 */
internal data class ReadPlan(
    /** UTC milliseconds. The interval actually queried, not the one asked for. */
    val intervalStartMillis: Long,
    val intervalEndMillis: Long,

    /**
     * UTC milliseconds through which the scope is VOUCHED FOR, which is not the
     * same as the interval that was read.
     *
     * The read runs to the end of the bucket the clock is currently inside, so
     * the steps taken in the last few minutes are delivered rather than held
     * back for an hour. The assertion stops at the last COMPLETED bucket
     * boundary, because the current bucket is still accumulating: settling it
     * would compact a slice that is about to be restated upward, and the steps
     * added after the settlement would have nowhere to land.
     *
     * Carried in the token rather than recomputed per page, so every page of
     * one read vouches for the same instant even though the clock moved
     * between them.
     */
    val throughMillis: Long,

    val bucketWidthMillis: Long,

    /** Which query or token produced this. Never reused across reads. */
    val queryGeneration: Long,

    /**
     * True only when the platform was actually asked for its full source list
     * for this interval. "The sources that appeared in this batch" is false.
     */
    val enumeratedAllOrigins: Boolean,

    /**
     * True when this read is the bounded recovery that follows an expired
     * token. The status stays `CURSOR_INVALIDATED` and the rescan window is
     * restated on every page of it, not only the first.
     */
    val isRecovery: Boolean,

    /** True when the recovery window was clamped, leaving an unreachable gap. */
    val rescanTruncated: Boolean,

    /**
     * Whether manually-entered samples count, as the read that started this
     * page was asked.
     *
     * Carried rather than re-read from each page's request, so a caller that
     * varied the flag mid-read could not produce a page that contradicts the
     * one before it. A read is one read; the filter is decided once.
     */
    val includeManualEntries: Boolean,

    /** The candidate cursor, offered on the final page only. */
    val candidateCursor: String,

    /** Zero-based index into the ordered observation list. */
    val offset: Int,

    /** Zero-based page index. Diagnostic and cross-check only. */
    val pageIndex: Long,
) {

    fun encode(): ByteArray {
        val cursor = candidateCursor.toByteArray(Charsets.UTF_8)
        val buffer = ByteBuffer.allocate(4 + 1 + 8 * 5 + 4 + 4 + 1 + 4 + cursor.size)
        buffer.put(MAGIC)
        buffer.put(VERSION)
        buffer.putLong(intervalStartMillis)
        buffer.putLong(intervalEndMillis)
        buffer.putLong(throughMillis)
        buffer.putLong(bucketWidthMillis)
        buffer.putLong(queryGeneration)
        buffer.putInt(offset)
        buffer.putInt(pageIndex.toInt())
        var flags = 0
        if (enumeratedAllOrigins) flags = flags or FLAG_ALL_ORIGINS
        if (isRecovery) flags = flags or FLAG_RECOVERY
        if (rescanTruncated) flags = flags or FLAG_TRUNCATED
        if (includeManualEntries) flags = flags or FLAG_INCLUDE_MANUAL
        buffer.put(flags.toByte())
        buffer.putInt(cursor.size)
        buffer.put(cursor)
        return buffer.array()
    }

    companion object {
        private val MAGIC = byteArrayOf('S'.code.toByte(), 'T'.code.toByte(), 'R'.code.toByte(), 'D'.code.toByte())
        private const val VERSION: Byte = 1

        private const val FLAG_ALL_ORIGINS = 1
        private const val FLAG_RECOVERY = 2
        private const val FLAG_TRUNCATED = 4
        private const val FLAG_INCLUDE_MANUAL = 8

        /**
         * Decodes a continuation, or null if it is not one this adapter wrote.
         *
         * Null is not an error and must not be treated as one: it means "start
         * a fresh read", which is always safe because every figure the adapter
         * produces is absolute. Throwing here would turn a stale token from a
         * process restart into a failed sync.
         */
        fun decode(bytes: ByteArray?): ReadPlan? {
            if (bytes == null || bytes.size < 4 + 1) return null
            for (i in MAGIC.indices) if (bytes[i] != MAGIC[i]) return null
            return try {
                val buffer = ByteBuffer.wrap(bytes)
                buffer.position(MAGIC.size)
                if (buffer.get() != VERSION) return null
                val intervalStart = buffer.long
                val intervalEnd = buffer.long
                val through = buffer.long
                val width = buffer.long
                val generation = buffer.long
                val offset = buffer.int
                val pageIndex = buffer.int.toLong()
                val flags = buffer.get().toInt()
                val cursorLength = buffer.int
                if (cursorLength < 0 || cursorLength > buffer.remaining()) return null
                val cursor = ByteArray(cursorLength)
                buffer.get(cursor)
                if (width <= 0L || offset < 0 || intervalEnd < intervalStart) return null
                ReadPlan(
                    intervalStartMillis = intervalStart,
                    intervalEndMillis = intervalEnd,
                    throughMillis = through,
                    bucketWidthMillis = width,
                    queryGeneration = generation,
                    enumeratedAllOrigins = (flags and FLAG_ALL_ORIGINS) != 0,
                    isRecovery = (flags and FLAG_RECOVERY) != 0,
                    rescanTruncated = (flags and FLAG_TRUNCATED) != 0,
                    includeManualEntries = (flags and FLAG_INCLUDE_MANUAL) != 0,
                    candidateCursor = String(cursor, Charsets.UTF_8),
                    offset = offset,
                    pageIndex = pageIndex,
                )
            } catch (_: BufferUnderflowException) {
                null
            }
        }
    }
}
