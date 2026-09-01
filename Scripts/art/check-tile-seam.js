#!/usr/bin/env node
// check-tile-seam.js
//
// The tile-seam gate. Precondition P-4 of
// `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md`.
//
// ## What it is for
//
// `DECISIONS/0029` forbids `centerSlice` and makes **tiling** the only
// permitted edge behaviour for an authored panel frame. That choice is right --
// stretching pixel art across four phone widths is exactly the failure the
// decision was written to avoid -- but it moves the risk somewhere subtler.
//
// A tiled edge repeats. If the last column of the tile does not meet the first
// column cleanly, the join produces a visible beat every repeat period. And the
// number of repeats is *not fixed*: §3.3 of the production plan works out that
// the four supported phone widths produce four different fractional remainders,
// one of them exact. So a seam can be invisible on the phone the author
// reviewed and obvious on the next one, and a single-height review cannot see
// it. That is a defect class a human gate structurally cannot catch, which is
// what makes it worth a script.
//
// ## What it measures, and what it refuses to conclude
//
// Two things, both mechanical:
//
//   tile-seam.wrap     The tile's last column against its own first column.
//                      This is the join the repeat actually makes. Scored as
//                      mean absolute channel difference over the column, and
//                      compared against the tile's own internal
//                      column-to-column variation -- because a busy texture
//                      tolerates a join a flat one does not, and an absolute
//                      threshold would either pass everything or fail
//                      everything depending on the material.
//
//   tile-seam.period   Whether the strip is honestly periodic at its declared
//                      period. A strip authored as a 16-px run but carrying a
//                      24-px motif reads as a repeating *motif*, not a
//                      material, and §3.4 forbids exactly that: a discrete
//                      centre in an edge run is clipped at one phone width and
//                      whole at another.
//
// **A pass here is not acceptance.** `RULES.md` A-3 was written about atlas
// boundaries and its logic transfers without change: a numeric seam score is a
// pre-filter. Acceptance is a blind read at device scale, at the four widths in
// §3.3. This script exists to stop a bad tile reaching the humans, never to
// tell them a good one arrived.
//
// ## Contract
//
// Exit 0  satisfied (or nothing to check).
// Exit 1  named violation, STRIDE_GUARD[tile-seam.<rule>].
// Exit 2  infrastructure fault, STRIDE_INFRA[<reason>].
//
// Usage:
//   node Scripts/art/check-tile-seam.js                  # every declared strip
//   node Scripts/art/check-tile-seam.js --self-test
//   node Scripts/art/check-tile-seam.js --measure <png> --period <n> [--axis h|v]
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const png = require('./png.js');

const ROOT = path.resolve(__dirname, '..', '..');

/**
 * Where frame sheets live once Batch A ships. Empty today, and that is fine:
 * a guard that is vacuously green before its subject exists is a guard that is
 * already wired when the subject arrives, rather than one somebody has to
 * remember to add.
 */
const FRAME_DIR = 'assets/ui/v1/frame';
const SURFACE_DIR = 'assets/ui/v1/surface';

/**
 * The repeat period the production plan fixes, in source pixels (§3.2).
 * A strip whose real period differs from this is not a chassis edge.
 */
const DEFAULT_PERIOD = 8;

/**
 * How much worse the wrap join may be than the strip's own internal
 * column-to-column variation before it counts as a seam.
 *
 * 1.0 would demand the join be as good as the *average* interior step, which
 * is stricter than the eye and would fail hand-authored material that reads
 * perfectly. 2.5 says: the join may be noticeably busier than a typical step,
 * but not a discontinuity. Calibrated against the one thing available to
 * calibrate against -- synthetic strips in the self-test whose seams are known
 * by construction -- and stated here so a future round can argue with the
 * number rather than rediscover it.
 */
const WRAP_TOLERANCE = 2.5;

/**
 * Below this mean interior variation a strip is flat enough that the ratio
 * test becomes meaningless (dividing by near-zero). Flat strips are held to a
 * small absolute difference instead.
 */
const FLAT_FLOOR = 1.5;
const FLAT_ABSOLUTE = 6;

// ---------------------------------------------------------------------------
// Measurement
// ---------------------------------------------------------------------------

/** Mean absolute RGBA difference between two columns of a raster. */
function columnDelta(raster, x0, x1, y0, y1) {
  const { width, data } = raster;
  let sum = 0;
  let n = 0;
  for (let y = y0; y < y1; y += 1) {
    const a = ((y * width) + x0) << 2;
    const b = ((y * width) + x1) << 2;
    // Fully transparent on both sides is not a difference -- alpha 0 pixels
    // carry no colour and comparing their RGB is comparing noise.
    if (data[a + 3] === 0 && data[b + 3] === 0) { n += 1; continue; }
    sum += Math.abs(data[a] - data[b])
      + Math.abs(data[a + 1] - data[b + 1])
      + Math.abs(data[a + 2] - data[b + 2])
      + Math.abs(data[a + 3] - data[b + 3]);
    n += 1;
  }
  return n === 0 ? 0 : sum / (n * 4);
}

/** Mean absolute RGBA difference between two rows. */
function rowDelta(raster, y0, y1, x0, x1) {
  const { width, data } = raster;
  let sum = 0;
  let n = 0;
  for (let x = x0; x < x1; x += 1) {
    const a = ((y0 * width) + x) << 2;
    const b = ((y1 * width) + x) << 2;
    if (data[a + 3] === 0 && data[b + 3] === 0) { n += 1; continue; }
    sum += Math.abs(data[a] - data[b])
      + Math.abs(data[a + 1] - data[b + 1])
      + Math.abs(data[a + 2] - data[b + 2])
      + Math.abs(data[a + 3] - data[b + 3]);
    n += 1;
  }
  return n === 0 ? 0 : sum / (n * 4);
}

/**
 * Measure one tileable strip.
 *
 * `axis` is `'h'` for a strip that repeats left-to-right (a top or bottom run)
 * and `'v'` for one that repeats top-to-bottom (a left or right run).
 *
 * Returns `{ wrap, interior, ratio, period, periodDelta, flat }`.
 */
function measureStrip(raster, { axis = 'h', period = DEFAULT_PERIOD } = {}) {
  const { width, height } = raster;
  const along = axis === 'h' ? width : height;
  const across = axis === 'h' ? height : width;

  if (along < 2) {
    throw Object.assign(new Error(`strip is ${along}px along its repeat axis`), { infra: true });
  }

  const delta = axis === 'h'
    ? (i, j) => columnDelta(raster, i, j, 0, across)
    : (i, j) => rowDelta(raster, i, j, 0, across);

  // The join the repeat actually makes: last against first.
  const wrap = delta(along - 1, 0);

  // The strip's own internal step, as the baseline the wrap is judged against.
  let sum = 0;
  for (let i = 0; i + 1 < along; i += 1) sum += delta(i, i + 1);
  const interior = sum / (along - 1);

  const flat = interior < FLAT_FLOOR;
  const ratio = flat ? 0 : wrap / interior;

  // Periodicity: how well the strip matches itself shifted by `period`.
  let periodDelta = null;
  if (along > period) {
    let psum = 0;
    let pn = 0;
    for (let i = 0; i + period < along; i += 1) { psum += delta(i, i + period); pn += 1; }
    periodDelta = pn === 0 ? null : psum / pn;
  }

  return { wrap, interior, ratio, period, periodDelta, flat, along, across };
}

/** Is this strip's wrap acceptable? */
function wrapOk(m) {
  return m.flat ? m.wrap <= FLAT_ABSOLUTE : m.ratio <= WRAP_TOLERANCE;
}

// ---------------------------------------------------------------------------
// Tree scan
// ---------------------------------------------------------------------------

function pngsUnder(base, dir) {
  const abs = path.join(base, dir);
  if (!fs.existsSync(abs)) return [];
  const out = [];
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.isFile() && e.name.toLowerCase().endsWith('.png')) {
        out.push(path.relative(base, p).split(path.sep).join('/'));
      }
    }
  };
  walk(abs);
  return out;
}

/**
 * A frame sheet is one PNG holding four corners and, in the remainder, the
 * four edge runs (§3.4 -- four edges, not two, because the key light is upper
 * left everywhere and a mirrored run flips it).
 *
 * The sheet's own geometry tells us where the runs are: a `corner`-sized block
 * in each corner, the horizontal runs between the corners along the top and
 * bottom, the vertical runs down the left and right. `corner` is read from the
 * sidecar `.json` a frame ships with, because guessing it from the image is
 * exactly the kind of inference that produces a guard nobody trusts.
 */
function stripsOfFrameSheet(raster, corner) {
  const { width, height } = raster;
  const runW = width - (corner * 2);
  const runH = height - (corner * 2);
  if (runW <= 0 || runH <= 0) {
    throw Object.assign(
      new Error(`corner ${corner} leaves no run in a ${width}x${height} sheet`),
      { infra: true },
    );
  }
  return [
    { name: 'top', axis: 'h', rect: [corner, 0, runW, corner] },
    { name: 'bottom', axis: 'h', rect: [corner, height - corner, runW, corner] },
    { name: 'left', axis: 'v', rect: [0, corner, corner, runH] },
    { name: 'right', axis: 'v', rect: [width - corner, corner, corner, runH] },
  ];
}

function scan(base) {
  const violations = [];
  let checked = 0;

  for (const dir of [FRAME_DIR, SURFACE_DIR]) {
    for (const file of pngsUnder(base, dir)) {
      const abs = path.join(base, file);
      let raster;
      try {
        raster = png.loadAny(abs);
      } catch (err) {
        throw Object.assign(new Error(`undecodable_png: ${file}: ${err.message}`), { infra: true });
      }

      const sidecar = abs.replace(/\.png$/i, '.json');
      let meta = {};
      if (fs.existsSync(sidecar)) {
        try {
          meta = JSON.parse(fs.readFileSync(sidecar, 'utf8'));
        } catch (err) {
          throw Object.assign(
            new Error(`bad_sidecar: ${file}: ${err.message}`),
            { infra: true },
          );
        }
      }

      const period = meta.period ?? DEFAULT_PERIOD;

      if (dir === SURFACE_DIR) {
        // An interior surface tiles in both directions.
        for (const axis of ['h', 'v']) {
          const m = measureStrip(raster, { axis, period });
          checked += 1;
          if (!wrapOk(m)) {
            violations.push({
              rule: 'wrap',
              file,
              detail:
                `surface does not wrap on the ${axis === 'h' ? 'horizontal' : 'vertical'} axis: `
                + `join ${m.wrap.toFixed(2)} vs interior step ${m.interior.toFixed(2)} `
                + `(ratio ${m.ratio.toFixed(2)}, tolerance ${WRAP_TOLERANCE})`,
            });
          }
        }
        continue;
      }

      // Frames: a sidecar declaring `corner` is required, because without it
      // there is no honest way to know where the runs are.
      if (meta.corner === undefined) {
        violations.push({
          rule: 'declaration',
          file,
          detail:
            'frame sheet has no sidecar .json declaring `corner`, so its edge '
            + 'runs cannot be located. Geometry is measured from the asset, never guessed.',
        });
        continue;
      }

      let strips;
      try {
        strips = stripsOfFrameSheet(raster, meta.corner);
      } catch (err) {
        throw err;
      }

      for (const s of strips) {
        const sub = png.crop(raster, s.rect[0], s.rect[1], s.rect[2], s.rect[3]);
        const m = measureStrip(sub, { axis: s.axis, period });
        checked += 1;

        if (!wrapOk(m)) {
          violations.push({
            rule: 'wrap',
            file,
            detail:
              `the ${s.name} run does not wrap: join ${m.wrap.toFixed(2)} vs `
              + `interior step ${m.interior.toFixed(2)} (ratio ${m.ratio.toFixed(2)}, `
              + `tolerance ${WRAP_TOLERANCE}). It will beat every ${period}px at some phone widths.`,
          });
        }

        // A run whose period-shifted self-match is worse than its wrap join is
        // carrying a motif rather than a material (§3.4).
        if (m.periodDelta !== null && !m.flat && m.periodDelta > m.interior * WRAP_TOLERANCE) {
          violations.push({
            rule: 'period',
            file,
            detail:
              `the ${s.name} run is not periodic at ${period}px `
              + `(shift-match ${m.periodDelta.toFixed(2)} vs interior step ${m.interior.toFixed(2)}). `
              + 'A discrete centre in an edge run is clipped at one phone width and whole at another.',
          });
        }
      }
    }
  }

  return { violations, checked };
}

// ---------------------------------------------------------------------------

function report({ violations, checked }) {
  if (violations.length === 0) {
    process.stdout.write(
      checked === 0
        ? '  ok      tile-seam: no frame or surface assets yet, vacuously satisfied\n'
        : `  ok      tile-seam: ${checked} strip(s) wrap cleanly at their declared period\n`,
    );
    return 0;
  }
  const byRule = new Map();
  for (const v of violations) {
    if (!byRule.has(v.rule)) byRule.set(v.rule, []);
    byRule.get(v.rule).push(v);
  }
  for (const [rule, list] of byRule) {
    process.stderr.write(`STRIDE_GUARD[tile-seam.${rule}] ${list.length} finding(s)\n`);
    for (const v of list) process.stderr.write(`    ${v.file}: ${v.detail}\n`);
  }
  process.stderr.write(
    '\n  A pass here would not have been acceptance either (RULES.md A-3): the\n'
    + '  verdict is a blind read at device scale, at all four widths.\n',
  );
  return 1;
}

// ---------------------------------------------------------------------------
// Self-test
// ---------------------------------------------------------------------------

function selfTest() {
  let pass = 0;
  let failed = 0;
  const ok = (l) => { pass += 1; process.stdout.write(`  ok      ${l}\n`); };
  const bad = (l, w) => { failed += 1; process.stderr.write(`  FAILED  ${l}: ${w}\n`); };

  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'stride-seam-'));

  /** Build a horizontal strip from a per-column colour function. */
  const strip = (w, h, fn) => {
    const r = new png.Raster(w, h);
    for (let y = 0; y < h; y += 1) {
      for (let x = 0; x < w; x += 1) {
        const [cr, cg, cb] = fn(x, y);
        const i = ((y * w) + x) << 2;
        r.data[i] = cr; r.data[i + 1] = cg; r.data[i + 2] = cb; r.data[i + 3] = 255;
      }
    }
    return r;
  };

  // A genuinely cyclic period-8 run. Note what this is NOT: a sawtooth
  // `0x33 + (x % 8) * 3` looks periodic and is measured as a seam, correctly --
  // its last column is the peak and its first is the trough, so every repeat
  // drops 21 values in one pixel. That is the exact defect this gate is for,
  // and it is easy to author by accident, so it is the negative case below.
  const cyclic = strip(16, 6, (x) => {
    const v = Math.round(0x3a + (9 * Math.sin((2 * Math.PI * x) / 8)));
    return [v, v - 8, v - 18];
  });
  let m = measureStrip(cyclic, { axis: 'h', period: 8 });
  if (wrapOk(m)) ok('a cyclic period-8 run wraps cleanly'); else bad('a cyclic period-8 run wraps cleanly', `ratio ${m.ratio.toFixed(2)}`);

  const sawtooth = strip(16, 6, (x) => {
    const v = 0x33 + ((x % 8) * 3);
    return [v, v - 8, v - 18];
  });
  m = measureStrip(sawtooth, { axis: 'h', period: 8 });
  if (!wrapOk(m)) ok('a sawtooth is caught -- its peak meets its trough'); else bad('a sawtooth is caught', `ratio ${m.ratio.toFixed(2)}`);

  // A ramp: last column is far from the first. Classic non-wrapping run.
  const ramp = strip(16, 6, (x) => {
    const v = 0x20 + (x * 8);
    return [v, v, v];
  });
  m = measureStrip(ramp, { axis: 'h', period: 8 });
  if (!wrapOk(m)) ok('a ramp is caught as a seam'); else bad('a ramp is caught as a seam', `ratio ${m.ratio.toFixed(2)}`);

  // A flat run with one bright column at the end -- the seam a ratio test on a
  // busy texture would wave through, and the reason FLAT_ABSOLUTE exists.
  const flatSeam = strip(16, 6, (x) => (x === 15 ? [0xc0, 0xc0, 0xc0] : [0x33, 0x29, 0x1f]));
  m = measureStrip(flatSeam, { axis: 'h', period: 8 });
  if (!wrapOk(m)) ok('a flat run with a bright last column is caught'); else bad('a flat run with a bright last column is caught', `wrap ${m.wrap.toFixed(2)} flat=${m.flat}`);

  // A perfectly flat run wraps by construction.
  const flat = strip(16, 6, () => [0x33, 0x29, 0x1f]);
  m = measureStrip(flat, { axis: 'h', period: 8 });
  if (wrapOk(m)) ok('a perfectly flat run wraps'); else bad('a perfectly flat run wraps', `wrap ${m.wrap.toFixed(2)}`);

  // The naive mirror fold the plan warns about: c0..c3 c3..c0 doubles c0 at the
  // join, so it wraps -- but its period is wrong, which is the real defect.
  const naiveFold = strip(16, 6, (x) => {
    const seq = [0, 1, 2, 3, 3, 2, 1, 0];
    const v = 0x33 + (seq[x % 8] * 9);
    return [v, v - 8, v - 18];
  });
  m = measureStrip(naiveFold, { axis: 'h', period: 8 });
  if (wrapOk(m)) ok('the naive mirror fold wraps (its defect is period, not join)'); else bad('naive fold wrap', `ratio ${m.ratio.toFixed(2)}`);

  // Vertical axis works the same way.
  const vertRamp = strip(6, 16, (x, y) => { const v = 0x20 + (y * 8); return [v, v, v]; });
  m = measureStrip(vertRamp, { axis: 'v', period: 8 });
  if (!wrapOk(m)) ok('a vertical ramp is caught'); else bad('a vertical ramp is caught', `ratio ${m.ratio.toFixed(2)}`);

  // A frame sheet with no sidecar is a declaration violation, not a pass.
  const dir = path.join(work, FRAME_DIR);
  fs.mkdirSync(dir, { recursive: true });
  png.save(path.join(dir, 'card.png'), strip(96, 96, () => [0x33, 0x29, 0x1f]));
  let res = scan(work);
  if (res.violations.some((v) => v.rule === 'declaration')) ok('a frame with no sidecar is refused, not assumed');
  else bad('a frame with no sidecar is refused', 'no declaration violation raised');

  // With a sidecar, a flat sheet passes.
  fs.writeFileSync(path.join(dir, 'card.json'), JSON.stringify({ corner: 16, period: 8 }));
  res = scan(work);
  if (res.violations.length === 0) ok('a declared flat frame sheet passes');
  else bad('a declared flat frame sheet passes', res.violations.map((v) => v.rule).join(','));

  // An empty tree is vacuously green.
  fs.rmSync(path.join(work, 'assets'), { recursive: true, force: true });
  res = scan(work);
  if (res.violations.length === 0 && res.checked === 0) ok('an empty tree is vacuously satisfied');
  else bad('an empty tree is vacuously satisfied', `${res.violations.length} violations`);

  fs.rmSync(work, { recursive: true, force: true });
  process.stdout.write(`\n  tile-seam self-test: ${pass} passed, ${failed} failed\n`);
  return failed === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--self-test')) process.exit(selfTest());

  // Ad-hoc measurement, for use during a production round before an asset is
  // declared and packaged.
  const mi = args.indexOf('--measure');
  if (mi !== -1) {
    const file = args[mi + 1];
    const pi = args.indexOf('--period');
    const ai = args.indexOf('--axis');
    const period = pi === -1 ? DEFAULT_PERIOD : Number(args[pi + 1]);
    const axis = ai === -1 ? 'h' : args[ai + 1];
    try {
      const m = measureStrip(png.loadAny(file), { axis, period });
      process.stdout.write(
        `${file} axis=${axis} period=${period}\n`
        + `  wrap join        ${m.wrap.toFixed(3)}\n`
        + `  interior step    ${m.interior.toFixed(3)}\n`
        + `  ratio            ${m.flat ? 'n/a (flat)' : m.ratio.toFixed(3)}\n`
        + `  period shift     ${m.periodDelta === null ? 'n/a' : m.periodDelta.toFixed(3)}\n`
        + `  verdict          ${wrapOk(m) ? 'wraps' : 'SEAM'}\n`,
      );
      process.exit(wrapOk(m) ? 0 : 1);
    } catch (err) {
      process.stderr.write(`STRIDE_INFRA[measure] ${err.message}\n`);
      process.exit(2);
    }
  }

  let result;
  try {
    result = scan(ROOT);
  } catch (err) {
    process.stderr.write(`STRIDE_INFRA[${err.infra ? 'unreadable_asset' : 'internal'}] ${err.message}\n`);
    process.exit(2);
  }
  process.exit(report(result));
}

main();
