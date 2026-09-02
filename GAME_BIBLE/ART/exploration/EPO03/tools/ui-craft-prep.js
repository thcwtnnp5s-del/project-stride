// ui-craft-prep.js — EPO03 UI-CRAFT's deterministic post-work (A-2): crop,
// alpha snap, chrome ceiling, text-safe exposure, guards, sidecar. Draws
// nothing; every pixel that changes is a clamp or a crop of a PixelLab roll.
//
//   node ui-craft-prep.js <in.png> --out <out.png> --kind <kind> [options]
//
//   --crop x,y,w,h      take a window of the master (source px)
//   --ceiling           chrome: no opaque pixel brighter than textMuted
//                       #7C7263 (offenders ranked onto the chassis ramp, in
//                       their own order — band.js's clampCeiling verbatim)
//   --textsafe [L]      picture under type: one linear-light gain so the
//                       brightest pixel is <= L (default 0.1403 = 4.5:1 under
//                       textPrimary) — band.js's textSafe verbatim
//   --alpha             snap 0<a<255 to 0 or 255 at 128 (integer scaling stays
//                       exact; check-art-palette's alpha rule)
//   --corner N --band N --period N --scale N   geometry, MEASURED by the
//                       author off the PNG and written to the sidecar
//   --note "..."        provenance line
//   --job <id>          the PixelLab job id
//
// Guards mirror FMPO02/tools/ui-package.js: teal (Chebyshev <= 10 of #58D6C0),
// semi (0<a<255), over (L > ceiling), colours, maxHex, maxL, verdict.
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require(path.resolve(__dirname, '../../FMPO02/tools/colour.js'));
const { CHASSIS } = require(path.resolve(__dirname, '../../FMPO02/tools/ramps.js'));

const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function arg(name, dflt) {
  const i = process.argv.indexOf(name);
  if (i < 0) return dflt;
  const v = process.argv[i + 1];
  if (v === undefined || v.startsWith('--')) return true;
  return v;
}

function snapAlpha(r) {
  let n = 0;
  for (let i = 0; i < r.data.length; i += 4) {
    const a = r.data[i + 3];
    if (a === 0 || a === 255) continue;
    n += 1;
    if (a < 128) { r.data[i] = 0; r.data[i + 1] = 0; r.data[i + 2] = 0; r.data[i + 3] = 0; } else r.data[i + 3] = 255;
  }
  return n;
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

/** One linear-light gain so the brightest opaque pixel lands on `target`. */
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
  return { gain: Number(gain.toFixed(4)), max: Number(max.toFixed(4)) };
}

function guards(r, ceilingL) {
  let teal = 0; let semi = 0; let over = 0; let maxL = 0; let maxHex = '';
  const cols = new Set();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semi += 1;
      if (px[3] !== 255) continue;
      cols.add(C.hex(px[0], px[1], px[2]));
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > ceilingL) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }
  return {
    teal, semi, over, colours: cols.size, maxHex, maxL: Number(maxL.toFixed(4)),
    verdict: teal + semi + over === 0 ? 'clean' : 'VIOLATION',
  };
}

const inFile = process.argv[2];
const out = arg('--out');
if (!inFile || !out) { console.error('usage: ui-craft-prep.js <in.png> --out <out.png> --kind <kind> [...]'); process.exit(2); }

let r = png.loadAny(inFile);
const master = path.relative(path.resolve(__dirname, '..'), inFile).replace(/\\/g, '/');
const steps = [];
if (arg('--crop')) {
  const [x, y, w, h] = String(arg('--crop')).split(',').map(Number);
  r = png.crop(r, x, y, w, h);
  steps.push(`crop ${x},${y},${w},${h}`);
}
if (arg('--alpha', false)) steps.push(`alpha snapped ${snapAlpha(r)} px`);
if (arg('--ceiling', false)) { const c = clampCeiling(r); steps.push(`ceiling: ${c.colours} inks over, ${c.changed} px moved`); }
let ceilingL = C.CEILING_L;
if (arg('--textsafe', false) !== false) {
  const t = arg('--textsafe') === true ? 0.1403 : Number(arg('--textsafe'));
  const g = textSafe(r, t); steps.push(`textsafe: gain ${g.gain} (max was ${g.max}) -> L <= ${t}`);
  ceilingL = t;
}
const g = guards(r, ceilingL);
const meta = {
  asset: path.basename(out, '.png'),
  destination: `assets/art/v1/ui/craft/${path.basename(out)}`,
  canvas: [r.width, r.height],
  kind: arg('--kind', 'icon'),
  corner: arg('--corner') ? Number(arg('--corner')) : null,
  band: arg('--band') ? Number(arg('--band')) : null,
  period: arg('--period') ? Number(arg('--period')) : null,
  scale: Number(arg('--scale', 2)),
  master,
  job: arg('--job', null),
  steps,
  ceiling: `L <= ${ceilingL.toFixed(4)}`,
  guards: g,
  note: arg('--note', ''),
};
fs.mkdirSync(path.dirname(out), { recursive: true });
png.save(out, r);
fs.writeFileSync(out.replace(/\.png$/, '.json'), JSON.stringify(meta, null, 2) + '\n');
console.log(`${path.basename(out).padEnd(28)} ${r.width}x${r.height}  ${g.colours} colours  max ${g.maxHex} (${g.maxL})  ${g.verdict}  [${steps.join('; ')}]`);
if (g.verdict !== 'clean') process.exit(1);
