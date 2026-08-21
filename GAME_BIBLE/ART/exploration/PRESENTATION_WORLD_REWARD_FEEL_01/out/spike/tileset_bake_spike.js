// PWRF01 atlas spike — Wang-tileset bake prototype (NON-PRODUCTION).
//
// Proves the headless tile pipeline: PixelLab tileset sheets + metadata in,
// a terrain vertex grid authored in code, corner-matched autotiling, one
// flattened PNG out. This is the "PixelLab owns terrain art, Claude/Flutter
// own coordinates and compositing" architecture, testable without the web
// Map Workshop.
//
// **Evidence, not a build step.** Nothing in the app runs this and no CI
// job calls it; it is kept because `MILESTONES/PIXELLAB_MAPS_EVALUATION.md`
// cites its result (a 45 × 25 grid over three chained tilesets, 1408 × 768
// out, zero cells missing a tile) and a future tiled-world round should
// start from working code rather than from the description of it.
//
// To re-run: fetch the three tilesets' `image` and `metadata` endpoints
// beside this file as `<pair>.png` / `<pair>.json` (ids in the evaluation),
// then `node tileset_bake_spike.js` from this directory. `bake_proof.png`
// is the output it produced.
'use strict';

const fs = require('fs');
const path = require('path');
const png = require('../../../../../Scripts/art/png.js');

// ---- tilesets: pair name -> {sheet, tiles: corners-key -> box, lower, upper}
function loadSet(base, lowerName, upperName) {
  const meta = JSON.parse(fs.readFileSync(`${base}.json`, 'utf8'));
  const sheet = png.load(`${base}.png`);
  const tiles = {};
  for (const t of meta.tileset_data.tiles) {
    const key = `${t.corners.NW},${t.corners.NE},${t.corners.SW},${t.corners.SE}`;
    tiles[key] = t.bounding_box;
  }
  return { sheet, tiles, lower: lowerName, upper: upperName };
}

const SETS = [
  loadSet('grass_stone', 'grass', 'stone'),
  loadSet('dirt_grass', 'dirt', 'grass'),
  loadSet('water_grass', 'water', 'grass'),
];

// ---- terrain vertex grid ------------------------------------------------
// 45 x 25 vertices -> 44 x 24 cells at 32 px = 1408 x 768 px.
const W = 45, H = 25;
const g = Array.from({ length: H }, () => Array(W).fill('grass'));

function blob(cx, cy, r, t) {
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dx = x - cx, dy = y - cy;
    if (dx * dx + dy * dy * 1.6 <= r * r * (0.75 + 0.5 * Math.abs(Math.sin(x * 3.1 + y * 1.7)))) g[y][x] = t;
  }
}
function pathLine(points, t, width) {
  for (let i = 0; i + 1 < points.length; i++) {
    const [x0, y0] = points[i], [x1, y1] = points[i + 1];
    const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) * 2;
    for (let s = 0; s <= steps; s++) {
      const x = x0 + ((x1 - x0) * s) / steps, y = y0 + ((y1 - y0) * s) / steps;
      for (let dy = -width; dy <= width; dy++) for (let dx = -width; dx <= width; dx++) {
        const xx = Math.round(x + dx), yy = Math.round(y + dy);
        if (xx >= 0 && xx < W && yy >= 0 && yy < H && dx * dx + dy * dy <= width * width) g[yy][xx] = t;
      }
    }
  }
}

// A lake in the west, a stone ridge along the north-east, a dirt road
// linking them across the meadow.
blob(9, 15, 7, 'water');
blob(33, 6, 6, 'stone');
blob(38, 9, 4, 'stone');
pathLine([[14, 17], [22, 14], [30, 9]], 'dirt', 1);

// ---- clean illegal cells: every cell may span at most one tileset pair --
// Adjacent-terrain graph: water-grass, grass-stone, dirt-grass. A cell whose
// corners mix water+stone, water+dirt, or dirt+stone is repaired by
// flooding it to grass (the shared neighbour) at the offending vertices.
const PAIRS = new Set(['grass|stone', 'dirt|grass', 'grass|water']);
function cellOk(x, y) {
  const c = [g[y][x], g[y][x + 1], g[y + 1][x], g[y + 1][x + 1]];
  const uniq = [...new Set(c)].sort();
  if (uniq.length === 1) return true;
  if (uniq.length === 2) return PAIRS.has(uniq.join('|'));
  return false;
}
let repaired = 0;
for (let pass = 0; pass < 4; pass++) {
  for (let y = 0; y + 1 < H; y++) for (let x = 0; x + 1 < W; x++) {
    if (cellOk(x, y)) continue;
    // demote non-grass minority corners to grass
    const cs = [[y, x], [y, x + 1], [y + 1, x], [y + 1, x + 1]];
    for (const [yy, xx] of cs) if (g[yy][xx] !== 'grass') { g[yy][xx] = 'grass'; repaired++; break; }
  }
}
console.log('repaired vertices:', repaired);

// ---- bake ---------------------------------------------------------------
const TILE = 32;
const out = new png.Raster((W - 1) * TILE, (H - 1) * TILE);
let missing = 0;
for (let y = 0; y + 1 < H; y++) {
  for (let x = 0; x + 1 < W; x++) {
    const corners = { NW: g[y][x], NE: g[y][x + 1], SW: g[y + 1][x], SE: g[y + 1][x + 1] };
    const uniq = [...new Set(Object.values(corners))];
    let drawn = false;
    for (const set of SETS) {
      const label = (t) => (t === set.lower ? 'lower' : t === set.upper ? 'upper' : null);
      if (!uniq.every((t) => label(t) !== null)) continue;
      const key = `${label(corners.NW)},${label(corners.NE)},${label(corners.SW)},${label(corners.SE)}`;
      const box = set.tiles[key];
      if (!box) continue;
      png.blit(
        out,
        png.crop(set.sheet, box.x, box.y, box.width, box.height),
        x * TILE,
        y * TILE,
      );
      drawn = true;
      break;
    }
    if (!drawn) missing++;
  }
}
console.log('cells missing a tile:', missing);
png.save('bake_proof.png', out);
console.log('baked', out.width, 'x', out.height);
