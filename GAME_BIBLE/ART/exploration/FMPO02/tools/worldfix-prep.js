// FMPO02 WORLD_FIX — deterministic preparation of the re-authored world-life
// sprites. Crops each PixelLab candidate to its own content bounds (A-2: a
// crop invents nothing) and writes it into `out/worldlife/` under the name
// package-art.js expects, then reports the size the manifest must declare.
//
// FINAL-04 #3 and #5: the two hero props shipped as isometric diorama tiles
// with an extruded soil side wall, and the four creature overlays shipped at
// 3-4x map scale. Both were re-authored at map scale; this script only moves
// bytes.
//
// Usage: node worldfix-prep.js
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

const RAW = path.join(ROOT, 'raw', 'worldlife');
const OUT = path.join(ROOT, 'out', 'worldlife');

/** Crop to the opaque bounds and save; returns [w,h]. */
function tight(src, dest) {
  const r = png.load(path.join(RAW, src));
  const b = png.bounds(r);
  const c = png.crop(r, b.left, b.top, b.right - b.left + 1, b.bottom - b.top + 1);
  png.save(path.join(OUT, dest), c);
  return [c.width, c.height];
}

const jobs = [
  ['castle_mo3.png', 'prop_fairy_castle.png'],
  ['house_mo1.png', 'prop_storm_house.png'],
  ['deer_still.png', 'overlay_deer2_f0.png'],
  ['yeti_still.png', 'overlay_yeti3_f0.png'],
  ['wagon_still.png', 'overlay_wagon_f0.png'],
];
for (const [src, dest] of jobs) {
  const [w, h] = tight(src, dest);
  console.log(`${dest.padEnd(28)} ${w}x${h}`);
}

// The frames the halved one-frame overlays leave behind. package-art.js emits
// exactly `frames` files per overlay, and `--check` reports anything left in
// `assets/art/v1/` that no emitter owns, so the surplus sources go too.
for (const [name, from] of [['overlay_deer2', 1], ['overlay_yeti3', 1]]) {
  for (let i = from; i < 9; i++) {
    const f = path.join(OUT, `${name}_f${i}.png`);
    if (fs.existsSync(f)) { fs.unlinkSync(f); console.log(`  removed ${name}_f${i}.png`); }
  }
}

// FINAL-04 #6, the half of it that is a colour and not a shape: the motes
// shipped as saturated gold, which is what makes six round bodies read as
// coins. This is the same deterministic tone remap `toneBronze` already
// applies to the FMPO02 reward strips — saturation pulled back and the hue
// carried off yellow toward honey-green — run over the four shipped frames.
// It does not change a single pixel's position or alpha (A-2).
{
  let touched = 0;
  for (let i = 0; i < 4; i++) {
    const f = path.join(OUT, `overlay_fairy_motes_f${i}.png`);
    const r = png.load(f);
    for (let p = 0; p < r.data.length; p += 4) {
      if (r.data[p + 3] === 0) continue;
      const [cr, cg, cb] = [r.data[p], r.data[p + 1], r.data[p + 2]];
      const y = 0.30 * cr + 0.59 * cg + 0.11 * cb;
      // 35% toward the pixel's own luma (desaturate), then a fixed
      // honey-green cast: red down, green up a little, blue held. Chosen off
      // a three-way sweep on the canopy the motes now sit on
      // (`review/fix/motes_tone_sweep.png`): 0.25 was still gold, 0.45 went
      // grey, 0.35 is pale honey with a green cast and no longer reads as a
      // struck coin.
      const mix = (c, k) => Math.max(0, Math.min(255, Math.round(c + (y - c) * 0.35 + k)));
      r.data[p] = mix(cr, -12);
      r.data[p + 1] = mix(cg, 4);
      r.data[p + 2] = mix(cb, 0);
      touched++;
    }
    png.save(f, r);
  }
  console.log(`overlay_fairy_motes: ${touched} px toned honey-green over 4 frames`);
}
