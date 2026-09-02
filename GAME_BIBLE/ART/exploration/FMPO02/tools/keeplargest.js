'use strict';
// keeplargest.js — deterministic cleanup: erase every opaque connected component
// except the largest one (removes stray specks/artifacts). A-2 permitted:
// invents no new pixels, only clears extras.
//   node keeplargest.js <threshold> <in.png> <out.png>
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [thresholdS, inFile, outFile] = process.argv.slice(2);
const threshold = Number(thresholdS);
const r = png.load(inFile);
const seen = new Uint8Array(r.width * r.height);
const comps = [];
for (let y = 0; y < r.height; y++) {
  for (let x = 0; x < r.width; x++) {
    const i = y * r.width + x;
    if (seen[i]) continue;
    const a = r.data[(i << 2) + 3];
    if (a <= threshold) { seen[i] = 1; continue; }
    const members = [];
    const stack = [i];
    seen[i] = 1;
    while (stack.length) {
      const cur = stack.pop();
      members.push(cur);
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
    comps.push(members);
  }
}
comps.sort((a, b) => b.length - a.length);
for (let c = 1; c < comps.length; c++) {
  for (const idx of comps[c]) {
    r.data[(idx << 2) + 3] = 0;
  }
}
png.save(outFile, r);
console.log(outFile, 'components found:', comps.length, 'kept largest (' + (comps[0]?comps[0].length:0) + 'px), erased', comps.length - 1, 'stray blob(s)');
