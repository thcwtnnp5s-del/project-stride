# ENEMIES report — FMPO02 Wave 2 (ART-08)

Balance: 450→1378 generations_used account-wide (shared by every concurrent
PROD-* lead this wave — not this family's number). **This lead's own spend:
43 generations** against a 280 cap. Full job table: `ledger/ENEMIES.md`.

## 1. Habitat plates — accepted (`out/enemies/habitat_<region>.png`, 192×76, opaque)

| File | Region | Note |
|---|---|---|
| `habitat_forest_floor.png` | Whispering Woods | mossy roots, packed dirt, dusk, dispatched as-is from the pre-existing probe job |
| `habitat_rocky_ledge.png` | Stonefall | **replaced mid-session** — producer review flagged the first accept as staged (cut block + loose plank + a stray sky-disc visible on closer zoom); round-2 pick is a natural jagged shelf with a cave-mouth gap behind and one timber log at the far right only |
| `habitat_cave_shadow.png` | Stonefall (deep) | **kept as originally accepted** — producer flagged it as reading like a wall seen face-on rather than a floor; one reroll of 3 candidates produced nothing better (an explicit open-flame brazier, a full architectural tunnel in perspective, and a wrong-material vine-textured wall) — see UNRESOLVED below |
| `habitat_snowbank.png` | Frostmere | packed snow ridge, pale rime conifers behind, correct cool-family palette |
| `habitat_hollow_rootbed.png` | Forgotten Hollow | roots crossing the ground, pale fungi caps, dark loam floor |

All 5 pass: exactly 192×76, fully opaque, zero teal-collision pixels
(Chebyshev ≥48 from `#58D6C0` everywhere checked), zero partial-alpha pixels,
no sky/horizon, no fire.

**UNRESOLVED:** `habitat_cave_shadow` still reads more like a rock wall than
a floor a creature stands on. Two rounds (6 candidates total) did not fix
this without introducing a worse defect each time (fire, architecture,
wrong material). Recommend a fresh brief for this one plate alone rather
than a third same-approach reroll — logged for `JOURNAL/OPEN_QUESTIONS.md`.

## 2. Missing tracks — `out/enemies/<family>_<track>_f<n>.png`

| Family | Track | Frames | Canvas | Anchor row | Notes for integrator |
|---|---|---:|---|---:|---|
| boar | hit | 6 (f0-f5) | 56² | 43 (unchanged from `boar_idle_f0`) | single component, no size jump |
| bear | hit | 6 (f0-f5) | 76² | 61 (unchanged) | same |
| salamander | hit | 6 (f0-f5) | 56² | 50 (unchanged) | same |
| crawler | hit | 6 (f0-f5) | 48² | 40 (unchanged) | same |
| crawler | defeat | 8 (f0-f7) | 48² | 40 (unchanged) | **partial success, recorded not faked**: legs splay and the body sits a little lower, but height only drops ~9% across the sequence — not the dramatic "drops flat" the brief asked for. 2-roll cap reached (both rolls similar); shipping the better roll rather than chasing a 3rd. If the owner wants a real collapse read, this needs a different technique (e.g. a hand-authored last frame pinned via `animate_image`'s `last_frame_url`), which is outside this session's tool-use pattern. |

Frame semantics: `animate_image` returns `frame_count+1` images (index 0 ≈
the input, near-identical — mean channel delta ~4/255, confirmed by direct
pixel diff — then `frame_count` genuinely new frames). For these even-target
tracks I dropped index 0 and used the `frame_count` generated frames,
renumbered f0..f(N-1), which lands exactly on the requested 6f/8f.

## 3. Elite distinguishing states — `out/enemies/<elite>_<track>_f<n>.png`

| Elite | Base | Idle | Attack | Canvas | Anchor row | Strike frame (attack) |
|---|---|---:|---:|---|---:|---:|
| old_grey | wolf | 8f (f0-f7) | 8f (f0-f7) | 56² | 40 (matches wolf exactly) | f3 (leftmost reach, one frame before retraction) |
| gallery_foreman | goblin | 8f (f0-f7) | 8f (f0-f7) | 56² | 46 (matches goblin exactly) | f5 |
| rimeclaw_matriarch | lynx | 8f (f0-f7) | 8f (f0-f7) | 56² | **40** (shipped lynx is 39 — 1px lower; the edit made the cat "larger/huskier" per brief, which plausibly explains it) | f5 |
| guardian_awakened | guardian | 8f (f0-f7) | 8f (f0-f7) | 96² | 83 (matches guardian exactly) | f5 (heavy-swing extension) |

All four passed the blind side-by-side test at card size
(`review/enemies/elites_final_x4.png`): each elite reads as "the same
species, something's different" in one glance — grey muzzle + scar on the
wolf, iron helmet + bulk on the goblin, dark/frosted coat + white chest on
the lynx, glowing rune cracks + lighter stone on the guardian. No full
idle+attack set failed twice, so nothing had to be shipped as an idle-only
fallback.

One cleanup applied: `old_grey_idle` frames 2-5 (as generated) carried a tiny
disconnected fleck near the muzzle (a breath-mist artifact PixelLab added,
color-checked and **not** a reserved-teal violation — Chebyshev 48, well
outside the ±10 radius — but still a second silhouette component). Removed
deterministically with a keep-largest-connected-component script (no new
pixels invented); re-verified single component and unchanged anchor row
before shipping.

**Integrator note on `combat_assets.dart`:** elites currently byte-reuse
their base species files. These are genuinely new sprites, so the packaging
step will need fresh `CombatantArt` entries (e.g. `combat_old_grey`) rather
than continuing to point at `combat_wolf`, and `sprite_footprints.dart` will
recompute a footprint from each elite's own frame 0 when it does. The
`rimeclaw_matriarch` 1px anchor difference from `lynx` only matters if the
integrator chooses to force a shared footprint; if each elite gets its own
footprint entry (the natural read of GOV-03 §1), no correction is needed.

## 4. Boar↔Ram insurance

- `out/enemies/ram_idle_insurance_f0..f6.png` (7 frames, 56², anchor row 42 —
  unchanged from shipped `ram_idle_f0`): horns thickened into a bold, tight
  curl, clearly bolder than the original thin curve at the outline level the
  brief asked for (a shape/grayscale comparison would now register it).
  Single `edit_image_pixen` roll, then **one** `animate_image` roll
  reproduced the full breathing-idle cycle cleanly — both conditions the
  brief set for re-animating were met, so this is a candidate **full
  replacement** of the shipped `ram_idle_f0-f6` set (not a patch — adopting
  it means swapping all 7 frames, since only frame 0 was edited and the rest
  were freshly re-animated from it).
- **Not yet integrated** (no Dart/`package-art.js` edits made per brief).
  If adopted, re-run the in-place boar/ram silhouette IoU per the original
  ART-08 §"Silhouette collision" instruction — I did not have the prior
  round's IoU tooling in scope here to re-measure it myself.
- Boar was left untouched — the brief's own text narrowed this lead's task
  to "the ram idle f0" only, so no bristle-ridge edit was attempted on the
  boar side.

## 5. What the integrator needs to do

1. Land `out/enemies/habitat_<region>.png` (5 files) into whatever asset
   path `EncounterHabitats` expects; none require crop/pad (all exactly
   192×76 already).
2. Register `boar_hit`, `bear_hit`, `salamander_hit`, `crawler_hit` (6f each)
   and `crawler_defeat` (8f) in `combat_assets.dart`'s per-family track
   tables, using the canvases/anchor rows above.
3. Decide how elites are registered (new `CombatantArt` ids vs. continued
   reuse) and land the 4×16 elite frames plus the 4 strike-frame values
   above.
4. Decide whether to adopt `ram_idle_insurance_*` as the new shipped
   `ram_idle` track; if yes, re-measure the boar/ram IoU.

## 6. UNRESOLVED

- `habitat_cave_shadow` still reads as a wall rather than a floor after one
  producer-directed reroll; recommend a fresh approach, not a third
  same-brief attempt (see §1). Logged for `JOURNAL/OPEN_QUESTIONS.md`.
- `crawler_defeat`'s collapse read is honestly weak (both rolls); flagging
  rather than claiming success — see §2.
