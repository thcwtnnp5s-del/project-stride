// key-flat.js — clear one exact colour to alpha 0.
//
//   node key-flat.js <in.png> <out.png> <RRGGBB> [tolerance]
//
// The deterministic half of PRODUCTION_RULES §2a's "a painted face is a key,
// not a rejection", pointed at a *flat* ground rather than a bright one: a
// generator that draws its subject over an opaque transparency-checkerboard
// bakes that checker into the file, and the file then measures as art. The
// checker is one exact ink alternating with real transparency, so keying that
// ink is a lossless removal — no resample, no repaint, A-2 clean, and zero
// generations.
//
// Prints the count keyed and the count left, so a key that took the subject
// with it is visible before the file is written.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [inPath, outPath, hex, tolS] = process.argv.slice(2);
if (!inPath || !outPath || !hex) {
  console.error('usage: key-flat.js <in.png> <out.png> <RRGGBB> [tolerance]');
  process.exit(2);
}
const tol = tolS === undefined ? 0 : Number(tolS);
const want = [
  parseInt(hex.slice(0, 2), 16),
  parseInt(hex.slice(2, 4), 16),
  parseInt(hex.slice(4, 6), 16),
];

const im = png.load(inPath);
const d = im.data;
let keyed = 0;
let kept = 0;
for (let i = 0; i < d.length; i += 4) {
  if (d[i + 3] < 8) continue;
  if (
    Math.abs(d[i] - want[0]) <= tol &&
    Math.abs(d[i + 1] - want[1]) <= tol &&
    Math.abs(d[i + 2] - want[2]) <= tol
  ) {
    d[i] = 0;
    d[i + 1] = 0;
    d[i + 2] = 0;
    d[i + 3] = 0;
    keyed++;
  } else {
    kept++;
  }
}
png.save(outPath, im);
console.log(`${outPath} ${im.width}x${im.height} keyed ${keyed}, kept ${kept}`);
