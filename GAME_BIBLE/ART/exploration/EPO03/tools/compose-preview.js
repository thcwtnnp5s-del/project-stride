// EPO03 — composite ONE region onto a copy of the shipped atlas with exactly
// the mask math package-art.js uses, WITHOUT touching assets/ (so four world
// teams can preview in parallel; package-art.js builds are serialized and run
// only at ACCEPT). Writes the three judgement views atlas-review.js writes:
//
//   review/atlas/<id>_preview_full.png   whole atlas x1
//   review/atlas/<id>_preview_x2.png     crop + 40 px untouched perimeter, x2
//   review/atlas/<id>_preview_fov.png    197x426 phone FOV at x1, centred
//   review/atlas/<id>_preview_fov_x2.png the same FOV at x2 (what the owner sees)
//
// Usage: node compose-preview.js <regionId> <team>
//   reads src/atlas/regions_<team>.json, out/atlas/<id>.png, out/atlas/<id>_mask.png
//
// Deterministic: same hash, same salt, same dither-SELECT (A-2). A preview
// that passes here is the composite package-art.js will build, except for
// the water-only ocean conform that runs after the EPO03 block.
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.resolve(ROOT, '../../../..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const { hash } = require(path.join(__dirname, 'atlas-mask.js'));

const [id, team] = process.argv.slice(2);
if (!id || !team) {
  console.error('usage: node compose-preview.js <regionId> <team>');
  process.exit(2);
}
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', `regions_${team}.json`), 'utf8'));
const region = cfg.regions.find((r) => r.id === id);
if (!region) throw new Error(`unknown region ${id} in regions_${team}.json`);
if (typeof region.salt !== 'number' || region.salt < 40) {
  throw new Error(`region ${id}: salt must be a number >= 40 (got ${region.salt})`);
}

const atlas = png.load(path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const gen = png.load(path.join(ROOT, 'out', 'atlas', `${id}.png`));
const mask = png.load(path.join(ROOT, 'out', 'atlas', `${id}_mask.png`));
if (gen.width !== region.w || gen.height !== region.h ||
    mask.width !== region.w || mask.height !== region.h) {
  throw new Error(`region ${id}: expected ${region.w}x${region.h}, got gen ` +
    `${gen.width}x${gen.height}, mask ${mask.width}x${mask.height}`);
}

let written = 0;
for (let sy = 0; sy < region.h; sy++) {
  for (let sx = 0; sx < region.w; sx++) {
    const m = mask.data[mask.idx(sx, sy)];
    if (m === 0) continue;
    const tx = region.x + sx, ty = region.y + sy;
    if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
    if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
    const si = gen.idx(sx, sy);
    if (gen.data[si + 3] === 0) continue;
    const ai = atlas.idx(tx, ty);
    for (let k = 0; k < 4; k++) atlas.data[ai + k] = gen.data[si + k];
    written++;
  }
}

const dir = path.join(ROOT, 'review', 'atlas');
fs.mkdirSync(dir, { recursive: true });
const clampRect = (x, y, w, h) => [
  Math.max(0, Math.min(1024 - w, x)), Math.max(0, Math.min(1024 - h, y)), w, h];

png.save(path.join(dir, `${id}_preview_full.png`), atlas);
{
  const [x, y, w, h] = clampRect(region.x - 40, region.y - 40,
    Math.min(1024, region.w + 80), Math.min(1024, region.h + 80));
  png.save(path.join(dir, `${id}_preview_x2.png`), png.scale(png.crop(atlas, x, y, w, h), 2));
}
{
  const cx = region.x + (region.w >> 1), cy = region.y + (region.h >> 1);
  const [x, y, w, h] = clampRect(cx - 98, cy - 213, 197, 426);
  const fov = png.crop(atlas, x, y, w, h);
  png.save(path.join(dir, `${id}_preview_fov.png`), fov);
  png.save(path.join(dir, `${id}_preview_fov_x2.png`), png.scale(fov, 2));
}
console.log(`${id} (${team}): ${written} px selected from the generation; ` +
  `preview full / x2 / fov / fov_x2 written to review/atlas/`);
