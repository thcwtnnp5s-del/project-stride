// Crop a region of a PNG and emit it as a base64 data: URL for PixelLab MCP
// image_url parameters. Pads the PNG byte length to a multiple of 3 with
// trailing zero bytes AFTER IEND (harmless to decoders) so the base64 string
// carries no '=' padding — the WMP-recorded transport strips trailing '='.
//
// Usage: node cropurl.js <src.png> <x> <y> <w> <h> [--save out.png]
// Prints the data URL to stdout (one line).
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.join(__dirname, '..', '..', '..', '..', '..', 'Scripts', 'art', 'png.js'));

const [src, x, y, w, h] = process.argv.slice(2);
const saveIdx = process.argv.indexOf('--save');
const raster = png.load(src);
const out = png.crop(raster, Number(x), Number(y), Number(w), Number(h));
const tmp = path.join(require('os').tmpdir(), `cropurl_${process.pid}.png`);
png.save(tmp, out);
let bytes = fs.readFileSync(tmp);
fs.unlinkSync(tmp);
if (saveIdx !== -1) fs.writeFileSync(process.argv[saveIdx + 1], bytes);
const pad = (3 - (bytes.length % 3)) % 3;
if (pad) bytes = Buffer.concat([bytes, Buffer.alloc(pad)]);
process.stdout.write('data:image/png;base64,' + bytes.toString('base64'));
