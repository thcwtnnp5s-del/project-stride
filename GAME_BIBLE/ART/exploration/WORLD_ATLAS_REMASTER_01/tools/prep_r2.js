// WORLD ATLAS REMASTER 01 — R2 (West Verge / the forest wall) prep.
//
// Run after `node Scripts/art/package-art.js`.
//
// Problem (D4, south half): the interior forest's west edge runs as a
// straight density/saturation wall down x~256 from y~545 to ~830 (the master
// boundary showing as art), and a half-ghost snowy peak at (205-280, 585-690)
// is sliced by it — summit painted, west face dissolving into smears, east
// flank overpainted by canopy. The WAR01 west_join adoption already authored
// the 360-584 band; this region owns 576-832.
//
// Crop: (152, 528) 184x352. Mask: x 200-272, y 576-832 —
//   - y0=576 keeps the west caravan road band (golden: 128-256 x 495-575)
//     untouched with the registry guard proving it
//   - x1=272 feathers into the A-4 rim band (256-276) and never the core
//   - x0=200 lands in the open meadow west of the ghost peak's foot
//   - y1=832 lands in the forest/plain transition south of the wall
//   - fire3 overlay (284-328 x 624-676), tree_rustle_a (276-324 x 596-644),
//     Wolfwood label (334,686), stag (156-184 x 493-515): all outside.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

// Mask bottom y1=808: the WAR01 south strand is registry-protected from
// y=810 (golden south_strand_w, 128-528 x 810-870) — the mask ends in
// uniform canopy just above it and the accepted strand top provides the
// lower transition.
const CROP = { x: 152, y: 528, w: 184, h: 328 };
const MASK = { x0: 200, x1: 272, y0: 576, y1: 808 };

const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const src = new png.Raster(CROP.w, CROP.h);
for (let y = 0; y < CROP.h; y++) {
  for (let x = 0; x < CROP.w; x++) {
    const si = atlas.idx(CROP.x + x, CROP.y + y), di = src.idx(x, y);
    for (let k = 0; k < 4; k++) src.data[di + k] = atlas.data[si + k];
  }
}
const white = (ax, ay) => ax >= MASK.x0 && ax < MASK.x1 && ay >= MASK.y0 && ay < MASK.y1;
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
png.save(path.join(srcDir, 'r2_verge_src_184x328.png'), src);
png.save(path.join(srcDir, 'r2_verge_mask_184x328.png'), mask);
console.log(`r2 prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
