// test-candidates.js — run the check-item-distinctness.js metrics between
// arbitrary local files (candidates vs shipped siblings), not just by item id
// in assets/art/v1/item. Lets PROD-ITEMS pick the numerically best candidate
// before committing to one.
//   node test-candidates.js <fileA> <fileB> [<fileA2> <fileB2> ...]
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const ALPHA_THRESHOLD = 8;
const CANVAS = 96;

function centroid(raster) {
  let sx = 0; let sy = 0; let n = 0;
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= ALPHA_THRESHOLD) continue;
      sx += x; sy += y; n++;
    }
  }
  if (n === 0) return null;
  return { x: sx / n, y: sy / n };
}
function alignedMask(raster) {
  const c = centroid(raster);
  const mask = new Uint8Array(CANVAS * CANVAS);
  if (!c) return mask;
  const ox = Math.round(CANVAS / 2 - c.x);
  const oy = Math.round(CANVAS / 2 - c.y);
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      if (raster.data[raster.idx(x, y) + 3] <= ALPHA_THRESHOLD) continue;
      const dx = x + ox; const dy = y + oy;
      if (dx < 0 || dy < 0 || dx >= CANVAS || dy >= CANVAS) continue;
      mask[dy * CANVAS + dx] = 1;
    }
  }
  return mask;
}
function alignedLightMask(raster) {
  const c = centroid(raster);
  const mask = new Uint8Array(CANVAS * CANVAS);
  if (!c) return mask;
  const lums = [];
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
      lums.push(0.299 * raster.data[i] + 0.587 * raster.data[i + 1] + 0.114 * raster.data[i + 2]);
    }
  }
  lums.sort((a, b) => a - b);
  const median = lums.length ? lums[lums.length >> 1] : 128;
  const ox = Math.round(CANVAS / 2 - c.x);
  const oy = Math.round(CANVAS / 2 - c.y);
  for (let y = 0; y < raster.height; y++) {
    for (let x = 0; x < raster.width; x++) {
      const i = raster.idx(x, y);
      if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
      const lum = 0.299 * raster.data[i] + 0.587 * raster.data[i + 1] + 0.114 * raster.data[i + 2];
      if (lum < median) continue;
      const dx = x + ox; const dy = y + oy;
      if (dx < 0 || dy < 0 || dx >= CANVAS || dy >= CANVAS) continue;
      mask[dy * CANVAS + dx] = 1;
    }
  }
  return mask;
}
function iou(a, b) {
  let inter = 0; let union = 0;
  for (let i = 0; i < a.length; i++) {
    if (a[i] || b[i]) union++;
    if (a[i] && b[i]) inter++;
  }
  return union === 0 ? 0 : inter / union;
}
function colourHistogramIntersection(a, b) {
  const BINS = 16;
  function hist(raster) {
    const h = [new Float64Array(BINS), new Float64Array(BINS), new Float64Array(BINS)];
    let n = 0;
    for (let y = 0; y < raster.height; y++) {
      for (let x = 0; x < raster.width; x++) {
        const i = raster.idx(x, y);
        if (raster.data[i + 3] <= ALPHA_THRESHOLD) continue;
        for (let c = 0; c < 3; c++) {
          const bin = Math.min(BINS - 1, (raster.data[i + c] / 256 * BINS) | 0);
          h[c][bin]++;
        }
        n++;
      }
    }
    if (n > 0) for (let c = 0; c < 3; c++) for (let k = 0; k < BINS; k++) h[c][k] /= n;
    return h;
  }
  const ha = hist(a); const hb = hist(b);
  let total = 0;
  for (let c = 0; c < 3; c++) {
    let s = 0;
    for (let k = 0; k < BINS; k++) s += Math.min(ha[c][k], hb[c][k]);
    total += s;
  }
  return total / 3;
}

const files = process.argv.slice(2);
for (let i = 0; i < files.length; i += 2) {
  const a = png.loadAny(files[i]);
  const b = png.loadAny(files[i + 1]);
  const shapeIoU = iou(alignedMask(a), alignedMask(b));
  const colourIntersection = colourHistogramIntersection(a, b);
  const greyIoU = iou(alignedLightMask(a), alignedLightMask(b));
  const collision = shapeIoU > 0.55 && colourIntersection > 0.6;
  const hueOnly = colourIntersection > 0.6 && Math.abs(greyIoU - shapeIoU) <= 0.05;
  const watch = !collision && (shapeIoU > 0.55 || colourIntersection > 0.6);
  const verdict = hueOnly ? 'HUE_ONLY' : collision ? 'COLLISION' : watch ? 'WATCH' : 'PASS';
  console.log(`${path.basename(files[i])} vs ${path.basename(files[i + 1])}: shape=${shapeIoU.toFixed(3)} colour=${colourIntersection.toFixed(3)} grey=${greyIoU.toFixed(3)} -> ${verdict}`);
}
