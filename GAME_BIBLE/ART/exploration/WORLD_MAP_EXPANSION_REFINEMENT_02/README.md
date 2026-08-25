# World Map Expansion Refinement 02 — art round

**Date:** 2026-08-25 · **Balance at start:** 1,416 (verified by `get_balance`;
resets 2026-09-16; ending balance in the milestone record). Milestone record:
`MILESTONES/WORLD_MAP_EXPANSION_REFINEMENT_02.md`.

Everything in `out/` is a tracked packaging source; everything in `rejected/`
is evidence; everything in `tools/` is the round's transport, crop,
composition-preview and sweep tooling. `Scripts/art/package-art.js --check`
must pass from a clean checkout.

## The brief (owner, physical-device review of `4f8459e`)

1. Fix atlas joins that do not line up cleanly (worst: the east dither band,
   the near-black NE corner, the SE beach cut-off).
2. Open the west: a caravan corridor through the mountain/forest wall.
3. Expand the world again in all four directions.
4. The flying dragon flies backwards — fix it; add a brief fire breath.
5. Re-audit every egg at the new scale; add 2–4 new quiet discoveries.
6. Restrain label density; geography may stay unnamed.

## Transport (carried from WMP03 §E, now committed)

The interactive MCP transport corrupts large inline base64 image arguments —
measured this round: `+` characters become whitespace in transit and the
server's tolerant decoder drops them, so every busy PNG arrives broken;
percent-encoding is not decoded server-side. All image-carrying calls run
through `tools/plab.js` (same endpoint, same bearer token, read from the
user's own Claude config at runtime, never logged; owner-approved this
session). Integrity was proven before any production call: a 128² crop
round-tripped through `animate_image` with **zero byte diffs**
(`out/transport_probe_src_128.png` vs `_result_f0.png`, job `58656b88`).
`tools/cropurl.js` cuts style/reference crops; `plab.js image` also follows
the no-auth download URLs for frames past the inline few.

## A. Inner-ring corrections (`out/world/`)

Replacements for four WMP03 ring pieces. The WMP03 recipe (64² style chip)
was extended with a **labelled context reference** — the full adjacent
composed column — after the WMP03 east strip proved a style chip alone does
not carry the water palette.

| Piece | Job | Verdict |
|---|---|---|
| `cand_strip_east_f0` | `5ec31eeb` seed 41 | ACCEPTED first roll: ocean continues the master's teal, wave dashes, sand-ring islands; volcanic coast fades at top |
| `cand_corner_ne_f0` → `corner_ne_conformed_v2` | `acdca76d` seed 42, candidate #0 of 4 | Daylight polar sea; then deterministically water-conformed (tools/waterconform.js) with a vertical gradient — glacial cyan (north patch) at top to the east strip's teal at bottom — so the y-join reads as water temperature, not a seam |
| `cand_corner_se_f3` | `fabc9b95` seed 43, candidate #3 of 4 | Warm shallows meeting open sea; candidates 0–2 pulled land across the top edge and were passed over |
| `cand_strip_west_f0` | `764f354d` seed 44 | ACCEPTED first roll: varied peak silhouettes (the repetition complaint), broad pass with a winding caravan road entering from the master side |

Retained from WMP03: `strip_north` (the glacier join survived the device
review), `corner_nw`, `corner_sw` (1px white generation border on its
formerly-canvas left/bottom edges replicated over at packaging), `strip_south`.

### Static in-place patches (edits of tracked crops, blitted at packaging)

| Patch | Job | Purpose |
|---|---|---|
| `corridor_edit_f0` @1024(256,483) | `d81e9c57` | The corridor cut: a winding dirt road through the master's west forest, log bridge over the stream, joining the bank road |
| `roadjoin_edit_f0` @(216,480) | `f6f8eb6f` | Connects the pass road's end to the corridor cut across the strip seam |
| `northfix_edit_f0` (superseded) → `northfix2_edit_f0` @(640,128) | `95d67e87` → `ff34a53e` | The WMP03 "night patch": dark navy sea on the north strip's right end converted to daylight polar teal; v2 recedes the rock toward the bottom edge |
| `eaststriptop_edit_f0` @(768,256) | `8563853a` | The east strip's volcanic top fades fully into open sea before the corner above |
| `southjoin_edit_f0` @(188,738) | `e45aff21` | The straight master→south-strip luminance line broken by irregular canopy spill |

## B. The dragon

The WMP03 layout gave the sky dragon `travel: {x: 30}` while the sprite's
head faces west — it flew tail-first (the owner's exact device finding).
**Data fix first**: origin moved 900 → 1260 (pre-sweep) and travel negated
to −30 — head-first westward through the same sky corridor. **Fire breath**
(`10bccfd8`, 1 generation, first roll): 8 frames pinned still→still — the
jaws open, a small orange flame puffs west from the mouth and fades. The
shipped journey is flight ×2 + breath (28 frames, `playLoops: 1`,
11.2 s), so the breath happens exactly once per crossing. Packaged crop
widened 64→68 for the flame.

## C. Second frontier ring — 768 → 1024 (`out/world/r2_*`)

Twelve pieces referencing the corrected inner ring's actual outer edges.
World: 4608 → **6144** world px; every layout coordinate swept +768
(`tools/sweep_layout.js`); the master sits byte-preserved at (256, 256).

| Piece | Job | Verdict |
|---|---|---|
| `r2_north_w` | v1 `53d6c8f9` REJECTED (outlined line-art ice) → v2 `0f2a2723` (glacier style chip) | Soft wind-streaked snowfield; snow-conformed onto the inner glacier palette |
| `r2_north_e` | `aaede817` | Frozen polar sea, floes thickening north. First roll |
| `r2_corner_nw` | `68bd3dd4` #0 | Snowfield + distant peaks; 1px generation border stripped; snow-conformed |
| `r2_corner_ne` | `b380b67f` #0 | Frozen sea thinning to open water. First roll |
| `r2_west_n` | `9ea8a0fd` | THE WESTERN FRONTIER: high ridges descending into a hazy valley, the caravan road continuing from the pass and fading west, one standing stone. Top ridge faded under snow by edit `a0bd334c`; snow-conformed |
| `r2_west_s` | v1 `5601f956` REJECTED (brown scree — WMP03's exact failure) → v2 `b85ff78f` | Green forested foothills tapering to open grass |
| `r2_east_n` | v1 `192d4769` + v2 `d75ca402` both palette-drifted; final = conformed v2 islet chain (top 200 rows) + **deterministic assembly of the approved east strip's own ocean** (`tools/assemble_ocean.js`, A-2 crop+assembly) | The Far Isles chain, then flat calm sea |
| `r2_east_s` | pixen `69b556e1` REJECTED (sparkle), pixen v2 `c606b2f5` REJECTED (navy dashes) → deterministic assembly of approved strip ocean | Flat open ocean |
| `r2_corner_se` | pixen `ba379034` REJECTED (glowing diamond), pixen v2 `2372a42e` REJECTED (isometric island cube) → crop of `r2_south_e`'s own right end | Warm sea corner carrying south_e's turquoise→teal gradient |
| `r2_corner_sw` | `f9a80e18` #0 | Foothills easing into plains. First roll |
| `r2_south_w` | `d88807bd` | Sunlit plains to a low coast; 7px white letterbox borders stripped |
| `r2_south_e` | `3fd5b65c` | Turquoise shallows deepening south. First roll |

**Lesson recorded:** generation cannot hold a flat ocean's exact palette —
two Pro rolls and two pixen rolls all drifted. Flat water joins are better
served by deterministic assembly of already-approved water (allowed under
A-2's crop/assembly), with generation reserved for content (islands, coasts,
ice). The deterministic water/snow palette conform (`tools/waterconform.js`,
mean/std match + snap to the target's own palette — invents no colors) is
the companion tool.

## D. Eggs

- **fire2 retired**: the corridor cut runs through its content box (the
  always-visible frame 0 would have painted pre-corridor forest over the
  road). Re-authored as **fire3** in the south-west forest — edit `d75b24f1`,
  anim `cd9e7a13` (10f) — and smaller (box 44×52 vs 42×44 on a busier
  canvas, per the copse-size flag).
- **stag** (NEW): edit `e76d0910` (roadside stag at the treeline), anim
  `c666f378` (10f, pinned to the empty source). Bear-pattern cycle: empty →
  sampled reversed entrance → standing hold → forward exit. Interval 34 s.
- **flock** (NEW): marsh birds lift from the reeds and settle— anim v1
  `94ccc39a` REJECTED (pools went transparent, no birds); v2 `60d0603a`
  with `no_background: false` accepted (subtle white specks circling the
  pools, both ends pinned to the untouched marsh). Interval 23 s.
- **caravan** (NEW): pixen `43800f6d`, a 20×19 covered wagon + oxen facing
  west, travelling the pass road (v5 `travel`, the ship's pattern).
  Interval 52 s.
- Intervals stay mutually distinct (9/13/14/18/20/23/26/30/34/40/45/52 s) —
  the renderer phase-separates purely by period, so no two eggs lock step.

## E. Labels

Outer Shoal removed (four names stacked in one SE column on device). The
Worldspine moved off the new pass onto the ridge it names. Marshlight nudged
NW clear of the flock's box. Three restrained frontier names added —
Wayfarer's Pass, The White Reach, The Far Isles — art-stream proposals under
Q-07 like every future-tier name. Net: 21 → 23 landmarks on a world 1.78×
larger.

## F. Rejected (evidence in `rejected/`)

`strip east/west/north` and corner v1s listed above; flock v1; the two
isometric/sparkle pixen seas; `r2_east_n` v1/v2 pale fields. The
aurora/shimmer family was not re-attempted (standing WMP03 rule).
