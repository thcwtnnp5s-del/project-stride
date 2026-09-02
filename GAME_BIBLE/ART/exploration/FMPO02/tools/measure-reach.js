// measure-reach.js — per-frame rightmost opaque column of an east-facing strip
// (the blade/fist reach), so a strike frame is measured, not guessed.
//   node measure-reach.js <prefix> <frames>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [prefix, n] = process.argv.slice(2);
const reach = [];
for (let i = 0; i < Number(n); i++) {
  const r = png.load(`${prefix}_f${i}.png`);
  reach.push(png.bounds(r, 1).right);
}
const max = Math.max(...reach);
console.log(`${path.basename(prefix)}: reach ${reach.join(' ')} -> max ${max} at f${reach.indexOf(max)}`);
