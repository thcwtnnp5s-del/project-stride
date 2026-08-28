// Deterministic open-ocean unification (A-2: palette remap of approved asset;
// invents no object, silhouette or frame).
//
// The open sea shipped as several independently-generated panels with slightly
// different teal dialects and straight panel edges (x=896, y=896, the far-east
// flat block, the south-east rectangle). This conforms the DEEP water of a set
// of rectangles to ONE target dialect (a clean swatch of the accepted east-coast
// sea), snapping every remapped pixel to the target's own water palette. Because
// every deep-ocean rectangle is conformed to the SAME target, their shared edges
// match and no panel rectangle survives; only true coast/shallows boundaries
// remain, which are natural.
//
// Guards so only open sea is touched: teal family only (b>=r+8, g>=r+3),
// mid/deep luminance only (55 < L < LMAX) so pale shallows, white floes/ice and
// sand are left exactly as they are.
//
// Usage (CLI): node ocean_unify.js <in.png> <out.png>
// Or require('./ocean_unify').unify(raster)  // conforms in place, returns count
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const LMAX = 198; // above this is pale shallows / floe / ice — leave it
const lum = (r, g, b) => 0.299 * r + 0.587 * g + 0.114 * b;
const isDeep = (r, g, b) => {
  const L = lum(r, g, b);
  if (L <= 55 || L >= LMAX) return false; // rock / floe / shallows
  return b >= r + 8 && g >= r + 3; // teal family
};

// Target dialect: a clean swatch of FLAT far-east open sea (moved out from the
// more mottled east-coast water at 820,560). Snapping the whole sea to the flat
// palette also flattens the authored-side mottling, so the texture-density
// boundary at x~832 does not survive as one sea.
const TGT = { x: 944, y: 380, w: 64, h: 180 };
// Rectangles of open sea to conform (deep-water edges only). [x,y,w,h]
const RECTS = [
  [636, 60, 388, 840], // whole eastern sea incl the far-NE corner above the ice
                       // (ice/floes are excluded by the guards, so only open
                       // water in this box is touched)
  [300, 860, 724, 164], // south / bottom deep sea (below the delta shallows)
  [504, 892, 520, 132], // r2_south_e panel: a distinct darker population its own
                        // stats flatten to the target (survived the broad rect)
];

const stats = (px) => {
  const m = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) m[k] += p[k];
  for (let k = 0; k < 3; k++) m[k] /= px.length;
  const s = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) s[k] += (p[k] - m[k]) ** 2;
  for (let k = 0; k < 3; k++) s[k] = Math.sqrt(s[k] / px.length) || 1;
  return { m, s };
};

function unify(atlas, extraRects = []) {
  // All source statistics are measured from a snapshot taken before any pixel
  // is rewritten, so overlapping rects do not compound and a later broad rect
  // cannot dilute an earlier tight one (each rect maps from the ORIGINAL water
  // distribution, exactly once). Writes land on `atlas`.
  //
  // `extraRects` (World Atlas Remaster 01) joins additional deep-water rects
  // to the SAME single global transform — both the source statistics and the
  // write loop — so an added area cannot introduce its own dialect. With no
  // argument the behaviour is byte-identical to the original.
  const rects = RECTS.concat(extraRects);
  const before = atlas.clone();
  const collect = (x0, y0, w, h) => {
    const px = [];
    for (let y = y0; y < y0 + h; y++) {
      for (let x = x0; x < x0 + w; x++) {
        if (x < 0 || y < 0 || x >= before.width || y >= before.height) continue;
        const i = before.idx(x, y);
        const r = before.data[i], g = before.data[i + 1], b = before.data[i + 2];
        if (isDeep(r, g, b)) px.push([r, g, b]);
      }
    }
    return px;
  };
  const tgtPx = collect(TGT.x, TGT.y, TGT.w, TGT.h);
  if (!tgtPx.length) throw new Error('no target water found');
  const t = stats(tgtPx);
  const palette = [...new Set(tgtPx.map((p) => (p[0] << 16) | (p[1] << 8) | p[2]))]
    .map((v) => [(v >> 16) & 255, (v >> 8) & 255, v & 255]);

  // ONE global source distribution across every rect, so the whole open sea
  // gets a single mean/std transform and no internal seam can survive between
  // two deep-water sub-populations (the per-rect version left a vertical tone
  // division at x~832 where the east bridge's authored sea met the frozen
  // strip). Deep water everywhere maps from the same `a` to the same target.
  let srcAll = [];
  for (const [rx, ry, rw, rh] of rects) srcAll = srcAll.concat(collect(rx, ry, rw, rh));
  if (!srcAll.length) return 0;
  const a = stats(srcAll);

  let changed = 0;
  for (const [rx, ry, rw, rh] of rects) {
    for (let y = ry; y < ry + rh; y++) {
      for (let x = rx; x < rx + rw; x++) {
        if (x < 0 || y < 0 || x >= atlas.width || y >= atlas.height) continue;
        const i = atlas.idx(x, y);
        // Map from the pixel's ORIGINAL value (snapshot), write to atlas.
        const r = before.data[i], g = before.data[i + 1], b = before.data[i + 2];
        if (!isDeep(r, g, b)) continue;
        const mapped = [r, g, b].map((v, k) => (v - a.m[k]) * (t.s[k] / a.s[k]) + t.m[k]);
        let best = null, bestD = Infinity;
        for (const p of palette) {
          const d = (p[0] - mapped[0]) ** 2 + (p[1] - mapped[1]) ** 2 + (p[2] - mapped[2]) ** 2;
          if (d < bestD) { bestD = d; best = p; }
        }
        atlas.data[i] = best[0]; atlas.data[i + 1] = best[1]; atlas.data[i + 2] = best[2];
        changed++;
      }
    }
  }
  return changed;
}

module.exports = { unify, isDeep, RECTS, TGT };

if (require.main === module) {
  const [inFile, outFile] = process.argv.slice(2);
  const atlas = png.load(inFile);
  const n = unify(atlas);
  png.save(outFile, atlas);
  console.log(`ocean_unify: conformed ${n} deep-water px -> ${outFile}`);
}
