// WORLD ATLAS REMASTER 01 — extract landmark-registry golden crops from the
// CURRENT shipped composite (run after `node Scripts/art/package-art.js`).
// Re-running this deliberately re-authorizes the landmarks at the composite's
// current state; the goldens' git diff is the authorization trail.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const reg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'landmark_registry.json'), 'utf8'));
const outDir = path.join(__dirname, '..', 'goldens');
fs.mkdirSync(outDir, { recursive: true });
for (const lm of reg.landmarks) {
  const crop = new png.Raster(lm.w, lm.h);
  for (let y = 0; y < lm.h; y++) {
    for (let x = 0; x < lm.w; x++) {
      const si = atlas.idx(lm.x + x, lm.y + y), di = crop.idx(x, y);
      for (let k = 0; k < 4; k++) crop.data[di + k] = atlas.data[si + k];
    }
  }
  png.save(path.join(outDir, `${lm.id}.png`), crop);
}
console.log(`extracted ${reg.landmarks.length} landmark goldens`);
