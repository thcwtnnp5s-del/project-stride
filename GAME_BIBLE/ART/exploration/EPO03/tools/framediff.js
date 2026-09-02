// framediff.js — how much does each frame differ from frame 0 and from the previous? 
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const files = process.argv.slice(2);
const rs = files.map(f => ({ f: path.basename(f), r: png.load(f) }));
function diff(a, b) { let n = 0; for (let i = 0; i < a.data.length; i += 4) { if (a.data[i] !== b.data[i] || a.data[i+1] !== b.data[i+1] || a.data[i+2] !== b.data[i+2] || a.data[i+3] !== b.data[i+3]) n++; } return n; }
function opaque(a){let n=0;for(let i=3;i<a.data.length;i+=4) if(a.data[i]>0)n++;return n;}
rs.forEach((x, i) => {
  const d0 = i === 0 ? 0 : diff(rs[0].r, x.r);
  const dp = i === 0 ? 0 : diff(rs[i-1].r, x.r);
  console.log(`${x.f}\topaque=${opaque(x.r)}\tvs_f0=${d0}\tvs_prev=${dp}`);
});
