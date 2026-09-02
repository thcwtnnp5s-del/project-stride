// ramp-png.js — emit a tiny N x 1 (or N x H) PNG holding a palette ramp.
//
// PixelLab's `color_image_base64` reads ONLY the colours of the image it is
// given; size is irrelevant. A 5x1 PNG is ~80 bytes, so it fits inline under
// the ~5 KB base64 ceiling in PRODUCTION_RULES with room to spare, which means
// the anchor does not have to be committed and pushed first.
//
// Usage:
//   node ramp-png.js <out.png> <#hex> <#hex> ...        # writes + prints base64
//   node ramp-png.js --b64 <out.png> ...                # prints base64 only
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const args = process.argv.slice(2).filter((a) => a !== '--b64');
const out = args[0];
const hexes = args.slice(1).map((h) => h.replace('#', ''));
if (!out || !hexes.length) { console.error('usage: node ramp-png.js <out.png> <#hex>...'); process.exit(2); }

const r = new png.Raster(hexes.length, 1);
hexes.forEach((h, i) => {
  const v = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  const o = i << 2;
  r.data[o] = v[0]; r.data[o + 1] = v[1]; r.data[o + 2] = v[2]; r.data[o + 3] = 255;
});
fs.mkdirSync(path.dirname(out), { recursive: true });
png.save(out, r);
const b64 = fs.readFileSync(out).toString('base64');
console.log(`${out} ${r.width}x1 ${fs.statSync(out).size}B`);
console.log(b64);
