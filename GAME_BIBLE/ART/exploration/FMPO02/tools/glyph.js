// glyph.js — a 16x16 pixen sprite down to a shipped 14x14 nav glyph in the
// chassis's own measured ramp.
//
// Why 16 and not 14: PixelLab cannot author 14x14. pixflux needs a total area of
// at least 32x32 = 1024 px, so its smallest square is 32x32; pixen goes smaller
// but only in multiples of four, so 16x16 is the smallest square either model
// will draw. 14 is neither. The glyph is therefore authored at 16, cropped to
// its own content, and centred in 14x14 -- a crop, never a rescale.
//
// Why remap: pixen takes no palette anchor (`color_image` is a pixflux
// parameter), so it returns whatever colours it likes -- these came back with
// bright orange, yellow and white in them. The production plan section 5 names
// the fix and calls it structural rather than disciplinary: "a deterministic
// index remap of every later asset onto the accepted chassis ramp". Section 6
// adds that the ramp to use is the MEASURED ramp of the accepted A-1 master,
// not the five hexes it proposes -- so the ramp here is read out of
// assets/ui/v1/frame/chassis_64.png at load time, by luminance percentile over
// its own opaque pixels. Change the chassis and this follows it.
//
// Usage:
//   node glyph.js <in.png> --out <file.png> [--size 14] [--ramp-src <chassis.png>]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const ROOT = path.resolve(__dirname, '../../../../..');
const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

/**
 * Five inks read out of the accepted chassis, at luminance percentiles over its
 * own opaque pixel population.
 *
 * Percentiles rather than "the five most common colours": the chassis carries 49
 * distinct inks and its most common by a wide margin is the outline, so a
 * frequency pick would return five near-blacks and the glyphs would be
 * invisible. Percentiles walk the ladder the artist actually drew.
 */
function measuredRamp(file) {
  const r = png.loadAny(file);
  const ls = [];
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      ls.push({ L: C.lstar(px[0], px[1], px[2]), rgb: [px[0], px[1], px[2]] });
    }
  }
  ls.sort((a, b) => a.L - b.L);
  const at = (p) => ls[Math.min(ls.length - 1, Math.floor(ls.length * p))];
  const picks = [0.04, 0.30, 0.62, 0.86, 0.985].map(at);
  // Dedupe by hex, keeping order, so a flat chassis cannot collapse the ladder.
  const out = []; const seen = new Set();
  for (const p of picks) {
    const h = C.hex(...p.rgb);
    if (!seen.has(h)) { seen.add(h); out.push({ hex: h, rgb: p.rgb, L: p.L }); }
  }
  return out;
}

function cropToContent(r) {
  let x0 = r.width; let y0 = r.height; let x1 = -1; let y1 = -1;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      if (P(r, x, y)[3] !== 0) {
        if (x < x0) x0 = x; if (x > x1) x1 = x;
        if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) throw new Error('fully transparent');
  return { box: [x0, y0, x1 - x0 + 1, y1 - y0 + 1], raster: png.crop(r, x0, y0, x1 - x0 + 1, y1 - y0 + 1) };
}

/** Hard alpha: P-1 allows 0 and 255 and nothing between. */
function hardAlpha(r) {
  let n = 0;
  for (let i = 3; i < r.data.length; i += 4) {
    if (r.data[i] > 0 && r.data[i] < 255) { r.data[i] = r.data[i] >= 128 ? 255 : 0; n += 1; }
  }
  return n;
}

/** Rank the distinct inks by luminance, spread them across the ramp. */
function remap(r, inks) {
  const pop = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const k = (px[0] << 16) | (px[1] << 8) | px[2];
      pop.set(k, (pop.get(k) ?? 0) + 1);
    }
  }
  const total = [...pop.values()].reduce((a, b) => a + b, 0);
  const floor = Math.max(1, Math.round(total * 0.01));
  const steps = [...pop.entries()].filter(([, n]) => n >= floor).map(([k]) => k)
    .sort((a, b) => C.lstar((a >> 16) & 255, (a >> 8) & 255, a & 255)
      - C.lstar((b >> 16) & 255, (b >> 8) & 255, b & 255));
  if (!steps.length) return 0;
  const assign = new Map();
  steps.forEach((k, i) => {
    const idx = steps.length === 1 ? 0 : Math.round((i / (steps.length - 1)) * (inks.length - 1));
    assign.set(k, inks[idx].rgb);
  });
  const stepL = steps.map((k) => C.lstar((k >> 16) & 255, (k >> 8) & 255, k & 255));
  const nearest = (L) => {
    let best = 0; let bd = Infinity;
    for (let i = 0; i < stepL.length; i += 1) { const d = Math.abs(stepL[i] - L); if (d < bd) { bd = d; best = i; } }
    return assign.get(steps[best]);
  };
  let changed = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const k = (r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2];
      const to = assign.get(k) ?? nearest(C.lstar(r.data[i], r.data[i + 1], r.data[i + 2]));
      if (r.data[i] !== to[0] || r.data[i + 1] !== to[1] || r.data[i + 2] !== to[2]) changed += 1;
      r.data[i] = to[0]; r.data[i + 1] = to[1]; r.data[i + 2] = to[2];
    }
  }
  return changed;
}

function main() {
  const a = process.argv.slice(2);
  const file = a[0];
  const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
  const size = Number(arg('--size', 14));
  const out = arg('--out');
  const rampSrc = arg('--ramp-src', path.join(ROOT, 'assets/ui/v1/frame/chassis_64.png'));

  const inks = measuredRamp(rampSrc);
  const src = png.loadAny(file);
  const semi = hardAlpha(src);
  const { box, raster } = cropToContent(src);

  const fits = raster.width <= size && raster.height <= size;
  let body = raster;
  if (!fits) {
    // Trim symmetrically rather than rescale: A-2 permits a crop and forbids a
    // resample, and one lost outline pixel is a smaller lie than a resampled
    // sprite.
    const dx = Math.max(0, raster.width - size); const dy = Math.max(0, raster.height - size);
    body = png.crop(raster, dx >> 1, dy >> 1, Math.min(size, raster.width), Math.min(size, raster.height));
  }

  const glyph = new png.Raster(size, size);
  png.blit(glyph, body, (size - body.width) >> 1, (size - body.height) >> 1);
  const changed = remap(glyph, inks);

  let teal = 0; let over = 0; let semiOut = 0; let maxL = 0; let maxHex = '';
  const cols = new Set();
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const px = P(glyph, x, y);
      if (px[3] > 0 && px[3] < 255) semiOut += 1;
      if (px[3] !== 255) continue;
      cols.add(C.hex(px[0], px[1], px[2]));
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }

  console.log(path.basename(file) + '  ' + src.width + 'x' + src.height + ' -> ' + size + 'x' + size);
  console.log('  ramp           ' + inks.map((k) => k.hex).join(' '));
  console.log('  content        ' + box[2] + 'x' + box[3] + (fits ? ' fits' : '  TRIMMED to fit'));
  console.log('  alpha          ' + semi + ' semi-transparent px hardened; ' + semiOut + ' left');
  console.log('  remap          ' + changed + ' px moved, ' + cols.size + ' colours out');
  console.log('  max luminance  ' + maxHex + ' L=' + maxL.toFixed(4) + '  ' + (over ? 'OVER CEILING' : 'under ceiling'));
  console.log('  guards         teal ' + teal + '  semi-alpha ' + semiOut + '  over-ceiling ' + over
    + '  ' + (teal + semiOut + over === 0 ? 'clean' : 'VIOLATION'));

  if (out) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    png.save(out, glyph);
    console.log('  wrote          ' + out);
  }
  process.exit(teal + semiOut + over === 0 ? 0 : 1);
}
main();
