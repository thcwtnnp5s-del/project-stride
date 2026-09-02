'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const target = [0x58, 0xD6, 0xC0];
for (const f of process.argv.slice(2)) {
  const r = png.load(f);
  let hits = 0, minD = 999, partialAlpha = 0;
  for (let i = 0; i < r.data.length; i += 4) {
    const a = r.data[i+3];
    if (a > 0 && a < 255) partialAlpha++;
    const d = Math.max(Math.abs(r.data[i]-target[0]), Math.abs(r.data[i+1]-target[1]), Math.abs(r.data[i+2]-target[2]));
    if (d < minD) minD = d;
    if (d <= 10 && a > 0) hits++;
  }
  console.log(f, 'tealHits=' + hits, 'minChebyshev=' + minD, 'partialAlphaPx=' + partialAlpha);
}
