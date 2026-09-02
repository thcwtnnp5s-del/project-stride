// flipx.js — horizontal mirror of a PNG (A-2: reflects existing pixels only,
// invents nothing). Used to make a matching right-side cap from a generated
// left-side cap for a nine-patch bar.
//   node flipx.js <in.png> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, outFile] = process.argv.slice(2);
const src = png.load(inFile);
const out = new png.Raster(src.width, src.height);
for (let y = 0; y < src.height; y++) {
  for (let x = 0; x < src.width; x++) {
    const si = src.idx(src.width - 1 - x, y);
    const di = out.idx(x, y);
    src.data.copy(out.data, di, si, si + 4);
  }
}
png.save(outFile, out);
console.log(`${outFile} ${out.width}x${out.height} flipped from ${inFile}`);
