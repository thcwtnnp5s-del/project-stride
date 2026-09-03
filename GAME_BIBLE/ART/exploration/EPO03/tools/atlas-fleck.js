// EPO03 — PROD-WORLD-EAST: deterministic removal of ONE-PIXEL islands from a
// region generation (the "orphan fleck" atlas-qa counts, ART-03 §7.6).
//
// Measured on E1 roll 3: the calving front the tool drew is right, but its
// brash is scattered as single isolated pixels, which doubled the fleck count
// over the region (285 -> 555) and reads as speck noise at phone FOV. The
// style lock asks for "sparse 2-4 px white ticks", not one-pixel confetti, so
// this is a style conformance pass, not authoring.
//
// Predicate is morphological, not colour: a pixel is an island when at least
// `--odd` of its 8 neighbours are far from it (the same |dR|+|dG|+|dB| > 150
// measure atlas-qa uses) AND it has no equal-coloured 8-neighbour. It is then
// filled with the MOST COMMON neighbour colour — an existing adjacent pixel,
// nothing invented, nothing averaged (A-2), the same idiom as the despeckle
// passes already shipping in Scripts/art/package-art.js.
//
// Usage: node atlas-fleck.js <in.png> <out.png> [--odd 7] [--passes 2]
//                            [--rect x0,y0,x1,y1]
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));
const argv = process.argv.slice(2);
const [inFile, outFile] = argv;
const flag = (n, d) => { const i = argv.indexOf(`--${n}`); return i < 0 ? d : argv[i + 1]; };
const ODD = Number(flag('odd', 7));
const PASSES = Number(flag('passes', 2));
const rect = flag('rect', null);
const r = png.load(inFile);
const [x0, y0, x1, y1] = rect ? rect.split(',').map(Number) : [0, 0, r.width, r.height];
const far = (i, j) => Math.abs(r.data[i] - r.data[j]) + Math.abs(r.data[i + 1] - r.data[j + 1]) +
  Math.abs(r.data[i + 2] - r.data[j + 2]) > 150;
let removed = 0;
for (let pass = 0; pass < PASSES; pass++) {
  const fills = [];
  for (let y = Math.max(1, y0); y < Math.min(r.height - 1, y1); y++) {
    for (let x = Math.max(1, x0); x < Math.min(r.width - 1, x1); x++) {
      const i = r.idx(x, y);
      let odd = 0, same = 0; const votes = new Map();
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const j = r.idx(x + dx, y + dy);
          if (far(i, j)) odd++;
          if (r.data[j] === r.data[i] && r.data[j + 1] === r.data[i + 1] &&
              r.data[j + 2] === r.data[i + 2]) same++;
          const k = (r.data[j] << 16) | (r.data[j + 1] << 8) | r.data[j + 2];
          votes.set(k, (votes.get(k) || 0) + 1);
        }
      }
      if (odd < ODD || same > 0) continue;
      let bk = -1, bn = -1;
      for (const [k, n] of votes) if (n > bn || (n === bn && k > bk)) { bn = n; bk = k; }
      fills.push([i, (bk >> 16) & 255, (bk >> 8) & 255, bk & 255]);
    }
  }
  if (!fills.length) break;
  for (const [i, rr, gg, bb] of fills) { r.data[i] = rr; r.data[i + 1] = gg; r.data[i + 2] = bb; }
  removed += fills.length;
}
png.save(outFile, r);
console.log(`${inFile} -> ${outFile}: ${removed} one-pixel islands filled (odd>=${ODD}, ${PASSES} passes)`);
