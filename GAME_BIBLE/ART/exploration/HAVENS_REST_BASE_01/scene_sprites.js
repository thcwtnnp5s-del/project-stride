// Project Stride - Haven's Rest Base Scene 01
// New artwork authored for the base world scene: the resident NPC, two trees of
// one species, and the HUD icon set.
//
// EXPLORATION-SUPPORT ARTIFACT ONLY. Nothing here is an art decision.
//
// The Traveler and the Meadow Herb are NOT re-authored here. CODE_RENDER_01 is
// preserved proof evidence and is never edited (RULES.md G-7, craft spec CR-2:
// do not improve successful work). Where full-scene review found an objective
// defect that only exists in context, the proof sprite is imported and a
// SCENE-LOCAL DERIVED COPY carries the correction, pixel by named pixel, so the
// proof and the correction stay separately auditable.
//
// Legend, from palette_ext.js: proof letters plus
//   1 2 3 = sky dark/mid/light    4 5 6 = roof dark/mid/light
//   7 8 9 = canopy dark/mid/light i j o = rust dark/mid/light
// '.' is transparent. Light is baked from the UPPER LEFT.

'use strict';
const { Surface, fromMap } = require('../CODE_RENDER_01/surface');
const { PLAYER, HERB_ICON } = require('../CODE_RENDER_01/sprites');
const { L } = require('./palette_ext');
const { drawText, textWidth } = require('./font_ext');

// A copy of a frozen proof sprite with a named list of single-pixel edits.
// The source surface is never mutated.
function derive(src, edits) {
  const out = new Surface(src.w, src.h);
  out.px.set(src.px);
  for (const [x, y, ch] of edits) out.set(x, y, L[ch]);
  return out;
}

// ---------------------------------------------------------------- resident NPC
// 12 x 22 canvas, figure occupies rows 1-20 => 20 px tall.
//
// NOT a palette swap of the Traveler. Shared construction (CR-3 near/far, CR-6
// deliberate asymmetry, CR-13 three values down the arm, CR-16 outline breaks)
// but a different body: narrower shoulders, weight settled on the near hip so
// the figure sits slightly off its own centreline, a shorter hem, hands hanging
// empty, and a rounder head with the hair mass low rather than crowned.
//
// Near/far chain (CR-3): the resident turns toward the viewer's LEFT -- the
// opposite of the Traveler -- so their near side is viewer-LEFT. That single
// decision is what stops the two figures reading as one sprite twice.
// Consequently the near shoulder appears first, the near arm is lit, the far
// arm is shaded, and the far foot plants one row above the near one on the
// right. The one accent is a rust over-tunic across the shoulders.
const NPC_MAP = [
  '............', //  0
  '....kkkk....', //  1  round crown, no fringe silhouette
  '...khhhhk...', //  2
  '...kWSHhk...', //  3  face plane on the NEAR (viewer-left) side
  '...kSkShk...', //  4  near eye; the far eye is compressed into the hairline
  '...kSskkk...', //  5  jaw recedes on the far side
  '....kssk....', //  6  neck
  '..kjjjPPk...', //  7  NEAR shoulder alone, one row higher (CR-4)
  '..kjjPPPjk..', //  8  rust over-tunic across the shoulders: the only accent
  '..kSjPPPjk..', //  9  near upper arm shaded, torso plain
  '..kWjPPPPjk.', // 10  near forearm lit
  '..kSkPPPPSk.', // 11  near hand terminates, then far hand one row lower
  '...kpPPPpkk.', // 12  waist pinch
  '...kbBBBbk..', // 13  belt
  '...kbBBBbk..', // 14
  '...kBBkBbk..', // 15  near leg lighter, far leg darker, unequal widths
  '...kBBkNbk..', // 16  FAR boot cuff: one light row (CR-17)
  '...kNNkbbk..', // 17  NEAR boot cuff, one row lower than the far one (CR-4)
  '...kBBkbbk..', // 18
  '..kBBBkbbk..', // 19  far foot plants here
  '..kbbbkkkk..', // 20  near foot forward, one row lower
  '............', // 21
];

// ---------------------------------------------------------------- trees
// One species, two individuals. Same construction grammar -- clustered canopy
// masses in three canopy steps, light up-left, a readable trunk, no
// individual-leaf texture -- but genuinely different plants: different heights,
// different mass counts, opposite lean, and different trunk offsets. Neither is
// a mirror or a copy of the other (CR-19).
//
// Terrain and background carry no outline; the outline is reserved as the
// signal for things that can be touched. Trees are therefore unoutlined and
// separate from the field by value alone.

// Tree A -- left of the settlement. 17 x 24. Shorter, wider, leaning right,
// trunk offset left of the canopy's centre of mass.
const TREE_A_MAP = [
  '.....99..........', //  0
  '...9999988.......', //  1
  '..9998888888.....', //  2
  '.99888888888.....', //  3
  '.9888888888887...', //  4
  '99888888888.877..', //  5  a notch of sky cuts into the mass
  '98888888888.8777.', //  6
  '.888888888887777.', //  7
  '.8888888887777777', //  8
  '..88888877777777.', //  9
  '..888887777777...', // 10
  '...8887777777....', // 11
  '....87777777.....', // 12
  '.....777777......', // 13
  '......7.77.......', // 14
  '......Zw.........', // 15  trunk emerges left of the canopy centre
  '......Zw.........', // 16
  '......Zw.........', // 17
  '.....ZZw.........', // 18
  '.....ZZww........', // 19
  '.....Zwww........', // 20
  '....ZZw.ww.......', // 21  a low root flare, not symmetrical
  '....Zw...w.......', // 22
  '.................', // 23
];

// Tree B -- right of the settlement. 17 x 27. Taller, narrower, leaning left,
// canopy carried in two stacked masses rather than one, trunk straighter.
const TREE_B_MAP = [
  '......999........', //  0
  '....99988887.....', //  1
  '...998888888.....', //  2
  '..99888888887....', //  3
  '..98888888.777...', //  4
  '..9888888..7777..', //  5
  '...88888887777...', //  6
  '....888877777....', //  7
  '.....8877777.....', //  8
  '......8.77.......', //  9  the two masses are separated, not one blob
  '...999888.77.....', // 10
  '..99888888877....', // 11
  '.9888888888777...', // 12
  '.988888888.7777..', // 13
  '..8888888887777..', // 14
  '...88888877777...', // 15
  '....8888777777...', // 16
  '.....88777777....', // 17
  '......7777.7.....', // 18
  '.......Zw........', // 19
  '.......Zw........', // 20
  '.......Zw........', // 21
  '.......Zw........', // 22
  '......ZZww.......', // 23
  '......Zwww.......', // 24
  '.....ZZw..w......', // 25
  '.....Zw..........', // 26
];

// ---------------------------------------------------------------- HUD icons
// Icon-only, chunky geometric construction (CR-31). Authored as 1-bit masks and
// painted in a single value, because a tab icon at this size is a silhouette
// and nothing else. Six tabs, matching the six-tab structure the mobile
// experience document already fixes; the visual language of each is
// PROVISIONAL.
const TAB_MASKS = [
  [ // 1 - character
    '...###...',
    '...###...',
    '..#####..',
    '.#######.',
    '.#######.',
    '..#####..',
    '..##.##..',
    '..##.##..',
    '..##.##..',
  ],
  [ // 2 - walking / activity
    '..##.....',
    '..##.....',
    '..##.....',
    '..##.....',
    '..###....',
    '..#####..',
    '.#######.',
    '#########',
    '#########',
  ],
  [ // 3 - skills / gathering
    '.....###.',
    '...#####.',
    '..######.',
    '.###.###.',
    '.##..###.',
    '.#..####.',
    '.#.###...',
    '.####....',
    '.##......',
  ],
  [ // 4 - crafting
    '..#####..',
    '.#######.',
    '.#######.',
    '..#####..',
    '...##....',
    '...##....',
    '...##....',
    '...##....',
    '...##....',
  ],
  [ // 5 - inventory
    '..#...#..',
    '..#####..',
    '.#######.',
    '.#######.',
    '.##...##.',
    '.##...##.',
    '.#######.',
    '.#######.',
    '.#######.',
  ],
  [ // 6 - world
    // A landform, not a compass star: Pass 2's four-point star read as a
    // sparkle, which is exactly the magical register the floor forbids.
    '.........',
    '....#....',
    '...###...',
    '..##.##..',
    '.##...##.',
    '##.....##',
    '#########',
    '#########',
    '.........',
  ],
];

// Banked walking energy is presented as a stock the player owns: a boot glyph
// and a numeral. Never a meter, never a countdown (PROJECT_KERNEL/06).
const BOOT_MASK = [
  '.###...',
  '.###...',
  '.###...',
  '.####..',
  '.######',
  '#######',
];

// A 1-bit mask painted in one palette index.
function drawMask(surf, mask, x, y, idx) {
  mask.forEach((row, dy) => {
    for (let dx = 0; dx < row.length; dx++) if (row[dx] === '#') surf.set(x + dx, y + dy, idx);
  });
}

// ------------------------------------------------- Traveler, scene-corrected
// IN-CONTEXT READABILITY CORRECTION. Two pixels. Not a character pass.
//
// Full-scene review found the one defect an isolated sprite could not show: the
// near hand was a SINGLE skin pixel at (15,17) with ink on both sides of it and
// the crossguard immediately beyond, so at scene scale hand + grip + guard
// merged into one dark mass at the hip. CR-16's outline pixel at x16 was
// already there and doing its job; what failed was CR-14 -- the hand had no
// mass left to terminate the limb with.
//
// The fix gives the hand a second row and lifts it one value step, so it reads
// as skin against the ink break beside it. Stance, proportions, tunic, head,
// pack, sword size and overall silhouette are untouched.
const PLAYER_SCENE = derive(PLAYER, [
  [15, 16, 'S'], // forearm terminates in the hand rather than in the sleeve
  [15, 17, 'W'], // the hand itself, one step lighter, beside the ink break
]);

// -------------------------------------------------- gather card, scene-fitted
// FULL-SCENE INTEGRATION ADJUSTMENT -- not a UI direction decision, and not a
// redesign. The proof card's visual language is reproduced exactly: flat opaque
// plate, one-pixel ink border, clipped corners, a single construction bevel
// light up-left and dark down-right, an engraved seam, the herb icon carrying
// the node's own silhouette family, and the same bitmap typography.
//
// Two objective full-frame defects are corrected:
//   * 36 x 24 is undersized against a 128-wide world frame
//   * the proof card right-aligned '+10XP' with no room for its space, so the
//     permitted string "+10 XP" was not literally rendered
//
// 48 x 30 buys the space back and gives the type the margin CR-31 asks for.
// These dimensions are PROVISIONAL and are not canonical.
function buildSceneGatherCard() {
  const W = 48, H = 30;
  const s = new Surface(W, H);

  s.rect(1, 1, W - 2, H - 2, L.x);
  s.frame(0, 0, W, H, L.k);
  s.set(0, 0, 0); s.set(W - 1, 0, 0);
  s.set(0, H - 1, 0); s.set(W - 1, H - 1, 0);

  for (let x = 1; x < W - 1; x++) { s.set(x, 1, L.y); s.set(x, H - 2, L.a); }
  for (let y = 1; y < H - 1; y++) { s.set(1, y, L.y); s.set(W - 2, y, L.a); }
  s.set(W - 2, 1, L.x); s.set(1, H - 2, L.x);

  s.blit(HERB_ICON, 5, 6);          // yield: what you get
  drawText(s, 'x2', 19, 8, L.z);

  for (let x = 4; x < W - 4; x++) { // engraved seam, not a shine
    s.set(x, 17, L.a);
    s.set(x, 18, L.y);
  }

  drawText(s, '90', 5, 21, L.v);    // cost
  const xp = '+10 XP';              // gain, right-aligned, space intact
  drawText(s, xp, W - 5 - textWidth(xp), 21, L.v);

  return s;
}

const NPC = fromMap(NPC_MAP, L);
const TREE_A = fromMap(TREE_A_MAP, L);
const TREE_B = fromMap(TREE_B_MAP, L);
const SCENE_GATHER_CARD = buildSceneGatherCard();

module.exports = {
  NPC, TREE_A, TREE_B, PLAYER_SCENE, SCENE_GATHER_CARD,
  TAB_MASKS, BOOT_MASK, drawMask,
};
