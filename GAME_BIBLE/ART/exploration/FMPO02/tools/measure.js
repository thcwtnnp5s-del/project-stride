// measure.js — per-frame geometry + gear census for a track. Reads only; invents nothing.
//   node measure.js <frame1.png> [frame2.png ...]
// Prints JSON: per-frame {file,w,h,bbox,footRow,opaque,attached,detached,bronze,steel}
// plus union bbox and the union foot row across the set.
//
// bronze  = warm reddish-copper ramp (r > g > b, r-b >= 40, r >= 90) — ART-01 says
//           bronze must never read gold, so a gold-leaning pixel (g close to r) is
//           counted separately as "gold" and a nonzero gold count is a smell.
// steel   = near-neutral mid/light grey (max-min <= 18, 90 <= max <= 210)
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const A = 8; // alpha threshold, matches png.bounds

function analyse(file) {
  const r = png.load(file);
  const box = png.bounds(r);
  if (box === null) return { file: path.basename(file), w: r.width, h: r.height, empty: true };

  let opaque = 0; let bronze = 0; let gold = 0; let steel = 0; let partial = 0;
  const solid = new Uint8Array(r.width * r.height);
  for (let y = 0; y < r.height; y++) {
    for (let x = 0; x < r.width; x++) {
      const i = r.idx(x, y);
      const a = r.data[i + 3];
      if (a <= A) continue;
      if (a < 255) partial++;
      solid[y * r.width + x] = 1;
      opaque++;
      const cr = r.data[i]; const cg = r.data[i + 1]; const cb = r.data[i + 2];
      const mx = Math.max(cr, cg, cb); const mn = Math.min(cr, cg, cb);
      if (cr > cg && cg > cb && cr - cb >= 40 && cr >= 90) {
        if (cr - cg <= 12 && cg - cb >= 45) gold++; else bronze++;
      }
      if (mx - mn <= 18 && mx >= 90 && mx <= 210) steel++;
    }
  }

  // 8-connected flood from every opaque pixel on the lowest opaque row.
  const seen = new Uint8Array(r.width * r.height);
  const stack = [];
  for (let x = 0; x < r.width; x++) {
    if (solid[box.bottom * r.width + x]) { stack.push(box.bottom * r.width + x); seen[box.bottom * r.width + x] = 1; }
  }
  let attached = 0;
  while (stack.length) {
    const p = stack.pop(); attached++;
    const py = (p / r.width) | 0; const px = p % r.width;
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        const nx = px + dx; const ny = py + dy;
        if (nx < 0 || ny < 0 || nx >= r.width || ny >= r.height) continue;
        const q = ny * r.width + nx;
        if (!solid[q] || seen[q]) continue;
        seen[q] = 1; stack.push(q);
      }
    }
  }

  return {
    file: path.basename(file),
    w: r.width,
    h: r.height,
    bbox: [box.left, box.top, box.right - box.left + 1, box.bottom - box.top + 1],
    footRow: box.bottom,
    opaque, attached, detached: opaque - attached, partial,
    bronze, gold, steel,
  };
}

const files = process.argv.slice(2);
const frames = files.map(analyse);
const live = frames.filter((f) => !f.empty);
const u = live.reduce((acc, f) => {
  const [x, y, w, h] = f.bbox;
  return {
    left: Math.min(acc.left, x), top: Math.min(acc.top, y),
    right: Math.max(acc.right, x + w - 1), bottom: Math.max(acc.bottom, y + h - 1),
  };
}, { left: Infinity, top: Infinity, right: -1, bottom: -1 });

console.log(JSON.stringify({
  frames,
  canvas: live.length ? `${live[0].w}x${live[0].h}` : null,
  union_bbox: live.length ? [u.left, u.top, u.right - u.left + 1, u.bottom - u.top + 1] : null,
  foot_row: live.length ? u.bottom : null,
  foot_row_min: live.length ? Math.min(...live.map((f) => f.footRow)) : null,
  detached_frames: live.filter((f) => f.detached > 0).map((f) => `${f.file}:${f.detached}`),
  gold_frames: live.filter((f) => f.gold > 0).map((f) => `${f.file}:${f.gold}`),
  partial_alpha_frames: live.filter((f) => f.partial > 0).map((f) => `${f.file}:${f.partial}`),
}, null, 1));
