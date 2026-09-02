// onatlas.js — composite candidate sprites onto atlas_base at atlas-native coords, crop, scale.
//   node onatlas.js <out.png> <cropX> <cropY> <cropW> <cropH> <scale> <sprite.png@x,y> ...
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const ATLAS = path.resolve(__dirname, '../../../../../assets/art/v1/world/atlas_base.png');
const [out, cxS, cyS, cwS, chS, scS, ...specs] = process.argv.slice(2);
const base = png.load(ATLAS);
for (const s of specs) {
  const m = s.match(/^(.*)@(-?\d+),(-?\d+)$/);
  if (!m) throw new Error('bad spec ' + s);
  png.blit(base, png.load(m[1]), Number(m[2]), Number(m[3]));
}
const c = png.crop(base, Number(cxS), Number(cyS), Number(cwS), Number(chS));
png.save(out, png.scale(c, Number(scS)));
console.log(`${out} ${Number(cwS)*Number(scS)}x${Number(chS)*Number(scS)} atlas=${base.width}x${base.height}`);
