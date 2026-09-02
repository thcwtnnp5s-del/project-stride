// strip-proof.js — tile a longitudinal strip the way EdgeStrip does and show the
// join. Deterministic: integer scale, nearest neighbour, blit only (A-2).
//
// EdgeStrip repeats the tile horizontally from the left at integer scale and
// clips the last one. A seam that is invisible in a single tile can beat every
// `period x scale` logical px across the bottom of every screen, so the only
// honest proof is the run itself, at the width and scale the phone shows.
//
//   node strip-proof.js <tile.png> <out.png> --width 393 --scale 2 [--bg "#201C17"] [--rows 3]
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const a = process.argv.slice(2);
const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
const src = png.loadAny(a[0]);
const out = a[1];
const width = Number(arg('--width', 393));
const scale = Number(arg('--scale', 2));
const rows = Number(arg('--rows', 3));      // stacked repeats, to read the vertical join too
const bg = arg('--bg', '#201C17');

const tile = png.scale(src, scale);
const H = tile.height * rows;
const sheet = new png.Raster(width, H);
const hex = bg.replace('#', '');
png.fill(sheet, [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16), 255]);
for (let r = 0; r < rows; r += 1) {
  for (let x = 0; x < width; x += tile.width) png.blit(sheet, tile, x, r * tile.height);
}
png.save(out, sheet);
console.log(`${out} ${width}x${H}  tile ${src.width}x${src.height} x${scale} = ${tile.width}x${tile.height}, `
  + `${Math.ceil(width / tile.width)} repeats/row, last clipped at ${width % tile.width || tile.width}px`);
