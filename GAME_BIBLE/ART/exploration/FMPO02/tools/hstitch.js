// hstitch.js — horizontal concatenation of pieces into a fixed canvas (A-2:
// blit only, invents nothing). Used to assemble a nine-patch bar (cap + tiled
// band + mirrored cap) from generated tiles that all share the same height.
//   node hstitch.js <out.png> <outW> <outH> <piece.png>:<repeat> [piece.png>:<repeat> ...]
// Pieces are blitted left-to-right in order, each repeated <repeat> times,
// until outW columns are filled or pieces run out (result is left as-is,
// short or exactly full — no stretching, no invention).
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [outFile, outWs, outHs, ...specs] = process.argv.slice(2);
const outW = Number(outWs);
const outH = Number(outHs);
const out = new png.Raster(outW, outH);
let x = 0;
for (const spec of specs) {
  const [file, repS] = spec.split(':');
  const rep = Number(repS || '1');
  const piece = png.load(file);
  if (piece.height !== outH) throw new Error(`${file}: height ${piece.height} != ${outH}`);
  for (let i = 0; i < rep && x < outW; i++) {
    const w = Math.min(piece.width, outW - x);
    for (let y = 0; y < outH; y++) {
      const si = piece.idx(0, y);
      const di = out.idx(x, y);
      piece.data.copy(out.data, di, si, si + w * 4);
    }
    x += piece.width;
  }
}
png.save(outFile, out);
console.log(`${outFile} ${outW}x${outH} (filled to x=${x})`);
