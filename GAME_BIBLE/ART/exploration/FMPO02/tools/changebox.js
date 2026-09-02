// changebox.js — bbox of pixels that differ between frame 0 and any later frame.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const rs = process.argv.slice(2).map(f => png.load(f));
const a = rs[0];
let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
for (let k = 1; k < rs.length; k++) {
  const b = rs[k];
  for (let y = 0; y < a.height; y++) for (let x = 0; x < a.width; x++) {
    const i = (y * a.width + x) * 4;
    if (a.data[i] !== b.data[i] || a.data[i+1] !== b.data[i+1] || a.data[i+2] !== b.data[i+2] || a.data[i+3] !== b.data[i+3]) {
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
}
console.log(`change bbox: x ${x0}..${x1}  y ${y0}..${y1}   (w ${x1-x0+1} h ${y1-y0+1})`);
