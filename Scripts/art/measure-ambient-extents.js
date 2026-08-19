// Measures the opaque extents of the ambient scene art and the node vignettes,
// for the composition table in `lib/ui/icons/ambient_assets.dart`.
//
// For the gather sequence under `assets/art/v1/anim/` and every ambient
// sequence under `assets/art/v1/ambient/` the union opaque
// bounding box across all of its frames is printed — the box a scene's layout
// must reserve for that track whatever frame is showing. For every node
// vignette under `assets/art/v1/node/` the single-frame opaque box is printed.
//
// Read-only. Reads the packaged art, never the exploration sources, so what is
// measured is exactly what ships. Run:
//
//   node Scripts/art/measure-ambient-extents.js
'use strict';

const fs = require('fs');
const path = require('path');
const png = require('./png.js');

const ROOT = path.resolve(__dirname, '..', '..');
const AMBIENT = path.join(ROOT, 'assets', 'art', 'v1', 'ambient');
const ANIM = path.join(ROOT, 'assets', 'art', 'v1', 'anim');
const NODE = path.join(ROOT, 'assets', 'art', 'v1', 'node');

function union(a, b) {
  if (a === null) return b;
  if (b === null) return a;
  return {
    left: Math.min(a.left, b.left),
    top: Math.min(a.top, b.top),
    right: Math.max(a.right, b.right),
    bottom: Math.max(a.bottom, b.bottom),
  };
}

function fmt(box) {
  return `left ${box.left} top ${box.top} right ${box.right} bottom ${box.bottom}`;
}

const sequences = new Map();
const files = [
  ...fs.readdirSync(ANIM).sort().map((f) => path.join(ANIM, f)),
  ...fs.readdirSync(AMBIENT).sort().map((f) => path.join(AMBIENT, f)),
];
for (const file of files) {
  const m = /^(.*)_f(\d+)\.png$/.exec(path.basename(file));
  if (!m) continue;
  const raster = png.load(file);
  const entry = sequences.get(m[1]) ?? {
    frames: 0,
    width: raster.width,
    height: raster.height,
    box: null,
  };
  entry.frames += 1;
  entry.box = union(entry.box, png.bounds(raster));
  sequences.set(m[1], entry);
}

console.log('# gather and ambient sequences — union opaque bounds across all frames');
for (const [id, e] of sequences) {
  console.log(
    `${id.padEnd(24)} ${e.frames} frames ${e.width}x${e.height}  ${fmt(e.box)}`,
  );
}

console.log('\n# node vignettes — opaque bounds');
for (const file of fs.readdirSync(NODE).sort()) {
  if (!file.endsWith('.png')) continue;
  const raster = png.load(path.join(NODE, file));
  console.log(
    `${file.padEnd(24)} ${raster.width}x${raster.height}  ${fmt(png.bounds(raster))}`,
  );
}
