// Project Stride - Code Render 01
// Indexed raster surface + zero-dependency PNG encoder.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Not part of the app build, not referenced
// by any Flutter, Dart, Kotlin, Swift, or CI target.
//
// Every pixel is a PALETTE INDEX in a Uint8Array. There is no drawing API, no
// blending stage, and no float coordinate anywhere, so anti-aliasing is not
// avoided by discipline -- it is unrepresentable. Index 0 is transparent.
//
// Dependencies: none beyond Node's built-in zlib.

'use strict';
const zlib = require('zlib');

// ---------------------------------------------------------------- CRC32 (PNG)
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typed = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(typed));
  return Buffer.concat([len, typed, crc]);
}

// ---------------------------------------------------------------- Surface
class Surface {
  constructor(w, h, fill = 0) {
    this.w = w | 0;
    this.h = h | 0;
    this.px = new Uint8Array(this.w * this.h);
    if (fill) this.px.fill(fill);
  }

  set(x, y, i) {
    x |= 0; y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    this.px[y * this.w + x] = i;
  }

  get(x, y) {
    x |= 0; y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return 0;
    return this.px[y * this.w + x];
  }

  rect(x, y, w, h, i) {
    for (let dy = 0; dy < h; dy++) for (let dx = 0; dx < w; dx++) this.set(x + dx, y + dy, i);
  }

  // Frame outline, one pixel thick.
  frame(x, y, w, h, i) {
    for (let dx = 0; dx < w; dx++) { this.set(x + dx, y, i); this.set(x + dx, y + h - 1, i); }
    for (let dy = 0; dy < h; dy++) { this.set(x, y + dy, i); this.set(x + w - 1, y + dy, i); }
  }

  // Copy another surface in, treating index 0 as transparent.
  blit(src, x, y) {
    for (let sy = 0; sy < src.h; sy++) {
      for (let sx = 0; sx < src.w; sx++) {
        const v = src.px[sy * src.w + sx];
        if (v !== 0) this.set(x + sx, y + sy, v);
      }
    }
  }

  // Nearest-neighbour integer enlargement. Each source pixel becomes an n x n block.
  scale(n) {
    const out = new Surface(this.w * n, this.h * n);
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        const v = this.px[y * this.w + x];
        for (let dy = 0; dy < n; dy++) {
          const row = (y * n + dy) * out.w + x * n;
          for (let dx = 0; dx < n; dx++) out.px[row + dx] = v;
        }
      }
    }
    return out;
  }

  // 8-bit indexed PNG (colour type 3) with a tRNS chunk making index 0 transparent.
  png(palette) {
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(this.w, 0);
    ihdr.writeUInt32BE(this.h, 4);
    ihdr[8] = 8;   // bit depth
    ihdr[9] = 3;   // colour type 3 = indexed; the PLTE *is* the palette
    ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

    const plte = Buffer.alloc(palette.length * 3);
    palette.forEach((c, k) => { plte[k * 3] = c[0]; plte[k * 3 + 1] = c[1]; plte[k * 3 + 2] = c[2]; });

    // Only index 0 is transparent; every other entry is fully opaque.
    const trns = Buffer.alloc(1);
    trns[0] = 0;

    const raw = Buffer.alloc(this.h * (this.w + 1));
    for (let y = 0; y < this.h; y++) {
      raw[y * (this.w + 1)] = 0; // filter type 0 = None, so the bytes stay literal
      Buffer.from(this.px.subarray(y * this.w, (y + 1) * this.w)).copy(raw, y * (this.w + 1) + 1);
    }

    return Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      chunk('IHDR', ihdr),
      chunk('PLTE', plte),
      chunk('tRNS', trns),
      chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]);
  }
}

// ---------------------------------------------------------------- ASCII maps
// Sprites are authored as arrays of equal-length strings, one character per
// pixel, resolved through a legend of character -> palette index. This is how
// the art is actually edited: it is legible, diffable, hand-tunable, and it
// ports to any language without redesigning the artwork.
function fromMap(rows, legend) {
  const w = rows[0].length;
  rows.forEach((r, y) => {
    if (r.length !== w) throw new Error(`row ${y} is ${r.length} wide, expected ${w}`);
  });
  const s = new Surface(w, rows.length);
  rows.forEach((r, y) => {
    for (let x = 0; x < w; x++) {
      const ch = r[x];
      if (ch === '.') continue;              // '.' is transparent
      if (!(ch in legend)) throw new Error(`unknown legend character '${ch}' at ${x},${y}`);
      s.set(x, y, legend[ch]);
    }
  });
  return s;
}

module.exports = { Surface, fromMap };
