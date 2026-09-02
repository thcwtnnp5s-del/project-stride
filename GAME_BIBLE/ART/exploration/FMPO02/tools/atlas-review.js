// FMPO02 — render the three judgement views for one atlas region.
//
//   <id>_full.png   the whole 1024^2 atlas at x1 (does the region read as part
//                   of one painting from arm's length?)
//   <id>_x2.png     the region at x2 with 40 px of UNTOUCHED perimeter on each
//                   side (does any boundary, dither column or repair footprint
//                   read?)
//   <id>_fov.png    a 197x426 phone-FOV crop centred on the region, at x1 —
//                   the opening-zoom viewport the owner actually sees.
//
// Usage: node atlas-review.js <regionId> [tag]     (tag: before | after | ...)
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const id = process.argv[2];
const tag = process.argv[3] || 'after';
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', 'regions.json'), 'utf8'));
const region = cfg.regions.find((r) => r.id === id);
if (!region) throw new Error(`unknown region ${id}`);

const atlas = png.load(path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
const dir = path.join(ROOT, 'review', 'atlas');
fs.mkdirSync(dir, { recursive: true });

const clampRect = (x, y, w, h) => {
  const x0 = Math.max(0, Math.min(1024 - w, x));
  const y0 = Math.max(0, Math.min(1024 - h, y));
  return [x0, y0, w, h];
};

// 1. Whole atlas, x1.
png.save(path.join(dir, `${id}_${tag}_full.png`), atlas);

// 2. Region + 40 px untouched perimeter, x2.
{
  const [x, y, w, h] = clampRect(region.x - 40, region.y - 40,
    Math.min(1024, region.w + 80), Math.min(1024, region.h + 80));
  png.save(path.join(dir, `${id}_${tag}_x2.png`), png.scale(png.crop(atlas, x, y, w, h), 2));
}

// 3. Phone FOV: 197 x 426 atlas px at the opening zoom, centred on the region.
{
  const cx = region.x + (region.w >> 1);
  const cy = region.y + (region.h >> 1);
  const [x, y, w, h] = clampRect(cx - 98, cy - 213, 197, 426);
  png.save(path.join(dir, `${id}_${tag}_fov.png`), png.crop(atlas, x, y, w, h));
}

console.log(`${id} ${tag}: full / x2 / fov written to review/atlas/`);
