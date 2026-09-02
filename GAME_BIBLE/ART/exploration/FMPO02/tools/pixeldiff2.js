'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [a, b] = process.argv.slice(2);
const ra = png.load(a), rb = png.load(b);
if (ra.width !== rb.width || ra.height !== rb.height) { console.log('size differs'); process.exit(0); }
let maxDelta = 0, sum = 0, n = ra.data.length/4;
for (let i = 0; i < ra.data.length; i += 4) {
  let d = 0;
  for (let k = 0; k < 4; k++) d = Math.max(d, Math.abs(ra.data[i+k]-rb.data[i+k]));
  maxDelta = Math.max(maxDelta, d);
  sum += d;
}
console.log(a, 'vs', b, 'maxChannelDelta=', maxDelta, 'meanDelta=', (sum/n).toFixed(2));
