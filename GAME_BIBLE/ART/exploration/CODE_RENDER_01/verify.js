// Project Stride - Code Render 01
// Minimal technical verifier. Deliberately small (RULES.md G-1, MISTAKES.md M-01).
//
// Checks only the five properties the proof must keep true:
//   1. output is an indexed PNG (colour type 3)
//   2. every colour used is a palette entry -- enforced by the format itself
//   3. no anti-aliasing / no blended colours
//   4. the x8 review render is exact nearest-neighbour
//   5. re-rendering is byte-identical
//
// This is not a verification framework and must not grow into one.
//
// Usage: node GAME_BIBLE/ART/exploration/CODE_RENDER_01/verify.js

'use strict';
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');
const { PALETTE } = require('./palette');

const OUT = path.join(__dirname, 'out');
const SCALE = 8;
const NAMES = ['player', 'herb', 'gather_card', 'proof_sheet'];

function decode(file) {
  const b = fs.readFileSync(file);
  let o = 8, w = 0, h = 0, depth = 0, type = -1, plte = 0;
  const idat = [];
  while (o < b.length) {
    const len = b.readUInt32BE(o);
    const t = b.toString('ascii', o + 4, o + 8);
    const d = b.subarray(o + 8, o + 8 + len);
    if (t === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); depth = d[8]; type = d[9]; }
    if (t === 'PLTE') plte = len / 3;
    if (t === 'IDAT') idat.push(d);
    o += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const px = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) {
    if (raw[y * (w + 1)] !== 0) throw new Error(`${file}: unexpected PNG filter`);
    for (let x = 0; x < w; x++) px[y * w + x] = raw[y * (w + 1) + 1 + x];
  }
  return { w, h, depth, type, plte, px };
}

let failures = 0;
function check(label, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  (${detail})` : ''}`);
  if (!ok) failures++;
}

const before = NAMES.flatMap((n) => [`${n}.png`, `${n}_x${SCALE}.png`])
  .map((f) => crypto.createHash('sha256').update(fs.readFileSync(path.join(OUT, f))).digest('hex'));

for (const name of NAMES) {
  const nat = decode(path.join(OUT, `${name}.png`));
  const big = decode(path.join(OUT, `${name}_x${SCALE}.png`));

  check(`${name}: indexed PNG`, nat.type === 3 && nat.depth === 8, `type=${nat.type} depth=${nat.depth}`);
  check(`${name}: palette intact`, nat.plte === PALETTE.length, `${nat.plte} entries`);

  // 3. Every index used must be a real palette entry. An index outside the
  //    PLTE, or a colour that is not in it, cannot be produced -- but an
  //    out-of-range index still would be a bug, so assert it.
  const used = new Set(nat.px);
  check(`${name}: no off-palette index`, [...used].every((i) => i < PALETTE.length), `${used.size} used`);

  // 4. Nearest-neighbour: every SCALE x SCALE block must be one uniform index.
  //    A single blended pixel anywhere would break this, so it doubles as the
  //    anti-aliasing check.
  let off = 0;
  check(`${name}: x${SCALE} dimensions`, big.w === nat.w * SCALE && big.h === nat.h * SCALE, `${big.w}x${big.h}`);
  for (let y = 0; y < nat.h; y++) {
    for (let x = 0; x < nat.w; x++) {
      const v = nat.px[y * nat.w + x];
      for (let dy = 0; dy < SCALE; dy++) {
        for (let dx = 0; dx < SCALE; dx++) {
          if (big.px[(y * SCALE + dy) * big.w + x * SCALE + dx] !== v) off++;
        }
      }
    }
  }
  check(`${name}: exact nearest-neighbour, no blended pixels`, off === 0, `${off} off-grid`);
}

// 5. Determinism: re-run the renderer and compare bytes.
execFileSync(process.execPath, [path.join(__dirname, 'render.js')], { stdio: 'ignore' });
const after = NAMES.flatMap((n) => [`${n}.png`, `${n}_x${SCALE}.png`])
  .map((f) => crypto.createHash('sha256').update(fs.readFileSync(path.join(OUT, f))).digest('hex'));
check('deterministic re-render', before.every((h, i) => h === after[i]), `${before.length} files`);

console.log(failures === 0 ? '\nAll checks passed.' : `\n${failures} check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
