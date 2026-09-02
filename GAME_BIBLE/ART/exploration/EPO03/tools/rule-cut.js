// rule-cut.js — turn a generated "line ruled across paper" into a rule TILE.
//
// The model cannot draw a rule on nothing: asked for a line, it draws a line on
// a sheet of paper, and the paper is 96% of the canvas and far over the
// `#7C7263` ceiling. But the paper is not the asset — the LINE is. A rule is
// drawn over whatever page material the screen already has, so the paper has to
// go, and what is left is exactly what was asked for.
//
// Three deterministic steps, nothing invented (A-2):
//
//   1. key      Every pixel lighter than --key (WCAG relative luminance) becomes
//               fully transparent. The threshold is chosen from the measured
//               histogram, not by eye, and alpha is only ever 0 or 255 so the
//               palette guard's no-semi-alpha rule holds by construction.
//   2. crop     To the rows that still carry ink, so the tile is the rule and
//               not a tall box with a line in it.
//   3. cut      The best-wrapping --w-wide window, scored the way
//               check-tile-seam.js scores a join. Transparent columns are
//               allowed here (unlike tile-cut.js, whose strips sit under a
//               bar and may not show the page through).
//
//   node rule-cut.js <in.png> --key 0.09 --w 8 --out <file.png>
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const a = process.argv.slice(2);
const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
const keyL = Number(arg('--key', 0.09));
const w = Number(arg('--w', 8));
const out = arg('--out');

const src = png.loadAny(a[0]);
console.log(`${path.basename(a[0])}  ${src.width}x${src.height}  key L>${keyL}`);

// 1. key
let kept = 0; let keyed = 0;
for (let i = 0; i < src.data.length; i += 4) {
  if (src.data[i + 3] === 0) continue;
  const L = C.relLum(src.data[i], src.data[i + 1], src.data[i + 2]);
  if (L > keyL) { src.data[i + 3] = 0; keyed += 1; } else { src.data[i + 3] = 255; kept += 1; }
}
console.log(`  keyed          ${keyed} px to transparent, ${kept} px of ink kept`);
if (!kept) { console.error('  nothing left: the threshold removed the line too'); process.exit(1); }

// 2. crop to the inked BAND, not the inked extent.
//
// Min-to-max is wrong here and the chart rule proved it: two stray specks in
// the corners of the sheet made the "band" the whole 32-row canvas, and a rule
// eight times taller than its own line is not a rule. So measure ink per row
// and keep the contiguous run around the densest row that still carries a
// real share of it. A speck is by definition a row with almost no ink, and
// this is the smallest rule that ignores one without also inventing anything.
const ink = new Array(src.height).fill(0);
for (let y = 0; y < src.height; y += 1) {
  for (let x = 0; x < src.width; x += 1) {
    if (src.data[(((y * src.width) + x) << 2) + 3] === 255) ink[y] += 1;
  }
}
const peak = Math.max(...ink);
const floor = peak * Number(arg('--band', 0.2));
const peakRow = ink.indexOf(peak);
let y0 = peakRow; let y1 = peakRow;
while (y0 > 0 && ink[y0 - 1] >= floor) y0 -= 1;
while (y1 < src.height - 1 && ink[y1 + 1] >= floor) y1 += 1;
console.log(`  ink band       peak row ${peakRow} (${peak} px), keeping rows with >= ${floor.toFixed(1)} px`);
const band = png.crop(src, 0, y0, src.width, (y1 - y0) + 1);
console.log(`  cropped        rows ${y0}-${y1} -> ${band.width}x${band.height}`);

// 3. best-wrapping window
const col = (r, i, j) => {
  let s = 0;
  for (let k = 0; k < r.height; k += 1) {
    const p1 = ((k * r.width) + i) << 2; const p2 = ((k * r.width) + j) << 2;
    for (let c = 0; c < 4; c += 1) s += Math.abs(r.data[p1 + c] - r.data[p2 + c]);
  }
  return s / (r.height * 4);
};
let best = null;
for (let x = 0; x + w <= band.width; x += 1) {
  const t = png.crop(band, x, 0, w, band.height);
  let interior = 0;
  for (let i = 0; i + 1 < w; i += 1) interior += col(t, i, i + 1);
  best = (!best || col(t, w - 1, 0) < best.join) ? { x, t, join: col(t, w - 1, 0), interior: interior / (w - 1) } : best;
}
console.log(`  cut            ${w}x${band.height} at x=${best.x}  join ${best.join.toFixed(3)} / interior ${best.interior.toFixed(3)}`);

let over = 0; let semi = 0; let teal = 0; let maxL = 0; let maxHex = '';
for (let i = 0; i < best.t.data.length; i += 4) {
  const A = best.t.data[i + 3];
  if (A > 0 && A < 255) semi += 1;
  if (A !== 255) continue;
  const [r, g, b] = [best.t.data[i], best.t.data[i + 1], best.t.data[i + 2]];
  if (C.cheb(r, g, b, C.TEAL) <= 10) teal += 1;
  const L = C.relLum(r, g, b);
  if (L > C.CEILING_L) over += 1;
  if (L > maxL) { maxL = L; maxHex = C.hex(r, g, b); }
}
console.log(`  max luminance  ${maxHex} L=${maxL.toFixed(4)}`);
console.log(`  guards         teal ${teal}  semi-alpha ${semi}  over-ceiling ${over}  ${teal + semi + over === 0 ? 'clean' : 'VIOLATION'}`);
if (out) { fs.mkdirSync(path.dirname(out), { recursive: true }); png.save(out, best.t); console.log(`  wrote          ${out}`); }
process.exit(teal + semi + over === 0 ? 0 : 1);
