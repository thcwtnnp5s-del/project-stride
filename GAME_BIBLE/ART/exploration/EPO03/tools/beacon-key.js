// EPO03 LANDMARKS — key `overlay_ice_beacon` (96x96, 10 f, 260 ms, loops 2)
// out of four `edit_image_pixen` passes over the SHIPPED L3 terrain crop.
//
// Each pass is the same 96x96 crop of the bastion with the beacon lit in a
// different sweep position. Subtracting the crop leaves exactly the light the
// model added — so every overlay pixel is a PixelLab pixel (A-2), and the
// terrain underneath is the terrain the atlas already ships, not a repaint.
//
// Frame plan (DIR-03): f0 empty; the crown light swells; the cone sweeps
// L -> C -> R -> C; a cold-white drift sparkle rides on top from f3.
//
//   node beacon-key.js
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const ROOT = path.join(__dirname, '..');
const RAW = path.join(ROOT, 'raw', 'landmarks');
const OUT = path.join(ROOT, 'out', 'landmarks', 'beacon');
fs.mkdirSync(OUT, { recursive: true });
const base = png.load(path.join(ROOT, 'src', 'landmarks', 'beacon_base_96.png'));
const W = base.width, H = base.height;
const THRESH = 70;                      // per-channel sum; below it the model just re-dithered
const hash = (x, y, salt) => {
  let h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791);
  h = (h ^ (h >>> 13)) >>> 0;
  return (h % 1024) / 1024;
};
/** The pixels `file` added to the base, as a transparent raster. */
function key(file) {
  const lit = png.load(path.join(RAW, file));
  const out = new png.Raster(W, H);
  let n = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = base.idx(x, y);
    const d = Math.abs(lit.data[i] - base.data[i]) +
      Math.abs(lit.data[i + 1] - base.data[i + 1]) +
      Math.abs(lit.data[i + 2] - base.data[i + 2]);
    // Light only: the beacon adds brightness. A pixel the model DARKENED is a
    // re-draw of the terrain, not light, and is dropped rather than shipped as
    // a hole in the overlay.
    const brighter = lit.data[i] + lit.data[i + 1] + lit.data[i + 2] >
      base.data[i] + base.data[i + 1] + base.data[i + 2];
    if (d < THRESH || !brighter) continue;
    const oi = out.idx(x, y);
    for (let k = 0; k < 4; k++) out.data[oi + k] = lit.data[i + k];
    out.data[oi + 3] = 255;
    n++;
  }
  // Drop 8-connected components under MIN_MASS: the model re-lights scattered
  // snow crystals all over the crop, which key as one- and two-pixel specks and
  // would ship as noise over terrain the overlay does not mean to touch. Mass,
  // not extremes, decides what stays (M-18).
  const MIN_MASS = 10;
  const seen = new Uint8Array(W * H);
  let dropped = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const k0 = y * W + x;
    if (seen[k0] || out.data[out.idx(x, y) + 3] === 0) continue;
    const stack = [[x, y]], comp = [];
    seen[k0] = 1;
    while (stack.length) {
      const [cx, cy] = stack.pop();
      comp.push([cx, cy]);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = cx + dx, ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        const k = ny * W + nx;
        if (seen[k] || out.data[out.idx(nx, ny) + 3] === 0) continue;
        seen[k] = 1; stack.push([nx, ny]);
      }
    }
    if (comp.length >= MIN_MASS) continue;
    for (const [cx, cy] of comp) { out.data[out.idx(cx, cy) + 3] = 0; dropped++; }
  }
  console.log(`  ${file}: ${n} lit px, ${dropped} speck px dropped`);
  return out;
}
/** A hash-thinned copy: whole pixels kept with probability `p` (A-2, never averaged). */
function thin(src, p, salt) {
  const out = new png.Raster(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = src.idx(x, y);
    if (src.data[i + 3] === 0 || hash(x, y, salt) >= p) continue;
    for (let k = 0; k < 4; k++) out.data[out.idx(x, y) + k] = src.data[i + k];
  }
  return out;
}
function over(dst, src, dx = 0, dy = 0) {
  for (let y = 0; y < src.height; y++) for (let x = 0; x < src.width; x++) {
    const si = src.idx(x, y);
    if (src.data[si + 3] === 0) continue;
    const tx = x + dx, ty = y + dy;
    if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
    for (let k = 0; k < 4; k++) dst.data[dst.idx(tx, ty) + k] = src.data[si + k];
  }
  return dst;
}
const dim = key('beacon_dim.png');
const left = key('beacon_far_left.png');
const centre = key('beacon_down.png');
const right = key('beacon_right.png');
const sparkle = png.load(path.join(RAW, 'sparkle_A.png'));
// 10 frames: 0 dark, the crown swells, the cone sweeps L -> C -> R -> C.
// A cone is never hash-thinned: half a cone reads as a checkerboard, not as a
// dimmer light (measured on the first assembly). Each frame carries ONE whole
// keyed sweep; the repeats are told apart by the sparkle, which drifts.
const plan = [
  [null, 0],               // f0 empty — the beacon is dark between sweeps
  [dim, 0],                // the crown lights
  [left, 0],               // the cone opens to the left
  [left, 1],
  [centre, 1],
  [centre, 2],
  [right, 2],
  [right, 3],
  [centre, 3],
  [dim, 0],                // and closes back to the crown
];
plan.forEach(([src, spark], i) => {
  let f = new png.Raster(W, H);
  if (src) f = over(f, src);
  if (spark) {
    // The sparkle tile drifts NW->SE across the crown ledge; whole pixels only.
    over(f, thin(sparkle, 0.5, 170 + i), 40 + spark * 7, 8 + spark * 5);
  }
  png.save(path.join(OUT, `overlay_ice_beacon_f${i}.png`), f);
});
console.log(`10 frames -> out/landmarks/beacon/`);
