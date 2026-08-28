// WORLD ATLAS REMASTER 01 — Iteration 02, Tier 2: density-ladder stamp belts.
//
// The owner's device review found "dense tile-like biome block → abrupt edge
// → empty terrain" across the atlas (register D-01/D-12/D-06). The authored
// canopy-face repaints wait for the 2026-09-16 PixelLab reset; this module is
// the deterministic half the owner's brief explicitly authorized ("improved
// deterministically / composited from existing assets"): whole existing
// approved tree sprites — harvested with their base shadows from the shipped
// composite itself — are stamped onto OPEN GROUND in graded transition belts,
// thinning away from each forest mass (ATLAS-J's density ladder, rungs
// L2–L4). Every output pixel is a pixel of the approved composite (A-2).
//
// Anti-repetition mandates (ATLAS-M): multiple distinct source sprites per
// belt, hash-jittered multi-round placement (never grid-aligned), horizontal
// mirroring, and a monotonic but irregular density gradient. Each belt
// carries an `enabled` flag — a belt that fails its phone-FOV desk gate is
// reverted whole by flipping the flag, never partially tuned.
//
// Substrate rule (ATLAS-J): a sprite may land only where the destination
// ground matches the sprite's own home ground (median of its border pixels;
// snow belts use a paleness test), so olive-grown trees never stand on lime,
// lime on sand, or pines on grass. The same check is the open-ground test:
// canopy, rock, road, water and sand all fail it, so a stamp can never
// overwrite art. 10% of a sprite's pixels may sit on ground dapple outliers;
// protection failures are never tolerated.
//
// Protection (ATLAS-L): every masked destination pixel is checked against
// the A-4 rim/core (`protDepth`) and each belt's HARD clip rect (the
// roadjoin-golden standoff at y 480, the strand goldens at y 870/872, the
// Frostmere golden's x 400, the rim limit x 275). Salt 15 (1–14 taken).

'use strict';

const SALT = 15;

// Source sprites: hand-picked singles from the shipped composite, each fully
// ringed by its own substrate.
const SPRITES = [
  // olive-verge substrate (the accepted R2 vocabulary, brighter olive)
  { id: 'olive_ball',   x: 234, y: 633, w: 14, h: 17, kind: 'broad' },
  { id: 'olive_yellow', x: 231, y: 735, w: 18, h: 20, kind: 'broad' },
  { id: 'olive_single', x: 240, y: 752, w: 17, h: 20, kind: 'broad' },
  // heath substrate (the darker meadow under the Worldspine, A1's own local
  // singles — harvested inside the belt so the substrate is exact)
  { id: 'heath_fir_a',  x: 175, y: 351, w: 10, h: 14, kind: 'conifer' },
  { id: 'heath_fir_b',  x: 190, y: 360, w: 11, h: 15, kind: 'conifer' },
  { id: 'heath_pairfir', x: 186, y: 389, w: 12, h: 17, kind: 'conifer' },
  { id: 'heath_fir_c',  x: 197, y: 389, w: 10, h: 16, kind: 'conifer' },
  { id: 'heath_broad',  x: 203, y: 349, w: 11, h: 14, kind: 'broad' },
  // lime substrate (the coastal plain's own singles)
  { id: 'lime_big',     x: 267, y: 974, w: 25, h: 29, kind: 'broad' },
  { id: 'lime_twin',    x: 363, y: 957, w: 29, h: 35, kind: 'broad' },
  { id: 'lime_bush',    x: 299, y: 919, w: 21, h: 17, kind: 'bush' },
  { id: 'lime_teal',    x: 377, y: 892, w: 27, h: 38, kind: 'broad' },
  { id: 'lime_small',   x: 301, y: 871, w: 18, h: 14, kind: 'bush' },
  // snow substrate: the only two pristine snow-ringed stragglers in the
  // north (component scan of the pre-stamp composite) — mirroring gives four
  // silhouettes, legitimate for stunted treeline pines
  { id: 'pine_b', x: 367, y: 271, w: 13, h: 20, kind: 'pine' },
  { id: 'pine_c', x: 354, y: 300, w: 12, h: 16, kind: 'pine' },
];

// Belts. Density falls from `pNear` at the `from` edge to `pFar` opposite.
// `cell` is the round-0 grid pitch; rounds 1–2 re-sweep at wider stagger.
// `hard` is the inviolable clip (ATLAS-L): a stamp may not touch outside it.
const BELTS = [
  {
    id: 'B1_treeline', enabled: true,
    rect: { x0: 250, y0: 238, x1: 393, y1: 275 },
    hard: { x0: 240, y0: 230, x1: 399, y1: 275 },
    sprites: ['pine_b', 'pine_c'],
    axis: 'y', from: 'far', pNear: 0.85, pFar: 0.12, cell: 6,
    groundTest: 'pale',
  },
  {
    id: 'A1_westverge', enabled: true,
    rect: { x0: 200, y0: 278, x1: 275, y1: 470 },
    hard: { x0: 190, y0: 276, x1: 275, y1: 479 },
    sprites: ['heath_fir_a', 'heath_fir_b', 'heath_pairfir', 'heath_fir_c',
      'heath_broad', 'olive_ball', 'olive_single'],
    axis: 'x', from: 'far', pNear: 0.8, pFar: 0.1, cell: 7,
    coniferNorthOf: 370,
  },
  {
    id: 'C1_swblock_east', enabled: true,
    rect: { x0: 282, y0: 874, x1: 336, y1: 964 },
    hard: { x0: 278, y0: 872, x1: 344, y1: 1010 },
    sprites: ['lime_big', 'lime_twin', 'lime_bush', 'lime_teal', 'lime_small'],
    axis: 'x', from: 'near', pNear: 0.9, pFar: 0.15, cell: 5,
  },
  {
    id: 'C2_swblock_south', enabled: true,
    rect: { x0: 122, y0: 946, x1: 305, y1: 1004 },
    hard: { x0: 120, y0: 938, x1: 312, y1: 1016 },
    sprites: ['lime_big', 'lime_bush', 'lime_small', 'olive_ball',
      'olive_single', 'olive_yellow'],
    axis: 'y', from: 'near', pNear: 0.85, pFar: 0.15, cell: 6,
  },
  {
    id: 'C5_swblock_west', enabled: true,
    rect: { x0: 98, y0: 872, x1: 142, y1: 964 },
    hard: { x0: 92, y0: 870, x1: 150, y1: 1010 },
    sprites: ['olive_ball', 'olive_single', 'olive_yellow', 'lime_bush',
      'lime_small'],
    axis: 'x', from: 'far', pNear: 0.85, pFar: 0.15, cell: 5,
  },
];

const dist = (data, g, i) =>
  Math.abs(data[i] - g[0]) + Math.abs(data[i + 1] - g[1]) + Math.abs(data[i + 2] - g[2]);

/** Harvest one sprite: raster copy + mask via border flood of ground-like
 * pixels. */
function harvest(base, s) {
  const { x, y, w, h } = s;
  const data = new Uint8Array(w * h * 4);
  for (let sy = 0; sy < h; sy++) {
    for (let sx = 0; sx < w; sx++) {
      const bi = base.idx(x + sx, y + sy), di = (sy * w + sx) * 4;
      for (let k = 0; k < 4; k++) data[di + k] = base.data[bi + k];
    }
  }
  const rs = [], gs = [], bs = [];
  for (let sx = 0; sx < w; sx++) {
    for (const sy of [0, h - 1]) {
      const i = (sy * w + sx) * 4; rs.push(data[i]); gs.push(data[i + 1]); bs.push(data[i + 2]);
    }
  }
  for (let sy = 0; sy < h; sy++) {
    for (const sx of [0, w - 1]) {
      const i = (sy * w + sx) * 4; rs.push(data[i]); gs.push(data[i + 1]); bs.push(data[i + 2]);
    }
  }
  const med = (arr) => arr.sort((p, q) => p - q)[Math.floor(arr.length / 2)];
  const ground = [med(rs), med(gs), med(bs)];
  const T = 60;
  const visited = new Uint8Array(w * h);
  const queue = [];
  const groundLike = (i) => dist(data, ground, i) <= T;
  for (let sx = 0; sx < w; sx++) for (const sy of [0, h - 1]) queue.push(sy * w + sx);
  for (let sy = 0; sy < h; sy++) for (const sx of [0, w - 1]) queue.push(sy * w + sx);
  while (queue.length) {
    const p = queue.pop();
    if (visited[p] || !groundLike(p * 4)) continue;
    visited[p] = 1;
    const px = p % w, py = (p / w) | 0;
    if (px > 0) queue.push(p - 1);
    if (px < w - 1) queue.push(p + 1);
    if (py > 0) queue.push(p - w);
    if (py < h - 1) queue.push(p + w);
  }
  const mask = new Uint8Array(w * h);
  let n = 0;
  for (let p = 0; p < w * h; p++) { if (!visited[p]) { mask[p] = 1; n++; } }
  if (n < 20) throw new Error(`stamp sprite ${s.id}: mask degenerate (${n} px)`);
  return { w, h, data, mask, ground };
}

/** Apply all enabled belts; returns per-belt placement counts. */
function apply(base, hash, protDepth, PROT) {
  const sprites = {};
  for (const s of SPRITES) sprites[s.id] = { ...s, ...harvest(base, s) };

  const occupied = new Uint8Array(1024 * 1024);
  const counts = {};
  for (const belt of BELTS) {
    if (!belt.enabled) { counts[belt.id] = 'disabled'; continue; }
    let placed = 0;
    const { x0, y0, x1, y1 } = belt.rect;
    for (let round = 0; round < 3; round++) {
      const salt = SALT + round * 7;
      const pitch = belt.cell + round * 3;
      const off = Math.floor(pitch / 2) * round;
      for (let cy = y0 + (off % pitch); cy < y1; cy += pitch) {
        for (let cx = x0 + (off % pitch); cx < x1; cx += pitch) {
          const jx = cx + Math.floor(hash(cx, cy, salt) * pitch);
          const jy = cy + Math.floor(hash(cx + 511, cy + 257, salt) * pitch);
          const t = belt.axis === 'x' ? (jx - x0) / (x1 - x0) : (jy - y0) / (y1 - y0);
          const tt = belt.from === 'near' ? Math.min(1, Math.max(0, t)) : 1 - Math.min(1, Math.max(0, t));
          const p = belt.pNear + (belt.pFar - belt.pNear) * tt;
          if (hash(jx, jy, salt) >= p * [0.55, 0.35, 0.25][round]) continue;
          let pool = belt.sprites;
          if (belt.coniferNorthOf && jy < belt.coniferNorthOf &&
              hash(jx + 97, jy + 31, salt) < 0.7) {
            const conifers = pool.filter((id) =>
              sprites[id].kind === 'conifer' || sprites[id].kind === 'pine');
            if (conifers.length) pool = conifers;
          }
          // try up to three pool picks at this site — zones inside one belt
          // can favour different substrates
          let spr = null, mirror = false, ox = 0, oy = 0;
          for (let attempt = 0; attempt < 3 && !spr; attempt++) {
            const cand = sprites[pool[
              Math.floor(hash(jx + 13 + attempt * 29, jy + 71, salt) * pool.length) % pool.length]];
            const cm = hash(jx + 41, jy + 179 + attempt, salt) < 0.5;
            const cox = jx - (cand.w >> 1), coy = jy - cand.h + 2;
            // hard clip: the stamp must lie fully inside the belt's hard rect
            if (cox < belt.hard.x0 || coy < belt.hard.y0 ||
                cox + cand.w > belt.hard.x1 || coy + cand.h > belt.hard.y1) continue;
            let ok = true, maskedN = 0, misfit = 0;
            for (let sy = 0; sy < cand.h && ok; sy++) {
              for (let sx = 0; sx < cand.w && ok; sx++) {
                if (!cand.mask[sy * cand.w + sx]) continue;
                maskedN++;
                const tx = cox + (cm ? cand.w - 1 - sx : sx), ty = coy + sy;
                if (protDepth(tx, ty) > PROT.band) { ok = false; break; }
                if (occupied[ty * 1024 + tx]) { ok = false; break; }
                const bi = base.idx(tx, ty);
                if (belt.groundTest === 'pale') {
                  if (!(base.data[bi] > 180 && base.data[bi + 1] > 195 &&
                        base.data[bi + 2] > 195)) misfit++;
                } else if (dist(base.data, cand.ground, bi) > 70) {
                  misfit++;
                }
              }
            }
            if (ok && misfit <= maskedN * 0.1) { spr = cand; mirror = cm; ox = cox; oy = coy; }
          }
          if (!spr) continue;
          for (let sy = 0; sy < spr.h; sy++) {
            for (let sx = 0; sx < spr.w; sx++) {
              if (!spr.mask[sy * spr.w + sx]) continue;
              const tx = ox + (mirror ? spr.w - 1 - sx : sx), ty = oy + sy;
              const bi = base.idx(tx, ty), si = (sy * spr.w + sx) * 4;
              for (let k = 0; k < 4; k++) base.data[bi + k] = spr.data[si + k];
              for (let my = -2; my <= 2; my++) {
                for (let mx = -2; mx <= 2; mx++) {
                  const qx = tx + mx, qy = ty + my;
                  if (qx >= 0 && qy >= 0 && qx < 1024 && qy < 1024) occupied[qy * 1024 + qx] = 1;
                }
              }
            }
          }
          placed++;
        }
      }
    }
    counts[belt.id] = placed;
  }
  return counts;
}

module.exports = { apply, BELTS, SPRITES };
