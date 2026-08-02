# Step Ledger — Persisted vs. Transient Data

**Authority:** `GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md`, `DECISIONS/0010`
**Task:** F-04
**Status:** ⚠️ **One narrowing of an existing rule needs owner ratification — see §5.**

---

## 1. The rule this document exists to honour

`GAME_BIBLE/HEALTH_INTEGRATION` says:

> Store only gameplay-relevant reconciliation state — ingested total, consumed total, sync anchor — **never a step history**.

and

> Raw health data never leaves the device. In any milestone.

F-04 keeps the second absolutely. It narrows the first, deliberately and in a bounded way, and §5 explains why and asks for that narrowing to be ratified rather than assumed.

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

### How it is bounded

Slices are compacted once they fall more than `StepReconciler.retentionWindowMillis` — **48 hours** — behind the newest observation:

- their granted amounts fold into `grantedBeforeWatermark`
- the watermark advances past them
- the individual entries are dropped
- a compacted slice can never be granted again, so forgetting the detail is safe

Steady-state size is roughly *(hours in 48) × (number of devices)* integer entries. For one phone at hourly resolution that is under fifty numbers.

Proven by `bounded retention` in `step_ledger_invariants_test.dart`: six days of syncs leave fewer than six slices retained, with `totalGranted` intact.

### Why 48 hours

Long enough to cover the realistic arrival window for delayed records and corrections — HealthKit and Health Connect both settle within hours, not days. Short enough that nothing resembling a diary accumulates.

**It is a judgement, not a derived number**, and it is stated as one. If real-device testing at S-01 shows corrections arriving later, it moves — it is one constant, and the tests assert the property rather than the value.

---

## 5. ⚠️ The narrowing that needs ratification

`GAME_BIBLE/HEALTH_INTEGRATION` says to store **"never a step history"**, and names the permitted state as *ingested total, consumed total, sync anchor*.

`grantedSlices` is more than that list. For up to 48 hours it holds per-device, per-hour granted amounts — which, while derived rather than raw, is close enough to a coarse recent step record that pretending otherwise would be dishonest.

### Why the alternative was not chosen

The scalar-only model — totals plus a watermark, no per-slice detail — stores strictly less. It is also unable to distinguish:

- a restated observation from a new one (breaks replay and overlap)
- one device's data from another's (breaks multi-device)
- which part of a rescan window was already granted (breaks bounded recovery without either double-granting or under-granting)

Each of those is a scenario the owner explicitly required. The scalar model can approximate them with a watermark and overlap arithmetic — the original hypothesis — but that approach assumes a window total stable enough for arithmetic over it to mean something, which retroactive writes and multiple origins undermine. §6 of the completion report compares them in full.

### What is being asked

Ratify one of:

1. **Keep `grantedSlices` at 48 hours** and amend `GAME_BIBLE/HEALTH_INTEGRATION` to permit bounded derived reconciliation state, naming this exception. *(Recommended — it is what makes the required scenarios provably safe.)*
2. **Shorten the window** to, say, 6 hours, accepting that corrections arriving later are silently under-granted.
3. **Revert to scalar-only**, accepting weaker multi-origin and recovery guarantees, and revise the affected scenarios.

Until ratified, this is recorded as a **known deviation**, not a settled decision.

---

## 6. What is never persisted, under any option

- Raw health samples
- Record identifiers or UIDs
- Precise sample timestamps
- Any data older than the retention window
- Anything at all outside the device — no cloud, no analytics, no crash reporting

`DECISIONS/0011` and the architecture plan §12 remain unchanged: raw health data never leaves the device, in any milestone.

---

## 7. Reset behaviour

`GAME_BIBLE/HEALTH_INTEGRATION` requires a visible disconnect-and-reset that clears health state while leaving gameplay progress intact.

The shape that satisfies it: clear `checkpoint`, `grantedSlices`, `recovery`, `sourceState`, and `totalObserved`; **keep `totalGranted`, `totalSpent`, and `grantedBeforeWatermark`**, because those are the player's earned progress rather than health data.

The reset command belongs with the settings surface and is **not implemented in F-04** — but the ledger is already shaped so that it is a field-clearing operation rather than a redesign.
