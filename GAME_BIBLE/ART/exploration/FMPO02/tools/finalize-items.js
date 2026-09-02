// finalize-items.js — verify each accepted candidate (48x48, zero partial
// alpha) and copy it to out/items/icon_<name>_48.png.
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const OUT = path.resolve(__dirname, '../out/items');
fs.mkdirSync(OUT, { recursive: true });

const PICKS = [
  ['hearty_stew', '../raw/items/hearty_stew/c1.png'],
  ['goblin_toothed_axe', '../raw/items/goblin_toothed_axe/c1.png'],
  ['tinbraced_pickaxe', '../raw/items/tinbraced_pickaxe/c1.png'],
  ['clawguard_coat', '../raw/items/clawguard_coat/c1.png'],
  ['lynx_pelt', '../raw/items/lynx_pelt/c3.png'],
  ['pristine_horn', '../raw/items/pristine_horn/c1.png'],
  ['scalewarmed_chestplate', '../raw/items/scalewarmed_chestplate/c1.png'],
  ['bronze_longsword', '../raw/items/bronze_longsword/c1.png'],
  ['fanghilt_sword', '../raw/items/fanghilt_sword/c2.png'],
  ['reclaim_axe', '../raw/items/reclaim_bronze_axe/c1.png'],
  ['reclaim_pickaxe', '../raw/items/reclaim_bronze_pickaxe/c1.png'],
  ['reclaim_chestplate', '../raw/items/reclaim_bronze_chestplate/c1.png'],
];

let allOk = true;
for (const [name, rel] of PICKS) {
  const src = path.resolve(__dirname, rel);
  const raster = png.loadAny(src);
  const problems = [];
  if (raster.width !== 48 || raster.height !== 48) {
    problems.push(`canvas ${raster.width}x${raster.height} != 48x48`);
  }
  let partialAlpha = 0;
  for (let i = 3; i < raster.data.length; i += 4) {
    const a = raster.data[i];
    if (a !== 0 && a !== 255) partialAlpha++;
  }
  if (partialAlpha > 0) problems.push(`${partialAlpha} partially-transparent pixels`);

  const out = path.join(OUT, `icon_${name}_48.png`);
  png.save(out, raster);
  if (problems.length) {
    allOk = false;
    console.log(`FAIL ${name}: ${problems.join('; ')} -> still wrote ${out} for inspection`);
  } else {
    console.log(`OK   ${name} -> ${out} (48x48, alpha binary)`);
  }
}
if (!allOk) process.exitCode = 1;
