// EPO03 LANDMARKS — placement proof for overlays whose atlas_layout.json rows
// PROD-WORLD-LIFE has not placed yet (it owns `overlays`).
//
// `worldlife-composite.js` can only show what the layout already places, so
// until LIFE lands the four requested rows this tool composites the family's
// own manifest onto the SHIPPED atlas at the coordinates the request asks for
// — the same top-left convention (`atlas.x/y`) the layout uses. One sheet per
// frame index, so the motion can be judged as well as the position.
//
//   node landmark-overlay-preview.js <frameIndex>
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.resolve(ROOT, '../../../..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const SRC = path.join(ROOT, 'out', 'landmarks');
const manifest = JSON.parse(fs.readFileSync(path.join(SRC, 'manifest.json'), 'utf8'));
const frameIndex = Number(process.argv[2] || 0);
const atlas = png.load(path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
for (const a of manifest.assets) {
  const f = Math.min(frameIndex, a.frames - 1);
  png.blit(atlas, png.load(path.join(SRC, `${a.name}_f${f}.png`)), a.atlas.x, a.atlas.y);
  console.log(`  ${a.name} f${f} at atlas ${a.atlas.x},${a.atlas.y} (${a.canvas})`);
}
const dir = path.join(ROOT, 'review', 'landmarks');
fs.mkdirSync(dir, { recursive: true });
png.save(path.join(dir, `PLACEMENT_f${frameIndex}_x1.png`), atlas);
// Each site at the 197x426 phone FOV, x2 — the opening zoom the owner sees.
const fov = (id, cx, cy) => {
  const x = Math.max(0, Math.min(1024 - 197, cx - 98));
  const y = Math.max(0, Math.min(1024 - 426, cy - 213));
  png.save(path.join(dir, `PLACEMENT_f${frameIndex}_${id}_fov_x2.png`),
    png.scale(png.crop(atlas, x, y, 197, 426), 2));
};
fov('L1_glade', 356, 448);
fov('L2_storm', 218, 904);
fov('L3_bastion', 468, 164);
console.log(`-> review/landmarks/PLACEMENT_f${frameIndex}_*.png`);
