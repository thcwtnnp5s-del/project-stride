# ART-13 — Material system brief (FMPO02 Wave 1)

One chassis (`chassis_64.png`, unchanged) frames eleven different interior SURFACES instead of eleven different borders. All hex verified by script against the WCAG relative-luminance ceiling `#7C7263` (L=0.1722) and against `textPrimary #F0E7D8` (L=0.8063) at 4.5:1 (needs background L≤0.1403).

## 1. Material ledger — interior surface per family

Ramp is shadow→base→mid→highlight-fleck. All stops sit under the chrome ceiling; **base** (largest area, where body text sits) carries the reported contrast against `textPrimary`.

| Family (screen) | Surface material | Ramp (hex) | Base contrast | Grain scale @×2 |
|---|---|---|---|---|
| Field journal (Adventure) | Aged parchment | `#1C1811 #241F17 #332B1F #463A28 #5C4C34` | 13.4:1 | isotropic fleck, 24 src px repeat (48 logical), irregular placement |
| Workbench folio (Craft) | Waxed canvas | `#1A1C15 #23261B #333524 #464A31 #5B5E3F` | 12.6:1 | isotropic weave, 16 src px repeat (32 logical) |
| Guild handbook (Skills) | Vellum | `#1D1912 #26211A #362E22 #4B4030 #61533E` | 13.0:1 | fine fleck, 24 src px repeat (48 logical) |
| Equipment case (Inventory) | Oiled leather | `#1B1310 #241914 #3A2620 #54372C #6C4736` | 14.0:1 | directional streak, 12×32 src tile (24×64 logical) |
| Traveler folio (Character) | Dark wood | `#160F0A #1E140E #2E2015 #43301F #5A4229` | 14.7:1 | directional grain, 12×32 src tile |
| Combat kit (Combat) | Steel plate | `#14161A #1C1F24 #2B2F36 #3E434C #535A63` | 13.5:1 | fine speckle, 16 src px repeat (tightest — metal reads finer than fiber) |
| Bestiary (creature preview) | Slate board | `#15161A #1E2024 #2C2F34 #3F444A #565B60` | 13.3:1 | fine speckle, 16 src px repeat |
| Atlas (World) | Linen backing | `#1A1712 #23201A #332E25 #463F32 #5A5142` | 13.3:1 | isotropic weave, 16 src px repeat |
| Pinned parchment (Goal Board) | Parchment scrap | `#1C170F #26201A #372E22 #4C4130 #63533D` | 13.1:1 | isotropic fleck, 24 src px repeat, + pin-hole ornament (discrete, not tiled) |
| Blueprint ledger (recipe detail / Roadmap) | Chalked slate | `#12161C #1A2028 #28323E #3B4A58 #4E6072` | 13.4:1 | fine speckle, 16 src px repeat, cooler hue lean than Bestiary/Combat |
| Reward trophy (victory panel) | Dark wood + brass fleck | `#160F0A #1E140E #332417 #4E351F #6B4A22` | 14.7:1 | directional grain 12×32 src, brass fleck ties to `rewardLightInk` at spawn points only |

Grain tile is baked non-grid (fleck positions jittered inside the tile) so the repeat reads as noise at native and ×2 (PIXELLAB_UI_PRODUCTION_PLAN §3.5) — a *regular* speckle at this pixel count reads as plaid, not material.

Eight named materials, eleven families: slate and dark wood each carry two families with a hue-lean shift (cooler blueprint vs neutral bestiary; neutral folio vs redder trophy) rather than inventing a ninth/tenth material, so PixelLab still anchors off eight seed palette images (§5).

## 2. Button material ramps

Shadow / mid / sheen / edge, plus one highlight rule. Pressed and disabled are remaps, never new art.

| Button | Shadow | Mid | Sheen | Edge | Highlight rule |
|---|---|---|---|---|---|
| Leather primary | `#241F18` | `#3A332B` (=`surfaceRaised`) | `#4A4034` (=`actionSheen`) | `#6B5A3E` (=`actionEdge`) | 1px specular line, top-left quarter of the top edge only |
| Steel secondary | `#1E222A` | `#2E3440` | `#3E4A5C` | `#5A6B80` | 1px cold specular, full top edge (flat metal reads edge-lit, not corner-lit) |
| Oxblood danger | `#2E1614` | `#4A211E` | `#68302A` | `#7A4238` | no specular; danger reads matte/dried, not glossy |
| Moss ready | `#20281A` | `#324226` | `#465C33` | `#5E7842` | 1px specular, top-left, same geometry as leather (positive echoes primary) |
| Blue-steel brace | `#1C2130` | `#2A3348` | `#3A4268` (=`defenseEdge`) | `#4E5C86` | 1px cold specular, full top edge (same family as Steel secondary) |
| Wood eat | `#1A120C` | `#2A1D12` | `#3E2C1B` | `#5A4128` | no specular; end-grain, matte |

**Pressed:** invert the vertical stop order (sheen↔shadow, mid stays put, highlight rule suppressed). Deterministic remap of the same four stops — no new pixels drawn, no new frame.

**Disabled:** remap all four stops through the neutral warm-grey ladder at matched luminance rank (shadow→`surfaceGround`-family, mid→`surfaceBlock`, sheen/edge→`surfaceRaised`-family, i.e. drop chroma to zero, keep the four luminance steps). No alpha — P-1's zero-semi-transparency baseline must not regress for a state.

## 3. Region atmosphere — deeper deltas

Measured (CIE L*, D65): `surfaceCard` L*=10.55. Current deeps sit only 1.6–4.7 L* from it — under one rung of the surface ladder itself (`surfaceCard`→`surfaceBlock` is a 5.1 L* step) — which is why the wash reads as noise, not weather. Proposed deeps push to 8–13 L*, roughly two ladder rungs, while raising chroma so they read as *tint*, not a fifth neutral rung (the ladder itself is chroma-zero; these are not).

| Region | Current deep | Current ΔL* | Proposed deep | Proposed ΔL* |
|---|---|---|---|---|
| Haven | `#20261A` | 3.67 | `#313B22` | 12.77 |
| Woods | `#182A20` | 4.69 | `#213F2E` | 13.37 |
| Stonefall | `#292019` | 2.52 | `#3D2C1D` | 9.01 |
| Frostmere | `#1C222E` | 2.60 | `#26364C` | 11.65 |
| Hollow | `#211E2B` | 1.58 | `#302949` | 8.23 |

`forRegion`/`forRegionDeep` signatures are unchanged — this is a value swap on five existing constants, not a new token or a new call site.

## 4. Rarity language — ink + bracket material

`RarityStyle` already supplies ink + dim accent; the addition is a *bracket material* — the item card's corner ornament, not a new border weight — so colour and material co-signal the same rank:

| Rarity | Ink (existing) | Bracket material |
|---|---|---|
| Common | `#A8A093` | none — bare chassis corner |
| Uncommon | `#86B06A` | waxed-canvas corner patch |
| Rare | `#7D91DE` | oiled-leather corner patch |
| Epic | `#A987D8` | dark-wood corner inlay |
| Legendary | `#E0A63F` | brass corner inlay (echoes `rewardLightInk`, never gold-banded — L-19) |

Ornament, not a second frame: same chassis, a small discrete corner asset swapped by rank, matching PIXELLAB_UI_PRODUCTION_PLAN's "discrete ornament" raster-chrome category. No new hex — all five inks are existing tokens.

## 5. PixelLab palette-anchoring method

- **Surfaces** (the eleven ramps above): generate via `create_tiles_pro` or `create_image_pixen` with `color_image` set to a small anchor swatch (a committed, pushed 8×N px PNG holding that family's ramp, shadow→highlight) so PixelLab's own shading never invents an off-ramp tone. Follow every surface generation with `reduce_colors` snapped to the same ramp (N=4 or 5) — the deterministic remap that makes "grain not pattern" enforceable, not hoped-for.
- **Sprites/props/creatures** (content art, not chrome): no restrictive `color_image` — L-18/A-1 already governs those through the accepted master's measured ramp at packaging time. Forcing the chassis ramp onto a creature would flatten it into UI chrome.
- Order per surface: generate tile → `reduce_colors` → tile-seam check (§3.5, unchanged) → palette guard.

## 6. Guard extension

`Scripts/art/check-art-palette.js` `CHROME` currently lists `assets/ui/v1/{frame,surface,ornament}`. Add the new material directory these ramps will populate:

```js
const CHROME = ['assets/ui/v1/frame', 'assets/ui/v1/surface', 'assets/ui/v1/material', 'assets/ui/v1/ornament'];
```

`assets/ui/v1/material/<family>/` holds the eleven tiles plus anchor swatches once committed. No change to `ALL_ART`, `FRAMES`, or teal/alpha/substrate — the new directory only needs the ceiling check: these are surfaces, not frames, and carry no substrate risk of their own (every family's darkest stop is deliberately not `surfaceCard`/`surfaceGround`, per the table above).
