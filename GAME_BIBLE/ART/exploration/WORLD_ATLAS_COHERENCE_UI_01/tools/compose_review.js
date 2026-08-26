// Review composite for WORLD_ATLAS_COHERENCE_UI_01: takes the shipped
// atlas_base, blits the authored cross-boundary bridge crops over the surviving
// generation seams, then unifies the open ocean deterministically. This mirrors
// exactly what the shipping composition in Scripts/art/package-art.js will do,
// and is the artifact reviewed at phone scale.
//
// Usage: node compose_review.js <atlas_base.png> <out.png>
'use strict';
const path = require('path');
const REPO = path.join(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const { unify } = require('./ocean_unify');

const BR = path.join(__dirname, '..', 'out', 'bridges');
const bridge = (name) => png.load(path.join(BR, `${name}_f0.png`));

// [name, x, y] — blit order matters where bridges overlap (later wins).
const BRIDGES = [
  ['north_west', 0, 0],
  ['north_center', 256, 0],
  ['north_east', 768, 0],
  ['north_master', 256, 224],
  ['nw_corner', 80, 80],
  ['north_junction', 256, 188],
  ['north_mtop', 300, 232],
  ['west_mid', 48, 256],
  ['east_x768', 640, 256],
  ['sw', 0, 592],
  ['south', 256, 720],
  ['se', 704, 704],
];

// Edge-integration pass (fix2): dissolves the visible perimeters of the bridges
// above. Cut from the post-conform atlas, so blitted AFTER the ocean conform.
const FIX2 = [
  ['d1_nw', 176, 24],
  ['d1c_nw', 0, 0],
  ['d4_west', 0, 544],
  ['d5_se', 684, 684],
  ['d2_north', 290, 236],
  ['d2b_floe', 240, 140],
  ['d3_ne', 740, 40],
];
const fix2 = (name) =>
  png.load(path.join(__dirname, '..', 'out', 'fix2', 'bridges', `${name}_f0.png`));

const atlas = png.load(process.argv[2]);
for (const [name, x, y] of BRIDGES) png.blit(atlas, bridge(name), x, y);
const n = unify(atlas);
for (const [name, x, y] of FIX2) png.blit(atlas, fix2(name), x, y);
png.save(process.argv[3], atlas);
console.log(
  `compose_review: ${BRIDGES.length} bridges + ${n} ocean px + ${FIX2.length} edge fixes -> ${process.argv[3]}`,
);
