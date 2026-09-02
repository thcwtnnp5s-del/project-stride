// iou.js — EPO03 items triage (deterministic, invents nothing). Unaligned 48²
// alpha IoU exactly as test/item_icon_distinctness_test.dart computes it
// (alpha >= 8), plus fill % and a binary-alpha / canvas check. A number here
// is triage; the ×2 sheet read is the verdict (M-04, M-14).
//   node iou.js <a.png> <b.png> [...more.png]   pairwise table over all files
//   node iou.js --fill <files...>               fill %, canvas, partial-alpha count
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const args = process.argv.slice(2);
const fillMode = args[0] === '--fill';
const files = fillMode ? args.slice(1) : args;
function mask(r) {
  const m = new Uint8Array(r.width * r.height);
  let n = 0, partial = 0;
  for (let i = 0; i < r.width * r.height; i++) {
    const a = r.data[(i << 2) + 3];
    if (a >= 8) { m[i] = 1; n++; }
    if (a > 0 && a < 255) partial++;
  }
  return { m, n, partial };
}
const loaded = files.map((f) => ({ f, name: path.basename(f, '.png'), r: png.loadAny(f) }));
for (const x of loaded) Object.assign(x, mask(x.r));
if (fillMode) {
  for (const x of loaded) {
    const pct = (100 * x.n / (x.r.width * x.r.height)).toFixed(1);
    console.log(`${x.name.padEnd(28)} ${x.r.width}x${x.r.height}  fill ${pct}%  partial-alpha ${x.partial}`);
  }
} else {
  for (let i = 0; i < loaded.length; i++) for (let j = i + 1; j < loaded.length; j++) {
    const a = loaded[i], b = loaded[j];
    if (a.m.length !== b.m.length) { console.log(`${a.name} vs ${b.name}: size mismatch`); continue; }
    let both = 0, either = 0;
    for (let k = 0; k < a.m.length; k++) { if (a.m[k] || b.m[k]) either++; if (a.m[k] && b.m[k]) both++; }
    console.log(`${a.name.padEnd(24)} ${b.name.padEnd(24)} IoU ${(either ? both / either : 0).toFixed(3)}`);
  }
}
