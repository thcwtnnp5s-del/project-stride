// EPO03 LANDMARKS — assemble the storm-rain loop deterministically (A-2: blit only).
// animate_image emptied the rain from 6 of 8 frames (ledger c7f6305b), so the
// rain body is the accepted still's own streaks scrolled diagonally with wrap
// (every pixel is an authored pixel of rain_still.png), and the churning cloud
// wisps (rows 0..WISP-1) are taken from the animate frames, which did move.
//   node rain-assemble.js <still.png> <animDir/prefix> <outDir/prefix> <frames> <wisp rows> <dx> <dy>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [stillP, animP, outP, framesS, wispS, dxS, dyS] = process.argv.slice(2);
const still = png.load(stillP);
const F = Number(framesS), WISP = Number(wispS), dx = Number(dxS), dy = Number(dyS);
const W = still.width, H = still.height;
for (let f = 0; f < F; f++) {
  const out = new png.Raster(W, H);
  const anim = png.load(`${animP}${f + 1}.png`); // animate frame 1..F (0 is the input)
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let src, sx, sy;
    if (y < WISP) { src = anim; sx = x; sy = y; }
    else {
      src = still;
      sx = ((x - dx * f) % W + W) % W;
      sy = WISP + (((y - WISP - dy * f) % (H - WISP)) + (H - WISP)) % (H - WISP);
    }
    const si = src.idx(sx, sy), oi = out.idx(x, y);
    for (let k = 0; k < 4; k++) out.data[oi + k] = src.data[si + k];
  }
  png.save(`${outP}${f}.png`, out);
}
console.log(`${F} frames -> ${outP}*.png (wisps rows 0..${WISP - 1} from anim, rain scrolled ${dx},${dy}/frame)`);
