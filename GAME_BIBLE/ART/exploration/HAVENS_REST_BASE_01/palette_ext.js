// Project Stride - Haven's Rest Base Scene 01
// The CODE_RENDER_01 proof palette, EXTENDED for a full world scene.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Nothing here is an art decision. Palette
// is UNRESOLVED in GAME_BIBLE/ART/ART_DIRECTION.md and this file does not
// change that (RULES.md G-3).
//
// The 49-entry proof palette is imported UNCHANGED and its indices are
// UNTOUCHED, so every CODE_RENDER_01 sprite (Traveler, Meadow Herb, gather
// card) blits into this scene with its authored indices intact. Four ramps are
// APPENDED because the full environment needs four materials the character /
// node / UI proof never had to express. Each is recorded with the reason the
// existing palette could not carry it:
//
//   sky     -- there is no sky in the proof. No existing ramp is a pale cool
//              atmospheric value; `stone` is a rock counterweight, not air.
//   roof    -- `timber` is the palisade, gate, signpost and firewood. Roofing
//              drawn in `timber` would make the buildings and the wall one
//              material and the settlement would read as a single mass.
//   canopy  -- `grass` IS the meadow field. Tree foliage drawn in `grass`
//              disappears into the ground it stands on. Canopy needs to sit
//              darker and cooler than the field it is seen against.
//   rust    -- the resident's single muted rust/umber outer-garment accent.
//              `leather` is belts and boots, so an accent drawn in it reads as
//              more equipment rather than as clothing.
//
// Deliberately NOT added, and solved by reuse instead:
//   distant treeline -> `stone` mid. Depth is carried by value and saturation
//                       loss, which is what a cool low-contrast grey-green
//                       horizon band already is.
//   smoke            -> `sky` light and mid.
//   dirt roads/path  -> existing `dirt` ramp.
//
// Total: 49 + 12 = 61 entries, still three-step ramps, still no glow ramp, no
// specular ramp, no cinematic highlight ramp.

'use strict';
const base = require('../CODE_RENDER_01/palette');

// Copy, never mutate, the proof palette.
const PALETTE = base.PALETTE.map((c) => c.slice());
const IDX = Object.assign({}, base.IDX);

const EXTRA_RAMPS = {
  sky:    ['#71879a', '#94aab6', '#bccbd1'], // pale cool air
  roof:   ['#4a3128', '#6d4838', '#8f634b'], // muted clay roofing
  canopy: ['#22301d', '#324529', '#455e37'], // tree foliage: darker, cooler than the field
  rust:   ['#5a3226', '#7d4634', '#a25f45'], // the resident's one accent
};

for (const [name, ramp] of Object.entries(EXTRA_RAMPS)) {
  IDX[name] = ramp.map((hex) => {
    PALETTE.push([
      parseInt(hex.slice(1, 3), 16),
      parseInt(hex.slice(3, 5), 16),
      parseInt(hex.slice(5, 7), 16),
    ]);
    return PALETTE.length - 1;
  });
}

// Legend: the proof's letters unchanged, plus twelve characters it never used.
const L = Object.assign({}, base.L, {
  1: IDX.sky[0],    2: IDX.sky[1],    3: IDX.sky[2],
  4: IDX.roof[0],   5: IDX.roof[1],   6: IDX.roof[2],
  7: IDX.canopy[0], 8: IDX.canopy[1], 9: IDX.canopy[2],
  i: IDX.rust[0],   j: IDX.rust[1],   o: IDX.rust[2],
});

module.exports = { PALETTE, IDX, L, EXTRA_RAMPS };
