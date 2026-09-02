// EPO03 LANDMARKS — assemble `overlay_fae_court` (112x80, 16 f, 220 ms,
// loops 3, gap 14 s) from the accepted 4-frame fairy wingbeat cut.
//
// DIR-03: five to seven fairies, 6-10 px winged silhouettes with a 2-3 px warm
// glow, on arcs converging on the castle; 1-px trails fading over three
// frames; frames 10-15 a gathering pulse. The castle stands at atlas
// (335,452); with the overlay's top-left at (300,400) that is local (35,52).
//
// A-2: every pixel placed is a pixel of PixelLab's own fairy sprite. A trail
// mark is the fairy's own brightest glow pixel, re-placed — nothing is drawn,
// tinted or averaged. Positions are a closed-form function of frame index, so
// the sheet a review saw is the sheet that ships.
//
//   node fairy-arcs.js
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'out', 'landmarks', 'faecourt');
fs.mkdirSync(OUT, { recursive: true });

const W = 112, H = 80, F = 16;
const CASTLE = { x: 35, y: 52 };
// The wingbeat: frames 1..4 of the animate_image result (frame 0 is the input
// still, which frame 1 repeats).
const BEAT = [1, 2, 3, 4].map((i) =>
  png.load(path.join(ROOT, 'out', 'landmarks', `fairy_cut_f${i}.png`)));
const SW = BEAT[0].width, SH = BEAT[0].height;

/** The sprite's brightest opaque pixel — the glow ink a trail is made of. */
function glowInk(r) {
  let best = null, lum = -1;
  for (let y = 0; y < r.height; y++) for (let x = 0; x < r.width; x++) {
    const i = r.idx(x, y);
    if (r.data[i + 3] === 0) continue;
    const l = r.data[i] * 2 + r.data[i + 1] * 3 + r.data[i + 2];
    if (l > lum) { lum = l; best = [r.data[i], r.data[i + 1], r.data[i + 2], 255]; }
  }
  return best;
}
const INK = glowInk(BEAT[0]);

// Seven fairies. Each rides an ellipse around the castle: `r` is its radius at
// rest, `rot` where on the ring it starts, `turns` how far round it travels in
// one 16-frame play, `lift` its own height above the pool.
const COURT = [
  { r: 30, rot: 0.05, turns: 0.55, lift: -6, squash: 0.62, phase: 0 },
  { r: 22, rot: 0.38, turns: -0.5, lift: -14, squash: 0.55, phase: 1 },
  { r: 34, rot: 0.62, turns: 0.45, lift: 2, squash: 0.7, phase: 2 },
  { r: 17, rot: 0.85, turns: 0.7, lift: -18, squash: 0.5, phase: 3 },
  { r: 41, rot: 0.22, turns: 0.38, lift: 6, squash: 0.66, phase: 1 },
  { r: 26, rot: 0.71, turns: -0.6, lift: -2, squash: 0.6, phase: 2 },
  { r: 12, rot: 0.47, turns: 0.9, lift: -22, squash: 0.48, phase: 0 },
];

/**
 * Where fairy `c` is at frame `f`.
 *
 * Frames 0-9 are the wide court; 10-15 are the gathering pulse, where every
 * radius closes toward the castle on a smoothstep, so the ring draws in and
 * the castle reads as the thing they are gathering at.
 */
function at(c, f) {
  const t = f / F;
  const g = f < 10 ? 0 : (() => { const u = (f - 10) / 6; return u * u * (3 - 2 * u); })();
  const r = c.r * (1 - 0.45 * g);
  const a = (c.rot + c.turns * t) * Math.PI * 2;
  return {
    x: CASTLE.x + Math.cos(a) * r,
    y: CASTLE.y + Math.sin(a) * r * c.squash + c.lift * (1 - 0.3 * g),
  };
}
function blit(dst, src, px, py) {
  const dx = Math.round(px) - (SW >> 1), dy = Math.round(py) - (SH >> 1);
  for (let y = 0; y < SH; y++) for (let x = 0; x < SW; x++) {
    const si = src.idx(x, y);
    if (src.data[si + 3] === 0) continue;
    const tx = dx + x, ty = dy + y;
    if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
    for (let k = 0; k < 4; k++) dst.data[dst.idx(tx, ty) + k] = src.data[si + k];
  }
}
function dot(dst, px, py) {
  const x = Math.round(px), y = Math.round(py);
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = dst.idx(x, y);
  if (dst.data[i + 3] !== 0) return;      // never over a fairy
  for (let k = 0; k < 4; k++) dst.data[i + k] = INK[k];
}
for (let f = 0; f < F; f++) {
  const frame = new png.Raster(W, H);
  // Bodies first, so a trail can never punch a hole in a wing.
  for (const c of COURT) {
    const p = at(c, f);
    blit(frame, BEAT[(f + c.phase) % BEAT.length], p.x, p.y);
  }
  // Then the trail: the three frames behind each fairy, one glow pixel each.
  for (const c of COURT) {
    for (let b = 1; b <= 3; b++) {
      const p = at(c, (f - b + F) % F);
      if (b === 3 && (f + c.phase) % 2 === 0) continue;   // the oldest mark blinks out
      dot(frame, p.x, p.y);
    }
  }
  png.save(path.join(OUT, `overlay_fae_court_f${f}.png`), frame);
}
console.log(`${F} frames -> out/landmarks/faecourt/ (castle local ${CASTLE.x},${CASTLE.y})`);
