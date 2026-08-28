// WORLD ATLAS REMASTER 01 — R1 (NE Pack-Ice Corridor) source + mask prep.
//
// Run after `node Scripts/art/package-art.js` so the crop reflects the
// shipped composite (Phase 0 water joins included).
//
// Crop: atlas (560, 0), 464x320 — frozen shelf west, dialect seam at x~755,
// mint-tinted floes x~620-720, truncated black wedge at (725-770, 215-250),
// pale top-right sheet junctions, volcano cape and watchtowers at the bottom
// (frozen), Cinder Skerries and the iceberg in open sea east (frozen).
//
// Mask (white = regenerate), authored so every edge lands in uniform terrain
// and every protected feature keeps >=20 px standoff (PROTECTION_PLAN.md):
//   - left edge x=608 (48 px inside the crop) in clean pale shelf ice
//   - top edge y=0 (canvas edge)
//   - bottom edge y=258 over ice; carved to y=253 over the east watchtower
//     (top 273) and y=245 over the volcano's green north cape (top 265)
//   - east boundary: a diagonal from (760,258) to (910,70) + 14 px seaward
//     buffer, following the existing ragged ice edge so the generator can
//     re-lace it without owning the open sea; plus a top strip (y<90) to the
//     canvas edge for the pale-sheet junction rectangles
//   - Cinder Skerries (921-965 x 175-235) and the pale iceberg (974-991 x
//     210-225) fall entirely outside the mask (FC: frozen centers)
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const CROP = { x: 560, y: 0, w: 464, h: 320 };

const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const src = new png.Raster(CROP.w, CROP.h);
for (let y = 0; y < CROP.h; y++) {
  for (let x = 0; x < CROP.w; x++) {
    const si = atlas.idx(CROP.x + x, CROP.y + y), di = src.idx(x, y);
    for (let k = 0; k < 4; k++) src.data[di + k] = atlas.data[si + k];
  }
}

// Mask in atlas coordinates, rendered into crop-local space.
const bottomLimit = (ax) => {
  if (ax >= 704 && ax < 768) return 253; // east watchtower standoff
  if (ax >= 768 && ax <= 816) return 245; // volcano north cape standoff
  return 258;
};
// Signed distance (px) NW of the ice-edge diagonal (760,258)->(910,70).
const P1 = { x: 760, y: 258 }, P2 = { x: 910, y: 70 };
const LEN = Math.hypot(P2.x - P1.x, P2.y - P1.y);
const sideDist = (ax, ay) =>
  ((ax - P1.x) * (P2.y - P1.y) - (ay - P1.y) * (P2.x - P1.x)) / LEN;

const white = (ax, ay) => {
  if (ax < 608) return false;
  if (ay >= bottomLimit(ax)) return false;
  if (ay < 90) return true; // top strip to the canvas edge
  return sideDist(ax, ay) >= -14;
};

const mask = new png.Raster(CROP.w, CROP.h);
let count = 0;
for (let y = 0; y < CROP.h; y++) {
  for (let x = 0; x < CROP.w; x++) {
    const on = white(CROP.x + x, CROP.y + y);
    const i = mask.idx(x, y);
    const v = on ? 255 : 0;
    mask.data[i] = v; mask.data[i + 1] = v; mask.data[i + 2] = v; mask.data[i + 3] = 255;
    if (on) count++;
  }
}

const srcDir = path.join(__dirname, '..', 'src');
fs.mkdirSync(srcDir, { recursive: true });
png.save(path.join(srcDir, 'r1_ice_src_464x320.png'), src);
png.save(path.join(srcDir, 'r1_ice_mask_464x320.png'), mask);

// Overlay for review: mask boundary tinted magenta over the crop.
const overlay = src.clone();
for (let y = 0; y < CROP.h; y++) {
  for (let x = 0; x < CROP.w; x++) {
    const on = white(CROP.x + x, CROP.y + y);
    const edge = on && [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= CROP.w || ny >= CROP.h) return false;
      return !white(CROP.x + nx, CROP.y + ny);
    });
    const i = overlay.idx(x, y);
    if (edge) { overlay.data[i] = 255; overlay.data[i + 1] = 0; overlay.data[i + 2] = 255; }
    else if (on) { overlay.data[i] = Math.min(255, overlay.data[i] + 40); }
  }
}
png.save(path.join(srcDir, 'r1_ice_mask_overlay.png'), overlay);
console.log(`r1 prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
