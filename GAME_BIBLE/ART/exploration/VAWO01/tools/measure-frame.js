// measure-frame.js — read a candidate chassis frame and report the numbers the
// production plan fixes, rather than the numbers it looks like it has.
//
// The plan (§3.2) fixes: band 6 src px, corner block 16, corner radius 7,
// repeat period 8. A candidate that misses those is not "close enough" -- the
// landed `PanelSkin` asserts the arithmetic and `PanelSkins._reserve` predicts
// 12 logical px of inset, so a frame with a different band reflows every one of
// ~34 call sites.
//
// Reports, per candidate:
//   * measured band thickness on each of the four runs
//   * corner radius, from the alpha silhouette
//   * whether the centre is filled (expected -- keyed later, A-2)
//   * palette: distinct opaque colours, max luminance vs the #7C7263 ceiling
//   * per-run longitudinal invariance, which is what decides if it can tile
'use strict';

const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const CEILING = [0x7c, 0x72, 0x63];

function lum(r, g, b) {
  const f = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
  return (0.2126 * f(r)) + (0.7152 * f(g)) + (0.0722 * f(b));
}
const CEIL_L = lum(...CEILING);

function px(r, x, y) {
  const i = ((y * r.width) + x) << 2;
  return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]];
}

/** Walk inward from an edge along a scanline until alpha drops to 0. */
function bandAt(r, { from, at }) {
  const n = from === 'top' || from === 'bottom' ? r.height : r.width;
  let run = 0;
  for (let i = 0; i < n; i += 1) {
    const [, , , a] = from === 'top' ? px(r, at, i)
      : from === 'bottom' ? px(r, at, r.height - 1 - i)
        : from === 'left' ? px(r, i, at)
          : px(r, r.width - 1 - i, at);
    if (a === 0) break;
    run += 1;
  }
  return run;
}

function analyse(file) {
  const r = png.loadAny(file);
  const { width: w, height: h } = r;
  const mid = { x: w >> 1, y: h >> 1 };

  // Centre filled?
  const centreAlpha = px(r, mid.x, mid.y)[3];

  // Band: measured at the midpoint of each run, where corners cannot confuse it.
  const band = {
    top: bandAt(r, { from: 'top', at: mid.x }),
    bottom: bandAt(r, { from: 'bottom', at: mid.x }),
    left: bandAt(r, { from: 'left', at: mid.y }),
    right: bandAt(r, { from: 'right', at: mid.y }),
  };

  // Corner radius: how far in from the corner the silhouette first becomes
  // opaque along the diagonal.
  let radius = 0;
  for (let d = 0; d < w; d += 1) { if (px(r, d, d)[3] !== 0) { radius = d; break; } }

  // Palette and ceiling.
  const colours = new Map();
  let maxL = 0; let maxHex = null; let semi = 0;
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const [cr, cg, cb, a] = px(r, x, y);
      if (a > 0 && a < 255) semi += 1;
      if (a !== 255) continue;
      const k = (cr << 16) | (cg << 8) | cb;
      colours.set(k, (colours.get(k) ?? 0) + 1);
      const L = lum(cr, cg, cb);
      if (L > maxL) { maxL = L; maxHex = `#${k.toString(16).padStart(6, '0')}`; }
    }
  }

  // Longitudinal invariance of each run: mean column-to-column (or row-to-row)
  // delta across the run region only, excluding the corner blocks.
  const CORNER = 16;
  const delta = (aX, aY, bX, bY, len, vertical) => {
    let sum = 0; let n = 0;
    for (let k = 0; k < len; k += 1) {
      const p = vertical ? px(r, aX, aY + k) : px(r, aX + k, aY);
      const q = vertical ? px(r, bX, bY + k) : px(r, bX + k, bY);
      if (p[3] === 0 && q[3] === 0) { n += 1; continue; }
      sum += Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) + Math.abs(p[2] - q[2]) + Math.abs(p[3] - q[3]);
      n += 1;
    }
    return n ? sum / (n * 4) : 0;
  };

  const runLen = w - (CORNER * 2);
  const invariance = {};
  // top run: compare adjacent columns over the band depth
  let s = 0;
  for (let x = CORNER; x < CORNER + runLen - 1; x += 1) s += delta(x, 0, x + 1, 0, band.top, true);
  invariance.top = s / (runLen - 1);
  s = 0;
  for (let x = CORNER; x < CORNER + runLen - 1; x += 1) s += delta(x, h - band.bottom, x + 1, h - band.bottom, band.bottom, true);
  invariance.bottom = s / (runLen - 1);
  s = 0;
  for (let y = CORNER; y < CORNER + runLen - 1; y += 1) s += delta(0, y, 0, y + 1, band.left, false);
  invariance.left = s / (runLen - 1);
  s = 0;
  for (let y = CORNER; y < CORNER + runLen - 1; y += 1) s += delta(w - band.right, y, w - band.right, y + 1, band.right, false);
  invariance.right = s / (runLen - 1);

  return { file, w, h, centreAlpha, band, radius, colours: colours.size, maxL, maxHex, semi, invariance };
}

for (const f of process.argv.slice(2)) {
  const a = analyse(f);
  const over = a.maxL > CEIL_L;
  console.log(`\n=== ${path.basename(a.file)} (${a.w}x${a.h}) ===`);
  console.log(`  centre            ${a.centreAlpha === 0 ? 'EMPTY' : `FILLED (alpha ${a.centreAlpha}) -- key it, A-2, no re-roll`}`);
  console.log(`  band  T/B/L/R     ${a.band.top} / ${a.band.bottom} / ${a.band.left} / ${a.band.right}   (plan fixes 6)`);
  console.log(`  corner radius     ${a.radius}   (plan fixes 7)`);
  console.log(`  distinct colours  ${a.colours}`);
  console.log(`  semi-transparent  ${a.semi}   (must be 0)`);
  console.log(`  max luminance     ${a.maxHex} L=${a.maxL.toFixed(4)} vs ceiling ${a.maxL > CEIL_L ? 'OVER' : 'under'} (#7C7263 L=${CEIL_L.toFixed(4)})`);
  console.log('  run invariance (lower = tiles more honestly):');
  for (const k of ['top', 'bottom', 'left', 'right']) {
    console.log(`      ${k.padEnd(7)} ${a.invariance[k].toFixed(2)}`);
  }
  if (over) console.log('  >>> would FAIL art-palette.ceiling as-is');
}
