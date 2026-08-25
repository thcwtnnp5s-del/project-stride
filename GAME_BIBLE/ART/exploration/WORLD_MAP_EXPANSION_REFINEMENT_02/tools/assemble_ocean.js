// Deterministic ocean assembly (A-2: crop + sheet assembly of approved
// assets — invents no object, silhouette or frame). Stacks crops of already
// approved sea into one piece, with the same dither crossfade the world
// composition uses at every internal horizontal join.
//
// Usage: node assemble_ocean.js <out.png> <W> <H> <src.png@sx,sy,sw,sh@dy> ...
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const [out, W, H, ...specs] = process.argv.slice(2);
const base = new png.Raster(Number(W), Number(H));
const joins = [];
for (const spec of specs) {
  const [file, srcRect, dyStr] = spec.split('@');
  const [sx, sy, sw, sh] = srcRect.split(',').map(Number);
  const dy = Number(dyStr);
  const crop = png.crop(png.load(path.resolve(file)), sx, sy, sw, sh);
  png.blit(base, crop, 0, dy);
  if (dy > 0) joins.push(dy);
}
const before = base.clone();
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};
const BAND = 11;
const chance = (d) => 0.45 * (1 - (d - 1) / BAND);
for (const seamY of joins) {
  for (let x = 0; x < base.width; x++) {
    for (let d = 1; d <= BAND; d++) {
      const pr = chance(d);
      const swap = (ay, by) => {
        if (ay < 0 || by < 0 || ay >= base.height || by >= base.height) return;
        const ai = base.idx(x, ay);
        const bi = before.idx(x, by);
        for (let k = 0; k < 4; k++) base.data[ai + k] = before.data[bi + k];
      };
      if (hash(x, seamY - d, 1) < pr) swap(seamY - d, seamY + d - 1);
      if (hash(x, seamY + d - 1, 2) < pr) swap(seamY + d - 1, seamY - d);
    }
  }
}
png.save(out, base);
console.log('assembled', out);
