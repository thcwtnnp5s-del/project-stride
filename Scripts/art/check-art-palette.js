#!/usr/bin/env node
// check-art-palette.js
//
// The palette guard. Precondition P-1 of
// `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md`, required before the first
// round of interface art is generated under `DECISIONS/0029`.
//
// ## Why this has to exist before the art, not after
//
// `ART_DIRECTION.md` L-16 reserves `#58D6C0` system-wide for walking, steps and
// banked energy. Nothing enforced it. That was survivable for as long as every
// generated asset was a creature, an item or a place — content art is authored
// nowhere near interface colour, so a collision was unlikely by accident.
//
// `DECISIONS/0029` changes exactly that. Interface art is the first art
// authored *near* interface colour, so it is the first that can collide, and
// `PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md` §4.1 concedes the generated
// palettes only *appear* clear of teal — "an impression, not a measurement".
// This file is the measurement.
//
// It lands green on the current tree, and that is deliberate. A guard that is
// red the day it ships gets weakened instead of obeyed, which is the failure
// `RULES.md` G-4 exists to name.
//
// ## The four rules
//
//   art-palette.teal       No opaque pixel within DeltaRGB 10 of #58D6C0
//                          anywhere in shipped art, with exactly one
//                          allowlisted file: the step glyph, which is the one
//                          asset L-16 says SHOULD carry it.
//
//   art-palette.alpha      No pixel with 0 < a < 255. Zero semi-transparent
//                          pixels is what makes integer scaling exact
//                          (L-18 first paragraph, unamended). The measured
//                          baseline across every shipped PNG is zero.
//
//   art-palette.ceiling    No opaque pixel in the interface-art directories
//                          brighter than `textMuted #7C7263` in relative
//                          luminance. Chrome that outshines the words has
//                          become a second piece of type.
//
//   art-palette.substrate  No frame pixel drawn in the ink of the surface
//                          behind it -- `surfaceCard #201C17` or
//                          `surfaceGround #14120F`. A frame drawn in its own
//                          background's colour is a frame nobody can see and
//                          everybody signs off.
//
// ## Contract
//
// Exit 0  satisfied.
// Exit 1  named violation, reported as STRIDE_GUARD[art-palette.<rule>].
// Exit 2  infrastructure fault, reported as STRIDE_INFRA[<reason>].
//
// The split matters for the same reason it matters in `Scripts/lib/xmlq.js`:
// only a real policy violation may fail as one. A missing directory or a PNG
// this decoder cannot read is not evidence that the tree breaks the rules, and
// must never be reported as though it were.
//
// Usage:
//   node Scripts/art/check-art-palette.js
//   node Scripts/art/check-art-palette.js --self-test
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const png = require('./png.js');

const ROOT = path.resolve(__dirname, '..', '..');

// ---------------------------------------------------------------------------
// Constants, every one of them cited
// ---------------------------------------------------------------------------

/** L-16's reserved teal. `stride_colors.dart` walkingAccent. */
const TEAL = [0x58, 0xd6, 0xc0];

/**
 * Chebyshev radius around TEAL that counts as a collision.
 *
 * Per-channel rather than Euclidean on purpose: a colour 10 off on all three
 * channels is still perceptually the reserved teal, and Euclidean distance 10
 * would wave it through. The plan's "DeltaRGB 10" is read as the stricter
 * reading, because the cheap direction to be wrong in is the strict one -- a
 * false positive costs one conversation, a false negative costs the register.
 */
const TEAL_RADIUS = 10;

/**
 * The one file L-16 says should carry teal: the accepted PixelLab traveller's
 * boot that marks the step economy (OD-03, closed in Activity Feel 01).
 * Measured across all shipped PNGs, it is the only file that does.
 */
const TEAL_ALLOWLIST = new Set(['assets/ui/v1/glyph_steps.png']);

/** `textMuted`. Interface art may not out-shine the words. */
const CEILING = [0x7c, 0x72, 0x63];

/** `surfaceCard` and `surfaceGround` -- the inks a frame may not be drawn in. */
const SUBSTRATE = [
  { name: 'surfaceCard', rgb: [0x20, 0x1c, 0x17] },
  { name: 'surfaceGround', rgb: [0x14, 0x12, 0x0f] },
];

/** Everything shipped. Scanned for teal and for stray alpha. */
const ALL_ART = ['assets/art/v1', 'assets/ui/v1'];

/** Interface art proper. Additionally bound by the luminance ceiling. */
const CHROME = ['assets/ui/v1/frame', 'assets/ui/v1/surface', 'assets/ui/v1/ornament'];

/** Frames only. Additionally bound by the substrate rule. */
const FRAMES = ['assets/ui/v1/frame'];

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

/**
 * WCAG relative luminance of an sRGB triple, 0..1.
 *
 * Linearised rather than a naive weighted mean, because the whole question is
 * "does this out-shine the text", and that is a perceptual question that the
 * gamma-encoded values answer wrong.
 */
function luminance(r, g, b) {
  const lin = (c) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  return (0.2126 * lin(r)) + (0.7152 * lin(g)) + (0.0722 * lin(b));
}

const CEILING_L = luminance(CEILING[0], CEILING[1], CEILING[2]);

function chebyshev(r, g, b, ref) {
  return Math.max(Math.abs(r - ref[0]), Math.abs(g - ref[1]), Math.abs(b - ref[2]));
}

function hex(r, g, b) {
  const h = (v) => v.toString(16).padStart(2, '0');
  return `#${h(r)}${h(g)}${h(b)}`;
}

// ---------------------------------------------------------------------------
// Walking the tree
// ---------------------------------------------------------------------------

/** Every .png under `dir`, recursively, as paths relative to `base`. */
function pngsUnder(base, dir) {
  const abs = path.join(base, dir);
  if (!fs.existsSync(abs)) return [];

  const out = [];
  const walk = (d) => {
    let entries;
    try {
      entries = fs.readdirSync(d, { withFileTypes: true });
    } catch (err) {
      throw Object.assign(new Error(`cannot read ${d}: ${err.message}`), { infra: true });
    }
    for (const e of entries.sort((a, b) => a.name.localeCompare(b.name))) {
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

// ---------------------------------------------------------------------------
// The scan
// ---------------------------------------------------------------------------

/**
 * Scan one tree. Returns `{ violations, scanned }` where each violation names
 * its rule, its file, the first offending pixel and what was found there.
 *
 * First offending pixel only, per file per rule. A frame authored in the wrong
 * ink is wrong in ten thousand pixels and reporting all of them buries the
 * next file's finding.
 */
function scan(base) {
  const violations = [];
  const counts = { files: 0, teal: 0, alpha: 0, ceiling: 0, substrate: 0 };

  const inAny = (file, dirs) => dirs.some((d) => file === d || file.startsWith(`${d}/`));

  const files = [];
  for (const dir of ALL_ART) files.push(...pngsUnder(base, dir));

  for (const file of files) {
    let raster;
    try {
      raster = png.loadAny(path.join(base, file));
    } catch (err) {
      throw Object.assign(
        new Error(`undecodable_png: ${file}: ${err.message}`),
        { infra: true },
      );
    }

    counts.files += 1;

    const chrome = inAny(file, CHROME);
    const frame = inAny(file, FRAMES);
    const tealExempt = TEAL_ALLOWLIST.has(file);

    // One violation of each kind per file, so the report stays readable.
    const seen = { teal: false, alpha: false, ceiling: false, substrate: false };

    const { width, height, data } = raster;
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const i = ((y * width) + x) << 2;
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const a = data[i + 3];

        if (a > 0 && a < 255 && !seen.alpha) {
          seen.alpha = true;
          counts.alpha += 1;
          violations.push({
            rule: 'alpha',
            file,
            detail: `semi-transparent pixel at (${x}, ${y}): alpha ${a}`,
          });
        }

        if (a !== 255) continue; // every remaining rule is about opaque ink

        if (!tealExempt && !seen.teal && chebyshev(r, g, b, TEAL) <= TEAL_RADIUS) {
          seen.teal = true;
          counts.teal += 1;
          violations.push({
            rule: 'teal',
            file,
            detail:
              `${hex(r, g, b)} at (${x}, ${y}) is within ${TEAL_RADIUS} of ` +
              `reserved ${hex(...TEAL)} (L-16)`,
          });
        }

        if (chrome && !seen.ceiling && luminance(r, g, b) > CEILING_L) {
          seen.ceiling = true;
          counts.ceiling += 1;
          violations.push({
            rule: 'ceiling',
            file,
            detail:
              `${hex(r, g, b)} at (${x}, ${y}) is brighter than the ` +
              `${hex(...CEILING)} textMuted ceiling`,
          });
        }

        if (frame && !seen.substrate) {
          const hit = SUBSTRATE.find(
            (s) => r === s.rgb[0] && g === s.rgb[1] && b === s.rgb[2],
          );
          if (hit) {
            seen.substrate = true;
            counts.substrate += 1;
            violations.push({
              rule: 'substrate',
              file,
              detail:
                `${hex(r, g, b)} at (${x}, ${y}) is ${hit.name}, the surface ` +
                'behind this frame -- a frame drawn in its own background',
            });
          }
        }
      }
    }
  }

  return { violations, counts };
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

function report(result) {
  const { violations, counts } = result;

  if (violations.length === 0) {
    process.stdout.write(
      `  ok      art-palette: ${counts.files} PNGs, no teal collision, ` +
      'no semi-transparent pixel, chrome under the textMuted ceiling\n',
    );
    return 0;
  }

  // Group by rule so the guard name in the failure line is unambiguous.
  const byRule = new Map();
  for (const v of violations) {
    if (!byRule.has(v.rule)) byRule.set(v.rule, []);
    byRule.get(v.rule).push(v);
  }

  for (const [rule, list] of byRule) {
    process.stderr.write(`STRIDE_GUARD[art-palette.${rule}] ${list.length} file(s)\n`);
    for (const v of list) process.stderr.write(`    ${v.file}: ${v.detail}\n`);
  }
  return 1;
}

// ---------------------------------------------------------------------------
// Self-test -- fabricated rasters in a temp tree, the live tree untouched
// ---------------------------------------------------------------------------

function selfTest() {
  let pass = 0;
  let failed = 0;
  const ok = (label) => { pass += 1; process.stdout.write(`  ok      ${label}\n`); };
  const bad = (label, why) => {
    failed += 1;
    process.stderr.write(`  FAILED  ${label}: ${why}\n`);
  };

  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'stride-palette-'));

  const write = (rel, pixels, w = 2, h = 1) => {
    const abs = path.join(work, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    const raster = new png.Raster(w, h);
    pixels.forEach((p, n) => {
      const i = n << 2;
      raster.data[i] = p[0];
      raster.data[i + 1] = p[1];
      raster.data[i + 2] = p[2];
      raster.data[i + 3] = p[3];
    });
    png.save(abs, raster);
  };

  const OPAQUE_DARK = [0x33, 0x29, 0x1f, 255];
  const CLEAR = [0, 0, 0, 0];

  const run = () => {
    try {
      return { result: scan(work), threw: null };
    } catch (err) {
      return { result: null, threw: err };
    }
  };

  const expect = (label, want) => {
    const { result, threw } = run();
    if (threw) { bad(label, `threw: ${threw.message}`); return; }
    const rules = new Set(result.violations.map((v) => v.rule));
    if (want === null) {
      if (rules.size === 0) ok(label);
      else bad(label, `expected clean, got ${[...rules].join(', ')}`);
    } else if (rules.has(want)) ok(label);
    else bad(label, `expected ${want}, got ${rules.size ? [...rules].join(', ') : 'clean'}`);
  };

  const reset = () => fs.rmSync(path.join(work, 'assets'), { recursive: true, force: true });

  // A clean tree is clean.
  reset();
  write('assets/art/v1/env/prop.png', [OPAQUE_DARK, CLEAR]);
  expect('clean tree passes', null);

  // Teal anywhere in shipped art is a violation...
  reset();
  write('assets/art/v1/env/prop.png', [[0x58, 0xd6, 0xc0, 255], CLEAR]);
  expect('exact teal is caught', 'teal');

  // ...including near-teal inside the radius...
  reset();
  write('assets/art/v1/env/prop.png', [[0x5e, 0xd0, 0xc6, 255], CLEAR]);
  expect('near-teal inside the radius is caught', 'teal');

  // ...but not outside it.
  reset();
  write('assets/art/v1/env/prop.png', [[0x40, 0xa0, 0x90, 255], CLEAR]);
  expect('a distinct teal-ish green is not caught', null);

  // The allowlisted step glyph may carry it, and only it.
  reset();
  write('assets/ui/v1/glyph_steps.png', [[0x58, 0xd6, 0xc0, 255], CLEAR]);
  expect('the step glyph is allowlisted', null);

  reset();
  write('assets/ui/v1/glyph_other.png', [[0x58, 0xd6, 0xc0, 255], CLEAR]);
  expect('a second teal file is not allowlisted', 'teal');

  // Transparent teal is not ink and is not a collision.
  reset();
  write('assets/art/v1/env/prop.png', [[0x58, 0xd6, 0xc0, 0], CLEAR]);
  expect('fully transparent teal is not ink', null);

  // Semi-transparency, anywhere.
  reset();
  write('assets/art/v1/env/prop.png', [[0x33, 0x29, 0x1f, 128], CLEAR]);
  expect('a semi-transparent pixel is caught', 'alpha');

  // The ceiling binds chrome...
  reset();
  write('assets/ui/v1/frame/card.png', [[0xd0, 0xc8, 0xb0, 255], CLEAR]);
  expect('chrome brighter than textMuted is caught', 'ceiling');

  // ...and does not bind content art, which is pictures and may be bright.
  reset();
  write('assets/art/v1/env/prop.png', [[0xd0, 0xc8, 0xb0, 255], CLEAR]);
  expect('content art is not bound by the chrome ceiling', null);

  // The substrate rule binds frames only.
  reset();
  write('assets/ui/v1/frame/card.png', [[0x20, 0x1c, 0x17, 255], CLEAR]);
  expect('a frame drawn in surfaceCard is caught', 'substrate');

  reset();
  write('assets/ui/v1/frame/card.png', [[0x14, 0x12, 0x0f, 255], CLEAR]);
  expect('a frame drawn in surfaceGround is caught', 'substrate');

  reset();
  write('assets/ui/v1/surface/grain.png', [[0x20, 0x1c, 0x17, 255], CLEAR]);
  expect('a surface may be the card ink -- it is the card', null);

  // A missing tree is not a violation.
  reset();
  expect('an absent art tree is clean, not a violation', null);

  fs.rmSync(work, { recursive: true, force: true });

  process.stdout.write(`\n  art-palette self-test: ${pass} passed, ${failed} failed\n`);
  return failed === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);

  if (args.includes('--self-test')) process.exit(selfTest());

  let result;
  try {
    result = scan(ROOT);
  } catch (err) {
    process.stderr.write(`STRIDE_INFRA[${err.infra ? 'unreadable_art' : 'internal'}] ${err.message}\n`);
    process.exit(2);
  }
  process.exit(report(result));
}

main();
