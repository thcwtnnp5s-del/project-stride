// Old set (top row) against the OD-04 round (bottom row), at x8 and at x2.
// Unlabelled and in a fixed order, so the two rows are compared as sets.
const path = require('path');
const png = require('../../../../Scripts/art/png.js');

const D = path.join(__dirname, 'out');
const UI = path.join(__dirname, '..', '..', '..', '..', 'assets', 'ui', 'v1');
const names = ['foraging', 'woodcutting', 'mining', 'smithing', 'cooking'];

for (const [factor, file] of [[8, 'compare_x8.png'], [2, 'compare_x2.png']]) {
  const size = 12 * factor;
  const cell = size + 8;
  const sheet = new png.Raster(cell * names.length, size * 2 + 12);
  names.forEach((n, k) => {
    png.blit(sheet, png.scale(png.load(path.join(UI, `skill_${n}.png`)), factor), k * cell + 4, 0);
    png.blit(sheet, png.scale(png.load(path.join(D, `${n}_12.png`)), factor), k * cell + 4, size + 12);
  });
  png.save(path.join(D, file), sheet);
}
console.log('wrote compare_x8.png and compare_x2.png');
