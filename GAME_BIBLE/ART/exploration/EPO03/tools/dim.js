// dim.js — a deterministic tone remap: scale every colour in LINEAR light by a
// constant factor, keeping hue and chroma ratios exactly (A-2, precedent
// 49c91f9 "bronze is not gold"). It invents no pixel and moves no pixel.
//
//   node dim.js <in.png> --out <file.png> --factor 0.4
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const a = process.argv.slice(2);
const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
const src = png.load(a[0]);
const k = Number(arg('--factor', '0.5'));
const toLin = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
const toSrgb = (l) => Math.round(255 * (l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055));
for (let i = 0; i < src.data.length; i += 4) {
  if (src.data[i + 3] === 0) continue;
  for (let c = 0; c < 3; c++) src.data[i + c] = toSrgb(Math.max(0, Math.min(1, toLin(src.data[i + c]) * k)));
}
png.save(arg('--out'), src);
console.log('wrote', arg('--out'), 'factor', k);
