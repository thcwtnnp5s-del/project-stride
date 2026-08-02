# Apple Health Design

## Initial metric

Step count only.

## Privacy principles

- Request only required permissions
- Explain how step data affects gameplay
- **Raw health data never leaves the device.** In any milestone. Changing this requires an explicit new owner decision.
- Store the minimum reconciliation state that safety requires — see the amendment below
- Provide a clear disconnect/reset path
- Never imply medical interpretation
- No analytics and no third-party SDKs in the app target for Milestone 01

### Amendment — bounded reconciliation history (owner ruling, 2026-08-02)

This document previously said to store *"ingested total, consumed total, sync anchor — never a step history."* That wording is amended.

The reconciler additionally persists **`grantedSlices`**: per pseudonymous origin and per UTC time bucket, the number of steps already granted.

**This is coarse recent reconciliation history, and is described as such.** It is not "not a history" — calling it that would be a word game. It is retained *only* because safe replay, overlap handling, multi-origin reconciliation, and bounded recovery require it; the scalar-only alternative cannot distinguish a restated observation from a new one.

**Persist only:** pseudonymous origin identifier, UTC time bucket, amount already granted for that bucket, and minimum schema metadata.

**Never persist:** raw HealthKit or Health Connect records, sub-bucket exact timestamps, device names, source display names, workout categories, location, heart data, or original native payloads.

**Retention:** 7 days by default, 48 hours minimum, provisional until S-01 measures real correction latency. After the window, slices are removed and compacted into non-temporal cumulative totals only. **No indefinite bucket-by-bucket activity timeline is ever retained.**

**Locality:** no telemetry, no plaintext diagnostic logging, no routine diagnostic export, no automatic inclusion in any future cloud sync, and the Android backup and transfer exclusions stand.

Full detail and rationale: `TECHNICAL/STEP_LEDGER_PRIVACY.md`.

## Step reconciliation

The implementation must track:

- Source step totals
- Last successful sync
- Steps already consumed by the game
- Corrections or delayed data updates
- Time-zone and day-boundary behavior

The system must prevent both double counting and lost legitimate progress.

### Ledger model

Steps are a ledger, not a daily budget. The save holds two monotonic counters — `stepsIngested` and `stepsConsumed` — and available steps are the difference. Both only ever increase.

**There are no day boundaries and no timezone logic.** This removes an entire class of bugs: travel, daylight saving, midnight, and retroactive Health writes all become non-events.

### Corrections must never claw back progress

If a Health correction reduces the ingested total below what has already been consumed, the game records the discrepancy and absorbs it against future ingestion. Granted progress is never revoked. The player must never watch progress disappear — this is a direct application of the no-punishment non-negotiable.

### Step authenticity

Manually-entered Health samples (`HKMetadataKeyWasUserEntered`) are **filtered out by default**, with a visible setting to include them. The default should reflect real movement; the choice belongs to the player, since Milestone 01 has no leaderboards and no competition. Revisit if a social layer is ever added.

The developer/simulated provider sits behind a debug build flag and never ships.

## Future provider model

Use a provider abstraction that can later support:

- Health Connect
- Manual test provider
- Import provider
- Other integrations where justified
