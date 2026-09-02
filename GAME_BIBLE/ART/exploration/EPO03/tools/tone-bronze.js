// tone-bronze.js — EPO03 EQUIPMENT: apply package-art.js's own `toneBronze`
// remap to a frame so a candidate can be reviewed as it will SHIP, not as it
// was generated. Copy of the shipped predicate; no pixel is invented (A-2).
//   node tone-bronze.js <in.png> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, outFile] = process.argv.slice(2);
const f = png.load(inFile);
const d = f.data;
let n = 0;
for (let i = 0; i < d.length; i += 4) {
  if (d[i + 3] === 0) continue;
  const r = d[i], g = d[i + 1], b = d[i + 2];
  if (r >= 225 && g <= 150 && b <= 90 && r - g >= 80) {
    d[i] = 200; d[i + 1] = 133; d[i + 2] = 54; n++;
  }
}
png.save(outFile, f);
console.log(`${outFile}: ${n} px snapped to the copper highlight`);
