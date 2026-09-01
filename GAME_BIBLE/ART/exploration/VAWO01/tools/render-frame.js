// render-frame.js — reproduce `_FramePainter` outside Flutter, so a frame can
// be judged at the sizes it will actually be drawn at before it is packaged.
//
// This mirrors `lib/ui/components/pixel_asset.dart` `_FramePainter.paint`
// exactly: four corners drawn once each at integer scale, four edge runs
// **tiled** (never stretched) with the final tile clipped. If this and that
// disagree, this file is wrong.
//
// Why it exists: production plan §3.3 works out that the four supported phone
// widths produce four different fractional remainders in the horizontal run --
// 14.0 exact at 320 dp, 16.5, 18.5625, 20.875 -- so a seam can be invisible at
// the width its author reviewed and obvious at the next. A single-height render
// cannot see that. This renders the whole matrix in one pass.
//
// Output is a review artifact, never a shipped asset.
'use strict';

const fs = require('fs');
const path = require('path');
const png = require(path.resolve(__dirname, '../../../../../Scripts/art/png.js'));

// StrideSpace.screenGutter is 16 logical, applied both sides.
const GUTTER = 16;
const WIDTHS = [320, 360, 393, 430];
// A short card and a tall one: §3.3 asks for both, because a vertical run's
// repeat count is content-driven and a seam can beat at one and not the other.
const HEIGHTS = [120, 336];

const BG = [0x14, 0x12, 0x0f, 255]; // surfaceGround
const FILL = [0x20, 0x1c, 0x17, 255]; // surfaceCard

function blitRect(dst, src, sx, sy, sw, sh, dx, dy, scale) {
  for (let y = 0; y < sh * scale; y += 1) {
    for (let x = 0; x < sw * scale; x += 1) {
      const ox = dx + x; const oy = dy + y;
      if (ox < 0 || oy < 0 || ox >= dst.width || oy >= dst.height) continue;
      const px = sx + Math.floor(x / scale);
      const py = sy + Math.floor(y / scale);
      if (px < 0 || py < 0 || px >= src.width || py >= src.height) continue;
      const si = ((py * src.width) + px) << 2;
      if (src.data[si + 3] === 0) continue;
      const di = ((oy * dst.width) + ox) << 2;
      dst.data[di] = src.data[si];
      dst.data[di + 1] = src.data[si + 1];
      dst.data[di + 2] = src.data[si + 2];
      dst.data[di + 3] = 255;
    }
  }
}

/**
 * Paint one framed card. `w`/`h` are logical px; `corner` and `scale` are the
 * PanelSkin fields.
 */
function paintCard(sheet, w, h, corner, scale, band) {
  const card = new png.Raster(w, h);
  // ground, then the card fill inside the band
  for (let i = 0; i < w * h; i += 1) {
    card.data[(i << 2)] = BG[0]; card.data[(i << 2) + 1] = BG[1];
    card.data[(i << 2) + 2] = BG[2]; card.data[(i << 2) + 3] = 255;
  }
  const inset = band * scale;
  for (let y = inset; y < h - inset; y += 1) {
    for (let x = inset; x < w - inset; x += 1) {
      const i = ((y * w) + x) << 2;
      card.data[i] = FILL[0]; card.data[i + 1] = FILL[1];
      card.data[i + 2] = FILL[2]; card.data[i + 3] = 255;
    }
  }

  const n = corner;
  const c = n * scale;
  const iw = sheet.width; const ih = sheet.height;

  // Corners, once each.
  blitRect(card, sheet, 0, 0, n, n, 0, 0, scale);
  blitRect(card, sheet, iw - n, 0, n, n, w - c, 0, scale);
  blitRect(card, sheet, 0, ih - n, n, n, 0, h - c, scale);
  blitRect(card, sheet, iw - n, ih - n, n, n, w - c, h - c, scale);

  // Edge runs, tiled, last tile clipped -- exactly _FramePainter's loops.
  const stripW = (iw - (2 * n)) * scale;
  const stripH = (ih - (2 * n)) * scale;
  for (let x = c; x < w - c; x += stripW) {
    const runW = Math.min(stripW, w - c - x);
    const srcW = Math.round((iw - (2 * n)) * (runW / stripW));
    blitRect(card, sheet, n, 0, srcW, n, x, 0, scale);
    blitRect(card, sheet, n, ih - n, srcW, n, x, h - c, scale);
  }
  for (let y = c; y < h - c; y += stripH) {
    const runH = Math.min(stripH, h - c - y);
    const srcH = Math.round((ih - (2 * n)) * (runH / stripH));
    blitRect(card, sheet, 0, n, n, srcH, 0, y, scale);
    blitRect(card, sheet, iw - n, n, n, srcH, w - c, y, scale);
  }
  return card;
}

function main() {
  const args = process.argv.slice(2);
  const file = args[0];
  const num = (flag, dflt) => { const i = args.indexOf(flag); return i === -1 ? dflt : Number(args[i + 1]); };
  const corner = num('--corner', 16);
  const scale = num('--scale', 2);
  const band = num('--band', 11);
  const outDir = (() => { const i = args.indexOf('--out'); return i === -1 ? 'review' : args[i + 1]; })();

  const sheet = png.loadAny(file);
  fs.mkdirSync(outDir, { recursive: true });

  console.log(`sheet ${sheet.width}x${sheet.height}  corner ${corner}  band ${band}  scale ${scale}`);
  console.log(`inset = band*scale = ${band * scale} logical px per side\n`);

  // One contact sheet: every width, both heights, stacked.
  const cards = [];
  for (const dp of WIDTHS) {
    for (const ch of HEIGHTS) {
      const cw = dp - (GUTTER * 2);
      const run = cw - (corner * scale * 2);
      const tiles = run / ((sheet.width - (2 * corner)) * scale);
      console.log(`  ${dp} dp -> card ${cw} wide, run ${run} logical, ${tiles.toFixed(4)} tiles`);
      cards.push({ dp, ch, img: paintCard(sheet, cw, ch, corner, scale, band) });
    }
  }

  const pad = 12;
  const sheetW = Math.max(...cards.map((k) => k.img.width)) + (pad * 2);
  const sheetH = cards.reduce((s, k) => s + k.img.height + pad, pad);
  const out = new png.Raster(sheetW, sheetH);
  for (let i = 0; i < sheetW * sheetH; i += 1) {
    out.data[(i << 2)] = 0x0a; out.data[(i << 2) + 1] = 0x09;
    out.data[(i << 2) + 2] = 0x08; out.data[(i << 2) + 3] = 255;
  }
  let y = pad;
  for (const k of cards) {
    png.blit(out, k.img, pad, y);
    y += k.img.height + pad;
  }
  const base = path.basename(file).replace(/\.png$/, '');
  png.save(path.join(outDir, `${base}_cards.png`), out);
  png.save(path.join(outDir, `${base}_cards_x2.png`), png.scale(out, 2));
  console.log(`\nwrote ${path.join(outDir, `${base}_cards.png`)}`);
}

main();
