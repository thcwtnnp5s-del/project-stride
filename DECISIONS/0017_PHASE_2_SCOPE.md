# 0017 — Playable Phase 2 scope: five locations, travel and crafting as commands

**Status:** Approved
**Date:** 2026-08-17
**Owner:** project owner
**Amends:** `DECISIONS/0004_MILESTONE_01_SCOPE.md`
**Graduates:** `JOURNAL/OPEN_QUESTIONS.md` **OD-02** (in part — the first slice only)

---

## Context

`DECISIONS/0004` froze Milestone 01 at **five skills, four locations, six tabs,
three enemies, no currency, no merchants**, and `production_content_test.dart`
counts those numbers so the freeze stays frozen. That freeze did its job: Phase 1
shipped and was accepted on hardware without scope drift.

The owner has now directed a substantially more playable milestone, naming an
alpine region, real travel, functional Skills and Craft screens, and the five
existing skills becoming genuinely useful. Some of that widens 0004. A widening
by instruction still needs a record, or the next session reads a frozen count in
a test and a different count in the content and has no way to tell which is
authoritative (`RULES.md` G-3, G-7).

## Decision

### What changes

| 0004 said | Phase 2 says | Why |
|---|---|---|
| Four locations | **Five** — Frostmere added | The owner asked for an alpine identity. Four locations across three terrains could not demonstrate that resources follow geography, which is `OD-02`'s entire requirement. |
| `EnterLocation` is the movement command, free | **`TravelTo` is the player's movement command, and it charges.** `EnterLocation` becomes internal | `OD-02` named the absence of a travel activity as the first dependency blocking a geographic world. A map whose point is that places are far apart needs a system that crosses the distance. |
| Crafting exists in content only | **`CraftItem` is a domain command** | The Craft tab was disabled in Phase 1 because nothing backed it. Recipes existed; the command did not. |
| Skill levels derived ad hoc at call sites | **F-07 — `SkillStanding`, derived in `stride_core`** | A progression screen needs XP-into-level, which is threshold math. Done in a widget it becomes a second implementation of the curve, free to disagree with the one the engine gates on (`RULES.md` E-2). |
| — | **Locations declare `terrain`** | `OD-02`: deciding what a region *is* in data precedes drawing one. |

### What does not change, and is re-frozen

- **Five skills.** Woodcutting, Mining, Foraging, Smithing, Cooking. Level cap
  **20**. Fishing was considered and **rejected** — a frozen tarn and a river
  exist in the new geography, and that is precisely the reason to be careful:
  the brief says not to add Fishing merely because a lake does. Nothing else in
  the slice needs it. A sixth skill still requires its own decision.
- **Six tabs.** Skills and Craft become functional; no seventh destination.
- **Three enemies, and no combat work.** Combat is not part of this milestone.
- **No currency, no merchants, no monetization.**
- **Bronze is the first crafted tier.** No iron, no second metal.

### The new content, in full

Five items (`duskcap`, `rime_blossom`, `duskcap_skewer`, `frostbloom_tea`), three
resource nodes (`duskcap_grove`, `rimefrost_hollow`, `frostpine_stand`), two
recipes (`duskcap_skewer`, `frostbloom_tea`). `pine_ridge` was **relocated and
renamed** to `frostpine_stand`, from Whispering Woods to Frostmere, because pine
is a cold-climate conifer and the woods are temperate broadleaf.

That is the whole expansion, and it is deliberately small. The brief's own
instruction was a coherent bounded vertical slice, not the eventual world.

### The optional dry region was not built

The brief offered a sandy/arid location "if scope remains healthy". It is
recorded as a named expansion exit — **the Dust Reach**, in the rain shadow east
of the range, which is where geography actually puts a dry region — and not
built. Five locations across four terrains already meets the brief's stated
target of 4–5 across 3–4. A fifth terrain would have widened the slice without
deepening it.

## Consequences

- `production_content_test.dart`'s counts move from four locations to five, and
  cite this ADR. The count test is kept, not deleted: it is what makes the next
  widening deliberate too.
- Travel costs and skill gates in the new content are **PROVISIONAL Phase 2 test
  balance**, chosen so the owner can produce feedback within days. They are
  recorded as such in `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §9 and
  are not a balance decision.
- `EnterLocation` moving to internal is enforced by
  `command_classification_test.dart`, whose table is a second independent
  statement of intent — so this reclassification cannot be silently reversed.

## What was rejected

| Option | Why not |
|---|---|
| Keep four locations and put the alpine resources in Stonefall | Would have made terrain decorative on the day it was introduced. Pine growing in a mine is the themed-zone failure `OD-02` names. |
| Add Fishing | See above. A lake is not a reason. |
| Let `TravelTo` be free after the first visit | Would give the player unlimited free movement after one journey, which empties the geography of meaning by the second hour. |
| Charge steps for crafting | Contradicts `GAME_BIBLE/SYSTEMS/04`. The steps were already spent gathering, and free crafting is what keeps "steps gate rate, never access" honest — and is the one meaningful action available at a zero balance (`Q-01`). |
| Gate crafting to Haven's Rest | Defensible in fiction, but it would make the Craft tab lie on four screens out of five, and no canon requires it. Revisit if a workshop ever means something mechanically. |
