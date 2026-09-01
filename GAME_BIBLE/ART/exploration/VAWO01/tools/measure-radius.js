const path=require('path');
const png=require(path.resolve(__dirname,'../../../../../Scripts/art/png.js'));
const f=process.argv[2];
const r=png.loadAny(f);
const A=(x,y)=>(x<0||y<0||x>=r.width||y>=r.height)?0:r.data[(((y*r.width)+x)<<2)+3];
// For each row near the top-left, find first opaque x. The corner arc profile.
console.log(f, r.width+'x'+r.height);
console.log('row : first opaque x');
const prof=[];
for(let y=0;y<20;y++){let fx=-1;for(let x=0;x<r.width;x++){if(A(x,y)){fx=x;break;}}prof.push(fx);console.log('  '+String(y).padStart(2)+' : '+fx);}
// radius = the y at which first-opaque-x reaches 0 (the straight run begins)
let rad=0; for(let y=0;y<prof.length;y++){ if(prof[y]===0){rad=y;break;} }
console.log('corner arc height (radius) =', rad);
// also the top run: first opaque y at mid
let fy=-1; const mid=r.width>>1; for(let y=0;y<r.height;y++){if(A(mid,y)){fy=y;break;}}
console.log('top run starts at y =', fy);
