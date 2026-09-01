// frame-prep.js — deterministic preparation of a generated chassis frame.
//
// Every operation here is A-2 permitted: crop, alpha key, speck removal by
// connected component, and palette index remap. **Nothing here invents an
// object, a silhouette, an animation frame or illustrated content.** If a
// candidate needs a mark it does not have, that is a re-roll, not a script.
//
// Pipeline, in order, each step explained where it is not obvious:
//
//   1. crop to the opaque bounding box
//        PixelLab centres its subject and leaves a transparent margin. The
//        margin is not part of the frame and would push the corner blocks off
//        their own corners.
//
//   2. drop specks
//        Connected components not touching the frame ring -- the stray marks
//        the model leaves outside the border. Removing a disconnected blob is
//        not authoring; it removes something rather than adding one.
//
//   3. key the interior
//        Flood fill inward from the centre, stopping at the frame's inner dark
//        line. The production plan predicts the filled centre and says
//        explicitly: key it, do not re-roll. Detects the stop edge by luminance
//        step rather than by an absolute colour, so it works on any candidate.
//
//   4. measure
//        Band thickness per run, corner radius, and the longitudinal
//        invariance that decides whether a run can tile at all.
//
//   5. remap (optional, --remap)
//        Quantise onto the five-ink chassis ramp from the production plan §6.
//        This is what brings a generated leather -- which always drifts bright
//        -- under the #7C7263 luminance ceiling without repainting it.
//        Nearest-luminance assignment, so the light/shadow ordering the model
//        drew is preserved exactly and only the values move.
'use strict';

const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

// The chassis ramp, production plan §6. Five inks, dark to light.
const RAMP = [
  { hex: '#0F0D0B', rgb: [0x0f, 0x0d, 0x0b], role: 'outer outline' },
  { hex: '#33291F', rgb: [0x33, 0x29, 0x1f], role: 'body shadow' },
  { hex: '#4A3B2B', rgb: [0x4a, 0x3b, 0x2b], role: 'body mid' },
  { hex: '#6B5A3E', rgb: [0x6b, 0x5a, 0x3e], role: 'body light' },
  { hex: '#7C6A4A', rgb: [0x7c, 0x6a, 0x4a], role: 'stitch' },
];

const CEILING_L = lum(0x7c, 0x72, 0x63);

function lum(r, g, b) {
  const f = (c) => { const s = c / 255; return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); };
  return (0.2126 * f(r)) + (0.7152 * f(g)) + (0.0722 * f(b));
}

const A = (r, x, y) => (x < 0 || y < 0 || x >= r.width || y >= r.height ? 0 : r.data[(((y * r.width) + x) << 2) + 3]);
const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };
const setA = (r, x, y, a) => { r.data[(((y * r.width) + x) << 2) + 3] = a; };

// --- 1. crop ---------------------------------------------------------------

function cropToContent(r) {
  let x0 = r.width; let y0 = r.height; let x1 = -1; let y1 = -1;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      if (A(r, x, y) !== 0) {
        if (x < x0) x0 = x; if (x > x1) x1 = x;
        if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) throw new Error('fully transparent');
  return { raster: png.crop(r, x0, y0, x1 - x0 + 1, y1 - y0 + 1), box: [x0, y0, x1 - x0 + 1, y1 - y0 + 1] };
}

// --- 2. specks -------------------------------------------------------------

/** Label opaque connected components (4-connected). Returns {labels, sizes}. */
function components(r) {
  const labels = new Int32Array(r.width * r.height).fill(-1);
  const sizes = [];
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const at = (y * r.width) + x;
      if (A(r, x, y) === 0 || labels[at] !== -1) continue;
      const id = sizes.length;
      let n = 0;
      const stack = [at];
      labels[at] = id;
      while (stack.length) {
        const p = stack.pop(); n += 1;
        const px0 = p % r.width; const py0 = (p - px0) / r.width;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = px0 + dx; const ny = py0 + dy;
          if (nx < 0 || ny < 0 || nx >= r.width || ny >= r.height) continue;
          const q = (ny * r.width) + nx;
          if (labels[q] !== -1 || A(r, nx, ny) === 0) continue;
          labels[q] = id; stack.push(q);
        }
      }
      sizes.push(n);
    }
  }
  return { labels, sizes };
}

/** Keep only the largest component; everything else is a speck. */
function dropSpecks(r) {
  const { labels, sizes } = components(r);
  if (sizes.length <= 1) return { removed: 0, components: sizes.length };
  let best = 0;
  for (let i = 1; i < sizes.length; i += 1) if (sizes[i] > sizes[best]) best = i;
  let removed = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const id = labels[(y * r.width) + x];
      if (id !== -1 && id !== best) { setA(r, x, y, 0); removed += 1; }
    }
  }
  return { removed, components: sizes.length };
}

// --- 3. interior key -------------------------------------------------------

/**
 * Flood fill from the centre outward, clearing pixels until the frame's inner
 * dark line stops the fill.
 *
 * The stop test is a luminance floor derived from the image itself: the darkest
 * decile. The inner line is the darkest ink in the frame by construction (the
 * prompt asks for it), so "stop at anything as dark as the darkest decile"
 * finds it without hardcoding a colour that only one candidate has.
 */
function keyInterior(r) {
  const ls = [];
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const [cr, cg, cb, a] = P(r, x, y);
      if (a === 255) ls.push(lum(cr, cg, cb));
    }
  }
  if (!ls.length) return { cleared: 0, stopL: 0 };
  ls.sort((a, b) => a - b);
  const stopL = ls[Math.floor(ls.length * 0.18)];

  const seen = new Uint8Array(r.width * r.height);
  const cx = r.width >> 1; const cy = r.height >> 1;
  if (A(r, cx, cy) === 0) return { cleared: 0, stopL };

  const stack = [(cy * r.width) + cx];
  seen[(cy * r.width) + cx] = 1;
  let cleared = 0;
  while (stack.length) {
    const p = stack.pop();
    const x = p % r.width; const y = (p - x) / r.width;
    const [cr, cg, cb, a] = P(r, x, y);
    if (a === 0) continue;
    if (lum(cr, cg, cb) <= stopL) continue; // the inner line: stop, keep it
    setA(r, x, y, 0); cleared += 1;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx; const ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= r.width || ny >= r.height) continue;
      const q = (ny * r.width) + nx;
      if (seen[q]) continue;
      seen[q] = 1; stack.push(q);
    }
  }
  return { cleared, stopL };
}

// --- 4. measure ------------------------------------------------------------

function bandFrom(r, from, at) {
  const n = (from === 'top' || from === 'bottom') ? r.height : r.width;
  let run = 0;
  for (let i = 0; i < n; i += 1) {
    const a = from === 'top' ? A(r, at, i)
      : from === 'bottom' ? A(r, at, r.height - 1 - i)
        : from === 'left' ? A(r, i, at) : A(r, r.width - 1 - i, at);
    if (a === 0) break;
    run += 1;
  }
  return run;
}

function invariance(r, side, band, corner) {
  const horiz = side === 'top' || side === 'bottom';
  const len = (horiz ? r.width : r.height) - (corner * 2);
  if (len < 2 || band < 1) return null;
  const col = (i) => {
    const out = [];
    for (let d = 0; d < band; d += 1) {
      if (side === 'top') out.push(P(r, corner + i, d));
      else if (side === 'bottom') out.push(P(r, corner + i, r.height - 1 - d));
      else if (side === 'left') out.push(P(r, d, corner + i));
      else out.push(P(r, r.width - 1 - d, corner + i));
    }
    return out;
  };
  let sum = 0;
  for (let i = 0; i + 1 < len; i += 1) {
    const a = col(i); const b = col(i + 1);
    let s = 0;
    for (let k = 0; k < band; k += 1) {
      if (a[k][3] === 0 && b[k][3] === 0) continue;
      s += Math.abs(a[k][0] - b[k][0]) + Math.abs(a[k][1] - b[k][1]) + Math.abs(a[k][2] - b[k][2]) + Math.abs(a[k][3] - b[k][3]);
    }
    sum += s / (band * 4);
  }
  return sum / (len - 1);
}

// --- 5. remap --------------------------------------------------------------

/**
 * Quantise every opaque pixel onto the chassis ramp by nearest luminance.
 *
 * Luminance rather than RGB distance on purpose: the model's leather is the
 * right *structure* in the wrong *values*, and matching on luminance preserves
 * which pixels are lit and which are shadowed -- the upper-left key light the
 * style spec requires -- while moving the whole set under the ceiling. Matching
 * on RGB distance would scramble that ordering wherever the model's hue drifted.
 */
/**
 * Clamp only what breaks the ceiling, and leave everything else exactly as the
 * model authored it.
 *
 * This is the preferred correction and `--remap` is the fallback. The ceiling
 * rule (production plan §6) forbids interface art *brighter* than `textMuted`;
 * it says nothing about the rest of the ramp. A full redistribution therefore
 * repaints ~3,300 pixels to fix a violation that lives in a few hundred, and it
 * showed: the accepted chassis came back olive and lost the warm brown that
 * made it read as oiled leather in the first place.
 *
 * So: every colour already under the ceiling is untouched. Each colour above it
 * is pulled to a ramp ink, preserving order -- the brightest offender takes the
 * brightest legal ink, the next takes the one below, and so on -- so a stitch
 * line stays lighter than the leather it runs along.
 */
function clampCeiling(r) {
  const ceiling = lum(0x7c, 0x72, 0x63);
  const over = new Set();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const [cr, cg, cb, a] = P(r, x, y);
      if (a !== 255) continue;
      if (lum(cr, cg, cb) > ceiling) over.add((cr << 16) | (cg << 8) | cb);
    }
  }
  if (!over.size) return { changed: 0, colours: 0 };

  // Brightest offender first, so it takes the brightest legal ink.
  const ranked = [...over].sort((a, b) => lum((b >> 16) & 255, (b >> 8) & 255, b & 255)
    - lum((a >> 16) & 255, (a >> 8) & 255, a & 255));
  // Legal inks, brightest first.
  const legal = RAMP.filter((k) => lum(...k.rgb) <= ceiling)
    .sort((a, b) => lum(...b.rgb) - lum(...a.rgb));

  const assign = new Map();
  ranked.forEach((k, i) => { assign.set(k, legal[Math.min(i, legal.length - 1)].rgb); });

  let changed = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const k = (r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2];
      const to = assign.get(k);
      if (!to) continue;
      [r.data[i], r.data[i + 1], r.data[i + 2]] = to;
      changed += 1;
    }
  }
  return { changed, colours: over.size };
}

function remap(r) {
  // Rank the DISTINCT colours by luminance, then spread that ranking across the
  // ramp. Not the raw per-pixel luminance, and the difference is not academic:
  //
  // Linear normalisation over [min, max] luminance was tried first and
  // destroyed the frame. One near-white stitch colour set `max`, ~80% of the
  // pixels were the dark outline, and the leather -- the entire subject --
  // compressed into the darkest ink. The result was a black rectangle with a
  // faint dashed line.
  //
  // A pixel artist's palette IS the tone ladder: each distinct colour is a
  // deliberate step, and how many pixels wear it says nothing about where it
  // sits on that ladder. So rank the distinct colours and distribute the
  // ranking evenly. That preserves the number of visible steps and the
  // light/shadow ordering the model drew, and moves only the values.
  const pop = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const [cr, cg, cb, a] = P(r, x, y);
      if (a !== 255) continue;
      const k = (cr << 16) | (cg << 8) | cb;
      pop.set(k, (pop.get(k) ?? 0) + 1);
    }
  }
  if (!pop.size) return 0;

  // Drop colours too rare to be a deliberate step -- stray dither the model
  // left behind. They ride with their nearest neighbour rather than claiming a
  // rung of the ladder to themselves.
  const total = [...pop.values()].reduce((a, b) => a + b, 0);
  const floor = Math.max(2, Math.round(total * 0.002));
  const steps = [...pop.entries()]
    .filter(([, n]) => n >= floor)
    .map(([k]) => k)
    .sort((a, b) => lum((a >> 16) & 255, (a >> 8) & 255, a & 255)
      - lum((b >> 16) & 255, (b >> 8) & 255, b & 255));

  const n = steps.length;
  const assign = new Map();
  steps.forEach((k, i) => {
    const idx = n === 1 ? 0 : Math.round((i / (n - 1)) * (RAMP.length - 1));
    assign.set(k, RAMP[idx].rgb);
  });

  // Anything below the floor takes the assignment of the nearest ranked colour
  // in luminance, so no pixel is left unmapped.
  const stepL = steps.map((k) => lum((k >> 16) & 255, (k >> 8) & 255, k & 255));
  const nearest = (L) => {
    let best = 0; let bd = Infinity;
    for (let i = 0; i < stepL.length; i += 1) {
      const d = Math.abs(stepL[i] - L);
      if (d < bd) { bd = d; best = i; }
    }
    return assign.get(steps[best]);
  };

  let changed = 0;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const k = (r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2];
      const to = assign.get(k) ?? nearest(lum(r.data[i], r.data[i + 1], r.data[i + 2]));
      if (r.data[i] !== to[0] || r.data[i + 1] !== to[1] || r.data[i + 2] !== to[2]) changed += 1;
      [r.data[i], r.data[i + 1], r.data[i + 2]] = to;
    }
  }
  return changed;
}

// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  const doRemap = args.includes('--remap');
  const doClamp = args.includes('--clamp');
  const outDir = (() => { const i = args.indexOf('--out'); return i === -1 ? null : args[i + 1]; })();
  const corner = (() => { const i = args.indexOf('--corner'); return i === -1 ? 16 : Number(args[i + 1]); })();
  const files = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--out' && args[i - 1] !== '--corner');

  for (const f of files) {
    const src = png.loadAny(f);
    const { raster, box } = cropToContent(src);
    const speck = dropSpecks(raster);
    // Re-crop: removing specks can shrink the box.
    const { raster: r } = cropToContent(raster);
    const key = keyInterior(r);
    const changed = doRemap ? remap(r) : 0;
    const clamped = doClamp ? clampCeiling(r) : { changed: 0, colours: 0 };

    const midX = r.width >> 1; const midY = r.height >> 1;
    const band = {
      top: bandFrom(r, 'top', midX),
      bottom: bandFrom(r, 'bottom', midX),
      left: bandFrom(r, 'left', midY),
      right: bandFrom(r, 'right', midY),
    };

    let maxL = 0; let maxHex = '';
    const cols = new Set();
    for (let y = 0; y < r.height; y += 1) {
      for (let x = 0; x < r.width; x += 1) {
        const [cr, cg, cb, a] = P(r, x, y);
        if (a !== 255) continue;
        cols.add((cr << 16) | (cg << 8) | cb);
        const L = lum(cr, cg, cb);
        if (L > maxL) { maxL = L; maxHex = `#${(((cr << 16) | (cg << 8) | cb)).toString(16).padStart(6, '0')}`; }
      }
    }

    console.log(`\n=== ${path.basename(f)} ===`);
    console.log(`  cropped        ${box[2]}x${box[3]} -> ${r.width}x${r.height}  (from ${src.width}x${src.height})`);
    console.log(`  specks         ${speck.components} component(s), ${speck.removed} px removed`);
    console.log(`  interior key   ${key.cleared} px cleared`);
    console.log(`  band T/B/L/R   ${band.top} / ${band.bottom} / ${band.left} / ${band.right}   (plan fixes 6)`);
    console.log(`  colours        ${cols.size}${doRemap ? ` (remapped, ${changed} px moved)` : ''}${doClamp ? ` (clamped ${clamped.colours} colour(s), ${clamped.changed} px)` : ''}`);
    console.log(`  max luminance  ${maxHex} L=${maxL.toFixed(4)}  ${maxL > CEILING_L ? 'OVER CEILING' : 'under ceiling'}`);
    console.log('  run invariance (lower tiles more honestly):');
    for (const s of ['top', 'bottom', 'left', 'right']) {
      const v = invariance(r, s, band[s], corner);
      console.log(`      ${s.padEnd(7)} ${v === null ? 'n/a' : v.toFixed(2)}`);
    }

    if (outDir) {
      fs.mkdirSync(outDir, { recursive: true });
      const base = path.basename(f).replace(/\.png$/, '');
      const suffix = doRemap ? '_prep_remap' : (doClamp ? '_prep_clamp' : '_prep');
      png.save(path.join(outDir, `${base}${suffix}.png`), r);
      png.save(path.join(outDir, `${base}${suffix}_x4.png`), png.scale(r, 4));
    }
  }
}

main();
