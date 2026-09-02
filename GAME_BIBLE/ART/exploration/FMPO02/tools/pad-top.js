// pad-top.js — extend a backdrop upward by N rows for outpainting (A-2: the
// added band is the top row repeated, a placeholder the inpaint mask replaces;
// nothing is drawn).
//   node pad-top.js <in.png> <rows> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, rowsS, outFile] = process.argv.slice(2);
const rows = Number(rowsS);
const src = png.load(inFile);
const out = new png.Raster(src.width, src.height + rows);
for (let y = 0; y < rows; y++) {
  for (let x = 0; x < src.width; x++) {
    const si = x * 4;
    const di = (y * out.width + x) * 4;
    out.data[di] = src.data[si];
    out.data[di + 1] = src.data[si + 1];
    out.data[di + 2] = src.data[si + 2];
    out.data[di + 3] = src.data[si + 3];
  }
}
png.blit(out, src, 0, rows);
png.save(outFile, out);
console.log(`${outFile} ${out.width}x${out.height} (top ${rows} rows = row 0 repeated)`);
