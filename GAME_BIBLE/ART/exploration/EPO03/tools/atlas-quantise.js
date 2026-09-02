// FMPO02 WORLD_FIX — deterministic palette remap of one region generation.
//
// FINAL-04 #1: N2 shipped in the wrong DRAWING DIALECT. Its geography is
// right and its neighbour N1 is right, but N2 is airbrushed — smooth gradient
// drifts, anti-aliased peaks, no cel bands, no pixel staircase — while N1
// beside it is flat cel bands with hard one-pixel steps. Measured: N1's eight
// most frequent colours cover 32.5% of its rect, N2's cover 15.6%.
//
// This is the cheap deterministic answer tried BEFORE spending a re-roll.
// A-2 permits it: nothing is invented and nothing is averaged — every output
// pixel is replaced by a colour that already exists in the accepted N1
// composite, chosen as the nearest palette entry. No dithering: a dither
// would put two colours where the generation put one and read as noise, which
// is the exact artefact the round is removing.
//
// NOTE FOR THE RECORD: an earlier round tried `reduce_colors` (the PixelLab
// service call) on N2 roll 1 with a 256-swatch palette and concluded palette
// work could not fix the softness. 256 swatches is not a quantisation — it is
// a no-op on an image carrying 15,200 colours. This tool builds a small
// (~30 entry) palette from the ACCEPTED NEIGHBOUR and is a different
// experiment; it may still fail, and the caller must judge it by eye.
//
// Palette construction: colours of the source rect in frequency order, each
// accepted only if it is at least `--spread` away (luma-weighted RGB) from
// every colour already accepted. Frequency-ordered so the palette is the
// neighbour's real value ladder; spread-gated so it is a ladder rather than
// thirty shades of the same white.
//
// Usage:
//   node atlas-quantise.js <regionId> [--spread N] [--in f] [--out f]
//                          [--src-rect x0,y0,x1,y1] [--rect-only]
// Defaults: source rect = N1's authored rect (0,0)-(252,272) of the current
// atlas_base.png; input/output = out/atlas/<id>.png.
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.join(ROOT, '..', '..', '..', '..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));

// Luma-weighted squared distance. Value separation is what a cel palette is
// about, so brightness is weighted the way the eye weights it.
const WR = 0.30, WG = 0.59, WB = 0.11;
const dist2 = (r1, g1, b1, r2, g2, b2) => {
  const dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return WR * dr * dr + WG * dg * dg + WB * db * db;
};

/** Frequency-ordered, spread-gated palette from a rect of a raster. */
function buildPalette(raster, [x0, y0, x1, y1], spread) {
  const counts = new Map();
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] === 0) continue;
      const k = (raster.data[i] << 16) | (raster.data[i + 1] << 8) | raster.data[i + 2];
      counts.set(k, (counts.get(k) || 0) + 1);
    }
  }
  const ordered = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  const pal = [];
  const gate = spread * spread;
  for (const [k, n] of ordered) {
    const r = (k >> 16) & 255, g = (k >> 8) & 255, b = k & 255;
    let ok = true;
    for (const p of pal) {
      if (dist2(r, g, b, p[0], p[1], p[2]) < gate) { ok = false; break; }
    }
    if (ok) pal.push([r, g, b, n]);
  }
  return pal;
}

/** Snap every opaque pixel of `raster` to its nearest palette entry. */
function remap(raster, pal, rect) {
  const [x0, y0, x1, y1] = rect
    || [0, 0, raster.width, raster.height];
  let changed = 0;
  const cache = new Map();
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] === 0) continue;
      const r = raster.data[i], g = raster.data[i + 1], b = raster.data[i + 2];
      const k = (r << 16) | (g << 8) | b;
      let hit = cache.get(k);
      if (hit === undefined) {
        let best = 0, bestD = Infinity;
        for (let p = 0; p < pal.length; p++) {
          const d = dist2(r, g, b, pal[p][0], pal[p][1], pal[p][2]);
          if (d < bestD) { bestD = d; best = p; }
        }
        hit = best;
        cache.set(k, hit);
      }
      const p = pal[hit];
      if (p[0] !== r || p[1] !== g || p[2] !== b) changed++;
      raster.data[i] = p[0]; raster.data[i + 1] = p[1]; raster.data[i + 2] = p[2];
    }
  }
  return changed;
}

module.exports = { buildPalette, remap, dist2 };

if (require.main === module) {
  const argv = process.argv.slice(2);
  const id = argv[0];
  const flag = (name, def) => {
    const i = argv.indexOf(`--${name}`);
    return i < 0 ? def : argv[i + 1];
  };
  const spread = Number(flag('spread', 18));
  const inFile = flag('in', path.join(ROOT, 'out', 'atlas', `${id}.png`));
  const outFile = flag('out', path.join(ROOT, 'out', 'atlas', `${id}.png`));
  const srcRect = flag('src-rect', '0,0,252,272').split(',').map(Number);
  const rectOnly = argv.includes('--rect-only');

  const paletteSrc = flag('palette-src',
    path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
  const atlas = png.load(paletteSrc);
  const pal = buildPalette(atlas, srcRect, spread);
  console.log(`palette: ${pal.length} entries from ${path.basename(paletteSrc)} ` +
    `${srcRect[0]}-${srcRect[2]} x ${srcRect[1]}-${srcRect[3]} (spread ${spread})`);
  console.log('  ' + pal.slice(0, 40).map(
    (p) => '#' + [p[0], p[1], p[2]].map((v) => v.toString(16).padStart(2, '0')).join(''),
  ).join(' '));

  const raster = png.load(inFile);
  let rect = null;
  if (rectOnly) {
    const cfg = JSON.parse(fs.readFileSync(
      path.join(ROOT, 'src', 'atlas', 'regions.json'), 'utf8'));
    const region = cfg.regions.find((r) => r.id === id);
    if (!region) throw new Error(`unknown region ${id}`);
    const ip = region.inpaint;
    rect = [ip.x, ip.y, Math.min(raster.width, ip.x + ip.w),
      Math.min(raster.height, ip.y + ip.h)];
    console.log(`  remapping the inpaint rect only: (${rect[0]},${rect[1]})..(${rect[2]},${rect[3]})`);
  }
  const changed = remap(raster, pal, rect);
  png.save(outFile, raster);
  console.log(`${inFile} -> ${outFile}: ${changed} px remapped`);
}
