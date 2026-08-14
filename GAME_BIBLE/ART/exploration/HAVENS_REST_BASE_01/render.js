// Project Stride - Haven's Rest Base Scene 01
// Writes the native scene and the x8 nearest-neighbour review render.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Not part of the app build, not referenced
// by any Flutter, Dart, Kotlin, Swift, or CI target, and not shipping art.
//
// Usage, from the repository root:
//   node GAME_BIBLE/ART/exploration/HAVENS_REST_BASE_01/render.js

'use strict';
const fs = require('fs');
const path = require('path');
const { PALETTE } = require('./palette_ext');
const { buildScene } = require('./scene');

const SCALE = 8;
const OUT = path.join(__dirname, 'out');

fs.mkdirSync(OUT, { recursive: true });

const scene = buildScene();
fs.writeFileSync(path.join(OUT, 'havens_rest_base.png'), scene.png(PALETTE));
fs.writeFileSync(path.join(OUT, `havens_rest_base_x${SCALE}.png`), scene.scale(SCALE).png(PALETTE));

console.log(`havens_rest_base: ${scene.w}x${scene.h} native, ` +
  `${scene.w * SCALE}x${scene.h * SCALE} review, ${PALETTE.length} palette entries`);
