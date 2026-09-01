// Minimal RGBA8 PNG read/write, plus the pixel operations the art packaging
// step needs. Node's own `zlib` is the only dependency.
//
// ## Why this exists rather than `pngjs`
//
// The exploration tools under `GAME_BIBLE/ART/exploration/*/tools/` require
// `pngjs`, and nothing in this repository installs it — there is no
// `node_modules` anywhere and `Scripts/tooling/package.json` declares only an
// XML parser. Those tools therefore cannot run on a fresh clone, which is
// exactly the state a future session finds the repository in.
//
// The art packaging step must be reproducible from a clean checkout with no
// network, because the assets it emits are the ones that ship. So it depends on
// the standard library and nothing else.
//
// ## Scope
//
// **Colour type 6 (RGBA), bit depth 8, non-interlaced, only.** Every PixelLab
// output measured is exactly that. A file that is not is rejected loudly rather
// than decoded approximately — a silently mis-decoded palette would produce
// wrong colours in shipped art, and wrong colours in pixel art are not subtle.
'use strict';

const fs = require('fs');
const zlib = require('zlib');

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** An RGBA8 raster. `data` is width * height * 4 bytes, row-major. */
class Raster {
  constructor(width, height, data) {
    this.width = width;
    this.height = height;
    this.data = data ?? Buffer.alloc(width * height * 4);
  }

  /** Byte offset of the pixel at (x, y). */
  idx(x, y) {
    return ((y * this.width) + x) << 2;
  }

  /** Alpha of the pixel at (x, y). Out-of-bounds reads as transparent. */
  alphaAt(x, y) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return 0;
    return this.data[this.idx(x, y) + 3];
  }

  clone() {
    return new Raster(this.width, this.height, Buffer.from(this.data));
  }
}

// ------------------------------------------------------------------- decode

function paethPredictor(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

/** Reads an RGBA8 PNG from disk. Throws on any format this does not handle. */
function load(file) {
  const buf = fs.readFileSync(file);
  if (!buf.subarray(0, 8).equals(SIGNATURE)) {
    throw new Error(`${file}: not a PNG`);
  }

  let width = 0;
  let height = 0;
  const idat = [];
  let offset = 8;

  while (offset < buf.length) {
    const length = buf.readUInt32BE(offset);
    const type = buf.toString('ascii', offset + 4, offset + 8);
    const body = buf.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length; // length + type + data + crc

    if (type === 'IHDR') {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      const depth = body[8];
      const colorType = body[9];
      const interlace = body[12];
      if (depth !== 8 || colorType !== 6 || interlace !== 0) {
        throw new Error(
          `${file}: expected 8-bit RGBA non-interlaced ` +
            `(depth 8, colour type 6, interlace 0), got depth ${depth}, ` +
            `colour type ${colorType}, interlace ${interlace}. ` +
            'Convert it before packaging rather than teaching this decoder ' +
            'to guess.',
        );
      }
    } else if (type === 'IDAT') {
      idat.push(body);
    } else if (type === 'IEND') {
      break;
    }
  }

  if (width === 0 || height === 0) throw new Error(`${file}: no IHDR`);

  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  const out = Buffer.alloc(height * stride);

  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const dst = y * stride;
    const prev = dst - stride;

    for (let x = 0; x < stride; x++) {
      const a = x >= 4 ? out[dst + x - 4] : 0;
      const b = y > 0 ? out[prev + x] : 0;
      const c = x >= 4 && y > 0 ? out[prev + x - 4] : 0;
      let value = line[x];
      switch (filter) {
        case 0: break;
        case 1: value += a; break;
        case 2: value += b; break;
        case 3: value += (a + b) >> 1; break;
        case 4: value += paethPredictor(a, b, c); break;
        default: throw new Error(`${file}: unknown row filter ${filter}`);
      }
      out[dst + x] = value & 0xff;
    }
  }

  return new Raster(width, height, out);
}

/**
 * Read-only decode of any depth-8 non-interlaced PNG into RGBA8.
 *
 * ## Why this exists alongside the strict `load`
 *
 * `load` refuses anything that is not colour type 6, and that strictness is
 * correct for what it serves: `package-art.js` **writes** the art that ships,
 * and a decoder that guesses would put wrong colours into shipped pixel art,
 * where wrong colours are not subtle.
 *
 * A **guard** has the opposite failure mode. `check-art-palette.js` measures
 * every shipped PNG for reserved-teal collisions, stray alpha and luminance
 * ceiling breaches. Thirteen of the 871 shipped files -- `glyph_arrow` and the
 * twelve nav icons -- are colour type 3, palette-indexed. Under `load` alone
 * the guard could not read them, and a guard that silently cannot see 13 files
 * is a guard with a hole exactly where hand-maintained interface art lives.
 *
 * So: `load` stays strict and nothing that writes art changes behaviour. This
 * is additive, and it is for reading only -- it has no `save` counterpart, by
 * design. Round-tripping a palette PNG through here and back out would launder
 * it into RGBA without anyone deciding to, which is how `assets/ui/v1`'s
 * hand-maintained provenance rows would quietly stop describing the files.
 *
 * Supports colour types 0 (grey), 2 (RGB), 3 (palette), 4 (grey+alpha) and
 * 6 (RGBA), at bit depth 8, non-interlaced. `tRNS` transparency is honoured
 * for types 0, 2 and 3.
 */
function loadAny(file) {
  const buf = fs.readFileSync(file);
  if (!buf.subarray(0, 8).equals(SIGNATURE)) {
    throw new Error(`${file}: not a PNG`);
  }

  let width = 0;
  let height = 0;
  let colorType = -1;
  let palette = null;
  let trns = null;
  const idat = [];
  let offset = 8;

  while (offset < buf.length) {
    const length = buf.readUInt32BE(offset);
    const type = buf.toString('ascii', offset + 4, offset + 8);
    const body = buf.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;

    if (type === 'IHDR') {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      const depth = body[8];
      colorType = body[9];
      const interlace = body[12];
      if (depth !== 8 || interlace !== 0) {
        throw new Error(
          `${file}: expected bit depth 8 and no interlacing, got depth ` +
            `${depth}, interlace ${interlace}.`,
        );
      }
      if (![0, 2, 3, 4, 6].includes(colorType)) {
        throw new Error(`${file}: unsupported colour type ${colorType}`);
      }
    } else if (type === 'PLTE') {
      palette = Buffer.from(body);
    } else if (type === 'tRNS') {
      trns = Buffer.from(body);
    } else if (type === 'IDAT') {
      idat.push(body);
    } else if (type === 'IEND') {
      break;
    }
  }

  if (width === 0 || height === 0) throw new Error(`${file}: no IHDR`);
  if (colorType === 3 && palette === null) {
    throw new Error(`${file}: palette colour type with no PLTE chunk`);
  }

  const samples = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
  const stride = width * samples;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const flat = Buffer.alloc(height * stride);

  // Unfilter. Identical to `load`, except the predictor step is the sample
  // width of this colour type rather than a hardcoded 4.
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const dst = y * stride;
    const prev = dst - stride;

    for (let x = 0; x < stride; x++) {
      const a = x >= samples ? flat[dst + x - samples] : 0;
      const b = y > 0 ? flat[prev + x] : 0;
      const c = x >= samples && y > 0 ? flat[prev + x - samples] : 0;
      let value = line[x];
      switch (filter) {
        case 0: break;
        case 1: value += a; break;
        case 2: value += b; break;
        case 3: value += (a + b) >> 1; break;
        case 4: value += paethPredictor(a, b, c); break;
        default: throw new Error(`${file}: unknown row filter ${filter}`);
      }
      flat[dst + x] = value & 0xff;
    }
  }

  // Expand to RGBA8.
  const out = Buffer.alloc(width * height * 4);
  for (let n = 0; n < width * height; n++) {
    const s = n * samples;
    const d = n << 2;
    let r;
    let g;
    let b;
    let alpha = 255;

    switch (colorType) {
      case 0:
        r = flat[s]; g = flat[s]; b = flat[s];
        if (trns && trns.length >= 2 && flat[s] === trns[1]) alpha = 0;
        break;
      case 2:
        r = flat[s]; g = flat[s + 1]; b = flat[s + 2];
        if (trns && trns.length >= 6
            && r === trns[1] && g === trns[3] && b === trns[5]) alpha = 0;
        break;
      case 3: {
        const i = flat[s] * 3;
        if (i + 2 >= palette.length) {
          throw new Error(`${file}: palette index ${flat[s]} out of range`);
        }
        r = palette[i]; g = palette[i + 1]; b = palette[i + 2];
        if (trns && flat[s] < trns.length) alpha = trns[flat[s]];
        break;
      }
      case 4:
        r = flat[s]; g = flat[s]; b = flat[s]; alpha = flat[s + 1];
        break;
      default: // 6
        r = flat[s]; g = flat[s + 1]; b = flat[s + 2]; alpha = flat[s + 3];
        break;
    }

    out[d] = r; out[d + 1] = g; out[d + 2] = b; out[d + 3] = alpha;
  }

  return new Raster(width, height, out);
}

// ------------------------------------------------------------------- encode

function chunk(type, body) {
  const out = Buffer.alloc(body.length + 12);
  out.writeUInt32BE(body.length, 0);
  out.write(type, 4, 'ascii');
  body.copy(out, 8);
  out.writeInt32BE(crc32(out.subarray(4, 8 + body.length)), 8 + body.length);
  return out;
}

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return c ^ -1;
}

/**
 * Writes [raster] to [file] as an RGBA8 PNG.
 *
 * Every row is written with filter 0 (none). Pixel art is flat-coloured and
 * run-heavy, so `deflate` already compresses it well, and an unfiltered file is
 * byte-for-byte reproducible across Node versions — which matters, because
 * these files are committed and a spurious binary diff on every run would make
 * a real art change impossible to spot in review.
 */
function save(file, raster) {
  const stride = raster.width * 4;
  const raw = Buffer.alloc(raster.height * (stride + 1));
  for (let y = 0; y < raster.height; y++) {
    raw[y * (stride + 1)] = 0;
    raster.data.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(raster.width, 0);
  ihdr.writeUInt32BE(raster.height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // colour type: RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  fs.writeFileSync(
    file,
    Buffer.concat([
      SIGNATURE,
      chunk('IHDR', ihdr),
      chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]),
  );
}

// --------------------------------------------------------------- operations

/** Nearest-neighbour integer upscale. Authoring and review boards only. */
function scale(src, n) {
  if (n === 1) return src.clone();
  const out = new Raster(src.width * n, src.height * n);
  for (let y = 0; y < out.height; y++) {
    const sy = (y / n) | 0;
    for (let x = 0; x < out.width; x++) {
      const si = src.idx((x / n) | 0, sy);
      src.data.copy(out.data, out.idx(x, y), si, si + 4);
    }
  }
  return out;
}

/** Source-over composite of [src] onto [dst] at (ox, oy). */
function blit(dst, src, ox, oy) {
  for (let y = 0; y < src.height; y++) {
    const dy = oy + y;
    if (dy < 0 || dy >= dst.height) continue;
    for (let x = 0; x < src.width; x++) {
      const dx = ox + x;
      if (dx < 0 || dx >= dst.width) continue;
      const si = src.idx(x, y);
      const sa = src.data[si + 3] / 255;
      if (sa === 0) continue;
      const di = dst.idx(dx, dy);
      const da = dst.data[di + 3] / 255;
      const oa = sa + da * (1 - sa);
      for (let c = 0; c < 3; c++) {
        dst.data[di + c] = Math.round(
          (src.data[si + c] * sa + dst.data[di + c] * da * (1 - sa)) / oa,
        );
      }
      dst.data[di + 3] = Math.round(oa * 255);
    }
  }
}

/** A rectangular copy. Out-of-bounds source area comes back transparent. */
function crop(src, x0, y0, w, h) {
  const out = new Raster(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const sx = x0 + x;
      const sy = y0 + y;
      if (sx < 0 || sy < 0 || sx >= src.width || sy >= src.height) continue;
      const si = src.idx(sx, sy);
      src.data.copy(out.data, out.idx(x, y), si, si + 4);
    }
  }
  return out;
}

/** Fills [raster] with a flat colour. */
function fill(raster, [r, g, b, a]) {
  for (let i = 0; i < raster.data.length; i += 4) {
    raster.data[i] = r;
    raster.data[i + 1] = g;
    raster.data[i + 2] = b;
    raster.data[i + 3] = a;
  }
  return raster;
}

/**
 * The opaque bounding box of [raster], or null when nothing is opaque.
 *
 * `threshold` is deliberately above zero: PixelLab output carries a few
 * near-transparent edge pixels that are invisible but would widen a box
 * measured at alpha > 0.
 */
function bounds(raster, threshold = 8) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= threshold) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return { left: minX, top: minY, right: maxX, bottom: maxY };
}

/**
 * The **footprint** of a standalone sprite: where it meets the ground.
 *
 * This is not the same as the opaque bounding box, and the difference is the
 * whole point. A walking figure's box includes its head, its pack and any
 * outstretched arm; what casts a contact shadow is the part actually touching
 * the ground. So the span is measured across the lowest [rows] opaque rows
 * only.
 *
 * Returns the contact span in sprite-local pixel coordinates, which is what
 * makes the shadow *derived from the sprite* rather than guessed per scene: a
 * caller cannot give the shadow a width that disagrees with the thing standing
 * on it, because the caller does not supply one.
 */
function footprint(raster, rows = 4) {
  const box = bounds(raster);
  if (box === null) return null;

  let left = Infinity;
  let right = -1;
  for (let y = Math.max(box.top, box.bottom - (rows - 1)); y <= box.bottom; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= 8) continue;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  return { left, right, bottom: box.bottom, width: right - left + 1 };
}

module.exports = {
  Raster,
  blit,
  bounds,
  crop,
  fill,
  footprint,
  load,
  loadAny,
  save,
  scale,
};
