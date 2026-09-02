// surface.js — turn a generated material master into a shippable, seamless,
// ramp-conformant grain tile. Deterministic throughout: every step is a
// measurement, a value remap or a mirror. Nothing is drawn.
//
//   1. --align (optional)   Shift the master's median L* onto the ramp's BASE
//                           ink before snapping. The model supplies structure
//                           (where the flecks are); the ramp supplies values
//                           (ART-13 section 5). If the model came back a stop
//                           or two hot, snapping absolutely would push the whole
//                           tile up the ramp and break the <=6 L* rule for a
//                           reason that has nothing to do with the texture. The
//                           shift preserves ordering and contrast exactly.
//   2. snap                 Every pixel to the nearest ramp ink by CIE L*.
//                           Luminance, not RGB distance, so lit stays lit.
//   3. seam                 Measure wrap on both axes the way
//                           Scripts/art/check-tile-seam.js does. If it does not
//                           wrap, fold builds a quarter-mirror tile from a
//                           quadrant: seamless by construction (production plan
//                           section 3.5 clause 3).
//   4. verdict              Ink histogram and the L* gap between the two most
//                           used inks. >6 L* is a REJECT: the grain is a
//                           pattern, not a material.
//
// Usage:
//   node surface.js <in.png> --ramp <name> --out <file.png> [--align] [--fold] [--quad N]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const { SURFACE, CHASSIS, BUTTON } = require('./ramps.js');
const C = require('./colour.js');

const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function ramp(name) {
  const hexes = SURFACE[name] || BUTTON[name] || (name === 'chassis' ? CHASSIS : null);
  if (!hexes) throw new Error('unknown ramp ' + name);
  return hexes.map((h) => ({ hex: h.toUpperCase(), rgb: C.parse(h), L: C.lstar(...C.parse(h)) }));
}

/**
 * Flat-field the master: subtract its own low-frequency luminance and put the
 * level back.
 *
 * PixelLab does not draw a material, it draws a SWATCH — a lit object with an
 * edge, a soft vignette, and a blotch or two of shading somewhere in the middle.
 * Every one of those is low-frequency, and every one of them is what wrecked the
 * first four review rounds: the blotches became a pattern, the vignette became a
 * grid of dark lines when tiled, and the gradient across a cut window made its
 * left edge disagree with its right.
 *
 * A box-blur of the L* field IS that unwanted shading. Subtracting it and adding
 * the median back leaves the per-pixel grain and nothing else — which is the
 * definition of "grain, not pattern", and is why this is the operation rather
 * than a taste-driven touch-up. It is the flat-field correction any measurement
 * pipeline applies, it is per-pixel and spatially local, it invents no object,
 * no silhouette and no mark, and it can only make a tile LESS interesting. The
 * radius is the boundary between the two: features smaller than it survive as
 * grain, features larger than it are shading and go.
 *
 * Recorded as a deviation in the report, because it is a step ART-13 section 5
 * does not name.
 */
function flatten(r, radius, depth, rampL) {
  const { width: w, height: h } = r;
  const L = new Float64Array(w * h);
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const px = P(r, x, y);
      L[(y * w) + x] = px[3] === 255 ? C.lstar(px[0], px[1], px[2]) : 0;
    }
  }
  // Separable box blur, edges clamped.
  const tmp = new Float64Array(w * h); const blur = new Float64Array(w * h);
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      let s = 0; let n = 0;
      for (let d = -radius; d <= radius; d += 1) { const xx = Math.min(w - 1, Math.max(0, x + d)); s += L[(y * w) + xx]; n += 1; }
      tmp[(y * w) + x] = s / n;
    }
  }
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      let s = 0; let n = 0;
      for (let d = -radius; d <= radius; d += 1) { const yy = Math.min(h - 1, Math.max(0, y + d)); s += tmp[(yy * w) + x]; n += 1; }
      blur[(y * w) + x] = s / n;
    }
  }
  const sorted = Array.from(L).sort((p, q) => p - q);
  const mid = sorted[sorted.length >> 1];

  // Optional depth normalisation, and the reason it is not cheating.
  //
  // The residual left after flat-fielding is the material's grain. Its ABSOLUTE
  // amplitude is an artefact of how the model happened to expose the swatch --
  // measured across these masters it ranges from 0.02 to 6.5 L*, a factor of
  // 300, for prompts that differ only in the noun. Snapping that against a fixed
  // 2.5-4.9 L* ramp step is therefore a coin toss: below half a step the tile
  // quantises to one ink and ships as a flat fill; above two steps it sprays
  // across the ramp and ships as a pattern. Both failures were observed, on the
  // same prompt, on the same day.
  //
  // ART-13 section 5 says the ramp is what fixes the material's values. Read
  // literally that fixes the RANGE too, not just the stops: the ramp is the
  // material's tonal ladder, so the grain should span an agreed number of its
  // rungs. Scaling the residual to a fixed rung span is that sentence carried
  // out, applied identically to every family, and it is why the depth is one
  // constant rather than a per-tile taste call.
  //
  // The floor is the honesty clause. Scaling multiplies whatever is there; where
  // there is nothing there, it would multiply PNG quantisation into a speckle
  // the model never drew, and that is authoring. So a master whose grain spans
  // less than half a rung is refused outright rather than amplified.
  let scale = 1; let spread = 0; let starved = false;
  if (depth > 0) {
    const res = [];
    for (let i = 0; i < w * h; i += 1) res.push(L[i] - blur[i]);
    res.sort((p, q) => p - q);
    const p5 = res[Math.floor(res.length * 0.05)];
    const p95 = res[Math.floor(res.length * 0.95)];
    spread = p95 - p5;
    const want = depth * (rampL[1] - rampL[0]);
    const floorL = (rampL[1] - rampL[0]) * 0.5;
    if (spread < floorL) starved = true;
    else scale = want / spread;
  }
  // Write the corrected L* back as a neutral grey; hue is the ramp's job from
  // here on, and the snap that follows only reads luminance anyway.
  let moved = 0;
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      const i = ((y * w) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const v = Math.max(0, Math.min(100, ((L[(y * w) + x] - blur[(y * w) + x]) * scale) + mid));
      const Y = v > 8 ? ((v + 16) / 116) ** 3 : v / 903.3;
      const s = Y <= 0.0031308 ? Y * 12.92 : (1.055 * (Y ** (1 / 2.4))) - 0.055;
      const c = Math.max(0, Math.min(255, Math.round(s * 255)));
      if (r.data[i] !== c) moved += 1;
      r.data[i] = c; r.data[i + 1] = c; r.data[i + 2] = c;
    }
  }
  return { radius, mid, moved, scale, spread, starved };
}

/** Snap every opaque pixel to the nearest ramp ink by L*, after an optional shift. */
function snap(r, inks, shift) {
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] === 0) continue;
      const L = C.lstar(r.data[i], r.data[i + 1], r.data[i + 2]) + shift;
      let best = 0; let bd = Infinity;
      for (let k = 0; k < inks.length; k += 1) { const d = Math.abs(inks[k].L - L); if (d < bd) { bd = d; best = k; } }
      r.data[i] = inks[best].rgb[0]; r.data[i + 1] = inks[best].rgb[1]; r.data[i + 2] = inks[best].rgb[2];
      r.data[i + 3] = 255;
    }
  }
}

/**
 * Median L*, over the region that will actually ship.
 *
 * Taking it over the whole master is wrong once a window is chosen: buckram's
 * flattest 16x16 sat well above its own image median, so the whole-image shift
 * pushed the shipped window a rung up the ramp and 97% of the tile came back on
 * the MID ink. The level correction has to be measured on the pixels it is
 * correcting.
 */
function medianL(r, box) {
  const [bx, by, bw, bh] = box || [0, 0, r.width, r.height];
  const ls = [];
  for (let y = by; y < by + bh; y += 1) {
    for (let x = bx; x < bx + bw; x += 1) {
      const px = P(r, x, y); if (px[3] === 255) ls.push(C.lstar(px[0], px[1], px[2]));
    }
  }
  ls.sort((a, b) => a - b);
  return ls.length ? ls[ls.length >> 1] : 0;
}

/** Quarter-mirror fold: quadrant Q at (qx,qy), then its X, Y and XY mirrors. */
function fold(src, qx, qy, n) {
  const out = new png.Raster(n * 2, n * 2);
  const put = (x, y, px) => {
    const i = ((y * out.width) + x) << 2;
    out.data[i] = px[0]; out.data[i + 1] = px[1]; out.data[i + 2] = px[2]; out.data[i + 3] = px[3];
  };
  for (let y = 0; y < n; y += 1) {
    for (let x = 0; x < n; x += 1) {
      const px = P(src, qx + x, qy + y);
      put(x, y, px);
      put((n * 2) - 1 - x, y, px);
      put(x, (n * 2) - 1 - y, px);
      put((n * 2) - 1 - x, (n * 2) - 1 - y, px);
    }
  }
  return out;
}

// --- seam, the same arithmetic as Scripts/art/check-tile-seam.js -------------
const WRAP_TOLERANCE = 2.5; const FLAT_FLOOR = 1.5; const FLAT_ABSOLUTE = 6;
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
function wrapOf(r, axis) {
  const along = axis === 'h' ? r.width : r.height;
  const wrap = lineDelta(r, axis, along - 1, 0);
  let s = 0; for (let i = 0; i + 1 < along; i += 1) s += lineDelta(r, axis, i, i + 1);
  const interior = s / (along - 1);
  const flat = interior < FLAT_FLOOR;
  const ok = flat ? wrap <= FLAT_ABSOLUTE : (wrap / interior) <= WRAP_TOLERANCE;
  return { wrap, interior, ratio: flat ? null : wrap / interior, flat, ok };
}

/**
 * Border bias — the defect the wrap test structurally cannot see.
 *
 * PixelLab vignettes: it darkens (or lifts) the outer ring of a swatch because
 * it is drawing a *swatch*, an object with an edge, not an infinite material.
 * That ring wraps perfectly — the last column matches the first column exactly,
 * because both are ring — so `wrap` reads 0.00 and calls it clean. Tiled, the
 * two rings abut and the surface grows a grid of dark lines every repeat.
 *
 * So measure it directly: mean L* of the outer `ring` px against the mean L* of
 * the interior. Anything past a rung of the ramp is a vignette.
 */
function borderBias(r, ring) {
  let bs = 0; let bn = 0; let is = 0; let inN = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const L = C.lstar(px[0], px[1], px[2]);
      const edge = x < ring || y < ring || x >= r.width - ring || y >= r.height - ring;
      if (edge) { bs += L; bn += 1; } else { is += L; inN += 1; }
    }
  }
  const border = bn ? bs / bn : 0; const interior = inN ? is / inN : 0;
  return { border, interior, delta: border - interior };
}

/**
 * Split a window's variation into the two halves that decide the whole question.
 *
 *   low   variance of 4x4 block means. This is STRUCTURE — a blotch, a cloud, a
 *         drawn mark, the arch PixelLab leaves at the top of a swatch. It is
 *         what makes a tiled surface read as a pattern, and it is what the
 *         mirror fold amplifies into a butterfly.
 *   high  mean |pixel - its own block mean|. This is GRAIN — the one-pixel
 *         speckle the brief actually asks for. It is what a flat fill has none
 *         of.
 *
 * "Grain, not pattern" is exactly `low` small and `high` non-zero, which is why
 * the two are measured apart instead of as one contrast number. A single
 * variance figure cannot tell a blotchy tile from a speckled one.
 */
function energy(r, x0, y0, n) {
  const blocks = [];
  let hi = 0; let hn = 0;
  for (let by = 0; by < n; by += 4) {
    for (let bx = 0; bx < n; bx += 4) {
      const vals = [];
      for (let y = by; y < Math.min(by + 4, n); y += 1) {
        for (let x = bx; x < Math.min(bx + 4, n); x += 1) {
          const px = P(r, x0 + x, y0 + y);
          if (px[3] === 255) vals.push(C.lstar(px[0], px[1], px[2]));
        }
      }
      if (!vals.length) continue;
      const m = vals.reduce((s, v) => s + v, 0) / vals.length;
      blocks.push(m);
      for (const v of vals) { hi += Math.abs(v - m); hn += 1; }
    }
  }
  const bm = blocks.reduce((s, v) => s + v, 0) / blocks.length;
  const low = Math.sqrt(blocks.reduce((s, v) => s + ((v - bm) ** 2), 0) / blocks.length);
  return { low, high: hn ? hi / hn : 0 };
}

/**
 * Deterministic window search — production plan section 3.5 clause 1, scored on
 * `low` rather than on a seam.
 *
 * PixelLab draws a swatch, not a material: it arches the top, vignettes the
 * ring, and drops a cloud somewhere. Somewhere inside that 64x64 there is
 * nonetheless a patch of honest material. Take the n x n window with the least
 * low-frequency energy and the fold has nothing left to turn into a butterfly.
 * Ties broken toward the centre, so the result is stable and reproducible.
 */
function pickWindow(r, n) {
  const all = [];
  const cx = (r.width - n) / 2; const cy = (r.height - n) / 2;
  for (let y = 0; y + n <= r.height; y += 1) {
    for (let x = 0; x + n <= r.width; x += 1) {
      all.push({ x, y, e: energy(r, x, y, n), d: Math.hypot(x - cx, y - cy) });
    }
  }
  // Objective, stated the way the brief states it: GRAIN, NOT PATTERN.
  //
  // Minimising structure alone was tried first and is wrong in a way that took a
  // batch to see: the least-structured window in any image is the deadest one,
  // so the search reliably returned a flat fill and every tile failed for having
  // no material at all. Structure is a CONSTRAINT, not the objective.
  //
  // So: keep the quietest quartile by structure, then take the grainiest window
  // in it. Ties to the centre, so the answer is stable across runs.
  const lows = all.map((w) => w.e.low).sort((p, q) => p - q);
  const cap = lows[Math.floor(lows.length * 0.25)];
  const pool = all.filter((w) => w.e.low <= cap);
  pool.sort((p, q) => (q.e.high - p.e.high) || (p.e.low - q.e.low) || (p.d - q.d));
  return { best: pool[0], pool, cap };
}

function histogram(r, inks) {
  const n = new Array(inks.length).fill(0);
  const other = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const k = inks.findIndex((v) => v.rgb[0] === px[0] && v.rgb[1] === px[1] && v.rgb[2] === px[2]);
      if (k >= 0) n[k] += 1;
      else { const h = C.hex(px[0], px[1], px[2]); other.set(h, (other.get(h) ?? 0) + 1); }
    }
  }
  return { n, other };
}

function main() {
  const a = process.argv.slice(2);
  const file = a[0];
  const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
  const name = arg('--ramp');
  const out = arg('--out');
  const quad = Number(arg('--quad', 32));
  const doAlign = a.includes('--align');
  const doFold = a.includes('--fold');

  const inks = ramp(name);
  let r = png.loadAny(file);
  console.log(path.basename(file) + '  ' + r.width + 'x' + r.height + '  ramp=' + name);

  const flatR = Number(arg('--flatten', 0));
  const depth = Number(arg('--depth', 0));
  let starved = false;
  if (flatR > 0) {
    const f = flatten(r, flatR, depth, inks.map((k) => k.L));
    starved = f.starved;
    console.log('  flat-field     radius ' + f.radius + ', level restored to L*=' + f.mid.toFixed(2)
      + ', ' + f.moved + ' px moved (shading removed, grain kept)');
    if (depth > 0) {
      console.log('  grain depth    p5-p95 residual ' + f.spread.toFixed(3) + ' L*'
        + (f.starved ? '  STARVED: below half a ramp rung, refusing to amplify nothing'
          : '  x' + f.scale.toFixed(2) + ' -> ' + depth + ' rung(s)'));
    }
  }

  // Where on the ramp the master's MEDIAN should land. Fractional, interpolated
  // in L*.
  //
  // 1.0 (the base ink) is the obvious reading of ART-13 and it is wrong here, and
  // the measurements say why. Every one of these ramps steps 2.5-4.9 L* from
  // shadow to base and then 6.0-8.4 L* from base to mid. Put the median on the
  // base and half the grain lands on the base and half on the MID, so the two
  // most-used inks are 6.3-7.6 apart and the tile fails the <=6 rule for a
  // reason that has nothing to do with how busy it is -- a 97%-flat vellum with a
  // 3% fleck failed by the same margin as a genuinely striped steel.
  //
  // 0.5 -- the midpoint between shadow and base -- straddles the ink0/ink1
  // boundary instead, so the grain's mass sits on the two closest rungs on the
  // ladder (<=4.9 L* apart by construction) and only a real outlier reaches the
  // mid. That is ART-13's own sentence read properly: shadow -> base -> mid ->
  // highlight-FLECK. The flecks are meant to be rare.
  //
  // It also darkens the surface, which is the right direction: body text sits on
  // this, and every ramp's contrast figure in ART-13 section 1 is a floor, not a
  // target.
  const target = Number(arg('--target', 1));
  const lo = inks[Math.floor(target)]; const hi = inks[Math.min(inks.length - 1, Math.ceil(target))];
  const targetL = lo.L + ((hi.L - lo.L) * (target - Math.floor(target)));

  // Search BEFORE snapping. After the snap there are five tones left, and a
  // window that quantised to a single ink scores zero structure and zero grain
  // and wins a search it should have failed. The master's own continuous tones
  // are the only honest thing to measure structure against.
  const search = a.includes('--pick') ? pickWindow(r, quad) : null;
  const win = search ? search.best : null;
  if (win) {
    console.log('  window search  quiet quartile (cap ' + search.cap.toFixed(2) + '), '
      + search.pool.length + ' candidates; grainiest at (' + win.x + ',' + win.y + ')'
      + '  low(structure)=' + win.e.low.toFixed(2) + '  high(grain)=' + win.e.high.toFixed(2));
  }

  const med = medianL(r, win ? [win.x, win.y, quad, quad] : null);
  const shift = doAlign ? targetL - med : 0;
  console.log('  median L*      ' + med.toFixed(2) + (win ? ' (over the shipped window)' : '')
    + (doAlign ? '  -> aligned to ramp index ' + target + ' L*=' + targetL.toFixed(2) + ' (shift ' + shift.toFixed(2) + ')' : ''));

  snap(r, inks, shift);

  const bias = borderBias(r, 3);
  console.log('  border bias    outer ring L* ' + bias.border.toFixed(2) + ' vs interior ' + bias.interior.toFixed(2)
    + '  d=' + bias.delta.toFixed(2) + (Math.abs(bias.delta) > 1.5 ? '  VIGNETTE (fold required)' : '  flat'));

  let folded = false;
  const before = { h: wrapOf(r, 'h'), v: wrapOf(r, 'v') };
  const noFold = a.includes('--no-fold');
  const show = (t, m) => console.log('  wrap ' + t + '   join ' + m.wrap.toFixed(2) + ' / interior ' + m.interior.toFixed(2)
    + (m.flat ? ' (flat)' : ' ratio ' + m.ratio.toFixed(2)) + '  ' + (m.ok ? 'wraps' : 'SEAM'));
  show('h (pre) ', before.h); show('v (pre) ', before.v);

  // CUT before FOLD, and the review sheet is why.
  //
  // The quarter-mirror fold is seamless by construction and it is also, at this
  // pixel count, the single most visible defect available: mirror symmetry turns
  // every surviving fleck into a butterfly, and a butterfly repeating every 32
  // logical px reads as plaid. Eight of eleven folded tiles failed a blind read
  // on exactly that, and none of them failed on a seam.
  //
  // A cut window has no symmetry to see. Its join is only as good as the noise
  // happens to make it -- but noise joins noise well, which is what the wrap
  // ratio measures, so the honest move is to SEARCH for a window that both reads
  // as material and happens to wrap, taking them in order of grain. The fold
  // stays as the fallback for a master where no window wraps, because a mirror
  // beat is still better than a hard seam.
  if (a.includes('--cut') && search) {
    // Take the BEST join in the pool, not the first acceptable one.
    //
    // `wrapOk` is a pass/fail gate calibrated for a frame's edge run. On an
    // amplified grain it is too generous: journal_leaf passed it and still grew
    // a visible vertical stripe every 64 logical px, because a ratio of 2.4 is
    // "legal" and "legal" is not "invisible". The pool is hundreds of windows
    // wide and they cost nothing to score, so score them all and take the
    // quietest join. Grain breaks ties, so a dead window cannot win by having no
    // join to speak of.
    // Grain is a constraint on the join search too, for the same reason it was a
    // constraint on the structure search: the quietest join in any image belongs
    // to its deadest window, so an unconstrained "best join" ships a flat fill
    // and calls it seamless. Keep the grainier half of the pool, then take the
    // best join inside it.
    const poolHighs = search.pool.map((w) => w.e.high).sort((p, q) => p - q);
    const grainFloor = poolHighs[poolHighs.length >> 1];
    const joinPool = search.pool.filter((w) => w.e.high >= grainFloor);
    let chosen = null; let bestScore = Infinity;
    for (const w of joinPool.slice(0, 600)) {
      const sub = png.crop(r, w.x, w.y, quad, quad);
      const mh = wrapOf(sub, 'h'); const mv = wrapOf(sub, 'v');
      if (!mh.ok || !mv.ok) continue;
      const score = (mh.flat ? mh.wrap : mh.ratio) + (mv.flat ? mv.wrap : mv.ratio);
      if (score < bestScore - 1e-9
        || (Math.abs(score - bestScore) < 1e-9 && chosen && w.e.high > chosen.w.e.high)) {
        bestScore = score; chosen = { w, sub, mh, mv, score };
      }
    }
    if (chosen) {
      r = chosen.sub;
      console.log('  cut            ' + quad + 'x' + quad + ' at (' + chosen.w.x + ',' + chosen.w.y + ')'
        + '  low=' + chosen.w.e.low.toFixed(2) + ' high=' + chosen.w.e.high.toFixed(2) + '  join=' + chosen.score.toFixed(2) + '  no mirror');
    } else {
      console.log('  cut            no window in the quiet quartile wraps; falling back to the fold');
    }
    if (!chosen && !noFold) { r = fold(r, win.x, win.y, quad); folded = true; }
  } else if (!noFold && (doFold || Math.abs(bias.delta) > 1.5 || !before.h.ok || !before.v.ok)) {
    const qx = win ? win.x : (r.width - quad) >> 1;
    const qy = win ? win.y : (r.height - quad) >> 1;
    r = fold(r, qx, qy, quad); folded = true;
  }
  const after = { h: wrapOf(r, 'h'), v: wrapOf(r, 'v') };
  if (folded) {
    console.log('  folded         quarter-mirror ' + quad + 'x' + quad + ' -> ' + r.width + 'x' + r.height);
  }
  show('h (out) ', after.h); show('v (out) ', after.v);

  const hist = histogram(r, inks);
  const n = hist.n;
  const total = n.reduce((s, v) => s + v, 0);
  inks.forEach((k, i) => console.log('  ink' + i + ' ' + k.hex + '  L*=' + k.L.toFixed(1).padStart(5)
    + '  ' + String(n[i]).padStart(5) + ' px  ' + ((n[i] / total) * 100).toFixed(1).padStart(5) + '%'));
  if (hist.other.size) console.log('  OFF-RAMP       ' + hist.other.size + ' colour(s): ' + [...hist.other.keys()].slice(0, 5).join(' '));

  // Two numbers, reported side by side, because one of them alone lies.
  //
  //   literal   dL* between the two most-used inks, whatever their area. This is
  //             the brief's rule as written and it is printed unmodified.
  //   mass      dL* between the two most-used inks that each carry >=10% of the
  //             tile. A 0.4%-of-area fleck one rung up is not a pattern, it is
  //             the "highlight-fleck" the ART-13 ramp is built to end on, and
  //             the literal rule cannot tell the two apart because every ramp
  //             here steps 6.0-8.4 L* from base to mid. Where the two numbers
  //             disagree the verdict is stated as CHECK and settled by looking.
  //
  // And one number in the other direction: a tile that is >97% a single ink has
  // no grain at all. It is a flat fill, it adds nothing over `surfaceCard`, and
  // it fails for the opposite reason to a pattern.
  const order = n.map((v, i) => [v, i]).sort((x, y) => y[0] - x[0]);
  const gap = Math.abs(inks[order[0][1]].L - inks[order[1][1]].L);
  const heavy = order.filter((o) => (o[0] / total) >= 0.10);
  const massGap = heavy.length > 1 ? Math.abs(inks[heavy[0][1]].L - inks[heavy[1][1]].L) : null;
  const dominant = order[0][0] / total;
  const literalOk = gap <= 6;
  const massOk = massGap === null ? true : massGap <= 6;
  const grainOk = dominant <= 0.97;
  const verdict = starved ? 'REJECT (master carries no grain to scale)'
    : !grainOk ? 'REJECT (flat fill, no grain)'
    : (literalOk && massOk) ? 'PASS'
      : massOk ? 'CHECK (literal fails on a sparse fleck; look at it)'
        : 'REJECT (two heavy inks too far apart)';
  console.log('  two most used  ink' + order[0][1] + ' (' + (dominant * 100).toFixed(1) + '%) + ink'
    + order[1][1] + ' (' + ((order[1][0] / total) * 100).toFixed(1) + '%)  literal dL*=' + gap.toFixed(2));
  console.log('  >=10% inks     ' + heavy.map((o) => 'ink' + o[1] + ' ' + ((o[0] / total) * 100).toFixed(1) + '%').join(' + ')
    + (massGap === null ? '  (single heavy ink)' : '  mass dL*=' + massGap.toFixed(2)));
  console.log('  verdict        ' + verdict);

  let teal = 0; let semi = 0; let over = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semi += 1;
      if (px[3] !== 255) continue;
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      if (C.relLum(px[0], px[1], px[2]) > C.CEILING_L) over += 1;
    }
  }
  console.log('  guards         teal ' + teal + '  semi-alpha ' + semi + '  over-ceiling ' + over
    + '  ' + (teal + semi + over === 0 ? 'clean' : 'VIOLATION'));

  if (out) {
    fs.mkdirSync(path.dirname(out), { recursive: true });
    png.save(out, r);
    console.log('  wrote          ' + out + ' ' + r.width + 'x' + r.height);
  }
  process.exit(verdict.startsWith('PASS') && teal + semi + over === 0 && after.h.ok && after.v.ok ? 0 : 1);
}
main();
