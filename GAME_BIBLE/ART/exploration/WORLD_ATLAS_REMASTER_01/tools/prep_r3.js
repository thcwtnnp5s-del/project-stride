// WORLD ATLAS REMASTER 01 — R3 (SW Sketchlands) prep.
//
// Run after `node Scripts/art/package-art.js`.
//
// Problem (D5): the bottom-left corner (~0-120 x 690-1024) is uncolored
// line-art — black contour hills and pen-stroke pines on flat green — meeting
// finished paint along a checker-dithered vertical at x~118, with gray ruin
// scraps at (0-25, 780-830). It reads as an unpainted layer of the file, not
// a biome.
//
// Crop: (0, 640) 200x384 — left and bottom edges are canvas edges (mask may
// touch them). Mask: x 0-126, y 688-1024 —
//   - x1=126 keeps a 2 px cushion to the WAR01 south strand golden (x>=128,
//     y 810-870) and lands in finished painted terrain east of the x~118
//     dither line
//   - y0=688 lands in the terrain south of the ring-2 valley road band
//     (protected to y=580) with 48 px of frozen crop above
//   - the Zone-1 coastline hand-off (130-260, 960-1024) stays outside
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

// Source review moved the mask to the true defect: the painted plain and
// rock ledges of 690-845 are finished art; the line-art sketch (outline
// hills, pen pines, halftone dither) begins ~y 848. Mask top lands in the
// plain just above it.
const CROP = { x: 0, y: 720, w: 200, h: 304 };
const MASK = { x0: 0, x1: 126, y0: 848, y1: 1024 };

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
png.save(path.join(srcDir, 'r3_sketch_src_200x304.png'), src);
png.save(path.join(srcDir, 'r3_sketch_mask_200x304.png'), mask);
console.log(`r3 prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
