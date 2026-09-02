// frame-measure.js — measure a hollow nine-patch candidate the way PanelSkin
// needs it, and say whether it can be one at all.
//
// `band` is the material depth from the outer edge inward to the hole, measured
// at the mid-point of each side. A frame whose four bands disagree cannot be a
// nine-patch: the painter insets content by ONE figure, so an asymmetric rim
// draws the edge over the text on two sides. FMPO02 rejected `nav_plate_32` and
// `banked_cartouche` on exactly this and the reject stands.
//
// `corner` is the block that must contain the whole corner, so it is at least
// the band plus whatever the corner rounds by. Reported, never guessed.
//
//   node frame-measure.js <png...>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

for (const f of process.argv.slice(2).filter((v) => v.endsWith('.png'))) {
  let r = png.loadAny(f);
  // Crop to content first. Pro returns the frame inside a transparent margin,
  // and measuring the band from the CANVAS edge reads 0 on every side — a
  // measurement of the margin, not of the frame.
  {
    let x0 = r.width; let y0 = r.height; let x1 = -1; let y1 = -1;
    for (let y = 0; y < r.height; y += 1) {
      for (let x = 0; x < r.width; x += 1) {
        if (r.data[(((y * r.width) + x) << 2) + 3] !== 0) {
          if (x < x0) x0 = x; if (x > x1) x1 = x;
          if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0) { console.log(`${path.basename(f).padEnd(26)} REJECT (blank)`); continue; }
    r = png.crop(r, x0, y0, (x1 - x0) + 1, (y1 - y0) + 1);
    if (process.argv.includes('--write')) png.save(f.replace(/.png$/, '_crop.png'), r);
  }
  const A = (x, y) => r.data[(((y * r.width) + x) << 2) + 3];
  const mx = r.width >> 1; const my = r.height >> 1;
  const walk = (side) => {
    const n = (side === 'top' || side === 'bottom') ? r.height : r.width;
    for (let i = 0; i < n; i += 1) {
      const a = side === 'top' ? A(mx, i)
        : side === 'bottom' ? A(mx, r.height - 1 - i)
          : side === 'left' ? A(i, my) : A(r.width - 1 - i, my);
      if (a === 0) return i;                    // first transparent px = the hole
    }
    return n;                                   // never opened: solid, not a frame
  };
  const b = { t: walk('top'), b: walk('bottom'), l: walk('left'), r: walk('right') };
  const bands = [b.t, b.b, b.l, b.r];
  const spread = Math.max(...bands) - Math.min(...bands);
  const solid = bands.some((v) => v >= Math.min(r.width, r.height) / 2);

  let opaque = 0; let over = 0; let semi = 0; let maxL = 0; let mh = '';
  for (let i = 0; i < r.data.length; i += 4) {
    const a = r.data[i + 3];
    if (a > 0 && a < 255) semi += 1;
    if (a !== 255) continue;
    opaque += 1;
    const L = C.relLum(r.data[i], r.data[i + 1], r.data[i + 2]);
    if (L > C.CEILING_L) over += 1;
    if (L > maxL) { maxL = L; mh = C.hex(r.data[i], r.data[i + 1], r.data[i + 2]); }
  }
  const verdict = solid ? 'REJECT (no hole - solid plate, not a frame)'
    : opaque === 0 ? 'REJECT (blank)'
      : spread > 1 ? `REJECT (bands disagree by ${spread}px - cannot be one inset)`
        : 'USABLE';
  console.log(`${path.basename(f).padEnd(26)} band T/B/L/R ${b.t}/${b.b}/${b.l}/${b.r}`
    + `  spread ${spread}  opaque ${String(opaque).padStart(4)}  over ${String(over).padStart(4)}`
    + `  max ${mh || '-'} L=${maxL.toFixed(4)}  ${verdict}`);
}
