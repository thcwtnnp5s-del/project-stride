// WORLD ATLAS REMASTER 01 — R4 (SE surf cut, D6) prep.
//
// Problem: the shoreline terminates against a razor-straight vertical at
// x=512 (y ~908-960) — the beach arc from the lower left and its surf chop
// flat against open sea, with a checker-dither patch at (483-517, 883-907).
//
// Intent: one continuous shoreline — the beach+surf arc sweeps northeast to
// join the strand's beach edge, green coastal plain inside the curve, open
// sea outside.
//
// Protected: both south-strand goldens end at y=870 — mask starts at 874.
//
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const CROP = { x: 420, y: 820, w: 192, h: 204 };
const MASK = { x0: 468, x1: 564, y0: 874, y1: 1024 };

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
png.save(path.join(srcDir, 'r4_coast_src_192x204.png'), src);
png.save(path.join(srcDir, 'r4_coast_mask_192x204.png'), mask);
console.log(`r4 prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
