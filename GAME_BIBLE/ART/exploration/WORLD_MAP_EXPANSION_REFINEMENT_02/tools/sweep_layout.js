// One-shot +768 world-px sweep of atlas_layout.json for the 768 -> 1024
// canvas expansion (a second 128-native frontier ring; 128 x 6 = 768).
// Asserts the expected before-state, shifts every world-px coordinate, and
// reports per-list deltas so a missed list is loud.
//
// Usage: node sweep_layout.js [--write]   (dry run without --write)
'use strict';
const fs = require('fs');
const path = require('path');
const FILE = path.join(__dirname, '..', '..', '..', '..', '..', 'assets', 'content', 'v1', 'atlas', 'atlas_layout.json');
const SHIFT = 768;

const j = JSON.parse(fs.readFileSync(FILE, 'utf8'));
if (j.world.width !== 4608 || j.world.height !== 4608) throw new Error(`unexpected world ${j.world.width}x${j.world.height}`);
if (j.base.tiles.length !== 1 || j.base.tiles[0].width !== 768) throw new Error('unexpected base tiles');

let shifted = 0;
const shift = (o) => {
  if (typeof o.x !== 'number' || typeof o.y !== 'number') throw new Error('entry without x/y: ' + JSON.stringify(o).slice(0, 80));
  o.x += SHIFT;
  o.y += SHIFT;
  shifted += 1;
};

j.world.width = 6144;
j.world.height = 6144;
j.base.tiles[0].width = 1024;
j.base.tiles[0].height = 1024;

for (const r of j.rumors) shift(r);
for (const l of j.locations) shift(l);
for (const l of j.landmarks) shift(l);
for (const o of j.overlays) shift(o);
for (const p of j.props ?? []) shift(p);
let points = 0;
for (const r of j.routes) {
  for (const pt of r.points) {
    pt[0] += SHIFT;
    pt[1] += SHIFT;
    points += 1;
  }
}

console.log(`world 4608->6144, tile 768->1024, shifted ${shifted} entries ` +
  `(${j.rumors.length} rumors, ${j.locations.length} locations, ${j.landmarks.length} landmarks, ` +
  `${j.overlays.length} overlays, ${(j.props ?? []).length} props) + ${points} route points`);

if (process.argv.includes('--write')) {
  fs.writeFileSync(FILE, JSON.stringify(j, null, 2) + '\n');
  console.log('written');
} else {
  console.log('dry run — pass --write to apply');
}
