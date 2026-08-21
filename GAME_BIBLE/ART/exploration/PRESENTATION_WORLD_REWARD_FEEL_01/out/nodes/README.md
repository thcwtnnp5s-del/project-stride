# PWRF01 — node vignettes

## node_hardened_copper_seam_96.png — ACCEPTED

The gather node REGIONAL_CONTENT_PACK_01 shipped without stage art (B-3).
96 × 96, transparent, no figures — the established node-vignette family.

**Provenance (PixelLab, 2026-08-21):**

| Round | Job | Method | Outcome |
|---|---|---|---|
| 1 | `d2a151b9` | pixflux img2img over shipped `copper_seam.png`, strength 120 | **REJECTED** — blind QA: vein ambiguous hot/metal, leaning ember; rounded lobes read *softer* than the shipped seam; stray glyph-like artifact lower-right; sparkle glyphs (CR-40 register). Kept: `../../qa/nodes_round1/rejected_candidate_1.png` |
| 1 | `ddd4e2ab` | pixflux img2img, strength 90, seed 7412 | **REJECTED** — blind QA BLOCKER: reads as molten glow / magma, green stone family break, weak rock-golem suggestion. Kept: `../../qa/nodes_round1/rejected_candidate_2.png` |
| 2 | `4bf0ca75` | pixflux img2img, strength 280, seed 3391, prompt rewritten from the round-1 QA prescription (discrete nuggets on dark matrix, no glow) | **REJECTED** — blind QA: mineral read clean, but host rock reads *crumblier/softer* than the shipped seam (inverts the hardened fiction). Kept: `../../qa/nodes_round2/rejected_candidate_3.png` |
| 2 | `c8dd1d9d` | pixflux img2img, strength 330, seed 9218 | **ACCEPTED — PASS-WITH-NOTE.** Blind reviewer, before intent reveal, independently called it "the harder, denser rock… a tight fracture the rock is grudgingly giving up", discrete metallic nodules, no glow, no figural read. |

**QA protocol:** two independent blind rounds (fresh reviewer each round), M-13
staging — neutral scratchpad paths, `plate_N` / `item_X` names, shipped
`copper_seam.png` and `tin_seam.png` included unlabelled as controls,
first-impression questions asked and answered before any intent was revealed.
×2 was the verdict view (M-05).

**Notes on record from QA:**
- The node family's silhouettes read as "one boulder with three fills" —
  acceptable for labelled stage scenery, noted for any future side-by-side use.
- Recommended: one in-context check of hardened beside ordinary copper in the
  compact activity list when the Adventure redesign lands (Phase 2 visual QA).
- Round 2 reviewer's incidental finding, on record: shipped **Tin Seam**'s
  blind first read was "a giant cookie" (round 1 reviewer, plate 4). Not in
  this milestone's scope; a future node round should know.

**Measured bounds** (Scripts/art/png.js): left 10, top 11, right 79,
bottom 90 — carried into `AmbientAssets._scenery`.

**Packaging:** `Scripts/art/package-art.js` § Presentation, World & Reward
Feel 01 → `assets/art/v1/node/hardened_copper_seam.png`.
**Regression:** `test/node_art_resolution_test.dart` holds the content pack,
`PixelIcons._nodeArt` and `AmbientAssets._scenery` in agreement for every
node in the pack.
