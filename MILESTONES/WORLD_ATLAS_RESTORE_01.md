# WORLD ATLAS RESTORE 01 — protected interior, restored geography, glass panel

**Status:** built, awaiting the owner's device test.
**Branch:** `playable-phase-2-multiregion`, on top of `5a34425`.
**Art round:** `GAME_BIBLE/ART/exploration/WORLD_ATLAS_RESTORE_01/README.md`.
**Canon:** `MISTAKES.md` M-15, `RULES.md` A-4.

## 1. The finding

The WACUI coherence passes fixed the seams the phone saw — and quietly
repainted the approved interior doing it. Every bridge and edge fix was
blitted with no boundary against the byte-preserved master at (256, 256);
measured against the approved 559669e composite, **35.3 % of the master
interior had drifted**. The Frostmere frozen basin was erased under generic
snowfield, the volcano's two watchtowers were deleted, and the approved
east coastline was rewritten into invented forest and beach by a bridge
that reached 128 px inside.

The root cause is recorded as **M-15**: a repair layer with no enforced
boundary *will* eventually repaint what it was protecting, and no
reproducibility check can see it, because the drifted composite is exactly
as reproducible as the right one.

## 2. The restore (deterministic)

In `Scripts/art/package-art.js`, the composition now snapshots the
approved-era state (master + static patches + dither) before any repair
layer runs:

- **Protected interior:** rect (256, 256)–(768, 768), rim band 20 px.
  Repair pixels deeper than the band are restored from the snapshot; the
  band itself is hash-feathered so no straight clip line can read.
- **`east_x768` retired** (the main damage vector). The ocean conform owns
  its water seam.
- **Ocean conform runs last**, one global transform over every layer's
  deep water.
- **Guard:** after composition, any non-deep-water core pixel differing
  from the snapshot throws — protected-zone drift now fails packaging and
  `--check`, permanently.

The basin, the lake, the watchtowers and the east coastline are back in
the shipped asset, byte-faithful to the approved painting outside the rim
band.

## 3. The seam re-authoring (surgical)

Retiring the east bridge re-exposed the master-east join; the west and
south carried their own mechanical reads. Four narrow inpaints (masks in
or outside the rim band only, ~125 generations) re-author them: the
volcano's eastern cliff and coves, the forest-to-meadow treeline at x≈256,
and the strand fading into dune grass and surf across the whole south
coast. Rejected stretches (red haze, ice debris, a ghost sail) are on the
record and out of the asset; two pre-existing flotsam artifacts and the
sail were removed by deterministic water fill. Full details in the art
round README.

## 4. The World panel becomes glass

The map-first screen's info panel was translucent in name only
(`0xF0` ≈ 94 % opaque). It is now a gradient glass — `0xB4` at the top of
the body falling to `0xE6` where the controls sit — so the painting
genuinely continues behind the words, with a drag handle, and a **fold**:
drag down (or tap the handle) and the panel collapses to a 76 px peek strip
carrying the selected place's name and journey cost, leaving the atlas
essentially full-screen; selecting a place unfolds it. The camera inset
centres the current place above the readable content in both states. No
blur (the recorded BackdropFilter decision stands); no change to travel
semantics, engine access, or the fallback presentation.

## 5. Verification

- `package-art.js --check` clean (792 files, atlas reproducible from
  tracked sources — including the four inpaint frames and the protected
  restore, which is deterministic).
- Full app suite green; the two World goldens regenerated and reviewed
  (they show the restored atlas behind the glass panel).
- Review artifacts: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_RESTORE_01/review/`
  (survey, four boundary strips at ×3, protected-zone overlay), emitted by
  the round's `make_review.js`.

## 6. Device checklist (the owner's next test)

1. World tab: the frozen basin and lake read as continuous geography north
   of the mountains; no rectangular snowfield insertion.
2. The volcano has both watchtowers; its east side drops to a cliff and
   coves into one continuous sea.
3. South coast: beach fades into dune grass; no straight sand/green line.
4. West: the forest thins into the pale meadow without a dotted column.
5. The panel: map visible through the glass, text readable, fold works,
   fold animation smooth on device.
6. Survey zoom: the world reads as one painting; call out any rectangle.
