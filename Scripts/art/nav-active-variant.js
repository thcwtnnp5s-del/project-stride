// Derives the active (selected) variant of a navigation glyph.
//
//   node Scripts/art/nav-active-variant.js [--check]
//
// ## The problem
//
// Three of the six tab glyphs shipped with a `_hi` variant, because only three
// tabs could be selected. Enabling World needs a fourth, and the generator that
// authored the set — `WALKSCAPE_PIVOT_01/UI_EXPLORATION_02/gen_assets.js` —
// cannot run here: it requires `pngjs`, and nothing in this repository installs
// it.
//
// ## What the variant actually is
//
// Measured rather than guessed. Every `nav_*.png` shares one master palette, and
// each `_hi` file has a **byte-identical PLTE** to its base. The difference is
// entirely in the pixel indices: the active variant recolours the glyph by
// pointing each pixel at a brighter entry of the same palette.
//
// So the transform is an **index → index remap**, and it is recoverable: read
// the three existing pairs, and every index that maps consistently across all of
// them is the mapping. Applying it to `nav_world.png` produces the fourth
// variant in the same visual language as the other three, rather than a
// brightness filter invented here that would be subtly off.
//
// A remap that the three pairs disagree about is reported and left alone — a
// glyph is 196 pixels and a wrong colour in one is visible.
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.resolve(__dirname, '..', '..');
const UI = path.join(ROOT, 'assets', 'ui', 'v1');

const PAIRS = ['nav_adventure', 'nav_character', 'nav_inventory'];

// The reference pairs stay the three that shipped with a `_hi` variant.
//
// Deliberately not widened to include the ones this script itself produced:
// deriving the mapping from its own output would let a single wrong index
// entrench itself as evidence, and the three originals are the only files whose
// active variant a human actually authored.
const TARGETS = ['nav_world', 'nav_skills', 'nav_craft'];

const checkOnly = process.argv.includes('--check');

// ------------------------------------------------------- indexed PNG access

function readChunks(file) {
  const buf = fs.readFileSync(file);
  const out = [];
  let offset = 8;
  while (offset < buf.length) {
    const length = buf.readUInt32BE(offset);
    out.push({
      type: buf.toString('ascii', offset + 4, offset + 8),
      body: buf.subarray(offset + 8, offset + 8 + length),
    });
    offset += 12 + length;
  }
  return { header: buf.subarray(0, 8), chunks: out };
}

/** Palette indices of an 8-bit colour-type-3 PNG, row-major. */
function readIndices(file) {
  const { chunks } = readChunks(file);
  const ihdr = chunks.find((c) => c.type === 'IHDR').body;
  const width = ihdr.readUInt32BE(0);
  const height = ihdr.readUInt32BE(4);
  if (ihdr[8] !== 8 || ihdr[9] !== 3) {
    throw new Error(`${file}: expected 8-bit palette PNG`);
  }

  const raw = zlib.inflateSync(
    Buffer.concat(chunks.filter((c) => c.type === 'IDAT').map((c) => c.body)),
  );
  const out = Buffer.alloc(width * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (width + 1)];
    const line = raw.subarray(y * (width + 1) + 1, (y + 1) * (width + 1));
    for (let x = 0; x < width; x++) {
      const a = x >= 1 ? out[y * width + x - 1] : 0;
      const b = y > 0 ? out[(y - 1) * width + x] : 0;
      const c = x >= 1 && y > 0 ? out[(y - 1) * width + x - 1] : 0;
      let value = line[x];
      switch (filter) {
        case 0: break;
        case 1: value += a; break;
        case 2: value += b; break;
        case 3: value += (a + b) >> 1; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          value += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
          break;
        }
        default: throw new Error(`${file}: unknown row filter ${filter}`);
      }
      out[y * width + x] = value & 0xff;
    }
  }
  return { width, height, indices: out };
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
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return c ^ -1;
}

function chunk(type, body) {
  const out = Buffer.alloc(body.length + 12);
  out.writeUInt32BE(body.length, 0);
  out.write(type, 4, 'ascii');
  body.copy(out, 8);
  out.writeInt32BE(crc32(out.subarray(4, 8 + body.length)), 8 + body.length);
  return out;
}

// ------------------------------------------------------------ the remapping

const remap = new Map();
const contested = new Set();

for (const name of PAIRS) {
  const base = readIndices(path.join(UI, `${name}.png`));
  const active = readIndices(path.join(UI, `${name}_hi.png`));
  for (let i = 0; i < base.indices.length; i++) {
    const from = base.indices[i];
    const to = active.indices[i];
    if (remap.has(from) && remap.get(from) !== to) contested.add(from);
    remap.set(from, to);
  }
}

for (const index of contested) remap.delete(index);

// ------------------------------------------------------------------- output

/** The `_hi` bytes [name] should have, derived from the shared remap. */
function activeVariant(name) {
  const source = readIndices(path.join(UI, `${name}.png`));
  const unmapped = new Set();
  const mapped = Buffer.from(source.indices);
  for (let i = 0; i < mapped.length; i++) {
    if (remap.has(mapped[i])) {
      mapped[i] = remap.get(mapped[i]);
    } else {
      unmapped.add(mapped[i]);
    }
  }

  const { chunks } = readChunks(path.join(UI, `${name}.png`));
  const raw = Buffer.alloc(source.height * (source.width + 1));
  for (let y = 0; y < source.height; y++) {
    raw[y * (source.width + 1)] = 0;
    mapped.copy(
      raw,
      y * (source.width + 1) + 1,
      y * source.width,
      (y + 1) * source.width,
    );
  }

  return {
    unmapped,
    bytes: Buffer.concat([
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      chunk('IHDR', chunks.find((c) => c.type === 'IHDR').body),
      chunk('PLTE', chunks.find((c) => c.type === 'PLTE').body),
      chunk('tRNS', chunks.find((c) => c.type === 'tRNS').body),
      chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
      chunk('IEND', Buffer.alloc(0)),
    ]),
  };
}

let stale = 0;
for (const name of TARGETS) {
  const { bytes, unmapped } = activeVariant(name);
  const target = path.join(UI, `${name}_hi.png`);

  if (checkOnly) {
    if (!fs.existsSync(target) || !fs.readFileSync(target).equals(bytes)) {
      console.error(`stale: assets/ui/v1/${name}_hi.png`);
      stale++;
      continue;
    }
    console.log(`nav active variant: assets/ui/v1/${name}_hi.png up to date`);
  } else {
    fs.writeFileSync(target, bytes);
    console.log(
      `nav active variant: wrote assets/ui/v1/${name}_hi.png`
      + ` (${remap.size} palette indices remapped`
      + `${contested.size > 0 ? `, ${contested.size} contested and left alone` : ''}`
      + `${unmapped.size > 0 ? `, ${unmapped.size} unseen in the reference pairs` : ''})`,
    );
  }
}

if (stale > 0) {
  console.error('Run: node Scripts/art/nav-active-variant.js');
  process.exit(1);
}
