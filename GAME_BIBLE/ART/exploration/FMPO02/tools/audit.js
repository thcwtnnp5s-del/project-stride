// audit.js — ART-01 §3 raster guard. node audit.js <file...>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const TEAL = [0x58, 0xD6, 0xC0];
const GROUND = 0x14 + 0x12 + 0x0F; // sum of surfaceGround
for (const f of process.argv.slice(2)) {
  const r = png.load(f);
  let partial = 0, teal = 0, below = 0, n = 0, minSum = 999, colors = new Set();
  for (let i = 0; i < r.data.length; i += 4) {
    const a = r.data[i + 3];
    if (a === 0) continue;
    if (a < 255) { partial++; continue; }
    n++;
    const [R, G, B] = [r.data[i], r.data[i + 1], r.data[i + 2]];
    colors.add((R << 16) | (G << 8) | B);
    if (Math.abs(R - TEAL[0]) <= 10 && Math.abs(G - TEAL[1]) <= 10 && Math.abs(B - TEAL[2]) <= 10) teal++;
    const s = R + G + B;
    if (s < minSum) minSum = s;
    if (s <= GROUND) below++;
  }
  console.log(`${path.basename(f)}  ${r.width}x${r.height}  opaque=${n} colors=${colors.size} partialAlpha=${partial} reservedTeal=${teal} atOrBelowGround=${below} minRGBsum=${minSum}`);
}
