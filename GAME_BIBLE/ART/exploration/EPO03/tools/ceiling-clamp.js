// ceiling-clamp.js — bring the pixels that out-shine the words down under the
// `#7C7263` ceiling, and change nothing else.
//
// This is the operation VAWO01 used on the accepted `chassis_64` ("a ceiling
// clamp moving 5 colours / 208 px — the model's near-white stitch — down onto
// the ramp"), written down so the next asset does not re-derive it. It is
// deterministic and per-colour (A-2): it invents no pixel, moves no pixel, and
// draws nothing. A colour over the ceiling is rescaled in LINEAR light until it
// sits at the ceiling, keeping its hue and its chroma ratios exactly; a colour
// under the ceiling is untouched.
//
// Why rescale rather than snap to the ramp's brightest ink: snapping collapses
// every over-ceiling tone onto ONE value, which turns a lit stitch into a flat
// dash and loses the thread's own shading. Rescaling preserves the ordering
// between two bright tones, so the stitch still reads as a stitch — only
// dimmer, which is the whole point of a ceiling.
//
//   node ceiling-clamp.js <in.png> --out <file.png> [--headroom 0.98]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const a = process.argv.slice(2);
const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
const out = arg('--out');
// Land just under the ceiling, not exactly on it: the guard is a strict
// comparison and floating point at the boundary is not worth arguing with.
const headroom = Number(arg('--headroom', 0.98));
const target = C.CEILING_L * headroom;

const r = png.loadAny(a[0]);
const lin = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
const enc = (v) => {
  const s = v <= 0.0031308 ? v * 12.92 : (1.055 * Math.pow(v, 1 / 2.4)) - 0.055;
  return Math.max(0, Math.min(255, Math.round(s * 255)));
};

const moved = new Map();
let px = 0;
for (let y = 0; y < r.height; y += 1) {
  for (let x = 0; x < r.width; x += 1) {
    const i = ((y * r.width) + x) << 2;
    if (r.data[i + 3] !== 255) continue;
    const before = C.relLum(r.data[i], r.data[i + 1], r.data[i + 2]);
    if (before <= C.CEILING_L) continue;
    const from = C.hex(r.data[i], r.data[i + 1], r.data[i + 2]);
    const k = target / before;             // one scalar in linear light: hue and chroma ratios survive
    for (let c = 0; c < 3; c += 1) r.data[i + c] = enc(lin(r.data[i + c]) * k);
    moved.set(from, C.hex(r.data[i], r.data[i + 1], r.data[i + 2]));
    px += 1;
  }
}

let maxL = 0; let maxHex = '';
for (let i = 0; i < r.data.length; i += 4) {
  if (r.data[i + 3] !== 255) continue;
  const L = C.relLum(r.data[i], r.data[i + 1], r.data[i + 2]);
  if (L > maxL) { maxL = L; maxHex = C.hex(r.data[i], r.data[i + 1], r.data[i + 2]); }
}
console.log(`${path.basename(a[0])}  ${r.width}x${r.height}`);
console.log(`  clamped        ${moved.size} colour(s) / ${px} px onto L<=${target.toFixed(4)}`);
for (const [f, t] of moved) console.log(`                 ${f} -> ${t}`);
console.log(`  max luminance  ${maxHex} L=${maxL.toFixed(4)}  ${maxL > C.CEILING_L ? 'STILL OVER' : 'under ceiling'}`);
if (out) { fs.mkdirSync(path.dirname(out), { recursive: true }); png.save(out, r); console.log(`  wrote          ${out}`); }
process.exit(maxL > C.CEILING_L ? 1 : 0);
