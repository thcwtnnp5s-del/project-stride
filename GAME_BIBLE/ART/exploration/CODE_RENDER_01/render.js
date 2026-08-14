// Project Stride - Code Render 01
// Renders the three proof assets and the contact sheet.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY.
//
// Usage, from the repository root:
//   node GAME_BIBLE/ART/exploration/CODE_RENDER_01/render.js
//
// Writes native PNGs and x8 nearest-neighbour review PNGs into ./out.
// The contact sheet BLITS the exact same sprite objects the individual assets
// are written from. Nothing is redrawn for presentation.

'use strict';
const fs = require('fs');
const path = require('path');
const { Surface } = require('./surface');
const { PALETTE, L } = require('./palette');
const { PLAYER, HERB, GATHER_CARD } = require('./sprites');

const SCALE = 8;
const OUT = path.join(__dirname, 'out');

function write(name, surf) {
  fs.writeFileSync(path.join(OUT, `${name}.png`), surf.png(PALETTE));
  fs.writeFileSync(path.join(OUT, `${name}_x${SCALE}.png`), surf.scale(SCALE).png(PALETTE));
  console.log(`${name}: ${surf.w}x${surf.h} native, ${surf.w * SCALE}x${surf.h * SCALE} review`);
}

// Integer midpoint ellipse, filled. No floats reach a pixel decision.
function contactShadow(surf, cx, cy, rx, ry, idx) {
  for (let y = -ry; y <= ry; y++) {
    for (let x = -rx; x <= rx; x++) {
      if (x * x * ry * ry + y * y * rx * rx <= rx * rx * ry * ry) surf.set(cx + x, cy + y, idx);
    }
  }
}

// ---------------------------------------------------------------- contact sheet
// Presentation only. A quiet neutral ground so each asset is judged against the
// kind of terrain the rendering floor actually calls for.
function buildSheet() {
  const W = 104, H = 46;
  const s = new Surface(W, H, L.G);

  for (let x = 0; x < W; x++) {            // one quiet ground band, no texture
    s.set(x, 40, L.g);
    s.set(x, 41, L.g);
  }
  for (let y = 42; y < H; y++) for (let x = 0; x < W; x++) s.set(x, y, L.g);

  contactShadow(s, 18, 39, 7, 2, L.g);
  contactShadow(s, 48, 38, 5, 2, L.g);

  s.blit(PLAYER, 6, 7);   // feet land on the contact shadow, not above it
  s.blit(HERB, 38, 20);
  s.blit(GATHER_CARD, 64, 11);

  return s;
}

fs.mkdirSync(OUT, { recursive: true });
write('player', PLAYER);
write('herb', HERB);
write('gather_card', GATHER_CARD);
write('proof_sheet', buildSheet());
