# Project Stride — Project State

**Version:** 2.22
**Status:** 🚧 **WORLD MAP EXPANSION REFINEMENT 02 — the second scale-up and
coherence pass is built, awaiting the owner's review and device test.**
Branch `playable-phase-2-multiregion`, on top of World Map Polish 03
(`4f8459e`). Record: `MILESTONES/WORLD_MAP_EXPANSION_REFINEMENT_02.md`; art
round `GAME_BIBLE/ART/exploration/WORLD_MAP_EXPANSION_REFINEMENT_02/README.md`.

The device review's verdict — right world, one more major pass — answered in
one breath: the atlas is **1024², world 6144 px** (the 512² master still
byte-preserved, now at (256, 256) inside two rings, every coordinate swept
+768); the four worst WMP03 joins are **fixed at the source** (the east
dither band, the NE night patch, the SE beach cut-off, the south luminance
line — regenerated pieces with full-column context references, edit-in-place
patches, and a deterministic water/snow palette conform that invents no
colors); the **west opens**: a caravan road runs continuously from
Whispering Woods across a log bridge, through a corridor cut in the master's
forest, over Wayfarer's Pass and down into a far western valley — scenery
that promises travel, no new destination (G-3); the **dragon flies
head-first** (the WMP03 travel vector was backwards) and **breathes one
small westward flame per crossing** (28-frame journey, playLoops 1); the
fire egg — found by the placement sweep sitting exactly on the new road —
is re-authored smaller in the south-west forest; three quiet **new eggs**
join (a westbound caravan on the pass road, a roadside stag, a marsh flock
that lifts and settles), every interval still mutually distinct; and the
label pass **removes** a name (Outer Shoal's crowded column) while adding
only three on a ~78 % larger world. Flat open ocean is now assembled
deterministically from the approved east strip's own water after four
generation rolls drifted — the lesson and the tools (`plab.js` transport,
finally committed; `waterconform`; `assemble_ocean`) are on the record.
The regional-ecology §8 compass conflict (canon said estuary west, Dust
Reach east; the accepted painting says Worldspine west, ocean east) is
amended on the record rather than silently diverged (G-7).

Suites: app **658**; analyze clean; guards clean; `package-art.js --check`
clean (792 files; the 1024 composition and 82 overlay frames reproducible
from tracked sources; overlay_fire2 retired under the orphan sweep).
Goldens: only the two World goldens changed, regenerated and reviewed.
PixelLab: 601 generations, balance 1,416 → **815**, rejects on the record.
Open: Q-06, Q-07 remainder (three more proposal names), Q-08, Q-09, Q-10,
Q-11, OD-04, OD-06; the whole-world-survey zoom-floor feel is an explicit
device-checklist owner call.

---

**Version:** 2.21
**Status:** 🚧 **WORLD MAP POLISH 03 — the scale-up and easter-egg rework is
built, awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, on top of part 2 (`5b0395d`). Record:
`MILESTONES/WORLD_MAP_POLISH_03.md`; art round
`GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_03/README.md`.

The device review's verdict on the ambient-life layer — right direction,
wrong execution — answered in one breath: the world is **2.25× bigger
without repainting anything** (the accepted 512² master sits byte-preserved
inside a composed 768² base — eight PixelLab Pro frontier pieces
style-referenced to the master's own edges, dither-crossfaded at the joins:
the Worldspine west, a frozen polar sea north, open ocean east, an estuary
coast south, five honest future-tier names on the frontier); every flagged
egg is **reworked as part of the painting** rather than pasted on it — the
fire is an irregular burn scar with charred trunks (edit-in-place, not a
black circle), the yeti sits at a real ice hole and keeps its rod through
all 8 frames, the bear is a ~12 px head that rises from a canopy gap and
ducks away, and the slug-read water dragon is a proper loch serpent that
surfaces, swims west and dives; and the sky gets the owner's **flying
dragon** — long, slim, undulating across the north-west for ~12 s at long
intervals — plus a whale roll, a distant sail, and one idea rejected on its
merits (aurora; the shimmer failure family). Layout schema **v5** adds
`travel` (per-play journeys, gap-reset, no wrap) and `playLoops` (long plays
without duplicate frames). Placement swept programmatically at origin and
travel-endpoint against every hit circle, glyph and label zone; one graze
found and fixed at the emitted-box level.

Suites: app **658** (+3 v5 schema/cadence); analyze clean; guards clean;
`package-art.js --check` clean (740 files; the composed base and 63 new
overlay frames reproducible from tracked sources; the four superseded eggs
and the standalone master retired under the orphan sweep). Goldens
**unchanged by design** and verified so. PixelLab: 399 generations, balance
1,815 → 1,416, rejects on the record. Open: Q-06, Q-07 remainder, Q-08,
Q-09, Q-10, Q-11, OD-04, OD-06.

---

**Version:** 2.20
**Status:** 🚧 **WORLD MAP POLISH 01, PART 2 — the ambient-life pass is
built, awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, on top of part 1 (`61e530d`). Record:
`MILESTONES/WORLD_MAP_POLISH_01.md` part 2; art round
`GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_01/README.md` part 2.

The recovered half of the owner's map brief, in one breath: the atlas now
**rewards looking around** — the volcano stirs, smokes and bursts on its own
clock (~every 18 s); a **blue yeti ice-fishes** on the frozen tarn (a still,
after two animation attempts dropped its rod — failure on the record, A-1);
a **cute water dragon** surfaces in the eastern sea every ~30 s, undulates
and slips under; a **bear peeks** from the southern forest edge every ~26 s
and looks around for five seconds; two forest patches **rustle** on offset
clocks; and the **water finally moves** — two continuous ripple loops made
by animating crops of the painting itself and placing them back where they
came from, which is also how the volcano and rustles work (frame 0 is the
untouched source crop, edges deterministically feathered back onto the
painting so no seam box can read). The five-times-failed water-shimmer
sprite was deliberately not re-attempted. "Occasional" is layout schema
**v4**: an optional overlay `intervalMillis` quiet gap, gap-first so a
frozen clock — tests, reduced motion, background — shows no creature at
all. Everything is presentation-only: no labels, no hit targets, no
gameplay, no audio; every placement was checked against marker glyphs,
labels and routes, with three collisions caught in placement review and
fixed by regeneration or emit-cropping.

Suites: app **655** (+3 schema/cadence); analyze clean; guards clean;
`package-art.js --check` clean (693 files; 70 new overlay frames from
tracked sources); goldens **unchanged by design** and verified so. PixelLab
part 2: 18 generations across 17 jobs (rejects on the record), balance
1,833 → 1,815. Open: Q-06, Q-07 remainder, Q-08, Q-09, Q-10, Q-11, OD-04,
OD-06.

---

**Version:** 2.19
**Status:** 🚧 **WORLD MAP POLISH 01 — the atlas presentation pass is built,
awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, on top of Playable Polish 02 (`0905b76`).
Record: `MILESTONES/WORLD_MAP_POLISH_01.md`; art round
`GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_01/README.md`.

A presentation-only World pass, in one breath: the **western forest fire**
is on the map — a burnt hollow eaten into the far-west forest at the river
fork with two live flames, style-matched by PixelLab inpainting against the
master's own canopy, animated in eight still-canopy frames (1.6 s loop),
decorative only (no hit target, no label, no system, no audio) — and the
**ambience the 512 × 512 continent replacement silently dropped is
restored**: chimney smoke at Haven's Rest, a smoke thread at the Stonefall
adit (the forge column was tried and rejected in preview — it read as
boulders), two drifting cloud shadows, a cloud wisp, and the bird flocks'
drift, all re-placed on the new painting's geography, with one mist patch
moved off the fire's corner. The world record's next-pass art items
(drainage, stamped forest, projection ruling, delta bars) stay deferred on
the record — map-scale inpainting is still tooling-blocked, and the fire
incidentally gives the stamped west quarter its first authored feature.

Suites: app **652** (+1: every asset the atlas layout names — every frame of
every overlay included — must exist packaged at its declared size); analyze
clean; the guard set clean; `package-art.js --check` clean from tracked
sources; the two World goldens regenerated and reviewed (only they changed).
Nothing outside the atlas presentation layer was touched. PixelLab: 7
generations (6 fire stills, 5 rejected on the record; 1 animation), balance
1,840 → 1,833. Open: Q-06, Q-07 remainder, Q-08, Q-09, Q-10, Q-11, OD-04,
OD-06.

---

**Version:** 2.18
**Status:** 🚧 **PLAYABLE POLISH 02 — the physical-device presentation pass
is built, awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, on top of the audio foundation (`14fedaf`).
Record: `MILESTONES/PLAYABLE_POLISH_02.md`; decision
`DECISIONS/0026_STEP_TRACKER_PROJECTION.md`; art round
`GAME_BIBLE/ART/exploration/PLAYABLE_POLISH_02/README.md`.

The owner's device list, answered in its own order. The **Character tab
carries a Steps card** (Today / This Week / last synced / Step Tracker) and
the tracker is a pushed screen — day-by-hour, week-by-day, the sync control
beside its own timestamp; the local-day fold is `StrideSession.stepHistory()`
under `DECISIONS/0026`, closing Q-UI-9 by ownership rather than waiver, on
the same one wall-clock seam, with the UI-boundary guard unweakened.
**Crafting is a scene**: three 384 × 176 work backdrops (smithy, carpenter's
workshop, hearth) and three 96² stations (anvil, bench, tripod cookpot)
through PixelLab; recipes carry an optional presentation-only `station` word
so the five wood recipes read as bench work; loop, timers and commits are
untouched. The **job board leads with reward icons**, colours reward lines
by rarity, shows READY/ACCEPTED counts and says honestly that orders rotate
on delivery. The **combat idle is re-authored east-in-profile with the sword
visible** (the PE01 v3 drift, recorded then, corrected now; 9 frames,
80 × 64) — the Traveler faces the enemy. **Tools name what they open**
("Mines: Copper Seam, Tin Seam", "Tier 2 opens Hardened Copper Seam") from
the same node fields the engine gates with, and equipment tiles expand to
the full gear evaluation in the bag. Faction reputation and tool speed
bonuses do not exist and were not faked; combat audio remains deferred with
its seam noted.

Suites: app **651**, `stride_core` **697**, `stride_health` 143,
`stride_storage` 108; analyze clean; the CI/verify guard set clean; goldens
regenerated and reviewed. (Found, not introduced: the step-model guard's
production scan — which CI does not run — carries a pre-existing
`\.signature\b` false positive against the knowledge system's
`drop.signature`, verified identical at `14fedaf`; on record in the
milestone §7 and flagged as its own task.) Nothing in the health adapters or the step ledger's counters,
slices, watermarks or cursor changed; no schema change (the content field
is optional; state stays v9). PixelLab: ≈128 generations, balance 1,921
before the round. Open: Q-06, Q-07 remainder, Q-08, Q-09, Q-10, Q-11,
OD-04, OD-06.

---

**Version:** 2.17
**Status:** 🚧 **AUDIO_PRESENTATION_01 — the playable audio foundation is
built, awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`. Record: `MILESTONES/AUDIO_PRESENTATION_01.md`;
manifest `AUDIO/AUDIO_ASSET_MANIFEST.md`; dependency record
`DEPENDENCIES.md`.

The workstream ran asset generation through five owner listening gates —
nothing was integrated unheard. Accepted: five region tracks (Haven and
Frostmere from the bake-off's Round 3 piano anchors; Whispering Woods,
Stonefall Mine and Forgotten Hollow new, one deliberate candidate each) and
five profession action cues (mining 4102, woodcutting 4203, foraging 4301,
smithing 4401, cooking 4503 — cooking took three attempts; 4501 and 4502
are retained rejected references). Owner rulings on the record: **one
strong cue per activity** (variants only if device play proves repetition
distracting); **cues punctuate what the player watches** — visible
animation beats, never activity duration, steps, or unwatched queues;
combat keeps regional music, no combat SFX this phase. Stability balance
399 → **61**; no further generation without the owner reopening it.

The runtime layer is minimal and presentation-only: `lib/audio/` holds the
one app-scoped `AudioController` (MUSIC crossfading per region with
same-region changes a structural no-op; SFX through per-cue cooldowns;
AMBIENCE as architecture only), settings (on by default, music 0.55 under
SFX 0.9) persisted as one JSON beside — never inside — the save directory,
and the `audioplayers 6.8.1` seam (pinned, recorded, policy-checked).
`AmbientStage`'s working loops fire the cue on their authored strike frame;
the one-shot gather sounds on the result, never the tap. Audio touches no
engine state, adds no background modes, and dies with the screen that shows
it. Assets ship in `assets/audio/v1/` (~19 MB of the 30 MB budget),
deterministically mastered, every file a manifest row with its verbatim
prompt.

Suites: app **646** (+17 audio), `stride_core` 697, `stride_health` 143,
`stride_storage` 108 untouched; analyze and every guard clean; Android
debug build green. Deferred by name: ambience production, combat/UI/travel
SFX, battle and World music, stingers, per-material variants. Open: Q-06,
Q-07 remainder, Q-08, Q-09, Q-10, Q-11, OD-04, OD-06.

---

**Version:** 2.16
**Status:** 🚧 **PLAYABLE POLISH 01 — correction pass complete, not pushed,
awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, on top of the published `3dae9e8`. Record:
the "Correction pass" section of `MILESTONES/PLAYABLE_POLISH_01.md`. The
future `EQUIPMENT_COMBAT_CRAFTING_DEPTH_01` workstream (material tiers,
weapon families, Slash/Crush/Pierce, ammunition, combat energy, the bank
cap, D20, road encounters) **remains deferred** to a fresh session after
this pass is physically accepted.

The device proved the fresh-playtest reset (mechanics pass: zero banked,
zero walked, old steps never re-banked, 328 new steps banked once) and
returned a list of presentation, pace and semantics findings, all
answered: the Adventure band's **SPENT is this epoch's** (a projection;
lifetime spend moves to the Character tab); a **fresh playtest wears the
starter loadout**; **profession tools are never power-compared** — an axe
over a pickaxe is a TOOL SWAP and the craft reveal names profession and
tier; **MINOR craft results are transient** and never pin the card; the
**Goal Board** gains a READY pill, a TRACKED mark and a collapsed project
row; the **reward layer is one frame** with hairlines inside and Common
rows plain; the **hardened seam** is re-authored (1 PixelLab round, 3 gens)
as compressed copper and every loop re-audited in context; **gathering
paces at 100 steps a minute** (600 ms a step on the engine's own cost,
with an authored `workSpeedPercent` seam); **crafting is deliberate at
zero steps** (`craftSeconds` per recipe: components 30–45 s, food 45–90 s,
gear 120–180 s); and **rarity is re-based** by owner ruling — Common <
Uncommon < Rare < Epic < Legendary, "how exceptional" not "where in
progression", training gear Common, standard Bronze Uncommon, with the
enum, palette names, content, canon and tests changed together.

Suites: app **629**, `stride_core` **697**, `stride_health` **143**,
`stride_storage` **108**; analyze and every guard clean; goldens
regenerated and reviewed. Nothing in the health adapters or the step
ledger's counters, slices, watermarks or cursor changed; no economy
re-basing; no schema change (the two new content fields are optional).
Open: Q-06, Q-07 remainder, Q-08, Q-09, Q-10, Q-11, OD-04, OD-06.

---

**Version:** 2.15
**Status:** 🚧 **PLAYABLE POLISH 01 — implementation complete, not pushed,
awaiting the owner's review and device test.** Branch
`playable-phase-2-multiregion`, five commits on top of Playable Experience
Refinement 01 (`1880d5d`). Record: `MILESTONES/PLAYABLE_POLISH_01.md`;
decision `DECISIONS/0025_PLAYTEST_RESET.md`; open questions Q-09, Q-10,
Q-11.

The owner's polish brief, in its own order. In one breath: the **mining
loop was backward** — the PixelLab source struck behind the figure and the
stage had placed the seam behind him to match; re-authored through
PixelLab, the miner now faces the seam and every profession works west
(`f9321c9`). The **three ore seams** are three generations, not one
boulder with a swapped patch — copper warm, tin silver, hardened dense and
dark. A **reward layer** (`reward_layer.dart`) now carries every MEDIUM and
MAJOR payoff — a delivery, a bounty, a contract, a project stage or
completion, finished equipment, a level, victory and defeat — as a scrim
and a framed panel above the surface that earned it, held until Continue;
the Goal Board beneath is one block per open job with Deliver filled
beside Track (`2cd2d35`). **Gear is evaluable at a glance**:
`gearStatsOf` gives the tile `ATK 9 +6` and the bench a block with the
worn piece, the verdict and the passives (`eeb26fc`). The **playtest
reset** (`DECISIONS/0025`, state v9) is the owner's confirmed command on
the Character tab: Banked Steps and Total Walked start again from zero,
with or without a fresh game, while `totalGranted`, the slices, the
watermarks and the cursor are untouched — proven through the real session
that re-delivered history grants zero after a reset and across a relaunch
(`39de384`). The **blow's quality** is recorded and said in the combat log
with no figure changed (`1e8dc1c`). The bank cap and combat energy (Q-10),
the roll spread and D20 (Q-09) and road encounters (Q-11) are written up
as concrete plans and deliberately not started.

Suites: app **623**, `stride_core` **695**, `stride_health` **143**,
`stride_storage` **108**; analyze and every guard clean; goldens
regenerated and reviewed. Nothing in the health adapters changed; no
economy re-basing ran; one schema change (v9), asked for by name.
Open: Q-06, Q-07 remainder, Q-08, **Q-09, Q-10, Q-11**, OD-04, OD-06.

---

**Version:** 2.14
**Status:** 🚧 **PLAYABLE EXPERIENCE REFINEMENT 01 — implementation complete,
awaiting the owner's physical-device test and the §0 confirmation.** Branch
`playable-phase-2-multiregion`, on top of the Presentation, World & Reward
Feel correction round (`a1ff92b`). Record:
`MILESTONES/PLAYABLE_EXPERIENCE_REFINEMENT_01.md`; open question Q-08.

The owner's extended device play ruled the game **strong enough to refine
rather than expand**, and reported one blocker: a defeat → retreat →
relaunch sequence that appeared to re-grant the day's steps (≈3,000 →
≈6,000).

**The blocker is not reproducible at the accounting boundary.** Eleven
regression cases over the real session, repository and file layout prove
that identical Health samples grant zero through live replay, the recovery
rescan, defeat, manual sync and four relaunches, that new steps grant
exactly once, that nothing is lost on retreat, that the adapter is read
only on an explicit foreground sync, and that the epoch never moves. The
one arithmetic path to a doubled bank is a **second HealthKit step source**
(a Watch, or any app writing steps): the ledger credits per origin by
design (H-1) and HealthKit's merged total de-duplicates where per-source
sums do not; a Watch's late batch arriving on a relaunch is exactly the
shape observed. The count of contributing sources is now visible — counts,
never identities (H-7) — on the Character tab, the sync line and the held
banner. Whether to reconcile on the merged total is **Q-08**, the owner's
decision; no accounting or persistence code changed.

What changed in presentation, in one breath: **one reward language** —
`RewardBeat` / `LevelUpCard` / `StaggeredReveal`, three tiers (MINOR,
MEDIUM, MAJOR), transient by contract — carries every result: craft
completion is a beat rather than a log line in the recipe card (equipment
in its rarity ink with the stat delta and Equip, held until OK), a finished
gather queue gets its `GATHERING COMPLETE` beat, combat victory resolves
XP → drops → **knowledge stage** (`STUDIED` names what is newly understood,
`KNOWN` reveals the signature) → level-up → bounty progress on one clock,
defeat says `Driven back / Retreated to … / Nothing was lost.` The giant
stage captions are gone; a **locked selection** composes the scene without
working and states its gate on the picture; HP shows by one rule; Goal
Board rows carry a restrained type chip, the project tile folds its lore
and pulses a contribution. **PixelLab**: six plates, two accepted — Stonefall
is a cut slate gallery with timber, lantern, rails and a shaft mouth; the
Woods clearing is open ground before the deeper wood — reviewed in context
through a new stage-evidence harness; the smith and cook loops play
ping-pong so the tool no longer pops on the wrap.

Suites: app **613**, `stride_core` **684**, `stride_storage` **103 of 108** (five cross-process lock probes time out on this machine; package untouched — see the record),
`stride_health` **143**; analyze clean; art packaging clean; goldens
regenerated and reviewed. **Nothing in the health / step-accounting or
persistence path changed; no economy re-basing; no schema change.**
Open: Q-06, Q-07 remainder, **Q-08**, OD-04, OD-06.

---

**Version:** 2.13
**Status:** 🚧 **PRESENTATION, WORLD & REWARD FEEL 01 — device correction
round complete, awaiting the owner's second physical-device test.** Branch
`playable-phase-2-multiregion`, on top of the Exploration & Progression Loop
(`0700969`). Records: `MILESTONES/PRESENTATION_WORLD_REWARD_FEEL_01.md`,
`MILESTONES/PIXELLAB_MAPS_EVALUATION.md`,
`DECISIONS/0024_TRACKED_GOAL_VALIDITY_REPAIR.md`.

The owner's first device test ruled the **mechanics good enough to build on
and the presentation not good enough yet**. The second ruled the new UI
architecture a meaningful improvement and returned a list of presentation
and correctness faults. Both are answered here, and neither added a
mechanic.

What changed, in one breath: Adventure is **one stage in two modes** —
nothing selected is the LOCATION (the whole painting, the Traveler, the cat,
the full idle cadence, and deliberately no resource prop), and selecting an
activity is WORK (the profession's own tighter backdrop, the resource on the
Traveler's own ground line where his tool lands, the companion scenes out of
the way, the caption naming the work) — with gather nodes reduced from
~380 dp cards to **~48 dp selectable rows**, **encounters given the same
treatment** (Salamander and Cave Goblin were ~400 dp each and permanently
expanded), and locked activities kept visible with the concrete gap; the
whole job board moved to a **Goal Board** behind one button, in each
location's own fiction, and the board itself reduced to **four facts a job**
— title, type, progress, reward — with the flavour and the buttons in the
one job the player opened; **crafting is a real activity** — categories,
compact rarity-inked recipe rows, one working detail panel, a ×1/×5/×10
queue clamped to the bag, a **working craft stage** (the Traveler hammering
at a forge or stirring over a cookfire, one PixelLab loop per craft skill),
timed repetitions (components 3 s, food 4 s, gear 6 s) each committing the
*unchanged* instant `CraftItem` exactly once, cancel keeping completions,
and a backgrounded queue that keeps running on its wall-clock anchor and
**reconciles only what legitimately elapsed** on resume; equipment
finishes with a **reveal** (name, rank, stat delta, level-up unlocks,
Equip); community projects gained animated per-material bars and a permanent
**completion preview**; enemy cards present the **ecology** (known drops in
rarity ink, the signature `???` until Known); and the world is a **new continent, doubled** —
one 512 × 512 PixelLab painting at scale 6, **3072 × 3072 world px**, 2.25×
the first pass, pannable in all four directions, with the five places spread
so thousands of steps look like thousands of steps and **fourteen future
landmarks** north, south, east, west and offshore that are named, quieter,
and deliberately not travelable.

Three device bugs fixed: a **completed contract or project now clears its
tracked slot** (it used to silently re-track the rotation's fresh 0/x copy);
**travel is one confirmed multi-leg journey** quoting the whole way's cost,
with the arrival naming the journey total and the final leg (the 4,400-step
walk that reported "3,000"); and the **Hardened Copper Seam has stage art**,
with a new test holding pack, lookup and scenery in agreement for every
node.

PixelLab (owner-amended scope): the **combined MCP ecosystem** was tested
live — tileset generation and chaining, a real metadata-driven headless
autotile bake, style-matched map objects, reference-styled Pro generation,
localized inpainting. Maps has **no programmatic creation and no structured
export**, so it is not the foundation; the tileset/object/inpaint tools are
adopted around a painted base. Full record and the preserved bake spike:
`MILESTONES/PIXELLAB_MAPS_EVALUATION.md`.

### The correction round's own corrections

Three faults were **correctness**, not presentation, and all three are
fixed with regression tests that fail if the fix is undone:

- **The stale tracker survived migration.** The reducer fix reached future
  completions and could not reach the save already on the phone, where Wolf
  Problem had been completed under the old build. **State version 8** is the
  migration table's first *repair* step: it clears a Contract tracker only
  when the contract is unaccepted **and** has been completed before, which
  is residue and nothing else. It runs once, as an ordinary event through
  the real engine (`DECISIONS/0024`).
- **"+0 STEPS BANKED / Journey Ready" was two faults in one card.** The
  banner read `lastSync`, which the five-second result timer nulls while the
  banner waits for a tap; it now holds its own copy. And the highlights were
  "what is true right now" asked after the sync, so every standing fact
  re-announced itself; they are now the **difference** between before and
  after, so a sync celebrates only what it made true.
- **The Goal Board's yellow underlines** were Flutter's missing-Material
  fallback, shipped twice. The first fix wrapped `MaterialApp.home`, which
  covers exactly one route — and the Goal Board is the product's first push,
  built by the Navigator outside it. The `Material` moved to
  `MaterialApp.builder`, so no future route can acquire this by being new.
  The guard asserts on **resolved text decoration** rather than on strings,
  and with the old placement it reports the board's 50 underlined strings.

### What the world item does and does not deliver

The continent is 2.25× larger and removes a blocker that is in the product
today — a rectangular compositing box sitting in open water, inpaint residue
from the first pass that reads as a texture that failed to load. It **does
not pass the §23 topology gate**, and the gate was run on the old painting
and the new one with the same questions so the comparison is a measurement:
both FAIL, the incumbent with one blocker, the replacement with none. The
shared faults — sparse drainage, a stamped forest quarter, mixed projection
— belong to the generator, not to either painting, and the next pass is
specified in the world record.

A **tooling** constraint was found and matters more than any single art
note: MCP's inline base64 ceiling measures at roughly **5.5 KB**, so
map-scale inpainting cannot be driven through this pipeline at all. Sprite
corrections work; atlas corrections need the web Map Workshop or a paint
pass outside it.

Suites: app **597**, `stride_core` **684**, `stride_storage` **108**;
analyze clean; art packaging clean; goldens regenerated and reviewed.
**No economy re-basing, and nothing in the health / step-accounting path
touched.** One schema change, asked for by name: state version 8, a repair
with no field added and no shape altered.
Open: Q-06, Q-07 remainder, OD-04, OD-06.

---

**Version:** 2.11
**Status:** 🚧 **EXPLORATION & PROGRESSION LOOP 01 — implementation complete,
awaiting the owner's physical-device test.** Branch
`playable-phase-2-multiregion`, on top of the device-corrected Activity Feel
& Presentation 01 (`28e6f01`). Records:
`MILESTONES/EXPLORATION_PROGRESSION_LOOP_01.md` (device script in the final
report), `DECISIONS/0023_EXPLORATION_PROGRESSION_LOOP.md`,
`GAME_BIBLE/SYSTEMS/09_EXPLORATION_PROGRESSION_LOOP.md`.

What changed, in one breath: the game now answers **"what will my next
1,000–3,000 steps accomplish?"** — three tracked goal slots (Journey /
Pursuit / Contract, live projections, never escrow, nothing expires) and a
held step-sync banner ("+N STEPS BANKED" plus what it made possible); every
location keeps a **board in its own fiction** (Notice Board, Ranger
Requests, Mine Ledger, Expedition Ledger) serving one contract architecture
— completion-rotated local needs, post-acceptance-only bounties with
deterministic material guarantees, and one-time regionals that teach recipes
and reveal rumors; three **community projects** (Mill, Gallery Lift, North
Shelter) take staged, atomic contributions and permanently change their
settlement's **named development state** (Struggling→Recovering,
Strained→Working, Exposed→Outpost) with exactly-once content-declared
effects (cheaper planks, a deeper seam, Frostmere safe); **HP persists**
between fights at save v7 (level = +2 Max HP, no auto attack; food heals out
of combat; safe settlements full-heal on arrival; defeat is still retreat);
**enemy knowledge** runs Seen → Studied → Known and stops, concealing
signature drops (`???`) until Known; the three RCP01 enemies (Wild Boar,
Mountain Ram, Salamander) and the Oakback Bear are **in the world** with
their accepted PixelLab tracks; travel costs are retuned onto the continent
scale (500 / 1,000 / 1,400 / 3,000 / 2,400) behind a **confirmation step**
and an arrival trace; contracts and projects reveal **rumors** as named
future-tier atlas landmarks; and gathering carries deterministic seeded
**yield bonuses** (node / wilderness / tool) with per-index queue rolls.

Fifteen new item icons shipped (12 pixen generations + 3 re-rolls + 1
re-re-roll, three blind Visual QA rounds — every verdict in
`GAME_BIBLE/ART/exploration/EXPLORATION_PROGRESSION_LOOP_01/items/README.md`)
plus three RCP01 material icons; a withheld icon would have withheld its item
(none needed it). Suites: app **555**, `stride_core` **674**,
`stride_storage` **108**, `stride_health` **143**; analyze clean; goldens
regenerated and reviewed; migration v6→v7 `rebasesEconomy: false`, v1–v6
fixtures byte-untouched, `v7_baseline.save` frozen, conformance transcript
amended (+255 B, reviewed). **No Health/step-accounting change; no economy
re-basing.** PixelLab: 16 of the cycle's 22 generations spent; world repaint,
project visual states and ambient vibrancy are recorded seams deferred to the
2026-09-16 budget reset. Audio: no canonical owner sources recoverable in the
repo (OD-06 unchanged) — reported, not blocking. Open: Q-06, Q-07 remainder,
OD-04, OD-06.

---

**Version:** 2.10
**Status:** 🚧 **ACTIVITY FEEL & PRESENTATION 01 — device-acceptance
correction pass complete, awaiting the owner's physical-device re-test.**
Branch `playable-phase-2-multiregion`, on top of the milestone's accepted
core (`d6c4675`). Record: `MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md`
§13–§13c (updated device script in the final report).

The owner's phone accepted the milestone's core — install/save, exact
step accounting, timed queueable gathering, the combat timeline fix, enemy
preview, per-visit encounters, loot RNG, the Frost Lynx, rarity, the new
boot mark — and returned corrections, all now implemented:

1. **Finite queues progress across background/lock/relaunch**
   (`DECISIONS/0022`, the one named P-4 exception): the queue is durable
   state at **v6** (`GameState.activityQueue`), reconciled exactly-once by
   wall-clock arithmetic through the same validation/effects path as a
   manual gather — one atomic event carries both the completions and the
   advanced anchor, so no crash, duplicate resume or backward clock can
   split, double or phantom a repetition. No background execution, no
   health sync, no notifications; Stop reconciles then discards the
   partial. Migration v5→v6 `rebasesEconomy: false`; v1–v5 fixtures
   byte-untouched; `v6_baseline.save` frozen.
2. **Prerequisite gating**: an activity the player cannot legally complete
   (skill/tool) is no longer startable — controls disable with the
   concrete reason; the engine's own validation stays as defense in depth.
3. **Blank item art root cause**: the four WRD01 icons were packaged but
   missing from BOTH pubspec and the icon table — every surface drew the
   blank slab. Fixed, and `item_icon_resolution_test` now holds all three
   lists in agreement for every item in the pack.
4. **Defeat reads as retreat**: a PixelLab stagger to a held kneel, an
   enemy settle beat, then DRIVEN BACK; victory holds the enemy's fall
   before the panel. No death imagery, no-loss semantics untouched.
5. **The world is a continent**: the master painting re-authored so the
   playable region is a ~15% north-eastern slice of a landmass (west
   cordillera, forests and lakes, tundra, arid southern plains, island
   sea), every location feature individually resolvable at max zoom
   (blind PASS-WITH-NOTE, decisive on the scale bar; the round-2
   candidate failed blind QA and is kept as evidence). Four landmarks;
   chimney smoke and a second bird flock; the full-width black label
   bars are replaced by text-hugging capsules (~37 world px at the
   survey floor where a bar spanned ~736).

Suites: app **553**, `stride_core` **640**, `stride_storage` **108**,
`stride_health` 143, `stride_secure_store` 31; analyze clean; goldens
regenerated and reviewed; strict verify per the milestone record. Health
untouched; in-place `devicectl` install unchanged. PixelLab balance
167 → **≈18** (art iteration stops until the monthly reset). Open: Q-06,
Q-07 remainder, OD-04.

---

**Version:** 2.9
**Status:** 🚧 **ACTIVITY FEEL & PRESENTATION 01 — implementation complete,
awaiting the owner's physical-device test.** Branch
`playable-phase-2-multiregion`, on top of the device-accepted World & Reward
Depth 01 (`f917a91`). Record: `MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md`
(device script §11).

What changed, in one breath: **gathering is a timed, queueable activity** —
choose Oak Stand, queue ×10, a PixelLab woodcutting loop plays while a
progress bar fills (~12 s per repetition, authored per profession), each
completion spends and grants **exactly once through the untouched
`GatherResource` command**, cancel loses nothing committed, backgrounding
pauses the presentation clock and grants nothing, and cumulative gains
accumulate on the card; the **world is one master painting** — the old
two-tile atlas is retired for a single seamless 384 × 688 PixelLab landmass
at atlas scale 4 (1536 × 2752 world px: alpine north, old-growth hollow,
purple moor, east coast, farmland south, walled Far Town, five landmarks),
so the five playable places read as a small part of a continent slice, the
zoom floor drops to 0.25 (**the whole world frames on a phone**, blind QA:
"CLEAR IMPROVEMENT"), seams and the black dead-wood cluster are gone by
construction, and a threshold LOD keeps the survey view clean; the **combat
heal-back is fixed at its root** (a mid-commit frame leaked post-round HP
into the stage before its replay; the view is now frozen while a command is
in flight) and the wolf's two hits land as two distinct, monotonic HP beats;
the **enemy stands on the encounter card** (grounded combat idle, bounded
visit) before Start Combat; and the **turquoise boot chrome is replaced** by
a PixelLab cuffed traveler's boot in the canonical teal/muted pair (OD-03
closed after three blind rounds and two geometry findings).

Suites: app **531** (incl. 12 activity queue/UI, combat presentation-order,
encounter preview, atlas scale-4 derivation/LOD), `stride_core` 613,
`stride_storage` 108, `stride_health` 143, `stride_secure_store` 31; strict
verify green; goldens regenerated and reviewed. **Nothing in the health /
step-accounting / save path changed — no schema change at all** (the queue
is ephemeral foreground presentation; each repetition is one ordinary
committed gather). The in-place `devicectl` install remains the default.
PixelLab balance 266 → 167. Open: Q-06, Q-07 (rarity order stays closed);
OD-04 skill icons still open; OD-03 (the step mark) **closed**.

---

**Version:** 2.8
**Status:** 🚧 **WORLD & REWARD DEPTH 01 — implementation complete, awaiting
the owner's physical-device test.** Branch `playable-phase-2-multiregion`, on
top of the device-validated Playable Expansion 01 (`e962420`).
Record: `MILESTONES/WORLD_REWARD_DEPTH_01.md` (device script §16).

What changed, in one breath: combat is **repeatable** — an authored number of
fights per enemy per visit (wolf 2, goblin 2, boss 1), reset by travel, never
by the clock, rewards still exactly once, encounter state at **state version
5** (`DECISIONS/0021`); **Frostmere has its first enemy**, the Frost Lynx, on
a PixelLab alpine backdrop; wolves and lynxes drop **pelts** that feed two
narrow smithing recipes; every item carries an **authored rarity**
(Uncommon · Common · Rare · Epic · Legendary — gray / green / blue / purple /
orange, one style table, label beside colour) shown on the **victory panel**
(headline, experience block, framed reward rows with icon · name · rank ·
count, Continue), in Inventory, Craft and Character; the World tab is a
**bigger atlas** — a second PixelLab tile doubles the world southward
(farmland, Millbridge, Ferry Crossing, the road to the Far Town as
non-interactive landmarks), location-kind glyphs under the rings, a **route
preview** with the multi-leg cost, and an **inspector** that lists the real
gathering sites and encounters at a place; the ambient stage **no longer
freezes** after four scenes — an idle cadence of PixelLab micro-idles
(breathe, look around) keeps the Traveler alive while the app is open, the
reading book is book-sized, and `pick_inspect` is out of rotation on a blind
verdict. The east and south-east atlas tiles were generated and **withheld**
after two independent blind Visual QA passes failed the composite on seam
continuity (`MISTAKES.md` M-12).

Suites: **613** `stride_core`, **108** `stride_storage`, app **≈ 500** incl.
combat recurrence / session / UI / stage / victory golden, rarity UI, atlas
schema v2 / scene / inspector / screen, ambient cadence (185). **Nothing in
the health / step-accounting path changed** (the only core change near it is
the v4→v5 table step, `rebasesEconomy: false`); the in-place `devicectl`
install remains the default. Audio remains deferred. PixelLab balance 700 →
335. Open: `JOURNAL/OPEN_QUESTIONS.md` Q-06, **Q-07**.

---

**Version:** 2.7
**Status:** 🚧 **PLAYABLE EXPANSION 01 — implementation complete, awaiting the
owner's physical-device test.** Branch `playable-phase-2-multiregion`, on top
of the device-validated Transformation Build 01 (`f66b29d`).
Record: `MILESTONES/PLAYABLE_EXPANSION_01.md` (device script §10).

What changed, in one breath: the game has **combat** — the three canonical
enemies at their canonical locations, fought on an animated side-view stage
with PixelLab art (Traveler east combat set, wolf / goblin / guardian,
impact effects, three backdrops), Attack · Eat · Retreat, one round = one
command = one commit, a seeded deterministic resolver, character XP and
level feeding HP and attack, the Bronze Sword and Chestplate finally
mattering, victory rewards exactly once, defeat as **retreat with nothing
lost**, an enemy *driven off until you move*, and encounter state in the save
at **state version 4** (`DECISIONS/0020`, `GAME_BIBLE/COMBAT/02`). The
Inventory screen gained the product's first **Equip / Unequip** control
(Woodcutting and Mining were unreachable on the phone without one —
`MISTAKES.md` M-11). The ambient stage is now **one authored composition**
(far scenery behind-left, figure near-right, cat grounded, clipped, a
stretch-square bug fixed; read and pick-inspect corrected through PixelLab and
back in rotation). The atlas got a device pass (bullseye current marker,
contoured route dots, mist off the landmarks, tap/zoom/pan tests). The iPhone
install is now **in place** — `flutter install` was uninstalling first and
deleting the save (`TECHNICAL/IOS_DEVICE_INSTALL.md` §1.4).

Suites: **592** `stride_core`, **108** `stride_storage`, app suite with
combat session / UI / stage / golden, inventory equip, ambient composition
(164 cases) and atlas tests; 13 goldens regenerated. **Nothing in the
health / step-accounting path changed** (the only core change near it is the
v3→v4 table step, `rebasesEconomy: false`). Audio remains deferred — no
owner-supplied source references exist in the repository.

---

**Version:** 2.6
**Status:** 🚧 **TRANSFORMATION BUILD 01 — implementation complete, awaiting
the owner's physical-device review.** Branch `playable-phase-2-multiregion`,
on top of the device-tested Phase 2 build `852cf72`.
Record: `MILESTONES/TRANSFORMATION_BUILD_01.md`.

What changed, in one breath: the World tab is now a **pannable, zoomable atlas**
(viewport + layers + real tap targets over a PixelLab base, `OD-05`), the
Adventure stage plays **PixelLab ambient scenes of the Traveler and an orange
cat** between gathers, every gather node has **its own vignette** on the card,
**all 24 items have icons** (the nine slabs are gone), the **skill icons are a
coordinated PixelLab set** (OD-04 round 2), the next playtest **begins at zero
spendable steps** through a second, owner-authorised economy epoch carried by
**state version 3** (`DECISIONS/0018`; the epoch is marked after the first
sync of the migrating launch, so the pre-cutover backlog is retired too; a
brand-new game retires its first authorised sync the same way, `DECISIONS/0019`), and the iPhone install path is a
**Release build the owner can launch unplugged**
(`TECHNICAL/IOS_DEVICE_INSTALL.md` — the previous "profile" install was in
fact Debug, because Xcode's Run button rebuilds Debug; `MISTAKES.md` M-09).

Suites: **552** `stride_core`, **108** `stride_storage`, app **224** incl.
atlas and ambient tests, 12 goldens regenerated for the new art. Nothing in the
gather / travel / craft / skill / equipment / persistence path changed except
the state-version bump and the migration table.

---

**Version:** 2.5
**Status:** 🚧 **PLAYABLE PHASE 2 — implementation complete, awaiting the
owner's physical-device acceptance.** Branch `playable-phase-2-multiregion`,
from the approved UI baseline `3dd892d`.
Records: `MILESTONES/PLAYABLE_PHASE_2.md`,
`MILESTONES/PLAYABLE_PHASE_2_ACCEPTANCE.md`.

Five locations across four terrains, real travel that spends real steps, all
five skills in the loop, a working Craft screen, and the **OD-01 economy
cutover** — the playable balance now begins at zero without deleting history,
lowering `totalGranted`, or rewinding the health cursor (`DECISIONS/0016`).

**Starting a fresh session? Read**
`MILESTONES/FRESH_CHAT_HANDOFF_2026_08_17.md` — the canonical snapshot written
after the first Phase 2 device review. It carries the device findings, the
current content tables, the settled owner directions (OD-05 atlas, OD-06 audio,
combat, dungeons, ambient life), and a **DO NOT RESURRECT** list. This document
remains canonical for project state; the handoff is the orientation map.

**The finding worth carrying from this milestone** is in `MISTAKES.md` **M-07**:
every structural validator passed and the loop was still unplayable, because
none of them plays it.

**OD-01 and OD-02 graduate** into `DECISIONS/0016`, `DECISIONS/0017` and
`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`. **OD-03 and OD-04 stay
open** — a specified icon round was generated and **failed independent blind
QA**, and was not shipped.

---

**Version:** 2.4
**Status:** ✅ **PLAYABLE DEMO PHASE 1 — CLOSED.** All twenty acceptance criteria
met on a physical iPhone (`eae7700`, iPhone 10 / iOS 26.6), verdict **PASS**
signed by the owner on 2026-08-16 under `MISTAKES.md` M-04. The whole loop runs
through the **product UI**, not the dev harness.
Record: `MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md`.

✅ **UI FACELIFT 01 — CLOSED, OWNER APPROVED**, 2026-08-17, on a physical
iPhone. Branch `ui-facelift-01`. Record: `MILESTONES/UI_FACELIFT_01.md`.
**D-01 is closed** — the owner confirmed the full `459,043` renders on all four
screens. Ten of ten closure criteria PASS.

**Current Phase: Playable Phase 2, awaiting device acceptance.** F-07 is **done**
(`SkillStanding`, in `stride_core`). OD-01 and OD-02 are **implemented and
graduated**; OD-03 and OD-04 are **specified, attempted, and still open**.

## Project identity

Project Stride is a mobile-first, solo **step-powered asynchronous RPG with idle-style planning**, with MMO-style long-term progression. Real-world walking powers travel, gathering, exploration, crafting preparation, and adventure.

Built in Flutter for **Android and iOS**. Android first, for interactive development on Windows; iOS kept compiling continuously in CI.

Progression is step-clocked: activities advance only from earned steps, never from wall-clock time. "Idle" means asynchronous planning, offline reconciliation, and delayed collection.

## Current design status

Completed foundations:

- Project identity and vision
- Design pillars and player promise
- Non-negotiables and anti-features
- AI agent roles and studio workflow
- Core gameplay loop
- Progression, skills, crafting, economy, inventory
- World, travel, and exploration direction
- PvE combat philosophy
- Mobile UX direction
- Audio identity
- Apple Health step-integration direction
- Starter-region content
- Milestone 01 vertical-slice definition
- Milestone 01 implementation sequencing
- Studio initialization audit (`STUDIO_INITIALIZATION_REPORT.md`)

## Approved foundation decisions

| # | Decision | Record |
|---|---|---|
| 0001 | Progression is step-clocked only | `DECISIONS/0001_PROGRESSION_CLOCK.md` |
| 0002 | ~~Native Swift + SwiftUI~~ — **superseded by 0010** | `DECISIONS/0002_TECHNOLOGY_STACK.md` |
| 0003 | Turn-based, retreat-not-death combat; no combat skills in M01 | `DECISIONS/0003_COMBAT_MODEL.md` |
| 0004 | M01 scope frozen — no currency, no merchants, five skills, six tabs | `DECISIONS/0004_MILESTONE_01_SCOPE.md` |
| 0005 | Audio sourcing — lean prototype budget, full provenance, replaceable asset IDs | `DECISIONS/0005_AUDIO_SOURCING.md` |
| 0006 | One activity at a time; travelling and gathering are a choice | `DECISIONS/0006_SINGLE_ACTIVITY.md` |
| 0007 | Loop validated in one to two weeks; maxing skills not required | `DECISIONS/0007_PROGRESSION_PACING.md` |
| 0008 | Earned opportunity never expires; nothing decays | `DECISIONS/0008_STEPLESS_WEEK.md` |
| 0009 | Portrait only, phone only, no store launch — *amended for Android* | `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md` |
| 0010 | **Flutter, pure Dart core, first-party health adapters, Android first** | `DECISIONS/0010_CROSS_PLATFORM_STACK.md` |
| 0011 | Staged private distribution — APK → Play internal; TestFlight later | `DECISIONS/0011_DISTRIBUTION_CHANNELS.md` |
| 0012 | Two slots, CAS, cursor authority, origin privacy | `DECISIONS/0012_SAVE_FORMAT.md` |
| 0013 | **Single-writer-isolate persistence; no background writer until S-01** | `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md` |
| 0014 | **S-01A precedes F-07; foreground health only, no background delivery** | `DECISIONS/0014_S01A_PRIORITY_AND_SCOPE.md` |
| 0015 | No change is a delivery kind | `DECISIONS/0015_NO_CHANGE_IS_A_DELIVERY_KIND.md` |
| 0016 | **The playable economy begins at an epoch, not at zero granted** | `DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md` |
| 0017 | **Phase 2 scope — five locations, travel and crafting as commands** | `DECISIONS/0017_PHASE_2_SCOPE.md` |
| 0018 | **Transformation playtest epoch — state v3, marked after the first sync** | `DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md` |
| 0019 | **A new game retires its first authorised reconcile; spendable-zero baseline** | `DECISIONS/0019_NEW_GAME_BASELINE.md` |
| 0020 | **Combat Slice 01 — encounter state in the save (v4), one round = one commit, driven-off rule, retreat to the nearest safe place** | `DECISIONS/0020_COMBAT_SLICE_01.md` |
| 0021 | **Repeatable encounters per visit (v5), authored item rarity, derived location kind** | `DECISIONS/0021_REPEATABLE_ENCOUNTERS_AND_RARITY.md` |

## Current milestone

**Milestone 01 — First Adventure Vertical Slice**

The vertical slice must prove:

> Walking in real life creates a satisfying loop of planning, progression, crafting, travel, and active solo PvE adventure.

## Required player experience

The player must be able to:

1. Read and reconcile real-world steps
2. Apply those steps to an intentional activity
3. Travel to a destination or progress a gathering activity
4. Gain resources and skill experience
5. Craft or equip an upgrade
6. Enter and complete a PvE encounter
7. Save progress locally
8. Return later and clearly understand what changed

## Immediate next actions for Claude Code

1. ~~Audit the repository for contradictions or missing dependencies.~~ **Done**
2. ~~Produce `STUDIO_INITIALIZATION_REPORT.md`.~~ **Done**
3. ~~Recommend and document the initial mobile technology stack.~~ **Done — `DECISIONS/0002_TECHNOLOGY_STACK.md`**
4. ~~Create `ARCHITECTURE_IMPLEMENTATION_PLAN.md`.~~ **Done — awaiting owner approval**
5. ~~Create `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`.~~ **Done — awaiting owner approval**
6. ~~Run design, critic, and QA review on those plans.~~ **Done — `DESIGN_REVIEW.md`, `CRITIC_REPORT.md`**
7. ~~Wait for owner approval before production implementation.~~ **Approved 2026-08-01**
8. ~~Execute F-01 (Swift).~~ **Authored, never compiled — paused, see below**
9. ~~Reopen the technology-stack decision.~~ **Done — `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`**
10. ~~Owner approval of the Flutter recommendation.~~ **Approved 2026-08-01**
11. ~~Revise architecture, structure, CI, and task plan; run four-role review.~~ **Done**
12. ~~Owner approval of the revised plans.~~ **Approved 2026-08-01**
13. ~~Execute migration M-1, M-2, M-3.~~ **Done — `MIGRATION_COMPLETION_REPORT.md`**
14. ~~Owner review at the M-3 stop gate.~~ **Approved**
15. ~~Execute M-4 — cross-platform CI validation.~~ **Done — `M4_CI_COMPLETION_REPORT.md`**
16. ~~Owner approval of M-4.~~ **Approved**
17. ~~Execute M-5 and M-6 — retire the Swift scaffold, close the migration.~~ **Done — `MIGRATION_CLOSURE_REPORT.md`**
18. ~~Owner approval of the closed migration.~~ **Approved**
19. ~~Execute F-02 — content schema, loader, validation.~~ **Done — `F02_COMPLETION_REPORT.md`**
20. ~~Owner approval of F-02.~~ **Approved**
21. ~~Execute F-03 — state, commands, events, engine.~~ **Done — `F03_COMPLETION_REPORT.md`**
22. ~~Owner approval of F-03.~~ **Approved**
23. ~~Execute F-04 — step ledger and reconciliation.~~ **Done — `F04_COMPLETION_REPORT.md`**
24. ~~Owner approval before F-05; answer the escalated privacy question.~~ **Approved 2026-08-02**
25. ~~Fix the three lost-grant defects the F-05 critic review found in F-04.~~ **Done — commit 8336774**
26. ~~Answer the four blocking F-05 decisions.~~ **Ruled 2026-08-02**
27. ~~Execute F-05 — save, ledger persistence, crash recovery.~~ **Done — `F05_COMPLETION_REPORT.md`**
28. ~~Owner approval before F-06.~~ **Approved 2026-08-02**
29. ~~Execute F-06 — device persistence, bootstrap, restart validation.~~ **Done — `F06_COMPLETION_REPORT.md`**
30. ~~Re-run CI and the Android process-death workflow against the final tree.~~ **Done — both green, `F06_COMPLETION_REPORT.md` §10**
31. ~~Execute F-07 — skill framework.~~ **Deferred by owner priority decision — `DECISIONS/0014`**
32. ~~Execute S-01A — foreground HealthKit and Health Connect integration with a device-validation harness.~~ **Done — closed on a physical iPhone, `S01A_PHYSICAL_VALIDATION.md`**
    - **Android foreground vertical slice implementation-complete**, branch `s01a-foreground-health-harness`.
      Real steps → `SyncResponse` → `ReconcileStepSync` → `GameEngine` → durable save →
      usable energy → `GatherResource` → persisted, verified across a relaunch.
      See `S01A_IMPLEMENTATION_MAP.md` and `S01A_DEVICE_VALIDATION.md`.
    - **Android physical validation PAUSED by owner priority.** The implementation is
      preserved and compiling; no Android-only work continues this milestone.
    - **iOS-first pivot.** The Swift HealthKit adapter was already complete; the shared
      vertical slice, harness, engine and save are platform-neutral and unchanged.
      21 further assertions cover the iOS configuration facts a compile cannot catch.
      See `S01A_IOS_READINESS.md`.
    - **Installation route: direct Xcode install, free Personal Team.** The owner has
      a Dell Windows PC (primary development machine), a Mac (sign-and-install station
      only), an iPhone, and an ordinary Apple Account. **No paid Apple Developer
      membership, and none needed.** Flutter cannot build iOS on Windows, which is why
      the Mac is in the loop; the macOS CI job builds `--no-codesign` and is therefore
      evidence that the code compiles and nothing more. Pending: Mac setup, then the
      physical device run. No further code change is required to create the path.
      An earlier revision recorded no Mac and called this blocked; that was wrong
      about the hardware and is withdrawn.
    - **CLOSED on real hardware.** Free Personal Team signing succeeded, the app
      installed and ran on the owner's iPhone, and the vertical slice passed end to
      end against real HealthKit data. The first device run found one real defect
      (`cursorOfferedWhenProhibited` on seven of eight pages); it was inert, it is
      fixed, and the re-run reported zero faults. `S01A_PHYSICAL_VALIDATION.md`.
33. **Define the player-facing / design milestone.**
    - Foreground health, the save, and the gather loop are validated on hardware;
      the next milestone is a design conversation, not a continuation of this one.
      **Still open — no player-facing milestone has been defined.**
    - F-07 (skill framework) is unblocked. S-01B (background sync) remains blocked on
      a real persistence coordinator and is not the automatic next step.
    - Governance layer added: `RULES.md`, `MISTAKES.md`, `GAME_BIBLE/ART/`.

34. **Visual exploration and correction.** — superseded by 35.
    - The active work was visual. See *Current visual phase* below, which is
      preserved as the record of the hand-authored rounds and is **no longer the
      live pipeline**: PixelLab is the approved production-art route.

35. **PLAYABLE DEMO PHASE 1 — implementation complete.** ← current state
    - The owner can launch, sync real steps, spend them on a gather, receive
      loot and XP, see inventory and progression update, view the location
      vignette and the region map, restart, and find the state intact —
      **through the product UI**.
    - Four working destinations: Adventure, Inventory, Character, **World**.
      Skills and Craft are visibly disabled. No dead active controls.
    - Production art is PixelLab's, packaged reproducibly by
      `Scripts/art/package-art.js` and checked in CI.
    - **Both carried visual corrections are closed** — the region map's
      watercourse and gather frame 5.
    - Visual QA ran on a real running build and found three defects the tests
      and goldens were structurally incapable of finding. All three are fixed.
      See the closeout's §4; this is the lesson most worth carrying.
    - **95 app tests, 4 goldens.**
    - Records: `MILESTONES/PLAYABLE_DEMO_PHASE_1_PLAN.md` (plan),
      `PLAYABLE_DEMO_PHASE_1_CLOSEOUT.md` (what shipped, what is limited),
      `PLAYABLE_DEMO_PHASE_1_ACCEPTANCE.md` (the owner's device script).
    - **Physical acceptance RUN AND PASSED.** All twenty criteria met on the
      owner's iPhone: the S-01A save loaded and was corroborated to the step
      against `S01A_PHYSICAL_VALIDATION.md`; a 47,395-step backlog drained
      exactly once; a gather spent exactly 90, yielded ×2 and +10 XP with
      `TOTAL WALKED` unmoved (H-2); state survived a force-quit and a
      Home Screen cold launch with no flash of zeros; and **two consecutive
      syncs granted nothing the second time**.
      Full record: `MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md`.
    - **Two run variables**, deliberately not corrected mid-run: the Mac had
      **Flutter 3.47.0**, not the pinned 3.44.8 (it compiled the branch cleanly
      with no source changes — the first favourable data point for the deferred
      3.47 evaluation, and not that evaluation); and the build was **profile**,
      because iOS 14+ will not launch a JIT debug build from the Home Screen.
    - ✅ **CLOSED.** Verdict **PASS**, written by the owner on 2026-08-16 —
      qualified under M-04, having run the script and not built the feature.
      This is the first milestone the owner has closed by *playing* the product
      rather than by reading a report.

    - **Open defect D-01 — the banked-steps header clips its final digit.**
      Presentation only; every value and invariant is correct. A fixed 72 dp
      box with `TextOverflow.clip` cannot hold a seven-character figure like
      `455,281`. **Deferred by owner decision to the UI facelift.**
      `TextOverflow.clip` raises no exception and the goldens render a
      six-character figure, so neither the overflow tests nor the goldens could
      see it — `MISTAKES.md` M-06 a third time. Detail and the required shape of
      its regression test are in the device result, §5.
      **Fixed on `ui-facelift-01`; closes on the owner's device review.**

36. ✅ **UI FACELIFT 01 — CLOSED, OWNER APPROVED.** ← current state
    - Branch `ui-facelift-01`. Record: `MILESTONES/UI_FACELIFT_01.md`.
    - **Closed across three physical-device reviews**, each of which changed the
      work. Review 1 passed the responsive hardening and **refused** the facelift
      — *"cleaner and safer, but visually it still feels too close to Phase 1"*.
      Review 2 passed the recomposition and asked for the activity stage back as
      real animation space. Review 3 passed the 180 dp stage, ten of ten.
    - **The owner's refusal to certify a 4 dp margin from desk evidence is the
      most reusable thing in this milestone.** Measuring it properly found the
      estimate wrong by 60 dp on one viewport family, and found a **cliff**: at
      375 dp a 180 dp stage leaves 127 dp for a title that measures 137.3, so the
      card falls back to stacking and the gather button drops ~94 dp. No
      arithmetic in a comment would have found that.
      `test/fold_clearance_test.dart` now asserts it on five viewports with real
      safe-area insets, and is mutation-checked.
    - **Deferred by owner decision at closure**, not omitted: remaining minor
      visual polish; **OD-03**, one canonical pixel step-economy mark to replace
      the temporary turquoise boot; **OD-04**, a cohesive PixelLab skill-icon set
      as one workstream against one specification. No assets were generated.
    - **D-01 fixed as a shape, not as a number.** A new `AdaptiveText`
      primitive is the one implementation of "this text must not lose a
      character"; `bankedFigureWidth` became `bankedFigureMinWidth`, so the
      stability the fixed box bought is kept and the figure takes the width it
      needs; a new `ValueTileRow` stacks tiles that no longer fit rather than
      shrinking type to reach them.
    - **The audit's new measurement found two further shipped defects** the old
      evidence was structurally incapable of seeing: `EXPERIENCE` clipped in the
      third cost tile at 320 / 360 / 393 dp, and the step cost `90` given 16 dp
      where it needed 19.8. Both fixed.
    - **The kind of evidence changed.** Every single-line paragraph in the tree
      is checked for `required width ≤ laid-out width`, replacing
      `takeException() == null`, which `TextOverflow.clip` can never fail. A
      **real font is loaded**, in the responsive tests and in the goldens, and
      its absence fails rather than skips — the harness fallback is ~50% wider
      than any font this app ships against.
    - Facelift: shorter tab bar, larger and more prominent primary button, the
      redundant `AVAILABLE` row and the two `→` glyphs removed, Character's two
      identity cards merged into one, a `YOU ARE HERE` caption under the region
      map, and the inventory grid's density and label weight raised.
    - Composition pass, after review 2: the walking card became a ~70 dp band,
      `Sync steps` became a secondary control, the activity stage moved beside
      the node identity and then grew to a 180 dp animation viewport with the
      figure bottom-aligned, the inventory grid gained a frame and category
      grouping, Character's progression figures gained weight against the
      portrait, and `YOU ARE HERE` moved onto the map.
    - **165 app tests, 8 goldens**, all green; `verify.sh --strict` passes. No
      gameplay, command, reducer, save, ledger or health path was touched.
    - **Still unseen on hardware:** the 375 dp and 360 dp stacked fallback. It is
      measured, asserted and accepted — a scroll rather than a crushed title —
      but the owner's device took the side-by-side branch, so nobody has looked
      at it running. Measured and accepted is not the same as seen.

## Next planned activity

### Project Stride Visual Exploration 01

**Purpose:** compare three visual directions using the **same canonical scene**
before choosing a production art direction.

Candidates, status, and the exploration rule live in
`GAME_BIBLE/ART/ART_DIRECTION.md`, which is in **EXPLORATION** status — no art
direction is chosen, and palette, sprite dimensions, camera angle, animation
frame counts, rendering treatment, character proportions, and final UI visual
language are all explicitly unresolved.

#### Canonical comparison scene

Every direction depicts the same content:

- Player character
- Haven's Rest
- Meadow Patch
- Starter Traveler gear
- One gatherable resource
- One NPC
- Basic mobile HUD

**All three directions must depict the same scene and the same content**, so
the comparison is about art direction rather than about composition. A
direction that changes the subject is not comparable and does not count as one
of the three.

Subjects are defined in `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`; HUD
structure in `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`.

**Superseded in part.** Art has since been generated as exploration proofs, audited,
and found perceptually failing. The comparison plan stands; the round it describes
must be re-run on a corrected shared base. See below.

### Current visual phase — corrections, before any identity comparison

**Status:** direction locked, correction work not yet started. No art is approved.

| Step | State |
|---|---|
| `VISUAL_STUDIO_BASELINE_AUDIT_01` — five-agent specialist and blind-QA audit | ✅ Done. Character, Environment and UI all returned **QA FAIL** |
| `VISUAL_STUDIO_CORRECTION_01` — render-set and craft-spec hardening | ✅ Done — `5d4664b` |
| **Visual Owner Direction Round 01** | ✅ **Done** — fifteen locks recorded in `GAME_BIBLE/ART/ART_DIRECTION.md` |
| `CHARACTER_READ_SPEC_01` | ✅ **Done — FROZEN 2026-08-14**, `GAME_BIBLE/ART/CHARACTER_READ_SPEC_01.md`. 102 items, 28 load-bearing |
| `CHARACTER_REBUILD_01` → Visual QA | ⬅ **next** — Character Pixel Artist against the frozen spec |
| Haven's Rest Base 02 | Not started |
| UI correctness pass | Not started |
| A1/A2/A3 re-run on the corrected base | Not started, and **not** rankable before then |

**The Traveler has not graduated.** OR02, R03, R03F and R03C are
**structurally informative, perceptually failed, and not the approved base
character**. They are evidence for the next attempt, which is **not** required to
preserve their body silhouette — preserve the useful discoveries, not the failed
geometry. There is deliberately no `TRAVELER_BASE.md`.

**Haven's Rest Base 01 and the A1/A2/A3 round are preserved as historical
exploration evidence** and are not production world art. The two exploration
directories carrying the failing evidence remain deliberately uncommitted.

The audit's own governing finding is recorded as `MISTAKES.md` M-05: the evidence
set contained no ×2 play-scale view, so every visual decision to that point had
been taken at inspection scale.

## F-05 closed the four decisions

All four were ruled on 2026-08-02 and implemented: two-slot ping-pong snapshots, compare-and-swap on every commit, save-authoritative balance profile, and the journal as a bounded recovery log rather than an event store. Recorded in `DECISIONS/0012_SAVE_FORMAT.md`.

## Ten root causes fixed during F-05

Four sub-agents ran against compiling code. They found a durable commit that reported failure and froze the step cursor; a `core.autocrlf` hazard that would have broken the frozen save fixture on any second machine; and unconstrained bucket *resolution*, which would have made a minute-by-minute activity log fully compliant with the retention ruling.

**The most serious was mine.** LG-3 — the origin-blind horizon that discarded a returning player's backlog — was fixed, committed, and reported closed at `8336774` with a passing regression test. The fix was inert: a single global watermark cannot express "settled for the phone, still open for the watch", and the test passed only because it never asserted completeness. Closed properly at `ae06719` with per-origin watermarks.

Full detail: `F05_COMPLETION_REPORT.md` §8. Review: `DESIGN_REVIEW_F05.md`.

## Milestone 01 progress

| Task | Status |
|---|---|
| F-01 — project skeleton, core purity | ✅ Done (Flutter form, M-2/M-3) |
| F-02 — content schemas and loader | ✅ Done |
| F-03 — GameState, events, engine | ✅ Done |
| **F-04 — step ledger and the thirteen scenarios** | ✅ **Done** |
| **F-05 — save, ledger persistence, crash recovery** | ✅ **Done** |
| **F-06 — device persistence, bootstrap, restart validation** | ✅ **Done** |
| **S-01A — foreground HealthKit + Health Connect, device harness** | ✅ **Done — validated on a physical iPhone** |
| **Playable Demo Phase 1 — the product UI** | ✅ **Implementation complete** — awaiting physical device acceptance |
| F-07 — skill framework | **Unblocked** — foreground health is validated (`DECISIONS/0014`) |
| S-01B — background synchronization | Blocked on a real persistence coordinator |

**S-01A closed on physical hardware.** Real iPhone, free Personal Team signing,
real HealthKit data: two syncs with **zero faults**, 961 steps newly granted
against a preserved 407,105, gathering spending 90 energy for 2 Meadow Herb, and
every figure surviving force-close and relaunch. Full evidence in
`S01A_PHYSICAL_VALIDATION.md`.

The one defect the first device run found — `cursorOfferedWhenProhibited` on
seven of eight pages — was a native adapter offering a candidate cursor
mid-read. It was inert (nothing prohibited ever became durable, so the save was
never reset), it is fixed in `5b68d33`, and the fix is confirmed on hardware.

**678 automated Dart tests**, zero skipped: 357 `stride_core`, 108 `stride_storage`, 31 `stride_secure_store`, **165 app**, 17 `stride_health` — plus **38 Swift simulator tests** and 5 Kotlin in CI.

Final F-06 verification: CI run **`30780992412`** (all four jobs green) and Android process-death run **`30781003035`** (PASS), both against `2d20280`.

### The F-06 finding worth carrying forward

A green **Windows** run is not evidence for anything lock-shaped. POSIX `fcntl`
locks are owned by the *process*; Windows `LockFileEx` locks are owned by the
*handle*. CI run `30767931205` was the first time four storage test files ran on
Linux: 94 passed, **11 failed**, against 105/105 on Windows — including
`totalGranted` of 7 where 0 was required. **Linux is the signal.** See
`DECISIONS/0013` and `TECHNICAL/PERSISTENCE_CONCURRENCY.md`.

`stride_core` is 31 files of pure Dart — no Flutter, no plugins, no `dart:io`, and now no clock, randomness, locale, or platform reads either, enforced by a static source scan.

## Current documents

| Document | Purpose |
|---|---|
| `ARCHITECTURE_IMPLEMENTATION_PLAN.md` | v2.0 Flutter — the technical plan |
| `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` | v2.0 — 41 tasks, review findings applied |
| `TECHNICAL/PROJECT_STRUCTURE.md` | Package layout and the Pigeon boundary |
| `.github/workflows/ci.yml` | Build matrix — Linux for Dart/Android, macOS for iOS |
| `TECHNICAL/PROJECT_SETUP.md` | How to build and verify |
| `TOOLCHAIN_REPORT_WINDOWS.md` | Verified Windows toolchain |
| `FILE_MANIFEST.md` | Full inventory, active vs. historical |
| **`S01A_PHYSICAL_VALIDATION.md`** | **S-01A closure — the physical iPhone run, and what it does not prove** |
| `S01A_IOS_READINESS.md` | iOS install route, the device sequence, the cursor defect record |
| `S01A_IMPLEMENTATION_MAP.md` | Where each S-01A piece lives |
| **`MIGRATION_CLOSURE_REPORT.md`** | **M-5/M-6, final CI, recommended F-02 scope** |
| **`F05_COMPLETION_REPORT.md`** | **Save format, crash recovery, the ten root causes** |
| **`DECISIONS/0012_SAVE_FORMAT.md`** | **Two slots, CAS, cursor authority, origin privacy** |
| `MIGRATION_EXECUTION_PLAN.md` | M-1 to M-6, with acceptance criteria |
| `DESIGN_REVIEW_FLUTTER.md` | Four-role review, approved with changes |
| `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md` | Why Flutter |

Archived, not deleted: `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`, `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`, `DECISIONS/0002` (superseded).

## Migration closed

**M-1 through M-6 complete.** See `MIGRATION_CLOSURE_REPORT.md`.

Repository: `thcwtnnp5s-del/project-stride` — **public, intentionally** — branch `master`, all history preserved including the superseded Swift scaffold at `859d0ac`.

**The repository is deliberately public.** An earlier revision of this line recorded it as private; that was stale documentation, corrected 2026-08-14 after `gh repo view` reported `visibility=PUBLIC`. Public visibility is the owner's intent and is not to be changed. `DECISIONS/0011` governs **app** distribution channels and is unaffected — source visibility and distribution are different questions.

One consequence is worth stating where a future session will see it, because it is a property of the setup rather than a problem with it: `.github/workflows/ci.yml` runs on `pull_request`, so on a public repository that workflow can execute fork-authored code. The workflow already declares least-privilege permissions rather than inheriting them. **Nothing about CI permissions, workflow behaviour, branch protection, or repository access was altered by this correction.**

**CI green on all four jobs** — run `30752832663`. **44 automated tests**: 17 Dart, 5 Kotlin, 12 Swift, plus the Dart suite re-run on macOS.

| Job | Runner | Covers |
|---|---|---|
| Dart core | ubuntu | Guards, format, analyze (fatal), 17 tests |
| Pigeon bindings | ubuntu | Three-way contract drift |
| Android | ubuntu | Both debug APKs, 5 Kotlin tests |
| iOS compile | **macOS** | Pigeon verify, 17 tests, app + Swift adapter compilation |

**The iOS branch compiles and its adapter is behaviorally tested.** It did not compile on its first attempt — `HealthKitAdapter.swift` was missing `import Flutter`, invisible to every tool on Windows. That single finding justifies the macOS job.

The Swift scaffold was retired at M-5. All ten `.claude/agents/` definitions, which still described the native-Swift stack, were corrected — they load as standing context and were the likeliest way a future agent could have been misled.

### No blockers

### Apple: validated on hardware

**Superseded.** This section used to say the adapter was tested and the platform
was not — true until S-01A closed, and no longer. Real HealthKit reads, the
save, and the gather loop are now verified on the owner's physical iPhone under
free Personal Team signing: `S01A_PHYSICAL_VALIDATION.md`.

Still unverified on hardware, and deliberately listed so a passing run is not
read as covering more than it did: background sync (S-01B, never started),
deletion escalation, cursor invalidation and recovery, denied permission, and
iCloud restore onto a second device (which needs two iPhones and an iCloud
account). Android physical validation remains paused by owner priority;
`HealthConnectAdapter` is implementation-complete and compiling, with cross-adapter
equivalence (V-02b) still outstanding.

A Mac is needed to build and sign the iOS app and remains a sign-and-install
station only. The Apple Developer Program was never required.

### Toolchain

| | |
|---|---|
| Flutter | ✅ 3.44.8 at `C:\Users\<username>\dev\flutter` |
| Dart | ✅ 3.12.2 |
| JDK | ✅ Temurin 17.0.20 |
| Android SDK | ✅ platform-36, build-tools 36.1.0, adb, emulator |
| AVD | ✅ `stride_pixel` (API 36) |
| GitHub CLI | ✅ 2.97.0, authenticated |
| Xcode | ➖ iOS-only; CI macOS job covers compilation |
| CI Flutter | 📌 pinned to exact 3.44.8 in `.github/workflows/ci.yml` |

#### Why CI pins its Flutter version

CI followed `channel: stable` with no version. When stable moved 3.44.8 →
3.47.0, `dart format` changed its output and the format check began failing on
three files nobody had touched since early August — on master as much as on any
branch. A CI result that depends on the date the run was started is not
evidence, so the version is now exact and matches the development machine.

#### Follow-up: evaluate Flutter 3.47 deliberately (not blocking)

Worth doing, on its own branch and its own milestone: upgrade, reformat what the
newer `dart format` wants, run the full suite, and look for behaviour changes
across `stride_core` and `stride_storage` before unpinning. It was deliberately
**not** done inside the S-01A HealthKit cursor fix — a toolchain bump landing in
the same commit as the evidence meant to validate a defect fix makes neither
trustworthy. Nothing is broken while pinned; this is scheduled work, not debt
that is accruing.


## Open gaps to close during Milestone 01

| ID | Gap | When |
|---|---|---|
| G-04 | No visual identity document | Task P-01, before Phase 5 |
| G-06 | No derived balance numbers | Task S-06 |
| G-09 | No privacy policy artifact | Task S-07 |

*(G-05 closed by `DECISIONS/0005`; G-07 closed by the reviewed task breakdown.)*

## Deferred features

- Multiplayer
- Trading
- Guilds
- PvP
- Live-service events
- Monetization
- Paid currencies
- Social pressure systems

## Active risks

- Feature creep
- Overengineering before validating the loop
- Inconsistent step accounting
- Health-data privacy mistakes
- Generic or menu-heavy presentation
- Combat disconnected from walking and preparation
- Audio being deferred until the end
