# World Atlas Restore 01 — art round record

**Date:** 2026-08-27 · **Milestone:** `MILESTONES/WORLD_ATLAS_RESTORE_01.md`
· **Mistake entry:** `MISTAKES.md` M-15 · **Rule:** `RULES.md` A-4

## Why this round exists

A read-only audit of the WACUI bridge passes found that seam repair had
drifted into **content damage**: the twelve inpaint bridges and seven
edge-integration fixes were blitted over the composite with no boundary
against the byte-preserved 512² master at (256, 256), and several reached
deep into it — `east_x768` 128 px, `d2_north` 84 px, `north_mtop` 72 px.
The measured damage: **35.3 % of the master interior** differed from the
approved 559669e composite. Erased outright: the Frostmere frozen basin
(glacial cirque walls, the frozen lake), the volcano's two watchtowers, and
the approved east coastline (rewritten as invented forest/beach).

## What the round did

1. **Protected interior in the pipeline** (`Scripts/art/package-art.js`):
   the composite is snapshotted after the approved-era steps (master +
   static patches + dither). Repair layers may write the 20 px rim band
   (hash-feathered); everything deeper is restored from the snapshot, and a
   **guard throws** if any non-deep-water core pixel drifts — so `--check`
   fails on protected-zone drift forever.
2. **`east_x768` retired.** Its water seam is owned by the global ocean
   conform; its interior repaint was the main damage vector.
3. **Ocean conform moved last**, so every layer's deep water (strips,
   bridges, master coast, edge pieces with older conforms baked in) maps
   through one global transform — no tonal panel edge can survive between
   layers.
4. **Four surgical inpaints** (via `plab.js`, masks in/outside the rim band
   only, ~125 generations, balance 300 → ~175):
   - `east_join` (seed 210): the volcano's eastern cliff dropping to rocky
     coves and pale shallows, replacing the re-exposed dither column at
     x≈768. **Adopted y 272–436 only** — the generation's top and bottom
     thirds invented red haze over the sea and debris on the ice shelf;
     rejected, frames preserved in `out/`.
   - `west_join` (seed 331): the master forest thinning into the pale
     western meadow as scattered trees, replacing the dotted crossfade
     column at x≈256. Adopted whole mask band.
   - `south_strand` (seed 412): the strand fading into dune grass, scrub
     and driftwood, replacing the straight sand-to-green line at y≈830.
   - `south_strand_e` (seed 517): the flat green filler east of the delta
     becomes the sea meeting the beach. One invented **ghost sail**
     rejected — removed by the deterministic flotsam fill.
5. **Flotsam cleanup (deterministic, A-2):** two pre-existing generation
   artifacts in open water — a dark scribble blob at (886..910, 622..662)
   and whitecap marks at (866..906, 760..784) that read as printed text at
   zoom — plus the ghost sail, each filled from neighbouring open water.

## Review

`tools/make_review.js` emits `review/`: survey, the four boundary strips at
×3, and the protected-zone overlay. Each adopted boundary was reviewed at
survey and ×3 before packaging; the phone device pass remains the final
authority (`MISTAKES.md` M-14).

Known residuals, on the record: the small dark headland with faint speckle
north-east of the volcano (~(756..800, 279..310), pre-existing); the
feather dots on the master's west mountain silhouette (~(230..270,
620..690)); the pale-vs-saturated tonal difference between the western
strip and the master forest (approved-era, softened but present).

## Budget note

The WMER02-era "≤200 ceiling" reserve note was consciously traded against
the owner's explicit high-effort restoration brief; ~125 generations spent,
~175 remain until the 2026-09-16 reset. `get_balance` is the authority.
