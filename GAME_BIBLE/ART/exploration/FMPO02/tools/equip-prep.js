// equip-prep.js — deterministic preparation of PixelLab v3 character frames
// into packaging-ready strips (A-2: crop, key detached fragments; invents
// nothing).
//
//   node equip-prep.js <manifest.json> <out-dir>
//
// The manifest is the one PROD-EQUIPMENT writes: an array of sets
//   { id, dir, frames, canvasWidth, verdict }
// where `dir` holds f0..f{frames-1}.png on v3's square canvas (88² for a 64²
// source, 104² for an 80×64 source). For every ACCEPT set this script:
//
//   1. measures the union opaque box across the strip and the lowest opaque
//      row of every frame (the foot row);
//   2. chooses ONE crop window for the whole strip — `canvasWidth` × 64 —
//      placed so the union box's bottom lands on row 62 (the anchor row every
//      shipped Traveler track stands on) and the box is horizontally centred;
//      the window is the same for every frame, so nothing jumps;
//   3. refuses the set if the union box does not fit the window (a wider
//      canvas is a declared fact, never a per-frame re-crop — ART-05 §3);
//   4. keys every opaque pixel not 8-connected to the component containing
//      the lowest foot pixel (the ghost-gear rule packaging enforces later;
//      here it removes the specks the model leaves, and reports how many);
//   5. writes <out-dir>/<id>_f<i>.png and prints one line per set with the
//      measured facts, plus a JSON summary the integrator copies into
//      package-art.js and the CombatTrack tables.
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [manifestFile, outDir] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
const sets = Array.isArray(manifest) ? manifest : manifest.sets;
fs.mkdirSync(outDir, { recursive: true });

const ANCHOR_ROW = 62;
const ROWS = 64;

function alphaAt(r, x, y) {
  return r.data[((y * r.width) + x) * 4 + 3];
}

// The figure is the LARGEST 8-connected component, not the lowest one: a
// chip of swing effect can land below the sole, and flooding from the lowest
// pixel then keeps the chip and deletes the man (found on the plate + axe
// strip, frame 4). Packaging's own guard still floods from the foot, which
// is right for a strip that has already been cleaned.
function attachedMask(r) {
  const w = r.width, h = r.height;
  const opaque = (x, y) => x >= 0 && y >= 0 && x < w && y < h && alphaAt(r, x, y) !== 0;
  const label = new Int32Array(w * h);
  const sizes = [0];
  let next = 1;
  for (let y0 = 0; y0 < h; y0++) {
    for (let x0 = 0; x0 < w; x0++) {
      if (!opaque(x0, y0) || label[y0 * w + x0]) continue;
      const id = next++;
      sizes[id] = 0;
      const stack = [[x0, y0]];
      label[y0 * w + x0] = id;
      while (stack.length) {
        const [cx, cy] = stack.pop();
        sizes[id]++;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
          const nx = cx + dx, ny = cy + dy;
          if (opaque(nx, ny) && !label[ny * w + nx]) { label[ny * w + nx] = id; stack.push([nx, ny]); }
        }
      }
    }
  }
  let best = 0;
  for (let id = 1; id < next; id++) if (sizes[id] > sizes[best]) best = id;
  const seen = new Uint8Array(w * h);
  for (let i = 0; i < label.length; i++) seen[i] = label[i] === best ? 1 : 0;
  return seen;
}

const summary = [];
for (const set of sets) {
  if (set.verdict && set.verdict !== 'ACCEPT') continue;
  const frames = [];
  for (let i = 0; i < set.frames; i++) {
    frames.push(png.load(path.join(set.dir, `f${i}.png`)));
  }
  // Key detached fragments first, then measure — a speck must not widen the
  // union box that decides the window.
  let keyed = 0;
  for (const r of frames) {
    const keep = attachedMask(r);
    for (let y = 0; y < r.height; y++) {
      for (let x = 0; x < r.width; x++) {
        const i = y * r.width + x;
        if (alphaAt(r, x, y) !== 0 && !keep[i]) { r.data[i * 4 + 3] = 0; keyed++; }
      }
    }
  }
  let ux0 = Infinity, uy0 = Infinity, ux1 = -1, uy1 = -1;
  const footRows = [];
  for (const r of frames) {
    const b = png.bounds(r, 1);
    ux0 = Math.min(ux0, b.left); uy0 = Math.min(uy0, b.top);
    ux1 = Math.max(ux1, b.right); uy1 = Math.max(uy1, b.bottom);
    footRows.push(b.bottom);
  }
  const W = set.canvasWidth;
  const boxW = ux1 - ux0 + 1;
  const boxH = uy1 - uy0 + 1;
  // The feet, not the lowest pixel: a tool striking the ground or a motion
  // swoosh can dip below the sole for a frame, and anchoring on that frame
  // would lift the figure off the stage's ground line in every other one.
  // The foot row is the MODE of the per-frame bottoms — the row the figure
  // stands on in most frames.
  const counts = new Map();
  for (const r of footRows) counts.set(r, (counts.get(r) || 0) + 1);
  const footRow = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0] - b[0])[0][0];
  const wy = footRow - ANCHOR_ROW;
  // Centre the window on the union box, then clamp it into the source: a
  // narrow figure on an 88-wide canvas must not push an 80-wide window off
  // the edge, and the clamp changes nothing when the box is wide.
  const wx = Math.max(0, Math.min(frames[0].width - W, Math.round(ux0 + (boxW - W) / 2)));
  const inSrc = wy >= 0 && wx >= 0 && wx + W <= frames[0].width && wy + ROWS <= frames[0].height;
  // Anything outside the window is clipped by the crop. Counted per frame and
  // reported, never silently: above the top it is a raised tool tip, below
  // the feet it is ground contact. The integrator reads the numbers and
  // decides; the tool refuses only when the width does not fit or a frame
  // would lose more than a few pixels off the top.
  const clippedTop = [], clippedBottom = [], clippedSide = [];
  for (const r of frames) {
    let t = 0, b = 0, s = 0;
    for (let y = 0; y < r.height; y++) {
      for (let x = 0; x < r.width; x++) {
        if (alphaAt(r, x, y) === 0) continue;
        if (y < wy) t++;
        else if (y >= wy + ROWS) b++;
        else if (x < wx || x >= wx + W) s++;
      }
    }
    clippedTop.push(t); clippedBottom.push(b); clippedSide.push(s);
  }
  const maxTop = Math.max(...clippedTop);
  const maxSide = Math.max(...clippedSide);
  const fits = inSrc && boxW <= W && maxTop <= (set.maxClipTop ?? 12) && maxSide === 0;
  const line = `${set.id}: ${set.frames}f src ${frames[0].width}x${frames[0].height} union x${ux0}..${ux1} y${uy0}..${uy1} (${boxW}x${boxH}) foot row ${footRow} (bottoms ${footRows.join(',')}) keyed ${keyed}px -> window (${wx},${wy}) ${W}x${ROWS} clipped top ${clippedTop.join(',')} bottom ${clippedBottom.join(',')} ${fits ? 'OK' : 'DOES NOT FIT'}`;
  console.log(line);
  if (!fits) { summary.push({ id: set.id, ok: false, note: line }); continue; }
  for (let i = 0; i < frames.length; i++) {
    png.save(path.join(outDir, `${set.id}_f${i}.png`), png.crop(frames[i], wx, wy, W, ROWS));
  }
  summary.push({
    id: set.id, ok: true, frames: set.frames, canvasWidth: W, canvasHeight: ROWS,
    anchorRow: ANCHOR_ROW, window: [wx, wy], footRowSrc: footRow,
    union: [ux0 - wx, uy0 - wy, ux1 - wx, uy1 - wy],
    keyedPixels: keyed, clippedTop, clippedBottom,
  });
}
fs.writeFileSync(path.join(outDir, 'PREP_SUMMARY.json'), JSON.stringify(summary, null, 2));
console.log(`wrote ${summary.filter((s) => s.ok).length} sets to ${outDir}`);
