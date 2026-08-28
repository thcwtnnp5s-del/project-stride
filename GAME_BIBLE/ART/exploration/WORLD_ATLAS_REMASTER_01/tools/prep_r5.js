// WORLD ATLAS REMASTER 01 — R5 (NW crackle-ice paste rectangle, D3) prep.
//
// Problem: the fine-crackle ice block (the d2b_floe edge-fix's footprint)
// shows a straight vertical left edge at x~239 (y ~205-270) against the
// smooth snowfield, and the small nunatak row (250-360, 130-165) sits on the
// block's shelf with its west end fading oddly.
//
// Intent: the snowfield grades into crackled pack ice with no straight
// boundary anywhere; the nunatak row becomes complete gray peaks poking
// naturally through the icefield with soft snow at their bases.
//
// Protected: Frostmere basin north wall golden (400-560 x 256-276) — mask
// bottom is 252; the teal melt-pond (350-410 x 128-155) — the mask's top
// steps down to 158 east of x=340 so the pond stays untouched; the NW
// glacier vignette west of x~210.
//
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

// Roll 1 (seed 606, wide mask incl. the nunatak row) was REJECTED: the
// generation deleted most of the mountain row instead of completing it,
// invented a new melt-lake joining the pond, and left red pixel flecks
// (rejected/r5_nwice_roll1_f0.png). Roll 2 narrows to the actual P0 — the
// straight edge below the row — and freezes the mountains and pond.
const CROP = { x: 166, y: 124, w: 230, h: 176 };
const white = (ax, ay) =>
  ax >= 214 && ax < 348 && ay >= 172 && ay < 252;

const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const src = new png.Raster(CROP.w, CROP.h);
for (let y = 0; y < CROP.h; y++) {
  for (let x = 0; x < CROP.w; x++) {
    const si = atlas.idx(CROP.x + x, CROP.y + y), di = src.idx(x, y);
    for (let k = 0; k < 4; k++) src.data[di + k] = atlas.data[si + k];
  }
}
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
png.save(path.join(srcDir, 'r5_nwice_src_230x176.png'), src);
png.save(path.join(srcDir, 'r5_nwice_mask_230x176.png'), mask);
console.log(`r5 prep: src+mask written, mask covers ${count} px ` +
  `(${(100 * count / (CROP.w * CROP.h)).toFixed(1)}% of crop)`);
