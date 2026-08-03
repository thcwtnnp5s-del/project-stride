package com.projectstride.stride_health

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The Health Connect step reader.
 *
 * Foreground only. There is no passive-monitoring registration, no worker, no
 * foreground service, and no background entry point of any kind in this plugin
 * — S-01A is foreground synchronization and S-01B is blocked on a real
 * persistence coordinator (DECISIONS/0013, DECISIONS/0014).
 *
 * All platform access goes through [StepSource], so every decision below is
 * assertable on a plain JVM with no device, no emulator, and no Health Connect
 * installed. [HealthConnectStepSource] is the only production implementation.
 *
 * ===========================================================================
 * The four things this class is responsible for getting right
 * ===========================================================================
 *
 * ## 1. Absolute totals, per origin, per bucket — never deltas
 *
 * Health Connect's Changes API reports *what changed*, which is not what the
 * boundary carries. So a change notification is only ever a hint about WHERE to
 * look: the adapter resolves an interval, re-reads it authoritatively, and
 * states the current total for every `(origin, bucket)` slice in it — zeros
 * included.
 *
 * A correction is an ordinary upsert and needs no special path, because the
 * restated total is the correction.
 *
 * **A deletion is the hard case, and it drives the design.** Health Connect
 * gives a deletion as a bare record id: no time, no origin, no count. Nothing
 * in the API says which bucket emptied. An adapter that forwarded "something
 * was deleted" would leave the core with no figure to reconcile, and one that
 * ignored deletions would leave a bucket permanently overstated.
 *
 * So when the change stream reports any deletion, the adapter widens the read
 * to the bounded recovery window and restates every slice in it. The deleted
 * steps then appear as the arithmetic difference in whichever bucket actually
 * changed, without the adapter ever having to know which one that was. It is
 * more work than a localized re-read; it is bounded by `maxRescanWindowMillis`
 * and by the one-hour minimum bucket width, and it is the only honest answer
 * available.
 *
 * ## 2. Completeness is asserted, and only for what was actually drained
 *
 * `COMPLETE_THROUGH` is emitted only on the final page of a read.
 * `ALL_ORIGINS` is emitted only when [StepSource.enumerateOrigins] actually
 * answered — Health Connect's aggregate result carries the full contributing
 * source list for an interval, so this is a real enumeration and not an
 * inference from the batch. When it declines, the scope names the origins the
 * adapter can vouch for and nothing else.
 *
 * The assertion stops at the last COMPLETED bucket. The read itself runs to the
 * end of the bucket the clock is inside, so recent steps are delivered
 * promptly, but the current bucket is still accumulating and settling it would
 * bury whatever lands in it next.
 *
 * ## 3. Token expiry is a bounded recovery, never a reset and never a windfall
 *
 * On `CHANGES_TOKEN_EXPIRED` the adapter reports `CURSOR_INVALIDATED` with a
 * `PlatformRescanWindow` over `[rescanFloorMillis, now]`, clamped to
 * `maxRescanWindowMillis` and flagged `truncated` when clamping occurred, and
 * observations that are the **authoritative contents of that window**. It never
 * reports the rescan as new, and it never signals a reset. The core reconciles
 * the absolutes against what it already granted for the same slices; the
 * no-clawback rule turns any shortfall into recorded discrepancy.
 *
 * Recovery mutates nothing here, so an interruption at any point leaves the old
 * cursor and the ledger untouched and the next attempt recomputes the same
 * answer.
 *
 * ## 4. The cursor is never native state
 *
 * The changes token is returned as `nextCursor` on the final page and
 * forgotten. It is not written to `SharedPreferences`, a DataStore, a file, or
 * anything else — there is no durable store in this plugin, and
 * `Scripts/check-origin-privacy.sh` fails the build if one appears. Between
 * pages the candidate travels inside the continuation, which is in-flight read
 * state that nobody persists either.
 *
 * ===========================================================================
 * Origin keying
 * ===========================================================================
 *
 * The salt arrives through [installOriginKeying] and lives in memory for the
 * lifetime of the engine attachment. This plugin is a consumer of the app's
 * device-bound identity and never a second custodian of one: there is no mint
 * path, no lookup path, and no cache. Until the salt is installed, [fetchSteps]
 * refuses with `ORIGIN_KEYING_UNCONFIGURED` and reads nothing — a page keyed
 * under no salt would re-key every origin, and a re-keyed origin looks exactly
 * like a new device whose whole retention window is ungranted.
 *
 * The raw `metadata.dataOrigin.packageName` exists between [StepSource] and
 * [OriginKeying.keyBytes] and is gone when the page is built. It is never a
 * field on the wire, never a log line, and never a diagnostic string.
 */
internal class HealthConnectAdapter(
    private val source: StepSource,
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
) : HealthHostApi {

    /**
     * The scope every platform call runs on.
     *
     * In-flight work for a Dart call the user's foreground app made, and
     * nothing else. Cancelled on detach, so a read cannot outlive the engine
     * that asked for it. This is not a background entry point and must not
     * become one.
     */
    private val scope = CoroutineScope(SupervisorJob() + dispatcher)

    /**
     * The device-bound keying salt, in memory only.
     *
     * Never written anywhere durable, and cleared by [forgetOriginKeying] on
     * detach. Until it is set, [fetchSteps] refuses.
     */
    @Volatile
    private var keying: OriginKeying? = null

    /**
     * Incremented whenever a new changes token is acquired or a fresh read
     * starts.
     *
     * In memory, and deliberately so: it identifies a read within one
     * attachment. A completeness assertion made under a generation that has
     * since been superseded is stale, and the core uses the number to notice.
     */
    private val queryGeneration = java.util.concurrent.atomic.AtomicLong(0L)

    // -----------------------------------------------------------------------
    // installOriginKeying
    // -----------------------------------------------------------------------

    override fun installOriginKeying(
        salt: ByteArray,
        algorithmVersion: Long,
        callback: (Result<PlatformOriginKeyingResult>) -> Unit,
    ) {
        if (algorithmVersion != OriginKeying.ALGORITHM_VERSION) {
            // A typed refusal rather than a silent fallback. Keys nothing else
            // on the device agrees with look exactly like a new device.
            callback(keyingResult(PlatformOriginKeyingOutcome.UNSUPPORTED_ALGORITHM))
            return
        }
        if (salt.isEmpty()) {
            // An empty salt makes every key a bare unkeyed digest of a package
            // name, which is trivially reversible by anyone holding a list of
            // package names -- that is, everyone.
            callback(keyingResult(PlatformOriginKeyingOutcome.REJECTED))
            return
        }
        keying?.forget()
        keying = OriginKeying(salt)
        callback(keyingResult(PlatformOriginKeyingOutcome.INSTALLED))
    }

    /** Drops the salt and cancels in-flight work. Called on engine detach. */
    fun forgetOriginKeying() {
        keying?.forget()
        keying = null
    }

    /** Tears the adapter down. Nothing survives the attachment. */
    fun dispose() {
        forgetOriginKeying()
        scope.cancel()
    }

    // -----------------------------------------------------------------------
    // availability
    // -----------------------------------------------------------------------

    override fun availability(callback: (Result<PlatformAvailabilityResult>) -> Unit) {
        // Absence is a NORMAL state, not an error: Android without Health
        // Connect installed is the ordinary case, and the game stays fully
        // playable through it (DECISIONS/0008).
        val result = when (safely { source.availability() } ?: SourceAvailability.SERVICE_MISSING) {
            SourceAvailability.AVAILABLE ->
                PlatformAvailabilityResult(available = true, reason = null, diagnostic = null)

            SourceAvailability.SERVICE_MISSING ->
                PlatformAvailabilityResult(
                    available = false,
                    reason = PlatformUnavailableReason.SERVICE_MISSING,
                    diagnostic = "health connect is not available on this device",
                )

            SourceAvailability.PROVIDER_UPDATE_REQUIRED ->
                PlatformAvailabilityResult(
                    available = false,
                    reason = PlatformUnavailableReason.SERVICE_MISSING,
                    diagnostic = "health connect requires a provider update",
                )
        }
        callback(Result.success(result))
    }

    // -----------------------------------------------------------------------
    // requestAuthorization
    // -----------------------------------------------------------------------

    override fun requestAuthorization(
        callback: (Result<PlatformAuthorizationResult>) -> Unit,
    ) {
        scope.launch {
            val state = try {
                when (source.availability()) {
                    SourceAvailability.AVAILABLE ->
                        // Read-only, steps only. There is no write scope
                        // anywhere in this plugin and there must not be one.
                        if (source.hasStepReadPermission()) {
                            PlatformAuthorizationState.GRANTED
                        } else {
                            source.requestStepReadPermission()
                        }

                    else -> PlatformAuthorizationState.UNAVAILABLE
                }
            } catch (_: Throwable) {
                // Never throws for a denial, and never throws for anything
                // else either: nothing about a missing permission may block a
                // screen, a craft, or a fight.
                PlatformAuthorizationState.UNAVAILABLE
            }
            callback(
                Result.success(
                    PlatformAuthorizationResult(state = state, diagnostic = null)
                )
            )
        }
    }

    // -----------------------------------------------------------------------
    // fetchSteps
    // -----------------------------------------------------------------------

    override fun fetchSteps(
        request: PlatformSyncRequest,
        callback: (Result<PlatformSyncPage>) -> Unit,
    ) {
        // Fail-closed, checked before anything is read. Observations keyed
        // under no salt would re-key every origin and grant the retention
        // window a second time, and nothing would detect it.
        val keying = this.keying
        if (keying == null) {
            callback(Result.success(unavailablePage(PlatformUnavailableReason.ORIGIN_KEYING_UNCONFIGURED)))
            return
        }

        scope.launch {
            val page = try {
                read(request, keying)
            } catch (_: Throwable) {
                // On a genuine error the adapter leaves its own state untouched
                // and reports a retryable failure. No cursor is offered, so the
                // next attempt resumes from exactly the same position.
                unavailablePage(PlatformUnavailableReason.TRANSIENT_FAILURE)
            }
            callback(Result.success(page))
        }
    }

    private suspend fun read(
        request: PlatformSyncRequest,
        keying: OriginKeying,
    ): PlatformSyncPage {
        if (source.availability() != SourceAvailability.AVAILABLE) {
            return unavailablePage(PlatformUnavailableReason.SERVICE_MISSING)
        }
        if (!source.hasStepReadPermission()) {
            // Health Connect will answer an unauthorized read with an empty
            // result, which is indistinguishable from a player who did not
            // move. Reporting the permission state instead is what stops an
            // empty page being mistaken for a settled one.
            return unavailablePage(PlatformUnavailableReason.PERMISSION_UNAVAILABLE)
        }

        // Clamped UP, never down. The privacy ruling bounds retention length
        // and says nothing about resolution; a minute-resolution read would be
        // a minute-by-minute record of when the player moved, kept for a week.
        val width = maxOf(request.bucketWidthMillis, MINIMUM_BUCKET_WIDTH_MILLIS)

        val resumed = ReadPlan.decode(request.continuation)
        if (resumed != null) {
            // A continuation is a pure description of a page. Nothing about
            // resuming touches the change stream again, which is what makes an
            // interrupted read safe to retry rather than merely unlikely to be
            // interrupted.
            return emit(resumed, keying)
        }

        val cursor = request.cursor?.toString(Charsets.UTF_8)
        if (cursor.isNullOrEmpty()) return initialRead(request, width, keying)

        return when (val changes = source.drainChanges(cursor)) {
            is ChangeStream.Expired -> recover(request, width, keying)
            is ChangeStream.Drained -> incremental(request, width, keying, changes)
        }
    }

    /**
     * The first read: register for changes, then read the bounded window.
     *
     * The token is acquired BEFORE the read, not after. A record written during
     * the read then falls inside the next sync's change stream rather than into
     * the gap between the two, and the worst case is a slice restated with the
     * same absolute figure — which costs nothing, because every figure is
     * absolute.
     */
    private suspend fun initialRead(
        request: PlatformSyncRequest,
        width: Long,
        keying: OriginKeying,
    ): PlatformSyncPage {
        val token = source.acquireChangesToken()
        val window = boundedWindow(request, width)
        val plan = ReadPlan(
            intervalStartMillis = window.startMillis,
            intervalEndMillis = window.endMillis,
            throughMillis = window.throughMillis,
            bucketWidthMillis = width,
            queryGeneration = queryGeneration.incrementAndGet(),
            enumeratedAllOrigins = false,
            isRecovery = false,
            rescanTruncated = false,
            includeManualEntries = request.includeManualEntries,
            candidateCursor = token,
            offset = 0,
            pageIndex = 0L,
        )
        return emit(plan, keying)
    }

    /**
     * Bounded authoritative recovery after the platform rejected the cursor.
     *
     * Never reports the rescan as all new, and never resets anything. A fresh
     * token is acquired first, so nothing written during recovery is lost.
     */
    private suspend fun recover(
        request: PlatformSyncRequest,
        width: Long,
        keying: OriginKeying,
    ): PlatformSyncPage {
        val token = source.acquireChangesToken()
        val window = boundedWindow(request, width)
        val plan = ReadPlan(
            intervalStartMillis = window.startMillis,
            intervalEndMillis = window.endMillis,
            throughMillis = window.throughMillis,
            bucketWidthMillis = width,
            queryGeneration = queryGeneration.incrementAndGet(),
            enumeratedAllOrigins = false,
            isRecovery = true,
            rescanTruncated = window.truncated,
            includeManualEntries = request.includeManualEntries,
            candidateCursor = token,
            offset = 0,
            pageIndex = 0L,
        )
        return emit(plan, keying)
    }

    /**
     * The ordinary path: something changed since the cursor.
     *
     * The change stream is drained fully before anything is read, so the
     * interval below covers every notification rather than the first page of
     * them.
     */
    private suspend fun incremental(
        request: PlatformSyncRequest,
        width: Long,
        keying: OriginKeying,
        changes: ChangeStream.Drained,
    ): PlatformSyncPage {
        if (changes.upserts.isEmpty() && !changes.sawDeletion) {
            // Nothing changed. No completeness is asserted: knowing that
            // nothing arrived since the cursor says nothing about what the
            // window already contained, and the safe default is to settle
            // nothing.
            return noChangePage(changes.nextToken)
        }

        val bounds = boundedWindow(request, width)
        val interval = if (changes.sawDeletion) {
            // A deletion carries no time and no origin, so it cannot be
            // localized. The recovery window is the smallest interval that is
            // guaranteed to contain it.
            bounds
        } else {
            // Upsertions carry their own times, so the affected interval is
            // exactly the buckets they touch -- clamped into the bounded
            // window so that one very old record cannot produce an unbounded
            // read.
            affectedInterval(changes.upserts, width, bounds)
        }

        val plan = ReadPlan(
            intervalStartMillis = interval.startMillis,
            intervalEndMillis = interval.endMillis,
            throughMillis = interval.throughMillis,
            bucketWidthMillis = width,
            queryGeneration = queryGeneration.incrementAndGet(),
            enumeratedAllOrigins = false,
            isRecovery = false,
            rescanTruncated = false,
            includeManualEntries = request.includeManualEntries,
            candidateCursor = changes.nextToken,
            offset = 0,
            pageIndex = 0L,
        )
        return emit(plan, keying)
    }

    /**
     * Reads the planned interval and emits one page of it.
     *
     * Re-reads on every page rather than caching the first page's result. That
     * costs a query per page and buys the property the contract cares about: a
     * page is a pure function of its continuation, so an interrupted read
     * resumes and a repeated page restates. Data that shifted between pages is
     * harmless for the same reason every figure is absolute.
     */
    private suspend fun emit(
        plan: ReadPlan,
        keying: OriginKeying,
    ): PlatformSyncPage {
        val records = source
            .readRecords(plan.intervalStartMillis, plan.intervalEndMillis)
            .filter { plan.includeManualEntries || !it.manuallyEntered }

        // Asked, not inferred. `null` means the platform would not give its
        // full source list, and the scope narrows accordingly -- "the sources
        // that appeared in this batch" is SOME_ORIGINS, and calling it
        // ALL_ORIGINS is how a completeness assertion settles a source that was
        // never read.
        val enumerated = source.enumerateOrigins(plan.intervalStartMillis, plan.intervalEndMillis)
        val origins = LinkedHashSet<String>()
        records.forEach { origins.add(it.originIdentifier) }
        enumerated?.let { origins.addAll(it) }

        val totals = StepBucketing.absolutes(
            records = records,
            origins = origins,
            intervalStartMillis = plan.intervalStartMillis,
            intervalEndMillis = plan.intervalEndMillis,
            bucketWidthMillis = plan.bucketWidthMillis,
        )

        val from = minOf(plan.offset, totals.size)
        val to = minOf(from + MAX_OBSERVATIONS_PER_PAGE, totals.size)
        val slice = totals.subList(from, to)
        val isFinalPage = to >= totals.size

        val observations = slice.map { total ->
            PlatformStepObservation(
                // Keyed here, and the raw identifier is gone when this returns.
                originKey = keying.keyBytes(total.originIdentifier),
                bucket = PlatformTimeBucket(
                    startMillis = total.startMillis,
                    endMillis = total.endMillis,
                ),
                steps = total.steps,
            )
        }

        // Narrowing is one-way across a read. If the platform enumerated on
        // page one and declined on page four, the read as a whole did not
        // enumerate, and the pages that follow must not claim it did -- a scope
        // that widens mid-read would let the final page settle sources an
        // earlier page could not see.
        val allOrigins = enumerated != null &&
            (plan.pageIndex == 0L || plan.enumeratedAllOrigins)
        val scope = if (allOrigins) {
            // ALL_ORIGINS names nothing: the bridge treats a scope that claims
            // to speak for every source while naming some as contradictory.
            PlatformOriginScope(
                kind = PlatformOriginScopeKind.ALL_ORIGINS,
                originKeys = emptyList(),
            )
        } else {
            PlatformOriginScope(
                kind = PlatformOriginScopeKind.SOME_ORIGINS,
                originKeys = origins.map { keying.keyBytes(it) },
            )
        }

        val kind = when {
            // Every page but the last. The bridge downgrades a completeness
            // assertion on a non-final page and counts it as a fault; this is
            // the adapter not making it in the first place.
            !isFinalPage -> PlatformCompletenessKind.PARTIAL

            // A truncated recovery reached less than it was asked to, and the
            // contract makes that PARTIAL rather than a narrower assertion:
            // there is one `truncated` flag and no way to say "complete for the
            // part I reached, and here is the gap". Under-settling costs a
            // little ledger growth; the alternative buries the gap.
            plan.isRecovery && plan.rescanTruncated -> PlatformCompletenessKind.PARTIAL

            // A recovery's authority stops at the window it could actually
            // reach, which is why this is not COMPLETE_THROUGH.
            plan.isRecovery -> PlatformCompletenessKind.RECOVERY_COMPLETE_THROUGH

            // Nothing to vouch for: the current bucket is the only one read.
            plan.throughMillis <= plan.intervalStartMillis -> PlatformCompletenessKind.PARTIAL

            else -> PlatformCompletenessKind.COMPLETE_THROUGH
        }

        val continuation = if (isFinalPage) {
            null
        } else {
            plan.copy(
                offset = to,
                pageIndex = plan.pageIndex + 1,
                enumeratedAllOrigins = allOrigins,
            ).encode()
        }

        return PlatformSyncPage(
            status = if (plan.isRecovery) {
                PlatformSyncStatus.CURSOR_INVALIDATED
            } else {
                PlatformSyncStatus.INCREMENTAL
            },
            observations = observations,
            completeness = PlatformCompleteness(
                kind = kind,
                dataType = PlatformHealthDataType.STEPS,
                scope = scope,
                intervalStartMillis = plan.intervalStartMillis,
                intervalEndMillis = plan.throughMillis,
                queryGeneration = plan.queryGeneration,
                throughMillis = plan.throughMillis,
            ),
            pagination = PlatformPagination(
                pageIndex = plan.pageIndex,
                isFinalPage = isFinalPage,
                continuation = continuation,
            ),
            // Offered on the final page only.
            //
            // A cursor handed over mid-read would let the caller record a
            // position for pages it has not seen. On the recovery path the
            // contract is read the same way and for the same reason: the
            // replacement token is offered once the recovery has been fully
            // delivered, and the caller still makes it durable only after the
            // ledger and snapshot commit. Withholding it forever would leave
            // the invalid cursor in place and repeat the recovery on every
            // sync, which is a worse failure than the one it would avoid.
            nextCursor = if (isFinalPage) {
                plan.candidateCursor.toByteArray(Charsets.UTF_8)
            } else {
                null
            },
            rescan = if (plan.isRecovery) {
                PlatformRescanWindow(
                    startMillis = plan.intervalStartMillis,
                    endMillis = plan.intervalEndMillis,
                    truncated = plan.rescanTruncated,
                )
            } else {
                null
            },
            unavailableReason = null,
            diagnostic = null,
        )
    }

    // -----------------------------------------------------------------------
    // Window arithmetic
    // -----------------------------------------------------------------------

    /** The interval a read covers, and the instant it may vouch through. */
    internal data class Window(
        val startMillis: Long,
        val endMillis: Long,
        val throughMillis: Long,
        val truncated: Boolean,
    )

    /**
     * `[rescanFloorMillis, now]`, clamped to `maxRescanWindowMillis`.
     *
     * `truncated` is set when the caller's floor is older than the clamp
     * allows. Steps in the unreachable gap are the core's problem to record and
     * never grant: they cannot be distinguished from steps already counted, and
     * inventing progress is worse than missing it. What the adapter owes is an
     * honest window, not a wider one.
     */
    private fun boundedWindow(request: PlatformSyncRequest, width: Long): Window {
        val now = source.nowMillis()
        val maxWindow = maxOf(request.maxRescanWindowMillis, width)
        val earliest = now - maxWindow
        val floor = request.rescanFloorMillis ?: earliest
        val truncated = floor < earliest

        // The read runs to the end of the bucket the clock is inside, so the
        // last few minutes of walking are delivered rather than held for an
        // hour. The ASSERTION stops at the boundary before it -- see
        // ReadPlan.throughMillis.
        val currentBucketStart = StepBucketing.bucketStart(now, width)
        val start = minOf(
            StepBucketing.bucketStart(maxOf(floor, earliest), width),
            currentBucketStart,
        )
        return Window(
            startMillis = start,
            endMillis = currentBucketStart + width,
            throughMillis = currentBucketStart,
            truncated = truncated,
        )
    }

    /**
     * The bucket-aligned span the upsertions touch, clamped into [bounds].
     *
     * Every bucket in it is restated, not only the ones a record landed in: a
     * record moved out of a bucket empties it, and an emptied bucket has to say
     * zero rather than say nothing.
     */
    private fun affectedInterval(
        upserts: List<RawStepRecord>,
        width: Long,
        bounds: Window,
    ): Window {
        var earliest = Long.MAX_VALUE
        var latest = Long.MIN_VALUE
        for (record in upserts) {
            earliest = minOf(earliest, record.startMillis)
            latest = maxOf(latest, maxOf(record.endMillis, record.startMillis + 1))
        }
        if (earliest == Long.MAX_VALUE) return bounds

        val start = maxOf(StepBucketing.bucketStart(earliest, width), bounds.startMillis)
        val end = minOf(StepBucketing.bucketStart(latest, width) + width, bounds.endMillis)
        if (end <= start) return bounds

        return Window(
            startMillis = start,
            endMillis = end,
            throughMillis = minOf(end, bounds.throughMillis),
            truncated = false,
        )
    }

    // -----------------------------------------------------------------------
    // Page construction
    // -----------------------------------------------------------------------

    private fun keyingResult(
        outcome: PlatformOriginKeyingOutcome,
    ): Result<PlatformOriginKeyingResult> = Result.success(
        // Never the salt, never a fingerprint of it, and never a source
        // identifier. There is nothing safe to say here, so nothing is said.
        PlatformOriginKeyingResult(outcome = outcome, diagnostic = null)
    )

    private fun <T> safely(block: () -> T): T? = try {
        block()
    } catch (_: Throwable) {
        null
    }

    private fun noChangePage(token: String): PlatformSyncPage = PlatformSyncPage(
        status = PlatformSyncStatus.NO_CHANGE,
        observations = emptyList(),
        completeness = emptyCompleteness(),
        pagination = PlatformPagination(pageIndex = 0L, isFinalPage = true, continuation = null),
        nextCursor = token.toByteArray(Charsets.UTF_8),
        rescan = null,
        unavailableReason = null,
        diagnostic = null,
    )

    companion object {
        /**
         * Must match `originKeyingAlgorithmVersion` in
         * `lib/src/origin_pseudonymizer.dart`.
         */
        const val ORIGIN_KEYING_ALGORITHM_VERSION = OriginKeying.ALGORITHM_VERSION

        /**
         * `TimeBucket.minimumWidthMillis` in the core, restated here because
         * the adapter clamps before it reads rather than being corrected after.
         */
        const val MINIMUM_BUCKET_WIDTH_MILLIS = 60L * 60L * 1000L

        /**
         * Slices per page.
         *
         * Bounds one Pigeon message rather than the read. Thirty days of hourly
         * buckets across four sources is under three thousand slices, so this
         * paginates in the ordinary case and is not a rare path that only runs
         * when something is already wrong.
         */
        const val MAX_OBSERVATIONS_PER_PAGE = 500

        private fun emptyCompleteness(): PlatformCompleteness = PlatformCompleteness(
            kind = PlatformCompletenessKind.PARTIAL,
            dataType = PlatformHealthDataType.STEPS,
            scope = PlatformOriginScope(
                kind = PlatformOriginScopeKind.SOME_ORIGINS,
                originKeys = emptyList(),
            ),
            intervalStartMillis = 0L,
            intervalEndMillis = 0L,
            queryGeneration = 0L,
            throughMillis = 0L,
        )

        /**
         * The answer when the adapter will not or cannot read.
         *
         * No cursor, no rescan, and PARTIAL completeness. Every one of those is
         * load-bearing: a cursor here would claim progress the ledger never
         * recorded, and any completeness assertion would settle buckets on the
         * strength of a read that never happened.
         */
        fun unavailablePage(reason: PlatformUnavailableReason): PlatformSyncPage =
            PlatformSyncPage(
                status = PlatformSyncStatus.UNAVAILABLE,
                observations = emptyList(),
                completeness = emptyCompleteness(),
                pagination = PlatformPagination(
                    pageIndex = 0L,
                    isFinalPage = true,
                    continuation = null,
                ),
                nextCursor = null,
                rescan = null,
                unavailableReason = reason,
                diagnostic = null,
            )
    }
}
