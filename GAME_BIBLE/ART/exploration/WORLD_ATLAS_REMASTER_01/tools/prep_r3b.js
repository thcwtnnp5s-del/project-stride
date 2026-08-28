// WORLD ATLAS REMASTER 01 — R3b (SW boundary checker-band correction) prep.
//
// R3's review found the pre-existing checker-dither column (atlas x~122-132,
// y ~848-1024 — the old D5 sketch/paint blend) survives just east of R3's
// mask edge, reading as a faint vertical speckle line through plain, forest
// and surf. This correction re-authors the band. Its 128-138 x 848-870 sliver
// lies inside the south_strand_w golden — a deliberate re-author of a
// defective sliver at the strand's west edge, authorized by re-extracting
// the golden in the same commit (see README R3b).
//
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const CROP = { x: 72, y: 800, w: 112, h: 224 };
const MASK = { x0: 116, x1: 138, y0: 848, y1: 1024 };

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
png.save(path.join(srcDir, 'r3b_band_src_112x224.png'), src);
png.save(path.join(srcDir, 'r3b_band_mask_112x224.png'), mask);
console.log(`r3b prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
