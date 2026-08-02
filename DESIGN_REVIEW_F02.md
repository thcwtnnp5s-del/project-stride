# Design Review — F-02 Content Foundation

**Subject:** `packages/stride_core/lib/src/content/`, `assets/content/v1/`, and the F-02 test suite
**Date:** 2026-08-02
**Reviewers:** Creative Director, Systems Designer, Technical Director, Critic Agent, QA Director

## Outcome

> **Approved with changes.**

Nine findings. Seven are applied; two are recorded as open questions for F-03 because they need a decision the content layer cannot make alone.

The reviewers agree on the shape: the schemas are right, the validator is genuinely strict, and the reachability walk earns its place. The findings are mostly about content *judgement* — numbers and relationships that pass validation but say something unintended.

---

## Creative Director review

### Summary

The content reads like Project Stride rather than like a schema exercise, which was not guaranteed. Haven's Rest is safe and is the start; Forgotten Hollow is gated behind a Bronze Sword, so the first mini-boss sits behind preparation exactly as `COMBAT_PHILOSOPHY` asks. Two findings.

### Findings

**CD-1 — The Hollow Sigil is produced by a lumber recipe.** *(Applied.)*

`recipe.pine_plank_bundle` turns three Pine Logs into `item.hollow_sigil`, and the Hollow Guardian also drops it at 100%. So the game's one quest artifact — named for the boss, dropped by the boss — can also be knocked together out of firewood by a smith who has never been to the Hollow.

It validates cleanly. It is also nonsense, and exactly the kind of thing that survives when content is written to satisfy a validator rather than to mean something. The Sigil should be the *proof* the player beat the Guardian.

*Change:* the recipe now produces `item.pine_plank` — a real processed material — and the Sigil is boss-drop only.

**CD-2 — Nothing consumed Pine Logs but that recipe.** *(Applied, follows from CD-1.)*

Pine sat at the end of a chain whose only purpose was to feed the Sigil. With the Sigil removed, Pine needs a genuine use or it is Woodcutting content that leads nowhere — the "material with no purpose is busywork" rule the validator already enforces for orphans.

*Change:* Pine Plank feeds Bronze Chestplate, giving the tier-1 gathering node a tier-1 destination.

### Recommendation

Approve with CD-1 and CD-2 applied.

---

## Systems Designer review

### Summary

The economy holds together: three gathering skills feed two production skills, and every raw material has a consumer. Two findings about relationships the schema permits but the design does not want.

### Findings

**SD-1 — Bronze Axe and Bronze Pickaxe are identical.** *(Recorded, not changed.)*

Same ingredients, same level, same XP, same power. They differ only in `toolKind`. That is defensible for a first tier — symmetry is easy to read — but it means the choice of which to craft first is a pure resource-timing decision with no character to it.

*Response:* left as-is for F-02. This is a balance judgement and belongs to S-06, which owns the numbers. Flagged there.

**SD-2 — Tin has one use and one source.** *(Recorded.)*

`item.tin_ore` exists solely to make Bronze Ingots. That is historically apt and mechanically fine, but it means Mining has two nodes that are really one activity with a ratio. Worth revisiting when Milestone 02 adds Iron.

### Recommendation

Approve. Both findings are pacing questions, correctly deferred to S-06 rather than settled by a schema.

---

## Technical Director review

### Summary

The architecture is right: `ContentSource` takes text rather than a directory, which keeps `dart:io` out of the core, makes the loader trivially testable, and removes file-enumeration order as a variable by construction rather than by discipline. Two findings.

**TD-1 — Reachability ran even when the profile was missing.** *(Applied.)*

The loader returned early on validation errors, but the ordering meant a bundle with an unknown profile could still reach the reachability walk with a null profile, producing a confusing second failure on top of the real one.

*Change:* the profile check now short-circuits before registry construction, so one root cause produces one error.

**TD-2 — `_dependsOn` shares its `seen` set across sibling branches.** *(Applied.)*

The recursive dependency walk passed one mutable `seen` set down every branch. A diamond-shaped recipe graph — two ingredients that both lead to the same base material — would mark the shared node visited on the first branch and return `false` on the second, under-reporting a real cycle.

Not currently reachable with the production content, which has no diamonds. It would have become reachable the moment someone added one, and it would have failed silently by *passing*.

*Change:* each branch now gets its own set.

### Recommendation

Approve with TD-1 and TD-2 applied. TD-2 is the one I would have most regretted missing.

---

## QA Director review

### Summary

Seventeen broken fixtures against thirteen required rules, each asserting the specific message rather than merely that something failed. `expectActionable` on every fixture is the detail I would have asked for: it means an error cannot regress into being unhelpful without failing a test. Two findings.

**QA-1 — The "missing ingredient reference" fixture asserted too loosely.** *(Applied.)*

It checked `reports(report, 'item')`, which matches nearly any error mentioning an item. The fixture would have passed against a completely different failure.

*Change:* now asserts on `the required field "item" is missing`.

**QA-2 — Nothing tested that a valid bundle rejects nothing.** *(Applied.)*

Every fixture proves the validator fires. Nothing proved it *doesn't* fire spuriously — a validator that rejected everything would pass the entire fixture suite.

*Change:* added a test asserting production content produces exactly zero errors, and that each fixture's error count is small and bounded rather than a cascade.

### Recommendation

Approve with QA-1 and QA-2 applied.

---

## Critic Agent review

### Summary

Scope held. No health ingestion, no UI, no combat simulation, no audio, no save state — the five things F-02 was told to stay out of, and it stayed out of all five. Content is data; the loader reads it and validates it and does nothing else.

### Findings

**CR-1 — `qaOnly` is a rule with no content behind it.** *(Recorded as an open question.)*

The flag exists, the validation rule works, and one fixture exercises it — but no production item sets it, and no QA-only content exists. The rule is currently a guard around an empty room.

That is not wrong: the mechanism should exist before the first QA-only item does, and building it after would mean the first such item ships unguarded. But it is worth saying plainly rather than implying coverage that has no subject yet.

**CR-2 — The reachability walk ignores quantities.** *(Recorded as an open question.)*

It asks whether an ingredient is *obtainable*, not whether enough of it is. A recipe needing 10,000 Copper Ore passes.

For F-02 that is correct — quantity is pacing, and pacing is S-06. But it means "reachable" is a weaker claim than a casual reader might assume, and the report should say so rather than let the green test imply more than it proves.

**CR-3 — The Forgotten Hollow gate is the first genuinely load-bearing content decision.** *(Observation, no change.)*

Requiring a Bronze Sword to enter means the whole Bronze chain is mandatory, not optional. That is a real design commitment made in a JSON file, and it is the right one — it makes the crafting loop the path to the boss rather than a side activity. Worth noticing that it happened here rather than in a design document.

### What I checked and found clean

- No deferred vocabulary anywhere in content — no expedition, profession, adventure momentum, currency, merchant, or combat skill. Verified by grep and by the build-failing guard.
- No orphan items: every item is referenced by a node, recipe, location, enemy, or the starting loadout.
- Traveler equipment is granted and appears in no recipe, per `DECISIONS/0004`.
- The production profile leaves everything at 100, so base content is the single source of truth for real numbers.
- The QA profile can only change four percentages — it has no vocabulary for touching IDs, references, or topology.

### Recommendation

**Approve.** CR-1 and CR-2 belong in the completion report's unresolved questions, not in the code.

---

## Consolidated changes

| ID | Change | Status |
|---|---|---|
| CD-1 | Hollow Sigil is boss-drop only; recipe produces Pine Plank | Applied |
| CD-2 | Pine Plank feeds Bronze Chestplate | Applied |
| TD-1 | Missing profile short-circuits before reachability | Applied |
| TD-2 | `_dependsOn` gets a fresh `seen` set per branch | Applied |
| QA-1 | Ingredient fixture asserts the specific message | Applied |
| QA-2 | Test that valid content produces zero errors | Applied |
| SD-1 | Bronze tool symmetry | Deferred to S-06 |
| SD-2 | Tin's single use | Deferred to Milestone 02 |
| CR-1, CR-2 | `qaOnly` has no subject; reachability ignores quantity | Recorded as open questions |

## Follow-up

No further review required before F-03. The two deferred findings are pacing questions that belong to the task that owns pacing.
