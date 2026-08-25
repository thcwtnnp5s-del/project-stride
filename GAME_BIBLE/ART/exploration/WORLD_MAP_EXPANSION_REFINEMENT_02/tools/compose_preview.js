// Compose a preview of the corrected 768 base: WMP03 retained pieces plus
// this round's replacement candidates, with the same deterministic dither
// crossfade package-art.js ships. Preview only — the shipping composition
// stays in Scripts/art/package-art.js.
//
// Usage: node compose_preview.js <out.png> [east=path] [west=path] [ne=path] [se=path]
'use strict';
const path = require('path');
const fs = require('fs');
const REPO = path.join(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const WMP03 = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'WORLD_MAP_POLISH_03', 'out', 'world');
const MASTER = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'PRESENTATION_WORLD_REWARD_FEEL_01', 'out', 'world', 'whole_a_0.png');

const over = {};
const patches = [];
for (const a of process.argv.slice(3)) {
  const [k, v] = a.split('=');
  if (k === 'patch') {
    // patch=file@x,y — blit an edited crop back onto the base at (x, y).
    const [file, at] = v.split('@');
    const [px, py] = at.split(',').map(Number);
    patches.push({ file: path.resolve(file), px, py });
  } else {
    over[k] = path.resolve(v);
  }
}

const p = (name, key, w, h) => {
  const file = over[key] ?? path.join(WMP03, `${name}.png`);
  const r = png.load(file);
  if (r.width !== w || r.height !== h) throw new Error(`${file}: ${r.width}x${r.height}, want ${w}x${h}`);
  return r;
};

const base = new png.Raster(768, 768);
png.blit(base, p('corner_nw_128', 'nw', 128, 128), 0, 0);
png.blit(base, p('strip_north_512x128', 'north', 512, 128), 128, 0);
png.blit(base, p('corner_ne_128', 'ne', 128, 128), 640, 0);
png.blit(base, p('strip_west_128x512', 'west', 128, 512), 0, 128);
png.blit(base, p('strip_east_128x512', 'east', 128, 512), 640, 128);
png.blit(base, p('corner_sw_128', 'sw', 128, 128), 0, 640);
png.blit(base, p('strip_south_512x128', 'south', 512, 128), 128, 640);
png.blit(base, p('corner_se_128', 'se', 128, 128), 640, 640);
png.blit(base, png.load(MASTER), 128, 128);
for (const { file, px, py } of patches) {
  png.blit(base, png.load(file), px, py);
}

const before = base.clone();
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};
const BAND = 11;
const chance = (d) => 0.45 * (1 - (d - 1) / BAND);
const swap = (ax, ay, bx, by) => {
  const ai = base.idx(ax, ay);
  const bi = before.idx(bx, by);
  for (let k = 0; k < 4; k++) base.data[ai + k] = before.data[bi + k];
};
for (const seamY of [128, 640]) {
  for (let x = 0; x < 768; x++) {
    for (let d = 1; d <= BAND; d++) {
      const pr = chance(d);
      if (hash(x, seamY - d, 1) < pr) swap(x, seamY - d, x, seamY + d - 1);
      if (hash(x, seamY + d - 1, 2) < pr) swap(x, seamY + d - 1, x, seamY - d);
    }
  }
}
for (const seamX of [128, 640]) {
  for (let y = 0; y < 768; y++) {
    for (let d = 1; d <= BAND; d++) {
      const pr = chance(d);
      if (hash(seamX - d, y, 3) < pr) swap(seamX - d, y, seamX + d - 1, y);
      if (hash(seamX + d - 1, y, 4) < pr) swap(seamX + d - 1, y, seamX - d, y);
    }
  }
}
png.save(process.argv[2], base);
console.log('wrote', process.argv[2]);
