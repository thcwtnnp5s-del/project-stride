// make-item-sheets.js — build one in-context review sheet per item: the
// candidates, then the current shipped icon and its family siblings, at x2 on
// #14120F. A2-permitted: scale + blit + fill only, invents no pixels.
//   node make-item-sheets.js
'use strict';
const path = require('path');
const fs = require('fs');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const ROOT = path.resolve(__dirname, '../../../../..');
const RAW = path.resolve(__dirname, '../raw/items');
const OUT = path.resolve(__dirname, '../review/items');
const SHIPPED = path.join(ROOT, 'assets/art/v1/item');

const BG = [0x14, 0x12, 0x0f, 255];
const SCALE = 4;
const COLS = 4;

function shipped(id) {
  return path.join(SHIPPED, `${id}.png`);
}

// item -> { candidates: n, siblings: [shipped item ids] }
const JOBS = {
  hearty_stew: { n: 4, siblings: ['herb_broth', 'expedition_stew', 'traveler_ration'] },
  goblin_toothed_axe: { n: 4, siblings: ['training_axe', 'bronze_axe', 'hornbound_bronze_axe'] },
  tinbraced_pickaxe: { n: 4, siblings: ['reinforced_pickaxe', 'hornpoint_pickaxe', 'training_pickaxe'] },
  clawguard_coat: { n: 4, siblings: ['bearhide_coat', 'frostwarden_coat'] },
  frostwarden_coat: { n: 4, siblings: ['bearhide_coat', 'clawguard_coat'] },
  lynx_pelt: { n: 4, siblings: ['wolf_pelt', 'bear_pelt', 'boar_hide'] },
  pristine_horn: { n: 4, siblings: ['ram_horn', 'boar_tusk', 'great_tusk'] },
  heat_scale: { n: 4, siblings: ['ember_core', 'frost_claw', 'scrap_metal'] },
  frost_claw: { n: 4, siblings: ['heat_scale', 'boar_tusk', 'pristine_wolf_fang'] },
  reclaim_bronze_axe: { n: 4, siblings: ['bronze_ingot', 'training_axe'], noShipped: true },
  reclaim_bronze_pickaxe: { n: 4, siblings: ['bronze_ingot', 'training_pickaxe'], noShipped: true },
  reclaim_bronze_chestplate: { n: 4, siblings: ['bronze_ingot', 'bronze_chestplate'], noShipped: true },
  scalewarmed_chestplate: { n: 2, siblings: ['bronze_chestplate', 'traveler_tunic'] },
  bronze_longsword: { n: 2, siblings: ['bronze_sword', 'fanghilt_sword'] },
  fanghilt_sword: { n: 2, siblings: ['bronze_sword', 'bronze_longsword'] },
  wolf_pelt: { n: 2, siblings: ['bear_pelt', 'boar_hide'] },
  hollow_root: { n: 2, siblings: ['meadow_herb', 'duskcap', 'gloom_silk'] },
  ram_horn: { n: 2, siblings: ['boar_tusk', 'pristine_wolf_fang'] },
  reinforced_pickaxe: { n: 2, siblings: ['hornpoint_pickaxe', 'training_pickaxe'] },
  bearhide_coat: { n: 2, siblings: ['clawguard_coat', 'frostwarden_coat'] },
};

fs.mkdirSync(OUT, { recursive: true });

for (const [item, cfg] of Object.entries(JOBS)) {
  const frames = [];
  for (let i = 1; i <= cfg.n; i++) {
    const f = path.join(RAW, item, `c${i}.png`);
    if (fs.existsSync(f)) frames.push(png.load(f));
  }
  // shipped icon (skip for items with no shipped equivalent, e.g. reclaim crates)
  if (!cfg.noShipped) {
    const s = shipped(item);
    if (fs.existsSync(s)) frames.push(png.loadAny(s));
  }
  for (const sib of cfg.siblings) {
    const s = shipped(sib);
    if (fs.existsSync(s)) frames.push(png.loadAny(s));
    else console.warn(`${item}: missing sibling ${sib}`);
  }

  const cw = Math.max(...frames.map((r) => r.width));
  const ch = Math.max(...frames.map((r) => r.height));
  const rows = Math.ceil(frames.length / COLS);
  const gap = 2;
  const W = (COLS * (cw + gap) + gap) * SCALE;
  const H = (rows * (ch + gap) + gap) * SCALE;
  const sheet = new png.Raster(W, H);
  png.fill(sheet, BG);
  frames.forEach((r, i) => {
    const col = i % COLS;
    const row = Math.floor(i / COLS);
    const x = (gap + col * (cw + gap)) * SCALE;
    const y = (gap + row * (ch + gap) + (ch - r.height)) * SCALE;
    png.blit(sheet, png.scale(r, SCALE), x, y);
  });
  const out = path.join(OUT, `${item}_sheet.png`);
  png.save(out, sheet);
  console.log(`${item}: ${frames.length} frames -> ${out} (${W}x${H})`);
}
