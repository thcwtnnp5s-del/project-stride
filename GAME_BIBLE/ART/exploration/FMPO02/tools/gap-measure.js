// FMPO02 WORLD_FIX — the four edges of the grey-green slab, measured the same
// way before and after so the numbers are comparable.
//   vertical   x=200, x=230 over y 150..260   (mean L1 to the pixel on the right)
//   horizontal y=160, y=255 over x 150..256   (mean L1 to the pixel below)
// plus each band's median and each line's longest run above threshold 28.
// Usage: node gap-measure.js <label>
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..',
  'Scripts', 'art', 'png.js'));
const a = png.load(path.join(__dirname, '..', '..', '..', '..', '..',
  'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const L1 = (x, y, dx, dy) => {
  const i = a.idx(x, y), j = a.idx(x + dx, y + dy);
  return Math.abs(a.data[i] - a.data[j]) + Math.abs(a.data[i + 1] - a.data[j + 1])
    + Math.abs(a.data[i + 2] - a.data[j + 2]);
};
const col = (x) => { let s = 0; for (let y = 150; y < 260; y++) s += L1(x, y, 1, 0); return s / 110; };
const row = (y) => { let s = 0; for (let x = 150; x < 256; x++) s += L1(x, y, 0, 1); return s / 106; };
const runC = (x) => { let b = 0, c = 0; for (let y = 150; y < 260; y++) { if (L1(x, y, 1, 0) >= 28) { c++; if (c > b) b = c; } else c = 0; } return b; };
const runR = (y) => { let b = 0, c = 0; for (let x = 150; x < 256; x++) { if (L1(x, y, 0, 1) >= 28) { c++; if (c > b) b = c; } else c = 0; } return b; };
const med = (v) => [...v].sort((p, q) => p - q)[v.length >> 1];
const cols = []; for (let x = 170; x < 256; x++) cols.push(col(x));
const rows = []; for (let y = 140; y < 270; y++) rows.push(row(y));
console.log(`--- ${process.argv[2] || 'measure'} ---`);
console.log(`vertical band median   ${med(cols).toFixed(1)}   horizontal band median ${med(rows).toFixed(1)}`);
for (const x of [200, 230, 233]) console.log(`  x=${x}  score ${col(x).toFixed(1)}  run ${runC(x)}`);
for (const y of [160, 255]) console.log(`  y=${y}  score ${row(y).toFixed(1)}  run ${runR(y)}`);
const worstC = cols.map((v, i) => [170 + i, v]).sort((p, q) => q[1] - p[1]).slice(0, 3);
const worstR = rows.map((v, i) => [140 + i, v]).sort((p, q) => q[1] - p[1]).slice(0, 3);
console.log('  worst columns ' + worstC.map(([x, v]) => `${x}:${v.toFixed(1)}`).join(' '));
console.log('  worst rows    ' + worstR.map(([y, v]) => `${y}:${v.toFixed(1)}`).join(' '));
