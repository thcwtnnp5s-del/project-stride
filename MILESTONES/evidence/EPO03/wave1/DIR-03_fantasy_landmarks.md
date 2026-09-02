# DIR-03 — Fantasy landmarks (Fairy Castle · Storm House · Ice-Mage Tower)

Atlas px throughout (world ÷ 6); one atlas px = one sprite px = 2 pt on screen. 0 generations spent.

## TOP FAILURES

1. **Ice tower: a pedestal icon.** At ×2 an oval plinth on blank snow — no drift, approach or foundation.
2. **Fairy castle: a white keep, not a fae court.** 31×39 on dark canopy is a speck at ×1. The motes are five toned discs.
3. **Storm house: a 25×21 blob.** A 6 %-duty bolt is the only signal; no darkness, rain, bent trees or windows.

## WHAT TO REPLACE

All three props, **discarded** — rows `prop_fairy_castle`, `prop_storm_house`, `prop_ice_tower` deleted (PROD-WORLD-LIFE edits the JSON). Each becomes **in-terrain paint at its existing anchor** (D0033 §3; terrain also survives overview zoom). Motes, beacon and lightning superseded in slot. **No fourth landmark** — the east sea is world-life's; it would cost ≈80 gens the three need.

## WHAT TO KEEP

Every landmark/location coordinate; `frostmere_north_wall` golden (20 rows south of L3); `atlas-mask.js`, dither-SELECT, the single-defect loop; the old fork as the strike reference.

## PRODUCTION FAMILY

**Regions** — `inpaint_image` on the current composite, `no_background` on, 24 px ramp, `manifest_landmarks.json`, composited **after** the terrain teams.

| id | mask rect | crop | sequence / constraints | terrain becomes |
|---|---|---|---|---|
| L3 `ice_bastion` | 420–540 × 116–236 | 380–580 × 72–264 (200×192) | **first**: outside core, no golden; NE-shelf mask stays east of x 540 here; nothing lit under the Frozen Shelf marker (445,176) | crevassed bastion, three stepped terraces, blue south faces, drifts north; crystalline tower footed at (468,177); 4–5 px frozen causeway with ice pillars winding up from the SW; sastrugi |
| L2 `storm_pocket` | 170–266 × 856–952 | 130–306 × 816–992 (176×176) | **after the SW coast**; SW team leaves no beach/road in the rect; `south_strand_w` re-extracted again in this commit | NE–SW darkness ≥25 L* below the heath, fading out at the edge; black-gabled house 28–34 px at (218,900), three amber windows; blasted trees leaning away, one split and charred; wet track |
| L1 `fairy_glade` | 296–416 × 392–496 | 256–464 × 352–544 (208×192) | **last**: core re-base (D0033 §2); west-face mask ends at x 296 here; clear of the Greenwatch and Whispering Woods markers | glade in the oak canopy; castle grown from three living birch trunks, moss roofs, amber windows at (335,452); root bridge over a moss-green pool ringed with gold flower-lights; faint paths; ragged copse edge |

Prompts: *"top-down fantasy map painting, same brush and palette as the surrounding {ice shelf / heath / oak forest}; [features above]; no plinth, pedestal, plate, isometric box, cloud shape or text"*. No cyan/teal (L-16).

**Overlays** — four sprites in three existing slots, net +1: PROD-WORLD-LIFE frees one (recommend `overlay_lantern`) or the producer records an R-9 raise (VAWO01 FOUNDATION-K).

| overlay | canvas · frames · cadence | opac. | depicts | top-left (atlas → world) | tool / gens |
|---|---|---|---|---|---|
| `overlay_fae_court` (⇐ motes) | 112×80 · 16 f · 220 ms · loops 3 · gap 14 s (43 %) | 1 | 5–7 fairies, 6–10 px winged silhouettes, 2–3 px warm glow, arcs converging on the castle; 1-px trails fading over 3 f; f10–15 gathering pulse | (300,400) → (1800,2400) | pixen 24² ×3 (1 ea) → `animate_image` 4-f wingbeat (1) → `fairy-arcs.js` (0) |
| `overlay_storm_rain` (new) | 96×96 · 8 f · 120 ms · loops 6 · gap 9 s (39 %) | 0.55 | diagonal 1-px pale streaks 6–10 px long; dark wisps churning at the top | (170,856) → (1020,5136) | pixen 96² ×3 (1) → `animate_image` ×2 (2) |
| `overlay_storm_strike` (⇐ lightning) | 80×96 · 8 f · 100 ms · loops 1 · gap 11 s | 1 | f1 fork top→roof + dithered white-blue ground flash 28 px, windows whited; f2 afterglow; f3 thinner second fork; f4 fade; rest empty | (178,808) → (1068,4848); foot on the roof (218,880) | pixen 80×96 ×4 (1) → script-assembled (0) |
| `overlay_ice_beacon` (⇐) | 96×96 · 10 f · 260 ms · loops 2 · gap 9 s (37 %) | 1 | crown light swells; pale cone sweeps L→C→R→C over the causeway; 1–2 px cold-white drift sparkle; f0 empty | (420,116) → (2520,696) | `edit_image_pixen` in place ×4 (1) → diff-key (0) + pixen 32² sparkle ×2 (1); fallback `animate_image` (2) |

## PIXELLAB BUDGET

| item | unit (GOV-04) | rolls | cap |
|---|---|---|---|
| L3 inpaint 200×192 | 25 (20–40 tier; confirm on job 1) | 3 | 75 |
| L2 inpaint 176×176 | 20–25 | 3 | 75 |
| L1 inpaint 208×192 | 25 | 3 | 75 |
| four overlays | 1–2 | as tabled | 27 |
| one 40-tier re-roll, any region | 40 | 1 | 40 |
| **family** | | | **target 252 · cap 300** |

Stop at 300; sum cost lines (M-17).

## PHONE-SCALE SUCCESS CRITERIA

197×426 FOV, opening zoom:
- Each landmark named within 2 s; scene ≥96 px (half the screen), structure ≥28 px, at every zoom.
- L1: ≥3 fairies visible at any instant, wing pixel resolvable at ×2, arcs not jitter; no disc, square or face.
- L2: ground at the house ≥25 L* darker than heath 60 px out; rain reads as lines at ×1; a strike every ≈12 s with a ≥24 px ground flash.
- L3: causeway reads as a road to the gate; terraces show blue shadow faces; beacon pulse visible at ×1; nothing reads as a pedestal.
- Guards pass: `--check`, palette, A-4 rim, goldens, `atlas_layout_test`; no straight line or generated rectangle; ≤12 overlays in the glade FOV. Physical iPhone is final.
