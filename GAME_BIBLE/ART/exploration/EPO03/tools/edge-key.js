// edge-key.js — EPO03 GATHER: strip a pure-black keyline from the frame-bleeding
// edges of a 48 subject plate. A deterministic key, not a repaint — the same
// class of recovery as the white-face key in PRODUCTION_RULES §2a, and it
// invents nothing (A-2).
//
// A gather subject is meant to bleed off its own edges so it has no silhouette
// of its own (DIR-10, integration split). But a plate drawn with a pixel-art
// outline puts that outline along the frame edge too, and the result at ×2 on
// a stage is a hard black rule down the side of the picture — the plate
// announcing its own box, which is the exact defect the round exists to remove.
//
// The rule is deliberately narrow so it cannot eat art: an outermost row or
// column is stripped ONLY if every one of its 48 pixels is opaque AND at
// luminance <= [maxL] (default 4, i.e. the keyline black). A partly-dark edge
// is rock, and is left alone. Repeats inward while the new edge also qualifies.
//
//   node edge-key.js <in.png> <out.png> [maxL]
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [inFile, outFile, maxLS] = process.argv.slice(2);
const maxL = maxLS === undefined ? 4 : Number(maxLS);
const r = png.load(inFile);
const at = (x, y) => (y * r.width + x) * 4;
const lum = (i) => 0.299 * r.data[i] + 0.587 * r.data[i + 1] + 0.114 * r.data[i + 2];

function line(kind, n) {
  const px = [];
  const len = kind === 'col' ? r.height : r.width;
  for (let k = 0; k < len; k++) px.push(kind === 'col' ? at(n, k) : at(k, n));
  return px;
}
const isKeyline = (px) => px.every((i) => r.data[i + 3] === 255 && lum(i) <= maxL);
const clear = (px) => px.forEach((i) => { r.data[i + 3] = 0; });

const stripped = [];
for (const [kind, start, step, limit] of [
  ['col', 0, 1, r.width], ['col', r.width - 1, -1, r.width],
  ['row', 0, 1, r.height], ['row', r.height - 1, -1, r.height],
]) {
  for (let k = 0, n = start; k < limit; k++, n += step) {
    const px = line(kind, n);
    if (!isKeyline(px)) break;
    clear(px);
    stripped.push(`${kind} ${n}`);
  }
}
png.save(outFile, r);
console.log(
  stripped.length
    ? `${outFile}: keyed ${stripped.length} edge line(s) to alpha 0 — ${stripped.join(', ')}`
    : `${outFile}: no edge line is a pure keyline (<= L${maxL}); nothing keyed`,
);
