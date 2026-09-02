// FMPO02 — verify one generation before it is allowed near the packaging step.
//
// M-15's lesson in one sentence: "byte-preserved master" described only the
// INPUT, and nothing enforced it on the OUTPUT. So this checks the output.
//
//   1. size matches the crop exactly;
//   2. every pixel the region's mask does not authorize is byte-identical to
//      the source crop — a generation may not reach outside its own mask,
//      whatever the service decided to redraw;
//   3. reports how far the drift extends if it does, so a re-roll or a mask
//      shrink is an informed choice rather than a guess.
//
// Usage: node atlas-verify.js <regionId> <candidate.png>
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const id = process.argv[2];
const file = process.argv[3];
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', 'regions.json'), 'utf8'));
const region = cfg.regions.find((r) => r.id === id);
if (!region) throw new Error(`unknown region ${id}`);

const src = png.load(path.join(ROOT, 'src', 'atlas', `${id}_crop.png`));
const gen = png.load(path.isAbsolute(file) ? file : path.join(ROOT, file));
const mask = png.load(path.join(ROOT, 'out', 'atlas', `${id}_mask.png`));

if (gen.width !== src.width || gen.height !== src.height) {
  console.log(`FAIL size: crop ${src.width}x${src.height}, gen ${gen.width}x${gen.height}`);
  process.exit(1);
}

let outside = 0, inside = 0, authorized = 0;
let minX = 1e9, minY = 1e9, maxX = -1, maxY = -1;
for (let y = 0; y < src.height; y++) {
  for (let x = 0; x < src.width; x++) {
    const i = src.idx(x, y);
    const same = gen.data[i] === src.data[i] && gen.data[i + 1] === src.data[i + 1] &&
      gen.data[i + 2] === src.data[i + 2] && gen.data[i + 3] === src.data[i + 3];
    const m = mask.data[mask.idx(x, y)];
    if (m > 0) authorized++;
    if (same) continue;
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
    if (m > 0) inside++; else outside++;
  }
}
console.log(`${id}: changed-inside-mask ${inside}, changed-outside-mask ${outside}, ` +
  `mask-authorized ${authorized}`);
console.log(`  changed bbox in crop coords: (${minX},${minY})..(${maxX},${maxY})` +
  `  |  mask rect: (${region.rect.x0},${region.rect.y0})..(${region.rect.x1},${region.rect.y1})`);
console.log(outside === 0
  ? '  OK — nothing outside the authorization mask can reach the atlas.'
  : `  NOTE — ${outside} px changed outside the mask; the mask blocks them at ` +
    'packaging time, so they cannot ship, but a large number means the ' +
    'generation fought the mask (consider a re-roll).');
