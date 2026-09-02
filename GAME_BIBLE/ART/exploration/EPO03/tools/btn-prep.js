// btn-prep.js — a generated button plate, measured, conformed, and then proved
// to carry every register as a remap.
//
// DECISIONS/0029 forbids raster state variants, so this batch authors ONE plate
// and every register -- commit, attack, defense, ready, equip, craft, travel --
// is a deterministic index remap of it onto an existing hue token (ART-02
// section 3 BTN, ART-13 section 2). The remaps cost nothing, but "cost nothing"
// is not the argument for them; the argument is that a button that is one object
// in seven colours cannot drift apart, and seven authored buttons will.
//
// So this tool does two jobs:
//
//   1. conform   Crop to content, harden alpha, MEASURE the band per side (never
//                assume it -- production plan section 3.2.1 is a whole section
//                about the cost of assuming), and snap the plate onto its ramp.
//                The interior is NOT keyed: a button has a face, unlike a frame.
//
//   2. prove     Emit the register remaps and the two states, from the rules as
//                written rather than from taste:
//                  pressed  = invert the vertical stop order (sheen <-> shadow,
//                             mid stays, specular suppressed)
//                  disabled = the same four luminance ranks with chroma zeroed
//                Both are ART-13 section 2 verbatim, and both are reversible.
//
// Usage:
//   node btn-prep.js <in.png> --ramp <name> --out-dir <dir> --name <btn_plate>
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const { BUTTON } = require('./ramps.js');
const C = require('./colour.js');

const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function hardAlpha(r) {
  let n = 0;
  for (let i = 3; i < r.data.length; i += 4) {
    if (r.data[i] > 0 && r.data[i] < 255) { r.data[i] = r.data[i] >= 128 ? 255 : 0; n += 1; }
  }
  return n;
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
  return png.crop(r, x0, y0, x1 - x0 + 1, y1 - y0 + 1);
}

/**
 * Band = how deep the plate's rim runs before the face begins, measured at the
 * mid-point of each side.
 *
 * The face is the plate's most common ink; the rim is everything between the
 * outer edge and the first run of it. That is a measurement of what was drawn,
 * which is exactly what PanelSkin needs and exactly what section 3.2.1 says
 * nobody may guess.
 */
function measureBand(r) {
  const pop = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const k = (px[0] << 16) | (px[1] << 8) | px[2];
      pop.set(k, (pop.get(k) ?? 0) + 1);
    }
  }
  let face = 0; let n = -1;
  for (const [k, c] of pop) if (c > n) { n = c; face = k; }
  const isFace = (x, y) => {
    const px = P(r, x, y);
    return px[3] === 255 && ((px[0] << 16) | (px[1] << 8) | px[2]) === face;
  };
  const midX = r.width >> 1; const midY = r.height >> 1;
  const walk = (side) => {
    const len = (side === 'top' || side === 'bottom') ? r.height : r.width;
    for (let i = 0; i < len; i += 1) {
      const hit = side === 'top' ? isFace(midX, i)
        : side === 'bottom' ? isFace(midX, r.height - 1 - i)
          : side === 'left' ? isFace(i, midY) : isFace(r.width - 1 - i, midY);
      if (hit) return i;
    }
    return len;
  };
  return {
    face: C.hex((face >> 16) & 255, (face >> 8) & 255, face & 255),
    top: walk('top'), bottom: walk('bottom'), left: walk('left'), right: walk('right'),
  };
}

/** Corner block = how far in the rounded corner reaches before the edge is straight. */
function measureCorner(r) {
  let n = 0;
  for (let i = 0; i < Math.min(r.width, r.height); i += 1) {
    if (P(r, i, 0)[3] === 255) break;
    n = i + 1;
  }
  // A radius of n needs a corner block of at least n + band; report the raw
  // radius and let the sidecar carry the sum.
  return n;
}

function snapTo(r, inks, faceAnchor) {
  const pop = new Map();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y); if (px[3] !== 255) continue;
      const k = (px[0] << 16) | (px[1] << 8) | px[2];
      pop.set(k, (pop.get(k) ?? 0) + 1);
    }
  }
  const steps = [...pop.keys()].sort((a, b) => C.lstar((a >> 16) & 255, (a >> 8) & 255, a & 255)
    - C.lstar((b >> 16) & 255, (b >> 8) & 255, b & 255));
  const assign = new Map();

  // Anchor on the FACE, not on the luminance extremes.
  //
  // Spreading the drawn tones evenly across the ramp puts the plate's largest
  // area -- its face -- on whichever ink its raw luminance rank lands on, and
  // every candidate drew a LIT face, so the face landed on `actionEdge #6B5A3E`
  // and the button came back as a pale tan slab with a dark rim. That is a
  // leather button drawn inside out.
  //
  // ART-13 section 2 assigns the four inks by ROLE, not by rank: shadow / mid /
  // sheen / edge, and the mid ink IS `surfaceRaised` -- the face. So anchor
  // there: the most-used tone becomes the mid, everything darker descends to
  // shadow, everything lighter ascends through sheen to edge. The plate then
  // reads as dark leather with a lit rim, which is the object that was asked
  // for, and the assignment is still one deterministic pass over the histogram.
  if (!faceAnchor) {
    steps.forEach((k, i) => {
      const idx = steps.length === 1 ? 0 : Math.round((i / (steps.length - 1)) * (inks.length - 1));
      assign.set(k, inks[idx]);
    });
  } else {
  let face = steps[0]; let fn = -1;
  for (const [k, c] of pop) if (c > fn) { fn = c; face = k; }
  const fi = steps.indexOf(face);
  const below = fi; const above = steps.length - 1 - fi;
  steps.forEach((k, i) => {
    let idx;
    if (i === fi) idx = 1;
    else if (i < fi) idx = below <= 1 ? 0 : Math.round((i / (below - 1 || 1)) * 1);
    else idx = 2 + Math.round(((i - fi - 1) / (above - 1 || 1)) * (inks.length - 3));
    assign.set(k, inks[Math.max(0, Math.min(inks.length - 1, idx))]);
  });
  }
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const to = assign.get((r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2]);
      if (!to) continue;
      r.data[i] = to[0]; r.data[i + 1] = to[1]; r.data[i + 2] = to[2];
    }
  }
  return steps.length;
}

/** Recolour a plate already on `from` onto `to`, rank for rank. */
function recolour(src, from, to) {
  const r = png.crop(src, 0, 0, src.width, src.height);
  const map = new Map();
  from.forEach((f, i) => map.set(C.hex(...f), to[i]));
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const i = ((y * r.width) + x) << 2;
      if (r.data[i + 3] !== 255) continue;
      const t = map.get(C.hex(r.data[i], r.data[i + 1], r.data[i + 2]));
      if (!t) continue;
      r.data[i] = t[0]; r.data[i + 1] = t[1]; r.data[i + 2] = t[2];
    }
  }
  return r;
}

/** ART-13 section 2: chroma to zero, the four luminance ranks kept. */
function greyLadder(inks) {
  return inks.map((v) => {
    const L = C.lstar(...v);
    const Y = L > 8 ? ((L + 16) / 116) ** 3 : L / 903.3;
    const s = Y <= 0.0031308 ? Y * 12.92 : (1.055 * (Y ** (1 / 2.4))) - 0.055;
    const c = Math.max(0, Math.min(255, Math.round(s * 255)));
    return [c, c, c];
  });
}

function main() {
  const a = process.argv.slice(2);
  const file = a[0];
  const arg = (f, d) => { const i = a.indexOf(f); return i === -1 ? d : a[i + 1]; };
  const rampName = arg('--ramp', 'leather_primary');
  const outDir = arg('--out-dir');
  const name = arg('--name', 'btn_plate');

  const inks = BUTTON[rampName].map((h) => C.parse(h));
  let r = png.loadAny(file);
  const semi = hardAlpha(r);
  const raw = [r.width, r.height];
  r = cropToContent(r);
  const steps = snapTo(r, inks, a.includes('--face-anchor'));
  const band = measureBand(r);
  const radius = measureCorner(r);

  let teal = 0; let over = 0; let semiOut = 0; let maxL = 0; let maxHex = '';
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semiOut += 1;
      if (px[3] !== 255) continue;
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }

  console.log(path.basename(file) + '  ' + raw[0] + 'x' + raw[1] + ' -> ' + r.width + 'x' + r.height);
  console.log('  alpha          ' + semi + ' hardened, ' + semiOut + ' left');
  console.log('  snapped        ' + steps + ' authored tone(s) -> ' + rampName + ' (' + BUTTON[rampName].join(' ') + ')');
  console.log('  face ink       ' + band.face);
  console.log('  band T/B/L/R   ' + band.top + ' / ' + band.bottom + ' / ' + band.left + ' / ' + band.right);
  console.log('  corner radius  ' + radius + '  -> corner block >= ' + (radius + Math.max(band.top, band.left)));
  console.log('  max luminance  ' + maxHex + ' L=' + maxL.toFixed(4) + '  ' + (over ? 'OVER CEILING' : 'under ceiling'));
  console.log('  guards         teal ' + teal + '  semi-alpha ' + semiOut + '  over-ceiling ' + over
    + '  ' + (teal + semiOut + over === 0 ? 'clean' : 'VIOLATION'));

  if (!outDir) return;
  fs.mkdirSync(outDir, { recursive: true });
  png.save(path.join(outDir, name + '.png'), r);

  // Registers: the same plate, every other ART-13 button ramp, rank for rank.
  for (const [reg, hexes] of Object.entries(BUTTON)) {
    if (reg === rampName) continue;
    png.save(path.join(outDir, name + '__' + reg + '.png'), recolour(r, inks, hexes.map((h) => C.parse(h))));
  }
  // Pressed: sheen <-> shadow, mid holds, edge holds. ART-13 section 2.
  png.save(path.join(outDir, name + '__pressed.png'),
    recolour(r, inks, [inks[2], inks[1], inks[0], inks[3]]));
  // Disabled: chroma zero at matched luminance rank.
  png.save(path.join(outDir, name + '__disabled.png'), recolour(r, inks, greyLadder(inks)));
  console.log('  wrote          ' + outDir + '/' + name + '{,__<register>,__pressed,__disabled}.png');
}
main();
