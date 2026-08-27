// Extract the east-join source crop from the current (restored) composite for
// the one surgical inpaint of World Atlas Restore 01. Run after
// `node Scripts/art/package-art.js` so the crop reflects the protected-interior
// restore.
'use strict';
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));
const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const crop = (x0, y0, w, h) => {
  const out = new png.Raster(w, h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const si = atlas.idx(x0 + x, y0 + y), di = out.idx(x, y);
    for (let k = 0; k < 4; k++) out.data[di + k] = atlas.data[si + k];
  }
  return out;
};
// East join: (656, 224) 256x288 — volcano slope west, open sea east, icy
// shelf north, coast/sea south. The seam band to repaint sits at x 752..818.
png.save(path.join(__dirname, '..', 'src', 'east_join_src_256x288.png'), crop(656, 224, 256, 288));
console.log('wrote src/east_join_src_256x288.png');
