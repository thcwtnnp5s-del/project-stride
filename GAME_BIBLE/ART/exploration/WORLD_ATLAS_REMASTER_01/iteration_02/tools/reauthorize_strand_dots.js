// WORLD ATLAS REMASTER 01 — Iteration 02, register D-04.
// Deliberate re-authorization of the south_strand_w golden: the red-dash
// trail despeckle in package-art.js removes 12 rust-red debris pixels that
// fall inside the golden's rows 810–815. This script applies the IDENTICAL
// local transformation (same predicate, same fixed offsets) to the golden
// file itself, so the landmark-registry guard holds byte-wise against the
// re-authorized state. The golden's git diff is the authorization trail
// (the R3b `reauthorize_strand_w.js` pattern).
'use strict';
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const file = path.join(__dirname, '..', '..', 'goldens', 'south_strand_w.png');
const g = png.load(file);
// Golden origin per landmark_registry.json: (128, 810). Trail x range 275–404.
const OX = 128, OY = 810;
let n = 0;
for (let y = 758; y <= 816; y++) {
  for (let x = 275; x <= 404; x++) {
    const gx = x - OX, gy = y - OY;
    if (gx < 0 || gy < 0 || gx >= g.width || gy >= g.height) continue;
    const i = g.idx(gx, gy);
    const isRed = (j) => g.data[j] > 150 &&
      g.data[j] > g.data[j + 1] + 60 && g.data[j] > g.data[j + 2] + 60;
    if (!isRed(i)) continue;
    let si = g.idx(gx, gy + 3);
    if (isRed(si)) si = g.idx(gx, gy + 5);
    for (let k = 0; k < 4; k++) g.data[i + k] = g.data[si + k];
    n++;
  }
}
png.save(file, g);
console.log(`re-authorized south_strand_w: ${n} debris px replaced`);
