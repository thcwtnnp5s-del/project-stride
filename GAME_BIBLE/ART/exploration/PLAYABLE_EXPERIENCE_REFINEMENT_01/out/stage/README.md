# PLAYABLE_EXPERIENCE_REFINEMENT_01 — work backdrops (§6)

The owner's physical-device screenshots found the mining work backdrop
"visually sparse and generic — flat wall, repeated vertical beams, large empty
floor/wall areas; a test chamber rather than Stonefall Mine", and asked for
region identity without clutter that fights the resource. Woodcutting was to
feel like the Whispering Woods with depth beyond the work tree; foraging
(Meadow Patch) already read well and is untouched.

All plates: PixelLab `create_image_pixen`, 384 × 176 (the location vignettes'
frame), side view, medium detail, selective outline, scene (no transparency).
Six generations, 2026-08-22. Rejected candidates are kept beside the accepted
ones, as the production rule requires.

## Mining — Stonefall

| File | Seed | Verdict |
|---|---|---|
| `mine_masonry_s41.png` | 41 | Rejected — dressed masonry wall reads as a cellar, not a cut mine; floor split by a raised rail bed |
| `mine_masonry_s97.png` | 97 | Rejected — same masonry; a timber walkway at the ground line would put the Traveler on a boardwalk |
| `mine_rock_s7.png` | 7 | **Accepted** — natural slate face with copper streaks, two timber props and a lintel, lantern, rails low at one side, a few stones, the tunnel mouth receding; open packed floor across the lower third |

Packaged **mirrored** (`Scripts/art/package-art.js`, `flipX`): the Traveler
stands at 60 % of the stage width and the mining loop works east, so the seam
prop lands at ~63–88 % — where the unmirrored plate has its tunnel mouth.
Mirrored, the mouth sits behind the figure's back and the seam sits against
the rock face it belongs to. A horizontal flip invents no object, silhouette
or content (`RULES.md` A-2).

## Woodcutting — Whispering Woods

| File | Seed | Verdict |
|---|---|---|
| `woods_stump_s41.png` | 41 | Rejected — a cut stump at the figure's own ground, exactly where the oak work prop stands |
| `woods_stump_s97.png` | 97 | Rejected — same stump, same collision |
| `woods_open_s7.png` | 7 | **Accepted** — open earthen clearing left and centre, a log stack at the far right, trunks with undergrowth in the middle distance, the deeper wood in cool haze, a shaft of daylight |

The oak prop stands west of the figure (~34–58 % of the width); the plate
is open ground there.

## Foraging — preserved

`work_foraging_0` from PRESENTATION_WORLD_REWARD_FEEL_01 stays the packaged
Meadow Patch backdrop; the owner's device found it readable.
