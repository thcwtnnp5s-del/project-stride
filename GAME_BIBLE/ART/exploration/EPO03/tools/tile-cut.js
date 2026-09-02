// tile-cut.js — cut the best-wrapping W x H tile out of a generated strip.
//
// This is production plan section 3.5 clause 1 -- "deterministic window search"
// -- generalised from a column scan to a 2-D one, and it is what turns a 64x16
// leather welt into the 8x4 tile `nav_welt` actually ships. Every candidate
// window is scored on the join it will make with its own repeat, on both axes at
// once, and the quietest wins. Ties go to the window with the most internal
// variation, so a dead patch cannot win by having nothing to join.
//
// Usage:
//   node tile-cut.js <in.png> --w 8 --h 4 --out <file.png> [--band-only]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function lineDelta(r, axis, i, j) {
  const across = axis === 'h' ? r.height : r.width;
  let sum = 0;
  for (let k = 0; k < across; k += 1) {
    const a = axis === 'h' ? ((k * r.width) + i) << 2 : ((i * r.width) + k) << 2;
    const b = axis === 'h' ? ((k * r.width) + j) << 2 : ((j * r.width) + k) << 2;
    if (r.data[a + 3] === 0 && r.data[b + 3] === 0) continue;
    sum += Math.abs(r.data[a] - r.data[b]) + Math.abs(r.data[a + 1] - r.data[b + 1])
      + Math.abs(r.data[a + 2] - r.data[b + 2]) + Math.abs(r.data[a + 3] - r.data[b + 3]);
  }
  return sum / (across * 4);
}

function score(t) {
  let s = 0; let interior = 0;
  for (const axis of ['h', 'v']) {
    const along = axis === 'h' ? t.width : t.height;
    s += lineDelta(t, axis, along - 1, 0);
    let n = 0; for (let i = 0; i + 1 < along; i += 1) n += lineDelta(t, axis, i, i + 1);
    interior += n / Math.max(1, along - 1);
  }
  return { join: s, interior };
}

function main() {
  const a = process.argv.slice(2);
  const file = a[0];
  const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
  const w = Number(arg('--w', 8)); const h = Number(arg('--h', 4));
  const out = arg('--out');

  const src = png.loadAny(file);
  const all = [];
  for (let y = 0; y + h <= src.height; y += 1) {
    for (let x = 0; x + w <= src.width; x += 1) {
      const t = png.crop(src, x, y, w, h);
      // A tile that is part transparent is not a tile: nav_welt and header_shelf
      // are drawn under a bar and a header, and a hole in either shows the page.
      let opaque = true;
      for (let k = 3; k < t.data.length; k += 4) if (t.data[k] !== 255) { opaque = false; break; }
      if (!opaque) continue;
      all.push({ x, y, t, s: score(t) });
    }
  }
  if (!all.length) { console.error('no fully opaque ' + w + 'x' + h + ' window'); process.exit(1); }

  // Material before join, for the reason the surface batch learned the hard way:
  // the quietest join in any strip belongs to its flattest window, so an
  // unconstrained minimum returns a single flat colour and calls it a shelf.
  // Keep the half of the windows carrying the most material, then take the best
  // join among those.
  const interiors = all.map((k) => k.s.interior).sort((p, q) => p - q);
  const floor = interiors[interiors.length >> 1];
  const pool = all.filter((k) => k.s.interior >= floor);
  pool.sort((p, q) => (p.s.join - q.s.join) || (q.s.interior - p.s.interior));
  const best = pool[0];

  let teal = 0; let over = 0; let maxL = 0; let maxHex = '';
  const cols = new Set();
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const px = P(best.t, x, y);
      cols.add(C.hex(px[0], px[1], px[2]));
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }

  console.log(path.basename(file) + '  ' + src.width + 'x' + src.height + ' -> ' + w + 'x' + h);
  console.log('  window         (' + best.x + ',' + best.y + ')  join ' + best.s.join.toFixed(3)
    + '  interior ' + best.s.interior.toFixed(3));
  console.log('  colours        ' + cols.size + '  ' + [...cols].join(' '));
  console.log('  max luminance  ' + maxHex + ' L=' + maxL.toFixed(4) + '  ' + (over ? 'OVER CEILING' : 'under ceiling'));
  console.log('  guards         teal ' + teal + '  semi-alpha 0  over-ceiling ' + over
    + '  ' + (teal + over === 0 ? 'clean' : 'VIOLATION'));

  if (out) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    png.save(out, best.t);
    console.log('  wrote          ' + out);
  }
  process.exit(teal + over === 0 ? 0 : 1);
}
main();
