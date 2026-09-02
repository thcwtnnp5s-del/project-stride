// EPO03 PROD-WORLD-SOUTH — conform ONE region generation's deep water to the
// atlas's single sea dialect, before the region is composited.
//
// Why this exists (DIR-02 failure mode 2, and the FMPO02 finding "generated
// flat water has never been accepted here"): a mask that reaches open sea
// makes the model invent its own water. S3's roll 2 came back with a grey-teal
// sea (#438383 and neighbours, hundreds of values) where the map's sea is one
// flat #3e98a6. The global ocean conform in package-art.js cannot fix it: its
// rectangles start at x=300, so the south-western wedge has never been inside
// them — which is also why the sea there was already an off-dialect turquoise
// (#4eb9a5 / #2c9da3, 82% of it) before this round.
//
// So the conform is applied here instead, to the region's own pixels, using
// `ocean_unify`'s own algorithm and its own target swatch: measure the region's
// deep-water distribution, map it mean/std onto the target's, and SNAP each
// mapped value to the nearest colour in the target's own palette. Every output
// pixel is therefore a colour the accepted sea is already made of — A-2: a
// palette remap of an approved asset; no object, silhouette or frame invented,
// and nothing averaged. Land, sand, surf and the pale shallows fail
// `isDeep` and are left byte-identical.
//
// Open-water guard (found the hard way): `isDeep` alone also matches the
// blue-green OUTLINE pixels inside dark foliage, and the first run turned the
// south-western wood cyan. A pixel is only conformed when it is deep AND at
// least 80 % of its 9x9 neighbourhood is deep — i.e. it sits in the interior of
// an open water body, never in a tree, a shadow or a one-pixel outline. The
// surf line and the pale shallows are excluded anyway (they fail isDeep).
//
// Usage: node conform-region-water.js <region.png> [out.png]   (in place if no out)
'use strict';
const path = require('path');
const REPO = path.resolve(__dirname, '../../../../..');
const png = require(path.join(REPO, 'Scripts', 'art', 'png.js'));
const ocean = require(path.join(REPO, 'GAME_BIBLE', 'ART', 'exploration',
  'WORLD_ATLAS_COHERENCE_UI_01', 'tools', 'ocean_unify.js'));

const stats = (px) => {
  const m = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) m[k] += p[k];
  for (let k = 0; k < 3; k++) m[k] /= px.length;
  const s = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) s[k] += (p[k] - m[k]) ** 2;
  for (let k = 0; k < 3; k++) s[k] = Math.sqrt(s[k] / px.length) || 1;
  return { m, s };
};

// True where the pixel is deep water AND its 9x9 neighbourhood is >= 80 % deep.
function openWater(im) {
  const W = im.width, H = im.height;
  const deep = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = im.idx(x, y);
      if (ocean.isDeep(im.data[i], im.data[i + 1], im.data[i + 2])) deep[y * W + x] = 1;
    }
  }
  const out = new Uint8Array(W * H);
  const R = 4, NEED = 0.8;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!deep[y * W + x]) continue;
      let n = 0, t = 0;
      for (let dy = -R; dy <= R; dy++) {
        const yy = y + dy; if (yy < 0 || yy >= H) continue;
        for (let dx = -R; dx <= R; dx++) {
          const xx = x + dx; if (xx < 0 || xx >= W) continue;
          t++; if (deep[yy * W + xx]) n++;
        }
      }
      if (n / t >= NEED) out[y * W + x] = 1;
    }
  }
  return out;
}

function conform(region, atlas) {
  const t = ocean.TGT;
  const tgtPx = [];
  for (let y = t.y; y < t.y + t.h; y++) {
    for (let x = t.x; x < t.x + t.w; x++) {
      const i = atlas.idx(x, y);
      const r = atlas.data[i], g = atlas.data[i + 1], b = atlas.data[i + 2];
      if (ocean.isDeep(r, g, b)) tgtPx.push([r, g, b]);
    }
  }
  if (!tgtPx.length) throw new Error('no target water in the atlas TGT swatch');
  const T = stats(tgtPx);
  const palette = [...new Set(tgtPx.map((p) => (p[0] << 16) | (p[1] << 8) | p[2]))]
    .map((v) => [(v >> 16) & 255, (v >> 8) & 255, v & 255]);

  const open = openWater(region);
  const src = [];
  for (let y = 0; y < region.height; y++) {
    for (let x = 0; x < region.width; x++) {
      if (!open[y * region.width + x]) continue;
      const i = region.idx(x, y);
      src.push([region.data[i], region.data[i + 1], region.data[i + 2]]);
    }
  }
  if (!src.length) return 0;
  const A = stats(src);

  let changed = 0;
  for (let y = 0; y < region.height; y++) {
    for (let x = 0; x < region.width; x++) {
      if (!open[y * region.width + x]) continue;
      const i = region.idx(x, y);
      const r = region.data[i], g = region.data[i + 1], b = region.data[i + 2];
      const mapped = [r, g, b].map((v, k) => (v - A.m[k]) * (T.s[k] / A.s[k]) + T.m[k]);
      let best = null, bestD = Infinity;
      for (const p of palette) {
        const d = (p[0] - mapped[0]) ** 2 + (p[1] - mapped[1]) ** 2 + (p[2] - mapped[2]) ** 2;
        if (d < bestD) { bestD = d; best = p; }
      }
      if (best[0] !== r || best[1] !== g || best[2] !== b) changed++;
      region.data[i] = best[0]; region.data[i + 1] = best[1]; region.data[i + 2] = best[2];
    }
  }
  return changed;
}

module.exports = { conform };

if (require.main === module) {
  const [inFile, outFile] = process.argv.slice(2);
  if (!inFile) { console.error('usage: node conform-region-water.js <region.png> [out.png]'); process.exit(2); }
  const region = png.load(inFile);
  const atlas = png.load(path.join(REPO, 'assets', 'art', 'v1', 'world', 'atlas_base.png'));
  const n = conform(region, atlas);
  png.save(outFile || inFile, region);
  console.log(`conformed ${n} deep-water px to the atlas sea dialect -> ${outFile || inFile}`);
}
