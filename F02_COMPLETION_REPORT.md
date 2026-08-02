# F-02 Completion Report — Content Schema, Loader, and Validation

**Date:** 2026-08-02
**Task:** F-02 — the platform-neutral content foundation
**Status:** ✅ **Complete.** 57 `stride_core` tests pass; 66 across the workspace.
**Review:** `DESIGN_REVIEW_F02.md` — approved with changes, all applied
**Scope held:** no health ingestion, no production UI, no combat simulation, no audio, no save state

---

## 1. Files created

### `packages/stride_core/lib/src/content/` — 9 files

| File | Purpose |
|---|---|
| `content_id.dart` | `ContentId` — namespaced, lowercase, globally unique, parsed with reasons |
| `schema_version.dart` | Supported-range checking; refuses to guess |
| `validation.dart` | `ValidationError`, `ValidationReport`, `ErrorCollector`, edit-distance suggestions |
| `json_reader.dart` | Field access that reports instead of throwing, so one bad entry does not hide twenty |
| `definitions.dart` | Item, skill, location, connection, resource node, recipe, ingredient, enemy, drop |
| `balance_profile.dart` | Profiles and `ReleaseSafety` |
| `content_registry.dart` | Validated, sorted, immutable registry |
| `content_loader.dart` | Deterministic loading and all cross-reference rules |
| `reachability.dart` | Progression-graph walk with diagnosis |

### `assets/content/v1/` — 7 content files plus a README

`skills.json`, `items.json`, `resource_nodes.json`, `locations.json`, `recipes.json`, `enemies.json`, `profiles.json`.

### Tests — 4 files, 57 tests

`content_test_support.dart`, `production_content_test.dart`, `broken_fixtures_test.dart`, `reachability_test.dart`, plus 17 fixtures in `test/fixtures/`.

### Tooling

`Scripts/generate-fixtures.js` — regenerates every fixture from production content with a single mutation.

---

## 2. Schemas created

Seven, each versioned and each rejecting unknown fields.

| Schema | Notable fields |
|---|---|
| **Item** | category, tier, slot, `toolKind`, power, healing, `qaOnly` |
| **Skill** | category, `maxLevel`, `xpThresholds` (cumulative, strictly increasing) |
| **Location** | `isSafe`, `isStart`, connections with step cost, `entryRequirements`, resource nodes |
| **Resource node** | skill, required level, **tool kind and minimum tier**, yield, step cost, XP |
| **Recipe** | skill, level, ingredients, output, XP |
| **Enemy** | location, health, attack, defence, `isBoss`, drops with whole-percent chance |
| **Balance profile** | four percentages and `releaseSafe`, and nothing else |

Two decisions inside the schemas are worth naming:

**Nodes require a tool *kind*, not a specific item.** A Bronze Axe satisfies any node a Training Axe satisfies, so adding a better tool does not mean editing every node.

**Drop chance is a whole percent, not a double.** Floating point in content invites values that differ between platforms, and the simulation is deterministic.

---

## 3. All validation rules

### Identifiers
1. Non-empty, lowercase, no spaces
2. Exactly one dot, separating a known namespace from a slug
3. Slug is `[a-z0-9_]`, starts with a letter, no doubled or trailing underscores
4. Namespace matches the field's expected type
5. **Globally unique** across the whole bundle, not merely within a file

### Structure
6. File is valid JSON and a JSON object
7. `schemaVersion` present, an integer, and within the supported range — **entries are not read at all against an unknown schema**
8. `kind` present and recognised
9. `entries` present and a list
10. Required fields present and correctly typed
11. Numeric fields within range
12. Enum fields within their allowed set
13. **Unknown fields rejected** — a typo'd optional field would otherwise be silently ignored

### Cross-references
14. Resource node → skill, → yielded item
15. Recipe → skill, → output item, → every ingredient item
16. Location → every connection target, → entry-requirement items, → resource nodes
17. Enemy → location, → every drop item
18. Starting loadout → every item

### Prohibited relationships
19. A recipe may not consume its own output
20. A location may not connect to itself

### Skills
21. Threshold count matches `maxLevel`
22. Level 1 requires 0 XP
23. Thresholds strictly increase

### World
24. Exactly one location is the start
25. Every gathered **material** has a consuming recipe

### Profiles
26. A production profile must exist
27. Production must be `releaseSafe`
28. Only production may be `releaseSafe`
29. Production must leave every percentage at 100
30. The requested profile must exist — the error lists what is available
31. Production content may not reference a `qaOnly` item
32. **A release build refuses a non-`releaseSafe` profile** (runtime, throws)

### Reachability
33. Every target obtainable from the granted loadout, with the block diagnosed

---

## 4. Representative content added

| | |
|---|---|
| **Skills** | Woodcutting, Mining, Foraging, Smithing, Cooking — all to level 20 |
| **Locations** | Haven's Rest (start, safe), Whispering Woods, Stonefall Mine, Forgotten Hollow (gated on a Bronze Sword) |
| **Starter gear** | Training Sword, Training Axe, Training Pickaxe, Traveler Tunic |
| **Raw resources** | Oak Log, Pine Log, Copper Ore, Tin Ore, Meadow Herb, Hollow Root |
| **Processed** | Oak Handle, Bronze Ingot, Pine Plank |
| **Bronze tier** | Sword, Axe, Pickaxe, Chestplate |
| **Consumables** | Herb Broth, Hearty Stew |
| **Quest** | Hollow Sigil — boss drop only |
| **Enemies** | Forest Wolf, Cave Goblin, Hollow Guardian |
| **Profiles** | `production`, `accelerated_qa` |

20 items, 5 skills, 4 locations, 6 nodes, 9 recipes, 3 enemies, 2 profiles.

**These numbers are not balance.** They are a plausible shape for the validator to chew on. `DECISIONS/0007`'s pacing targets are hypotheses to be tested against real walking data at S-06 and revised at V-04.

---

## 5. Broken fixtures exercised

17 fixtures. Every one is **generated from production content with a single mutation**, so a test breaks one rule against otherwise-real data.

| Fixture | Rule proven |
|---|---|
| `duplicate_id` | Duplicate ID |
| `invalid_id_syntax` | ID syntax |
| `unknown_item_reference` | Unknown item, plus "did you mean" |
| `unknown_skill_reference` | Unknown skill |
| `unknown_location_reference` | Unknown location, plus "did you mean" |
| `missing_ingredient_reference` | Missing ingredient reference |
| `unsupported_schema_version` | Schema too new |
| `malformed_schema_version` | Missing schema version |
| `missing_required_field` | Missing required field |
| `invalid_numerical_range` | Below minimum and above maximum |
| `prohibited_self_reference` | Recipe consuming its own output |
| `self_connected_location` | Location connected to itself |
| `unreachable_tool_bootstrap` | Unreachable starter chain |
| `production_uses_qa_value` | Production referencing QA-only content |
| `qa_profile_marked_release_safe` | QA profile marked shippable |
| `unknown_field` | Typo'd field name |
| `broken_xp_curve` | Non-increasing thresholds |

Every fixture also asserts the error is **actionable** — a source file, an explanation, and a fix. An error cannot regress into being unhelpful without failing a test.

### The fixture approach was wrong the first time

Fixtures began as hand-written stubs: a `resource_nodes.json` containing one node to break. Because a fixture *replaces* its production file, every entry it omitted vanished, and one broken skill reference cascaded into six unrelated "not defined" errors. The test still passed — it only asked whether the right message appeared somewhere in the noise.

The cascade test added at QA review caught it. Fixtures are now generated from production with one mutation, and no fixture produces more than five errors.

A fixture that tests a rule *and* accidentally deletes half the content is not testing the rule.

---

## 6. Reachability result

✅ **The player can reach Bronze from the granted loadout.**

The verified chain:

```text
granted:  Training Sword, Training Axe, Training Pickaxe, Traveler Tunic
          ↓
travel:   Haven's Rest → Whispering Woods, Stonefall Mine
gather:   Oak Log (training axe), Copper Ore + Tin Ore (training pickaxe)
craft:    Oak Handle, Bronze Ingot
craft:    Bronze Sword, Bronze Axe, Bronze Pickaxe
          ↓
travel:   Forgotten Hollow (requires the Bronze Sword)
gather:   Pine Log (bronze axe), Hollow Root
craft:    Pine Plank → Bronze Chestplate
```

All four locations are reachable. The Forgotten Hollow gate is a milestone, not a wall.

The validator also diagnoses each way this can break, proven by five tests on purpose-built graphs: tool-bootstrap deadlock, missing ingredient, circular dependency, resource gated behind its own output, unobtainable entry requirement, and nothing-produces-it.

**This is reachability, not balance.** Step costs, quantities, and skill levels are ignored — see §8.

---

## 7. Test count and exact results

```text
=== Core purity ===        core purity: OK (12 Dart files, 7 forbidden imports)
=== Dependency policy ===  dependency policy: OK (4 pubspec files)
=== Format ===             clean
=== stride_core ===        No issues found!   00:00 +57: All tests passed!
=== Workspace analyze ===  No issues found!
=== Flutter tests ===      00:00 +2: All tests passed!
=== stride_health tests === 00:00 +7: All tests passed!
All checks passed.
```

**57 `stride_core` tests** — 2 module, 3 step-provider contract, 4 purity, 9 production content, 4 determinism, 7 balance profile, 20 broken-fixture, 8 reachability.

**66 Dart tests across the workspace**, plus 5 Kotlin and 12 Swift in CI.

Runtime: under one second, on Windows, with no emulator, no simulator, and no Mac.

---

## 8. Unresolved questions

**Q1 — Reachability ignores quantity.** It asks whether an ingredient is *obtainable*, not whether enough of it is. A recipe needing 10,000 Copper Ore passes. Correct for F-02, since quantity is pacing and pacing is S-06 — but "reachable" is a weaker claim than a green test might suggest, and S-06 should add a *cost* projection alongside it.

**Q2 — `qaOnly` guards an empty room.** The flag works and a fixture exercises it, but no production item sets it and no QA-only content exists. The mechanism should exist before the first such item does; recorded so nobody mistakes the rule for coverage.

**Q3 — Bronze Axe and Bronze Pickaxe are mechanically identical.** Same ingredients, level, XP, and power. Defensible symmetry for a first tier, but the choice of which to craft first has no character. S-06.

**Q4 — Tin has exactly one use and one source.** Mining has two nodes that are really one activity with a ratio. Revisit when Milestone 02 adds Iron.

**Q5 — Where does content live at runtime?** Tests read `assets/content/v1/` with `dart:io`. The Flutter app will need a `ContentLoader` adapter over `rootBundle`, and the assets declared in `pubspec.yaml`. Small, and belongs to whichever task first needs content on a device.

**Q6 — No `activityKind` field yet.** `ActivityKind` exists as an enum and the terminating/repeating distinction is settled (review finding QA-1 of the Flutter review), but nothing in content carries it — travel is terminating and gathering is repeating by construction. If a repeating travel or terminating gather is ever wanted, it becomes a field. Not needed yet.

---

## 9. Recommended F-03 scope

> ### F-03 — `GameState`, events, and the engine entry point.

The task breakdown's F-03. Now unblocked: content gives the engine something to operate on.

### In scope

- **`GameState`** — immutable value type: player, steps, skills, inventory, equipment, world, activity, encounter slot, seeded RNG
- **Immutability enforced by test** — Dart gives none of Swift's value semantics for free, and a mutable list leaking into `GameState` would break save correctness far from its cause. Tracked as risk F-03i.
- **`GameEvent` catalogue** — the sole channel to audio, haptics, and the return summary
- **`PlayerIntent`** — the only way to change state
- **`GameEngine`** — `apply(intent)` and `ingest(steps)`, each returning events
- **Seeded RNG in state** — same state plus same intent gives the same result, every time
- **No clock** — timestamps enter as data, never read

### Explicitly out of scope

Reconciliation (S-02, after F-04's thirteen scenarios), save persistence (F-05), health ingestion, UI, combat resolution, audio.

### Recommended acceptance criteria

1. `GameState` is immutable and value-equal; a returned state cannot be mutated to affect the engine's own — asserted by test
2. Every mutation returns its events; no mutation is silent
3. The core reads no clock and draws no unseeded randomness
4. Identical state + identical intent ⇒ identical resulting state and identical event sequence, across 1,000 randomized cases
5. **Step consumption is not publicly callable** — steps are spent only through activity progression, with an invariant test that `stepsConsumed` never rises without a matching progress event *(review finding TD-1 of the original plan)*
6. `GameState` round-trips through JSON unchanged, so F-05 inherits a serializable object rather than retrofitting one
7. The engine is constructed from a `ContentRegistry` and holds no content of its own
8. `stride_core` purity holds; all four CI jobs stay green

---

## 10. Recommendation

**Approve F-02 and proceed to F-03.**

The content layer does what it was asked to: it is strict, it explains itself, it is deterministic, and it proves the game is playable from the loadout the player is actually given. Everything F-02 was told to stay out of, it stayed out of.

The one thing worth carrying forward is the fixture lesson. The first version of the broken fixtures passed while testing something other than what it claimed. It was caught by a test asking whether failures were *narrow*, not whether they happened — which is a question worth asking of every validator this project builds from here.
