// weapon-presence.js — does the held weapon survive every frame of a track?
//
// The VAWO01 equipment round deferred combat weapon variants on a measured
// finding: PixelLab's TEMPLATE animations discard held props, and the failure
// was invisible until the frames were laid side by side. This is that
// inspection, automated, so a later round cannot ship the same defect by
// glancing at a contact sheet.
//
// ## Why this measures the SILHOUETTE and not the blade's colour
//
// The obvious check — count pixels in the blade's colour family — was written
// first and is useless here. The bronze blade shares its hue band with the
// Traveler's own leather, boots and scarf, so the count stays high on a frame
// with no sword at all. It passed a template idle that is visibly bare-handed.
//
// A sword is a long thin mass sticking out of the body. What it reliably
// changes is the opaque silhouette's WIDTH, so that is what is measured: the
// per-frame bounding box, against the widest frame in the same track. A frame
// that loses the weapon loses the reach that came with it.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

function bbox(r) {
  let x0 = r.width, x1 = -1;
  for (let y = 0; y < r.height; y += 1) {
    for (let x = 0; x < r.width; x += 1) {
      if (r.data[(((y * r.width) + x) << 2) + 3] !== 0) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
      }
    }
  }
  return x1 < 0 ? 0 : x1 - x0 + 1;
}

const [track, countArg, floorArg] = process.argv.slice(2);
const count = Number(countArg);
// A drawn arm swing changes reach a little; a dropped sword changes it a lot.
const ratio = floorArg ? Number(floorArg) : 0.78;

const widths = [];
for (let i = 0; i < count; i += 1) {
  widths.push(bbox(png.loadAny(`raw/equip/tracks/${track}_f${i}.png`)));
}
const max = Math.max(...widths);
const floor = Math.round(max * ratio);
const bad = widths.map((w, i) => [i, w]).filter(([, w]) => w < floor);

console.log(`${track}: silhouette width per frame ${widths.join(' ')}`);
console.log(`  widest ${max}, floor ${floor} (${ratio}x)`);
console.log(`  ${bad.length ? 'REJECT — weapon reach lost at ' + bad.map(([i, w]) => `f${i}=${w}`).join(' ') : 'PASS — reach held in every frame'}`);
process.exit(bad.length ? 1 : 0);
