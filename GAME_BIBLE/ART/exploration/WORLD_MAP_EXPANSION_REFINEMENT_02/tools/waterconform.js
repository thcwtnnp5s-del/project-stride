// Deterministic water-palette conform (A-2: palette remap of an approved
// asset — invents no object, silhouette or frame).
//
// Classifies "water" pixels in the source tile (teal family, excludes
// near-white floes and dark rock), matches their per-channel mean/std to the
// water of a target tile, then snaps every remapped pixel to the nearest
// actual water color of the target so the result stays on the target's
// palette.
//
// Usage: node waterconform.js <src.png> <target.png> <out.png>
//        node waterconform.js <src.png> <targetTop.png> <out.png> --bottom <targetBottom.png>
//
// With --bottom, the remap blends per row from the top target's water stats
// at y=0 to the bottom target's at y=h-1, and snaps to the union of both
// water palettes — a vertical temperature gradient using only approved
// colors.
'use strict';
const path = require('path');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const [srcFile, tgtFile, outFile] = process.argv.slice(2);
const src = png.load(srcFile);
const tgt = png.load(tgtFile);

const lum = (r, g, b) => 0.299 * r + 0.587 * g + 0.114 * b;
const snowMode = process.argv.includes('--snow');
const isWater = snowMode
  ? (r, g, b) => {
      // snow family: bright, cool, low-saturation (excludes rock and trees)
      const L = lum(r, g, b);
      const spread = Math.max(r, g, b) - Math.min(r, g, b);
      return L >= 140 && spread < 70 && b >= r;
    }
  : (r, g, b) => {
      const L = lum(r, g, b);
      if (L > 215 || L < 55) return false; // floes / rock
      // teal family: blue and green dominate red
      return b >= r + 10 && g >= r + 5;
    };

const collect = (ras) => {
  const px = [];
  for (let i = 0; i < ras.data.length; i += 4) {
    const [r, g, b] = [ras.data[i], ras.data[i + 1], ras.data[i + 2]];
    if (isWater(r, g, b)) px.push([r, g, b]);
  }
  return px;
};

const stats = (px) => {
  const m = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) m[k] += p[k];
  for (let k = 0; k < 3; k++) m[k] /= px.length;
  const s = [0, 0, 0];
  for (const p of px) for (let k = 0; k < 3; k++) s[k] += (p[k] - m[k]) ** 2;
  for (let k = 0; k < 3; k++) s[k] = Math.sqrt(s[k] / px.length) || 1;
  return { m, s };
};

const bIdx = process.argv.indexOf('--bottom');
const tgtBottom = bIdx !== -1 ? png.load(process.argv[bIdx + 1]) : null;

const srcW = collect(src);
const tgtW = collect(tgt);
if (!srcW.length || !tgtW.length) throw new Error('no water classified');
const a = stats(srcW);
const t = stats(tgtW);
const tgtBW = tgtBottom ? collect(tgtBottom) : null;
const tB = tgtBW && tgtBW.length ? stats(tgtBW) : null;

// Unique target water palette for snapping (union when a bottom target given).
const allTgt = tB ? tgtW.concat(tgtBW) : tgtW;
const palette = [...new Set(allTgt.map((p) => (p[0] << 16) | (p[1] << 8) | p[2]))].map((v) => [
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
]);

const out = src.clone();
for (let i = 0; i < out.data.length; i += 4) {
  const [r, g, b] = [out.data[i], out.data[i + 1], out.data[i + 2]];
  if (!isWater(r, g, b)) continue;
  const y = Math.floor(i / 4 / out.width);
  const f = tB ? y / (out.height - 1) : 0;
  const mapped = [r, g, b].map((v, k) => {
    const mm = tB ? t.m[k] * (1 - f) + tB.m[k] * f : t.m[k];
    const ss = tB ? t.s[k] * (1 - f) + tB.s[k] * f : t.s[k];
    return (v - a.m[k]) * (ss / a.s[k]) + mm;
  });
  let best = null;
  let bestD = Infinity;
  for (const p of palette) {
    const d = (p[0] - mapped[0]) ** 2 + (p[1] - mapped[1]) ** 2 + (p[2] - mapped[2]) ** 2;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  out.data[i] = best[0];
  out.data[i + 1] = best[1];
  out.data[i + 2] = best[2];
}
png.save(outFile, out);
console.log(`conformed ${srcW.length} water px onto ${palette.length} target colors -> ${outFile}`);
