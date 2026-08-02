# Glossary

## Activity
A selected gameplay process such as woodcutting, mining, travel, crafting, or expedition progress.

## Adventure
The player’s overall journey through progression, discovery, combat, and exploration.

## Adventure Momentum
Working term for movement-derived opportunity. **Deferred vocabulary — Milestone 02+.** Must not appear in Milestone 01 code, content schemas, or UI.

## Destination
A specific place within a region, such as a town, mine, forest, camp, or dungeon.

## Encounter
A focused active gameplay event, usually combat, discovery, or a meaningful choice.

## Expedition
A planned journey or activity involving preparation, movement, and outcomes. **Deferred concept — Milestone 02+.** Travel and gathering cover Milestone 01; Expedition must not be implemented as a distinct system in the vertical slice.

## Idle progression
Asynchronous planning, offline step reconciliation, and delayed collection. The player selects a goal, walks their ordinary life with the app closed, and collects the outcome on their next launch.

Idle progression is **not** passive wall-clock accrual. Nothing advances from time alone. See `DECISIONS/0001_PROGRESSION_CLOCK.md`.

## Profession
A higher-level specialization built from related skills. **Deferred vocabulary — Milestone 02+.** Must not appear in Milestone 01 code, content schemas, or UI.

## Step-clocked
The progression model: activity progress is a function of consumed steps only. Wall-clock time may be displayed ("last synced", "you were away for 3 days") but is never an input to progression.

## Region
A major thematic area containing locations, resources, enemies, activities, and discoveries.

## Skill
A long-term mastery path such as Woodcutting, Mining, Smithing, or Cooking.

## Step reconciliation
The process of determining newly earned, unconsumed steps without double-counting.

## Vertical slice
A small but complete version of the intended experience that validates the full core loop.
