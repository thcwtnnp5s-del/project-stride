// WORLD ATLAS REMASTER 01 — review artifact set.
//
// Renders the round's review set into review/ from the BEFORE snapshot
// (review/before/atlas_base_before.png) and the current shipped composite:
//   - survey_before.png / survey_after.png (1:1)
//   - per-region before/after pairs at x2
//   - phone-FOV crops (197x350 at x2 — iPhone 15 Pro Max width at the
//     default 1/3 zoom) over each region
//   - perimeter strips at x3 for each region's mask boundary
//   - protected_overlay.png — landmark registry (orange) + A-4 core
//     (magenta rim) over the after survey
//
// Run after `node Scripts/art/package-art.js`.
'use strict';
const path = require('path');
const fs = require('fs');
const ROOT = path.resolve(__dirname, '..', '..', '..', '..', '..');
const png = require(path.join(ROOT, 'Scripts', 'art', 'png.js'));

const R = path.join(__dirname, '..');
const before = png.load(path.join(R, 'review', 'before', 'atlas_base_before.png'));
const after = png.load(path.join(ROOT, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const outDir = path.join(R, 'review');
fs.mkdirSync(outDir, { recursive: true });

const crop = (src, x, y, w, h, s) => {
  const out = new png.Raster(w * s, h * s);
  for (let oy = 0; oy < h * s; oy++) {
    for (let ox = 0; ox < w * s; ox++) {
      const sx = Math.min(src.width - 1, Math.max(0, x + Math.floor(ox / s)));
      const sy = Math.min(src.height - 1, Math.max(0, y + Math.floor(oy / s)));
      const si = src.idx(sx, sy), oi = out.idx(ox, oy);
      for (let k = 0; k < 4; k++) out.data[oi + k] = src.data[si + k];
    }
  }
  return out;
};
const save = (name, raster) => {
  png.save(path.join(outDir, name), raster);
  console.log(`wrote review/${name}`);
};

save('survey_before.png', crop(before, 0, 0, 1024, 1024, 1));
save('survey_after.png', crop(after, 0, 0, 1024, 1024, 1));

// Region views: [id, x, y, w, h] view rects chosen to include each mask
// perimeter with context.
const VIEWS = [
  ['r1_ice', 560, 0, 464, 320],
  ['r2_verge', 152, 528, 184, 328],
  ['r3_sw', 0, 720, 200, 304],
  ['r4_coast', 420, 820, 192, 204],
  ['r5_nwice', 166, 78, 254, 222],
];
for (const [id, x, y, w, h] of VIEWS) {
  save(`${id}_before_x2.png`, crop(before, x, y, w, h, 2));
  save(`${id}_after_x2.png`, crop(after, x, y, w, h, 2));
  const cx = Math.max(0, Math.min(1024 - 197, x + Math.floor(w / 2) - 98));
  const cy = Math.max(0, Math.min(1024 - 350, y + Math.floor(h / 2) - 175));
  save(`${id}_phonefov_x2.png`, crop(after, cx, cy, 197, 350, 2));
}

// Perimeter strips (x3) across each region's mask edges.
const STRIPS = [
  ['r1_west_edge', 578, 0, 60, 280],
  ['r1_south_edge', 600, 210, 340, 90],
  ['r2_west_edge', 170, 560, 60, 264],
  ['r2_east_edge', 242, 560, 60, 264],
  ['r3_north_edge', 0, 818, 160, 60],
  ['r3b_band', 100, 840, 80, 184],
  ['r4_top_edge', 440, 844, 150, 60],
  ['r5_west_edge', 184, 96, 60, 186],
  ['r5_east_edge', 342, 96, 60, 186],
];
for (const [id, x, y, w, h] of STRIPS) {
  save(`strip_${id}_x3.png`, crop(after, x, y, w, h, 3));
}

// Protected overlay.
const overlay = after.clone();
const tint = (x, y, r, g, b) => {
  if (x < 0 || y < 0 || x >= 1024 || y >= 1024) return;
  const i = overlay.idx(x, y);
  overlay.data[i] = Math.round((overlay.data[i] + 2 * r) / 3);
  overlay.data[i + 1] = Math.round((overlay.data[i + 1] + 2 * g) / 3);
  overlay.data[i + 2] = Math.round((overlay.data[i + 2] + 2 * b) / 3);
};
// A-4 core rim (magenta outline at the guard boundary 276/748).
for (let t = 276; t < 748; t++) {
  for (const [x, y] of [[t, 276], [t, 747], [276, t], [747, t]]) tint(x, y, 255, 0, 255);
}
const reg = JSON.parse(fs.readFileSync(path.join(R, 'landmark_registry.json'), 'utf8'));
for (const lm of reg.landmarks) {
  for (let x = lm.x; x < lm.x + lm.w; x++) { tint(x, lm.y, 255, 140, 0); tint(x, lm.y + lm.h - 1, 255, 140, 0); }
  for (let y = lm.y; y < lm.y + lm.h; y++) { tint(lm.x, y, 255, 140, 0); tint(lm.x + lm.w - 1, y, 255, 140, 0); }
}
save('protected_overlay.png', overlay);
