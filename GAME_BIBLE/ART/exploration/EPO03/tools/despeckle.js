// FMPO02 — deterministic removal of generation debris from a region result.
//
// Not art authoring: no pixel is invented. Each debris pixel takes the colour
// of the nearest clean pixel from a fixed offset list, exactly like the
// "NW-ice red-fleck despeckle" and "green-confetti cliff cleanup" passes that
// already ship in `Scripts/art/package-art.js` (both labelled deterministic,
// A-2). Run on the raw generation; the cleaned file is what goes to
// `out/atlas/` and what the log's evidence shows.
//
// Predicates:
//   red    warm debris on snow — nothing in the northern snow country is
//          legitimately red (the volcano is at x ≥ 580, far outside).
//   sage   the FINAL-04 #7 debris in the sea ice: a green whose green channel
//          leads red by 40 and blue by 8. Legitimate shelf teal runs the other
//          way (blue leads green), so the two never collide — but grass does
//          match it, which is why this predicate is only ever run under an
//          explicit `--rect` inside the ice.
//
// Usage: node despeckle.js <in.png> <out.png> <kind> [passes] [--rect x0,y0,x1,y1]
// `--rect` is in the coordinates of the file being cleaned.
'use strict';

const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..',
  'Scripts', 'art', 'png.js'));

const PREDICATES = {
  red: (d, i) => d[i] > 140 && d[i] > d[i + 1] + 40 && d[i + 2] + 30 < d[i],
  sage: (d, i) => d[i + 1] > d[i] + 40 && d[i + 1] > d[i + 2] + 8,
};

const OFFSETS = [[0, 2], [0, -2], [2, 0], [-2, 0], [0, 4], [0, -4],
  [4, 0], [-4, 0], [3, 3], [-3, 3], [3, -3], [-3, -3], [0, 6], [6, 0]];

function despeckle(raster, isDebris, passes = 6, rect = null) {
  const [rx0, ry0, rx1, ry1] = rect
    || [0, 0, raster.width, raster.height];
  let removed = 0;
  for (let pass = 0; pass < passes; pass++) {
    const fills = [];
    for (let y = ry0; y < ry1; y++) {
      for (let x = rx0; x < rx1; x++) {
        const i = raster.idx(x, y);
        if (!isDebris(raster.data, i)) continue;
        for (const [ox, oy] of OFFSETS) {
          const sx = x + ox, sy = y + oy;
          if (sx < 0 || sy < 0 || sx >= raster.width || sy >= raster.height) continue;
          const si = raster.idx(sx, sy);
          if (isDebris(raster.data, si)) continue;
          fills.push([i, si]);
          break;
        }
      }
    }
    if (!fills.length) break;
    // Two-phase, so one fill never feeds another within a pass.
    const snapshot = Buffer.from(raster.data);
    for (const [ai, si] of fills) {
      for (let k = 0; k < 4; k++) raster.data[ai + k] = snapshot[si + k];
    }
    removed += fills.length;
  }
  return removed;
}

module.exports = { despeckle, PREDICATES };

if (require.main === module) {
  const argv = process.argv.slice(2);
  const ri = argv.indexOf('--rect');
  const rect = ri < 0 ? null : argv[ri + 1].split(',').map(Number);
  if (ri >= 0) argv.splice(ri, 2);
  const [inFile, outFile, kind, passesArg] = argv;
  const pred = PREDICATES[kind];
  if (!pred) throw new Error(`unknown predicate '${kind}'`);
  const raster = png.load(inFile);
  const removed = despeckle(raster, pred, passesArg ? Number(passesArg) : 6, rect);
  png.save(outFile, raster);
  console.log(`${inFile} -> ${outFile}: ${removed} '${kind}' debris px replaced`);
}
