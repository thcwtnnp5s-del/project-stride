// Project Stride - Haven's Rest Base Scene 01
// The CODE_RENDER_01 3x5 bitmap font, EXTENDED with the glyphs the HUD needs.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Provisional; not a typographic decision.
//
// The proof only ever had to set "x2", "90" and "+10XP". The top HUD strip adds
// "Haven's Rest" and "1,240", which need mixed-case letters and a comma. The
// proof's own glyph table is imported unchanged rather than edited, so
// CODE_RENDER_01 keeps rendering byte-identically.
//
// Same 3 x 5 cell on a 4 px advance. Lowercase occupies the lower four rows so
// it sits on the same baseline as the capitals.

'use strict';
const { GLYPHS: BASE_GLYPHS } = require('../CODE_RENDER_01/sprites');

const GLYPHS = Object.assign({}, BASE_GLYPHS, {
  H: ['#.#', '#.#', '###', '#.#', '#.#'],
  R: ['##.', '#.#', '##.', '#.#', '#.#'],
  a: ['...', '##.', '.##', '#.#', '.##'],
  e: ['...', '.#.', '###', '#..', '.##'],
  n: ['...', '##.', '#.#', '#.#', '#.#'],
  s: ['...', '.##', '##.', '..#', '##.'],
  t: ['.#.', '###', '.#.', '.#.', '.##'],
  v: ['...', '#.#', '#.#', '#.#', '.#.'],
  "'": ['.#.', '.#.', '...', '...', '...'],
  ',': ['...', '...', '...', '.#.', '#..'],
  4: ['#.#', '#.#', '###', '..#', '..#'],
});

function drawText(surf, text, x, y, idx) {
  let cx = x;
  for (const ch of text) {
    const g = GLYPHS[ch];
    if (!g) throw new Error(`no glyph for '${ch}'`);
    g.forEach((row, dy) => {
      for (let dx = 0; dx < row.length; dx++) if (row[dx] === '#') surf.set(cx + dx, y + dy, idx);
    });
    cx += 4;
  }
  return cx - 1;
}

function textWidth(text) { return text.length * 4 - 1; }

module.exports = { GLYPHS, drawText, textWidth };
