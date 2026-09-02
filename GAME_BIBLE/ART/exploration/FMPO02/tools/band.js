// band.js — take a 384-wide master down to the shipped 384x48 chrome band.
//
// Three things happen, in this order, and none of them draws anything:
//
//   1. crop        Choose the 48-row window. The brief says "author at 384x96 and
//                  take the lower 48 by crop if the model composes a scene", and
//                  the model does compose a scene -- at 384x48 it laid out a row
//                  of tiny disconnected icons, at 384x96 it built an actual bench
//                  with tools on it. But the lower 48 of that bench is its LEGS.
//                  So the window is chosen by content instead: the 48 rows
//                  carrying the most ink that is not the backdrop, ties broken
//                  downward so the brief's preference still decides between
//                  equals. `--row N` overrides when a human has looked.
//
//   2. ceiling     Nothing in interface chrome may out-shine `textMuted`
//                  #7C7263 (production plan section 6). Offenders are pulled to
//                  the brightest legal inks IN ORDER of their own luminance, so
//                  the lit face of a hammer stays lighter than the shadowed one.
//                  This is `frame-prep.js`'s clampCeiling, applied to a picture
//                  rather than a frame.
//
//   3. guards      teal / semi-alpha / ceiling, by hand, the same three rules
//                  Scripts/art/check-art-palette.js enforces on the tree.
//
// Usage:
//   node band.js <in.png> --out <file.png> [--row N] [--height 48]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');
const { CHASSIS } = require('./ramps.js');

const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

/** Modal colour = the backdrop the model painted behind the objects. */
function modal(r) {
  const m = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const k = (px[0] << 16) | (px[1] << 8) | px[2];
      m.set(k, (m.get(k) ?? 0) + 1);
    }
  }
  let best = 0; let bn = -1;
  for (const [k, n] of m) if (n > bn) { bn = n; best = k; }
  return [(best >> 16) & 255, (best >> 8) & 255, best & 255];
}

function pickRow(r, h) {
  const bg = modal(r);
  const rowInk = [];
  for (let y = 0; y < r.height; y += 1) {
    let n = 0;
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] === 255 && (px[0] !== bg[0] || px[1] !== bg[1] || px[2] !== bg[2])) n += 1;
    }
    rowInk.push(n);
  }
  let best = 0; let bestSum = -1;
  for (let y = 0; y + h <= r.height; y += 1) {
    let s = 0; for (let d = 0; d < h; d += 1) s += rowInk[y + d];
    if (s >= bestSum) { bestSum = s; best = y; } // >= breaks ties downward
  }
  return { row: best, ink: bestSum, bg };
}

/** frame-prep's ceiling clamp: only offenders move, and they keep their order. */
function clampCeiling(r) {
  const over = new Set();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      if (C.relLum(px[0], px[1], px[2]) > C.CEILING_L) over.add((px[0] << 16) | (px[1] << 8) | px[2]);
    }
  }
  if (!over.size) return { colours: 0, changed: 0 };
  const lumOf = (k) => C.relLum((k >> 16) & 255, (k >> 8) & 255, k & 255);
  const ranked = [...over].sort((a, b) => lumOf(b) - lumOf(a));
  const legal = CHASSIS.map((h) => C.parse(h)).filter((v) => C.relLum(...v) <= C.CEILING_L)
    .sort((a, b) => C.relLum(...b) - C.relLum(...a));
  const assign = new Map();
  ranked.forEach((k, i) => assign.set(k, legal[Math.min(i, legal.length - 1)]));
  let changed = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const to = assign.get((r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2]);
      if (!to) continue;
      r.data[i] = to[0]; r.data[i + 1] = to[1]; r.data[i + 2] = to[2]; changed += 1;
    }
  }
  return { colours: over.size, changed };
}

/**
 * Text-safe exposure — the rule the chrome ceiling does not cover.
 *
 * `#7C7263` is the ceiling because chrome must not out-shine `textMuted`. But a
 * station band is not beside the words, it is UNDER them: ART-02 puts a Cinzel
 * station name straight onto it. The brightest legal chrome ink, `#7C6A4A`,
 * measures 4.26:1 against `textPrimary #F0E7D8` -- under the 4.5:1 ART-13
 * section 1 holds every other surface to, and the bands come back sitting right
 * on it because a lit plank is the biggest thing in the picture.
 *
 * So scale the whole band's LINEAR luminance by one gain until its brightest
 * pixel lands on 4.5:1 (background L <= 0.1403). One gain, applied per channel
 * in linear light: every relationship in the picture is preserved exactly, hue
 * included, and nothing is redrawn -- it is an exposure change, the flattest
 * possible correction, and the alternative (ranking the offenders onto three
 * legal inks) would posterise the plank it is trying to save.
 */
function textSafe(r, target) {
  let max = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const L = C.relLum(px[0], px[1], px[2]); if (L > max) max = L;
    }
  }
  if (max <= target) return { gain: 1, max };
  const gain = target / max;
  const lin = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4; };
  const enc = (v) => {
    const s = v <= 0.0031308 ? v * 12.92 : (1.055 * (v ** (1 / 2.4))) - 0.055;
    return Math.max(0, Math.min(255, Math.round(s * 255)));
  };
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      r.data[i] = enc(lin(r.data[i]) * gain);
      r.data[i + 1] = enc(lin(r.data[i + 1]) * gain);
      r.data[i + 2] = enc(lin(r.data[i + 2]) * gain);
    }
  }
  return { gain, max };
}

function guards(r) {
  let teal = 0; let semi = 0; let over = 0; let maxL = 0; let maxHex = '';
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semi += 1;
      if (px[3] !== 255) continue;
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }
  return { teal, semi, over, maxHex, maxL };
}

function main() {
  const a = process.argv.slice(2);
  const file = a[0];
  const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
  const h = Number(arg('--height', 48));
  const out = arg('--out');

  const src = png.loadAny(file);
  console.log(path.basename(file) + '  ' + src.width + 'x' + src.height);

  let r = src;
  if (src.height > h) {
    const forced = arg('--row', null);
    const pick = pickRow(src, h);
    const row = forced === null ? pick.row : Number(forced);
    console.log('  crop           rows ' + row + '-' + (row + h - 1) + ' of ' + src.height
      + (forced === null ? '  (content-picked, ' + pick.ink + ' non-backdrop px)' : '  (forced)')
      + '  backdrop ' + C.hex(...pick.bg));
    r = png.crop(src, 0, row, src.width, h);
  }

  const pre = guards(r);
  if (a.includes('--textsafe')) {
    const ts = textSafe(r, 0.1403);
    console.log('  text-safe      brightest L=' + ts.max.toFixed(4)
      + (ts.gain === 1 ? ' already <= 0.1403 (4.5:1 vs #F0E7D8)'
        : ' -> gain x' + ts.gain.toFixed(3) + ' so 4.5:1 holds under body text'));
  }
  const cl = clampCeiling(r);
  const post = guards(r);
  console.log('  ceiling clamp  ' + cl.colours + ' colour(s) over #7C7263, ' + cl.changed + ' px pulled down');
  console.log('  max luminance  ' + pre.maxHex + ' -> ' + post.maxHex + ' L=' + post.maxL.toFixed(4)
    + '  ' + (post.over === 0 ? 'under ceiling' : 'STILL OVER'));
  console.log('  guards         teal ' + post.teal + '  semi-alpha ' + post.semi + '  over-ceiling ' + post.over
    + '  ' + (post.teal + post.semi + post.over === 0 ? 'clean' : 'VIOLATION'));

  const cols = new Set();
  for (let y = 0; y < r.height; y += 1) for (let x = 0; x < r.width; x += 1) {
    const px = P(r, x, y); if (px[3] === 255) cols.add(C.hex(px[0], px[1], px[2]));
  }
  console.log('  colours        ' + cols.size);

  if (out) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    png.save(out, r);
    console.log('  wrote          ' + out + ' ' + r.width + 'x' + r.height);
  }
  process.exit(post.teal + post.semi + post.over === 0 ? 0 : 1);
}
main();
