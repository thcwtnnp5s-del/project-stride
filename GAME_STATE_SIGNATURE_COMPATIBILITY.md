# `GameState.signature` — compatibility analysis and disposition

**Status:** complete. The property has been removed; the analysis below is the
record of why removing it was safe.
**Raised by:** the S-01A fixture audit (Commit A), which found the signature
being used as whole-state unchanged-evidence in tests.
**Resolved by:** Commit A.1.

---

## Summary

`GameState.signature` was a hand-written summary string. It was **never
persisted**, in any form, anywhere. Its only production reader was the
save-repository's equal-generation divergence check — a fail-closed corruption
guard — and there it was **incomplete in a way that could silently discard a
player's progress**.

Because nothing stored it, there was no save-compatibility burden, no version
field to introduce, and no migration to perform. The mechanism was replaced
outright rather than extended.

---

## 1. Every writer

There was exactly one.

| Writer | Location | Kind |
|---|---|---|
| `GameState.signature` (getter) | `packages/stride_core/lib/src/engine/game_state.dart` | derived, computed on read |

It composed `StepLedger.signature` and formatted the player, inventory,
equipment, skills, world and event-sequence fields into a `;`-delimited string.

`StepLedger.signature` is a **separate, still-existing** property. It is
ledger-scoped and honestly named — it summarises the ledger for diagnostics and
`toString()` — and it is not used to decide anything. It is *also* incomplete
(no cursor, no per-origin watermarks, slice count only), which is exactly why it
must never be used as whole-state evidence; the tests that were doing so have
been migrated.

## 2. Every reader

| Reader | Location | Kind | Disposition |
|---|---|---|---|
| Equal-generation slot divergence | `save_repository.dart` step 3 | **production correctness** | replaced with `durableGameStatesEqual` |
| `GameState.toString()` | `game_state.dart` | diagnostic | now formats a short summary inline |
| ~44 test assertions | `stride_core/test`, `stride_health/test` | evidence | replaced with `canonicalDurableGameState` |

No other reader existed. No validator, no UI, no telemetry, no export.

## 3. Persistence

**Not persisted.** Verified by inspection of every save-writing path:

- `save_codec.dart` — `encodeGameState`, `encodeSnapshot`, `encodeEnvelope`
  never reference it.
- `journal_record.dart` — journal records carry events and a CRC32C digest,
  never a signature.
- No save-format field, header field, or envelope field holds it.

## 4. Corruption detection

**Yes — and this was the defect.**

Snapshot and journal integrity are independent of it: both use CRC32C over
canonical JSON, with the digest written outside the object it covers
(`journal_record.dart`). That mechanism is untouched by this work.

But `SaveRepository.load` step 3 used the signature to answer a different
question: *when two slots claim the same snapshot generation, have they
diverged?* The refusal is fail-closed by design — there is no principled way to
choose between two same-generation slots, and choosing wrong duplicates or
destroys a grant.

The signature could not answer it. It omitted:

- `checkpoint.cursor` — the durable sync position
- `checkpoint.originWatermarks` — the per-origin settled horizons
- the **contents** of `grantedSlices`; it carried only `slices=<count>`

So two slots differing in exactly those fields compared **equal**, the refusal
did not fire, and control fell through to a generation sort that is a tie —
selecting `verified.first`, an arbitrary slot.

**The failure this permits.** Pick the slot whose cursor is further along, and
the next sync resumes from a position the chosen ledger never granted. Every
step in the gap is unrecoverable, and nothing counts it: no completeness
assertion was violated, so no bucket settled early and `lateDiscardedSlices`
never fires. Divergent watermarks have the same shape — the further horizon
buries buckets the other slot would still have accepted. Same class as the
55,200-step defect, located in the corruption check rather than the bridge.

## 5. Behaviour of existing saves if the algorithm changes

**Unchanged, in every case.** Nothing on disk encodes the signature, so no
existing save file is read differently, re-validated differently, or made
unreadable. The value is derived from state already decoded.

The only behavioural change is at the equal-generation tie, and it is strictly
in the fail-closed direction: cases that previously compared equal and picked a
winner now refuse and leave both files intact for recovery. **No save that
loaded correctly before loads differently now** — a genuinely identical pair
still compares identical, which is pinned by test.

## 6. Signature version field

**None exists, and none is required.** A version field exists to let a reader
interpret a stored value written by a different writer. There is no stored
value.

## 7. Downgrade implications

**None.** Downgrade risk arises when a newer build writes a representation an
older build cannot read. No stored representation changes here: the save format,
the envelope, the journal record and the CRC32C scheme are all byte-identical
before and after.

An older binary reading a save written after this change sees exactly what it
would have seen before. This is a narrower and safer situation than the
`SourceState` enum note in `DECISIONS/0014`, where a new enum value genuinely
would be refused by an older binary — and where the project's position is that
**downgrade compatibility is not a guarantee it makes**. That position is
unchanged; it simply is not engaged by this change.

## 8. Migration and versioning options considered

| Option | Assessment |
|---|---|
| **A. Extend `GameState.signature` to cover the missing fields** | Rejected. It fixes today's omission and preserves the shape that caused it: a hand-maintained summary that must be *remembered* when a field is added, with nothing to make forgetting fail. |
| **B. Keep the signature, add a second complete comparison for the save path** | Rejected. Two mechanisms with overlapping names, one of them a trap. Every caller reads "signature" as "the whole state" — that assumption is the defect, and leaving the name in place preserves the invitation. |
| **C. Replace with canonical durable-state equality, remove the signature** | **Adopted.** |
| **D. Compare `GameState` structurally by field, in code** | Rejected. It is a second list of fields to maintain, and it fails in the same way as A the first time someone adds a field and does not update it. |

## 9. What replaced it

`packages/stride_core/lib/src/save/durable_state.dart`:

```dart
String canonicalDurableGameState(GameState state) =>
    canonicalJson(encodeGameState(state));

bool durableGameStatesEqual(GameState a, GameState b) =>
    canonicalDurableGameState(a) == canonicalDurableGameState(b);
```

Deliberately a function beside the codec, **not** a getter on `GameState`. A
convenience summary sitting where a complete comparison was assumed is what
caused the defect, and a property on the state object is what invited the
assumption.

**Why it is complete by construction rather than by maintenance:**

- it is the exact byte sequence a save file carries, so it cannot omit a durable
  field without the save also omitting it
- a new `GameState` field that is persisted joins the comparison automatically —
  there is no second list
- a new `GameState` field that is *not* persisted fails the codec's own
  round-trip tests, which is the correct place for that failure to appear
- ordering is not a hazard: the codec sorts object keys and sorts id-keyed
  collections, so two states built by different insertion orders encode
  identically. Pinned by test, not assumed.

## 10. Recommendation status

The recommendation of this analysis was option C, and the owner directed its
implementation in Commit A.1. It is done, with regression coverage for every
divergence case in `packages/stride_core/test/equal_generation_divergence_test.dart`,
including a mutation that reproduces the original blind spot and kills exactly
the three tests that name it.

**Not done, and not recommended for now:** changing `StepLedger.signature`. It
is honestly scoped to the ledger, is used only for diagnostics, and decides
nothing. Its incompleteness is only dangerous when it is mistaken for whole-state
evidence, and no remaining caller does that.
