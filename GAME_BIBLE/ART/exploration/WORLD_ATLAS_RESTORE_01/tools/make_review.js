// Review artifacts for World Atlas Restore 01 — and for every future atlas
// pass (M-14: review every boundary at survey, high-zoom and phone-FOV scale
// BEFORE the device pass; M-15: show the protected interior on the picture).
//
// Emits into ../review/:
//   survey.png            — whole atlas at 1:1 (the survey read)
//   protected_overlay.png — the atlas with the protected interior rect and its
//                           rim band drawn on it (magenta core, orange band)
//   boundary_{n,e,s,w}_x3.png — 3x crops across each master boundary
//
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));
const OUT = path.join(__dirname, '..', 'review');
const atlas = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));

const cropScale = (x0, y0, w, h, s) => {
  const o = new png.Raster(w * s, h * s);
  for (let y = 0; y < h * s; y++) for (let x = 0; x < w * s; x++) {
    const si = atlas.idx(
      Math.min(atlas.width - 1, x0 + Math.floor(x / s)),
      Math.min(atlas.height - 1, y0 + Math.floor(y / s)));
    const di = o.idx(x, y);
    for (let k = 0; k < 4; k++) o.data[di + k] = atlas.data[si + k];
  }
  return o;
};

png.save(path.join(OUT, 'survey.png'), cropScale(0, 0, 1024, 1024, 1));
png.save(path.join(OUT, 'boundary_n_x3.png'), cropScale(240, 180, 544, 180, 3));
png.save(path.join(OUT, 'boundary_e_x3.png'), cropScale(640, 240, 300, 300, 3));
png.save(path.join(OUT, 'boundary_w_x3.png'), cropScale(180, 260, 200, 500, 3));
png.save(path.join(OUT, 'boundary_s_x3.png'), cropScale(240, 640, 544, 260, 3));

// Protected-zone overlay: core rect and rim band, on the picture.
const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 };
const ov = cropScale(0, 0, 1024, 1024, 1);
const mark = (x, y, rgb) => {
  const i = ov.idx(x, y);
  for (let k = 0; k < 3; k++) ov.data[i + k] = rgb[k];
};
for (let t = 0; t < 1024; t++) {
  for (const [x, y] of [
    [PROT.x0, t], [PROT.x1 - 1, t], [t, PROT.y0], [t, PROT.y1 - 1],
    [PROT.x0 + PROT.band, t], [PROT.x1 - 1 - PROT.band, t],
    [t, PROT.y0 + PROT.band], [t, PROT.y1 - 1 - PROT.band],
  ]) {
    if (x >= PROT.x0 && x < PROT.x1 && y >= PROT.y0 && y < PROT.y1) {
      const onCore = x === PROT.x0 + PROT.band || x === PROT.x1 - 1 - PROT.band ||
        y === PROT.y0 + PROT.band || y === PROT.y1 - 1 - PROT.band;
      mark(x, y, onCore ? [255, 0, 255] : [255, 160, 0]);
    }
  }
}
png.save(path.join(OUT, 'protected_overlay.png'), ov);
console.log('review artifacts written to', OUT);
