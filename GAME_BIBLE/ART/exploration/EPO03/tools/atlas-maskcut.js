// EPO03 — PROD-WORLD-EAST: NARROW a region's shipping mask (never widen) after
// atlas-mask.js has built it, and write the matching PixelLab inpaint mask.
//
//   (a) Open sea further than `cut.seaMargin` px from any sizeable non-sea body
//       (ice, rock, an islet of >= `cut.minLand` px) is forced to 0: the sea is
//       never authorized, so it stays the deterministic one sea the global
//       conform owns (the FMPO02 N3 lesson; DIR-02 "mask stops at the ice
//       edge"). Ticks and brash smaller than minLand count as sea.
//   (b) Declared identity `cut.holes` ([{x,y,w,h}] in atlas px — the volcano's
//       towers, the watchtower flank, the east-cliff cape) are hard 0 even
//       though `coreAuthor` / `reauthorizes` lifted the tool's own protection.
//
// The PixelLab mask (src/atlas/<id>_inpaint.png, white = paint) is the
// region's `inpaint` rect minus open sea beyond `cut.inpaintMargin` (smaller
// than seaMargin, so the generator's own feather lies inside the shipped
// authorization) minus every hole inflated by `cut.holeInflate` px, so the
// generator keeps the identity pixels byte-identical and nothing it paints
// can be cut in half by the shipping mask.
//
// Pure function of (region geometry, the committed source crop); no
// randomness, no image content from the generation. Run it every time
// atlas-mask.js runs (geometric pass and graded pass alike).
//   node atlas-maskcut.js <regionId> <team>
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const REPO = path.resolve(ROOT, '../../../..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const { isDeep } = require(path.join(ROOT, '..', 'WORLD_ATLAS_COHERENCE_UI_01', 'tools', 'ocean_unify.js'));

const [id, team] = process.argv.slice(2);
if (!id || !team) { console.error('usage: node atlas-maskcut.js <regionId> <team>'); process.exit(2); }
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'atlas', `regions_${team}.json`), 'utf8'));
const region = cfg.regions.find((r) => r.id === id);
if (!region) throw new Error(`unknown region ${id} in regions_${team}.json`);
const cut = region.cut;
if (!cut) { console.log(`${id}: no cut block - nothing to do`); process.exit(0); }
const { w, h } = region;
const seaMargin = cut.seaMargin === undefined ? 24 : cut.seaMargin;
const inpaintMargin = cut.inpaintMargin === undefined ? Math.max(0, seaMargin - 6) : cut.inpaintMargin;
const minLand = cut.minLand === undefined ? 40 : cut.minLand;
const holeInflate = cut.holeInflate === undefined ? 2 : cut.holeInflate;
// (c) EPO03 east, added after E1 rolls 1-2: an optional RIBBON cut. Land (ice)
// further than `cut.landMargin` px from the nearest open water is forced to 0,
// so the authorization becomes a band straddling the ice margin and the pack
// interior is frozen. Two rolls proved the tool answers a wide ice mask with a
// generator pattern (a slab, then a fresh honeycomb); a ribbon leaves it no
// room to invent one. Narrows only, never widens (G-4). Undefined = disabled.
const landMargin = cut.landMargin === undefined ? null : cut.landMargin;
const landInpaintMargin = cut.landInpaintMargin === undefined
  ? (landMargin === null ? null : landMargin - 6) : cut.landInpaintMargin;
const holes = cut.holes || [];

const src = png.load(path.join(ROOT, 'src', 'atlas', `${id}_crop.png`));
const maskPath = path.join(ROOT, 'out', 'atlas', `${id}_mask.png`);
const mask = png.load(maskPath);
if (src.width !== w || src.height !== h || mask.width !== w || mask.height !== h) {
  throw new Error(`${id}: expected ${w}x${h}, got crop ${src.width}x${src.height}, mask ${mask.width}x${mask.height}`);
}

// 1. land = opaque and not deep teal (the conform's own predicate).
const land = new Uint8Array(w * h);
for (let y = 0; y < h; y++) {
  for (let x = 0; x < w; x++) {
    const i = src.idx(x, y);
    if (src.data[i + 3] === 0) continue;
    if (!isDeep(src.data[i], src.data[i + 1], src.data[i + 2])) land[y * w + x] = 1;
  }
}
// 2. 8-connected components; only bodies >= minLand px anchor the margin.
const comp = new Int32Array(w * h).fill(-1);
const sizes = [];
const stack = [];
for (let s = 0; s < w * h; s++) {
  if (!land[s] || comp[s] !== -1) continue;
  const c = sizes.length; sizes.push(0);
  stack.push(s); comp[s] = c;
  while (stack.length) {
    const p = stack.pop(); sizes[c]++;
    const px = p % w, py = (p / w) | 0;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = px + dx, ny = py + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const n = ny * w + nx;
        if (land[n] && comp[n] === -1) { comp[n] = c; stack.push(n); }
      }
    }
  }
}
const big = new Uint8Array(w * h);
for (let s = 0; s < w * h; s++) if (land[s] && sizes[comp[s]] >= minLand) big[s] = 1;
// 3. Chebyshev distance to the nearest big-land pixel (multi-source BFS).
const dist = new Int32Array(w * h).fill(1e9);
let q = [];
for (let s = 0; s < w * h; s++) if (big[s]) { dist[s] = 0; q.push(s); }
while (q.length) {
  const next = [];
  for (const p of q) {
    const px = p % w, py = (p / w) | 0, d = dist[p] + 1;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = px + dx, ny = py + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const n = ny * w + nx;
        if (dist[n] > d) { dist[n] = d; next.push(n); }
      }
    }
  }
  q = next;
}
// 3b. Chebyshev distance from each pixel to the nearest NON-big-land pixel
// (open water, a lead, or brash below minLand) — the ribbon cut uses it.
const wet = new Int32Array(w * h).fill(1e9);
if (landMargin !== null) {
  // Sources are the OPEN SEA only — the largest connected water body — not the
  // leads inside the pack, or every ice pixel would be "coastal" and the cut
  // would do nothing (measured: 0 px on E1 roll 3 attempt 1).
  const sea = new Uint8Array(w * h);
  for (let s2 = 0; s2 < w * h; s2++) if (!land[s2]) sea[s2] = 1;
  const scomp = new Int32Array(w * h).fill(-1); const ssz = []; const sstack = [];
  for (let s2 = 0; s2 < w * h; s2++) {
    if (!sea[s2] || scomp[s2] !== -1) continue;
    const c = ssz.length; ssz.push(0); sstack.push(s2); scomp[s2] = c;
    while (sstack.length) {
      const p2 = sstack.pop(); ssz[c]++;
      const px = p2 % w, py = (p2 / w) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = px + dx, ny = py + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const n = ny * w + nx;
        if (sea[n] && scomp[n] === -1) { scomp[n] = c; sstack.push(n); }
      }
    }
  }
  let best = -1; for (let c = 0; c < ssz.length; c++) if (best < 0 || ssz[c] > ssz[best]) best = c;
  let qw = [];
  for (let s2 = 0; s2 < w * h; s2++) if (sea[s2] && scomp[s2] === best) { wet[s2] = 0; qw.push(s2); }
  while (qw.length) {
    const next = [];
    for (const p2 of qw) {
      const px = p2 % w, py = (p2 / w) | 0, d = wet[p2] + 1;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          const n = ny * w + nx;
          if (wet[n] > d) { wet[n] = d; next.push(n); }
        }
      }
    }
    qw = next;
  }
}

const inHole = (ax, ay, inflate) => holes.some((r) =>
  ax >= r.x - inflate && ax < r.x + r.w + inflate && ay >= r.y - inflate && ay < r.y + r.h + inflate);

// 4. Narrow the shipping mask; build the PixelLab mask.
const ip = region.inpaint;
const paint = new png.Raster(w, h);
let cutSea = 0, cutHole = 0, cutDeep = 0, white = 0, kept = 0;
for (let y = 0; y < h; y++) {
  for (let x = 0; x < w; x++) {
    const s = y * w + x, ax = region.x + x, ay = region.y + y;
    const mi = mask.idx(x, y);
    const openSea = !big[s] && dist[s] > seaMargin;
    if (mask.data[mi] > 0 && openSea) { cutSea++; mask.data[mi] = mask.data[mi + 1] = mask.data[mi + 2] = 0; }
    const deepIce = landMargin !== null && wet[s] > landMargin;
    if (mask.data[mi] > 0 && deepIce) { cutDeep++; mask.data[mi] = mask.data[mi + 1] = mask.data[mi + 2] = 0; }
    if (mask.data[mi] > 0 && inHole(ax, ay, 0)) { cutHole++; mask.data[mi] = mask.data[mi + 1] = mask.data[mi + 2] = 0; }
    if (mask.data[mi] > 0) kept++;
    const inRect = ip && x >= ip.x && x < ip.x + ip.w && y >= ip.y && y < ip.y + ip.h;
    const paintable = inRect && !(!big[s] && dist[s] > inpaintMargin)
      && !(landInpaintMargin !== null && wet[s] > landInpaintMargin)
      && !inHole(ax, ay, holeInflate);
    const v = paintable ? 255 : 0;
    if (paintable) white++;
    const pi = paint.idx(x, y);
    paint.data[pi] = v; paint.data[pi + 1] = v; paint.data[pi + 2] = v; paint.data[pi + 3] = 255;
  }
}
png.save(maskPath, mask);
const paintPath = path.join(ROOT, 'src', 'atlas', `${id}_inpaint.png`);
png.save(paintPath, paint);
console.log(`${id} cut: sea ${cutSea} px zeroed (margin ${seaMargin}), deep ice ${cutDeep} px zeroed ` +
  `(landMargin ${landMargin}), holes ${cutHole} px zeroed, ` +
  `${kept} px still authorized; inpaint mask ${white} px white (margin ${inpaintMargin}, ` +
  `holes +${holeInflate}) -> ${path.relative(REPO, paintPath)}`);
