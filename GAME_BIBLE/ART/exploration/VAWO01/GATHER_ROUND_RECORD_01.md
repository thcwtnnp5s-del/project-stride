# Gather scene round 01 — record

```
STATUS: ACCEPTED · 28 plates shipped · 68 generations spent
Date: 2026-09-01 · Branch: visual-audio-world-overhaul-01
Authority: DECISIONS/0031 (L-18a, owner ruling) · DECISIONS/0030
Direction: GATHER_SCENE_DIRECTION_01.md
```

**Balance:** 9,982 at round open. **68 spent** (18 R1 + 12 re-rolls + 10 R2 +
28 accepted-first-time). Verified live, not remembered.

## What shipped

| Family | Plates | Native | Drawn |
|---|---:|---|---|
| Region × skill backdrops | 7 | 384 × 176 | ×1 |
| Project-built backdrops | 7 | 384 × 176 | ×1 |
| Working faces | 14 | **48 × 48** | **×2** (L-18a) |

## The number that matters

**22 of 22 nodes are now a distinct scene.** Before this round it was 12 of 22,
and all five Forgotten Hollow nodes drew one identical picture.

A "scene" is the pair the player looks at — backdrop plus working face.
Fourteen faces serve twenty-two nodes and that is correct: the Tin Seam and the
Gallery Tin Lode *are* the same face in two different places. The backdrop
separates them. `gather_grounding_test.dart` asserts this at zero collisions.

## Three findings worth not re-learning

**1. "Spreading flush into soil at the bottom edge" buys an isometric ground
tile.** Three of the first eleven subjects came back standing on a hard-edged
diamond plinth — the floating-object defect wearing a different hat. The fix is
to name it: *no isometric tile, no ground tile, no base platform, no plinth, no
diamond base*, plus `view: "side"`. Two of the three took two further rolls.

**2. The word "wall" produces brickwork.** All three mining faces came back as
coursed masonry with mortar lines, which is a ruin, not an ore seam. Replacing
"wall" with "rough broken natural rock face … irregular craggy stone with
natural fracture planes, no two blocks alike" and banning bricks explicitly
fixed all three in one roll.

**3. An abstract subject needs a concrete physical analogue.** "Silk strands
slung between two stems" produced, in order, a **jar**, a **necklace on
chains**, and only then something usable — when the prompt stopped describing
the *concept* and described a thing that exists: *"tufts of pale fibrous silk
snagged on dark bare twigs, like wool caught on a bramble thicket."*

## Rejections, kept

`rejected/gather/` holds every superseded roll with its round suffix. The six
96 px incumbent props remain **packaged and unreferenced** as the exploration
record — superseded under L-18a, not deleted, because a 96 → 48 downscale
destroys a one-pixel outline and would not be A-2 anyway.

## Verification

- `package-art.js --check` green; **900 PNGs** through the palette guard, no
  teal collision, zero semi-transparent pixels.
- 977 tests pass; `flutter analyze` clean.
- Every subject has a **measured** footprint, so every one is grounded by
  `GroundedSprite` rather than by hand.
- Stage evidence captured at 393 × 852 in `review/gather/stage/`.

**One defect in the harness was found and fixed while capturing that evidence.**
`stage_evidence_test.dart` passed `vignette: null`, and the work backdrop is
resolved *from* the vignette — so every frame it had ever captured showed the
legacy per-skill plate rather than what the app draws. An evidence harness that
does not exercise the shipped path is evidence of nothing. It now passes the
real location painting.

## Known, and not fixed here

- The foraging bed reads ~92 dp tall against the direction's ≤ 51 dp guidance,
  so it overlaps the kneeling figure more than intended. It reads as bending
  into the patch and was accepted; if the device read disagrees, the fix is the
  plate, not the placement.
- `prop_deep_tin_lode` carries some squared cut faces. Defensible — it is a
  driven heading rather than natural rock — but it is the weakest of the
  fourteen.
