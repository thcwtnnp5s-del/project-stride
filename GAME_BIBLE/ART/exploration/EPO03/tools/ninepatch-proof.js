// ninepatch-proof.js — draw a candidate the way lib/ui/components/pixel_asset.dart
// `_FramePainter` will: four corner blocks once each at integer scale, four edge
// strips TILED between them, last tile clipped, interior never drawn.
//
// This is the only check that can fail the way a real frame fails. A symmetric
// band measurement says the inset is representable; it says nothing about
// whether a corner cap wider than `corner` gets tiled across the edge, which is
// the defect that made FMPO02's `modal_128` unusable and is invisible in the
// source PNG.
//
//   node ninepatch-proof.js <png> --corner 26 --band 19 --scale 1 --w 361 --h 200 --out <file>
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const a = process.argv.slice(2);
const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
const n = Number(arg('--corner', 16));
const s = Number(arg('--scale', 1));
const W = Number(arg('--w', 361));
const H = Number(arg('--h', 200));
const out = arg('--out');
const src = png.loadAny(a[0]);
const iw = src.width; const ih = src.height;
if (iw <= 2 * n || ih <= 2 * n) { console.error('corner too large for the canvas'); process.exit(1); }

const dst = new png.Raster(W, H);
png.fill(dst, [0x20, 0x1c, 0x17, 255]);                 // surfaceCard, the interior the panel paints
const c = n * s;
const put = (sub, dx, dy) => png.blit(dst, sub, dx, dy);
const S = (x, y, w, h) => png.scale(png.crop(src, x, y, w, h), s);

put(S(0, 0, n, n), 0, 0);
put(S(iw - n, 0, n, n), W - c, 0);
put(S(0, ih - n, n, n), 0, H - c);
put(S(iw - n, ih - n, n, n), W - c, H - c);

const stripW = (iw - 2 * n) * s; const stripH = (ih - 2 * n) * s;
for (let x = c; x < W - c; x += stripW) {
  const w = Math.min(stripW, W - c - x);
  const srcW = Math.max(1, Math.round((w / s)));
  put(S(n, 0, srcW, n), x, 0);
  put(S(n, ih - n, srcW, n), x, H - c);
}
for (let y = c; y < H - c; y += stripH) {
  const h = Math.min(stripH, H - c - y);
  const srcH = Math.max(1, Math.round((h / s)));
  put(S(0, n, n, srcH), 0, y);
  put(S(iw - n, n, n, srcH), W - c, y);
}
png.save(out, dst);
console.log(`${out}  ${W}x${H}  corner ${n} band ${arg('--band', '?')} scale ${s}`
  + `  -> ${Math.ceil((W - 2 * c) / stripW)} h-repeats, ${Math.ceil((H - 2 * c) / stripH)} v-repeats`);
