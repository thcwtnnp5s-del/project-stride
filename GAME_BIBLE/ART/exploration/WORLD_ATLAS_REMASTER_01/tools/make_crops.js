// WORLD ATLAS REMASTER 01 — review crop renderer.
// Nearest-neighbour crops of any atlas PNG for before/after review.
// Usage: node make_crops.js <atlas.png> <outdir> <name:x,y,w,h,scale> ...
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const [src, outdir, ...specs] = process.argv.slice(2);
if (!src || !outdir || !specs.length) {
  console.error('usage: node make_crops.js <atlas.png> <outdir> <name:x,y,w,h,scale> ...');
  process.exit(1);
}
fs.mkdirSync(outdir, { recursive: true });
const atlas = png.load(src);
for (const spec of specs) {
  const [name, rest] = spec.split(':');
  const [x, y, w, h, s] = rest.split(',').map(Number);
  const out = new png.Raster(w * s, h * s);
  for (let oy = 0; oy < h * s; oy++) {
    for (let ox = 0; ox < w * s; ox++) {
      const sx = Math.min(atlas.width - 1, x + Math.floor(ox / s));
      const sy = Math.min(atlas.height - 1, y + Math.floor(oy / s));
      const si = atlas.idx(sx, sy), oi = out.idx(ox, oy);
      for (let k = 0; k < 4; k++) out.data[oi + k] = atlas.data[si + k];
    }
  }
  const file = path.join(outdir, `${name}_x${s}.png`);
  png.save(file, out);
  console.log(`wrote ${file} (${w * s}x${h * s})`);
}
