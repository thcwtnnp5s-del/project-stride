// kit-package.js — the EPO03 UI kit's last deterministic pass: each accepted
// piece at its shipped canvas with a sidecar declaring the geometry the
// integrator needs and nothing it has to guess. Same schema and same guards as
// FMPO02's ui-package.js (GOV-05 §4); the tree it feeds, assets/ui/v1/, is
// hand-maintained on purpose — package-art.js writes assets/art/v1/ and only that.
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const C = require('./colour.js');

const root = path.resolve(__dirname, '..');
const R = (p) => path.join(root, p);
const P = (r, x, y) => { const i = ((y * r.width) + x) << 2; return [r.data[i], r.data[i + 1], r.data[i + 2], r.data[i + 3]]; };

function guards(r) {
  let teal = 0; let semi = 0; let over = 0; let maxL = 0; let maxHex = '';
  const cols = new Set();
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      const px = P(r, x, y);
      if (px[3] > 0 && px[3] < 255) semi += 1;
      if (px[3] !== 255) continue;
      cols.add(C.hex(px[0], px[1], px[2]));
      if (C.cheb(px[0], px[1], px[2], C.TEAL) <= 10) teal += 1;
      const L = C.relLum(px[0], px[1], px[2]);
      if (L > C.CEILING_L) over += 1;
      if (L > maxL) { maxL = L; maxHex = C.hex(px[0], px[1], px[2]); }
    }
  }
  return { teal, semi, over, colours: cols.size, maxHex, maxL: Number(maxL.toFixed(4)),
    verdict: teal + semi + over === 0 ? 'clean' : 'VIOLATION' };
}

function emit(outPath, raster, meta) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  png.save(outPath, raster);
  const g = guards(raster);
  fs.writeFileSync(outPath.replace(/\.png$/, '.json'),
    JSON.stringify({ ...meta, canvas: [raster.width, raster.height], guards: g }, null, 2) + '\n');
  console.log(path.relative(root, outPath).padEnd(38) + `${raster.width}x${raster.height}`
    + `  ${g.colours} colours  max ${g.maxHex} L=${g.maxL}  ${g.verdict}`);
  if (g.verdict !== 'clean') process.exitCode = 1;
}

emit(R('out/ui/nav/nav_welt_v2.png'), png.loadAny(R('out/ui/nav/nav_welt_v2.png')), {
  asset: 'nav_welt_v2',
  destination: 'assets/ui/v1/nav/nav_welt_v2.png',
  kind: 'longitudinal tile, repeated along the top edge of the 64dp nav bar and, at the same '
    + 'period and scale, along the header shelf — one chassis, one stitch (DIR-15 §2)',
  corner: null,
  band: null,
  period: 8,
  scale: 2,
  tiles: 'horizontally only; the last tile is clipped, never rescaled',
  ramp: 'the master\'s own leather, ceiling-clamped; no ramp snap',
  master: 'raw/ui/nav_welt_v2_b.png (pixen 64x32, job 7a0c4880)',
  recipe: {
    crop: 'rows 0-5, the stitch band',
    clamp: 'tools/ceiling-clamp.js — 1 colour / 8 px, #A87353 -> #97674A, linear-light rescale',
    cut: 'tools/tile-cut.js --w 8 --h 6, best-wrapping window at (12,0), join 15.219 / interior 38.341',
  },
  note: 'Replaces nav_welt (8x4). 12 dp at x2, which is the header shelf\'s 12 exactly, so the '
    + 'bar and the header are terminated by the same stitch. The master\'s bottom row was pure '
    + 'white and its two stitch rows sat over the ceiling; the band cut and the clamp are why '
    + 'neither ships.',
});
