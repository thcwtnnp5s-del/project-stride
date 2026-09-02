'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
for (const f of process.argv.slice(2)) {
  const r = png.load(f);
  const b = png.bounds ? png.bounds(r) : null;
  console.log(f, r.width + 'x' + r.height, b ? JSON.stringify(b) : '');
}
