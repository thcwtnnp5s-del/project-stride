# Content — schema v1

Authored game data for Project Stride. Loaded and validated by
`packages/stride_core/lib/src/content/`.

## Files

| File | Kind |
|---|---|
| `skills.json` | The five Milestone 01 skills and their XP curves |
| `items.json` | Starting gear, raw materials, processed components, Bronze tier, consumables |
| `resource_nodes.json` | What can be gathered, where, with what tool |
| `locations.json` | The four locations, the travel graph, entry requirements |
| `recipes.json` | Crafting |
| `enemies.json` | The three Milestone 01 enemies |
| `profiles.json` | `production` and `accelerated_qa` balance profiles |

## Rules

**Identifiers are permanent.** `item.oak_log` is written into saves and
cross-references. Renaming one after release breaks both. Display names are a
separate field and may change freely — nothing looks anything up by them.

**Every file declares `schemaVersion`.** The loader rejects versions it does not
support rather than guessing. See `SchemaVersion`.

**Numbers here are provisional.** The pacing targets in
`DECISIONS/0007_PROGRESSION_PACING.md` are hypotheses to be tested against real
walking data, not settled balance. Expect them to move at task S-06 and again
at V-04.

**No balance constant belongs in Dart.** If a number needs tuning, it lives here.

## Profiles

`production` leaves everything unscaled and is the only profile marked
`releaseSafe`. `accelerated_qa` compresses pacing for testing and can never ship
— a release build that selects it throws at load.

A profile may change only the four percentages. It has no vocabulary for adding
an item, changing a reference, or rewiring progression, because those live in a
layer it cannot reach.

## Validation

`dart test` in `packages/stride_core` validates this directory on every run:
duplicate IDs, ID syntax, unknown references, self-referencing recipes, XP curve
shape, orphan materials, profile rules, and a reachability walk proving the
player can get from the starting loadout to Bronze.

Broken fixtures live in `packages/stride_core/test/fixtures/` — one per rule,
each proving the validator actually catches it.
