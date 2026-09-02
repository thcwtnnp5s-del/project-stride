// pack.js — copy accepted raw frames to out/worldlife/<name>_f<i>.png verbatim (byte copy, no pixel change).
//   node pack.js <name> <srcPrefix> <i0> <i1>
'use strict';
const fs = require('fs'); const path = require('path');
const [name, prefix, a, b] = process.argv.slice(2);
const outDir = path.resolve(__dirname, '../out/worldlife');
fs.mkdirSync(outDir, { recursive: true });
let n = 0;
for (let i = Number(a), j = 0; i <= Number(b); i++, j++) {
  const src = `${prefix}${i}.png`;
  if (!fs.existsSync(src)) throw new Error('missing ' + src);
  fs.copyFileSync(src, path.join(outDir, `${name}_f${j}.png`));
  n++;
}
console.log(`${name}: ${n} frames`);
