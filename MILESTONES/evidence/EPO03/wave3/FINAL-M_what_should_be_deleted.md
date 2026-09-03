# FINAL-M — what should be deleted, rebuilt, regenerated, reconsidered, and let go

Adversarial review, EPO03 wave 3. I built none of this. No PixelLab generations
were spent; every number below is measured from the shipped bytes on
`fable5-executive-production-overhaul-03`.

Method: I read the atlas and the nine shipping goldens as images,
contact-sheeted `assets/art/v1/item/` and `assets/art/v1/env/`, and measured
silhouette overlap, per-frame motion, frame hashes and alpha coverage directly.
`PRODUCER_OBSERVATIONS.md` and the twenty-five `*_report.md` files were read
last, deliberately, so their framing did not set my priors.

---

## 1. Map section to delete and replace — BLOCKER

**Atlas rect x 788–1024 × y 0–1024** of `assets/art/v1/world/atlas_base.png`
(23 % of the world) is a flat teal swatch, not a map.

Measured per phone viewport (197 × 426 atlas px, the atlas is drawn at ×2):

| viewport | distinct colours | dominant colour share |
|---|---|---|
| (788, 0) | 142 | 73.7 % `62,152,166` |
| (985, 0) | **32** | 93.8 % |
| (788, 426) | 902 | 86.3 % |
| (985, 426) | **17** | 97.5 % |
| (788, 852) | 340 | 88.6 % |
| (985, 852) | **6** | 98.1 % |

For comparison the inhabited west averages 14 000–28 000 colours per viewport.
The far column carries **six distinct colours across an entire phone screen**.

This is reachable, not cropped out:
`lib/ui/screens/world/atlas/atlas_viewport.dart:295` clamps with
`value.clamp(0, world - visible)` against the full 1024 width, so a player who
drags east gets two screen-widths of undifferentiated blue-green with nothing in
it — no island, no route, no destination, no reason to have dragged.

**What a viewer would see if fixed:** either the eastern sea ends where the
content ends (clamp the camera to x ≈ 830 and delete the dead pixels), or the
column earns its space — an archipelago chain, reef shelf, ice floes, a shipping
lane that reads as somewhere the game intends to go. Right now it reads as an
unfinished canvas, which is worse than a smaller world.

This is in no wave-2 report. `WORLD_EAST_report.md`'s "what did not close" names
the ice-to-volcano join at (680, 290) — a 60-pixel detail — while 236 columns of
blank ocean beside it went unmentioned by every east-facing document.

## 2. UI surface to rebuild — DEBT (high)

**The Craft screen** (`test/goldens/phase2_craft.png`,
`lib/ui/screens/craft/craft_screen.dart`).

It spends roughly 45 % of an 852 dp viewport on five stacked chrome bands before
a single recipe appears:

1. three station tiles (forge / bench / cookfire art), ~100 dp;
2. a station **name and count row** directly beneath them — "Forge 23·0 ready",
   "Bench 3·0 ready", "Cookfire 10·1 ready" — a second row saying in text what
   row 1 already said in art;
3. a purely decorative shelf strip of pots and vegetables, ~40 dp, carrying no
   information at all;
4. a category tab row (All / Materials / Food / Gear / Tools);
5. a summary line, "1 craftable · 10 known".

The result is that exactly **one recipe card** is visible, and the Recipe Book —
the thing this round built to answer "locked content must not read as
spreadsheet rows" — is clipped to a single hairline of the words "THE RECIPE
BOOK" at the bottom edge, below the fold, on the default screen.

The round's craft work was judged on the book. The book is not on screen.

**What a viewer would see if fixed:** the station selector collapses to one row
carrying its own name and ready-count (bands 1 and 2 merged, band 3 deleted),
and three or four recipe cards plus the head of the book sit above the fold.

`UI_CRAFT_report.md`'s "did not close" names the dog-ear and pursuit ribbon being
painted rather than drawn. That is a material question about two ornaments; the
screen's information budget is the larger problem and is not raised.

## 3. Asset family to regenerate — BLOCKER

**`reclaim_axe`, `reclaim_chestplate`, `reclaim_pickaxe`** in
`assets/art/v1/item/`. All three are the same brown wooden crate with an
indistinct brown shape inside it.

Silhouette IoU, measured pairwise:

| pair | IoU |
|---|---|
| reclaim_axe vs reclaim_chestplate | **87.2 %** |
| reclaim_axe vs reclaim_pickaxe | **82.2 %** |
| reclaim_chestplate vs reclaim_pickaxe | **88.4 %** |
| bronze_axe vs bronze_chestplate | 35.4 % |
| bronze_axe vs bronze_pickaxe | 54.7 % |
| bronze_chestplate vs bronze_pickaxe | 27.7 % |

The same three item types, done correctly elsewhere in the same family, separate
at 28–55 %. The reclaim trio separates at 82–88 % — two to three times worse,
against the family's own in-house benchmark. The container is the icon; the item
is a mid-brown smudge in the same hue as the container carrying it.

This is ship-stopping rather than cosmetic because the icon is sometimes the
*only* identifier. `phase1_inventory.png` renders the Materials grid as icon plus
"×2" with **no name**, and `phase2_craft.png` renders the ingredient tray as icon
plus "2/2" with **no name**. In both surfaces a player holding two of these
cannot tell which is which.

**What a viewer would see if fixed:** three silhouettes that differ at the
outline — a haft breaking the crate line for the axe, a shoulder-and-neck mass
for the chestplate, a head-and-pick profile for the pickaxe — readable at 48 px
without opening anything.

## 4. Animation family to reconsider — BLOCKER

**The world-life creature overlays** in `assets/art/v1/env/`. Three separate
faults, two of which ship.

**(a) Four "overlays" are opaque rectangles.** Measured alpha coverage of `_f0`:

| family | size | opaque | placed in `atlas_layout.json` |
|---|---|---|---|
| `overlay_bear2` | 26×28 | **100.0 %** | **yes** |
| `overlay_flock` | 64×40 | **95.0 %** | **yes** |
| `overlay_stag` | 28×22 | 100.0 % | no |
| `overlay_yeti2` | 44×34 | 100.0 % | no |

Correctly built members of the same family run 17–55 % opaque (`nessie` 17.2 %,
`skydragon` 29.3 %, `wolfpair` 31.9 %, `bear3` 42.6 %). `overlay_bear2` ships its
own baked green foliage and `overlay_flock` its own sky; both are placed, so at
runtime they stamp a hard-edged rectangle of foreign terrain over whatever atlas
pixels sit beneath them. An overlay that is 100 % opaque is not an overlay.

**(b) `overlay_skydragon` is a ten-frame loop stored three times.** MD5 of the 28
frame files: `f10`–`f19` are **byte-identical** to `f0`–`f9` (hashes
`68f72ab0 8e738e95 e177a363 01a73702 b9dcbdd3 43a4cb07 6817a7cd 6c84ad9c
b19a1cd8 87dd832e`, repeated exactly). 18 unique frames, 10 pure duplicates. The
runtime plays the same wingbeat twice and calls it new motion.

**(c) The quadruped cycles are baked palindromes with freezes.** `overlay_stag`
is 20 files / 11 unique, hashed forward then exactly reversed (`f19`==`f0`,
`f18`==`f1`, …), with `f6`–`f9` **all four identical** — the stag holds one pose
for a fifth of its cycle, then walks backwards. `overlay_bear2` is 19 files / 13
unique with the same mirror structure. A ping-pong is defensible for a wingbeat;
for a gait it reverses the legs.

**What a viewer would see if fixed:** animals composited into the map instead of
sitting in visible boxes, a dragon whose wings do not repeat, and a stag that
walks in one direction.

None of (a), (b) or (c) appears in `WORLDLIFE_report.md` or
`PRODUCER_OBSERVATIONS.md`.

## 5. Preserved only because it already exists — DEBT

**115 of 424 world-life overlay frames — 27 % of the family, 132 KB — are not
referenced anywhere in `assets/content/v1/atlas/atlas_layout.json`.**

Whole families ship unplaceable: `stag` (20 frames), `fire3` (10),
`tree_rustle_a` (9), `tree_rustle_b` (9), `bear3` (9), `redwyrm_breath` (8),
`stormdrake_breath` (8, 23 KB), `yeti2` (8), `snow_flurry` (8),
`storm_lightning` (8), `birds` (6), `forge_smoke` (6), `fairy_motes` (4),
`cloud_shadow`, `cloud_wisp`.

Both dragons are instructive: each was given two effect layers and only one was
wired. `redwyrm_plume` is placed and `redwyrm_breath` is not; `stormdrake_bolt`
is placed and `stormdrake_breath` is not. The unwired halves were generated,
paid for, committed, and kept.

The reports treat this as pending rather than as a decision.
`LANDMARKS_report.md` says four overlay rows "are not in `atlas_layout.json`" and
files a request; `WORLDLIFE_report.md` explains the fairy overlays as a
"deliberate deviation" because `overlay_fae_court` already covers the same glade
— which is a good reason to **delete** `fairy_motes`, and instead it stays.
Nothing proposes removing any of it. The honest position is that these frames are
carried because deleting generated art feels like waste, which is the definition
of a sunk cost. Either place them this round or delete them; carrying 132 KB of
unreachable animation into wave 3 is a decision nobody has made out loud.

---

## Where the producer let something off too lightly

**Named the wrong weakest item.** `PRODUCER_OBSERVATIONS.md` singles out
`reinforced_pickaxe` as "the one icon in the family I would look at first" —
weaker because "it separates from its siblings by the head-to-haft joint rather
than by outline". Rendered at ×6 beside its neighbours, `reinforced_pickaxe` is a
crossed haft-and-head with a clean, distinctive outline; it is the *strongest* of
the four icons in that corner of the sheet. The three icons beside it are the same
crate at 82–88 % IoU (§3) and are not mentioned in the observations at all. The
producer applied the silhouette standard to the armour group, wrote a genuinely
principled note about the longsword reach assertion, and then did not run the same
measurement across the rest of the family.

**Funded a backdrop while a plate is still unkeyed.** The producer judged
`prop_tin_face` personally, traced the fin read to the flat `bg_stonefall_mining`
wall, and authorised an 80-generation tier-2 recess rather than re-rolling the
prop. The reasoning is sound and the recess helped. But in the delivered
`review/gather/_r_tier2_stage_after_x2.png`, panels 2 and 3 show the prop plate
with a **hard black rectangular edge** — a straight vertical left border and a
straight bottom border, on the sprite rect, against the wall. That is not a "reads
as a fin" nuance and no backdrop can fix it; it is the same defect the same team
already caught once this round ("a KEEP-verdict prop turned out to carry a black
base bar that only appeared under the figure"). Having found that class of fault
once, the family was not swept for it. The cause was diagnosed correctly and then
the search stopped.

**The right call, recorded as such.** The producer's judgement that the composed
render overturned three sheet verdicts is correct and is the most valuable method
finding of the round — it is the reason I read every asset here composed or at ×6
rather than from a sheet. My §3 and §4(a) are that same rule pushed one step
further: to the *screen* the icon appears on, and to the *alpha* the overlay
composites with.

---

## Summary

| # | Category | Subject | Verdict |
|---|---|---|---|
| 1 | Delete and replace | atlas x 788–1024, all y | **BLOCKER** |
| 2 | Rebuild | Craft screen chrome stack | DEBT (high) |
| 3 | Regenerate | `reclaim_axe` / `_chestplate` / `_pickaxe` | **BLOCKER** |
| 4 | Reconsider | world-life creature overlays | **BLOCKER** |
| 5 | Let go | 115 unplaced overlay frames (132 KB) | DEBT |

Three blockers. Findings 1 and 4(a) are visible to any player on a device within
the first minute of panning the world map, and neither is named anywhere in
wave 2.
