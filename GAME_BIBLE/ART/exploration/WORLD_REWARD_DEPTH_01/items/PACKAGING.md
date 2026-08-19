# WORLD_REWARD_DEPTH_01 — item icon packaging

```
STATUS: packaging contract for the lead · NOT CANON · nothing here has been integrated
```

Companion to `README.md`. Regenerate with `node tools/package.js`
(reads `tools/accept.json`).

## 1. Files

`out/`:

```
icon_wolf_pelt_48.png
icon_lynx_pelt_48.png
icon_wolfhide_jerkin_48.png
icon_frostlined_jerkin_48.png
manifest.json
```

All **48 × 48 PNG, RGBA**, transparent background, **0 semi-transparent pixels**
(quantised at 128; the quantiser never fired), **0 despeckled pixels**, **one
4-connected opaque component each**. No cast shadow, no baked ground, no text.

## 2. Measured bounds

```text
icon_wolf_pelt_48        48x48   0,0..46,47   21 colours
icon_lynx_pelt_48        48x48   0,0..47,46   42 colours
icon_wolfhide_jerkin_48  48x48   3,1..44,46   26 colours
icon_frostlined_jerkin_48 48x48  5,1..43,45   46 colours
```

The two pelts fill the frame to its edges — intended (the clause asks for "object
centred and filling most of the frame") but worth knowing if any UI draws these with a
1-px inset border.

## 3. Content ids these serve

From `MILESTONES/WORLD_REWARD_DEPTH_01.md` §5:

| icon | content id | rarity | where it comes from |
|---|---|---|---|
| `icon_wolf_pelt_48.png` | `item.wolf_pelt` | common | wolf drop @ 45 % |
| `icon_lynx_pelt_48.png` | `item.lynx_pelt` | rare | frost lynx drop @ 35 % |
| `icon_wolfhide_jerkin_48.png` | `item.wolfhide_jerkin` | rare | `recipe.wolfhide_jerkin`, smithing L2 |
| `icon_frostlined_jerkin_48.png` | `item.frostlined_jerkin` | epic | `recipe.frostlined_jerkin`, smithing L4 |

## 4. Integration

`Scripts/art/package-art.js`, icon section: source these four from
`GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/items/out/` and emit them as
`assets/art/v1/item/wolf_pelt.png`, `lynx_pelt.png`, `wolfhide_jerkin.png`,
`frostlined_jerkin.png` — the same 48-px path shape and naming as every other shipped
item icon, so `PixelIcons` needs only the four new keys.

None of these replaces an existing file; all four are additions.

## 5. Manifest schema

```json
{ "id": "icon_wolf_pelt_48", "size": [48, 48],
  "bounds": { "left": 0, "top": 0, "right": 46, "bottom": 47 },
  "colours": 21, "status": "withheld", "note": "…" }
```

`status` is `"withheld"` on all four until an independent Visual QA verdict lands;
the lead flips them and re-runs `node tools/package.js`.

## 6. Known caveats, carried forward not fixed

- `icon_lynx_pelt_48` (42 colours) and `icon_frostlined_jerkin_48` (46) exceed the
  flat-shading spirit of the §7.2 clause because pixen anti-aliases its outlines. PE01
  hit the same thing on `skill_foraging` and recorded the same answer: **do not reduce
  the palette in code** — that is authoring (`RULES.md` A-2). A tighter version has to
  be a new PixelLab roll.
- `icon_frostlined_jerkin_48`'s pale fur is the brightest thing in the set; if QA reads
  it as specular, the fix is a re-roll asking for "cool grey fur, not white".
