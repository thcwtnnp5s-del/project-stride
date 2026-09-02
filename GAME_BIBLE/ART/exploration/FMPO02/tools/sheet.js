// sheet.js — contact sheet for review (A-2: scale + blit only, invents nothing).
//   node sheet.js <out.png> <scale> <cols> <bg:hex|transparent> <frame1.png> [frame2.png ...]
// Frames are integer-scaled and laid on a grid; unequal frames are padded to the
// largest cell, bottom-aligned (so feet rows line up for animation review).
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [out, scaleS, colsS, bg, ...files] = process.argv.slice(2);
const scale = Number(scaleS);
const cols = Number(colsS);
const frames = files.map((f) => ({ f, r: png.loadAny(f) }));
const cw = Math.max(...frames.map((x) => x.r.width));
const ch = Math.max(...frames.map((x) => x.r.height));
const rows = Math.ceil(frames.length / cols);
const gap = 2;
const W = (cols * (cw + gap) + gap) * scale;
const H = (rows * (ch + gap) + gap) * scale;
const sheet = new png.Raster(W, H);
if (bg !== 'transparent') {
  const hex = bg.replace('#', '');
  const r = parseInt(hex.slice(0, 2), 16), g = parseInt(hex.slice(2, 4), 16), b = parseInt(hex.slice(4, 6), 16);
  png.fill(sheet, [r, g, b, 255]);
}
frames.forEach(({ r }, i) => {
  const col = i % cols, row = Math.floor(i / cols);
  const x = (gap + col * (cw + gap)) * scale;
  const y = (gap + row * (ch + gap) + (ch - r.height)) * scale; // bottom-align
  png.blit(sheet, png.scale(r, scale), x, y);
});
png.save(out, sheet);
console.log(`${out} ${W}x${H} (${frames.length} frames, cell ${cw}x${ch} x${scale})`);
