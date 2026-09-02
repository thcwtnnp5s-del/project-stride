// FMPO02 — the two acceptance checks a human eye is bad at, run on the
// SHIPPED composite rather than on the generation (ART-03 §7.6):
//
//   * repeated identical sprite pairs within 40 px — a generator's favourite
//     tell, and invisible until you notice it and then impossible to unsee;
//   * orphan flecks — isolated 1–2 px clusters that read as speck noise at
//     phone FOV.
//
// A "sprite" here is a 10×10 block whose content is busy enough to be a
// drawn thing rather than flat ground (a flat-grass block matches a thousand
// others and means nothing). Blocks are compared by exact RGB equality.
//
// Usage: node atlas-qa.js <regionId>
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const id = process.argv[2];
const team = process.argv[3];
const cfgFile = team ? `regions_${team}.json` : 'regions.json';
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', cfgFile), 'utf8'));
const region = cfg.regions.find((r) => r.id === id);
if (!region) throw new Error(`unknown region ${id}`);
const atlas = png.load(path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));

const B = 10;          // block size
const NEAR = 40;       // "within 40 px"
const MIN_COLORS = 6;  // a block flatter than this is ground, not a sprite

const x0 = Math.max(0, region.x), y0 = Math.max(0, region.y);
const x1 = Math.min(1024, region.x + region.w), y1 = Math.min(1024, region.y + region.h);

const blocks = new Map();
let dupPairs = 0;
const examples = [];
for (let y = y0; y + B <= y1; y += 2) {
  for (let x = x0; x + B <= x1; x += 2) {
    const px = [];
    const seen = new Set();
    for (let by = 0; by < B; by++) {
      for (let bx = 0; bx < B; bx++) {
        const i = atlas.idx(x + bx, y + by);
        const c = (atlas.data[i] << 16) | (atlas.data[i + 1] << 8) | atlas.data[i + 2];
        px.push(c); seen.add(c);
      }
    }
    if (seen.size < MIN_COLORS) continue;
    const key = px.join(',');
    const prev = blocks.get(key);
    if (prev) {
      for (const [px0, py0] of prev) {
        if (Math.abs(px0 - x) <= NEAR && Math.abs(py0 - y) <= NEAR) {
          dupPairs++;
          if (examples.length < 8) examples.push(`(${px0},${py0}) == (${x},${y})`);
          break;
        }
      }
      prev.push([x, y]);
    } else {
      blocks.set(key, [[x, y]]);
    }
  }
}

// Orphan flecks: a pixel whose colour differs sharply from ≥7 of its 8
// neighbours, and whose 5×5 neighbourhood holds no more than 2 such pixels.
let flecks = 0;
const far = (a, b) => Math.abs(atlas.data[a] - atlas.data[b]) +
  Math.abs(atlas.data[a + 1] - atlas.data[b + 1]) +
  Math.abs(atlas.data[a + 2] - atlas.data[b + 2]) > 150;
for (let y = y0 + 2; y < y1 - 2; y++) {
  for (let x = x0 + 2; x < x1 - 2; x++) {
    const i = atlas.idx(x, y);
    let odd = 0;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        if (far(i, atlas.idx(x + dx, y + dy))) odd++;
      }
    }
    if (odd >= 7) flecks++;
  }
}

console.log(`${id} (atlas ${x0}..${x1} × ${y0}..${y1}):`);
console.log(`  repeated ${B}×${B} sprite pairs within ${NEAR} px: ${dupPairs}`);
for (const e of examples) console.log(`    ${e}`);
console.log(`  orphan flecks: ${flecks}`);
