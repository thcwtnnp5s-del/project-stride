const path=require('path');
const png=require(path.resolve(__dirname,'../../../../../Scripts/art/png.js'));
for(const f of process.argv.slice(2)){
  const r=png.loadAny(f);
  let x0=r.width,y0=r.height,x1=-1,y1=-1;
  for(let y=0;y<r.height;y++)for(let x=0;x<r.width;x++){
    if(r.data[((y*r.width)+x)*4+3]!==0){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y;}}
  console.log(path.basename(f),`bbox x${x0}..${x1} y${y0}..${y1}  (${x1-x0+1}x${y1-y0+1})  margin L${x0} T${y0} R${r.width-1-x1} B${r.height-1-y1}`);
  // scale 4x for viewing
  const out=png.scale(r,4);
  png.save(path.join('review',path.basename(f).replace(/\.png$/,'_x4.png')),out);
}
