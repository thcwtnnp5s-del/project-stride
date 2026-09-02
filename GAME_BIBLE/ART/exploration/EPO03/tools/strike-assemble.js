// EPO03 LANDMARKS — assemble `overlay_storm_strike` (80x96, 8 f, 100 ms, loops 1)
// from the two accepted PixelLab forks, per DIR-03's overlay table:
//   f0 main fork top->roof + a dithered white-blue ground flash, 28 px across
//   f1 afterglow (the flash only, thinned by the same hash dither)
//   f2 the thinner second fork
//   f3 fade (the thin fork, hash-thinned)
//   f4..f7 empty
// A-2: the forks are PixelLab's own pixels, translated only. The flash is the
// script-assembled element DIR-03 specifies (a dithered disc), drawn from two
// fixed inks, never averaged with anything.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const OUT = path.resolve(__dirname, '..', 'out', 'landmarks', 'strike');
require('fs').mkdirSync(OUT, { recursive: true });
const W = 80, H = 96;
const FOOT = { x: 40, y: 72 };            // the house roof in overlay coords
const main = png.load(path.join(__dirname, '..', 'out', 'landmarks', 'strike_fork_main.png'));
const thin = png.load(path.join(__dirname, '..', 'out', 'landmarks', 'strike_fork_thin.png'));
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};
const INK_HOT = [255, 255, 255, 255];
const INK_COOL = [206, 218, 255, 255];
function blank() { return new png.Raster(W, H); }
function stamp(dst, src, dx, dy, keep) {
  for (let y = 0; y < src.height; y++) for (let x = 0; x < src.width; x++) {
    const si = src.idx(x, y);
    if (src.data[si + 3] === 0) continue;
    const tx = x + dx, ty = y + dy;
    if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
    if (keep !== undefined && hash(tx, ty, 137) >= keep) continue;
    const di = dst.idx(tx, ty);
    for (let k = 0; k < 4; k++) dst.data[di + k] = src.data[si + k];
  }
}
/** A dithered disc of light on the ground: density falls off with radius. */
function flash(dst, radius, strength) {
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dx = (x - FOOT.x) / radius, dy = (y - FOOT.y) / (radius * 0.55);
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d > 1) continue;
    const p = (1 - d) * strength;
    if (hash(x, y, 149) >= p) continue;
    const ink = hash(x, y, 151) < 0.45 ? INK_HOT : INK_COOL;
    const di = dst.idx(x, y);
    for (let k = 0; k < 4; k++) dst.data[di + k] = ink[k];
  }
}
const frames = [];
{ const f = blank(); flash(f, 15, 1.0); stamp(f, main, 14, -18); frames.push(f); }
{ const f = blank(); flash(f, 14, 0.55); stamp(f, main, 14, -18, 0.35); frames.push(f); }
{ const f = blank(); flash(f, 11, 0.30); stamp(f, thin, 12, -17); frames.push(f); }
{ const f = blank(); flash(f, 9, 0.14); stamp(f, thin, 12, -17, 0.30); frames.push(f); }
for (let i = 4; i < 8; i++) frames.push(blank());
frames.forEach((f, i) => png.save(path.join(OUT, `overlay_storm_strike_f${i}.png`), f));
console.log(`8 frames -> out/landmarks/strike/ (foot ${FOOT.x},${FOOT.y})`);
