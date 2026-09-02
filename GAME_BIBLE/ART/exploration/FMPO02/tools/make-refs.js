// make-refs.js — deterministic reference crops for PixelLab prompts (A-2: crop only).
//   node make-refs.js
// Copies style anchors and cuts 256x256 windows out of the shipped atlas master
// over the regions the device register names as weak. Nothing is invented.
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const ROOT = path.resolve(__dirname, '../../../../..');
const OUT = path.resolve(__dirname, '../src/ref');
fs.mkdirSync(OUT, { recursive: true });

for (const f of [
  'assets/art/v1/sprite/traveler_south.png',
  'assets/art/v1/sprite/traveler_south_plate.png',
  'assets/art/v1/sprite/traveler_south_jerkin.png',
  'assets/art/v1/sprite/traveler_south_coat.png',
  'assets/ui/v1/frame/chassis_64.png',
]) {
  fs.copyFileSync(path.join(ROOT, f), path.join(OUT, path.basename(f)));
}

const atlas = png.load(path.join(ROOT, 'assets/art/v1/world/atlas_base.png'));
const crops = {
  west_treeline: [0, 300],
  southwest_slab: [0, 700],
  south_layercake: [300, 768],
  south_center: [500, 768],
  frostmere_nw: [0, 0],
  frostmere_n: [300, 0],
  frostmere_ne: [640, 0],
  east_coast: [768, 400],
  south_east: [768, 768],
  west_mid: [0, 500],
};
for (const [k, [x, y]] of Object.entries(crops)) {
  png.save(path.join(OUT, `atlas_${k}_256.png`), png.crop(atlas, x, y, 256, 256));
}
// Half-scale whole atlas is not producible losslessly (no downscale in png.js by
// design); the full master is served from assets/art/v1/world/atlas_base.png.
console.log(fs.readdirSync(OUT).join('\n'));
