// enemy-stage.js — EPO03 ENEMIES. Seats a creature on a habitat plate with
// exactly the arithmetic `_EnemyStage` (lib/ui/screens/adventure/
// encounter_card.dart) uses, draws the foreground overlay above it, and lays
// the cells on a contact sheet. Deterministic: blit, scale and one multiply
// ellipse that mirrors GroundedSprite's ContactShadowSpec (A-2 — a review
// aid, never an asset).
//
//   node enemy-stage.js <out.png> <scale> <cols> <cell> [<cell> ...]
//   cell = plate.png,creature_f0.png[,foreground.png]
//
// Seating (native plate pixels, before the sheet scale):
//   band height  = plate height (76 → 152 dp, 96 → 192 dp at ×2)
//   creature x   = centred: floor((plateW - canvasW) / 2)
//   creature y   = footprint.bottom lands on row plateH - 5
//                  (GroundedSprite's bleed 4 + ContactShadowSpec.inset 1)
//   foreground   = same canvas as the plate, bottom-aligned, drawn last.
'use strict';
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const [out, scaleS, colsS, ...cells] = process.argv.slice(2);
const scale = Number(scaleS);
const cols = Number(colsS);
if (!out || !scale || !cols || cells.length === 0) {
  console.error('usage: node enemy-stage.js <out.png> <scale> <cols> plate,creature[,fg] ...');
  process.exit(2);
}

// GroundedSprite's shadow, in sprite-native pixels (grounded_sprite.dart).
const STRENGTH = 0.72;
const SQUASH = 0.30;
const SPREAD = 3;
const INSET = 1;
const MAX_HALF_HEIGHT = 9;

function shadow(dst, fp, ox, oy) {
  const cx = ox + (fp.left + fp.right + 1) / 2;
  const cy = oy + fp.bottom - INSET;
  const rx = fp.width / 2 + SPREAD;
  const ry = Math.min(rx * SQUASH, MAX_HALF_HEIGHT);
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
    for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      if (x < 0 || y < 0 || x >= dst.width || y >= dst.height) continue;
      const nx = (x + 0.5 - cx) / rx;
      const ny = (y + 0.5 - cy) / ry;
      const r2 = nx * nx + ny * ny;
      if (r2 >= 1) continue;
      const a = (1 - r2) * STRENGTH;
      const i = dst.idx(x, y);
      for (let k = 0; k < 3; k++) dst.data[i + k] = Math.round(dst.data[i + k] * (1 - a));
    }
  }
}

function seat(spec) {
  const [plateF, creatureF, fgF] = spec.split(',');
  const plate = png.loadAny(plateF);
  const cell = new png.Raster(plate.width, plate.height);
  png.blit(cell, plate, 0, 0);
  if (creatureF) {
    const c = png.loadAny(creatureF);
    const fp = png.footprint(c);
    if (!fp) throw new Error(`${creatureF}: empty sprite`);
    const ox = Math.floor((plate.width - c.width) / 2);
    const oy = plate.height - 5 - fp.bottom;
    shadow(cell, fp, ox, oy);
    png.blit(cell, c, ox, oy);
  }
  if (fgF) {
    const fg = png.loadAny(fgF);
    png.blit(cell, fg, Math.floor((plate.width - fg.width) / 2), plate.height - fg.height);
  }
  return cell;
}

const rasters = cells.map(seat);
const cw = Math.max(...rasters.map((r) => r.width));
const ch = Math.max(...rasters.map((r) => r.height));
const rows = Math.ceil(rasters.length / cols);
const gap = 2;
const W = (cols * (cw + gap) + gap) * scale;
const H = (rows * (ch + gap) + gap) * scale;
const sheet = new png.Raster(W, H);
png.fill(sheet, [0x1e, 0x1e, 0x1e, 255]);
rasters.forEach((r, i) => {
  const col = i % cols;
  const row = Math.floor(i / cols);
  const x = (gap + col * (cw + gap)) * scale;
  const y = (gap + row * (ch + gap) + (ch - r.height)) * scale;
  png.blit(sheet, png.scale(r, scale), x, y);
});
png.save(out, sheet);
console.log(`${out} ${W}x${H} (${rasters.length} cells, ${cw}x${ch} x${scale})`);
