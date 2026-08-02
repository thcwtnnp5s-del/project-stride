# 0012 — Save format and durability model

**Status:** Approved
**Date:** 2026-08-02
**Authority:** Owner rulings of 2026-08-02 (four design rulings, cursor authority, completeness contract, origin privacy, late data)
**Supersedes:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §4.1's temp-file-plus-rename snapshot
**Task:** F-05

---

## Decision

Local save state is held in **two ping-pong snapshot slots plus a bounded write-ahead journal**, with optimistic compare-and-swap on every commit.

This record exists because three of its parts are the kind of thing that gets "simplified" later by someone who does not know why they were there.

---

## 1. Two slots, not temp-file-plus-rename

`save_slot_a` and `save_slot_b`. Each complete slot carries a monotonic generation, save format version, last applied journal transaction, an integrity digest, the payload, and an internally-validated commit-complete marker.

**Why not rename.** The approved plan said temp file plus atomic replace. From Dart there is **no way to fsync a directory**, so a rename is not durably ordered against the file's contents. On some storage stacks a crash immediately after a rename can leave the directory entry unpersisted, or the entry persisted and the content not. Rename atomicity is a promise we cannot verify from where we stand.

Ping-pong obtains atomicity by **never overwriting the live copy**. An interrupted write can only damage a slot that was already superseded. This is a property of the protocol, not of the filesystem.

**Protocol:** identify the newest valid slot → write to the older or invalid one → flush → read back and validate the full envelope → leave the previous valid slot untouched → on restart, load the highest-generation valid slot.

**No current-slot pointer is required for correctness.** If one is ever added as a hint, recovery must ignore it when stale or corrupt — a pointer that recovery trusts is a third thing that can be wrong.

**Equal generations with different valid contents fail closed.** There is no principled way to choose, and choosing wrong either duplicates or destroys a grant.

Cost: about 5 KB and one extra read at launch. **If someone later proposes collapsing this to a single file plus rename, this section is the answer.**

## 2. Compare-and-swap, because a mutex is not enough

Every transaction carries `expectedSnapshotGeneration` and `expectedLastAppliedTransaction`, and commits only if durable state still matches. On conflict: nothing partial is written, the caller reloads, reconciles against the newer state, and retries through a bounded coordinator; past the limit it gets a typed conflict result.

A single-writer queue also serializes within one process. **It is explicitly not treated as sufficient by itself.** Health Connect background delivery can run in a separate worker, and an in-memory mutex in one isolate says nothing about another. That failure double-grants, and it will not reproduce on a developer's machine.

Actual Android background-worker integration is out of scope for F-05 and lands in S-01.

## 3. The journal is a recovery log, not an event store

Records are retained only until their grant is represented in a **verified** snapshot and compaction is safe. The floor is the older of two verified snapshots, and compaction is refused outright when fewer than two verify.

**This is a privacy control, not a size optimization.** `StepObservationReconciled` carries the full granted-slice map. An uncompacted journal is a permanent, unbounded step history — exactly what the retention ruling bounds, reintroduced through the back door.

After compaction, only minimal redacted diagnostic metadata may be kept: transaction id, generation, outcome or recovery code, aggregate counters, integrity result. Never raw observations, device names, native records, or an indefinite reconciliation history.

**The cost, accepted deliberately:** no post-hoc debugging of a reconciliation defect from a player's device, and no history to reconstruct an away-summary from. The alternative — an event store with health fields redacted at compaction — needs a redaction mechanism that must itself be correct, and a redaction bug is the quietest possible privacy failure.

## 4. Profile authority

The save's stored `balanceProfileId` is **authoritative**, regardless of the app's current default. Production saves load with production. Unknown profiles fail closed. Release builds hard-refuse `accelerated_qa` saves. Development builds load `accelerated_qa` only through explicit developer configuration. Changing an existing save's profile requires an explicit migration or a new game.

**A save is never silently reinterpreted under another profile.** That is how compressed QA pacing reaches a production character, and it is invisible afterwards.

Typed outcomes: `unknownProfile`, `qaProfileForbiddenInRelease`, `profileMigrationRequired`.

## 5. Cursor authority

**The validated snapshot is the sole durable authority for the provider cursor or token.**

This holds structurally rather than by discipline: `SyncCheckpoint.cursor` lives inside `StepLedger` inside `GameState`, and a whole batch is one journal record — so the cursor and the grant that authorized it are *the same bytes*. There is no durable state in which one advanced and the other did not.

Native adapters **may** hold a cursor transiently during one operation. They **must not** independently persist or advance it, and **must not** cache a newer cursor outside the committed snapshot.

The reason this is a decision record and not a comment: caching the HealthKit anchor in `NSUserDefaults` or the Health Connect token in `SharedPreferences` is the *natural* thing for an adapter author to do, and it looks like an optimization. It decouples cursor from ledger, so a snapshot fallback rolls back the grants but not the cursor, and everything between them becomes permanently unrecoverable.

## 6. Integrity is CRC-32C, not a cryptographic hash

The threat is **corruption, not tampering**. The save is in app-private storage on the player's own device, there is no server, and any digest we compute a save editor can recompute. Adding `package:crypto` — to a package whose value proposition is having two dependencies — for tamper-evidence we cannot enforce is the wrong trade.

CRC-32C detects all single-bit errors, all burst errors up to 32 bits, and, with the explicit length in the frame, every truncation. That is the real failure set: interrupted writes, flash bit-rot, and bugs in our own encoder.

**Never `Object.hashAll` or `String.hashCode`** — Dart hash codes are not stable across VM versions or between JIT and AOT, so a save written by a debug build would fail to verify in release.

Revisit if informal comparison between players ever becomes a feature.

## 7. Structural keys, and an origin type that cannot hold a name

`ObservationKey` serializes as separate fields, never as `toString()`. A composite string can split on a separator or merge after normalization; a split key re-grants a whole window, a merged one silently under-grants a real second device.

`StepOriginKey` accepts only sixteen lowercase hex characters or the reserved literal `unknown`. A device name is **not a representable value** — the privacy rule is enforced by the type system rather than by review. `OriginPseudonymizer` in `stride_health` is the only thing that can produce a key, and it is the only place a raw platform identifier exists in Dart.

**Pseudonymization salt loss** re-keys every origin, so recent buckets look ungranted and would be granted a second time — a double-grant bounded by the retention window. The save therefore records a salt fingerprint, and a load that cannot reproduce it fails closed rather than guessing. Refusing is recoverable: the player can be offered a health reconnect, which clears health state and keeps earned progress. A silent double-grant is not recoverable, because nothing detects it.

---

## Three version axes, deliberately separate

| Axis | Governs | On mismatch |
|---|---|---|
| `saveFormatVersion` | Framing, envelope shape, journal record shape | Refuse a future format before decoding anything |
| `gameStateVersion` | The `GameState` object shape | Direct decoder per version |
| `contentSchemaVersion` | The content pack | **No decoder** — content is reloaded from assets, so a schema bump is validated, never migrated |

**Decoding fans in; encoding does not fan out.** There is exactly one encoder, for the current state version. A build never writes an old format.

**A direct decoder per version, not a v0→v1→v2 chain.** With a handful of versions a chain means every old shape stays materialisable forever, and each hop is somewhere a defect compounds quietly. Chaining wins only at dozens of versions; revisit then, behind the same interface.

---

## Consequences

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §4.1 is amended: the snapshot is two slots, not temp-plus-rename.
- Frozen fixtures are never regenerated. When `StateVersion.current` becomes 2, `v1_baseline.save` stays as it is, a v2 decoder is added, and v1's round-trip test becomes decode-only.
- S-01 inherits: the native adapters must not persist cursors, and background-worker concurrency must be reconciled against the CAS contract rather than assumed safe.
