'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));
const [a, b] = process.argv.slice(2);
const ra = png.load(a), rb = png.load(b);
if (ra.width !== rb.width || ra.height !== rb.height) { console.log('size differs', ra.width+'x'+ra.height, rb.width+'x'+rb.height); process.exit(0); }
let diff = 0;
for (let i = 0; i < ra.data.length; i++) if (ra.data[i] !== rb.data[i]) diff++;
console.log(a, 'vs', b, '-> differing bytes:', diff, '/', ra.data.length);
