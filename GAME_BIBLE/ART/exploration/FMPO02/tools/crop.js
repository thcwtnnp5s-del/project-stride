// crop.js — rectangular crop of a PNG (A-2 permitted: invents nothing).
//   node crop.js <in.png> <x> <y> <w> <h> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [inFile, x, y, w, h, outFile] = process.argv.slice(2);
const src = png.load(inFile);
png.save(outFile, png.crop(src, Number(x), Number(y), Number(w), Number(h)));
console.log(`${outFile} ${w}x${h} from (${x},${y})`);
