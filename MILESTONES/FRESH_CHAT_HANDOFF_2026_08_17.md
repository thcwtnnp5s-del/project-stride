# PROJECT STRIDE — NEW CHAT HANDOFF

**Written:** 2026-08-17, after the owner's first physical-device review of Playable Phase 2.
**Purpose:** canonical working context for a fresh conversation.

> **Read this, then read the repository.** This snapshot is a map, not a
> replacement for canon. Where this document and the repository disagree, **the
> repository wins** — `CLAUDE.md`, `RULES.md`, `MISTAKES.md`,
> `PROJECT_STATE.md`, `DECISIONS/`, `GAME_BIBLE/`,
> `JOURNAL/OPEN_QUESTIONS.md`.
>
> Do **not** reconstruct intent from older conversational fragments. The prior
> thread was very long and precision was lost in it. Everything that survived is
> either in the repository or in this file.

---

## 1. Current repository state

| | |
|---|---|
| **Branch** | `playable-phase-2-multiregion` |
| **HEAD** | `852cf72e36cbf7eadf9db5496ccd5cc77be7396e` |
| **Remote** | identical — 0 ahead, 0 behind `origin/playable-phase-2-multiregion` |
| **Working tree** | clean (26 untracked entries are prior sessions' exploration dirs, deliberately untracked) |
| **CI** | run **`32069255157` — success**, all four jobs green against `852cf72` |
| **Device-tested build** | this HEAD, on the owner's iPhone, free Personal Team, `flutter build ios --profile` |
| **Base** | branched from `3dd892d` (approved UI Facelift 01 baseline); 30 commits ahead of `master` |
| **PR** | none, deliberately — no PR until the owner closes the milestone |

CI jobs: Pigeon bindings ✓ · Dart core ✓ · iOS compile ✓ · Android ✓.
Local suites: **521** `stride_core`, **108** `stride_storage`, **174** app, 12 goldens.

**The branch history was rewritten once** (force-push, owner-authorised) to purge
929 accidentally-committed exploration files, including third-party reference
imagery, from a public repository. Verified absent from the published object
graph by bare clone. See `MISTAKES.md` M-08 and `RULES.md` G-8.

---

## 2. What is currently playable

The implemented loop, and nothing beyond it:

```text
walk in real life
  → open the app (foreground startup sync grants new steps automatically)
  → gather at the current location (spends steps, yields items + skill XP)
  → travel to a neighbouring location (spends steps, moves atomically)
  → gather different things there
  → craft (costs no steps; consumes ingredients, grants output + XP)
  → skill levels rise and open new nodes and recipes
  → close the app, return later, state intact
```

Six working tabs: **Adventure, Character, Skills, Inventory, Craft, World.**

**Not implemented:** combat (enemies exist in content and nothing fights them),
dungeons, fishing, merchants, currency, NPCs, quests, meaningful audio.

---

## 3. Physical iPhone findings

Owner observations, first Phase 2 device session. **Only observed facts.**

### Step economy — the cutover worked

| Reading | Value |
|---|---|
| Playable banked steps at launch | **5,723** |
| `TOTAL WALKED` | **464,946** |
| Prior validated total (Phase 1 close) | ~**459,223** |
| Difference | 464,946 − 459,223 = **5,723** ✓ |

The historical ~459k did **not** return as spendable currency. The epoch cut over
correctly and startup sync granted only post-cutover steps.

- **Manual Sync immediately afterward granted no additional steps** — duplicate
  protection works on device.
- Later screenshots: banked **5,123** after travel/spending; current location
  **Whispering Woods**.

### UI / gameplay review

- **Adventure** — multiple activities per location work visually. Whispering
  Woods showed **Oak Stand** and **Duskcap Grove**. Materially closer to a
  playable game.
- **Skills** — five skills visible with XP, level, progress and next unlock.
  Functionally acceptable for the playtest. Icons remain temporary.
- **Craft** — recipe system visible and functional. Some outputs have production
  art; some still show placeholder slabs.
- **World** — works, but the **map format is not what the owner wants**. See §12.

Nothing beyond the above is claimed. No completed run of the full 45-step
acceptance script (`MILESTONES/PLAYABLE_PHASE_2_ACCEPTANCE.md`) has been
reported.

---

## 4. Current economy / health model

### The four concepts (`RULES.md` H-1)

`observed` (what the platform says) · `granted` (what the ledger credited) ·
`spent` (committed to activities) · `banked` (usable). Collapsing any two is how
steps get double-counted or lost.

### The Phase 2 cutover (`DECISIONS/0016`)

```text
banked = (totalGranted − epoch.grantedAtStart) − (totalSpent − epoch.spentAtStart)
```

An **epoch mark on both running totals**. Nothing subtracted, deleted or
rewound. Historical figures survive intact and stay reportable; they are simply
not spendable.

- **H-2** (granted is monotonic, no clawback) — intact. The mark moves, not the
  counter.
- **H-3** (the cursor prevents double-counting) — intact. Cursor, per-origin
  watermarks, granted slices and sync count pass through byte-identical.
- **P-5** (nothing decays, absence never punished) — **unamended**. The epoch is
  one deliberate owner-authorised cutover of validation data at a defined point,
  not a recurring mechanism. A second epoch would need its own decision.
- A new game marks the origin `(0,0)`, under which the formula reduces exactly to
  `granted − spent`. No "is an epoch active" branch exists anywhere.

**Exactly-once is the state version and nothing else.** The save format is at
**state version 2**; v1 decodes with the origin epoch, and
`BootstrapCoordinator` migrates once through the ordinary transaction path
(lock, CAS, journal-first, read-back). A migration that cannot commit **blocks
startup** rather than being played in memory.

### Health

- **Foreground sync only** (`RULES.md` H-5). One startup reconcile after the
  first frame, plus a manual `Sync steps` control. **No background sync** —
  S-01B is not started and is not implied.
- First-party native adapters only (H-6). Privacy is structural (H-7): no bundle
  id, device name, source name, salt or cursor content is ever logged or shown.
- Startup ordering: the durable save paints **first**, the sync lands after. No
  flash of zeros.

---

## 5. Current locations / travel graph

Five locations, four terrains. Canon:
`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`.

```text
                    FROSTMERE  (alpine, frozen tarn)
                        │ Rimeward Pass · 1,500
   FORGOTTEN        STONEFALL MINE  (foothills, granite)
    HOLLOW           │        │
      │ 1,300        │ 700    │ 800
   WHISPERING WOODS ─┘        │
      │ 600                   │
   HAVEN'S REST ──────────────┘
```

| Location | Terrain | Safe | Entry requirement | Nodes |
|---|---|---|---|---|
| Haven's Rest | grassland | ✔ start | — | meadow_patch |
| Whispering Woods | forest | | — | oak_stand, duskcap_grove |
| Stonefall Mine | foothills | | — | copper_seam, tin_seam |
| Frostmere | alpine | | — | rimefrost_hollow, frostpine_stand |
| Forgotten Hollow | forest | | **item.bronze_sword** | hollow_thicket |

Routes are **symmetric and same-priced both ways**. There is deliberately **no**
Haven's Rest → Frostmere edge; the alpine basin is reached through the mining
district or not at all.

**Travel is a domain command.** `TravelTo` charges the connection cost, moves
atomically, and unlocks on arrival. Adjacency comes from content — a caller
cannot fabricate a route by naming two places. `EnterLocation` still exists but
is **internal**: a surface offering the free move would hand out unlimited
travel.

**Frostmere is gated twice and neither gate is a locked door** — the most
expensive route in the world, and two nodes that refuse an unprepared arrival.
A player can always reach it and look at it.

---

## 6. Current skills

Five, frozen (`DECISIONS/0004`, `0017`). Level cap **20**.

| Skill | Category | XP for L2 | XP for L3 |
|---|---|---:|---:|
| Foraging | gathering | 100 | 250 |
| Woodcutting | gathering | 120 | 300 |
| Mining | gathering | 120 | 300 |
| Cooking | production | 100 | 250 |
| Smithing | production | 150 | 380 |

**F-07 is done.** `SkillStanding` in `stride_core` derives level, XP into level,
span to next, and max handling. **Flutter owns no threshold math** — a widget
computing it would be a second implementation of the curve (`RULES.md` E-2).

**Fishing was considered for Phase 2 and rejected.** A frozen tarn and a river
exist, and that is precisely the reason to be careful. A sixth skill needs its
own decision.

---

## 7. Current gathering / resources

| Node | Location | Skill | Lvl | Tool | Yield | Cost | XP |
|---|---|---|---:|---|---|---:|---:|
| meadow_patch | Haven's Rest | Foraging | 1 | — | meadow_herb ×2 | 90 | 10 |
| oak_stand | Whispering Woods | Woodcutting | 1 | axe t0 | oak_log ×1 | 120 | 12 |
| duskcap_grove | Whispering Woods | Foraging | 3 | — | duskcap ×2 | 130 | 18 |
| copper_seam | Stonefall Mine | Mining | 1 | pickaxe t0 | copper_ore ×1 | 140 | 14 |
| tin_seam | Stonefall Mine | Mining | 3 | pickaxe t0 | tin_ore ×1 | 160 | 16 |
| rimefrost_hollow | Frostmere | Foraging | 5 | — | rime_blossom ×1 | 200 | 26 |
| frostpine_stand | Frostmere | Woodcutting | 8 | **axe t1** | pine_log ×1 | 260 | 30 |
| hollow_thicket | Forgotten Hollow | Foraging | 10 | — | hollow_root ×1 | 300 | 34 |

**Geography does the explaining.** Copper and tin sit together because
cassiterite and copper sulphides both associate with granite intrusions. Oak is
temperate lowland; pine is cold-climate, so it lives in Frostmere and needs a
**crafted** tier-1 axe.

**Foraging is the skill that travels** — four nodes, four climates, four levels.

**Tools must be equipped, not merely owned.** The starting loadout grants them
into the inventory; `GameStarted` equips nothing.

---

## 8. Current crafting / recipes

**Crafting costs no steps** (`GAME_BIBLE/SYSTEMS/04`). The steps were already
spent gathering. Consequence: **any recipe affordable in materials is craftable
at any step balance, including zero** — the game's answer to a week nobody could
walk (`Q-01`).

| Recipe | Skill | Lvl | Ingredients | Output | XP |
|---|---|---:|---|---|---:|
| oak_handle | Smithing | 1 | oak_log ×2 | oak_handle | 15 |
| bronze_ingot | Smithing | 1 | copper_ore ×2 + tin_ore ×1 | bronze_ingot | 30 |
| bronze_axe | Smithing | 2 | bronze_ingot ×2 + oak_handle ×1 | bronze_axe | 70 |
| bronze_pickaxe | Smithing | 2 | bronze_ingot ×2 + oak_handle ×1 | bronze_pickaxe | 70 |
| bronze_sword | Smithing | 3 | bronze_ingot ×3 + oak_handle ×1 | bronze_sword | 90 |
| pine_plank | Smithing | 4 | pine_log ×3 | pine_plank | 110 |
| bronze_chestplate | Smithing | 5 | bronze_ingot ×5 + pine_plank ×1 | bronze_chestplate | 140 |
| herb_broth | Cooking | 1 | meadow_herb ×3 | herb_broth | 12 |
| duskcap_skewer | Cooking | 3 | duskcap ×2 + meadow_herb ×1 | duskcap_skewer | 26 |
| frostbloom_tea | Cooking | 6 | rime_blossom ×2 + duskcap ×1 | frostbloom_tea | 48 |
| hearty_stew | Cooking | 7 | meadow_herb ×2 + hollow_root ×1 | hearty_stew | 45 |

`CraftItem` consumes, produces and awards in **one event**. Every ingredient
shortfall is reported, not just the first. Crafting works **anywhere**, not only
at Haven's Rest — flagged provisional.

**Measured loop cost:** forage → travel → chop → travel → mine → smelt → craft a
Bronze Axe → cross the pass to Frostmere = **8,010 steps ≈ 1.1 days** at 7,000
steps/day. `phase2_loop_budget_test.dart` asserts this stays between one and five
days' walking.

**All balance figures are PROVISIONAL test balance**, not design decisions.

---

## 9. Current UI state

**Accepted, do not redo.** The UI Facelift 01 baseline is approved on hardware.
Phase 2 extended it and did not redesign it.

- Six functional tabs. Adventure is location-aware and renders N activity cards.
- World shows a travel card **above** the map (the map is 640 px; behind it the
  control was ~77 dp visible on a 393 dp phone).
- Skills shows level, XP into level, span to next, and what the next level opens.
- Craft lists **every** recipe with a truthful reason for each disabled one.
- Every disabled control states its reason **in the engine's own refusal order** —
  the requirement before the price.

**Temporary.** Skill icons, step/walking glyph, some item placeholder slabs.

**Intentionally deferred.** Minor visual polish. The 375 dp / 360 dp stacked
fallback is measured and asserted but has never been seen running on hardware.

**Guarded.** `Scripts/check-ui-boundary.sh` forbids `lib/ui/` from importing
storage, naming any `GameCommand`, touching `.engine` / `.runtime` / `.health`,
or using `FutureBuilder` / `StreamBuilder`. UI reads projections and dispatches
controller methods — nothing else.

---

## 10. PixelLab production policy

**Settled.** `RULES.md` **A-1** and **A-2**.

> **PixelLab is the creative production-art and production-animation engine.**

Claude Code **may**: art-direct · prompt PixelLab · select candidates · crop ·
key transparency · nearest-neighbour scale · palette/index remap ·
selected/disabled-state derivation · sprite-sheet assembly · format conversion ·
package · integrate · implement playback, compositing and layers.

Claude Code **may not** hand- or code-author creative production artwork or new
animation frames when PixelLab can do the job.

**If PixelLab fails:** preserve the temporary/existing asset, record the failure,
escalate, revise the spec later. **Never** silently substitute code-drawn art.

Deterministic transformations of approved assets are explicitly allowed and are
not authoring — provided they invent no new object, silhouette, animation frame
or illustrated content.

Style and workflow:
`GAME_BIBLE/ART/exploration/PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md`.
Verdict scale is **×2**; ×8 is inspection only (`MISTAKES.md` M-05). The author
never writes the QA verdict (`M-04`).

---

## 11. Art status

**Production (PixelLab).**

- Four new location vignettes — Whispering Woods, Stonefall Mine, Frostmere,
  Forgotten Hollow (384×176, keyed + cropped from 512×384).
- Four new item icons — duskcap, rime_blossom, duskcap_skewer, frostbloom_tea
  (48×48 native = inventory display size, no reduction step).
- Phase 2 region map (384×640, full-bleed, **no post-processing at all**).
- Phase 1 carry-over: 11 item icons, Traveler sprite + portrait, 8-frame gather
  animation, Haven's Rest vignette.

**Deterministic derivation (allowed, not authoring).** `nav_skills_hi.png`,
`nav_craft_hi.png`, `nav_world_hi.png` — palette index remap measured from three
human-authored pairs.

**Temporary, still in product.** Five skill icons · step/walking glyph
(turquoise boot) · `item/unknown.png` slab.

**Rejected at play scale, not shipped.** The OD-04 five-icon round (blind QA
FAIL — axe and pickaxe read as the same object at ×2) and the OD-03 step-mark
round. Record:
`GAME_BIBLE/ART/exploration/SKILL_ICONS_OD04/ROUND_01_RESULT.md`.

**Missing — PixelLab backlog (9 items render the placeholder slab).**
`hollow_root`, `pine_plank`, `bronze_sword`, `bronze_axe`, `bronze_pickaxe`,
`bronze_chestplate`, `herb_broth`, `hearty_stew`, `hollow_sigil`.
Four are crafted outputs, so the Craft screen shows a blank slab for things it is
offering to make. **Does not block the playtest.**

**Also missing.** All enemy art, all combat animation, all ambient/idle
animation, the orange cat.

---

## 12. World-map correction — IMPORTANT

**The current Phase 2 World map is NOT the owner's intended experience.**

What shipped is a **temporary presentation**: one tall static 384×640 regional
image, with travel cards and a region list around it. The art was produced
through PixelLab and is fine as art. **The product format is wrong.**

What the owner wants (**OD-05**):

- **One much larger continuous world atlas.**
- **Pannable / scrollable** horizontally and vertically on mobile — inspect the
  broader world by dragging around it.
- Locations **embedded geographically into one coherent world**, not a picture
  beside a list.
- **Zoom later** if it helps mobile usability.
- **Subtle ambient animation** — drifting clouds, minor wind and vegetation
  movement, water, snow/weather where appropriate.
- Animation must **never obscure important destinations** and never reduce
  readability.
- **Strategic map. No joystick, no free roam, no character steering.**
- Travel stays domain-owned, deliberate and step-powered.

> **Do not treat the current single static image as the final interpretation of
> OD-05, and do not "solve" OD-05 by regenerating one bigger image.** It is a
> system and interface problem — viewport, layers, coordinates, hit targets,
> animation playback — with PixelLab supplying the creative assets.

---

## 13. Audio direction (OD-06)

Settled direction, **implementation deferred**. Not a blocker for the playtest.

Scope: biome/region ambience · settlement and interior ambience · wind and
weather · environmental loops · travel feedback · UI feedback · gathering,
woodcutting, mining, smithing, cooking · fishing later · combat later · regional
music where appropriate.

Audio should reinforce **biome, profession and world identity**.

**The owner previously shared GitHub audio resources. Those URLs are NOT in
current context. Do not guess or invent them — ask the owner to resend when
audio work opens.** A plausible-looking invented URL would be acted on later as
though it were the owner's.

Order of work when OD-06 opens:

1. Recover the exact shared source (or ask).
2. Audit licensing.
3. Audit Flutter / mobile compatibility.
4. Audit formats, looping, memory footprint.
5. Decide sourced vs custom-generated.
6. Integrate through **one coherent audio layer**, not per-screen playback calls.

**ElevenLabs remains a candidate** for custom sound design.
Existing canon: `DECISIONS/0005_AUDIO_SOURCING.md`,
`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`.

---

## 14. Future combat direction

**New owner direction — recorded conceptually. Not yet repository canon beyond
`DECISIONS/0003`.**

Lightweight regional combat prototype:

- Keep the first prototype **deliberately simple**.
- Roughly **3 enemy archetypes / variations per playable region** as an initial
  **content target, not an immutable law**.
- Enemies fit **regional ecology and identity**.
- Likely flow: `Start Combat` → dedicated combat visual → Traveler and enemy
  **alternate attacks** → each reacts to being hit → repeat until outcome.
- First version may be **turn-based or timing-driven** under the hood.
- **Do not overbuild** stats or controls. No joystick, no action-combat.
- Test as a **small vertical slice before expanding**.

**Existing canon this must respect** — `DECISIONS/0003_COMBAT_MODEL.md`:
turn-based, no real-time pressure, ~6–12 turns, **encounter state persists**
across app closure, and **retreat-not-death**: defeat returns the player to their
last safe destination and **never** removes equipment, inventory, skill XP,
character XP or any progression (`RULES.md` **P-7**). No combat skills in
Milestone 01.

Content already present: `enemy.forest_wolf` (Whispering Woods),
`enemy.cave_goblin` (Stonefall Mine), `enemy.hollow_guardian` (Forgotten Hollow,
boss). Nothing fights them.

**PixelLab produces:** enemy sprites and variants, Traveler combat animation,
attack / reaction / defeat frames, effects.
**Claude implements:** combat state machine, damage, turns/timing, rewards,
persistence, animation playback, UI.

---

## 15. Future dungeon direction

Desired. **Exact design intentionally unresolved — do not canonise it yet.**

Possible shapes: turn-based bounded dungeon · AFK / expedition-style · hybrid
where walking and steps grant entry or access while the dungeon itself is a short
active or turn-based sequence.

**Do not fix the model until basic combat exists and has been tested.**

Dungeons must build on existing combat, equipment, skills, resources and
progression — **not become a disconnected second game**.

---

## 16. Ambient Traveler / orange-cat direction

The owner wants static screens to feel alive and worth revisiting.

Future idle/home animation system — PixelLab-authored rotating ambient sequences,
for example: Traveler playing with an **orange cat** · cat rolling over · cat
batting a red ball of yarn · Traveler petting or scratching the cat · reading ·
push-ups · checking and reorganising the backpack · inspecting or maintaining
tools · stretching · sitting by a fire · eating or drinking · resting or dozing
with the cat nearby.

**The orange cat is an approved recurring visual companion concept.**

Hard limits:

- **Do not infer a pet gameplay system.** No taming, feeding, stats or bonuses.
- Ambient animations **grant no resources and no XP**.
- They must **not pretend gameplay is happening**.

PixelLab creates character / cat / props / animation frames. Claude implements
idle selection, timing, playback and state handling.

---

## 17. Known technical limitations / open questions

**Limitations.**

- No combat, dungeons, fishing, merchants, currency, NPCs or quests.
- 9 items render the placeholder slab (§11).
- World map format is temporary (§12).
- Skill icons and step glyph are temporary.
- Crafting works anywhere rather than at a workshop — provisional.
- The 375 dp / 360 dp stacked layout fallback is asserted but never seen on
  hardware.
- Android physical validation remains paused by owner priority; the Health
  Connect adapter compiles and is untested on a device.
- Flutter pinned at **3.44.8**; a deliberate 3.47 evaluation is scheduled work,
  not accruing debt.
- The test harness's Roboto is now **vendored** at `test/support/fonts/`
  (byte-identical to the SDK's, Apache-2.0) because the SDK cache path proved
  unreliable on Linux CI. `MISTAKES.md` M-06 is intact — the guard still fails
  rather than skips.

**Open questions** (`JOURNAL/OPEN_QUESTIONS.md`).

- **Q-01** — what does Stride offer a player who cannot walk this week?
- **Q-02** — what makes the Traveler recognisable?
- **Q-03** — can the locked equipment read inside 24 × 34?
- **Q-04** — does the current location get to be teal? (L-16 tension)
- **OD-03** — step mark: specified, one round rejected, open.
- **OD-04** — skill icons: specified, one round rejected at play scale, open.
  The finding: **two hafted tools cannot be told apart at 12 × 12** — the next
  round must separate Woodcutting and Mining by silhouette *family*, a mass
  rather than a stick, not by head geometry.
- **OD-05** — world atlas (§12). **OD-06** — audio (§13).
- **Closed and graduated:** OD-01 → `DECISIONS/0016`; OD-02 →
  `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` (first slice only).

---

## 18. Superseded / DO NOT RESURRECT

**Read this section before proposing anything.**

1. **Another broad UI facelift.** UI Facelift 01 closed with owner approval on
   hardware across three device reviews. Phase 2 extended it. The owner has
   explicitly said the priority is **playing**, not polish. Log minor visual
   defects; do not open a polish milestone.
2. **Historical steps as spendable currency.** The ~459k pre-cutover balance is
   retired by `DECISIONS/0016` and confirmed retired on device. Do not "restore"
   it, do not treat `totalGranted` as spendable, and do not add a second epoch
   without a new decision.
3. **Lowering `totalGranted`, rewinding the cursor, or a fresh ledger** as ways to
   reset a balance. All three were explicitly rejected — they break H-2 or H-3,
   which are the guarantees the architecture exists for.
4. **Local free-roam map gameplay.** No joystick, no d-pad, no walkable tile
   field, no controllable character token on the world map. The style spec's
   governing rule: *art must not imply a system the game does not have.* A blind
   reviewer once expected to control a PROOF_02 tile scene "with a stick or
   d-pad"; that scene was discarded.
5. **Treating the current static regional image as the final atlas.** It is a
   temporary presentation (§12).
6. **Solving OD-05 by generating one bigger picture.** It is a system problem.
7. **Claude/code-generated production art** where PixelLab is appropriate
   (`RULES.md` A-1). Deterministic transforms are fine (A-2).
8. **Background health sync / S-01B.** Foreground only (`RULES.md` H-5,
   `DECISIONS/0014`). No `HKObserverQuery`, no background delivery, no background
   modes, no `Timer.periodic` anywhere in `lib/`. Reopening needs an explicit
   decision and a real persistence coordinator.
9. **Wall-clock progression.** Progression is step-clocked (`DECISIONS/0001`,
   `RULES.md` P-4). Time passing is never a substitute for movement.
10. **Decay, expiry, FOMO, streaks, upkeep, spoilage** (`P-5`, `DECISIONS/0008`).
    Nothing stored decays, ever.
11. **Death penalties, item loss, XP loss, progress rollback** (`P-7`,
    `DECISIONS/0003`). Retreat, not death.
12. **Multiplayer, trading, guilds, PvP** (`P-2`). **Monetization, premium
    currency, ads, loot boxes, gacha, battle passes** (`P-6`).
13. **Merchants, buying and selling, currency** (`DECISIONS/0004`) — including
    market stalls or price boards in any settlement art.
14. **Native Swift + SwiftUI.** Superseded by `DECISIONS/0010` — Flutter with a
    pure-Dart core. The Swift scaffold was retired at M-5.
15. **A sixth skill (including Fishing) without a decision record.** Considered
    for Phase 2 and rejected; a lake is not a reason.
16. **`git add -A` / `git add .`** (`RULES.md` G-8, `MISTAKES.md` M-08).
17. **Weakening an invariant or a guard to make a test pass** (`G-4`). A failing
    guard is evidence about the code.
18. **Verification campaigns without a named uncovered risk** (`G-1`,
    `MISTAKES.md` M-01).
19. **Judging art at ×8**, or letting the author write the QA verdict (`M-04`,
    `M-05`).
20. **Regenerating the frozen save fixtures** (`v1_baseline.save`,
    `v2_baseline.save`) to make a suite green.

---

## 19. Recommended immediate next actions

1. **Play it for several days.** Walk, sync, travel, gather, craft, level. The
   milestone exists to answer a question no test can: *does it feel like a game?*
2. **Watch step ingestion during real use** — that new steps keep arriving, that
   repeat syncs grant nothing, and that nothing resets across relaunches.
3. **Log what you hit.** Separate *gameplay blockers* (something is impossible,
   wrong, or lost) from *cosmetic gaps* (a placeholder slab, an icon).
4. **Fix only true blockers** in the meantime. Do not start a content or art
   expansion mid-playtest.
5. Optional, non-blocking: the nine PixelLab item icons (§11) — cheap, isolated,
   and the most visible remaining gap.

---

## 20. Suggested next milestone after playtest

**Proposal only. Not a plan, not authorised.**

Whatever the playtest reports should shape it. On current evidence the highest
value is **one** of these, not several:

- **A. Combat vertical slice.** One region, ~3 archetypes, turn-based per
  `DECISIONS/0003`, retreat-not-death, encounter persistence. Gives Bronze
  equipment a purpose beyond gating, and the enemies already exist in content.
  Most likely to make it feel like an RPG.
- **B. World atlas (OD-05).** Pannable single-world map with embedded locations
  and subtle ambient animation. Highest visible impact; largest interface build;
  no new gameplay.
- **C. Content and progression depth.** More regions, resources, recipes and
  equipment utility — widening what already works.

**Recommendation: A, then C, then B** — combat is the missing *system*, content
widens what exists, and the atlas is presentation for a world that should first
be worth exploring. Audio (OD-06) and ambient life (§16) fold in afterwards.

Whichever is chosen: **one milestone, bounded, with a device acceptance script**,
in the pattern Phase 1 and Phase 2 established.
