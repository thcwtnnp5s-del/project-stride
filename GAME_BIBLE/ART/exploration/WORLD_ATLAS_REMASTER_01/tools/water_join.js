// WORLD ATLAS REMASTER 01 — deterministic water joins (A-2: every output
// pixel is one of two approved values — the pre-conform original or its
// globally-conformed mapping; no object, silhouette or frame is invented).
//
// Phase 0 of the remaster (`README.md` §9). Two defects, both edges of the
// WACUI ocean-conform RECTS showing in flat water at phone scale:
//
// D1 — a dead-straight vertical waterline at x=636 (y ≈ 440–960): the east
// bay's bright master-painted water is deep-predicate teal that sat OUTSIDE
// the conform rect, so the rect's western edge became a hard tonal step in
// open water. Fix: the bay strip joins the global conform (EXTRA_RECTS), and
// `shoalRamp` then restores the original bright water with a hash-dithered
// probability that falls from 1 at x=560 to 0 at x=636 — the step becomes
// ~76 px of shoaling gradient whose speckle boundary is never straight. East
// of x=636 nothing is remixed, so the ramp lands exactly on the conformed sea
// with no new edge.
//
// D8 — ghost tonal rectangles in the far-NE corner (x ≈ 975–1024, y 0–60):
// unconformed bright corner water above the conform rect's y=60 top edge.
// Fix: the corner strip joins the global conform (ice and floes are excluded
// by the deep-water guards, exactly as the far-NE extension of the pass-3
// refinement).
//
// Both rects feed the SAME single global source distribution inside
// `ocean_unify.unify` (its `extraRects` parameter), so the whole sea keeps
// mapping through one transform and no internal seam can survive.
'use strict';

// Extra deep-water rects joining the global ocean conform. [x, y, w, h]
const EXTRA_RECTS = [
  [560, 440, 76, 520], // D1: east-bay strip west of the old rect edge at x=636
  [896, 0, 128, 60],   // D8: far-NE corner above the old rect edge at y=60
];

// D1 shoaling remix. `base` has been globally conformed (including
// EXTRA_RECTS); `pre` is the snapshot taken immediately before the conform.
// For the bay strip only, restore the original pixel with probability
// 1 → 0 across x 560 → 636 (hash-dithered, salt 7 — salts 1–6 are taken by
// the crossfade, rim band and adoption feathers in package-art.js).
//
// y1 stops at 860, where the pre-existing south conform rect begins: below
// it both sides of x=636 were already one conformed sea with no line, and a
// ramp there would restore raw panel water as a new visible column (found
// and rejected in this round's first Phase 0 review).
const RAMP = { x0: 560, x1: 636, y0: 440, y1: 860 };

function shoalRamp(base, pre, hash) {
  let remixed = 0;
  for (let y = RAMP.y0; y < RAMP.y1; y++) {
    for (let x = RAMP.x0; x < RAMP.x1; x++) {
      const i = base.idx(x, y);
      const same = base.data[i] === pre.data[i] &&
        base.data[i + 1] === pre.data[i + 1] &&
        base.data[i + 2] === pre.data[i + 2];
      if (same) continue; // not conformed (land, sand, shallows) — leave it
      const pKeep = 1 - (x - RAMP.x0) / (RAMP.x1 - RAMP.x0);
      if (hash(x, y, 7) < pKeep) {
        for (let k = 0; k < 4; k++) base.data[i + k] = pre.data[i + k];
        remixed++;
      }
    }
  }
  return remixed;
}

module.exports = { EXTRA_RECTS, shoalRamp, RAMP };
