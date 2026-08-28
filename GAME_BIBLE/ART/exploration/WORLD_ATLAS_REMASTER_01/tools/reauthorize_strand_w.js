// WORLD ATLAS REMASTER 01 — deliberate re-authorization of the
// south_strand_w golden's westmost sliver (x 128-138, y 848-870), which
// contained the pre-existing D5 checker-dither column that R3b re-authors.
// The golden is updated from the accepted R3b generation through R3b's own
// mask, so the authorization is exactly the reviewed correction — nothing
// else in the golden changes. Record: README.md, R3b.
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const GOLDEN = { x: 128, y: 810, w: 400, h: 60 };
const GEN = { x: 72, y: 800 };

const goldenPath = path.join(__dirname, '..', 'goldens', 'south_strand_w.png');
const golden = png.load(goldenPath);
const gen = png.load(path.join(__dirname, '..', 'out', 'r3b_band_f0.png'));
const mask = png.load(path.join(__dirname, '..', 'src', 'r3b_band_mask_112x224.png'));

let changed = 0;
for (let gy = 0; gy < GOLDEN.h; gy++) {
  for (let gx = 0; gx < GOLDEN.w; gx++) {
    const ax = GOLDEN.x + gx, ay = GOLDEN.y + gy;
    const mx = ax - GEN.x, my = ay - GEN.y;
    if (mx < 0 || my < 0 || mx >= mask.width || my >= mask.height) continue;
    if (mask.data[mask.idx(mx, my)] === 0) continue;
    const gi = golden.idx(gx, gy), si = gen.idx(mx, my);
    for (let k = 0; k < 4; k++) golden.data[gi + k] = gen.data[si + k];
    changed++;
  }
}
png.save(goldenPath, golden);
console.log(`reauthorized ${changed} px of south_strand_w golden`);
