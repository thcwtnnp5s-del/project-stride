// paste.js — EPO03 GATHER: blit a repaired band back into its parent image at
// the offset it was cut from, and assert every pixel outside the band is
// byte-identical to the parent (A-2: a transform, invents nothing).
//   node paste.js <parent.png> <band.png> <ox> <oy> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [parentFile, bandFile, oxS, oyS, outFile] = process.argv.slice(2);
const ox = Number(oxS);
const oy = Number(oyS);
const parent = png.load(parentFile);
const band = png.load(bandFile);
const out = png.crop(parent, 0, 0, parent.width, parent.height);
png.blit(out, band, ox, oy);

// The margin outside the pasted band must not have moved. An inpaint that
// silently shifted or recoloured the frozen area is a different picture, not
// a repair, and this is the only place that would catch it.
let moved = 0;
for (let y = 0; y < parent.height; y++) {
  for (let x = 0; x < parent.width; x++) {
    if (x >= ox && x < ox + band.width && y >= oy && y < oy + band.height) continue;
    const i = (y * parent.width + x) * 4;
    for (let c = 0; c < 4; c++) if (out.data[i + c] !== parent.data[i + c]) { moved += 1; c = 4; }
  }
}
if (moved) throw new Error(`paste: ${moved} px changed outside the band — margins are not frozen`);
png.save(outFile, out);
console.log(`${outFile} ${out.width}x${out.height} — band ${band.width}x${band.height} at (${ox},${oy}), margins frozen`);
