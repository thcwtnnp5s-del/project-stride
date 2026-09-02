// EPO03 — re-extract one or more landmark goldens from a pre-guard composite
// (DECISIONS/0033: deliberate re-authoring of a landmark = re-extracting its
// golden in the same commit; the golden's git diff is the authorization).
//
// The golden guard in package-art.js throws BEFORE `emit`, so a composite that
// legitimately re-authors a landmark is never written to assets/. Sequence:
//
//   ATLAS_DUMP=<scratch>/pre_guard.png node Scripts/art/package-art.js   (throws on the golden — expected)
//   node extract-golden.js <scratch>/pre_guard.png south_strand_w south_strand_e
//   node Scripts/art/package-art.js      (green)
//   node Scripts/art/package-art.js --check
//
// Then stage the golden(s), the manifest, the region PNGs and
// assets/art/v1/world/atlas_base.png explicitly (G-8).
//
// A registry rect may be edited beforehand to follow the re-authored feature
// (never emptied or deleted); this tool crops whatever the registry says.
'use strict';
const fs = require('fs');
const path = require('path');
const REPO = path.resolve(__dirname, '../../../../..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const REM01 = path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration', 'WORLD_ATLAS_REMASTER_01');

const [compositePath, ...ids] = process.argv.slice(2);
if (!compositePath || !ids.length) {
  console.error('usage: node extract-golden.js <composite.png> <goldenId> [goldenId ...]');
  process.exit(2);
}
const reg = JSON.parse(fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8')).landmarks;
const atlas = png.load(compositePath);
if (atlas.width !== 1024 || atlas.height !== 1024) {
  throw new Error(`composite must be 1024x1024, got ${atlas.width}x${atlas.height}`);
}
for (const id of ids) {
  const lm = reg.find((l) => l.id === id);
  if (!lm) throw new Error(`unknown golden '${id}' — registry ids: ${reg.map((l) => l.id).join(', ')}`);
  const dest = path.join(REM01, 'goldens', `${id}.png`);
  png.save(dest, png.crop(atlas, lm.x, lm.y, lm.w, lm.h));
  console.log(`re-extracted ${id} ${lm.w}x${lm.h} @ (${lm.x},${lm.y}) -> ${path.relative(REPO, dest)}`);
}
