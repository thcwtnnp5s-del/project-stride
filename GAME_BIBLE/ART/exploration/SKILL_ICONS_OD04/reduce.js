const png = require('../../../../Scripts/art/png.js');
const D = require('path').join(__dirname, 'out');

/** 48 -> 12 by 4x4 blocks: dominant colour, ties to the darker, <half opaque clears. */
function reduce(src) {
  const out = new png.Raster(12, 12);
  for (let by = 0; by < 12; by++) for (let bx = 0; bx < 12; bx++) {
    const tally = new Map();
    let opaque = 0;
    for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) {
      const i = src.idx(bx * 4 + x, by * 4 + y);
      if (src.data[i + 3] < 128) continue;
      opaque++;
      const k = `${src.data[i]},${src.data[i + 1]},${src.data[i + 2]}`;
      const e = tally.get(k) || { n: 0, lum: 0.299 * src.data[i] + 0.587 * src.data[i + 1] + 0.114 * src.data[i + 2] };
      e.n++;
      tally.set(k, e);
    }
    const o = out.idx(bx, by);
    if (opaque < 8) { out.data[o + 3] = 0; continue; }
    let best = null, bestE = null;
    for (const [k, e] of tally) {
      if (!bestE || e.n > bestE.n || (e.n === bestE.n && e.lum < bestE.lum)) { best = k; bestE = e; }
    }
    const [r, g, b] = best.split(',').map(Number);
    out.data[o] = r; out.data[o + 1] = g; out.data[o + 2] = b; out.data[o + 3] = 255;
  }
  return out;
}

const names = ['foraging', 'woodcutting', 'mining', 'smithing', 'cooking'];
const cell = 104, W = cell * names.length, H = 96;
const sheet = new png.Raster(W, H);
names.forEach((n, k) => {
  const small = reduce(png.load(`${D}/${n}_48.png`));
  png.save(`${D}/${n}_12.png`, small);
  png.blit(sheet, png.scale(small, 8), k * cell, 0);
});
png.save(`${D}/contact_x8.png`, sheet);

// Also a x2 strip — the verdict scale (MISTAKES M-05).
const s2 = new png.Raster(names.length * 32, 24);
names.forEach((n, k) => png.blit(s2, png.scale(png.load(`${D}/${n}_12.png`), 2), k * 32 + 4, 0));
png.save(`${D}/contact_x2.png`, s2);
console.log('wrote 12px icons, x8 and x2 contact sheets');
