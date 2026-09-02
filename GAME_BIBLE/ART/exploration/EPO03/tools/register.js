// register.js — EPO03 EQUIPMENT: undo the whole-frame translation a PixelLab
// re-dress introduces, by registering each edited frame back onto the bounding
// box of the ACCEPTED source frame it was made from.
//
//   node register.js <src-dir> <src-prefix> <edit-dir> <edit-prefix> <frames>
//
// This is a transform, not authoring (A-2), and it is only legal when the edit
// is a pure translation of the source — which the script REFUSES to assume: it
// compares the opaque bounding-box WIDTH and HEIGHT of each pair first, and
// throws if they differ, because a different size means the model redrew the
// figure and a translation would be a lie about what changed. When the sizes
// match, the offset is fully determined (dx = editLeft - srcLeft,
// dy = editBottom - srcBottom) and applying its inverse makes every frame's
// box identical to its source's — which the caller can then verify, rather
// than eyeball.
//
// Why it is needed: the shipped strips are anchored per STRIP, not per frame
// (ART-05 §3 — one window, never a per-frame re-crop). A re-dress that moves
// one frame six pixels right therefore does not "fit better", it makes the
// figure pop on that frame. Re-registering restores the source's own anchor.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [srcDir, srcPrefix, editDir, editPrefix, framesS] = process.argv.slice(2);
const frames = Number(framesS);
for (let i = 0; i < frames; i++) {
  const src = png.load(path.join(srcDir, `${srcPrefix}_f${i}.png`));
  const file = path.join(editDir, `${editPrefix}_f${i}.png`);
  const edit = png.load(file);
  const a = png.bounds(src);
  const b = png.bounds(edit);
  const aw = a.right - a.left, ah = a.bottom - a.top;
  const bw = b.right - b.left, bh = b.bottom - b.top;
  if (aw !== bw || ah !== bh) {
    throw new Error(
      `${editPrefix} f${i}: source box ${aw + 1}x${ah + 1}, edit box ` +
        `${bw + 1}x${bh + 1} — not a translation, refusing to register`,
    );
  }
  const dx = b.left - a.left;
  const dy = b.bottom - a.bottom;
  if (dx === 0 && dy === 0) { console.log(`f${i}: already registered`); continue; }
  const out = new png.Raster(edit.width, edit.height);
  png.blit(out, edit, -dx, -dy);
  png.save(file, out);
  const c = png.bounds(png.load(file));
  if (c.left !== a.left || c.bottom !== a.bottom || c.top !== a.top || c.right !== a.right) {
    throw new Error(`${editPrefix} f${i}: registration did not land on the source box`);
  }
  console.log(`f${i}: moved (${-dx}, ${-dy}) — box now identical to the source`);
}
