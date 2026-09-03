// wax-tone.js — EPO03 REWARDS: re-hue one accepted mark onto a named tone,
// deterministically, so a family of seals and ribbons varies by MATERIAL
// without a second generation.
//
// The producer's running note on the Craft recipe book is the reason this
// exists: six sealed pages carrying six identical saturated red seals read as
// a grid of stamps rather than as six sealed pages. The cheapest fix named in
// that note is a deterministic wax-tone remap, and the technique is already
// proven this round (`tone-bronze.js`, commit 49c91f9 "bronze is not gold").
//
// What it does, and what it refuses to do (RULES.md A-2):
//
//   * every opaque pixel keeps its position and its ALPHA exactly;
//   * every opaque pixel keeps its RANK in the source's own luminance order —
//     the shading, the rim light and the impression survive;
//   * only the hue and chroma move, onto a two-stop ramp derived from the
//     target hex (0.32x for the shadow stop, 1.0x for the light stop).
//
// So it invents no pixel, moves no pixel and draws nothing. The output is a
// function of (source, target hex) alone: run it twice and get the same bytes.
//
//   node wax-tone.js <in.png> <out.png> <#rrggbb> [--lift 0.32]
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const args = process.argv.slice(2);
const [inFile, outFile, targetHex] = args;
if (!inFile || !outFile || !targetHex) {
  console.error('usage: wax-tone.js <in.png> <out.png> <#rrggbb> [--lift f]');
  process.exit(2);
}
const liftIdx = args.indexOf('--lift');
const LIFT = liftIdx >= 0 ? Number(args[liftIdx + 1]) : 0.32;

const [tr, tg, tb] = C.parse(targetHex);
const f = png.load(inFile);
const d = f.data;

// The source's own opaque luminance range. Measured, never assumed: a seal
// whose darkest ink is already dark must not be dragged to black.
let lo = Infinity;
let hi = -Infinity;
for (let i = 0; i < d.length; i += 4) {
  if (d[i + 3] === 0) continue;
  const l = C.relLum(d[i], d[i + 1], d[i + 2]);
  if (l < lo) lo = l;
  if (l > hi) hi = l;
}
if (!(hi > lo)) {
  console.error(`${inFile}: no opaque luminance range to remap`);
  process.exit(1);
}

const stop = (t) => [
  Math.round(tr * (LIFT + (1 - LIFT) * t)),
  Math.round(tg * (LIFT + (1 - LIFT) * t)),
  Math.round(tb * (LIFT + (1 - LIFT) * t)),
];

let moved = 0;
let maxL = 0;
for (let i = 0; i < d.length; i += 4) {
  if (d[i + 3] === 0) continue;
  const t = (C.relLum(d[i], d[i + 1], d[i + 2]) - lo) / (hi - lo);
  const [r, g, b] = stop(t);
  if (r !== d[i] || g !== d[i + 1] || b !== d[i + 2]) moved++;
  d[i] = r;
  d[i + 1] = g;
  d[i + 2] = b;
  const l = C.lstar(r, g, b);
  if (l > maxL) maxL = l;
}
png.save(outFile, f);
console.log(
  `${outFile}: ${moved} px re-hued to ${targetHex.toUpperCase()} ` +
    `(lift ${LIFT}), max L* ${maxL.toFixed(4)}`,
);
