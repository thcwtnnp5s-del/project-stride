# Fable 5 Executive Production Overhaul 03 (EPO03)

**Opened:** 2026-09-02 · **Branch:** `fable5-executive-production-overhaul-03`
(from `fable5-mega-production-overhaul-02` @ `59c4723`) · **Status:** closed out 2026-09-03,
awaiting the owner's physical iPhone verdict · **Authority:** the owner's EPO03 directive (2026-09-02), quoted in
§1; `DECISIONS/` entry recorded in §4 · **Not merged.** The physical iPhone
remains the final authority.

Evidence: `MILESTONES/evidence/EPO03/wave0..3/` (guardians, directors,
producers, QA), `GAME_BIBLE/ART/exploration/EPO03/` (sources, accepted art,
review renders, rejected rolls with verdicts, per-family ledgers).

## 1. The verdict this answers

The owner's physical-iPhone read of `59c4723` (FMPO02 closeout, v2.40):
typography, Character, Inventory, gathering architecture, equipment
projection, encounter staging, Craft structure, some world regions and the
visibility of world life are **better**. Not good enough: the world still
reads stitched in places with uneven biome transitions; fantasy landmarks and
world life are not convincing; the UI is still systematised dark cards
("Claude generated"), Skills detail stacks rectangles, Craft's locked half
becomes a spreadsheet, the bottom nav is plain, the World sheet hides the map;
equipment must become fully convincing with no fallback; audio is incomplete.

The owner's explicit authority for this round, verbatim:

> "The owner is explicitly authorizing aggressive replacement of weak existing
> art and layout in order to reach a substantially higher quality bar." · "If a
> section of the atlas cannot be salvaged cleanly: overwrite it." · "some older
> terrain should not be protected merely because it exists." · "THE MAP MAY BE
> REPAINTED. THE REGIONS MAY BE RECOMPOSED. THE UI MAY BE REBUILT. THE OLD CARD
> STRUCTURE MAY BE REMOVED."

Acceptance target: **"This feels like a much more finished game."**

## 2. Doctrine

1. **Quality over preservation.** A weak region, screen or asset is replaced,
   not defended. Sunk cost is not an argument.
2. **Coherence over history.** Where a patch made a seam, both sides are
   re-authored as one transition; where a region is compositionally broken,
   the region is repainted, not the seam.
3. **Visible player value over internal cleverness.** A generation is
   justified only by what the phone shows.
4. **Protection stays in tooling.** Replacement inside a protected zone is
   done by re-basing the protected state in code (a new approved interior and
   re-extracted goldens in the same commit), never by weakening the guard
   (G-4, A-4).
5. **The single-defect loop stands for the atlas** (`STUDIO_OPERATIONS/
   WORKFLOW.md`, "World-atlas repairs"): one region → composite → guards →
   full atlas + ×2 perimeter + phone FOV → verdict → next.
6. **Nothing in the locks moves.** Health, ledger, save, epoch, replay,
   single-writer, sync policy, craft step cost, defeat rules, no-FOMO,
   strategic travel.

## 3. What landed, by workstream

Grouped rather than listed: the round is 190 commits. Each row names the commits a reader would open first;
`git log 59c4723..HEAD` is the full sequence.

| Workstream | Key commits | What a player gets |
|---|---|---|
| **Foundation and authority** | `6a9a2d9`, `9cabe4f`, `2161e8f`, `ce30361` | The workspace, `DECISIONS/0033` (the owner may replace the approved atlas), and the compositor that re-bases the protected interior instead of weakening the guard: claimed pixels, a re-taken snapshot, a whole-canvas drift walk, five per-team manifests. |
| **Direction** | `f6ef89e`, `91f196f` | Sixteen director briefs and the binding production rules, including the four-at-a-time batching and interruption discipline (§9a) and the measured tool limits (§2a). |
| **The south coast (P0)** | `d28e6b0`, `111879f`, `3419c76`, `8630ddf`, `1f18327` | The latitude stripe is gone. A bending shore with surf, angled dunes, machair, a creek at a rock headland, braided channels into flats and a spit hooking south; the Sunward Strand still stands on sand. Two rolls rejected by changing intent, not seed. |
| **The west** | `1d3e6cc`, `38a6366`, `a26f1e8` | The core forest’s west face breaks into bays, a promontory and stepping copses — the wall inside the protected core that the previous round could not reach. The pass road turns around something at every bend; the y=700 join with the south is bridged. |
| **Three destinations** | `f9f48b7`, `14827ae`, `6145ce5`, `1a0a477` | The ice tower is an ice bastion on a glacial foundation; the storm house a black gable with lit windows among blasted trees; the fairy castle grows from three birches over a flower-ringed pool. All painted into the terrain, so they survive the overview zoom where the old props vanished. Four overlays give them motion. |
| **World life** | `46c4b13` | Overlay schema v6: waypoint paths, breath followers, shadows and depth ordering — and Reduce Motion now pins the world rather than emptying it (M-16’s rule applied). |
| **The interface kit** | `d32a01f`, `5b92ef6`, `80463ee`, `3e1fa02`, `acee668` | Thirteen shared rows — frames, tiles, ornaments, a category rail, an illustrated header, a page edge — plus the button plate wired through all 43 call sites, replacing the old plate’s corner ticks with a continuous rim. |
| **The navigation bar** | `ade5a62`, `2db6fe6`, `771930e` | A leather strap into the home-indicator inset, stamped icon wells, a raised lit plate breaking the stitched welt, one glyph per destination, and the corner radius retired square so every screen inherits the fix. |
| **Skills** | `75e1508`, `48da1b1` | The detail screen stops stacking rectangles: a road with a joint at every level, a lit lantern cairn at "you are here", unlocks unboxed on spurs, level badges blank stone with the number set in type. |
| **Equipment** | `8b26127`, `4629993`, `6d52c60` | The starting loadout can brace; the Waywarden’s Tunic stops resolving to the shirt; the Bronze Longsword is actually a longsword — a blade half again as long with a cross-guard, across four bodies and five tracks; the Waywarden gets a body in every context. |
| **Combat** | `949f939` | Attack, the Eat choice and Retreat answer the hand — the three commands that fired no haptic. |
| **Record and correction** | `4bd31ca`, `38a31e2`, `6d24b9a`, `0232226`, `d7a9fae` | The first executive checkpoint, the producer’s ranked atlas read, and the three measured production facts that stopped later teams paying twice for the same lesson. |

## 4. Facts proven before spending

Six guardians (`MILESTONES/evidence/EPO03/wave0/`), then sixteen directors
(`wave1/`), before any generation:

- **Canon (GOV-01).** The directive is a rank-1 owner instruction; it answers
  Q-18/Q-25 and changes *which state is approved*, not A-4. Recorded as
  `DECISIONS/0033`. All five playable locations sit inside the core with
  frozen coordinates; the Sunward Strand landmark must keep a beach; routes
  are content and never edited to fit art. Equipment: 23 items (4 weapons,
  10 armour, 4 axes, 5 pickaxes); per-item silhouettes are art; new items are
  not this round. `waywarden_tunic` was unmapped in the resolver.
- **Boundary (GOV-02).** Do-not-touch list verified at HEAD; every mutation
  flows through `SessionController`; save state v9 cannot be reached by
  assets, overlays, strips or layout JSON. Guards: core-purity,
  single-writer, origin-privacy, backup-exclusions, dependency-policy PASS;
  `check-ui-boundary.sh` fails on the pre-existing `craft_memory.dart`
  violation (CI red before this round); `check-step-model.sh`'s production
  scan carries 13 pre-existing false positives. 1,049 app / 738 core / 143
  health tests green at 59c4723.
- **Atlas mechanics (GOV-03).** The EPO03 layer must run after the ghost-sail
  restore and before the water-only conform (so crops and substrate are the
  same image), mark its pixels `claimed`, re-take `approved`, and the drift
  guard must walk the whole canvas. Golden overlaps per candidate zone
  measured; a golden is re-extracted from an `ATLAS_DUMP` pre-guard
  composite. Build 6–7 s; concurrent builds corrupt reads → the build lock.
- **Pipeline (GOV-04).** Real FMPO02 costs: pixen 1 at every size; pro 40;
  edit_image ≈20 per call (whole frame grid); inpaint 20/25/40 by size;
  animate_image 1–2; character state ≈44; map object ≈32. Hosting by commit
  SHA on raw.githubusercontent; inline base64 caps ≈5 KB. Overlays: frame
  loop, cadence, drift and straight travel exist; **no waypoint path, no
  per-overlay scale** — DIR-04 specified the path schema LIFE builds.
  Device render: `SCREEN_EVIDENCE_DIR=… flutter test test/screen_evidence_test.dart`
  (393×852 @ DPR 1).
- **UI (GOV-05).** Single-owner list for the kit files (PROD-UI-NAV); combat
  is a child of Adventure's list, not a route (branch frozen); one golden test
  renders all six tabs — producers prove with evidence renders, the producer
  regenerates goldens once; registries are name-guarded.
- **Audio (GOV-06).** **No-go.** `STABILITY_API_KEY` unset; ElevenLabs is
  permitted by 0005/0030 but has no runner and no key; procedural synthesis
  is forbidden by the locked direction; nothing in `AUDIO/evaluation/` is
  packageable. 22 files owed (combat 11, craft 3 + 1 swap, gathering 1,
  reward 5, UI 1). Recorded once; DIR-14 named three zero-file improvements
  (haptics on Attack/Eat/Retreat, the telegraph cue's segment, a doc fix).

## 4a. First executive checkpoint

Taken with six atlas regions accepted and the interface kit landing.

**Is enough visible production shipping?** Yes, and the largest item is the
one the owner named first. The south territory is complete: four regions
replaced the latitude stripe with a coast that follows terrain — measured,
sand in the old belt 172–440 × 810–870 fell **31.9 % → 2.3 %**, and the
Sunward Strand anchor went the other way, 2.3 % → 49.5 %, so the landmark
still stands on a beach. The shore bends, with surf, angled dunes, machair,
a creek at a rock headland, braided channels into flats and a spit hooking
south. Three landmark goldens were re-extracted under `DECISIONS/0033`;
all fifteen hold and protected-interior drift is 0.

**Has the world materially changed?** Yes. Beyond the south: the Ice-Mage
Tower is no longer an icon on flat snow but an ice bastion on a glacial
foundation with a pillared causeway (L3), and the Storm House now sits in
its own dark grove on a headland with lit windows (L2).

**Has the UI structurally changed?** Partly, and this is the gap. The
bottom navigation — which the owner called one of the least authored parts
of the game — is rebuilt: a leather strap running into the home-indicator
inset, stamped icon wells, and a raised lit plate that breaks the stitched
welt. The shared kit is landing. **The screen rebuilds are the weakest area
of the round so far** and are the next priority as capacity frees.

**Was PixelLab used productively, and did weak work survive because
replacement was inconvenient?** One correction was needed and made. The kit
owner declared the frame and mark families closed after 31 rejected rolls,
leaving 288 generations unspent — exactly the outcome the directive forbids.
Two of the three failure reasons were sound tool limits; the third was not:
four assets had been rejected for brightness alone, which this repository
already fixes deterministically (`49c91f9`, and `RULES.md` A-2). Sent back,
the four shipped for **zero generations**, and a tool the pass had never
tried — `create_image_pro` with an accepted grain as a labelled style
reference — produced all three frame families **on the first call**, 60
generations for the set. The "frame class is closed" conclusion was
retracted in the ledger in place. The measured tool facts are now in
`wave2/PRODUCTION_RULES.md` §2a so no later team pays for them again.

**Course correction applied.** Nineteen concurrent producers exhausted the
session usage limit twice, killing every team mid-flight; the round now
runs four at a time, and every team commits after each accepted item and
records job ids at submission, because a submitted job survives the outage
and can be re-fetched rather than re-rolled (§9a).

## 5. Budget ledger

Live `get_balance` at open **7,989**; at close **6,226**. **Round spend: 1,763**
generations against a 2,000–3,000 target. Checkpoints are in
`GAME_BIBLE/ART/exploration/EPO03/GENERATION_LEDGER.md`; only checkpoints are
facts, every family figure is a lead’s own sum of cost lines (M-17).

| Family | Cap | Spend | Note |
|---|---:|---:|---|
| World — south | 440 | 220 | 4 regions; stopped when no named defect remained |
| World — west | 200 | 150 | 4 regions |
| World — east | 140 | 135 | 3 regions |
| World — north | 100 | 45 | 2 regions, both first-roll |
| Landmarks | 300 | 159 | 3 in-terrain destinations + 4 overlays |
| World life | 200 | 21 | schema v6, dragon breath, roster |
| Equipment | 500 | ~435 | warden body, longsword class, special tool heads |
| Items | 200 | 52 | 20 icons re-authored |
| Gather | 235 | 187 | 12 scenes + the Stonefall recess |
| Enemies | 130 | 68 | 5 plates, 6 foregrounds, dossier |
| Interface kit + nav | 320 | 258 | 13 shared rows |
| Craft | 112 | 15 | the kit already held ~60 planned rolls |
| Skills | 100 | 14 | |
| Combat | 150 | 3 | 7 of 9 marks already in the kit |
| Rewards | 90 | 4 | 10 of 11 assets by deterministic remap |
| Adventure / Inventory / Character / World UI | 230 | **0** | built entirely from the kit |

**On the spend.** The round came in at the bottom of the target band and the
reason is the interface kit: once 13 shared rows existed, five screens were
rebuilt for a combined 32 generations and four of them for none at all. Two
recoveries — a deterministic tone remap and keying a painted-white face —
produced ten of the kit’s own thirteen assets for nothing. Spending more
would have meant generating art the design did not need.

## 6. Known gaps, named

Nothing here is softened, and the closing council’s words are used where they
are sharper than mine.

**Visual debt, ranked by what the phone shows:**

1. **The west territory is drawn by a weaker hand than the centre** (FINAL-K).
   Around atlas (20, 260) one three-lobe tree stamp repeats ~15 times and one
   boulder blob appears at four scales. Two viewports east, Haven’s forest is
   genuinely authored. The owner’s "some areas authored, others patched" is
   still literally true of that corner.
2. **The east ocean is a flat tint** — roughly 23 % of the canvas, 6–32 distinct
   colours per phone viewport against 14k–28k in the west (FINAL-M), and the
   viewport lets the player drag into it. World life put six entries on it;
   the water itself was deliberately not repainted.
3. **The combat page is empty between rounds** — 163 dp of leather on an
   ordinary turn. Recorded as **Q-30** rather than filled, because what
   belongs there is a design decision.
4. **The tin seam still reads as a fin**, and the deep tin lode still shows an
   angular corner. The Stonefall recess fixed copper and helped both; two
   intents were spent and the third was refused.
5. **The three reclaim crates remain near-identical** (82–88 % silhouette IoU,
   FINAL-M) — a collision group the items team reported closed and did not.
6. **The Skills overview is unchanged** from the rejected build (FINAL-L). It
   was judged good and left alone; the owner may disagree now that everything
   around it moved.
7. **Craft spends ~45 % of the viewport on chrome** above one recipe, and the
   recipe book — the round’s headline work — opens below the fold (FINAL-M).
8. **115 of 424 overlay frames (132 KB) are packaged and unplaced**, including
   both dragons’ second breath layers.
9. **`overlay_stag` and `overlay_bear2` are baked palindromes**; the stag holds
   four frames then walks backwards. `overlay_skydragon` f10–f19 duplicate
   f0–f9. None is placed in a way that shows a rectangle (verified, below).
10. **Adventure kit entries wrap to two or three lines** where the card fitted
    them on one, and **Inventory’s empty wells** read flatter than the ornate
    panel they replaced (FINAL-L).

**A council claim I checked and did not accept.** FINAL-M called the opaque
creature overlays a BLOCKER — `overlay_bear2` at 100 % and `overlay_flock` at
95 % opacity "will stamp rectangles of baked foliage onto the atlas". They are
not sprites: they are **in-place animated crops of the master painting**, the
documented technique where a patch of map moves, and they are supposed to be
opaque. The real risk was the one the reviewer did not name — that this round
repainted the terrain beneath one. Measured against the shipped composite, mean
|ΔRGB| under each is 0.0 (bear2), 0.0 (volcano), 5.8 (both ripples) and 14.6
(flock): all seamless. No rectangle ships.

**Inherited, untouched, and not this round’s to fix:**

- `check-step-model.sh` fails its production scan on
  `packages/stride_core/test/veteran_hunts_test.dart` (FDO01). EPO03 changed
  neither the guard nor the file; CI runs only `--self-test`, which passes.
- `check-ui-boundary.sh` fails on `lib/ui/state/craft_memory.dart` (GFCP01)
  reaching path_provider and the filesystem. Untouched this round.
- `dart format` and `package-art.js` disagree about the generated
  `lib/ui/icons/sprite_footprints.dart`. They disagreed at 59c4723 too. The
  generator’s output ships, because a stale generated file is a real defect
  and format drift on a generated one is cosmetic.
- **No audio files.** `STABILITY_API_KEY` is unset; ElevenLabs has no runner;
  procedural synthesis is forbidden by the locked direction; nothing in
  `AUDIO/evaluation/` is packageable. 22 files owed, every call site present.
  Recorded once and moved on, as the directive asked.

**Open questions raised, recorded rather than answered:** Q-29 (what a chapter
of the recipe book is called) and Q-30 (what is on the combat page between
rounds). Both are the owner’s.

## 7. Physical iPhone acceptance checklist

Install over `59c4723` with the existing save. **State stays v9; no migration.**
Every step names a control that exists in this build.

**World — the largest change.**

1. Open World. The sheet should be a **peek strip ~64 dp**, not a panel: map
   visible 663 dp of a 727 dp body (**91 %**, was 66 %).
2. Pan the whole map. **South:** the pale latitude stripe is gone — a bending
   shore, a spit hooking south-east, braided channels into tidal flats, angled
   dunes. **West:** the pass road turns around outcrops and crosses a ford.
   **North-east:** a lobed calving front with bergs and brash, no hard white
   diagonal. **North-west:** moraine and melt tongues, no ruler-straight
   snowline. **Core forest’s west face:** bays and stepping copses, not a wall.
3. Find the three destinations, and note they survive zooming out: the **fairy
   castle** grown from three birches over a flower-ringed pool with fairies
   gathering; the **storm house**, a black gable with lit windows under rain
   and a lightning strike on an ~11.8 s cadence; the **ice bastion** on a
   glacial foundation with a sweeping beacon.
4. Wait for the **red dragon** — a 127 s closed lap over the volcano, two fire
   plumes per lap, never absent — and the **blue drake**, a 176 s ping-pong
   between Frostmere and the cape carrying its storm cloud, striking at
   43/88/133 s. Both cast shadows and pass above ground life.
5. Tap a marker: the sheet must **not** rise. Tap the map: it drops to peek.
   Select an off-screen place: a 22 dp strip appears with direction carets.
   Travel still costs steps and still needs "Set out · N steps".

**Screens.**

6. **Adventure** — a journal: gather sites as ledger entries with cost in a
   right margin, the locked site a **graphite sketch** (not a dimmed card),
   goals as pinned slips.
7. **Craft** — stations on a shelf, an icon-led category rail, and the locked
   half as a **recipe book**: chapters with illustrated rules, the gate stated
   **once per chapter**, sealed pages with wax seals. It must never read
   "1 more at Cooking 5".
8. **Skills** — open Mining detail. A **road** with a joint at every level, a
   lit lantern cairn at "you are here", unlocks unboxed on spurs. The overview
   is deliberately unchanged.
9. **Inventory** — a leather case: figure in a window, three wells cut in, an
   empty well showing its **class shadow** and never the word "Empty"; the
   pack as ruled canvas pockets.
10. **Character** — a folio: bust in a window, gear in margin wells, walking
    figures as a ruled vellum ledger. An empty slot is stated **once**.
11. **Combat** — fight the wolf. The stage chassis is 398 dp against a 120 dp
    command rail (**3.3 : 1**, was ~1.2 : 1): gauges in the frame’s lintel,
    narration on its sill, three plates at thumb height, Retreat a quiet link.
    Attack, Eat and Retreat now answer the hand with a haptic. **Expect the
    leather page between them to be empty on an ordinary turn (Q-30).**
12. **Encounters** — each creature stands *in* its habitat with a foreground
    drawn above it; the cave floor is a floor, not a wall; the boss has its
    own chamber.
13. **Nav** — a leather strap into the home-indicator inset, stamped wells, the
    active tab a raised lit plate breaking the stitched welt.

**Equipment, items, gathering, rewards.**

14. Equip the **Waywarden’s Tunic**: hood, tiered mantle, split skirt — and it
    must never be the plain shirt. Check it in combat, mining, woodcutting,
    foraging, at the anvil and the pot, as the Inventory figure and the bust.
15. Equip the **Bronze Longsword**: visibly longer with a cross-guard, tip past
    the front foot. **Brace with the starting loadout** — it had no brace
    track at all before.
16. **Items** — the four brown vests and the bearhide coat must read as five
    different things; the five ivory curves likewise; hearty vs expedition stew.
    **The three reclaim crates will still look alike** (named debt).
17. **Gathering** — the copper seam sits *inside* a shaded recess with rock
    overhanging. **The tin seam will still read as a fin** (named debt).
18. **Rewards** — a result is a paper tally slip: item named on a ruled line,
    figures in the right margin, rarity as material, a wax seal whose tone
    differs by rank. Nothing flashes, loops or counts up.
19. **Reduce Motion on** — the world still shows its life, pinned; sound and
    haptics must **not** go quiet with it.
20. **Save** — every figure and item from before the install is still there.

**Performance to watch:** first World-tab entry after a cold launch (287
precache decodes in one pass), and the World tab again late in a long session.

## 8. Reviewer verdicts

Five closing reviewers, each given the shipped pixels and told to find the
reason the owner would say no. Reports in `MILESTONES/evidence/EPO03/wave3/`.

| # | Reviewer | Verdict | What closed, or why not |
|---|---|---|---|
| FINAL-J | Identity guardian | **IDENTITY INTACT** | `git diff --stat -- packages/` is empty; save v9; locations/landmarks/routes hold at 5/23/5. Checked every moved assertion individually: none weakened, several strengthened. Noted ADR 0033 §2 prose is one revision behind the code — same guarantee. |
| FINAL-I | Performance | **NO BLOCKER** | Bundle 23.22 → 24.23 MiB (+4.3 %); World tab no step change, nothing runs hidden. Found the image cache’s entry cap (2,000) below the shipped PNG count (2,388) — **fixed**, raised to 3,000. |
| FINAL-K | "Does it still look generated?" | **PARTLY** | Map centre, combat backdrop, item icons and portrait genuinely answered; the west’s repeated stamps and the flat ocean are not. Carried as debt 1 and 2 — both need generation, which the closing brief forbids. |
| FINAL-L | "Would the owner say WOW?" | **BETTER, NOT WOW** | Skills detail, the recipe book and the atlas SUBSTANTIAL; Craft, Adventure, Inventory INCREMENTAL; Skills list UNCHANGED. Called **Character the weakest link** — **fixed**, the duplicated empty slot is gone. |
| FINAL-M | "What should be deleted?" | 5 nominations | Reclaim crates, east ocean and Craft chrome carried as debt. Its overlay BLOCKER was **checked and not accepted** — the opaque overlays are in-place crops and measure seamless (§6). Its critique of the producer’s own judgement on `reinforced_pickaxe` is recorded and stands. |

**Two blockers were fixed on the council’s word; the rest are named debt**,
because the closing brief forbids reopening production scope, and every
remaining finding needs either new generation or a screen redesign.

## 9. Closeout

**Branch** `fable5-executive-production-overhaul-03`, from
`fable5-mega-production-overhaul-02` @ `59c4723`. **Not merged.** The physical
iPhone is the authority and the checklist in §7 is what it is asked to answer.

**Verification at close:** app suite **1,111 pass / 0 fail**; `stride_core` 738;
`stride_health` 143. `flutter analyze` clean across app and tests. Packaging
idempotent at **2,320** files; palette guard green at **2,388** PNGs; tile-seam
green at 26 strips. Twelve architecture guards pass; the two that fail are
inherited and named in §6. Fifteen goldens regenerated, each diff inspected
side by side first.

**What this round changed, in one line each:** 17 atlas regions across four
territories and three in-terrain landmarks; 8 UI surfaces rebuilt on a new
13-row material kit; a fifth armour body and a real longsword class; 20 item
icons re-authored; 12 gather scenes; 5 habitat plates with foregrounds; a
world-life behaviour system with patrol paths, shadows and depth; the result
card rebuilt as a tally slip.

**Three production facts this round measured, now in `wave2/PRODUCTION_RULES.md`**
so no later round pays for them again: pixen cannot draw flat tileable chrome
and `create_image_pro` can, first call; brightness over the ceiling is a
deterministic remap and a painted-white face is a key, not rejections; and a
held item on a shipped frame costs 1 generation, not 44.
