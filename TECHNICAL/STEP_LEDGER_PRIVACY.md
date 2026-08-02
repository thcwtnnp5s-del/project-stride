# Step Ledger — Persisted vs. Transient Data

**Authority:** owner ruling of 2026-08-02, amending `GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md`
**Tasks:** F-04, F-05
**Status:** ✅ **Approved as a documented exception.**

---

## 1. What is persisted, said plainly

`GAME_BIBLE/HEALTH_INTEGRATION` originally said to persist only *"ingested total, consumed total, sync anchor"* and **"never a step history"**.

That wording is amended. The ledger additionally persists `grantedSlices`.

> **`grantedSlices` is coarse recent reconciliation history.**
>
> It is not "not history". Calling it that would be a word game. It records, per pseudonymous origin and per UTC time bucket, how many steps the game has already granted — which is a coarse recent record of when the player was active.
>
> It is retained **only** because safe replay, overlap handling, multi-origin reconciliation, and bounded recovery require it. Without it the reconciler cannot distinguish a restated observation from a new one, and four of the thirteen required scenarios become approximations.
>
> It is bounded, compacted, and never leaves the device.

`Raw health data never leaves the device, in any milestone` is unchanged and absolute.

---

## 2. Transient — processed, never stored

These are read from a provider response, used within a single reconciliation, and discarded when it returns.

| Data | Used for | Lifetime |
|---|---|---|
| Raw per-record step samples | Aggregated by the adapter into `(origin, bucket)` observations before they reach the core | Never enters `stride_core` |
| Record identifiers / UIDs | Available to an adapter for de-duplication within one read | Adapter only; never crosses the boundary |
| Precise sample timestamps | Collapsed into a `TimeBucket` by the adapter | Not persisted |
| `SyncResponse` and its observations | The reconciliation itself | The duration of one `reconcile` call |
| Rescan window bounds | Deciding what a recovery covers | Recorded only as a truncation *count*, not the window |

**No raw health history is ever handed to the core, and nothing the core receives is stored verbatim.**

---

## 3. Persisted — and why each field is required

| Field | Why it must persist | Bound |
|---|---|---|
| `totalObserved` | Lets the game explain a divergence from the Health app instead of appearing to have lost data | One integer |
| `totalGranted` | The player's earned progress. Losing it loses the game | One integer |
| `totalSpent` | What has been committed to activities | One integer |
| `grantedBeforeWatermark` | Keeps `totalGranted` reconstructable after slices are compacted, so compaction never loses credit | One integer |
| `checkpoint.cursor` | Opaque platform anchor/token. Without it every sync re-reads everything | Small byte array |
| `checkpoint.watermarkMillis` | Marks the point before which nothing can be granted again | One integer |
| `checkpoint.syncCount` | Distinguishes a repeated reconciliation from one that never happened, **without needing a clock** | One integer |
| `recovery` | Tells a retry whether a recovery began and never finished | Small enum + two integers |
| `sourceState` | Lets the UI explain itself calmly when health is unavailable | One enum |
| `correctionsObserved`, `unreachableGapEvents` | Diagnostic counters, so "why does the game say more than Health does?" has an answer | Two integers |
| **`grantedSlices`** | **The one non-trivial entry — see §4 and §5** | Bounded, see below |

---

## 4. `grantedSlices` — what it is

A map from `(origin, bucket)` to **the number of steps already granted for that slice**.

It is what makes replay, overlap, delayed records, corrections, deletions, multi-device sync, and bounded recovery all safe through one arithmetic rule rather than six special cases. Without it, the reconciler cannot tell a restated observation from a new one, and every scenario that depends on that distinction becomes guesswork.

### What it is not

It is **not** a record of steps taken. It records **what the game credited**, which diverges from what the source says the moment a correction arrives — that divergence is the entire point of separating observed from granted.

### Exactly what a slice may contain

Per the ruling, a persisted slice carries **only**:

| Field | |
|---|---|
| Pseudonymous origin identifier | Opaque string. **Never** a device name, source display name, or anything a human would recognise |
| UTC time bucket | Start and end, milliseconds since epoch. **UTC exclusively** — no local calendar anywhere |
| Amount already granted for that bucket | An integer |
| Minimum schema/version metadata | Enough to decode it |

**Never persisted, under any circumstance:** raw HealthKit or Health Connect records, sub-bucket exact timestamps, device names, source display names, workout categories, location, heart data, or original native payloads.

### How it is bounded

Slices are compacted once they fall more than `StepReconciler.retentionWindowMillis` behind the newest observation.

| | |
|---|---|
| **Default retention** | **7 days** |
| **Configurable minimum** | **48 hours** — a hard floor; a shorter window throws |
| Production value | **Provisional** until S-01 measures real delayed corrections and provider behaviour |

After the active window: time-bucket slices are **removed**, and compaction folds them into **non-temporal cumulative totals** — `grantedBeforeWatermark` and the watermark — which carry no timing information at all.

**No indefinite bucket-by-bucket activity timeline is ever retained.** That is the line the retention window exists to hold.

- their granted amounts fold into `grantedBeforeWatermark`
- the watermark advances past them
- the individual entries are dropped
- a compacted slice can never be granted again, so forgetting the detail is safe

Steady-state size is roughly *(hours in the window) × (number of devices)* integer entries.

Proven by `bounded retention` in `step_ledger_invariants_test.dart`: fourteen days of syncs leave fewer than fourteen slices retained, with `totalGranted` intact, and a long-settled slice restated by a rescan grants nothing.

### Why these numbers

**7 days** is long enough to cover realistic delayed-record and correction latency with margin. **48 hours** is a floor rather than a target: a shorter window trades a privacy gain nobody asked for against a correctness loss that is invisible until a player's walk fails to count. `StepReconciler` throws below it.

**Both are judgements, not derivations.** If S-01 shows corrections arriving later than 7 days, the default moves — it is one constant, and the tests assert the property rather than the value.

---

## 5. Locality — this data never leaves the device

Required by the ruling, and absolute:

| | |
|---|---|
| Telemetry | **None.** No analytics SDK, no crash reporter |
| Plaintext diagnostic logging | **None.** Slice detail is redacted from every diagnostic surface |
| Routine diagnostic export | **None** |
| Automatic cloud-sync inclusion | **None.** A future sync layer must exclude this explicitly, not inherit it |
| Android backup and transfer | **Excluded**, and those exclusions are retained — see `android/app/src/main/res/xml/data_extraction_rules.xml` |

The Android exclusion matters more than it looks: an automatic backup restored onto a second device would replay a step ledger against a source the original already consumed from, producing exactly the double-count the whole design exists to prevent.

---

## 6. Never persisted, under any configuration

- Raw HealthKit or Health Connect records
- Original native payloads
- Record identifiers or UIDs
- Sub-bucket exact timestamps
- Device names or source display names
- Workout categories, location, heart data
- Any local-calendar or timezone-derived value — **UTC exclusively**
- Any slice older than the retention window
- Anything at all outside the device

`DECISIONS/0011` and architecture plan §12 are unchanged: raw health data never leaves the device, in any milestone.

---

## 7. Reset behaviour

`GAME_BIBLE/HEALTH_INTEGRATION` requires a visible disconnect-and-reset that clears health state while leaving gameplay progress intact.

The shape that satisfies it: clear `checkpoint`, `grantedSlices`, `recovery`, `sourceState`, and `totalObserved`; **keep `totalGranted`, `totalSpent`, and `grantedBeforeWatermark`**, because those are the player's earned progress rather than health data.

The reset command belongs with the settings surface and is **not implemented in F-04** — but the ledger is already shaped so that it is a field-clearing operation rather than a redesign.
