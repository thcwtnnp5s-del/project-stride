// fold.js — quarter-mirror fold for a seamless tile (A-2: reflects existing
// pixels only, invents nothing). Takes the top-left N/2 x N/2 quadrant of the
// source and mirrors it into all four quadrants of an N x N output, so every
// edge column/row equals itself under mirroring and the tile repeats with no
// seam at any edge.
//   node fold.js <in.png> <N> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, nS, outFile] = process.argv.slice(2);
const N = Number(nS);
const src = png.load(inFile);
const out = new png.Raster(N, N);
for (let y = 0; y < N; y++) {
  const sy = y < N / 2 ? y : N - 1 - y;
  for (let x = 0; x < N; x++) {
    const sx = x < N / 2 ? x : N - 1 - x;
    const si = src.idx(sx, sy);
    const di = out.idx(x, y);
    src.data.copy(out.data, di, si, si + 4);
  }
}
png.save(outFile, out);
console.log(`${outFile} ${N}x${N} folded from ${inFile}`);
