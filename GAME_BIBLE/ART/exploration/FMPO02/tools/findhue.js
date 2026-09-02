'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [f] = process.argv.slice(2);
const r = png.load(f);
let minX=999,maxX=-1,minY=999,maxY=-1,count=0;
for (let y=0;y<r.height;y++) for (let x=0;x<r.width;x++){
  const i=(y*r.width+x)*4;
  const R=r.data[i],G=r.data[i+1],B=r.data[i+2],A=r.data[i+3];
  if (A<8) continue;
  // reddish-orange: R significantly higher than G and B, and R fairly high
  if (R>120 && R-G>40 && R-B>50) { count++; if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; }
}
console.log(f, 'reddish px:', count, count? `bbox ${minX},${minY}..${maxX},${maxY}`:'');
