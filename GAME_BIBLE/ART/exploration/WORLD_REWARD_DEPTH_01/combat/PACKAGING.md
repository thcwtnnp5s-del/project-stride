# WORLD_REWARD_DEPTH_01 — combat packaging

```
STATUS: packaging contract for the lead · NOT CANON · nothing here has been integrated
```

Companion to `README.md`. Regenerate with `node tools/package.js`
(reads `tools/accept.json`).

## 1. Files

`out/combat/`:

```
lynx_idle_f0.png … lynx_idle_f6.png          (7)   56 x 56
lynx_attack_f0.png … lynx_attack_f8.png      (9)   56 x 56
lynx_hit_f0.png … lynx_hit_f6.png            (7)   56 x 56   (withheld)
lynx_defeat_f0.png … lynx_defeat_f6.png      (7)   56 x 56
backdrop_frostmere.png                       (1)  192 x 96  opaque
manifest.json
```

Not packaged: `fx_reward_burst` (withheld — README §4.4). Its frames stay in
`candidates/fx_reward_burst/f0..f6.png`.

Every figure PNG is RGBA with **0 semi-transparent pixels**; the backdrop is fully
opaque. **0 teal pixels** (`#58d6c0` ± 12) anywhere.

## 2. The facts the stage needs

| fact | value |
|---|---|
| Figure canvas | **56 × 56** — the same canvas as the shipped wolf and goblin |
| Facing | **west** (enemy side of the stage). Nothing is mirrored in code |
| Standing anchor row | **39** (the wolf's is 40) |
| Lowest opaque row across all tracks | 39, except `lynx_defeat` f1–f3 and f6 which reach **40** while lying |
| Backdrop | **192 × 96**, opaque, **groundRow 88** — identical to `backdrop_forest` / `_mine` / `_hollow` |
| Enemy standing column on the backdrop | 138 (≈ 72 % of the width), the shipped convention |
| Source canvas from `animate_character` v3 | 68 × 68; crop origin **(6, 6)** |
| Frames whose opaque box touched a crop edge | **0** |

Height check: the lynx's opaque top is row 13 with the anchor on 39, so the animal
stands **26 rows** above the ground — 52 dp at ×2 against the Traveler's ~120 dp.
Waist height on a walker, as the wolf is.

## 3. Measured bounds and footprints

`bounds` = union opaque box across the sequence.
`footprint` = `Scripts/art/png.js` `footprint()` on frame 0 — the same function
`package-art.js` uses for `combat_*`.

```text
lynx_idle    56x56  10,13..51,39   footprint x 22..44 (23 px), bottom 39
lynx_attack  56x56   3,13..52,39   footprint x 22..44 (23 px), bottom 39
lynx_hit     56x56   8,13..51,39   footprint x 22..44 (23 px), bottom 39
lynx_defeat  56x56   5,13..51,40   footprint x 22..44 (23 px), bottom 39

for comparison, the shipped wolf:
wolf_idle    56x56   7,12..51,40   footprint x 21..45 (25 px), bottom 40
```

All four lynx tracks share one footprint, so `GroundedSprite` places every track by
the same contact centre and the animal never shifts between idle, attack and defeat.

**`lynx_attack` travel.** The pounce carries the body forward: the union box reaches
x 3 against the idle's x 10, i.e. ≈ 7–10 px toward the Traveler, and frame 8 is still
extended. The shipped `wolf_attack` travels 3 px by the same measure. The track is
`once`; the stage returns to `lynx_idle` when it finishes, so the snap-back is one
frame. If that reads badly on device, the cheap fix is dropping f8 (`frames: 8`).

## 4. Manifest schema

```json
{ "id": "lynx_idle", "kind": "enemy.frost_lynx", "frames": 7, "fps": 6,
  "loop": "pingpong", "canvas": 56, "anchor": 39, "baseline": 39,
  "bounds": { "left": 10, "top": 13, "right": 51, "bottom": 39 },
  "status": "withheld", "note": "…" }
```

`status` is `"withheld"` on **every** entry until an independent Visual QA verdict
lands; the lead flips the accepted ones to `"accepted"` and re-runs
`node tools/package.js`. The author's recommendation is: accept `lynx_idle`,
`lynx_attack`, `lynx_defeat` and `backdrop_frostmere`; leave `lynx_hit` withheld.

## 5. Suggested Dart entries (for the lead — not written by this agent)

`lib/ui/icons/combat_assets.dart`, alongside the existing enemies. The table maps by
meaning, and this enemy has no hit track for the same reason the wolf has none — the
hit reaction is `fx_impact` at the enemy plus the UI-side recoil offset already in
place (`RULES.md` A-2, a deterministic presentation, not authored art):

```dart
// enemy.frost_lynx — WORLD_REWARD_DEPTH_01/combat/README.md, 2026-08-19.
// lynx_hit is packaged but withheld: three rounds of the wolf flinch never read in
// PLAYABLE_EXPANSION_01 and one round of the lynx flinch reads as a prowl. Same
// treatment as the wolf.
CombatantArt(
  idle:   CombatTrack(id: 'lynx_idle',   canvasWidth: 56, canvasHeight: 56, anchorRow: 39, …),
  attack: CombatTrack(id: 'lynx_attack', canvasWidth: 56, canvasHeight: 56, anchorRow: 39, …),
  defeat: CombatTrack(id: 'lynx_defeat', canvasWidth: 56, canvasHeight: 56, anchorRow: 39, …),
)
```

Backdrop: `backdrop_frostmere` keys off `location.frostmere` exactly as
`backdrop_forest` keys off the woods, `groundRow` 88.

`strikeFrame` for `lynx_attack`: **frame 6** — the first frame of the extended pounce,
where the paw and open jaws reach the Traveler's side of the gap.

## 6. Regenerating

```
node tools/fetch_lynx.js        # re-download the four animation groups
node tools/package.js           # crop, quantise, remap, write out/combat + sheets
node tools/stage.js             # rebuild the blind set p2w6/ and tools/BLIND_KEY.txt
node tools/ctx.js <out> <backdrop> <groundRow> <scale> "<file>|<col>|<anchor>" …
```
