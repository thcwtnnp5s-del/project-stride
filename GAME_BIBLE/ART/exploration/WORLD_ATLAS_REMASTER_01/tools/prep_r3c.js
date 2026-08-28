// WORLD ATLAS REMASTER 01 — R3c (SW top-edge correction, ATLAS-H F1) prep.
//
// The independent ATLAS-H review found R3's own mask top shipped as a
// ruler-straight tone step at y=848 (x 0–137): the olive plain changes
// shade on the line, a boulder base is clipped at (0–30, 838–858), and
// bush-top/conifer hybrid trees stand at (54–90, 836–870). A repair's own
// perimeter is never shipped (owner directive, M-14) — this band
// re-authors the join.
//
// Mask: x 0–126 (canvas left edge; strand golden starts x=128), y 828–888
// — top edge in the old plain, bottom edge in R3's new plain.
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const CROP = { x: 0, y: 780, w: 176, h: 156 };
const MASK = { x0: 0, x1: 126, y0: 828, y1: 888 };

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
png.save(path.join(srcDir, 'r3c_topedge_src_176x156.png'), src);
png.save(path.join(srcDir, 'r3c_topedge_mask_176x156.png'), mask);
console.log(`r3c prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
