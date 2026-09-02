'use strict';
// checkframes.js — reports bounds + opaque 8-connected component count per frame.
//   node checkframes.js <threshold> <f0.png> <f1.png> ...
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const threshold = Number(process.argv[2]);
const files = process.argv.slice(3);
for (const f of files) {
  const r = png.load(f);
  const b = png.bounds(r, threshold);
  // connected components over alpha>threshold, 8-connectivity
  const seen = new Uint8Array(r.width * r.height);
  let comps = 0, largest = 0;
  for (let y = 0; y < r.height; y++) {
    for (let x = 0; x < r.width; x++) {
      const i = y * r.width + x;
      if (seen[i]) continue;
      const a = r.data[(i << 2) + 3];
      if (a <= threshold) { seen[i] = 1; continue; }
      // flood fill
      let size = 0;
      const stack = [i];
      seen[i] = 1;
      while (stack.length) {
        const cur = stack.pop();
        size++;
        const cx = cur % r.width, cy = (cur / r.width) | 0;
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = cx + dx, ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= r.width || ny >= r.height) continue;
          const ni = ny * r.width + nx;
          if (seen[ni]) continue;
          if (r.data[(ni << 2) + 3] <= threshold) { seen[ni] = 1; continue; }
          seen[ni] = 1;
          stack.push(ni);
        }
      }
      comps++;
      if (size > largest) largest = size;
    }
  }
  console.log(`${f}\t${r.width}x${r.height}\tbounds=${b.left},${b.top}..${b.right},${b.bottom} (${b.right-b.left+1}x${b.bottom-b.top+1})\tcomponents=${comps}\tlargestPx=${largest}`);
}
