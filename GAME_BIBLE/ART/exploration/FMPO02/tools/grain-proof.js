// grain-proof.js — judge "grain, not pattern" the only way it can be judged:
// tiled, at the scale Flutter will tile it, with body text running over it.
//
// A 32x32 tile inspected alone always looks fine. The defect the eye catches is
// the REPEAT — a fleck that lands on the same relative spot every 64 logical px
// reads as plaid the moment three copies sit side by side, and it reads worse
// once text crosses it, because the grain then competes with the words instead
// of sitting behind them.
//
// So: each tile is drawn at x2 (one source px = two logical px, RULES.md G-3)
// across a 200x120 logical panel, exactly as `_FramePainter` will tile a
// surface into a card interior, and five 1px runs in `textPrimary #F0E7D8` are
// laid across it at body-text positions. Then the whole sheet is scaled again
// for reading.
//
// Output is a review artifact. It is never a shipped asset.
//
// Usage:
//   node grain-proof.js <out.png> <cols> <label:file.png> [label:file.png ...]
'use strict';
const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

const PANEL_W = 200; const PANEL_H = 120;
const TILE_SCALE = 2;
const TEXT = [0xf0, 0xe7, 0xd8, 255];
const GROUND = [0x14, 0x12, 0x0f, 255];
// Five runs at plausible body-copy positions, as [y, x0, x1].
const RUNS = [[18, 12, 172], [34, 12, 188], [50, 12, 140], [78, 12, 180], [94, 12, 118]];

function panel(tile) {
  const p = new png.Raster(PANEL_W, PANEL_H);
  for (let y = 0; y < PANEL_H; y += 1) {
    for (let x = 0; x < PANEL_W; x += 1) {
      const sx = Math.floor(x / TILE_SCALE) % tile.width;
      const sy = Math.floor(y / TILE_SCALE) % tile.height;
      const si = ((sy * tile.width) + sx) << 2;
      const di = ((y * PANEL_W) + x) << 2;
      if (tile.data[si + 3] === 0) {
        p.data[di] = GROUND[0]; p.data[di + 1] = GROUND[1]; p.data[di + 2] = GROUND[2]; p.data[di + 3] = 255;
      } else {
        p.data[di] = tile.data[si]; p.data[di + 1] = tile.data[si + 1];
        p.data[di + 2] = tile.data[si + 2]; p.data[di + 3] = 255;
      }
    }
  }
  for (const [y, x0, x1] of RUNS) {
    for (let x = x0; x < x1; x += 1) {
      const i = ((y * PANEL_W) + x) << 2;
      p.data[i] = TEXT[0]; p.data[i + 1] = TEXT[1]; p.data[i + 2] = TEXT[2]; p.data[i + 3] = 255;
    }
  }
  return p;
}

function main() {
  const a = process.argv.slice(2);
  const out = a[0];
  const cols = Number(a[1]);
  const items = a.slice(2).map((s) => {
    const k = s.indexOf(':');
    return { label: s.slice(0, k), file: s.slice(k + 1) };
  });

  const gap = 6;
  const rows = Math.ceil(items.length / cols);
  const W = (cols * (PANEL_W + gap)) + gap;
  const H = (rows * (PANEL_H + gap)) + gap;
  const sheet = new png.Raster(W, H);
  png.fill(sheet, [0x0a, 0x09, 0x08, 255]);

  items.forEach((it, i) => {
    const c = i % cols; const r = Math.floor(i / cols);
    png.blit(sheet, panel(png.loadAny(it.file)), gap + (c * (PANEL_W + gap)), gap + (r * (PANEL_H + gap)));
    console.log('  cell ' + (c + 1) + ',' + (r + 1) + '  ' + it.label + '  ' + it.file);
  });

  fs.mkdirSync(path.dirname(out), { recursive: true });
  png.save(out, sheet);
  png.save(out.replace(/\.png$/, '_x2.png'), png.scale(sheet, 2));
  console.log(out + ' ' + W + 'x' + H + ' (' + items.length + ' panels)');
}
main();
