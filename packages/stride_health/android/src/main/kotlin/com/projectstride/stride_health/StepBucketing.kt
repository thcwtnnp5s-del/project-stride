package com.projectstride.stride_health

/**
 * Turning records into absolute per-origin, per-bucket totals.
 *
 * This is the only place the adapter does arithmetic on health values, and the
 * only normalization it is permitted to do. Collapsing overlapping records into
 * one total per `(origin, bucket)` is normalization. Deciding what to *grant*
 * is not: no banked totals, no no-clawback rule, no ledger deduplication lives
 * here or anywhere else in this plugin.
 */
internal object StepBucketing {

    /**
     * The bucket grid, anchored to the Unix epoch.
     *
     * Not to local midnight, not to the read window, and not to the first
     * record seen: a grid that moved would produce different buckets for the
     * same instant on two reads, and the core keys its ledger on the bucket.
     * Two reads of the same slice must produce the same `(origin, bucket)` or
     * an absolute restatement is not a restatement of anything.
     */
    fun bucketStart(millis: Long, widthMillis: Long): Long =
        Math.floorDiv(millis, widthMillis) * widthMillis

    /** The bucket boundaries covering `[startMillis, endMillis)`, aligned. */
    fun bucketStartsIn(startMillis: Long, endMillis: Long, widthMillis: Long): List<Long> {
        if (endMillis <= startMillis) return emptyList()
        val first = bucketStart(startMillis, widthMillis)
        val out = ArrayList<Long>()
        var at = first
        while (at < endMillis) {
            out.add(at)
            at += widthMillis
        }
        return out
    }

    /**
     * Absolute totals for every `(origin, bucket)` in the interval, zeros
     * included.
     *
     * ## Why zeros are emitted rather than omitted
     *
     * A deletion is `steps = 0` for the slice it emptied, and an omitted slice
     * is not a zero -- it is silence, which the core cannot act on. Health
     * Connect reports a deletion as a bare record id with no time and no
     * origin, so the adapter can never point at the bucket that changed. What
     * it CAN do is re-read a bounded interval authoritatively and state the
     * total for every slice in it, at which case the emptied bucket says zero
     * because it genuinely is zero.
     *
     * That is why this function takes an interval and enumerates it, rather
     * than iterating the records it happened to receive.
     *
     * The cost is bounded and small: the interval is clamped by
     * `maxRescanWindowMillis` and buckets are at least an hour wide, so a
     * thirty-day window is 720 slices per origin.
     *
     * @param origins the sources to enumerate. Every one gets an entry for
     *   every bucket, so a source that fell to zero across the whole window is
     *   still stated rather than implied.
     */
    fun absolutes(
        records: List<RawStepRecord>,
        origins: Set<String>,
        intervalStartMillis: Long,
        intervalEndMillis: Long,
        bucketWidthMillis: Long,
    ): List<BucketTotal> {
        val bucketStarts = bucketStartsIn(intervalStartMillis, intervalEndMillis, bucketWidthMillis)
        if (bucketStarts.isEmpty()) return emptyList()

        val totals = HashMap<String, LongArray>()
        val indexOf = HashMap<Long, Int>(bucketStarts.size * 2)
        for ((index, start) in bucketStarts.withIndex()) indexOf[start] = index

        for (origin in origins) totals[origin] = LongArray(bucketStarts.size)

        for (record in records) {
            val row = totals.getOrPut(record.originIdentifier) { LongArray(bucketStarts.size) }
            for ((bucketStart, share) in apportion(record, bucketWidthMillis)) {
                val index = indexOf[bucketStart] ?: continue
                row[index] += share
            }
        }

        val out = ArrayList<BucketTotal>(totals.size * bucketStarts.size)
        for ((origin, row) in totals) {
            for ((index, start) in bucketStarts.withIndex()) {
                out.add(
                    BucketTotal(
                        originIdentifier = origin,
                        startMillis = start,
                        endMillis = start + bucketWidthMillis,
                        steps = row[index],
                    )
                )
            }
        }

        // Sorted, and sorted explicitly rather than left to map iteration
        // order: the page offset in a continuation is an index into this list,
        // so two reads of the same interval must order it identically or a
        // resumed page would skip or repeat a slice. A HashMap's order is
        // stable within one run and guaranteed by nothing across two.
        out.sortWith(
            compareBy<BucketTotal> { it.startMillis }.thenBy { it.originIdentifier }
        )
        return out
    }

    /**
     * Splits one record across the buckets it spans, without inventing or
     * losing a step.
     *
     * A record carries a count and a span, not a per-instant series, so a
     * record crossing a bucket boundary has to be apportioned somehow. This
     * apportions pro-rata by elapsed time, using a cumulative floor so that the
     * shares sum to EXACTLY the record's count -- rounding each bucket
     * independently would lose a step per boundary, permanently and invisibly.
     *
     * A zero-length record (start == end, which Health Connect permits for an
     * instantaneous write) lands wholly in the bucket containing its start.
     */
    fun apportion(record: RawStepRecord, widthMillis: Long): List<Pair<Long, Long>> {
        val span = record.endMillis - record.startMillis
        if (span <= 0L) {
            return listOf(bucketStart(record.startMillis, widthMillis) to record.count)
        }

        val out = ArrayList<Pair<Long, Long>>()
        var allocated = 0L
        var elapsed = 0L
        var at = bucketStart(record.startMillis, widthMillis)
        while (at < record.endMillis) {
            val overlapStart = maxOf(at, record.startMillis)
            val overlapEnd = minOf(at + widthMillis, record.endMillis)
            elapsed += overlapEnd - overlapStart
            // Cumulative rather than per-bucket, so the shares sum to exactly
            // `count`. `Math.multiplyHigh` is not needed and not used: the
            // product is bounded by the interval clamp upstream and by the
            // record count, and a 128-bit path here would be complexity in the
            // one place the reasoning has to stay obvious.
            val cumulative = (record.count * elapsed) / span
            out.add(at to (cumulative - allocated))
            allocated = cumulative
            at += widthMillis
        }
        return out
    }
}

/** One absolute total, still carrying its raw origin. Never crosses Pigeon. */
internal data class BucketTotal(
    val originIdentifier: String,
    val startMillis: Long,
    val endMillis: Long,
    val steps: Long,
)
