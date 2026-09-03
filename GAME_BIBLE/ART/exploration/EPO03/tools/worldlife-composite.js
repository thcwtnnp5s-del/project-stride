// FMPO02 WORLD_FIX — composite every placed overlay and prop onto the CURRENT
// atlas and write the placement review sheets.
//
// FINAL-04 #4: the placement evidence that shipped
// (`review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png`, 00:38) predates N1, N2,
// N3 and NB2 — its north is the old honeycomb, so nothing northern was ever
// verified against the atlas that ships. This tool always reads
// `assets/art/v1/world/atlas_base.png` at HEAD-of-disk and
// `assets/content/v1/atlas/atlas_layout.json`, so a sheet cannot be stale
// against the pixels it claims to verify.
//
// Sprites come from the PACKAGED tree (`assets/art/v1/env/`) — the bytes the
// app loads — not from `out/worldlife/`, so a manifest that has not been
// repackaged shows up as a missing file rather than as a passing sheet.
//
// Overlay `x,y` is the sprite TOP-LEFT in world coords; prop `x,y` is the
// ANCHOR, with `anchorX/anchorY` sprite-local. World = atlas x 6.
//
// Usage: node worldlife-composite.js [outPrefix]
//   writes review/worldlife/<prefix>_x1.png (the whole atlas, every entry)
//   and   review/worldlife/<prefix>_north_x2.png (atlas 380-800 x 0-260).
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const SCALE = 6; // world units per atlas pixel
const ART = path.join(REPO, 'assets', 'art', 'v1');
const layout = JSON.parse(fs.readFileSync(
  path.join(REPO, 'assets', 'content', 'v1', 'atlas', 'atlas_layout.json'), 'utf8'));
const atlas = png.load(path.join(ART, 'world', 'atlas_base.png'));

const prefix = process.argv[2] || 'ATLAS_PLACEMENT_HEAD';
const missing = [];
const placed = [];

/** First frame of an overlay, or the still of a prop. */
function sprite(asset, frames) {
  const base = path.join(ART, `${asset}.png`);
  const f0 = path.join(ART, `${asset}_f0.png`);
  const file = frames === undefined ? base : (fs.existsSync(f0) ? f0 : base);
  if (!fs.existsSync(file)) { missing.push(path.relative(ART, file)); return null; }
  return png.load(file);
}

for (const p of layout.props) {
  const r = sprite(p.asset);
  if (!r) continue;
  const x = Math.round(p.x / SCALE) - (p.anchorX || 0);
  const y = Math.round(p.y / SCALE) - (p.anchorY || 0);
  png.blit(atlas, r, x, y);
  placed.push([p.asset, x, y, r.width, r.height, 'prop']);
}

const patrols = [];
for (const o of layout.overlays) {
  // EPO03 schema v6: a `path` overlay has no `x,y` at all — the line says
  // where it is, and where it is depends on the second. Blitting one here
  // would compute NaN and drop it from the sheet without a word, which is
  // exactly the "verified against something that isn't what ships" failure
  // this tool exists to prevent. Named and skipped instead.
  if (o.path) { patrols.push(o.asset); continue; }
  const r = sprite(o.asset, o.frames);
  if (!r) continue;
  const x = Math.round(o.x / SCALE);
  const y = Math.round(o.y / SCALE);
  png.blit(atlas, r, x, y);
  placed.push([o.asset, x, y, r.width, r.height, 'overlay']);
}

const dir = path.join(ROOT, 'review', 'worldlife');
fs.mkdirSync(dir, { recursive: true });
png.save(path.join(dir, `${prefix}_x1.png`), atlas);
png.save(path.join(dir, `${prefix}_north_x2.png`),
  png.scale(png.crop(atlas, 380, 0, 420, 260), 2));

console.log(`${placed.length} entries composited onto the current atlas`);
for (const [a, x, y, w, h, kind] of placed) {
  console.log(`  ${kind.padEnd(7)} ${a.padEnd(34)} atlas ${x},${y} ${w}x${h}`);
}
if (patrols.length) {
  console.log(`SKIPPED ${patrols.length} v6 path overlay(s) — they have no `
    + `fixed x,y and their position depends on the clock. Render those with `
    + `life-patrol-proof.js <prefix> <seconds...>: ${[...new Set(patrols)].join(', ')}`);
}
if (missing.length) {
  console.log(`MISSING ${missing.length} packaged sprite(s): ${missing.join(', ')}`);
}
