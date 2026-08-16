# Phase 1 carried corrections

```
STATUS: APPLIED — both corrections are in the shipped art
Date: 2026-08-16 · Predecessor: PIXELLAB_STABILIZATION_01
```

The two corrections `PIXELLAB_STABILIZATION_01` carried forward, closed here.
Each is stored as **the patch, not a replacement asset**, so what changed stays
legible: everything outside the patched region is the approved source, byte for
byte.

`Scripts/art/package-art.js` applies both. Nothing here is loaded at runtime.

## A — the region map's watercourse: CLOSED

`region_map_tarn_patch_96x96.png`, pasted at **(120, 224)**.
`region_map_tarn_mask_96x96.png` is the mask that produced it.

The stabilization pass left this **NOT CLOSED**, and its own record of why is
the useful part. A tarn had been generated and verified *objectively* — blue
pixels in the terminus region went 132 → 267, the bounding box grew — and a
blind reviewer looking directly at those coordinates still reported the stream
*"narrows by perhaps a pixel and stops… no pool, no pond, no marsh or reed
fringe"*.

Two things were wrong with the first attempt, and only one of them was obvious.

**Value, not area.** The pool was about the right size and the wrong contrast:
its blue sat close to the grass in *value*, so it vanished at native scale while
measuring as a clear success. This correction asked specifically for water
*darker in value than the surrounding grass*. That is why counting blue pixels
had said it worked and looking at it had said it had not — the measurement was
answering a different question from the one that mattered.

**An elliptical mask.** A first attempt here used a rectangular mask and
reproduced exactly the artefact the stabilization pass found when it inpainted a
tavern floor: *"a distinct patch — hard-edged, flatter plank treatment,
different value"*. Inpainting regenerates the whole masked area, so its overall
tone shifts slightly, and a straight mask edge turns that shift into a visible
rectangle. With no straight edges in the mask the regenerated region cannot
terminate along a line the eye reads as a boundary. **That attempt was discarded
rather than shipped** — a hard-edged patch in the middle of the map is worse
than a stream that fades.

Verified on a running device at native scale, not only at magnification.

### Still open, and deliberately not attempted

The reviewer raised three properties of the *original* watercourse that this
pass did not touch: it has no banks anywhere along its length, it holds a
constant one-to-two-pixel width from source to mouth, and its blue is the
highest-chroma element on the map. Those are composition questions rather than
legibility ones, and the milestone brief says not to reopen world-map
composition. They are recorded here so a future pass does not rediscover them.

## B — gather frame 5: CLOSED

`gather_f5_repaired.png`, replacing `gather_trim_f5.png`.

Frame 5 was the last of the owner's five criteria to fail. Blind review:
*"torso, both arms and knee fuse into one mass"*. Trimming could not fix it —
the defect is in the generated frame — and the frame is load-bearing, because it
is the rise between the crouch and the standing hold. Dropping it would leave
the figure snapping from a deep crouch to standing.

One `inpaint_image` over a **21 × 25 box at (16, 34)**, covering the left arm,
hip and knee. Two exclusions were chosen deliberately:

- **The herb hand sits at x ≥ 38, outside the mask.** The herb interaction
  could not drift.
- **The boot rows sit at y ≥ 59, outside the mask.** The feet stay planted
  exactly where the neighbouring frames put them, so the cycle does not slide.

## What was measured rather than assumed

Both corrections were checked for containment before being accepted:

| Correction | Pixels changed outside the mask |
|---|---|
| A — map tarn | **0** |
| B — gather frame 5 | **0** |

That is the property that makes a targeted edit safe. The noun cannot drift,
because the silhouette outside the mask was never regenerated.

## Cost

40 generations for the two accepted edits, plus 20 for the discarded
rectangular-mask attempt. 60 total.
