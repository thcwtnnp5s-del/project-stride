// pad.js — EPO03 EQUIPMENT: place a frame on a larger transparent canvas at a
// fixed offset (A-2: a transform, invents nothing). Used to give a v3 start
// frame room for a longer blade before the edit, so the canvas — not the
// model — decides where the tip may reach.
//   node pad.js <in.png> <out.png> <W> <H> <ox> <oy>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, outFile, W, H, ox, oy] = process.argv.slice(2);
const src = png.load(inFile);
const dst = new png.Raster(Number(W), Number(H));
png.blit(dst, src, Number(ox), Number(oy));
png.save(outFile, dst);
console.log(`${outFile} ${W}x${H} (src ${src.width}x${src.height} at ${ox},${oy})`);
