# S-01A — Physical iPhone Validation Report

**Result: PASS.** The S-01A foreground-health vertical slice ran on the owner's
real iPhone, against real HealthKit data, and behaved correctly.

This is the evidence category nothing else could produce. Every line touching
`HKHealthStore` was unverified by any suite — an authorization prompt cannot be
answered on a CI runner, a simulator holds no real step samples, and no
fabricated reading exercises anchored-query drain behaviour against a real
device's sample volume.

---

## Device and signing

| | |
|---|---|
| Hardware | The owner's real iPhone |
| Signing | Free Apple **Personal Team** — no paid membership |
| HealthKit availability | `available` |
| Steps permission | `granted` |

Personal Team signing was sufficient, as
`S01A_IOS_READINESS.md` predicted. The Apple Developer Program was never
required and TestFlight stayed out of scope.

---

## The run

### 1. Install over the existing app — state preserved

The fix was installed **over** the first-run save rather than onto a clean
device. That was deliberate: the save carried the first real HealthKit
reconciliation and was the evidence that the earlier cursor defect had been
inert.

| Figure | Value |
|---|---|
| Granted | 407,105 |
| Spent | 0 |
| Usable | 407,105 |
| Cursor | present |
| Save | in sync |

Nothing was lost across the reinstall.

### 2. First sync after the cursor fix — **zero faults**

| Field | Value |
|---|---|
| Status | `reconciled` |
| Delivery kind | `incremental` |
| Pages | **1** |
| Origins | 2 |
| UTC buckets | 721 |
| Observed steps | 404,173 |
| Newly granted | **961** |
| **Faults** | **none** |
| Syncs committed | 9 |
| Cursor | present |
| Save | in sync |

This is the assertion the whole fix existed for. The previous run reported
seven `cursorOfferedWhenProhibited` faults across eight pages; this one reports
none.

Resulting state: granted **408,066**, spent 0, usable **408,066** — the
preserved 407,105 plus the 961 newly granted, exactly.

### 3. Gather — energy actually buys something

One **Gather Meadow Herb**:

| Field | Value |
|---|---|
| Cost | 90 energy |
| Reward | 2 × Meadow Herb |
| Granted after | 408,066 |
| Spent after | **90** |
| Usable after | **407,976** |
| Held | 2 × Meadow Herb |

Granted did not move; spent absorbed the cost. Those are separate figures for
exactly this reason.

### 4. Force-close and relaunch — persistence holds

Force-closed and relaunched through Xcode. Persisted correctly:

| Figure | Value |
|---|---|
| Granted | 408,066 |
| Spent | 90 |
| Usable | 407,976 |
| Meadow Herb | 2 |

### 5. Final sync — duplicate protection

| Field | Value |
|---|---|
| Status | `noChange` |
| Delivery kind | `noChange` |
| Pages | 1 |
| Query interval | not asserted |
| Origins | 0 |
| UTC buckets | 0 |
| Observed steps | 0 |
| Newly granted | **0** |
| **Faults** | **none** |
| Syncs committed | 10 |
| Cursor | present |
| Save | in sync |
| Backup exclusion | clean |
| Identity storage | keychain |

A no-change page asserts no completeness and settles nothing, and it is still
entitled to advance the cursor — the documented exception in
`cursor_authorization.dart`. It behaved as specified: cursor present, nothing
granted, nothing lost.

---

## What this proves

- **The cursor defect is fixed on real hardware.** Zero faults across two real
  syncs, where the pre-fix run produced seven.
- **No duplicate energy was granted.** A second sync over the same window
  credited nothing.
- **Real HealthKit reads work** — two origins, 721 UTC buckets, hundreds of
  thousands of real steps, reconciled without a fault.
- **Gathering spends what it says it spends**, and spends it from `spent` rather
  than by reducing `granted`.
- **The save survives force-close and relaunch** with every figure and the
  inventory intact.
- **Privacy holds on device**: backup exclusion clean, identity in the Keychain,
  origins reported as a count, cursor reported as present/absent. No bundle
  identifier, device name, salt, origin-key byte or anchor content appeared on
  screen, in the console, or in the save.

## What this does not prove

Recorded so no later reader mistakes the scope of a passing run:

- **Background synchronization** — never started, out of scope, S-01B.
- **Deletion escalation** — no deletion occurred during validation, so the
  `HKDeletedObject` rescan path remains unexercised on hardware.
- **Cursor invalidation / recovery** — no invalidation occurred, so the bounded
  authoritative rescan is still simulator-and-unit-test evidence only.
- **Multi-page delivery post-fix** — this sync drained in one page. The
  eight-page case is covered by the Swift and Dart regression tests, and by the
  pre-fix device run that produced the eight-page delivery in the first place.
- **iCloud restore onto a second device** — the `ThisDeviceOnly` Keychain
  control still needs two iPhones and an iCloud account.
- **Denied permission on hardware** — permission was granted throughout.

---

## The defect this run closed

The first physical sync reported seven `cursorOfferedWhenProhibited` faults
across eight pages. `HKAnchoredObjectQuery` returns one anchor per page;
`HealthKitStepStore` assigned it to both the continuation and the candidate
cursor, and `HealthKitAdapter.map` forwarded it as `nextCursor` without
consulting `isFinalPage` — the only one of that page's three outbound fields
that was not gated on it.

Nothing durable ever moved: `authorizeCursor` refused all seven, the bridge
dropped them and raised the fault, and only the eighth cursor reached the save.
The save was never reset, and this run resumed from it.

Fixed in `5b68d33`. Regression coverage in
`packages/stride_health/example/ios/RunnerTests/RunnerTests.swift` and
`packages/stride_health/test/multi_page_cursor_regression_test.dart`.

**No save-format change and no migration** was involved at any point.
